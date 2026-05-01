---
title: aws-cloud-platform-context
client: mako
project: aws-cloud-platform
domain: client-work
document_type: runtime-context
context_type: cloud-detective-snapshot
classification: internal
source_of_truth: false
runtime_snapshot: true
aws_profile: mako-dc
account_id: "864277686382"
regions:
  - eu-central-1
extra_regions:
  - us-east-1  # health-notifications EventBridge + Lambda (monitoring account)
iac: terraform
repository: "~/projekty/mako/aws-projects/aws-cloud-platform"
created: "2026-05-01"
updated: "2026-05-01"
last_verified: "2026-05-01"
scan_method: cloud-detective-v2
last_verified_by: claude
tags:
  - aws
  - terraform
  - mako
  - aws-cloud-platform
  - organizations
  - platform
---

# aws-cloud-platform — MakoLab AWS Organization Platform

#aws #terraform #organizations #platform #mako

**Data:** 2026-05-01
**Typ dokumentu:** snapshot runtime / context wejściowy
**Source of truth:** AWS live + IaC (Terraform)
**Tryb skanowania:** read-only
**Poziom pewności snapshotu:** częściowa — konto management sprawdzone live; zasoby cross-account (monitoring-nagios-bot) niezweryfikowane bezpośrednio (oparte na IaC + import blocks)
**Projekt:** Platforma organizacyjna MakoLab — AWS Organizations, governance (SCPs, tag policies), cross-account monitoring (OAM), health notifications
**OrgAccountID:** 864277686382
**Account ID:** `864277686382`
**Role:** jgol_cli (IAM user, management account)
**AWS profile:** `mako-dc`
**IAM principal:** `jgol_cli` *(arn:aws:iam::864277686382:user/jgol_cli)*
**Region główny:** `eu-central-1`
**Region dodatkowy:** `us-east-1` (health-notifications EventBridge + Lambda w koncie monitoring)

---

## Snapshot metadata

| Pole | Wartość |
|------|---------|
| scan_date | 2026-05-01 |
| scan_scope | partial |
| regions_checked | eu-central-1 (management account), us-east-1 (management account — tylko default bus) |
| repo_checked | tak |
| iac_checked | tak |
| runtime_checked | częściowe (management account live; monitoring account przez IaC/import blocks) |
| extra_regions_checked | us-east-1 (management account only — health bus w monitoring account niezweryfikowany) |

---

## Zakres snapshotu vs audytu

| Obszar | Typ | Zakres | Źródło |
|--------|-----|--------|--------|
| Organization structure (accounts, OUs) | snapshot | live AWS | live AWS |
| SCP — lista i stan | snapshot | live AWS — pełna lista | live AWS |
| Tag Policies — stan | snapshot | live AWS — list-policies | live AWS |
| CloudTrail — status i błędy dostawy | snapshot | live AWS — get-trail-status | live AWS |
| Terraform state backend | snapshot | live AWS — S3 + DynamoDB | live AWS |
| IaC analiza (SCPs, tag policies, platform modules) | snapshot | lokalny checkout | IaC |
| OAM monitoring (sink, links) | snapshot | IaC + import blocks; nie weryfikowane live w monitoring account | IaC |
| Health notifications (EventBridge, Lambda, SNS) | snapshot | IaC; nie weryfikowane live w monitoring account | IaC |
| SecurityHub, GuardDuty, Config | snapshot | live AWS — management account | live AWS |
| Tagging coverage | niezweryfikowane | nie wykonano resourcegroupstaggingapi scan | niezweryfikowane |
| FinOps / cost allocation | niezweryfikowane | brak osobnego audytu | niezweryfikowane |

---

## Repozytorium kodu

- lokalna ścieżka: `~/projekty/mako/aws-projects/aws-cloud-platform`
- remote: `https://gitlab.makolab.net/admin-makolab/dc/aws-cloud-platform.git`
- aktywny branch: `main`
- IaC: **Terraform** (provider hashicorp/aws v6.41.0)

IaC source of truth:
- `organization/governance/` — SCPs + Tag Policies (org-level governance)
- `platform/health-notifications/` — AWS Health event aggregation (monitoring account)
- `platform/monitoring/` — CloudWatch OAM cross-account observability (monitoring account)
- `bootstrap/`, `networking/`, `security/`, `workloads/` — puste (scaffolding)

---

## Środowiska / konta AWS Organizations

**Organizacja:** `o-5c4d5k6io1` | Root: `r-z8np`
**Typ:** `FeatureSet: ALL` | SCP: ENABLED | TAG_POLICY: ENABLED
**Management account:** `864277686382` (makolab_dc, dc@makolab.com)

| Account | ID | Email | OU | Status |
|---------|-----|-------|-----|--------|
| makolab_dc (management) | 864277686382 | dc@makolab.com | Root (management) | ACTIVE |
| monitoring-nagios-bot | 814662658531 | aws@makolab.pl | Platform OU | ACTIVE |
| Admin MakoLab | 647075515164 | admin@makolab.pl | Platform OU (hipoteza) | ACTIVE |
| lab | 052845428574 | lab@makolab.pl | Sandbox OU (hipoteza) | ACTIVE |
| LogArchiveNew | 771354139056 | log-archive-new@makolab.pl | Security OU (hipoteza) | ACTIVE |
| planodkupow | 333320664022 | planodkupow@makolab.pl | Production OU | ACTIVE |
| planodkupowv1 | 292464762806 | planodkupow1@makolab.pl | Production OU | ACTIVE |
| Booking_Online | 128264038676 | BookingOnline@makolab.pl | Production OU | ACTIVE |
| RShop | 943111679945 | rshop-dev@makolab.pl | Production OU | ACTIVE |
| dacia-asystent | 074412166613 | dacia-asystent@makolab.pl | Production OU | ACTIVE |
| CC | 943696080604 | CCAWS@makolab.com | Production OU | ACTIVE |
| DRP-TFS | 613448424242 | drptfs@makolab.pl | Production OU (hipoteza) | ACTIVE |
| Audit | 012086764624 | audit@makolab.info | Quarantine | SUSPENDED/CLOSED |
| Log Archive (stary) | 518286664393 | log@makolab.info | Quarantine | SUSPENDED/CLOSED |
| makolab_monitoring (stary) | 400837535641 | — | Quarantine | SUSPENDED/CLOSED |
| pbms | 378131232770 | — | Quarantine | SUSPENDED/CLOSED |
| MakolabDev | 442703586623 | — | Quarantine | SUSPENDED/CLOSED |

*Uwaga: przypisanie kont Platform/Security/Sandbox OU oparte na IaC locals + hipotezy — wymaga potwierdzenia przez `list-accounts-for-parent` per OU.*

Terraform state:
- Bucket: `864277686382-terraform-state-bucket` (eu-central-1, versioning: ENABLED)
- Lock table: `terraform-state-lock` (ACTIVE, PAY_PER_REQUEST)
- State keys:
  - `organization/governance/terraform.tfstate`
  - `platform/health-notifications/terraform.tfstate`
  - `platform/monitoring/terraform.tfstate` (hipoteza — backend.tf niezweryfikowany)

---

## Struktura OU

```text
Root (r-z8np)
├── Platform OU (ou-z8np-40w1yjwg)
│   └── monitoring-nagios-bot (814662658531)
│   └── Admin MakoLab (647075515164) — hipoteza
├── Quarantine OU (ou-z8np-807kci0k)
│   └── [SUSPENDED/CLOSED: Audit, Log Archive, MakolabDev, makolab_monitoring, pbms]
├── Sandbox OU (ou-z8np-dqtp5qcx)
│   └── [brak kont — lub lab: 052845428574 — wymaga potwierdzenia]
├── Security OU (ou-z8np-enuc6lre)
│   └── LogArchiveNew (771354139056) — hipoteza
└── Workloads OU (ou-z8np-ny08nzho)
    ├── Production OU (ou-z8np-jomloow3)
    │   ├── planodkupow (333320664022)
    │   ├── planodkupowv1 (292464762806)
    │   ├── Booking_Online (128264038676)
    │   ├── RShop (943111679945)
    │   ├── dacia-asystent (074412166613)
    │   ├── CC (943696080604)
    │   └── DRP-TFS (613448424242)
    └── NonProduction OU (ou-z8np-ydx42f96)
        └── [brak kont sprawdzonych — niezweryfikowane]
```

---

## Architektura

```text
Management (864277686382)
  ├── Organizations — org root, SCPs, Tag Policies
  ├── CloudTrail org-baseline (eu-central-1) → S3 (LogArchiveNew) [🔥 DELIVERY BROKEN]
  └── Terraform state S3 + DynamoDB

Platform: monitoring-nagios-bot (814662658531)
  ├── CloudWatch OAM Sink "observabilitySink" (eu-central-1)
  │   └── Links ← rshop, planodkupow, booking, dacia [Metrics, Logs, XRay]
  ├── SNS topic "health-notifications" (eu-central-1) [IaC]
  └── EventBridge bus "health-aggregation" (us-east-1) [IaC]
       └── Rule → Lambda "health_notify" (us-east-1) [IaC]
            └── → SNS topic (eu-central-1)

Per-account (health forwarding, us-east-1):
  rshop, planodkupow, booking, planodkupowv1, dacia, lab,
  admin_makolab, log_archive, cc, drp_tfs, nagios_bot
    └── EventBridge default bus → forward rule → health-aggregation bus (monitoring)
```

---

## Zasoby kluczowe

| Zasób | Identyfikator | Źródło | Pewność |
|-------|---------------|--------|---------|
| CloudTrail org-trail | `arn:aws:cloudtrail:eu-central-1:864277686382:trail/org-baseline-cloudtrail` | live AWS | wysoka |
| CloudTrail S3 bucket | `makolab-org-cloudtrail-logs-771354139056` (konto 771354139056) | live AWS | wysoka |
| CloudTrail KMS key | `arn:aws:kms:eu-central-1:771354139056:key/a6ce6c61-2bc7-4bab-b9b7-b556551983bb` | live AWS | wysoka |
| Terraform state bucket | `864277686382-terraform-state-bucket` (eu-central-1) | live AWS | wysoka |
| Terraform lock table | `terraform-state-lock` | live AWS | wysoka |
| SCP: FullAWSAccess | `p-FullAWSAccess` (AWS managed) | live AWS | wysoka |
| SCP: aws-guardrails-WCOddW | `p-26aljn7o` (Control Tower managed) | live AWS | wysoka |
| SCP: aws-guardrails-BbhyLy | `p-wacgblah` (Control Tower managed) | live AWS | wysoka |
| SCP: aws-guardrails-zTzmTA | `p-yncf8tm8` (Control Tower managed) | live AWS | wysoka |
| SCP: bilingi | `p-c6iuxb0c` (manual, untracked) | live AWS | wysoka |
| SCP: DEV | `p-yfwlx134` (manual, untracked) | live AWS | wysoka |
| OAM sink (management) | `arn:aws:oam:eu-central-1:864277686382:sink/47f25adc-26a3-491c-9a06-1cfc23203f42` (untracked) | live AWS | wysoka |
| OAM sink (monitoring) | `arn:aws:oam:eu-central-1:814662658531:sink/dc0f8121-e9d4-4103-afb0-7d8031e72570` | IaC (import) | średnia |
| OAM link rshop | `arn:aws:oam:eu-central-1:943111679945:link/8287c5bd-aa96-4b65-98e2-80ac2948c723` | IaC (import) | średnia |
| OAM link booking | `arn:aws:oam:eu-central-1:128264038676:link/271113ad-b90f-431e-b576-095d46886c24` | IaC (import) | średnia |
| OAM link planodkupow | `arn:aws:oam:eu-central-1:333320664022:link/d37c0cfb-4aa4-4b25-94ef-99874e3d51a3` | IaC (import) | średnia |

---

## Secrets Manager

Secrets Manager w koncie management: niezweryfikowane (list-secrets nie wykonano).
Projekt platformowy — sekrety operacyjne najpewniej nie są przechowywane w management account.

---

## ACM Certificates

Niezweryfikowane — acm list-certificates nie wykonano. Konto management nie hostuje workloadów z certyfikatami TLS.

---

## SCPs — stan live vs IaC

### Aktywne SCPs (live AWS)

| SCP | ID | Źródło | Tracking |
|-----|----|--------|---------|
| FullAWSAccess | p-FullAWSAccess | AWS managed | AWS managed |
| aws-guardrails-WCOddW | p-26aljn7o | Control Tower | poza IaC (CT managed) |
| aws-guardrails-BbhyLy | p-wacgblah | Control Tower | poza IaC (CT managed) |
| aws-guardrails-zTzmTA | p-yncf8tm8 | Control Tower | poza IaC (CT managed) |
| bilingi | p-c6iuxb0c | manual | **untracked** |
| DEV | p-yfwlx134 | manual | **untracked** |

### SCPs z IaC (niezdeplojowane)

| SCP | IaC resource | Stan | Uwagi |
|-----|-------------|------|-------|
| llz-quarantine-deny-all | `aws_organizations_policy.quarantine_deny_all` | **NIE ISTNIEJE w live** | Terraform nie był applied lub state stracony |
| llz-workloads-baseline | `aws_organizations_policy.workloads_baseline` | **NIE ISTNIEJE w live** | Terraform nie był applied lub state stracony |

**IaC drift: krytyczny** — governance SCPs nie zostały wdrożone.

### Tag Policies — stan live vs IaC

| Stan | Wartość |
|------|---------|
| TAG_POLICY feature | ENABLED (root) |
| tag_project policy (IaC) | NIE ISTNIEJE w live |
| tag_environment policy (IaC) | NIE ISTNIEJE w live |

**IaC drift:** Tag Policies zdefiniowane w `tag_policies.tf` nie są wdrożone.

---

## Tagging / FinOps / LLZ / AWS WAF readiness

Brak osobnego audytu tagów dla aws-cloud-platform — rekomendowane utworzenie dedicated tagging audit.
**Bieżący scan:** niezweryfikowane (resourcegroupstaggingapi nie wykonano dla konta management).

| Obszar | Status | Uwagi |
|--------|--------|-------|
| FinOps — cost allocation tags (Project/Environment/CostCenter) | niezweryfikowane | Brak scan live |
| LLZ tagging standard (Project/Environment/Owner/ManagedBy/CostCenter) | niezweryfikowane | Brak scan live |
| ECS/Fargate — tag propagation | nie dotyczy | Brak ECS w management account |
| ECR — tagi na repozytoriach | nie dotyczy | Brak ECR w management account |
| S3 — tagi na bucketach | niezweryfikowane | Terraform state bucket — tagi niezweryfikowane |
| CloudWatch Log Groups — tagi | niezweryfikowane | |
| VPC / Endpoints — tagi | nie dotyczy | Brak VPC workload w management |
| AWS WAF — obecność i przypisanie właściciela | nie dotyczy | Brak ALB/CloudFront w management account |

### Wymagane tagi LLZ (konto management)

| Tag | Oczekiwana wartość | Status |
|-----|--------------------|--------|
| Project | platform | nieustalone |
| Environment | prod | nieustalone |
| Owner | dc@makolab.com / team | nieustalone |
| ManagedBy | Terraform | nieustalone |
| CostCenter | — | nieustalone |

### Wniosek

Konto management jest kontem platformowym — tagging coverage niezweryfikowane. Tag Policies (IaC) definiują standard dla kont Workloads, ale nie zostały wdrożone. Brak WAF jest irrelewantny dla tego konta (brak workloadów HTTPS). FinOps coverage wymaga dedykowanego audytu po wdrożeniu tag policies.

### Następne kroki

| Akcja | Priorytet | Kto |
|-------|-----------|-----|
| Wdrożyć `organization/governance` Terraform | WYSOKI | jgol_cli |
| Zweryfikować tagging coverage po wdrożeniu tag policies | ŚREDNI | jgol_cli |

---

## Platform modules — stan

### CloudWatch OAM (cross-account monitoring)

| Zasób | Konto | Region | Stan | Źródło |
|-------|-------|--------|------|--------|
| OAM Sink `observabilitySink` | monitoring-nagios-bot (814662658531) | eu-central-1 | najpewniej deployed (import block w IaC) | IaC import |
| OAM Sink `org-observability-sink` | management (864277686382) | eu-central-1 | DEPLOYED — untracked | live AWS |
| OAM Link rshop | RShop (943111679945) | eu-central-1 | najpewniej deployed | IaC import |
| OAM Link booking | Booking_Online (128264038676) | eu-central-1 | najpewniej deployed | IaC import |
| OAM Link planodkupow | planodkupow (333320664022) | eu-central-1 | najpewniej deployed | IaC import |
| OAM Link dacia | dacia-asystent (074412166613) | eu-central-1 | najpewniej deployed (brak import block — tylko resource) | IaC |
| OAM resources types | — | — | CloudWatch::Metric, Logs::LogGroup, XRay::Trace | IaC |

**Uwaga:** OAM sink w management account (`org-observability-sink`) jest nieznannym zasobem niepowiązanym z IaC. Wymaga potwierdzenia — czy jest orphanem czy aktywnie używany.

### Health Notifications (EventBridge + Lambda)

Wszystkie zasoby w koncie monitoring-nagios-bot. Niezweryfikowane bezpośrednio — oparte na IaC.

| Zasób | Konto | Region | IaC stan |
|-------|-------|--------|----------|
| EventBridge bus `health-aggregation` | monitoring (814662658531) | us-east-1 | definiowany w IaC |
| Lambda `health_notify` | monitoring (814662658531) | us-east-1 | definiowany w IaC |
| SNS topic `health-notifications` | monitoring (814662658531) | eu-central-1 | definiowany w IaC |
| EventBridge forwarding rules (per konto) | 11 kont | us-east-1 | definiowane w IaC |
| IAM role `health-eventbridge-forward` | monitoring (814662658531) | — | definiowana w IaC |

Lambda: Python, wysyła do SNS email alert. SNS subscriber: `var.notification_email` (wartość niezweryfikowana — poza repo).

---

## Observability

**Runtime health (live, 2026-05-01):**

| Element | Status | Uwagi |
|---------|--------|-------|
| CloudTrail org-baseline | 🔥 DELIVERY BROKEN | IsLogging: True, ale `LatestDeliveryAttemptSucceeded: 2026-02-14` |
| Terraform state backend (S3) | OK | bucket active, versioning enabled |
| Terraform lock table (DynamoDB) | OK | ACTIVE, PAY_PER_REQUEST |
| OAM monitoring (management account) | PARTIAL | Sink widoczny live; links niezweryfikowane |
| SecurityHub | NIE WŁĄCZONY | management account |
| GuardDuty | NIE WŁĄCZONY | management account |
| AWS Config | NIE SKONFIGUROWANY | brak configuration recorder w management account |

**CloudWatch alarms:** niezweryfikowane (describe-alarms nie wykonano).

**Log groups:** niezweryfikowane.

---

## Znane problemy / dług techniczny

| Problem | Priorytet | Evidence | Opis |
|---------|-----------|----------|------|
| 🔥 CloudTrail S3 delivery failure | 🔥 CRITICAL | `LatestDeliveryError: AccessDenied`, `LatestDeliveryAttemptSucceeded: 2026-02-14` (live AWS) | KMS key policy w koncie LogArchiveNew nie pozwala roli delivery CloudTrail (`eagle-fra-prod-regional-delivery-role` z konta 035351147821) na GenerateDataKey. Logi org nie są persystowane od 2.5 miesiąca. |
| LLZ SCPs nie wdrożone | WYSOKI | `list-policies` zwróciło brak llz-* (live AWS) | `llz-quarantine-deny-all` i `llz-workloads-baseline` zdefiniowane w IaC, nieobecne w live. Konta Workloads bez LLZ guardrails. |
| Tag Policies nie wdrożone | WYSOKI | `list-policies TAG_POLICY` puste (live AWS) | `tag_project` i `tag_environment` zdefiniowane w `tag_policies.tf`, nie zastosowane. TAG_POLICY feature włączony ale brak polityk. |
| AWS Config nie skonfigurowany | WYSOKI | `describe-configuration-recorders` puste (live AWS) | Brak Config recorder w management account. SCP chroni Config w Workloads OU, ale Config musi być osobno włączony per konto. |
| SecurityHub nie włączony | WYSOKI | `GetEnabledStandards` error (live AWS) | Brak SecurityHub w management account. GAP względem LLZ/security readiness. |
| GuardDuty nie włączony | WYSOKI | `list-detectors` puste (live AWS) | Brak GuardDuty w management account. GAP względem LLZ/security readiness. |
| OAM sink `org-observability-sink` untracked | ŚREDNI | live AWS — oam list-sinks w management account | Sink w management account (864277686382) nie jest w IaC. Orphan lub ręcznie tworzony. |
| Control Tower guardrail SCPs — orphaned? | ŚREDNI | live AWS — 3x aws-guardrails-* SCP | CT Audit i Log Archive konta zamknięte; SCPs CT mogą być niezarządzane (CT wyłączone/porzucone). |
| Untracked SCPs: bilingi, DEV | ŚREDNI | live AWS — p-c6iuxb0c, p-yfwlx134 | Dwa SCP poza IaC. `bilingi` — restrict billing-only; `DEV` — "All FOR Dev". Scope i attachments niezweryfikowane. |
| Brak delegated administrators | ŚREDNI | `list-delegated-administrators` puste (live AWS) | Brak delegacji SecurityHub/Config/GuardDuty do centralnego konta. GAP względem LLZ enterprise readiness. |
| CloudTrail — brak data event selectors | NISKI | `get-event-selectors` (live AWS) | Trail loguje Management events (ReadWriteType: All); brak custom event selectors → brak loggowania S3/Lambda data events. Zależne od wymagań security. |
| bootstrap/networking/security/workloads — puste | INFO | IaC repo | Katalogi scaffolding bez kodu. Roadmap: implementacja kolejnych platform modules. |

---

## Różnice IaC vs Runtime

| Obszar | IaC | Runtime AWS | Ocena |
|--------|-----|-------------|-------|
| SCP llz-quarantine-deny-all | zdefiniowany | NIE ISTNIEJE | rozbieżność |
| SCP llz-workloads-baseline | zdefiniowany | NIE ISTNIEJE | rozbieżność |
| Tag Policy tag_project | zdefiniowana | NIE ISTNIEJE | rozbieżność |
| Tag Policy tag_environment | zdefiniowana | NIE ISTNIEJE | rozbieżność |
| OAM sink (management account) | NIE w IaC | `org-observability-sink` ISTNIEJE | rozbieżność |
| SCP bilingi / DEV | NIE w IaC | ISTNIEJĄ | rozbieżność |
| OU structure | 5 OUs + Production/NonProduction | zgodne | zgodne |
| Terraform state backend | zdefiniowany | ACTIVE | zgodne |
| CloudTrail org-trail | nie zarządzany przez ten repo | ISTNIEJE | niezweryfikowane (IaC poza tym repo) |

---

## Drift / niespójności architektury

| Obszar | Typ driftu | Źródło | Opis |
|--------|-----------|--------|------|
| LLZ SCPs | IaC vs runtime | live AWS | SCPs w IaC, brak w AWS. Najpewniej `terraform apply` nie był uruchomiony dla `organization/governance` w obecnym stanie. |
| Tag Policies | IaC vs runtime | live AWS | Policies w IaC, brak w AWS. |
| OAM sink w management account | manual change | live AWS | `org-observability-sink` w management account — nie zarządzany przez IaC monitoring module. |
| Untracked SCPs | manual change | live AWS | `bilingi` i `DEV` SCP poza IaC. |
| Control Tower SCPs | unknown | live AWS | 3x aws-guardrails-* bez aktywnego CT — czy są aktywnie zarządzane? |

---

## Pewność ustaleń

| Obszar | Pewność | Evidence | Uwagi |
|--------|---------|----------|-------|
| Organization struktura (konta, OUs) | wysoka | live AWS — list-accounts, list-organizational-units | |
| SCP lista (live) | wysoka | live AWS — list-policies | |
| CloudTrail status i błąd dostawy | wysoka | live AWS — get-trail-status | |
| Terraform state backend | wysoka | live AWS — S3, DynamoDB | |
| IaC drift (SCPs, tag policies) | wysoka | live AWS + IaC | |
| OAM monitoring (monitoring account) | średnia | IaC import blocks — nie weryfikowane live | Cross-account assume-role nie wykonano |
| Health-notifications (monitoring account) | niska | IaC — nie weryfikowane live | |
| Konta Platform/Security/Sandbox OU | niska | hipoteza | list-accounts-for-parent dla Platform/Security/Sandbox nie wykonano |

---

## Dostęp diagnostyczny

```bash
# Diagnoza: sprawdź CloudTrail delivery error
aws cloudtrail get-trail-status \
  --name org-baseline-cloudtrail \
  --profile mako-dc --region eu-central-1

# Diagnoza: sprawdź SCP listę i attachmenty
aws organizations list-policies --filter SERVICE_CONTROL_POLICY --profile mako-dc

# Diagnoza: sprawdź Tag Policies
aws organizations list-policies --filter TAG_POLICY --profile mako-dc

# Diagnoza: sprawdź konta w Platform/Security/Sandbox OU
aws organizations list-accounts-for-parent --parent-id ou-z8np-40w1yjwg --profile mako-dc  # Platform
aws organizations list-accounts-for-parent --parent-id ou-z8np-enuc6lre --profile mako-dc  # Security
aws organizations list-accounts-for-parent --parent-id ou-z8np-dqtp5qcx --profile mako-dc  # Sandbox

# Diagnoza: sprawdź OAM sink w management account
aws oam get-sink \
  --identifier arn:aws:oam:eu-central-1:864277686382:sink/47f25adc-26a3-491c-9a06-1cfc23203f42 \
  --profile mako-dc --region eu-central-1

# Diagnoza: sprawdź KMS key policy (CloudTrail delivery fix)
aws kms get-key-policy \
  --key-id "arn:aws:kms:eu-central-1:771354139056:key/a6ce6c61-2bc7-4bab-b9b7-b556551983bb" \
  --policy-name default \
  --profile mako-dc --region eu-central-1
```

```bash
# Diagnoza cross-account: monitoring-nagios-bot (wymaga OrganizationAccountAccessRole)
aws lambda list-functions \
  --region us-east-1 \
  --query 'Functions[?contains(FunctionName,`health`)].{name:FunctionName,state:State}' \
  --profile mako-dc  # lub assume-role do 814662658531

aws events list-event-buses --region us-east-1 --profile mako-dc  # jako management; lub cross-account

aws oam list-sinks --region eu-central-1  # weryfikuj w monitoring account
```

Proposed action: fix KMS key policy in LogArchiveNew account to allow CloudTrail delivery service principal (`cloudtrail.amazonaws.com` lub rola `eagle-fra-prod-regional-delivery-role`) na kms:GenerateDataKey i kms:Decrypt.

---

## Scheduler / automatyzacje

| Automatyzacja | Harmonogram | Zakres | Uwagi |
|--------------|-------------|--------|-------|
| EventBridge health forwarding | event-driven | per-account → monitoring | IaC, niezweryfikowane live |
| Health Lambda | event-driven | monitoring account us-east-1 | IaC, niezweryfikowane live |

---

## Aktualizacja dokumentacji po zmianach IaC

Nigdy nie łącz `terraform apply` z generowaniem dokumentacji — to dwa osobne kroki.

```bash
cd ~/projekty/mako/aws-projects/aws-cloud-platform/organization/governance
AWS_PROFILE=mako-dc terraform plan  # weryfikuj przed apply
# osobno po apply:
# uruchom ponownie cloud-detective przez plik invocation
```

---

## Źródła użyte

| Źródło | Zakres | Status |
|--------|--------|--------|
| live AWS | organizations (accounts, OUs, SCPs, tag policies), cloudtrail, s3, dynamodb, oam, lambda, events, securityhub, guardduty, config | sprawdzone (management account) |
| repo lokalne | ~/projekty/mako/aws-projects/aws-cloud-platform | sprawdzone |
| IaC | Terraform — governance, health-notifications, monitoring modules | sprawdzone |
| vault historyczny | nieużyte | nieużyte |
| extra_regions | us-east-1 (management account — default bus only; monitoring account niezweryfikowane) | częściowe |

## Fakty live vs historia vault

| Informacja | Status | Źródło | Uwagi |
|------------|--------|--------|-------|
| Org ID: o-5c4d5k6io1 | live | live AWS | |
| Management account: 864277686382 | live | live AWS | |
| CloudTrail delivery broken od 2026-02-14 | live | live AWS | |
| LLZ SCPs nie wdrożone | live | live AWS | |
| TAG_POLICY ENABLED | live | live AWS | |
| Tag Policies nie wdrożone | live | live AWS | |
| SecurityHub/GuardDuty/Config OFF | live | live AWS | |
| OAM sink management account | live | live AWS | |

Nie użyto danych historycznych z vault.

---

## Powiązane

- [[20-projects/internal/llz/]] — Light Landing Zone standard
- [[rshop-context]] — konto RShop z OAM link do monitoring
- [[booking-online-context]] — konto Booking_Online z OAM link
