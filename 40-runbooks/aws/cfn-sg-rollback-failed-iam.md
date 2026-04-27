---
tags: [#incident, #cloudformation, #iam, #securitygroup, #runbook, #pattern]
projekty: [planodkupow]
środowiska: [qa, uat]
potwierdzone: 2026-04-27
---

# Wzorzec: CFN UPDATE_ROLLBACK_FAILED — brakujące uprawnienie IAM na SecurityGroup

## 1. Executive Summary

Ten sam incydent wystąpił niezależnie w dwóch środowiskach (QA i UAT) tego samego dnia. Prosta zmiana portu w SG.yaml spowodowała zablokowanie rollbacku CloudFormation z powodu braku uprawnienia `ec2:RevokeSecurityGroupIngress` u użytkownika CI. Ponieważ ten sam brak uprawnień blokuje zarówno **update** jak i **rollback**, stack ląduje w `UPDATE_ROLLBACK_FAILED` bez możliwości samonaprawy.

Odblokowanie w obu środowiskach zajęło < 5 minut po dodaniu uprawnień. Zero skipowanych zasobów. Zero driftu.

---

## 2. Podsumowanie pary incydentów

| | QA | UAT |
|---|---|---|
| Root stack | `planodkupow-qa` | `planodkupow-uat` |
| Nested stack | `planodkupow-qa-SecGroupStack-86WXRW5TVXUF` | `planodkupow-uat-SecGroupStack-GB68K9QVSRJ0` |
| Failing resource | `MQSG` (`AWS::EC2::SecurityGroup`) | `MQSG` (`AWS::EC2::SecurityGroup`) |
| Physical SG | `sg-05f145a760d343b50` | `sg-090925805cd202b78` |
| Root cause | brak `ec2:RevokeSecurityGroupIngress` | identyczny |
| Zmiana wyzwalająca | zmiana portu w SG.yaml | identyczna |
| Recovery bez skip | TAK | TAK |
| Czas do `UPDATE_ROLLBACK_COMPLETE` | ~1 min | ~1 min |

Oba incydenty potwierdziły **systemową lukę IAM** — nie defekt środowiskowy.

---

## 3. Analiza przyczyny

CloudFormation przy aktualizacji reguł SecurityGroup wykonuje sekwencję:
1. `AuthorizeSecurityGroupIngress` — dodaje nową regułę
2. `RevokeSecurityGroupIngress` — usuwa starą regułę

Jeśli user CI nie ma `ec2:RevokeSecurityGroupIngress`, krok 2 failuje z `AccessDenied`. CFN próbuje rollbacku — rollback też wymaga `RevokeSecurityGroupIngress` (przywrócenie starej reguły wymaga usunięcia częściowo nałożonej). Efekt: stack ląduje w `UPDATE_ROLLBACK_FAILED` i jest w pełni zablokowany.

**Ważne:** problem nie dotyczy tylko zmiany port → port. Każda modyfikacja reguły ingressowej (dodanie, usunięcie, zmiana źródła, zmiana protokołu) wymaga obu akcji.

---

## 4. Wzorzec recovery — potwierdzony w dwóch środowiskach

### Krok 1 — weryfikacja root cause

```bash
# status root stacka
aws cloudformation describe-stacks \
  --stack-name <root-stack> \
  --region eu-central-1 --profile <profil> \
  --query 'Stacks[0].[StackStatus,StackStatusReason]' --output table

# fizyczna nazwa nested SecGroupStack
aws cloudformation describe-stack-resources \
  --stack-name <root-stack> \
  --region eu-central-1 --profile <profil> \
  --query 'StackResources[?LogicalResourceId==`SecGroupStack`].[PhysicalResourceId,ResourceStatus]' \
  --output text

# exact error z nested stacka
aws cloudformation describe-stack-events \
  --stack-name <nested-stack-name> \
  --region eu-central-1 --profile <profil> \
  --max-items 10 \
  --query 'StackEvents[?ResourceStatus==`UPDATE_FAILED`].[LogicalResourceId,ResourceType,ResourceStatusReason]' \
  --output json
```

Potwierdzasz incydent IAM jeśli widzisz:
- `LogicalResourceId`: `MQSG` (lub inny SG resource)
- `ResourceStatusReason`: zawiera `ec2:RevokeSecurityGroupIngress` + `AccessDenied`

### Krok 2 — patch IAM

Dodaj do policy CI usera nowy statement (scoped na konkretne SG, nie `*`):

```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:RevokeSecurityGroupIngress",
    "ec2:AuthorizeSecurityGroupIngress",
    "ec2:RevokeSecurityGroupEgress",
    "ec2:AuthorizeSecurityGroupEgress"
  ],
  "Resource": "arn:aws:ec2:<region>:<account-id>:security-group/<sg-id>"
}
```

Physical SG ID odczytujesz z eventu błędu lub przez:
```bash
aws cloudformation describe-stack-resource \
  --stack-name <nested-stack> \
  --logical-resource-id MQSG \
  --region eu-central-1 --profile <profil> \
  --query 'StackResourceDetail.PhysicalResourceId' --output text
```

IAM policy może mieć max 5 wersji — jeśli limit osiągnięty, usuń najstarszą non-default przed tworzeniem nowej:
```bash
aws iam delete-policy-version --policy-arn <arn> --version-id <stara-wersja> --profile <profil>
aws iam create-policy-version --policy-arn <arn> --policy-document file://policy.json --set-as-default --profile <profil>
```

### Krok 3 — continue-update-rollback

**ZAWSZE na root stacku, nigdy na nested.**

```bash
aws cloudformation continue-update-rollback \
  --stack-name <root-stack> \
  --region eu-central-1 \
  --profile <profil>
```

Wywołanie na nested stacku kończy się błędem:
```
RollbackUpdatedStack cannot be invoked on child stacks
```

### Krok 4 — monitoring

```bash
# polling obu stacków
watch -n 5 'aws cloudformation describe-stacks \
  --stack-name <root-stack> --region eu-central-1 --profile <profil> \
  --query "Stacks[0].StackStatus" --output text'
```

Oczekiwane wyniki:
- `<nested>-SecGroupStack-*` → `UPDATE_ROLLBACK_COMPLETE`
- `<root-stack>` → `UPDATE_ROLLBACK_COMPLETE`

---

## 5. Anti-Patterns

| Anti-pattern | Dlaczego złe |
|---|---|
| Domyślny skip (`--resources-to-skip MQSG`) | Zostawia SG w niespójnym stanie — reguły mogą być w połowie zaktualizowane. Następny deploy może duplikować reguły lub failować z innego powodu |
| `continue-update-rollback` na nested stacku | AWS nie pozwala — zawsze failuje z `RollbackUpdatedStack cannot be invoked on child stacks` |
| Anulowanie update przed sprawdzeniem runtime | Może ukryć prawdziwy problem (zob. Pattern B niżej) |
| Dodanie `ec2:*` do policy CI zamiast konkretnych akcji | Nadmierne uprawnienia — scoped resource jest bezpieczniejszy |
| Zakładanie że QA fix pokrywa UAT | SG IDs różnią się między środowiskami — policy musi zawierać ARN dla każdego SG z osobna |

---

## 6. Wzorce wielokrotnego użytku

### Pattern A — Brakujące uprawnienie IAM blokuje rollback SG

**Symptom:**
```
SecGroupStack → UPDATE_ROLLBACK_FAILED
MQSG (AWS::EC2::SecurityGroup) → UPDATE_FAILED
Reason: ec2:RevokeSecurityGroupIngress — AccessDenied
```

**Trigger:** każda modyfikacja reguł ingressowych/egressowych SG przez CFN

**Fix:**
1. Dodaj `ec2:RevokeSecurityGroupIngress` + `ec2:AuthorizeSecurityGroupIngress` do policy CI
2. `continue-update-rollback` na **root stacku**
3. Poczekaj na `UPDATE_ROLLBACK_COMPLETE`

**Czas naprawy:** < 5 min po identyfikacji

---

### Pattern B — Health check mismatch blokuje stabilizację ECS

**Symptom:**
CFN update utknął w `UPDATE_IN_PROGRESS` — ECS task nie przechodzi health checku, target group nie stabilizuje, deployment timeout.

**Przykład (planodkupow QA, wcześniejszy incydent):**
ALB health check skierowany na `/signin` → zwracał 404 → ECS deployment nigdy nie osiągał healthy.

**Mitigation:**
Zmień ścieżkę health checku na działający endpoint (`/api/health`) bezpośrednio na target group (poza CFN), bez modyfikacji szablonu. Stack odblokowuje się i osiąga `UPDATE_COMPLETE`.

**Fix na stałe:** zaktualizuj health check path w szablonie ALB/ECS na endpoint który zawsze zwraca 200.

---

## 7. Wymagane zmiany baseline IAM dla CI userów

Każdy user CI który deployuje stacki zawierające `AWS::EC2::SecurityGroup` **musi mieć** w swojej policy:

```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:AuthorizeSecurityGroupIngress",
    "ec2:RevokeSecurityGroupIngress",
    "ec2:AuthorizeSecurityGroupEgress",
    "ec2:RevokeSecurityGroupEgress",
    "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
    "ec2:UpdateSecurityGroupRuleDescriptionsEgress"
  ],
  "Resource": "arn:aws:ec2:<region>:<account>:security-group/*"
}
```

Alternatywnie scoped do konkretnych SG jeśli polityka organizacji wymaga minimalnych uprawnień.

**Dlaczego egress też:** CFN modyfikuje reguły egressowe tym samym mechanizmem. Brak `RevokeSecurityGroupEgress` spowoduje identyczny incydent przy pierwszej zmianie reguły egress.

---

## 8. Preflight przed deploym SG

Przed każdym `terraform apply` / `aws cloudformation deploy` zawierającym zmiany SG:

```bash
# 1. Sprawdź czy CI user ma wymagane SG akcje
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::<account>:user/<ci-user> \
  --action-names ec2:RevokeSecurityGroupIngress ec2:AuthorizeSecurityGroupIngress \
  --resource-arns arn:aws:ec2:<region>:<account>:security-group/<sg-id> \
  --profile <admin-profil>

# Oczekiwany wynik: EvalDecision = allowed

# 2. Sprawdź obecny stan SG (baseline przed zmianą)
aws ec2 describe-security-groups \
  --group-ids <sg-id> \
  --region eu-central-1 --profile <profil> \
  --query 'SecurityGroups[0].IpPermissions'
```

---

## 9. Lekcja platformowa (LLZ / standard)

Ten incydent odsłonił wzorzec który będzie się powtarzał w każdym projekcie gdzie:
- CI user ma wąsko skrojone uprawnienia
- CFN zarządza Security Groups przez nested stacki
- Nikt nie przetestował scenariusza rollbacku

**Nie jest to defekt projektu planodkupow.** To systemowa luka w definicji minimalnych uprawnień CI dla CloudFormation.

Rekomendacja dla LLZ / platform standard (`30-standards/iac.md` lub `30-standards/cicd.md`):

> Każdy projekt deploying Security Groups przez CloudFormation musi mieć CI user z uprawnieniami `ec2:Authorize/Revoke SecurityGroupIngress/Egress`. To jest warunek konieczny poprawnego rollbacku, nie opcjonalne rozszerzenie.

Bez tego standardu każdy nowy projekt będzie odkrywał ten sam problem przy pierwszej zmianie reguły SG w produkcji.

---

## 10. Follow-up — Jenkins / CFN hardening

- [ ] Dodać `ec2:RevokeSecurityGroupIngress/Egress` + `ec2:AuthorizeSecurityGroupIngress/Egress` do **baseline policy CI** dla wszystkich projektów z SG w CFN
- [ ] Dodać preflight simulation (`iam simulate-principal-policy`) do pipeline przed krokiem deploy SG stacka
- [ ] Sprawdzić czy inne projekty mają ten sam brak (pbms, rshop, maspex — każdy projekt z `AWS::EC2::SecurityGroup` w CFN)
- [ ] Zstandaryzować ścieżkę health checku ECS (`/api/health` lub `/health`) jako konwencja platformy — nie pozostawiać jako per-project tribal knowledge
- [ ] Rozważyć dodanie `continue-update-rollback` jako krok recovery w Jenkins pipeline (z flagą `--resources-to-skip` jako ostateczność, z alertem)
