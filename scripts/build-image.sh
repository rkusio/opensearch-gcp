#!/bin/bash
# Build OpenSearch Packer image
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKER_DIR="${SCRIPT_DIR}/../packer"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Build a new OpenSearch image using Packer.

Options:
  --project-id       GCP project ID (required)
  --zone             Build zone (default: europe-central2-a)
  --os-version       OpenSearch version (default: 2.17.0)
  --dp-version       Data Prepper version (default: 2.9.0)
  --var-file         Path to variables file (default: packer/variables.pkrvars.hcl)
  --help             Show this help
EOF
}

PROJECT_ID=""
ZONE="europe-central2-a"
OS_VERSION="2.17.0"
DP_VERSION="2.9.0"
VAR_FILE="${PACKER_DIR}/variables.pkrvars.hcl"

while [[ $# -gt 0 ]]; do
  case $1 in
    --project-id)   PROJECT_ID="$2"; shift 2 ;;
    --zone)         ZONE="$2"; shift 2 ;;
    --os-version)   OS_VERSION="$2"; shift 2 ;;
    --dp-version)   DP_VERSION="$2"; shift 2 ;;
    --var-file)     VAR_FILE="$2"; shift 2 ;;
    --help)         usage; exit 0 ;;
    *)              echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$PROJECT_ID" ]]; then
  echo "ERROR: --project-id is required"
  usage
  exit 1
fi

echo "=== Building OpenSearch image ==="
echo "Project:      ${PROJECT_ID}"
echo "Zone:         ${ZONE}"
echo "OS Version:   ${OS_VERSION}"
echo "DP Version:   ${DP_VERSION}"
echo ""

cd "${PACKER_DIR}"

packer init opensearch.pkr.hcl

packer build \
  -var "project_id=${PROJECT_ID}" \
  -var "zone=${ZONE}" \
  -var "opensearch_version=${OS_VERSION}" \
  -var "data_prepper_version=${DP_VERSION}" \
  -var-file="${VAR_FILE}" \
  opensearch.pkr.hcl

echo "=== Image build complete ==="
echo "List images with: gcloud compute images list --project=${PROJECT_ID} --filter='family=opensearch' --sort-by=~creationTimestamp"
