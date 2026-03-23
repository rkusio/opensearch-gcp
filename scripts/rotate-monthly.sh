#!/bin/bash
# Monthly image rotation orchestrator
# 1. Builds new Packer image
# 2. Updates Terraform with new image
# 3. Runs rolling update for each MIG role
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Perform monthly image rotation: build new image and roll it out zone-by-zone.

Options:
  --project        GCP project ID (required)
  --environment    Environment to rotate: dev-1, uat-1, prod, etc. (required)
  --endpoint       OpenSearch endpoint URL (required)
  --region         GCP region (default: europe-central2)
  --zones          Comma-separated zones (default: europe-central2-a,europe-central2-b,europe-central2-c)
  --os-version     OpenSearch version (default: 3.5.0)
  --skip-build     Skip image build (use existing latest image)
  --dry-run        Show what would be done without executing
  --help           Show this help
EOF
}

PROJECT=""
ENVIRONMENT=""
ENDPOINT=""
REGION="europe-central2"
ZONES="europe-central2-a,europe-central2-b,europe-central2-c"
OS_VERSION="3.5.0"
SKIP_BUILD=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --project)       PROJECT="$2"; shift 2 ;;
    --environment)   ENVIRONMENT="$2"; shift 2 ;;
    --endpoint)      ENDPOINT="$2"; shift 2 ;;
    --region)        REGION="$2"; shift 2 ;;
    --zones)         ZONES="$2"; shift 2 ;;
    --os-version)    OS_VERSION="$2"; shift 2 ;;
    --skip-build)    SKIP_BUILD=true; shift ;;
    --dry-run)       DRY_RUN=true; shift ;;
    --help)          usage; exit 0 ;;
    *)               echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$PROJECT" || -z "$ENVIRONMENT" || -z "$ENDPOINT" ]]; then
  echo "ERROR: --project, --environment, and --endpoint are required"
  usage
  exit 1
fi

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

TF_DIR="${SCRIPT_DIR}/../terraform/environments/${ENVIRONMENT}"

# ---------------------------------------------------------------------------
# Step 1: Build new image (optional)
# ---------------------------------------------------------------------------
if [[ "$SKIP_BUILD" == false ]]; then
  log "=== Step 1: Building new Packer image ==="
  "${SCRIPT_DIR}/build-image.sh" \
    --project-id "${PROJECT}" \
    --os-version "${OS_VERSION}"
fi

# ---------------------------------------------------------------------------
# Step 2: Get latest image name
# ---------------------------------------------------------------------------
log "=== Step 2: Finding latest image ==="
IMAGE_NAME=$(gcloud compute images list \
  --project="${PROJECT}" \
  --filter="family=opensearch" \
  --sort-by="~creationTimestamp" \
  --limit=1 \
  --format="value(name)")

if [[ -z "$IMAGE_NAME" ]]; then
  log "ERROR: No opensearch image found"
  exit 1
fi
log "Latest image: ${IMAGE_NAME}"

# ---------------------------------------------------------------------------
# Step 3: Update Terraform
# ---------------------------------------------------------------------------
log "=== Step 3: Updating Terraform with new image ==="
cd "${TF_DIR}"

if [[ "$DRY_RUN" == false ]]; then
  terraform plan -var="opensearch_image=${IMAGE_NAME}" -out=rotation.tfplan
  log "Review the plan above. Applying in 10 seconds (Ctrl+C to abort)..."
  sleep 10
  terraform apply rotation.tfplan
  rm -f rotation.tfplan
else
  log "[DRY-RUN] terraform apply -var='opensearch_image=${IMAGE_NAME}'"
fi

# ---------------------------------------------------------------------------
# Step 4: Rolling update for MIG roles
# ---------------------------------------------------------------------------
log "=== Step 4: Rolling update ==="

CLUSTER_NAME="opensearch-${ENVIRONMENT}"
DRY_RUN_FLAG=""
if [[ "$DRY_RUN" == true ]]; then
  DRY_RUN_FLAG="--dry-run"
fi

# Update each MIG role that exists
for ROLE in data data-hot coordinator; do
  # Check if this role has MIGs
  MIG_CHECK=$(gcloud compute instance-groups managed list \
    --project="${PROJECT}" \
    --filter="name~${CLUSTER_NAME}-${ROLE}" \
    --format="value(name)" 2>/dev/null | head -1)

  if [[ -n "$MIG_CHECK" ]]; then
    TEMPLATE=$(gcloud compute instance-templates list \
      --project="${PROJECT}" \
      --filter="name~${CLUSTER_NAME}-${ROLE}" \
      --sort-by="~creationTimestamp" \
      --limit=1 \
      --format="value(selfLink)")

    log "Updating role: ${ROLE} with template: ${TEMPLATE}"
    "${SCRIPT_DIR}/rolling-update.sh" \
      --project "${PROJECT}" \
      --cluster "${CLUSTER_NAME}" \
      --endpoint "${ENDPOINT}" \
      --region "${REGION}" \
      --zones "${ZONES}" \
      --role "${ROLE}" \
      --new-template "${TEMPLATE}" \
      ${DRY_RUN_FLAG}
  else
    log "No MIGs found for role ${ROLE}, skipping."
  fi
done

log ""
log "=== Monthly Rotation Complete ==="
