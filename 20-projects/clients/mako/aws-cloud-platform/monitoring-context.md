---
title: monitoring-context
client: mako
project: monitoring-nagios-bot
domain: client-work
document_type: runtime-context
context_type: cloud-detective-snapshot
classification: internal
source_of_truth: false
runtime_snapshot: true
aws_profile: cd-monitoring-nagios-bot
account_id: "814662658531"
regions:
  - eu-central-1
extra_regions:
  - us-east-1
iac: terraform
repository: "~/projekty/mako/aws-projects/aws-cloud-platform"
created: "2026-05-01"
updated: "2026-05-02"
last_verified: "2026-05-02"
# last major update: 2026-05-02 — SLO alarms + OAM links planodkupowv1+CC
scan_method: cloud-detective-v2
last_verified_by: claude
tags:
  - aws
  - terraform
  - mako
  - monitoring
---

# monitoring-nagios-bot — konto obserwabilności i alertów AWS Health

#aws #terraform #mako #monitoring

**Data:** 2026-05-01
**Typ dokumentu:** snapshot runtime / context wejściowy
**Source of truth:** AWS live + IaC + Terraform state
**Tryb skanowania:** read-only (CloudDetectiveReadOnly)
**Poziom pewności snapshotu:** wysoka — zasoby potwierdzone live i w IaC
**Projekt:** konto dedykowane dla cross-account obserwabilności (OAM sink) i powiadomień o zdarzeniach AWS Health
**OrgAccountID:** 864277686382
**Account ID:** 814662658531
**Role:** `CloudDetectiveReadOnly`
**AWS profile:** `cd-monitoring-nagios-bot`
**IAM principal:** `cloud-detective-agent → CloudDetectiveReadOnly`
**Region główny:** `eu-central-1`

---

## Snapshot metadata

| Pole | Wartość |
|------|---------|
| scan_date | 2026-05-01 |
| scan_scope | full |
| regions_checked | eu-central-1, us-east-1 |
| repo_checked | tak |
| iac_checked | tak (platform/health-notifications, platform/monitoring) |
| runtime_checked | tak |
| extra_regions_checked | us-east-1 (EventBridge + Lambda — AWS Health requires us-east-1) |

---

## Zakres snapshotu vs audytu

| Obszar | Typ | Zakres | Źródło |
|--------|-----|--------|--------|
| Runtime health (Lambda, EventBridge) | snapshot | live AWS | live AWS |
| OAM sink + links | snapshot | live AWS | live AWS |
| CloudWatch dashboards | snapshot | lista live | live AWS |
| IaC analiza | snapshot | pełny lokalny checkout | IaC |
| Tagging coverage | snapshot | sample-based (2 zasoby eu-central-1) | live AWS |
| FinOps / cost allocation | audit (external) | brak osobnego dokumentu | nieustalone |
| Security (WAF) | gap analysis | niezweryfikowane (brak WAF dla tego konta) | niezweryfikowane |
| ACM certs | snapshot | eu-central-1 + us-east-1 | niezweryfikowane |

---

## Repozytorium kodu

- lokalna ścieżka: `~/projekty/mako/aws-projects/aws-cloud-platform`
- IaC: **Terraform**
- moduły dotyczące tego konta:
  - `platform/health-notifications/` — EventBridge bus, Lambda, SNS (state: 2026-04-20)
  - `platform/monitoring/` — OAM sink, dashboardy (state: 2026-04-18)

---

## Środowiska

| Env | Region | Account ID | Status | Pewność |
|-----|--------|------------|--------|---------|
| prod (platform) | eu-central-1 | 814662658531 | aktywne | wysoka |
| (Lambda/EventBridge) | us-east-1 | 814662658531 | aktywne | wysoka |

State bucket: `864277686382-terraform-state-bucket`
State keys:
- `platform/health-notifications/terraform.tfstate`
- `platform/monitoring/terraform.tfstate`

Lock table: `terraform-state-lock`

---

## Architektura

```text
Org member accounts (us-east-1) — 12 kont (incl. makolab_dc od 2026-05-02)
  └─ EventBridge rule "health-to-monitoring" (per konto)
       │  aws.health events (open, issue/investigation)
       │  dead_letter_config → SQS health-eventbridge-dlq
       ▼
   monitoring-nagios-bot (814662658531)
   ├─ us-east-1:
   │   ├─ EventBridge bus "health-aggregation"
   │   │   └─ rule "health-to-lambda" → Lambda "health-notify"
   │   ├─ Lambda "health-notify" (python3.12, 30s timeout)
   │   │   ├─ dead_letter_config → SQS health-notify-dlq
   │   │   └─ SNS Publish → sns:eu-central-1:health-notifications
   │   ├─ SQS "health-notify-dlq" (14 dni)
   │   ├─ SQS "health-eventbridge-dlq" (14 dni) ← EventBridge forwarding DLQ
   │   └─ CW alarms: health-notify-errors, health-notify-throttles,
   │                  health-to-lambda-failed-invocations,
   │                  health-eventbridge-dlq-messages → SNS health-ops-alerts
   │
   └─ eu-central-1:
       ├─ SNS "health-notifications" → email: jaroslaw.golab@makolab.com
       ├─ SNS "health-ops-alerts" → email (ops alarms)
       ├─ SNS "slo-alerts" → email (SLO alarms) [live 2026-05-02]
       ├─ OAM sink "observabilitySink"
       │   ← OAM links z: rshop, dacia, planodkupow, booking, planodkupowv1, cc
       │   (metryki CloudWatch + LogGroups + XRay) — wszystkie 6 kont live ✅
       │   (metryki CloudWatch + LogGroups + XRay)
       ├─ CloudWatch dashboards (5 szt.)
       │   llz-platform-overview, booking-production,
       │   dacia-production, rshop-production, bbmt-environments
       └─ CloudWatch SLO alarms (8 szt.) [live 2026-05-02]
           slo-rshop-error-rate, slo-rshop-latency-p99,
           slo-booking-error-rate, slo-booking-latency-p99,
           slo-dacia-error-rate, slo-dacia-latency-p99,
           slo-bbmt-uat-error-rate, slo-bbmt-uat-latency-p99
```

---

## Mikroserwisy / komponenty

Brak ECS/Fargate. Konto ma charakter platformowy, nie aplikacyjny.

---

## Zasoby kluczowe

| Zasób | Identyfikator | Źródło | Pewność |
|-------|---------------|--------|---------|
| EventBridge bus | `arn:aws:events:us-east-1:814662658531:event-bus/health-aggregation` | live AWS | wysoka |
| Lambda | `health-notify` (us-east-1), State: Active, LastUpdateStatus: Successful | live AWS | wysoka |
| CW log group | `/aws/lambda/health-notify` (us-east-1), retencja 30 dni | live AWS | wysoka |
| SNS topic | `arn:aws:sns:eu-central-1:814662658531:health-notifications` | live AWS | wysoka |
| SNS subscription | email → jaroslaw.golab@makolab.com, status: confirmed | live AWS | wysoka |
| OAM sink | `arn:aws:oam:eu-central-1:814662658531:sink/dc0f8121-e9d4-4103-afb0-7d8031e72570` | live AWS | wysoka |
| CloudWatch dashboards | 5 szt. (llz-platform-overview, booking-production, dacia-production, rshop-production, bbmt-environments) | live AWS | wysoka |
| IAM role | `health-notify-lambda` (eu-central-1) | live AWS | wysoka |
| IAM role | `health-eventbridge-forward` (eu-central-1) | live AWS | wysoka |
| IAM role | `OrganizationAccountAccessRole` (created 2023-05-16) | live AWS | wysoka |
| IAM role | `CloudDetectiveReadOnly` (created 2026-05-01) | live AWS | wysoka |
| SQS queue | `health-notify-dlq` (us-east-1, 14 dni retencji) — Lambda DLQ | IaC (2026-05-02) | wysoka |
| SNS topic | `health-ops-alerts` (us-east-1) — CW alarms → ops notifications | IaC (2026-05-02) | wysoka |
| CW alarm | `health-notify-errors`, `health-notify-throttles`, `health-to-lambda-failed-invocations`, `health-eventbridge-dlq-messages` (us-east-1) | IaC (2026-05-02) | wysoka |

---

## OAM — cross-account observability

OAM sink `observabilitySink` w eu-central-1 akceptuje linki z całej organizacji (`aws:PrincipalOrgID: o-5c4d5k6io1`).

Linki potwierdzone w Terraform state (platform/monitoring):

| Konto | Account ID | Typy danych | Link ARN (źródło: TF state) |
|-------|------------|-------------|------------------------------|
| RShop | 943111679945 | Metric, LogGroup, XRay | `arn:aws:oam:eu-central-1:943111679945:link/8287c5bd-aa96-4b65-98e2-80ac2948c723` |
| Booking Online | 128264038676 | Metric, LogGroup, XRay | `arn:aws:oam:eu-central-1:128264038676:link/271113ad-b90f-431e-b576-095d46886c24` |
| Planodkupow | 333320664022 | Metric, LogGroup, XRay | `arn:aws:oam:eu-central-1:333320664022:link/d37c0cfb-4aa4-4b25-94ef-99874e3d51a3` |
| Dacia | 074412166613 | Metric, LogGroup, XRay | IaC, link ARN niezweryfikowany live |

Konta BEZ OAM link (nie skonfigurowane): cc, drp_tfs, planodkupowv1, admin_makolab, lab, log_archive_new.

---

## AWS Health — forwarding (health-notifications)

EventBridge rules w każdym koncie członkowskim (us-east-1) kierują zdarzenia `aws.health` (statusCode=open, eventTypeCategory=issue/investigation) na bus `health-aggregation` w monitoringu.

Lambda `health-notify`:
- wzbogaca zdarzenia o nazwy kont (z map ACCOUNT_NAMES)
- publikuje do SNS `health-notifications` → email
- runtime: python3.12, timeout 30s, memory 128MB, code 832B
- stan: **Active / LastUpdateStatus: Successful**

Konta objęte health forwarding (**12**, od 2026-05-02):
drp_tfs, planodkupowv1, admin_makolab, booking_online, rshop, dacia, nagios_bot, planodkupow, lab, log_archive, cc, **makolab_dc** (management account, provider `management_use1`, bez AssumeRole)

---

## Secrets Manager

Secrets Manager: 0 sekretów w eu-central-1 (niezweryfikowane — list-secrets nie wykonano).
Możliwe alternatywne źródła:
- Lambda environment variables (ACCOUNT_NAMES, SNS_TOPIC_ARN) — nie są sekretami, są w Terraform state
- brak innego secret storage widocznego w IaC

---

## ACM Certificates

Nie sprawdzono (list-certificates nie wykonano). Konto platformowe — brak ALB/CloudFront.
Prawdopodobny brak certyfikatów ACM.

---

## Tagging / FinOps / LLZ / AWS WAF readiness

**Brak historycznego audytu.** Bieżący scan: sample-based (2 zasoby sprawdzone live w eu-central-1).

| Obszar | Status | Uwagi |
|--------|--------|-------|
| FinOps — cost allocation tags (Project/Environment/CostCenter) | PARTIAL | Project obecny, brak Environment i CostCenter |
| LLZ tagging standard (Project/Environment/Owner/ManagedBy/CostCenter) | NO-GO | brak Environment, Owner, CostCenter na sprawdzonych zasobach |
| ECS/Fargate — tag propagation | nie dotyczy | brak ECS w tym koncie |
| ECR — tagi na repozytoriach | nie dotyczy | brak ECR |
| S3 — tagi na bucketach | niezweryfikowane | nie sprawdzono |
| CloudWatch Log Groups — tagi | niezweryfikowane | nie sprawdzono |
| AWS WAF — obecność | niezweryfikowane | list-web-acls nie wykonano; konto platformowe bez ALB — mało prawdopodobne |

### Wymagane tagi LLZ

| Tag | Oczekiwana wartość | Status |
|-----|--------------------|--------|
| Project | platform / aws-cloud-platform | obecny (niespójne: platform vs aws-cloud-platform) |
| Environment | prod | brakuje |
| Owner | DevOps/jgol | brakuje |
| ManagedBy | Terraform | obecny (jako "terraform" lowercase) |
| CostCenter | — | brakuje |

### Wniosek

Tagging jest NO-GO względem LLZ — brak Environment, Owner, CostCenter na kluczowych zasobach. Niespójność wartości Project (platform vs aws-cloud-platform) między modułami. Nie oznacza aktywnej awarii runtime. Rekomendowane ujednolicenie tagów przy kolejnym `terraform apply`.

### Następne kroki

| Akcja | Priorytet | Kto |
|-------|-----------|-----|
| Dodać Environment=prod, Owner=DevOps, CostCenter do default_tags w obu modułach | ŚREDNI | jgol |
| Ujednolicić Project (platform → aws-cloud-platform lub odwrotnie) | NISKI | jgol |

---

## Scheduler / automatyzacje

| Automatyzacja | Harmonogram | Zakres | Uwagi |
|--------------|-------------|--------|-------|
| EventBridge health forwarding | event-driven (aws.health) | 11 kont członkowskich | aktywne, ENABLED |

---

## ECS / runtime config

Brak ECS. Konto zawiera wyłącznie Lambda + EventBridge + SNS + OAM.

---

## Observability

**Runtime health (live, 2026-05-01):**

| Element | Status | Uwagi |
|---------|--------|-------|
| Lambda `health-notify` | Active / Successful | us-east-1, ostatnia aktualizacja 2026-04-20 |
| EventBridge bus `health-aggregation` | aktywny | us-east-1, created 2026-04-20 |
| EventBridge rule `health-to-lambda` | ENABLED | us-east-1 |
| SNS topic `health-notifications` | aktywna | eu-central-1, 1 subskrypcja |
| SNS subscription (email) | confirmed | jaroslaw.golab@makolab.com |
| OAM sink `observabilitySink` | aktywny | eu-central-1 |

**CloudWatch SLO alarms (eu-central-1, live 2026-05-02):**

| Alarm | Account | SLO | Trigger | Stan |
|-------|---------|-----|---------|------|
| slo-rshop-error-rate | RShop (prod) | 5xx < 1% | 3/5 min | INSUFFICIENT_DATA→OK |
| slo-rshop-latency-p99 | RShop (prod) | p99 < 2s | 2/3 min | INSUFFICIENT_DATA→OK |
| slo-booking-error-rate | Booking_Online (prod) | 5xx < 1% | 3/5 min | INSUFFICIENT_DATA→OK |
| slo-booking-latency-p99 | Booking_Online (prod) | p99 < 3s | 2/3 min | INSUFFICIENT_DATA→OK |
| slo-dacia-error-rate | dacia-asystent (prod) | 5xx < 1% | 3/5 min | INSUFFICIENT_DATA→OK |
| slo-dacia-latency-p99 | dacia-asystent (prod) | p99 < 3s | 2/3 min | INSUFFICIENT_DATA→OK |
| slo-bbmt-uat-error-rate | planodkupow (prod-on-uat) | 5xx < 1% | 3/5 min | live 2026-05-02 |
| slo-bbmt-uat-latency-p99 | planodkupow (prod-on-uat) | p99 < 3s | 2/3 min | live 2026-05-02 |

**SLO Coverage — Workloads/Production OU:**

| Account | OAM Link | SLO Alarms | Klasyfikacja |
|---------|----------|------------|--------------|
| RShop (943111679945) | ✅ live | ✅ 2 alarmy | prod — publiczny ALB |
| Booking_Online (128264038676) | ✅ live | ✅ 2 alarmy | prod — publiczny ALB |
| dacia-asystent (074412166613) | ✅ live | ✅ 2 alarmy | prod — publiczny ALB |
| planodkupow (333320664022) | ✅ live | ✅ 2 alarmy (live 2026-05-02) | PRODUCTION_WORKLOAD_ON_UAT — bbmt_uat ALB |
| planodkupowv1 (292464762806) | ✅ live | ❌ brak | NONPROD_EXCLUDED — tymczasowa klasyfikacja |
| CC (943696080604) | ✅ live | ❌ brak | NO_ALB_FOUND — tylko pusty klaster ECS |

**Log groups:**

| Log group | Retencja | Uwagi |
|-----------|----------|-------|
| `/aws/lambda/health-notify` | 30 dni | us-east-1 |

---

## Znane problemy / dług techniczny

| Problem | Priorytet | Evidence | Opis |
|---------|-----------|----------|------|
| ~~Brak CloudWatch alarms na Lambda errors / EventBridge~~ | ~~WYSOKI~~ | **RESOLVED 2026-05-02** | Alarmy wdrożone: `health-notify-errors`, `health-notify-throttles`, `health-to-lambda-failed-invocations`, `health-eventbridge-dlq-messages` → SNS `health-ops-alerts` |
| ~~Partial OAM links~~ | ~~WYSOKI~~ | **RESOLVED 2026-05-02** — wszystkie 6 kont Workloads/Production podłączone (rshop, booking, planodkupow, dacia, planodkupowv1, CC) | ✅ |
| Niespójne tagi (NO-GO LLZ) | ŚREDNI | live AWS: brak Environment, Owner, CostCenter | platform/health-notifications i platform/monitoring mają niekompletne default_tags |
| Niespójność Project tag | NISKI | OAM sink: Project=platform; SNS: Project=aws-cloud-platform | Dwa moduły używają różnych wartości Project |
| ~~Brak mechanizmu retry/DLQ dla Lambda~~ | ~~NISKI~~ | **RESOLVED 2026-05-02** | SQS `health-notify-dlq` (14 dni) + `dead_letter_config` na Lambda + CW alarm `health-eventbridge-dlq-messages` |

---

## Różnice IaC vs Runtime

| Obszar | IaC | Runtime AWS | Ocena |
|--------|-----|-------------|-------|
| Lambda `health-notify` | zdefiniowana w lambda.tf | Active, LastUpdateStatus: Successful | zgodne |
| EventBridge bus `health-aggregation` | zdefiniowany | aktywny, policy zgodna z IaC | zgodne |
| SNS topic `health-notifications` | zdefiniowany | aktywny, 1 subskrypcja | zgodne |
| OAM sink `observabilitySink` | zaimportowany do TF | aktywny, ARN zgodny | zgodne |
| CW dashboards | 5 zdefiniowanych (TF resource names: overview, bbmt, booking_production, dacia_production, rshop_production) | 5 aktywnych (llz-platform-overview, bbmt-environments, booking-production, dacia-production, rshop-production) | zgodne (nazwy TF resource ≠ dashboard_name, expected) |

---

## Drift / niespójności architektury

| Obszar | Typ driftu | Źródło | Opis |
|--------|-----------|--------|------|
| Brak OAM linków dla 7 kont | IaC vs architektura | IaC (tylko 4 linki) | cc, drp_tfs, planodkupowv1, admin_makolab, lab, log_archive_new nie mają OAM links — celowe lub do uzupełnienia |

---

## Pewność ustaleń

| Obszar | Pewność | Evidence | Uwagi |
|--------|---------|----------|-------|
| Lambda stan | wysoka | live AWS get-function | Active / Successful |
| EventBridge | wysoka | live AWS list-event-buses | health-aggregation obecny |
| OAM sink | wysoka | live AWS list-sinks | ARN zgodny z TF state |
| OAM links (4 konta) | wysoka | TF state + import blocks | live ARN potwierdzone w state |
| OAM links (7 kont bez linku) | wysoka | TF state: brak resource | celowe |
| CloudWatch dashboards | wysoka | live AWS list-dashboards | 5 dashboardów aktywnych |
| Tagging | częściowa | 2 zasoby sprawdzone live | sample-based |

---

## Dostęp diagnostyczny

```bash
# Diagnoza: stan Lambda
aws lambda get-function --function-name health-notify \
  --profile cd-monitoring-nagios-bot --region us-east-1

# Diagnoza: ostatnie logi Lambda
aws logs tail /aws/lambda/health-notify \
  --profile cd-monitoring-nagios-bot --region us-east-1

# Diagnoza: ostatnie zdarzenia na health-aggregation bus
aws cloudwatch get-metric-statistics \
  --namespace AWS/Events \
  --metric-name Invocations \
  --dimensions Name=RuleName,Value=health-to-lambda Name=EventBusName,Value=health-aggregation \
  --start-time "$(date -u -v-24H +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --period 3600 --statistics Sum \
  --profile cd-monitoring-nagios-bot --region us-east-1

# Diagnoza: status OAM sink i linki
aws oam list-sinks --profile cd-monitoring-nagios-bot --region eu-central-1
aws oam get-sink --identifier dc0f8121-e9d4-4103-afb0-7d8031e72570 \
  --profile cd-monitoring-nagios-bot --region eu-central-1
```

---

## Źródła użyte

| Źródło | Zakres | Status |
|--------|--------|--------|
| live AWS (cd-monitoring-nagios-bot) | Lambda, EventBridge, SNS, OAM, CloudWatch dashboards, alarms, log groups, IAM roles | sprawdzone |
| live AWS (us-east-1) | Lambda, EventBridge bus, log groups | sprawdzone |
| repo lokalne | platform/health-notifications/, platform/monitoring/ | sprawdzone |
| IaC | Terraform — main.tf, lambda.tf, dashboards.tf, locals.tf, providers.tf, variables.tf | sprawdzone |
| Terraform state (S3) | platform/health-notifications (2026-04-20), platform/monitoring (2026-04-18) | sprawdzone |
| vault historyczny | aws-cloud-platform-context.md (korekta: OAM sink jest w 814662658531, nie management account) | użyte (korekta) |
| extra_regions | us-east-1: EventBridge + Lambda (sprawdzone) | sprawdzone |

## Fakty live vs historia vault

| Informacja | Status | Źródło | Uwagi |
|------------|--------|--------|-------|
| OAM sink w koncie 814662658531 | live | live AWS + TF state | Poprzedni context aws-cloud-platform przypisywał sink do management account — błąd |
| Lambda health-notify Active | live | live AWS | |
| EventBridge bus health-aggregation aktywny | live | live AWS | |
| 4 OAM links (rshop, booking, planodkupow, dacia) | live (TF state) | TF state | live ARN w imporcie = potwierdzenie |
| 5 CloudWatch dashboards | live | live AWS | |

---

## Powiązane

- [[aws-cloud-platform-context]] — management account, organizacja, CloudTrail, LLZ
- `platform/health-notifications/` — IaC źródło dla EventBridge + Lambda + SNS
- `platform/monitoring/` — IaC źródło dla OAM sink + dashboardy
