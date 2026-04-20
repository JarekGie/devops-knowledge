# planodkupow UAT — RabbitMQ UPDATE_ROLLBACK_FAILED (2026-04-20)

#incident #aws #cloudformation #planodkupow

**Data:** 2026-04-20
**Środowisko:** UAT (`planodkupow-uat`, konto `333320664022`, `eu-central-1`)
**Status:** PLAN GOTOWY — czeka na wykonanie

---

## 1. Objaw / symptom

```
Stack:      planodkupow-uat → UPDATE_ROLLBACK_FAILED
Przyczyna:  Rollback próbuje przywrócić RabbitMQ do wersji 3.8.6 (EOL)
            AWS odrzuca: "Broker engine version [3.8.6] is invalid. Valid values: [4.2, 3.13]"
Broker:     RUNNING (3.13.7, mq.t3.micro) — dane bezpieczne
```

---

## 2. Stan stacków

| Nested stack | Stan |
|---|---|
| RabbitMQStack | `UPDATE_ROLLBACK_FAILED` — `BasicBroker` w `UPDATE_FAILED` |
| DBStack | `UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS` → zakończy sam |
| Pozostałe 7 | `UPDATE_COMPLETE` — OK |

**Fizyczne identyfikatory:**
- Root stack: `planodkupow-uat`
- Nested RabbitMQStack: `planodkupow-uat-RabbitMQStack-1XMB1IYDKWTXU`
- Nested DBStack: `planodkupow-uat-DBStack-1XG4EQK2F3VWE`
- Broker ID: `b-2d26b881-79f2-4c3c-8b77-06c1a0fb0b29`
- Broker name: `planodkupow-uat-RabbitMQ`

---

## 3. Root Cause

### Drift przedwdrożeniowy

Template CFN (`RMQ.yml`) miał `EngineVersion: "3.8.6"` i `AutoMinorVersionUpgrade: "true"`.
AWS auto-upgrade podniósł broker do `3.13.7` **poza świadomością CFN** — drift istniał przed deployem.

### Sekwencja zdarzeń

```
09:16:42  Deploy startuje (zmiana wersji 3.8.6 → 3.13 + t3.micro → m5.large)
09:16:45  BasicBroker UPDATE_IN_PROGRESS
09:16:46  BasicBroker UPDATE_FAILED — "mq:DescribeBroker not authorized" (AccessDenied)
          → broker NIE był dotknięty (fail przed jakąkolwiek zmianą, 1 sekunda)
09:16:46  Rollback startuje — próbuje "przywrócić" broker do 3.8.6

09:17:05  BasicBroker UPDATE_FAILED — "This account is suspended (AWSLambda)"
          → wewnętrzny błąd AWS custom resource handler
09:17:06  RabbitMQStack → UPDATE_ROLLBACK_FAILED

[nieudane continue-update-rollback na root stacku — zły format resources-to-skip]

10:09:23  continue-update-rollback (User Initiated)
10:09:26  BasicBroker UPDATE_FAILED — "Broker engine version [3.8.6] is invalid"
10:09:27  RabbitMQStack → UPDATE_ROLLBACK_FAILED

[3 kolejne próby z root stacka — błędne formaty]:
  --resources-to-skip BasicBroker           → "does not belong to stack planodkupow-uat"
  --resources-to-skip RabbitMQStack         → "Nested stacks could not be skipped"
  (stack-name = RabbitMQStack)              → "Stack [RabbitMQStack] does not exist"
```

### Dlaczego pominięcie BasicBroker jest bezpieczne

Broker **nigdy nie był zmieniany** przez deployment (AccessDenied 1s po starcie).
Stan brokera po nieudanym deployu = identyczny jak przed = `3.13.7 RUNNING`.
Pominięcie rollbacku = zostawienie brokera w pre-update state = prawidłowe zachowanie.

---

## 4. Plan odblokowania (gotowy do wykonania)

### Warunek wstępny

Poczekaj na zakończenie DBStack cleanup:

```bash
aws cloudformation describe-stacks \
  --stack-name "planodkupow-uat-DBStack-1XG4EQK2F3VWE" \
  --profile plan --region eu-central-1 \
  --query 'Stacks[0].StackStatus' --output text
# Oczekiwane: UPDATE_ROLLBACK_COMPLETE
```

### Krok 1 — continue-update-rollback na ROOT stacku z pominięciem BasicBroker

```bash
aws cloudformation continue-update-rollback \
  --stack-name planodkupow-uat \
  --resources-to-skip "planodkupow-uat-RabbitMQStack-1XMB1IYDKWTXU.BasicBroker" \
  --profile plan --region eu-central-1
```

**Krytyczna uwaga:** `continue-update-rollback` wywołujemy TYLKO na root stacku.
Format skip dla zasobów w nested stackach: `<runtime-nested-stack-name>.<LogicalResourceId>`.
Nie używać samego `BasicBroker` (należy do nested stacka, nie root) ani `RabbitMQStack.BasicBroker`
(to logical ID, nie runtime name).

### Krok 2 — weryfikacja (~60 sekund po kroku 1)

```bash
# Root stack
aws cloudformation describe-stacks \
  --stack-name planodkupow-uat \
  --profile plan --region eu-central-1 \
  --query 'Stacks[0].{Status:StackStatus,Reason:StackStatusReason}' --output table

# RabbitMQStack
aws cloudformation describe-stacks \
  --stack-name "planodkupow-uat-RabbitMQStack-1XMB1IYDKWTXU" \
  --profile plan --region eu-central-1 \
  --query 'Stacks[0].{Status:StackStatus,Reason:StackStatusReason}' --output table

# Broker — upewnij się że niezmieniony
aws mq describe-broker \
  --broker-id "b-2d26b881-79f2-4c3c-8b77-06c1a0fb0b29" \
  --profile plan --region eu-central-1 \
  --query '{State:BrokerState,Version:EngineVersion}' --output table
```

**Oczekiwane wyniki:**

| Zasób | Oczekiwany stan |
|---|---|
| `planodkupow-uat` | `UPDATE_ROLLBACK_COMPLETE` |
| `planodkupow-uat-RabbitMQStack-1XMB1IYDKWTXU` | `UPDATE_ROLLBACK_COMPLETE` |
| Broker `BrokerState` | `RUNNING` |
| Broker `EngineVersion` | `3.13.7` (niezmieniony) |

### Warunki zatrzymania (STOP — nie ponawiaj)

```
UPDATE_ROLLBACK_FAILED z NOWYM komunikatem → zapisz StatusReason, nie ponawiaj, eskaluj
UPDATE_ROLLBACK_FAILED z TYM SAMYM komunikatem → format nie zadziałał → AWS Support
BrokerState = REBOOT_IN_PROGRESS lub UPDATING → czekaj, nic nie rób
BrokerState = EngineVersion zmieniony z 3.13.7 → STOP, raportuj natychmiast
```

---

## 5. Ryzyko

| Co | CFN | AWS | Dane | Przyszłe deploy |
|---|---|---|---|---|
| BasicBroker pominięty w rollbacku | Oznaczony jako skipped, stack → `UPDATE_ROLLBACK_COMPLETE` | Broker 3.13.7 RUNNING, bez zmian | Bezpieczne | ⚠ Kolejny deploy dotykający RabbitMQStack spróbuje ustawić 3.8.6 → fail |
| DBStack | Zakończony cleanup | Bez zmian | Bezpieczne | OK |
| Root stack | `UPDATE_ROLLBACK_COMPLETE` | Operacyjny | Bezpieczne | OK |

---

## 6. Wymagane działanie po odblokowaniu

Przed kolejnym deployem zaktualizować `RMQ.yml`:

```yaml
# było:
EngineVersion: "3.8.6"
HostInstanceType: mq.t3.micro

# powinno być:
EngineVersion: "3.13"
HostInstanceType: mq.m5.large   # t3.micro nie jest wspierany dla RabbitMQ
```

Bez tej zmiany każdy następny deploy UAT ponownie zakończy się tym samym błędem.
(Na QA ta zmiana już jest — `RMQ.yml` w `infra-bbmt/cloudformation/` jest naprawiony.)

---

## 7. Czego NIE robić

- NIE uruchamiać `continue-update-rollback` na child stacku jako `--stack-name`
- NIE używać `--resources-to-skip BasicBroker` (zasób jest w nested stacku, nie w root)
- NIE używać `--resources-to-skip RabbitMQStack` (CFN nie pozwala skipować całych nested stacków)
- NIE robić delete + redeploy (brak potrzeby, UAT ma dane)
- NIE robić change setu naprzód (zbędne, broker działa)

---

*Utworzono: 2026-04-20 | Status: PLAN GOTOWY*
