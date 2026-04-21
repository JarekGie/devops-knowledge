# planodkupow — RabbitMQ: wyjście z root stack CFN

#aws #cloudformation #rabbitmq #planodkupow #architecture

**Data:** 2026-04-21
**Dotyczy:** planodkupow-qa (wzorzec do replikacji na UAT)
**Status:** PLAN GOTOWY — do wdrożenia

---

## 1. Decyzja architektoniczna

**Wybór: Opcja A — osobny stack CFN `planodkupow-qa-rabbitmq`**
z SSM Parameter Store jako kontraktem między brokerem a aplikacją.

### Opcja A: Dedykowany stack CFN (wybrana)

```
planodkupow-qa-rabbitmq
  └── AWS::AmazonMQ::Broker (BasicBroker)

planodkupow-qa (root)
  └── KlasterStack
        └── MQCS: {{resolve:ssm:/planodkupow/qa/rabbitmq/mqcs}}
```

**Za:**
- Broker nadal w IaC — historia zmian, change sety, audyt
- Lifecycle całkowicie oddzielony od deployów aplikacji
- Zmiana brokera nie wymaga dotykania root stacka
- SSM jako luźne sprzężenie — brak hard dependency przez `!GetAtt`

**Przeciw:**
- CFN nadal zarządza AmazonMQ (te same ograniczenia API)
- Wymaga dyscypliny: **nigdy nie updateować brokera przez CI/CD**

### Opcja B: Poza CFN (alternatywa)

Broker zarządzany manualnie lub skryptem. SSM jako jedyne źródło prawdy.

**Za:** Całkowite wyjście z problematycznej kombinacji CFN + AmazonMQ

**Przeciw:** Brak IaC dla brokera, trudniejszy audyt zmian

**Powód odrzucenia B:** Broker powinien być udokumentowany jako zasób IaC.
W praktyce — jeśli CFN ponownie sprawi problemy, fallback do opcji B jest łatwy
(broker zostaje, usuwamy tylko stack CFN, SSM pozostaje).

---

## 2. Kontrakt aplikacja ↔ broker

### Źródło MQCS

```
SSM Parameter Store:
  /planodkupow/qa/rabbitmq/mqcs
  Type: SecureString
  Value: amqps://<endpoint>:5671:admin:<password>
```

### Jak ECS konsumuje MQCS

W ROOT.yml, parametr KlasterStack:

```yaml
# PRZED (hard dependency na RabbitMQStack):
MQCS: !GetAtt [RabbitMQStack, Outputs.MQCS]

# PO (luźne sprzężenie przez SSM):
MQCS: '{{resolve:ssm:/planodkupow/qa/rabbitmq/mqcs}}'
```

**Zasada:** ECS NIGDY nie zależy od lifecycle brokera. Zmiana brokera = zmiana SSM parametru, nie zmiana CFN stacka aplikacji.

---

## 3. Plan migracji — krok po kroku

### Krok 0 — Stan wyjściowy (DONE)

```
✅ Nowy broker aktywny:  b-f231815d, mq.m7g.medium, RUNNING
✅ ECS używa nowego brokera: KlasterStack zaktualizowany bezpośrednio
✅ Stary broker:          b-5cb3fcb4, DELETION_IN_PROGRESS
```

### Krok 1 — Utwórz SSM parameter

```bash
aws ssm put-parameter \
  --name "/planodkupow/qa/rabbitmq/mqcs" \
  --value "amqps://b-f231815d-d0dd-42c5-aeb8-c2aeeaa3f803.mq.eu-central-1.on.aws:5671:admin:ZAQ!2wsxFREF3" \
  --type SecureString \
  --region eu-central-1 \
  --profile plan
```

### Krok 2 — Zmodyfikuj ROOT.yml

**Zmiana 1** — zastąp `!GetAtt RabbitMQStack` przez SSM resolve (linia 568):

```yaml
# USUŃ:
MQCS: !GetAtt [RabbitMQStack, Outputs.MQCS ]

# DODAJ:
MQCS: '{{resolve:ssm:/planodkupow/qa/rabbitmq/mqcs}}'
```

**Zmiana 2** — usuń cały blok `RabbitMQStack` (linie 581–601):

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

### Krok 3 — Upload ROOT.yml do S3

```bash
aws s3 cp cloudformation/ROOT.yml \
  s3://planodkupow-cf/ROOT.yml \
  --region eu-central-1 --profile plan
```

### Krok 4 — Utwórz i zweryfikuj change set

```bash
aws cloudformation create-change-set \
  --stack-name planodkupow-qa \
  --template-url https://planodkupow-cf.s3.eu-central-1.amazonaws.com/ROOT.yml \
  --use-previous-template false \
  --parameters [wszystkie inne parametry z UsePreviousValue=true] \
  --capabilities CAPABILITY_NAMED_IAM \
  --change-set-name remove-rabbitmq-nested-stack \
  --region eu-central-1 --profile plan
```

**Weryfikacja change setu — oczekiwane zmiany:**

| Zasób | Akcja | Oczekiwane |
|---|---|---|
| `RabbitMQStack` (nested stack) | DELETE | TAK — stary broker już usunięty |
| `KlasterStack` | MODIFY | TAK — zmiana parametru MQCS (SSM resolve) |
| Wszystkie inne | brak | Tak |

**STOP jeśli:**
- Jakikolwiek zasób poza RabbitMQStack + KlasterStack jest modyfikowany
- Replacement: True na KlasterStack
- DELETE na zasobach poza RabbitMQStack

### Krok 5 — Wykonaj change set

```bash
aws cloudformation execute-change-set \
  --stack-name planodkupow-qa \
  --change-set-name remove-rabbitmq-nested-stack \
  --region eu-central-1 --profile plan
```

### Krok 6 — (Opcjonalnie) Utwórz dedykowany stack brokera

```bash
aws cloudformation create-stack \
  --stack-name planodkupow-qa-rabbitmq \
  --template-url https://planodkupow-cf.s3.eu-central-1.amazonaws.com/RMQ.yml \
  --parameters [parametry środowiska] \
  --region eu-central-1 --profile plan
```

**Uwaga:** Nowy broker `b-f231815d` nie jest zarządzany przez żaden stack CFN (stworzony manualnie). Opcja:
- IMPORT `b-f231815d` do `planodkupow-qa-rabbitmq` (wymaga stabilnego stanu)
- Lub: stack CFN zarządza tylko dokumentacją/przyszłymi brokerami

### Krok 7 — Walidacja końcowa

```bash
# Stack root stabilny
aws cloudformation describe-stacks \
  --stack-name planodkupow-qa \
  --query 'Stacks[0].StackStatus'
# Oczekiwane: UPDATE_COMPLETE

# Brak nested stacka RabbitMQStack
aws cloudformation list-stack-resources \
  --stack-name planodkupow-qa \
  --query 'StackResourceSummaries[?ResourceType==`AWS::CloudFormation::Stack`].LogicalResourceId'
# RabbitMQStack NIE powinien być na liście

# ECS nadal działa
aws ecs describe-services --cluster planodkupow-qa-Klaster ...
# 14/14 desired==running

# SSM parameter dostępny
aws ssm get-parameter \
  --name /planodkupow/qa/rabbitmq/mqcs \
  --with-decryption \
  --region eu-central-1 --profile plan
```

---

## 4. Co usunąć z ROOT.yml

| Element | Lokalizacja w ROOT.yml | Akcja |
|---|---|---|
| `MQCS: !GetAtt [RabbitMQStack, Outputs.MQCS]` | KlasterStack parameters ~linia 568 | Zastąpić SSM resolve |
| `RabbitMQStack:` blok całkowity | ~linia 581–601 | Usunąć |

Nie ma innych referencji do RabbitMQStack w ROOT.yml.

---

## 5. Ryzyka i mitigacja

| Ryzyko | Prawdopodobieństwo | Mitigacja |
|---|---|---|
| CFN próbuje USUNĄĆ brokera przy DELETE RabbitMQStack | LOW | Stary broker jest już w DELETION_IN_PROGRESS; nowy broker nie jest w tym stacku |
| MQCS w SSM nie synchronizuje się z nowym endpointem przy przyszłej zmianie | MEDIUM | Procedura: zawsze najpierw update SSM, potem weryfikacja ECS |
| ECS nie może odczytać SSM w czasie deploy | LOW | Dodać `ssm:GetParameter` do roli ECS task execution jeśli nie ma |
| KlasterStack wymaga pełnego redeploy przy zmianie MQCS source | LOW | Zmiana SSM resolve nie wymaga replace'u zasobu ECS |

---

## 6. Model operacyjny po refaktorze

### Deploy aplikacji (Jenkins — BEZPIECZNY)

```
ROOT.yml (update-stack --use-previous-template)
  └── KlasterStack → ECS TaskDefinitions + Services
      └── MQCS z SSM (statyczne — nie zmienia się podczas deploy)

Nic nie dotyka brokera.
```

### Zmiana brokera (OPERATORSKA, manualna)

```
1. Utwórz nowy broker (AWS CLI lub planodkupow-qa-rabbitmq stack)
2. Poczekaj na RUNNING
3. Zaktualizuj SSM: /planodkupow/qa/rabbitmq/mqcs
4. Zaktualizuj KlasterStack (parametr MQCS) → ECS rollout
5. Weryfikuj metryki
6. Usuń stary broker
```

### Reguły bezpieczeństwa

```
❌ Nigdy nie modyfikuj brokera przez CI/CD
❌ Nigdy nie dodawaj RabbitMQ z powrotem do root stack
❌ Nigdy nie używaj !GetAtt do przekazywania MQCS między stackami
✅ SSM jest jedynym źródłem prawdy dla MQCS
✅ Każda zmiana brokera = jawna operatorska decyzja
✅ Broker lifecycle ≠ app deployment lifecycle
```

---

## 7. Wnioski (lessons learned)

### AmazonMQ + CloudFormation nie jest bezpiecznie idempotentny

- Każdy update brokera (nawet niezamierzony przez drift) wywołuje UpdateBroker → RebootBroker
- Rollback wymaga tych samych uprawnień co update → brak = double failure
- `continue-update-rollback --resources-to-skip` zamraża stan → trwały drift

### Root stack fan-out = fałszywe poczucie blast radius

Formalne `UPDATE_*` na 9 nested stackach nie oznacza zmiany zasobów. Sprawdzaj zawsze resource-level events w nested stacku.

### Messaging system nie należy do deployment pipeline

RabbitMQ to infrastruktura danych — zmiana brokera to operacja z własnym runbookiem, nie parametr CI/CD.

### SSM > CFN cross-stack outputs dla connection strings

`!GetAtt [Stack, Outputs.ConnectionString]` tworzy hard dependency lifecycle.
`{{resolve:ssm:/path}}` jest statycznym odczytem — brak zależności.

---

## Pliki do zmiany

```
Repo: ~/projekty/mako/aws-projects/infra-bbmt

cloudformation/ROOT.yml
  - linia 568: zastąpić !GetAtt SSM resolve
  - linia 581-601: usunąć blok RabbitMQStack
```

---

*Utworzono: 2026-04-21 | Status: PLAN — do wdrożenia*
