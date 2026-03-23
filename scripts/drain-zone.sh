#!/bin/bash
# Drain or undrain shards from a specific zone
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") --endpoint <url> --zone <zone> [--undrain]

Drain shards from a zone by setting cluster routing allocation exclusion,
or undrain by removing the exclusion.

Options:
  --endpoint     OpenSearch endpoint URL (required)
  --zone         Zone to drain (required, e.g. europe-central2-a)
  --undrain      Remove the zone exclusion (undrain)
  --wait         Wait for relocating shards to complete (default: true for drain)
  --timeout      Timeout for waiting in seconds (default: 1800)
  --help         Show this help
EOF
}

ENDPOINT=""
ZONE=""
UNDRAIN=false
WAIT=true
TIMEOUT=1800

while [[ $# -gt 0 ]]; do
  case $1 in
    --endpoint)  ENDPOINT="$2"; shift 2 ;;
    --zone)      ZONE="$2"; shift 2 ;;
    --undrain)   UNDRAIN=true; shift ;;
    --wait)      WAIT="$2"; shift 2 ;;
    --timeout)   TIMEOUT="$2"; shift 2 ;;
    --help)      usage; exit 0 ;;
    *)           echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$ENDPOINT" || -z "$ZONE" ]]; then
  echo "ERROR: --endpoint and --zone are required"
  usage
  exit 1
fi

if [[ "$UNDRAIN" == true ]]; then
  echo "Undraining zone: ${ZONE}..."
  curl -sf -X PUT "${ENDPOINT}/_cluster/settings" \
    -H "Content-Type: application/json" \
    -d '{
      "transient": {
        "cluster.routing.allocation.exclude.zone": null
      }
    }' | jq .
  echo "Zone ${ZONE} undrained."
else
  echo "Draining zone: ${ZONE}..."
  curl -sf -X PUT "${ENDPOINT}/_cluster/settings" \
    -H "Content-Type: application/json" \
    -d "{
      \"transient\": {
        \"cluster.routing.allocation.exclude.zone\": \"${ZONE}\"
      }
    }" | jq .

  if [[ "$WAIT" == true ]]; then
    echo "Waiting for shard relocation to complete (timeout: ${TIMEOUT}s)..."
    START_TIME=$(date +%s)
    while true; do
      ELAPSED=$(( $(date +%s) - START_TIME ))
      if [[ $ELAPSED -ge $TIMEOUT ]]; then
        echo "ERROR: Timeout after ${TIMEOUT}s waiting for shard relocation"
        exit 1
      fi

      RELOCATING=$(curl -sf "${ENDPOINT}/_cluster/health" | jq -r '.relocating_shards')
      echo "[${ELAPSED}s] relocating_shards=${RELOCATING}"

      if [[ "$RELOCATING" == "0" ]]; then
        echo "All shards relocated from zone ${ZONE}."
        break
      fi

      sleep 10
    done
  fi
fi
