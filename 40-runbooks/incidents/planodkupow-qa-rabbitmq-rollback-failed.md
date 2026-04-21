# RUNBOOK — CloudFormation Incident: RabbitMQ / UPDATE_ROLLBACK_FAILED

#incident #aws #cloudformation #planodkupow

**Data:** 2026-04-21
**Środowisko:** QA (`planodkupow-qa`, konto `333320664022`, `eu-central-1`)
**Status:** ZAMKNIĘTE CAŁKOWICIE — drift usunięty, nowy broker aktywny, stary usunięty

---

## 1. Objaw / symptom

```
Stack:      planodkupow-qa → UPDATE_ROLLBACK_FAILED
Przyczyna:  Sekwencja braków IAM → AccessDenied → pętle rollback
Broker:     RUNNING przez cały incydent — dane bezpieczne
```

Nested stack:

```
planodkupow-qa-RabbitMQStack-PN8W0DD6SK1U → UPDATE_ROLLBACK_FAILED
Resource: AWS::AmazonMQ::Broker (BasicBroker)
Broker ID: b-5cb3fcb4-e8df-42af-9de3-cb004282af27
```

---

## 2. Root cause — łańcuch przyczynowy

### Incydent 1 (09:09 UTC)

```
AccessDenied: mq:UpdateBroker
User: arn:aws:iam::333320664022:user/planodkupow-auto
```

CFN deploy próbował UpdateBroker (z powodu CFN drift — patrz niżej).
Brak `mq:UpdateBroker` → UPDATE_FAILED → rollback też wymaga UpdateBroker → UPDATE_ROLLBACK_FAILED.

**Fix:** dodano `mq:UpdateBroker` ręcznie (policy v4).
**Recovery:** `continue-update-rollback` z skip `BasicBroker` (profil `plan`).

### Incydent 2 (10:02 UTC)

Po naprawie v4, kolejny deploy: UpdateBroker przeszedł, ale CFN chciał wykonać RebootBroker po zmianie.

```
AccessDenied: mq:RebootBroker
```

Rollback znów wymagał RebootBroker → drugi UPDATE_ROLLBACK_FAILED.

**Fix:** dodano `mq:RebootBroker` (policy v5).
**Recovery:** `continue-update-rollback` z skip (profil `plan`), łącznie x3.

### Drift CFN — pierwotna przyczyna pętli

Po każdym `continue-update-rollback --resources-to-skip`:
- CFN zamraża wewnętrzny stan zasobu na pre-update wartości
- Template + real broker: `mq.m5.large`
- CFN internal state: `mq.t3.micro` (frozen)
- Każdy kolejny deploy próbował przywrócić `mq.t3.micro` → UpdateBroker → AccessDenied → pętla

---

## 3. Rozwiązanie — RECREATE + CUTOVER

### Dlaczego nie IMPORT

CFN IMPORT wymaga stabilnego stanu stacka. Po `continue-update-rollback` z skip, stack jest w `UPDATE_ROLLBACK_COMPLETE` — formalnie stabilny, ale stan zasobu wewnętrznie niespójny. Ryzyko: IMPORT może nie rozwiązać driftu jeśli typ instancji nie pasuje.

Wybrana strategia: **RECREATE nowego brokera + CUTOVER ECS + DELETE starego**.

### Dlaczego nie mq.t3.micro

```
BadRequestException: Broker engine type [RabbitMQ] does not support host instance type [mq.t3.micro]
```

`mq.t3.micro` działa **tylko dla ActiveMQ**. Nowe brokerzy RabbitMQ: tylko `mq.m5.*` lub `mq.m7g.*`.
Stary broker `b-5cb3fcb4` działał na `mq.m5.large` — był stworzony w czasach gdy typy były inne lub przez pomyłkę.

### Tania opcja

```
mq.m7g.medium — ~$66/miesiąc (vs mq.m5.large ~$197/miesiąc, oszczędność ~66%)
```

### Sekwencja operacji

```bash
# 1. Utwórz nowy broker
aws mq create-broker \
  --broker-name planodkupow-qa-rabbitmq-cheap \
  --engine-type RabbitMQ \
  --engine-version 3.13 \
  --host-instance-type mq.m7g.medium \
  --deployment-mode SINGLE_INSTANCE \
  --publicly-accessible false \
  --subnet-ids subnet-0a8646f3cc6c56183 \
  --security-groups sg-05f145a760d343b50 \
  --user Username=admin,Password=<PASSWORD> \
  --region eu-central-1 --profile planodkupow-auto

# 2. Czekaj na RUNNING
aws mq describe-broker --broker-id <NEW_ID> --query 'BrokerState'

# 3. Cutover — change set na KlasterStack (tylko parametr MQCS)
aws cloudformation create-change-set \
  --stack-name planodkupow-qa-KlasterStack-1F8B7693FIMIX \
  --use-previous-template \
  --parameters ParameterKey=MQCS,ParameterValue=amqps://<NEW_ENDPOINT>:5671:admin:<PASSWORD> \
               [pozostałe: UsePreviousValue=true] \
  --capabilities CAPABILITY_NAMED_IAM \
  --change-set-name mqcs-cutover-to-new-broker

# 4. Waliduj change set: TYLKO ECS::TaskDefinition + ECS::Service, żadnych Replacement
# 5. Execute
aws cloudformation execute-change-set ...

# 6. Sprawdź 14/14 ECS serwisów healthy
# 7. Sprawdź metryki starego brokera: ConnectionCount/ChannelCount/ConsumerCount/PublishRate == 0

# 8. Usuń stary broker (wymaga ec2:DetachNetworkInterface — profil plan, nie planodkupow-auto)
aws mq delete-broker --broker-id <OLD_ID> --profile plan
```

---

## 4. Stan końcowy

| Zasób | Stan |
|---|---|
| root `planodkupow-qa` | `UPDATE_ROLLBACK_COMPLETE` |
| `planodkupow-qa-KlasterStack-1F8B7693FIMIX` | `UPDATE_COMPLETE` |
| Nowy broker `b-f231815d` (mq.m7g.medium) | `RUNNING` |
| Stary broker `b-5cb3fcb4` (mq.m5.large) | `DELETION_IN_PROGRESS` |
| ECS 14/14 serwisów | healthy |

---

## 5. IAM — wymagane uprawnienia dla CFN automation

Policy: `arn:aws:iam::333320664022:policy/planodkupow-auto-CFN-Describe-Fix`

### Wymagane do uniknięcia incydentu

| Akcja | Dlaczego |
|---|---|
| `mq:UpdateBroker` | CFN deploy może dotknąć brokera nawet przy zmianach ECS |
| `mq:RebootBroker` | Wymagane przez CFN po UpdateBroker |
| `mq:CreateBroker` | Do recreate poza CFN (opcjonalne dla breakglass) |
| `mq:DeleteBroker` | Do cleanup (uwaga: wymaga też EC2) |
| `ec2:DetachNetworkInterface` | Wymagane przy DeleteBroker (AWS odpina ENI) |
| `cloudformation:ContinueUpdateRollback` | Breakglass recovery bez operatora |

### Obserwacja

Brak **któregokolwiek** z powyższych może spowodować:
- zablokowany rollback → `UPDATE_ROLLBACK_FAILED`
- konieczność ręcznej interwencji z profilu operatora (`plan`)

### Historia wersji policy

```
v3: baseline CFN + mq:DescribeBroker
v4: + mq:UpdateBroker (dodane ręcznie po incydencie 1)
v5: + mq:RebootBroker (po incydencie 2)
v6: + mq:CreateBroker, mq:DeleteBroker
```

---

## 6. CloudFormation — pułapki

### Root stack UPDATE != real change

Root stack `planodkupow-qa` formalnie przepuszcza `UPDATE_*` przez **wszystkie** nested stacki podczas każdego deployu. Ale rzeczywiste resource-level zmiany mogą dotyczyć tylko jednego — np. `KlasterStack` (ECS).

Sygnały do rozróżnienia:
- zdarzenia na poziomie **zasobu** (np. `AWS::AmazonMQ::Broker UPDATE_IN_PROGRESS`) = real change
- zdarzenia na poziomie stacka (`AWS::CloudFormation::Stack UPDATE_*`) = może być tylko pass-through

### continue-update-rollback + skip = drift

Po `--resources-to-skip "StackName.Resource"`:
- zasób pozostaje niezmieniony w rzeczywistości
- CFN zamraża swój wewnętrzny stan na wartość *przed* updatem
- Template może być inny niż zamrożony stan
- Każdy kolejny deploy wykryje "zmianę" i spróbuje UpdateBroker

**Strategia naprawy driftu:**
1. IMPORT (wymaga stabilnego stacka, może nie działać przy niezgodności typów)
2. RECREATE + CUTOVER + DELETE (bezpieczniejsze, prostsze)

---

## 7. Bezpieczny model deploymentu (planodkupow)

### Jenkins — zakres BEZPIECZNY

```
update-stack z --use-previous-template
Zmiany parametrów: obrazy Docker, MQCS, Redis endpoint
Zmiany zasobów:    ECS::TaskDefinition, ECS::Service
```

### Jenkins — zakres NIEBEZPIECZNY

```
Zmiany root template (ROOT.yml)
Zmiany infra: AmazonMQ, RDS, ALB, VPC, Redis, Security Groups
Tagowanie / strukturalne modyfikacje CFN
```

### Wymagane działania operatora (manualne)

```
Lifecycle AmazonMQ (create/delete/import)
Reconciliacja driftu CFN
Refaktory template
Naprawy IAM
Recovery z UPDATE_ROLLBACK_FAILED (do czasu dodania cloudformation:ContinueUpdateRollback)
```

---

## 8. AmazonMQ (RabbitMQ) — typy instancji

| Typ | ActiveMQ | RabbitMQ |
|---|---|---|
| mq.t3.micro | TAK | NIE (nowe, od ~2023) |
| mq.m5.large | TAK | TAK |
| mq.m7g.medium | TAK | TAK |

**Wyjątek (legacy):** stare brokerzy RabbitMQ mogą działać na `mq.t3.micro` jeśli zostały stworzone wcześniej. **Nie można replikować — nowe deploy/change-type odrzuca ten typ.**

### In-place downgrade

NIE jest możliwy. Zmiana `HostInstanceType` wymaga:
1. Stworzenie nowego brokera (nowy ID, nowy endpoint)
2. Cutover aplikacji
3. Usunięcie starego

### Cennik (eu-central-1, marzec 2026)

```
mq.m5.large:   ~$197/miesiąc
mq.m7g.medium: ~$66/miesiąc  ← najtańszy obsługiwany RabbitMQ
```

---

## 9. Wzorzec cutover (standardowy)

Dla każdej zmiany wymagającej nowego brokera:

```
ADD:    Stwórz nowy broker → czekaj RUNNING
SWITCH: Zaktualizuj MQCS w aplikacji (change set ECS only)
VERIFY: ECS healthy + ConnectionCount na nowym > 0 + ConnectionCount na starym = 0
REMOVE: Usuń stary broker (wymagany profil z ec2:DetachNetworkInterface)
```

**Zasada:** nigdy nie usuwaj starego zasobu przed weryfikacją metryk ruchu.

---

## 10. Recovery command (breakglass)

```bash
# Wymaga profilu plan (operator)
aws cloudformation continue-update-rollback \
  --stack-name planodkupow-qa \
  --region eu-central-1 \
  --profile plan \
  --resources-to-skip "planodkupow-qa-RabbitMQStack-PN8W0DD6SK1U.BasicBroker"
```

---

## 11. Analogia z UAT

UAT miał ten sam symptom (`UPDATE_ROLLBACK_FAILED`, `BasicBroker`), inny root cause:
- UAT: rollback próbował przywrócić `EngineVersion: 3.8.6` (EOL) — AWS odrzuca jako invalid
- QA: IAM AccessDenied (UpdateBroker/RebootBroker) + drift na typie instancji

Ten sam fix operacyjny (`continue-update-rollback` z skip), różna przyczyna, różna finalna strategia.
UAT: minimal sync child stacka. QA: pełny recreate + cutover.

---

*Utworzono: 2026-04-21 | Status: zamknięte całkowicie*
