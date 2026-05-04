# Kontekst dla LLM — LLZ (Light Landing Zone)

> Wklej na początku sesji dotyczącej LLZ. Standalone — nie wymaga dodatkowych plików.
> Aktualizuj po każdej sesji implementacyjnej.

## Jak używać tego kontekstu z LLM

- Wklej ten plik na początku rozmowy jako kontekst bazowy
- Dodaj konkretny problem lub pytanie
- Jeśli temat dotyczy konkretnego projektu (rshop, planodkupow) — dołącz jego kontekst z `20-projects/`
- Nie wklejaj całego vault — tylko potrzebne fragmenty
- Przy pytaniach o stan — zweryfikuj w IaC/AWS, nie polegaj wyłącznie na tym dokumencie

---

**Projekt:** LLZ — Light Landing Zone (MakoLab platforma AWS)
**Zaktualizowano:** 2026-05-04
**Repozytoria:** `~/projekty/mako/aws-projects/aws-cloud-platform/` (Terraform IaC)

---

## Kim jestem

Senior DevOps/SRE, AWS-primary. Właściciel platformy AWS dla MakoLab — firmy IT świadczącej usługi cloud dla klientów zewnętrznych. Org multi-account (12 aktywnych kont). Vault wiedzy w Obsidian (Claude Code jako asystent). IaC: Terraform + CloudFormation.

---

## Czym jest LLZ

**Light Landing Zone** to wewnętrzny standard platformowy MakoLab. NIE jest to AWS Control Tower ani pełny Landing Zone — jest to minimalny zestaw standardów operacyjnych obejmujący:

| Wymiar | Narzędzie | Co audytuje |
|--------|-----------|-------------|
| **Scaffold conformance** | Terraform | struktura `envs/`, `backend.tf`, `versions.tf`, `project.yaml` |
| **Observability readiness** | AWS API | ECS logi, ALB access logs, VPC Flow Logs, CloudFront logging, ElastiCache |
| **Tagging governance** | CFN + Terraform | tagi `Project`/`Environment`/`ManagedBy`/`Owner`, AWS Tag Policies |
| **Org security baseline** | AWS Organizations | SCP, GuardDuty, Config, Security Hub, CloudTrail |

Narzędzie audytu: `devops-toolkit` — CLI (`toolkit audit-pack llz-basic`, `toolkit audit-pack aws-logging`, `toolkit audit-pack tagging`).

---

## Struktura organizacji AWS

```
Org ID: o-5c4d5k6io1
Management: 864277686382 (makolab_dc) — profil AWS: mako-dc

Root (FullAWSAccess SCP only)
├── Platform OU              ← NIE ma llz-security-baseline
│   └── Admin MakoLab        647075515164
├── Security OU              ← NIE ma llz-security-baseline
│   └── LogArchiveNew        771354139056  ← CloudTrail logs
├── Sandbox OU  ←────────────── llz-security-baseline ✅
│   └── lab                  052845428574
├── Quarantine OU
└── Workloads OU
    ├── Production OU  ←─────── llz-security-baseline ✅
    │   ├── planodkupow       333320664022
    │   ├── planodkupowv1     292464762806
    │   ├── Booking_Online    128264038676
    │   ├── RShop             943111679945
    │   ├── dacia-asystent    074412166613
    │   └── CC                943696080604  (konto INVITED — klient zewnętrzny)
    └── NonProduction OU  ←──── llz-security-baseline ✅
        └── DRP-TFS           613448424242

Delegated admins:
  GuardDuty:    monitoring-nagios-bot  814662658531
  Security Hub: monitoring-nagios-bot  814662658531
  Config:       monitoring-nagios-bot  814662658531 (aggregator)
```

Terraform state: S3 `864277686382-terraform-state-bucket` + DynamoDB `terraform-state-lock` (eu-central-1).

---

## Co jest wdrożone — stan na 2026-05-04

### 1. SCP — llz-security-baseline ✅ LIVE (2026-05-02)

Podpięty do: Sandbox OU, Workloads/Production OU, Workloads/NonProduction OU.  
NIE podpięty do: Root (zamierzony), Platform OU, Security OU.

Zawiera:
- `DenyDisableSecurityServices` — blokuje wyłączenie GuardDuty, Config, CloudTrail, Security Hub
- `DenyRootUserActions` — blokuje akcje root usera

Brak: region restriction (planowane w kolejnej fazie).

### 2. GuardDuty org-wide ✅ LIVE (2026-05-02)

- Delegated admin: `monitoring-nagios-bot` (814662658531)
- Members: **12/12 kont** Enabled
- auto_enable = ALL (nowe konta automatycznie)
- Baseline: CLOUD_TRAIL, DNS_LOGS, FLOW_LOGS

### 3. AWS Config org-wide ✅ LIVE (2026-05-02)

- Aggregator: `org-aggregator` w monitoring-nagios-bot
- OrgConfigRules (5 baseline, z management account):
  - `cloudtrail-enabled`
  - `iam-root-access-key-check`
  - `multi-region-cloud-trail-enabled`
  - `s3-bucket-public-read-prohibited`
  - `s3-bucket-public-write-prohibited`
- StackSet `aws-config-org-recorder`: ACTIVE, CURRENT na 11/12 kont (eu-central-1 + us-east-1)
- **Gap:** management account (864277686382) nie ma Config recordera — OrgConfigRules nie obejmują management account z definicji

**Compliance na 2026-05-04:**

| Rule | COMPLIANT | NON_COMPLIANT |
|------|-----------|---------------|
| cloudtrail-enabled | 11/11 | 0 |
| iam-root-access-key-check | 10/11 | **1 ⚠️** Admin MakoLab (647075515164) |
| multi-region-cloud-trail-enabled | 11/11 | 0 |
| s3-bucket-public-read-prohibited | 10/10 | 0 |
| s3-bucket-public-write-prohibited | 10/10 | 0 |

### 4. Security Hub org-wide ✅ LIVE (2026-05-04)

- Delegated admin: `monitoring-nagios-bot` (814662658531)
- Members enrolled: **11/11** (MemberStatus=Enabled)
- AutoEnable: true (nowe konta automatycznie)
- AutoEnableStandards: NONE (standardy nie włączają się automatycznie)
- Istniejące standardy w monitoring account: CIS AWS Foundations v1.2.0, FSBP v1.0.0
- **Uwaga:** initial findings sync z nowo-enrolled kont może trwać do 24h

**Findings (monitoring account, 2026-05-04):**

| Severity | Count | Główne tematy |
|----------|-------|---------------|
| CRITICAL | 6 | Root bez MFA (1.13/IAM.6), Config SLR (Config.1/2.5), SSM public (SSM.7) |
| HIGH | 14 | VPC default SG, EBS BPA, GuardDuty Runtime/Malware/Lambda/S3/EKS/RDS, Inspector |

### 5. CloudTrail org-trail ✅ LIVE (pre-existing, audit 2026-05-04)

- Trail: `org-baseline-cloudtrail`
- IsOrganizationTrail: true, IsMultiRegionTrail: true
- Logging aktywny, ostatnia dostawa 2026-05-04
- S3: `makolab-org-cloudtrail-logs-771354139056` (LogArchiveNew)
- **Gap:** brak KMS encryption, log file validation nieaudytowana

### 6. Centralna observability

- CloudWatch OAM sink `observabilitySink` w monitoring-nagios-bot (814662658531)
- **6 kont** podłączonych jako sources: rshop, booking, planodkupow, dacia + 2 dodane 2026-05-02
- SLO alarms: rshop/booking/dacia/planodkupow (bbmt-uat) — 8 alarmów, error rate + latency p99
- CloudTrail org trail → S3 LogArchiveNew ✅

### 7. AWS Health notifications ✅ (IaC: `aws-cloud-platform/platform/health-notifications/`)

- EventBridge rules (us-east-1) w każdym z 11 kont → bus `health-aggregation` (monitoring-nagios-bot)
- Lambda (Python 3.12, us-east-1) → SNS topic (eu-central-1) → email
- Filtr: statusCode=open + eventTypeCategory=issue|investigation

### 8. Tagging standard (LLZ v1)

```
Wymagane:  Project, Environment
Zalecane:  ManagedBy, Owner
Enforce:   AWS Tag Policies (org Root) — llz-project + llz-environment
```

### 9. Budgets + Cost Anomaly Detection ✅ (2026-05-02)

- 28 budgetów (21 importowanych + 7 nowych) — pokrycie wszystkich 12 kont
- Cost Anomaly Detection: org-level DIMENSIONAL/SERVICE, threshold $50+20%, SNS us-east-1

---

## Otwarte CRITICAL (stan 2026-05-04)

| Problem | Konto | Priorytet |
|---------|-------|-----------|
| Root user **bez MFA** | 814662658531 (monitoring, delegated admin) | **BLOKER FTR** — ręcznie w konsoli |
| Root **access keys aktywne** | 647075515164 (Admin MakoLab) | **BLOKER FTR** — Config NON_COMPLIANT |
| Config recorder **brak** | 864277686382 (management) | HIGH — oddzielny StackSet lub ręcznie |

---

## WAF + FTR status — stan 2026-05-04

**Overall WAF: ~40%** (było ~30% w 2026-04)

| Pillar | Stan | Zmiana | Główne luki |
|--------|------|--------|-------------|
| Operational Excellence | ~40% | → | Brak SLO, brak CI/CD dla IaC |
| Security | ~45% | ↑ | Root MFA (CRITICAL), brak IR plan |
| Reliability | ~30% | → | Brak DR plan, brak restore tests |
| Performance | ~40% | → | Brak right-sizing, brak load testing |
| Cost | ~40% | ↑ | All On-Demand (brak Savings Plans) |
| Sustainability | ~40% | → | Brak Graviton, brak S3 lifecycle standard |
| Organizations Governance | ~40% | ↑↑ | Root MFA, IAM Identity Center |
| **FTR Partner Readiness** | **~60%** | **↑↑** | **FTR 6 (Root MFA) = jedyny bloker** |

**Rozwiązane HRI (2026-05-02/04):**
- ~~GuardDuty wyłączony~~ → ✅ 12/12 kont
- ~~Brak SCP preventive controls~~ → ✅ llz-security-baseline live
- ~~Brak AWS Config org-wide~~ → ✅ deployed
- ~~Security Hub 0 members~~ → ✅ 11/11 enrolled

**Aktywne HRI:**
1. **Root bez MFA** w monitoring account (delegated admin) — Security Hub CRITICAL
2. **Root access keys** w Admin MakoLab — Config NON_COMPLIANT
3. Brak formalnego DR plan (konto DRP-TFS istnieje, RTO/RPO nieudokumentowane)
4. Brak IR plan

**FTR:** z 3 blokerów (Config, Security Hub, GuardDuty) zostały 0. Jedyny bloker = Root MFA (FTR 6). Szacowany czas do FTR readiness: 1-2 dni operacyjne.

---

## Aktualny fokus (2026-05)

1. **Root MFA** w monitoring account (814662658531) — ręcznie w konsoli, 15 min, odblokowuje FTR
2. **Root access keys** w Admin MakoLab (647075515164) — usuń w konsoli, 5 min
3. **Config recorder** w management account (864277686382) — StackSet lub ręcznie
4. **S3 Block Public Access** audit org-wide — AWS CLI, 30 min (FTR 15)
5. **Savings Plans** zakup — analiza Cost Explorer 1h, ~20-30% savings dla rshop/booking/planodkupow

---

## Tagging governance — stan projektów

| Projekt | IaC | Tagging | Status |
|---------|-----|---------|--------|
| rshop | CloudFormation | dev 11/14, prod 12/13 compliant | ⚠️ partial |
| planodkupow (bbmt) | CloudFormation | Faza 1 audyt DONE | ⚠️ in progress |
| Terraform projekty | Terraform | niezbadane — wymaga inwentaryzacji | ❌ not audited |

---

## Kluczowe wzorce i lekcje operacyjne

### CFN (planodkupow)

- **Tag drift = DBStack failure:** drift między deployed template a S3 template → `Static/DirectModification` → CFN próbuje update RDS → `custom-named resource requires replacing` → rollback. Fix: patchuj `get-template`, nie repo.
- **ssm-secure nie działa** dla nested stack parameters → użyj `String` + `{{resolve:ssm:...}}`
- **RabbitMQ poza root stack (QA DONE 2026-04-21)** — UAT do wdrożenia

### Security Hub enrollment (lekcja 2026-05-04)

`create-members` z delegated admin dla kont org = enable + associate w jednym kroku. Nie trzeba invite/accept. `UnprocessedAccounts: []` = sukces. AutoEnableStandards=NONE zapobiega duplikatom CIS/FSBP.

### EventBridge cross-account

Cross-account EventBridge target ZAWSZE wymaga `role_arn` w source account (IAM role `health-eventbridge-forward` w każdym z 11 kont).

### CloudWatch Logs Insights — ASP.NET Core

Regex do parsowania czasu odpowiedzi: `/ (?<duration>[0-9]+\.[0-9]+)ms/` — bez `in` przed wartością (format ASP.NET Core, nie Spring).

---

## Kluczowe decyzje architektoniczne

1. **Control Tower porzucony** → własny SCP przez Terraform IaC (aws-cloud-platform)
2. **Monitoring infra na monitoring-nagios-bot** (814662658531), nie na management account
3. **Health notifications: per-account EventBridge** (bez Business Support = bez org-wide Health view)
4. **Dokumentacja LLZ pod AWS review od razu** — nie przepisywać do WAF format później
5. **CC account (INVITED)** — konto klienta zewnętrznego w org
6. **Security Hub AutoEnableStandards=NONE** — zapobiega duplikacji CIS/FSBP przy masowym enrollmencie

---

## Pytania otwarte

- [ ] Admin MakoLab (647075515164) — root access keys: kto je utworzył i dlaczego?
- [ ] CC account — jaka rola w org? Czy powinno mieć llz-security-baseline?
- [ ] Platform OU + Security OU — czy celowo bez llz-security-baseline?
- [ ] `zespol` tag policy — jakie są obecne nazwy zespołów? (wymaga HR)
- [ ] rshop: zostać na CFN czy migrować do Terraform?
- [ ] Config recorder w management account — jak wdrożyć (poza zakresem OrgConfigRules)?

---

## Profile AWS i uruchamianie

```bash
# Management account (Terraform state, Organizations API)
AWS_PROFILE=mako-dc terraform plan/apply

# Monitoring account (delegated admin dla GD/SecHub/Config)
aws ... --profile monitoring-tbd    # 814662658531 via OrganizationAccountAccessRole

# Inne konta
aws ... --profile rshop             # 943111679945
aws ... --profile booking           # 128264038676
aws ... --profile plan              # 333320664022 (planodkupow)
```

| Profil | Konto | Zastosowanie |
|--------|-------|--------------|
| `mako-dc` | 864277686382 (management) | Terraform state, Organizations API, aws-cloud-platform |
| `monitoring-tbd` | 814662658531 (monitoring-nagios-bot) | GD/SecHub/Config delegated admin ops |
| `plan` | 333320664022 (planodkupow) | CloudFormation, RDS, ECS, MQ |

**UWAGA:** awsume nadpisuje env vars — zawsze `AWS_PROFILE=mako-dc terraform ...` (nie awsume przed terraform).

---

*Vault: `20-projects/internal/llz/` — session-log, context, org-inventory, waf-checklist, llz-compliance-audit-2026-05-04*
