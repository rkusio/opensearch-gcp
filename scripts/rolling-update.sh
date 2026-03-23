#!/bin/bash
# Rolling update orchestrator — zone-by-zone image rotation
# Ensures zero-downtime by draining shards before replacing instances
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Perform a zone-by-zone rolling update of OpenSearch MIG nodes.

Options:
  --project        GCP project ID (required)
  --cluster        OpenSearch cluster name (required)
  --endpoint       OpenSearch endpoint URL (required)
  --region         GCP region (required)
  --zones          Comma-separated zones (required, e.g. europe-central2-a,europe-central2-b,europe-central2-c)
  --role           Node role to update: data, data-hot, coordinator (required)
  --new-template   New instance template self link (required)
  --timeout        Timeout per zone in seconds (default: 3600)
  --dry-run        Show what would be done without executing
  --help           Show this help
EOF
}

PROJECT=""
CLUSTER=""
ENDPOINT=""
REGION=""
ZONES=""
ROLE=""
NEW_TEMPLATE=""
TIMEOUT=3600
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --project)       PROJECT="$2"; shift 2 ;;
    --cluster)       CLUSTER="$2"; shift 2 ;;
    --endpoint)      ENDPOINT="$2"; shift 2 ;;
    --region)        REGION="$2"; shift 2 ;;
    --zones)         ZONES="$2"; shift 2 ;;
    --role)          ROLE="$2"; shift 2 ;;
    --new-template)  NEW_TEMPLATE="$2"; shift 2 ;;
    --timeout)       TIMEOUT="$2"; shift 2 ;;
    --dry-run)       DRY_RUN=true; shift ;;
    --help)          usage; exit 0 ;;
    *)               echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$PROJECT" || -z "$CLUSTER" || -z "$ENDPOINT" || -z "$REGION" || -z "$ZONES" || -z "$ROLE" || -z "$NEW_TEMPLATE" ]]; then
  echo "ERROR: All required options must be provided"
  usage
  exit 1
fi

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

run() {
  if [[ "$DRY_RUN" == true ]]; then
    log "[DRY-RUN] $*"
  else
    "$@"
  fi
}

# ---------------------------------------------------------------------------
# Pre-flight check
# ---------------------------------------------------------------------------
log "=== Rolling Update Start ==="
log "Cluster: ${CLUSTER}"
log "Role: ${ROLE}"
log "Zones: ${ZONES}"
log ""

log "Pre-flight: checking cluster health..."
"${SCRIPT_DIR}/wait-for-green.sh" --endpoint "${ENDPOINT}" --timeout 60 --interval 5

IFS=',' read -ra ZONE_LIST <<< "$ZONES"

# ---------------------------------------------------------------------------
# Process each zone
# ---------------------------------------------------------------------------
for zone in "${ZONE_LIST[@]}"; do
  MIG_NAME="${CLUSTER}-${ROLE}-${zone}"

  log ""
  log "=== Processing zone: ${zone} ==="
  log "MIG: ${MIG_NAME}"

  # Step 1: Drain the zone
  log "Step 1: Draining shards from zone ${zone}..."
  run "${SCRIPT_DIR}/drain-zone.sh" --endpoint "${ENDPOINT}" --zone "${zone}" --timeout "${TIMEOUT}"

  # Step 2: Trigger MIG rolling update
  log "Step 2: Triggering MIG rolling update..."
  run gcloud compute instance-groups managed rolling-action start-update "${MIG_NAME}" \
    --project="${PROJECT}" \
    --zone="${zone}" \
    --version="template=${NEW_TEMPLATE}" \
    --max-surge=1 \
    --max-unavailable=1

  # Step 3: Wait for MIG to stabilize
  log "Step 3: Waiting for MIG to stabilize..."
  run gcloud compute instance-groups managed wait-until "${MIG_NAME}" \
    --project="${PROJECT}" \
    --zone="${zone}" \
    --stable \
    --timeout="${TIMEOUT}"

  # Step 4: Undrain the zone
  log "Step 4: Undraining zone ${zone}..."
  run "${SCRIPT_DIR}/drain-zone.sh" --endpoint "${ENDPOINT}" --zone "${zone}" --undrain

  # Step 5: Wait for cluster to return to green
  log "Step 5: Waiting for cluster green..."
  run "${SCRIPT_DIR}/wait-for-green.sh" --endpoint "${ENDPOINT}" --timeout "${TIMEOUT}"

  log "=== Zone ${zone} complete ==="
done

log ""
log "=== Rolling Update Complete ==="
log "All zones updated successfully."
