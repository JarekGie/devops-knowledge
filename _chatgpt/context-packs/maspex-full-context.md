---
title: "Maspex — pełny kontekst projektu (ChatGPT)"
project: maspex
client: mako
updated: 2026-05-18
sources:
  - 20-projects/clients/mako/maspex/maspex-context.md
  - 20-projects/clients/mako/maspex/session-log.md
  - 20-projects/clients/mako/maspex/cutover-twojkapsel-2026-05-17.md
  - 20-projects/clients/mako/maspex/campaign-day-runbook.md
  - 20-projects/clients/mako/maspex/troubleshooting.md
  - 20-projects/clients/mako/maspex/finops-as-is-estimate.md
  - 20-projects/clients/mako/maspex/load-test-analysis-2026-05-16-2130-cest-prod-vs-uat.md
  - infra-maspex git log (live, 2026-05-18)
  - infra-maspex git diff (live, 2026-05-18)
---

# Maspex — Kapsel (aplikacja konkursowa) — pełny kontekst

**Stan na:** 2026-05-18 (po cutoverze)  
**Przygotował:** Jarosław Gołąb

---

## 1. Identyfikatory projektu

| Pole | Wartość |
|------|---------|
| Klient | Maspex Group (pośrednik: MakoLab) |
| Projekt | Kapsel — platforma konkursowa dla konsumentów |
| AWS Account ID | `969209893152` |
| AWS profile lokalne | `maspex-cli` (IAM user + MFA, przez `awsume maspex-cli`) |
| Główny region | `eu-west-1` |
| Dodatkowy region | `us-east-1` (ACM dla CloudFront) |
| IaC | Terraform (provider `hashicorp/aws ~> 5.0`, aktualnie `5.100.0`) |
| Repo infra (lokalna) | `~/projekty/mako/aws-projects/infra-maspex/` |
| Repo infra (GitLab) | `git@gitlab.makolab.net:admin-makolab/dc/aws-projects/infra-maspex-kapsel.git` |
| Repo aplikacja | `~/projekty/mako/next-core-app/` |
| Aktywny branch infra | `feat/campaign-day-monitoring` |
| Środowisko prod live | `twojkapsel.pl` — LIVE od **2026-05-18 ~10:50 CEST** |

---

## 2. Architektura ogólna

```
Internet
  │
  ├── CloudFront E33PUJBAQ533K0  → twojkapsel.pl (api/frontend PROD) ← LIVE od 2026-05-18
  ├── CloudFront E32AZKJ5SJSDSV  → kapsel-prod.makotest.pl (admin PROD)
  ├── CloudFront E3J76RNXIE2YIG  → kapsel.makotest.pl (api/frontend UAT)
  ├── CloudFront E3R9U1TWNUJZ11  → kapsel-admin-uat.makotest.pl (admin UAT)
  └── CloudFront E17VHHQJ29MVAB  → bez aliasów (po cutoverze — dawny preprod/test)
        │
        ▼
  ALB maspex-prod (internet-facing, eu-west-1)
  ALB maspex-uat  (internet-facing, eu-west-1)
  ALB maspex-preprod (internet-facing, eu-west-1)
        │
        ▼
  ECS Fargate — cluster maspex-prod
    ├── maspex-api         (desired=9 / aktualnie, autoscaling min=30 max=45)  ← last load test
    ├── maspex-bot         (0/1 unhealthy — FailedHealthChecks, persistent)
    └── maspex-admin-panel (1/1)
                                ─── Redis ElastiCache maspex-prod :6379
                                ─── Supabase / PostgREST (downstream, zewnętrzny)

  ECS Fargate — cluster maspex-uat
    ├── maspex-api         (9/9)
    ├── maspex-bot         (0/1 unhealthy — FailedHealthChecks, persistent)
    └── maspex-admin-panel (1/1)
                                ─── Redis ElastiCache maspex-uat :6379

  ECS Fargate — cluster maspex-preprod
    ├── maspex-preprod-api (IAM error — 0/3 → naprawione 2026-05-18)
    ├── maspex-preprod-bot (1/1)
    └── maspex-preprod-admin-panel (1/1)
```

**Aplikacja:** Next.js/Node.js API + admin panel (React) + bot service  
**Pattern:** CloudFront → ALB → ECS Fargate → Redis ElastiCache + Supabase/PostgREST  
**CI/CD:** Jenkins → ECR → ECS force-new-deployment  
**Uwaga:** ECS moduł ma `ignore_changes = [task_definition]` → TF rejestruje nową task-def ale NIE przełącza serwisu; wymagane ręczne `aws ecs update-service --force-new-deployment`

---

## 3. Środowiska

| Env | VPC CIDR | Status (2026-05-18) |
|-----|----------|---------------------|
| shared | brak klastra ECS | zasoby sieciowe, ECR, S3 |
| uat | 10.44.0.0/16 | aktywny — 11 tasków running |
| preprod | 10.45.0.0/16 | częściowo aktywny |
| prod | nieustalone | **LIVE** od 2026-05-18 10:50 CEST |

**Terraform state backend (S3 + DynamoDB, encrypt=true):**

| Env | Key |
|-----|-----|
| shared | `maspex/shared/terraform.tfstate` |
| uat | `maspex/uat/terraform.tfstate` |
| prod | `maspex/prod/terraform.tfstate` |

Bucket: `terraform-state-969209893152` | Lock table: `terraform-locks-969209893152`  
Backend: przez `-backend-config=backend.hcl` (nie hardcode)

---

## 4. Repo infra — bieżący stan

**Aktywny branch:** `feat/campaign-day-monitoring`

**Uncommitted changes (2026-05-18):**
- `terraform/envs/prod/terraform.tfvars` — zmiany z cutovera:
  - `api_domain = "twojkapsel.pl"` (bylo `test.twojkapsel.pl`)
  - `api_cloudfront_certificate_arn = "arn:aws:acm:us-east-1:...f1370536"` (nowy 4-SAN cert)
- `terraform/envs/prod/waf.tf` — WAF admin panel otwarty publicznie (TEMP):
  - `default_action { allow {} }` z komentarzem rollback

**Untracked files:**
- `scripts/redis_secret_rotation.sh` — skrypt rotacji sekretu Redis
- `testy-qa/` — katalog testów QA

**Ostatnie commity:**
```
65fe2fb feat(prod,ecs): skalowanie api - min=30 max=45 desired=30
8c798bc feat(prod,cf): wylacz test.twojkapsel.pl - usun aliasy z CF i ALB
84a7b77 fix(prod,waf): otworz twojkapsel.pl - ruch publiczny
...
4cd3d01 fix(prod): migrate API CloudFront alias to test.twojkapsel.pl
7511067 feat(prod): separate task definition families from service names
```

---

## 5. ECS — szczegóły serwisów i scaling

### PROD

| Serwis | Desired | Running | Uwagi |
|--------|---------|---------|-------|
| maspex-api | 9 (baseline, last set) | 9 | autoscaling min=30 max=45 (z load testu) |
| maspex-bot | 1 | 0 | ⚠️ FailedHealthChecks — persistent; restart loop co ~30–60 min |
| maspex-admin-panel | 1 | 1 | OK |

**Autoscaling maspex-api PROD:**
- Trigger: `ALBRequestCountPerTarget > 200` (scale-out), CPU + Memory Target Tracking
- Pre-scale na campaign day: `min_capacity=12` (runbook) lub ręcznie desired=15
- Max capacity ostatnio ustawione: 45 (po load teście 2026-05-16)
- Campaign day runbook: pre-scale do min=12 lub 30 min przed kampanią

**Scaling komendy:**
```bash
# Pre-scale przed kampanią
AWS_PROFILE=maspex-cli aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/maspex-prod/maspex-api \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 12 --max-capacity 45 --region eu-west-1

# Ręczny scale-up
AWS_PROFILE=maspex-cli aws ecs update-service \
  --cluster maspex-prod --service maspex-api --desired-count 15 --region eu-west-1
```

### UAT

| Serwis | Desired | Running | Uwagi |
|--------|---------|---------|-------|
| maspex-api | 9 | 9 | OK |
| maspex-bot | 1 | 0–1 | ⚠️ unhealthy (FailedHealthChecks) od 2026-04-23 |
| maspex-admin-panel | 1 | 1 | OK |

**IAM drift UAT (naprawiony 2026-05-18):**  
Execution role `maspex-api-execution` miała ARN `maspex/prod/api` zamiast `maspex/uat/api` → fix przez `terraform apply -target`.

---

## 6. Redis ElastiCache

| Zasób | Endpoint | Node type | Wersja |
|-------|---------|-----------|--------|
| maspex-prod | `maspex-prod.zwowz5.0001.euw1.cache.amazonaws.com:6379` | cache.t3.medium | Redis 7.1.0, single-node |
| maspex-uat | `maspex-uat.zwowz5.0001.euw1.cache.amazonaws.com:6379` | cache.t3.medium | Redis 7.1.0, single-node |
| maspex-preprod | `maspex-preprod.zwowz5.0001.euw1.cache.amazonaws.com:6379` | cache.t3.micro | Redis 7.1.0 |

**Load test findings (PROD, 2026-05-16):**
- Hit rate PROD: ~47–50% (vs UAT 75%) — produkcyjne dane bardziej zróżnicowane = więcej miss = więcej zapytań do Supabase
- EngineCPU max: 23.8% przy 6,483 req/s
- 0 evictions, 0 circuit open
- CurrConnections stałe ~95 (30 tasks × ~3 conn)

**REDIS_URL issue (otwarte):** W środowiskach preprod i prod wartość `ConnectionStrings__Redis` w Secrets Manager może wskazywać na zły endpoint — do weryfikacji i aktualizacji przez rotację sekretu (`scripts/redis_secret_rotation.sh`).

**Dostęp do Redis przez ECS Exec:**
```bash
aws ecs execute-command \
  --cluster maspex-uat \
  --task <TASK_ID> \
  --container api \
  --command "/bin/sh" \
  --interactive \
  --region eu-west-1 --profile maspex-cli
# Wewnątrz:
redis-cli -h maspex-uat.zwowz5.0001.euw1.cache.amazonaws.com -p 6379
```

---

## 7. CloudFront — dystrybucje

| ID | Domena | Aktualny alias | Status |
|----|--------|----------------|--------|
| E33PUJBAQ533K0 | d1w5bz7itj42sz.cloudfront.net | twojkapsel.pl, www.twojkapsel.pl, test.twojkapsel.pl, www.test.twojkapsel.pl | **PROD API — LIVE** |
| E32AZKJ5SJSDSV | dfx1ac92hj3uw.cloudfront.net | kapsel-prod.makotest.pl | PROD admin |
| E3J76RNXIE2YIG | (CF domain) | kapsel.makotest.pl | UAT API |
| E3R9U1TWNUJZ11 | (CF domain) | kapsel-admin-uat.makotest.pl | UAT admin |
| E17VHHQJ29MVAB | d1epwako2iigq8.cloudfront.net | (brak — usunięte po cutoverze) | dawny preprod/test |
| E34Y0KHR85VIR7 | (CF domain) | (nieokreślony) | shared/inne |

**CF cert PROD (us-east-1):** `f1370536` — 4 SANy: twojkapsel.pl, www.twojkapsel.pl, test.twojkapsel.pl, www.test.twojkapsel.pl — ISSUED ✅

**Cache behaviors PROD API (E33PUJBAQ533K0):**
- `/_next/static/*` → min_ttl=86400 (custom static cache policy)
- `/landing/*` → min_ttl=86400
- `/favicon.ico` → min_ttl=86400
- `/_next/image*` → image_optimizer policy (`query_string_behavior = all`)
- `default` → CachingDisabled (dynamika)
- `/api/slogan?*` → dedykowana policy z cachingiem

**Uwaga:** load testy 2026-05-16 bypassowały CloudFront (bezpośrednio na ALB). Produkcja używa CF jako edge z ~41% offload (na podstawie UAT testów).

---

## 8. ALB

| ALB | DNS | Env |
|-----|-----|-----|
| maspex-prod | `maspex-prod-1795571755.eu-west-1.elb.amazonaws.com` | PROD |
| maspex-uat | `maspex-uat-1361582173.eu-west-1.elb.amazonaws.com` | UAT |
| maspex-preprod | `maspex-preprod-1322298306.eu-west-1.elb.amazonaws.com` | preprod |

**ALB routing:** host-based rules — `twojkapsel.pl` + `www.twojkapsel.pl` (po cutoverze)  
**HTTPS redirect:** aktywny (HTTP 301 → HTTPS)

---

## 9. ACM Certificates

**eu-west-1 (ALB):**

| Suffix | Domena | Status |
|--------|--------|--------|
| ddced1bc | twojkapsel.pl, www.twojkapsel.pl | ISSUED ✅ |
| d4bbfef0 | test.twojkapsel.pl | ISSUED ✅ |
| a139f9a4 | kapsel-prod.makotest.pl | ISSUED ✅ |
| fd2f0c7c | (nowy ALB cert PROD) | ISSUED ✅ |

**us-east-1 (CloudFront):**

| Suffix | Domena / SANy | Status |
|--------|---------------|--------|
| f1370536 | twojkapsel.pl, www.*, test.*, www.test.* | ISSUED ✅ — używany na E33 |
| caed9d07 | test.twojkapsel.pl, www.test.twojkapsel.pl | ISSUED ✅ |
| 369af310 | kapsel-prod.makotest.pl | ISSUED ✅ |
| 1e70d4ef | twojkapsel.pl, www.twojkapsel.pl | ISSUED ✅ |

---

## 10. WAF

**PROD — public_app_allowlist (CloudFront CLOUDFRONT scope):**
- Stan po cutoverze: `default_action { allow {} }` — publiczny dostęp otwarty ✅
- Uncommitted w repo: waf.tf zmieniony, nie zacommitowany

**PROD — admin_panel_allowlist (CloudFront CLOUDFRONT scope):**
- Stan po 2026-05-18: **tymczasowo otwarty** (`default_action { allow {} }`)
- Rollback: zmień na `block {}`, lista IP zachowana w `local.admin_panel_allowed_ipv4_cidrs`

**WAF REGIONAL (eu-west-1):**
- Stan z cloud-detective skanu 2026-05-05: **brak WAF REGIONAL** (gap LLZ)
- Może być zmienione po cutoverze — do weryfikacji

---

## 11. Monitoring i alarmy PROD

**Dashboards:**
- `maspex-prod-overview` (CloudWatch)
- `maspex-uat-overview` (CloudWatch)

**SNS topic PROD:** `arn:aws:sns:eu-west-1:969209893152:maspex-prod-alarms` (email: jaroslaw.golab@makolab.com)

**Kompletna lista alarmów PROD:**

| Alarm | Próg | Akcja gdy w ALARM |
|-------|------|-------------------|
| `maspex-prod-alb-target-5xx` | >5 / 5 min | Sprawdź logi /maspex/prod/contest-service |
| `maspex-prod-alb-elb-5xx` | >5 / 5 min | ECS health + upstream timeout |
| `maspex-prod-alb-unhealthy-hosts-api` | ≥1 / 5 min | describe-target-health + logi taska |
| `maspex-prod-alb-api-target-response-time-high` | p99 >10s / 3 min | Redis circuit open? Supabase 502? |
| `maspex-prod-alb-api-target-connection-errors` | >10 / 1 min | Sprawdź health state tasków |
| `maspex-prod-ecs-api-running-below-desired` | running < desired / 2 min | Stopped tasks + service events |
| `maspex-prod-ecs-high-cpu-api` | avg >80% / 10 min | Pre-scale: desired +3 |
| `maspex-prod-ecs-high-memory-api` | avg >85% / 10 min | Restart najstarszych tasków |
| `maspex-prod-ecs-api-pending-tasks` | >0 / 3 min | Fargate capacity + service events |
| `maspex-prod-cloudfront-api-5xx-rate` | >1% / 3 min | Origin health (ALB/ECS) |
| `maspex-prod-api-downstream-log-errors` | >5 / 5 min | Supabase502, pool timeout |
| `maspex-prod-api-redis-circuit-open` | >10 / 1 min | Redis health (CPU, evictions, conn) |
| `maspex-prod-redis-high-engine-cpu` | >50% / 3 min | Monitoruj; >70% → eskalacja |
| `maspex-prod-redis-evictions` | >100 / 1 min | maxmemory-policy; flush starych kluczy |
| `maspex-prod-api-auth-errors` | >10 / 5 min | JWT config lub burst refresh |

**Progi campaign day:**

| Metryka | ZIELONY | ŻÓŁTY | CZERWONY |
|---------|---------|-------|---------|
| ALB Target 5xx | 0 | 1–5 / 5 min | >5 / 5 min |
| ALB p99 latency | <2s | 2–10s | >10s |
| ECS CPU avg | <60% | 60–80% | >80% |
| ECS Memory avg | <75% | 75–85% | >85% |
| Redis EngineCPU | <30% | 30–50% | >50% |
| Redis Evictions | 0 | <100/min | >100/min |

**Log groups (eu-west-1):**

| Log group | Retencja |
|-----------|----------|
| `/maspex/prod/contest-service` | nieustalone |
| `/maspex/shared/maspex-api` | 90 dni |
| `/maspex/uat/admin-panel` | 30 dni |
| `/maspex/uat/bot` | 30 dni |
| `/aws/ecs/containerinsights/maspex-prod/performance` | 1 dzień ⚠️ |
| `/aws/ecs/containerinsights/maspex-uat/performance` | 1 dzień ⚠️ |

---

## 12. Secrets Manager

| Secret | Env | Uwagi |
|--------|-----|-------|
| `maspex/uat/api` | UAT | widoczny dla makolab-ci |
| `maspex/prod/api` | PROD | może być niewidoczny dla makolab-ci |
| `maspex/preprod/api` | preprod | istnieje (AccessDeniedException potwierdza) |

**REDIS_URL w sekretach:** Wartość `ConnectionStrings__Redis` w preprod/prod może wskazywać na zły endpoint. Skrypt rotacji: `scripts/redis_secret_rotation.sh`.

```bash
# Aktualizacja REDIS_URL
aws secretsmanager put-secret-value \
  --secret-id arn:aws:secretsmanager:eu-west-1:969209893152:secret:maspex/prod/api-<suffix> \
  --secret-string '{"ConnectionStrings__Redis":"redis://maspex-prod.zwowz5.0001.euw1.cache.amazonaws.com:6379"}' \
  --profile maspex-cli --region eu-west-1
```

---

## 13. Historia load testów

**Seria testów (UAT + PROD, kwiecień–maj 2026):**

| Data | Env | Peak req/s | Wynik | Kluczowe ustalenie |
|------|-----|-----------|-------|---------------------|
| 2026-04-28 | UAT | ~2,000 | częściowy fail | autoscaling za wolny |
| 2026-04-29 | UAT | ~2,000 | fail | Redis circuit open |
| 2026-05-05 | UAT | niski | observability | baseline monitoring |
| 2026-05-05 | UAT | niski | monitoring | alarmy UAT skonfigurowane |
| 2026-05-11 | UAT | wysoki | degradacja | VOTE_CACHE_WRITETHROUGH_FAIL |
| 2026-05-14 | UAT | kalibracja | calibration | ASG rekalibration, min=12/max=30 |
| 2026-05-15 | UAT | **8,835** | **zdał** | autoscaling 12→30 w 4 min |
| 2026-05-16 | **PROD** | **6,483** | **zdał** | p99=0.277s peak; post-peak tail 8.7s |

**Wyniki ostatniego testu PROD (2026-05-16 21:30–22:10 CEST):**
- PROD zdał: 0 Target 5xx, 0 app errors, p99 peak = **0.277s**
- Post-peak tail degradacja (21:45): 67 ELB 5xx, p99 = **8.721s** — connection queue overflow (nie błąd app)
- Redis: hit rate **47–50%** (vs UAT 75%), EngineCPU max 23.8%, 0 evictions
- ECS: 30 tasków pre-scaled (max capacity), CPU max 48%, Memory max 47.9%
- **Różnica od UAT:** PROD znacznie stabilniejszy (pre-scale), ale nowy problem post-peak tail

**Znane otwarte kwestie po testach:**
- Redis FLUSHALL PROD — **nie wykonano** (czeka na decyzję)
- Test z CF routing — nie wykonany (testy bypassowały CloudFront)
- Autoscaling PROD nie był testowany (start z max capacity)
- Warmup run rekomendowany przed każdym testem (cold state p99=9.9s)

---

## 14. Cutover twojkapsel.pl (2026-05-18)

**Status:** ✅ LIVE od ~10:50 CEST

**Co wykonano:**
1. DNS (Cloudflare): `twojkapsel.pl + www → d1w5bz7itj42sz.cloudfront.net`
2. `terraform apply`: WAF open, ALB cert (ddced1bc), ALB routing (+twojkapsel.pl, +www), CF E33 aliases+cert swap (caed9d07→f1370536)
3. Hotfixe: WAF description em dash (—→-), usunięcie konfliktujących aliasów z E17VHHQJ29MVAB przez CLI
4. Weryfikacja: twojkapsel.pl, www.twojkapsel.pl, test.twojkapsel.pl → HTTP 200 ✅

**Zmiany w IaC (uncommitted):**
- `terraform.tfvars`: `api_domain = "twojkapsel.pl"`, cert = f1370536
- `waf.tf`: default_action `allow {}` dla public_app_allowlist

**Po cutoverze — do zrobienia:**
- Zacommitować i wypchnąć zmiany z cutovera na GitLab
- Przygotować MR: `feat/campaign-day-monitoring` → `main`
- Monitoring przez 24h
- Opcjonalnie: usunąć/przekierować E17VHHQJ29MVAB

---

## 15. Znane problemy i dług techniczny

### Krytyczne / otwarte

| Problem | Evidence | Szczegóły |
|---------|----------|-----------|
| **maspex-bot unhealthy (PROD + UAT)** | FailedHealthChecks od 2026-04-23 (25+ dni) | Restart loop co ~30–60 min. Prawdopodobna przyczyna: brak tokenu Twitch lub błąd auth w bot service. Niezależne od API ale generuje szum w metrykach i alarmach. |
| **REDIS_URL w preprod/prod** | session-log 2026-05-18 | ConnectionStrings__Redis może wskazywać na zły endpoint. Do zweryfikowania i aktualizacji. |
| **Supabase SITE_URL w UAT** | session-log | `SITE_URL` wskazuje na `test.kapsel.makotest.pl` zamiast `test.twojkapsel.pl` lub `kapsel.makotest.pl`. Może powodować błędy auth redirect. |
| **WAF admin panel PROD tymczasowo otwarty** | waf.tf uncommitted | `default_action { allow {} }` — do zamknięcia po kampanii lub po rezygnacji z potrzeby |
| **Redis FLUSHALL PROD** | session-log 2026-05-16 | Nie wykonano po load teście. Może być potrzebny do czystego startu kampanii. Wymaga ECS exec. |

### Znane, nie krytyczne

| Problem | Priorytet | Szczegóły |
|---------|-----------|-----------|
| Brak WAF REGIONAL | ŚREDNI | `wafv2 list-web-acls --scope REGIONAL` = puste (scan 2026-05-05). LLZ gap. |
| Container Insights retencja 1 dzień | NISKI | `/aws/ecs/containerinsights/maspex-*/performance` — utrudnia debugging post-incident |
| Enhanced Container Insights PROD | ŚREDNI | Brak per-task metryk — hotspot analiza niemożliwa |
| ECS task definition drift (UAT) | INFO | TF deploy vs CI/CD deploy z różnymi revizjami — `ignore_changes = [task_definition]` |
| VPC bez Name tagu | INFO | `vpc-0df07c64ea8a8b00e` bez nazwy |
| Tagging coverage nieweryfikowane | ŚREDNI | resourcegroupstaggingapi nie uruchomiono |
| Post-peak tail degradacja PROD | ŚREDNI | 8.7s p99 przy opadaniu ruchu — connection queue overflow; rozważyć tuning ALB drain timeout |
| Błąd prerender `/zwycieskie` | NISKI | Next.js ISR/prerender error — `fetch()` po zakończeniu prerenderingu; kod app |

---

## 16. FinOps

**Szacunek miesięczny (UAT + preprod, kwiecień 2026):**

| Wariant | Koszt/mies |
|---------|-----------|
| Minimalny (API 1024/2048) | ~$420 |
| Prawdopodobny | ~$431 |
| Ostrożny (API 4096/8192) | ~$751 |

**Top cost drivery:**
1. ECS Fargate compute (dominuje — zwłaszcza przy dużej liczbie tasków)
2. NAT Gateway (~$35/mies stały koszt)
3. Container Insights (~$24–79/mies zależnie od vCPU)

**PROD:** koszty nieoszacowane formalnie. Z 9–30 taskami ECS Fargate (1 task = 1vCPU/2GB lub 4vCPU/8GB) koszt PROD może być 3–5× wyższy niż UAT+preprod razem.

**Nowe zasoby shared (2026-05):**
- `assets.twojkapsel.pl` — S3 + CloudFront dla mail assets (commit `a6661d0`)

---

## 17. Terraform — struktura repo

```
terraform/
  bootstrap/          — S3 state bucket, DynamoDB lock table
  envs/
    shared/           — VPC, ECR, S3, mail assets CF
    uat/              — ECS uat, ALB uat, CF uat, monitoring, autoscaling
    prod/             — ECS prod, ALB prod, CF prod, WAF, autoscaling
    preprod/          — ECS preprod, ALB preprod, CF preprod (preprod VPC 10.45.0.0/16)
  modules/
    alb/              — ALB z listenerami
    alb-routing/      — listener rules (host-based)
    cloudfront-site/  — CloudFront distribution + cache behaviors (z image optimizer)
    ecs/              — ECS service + task def (ignore_changes = [task_definition])
    elasticache/      — Redis ElastiCache
    monitoring/       — CW dashboards, alarmy, log metric filters
    (inne)
```

**Wzorzec deploy:**
```bash
cd terraform/envs/prod
terraform init -backend-config=backend.hcl
AWS_PROFILE=maspex-cli terraform plan -out=<name>.tfplan
AWS_PROFILE=maspex-cli terraform apply <name>.tfplan
```

---

## 18. Kluczowe komendy diagnostyczne

```bash
# Tożsamość
aws sts get-caller-identity --profile maspex-cli

# ECS PROD — stan serwisów
AWS_PROFILE=maspex-cli aws ecs describe-services \
  --cluster maspex-prod \
  --services maspex-api maspex-admin-panel maspex-bot \
  --region eu-west-1 \
  --query 'services[*].{svc:serviceName,desired:desiredCount,running:runningCount,pending:pendingCount}'

# Autoscaling activities PROD (ostatnie 20)
AWS_PROFILE=maspex-cli aws application-autoscaling describe-scaling-activities \
  --service-namespace ecs \
  --resource-id service/maspex-prod/maspex-api \
  --region eu-west-1 --max-results 20 \
  --query 'ScalingActivities[*].{time:StartTime,cause:Cause,status:StatusCode}'

# Alarmy w ALARM
AWS_PROFILE=maspex-cli aws cloudwatch describe-alarms \
  --alarm-name-prefix maspex-prod \
  --state-value ALARM \
  --region eu-west-1 \
  --query 'MetricAlarms[*].{alarm:AlarmName,reason:StateReason}'

# ALB healthy host count PROD
AWS_PROFILE=maspex-cli aws elbv2 describe-target-groups \
  --region eu-west-1 \
  --query 'TargetGroups[?contains(TargetGroupName,`prod`)&&contains(TargetGroupName,`api`)].TargetGroupArn' \
  --output text | xargs -I{} \
  AWS_PROFILE=maspex-cli aws elbv2 describe-target-health \
    --target-group-arn {} --region eu-west-1

# Logi API PROD (ostatnie błędy)
AWS_PROFILE=maspex-cli aws logs filter-log-events \
  --log-group-name /maspex/prod/contest-service \
  --start-time $(date -v-10M +%s000) \
  --filter-pattern "error" \
  --region eu-west-1 --limit 50

# Redis PROD — EngineCPU live
AWS_PROFILE=maspex-cli aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name EngineCPUUtilization \
  --dimensions Name=CacheClusterId,Value=maspex-prod \
  --start-time $(date -u -v-10M +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 60 --statistics Average \
  --region eu-west-1 --profile maspex-cli \
  --query 'Datapoints[*].{time:Timestamp,cpu:Average}' | jq 'sort_by(.time)'

# Scaling target PROD — bieżące min/max
AWS_PROFILE=maspex-cli aws application-autoscaling describe-scalable-targets \
  --service-namespace ecs \
  --resource-id service/maspex-prod/maspex-api \
  --region eu-west-1
```

---

## 19. Krótka historia projektu

| Data | Zdarzenie |
|------|-----------|
| 2026-04-20 | Środowisko preprod — pierwsze wdrożenie |
| 2026-04-21 | UAT: fix CloudFront static caching (`max-age=0` override) |
| 2026-04-22 | UAT: fix CloudFront 502 dla `/_next/static/*` i `/landing/*` |
| 2026-04-23 | UAT: fix admin CloudFront 502 dla assetów |
| 2026-04-24 | UAT: CF `/_next/image*` caching (query_string=all) — wdrożone |
| 2026-04-26 | CloudFront audit — kompletna analiza distributions |
| 2026-04-28/29 | Pierwsze load testy UAT — autoscaling za wolny, Redis circuit open |
| 2026-05-05 | Cloud Detective scan — stan wyjściowy udokumentowany |
| 2026-05-08 | Zmiana połączenia Redis — nowy endpoint w secret |
| 2026-05-11 | Load test UAT — VOTE_CACHE_WRITETHROUGH_FAIL pod saturacją |
| 2026-05-14 | Load test kalibracja UAT — ASG min=12/max=30, nowe progi |
| 2026-05-15 | PROD↔UAT drift analysis; fix CF alias + DNS; PROD parity |
| 2026-05-15 | Load test UAT 8,835 req/s — **zdał** (autoscaling 12→30 w 4 min) |
| 2026-05-16 | Load test PROD 6,483 req/s — **zdał** (0 Target 5xx, p99=0.28s) |
| 2026-05-17 | Przygotowanie IaC do cutovera twojkapsel.pl; certyfikat 4-SAN |
| 2026-05-18 | IAM drift UAT fix; WAF admin otwarcie |
| **2026-05-18** | **CUTOVER: twojkapsel.pl LIVE ~10:50 CEST** |

---

## 20. Pending (po stanie 2026-05-18)

| Zadanie | Priorytet | Uwagi |
|---------|-----------|-------|
| Commit + push uncommitted changes (waf.tf, tfvars) na GitLab | WYSOKI | gałąź `feat/campaign-day-monitoring` |
| MR na GitLab: `feat/campaign-day-monitoring` → `main` | WYSOKI | |
| Monitoring 24h po go-live | WYSOKI | CloudWatch alarms, ECS, CF 5xx |
| Zweryfikować REDIS_URL w prod Secrets Manager | WYSOKI | `scripts/redis_secret_rotation.sh` |
| Naprawić Supabase SITE_URL w UAT | ŚREDNI | wskazuje na zły host |
| Zamknąć WAF admin panel PROD (po kampanii) | ŚREDNI | rollback: `block {}` |
| Naprawić maspex-bot (PROD + UAT) | ŚREDNI | FailedHealthChecks od 25+ dni |
| Redis FLUSHALL PROD (jeśli potrzebny) | NISKI | przez ECS Exec |
| Enhanced Container Insights PROD | NISKI | per-task diagnostyka |
| Container Insights retencja → 7 dni | NISKI | teraz 1 dzień |
| WAF REGIONAL (eu-west-1) | NISKI | gap LLZ |
| 9 pozostałych driftów IAM/autoscaling/tagi UAT | NISKI | czekają na decyzję |
