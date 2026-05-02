---
title: llz-budgets-audit
type: prompt-template
domain: client-work
use_case: LLZ AWS Budgets & cost alerts audit — inventory, Terraform import plan, missing baseline budgets
tags:
  - prompt
  - llz
  - finops
  - budgets
  - cost-alerts
  - terraform
  - import
created: 2026-05-02
updated: 2026-05-02
---

# CONTEXT — AWS LLZ Budgets & Cost Alerts Audit + Terraform Import Plan

You are a senior AWS FinOps / DevOps engineer.

We are working on MakoLab AWS Light Landing Zone.

Repository for platform Terraform:
`~/projekty/mako/aws-projects/aws-cloud-platform`

Task scope:

* audit AWS Budgets and cost alerts across the whole AWS Organization
* identify existing budgets
* prepare Terraform import plan
* add missing baseline budgets as Terraform modules
* DO NOT run terraform apply
* DO NOT delete or replace existing budgets

AWS Organization:

* Management account: `864277686382` / `makolab_dc`
* Monitoring account: `814662658531` / `monitoring-nagios-bot`
* Log archive account: `771354139056` / `LogArchiveNew`
* Role used in member accounts: `OrganizationAccountAccessRole`

Known accounts:

* `943111679945` RShop
* `333320664022` planodkupow
* `128264038676` Booking_Online
* `074412166613` dacia-asystent
* `613448424242` DRP-TFS
* `292464762806` planodkupowv1
* `647075515164` Admin-MakoLab
* `052845428574` lab
* `943696080604` CC
* `814662658531` monitoring-nagios-bot
* `771354139056` LogArchiveNew
* `864277686382` makolab_dc

---

# GOAL

Bring AWS Budgets and cost alerts under Terraform control in the platform repository.

Use a safe sequence:

1. Read-only audit
2. Terraform import plan for existing budgets
3. Terraform module design
4. Add missing baseline budgets
5. Generate commands only — no apply

---

# IMPORTANT RULES

* Work read-only until explicitly asked otherwise.
* Do not run `terraform apply`.
* Do not delete existing budgets.
* Do not rename existing budgets unless explicitly approved.
* Do not create duplicate budgets with the same purpose.
* Prefer importing existing budgets over recreating them.
* Treat manually created budgets as production resources.
* If uncertain, mark as `NEEDS_REVIEW`.

---

# PHASE 1 — AUDIT EXISTING BUDGETS

Check budgets in:

1. Management account
2. Each member account through AssumeRole

For every account run equivalent of:

```bash
aws budgets describe-budgets \
  --account-id <ACCOUNT_ID> \
  --profile <profile-or-assumed-role-context>
```

For each budget collect:

* account id
* account name
* budget name
* budget type
* time unit
* limit amount
* limit unit
* cost filters
* cost types
* notifications
* subscribers
* whether it appears to track only that account or broader org costs

Also check:

* Cost Anomaly Detection monitors/subscriptions if present
* SNS topics used by budget alerts, if referenced
* email subscribers where visible

Output table:

| Account | Existing Budgets | Alerts | Subscribers | Terraform Import Candidate | Notes |

---

# PHASE 2 — CLASSIFY

Classify each account:

## A — Has usable budget

Existing budget is good enough and should be imported.

## B — Has budget but needs cleanup

Budget exists but naming/threshold/subscribers are inconsistent.

## C — No budget

Needs baseline budget.

## D — Special account

Management / Monitoring / LogArchive — requires separate decision.

---

# PHASE 3 — TERRAFORM DESIGN

Inspect the repository:

`~/projekty/mako/aws-projects/aws-cloud-platform`

Find current structure before editing:

* providers
* modules
* envs
* accounts representation
* locals/tags
* existing FinOps/cost modules, if any

Propose minimal structure. Preferred direction:

```text
modules/
  budgets/
    main.tf
    variables.tf
    outputs.tf
    README.md

platform/
  budgets/
    main.tf
    providers.tf
    variables.tf
    budgets.tf
    imports.tf
```

Adapt paths to the existing repo if it already has a better convention.

---

# PHASE 4 — MODULE REQUIREMENTS

Create a reusable Terraform module for AWS Budgets.

Module should support:

* budget name
* budget type, default `COST`
* time unit, default `MONTHLY`
* limit amount
* limit unit, default `USD`
* account-specific cost filter if budget is created centrally
* notifications:

  * threshold
  * threshold type
  * comparison operator
  * notification type
  * subscribers

Baseline default:

* 80% actual
* 100% actual
* 120% forecasted

Do not hardcode personal emails.
Use variable:

```hcl
budget_notification_emails = []
```

---

# PHASE 5 — IMPORT EXISTING BUDGETS

For every existing budget produce Terraform import blocks or commands.

Prefer Terraform 1.5+ import blocks if repo uses Terraform >= 1.5:

```hcl
import {
  to = module.account_budgets["rshop"].aws_budgets_budget.this
  id = "943111679945:ExistingBudgetName"
}
```

If import blocks do not fit repo style, generate CLI commands:

```bash
terraform import 'module.account_budgets["rshop"].aws_budgets_budget.this' '943111679945:ExistingBudgetName'
```

Important:

* Do not invent import IDs.
* Use exact budget names from AWS.
* If budget name has spaces or special chars, quote safely.

---

# PHASE 6 — CREATE MISSING BASELINE BUDGETS

For accounts with no budget, add Terraform configuration only.

Use conservative placeholder limits for now, because final thresholds will be tuned later:

```hcl
monthly_limit_usd = 1000
```

Mark placeholders clearly:

```hcl
# TODO: tune after Cost Explorer review
```

Recommended default baseline:

* workload prod accounts: placeholder 1000 USD
* nonprod/lab accounts: placeholder 200 USD
* monitoring/log archive: placeholder 100 USD unless real spend says otherwise
* management: separate org-level budget, placeholder only if approved

---

# PHASE 7 — VALIDATION

Run only safe validation:

```bash
terraform fmt -recursive
terraform validate
terraform plan
```

Do not apply.

Expected output:

* list of files changed
* list of import blocks/commands
* list of budgets to be created
* list of existing budgets imported
* list of decisions still needed

---

# FINAL OUTPUT FORMAT

Return:

## 1. Executive Summary

## 2. Existing Budgets Inventory

## 3. Classification

## 4. Terraform Design

## 5. Import Plan

## 6. Missing Budgets Plan

## 7. Files Changed

## 8. Commands To Run Manually

## 9. Risks / Decisions Needed

---

# NON-GOALS

* Do not implement Cost Anomaly Detection unless it already exists and needs inventory.
* Do not implement SCP.
* Do not implement devops-toolkit changes.
* Do not change CloudFormation projects.
* Do not run destructive commands.
