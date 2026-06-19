#!/usr/bin/env bash
set -euo pipefail

HOST="${1:?Host required (IP or DNS)}"
TIMEOUT="${2:-5}"

PORTS=(22 80 443 3000 30080 6443 8080 9090 3001)
declare -A PORT_LABEL=(
  [22]="SSH"
  [80]="HTTP"
  [443]="HTTPS"
  [3000]="App direct"
  [30080]="K8s NodePort / ALB backend"
  [6443]="Kubernetes API"
  [8080]="Jenkins"
  [9090]="Prometheus"
  [3001]="Grafana"
)

echo "=== Firewall / connectivity test: ${HOST} ==="
echo ""

check_port() {
  local port="$1"
  local label="${PORT_LABEL[$port]:-unknown}"

  if command -v nc >/dev/null 2>&1; then
    if nc -z -w "${TIMEOUT}" "${HOST}" "${port}" 2>/dev/null; then
      printf "  [OPEN]   %-5s %s (nc)\n" "${port}" "${label}"
      return 0
    fi
    printf "  [CLOSED] %-5s %s (nc)\n" "${port}" "${label}"
    return 1
  fi

  if command -v telnet >/dev/null 2>&1; then
    if timeout "${TIMEOUT}" telnet "${HOST}" "${port}" </dev/null 2>&1 | grep -qi "Connected"; then
      printf "  [OPEN]   %-5s %s (telnet)\n" "${port}" "${label}"
      return 0
    fi
    printf "  [CLOSED] %-5s %s (telnet)\n" "${port}" "${label}"
    return 1
  fi

  if timeout "${TIMEOUT}" bash -c "echo >/dev/tcp/${HOST}/${port}" 2>/dev/null; then
    printf "  [OPEN]   %-5s %s (/dev/tcp)\n" "${port}" "${label}"
    return 0
  fi

  printf "  [CLOSED] %-5s %s (/dev/tcp)\n" "${port}" "${label}"
  return 1
}

for port in "${PORTS[@]}"; do
  check_port "${port}" || true
done

echo ""
echo "=== HTTP health checks ==="
for url in \
  "http://${HOST}/health" \
  "http://${HOST}:3000/health" \
  "http://${HOST}:30080/health"; do
  if curl -sf --max-time "${TIMEOUT}" "${url}" >/dev/null 2>&1; then
    echo "  [OK] ${url}"
  else
    echo "  [FAIL] ${url}"
  fi
done

echo ""
echo "Done."
