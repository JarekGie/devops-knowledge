---
title: "Supabase cron → twojkapsel.pl/api/cron/sync-redis — analiza dostępności 2026-05-18"
date: 2026-05-18
type: connectivity-investigation
environment: prod
status: resolved-by-cutover
classification: internal
domain: client-work
aws_profile: maspex-cli
---

# Analiza: Supabase cron nie może wywołać `/api/cron/sync-redis`

## A. Executive Summary

**Problem był spowodowany przez dwa nałożone blokery — oba usunięte w ramach cutoveru 2026-05-18:**

1. **DNS pointing to wrong CloudFront** — przed cutoverem `twojkapsel.pl` wskazywało na E17VHHQJ29MVAB (S3 zasłępka, brak API). Supabase dostało 403/404 zamiast trafić do API.
2. **WAF default_action: block** — E33PUJBAQ533K0 (prod API CF) miał WAF blokujący cały ruch poza MakoLab IPs. Supabase IPv6 był co prawda na allowliście, ale IPv4 Supabase nie był pokryty.

Po cutoverze (DNS switch + terraform apply 09:52 UTC):
- `twojkapsel.pl` → E33PUJBAQ533K0 → prod ALB → prod API ✓
- WAF: `default_action: Allow` ✓
- Endpoint odpowiada 200 co minutę ✓

**Aktualny stan (2026-05-18, po cutoverze): endpoint działa poprawnie.**

Residualny problem: Część wywołań Supabase używa `//api/cron/sync-redis` (podwójny slash) → Next.js zwraca 308 Permanent Redirect → pg_net śledzi redirect (ten sam TID w ALB logach) → finalnie 200. Jeśli Supabase dashboard raportuje pierwszy status (308) jako wynik — widoczne "błędy" w monitoringu, ale Redis sync zachodzi.

---

## B. Traffic Path (po cutoverze)

```
Supabase pg_net (IPv6: 2a05:d018:135e:16df:0624:8d0e:2886:f540 + IPv4: 3.172.101.x)
  │
  ▼
CloudFront E33PUJBAQ533K0 (d1w5bz7itj42sz.cloudfront.net)
  Aliases: twojkapsel.pl, www.twojkapsel.pl, test.twojkapsel.pl, www.test.twojkapsel.pl
  WAF: maspex-prod-public-app-allowlist (DefaultAction: Allow)
  Default behavior: CachingDisabled + AllViewer + all 7 HTTP methods
  Path /api/cron/sync-redis → default behavior → pass-through do origin
  │
  ▼
ALB maspex-prod (maspex-prod-1795571755.eu-west-1.elb.amazonaws.com)
  HTTPS Listener port 443
  Rule priority 100: host [twojkapsel.pl, www.twojkapsel.pl] → forward maspex-prod-api-3000
  │
  ▼
Target Group: maspex-prod-api-3000 (port 3000, HTTP)
  30/30 targets healthy (10.44.x.x:3000)
  │
  ▼
ECS Fargate — cluster maspex-prod — service maspex-api
  Task def: maspex-prod-api:19 (registered 2026-05-18T12:14:59 UTC)
  Image: 969209893152.dkr.ecr.eu-west-1.amazonaws.com/maspex-api:coreapp-prod-772
  │
  ▼
Next.js app: app/api/cron/sync-redis/route.ts
  Method: POST only
  Auth: Authorization: Bearer ${CRON_SECRET}
  Action: Supabase RPC get_slogans_for_cache → ElastiCache Redis sync
```

---

## C. CloudFront Findings

| Dystrybucja | ID | Zmiana |
|---|---|---|
| Prod API | E33PUJBAQ533K0 | LastModified: 2026-05-18T09:52:07 UTC (cutover apply) |

**Przed cutoverem:**
- `twojkapsel.pl` alias → E17VHHQJ29MVAB (S3 zasłępka nginx)
- E17VHHQJ29MVAB: origin = `maspex-preprod-zaslepka-969209893152.s3.eu-west-1.amazonaws.com`, brak API, brak WAF
- Supabase wywołujący `twojkapsel.pl/api/cron/sync-redis` → 403 OAC/404 brak klucza S3

**Po cutoverze:**
- E33PUJBAQ533K0: aliases = `twojkapsel.pl`, `www.twojkapsel.pl`, `test.twojkapsel.pl`, `www.test.twojkapsel.pl`
- Default behavior: CachingDisabled + AllViewer + 7 metod HTTP — poprawne dla dynamicznego API
- `/api/cron/sync-redis` trafia na default behavior (brak dedykowanego behavior dla `/api/cron/*`) ✓
- CloudFront: brak blokera

---

## D. WAF / Allow List Findings

**WAF: `maspex-prod-public-app-allowlist` (CLOUDFRONT scope, us-east-1)**

| Reguła | Priority | IPSet | Akcja |
|---|---|---|---|
| allow-public-app-ips | 0 | MakoLab office IPs (195.117.107.110/32, 91.233.19.251/32) | Allow |
| allow-supabase-ipv6 | 1 | `maspex-prod-supabase-ipv6`: `2a05:d018:135e:16df:0624:8d0e:2886:f540/128` | Allow |
| allow-loadtest-fleet | 2 | (opróżniony po load teście) | Allow |
| **Default action** | — | — | **Allow** (zmienione w cutoverze z block) |

**Przed cutoverem:**
- `DefaultAction: block` — cały ruch publiczny blokowany
- Tylko Supabase IPv6 (`2a05:d018:...`) był allowlistowany
- Ruch Supabase IPv4 (3.172.101.x) przez CF nie był allowlistowany → blokowany
- Łukasz z IP MakoLab → allowlistowany → dochodził do API

**Po cutoverze:**
- `DefaultAction: Allow` — cały ruch publiczny przepuszczany
- Nie ma blokady dla Supabase

**Wyjaśnienie asymetrii**: Supabase cron nie działał (blokada WAF dla IPv4), Łukasz z komputera działał (jego IP MakoLab na allowliście).

---

## E. Endpoint Behavior Findings

**Plik:** `app/api/cron/sync-redis/route.ts`

```typescript
export async function POST(req: NextRequest): Promise<NextResponse> {
  const authHeader = req.headers.get("authorization");
  const expectedAuth = `Bearer ${process.env.CRON_SECRET}`;
  if (authHeader !== expectedAuth) {
    return createError("UNAUTHORIZED", "Brak autoryzacji", undefined, 401);
  }
  // ... Supabase RPC + Redis sync
}
```

| Parametr | Wartość |
|---|---|
| Metoda | **POST only** — GET zwróci 405 Method Not Allowed |
| Auth | `Authorization: Bearer ${CRON_SECRET}` — wymagany |
| CRON_SECRET | Dostępny w kontenerze via `.env.local` baked w Docker image przez CI pipeline (`dist/.env → .env.local`) |
| Supabase client | `createServiceClient()` — używa `SUPABASE_SERVICE_ROLE_KEY` z `.env.local` |

**Uwaga o metodzie**: "Ręczne wywołanie z przeglądarki" → GET → 405. Jeśli Łukasz testował przez przeglądarkę, NIE testował poprawnie tego samego co Supabase (POST). Prawidłowy test: `curl -X POST -H "Authorization: Bearer <CRON_SECRET>" https://twojkapsel.pl/api/cron/sync-redis`.

---

## F. Evidence

### ALB Access Logs — dziś (2026-05-18)

**Pierwsze wywołania pg_net w ALB:** `2026-05-18T08:51:00 UTC` (przed 09:52 cutover — DNS już przestawiony)
**Przed 08:51:** zero pg_net/cron w ALB logach (midnight log = 1 entry, brak pg_net)

**Wzorzec co minutę (powtarzalny od 08:51):**
```
08:51:00.267 POST https://twojkapsel.pl:443//api/cron/sync-redis  308  TID_cd71f0f6  IP 3.172.101.107:54024
08:51:00.372 POST https://twojkapsel.pl:443/api/cron/sync-redis   200  TID_cd71f0f6  IP 3.172.101.107:54024
```

Ten sam TID i IP dla 308→200 = pg_net/0.20.0 **śledzi** 308 Permanent Redirect (metoda POST zachowana, bo 308 ≠ 302).

**Statusy zbiorcze (próbka logów 08:51–11:06):**
- `sync-redis`: co minutę — 1× 308 (`//api/cron/sync-redis`) + 1× 200 (`/api/cron/sync-redis`)
- `process-queue`: analogiczny wzorzec
- `email/process-outbox`: wyłącznie 200 (poprawny URL bez double slash)
- Brak 401, 403, 404, 5xx dla cron endpoints

### CloudWatch Logs (`/maspex/prod/contest-service`)

Logi z 10:05 UTC potwierdzają:
```
[10:05:00] >>> [CACHE-CRON] Start requestu
[10:05:00] >>> [CACHE-CRON] Start requestu
```
Endpoint autoryzowany i uruchomiony (brak "Nieautoryzowana próba dostępu").

### WAF IPSet — Supabase IPv6
- `maspex-prod-supabase-ipv6`: `2a05:d018:135e:16df:0624:8d0e:2886:f540/128`
- Description: "Supabase pg_net outbound IPv6 for twojkapsel.pl cron/email endpoints"
- Był allowlistowany jeszcze przy default_action: block — ale IPv4 traffic Supabase (przez CF edge 3.172.101.x) nie był pokryty

---

## G. Final Classification

**`LIKELY_WAF_BLOCK`** — dla stanu SPRZED cutoveru (który był punktem wyjścia pytania)

**Uzasadnienie:**
- WAF `default_action: block` z allowlistą tylko dla MakoLab IPs i Supabase IPv6
- Supabase pg_net łączył się przez IPv4 (CloudFront edge node 3.172.101.x) — nie był pokryty przez `allow-supabase-ipv6` (który obejmował tylko `2a05:d018:.../128`)
- DNS wskazywał na S3 zasłępkę (drugi bloker) — nawet gdyby WAF przepuścił, nie byłoby API
- Asymetria: Łukasz (MakoLab IP na allowliście) miał dostęp, Supabase nie

**Aktualny stan (2026-05-18, po cutoverze): `RESOLVED`**
- WAF default_action: Allow
- Prawidłowa ścieżka CF → ALB → API
- Endpoint zwraca 200 co minutę

---

## H. Recommended Next Step

**Napraw double-slash URL w konfiguracji Supabase cron dla `sync-redis` i `process-queue`.**

Supabase cron jest skonfigurowany z URL `https://twojkapsel.pl//api/cron/sync-redis` (podwójny slash). Powoduje to 308 redirect przy każdym wywołaniu. Choć pg_net śledzi redirect i finalnie dostaje 200, Supabase dashboard może raportować wywołania jako "nieudane" (pierwsza odpowiedź = 308).

Poprawny URL: `https://twojkapsel.pl/api/cron/sync-redis` (pojedynczy slash).

Weryfikacja w Supabase Dashboard → Project → Edge Functions / Scheduled Functions / `pg_cron` → sprawdź URL we wszystkich cron job definitions dla tego projektu.

**Nie wymaga zmian w AWS — tylko korekta URL w Supabase.**

---

## I. Resources Used

### AWS Resources
- CloudFront E33PUJBAQ533K0 (`get-distribution`)
- CloudFront E17VHHQJ29MVAB (`get-distribution`)
- WAF `maspex-prod-public-app-allowlist` (`get-web-acl --scope CLOUDFRONT --region us-east-1`)
- WAF IPSet `maspex-prod-supabase-ipv6` (`get-ip-set`)
- ALB `maspex-prod` (`describe-listeners`, `describe-rules`, `describe-load-balancer-attributes`)
- Target group `maspex-prod-api-3000` (`describe-target-health`)
- ECS cluster `maspex-prod`, service `maspex-api` (`describe-services`)
- ECS task definition `maspex-prod-api:19` (`describe-task-definition`)
- Secrets Manager `maspex/prod/api` (`get-secret-value` — tylko klucze bez wartości)
- CloudWatch Log Group `/maspex/prod/contest-service` (`filter-log-events`)
- S3 `maspex-prod-access-logs-969209893152` — ALB access logs (`s3 ls`, `s3 cp`)

### App Code
- `app/api/cron/sync-redis/route.ts`
- `app/api/cron/process-queue/route.ts`
- `lib/supabase/client.ts`
- `.gitlab-ci.yml` (mechanizm `dist/.env → .env.local`)
- `next.config.ts`

### Vault Files
- [[maspex-context]] — architektura, profil AWS
- [[cutover-twojkapsel-2026-05-17]] — plan cutoveru, WAF config, zasoby prod
- [[cloudfront-audit-2026-04-26]] — audit CF distributions

---

## Powiązane

- [[cutover-twojkapsel-2026-05-17]]
- [[cloudfront-audit-2026-04-26]]
- [[maspex-context]]
- [[api-secrets]]
