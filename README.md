# DevOps Demo — Industry Pipeline

**GitHub → GitHub Actions → Amazon ECR → ECS Fargate → ALB (4 environments)**

| Layer | Technology |
|-------|------------|
| App | Node.js + Express + `/metrics` |
| CI/CD | GitHub Actions (AWS CD) + Jenkins (local practice) |
| Container | Docker |
| AWS deploy | ECS Fargate + ECR + ALB × 4 envs |
| Logs | CloudWatch (`/ecs/devops-demo-*`) |

**Sinhala guide:** `../Note/industry.html`  
**Bitbucket Pipelines (company interview):** `docs/BITBUCKET-PIPELINE-GUIDE.md`

---

## CI/CD platforms (same AWS backend)

| Platform | Config file | Use case |
|----------|-------------|----------|
| **GitHub Actions** | `.github/workflows/*.yml` | Current repo (Randipa/DevopsDemo) |
| **Bitbucket Pipelines** | `bitbucket-pipelines.yml` | Company uses Bitbucket — see guide |

Both deploy to the same 4 ECS environments (Dev auto, Test/Stage/Prod manual).

---

## CD Environments

| Environment | Trigger | GitHub Workflow | Stack name |
|-------------|---------|-----------------|------------|
| **Development** | Auto — push to `main` | Deploy to Development | `devops-ecs-dev` |
| **Testing** | Manual button | Promote to Environment → testing | `devops-ecs-test` |
| **Stage** | Manual button | Promote to Environment → stage | `devops-ecs-stage` |
| **Production** | Manual button | Promote to Environment → production | `devops-ecs-prod` |

### One-time GitHub setup

1. **Settings → Secrets** → `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
2. **Settings → Environments** → create: `development`, `testing`, `stage`, `production`
3. **Actions → Setup All Environments (Infra)** → Run workflow (creates 4 AWS stacks)

### Daily flow

```
1. Code change → git push main
2. "Deploy to Development" runs automatically
3. Open Summary tab → copy Development URL → test /health and /api/info
4. When ready → Actions → "Promote to Environment (Manual)"
   → Run workflow → choose testing | stage | production
   → image_tag: dev-latest (default)
5. Each run prints that environment's URL in the job summary
```

Verify environment name in API response:

```bash
curl http://<ALB-DNS>/api/info
# "deployEnv": "development" | "testing" | "stage" | "production"
```

---

## Quick Start (Local)

```bash
npm install && npm test && npm start
```

## Jenkins (local — optional)

```bash
cd jenkins && docker compose -f docker-compose.jenkins.yml up -d --build
```

## Monitoring (local — optional)

```bash
./scripts/start-monitoring.sh
# Grafana: http://localhost:3001  (admin/admin)
```

## CLI deploy (optional)

```bash
./scripts/deploy-ecs-env.sh dev          # build + deploy development
IMAGE_TAG=dev-latest ./scripts/deploy-ecs-env.sh test   # promote to testing
./scripts/delete-ecs-env.sh all          # delete all stacks
```

---

## Workflows

| File | Purpose |
|------|---------|
| `deploy-development.yml` | Auto CD on push to main |
| `promote-environment.yml` | Manual CD to test/stage/prod |
| `setup-aws-cloud.yml` | Create all 4 infra stacks |
| `delete-aws-cloud.yml` | Delete all stacks |
| `ecs-deploy-reusable.yml` | Shared deploy logic |
| `ci.yml` | PR tests only |

---

## API Endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | Health check — includes `deployEnv` |
| `GET /api/info` | App info — shows which environment |
| `GET /metrics` | Prometheus metrics |
| `GET /api/echo?message=hi` | Demo API |
