---
title: budgets-context
client: mako
project: aws-cloud-platform
domain: finops
document_type: iac-context
created: "2026-05-02"
updated: "2026-05-02"
tags:
  - aws
  - terraform
  - budgets
  - finops
  - mako
  - aws-cloud-platform
---

# AWS Budgets — MakoLab Org — IaC Context

#aws #terraform #budgets #finops #mako

**Data audytu:** 2026-05-02  
**Moduł Terraform:** `platform/budgets/`  
**Backend:** `864277686382-terraform-state-bucket / platform/budgets/terraform.tfstate`  
**Profile:** `mako-dc` (management account)

---

## Stan przed audytem

| Konto | ID | Środowisko | Budżety | Alerty |
|---|---|---|---|---|
| RShop | 943111679945 | prod | 7 (1 monthly + 1 CW monthly + 5 daily svc) | SNS: rshop-account-budget-alarms-topic |
| planodkupow | 333320664022 | prod | 6 (2 monthly + 1 daily + 3 daily svc) | **BRAK** |
| Booking_Online | 128264038676 | prod | 4 (1 monthly + 3 daily svc) | **BRAK** |
| dacia-asystent | 074412166613 | prod | 0 | — |
| DRP-TFS | 613448424242 | nonprod | 4 daily svc | dc@makolab.com (thresholds: 150%/200%) |
| CC | 943696080604 | nonprod | 1 monthly "ops" | op.cc@makolab.com |
| planodkupowv1 | 292464762806 | nonprod | 0 | — |
| Admin-MakoLab | 647075515164 | nonprod | 0 | — |
| lab | 052845428574 | nonprod | 0 | — |
| monitoring-nagios-bot | 814662658531 | platform | 0 | — |
| LogArchiveNew | 771354139056 | platform | 0 | — |
| makolab_dc | 864277686382 | management | 0 | — |

---

## Architektura modułu

```
platform/budgets/
├── backend.tf      — S3 backend (management account)
├── versions.tf     — TF >= 1.5, AWS provider >= 5.0
├── providers.tf    — 1 default (management) + 11 alias providers (per-account AssumeRole)
├── variables.tf    — budget_notification_emails (list), tags
├── accounts.tf     — locals.accounts map (12 kont), locals.rshop_budget_sns
├── budgets.tf      — 22 importowane + 6 nowych baseline + 1 deferred (management)
└── imports.tf      — 22 import blocks (Terraform 1.5+ format)
```

### Kluczowa decyzja architektoniczna: per-account providers

AWS Budgets API zwraca `AccessDeniedException` gdy management account wywołuje `DescribeBudget`/`CreateBudget` z `account_id` innego konta. Wymagane AssumeRole do `OrganizationAccountAccessRole` w każdym koncie.

Każdy zasób `aws_budgets_budget` ma `provider = aws.<alias>` odpowiadający kontu.

---

## Zasoby importowane (22 istniejących budżetów)

### RShop (7 budżetów) — alerty przez SNS
- `rshop_monthly` — 900 USD/month, 100%/130%/150% ACTUAL+FORECASTED → SNS
- `rshop_cloudwatch` — 5 USD/month, CW filter → SNS
- `rshop_ecs_daily` / `rshop_elb_daily` / `rshop_elasticache_daily` / `rshop_rds_daily` / `rshop_vpc_daily` — daily service budgets, brak alertów

### planodkupow (6 budżetów) — brak alertów ⚠️
- `planodkupow_monthly_v2` — 950 USD/month (**NEEDS_REVIEW: duplikat poniżej**)
- `planodkupow_monthly` — 900 USD/month
- `planodkupow_daily` — 25 USD/day
- `planodkupow_ecs_daily` / `planodkupow_elb_daily` / `planodkupow_elasticache_daily`

### Booking_Online (4 budżety) — brak alertów ⚠️
- `booking_monthly` — 950 USD/month
- `booking_ecs_daily` / `booking_elb_daily` / `booking_elasticache_daily`

### DRP-TFS (4 budżety) — alerty przez email
- `drptfs_ec2_daily` / `drptfs_ecs_daily` / `drptfs_elb_daily` / `drptfs_vpc_daily` — 150%/200% ACTUAL → dc@makolab.com

### CC (1 budżet)
- `cc_monthly` — 15 USD/month, 80% → op.cc@makolab.com (**NEEDS_REVIEW: prawdopodobnie nieaktualna kwota**)

---

## Nowe baseline budżety (6 kont bez budżetów)

Wszystkie z `dynamic notification` — aktywne tylko gdy `budget_notification_emails` nie jest puste.

| Zasób | Konto | Kwota | Uwaga |
|---|---|---|---|
| `dacia_monthly` | dacia-asystent | 1000 USD | prod workload, wymaga tuningowania |
| `v1_monthly` | planodkupowv1 | 200 USD | nonprod |
| `adminml_monthly` | Admin-MakoLab | 200 USD | nonprod |
| `lab_monthly` | lab | 200 USD | nonprod/lab |
| `monitoring_monthly` | monitoring-nagios-bot | 100 USD | platform |
| `logarchive_monthly` | LogArchiveNew | 100 USD | platform |

Thresholds: 80% ACTUAL, 100% ACTUAL, 120% FORECASTED.

---

## Stan planu Terraform (2026-05-02)

```
Plan: 22 to import, 6 to add, 16 to change, 0 to destroy
```

**22 to import** — wszystkie istniejące budżety, importy działają poprawnie.

**6 to add** — nowe baseline (dacia, v1, adminml, lab, monitoring, logarchive).

**16 to change (safe drift):**
- 11 zasobów: `cost_filter` (Terraform) zastępuje `filter_expression` (computed read-only) — ta sama semantyka, inna reprezentacja providera v6
- 4 zasoby monthly: `billing_view_arn → null` + `metrics = ["UnblendedCost"] → []` — auto-populated pola AWS, provider v6 behavior
- 1 zasób (cc_monthly): usunięcie `planned_limit` blocks z 2021 (wszystkie 15 USD — ta sama wartość co `limit_amount`)

**0 to destroy** — bezpieczny plan.

Znany permanent drift: `billing_view_arn` i `metrics` będą pojawiać się w każdym planie dla budżetów bez cost_filter, bo AWS je auto-populate. Suppress przez `lifecycle { ignore_changes = [billing_view_arn, metrics] }` jeśli uciążliwe.

---

## Otwarte decyzje

| Decyzja | Opis | Priorytet |
|---|---|---|
| planodkupow duplicates | Dwa monthly budgets: Plan-odkupow 950 vs plan_odkupow 900 — usunąć jeden | Wysoki |
| planodkupow + Booking alerty | Zero subskrybentów na wszystkich budżetach — dodać emaile | Wysoki |
| DRP-TFS thresholds | 150%/200% very permissive, brak monthly total budget | Średni |
| CC ops limit | 15 USD/month — prawdopodobnie relikt pilotażu, nie odzwierciedla rzeczywistości | Średni |
| baseline amounts | dacia/v1/adminml/lab/monitoring/logarchive — tuning po Cost Explorer review | Niski |
| management account budget | makolab_dc — deferred, wymaga decyzji FinOps (scope: management-only vs consolidated?) | Niski |

---

## Zastosowanie

```bash
# NIE aplikować bez przeglądu otwartych decyzji powyżej
# Gdy gotowy:
cd platform/budgets
AWS_PROFILE=mako-dc terraform apply \
  -var 'budget_notification_emails=["jaroslaw.golab@makolab.com"]' \
  tfplan-budgets
```
