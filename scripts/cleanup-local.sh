#!/usr/bin/env bash
# Stop and remove local DevOps demo Docker resources
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Stopping main app compose..."
(cd "${ROOT}" && docker compose down 2>/dev/null) || true

echo "==> Removing leftover devops containers..."
for name in devops-demo-app ci-validate; do
  docker rm -f "${name}" 2>/dev/null || true
done

echo "==> Removing devops Docker networks..."
docker network rm devopsdemo_default 2>/dev/null || true

echo "==> Pruning unused devops images (optional)..."
docker image rm devops-demo:latest 2>/dev/null || true
docker image prune -f 2>/dev/null || true

echo ""
echo "Local cleanup done."
echo "Still running containers:"
docker ps --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null || true
echo ""
echo "AWS stack: GitHub Actions → Delete AWS Cloud Stack (or ./scripts/delete-ecs-env.sh)"
