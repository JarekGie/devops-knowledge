---
title: break-glass-ou-move
domain: client-work
tags:
  - aws
  - organizations
  - break-glass
  - root
  - mfa
  - runbook
created: "2026-05-07"
updated: "2026-05-07"
---

# Runbook: Break-Glass OU Move

#aws #organizations #break-glass #runbook

**Symptom / kiedy używać:** potrzebujesz operacji root na koncie member (MFA enrollment, zmiana email, reset hasła), ale `DenyRootUserActions` SCP blokuje wykonanie.

**Blast radius:** MINIMAL — jedno konto na raz, Break-Glass OU ma `DenyDisableSecurityServices` aktywne.

---

## Szybkie komendy

```bash
# Zmienne — wypełnij przed uruchomieniem
ACCOUNT_ID="XXXXXXXXXXXX"
BREAK_GLASS_OU="ou-z8np-XXXXXXXX"   # ← z terraform output break_glass_ou_id
PROFILE="mako-dc"

# 1. Znajdź oryginalny OU
ORIGINAL_OU=$(aws organizations list-parents \
  --child-id $ACCOUNT_ID --profile $PROFILE \
  --query 'Parents[0].Id' --output text)
echo "ORIGINAL_OU=$ORIGINAL_OU"  # ← zapisz to

# 2. Move do Break-Glass OU
aws organizations move-account \
  --account-id $ACCOUNT_ID \
  --source-parent-id $ORIGINAL_OU \
  --destination-parent-id $BREAK_GLASS_OU \
  --profile $PROFILE

# 3. Verify (poczekaj 60s)
sleep 60
aws organizations list-parents --child-id $ACCOUNT_ID --profile $PROFILE
# Oczekiwane: Break-Glass OU ID

# --- wykonaj maintenance (root console login) ---

# 4. Restore
aws organizations move-account \
  --account-id $ACCOUNT_ID \
  --source-parent-id $BREAK_GLASS_OU \
  --destination-parent-id $ORIGINAL_OU \
  --profile $PROFILE

# 5. Verify restore
aws organizations list-parents --child-id $ACCOUNT_ID --profile $PROFILE
# Oczekiwane: ORIGINAL_OU

# 6. Verify Break-Glass OU pusty
aws organizations list-children \
  --parent-id $BREAK_GLASS_OU \
  --child-type ACCOUNT \
  --profile $PROFILE
# Oczekiwane: pusta lista
```

---

## Decision points

- **Nie znasz ORIGINAL_OU?** → uruchom krok 1, zapisz wynik przed move
- **EventBridge alert przyszedł?** → oczekiwane, potwierdź w GLPI że to planowany maintenance
- **Konto nie wróciło do Original OU?** → uruchom krok 4 ponownie, sprawdź $ORIGINAL_OU
- **Maintenance trwa > 4h?** → alert eskaluje, wymagane potwierdzenie przez drugą osobę

## Rollback / safety

Konto utknęło w Break-Glass OU → zawsze możesz wykonać MoveAccount back. Break-Glass OU nie niszczy żadnych zasobów w koncie, zmienia tylko SCP inheritance.

## Findings / notes

- Propagation delay SCP: 15–60s po MoveAccount
- CloudTrail rejestruje MoveAccount → EventBridge alert wysyłany automatycznie
- Break-Glass OU ID: **wpisz po terraform apply** → `aws_organizations_organizational_unit.break_glass` output

**Pełny framework:** [[break-glass-framework]]
**Kontekst org:** [[aws-cloud-platform-context]]
