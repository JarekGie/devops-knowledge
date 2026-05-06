---
title: Bez nazwy
domain: client-work
use_case:
llm_target: any
aws_account_id:
aws_profile: maspex-cli
aws_mgm_account_id:
aws_mgm_profile:
repozytorium:
region: eu-central-1
environment: dev
tags:
  - prompt
created: 2026-05-01
updated: 2026-05-01
---
Pracujesz na projekcie Maspex jako senior DevOps/SRE.

Twoim zadaniem jest przygotować i — jeśli wszystko będzie bezpieczne i jednoznaczne — wykonać **kontrolowaną operację na UAT**:

1. **restart Redis / ElastiCache na UAT**
    
2. **wyczyszczenie cache CloudFront na UAT**
    

## Cel operacji

Chcę zrobić kontrolowany refresh warstw cache / delivery na środowisku UAT, bo po testach i zmianach chcemy wrócić do czystego stanu operacyjnego.

Zakres:

- **ElastiCache / Redis UAT**
    
- **CloudFront UAT API**
    

## Kontekst środowiska

Projekt: Maspex  
AWS profile: `maspex-cli`  
Region aplikacyjny: `eu-west-1`  
CloudFront region logiczny / API: `us-east-1`  
Konto AWS: `969209893152`

Zasoby:

- CloudFront distribution UAT API: `E3J76RNXIE2YIG`
    
- hostname: `kapsel.makotest.pl`
    
- ElastiCache cluster UAT: `maspex-uat`
    
- Redis node id najpewniej: `0001`  
    ale **najpierw potwierdź live**, nie zgaduj
    

## Ważne zasady

- najpierw **read-only precheck**
    
- niczego nie rób “w ciemno”
    
- jeśli jakikolwiek parametr nie jest jednoznaczny, najpierw go ustal
    
- jeśli restart Redis na tym konkretnym klastrze oznacza downtime, napisz to wprost
    
- nie rób żadnych zmian Terraform
    
- nie rób apply
    
- operacja ma być wykonana przez AWS CLI
    
- chcę pełen, czytelny raport z tego co sprawdziłeś i co zrobiłeś
    

## Co masz zrobić

### 1. Precheck Redis / ElastiCache

Sprawdź live:

- czy cluster `maspex-uat` istnieje
    
- jaki ma engine / version
    
- czy to single-node czy replication group
    
- jakie są cache node ids
    
- jaki jest current status
    
- czy widać maintenance / reboot constraints
    
- czy restart jest możliwy przez CLI i jak dokładnie powinien wyglądać dla tego typu zasobu
    

Użyj komend read-only typu:

- `aws elasticache describe-cache-clusters --show-cache-node-info`
    
- jeśli potrzeba: `describe-replication-groups`
    

### 2. Precheck CloudFront

Sprawdź live:

- czy distribution `E3J76RNXIE2YIG` istnieje
    
- czy jest `Deployed`
    
- jakie ma aliasy
    
- czy to na pewno UAT API distribution
    
- czy można bezpiecznie zrobić invalidation całego cache
    

### 3. Przygotuj dokładne komendy

Chcę zobaczyć:

- dokładną komendę restartu Redis
    
- dokładną komendę invalidation CloudFront
    
- jeśli restart Redis wymaga node id — pokaż konkretny node id z live
    
- jeśli lepiej użyć innej komendy niż zakładałem — uzasadnij krótko
    

### 4. Jeśli precheck jest OK — wykonaj operację

Kolejność:

1. restart Redis
    
2. invalidation CloudFront (`/*`)
    

### 5. Po wykonaniu — verification

Sprawdź i pokaż:

- status Redis po restarcie
    
- status / ID invalidation CloudFront
    
- czy distribution nadal jest healthy / deployed
    
- ewentualnie podstawowy sanity check CLI / curl, jeśli ma sens
    

## Oczekiwany wynik

Odpowiedź przygotuj dokładnie w tej strukturze:

### A. Executive Summary

- co zostało sprawdzone
    
- czy Redis restart był możliwy
    
- czy CloudFront invalidation został uruchomiony
    
- czy operacja zakończyła się powodzeniem
    

### B. Live inventory

- dokładny stan Redis / ElastiCache
    
- dokładny stan CloudFront
    
- potwierdzone identyfikatory zasobów
    

### C. Commands used

Pokaż wszystkie komendy:

- read-only precheck
    
- restart Redis
    
- CloudFront invalidation
    
- verification
    

### D. Execution result

- output / wynik operacji
    
- statusy po wykonaniu
    
- invalidation id
    
- status Redis
    

### E. Risk note

- czy restart Redis powodował chwilową przerwę
    
- czy invalidation `/*` może chwilowo zwiększyć origin traffic
    
- czy są jakieś dalsze kroki obserwacyjne po operacji
    

### F. Final verdict

Jednoznacznie:

- czy operacja została wykonana poprawnie
    
- czy środowisko jest gotowe do dalszych testów
    

## Dodatkowe wymagania

- nie zgaduj node id Redis
    
- nie zgaduj typu klastra
    
- jeśli Redis okaże się replication group zamiast prostego cache cluster, dopasuj procedurę do live stanu
    
- jeśli z jakiegoś powodu restart nie powinien być wykonany, zatrzymaj się i napisz dlaczego
    
- wszystkie decyzje opieraj na live AWS state