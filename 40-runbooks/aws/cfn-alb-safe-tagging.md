# RUNBOOK — Safe Tagging of ALB/ECS (CloudFormation)

## 1. Purpose

Bezpieczne wprowadzenie tagów do zasobów AWS (ALB, Target Groups, ECS) zarządzanych przez CloudFormation **bez ryzyka downtime, replacementów i rollback failure**.

Zakres:

* AWS::ElasticLoadBalancingV2::*
* AWS::ECS::Service
* Nested stacks

---

## 2. High-Risk Resources

Tagowanie poniższych zasobów może wywołać **update chain reaction**:

| Resource Type | Risk      | Notes                                    |
| ------------- | --------- | ---------------------------------------- |
| LoadBalancer  | 🔴 HIGH   | może propagować zmiany do listenerów     |
| Listener      | 🔴 HIGH   | może powodować reewaluację rules         |
| ListenerRule  | 🔴 HIGH   | routing może się zmienić                 |
| TargetGroup   | 🔴 HIGH   | ECS może się przełączyć / stracić health |
| ECS Service   | 🟠 MEDIUM | może triggerować deployment              |

---

## 3. Preconditions (MANDATORY)

### 3.1 Drift Check

```bash
aws cloudformation detect-stack-drift --stack-name <STACK>
aws cloudformation describe-stack-drift-detection-status --stack-drift-detection-id <ID>
```

✅ Wymagane: `StackDriftStatus = IN_SYNC`
❌ Jeśli `DRIFTED` → STOP

---

### 3.2 Resource Ownership

Sprawdź:

* czy ALB istnieje tylko w CF
* czy nie był modyfikowany ręcznie, odtwarzany poza CF, podmieniany DNS / TG

```bash
aws elbv2 describe-load-balancers
aws elbv2 describe-target-groups
```

❌ Jeśli ARN ≠ CF template → STOP

---

### 3.3 Dependency Mapping

Zmapuj pełny chain:

```
ALB
 └── Listener
      └── ListenerRule
           └── TargetGroup
                └── ECS Service
```

---

### 3.4 Change Set Preview (REQUIRED)

```bash
aws cloudformation create-change-set ...
aws cloudformation describe-change-set ...
```

✅ Wymagane: brak `Replacement: True` dla ALB, TargetGroup, ECS Service
❌ Jeśli występuje → STOP

---

## 4. Safe Tagging Strategy

### 4.1 Phase 1 — Safe Resources Only

Taguj tylko:

* VPC, Subnet, Security Groups, S3, ECS Cluster, LogGroup

❌ NIE taguj: ALB, Listener, ListenerRule, TargetGroup

---

### 4.2 Phase 2 — Controlled ALB Tagging

Warunki: drift = brak, change set = bez replacementów

1. Taguj LoadBalancer ONLY
2. Deploy
3. Obserwuj 5–10 min (brak 5xx, target health OK)

---

### 4.3 Phase 3 — Target Groups

1. Dodaj tagi tylko do TG
2. Deploy
3. Check:

```bash
aws elbv2 describe-target-health --target-group-arn <ARN>
```

---

### 4.4 Phase 4 — ECS Service

Opcjonalnie — użyj:

```yaml
EnableECSManagedTags: true
PropagateTags: SERVICE
```

---

## 5. Forbidden Operations

❌ NIE WOLNO:

* tagować wszystkiego w jednym deployu
* tagować Listener + TargetGroup jednocześnie
* używać `UsePreviousValue` przy drift
* wykonywać deploy bez change-set review
* mieszać manual changes + CF update

---

## 6. Rollback Safety

```bash
aws ecs describe-services ...
aws elbv2 describe-target-health ...
aws ecr describe-images --repository-name <repo>
```

❌ Brak image → rollback FAIL

### Emergency Recovery

```bash
aws cloudformation continue-update-rollback \
  --stack-name <STACK> \
  --resources-to-skip <RESOURCE>
```

---

## 7. Observability During Change

Monitor:

* ALB: 5xx, TargetResponseTime
* ECS: runningCount, deployment events
* CloudWatch Logs

---

## 8. Post-Deployment Validation

* ALB healthy, wszystkie TG healthy, brak 5xx, ECS stable, brak restartów

---

## 9. Golden Rules

* ALB = najbardziej wrażliwy element stacka
* Tagging ≠ metadata only (dla CF to change)
* Drift + tagging = najwyższe ryzyko
* Zawsze małe kroki + deploy per warstwa

---

## 10. Recommended Architecture (Future)

Aby uniknąć problemów: ALB jako osobny stack, ECS jako osobny stack — komunikacja przez Outputs/Imports lub parametry.

---

## 11. TL;DR

1. Detect drift
2. Preview change set
3. Tag warstwowo
4. Monitor po każdym kroku
5. Nigdy nie ruszaj ALB + TG jednocześnie

---

## 12. Incident Memory

Po wcześniejszym incydencie z rshop:

* traktuj ALB jako **potentially drifted**
* zawsze używaj explicit values — NIE `UsePreviousValue`
* listenerów NIE taguj przez CFN stack-level tags (propagacja = niekontrolowana)
* `apply-pack tagging` (API) jest bezpieczniejszy niż CFN — nie dotyka listenerów
