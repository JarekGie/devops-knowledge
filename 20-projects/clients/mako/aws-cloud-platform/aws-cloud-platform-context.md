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
aws_profile: cd-management
account_id: "864277686382"
regions:
  - eu-central-1
extra_regions: []
iac: terraform
repository: "~/projekty/mako/aws-projects/aws-cloud-platform"
created: "2026-05-01"
updated: "2026-05-02"
last_verified: "2026-05-02"
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
**Tryb skanowania:** read-only (rola `cloud-detective-agent`)
**Poziom pewności snapshotu:** wysoka — management account w pełni sprawdzony live; konto monitoring (814662658531) i inne member accounts niezweryfikowane bezpośrednio, ale dostęp cross-account teraz możliwy przez `cd-<konto>` profile
**Projekt:** Platforma organizacyjna MakoLab — AWS Organizations, governance (SCPs, tag policies), Control Tower guardrails, cross-account monitoring (OAM), health notifications
**OrgAccountID:** 864277686382
**Account ID:** `864277686382`
**Role:** `cloud-detective-agent` (IAM role, read-only agent)
**AWS profile:** `cd-management`
**IAM principal:** `cloud-detective-agent` *(assumed-role via jgol_cli → mako-dc)*
**Region główny:** `eu-central-1`

---

## Snapshot metadata

| Pole | Wartość |
|------|---------|
| scan_date | 2026-05-01 |
| scan_scope | partial |
| regions_checked | eu-central-1 (management account) |
| repo_checked | tak |
| iac_checked | tak |
| runtime_checked | management account — pełne; member accounts — niezweryfikowane (możliwy dostęp przez cd-* profiles) |
| extra_regions_checked | nie dotyczy (brak workloadów w management account wymagających us-east-1) |

---

## Zakres snapshotu vs audytu

| Obszar | Typ | Zakres | Źródło |
|--------|-----|--------|--------|
| Organization structure (accounts, OUs) | snapshot | live AWS — pełna weryfikacja | live AWS |
| SCP — lista, stan, attachmenty | snapshot | live AWS — list-policies + list-targets-for-policy | live AWS |
| Tag Policies — stan | snapshot | live AWS — list-policies | live AWS |
| CloudTrail — status, błędy dostawy, konfiguracja | snapshot | live AWS — get-trail-status + get-trail | live AWS |
| KMS key policy (LogArchiveNew) | snapshot | live AWS — get-key-policy | live AWS |
| S3 bucket policy (CloudTrail) | snapshot | live AWS — get-bucket-policy | live AWS |
| Terraform state backend | snapshot | live AWS — S3 objects list | live AWS |
| IaC analiza (governance, platform modules) | snapshot | lokalny checkout | IaC |
| OAM monitoring (management account) | snapshot | live AWS | live AWS |
| OAM monitoring (monitoring account) | snapshot | IaC + import blocks | IaC |
| Health notifications (EventBridge, Lambda, SNS) | snapshot | IaC | IaC |
| SecurityHub, GuardDuty, Config | snapshot | live AWS — management account | live AWS |
| Tagging coverage (sample) | snapshot | live AWS — resourcegroupstaggingapi (2 zasoby) | live AWS / partial |
| FinOps / cost allocation | niezweryfikowane | brak osobnego audytu | niezweryfikowane |
| Member accounts (rshop, booking, etc.) | niezweryfikowane | nie sprawdzono w tym scanie | cd-* profiles dostępne |

---

## Repozytorium kodu

- lokalna ścieżka: `~/projekty/mako/aws-projects/aws-cloud-platform`
- remote: `https://gitlab.makolab.net/admin-makolab/dc/aws-cloud-platform.git`
- aktywny branch: `main`
- IaC: **Terraform** (provider hashicorp/aws >= 5.0)

IaC source of truth:
- `organization/governance/` — SCPs + Tag Policies (org-level governance)
- `platform/health-notifications/` — AWS Health event aggregation (monitoring account); 12 kont, Lambda DLQ, CW alarmy (stan: 2026-05-02)
- `platform/monitoring/` — CloudWatch OAM cross-account observability (monitoring account)
- `security/cloud-detective/` — cross-account read-only IAM roles (wdrożone 2026-05-01)
- `monitoring/org-dashboards/` — CloudWatch dashboards org-level
- `bootstrap/`, `networking/`, `security/`, `workloads/` — scaffolding (puste katalogi)

Dokumentacja operacyjna:
- `docs/operator/usage.md` — health-notifications (uruchomienie, GLPI, testowanie)
- `docs/operator/cloudwatch-log-retention.md` — polityka retencji logów, skrypt remediacji (dodane 2026-05-02)

Skrypty operacyjne:
- `scripts/fix-log-retention.sh` — remediacja retencji CloudWatch Logs (prod: 90d, nonprod: 30d)
- `scripts/accounts-llz.yaml` — lista kont LLZ z env assignment
- `scripts/generate-cloud-detective-profiles.sh` — generowanie profili AWS CLI

---

## Środowiska / konta AWS Organizations

**Organizacja:** `o-5c4d5k6io1` | Root: `r-z8np`
**Feature set:** `ALL` | SCP: ENABLED | TAG_POLICY: ENABLED
**Control Tower:** aktywny (controltower.amazonaws.com w org services access; 3x aws-guardrails-* SCP)
**Management account:** `864277686382` (makolab_dc)

| Account | ID | OU | Status |
|---------|-----|-----|--------|
| makolab_dc (management) | 864277686382 | Root (bezpośrednio) | ACTIVE |
| Admin MakoLab | 647075515164 | Platform | ACTIVE |
| monitoring-nagios-bot | 814662658531 | Platform | ACTIVE |
| lab | 052845428574 | Sandbox | ACTIVE |
| pbms | 378131232770 | Sandbox | SUSPENDED |
| LogArchiveNew | 771354139056 | Security | ACTIVE |
| planodkupow | 333320664022 | Workloads / Production | ACTIVE |
| planodkupowv1 | 292464762806 | Workloads / Production | ACTIVE |
| Booking_Online | 128264038676 | Workloads / Production | ACTIVE |
| RShop | 943111679945 | Workloads / Production | ACTIVE |
| dacia-asystent | 074412166613 | Workloads / Production | ACTIVE |
| CC | 943696080604 | Workloads / Production | ACTIVE |
| DRP-TFS | 613448424242 | Workloads / NonProduction | ACTIVE |
| Audit | 012086764624 | Quarantine | SUSPENDED |
| Log Archive (stary) | 518286664393 | Quarantine | SUSPENDED |
| makolab_monitoring (stary) | 400837535641 | Quarantine | SUSPENDED |
| MakolabDev | 442703586623 | Quarantine | SUSPENDED |

Terraform state backend:
- Bucket: `864277686382-terraform-state-bucket` (eu-central-1, versioning: ENABLED)
- Lock table: `terraform-state-lock` (ACTIVE, PAY_PER_REQUEST)
- State keys (sprawdzone live 2026-05-01):

| State key | Ostatnia modyfikacja |
|-----------|---------------------|
| `monitoring/org-dashboards/terraform.tfstate` | 2025-11-12 |
| `organization/governance/terraform.tfstate` | 2026-04-20 |
| `platform/health-notifications/terraform.tfstate` | 2026-05-02 |
| `platform/monitoring/terraform.tfstate` | 2026-04-18 |
| `security/cloud-detective/terraform.tfstate` | 2026-05-01 |

---

## Struktura OU (potwierdzona live 2026-05-01)

```text
Root (r-z8np)
├── makolab_dc (864277686382) — management account, bezpośrednio pod Root
├── Platform OU (ou-z8np-40w1yjwg)
│   ├── Admin MakoLab (647075515164)
│   └── monitoring-nagios-bot (814662658531)
├── Quarantine OU (ou-z8np-807kci0k)
│   ├── Audit (012086764624) — SUSPENDED
│   ├── MakolabDev (442703586623) — SUSPENDED [DEV SCP]
│   ├── Log Archive (518286664393) — SUSPENDED
│   └── makolab_monitoring (400837535641) — SUSPENDED
├── Sandbox OU (ou-z8np-dqtp5qcx)
│   ├── pbms (378131232770) — SUSPENDED
│   └── lab (052845428574) — ACTIVE
├── Security OU (ou-z8np-enuc6lre)
│   └── LogArchiveNew (771354139056) [CT guardrails: aws-guardrails-BbhyLy + zTzmTA]
└── Workloads OU (ou-z8np-ny08nzho)
    ├── Production sub-OU (ou-z8np-jomloow3)
    │   ├── planodkupow (333320664022)
    │   ├── planodkupowv1 (292464762806)
    │   ├── Booking_Online (128264038676)
    │   ├── RShop (943111679945)
    │   ├── dacia-asystent (074412166613)
    │   └── CC (943696080604)
    └── NonProduction sub-OU (ou-z8np-ydx42f96)
        └── DRP-TFS (613448424242)
```

---

## Architektura

```text
Management (864277686382) — makolab_dc
  ├── AWS Organizations — org root r-z8np
  │   ├── Control Tower guardrails (Security OU only)
  │   └── SCP/TAG_POLICY: ENABLED, brak LLZ SCPs w live
  ├── CloudTrail org-baseline (eu-central-1)
  │   └── → S3 makolab-org-cloudtrail-logs-771354139056 (LogArchiveNew)
  │       [🔥 DELIVERY BROKEN — root cause: KMS policy incompatibility]
  ├── OAM Sink "org-observability-sink" (Terraform, ManagedBy: Terraform)
  ├── EventBridge rule "org-cloudwatch-alarms-to-sns" (Terraform)
  ├── IAM role "cloud-detective-agent" (Terraform, read-only agent)
  └── Terraform state: S3 864277686382-terraform-state-bucket

Platform: monitoring-nagios-bot (814662658531)
  ├── CloudWatch OAM Sink "observabilitySink" (eu-central-1) [IaC import]
  │   └── Links ← rshop, planodkupow, booking, dacia [Metrics, Logs, XRay]
  ├── SNS topic "health-notifications" (eu-central-1) [IaC]
  └── EventBridge bus "health-aggregation" (us-east-1) [IaC]
       └── Rule → Lambda "health_notify" (us-east-1) [IaC]
            └── → SNS topic (eu-central-1)

LogArchiveNew (771354139056)
  ├── S3 "makolab-org-cloudtrail-logs-771354139056" (CloudTrail destination)
  ├── KMS key a6ce6c61-... "KMS for Organization CloudTrail logs" (Enabled)
  └── KMS key af0cf61f-... "KMS for Organization CloudTrail logs (LogArchive)" (Disabled)

Per-account: 11 kont ACTIVE
  └── IAM role CloudDetectiveReadOnly (Terraform, 2026-05-01)
       └── Trust: cloud-detective-agent (864277686382) + PrincipalOrgID
```

---

## IAM — cloud-detective (nowe, 2026-05-01)

| Zasób | Konto | ARN | IaC |
|-------|-------|-----|-----|
| cloud-detective-agent | management (864277686382) | arn:aws:iam::864277686382:role/cloud-detective-agent | Terraform security/cloud-detective/ |
| CloudDetectiveReadOnly | monitoring (814662658531) | arn:aws:iam::814662658531:role/CloudDetectiveReadOnly | Terraform security/cloud-detective/ |
| CloudDetectiveReadOnly | admin-makolab (647075515164) | arn:aws:iam::647075515164:role/CloudDetectiveReadOnly | Terraform security/cloud-detective/ |
| CloudDetectiveReadOnly | lab (052845428574) | arn:aws:iam::052845428574:role/CloudDetectiveReadOnly | Terraform security/cloud-detective/ |
| CloudDetectiveReadOnly | log-archive-new (771354139056) | arn:aws:iam::771354139056:role/CloudDetectiveReadOnly | Terraform security/cloud-detective/ |
| CloudDetectiveReadOnly | planodkupow (333320664022) | arn:aws:iam::333320664022:role/CloudDetectiveReadOnly | Terraform security/cloud-detective/ |
| CloudDetectiveReadOnly | planodkupowv1 (292464762806) | arn:aws:iam::292464762806:role/CloudDetectiveReadOnly | Terraform security/cloud-detective/ |
| CloudDetectiveReadOnly | booking (128264038676) | arn:aws:iam::128264038676:role/CloudDetectiveReadOnly | Terraform security/cloud-detective/ |
| CloudDetectiveReadOnly | rshop (943111679945) | arn:aws:iam::943111679945:role/CloudDetectiveReadOnly | Terraform security/cloud-detective/ |
| CloudDetectiveReadOnly | dacia (074412166613) | arn:aws:iam::074412166613:role/CloudDetectiveReadOnly | Terraform security/cloud-detective/ |
| CloudDetectiveReadOnly | cc (943696080604) | arn:aws:iam::943696080604:role/CloudDetectiveReadOnly | Terraform security/cloud-detective/ |
| CloudDetectiveReadOnly | drp-tfs (613448424242) | arn:aws:iam::613448424242:role/CloudDetectiveReadOnly | Terraform security/cloud-detective/ |

Trust chain: `jgol_cli → mako-dc profile → cloud-detective-agent (assume-role) → CloudDetectiveReadOnly (konto docelowe)`

Profil `cd-management` i 11 profili `cd-<konto>` wygenerowane w ~/.aws/config (2026-05-01).

---

## IAM users (management account)

| User | Created | Uwagi |
|------|---------|-------|
| jgol_cli | 2023-10-26 | główny user ops, brak inline policy AssumeCloudDetectiveAgent (ręczny krok) |
| AzureADRoleManager | 2019-07-31 | stary user — wymaga audytu |
| BillingViewer | 2024-12-10 | |
| eryk.karpinski | 2024-10-22 | |
| gitlab | 2025-08-25 | CI/CD |
| jmarchel | 2025-08-05 | |
| mateusz.kmiecik | 2026-02-19 | |
| mikomax / popo | 2019-08-05 / 2019-03-26 | bardzo stare, wymaga audytu |
| rote53.ipa | 2021-08-06 | |
| solejniczak | 2024-08-20 | |
| tribecloud | 2023-03-16 | |

---

## Zasoby kluczowe

| Zasób | Identyfikator | Źródło | Pewność |
|-------|---------------|--------|---------|
| CloudTrail org-trail | `arn:aws:cloudtrail:eu-central-1:864277686382:trail/org-baseline-cloudtrail` | live AWS | wysoka |
| CloudTrail — KMSKeyId | `None` — trail bez KMS; szyfrowanie S3 bucket SSE-KMS | live AWS | wysoka |
| CloudTrail S3 bucket | `makolab-org-cloudtrail-logs-771354139056` (konto 771354139056) | live AWS | wysoka |
| CloudTrail bucket encryption KMS | `a6ce6c61-2bc7-4bab-b9b7-b556551983bb` (LogArchiveNew, Enabled) | live AWS | wysoka |
| CloudTrail bucket encryption KMS (stary) | `af0cf61f-0313-4698-b047-3634e6f2b332` (LogArchiveNew, **Disabled**) | live AWS | wysoka |
| Terraform state bucket | `864277686382-terraform-state-bucket` (eu-central-1) | live AWS | wysoka |
| Terraform lock table | `terraform-state-lock` | live AWS | wysoka |
| SCP: FullAWSAccess | `p-FullAWSAccess` (AWS managed) | live AWS | wysoka |
| SCP: aws-guardrails-WCOddW | `p-26aljn7o` (CT managed, brak targets) | live AWS | wysoka |
| SCP: aws-guardrails-BbhyLy | `p-wacgblah` (CT managed → Security OU) | live AWS | wysoka |
| SCP: aws-guardrails-zTzmTA | `p-yncf8tm8` (CT managed → Security OU) | live AWS | wysoka |
| SCP: bilingi | `p-c6iuxb0c` (manual, **brak targets — unattached**) | live AWS | wysoka |
| SCP: DEV | `p-yfwlx134` (manual → MakolabDev account) | live AWS | wysoka |
| OAM sink (management) | `arn:aws:oam:eu-central-1:864277686382:sink/47f25adc-26a3-491c-9a06-1cfc23203f42` | live AWS | wysoka |
| OAM sink (monitoring) | `arn:aws:oam:eu-central-1:814662658531:sink/dc0f8121-e9d4-4103-afb0-7d8031e72570` | live AWS (2026-05-01) | wysoka |
| EventBridge rule | `org-cloudwatch-alarms-to-sns` (management, Terraform) | live AWS | wysoka |
| cloud-detective-agent role | `arn:aws:iam::864277686382:role/cloud-detective-agent` | live AWS | wysoka |

---

## Secrets Manager

Secrets Manager w koncie management (eu-central-1): niezweryfikowane (list-secrets nie wykonano).
Projekt platformowy — sekrety operacyjne najpewniej nie są przechowywane w management account.

Możliwe alternatywne źródła (niezweryfikowane):
- SSM Parameter Store
- CloudFormation parameters (NoEcho)
- CI/CD credentials (GitLab CI)

---

## ACM Certificates

`acm list-certificates --region eu-central-1` zwróciło **0 certyfikatów** (sprawdzone live).
Konto management nie hostuje workloadów z TLS. Brak certyfikatów zgodny z oczekiwaniami.

---

## SCPs — stan live vs IaC

### Aktywne SCPs (live AWS, potwierdzone 2026-05-01)

| SCP | ID | Targets | Tracking |
|-----|----|---------|---------|
| FullAWSAccess | p-FullAWSAccess | Root (inherited all) | AWS managed |
| aws-guardrails-WCOddW | p-26aljn7o | **brak targets** | CT managed (orphaned?) |
| aws-guardrails-BbhyLy | p-wacgblah | Security OU | CT managed |
| aws-guardrails-zTzmTA | p-yncf8tm8 | Security OU | CT managed |
| bilingi | p-c6iuxb0c | **brak targets** | manual, untracked |
| DEV | p-yfwlx134 | MakolabDev (SUSPENDED) | manual, untracked |

### Brakujące LLZ SCPs (IaC zdefiniowane, brak w live)

IaC locals.tf komentarz: `# SCP ID (po apply 2026-04-18): quarantine_deny_all: p-wxsdn4cy, workloads_baseline: p-flr98jkj`

Tych IDs nie ma w live AWS. Governance terraform state zmodyfikowany 2026-04-20 (2 dni po apply).
**Hipoteza:** SCPs zostały wdrożone 2026-04-18, następnie usunięte przez `terraform destroy` lub ręcznie 2026-04-20.
**Impact:** Quarantine OU bez deny-all. Workloads Production OU bez baseline guardrails.

| SCP (IaC) | Oczekiwany ID | Stan live | Impact |
|-----------|--------------|-----------|--------|
| llz-quarantine-deny-all | p-wxsdn4cy (z 2026-04-18) | **NIE ISTNIEJE** | Quarantine konta bez blokady |
| llz-workloads-baseline | p-flr98jkj (z 2026-04-18) | **NIE ISTNIEJE** | Production accounts bez LLZ guardrails |

### Tag Policies — stan live

TAG_POLICY feature: ENABLED (root)
Tag policies w live: **brak** (list-policies TAG_POLICY zwróciło pustą listę, sprawdzone live)
IaC: `tag_project` i `tag_environment` zdefiniowane w tag_policies.tf — nie wdrożone.

---

## CloudTrail — diagnoza root cause (potwierdzone 2026-05-01)

**Problem:** org-baseline-cloudtrail delivery broken od 2026-02-14 (`AccessDenied`).

**Konfiguracja:**

| Parametr | Wartość |
|----------|---------|
| Trail KMSKeyId | `None` — trail NIE ma własnego KMS |
| S3 bucket encryption | SSE-KMS z kluczem `a6ce6c61-...` (default bucket encryption) |
| Klucz aktywny | `a6ce6c61-...` (Enabled) |
| Klucz nieaktywny | `af0cf61f-...` (Disabled, stary) |

**Root cause — niezgodność konfiguracji:**

Klucz KMS (`a6ce6c61`) ma statement `AllowCloudTrailUseKey` z warunkiem:
```
"kms:EncryptionContext:aws:cloudtrail:arn": "arn:aws:cloudtrail:eu-central-1:864277686382:trail/org-baseline-cloudtrail"
```

Ten warunek jest spełniany **wyłącznie** gdy CloudTrail szyfruje dane sam (trail z `KMSKeyId`). Przy S3 SSE-KMS (default bucket encryption), S3 wywołuje KMS w imieniu zapisu — bez tego encryption context. Condition nigdy nie jest spełnione → AccessDenied.

**Opcje naprawy (do decyzji operatora):**

Opcja A — Dodaj `KMSKeyId` do trail:
```bash
# Proposed only, do not run from context. Requires explicit operator approval.
# aws cloudtrail update-trail \
#   --name org-baseline-cloudtrail \
#   --kms-key-id arn:aws:kms:eu-central-1:771354139056:key/a6ce6c61-2bc7-4bab-b9b7-b556551983bb \
#   --profile mako-dc --region eu-central-1
```

Opcja B — Usuń condition `kms:EncryptionContext:aws:cloudtrail:arn` z KMS key policy w LogArchiveNew.
Wymaga uprawnień IAM write w koncie 771354139056.

---

## Tagging / FinOps / LLZ / AWS WAF readiness

Brak osobnego audytu tagów dla aws-cloud-platform — rekomendowane utworzenie dedicated tagging audit.
**Bieżący scan:** sample-based (2 zasoby sprawdzone live przez resourcegroupstaggingapi: OAM sink + EventBridge rule).

| Obszar | Status | Uwagi |
|--------|--------|-------|
| FinOps — cost allocation tags (Project/Environment/CostCenter) | niezweryfikowane | Brak pełnego scan live |
| LLZ tagging standard (Project/Environment/Owner/ManagedBy/CostCenter) | PARTIAL | OAM sink ma Project+Environment+ManagedBy; EventBridge rule ma tylko ManagedBy |
| ECS/Fargate — tag propagation | nie dotyczy | Brak ECS w management account |
| ECR — tagi na repozytoriach | nie dotyczy | Brak ECR w management account |
| S3 — tagi na bucketach | niezweryfikowane | Terraform state bucket — tagi niezweryfikowane |
| CloudWatch Log Groups — tagi | niezweryfikowane | |
| VPC / Endpoints — tagi | nie dotyczy | Brak VPC workload w management |
| AWS WAF — obecność | nie dotyczy | Brak ALB/CloudFront w management account |

### Wymagane tagi LLZ (sample, konto management)

| Tag | Oczekiwana wartość | Status |
|-----|--------------------|--------|
| Project | platform / Observability | PARTIAL (OAM sink: tak; EventBridge rule: brak) |
| Environment | mgm / prod | PARTIAL (OAM sink: mgm; EventBridge rule: brak) |
| Owner | — | nieustalone |
| ManagedBy | Terraform | PARTIAL (oba sprawdzone zasoby: tak) |
| CostCenter | — | nieustalone |

### Wniosek

Konto management jest kontem platformowym bez workloadów HTTPS. Brak WAF jest nieistotny. Sample-based scan (2 zasoby) potwierdza że zasoby IaC mają tagi ManagedBy/Project — pełna weryfikacja wymaga `resourcegroupstaggingapi get-resources` bez filtra. Tag Policies nie wdrożone, więc brak enforcement na member accounts.

### Następne kroki

| Akcja | Priorytet | Kto |
|-------|-----------|-----|
| Naprawić CloudTrail delivery (Opcja A lub B) | WYSOKI | jgol_cli |
| Zbadać dlaczego LLZ SCPs usunięte po 2026-04-18 | WYSOKI | jgol_cli |
| Wdrożyć `organization/governance` (SCPs + tag policies) | WYSOKI | jgol_cli |
| Pełny tagging audit management account | ŚREDNI | jgol_cli |

---

## Platform modules — stan

### CloudWatch OAM (cross-account monitoring)

| Zasób | Konto | Region | Stan | Źródło |
|-------|-------|--------|------|--------|
| OAM Sink `org-observability-sink` | management (864277686382) | eu-central-1 | DEPLOYED, ManagedBy: Terraform, Project: Observability | live AWS |
| OAM Sink `observabilitySink` | monitoring (814662658531) | eu-central-1 | DEPLOYED, confirmed live 2026-05-01 | live AWS |
| OAM Link rshop | RShop (943111679945) | eu-central-1 | deployed (ARN w TF state: link/8287c5bd) | Terraform state |
| OAM Link booking | Booking_Online (128264038676) | eu-central-1 | deployed (ARN w TF state: link/271113ad) | Terraform state |
| OAM Link planodkupow | planodkupow (333320664022) | eu-central-1 | deployed (ARN w TF state: link/d37c0cfb) | Terraform state |
| OAM Link dacia | dacia-asystent (074412166613) | eu-central-1 | deployed (IaC resource, bez import bloku) | IaC |
| OAM Sink policy | management (864277686382) | eu-central-1 | AllowOrganization + PrincipalOrgID | live AWS |

**Uwaga:** `org-observability-sink` w management account (tagi: ManagedBy: Terraform, Project: Observability) to OSOBNY zasób od `observabilitySink` w monitoring account. Oba istnieją live. `observabilitySink` potwierdzony live 2026-05-01. Szczegóły → [[monitoring-context]].

### Health Notifications (EventBridge + Lambda)

Zasoby w koncie monitoring-nagios-bot — potwierdzone live 2026-05-01. Szczegóły → [[monitoring-context]].

| Zasób | Konto | Region | IaC stan |
|-------|-------|--------|----------|
| EventBridge bus `health-aggregation` | monitoring (814662658531) | us-east-1 | IaC |
| Lambda `health_notify` | monitoring (814662658531) | us-east-1 | IaC |
| SNS topic `health-notifications` | monitoring (814662658531) | eu-central-1 | IaC |
| EventBridge forwarding rules (per konto) | **12 kont** (incl. makolab_dc od 2026-05-02) | us-east-1 | IaC |
| SQS DLQ `health-eventbridge-dlq` | monitoring (814662658531) | us-east-1 | IaC (2026-05-02) |

### Cloud Detective IAM (nowe, 2026-05-01)

Moduł `security/cloud-detective/` wdrożony. 25 zasobów IAM. Szczegóły w sekcji IAM wyżej.

---

## Observability

**Runtime health (live, 2026-05-01):**

| Element | Status | Uwagi |
|---------|--------|-------|
| CloudTrail org-baseline | ✅ NAPRAWIONY 2026-05-01 | KMSKeyId dodany, KMS policy poprawiona (usunięto kms:GrantIsForAWSResource); LatestDeliveryError: null |
| Terraform state backend (S3) | OK | bucket active, versioning enabled |
| Terraform lock table (DynamoDB) | OK | ACTIVE, PAY_PER_REQUEST |
| OAM sink management account | OK | deployed, Terraform managed |
| OAM monitoring (monitoring account) | OK | Confirmed live 2026-05-01; Lambda Active, EventBridge ENABLED, SNS subscribed; szczegóły: [[monitoring-context]] |
| SecurityHub | NIE WŁĄCZONY | management account — GAP |
| GuardDuty | NIE WŁĄCZONY | management account — GAP |
| AWS Config | NIE SKONFIGUROWANY | brak configuration recorder — GAP |

**CloudWatch alarms:** 0 alarmów w eu-central-1 (describe-alarms wykonano, lista pusta).
EventBridge rule `org-cloudwatch-alarms-to-sns` istnieje (Terraform) — brak alarmów do forwarding.

**Log groups:** retencja ustawiona org-wide 2026-05-02 — 58 grup bez retencji → naprawione skryptem `scripts/fix-log-retention.sh` (prod: 90d, nonprod: 30d). Skrypt w repozytorium: `scripts/fix-log-retention.sh`, konfiguracja kont: `scripts/accounts-llz.yaml`.

---

## Znane problemy / dług techniczny

| Problem | Priorytet | Evidence | Opis |
|---------|-----------|----------|------|
| 🔥 CloudTrail S3 delivery failure | 🔥 CRITICAL | `LatestDeliveryError: AccessDenied`, LastDeliveryTime: 2026-02-14 (live AWS) | Trail bez KMS; S3 bucket SSE-KMS z condition `kms:EncryptionContext:aws:cloudtrail:arn` w key policy — condition niespełniany dla S3 SSE-KMS. Logi org nie są persystowane ~2.5 mies. Opcja A: dodaj KMSKeyId do trail. Opcja B: zmień KMS key policy. |
| LLZ SCPs usunięte po 2026-04-18 | WYSOKI | IaC locals.tf komentarz (SCP IDs p-wxsdn4cy, p-flr98jkj) vs live AWS (IDs nieobecne) | SCPs zostały wdrożone 2026-04-18, następnie usunięte (state 2026-04-20). Quarantine OU bez deny-all. Production bez LLZ baseline. Wymaga zbadania dlaczego usunięte. |
| Tag Policies nie wdrożone | WYSOKI | `list-policies TAG_POLICY` puste (live AWS) | `tag_project` i `tag_environment` w IaC — nie wdrożone. TAG_POLICY feature włączony. |
| AWS Config nie skonfigurowany | WYSOKI | describe-configuration-recorders puste (live AWS) | Brak Config recorder w management account. GAP security/compliance. |
| SecurityHub nie włączony | WYSOKI | InvalidAccessException (live AWS) | Brak SecurityHub w management account. GAP względem LLZ/security readiness. |
| GuardDuty nie włączony | WYSOKI | list-detectors puste (live AWS) | Brak GuardDuty w management account. GAP względem LLZ/security readiness. |
| Brak delegated administrators | WYSOKI | list-delegated-administrators puste (live AWS) | Brak delegacji SecurityHub/Config/GuardDuty do centralnego konta. |
| SCP aws-guardrails-WCOddW — brak targets | ŚREDNI | list-targets-for-policy puste (live AWS) | CT SCP bez przypisania — orphan po częściowym CT deploy/remove? |
| SCP bilingi — brak targets | ŚREDNI | list-targets-for-policy puste (live AWS) | Manual SCP bez przypisania — orphan, wymaga audytu i usunięcia lub przypisania. |
| SCP DEV na SUSPENDED account | ŚRODNI | DEV → MakolabDev (442703586623, SUSPENDED) | Nieaktywny, ale cleanup wskazany. |
| IAM users — stare konta | ŚREDNI | list-users (live AWS) | AzureADRoleManager (2019), mikomax (2019), popo (2019) — wymagają audytu rotacji/usunięcia. |
| jgol_cli — brak AssumeCloudDetectiveAgent inline policy | NISKI | ręczny krok po terraform apply 2026-05-01 | Policy nie dodana — cd-management działa przez mako-dc profile; jgol_cli CLI może wymagać tej zmiany. |
| bootstrap/networking/security/workloads — puste | INFO | IaC repo | Scaffolding bez kodu. |

---

## Różnice IaC vs Runtime

| Obszar | IaC | Runtime AWS | Ocena |
|--------|-----|-------------|-------|
| SCP llz-quarantine-deny-all | zdefiniowany (IaC) | NIE ISTNIEJE (live) | rozbieżność |
| SCP llz-workloads-baseline | zdefiniowany (IaC) | NIE ISTNIEJE (live) | rozbieżność |
| Tag Policy tag_project | zdefiniowana (IaC) | NIE ISTNIEJE (live) | rozbieżność |
| Tag Policy tag_environment | zdefiniowana (IaC) | NIE ISTNIEJE (live) | rozbieżność |
| CloudTrail KMS | trail bez KMS (live) | S3 bucket z SSE-KMS (live) | niezgodność — root cause delivery failure |
| OAM sink management account | najpewniej w IaC (ManagedBy: Terraform) | ISTNIEJE | zgodne |
| SCP bilingi / DEV | NIE w IaC | ISTNIEJĄ (unattached) | rozbieżność |
| cloud-detective IAM module | security/cloud-detective/ | DEPLOYED 2026-05-01 | zgodne |
| OU structure (5 OUs + Production/NonProduction) | IaC locals.tf | zgodne z live | zgodne |
| Terraform state backend | zdefiniowany | ACTIVE | zgodne |

---

## Drift / niespójności architektury

| Obszar | Typ driftu | Źródło | Opis |
|--------|-----------|--------|------|
| LLZ SCPs | IaC vs runtime | live AWS | SCPs wdrożone 2026-04-18, usunięte ~2026-04-20. State ostatnio modyfikowany 2026-04-20. |
| Tag Policies | IaC vs runtime | live AWS | Policies w IaC, brak w AWS. Prawdopodobnie `terraform destroy` lub nigdy apply. |
| CloudTrail encryption | konfiguracyjny | live AWS | Trail bez KMSKeyId + S3 SSE-KMS z encryption-context condition = niezgodność powodująca AccessDenied. |
| Untracked SCPs | manual change | live AWS | `bilingi` i `DEV` SCP poza IaC. |
| Control Tower SCPs orphaned? | unknown | live AWS | aws-guardrails-WCOddW bez targets — CT porzucone lub częściowe. |

---

## Pewność ustaleń

| Obszar | Pewność | Evidence | Uwagi |
|--------|---------|----------|-------|
| Organization struktura (konta, OUs, SC) | wysoka | live AWS — list-accounts, list-accounts-for-parent, list-parents | Pełna weryfikacja per OU 2026-05-01 |
| SCP lista + targets | wysoka | live AWS — list-policies + list-targets-for-policy | |
| CloudTrail status i root cause | wysoka | live AWS — get-trail-status + get-trail + KMS/S3 policies | KMS key policy i S3 bucket policy przeczytane live z LogArchiveNew |
| Terraform state backend i keys | wysoka | live AWS — S3 list-objects | |
| IaC drift (SCPs, tag policies) | wysoka | live AWS + IaC | |
| OAM monitoring (management account) | wysoka | live AWS — oam list-sinks, get-sink, get-sink-policy | |
| OAM monitoring (monitoring account) | średnia | IaC import blocks — nie weryfikowane live | cd-monitoring dostępny dla cross-account weryfikacji |
| Health-notifications (monitoring account) | niska | IaC — nie weryfikowane live | |
| IAM users management account | wysoka | live AWS — list-users | |

---

## Dostęp diagnostyczny

```bash
# Diagnoza: sprawdź CloudTrail delivery error
aws cloudtrail get-trail-status \
  --name org-baseline-cloudtrail \
  --profile cd-management --region eu-central-1

# Diagnoza: sprawdź KMS key policy w LogArchiveNew
aws kms get-key-policy \
  --key-id "arn:aws:kms:eu-central-1:771354139056:key/a6ce6c61-2bc7-4bab-b9b7-b556551983bb" \
  --policy-name default \
  --profile cd-logarchivenew --region eu-central-1

# Diagnoza: sprawdź SCP listę i targets
aws organizations list-policies --filter SERVICE_CONTROL_POLICY --profile cd-management
aws organizations list-targets-for-policy --policy-id p-c6iuxb0c --profile cd-management  # bilingi

# Diagnoza: sprawdź OAM monitoring account
aws oam list-sinks --profile cd-monitoring --region eu-central-1
aws lambda list-functions --profile cd-monitoring --region us-east-1 \
  --query 'Functions[?contains(FunctionName,`health`)].FunctionName'
```

```bash
# Proposed only, do not run from context. Requires explicit operator approval.
# Opcja A — dodaj KMSKeyId do trail (po akceptacji):
# aws cloudtrail update-trail \
#   --name org-baseline-cloudtrail \
#   --kms-key-id arn:aws:kms:eu-central-1:771354139056:key/a6ce6c61-2bc7-4bab-b9b7-b556551983bb \
#   --profile mako-dc --region eu-central-1
```

---

## Scheduler / automatyzacje

| Automatyzacja | Harmonogram | Zakres | Uwagi |
|--------------|-------------|--------|-------|
| EventBridge health forwarding | event-driven | 11 kont → monitoring | IaC, niezweryfikowane live |
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
| live AWS (management account, cd-management) | organizations (accounts, OUs, SCPs + targets, tag policies), cloudtrail (status + config), kms (key policies, LogArchiveNew), s3 (bucket policy, bucket objects), oam, cloudwatch (alarms), iam (users, roles), resourcegroupstaggingapi (sample), acm | sprawdzone |
| live AWS (LogArchiveNew, cd-logarchivenew) | kms key policies, s3 bucket policy + encryption, s3 objects (last delivery) | sprawdzone |
| repo lokalne | ~/projekty/mako/aws-projects/aws-cloud-platform | sprawdzone |
| IaC | Terraform — governance (scps.tf, tag_policies.tf, locals.tf), platform/monitoring (import blocks), security/cloud-detective | sprawdzone |
| vault historyczny | nieużyte | nieużyte |
| extra_regions | nie dotyczy | nie dotyczy |

## Fakty live vs historia vault

| Informacja | Status | Źródło | Uwagi |
|------------|--------|--------|-------|
| Org ID: o-5c4d5k6io1 | live | live AWS | |
| Management account: 864277686382 | live | live AWS | |
| CloudTrail delivery broken — root cause KMS policy incompatibility | live | live AWS | Precyzyjniejsza diagnoza vs poprzedni scan |
| OU assignments (Platform/Security/Sandbox) — potwierdzone | live | live AWS | Poprzedni scan: hipoteza; teraz: potwierdzone |
| LLZ SCPs wdrożone 2026-04-18, usunięte ~2026-04-20 | live+IaC | live AWS + IaC locals.tf | Nowe ustalenie — poprzedni scan: "nie wdrożone" |
| TAG_POLICY ENABLED, tag policies nie wdrożone | live | live AWS | |
| SecurityHub/GuardDuty/Config OFF | live | live AWS | |
| OAM sink management account — Terraform managed | live | live AWS | Poprzedni scan: "untracked" — teraz: ManagedBy: Terraform |
| cloud-detective IAM module — wdrożony 2026-05-01 | live | live AWS | Nowe |
| IAM users w management account (12 users) | live | live AWS | Nowe |
| Control Tower aktywny (controltower.amazonaws.com) | live | live AWS | Nowe |
| SCP bilingi unattached, DEV → MakolabDev | live | live AWS | Nowe — targets zweryfikowane |

Nie użyto danych historycznych z vault.

---

## Powiązane

- [[20-projects/internal/llz/]] — Light Landing Zone standard
- [[rshop-context]] — konto RShop z OAM link do monitoring
- [[booking-online-context]] — konto Booking_Online z OAM link
