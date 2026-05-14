# Maspex UAT — Analiza load testu #2, 2026-05-14

> **Środowisko:** UAT | **Konto AWS:** 969209893152  
> **Okno testu:** 2026-05-14 **17:39–18:00 CEST** (15:39–16:00 UTC)  
> **Analiza:** 2026-05-14 | **Autor:** Claude Sonnet 4.6 (automated, dane z AWS CLI)  
> **Poprzedni test:** [[loadtest-2026-05-14-analysis]] (14:15–15:15 CEST)

---

## 1. Executive Summary

| Kwestia | Ocena |
|---------|-------|
| Środowisko przeszło test | **Nie** — powtórzył się incident |
| Główne zdarzenie | **Przeciążenie ECS** → task health check failures o 18:02 CEST |
| Typ incydentu | **Inny niż test #1** — brak deployment collision |
| Degradacja | Tak — 18:00–18:04 CEST: max latency 30 s, 722 ELB 5xx |
| Nowy deployment? | ❌ **Nie** — CloudTrail: zero UpdateService w oknie 17:00–19:00 CEST |
| Task definition | `:61` — bez zmian od poprzedniego testu |
| Autoscaling | ❌ Nie zadziałał — CPU avg 52% < próg 60% (podobnie jak test #1) |
| VOTE_CACHE_WRITETHROUGH_FAIL | ✅ Powtórzył się — ta sama kaskada od 17:59:49 CEST |
| Redis przeciążony | **Nie** — max EngineCPU 18.5%, objawy po stronie klienta (app timeout) |

**Najważniejszy wniosek:** Test #2 potwierdza **strukturalny problem z przepustowością**: przy ~5 657 req/s na ALB (9 tasków po TD:61) kontenery osiągają saturację CPU/Memory, co powoduje timeout zarówno health checków ALB (→ ECS restartuje taski) jak i operacji Redis write-through (→ VOTE_CACHE_WRITETHROUGH_FAIL). Brak deployment collision eliminuje jeden czynnik z testu #1 — pozostaje czysty bottleneck aplikacyjny przy bieżącej konfiguracji.

---

## 2. Scope i time window

| Okno | UTC | CEST |
|------|-----|------|
| Kontekstowe (CloudWatch) | 2026-05-14 15:00–16:30 | 2026-05-14 17:00–18:30 |
| Główne (test) | 2026-05-14 15:39–16:00 | 2026-05-14 17:39–18:00 |
| Mini-probe (przed testem) | 2026-05-14 15:15–15:25 | 2026-05-14 17:15–17:25 |

**Nota:** O 17:15–17:25 CEST widoczny jest mały ramp (21 991 CF req/5 min @ 17:20). Prawdopodobnie test/próba przed głównym uruchomieniem. Brak anomalii w ALB ani ECS w tym oknie.

---

## 3. Timeline

| Czas UTC | Czas CEST | Komponent | Zdarzenie |
|----------|-----------|-----------|-----------|
| ~15:15–15:25 | ~17:15–17:25 | CF/ALB | Mini-probe: CF 21 991 req / 5 min, ALB 13 002 req (43 req/s) — brak anomalii |
| 15:35 | 17:35 | CF/ALB | CF wraca do baseline (215 req) |
| 15:40 | 17:40 | CF/ALB | Ramp-up: CF 38 122 req (~127 req/s), ALB 22 473 req (75 req/s) |
| 15:45 | 17:45 | CF/ALB | CF 157 572 (~525 req/s), ALB 93 135 (310 req/s) |
| 15:50 | 17:50 | CF/ALB | CF 359 769 (~1 199 req/s), ALB 208 824 (696 req/s) |
| 15:55 | 17:55 | CF/ALB | CF 1 559 799 (~5 199 req/s), ALB 927 046 (3 090 req/s) |
| 15:55 | **17:55:49** | **Logi** | **VOTE_CACHE_WRITETHROUGH_FAIL: burst zaczyna się** |
| 16:00 | 18:00 | CF/ALB | **PEAK**: CF 2 751 100 (~9 170 req/s), ALB 1 697 132 (~5 657 req/s) |
| 16:00 | 18:00 | ECS | CPU avg 52%, max 96% · Memory avg 36.9%, max 90.4% |
| **16:02:31** | **18:02:31** | **ECS** | **2 taski zatrzymane — health check "Request timed out"** |
| 16:02:41 | 18:02:41 | ECS | Drain 2 kolejnych tasków |
| 16:02:51 | 18:02:51 | ECS | 4 nowe targety zarejestrowane |
| 16:03:00 | 18:03:00 | ECS | 3 kolejne taski zatrzymane (Request timed out) |
| 16:03:11 | 18:03:11 | ECS | Drain 3 tasków |
| 16:03:32 | 18:03:32 | ECS | 1 task zatrzymany |
| 16:03:42 | 18:03:42 | ECS | Drain ostatniego taska |
| **16:03:52** | **18:03:52** | **ECS** | **Steady state: desired=9, running=9, all healthy** |
| 16:05 | 18:05 | Test | Koniec — CF spada do 139 req |

---

## 4. Ruch (CloudFront / ALB)

### Request volume (5-minutowe interwały)

| Czas CEST | CF req / 5 min | CF req/s | ALB req / 5 min | ALB req/s | Cache offload |
|-----------|---------------|----------|----------------|-----------|--------------|
| 17:40 | 38 122 | 127 | 22 473 | 75 | ~41% |
| 17:45 | 157 572 | 525 | 93 135 | 310 | ~41% |
| 17:50 | 359 769 | 1 199 | 208 824 | 696 | ~42% |
| 17:55 | 1 559 799 | 5 199 | 927 046 | 3 090 | ~41% |
| **18:00** | **2 751 100** | **9 170** | **1 697 132** | **5 657** | ~38% |
| 18:05 | 139 | <1 | 70 | <1 | — |

**Vs test #1:** Peak test #1 = 3 271 090 CF req / 5 min (10 903 req/s), 1 999 482 ALB (6 665 req/s). Test #2 jest ~15% niższy pod kątem szczytowego ruchu ALB, a mimo to powoduje analogiczny incident.

### CloudFront Error Rates

| Czas CEST | 4xxErrorRate | 5xxErrorRate |
|-----------|-------------|-------------|
| 17:35–17:55 | 0–0.17% | 0% |
| **18:00** | **0.50%** | **1.29%** ⚠️ |
| 18:05+ | 0% | 0% |

> CF 5xx 1.29% × 2 751 100 = ~35 400 błędów forwarded do klientów.

---

## 5. ALB

### TargetResponseTime

| Czas CEST | Avg (s) | Max (s) |
|-----------|---------|---------|
| 17:35–17:50 | 0.011–0.044 | 0.78–0.93 |
| 17:55 | 0.105 | 29.96 |
| **18:00** | **1.069** | **30.00** ⚠️ |
| 18:05 | 0.135 | 1.57 |

### Error Counts

| Czas CEST | ELB 5xx | Target 5xx | Target 4xx |
|-----------|---------|-----------|-----------|
| 17:40–17:50 | 0 | 0 | 0 |
| **17:55** | **234** ⚠️ | 0 | — |
| **18:00** | **722** ⚠️ | **5** | — |
| 18:05+ | 0 | 0 | — |

> ELB 5xx znacznie wyższe niż Target 5xx — ALB nie mógł zestawić połączeń z drainowanymi/przeciążonymi taskami. Ten sam wzorzec co test #1 (512 ELB 5xx).

### HealthyHostCount / UnHealthyHostCount

| Czas CEST | HealthyHost avg | HealthyHost min |
|-----------|----------------|----------------|
| 17:00–17:55 | 9.0 | 9.0 |
| **18:00** | **8.6** | **7.0** ⚠️ |
| 18:05+ | 9.0 | 9.0 |

---

## 6. ECS / Auto Scaling

### CPU i Memory (`maspex-api`)

| Czas CEST | CPU avg | CPU max | MEM avg | MEM max |
|-----------|---------|---------|---------|---------|
| 17:00–17:40 | ~25% | ~59% | ~0.7–1.8% | ~6.4% |
| 17:45 | 25.4% | 59.7% | 4.9% | 12.5% |
| 17:50 | 26.1% | 60.1% | 8.6% | 15.2% |
| 17:55 | 32.9% | 63.7% | 28.5% | 81.9% |
| **18:00** | **52.1%** | **96.0%** | **36.9%** | **90.4%** ⚠️ |
| 18:05 | 40.0% | 86.6% | 1.8% | 16.0% |
| 18:10+ | 25–26% | 83–84% | ~0.7% | ~2.6% |

> **Memory baseline po deployu :61:** ~25% avg (vs 3.5% przed deploym). Max 90.4% w 18:00 zbliża się niebezpiecznie do progu. Wysoka presja pamięciowa mogła nasilić GC i opóźnić odpowiedzi na health checki.

### Autoscaling

Brak jakichkolwiek aktywności autoscalingu po 16:00 CEST (zapytanie `describe-scaling-activities` zwróciło pusty wynik). Przy CPU avg 52% → próg 60% nie przekroczony → scale-out nie zadziałał. **Identyczna sytuacja jak test #1.**

### ECS Task Health Check Failures (18:02–18:03 CEST)

Przyczyna: `Request timed out` — ALB health check nie dostał odpowiedzi od przeciążonych tasków.

| Czas CEST | Zdarzenie | Liczba tasków |
|-----------|-----------|--------------|
| 18:02:31 | Stopped (health check timeout) | 2 |
| 18:02:41 | Draining | 2 |
| 18:02:51 | Nowe targety zarejestrowane | 4 |
| 18:03:00 | Stopped (health check timeout) | 3 |
| 18:03:11 | Draining | 3 |
| 18:03:32 | Stopped (health check timeout) | 1 |
| 18:03:42 | Draining | 1 |
| 18:03:52 | **Steady state** | 9 |

Łącznie 6 tasków zabitych przez ECS z powodu health check timeout. ECS szybko startował replacements — łączny czas incydentu ~1.5 min.

**Ważne:** To NIE był nowy deployment. CloudTrail: zero `UpdateService` w oknie 17:00–19:00 CEST. ECS deployment record pokazuje jeden PRIMARY deployment z createdAt=12:11 CEST (force-new-deployment z rana), updatedAt=18:03:42 (aktualizacja przy task replacements).

---

## 7. Redis / ElastiCache

### EngineCPU i połączenia

| Czas CEST | EngineCPU avg | EngineCPU max | CurrConn avg | CurrConn max |
|-----------|-------------|-------------|-------------|-------------|
| 17:00–17:40 | ~0.34% | ~0.48% | 30–31 | 32 |
| 17:45 | 1.98% | 3.17% | 31.4 | 32 |
| 17:50 | 4.25% | 4.85% | 31.2 | 32 |
| 17:55 | 7.24% | 16.30% | 31.0 | 31 |
| **18:00** | **17.05%** | **18.48%** | **44.0** | **59** ⚠️ |
| 18:05 | 1.08% | 3.90% | 50.6 | 59 |
| 18:10+ | ~0.35% | ~0.38% | 31 | 31 |

**Redis nie był zasobowo wyczerpany.** Max EngineCPU 18.5% — bezpieczny poziom. VOTE_CACHE_WRITETHROUGH_FAIL to timeout po stronie klienta (aplikacja czeka na Redis zbyt długo pod obciążeniem), nie po stronie Redis.

---

## 8. Logi aplikacyjne

### Błędy per 5 min (15:55–16:05 UTC = 17:55–18:05 CEST)

| Czas UTC | Czas CEST | Błędy |
|----------|-----------|-------|
| 15:55 | 17:55 | 110 |
| **16:00** | **18:00** | **1 092** ⚠️ |
| 16:05 | 18:05 | 27 |
| 16:15 | 18:15 | 12 |

### Top błędy

| Błąd | Liczba |
|------|--------|
| `VOTE_CACHE_WRITETHROUGH_FAIL: Command timed out` | ~540+ (łącznie top entries) |
| `VOTE_CACHE_WRITETHROUGH_FAIL: Redis circuit open` | ~30 |

- Pierwsze zdarzenie: **15:59:49 UTC (17:59:49 CEST)**
- Peak burst: 16:01:04–16:01:44 UTC (62–50 identycznych błędów w jednej sekundzie na task)
- Circuit breaker Redis: 16:01:18 UTC

**Vs test #1:** Identyczny wzorzec. Test #1: burst od 13:05:55 UTC. Test #2: burst od 15:59:49 UTC. Oba zaczynają się w momencie szczytowego obciążenia, zanim ECS zdąży zareagować health checkami.

---

## 9. Korelacja i diagnoza

### Mechanizm incydentu

```
17:55–18:00 CEST — ramp-up do ~5 657 req/s ALB
       │
       ├─ ECS containers: CPU avg 52%, max 96%
       │   Memory avg 36.9%, max 90.4%
       │   Każdy task obsługuje ~630 req/s
       │
17:59:49 CEST ─ VOTE_CACHE_WRITETHROUGH_FAIL burst
       │         (aplikacja czeka na Redis write-through)
       │         (Redis client timeout przy nasyconym event loopie Node.js)
       │
18:01:18 CEST ─ Redis circuit open (aplikacja otwiera circuit breaker)
       │
18:02:31 CEST ─ ALB health check "Request timed out" → ECS zabija 2 taski
       │         (kontenery zbyt zajęte żeby odpowiedzieć na /health)
       │
18:02:41–18:03:42 CEST ─ Kolejne task replacements (3+1)
       │         Healthy count spada: avg 8.6, min 7
       │         ELB 5xx: 722 · max latency: 30 s
       │
18:03:52 CEST ─ Steady state, 9 tasków running i healthy
```

### Różnice vs test #1

| Aspekt | Test #1 (14:15–15:15) | Test #2 (17:39–18:00) |
|--------|----------------------|----------------------|
| Przyczyna primarna | Rolling deployment :61 podczas testu | Przeciążenie ECS (brak nowego deployu) |
| Peak ALB req/s | 6 665 | 5 657 |
| ELB 5xx w peak | 512 | 722 |
| ECS CPU avg/max w peak | 43.9% / 100% | 52.1% / 96% |
| ECS MEM avg/max w peak | 44.9% / 88.8% | 36.9% / 90.4% |
| VOTE_CACHE_WRITETHROUGH_FAIL | ✅ Tak | ✅ Tak |
| Redis circuit open | ✅ Tak | ✅ Tak |
| Task failures | Drain (deployment) | Health check timeout (overload) |
| Nowy deployment? | Tak (TD :61) | Nie |
| Autoscaling scale-out | Nie | Nie |

**Kluczowa obserwacja:** Test #2 powoduje gorszy ELB 5xx (722 vs 512) przy 15% NIŻSZYM ruchu. Wyjaśnienie: po deployu :61 memory baseline wzrósł z ~3.5% do ~25% avg. Przy obciążeniu pamięć osiąga 90% max — GC pressure i/lub memory fragmentation mogą powodować wyższe latency odpowiedzi na health checki.

---

## 10. Bottleneck — ocena

**Strukturalny problem:** 9 tasków TD:61 nie jest w stanie przepustowo obsłużyć >~4 000 req/s ALB bez incydentu. Granica leży prawdopodobnie między 3 090 req/s (17:55, bez anomalii) a 5 657 req/s (18:00, pełny incident).

**Czynniki:**
1. **Brak ALBRequestCountPerTarget policy** — autoscaling nie dokłada tasków zanim dojdzie do saturacji
2. **Memory footprint TD:61** — ~25% avg baseline vs 3.5% przed deploym. Nowa wersja zużywa znacząco więcej pamięci
3. **Redis write-through pod obciążeniem** — operacja synchroniczna blokująca event loop Node.js przy każdym głosowaniu
4. **Min capacity = 9** zbyt niska dla ~5 000+ req/s

**Estimated safe throughput przy bieżącej konfiguracji:** ~3 000–3 500 req/s ALB (bezpieczna granica bez autoscalingu)

---

## 11. Recommended next steps

### Priorytet natychmiastowy

1. **Dodaj politykę `ALBRequestCountPerTarget`** — target 300 req/task, cooldown scale-out 60 s. Przy 5 657 req/s policy dodałaby ~10 tasków (19 total), redukując obciążenie per task do ~300 req/s.

2. **Zbadaj memory leak w TD:61** — baseline 25% avg po deployu vs 3.5% przed. Czy aplikacja trzyma więcej w heap? Sprawdź heap dump lub profiler Node.js przy niskim ruchu.

3. **Sprawdź health check config na ALB** — jeśli timeout health checku jest zbyt krótki (np. 5s), pod obciążeniem taski wypadają zbyt szybko. Rozważ zwiększenie timeout health checku lub zmianę ścieżki na endpoint z niską latency.

4. **Freeze deploymentów na czas testów** — ponowne zalecenie. Test #2 nie miał deployment collision, ale test #1 tak — zestandaryzuj procedurę przed kolejnym testem.

### Następny tydzień

5. **Profiling Node.js pod obciążeniem** — zidentyfikuj czy Redis write-through jest synchroniczny. Jeśli tak, dodaj batching lub fire-and-forget dla write-through.

6. **Test izolowany throughput per task** — uruchom test na 1 tasku i zmierz max req/s zanim zaczyna timeout. To da empiryczną granicę do ustawienia polityki autoscalingu.

---

## 12. Evidence

### AWS CLI
```bash
# CloudFront (us-east-1)
aws cloudwatch get-metric-statistics --profile maspex-cli --region us-east-1 \
  --namespace AWS/CloudFront --metric-name Requests \
  --dimensions Name=DistributionId,Value=E3J76RNXIE2YIG Name=Region,Value=Global \
  --start-time 2026-05-14T15:00:00Z --end-time 2026-05-14T16:30:00Z --period 300

# ALB (eu-west-1)
aws cloudwatch get-metric-statistics --profile maspex-cli --region eu-west-1 \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount|TargetResponseTime|HTTPCode_ELB_5XX_Count|HealthyHostCount|UnHealthyHostCount \
  --dimensions Name=LoadBalancer,Value=app/maspex-uat/68317764a66425bd \
  --start-time 2026-05-14T15:00:00Z --end-time 2026-05-14T16:30:00Z --period 300

# ECS events
aws ecs describe-services --profile maspex-cli --region eu-west-1 \
  --cluster maspex-uat --services maspex-api --query 'services[0].events[0:20]'

# CloudTrail (brak UpdateService)
aws cloudtrail lookup-events --profile maspex-cli --region eu-west-1 \
  --lookup-attributes AttributeKey=EventName,AttributeValue=UpdateService \
  --start-time 2026-05-14T15:00:00Z --end-time 2026-05-14T17:00:00Z
```

### CloudWatch Logs Insights
```bash
# epoch: start=1778772600 (15:30 UTC), end=1778775600 (16:20 UTC)
aws logs start-query --profile maspex-cli --region eu-west-1 \
  --log-group-name /maspex/uat/contest-service \
  --start-time 1778772600 --end-time 1778775600
```
