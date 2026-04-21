# planodkupow UAT — RabbitMQ UPDATE_ROLLBACK_FAILED (2026-04-20)

#incident #aws #cloudformation #planodkupow

**Data:** 2026-04-20
**Środowisko:** UAT (`planodkupow-uat`, konto `333320664022`, `eu-central-1`)
**Status:** ZAMKNIĘTE OPERACYJNIE — rollback odblokowany, child stack drift zsynchronizowany

---

## 1. Objaw / symptom

```
Stack:      planodkupow-uat → UPDATE_ROLLBACK_FAILED
Przyczyna:  Rollback próbuje przywrócić RabbitMQ do wersji 3.8.6 (EOL)
            AWS odrzuca: "Broker engine version [3.8.6] is invalid. Valid values: [4.2, 3.13]"
Broker:     RUNNING (3.13.7, mq.t3.micro) — dane bezpieczne
```

---

## 2. Stan końcowy

| Zasób | Stan końcowy |
|---|---|
| Root `planodkupow-uat` | `UPDATE_ROLLBACK_COMPLETE` |
| `RabbitMQStack` | `UPDATE_COMPLETE` |
| `RedisStack` | `UPDATE_COMPLETE` |
| `DBStack` | `UPDATE_COMPLETE` |
| Pozostałe nested stacki | stabilne |

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

## 4. Wykonane odblokowanie

### Krok 1 — continue-update-rollback na ROOT stacku z pominięciem BasicBroker

```bash
aws cloudformation continue-update-rollback \
  --stack-name planodkupow-uat \
  --resources-to-skip "planodkupow-uat-RabbitMQStack-1XMB1IYDKWTXU.BasicBroker" \
  --profile plan --region eu-central-1
```

Wynik:
- root `planodkupow-uat` wrócił do `UPDATE_ROLLBACK_COMPLETE`
- broker pozostał niezmieniony: `RUNNING`, `3.13.7`, `mq.t3.micro`

### Krok 2 — minimalny sync child stacków

Po recovery wykonano dwa osobne change sety bez użycia root stacka.

#### RabbitMQ child stack

Stack:
- `planodkupow-uat-RabbitMQStack-1XMB1IYDKWTXU`

Zmiana:

```yaml
EngineVersion: "3.8.6" -> "3.13"
```

Wynik:
- tylko `BasicBroker`
- `Action = Modify`
- `Replacement = False`
- child stack `UPDATE_COMPLETE`
- broker po operacji: `RUNNING`, `3.13.7`, `mq.t3.micro`

#### Redis child stack

Stack:
- `planodkupow-uat-RedisStack-1DTSACMNM3U2T`

Zmiana:

```yaml
EngineVersion: 5.0.0 -> 5.0.6
```

Wynik:
- tylko `RedisCache`
- `Action = Modify`
- `Replacement = False`
- child stack `UPDATE_COMPLETE`
- Redis po operacji: `EngineVersion = 5.0.6`, `NodeType = cache.t3.micro`, `Status = available`

### Krok 3 — IAM baseline dla deployment identity

Uzupełniono managed policy:
- `arn:aws:iam::333320664022:policy/planodkupow-auto-CFN-Describe-Fix`

Aktywna wersja:
- `v3`

Najważniejsze dodane akcje:
- `cloudformation:Describe*`
- `cloudformation:List*`
- `cloudformation:GetTemplate`
- `cloudformation:GetTemplateSummary`
- `cloudformation:ValidateTemplate`
- `cloudformation:CreateChangeSet`
- `cloudformation:DescribeChangeSet`
- `cloudformation:ExecuteChangeSet`
- `elasticache:DescribeCacheClusters`
- `mq:DescribeBroker`
- `rds:DescribeDBInstances`
- `ec2:DescribeSubnets`
- `ec2:DescribeSecurityGroups`
- `ec2:DescribeVpcs`
- `logs:DescribeLogGroups`
- `logs:ListTagsForResource`

Walidacja profilem `planodkupow-auto`:
- `sts get-caller-identity` — OK
- `validate-template` — OK
- `create-change-set` — OK
- `describe-change-set` — OK
- ElastiCache / MQ / RDS / EC2 describe — OK

### Krok 4 — status końcowy

```bash
aws cloudformation describe-stacks \
  --stack-name planodkupow-uat \
  --profile plan --region eu-central-1 \
  --query 'Stacks[0].[StackStatus,StackStatusReason]' --output table
```

Aktualny wynik:
- `planodkupow-uat` → `UPDATE_ROLLBACK_COMPLETE`

---

## 5. Co pokazała analiza root scope

Analiza eventów ostatniego udanego root deployu pokazała:
- root stack formalnie przepuszcza `UPDATE_*` przez wszystkie nested stacki
- ale realne resource-level zmiany dotyczyły tylko `KlasterStack`
- `VPCStack`, `S3Stack`, `SecGroupStack`, `ALBStack`, `DBStack`, `RedisStack`, `RabbitMQStack`, `CFStack` były wtedy tylko pass-through

---

## 6. Status na rano

### App-only deploy na root stacku

Preflight na `2026-04-21`:
- root stack w stabilnym stanie końcowym
- brak aktywnej operacji
- Jenkins deploy typu `aws cloudformation update-stack --use-previous-template` ma status `GO`

### Root deploy z aktualnym `ROOT.yml`

To nadal **nie jest bezpieczne** jako minimalny sync:
- poprawne parametry UAT są już rozwiązane
- IAM jest już poprawne
- ale root change set na aktualnym `ROOT.yml` nadal formalnie dotyka 9 nested stacków

---

## 7. Czego NIE robić

- NIE uruchamiać `continue-update-rollback` na child stacku jako `--stack-name`
- NIE używać root change setu z szerokim scope jako „minimalnej synchronizacji”
- NIE traktować root `UPDATE_*` na nested stackach jako dowodu realnej zmiany zasobów
- NIE robić aplikacyjnego deployu bez poprawnych runtime parametrów / `UsePreviousValue=true`
- NIE wracać do `EngineVersion: "3.8.6"` dla RabbitMQ

---

*Utworzono: 2026-04-20 | Zaktualizowano: 2026-04-21 | Status: operacyjnie zamknięte, gotowe pod app-only deploy*
