---
title: mail-assets-migration-plan
project: maspex
client: mako
domain: client-work
type: implementation-plan
created: 2026-05-16
status: ready-to-execute
---

# Mail Assets — Migracja do S3 + CloudFront Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Przenieść assety mailowe z `kapsel.makotest.pl/email/` na neutralną domenę assetową `assets.twojkapsel.pl` hostowaną na S3 + CloudFront, niezależną od domeny frontu.

**Architecture:** S3 bucket `maspex-mail-assets-{account_id}` w shared env + CloudFront distribution z OAC (Origin Access Control) + alias `assets.twojkapsel.pl`. App czyta nową zmienną `EMAIL_ASSETS_BASE_URL` z fallbackiem do `NEXT_PUBLIC_SITE_URL`. ECS task definitions (prod + uat) wstrzykują wartość `https://assets.twojkapsel.pl`.

**Tech Stack:** Terraform ~> 5.0, AWS S3, CloudFront, ACM (us-east-1), Next.js env vars

**Repozytoria:**
- IaC: `~/projekty/mako/aws-projects/infra-maspex/`
- App: `~/projekty/mako/next-core-app/`

---

## Discovery summary

| Obszar | Stan |
|--------|------|
| Assety | `next-core-app/public/email/` — 9 plików PNG |
| Runtime templates | `lib/email/templates/` — 4 pliki TS używają `NEXT_PUBLIC_SITE_URL` |
| URL pattern | `${process.env.NEXT_PUBLIC_SITE_URL}/email/filename.png` |
| Dedicated var | Brak — tylko `NEXT_PUBLIC_SITE_URL` |
| IaC pattern | `preprod/zaslepka-s3.tf` — S3+OAC identyczny wzorzec |
| CloudFront module | `modules/cloudfront-site` — akceptuje `s3_bucket_regional_domain_name` |
| Cert us-east-1 | `twojkapsel.pl` — NIE pokrywa `assets.twojkapsel.pl` → nowy cert potrzebny |
| DNS | Route53 NIE zarządzany przez Terraform → ręcznie |
| Shared env providers | Brak `aws.us_east_1` alias → trzeba dodać |

---

## File structure

**IaC — nowe / zmieniane:**
- Create: `terraform/envs/shared/mail-assets.tf`
- Modify: `terraform/envs/shared/providers.tf`
- Modify: `terraform/envs/shared/variables.tf`
- Modify: `terraform/envs/shared/terraform.tfvars`
- Modify: `terraform/envs/shared/outputs.tf`
- Modify: `terraform/envs/prod/main.tf` (linia ~95: environment_variables)
- Modify: `terraform/envs/uat/main.tf` (linia ~81: environment_variables)

**App — zmieniane:**
- Modify: `next-core-app/.env.example`
- Modify: `next-core-app/lib/email/templates/slogan-approved.ts`
- Modify: `next-core-app/lib/email/templates/slogan-rejected.ts`
- Modify: `next-core-app/lib/email/templates/slogan-revoked.ts`
- Modify: `next-core-app/lib/email/templates/social-registration.ts`

---

## PREREQ: Certyfikat ACM (wykonaj przed Task 5)

Cert musi być `ISSUED` zanim uruchomisz `terraform apply` na shared env.
Cert `twojkapsel.pl` w us-east-1 pokrywa tylko `twojkapsel.pl` + `www.twojkapsel.pl` — nie `assets.twojkapsel.pl`.

```bash
# Krok A — request cert
aws acm request-certificate \
  --domain-name assets.twojkapsel.pl \
  --validation-method DNS \
  --region us-east-1 \
  --profile maspex-cli

# Krok B — pobierz CNAME walidacyjny (podaj ARN z outputu powyżej)
aws acm describe-certificate \
  --certificate-arn <ARN_Z_KROKU_A> \
  --region us-east-1 \
  --profile maspex-cli \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord'

# Krok C — dodaj rekord CNAME do DNS (u rejestratora domeny twojkapsel.pl)
#   Name:  <_xxxxx.assets.twojkapsel.pl z outputu>
#   Type:  CNAME
#   Value: <_yyyyy.acm-validations.aws z outputu>

# Krok D — sprawdź status (czekaj na ISSUED, zwykle 1-5 min po dodaniu DNS)
aws acm describe-certificate \
  --certificate-arn <ARN_Z_KROKU_A> \
  --region us-east-1 \
  --profile maspex-cli \
  --query 'Certificate.Status'

# Zanotuj ARN — będzie potrzebny w terraform.tfvars
```

---

## Task 1: shared env — dodaj provider us_east_1

**Files:**
- Modify: `terraform/envs/shared/providers.tf`

- [ ] **Step 1: Dodaj alias us_east_1 do providers.tf**

Obecna treść `terraform/envs/shared/providers.tf`:
```hcl
# Credentials are supplied by awsume (environment variables).
# Do NOT set profile here — it would conflict with MFA sessions.
# Usage: awsume maspex && terraform init -backend-config=backend.hcl
provider "aws" {
  region = var.region
}
```

Nowa treść:
```hcl
# Credentials are supplied by awsume (environment variables).
# Do NOT set profile here — it would conflict with MFA sessions.
# Usage: awsume maspex && terraform init -backend-config=backend.hcl
provider "aws" {
  region = var.region
}

# Required for aws_cloudfront_origin_access_control (CloudFront global resource,
# project convention: OAC created via us-east-1 provider).
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
```

- [ ] **Step 2: Commit**

```bash
cd ~/projekty/mako/aws-projects/infra-maspex
git add terraform/envs/shared/providers.tf
git commit -m "feat(shared): add us_east_1 provider alias for CloudFront OAC"
```

---

## Task 2: shared env — variables.tf

**Files:**
- Modify: `terraform/envs/shared/variables.tf`

- [ ] **Step 1: Dopisz zmienne na końcu pliku**

```hcl
variable "mail_assets_domain" {
  description = "Alternate domain name for the mail assets CloudFront distribution"
  type        = string
  default     = "assets.twojkapsel.pl"
}

variable "mail_assets_cf_certificate_arn" {
  description = "ARN of a pre-provisioned ACM certificate in us-east-1 for assets.twojkapsel.pl. CloudFront only accepts us-east-1 certs."
  type        = string
}
```

- [ ] **Step 2: Commit**

```bash
git add terraform/envs/shared/variables.tf
git commit -m "feat(shared): add mail_assets_domain and mail_assets_cf_certificate_arn variables"
```

---

## Task 3: shared env — terraform.tfvars

**Files:**
- Modify: `terraform/envs/shared/terraform.tfvars`

- [ ] **Step 1: Dopisz wartości zmiennych na końcu pliku**

Zastąp `<ARN_CERT>` wartością z PREREQ:

```hcl
mail_assets_domain             = "assets.twojkapsel.pl"
mail_assets_cf_certificate_arn = "arn:aws:acm:us-east-1:969209893152:certificate/<ARN_CERT>"
```

- [ ] **Step 2: Commit**

```bash
git add terraform/envs/shared/terraform.tfvars
git commit -m "feat(shared): set mail assets domain and certificate ARN"
```

---

## Task 4: shared env — mail-assets.tf (S3 + OAC + CloudFront)

**Files:**
- Create: `terraform/envs/shared/mail-assets.tf`

- [ ] **Step 1: Utwórz plik**

```hcl
# ---------------------------------------------------------------------------
# S3 bucket — mail assets (environment-neutral)
#
# Serves email images for all environments (UAT, prod) via CloudFront.
# Architecture: S3 (private) + CloudFront OAC → assets.twojkapsel.pl
# Bucket is environment-neutral — same assets for all envs.
#
# To upload assets:
#   aws s3 cp public/email/ s3://<bucket>/email/ --recursive --profile maspex-cli
#
# To invalidate after upload:
#   aws cloudfront create-invalidation --distribution-id <id> --paths "/email/*" --profile maspex-cli
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "mail_assets" {
  provider = aws

  bucket = "maspex-mail-assets-${data.aws_caller_identity.current.account_id}"

  tags = merge(local.common_tags, { Name = "maspex-mail-assets" })
}

resource "aws_s3_bucket_public_access_block" "mail_assets" {
  provider = aws

  bucket                  = aws_s3_bucket.mail_assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "mail_assets" {
  provider = aws

  bucket = aws_s3_bucket.mail_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

# CloudFront Origin Access Control — S3 signed requests (replaces legacy OAI).
resource "aws_cloudfront_origin_access_control" "mail_assets" {
  provider = aws.us_east_1

  name                              = "maspex-mail-assets"
  description                       = "OAC for mail assets S3 bucket (assets.twojkapsel.pl)"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Bucket policy — allow CloudFront OAC to read objects.
resource "aws_s3_bucket_policy" "mail_assets" {
  provider = aws

  bucket = aws_s3_bucket.mail_assets.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.mail_assets.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = module.cloudfront_mail_assets.cloudfront_arn
          }
        }
      }
    ]
  })

  depends_on = [module.cloudfront_mail_assets]
}

module "cloudfront_mail_assets" {
  source = "../../modules/cloudfront-site"

  enabled     = true
  domain_name = var.mail_assets_domain

  s3_bucket_regional_domain_name = aws_s3_bucket.mail_assets.bucket_regional_domain_name
  s3_origin_access_control_id    = aws_cloudfront_origin_access_control.mail_assets.id

  certificate_arn = var.mail_assets_cf_certificate_arn
  price_class     = "PriceClass_100"

  tags = merge(local.common_tags, { Name = "maspex-mail-assets" })
}
```

- [ ] **Step 2: Commit**

```bash
git add terraform/envs/shared/mail-assets.tf
git commit -m "feat(shared): add S3 bucket + CloudFront for environment-neutral mail assets"
```

---

## Task 5: shared env — outputs.tf

**Files:**
- Modify: `terraform/envs/shared/outputs.tf`

- [ ] **Step 1: Dopisz outputy na końcu pliku**

```hcl
output "mail_assets_bucket_name" {
  description = "S3 bucket name for mail assets"
  value       = aws_s3_bucket.mail_assets.bucket
}

output "mail_assets_cloudfront_domain" {
  description = "CloudFront domain name for mail assets — use as CNAME target for assets.twojkapsel.pl"
  value       = module.cloudfront_mail_assets.cloudfront_domain_name
}

output "mail_assets_cloudfront_arn" {
  description = "ARN of the mail assets CloudFront distribution"
  value       = module.cloudfront_mail_assets.cloudfront_arn
}
```

- [ ] **Step 2: Commit**

```bash
git add terraform/envs/shared/outputs.tf
git commit -m "feat(shared): add mail assets outputs (bucket name, cloudfront domain)"
```

---

## Task 6: terraform validate — shared env

- [ ] **Step 1: Init + validate**

```bash
cd ~/projekty/mako/aws-projects/infra-maspex/terraform/envs/shared
terraform init -backend-config=backend.hcl
terraform validate
```

Oczekiwany wynik: `Success! The configuration is valid.`

- [ ] **Step 2: Plan (tylko po PREREQ cert jest ISSUED)**

```bash
terraform plan -var-file=terraform.tfvars
```

Oczekiwany wynik: plan pokazuje do dodania:
- `aws_s3_bucket.mail_assets`
- `aws_s3_bucket_public_access_block.mail_assets`
- `aws_s3_bucket_versioning.mail_assets`
- `aws_cloudfront_origin_access_control.mail_assets`
- `aws_s3_bucket_policy.mail_assets`
- `module.cloudfront_mail_assets.*` (distribution + cache policy)

Brak zmian destrukcyjnych.

---

## Task 7: prod env — EMAIL_ASSETS_BASE_URL w ECS

**Files:**
- Modify: `terraform/envs/prod/main.tf` (linia ~95)

- [ ] **Step 1: Dodaj env var do service_api**

Zmień:
```hcl
  environment_variables = [
    { name = "HOSTNAME", value = "0.0.0.0" },
    { name = "PORT", value = "3000" },
  ]
```

Na:
```hcl
  environment_variables = [
    { name = "HOSTNAME", value = "0.0.0.0" },
    { name = "PORT", value = "3000" },
    { name = "EMAIL_ASSETS_BASE_URL", value = "https://assets.twojkapsel.pl" },
  ]
```

- [ ] **Step 2: Validate**

```bash
cd ~/projekty/mako/aws-projects/infra-maspex/terraform/envs/prod
terraform validate
```

Oczekiwany wynik: `Success! The configuration is valid.`

- [ ] **Step 3: Commit**

```bash
cd ~/projekty/mako/aws-projects/infra-maspex
git add terraform/envs/prod/main.tf
git commit -m "feat(prod): inject EMAIL_ASSETS_BASE_URL into api ECS task definition"
```

---

## Task 8: uat env — EMAIL_ASSETS_BASE_URL w ECS

**Files:**
- Modify: `terraform/envs/uat/main.tf` (linia ~81)

- [ ] **Step 1: Dodaj env var do service_api**

Zmień:
```hcl
  environment_variables = [
    { name = "HOSTNAME", value = "0.0.0.0" },
    { name = "PORT", value = "3000" },
  ]
```

Na:
```hcl
  environment_variables = [
    { name = "HOSTNAME", value = "0.0.0.0" },
    { name = "PORT", value = "3000" },
    { name = "EMAIL_ASSETS_BASE_URL", value = "https://assets.twojkapsel.pl" },
  ]
```

- [ ] **Step 2: Validate**

```bash
cd ~/projekty/mako/aws-projects/infra-maspex/terraform/envs/uat
terraform validate
```

Oczekiwany wynik: `Success! The configuration is valid.`

- [ ] **Step 3: Commit**

```bash
cd ~/projekty/mako/aws-projects/infra-maspex
git add terraform/envs/uat/main.tf
git commit -m "feat(uat): inject EMAIL_ASSETS_BASE_URL into api ECS task definition"
```

---

## Task 9: App — .env.example

**Files:**
- Modify: `next-core-app/.env.example`

- [ ] **Step 1: Dodaj zmienną po NEXT_PUBLIC_SITE_URL**

Znajdź linię:
```
NEXT_PUBLIC_SITE_URL=http://localhost:3000
```

Dopisz bezpośrednio po niej:
```
# Base URL for email image assets (served from environment-neutral CDN).
# In production: https://assets.twojkapsel.pl
# Unset or empty = falls back to NEXT_PUBLIC_SITE_URL (safe for local dev).
EMAIL_ASSETS_BASE_URL=
```

- [ ] **Step 2: Commit**

```bash
cd ~/projekty/mako/next-core-app
git add .env.example
git commit -m "feat(email): add EMAIL_ASSETS_BASE_URL to .env.example"
```

---

## Task 10: App — slogan-approved.ts

**Files:**
- Modify: `next-core-app/lib/email/templates/slogan-approved.ts`

- [ ] **Step 1: Dodaj stałą EMAIL_ASSETS_BASE_URL na początku pliku**

Zmień linię 1:
```typescript
const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL;
```

Na:
```typescript
const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL;
const EMAIL_ASSETS_BASE_URL = process.env.EMAIL_ASSETS_BASE_URL ?? SITE_URL;
```

- [ ] **Step 2: Zamień wszystkie referencje do assetów mailowych**

Zamień wszystkie wystąpienia `${SITE_URL}/email/` na `${EMAIL_ASSETS_BASE_URL}/email/`.
Zamień jeden outlier na linii ~264: `${process.env.NEXT_PUBLIC_SITE_URL}/email/` → `${EMAIL_ASSETS_BASE_URL}/email/`.

Weryfikacja (zero wyników = sukces):
```bash
grep -n 'SITE_URL}/email/' lib/email/templates/slogan-approved.ts
grep -n 'NEXT_PUBLIC_SITE_URL}/email/' lib/email/templates/slogan-approved.ts
```

Oczekiwany wynik: brak wyników.

Weryfikacja (powinny zostać referencje bez `/email/`):
```bash
grep -c 'EMAIL_ASSETS_BASE_URL}/email/' lib/email/templates/slogan-approved.ts
```

Oczekiwany wynik: liczba >= 8 (header ×2, footer ×4, social icons ×4 = 10 w sumie; może być ~11).

- [ ] **Step 3: Commit**

```bash
cd ~/projekty/mako/next-core-app
git add lib/email/templates/slogan-approved.ts
git commit -m "feat(email): use EMAIL_ASSETS_BASE_URL for mail image assets in slogan-approved"
```

---

## Task 11: App — slogan-rejected.ts

**Files:**
- Modify: `next-core-app/lib/email/templates/slogan-rejected.ts`

- [ ] **Step 1: Dodaj stałą EMAIL_ASSETS_BASE_URL**

Zmień linię 1 (identyczny wzorzec jak Task 10):
```typescript
const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL;
const EMAIL_ASSETS_BASE_URL = process.env.EMAIL_ASSETS_BASE_URL ?? SITE_URL;
```

- [ ] **Step 2: Zamień referencje**

```bash
sed -i 's|${SITE_URL}/email/|${EMAIL_ASSETS_BASE_URL}/email/|g' lib/email/templates/slogan-rejected.ts
sed -i 's|${process.env.NEXT_PUBLIC_SITE_URL}/email/|${EMAIL_ASSETS_BASE_URL}/email/|g' lib/email/templates/slogan-rejected.ts
```

Weryfikacja:
```bash
grep -c '}/email/' lib/email/templates/slogan-rejected.ts && \
grep -n 'SITE_URL}/email/' lib/email/templates/slogan-rejected.ts && \
echo "SITE_URL refs above should be 0"
```

- [ ] **Step 3: Commit**

```bash
git add lib/email/templates/slogan-rejected.ts
git commit -m "feat(email): use EMAIL_ASSETS_BASE_URL for mail image assets in slogan-rejected"
```

---

## Task 12: App — slogan-revoked.ts

**Files:**
- Modify: `next-core-app/lib/email/templates/slogan-revoked.ts`

- [ ] **Step 1: Dodaj stałą EMAIL_ASSETS_BASE_URL i zamień referencje**

```bash
cd ~/projekty/mako/next-core-app

# Dodaj linię po line 1 (const SITE_URL = ...)
# Ręcznie edytuj lub użyj poniższego sed (działa na macOS z gsed lub GNU sed):
sed -i 's|const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL;|const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL;\nconst EMAIL_ASSETS_BASE_URL = process.env.EMAIL_ASSETS_BASE_URL ?? SITE_URL;|' \
  lib/email/templates/slogan-revoked.ts

# Zamień referencje assetów
sed -i 's|${SITE_URL}/email/|${EMAIL_ASSETS_BASE_URL}/email/|g' lib/email/templates/slogan-revoked.ts
sed -i 's|${process.env.NEXT_PUBLIC_SITE_URL}/email/|${EMAIL_ASSETS_BASE_URL}/email/|g' lib/email/templates/slogan-revoked.ts
```

Weryfikacja:
```bash
grep -n 'SITE_URL}/email/' lib/email/templates/slogan-revoked.ts
# Oczekiwany wynik: brak
grep -c 'EMAIL_ASSETS_BASE_URL}/email/' lib/email/templates/slogan-revoked.ts
# Oczekiwany wynik: >= 8
```

- [ ] **Step 2: Commit**

```bash
git add lib/email/templates/slogan-revoked.ts
git commit -m "feat(email): use EMAIL_ASSETS_BASE_URL for mail image assets in slogan-revoked"
```

---

## Task 13: App — social-registration.ts

**Files:**
- Modify: `next-core-app/lib/email/templates/social-registration.ts`

- [ ] **Step 1: Dodaj stałą EMAIL_ASSETS_BASE_URL i zamień referencje**

```bash
cd ~/projekty/mako/next-core-app

sed -i 's|const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL;|const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL;\nconst EMAIL_ASSETS_BASE_URL = process.env.EMAIL_ASSETS_BASE_URL ?? SITE_URL;|' \
  lib/email/templates/social-registration.ts

sed -i 's|${SITE_URL}/email/|${EMAIL_ASSETS_BASE_URL}/email/|g' lib/email/templates/social-registration.ts
sed -i 's|${process.env.NEXT_PUBLIC_SITE_URL}/email/|${EMAIL_ASSETS_BASE_URL}/email/|g' lib/email/templates/social-registration.ts
```

Weryfikacja:
```bash
grep -n 'SITE_URL}/email/' lib/email/templates/social-registration.ts
# Oczekiwany wynik: brak
grep -c 'EMAIL_ASSETS_BASE_URL}/email/' lib/email/templates/social-registration.ts
# Oczekiwany wynik: >= 8
```

- [ ] **Step 2: Commit**

```bash
git add lib/email/templates/social-registration.ts
git commit -m "feat(email): use EMAIL_ASSETS_BASE_URL for mail image assets in social-registration"
```

---

## Task 14: Validation — brak starych URL-i w kodzie

- [ ] **Step 1: Sprawdź brak starych referencji we wszystkich templates**

```bash
cd ~/projekty/mako/next-core-app

# Szukaj starych URL-i w template files
grep -rn 'kapsel\.makotest\.pl' lib/email/
grep -rn 'twojkapsel\.pl' lib/email/
grep -rn 'test\.twojkapsel\.pl' lib/email/
grep -rn '}/email/' lib/email/templates/
```

Oczekiwany wynik dla pierwszych 3 komend: brak wyników.
Wynik `}/email/` powinien zawierać wyłącznie `EMAIL_ASSETS_BASE_URL}/email/` — zero wystąpień z `SITE_URL}/email/`.

- [ ] **Step 2: Sprawdź brak outliera**

```bash
grep -rn 'process\.env\.NEXT_PUBLIC_SITE_URL}/email/' lib/email/
```

Oczekiwany wynik: brak.

---

## Task 15: terraform apply — shared env (PREREQ: cert ISSUED)

Wykonuj tylko po tym jak cert `assets.twojkapsel.pl` ma status `ISSUED`.

- [ ] **Step 1: Weryfikuj cert przed apply**

```bash
aws acm describe-certificate \
  --certificate-arn "arn:aws:acm:us-east-1:969209893152:certificate/<CERT_ARN>" \
  --region us-east-1 \
  --profile maspex-cli \
  --query 'Certificate.Status'
# Oczekiwany wynik: "ISSUED"
```

- [ ] **Step 2: Plan przed apply**

```bash
cd ~/projekty/mako/aws-projects/infra-maspex/terraform/envs/shared
terraform plan -var-file=terraform.tfvars -out=mail-assets.tfplan
```

Sprawdź: plan dodaje 6-7 zasobów, brak destroys.

- [ ] **Step 3: Apply**

```bash
terraform apply mail-assets.tfplan
```

- [ ] **Step 4: Pobierz output z CloudFront domain**

```bash
terraform output mail_assets_cloudfront_domain
terraform output mail_assets_bucket_name
```

Zanotuj oba outputy — potrzebne w kolejnych krokach.

---

## Task 16: DNS — CNAME assets.twojkapsel.pl

- [ ] **Step 1: Utwórz rekord DNS**

W panelu rejestratora domeny `twojkapsel.pl` (lub w systemie DNS który zarządza tą domeną — sprawdź z zespołem):

```
Name:   assets.twojkapsel.pl
Type:   CNAME
Value:  <output z Task 15 Step 4 — np. d1abc123.cloudfront.net>
TTL:    300
```

- [ ] **Step 2: Weryfikuj propagację**

```bash
dig assets.twojkapsel.pl CNAME +short
# Oczekiwany wynik: <domena cloudfront>.cloudfront.net
```

- [ ] **Step 3: Test HTTP (po propagacji DNS)**

```bash
curl -I https://assets.twojkapsel.pl/email/fb_ico.png
# Oczekiwany wynik: 403 (bucket pusty) lub 200 po Task 17
```

---

## Task 17: Upload assetów do S3

Assety są już dostępne lokalnie w `next-core-app/public/email/`.

- [ ] **Step 1: Upload**

```bash
BUCKET=$(cd ~/projekty/mako/aws-projects/infra-maspex/terraform/envs/shared && terraform output -raw mail_assets_bucket_name)

aws s3 cp ~/projekty/mako/next-core-app/public/email/ \
  s3://${BUCKET}/email/ \
  --recursive \
  --profile maspex-cli

# Weryfikacja uploadowanych plików:
aws s3 ls s3://${BUCKET}/email/ --profile maspex-cli
```

Oczekiwany wynik — lista plików:
```
tymbark_kapsel_desktop_naglowek_650x200_v4.png
tymbark_kapsel_mobile_naglowek_350x100_v4.png
tymbark_kapsel_desktop_stopka_650x150_v4.png
tymbark_kapsel_desktop_stopka_350x100_v4.png
tymbark_kapsel_desktop_stopka_350x100_v4_ikony.png
fb_ico.png
tiktok_ico.png
instagram_ico.png
yt_ico.png
```

- [ ] **Step 2: CloudFront invalidation**

```bash
DIST_ID=$(cd ~/projekty/mako/aws-projects/infra-maspex/terraform/envs/shared && \
  terraform output -raw mail_assets_cloudfront_arn | cut -d'/' -f2)

aws cloudfront create-invalidation \
  --distribution-id "${DIST_ID}" \
  --paths "/email/*" \
  --profile maspex-cli
```

- [ ] **Step 3: Test dostępności**

```bash
curl -I https://assets.twojkapsel.pl/email/fb_ico.png
# Oczekiwany wynik: HTTP/2 200, x-cache: Miss from cloudfront (lub Hit po chwili)

curl -I https://assets.twojkapsel.pl/email/tymbark_kapsel_desktop_naglowek_650x200_v4.png
# Oczekiwany wynik: HTTP/2 200
```

---

## Task 18: terraform apply — prod env

- [ ] **Step 1: Plan**

```bash
cd ~/projekty/mako/aws-projects/infra-maspex/terraform/envs/prod
terraform plan -var-file=terraform.tfvars -out=email-assets.tfplan
```

Sprawdź: plan pokazuje zmianę task definition dla `service_api` — dodanie env var `EMAIL_ASSETS_BASE_URL`. Brak destroys.

- [ ] **Step 2: Apply**

```bash
terraform apply email-assets.tfplan
```

ECS zadeplojuje nowe taski z env varem. Rolling update — zero downtime.

---

## Task 19: terraform apply — uat env

- [ ] **Step 1: Plan**

```bash
cd ~/projekty/mako/aws-projects/infra-maspex/terraform/envs/uat
terraform plan -var-file=terraform.tfvars -out=email-assets.tfplan
```

- [ ] **Step 2: Apply**

```bash
terraform apply email-assets.tfplan
```

---

## Task 20: Final validation

- [ ] **Step 1: Sprawdź ECS env var w running task (UAT)**

```bash
# Pobierz ARN running task
TASK_ARN=$(aws ecs list-tasks \
  --cluster maspex-uat \
  --service-name maspex-api \
  --profile maspex-cli --region eu-west-1 \
  --query 'taskArns[0]' --output text)

# Sprawdź env vars w task definition
aws ecs describe-tasks \
  --cluster maspex-uat \
  --tasks "${TASK_ARN}" \
  --profile maspex-cli --region eu-west-1 \
  --query 'tasks[0].overrides.containerOverrides' 2>/dev/null || \
aws ecs describe-task-definition \
  --task-definition maspex-api \
  --profile maspex-cli --region eu-west-1 \
  --query 'taskDefinition.containerDefinitions[0].environment[?name==`EMAIL_ASSETS_BASE_URL`]'
```

Oczekiwany wynik: `[{"name": "EMAIL_ASSETS_BASE_URL", "value": "https://assets.twojkapsel.pl"}]`

- [ ] **Step 2: End-to-end test emaila**

Wyzwól wysłanie testowego maila (endpoint `/api/email/test` jeśli dostępny, lub przez aplikację):

```bash
curl -X POST https://kapsel.makotest.pl/api/email/test \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json"
```

Sprawdź odebrany email — obrazki powinny ładować się z `https://assets.twojkapsel.pl/email/...`.

- [ ] **Step 3: Sprawdź brak starych URL-i w całym repozytorium app**

```bash
cd ~/projekty/mako/next-core-app
grep -rn 'kapsel\.makotest\.pl/email' .
grep -rn 'twojkapsel\.pl/email' .
grep -rn 'test\.twojkapsel\.pl/email' .
```

Oczekiwany wynik: brak wyników.

---

## Deployment order summary

```
PREREQ: ACM cert request + DNS validation → wait for ISSUED
   │
   ├── Track A (IaC shared)
   │    Task 1-5 (code) → Task 6 (validate) → Task 15 (apply after cert ISSUED)
   │                                               │
   │                                          Task 16 (DNS CNAME)
   │                                               │
   │                                          Task 17 (S3 upload + CDN test)
   │
   ├── Track B (App code)
   │    Task 9-13 → Task 14 (validation)
   │         │
   │         └── PR → merge → CI build → ECS deploy
   │
   └── Track C (IaC prod/uat) — po Task 17 i po deploymencie kodu app
        Task 7-8 (code) → Task 18-19 (apply)
              │
         Task 20 (final validation)
```

---

## D. Domain / Certificate verdict

| Parametr | Wartość |
|----------|---------|
| Rekomendowana domena | `assets.twojkapsel.pl` |
| Cert potrzebny | TAK — nowy, dla `assets.twojkapsel.pl` |
| Region certu | `us-east-1` (wymaganie CloudFront) |
| Cert istnieje? | NIE — `twojkapsel.pl` (us-east-1) pokrywa tylko `twojkapsel.pl` + `www.twojkapsel.pl` |
| Bloker DNS | NIE — DNS da się zrobić ręcznie, Route53 nie jest w Terraform |
| Bloker cert | Tylko czas — DNS validation zajmuje 1-5 min po dodaniu CNAME |

---

## H. Risks / Blockers

| Ryzyko | Ocena | Mitigacja |
|--------|-------|-----------|
| Cert validation delay | NISKI | Request cert wcześnie, aplikuj Terraform po ISSUED |
| DNS propagacja | NISKI | TTL=300, test przez dig przed deploym app |
| S3 upload bez dostępu | NISKI | `maspex-cli` ma uprawnienia do S3 na tym koncie |
| App fallback gap | BRAK | `EMAIL_ASSETS_BASE_URL ?? SITE_URL` — maile działają też bez nowego var |
| Rollback | PROSTY | Usuń `EMAIL_ASSETS_BASE_URL` z ECS → containers fall back to SITE_URL |
| email/build.js | INFO | build.js używa NEXT_PUBLIC_SITE_URL dla preview HTML w `email/generated/` — nie jest to ścieżka runtime, ale można zaktualizować osobno |

---

## Powiązane

- [[maspex-context]] — architektura projektu, ścieżki repo
- [[cloudfront-audit-2026-04-26]] — istniejące CF distributions
