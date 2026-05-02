# rshop PROD — p99 Latency Degradation (2026-05-02)

#incident #aws #performance #sre

## 1. Objaw / symptom

ALB TargetResponseTime p99 przekroczył 2s (SLO alarm). Spike:
- 21:00 CEST: p99 = 7.59s
- 21:01 CEST: p99 = 11.55s (peak)
- 21:06 CEST: RequestCount = 2040 req/min (normalnie 33-338)
- p50 pozostało zdrowe (4-27ms) — long-tail pattern, nie overload systemowy

## 2. Zakres / scope

- Konto: rshop prod (943111679945)
- Region: eu-central-1
- Czas zdarzenia: 2026-05-02 ~21:00-21:15 CEST
- Chroniczne podwyższone p99 (600ms-2s) przez cały okres obserwacji
- Brak 5xx od aplikacji — wszystkie requesty zakończone sukcesem

## 3. Stan infrastruktury (READ-ONLY audit)

| Komponent | Status |
|-----------|--------|
| ECS: rshop-prod-api-svc | desired=running=1, stable (deploy 2026-04-30) |
| ECS: rshop-prod-frontend-svc1/2 | desired=running=1, stable |
| ECS: rshop-prod-backoffice-svc | desired=running=1, stable |
| Target groups (6/6) | 100% healthy |
| RDS pssa61v1phykq0 (db.t3.large, sqlserver-web) | CPU 7-10%, połączenia 2-5, latency <1ms |
| HTTPCode_Target_5XX | BRAK — zero błędów aplikacji |
| HTTPCode_ELB_5XX | pojedyncze (1-5/min scattered) |

RDS jest **kompletnie zdrowy**. Baza danych nie jest bottleneckiem.

## 4. Root Cause — dwie niezależne przyczyny

### Przyczyna A: External DMS API bez timeout/cache (WYSOKA)

**Endpoint:** `/api/Services/categories` i `/api/Services/category/{id}`

API wywołuje zewnętrzny system DMS dealerów Renault/Dacia używając `bir=` (kod dealera) + `vin=` (VIN pojazdu). Pierwszy request per VIN/dealer:

```
21:09:48 GET /api/Services/categories?bir=61617073&vin=VF1RFC00856670325&basketId=... → 12,422ms
21:10:13 GET /api/Services/category/5/bir/61617073/vin/VF1RFC00856670325?mileage=208000 → 9,437ms
21:11:03 GET /api/Services/categories?bir=61617073&... (2. wywołanie, cache) → 593ms
21:11:13 GET /api/Services/category/3/... → 2,522ms
21:11:33 GET /api/Services/category/7/... → 1,568ms
21:11:48 GET /api/Services/category/82/... → 2,189ms
```

**Dlaczego:** Brak HTTP response cache (drugie wywołanie do tego samego BIR/VIN: 593ms — internal cache działa), brak timeout na wywołaniach zewnętrznych, brak circuit breaker. DMS cold start = 12.4s.

### Przyczyna B: `ORDER BY NEWID()` w SQL Accessories (ŚREDNIA)

**Endpoint:** `/api/Accessories`, `/api/Accessories/details/{id}`

EF Core generuje zapytanie:
```sql
SELECT TOP(@__p_4) [a].[Id], ...
FROM [Accessory] AS [a]
WHERE [complex filter]
ORDER BY NEWID()
```

`NEWID()` = nowy GUID per wiersz przy sortowaniu → full table scan na każdy request, nie może użyć indeksów. Przy normalnym obciążeniu: 30-115ms. Przy 3 concurrent requestach: 1-2s każdy.

```
21:01:11 GET /api/Accessories/details/749M62522R?bir=61617904 → 1,819ms
21:01:11 GET /api/Accessories?pageSize=9&bir=61617904&categoryId=303 → 1,036ms
21:01:11 POST /api/Basket/.../dealer/bir/61617904 → 1,781ms
```

Wszystkie trzy zakończyły się jednocześnie → były skolejkowane, serwowane jako concurrent.

## 5. Oś czasu korelacji

```
20:59  DB connections: 3 → 4 → 5 (normalnie ~3)
21:00  ALB p99 spike 7.59s — Accessories concurrent requests
21:01  ALB p99 peak 11.55s — 3 heavy requests completing simultaneously
21:06  RequestCount 2040/min — frontend retry storm po slow responses
21:09  User zaczyna booking serwisu (Renault, VIN lookup + mileage)
21:10  Services/categories cold call: 12.4s → zewnętrzny Renault DMS
21:10  Services/category/5: 9.4s — DMS wciąż wolny
21:11+ Services/categories: 593ms (cache), category/{3,7,82}: 1.5-2.5s
```

## 6. Klasyfikacja

| | |
|--|--|
| **Incydent?** | Nie — brak błędów dla klientów, brak 5xx |
| **SLO breach?** | Tak — p99 >2s |
| **Strata danych?** | Nie |
| **Impact na przychód?** | Możliwy — użytkownik na 12.4s serwis booking mógł opuścić stronę |
| **Czas trwania** | ~15 min (21:00-21:15 CEST) + chroniczne podwyższone p99 |
| **Zakres** | Endpointy: Accessories, Services (booking serwisu pojazdu) |

## 7. Diagnoza architektoniczna

System wykazuje wzorzec **single-task low-scale**:
- `desired=1` dla wszystkich serwisów — zero horizontal scaling
- Brak circuit breakerów na zewnętrznych API
- Brak HTTP response cache dla kosztownych wywołań
- `ORDER BY NEWID()` — anti-pattern EF Core dla losowych wierszy
- Brak APM/tracing — root cause wymagał ręcznego grep logów

## 8. Rekomendacje

**Natychmiast:**
1. Dodaj response cache na `/api/Services/categories?bir=X&vin=Y` — TTL 60s wystarczy (katalog serwisów zmienia się max raz dziennie). Eliminuje 12.4s cold start.
2. Dodaj HTTP timeout na wywołania DMS — max 10s z 503 fallback zamiast nieskończonego czekania.

**Krótkoterminowo:**
3. Zastąp `ORDER BY NEWID()` — pobierz stronę bez sortowania, potem shuffle w aplikacji. Eliminuje full table scan.
4. Zwiększ `desired=2` minimum dla `rshop-prod-api-svc` — single task jest SPOF na latency pod obciążeniem.

**Średnioterminowo:**
5. Circuit breaker na integrację DMS (Polly lub podobne) — jeśli DMS >5s, zwróć stale data z "tryb degradowany".
6. Dodaj APM tracing (X-Ray lub OpenTelemetry) — investigacja wymagała 45 min ręcznego grep, z APM byłaby 5-minutowa.
