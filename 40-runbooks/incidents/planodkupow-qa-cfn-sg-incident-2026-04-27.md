---
date: 2026-04-27
tags: [#incident, #cloudformation, #aws, #iam, #securitygroup]
project: planodkupow
env: qa
region: eu-central-1
---

# Incydent: CFN UPDATE_ROLLBACK_FAILED — SecGroupStack / MQSG — QA

## Objaw

Root stack `planodkupow-qa` utknął w `UPDATE_ROLLBACK_FAILED` po próbie aktualizacji SG.yaml.

```
Root stack:   planodkupow-qa                             → UPDATE_ROLLBACK_FAILED
Nested stack: planodkupow-qa-SecGroupStack-86WXRW5TVXUF  → UPDATE_ROLLBACK_FAILED
Failed resource: MQSG (AWS::EC2::SecurityGroup, sg-05f145a760d343b50)
```

## Kontekst

Deployment zawierał prostą zmianę reguły ingress (zmiana portu) w MQSG. CloudFormation podczas rollbacku próbował wywołać `ec2:RevokeSecurityGroupIngress` — akcja nie była w żadnej policy IAM usera `planodkupow-auto`.

Rollback wyłożył się **dwa razy** tym samym błędem:
- przy próbie UPDATE (usunięcie starej reguły)
- przy próbie ROLLBACK (przywrócenie starej reguły)

Dokładny error:
```
User: arn:aws:iam::333320664022:user/planodkupow-auto
is not authorized to perform: ec2:RevokeSecurityGroupIngress
on resource: arn:aws:ec2:eu-central-1:333320664022:security-group/sg-05f145a760d343b50
HandlerErrorCode: AccessDenied
```

## Rozwiązanie

### 1. Patch IAM

Zaktualizowano policy `planodkupow-auto-CFN-Describe-Fix` (v7 → v8, usunięto v3 żeby zmieścić w limicie 5 wersji):

```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:RevokeSecurityGroupIngress",
    "ec2:AuthorizeSecurityGroupIngress"
  ],
  "Resource": "arn:aws:ec2:eu-central-1:333320664022:security-group/sg-05f145a760d343b50"
}
```

### 2. continue-update-rollback

**Ważne:** `continue-update-rollback` na nested stacku zwraca błąd:
```
RollbackUpdatedStack cannot be invoked on child stacks
```
Należy zawsze wywoływać na **root stacku**:

```bash
aws cloudformation continue-update-rollback \
  --stack-name planodkupow-qa \
  --region eu-central-1 \
  --profile plan
```

### 3. Wynik

```
planodkupow-qa-SecGroupStack-86WXRW5TVXUF → UPDATE_ROLLBACK_COMPLETE
planodkupow-qa                             → UPDATE_ROLLBACK_COMPLETE
```

Rollback zakończony bez skipowania MQSG. Stan SG przywrócony do poprzedniego.

## Uwagi

- `ec2:AuthorizeSecurityGroupIngress` dodane profilaktycznie — bez niego następna aktualizacja SG też by się wyłożyła przy dodawaniu nowej reguły
- Uprawnienie jest scoped na konkretne SG (`sg-05f145a760d343b50`), nie `*`
- Jeśli MQSG zostanie w przyszłości zastąpiony (replace), nowy SG będzie miał inny ID — trzeba zaktualizować policy
- Po recovery zmiana z nieudanego deployu jest utracona — następny deploy SG.yaml nałoży ją ponownie (tym razem bez błędu)
- Wzorzec do zapamiętania: każda zmiana SG rules w CFN wymaga zarówno `Authorize` jak i `Revoke` na tym samym zasobie
