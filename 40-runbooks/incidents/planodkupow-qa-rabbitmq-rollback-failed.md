# RUNBOOK — CloudFormation Incident: RabbitMQ / UPDATE_ROLLBACK_FAILED

#incident #aws #cloudformation #planodkupow

**Data:** 2026-04-21
**Środowisko:** QA (`planodkupow-qa`, konto `333320664022`, `eu-central-1`)
**Status:** ZAMKNIĘTE — stack naprawiony, IAM fix wdrożony

## Kontekst

Środowisko: AWS
Region: eu-central-1
Stack: `planodkupow-qa`
Typ deployu: root CloudFormation (`--use-previous-template`, parametry obrazów)

## Objaw

Stack wszedł w:

```
UPDATE_ROLLBACK_FAILED
```

Nested stack:

```
RabbitMQStack → UPDATE_FAILED
planodkupow-qa-RabbitMQStack-PN8W0DD6SK1U
```

Resource:

```
AWS::AmazonMQ::Broker (BasicBroker)
Broker ID: b-5cb3fcb4-e8df-42af-9de3-cb004282af27
```

## Root Cause

Bezpośrednia przyczyna:

```
AccessDenied (403) na mq:UpdateBroker
User: arn:aws:iam::333320664022:user/planodkupow-auto
```

Mechanizm:

1. Root deploy próbował wykonać zmianę na brokerze (nawet jeśli niezamierzoną).
2. IAM user `planodkupow-auto` NIE miał `mq:UpdateBroker`.
3. CloudFormation: FAIL podczas update → FAIL podczas rollback (rollback też wymaga UpdateBroker).
4. Stack utknął w `UPDATE_ROLLBACK_FAILED`.

Dodatkowy problem:

* brak `cloudformation:ContinueUpdateRollback` na `planodkupow-auto`
* recovery wymagał ręcznej interwencji z profilu `plan` (operator)

## Fakty operacyjne

* Broker był zdrowy przez cały incydent:
  * status: RUNNING
  * version: 3.13.7
  * instance: mq.m5.large
* Nie było realnej zmiany infrastruktury
* Problem = IAM, nie zasób

## Recovery (SAFE)

Wykonane z profilu `plan` (operator):

```bash
aws cloudformation continue-update-rollback \
  --stack-name planodkupow-qa \
  --region eu-central-1 \
  --profile plan \
  --resources-to-skip "planodkupow-qa-RabbitMQStack-PN8W0DD6SK1U.BasicBroker"
```

Efekt:

```
UPDATE_ROLLBACK_COMPLETE
```

Stan końcowy wszystkich nested stacków:

| Stack | Status |
|---|---|
| ALBStack | UPDATE_COMPLETE |
| CFStack | UPDATE_COMPLETE |
| DBStack | UPDATE_COMPLETE |
| KlasterStack | UPDATE_COMPLETE |
| RabbitMQStack | UPDATE_COMPLETE |
| RedisStack | UPDATE_COMPLETE |
| S3Stack | UPDATE_COMPLETE |
| SecGroupStack | UPDATE_COMPLETE |
| VPCStack | UPDATE_COMPLETE |

## Fix (IAM) — WDROŻONY (2026-04-21)

Minimalny wymagany fix:

```json
"mq:UpdateBroker"
```

Rekomendowany fix (pełny):

```json
[
  "mq:UpdateBroker",
  "cloudformation:ContinueUpdateRollback"
]
```

Policy do zaktualizowania:

```
arn:aws:iam::333320664022:policy/planodkupow-auto-CFN-Describe-Fix
```

## Wnioski architektoniczne

### 1. CloudFormation ≠ tylko ECS

Nawet jeśli deploy zmienia tylko obrazy Docker / ECS services, root stack może dotknąć RabbitMQ, ALB, DB, inne nested stacki.

### 2. Rollback wymaga tych samych uprawnień co update

Brak permission = podwójna awaria: FAIL update → FAIL rollback.

### 3. AmazonMQ to resource wysokiego ryzyka

* często wymaga replacement przy zmianie parametrów
* rollback może być niemożliwy bez pełnych uprawnień

### 4. UPDATE_* ≠ real change

W analizie: 9 nested stacków dotkniętych formalnie, tylko 1 (KlasterStack) miał realne zmiany zasobów.

## Safe Deployment Pattern (rekomendacja)

Dla aplikacyjnych deployów (obrazy ECS):

```bash
# OK — minimal blast radius
aws cloudformation create-change-set \
  --use-previous-template \
  --parameters ... ECS image params only
```

Wymaganie: IAM musi mieć pełne permissje dla **wszystkich** zasobów w template, nawet jeśli ich nie zmieniasz.

## Anti-pattern (który wystąpił)

- Root stack zawiera wszystko (RMQ + DB + ECS w jednym)
- Deploy identity ma tylko partial permissions
- Brak breakglass permissions (`cloudformation:ContinueUpdateRollback`)
- Brak testu rollback path

## Analogia z UAT (2026-04-20)

UAT miał ten sam symptom (`UPDATE_ROLLBACK_FAILED`, `BasicBroker`), ale inny root cause:
- UAT: rollback próbował przywrócić EngineVersion 3.8.6 (EOL) — AWS odrzucił jako invalid version
- QA: rollback zablokowany przez AccessDenied na `mq:UpdateBroker`

Ten sam fix operacyjny (`continue-update-rollback` z skip), różna przyczyna.

## Lessons Learned

* IAM dla CFN musi pokrywać **cały template**, nie tylko aktualny use-case
* RabbitMQ (AmazonMQ) = high-risk mutable resource — traktować jak DB
* Recovery path musi być zawsze dostępny (`cloudformation:ContinueUpdateRollback`)
* Root stack events są mylące → zawsze patrzeć na resource-level events w nested stacku
