---
title: session-log — puzzler-b2b
project: puzzler-b2b
client: mako
tags: [#terraform, #aws, #ecs, #alb]
---

# Session Log — puzzler-b2b / PBMS

Chronologicznie, najnowszy na górze.

## 2026-05-22 — Alph API communication fix (DEV sync)

### Kontekst
Serwis `infra-puzzler-b2b-dev-sync` nie mógł połączyć się z Alph API — DNS failure na `alph-api-qa.makolab.net` (prywatna domena MakoLab, niedostępna z AWS VPC).

### Root cause
- Obraz DEV zbudowany ze starego kodu → `alph-api-qa.makolab.net` baked w image
- Aktualny source code ma `alph-api-uat.makodev.pl` w `appsettings.json`, ale żaden env-specific override nie istniał
- `AlphApiSettings` nie był konfigurowalny przez env vars — wyłącznie w obrazie
- `ignore_changes = [container_definitions]` na TD blokuje Terraform plan

### Fix zastosowany
1. `envs/dev/services.tf` — dodano `AlphApiSettings__BaseUrl = "https://alph-api-uat.makodev.pl"` do sync_service
2. AWS CLI: zarejestrowano nową revision TD (`infra-puzzler-b2b-dev-sync:60`) z env varem
3. `aws ecs update-service --task-definition infra-puzzler-b2b-dev-sync:60`
4. Rollout COMPLETED, running=1/desired=1 ✅
5. Commit `aba8998` na `feat/uat-environment`

### Uwagi
- Alph jest lazy-loaded (tylko przy wywołaniu endpointu, nie na starcie)
- Weryfikacja komunikacji możliwa dopiero przy żywym żądaniu do `GET /AlphGeneratorSettings`
- Dług: Login/Password Alph w plain text w `appsettings.json` → przenieść do SM
- Vault: `20-projects/clients/mako/puzzler-b2b/alph-communication-check-2026-05-22.md`

---

## 2026-05-21 — Jumphost CI/CD pipeline + ECS fix

### Kontekst
DEV i QA jumphosty nie startowały z powodu `CannotPullContainerError` — obraz `jumphost-v11` miał inny digest w ECR niż cached przez ECS. Naprawiono i zbudowano kompletny CI/CD pipeline dla jumphostów.

### Wykonane

**ECS fix:**
- Zbudowano nowy obraz `jumphost-v11` lokalnie (colima) dla `linux/amd64`
- Pushnięto do ECR dev i qa
- DEV nadal failował (ECS cache digest `sha256:4cd031...`) mimo nowego push
- Fix: zarejestrowano nową rewizję TD (`infra-puzzler-b2b-dev-jumphost:12`) — to czyści cache digestu w ECS
- Wynik: DEV running=1, QA running=1 (QA naprawiło się samo przy force-new-deployment)

**Publiczne IP po naprawie:**
- DEV: `35.179.105.33`
- QA: `13.41.69.251`
- UAT: `18.134.142.38` (był już running)

**CI/CD pipeline — nowe pliki w `infra-puzzler-b2b-final`:**
- `.gitlab-ci.yml` — 3 stages: build (docker), deploy (ECS), notify (email)
  - matrix dla [dev, qa, uat, prod]
  - build: auto gdy Dockerfile/entrypoint/.gitlab-ci.yml zmienią się na main, lub manual
  - deploy: zawsze manual (osobny przycisk per env)
  - notify: auto po deploy
  - IMAGE_TAG: `jumphost-v${CI_PIPELINE_IID}`
- `scripts/ecs-update-image.sh` — generic ECS image updater:
  - pobiera live TD z ECS (source of truth)
  - zmienia wyłącznie `containerDefinitions[0].image`
  - stripuje read-only fields, rejestruje nową rewizję
  - `aws ecs wait services-stable` (do 10 min)
  - pobiera ENI → public IP, zapisuje do `deploy.env` (GitLab dotenv artifact)
- `scripts/send-notification.py` — profesjonalny email HTML+text przez SMTP
  - zawiera środowisko, public IP, komendę SSH tunnel
- `docs/jumphost-pipeline.md` — operator README (jak uruchomić, debug, failure scenarios)

**Dockerfile — zaktualizowany:**
- Dodano `ARG JUMPHOST_USER=devuser` (konfigurowalne)
- Dodano `ARG JUMPHOST_PUBLIC_KEY_B64=""` — klucze baked w image podczas buildu
- base64 encoding dla bezpiecznego przesyłania multiline content przez docker build-arg
- SSH hardening: sed pattern dla istniejących dyrektyw + echo dla brakujących
- AllowTcpForwarding YES (sed + fallback)

**docker-entrypoint.sh — zaktualizowany:**
- Dynamiczny `JUMPHOST_USER` (przez ENV var z Dockerfile)
- Priority: runtime `AUTHORIZED_KEYS` env var > klucze baked w image

### GitLab variables wymagane
`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `JUMPHOST_PUBLIC_KEY[_DEV|_QA|_UAT|_PROD]`, `JUMPHOST_USER`, `SMTP_*`, `DEVELOPERS_EMAILS`, `DOCDB_ENDPOINT_<ENV>`

### Kluczowy pattern (ECS guardrail)
Pipeline NIGDY nie generuje TD od zera. Live TD = source of truth. Zmiana tylko image, reseta secrets/env/roles/cpu-memory.

## 2026-05-20 — UAT environment IaC build + terraform plan

### Kontekst
Zbudowanie pełnego środowiska UAT w Terraform (`infra-puzzler-b2b-final`) od podstaw na branchu `feat/uat-environment`.

### Wykonane

**IaC (envs/uat/):**
- `backend.tf` — S3 backend `698220459519-terraform-state`, key `infra-puzzler-b2b/uat/terraform.tfstate`, region `eu-central-1`
- `variables.tf` + `terraform.tfvars` — pełny zestaw zmiennych (region: `eu-west-2`, VPC: `10.2.0.0/16`, AZ: `eu-west-2a/b`); sekrety wyłącznie przez `TF_VAR_*`
- `acm.tf` — dwa certyfikaty DNS: `pbms-api-uat.makotest.pl` (gateway), `pbms-uat.makotest.pl` (frontend)
- `iam.tf` — dedykowane role UAT (moduł `ecs-iam`), osobna polityka inline dla secretsmanager; 5 reguł SG dla DocDB (gateway/core/delivery/notifier/worker)
- `secrets.tf` — 4 secrety SM: `docdb`, `azuread`, `jumphost_ssh`, `external_dashboard`; wszystkie z `ignore_changes = [secret_string]`
- `main.tf` — moduł `app-stack` + ECR repos (app + worker)
- `services.tf` — 9 serwisów ECS: gateway, core, delivery, notifier, worker, frontend, sync, builder, jumphost
- `service_discovery.tf` — Cloud Map namespace `pbms.local` + 7 serwisów
- `schedulers.tf` — AppAutoScaling start 07:00 / stop 19:00 MON-FRI dla 4 serwisów
- `cloudwatch.tf` — dashboard + 6 alarmów
- `alb_frontend.tf` — dodatkowy cert na HTTPS listenerze dla frontend
- `output.tf` — ALB DNS, DocDB endpoints, SQS, IAM ARNs, service names, ACM validation options

**Fix modułu core/alb:**
- `modules/core/alb/locals.tf` — zmieniono `create_https_listener = var.enable_https && var.certificate_arn != null` → `create_https_listener = var.enable_https`
- Powód: `count` zależny od `certificate_arn != null` blokuje `terraform plan` gdy cert jest `known after apply`
- Bezpieczna zmiana — precondition w `app-stack` chroni przed `enable_https=true && cert_arn=null`

**Wynik:**
- `terraform init` — OK (provider aws 6.45.0)
- `terraform plan` — **139 to add, 0 to change, 0 to destroy** ✅
- Deprecation warnings (`data.aws_region.current.name`) — kosmetyczne, nie blokują

**Następne kroki (kolejność):**
1. `terraform apply` → ACM ceryfikaty tworzone automatycznie → wyciągnij CNAME z outputu
2. Dodaj rekordy CNAME do `makotest.pl` (admin DNS)
3. Poczekaj na status ISSUED (5–30 min)
4. Wymień obrazy nginx:latest na docelowe URI ECR
5. `terraform apply` bez targetów — pełny deploy

**Ważne:**
- `jumphost_image` wymaga zbudowania obrazu ECR po pierwszym apply (BLOCKER)
- `external_dashboard` secret: BaseUrl `https://syndication-dev.makodev.pl`, Username `tony`
- CNAME po apply: `terraform output -json acm_gateway_validation_options acm_frontend_validation_options`

---

## 2026-05-12 — QA notifier fix + config audit (AzureAd + ExternalDashboardApi)

### Config audit — AzureAd + ExternalDashboardApi

**Trigger:** Sebastian Prościński (dev) przekazał zestaw wartości konfiguracyjnych dla DEV i QA.

**Model konfiguracji:**
- `AzureAd__*` — Secrets Manager (`infra-puzzler-b2b/{env}/azuread`) → ECS secrets injection (env vars nadpisują appsettings). Runtime source = SM.
- `ExternalDashboardApi__*` — baked w Docker image przez `appsettings.{ENV}.json`. Brak ECS injection.

**Wynik porównania:**
- AzureAd DEV + QA w SM: zgodne ✅ (zero zmian)
- ExternalDashboardApi DEV (`appsettings.DEV.json`): zgodne ✅ (zero zmian)
- ExternalDashboardApi QA: brakowało w `appsettings.QA.json` — QA fallowała do `appsettings.json` (base), wartości identyczne, więc runtime OK; dodano dla explicitness

**Zmiana:**
- `Core/PBMS.Core.API/appsettings.QA.json` — dodano sekcję `ExternalDashboardApi`
- Commit: `478d5694` (pbms-backend `dev`), pushed
- Przy merge: remote miał już zmiany w tym pliku (nowe crony, `TestTokenAuth`, BaseUrl z trailing slash) — rozwiązano konflikt, zachowano remote + BaseUrl bez trailing slash per developer value

**Redeployment:** nie wymagany — wartości były już poprawne przez fallback

---

## 2026-05-12 — QA notifier down: missing secret key

**Trigger:** sprawdzenie QA środowiska

### Stan QA na 2026-05-12

| Serwis | desired | running | uwagi |
|--------|---------|---------|-------|
| gateway | 1 | 1 | ✅ |
| core | 1 | 1 | ✅ |
| delivery | 1 | 1 | ✅ |
| notifier | 1 | 0 | ❌ → naprawiony |
| front | 1 | 1 | ✅ |
| builder | 1 | 1 | ✅ |
| sync | 1 | 1 | ✅ |
| jumphost | 1 | 1 | ✅ |
| worker | 0 | 0 | ✅ intentional |

DocumentDB: `available`. ALB: gateway-tg i front-tg `healthy`.

### Notifier — RCA

- 11:15 — CI/CD wdrożył task def rev 27 (image `notifier-api-qa-156`)
- 11:16 — Michał Grzywacz (dev) na Slacku: prosił o dodanie `PBMS_DB_notifier` i connection stringów do DEV i QA
- Task def rev 27 referencjonuje klucz `connection_string_notifier` w `infra-puzzler-b2b/qa/docdb`
- Klucz nie istniał w live sekrecie — failedTasks=12, crash loop co ~5 min

**Root cause:** secret `infra-puzzler-b2b/qa/docdb` był stworzony zanim dodano klucze notifier do `envs/qa/secrets.tf`. `ignore_changes = [secret_string]` w lifecycle blokuje automatyczną synchronizację przy `terraform apply`. DEV był aktualny, QA nie.

### Fix zastosowany

1. `aws secretsmanager put-secret-value` — dodano `connection_string_notifier` i `database_notifier` do `infra-puzzler-b2b/qa/docdb`
2. `aws ecs update-service --force-new-deployment` — wymuszono nowe deployment
3. Notifier wstał: running=1/1

**Terraform:** `envs/qa/secrets.tf` i `envs/dev/secrets.tf` były już aktualne (oba mają `connection_string_notifier`). Żadna zmiana kodu nie była potrzebna.

**Lekcja:** przy dodawaniu nowych kluczy do `aws_secretsmanager_secret_version` z `ignore_changes = [secret_string]` — live sekrety w istniejących środowiskach trzeba zaktualizować ręcznie (`put-secret-value`).

---

## 2026-05-07 — CI/CD pipeline audit + deployment ownership analysis

**Repo:** `~/projekty/mako/aws-projects/infra-puzzler-b2b-final` + `~/projekty/mako/pbms-backend`
**Pipeline source:** `git@gitlab.makolab.net:bss/pbms/cicd.git` (ref: dev), plik `backend/backend.yml`
**Operacja:** read-only audit

### Exact deploy flow (backend.yml — verbatim)

```bash
# 1. Pobierz aktualny task definition ARN z serwisu ECS
TASK_DEF=$(aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE \
  --query "services[0].taskDefinition" --output text)

# 2. Pobierz pełne JSON task definition
aws ecs describe-task-definition --task-definition "$TASK_DEF" \
  --query "taskDefinition" > task-def.json

# 3. Zmień TYLKO image; usuń metadata ECS
jq --arg IMAGE "$IMAGE" '
  .containerDefinitions[0].image = $IMAGE
  | del(.taskDefinitionArn, .revision, .status, .requiresAttributes,
        .compatibilities, .registeredAt, .registeredBy, .deregisteredAt?)
' task-def.json > new-task-def.json

# 4. Zarejestruj nową revision
NEW_TASK_DEF=$(aws ecs register-task-definition \
  --cli-input-json file://new-task-def.json \
  --query "taskDefinition.taskDefinitionArn" --output text)

# 5. Update service
aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE \
  --task-definition "$NEW_TASK_DEF"

# 6. Tracking 600s / 15s interval (rolloutState + failedTasks check)
```

### Pola kopiowane przez CI/CD (pull-and-update)

Wszystko poza `del()` jest kopiowane dosłownie z poprzedniego revision:

| Pole | Co się dzieje |
|------|---------------|
| `secrets` | **kopiowane w całości — źródło AzureAd propagacji** |
| `environment` | kopiowane — stale env vars propagują się |
| `executionRoleArn` | kopiowane — **DEV role w QA** (see below) |
| `taskRoleArn` | kopiowane — **DEV role w QA** |
| `logConfiguration` | kopiowane |
| `cpu` / `memory` | kopiowane (512/1024) |
| `healthCheck` | kopiowane (null — nigdy nie doda healthchecka) |

### Kluczowe findings

**1. Worker nie jest w CI/CD matrix**

Pipeline matrix (6 serwisów): core-api, delivery-api, notifier-api, gateway, sync-api, builder-api.
`worker` jest **nieobecny**. Worker revision :1 z 2026-04-27 — nigdy nie był deployowany przez CI/CD.

**2. DEV IAM roles w QA task definitions**

```
executionRoleArn: infra-puzzler-b2b-dev-ecs-execution-role
taskRoleArn:      infra-puzzler-b2b-dev-ecs-task-role
```

Potwierdzono w `envs/qa/terraform.tfvars`:
```hcl
ecs_execution_role_arn = "arn:aws:iam::698220459519:role/infra-puzzler-b2b-dev-ecs-execution-role"
ecs_task_role_arn      = "arn:aws:iam::698220459519:role/infra-puzzler-b2b-dev-ecs-task-role"
```
**To jest intencjonalne w Terraform** — QA-specific IAM roles nie zostały jeszcze stworzone.
CI/CD perpetuuje DEV roles przez pull-and-update.

**3. Terraform blind na container_definitions**

`ignore_changes = [container_definitions]` → Terraform apply z `15ae29e` usunął AzureAd z kodu, ale nie stworzył nowej task definition revision. `terraform plan` pokazuje "no changes" — porównuje state do siebie.

**4. CI/CD pipeline jest generic ECS image updater**

Brak canonical task definition template w repo. Live ECS revision jest jedynym source of truth dla CI/CD. Każdy deploy utrwala wszystkie pola poprzedniego revision.

### Rekomendacja architektury

**Wariant C (rekomendowany):** Terraform zarządza structural baseline (IAM, log groups, networking) eksportowanym przez SSM. CI/CD buduje task definition deterministycznie z whitelist secrets — NIE używa pull-and-update.

Szczegóły 3 wariantów: `40-runbooks/` lub następny commit.

### Quick fix (bez refaktoru pipeline)

Dla każdego serwisu: wygenerować clean task def bez AzureAd secrets (`jq del`), zarejestrować ręcznie, ustawić serwis. CI/CD użyje tej czystej revision jako bazy przy następnym deploy. **Wymaga decyzji biznesowej:** czy QA potrzebuje AzureAd? (`appsettings.QA.json` ma AzureAd sekcję.)

### Stan po sesji

```
infra repo: staged envs/dev/services.tf — do commita
untracked:  docs/db-access.md — bez decyzji
apply:      NIE wykonany
```

---

## 2026-05-07 — DEV: ownership parity z QA bez runtime drift

**Scope:** DEV — Terraform ownership guardrails / ECS service secrets
**Repo:** `~/projekty/mako/aws-projects/infra-puzzler-b2b-final`
**Wynik:** IaC zmienione i staged ✅ | plan DEV = no-op | apply nie wykonany

### Zmiana

`envs/dev/services.tf` dostosowany do modelu QA:
- usunięto `local.azuread_secrets`
- 7x `merge(local.docdb_secrets, local.azuread_secrets)` → `local.docdb_secrets`
- AzureAd secret metadata i secret version zostają w Secrets Manager/IaC, ale nie są wstrzykiwane do ECS task definitions jako runtime env

### Guardraile potwierdzone

- `envs/dev/secrets.tf`: `ignore_changes = [secret_string]` na `docdb`, `azuread`, `jumphost_ssh`
- `modules/core/documentdb/main.tf`: `ignore_changes = [master_password]`
- `modules/core/ecs-service/main.tf`: `ignore_changes = [container_definitions]`
- `modules/core/ecs-service/main.tf`: `ignore_changes = [task_definition, desired_count]`
- `envs/dev/terraform.tfvars`: account `698220459519`, ALB CIDR `195.117.107.110/32`, live-aligned app image tags zachowane
- worker nadal `nginx:latest`, zgodnie z live/desired=0 komentarzem

### Walidacja

```
terraform fmt envs/dev/services.tf                         → OK
AWS_PROFILE=puzzler-pbms terraform -chdir=envs/dev init    → OK
AWS_PROFILE=puzzler-pbms terraform -chdir=envs/dev validate → Success
terraform -chdir=envs/dev plan -no-color -input=false      → No changes
```

Plan był wykonany z placeholderami dla wymaganych sensitive `TF_VAR_*`; `ignore_changes` zadziałało, więc nie było rotacji sekretów, zmian `master_password`, nowych ECS task definitions ani rollbacku services.

### Stan repo po sesji

- staged: `envs/dev/services.tf`
- untracked, nietknięte: `docs/db-access.md`
- rekomendowany commit:
  `fix(dev): align Terraform drift guardrails with QA ownership model`

---

## 2026-05-07 — QA: usunięcie AzureAd env vars z serwisów ECS

**Scope:** QA — wszystkie serwisy backendowe (gateway, core, delivery, notifier, worker, sync, builder)
**Repo:** `~/projekty/mako/aws-projects/infra-puzzler-b2b-final/envs/qa`
**Wynik:** IaC zmienione i zaaplikowane ✅ | runtime cleanup wymaga force-replace (patrz niżej)

### Root cause / motywacja

Developer potwierdził: `AzureAd__ClientId`, `AzureAd__ClientSecret`, `AzureAd__ClientSecretId`, `AzureAd__TenantId` są niepotrzebne na QA — aplikacja czyta z `appsettings`. Zmienne były skopiowane z dev i wstrzykiwane przez ECS jako ECS secrets z Secrets Manager.

### Gdzie były zdefiniowane

- `local.azuread_secrets` w `envs/qa/services.tf:42-47` — map 4 zmiennych → ARN Secrets Manager
- Używane przez `merge(local.docdb_secrets, local.azuread_secrets)` w 7 serwisach
- Secrets Manager: `infra-puzzler-b2b/qa/azuread` — nadal istnieje (nie usunięte, cel: Key Vault)

### Zmiany IaC

**`envs/qa/services.tf`** (core change):
- Usunięto `local.azuread_secrets` block
- 7x `merge(local.docdb_secrets, local.azuread_secrets)` → `local.docdb_secrets`
- Worker service miał różne wcięcia — naprawione osobno

**`envs/qa/secrets.tf`** (prerequisite safety fixes — parity z dev):
- `lifecycle { ignore_changes = [secret_string] }` dodane do `aws_secretsmanager_secret_version.docdb`
- `lifecycle { ignore_changes = [secret_string] }` dodane do `aws_secretsmanager_secret_version.azuread`
- `lifecycle { ignore_changes = [secret_string] }` dodane do `aws_secretsmanager_secret_version.jumphost_ssh`

**`modules/core/documentdb/main.tf`** (prerequisite safety fix — wszystkie envs):
- `lifecycle { ignore_changes = [master_password] }` dodane do `aws_docdb_cluster.this`
- Zapobiega incydentowi z dev (nadpisanie hasła przy planowaniu z placeholder)

### Plan / apply

```
terraform fmt -check    → OK (brak outputu)
terraform validate      → Success (only pre-existing deprecated attribute warnings)
terraform plan          → Plan: 0 to add, 1 to change, 0 to destroy
                          1 zmiana: module.app_stack.aws_security_group.alb
                          — description "MakoLab office HTTP/HTTPS" → "HTTP/HTTPS"
                          — pre-existing drift, niezwiązane z naszą zmianą, bezpieczne
terraform apply         → Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

### Stan runtime po apply

Serwisy RUNNING, zdrowe, bez AzureAd errors:
```
gateway:   running:1/desired:1, rev:5, logi: 200 OK requests ✅
core:      running:1/desired:1, rev:5, logi: jobs processing ✅
delivery:  running:1/desired:1, rev:5
notifier:  running:1/desired:1, rev:5
sync:      running:1/desired:1, rev:5
builder:   running:1/desired:1, rev:5
worker:    desired:0 (wyłączony przez scheduler)
```

### Ograniczenie: runtime vars nadal w kontenerach

`ignore_changes = [container_definitions]` na task definitions → apply NIE tworzy nowych rewizji. Zmienne są usunięte z IaC, ale nadal obecne w task definition rev:5 działających kontenerów. Znikną przy:
- **automatycznie:** następnym deployu CI/CD (nowy obraz → nowy task def)
- **ręcznie:** `terraform apply -replace=module.<svc>.module.ecs_service.aws_ecs_task_definition.this` + `aws ecs update-service` dla każdego z 7 serwisów

### Do zrobienia (opcjonalnie, nie blokujące)

- [ ] Force-replace task definitions dla natychmiastowego runtime cleanup
- [ ] Rozważyć usunięcie `aws_secretsmanager_secret.azuread` z QA gdy target: Key Vault

---

## 2026-05-07 — Notifier crash loop: MongoConfigurationException

**Serwis:** `infra-puzzler-b2b-dev-notifier` (ECS Fargate)
**Repo:** `~/projekty/mako/aws-projects/infra-puzzler-b2b-final`
**Wynik:** crash loop zażegnany, serwis RUNNING od 10:15:05 ✅

### Root cause

Task definition (rev 65, potem 69) nie zawierała mappingu `ConnectionStrings__PBMS_DB_notifier` w sekcji `secrets` kontenera. Aplikacja .NET otrzymywała pusty string zamiast MongoDB connection string → `MongoConfigurationException: The connection string '' is not valid` → crash co ~30s.

Secret `infra-puzzler-b2b/dev/docdb` zawierał klucz `connection_string_notifier` z poprawnym connection string. Mapowanie było zdefiniowane w Terraform (`secrets.tf` → `local.docdb_secrets`) ale nie było w faktycznej task definition — prawdopodobnie rev 65 było wdrożone przed dodaniem tego mappingu do kodu Terraform.

### Fix

1. `terraform apply -replace=module.app_stack.module.notifier[0].aws_ecs_task_definition.this` z prawdziwymi sensitive vars
   → task definition rev 70 z poprawnym mappingiem `ConnectionStrings__PBMS_DB_notifier`
2. `aws ecs update-service --task-definition infra-puzzler-b2b-dev-notifier:70`
   → serwis skierowany na rev 70

### Incident w trakcie naprawy (WAŻNE)

`aws_docdb_cluster.master_password` nadpisane wartością `"plan-placeholder"` podczas pierwszego apply. Przyczyna: brak `lifecycle { ignore_changes = [master_password] }` na `aws_docdb_cluster`. Wszystkie sensitive vars (w tym `documentdb_password`) muszą być podane bez defaults i nie mają guardrails jeśli nie ma `ignore_changes`.

**Naprawione:** drugi apply z prawdziwym hasłem `TF_VAR_documentdb_password="64IAJ#<233Bt"`.

**Rekomendacja:** dodać `ignore_changes = [master_password]` do `modules/core/docdb/main.tf`.

### Weryfikacja końcowa

```
runningCount: 1 / desiredCount: 1 / pendingCount: 0
task: 533d3891 | rev 70 | RUNNING od 10:15:05
logi: "PBMS Notifier API started." — brak MongoConfigurationException ✅
```

### Kluczowe pliki

- `envs/dev/secrets.tf` — `local.docdb_secrets` z mappingiem `ConnectionStrings__PBMS_DB_notifier`
- `envs/dev/services.tf` — `merge(local.docdb_secrets, local.azuread_secrets)` → notifier container secrets
- `modules/core/ecs-service/main.tf:29` — `ignore_changes = [container_definitions]` (blokuje normal plan)

---

## 2026-05-07 — DEV/QA jumphost final stabilization

**Repo:** `~/projekty/mako/aws-projects/infra-puzzler-b2b-final`  
**AWS:** profile `puzzler-pbms`, account `698220459519`, region `eu-west-2`  
**Result:** DEV and QA jumphosts operational for SSH, ECS Exec and DocumentDB TCP forwarding.

### Root causes

- QA `jumphost-v10` ECR tag was `linux/arm64` only while Fargate ran `x86_64`.
- ECS Exec was disabled on DEV and QA jumphost services.
- QA `jumphost_ssh` secret contained literal `$(cat ~/.ssh/id_rsa.pub)`.
- Dockerfile appended unsupported Alpine/OpenSSH option `UsePAM no`.
- `modules/core/ecs-service` ignores `task_definition`, so Terraform registered new task definitions but did not automatically switch services to them.

### Changes

- `Dockerfile`
  - removed `UsePAM no`
  - kept `PermitRootLogin no`, `PasswordAuthentication no`, `PubkeyAuthentication yes`
  - enforced `AllowTcpForwarding yes` via replacement
- `modules/pattern/db-jumphost`
  - added `enable_execute_command`
  - passed it into `modules/core/ecs-service`
- `envs/dev/services.tf`, `envs/qa/services.tf`
  - enabled ECS Exec only for `module "db_jumphost"`
- `envs/dev/terraform.tfvars`, `envs/qa/terraform.tfvars`
  - `jumphost_image` -> `jumphost-v11`

### Image

Built and pushed deterministic amd64 image:

```text
tag:      jumphost-v11
platform: linux/amd64
digest:   sha256:4cd031cee7da3f5b874f3fadab93399a945ff4ccfecb6a333a4a7ed70f13e66d
DEV:      698220459519.dkr.ecr.eu-west-2.amazonaws.com/infra-puzzler-b2b-app-dev:jumphost-v11
QA:       698220459519.dkr.ecr.eu-west-2.amazonaws.com/infra-puzzler-b2b-app-qa:jumphost-v11
```

### Deployment

Targeted Terraform apply only:

- DEV/QA `aws_secretsmanager_secret_version.jumphost_ssh`
- DEV/QA `module.db_jumphost.module.ecs_service.aws_ecs_task_definition.this`
- DEV/QA `module.db_jumphost.module.ecs_service.aws_ecs_service.this`

Then explicit jumphost-only ECS service update:

```text
DEV service -> infra-puzzler-b2b-dev-jumphost:11
QA service  -> infra-puzzler-b2b-qa-jumphost:4
```

No ALB, VPC, DocumentDB, app ECS services or unrelated secrets were changed.

### Runtime verification

DEV:

```text
service: desired=1 running=1 pending=0 rollout=COMPLETED
task:    41dab89d34894d9e9c74aad1bfc2e819
image:   jumphost-v11, digest sha256:4cd031cee7da3f5b874f3fadab93399a945ff4ccfecb6a333a4a7ed70f13e66d
arch:    x86_64
ECS Exec: OK
sshd -T: allowtcpforwarding yes; permitrootlogin no; passwordauthentication no; pubkeyauthentication yes
authorized_keys: 2 lines, non-empty
port 22: listening
container -> DocumentDB:27017: open
SSH login with configured RSA key: OK
local tunnel 127.0.0.1:37017 -> DEV DocumentDB: OK
```

QA:

```text
service: desired=1 running=1 pending=0 rollout=COMPLETED
task:    85610ee4390b4f158c9507cbee2e32a1
image:   jumphost-v11, digest sha256:4cd031cee7da3f5b874f3fadab93399a945ff4ccfecb6a333a4a7ed70f13e66d
arch:    x86_64
ECS Exec: OK
sshd -T: allowtcpforwarding yes; permitrootlogin no; passwordauthentication no; pubkeyauthentication yes
authorized_keys: 2 lines, non-empty
port 22: listening
container -> DocumentDB:27017: open
SSH login with configured RSA key: OK
local tunnel 127.0.0.1:37018 -> QA DocumentDB: OK
```

### Commits

```text
12fac50 fix(jumphost): stabilize sshd runtime and amd64 image build
a5e5598 fix(terraform): enable ecs exec and normalize jumphost key handling
```

### Remaining repo state

```text
staged:    envs/dev/services.tf
untracked: docs/db-access.md
```

The staged `envs/dev/services.tf` is the earlier DEV guardrail parity change and was intentionally preserved after the jumphost commits.

## 2026-05-07 — DEV DocumentDB Compass URI (read-only discovery)

**Repo:** `~/projekty/mako/aws-projects/infra-puzzler-b2b-final`
**AWS:** profile `puzzler-pbms`, account `698220459519`, region `eu-west-2`
**Operacja:** read-only — secret discovery + local URI generation, bez zmian w AWS

### Cel

Wygenerowanie poprawnego URI do MongoDB Compass przez SSH tunnel (localhost:27117 → DEV DocDB:27017).

### Stan secretu `infra-puzzler-b2b/dev/docdb`

Klucze obecne w secrecie:

```
connection_string
connection_string_automation
connection_string_core
connection_string_notifier
database_automation
database_core
database_notifier
host
password
port
username
```

Weryfikacja:
- `username` = `dbadmin` ✅
- `password` niepusty ✅
- `connection_string_automation` wskazuje `PBMS_DB_automation` ✅
- `connection_string_automation` zawiera `replicaSet=rs0` — usunięty tylko z lokalnego URI

### URI do MongoDB Compass

Tunnel: `localhost:27117` → `infra-puzzler-b2b-dev-puzzler-mongo.cluster-*.docdb.amazonaws.com:27017`

```
mongodb://dbadmin:***@localhost:27117/PBMS_DB_automation?authSource=admin&directConnection=true&tls=true&tlsAllowInvalidCertificates=true&retryWrites=false
```

Parametry konieczne przez tunnel:
- `directConnection=true` — bez tego Compass próbuje discovery przez replica set, co nie działa przez tunel
- `replicaSet=rs0` USUNIĘTY — przez localhost tunnel RS discovery nie działa; secret AWS pozostał niezmieniony
- `tlsAllowInvalidCertificates=true` — DocDB używa własnego CA; cert nie matchuje `localhost`
- `retryWrites=false` — DocDB nie obsługuje retryable writes

### Stan repo (bez zmian)

```
staged:    envs/dev/services.tf  (guardrail parity DEV — do commita)
untracked: docs/db-access.md
apply:     NIE wykonany
```

---

## 2026-05-06 — IaC ownership normalization commit

**Branch:** `feat/dev-jumphost-runtime-secret`
**Commit:** `72c3764`
**Repo:** `~/projekty/mako/aws-projects/infra-puzzler-b2b-final`

### Co zrobiono

Przygotowano i zacommitowano minimalny, bezpieczny commit normalizujący własność zasobów ALB i ECS:

- `alb_ingress_cidr_blocks = ["195.117.107.110/32"]` — ALB HTTP/HTTPS dostępny tylko z biura MakoLab (dev i qa)
- `ignore_changes = [task_definition]` — rewizje task definition zarządzane przez CI/CD, nie Terraform; zaimplementowane w `modules/core/ecs-service/main.tf`
- Vendor modułów lokalnie (`modules/core/`, `modules/pattern/`) — usunięto zależność od remote GitLab w runtime
- Wszystkie moduły `ecs-microservice` i `db-jumphost` przełączone z `git@gitlab...` na ścieżki lokalne
- `envs/qa/backend.tf`: placeholder `FILL_IN` → `698220459519-terraform-state`
- `.gitignore`: literówka `autorized_keys` → `authorized_keys`, dodano `.env`, `*.pem`, `*.key`

### Technika stagingu

`envs/dev/services.tf` zawierał mieszane zmiany (source paths + notifier DB vars). Użyto:
```bash
git show HEAD:envs/dev/services.tf > /tmp/services_clean.tf
perl -i -pe 's|git@gitlab...|../../modules/pattern/...|g' /tmp/services_clean.tf
NEW_HASH=$(git hash-object -w /tmp/services_clean.tf)
git update-index --cacheinfo 100644,"$NEW_HASH",envs/dev/services.tf
```
Efekt: staged tylko source changes; notifier hunks pozostały wyłącznie w working tree.

### Walidacja

- `terraform fmt -check`: ✅ PASS
- `terraform validate`: ❌ FAIL — pre-existing `envs/dev/alb_frontend.tf` (untracked, broken) references undeclared `var.frontend_alb_certificate_arn`. Nie wprowadzono przez ten commit.

### Co WYKLUCZONE z commitu (nadal w working tree)

| Plik | Powód wykluczenia |
|------|-------------------|
| `Dockerfile` | AllowTcpForwarding yes — jumphost SSH change, osobny commit |
| `envs/dev/secrets.tf` | Dodaje `database_notifier` / `connection_string_notifier` — osobna praca |
| `envs/dev/services.tf` (2 hunki) | `PBMS_DB_NOTIFIER`, `ConnectionStrings__PBMS_DB_notifier` — notifier |
| `envs/qa/terraform.tfvars` | **BLOKADA: hardcoded secrets** — patrz niżej |
| `envs/qa/main.tf` | Coupled z `envs/qa/secrets.tf` (niestaged) |
| `envs/qa/variables.tf` | Zbyt wiele niepowiązanych additions |
| `envs/qa/services.tf` (untracked) | Zawiera notifier vars, coupled z secrets.tf |
| `envs/qa/secrets.tf` (untracked) | Notifier DB work |
| `envs/qa/cloudwatch.tf`, `iam.tf`, `output.tf`, `schedulers.tf`, `service_discovery.tf` | QA build-out in-progress |
| `envs/dev/alb_frontend.tf` (untracked) | Broken — undeclared variable |
| `scripts/` | Jumphost tooling (db-connect.*) |

### 🔴 Krytyczny blocker — secrets w working tree

`envs/qa/terraform.tfvars` zawiera hardcoded credentials:
- `documentdb_password`
- `azuread_client_secret` — **ROTATE IMMEDIATELY**
- `azuread_tenant_id`, `azuread_client_id`, `azuread_client_secret_id`

Plik nie był commitowany (tylko working tree). Ale `azuread_client_secret` powinien być zrotowany prewencyjnie. Po rotacji — wyczyścić plik z hardcoded values, zastąpić instrukcją `export TF_VAR_*`.

### Następne kroki (kolejne commity)

1. Rotate `azuread_client_secret` w Azure AD
2. Wyczyścić `envs/qa/terraform.tfvars` (secrets → TF_VAR_* only)
3. Commit: notifier DB (`envs/dev/secrets.tf` + notifier hunks `services.tf`)
4. Commit: jumphost (`Dockerfile` TCP forwarding + `scripts/`)
5. Commit: QA IaC (`envs/qa/main.tf` + `variables.tf` + `services.tf`) — po cleanup secrets + naprawie validate
6. Fix `envs/dev/alb_frontend.tf` (dodać var lub usunąć)
