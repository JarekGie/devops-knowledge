# AmazonMQ — RabbitMQ operacyjne

#aws #amazonmq #rabbitmq

---

## Typy instancji

| Typ | ActiveMQ | RabbitMQ |
|---|---|---|
| mq.t3.micro | TAK | NIE (nowe, od ~2023) |
| mq.m5.large | TAK | TAK |
| mq.m5.xlarge | TAK | TAK |
| mq.m7g.medium | TAK | TAK |
| mq.m7g.large | TAK | TAK |

**Wyjątek legacy:** Istniejące brokerzy RabbitMQ na `mq.t3.micro` działają — nie można jednak tworzyć nowych ani zmieniać typu na t3.micro. AWS odrzuca z:

```
BadRequestException: Broker engine type [RabbitMQ] does not support host instance type [mq.t3.micro]
```

**Najtańszy obsługiwany RabbitMQ:** `mq.m7g.medium` (~$66/mies. eu-central-1)

---

## Zmiana typu instancji

In-place zmiana `HostInstanceType` — **nie jest możliwa**.

Wymagany wzorzec:

```
CREATE nowy broker → WAIT RUNNING → SWITCH MQCS → VERIFY ruch → DELETE stary
```

Patrz: [[planodkupow-qa-rabbitmq-rollback-failed]] sekcja 9 (wzorzec cutover).

---

## IAM — minimalne uprawnienia dla CFN automation

Brak któregokolwiek może zablokować rollback:

```json
[
  "mq:DescribeBroker",
  "mq:UpdateBroker",
  "mq:RebootBroker",
  "mq:CreateBroker",
  "mq:DeleteBroker",
  "ec2:DetachNetworkInterface"
]
```

`ec2:DetachNetworkInterface` jest wymagane przez AWS przy usuwaniu brokera (AWS odpina ENI z VPC).

---

## CloudWatch metryki (weryfikacja ruchu)

Namespace: `AWS/AmazonMQ`
Dimension: `Name=Broker,Value=<BrokerName>`

Kluczowe metryki:

| Metryka | Znaczenie |
|---|---|
| `ConnectionCount` | Aktywne połączenia AMQP |
| `ChannelCount` | Otwarte kanały |
| `ConsumerCount` | Aktywni konsumenci |
| `PublishRate` | Wiadomości/s publikowane |

Przy cutoverze: stary broker powinien pokazywać 0 we wszystkich przed usunięciem.

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/AmazonMQ \
  --metric-name ConnectionCount \
  --dimensions Name=Broker,Value=<BROKER_NAME> \
  --start-time $(date -u -v-15M +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 --statistics Average Maximum \
  --region eu-central-1 --profile <PROFILE>
```

---

## Weryfikacja stanu brokera

```bash
aws mq describe-broker \
  --broker-id <BROKER_ID> \
  --region eu-central-1 --profile <PROFILE> \
  --query '{State:BrokerState,Type:HostInstanceType,Name:BrokerName,Endpoints:BrokerInstances[0].Endpoints}'
```

Stany:
- `RUNNING` — normalny
- `REBOOT_IN_PROGRESS` — restart po zmianie
- `DELETION_IN_PROGRESS` — usuwanie
- `CREATION_IN_PROGRESS` — tworzenie (może trwać ~10-15 min)

---

## CFN + AmazonMQ — pułapki

### Rollback wymaga tych samych uprawnień co update

Brak `mq:UpdateBroker` = podwójna awaria: FAIL update → FAIL rollback.

### continue-update-rollback z skip zamraża stan

Po pominięciu `BasicBroker` w rollbacku, CFN zapisuje stan zasobu jako wartość **przed** updatem. Jeśli template ma inną wartość → drift → każdy deploy próbuje UpdateBroker.

### Root stack UPDATE != zmiana zasobu

Root stack formalnie przepuszcza `UPDATE_*` przez wszystkie nested stacki. Rzeczywiste zmiany zasobów widać dopiero w resource-level events nested stacka.

---

## Tworzenie brokera (minimal)

```bash
aws mq create-broker \
  --broker-name <NAME> \
  --engine-type RabbitMQ \
  --engine-version 3.13 \
  --host-instance-type mq.m7g.medium \
  --deployment-mode SINGLE_INSTANCE \
  --publicly-accessible false \
  --subnet-ids <SUBNET_ID> \
  --security-groups <SG_ID> \
  --user Username=admin,Password=<PASSWORD> \
  --region eu-central-1 --profile <PROFILE>
```

Broker ID zwracany w odpowiedzi. Czas tworzenia: ~10-15 minut.

---

## Usuwanie brokera

```bash
aws mq delete-broker \
  --broker-id <BROKER_ID> \
  --region eu-central-1 --profile <PROFILE>
```

Wymaga `ec2:DetachNetworkInterface` — planodkupow-auto nie ma tej akcji, wymaga profilu `plan`.

---

*Ostatnia aktualizacja: 2026-04-21*
