---
title: NIS2 Technical Assessment — AWS Infrastructure
date: 2026-05-04
tags: [nis2, aws, security, compliance, audit, llz]
org: o-5c4d5k6io1
scope: AWS infrastructure only (no processes, no documentation)
status: identified
---

# NIS2 Technical Assessment — AWS Infrastructure

**Org:** `o-5c4d5k6io1` | 12 accounts | eu-central-1 primary
**Data:** 2026-05-04 | **Tryb:** evidence-based, infrastructure only
**Powiązane:** [[llz-compliance-audit-2026-05-04]]

> Ocena wyłącznie warstwy technicznej AWS pod kątem wymagań NIS2.
> Brak oceny procesów, dokumentacji i polityk.

---

## 1. SUMMARY

| Wymiar | Status | Dowód |
|--------|--------|-------|
| Detection | ⚠ PARTIAL | GuardDuty org-wide ✅, rozszerzone ochrony wyłączone; Inspector brak |
| Logging | ⚠ PARTIAL | CloudTrail ✅ org-wide; VPC/ALB/CF logi częściowe; brak SIEM; CloudTrail nieszyfrowany |
| Identity | ❌ MISSING | Root MFA brak na koncie delegated admin; root access keys aktywne |
| Governance | ⚠ PARTIAL | SCP brak na Platform OU + Security OU; Config recorder brak na management account |
| Observability | ⚠ PARTIAL | OAM 6/12 kont; Security Hub 11/11 enrolled, 6 CRITICAL findings otwarte, brak auto-response |
| Resilience | ❌ MISSING | Konto DR istnieje, brak potwierdzonych polityk backup, RTO/RPO nieznane, brak testów restore |

---

## 2. CRITICAL GAPS (TOP 5)

### GAP 1 — Root MFA brak na security-critical account (814662658531)

- **Impact techniczny:** `814662658531` jest delegated admin dla GuardDuty, Security Hub i Config aggregator. Kompromitacja root = całkowita utrata org-wide threat detection i compliance visibility. Brak drugiego czynnika uwierzytelnienia.
- **NIS2:** Art. 21(2)(i) — MFA wymagane dla dostępów wpływających na bezpieczeństwo sieci i systemów informacyjnych.

### GAP 2 — Root access keys aktywne na koncie Platform OU (647075515164)

- **Impact techniczny:** Długożyciowe statyczne dane uwierzytelniające dla root usera Admin MakoLab. Kluczy root nie można ograniczyć zakresem, rotować przez IAM policy ani zablokować SCP. Config rule `iam-root-access-key-check` = NON_COMPLIANT.
- **NIS2:** Art. 21(2)(i) — programatyczne dane uwierzytelniające root bez wygaśnięcia są niezgodne z wymaganiami silnej kontroli dostępu.

### GAP 3 — AWS Inspector nie włączony (org-wide)

- **Impact techniczny:** Brak automatycznego skanowania podatności na instancjach EC2 i obrazach kontenerów (ECR). Security Hub HIGH finding `Inspector.1-4` potwierdzony. Produkcja (rshop, booking, planodkupow) bez detekcji CVE.
- **NIS2:** Art. 21(2)(e) — obsługa podatności wymaga technicznego proaktywnego skanowania jako minimum dla zarządzanej infrastruktury.

### GAP 4 — Brak potwierdzonych polityk backup i walidacji restore

- **Impact techniczny:** Konto DRP-TFS istnieje w NonProduction OU, ale brak AWS Backup policies, vaultów ani cross-account backup plans. RDS (SQL Server Web `db.t3.large` dla rshop), stan ECS i inne dane produkcyjne bez zweryfikowanej możliwości odtworzenia.
- **NIS2:** Art. 21(2)(c) — zarządzanie ciągłością działania wymaga technicznie zweryfikowanych mechanizmów, nie tylko istnienia konta DR.

### GAP 5 — SCP brak na Platform OU i Security OU

- **Impact techniczny:** `DenyDisableSecurityServices` i `DenyRootUserActions` NIE są podpięte pod Platform OU (`647075515164`) i Security OU (`771354139056`). Konto archiwum CloudTrail nie ma preventive control blokującego wyłączenie logowania ani akcje root. Atakujący z dostępem do `771354139056` może usunąć logi bez egzekucji SCP.
- **NIS2:** Art. 21(2)(d) — bezpieczeństwo sieci i systemów wymaga preventive controls na wszystkich warstwach, szczególnie na warstwie infrastruktury bezpieczeństwa.

---

## 3. FULL GAP LIST (AWS ONLY)

### Identity & Access

| Gap | Severity | Dowód |
|-----|----------|-------|
| Root MFA brak — `814662658531` (delegated admin) | CRITICAL | Security Hub IAM.6 / CIS 1.13 potwierdzony |
| Root access keys aktywne — `647075515164` (Admin MakoLab) | CRITICAL | Config `iam-root-access-key-check` NON_COMPLIANT |
| Root MFA status niezbadany — pozostałe 10 kont | HIGH | Brak audytu; Security Hub findings tylko z monitoring account |
| SCP `DenyRootUserActions` brak na Platform OU | HIGH | `list-targets-for-policy` — Platform OU nie podpięte |
| SCP `DenyRootUserActions` brak na Security OU (log archive) | HIGH | Security OU nie podpięte; konto CloudTrail bez ochrony |
| Brak SCP region restriction | MEDIUM | Celowo pominięty w v1; w backlogu |
| Brak enforcement hardware/phishing-resistant MFA przez IAM policy | MEDIUM | Security Hub finding `1.14`; SCP blokuje root actions ale nie wymusza typu MFA |

### Logging & Monitoring

| Gap | Severity | Dowód |
|-----|----------|-------|
| CloudTrail logi bez szyfrowania KMS | HIGH | Audit finding: "brak KMS encryption"; S3 `makolab-org-cloudtrail-logs-771354139056` |
| CloudTrail log file validation niepotwierdzone | MEDIUM | `EnableLogFileValidation` status niezweryfikowany |
| VPC Flow Logs częściowe — brak potwierdzenia per-VPC | HIGH | Observability audit: "VPC — backlog"; GD FLOW_LOGS data source ≠ per-VPC logi w S3/CW |
| ALB access logs nie włączone — rshop co najmniej | HIGH | Observability audit: "9 findings (ALB, CF, VPC — backlog)" |
| CloudFront standard logging nie włączone | MEDIUM | Ten sam backlog observability |
| OAM: 6/12 kont podłączonych | MEDIUM | CloudWatch OAM sink ma 6 źródeł; 6 kont bez cross-account metric/log access |
| Brak centralnego SIEM lub agregacji logów poza S3 CloudTrail | HIGH | Tylko S3; brak dowodów na CW Logs Insights aggregation, OpenSearch ani SIEM |
| WAF logging — status nieznany | MEDIUM | Brak potwierdzenia w audycie |
| Config recorder brak — management account `864277686382` | HIGH | StackSet wyklucza management account; OrgConfigRules go nie obejmują |

### Threat Detection

| Gap | Severity | Dowód |
|-----|----------|-------|
| GuardDuty Runtime Monitoring wyłączony | HIGH | Security Hub finding `GuardDuty.5` |
| GuardDuty Malware Protection wyłączony | HIGH | Security Hub finding `GuardDuty.6` |
| GuardDuty Lambda Protection wyłączony | HIGH | Security Hub finding `GuardDuty.7` |
| GuardDuty S3 Protection wyłączony | HIGH | Security Hub finding `GuardDuty.8` |
| GuardDuty EKS Protection wyłączony | HIGH | Security Hub finding `GuardDuty.9` |
| GuardDuty RDS Protection wyłączony | HIGH | Security Hub finding `GuardDuty.11` |
| AWS Inspector nie włączony org-wide | HIGH | Security Hub findings `Inspector.1-4` |
| 6 CRITICAL Security Hub findings otwarte bez auto-remediation | CRITICAL | IAM.6, Config.1/2.5, 1.13/1.14, SSM.7 — otwarte na 2026-05-04 |
| SSM documents block public sharing wyłączone — `SSM.7` | CRITICAL | Security Hub CRITICAL finding potwierdzony |
| Brak automatycznego incident response (Security Hub → Lambda/EventBridge) | HIGH | Brak dowodów auto-remediation rules w jakimkolwiek koncie |
| Security Hub AutoEnableStandards=NONE | MEDIUM | Nowe member accounts nie otrzymają CIS/FSBP automatycznie |

### Governance

| Gap | Severity | Dowód |
|-----|----------|-------|
| EBS Snapshot Block Public Access wyłączony | HIGH | Security Hub finding `EC2.182` |
| Default VPC security groups zezwalają na ruch | HIGH | Security Hub finding `EC2.2 / CIS 4.3` |
| Config rules: tylko 5 baseline rules | MEDIUM | Brak reguł dla: szyfrowania woluminów, MFA delete S3, IAM password policy, SG rules |
| Config aggregator: 10 OUTDATED StackSet instances | LOW | Suspended/deleted accounts nie wyczyszczone |
| Tag policy enforcement częściowy — projekty Terraform niezbadane | MEDIUM | rshop/planodkupow częściowe; zasoby Terraform-managed nie ocenione |

### Resilience

| Gap | Severity | Dowód |
|-----|----------|-------|
| Brak potwierdzonych AWS Backup policies | CRITICAL | Konto DRP-TFS istnieje; brak backup vaultów, planów, cross-account backup |
| Brak testów restore | HIGH | Otwarty HRI: "brak restore tests" |
| RTO/RPO niezdefiniowane technicznie | HIGH | Konto DR istnieje; parametry operacyjne nieokreślone |
| rshop ECS single task (desired=1, brak autoscalingu) | HIGH | `rshop-prod-api-svc` desired=1 potwierdzony w analizie incydentu 2026-05-04 |
| EBS Block Public Access nie włączony | HIGH | Wektor exfiltracji snapshotów; finding `EC2.182` |
| Brak potwierdzonych możliwości multi-region failover | MEDIUM | Wszystkie workloady eu-central-1; zakres DRP-TFS nieopisany |

---

## 4. FALSE POSITIVES

| Co wygląda jak gap | Dlaczego nim nie jest |
|--------------------|----------------------|
| Security Hub management account nie enrolled jako member | AWS Organizations by-design: management account nie może być enrollowany jako member delegated admin. Architectural constraint, nie misconfiguracja. |
| OrgConfigRules nie ewaluują management account | AWS by-design. Gap to brak Config recordera w tym koncie (osobna kwestia powyżej). |
| SCP nie podpięty do Root OU | Deliberate architecture — SCP na poziomie OU z explicit deny dają równoważną lub lepszą kontrolę. Nie jest luką jeśli wszystkie leaf OUs są pokryte. |
| GuardDuty FLOW_LOGS data source włączony, per-VPC Flow Logs brak | Różne funkcje. GD analizuje dane flow przez własną infrastrukturę niezależnie od per-VPC Flow Logs w CW/S3. Detekcja GD działa. Gap: forensics/audit logging — osobno w tabeli. |
| CloudTrail logi w S3 innego konta niż źródłowe | Best practice — log archive w izolowanym koncie `771354139056` (Security OU). Gap SCP na tym koncie to osobna pozycja. |
| Security Hub AutoEnableStandards=NONE | Celowa konfiguracja zapobiegająca duplikatom CIS/FSBP przy masowym enrollmencie. Standardy zarządzane centralnie w delegated admin account. |

---

## Podsumowanie techniczne

Org wdrożyła wszystkie 4 filary detekcji i compliance (GuardDuty / Config / Security Hub / CloudTrail) — to materialnie mocniejszy baseline niż większość AWS środowisk tej wielkości.

**Blokery NIS2 techniczne koncentrują się w 3 obszarach:**

| Obszar | Czas fixu | Priorytet |
|--------|-----------|-----------|
| Root credential hygiene (MFA + access keys) | ~30 min, konsola ręcznie | **Natychmiast** |
| Extended detection (Inspector + GuardDuty protections) | ~1-2h konfiguracja | Tydzień |
| Backup verification (AWS Backup + restore runbook) | Wymaga projektowania | Miesiąc |
