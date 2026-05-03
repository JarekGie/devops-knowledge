---
title: AWS Cloud Platform — Dokumentacja projektu
project: aws-cloud-platform
type: confluence-page
updated: 2026-05-03
---

# AWS Cloud Platform — MakoLab

**Ostatnia aktualizacja:** 2026-05-03
**Repozytorium:** `gitlab.makolab.net/admin-makolab/dc/aws-cloud-platform`
**IaC:** Terraform >= 1.5 · AWS Provider >= 5.0
**Region główny:** eu-central-1
**Management account:** 864277686382 (makolab_dc)

---

## 1. Cel projektu

Platforma AWS MakoLab (Light Landing Zone) zarządza wspólną infrastrukturą całej organizacji AWS. Obejmuje:

- governance organizacji (konta, OU, SCP, polityki tagów)
- bezpieczeństwo org-wide (GuardDuty, Config, Security Hub, CloudTrail)
- observability cross-account (CloudWatch OAM, dashboardy, SLO alarms)
- alerty operacyjne (AWS Health → GLPI)
- cost management (budgets, anomaly detection)

Platforma jest wdrażana wyłącznie przez Terraform. Konto management (`864277686382`) nie hostuje workloadów — jest wyłącznie warstwą zarządzającą.

---

## 2. Struktura organizacji AWS

**Org ID:** `o-5c4d5k6io1` · **Feature set:** ALL · **SCP:** ENABLED · **TAG_POLICY:** ENABLED

```
Root (r-z8np)
├── makolab_dc (864277686382) — management account
├── Platform OU
│   ├── Admin MakoLab (647075515164)
│   └── monitoring-nagios-bot (814662658531) — delegated admin: GuardDuty, Config, Security Hub
├── Quarantine OU
│   ├── Audit (012086764624) — SUSPENDED
│   ├── MakolabDev (442703586623) — SUSPENDED
│   ├── Log Archive stary (518286664393) — SUSPENDED
│   └── makolab_monitoring (400837535641) — SUSPENDED
├── Sandbox OU
│   └── lab (052845428574) — ACTIVE
├── Security OU
│   └── LogArchiveNew (771354139056) — centralny log archive
└── Workloads OU
    ├── Production
    │   ├── planodkupow (333320664022)
    │   ├── planodkupowv1 (292464762806)
    │   ├── Booking_Online (128264038676)
    │   ├── RShop (943111679945)
    │   ├── dacia-asystent (074412166613)
    │   └── CC (943696080604)
    └── NonProduction
        └── DRP-TFS (613448424242)
```

---

## 3. Stan bezpieczeństwa (2026-05-03)

| Komponent | Status | Delegated admin | Uwagi |
|-----------|--------|-----------------|-------|
| **CloudTrail** org-wide | ✅ LIVE | — (management) | Naprawiony 2026-05-01 (KMS fix) |
| **GuardDuty** org-wide | ✅ LIVE | monitoring-nagios-bot | Auto-enable nowych kont |
| **AWS Config** org-wide | ✅ LIVE | monitoring-nagios-bot | 5 reguł baseline, StackSet na 11 kont |
| **Security Hub** org-wide | ✅ LIVE | monitoring-nagios-bot | FSBP v1.0 + CIS v1.2, auto-enable |
| **SCP security-baseline** | ✅ LIVE | — | Sandbox / NonProduction / Production OU |
| Root access key (Admin-MakoLab) | ✅ USUNIĘTY | — | Usunięty 2026-05-03, FTR compliant |
| MFA root (Admin-MakoLab) | ✅ WŁĄCZONE | — | 3 urządzenia |

### AWS Config — wdrożone reguły

| Reguła | Opis |
|--------|------|
| `CLOUD_TRAIL_ENABLED` | CloudTrail musi być aktywny |
| `IAM_ROOT_ACCESS_KEY_CHECK` | Brak aktywnych kluczy API dla root |
| `MULTI_REGION_CLOUD_TRAIL_ENABLED` | Multi-region trail wymagany |
| `S3_BUCKET_PUBLIC_READ_PROHIBITED` | Brak publicznego odczytu S3 |
| `S3_BUCKET_PUBLIC_WRITE_PROHIBITED` | Brak publicznego zapisu S3 |

### Security Hub — aktywne standardy

| Standard | Wersja | Status |
|----------|--------|--------|
| AWS Foundational Security Best Practices | v1.0.0 | READY |
| CIS AWS Foundations Benchmark | v1.2.0 | READY |

### SCP security-baseline — zakres

Reguła blokuje w Production, NonProduction i Sandbox:

- wyłączenie CloudTrail
- wyłączenie AWS Config
- wyłączenie GuardDuty
- operacje z regionów poza listą dozwolonych (eu-central-1 + us-east-1 + globalne)

---

## 4. Architektura platform

### 4.1 Observability — CloudWatch OAM

Cross-account monitoring oparty na AWS OAM (Observability Access Manager).

```
Management (864277686382)
  └── OAM Sink: org-observability-sink

Monitoring (814662658531)
  └── OAM Sink: observabilitySink
       ← Links od: RShop, Booking_Online, planodkupow, dacia-asystent
         (Metrics, Logs, X-Ray)
```

**Dashboardy** (CloudWatch, konto monitoring):
- Organization Health Overview
- SLO — RShop / Booking / Dacia (error rate + latency p99)
- Cost Explorer summary

**SLO Alarms:**

| Workload | Error rate SLO | Latency p99 SLO |
|----------|---------------|-----------------|
| RShop | < 1% | < 2 s |
| Booking_Online | < 1% | < 3 s |
| dacia-asystent | < 1% | < 3 s |

### 4.2 Health Notifications → GLPI

Pipeline:

```
Konta źródłowe (12, us-east-1)
  → EventBridge rule: health-to-monitoring
    → bus: health-aggregation (monitoring-nagios-bot, us-east-1)
      → rule: health-to-lambda
        → Lambda: health-notify (Python 3.12, us-east-1)
          → SNS: health-notifications (eu-central-1)
            → email: ops + glpi-aws-alerts@makolab.pl
```

Lambda przetwarza tylko eventy `issue` i `investigation` ze statusem `open`.

**Format ticketu GLPI:**

```
Subject: [GLPI][AWS][HEALTH][<ACCOUNT_NAME>][<REGION>][<SERVICE>][ISSUE] <EVENT_CODE>
```

Alarmy operacyjne (CloudWatch) monitorują Lambda Errors, Throttles oraz EventBridge FailedInvocations — powiadomienia na `health-ops-alerts` SNS.

### 4.3 Cloud Detective IAM

Rola `cloud-detective-agent` (management account) może przejąć rolę `CloudDetectiveReadOnly` w każdym z 11 kont member. Umożliwia read-only audyt infrastruktury przez CLI/Terraform bez uprawnień admin.

**Trust chain:**
```
operator (mako-dc profile) → cloud-detective-agent (864277686382) → CloudDetectiveReadOnly (<konto>)
```

Dostępne profile CLI: `cd-management`, `cd-admin-makolab`, `cd-monitoring-nagios-bot`, `cd-<konto>` (11 kont).

### 4.4 Cost Management

| Moduł | Opis |
|-------|------|
| `platform/budgets/` | Budżety miesięczne per konto, alerty email przy 80%/100% |
| `platform/finops/` | Anomaly detection (Cost Explorer), alerty SNS przy anomalii kosztowej |

---

## 5. Terraform — state backend

| Parametr | Wartość |
|----------|---------|
| Bucket | `864277686382-terraform-state-bucket` |
| Region | eu-central-1 |
| Lock table | `terraform-state-lock` (DynamoDB) |
| Szyfrowanie | SSE-S3 |
| Versioning | ENABLED |
| Profile | `mako-dc` |

### State keys (aktywne moduły)

| Moduł | State key |
|-------|-----------|
| organization/governance | `organization/governance/terraform.tfstate` |
| organization/scp | `organization/scp/terraform.tfstate` |
| platform/health-notifications | `platform/health-notifications/terraform.tfstate` |
| platform/monitoring | `platform/monitoring/terraform.tfstate` |
| platform/budgets | `platform/budgets/terraform.tfstate` |
| platform/finops | `platform/finops/terraform.tfstate` |
| platform/security/config | `platform/security/config/terraform.tfstate` |
| platform/security/security-hub | `platform/security/security-hub/terraform.tfstate` |
| security/cloud-detective | `security/cloud-detective/terraform.tfstate` |
| security/guardduty | `security/guardduty/terraform.tfstate` |

---

## 6. Dostęp

### Wymagania lokalne

- AWS CLI z profilem `mako-dc` (bezpośredni dostęp do management account)
- Profile `cd-*` (cross-account assume-role) — generowane przez:

```bash
scripts/generate-cloud-detective-profiles.sh
```

### IAM users (management account)

| User | Rola | Uwagi |
|------|------|-------|
| jgol_cli | operator DevOps | główny user ops |
| gitlab | CI/CD | GitLab pipeline |
| BillingViewer | billing | read-only |
| eryk.karpinski, jmarchel, mateusz.kmiecik, solejniczak | — | do weryfikacji zakresu |
| AzureADRoleManager, mikomax, popo, rote53.ipa, tribecloud | legacy | wymagają audytu |

### Root access (Admin-MakoLab — 647075515164)

| Element | Wartość |
|---------|---------|
| Root email | `admin@makolab.pl` |
| Hasło | KeePass (team) |
| MFA | 3 urządzenia |
| Klucze API | BRAK (usunięty 2026-05-03) |
| Tryb użycia | **break-glass only** — logowanie tylko w wyjątkowych sytuacjach, każde użycie dokumentowane |

---

## 7. Procedury operacyjne

### Deploy nowego modułu

```bash
cd platform/security/<moduł>
terraform init
terraform plan -out=tfplan
# weryfikuj: 0 destroy, tylko oczekiwane zasoby
terraform apply tfplan
```

### Weryfikacja Security Hub (findings)

```bash
aws securityhub get-findings \
  --filters '{"RecordState":[{"Value":"ACTIVE","Comparison":"EQUALS"}],"WorkflowStatus":[{"Value":"NEW","Comparison":"EQUALS"}]}' \
  --sort-criteria '{"Field":"LastObservedAt","SortOrder":"desc"}' \
  --max-items 20 \
  --profile cd-monitoring-nagios-bot \
  --query 'Findings[].{Title:Title,Severity:Severity.Label,Account:AwsAccountId}'
```

### Weryfikacja AWS Config compliance

```bash
aws configservice describe-compliance-by-config-rule \
  --profile cd-monitoring-nagios-bot \
  --query 'ComplianceByConfigRules[].{Rule:ConfigRuleName,Status:Compliance.ComplianceType}'
```

### Retencja CloudWatch Logs

```bash
# Dry-run — sprawdź log groups bez retencji
scripts/fix-log-retention.sh \
  --accounts-file scripts/accounts-llz.yaml \
  --dry-run \
  --region eu-central-1

# Apply retencji (prod: 90d, nonprod: 30d)
scripts/fix-log-retention.sh \
  --accounts-file scripts/accounts-llz.yaml \
  --region eu-central-1
```

### Test Health notifications (Lambda invoke)

```bash
# Zakładamy credentials do konta monitoring
CREDS=$(aws sts assume-role \
  --profile mako-dc \
  --role-arn arn:aws:iam::814662658531:role/OrganizationAccountAccessRole \
  --role-session-name health-test \
  --query 'Credentials' --output json)

export AWS_ACCESS_KEY_ID=$(echo $CREDS | jq -r .AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq -r .SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo $CREDS | jq -r .SessionToken)

aws lambda invoke \
  --function-name health-notify --region us-east-1 \
  --cli-binary-format raw-in-base64-out \
  --payload '{"account":"943111679945","region":"eu-central-1","detail":{"eventArn":"arn:aws:health:eu-central-1::event/RDS/TEST/001","service":"RDS","eventTypeCode":"AWS_RDS_TEST","eventTypeCategory":"issue","statusCode":"open","affectedEntities":[],"eventDescription":[{"language":"en_US","latestDescription":"Test invoke."}]}}' \
  /tmp/response.json && cat /tmp/response.json

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

---

## 8. Znane problemy i backlog

| # | Problem | Priorytet | Status |
|---|---------|-----------|--------|
| 1 | Tag Policies — zdefiniowane w IaC, nie wdrożone | WYSOKI | do apply |
| 2 | `organization/scp` quarantine-deny-all — nie wdrożony na Quarantine OU | ŚREDNI | do apply |
| 3 | SCP `bilingi` — unattached (brak targets) | ŚREDNI | do audytu / usunięcia |
| 4 | SCP `DEV` na SUSPENDED koncie MakolabDev | NISKI | cleanup |
| 5 | IAM users legacy (AzureADRoleManager, mikomax, popo) | ŚREDNI | audyt rotacji/usunięcia |
| 6 | Security Hub — CIS v1.2 generuje szum (log metric filters LOW) | NISKI | tuning controls |
| 7 | `platform/budgets` — moduł dodany, czeka na apply | ŚREDNI | do apply |
| 8 | `platform/finops` — moduł dodany, czeka na apply | ŚREDNI | do apply |
| 9 | Security Hub → GLPI pipeline (EventBridge → Lambda) | ŚREDNI | faza następna |
| 10 | CloudTrail — monitoring account bez Config service-linked role (Config.1 CRITICAL) | ŚREDNI | do naprawy |

---

## 9. Architektura zasobów — diagram

```
Management (864277686382 — makolab_dc)
  ├── AWS Organizations root r-z8np
  ├── CloudTrail: org-baseline-cloudtrail → S3 LogArchiveNew
  ├── OAM Sink: org-observability-sink
  ├── IAM: cloud-detective-agent
  └── Terraform state: S3 864277686382-terraform-state-bucket

Platform: monitoring-nagios-bot (814662658531)
  ├── GuardDuty delegated admin (org-wide)
  ├── AWS Config delegated admin (aggregator + rules StackSet)
  ├── Security Hub delegated admin (FSBP + CIS, org auto-enable)
  ├── OAM Sink: observabilitySink ← links RShop / Booking / planodkupow / dacia
  ├── CloudWatch dashboards + SLO alarms
  ├── EventBridge bus: health-aggregation (us-east-1)
  │     └── Lambda: health-notify → SNS health-notifications → email / GLPI
  └── SNS: security-hub-alerts (placeholder, przyszły pipeline)

Security: LogArchiveNew (771354139056)
  └── S3: makolab-org-cloudtrail-logs-771354139056 (CloudTrail destination)

Per konto (11 aktywnych):
  ├── IAM: CloudDetectiveReadOnly (trust: cloud-detective-agent)
  ├── CloudDetectiveReadOnly → GuardDuty member
  ├── AWS Config recorder (StackSet z management)
  └── Security Hub member (auto-enrolled)
```

---

## 10. Security Operations Model

Detekcja → agregacja → powiadomienie → naprawa — bez auto-remediacji.

| Krok | Źródło / narzędzie | Gdzie |
|------|--------------------|-------|
| Detekcja | GuardDuty, AWS Config (NON_COMPLIANT), Security Hub (FSBP/CIS), AWS Health | org-wide → monitoring account |
| Agregacja | Security Hub delegated admin | monitoring-nagios-bot (814662658531) |
| Powiadomienie | SNS email (current) · GLPI ticket (faza następna) | `glpi-aws-alerts@makolab.pl` |
| Reakcja | Platform / DevOps team | ręczna analiza findings |
| Naprawa | Terraform apply lub ręczna akcja w konsoli | brak auto-remediacji (by design) |
| Zamknięcie | Weryfikacja przez Config compliance lub re-check Security Hub | `describe-compliance-by-config-rule` |

---

## 11. Model odpowiedzialności

**Platform team (DevOps/SRE MakoLab) — owns:**
- AWS Organizations, OU, konta member
- SCP (guardrails org-wide)
- GuardDuty, AWS Config, Security Hub (org-level)
- CloudTrail, log archival (LogArchiveNew)
- IAM baseline: `cloud-detective-agent`, `CloudDetectiveReadOnly`, `OrganizationAccountAccessRole`
- Terraform state backend, moduły platformowe
- Monitoring cross-account (OAM, health notifications)

**Application teams — own:**
- IAM roles i policies dla własnych workloadów
- bezpieczeństwo aplikacji (OWASP, secrets management)
- patching AMI / kontenerów
- klasyfikacja i ochrona danych
- reagowanie na Security Hub findings dotyczące własnych zasobów

Granica: platform team zapewnia guardrails i visibility — nie zarządza zasobami aplikacyjnymi.

---

## 12. Własność findingów i eskalacja

| Typ findingu | Właściciel | SLA triage | Eskalacja |
|-------------|-----------|-----------|-----------|
| Security Hub CRITICAL/HIGH | Platform team | 24h | CTO + właściciel konta |
| Security Hub MEDIUM/LOW | Platform team | 72h | backlog sprint |
| Config NON_COMPLIANT | Platform team | 48h | właściciel konta jeśli workload-specific |
| GuardDuty finding | Platform team (triage) | 24h | właściciel konta jeśli workload-specific |
| AWS Health issue/investigation | Właściciel workloadu + platform CC | natychmiast | eskalacja do CTO jeśli konto produkcyjne |

**Workflow:**
1. Finding pojawia się w Security Hub / GuardDuty / AWS Health
2. SNS email → `ops@makolab.com` + `glpi-aws-alerts@makolab.pl`
3. Platform team ocenia severity i przypisuje właściciela
4. Naprawa przez Terraform lub ręczną akcję (brak auto-remediacji)
5. Zamknięcie finding po weryfikacji compliance

---

## 13. FTR Controls Mapping

| FTR Control | Komponent | Status |
|-------------|-----------|--------|
| FTR-1 — CloudTrail enabled | `security/cloudtrail` (org-baseline-cloudtrail) | ✅ COMPLIANT |
| FTR-3 — Threat detection | `security/guardduty` (org-wide, delegated admin) | ✅ COMPLIANT |
| FTR-4 — Config compliance | `platform/security/config` (5 reguł baseline) | ✅ COMPLIANT |
| FTR-5 — Security posture mgmt | `platform/security/security-hub` (FSBP + CIS) | ✅ COMPLIANT |
| FTR-12 — Cost controls | `platform/budgets` + `platform/finops` | ✅ (pending apply) |

**FTR blockers resolved:**
- Root access key (Admin-MakoLab) usunięty 2026-05-03 — `IAM_ROOT_ACCESS_KEY_CHECK` COMPLIANT

---

## 14. Znane problemy i ryzyka

| Gap | Typ | Priorytet |
|-----|-----|-----------|
| Brak dedykowanego konta Security — tooling w monitoring account | tymczasowy | NISKI (akceptowalny przy obecnej skali) |
| Brak automatycznego workflow incydentów (GLPI integration planned) | tymczasowy | ŚREDNI |
| Root access process częściowo manualny (KeePass + break-glass bez automation) | tymczasowy | ŚREDNI |
| Brak auto-remediacji Config/Security Hub | **celowy** | — |
| Control Tower częściowo usunięty — artefakty SCP orphaned (aws-guardrails-WCOddW) | ryzyko | NISKI |
| Tag Policies zdefiniowane w IaC, nie wdrożone | backlog | WYSOKI |
| Quarantine OU bez deny-all SCP | backlog | ŚREDNI |
| monitoring account bez Config service-linked role (Config.1 CRITICAL) | backlog | ŚREDNI |

---

## 15. Architecture Decision Record

### ADR-001: Security tooling w monitoring account zamiast dedykowanego Security account

**Data:** 2026-05-03  
**Status:** ACCEPTED

**Kontekst:**
AWS rekomenduje osobne konto Security dla narzędzi takich jak Security Hub, GuardDuty, Config. MakoLab ma istniejące konto `monitoring-nagios-bot` (814662658531), które już pełni rolę centrum widoczności operacyjnej (OAM, CloudWatch, health alerts).

**Decyzja:**
Używamy `monitoring-nagios-bot` jako delegated admin dla Security Hub, GuardDuty i AWS Config zamiast tworzenia osobnego konta Security.

**Uzasadnienie:**
- Brak budżetu i zasobów na zarządzanie dodatkowym kontem
- monitoring-nagios-bot już ma OAM sink i CloudWatch dashboardy — konsolidacja widoczności
- Przy obecnej skali organizacji (11 kont, brak regulacji compliance wymagających separacji) ryzyko jest akceptowalne

**Konsekwencje:**
- Jeśli konto monitoring zostanie skompromitowane — visibility + security tooling tracone jednocześnie
- Przyszła migracja do osobnego Security account jest możliwa przez zmianę delegated admin (bez utraty historii findingów)
- Znany gap: zarejestrowany w Risk Register jako NISKI priorytet
