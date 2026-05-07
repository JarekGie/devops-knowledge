---
title: session-log — puzzler-b2b
project: puzzler-b2b
client: mako
tags: [#terraform, #aws, #ecs, #alb]
---

# Session Log — puzzler-b2b / PBMS

Chronologicznie, najnowszy na górze.

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
