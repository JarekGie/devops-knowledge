---
title: maspex-context
domain: client-work
use_case: project-context
llm_target: any
aws_account_id: "969209893152"
aws_profile: maspex-cli
aws_mgm_account_id: 864277686382
aws_mgm_profile: mako-dc
repozytorium: ~/projekty/mako/aws-projects/infra-maspex
region: eu-west-1
environment: uat
tags:
  - maspex
  - aws
  - terraform
  - ecs
  - fargate
  - mako
created: 2026-05-01
updated: 2026-05-01
---

# maspex — Kapsel (aplikacja konkursowa)

#aws #terraform #ecs #fargate #mako #maspex

**Data:** 2026-05-01
**Projekt:** Platforma konkursowa Kapsel (Maspex) — Next.js API + admin panel + bot, CloudFront → ALB → ECS Fargate, Redis ElastiCache, Supabase/PostgREST jako downstream.
**Account ID:** `969209893152`
**AWS profile:** `maspex-cli`
**IAM user (CLI):** `makolab-ci` (`AIDA6DKLJKEQIJ6W5OVZ4`)
**Region główny:** `eu-west-1` (CloudFront certy też w `us-east-1`)

---

## Repozytorium kodu

- lokalna ścieżka (infra): `~/projekty/mako/aws-projects/infra-maspex/`
- lokalna ścieżka (app): `~/projekty/mako/next-core-app/`
- remote (infra): `git@gitlab.makolab.net:admin-makolab/dc/aws-projects/infra-maspex-kapsel.git`
- aktywny branch: `main`
- IaC: **Terraform** (provider aws ~5.0, aktualnie 5.100.0)

Struktura repo infra:
```
terraform/
  bootstrap/   — S3 state bucket, DynamoDB lock
  envs/        — shared/, uat/, prod/, preprod/
  modules/     — alb, alb-routing, ecs, elasticache, cloudfront, …
```

---

## Środowiska

| Env | Region | Account ID | Status | VPC CIDR |
|-----|--------|------------|--------|----------|
| shared | eu-west-1 | 969209893152 | infrastruktura współdzielona | nieustalone |
| uat | eu-west-1 | 969209893152 | aktywny, 11 tasków running | 10.44.0.0/16 |
| preprod | eu-west-1 | 969209893152 | częściowo — API 0/3 running | 10.44.0.0/16 |
| prod | eu-west-1 | 969209893152 | IaC istnieje, stan live nieustalone | nieustalone |

VPC: `vpc-0df07c64ea8a8b00e` (10.44.0.0/16) — brak Name tagu.

**Terraform state:**

| Env | Bucket | Key | Lock table |
|-----|--------|-----|------------|
| shared | terraform-state-969209893152 | maspex/shared/terraform.tfstate | terraform-locks-969209893152 |
| uat | terraform-state-969209893152 | maspex/uat/terraform.tfstate | terraform-locks-969209893152 |
| prod | terraform-state-969209893152 | maspex/prod/terraform.tfstate | terraform-locks-969209893152 |

Backend: S3 + DynamoDB encrypt=true; wartości przez `-backend-config=backend.hcl`.

---

## Architektura (UAT)

```text
Internet
  │
  ▼
CloudFront E3J76RNXIE2YIG (kapsel.makotest.pl)          — API / frontend
CloudFront E3R9U1TWNUJZ11 (kapsel-admin-uat.makotest.pl) — admin panel
CloudFront E17VHHQJ29MVAB (twojkapsel.pl, preprod/prod)
  │
  ▼
ALB maspex-uat (internet-facing, eu-west-1)
ALB maspex-preprod (internet-facing, eu-west-1)
  │
  ▼
ECS Fargate cluster maspex-uat
  ├── maspex-api         (desired: 9, running: 9) — task-def :53
  ├── maspex-bot         (desired: 1, running: 1) — task-def :8
  └── maspex-admin-panel (desired: 1, running: 1) — task-def :25
  │
  ├── Redis ElastiCache maspex-uat
  │     maspex-uat.zwowz5.0001.euw1.cache.amazonaws.com:6379
  │     cache.t3.medium, Redis 7.1.0, single-node
  │
  └── Supabase/PostgREST (downstream, zewnętrzny)
```

---

## Mikroserwisy / komponenty

| Serwis | Cluster | Desired | Running | Launch Type | Task Def | Status |
|--------|---------|---------|---------|-------------|----------|--------|
| maspex-api | maspex-uat | 9 | 9 | FARGATE | maspex-api:53 | ACTIVE ✓ |
| maspex-bot | maspex-uat | 1 | 1 | FARGATE | maspex-bot:8 | ACTIVE ✓ |
| maspex-admin-panel | maspex-uat | 1 | 1 | FARGATE | maspex-admin-panel:25 | ACTIVE ✓ |
| maspex-preprod-api | maspex-preprod | 3 | 0 | FARGATE | maspex-preprod-api:1 | ACTIVE ⚠ 0/3 |
| maspex-preprod-bot | maspex-preprod | 1 | 1 | FARGATE | maspex-preprod-bot:1 | ACTIVE ✓ |
| maspex-preprod-admin-panel | maspex-preprod | 1 | 1 | FARGATE | maspex-preprod-admin-panel:11 | ACTIVE ✓ |

Brak Service Discovery. Brak EventBridge rules. Brak SQS.

---

## Zasoby kluczowe

| Zasób | Identyfikator |
|---|---|
| ECS cluster UAT | maspex-uat |
| ECS cluster preprod | maspex-preprod |
| ALB UAT | maspex-uat-1361582173.eu-west-1.elb.amazonaws.com |
| ALB preprod | maspex-preprod-1322298306.eu-west-1.elb.amazonaws.com |
| CloudFront API/UAT | E3J76RNXIE2YIG → kapsel.makotest.pl |
| CloudFront admin/UAT | E3R9U1TWNUJZ11 → kapsel-admin-uat.makotest.pl |
| CloudFront preprod/prod | E17VHHQJ29MVAB → twojkapsel.pl, www.twojkapsel.pl |
| Redis UAT | maspex-uat.zwowz5.0001.euw1.cache.amazonaws.com:6379 (cache.t3.medium, Redis 7.1) |
| Redis preprod | maspex-preprod (cache.t3.micro, Redis 7.1) |
| VPC | vpc-0df07c64ea8a8b00e (10.44.0.0/16) |
| State bucket | terraform-state-969209893152 |
| Lock table | terraform-locks-969209893152 |

---

## Secrets Manager

Nie wypisuj wartości sekretów.

| Secret | Przeznaczenie / zawartość logiczna |
|---|---|
| maspex/uat/api | konfiguracja API (klucze, connection strings, sekrety aplikacyjne) |

---

## ACM Certificates

| Domena | Region | Status |
|---|---|---|
| kapsel-admin-uat.makotest.pl | eu-west-1 | ISSUED ✓ |
| twojkapsel.pl | eu-west-1 | ISSUED ✓ |
| twojkapsel.pl | us-east-1 | ISSUED ✓ |
| twojkapsel-admin.makolab.pro | eu-west-1 | **PENDING_VALIDATION ⚠** |
| twojkapsel-admin.makolab.pro | us-east-1 | **PENDING_VALIDATION ⚠** |

---

## Observability

| Element | Status | Uwagi |
|---|---|---|
| CloudWatch Alarms UAT | 3 w ALARM | patrz sekcja "Znane problemy" |
| CloudWatch Alarms preprod | wszystkie OK | |
| Container Insights UAT | aktywny | retencja **1 dzień** — bardzo krótka |
| Container Insights preprod | aktywny | retencja **1 dzień** — bardzo krótka |
| ElastiCache logs | aktywny | retencja 30 dni |
| Log group /maspex/uat/* | aktywny | retencja 30 dni |
| Log group /maspex/preprod/* | aktywny | retencja 30 dni |
| Log group /maspex/shared/* | obecny | retencja 90 dni — środowisko "shared" bez aktywnego klastra |
| CW dashboards | nieustalone | nie sprawdzono |

Log groups bez serwisu (orphaned?):
- `/maspex/uat/contest-service`
- `/maspex/preprod/contest-service`
- `/maspex/shared/maspex-api`, `/maspex/shared/maspex-frontend`, `/maspex/shared/maspex-worker`

---

## Znane problemy / dług techniczny

| Problem | Priorytet | Evidence | Opis |
|---|---|---|---|
| maspex-preprod-api: 0/3 running | WYSOKI | `describe-services`: running:0, desired:3 | API w preprod nie startuje; bot i admin-panel działają |
| twojkapsel-admin.makolab.pro cert PENDING | ŚREDNI | ACM eu-west-1 i us-east-1 | Certyfikat admina dla preprod/prod nie przeszedł walidacji DNS |
| maspex-uat-alb-unhealthy-hosts-bot | NISKI | CW alarm w ALARM od 23/04/26 | 1 unhealthy host bota; alarm stale otwarty, wymaga weryfikacji aktualności |
| Container Insights retencja 1 dzień | NISKI | describe-log-groups | `/aws/ecs/containerinsights/*/performance` — retencja 1d; utrudnia post-incident debugging |
| Auto-scaling AlarmLow w ALARM | INFO | CW alarms | Scale-down alarmy (CPU < 54%, MEM < 67.5%) — oczekiwane po load testach, nie krytyczne |
| contest-service log groups bez serwisu | INFO | describe-log-groups | Możliwy relikt po usuniętym serwisie lub feature flag |

---

## Różnice IaC vs Runtime

| Obszar | IaC | Runtime AWS | Ocena |
|---|---|---|---|
| preprod-api | desired w IaC nieustalone | desired:3, running:0 | **ROZBIEŻNOŚĆ** — API nie startuje |
| shared env | Terraform env istnieje | brak klastra ECS | możliwe celowe — shared może być tylko VPC/networking |
| prod env | Terraform env istnieje | stan live nieweryfikowany | do sprawdzenia |
| backend.hcl | plik istnieje lokalnie | S3 bucket aktywny | ✓ |

---

## Dostęp diagnostyczny

```bash
# Tożsamość
aws sts get-caller-identity --profile maspex-cli

# ECS UAT
aws ecs describe-services --cluster maspex-uat \
  --services maspex-api maspex-bot maspex-admin-panel \
  --profile maspex-cli --region eu-west-1

# Zadania API (UAT)
aws ecs list-tasks --cluster maspex-uat --service-name maspex-api \
  --profile maspex-cli --region eu-west-1

# Dlaczego preprod-api nie startuje — ostatnie zatrzymane taski
aws ecs list-tasks --cluster maspex-preprod --desired-status STOPPED \
  --service-name maspex-preprod-api --profile maspex-cli --region eu-west-1

# Opis zatrzymanego taska (podmień TASK_ARN)
aws ecs describe-tasks --cluster maspex-preprod --tasks <TASK_ARN> \
  --profile maspex-cli --region eu-west-1 \
  --query 'tasks[0].{status:lastStatus,stop:stoppedReason,containers:containers[*].{name:name,reason:reason,exit:exitCode}}'

# Target health ALB UAT
aws elbv2 describe-target-groups --profile maspex-cli --region eu-west-1 \
  --query 'TargetGroups[?contains(TargetGroupName,`maspex-uat`)].TargetGroupArn' --output text | \
  xargs -I{} aws elbv2 describe-target-health --target-group-arn {} \
  --profile maspex-cli --region eu-west-1

# CloudWatch alarms aktualny stan
aws cloudwatch describe-alarms --profile maspex-cli --region eu-west-1 \
  --query 'MetricAlarms[?StateValue==`ALARM`].{name:AlarmName,metric:MetricName,reason:StateReason}'

# Terraform plan UAT (read-only)
cd ~/projekty/mako/aws-projects/infra-maspex/terraform/envs/uat
terraform init -backend-config=backend.hcl
terraform plan
```

---

## Powiązane

- [[maspex-load-testing]] (`_chatgpt/context-packs/maspex-load-testing.md`)
- [[maspex]] (`_chatgpt/context-packs/maspex.md`)
- [[now]]
