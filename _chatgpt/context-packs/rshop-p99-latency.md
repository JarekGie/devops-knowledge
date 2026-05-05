# Paczka kontekstu — rshop ALB p99 latency

> Wklej całość na początku rozmowy z ChatGPT. Cel: <1500 tokenów.

**Zakres:** rshop PROD — chroniczne i incydentalne przekroczenia SLO p99 >2s
**Data przygotowania:** 2026-05-05

---

## Kim jestem / kontekst roli

Senior DevOps/SRE, AWS multi-account (Organizations), Terraform + CloudFormation, ECS Fargate.
Analizuję i dociążam team developerski konkretnymi rekomendacjami do wdrożenia.

## Stan obecny

rshop PROD (konto 943111679945, eu-central-1) ma chroniczny problem z p99 > 2s na ALB (SLO breach).
Zidentyfikowano dwa incydenty: 2026-05-02 (spike do 11.55s, ~15 min) i 2026-05-04 (flapping, max 6.57s, ciągły).
p50 pozostaje zdrowe (8–60ms) — to wyłącznie long tail, nie globalny slowdown.
RDS, healthchecki i deploye wykluczone jako przyczyna. Brak 5xx po stronie aplikacji.

## Root causes (zidentyfikowane)

| Priorytet | Endpoint | Problem | Max |
|-----------|----------|---------|-----|
| P1 | `/api/Services/categories` + `/api/Services/category/{cat}/bir/{bir}/vin/{vin}` | Sync call do zewnętrznego API Renault/Dacia DMS, brak timeout/circuit breaker, brak cache | 12 407ms |
| P2 | `/api/Tires` | Zewnętrzne API, brak timeout | 6 642ms |
| P2 | `/api/pdf` / `/api/PDF` | CPU-bound PDF generation blokuje ASP.NET thread pool | 4 382ms |
| P2 | `/api/Accessories` + `/api/Accessories/details/{id}` | `ORDER BY NEWID()` → full table scan per request (EF Core anti-pattern) | ~2s concurrent |

**Wzmacniacz:** ECS `desired=1` (single task) — jeden wolny request blokuje wątki, pozostałe kolejkują się.

## Kluczowe fakty

- Stack: ASP.NET Core, ECS Fargate, SQL Server (RDS db.t3.large), ALB
- Zewnętrzne API: Renault/Dacia vehicle service catalog (DMS) — czas odpowiedzi 300ms–12s (niepredictowalny)
- `/api/Services` wywoływane 4–11 razy na 5 minut okno — burst pattern → flapping alarmów
- RDS: ReadLatency avg=0.3ms, max=2.9ms — zdrowy, nie jest bottleneckiem
- `ORDER BY NEWID()` przy 3 concurrent requestach: 1–2s każdy (normalnie 30–115ms)
- Cache wewnętrzny w appce działa (drugie wywołanie tego samego BIR/VIN: 593ms vs 12s cold)
- Brak APM — diagnoza wymagała 45 min ręcznego CW Logs Insights

## Zasoby

```
Account: 943111679945
Region: eu-central-1
ALB: app/prod-ALB/90737edb8f90e9e6
ECS cluster: rshop-prod-Klaster
ECS service: rshop-prod-api-svc (desired=1, running=1)
RDS: pssa61v1phykq0 (SQL Server Web, db.t3.large)
Log group API: /ecs/rshop-prod
Log group Backoffice: /esc/backoffice (uwaga: literówka /esc/ zamiast /ecs/)
```

## Pytanie

Potrzebuję pomocy przy formułowaniu rekomendacji dla zespołu dev — konkretne implementacje w ASP.NET Core (.NET):
1. Jak dodać timeout + Polly circuit breaker na HttpClient wywołujący zewnętrzne API DMS?
2. Jak zastąpić `ORDER BY NEWID()` w EF Core (shuffle po stronie aplikacji)?
3. Jak skonfigurować response cache per BIR/VIN w ASP.NET Core (IMemoryCache)?
