#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}/monitoring"

echo "==> Starting Prometheus + Grafana..."
docker compose -f docker-compose.monitoring.yml up -d

echo "==> Starting app on monitoring network..."
docker stop devops-demo-app 2>/dev/null || true
docker rm devops-demo-app 2>/dev/null || true
docker compose -f docker-compose.app.yml up -d --build

echo "==> Waiting for metrics endpoint..."
for i in $(seq 1 15); do
  if curl -sf http://localhost:3000/metrics >/dev/null; then
    break
  fi
  sleep 2
done

echo "==> Checking Prometheus targets..."
sleep 3
curl -sf "http://localhost:9090/api/v1/targets" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for t in data['data']['activeTargets']:
    job = t['labels'].get('job', '?')
    print(f\"  {job}: {t['health']}\")
"

echo ""
echo "Monitoring stack ready:"
echo "  App metrics:  http://localhost:3000/metrics"
echo "  Prometheus:   http://localhost:9090"
echo "  Grafana:      http://localhost:3001  (admin / admin)"
echo "  Dashboard:    http://localhost:3001/d/devops-demo-overview/devops-demo-overview"
