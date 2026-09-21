# NexCell DevOps Assessment

## ABOUT YOU

**Name / Time spent (minutes): honest, not scored**

Rajesh B T / 180 minutes.

**AI tools used, and one thing you changed or corrected from their output:**

OpenAI ChatGPT/Codex. I corrected the generated Compose design by disabling the API health check inherited by the worker and one-shot migration containers.

## BUILD AND RUN

**What I delivered, and how to run and verify it (commands):**

A production-oriented FastAPI service with liveness/readiness endpoints, PostgreSQL migration, Redis worker, health-gated Compose stack, smoke test and GitHub Actions CI/OIDC deployment demonstration.

```bash
cp .env.example .env
# Replace the placeholder PostgreSQL password in both relevant .env values.
docker compose up --build -d
docker compose ps -a
./smoke_test.sh
docker compose down -v  # Removes local containers and data volumes.
```

**Top 3 problems fixed in the starting Dockerfile, and why each matters:**

1. Removed embedded secrets and excluded `.env`, preventing credentials from entering image layers. 2. Pinned the slim Python base and Python packages, making builds repeatable. 3. Created an unprivileged UID/GID and run Uvicorn without reload, reducing container privilege and production instability.

**How dependencies are kept reproducible, and how migrations run safely on deploy:**

The Python image and every package in `requirements.txt` use exact versions. Compose runs the idempotent migration only after PostgreSQL/Redis are healthy, and API/worker start only after migration exits successfully; production uses the same pattern as a required one-off ECS task.

## AWS DESIGN

**Target architecture in 3 to 5 lines (link your diagram if you made one):**

CloudFront fronts an internet-facing ALB across two public subnets. The ALB routes to API tasks on ECS Fargate in private subnets, with separate worker and migration tasks. PostgreSQL and Redis ElastiCache remain in isolated private data subnets. Secrets Manager supplies runtime credentials, while CloudWatch collects logs, metrics and alarms.

**Networking and security: VPC and subnets, IAM, secrets, how CI authenticates to AWS:**

The multi-AZ VPC exposes only CloudFront/ALB; security groups allow ALB-to-API and task-to-database/cache traffic only. Least-privilege task roles access Secrets Manager, and GitHub assumes a restricted deployment role through OIDC instead of storing AWS access keys.

**Deploying without downtime, and how you would roll back:**

Run the migration task first, then use ECS rolling deployment with ALB `/ready` checks, 100% minimum healthy and 200% maximum capacity. On failure, stop the rollout and redeploy the previous task-definition revision and immutable image digest.

**Monitoring: the three alarms you would add first, with thresholds:**

1. ALB/API error rate above 1% for five minutes. 2. ALB target-response p95 latency above one second for ten minutes. 3. Redis queue backlog above 100 jobs or oldest-job age above five minutes; each alarm pages the on-call route through SNS.

## COST

**Top 3 savings: change, estimated £/month, and the risk each introduces:**

1. Schedule/right-size staging: £260 → £78, saving £182; risk is unavailable off-hours testing. 2. Right-size and autoscale Fargate: £505 → £190, saving £315; risk is reduced spike headroom. 3. Right-size Redis: £150 → £55, saving £95; risk is lower memory/failover capacity.

**New projected AWS total and cost per customer (show the sum):**

£78 + £190 + £55 + £500 retained costs = **£823/month**. £823 ÷ 20 customers = **£41.15 per customer/month**.

**One cost you would deliberately not cut, and how you would catch a cost spike early:**

I would retain Multi-AZ database resilience because losing availability or data costs more than the saving. AWS Budgets at 80%/100% plus Cost Anomaly Detection alerts would identify an unexpected increase early.

## JUDGEMENT

**How this scales to 100 customers:**

Scale stateless API tasks on ALB request count/CPU and workers on queue depth/age, while CloudFront absorbs cacheable traffic; then scale ElastiCache and RDS vertically/read replicas based on measured saturation.

**The biggest production risk in the current setup, and your first fix:**

Manual database migrations are the biggest immediate production risk because they have already caused deployment incidents. My first fix is an automated migration task that must succeed before the ECS service is updated.

**One thing kept intentionally simple, and what you would do with 3 more hours:**

The migration is deliberately a small idempotent schema operation. With three more hours I would add versioned migrations, locking, compatibility checks and a tested rollback path around the dedicated ECS migration task.
