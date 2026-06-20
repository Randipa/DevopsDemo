# DevOps Demo — Industry Pipeline

**GitHub → GitHub Actions → Amazon ECR → ECS Fargate → ALB**

| Layer | Technology |
|-------|------------|
| App | Node.js + Express + `/metrics` |
| CI/CD | GitHub Actions (AWS deploy) + Jenkins (local practice) |
| Container | Docker |
| AWS deploy | ECS Fargate + ECR + ALB |
| Logs | CloudWatch (`/ecs/devops-demo`) |

**Sinhala guide:** `../Note/industry.html` (open with `cd ../Note && python3 -m http.server 5500`)

---

## Quick Start (Local)

```bash
npm install && npm test && npm start
# http://localhost:3000/health
# http://localhost:3000/metrics
```

## Docker (local)

```bash
docker compose up -d --build
./scripts/validate-deployment.sh http://localhost:3000
```

## Jenkins (local CI — optional)

```bash
cd jenkins && docker compose -f docker-compose.jenkins.yml up -d --build
# UI: http://localhost:8080
# Blue Ocean: http://localhost:8080/blue
```

Create job: **New Item → Pipeline → SCM Git →** repo URL → Script Path: `Jenkinsfile` → **Build Now**

AWS deploy stays on **GitHub Actions** (push to `main`). Jenkins runs build, test, and Docker locally.

## AWS Deploy (automatic)

1. GitHub repo → **Settings → Secrets** → `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
2. **Actions → Setup AWS Cloud (ECS)** → Run workflow (one-time infra)
3. Push to `main` → **Deploy to AWS ECS** runs automatically

Or from CLI (with AWS credentials):

```bash
./scripts/deploy-ecs-env.sh
```

Delete AWS stack:

```bash
./scripts/delete-ecs-env.sh
# or GitHub Actions → Delete AWS Cloud Stack
```

---

## Project Structure

```
├── .github/workflows/
│   ├── deploy-ecs.yml          # Auto deploy on push to main
│   ├── setup-aws-cloud.yml     # One-time ECS + ALB setup
│   └── delete-aws-cloud.yml    # Tear down AWS stack
├── Jenkinsfile                 # Local Jenkins pipeline (no k8s deploy)
├── jenkins/docker-compose.jenkins.yml
├── infra/cloudformation-ecs-simple.yaml
├── ecs/task-definition.json
├── scripts/
│   ├── deploy-ecs-env.sh
│   ├── delete-ecs-env.sh
│   ├── validate-deployment.sh
│   └── cleanup-local.sh
├── docs/IAM-GITHUB-PERMISSIONS.md
└── src/server.js
```

---

## API Endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | Health check (ALB target group) |
| `GET /metrics` | Prometheus-format metrics |
| `GET /api/info` | App version info |
| `GET /api/echo?message=hi` | Demo API |
