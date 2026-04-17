# Area — Terraform / Terragrunt

Wzorce, gotcha i standardy IaC.

**Należy tutaj:** wzorce modułów, Terragrunt config, gotcha, decyzje IaC.  
**Nie należy tutaj:** runbooki tf apply/destroy (→ `40-runbooks/terraform/`), standardy (→ `30-standards/iac-standard.md`).

## Standard

→ [[iac-standard]]

## Struktura katalogów (wzorzec)

```
infra/
├── modules/          # moduły wielokrotnego użytku
│   └── ecs-service/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── terragrunt.hcl   # root config
```

## Gotcha

- `terraform import` nie aktualizuje state w Terragrunt — sprawdź ścieżkę state
- `depends_on` na module nie propaguje destroy order — użyj `dependency` w Terragrunt
- AWS provider version lock — zawsze pinuj do minor version
- `lifecycle { prevent_destroy = true }` na RDS, S3 state bucket

## Wersje

| Narzędzie | Wersja | Uwagi |
|-----------|--------|-------|
| Terraform | | |
| Terragrunt | | |
| AWS Provider | | |

## Szybkie komendy

```bash
# Init + plan z Terragrunt
terragrunt plan

# Apply z auto-approve (tylko dev!)
terragrunt apply --auto-approve

# Destroy z potwierdzeniem
terragrunt destroy

# Format wszystkich plików
terraform fmt -recursive
```
