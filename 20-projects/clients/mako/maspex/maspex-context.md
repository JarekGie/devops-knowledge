---
title: maspex-context
client: maspex
project: maspex
domain: client-work
document_type: runtime-context
context_type: cloud-detective-snapshot
classification: internal
source_of_truth: false
runtime_snapshot: true
aws_profile: maspex-cli
account_id: "969209893152"
regions:
  - eu-west-1
  - us-east-1
iac: terraform
repository: "~/projekty/mako/aws-projects/infra-maspex/"
created: 2026-05-01
updated: 2026-05-01
tags:
  - aws
  - terraform
  - ecs
  - fargate
  - mako
  - maspex
---

# maspex — Kapsel (aplikacja konkursowa Maspex)

#aws #terraform #ecs #fargate #mako #maspex

**Data:** 2026-05-01
**Typ dokumentu:** snapshot runtime / context wejściowy
**Source of truth:** AWS live + IaC + Terraform state
**Tryb skanowania:** read-only
**Projekt:** Platforma konkursowa Kapsel — Next.js API + admin panel + bot, CloudFront → ALB → ECS Fargate, Redis ElastiCache, Supabase/PostgREST jako downstream.
**Account ID:** `969209893152`
**AWS profile:** `maspex-cli`
**IAM principal:** `makolab-ci` (IAM user, uprawnienia CI)
**Region główny:** `eu-west-1` (CloudFront / ACM dodatkowo w `us-east-1`)

---

## Repozytorium kodu

- lokalna ścieżka (infra): `~/projekty/mako/aws-projects/infra-maspex/`
- lokalna ścieżka (app): `~/projekty/mako/next-core-app/`
- remote (infra): `git@gitlab.makolab.net:admin-makolab/dc/aws-projects/infra-maspex-kapsel.git`
- aktywny branch: `main`
- IaC: **Terraform** (provider `hashicorp/aws ~> 5.0`, aktualnie `5.100.0`)

Struktura repo infra:
```
terraform/
  bootstrap/   — S3 state bucket, DynamoDB lock table
  envs/        — shared/, uat/, prod/, preprod/
  modules/     — alb, alb-routing, ecs, elasticache, cloudfront, …
```

---

## Środowiska

| Env | Region | Account ID | Status | VPC CIDR | Pewność |
|-----|--------|------------|--------|----------|---------|
| shared | eu-west-1 | 969209893152 | IaC istnieje, brak klastra ECS | nieustalone | średnia — IaC + brak live cluster |
| uat | eu-west-1 | 969209893152 | aktywny — 11 tasków running | 10.44.0.0/16 | wysoka — live AWS |
| preprod | eu-west-1 | 969209893152 | częściowo — API 0/3 running | 10.44.0.0/16 | wysoka — live AWS |
| prod | eu-west-1 | 969209893152 | IaC istnieje, live nieweryfikowane | nieustalone | niska — tylko IaC |

VPC: `vpc-0df07c64ea8a8b00e` (10.44.0.0/16), brak Name tagu.

**Terraform state (S3 + DynamoDB, encrypt=true):**

| Env | Bucket | Key | Lock table |
|-----|--------|-----|------------|
| shared | terraform-state-969209893152 | maspex/shared/terraform.tfstate | terraform-locks-969209893152 |
| uat | terraform-state-969209893152 | maspex/uat/terraform.tfstate | terraform-locks-969209893152 |
| prod | terraform-state-969209893152 | maspex/prod/terraform.tfstate | terraform-locks-969209893152 |

Backend przez `-backend-config=backend.hcl` (wartości nie są hardcode'owane w `backend.tf`).

---

## Architektura (UAT — potwierdzone live)

```text
Internet
  │
  ├── CloudFront E3J76RNXIE2YIG  → kapsel.makotest.pl           (API / frontend UAT)
  ├── CloudFront E3R9U1TWNUJZ11  → kapsel-admin-uat.makotest.pl (admin UAT)
  └── CloudFront E17VHHQJ29MVAB  → twojkapsel.pl / www          (preprod/prod — wymaga potwierdzenia)
        │
        ▼
  ALB maspex-uat (internet-facing, eu-west-1)
  ALB maspex-preprod (internet-facing, eu-west-1)
        │
        ▼
  ECS Fargate — cluster maspex-uat
    ├── maspex-api         (9/9 running)  ─── Redis ElastiCache maspex-uat :6379
    ├── maspex-bot         (1/1 running)
    └── maspex-admin-panel (1/1 running)
                                         ─── Supabase/PostgREST (downstream, zewnętrzny)

  ECS Fargate — cluster maspex-preprod
    ├── maspex-preprod-api         (0/3 running) ⚠ API nie startuje
    ├── maspex-preprod-bot         (1/1 running)
    └── maspex-preprod-admin-panel (1/1 running)
```

Przypisanie CloudFront `E17VHHQJ29MVAB` (twojkapsel.pl) do preprod lub prod — **wymaga potwierdzenia**.

---

## Mikroserwisy / komponenty

| Serwis | Cluster | Ingress | Service Discovery | ECS Exec | Desired | Running | Status |
|--------|---------|---------|-------------------|----------|---------|---------|--------|
| maspex-api | maspex-uat | ALB → CF | brak | nieustalone | 9 | 9 | ✓ ACTIVE |
| maspex-bot | maspex-uat | ALB | brak | nieustalone | 1 | 1 | ✓ ACTIVE |
| maspex-admin-panel | maspex-uat | ALB → CF | brak | nieustalone | 1 | 1 | ✓ ACTIVE |
| maspex-preprod-api | maspex-preprod | ALB | brak | nieustalone | 3 | 0 | ⚠ API DOWN |
| maspex-preprod-bot | maspex-preprod | ALB | brak | nieustalone | 1 | 1 | ✓ ACTIVE |
| maspex-preprod-admin-panel | maspex-preprod | ALB | brak | nieustalone | 1 | 1 | ✓ ACTIVE |

Brak Cloud Map / Service Discovery. Brak EventBridge rules. Brak SQS.

---

## Zasoby kluczowe

| Zasób | Identyfikator | Źródło | Pewność |
|-------|---------------|--------|---------|
| ECS cluster UAT | maspex-uat | live AWS | wysoka |
| ECS cluster preprod | maspex-preprod | live AWS | wysoka |
| ALB UAT | maspex-uat-1361582173.eu-west-1.elb.amazonaws.com | live AWS | wysoka |
| ALB preprod | maspex-preprod-1322298306.eu-west-1.elb.amazonaws.com | live AWS | wysoka |
| CloudFront API/UAT | E3J76RNXIE2YIG → kapsel.makotest.pl | live AWS | wysoka |
| CloudFront admin/UAT | E3R9U1TWNUJZ11 → kapsel-admin-uat.makotest.pl | live AWS | wysoka |
| CloudFront preprod/prod | E17VHHQJ29MVAB → twojkapsel.pl, www.twojkapsel.pl | live AWS | średnia — env niepotwierdzony |
| Redis UAT | maspex-uat.zwowz5.0001.euw1.cache.amazonaws.com:6379 | live AWS | wysoka |
| Redis UAT node type | cache.t3.medium, Redis 7.1.0, single-node | live AWS | wysoka |
| Redis preprod | maspex-preprod (endpoint niepobrany) | live AWS | średnia |
| Redis preprod node type | cache.t3.micro, Redis 7.1.0 | live AWS | wysoka |
| VPC | vpc-0df07c64ea8a8b00e (10.44.0.0/16) | live AWS | wysoka |
| State bucket | terraform-state-969209893152 | IaC backend.hcl | wysoka |
| Lock table | terraform-locks-969209893152 | IaC backend.hcl | wysoka |

---

## Secrets Manager

Nie wypisuj wartości sekretów.

| Secret | Przeznaczenie / zawartość logiczna | Źródło |
|--------|------------------------------------|--------|
| maspex/uat/api | konfiguracja API UAT (klucze, connection strings) | live AWS |

Uwaga: lista może być niekompletna — `list-secrets` zwrócił jeden wpis. Sekrety preprod/prod mogą być niewidoczne dla `makolab-ci` lub nie istnieją.

---

## ACM Certificates

| Domena | Region | Status | Uwagi |
|--------|--------|--------|-------|
| kapsel-admin-uat.makotest.pl | eu-west-1 | ISSUED ✓ | admin UAT |
| twojkapsel.pl | eu-west-1 | ISSUED ✓ | preprod/prod ALB |
| twojkapsel.pl | us-east-1 | ISSUED ✓ | CloudFront (us-east-1 required) |
| twojkapsel-admin.makolab.pro | eu-west-1 | **PENDING_VALIDATION ⚠** | brak walidacji DNS |
| twojkapsel-admin.makolab.pro | us-east-1 | **PENDING_VALIDATION ⚠** | brak walidacji DNS |

---

## Scheduler / automatyzacje

| Automatyzacja | Harmonogram | Zakres | Uwagi |
|--------------|-------------|--------|-------|
| — | — | — | Brak EventBridge rules (live AWS, eu-west-1) |

---

## ECS / runtime config

| Parametr | Wartość |
|----------|---------|
| Launch type | FARGATE |
| Task def API UAT | maspex-api:53 |
| Task def bot UAT | maspex-bot:8 |
| Task def admin-panel UAT | maspex-admin-panel:25 |
| Task def API preprod | maspex-preprod-api:1 |
| Task def bot preprod | maspex-preprod-bot:1 |
| Task def admin-panel preprod | maspex-preprod-admin-panel:11 |
| Auto-scaling (UAT API) | Target Tracking — CPU + Memory |

---

## Observability

**Runtime health (live, 2026-05-01):**

| Element | Status | Uwagi |
|---------|--------|-------|
| maspex-uat — serwisy | ✓ healthy | 11/11 tasków running |
| maspex-preprod — api | ⚠ DOWN | 0/3 running |
| maspex-preprod — bot, admin-panel | ✓ healthy | |
| ALB UAT | ✓ active | |
| ALB preprod | ✓ active | ALB działa, API tasks nie startują |
| Redis UAT | ✓ available | cache.t3.medium |
| Redis preprod | ✓ available | cache.t3.micro |

**CloudWatch alarms:**

| Alarm | Stan | Metric | Kontekst |
|-------|------|--------|----------|
| TargetTracking maspex-uat/maspex-api AlarmLow (Memory) | ALARM | MemoryUtilization < 67.5% | Auto-scaling scale-down — normalny po load teście, nie krytyczny |
| TargetTracking maspex-uat/maspex-api AlarmLow (CPU) | ALARM | CPUUtilization < 54% | Auto-scaling scale-down — normalny po load teście, nie krytyczny |
| maspex-uat-alb-unhealthy-hosts-bot | ALARM | UnHealthyHostCount > 0 | Alarm od 23/04/26 08:09 — stary, wymaga weryfikacji aktualności |
| Pozostałe alarmy preprod | OK | — | |

**Log groups:**

| Log group | Retencja | Uwagi |
|-----------|----------|-------|
| /maspex/uat/* | 30 dni | aktywne |
| /maspex/preprod/* | 30 dni | aktywne |
| /maspex/shared/* | 90 dni | środowisko shared bez klastra ECS — orphaned? |
| /maspex/uat/contest-service | 30 dni | brak serwisu ECS — relikt lub feature flag |
| /maspex/preprod/contest-service | 30 dni | brak serwisu ECS — relikt lub feature flag |
| /aws/ecs/containerinsights/*/performance | **1 dzień** | ⚠ retencja zbyt krótka dla post-incident debugging |
| /aws/elasticache/* | 30 dni | |

---

## Znane problemy / dług techniczny

| Problem | Priorytet | Evidence | Opis |
|---------|-----------|----------|------|
| maspex-preprod-api: 0/3 running | WYSOKI | `describe-services`: running:0, desired:3 | API w preprod nie startuje; task-def revision :1 (bardzo niska, możliwy config issue) |
| twojkapsel-admin.makolab.pro PENDING_VALIDATION | ŚREDNI | ACM eu-west-1 + us-east-1 | Certyfikat dla admin preprod/prod bez walidacji DNS; blokuje HTTPS |
| maspex-uat-alb-unhealthy-hosts-bot alarm | NISKI | CW alarm w ALARM od 23/04/26 | Nie potwierdzono target health — może być stale; wymaga `describe-target-health` |
| Container Insights retencja 1 dzień | NISKI | `describe-log-groups` | `/aws/ecs/containerinsights/*/performance` — 1d retencja; utrudnia debugging |
| contest-service log groups bez serwisu | INFO | `describe-log-groups` | Log groups dla UAT + preprod bez odpowiadającego serwisu ECS |
| Sekrety: tylko 1 wpis widoczny | INFO | `list-secrets` | Możliwe ograniczenie uprawnień lub niekompletne pokrycie envów preprod/prod |
| VPC bez Name tagu | INFO | `describe-vpcs`: name: null | Utrudnia nawigację; może być celowe |

---

## Różnice IaC vs Runtime

| Obszar | IaC | Runtime AWS | Ocena |
|--------|-----|-------------|-------|
| preprod-api | task-def :1, desired nieustalone z IaC | desired:3, running:0 | **rozbieżność** — API nie startuje |
| shared env | Terraform env istnieje (envs/shared/) | brak klastra ECS, log groups obecne | nieustalone — shared może być tylko VPC/networking |
| prod env | Terraform env istnieje (envs/prod/) | stan live nieweryfikowany | **nieustalone** |
| Terraform backend | backend.hcl lokalnie, S3 bucket aktywny | bucket 969209893152 dostępny | zgodne |
| Redis (UAT) | nieustalone z IaC (nie czytano modułu) | single-node (brak replication group) | wymaga potwierdzenia |
| Auto-scaling API | zdefiniowane (target tracking CPU+MEM) | aktywne alarmy AlarmLow w ALARM | zgodne — alarmy są efektem ubocznym auto-scaling po load teście |

---

## Pewność ustaleń

| Obszar | Pewność | Evidence | Uwagi |
|--------|---------|----------|-------|
| Account ID, region, profil | wysoka | `sts get-caller-identity` | |
| ECS UAT — serwisy i taski | wysoka | `describe-services` | |
| ECS preprod — api down | wysoka | `describe-services` running:0 | przyczyna nieustalona |
| CloudFront distributions | wysoka | `list-distributions` | przypisanie prod/preprod wymaga potwierdzenia |
| Redis endpointy | wysoka (UAT), średnia (preprod) | `describe-cache-clusters --show-cache-node-info` | preprod endpoint nie pobrany |
| Terraform state backend | wysoka | `backend.hcl` z repozytorium | |
| IaC (envs/prod, envs/shared) | średnia | pliki .tf w repo | live stan nieweryfikowany |
| Secrets Manager pokrycie | niska | tylko 1 secret widoczny | możliwe ograniczenie uprawnień |
| CloudWatch alarms jako health | średnia | alarmy ALARM ale kontekst czasowy | AlarmLow = auto-scaling artefakt; bot alarm stary |
| contest-service | niska | log groups bez ECS service | relikt, feature flag lub niedokończona migracja — nieustalone |

---

## Dostęp diagnostyczny

```bash
# Tożsamość
aws sts get-caller-identity --profile maspex-cli

# ECS UAT — stan serwisów
aws ecs describe-services \
  --cluster maspex-uat \
  --services maspex-api maspex-bot maspex-admin-panel \
  --profile maspex-cli --region eu-west-1 \
  --query 'services[*].{name:serviceName,desired:desiredCount,running:runningCount}'

# Diagnoza preprod-api — dlaczego 0/3
aws ecs list-tasks \
  --cluster maspex-preprod \
  --service-name maspex-preprod-api \
  --desired-status STOPPED \
  --profile maspex-cli --region eu-west-1

# Opis zatrzymanego taska (podmień <TASK_ARN>)
aws ecs describe-tasks \
  --cluster maspex-preprod \
  --tasks <TASK_ARN> \
  --profile maspex-cli --region eu-west-1 \
  --query 'tasks[0].{status:lastStatus,stop:stoppedReason,containers:containers[*].{name:name,reason:reason,exit:exitCode}}'

# Bot target health (zweryfikuj alarm)
aws elbv2 describe-target-groups \
  --profile maspex-cli --region eu-west-1 \
  --query 'TargetGroups[?contains(TargetGroupName,`uat`)&&contains(TargetGroupName,`bot`)].TargetGroupArn' \
  --output text | \
  xargs -I{} aws elbv2 describe-target-health --target-group-arn {} \
  --profile maspex-cli --region eu-west-1

# Alarmy w ALARM
aws cloudwatch describe-alarms \
  --profile maspex-cli --region eu-west-1 \
  --query 'MetricAlarms[?StateValue==`ALARM`].{name:AlarmName,metric:MetricName,reason:StateReason}'

# Sekrety (bez wartości)
aws secretsmanager list-secrets \
  --profile maspex-cli --region eu-west-1 \
  --query 'SecretList[*].{name:Name,description:Description}'

# OPCJONALNIE — tylko po świadomej decyzji operatora.
# Nie jest częścią automatycznego cloud-detective read-only scan.
# cd ~/projekty/mako/aws-projects/infra-maspex/terraform/envs/uat
# terraform init -backend-config=backend.hcl
# terraform plan -refresh=false
```

---

## Aktualizacja dokumentacji po zmianach IaC

Ten context jest snapshotem na 2026-05-01. Po każdym `terraform apply` należy zaktualizować.

Docelowy wzorzec:
```bash
# po terraform apply:
# uruchom ponownie cloud-detective (prompt: 50-patterns/prompts/starter-pack/cloud-detective-v2.md)
# lub ręcznie zaktualizuj sekcje "Środowiska", "Mikroserwisy", "Zasoby kluczowe"
```

Proponowany przyszły target Makefile (bez wdrażania):
```makefile
docs-refresh:
    # read-only scan runtime + update vault context
```

---

## Powiązane

- [[load-test-analysis-2026-04-28-1730-cest]]
- [[load-test-analysis-2026-04-29-1300-cest]]
- [[cloudfront-audit-2026-04-26]]
- [[troubleshooting]]
- [[maspex]] (`_chatgpt/context-packs/maspex.md`)
- [[maspex-load-testing]] (`_chatgpt/context-packs/maspex-load-testing.md`)
- [[now]]
