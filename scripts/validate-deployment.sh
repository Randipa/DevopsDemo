#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://localhost:3000}"
MAX_RETRIES=10
SLEEP_SECONDS=3

echo "Validating deployment at ${BASE_URL}"

for i in $(seq 1 "${MAX_RETRIES}"); do
  if curl -sf "${BASE_URL}/health" > /dev/null; then
    echo "Health check passed on attempt ${i}"
    curl -s "${BASE_URL}/health" | python3 -m json.tool
    curl -s "${BASE_URL}/api/info" | python3 -m json.tool
    exit 0
  fi
  echo "Attempt ${i}/${MAX_RETRIES} failed. Retrying in ${SLEEP_SECONDS}s..."
  sleep "${SLEEP_SECONDS}"
done

echo "Deployment validation failed after ${MAX_RETRIES} attempts."
exit 1
