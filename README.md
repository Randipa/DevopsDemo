# DevOps Demo — Full Pipeline

Real-world flow: **GitHub → Jenkins → Build/Test → AWS Dev (K8s + ALB) → Grafana**

| Layer | Technology |
|-------|------------|
| App | Node.js + Express + Prometheus metrics |
| CI/CD | Jenkins Pipeline + GitHub Actions |
| Container | Docker multi-stage build |
| Orchestration | Kubernetes (k3s on AWS EC2) |
| Load balancing | AWS ALB + K8s Service (2 replicas) |
| Firewall | Security Groups + Network ACL |
| Monitoring | Prometheus + Grafana |
| Connectivity | telnet / nc / curl validation scripts |

**Full setup guide:** [docs/PIPELINE-GUIDE.md](docs/PIPELINE-GUIDE.md)

---

## Quick Start (Local)

```bash
npm install && npm test && npm start
# http://localhost:3000/health
# http://localhost:3000/metrics
```

## Docker

```bash
docker compose up -d --build
./scripts/validate-deployment.sh http://localhost:3000
```

## Jenkins

```bash
cd jenkins && docker compose -f docker-compose.jenkins.yml up -d
# http://localhost:8080 — create Pipeline job from GitHub + Jenkinsfile
```

## Grafana (local)

```bash
docker compose up -d
cd monitoring && docker compose -f docker-compose.monitoring.yml up -d
# Grafana: http://localhost:3001 (admin/admin)
```

## AWS Dev Environment

```bash
export KEY_NAME=your-key ADMIN_CIDR=$(curl -s ifconfig.me)/32
./scripts/deploy-dev-env.sh
./scripts/deploy-k8s.sh
./scripts/test-connectivity.sh <ALB_DNS>
```

---

## Project Structure

```
├── .github/workflows/ci.yml     # GitHub CI
├── Jenkinsfile                  # Jenkins pipeline (build, test, deploy)
├── k8s/                         # Kubernetes manifests
├── monitoring/                  # Prometheus + Grafana
├── infra/
│   ├── cloudformation-ec2.yaml
│   └── cloudformation-dev-env.yaml  # ALB + firewall + k3s
├── jenkins/docker-compose.jenkins.yml
├── scripts/
│   ├── deploy-dev-env.sh
│   ├── deploy-k8s.sh
│   ├── test-connectivity.sh     # firewall / telnet checks
│   └── validate-deployment.sh
└── docs/
    ├── PIPELINE-GUIDE.md
    └── DEPLOYMENT-RUNBOOK.md
```

---

## API Endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | Health check (ALB + K8s probes) |
| `GET /metrics` | Prometheus metrics (Grafana) |
| `GET /api/info` | App version info |
| `GET /api/echo?message=hi` | Demo API |
