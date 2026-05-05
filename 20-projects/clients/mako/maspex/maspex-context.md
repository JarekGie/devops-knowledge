---
title: maspex-context
client: mako
project: maspex
domain: client-work
document_type: runtime-context
context_type: cloud-detective-snapshot
classification: internal
source_of_truth: false
runtime_snapshot: true
aws_profile: maspex-cli
account_id: "969209893152"
regions:
  - eu-west-1
  - us-east-1
iac: terraform
repository: "~/projekty/mako/aws-projects/infra-maspex/"
created: 2026-05-01
updated: 2026-05-05
last_verified: "2026-05-05"
scan_method: cloud-detective-v2
last_verified_by: claude
tags:
  - aws
  - terraform
  - ecs
  - fargate
  - mako
  - maspex
---

# maspex — Kapsel (aplikacja konkursowa Maspex)

#aws #terraform #ecs #fargate #mako #maspex

**Data:** 2026-05-05
**Typ dokumentu:** snapshot runtime / context wejściowy
**Source of truth:** AWS live + IaC + Terraform state
**Tryb skanowania:** read-only
**Poziom pewności snapshotu:** częściowa — UAT potwierdzone live, preprod częściowe (API DOWN — trwa od 2026-05-01), prod nieweryfikowane
**Projekt:** Platforma konkursowa Kapsel — Next.js API + admin panel + bot, CloudFront → ALB → ECS Fargate, Redis ElastiCache, Supabase/PostgREST jako downstream.
**OrgAccountID:** nieustalone
**Account ID:** `969209893152`
**Role:** nieustalone
**AWS profile:** `maspex-cli`
**IAM principal:** `makolab-ci` (IAM user, uprawnienia CI)
**Region główny:** `eu-west-1` (CloudFront / ACM dodatkowo w `us-east-1`)

---

## Snapshot metadata

| Pole | Wartość |
|------|---------|
| scan_date | 2026-05-05 |
| scan_scope | partial |
| regions_checked | eu-west-1, us-east-1 (ACM only) |
| repo_checked | częściowo — git log (brak nowych commitów od 2026-05-01) |
| iac_checked | częściowo — git log bez nowych commitów |
| runtime_checked | tak — ECS UAT/preprod, ALB target health, CW alarms, ACM eu-west-1+us-east-1, Secrets Manager, WAF |
| extra_regions_checked | us-east-1 (ACM only) |

---

## Zakres snapshotu vs audytu

| Obszar | Typ | Zakres | Źródło |
|--------|-----|--------|--------|
| Runtime health (ECS/ALB) | snapshot | live AWS — UAT + preprod | live AWS |
| CFN stack status | nie dotyczy | projekt używa Terraform | — |
| IaC analiza | snapshot | partial — struktura, backend.hcl, task-def revision :1 | IaC |
| Tagging coverage | niezweryfikowane | resourcegroupstaggingapi nie uruchomiono | — |
| FinOps / cost allocation | audit (external) | patrz [[finops-as-is-estimate]] i [[finops-uat-preprod-cost-estimate-2026-04]] | vault historyczny |
| Security (WAF) | niezweryfikowane | list-web-acls nie wykonano | — |
| ACM certs | snapshot | eu-west-1 + us-east-1 sprawdzone live | live AWS |
| Secrets Manager | snapshot | list-secrets wykonano | live AWS |
| CloudWatch alarms | snapshot | describe-alarms wykonano | live AWS |
| Bot target health | snapshot | describe-target-health wykonano | live AWS |
| Prod environment | niezweryfikowane | nie sprawdzano ECS prod live | — |

---

## Repozytorium kodu

- lokalna ścieżka (infra): `~/projekty/mako/aws-projects/infra-maspex/`
- lokalna ścieżka (app): `~/projekty/mako/next-core-app/`
- remote (infra): `git@gitlab.makolab.net:admin-makolab/dc/aws-projects/infra-maspex-kapsel.git`
- aktywny branch: `main`
- IaC: **Terraform** (provider `hashicorp/aws ~> 5.0`, aktualnie `5.100.0`)

Struktura repo infra:
```
terraform/
  bootstrap/   — S3 state bucket, DynamoDB lock table
  envs/        — shared/, uat/, prod/, preprod/
  modules/     — alb, alb-routing, ecs, elasticache, cloudfront, …
```

Ostatnie commity (live, 2026-05-05 — brak nowych od 2026-05-01):
```
6f466af feat(uat): add ECS Application Auto Scaling for maspex-api
6e6b4f1 aktualizacja cloudfront
fd46bf3 Merge branch 'feat/preprod-zaslepka' into 'main'
743d43e fix(preprod): scale api to 1 task, wire api log group to monitoring module
168a569 fix(ecs): manage desired_count via Terraform (remove from lifecycle ignore_changes)
```

Uwaga: commit `743d43e` mówi "scale api to 1 task", ale runtime pokazuje `desired:3` — możliwy drift lub późniejsza zmiana poza commitem. Źródło: IaC + live AWS.

---

## Środowiska

| Env | Region | Account ID | Status | VPC CIDR | Pewność |
|-----|--------|------------|--------|----------|---------|
| shared | eu-west-1 | 969209893152 | IaC istnieje, brak klastra ECS | nieustalone | średnia — IaC + brak live cluster |
| uat | eu-west-1 | 969209893152 | aktywny — 11 tasków running | 10.44.0.0/16 | wysoka — live AWS |
| preprod | eu-west-1 | 969209893152 | częściowo — API 0/3 running (IAM error) | 10.44.0.0/16 | wysoka — live AWS |
| prod | eu-west-1 | 969209893152 | IaC istnieje, live nieweryfikowane | nieustalone | niska — tylko IaC |

VPC: `vpc-0df07c64ea8a8b00e` (10.44.0.0/16), brak Name tagu. Źródło: live AWS.

**Terraform state (S3 + DynamoDB, encrypt=true):**

| Env | Bucket | Key | Lock table |
|-----|--------|-----|------------|
| shared | terraform-state-969209893152 | maspex/shared/terraform.tfstate | terraform-locks-969209893152 |
| uat | terraform-state-969209893152 | maspex/uat/terraform.tfstate | terraform-locks-969209893152 |
| prod | terraform-state-969209893152 | maspex/prod/terraform.tfstate | terraform-locks-969209893152 |

Backend przez `-backend-config=backend.hcl` (wartości nie są hardcode'owane w `backend.tf`). Źródło: IaC.

---

## Architektura (UAT — potwierdzone live)

```text
Internet
  │
  ├── CloudFront E3J76RNXIE2YIG  → kapsel.makotest.pl           (API / frontend UAT)
  ├── CloudFront E3R9U1TWNUJZ11  → kapsel-admin-uat.makotest.pl (admin UAT)
  └── CloudFront E17VHHQJ29MVAB  → twojkapsel.pl / www          (preprod/prod — wymaga potwierdzenia)
        │
        ▼
  ALB maspex-uat (internet-facing, eu-west-1)
  ALB maspex-preprod (internet-facing, eu-west-1)
        │
        ▼
  ECS Fargate — cluster maspex-uat
    ├── maspex-api         (9/9 running)  ─── Redis ElastiCache maspex-uat :6379
    ├── maspex-bot         (2 running / 1 desired) ⚠ wymaga weryfikacji (task replacement?)
    └── maspex-admin-panel (1/1 running)
                                         ─── Supabase/PostgREST (downstream, zewnętrzny)

  ECS Fargate — cluster maspex-preprod
    ├── maspex-preprod-api         (0/3 running) 🔴 IAM error — execution role brak dostępu do secretu
    ├── maspex-preprod-bot         (1/1 running)
    └── maspex-preprod-admin-panel (1/1 running)
```

Przypisanie CloudFront `E17VHHQJ29MVAB` (twojkapsel.pl) do preprod lub prod — **wymaga potwierdzenia** (listener rules niezweryfikowane).

---

## Mikroserwisy / komponenty

| Serwis | Cluster | Ingress | Service Discovery | ECS Exec | Desired | Running | Status |
|--------|---------|---------|-------------------|----------|---------|---------|--------|
| maspex-api | maspex-uat | ALB → CF | brak | niezweryfikowane | 9 | 9 | ✓ ACTIVE |
| maspex-bot | maspex-uat | ALB → CF | brak | niezweryfikowane | 1 | 1 | ⚠ WYSOKI — running:1/desired:1 ale target unhealthy (FailedHealthChecks) od 2026-04-23 (12 dni) |
| maspex-admin-panel | maspex-uat | ALB → CF | brak | niezweryfikowane | 1 | 1 | ✓ ACTIVE |
| maspex-preprod-api | maspex-preprod | ALB | brak | niezweryfikowane | 3 | 0 | 🔴 DOWN — IAM: brak dostępu do maspex/preprod/api (trwa od 2026-05-01, ostatnie STOPPED: 2026-05-05 10:00) |
| maspex-preprod-bot | maspex-preprod | ALB | brak | niezweryfikowane | 1 | 1 | ✓ ACTIVE |
| maspex-preprod-admin-panel | maspex-preprod | ALB | brak | niezweryfikowane | 1 | 1 | ✓ ACTIVE |

Brak Cloud Map / Service Discovery. Brak EventBridge rules. Brak SQS. Źródło: live AWS.

---

## Zasoby kluczowe

| Zasób | Identyfikator | Źródło | Pewność |
|-------|---------------|--------|---------|
| ECS cluster UAT | maspex-uat | live AWS | wysoka |
| ECS cluster preprod | maspex-preprod | live AWS | wysoka |
| ALB UAT | maspex-uat-1361582173.eu-west-1.elb.amazonaws.com | live AWS | wysoka |
| ALB preprod | maspex-preprod-1322298306.eu-west-1.elb.amazonaws.com | live AWS | wysoka |
| CloudFront API/UAT | E3J76RNXIE2YIG → kapsel.makotest.pl | live AWS | wysoka |
| CloudFront admin/UAT | E3R9U1TWNUJZ11 → kapsel-admin-uat.makotest.pl | live AWS | wysoka |
| CloudFront preprod/prod | E17VHHQJ29MVAB → twojkapsel.pl, www.twojkapsel.pl | live AWS | średnia — env niepotwierdzony |
| Redis UAT | maspex-uat.zwowz5.0001.euw1.cache.amazonaws.com:6379 | live AWS | wysoka |
| Redis UAT node type | cache.t3.medium, Redis 7.1.0, single-node | live AWS | wysoka |
| Redis preprod | maspex-preprod (endpoint niepobrany) | live AWS | średnia |
| Redis preprod node type | cache.t3.micro, Redis 7.1.0 | live AWS | wysoka |
| VPC | vpc-0df07c64ea8a8b00e (10.44.0.0/16) | live AWS | wysoka |
| State bucket | terraform-state-969209893152 | IaC backend.hcl | wysoka |
| Lock table | terraform-locks-969209893152 | IaC backend.hcl | wysoka |

---

## Secrets Manager

Nie wypisuj wartości sekretów.

| Secret | Przeznaczenie / zawartość logiczna | Źródło |
|--------|------------------------------------|--------|
| maspex/uat/api | konfiguracja API UAT (klucze, connection strings) | live AWS |

Uwaga: `list-secrets` zwrócił 1 wpis. Jednak task-def `maspex-preprod-api:1` odwołuje się do `maspex/preprod/api` (secret istnieje — błąd to `AccessDeniedException`, nie `ResourceNotFoundException`) — secret preprod/api nie jest widoczny przez `makolab-ci`, mimo że istnieje. Sekrety prod mogą być niewidoczne z tych samych powodów.

```
Secrets Manager: 1 secret widoczny w eu-west-1 (sprawdzone live)
Dodatkowe sekrety mogą istnieć (niezweryfikowane dla makolab-ci):
- maspex/preprod/api — istnieje (potwierdzone przez AccessDeniedException w stopped task)
- maspex/prod/api — nieustalone
- SSM Parameter Store — niezweryfikowane
```

---

## ACM Certificates

| Domena | Region | Status | Uwagi |
|--------|--------|--------|-------|
| kapsel-admin-uat.makotest.pl | eu-west-1 | ISSUED ✓ | admin UAT |
| twojkapsel.pl | eu-west-1 | ISSUED ✓ | preprod/prod ALB |
| twojkapsel.pl | us-east-1 | ISSUED ✓ | CloudFront (us-east-1 required) |
| twojkapsel-admin.makolab.pro | eu-west-1 | **FAILED ⛔** | Zmiana z PENDING_VALIDATION (2026-05-01) → FAILED (2026-05-05). Certyfikat wygasł bez walidacji — wymaga ponownego request. |
| twojkapsel-admin.makolab.pro | us-east-1 | **FAILED ⛔** | Zmiana z PENDING_VALIDATION (2026-05-01) → FAILED (2026-05-05). Wymaga ponownego request. |

---

## Tagging / FinOps / LLZ / AWS WAF readiness

**Źródło historyczne:** [[finops-as-is-estimate]] i [[finops-uat-preprod-cost-estimate-2026-04]] — jeśli zawierają audyt tagów.
**Bieżący scan:** sample-based (0 zasobów sprawdzonych live przez resourcegroupstaggingapi — nie uruchomiono)

| Obszar | Status | Uwagi |
|--------|--------|-------|
| FinOps — cost allocation tags (Project/Environment/CostCenter) | niezweryfikowane | resourcegroupstaggingapi nie uruchomiono |
| LLZ tagging standard (Project/Environment/Owner/ManagedBy/CostCenter) | niezweryfikowane | nie uruchomiono |
| ECS/Fargate — tag propagation do tasków (`propagate_tags`) | niezweryfikowane | nie sprawdzono w task-def ani describe-services |
| ECR — tagi na repozytoriach | niezweryfikowane | nie sprawdzono |
| S3 — tagi na bucketach | niezweryfikowane | nie sprawdzono |
| CloudWatch Log Groups — tagi | niezweryfikowane | nie sprawdzono |
| VPC / Endpoints — tagi | PARTIAL | VPC bez Name tagu (sprawdzone), pozostałe niezweryfikowane |
| AWS WAF — obecność i przypisanie właściciela | GAP | `wafv2 list-web-acls --scope REGIONAL` zwróciło pustą listę (live AWS 2026-05-05). Brak WAF względem LLZ/WAF-readiness; nie oznacza aktywnej awarii runtime. |

### Wymagane tagi LLZ

| Tag | Oczekiwana wartość | Status |
|-----|--------------------|--------|
| Project | maspex | nieustalone |
| Environment | prod / uat / preprod | nieustalone |
| Owner | team / e-mail | nieustalone |
| ManagedBy | Terraform | nieustalone |
| CostCenter | ID działu / projektu | nieustalone |

### Wniosek

Pokrycie tagów i gotowość WAF są niezweryfikowane w bieżącym skanie — nie uruchomiono `resourcegroupstaggingapi get-resources` ani `wafv2 list-web-acls`. Znany fakt: VPC nie ma Name tagu (co utrudnia nawigację). Pełna ocena wymaga osobnego skanu tagowania.

### Następne kroki

| Akcja | Priorytet | Kto |
|-------|-----------|-----|
| Uruchom `resourcegroupstaggingapi get-resources` i sprawdź pokrycie tagów | ŚREDNI | DevOps |
| Sprawdź `wafv2 list-web-acls` | ŚREDNI | DevOps |

---

## Scheduler / automatyzacje

| Automatyzacja | Harmonogram | Zakres | Uwagi |
|--------------|-------------|--------|-------|
| — | — | — | Brak EventBridge rules (live AWS, eu-west-1) |

---

## ECS / runtime config

| Parametr | Wartość |
|----------|---------|
| Launch type | FARGATE |
| Task def API UAT | maspex-api:53 |
| Task def bot UAT | maspex-bot:8 |
| Task def admin-panel UAT | maspex-admin-panel:25 |
| Task def API preprod | maspex-preprod-api:1 |
| Task def bot preprod | maspex-preprod-bot:1 |
| Task def admin-panel preprod | maspex-preprod-admin-panel:11 |
| Auto-scaling (UAT API) | Target Tracking — CPU + Memory |
| preprod-api image | 969209893152.dkr.ecr.eu-west-1.amazonaws.com/maspex-api:coreapp-uat-303 |
| preprod-api secrets | maspex/preprod/api (ConnectionStrings__Redis) |

---

## Observability

**Ważne:** CloudWatch alarms NIE są równoznaczne z aktualnym stanem runtime. Zawsze weryfikuj przez `describe-target-health` i `describe-tasks`.

**Runtime health (live, 2026-05-05):**

| Element | Status | Uwagi |
|---------|--------|-------|
| maspex-uat — maspex-api | ✓ healthy | 9/9 tasków running |
| maspex-uat — maspex-bot | ⚠ WYSOKI | running:1/desired:1 ale target unhealthy (FailedHealthChecks) od 2026-04-23 — 12 dni. NIE jest deployment cycle. |
| maspex-uat — maspex-admin-panel | ✓ healthy | 1/1 |
| maspex-preprod — maspex-preprod-api | 🔴 DOWN | 0/3 running — IAM: AccessDeniedException na secretsmanager:GetSecretValue (trwa od 2026-05-01) |
| maspex-preprod — bot, admin-panel | ✓ healthy | |
| ALB UAT | ✓ active | |
| ALB preprod | ✓ active | ALB działa, API tasks nie startują |
| Redis UAT | ✓ available | cache.t3.medium |
| Redis preprod | ✓ available | cache.t3.micro |

**Bot target health (live, 2026-05-05 — describe-target-health):**

| Target IP | Port | Health | Reason |
|-----------|------|--------|--------|
| 10.44.2.67 | 8080 | draining | Target.DeregistrationInProgress |
| 10.44.3.68 | 8080 | unhealthy | Target.FailedHealthChecks |

Interpretacja (2026-05-05): bot service desired:1/running:1, ale target (10.44.3.68) jest unhealthy. Stary task (10.44.2.67) draining. Alarm aktywny od 2026-04-23 (12 dni) — **to NIE jest tymczasowy deployment cycle**; bot nie przechodzi health checków. Poprzedni snapshot (2026-05-01) oceniał jako możliwy cykl zastępowania — teraz escalacja do WYSOKI.

**CloudWatch alarms (live, 2026-05-05):**

| Alarm | Stan | Metric | Kontekst / aktualny? |
|-------|------|--------|----------------------|
| TargetTracking maspex-uat/maspex-api AlarmLow (Memory) | ALARM | MemoryUtilization < 67.5% | Auto-scaling scale-down po load teście (ostatni punkt: 2026-04-28) — stale/historyczny artefakt, nie awaria runtime |
| TargetTracking maspex-uat/maspex-api AlarmLow (CPU) | ALARM | CPUUtilization < 54% | Auto-scaling scale-down po load teście (ostatni punkt: 2026-04-29) — stale/historyczny artefakt, nie awaria runtime |
| maspex-uat-alb-unhealthy-hosts-bot | ALARM | UnHealthyHostCount > 0 | **AKTUALNY** — potwierdzone describe-target-health 2026-05-05; alarm od 2026-04-23 (12 dni); bot nie przechodzi health checks |
| Pozostałe alarmy preprod | OK | — | |

**Log groups (live, 2026-05-05 — describe-log-groups, pełna lista):**

| Log group | Retencja | Uwagi |
|-----------|----------|-------|
| /maspex/uat/admin-panel | 30 dni | ✓ aktywny |
| /maspex/uat/bot | 30 dni | ✓ aktywny |
| /maspex/uat/contest-service | 30 dni | brak serwisu ECS — relikt lub feature flag |
| /maspex/preprod/admin-panel | 30 dni | ✓ aktywny |
| /maspex/preprod/bot | 30 dni | ✓ aktywny |
| /maspex/preprod/contest-service | 30 dni | brak serwisu ECS — relikt lub feature flag |
| /maspex/preprod/api | — | **absent** — brak log group; preprod-api nigdy nie startowało (0/3 running) |
| /maspex/uat/api | — | **absent** — brak log group; możliwe że api-UAT loguje do /maspex/shared/maspex-api |
| /maspex/shared/maspex-api | 90 dni | shared — może być log group dla UAT api (wymaga potwierdzenia) |
| /maspex/shared/maspex-frontend | 90 dni | shared — brak klastra ECS w shared |
| /maspex/shared/maspex-worker | 90 dni | shared — brak klastra ECS w shared |
| /aws/ecs/containerinsights/maspex-uat/performance | **1 dzień** | ⚠ retencja zbyt krótka dla post-incident debugging |
| /aws/ecs/containerinsights/maspex-preprod/performance | **1 dzień** | ⚠ retencja zbyt krótka dla post-incident debugging |
| /aws/elasticache/maspex-uat/redis | 30 dni | ✓ |
| /aws/elasticache/maspex-preprod/redis | 30 dni | ✓ |

---

## Znane problemy / dług techniczny

| Problem | Priorytet | Evidence | Opis |
|---------|-----------|----------|------|
| maspex-preprod-api: 0/3 running — **przyczyna zidentyfikowana, trwa od 2026-05-01** | WYSOKI | `describe-tasks` 2026-05-05 10:00: `ResourceInitializationError: AccessDeniedException: ...maspex-preprod-api-execution is not authorized to perform: secretsmanager:GetSecretValue on resource: ...maspex/preprod/api-STbBy3` | Execution role `maspex-preprod-api-execution` nie ma uprawnień do sekretu `maspex/preprod/api`. Wymaga dodania policy `secretsmanager:GetSecretValue` na ARN `maspex/preprod/api-*` do roli w Terraform. Brak działań przez 4 dni. |
| twojkapsel-admin.makolab.pro **FAILED** — ESCALACJA (było PENDING) | WYSOKI | ACM eu-west-1 + us-east-1, scan 2026-05-05 | Status zmienił się z PENDING_VALIDATION (2026-05-01) → FAILED (2026-05-05). Certyfikat wygasł bez walidacji DNS — wymaga ponownego `request-certificate` + walidacji DNS. Blokuje HTTPS dla admin preprod/prod. |
| maspex-bot: target unhealthy od 12 dni — ESCALACJA (było NISKI) | WYSOKI | `describe-target-health` 2026-05-05: 10.44.3.68:8080 = unhealthy (FailedHealthChecks); 10.44.2.67 draining. Alarm ALARM od 2026-04-23. | NIE jest deployment cycle — bot desired:1/running:1, ale serwis nie przechodzi health checków od 12 dni. Wymaga diagnozy health check config (port, path, thresholds) i logów /maspex/uat/bot. |
| Brak WAF (REGIONAL eu-west-1) — potwierdzone | WYSOKI | `wafv2 list-web-acls --scope REGIONAL` = `{"WebACLs": []}` 2026-05-05 | Brak WAF względem LLZ/WAF-readiness; nie oznacza aktywnej awarii runtime. Governance gap. |
| Container Insights retencja 1 dzień | NISKI | `describe-log-groups` 2026-05-05 | `/aws/ecs/containerinsights/maspex-uat/performance` + `maspex-preprod/performance` — 1d retencja; utrudnia debugging po incydencie. |
| /maspex/uat/api log group absent — api loguje do /maspex/shared/maspex-api? | NISKI | `describe-log-groups` 2026-05-05 — brak /maspex/uat/api | UAT api (9/9 running) nie ma dedykowanej log group — możliwe logowanie do /maspex/shared/maspex-api (90d). Wymaga potwierdzenia w task-def. |
| contest-service log groups bez serwisu | INFO | `describe-log-groups` | Log groups dla UAT + preprod bez odpowiadającego serwisu ECS — relikt lub niedokończona migracja. |
| Sekrety: widoczny tylko 1 wpis dla makolab-ci | INFO | `list-secrets`: 1 wynik (maspex/uat/api, last changed 2026-03-19); `maspex/preprod/api` istnieje (AccessDeniedException potwierdza) | IAM user makolab-ci nie ma dostępu do wszystkich sekretów — możliwe celowe ograniczenie. |
| VPC bez Name tagu | INFO | `describe-vpcs`: name: null | Utrudnia nawigację; może być celowe. |
| Drift desired_count preprod-api | INFO | commit `743d43e` "scale api to 1 task" vs runtime desired:3 | Commit sugeruje desired:1, runtime pokazuje desired:3 — możliwy późniejszy change poza commitem lub Terraform state drift. |

---

## Różnice IaC vs Runtime

| Obszar | IaC | Runtime AWS | Ocena |
|--------|-----|-------------|-------|
| preprod-api execution role | IaC definiuje rolę execution (zakładane) | rola nie ma `secretsmanager:GetSecretValue` na `maspex/preprod/api-*` | **rozbieżność** — brak IAM permission |
| preprod-api desired count | commit sugeruje 1 | desired:3 | **rozbieżność** — możliwy drift lub brak commitu |
| preprod-api image | nieustalone z IaC | `maspex-api:coreapp-uat-303` (tag UAT w preprod env) | **wymaga potwierdzenia** — może być celowe |
| shared env | Terraform env istnieje | brak klastra ECS, log groups obecne | nieustalone — shared może być tylko VPC/networking |
| prod env | Terraform env istnieje | stan live nieweryfikowany | **nieustalone** |
| Terraform backend | backend.hcl lokalnie, S3 bucket aktywny | bucket 969209893152 dostępny | zgodne |
| Redis (UAT) | nieustalone z IaC (nie czytano modułu) | single-node (brak replication group) | wymaga potwierdzenia |
| Auto-scaling API | zdefiniowane (target tracking CPU+MEM) | aktywne alarmy AlarmLow w ALARM | zgodne — alarmy są efektem ubocznym auto-scaling po load teście |

---

## Drift / niespójności architektury

| Obszar | Typ driftu | Źródło | Opis |
|--------|-----------|--------|------|
| preprod-api execution role IAM | IaC vs runtime | live AWS (AccessDeniedException) | Rola `maspex-preprod-api-execution` nie ma `secretsmanager:GetSecretValue` na `maspex/preprod/api-*`. Możliwy brak modułu IAM w Terraform lub secret utworzony po deploymencie roli. |
| preprod-api desired_count | IaC vs runtime | commit 743d43e vs describe-services | IaC commit mówi "scale to 1", runtime: desired:3. Możliwy drift Terraform state vs kod. |
| preprod-api image tag | IaC vs runtime | task-def :1 | Obraz `coreapp-uat-303` w środowisku preprod — tag UAT użyty w preprod (celowe lub pomyłka). |

---

## Pewność ustaleń

| Obszar | Pewność | Evidence | Uwagi |
|--------|---------|----------|-------|
| Account ID, region, profil | wysoka | `sts get-caller-identity` | |
| ECS UAT — serwisy i taski | wysoka | `describe-services` | |
| ECS preprod — api down + przyczyna | wysoka | `describe-services` + `describe-tasks` | przyczyna: AccessDeniedException na secret |
| Bot target health | wysoka | `describe-target-health` | 1 unhealthy, 1 initial — cykl zastępowania |
| CloudFront distributions | wysoka | `list-distributions` | przypisanie prod/preprod wymaga potwierdzenia |
| Redis endpointy | wysoka (UAT), średnia (preprod) | `describe-cache-clusters --show-cache-node-info` | preprod endpoint nie pobrany |
| Terraform state backend | wysoka | `backend.hcl` z repozytorium | |
| IaC (envs/prod, envs/shared) | średnia | pliki .tf w repo — nieprzeczytane szczegółowo | live stan nieweryfikowany |
| Secrets Manager pokrycie | niska | tylko 1 secret widoczny dla makolab-ci | secret preprod/api istnieje (AccessDeniedException potwierdza) |
| CloudWatch alarms jako health | wysoka | alarmy zweryfikowane przez target-health (2026-05-05) | AlarmLow = auto-scaling artefakt stale; bot alarm aktualny i persistentny (12 dni) |
| Bot persistent health issue | wysoka | describe-target-health 2026-05-05 | NIE deployment cycle; eskalacja do WYSOKI |
| ACM FAILED twojkapsel-admin | wysoka | list-certificates eu-west-1 + us-east-1 (2026-05-05) | eskalacja z PENDING_VALIDATION → FAILED; wymaga re-request |
| WAF brak (REGIONAL) | wysoka | wafv2 list-web-acls --scope REGIONAL (2026-05-05) | potwierdzone GAP |
| contest-service | niska | log groups bez ECS service | relikt, feature flag lub niedokończona migracja |
| Tagging | nieustalone | resourcegroupstaggingapi nie uruchomiono | wymaga osobnego skanu |
| WAF CloudFront (CLOUDFRONT scope) | nieustalone | list-web-acls --scope CLOUDFRONT nie wykonano | do weryfikacji |
| Prod environment | nieustalone | live scan nie wykonano | |

---

## Dostęp diagnostyczny

```bash
# Tożsamość
aws sts get-caller-identity --profile maspex-cli

# ECS UAT — stan serwisów
aws ecs describe-services \
  --cluster maspex-uat \
  --services maspex-api maspex-bot maspex-admin-panel \
  --profile maspex-cli --region eu-west-1 \
  --query 'services[*].{name:serviceName,desired:desiredCount,running:runningCount}'

# Diagnoza preprod-api — dlaczego 0/3
aws ecs list-tasks \
  --cluster maspex-preprod \
  --service-name maspex-preprod-api \
  --desired-status STOPPED \
  --profile maspex-cli --region eu-west-1

# Opis zatrzymanego taska (podmień <TASK_ARN>)
aws ecs describe-tasks \
  --cluster maspex-preprod \
  --tasks <TASK_ARN> \
  --profile maspex-cli --region eu-west-1 \
  --query 'tasks[0].{status:lastStatus,stop:stoppedReason,containers:containers[*].{name:name,reason:reason,exit:exitCode}}'

# Naprawa: sprawdź IAM policy execution role preprod-api
aws iam list-attached-role-policies \
  --role-name maspex-preprod-api-execution \
  --profile maspex-cli

# Bot target health (zweryfikuj alarm)
aws elbv2 describe-target-groups \
  --profile maspex-cli --region eu-west-1 \
  --query 'TargetGroups[?contains(TargetGroupName,`uat`)&&contains(TargetGroupName,`bot`)].TargetGroupArn' \
  --output text | \
  xargs -I{} aws elbv2 describe-target-health --target-group-arn {} \
  --profile maspex-cli --region eu-west-1

# Alarmy w ALARM
aws cloudwatch describe-alarms \
  --profile maspex-cli --region eu-west-1 \
  --query 'MetricAlarms[?StateValue==`ALARM`].{name:AlarmName,metric:MetricName,reason:StateReason}'

# Sekrety (bez wartości)
aws secretsmanager list-secrets \
  --profile maspex-cli --region eu-west-1 \
  --query 'SecretList[*].{name:Name,description:Description}'

# Tagging coverage (brakujący krok w bieżącym skanie)
aws resourcegroupstaggingapi get-resources \
  --profile maspex-cli --region eu-west-1 \
  --query 'ResourceTagMappingList[?Tags[?Key==`Project`]==`[]`].ResourceARN'

# OPCJONALNIE — tylko po świadomej decyzji operatora.
# Nie jest częścią automatycznego cloud-detective read-only scan.
# cd ~/projekty/mako/aws-projects/infra-maspex/terraform/envs/preprod
# terraform init -backend-config=backend.hcl
# terraform plan -refresh=false
```

---

## Aktualizacja dokumentacji po zmianach IaC

Ten context jest snapshotem na 2026-05-01. Po każdym `terraform apply` należy zaktualizować.

```bash
# po terraform apply:
# uruchom ponownie cloud-detective przez plik invocation:
# @50-patterns/prompts/invocations/cloud-detective-maspex.md
```

---

## Źródła użyte

| Źródło | Zakres | Status |
|--------|--------|--------|
| live AWS | ecs, elbv2, cloudwatch, acm (eu-west-1+us-east-1), secretsmanager, sts, wafv2, logs | sprawdzone (2026-05-05) |
| repo lokalne | `~/projekty/mako/aws-projects/infra-maspex/` — git log | częściowe |
| IaC | brak nowych commitów od 2026-05-01 | częściowe — bez zmian |
| CFN stacks | nie dotyczy — projekt używa Terraform | — |
| vault historyczny | [[finops-as-is-estimate]], [[finops-uat-preprod-cost-estimate-2026-04]], [[cloudfront-audit-2026-04-26]] | zlinkowane, nie duplikowane |
| extra_regions | us-east-1 — ACM only | sprawdzone (2026-05-05) |

## Fakty live vs historia vault

| Informacja | Status | Źródło | Uwagi |
|------------|--------|--------|-------|
| ECS UAT healthy (9/9, 1/1, 1/1) | live | live AWS 2026-05-05 | bez zmian od 2026-05-01 |
| ECS preprod-api DOWN (0/3) | live | live AWS 2026-05-05 | trwa od 2026-05-01; ten sam IAM error potwierdzony 2026-05-05 10:00 |
| Bot target unhealthy — eskalacja do WYSOKI | live | live AWS 2026-05-05 describe-target-health | alarm aktywny od 2026-04-23 (12 dni); NIE deployment cycle |
| ACM twojkapsel-admin.makolab.pro FAILED | live | live AWS 2026-05-05 | eskalacja z PENDING_VALIDATION (2026-05-01) → FAILED; wymaga re-request |
| WAF brak (REGIONAL) | live | live AWS 2026-05-05 wafv2 list-web-acls | poprzednio niezweryfikowane; teraz potwierdzone GAP |
| Log groups — brak /maspex/preprod/api | live | live AWS 2026-05-05 | poprzednio niezweryfikowane; potwierdzone brak — API nigdy nie startowało |
| Brak nowych commitów od 2026-05-01 | live | git log 2026-05-05 | IaC bez zmian od ostatniego skanu |
| Account ID 969209893152 | live | sts get-caller-identity | bez zmian |
| Finops estimates | historyczna | vault — finops-as-is-estimate | nie weryfikowane live |
| CloudFront audit | historyczna | vault — cloudfront-audit-2026-04-26 | |

---

## Powiązane

- [[load-test-analysis-2026-04-28-1730-cest]]
- [[load-test-analysis-2026-04-29-1300-cest]]
- [[cloudfront-audit-2026-04-26]]
- [[troubleshooting]]
- [[finops-as-is-estimate]]
- [[finops-uat-preprod-cost-estimate-2026-04]]
- [[maspex]] (`_chatgpt/context-packs/maspex.md`)
- [[maspex-load-testing]] (`_chatgpt/context-packs/maspex-load-testing.md`)
- [[now]]
