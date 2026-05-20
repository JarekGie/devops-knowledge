---
type: prompt
topic: RCA load test 2026-05-11
created: 2026-05-11
---

# Prompt: RCA po load teście 2026-05-11 00:00–01:00 CEST

Pracujesz jako senior SRE / DevOps / incident analyst na projekcie Maspex.

Masz wykonać **RCA (root cause analysis)** po load teście **Maspex UAT** z dnia:

* **2026-05-11**
* **00:00–01:00 CEST**

## Kontekst wejściowy

Traktuj poniższe ustalenia jako potwierdzone fakty z wcześniejszej analizy:

* test był jedno-falowy, około 55 minut aktywnego ruchu
* peak ruchu był około **00:20 CEST / 22:20 UTC**
* CloudFront obsłużył bardzo duży wolumen
* ALB zanotował:

  * bardzo wysoki `RequestCount`
  * bardzo zły tail latency
  * realne `HTTPCode_Target_5XX_Count`
  * częściowo też `HTTPCode_ELB_5XX_Count`
* ECS:

  * CPU avg peak około 46%
  * CPU max około 79%
  * memory max na taskach ponad 84–92%
  * po teście memory **nie wróciła do baseline**
  * po teście health-check latencja nadal była podwyższona
* Redis / ElastiCache:

  * zdrowy
  * bez evictions
  * bez swap
  * bez symptomów saturacji
  * `VOTE_CACHE_WRITETHROUGH_FAIL` nie występował
* logi aplikacyjne:

  * nie potwierdzają już starego problemu z circuit breakerem Redis
  * wskazują, że problem przesunął się poza Redis
* główny open question:

  * czy bottleneck siedzi w aplikacji,
  * w DB / Supabase / downstream,
  * w poolach połączeń,
  * w memory pressure / GC / event loop lag,
  * czy w kombinacji powyższych

## Cel

Chcę, żebyś przygotował **RCA operatorsko-architektoniczne**, które:

1. oddzieli fakty od hipotez,
2. wskaże najbardziej prawdopodobny root cause,
3. rozpisze możliwe contributing factors,
4. oceni, co zostało już wykluczone,
5. poda konkretny plan dalszej weryfikacji.

## Bardzo ważne zasady

* nie zgaduj
* jeśli czegoś nie da się potwierdzić, nazwij to hipotezą
* oddziel:

  * **Root cause**
  * **Contributing factors**
  * **Symptoms**
* nie wracaj do starej narracji "to Redis", jeśli evidence temu przeczy
* weź pod uwagę, że poprzedni problem Redisowy mógł zostać naprawiony i odsłonić nowy bottleneck
* jeśli widzisz kilka sensownych wariantów RCA, pokaż ranking prawdopodobieństwa

## Co masz zrobić

### 1. Zsyntetyzuj fakty

Na podstawie dostępnego raportu zbierz twarde fakty:

* co dokładnie stało się na ALB
* co dokładnie stało się na ECS
* co wiadomo o Redis
* co wiadomo o logach
* co wiadomo o zachowaniu po teście

### 2. Zbuduj hipotezy RCA

Rozważ minimum te hipotezy:

#### H1 — application memory pressure / GC / event-loop lag

* czy memory retention + latency tail pasują do tego scenariusza

#### H2 — DB / Supabase / downstream connection pool exhaustion

* czy 5xx + p99 15.8 s + brak problemów Redis pasują do wolnego downstreamu

#### H3 — request queue buildup / burst overload bez wystarczającego autoscalingu

* czy burst był zbyt gwałtowny, żeby system zdążył się rozwinąć

#### H4 — kombinacja memory pressure + downstream slow path

* czy to jest bardziej prawdopodobne niż pojedyncza przyczyna

### 3. Oceń prawdopodobieństwo

Dla każdej hipotezy daj:

* evidence za
* evidence przeciw
* ocenę prawdopodobieństwa:

  * wysokie
  * średnie
  * niskie

### 4. Wskaż najbardziej prawdopodobny root cause

Chcę:

* 1 główny root cause
* ewentualnie 1–2 contributing factors

### 5. Wskaż czego jeszcze brakuje

Opisz:

* jakich metryk / logów / tracingu brakuje
* co trzeba zebrać przy następnym teście, żeby zamknąć RCA

### 6. Przygotuj plan weryfikacji

Chcę listę testów / checków:

* co sprawdzić od razu
* co sprawdzić przed następnym load testem
* co wdrożyć jako instrumentację

## Oczekiwany wynik

Przygotuj odpowiedź dokładnie w tej strukturze:

### A. Executive Summary

* najbardziej prawdopodobny root cause
* najważniejsze contributing factors
* co już można uznać za wykluczone

### B. Confirmed facts

* lista twardych faktów z raportu
* bez interpretacji

### C. Hypothesis assessment

Dla każdej hipotezy:

* description
* evidence for
* evidence against
* probability

### D. Most likely RCA

Jednoznacznie:

* root cause
* contributing factors
* mechanizm degradacji

### E. What was ruled out

* tabela obszarów, które nie wyglądają na root cause

### F. Gaps in evidence

* czego jeszcze nie wiemy
* co blokuje pełne domknięcie RCA

### G. Verification plan

* działania natychmiastowe
* działania przed kolejnym testem
* dane do zebrania

### H. Final verdict

Jedno krótkie zdanie operatorskie:

* co jest dziś najbardziej prawdopodobną przyczyną incydentu

## Priorytet

Najpierw:

1. potwierdzone fakty,
2. ranking hipotez,
3. najbardziej prawdopodobne RCA,
4. plan domknięcia RCA.
