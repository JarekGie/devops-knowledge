# Runbook: planodkupow-qa CFN Rebuild po UPDATE_ROLLBACK_FAILED

#incident #aws #cloudformation #planodkupow

**Środowisko:** QA  
**Stack:** `planodkupow-qa`  
**Region:** `eu-central-1`  
**Profil AWS CLI:** `plan`  
**Konto:** `333320664022`  
**Data incydentu:** 2026-04-18  
**Strategia:** controlled rebuild (rollback recovery niewykonalny)

---

## Kontekst incydentu

| Problem | Szczegół |
|---|---|
| Root stack | `UPDATE_ROLLBACK_FAILED` — "Stack [RedisStack] does not exist" |
| RabbitMQStack | `UPDATE_ROLLBACK_FAILED` — Lambda custom resource 403 "account suspended" |
| DBStack | `UPDATE_ROLLBACK_FAILED` — SQLDatabase "Resource update cancelled" |
| RedisStack | Rollback zakończony sukcesem (`UPDATE_ROLLBACK_COMPLETE`), ale root stack nie może tego przetworzyć |
| Przyczyna pierwotna | Redis 5.0.0 EOL (AWS usunął wersję); LLZ tags deploy uruchomił Replace na wszystkich nested stackach |

**Nested stacks w root:**

| Logical ID | Physical Stack Name | Status |
|---|---|---|
| VPCStack | planodkupow-qa-VPCStack-1OHNJ84RQI8K2 | UPDATE_COMPLETE |
| SecGroupStack | planodkupow-qa-SecGroupStack-1DFRR36S6WWNM | UPDATE_COMPLETE |
| S3Stack | planodkupow-qa-S3Stack-Q99MN1145Z29 | UPDATE_COMPLETE |
| DBStack | planodkupow-qa-DBStack-ZWZM5XD8MGCI | UPDATE_ROLLBACK_FAILED |
| RedisStack | planodkupow-qa-RedisStack-1WIH38OPWPVY9 | UPDATE_ROLLBACK_COMPLETE |
| RabbitMQStack | planodkupow-qa-RabbitMQStack-14EK8W0EXEAKH | UPDATE_ROLLBACK_FAILED |
| KlasterStack | planodkupow-qa-KlasterStack-9FQ1X8MGER2U | UPDATE_COMPLETE |
| ALBStack | planodkupow-qa-ALBStack-RLEKD6CW0G5U | UPDATE_COMPLETE |
| CFStack | planodkupow-qa-CFStack-1EVT0HBINY46S | UPDATE_COMPLETE |

---

## BEZPIECZEŃSTWO — przeczytaj przed rozpoczęciem

### NIE rób:
- Nie usuwaj DBStack bez wcześniejszego snapshotu RDS
- Nie usuwaj VPCStack jeśli jakikolwiek zasób z innych stacków nadal istnieje w tej VPC
- Nie używaj `--retain-resources` bez weryfikacji co zostaje
- Nie deployuj na root stacku zanim wszystkie nested stacks nie zostaną usunięte
- Nie rób `continue-update-rollback` — strategia porzucona

### Pułapki CFN nested stacks:
- `delete-stack` na root stacku może wisieć jeśli nested stack ma zasoby z zewnętrznymi zależnościami (ENI, SG używane przez inne zasoby)
- Po delete root stacka nested stacks mogą zostać jako orphans — weryfikuj ręcznie
- RDS z `DeletionPolicy: Retain` lub protection zostanie, nawet gdy stack jest usunięty — to jest dobre, ale wymaga ręcznego re-importu przy redeploy

---

## FAZA 0: PRE-FLIGHT / FREEZE

**Cel:** Zatrzymać wszelkie automatyczne deploye, zweryfikować aktualny stan przed działaniem.

### 0.1 Zablokuj Jenkins/CI pipeline
Zatrzymaj wszystkie joby deployujące na `planodkupow-qa` zanim zaczniesz. Nie możesz mieć konkurującego deploy podczas ręcznego rebuild.

### 0.2 Zweryfikuj aktualny status stacka

```bash
aws cloudformation describe-stacks \
  --stack-name planodkupow-qa \
  --profile plan \
  --region eu-central-1 \
  --query 'Stacks[0].{Status:StackStatus,Reason:StackStatusReason}' \
  --output table
```

**Oczekiwany wynik:** `UPDATE_ROLLBACK_FAILED`

### 0.3 Zweryfikuj status nested stacków

```bash
aws cloudformation list-stack-resources \
  --stack-name planodkupow-qa \
  --profile plan \
  --region eu-central-1 \
  --query 'StackResourceSummaries[].{ID:LogicalResourceId,Status:ResourceStatus,Reason:ResourceStatusReason}' \
  --output table
```

### 0.4 Zrób snapshot stanu przed działaniem (opcjonalnie)

```bash
# Zapisz pełny stan stack events do pliku
aws cloudformation describe-stack-events \
  --stack-name planodkupow-qa \
  --profile plan \
  --region eu-central-1 \
  --output json > /tmp/planodkupow-qa-events-$(date +%Y%m%d-%H%M).json
```

---

## FAZA 1: BACKUP RDS (OBOWIĄZKOWY)

**Cel:** Zabezpieczyć dane RDS przed jakimkolwiek działaniem na stackach.

### 1.1 Znajdź identyfikator instancji RDS

```bash
aws rds describe-db-instances \
  --profile plan \
  --region eu-central-1 \
  --query 'DBInstances[?contains(DBInstanceIdentifier, `planodkupow`) || contains(DBInstanceIdentifier, `qa`)].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine,EngineVersion:EngineVersion}' \
  --output table
```

> Zapisz `DBInstanceIdentifier` — użyjesz go w kolejnych krokach.

### 1.2 Utwórz manualny snapshot

```bash
# Zastąp INSTANCE_ID wartością z kroku 1.1
INSTANCE_ID="<DBInstanceIdentifier>"
SNAPSHOT_ID="planodkupow-qa-pre-rebuild-$(date +%Y%m%d-%H%M)"

aws rds create-db-snapshot \
  --db-instance-identifier "$INSTANCE_ID" \
  --db-snapshot-identifier "$SNAPSHOT_ID" \
  --profile plan \
  --region eu-central-1

echo "Snapshot ID: $SNAPSHOT_ID"
```

### 1.3 Czekaj na zakończenie snapshotu

```bash
aws rds wait db-snapshot-completed \
  --db-snapshot-identifier "$SNAPSHOT_ID" \
  --profile plan \
  --region eu-central-1

echo "Snapshot gotowy."
```

**Timeout:** domyślnie ~15 min. Jeśli fail — sprawdź status:
```bash
aws rds describe-db-snapshots \
  --db-snapshot-identifier "$SNAPSHOT_ID" \
  --profile plan \
  --region eu-central-1 \
  --query 'DBSnapshots[0].{Status:Status,Progress:PercentProgress}' \
  --output table
```

### 1.4 Zweryfikuj snapshot

```bash
aws rds describe-db-snapshots \
  --db-snapshot-identifier "$SNAPSHOT_ID" \
  --profile plan \
  --region eu-central-1 \
  --query 'DBSnapshots[0].{ID:DBSnapshotIdentifier,Status:Status,Engine:Engine,AllocatedStorage:AllocatedStorage}' \
  --output table
```

**Oczekiwany status:** `available`

### 1.5 (Opcjonalnie) Backup Amazon MQ

```bash
# Sprawdź konfigurację brokera (eksport konfiguracji)
BROKER_ID=$(aws mq list-brokers \
  --profile plan \
  --region eu-central-1 \
  --query 'BrokerSummaries[?contains(BrokerName, `planodkupow`) || contains(BrokerName, `qa`)].BrokerId' \
  --output text)

echo "Broker ID: $BROKER_ID"

aws mq describe-broker \
  --broker-id "$BROKER_ID" \
  --profile plan \
  --region eu-central-1 \
  --output json > /tmp/rabbitmq-qa-broker-config-$(date +%Y%m%d-%H%M).json
```

> Amazon MQ nie wspiera snapshotów danych jak RDS. QA — utrata wiadomości w kolejkach akceptowalna.

---

## FAZA 2: NAPRAWY PRZED REDEPLOY (ROOT CAUSE FIX)

**Cel:** Wyeliminować przyczyny pierwotne, żeby redeploy zakończył się sukcesem.

### 2.1 Weryfikacja REDIS.yml — EngineVersion

```bash
grep -n "EngineVersion" ~/projekty/mako/aws-projects/infra-bbmt/cloudformation/REDIS.yml
```

**Oczekiwany wynik:** `EngineVersion: '5.0.6'`

Jeśli nadal `5.0.0`:
```bash
sed -i "s/EngineVersion: '5.0.0'/EngineVersion: '5.0.6'/" \
  ~/projekty/mako/aws-projects/infra-bbmt/cloudformation/REDIS.yml
```

### 2.2 Weryfikacja ROOT.yml — brak problematycznych zmian

```bash
# Sprawdź czy ROOT.yml nie zawiera zmian powodujących Replace na zasobach
grep -n "Tags" ~/projekty/mako/aws-projects/infra-bbmt/cloudformation/ROOT.yml | head -30
```

> Tags na nested stackach powinny być obecne (to cel wdrożenia). Weryfikuj że nie ma innych nieoczekiwanych zmian.

### 2.3 Wgraj poprawione szablony na S3

```bash
BUCKET="planodkupow-cf"
REGION="eu-central-1"

aws s3 cp ~/projekty/mako/aws-projects/infra-bbmt/cloudformation/ROOT.yml \
  "s3://$BUCKET/ROOT.yml" \
  --profile plan \
  --region "$REGION"

aws s3 cp ~/projekty/mako/aws-projects/infra-bbmt/cloudformation/REDIS.yml \
  "s3://$BUCKET/REDIS.yml" \
  --profile plan \
  --region "$REGION"

# Zweryfikuj wersje na S3
aws s3api list-object-versions \
  --bucket "$BUCKET" \
  --prefix "ROOT.yml" \
  --profile plan \
  --region "$REGION" \
  --query 'Versions[:3].{VersionId:VersionId,LastModified:LastModified,IsLatest:IsLatest}' \
  --output table
```

### 2.4 Diagnoza Lambda custom resource (RabbitMQ)

> Błąd "account suspended" przy BasicBroker Lambda sugeruje że Lambda wykonuje się w kontekście zawieszonego konta lub używa zewnętrznego API z nieprawidłowymi credentials.

```bash
# Znajdź Lambda odpowiedzialną za AmazonMQ custom resource
aws lambda list-functions \
  --profile plan \
  --region eu-central-1 \
  --query 'Functions[?contains(FunctionName, `amq`) || contains(FunctionName, `mq`) || contains(FunctionName, `broker`)].{Name:FunctionName,Runtime:Runtime,LastModified:LastModified}' \
  --output table
```

```bash
# Sprawdź logi Lambda z ostatniej próby rollbacku
LOG_GROUP="/aws/lambda/<nazwa-lambdy>"  # z kroku powyżej

aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --start-time $(date -d '24 hours ago' +%s000) \
  --profile plan \
  --region eu-central-1 \
  --query 'events[].message' \
  --output text 2>/dev/null | head -50
```

> Jeśli Lambda failuje z 403 przy każdym wywołaniu — redeploy RabbitMQStack może się nie udać. Rozważ:
> - Ręczne stworzenie brokera poza CFN (import do state)  
> - AWS Support ticket na Lambda execution issue

---

## FAZA 3: USUNIĘCIE STACKÓW

**Cel:** Usunąć root stack i nested stacks w kontrolowanej kolejności.

### 3.1 Sprawdź RDS DeletionPolicy

```bash
# Weryfikuj czy RDS ma protection przed usunięciem
aws rds describe-db-instances \
  --db-instance-identifier "$INSTANCE_ID" \
  --profile plan \
  --region eu-central-1 \
  --query 'DBInstances[0].DeletionProtection' \
  --output text
```

Jeśli `False` — PRZED usunięciem stacka włącz ochronę:
```bash
aws rds modify-db-instance \
  --db-instance-identifier "$INSTANCE_ID" \
  --deletion-protection \
  --profile plan \
  --region eu-central-1
```

> Dzięki temu nawet jeśli CFN spróbuje usunąć RDS, operacja się nie powiedzie i będziesz musiał ją jawnie odblokować.

### 3.2 Usuń root stack z retain na RDS

```bash
# Usuń root stack — CFN usunie nested stacks po kolei
# Jeśli DBStack/REDIS/RMQ mają DeletionPolicy: Retain — zasoby zostaną
aws cloudformation delete-stack \
  --stack-name planodkupow-qa \
  --profile plan \
  --region eu-central-1

echo "Delete zainicjowany. Czekam..."
```

### 3.3 Monitoruj postęp usuwania

```bash
# Otwórz w osobnym terminalu — odświeżaj co 30s
watch -n 30 'aws cloudformation describe-stacks \
  --stack-name planodkupow-qa \
  --profile plan \
  --region eu-central-1 \
  --query "Stacks[0].StackStatus" \
  --output text 2>/dev/null || echo "STACK DELETED"'
```

**Alternatywnie — jednorazowe sprawdzenie:**
```bash
aws cloudformation describe-stack-events \
  --stack-name planodkupow-qa \
  --profile plan \
  --region eu-central-1 \
  --query 'StackEvents[:10].{Time:Timestamp,Resource:LogicalResourceId,Status:ResourceStatus,Reason:ResourceStatusReason}' \
  --output table
```

### 3.4 Jeśli delete-stack wisi lub failuje

**Scenariusz A: ENI nie może być usunięty (SG w użyciu)**
```bash
# Znajdź ENI powiązane z VPC
VPC_ID=$(aws cloudformation describe-stack-resource \
  --stack-name planodkupow-qa-VPCStack-1OHNJ84RQI8K2 \
  --logical-resource-id VPC \
  --profile plan \
  --region eu-central-1 \
  --query 'StackResourceDetail.PhysicalResourceId' \
  --output text 2>/dev/null)

aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --profile plan \
  --region eu-central-1 \
  --query 'NetworkInterfaces[].{ID:NetworkInterfaceId,Status:Status,Desc:Description,Type:InterfaceType}' \
  --output table
```

**Scenariusz B: Nested stack zablokowany — usuń ręcznie**
```bash
# Jeśli np. RabbitMQStack blokuje delete root stacka, usuń go bezpośrednio
aws cloudformation delete-stack \
  --stack-name planodkupow-qa-RabbitMQStack-14EK8W0EXEAKH \
  --profile plan \
  --region eu-central-1

aws cloudformation wait stack-delete-complete \
  --stack-name planodkupow-qa-RabbitMQStack-14EK8W0EXEAKH \
  --profile plan \
  --region eu-central-1
```

**Scenariusz C: DBStack blokuje delete — usuń z retain RDS**
```bash
aws cloudformation delete-stack \
  --stack-name planodkupow-qa-DBStack-ZWZM5XD8MGCI \
  --retain-resources SQLDatabase SiecDB \
  --profile plan \
  --region eu-central-1
```

### 3.5 Czekaj na pełne usunięcie root stacka

```bash
aws cloudformation wait stack-delete-complete \
  --stack-name planodkupow-qa \
  --profile plan \
  --region eu-central-1

echo "Root stack usunięty."
```

**Timeout waiter:** ~2 godziny. Jeśli po timeout stack nadal istnieje:
```bash
aws cloudformation describe-stacks \
  --stack-name planodkupow-qa \
  --profile plan \
  --region eu-central-1 \
  --query 'Stacks[0].{Status:StackStatus,Reason:StackStatusReason}' \
  --output table
```

---

## FAZA 4: CLEANUP — ORPHAN RESOURCES

**Cel:** Wykryć zasoby, które przeżyły usunięcie stacka i mogą blokować redeploy.

### 4.1 Sprawdź czy nested stacks zostały usunięte

```bash
for STACK in \
  planodkupow-qa-VPCStack-1OHNJ84RQI8K2 \
  planodkupow-qa-SecGroupStack-1DFRR36S6WWNM \
  planodkupow-qa-S3Stack-Q99MN1145Z29 \
  planodkupow-qa-DBStack-ZWZM5XD8MGCI \
  planodkupow-qa-RedisStack-1WIH38OPWPVY9 \
  planodkupow-qa-RabbitMQStack-14EK8W0EXEAKH \
  planodkupow-qa-KlasterStack-9FQ1X8MGER2U \
  planodkupow-qa-ALBStack-RLEKD6CW0G5U \
  planodkupow-qa-CFStack-1EVT0HBINY46S; do
  STATUS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK" \
    --profile plan \
    --region eu-central-1 \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null || echo "DELETED")
  echo "$STACK: $STATUS"
done
```

**Oczekiwany wynik:** wszystkie `DELETED`

### 4.2 Sprawdź orphan zasoby

```bash
# ElastiCache cluster
aws elasticache describe-cache-clusters \
  --profile plan \
  --region eu-central-1 \
  --query 'CacheClusters[?contains(CacheClusterId, `planodkupow`) || contains(CacheClusterId, `qa`)].{ID:CacheClusterId,Status:CacheClusterStatus}' \
  --output table

# Amazon MQ brokers
aws mq list-brokers \
  --profile plan \
  --region eu-central-1 \
  --query 'BrokerSummaries[?contains(BrokerName, `planodkupow`) || contains(BrokerName, `qa`)].{ID:BrokerId,Name:BrokerName,Status:BrokerState}' \
  --output table

# RDS instances (oczekujemy że ZOSTANIE — DeletionPolicy: Retain)
aws rds describe-db-instances \
  --profile plan \
  --region eu-central-1 \
  --query 'DBInstances[?contains(DBInstanceIdentifier, `planodkupow`) || contains(DBInstanceIdentifier, `qa`)].{ID:DBInstanceIdentifier,Status:DBInstanceStatus}' \
  --output table

# ALB
aws elbv2 describe-load-balancers \
  --profile plan \
  --region eu-central-1 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `planodkupow`) || contains(LoadBalancerName, `qa`)].{Name:LoadBalancerName,State:State.Code}' \
  --output table

# ECS clusters
aws ecs list-clusters \
  --profile plan \
  --region eu-central-1 \
  --query 'clusterArns[?contains(@, `planodkupow`) || contains(@, `qa`)]' \
  --output table

# Security Groups (orphans)
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=*planodkupow*,*qa*" \
  --profile plan \
  --region eu-central-1 \
  --query 'SecurityGroups[].{ID:GroupId,Name:GroupName}' \
  --output table
```

### 4.3 Usuń orphan zasoby (jeśli istnieją i nie są potrzebne)

```bash
# Przykład: orphan ElastiCache cluster
# aws elasticache delete-cache-cluster \
#   --cache-cluster-id <ID> \
#   --profile plan \
#   --region eu-central-1

# Przykład: orphan Amazon MQ broker
# aws mq delete-broker \
#   --broker-id <BROKER_ID> \
#   --profile plan \
#   --region eu-central-1
```

> Przed usunięciem każdego orphan zasobu potwierdź że nie jest używany przez inny stack lub serwis.

---

## FAZA 5: REDEPLOY

**Cel:** Odtworzyć środowisko QA z poprawionymi szablonami.

### 5.1 Weryfikacja szablonów przed deployem

```bash
# Walidacja ROOT.yml
aws cloudformation validate-template \
  --template-url "https://planodkupow-cf.s3.eu-central-1.amazonaws.com/ROOT.yml" \
  --profile plan \
  --region eu-central-1

# Walidacja REDIS.yml
aws cloudformation validate-template \
  --template-url "https://planodkupow-cf.s3.eu-central-1.amazonaws.com/REDIS.yml" \
  --profile plan \
  --region eu-central-1
```

### 5.2 Deploy przez Jenkins (rekomendowane)

Uruchom standardowy Jenkins job dla QA z parametrami:
- Template URL: `https://planodkupow-cf.s3.eu-central-1.amazonaws.com/ROOT.yml`
- Environment: `qa`

### 5.3 Alternatywnie: deploy ręczny przez CLI

```bash
# Pobierz aktualne parametry (z poprzedniego deploy lub z project.yaml)
# Następnie:
aws cloudformation create-stack \
  --stack-name planodkupow-qa \
  --template-url "https://planodkupow-cf.s3.eu-central-1.amazonaws.com/ROOT.yml" \
  --parameters file:///tmp/planodkupow-qa-params.json \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --tags Key=Environment,Value=qa Key=Project,Value=planodkupow \
  --profile plan \
  --region eu-central-1
```

### 5.4 Monitoruj deploy

```bash
aws cloudformation wait stack-create-complete \
  --stack-name planodkupow-qa \
  --profile plan \
  --region eu-central-1

echo "Deploy zakończony."
```

### 5.5 Jeśli deploy failuje przy RabbitMQStack (Lambda 403)

Opcja A — deploy bez RabbitMQStack (tymczasowo):
> Wymaga modyfikacji ROOT.yml — usunięcia lub zakomentowania RabbitMQStack + wszystkich zależności.

Opcja B — ręczne stworzenie brokera i import do CFN:
```bash
# 1. Stwórz brokera ręcznie
aws mq create-broker \
  --broker-name planodkupow-qa \
  --broker-type SINGLE_INSTANCE \
  --engine-type RABBITMQ \
  --engine-version "3.13" \
  --host-instance-type mq.m5.large \
  --auto-minor-version-upgrade \
  --publicly-accessible false \
  --profile plan \
  --region eu-central-1

# 2. Dodaj import blok do template i użyj --create-stack z importem
# Szczegóły zależą od struktury RabbitMQStack
```

---

## FAZA 6: RESTORE / WALIDACJA

**Cel:** Zweryfikować że środowisko działa poprawnie po redeploy.

### 6.1 Weryfikacja RDS

```bash
# Status instancji
aws rds describe-db-instances \
  --db-instance-identifier "$INSTANCE_ID" \
  --profile plan \
  --region eu-central-1 \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address,Port:Endpoint.Port}' \
  --output table
```

> Jeśli RDS zostało zachowane przez DeletionPolicy: Retain — sprawdź czy nowy stack wskazuje na tę samą instancję (przez parametr lub import).

### 6.2 Weryfikacja ElastiCache Redis

```bash
aws elasticache describe-cache-clusters \
  --profile plan \
  --region eu-central-1 \
  --query 'CacheClusters[?contains(CacheClusterId, `planodkupow`)].{ID:CacheClusterId,Status:CacheClusterStatus,Engine:EngineVersion}' \
  --output table
```

**Oczekiwany EngineVersion:** `5.0.6`

### 6.3 Weryfikacja Amazon MQ

```bash
aws mq describe-broker \
  --broker-id "$BROKER_ID" \
  --profile plan \
  --region eu-central-1 \
  --query '{Name:BrokerName,State:BrokerState,Version:EngineVersion}' \
  --output table
```

**Oczekiwany stan:** `RUNNING`

### 6.4 Weryfikacja ECS

```bash
CLUSTER=$(aws ecs list-clusters \
  --profile plan \
  --region eu-central-1 \
  --query 'clusterArns[?contains(@, `planodkupow`)]' \
  --output text)

aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services $(aws ecs list-services --cluster "$CLUSTER" --profile plan --region eu-central-1 --query 'serviceArns[]' --output text) \
  --profile plan \
  --region eu-central-1 \
  --query 'services[].{Name:serviceName,Running:runningCount,Desired:desiredCount,Status:status}' \
  --output table
```

**Oczekiwany wynik:** `Running == Desired` dla każdego serwisu.

### 6.5 Weryfikacja ALB target health

```bash
# Znajdź Target Groups
TG_ARNS=$(aws elbv2 describe-target-groups \
  --profile plan \
  --region eu-central-1 \
  --query 'TargetGroups[?contains(TargetGroupName, `planodkupow`) || contains(TargetGroupName, `qa`)].TargetGroupArn' \
  --output text)

for TG in $TG_ARNS; do
  echo "=== $TG ==="
  aws elbv2 describe-target-health \
    --target-group-arn "$TG" \
    --profile plan \
    --region eu-central-1 \
    --query 'TargetHealthDescriptions[].{Target:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason}' \
    --output table
done
```

**Oczekiwany stan:** `healthy` dla wszystkich targetów.

### 6.6 Weryfikacja logów (CloudWatch)

```bash
# Sprawdź czy logi aplikacji płyną (dostosuj log group)
aws logs describe-log-groups \
  --log-group-name-prefix "/ecs/planodkupow-qa" \
  --profile plan \
  --region eu-central-1 \
  --query 'logGroups[].{Name:logGroupName,StoredBytes:storedBytes}' \
  --output table

# Ostatnie logi
aws logs tail "/ecs/planodkupow-qa" \
  --since 10m \
  --profile plan \
  --region eu-central-1 2>/dev/null | head -30
```

---

## FINALNA CHECKLISTA WALIDACJI

```
[ ] Stack planodkupow-qa w statusie CREATE_COMPLETE lub UPDATE_COMPLETE
[ ] Wszystkie nested stacks w statusie CREATE_COMPLETE lub UPDATE_COMPLETE
[ ] RDS dostępny, status: available
[ ] RDS endpoint bez zmiany (lub aplikacja zaktualizowana o nowy endpoint)
[ ] ElastiCache Redis 5.0.6: status available
[ ] Amazon MQ BasicBroker: status RUNNING
[ ] ECS: wszystkie serwisy Running == Desired
[ ] ALB: wszystkie targety healthy
[ ] CloudFront: distribution deployed
[ ] Logi ECS płyną w CloudWatch
[ ] Snapshot RDS pre-rebuild istnieje i jest available
[ ] Jenkins pipeline odblokowany po zakończeniu
```

---

## S3 ROLLBACK (jeśli potrzebny)

Poprzednia wersja ROOT.yml (przed incydentem) jest dostępna w wersjonowanym buckecie S3:

```bash
# Przywróć poprzednią wersję ROOT.yml z S3
aws s3api copy-object \
  --bucket planodkupow-cf \
  --copy-source "planodkupow-cf/ROOT.yml?versionId=Qn8EJ.mwtuYz43GF1JEl.JeV6t2OOsEQ" \
  --key ROOT.yml \
  --profile plan \
  --region eu-central-1
```

> VersionId `Qn8EJ.mwtuYz43GF1JEl.JeV6t2OOsEQ` = ROOT.yml pre-incydent (2023-06-15). Użyj tylko jeśli chcesz wrócić do stanu bez LLZ Tags — oznacza rezygnację z wdrożenia tagowania.

---

*Runbook wygenerowany: 2026-04-19 | Incydent: CFN UPDATE_ROLLBACK_FAILED planodkupow-qa*
