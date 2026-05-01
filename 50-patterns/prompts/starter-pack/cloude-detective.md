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
Ważne, żeby plik .md zaczymał się od sekcji frontmatter o podobnym wyglądzie jak w templates/frontmatter/client_context.md
Context ma służyć jako szybki punkt wejścia dla Claude / ChatGPT / Codex przed pracą nad projektem.

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
Repozytorium lokalne: `~/projekty/mako/aws-projects/infra-maspex/` 
IaC: `<Terraform / CloudFormation / mixed / unknown>`

# Tryb pracy

Działaj jako cloud-detective w trybie read-only.

Dozwolone:

- czytanie repozytorium
    
- analiza Terraform / CloudFormation / Helm / CI/CD
    
- komendy AWS read-only typu:
    
    - sts get-caller-identity
        
    - ec2 describe-*
        
    - ecs list-* / describe-*
        
    - elbv2 describe-*
        
    - rds describe-*
        
    - docdb describe-*
        
    - secretsmanager list-secrets / describe-secret
        
    - cloudformation describe-* / list-*
        
    - cloudwatch describe-* / list-*
        
    - logs describe-log-groups
        
    - servicediscovery list-* / get-*
        
    - sqs list-queues / get-queue-attributes
        
    - events list-rules / list-targets-by-rule
        
    - acm list-certificates / describe-certificate
        
    - cloudfront list-distributions / get-distribution-config
        

Zakazane:

- żadnych operacji write
    
- żadnego terraform apply
    
- żadnego terraform destroy
    
- żadnego aws delete/update/create/put/modify
    
- żadnego force push
    
- żadnego generowania sekretów do outputu
    
- nie wypisuj wartości sekretów z Secrets Manager
    

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
        
4. Zapisz wynik jako context projektu w vault.
    

# Gdzie zapisać

Najpierw sprawdź, czy istnieje notatka projektu w:

`20-projects/clients/maspex/`

Jeśli istnieje — zaktualizuj ją.

Jeśli nie istnieje — utwórz:

`20-projects/clients/maspex/maspex-context.md`

Nie twórz duplikatów.

Dodatkowo zaktualizuj:

`02-active-context/now.md`

krótkim wpisem:

- jaki projekt przeskanowano
    
- gdzie zapisano context
    
- co wymaga dalszej pracy
    

# Format contextu

Użyj tej struktury:

````md
# <PROJEKT> — <pełna nazwa>

#aws #terraform #ecs #fargate #mako #<projekt>

**Data:** <YYYY-MM-DD>
**Projekt:** <opis jednym zdaniem>
**OrgAccountID:** <jeśli znane>
**Account ID:** <account id>
**Role:** <rola jeśli znana>
**AWS profile:** `<profile>`
**Region główny:** `<region>`

---

## Repozytorium kodu

- lokalna ścieżka: `<path>`
- remote: `<remote>`
- aktywny branch: `<branch>`
- IaC: **<Terraform / CloudFormation / mixed>**

---

## Środowiska

| Env | Region | Account ID | Status | VPC CIDR |
|-----|--------|------------|--------|----------|
| dev | | | | |
| qa | | | | |
| uat | | | | |
| prod | | | | |

State bucket: `<jeśli Terraform>`
State key: `<jeśli Terraform>`

---

## Architektura

```text
<diagram tekstowy runtime>
````

---

## Mikroserwisy / komponenty

|Serwis|Port|Ingress|Service Discovery|ECS Exec|Status|
|---|---|---|---|---|---|

---

## Zasoby kluczowe

|Zasób|Identyfikator|
|---|---|

---

## Secrets Manager

Nie wypisuj wartości sekretów.

|Secret|Przeznaczenie / zawartość logiczna|
|---|---|

---

## Scheduler / automatyzacje

|Automatyzacja|Harmonogram|Zakres|Uwagi|
|---|---|---|---|

---

## ECS / runtime config

|Parametr|Wartość|
|---|---|

---

## Observability

|Element|Status|Uwagi|
|---|---|---|

---

## Znane problemy / dług techniczny

|Problem|Priorytet|Evidence|Opis|
|---|---|---|---|

---

## Różnice IaC vs Runtime

|Obszar|IaC|Runtime AWS|Ocena|
|---|---|---|---|

---

## Dostęp diagnostyczny

Dodaj gotowe komendy read-only / diagnostyczne, np. ECS Exec, describe-services, describe-target-health.

Nie dodawaj komend write.

---

## Powiązane

- [[...]]
    

```

# Wymagania jakościowe

- Oddziel fakty od hipotez.
- Nie zgaduj brakujących danych.
- Jeśli czegoś nie da się ustalić read-only, wpisz `nieustalone`.
- Jeśli runtime różni się od IaC, oznacz to wyraźnie.
- Nie wypisuj sekretów.
- Nie wykonuj żadnych zmian w AWS.
- Nie generuj długiego eseju — context ma być operacyjny.

# Wynik końcowy

Na końcu odpowiedzi podaj tylko:

1. gdzie zapisano context
2. jakie źródła sprawdzono
3. top 5 najważniejszych ustaleń
4. top 5 braków / rzeczy do dalszej weryfikacji
```