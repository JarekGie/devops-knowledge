# Context Pack — maspex (stan live: 2026-05-15)

> Wklej na początku sesji dotyczącej projektu maspex. Standalone.
> Dane zweryfikowane live z AWS.

---

## Kto i co

**Projekt:** maspex — platforma konkursowa dla klientów Maspex (polskie FMCG)
**Ja:** Senior DevOps/SRE MakoLab — właściciel infrastruktury AWS
**Klient:** aplikacja Next.js (frontend/API coreapp) + bot worker (.NET), zarządzana przez dev team MakoLab
**IaC:** Terraform, repo lokalne `~/projekty/mako/aws-projects/infra-maspex`
**Profil AWS:** `maspex-cli` (IAM user + MFA, `awsume maspex-cli`)
**Region:** eu-west-1 | **Konto:** 969209893152

---

## Środowiska — przegląd

| Env | Cluster ECS | Terraform env | VPC CIDR |
|-----|-------------|---------------|----------|
| UAT | `maspex-uat` | `envs/uat` | 10.44.0.0/16 |
| PROD | `maspex-prod` | `envs/prod` | 10.44.0.0/16 |
| Preprod (zasłepka) | — | `envs/preprod` | 10.45.0.0/16 |

---

## UAT — pełna konfiguracja

### CloudFront (UAT)

| ID | Domena CF | Alias (CNAME) | DNS → CF | WAF |
|----|-----------|---------------|----------|-----|
| `E3J76RNXIE2YIG` | `d3p408gzqcntg6.cloudfront.net` | `kapsel.makotest.pl` | ✅ OK | `maspex-uat-public-uat-allowlist` |
| `E3R9U1TWNUJZ11` | `dglmraezzepmo.cloudfront.net` | `kapsel-admin-uat.makotest.pl` | ✅ OK | `maspex-uat-admin-panel-allowlist` |

Obie dystrybucje: origin = ALB `maspex-uat`, protocol `https-only`, `AllViewer` origin request policy (forward Host header).

### ALB (UAT)

- Nazwa: `maspex-uat`
- DNS: `maspex-uat-1361582173.eu-west-1.elb.amazonaws.com`
- ARN: `arn:aws:elasticloadbalancing:eu-west-1:969209893152:loadbalancer/app/maspex-uat/68317764a66425bd`

**HTTPS listener certy (SNI):**

| Short ID | Pokrywa domeny | Rola |
|----------|----------------|------|
| `33c1a772` | `kapsel-admin-uat.makotest.pl`, `www.kapsel-admin-uat.makotest.pl` | DEFAULT |
| `99e64abc` | `kapsel.makotest.pl`, `www.kapsel.makotest.pl` | SNI |

**Listener rules (HTTPS, priority order):**

| Priority | Warunek | Target Group |
|----------|---------|-------------|
| 20 | `host=kapsel.makotest.pl` AND `path=/bots/*` | `maspex-uat-bot` |
| 100 | `host=kapsel.makotest.pl` | `maspex-uat-api-3000` |
| 200 | `host=kapsel-admin-uat.makotest.pl` | `maspex-uat-admin-3000` |
| default | — | 503 fixed response |

### ECS Services (UAT)

| Serwis | Task Definition | Desired | Running | Status |
|--------|----------------|---------|---------|--------|
| `maspex-api` | `maspex-api:65` | 12 | 12 | ✅ healthy |
| `maspex-admin-panel` | `maspex-admin-panel:27` | 1 | 1 | ✅ healthy |
| `maspex-bot` | `maspex-bot:10` | 1 | 1 | ✅ running |
| `maspex-redis` | `maspex-redis:2` | 1 | 1 | ✅ running |

Target group health: api 12/12, admin 1/1, bot 0/2 (⚠️ bot TG unhealthy — znany issue).

### ElastiCache (UAT)

- Cluster ID: `maspex-uat`
- Node type: `cache.t3.medium`
- Engine: Redis 7.1.0
- Status: `available`

### Sekrety UAT

Secret name: `maspex/uat/api` (ARN suffix `-STbBy3`)

| Klucz | Opis |
|-------|------|
| `ConnectionStrings__Redis` | Redis connection string → injektowany jako `REDIS_URL` |
| `SUPABASE_JWT_SECRET` | JWT secret Supabase — walidacja tokenów w `@supabase/ssr` |
| `JWT_SECRET` | Generowanie tokenów w load test fleet (= `SUPABASE_JWT_SECRET`) |
| `JWT_KID` | Key ID w headerze `kid` tokenów JWT (stała arbitralna wartość) |

---

## PROD — pełna konfiguracja

### CloudFront (PROD)

| ID | Domena CF | Alias (CNAME) | DNS → CF | Rola | WAF |
|----|-----------|---------------|----------|------|-----|
| `E33PUJBAQ533K0` | `d1w5bz7itj42sz.cloudfront.net` | **docelowo:** `test.twojkapsel.pl` + `www.test.twojkapsel.pl` | ⚠️ DNS wskazuje na złą dystrybucję (patrz niżej) | API / coreapp | `maspex-prod-public-app-allowlist` |
| `E32AZKJ5SJSDSV` | `dfx1ac92hj3uw.cloudfront.net` | `kapsel-prod.makotest.pl` | ❌ brak rekordu DNS | Admin panel | `maspex-prod-admin-panel-allowlist` |

**Stan DNS (live 2026-05-15):**

| Domena | Aktualny CNAME | Powinno być |
|--------|----------------|-------------|
| `test.twojkapsel.pl` | `dfx1ac92hj3uw.cloudfront.net` (admin panel E32) | `d1w5bz7itj42sz.cloudfront.net` (API E33) |
| `www.test.twojkapsel.pl` | brak rekordu | `d1w5bz7itj42sz.cloudfront.net` |
| `kapsel-prod.makotest.pl` | brak rekordu DNS | `dfx1ac92hj3uw.cloudfront.net` |

**Pending Terraform apply:** CF distribution `E33PUJBAQ533K0` czeka na aktualizację aliasów → `test.twojkapsel.pl` + `www.test.twojkapsel.pl` (blokowane przez błędny DNS — `CNAMEAlreadyExists`). Po zmianie DNS w Cloudflare wymagany `terraform apply` w `envs/prod`.

Obie dystrybucje: origin = ALB `maspex-prod`, protocol `https-only`, `AllViewer` origin request policy.

### ALB (PROD)

- Nazwa: `maspex-prod`
- DNS: `maspex-prod-1795571755.eu-west-1.elb.amazonaws.com`
- ARN: `arn:aws:elasticloadbalancing:eu-west-1:969209893152:loadbalancer/app/maspex-prod/e90292a1ad614fc5`

**HTTPS listener certy (SNI):**

| Short ID | Pokrywa domeny | Rola |
|----------|----------------|------|
| `a139f9a4` | `kapsel-prod.makotest.pl`, `www.kapsel-prod.makotest.pl` | DEFAULT |
| `d4bbfef0` | `test.twojkapsel.pl`, `www.test.twojkapsel.pl` | SNI |
| `fd2f0c7c` | `kapsel-api-prod.makotest.pl`, `www.kapsel-api-prod.makotest.pl` | SNI (legacy) |

**Listener rules (HTTPS, priority order):**

| Priority | Warunek | Target Group |
|----------|---------|-------------|
| 20 | `host=[test.twojkapsel.pl, www.test.twojkapsel.pl]` AND `path=/bots/*` | `maspex-prod-bot` |
| 100 | `host=[test.twojkapsel.pl, www.test.twojkapsel.pl]` | `maspex-prod-api-3000` |
| 200 | `host=kapsel-prod.makotest.pl` | `maspex-prod-admin-3000` |
| default | — | 503 fixed response |

### ECS Services (PROD)

| Serwis | Task Definition | Desired | Running | Status |
|--------|----------------|---------|---------|--------|
| `maspex-api` | `maspex-prod-api:4` | 9 | 9 | ✅ healthy |
| `maspex-admin-panel` | `maspex-prod-admin-panel:3` | 1 | 1 | ✅ healthy |
| `maspex-bot` | `maspex-prod-bot:2` | 1 | 2 | ⚠️ running=2 (rolling, TG 0/2) |

Target group health: api 9/9, admin 1/1, bot 0/2 (⚠️).

**Konwencja nazewnicza ECS:**
- Nazwa serwisu: bez sufixu `prod` (np. `maspex-api`) — identycznie jak UAT
- Nazwa task definition family: z sufiksem `prod` (np. `maspex-prod-api`) — oddziela rewizje UAT/PROD

### ElastiCache (PROD)

- Cluster ID: `maspex-prod`
- Node type: `cache.t3.medium`
- Engine: Redis 7.1.0
- Status: `available`

### Sekrety PROD

Secret name: `maspex/prod/api` (ARN suffix `-z6g7eq`)
Full ARN: `arn:aws:secretsmanager:eu-west-1:969209893152:secret:maspex/prod/api-z6g7eq`

| Klucz | Opis |
|-------|------|
| `ConnectionStrings__Redis` | Redis connection string → injektowany jako `REDIS_URL` |
| `SUPABASE_JWT_SECRET` | JWT secret Supabase — walidacja tokenów w `@supabase/ssr` |

PROD nie ma `JWT_SECRET` / `JWT_KID` — load testy uruchamiane są przez UAT.

---

## Zasłepka / preprod

| CF ID | Alias | DNS | Opis |
|-------|-------|-----|------|
| `E17VHHQJ29MVAB` | `twojkapsel.pl`, `www.twojkapsel.pl` | ✅ OK | Static S3, cookie banner GDPR |

S3 bucket: `s3://maspex-preprod-static-...` (OAC), `index.html` + `instrukcja-usuniecia-konta.pdf`.

---

## ACM Certyfikaty

| Short ID | Region | Pokrywa |
|----------|--------|---------|
| `caed9d07` | us-east-1 | `test.twojkapsel.pl`, `www.test.twojkapsel.pl` — dla CF API (E33) |
| `369af310` | us-east-1 | `kapsel-prod.makotest.pl`, `www.kapsel-prod.makotest.pl` — dla CF admin (E32) |
| `3247fa27` | us-east-1 | `kapsel-api-prod.makotest.pl` — legacy, już nieużywany przez CF |
| `d4bbfef0` | eu-west-1 | `test.twojkapsel.pl`, `www.test.twojkapsel.pl` — na ALB PROD (SNI) |
| `a139f9a4` | eu-west-1 | `kapsel-prod.makotest.pl` — DEFAULT cert ALB PROD |
| `fd2f0c7c` | eu-west-1 | `kapsel-api-prod.makotest.pl` — legacy SNI na ALB PROD |

---

## Pending actions (2026-05-15)

1. **Cloudflare DNS (twojkapsel.pl):**
   - Zmień `test.twojkapsel.pl` CNAME: `dfx1ac92hj3uw.cloudfront.net` → `d1w5bz7itj42sz.cloudfront.net`
   - Dodaj `www.test.twojkapsel.pl` CNAME → `d1w5bz7itj42sz.cloudfront.net`

2. **PowerDNS (makotest.pl):**
   - Dodaj `kapsel-prod.makotest.pl` CNAME → `dfx1ac92hj3uw.cloudfront.net`

3. **Terraform apply (envs/prod):**
   - Po zmianie DNS: `AWS_PROFILE=maspex-cli terraform plan -out=/tmp/cf-api-domain.tfplan && terraform apply /tmp/cf-api-domain.tfplan`
   - Zmiana: CF `E33PUJBAQ533K0` aliasy → `test.twojkapsel.pl` + `www.test.twojkapsel.pl`, cert → `caed9d07`

---

## Architektura przepływu żądania (PROD docelowa)

```
Użytkownik → test.twojkapsel.pl
  → Cloudflare DNS → d1w5bz7itj42sz.cloudfront.net (CF E33PUJBAQ533K0)
  → WAF: maspex-prod-public-app-allowlist
  → Origin: ALB maspex-prod (HTTPS, Host: test.twojkapsel.pl)
  → ALB rule prio 100: host=test.twojkapsel.pl → TG maspex-prod-api-3000
  → ECS maspex-api (task def maspex-prod-api:4, 9 tasków)
  → ElastiCache maspex-prod (Redis 7.1, t3.medium)
  → Secrets: maspex/prod/api (REDIS_URL + SUPABASE_JWT_SECRET)

Bot webhook → test.twojkapsel.pl/bots/*
  → ALB rule prio 20: host=test.twojkapsel.pl AND path=/bots/* → TG maspex-prod-bot
  → ECS maspex-bot (task def maspex-prod-bot:2)

Admin panel → kapsel-prod.makotest.pl  [DNS pending]
  → CF E32AZKJ5SJSDSV → ALB rule prio 200 → TG maspex-prod-admin-3000
  → ECS maspex-admin-panel (task def maspex-prod-admin-panel:3)
```
