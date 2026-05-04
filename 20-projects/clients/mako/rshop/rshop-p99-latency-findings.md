---
title: rshop — findings ALB p99 latency
date: 2026-05-04
project: rshop
account: "943111679945"
severity: P3
status: identified
tags: [rshop, alb, latency, performance, external-api, ecs]
---

# rshop — Findings: ALB p99 latency flapping

## Objaw

ALB `TargetResponseTime p99 > 2s` — alarm flapping (ALARM/OK), zidentyfikowany 2026-05-04.

- p50: 8–60ms (stabilne przez cały czas)
- p99: 800ms–**6572ms** (spike co kilka minut)
- 5XX: minimalne (2-4/5min), nie korelują z p99

**Charakter:** long tail — nie globalny slowdown. Zdecydowana większość requestów fast.

## Kontekst

- LoadBalancer: `app/prod-ALB/90737edb8f90e9e6`
- ECS cluster: `rshop-prod-Klaster`
- Serwis: `rshop-prod-api-svc` (desired=**1**, running=1) — **single instance**
- Logi: `/ecs/rshop-prod` (ASP.NET Core)
- RDS prod: `pssa61v1phykq0` (SQL Server Web, db.t3.large)
- System obsługuje wiele domen z jednego procesu: bo.sklep.renault.pl, bo.sklep.dacia.pl, bo.eshop.dacia.sk/cz, bo.eshop.renault.cz

## Root Cause

### PRIMARY: `/api/Services` → zewnętrzne API Renault/Dacia

Endpointy:
- `GET /api/Services/category/{cat}/bir/{bir}/vin/{vin}`
- `GET /api/Services/categories?bir={bir}&vin={vin}`

wykonują synchroniczne wywołania do zewnętrznego backendu Renault/Dacia (vehicle service catalog).

**Czasy odpowiedzi zewnętrznego API:**

| Endpoint | cnt (2h) | avg | max |
|----------|----------|-----|-----|
| `/api/Services` | 64 req >500ms | **4701ms** | **12307ms** |
| `/api/Tires` | 33 req >500ms | 1276ms | 6642ms |
| `/api/pdf` / `/api/PDF` | 82 req >500ms | 1559ms | 4382ms |

Czasy Services są wysoce zmienne — od 300ms (kiedy backend działa) do 12s (kiedy zewnętrzne API wolne).

### Mechanizm kolejkowania

```
User A → /api/Services/vin/... → external API → 10s (blokuje wątek)
User B → /api/Services/vin/... → external API →  8s (blokuje wątek)
User C → /api/Basket/...       → kolejkuje za A+B → pojawia się w p99
```

Przy **desired=1** (single ECS task) ASP.NET Core ma ograniczony thread pool na jednym kontenerze. Równoległe wywołania Services (4–11 na 5 minut) wypełniają wątki i kolejkują pozostałe requesty.

### Flapping ALARM/OK

Flapping jest spowodowany burstowością Services requestów:
- brak zapytań o historię serwisową → p99 normalny
- burst zapytań (user otwiera historię) → p99 skacze > 2s → ALARM
- burst mija → OK

### Contributing factors

1. **Single ECS task** — brak horizontal scaling; jeden wolny request blokuje wszystkich
2. **PDF generation** — CPU-bound, 2–4s, 82 req/2h (price lists + maintenance plans)
3. **Brak timeout / circuit breaker** na external API calls (brak dowodów na timeout w logach — requesty czekają do 12s)
4. **Brak autoscalingu** ECS

### Wykluczone

| Czynnik | Status | Dowód |
|---------|--------|-------|
| RDS | ✅ zdrowy | ReadLatency avg=0.3ms, max=2.9ms |
| Healthcheck failures | ✅ brak | stopped tasks=0, targets healthy |
| Deployment | ✅ brak | rollout=COMPLETED, steady state events |
| Network/infra | ✅ OK | ELB 5XX minimalne, brak wzorca |

## Korelacja czasowa

| ALB window (CEST) | p99 | Services calls (UTC) | max Services |
|-------------------|-----|---------------------|--------------|
| 13:04 (worst) | **6572ms** | 11:00–11:05 UTC | **12307ms** |
| 11:44 | 3612ms | 09:40 | 8301ms |
| 11:29 | 3198ms | 09:45 | 9965ms |
| 11:49 | 2507ms | 10:10 | 11600ms |

Korelacja 1:1 — każdy spike ALB p99 ma odpowiadający burst Services external API calls.

## Rekomendowane działania

Priorytet | Działanie | Efekt
--- | --- | ---
P1 | Timeout na external API ≤5s + fallback (pusta lista / cached) | eliminuje 12s blokad
P1 | Circuit breaker (Polly) na wywołania Renault/Dacia | fast-fail przy degradacji backendu
P2 | Cache wyników `/api/Services` per VIN (TTL 24h) | historia serwisowa statyczna, nie zmienia się
P2 | ECS desired=2 + autoscaling (ALBRequestCountPerTarget ≈ 500) | eliminuje single-task bottleneck
P3 | PDF → background job + S3 presigned URL | odblokowanie thread pool z CPU-bound pracy

## Uwagi operacyjne

- Log group API: `/ecs/rshop-prod` | Backoffice: `/esc/backoffice` (uwaga: literówka `/esc/` zamiast `/ecs/`)
- Container Insights CPU — dane niedostępne w czasie analizy (brak metryk w namespace)
- Runbook diagnostyczny: [[rshop-alb-p99-latency-2026-05-04]]
- Przy kolejnym incydencie: sprawdź `CW Logs Insights` na `/ecs/rshop-prod` z query `filter @message like /Request finished/ | parse @message / (?<duration>[0-9]+\.[0-9]+)ms/ | sort duration desc` (ważne: regex bez "in " — format ASP.NET Core)
