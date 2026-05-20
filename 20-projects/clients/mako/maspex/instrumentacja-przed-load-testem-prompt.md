---
type: prompt
topic: plan instrumentacji przed kolejnym load testem
created: 2026-05-11
---

# Prompt: Plan instrumentacji aplikacji przed kolejnym load testem

Pracujesz jako senior SRE / DevOps / observability engineer na projekcie Maspex.

Twoim zadaniem jest przygotować **praktyczny plan instrumentacji aplikacji i środowiska** przed kolejnym load testem Maspex UAT.

## Kontekst

Ostatni istotny load test pokazał:

* bardzo duży peak ruchu
* realne 5xx z targetów
* bardzo zły tail latency (p99 do kilkunastu sekund)
* brak symptomów przeciążenia Redis
* brak dawnych błędów `VOTE_CACHE_WRITETHROUGH_FAIL`
* memory retention po teście
* brak wystarczających danych do jednoznacznego rozbicia request latency na:

  * aplikację
  * DB / Supabase
  * connection pool
  * Redis
  * event loop / GC
  * inne downstreamy

## Cel

Chcę dostać **konkretny, praktyczny plan instrumentacji**, który da nam lepsze dane przed następnym load testem.

Plan ma być:

* realistyczny
* priorytetyzowany
* nastawiony na szybkie wdrożenie
* bez wielkiej przebudowy całego systemu, jeśli da się tego uniknąć

## Ważne zasady

* skup się na danych, które realnie pomogą rozstrzygnąć bottleneck
* nie proponuj 50 narzędzi naraz
* rozdziel:

  * szybkie wins
  * średni wysiłek
  * większe zmiany
* pokaż, co da największy zwrot poznawczy przed kolejnym testem
* uwzględnij zarówno aplikację, jak i AWS runtime
* jeśli coś jest warte wdrożenia tylko na czas testów, napisz to wprost

## Obszary, które chcę pokryć

### 1. Request-level visibility

Potrzebujemy wiedzieć:

* które endpointy są najwolniejsze
* jaki jest latency breakdown
* które requesty kończą się 5xx
* jaki jest rozkład p50 / p90 / p99 per route

### 2. Downstream visibility

Potrzebujemy wiedzieć:

* czy problem siedzi w DB / Supabase
* czy pool połączeń się kończy
* ile trwa każdy call downstream
* czy są timeouty / retries / queue wait

### 3. Runtime visibility

Potrzebujemy wiedzieć:

* event loop lag
* GC pressure / heap / RSS
* memory growth w czasie testu
* liczbę aktywnych połączeń / requestów / jobów

### 4. Redis visibility

Redis już nie wygląda na root cause, ale nadal chcemy wiedzieć:

* command latency
* hit / miss
* liczba połączeń po stronie klienta
* czy write-through działa poprawnie

### 5. AWS / infra visibility

Potrzebujemy wiedzieć:

* czy autoscaling reaguje wystarczająco szybko
* czy ALB access logs mogą pomóc
* czy warto włączyć dodatkowe metryki CloudFront
* czy potrzebujemy per-task visibility

## Co masz zrobić

### 1. Zaproponuj minimalny zestaw instrumentacji na następny test

To ma być "must have" przed następnym testem.

### 2. Zaproponuj warstwę aplikacyjną

Uwzględnij:

* route-level metrics
* downstream timing
* request identifiers / correlation
* błędy i timeouty
* memory / event loop / GC
* pool metrics

### 3. Zaproponuj warstwę AWS

Uwzględnij:

* ALB access logs
* ewentualnie CloudFront enhanced metrics
* ECS task-level observability
* CloudWatch dashboards / alarms pod test

### 4. Zaproponuj tracing / APM

Jeśli rekomendujesz:

* OpenTelemetry
* X-Ray
* inne APM

to opisz:

* minimalny zakres
* co dokładnie da
* czy warto to wdrożyć przed następnym testem, czy dopiero później

### 5. Nadaj priorytety

Dla każdego elementu daj:

* wartość diagnostyczną
* koszt / wysiłek wdrożenia
* priorytet

### 6. Daj gotową checklistę

Chcę checklistę "przed kolejnym testem".

## Oczekiwany wynik

Przygotuj odpowiedź dokładnie w tej strukturze:

### A. Executive Summary

* co trzeba wdrożyć koniecznie przed następnym testem
* co da największy zwrot diagnostyczny

### B. Must-have instrumentation

* lista absolutnego minimum
* dlaczego to jest najważniejsze

### C. Application instrumentation

* route-level metrics
* downstream timings
* pool metrics
* memory / GC / event loop
* log correlation
* co dokładnie mierzyć

### D. AWS / infra instrumentation

* ALB
* CloudFront
* ECS
* Redis / ElastiCache
* dashboards / alarms

### E. Tracing / APM recommendation

* czy wdrażać
* jaki wariant minimalny
* co to da

### F. Prioritized implementation plan

Tabela:

* element
* wartość diagnostyczna
* effort
* priority

### G. Pre-test checklist

Krótka checklista do odhaczenia przed kolejnym testem

### H. Final verdict

Jedno zdanie operatorskie:

* jaka instrumentacja jest konieczna, żeby następny test dał jednoznaczniejsze wnioski

## Priorytet

Najpierw:

1. minimum konieczne,
2. największy zwrot diagnostyczny,
3. plan wdrożenia,
4. checklista przed testem.
