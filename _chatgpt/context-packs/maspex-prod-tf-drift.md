# Paczka kontekstu — maspex PROD: Terraform drift cleanup

> Wklej całość na początku rozmowy z ChatGPT.

**Zakres:** Aktualny drift między TF config a AWS PROD + zaplanowane zmiany do wdrożenia  
**Data przygotowania:** 2026-05-19

---

## Kim jestem / kontekst roli

Senior DevOps/SRE. AWS Fargate + Terraform. Środowisko: account 969209893152, eu-west-1.  
Projekt: Kapsel (platforma konkursowa Maspex) — aplikacja live od 2026-05-17 (cutover).

---

## Stack

- ECS Fargate: `maspex-prod` cluster, serwisy `maspex-api` (main), `maspex-admin-panel`, `maspex-bot`
- CloudFront → ALB → ECS; WAF CloudFront scope (us-east-1); ElastiCache Redis
- TF w `terraform/envs/prod/`; backend S3; moduły lokalne (`../../modules/`)
- ECS service ma `lifecycle { ignore_changes = [desired_count, task_definition] }` — autoscaling i CI/CD zarządzają tymi polami poza TF

---

## Aktualny drift — 4 pozycje

### D1 — WAF admin panel otwarty (rollback wymagany) 🔴

**Plik:** `terraform/envs/prod/waf.tf`  
**TF stan (obecny):**
```hcl
resource "aws_wafv2_web_acl" "admin_panel_allowlist" {
  description = "TEMP open to public 0.0.0.0/0 - rollback: revert default_action to block"
  default_action {
    allow {}   # ← TEMP: otwarte na kampanię
  }
  # reguła allow-makolab-office-ips z IP-setami jest, ale dead (default=allow)
}
```
**Co powinno być:** `default_action { block {} }` — tylko MakoLab IPs (195.117.107.110/32, 91.233.19.251/32) mają dostęp do admin panelu.  
**Ryzyko aktualnego stanu:** panel admina (`kapsel-prod.makotest.pl`) dostępny publicznie.  
**Akcja:** zmienić `allow {}` → `block {}` + `terraform apply`.

---

### D2 — ECS image tag w tfvars ≠ faktyczny deploy (bezpieczny, ale stale) 🟡

**Plik:** `terraform/envs/prod/terraform.tfvars`  
**TF tfvars:** `api_image_tag = "coreapp-uat-612"`  
**AWS faktyczny obraz:** `maspex-api:coreapp-prod-805` (task def rev 26)  
**Dlaczego bezpieczne:** `task_definition` jest w `ignore_changes` — `terraform apply` nie nadpisze task definition.  
**Akcja:** zaktualizować tfvars do `"coreapp-prod-805"` żeby config był czytelny i żeby usunąć ryzyko gdyby ktoś w przyszłości usunął ignore_changes.

---

### D3 — Orphaned ACM certificate w TF state 🟡

**Lokalizacja:** `module.cloudfront_site.aws_acm_certificate.this[0]` w S3 state  
**Problem:** certyfikat ACM był kiedyś zarządzany przez ten moduł, potem przeniesiony poza TF (używamy `certificate_arn` z zewnątrz). Zasób istnieje w state ale nie ma go w konfiguracji (lub jest w stanie orpan).  
**Objaw:** `terraform plan` może zgłaszać błąd przy próbie usunięcia lub modyfikacji.  
**Obecny obejście** (w `main.tf`):
```hcl
# TEMPORARY — pass aws.us_east_1 so Terraform can resolve the orphaned
# aws_acm_certificate.this[0] still present in state.
# Remove after: terraform state rm 'module.cloudfront_site.aws_acm_certificate.this[0]'
providers = {
  aws           = aws
  aws.us_east_1 = aws.us_east_1
}
```
**Akcja:** `terraform state rm 'module.cloudfront_site.aws_acm_certificate.this[0]'` → usunąć provider override.

---

### D4 — IAM role tag: environment=uat na roli PROD (cosmetic) 🟢

**Zasób:** `maspex-api-execution` IAM role  
**AWS:** tag `environment=uat` (błąd z czasu tworzenia — rola shared UAT/PROD)  
**TF:** brak eksplicitnego tagu — zależy jak moduł generuje tagi (z `var.environment`)  
**Ryzyko:** zero funkcjonalne; policy i permissions są poprawne.  
**Akcja:** sprawdzić czy TF zarządza tagami tej roli; jeśli tak — `terraform apply` powinien to naprawić automatycznie.

---

## Zaplanowane zmiany (nie drift — jeszcze nie wdrożone)

### P1 — Autoscaling: min=30 → min=8, max=45 → max=30

**Plik:** `terraform/envs/prod/autoscaling.tf`  
**Bieżąco:**
```hcl
resource "aws_appautoscaling_target" "api" {
  min_capacity = 30
  max_capacity = 45
}
```
**Docelowo (po analizie FinOps):**
```hcl
resource "aws_appautoscaling_target" "api" {
  min_capacity = 8
  max_capacity = 30
}
```
**Plus** w `main.tf` zmienić `desired_count = 30` → `desired_count = 8`.  
**Oszczędność:** ~$2 190/mies. (−49%).  
**Warunki przed wdrożeniem:** dodać alarm `RunningTaskCount < 6` i `p99 > 500ms`.

### P2 — TF apply niezatwierdzony dla secret_arns fix

Commity `334353c` i `a2bcd3a` dodały ARN-y do `secret_arns` w modułach ECS. Apply był pominięty (AWS był już w sync po ręcznym hotfixie). Następny `terraform plan` powinien pokazać 0 zmian — warto to potwierdzić.

---

## Priorytet cleanup

| ID | Pozycja | Priorytet | Ryzyko jeśli nie zrobione |
|----|---------|-----------|---------------------------|
| ~~D1~~ | ~~WAF admin panel otwarty~~ | ~~**HIGH — teraz**~~ | ✅ ZAMKNIĘTY — commit ca12875 (2026-05-19) |
| P1 | Autoscaling min=8/max=30 | MEDIUM — ten tydzień | $2k/mies. przepalane |
| D3 | Orphaned ACM cert state | MEDIUM — przed next apply | plan może failować |
| P2 | Potwierdzenie apply secret_arns | LOW — przy okazji | cosmetic |
| D2 | image tag w tfvars | LOW — przy okazji | confusing ale bezpieczne |
| ~~D4~~ | ~~IAM role tag~~ | ~~LOW~~ | ✅ ZAMKNIĘTY — commit ca12875 (2026-05-19) |

---

## Pytanie do ChatGPT

Chcę przeprowadzić cleanup session. Proszę zaproponuj:
1. Kolejność operacji (co najpierw, żeby uniknąć problemów)
2. Czy D3 (orphaned state) trzeba robić przed `terraform apply` dla D1/P1?
3. Bezpieczna procedura `terraform state rm` dla D3
4. Czy `desired_count` w main.tf i `min_capacity` w autoscaling.tf można zmienić w jednym apply?
