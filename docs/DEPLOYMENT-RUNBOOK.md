# Deployment Runbook — DevOps Demo

## Purpose
Deploy and validate the Node.js demo application in demo, test, and customer-like environments.

## Prerequisites
- Linux host with Docker and Docker Compose
- Node.js 18+ (for local development only)
- AWS CLI configured (for EC2 deployment)
- Jenkins agent with Docker access (for CI/CD)

## Standard Deployment (Docker Compose)

```bash
git clone <repo-url>
cd DevopsDemo
cp .env.example .env
docker compose up -d --build
./scripts/validate-deployment.sh http://localhost:3000
```

## Rollback Procedure

```bash
docker compose down
docker compose up -d
./scripts/validate-deployment.sh http://localhost:3000
```

## Known Issues
| Issue | Symptom | Resolution |
|-------|---------|------------|
| Port conflict | `bind: address already in use` | Change `HOST_PORT` in `.env` |
| Health check fails | Container restarts | Check logs: `docker logs devops-demo-app` |

## Escalation
1. Check container logs and `/health` endpoint
2. Notify Engineering if application error
3. Notify Infrastructure if host/network issue
