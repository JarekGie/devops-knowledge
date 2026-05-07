---
title: session-log — puzzler-b2b
project: puzzler-b2b
client: mako
tags: [#terraform, #aws, #ecs, #alb]
---

# Session Log — puzzler-b2b / PBMS

Chronologicznie, najnowszy na górze.

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
