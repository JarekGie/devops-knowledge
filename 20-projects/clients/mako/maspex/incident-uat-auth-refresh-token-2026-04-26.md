---
tags: [#incident, #maspex, #uat, #supabase, #auth]
date: 2026-04-26
---

# Incydent UAT: Invalid Refresh Token — 2026-04-26 17:42:55 UTC

## Objaw

```
2026-04-26 17:42:55: Error [AuthApiError]: Invalid Refresh Token: Refresh Token Not Found
  code: 'refresh_token_not_found', status: 400
```

Błąd w logach ECS (`/maspex/uat/contest-service`, kontenery maspex-api).

## Zakres

- Środowisko: **UAT** (`maspex-uat`, `kapsel.makotest.pl`)
- Dotyczyło: 2 z 6 kontenerów maspex-api (`c6604ec26c3d`, `5e23d367db7b`)
- Czas: dokładnie **17:42:55 UTC**, jednorazowo (8 eventów = 2×double-logging × 2 kontenery)
- Brak powtórzeń w całym dniu

## Szybka diagnoza

**Charakter**: aplikacyjny / Supabase Auth-level. Nie CloudFront, nie ALB, nie deploy.

**Co się stało**: Next.js middleware (SSR) próbował odświeżyć sesję Supabase dla użytkownika, którego refresh_token nie istniał już w bazie Supabase. Błąd złapany przez middleware — brak 4xx na ALB. Użytkownik dostał redirect do logowania.

**Czemu 2 kontenery jednocześnie**: przeglądarka wysłała kilka równoległych SSR requestów przy załadowaniu strony, load balancer rozdzielił je na 2 kontenery — oba próbowały refreshować ten sam invalid token.

## Timeline

| Czas (UTC) | Zdarzenie |
|---|---|
| 15:03 | Wdrożona zmiana CloudFront (`/api/slogan` cache policy) |
| 17:23–17:25 | Deploy maspex-api, steady state |
| 17:42:55 | **8× AuthApiError: refresh_token_not_found** |
| 17:43+ | Normalna praca, zero kolejnych błędów auth |

## Root cause

Refresh token użytkownika testowego był unieważniony w Supabase (typowe przyczyny: ponowne logowanie, wylogowanie z innej zakładki, rotacja tokenu, admin signOut).

## CloudFront — wykluczone

Zmiana `/api/slogan` behavior (15:03 UTC, 2,5h wcześniej):
- PathPattern = exact `/api/slogan` (bez wildcard) — nie dotyka auth endpoints
- Default behavior: `Managed-CachingDisabled` + `Managed-AllViewer` — wszystkie cookies/headers forwarded
- Auth call server-to-Supabase odbywa się bezpośrednio (nie przez CF)

## Co wykluczono

- Restarty ECS w oknie incydentu — brak
- Deploy w momencie incydentu — deploy zakończony 17 min wcześniej
- 4xx/5xx na ALB — zero
- Wpływ `/api/slogan` CF behavior — nie możliwe (exact match)
- Trwała awaria — jednorazowy event, nie powtórzy się automatycznie

## Następne kroki

1. Supabase Dashboard → Auth → sprawdź sesje użytkownika o 17:42 UTC
2. `SELECT * FROM auth.sessions WHERE updated_at BETWEEN '2026-04-26 17:40:00Z' AND '2026-04-26 17:45:00Z'`
3. Sprawdź czy CACHE-CRON korzysta z service role key (nie z sesji użytkownika)
4. Rozważ alert CW na `AuthApiError` w `contest-service` — jeśli zacznie pojawiać się regularnie, to problem CACHE-CRON

## Log groups i komendy

- Log group: `/maspex/uat/contest-service` (maspex-api loguje tutaj — naming misleading)
- CF distribution: `E3J76RNXIE2YIG`
- Cluster: `maspex-uat`

```bash
# Szybkie sprawdzenie auth błędów
aws --profile maspex-cli --region eu-west-1 logs filter-log-events \
  --log-group-name "/maspex/uat/contest-service" \
  --start-time <epoch_ms> --end-time <epoch_ms> \
  --filter-pattern "AuthApiError"
```
