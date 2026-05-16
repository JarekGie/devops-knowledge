---
title: "Diagnoza: CloudFront vs Google social auth — test.twojkapsel.pl"
date: 2026-05-16
tags: [cloudfront, auth, supabase, google-oauth, maspex, prod]
---

# Diagnoza: CloudFront vs Google social auth — test.twojkapsel.pl

## Objaw

Logowanie Google social auth nie działa poprawnie na `test.twojkapsel.pl` PROD:
- konto się tworzy ✓
- token „się dodaje" ✓
- aplikacja zachowuje się jakby użytkownik nie był zalogowany ✗

## Werdykt

**`CLOUDFRONT_LIKELY_OK`** — CloudFront nie psuje flow auth.

**Root cause: aplikacja hardcode'uje SITE_URL jako `test.kapsel.makotest.pl`** — domenę NXDOMAIN (nie istnieje w DNS). Po OAuth callback app redirectuje użytkownika na martwą domenę → sesja nigdy nie trafia do przeglądarki.

## Kontekst techniczny

```
user → Cloudflare (klienta) → test.twojkapsel.pl → CF E33PUJBAQ533K0 → ALB maspex-prod → maspex-api ECS
```

App używa **Supabase PKCE flow**, nie NextAuth.js. Ścieżka callbacku: `/auth/callback`.

## Dowód (HTTP test)

```
GET /auth/callback?code=test&state=xyz
→ HTTP 307 Location: https://test.kapsel.makotest.pl/auth/error
  ?error=PKCE%20code%20verifier%20not%20found%20in%20storage
```

`dig test.kapsel.makotest.pl` → **NXDOMAIN**

## Dlaczego CF jest czysty

| Ryzyko | Status | Dowód |
|---|---|---|
| Caching auth responses | ✓ BRAK | CachingDisabled (TTL=0), `x-cache: Miss` potwierdzony |
| Cookie stripping | ✓ BRAK | AllViewer ORP: `CookieBehavior: all` |
| Query string stripping | ✓ BRAK | AllViewer ORP: `QueryStringBehavior: all` |
| Behavior przechwytujący auth | ✓ BRAK | Brak behavior dla `/auth/*` — default behavior |
| Host header mismatch | ✓ BRAK | AllViewer forwarduje `Host: test.twojkapsel.pl`, ALB rule priority=100 matchuje |
| Response cookie modification | ✓ BRAK | Brak Response Headers Policy |

## CF config summary (E33PUJBAQ533K0)

- **Default behavior**: CachingDisabled + AllViewer (all headers/cookies/query strings)
- **AllowedMethods**: wszystkie 7 (GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS)
- **Behaviors**: `/api/slogan`, `/_next/image*`, `/_next/static/*`, `/landing/*`, `/favicon.ico`, `/email/*` — wyłącznie statyczne/public ścieżki, BRAK behavior dla auth
- **WAF**: `DefaultAction: Block` — allowlist: `91.233.19.251/32`, `195.117.107.110/32`, Supabase IPv6

## Root cause (aplikacja)

Env vars są baked-in do Docker image podczas build w CI/CD:
```
Vault path: bss/maspex-kapsel/coreapp-prod/
```
`NEXT_PUBLIC_SITE_URL` (lub `NEXT_PUBLIC_APP_URL`) ustawiony na `test.kapsel.makotest.pl` — stara staging domena, która:
- Nie ma DNS (NXDOMAIN)
- Nie jest obecną domeną PROD

## Fix

### 1. Vault secrets (obowiązkowy rebuild po zmianie)
```
bss/maspex-kapsel/coreapp-prod/
  NEXT_PUBLIC_SITE_URL = https://test.twojkapsel.pl   # było: test.kapsel.makotest.pl
  # (sprawdź wszystkie klucze z URL domeną)
```
Po zmianie: **rebuild + redeploy** — `NEXT_PUBLIC_*` są kompilowane w bundle JS.

### 2. Supabase Console (Authentication → URL Configuration)
```
Site URL: https://test.twojkapsel.pl
Redirect URLs: https://test.twojkapsel.pl/auth/callback
```

### 3. Google Cloud Console (OAuth Credentials)
Dodaj `https://test.twojkapsel.pl/auth/callback` do Authorized redirect URIs.

### 4. WAF (jeśli ruch przez Cloudflare klienta)
Jeśli użytkownicy dochodzą przez Cloudflare proxy klienta, WAF widzi Cloudflare edge IPs, nie user IPs. Obecna allowlista (2 IP /32) blokuje cały ruch przez Cloudflare. Należy:
- Dodać Cloudflare IP ranges do allowlisty, lub
- Przestawić WAF na managed rules + rate limiting

## ALB routing (potwierdzony)
```
Priority=20:  path=/bots/* + host=test.twojkapsel.pl → maspex-bot TG
Priority=100: host=test.twojkapsel.pl                → maspex-api-3000 TG  ← API/coreapp
Priority=200: host=kapsel-prod.makotest.pl           → maspex-admin-3000 TG
Default:      fixed-response (block)
```

## Zasoby użyte w diagnozie

- CloudFront: `E33PUJBAQ533K0` (get-distribution, get-cache-policy, get-origin-request-policy)
- WAF: `5ee5cb12-f6ee-4cf4-b66f-02ba3fc8d2eb` + IP sets
- ECS: cluster `maspex-prod`, service `maspex-api`, task-def `maspex-prod-api:8`
- ALB: `maspex-prod` HTTPS listener rules
- HTTP edge tests: 12+ ścieżek na `test.twojkapsel.pl`
- Terraform: `infra-maspex/envs/prod/terraform.tfvars`, `main.tf`
- CI/CD: `maspex-cicd/core-app/core-app.yml`
