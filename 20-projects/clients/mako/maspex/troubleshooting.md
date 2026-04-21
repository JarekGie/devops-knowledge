# maspex — Troubleshooting

Aktywne problemy na górze. Rozwiązane zostają jako archiwum poniżej.

## Repozytorium
- lokalna ścieżka: `~/projekty/mako/aws-projects/infra-maspex`
- profil AWS: `maspex-cli` (IAM user + MFA, przez `awsume maspex-cli`)

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
