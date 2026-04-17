# Runbook — S3 bucket policy lockout

#aws #s3 #runbook

## Symptom

`AccessDenied` na bucket gdzie miałeś dostęp. Bucket policy może blokować nawet konto właściciela.

## Zakres

Jeden bucket. Sprawdź czy problem dotyczy wszystkich operacji czy tylko wybranych.

---

## Komendy diagnostyczne

```bash
BUCKET=nazwa-bucketu

# Sprawdź aktualną politykę
aws s3api get-bucket-policy --bucket $BUCKET

# Sprawdź ACL
aws s3api get-bucket-acl --bucket $BUCKET

# Sprawdź czy bucket jest publiczny
aws s3api get-public-access-block --bucket $BUCKET

# Sprawdź własność (account, który stworzył bucket)
aws s3api get-bucket-location --bucket $BUCKET
```

## Punkty decyzyjne

1. **Explicit Deny w policy** → policy musi być poprawiona przez konto które ma dostęp
2. **Public Access Block blokuje** → sprawdź ustawienia block public access
3. **Cross-account** → sprawdź czy rola ma odpowiednie uprawnienia cross-account
4. **SCP** → sprawdź Organizations SCP

## Naprawienie lockout (jeśli masz root lub admin)

```bash
# Usuń problematyczną politykę (ostrożnie!)
aws s3api delete-bucket-policy --bucket $BUCKET

# Lub podmień na poprawną politykę
aws s3api put-bucket-policy --bucket $BUCKET --policy file://policy.json
```

## Rollback / bezpieczeństwo

- Zanim usuniesz policy — zapisz aktualną wersję
- Jeśli bucket ma `prevent_destroy` w Terraform — nie usuwaj przez CLI
- Root account może zawsze nadpisać bucket policy (jeśli konto właściciel)

## Findings

<!-- Co znalazłeś i jak rozwiązano -->
