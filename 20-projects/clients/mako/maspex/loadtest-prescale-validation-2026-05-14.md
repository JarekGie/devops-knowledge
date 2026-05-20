# Maspex UAT — Wyniki testu walidacyjnego pre-scale 2026-05-14

#maspex #autoscaling #loadtest #prescale #validation

Data: 2026-05-14 ok. 21:46–22:24 CEST
Środowisko: UAT | ECS: `maspex-uat/maspex-api` | AWS profile: `maspex-cli`
Generatory: 4 × EC2 (ASG `maspex-uat-loadtest`), k6 v2.0.0, `constant-arrival-rate`
Endpoint: `/api/health` (~7ms latency)

---

## Pytania badawcze

1. Czy pre-scale eliminuje wejście w incident zone przy szybkim rampie?
2. Jaki poziom pre-scale jest sensowny: 15 czy 18 tasków?
3. Jak zachowuje się system przy 4,500 req/s z gotową pojemnością?

---

## Stan przed testem (baseline po teście kalibracyjnym)

| Metryka | Wartość |
|---------|---------|
| ECS desired / running | 9 / 9 |
| Autoscaling min/max | 9 / 20 |
| CPU avg (idle) | ~0.6% |
| ALB req/s (idle) | ~0.05 |

---

## Naprawione błędy podczas sesji

| Plik | Zmiana |
|------|--------|
| `scripts/loadtest-ctrl.sh` | `info()`/`ok()`/`warn()` → zapis do stderr (`>&2`) zamiast stdout (fix WAF ANSI injection bug) |

---

## Pre-scale: ustawienie min=15, desired=15

| Timestamp CEST | Akcja |
|----------------|-------|
| 21:46:19 | `register-scalable-target --min-capacity 15` |
| 21:46:19 | `update-service --desired-count 15` |
| 21:47:02 | ECS: desired=15, running=15, pending=0 (steady state, ~16s) |
| 21:47:xx | CPU baseline z 15 tasków: ~0.5% |

**Czas rampy ECS: ~16s** (9→15 tasków)

---

## Level A — 3,000 req/s ALB (pre-scale=15)

### Parametry

| Parametr | Wartość |
|---------|---------|
| VUs/gen | auto (constant-arrival-rate) |
| RPS/gen | 750 |
| Generatory | 4 |
| Target ALB | 3,000 req/s |
| Duration | 8 min |
| Start | 21:55:12 |
| End | 22:03:12 |

### k6 wyniki (per generator, wszystkie identyczne)

| Metryka | Wartość |
|---------|---------|
| req/s per gen | 749.8–750.0 |
| Total req | 360,000 per gen / **1,440,003 łącznie** |
| Errors | **0.00%** |
| avg latency | 7.63–7.74ms |
| p90 | 8.95–9.23ms |
| p95 | 14.59–15.04ms |
| max | 1.33–1.45s (outliers, rzadkie) |

### ALB dane (CloudWatch)

| Timestamp CEST | RequestCount/min | req/s | RequestCountPerTarget | Zadanie |
|----------------|-----------------|-------|----------------------|---------|
| 21:55 | 140,298 | 2,338 | 9,353 | ramp-up |
| 21:56 | 180,000 | 3,000 | 12,000 | steady |
| 21:57 | 180,003 | 3,000 | 12,000 | steady |
| 21:58 | 179,997 | 3,000 | 12,000 | steady |
| 21:59 | 180,006 | 3,000 | 12,000 | steady |
| 22:00 | 179,983 | 3,000 | 11,999 | steady |
| 22:01 | 180,026 | 3,000 | 12,002 | steady |
| 22:02 | 89,896 | — | — | koniec |

**ELB 5xx: 0 | Target 5xx: 0**

### Autoscaling — scaling path

| Timestamp CEST | Zdarzenie | desired |
|----------------|----------|---------|
| 21:55:12 | Load start | — |
| 21:56–21:58 | AlarmHigh: 12,000 req/task/min > 10,000 × 3 min | — |
| 22:01:48 | Scale-out #1: AlarmHigh ALBRequestCountPerTarget | **15→18** |
| 22:02:48 | Scale-out #2: nowe taski jeszcze nie healthy | **18→19** |
| 22:04:48 | Scale-out #3: target tracking stabilizacja | **19→20** |

**Czas od startu do pierwszego scale-out: 6 min 36s**

### Analiza per-task load podczas opóźnienia

| Konfiguracja | Req/s per task | Req/task/min | Strefa |
|-------------|---------------|-------------|-------|
| 9 tasków (bez pre-scale) | 333 req/s | 20,000 | ⚠️ degradacja |
| **15 tasków (z pre-scale)** | **200 req/s** | **12,000** | **✅ manageable** |
| 18 tasków (po scale-out) | 167 req/s | 10,000 | ✅ na granicy safe |
| 20 tasków (max) | 150 req/s | 9,000 | ✅ safe |

**Pre-scale z 9→15 zredukowało per-task load o 40% podczas okna autoscaling (6.5 min).**
Brak incydentu, brak 5xx, latencja bez zmiany.

---

## Level B — 4,500 req/s ALB (pre-scale=20 / max cap)

*System po Level A był już na desired=20 (max) dzięki cascade scale-out 15→18→19→20.*

### Parametry

| Parametr | Wartość |
|---------|---------|
| RPS/gen | 1,125 |
| Generatory | 4 |
| Target ALB | 4,500 req/s |
| ECS na start | 20 tasków (max cap) |
| Duration | 8 min |
| Start | 22:06:07 |
| End | 22:14:07 |

### k6 wyniki (per generator)

| Metryka | Wartość |
|---------|---------|
| req/s per gen | 1,124.6–1,124.9 |
| Total req | 540,000–540,001 per gen / **2,160,003 łącznie** |
| Errors | **0.00%** |
| avg latency | 7.72–7.98ms |
| p90 | 9.27–9.62ms |
| p95 | 15.23–16.22ms |
| max | 1.48–2.0s (outliers) |

### ALB dane (CloudWatch)

| Timestamp CEST | RequestCount/min | req/s | RequestCountPerTarget |
|----------------|-----------------|-------|----------------------|
| 22:06 | 232,873 | — | 11,644 | ramp-up |
| 22:07 | 270,010 | 4,500 | 13,501 | steady |
| 22:08 | 269,994 | 4,500 | 13,500 | steady |
| 22:09 | 270,016 | 4,500 | 13,501 | steady |
| 22:10 | 269,997 | 4,500 | 13,500 | steady |
| 22:11 | 270,009 | 4,500 | 13,500 | steady |
| 22:12 | 270,003 | 4,500 | 13,500 | steady |
| 22:13 | 270,004 | 4,500 | 13,500 | steady |
| 22:14 | 37,124 | — | — | koniec |

**ELB 5xx: 0 | Target 5xx: 0**

Per-task load: 4,500 req/s / 20 tasków = **225 req/s per task** (13,500 req/task/min)
Powyżej safe ceiling (167 req/s), ale poniżej incident zone (440 req/s). Zero błędów.

---

## Odpowiedzi na pytania badawcze

### 1. Czy pre-scale eliminuje wejście w incident zone?

**TAK — pre-scale z 9→15 zapobiega wejściu w incident zone przy 3,000 req/s.**

- Bez pre-scale (9 tasków): 3,000 req/s = 333 req/s/task → degradacja zone
- Z pre-scale (15 tasków): 3,000 req/s = 200 req/s/task → powyżej safe ale nie incident
- Potwierdzenie: 0 errors, brak wzrostu latencji podczas 6.5-minutowego okna autoscaling

### 2. Jaki poziom pre-scale: 15 czy 18?

**15 tasków = wystarczające dla 3,000 req/s. Dla 4,500 req/s → pre-scale=20 (max).**

| Pre-scale | Max bezpieczny ruch | Uzasadnienie |
|-----------|--------------------|----|
| 9 (brak) | ~1,500 req/s | 167 req/s × 9 = 1,503 |
| 15 | ~2,500 req/s | 167 req/s × 15 = 2,505 |
| 18 | ~3,006 req/s | 167 req/s × 18 = 3,006 ← minimal safe dla 3k |
| 20 (max) | ~3,340 req/s | 167 req/s × 20 = 3,340 |

Dla 3,000 req/s: pre-scale=18 (na granicy safe) lub 20 (bezpieczny).
Pre-scale=15 działa (0 errors), ale operuje w "yellow zone" i wymaga autoscaling.

**Rekomendacja operacyjna:**
- Spodziewany ruch 2,000–3,000 req/s → pre-scale=15 (wystarczające)
- Spodziewany ruch 3,000–4,500 req/s → pre-scale=20 (max cap)
- Niespodziewany spike → pre-scale=15 minimum, autoscaling działa

### 3. Zachowanie przy 4,500 req/s?

**STABLE** — 4,500 req/s przez 8 min z 20 taskami: 0 errors, latencja bez zmiany.
System jest na max cap (nie może skalować wyżej). Przy produkcyjnym endpoincie (300ms) ten wynik byłby inny.

---

## Klasyfikacja systemu z pre-scale

| Scenariusz | Klasyfikacja |
|-----------|-------------|
| Bez pre-scale, szybki ramp | `WORKING_BUT_TOO_LATE` |
| Pre-scale=15, 3,000 req/s | `WORKING_WELL` |
| Pre-scale=20, 4,500 req/s | `WORKING_WELL` (przy tym endpoincie) |

---

## Stan po teście

| Akcja | Wynik |
|-------|-------|
| Generator fleet stopped | ASG desired=0, wszystkie instancje terminated |
| WAF `maspex-uat-loadtest-allowlist` | wyczyszczony (NextLockToken: 0d807bd6...) |
| ECS autoscaling min-capacity | przywrócony do 9 |
| ECS desired (scale-in w toku) | 20 → scale-in stopniowy (~80-90 min do 9) |

---

## Linki

- [[loadtest-calibration-results-2026-05-14]] — wyniki testu kalibracyjnego (rano)
- [[loadtest-calibration-runbook]] — procedura testu
