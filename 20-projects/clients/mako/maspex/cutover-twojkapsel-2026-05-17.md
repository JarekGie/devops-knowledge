---
title: "Cutover plan — twojkapsel.pl — 2026-05-17"
date: 2026-05-17
type: cutover-plan
environment: prod
status: plan-ready / BLOCKED-cert
---

## A. Executive Summary

IaC przygotowane, `terraform validate` czyste, `terraform plan` zakończony sukcesem (1 add, 12 change, 0 destroy). Plan zapisany jako `cutover.tfplan`.

**BLOCKER przed apply:** certyfikat ACM us-east-1 `1e70d4ef` (twojkapsel.pl cert) NIE pokrywa `test.twojkapsel.pl` ani `www.test.twojkapsel.pl`. CF API odrzuci apply jeśli alias nie jest pokryty przez cert. Wymagane: nowy 4-SAN cert lub rezygnacja z zachowania test.* jako CF alias.

**OSTRZEŻENIE:** plan zawiera niezamierzoną zmianę autoscalingu (`max_capacity 30→15`, `min_capacity 5→9`) — TF cofa ręczne zmiany z dnia load testu. Decyzja wymagana przed apply.

---

## Status certyfikatu

| ARN (suffix) | SANs | Status |
|---|---|---|
| f1370536 | twojkapsel.pl, www.twojkapsel.pl, test.twojkapsel.pl, www.test.twojkapsel.pl | **ISSUED** ✅ |

Walidacja DNS po stronie klienta (Cloudflare). Rekordy CNAME: `dns-validation-teams-msg.md`

Sprawdzenie statusu:
```bash
aws acm describe-certificate \
  --certificate-arn "arn:aws:acm:us-east-1:969209893152:certificate/f1370536-7607-4a75-83f9-f261afce97f2" \
  --region us-east-1 --profile maspex-cli \
  --query 'Certificate.Status' --output text
```

## B. Discovery

### CloudFront distributions (prod)

| Distribution | ID | Domain | Aktualny cert (us-east-1) | Aktualny aliasy |
|---|---|---|---|---|
| API/app | E33PUJBAQ533K0 | d1w5bz7itj42sz.cloudfront.net | caed9d07 (test.twojkapsel.pl) | test.twojkapsel.pl, www.test.twojkapsel.pl |
| Landing/admin | E32AZKJ5SJSDSV | dfx1ac92hj3uw.cloudfront.net | 369af310 (kapsel-prod.makotest.pl) | kapsel-prod.makotest.pl |

### Certyfiakty ACM — us-east-1

| ARN (suffix) | Domena | SANs | Status |
|---|---|---|---|
| caed9d07 | test.twojkapsel.pl | test.twojkapsel.pl, www.test.twojkapsel.pl | ISSUED |
| 1e70d4ef | twojkapsel.pl | twojkapsel.pl, www.twojkapsel.pl | ISSUED |
| 369af310 | kapsel-prod.makotest.pl | kapsel-prod.makotest.pl | ISSUED |

### Certyfikaty ACM — eu-west-1 (ALB)

| ARN (suffix) | Domena | SANs | Użycie |
|---|---|---|---|
| d4bbfef0 | test.twojkapsel.pl | test.twojkapsel.pl | `aws_lb_listener_certificate.twojkapsel` |
| ddced1bc | twojkapsel.pl | twojkapsel.pl, www.twojkapsel.pl | ISSUED, nie użyty — NOWY zasób |
| a139f9a4 | kapsel-prod.makotest.pl | kapsel-prod.makotest.pl | default cert na ALB |

### Aktualny dostęp do prod

WAF `public_app_allowlist`: `default_action { block {} }` + allowlist: 195.117.107.110/32 (MakoLab), 91.233.19.251/32 (MakoLab). Cały ruch publiczny BLOKOWANY.

---

## C. Zmiany przygotowane w IaC

### terraform.tfvars

```diff
- api_domain = "test.twojkapsel.pl"
+ api_domain = "twojkapsel.pl"

- api_cloudfront_certificate_arn = "arn:aws:acm:us-east-1:...caed9d07..."  # test.* cert
+ api_cloudfront_certificate_arn = "arn:aws:acm:us-east-1:...1e70d4ef..."  # twojkapsel.pl cert
```

### main.tf — CF aliases

```diff
  module "cloudfront_site_api" {
-   aliases = ["www.test.twojkapsel.pl"]
+   aliases = ["www.twojkapsel.pl", "test.twojkapsel.pl", "www.test.twojkapsel.pl"]
```

### main.tf — ALB routing aliases

```diff
  module "alb_routing" {
-   api_domain_aliases = ["www.test.twojkapsel.pl"]
+   api_domain_aliases = ["www.twojkapsel.pl", "test.twojkapsel.pl", "www.test.twojkapsel.pl"]
```

### main.tf — nowy zasób ALB listener cert

```hcl
resource "aws_lb_listener_certificate" "twojkapsel_prod" {
  listener_arn    = module.alb.https_listener_arn
  certificate_arn = "arn:aws:acm:eu-west-1:969209893152:certificate/ddced1bc-fb38-46ab-a84e-bfb0e173314c"
}
```

### waf.tf — otwarcie na 0.0.0.0/0

```diff
  resource "aws_wafv2_web_acl" "public_app_allowlist" {
    default_action {
-     block {}
+     allow {}
    }
```

---

## D. Wynik walidacji

```
terraform fmt     ✓ (1 plik sformatowany: terraform.tfvars)
terraform validate ✓ The configuration is valid.
terraform plan    ✓ Plan: 1 to add, 12 to change, 0 to destroy.
                    Saved: cutover.tfplan
```

### Pełna lista zasobów w planie

| Zasób | Akcja | Szczegóły |
|---|---|---|
| `aws_lb_listener_certificate.twojkapsel_prod` | CREATE | ALB cert ddced1bc (twojkapsel.pl eu-west-1) |
| `aws_wafv2_web_acl.public_app_allowlist` | UPDATE | default_action: block → allow |
| `aws_wafv2_ip_set.loadtest_allowlist` | UPDATE | 4 fleet IPs → empty (+ opis) |
| `aws_wafv2_ip_set.public_app_allowlist` | UPDATE | opis: test.twojkapsel.pl → twojkapsel.pl |
| `aws_wafv2_ip_set.public_app_supabase_ipv6` | UPDATE | opis: test.twojkapsel.pl → twojkapsel.pl |
| `module.alb_routing.aws_lb_listener_rule.api[0]` | UPDATE | host_header: dodano twojkapsel.pl, www.twojkapsel.pl |
| `module.alb_routing.aws_lb_listener_rule.bot[0]` | UPDATE | host_header: dodano twojkapsel.pl, www.twojkapsel.pl |
| `module.cloudfront_site_api.aws_cloudfront_distribution.this[0]` | UPDATE | aliases +twojkapsel.pl +www.twojkapsel.pl; cert caed9d07→1e70d4ef |
| `module.cloudfront_site_api.aws_cloudfront_cache_policy.static_assets[0]` | UPDATE | rename: test-twojkapsel-pl → twojkapsel-pl |
| `module.cloudfront_site_api.aws_cloudfront_cache_policy.image_optimizer[0]` | UPDATE | rename |
| `module.cloudfront_site_api.aws_cloudfront_cache_policy.api["/api/slogan"]` | UPDATE | rename |
| `module.cloudfront_site_api.aws_cloudfront_origin_request_policy.api["/api/slogan"]` | UPDATE | rename |
| `aws_appautoscaling_target.api` | UPDATE | **OSTRZEŻENIE**: max 30→15, min 5→9 (patrz Sekcja F) |

---

## E. Cutover Checklist (dzień kuterover'u)

### Pre-cutover (T-24h, dziś)

- [ ] **BLOCKER — nowy certyfikat ACM us-east-1:**
  ```bash
  aws acm request-certificate \
    --domain-name "twojkapsel.pl" \
    --subject-alternative-names "www.twojkapsel.pl" "test.twojkapsel.pl" "www.test.twojkapsel.pl" \
    --validation-method DNS \
    --region us-east-1 \
    --profile maspex-cli
  ```
  Następnie: w Cloudflare dodaj CNAME rekordy walidacyjne → poczekaj na ISSUED (zwykle 2-5 min).

- [ ] Po otrzymaniu nowego ARN — zaktualizuj `terraform.tfvars`:
  ```hcl
  api_cloudfront_certificate_arn = "arn:aws:acm:us-east-1:969209893152:certificate/<NOWY_ARN>"
  ```

- [ ] Re-run plan z nowym certem:
  ```bash
  AWS_PROFILE=maspex-cli terraform plan -out=cutover.tfplan
  ```

- [ ] Podjąć decyzję o autoscalingu (patrz Sekcja F) — zaktualizować wartości w TF lub zaakceptować revert.

- [ ] Weryfikacja DNS przed cutover:
  ```bash
  dig twojkapsel.pl +short    # aktualnie powinno wskazywać na coś innego
  dig test.twojkapsel.pl +short   # aktualnie → d1w5bz7itj42sz.cloudfront.net (docelowo)
  ```

### Dzień cutover (T=0, gdy klient zmienia DNS)

- [ ] **WAF open (można wcześniej):**
  ```bash
  AWS_PROFILE=maspex-cli terraform apply "cutover.tfplan"
  ```
  Czas propagacji WAF: ~30s–2min. ALB routing i CF aliases: ~1-3 min.

- [ ] Weryfikacja WAF aktywna:
  ```bash
  curl -s -o /dev/null -w "%{http_code}" https://test.twojkapsel.pl/
  # Przed apply: 403 dla nowych IP; Po apply: 200
  ```

- [ ] Klient zmienia DNS: `twojkapsel.pl CNAME → d1w5bz7itj42sz.cloudfront.net`
  - CloudFront propagacja: 1-5 min

- [ ] Weryfikacja po DNS switch:
  ```bash
  curl -sv https://twojkapsel.pl/ 2>&1 | grep -E "Subject:|HTTP/"
  curl -s -o /dev/null -w "%{http_code}" https://www.twojkapsel.pl/
  curl -s -o /dev/null -w "%{http_code}" https://test.twojkapsel.pl/
  ```

- [ ] Monitor przez 30 min po cutover:
  - ALB: `HTTPCode_Target_5XX_Count`, `TargetResponseTime`
  - CF: `5xxErrorRate`, `TotalErrorRate`
  - ECS: `CPUUtilization`, `MemoryUtilization`
  - CloudWatch alarm: `maspex-prod-cloudfront-api-5xx-rate`

### Rollback (jeśli coś pójdzie nie tak)

```bash
# Revert WAF do IP-only (blokowanie publiczne)
cd terraform/envs/prod
# Zmień waf.tf default_action z allow {} z powrotem na block {}
AWS_PROFILE=maspex-cli terraform apply -target=aws_wafv2_web_acl.public_app_allowlist

# DNS rollback: klient przywraca test.twojkapsel.pl lub tymczasowy CNAME
```

---

## F. Ryzyka i blokery

### BLOCKER (krytyczny — apply nie wyjdzie bez tego)

**Cert mismatch na CF:**
- Cert `1e70d4ef` pokrywa: twojkapsel.pl, www.twojkapsel.pl
- CF aliases po apply będą: twojkapsel.pl, www.twojkapsel.pl, **test.twojkapsel.pl**, **www.test.twojkapsel.pl**
- CloudFront API odrzuci update bo test.* nie jest pokryte przez nowy cert
- `terraform plan` ZDAŁ (TF nie waliduje SANs), ale `terraform apply` WYMAGNIE nowego certu
- Rozwiązanie: nowy cert z 4 SANami (komenda powyżej w sekcji E)

### OSTRZEŻENIE (wymaga decyzji)

**Autoscaling revert:**
- Obecny stan (po ręcznych zmianach z load testu): min=5, max=30
- TF chce ustawić: min=9, max=15
- Dla campaign day: min=9 może być za mało, max=15 może ograniczać skalowanie
- Opcja: zaktualizować kod TF przed apply:
  ```hcl
  # W main.tf lub dedykowanym pliku:
  resource "aws_appautoscaling_target" "api" {
    min_capacity = 9   # lub ile potrzebne na campaign day
    max_capacity = 30  # lub zostawić z load testu
  }
  ```

**Loadtest fleet IPs czyszczone:**
- `loadtest_allowlist` IPSet: 4 IP → empty
- Oczekiwane zachowanie (fleet zatrzymana po teście), ale warto potwierdzić że nie ma aktywnych sesji testowych

### NISKIE RYZYKO

- Cache policies rename (test-twojkapsel-pl → twojkapsel-pl): in-place update, zero downtime
- ALB listener rule update: in-place, zero downtime (~1s propagacja)
- CF distribution update: rolling update, ~1-3 min propagacja, brak downtime

---

## G. Werdykt końcowy

**IaC gotowe. Plan czysty. Apply ZABLOKOWANY przez cert.**

Żeby apply było safe:
1. Zamówić nowy cert (us-east-1, 4 SANy)
2. Poczekać ISSUED (2-5 min)
3. Zaktualizować `api_cloudfront_certificate_arn` w tfvars
4. Ponownie uruchomić `terraform plan`
5. Podjąć decyzję o autoscalingu (min/max wartości)

---

## H. Pliki i zasoby użyte

### Zmienione pliki

| Plik | Zmiana |
|---|---|
| `terraform/envs/prod/terraform.tfvars` | `api_domain` + `api_cloudfront_certificate_arn` |
| `terraform/envs/prod/main.tf` | CF aliases, ALB aliases, nowy `aws_lb_listener_certificate.twojkapsel_prod` |
| `terraform/envs/prod/waf.tf` | `default_action { block {} }` → `allow {}` |

### Plan zapisany

```
terraform/envs/prod/cutover.tfplan
```

### Komendy użyte w discovery

```bash
# Certy us-east-1
aws acm list-certificates --region us-east-1 --profile maspex-cli
aws acm describe-certificate --certificate-arn <ARN> --region us-east-1 --profile maspex-cli

# Certy eu-west-1
aws acm list-certificates --region eu-west-1 --profile maspex-cli

# Live CF distribution state
aws cloudfront get-distribution --id E33PUJBAQ533K0 --profile maspex-cli

# Plan
cd terraform/envs/prod
AWS_PROFILE=maspex-cli terraform plan -out=cutover.tfplan
```
