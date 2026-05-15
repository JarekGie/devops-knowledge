---
title: PROD vs UAT drift analysis — 2026-05-15
client: mako
project: maspex
domain: client-work
document_type: drift-analysis
classification: internal
source_of_truth: true
last_verified: "2026-05-15"
tags:
  - maspex
  - prod
  - drift
  - cloudfront
  - dns
  - ecs
---

# PROD vs UAT — analiza driftów 2026-05-15

## Executive Summary

Stan PROD jest **prawie zgodny** z UAT. Istnieje **1 krytyczny drift** w Terraform — CloudFront API distribution ma stary alias `kapsel-api-prod.makotest.pl` zamiast `test.twojkapsel.pl`. Terraform plan jest czysty (1 zmiana, 0 destroys). Blokery apply: DNS.

- ECS naming: ✓ poprawne
- ALB routing: ✓ poprawne  
- ALB certy: ✓ poprawne
- Admin CF (`kapsel-prod.makotest.pl`): ✓ OK
- DNS `kapsel-prod.makotest.pl`: ✓ JUŻ USTAWIONE
- API CF (`test.twojkapsel.pl`): ✗ alias i cert do zmiany przez `terraform apply`
- DNS `test.twojkapsel.pl`: ✗ wskazuje na zły CF distribution (Cloudflare)
- DNS `www.test.twojkapsel.pl`: ✗ brak rekordu

---

## B. UAT vs PROD Drift Matrix

| Obszar | UAT | PROD | Drift | Severity | Action |
|--------|-----|------|-------|----------|--------|
| CF API alias | `kapsel.makotest.pl` | `kapsel-api-prod.makotest.pl` (live) / `test.twojkapsel.pl` (TF code) | **DRIFT — CF alias ≠ TF code** | KRYTYCZNY | `terraform apply` |
| CF API cert (us-east-1) | `ab337320` (kapsel.makotest.pl) | `3247fa27` (kapsel-api-prod) / `caed9d07` (TF code: test.twojkapsel.pl) | **DRIFT — live cert ≠ TF code** | KRYTYCZNY | `terraform apply` |
| CF admin alias | `kapsel-admin-uat.makotest.pl` | `kapsel-prod.makotest.pl` | OK (env-specific) | — | — |
| CF admin cert | `369af310` (kapsel-admin-uat) | `369af310` wait no — `369af310` (kapsel-prod.makotest.pl) | OK | — | — |
| DNS API domain | `kapsel.makotest.pl` → d3p408gzq (CF UAT API) | `test.twojkapsel.pl` → `dfx1ac92hj3uw` (BŁĘDNIE na admin CF!) | **DNS DRIFT** | KRYTYCZNY | Cloudflare CNAME change |
| DNS API www | brak (UAT nie używa www) | `www.test.twojkapsel.pl` → brak rekordu | DRIFT | WAŻNY | Dodać CNAME w Cloudflare |
| DNS admin | `kapsel-admin-uat.makotest.pl` → d3p... | `kapsel-prod.makotest.pl` → `dfx1ac92hj3uw` ✓ | **OK — już ustawione** | — | — |
| ALB routing prio 100 | host=kapsel.makotest.pl → api TG | host=test.twojkapsel.pl + www → api TG | OK (env-specific) | — | — |
| ALB routing prio 200 | host=kapsel-admin-uat → admin TG | host=kapsel-prod.makotest.pl → admin TG | OK | — | — |
| ALB routing prio 20 | host=kapsel.makotest.pl + /bots/* → bot TG | host=test.twojkapsel.pl + www + /bots/* → bot TG | OK | — | — |
| ALB HTTPS cert (primary) | `33c1a772` (kapsel-admin-uat) | `a139f9a4` (kapsel-prod.makotest.pl) | OK (env-specific) | — | — |
| ALB HTTPS cert API | `99e64abc` (kapsel.makotest.pl) | `d4bbfef0` (test.twojkapsel.pl) ✓ + `fd2f0c7c` (kapsel-api-prod — old) | OK (d4bbfef0 present) | — | Cleanup fd2f0c7c po migracji |
| ECS service maspex-api | desired 9, running 9 | desired 9, running 9 | OK | — | — |
| ECS service maspex-admin-panel | desired 1, running 1 | desired 1, running 1 | OK | — | — |
| ECS service maspex-bot | desired 1, running 1 | desired 1, running **0** ⚠ | **BOT DOWN** | WAŻNY | Diagnoza health check |
| ECS naming — service | `maspex-api`, `maspex-admin-panel`, `maspex-bot` | `maspex-api`, `maspex-admin-panel`, `maspex-bot` | OK | — | — |
| ECS naming — task def | `maspex-api`, `maspex-admin-panel`, `maspex-bot` | `maspex-prod-api`, `maspex-prod-admin-panel`, `maspex-prod-bot` | OK (env-specific) | — | — |
| Secrets — REDIS_URL | `maspex/uat/api:ConnectionStrings__Redis` | `maspex/prod/api-z6g7eq:ConnectionStrings__Redis` | OK | — | — |
| Secrets — SUPABASE_JWT_SECRET | z `maspex/uat/api` | z `maspex/prod/api-z6g7eq` | OK | — | — |
| Secrets — JWT_SECRET/JWT_KID | obecne w UAT | nieobecne w PROD | OK (intended) | — | — |
| WAF | brak (UAT) | CloudFront WAF IP allowlist (MakoLab) | OK (PROD ma więcej zabezpieczeń) | — | — |

---

## C. Domain / Routing Verdict

| Domena | Cel | Aktualny stan | OK? |
|--------|-----|---------------|-----|
| `kapsel.makotest.pl` → `maspex-api` (UAT) | d3p408gzq → UAT ALB → api TG | ✓ DNS + CF + ALB OK | ✓ |
| `kapsel-admin-uat.makotest.pl` → `maspex-admin-panel` (UAT) | dglmraez → UAT ALB → admin TG | ✓ OK | ✓ |
| `test.twojkapsel.pl` → `maspex-api` (PROD) | DNS → `dfx1ac92hj3uw` (admin CF!) ← BŁĄD | ✗ DNS wskazuje na zły CF | ✗ |
| `kapsel-prod.makotest.pl` → `maspex-admin-panel` (PROD) | DNS → `dfx1ac92hj3uw` (admin CF) → ALB → admin TG | ✓ DNS poprawne, CF alias OK | ✓ |

---

## D. Certificates Verdict

| Cert ARN (suffix) | Region | Domeny | Gdzie używany | OK? | Blocker? |
|-------------------|--------|--------|---------------|-----|---------|
| `ab337320` | us-east-1 | `kapsel.makotest.pl` | CF E3J76RNXIE2YIG (UAT API) | ✓ | nie |
| `6027584b` | us-east-1 | `kapsel-admin-uat.makotest.pl` | CF E3R9U1TWNUJZ11 (UAT admin) | ✓ | nie |
| `caed9d07` | us-east-1 | `test.twojkapsel.pl`, `www.test.twojkapsel.pl` | CF E33PUJBAQ533K0 (PROD API) — po apply | ✓ ISSUED | nie |
| `369af310` | us-east-1 | `kapsel-prod.makotest.pl`, `www.kapsel-prod.makotest.pl` | CF E32AZKJ5SJSDSV (PROD admin) | ✓ | nie |
| `3247fa27` | us-east-1 | `kapsel-api-prod.makotest.pl`, `www...` | CF E33PUJBAQ533K0 (live, stary cert) | DO ZASTĄPIENIA przez apply | tak (blokuje parity) |
| `d4bbfef0` | eu-west-1 | `test.twojkapsel.pl`, `www.test.twojkapsel.pl` | ALB PROD HTTPS listener (SNI) | ✓ już attached | nie |
| `a139f9a4` | eu-west-1 | `kapsel-prod.makotest.pl`, `www...` | ALB PROD HTTPS (primary) | ✓ | nie |
| `fd2f0c7c` | eu-west-1 | `kapsel-api-prod.makotest.pl`, `www...` | ALB PROD (stary domain cert, extra) | harmless, do usunięcia | nie |

---

## E. ECS Naming Verdict

| Zasób | Wzorzec UAT | PROD | Zgodność |
|-------|------------|------|----------|
| ECS service name | `maspex-{svc}` | `maspex-{svc}` (bez prod) | ✓ |
| Task def family | `maspex-{svc}` | `maspex-prod-{svc}` | ✓ (prod marker w TD) |
| ECS cluster | `maspex-uat` | `maspex-prod` | ✓ (env-specific) |
| TG naming | `maspex-uat-{svc}-{port}` | `maspex-prod-{svc}-{port}` | ✓ |

Zasada: service bez `prod`, task definition family z `prod` — **zachowana prawidłowo**.

---

## F. Secrets / Blockers

| Element | Status | Uwagi |
|---------|--------|-------|
| `maspex/prod/api-z6g7eq` | ARN znany z tfvars | Nie zgaduję wartości |
| `ConnectionStrings__Redis` → `REDIS_URL` | mapowanie poprawne w main.tf | ✓ |
| `SUPABASE_JWT_SECRET` | mapowanie poprawne w main.tf | ✓ |
| `JWT_SECRET` / `JWT_KID` | nieobecne w PROD — zgodne z wymaganiami | ✓ intentional |
| **BLOCKER**: DNS `test.twojkapsel.pl` → zły CF | Cloudflare wymaga ręcznej zmiany CNAME | ✗ DNS nie może być zmienione przez Terraform |
| **BLOCKER**: DNS `www.test.twojkapsel.pl` brak | Cloudflare wymaga dodania CNAME | ✗ |

---

## G. Changes Made

### Plik: `terraform/envs/prod/terraform.tfvars`

Zaktualizowano comment sekcji `API domain — PROD`:
- stary comment opisywał `kapsel-api-prod.makotest.pl` (stara domena)
- nowy comment: dokumentuje aktualny stan (`test.twojkapsel.pl`), pending DNS actions, stan `kapsel-prod.makotest.pl`

Wartości nie zmienione (kod był już poprawny).

---

## H. Validation Result

| Test | Wynik |
|------|-------|
| `terraform fmt -check` | ✓ PASS (exit 0) |
| `terraform validate` | ✓ PASS ("Success! The configuration is valid.") |
| `terraform plan` | ✓ 1 change, 0 add, 0 destroy |

### Plan summary

```
# module.cloudfront_site_api.aws_cloudfront_distribution.this[0] will be updated in-place
~ aliases = [
    - "kapsel-api-prod.makotest.pl",
    + "test.twojkapsel.pl",
    + "www.test.twojkapsel.pl",
  ]
~ viewer_certificate.acm_certificate_arn:
    "3247fa27-..." → "caed9d07-..."

Plan: 0 to add, 1 to change, 0 to destroy.
```

### Czy plan jest gotowy do apply?

**NIE — pending blocker DNS.** Terraform apply dla CloudFront jest technicznie bezpieczny (cert `caed9d07` jest ISSUED, obejmuje `test.twojkapsel.pl`). Ale zaraz po apply, ruch nadal trafi na zły CF (bo DNS Cloudflare wskazuje na admin panel). Aby plan był kompletny, DNS musi być zmieniony tuż po apply.

**Kolejność operacji do apply:**
1. `terraform apply` — zmieni CF API alias i cert (bezpieczne, 1 minuta)
2. Cloudflare: zmień `test.twojkapsel.pl` CNAME: `dfx1ac92hj3uw` → `d1w5bz7itj42sz.cloudfront.net`
3. Cloudflare: dodaj `www.test.twojkapsel.pl` CNAME → `d1w5bz7itj42sz.cloudfront.net`

---

## I. Final Verdict

| Pytanie | Odpowiedź |
|---------|-----------|
| Czy drifty są usunięte? | **NIE** — CF API alias/cert drift pozostaje (pending apply + DNS) |
| Co blokuje pełne parity? | DNS Cloudflare (test.twojkapsel.pl wskazuje na zły CF) |
| Stan PROD? | Częściowo zgodny z UAT — routing ALB, ECS, admin CF: OK; API CF + DNS: ✗ |
| Terraform kod? | Poprawny — kod już opisuje docelowy stan |
| Czy `terraform apply` jest safe? | Tak, technicznie. Blokuje DNS, nie Terraform. |
| Bot PROD | Running 0/desired 1 — health check failure — ten sam wzorzec co UAT bot |

**Następne kroki:**
1. `terraform apply` (envs/prod) — zaakceptować plan 1 change
2. Cloudflare DNS: zmień `test.twojkapsel.pl` + dodaj `www.test.twojkapsel.pl`
3. Zweryfikować routing: `curl -vI https://test.twojkapsel.pl/api/health`
4. Zbadać PROD bot health check failure

---

## J. Files / Resources

### Pliki przeczytane
- `terraform/envs/prod/main.tf`
- `terraform/envs/prod/terraform.tfvars`
- `terraform/envs/prod/locals.tf`
- `terraform/envs/prod/variables.tf`
- `terraform/envs/prod/waf.tf`
- `terraform/envs/prod/moved.tf`
- `terraform/envs/uat/terraform.tfvars`
- `terraform/envs/uat/main.tf` (partial)
- `terraform/modules/alb-routing/main.tf`
- vault: `maspex-context.md`, `cloudfront-audit-2026-04-26.md`

### Pliki zmienione
- `terraform/envs/prod/terraform.tfvars` — zaktualizowano comment sekcji api_domain

### AWS resources inspected (live, 2026-05-15)
- CloudFront: E33PUJBAQ533K0, E32AZKJ5SJSDSV, E3J76RNXIE2YIG, E3R9U1TWNUJZ11, E17VHHQJ29MVAB
- ALB PROD: maspex-prod-1795571755 (listeners, rules, certs)
- ECS cluster maspex-prod: services maspex-api, maspex-admin-panel, maspex-bot
- ACM: caed9d07 (us-east-1), 3247fa27 (us-east-1), fd2f0c7c (eu-west-1)
- Target groups: maspex-prod-api-3000, maspex-prod-admin-3000, maspex-prod-bot
- DNS: `test.twojkapsel.pl`, `kapsel-prod.makotest.pl`, `www.test.twojkapsel.pl`
