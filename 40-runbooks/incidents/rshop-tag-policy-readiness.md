---
date: 2026-04-24
project: rshop
tags: [rshop, tag-policy, runbook, ecs, cfn]
domain: client-work/mako
---

# RSHOP — Gotowość do Tag Policies (runbook przed re-enable)

## Objaw / Symptom

Incydent 2026-04-20: Tag Policies (LLZ) wdrożone przez terraform → ENI Fargate tasks nie miały wymaganych tagów → `TagPolicyViolation` → ECS nie mógł tworzyć ENI dla nowych zadań → prod 503.
Tymczasowe rozwiązanie: `terraform destroy` Tag Policies (LLZ). Tag Policies są obecnie **WYŁĄCZONE**.

Cel tego runbooka: lista blokerów + kolejność kroków bezpiecznego re-enable Tag Policies.

---

## Kontekst

- Konto: 943111679945 | Region: eu-central-1 | Profil: `rshop`
- Klastry ECS: `rshop-prod-Klaster`, `rshop-dev-Klaster`, `akcesoria2-prod-Klaster`
- CFN repozytoria:
  - `~/projekty/mako/rshop-cloudformation/cloudformation/` (api.yml, backoffice.yml, frontend.yml, frontend2.yml)
  - `~/projekty/mako/aws-projects/infra-rshop/cloudformation/akcesoria2/svc.yml`
- LLZ Tag Policy Terraform: repo `aws-cloud-platform`, moduł tag-policies

## Root Cause (incydent 2026-04-20)

ECS Fargate przy każdym nowym tasku tworzy ENI. Jeśli Tag Policy wymaga tagów na `ec2:network-interface` i task nie ma `PropagateTags: SERVICE` → ENI nie dostaje tagów serwisu → violation → CreateNetworkInterface denied → task nie startuje → ECS service unhealthy → 503.

---

## Ocena gotowości: per zakres (2026-04-24)

| Zakres | Status | Bloker |
|--------|--------|--------|
| rshop-prod ECS Services | **NO-GO** | propagateTags=SERVICE tylko runtime (drift) — CFN nie ma PropagateTags. Następny deploy CFN resetuje do NONE. |
| rshop-dev ECS Services | **NO-GO** | propagateTags=NONE, brak PropagateTags w CFN. ENI nigdy nie tagowane. |
| akcesoria2-prod ECS Services | **NO-GO** | propagateTags=NONE, CFN ma Tags ale brak PropagateTags. |
| RDS | TAK | kompletne tagi |
| ALB prod | TAK | kompletne tagi |
| ALB dev | NO-GO | stary schemat Tribecloud — brakuje Owner, CostCenter, ManagedBy, Project |
| VPC Endpoints (8) | PARTIAL | brakuje Project i/lub Environment |
| ECR repozytoria (prod/qa/uat) | NO-GO | brakuje Project, Owner, ManagedBy, CostCenter |
| S3 orphany | PARTIAL | rshop-dev-backup/bk/temp/terraform-states bez tagów |
| CloudWatch Log Groups | NO-GO | brak wszystkich tagów |

**Ogólna ocena: NO-GO** — nie re-enable bez usunięcia blokerów #1–#3 poniżej.

---

## Szybkie komendy diagnostyczne

```bash
# Sprawdź propagateTags na prod serwisach
aws ecs describe-services \
  --cluster rshop-prod-Klaster \
  --services rshop-prod-backoffice-svc rshop-prod-frontend-svc1 rshop-prod-frontend-svc2 rshop-prod-api-svc \
  --profile rshop --region eu-central-1 \
  --query 'services[*].{svc:serviceName,prop:propagateTags,ems:enableECSManagedTags}' \
  --include TAGS

# Sprawdź propagateTags na dev serwisach
aws ecs describe-services \
  --cluster rshop-dev-Klaster \
  --services rshop-dev-backoffice-svc rshop-dev-frontend-svc1 rshop-dev-frontend-svc2 rshop-dev-api-svc \
  --profile rshop --region eu-central-1 \
  --query 'services[*].{svc:serviceName,prop:propagateTags,ems:enableECSManagedTags}' \
  --include TAGS

# Sprawdź tagi na ENI aktualnych tasków (sample: prod-backoffice)
TASK=$(aws ecs list-tasks --cluster rshop-prod-Klaster --service-name rshop-prod-backoffice-svc \
  --profile rshop --region eu-central-1 --query 'taskArns[0]' --output text)
aws ecs describe-tasks --cluster rshop-prod-Klaster --tasks "$TASK" \
  --profile rshop --region eu-central-1 \
  --query 'tasks[0].attachments[?type==`ElasticNetworkInterface`].details'

# Sprawdź stan Tag Policies (LLZ — Organizations)
# UWAGA: wymaga profilu z dostępem do Organizations (management account lub delegated)
```

---

## Top 5 blokerów przed re-enable Tag Policies

### BLOKER #1 — rshop-cloudformation: brak PropagateTags/Tags/EnableECSManagedTags (KRYTYCZNE)

**Dotyczy:** api.yml, backoffice.yml, frontend.yml, frontend2.yml

**Co dodać** do każdego `AWS::ECS::Service`:

```yaml
PropagateTags: SERVICE
EnableECSManagedTags: true
Tags:
  - Key: Project
    Value: !Ref Projekt
  - Key: Environment
    Value: !Ref Srodowisko
  - Key: Owner
    Value: DC-devops
  - Key: ManagedBy
    Value: cloudformation
  - Key: CostCenter
    Value: DC
  - Key: Service
    Value: <nazwa-serwisu>  # backoffice / api / frontend-renault / frontend-dacia
```

**Lokalizacja w pliku:** po ostatniej właściwości `AWS::ECS::Service`, przed zamknięciem definicji serwisu.

**Weryfikacja po deploy:**
```bash
aws ecs describe-services --cluster rshop-dev-Klaster \
  --services rshop-dev-api-svc --profile rshop --region eu-central-1 \
  --query 'services[0].{prop:propagateTags,ems:enableECSManagedTags}'
# Oczekiwane: propagateTags: SERVICE, enableECSManagedTags: true
```

### BLOKER #2 — akcesoria2/svc.yml: brak PropagateTags/EnableECSManagedTags (KRYTYCZNE)

**Dotyczy:** svc.yml — `DaciaSvc` i `RenaultSvc`

**Co dodać** (Tags już są — tylko dwie linie brakuje per serwis):

```yaml
# Pod Properties: ... (po Tags:), przed zamknięciem serwisu
PropagateTags: SERVICE
EnableECSManagedTags: true
```

**Uwaga:** Sprawdzić czy allowedValues Tag Policy dla `Project` zawiera `akcesoria2`. Jeśli polityka ma `allowedValues: [rshop]` — akcesoria2-prod nadal będzie naruszać, nawet po dodaniu PropagateTags.

### BLOKER #3 — Weryfikacja allowedValues LLZ Tag Policy (KRYTYCZNE dla akcesoria2)

**Sprawdzić w repo LLZ (aws-cloud-platform):**
- Moduł tag-policies: `Project` allowedValues — czy zawiera `akcesoria2`
- Jeśli nie → dodać przed re-enable
- **Lokalizacja:** `~/projekty/mako/aws-cloud-platform/` lub repo LLZ

### BLOKER #4 — dev-ALB niekompletne tagi (WYSOKIE)

- dev-ALB ma stary schemat Tribecloud (zarządzany przez `dev-alb-ownership` CFN stack)
- Brakuje: Project, Owner, CostCenter, ManagedBy
- Jeśli Tag Policy obejmuje `elasticloadbalancing:loadbalancer` → violation
- Fix: aktualizacja CFN stack `dev-alb-ownership` — dodać brakujące tagi do zasobu ALB

### BLOKER #5 — ECR repozytoria (WYSOKIE)

- rshopapp-prod, rshopapp-qa, rshopapp-uat: brakuje Project (prod), Owner/ManagedBy/CostCenter (wszystkie)
- Jeśli Tag Policy obejmuje `ecr:repository` → violation
- Fix: `aws ecr tag-resource` lub CFN update

---

## Kolejność bezpiecznego re-enable

```
KROK 1: Fix CFN rshop-cloudformation (api/backoffice/frontend/frontend2)
        → commit na feature branch → code review → merge

KROK 2: Deploy na rshop-dev (update stack)
        → wait for steady state
        → weryfikacja ENI tagów (komenda diagnostyczna wyżej)
        → weryfikacja propagateTags=SERVICE via describe-services

KROK 3: Deploy na rshop-prod (update stack)
        → monitoring przez 15 min (żadne 503, service healthy)

KROK 4: Fix CFN akcesoria2/svc.yml
        → commit → deploy akcesoria2-prod
        → weryfikacja ENI tagów

KROK 5: Weryfikacja allowedValues w LLZ Tag Policy
        → upewnienie się, że 'akcesoria2' jest w Project allowedValues

KROK 6: Weryfikacja pozostałych zasobów (VPC Endpoints, ECR, ALB dev)
        → tag remediation (nie blokuje ECS, ale może powodować soft violations)

KROK 7: terraform apply Tag Policies (LLZ)
        → środowisko: LLZ management account / Organizations

KROK 8: Monitoring przez 24h
        → CloudTrail: szukaj TagPolicyViolation events
        → ECS: desiredCount vs runningCount na wszystkich serwisach
```

---

## Decision Points

| Pytanie | Decyzja wymagana od |
|---------|---------------------|
| Czy Tag Policy w LLZ ma `ec2:network-interface` w scope? | Sprawdzić w terraform LLZ |
| Czy `akcesoria2` jest w allowedValues dla Project? | Sprawdzić w terraform LLZ |
| Czy stary schemat Tribecloud na dev-ALB/cos_dev VPC ma być migrowany przed re-enable? | Jarosław + klient |
| Co z ECR rshopapp-qa — czy QA będzie reaktywowane? | Klient |

---

## Rollback / Safety

Jeśli po re-enable pojawią się nowe 503:
1. Natychmiast: `terraform destroy` w module tag-policies (LLZ) — jak 2026-04-20
2. Sprawdzić CloudTrail: `aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=TagPolicyViolation`
3. Sprawdzić który serwis / zasób generuje violations
4. Fix tagów na zasobie PRZED ponownym re-enable

---

## Findings / Notes

- Incydent 2026-04-20: prod był ponownie zdeployowany ręcznie z `propagateTags=SERVICE` po disable Tag Policies — to tymczasowy fix, nie trwały
- rshop-prod serwisy mają `enableECSManagedTags=True` (drift) — to pozwala na tagowanie TaskArn/ServiceArn na ENI, ale nadal potrzebuje PropagateTags=SERVICE by dziedziczone były tagi klienta (Project/Environment etc.)
- Bez `PropagateTags: SERVICE` w CFN — każdy `aws cloudformation update-stack` zresetuje serwis do NONE
- Log groups bez retencji >1d: /ecs/rshop-prod i /ecs/rshop-dev (1 dzień!) — odrębna luka operacyjna

*Powiązane: [[rshop-tagging-baseline-2026-04-24]] | [[rshop-prod-503-2026-04-20]] | [[rshop-tag-policy-remediation]]*
*Audyt bazowy: 2026-04-24*
