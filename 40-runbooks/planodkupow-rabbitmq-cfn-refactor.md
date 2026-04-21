# planodkupow — RabbitMQ: wyjście z ROOT stack CFN

#aws #cloudformation #rabbitmq #planodkupow #architecture #runbook

**Data:** 2026-04-21
**Status QA:** DONE ✅ (2026-04-21 22:42)
**Status UAT:** DO WDROŻENIA
**Status PROD:** DO WDROŻENIA (po UAT)

---

## Kontekst

### Problem w starym modelu

- ROOT update dotykał wszystkich nested stacków
- Nawet zmiana aplikacyjna mogła wywołać update DBStack / Redis / ALB
- RabbitMQ w tym samym lifecycle → rollback przy unrelated zasobach
- Duży blast radius, niestabilne deploye, trudne recovery

### Rozwiązanie

- RabbitMQ jako osobny lifecycle
- Kontrakt przez SSM zamiast `!GetAtt`

---

## Docelowy model

```
ROOT stack — nie zawiera RabbitMQStack

KlasterStack:
  MQCS: '{{resolve:ssm:/planodkupow/<env>/rabbitmq/mqcs}}'

RabbitMQ:
  zarządzany osobno (manual / dedykowany stack)
```

---

## Zakres zmiany w ROOT.yml

### Zmiana 1 — źródło MQCS (KlasterStack parameters)

```yaml
# USUŃ:
MQCS: !GetAtt [RabbitMQStack, Outputs.MQCS]

# DODAJ:
MQCS: '{{resolve:ssm:/planodkupow/<env>/rabbitmq/mqcs}}'
```

**Uwaga:** `{{resolve:ssm:...}}` (nie `ssm-secure`) — SSM parameter musi być typu `String`.
`ssm-secure` nie jest wspierany dla `AWS::CloudFormation::Stack/Properties/Parameters`.

### Zmiana 2 — usunięcie bloku RabbitMQStack

```yaml
# USUŃ CAŁY BLOK:
  RabbitMQStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: https://planodkupow-cf.s3.eu-central-1.amazonaws.com/RMQ.yml
      Parameters:
        Projekt: !Ref Projekt
        Srodowisko: !Ref Srodowisko
        MQSG: !GetAtt [ SecGroupStack, Outputs.MQSG ]
        Siec1: !GetAtt [ VPCStack, Outputs.PPr1 ]
        Siec2: !GetAtt [ VPCStack, Outputs.PPr2 ]
      Tags: [...]
```

---

## Warunki przed deployem (BLOCKERY)

Wszystkie muszą być spełnione:

1. Nowy broker istnieje i działa (State: RUNNING, poprawny endpoint)
2. ECS używa nowego brokera (100% serwisów przełączone, brak ruchu na starym)
3. SSM parameter `/planodkupow/<env>/rabbitmq/mqcs` istnieje jako `String`
4. Stary broker: DELETED lub DELETION_IN_PROGRESS (NIE aktywnie używany)
5. Stack stabilny: `UPDATE_COMPLETE` lub `UPDATE_ROLLBACK_COMPLETE`

---

## Procedura

### Krok 0 — weryfikacja stanu

```bash
# Stan stacka
aws cloudformation describe-stacks \
  --stack-name planodkupow-<env> \
  --region eu-central-1 --profile plan \
  --query 'Stacks[0].StackStatus' --output text

# Broker
aws mq list-brokers --region eu-central-1 --profile plan \
  --query 'BrokerSummaries[?contains(BrokerName,`<env>`)].[BrokerId,BrokerName,BrokerState]'
```

### Krok 1 — SSM parameter (typ String)

```bash
aws ssm put-parameter \
  --name "/planodkupow/<env>/rabbitmq/mqcs" \
  --value "amqps://<endpoint>:5671:admin:<password>" \
  --type String \
  --overwrite \
  --region eu-central-1 \
  --profile plan

# Weryfikacja
aws ssm get-parameter \
  --name "/planodkupow/<env>/rabbitmq/mqcs" \
  --region eu-central-1 --profile plan
```

### Krok 2 — patch ROOT.yml (z DEPLOYED template jako bazy)

**KRYTYCZNE:** Użyj aktualnie wdrożonego template jako bazy, NIE wersji z repo.
Różnica tagów między deployed a repo powoduje tag drift → DBStack update → SQLDatabase replacement → rollback.

```bash
# Pobierz deployed template
aws cloudformation get-template \
  --stack-name planodkupow-<env> \
  --region eu-central-1 --profile plan \
  --query 'TemplateBody' --output text > /tmp/ROOT_deployed.yml

# Wygeneruj patch
python3 - << 'EOF'
with open('/tmp/ROOT_deployed.yml', 'r') as f:
    content = f.read()

old_mqcs = "        MQCS: !GetAtt [RabbitMQStack, Outputs.MQCS ]"
new_mqcs = "        MQCS: '{{resolve:ssm:/planodkupow/<env>/rabbitmq/mqcs}}'"
content = content.replace(old_mqcs, new_mqcs, 1)

# usuń blok RabbitMQStack — dostosuj do faktycznej zawartości deployed template
# (może mieć Tags lub nie)

with open('/tmp/ROOT_patched.yml', 'w') as f:
    f.write(content)

# weryfikacja
remaining = [l for l in content.split('\n') if 'RabbitMQStack' in l or ('MQCS' in l and 'GetAtt' in l)]
print(f"Remaining bad refs: {remaining}")  # musi być pusta lista
EOF
```

### Krok 3 — upload do S3

```bash
aws s3 cp /tmp/ROOT_patched.yml \
  s3://planodkupow-cf/ROOT.yml \
  --region eu-central-1 --profile plan
```

### Krok 4 — change set (NIE execute)

```bash
TIMESTAMP=$(date +%s)
CS_NAME="remove-rabbitmq-from-root-${TIMESTAMP}"

PARAMS_JSON=$(aws cloudformation describe-stacks \
  --stack-name planodkupow-<env> \
  --region eu-central-1 --profile plan \
  --query 'Stacks[0].Parameters[*].ParameterKey' \
  --output json | python3 -c "
import sys, json
keys = json.load(sys.stdin)
result = [{'ParameterKey': k, 'UsePreviousValue': True} for k in keys]
print(json.dumps(result))
")

aws cloudformation create-change-set \
  --stack-name planodkupow-<env> \
  --change-set-name "${CS_NAME}" \
  --template-url https://planodkupow-cf.s3.eu-central-1.amazonaws.com/ROOT.yml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters "${PARAMS_JSON}" \
  --region eu-central-1 --profile plan

echo "CS_NAME=${CS_NAME}"
```

Czekaj na `CREATE_COMPLETE`, potem weryfikuj.

### Krok 5 — walidacja change setu (HARD STOP)

```bash
aws cloudformation describe-change-set \
  --stack-name planodkupow-<env> \
  --change-set-name "${CS_NAME}" \
  --region eu-central-1 --profile plan \
  --query 'Changes[*].{Action:ResourceChange.Action,LogicalId:ResourceChange.LogicalResourceId,Replacement:ResourceChange.Replacement}' \
  --output table
```

**SAFE tylko jeśli:**

| Stack | Akcja | Uwagi |
|-------|-------|-------|
| RabbitMQStack | DELETE | wymagane |
| KlasterStack | MODIFY | ECS rollout |
| pozostałe | MODIFY | tylko Dynamic/ResourceAttribute |

**HARD STOP jeśli:**

```bash
# Sprawdź DBStack details
aws cloudformation describe-change-set \
  --stack-name planodkupow-<env> \
  --change-set-name "${CS_NAME}" \
  --region eu-central-1 --profile plan \
  --query 'Changes[?ResourceChange.LogicalResourceId==`DBStack`].ResourceChange.Details[*].{Evaluation:Evaluation,Source:ChangeSource}' \
  --output table
```

- DBStack ma `Static` evaluation → STOP
- DBStack ma `DirectModification` → STOP
- `Replacement: True` gdziekolwiek → STOP
- DELETE poza RabbitMQStack → STOP

### Krok 6 — execute

```bash
aws cloudformation execute-change-set \
  --stack-name planodkupow-<env> \
  --change-set-name "${CS_NAME}" \
  --region eu-central-1 --profile plan
```

### Krok 7 — monitoring

```bash
# Root stack
for i in $(seq 1 60); do
  STATUS=$(aws cloudformation describe-stacks \
    --stack-name planodkupow-<env> \
    --region eu-central-1 --profile plan \
    --query 'Stacks[0].StackStatus' --output text)
  echo "$(date +%H:%M:%S) $STATUS"
  [[ "$STATUS" == "UPDATE_COMPLETE" ]] && break
  [[ "$STATUS" == *"ROLLBACK"* || "$STATUS" == *"FAILED"* ]] && echo "STOP — FAILURE" && break
  sleep 10
done
```

### Krok 8 — weryfikacja końcowa

```bash
# RabbitMQStack usunięty
aws cloudformation list-stack-resources \
  --stack-name planodkupow-<env> \
  --region eu-central-1 --profile plan \
  --query 'StackResourceSummaries[*].{Logical:LogicalResourceId,Status:ResourceStatus}' \
  --output table

# ECS healthy
aws ecs describe-services \
  --cluster planodkupow-<env>-Klaster \
  --services <wszystkie serwisy> \
  --region eu-central-1 --profile plan \
  --query 'services[*].[serviceName,desiredCount,runningCount,pendingCount]' \
  --output table
```

Oczekiwane: RabbitMQStack brak, ECS `desired==running`, `pending==0`.

---

## Recovery — stack w UPDATE_ROLLBACK_FAILED

Jeśli stack utknął (np. BasicBroker 404):

```bash
# Krok A — nested stack
aws cloudformation continue-update-rollback \
  --stack-name planodkupow-<env>-RabbitMQStack-<ID> \
  --resources-to-skip BasicBroker \
  --region eu-central-1 --profile plan

aws cloudformation wait stack-rollback-complete \
  --stack-name planodkupow-<env>-RabbitMQStack-<ID> \
  --region eu-central-1 --profile plan

# Krok B — root stack
aws cloudformation continue-update-rollback \
  --stack-name planodkupow-<env> \
  --resources-to-skip "planodkupow-<env>-RabbitMQStack-<ID>.BasicBroker" \
  --region eu-central-1 --profile plan

aws cloudformation wait stack-rollback-complete \
  --stack-name planodkupow-<env> \
  --region eu-central-1 --profile plan
```

---

## Najczęstsze błędy i ich przyczyny

### 1. DBStack UPDATE_FAILED — SQLDatabase requires replacement

**Przyczyna:** tag drift lub zmiana parametrów między deployed a uploaded ROOT.yml.

**Symptom:** `CloudFormation cannot update a stack when a custom-named resource requires replacing. Rename planodkupowqadb`

**Fix:** Zawsze patchuj deployed template (krok 2), nie wersję z repo. Tagi i parametry (zwłaszcza `DBSnapshotIdentifier`) muszą być identyczne z deployed.

### 2. ssm-secure nie działa dla nested stack parameters

**Przyczyna:** `{{resolve:ssm-secure:...}}` nie jest wspierany dla `AWS::CloudFormation::Stack/Properties/Parameters`.

**Fix:** SSM parameter jako typ `String` + `{{resolve:ssm:...}}`.

### 3. ParameterNotFound przy create-change-set

**Przyczyna:** SSM parameter nie istnieje.

**Fix:** Krok 1 (put-parameter) przed create-change-set.

### 4. Stack w UPDATE_ROLLBACK_FAILED blokuje change set

**Fix:** `continue-update-rollback` na nested + root (patrz sekcja Recovery).

### 5. DBSnapshotIdentifier nie istnieje w template

**Przyczyna:** Wgranie wersji z repo zamiast deployed. Deployed template może mieć parametry nieobecne w repo.

**Fix:** `get-template` ze stacka, nie `s3 cp` z repo.

---

## Postęp wdrożenia

| Środowisko | Status | Data | Uwagi |
|------------|--------|------|-------|
| QA | ✅ DONE | 2026-04-21 | 3 iteracje przez tag drift + DBStack recovery |
| UAT | ⏳ TODO | — | stack: UPDATE_ROLLBACK_COMPLETE |
| PROD | ⏳ TODO | — | po UAT |

---

## Stan po QA (reference)

```
Root stack:    UPDATE_COMPLETE
KlasterStack:  UPDATE_COMPLETE
RabbitMQStack: USUNIĘTY z root
ECS:           14/14 running, 0 pending
MQCS:          {{resolve:ssm:/planodkupow/qa/rabbitmq/mqcs}}
SSM:           /planodkupow/qa/rabbitmq/mqcs (String, Version 2)
Broker QA:     b-f231815d, mq.m7g.medium, RUNNING
```

---

*Ostatnia aktualizacja: 2026-04-21 — po zakończeniu QA*
