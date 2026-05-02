---
title: llz-observability-audit
type: prompt-template
domain: client-work
use_case: LLZ observability audit — CloudWatch, OAM, CloudTrail, log retention
tags:
  - prompt
  - llz
  - observability
  - cloudwatch
  - oam
  - cloudtrail
  - audit
created: 2026-05-02
updated: 2026-05-02
---

# CONTEXT — AWS LLZ Monitoring Audit (MakoLab)

You are a senior AWS SRE performing a **read-only audit of AWS Organization** focused on:

1. CloudWatch metrics coverage
2. Cross-account observability (OAM / monitoring account)
3. Central logging (CloudTrail → LogArchive account)
4. LLZ compliance

Work ONLY in read-only mode (no write operations).

---

# INPUT (ASSUMPTIONS)

Organization structure:

* Monitoring account: monitoring-nagios-bot
* Log archive account: LogArchiveNew
* Multiple workload accounts (prod + nonprod)

Expected LLZ behavior:

* CloudWatch metrics available in each account
* Cross-account aggregation via OAM sink (monitoring account)
* Organization CloudTrail writing to LogArchive account
* No local-only observability silos

---

# TASK

Perform structured audit and return:

## 1. METRICS COVERAGE PER ACCOUNT

For each AWS account:

* List available CloudWatch namespaces
* Detect key services:

  * ECS / Fargate
  * EC2
  * RDS
  * ALB / NLB
  * Lambda
* Identify:

  * Missing expected metrics
  * Accounts with minimal/no metrics

Output:

* Table: account → services → metrics present/missing
* Flag accounts with LOW observability

---

## 2. CROSS-ACCOUNT OBSERVABILITY (OAM)

Verify:

### A. Monitoring account (sink)

* Is OAM sink configured?
* What resource types are allowed:

  * metrics
  * logs
  * traces
* Is org-wide access enabled?

### B. Source accounts

* Are they linked to the sink?
* Are links ACTIVE?

### C. Consistency

* Accounts without OAM link
* Accounts partially configured

Output:

* FULL / PARTIAL / MISSING per account

---

## 3. CLOUDWATCH LOGS

For each account:

* Check:

  * Log groups exist
  * Retention policy set (not "Never expire")
* Identify:

  * Missing logs for ECS/Lambda
  * Infinite retention (cost risk)

---

## 4. CLOUDTRAIL (ORG LEVEL)

Verify:

### A. Organization Trail

* Exists?
* Multi-region enabled?
* Includes:

  * management events
  * data events (S3 / Lambda?)

### B. Delivery

* Target: LogArchiveNew account
* S3 bucket:

  * encryption enabled
  * versioning enabled

### C. Coverage

* All accounts included?
* Any standalone trails?

Output:

* PASS / PARTIAL / FAIL

---

## 5. LOG ARCHIVE ACCOUNT (LogArchiveNew)

Validate:

* S3 bucket structure for CloudTrail
* Access policies (org-wide write)
* Lifecycle policies (cost optimization)

Detect:

* Missing lifecycle
* Misconfigured permissions

---

## 6. LLZ COMPLIANCE SUMMARY

Evaluate against LLZ baseline:

| Area                        | Status                |
| --------------------------- | --------------------- |
| Metrics coverage            | PASS / PARTIAL / FAIL |
| Cross-account observability | PASS / PARTIAL / FAIL |
| Central logging             | PASS / PARTIAL / FAIL |
| Log retention               | PASS / PARTIAL / FAIL |

---

## 7. CRITICAL FINDINGS (TOP 10)

Only high-impact issues:

* Missing OAM links
* No CloudTrail in account
* No logs / no metrics
* No retention

---

## 8. SAFE REMEDIATION PLAN

For each issue:

* What to fix
* Where (account / org)
* Recommended Terraform approach (high-level)

DO NOT propose manual console fixes.

---

# OUTPUT FORMAT

Strict structure:

1. Executive Summary (max 10 lines)
2. Evidence (tables, per account)
3. Findings (prioritized)
4. LLZ compliance matrix
5. Remediation plan

Separate:

* FACTS (observed)
* ASSUMPTIONS (if any)

---

# IMPORTANT RULES

* Read-only only
* No speculation without marking it
* No generic AWS advice
* Focus on THIS organization
* Prefer completeness over brevity
