# Maspex UAT — Wyniki testu kalibracyjnego autoscalingu 2026-05-14

#maspex #autoscaling #loadtest #calibration

Data: 2026-05-14 ok. 19:55–21:00 CEST
Środowisko: UAT | ECS: `maspex-uat/maspex-api` | AWS profile: `maspex-cli`

---

## Stan przed testem (baseline)

| Metryka | Wartość |
|---------|---------|
| ECS desired | 9 |
| ECS running | 9 |
| ECS task definition | maspex-api:61 |
| CPU avg (idle) | ~1.5% |
| HealthyHostCount | 9 |
| ALB req/s (idle) | ~0.05 |
| Autoscaling min/max | 9 / 20 |
| Polityki aktywne | 3 (ALBRequestCountPerTarget, CPU, Memory) |

CPU baseline 1.5% — zdrowy, normalny stan. (Kontrast z testem porannym gdzie CPU baseline wynosił ~25% — to był efekt poprzedniego testu load, nie TD:61.)

---

## Stage 0 — wyniki

| Parametr | Wartość |
|---------|---------|
| VUs per generator | 10 |
| Generators | 4 |
| Duration | 3 min |
| k6 req/s per generator | **1,335 req/s** |
| k6 avg latency | 7.42ms (p90: 8.87ms, p95: 11.6ms) |
| k6 errors | **0.00%** |
| ALB RequestCount peak | **~5,340 req/s** |
| ALBRequestCountPerTarget peak | **~35,599 req/task/min** |
| ELB 5xx | **0** |
| ALB TargetResponseTime avg | **3ms** (trivial endpoint) |
| Scale-out triggered | **TAK** — AlarmHigh ALBRequestCountPerTarget |
| ECS po scale-out | desired=20, running=20 (max cap) |

**Uwaga krytyczna:** `/api/health` ma 7ms latency — k6 produkował 135 req/s per VU zamiast zakładanych 10 req/s. Efekt: Stage 0 z 10 VUs × 4 gen wygenerował ~5,340 req/s ALB (poziom Stage 3). Endpoint jest cache'owany po stronie Edge CF (pominięcie ALB) — NIE — dane ALB potwierdzają, że requesty trafiały na ALB.

---

## Kalibracja VU → req/s

| Wartość | Dane |
|---------|------|
| rps per VU per generator | **135 req/s** |
| Poprawny VU dla Stage 0 (500 req/s ALB) | 1 VU/gen |
| Poprawny VU dla Stage 1 (2,000 req/s ALB) | 4 VU/gen |
| Poprawny VU dla Stage 2 (2,500 req/s ALB) | 5 VU/gen |
| Poprawny VU dla Stage 3 (3,500 req/s ALB) | 7 VU/gen |
| Poprawny VU dla Stage 4 (4,500 req/s ALB) | 9 VU/gen |

Uwaga: te wartości dotyczą endpointu `/api/health` (7ms latency). Dla produkcyjnego endpointu `/api/slogan/vote` (szacowany ~300ms) VU count będzie ~40× wyższy.

---

## Autoscaling — timing scale-out

| Timestamp CEST | Zdarzenie |
|----------------|----------|
| 20:04:10 | Load start (k6 na 4 generatorach) |
| 20:04–20:07 | ALB: 268k–320k req/min (35,000 req/task/min — TargetValue×3.5) |
| 20:07:10 | Load stop (k6 zakończony) |
| 20:09:48 | **Scaling activity: AlarmHigh ALBRequestCountPerTarget → desired=20** |
| 20:14:48 | Scale-out cooldown expires (300s) |

**Timing breakdown:**
- 3 min: AlarmHigh EvaluationPeriods (3 × 60s = 180s)
- 30s: scale-out cooldown
- ~2 min: ECS task start + ALB health check
- **Total: ~5.5 min od przekroczenia TargetValue do nowych tasków healthy**

---

## Autoscaling — timing scale-in

| Timestamp CEST | Zdarzenie | desired |
|----------------|----------|---------|
| 20:09:48 | Scale-out: 9→20 | 20 |
| 20:24:42 | Scale-in: AlarmLow ALBRequestCountPerTarget | 19 |
| 20:31:01 | Scale-in: AlarmLow CPU | 18 |
| 20:37:36 | Scale-in: AlarmLow Memory | 17 |
| 20:44:01 | Scale-in: AlarmLow CPU | 16 |
| 20:50:36 | Scale-in: AlarmLow Memory | 15 |
| 20:57:01 | Scale-in: AlarmLow CPU | 14 |

**Scale-in pattern: ~1 task per ~6.5 min**
- AlarmLow EvaluationPeriods=15 (15 min od braku load do pierwszego scale-in)
- Cooldown między krokami: 300s
- Trzy policy (ALB, CPU, Memory) rotują co 6.5 min
- Czas od scale-out do powrotu na min=9: **~80-90 min**

---

## Ocena skuteczności

### Mechanizm
- **Polityka ALBRequestCountPerTarget**: ISTNIEJE, AKTYWNA
- **Trigger**: poprawny (AlarmHigh fires przy >10,000 req/task/min)
- **Scale-out**: poprawny (desired=20 = max cap przy 35,000 req/task/min)
- **Scale-in**: poprawny (1 task co 6.5 min, konserwatywny)
- **5xx podczas testu**: 0 (null) — brak degradacji przy tym endpoincie

### Timing scale-out
- **5.5 min od przekroczenia threshold do nowych tasków healthy**
- Przy realnym endpoincie (vote, 300ms latency): przez te 5.5 min system operuje bez dodatkowej pojemności
- Przy 1,500 req/s (scale-out trigger): 9 tasks × 167 req/s = na granicy safe/degradation zone
- Przy szybkim rampie (2,000+ req/s): przez 5.5 min w degradation zone

### Klasyfikacja
**`WORKING_BUT_TOO_LATE`**

Uzasadnienie:
- Mechanizm działa poprawnie
- ALE: 3-minutowy evaluation period (EvaluationPeriods=3) oznacza 3 min w overload zanim alarm fires
- Przy produkcyjnym endpoint i szybkim rampie: te 3 min = degradacja lub incident, zanim autoscaling zareaguje
- Pre-scaling before load tests jest **konieczny** (jak pokazały testy poranne)

### Co poprawić

**Opcja A — redukcja EvaluationPeriods (3→2):**
- Przyspiesza trigger o 1 min
- Ryzyko: fałszywe alarmy przy krótkich spikach
- Zmiana w Terraform: `scale_out_cooldown = 30` (bez zmiany) + parametry alarmu zarządzane przez AWS

**Opcja B — obniżenie TargetValue (10000→8000):**
- Scale-out trigger wcześniej (przy 1,200 req/s zamiast 1,500)
- Pre-scale buffer: 9 → 12 tasks bez load przy ~900 req/s
- Koszt: więcej tasków w steady state

**Opcja C — pre-scale przed testem (rekomendowana operacyjna):**
- Manualne ustawienie min=15 lub 18 przed spodziewanym ruchem
- Powrót do min=9 po teście
- Bez zmian w kodzie

---

## Błędy naprawione podczas sesji

| Plik | Zmiana |
|------|--------|
| `scripts/loadtest-ctrl.sh` | `DESIRED_CAPACITY_RUN=2→4, MAX_SIZE_RUN=2→4` |
| `scripts/loadtest-ctrl.sh` | Fix `add_loadtest_ips_to_allowlist`: pusta tablica `${arr[@]:-}` zwracała pusty string → skip empty w loop |

---

## Linki
- [[loadtest-calibration-runbook]] — procedura testu
- [[loadtest-2026-05-14-analysis]] — analiza testu #1 rano
- [[loadtest-2026-05-14-analysis-test2]] — analiza testu #2 rano
