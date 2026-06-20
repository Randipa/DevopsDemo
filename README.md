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

---

## CD Environments

| Environment | Trigger | GitHub Workflow | Stack name |
|-------------|---------|-----------------|------------|
| **Development** | Auto — push to `main` | Deploy to Development and Stage (job 1) | `devops-ecs-dev` |
| **Stage** | Auto — push to `main` (after Dev) | Deploy to Development and Stage (job 2) | `devops-ecs-stage` |
| **Testing** | Manual button | Promote to Environment → testing | `devops-ecs-test` |
| **Production** | Manual button | Promote to Environment → production | `devops-ecs-prod` |
| **Jenkins** | Auto — poll GitHub every 2 min | Local pipeline (build/test/Docker) | localhost:8080 |

### One-time GitHub setup

1. **Settings → Secrets** → `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
2. **Settings → Environments** → create: `development`, `testing`, `stage`, `production`
3. **Actions → Setup All Environments (Infra)** → Run workflow (creates 4 AWS stacks)

### Daily flow

```
1. Code change → git push main
2. GitHub Actions auto:
   - Deploy Development (build + test + ECR push)
   - Deploy Stage (same image, no rebuild)
3. Jenkins auto (~2 min): build, test, Docker on local PC
4. Summary tab → Development URL + Stage URL → test /api/info
5. Manual when ready → Promote → testing | production
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

## Jenkins (local — auto on push)

```bash
cd jenkins && docker compose -f docker-compose.jenkins.yml up -d --build
```

Create Pipeline job once: **SCM Git** → repo URL → Script Path: `Jenkinsfile`

After `git push main`, Jenkins polls GitHub every **2 minutes** and runs automatically (`pollSCM` in Jenkinsfile).

Blue Ocean: http://localhost:8080/blue

**Note:** Jenkins runs on your PC (build/test). AWS deploy is GitHub Actions only.

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
| `deploy-development.yml` | Auto CD: Development + Stage on push to main |
| `promote-environment.yml` | Manual CD to testing / production |
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
