---
title: cloud-detective-v2
domain: client-work
use_case: cloud-detective-prompt
llm_target: any
tags:
  - prompt
  - cloud-detective
  - template
created: 2026-05-01
updated: 2026-05-01
---

# Cel

Utwórz lub zaktualizuj context projektu w vault w stylu operator-grade, podobnym do istniejącego kontekstu PBMS.

Plik `.md` MUSI zaczynać się od sekcji frontmatter zgodnej stylistycznie z `templates/frontmatter/client_context.md`.

Context ma służyć jako szybki punkt wejścia dla Claude / ChatGPT / Codex przed pracą nad projektem.

Ten dokument jest **snapshotem runtime / contextem wejściowym**, a nie source of truth.

Source of truth:

- AWS live
- IaC w repozytorium
- Terraform state / CloudFormation stacki

---

# Zasady nadrzędne

Zanim wykonasz jakiekolwiek działanie:

1. Przeczytaj `_system/AGENT_BOOTSTRAP.md`
2. Przeczytaj `_system/AGENTS.md`
3. Przeczytaj `_system/DOMAIN_ISOLATION_CONTRACT.md`
4. Przeczytaj `_system/LLM_CONTEXT_BOUNDARY_CONTRACT.md`
5. Przeczytaj `_system/AI_COST_AWARE_AGENT_CONTRACT.md`

Działaj wyłącznie w jednej domenie: `client-work`.

Wszystko zapisuj po polsku. Kod, komendy, ścieżki, nazwy zasobów AWS, ID i output CLI zostają po angielsku.

## Frontmatter — zasada zastępowania

Jeśli plik docelowy zawiera frontmatter szablonu promptu (np. `title: Bez nazwy`, `use_case`, `llm_target`):

- **ZASTĄP go docelowym frontmatter projektu** zgodnym z `templates/frontmatter/client_context.md`
- **NIE łącz** struktury prompt + context w jednym frontmatter
- wynikowy plik ma mieć tylko jeden, spójny frontmatter projektu

## Context ≠ source of truth

Ten dokument:

- NIE jest źródłem prawdy
- jest snapshotem runtime na konkretną datę
- służy jako punkt wejścia do projektu dla agentów LLM

Source of truth zawsze:

- AWS live
- IaC w repozytorium
- Terraform state / CloudFormation stacki

---

# Projekt

Nazwa projektu: `maspex`
Klient / domena: `client-work`
AWS profile: `maspex-cli`
Account ID: `<UZUPEŁNIJ albo wykryj przez sts get-caller-identity>`
Regiony do sprawdzenia: `eu-west-1`
Region dodatkowy dla CloudFront/ACM: `us-east-1`
Repozytorium lokalne: `~/projekty/mako/aws-projects/infra-maspex/`
IaC: `<Terraform / CloudFormation / mixed / unknown>`

---

# Tryb pracy

Działaj jako cloud-detective w trybie read-only.

## Dozwolone

- czytanie repozytorium
- analiza Terraform / CloudFormation / Helm / CI/CD
- analiza backendów Terraform i plików `.tf`
- komendy AWS read-only:
  - `sts get-caller-identity`
  - `ec2 describe-*`
  - `ecs list-* / describe-*`
  - `elbv2 describe-*`
  - `rds describe-*`
  - `docdb describe-*`
  - `elasticache describe-*`
  - `secretsmanager list-secrets / describe-secret`
  - `cloudformation describe-* / list-*`
  - `cloudwatch describe-* / list-*`
  - `logs describe-log-groups`
  - `servicediscovery list-* / get-*`
  - `sqs list-queues / get-queue-attributes`
  - `events list-rules / list-targets-by-rule`
  - `acm list-certificates / describe-certificate`
  - `cloudfront list-distributions / get-distribution-config`
  - `resourcegroupstaggingapi get-resources` (do audytu tagów)

## Warunkowo dozwolone

- `terraform init -backend-config=backend.hcl` — tylko jeśli potrzebne do lokalnej analizy i nie powoduje zmian w repo
- `terraform plan -refresh=false` — tylko jako opcjonalny krok diagnostyczny po świadomej decyzji operatora; NIE uruchamiaj automatycznie jako część scanu

## Zakazane

- żadnych operacji write w AWS
- żadnego `terraform apply`
- żadnego `terraform destroy`
- żadnego `aws delete/update/create/put/modify`
- żadnego force push
- żadnego generowania sekretów do outputu
- nie wypisuj wartości sekretów z Secrets Manager
- nie zapisuj wartości sekretów do vault
- nie traktuj contextu jako źródła prawdy
- **nie usuwaj istniejących plików bez wyraźnej zgody użytkownika**
- **jeśli plik jest w złej lokalizacji: przenieś go, nie kasuj** — chyba że został utworzony w tej samej sesji i jest ewidentnie błędny
- **nie nadpisuj istniejących plików bez zachowania ich struktury** — merge zamiast replace
- **nigdy nie łącz `terraform apply` z generowaniem dokumentacji w jednym kroku** — apply = operacja write, context = read-only snapshot; to muszą być dwa osobne kroki

---

# Zadanie

1. Ustal rzeczywisty stan projektu z repozytorium i live AWS.

2. Porównaj IaC z runtime AWS.

3. Wykryj:
   - konta i regiony
   - środowiska
   - repozytoria
   - backend state
   - VPC / sieć
   - ECS / Fargate / usługi
   - ALB / Target Groups / CloudFront
   - RDS / DocumentDB / Redis / SQS / EventBridge
   - Cloud Map / Service Discovery
   - Secrets Manager — tylko nazwy i przeznaczenie, bez wartości
   - CloudWatch logs / dashboardy / alarmy
   - certyfikaty ACM
   - scheduler / automatyzacje FinOps
   - znane problemy i dług techniczny
   - **tagi AWS** (`Project`, `Environment`, `Owner`) — sprawdź pokrycie; brak tagów = problem governance + FinOps

4. Rozdziel:
   - fakty potwierdzone live AWS
   - fakty potwierdzone z IaC
   - hipotezy
   - braki / nieustalone

5. Wyznacz poziom pewności snapshotu:
   - **wysoka** — większość zasobów potwierdzona live AWS
   - **częściowa** — mix IaC + runtime, niektóre env nieweryfikowane
   - **niska** — brak danych / głównie hipotezy

6. Zapisz wynik jako context projektu w vault.

---

# Gdzie zapisać

Najpierw sprawdź, czy istnieje notatka projektu w:

`20-projects/clients/mako/maspex/`

Jeśli istnieje — zaktualizuj ją (merge, nie replace).

Jeśli nie istnieje — utwórz:

`20-projects/clients/mako/maspex/maspex-context.md`

Nie twórz duplikatów.

Dodatkowo zaktualizuj:

`02-active-context/now.md`

krótkim wpisem:

- jaki projekt przeskanowano
- gdzie zapisano context
- co wymaga dalszej pracy

---

# Frontmatter

Plik musi zaczynać się od frontmatter projektu — nie prompt template.

Minimalna wymagana struktura:

```yaml
---
title: maspex-context
client: maspex
project: maspex
domain: client-work
document_type: runtime-context
context_type: cloud-detective-snapshot
classification: internal
source_of_truth: false
runtime_snapshot: true
aws_profile: maspex-cli
account_id: "<wykryty account id>"
regions:
  - eu-west-1
  - us-east-1
iac: terraform
repository: "~/projekty/mako/aws-projects/infra-maspex/"
created: "<YYYY-MM-DD>"
updated: "<YYYY-MM-DD>"
last_verified: "<YYYY-MM-DD>"
tags:
  - aws
  - terraform
  - ecs
  - fargate
  - mako
  - maspex
---
```

`last_verified` = data snapshotu runtime; musi być zgodna z polem `**Data:**` w dokumencie.

Jeśli `templates/frontmatter/client_context.md` ma dodatkowe pola, zachowaj jego styl i dopasuj do projektu.

---

# Format contextu

````md
---
<frontmatter>
---

# <PROJEKT> — <pełna nazwa>

#aws #terraform #ecs #fargate #mako #<projekt>

**Data:** <YYYY-MM-DD>
**Typ dokumentu:** snapshot runtime / context wejściowy
**Source of truth:** AWS live + IaC + Terraform state / CloudFormation stacki
**Tryb skanowania:** read-only
**Poziom pewności snapshotu:** wysoka / częściowa / niska
**Projekt:** <opis jednym zdaniem>
**OrgAccountID:** <jeśli znane>
**Account ID:** <account id>
**Role:** <rola jeśli znana>
**AWS profile:** `<profile>`
**IAM principal:** `<nazwa logiczna, np. makolab-ci>` *(nie wypisuj AccessKeyId, AIDA..., pełnych ARN jeśli nie są potrzebne)*
**Region główny:** `<region>`

---

## Repozytorium kodu

- lokalna ścieżka: `<path>`
- remote: `<remote>`
- aktywny branch: `<branch>`
- IaC: **<Terraform / CloudFormation / mixed>**

---

## Środowiska

| Env | Region | Account ID | Status | VPC CIDR | Pewność |
|-----|--------|------------|--------|----------|---------|

State bucket: `<jeśli Terraform>`
State key: `<jeśli Terraform>`
Lock table: `<jeśli Terraform>`

---

## Architektura

```text
<diagram tekstowy runtime>
```

Jeśli przypisanie domeny / CloudFront / środowiska nie jest pewne, oznacz wprost jako:
`wymaga potwierdzenia`.

---

## Mikroserwisy / komponenty

| Serwis | Cluster | Port | Ingress | Service Discovery | ECS Exec | Desired | Running | Status |
|--------|---------|------|---------|-------------------|----------|---------|---------|--------|

---

## Zasoby kluczowe

| Zasób | Identyfikator | Źródło | Pewność |
|-------|---------------|--------|---------|

Źródło:
- `live AWS`
- `IaC`
- `Terraform state`
- `hipoteza`

Pewność:
- `wysoka` — potwierdzone live AWS
- `średnia` — potwierdzone częściowo / z IaC
- `niska` — hipoteza / wymaga dalszego sprawdzenia

---

## Secrets Manager

Nie wypisuj wartości sekretów.

| Secret | Przeznaczenie / zawartość logiczna | Źródło |
|--------|------------------------------------|--------|

---

## ACM Certificates

| Domena | Region | Status | Uwagi |
|--------|--------|--------|-------|

---

## Tagging (governance / FinOps)

Sprawdź pokrycie tagów `Project`, `Environment`, `Owner` dla kluczowych zasobów.

| Zasób | Project | Environment | Owner | Ocena |
|-------|---------|-------------|-------|-------|

Brak tagów = problem governance + problem FinOps + brak cost attribution + potencjalne naruszenie standardu organizacyjnego.

---

## Scheduler / automatyzacje

| Automatyzacja | Harmonogram | Zakres | Uwagi |
|--------------|-------------|--------|-------|

---

## ECS / runtime config

| Parametr | Wartość |
|----------|---------|

---

## Observability

**Poziom pewności tej sekcji:** CloudWatch alarms NIE są równoznaczne z aktualnym stanem runtime. Zawsze weryfikuj przez `describe-target-health` i `describe-tasks`. Alarm starszy niż aktualny runtime oznacz jako `historyczny / stale`.

**Runtime health (live, <YYYY-MM-DD>):**

| Element | Status | Uwagi |
|---------|--------|-------|

**CloudWatch alarms:**

| Alarm | Stan | Metric | Kontekst / czy aktualny? |
|-------|------|--------|--------------------------|

Rozdziel:
- aktualny runtime health (ECS tasks, ALB target health)
- stale / historyczne alarmy CloudWatch
- braki obserwowalności

**Log groups:**

| Log group | Retencja | Uwagi |
|-----------|----------|-------|

---

## Znane problemy / dług techniczny

*Krytyczne problemy (service down, brak certyfikatu, brak ingress, brak backendu, brak tasków) oznacz jako 🔥 CRITICAL i umieść na początku.*

| Problem | Priorytet | Evidence | Opis |
|---------|-----------|----------|------|

Priorytety:
- 🔥 CRITICAL
- WYSOKI
- ŚREDNI
- NISKI
- INFO

---

## Różnice IaC vs Runtime

| Obszar | IaC | Runtime AWS | Ocena |
|--------|-----|-------------|-------|

Ocena:
- `zgodne`
- `rozbieżność`
- `nieustalone`
- `wymaga potwierdzenia`

---

## Pewność ustaleń

| Obszar | Pewność | Evidence | Uwagi |
|--------|---------|----------|-------|

Pewność:
- `wysoka` — potwierdzone live AWS
- `średnia` — potwierdzone częściowo / z IaC
- `niska` — hipoteza / wymaga dalszego sprawdzenia

---

## Dostęp diagnostyczny

Komendy read-only / diagnostyczne:

```bash
# ECS task health
aws ecs describe-services --cluster <cluster> --services <svc> \
  --profile <profile> --region eu-west-1

# Zatrzymane taski (diagnoza crashu)
aws ecs list-tasks --cluster <cluster> --desired-status STOPPED \
  --service-name <svc> --profile <profile> --region eu-west-1

# ALB target health
aws elbv2 describe-target-health --target-group-arn <arn> \
  --profile <profile> --region eu-west-1

# CloudWatch alarms stan
aws cloudwatch describe-alarms --profile <profile> --region eu-west-1 \
  --query 'MetricAlarms[?StateValue==`ALARM`].{name:AlarmName,metric:MetricName,reason:StateReason}'
```

Jeśli używasz `terraform plan`, oznacz go jako opcjonalny i nieautomatyczny:

```bash
# OPCJONALNE — tylko po świadomej decyzji operatora.
# NIE jest częścią automatycznego cloud-detective read-only scan.
terraform plan -refresh=false
```

Nie dodawaj komend write.

---

## Aktualizacja dokumentacji po zmianach IaC

Ten context jest snapshotem. Po każdym `terraform apply` aktualizuj osobno.

**Nigdy nie łącz `terraform apply` z generowaniem dokumentacji** — to dwa osobne kroki.

Rekomendowany workflow:

```bash
terraform apply

# osobno, po apply:
cloud-detective context refresh --project maspex --profile maspex-cli --region eu-west-1
```

Proponowany przyszły target Makefile (bez wdrażania):

```makefile
docs-refresh:
    # read-only scan runtime + update vault context
```

---

## Powiązane

- [[...]]
````

---

# Wymagania jakościowe

- Oddziel fakty od hipotez.
- Nie zgaduj brakujących danych.
- Jeśli czegoś nie da się ustalić read-only, wpisz `nieustalone`.
- Jeśli runtime różni się od IaC, oznacz to wyraźnie.
- Jeśli przypisanie zasobu do środowiska jest niepewne, wpisz `wymaga potwierdzenia`.
- Nie wypisuj sekretów ani wartości sekretów.
- Nie wykonuj żadnych zmian w AWS.
- Nie generuj długiego eseju — context ma być operacyjny.
- **CloudWatch alarms NIE są równoznaczne z aktualnym runtime health** — sprawdź target health i task health; alarmy starsze niż runtime oznaczaj jako `historyczny / stale`.
- **Brak tagów (Project/Environment/Owner) = problem governance + problem FinOps** — wpisz do sekcji "Znane problemy".
- **IAM principal**: nie wypisuj AccessKeyId, AIDA..., pełnych ARN jeśli nie są potrzebne — używaj tylko nazwy logicznej.
- **Nie łącz `terraform apply` z dokumentowaniem** — to muszą być dwa osobne kroki.
- Context jest mapą wejścia do projektu, nie źródłem prawdy.
- **Nie usuwaj istniejących plików bez zgody użytkownika** — jeśli plik jest w złej lokalizacji, przenieś go; jeśli plik istnieje, zrób merge, nie replace.

---

# Wynik końcowy

Na końcu odpowiedzi podaj tylko:

1. gdzie zapisano context
2. jakie źródła sprawdzono
3. **poziom pewności snapshotu** (wysoka / częściowa / niska) z uzasadnieniem
4. **🔥 problemy krytyczne** (jeśli wykryto)
5. top 5 najważniejszych ustaleń
6. top 5 braków / rzeczy do dalszej weryfikacji
7. czy wykryto rozbieżności IaC vs Runtime
8. czy dokument może być użyty jako aktualny snapshot runtime, czy wymaga dalszej weryfikacji
