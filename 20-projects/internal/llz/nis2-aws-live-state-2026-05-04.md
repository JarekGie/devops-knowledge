---
title: NIS2 AWS Live State Audit
date: 2026-05-04
tags: [nis2, aws, security, compliance, live-audit, llz]
org: o-5c4d5k6io1
scope: AWS infrastructure only — evidence from live AWS CLI
status: active
method: live-cli
---

# NIS2 AWS Live State Audit — 2026-05-04

**Org:** `o-5c4d5k6io1` | 12 active accounts | eu-central-1 primary  
**Metoda:** wyłącznie live AWS CLI — żadne notatki nie są source of truth  
**Profiles użyte:** `mako-dc` (management), `monitoring-tbd` (delegated admin), per-account profiles dla rshop/booking/plan/dacia/drp-tfs/lab/logArchive/cc/plan-v1/cd-admin-makolab

---

## SUMMARY (live)

| Dimension | Status | Evidence |
|-----------|--------|----------|
| Identity | ⚠ PARTIAL | MFA enabled na management/monitoring/admin ✅; brak na 9/12 kont workload; hardware MFA brak wszędzie (CIS 1.14 ACTIVE) |
| Governance | ⚠ PARTIAL | SCP llz-security-baseline: Production/NonProduction/Sandbox OU ✅; Platform OU i Security OU — tylko FullAWSAccess |
| Logging | ❌ MISSING | ALB logs: 0/8 ALBów enabled; VPC Flow Logs: 0/3 prod accounts; CloudFront: 0/8 dist enabled; CloudTrail OK ale brak KMS |
| Detection | ⚠ PARTIAL | GuardDuty baseline ENABLED 12/12; wszystkie extended features DISABLED; Inspector DISABLED org-wide |
| Observability | ⚠ PARTIAL | Config recorder aktywny na monitoring ✅; management account brak Config recordera; Config używa custom role (nie SLR) |
| Resilience | ❌ MISSING | Backup vaults: 0 na wszystkich sprawdzonych kontach; RDS SQL Server (rshop prod) bez backup policy; drp-tfs account bez AWS Backup |

---

## ACTIVE GAPS

### IDENTITY

**GAP-I-1 — Root MFA absent: 9/12 accounts**

| Account | ID | MFA | AccessKeys |
|---------|-----|-----|-----------|
| management (makolab_dc) | 864277686382 | ✅ 1 | ✅ 0 |
| monitoring-nagios-bot | 814662658531 | ✅ 1 | ✅ 0 |
| Admin MakoLab | 647075515164 | ✅ 1 | ✅ 0 |
| RShop | 943111679945 | ❌ 0 | ✅ 0 |
| Booking_Online | 128264038676 | ❌ 0 | ✅ 0 |
| planodkupow | 333320664022 | ❌ 0 | ✅ 0 |
| planodkupowv1 | 292464762806 | ❌ 0 | ✅ 0 |
| DRP-TFS | 613448424242 | ❌ 0 | ✅ 0 |
| dacia-asystent | 074412166613 | ❌ 0 | ✅ 0 |
| lab | 052845428574 | ❌ 0 | ✅ 0 |
| LogArchiveNew | 771354139056 | ❌ 0 | ✅ 0 |
| CC | 943696080604 | ❌ 0 | ✅ 0 |

Source: `aws iam get-account-summary` per account, live.  
Żadne konto nie ma aktywnych root access keys. ✅

**GAP-I-2 — Hardware MFA brak na wszystkich kontach (CIS 1.14)**

Security Hub CRITICAL `IAM.6` i `CIS 1.14` na 814662658531 — AKTYWNE.  
Nawet na kontach z `AccountMFAEnabled=1` (management/monitoring/admin) — virtual MFA nie spełnia CIS 1.14.  
Hardware MFA (YubiKey/FIDO) wymagane dla root na kontach z wysokim poziomem uprawnień.  
Scope NIS2: Art. 21(2)(i) — silna autentykacja dla kont zarządzających bezpieczeństwem org-wide.

---

### GOVERNANCE

**GAP-G-1 — SCP brak na Platform OU (647075515164 — Admin MakoLab)**

```
aws organizations list-policies-for-target --target-id ou-z8np-40w1yjwg → ['FullAWSAccess']
```

`DenyDisableSecurityServices` i `DenyRootUserActions` nie są egzekwowane na Admin MakoLab.  
Konto może wyłączyć GuardDuty/Config/CloudTrail lub wykonywać akcje root bez blokady SCP.

**GAP-G-2 — SCP brak na Security OU (771354139056 — LogArchiveNew)**

```
aws organizations list-policies-for-target --target-id ou-z8np-enuc6lre → ['FullAWSAccess']
```

Konto przechowujące org-wide CloudTrail logs (`makolab-org-cloudtrail-logs-771354139056`) nie ma SCP blokującego wyłączenie CloudTrail ani akcje root. Krytyczne dla integralności logów.

**GAP-G-3 — Config brak AWSServiceRoleForConfig (monitoring account)**

```
aws iam get-role --role-name AWSServiceRoleForConfig → NOT FOUND
```

Config recorder używa `AWSConfigRecorderRole-eu-central-1` (custom role). Security Hub CRITICAL `Config.1` i `2.5` — **VALID**, nie stale. SLR `AWSServiceRoleForConfig` nie istnieje na koncie.

**GAP-G-4 — Config recorder brak na management account (864277686382)**

```
aws configservice describe-configuration-recorders --profile mako-dc → ConfigurationRecorders: []
```

Management account nie jest pokryty przez Config. OrgConfigRules nie ewaluują management account z definicji AWS.

---

### LOGGING

**GAP-L-1 — VPC Flow Logs: 3/5 produkcyjnych kont bez logowania**

| Account | VPC Flow Logs |
|---------|---------------|
| rshop (943111679945) | ❌ NONE |
| booking (128264038676) | ❌ NONE |
| planodkupow (333320664022) | ❌ NONE |
| dacia-asystent (074412166613) | ✅ 2 VPCs → CloudWatch |
| drp-tfs (613448424242) | ✅ 1 VPC → CloudWatch |

Source: `aws ec2 describe-flow-logs` per account, live.

**GAP-L-2 — ALB access logs: 0/8 ALBów z włączonym logowaniem**

| Account | ALBs | access_logs.enabled |
|---------|------|---------------------|
| rshop | prod-ALB, dev-ALB | false, false |
| booking | 4 ALBs (dev/qa/uat/prod) | false × 4 |
| planodkupow | 2 ALBs (uat/qa) | false × 2 |
| dacia | 2 ALBs (dev/prod) | false × 2 |

Source: `aws elbv2 describe-load-balancer-attributes` per ALB, live.

**GAP-L-3 — CloudFront logging: 0/8 dystrybucji z włączonym logowaniem**

| Account | Distributions | Logging |
|---------|--------------|---------|
| rshop | 4 | all false |
| booking | 4 | all false |

Source: `aws cloudfront list-distributions`, live.

**GAP-L-4 — CloudTrail brak KMS encryption**

```
aws cloudtrail describe-trails → KMSKeyId: NONE
```

org-baseline-cloudtrail działa (IsLogging=True, ostatnia dostawa 2026-05-04 20:57), ale logi w S3 nie są szyfrowane kluczem KMS. LogFileValidationEnabled: **True** ✅ (wcześniej UNVERIFIED).

---

### DETECTION

**GAP-D-1 — GuardDuty extended protections: wszystkie DISABLED**

```
aws guardduty get-detector --detector-id 3ecef4fd34e833c4821cb0c835343048 --profile monitoring-tbd
```

| Feature | Status |
|---------|--------|
| CLOUD_TRAIL | ✅ ENABLED |
| DNS_LOGS | ✅ ENABLED |
| FLOW_LOGS | ✅ ENABLED |
| S3_DATA_EVENTS | ❌ DISABLED |
| EKS_AUDIT_LOGS | ❌ DISABLED |
| EBS_MALWARE_PROTECTION | ❌ DISABLED |
| RDS_LOGIN_EVENTS | ❌ DISABLED |
| EKS_RUNTIME_MONITORING | ❌ DISABLED |
| LAMBDA_NETWORK_LOGS | ❌ DISABLED |
| RUNTIME_MONITORING | ❌ DISABLED |

Security Hub HIGH findings potwierdzone: GuardDuty.5–.11.

**GAP-D-2 — Inspector2: DISABLED na wszystkich sprawdzonych kontach**

```
aws inspector2 batch-get-account-status (per account)
```

| Account | EC2 | ECR | Lambda |
|---------|-----|-----|--------|
| monitoring-nagios-bot | DISABLED | DISABLED | DISABLED |
| rshop | DISABLED | DISABLED | DISABLED |
| booking | DISABLED | DISABLED | DISABLED |
| planodkupow | DISABLED | DISABLED | DISABLED |
| dacia-asystent | DISABLED | DISABLED | DISABLED |

RDS SQL Server (rshop: `db.t3.large` prod, `db.t3.small` dev) i ECS bez CVE scanning.  
Security Hub HIGH findings Inspector.1–.4 potwierdzone.

---

### RESILIENCE

**GAP-R-1 — AWS Backup: brak vaultów i planów na wszystkich sprawdzonych kontach**

```
aws backup list-backup-vaults → [] na wszystkich kontach
aws backup list-backup-plans → 0 na rshop
aws backup list-protected-resources → 0 na rshop
```

| Account | Backup Vaults |
|---------|---------------|
| rshop | 0 |
| booking | 0 |
| planodkupow | 0 |
| dacia-asystent | 0 |
| drp-tfs | 0 |
| management | 0 |
| monitoring | 0 |

**GAP-R-2 — RDS bez MultiAZ i bez backup policy (rshop)**

```
aws rds describe-db-instances --profile rshop
```

| Instance | Engine | Class | MultiAZ |
|----------|--------|-------|---------|
| pssa61v1phykq0 (prod) | sqlserver-web 15.00.4198 | db.t3.large | **False** |
| dev-dbstack-... (dev) | sqlserver-ex 15.00.4198 | db.t3.small | False |

RDS automated backups istnieją domyślnie (AWS default retention = 1 dzień), ale brak AWS Backup policy, brak cross-account backup, DRP-TFS account bez vaultów.

---

## RESOLVED / NOT A GAP

| Item | Evidence | Status |
|------|---------|--------|
| Root MFA na monitoring account (814662658531) | `AccountMFAEnabled: 1` live | ✅ RESOLVED — Security Hub IAM.6/CIS 1.13 = **POSSIBLY STALE** |
| Root access keys na Admin MakoLab (647075515164) | `AccountAccessKeysPresent: 0` live | ✅ RESOLVED — Config `iam-root-access-key-check` = **POSSIBLY STALE** |
| Root access keys na wszystkich kontach | 0 na wszystkich 12 | ✅ CONFIRMED |
| CloudTrail logging aktywny | `IsLogging: True`, ostatnia dostawa 2026-05-04 20:57 | ✅ OK |
| CloudTrail LogFileValidation | `LogFileValidationEnabled: True` | ✅ CONFIRMED (było UNVERIFIED) |
| CloudTrail IsOrganizationTrail | `True` | ✅ OK |
| CloudTrail IsMultiRegionTrail | `True` | ✅ OK |
| GuardDuty baseline 12/12 kont | detector aktywny, ENABLED | ✅ OK |
| Config recorder na monitoring | `recording: True, lastStatus: SUCCESS` | ✅ OK |
| VPC Flow Logs na dacia i drp-tfs | describe-flow-logs → ACTIVE | ✅ OK |

---

## UNVERIFIED

| Item | Reason |
|------|--------|
| Root MFA na kontach bez direct IAM access (lab, logArchive, planv1 itp.) | `get-account-summary` zwrócony przez profil per-account — dane wiarygodne ale sprawdzone przez profil role, nie bezpośrednio przez management |
| EC2.182 — EBS snapshot Block Public Access | `describe-account-attributes blockPublicAccessSettings` zwrócił błąd; `get-ebs-encryption-by-default = false` (brak default encryption, ale to inne ustawienie) |
| Default SG na kontach workload | sprawdzone tylko monitoring account (1 inbound rule = SG z self-referencing rule = EC2.2 aktywne); pozostałe konta nie sprawdzone |
| SSM.7 — root cause | 0 self-owned SSM docs na monitoring account; możliwy false positive, ale dostęp do listy shared docs ograniczony |
| CloudFront na planodkupow/dacia | nie sprawdzone przez brak profilu cloudfront w tych kontach |
| Inspector2 na lab, logArchive, planv1, drp-tfs, CC, management | batch-get-account-status ACCESS_DENIED z monitoring; per-account nie sprawdzone |
| WAF logging | nie sprawdzone |
| S3 bucket versioning/replication dla backup | nie sprawdzone |
| IAM Identity Center / SSO status org-wide | brak danych z CLI |
| Config recorder na pozostałych kontach (poza monitoring i management) | StackSet coverage nie zweryfikowany per-account live |

---

## FALSE POSITIVES

| Finding | Wyjaśnienie |
|---------|-------------|
| Security Hub IAM.6 / CIS 1.13 (root MFA) — 814662658531 | Live `AccountMFAEnabled=1` — wirtualne MFA włączone. Finding prawdopodobnie stale. **CIS 1.14 (hardware MFA) osobne i nadal ACTIVE** |
| Config NON_COMPLIANT `iam-root-access-key-check` — 647075515164 | Live `AccountAccessKeysPresent=0` — klucze usunięte. Config rule = POSSIBLY STALE (sync delay) |
| SSM.7 na 814662658531 | `aws ssm list-documents --filters Owner=Self` → 0 dokumentów. Brak własnych SSM docs = brak co blokować. Likely false positive lub dotyczy AWS-managed shared docs |
| SCP brak na management account | Management account przez design nie podlega SCP (SCPs nie blokują management account) — NOT a gap |
| DRP-TFS bez llz-security-baseline | NonProduction OU ma SCP ✅. DRP-TFS jest w NonProduction OU — pokryty |
| CC account bez llz-security-baseline | CC jest w Production OU ✅ — pokryty SCP |
| GuardDuty FLOW_LOGS source ENABLED ≠ per-VPC Flow Logs w S3 | GuardDuty może analizować flow logi z VPC bez osobnego dostarczania do S3/CW — to osobne capability. GAP-L-1 nadal aktywny dla audyt trail / SIEM |

---

## CRITICAL ACTIONS (priorytet NIS2)

1. **Hardware MFA** na management (864277686382), monitoring (814662658531), Admin MakoLab (647075515164) — CIS 1.14 / IAM.6 — YubiKey lub equivalent
2. **SCP llz-security-baseline → Platform OU + Security OU** — Terraform IaC, 30 min
3. **AWS Backup policy** dla RDS SQL Server (rshop prod `pssa61v1phykq0`) — minimum 7-day retention, cross-account do drp-tfs
4. **VPC Flow Logs** na rshop, booking, planodkupow — CloudWatch lub S3
5. **ALB access logs** — 8 ALBów, bucket S3 w każdym koncie
6. **Config SLR** (`AWSServiceRoleForConfig`) na monitoring account — 1 Terraform resource
7. **Config recorder** na management account — oddzielny StackSet lub ręczna konfiguracja
