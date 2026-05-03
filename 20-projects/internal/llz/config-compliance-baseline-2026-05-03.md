---
title: LLZ Config Compliance — Baseline Report 2026-05-03
tags:
  - aws
  - config
  - compliance
  - llz
  - finops
  - decision
date: 2026-05-03
---

# LLZ Config Compliance — Baseline Report

> [!info] Kontekst
> Pierwsze dane compliance po wdrożeniu Config Phase 3 (5 org-managed baseline rules).
> Dane zebrane: 2026-05-03 ~08:30 (ok. 15 min po apply).

## Rule Summary

| Reguła | COMPLIANT | NON_COMPLIANT | NO_DATA |
|---|---|---|---|
| cloudtrail-enabled | 11 | 0 | 0 |
| iam-root-access-key-check | 10 | **1** | 0 |
| multi-region-cloud-trail-enabled | 11 | 0 | 0 |
| s3-bucket-public-read-prohibited | 10 | 0 | 1 |
| s3-bucket-public-write-prohibited | 10 | 0 | 1 |

NO_DATA dla monitoring-nagios-bot (s3 rules) = brak bucketów S3 w tym koncie — oczekiwane.

## Per Account Matrix

| Konto | cloudtrail | root-key | multi-trail | s3-read | s3-write |
|---|---|---|---|---|---|
| Admin-MakoLab (647075515164) | ✅ | ❌ | ✅ | ✅ | ✅ |
| Booking_Online (128264038676) | ✅ | ✅ | ✅ | ✅ | ✅ |
| CC (943696080604) | ✅ | ✅ | ✅ | ✅ | ✅ |
| DRP-TFS (613448424242) | ✅ | ✅ | ✅ | ✅ | ✅ |
| LogArchiveNew (771354139056) | ✅ | ✅ | ✅ | ✅ | ✅ |
| RShop (943111679945) | ✅ | ✅ | ✅ | ✅ | ✅ |
| dacia-asystent (074412166613) | ✅ | ✅ | ✅ | ✅ | ✅ |
| lab (052845428574) | ✅ | ✅ | ✅ | ✅ | ✅ |
| monitoring-nagios-bot (814662658531) | ✅ | ✅ | ✅ | ⚪ | ⚪ |
| planodkupow (333320664022) | ✅ | ✅ | ✅ | ✅ | ✅ |
| planodkupowv1 (292464762806) | ✅ | ✅ | ✅ | ✅ | ✅ |

⚪ = NO_DATA (brak zasobów do oceny — nie jest problemem compliance)

## Critical Findings

### ❌ Admin-MakoLab — aktywny root access key

- **Konto:** Admin-MakoLab (647075515164)
- **Reguła:** `iam-root-access-key-check` (IAM_ROOT_ACCESS_KEY_CHECK)
- **Potwierdzone przez:** `iam get-account-summary` → `AccountAccessKeysPresent: 1`
- **MFA:** włączone (3 urządzenia) — częściowa mitigacja
- **Ryzyko:** Root access key to permanentne poświadczenia z pełnymi uprawnieniami do konta. Jeden wyciek = pełny kompromit konta.
- **Status FTR:** ❌ BLOCKER przed FTR
- **Akcja:** Usunąć root access key z konta Admin-MakoLab. Jeśli key jest używany — zastąpić rolą IAM lub federated identity.

> [!danger] FTR Blocker
> Active root access key = naruszenie AWS CIS Benchmark 1.4 oraz wymagania FTR SEC-3.

## Medium Findings

Brak. Wszystkie konta mają `multi-region-cloud-trail-enabled` = COMPLIANT.

## Low Findings

Brak. Żadne S3 bucket nie jest publicznie dostępny.

## False Positives

- **monitoring-nagios-bot s3-read/s3-write = NO_DATA**: oczekiwane — brak bucketów S3 w tym koncie. Nie jest problemem compliance.

## LLZ Compliance Score

- Łączne punkty oceny: 11 kont × 5 reguł = 55
- NO_DATA (nie podlega ocenie): 2 (monitoring-nagios-bot s3 rules)
- COMPLIANT: 52
- NON_COMPLIANT: 1

**Score: 52/53 = 98%** (z punktów które podlegają ocenie)

---

## Decyzja

### Czy baseline LLZ jest akceptowalny?

**TAK — z jednym wyjątkiem:** aktywny root access key na Admin-MakoLab.

Wynik 98% przy pierwszym uruchomieniu reguł to bardzo dobry wynik. Oznacza że:
- CloudTrail jest włączony wszędzie ✅
- Multi-region trail jest wszędzie ✅
- S3 buckets nie są publiczne (żadne) ✅
- Root keys: 10/11 kont clean ✅

### Co musi być naprawione przed FTR?

1. **❌ Usunąć root access key z Admin-MakoLab (647075515164)** — blocker

### Co może poczekać?

- Management account recorder (oddzielna architektura, nie blokuje FTR member accounts)
- Optional rules (ec2-ssm, rds-encrypted)

---

## Powiązane notatki

- [[session-log]] — historia wdrożeń Phase 2/3
- [[progress-tracker]] — WAF checklist LLZ
- [[config-compliance-check]] — runbook do ponownego sprawdzenia
