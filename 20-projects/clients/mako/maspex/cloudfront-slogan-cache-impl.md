---
tags: [maspex, aws, cloudfront, terraform, cache, #decision]
date: 2026-04-26
status: applied, live
---

# CloudFront cache dla /api/slogan — implementacja

Konto: 969209893152 | Region: eu-west-1 | Dystrybucja: E3J76RNXIE2YIG (kapsel.makotest.pl)

## Objaw / problem

`GET /api/slogan` to publiczny endpoint z listą haseł. Brak cache behavior — 100% ruchu dociera do originu (Next.js ECS). Przy load testach powoduje saturację ECS/ALB. Cel: zatrzymać większość ruchu na CloudFront.

## Stan przed zmianą

- Dystrybucja E3J76RNXIE2YIG miała 4 ordered behaviors: `/_next/image*`, `/_next/static/*`, `/landing/*`, `/favicon.ico`
- `/api/slogan` obsługiwany przez **default behavior** → Managed-CachingDisabled (4135ea2d) → 0 cache
- Brak `/api/slogan` behavior w Terraform i w live

## Wprowadzone zmiany

### Pliki zmienione

**`terraform/modules/cloudfront-site/variables.tf`** — dodano zmienną `api_cache_behaviors` (linia 128+):
```hcl
variable "api_cache_behaviors" {
  type = list(object({
    path_pattern            = string
    min_ttl                 = number
    default_ttl             = number
    max_ttl                 = number
    cache_key_query_strings = list(string)
  }))
  default = []
}
```

**`terraform/modules/cloudfront-site/main.tf`** — dodano (przed blokiem `aws_cloudfront_distribution`):
- `aws_cloudfront_cache_policy.api` (for_each po path_pattern) — whitelist QS: page, sortBy, search; brak cookies; brak headers
- `aws_cloudfront_origin_request_policy.api` (count=1) — brak cookies, brak headers, all QS do originu
- dynamic `ordered_cache_behavior` dla api_cache_behaviors — umieszczony PRZED image_optimizer i static_paths

**`terraform/envs/uat/main.tf`** — w module `cloudfront_site_api` dodano:
```hcl
api_cache_behaviors = [
  {
    path_pattern            = "/api/slogan"
    min_ttl                 = 0
    default_ttl             = 60
    max_ttl                 = 600
    cache_key_query_strings = ["page", "sortBy", "search"]
  }
]
```

### Nowe zasoby AWS (z planu)

| Zasób | Nazwa |
|---|---|
| `aws_cloudfront_cache_policy.api["/api/slogan"]` | `kapsel-makotest-pl-api--api-slogan` |
| `aws_cloudfront_origin_request_policy.api[0]` | `kapsel-makotest-pl-api-no-cookies-all-qs` |
| update `aws_cloudfront_distribution.this[0]` (E3J76RNXIE2YIG) | nowy ordered behavior `/api/slogan` jako precedence 0 |

### Cache policy szczegóły

| Parametr | Wartość | Uzasadnienie |
|---|---|---|
| `min_ttl` | 0 | Respektuje `s-maxage` z aplikacji — nie wymusza cache |
| `default_ttl` | 60 | Fallback gdy aplikacja nie poda Cache-Control |
| `max_ttl` | 600 | Ceiling dla stale-while-revalidate |
| `query_string_behavior` | whitelist | Tylko `page`, `sortBy`, `search` tworzą różne cache entries |
| `cookie_behavior` | none | Endpoint publiczny, bez personalizacji |
| `header_behavior` | none | Brak Authorization, brak session headers |

### Origin request policy szczegóły

| Parametr | Wartość | Uzasadnienie |
|---|---|---|
| `cookie_behavior` | none | Nie forwarduj cookies do originu |
| `header_behavior` | none | Nie forwarduj Authorization ani innych |
| `query_string_behavior` | all | Origin widzi pełne QS (filtry paginacji) |

## Pattern wyboru `/api/slogan` (bez wildcard)

CloudFront wildcard `*` dopasowuje WSZYSTKO włącznie ze slashem. Użycie `/api/slogan*` objęłoby też `/api/slogan/vote`, `/api/slogan/submit` — niebezpieczne (mutujące endpointy w cache).

**Decyzja:** `path_pattern = "/api/slogan"` (exact match bez wildcard). Dopasowuje tylko `/api/slogan` i `/api/slogan?...`. Nie obejmuje sub-ścieżek.

## Wynik terraform plan

```
Plan: 2 to add, 1 to change, 0 to destroy.
```

- 2 create: cache_policy.api + origin_request_policy.api
- 1 update in-place: distribution E3J76RNXIE2YIG (nowy behavior)
- 0 destroy: żadnych existing zasobów nie usuwa

Plan addytywny i bezpieczny.

## Kolejność behaviors po wdrożeniu

1. `/api/slogan` — NOWY — cache policy z whitelist QS
2. `/_next/image*` — bez zmian
3. `/_next/static/*` — bez zmian
4. `/landing/*` — bez zmian
5. `/favicon.ico` — bez zmian
6. `*` (default) — Managed-CachingDisabled, bez zmian

## Weryfikacja po wdrożeniu

```bash
# Hit test — pierwsze żądanie (Miss)
curl -sI "https://kapsel.makotest.pl/api/slogan?page=1&sortBy=votes_desc" | grep -i "x-cache"
# Oczekiwane: X-Cache: Miss from cloudfront

# Drugie żądanie (Hit)
curl -sI "https://kapsel.makotest.pl/api/slogan?page=1&sortBy=votes_desc" | grep -i "x-cache"
# Oczekiwane: X-Cache: Hit from cloudfront

# Różne QS = różne cache entries (powinno być Miss pierwsze wywołanie)
curl -sI "https://kapsel.makotest.pl/api/slogan?page=2&sortBy=votes_desc" | grep -i "x-cache"
# Oczekiwane: Miss (nowy cache entry)

# Sub-path NIE objęty cache (Vote — mutujący endpoint)
curl -sI -X POST "https://kapsel.makotest.pl/api/slogan/vote" | grep -i "x-cache"
# Oczekiwane: Miss + brak cache (trafia do default behavior → CachingDisabled)

# Dodatkowy QS spoza whitelist — nie wpływa na cache key
curl -sI "https://kapsel.makotest.pl/api/slogan?page=1&sortBy=votes_desc&foo=bar" | grep -i "x-cache"
# Oczekiwane: Hit (foo=bar ignorowany w cache key)
```

## Ryzyka i ograniczenia

- Skuteczność cache zależy od aplikacji: jeśli `/api/slogan` nie zwraca `Cache-Control: s-maxage=...` — TTL = default_ttl (60s)
- Nie cache'uje jeśli aplikacja zwróci `Cache-Control: no-store` lub `private`
- Jeśli `/api/slogan/` (z trailing slash) istnieje — potrzebny osobny behavior
- Query strings spoza whitelist (`foo`, `debug`) są ignorowane w cache key — ale przekazywane do originu (przez origin request policy all QS)
- Zmiana jest dla UAT. Dla preprod — osobna implementacja gdy gotowi

## Regresja po wdrożeniu — 502 fix (2026-04-26)

Po apply oryginalnej implementacji pojawił się `502 Bad Gateway` na `GET /api/slogan?page=1&sortBy=newest`.

**Root cause:** Custom ORP miał `header_behavior = "none"` — CloudFront nie forwardował nagłówka `Host` do originu (ALB). Bez `Host`, CloudFront używał domeny originu (`maspex-uat-1361582173.eu-west-1.elb.amazonaws.com`) jako SNI dla TLS. Certyfikat ALB jest wystawiony na `kapsel.makotest.pl` — mismatch → TLS handshake failure → 502.

**Fix:** Zmiana `header_behavior = "none"` na `whitelist` z `["Host"]` w `aws_cloudfront_origin_request_policy.api` (`modules/cloudfront-site/main.tf`). Cache policy bez zmian.

**Lekcja:** Dla ALB z `https-only` i host-based routing, ORP MUSI forwardować `Host`. Wystarczy whitelist z `["Host"]` — nie trzeba Managed-AllViewer. Cache key jest kontrolowany niezależnie przez cache policy.

**Weryfikacja po apply:**
```
HTTP/2 200  x-cache: Miss from cloudfront   (1. request)
HTTP/2 200  x-cache: Hit from cloudfront    (2. request)
```

Apply: 2026-04-26. Apply time: <5 sekund. 0 destroy. Propagacja CF natychmiastowa.
