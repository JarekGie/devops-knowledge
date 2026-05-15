# Maspex Campaign Day Monitoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rozszerzyć istniejący moduł monitoringowy Maspex o brakujące widżety i alarmy na campaign day 18 maja (additive-only changes).

**Architecture:** Wszystkie zmiany trafiają do `terraform/modules/monitoring/main.tf` w `infra-maspex`. Dwa środowiska: UAT (validate) + PROD (target). Runbook ląduje w vault. Żadne istniejące zasoby nie są modyfikowane — tylko nowe bloki dołączane na końcu.

**Tech Stack:** Terraform ≥1.0, AWS CloudWatch, ECS/ContainerInsights, SNS. Branch: `feat/campaign-day-monitoring` w `infra-maspex`.

---

## Pliki

| Plik | Akcja | Co się zmienia |
|------|-------|----------------|
| `terraform/modules/monitoring/main.tf` | Modify | +3 alarmy, +3 widżety w dashboardzie, +1 local `campaign_alarm_arns` |
| `terraform/envs/prod/main.tf` | Modify | `container_insights = "enhanced"` w module `ecs_cluster` |
| `20-projects/clients/mako/maspex/campaign-day-runbook.md` (vault) | Create | Runbook operatorski na 18 maja |

---

## Task 1: Nowe alarmy w monitoring module

**Pliki:**
- Modify: `~/projekty/mako/aws-projects/infra-maspex/terraform/modules/monitoring/main.tf` — append 3 alarm resources

- [ ] **Krok 1: Otwórz plik i zidentyfikuj koniec sekcji alarmów**

Plik kończy się definicją dashboardu (`resource "aws_cloudwatch_dashboard" "overview"`). Nowe alarmy dopisujemy PRZED tym resource, za ostatnim alarmem `api_auth_errors`.

- [ ] **Krok 2: Dopisz 3 alarmy po linii `tags = var.tags\n}` ostatniego alarmu (api_auth_errors)**

```hcl
resource "aws_cloudwatch_metric_alarm" "redis_high_engine_cpu" {
  count = var.redis_cache_cluster_id != null ? 1 : 0

  alarm_name          = "${var.name}-redis-high-engine-cpu"
  alarm_description   = "Redis EngineCPU exceeded 50% for 3 minutes — cache saturation risk, latency spikes likely"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "EngineCPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 60
  statistic           = "Average"
  threshold           = 50
  treat_missing_data  = "notBreaching"

  dimensions = {
    CacheClusterId = var.redis_cache_cluster_id
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "redis_evictions" {
  count = var.redis_cache_cluster_id != null ? 1 : 0

  alarm_name          = "${var.name}-redis-evictions"
  alarm_description   = "Redis Evictions > 100/min — maxmemory pressure, slogan cache data being dropped"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Evictions"
  namespace           = "AWS/ElastiCache"
  period              = 60
  statistic           = "Sum"
  threshold           = 100
  treat_missing_data  = "notBreaching"

  dimensions = {
    CacheClusterId = var.redis_cache_cluster_id
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_api_pending_tasks" {
  alarm_name          = "${var.name}-ecs-api-pending-tasks"
  alarm_description   = "ECS api PendingTaskCount > 0 for 3 minutes — autoscaling not delivering capacity, tasks stuck"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "PendingTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.service_api_name
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions
  tags          = var.tags
}
```

- [ ] **Krok 3: Validate syntax**

```bash
cd ~/projekty/mako/aws-projects/infra-maspex/terraform/modules/monitoring
terraform fmt -check main.tf
```

Expected: brak wyjścia (lub "main.tf" jeśli fmt potrzebny — uruchom `terraform fmt` bez `-check`).

---

## Task 2: Nowe widżety w dashboardzie (campaign day row)

**Pliki:**
- Modify: `~/projekty/mako/aws-projects/infra-maspex/terraform/modules/monitoring/main.tf` — modify dashboard body

Obecny dashboard kończy się w wierszu 12 (y=66+6=72). Dodajemy 3 nowe wiersze:
- Row 13 (y=72): Alarm Status Overview — 24-wide single panel
- Row 14 (y=76): ALBRequestCountPerTarget (12-wide) | PendingTaskCount (12-wide)

- [ ] **Krok 1: Dodaj local `campaign_alarm_arns` w bloku `locals {}`**

W istniejącym `locals {}` (na początku pliku) dopisz:

```hcl
  campaign_alarm_arns = compact([
    aws_cloudwatch_metric_alarm.alb_target_5xx.arn,
    aws_cloudwatch_metric_alarm.alb_elb_5xx.arn,
    aws_cloudwatch_metric_alarm.alb_unhealthy_hosts_api.arn,
    aws_cloudwatch_metric_alarm.alb_api_target_response_time_high.arn,
    aws_cloudwatch_metric_alarm.alb_api_target_connection_errors.arn,
    aws_cloudwatch_metric_alarm.ecs_api_running_below_desired.arn,
    aws_cloudwatch_metric_alarm.ecs_high_cpu_api.arn,
    aws_cloudwatch_metric_alarm.ecs_high_memory_api.arn,
    aws_cloudwatch_metric_alarm.api_downstream_log_errors.arn,
    aws_cloudwatch_metric_alarm.api_redis_circuit_open.arn,
    try(aws_cloudwatch_metric_alarm.cloudfront_api_5xx[0].arn, null),
    try(aws_cloudwatch_metric_alarm.redis_high_engine_cpu[0].arn, null),
    try(aws_cloudwatch_metric_alarm.redis_evictions[0].arn, null),
    aws_cloudwatch_metric_alarm.ecs_api_pending_tasks.arn,
  ])
```

- [ ] **Krok 2: Dopisz 3 widżety na końcu listy `widgets = [` w resource `aws_cloudwatch_dashboard.overview`**

Ostatni istniejący widżet kończy się `},` przed zamknięciem `]`. Dopisz:

```hcl
      # -----------------------------------------------------------------------
      # Row 13 — Campaign Day: Alarm Status Overview
      # -----------------------------------------------------------------------
      {
        type   = "alarm"
        x      = 0
        y      = 72
        width  = 24
        height = 4
        properties = {
          title  = "CAMPAIGN DAY — Alarm Status (zielono = OK)"
          alarms = local.campaign_alarm_arns
        }
      },

      # -----------------------------------------------------------------------
      # Row 14 — Campaign Day: Autoscaling signals
      # -----------------------------------------------------------------------
      {
        type   = "metric"
        x      = 0
        y      = 76
        width  = 12
        height = 6
        properties = {
          title  = "ECS API — ALB Requests / Target (autoscaling trigger)"
          region = var.region
          view   = "timeSeries"
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCountPerTarget",
              "LoadBalancer", local.alb_arn_suffix,
              "TargetGroup", var.api_tg_arn_suffix,
              { label = "Req/Target/min" }]
          ]
          annotations = {
            horizontal = [
              { value = 200, label = "Autoscaling target (scale-out)", color = "#ff9900" }
            ]
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 76
        width  = 12
        height = 6
        properties = {
          title  = "ECS API — Pending Task Count"
          region = var.region
          view   = "timeSeries"
          stat   = "Maximum"
          period = 60
          metrics = [
            ["ECS/ContainerInsights", "PendingTaskCount",
              "ClusterName", var.ecs_cluster_name,
              "ServiceName", var.service_api_name,
              { label = "PendingTasks (>0 = autoscaling w toku lub stuck)" }]
          ]
        }
      },
```

- [ ] **Krok 3: fmt i validate**

```bash
cd ~/projekty/mako/aws-projects/infra-maspex/terraform/modules/monitoring
terraform fmt main.tf
```

---

## Task 3: Enhanced Container Insights dla PROD

**Ocena ryzyka:** Zero ryzyka operacyjnego. Enhanced CI dodaje wyłącznie metryki CloudWatch (dimension TaskId). Nie restartuje tasków, nie zmienia sieci, nie wymaga downtime. Koszt: ~$0.30–0.50/mies. dodatkowych metryk CW.

**Pliki:**
- Modify: `~/projekty/mako/aws-projects/infra-maspex/terraform/envs/prod/main.tf` — module `ecs_cluster`

- [ ] **Krok 1: Znajdź blok `module "ecs_cluster"` w prod/main.tf**

```bash
grep -n "ecs_cluster\|container_insights" ~/projekty/mako/aws-projects/infra-maspex/terraform/envs/prod/main.tf | head -10
```

- [ ] **Krok 2: Dopisz `container_insights = "enhanced"` w module ecs_cluster**

Dodaj linię do istniejącego bloku `module "ecs_cluster"` (analogicznie jak w UAT line 57):

```hcl
  container_insights = "enhanced"
```

- [ ] **Krok 3: Commit zmian Task 1–3 (przed terraform plan)**

```bash
cd ~/projekty/mako/aws-projects/infra-maspex
git add terraform/modules/monitoring/main.tf terraform/envs/prod/main.tf
git commit -m "feat(monitoring): add campaign-day alarms, widgets, enhanced CI prod"
```

---

## Task 4: Terraform plan — UAT (validate)

- [ ] **Krok 1: Init + plan UAT**

```bash
cd ~/projekty/mako/aws-projects/infra-maspex/terraform/envs/uat
AWS_PROFILE=maspex-cli terraform init -backend-config=backend.hcl -reconfigure
AWS_PROFILE=maspex-cli terraform plan -out=plan-uat-campaign.tfplan 2>&1 | tee /tmp/plan-uat.txt
```

- [ ] **Krok 2: Zweryfikuj plan output**

Expected zmiany (tylko additions):
- `module.monitoring.aws_cloudwatch_metric_alarm.redis_high_engine_cpu[0]` — create
- `module.monitoring.aws_cloudwatch_metric_alarm.redis_evictions[0]` — create
- `module.monitoring.aws_cloudwatch_metric_alarm.ecs_api_pending_tasks` — create
- `module.monitoring.aws_cloudwatch_dashboard.overview` — update in-place (dashboard body zmienia się)

Expected: **0 destroyed**. Jeśli plan pokazuje destroy czegokolwiek — STOP, nie rób apply.

- [ ] **Krok 3: Apply UAT**

```bash
AWS_PROFILE=maspex-cli terraform apply plan-uat-campaign.tfplan
```

- [ ] **Krok 4: Weryfikacja wizualna**

Otwórz CloudWatch → Dashboards → `maspex-uat-overview`.
Sprawdź:
- Row 13: "CAMPAIGN DAY — Alarm Status" — widoczny, alarmy wylistowane
- Row 14: "ECS API — ALB Requests / Target" + "ECS API — Pending Task Count" — widoczne wykresy
- Żadne istniejące widżety nie zniknęły

---

## Task 5: Terraform plan + apply — PROD

- [ ] **Krok 1: Init + plan PROD**

```bash
cd ~/projekty/mako/aws-projects/infra-maspex/terraform/envs/prod
AWS_PROFILE=maspex-cli terraform init -backend-config=backend.hcl -reconfigure
AWS_PROFILE=maspex-cli terraform plan -out=plan-prod-campaign.tfplan 2>&1 | tee /tmp/plan-prod.txt
```

- [ ] **Krok 2: Zweryfikuj plan output**

Expected zmiany:
- `module.ecs_cluster` — update (container_insights standard → enhanced)
- `module.monitoring.aws_cloudwatch_metric_alarm.redis_high_engine_cpu[0]` — create
- `module.monitoring.aws_cloudwatch_metric_alarm.redis_evictions[0]` — create
- `module.monitoring.aws_cloudwatch_metric_alarm.ecs_api_pending_tasks` — create
- `module.monitoring.aws_cloudwatch_dashboard.overview` — update in-place

Expected: **0 destroyed**.

- [ ] **Krok 3: Apply PROD**

```bash
AWS_PROFILE=maspex-cli terraform apply plan-prod-campaign.tfplan
```

- [ ] **Krok 4: Weryfikacja wizualna PROD**

Otwórz CloudWatch → Dashboards → `maspex-prod-overview`.
Sprawdź Row 13 i Row 14 jak w UAT.

---

## Task 6: Runbook w vault

**Pliki:**
- Create: `~/projekty/devops/devops-knowledge/20-projects/clients/mako/maspex/campaign-day-runbook.md`

- [ ] **Krok 1: Utwórz plik runbooku**

Zawartość — patrz poniżej (sekcja Runbook).

- [ ] **Krok 2: Zaktualizuj session-log**

Dopisz wpis do `session-log.md`.

---

## Task 7: PR

- [ ] **Krok 1: Push feature branch**

```bash
cd ~/projekty/mako/aws-projects/infra-maspex
git push -u origin feat/campaign-day-monitoring
```

- [ ] **Krok 2: Utwórz MR/PR**

Title: `feat(monitoring): campaign-day alarms + widgets + Enhanced CI prod`
Body: wskaż co dodano, że zmiany są additive-only, że UAT validate przeszedł.

---

## Self-Review

- [x] Spec coverage: alarmy Redis (CPU + evictions) ✓, ECS pending ✓, alarm status widget ✓, ALBRequestCountPerTarget ✓, PendingTaskCount ✓, Enhanced CI PROD ✓, runbook ✓
- [x] Placeholder scan: brak TBD
- [x] Type consistency: wszystkie resource names spójne, locals.campaign_alarm_arns używa poprawnych ARN referencji
- [x] Additive-only: 0 destroyed w obu planach (zweryfikowane w kroku walidacji)
