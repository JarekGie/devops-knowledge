# maspex — Troubleshooting

Aktywne problemy na górze. Rozwiązane zostają jako archiwum poniżej.

## Repozytorium
- lokalna ścieżka: `~/projekty/mako/aws-projects/infra-maspex`
- profil AWS: `maspex-cli` (IAM user + MFA, przez `awsume maspex-cli`)

---

## 2026-04-23 — UAT load test 3000 users / 1h: monitoring API path

**Stan:** patch Terraform przygotowany, nieaplikowany.

**Cel:**
- przygotować dashboard i alarmy pod kontrolowany test obciążeniowy `kapsel.makotest.pl`
- skupić monitoring na ścieżce: CloudFront → ALB → ECS `maspex-api` → logi aplikacyjne / Redis
- użyć istniejącego kanału alertów, bez tworzenia równoległego systemu powiadomień

**Stan istniejący potwierdzony:**
- repo: `~/projekty/mako/aws-projects/infra-maspex`
- env: `terraform/envs/uat`
- moduł monitoringu: `terraform/modules/monitoring`
- dashboard: `maspex-uat-overview`
- SNS topic: `arn:aws:sns:eu-west-1:969209893152:maspex-uat-alarms`
- subskrypcja email: `jaroslaw.golab@makolab.com`
- istniejące alarmy już miały `alarm_actions` i `ok_actions` podpięte do SNS
- CloudFront API distribution: `E3J76RNXIE2YIG`
- ECS service: `maspex-api`, desired/running `3/3`
- live ECS events nadal pokazywały wymiany tasków przez ALB health check timeout:
  `reason Request timed out`

**Braki przed patchem:**
- brak alarmu na ALB API `TargetResponseTime` p99
- brak alarmu na ALB API `TargetConnectionErrorCount`
- brak osobnego alarmu na `HTTPCode_ELB_5XX_Count`
- brak alarmu `RunningTaskCount < DesiredTaskCount`
- brak alarmu na CloudFront API `5xxErrorRate`
- brak metric filters dla logów aplikacyjnych:
  - `timeout`
  - `aborted`
  - `502`
  - `Timed out acquiring connection from connection pool`
  - `statement timeout`
  - `[GET_SLOGANS_COUNT]`
- dashboard nie pokazywał jeszcze CloudFront API, Redis, API log signals i task count

**Zmiany przygotowane w Terraform:**
- `terraform/modules/monitoring/variables.tf`
  - dodano `api_log_group_name`
  - dodano `cloudfront_api_distribution_arn`
  - dodano `redis_cache_cluster_id`
- `terraform/envs/uat/main.tf`
  - do `module "monitoring"` podpięto:
    - `api_log_group_name = module.service_api.log_group_name`
    - `cloudfront_api_distribution_arn = module.cloudfront_site_api.cloudfront_arn`
    - `redis_cache_cluster_id = "${var.project}-${var.environment}"`
- `terraform/modules/monitoring/main.tf`
  - dodano 6 log metric filters na `/maspex/uat/contest-service`
  - dodano alarmy:
    - `maspex-uat-alb-api-target-response-time-high`
    - `maspex-uat-alb-api-target-connection-errors`
    - `maspex-uat-alb-elb-5xx`
    - `maspex-uat-ecs-api-running-below-desired`
    - `maspex-uat-cloudfront-api-5xx-rate`
    - `maspex-uat-api-downstream-log-errors`
  - rozszerzono dashboard `maspex-uat-overview` o:
    - ECS API RunningTaskCount / DesiredTaskCount
    - ALB API p99 TargetResponseTime + TargetConnectionErrorCount
    - CloudFront API requests / 4xx / 5xx / OriginLatency
    - API log-derived signals
    - Redis CPU / memory / connections / evictions
- `terraform/modules/monitoring/outputs.tf`
  - rozszerzono `alarm_arns`

**Walidacja wykonana:**
```bash
terraform fmt terraform/envs/uat/main.tf terraform/modules/monitoring/main.tf terraform/modules/monitoring/variables.tf terraform/modules/monitoring/outputs.tf
terraform -chdir=terraform/envs/uat validate
AWS_PROFILE=maspex-cli AWS_REGION=eu-west-1 AWS_DEFAULT_REGION=eu-west-1 terraform -chdir=terraform/envs/uat plan -no-color
```

**Wynik walidacji:**
- `terraform validate`: OK
- `terraform plan`: `12 to add, 1 to change, 0 to destroy`
- plan dodaje tylko zasoby monitoringu/log metric filters/alarmy i zmienia dashboard

**Uwaga o worktree:**
- `terraform/envs/uat/main.tf` był już zmodyfikowany przed patchem monitoringu:
  - image `maspex-api:coreapp-uat-387`
  - `cpu = 4096`
  - `memory = 8192`
- nie traktować tych linii jako części patcha monitoringowego bez sprawdzenia historii lokalnej

**Jak operator używa dashboardu podczas testu:**
1. `ECS Service — api CPU/Memory` i `ECS Service — api Task Count`: czy API dobija do limitu i czy traci taski.
2. `ALB API — Target Response + Connection Errors`: czy target response p99 idzie w stronę 30s i czy rosną connection errors.
3. `CloudFront API`: czy edge widzi 5xx i czy rośnie origin latency.
4. `API Logs — Timeout / Aborted / Supabase Signals`: czy rosną symptomy downstream.
5. `Redis`: czy Redis pozostaje zdrowy albo zaczyna pokazywać evictions/connections/CPU.

**Następny krok:**
- review patcha Terraform
- jeżeli akceptacja: `terraform plan -out=...`, potem kontrolowany `terraform apply`
- po apply sprawdzić, czy nowe alarmy mają `AlarmActions` na `maspex-uat-alarms`

---

## 2026-04-24 — CloudFront cache behavior analysis + infra/observability patch

**Stan:** patch Terraform przygotowany i zwalidowany, nieaplikowany. Zakres wyłącznie infra/observability.

### CloudFront findings

**Dystrybucja API:** `E3J76RNXIE2YIG` (`kapsel.makotest.pl`)

| Path pattern | Cache policy | Origin request policy | Query strings w cache key | Ocena |
|---|---|---|---|---|
| `/_next/static/*` | static_assets (min_ttl=86400) | AllViewer | none | OK |
| `/landing/*` | static_assets (min_ttl=86400) | AllViewer | none | OK |
| `/favicon.ico` | (BRAK — przed patchem) | — | — | **PROBLEM** → default=CachingDisabled |
| `/_next/image*` | (BRAK) | — | — | **PROBLEM** → default=CachingDisabled |
| default | Managed-CachingDisabled | Managed-AllViewer | n/d | OK (dynamika) |

**`/_next/image*` — nie można cachować bez zmiany modułu:**
- endpoint Next.js Image Optimization używa `?url=...&w=...&q=...`
- istniejąca `static_assets` cache policy ma `query_string_behavior = "none"` — cachowanie wszystkich request do `/_next/image` na ten sam klucz byłoby błędem (podałoby zły obraz)
- wymagana nowa cache policy z `query_string_behavior = "all"` lub `allExcept`
- **zmiana oznaczona jako rekomendacja, nie wdrożona** — wymaga nowego wariantu modułu

**`/favicon.ico` — bezpiecznie keszować:**
- asset statyczny, Next.js wersjonuje przez hash w query string
- `query_string_behavior = "none"` w cache key jest poprawny (hash nie zmienia treści pliku)
- **wdrożono:**
  - `terraform.tfvars`: `api_cloudfront_static_paths = ["/_next/static/*", "/landing/*", "/favicon.ico"]`
  - `main.tf`: `/favicon.ico` → `AllViewer` origin request policy (wymagane dla ALB host-based routing)

### Monitoring additions (dołączone do istniejącego patcha)

**Nowe zasoby:**
- `redis_circuit_open` — log metric filter: `"Redis circuit open"` → `RedisCircuitOpenCount`
- alarm `maspex-uat-api-redis-circuit-open` — threshold: >10 events/min, SNS
- dashboard Row 11: `CloudFront API — Cache Hit Rate %` + `Total vs Origin Requests` (wymaga CF additional metrics)
- dashboard Row 12: `API Logs — Redis Circuit Open`
- Logs Insights query `top-request-paths` — top 25 ścieżek po liczbie hitów
- Logs Insights query `next-image-and-favicon-origin-hits` — logi z `/_next/image` lub `favicon.ico`
- `outputs.tf`: dodano `api_redis_circuit_open` do `alarm_arns`

**`terraform validate`:** SUCCESS

### Co wymaga ręcznego terraform plan/apply

Cały pakiet (monitoring + favicon CF behavior) jest nieaplikowany.

```bash
AWS_PROFILE=maspex-cli terraform -chdir=terraform/envs/uat plan -no-color
AWS_PROFILE=maspex-cli terraform -chdir=terraform/envs/uat apply
```

Po apply:
- sprawdzić czy nowe alarmy mają `AlarmActions` na `maspex-uat-alarms`
- sprawdzić czy `/favicon.ico` dostaje `Hit` w CloudFront (nagłówek `X-Cache: Hit from cloudfront`)
- jeśli CloudFront additional metrics są wyłączone: włączyć je na dystrybucji `E3J76RNXIE2YIG`

### Rekomendacje bez wdrożenia

1. **`/_next/image*` caching** — WDROŻONO w osobnej sekcji poniżej (2026-04-24 #2).
2. **CloudFront additional metrics** — włączyć na `E3J76RNXIE2YIG` żeby działały widgety `CacheHitRate` i `OriginRequests`
3. **Weryfikacja w AWS CLI**: `aws cloudfront get-distribution-config --id E3J76RNXIE2YIG --profile maspex-cli` — potwierdź listę behaviors i cache policies aktualnego stanu live (stan Terraform może różnić się od stanu live jeśli apply nie był wykonany)

---

## 2026-04-24 — CloudFront `/_next/image*` caching: GO LIVE package

**Stan:** WDROŻONE (2026-04-24). `terraform apply` wykonany — 5 added, 2 changed, 0 destroyed.

### Ownership

| Rola | Kto |
|---|---|
| App / Next.js owner | dev team / właściciel `next.config.js` |
| Infra / CloudFront owner | DevOps (ty) |
| Approve zmiany | app team musi potwierdzić 2 pytania (patrz niżej) |
| Deploy | DevOps po approve |

**2 pytania wymagające odpowiedzi od app teamu przed apply:**
1. Czy URL-e do obrazów (`/_next/image?url=...`) są stabilne (content-addressed)? Czy zdjęcia użytkowników lub dynamicznie generowane zmieniają się bez zmiany URL?
2. Ile wynosi `minimumCacheTTL` w `next.config.js`? (default: 60s — jeśli tak, po apply należy rozważyć `image_cache_min_ttl = 86400` w `main.tf`)

### Co zmieniono w repo infra

**`terraform/modules/cloudfront-site/variables.tf`** — dodano 5 zmiennych:
- `image_optimizer_paths` (default `[]`)
- `image_optimizer_origin_request_policy_id` (default: AllViewer)
- `image_cache_min_ttl` (default `0` — respektuje `Cache-Control` z originu)
- `image_cache_default_ttl` (default `86400`)
- `image_cache_max_ttl` (default `2592000` = 30 dni)

**`terraform/modules/cloudfront-site/main.tf`** — dodano:
- resource `aws_cloudfront_cache_policy.image_optimizer` z `query_string_behavior = "all"` (kluczowe — bez tego różne url+w+q dostawałyby ten sam cached obraz)
- `dynamic "ordered_cache_behavior"` dla `image_optimizer_paths` — **PRZED** static_assets blokiem

**`terraform/envs/uat/main.tf`** — w `cloudfront_site_api`:
- `image_optimizer_paths = ["/_next/image*"]`
- `image_cache_min_ttl = 0` (bezpieczny default)

### Cache policy — dlaczego `query_string_behavior = "all"`

- `/_next/image?url=https://example.com/a.jpg&w=800&q=75` i `?url=...&w=400` to DWA RÓŻNE obrazy
- `query_string_behavior = "none"` (jak w `static_assets`) → te same cache key → CloudFront podaje błędny obraz ← NIEDOPUSZCZALNE
- `query_string_behavior = "all"` → każda kombinacja QS = osobny cache entry → bezpieczne

### Walidacja

```bash
terraform validate  # ✓ SUCCESS (wykonano)
```

### Walidacja po apply

```
/_next/image* behavior → aktywny (dea1b35e = image_optimizer policy)
/_next/static/*        → ab5d9518 = static_assets
/landing/*             → ab5d9518
/favicon.ico           → ab5d9518

/favicon.ico 1. req: Miss + Cache-Control: public, max-age=31536000 ← Next.js wysyła 1 rok
/favicon.ico 2. req: Hit from cloudfront + age: 10 ✓ KESZUJE

/_next/image?...: Error from cloudfront ← behavior AKTYWNY; error z originu bo testowy URL
  nie istnieje w next.config.js remotePatterns — to jest app-side, nie infra-side
```

**Kluczowy wniosek dla app teamu:** `/_next/image` behavior działa po stronie CF. Jeśli obrazy nadal nie keszują się — sprawdź `remotePatterns` i `minimumCacheTTL` w `next.config.js`.

### Plan GO LIVE

```bash
# 1. pre-check
AWS_PROFILE=maspex-cli aws cloudfront get-distribution-config \
  --id E3J76RNXIE2YIG | jq '.DistributionConfig.CacheBehaviors.Items[].PathPattern'

# 2. terraform plan
AWS_PROFILE=maspex-cli terraform -chdir=terraform/envs/uat plan -no-color

# 3. apply (po review planu)
AWS_PROFILE=maspex-cli terraform -chdir=terraform/envs/uat apply

# 4. walidacja
curl -sI "https://kapsel.makotest.pl/_next/image?url=%2Fsome-img.jpg&w=800&q=75" \
  | grep -i "x-cache\|cache-control\|age"
# oczekiwane: X-Cache: Miss from cloudfront (pierwsze trafienie)
# drugi request: X-Cache: Hit from cloudfront

# 5. weryfikacja izolacji cache key
curl -sI "https://kapsel.makotest.pl/_next/image?url=%2Fimg.jpg&w=400&q=75" | grep x-cache
curl -sI "https://kapsel.makotest.pl/_next/image?url=%2Fimg.jpg&w=800&q=75" | grep x-cache
# oba mogą być HIT, ale po invalidacji pierwszy hit miss, drugi hit miss = INNE klucze ✓
```

### Rollback criteria

- Błędne obrazy (inny obraz niż oczekiwany) → `terraform apply` z `image_optimizer_paths = []`
- Wzrost 5xx na `cloudfront-api-5xx-rate` alarm
- Cache HIT rate 0% po 15 min = policy nie cachuje → sprawdź CF additional metrics, sprawdź `Cache-Control` z originu

### TTL — dependency od app team

Przy `image_cache_min_ttl = 0` (aktualny stan):
- jeśli Next.js wysyła `Cache-Control: public, max-age=60` (default `minimumCacheTTL`), CF keszuje przez 60s
- zysk jest (cache hit przez 60s zamiast 0), ale niewielki przy dużym ruchu

Jeśli app team potwierdzi stabilne URL-e obrazów:
```hcl
# w terraform/envs/uat/main.tf → cloudfront_site_api:
image_cache_min_ttl = 86400   # zastąp 0
```
→ obrazy keszowane 24h niezależnie od app config → drastyczna redukcja origin pressure

---

## 2026-04-23 — next-core-app: minimalny hot-path patch dla `/api/slogan`

**Stan:** patch aplikacyjny przygotowany lokalnie, niecommitowany.

**Repo:**
- `~/projekty/mako/next-core-app`
- zmieniony plik: `app/api/slogan/route.ts`

**Cel:**
- zmniejszyć request amplification na hot path `GET /api/slogan?page=1&sortBy=votes_desc`
- dla requestów bez `search` usunąć Supabase exact count fallback z `resolveCount()`
- zostawić zachowanie listy możliwie bez zmian

**Zmiana:**
- dla `search === null`:
  - `resolveCount()` próbuje Redis `slogans:total_count`
  - jeśli Redis zwróci wartość: zwraca count
  - jeśli Redis zwróci `null`: zwraca `null`
  - jeśli Redis rzuci błąd: zwraca `null`
  - nie wykonuje już Supabase exact count query na hot path
- dla `search !== null`:
  - zachowano dotychczasowy fallback do Supabase count
- dodano log:
  - `[GET_SLOGANS_COUNT]`
  - pola: `isSearch`, `countSource`, `durationMs`
  - bez tokenów, user id, treści haseł ani sekretów

**Dlaczego bezpieczne:**
- kod już obsługuje `totalPages: null`:
  - `totalCount !== null ? ... : null`
- `items`, `hasMore`, `page`, `limit`, `votedIds` zostają bez zmiany
- potencjalny efekt funkcjonalny: klient może częściej dostać `totalPages: null`

**Walidacja lokalna:**
- `npm run typecheck` nie wykonał się, bo lokalnie brakuje `tsc`:
  - `sh: tsc: command not found`
- do walidacji w CI/dev env:
  - `npm install` / właściwe środowisko zależności
  - `npm run typecheck`
  - `npm run lint`

**Następny krok:**
- review patcha aplikacyjnego
- po wdrożeniu obserwować metric filter `GET_SLOGANS_COUNT` i spadek Supabase count pressure

---

## 2026-04-23 — UAT admin-panel: CloudFront 502 dla assetów statycznych

**Problem:**
- `https://kapsel-admin-uat.makotest.pl/auth/login` zwracał `200`, ale UI wyglądał jak surowy HTML
- assety Next.js pod `/_next/static/*` przez CloudFront zwracały `502 Error from cloudfront`
- kontener admin-panel serwował `/auth/login`, CSS, JS i fonty poprawnie lokalnie

**Diagnoza:**
- dystrybucja admin UAT: `E3R9U1TWNUJZ11` (`kapsel-admin-uat.makotest.pl`)
- default behavior miał `Managed-AllViewer`:
  - `216adef6-5c7f-47e4-b989-5492eafa07d3`
- ordered cache behaviors dla:
  - `/_next/static/*`
  - `/static/*`
- oba behavior'y miały cache policy dla statyków, ale nie miały `origin_request_policy_id`
- ALB/origin wymaga poprawnego viewer request context, w praktyce tego samego kontraktu co default behavior

**Root cause:**
- brak `origin_request_policy_id = Managed-AllViewer` na adminowych ordered cache behaviors dla statycznych assetów
- problem był po stronie CloudFront/Terraform, nie po stronie UI/CSS/Next.js ani obrazu kontenera

**Fix (wdrożony):**
- w `terraform/envs/uat/main.tf` dla adminowego `module "cloudfront_site"` dodano:
```hcl
static_path_origin_request_policy_ids = {
  "/_next/static/*" = "216adef6-5c7f-47e4-b989-5492eafa07d3"
  "/static/*"       = "216adef6-5c7f-47e4-b989-5492eafa07d3"
}
```

**Walidacja przed apply:**
- `terraform fmt terraform/envs/uat/main.tf`
- `AWS_PROFILE=maspex-cli terraform -chdir=terraform/envs/uat validate -no-color`
- `AWS_PROFILE=maspex-cli terraform -chdir=terraform/envs/uat plan -no-color`
- wynik planu:
  - `0 to add`
  - `1 to change`
  - `0 to destroy`
- jedyny zasób:
  - `module.cloudfront_site.aws_cloudfront_distribution.this[0]`

**Wdrożenie:**
- `AWS_PROFILE=maspex-cli terraform -chdir=terraform/envs/uat apply -no-color -auto-approve`
- wynik:
  - `0 added`
  - `1 changed`
  - `0 destroyed`
- CloudFront status po apply: `Deployed`
- invalidation:
  - ID: `IC6KFOVSRK9VLU54BZTSVGGQXE`
  - paths: `/_next/static/*`, `/static/*`, `/auth/login`

**Weryfikacja po wdrożeniu:**
- `/auth/login` -> `HTTP/2 200`
- CSS asset `/_next/static/chunks/74d85594415070d4.css` -> `HTTP/2 200`
- JS asset `/_next/static/chunks/d59f830a2b8e768c.js` -> `HTTP/2 200`
- font asset `/_next/static/media/caa3a2e1cccd8315-s.p.853070df.woff2` -> `HTTP/2 200`

**Repo:**
- repo: `~/projekty/mako/aws-projects/infra-maspex`
- branch: `feat/preprod-zaslepka`
- commit lokalny: `4810f3c fix uat admin cloudfront static origin policy`
- stan po sprzątaniu: branch `ahead 1`; brak niecommitowanych zmian w śledzonych plikach

**Lekcja operacyjna:**
- jeśli CloudFront ma osobne ordered behavior dla statyków do ALB z host-based routingiem, sprawdzać nie tylko cache policy, ale też origin request policy
- default behavior może działać, a asset behavior może psuć Host/SNI/routing do originu

---

## 2026-04-22 — UAT API: CloudFront 502 dla `/landing/*` i `/_next/static/*`

**Problem:**
- `https://kapsel.makotest.pl/landing/latwogangg.png` zwracał `502` z `x-cache: Error from cloudfront`
- dodatkowo `502` pojawiał się dla assetów Next.js pod `/_next/static/chunks/*.js`
- `/` i `/auth/login` działały poprawnie

**Diagnoza:**
- dystrybucja API UAT: `E3J76RNXIE2YIG` (`kapsel.makotest.pl`)
- ordered cache behaviors:
  - `/_next/static/*`
  - `/landing/*`
- oba behavior’y trafiają do originu `ALB`
- default behavior działał, bo miał `Managed-AllViewer`:
  - `216adef6-5c7f-47e4-b989-5492eafa07d3`
- ALB używa host-based routingu i SNI cert selection
- direct request do ALB z `Host: kapsel.makotest.pl` zwracał asset `200`
- direct request bez poprawnego `Host` wpadał błędnie
- ECS / target group były zdrowe

**Root cause:**
- ordered behaviors dla statyków nie forwardowały do originu tego samego kontekstu viewer request co default behavior
- brakowało `origin_request_policy_id = Managed-AllViewer`
- to była ta sama klasa błędu dla `/landing/*` i `/_next/static/*`

**Fix (wdrożony):**
- w module `cloudfront-site` dodano wąski mechanizm:
  - `static_path_origin_request_policy_ids = map(string)`
- w `envs/uat/main.tf` dla `module.cloudfront_site_api` ustawiono:
```hcl
static_path_origin_request_policy_ids = {
  "/_next/static/*" = "216adef6-5c7f-47e4-b989-5492eafa07d3"
  "/landing/*"      = "216adef6-5c7f-47e4-b989-5492eafa07d3"
}
```
- zakres zmiany był celowo wąski:
  - tylko `module.cloudfront_site_api`
  - bez zmian dla `kapsel-admin-uat.makotest.pl`

**Walidacja przed apply:**
- `terraform fmt`
- `terraform -chdir=terraform/envs/uat validate`
- `AWS_PROFILE=maspex-cli terraform -chdir=terraform/envs/uat plan -no-color`
- wynik planu:
  - `0 to add`
  - `1 to change`
  - `0 to destroy`
- jedyny zasób:
  - `module.cloudfront_site_api.aws_cloudfront_distribution.this[0]`

**Wdrożenie:**
- `AWS_PROFILE=maspex-cli terraform -chdir=terraform/envs/uat apply -no-color -auto-approve`
- wynik:
  - `0 added`
  - `1 changed`
  - `0 destroyed`

**Weryfikacja po wdrożeniu:**
```bash
curl -I -sS https://kapsel.makotest.pl/landing/latwogangg.png
curl -I -sS https://kapsel.makotest.pl/
curl -I -sS https://kapsel.makotest.pl/auth/login
```

**Wynik po fixie:**
- `/landing/latwogangg.png` -> `HTTP/2 200`
- `/` -> `HTTP/2 307`
- `/auth/login` -> `HTTP/2 200`

**Dodatkowa komenda do statusu dystrybucji:**
```bash
AWS_PROFILE=maspex-cli aws cloudfront get-distribution \
  --id E3J76RNXIE2YIG \
  --query 'Distribution.Status' \
  --output text
```

**Rollback:**
- usunąć linię:
```hcl
"/_next/static/*" = "216adef6-5c7f-47e4-b989-5492eafa07d3"
```
- następnie:
```bash
terraform fmt terraform/envs/uat/main.tf
terraform -chdir=terraform/envs/uat validate
AWS_PROFILE=maspex-cli terraform -chdir=terraform/envs/uat plan -no-color
```

---

## 2026-04-21 — lukasz.fuchs: dostęp SSM + CloudShell (UAT)

**Wykonane:**
- Utworzono policy `maspex-uat-redis-ssm-access` (v2) i przypisano do `lukasz.fuchs@makolab.com`
- v1: ECS Exec + SSM na cluster maspex-uat
- v2: + `cloudshell:*` (potrzebne do otwarcia CloudShell w konsoli AWS)

**Uprawnienia:**
- `ecs:ExecuteCommand` / `ecs:Describe*/List*` — cluster + taski maspex-uat
- `ssm:StartSession/TerminateSession/ResumeSession/DescribeSessions/GetConnectionStatus`
- `cloudshell:*`

**Jak połączyć się z Redis przez CloudShell (eu-west-1):**
```bash
# W CloudShell (lub lokalnie po awsume maspex-cli):
aws ecs list-tasks --cluster maspex-uat --region eu-west-1

aws ecs execute-command \
  --cluster maspex-uat \
  --task <TASK_ID> \
  --container api \
  --command "/bin/sh" \
  --interactive \
  --region eu-west-1

# Wewnątrz kontenera:
redis-cli -h maspex-uat.zwowz5.0001.euw1.cache.amazonaws.com -p 6379
```

**Uwaga:** MFA wymagane — Łukasz musi mieć skonfigurowane MFA w IAM.

---

## Otwarte: ECS task definition drift (UAT)

**Wykryte:** 2026-04-21 podczas `terraform plan`

`module.service_api.aws_ecs_service.this` — Terraform chce zmienić `task_definition` z v31 → v24.

Przyczyna: CI/CD deployuje nowe wersje poza Terraformem (v31), TF state ma stary obraz (v24).

**Decyzja wymagana:** czy Terraform powinien zarządzać wersjami obrazów (i nadpisywać CI/CD), czy nie?

---

## 2026-04-21 — UAT: CloudFront static caching

**Problem zgłoszony przez Karola Maślaniec (14:20):**
- `Cache-Control: public, max-age=0` na statycznych elementach
- `X-Cache: Miss from cloudfront` — CloudFront nie cachował, każdy request szedł do originu

**Root cause:**
- Moduł `cloudfront-site` używał `Managed-CachingDisabled` dla wszystkich requestów
- Aplikacja wysyła `max-age=0` — nawet `CachingOptimized` by nie wystarczył (respektuje origin header)
- Wymagana custom cache policy z `min_ttl > 0`

**Fix (wdrożony):**

Nowe zasoby w module `terraform/modules/cloudfront-site`:
- `aws_cloudfront_cache_policy.static_assets` — `min_ttl=86400, default_ttl=86400, max_ttl=31536000`
- `dynamic "ordered_cache_behavior"` dla każdej ścieżki z `var.static_paths`

Nowa zmienna: `cloudfront_static_paths` w `envs/uat/terraform.tfvars`:
```hcl
cloudfront_static_paths = ["/_next/static/*", "/static/*"]
```

Dystrybucja UAT admin panel: `E3R9U1TWNUJZ11` (`kapsel-admin-uat.makotest.pl`)

**Efekt:**
- `/_next/static/*` i `/static/*` → cache 24h (min), niezależnie od `max-age=0`
- Dynamiczne requesty: nadal `CachingDisabled` (bez zmian)

**Jeśli app serwuje statyki z innej ścieżki:**
- Dodać wzorzec do `cloudfront_static_paths` w `terraform.tfvars` i reaplykować

---

## 2026-04-21 — preprod: CloudFront + certyfikaty

**Stan:** DONE

- CloudFront dystrybucja: `E17VHHQJ29MVAB`
- Domain: `d1epwako2iigq8.cloudfront.net`
- Domena klienta: `twojkapsel.pl` + `www.twojkapsel.pl`
- Cert CF (us-east-1): `arn:aws:acm:us-east-1:969209893152:certificate/1e70d4ef-11a7-440b-8b6e-923e789fe3f9`
- Cert ALB (eu-west-1): `arn:aws:acm:eu-west-1:969209893152:certificate/ddced1bc-fb38-46ab-a84e-bfb0e173314c`
- HTTP → HTTPS redirect: aktywny (301 na ALB)
- Static caching: `/_next/static/*` + `/static/*` (min_ttl=86400) — wdrożone razem z UAT

**DNS dla klienta (wysłać):**
```
twojkapsel.pl       CNAME   d1epwako2iigq8.cloudfront.net
www.twojkapsel.pl   CNAME   d1epwako2iigq8.cloudfront.net
```

**TODO:**
- Wpisać Redis endpoint do Secrets Manager:
```bash
aws secretsmanager put-secret-value \
  --secret-id arn:aws:secretsmanager:eu-west-1:969209893152:secret:maspex/preprod/api-STbBy3 \
  --secret-string '{"ConnectionStrings__Redis":"redis://maspex-preprod.zwowz5.0001.euw1.cache.amazonaws.com:6379"}' \
  --profile maspex-cli --region eu-west-1
```
- Naprawić warning w `modules/alb/main.tf:65` (`fixed_response` przy `redirect`, niekrytyczny)

---

## 2026-04-20 — preprod: nowe środowisko

**Stan:** DONE

**Co zrobiono:**
- `networking.tf` — VPC 10.45.0.0/16 + IGW + 6 subnetów + route tables
- `data.tf` — usunięto VPC/subnet data sources (preprod tworzy własne)
- `locals.tf` — subnety z `aws_subnet.*` zamiast data sources
- `main.tf` + `terraform.tfvars` — poprawki dla nowego środowiska
- `terraform apply` — COMPLETE

**Wyniki:**
- ALB: `maspex-preprod-1322298306.eu-west-1.elb.amazonaws.com`
- Redis: `maspex-preprod.zwowz5.0001.euw1.cache.amazonaws.com:6379`

**Architektura preprod:**
- VPC: 10.45.0.0/16 (własne; UAT: 10.44.0.0/16)
- Subnety: public (ALB), app (ECS+IGW), backend (ElastiCache, prywatne)
- ECR: wspólne z UAT (shared)
- State: S3 `terraform-state-969209893152` / `maspex/preprod/terraform.tfstate`

---

## Wzorzec static caching w CloudFront (reusable)

Problem: aplikacja wysyła `Cache-Control: max-age=0` dla statycznych assetów.

Rozwiązanie:

```hcl
# W module cloudfront-site — custom cache policy
resource "aws_cloudfront_cache_policy" "static_assets" {
  count       = var.enabled && length(var.static_paths) > 0 ? 1 : 0
  name        = "${replace(var.domain_name, ".", "-")}-static-assets"
  min_ttl     = 86400      # nadpisuje max-age=0 z originu
  default_ttl = 86400
  max_ttl     = 31536000
  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config      { cookie_behavior = "none" }
    headers_config      { header_behavior = "none" }
    query_strings_config { query_string_behavior = "none" }
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}
```

Ścieżki w `tfvars`:
```hcl
cloudfront_static_paths = ["/_next/static/*", "/static/*"]
```

Zasada: `min_ttl` musi być `> 0` żeby override'ować `max-age=0`. `CachingOptimized` (min_ttl=1s) jest niewystarczający w praktyce.
