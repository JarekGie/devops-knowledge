# Konwencje nazewnictwa

#standard

## Zasada ogólna

```
{projekt}-{środowisko}-{typ}-{suffix}
```

Wszystko **kebab-case**, tylko małe litery, bez znaków specjalnych.

## AWS zasoby

| Typ | Format | Przykład |
|-----|--------|---------|
| VPC | `{proj}-{env}-vpc` | `toolkit-prod-vpc` |
| Subnet | `{proj}-{env}-{pub/priv}-{az}` | `toolkit-prod-priv-a` |
| Security Group | `{proj}-{env}-sg-{opis}` | `toolkit-prod-sg-alb` |
| ECS Cluster | `{proj}-{env}-cluster` | `toolkit-prod-cluster` |
| ECS Service | `{proj}-{env}-svc-{nazwa}` | `toolkit-prod-svc-api` |
| RDS | `{proj}-{env}-db-{typ}` | `toolkit-prod-db-postgres` |
| S3 Bucket | `{proj}-{env}-{cel}-{account}` | `toolkit-prod-assets-123456789` |
| IAM Role | `{proj}-{env}-role-{opis}` | `toolkit-prod-role-ecs-task` |
| Lambda | `{proj}-{env}-fn-{opis}` | `toolkit-prod-fn-notifier` |

## Terraform

| Element | Format |
|---------|--------|
| Moduł | `modules/{typ-zasobu}` |
| Zmienna | `snake_case` |
| Output | `snake_case` |
| Local | `snake_case` |

## Kontenery / Images

```
{registry}/{projekt}/{serwis}:{tag}
# tag = git SHA (short) lub semver
123456789.dkr.ecr.eu-west-1.amazonaws.com/toolkit/api:abc1234
```

## Repozytoria Git

```
{org}/{projekt}-{typ}
# przykłady:
devops-toolkit
devops-toolkit-docs
devops-platform-modules
```

## Środowiska

| Skrót | Pełna nazwa |
|-------|-------------|
| `dev` | Development |
| `staging` | Staging / QA |
| `prod` | Production |

## Regiony AWS (aliasy)

| Alias | Region AWS |
|-------|-----------|
| `euw1` | eu-west-1 |
| `euw2` | eu-west-2 |
| `use1` | us-east-1 |

## Powiązane

- [[iac-standard]]
- [[aws-tagging-standard]]
