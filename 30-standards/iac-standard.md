# Standard IaC

#terraform #standard

## Zasady

1. **Wszystko w kodzie** — żadnych ręcznych zmian zasobów zarządzanych przez IaC
2. **State w S3 + locking w DynamoDB** — zawsze, bez wyjątku
3. **Pinuj wersje** — provider, moduły, Terraform binary
4. **Moduły zamiast copy-paste** — jeśli coś powtarzasz >2 razy, wydziel moduł
5. **Plan przed apply** — plan review jest obowiązkowy na prod
6. **`prevent_destroy`** na RDS, S3 state bucket, certyfikaty ACM

## Struktura modułu

```
modules/NAZWA-MODUŁU/
├── main.tf
├── variables.tf
├── outputs.tf
└── README.md          ← co robi moduł, wymagane zmienne
```

## Struktura środowisk (Terragrunt)

```
environments/
├── terragrunt.hcl     ← root: provider, remote state config
├── dev/
│   ├── terragrunt.hcl
│   └── ecs-service/
│       └── terragrunt.hcl
└── prod/
    └── ...
```

## Konwencje nazw

```hcl
# Zasoby: {projekt}-{env}-{typ}-{suffix}
resource "aws_ecs_service" "main" {
  name = "${var.project}-${var.environment}-svc-api"
}
```

→ [[naming-conventions]]

## Remote state

```hcl
# terragrunt.hcl (root)
remote_state {
  backend = "s3"
  config = {
    bucket         = "terraform-state-${local.account_id}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

## Taggowanie

→ [[aws-tagging-standard]]

## Powiązane

- [[naming-conventions]]
- [[aws-tagging-standard]]
- `40-runbooks/terraform/`
