# Runbook — Terraform state lock

#terraform #runbook

## Symptom

```
Error acquiring the state lock
Lock Info:
  ID:        xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  Path:      s3://bucket/path/terraform.tfstate
  Operation: OperationTypeApply
  Who:       user@host
  Version:   1.x.x
  Created:   2026-01-01 12:00:00
```

## Zakres

Jeden workspace / Terragrunt unit. Nie rób force-unlock bez potwierdzenia że nikt nie ma aktywnego apply.

---

## Diagnostyka

```bash
# Sprawdź czy proces apply nadal działa
# Sprawdź CI pipeline, terminal innego użytkownika

# Sprawdź lock w DynamoDB
aws dynamodb get-item \
  --table-name terraform-locks \
  --key '{"LockID": {"S": "BUCKET/PATH/terraform.tfstate"}}' \
  --region eu-west-1
```

## Punkty decyzyjne

1. **Apply w toku (CI lub inny user)** → poczekaj, nie rób force-unlock
2. **Proces padł / CI failed** → bezpieczne force-unlock po potwierdzeniu
3. **Lock ID nieznany** → sprawdź DynamoDB, zidentyfikuj właściciela

## Force unlock — TYLKO gdy pewny że nikt nie ma active apply

```bash
terraform force-unlock LOCK_ID

# Terragrunt
terragrunt force-unlock LOCK_ID
```

## Rollback / bezpieczeństwo

- Force unlock przy aktywnym apply = korupcja state
- Zawsze sprawdź: CI pipeline, logi, inni użytkownicy
- Po force-unlock: uruchom `terraform plan` i sprawdź czy state jest spójny

## Findings

<!-- Wpisz przyczynę blokady i co zrobiono -->
