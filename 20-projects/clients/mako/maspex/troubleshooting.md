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

**Po apply:**
- Outputy `elasticache_endpoint` + `elasticache_connection_string` → wpisać do Secrets Manager `maspex/preprod/api`
- Gdy klient dostarczy domenę + certyfikaty → odkomentować zmienne w `terraform.tfvars`, `cloudfront_enabled = true`

**Architektura preprod:**
- VPC: 10.45.0.0/16 (własne, UAT ma 10.44.0.0/16)
- Subnety: public (ALB), app (ECS+IGW), backend (ElastiCache, prywatne)
- ECR: wspólne z UAT (shared)
- State backend: wspólny S3 `terraform-state-969209893152`, klucz `maspex/preprod/terraform.tfstate`
- CloudFront: wyłączony do czasu dostarczenia certyfikatów przez klienta
