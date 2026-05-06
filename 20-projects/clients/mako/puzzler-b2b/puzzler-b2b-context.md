---
title: puzzler-b2b-context
client: mako
project: puzzler-b2b
domain: client-work
document_type: runtime-context
context_type: cloud-detective-snapshot
classification: internal
source_of_truth: false
runtime_snapshot: true
aws_profile: puzzler-pbms
account_id: "698220459519"
regions:
  - eu-west-2
iac: terraform
repository: "~/projekty/mako/aws-projects/infra-puzzler-b2b-final"
created: 2026-05-01
updated: 2026-05-06
last_verified: "2026-05-01"
scan_method: cloud-detective-v2
last_verified_by: claude
tags:
  - aws
  - terraform
  - ecs
  - fargate
  - documentdb
  - mako
  - puzzler-b2b
---

# puzzler-b2b — PBMS (Puzzler B2B Management System)

#aws #terraform #ecs #fargate #documentdb #mako #puzzler-b2b

**Data:** 2026-05-01
**Typ dokumentu:** snapshot runtime / context wejściowy
**Source of truth:** AWS live + IaC + Terraform state
**Tryb skanowania:** read-only
**Poziom pewności snapshotu:** częściowa — dev i QA potwierdzone live, UAT/prod niezweryfikowane
**Projekt:** Mikroserwisowa aplikacja .NET (Puzzler B2B Management System) — ECS Fargate + DocumentDB + SQS + Cloud Map. Dev i QA wdrożone w eu-west-2, konto 698220459519.
**OrgAccountID:** `233573821857` (management account — vault historyczny)
**Account ID:** `698220459519`
**Role:** `OrganizationAccountAccessRole` (vault historyczny — niezweryfikowane live)
**AWS profile:** `puzzler-pbms`
**IAM principal:** `makolab-ci` (IAM user)
**Region główny:** `eu-west-2`

---

## Snapshot metadata

| Pole | Wartość |
|------|---------|
| scan_date | 2026-05-05 |
| scan_scope | partial — IaC only; AWS credentials expired, live scan niemożliwy |
| regions_checked | eu-west-2 (poprzedni scan 2026-05-01; nowy scan niemożliwy — credentials expired) |
| repo_checked | tak — pełna analiza working tree, niezatwierdzone zmiany, nowe pliki QA IaC |
| iac_checked | tak — envs/dev, envs/qa (nowe pliki), modules/pattern/ |
| runtime_checked | poprzedni scan 2026-05-01 — nowy scan niemożliwy (credentials expired) |
| extra_regions_checked | nie dotyczy (brak extra_regions w manifeście) |

---

## Zakres snapshotu vs audytu

| Obszar | Typ | Zakres | Źródło |
|--------|-----|--------|--------|
| Runtime health (ECS dev) | snapshot | live AWS — 9 serwisów dev | live AWS |
| Runtime health (ECS QA) | snapshot | live AWS — 9 serwisów QA | live AWS |
| DocumentDB dev + QA | snapshot | describe-db-clusters — oba klastry | live AWS |
| SQS dev + QA | snapshot | list-queues | live AWS |
| Scheduler | snapshot | describe-scheduled-actions | live AWS |
| CFN stack status | nie dotyczy | projekt używa Terraform | — |
| IaC analiza | snapshot | partial — dev/qa envs, schedulers.tf, backend.tf | IaC |
| Tagging coverage | niezweryfikowane | resourcegroupstaggingapi nie uruchomiono | — |
| FinOps / cost allocation | niezweryfikowane | brak historycznego audytu | — |
| Security (WAF) | niezweryfikowane | list-web-acls nie wykonano | — |
| ACM certs | snapshot | eu-west-2 sprawdzone live | live AWS |
| Secrets Manager | snapshot | list-secrets wykonano | live AWS |
| CloudWatch alarms | snapshot | describe-alarms wykonano | live AWS |
| ALB target health | niezweryfikowane | describe-target-health nie wykonano | — |
| UAT / prod environments | niezweryfikowane | live scan nie wykonano | — |
| CloudFront | snapshot | list-distributions + get-distribution-config | live AWS |

---

## Repozytorium kodu

- lokalna ścieżka: `~/projekty/mako/aws-projects/infra-puzzler-b2b-final`
- remote: `git@gitlab.makolab.net:admin-makolab/dc/aws-projects/infra-pbms.git`
- aktywny branch: **`feat/dev-jumphost-runtime-secret`** (nie main)
- IaC: **Terraform** >= 1.5.0

Struktura repo:
```
envs/          — dev/, qa/, uat/, prod/, shared/, remote-state/
modules/       — pattern/frontend-ecs-microservice (nowy moduł)
locals.tf
providers.tf
versions.tf
```

Ostatnie commity (IaC, bez zmian od 2026-05-01):
```
1b961b9 feat(dev): store jumphost authorized_keys in Secrets Manager
25ce75a feat(dev): add CloudWatch dashboard and baseline operational alarms
80209ff Add dev per-service ECS schedulers
be91cfd changed .gitignore
04377d4 Merge branch 'platform/dev-microservices-refactor' into 'main'
```

**Working tree (2026-05-05) — liczne niezatwierdzone zmiany:**

Nowe pliki QA (untracked — niezatwierdzone):
- `envs/qa/services.tf` — 9 serwisów ECS mikroserwisowa struktura
- `envs/qa/schedulers.tf` — AppAutoScaling MON-FRI 07:00-19:00
- `envs/qa/cloudwatch.tf` — dashboard + alarmy (identyczne z dev)
- `envs/qa/secrets.tf` — DocumentDB, Azure AD, jumphost secrets
- `envs/qa/iam.tf`, `envs/qa/service_discovery.tf`, `envs/qa/output.tf`, `envs/qa/alb_frontend.tf`

Nowe pliki dev (untracked):
- `envs/dev/alb_frontend.tf` — listener certificate dla frontend
- `envs/dev/.env` — plik pusty (0 bytes), BRAK w `.gitignore` — ryzyko

Zmodyfikowane pliki (unstaged): `envs/dev/main.tf`, `services.tf`, `secrets.tf`, `schedulers.tf`, `variables.tf`, `terraform.tfvars`, `envs/qa/main.tf`, `envs/qa/variables.tf`, `envs/prod/main.tf`, `envs/uat/main.tf`, `envs/shared/backend.tf`

Nowy moduł lokalny: `modules/pattern/frontend-ecs-microservice` (untracked)

Untracked plik wrażliwy: `authorized_keys` (2 linie SSH keys) na root repozytorium — `.gitignore` ma literówkę (`autorized_keys`), plik NIE jest ignorowany.

Źródło: IaC git status 2026-05-05.

---

## Środowiska

| Env | Region | Account ID | Status | VPC CIDR | Pewność |
|-----|--------|------------|--------|----------|---------|
| dev | eu-west-2 | 698220459519 | aktywny — 4 serwisy running, 5 stopped (scheduler) | 10.0.0.0/16 | wysoka — live AWS |
| qa | eu-west-2 | 698220459519 | aktywny — 3 serwisy running, 5 stopped (scheduler), jumphost DOWN | 10.1.0.0/16 | wysoka — live AWS |
| uat | eu-west-2 | 698220459519 — hipoteza | IaC template (envs/uat/) — stan live nieweryfikowany | 10.2.0.0/16 (IaC) | niska — tylko IaC |
| prod | eu-west-2 | 698220459519 — hipoteza | IaC template (envs/prod/) — stan live nieweryfikowany | 10.3.0.0/16 (IaC) | niska — tylko IaC |

Uwaga: poprzedni snapshot (context.md, 2026-04-22) sugerował oddzielne konta dla QA/UAT/prod (CHANGE_ME). Live scan potwierdza, że QA używa tego samego konta (`698220459519`). Konta UAT/prod: nieustalone. Źródło: live AWS (`sts get-caller-identity`) + IaC `backend.tf`.

**Terraform state (S3 + DynamoDB, region eu-central-1 — cross-region backend):**

| Env | Bucket | Key | Lock table |
|-----|--------|-----|------------|
| dev | 698220459519-terraform-state | infra-puzzler-b2b/dev/terraform.tfstate | terraform-state-lock |
| qa | 698220459519-terraform-state | infra-puzzler-b2b/qa/terraform.tfstate | terraform-state-lock |
| uat | 698220459519-terraform-state | infra-puzzler-b2b/uat/terraform.tfstate | terraform-state-lock |
| prod | 698220459519-terraform-state | infra-puzzler-b2b/prod/terraform.tfstate | terraform-state-lock |

State QA istnieje (sprawdzone `s3 ls`, aktualizacja: 2026-04-27). Źródło: IaC backend.tf + S3.

---

## Architektura (dev + QA — potwierdzone live)

```text
Internet
  │
  ├── CloudFront E2UE2U5RBCIYKZ (dev ALB origin, brak aliasu custom domain)
  │       ↓
  ├── ALB infra-puzzler-b2b-dev-puzzler (internet-facing, eu-west-2)
  │       ├── TG: infra-puzzler-b2b-dev-gateway-tg  :8080
  │       ├── TG: infra-puzzler-b2b-dev-puzzler-tg  :80
  │       └── TG: devfro20260415...:3000 (front)
  │
  └── ALB infra-puzzler-b2b-qa-puzzler (internet-facing, eu-west-2)
          ├── TG: infra-puzzler-b2b-qa-gateway-tg   :8080
          ├── TG: infra-puzzler-b2b-qa-puzzler-tg   :80
          └── TG: qafron20260427...:3000 (front)

ECS Cluster: infra-puzzler-b2b-dev-puzzler
  ├── gateway  (desired:0 — scheduler STOP po 19:00)  → Cloud Map: pbms-gateway-dev.pbms.local
  ├── core     (desired:0 — scheduler STOP po 19:00)  → Cloud Map: pbms-core-dev.pbms.local
  ├── delivery (desired:0 — scheduler STOP po 19:00)  → Cloud Map: pbms-delivery-dev.pbms.local
  ├── notifier (desired:0 — scheduler STOP po 19:00)  → Cloud Map: pbms-notifier-dev.pbms.local
  ├── front    (1/1) → ALB front TG
  ├── builder  (1/1) → Cloud Map: pbms-builder-dev
  ├── sync     (1/1) → Cloud Map: pbms-sync-dev
  ├── jumphost (1/1) → ECS Exec (VPN)
  └── worker   (0/0) → SQS: infra-puzzler-b2b-dev-jobs (intentionally stopped?)

ECS Cluster: infra-puzzler-b2b-qa-puzzler
  ├── gateway  (desired:0 — scheduler STOP po 19:00)  → Cloud Map: pbms-gateway-qa
  ├── core     (desired:0 — scheduler STOP po 19:00)  → Cloud Map: pbms-core-qa
  ├── delivery (desired:0 — scheduler STOP po 19:00)  → Cloud Map: pbms-delivery-qa
  ├── notifier (desired:0 — scheduler STOP po 19:00)  → Cloud Map: pbms-notifier-qa
  ├── front    (1/1, pending:1)  → ALB front TG
  ├── builder  (1/1)             → Cloud Map: pbms-builder-qa
  ├── sync     (1/1)             → Cloud Map: pbms-sync-qa
  ├── jumphost (0/1) ⚠ ECR image missing
  └── worker   (0/0) → SQS: infra-puzzler-b2b-qa-jobs (intentionally stopped?)

DocumentDB dev:  infra-puzzler-b2b-dev-puzzler-mongo.cluster-c1moyqeoccm2.eu-west-2.docdb.amazonaws.com:27017
DocumentDB QA:   infra-puzzler-b2b-qa-puzzler-mongo.cluster-c1moyqeoccm2.eu-west-2.docdb.amazonaws.com:27017
```

Przypisanie domen do serwisów przez CloudFront/ALB — **wymaga potwierdzenia** (listener rules niezweryfikowane).

---

## Mikroserwisy / komponenty

### DEV

| Serwis | Cluster | Desired | Running | Status | Task Def |
|--------|---------|---------|---------|--------|----------|
| infra-puzzler-b2b-dev-gateway | dev | 0 | 0 | ACTIVE / stopped by scheduler | :55 |
| infra-puzzler-b2b-dev-core | dev | 0 | 0 | ACTIVE / stopped by scheduler | :54 |
| infra-puzzler-b2b-dev-delivery | dev | 0 | 0 | ACTIVE / stopped by scheduler | :54 |
| infra-puzzler-b2b-dev-notifier | dev | 0 | 0 | ACTIVE / stopped by scheduler | :54 |
| infra-puzzler-b2b-dev-front | dev | 1 | 1 | ✓ ACTIVE | :17 |
| infra-puzzler-b2b-dev-builder | dev | 1 | 1 | ✓ ACTIVE | :11 |
| infra-puzzler-b2b-dev-sync | dev | 1 | 1 | ✓ ACTIVE | :11 |
| infra-puzzler-b2b-dev-jumphost | dev | 1 | 1 | ✓ ACTIVE | :10 |
| infra-puzzler-b2b-dev-worker | dev | 0 | 0 | ACTIVE / stopped | :2 |

### QA

| Serwis | Cluster | Desired | Running | Status | Task Def |
|--------|---------|---------|---------|--------|----------|
| infra-puzzler-b2b-qa-gateway | qa | 0 | 0 | ACTIVE / stopped by scheduler | :1 |
| infra-puzzler-b2b-qa-core | qa | 0 | 0 | ACTIVE / stopped by scheduler | :1 |
| infra-puzzler-b2b-qa-delivery | qa | 0 | 0 | ACTIVE / stopped by scheduler | :1 |
| infra-puzzler-b2b-qa-notifier | qa | 0 | 0 | ACTIVE / stopped by scheduler | :1 |
| infra-puzzler-b2b-qa-front | qa | 1 | 1 | ✓ ACTIVE (pending:1 — deployment?) | :1 |
| infra-puzzler-b2b-qa-builder | qa | 1 | 1 | ✓ ACTIVE | :1 |
| infra-puzzler-b2b-qa-sync | qa | 1 | 1 | ✓ ACTIVE | :1 |
| infra-puzzler-b2b-qa-jumphost | qa | 1 | 0 | ⚠ DOWN — ECR image not found | :2 |
| infra-puzzler-b2b-qa-worker | qa | 0 | 0 | ACTIVE / stopped | :1 |

Scheduler zarządza: gateway, core, delivery, notifier (oba env) — start 07:00, stop 19:00, cron AppAutoScaling.
Worker (dev + QA): desired:0 — nie wchodzi w scheduler — status intentional do wyjaśnienia. Źródło: live AWS.

---

## Zasoby kluczowe

| Zasób | Identyfikator | Źródło | Pewność |
|-------|---------------|--------|---------|
| ECS cluster dev | infra-puzzler-b2b-dev-puzzler | live AWS | wysoka |
| ECS cluster QA | infra-puzzler-b2b-qa-puzzler | live AWS | wysoka |
| ALB dev | infra-puzzler-b2b-dev-puzzler-1365062480.eu-west-2.elb.amazonaws.com | live AWS | wysoka |
| ALB QA | infra-puzzler-b2b-qa-puzzler-495374675.eu-west-2.elb.amazonaws.com | live AWS | wysoka |
| CloudFront dev | E2UE2U5RBCIYKZ → dev ALB | live AWS | wysoka |
| CloudFront QA | brak | live AWS (list-distributions) | wysoka — brak dystrybucji QA |
| DocumentDB dev | infra-puzzler-b2b-dev-puzzler-mongo.cluster-c1moyqeoccm2.eu-west-2.docdb.amazonaws.com:27017 | live AWS | wysoka |
| DocumentDB QA | infra-puzzler-b2b-qa-puzzler-mongo.cluster-c1moyqeoccm2.eu-west-2.docdb.amazonaws.com:27017 | live AWS | wysoka |
| DocumentDB engine | 5.0.0 (oba env) | live AWS | wysoka |
| SQS dev | infra-puzzler-b2b-dev-jobs + dev-jobs-dlq | live AWS | wysoka |
| SQS QA | infra-puzzler-b2b-qa-jobs + qa-jobs-dlq | live AWS | wysoka |
| Cloud Map | 14 usług (7 dev + 7 QA) | live AWS | wysoka |
| State bucket | 698220459519-terraform-state (eu-central-1) | IaC backend.tf | wysoka |
| OrgAccountID | 233573821857 | vault historyczny | niezweryfikowane live |

---

## Secrets Manager

Nie wypisuj wartości sekretów.

| Secret | Przeznaczenie / zawartość logiczna | Źródło |
|--------|------------------------------------|--------|
| infra-puzzler-b2b/dev/docdb | DocumentDB runtime connection secret (Terraform-managed) | live AWS |
| infra-puzzler-b2b/dev/jumphost-ssh | DB jumphost SSH authorized_keys (Terraform-managed) | live AWS |
| infra-puzzler-b2b/dev/azuread | Azure AD credentials (Terraform-managed) | live AWS |
| infra-puzzler-b2b/qa/docdb | DocumentDB runtime connection secret QA (Terraform-managed) | live AWS |
| infra-puzzler-b2b/qa/jumphost-ssh | DB jumphost SSH authorized_keys QA (Terraform-managed) | live AWS |
| infra-puzzler-b2b/qa/azuread | Azure AD credentials QA (Terraform-managed) | live AWS |

6 sekretów — dev (3) + QA (3). Sekrety UAT/prod: niezweryfikowane. Źródło: live AWS.

---

## ACM Certificates

| Domena | Region | Status | Uwagi |
|--------|--------|--------|-------|
| pbms-api-dev.makotest.pl | eu-west-2 | ISSUED ✓ | gateway dev |
| pbms-dev.makotest.pl | eu-west-2 | ISSUED ✓ | frontend dev |
| pbms-api-qa.makotest.pl | eu-west-2 | ISSUED ✓ | gateway QA |
| pbms-qa.makotest.pl | eu-west-2 | ISSUED ✓ | frontend QA |

Brak certyfikatów us-east-1 (CloudFront bez custom domain — alias=0). Źródło: live AWS.

---

## Tagging / FinOps / LLZ / AWS WAF readiness

**Źródło historyczne:** Brak historycznego audytu tagowania.
**Bieżący scan:** sample-based (0 zasobów sprawdzonych live przez resourcegroupstaggingapi — nie uruchomiono)

| Obszar | Status | Uwagi |
|--------|--------|-------|
| FinOps — cost allocation tags (Project/Environment/CostCenter) | niezweryfikowane | nie uruchomiono resourcegroupstaggingapi |
| LLZ tagging standard (Project/Environment/Owner/ManagedBy/CostCenter) | niezweryfikowane | nie uruchomiono |
| ECS/Fargate — tag propagation do tasków (`propagate_tags`) | niezweryfikowane | nie sprawdzono w task-def |
| ECR — tagi na repozytoriach | niezweryfikowane | nie sprawdzono |
| S3 — tagi na bucketach | niezweryfikowane | nie sprawdzono |
| CloudWatch Log Groups — tagi | niezweryfikowane | nie sprawdzono |
| VPC / Endpoints — tagi | niezweryfikowane | nie sprawdzono |
| AWS WAF — obecność i przypisanie właściciela | niezweryfikowane | list-web-acls nie wykonano |

### Wymagane tagi LLZ

| Tag | Oczekiwana wartość | Status |
|-----|--------------------|--------|
| Project | puzzler-b2b | nieustalone |
| Environment | dev / qa / uat / prod | nieustalone |
| Owner | team / e-mail | nieustalone |
| ManagedBy | Terraform | nieustalone |
| CostCenter | ID działu / projektu | nieustalone |

### Wniosek

Pokrycie tagów i WAF niezweryfikowane — resourcegroupstaggingapi i wafv2 nie uruchomiono. Wymaga osobnego skanu tagowania.

### Następne kroki

| Akcja | Priorytet | Kto |
|-------|-----------|-----|
| Uruchom `resourcegroupstaggingapi get-resources` — sprawdź pokrycie | ŚREDNI | DevOps |
| Sprawdź `wafv2 list-web-acls` — CloudFront bez WAF to governance gap | ŚREDNI | DevOps |

---

## Scheduler / automatyzacje FinOps

| Automatyzacja | Mechanizm | Harmonogram | Zakres | Uwagi |
|--------------|-----------|-------------|--------|-------|
| Start dev services | AppAutoScaling ScheduledAction | cron(0 7 ? * MON-FRI *) Europe/Warsaw | gateway, core, delivery, notifier (dev) | |
| Stop dev services | AppAutoScaling ScheduledAction | cron(0 19 ? * MON-FRI *) Europe/Warsaw | gateway, core, delivery, notifier (dev) | |
| Start QA services | AppAutoScaling ScheduledAction | cron(0 7 ? * MON-FRI *) Europe/Warsaw | gateway, core, delivery, notifier (QA) | |
| Stop QA services | AppAutoScaling ScheduledAction | cron(0 19 ? * MON-FRI *) Europe/Warsaw | gateway, core, delivery, notifier (QA) | |

Scheduler oparty na **Application Auto Scaling** (`aws_appautoscaling_scheduled_action`) — nie EventBridge Rules/Scheduler. Potwierdzono live: `describe-scheduled-actions --service-namespace ecs` zwrócił 16 akcji. Źródło: IaC + live AWS.

Worker nie wchodzi w scheduler — desired:0 stały (wymaga wyjaśnienia czy celowe). Źródło: live AWS.

---

## ECS / runtime config

| Parametr | Wartość |
|----------|---------|
| Launch type | FARGATE |
| Terraform >= | 1.5.0 |
| State backend | S3 eu-central-1 + DynamoDB lock |
| Task def dev-gateway | :55 |
| Task def dev-core | :54 |
| Task def dev-front | :17 |
| Task def dev-builder | :11 |
| Task def dev-sync | :11 |
| Task def dev-jumphost | :10 |
| Task def dev-worker | :2 |
| Task def qa-jumphost | :2 |

---

## Observability

**Ważne:** CloudWatch alarms NIE są równoznaczne z aktualnym runtime health. Weryfikuj przez `describe-target-health`. Serwisy stopped przez scheduler (desired:0) są oczekiwanym stanem — nie błędem.

**Runtime health (live, 2026-05-01 ~21:xx — serwisy po godzinach schedulera):**

| Element | Status | Uwagi |
|---------|--------|-------|
| dev — gateway, core, delivery, notifier | stopped (desired:0) | normalny stan po 19:00 (scheduler) |
| dev — front, builder, sync, jumphost | ✓ 1/1 running | |
| dev — worker | stopped (desired:0) | nieustalone czy celowe |
| dev — DocumentDB | ✓ available | engine 5.0.0 |
| QA — gateway, core, delivery, notifier | stopped (desired:0) | normalny stan po 19:00 (scheduler) |
| QA — front | ✓ 1/1 (pending:1) | możliwy active deployment |
| QA — builder, sync | ✓ 1/1 | |
| QA — jumphost | ⚠ 0/1 DOWN | ECR image missing: infra-puzzler-b2b-app-qa:jumphost |
| QA — worker | stopped (desired:0) | nieustalone czy celowe |
| QA — DocumentDB | ✓ available | engine 5.0.0 |
| ALB dev | ✓ active | internet-facing |
| ALB QA | ✓ active | internet-facing |
| ALB target health | niezweryfikowane | describe-target-health nie wykonano |

**CloudWatch alarms (live, 2026-05-01):**

| Alarm | Stan | Metric | Kontekst |
|-------|------|--------|----------|
| dev-core-runtime-down | OK | log metric filter | |
| dev-delivery-runtime-down | OK | log metric filter | |
| dev-gateway-runtime-down | OK | log metric filter | |
| dev-notifier-runtime-down | OK | log metric filter | |
| dev-documentdb-high-cpu | OK | CPUUtilization | |
| dev-documentdb-low-freeable-memory | OK | FreeableMemory | |
| dev-gateway-target-5xx | OK | HTTPCode_Target_5XX_Count | |
| dev-gateway-unhealthy-hosts | OK | UnHealthyHostCount | |
| dev-jobs-oldest-message-age | OK | ApproximateAgeOfOldestMessage | |
| dev-worker-sqs-scale-in | **INSUFFICIENT_DATA** | ApproximateNumberOfMessagesVisible | Worker stopped — no SQS messages; normalny stan gdy worker desired:0 |
| dev-worker-sqs-scale-out | **INSUFFICIENT_DATA** | ApproximateNumberOfMessagesVisible | jak wyżej |
| qa-core-runtime-down | OK | log metric filter | |
| qa-delivery-runtime-down | OK | log metric filter | |
| qa-gateway-runtime-down | OK | log metric filter | |
| qa-notifier-runtime-down | OK | log metric filter | |
| qa-documentdb-high-cpu | OK | CPUUtilization | |
| qa-documentdb-low-freeable-memory | OK | FreeableMemory | |
| qa-gateway-target-5xx | OK | HTTPCode_Target_5XX_Count | |
| qa-gateway-unhealthy-hosts | OK | UnHealthyHostCount | **ostatnia zmiana: 2026-05-01 19:09** — ślad schedulera stop |
| qa-jobs-oldest-message-age | OK | ApproximateAgeOfOldestMessage | |
| qa-worker-sqs-scale-in | **INSUFFICIENT_DATA** | ApproximateNumberOfMessagesVisible | Worker stopped |
| qa-worker-sqs-scale-out | **INSUFFICIENT_DATA** | ApproximateNumberOfMessagesVisible | Worker stopped |

Brak alarmów w stanie ALARM — środowisko OK. INSUFFICIENT_DATA na worker-sqs-scale jest oczekiwanym efektem ubocznym gdy worker desired:0.

**Log groups:**

| Log group | Retencja | Uwagi |
|-----------|----------|-------|
| /ecs/infra-puzzler-b2b-dev-* (9 grup) | 14 dni | aktywne per-serwis |
| /ecs/infra-puzzler-b2b-qa-* (9 grup) | 14 dni | aktywne per-serwis |
| /infra-puzzler-b2b/dev/app | 90 dni | starszy log group (przed refaktorem?) |
| /infra-puzzler-b2b/dev/worker | 90 dni | starszy log group |

Uwaga: log groups QA mają prefix `/ecs/` (nie `/infra-puzzler-b2b/qa/`). 14-dniowa retencja dla `/ecs/` jest krótka, ale akceptowalna dla środowisk deweloperskich.

---

## Znane problemy / dług techniczny

| Problem | Priorytet | Evidence | Opis |
|---------|-----------|----------|------|
| QA jumphost DOWN — ECR image missing | WYSOKI | `describe-tasks` 2026-05-01: CannotPullContainerError — `infra-puzzler-b2b-app-qa:jumphost` not found w ECR | Terraform wdrożył serwis jumphost QA, ale obraz nie był buildowany/pushowany. Naprawa: zbudować i push obraz `jumphost` do ECR repo QA. Stan aktualny: niezweryfikowany (credentials expired 2026-05-05). |
| `authorized_keys` untracked na root repo — gitignore literówka | WYSOKI | git status 2026-05-05: untracked; `.gitignore` ma `autorized_keys` zamiast `authorized_keys` | Plik SSH authorized_keys z 2 liniami kluczy leży na root repozytorium i NIE jest ignorowany przez `.gitignore` (literówka). Przy `git add .` trafi do repozytorium. Fix: poprawić `.gitignore` (`authorized_keys`). |
| `envs/dev/.env` untracked — brak w `.gitignore` | WYSOKI | git status 2026-05-05: untracked; `git check-ignore` exit:1 (nie ignorowany); plik pusty | Plik `.env` nie jest objęty `.gitignore`. Aktualnie pusty (0 bytes) — ale jeśli operator doda TF_VAR_* lub credentiale, zostanie przypadkowo committed. Fix: dodać `.env` do `.gitignore`. |
| AWS credentials wygasłe (profile puzzler-pbms) | WYSOKI | `sts get-caller-identity` 2026-05-05: SignatureDoesNotMatch; statyczne klucze IAM AKIA2FEJOWX7TOPU2B44 | Brak możliwości live scan. Klucze zrotowane lub unieważnione. Fix: odświeżyć klucze IAM w `~/.aws/config` dla profilu `puzzler-pbms`. |
| QA IaC niezatwierdzone — in-progress work | ŚREDNI | git status 2026-05-05: wiele plików untracked/modified | Kompletna struktura IaC QA (services.tf, schedulers.tf, cloudwatch.tf itd.) niezatwierdzona. Branch `feat/dev-jumphost-runtime-secret` nie merged. Ryzyko: niezatwierdzone zmiany mogą być utracone. |
| Worker desired:0 (dev + QA) — nieustalone czy celowe | ŚREDNI | live AWS 2026-05-01: describe-services, desired:0; brak schedulera dla worker | Worker nie jest zarządzany przez scheduler (który obsługuje tylko gateway/core/delivery/notifier). Desired:0 może być ręcznie ustawione lub celowe (brak wdrożonego obrazu). Wymaga wyjaśnienia. |
| CloudFront bez custom domain (alias) | ŚREDNI | get-distribution-config 2026-05-01: aliases.Quantity=0; origin=dev ALB | CloudFront dev nie ma skonfigurowanego CNAME/aliasu. Dostęp przez `d187f8g7g4wvm6.cloudfront.net` lub bezpośrednio przez ALB. |
| QA front: pending:1 | NISKI | describe-services 2026-05-01: pending:1 | Możliwy aktywny deployment lub zablokowane rejestrowanie taska. Monitorować (stan aktualny niezweryfikowany). |
| 14-dniowa retencja logów /ecs/* | NISKI | describe-log-groups 2026-05-01 | Krótka dla post-incident debugging jeśli incydent wykryty po >14 dniach. Akceptowalne dla dev/QA. |
| Worker sqs-scale alarms: INSUFFICIENT_DATA | INFO | describe-alarms 2026-05-01 | Oczekiwany stan gdy worker desired:0. Nie jest błędem. |
| Brak CloudFront dla QA | INFO | list-distributions 2026-05-01: 1 dystrybucja (dev only) | QA dostępne tylko przez ALB bezpośrednio. Może być celowe dla środowiska testowego. |

---

## Różnice IaC vs Runtime

| Obszar | IaC | Runtime AWS | Ocena |
|--------|-----|-------------|-------|
| Scheduler mechanizm | AppAutoScaling ScheduledAction (schedulers.tf) | Potwierdzone 2026-05-01: describe-scheduled-actions zwrócił 16 akcji | zgodne |
| QA account ID | CHANGE_ME_QA_ACCOUNT_ID (komentarz w backend.tf) | 698220459519 (ten sam co dev) | **rozbieżność** — komentarz nieaktualny, QA w tym samym koncie |
| QA deployment | envs/qa/ istnieje, state z 2026-04-27 | klaster ACTIVE, 9 serwisów (2026-05-01) | zgodne — QA wdrożone |
| QA jumphost image | IaC definiuje serwis jumphost | obraz `jumphost` brak w ECR (2026-05-01) | **rozbieżność** — IaC deployed, obraz nie zbudowany |
| Worker desired_count | nieustalone (IaC nie przeczytane szczegółowo) | desired:0 (dev + QA) — 2026-05-01 | wymaga potwierdzenia |
| UAT/prod environments | IaC templates w envs/ | stan live nieweryfikowany | nieustalone |
| QA IaC struktura mikroserwisów | niezatwierdzone pliki (services.tf, schedulers.tf, cloudwatch.tf itd.) w working tree | niezweryfikowane — credentials expired | **nowe IaC, niezatwierdzone** — stan live QA nieznany wobec nowego IaC |
| QA scheduler (AppAutoScaling) | `enable_runtime_scheduler = true` w envs/qa/main.tf (niezatwierdzone) | 16 akcji z 2026-05-01 — QA scheduler potwierdzony live | **do weryfikacji** — scheduler był live, teraz IaC definiuje go explicite przez schedulers.tf |
| `modules/pattern/frontend-ecs-microservice` | nowy moduł lokalny (untracked) | niezweryfikowane | nowe — nie wiadomo czy deploy |

---

## Drift / niespójności architektury

| Obszar | Typ driftu | Źródło | Opis |
|--------|-----------|--------|------|
| QA jumphost — ECR image missing | IaC vs runtime | live AWS 2026-05-01 (CannotPullContainerError) | Terraform wdrożył ECS service, CI/CD nie pushował obrazu do ECR dla QA. Stan aktualny: niezweryfikowany. |
| Worker desired:0 (dev + QA) | unknown | live AWS 2026-05-01 | Worker services na 0 — brak schedulera dla worker; może być manual change lub IaC default. |
| QA CHANGE_ME_QA_ACCOUNT_ID | IaC vs runtime | IaC backend.tf + live AWS | Komentarz w backend.tf mówi "zastąp ID konta QA" ale QA deployowane w tym samym koncie co dev. |
| Stare log groups (/infra-puzzler-b2b/dev/app+worker) | IaC vs runtime | live AWS 2026-05-01 | Dwa starsze log groups z 90d retencją obok 9 nowych /ecs/ z 14d — prawdopodobnie orphaned po refaktorze. |
| `authorized_keys` untracked — gitignore literówka | IaC (gitignore) | git status 2026-05-05 | Plik SSH keys nie objęty `.gitignore` przez literówkę — `autorized_keys` zamiast `authorized_keys`. Ryzyko accidental commit. |
| `envs/dev/.env` untracked — brak gitignore rule | IaC (gitignore) | git status 2026-05-05 | Plik `.env` pusty ale brak reguły w `.gitignore`. Ryzyko gdy operator doda TF_VAR_*. |
| QA IaC niezatwierdzone — in-progress work on non-main branch | multi-repo / branch | IaC git status 2026-05-05 | Kompletna struktura QA (9 plików TF) w working tree, nie committed. Branch feat/dev-jumphost-runtime-secret nie merged do main. |

---

## Pewność ustaleń

| Obszar | Pewność | Evidence | Uwagi |
|--------|---------|----------|-------|
| Account ID, region, profil | wysoka | `sts get-caller-identity` | |
| ECS dev — serwisy | wysoka | `describe-services` (9 serwisów) | |
| ECS QA — serwisy | wysoka | `describe-services` (9 serwisów) | |
| QA jumphost DOWN + przyczyna | wysoka | `describe-tasks`: CannotPullContainerError | |
| DocumentDB dev + QA | wysoka | `describe-db-clusters` | |
| SQS (dev + QA) | wysoka | `list-queues` | |
| AppAutoScaling scheduler | wysoka | `describe-scheduled-actions` | |
| CloudFront (1 dystrybucja, dev) | wysoka | `list-distributions` + `get-distribution-config` | |
| ACM certs (4, eu-west-2) | wysoka | `list-certificates` | |
| Secrets Manager (6 wpisów) | wysoka | `list-secrets` | |
| CloudWatch alarms (22) | wysoka | `describe-alarms` | |
| ALB target health | niezweryfikowane | nie wykonano | |
| Tagging / WAF | niezweryfikowane | nie wykonano | |
| UAT / prod live state | niezweryfikowane | nie wykonano | |
| OrgAccountID | niska | vault historyczny (2026-04-22) | nieweryfikowane live |

---

## Dostęp diagnostyczny

```bash
# Tożsamość
aws sts get-caller-identity --profile puzzler-pbms

# ECS dev — serwisy
aws ecs describe-services \
  --cluster infra-puzzler-b2b-dev-puzzler \
  --services infra-puzzler-b2b-dev-gateway infra-puzzler-b2b-dev-core \
    infra-puzzler-b2b-dev-delivery infra-puzzler-b2b-dev-notifier \
    infra-puzzler-b2b-dev-front infra-puzzler-b2b-dev-builder \
    infra-puzzler-b2b-dev-sync infra-puzzler-b2b-dev-jumphost infra-puzzler-b2b-dev-worker \
  --profile puzzler-pbms --region eu-west-2 \
  --query 'services[*].{name:serviceName,desired:desiredCount,running:runningCount}'

# QA jumphost — diagnoza (build + push image)
aws ecr describe-repositories \
  --profile puzzler-pbms --region eu-west-2 \
  --query 'repositories[?contains(repositoryName,`qa`)].{name:repositoryName,uri:repositoryUri}'

# QA jumphost — zatrzymany task
aws ecs list-tasks \
  --cluster infra-puzzler-b2b-qa-puzzler \
  --service-name infra-puzzler-b2b-qa-jumphost \
  --desired-status STOPPED \
  --profile puzzler-pbms --region eu-west-2

# ALB target health (sprawdź po godzinach schedulera)
aws elbv2 describe-target-groups \
  --profile puzzler-pbms --region eu-west-2 \
  --query 'TargetGroups[*].{name:TargetGroupName,arn:TargetGroupArn}' | \
  # następnie dla każdego TG:
  # aws elbv2 describe-target-health --target-group-arn <ARN> --profile puzzler-pbms --region eu-west-2

# Scheduler — scheduled actions
aws application-autoscaling describe-scheduled-actions \
  --service-namespace ecs \
  --profile puzzler-pbms --region eu-west-2

# Tagging (brakujący krok)
aws resourcegroupstaggingapi get-resources \
  --profile puzzler-pbms --region eu-west-2 \
  --query 'ResourceTagMappingList[?Tags[?Key==`Project`]==`[]`].ResourceARN'

# ECS Exec do jumphost dev (VPN wymagany: 195.117.107.110/32)
aws ecs execute-command \
  --cluster infra-puzzler-b2b-dev-puzzler \
  --task <task-id> \
  --container infra-puzzler-b2b-dev-jumphost \
  --interactive --command "/bin/bash" \
  --region eu-west-2 --profile puzzler-pbms

# OPCJONALNIE — tylko po świadomej decyzji operatora.
# cd ~/projekty/mako/aws-projects/infra-puzzler-b2b-final/envs/dev
# terraform init -backend-config=backend.tf
# terraform plan -refresh=false
```

---

## Aktualizacja dokumentacji po zmianach IaC

```bash
# po terraform apply:
# uruchom ponownie cloud-detective przez plik invocation:
# @50-patterns/prompts/invocations/cloud-detective-puzzler-b2b.md
```

---

## Źródła użyte

| Źródło | Zakres | Status |
|--------|--------|--------|
| live AWS | ecs, elbv2, docdb, sqs, secretsmanager, cloudwatch, acm, cloudfront, application-autoscaling, sts, logs | sprawdzone (2026-05-01); nowy scan niemożliwy — credentials expired |
| repo lokalne | `~/projekty/mako/aws-projects/infra-puzzler-b2b-final/` — working tree 2026-05-05: nowe pliki QA, git status, nowe moduły | tak (2026-05-05) |
| IaC | Terraform — envs/dev, envs/qa (nowe pliki), envs/prod, envs/uat, modules/pattern/ | tak (2026-05-05) |
| CFN stacks | nie dotyczy — projekt używa Terraform | — |
| vault historyczny | context.md (2026-04-22) — architektura, OrgAccountID, CIDR; puzzler-b2b-context.md (2026-05-01) jako baseline | użyte |
| extra_regions | nie dotyczy | — |

## Fakty live vs historia vault

| Informacja | Status | Źródło | Uwagi |
|------------|--------|--------|-------|
| QA wdrożone (klaster, 9 serwisów, DocumentDB) | live | live AWS 2026-05-01 | poprzedni snapshot: CHANGE_ME (niezwdrożone) |
| Dev: 9 serwisów (builder i sync nowe) | live | live AWS 2026-05-01 | poprzedni snapshot: 7 serwisów (brak builder, sync) |
| Scheduler: AppAutoScaling (nie EventBridge) | live | live AWS + schedulers.tf | poprzedni snapshot: mechanizm niezidentyfikowany |
| QA account = 698220459519 (ten sam co dev) | live | sts get-caller-identity 2026-05-01 | poprzedni snapshot: CHANGE_ME (zakładano oddzielne konto) |
| QA jumphost DOWN (ECR image missing) | live | live AWS 2026-05-01 | nowe ustalenie; stan aktualny niezweryfikowany |
| SQS DLQ (dev + QA) | live | live AWS 2026-05-01 | poprzedni snapshot: bez DLQ |
| OrgAccountID 233573821857 | historyczna | vault context.md 2026-04-22 | nieweryfikowane live |
| VPN restriction: 195.117.107.110/32 | historyczna | vault context.md 2026-04-22 | nieweryfikowane live |
| QA IaC — pełna struktura mikroserwisów (services.tf, schedulers.tf itd.) | IaC working tree | IaC git status 2026-05-05 | niezatwierdzone; wcześniej brak tych plików w QA |
| `authorized_keys` untracked na root / gitignore literówka | IaC | git status 2026-05-05 | nowe ustalenie — ryzyko security |
| `envs/dev/.env` untracked / brak gitignore rule | IaC | git status 2026-05-05 | nowe ustalenie — pusty, ale ryzyko |
| AWS credentials puzzler-pbms expired | live | aws sts 2026-05-05 | SignatureDoesNotMatch — klucze AKIA... nieaktualne |

---

## Powiązane

- [[context]] (`20-projects/clients/mako/puzzler-b2b/context.md` — poprzedni snapshot 2026-04-22, dane historyczne)
- [[troubleshooting]] (`20-projects/clients/mako/puzzler-b2b/troubleshooting.md`)
- [[now]]
