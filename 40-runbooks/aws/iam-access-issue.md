# Runbook — IAM access issue

#aws #iam #runbook

## Symptom

`AccessDenied` lub `UnauthorizedAccess` przy operacji AWS.

## Zakres

Dotyczy: roli IAM, użytkownika, OIDC, cross-account assume role.

---

## Komendy diagnostyczne

```bash
# Kim jesteś?
aws sts get-caller-identity

# Symulacja polityki (sprawdź czy rola może wykonać akcję)
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/NAZWA-ROLI \
  --action-names "s3:GetObject" \
  --resource-arns "arn:aws:s3:::BUCKET-NAME/*"

# Lista załączonych polityk do roli
aws iam list-attached-role-policies --role-name NAZWA-ROLI

# Inline policies roli
aws iam list-role-policies --role-name NAZWA-ROLI

# Szczegóły polityki
aws iam get-role-policy --role-name NAZWA-ROLI --policy-name NAZWA-POLITYKI

# Trust policy roli
aws iam get-role --role-name NAZWA-ROLI --query 'Role.AssumeRolePolicyDocument'
```

## Punkty decyzyjne

1. **AccessDenied na własne konto** → sprawdź policy roli / użytkownika
2. **AccessDenied cross-account** → sprawdź trust policy roli docelowej + permissions na źródle
3. **OIDC assume role** → sprawdź warunek `sts:sub` i `sts:aud` w trust policy
4. **SCP blokuje** → sprawdź AWS Organizations SCPs na koncie

## Sprawdzenie SCP

```bash
# Lista SCP na koncie (wymaga roli management account lub delegated admin)
aws organizations list-policies-for-target \
  --target-id ACCOUNT_ID \
  --filter SERVICE_CONTROL_POLICY
```

## Rollback / bezpieczeństwo

- Nie usuwaj roli pod presją — najpierw zrozum dlaczego jest zablokowana
- Jeśli musisz zmodyfikować politykę — najpierw dodaj uprawnienie, sprawdź, potem usuń stare
- Break-glass: użyj root account lub roli emergency-admin tylko w ostateczności

## Typowe przyczyny

| Przyczyna | Gdzie szukać |
|-----------|-------------|
| Brak uprawnienia w inline/managed policy | `iam list-attached-role-policies` |
| SCP blokuje na poziomie OU/konta | Organizations console |
| Trust policy nie zezwala na assume | `iam get-role` → AssumeRolePolicyDocument |
| Resource-based policy (np. S3 bucket policy) | Bucket policy w S3 console |
| KMS key policy blokuje | KMS console → key policy |
| VPC endpoint policy | VPC → Endpoints |

## Findings

<!-- Wpisz co znalazłeś -->
