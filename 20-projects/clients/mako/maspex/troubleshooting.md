# maspex — Troubleshooting

Aktywne problemy na górze. Rozwiązane zostają jako archiwum poniżej.

## Repozytorium
- lokalna ścieżka: `~/projekty/mako/aws-projects/infra-maspex`
- profil AWS: `maspex-cli` (IAM user + MFA, przez `awsume maspex-cli`)

---

## 2026-04-20 — preprod: nowe środowisko w toku

**Stan:** `terraform validate` OK, plan częściowo uruchomiony (sesja MFA wygasła)

**Co zrobiono:**
- Dodano `networking.tf` — tworzy VPC 10.45.0.0/16 + IGW + 6 subnetów + route tables
- `data.tf` — usunięto VPC/subnet data sources (preprod tworzy własne zasoby)
- `locals.tf` — subnety z `aws_subnet.*` zamiast data sources
- `main.tf` — `aws_vpc.this.id`, latest image `coreapp-uat-303`
- `terraform.tfvars` — `cloudfront_enabled = false`, usunięto UAT subnet IDs
- `moved.tf` — wyczyszczone (nowe env)
- `variables.tf` — defaults: `environment=preprod`, `vpc_cidr=10.45.0.0/16`

**Żeby dokończyć:**
```bash
cd ~/projekty/mako/aws-projects/infra-maspex/terraform/envs/preprod
awsume maspex-cli
terraform plan -out=tfplan
terraform apply tfplan
```

**Po apply — DONE ✓:**
- ALB DNS: `maspex-preprod-1322298306.eu-west-1.elb.amazonaws.com`
- Redis: `maspex-preprod.zwowz5.0001.euw1.cache.amazonaws.com:6379`
- TODO: wpisać Redis do Secrets Manager `maspex/preprod/api` (klucz `ConnectionStrings__Redis`)

**DNS dla klienta:**
- Tymczasowo: CNAME subdomeny na ALB DNS (nie apex domeny)
- Docelowo: CloudFront + własna domena (klient dostarcza domenę + certyfikaty ACM)
- Gdy klient dostarczy → odkomentować zmienne w `terraform.tfvars`, `cloudfront_enabled = true` → plan + apply

**Architektura preprod:**
- VPC: 10.45.0.0/16 (własne, UAT ma 10.44.0.0/16)
- Subnety: public (ALB), app (ECS+IGW), backend (ElastiCache, prywatne)
- ECR: wspólne z UAT (shared)
- State backend: wspólny S3 `terraform-state-969209893152`, klucz `maspex/preprod/terraform.tfstate`
- CloudFront: wyłączony do czasu dostarczenia certyfikatów przez klienta
