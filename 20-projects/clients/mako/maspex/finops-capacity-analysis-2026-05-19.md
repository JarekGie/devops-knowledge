# FinOps & Capacity Analysis — maspex-prod — 2026-05-19

**Okno analizy:** 2026-05-18 12:00 CEST — 2026-05-19 12:00 CEST (24h po kampanii)  
**Env:** account 969209893152 / eu-west-1 / cluster `maspex-prod` / service `maspex-api`  
**Task definition:** 4 vCPU / 8 GB RAM, image `maspex-api:coreapp-prod-805`  
**Autoscaling bieżące:** min=30, max=45, target ALB=200 req/5min/task, CPU=60%, Memory=75%

---

## 1. Executive Summary

**Środowisko PROD jest masowo przewymiarowane relative do rzeczywistego ruchu.**  
Peak produkcyjny (123 req/s) to ~52× mniej niż szczytowe obciążenie load-testowe (6 483 req/s).  
Przy min=30 całą noc (~10h, 02:00–09:00 CEST) system obsługiwał 2–5 req/s utrzymując 30 tasków.

**Werdykt: CONDITIONAL GO** na redukcję min=30 → min=8, max=45 → max=30.  
Warunek: tydzień monitoringu po zmianie z alertem P99 >500ms + Running Tasks <min_threshold.

**Szacowane oszczędności: ~$2 190/mies. (−49%) przy min=8, max=30.**

---

## 2. Real Production Load

### CloudFront (twojkapsel.pl, dist E33PUJBAQ533K0)

| Metryka | Wartość |
|---------|---------|
| Całkowite requestów 24h | 6 789 470 |
| Peak godzinny (15:00–16:00 CEST) | 582 599 req/h = **161.8 req/s** |
| Średnia hourly | 282 895 req/h = **78.6 req/s** |
| 4xx rate (avg/max) | 1.1% / 1.6% |
| 5xx rate | **0.0%** |
| Cache hit rate CloudFront | ~38.5% (6 789k - 4 178k ALB = 2 611k absorbed) |

### ALB → ECS (rzeczywisty ruch do aplikacji)

| Metryka | Wartość |
|---------|---------|
| Całkowite requestów 24h | 4 178 174 |
| Peak 5-min window | 37 018 req = **123.4 req/s** |
| Średni req/s (24h) | **48.4 req/s** |
| Minimalny req/s (noc) | **2.2 req/s** (02:00–05:00 CEST) |
| ALB latency avg | 20.1 ms |
| ALB latency p95 | 55.9 ms |
| ALB latency p99 (avg) | 221.5 ms |
| ALB latency p99 podczas peak (15–16:30 CEST) | **184–196 ms** |
| ALB latency p99 (nocny min, 04:00) | 1 206 ms (1 conn / outlier) |
| ELB 5xx | negligible |
| Rejected connections | **0** |

### Load test vs produkcja

| | Load test (2026-05-11) | Produkcja peak |
|---|---|---|
| req/s | 6 483 | 123 |
| Stosunek | **52.6× wyżej niż prod peak** | — |
| Taski ECS | 30 | 41 (autoscaled) |
| CPU per task | ~60% | **0.3–1.24%** |

---

## 3. ECS Utilization Analysis

| Metryka | Avg (24h) | P95 | Max |
|---------|-----------|-----|-----|
| CPU Utilization | 0.3–1.24% | ~3% | ~5% (szacowane) |
| Memory Utilization | 3–7% | ~10% | ~12% (szacowane) |
| RunningTaskCount | **31.38** | — | 48.8 (chwilowe) |
| PendingTaskCount | 0 (normalnie) | — | 35 (scale-out) |
| DesiredTaskCount | 30 | — | **41** |

**Wniosek:** Taski praktycznie idle. CPU poniżej 1.5%, Memory poniżej 7%. Każdy task zużywa <2% swojej faktycznej pojemności (load-test reference: 216 req/s/task @ 60% CPU).

---

## 4. Traffic Analysis (RPS / Latency / Peaks)

### Profil dobowy (ALB requests/h → req/s)

| Godzina CEST | Req/h | Req/s avg |
|---|---|---|
| 12–13 | ~160 000 | 44 |
| 13–14 | ~480 000 | 133 |
| 14–15 | ~511 000 | 142 |
| **15–16** | **~582 000** | **162** ← peak godzinny CF |
| 16–17 | ~554 000 | 154 |
| 17–18 | ~480 000 | 133 |
| 18–21 | ~390–426 000 | 108–118 |
| 21–23 | ~300–389 000 | 83–108 |
| 23–00 | ~298 000 | 83 |
| 00–03 | ~120 000 → 27 000 | 7–33 |
| 03–06 | ~22 000–44 000 | 6–12 |
| 06–09 | ~140 000–244 000 | 39–68 |
| 09–12 | ~218 000–391 000 | 61–109 |

**Dwa wyraźne okna:**
- **Nocne (23:00–09:00 CEST, ~10h):** 2–40 req/s; min=30 to czyste przepalanie $
- **Dzienne peak (13:00–18:00 CEST, 5h):** 100–162 req/s; tu autoscaling ma sens

### Latency

Peak window (15:00–16:30 CEST):  
- p99 = 184–196 ms — bardzo dobre dla SSR Next.js app
- Brak degradacji latency mimo scale-out do 41 tasków

---

## 5. Autoscaling Analysis

### Aktywność (2026-05-18)

| Czas CEST | Zdarzenie | Taski |
|---|---|---|
| ~13:49 | Scale-out start (ALB target exceeded) | 30 → ? |
| ~15:23 | Stabilizacja po scale-out | → **41** |
| ~18:30 | Scale-in do min | → **30** |
| 18:30+ | Brak dalszych aktywności | 30 (noc) |

### Analiza triggera ALBRequestCountPerTarget=200

Metryka: requestów per target per 5-min window (CloudWatch resolution).  
Threshold: >200 req/target/5min → scale-out.

```
Peak 5-min: 37 018 total requests
37 018 / 30 tasks = 1 234 req/task/5min  >> 200 → scale-out trigger ✓
37 018 / 41 tasks =   903 req/task/5min  >> 200 → nadal above target
```

**Problem z algorytmem:** autoscaling oblicza target w oparciu o ALB metric, ale target=200 jest bardzo niski względem faktycznej pojemności taska (216 req/s = 64 800 req/5min).  
W efekcie przy 123 req/s system skaluje do 41 tasków chociaż 2-3 taski mogłyby obsłużyć ten ruch.

### Scale-out cooldown

- ALB policy: 30–60s → zbyt agresywne (przeprowadza scale-out zanim poprzednie taski fully zarejestrują się w target group)
- Scale-in cooldown: 300s → rozsądne

---

## 6. Redis Capacity Analysis

| Metryka | Max (24h) | Ocena |
|---------|-----------|-------|
| CPU | 0.55% | Idle |
| Connections | 263 | Niskie (cache.t3.medium obsługuje 4k+) |
| Cache hit rate (avg) | 86.6% | Bardzo dobre |
| Evictions | **0** | Brak memory pressure |
| Memory usage | ~0.51% (z 6.37 GB) | ~33 MB używane |

**Wniosek:** Redis jest masowo przewymiarowany. `cache.t3.medium` (6.37 GB RAM, 2 vCPU) przy 33 MB aktywnych danych i 0 evictions. Potencjalny downscale do `cache.t3.micro` ($14/mies. vs ~$28/mies.) możliwy jeśli wzorce dostępu potwierdzą (<100 conn, hit rate stabilny). **Poza zakresem tego ticketu.**

---

## 7. Cost Analysis

### Fargate task cost (eu-west-1)

| Komponent | Stawka | Per task/h |
|---|---|---|
| 4 vCPU @ $0.04048/vCPU/h | $0.1619 | — |
| 8 GB RAM @ $0.004445/GB/h | $0.0356 | — |
| **Łącznie** | — | **$0.1975/h** |
| Per task/miesięcznie (720h) | — | **$142.19** |

### Scenariusze miesięczne

| Scenariusz | min | max | Avg tasks | Miesięcznie | Delta | Oszczędność |
|---|---|---|---|---|---|---|
| **Current** (min=30, max=45) | 30 | 45 | 31.4 | **$4 465** | — | — |
| **Proposed A** (min=8, max=30) | 8 | 30 | ~16.0 | **$2 275** | −$2 190 | **−49%** |
| **Proposed B** (min=10, max=30) | 10 | 30 | ~18.0 | **$2 559** | −$1 905 | **−43%** |

> *Avg tasks estimated: Current=31.4 (observed), Proposed A=16 (8 nocą, ~20-25 w dzień), Proposed B=18 (10 nocą, ~22-26 w dzień). Koszt nie uwzględnia ALB, CloudFront, Redis — te nie zmieniają się przy zmianie autoscalingu.*

### Nocne marnotrawstwo (ilustracja)

- Okno nocne (23:00–09:00 CEST) ≈ 10h/dobę, ruch 2–40 req/s
- Bieżąco: 30 tasków × 10h × $0.1975 = **$59.25/noc = $1 778/mies.**
- Przy min=8: 8 tasków × 10h × $0.1975 = **$15.80/noc = $474/mies.**
- Nocna oszczędność przy min=8: **$1 304/mies.** (tylko z nocnego okna)

---

## 8. Recommendations

### FINAL RECOMMENDATION: min=8, max=30

#### Uzasadnienie techniczne

**min=8:**
- 8 tasków @ 2.2 req/s (nocne minimum) = 0.27 req/s/task = 0.13% pojemności per task
- 8 tasków @ 123 req/s (kampania peak, przed scale-out) = 15.4 req/s/task = 7.1% pojemności
- Czas scale-out: ~30-60s; podczas tej chwili 8 tasków bez problemu obsłuży spike
- Ranki (06:00–09:00 CEST): ruch rośnie od ~40 req/s → autoscaling fires, stabilizuje na ~12-15 tasków

**max=30:**
- 30 tasków @ 6 480 req/s pojemności (load test reference: 216 req/s/task)
- Produkcyjny peak: 123 req/s = 1.9% pojemności 30 tasków → 5.3× margin ponad peak
- Historycznie nigdy nie przekroczyliśmy 41 tasków; przy max=30 i takim ruchu: nie potrzeba
- Obniżenie max nie blokuje przyszłości: przy 10× wzroście ruchu (1 230 req/s) 30 tasków nadal = 25% pojemności

#### Parametry autoscalingu

| Parametr | Bieżąco | Rekomendacja |
|---|---|---|
| min | 30 | **8** |
| max | 45 | **30** |
| ALBRequestCountPerTarget target | 200 | 200 (bez zmian, osobny ticket) |
| CPU scale-out target | 60% | 60% (bez zmian) |
| Memory scale-out target | 75% | 75% (bez zmian) |
| Scale-out cooldown | 30–60s | bez zmian |
| Scale-in cooldown | 300s | bez zmian |

#### Campaign baseline (pre-scaling manualny)

Przed ogłoszeniem dużej kampanii (np. konkurs ogólnopolski):
- Ręcznie ustaw `desired_count = 20` lub `min_capacity = 20` przez 1–2h przed startem
- Koszt: 20 tasków × 2h × $0.1975 = $7.90 — irrelevant

### Alarmy po zmianie (MUST HAVE)

Przed wdrożeniem zmienić lub dodać alarmy:

1. **RunningTaskCount < 6** → PagerDuty P1 (zakładamy min=8, guard)
2. **PendingTaskCount > 10 przez >5min** → SNS alarm (scale-out blokada)
3. **ALB TargetResponseTime p99 > 500ms przez >5min** → SNS alarm
4. **ALB 5xxCount > 50/min** → PagerDuty P1 (istniejący?)

---

## 9. Risk Assessment

| Ryzyko | Prawdopodobieństwo | Wpływ | Mitigacja |
|---|---|---|---|
| Spike ruchu 5× przed zakończeniem scale-out | Niskie | Średni | 8 tasków obsłuży 600 req/s bez problemu |
| Autoscaling zbyt wolny (cold start ECS) | Niskie-Średnie | Niski | Load test pokazał startup ~30s; CPU headroom ogromne |
| Nocne błędy cron/bot zbijają min | Niskie | Niski | Bot serwis osobny, nie wpływa na api min |
| Kampania bez pre-scalingu | Możliwe | Średni | Procedura kampanijna: [[campaign-day-runbook]] |
| Regression bugiem: OOM przy wyższym load per task | Bardzo niskie | Wysoki | Memory usage 7% max w analizie; load test 8 GB bez OOM |

**Najważniejszy risk:** efektem ubocznym obniżenia min może być wyższy p99 w momentach po scale-out, jeśli nowe taski potrzebują warm-up JVM/cache. W tym przypadku aplikacja to Node.js (stateless) + Redis — warm-up nie jest czynnikiem.

---

## 10. Verdict

```
┌─────────────────────────────────────────────────────┐
│  CONDITIONAL GO                                     │
│                                                     │
│  Zmiana: min=30→8, max=45→30                       │
│  Szacowane oszczędności: ~$2 190/mies. (−49%)      │
│                                                     │
│  Warunki GO:                                        │
│  ✓ Dodaj alarm RunningTaskCount < 6 → P1            │
│  ✓ Dodaj alarm p99 > 500ms przez 5min              │
│  ✓ Monitoruj przez 7 dni po wdrożeniu              │
│  ✓ Wdroż poza kampanią (nie dzień przed eventem)   │
│                                                     │
│  NIE WYMAGA:                                        │
│  - zmiany w kodzie aplikacji                       │
│  - zmiany image / deployment                       │
│  - zmiany polityk autoscalingu (target pozostaje)  │
└─────────────────────────────────────────────────────┘
```

---

## Załącznik: Terraform zmiana

```hcl
# terraform/envs/prod/main.tf
module "service_api" {
  # ...
  desired_count = 8   # zmiana z 30; autoscaling zarządza dalej
  # ...
}
```

Plus w `autoscaling.tf` (lub analogicznym):
```hcl
resource "aws_appautoscaling_target" "api" {
  min_capacity = 8    # było: 30
  max_capacity = 30   # było: 45
}
```

**Nie zmieniać:** polityk scaling (ALBRequestCountPerTarget=200, CPU=60%, Memory=75%).

---

*Analiza oparta na danych CloudWatch / ALB / CloudFront z 2026-05-18 12:00 – 2026-05-19 12:00 CEST.*  
*Dane kosztowe: Fargate eu-west-1 on-demand pricing, stan na 2026-05-19.*  
*Load test reference: [[load-test-analysis-2026-05-11-0000-cest]]*
