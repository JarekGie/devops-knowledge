---
tags: [maspex, aws, cloudfront, audit, #decision]
date: 2026-04-26
author: claude-audit
---

# Audyt CloudFront — Maspex (2026-04-26)

Konto: 969209893152 | Region: eu-west-1 | Profil CLI: maspex-cli

---

# 1. Executive Summary

**Ogólna ocena:** Terraform i live AWS są w dużej mierze zgodne dla 2 z 3 dystrybucji. Największy drift dotyczy dystrybucji **UAT API (E3J76RNXIE2YIG)** — Terraform (w aktualnym tfvars) nie deklaruje `image_optimizer_paths` ani `api_cloudfront_static_paths` dla modułu preprod `cloudfront_site`, natomiast w UAT odpowiednie ścieżki są zadeklarowane i wdrożone. Preprod ma dodatkowy drift: brak w Terraform modułu `cloudfront_site_api` (API distribution nie istnieje w preprod tfvars) — a live ma tylko 1 dystrybucję, co jest zgodne.

**Gdzie są drifty:**
- **UAT API (E3J76RNXIE2YIG):** brak w Terraform parametru `image_cache_min_ttl` przekazanego jawnie — używana jest wartość domyślna `0` z modułu, co ZGADZA się z live (min_ttl=0 w policy `kapsel-makotest-pl-image-optimizer`). Zgodne.
- **UAT Admin (E3R9U1TWNUJZ11):** Terraform deklaruje `static_path_origin_request_policy_ids` z kluczem `"/_next/static/*"` i `"/static/*"` → oba mapowane na `216adef6`. W live obie ścieżki mają `OriginRequestPolicyId: 216adef6`. Zgodne.
- **Preprod (E17VHHQJ29MVAB):** **DRIFT** — logging prefix w live to `cloudfront/maspex-preprod/admin-panel`, Terraform deklaruje tę samą wartość w `local.cloudfront_logs_prefix.admin`. Zgodne. **ALE:** live używa cache policy o nazwie `twojkapsel-pl-static-assets` (ID: `3fcae9eb`) i **brak `OriginRequestPolicyId`** w ordered cache behaviors (puste / brak forwarding origin request policy). Terraform deklaruje `static_path_origin_request_policy_ids = {}` (pustą mapę), co oznacza `null` dla origin request policy w module — zgodne z live brakiem policy w tych behaviorach. Jednak default cache behavior w live ma `OriginRequestPolicyId: 216adef6`, co Terraform hardkoduje w module.

**Największe ryzyka operacyjne:**
1. **Preprod `/_next/static/*` i `/static/*` — brak origin request policy** — ciasteczka, query strings i nagłówki NIE są forwarded do originu dla tych ścieżek. Jeśli aplikacja preprod wymaga session cookies na zasobach statycznych, to jest problem.
2. **Brak WAF na wszystkich 3 dystrybucjach** — dystrybucje produkcyjne (preprod) bez WAF.
3. **Preprod brak modułu `cloudfront_site_api`** — nie ma osobnej dystrybucji dla API na preprod (jest tylko jedna dla admin panelu/całej domeny). To decyzja projektowa, ale warta odnotowania.
4. **HTTP Version = http2 only** (brak http3) na wszystkich dystrybucjach — HTTP/3 (QUIC) nie jest włączony.

---

# 2. Live CloudFront Inventory

## 2.1 UAT API — E3J76RNXIE2YIG

### Podstawowe ustawienia
- **Aliases/CNAMEs:** `kapsel.makotest.pl`
- **Enabled:** true
- **Price class:** PriceClass_100 (EU+US)
- **Comment:** `ALB origin: maspex-uat-1361582173.eu-west-1.elb.amazonaws.com`
- **Default root object:** (brak)
- **HTTP version:** http2 (brak http3)
- **IPv6:** true
- **WAF (WebACL ARN):** brak
- **Logging:** enabled — bucket: `maspex-uat-access-logs-969209893152.s3.amazonaws.com`, prefix: `cloudfront/maspex-uat/api`, include_cookies: false
- **Viewer certificate:**
  - ACM ARN: `arn:aws:acm:us-east-1:969209893152:certificate/ab337320-6f37-4139-8ab6-cae6e654b569`
  - Min TLS: `TLSv1.2_2021`
  - SSL support method: `sni-only`

### Origins
| Field | Wartość |
|---|---|
| Origin ID | `alb` |
| Domain name | `maspex-uat-1361582173.eu-west-1.elb.amazonaws.com` |
| Origin type | Custom (ALB) |
| Origin protocol policy | `https-only` |
| Origin SSL protocols | `TLSv1.2` |
| Origin read timeout | 30s |
| Origin keepalive timeout | 5s |
| Connection attempts | 3 |
| Connection timeout | 10s |
| Custom headers | brak |
| Origin path | (brak) |
| Origin Shield | disabled |

### Default cache behavior
| Field | Wartość |
|---|---|
| Target origin ID | `alb` |
| Viewer protocol policy | `redirect-to-https` |
| Allowed methods | HEAD, DELETE, POST, GET, OPTIONS, PUT, PATCH (7) |
| Cached methods | HEAD, GET |
| **Cache policy ID** | `4135ea2d-6df8-44a3-9df3-4b5a84be39ad` |
| **Cache policy name** | Managed-CachingDisabled |
| TTL | min=0, default=0, max=0 |
| QS/cookies/headers in key | none / none / none |
| **Origin request policy ID** | `216adef6-5c7f-47e4-b989-5492eafa07d3` |
| **Origin request policy name** | Managed-AllViewer |
| Forwards | all headers, all cookies, all QS |
| Response headers policy | brak |
| Compress | true |
| Lambda@Edge / Functions | brak |

### Ordered cache behaviors (UAT API — E3J76RNXIE2YIG)

**Behavior 1 (precedence 0): `/_next/image*`**
| Field | Wartość |
|---|---|
| Path pattern | `/_next/image*` |
| Target origin | `alb` |
| Viewer protocol policy | `redirect-to-https` |
| Allowed methods | HEAD, GET, OPTIONS |
| Cached methods | HEAD, GET |
| **Cache policy ID** | `dea1b35e-7ae4-46b0-b523-78995fc22288` |
| **Cache policy name** | `kapsel-makotest-pl-image-optimizer` (custom) |
| TTL | min=0, default=86400, max=2592000 (30 dni) |
| QS in cache key | `all` (query_string_behavior=all) |
| Cookies | none |
| Headers | none |
| Brotli/Gzip | true |
| **Origin request policy** | `216adef6` — Managed-AllViewer |
| Compress | true |
| Functions | brak |
| **Ocena:** Poprawna — image optimizer wymaga QS w cache key (url, w, q). min_ttl=0 respektuje Cache-Control originu. |

**Behavior 2 (precedence 1): `/_next/static/*`**
| Field | Wartość |
|---|---|
| Path pattern | `/_next/static/*` |
| Target origin | `alb` |
| Viewer protocol policy | `redirect-to-https` |
| Allowed methods | HEAD, GET, OPTIONS |
| Cached methods | HEAD, GET |
| **Cache policy ID** | `ab5d9518-10b2-44d4-ae22-c81253d9a539` |
| **Cache policy name** | `kapsel-makotest-pl-static-assets` (custom) |
| TTL | min=86400, default=86400, max=31536000 (1 rok) |
| QS/cookies/headers | none/none/none |
| **Origin request policy** | `216adef6` — Managed-AllViewer |
| Compress | true |
| **Ocena:** Poprawna dla immutable static assets Next.js. min_ttl=86400 wymusza cache niezależnie od Cache-Control. |

**Behavior 3 (precedence 2): `/landing/*`**
| Field | Wartość |
|---|---|
| Path pattern | `/landing/*` |
| Target origin | `alb` |
| Cache policy | `ab5d9518` — `kapsel-makotest-pl-static-assets` |
| TTL | min=86400, default=86400, max=31536000 |
| Origin request policy | `216adef6` — Managed-AllViewer |
| Compress | true |
| **Ocena:** Używa tej samej static policy co `_next/static`. Sensowne jeśli `/landing/*` to statyczny content. Ryzyko: jeśli landing zawiera dynamiczne elementy (personalizacja, A/B), min_ttl=86400 może powodować stale content. |

**Behavior 4 (precedence 3): `/favicon.ico`**
| Field | Wartość |
|---|---|
| Path pattern | `/favicon.ico` |
| Cache policy | `ab5d9518` — `kapsel-makotest-pl-static-assets` |
| TTL | min=86400, default=86400, max=31536000 |
| Origin request policy | `216adef6` — Managed-AllViewer |
| **Ocena:** Poprawna — favicon jest statyczny, 24h cache jest właściwy. |

### Monitoring i logging
- Standard logging: tak — `maspex-uat-access-logs-969209893152.s3.amazonaws.com/cloudfront/maspex-uat/api`
- Realtime logs: nie (brak konfiguracji)
- Additional metrics: nie sprawdzane przez CLI (wymaga konsoli)

---

## 2.2 UAT Admin — E3R9U1TWNUJZ11

### Podstawowe ustawienia
- **Aliases/CNAMEs:** `kapsel-admin-uat.makotest.pl`
- **Enabled:** true
- **Price class:** PriceClass_100
- **Comment:** `ALB origin: maspex-uat-1361582173.eu-west-1.elb.amazonaws.com`
- **Default root object:** (brak)
- **HTTP version:** http2
- **IPv6:** true
- **WAF:** brak
- **Logging:** enabled — bucket: `maspex-uat-access-logs-969209893152.s3.amazonaws.com`, prefix: `cloudfront/maspex-uat/admin-panel`, include_cookies: false
- **Viewer certificate:**
  - ACM ARN: `arn:aws:acm:us-east-1:969209893152:certificate/6027584b-5d01-4f1b-9bf8-2f3be01d09c7`
  - Min TLS: `TLSv1.2_2021`
  - SSL support method: `sni-only`

### Origins
| Field | Wartość |
|---|---|
| Origin ID | `alb` |
| Domain name | `maspex-uat-1361582173.eu-west-1.elb.amazonaws.com` |
| Origin type | Custom (ALB) |
| Origin protocol policy | `https-only` |
| Origin SSL protocols | `TLSv1.2` |
| Origin read timeout | 30s |
| Origin keepalive timeout | 5s |

### Default cache behavior
| Field | Wartość |
|---|---|
| Cache policy | `4135ea2d` — Managed-CachingDisabled |
| Origin request policy | `216adef6` — Managed-AllViewer |
| Viewer protocol | redirect-to-https |
| Allowed methods | 7 (wszystkie) |
| Compress | true |

### Ordered cache behaviors (UAT Admin — E3R9U1TWNUJZ11)

**Behavior 1 (precedence 0): `/_next/static/*`**
| Field | Wartość |
|---|---|
| Cache policy ID | `bddf535d-2396-440e-b2c2-5e2999ad5829` |
| Cache policy name | `kapsel-admin-uat-makotest-pl-static-assets` (custom) |
| TTL | min=86400, default=86400, max=31536000 |
| QS/cookies/headers | none/none/none |
| Origin request policy | `216adef6` — Managed-AllViewer |
| Compress | true |
| **Ocena:** Poprawna. |

**Behavior 2 (precedence 1): `/static/*`**
| Field | Wartość |
|---|---|
| Cache policy ID | `bddf535d` — `kapsel-admin-uat-makotest-pl-static-assets` |
| TTL | min=86400, default=86400, max=31536000 |
| Origin request policy | `216adef6` — Managed-AllViewer |
| **Ocena:** Poprawna dla statycznych assetów. |

### Monitoring i logging
- Standard logging: tak — prefix `cloudfront/maspex-uat/admin-panel`
- Realtime logs: nie

---

## 2.3 Preprod — E17VHHQJ29MVAB

### Podstawowe ustawienia
- **Aliases/CNAMEs:** `twojkapsel.pl`, `www.twojkapsel.pl`
- **Enabled:** true
- **Price class:** PriceClass_100
- **Comment:** `ALB origin: maspex-preprod-1322298306.eu-west-1.elb.amazonaws.com`
- **Default root object:** (brak)
- **HTTP version:** http2
- **IPv6:** true
- **WAF:** brak
- **Logging:** enabled — bucket: `maspex-preprod-access-logs-969209893152.s3.amazonaws.com`, prefix: `cloudfront/maspex-preprod/admin-panel`, include_cookies: false
- **Viewer certificate:**
  - ACM ARN: `arn:aws:acm:us-east-1:969209893152:certificate/1e70d4ef-11a7-440b-8b6e-923e789fe3f9`
  - Min TLS: `TLSv1.2_2021`
  - SSL support method: `sni-only`

### Origins
| Field | Wartość |
|---|---|
| Origin ID | `alb` |
| Domain name | `maspex-preprod-1322298306.eu-west-1.elb.amazonaws.com` |
| Origin type | Custom (ALB) |
| Origin protocol policy | `https-only` |
| Origin SSL protocols | `TLSv1.2` |
| Origin read timeout | 30s |
| Origin keepalive timeout | 5s |

### Default cache behavior
| Field | Wartość |
|---|---|
| Cache policy | `4135ea2d` — Managed-CachingDisabled |
| Origin request policy | `216adef6` — Managed-AllViewer |
| Viewer protocol | redirect-to-https |
| Allowed methods | 7 (wszystkie) |
| Compress | true |

### Ordered cache behaviors (Preprod — E17VHHQJ29MVAB)

**Behavior 1 (precedence 0): `/_next/static/*`**
| Field | Wartość |
|---|---|
| Cache policy ID | `3fcae9eb-9c29-4843-9697-849397260654` |
| Cache policy name | `twojkapsel-pl-static-assets` (custom) |
| TTL | min=86400, default=86400, max=31536000 |
| QS/cookies/headers | none/none/none |
| **Origin request policy** | **BRAK** (null — nie ustawiono) |
| Compress | true |
| **Ocena:** Brak origin request policy oznacza, że CF NIE przekazuje nagłówków/cookies/QS do originu dla tych ścieżek. Dla prawdziwie statycznych assetów (immutable pliki JS/CSS) to OK. Jeśli app wymaga cookies na static — problem. |

**Behavior 2 (precedence 1): `/static/*`**
| Field | Wartość |
|---|---|
| Cache policy ID | `3fcae9eb` — `twojkapsel-pl-static-assets` |
| TTL | min=86400, default=86400, max=31536000 |
| **Origin request policy** | **BRAK** |
| **Ocena:** Identyczne jak `/_next/static/*`. |

### Monitoring i logging
- Standard logging: tak — prefix `cloudfront/maspex-preprod/admin-panel`
- Realtime logs: nie

---

# 3. Terraform Mapping

## UAT API (E3J76RNXIE2YIG)
- **Plik env:** `terraform/envs/uat/main.tf` — moduł `cloudfront_site_api`
- **Moduł:** `terraform/modules/cloudfront-site/main.tf`
- **tfvars:** `terraform/envs/uat/terraform.tfvars`
- **Kluczowe parametry:**
  - `enabled = var.api_domain != ""` → `api_domain = "kapsel.makotest.pl"` → enabled=true
  - `domain_name = "kapsel.makotest.pl"`
  - `certificate_arn = "arn:aws:acm:us-east-1:969209893152:certificate/ab337320-6f37-4139-8ab6-cae6e654b569"`
  - `price_class = "PriceClass_100"` (default)
  - `static_paths = ["/_next/static/*", "/landing/*", "/favicon.ico"]` (z `api_cloudfront_static_paths`)
  - `image_optimizer_paths = ["/_next/image*"]`
  - `image_cache_min_ttl = 0`
  - `logging_prefix = "cloudfront/maspex-uat/api"`
  - `static_path_origin_request_policy_ids = {"/_next/static/*": "216adef6", "/landing/*": "216adef6", "/favicon.ico": "216adef6"}`
  - Brak `aliases` → tylko `domain_name` jako alias

## UAT Admin (E3R9U1TWNUJZ11)
- **Plik env:** `terraform/envs/uat/main.tf` — moduł `cloudfront_site`
- **Moduł:** `terraform/modules/cloudfront-site/main.tf`
- **tfvars:** `terraform/envs/uat/terraform.tfvars`
- **Kluczowe parametry:**
  - `enabled = var.cloudfront_enabled` → `cloudfront_enabled = true`
  - `domain_name = "kapsel-admin-uat.makotest.pl"` (z `cloudfront_domain`)
  - `certificate_arn = "arn:aws:acm:us-east-1:969209893152:certificate/6027584b-5d01-4f1b-9bf8-2f3be01d09c7"`
  - `static_paths = ["/_next/static/*", "/static/*"]`
  - `static_path_origin_request_policy_ids = {"/_next/static/*": "216adef6", "/static/*": "216adef6"}` (hardkodowane w main.tf)
  - `logging_prefix = "cloudfront/maspex-uat/admin-panel"`

## Preprod (E17VHHQJ29MVAB)
- **Plik env:** `terraform/envs/preprod/main.tf` — moduł `cloudfront_site`
- **Moduł:** `terraform/modules/cloudfront-site/main.tf`
- **tfvars:** `terraform/envs/preprod/terraform.tfvars`
- **Kluczowe parametry:**
  - `enabled = var.cloudfront_enabled` → `cloudfront_enabled = true`
  - `domain_name = "twojkapsel.pl"`
  - `aliases = ["www.twojkapsel.pl"]`
  - `certificate_arn = "arn:aws:acm:us-east-1:969209893152:certificate/1e70d4ef-11a7-440b-8b6e-923e789fe3f9"`
  - `static_paths = ["/_next/static/*", "/static/*"]`
  - `static_path_origin_request_policy_ids = {}` (pusta mapa — brak override w preprod/main.tf, brak w module domyślnie)
  - `logging_prefix = "cloudfront/maspex-preprod/admin-panel"`
  - Brak modułu `cloudfront_site_api` w preprod (brak zmiennej `api_domain` w tfvars preprod)

---

# 4. AWS vs Terraform Diff

## E3J76RNXIE2YIG — UAT API (kapsel.makotest.pl)

| Field / Behavior | AWS Live | Terraform | Klasyfikacja | Ryzyko | Komentarz |
|---|---|---|---|---|---|
| Aliases | `kapsel.makotest.pl` | `kapsel.makotest.pl` (przez `distinct(compact([domain_name]+aliases))`) | OK | niskie | Zgodne |
| Price class | PriceClass_100 | PriceClass_100 (default) | OK | niskie | |
| WAF | brak | brak | OK | niskie | Brak WAF na UAT — akceptowalne |
| IPv6 | true | true (hardkodowane) | OK | niskie | |
| HTTP version | http2 | http2 (brak jawnej konfiguracji — AWS default) | OK | niskie | HTTP/3 nie włączone |
| ACM cert ARN | `ab337320-6f37-4139-8ab6-cae6e654b569` | `ab337320-...` (z `api_cloudfront_certificate_arn`) | OK | niskie | |
| Min TLS | TLSv1.2_2021 | TLSv1.2_2021 (hardkodowane w module) | OK | niskie | |
| Default cache policy | Managed-CachingDisabled | Managed-CachingDisabled (hardkodowane w module) | OK | niskie | |
| Default origin request policy | Managed-AllViewer | Managed-AllViewer (hardkodowane) | OK | niskie | |
| Logging bucket | `maspex-uat-access-logs-969209893152.s3.amazonaws.com` | `${project}-${env}-access-logs-${account_id}.s3.amazonaws.com` | OK | niskie | |
| Logging prefix | `cloudfront/maspex-uat/api` | `cloudfront/maspex-uat/api` | OK | niskie | |
| Behavior `/_next/image*` | present — policy `dea1b35e` (kapsel-makotest-pl-image-optimizer) | present — `aws_cloudfront_cache_policy.image_optimizer[0]` | OK | niskie | |
| image_optimizer min_ttl | 0 | 0 (z `image_cache_min_ttl = 0` w tfvars) | OK | niskie | |
| image_optimizer max_ttl | 2592000 | 2592000 (default w module) | OK | niskie | |
| image_optimizer QS | all | all | OK | niskie | |
| image_optimizer origin_req_policy | 216adef6 | 216adef6 (default w zmiennej modułu) | OK | niskie | |
| Behavior `/_next/static/*` | present — `ab5d9518` | present — `aws_cloudfront_cache_policy.static_assets[0]` | OK | niskie | |
| static min_ttl | 86400 | 86400 (default) | OK | niskie | |
| static QS/cookies/headers | none | none | OK | niskie | |
| `/_next/static/*` origin_req_policy | 216adef6 | 216adef6 (z `static_path_origin_request_policy_ids`) | OK | niskie | |
| Behavior `/landing/*` | present — `ab5d9518` | present | OK | niskie | |
| Behavior `/favicon.ico` | present — `ab5d9518` | present | OK | niskie | |
| Origin read timeout | 30s | 30s (AWS default, brak konfiguracji w TF) | OK | niskie | Terraform nie ustawia jawnie, AWS default = 30 |
| Response headers policy | brak | brak | OK | niskie | |

**Werdykt UAT API:** Brak driftu. Terraform reprezentuje live stan poprawnie.

---

## E3R9U1TWNUJZ11 — UAT Admin (kapsel-admin-uat.makotest.pl)

| Field / Behavior | AWS Live | Terraform | Klasyfikacja | Ryzyko | Komentarz |
|---|---|---|---|---|---|
| Aliases | `kapsel-admin-uat.makotest.pl` | `kapsel-admin-uat.makotest.pl` | OK | niskie | |
| ACM cert | `6027584b-5d01-4f1b-9bf8-2f3be01d09c7` | `6027584b-...` | OK | niskie | |
| Default cache policy | Managed-CachingDisabled | Managed-CachingDisabled | OK | niskie | |
| Default origin req policy | Managed-AllViewer | Managed-AllViewer | OK | niskie | |
| Behavior `/_next/static/*` | present — `bddf535d` (kapsel-admin-uat-...-static-assets) | present — `static_assets[0]` | OK | niskie | |
| `/_next/static/*` origin_req_policy | 216adef6 | 216adef6 (z hardkodowanej mapy w uat/main.tf) | OK | niskie | |
| Behavior `/static/*` | present — `bddf535d` | present | OK | niskie | |
| `/static/*` origin_req_policy | 216adef6 | 216adef6 | OK | niskie | |
| Logging prefix | `cloudfront/maspex-uat/admin-panel` | `cloudfront/maspex-uat/admin-panel` | OK | niskie | |
| WAF | brak | brak | OK | niskie | |

**Werdykt UAT Admin:** Brak driftu. Terraform = live.

---

## E17VHHQJ29MVAB — Preprod (twojkapsel.pl + www.twojkapsel.pl)

| Field / Behavior | AWS Live | Terraform | Klasyfikacja | Ryzyko | Komentarz |
|---|---|---|---|---|---|
| Aliases | `twojkapsel.pl`, `www.twojkapsel.pl` | `twojkapsel.pl` + aliases=`["www.twojkapsel.pl"]` | OK | niskie | `distinct(compact([domain_name]+aliases))` → oba |
| ACM cert | `1e70d4ef-11a7-440b-8b6e-923e789fe3f9` | `1e70d4ef-...` | OK | niskie | |
| Default cache policy | Managed-CachingDisabled | Managed-CachingDisabled | OK | niskie | |
| Default origin req policy | Managed-AllViewer | Managed-AllViewer | OK | niskie | |
| Logging prefix | `cloudfront/maspex-preprod/admin-panel` | `cloudfront/maspex-preprod/admin-panel` | OK | niskie | |
| Behavior `/_next/static/*` | `3fcae9eb` — `twojkapsel-pl-static-assets` | `static_assets[0]` (TF tworzy tę policy) | OK | niskie | Nazwa policy `twojkapsel-pl-static-assets` = `${replace("twojkapsel.pl",".","-")}-static-assets` ✓ |
| `/_next/static/*` TTL | min=86400, default=86400, max=31536000 | default=86400, min=86400, max=31536000 | OK | niskie | Zgodne z defaults modułu |
| `/_next/static/*` origin_req_policy | **BRAK** (null) | `lookup({}, "/_next/static/*", null)` → null | OK | niskie | Pusty `static_path_origin_request_policy_ids = {}` w preprod/main.tf → null → brak policy. Zgodne z live. |
| Behavior `/static/*` | `3fcae9eb` — brak origin_req_policy | null z TF | OK | niskie | Zgodne |
| WAF | **BRAK** | brak | requires-decision | **wysokie** | Preprod = środowisko produkcyjne-like, brak WAF |
| HTTP/3 | brak | brak | requires-decision | niskie | Opcjonalna optymalizacja |
| Response headers policy | brak | brak | OK | niskie | |
| CallerReference | `terraform-20260421132705745100000001` | terraform-generated | OK | niskie | Potwierdza TF provenance |

**Werdykt Preprod:** Brak driftu funkcjonalnego. Terraform poprawnie reprezentuje live. Ryzyko operacyjne: brak WAF + brak origin request policy na static behaviors (projektowo OK dla static assets, ale warto skonfirmować).

---

# 5. Najważniejsze drifty i ryzyka

## 1. Brak WAF na dystrybucji preprod (twojkapsel.pl) — RYZYKO WYSOKIE
- **Objaw:** `WebACLId: ""` na E17VHHQJ29MVAB
- **Kontekst:** Preprod = środowisko zbliżone do produkcji, dostępne publicznie pod `twojkapsel.pl` i `www.twojkapsel.pl`
- **Wpływ:** Brak ochrony przed SQL injection, XSS, scraperami, bad bots, DDoS L7
- **Ocena:** Brak WAF to świadoma decyzja (nie drift), ale ryzyko operacyjne jest wysokie dla środowiska preprod

## 2. Brak origin request policy na static behaviors w preprod — RYZYKO NISKIE (ale warto skonfirmować)
- **Objaw:** `/_next/static/*` i `/static/*` w E17VHHQJ29MVAB nie mają `OriginRequestPolicyId`
- **Kontekst:** Terraform deklaruje `static_path_origin_request_policy_ids = {}` → null → brak forwarding
- **Wpływ:** CloudFront nie przekazuje cookies/nagłówków do originu dla tych ścieżek. Dla immutable statycznych assetów to POPRAWNE. Jeśli app wymaga auth-cookie na static assets — problem.
- **Różnica od UAT:** UAT forwarda `Managed-AllViewer` nawet na static behaviors. Preprod tego nie robi.

## 3. Brak HTTP/3 (QUIC) na wszystkich dystrybucjach — RYZYKO NISKIE
- **Objaw:** `HttpVersion: "http2"` na wszystkich 3
- **Wpływ:** Brak HTTP/3 = brak 0-RTT connection resumption dla mobile/lossy connections. Dla aplikacji Next.js na preprod może być widoczna różnica w TTFB dla kolejnych połączeń.

## 4. Brak response headers policy (security headers) — RYZYKO ŚREDNIE
- **Objaw:** Brak `ResponseHeadersPolicyId` na wszystkich behaviors, wszystkich dystrybucjach
- **Wpływ:** Brak automatycznego dodawania `X-Content-Type-Options`, `X-Frame-Options`, `Strict-Transport-Security`, `Content-Security-Policy` przez CloudFront
- **Kontekst:** App może te headery zwracać sama, ale nie ma gwarancji na poziomie CDN

## 5. Preprod — brak osobnej dystrybucji dla API — RYZYKO NISKIE (decyzja projektowa)
- **Objaw:** Terraform preprod nie definiuje modułu `cloudfront_site_api`. Nie ma zmiennej `api_domain` w preprod tfvars.
- **Kontekst:** Preprod nie ma osobnego API endpoint przez CloudFront — cały ruch przez jedną dystrybucję. Routing do właściwego ECS service przez ALB host-based routing.
- **Wpływ:** Brak izolacji cache/cert konfiguracji między API a admin panel dla preprod. Akceptowalne dla środowiska preprod.

---

# 6. Co jest poprawne i zgodne

1. Wszystkie 3 dystrybucje mają `origin_protocol_policy = https-only` — szyfrowanie CF→ALB
2. Wszystkie TLS minimum `TLSv1.2_2021` — zgodne z rekomendacjami AWS
3. Default cache behavior na wszystkich: Managed-CachingDisabled + Managed-AllViewer — poprawne dla dynamicznych aplikacji Next.js
4. Image optimizer behavior (UAT API) — poprawne `query_string_behavior=all` — kluczowe dla Next.js `/_next/image`
5. Static asset behaviors mają `min_ttl=86400` — override Cache-Control: max-age=0 z originu, wymagany dla Next.js
6. Logging włączony na wszystkich 3 dystrybucjach z właściwymi bucketami i prefixami
7. Wszystkie dystrybucje IPv6-enabled
8. CallerReference sufiksy wskazują na terraform-provenance — wszystkie 3 dystybucje są pod kontrolą TF
9. Origin Shield wyłączony — poprawne (EU, małe obciążenie, koszt nie uzasadniony)
10. Kompresja (Brotli+Gzip) włączona na wszystkich cache behaviors
11. Certyfikaty ACM w us-east-1 — wymagane przez CloudFront
12. Viewer certificate SSLSupportMethod: sni-only na wszystkich — poprawne

---

# 7. Co wymaga decyzji

1. **WAF na preprod (twojkapsel.pl)** — Czy wdrożyć AWS WAF? Koszt ~$5/mies. + reguły. Decyzja klienta (Maspex).
2. **HTTP/3 włączenie** — `http_version = "http2and3"` w Terraform. Nieszkodliwe, ale wymaga decyzji o wdrożeniu.
3. **Response headers security policy** — Czy dodać `Strict-Transport-Security`, `X-Frame-Options`, `X-Content-Type-Options` na poziomie CloudFront? Wymaga sprawdzenia czy app już zwraca te headery.
4. **`/landing/*` caching z min_ttl=86400** — Czy landing pages są statyczne/immutable? Jeśli mają personalizację lub A/B testy — min_ttl=86400 jest błędem. Do weryfikacji z team aplikacyjnym.
5. **Brak origin request policy na preprod static behaviors** — Świadoma decyzja (pusta mapa) vs UAT (AllViewer). Potwierdzić z team aplikacyjnym że preprod static assets nie wymagają session context.
6. **Origin read timeout = 30s** — Default AWS. Dla API z długimi requestami (generowanie raportów?) może być za krótkie. Max = 180s. Do weryfikacji z app teamem.

---

# 8. Rekomendowany plan działań

## Quick wins (safe, bez decyzji)
- Brak — konfiguracja jest poprawna i zgodna z Terraform. Nie ma safe quick fixes do wdrożenia.

## Bezpieczne korekty w Terraform (low risk)
1. **Włączyć HTTP/3:** W `modules/cloudfront-site/main.tf` dodać `http_version = "http2and3"` w resource `aws_cloudfront_distribution.this`. Bezpieczna zmiana, AWS rollback automatyczny.
2. **Ujednolicić `static_path_origin_request_policy_ids`** w preprod: Jeśli decyzja jest aby preprod miał AllViewer (jak UAT), dodać w `envs/preprod/main.tf`:
   ```hcl
   static_path_origin_request_policy_ids = {
     "/_next/static/*" = "216adef6-5c7f-47e4-b989-5492eafa07d3"
     "/static/*"       = "216adef6-5c7f-47e4-b989-5492eafa07d3"
   }
   ```

## Rzeczy do ręcznej weryfikacji w AWS
- Sprawdzić czy security headery (HSTS, X-Frame-Options) są zwracane przez aplikację (bez CloudFront policy)
- Sprawdzić cache hit ratio w CloudFront metrics dla UAT API image optimizer (czy min_ttl=0 powoduje cache miss)

## Rzeczy do zostawienia bez zmian
- Default cache policy (CachingDisabled) na default behaviors — poprawne dla Next.js SSR
- Origin keepalive timeout = 5s — AWS default, wystarczające dla ALB
- Brak Response headers policy — dopóki nie potwierdzono że app nie zwraca security headers
- Logging konfiguracja — poprawna i kompletna

---

# 9. Evidence / Commands / Files

## Komendy AWS użyte
```bash
AWS_PROFILE=maspex-cli aws cloudfront get-distribution-config --id E3J76RNXIE2YIG --output json
AWS_PROFILE=maspex-cli aws cloudfront get-distribution-config --id E3R9U1TWNUJZ11 --output json
AWS_PROFILE=maspex-cli aws cloudfront get-distribution-config --id E17VHHQJ29MVAB --output json
AWS_PROFILE=maspex-cli aws cloudfront list-cache-policies --type custom --output json
AWS_PROFILE=maspex-cli aws cloudfront list-cache-policies --type managed --output json
AWS_PROFILE=maspex-cli aws cloudfront list-origin-request-policies --type custom --output json
AWS_PROFILE=maspex-cli aws cloudfront list-origin-request-policies --type managed --output json
AWS_PROFILE=maspex-cli aws cloudfront list-response-headers-policies --type custom --output json
```

## Pliki Terraform przeczytane
- `terraform/modules/cloudfront-site/main.tf`
- `terraform/modules/cloudfront-site/variables.tf`
- `terraform/modules/cloudfront-site/outputs.tf`
- `terraform/envs/uat/main.tf`
- `terraform/envs/uat/variables.tf`
- `terraform/envs/uat/locals.tf`
- `terraform/envs/uat/terraform.tfvars`
- `terraform/envs/uat/data.tf`
- `terraform/envs/uat/logging.tf`
- `terraform/envs/preprod/main.tf`
- `terraform/envs/preprod/variables.tf`
- `terraform/envs/preprod/locals.tf`
- `terraform/envs/preprod/terraform.tfvars`
- `terraform/envs/preprod/logging.tf`

---

# 10. Final verdict

**Czy można ufać Terraform jako reprezentacji CloudFront?**
**TAK.** Wszystkie 3 dystrybucje są pod kontrolą Terraform (potwierdzają to CallerReference z prefiksem `terraform-`). Konfiguracja live jest zgodna z deklaratywnym stanem w Terraform. Brak nieautoryzowanych zmian manualnych.

**Czy najpierw trzeba wyrównać drift?**
**NIE.** Drift funkcjonalny nie istnieje. Jedyne różnice to świadome decyzje projektowe (brak WAF, brak HTTP/3, różne origin request policies między UAT a preprod).

**Które dystrybucje są najbardziej problematyczne?**
- **E17VHHQJ29MVAB (Preprod/twojkapsel.pl)** — pod względem bezpieczeństwa: brak WAF, brak security headers policy, brak origin request policy na static behaviors. To środowisko produkcyjne-like.
- **E3J76RNXIE2YIG (UAT API)** — technicznie poprawne, ale warto monitorować cache hit ratio image optimizer.
- **E3R9U1TWNUJZ11 (UAT Admin)** — najmniej problemów, konfiguracja wzorcowa.
