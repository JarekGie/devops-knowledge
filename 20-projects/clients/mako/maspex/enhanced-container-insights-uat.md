---
title: "Enhanced Container Insights — Maspex UAT — analiza i plan wdrożenia"
date: 2026-05-14
type: decision-record
environment: uat
tags: [ecs, observability, container-insights, load-test, aws]
---

## A. Executive Summary

| Pytanie | Odpowiedź |
|---------|-----------|
| Czy Container Insights są dziś włączone? | **TAK** — standard (`enabled`), nie enhanced |
| Czy warto włączyć Enhanced? | **TAK** — bezpośrednio odpowiada na pytanie "który task był hotspotem" |
| Czy zostały włączone? | Nie jeszcze live — **IaC zmienione**, wymaga `terraform apply` w UAT |
| Realny zysk diagnostyczny | Per-task CPU + memory z `TaskId` dimension → widać który konkretny task przekroczył granicę |

---

## B. Discovery result

### Aktualny stan

```
Cluster:     maspex-uat
Setting:     containerInsights = enabled (standard)
Namespace:   ECS/ContainerInsights
Dimensions:  ClusterName + ServiceName | ClusterName + TaskDefinitionFamily
Brak:        TaskId dimension (brak per-task granularity)
```

Metryki, które JUŻ działają (potwierdzono `list-metrics`):
- `CpuUtilized`, `CpuReserved`, `MemoryUtilized`, `MemoryReserved`
- `NetworkRxBytes`, `NetworkTxBytes`, `StorageReadBytes`, `StorageWriteBytes`
- `RunningTaskCount`, `PendingTaskCount`, `DesiredTaskCount`
- Wszystkie wyłącznie na poziomie serwisu/task-def-family — **agregat** 12 tasków

Brak w obecnym stanie: `TaskId` dimension → nie wiemy który task był hotspotem.

### Gotcha: dlaczego `describe-clusters` pierwotnie zwróciło `settings: []`

`aws ecs describe-clusters` bez flagi `--include SETTINGS` pomija sekcję settings w output.
Z `--include SETTINGS` poprawnie zwraca `containerInsights = enabled`.

### Dostępność Enhanced Container Insights

- **Dostępne w eu-west-1**: TAK (rollout od Nov 2024, ogólnodostępne)
- **Fargate compatibility**: TAK (nie wymaga agenta sidecar — AWS zarządza zbieraniem)
- **Konfiguracja**: wyłącznie zmiana `containerInsights` na poziomie klastra: `enabled` → `enhanced`
- **Dodatkowe zasoby**: brak — same metryki, nowe dimensions (`TaskId`, `ContainerName`)
- **Log groups**: brak nowych — tylko nowe dimensions w `ECS/ContainerInsights`
- **Permissions**: żadne dodatkowe IAM nie są potrzebne
- **Koszt**: ~$0.50 za kontener/miesiąc (AWS Container Insights pricing). Przy 12 taskach ≈ $6–10/mies. dla UAT

### Source of truth

```
terraform/envs/uat/main.tf  →  module "ecs_cluster"  →  container_insights = "enhanced"
```

Moduł: `terraform/modules/ecs-cluster/main.tf` — `resource "aws_ecs_cluster"` z `setting { name = "containerInsights" value = var.container_insights }`.

---

## C. Decision

**`ENABLE_NOW`** — IaC zmienione, czeka na `terraform apply`.

Uzasadnienie:
1. Standard CI już działa → upgrade to enhanced to pojedyncza zmiana jednej zmiennej
2. Fargate: zero ryzyka operacyjnego (brak agenta sidecar, brak restartu tasków)
3. Bezpośrednio odpowiada na otwarte pytania diagnostyczne z anomalii Memory avg 45% / max 96%
4. Koszt akceptowalny dla UAT (~$6–10/mies.)
5. Łatwy rollback: zmień z powrotem na `enabled` i apply

---

## D. Changes made

### IaC (zrobione, czeka na apply)

Plik: `infra-maspex/terraform/envs/uat/main.tf`

```diff
 module "ecs_cluster" {
   source = "../../modules/ecs-cluster"

-  name = "${var.project}-${var.environment}"
-  tags = local.common_tags
+  name               = "${var.project}-${var.environment}"
+  container_insights = "enhanced"
+  tags               = local.common_tags
 }
```

Prod i preprod: **niezmienione** (zmiana tylko w `envs/uat/main.tf`, moduł nie był modyfikowany).

### Żeby aktywować — uruchom w UAT env

```bash
cd ~/projekty/mako/aws-projects/infra-maspex/terraform/envs/uat
terraform init  # jeśli nie zainicjalizowane
terraform plan -target=module.ecs_cluster
terraform apply -target=module.ecs_cluster
```

`-target=module.ecs_cluster` — tylko zmiana klastra, nie ruszamy innych zasobów.

### Alternatywa: live change bez Terraform (tworzy drift, do uzgodnienia z teamem)

```bash
aws ecs update-cluster-settings \
  --cluster maspex-uat \
  --settings name=containerInsights,value=enhanced \
  --profile maspex-cli --region eu-west-1
```

Ta zmiana zadziała natychmiast. Przy kolejnym `terraform apply` TF ją zharmonizuje (nie nadpisze — TF będzie ustawiał `enhanced`, co już jest ustawione).

### Skutki uboczne

- Nowe wymiary w `ECS/ContainerInsights` — więcej datapoints = wyższy rachunek CloudWatch
- Brak wpływu na działanie aplikacji, serwisu, health checks, autoskalowanie
- Brak restartu tasków

---

## E. Validation / verification result

Po `terraform apply` lub live change, weryfikacja:

```bash
# 1. Potwierdź ustawienie klastra
aws ecs describe-clusters \
  --clusters maspex-uat \
  --include SETTINGS \
  --profile maspex-cli --region eu-west-1 \
  --query 'clusters[0].settings'
# Oczekiwane: [{"name": "containerInsights", "value": "enhanced"}]

# 2. Sprawdź czy pojawiły się per-task metryki (po ~5 min)
aws cloudwatch list-metrics \
  --namespace ECS/ContainerInsights \
  --profile maspex-cli --region eu-west-1 \
  --query 'Metrics[?Dimensions[?Name==`TaskId`]].{metric:MetricName,task:Dimensions[?Name==`TaskId`].Value|[0]}' \
  --output table
# Oczekiwane: wiersze z kolumną task wypełnioną task-ID
```

Nowe metryki pojawiają się w ciągu **1–5 minut** od aktywacji.

### Gdzie szukać danych

| Narzędzie | Namespace | Dimensions |
|-----------|-----------|------------|
| CloudWatch Console | `ECS/ContainerInsights` | `TaskId` |
| AWS CLI | `aws cloudwatch get-metric-statistics --dimensions Name=TaskId,Value=<id>` | `TaskId` |
| CloudWatch Logs Insights | nie dotyczy — to są metryki, nie logi | — |

---

## F. Next load test validation plan

### Pytania do rozstrzygnięcia

| # | Pytanie | Metryka | Jak odczytać |
|---|---------|---------|--------------|
| 1 | Który task był hotspotem? | `MemoryUtilized` per TaskId | Task z najwyższym peak podczas testu |
| 2 | Czy problem był memory-first czy CPU-first? | oba per TaskId w czasie | Który wzrósł wcześniej i mocniej |
| 3 | Czy rozkład ruchu był nierówny? | `CpuUtilized` per TaskId | Spread między taskami podczas peak |
| 4 | Czy ubijane taski miały charakter OOM / CPU starvation? | TaskId korelacja ze stopped-tasks | Czy zadany task → STOPPED miał memory = ~100% przed śmiercią |

### Dane do zebrania PODCZAS testu

#### Continuous (co 1 min przez CLI lub alarm)

```bash
START="2026-XX-XXT...:00Z"  # UTC
END="2026-XX-XXT...:00Z"

# Per-task memory — wszystkie taski maspex-api
aws cloudwatch get-metric-data \
  --profile maspex-cli --region eu-west-1 \
  --start-time $START --end-time $END \
  --metric-data-queries '[
    {"Id":"mem","MetricStat":{"Metric":{"Namespace":"ECS/ContainerInsights","MetricName":"MemoryUtilized","Dimensions":[{"Name":"ClusterName","Value":"maspex-uat"},{"Name":"ServiceName","Value":"maspex-api"}]},"Period":60,"Stat":"Maximum"},"Label":"mem_max"}
  ]' --output json
# UWAGA: to daje agregat serwisu. Dla per-task potrzebujesz TaskId dimension.
# Zrób osobne query dla każdego TaskId lub użyj Metrics Insights:

aws cloudwatch get-metric-data \
  --profile maspex-cli --region eu-west-1 \
  --start-time $START --end-time $END \
  --metric-data-queries '[
    {"Id":"q1","Expression":"SELECT MAX(MemoryUtilized) FROM ECS/ContainerInsights WHERE ClusterName = '\''maspex-uat'\'' AND ServiceName = '\''maspex-api'\'' GROUP BY TaskId","Period":60,"Label":"mem_per_task"}
  ]' --output json
```

#### Po teście — korelacja stopped tasks z metrykamii

```bash
# 1. Lista stopped tasks z ECS
aws ecs list-tasks \
  --cluster maspex-uat \
  --service-name maspex-api \
  --desired-status STOPPED \
  --profile maspex-cli --region eu-west-1

# 2. Szczegóły stopped tasks (powód ubicia)
aws ecs describe-tasks \
  --cluster maspex-uat \
  --tasks <task-arn1> <task-arn2> \
  --profile maspex-cli --region eu-west-1 \
  --query 'tasks[*].{id:taskArn,reason:stoppedReason,stopCode:stopCode,startedAt:startedAt,stoppedAt:stoppedAt,containers:containers[*].{name:name,exitCode:exitCode,reason:reason}}'

# 3. ECS service events (ostatnie 10 zdarzeń)
aws ecs describe-services \
  --cluster maspex-uat \
  --services maspex-api \
  --profile maspex-cli --region eu-west-1 \
  --query 'services[0].events[:10]'

# 4. CloudWatch Metrics Insights — per-task max memory podczas okna testu
aws cloudwatch get-metric-data \
  --profile maspex-cli --region eu-west-1 \
  --start-time $START --end-time $END \
  --metric-data-queries '[
    {"Id":"q1","Expression":"SELECT MAX(MemoryUtilized) FROM ECS/ContainerInsights WHERE ClusterName = '\''maspex-uat'\'' GROUP BY TaskId","Period":300,"Label":"mem_per_task"},
    {"Id":"q2","Expression":"SELECT MAX(CpuUtilized) FROM ECS/ContainerInsights WHERE ClusterName = '\''maspex-uat'\'' GROUP BY TaskId","Period":300,"Label":"cpu_per_task"}
  ]' --output json
```

### Interpretacja wyników

#### Memory hotspot (zadany task dobijał do limitu)

```
Sygnał:  TaskId X: MemoryUtilized → ~7800–8192 MB (task ma 8192 MB limitu)
         Pozostałe taski: MemoryUtilized ~3000–5000 MB
Diagnoza: Task X był memory-saturated. Reszta serwisu jeszcze nie.
Korelacja: TaskId X w liście stopped-tasks z stoppedReason zawierającym "OOM" lub exitCode 137
```

#### CPU hotspot / CPU starvation

```
Sygnał:  TaskId X: CpuUtilized → ~3800–4096 CPU units (task ma 4096 limitu)
         Pozostałe taski: CpuUtilized ~1000–2000
Diagnoza: Task X był CPU-saturated. Może to powodować timeout requestów.
Korelacja: ALB HTTPCode_Target_5XX_Count wzrost w tym samym oknie
```

#### Nierówny rozkład obciążenia

```
Sygnał:  Spread CpuUtilized między taskami > 3x
         np. task A: 3800 units, task B: 900 units w tym samym czasie
Diagnoza: ALB rozkłada ruch nierównomiernie (możliwy connection draining, sticky sessions, cold start nowego taska)
Korelacja: sprawdź czy ubity task miał krótki uptime przed śmiercią (cold-start pod obciążeniem)
```

#### OOM-like bez CW OOM signal

```
Sygnał:  stoppedReason: "Essential container in task exited"
         exitCode: 137 (SIGKILL = OOM Kill w Linuxie)
         MemoryUtilized tego TaskId osiągało peak ~100% tuż przed stoppedAt
Diagnoza: OOM Kill na poziomie kontenera Fargate
```

#### Transient overload (task się zrestartował, wrócił normalnie)

```
Sygnał:  TaskId X ubity, nowy TaskId Y startuje w ciągu 30-60s
         Brak trwałego degradacji MemoryUtilized/CpuUtilized po restarcie
Diagnoza: Transient spike, nie strukturalne przepełnienie. Może być cold-start przy scale-out.
```

---

## G. Remaining gaps — czego nadal nie zobaczymy

| Brak danych | Co byłoby potrzebne |
|-------------|---------------------|
| Który konkretny endpoint / request spowodował memory spike | APM: X-Ray, Datadog, Sentry performance monitoring |
| Per-request latency rozbita na taskopoziom | APM lub middleware z TaskId w nagłówku |
| Auth path breakdown (bearer-local-jwt vs bearer-gotrue-fallback) | Logi aplikacyjne + strukturyzowany JSON log z polem `authStrategy` |
| Connection pool exhaustion (PostgreSQL, Redis) per-task | Logi aplikacyjne (pg pool, ioredis) lub metryki custom |
| Garbage collection pressure (Node.js heap) | Node.js --expose-gc metryki lub APM |
| Dokładna kolejność przyczyna→skutek na poziomie ms | Distributed tracing (X-Ray, OTEL) |
| Skumulowany load per-task (ile requestów trafił dany task) | ALB target group nie ma per-task breakdown — tylko per-AZ |

**Krótki wniosek:** Enhanced Container Insights odpowiada na pytania *infrastrukturalne* (który task, memory vs CPU, OOM/exit code). Nie odpowiada na pytania *aplikacyjne* (który request, który handler, dlaczego memory rośnie).

---

## H. Final verdict

**Enhanced Container Insights = właściwy następny krok diagnostyczny dla UAT.**

Mamy gotowe pytania, których standard CI nie może rozstrzygnąć. Enhanced CI je rozstrzyga bez zmiany kodu aplikacji, bez sidecar agenta, za ~$6–10/mies. Zmiana jest już w IaC, potrzebuje tylko `terraform apply`.

Po włączeniu i kolejnym load teście będziemy wiedzieć, który task był hotspotem i czy problem był memory-first czy CPU-first. Dalsze dochodzenie (why memory grows) wymaga APM.

---

## I. Exact files / resources used

### AWS resources inspected

```
aws ecs describe-clusters --clusters maspex-uat --include SETTINGS
aws ecs describe-services --cluster maspex-uat --services maspex-api
aws ecs describe-task-definition --task-definition maspex-api:65
aws cloudwatch list-metrics --namespace ECS/ContainerInsights [+ all maspex-uat cluster metrics]
aws ecs list-account-settings
```

### Files analyzed

```
infra-maspex/terraform/envs/uat/main.tf
infra-maspex/terraform/modules/ecs-cluster/main.tf
infra-maspex/terraform/modules/ecs-cluster/variables.tf
infra-maspex/terraform/modules/monitoring/main.tf (komentarz o CI)
```

### File changed

```
infra-maspex/terraform/envs/uat/main.tf
  → module "ecs_cluster": dodano container_insights = "enhanced"
```

### Key finding w discovery

`aws ecs describe-clusters` bez `--include SETTINGS` zwraca `settings: []` nawet gdy Container Insights jest włączone. Zawsze używaj `--include SETTINGS` do weryfikacji.
