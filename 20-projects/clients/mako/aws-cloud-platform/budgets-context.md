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

## Architektura modułu

```
platform/budgets/
├── backend.tf      — S3 backend (management account)
├── versions.tf     — TF >= 1.5, AWS provider >= 5.0
├── providers.tf    — 1 default (management) + 11 alias providers (per-account AssumeRole)
├── variables.tf    — budget_notification_emails (list), tags
├── accounts.tf     — locals.accounts map (12 kont), locals.rshop_budget_sns
├── budgets.tf      — 21 importowane + 7 nowych (6 baseline + management)
└── imports.tf      — 21 import blocks (TF 1.5+ format)
```

### Kluczowa decyzja: per-account providers

AWS Budgets API zwraca `AccessDeniedException` gdy management account wywołuje `DescribeBudget`/`CreateBudget` z `account_id` innego konta. Wymagane AssumeRole do `OrganizationAccountAccessRole` w każdym koncie. Każdy zasób `aws_budgets_budget` ma `provider = aws.<alias>`.

Management budget używa domyślnego providera (mako-dc profile = management account).

---

## Stan budżetów po audycie

### Pokrycie alertów (po apply)

| Konto | Env | Budżety | Alerty |
|---|---|---|---|
| RShop | prod | 7 | ✅ SNS (100/130/150%) |
| planodkupow | prod | 5 | ✅ email 80/100/120% (było: BRAK) |
| Booking_Online | prod | 4 | ✅ email 80/100/120% (było: BRAK) |
| dacia-asystent | prod | 1 new | ✅ email 80/100/120% |
| DRP-TFS | nonprod | 4 | ✅ email 80/100% (było: 150/200%) |
| CC | nonprod | 1 | ✅ 80% → op.cc@makolab.com |
| planodkupowv1 | nonprod | 1 new | ✅ email 80/100/120% |
| Admin-MakoLab | nonprod | 1 new | ✅ email 80/100/120% |
| lab | nonprod | 1 new | ✅ email 80/100/120% |
| monitoring-nagios-bot | platform | 1 new | ✅ email 80/100/120% |
| LogArchiveNew | platform | 1 new | ✅ email 80/100/120% |
| makolab_dc | management | 1 new | ✅ email 80/100/120% (WAF) |

Email: `var.budget_notification_emails` — podawane przy `terraform apply`.

### Zasoby importowane (21 istniejących budżetów)

**RShop** (7) — alerty SNS bez zmian:  
`rshop_monthly` `rshop_cloudwatch` `rshop_ecs_daily` `rshop_elb_daily` `rshop_elasticache_daily` `rshop_rds_daily` `rshop_vpc_daily`

**planodkupow** (5, bez planodkupow_monthly_v2 który był duplikatem):  
`planodkupow_monthly` `planodkupow_daily` `planodkupow_ecs_daily` `planodkupow_elb_daily` `planodkupow_elasticache_daily`

**Booking_Online** (4):  
`booking_monthly` `booking_ecs_daily` `booking_elb_daily` `booking_elasticache_daily`

**DRP-TFS** (4) — thresholds zmienione z 150%/200% na 80%/100%:  
`drptfs_ec2_daily` `drptfs_ecs_daily` `drptfs_elb_daily` `drptfs_vpc_daily`

**CC** (1) — bez zmian: `cc_monthly` (15 USD/month, confirmed current)

### Nowe baseline budżety (7)

Kwoty oparte na danych Cost Explorer (Feb-Apr 2026). `dynamic notification` aktywne gdy `budget_notification_emails` nie jest puste.

| Zasób | Konto | Limit | Dane historyczne | Headroom |
|---|---|---|---|---|
| `dacia_monthly` | dacia-asystent | 600 USD | Mar=$92, Apr=$267 (rośnie!) | ~2x na Apr peak |
| `v1_monthly` | planodkupowv1 | 50 USD | ~$21/month (stabilny) | ~2.4x |
| `adminml_monthly` | Admin-MakoLab | 150 USD | Apr=$66 (rośnie) | ~2.3x |
| `lab_monthly` | lab | 25 USD | Apr=$1.34 (near-zero) | guard floor |
| `monitoring_monthly` | monitoring-nagios-bot | 20 USD | Apr=$5.69 | ~3.5x |
| `logarchive_monthly` | LogArchiveNew | 20 USD | Apr=$5.63 | ~3.5x |
| `management_monthly` | makolab_dc | 40 USD | ~$18/month (stabilny) | ~2x (WAF) |

---

## Apply (2026-05-02)

```
Apply complete! Resources: 21 imported, 7 added, 18 changed, 0 destroyed.
```

**Status:** ✅ ZAAPLIKOWANY

**Known permanent drift:** `billing_view_arn` i `metrics` wracają po każdym planie. Suppress przez `lifecycle { ignore_changes = [billing_view_arn, metrics] }` jeśli uciążliwe.

---

## Otwarte decyzje

| Decyzja | Status | Priorytet |
|---|---|---|
| dacia budget tuning | Kwota 600 USD — dostosować po stabilizacji workloadu | Średni |
| adminml budget tuning | Kwota 150 USD — dostosować po zakończeniu projektu | Niski |
| planodkupow_monthly_v2 | ✅ Usunięty przez Terraform (import → destroy 2026-05-02) — nie istnieje w AWS | Zamknięte |
