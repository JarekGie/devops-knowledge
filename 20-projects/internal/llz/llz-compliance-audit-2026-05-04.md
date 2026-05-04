---
title: LLZ Compliance Audit — post-wdrożenie
date: 2026-05-04
tags: [llz, aws, security, compliance, audit]
---

# LLZ Compliance Audit — 2026-05-04

Audyt stanu zgodności po wdrożeniu: SCP baseline, GuardDuty org-wide, AWS Config org-wide, Security Hub org-wide.

**Tryb:** read-only | **Org:** `o-5c4d5k6io1` | **Management:** `864277686382` | **Region:** eu-central-1

---

## 1. SCP — Status: OK ✅

| OU | llz-security-baseline |
|----|-----------------------|
| Root | NIE (oczekiwane) ✅ |
| Sandbox (ou-z8np-dqtp5qcx) | TAK ✅ |
| Workloads/Production (ou-z8np-jomloow3) | TAK ✅ |
| Workloads/NonProduction (ou-z8np-ydx42f96) | TAK ✅ |
| Platform (ou-z8np-40w1yjwg) | NIE (do weryfikacji) |
| Security (ou-z8np-enuc6lre) | NIE (do weryfikacji) |

Brak `aws-guardrails-*` (Control Tower SCP leftovers) ✅  
Dodatkowe SCP: `bilingi`, `DEV` — client-specific, poza LLZ scope.

---

## 2. GuardDuty — Status: OK ✅

- Delegated admin: `814662658531` (monitoring-nagios-bot) ✅
- Detector ID: `3ecef4fd34e833c4821cb0c835343048`
- Members: **11/11** Enabled (wszystkie aktywne konta + management account)
- Coverage: 12/12 kont

---

## 3. AWS Config — Status: PARTIAL ⚠️

| Komponent | Status |
|-----------|--------|
| Aggregator `org-aggregator` | ✅ SUCCEEDED (created 2026-05-02) |
| OrgConfigRules (5 baseline) | ✅ Wdrożone |
| StackSet `aws-config-org-recorder` | ACTIVE |
| StackSet CURRENT instances | 22 (11 kont × eu-central-1 + us-east-1) |
| StackSet OUTDATED | 10 (5 suspended/deleted kont) |
| Config recorder — `864277686382` (management) | ❌ **BRAK** |
| Config recorder — `814662658531` (monitoring) | ✅ recording=true |

> ❌ Management account poza zasięgiem Config. OrgConfigRules nie ewaluują management account z definicji.

Control Tower leftover rules w agregatorze (3 reguły `AWSControlTower_AWS-GR_*`) — do oczyszczenia.

---

## 4. Config Compliance — Status: PARTIAL ⚠️

| Rule | COMPLIANT | NON_COMPLIANT |
|------|-----------|---------------|
| cloudtrail-enabled | 11 | 0 ✅ |
| iam-root-access-key-check | 10 | **1 ⚠️** |
| multi-region-cloud-trail-enabled | 11 | 0 ✅ |
| s3-bucket-public-read-prohibited | 10 | 0 ✅ |
| s3-bucket-public-write-prohibited | 10 | 0 ✅ |

**NON_COMPLIANT:** `647075515164` (Admin MakoLab) — root access keys istnieją.

Management account (`864277686382`) niewidoczny w żadnej regule (brak recordera).

---

## 5. Security Hub — Status: OK ✅ (naprawione 2026-05-04)

| | |
|---|---|
| Delegated admin | `814662658531` ✅ |
| AutoEnable new members | true ✅ |
| AutoEnableStandards | ⚠️ NONE |
| **Members enrolled** | ✅ **11 / 11** |

Enrollment wykonany 2026-05-04 via `create-members` z konta delegated admin.  
Wszystkie 11 kont: MemberStatus=Enabled, `get-administrator-account` → `814662658531 Enabled` ✅  
Standards w member accounts: `[]` — brak duplikatów CIS/FSBP ✅

> ℹ️ Initial findings sync z nowo-enrolled kont: kilka minut do 24h na pełny initial scan.

---

## 6. Security Hub Findings (tylko monitoring account — pozostałe nie enrolled)

### CRITICAL (6)
| Finding | Opis |
|---------|------|
| Config.1 / 2.5 | AWS Config brak service-linked role |
| IAM.6 / 1.14 | Hardware MFA brak dla root user |
| 1.13 | MFA brak dla root user (814662658531) |
| SSM.7 | SSM documents block public sharing wyłączone |

### HIGH (14, wszystkie z 814662658531)
- EC2.2 / 4.3 — VPC default SG allows traffic
- EC2.182 — EBS snapshot BPA wyłączone
- GuardDuty.5-11 — Runtime/Malware/Lambda/S3/EKS/RDS protection wyłączone
- Inspector.1-4 — Inspector nie włączony

---

## 7. CloudTrail — Status: OK ✅

| | |
|---|---|
| Trail | `org-baseline-cloudtrail` |
| IsOrganizationTrail | true ✅ |
| IsMultiRegionTrail | true ✅ |
| IsLogging | true ✅ |
| LatestDelivery | 2026-05-04T11:36 (brak błędów) |
| S3 | `makolab-org-cloudtrail-logs-771354139056` |

---

## Executive Summary

| Kontrola | Status |
|----------|--------|
| SCP | ✅ OK |
| GuardDuty | ✅ OK |
| Config (infra) | ⚠️ PARTIAL |
| Config Compliance | ⚠️ PARTIAL |
| Security Hub | ❌ FAIL |
| CloudTrail | ✅ OK |

**Gotowość na AWS audit: NIE** — Security Hub bez enrollmentu i root bez MFA = blokery.

---

## Findings

### CRITICAL
- **C1** — Security Hub 0/11 members enrolled — org-wide visibility brak
- **C2** — Root bez MFA w monitoring account `814662658531` (delegated admin!)
- **C3** — Root access keys w `647075515164` (Admin MakoLab)

### HIGH
- **H1** — Config recorder brak w management account `864277686382`
- **H2** — Hardware MFA brak dla root monitoring account
- **H3** — Control Tower leftover Config rules (`AWSControlTower_AWS-GR_*`) w agregatorze

---

## Recommendations

1. **Security Hub enrollment** — enrolled 11 kont via `create-members` jako delegated admin (`814662658531`)
2. **Root MFA** — włączyć MFA dla root w `814662658531` (priorytet #1 przed audytem)
3. **Root access keys** — usunąć w `647075515164` → IAM → Security credentials
4. **Config — management account** — wdrożyć recorder ręcznie lub oddzielny StackSet
5. **StackSet cleanup** — usunąć OUTDATED instances (pbms, makolab_monitoring, MakolabDev + 2 deleted)
