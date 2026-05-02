---
title: llz-observability-audit-2026-05-02
domain: internal
project: llz
document_type: audit-report
classification: internal
source_of_truth: false
runtime_snapshot: true
scan_date: 2026-05-02
scan_method: manual-cli-read-only
last_verified_by: claude
org_id: o-5c4d5k6io1
management_account: "864277686382"
tags:
  - llz
  - observability
  - cloudwatch
  - oam
  - cloudtrail
  - audit
---

# LLZ Observability Audit — 2026-05-02

**Typ dokumentu:** audit snapshot (read-only)
**Scope:** AWS Organization `o-5c4d5k6io1`, 12 aktywnych kont
**Source of truth:** live AWS CLI (mako-dc + AssumeRole OrganizationAccountAccessRole)
**Regiony sprawdzone:** eu-central-1 (workload region) | us-east-1 NIE sprawdzony
**Data:** 2026-05-02

---

## 1. Executive Summary

Organizacja ma działający org-level CloudTrail i 4 z 9 kont workload podłączone do centralnego OAM sink w monitoring-nagios-bot. Główne luki:

1. **5 kont workload bez OAM link** → DRP-TFS, planodkupowv1, Admin-MakoLab, lab, CC są niewidoczne w monitoring account.
2. **Brak lifecycle policy na CloudTrail S3 bucket** → logi CloudTrail rosną bez limitu kosztowego.
3. **57% grup logów z retencją "Never expire"** → planodkupow (40/60), DRP-TFS (17/18) — wysokie ryzyko kosztowe.
4. **planodkupowv1, Admin-MakoLab, lab mają 0 grup logów** w eu-central-1 — brak widoczności aplikacyjnej.
5. **Brak data events w CloudTrail** → operacje S3/Lambda nie są audytowane.
6. **RShop i planodkupow mają dodatkowy link do management account (CloudWatch only)** — niespójne, stare residuum.
7. **monitoring-nagios-bot: 0 log groups** — sink działa jako agregatoer metryk, ale logi z 4 połączonych kont są dostępne cross-account, nie lokalnie.

CloudTrail PASS (z zastrzeżeniami). OAM PARTIAL. Log retention FAIL.

---

## 2. Konta organizacji

| Account ID | Nazwa | Rola |
|------------|-------|------|
| 864277686382 | makolab_dc | Management (Root) |
| 814662658531 | monitoring-nagios-bot | Monitoring (OAM sink, health events) |
| 771354139056 | LogArchiveNew | Log Archive (CloudTrail S3) |
| 943111679945 | RShop | Workload |
| 333320664022 | planodkupow | Workload |
| 128264038676 | Booking_Online | Workload |
| 074412166613 | dacia-asystent | Workload |
| 613448424242 | DRP-TFS | Workload |
| 292464762806 | planodkupowv1 | Workload |
| 647075515164 | Admin-MakoLab | Workload |
| 052845428574 | lab | Workload |
| 943696080604 | CC | Workload |

---

## 3. Metrics Coverage per Account (eu-central-1)

| Account | ECS | EC2/RDS | ALB/NLB | Lambda | GuardDuty | Container Insights | Observability Level |
|---------|-----|---------|---------|--------|-----------|-------------------|---------------------|
| RShop | ✓ | RDS ✓ | ALB ✓ | – | ✓ | ✓ | HIGH |
| planodkupow | ✓ | RDS ✓ | ALB ✓ | – | – | – | HIGH |
| dacia-asystent | ✓ | – | ALB ✓ | – | – | ✓ | MEDIUM |
| Booking_Online | ✓ | – | ALB ✓ | – | ✓ | – | MEDIUM |
| DRP-TFS | – | – | NLB ✓ | – | – | – | LOW (NLB+VPN+DynamoDB) |
| planodkupowv1 | – | EC2 ✓ | – | – | – | – | LOW (EC2+Firehose+States) |
| Admin-MakoLab | – | EC2 ✓ | – | – | – | – | LOW (EC2+EBS only) |
| lab | – | – | – | – | – | – | MINIMAL (DynamoDB+Rekognition) |
| CC | – | – | – | – | – | – | MINIMAL (Logs+S3+Usage only) |

**Źródło:** live AWS `cloudwatch list-metrics` eu-central-1.

**Uwaga:** Brak przestrzeni nazw ECS/ALB w koncie nie oznacza braku serwisów — może wskazywać na:
- inne regiony (nie sprawdzano us-east-1, eu-west-1, eu-west-2)
- brak włączonego Container Insights
- infrastrukturę non-ECS (EC2 native)

---

## 4. Cross-Account Observability (OAM)

### Sinks

| Konto | Nazwa sink | ARN |
|-------|-----------|-----|
| monitoring-nagios-bot (814662658531) | observabilitySink | `arn:aws:oam:eu-central-1:814662658531:sink/dc0f8121-...` |
| makolab_dc (864277686382) | org-observability-sink | `arn:aws:oam:eu-central-1:864277686382:sink/47f25adc-...` |

Oba sinki mają politykę org-wide (`aws:PrincipalOrgID = o-5c4d5k6io1`).

**Sink policy observabilitySink:** AllowOrganization — `oam:CreateLink + oam:UpdateLink` ✓

### Links do observabilitySink (monitoring-nagios-bot)

| Account | Label | Resource Types | Status |
|---------|-------|----------------|--------|
| RShop (943111679945) | RShop | Logs + CloudWatch + XRay | ✓ ACTIVE |
| planodkupow (333320664022) | planodkupow | Logs + CloudWatch + XRay | ✓ ACTIVE |
| dacia-asystent (074412166613) | dacia-asystent | Logs + CloudWatch + XRay | ✓ ACTIVE |
| Booking_Online (128264038676) | Booking_Online | Logs + CloudWatch + XRay | ✓ ACTIVE |
| DRP-TFS (613448424242) | – | – | ✗ MISSING |
| planodkupowv1 (292464762806) | – | – | ✗ MISSING |
| Admin-MakoLab (647075515164) | – | – | ✗ MISSING |
| lab (052845428574) | – | – | ✗ MISSING |
| CC (943696080604) | – | – | ✗ MISSING |
| LogArchiveNew (771354139056) | – | – | N/A (archive account) |
| monitoring-nagios-bot | – | – | N/A (jest sinkiem) |
| makolab_dc | – | – | N/A (ma własny sink; brak OAR dla assume-role) |

### Links do org-observability-sink (management account)

| Account | Resource Types | Uwaga |
|---------|----------------|-------|
| RShop | CloudWatch only | Stary link — Metrics, bez Logs/XRay |
| planodkupow | CloudWatch only | Stary link — Metrics, bez Logs/XRay |

**Źródło:** live AWS `oam list-links` per konto + `oam list-attached-links` na sink.

---

## 5. CloudWatch Logs (eu-central-1)

| Account | Log Groups | Never Expire | Short (<30d) | Ocena |
|---------|-----------|-------------|--------------|-------|
| planodkupow | 60 | **40 (67%)** | 20 | ⚠ WYSOKI koszt |
| DRP-TFS | 18 | **17 (94%)** | 0 | ⚠ WYSOKI koszt |
| RShop | 15 | 0 | 15 (all <30d) | OK (krótkie, ale ustawione) |
| dacia-asystent | 10 | 0 | 10 (all <30d) | OK |
| Booking_Online | 5 | 1 | 4 | Uwaga: 1 lambda log bez retencji |
| CC | 1 | 0 | 0 | Minimalne |
| planodkupowv1 | **0** | 0 | 0 | ⚠ BRAK LOGÓW |
| Admin-MakoLab | **0** | 0 | 0 | ⚠ BRAK LOGÓW |
| lab | **0** | 0 | 0 | ⚠ BRAK LOGÓW |
| monitoring-nagios-bot | 0 | 0 | 0 | OK (sink, nie workload) |
| makolab_dc | 0 | 0 | 0 | OK (management) |

**DRP-TFS never-expire (przykłady):**
- `/aws/application-signals/data`
- `/aws/codebuild/TerraformBuild`, `/aws/codebuild/TerraformDestroy`
- `/aws/codebuild/tfs-drp-build`, `/aws/codebuild/tfs-drp-destroy`

**planodkupow never-expire (przykłady):**
- `/aws/amazonmq/broker/*/channel`, `*/connection`, `*/federation`, `*/general`, `*/mirroring`

**Źródło:** live AWS `logs describe-log-groups` eu-central-1.

---

## 6. CloudTrail (Org Level)

| Parametr | Wartość | Status |
|----------|---------|--------|
| Nazwa | org-baseline-cloudtrail | ✓ |
| IsOrganizationTrail | true | ✓ |
| IsMultiRegionTrail | true | ✓ |
| IsLogging | true | ✓ |
| Ostatnia dostawa | 2026-05-02T11:34 | ✓ aktywny |
| Management events | ALL (Read + Write) | ✓ |
| Data events (S3) | BRAK | ⚠ |
| Data events (Lambda) | BRAK | ⚠ |
| S3 bucket | makolab-org-cloudtrail-logs-771354139056 | ✓ |
| Bucket account | LogArchiveNew (771354139056) | ✓ |
| Bucket encryption | aws:kms | ✓ |
| Bucket versioning | Enabled | ✓ |
| Bucket lifecycle | **BRAK** | ⚠ RYZYKO KOSZTÓW |
| S3 bucket policy | cloudtrail.amazonaws.com PutObject + GetBucketAcl | ✓ |
| Standalone trails w kontach workload | Brak (org trail jest widoczny we wszystkich kontach) | ✓ |

**Źródło:** live AWS `cloudtrail describe-trails` + `get-trail-status` + `get-event-selectors` + `s3api get-bucket-*`

---

## 7. Log Archive Account (LogArchiveNew)

| Element | Wartość | Status |
|---------|---------|--------|
| S3 buckets | 1: `makolab-org-cloudtrail-logs-771354139056` | ✓ |
| Encryption | aws:kms | ✓ |
| Versioning | Enabled | ✓ |
| Lifecycle policy | **BRAK** | ⚠ FAIL |
| Bucket policy | CloudTrail PutObject + GetBucketAcl | ✓ |
| OAM link | Brak (oczekiwane dla account archiwalnego) | N/A |

**Ryzyko:** bez lifecycle logi CloudTrail rosną w nieskończoność. Przy aktywnej org z 12 kontami i multi-region trail — to może być setki GB/rok.

---

## 8. LLZ Compliance Matrix

| Obszar | Status | Uzasadnienie |
|--------|--------|--------------|
| Metrics coverage | PARTIAL | 4/9 kont HIGH/MEDIUM; 5 kont LOW/MINIMAL w eu-central-1 |
| Cross-account observability (OAM) | PARTIAL | 4/9 kont podłączone do monitoring sink; 5 MISSING |
| Central logging (CloudTrail) | PARTIAL | Org trail aktywny, multi-region, KMS ✓; brak lifecycle + brak data events |
| Log retention | FAIL | 57/123 grup (>46%) z retencją Never expire; 3 konta bez żadnych logów |

---

## 9. Critical Findings (Top 10)

| # | Priorytet | Finding | Konto(a) |
|---|-----------|---------|----------|
| 1 | WYSOKI | 5 kont bez OAM link → niewidoczne w monitoring account | DRP-TFS, planodkupowv1, Admin-MakoLab, lab, CC |
| 2 | WYSOKI | 0 log groups w eu-central-1 → brak widoczności aplikacyjnej | planodkupowv1, Admin-MakoLab, lab |
| 3 | WYSOKI | 40/60 log groups bez retencji (Never expire) | planodkupow |
| 4 | WYSOKI | 17/18 log groups bez retencji (Never expire) | DRP-TFS |
| 5 | WYSOKI | Brak lifecycle policy na CloudTrail S3 bucket → koszty bez limitu | LogArchiveNew |
| 6 | ŚREDNI | Brak data events w CloudTrail (S3 + Lambda) → niepełny audit trail | org-wide |
| 7 | ŚREDNI | CC: tylko 3 CW namespaces — ekstremalnie niska widoczność | CC |
| 8 | ŚREDNI | Dwa OAM sinki (monitoring + management) — niespójność architektury | RShop, planodkupow |
| 9 | NISKI | 1 Lambda log group bez retencji | Booking_Online |
| 10 | NISKI | RShop, dacia-asystent: log retention <30d — ryzyko przy dłuższych incydentach | RShop, dacia-asystent |

---

## 10. Remediation Plan

### F1 — Dodaj OAM links dla 5 brakujących kont

**Konta:** DRP-TFS, planodkupowv1, Admin-MakoLab, lab, CC

**Terraform (platform/monitoring/ — analogicznie do istniejących linków):**

```hcl
resource "aws_oam_link" "drp_tfs" {
  provider           = aws.drp_tfs          # eu-central-1 w tym koncie
  label_template     = "$AccountName"
  resource_types     = [
    "AWS::CloudWatch::Metric",
    "AWS::Logs::LogGroup",
    "AWS::XRay::Trace",
  ]
  sink_identifier = "arn:aws:oam:eu-central-1:814662658531:sink/dc0f8121-e9d4-4103-afb0-7d8031e72570"
  tags = local.default_tags
}
# Powtórz dla planodkupowv1, admin_makolab, lab, cc
```

Wymagany provider per konto w `providers.tf` modułu monitoring.

---

### F2 — Ustaw retencję na log groups bez limitu

**Najważniejsze konta:** planodkupow (40 grup), DRP-TFS (17 grup)

Recommended: 90 dni dla prod, 30 dni dla non-prod.

**Terraform:**
```hcl
resource "aws_cloudwatch_log_group" "existing" {
  name              = "/aws/amazonmq/broker/.../general"
  retention_in_days = 90
}
```

Dla bulk update istniejących grup przed przejściem na Terraform:
```bash
# Diagnoza: lista grup bez retencji
aws logs describe-log-groups --region eu-central-1 \
  --query 'logGroups[?!retentionInDays].logGroupName' \
  --profile <profil> --output text
# Proposed only, do not run from context without approval.
# aws logs put-retention-policy --log-group-name <name> --retention-in-days 90
```

---

### F3 — Lifecycle policy na CloudTrail S3 bucket

**Konto:** LogArchiveNew

**Terraform (platform lub separate stack):**
```hcl
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = "makolab-org-cloudtrail-logs-771354139056"

  rule {
    id     = "cloudtrail-retention"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 365
      storage_class = "GLACIER"
    }
    expiration {
      days = 2555  # 7 lat (compliance minimum)
    }
  }
}
```

---

### F4 — CloudTrail data events

**Scope:** org-level trail

**Terraform (wysokopoziomowo):**
```hcl
resource "aws_cloudtrail" "org_baseline" {
  # ... existing config ...

  advanced_event_selector {
    name = "S3DataEvents"
    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }
    field_selector {
      field  = "resources.type"
      equals = ["AWS::S3::Object"]
    }
  }
}
```

**Uwaga kosztu:** data events S3 drastycznie zwiększają objętość CloudTrail → wycenić przed włączeniem; rozważyć only-write lub tylko wybrane buckety.

---

### F5 — Usuń stare linki OAM do management account

**Dotyczy:** RShop, planodkupow (linki CloudWatch-only do sink 864277686382)

Jeśli `org-observability-sink` w management nie jest aktywnie używany, usuń duplikaty z `platform/monitoring/` i usuń sam sink.

---

## Powiązane

- [[session-log]] (LLZ session log)
- `platform/monitoring/` — Terraform dla OAM sink/links
- `50-patterns/prompts/starter-pack/llz-observability-audit.md` — prompt użyty do tego audytu
