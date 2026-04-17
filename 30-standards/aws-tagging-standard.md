# Standard tagowania AWS

#aws #standard

## Obowiązkowe tagi — wszystkie zasoby

| Tag | Format | Przykład |
|-----|--------|---------|
| `Environment` | `dev` / `staging` / `prod` | `prod` |
| `Project` | kebab-case | `devops-toolkit` |
| `Owner` | email lub team | `jarek@example.com` |
| `ManagedBy` | `terraform` / `manual` / `cloudformation` | `terraform` |
| `CostCenter` | identyfikator | `cc-devops-001` |

## Tagi opcjonalne (rekomendowane)

| Tag | Format | Opis |
|-----|--------|------|
| `Service` | kebab-case | nazwa serwisu / mikroserwisu |
| `Team` | kebab-case | odpowiedzialny team |
| `Version` | semver lub git SHA | `1.2.3` |
| `Backup` | `enabled` / `disabled` | polityka backupu |
| `Schedule` | `always-on` / `office-hours` | kiedy zasób ma działać |

## Wartości standaryzowane

```
Environment:  dev | staging | prod
ManagedBy:    terraform | terragrunt | cloudformation | manual | helm
```

## Terraform — przykład

```hcl
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    ManagedBy   = "terraform"
    CostCenter  = var.cost_center
  }
}

resource "aws_instance" "example" {
  # ...
  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${var.environment}-app"
    Service = "api"
  })
}
```

## Weryfikacja

```bash
# Sprawdź zasoby bez tagu Environment
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Environment \
  --query 'ResourceTagMappingList[?Tags[?Key==`Environment`]==`[]`]'

# Lista zasobów z tagiem
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=devops-toolkit
```

## Powiązane

- [[iac-standard]]
- [[finops-reporting]]
- `70-finops/tagging-review-template.md`
