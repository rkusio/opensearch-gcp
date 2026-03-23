#!/bin/bash
# Wait for OpenSearch cluster to reach green health status
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") --endpoint <url> [OPTIONS]

Wait for an OpenSearch cluster to reach green health status.

Options:
  --endpoint       OpenSearch endpoint URL (required, e.g. http://10.0.0.1:9200)
  --timeout        Timeout in seconds (default: 600)
  --interval       Poll interval in seconds (default: 15)
  --help           Show this help
EOF
}

ENDPOINT=""
TIMEOUT=600
INTERVAL=15

while [[ $# -gt 0 ]]; do
  case $1 in
    --endpoint)  ENDPOINT="$2"; shift 2 ;;
    --timeout)   TIMEOUT="$2"; shift 2 ;;
    --interval)  INTERVAL="$2"; shift 2 ;;
    --help)      usage; exit 0 ;;
    *)           echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$ENDPOINT" ]]; then
  echo "ERROR: --endpoint is required"
  usage
  exit 1
fi

echo "Waiting for cluster at ${ENDPOINT} to reach green status (timeout: ${TIMEOUT}s)..."

START_TIME=$(date +%s)

while true; do
  ELAPSED=$(( $(date +%s) - START_TIME ))
  if [[ $ELAPSED -ge $TIMEOUT ]]; then
    echo "ERROR: Timeout after ${TIMEOUT}s waiting for green status"
    exit 1
  fi

  HEALTH=$(curl -sf "${ENDPOINT}/_cluster/health" 2>/dev/null || echo '{}')
  STATUS=$(echo "$HEALTH" | jq -r '.status // "unknown"')
  RELOCATING=$(echo "$HEALTH" | jq -r '.relocating_shards // -1')
  NODES=$(echo "$HEALTH" | jq -r '.number_of_nodes // 0')

  echo "[${ELAPSED}s] status=${STATUS} relocating_shards=${RELOCATING} nodes=${NODES}"

  if [[ "$STATUS" == "green" && "$RELOCATING" == "0" ]]; then
    echo "Cluster is green with 0 relocating shards."
    exit 0
  fi

  sleep "$INTERVAL"
done
