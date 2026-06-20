# Bitbucket Pipeline — Setup & Interview Guide

Use this guide to practice **"Experience in build CI/CD workflow using Bitbucket Pipeline"** with the same ECS multi-env flow as GitHub Actions.

---

## What you built

| Environment | Bitbucket trigger | Pipeline |
|-------------|-------------------|----------|
| **Development** | Push to `main` (auto) | `branches: main` |
| **Testing** | Manual custom pipeline | `promote-to-testing` |
| **Stage** | Manual custom pipeline | `promote-to-stage` |
| **Production** | Manual custom pipeline | `promote-to-production` |

**Config file:** `bitbucket-pipelines.yml` (root)  
**Deploy script:** `scripts/bitbucket-deploy-ecs.sh`

---

## Step 1 — Create Bitbucket repo

1. [bitbucket.org](https://bitbucket.org) → **Create repository**
2. Name: `devops-demo` (or import from GitHub)

**Import from GitHub:**
```bash
cd DevopsDemo
git remote add bitbucket https://bitbucket.org/<your-user>/devops-demo.git
git push bitbucket main
```

---

## Step 2 — Enable Pipelines

**Repository settings → Pipelines → Settings → Enable Pipelines**

---

## Step 3 — Repository variables (secrets)

**Repository settings → Pipelines → Repository variables**

| Variable | Secured | Value |
|----------|---------|-------|
| `AWS_ACCESS_KEY_ID` | ✅ Yes | IAM access key |
| `AWS_SECRET_ACCESS_KEY` | ✅ Yes | IAM secret key |
| `AWS_REGION` | No | `eu-north-1` |
| `PROMOTE_IMAGE_TAG` | No | `dev-latest` (optional) |

Same IAM user/permissions as GitHub: `docs/IAM-GITHUB-PERMISSIONS.md`

---

## Step 4 — Deployment environments

**Repository settings → Pipelines → Deployments**

Create (same names as in `bitbucket-pipelines.yml`):

| Name | Type |
|------|------|
| `development` | Test |
| `testing` | Test |
| `stage` | Staging |
| `production` | Production |

Optional: add **Deployment restrictions** on `production` (manual approval).

---

## Step 5 — First run

### Infra (one time)
**Pipelines → Run pipeline → Branch: main → Custom: `setup-all-environments` → Run**

### Development (auto CD)
```bash
git push bitbucket main
```
Pipeline runs: CI → Deploy to Development

### Testing / Stage / Production (manual)
**Pipelines → Run pipeline → Custom pipeline:**
- `promote-to-testing`
- `promote-to-stage`
- `promote-to-production`

Log output shows URLs:
```
Environment : testing
Health URL  : http://devops-demo-test-alb-xxx/health
Info URL    : http://devops-demo-test-alb-xxx/api/info
```

Verify: `"deployEnv": "testing"` in `/api/info`

---

## GitHub Actions vs Bitbucket Pipelines (interview answer)

| | GitHub Actions | Bitbucket Pipelines |
|---|----------------|---------------------|
| Config | `.github/workflows/*.yml` | `bitbucket-pipelines.yml` |
| Secrets | GitHub Secrets | Repository variables |
| Environments | Settings → Environments | Settings → Deployments |
| Auto dev deploy | `on: push: main` | `pipelines: branches: main` |
| Manual promote | `workflow_dispatch` | `pipelines: custom:` |
| Manual run UI | Actions → Run workflow | Pipelines → Run pipeline |

**Same architecture:** Bitbucket → AWS ECR → ECS Fargate → ALB (4 envs)

---

## Interview talking points

1. Built **multi-stage CD pipeline** with Bitbucket Pipelines
2. **Development** auto-deploys on merge to `main` after CI (test + lint)
3. **Testing, Stage, Production** use **custom pipelines** (manual promotion)
4. Shared Docker image in ECR (`dev-latest`) promoted across environments
5. Infrastructure as Code with **CloudFormation** (VPC, ALB, ECS per env)
6. Deployment tracking via Bitbucket **Deployments** dashboard per environment

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Pipelines not running | Enable Pipelines in repo settings |
| AWS auth fail | Check secured repository variables |
| Docker build fail | Ensure `services: docker` in deploy steps |
| ResourceExistenceCheck | Delete old `devops-ecs-simple` stack in AWS |
| Custom pipeline missing | Push `bitbucket-pipelines.yml` to repo |

---

## Files in this project

```
bitbucket-pipelines.yml          # Bitbucket CI/CD config
scripts/bitbucket-deploy-ecs.sh # Shared deploy logic
.github/workflows/               # GitHub version (same AWS backend)
infra/cloudformation-ecs-simple.yaml
```

You can demo **either** GitHub Actions **or** Bitbucket Pipelines — AWS side is identical.
