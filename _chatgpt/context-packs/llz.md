# Kontekst dla LLM — LLZ (Light Landing Zone)

> Wklej na początku sesji dotyczącej LLZ. Standalone — nie wymaga dodatkowych plików.
> Aktualizuj po każdej sesji implementacyjnej.

## Jak używać tego kontekstu z LLM

- Wklej ten plik na początku rozmowy jako kontekst bazowy
- Dodaj konkretny problem lub pytanie (np. "jak wdrożyć GuardDuty org-wide")
- Jeśli temat dotyczy konkretnego projektu (rshop, planodkupow) — dołącz jego kontekst z `20-projects/`
- Nie wklejaj całego vault — tylko potrzebne fragmenty
- Przy pytaniach o stan — zweryfikuj w IaC, nie polegaj wyłącznie na tym dokumencie

---

**Projekt:** LLZ — Light Landing Zone (MakoLab platforma AWS)
**Zaktualizowano:** 2026-04-21
**Repozytoria:** `~/projekty/mako/aws-projects/aws-cloud-platform/` (Terraform IaC)

---

## Kim jestem

Senior DevOps/SRE, AWS-primary. Właściciel platformy AWS dla MakoLab — firmy IT świadczącej usługi cloud dla klientów zewnętrznych. Org multi-account (11 aktywnych kont). Vault wiedzy w Obsidian (Claude Code jako asystent). IaC: Terraform + CloudFormation.

---

## Czym jest LLZ

**Light Landing Zone** to wewnętrzny standard platformowy MakoLab. NIE jest to AWS Control Tower ani pełny Landing Zone — jest to minimalny zestaw standardów operacyjnych obejmujący:

| Wymiar | Narzędzie | Co audytuje |
|--------|-----------|-------------|
| **Scaffold conformance** | Terraform | struktura `envs/`, `backend.tf`, `versions.tf`, `project.yaml` |
| **Observability readiness** | AWS API | ECS logi, ALB access logs, VPC Flow Logs, CloudFront logging, ElastiCache |
| **Tagging governance** | CFN + Terraform | tagi `Project`/`Environment`/`ManagedBy`/`Owner`, AWS Tag Policies |
| **Architecture audit** | CFN static analysis | messaging (AmazonMQ/MSK) w root stack, inne wzorce architektoniczne |

Narzędzie: `devops-toolkit` — CLI (`toolkit audit-pack llz-basic`, `toolkit audit-pack aws-logging`, `toolkit audit-pack tagging`, `toolkit audit-pack cfn-messaging`).

---

## Zakres LLZ (scope boundaries)

LLZ obejmuje:
- governance (SCP, Tag Policies, AWS Organizations)
- observability (CloudWatch, logi, alerty)
- baseline security (GuardDuty, Config, CloudTrail)
- standardy operacyjne (scaffold, tagging, health notifications)
- architecture guardrails (CFN static analysis)

LLZ NIE obejmuje:
- architektury aplikacyjnej (baza danych, kolejki, API design)
- implementacji CI/CD dla aplikacji klientów
- logiki aplikacyjnej ani konfiguracji runtime

Rekomendacje poza tym zakresem traktuj jako out-of-scope.

---

## Źródła prawdy (Source of Truth)

| Co | Gdzie |
|----|-------|
| Infrastruktura platformowa | Terraform (`aws-cloud-platform/`) |
| Projekty klientów | CloudFormation (`infra-bbmt/`, `infra-rshop/` itd.) |
| SCP, Tag Policies, OU | AWS Organizations (stan w Terraform state) |
| Audyty i conformance | `devops-toolkit` (artefakty w `.devops-toolkit/runs/`) |

**Vault jest warstwą dokumentacyjną — nie jest źródłem prawdy runtime.** Przy rozbieżności między vault a stanem AWS → zaufaj AWS.

---

## Struktura organizacji AWS

```
Org ID: o-5c4d5k6io1
Management: 864277686382 (makolab_dc) — profil AWS: mako-dc

Root
├── Platform OU
│   ├── Admin MakoLab        647075515164
│   └── monitoring-nagios-bot 814662658531  ← monitoring, health notifications
├── Security OU
│   └── LogArchiveNew        771354139056  ← CloudTrail logs
├── Sandbox OU
│   └── lab                  052845428574
└── Workloads OU
    ├── Production OU
    │   ├── planodkupow       333320664022
    │   ├── planodkupowv1     292464762806
    │   ├── Booking_Online    128264038676
    │   ├── RShop             943111679945
    │   ├── dacia-asystent    074412166613
    │   └── CC                943696080604  (konto INVITED — klient zewnętrzny)
    └── NonProduction OU
        └── DRP-TFS           613448424242
```

Terraform state: S3 `864277686382-terraform-state-bucket` + DynamoDB `terraform-state-lock` (eu-central-1).

---

## Co jest już wdrożone (Faza A — DONE)

### 1. Governance (IaC: `aws-cloud-platform/organization/governance/`)

- **SCP `llz-workloads-baseline`** → Workloads OU (Production + NonProduction dziedziczą)
  - Deny: wyłączenie CloudTrail, wyłączenie Config, zmiana S3 public access block
- **SCP `llz-quarantine-deny-all`** → Quarantine OU
- **Tag Policies** (zaktualizowane, dziedziczone z Root):
  - `klient`: booking, dacia-asystent, rshop, planodkupow, cc, makolab + legacy
  - `projekt`: booking, dacia-asystent, planodkupow, rshop, cc + legacy
  - `typ`: prod, dev, qa, uat, poc, test
  - `zespol`: legacy (wymaga aktualizacji po zebraniu obecnych teamów)

### 2. Centralna observability (IaC: `aws-cloud-platform/platform/monitoring/`)

- **CloudWatch OAM** — sink `observabilitySink` w monitoring-nagios-bot (814662658531)
- 4 konta podłączone jako sources: rshop, booking, planodkupow, dacia
- Sink policy: org-wide (`PrincipalOrgID`), metryki + logi + X-Ray
- CloudTrail org trail `org-baseline-cloudtrail` → S3 w LogArchiveNew ✅

### 3. AWS Health notifications ✅ WDROŻONE (IaC: `aws-cloud-platform/platform/health-notifications/`)

- EventBridge rules (us-east-1) w każdym z 11 kont → bus `health-aggregation` (monitoring-nagios-bot)
- Lambda (Python 3.12, us-east-1) → SNS topic (eu-central-1) → email
- Filtr: tylko `statusCode=open` + `eventTypeCategory=issue|investigation`
- Kluczowa lekcja: cross-account EventBridge target zawsze wymaga `role_arn` w source account (IAM role `health-eventbridge-forward` w każdym z 11 kont)

### 4. Tagging standard (LLZ v1)

```
Wymagane: Project, Environment
Zalecane: ManagedBy, Owner
Enforce przez AWS Tag Policies (org Root)
```

### 5. devops-toolkit — audyt CFN messaging (WAF-ARCH-MQ-001) ✅

Plugin `cfn_messaging_audit` (statyczny, bez boto3):
- Wykrywa `AWS::AmazonMQ::Broker` i `AWS::MSK::Cluster` w root i nested stackach CFN
- Zwraca `iac.messaging_in_root: true/false` w normalized_artifacts
- Finding WAF-ARCH-MQ-001: messaging w root stack = duży blast radius przy rollbackach
- 20/20 testów, PARTIAL status gdy nested stack jest na S3 URL (nie lokalny)

### 6. devops-toolkit — audit-pack llz-waf-readonly (6 bugów naprawione, 2026-04-20)

- `llz.required_tags`, `llz.monitoring_account_id`, `llz.workloads_ou_name` — wymagane pola w `project.yaml`
- Region fallback dla cloudtrail/observability gdy brak konfiguracji
- 129/129 testów PASS

---

## Co jest w toku / planowane (Faza B)

| Epic | Co | Status |
|------|----|--------|
| EPIC 1 | Dokument OU owners + kontakty | Planowane |
| EPIC 3 | Security Account (oddzielne konto dla Security Hub, SIEM) | Planowane |
| EPIC 4 | GuardDuty org-wide | **Priorytet — HRI** |
| EPIC 5 | AWS Config org aggregator + reguły conformance | Planowane |
| EPIC 6 | SCP baseline (deny expensive, region restriction) | Planowane |

---

## Aktualny fokus (2026-04)

Priorytety na bieżący kwartał — zgodnie z HRI i Fazą B:

1. **GuardDuty org-wide** — HRI SEC 4, brak detekcji zagrożeń w całej org
2. **SCP Faza B** — HRI SEC 1, brak preventive controls poza `llz-workloads-baseline`
3. **AWS Config org aggregator** — widoczność compliance cross-account (brak teraz)
4. **Inwentaryzacja projektów Terraform** — tagowanie i scaffold dla kont spoza CFN

Rekomendacje powinny być zgodne z tymi priorytetami. Jeśli sugerujesz nowe działanie — zaznacz czy wpisuje się w jeden z tych 4 punktów.

---

## WAF stan (2026-04-20)

Overall: **~30% WAF-ready**.

| Pillar | Stan | Główne luki |
|--------|------|------------|
| Operational Excellence | ~40% | Brak SLO, brak CI/CD dla IaC, brak readiness checklist |
| Security | ~25% | GuardDuty wyłączony (HRI!), brak IR plan, brak SCP Faza B |
| Reliability | ~30% | Brak DR plan (konto DRP istnieje, plan nie), brak restore tests |
| Performance | ~40% | Brak right-sizing, brak load testing standard |
| Cost | ~20% | All On-Demand (brak Savings Plans), brak anomaly detection |
| Sustainability | ~40% | Brak Graviton, brak S3 lifecycle standard |

**High Risk Issues (HRI):**
1. GuardDuty wyłączony org-wide → zagrożenia niewykrywane
2. Brak SCP preventive controls → konta mogą wyłączyć security tooling
3. Brak formalnego DR plan (konto DRP-TFS istnieje ale bez dokumentacji RTO/RPO)
4. Brak IR plan → zero procedury na incydent bezpieczeństwa

**Quick wins:**
- Cost Anomaly Detection (30 min) — COST 3
- Savings Plans analiza (1h, ~20-30% savings) — COST 7
- GuardDuty org-wide (1-2 dni) — SEC 4 HRI

---

## Tagging governance — stan projektów (2026-04-21)

| Projekt | IaC | Tagging | Status |
|---------|-----|---------|--------|
| rshop | CloudFormation | dev 11/14, prod 12/13 compliant | ⚠️ partial |
| planodkupow (bbmt) | CloudFormation | Faza 1 audyt DONE — patrz niżej | ⚠️ in progress |
| Terraform projekty | Terraform | niezbadane — wymaga inwentaryzacji | ❌ not audited |

### planodkupow tagging — wyniki audytu Fazy 1 (2026-04-21)

Dwa równoległe schematy tagów:

**QA (nowy stack):** `Project`, `Environment`, `Owner=DC-devops`, `ManagedBy=cloudformation`, `CostCenter=DC`

**UAT (stary stack):** `Project`, `Environment`, `Maintainer=3rd party - Tribecloud`, `Provisioner=cloudformation`, `Team=DataCenter`, `Client=Reno/Dacia`, `typ=uat`

Brakujące w UAT: `Owner`, `ManagedBy`, `CostCenter`

Mapowanie: `Maintainer→Owner` (wartość się zmienia!), `Provisioner→ManagedBy` (1:1), `CostCenter` bez poprzednika.

**Strategia:** addytywna — dodaj nowe klucze, stare usuń w drugiej fali. Mapowanie logiczne niewystarczające — AWS działa na realnych kluczach.

**DO NOT TOUCH:** wszystkie 4 CloudFront distributions (3x UAT, 1x QA — ten bez tagów).

**SAFE pierwsza fala:** S3, VPC/SG bezpośrednio przez API (nie CFN). RDS przez `rds add-tags-to-resource` (NIE przez CFN — ryzyko SQLDatabase replacement).

---

## Kluczowe wzorce i lekcje CFN (planodkupow)

### Tag drift = DBStack failure

Tag drift między deployed template a template uploadowanym do S3 powoduje `Static/DirectModification` na DBStack → CFN próbuje update RDS → `custom-named resource requires replacing` → rollback.

**Fix:** zawsze patchuj deployed template pobrany przez `aws cloudformation get-template`, nie wersję z repo.

### ssm-secure nie działa dla nested stack parameters

`{{resolve:ssm-secure:...}}` nie jest wspierany dla `AWS::CloudFormation::Stack/Properties/Parameters`.
**Fix:** SSM parameter jako typ `String` + `{{resolve:ssm:...}}`.

### RabbitMQ poza root stack (QA DONE 2026-04-21)

- RabbitMQ usunięty z lifecycle root stack planodkupow-qa
- MQCS przez `{{resolve:ssm:/planodkupow/qa/rabbitmq/mqcs}}`
- UAT: do wdrożenia (stack: UPDATE_ROLLBACK_COMPLETE, broker b-2d26b881 RUNNING)

### continue-update-rollback — dwa kroki

UPDATE_ROLLBACK_FAILED wymaga dwóch kroków:
1. Nested stack: `--resources-to-skip BasicBroker`
2. Root stack: `--resources-to-skip "planodkupow-<env>-RabbitMQStack-<ID>.BasicBroker"`

---

## Kluczowe decyzje architektoniczne

1. **Control Tower porzucony** → własny SCP przez Terraform IaC (aws-cloud-platform)
2. **Monitoring infra na monitoring-nagios-bot** (814662658531), nie na management account
3. **Health notifications: per-account EventBridge** (bez Business Support = bez org-wide Health view)
4. **Dokumentacja LLZ pod AWS review od razu** — nie przepisywać do WAF format później
5. **CC account (INVITED)** — konto klienta zewnętrznego w org, wyjaśnienie kontekstu otwarte
6. **cfn_messaging_audit** — statyczny, bez boto3, local file analysis only (wzorzec dla kolejnych CFN audit pluginów)

---

## Pytania otwarte / do rozstrzygnięcia

- [ ] CC account — co to jest dokładnie? (INVITED = klient zewnętrzny?)
- [ ] Admin MakoLab (647075515164) — jaką pełni rolę w Platform OU?
- [ ] `zespol` tag policy — jakie są obecne nazwy zespołów? (wymaga HR)
- [ ] rshop: zostać na CFN czy migrować do Terraform?
- [ ] DRP-TFS w NonProduction OU — czy nie powinno być w Platform?
- [ ] planodkupow UAT tagging: czy `Owner=DC-devops` właściwy? (historycznie `Maintainer=3rd party - Tribecloud`)

---

## Profil AWS i uruchamianie

```bash
# Management account (Terraform state, Organizations API)
AWS_PROFILE=mako-dc terraform plan/apply

# Monitoring account — bezpośredni dostęp (nie przez assume_role)
aws ... --profile monitoring-tbd    # monitoring-tbd = profil dla monitoring-nagios-bot (814662658531)

# Inne konta przez assume_role z mako-dc (OrganizationAccountAccessRole)
aws sts assume-role --role-arn arn:aws:iam::<ACCOUNT_ID>:role/OrganizationAccountAccessRole \
  --role-session-name llz-audit --profile mako-dc
```

**UWAGA:** awsume ustawia env vars które nadpisują `profile` w Terraform backend. Zawsze używaj `AWS_PROFILE=mako-dc terraform ...` (nie awsume przed terraform).

| Profil | Konto | Zastosowanie |
|--------|-------|--------------|
| `mako-dc` | 864277686382 (management) | Terraform state, Organizations API, aws-cloud-platform |
| `monitoring-tbd` | 814662658531 (monitoring-nagios-bot) | bezpośredni dostęp CLI do konta monitoring |
| `plan` | 333320664022 (planodkupow) | CloudFormation, RDS, ECS, MQ |

---

*Vault: `20-projects/internal/llz/` — session-log.md, context.md, org-inventory.md, waf-checklist.md, ideas.md, progress-tracker.md*
