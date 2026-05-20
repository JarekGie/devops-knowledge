---
title: "PROD E2E Test — CloudFront change — test.twojkapsel.pl + kapsel-prod.makotest.pl"
date: 2026-05-15
type: e2e-test-report
environment: prod
analyst: Jarosław Gołąb
---

## A. Executive Summary

| Pytanie | Odpowiedź |
|---------|-----------|
| `test.twojkapsel.pl` działa E2E poprawnie? | **TAK** — API PROD odpowiada HTTP 200, cały łańcuch poprawny |
| `kapsel-prod.makotest.pl` działa E2E poprawnie? | **TAK** — admin panel PROD odpowiada HTTP 200, cały łańcuch poprawny |
| Obie domeny trafiają wyłącznie do PROD? | **TAK** — potwierdzone na poziomie DNS, CF, ALB, TG, ECS |
| Wykryto mix z UAT? | **NIE** — izolacja potwierdzona wielowarstwowo |
| Problemy? | **TAK** — `maspex-bot` PROD jest unhealthy → 502 na `/bots/*` |

---

## B. DNS / TLS result

### test.twojkapsel.pl

| Właściwość | Wartość |
|-----------|---------|
| Rekord DNS | CNAME → `d1w5bz7itj42sz.cloudfront.net` |
| Rozwiązane IP | 18.66.233.121 / .64 / .71 / .95 (CloudFront edge) |
| CloudFront distribution | `E33PUJBAQ533K0` ✅ |
| TTL CNAME | 189s |
| Cert CN | `CN=test.twojkapsel.pl` |
| SAN | `DNS:test.twojkapsel.pl, DNS:www.test.twojkapsel.pl` |
| Cert ARN | `caed9d07-81d1-4069-9947-2aeb2d2dea08` (us-east-1) |
| Verify return code | 0 (ok) ✅ |
| CF PoP | WAW51-P1 (Warsaw) |

### kapsel-prod.makotest.pl

| Właściwość | Wartość |
|-----------|---------|
| Rekord DNS | CNAME → `dfx1ac92hj3uw.cloudfront.net` |
| Rozwiązane IP | 18.244.146.17 / .77 / .33 / .48 (CloudFront edge) |
| CloudFront distribution | `E32AZKJ5SJSDSV` ✅ |
| TTL CNAME | 3600s |
| Cert CN | `CN=kapsel-prod.makotest.pl` |
| SAN | `DNS:kapsel-prod.makotest.pl, DNS:www.kapsel-prod.makotest.pl` |
| Verify return code | 0 (ok) ✅ |
| CF PoP | WAW51-P4 (Warsaw) |

---

## C. CloudFront result

| Distribution | ID | DomainName CF | Aliasy | Cert | Origin | Status |
|---|---|---|---|---|---|---|
| API PROD | `E33PUJBAQ533K0` | `d1w5bz7itj42sz.cloudfront.net` | `test.twojkapsel.pl`, `www.test.twojkapsel.pl` | `caed9d07` (us-east-1) | PROD ALB | Deployed ✅ |
| Admin PROD | `E32AZKJ5SJSDSV` | `dfx1ac92hj3uw.cloudfront.net` | `kapsel-prod.makotest.pl` | `369af310` (us-east-1) | PROD ALB | Deployed ✅ |
| API UAT (referencja) | `E3J76RNXIE2YIG` | `d3p408gzqcntg6.cloudfront.net` | `kapsel.makotest.pl` | — | UAT ALB | ≠ PROD ALB ✅ |

Obydwie dystrybucje PROD wskazują na ten sam PROD ALB:
`maspex-prod-1795571755.eu-west-1.elb.amazonaws.com`

UAT CF wskazuje na: `maspex-uat-1361582173.eu-west-1.elb.amazonaws.com` — **kompletnie oddzielny ALB** ✅

---

## D. ALB / TG / ECS routing result

**ALB PROD:** `maspex-prod` (ARN: `app/maspex-prod/e90292a1ad614fc5`) — **active** ✅

**Listener HTTP:80** → redirect 301 HTTPS (wszystkie hosty) ✅

**Listener HTTPS:443 — reguły routingu:**

| Priorytet | Host | Path | Target Group | TG health |
|-----------|------|------|-------------|-----------|
| 20 | `test.twojkapsel.pl`, `www.test.twojkapsel.pl` | `/bots/*` | `maspex-prod-bot` | **UNHEALTHY** ❌ |
| 100 | `test.twojkapsel.pl`, `www.test.twojkapsel.pl` | `*` | `maspex-prod-api-3000` | 9/9 healthy ✅ |
| 200 | `kapsel-prod.makotest.pl` | `*` | `maspex-prod-admin-3000` | 1/1 healthy ✅ |
| default | — | — | fixed-response | nie kieruje do UAT ✅ |

**ECS PROD cluster** (`maspex-prod`):

| Service | Desired | Running | Pending | Status | Task Definition |
|---------|---------|---------|---------|--------|-----------------|
| `maspex-api` | 9 | 9 | 0 | ACTIVE ✅ | `maspex-prod-api:4` |
| `maspex-admin-panel` | 1 | 1 | 0 | ACTIVE ✅ | `maspex-prod-admin-panel:3` |
| `maspex-bot` | 1 | 1 | 0 | ACTIVE ⚠️ | `maspex-prod-bot:2` |

**Uwaga bot:** ECS raportuje `running: 1`, ale w TG task jest unhealthy i właśnie jest deregistrowany → service będzie próbował zarejestrować nowy → prawdopodobny crash-loop (`failedTasks: 16`).

---

## E. Endpoint test results

| Domena | Endpoint | Expected | Actual | Status | Uwagi |
|--------|----------|----------|--------|--------|-------|
| `test.twojkapsel.pl` | `/` | HTTP 200, HTML, PROD | HTTP 200, `text/html`, Next.js | ✅ PASS | `via: CloudFront`, PoP WAW51 |
| `test.twojkapsel.pl` | `/api/health` | HTTP 200, JSON, `status: ok` | HTTP 200, `{"success":true,"status":"ok","service":"next-core-app"}` | ✅ PASS | uptime 2h 22m — serwis stabilny |
| `kapsel-prod.makotest.pl` | `/` | HTTP 200, HTML, admin panel | HTTP 200, `text/html`, Next.js, `x-powered-by: Next.js` | ✅ PASS | `via: CloudFront`, PoP WAW51 |
| `kapsel-prod.makotest.pl` | `/api/health` | N/A (admin) | HTTP 307 → `/auth/login` | ✅ OK | Admin panel przekierowuje niezalogowanych — poprawne zachowanie |
| `test.twojkapsel.pl` | `/bots/test` | routing do bot TG | HTTP 502, `Error from cloudfront` | ❌ FAIL | Bot TG unhealthy — brak zdrowych targets |

---

## F. Cross-environment isolation verdict

**POTWIERDZONE: brak mixu PROD/UAT.**

Dowody wielowarstwowe:

1. **DNS level**: obie PROD domeny CNAME na CF domains należące do PROD distributions. `test.twojkapsel.pl` → `d1w5bz7itj42sz.cloudfront.net` ≠ UAT CF `d3p408gzqcntg6.cloudfront.net`

2. **CloudFront level**: UAT distribution `E3J76RNXIE2YIG` ma alias tylko dla `kapsel.makotest.pl`. Nie zawiera `test.twojkapsel.pl` ani `kapsel-prod.makotest.pl`.

3. **ALB level**: PROD ALB DNS = `maspex-prod-1795571755.eu-west-1.elb.amazonaws.com`. UAT ALB DNS = `maspex-uat-1361582173.eu-west-1.elb.amazonaws.com`. Kompletnie osobne ALBy.

4. **ALB routing rules — UAT**: reguły UAT obsługują wyłącznie `kapsel.makotest.pl` i `kapsel-admin-uat.makotest.pl`. Żadna reguła UAT nie zawiera PROD domen.

5. **Target group level**: PROD TG names zawierają `-prod-`, UAT TG names zawierają `-uat-`. Bez overlap.

6. **ECS level**: cluster `maspex-prod` vs cluster `maspex-uat`. Task definitions: `maspex-prod-api:4` vs `maspex-uat-*`. Izolacja kompletna.

---

## G. Issues found

### ISSUE-1: maspex-bot PROD unhealthy — 502 na `/bots/*`

| Pole | Wartość |
|------|---------|
| Severity | **HIGH** (dla funkcjonalności botów) |
| Scope | Ograniczony: tylko `/bots/*` ścieżki na `test.twojkapsel.pl` |
| Gdzie | ECS `maspex-bot` PROD / TG `maspex-prod-bot` |
| Objaw | HTTP 502 na `https://test.twojkapsel.pl/bots/*` |
| Dowód | TG target `10.44.2.46:8080` — `unhealthy`, `Target.FailedHealthChecks`; `10.44.3.181:8080` — draining |
| Przyczyna | Health check `/health` na porcie 8080 zwraca błąd lub nie odpowiada. `failedTasks: 16` w bieżącym deploymencie — crash-loop. |
| Impact na API | **BRAK** — API działa poprawnie (TG `maspex-prod-api-3000` 9/9 healthy) |
| Impact na admin | **BRAK** — admin działa poprawnie (TG `maspex-prod-admin-3000` 1/1 healthy) |
| Co trzeba zrobić | Zbadać logi `maspex-bot` PROD (`/maspex/prod/bot`?), ustalić dlaczego `/health` na porcie 8080 nie przechodzi. Sprawdzić task definition `maspex-prod-bot:2` — czy port 8080 jest właściwy, czy serwis startuje poprawnie. |

### ISSUE-2 (minor): cert admin — różny od API cert

Admin distribution używa innego certu (`369af310`) niż API (`caed9d07`). To jest poprawne — każdy cert jest dla innej domeny. Nie jest to problem, ale warto śledzić daty wygaśnięcia obydwu.

---

## H. Final verdict

```
READY_WITH_RISKS
```

**Uzasadnienie:**

- `test.twojkapsel.pl` → maspex-api PROD: **READY** ✅ — cały łańcuch edge-to-app działa poprawnie
- `kapsel-prod.makotest.pl` → maspex-admin-panel PROD: **READY** ✅ — cały łańcuch działa poprawnie
- Izolacja od UAT: **POTWIERDZONA** ✅ — brak mixu na żadnej warstwie
- `/bots/*` path: **NOT READY** ❌ — bot PROD ma crash-loop, 502 na wszystkich `/bots/*` requestach

Ruch API i admin można bezpiecznie puścić. Bot wymaga naprawy przed uruchomieniem funkcjonalności botów.

---

## I. Evidence

### Komendy użyte do weryfikacji

```bash
# DNS
dig test.twojkapsel.pl
dig kapsel-prod.makotest.pl

# TLS
openssl s_client -connect test.twojkapsel.pl:443 -servername test.twojkapsel.pl
openssl s_client -connect kapsel-prod.makotest.pl:443 -servername kapsel-prod.makotest.pl

# HTTP headers
curl -sI https://test.twojkapsel.pl/
curl -sI https://kapsel-prod.makotest.pl/

# CloudFront distributions
aws cloudfront get-distribution --id E33PUJBAQ533K0 --profile maspex-cli
aws cloudfront get-distribution --id E32AZKJ5SJSDSV --profile maspex-cli
aws cloudfront get-distribution --id E3J76RNXIE2YIG --profile maspex-cli  # UAT cross-check

# ALB
aws elbv2 describe-load-balancers --profile maspex-cli --region eu-west-1 \
  --query 'LoadBalancers[?contains(LoadBalancerName,`maspex-prod`)]'
aws elbv2 describe-listeners --load-balancer-arn <PROD_ALB_ARN> --profile maspex-cli --region eu-west-1
aws elbv2 describe-rules --listener-arn <HTTPS_443> --profile maspex-cli --region eu-west-1
aws elbv2 describe-rules --listener-arn <UAT_HTTPS_443> --profile maspex-cli --region eu-west-1  # cross-check

# Target group health
aws elbv2 describe-target-health --target-group-arn <maspex-prod-api-3000>
aws elbv2 describe-target-health --target-group-arn <maspex-prod-bot>
aws elbv2 describe-target-health --target-group-arn <maspex-prod-admin-3000>

# ECS PROD
aws ecs describe-services --cluster maspex-prod \
  --services maspex-api maspex-bot maspex-admin-panel \
  --profile maspex-cli --region eu-west-1

# Endpoint tests
curl -sv https://test.twojkapsel.pl/
curl -sv https://test.twojkapsel.pl/api/health
curl -sv https://test.twojkapsel.pl/bots/test
curl -sv https://kapsel-prod.makotest.pl/
curl -sv https://kapsel-prod.makotest.pl/api/health
```

### Zasoby zweryfikowane

| Zasób | ARN / ID | Wynik |
|-------|----------|-------|
| CF API PROD | `E33PUJBAQ533K0` | ✅ |
| CF Admin PROD | `E32AZKJ5SJSDSV` | ✅ |
| CF API UAT | `E3J76RNXIE2YIG` | ✅ (brak PROD alias) |
| ALB PROD | `app/maspex-prod/e90292a1ad614fc5` | ✅ |
| ALB UAT | `app/maspex-uat/68317764a66425bd` | ✅ (brak PROD reguł) |
| TG `maspex-prod-api-3000` | `f1c1169c3a1a7125` | ✅ 9/9 healthy |
| TG `maspex-prod-bot` | `d99e1935c0df1072` | ❌ 0 healthy |
| TG `maspex-prod-admin-3000` | `ea2d13909032b37f` | ✅ 1/1 healthy |
| ECS cluster `maspex-prod` | — | ✅ |
| ECS `maspex-api` PROD | td `maspex-prod-api:4` | ✅ 9/9 |
| ECS `maspex-admin-panel` PROD | td `maspex-prod-admin-panel:3` | ✅ 1/1 |
| ECS `maspex-bot` PROD | td `maspex-prod-bot:2` | ❌ crash-loop |
