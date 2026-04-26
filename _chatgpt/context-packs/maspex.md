# Context Pack — maspex (stan: 2026-04-26)

> Wklej na początku sesji dotyczącej projektu maspex. Standalone.
> Aktualizuj po każdej sesji implementacyjnej.

---

## Kto i co

**Projekt:** maspex — platforma konkursowa dla klientów Maspex (polskie FMCG)
**Ja:** Senior DevOps/SRE MakoLab — właściciel infrastruktury AWS
**Klient:** aplikacja Next.js + .NET API, zarządzana przez dev team MakoLab
**IaC:** Terraform, repo lokalne `~/projekty/mako/aws-projects/infra-maspex`
**Profil AWS:** `maspex-cli` (IAM user + MFA, `awsume maspex-cli`)
**Region:** eu-west-1 | **Konto:** 969209893152

---

## Środowiska

| Env | Domena | CloudFront ID | ECS Cluster | Terraform env |
|-----|--------|--------------|-------------|---------------|
| UAT | `kapsel.makotest.pl` (API) | `E3J76RNXIE2YIG` | `maspex-uat` | `envs/uat` |
| UAT admin | `kapsel-admin-uat.makotest.pl` | `E3R9U1TWNUJZ11` | `maspex-uat` | `envs/uat` |
| Preprod | `twojkapsel.pl` + `www.twojkapsel.pl` | `E17VHHQJ29MVAB` | — | `envs/preprod` |
| Shared | — | — | — | `envs/shared` (ECR) |

VPC:
- UAT: 10.44.0.0/16
- Preprod: 10.45.0.0/16

---

## Architektura UAT (aktualny stan wdrożony)

```
Internet → CloudFront → ALB → ECS Fargate (maspex-uat cluster)
                                  ↓
                     Redis (ElastiCache) + Supabase/PostgREST (zewnętrzny)
```

**ECS services (UAT):**

| Service | Tasks | CPU | RAM | Uwagi |
|---------|-------|-----|-----|-------|
| `maspex-api` | 3 desired | 4096* | 8192* | Next.js contest API |
| `maspex-admin-panel` | 1 | — | — | panel admina |
| `maspex-bot` | 1 | — | — | bot |

*TF code: 4096/8192, live może być 1024/2048 — wymaga weryfikacji (ECS task definition drift)

**Redis (UAT):**
- Endpoint: `maspex-uat.zwowz5.0001.euw1.cache.amazonaws.com:6379`

**SNS alarms:** `arn:aws:sns:eu-west-1:969209893152:maspex-uat-alarms` → `jaroslaw.golab@makolab.com`

---

## CloudFront behaviors (UAT API — E3J76RNXIE2YIG)

| Path | Cache Policy | QS w cache key | Uwagi |
|------|-------------|----------------|-------|
| `/_next/static/*` | static_assets (min_ttl=86400) | none | OK |
| `/landing/*` | static_assets (min_ttl=86400) | none | OK |
| `/favicon.ico` | static_assets (min_ttl=86400) | none | wdrożono 2026-04-24 |
| `/_next/image*` | image_optimizer (query_string=all) | all | wdrożono 2026-04-24 |
| default | CachingDisabled | n/d | OK — dynamika |

**Krytyczne:** `/_next/image` musi mieć `query_string_behavior = "all"` — inaczej różne URL→w→q otrzymują ten sam obraz z cache.

---

## Co jest wdrożone (terraform apply wykonany)

- Preprod: VPC + ALB + Redis + ECS + CloudFront + HTTP→HTTPS redirect
- UAT CloudFront static caching: `/_next/static/*`, `/landing/*`, `/favicon.ico`, `/_next/image*`
- UAT admin CloudFront fix: `origin_request_policy_id` na ordered behaviors dla statyków
- UAT monitoring: SNS + CW alarms (11) + dashboard `maspex-uat-overview`
- CloudWatch Redis Circuit Open metric filter + alarm
- Dashboard Row 11-12: CF CacheHitRate + Redis Circuit Open
- Logs Insights: `top-request-paths`, `next-image-and-favicon-origin-hits`

---

## Co jest przygotowane ale NIE wdrożone (terraform plan OK, apply pending)

### Patch monitoring — load test readiness (przygotowany 2026-04-23/24)

`terraform plan`: 12 to add, 1 to change, 0 to destroy — wyłącznie monitoring/alarmy

Nowe zasoby:
- 6 log metric filters na `/maspex/uat/contest-service`:
  - `timeout`, `aborted`, `502`, `Timed out acquiring connection from connection pool`, `statement timeout`, `[GET_SLOGANS_COUNT]`
- Alarmy:
  - `maspex-uat-alb-api-target-response-time-high` — ALB p99
  - `maspex-uat-alb-api-target-connection-errors`
  - `maspex-uat-alb-elb-5xx`
  - `maspex-uat-ecs-api-running-below-desired`
  - `maspex-uat-cloudfront-api-5xx-rate`
  - `maspex-uat-api-downstream-log-errors`
- Dashboard rozszerzony o: ECS task count, ALB p99, CF API, API log signals, Redis CPU/memory/connections/evictions

**Jak wdrożyć:**
```bash
AWS_PROFILE=maspex-cli terraform -chdir=terraform/envs/uat plan -no-color
AWS_PROFILE=maspex-cli terraform -chdir=terraform/envs/uat apply
```

**Uwaga:** `terraform/envs/uat/main.tf` ma już dirty state z poprzedniej sesji (`maspex-api:coreapp-uat-387`, `cpu = 4096`, `memory = 8192`) — sprawdź historię przed apply.

---

## Patch aplikacyjny (lokalny, niecommitowany)

**Repo:** `~/projekty/mako/next-core-app`
**Plik:** `app/api/slogan/route.ts`

**Cel:** redukcja request amplification na hot path `GET /api/slogan?page=1&sortBy=votes_desc`

**Zmiana:** `resolveCount()` — dla requestów bez `search`:
- Redis-only best-effort (nie Supabase exact count)
- jeśli Redis null lub błąd → zwróć null (kod już obsługuje `totalPages: null`)

**Logging:** `[GET_SLOGANS_COUNT]` z `isSearch`, `countSource`, `durationMs`

**Status:** nie commitowane, wymaga `npm run typecheck` w CI przed mergem.

---

## Znane problemy i otwarte kwestie

| Problem | Stan | Priorytet |
|---------|------|-----------|
| ECS task definition drift (api v31 vs TF v24) | open — decyzja CI/CD vs TF | medium |
| ECS Auto Scaling brak | open — known gap | high (przed prod) |
| `/_next/image` min_ttl=0 | wdrożone bezpiecznie; rozważyć 86400 po confirm app team | low |
| Redis endpoint do Secrets Manager preprod | TODO | medium |
| Warning `modules/alb/main.tf:65` | niekrytyczny | low |
| CloudFront additional metrics wyłączone? | sprawdzić czy CacheHitRate widgety działają | low |

---

## Kluczowe komendy operacyjne

```bash
# Status ECS
AWS_PROFILE=maspex-cli aws ecs describe-services \
  --cluster maspex-uat \
  --services maspex-api \
  --query 'services[0].{taskDef:taskDefinition,running:runningCount,desired:desiredCount}' \
  --region eu-west-1

# Terraform plan (bez apply)
AWS_PROFILE=maspex-cli terraform -chdir=terraform/envs/uat plan -no-color

# CF cache headers
curl -sI "https://kapsel.makotest.pl/favicon.ico" | grep -i "x-cache\|cache-control\|age"

# Redis przez ECS Exec
aws ecs execute-command \
  --cluster maspex-uat \
  --task <TASK_ID> \
  --container api \
  --command "/bin/sh" \
  --interactive \
  --region eu-west-1
```

---

## Dostęp lukasz.fuchs

- Policy `maspex-uat-redis-ssm-access` (v2) przypisana do `lukasz.fuchs@makolab.com`
- Uprawnienia: ECS Exec + SSM + cloudshell:*
- Wymaga: MFA skonfigurowane w IAM

---

## Load testing

Kontekst testów obciążeniowych w osobnym pliku: `maspex-load-testing.md`

Skrót:
- Narzędzie: AWS Distributed Load Testing (SO0062), CFN stack `maspex-load-testing`
- Status wdrożenia: **NIE wdrożone** — plan gotowy, ~1h pracy inżyniera
- Błąd z testu Łukasza: 7.53% błędów na `/api/slogan/vote` — hipoteza: Redis/DB pool exhaustion lub brak Auto Scaling
- Target środowisko testów: UAT `kapsel.makotest.pl`

---

## Preprod — TODO przed go-live

```bash
# Wpisać Redis endpoint do Secrets Manager
aws secretsmanager put-secret-value \
  --secret-id arn:aws:secretsmanager:eu-west-1:969209893152:secret:maspex/preprod/api-STbBy3 \
  --secret-string '{"ConnectionStrings__Redis":"redis://maspex-preprod.zwowz5.0001.euw1.cache.amazonaws.com:6379"}' \
  --profile maspex-cli --region eu-west-1
```

DNS klienta (wysłać / potwierdzić):
```
twojkapsel.pl       CNAME   d1epwako2iigq8.cloudfront.net
www.twojkapsel.pl   CNAME   d1epwako2iigq8.cloudfront.net
```

---

## Wzorzec CloudFront + ALB host-based routing (lekcja operacyjna)

Jeśli CloudFront ma ordered behavior dla statycznych ścieżek do ALB — każdy ordered behavior musi mieć `origin_request_policy_id = Managed-AllViewer` (216adef6-5c7f-47e4-b989-5492eafa07d3), nie tylko default behavior. Brak tego → 502 Error from cloudfront na statykach mimo że dynamiczne ścieżki działają.
