# PBMS — Runbook diagnostyczny

#pbms #ecs #fargate #documentdb #aws #troubleshoot

**Projekt:** Puzzler B2B (infra-puzzler-b2b-final)  
**Środowisko dev:** eu-west-2, account `698220459519`  
**Klaster ECS:** `infra-puzzler-b2b-dev-puzzler`  
**ALB:** `pbms-api-dev.makotest.pl`

---

## Symptom: Swagger Core zwraca HTTP 500 na `/swagger/docs/v1/Core`

### Architektura requestu

- Gateway używa `SwaggerForOcelot`, nie generuje dokumentu Core lokalnie.
- `/swagger/docs/v1/Core` jest składane przez gateway z downstream:
  `http://pbms-core-qa:8080/swagger/v1/swagger.json`
- Źródła kodowe:
  - `~/projekty/mako/pbms-backend/Connector/PBMS.Gateway/Extensions/SwaggerExtensions.cs`
  - `~/projekty/mako/pbms-backend/Connector/PBMS.Gateway/swaggerEndpoints.QA.json`
  - `~/projekty/mako/pbms-backend/Core/PBMS.Core.API/Program.cs`
  - `~/projekty/mako/pbms-backend/PBMS.Common/Extensions/SwaggerExtensions.cs`

### Najbardziej prawdopodobna przyczyna

Swagger wywala się w **Core API**, nie w gatewayu.

Najmocniejszy trop z kodu:
- `MediaModel` i `SupplyResponse` wystawiają `IMediaDeliveryModel DeliveryDefinition`
- `IMediaDeliveryModel` jest interfejsem z `SwaggerSubType(typeof(MediaSftpDeliveryModel))`
- w `ConfigureSwaggerOptions.cs` konfiguracja polimorfizmu Swaggera jest zakomentowana

To daje ścieżkę:

```text
gateway /swagger/docs/v1/Core
  -> fetch downstream /swagger/v1/swagger.json
  -> Core Swagger generation traverses MediaModel / SupplyResponse
  -> interface schema IMediaDeliveryModel causes runtime failure
  -> gateway pokazuje 500
```

### Minimalny fix

Najmniejsza bezpieczna zmiana po stronie aplikacji:

- zmienić tylko typ `DeliveryDefinition` w response DTO:
  - `PBMS.Core/Models/Media/MediaModel.cs`
  - `PBMS.Core/Models/Supply/SupplyResponse.cs`
- z:
  - `IMediaDeliveryModel`
- na:
  - `object`

To jest najmniejszy patch, bo:
- request DTO już używają `object DeliveryDefinition`
- nie wymaga przebudowy Swagger/Ocelot
- nie wymaga zmian infra

### Walidacja po fixie

```bash
rg -n "IMediaDeliveryModel DeliveryDefinition|object DeliveryDefinition" ~/projekty/mako/pbms-backend/Core/PBMS.Core
```

```text
http://pbms-core-qa:8080/swagger/v1/swagger.json
/swagger/docs/v1/Core
/
```

Jeśli pierwszy endpoint dalej zwraca 500, problem nadal jest w Core Swagger generation.

---

## Symptom: serwis nie odpowiada

### 1. Czy to scheduler?

Serwisy zatrzymują się automatycznie poza godzinami pracy (07:00–19:00 Europe/Warsaw, pon–pt).

```bash
# Sprawdź desired_count
aws ecs describe-services \
  --cluster infra-puzzler-b2b-dev-puzzler \
  --services pbms-gateway-dev pbms-core-dev pbms-delivery-dev pbms-notifier-dev \
  --region eu-west-2 \
  --query 'services[*].{name:serviceName,desired:desiredCount,running:runningCount}'
```

Jeśli `desiredCount = 0` → scheduler zadziałał, nie ma problemu.

### 2. Sprawdź stan tasków

```bash
aws ecs list-tasks \
  --cluster infra-puzzler-b2b-dev-puzzler \
  --service-name pbms-gateway-dev \
  --region eu-west-2

# Szczegóły tasku (health, stopped reason)
aws ecs describe-tasks \
  --cluster infra-puzzler-b2b-dev-puzzler \
  --tasks <task-arn> \
  --region eu-west-2 \
  --query 'tasks[0].{status:lastStatus,health:healthStatus,stopped:stoppedReason,containers:containers[*].{name:name,status:lastStatus,reason:reason}}'
```

### 3. Logi CloudWatch

```bash
# Gateway logi (ostatnie 30 min)
aws logs filter-log-events \
  --log-group-name /ecs/infra-puzzler-b2b-dev/gateway \
  --start-time $(date -d '30 minutes ago' +%s000) \
  --filter-pattern "ERROR" \
  --region eu-west-2

# Skróty serwisów: gateway, core, delivery, notifier, worker, jumphost
```

---

## Symptom: serwis crashuje / restart loop

### Przyczyny w kolejności prawdopodobieństwa

1. **Secrets Manager** — kontener nie może pobrać secretu przy starcie
2. **DocumentDB TLS** — brak CA bundle w obrazie (ścieżka: `/etc/ssl/certs/rds-ca-bundle.pem`)
3. **Cloud Map** — task nie rejestruje się, inny serwis nie może go znaleźć
4. **Zły obraz** — worker używa `nginx:latest` (placeholder), powinien używać ECR

```bash
# Stopped reason z ostatniego tasku
aws ecs describe-tasks \
  --cluster infra-puzzler-b2b-dev-puzzler \
  --tasks $(aws ecs list-tasks --cluster infra-puzzler-b2b-dev-puzzler \
    --service-name pbms-gateway-dev --region eu-west-2 \
    --query 'taskArns[0]' --output text) \
  --region eu-west-2 \
  --query 'tasks[0].stoppedReason'
```

---

## ECS Exec — dostęp interaktywny (tylko gateway)

Gateway ma `enable_execute_command = true`.

```bash
# Pobierz aktywne taski
TASK_ID=$(aws ecs list-tasks \
  --cluster infra-puzzler-b2b-dev-puzzler \
  --service-name pbms-gateway-dev \
  --region eu-west-2 \
  --query 'taskArns[0]' --output text | cut -d'/' -f3)

# Wejdź do kontenera
aws ecs execute-command \
  --cluster infra-puzzler-b2b-dev-puzzler \
  --task $TASK_ID \
  --container gateway \
  --interactive \
  --command "/bin/bash" \
  --region eu-west-2
```

**Wymagania:** SSM Plugin zainstalowany lokalnie, VPN aktywny.  
`core`, `delivery`, `notifier` — ECS Exec wyłączony. Dostęp tylko przez gateway → Cloud Map DNS.

---

## DocumentDB — dostęp diagnostyczny przez jumphost

**Wymaganie:** VPN `195.117.107.110/32` aktywny.

```bash
# 1. ECS Exec do jumphost
JUMPHOST_TASK=$(aws ecs list-tasks \
  --cluster infra-puzzler-b2b-dev-puzzler \
  --service-name pbms-db-jumphost-dev \
  --region eu-west-2 \
  --query 'taskArns[0]' --output text | cut -d'/' -f3)

aws ecs execute-command \
  --cluster infra-puzzler-b2b-dev-puzzler \
  --task $JUMPHOST_TASK \
  --container jumphost \
  --interactive \
  --command "/bin/bash" \
  --region eu-west-2

# 2. Wewnątrz jumphost — pobierz endpoint i połącz
DOCDB_HOST=$(aws secretsmanager get-secret-value \
  --secret-id infra-puzzler-b2b/dev/docdb \
  --region eu-west-2 \
  --query SecretString --output text | jq -r .host)

mongosh "mongodb://$DOCDB_HOST:27017/?tls=true&tlsCAFile=/etc/ssl/certs/rds-ca-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
```

---

## Symptom: Cloud Map — serwis wewnętrzny nieosiągalny

DNS pattern: `pbms-{service}-dev.pbms.local:8080`

```bash
# Sprawdź rejestracje w Cloud Map
aws servicediscovery list-instances \
  --service-id $(aws servicediscovery list-services \
    --filters Name=NAMESPACE_ID,Values=<namespace-id> \
    --region eu-west-2 \
    --query 'Services[?Name==`pbms-core-dev`].Id' --output text) \
  --region eu-west-2

# Namespace ID (znajdź raz):
aws servicediscovery list-namespaces \
  --region eu-west-2 \
  --query 'Namespaces[?Name==`pbms.local`].Id' --output text
```

Jeśli instancje nie są zarejestrowane — task jest unhealthy lub moduł ecs-microservice ma buga w Cloud Map registration (znany problem, patch wymagany).

Weryfikacja DNS z wnętrza kontenera gateway:
```bash
nslookup pbms-core-dev.pbms.local
curl -v http://pbms-core-dev.pbms.local:8080/health
```

---

## Symptom: worker nie przetwarza wiadomości

```bash
# Sprawdź głębokość kolejki SQS
aws sqs get-queue-attributes \
  --queue-url $(aws sqs get-queue-url \
    --queue-name infra-puzzler-b2b-dev-jobs \
    --region eu-west-2 --query QueueUrl --output text) \
  --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
  --region eu-west-2

# Sprawdź skalowanie workera (SQS-based, threshold=1, max=2)
aws ecs describe-services \
  --cluster infra-puzzler-b2b-dev-puzzler \
  --services pbms-worker-dev \
  --region eu-west-2 \
  --query 'services[0].{desired:desiredCount,running:runningCount,pending:pendingCount}'
```

**Uwaga:** `worker_image = "nginx:latest"` — jeśli worker jest na nginx, żadne wiadomości nie będą przetwarzane. ECR repo `infra-puzzler-b2b-worker-dev` jest puste — obraz musi zostać zbudowany i pushowany przez CI/CD.

---

## Symptom: ALB 502/503

```bash
# Target group health
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names infra-puzzler-b2b-dev-gateway \
    --region eu-west-2 \
    --query 'TargetGroups[0].TargetGroupArn' --output text) \
  --region eu-west-2
```

502 najczęściej: task jest healthy w ECS ale `/health` zwraca 5xx.  
503: brak zdrowych targetów — sprawdź czy serwis jest uruchomiony.

---

## CloudWatch Dashboard

```
https://eu-west-2.console.aws.amazon.com/cloudwatch/home?region=eu-west-2#dashboards:name=infra-puzzler-b2b-dev-operations
```

Zawiera: ECS Running/Desired Tasks, CPU/Memory, ALB 5xx, DocumentDB connections, SQS queue depth.

---

## Secrets Manager — skróty

```bash
# DocumentDB endpoint/credentials
aws secretsmanager get-secret-value \
  --secret-id infra-puzzler-b2b/dev/docdb \
  --region eu-west-2 \
  --query SecretString --output text | jq .

# Azure AD (TenantId, ClientId, ClientSecret)
aws secretsmanager get-secret-value \
  --secret-id infra-puzzler-b2b/dev/azuread \
  --region eu-west-2 \
  --query SecretString --output text | jq .

# Jumphost SSH authorized_keys
aws secretsmanager get-secret-value \
  --secret-id infra-puzzler-b2b/dev/jumphost-ssh \
  --region eu-west-2 \
  --query SecretString --output text
```

---

## Powiązane

- [[pbms-context]] — projekt, architektura, zasoby kluczowe
- repo lokalne: `~/projekty/mako/aws-projects/infra-puzzler-b2b-final`
- branch aktywny: `feat/dev-jumphost-runtime-secret`
