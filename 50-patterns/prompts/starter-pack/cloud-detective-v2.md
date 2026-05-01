---
title: Bez nazwy
domain: client-work
use_case:
llm_target: any
aws_profile:
repozytorium: ~/projekty/mako/aws-projects/CHANGE_ME
region: eu-central-1
environment: dev
tags:
  - prompt
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
    

# Zasady nadrzędne

Zanim wykonasz jakiekolwiek działanie:

1. Przeczytaj `_system/AGENT_BOOTSTRAP.md`
    
2. Przeczytaj `_system/AGENTS.md`
    
3. Przeczytaj `_system/DOMAIN_ISOLATION_CONTRACT.md`
    
4. Przeczytaj `_system/LLM_CONTEXT_BOUNDARY_CONTRACT.md`
    
5. Przeczytaj `_system/AI_COST_AWARE_AGENT_CONTRACT.md`
    

Działaj wyłącznie w jednej domenie: `client-work`.

Wszystko zapisuj po polsku. Kod, komendy, ścieżki, nazwy zasobów AWS, ID i output CLI zostają po angielsku.

# Projekt

Nazwa projektu: `maspex`  
Klient / domena: `client-work`  
AWS profile: `maspex-cli`  
Account ID: `<UZUPEŁNIJ albo wykryj przez sts get-caller-identity>`  
Regiony do sprawdzenia: `eu-west-1`  
Region dodatkowy dla CloudFront/ACM: `us-east-1`  
Repozytorium lokalne: `~/projekty/mako/aws-projects/infra-maspex/`  
IaC: `<Terraform / CloudFormation / mixed / unknown>`

# Tryb pracy

Działaj jako cloud-detective w trybie read-only.

Dozwolone:

- czytanie repozytorium
    
- analiza Terraform / CloudFormation / Helm / CI/CD
    
- analiza backendów Terraform i plików `.tf`
    
- komendy AWS read-only typu:
    
    - sts get-caller-identity
        
    - ec2 describe-*
        
    - ecs list-* / describe-*
        
    - elbv2 describe-*
        
    - rds describe-*
        
    - docdb describe-*
        
    - elasticache describe-*
        
    - secretsmanager list-secrets / describe-secret
        
    - cloudformation describe-* / list-*
        
    - cloudwatch describe-* / list-*
        
    - logs describe-log-groups
        
    - servicediscovery list-* / get-*
        
    - sqs list-queues / get-queue-attributes
        
    - events list-rules / list-targets-by-rule
        
    - acm list-certificates / describe-certificate
        
    - cloudfront list-distributions / get-distribution-config
        

Warunkowo dozwolone:

- `terraform init -backend-config=backend.hcl` tylko jeśli potrzebne do lokalnej analizy i nie powoduje zmian w repo
    
- `terraform plan -refresh=false` tylko jako opcjonalny krok diagnostyczny po świadomej decyzji operatora
    
- NIE uruchamiaj `terraform plan` jako część automatycznego cloud-detective scan bez wyraźnej potrzeby
    

Zakazane:

- żadnych operacji write
    
- żadnego terraform apply
    
- żadnego terraform destroy
    
- żadnego aws delete/update/create/put/modify
    
- żadnego force push
    
- żadnego generowania sekretów do outputu
    
- nie wypisuj wartości sekretów z Secrets Manager
    
- nie zapisuj wartości sekretów do vault
    
- nie traktuj contextu jako źródła prawdy
    

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
        
4. Rozdziel:
    
    - fakty potwierdzone live AWS
        
    - fakty potwierdzone z IaC
        
    - hipotezy
        
    - braki / nieustalone
        
5. Zapisz wynik jako context projektu w vault.
    

# Gdzie zapisać

Najpierw sprawdź, czy istnieje notatka projektu w:

`20-projects/clients/mako/maspex/`

Jeśli istnieje — zaktualizuj ją.

Jeśli nie istnieje — utwórz:

`20-projects/clients/mako/maspex/maspex-context.md`

Nie twórz duplikatów.

Dodatkowo zaktualizuj:

`02-active-context/now.md`

krótkim wpisem:

- jaki projekt przeskanowano
    
- gdzie zapisano context
    
- co wymaga dalszej pracy
    

# Frontmatter

Plik musi zaczynać się od frontmatter.

Użyj struktury podobnej do `templates/frontmatter/client_context.md`.

Minimalny wymagany frontmatter:

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
tags:
  - aws
  - terraform
  - ecs
  - fargate
  - mako
  - maspex
---
```

Jeśli `templates/frontmatter/client_context.md` ma dodatkowe pola, zachowaj jego styl i dopasuj pola do projektu.

# Format contextu

Użyj tej struktury:

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
**Projekt:** <opis jednym zdaniem>
**OrgAccountID:** <jeśli znane>
**Account ID:** <account id>
**Role:** <rola jeśli znana>
**AWS profile:** `<profile>`
**IAM principal:** `<nazwa principal, bez nadmiernych szczegółów jeśli nie są potrzebne>`
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
| dev | | | | | |
| qa | | | | | |
| uat | | | | | |
| preprod | | | | | |
| prod | | | | | |

State bucket: `<jeśli Terraform>`
State key: `<jeśli Terraform>`
Lock table: `<jeśli Terraform>`

---

## Architektura

```text
<diagram tekstowy runtime>
```

Jeśli przypisanie domeny / CloudFront / środowiska nie jest pewne, oznacz to wprost jako:
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

## Scheduler / automatyzacje

| Automatyzacja | Harmonogram | Zakres | Uwagi |
|--------------|-------------|--------|-------|

---

## ECS / runtime config

| Parametr | Wartość |
|----------|---------|

---

## Observability

| Element | Status | Uwagi |
|---------|--------|-------|

Rozdziel:
- aktualny runtime health
- stale / historyczne alarmy CloudWatch
- braki obserwowalności

Nie pisz “wszystko healthy”, jeśli jednocześnie istnieją alarmy w ALARM bez wyjaśnienia kontekstu czasowego.

---

## Znane problemy / dług techniczny

| Problem | Priorytet | Evidence | Opis |
|---------|-----------|----------|------|

Priorytety:
- WYSOKI
- ŚREDNI
- NISKI
- INFO

---

## Różnice IaC vs Runtime

| Obszar | IaC | Runtime AWS | Ocena |
|--------|-----|-------------|-------|

Ocena:
- zgodne
- rozbieżność
- nieustalone
- wymaga potwierdzenia

---

## Pewność ustaleń

| Obszar | Pewność | Evidence | Uwagi |
|--------|---------|----------|-------|

Pewność:
- wysoka — potwierdzone live AWS
- średnia — potwierdzone częściowo / z IaC
- niska — hipoteza / wymaga dalszego sprawdzenia

---

## Dostęp diagnostyczny

Dodaj gotowe komendy read-only / diagnostyczne, np.:
- `describe-services`
- `describe-tasks`
- `describe-target-health`
- `describe-alarms`
- `logs describe-log-groups`

Nie dodawaj komend write.

Jeśli dodajesz `terraform plan`, oznacz go jako opcjonalny i nieautomatyczny:

```bash
# OPCJONALNIE — tylko po świadomej decyzji operatora.
# Nie jest częścią automatycznego cloud-detective read-only scan.
terraform plan -refresh=false
```

---

## Aktualizacja dokumentacji po zmianach IaC

Ten context powinien być aktualizowany po zmianach infrastruktury.

Docelowy wzorzec:
- po każdym świadomym `terraform apply` operator uruchamia osobny krok dokumentacyjny
- krok dokumentacyjny robi read-only scan runtime
- aktualizuje `20-projects/clients/maspex/maspex-context.md`
- aktualizuje `02-active-context/now.md`

Nie implementuj automatycznego hooka na `terraform apply` bez osobnej decyzji.

Proponowany przyszły workflow:

```bash
terraform apply
# potem osobno:
cloud-detective context refresh --project maspex --profile maspex-cli --region eu-west-1
```

Jeśli repo ma Makefile / pipeline, zaproponuj tylko bezpieczną koncepcję targetu, bez wdrażania:

```makefile
docs-refresh:
	# read-only scan + update vault context
```

---

## Powiązane

- [[...]]
````

# Wymagania jakościowe

- Oddziel fakty od hipotez.
    
- Nie zgaduj brakujących danych.
    
- Jeśli czegoś nie da się ustalić read-only, wpisz `nieustalone`.
    
- Jeśli runtime różni się od IaC, oznacz to wyraźnie.
    
- Jeśli przypisanie zasobu do środowiska jest niepewne, wpisz `wymaga potwierdzenia`.
    
- Nie wypisuj sekretów.
    
- Nie wykonuj żadnych zmian w AWS.
    
- Nie generuj długiego eseju — context ma być operacyjny.
    
- Nie traktuj CloudWatch alarmów jako aktualnego runtime health bez sprawdzenia target/task health.
    
- Nie eksportuj pełnych identyfikatorów IAM principal do context packów dla zewnętrznych LLM, jeśli nie są potrzebne.
    
- Context jest mapą wejścia do projektu, nie źródłem prawdy.
    

# Wynik końcowy

Na końcu odpowiedzi podaj tylko:

1. gdzie zapisano context
    
2. jakie źródła sprawdzono
    
3. top 5 najważniejszych ustaleń
    
4. top 5 braków / rzeczy do dalszej weryfikacji
    
5. czy wykryto rozbieżności IaC vs Runtime
    
6. czy dokument może być użyty jako aktualny snapshot runtime, czy wymaga dalszej weryfikacji