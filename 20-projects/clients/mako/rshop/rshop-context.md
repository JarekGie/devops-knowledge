---
title: rshop-context
client: mako
project: rshop
domain: client-work
document_type: runtime-context
context_type: cloud-detective-snapshot
classification: internal
source_of_truth: false
runtime_snapshot: true
aws_profile: rshop
account_id: "943111679945"
regions:
  - eu-central-1
extra_regions:
  - us-east-1
iac: cloudformation
repository: "~/projekty/mako/aws-projects/infra-rshop"
created: "2026-05-01"
updated: "2026-05-01"
last_verified: "2026-05-01"
tags:
  - aws
  - cloudformation
  - mako
  - rshop
---

# rshop — Platforma e-commerce Renault/Dacia

#aws #cloudformation #ecs #fargate #mako #rshop

**Data:** 2026-05-01
**Typ dokumentu:** snapshot runtime / context wejściowy
**Source of truth:** AWS live + IaC (infra-rshop) + CloudFormation stacki
**Tryb skanowania:** read-only
**Poziom pewności snapshotu:** częściowa — prod potwierdzony live AWS; dev zablokowany (rollback); repo prod (rshop-cloudformation) niezaładowany
**Projekt:** Wielorynkowa platforma e-commerce Renault i Dacia, obsługująca PL/CZ/SK/HU/LT/LV/EE; dwie marki jako osobne frontend-svc w jednym klastrze ECS
**Account ID:** 943111679945
**IAM principal (sesja):** OrganizationAccountAccessRole (dostęp przez org management account)
**IAM principal (CI/CD):** `jenkinsit` IAM user
**AWS profile:** `rshop`
**Region główny:** `eu-central-1`
**Region dodatkowy:** `us-east-1` (certyfikaty ACM dla CloudFront)

---

## Repozytorium kodu

- lokalna ścieżka: `~/projekty/mako/aws-projects/infra-rshop`
- remote: `git@gitlab.makolab.net:admin-makolab/dc/aws-projects/infra-rshop.git`
- aktywny branch: `main`
- IaC: **CloudFormation**
- Ostatni commit: `2103f04 aktualizacja ecs tags`

**Uwaga:** Repo `infra-rshop` zawiera templates dla środowiska dev i akcesoria2-prod.
Środowisko prod (`prod-*` stacki) jest zarządzane z osobnego repo: `rshop-cloudformation` — lokalna ścieżka nieznana. Templates obu środowisk są publikowane do S3 bucket `rshop-cf` przed deployem CFN.

---

## Środowiska

| Env | Region | Account ID | CFN Root Status | ECS | ALB | Pewność |
|-----|--------|------------|-----------------|-----|-----|---------|
| prod | eu-central-1 | 943111679945 | UPDATE_COMPLETE (2026-04-30) | 4 svc ACTIVE | prod-ALB active | wysoka |
| dev | eu-central-1 | 943111679945 | **UPDATE_ROLLBACK_COMPLETE (2026-04-28)** | 4 svc ACTIVE | dev-ALB active | wysoka |
| akcesoria2-prod | eu-central-1 | 943111679945 | UPDATE_COMPLETE (2026-04-24) | 2 svc ACTIVE | prod-ALB (shared) | wysoka |
| qa | eu-central-1 | 943111679945 | nieznany — brak stacka | brak klastra | nieznany | niska |
| uat | eu-central-1 | 943111679945 | nieznany — brak stacka | brak klastra | nieznany | niska |

---

## Architektura

```text
Internet
  │
  ├── CloudFront (4 dystrybucje)
  │     ├── prod-PL (EHVSOBMPOXLM7): sklep.renault.pl, sklep.dacia.pl, bo.sklep.*
  │     │     └── origin: rshop-prod S3
  │     ├── prod-Foreign (ET4SVT8DC9P9M): eshop.*.cz, .sk, webshop.*.hu
  │     │     └── origin: rshop-prod S3
  │     ├── dev-LT/LV/EE (E12KV5NOV0I551): dev.eshop*.lt/lv/ee
  │     │     └── origin: dev-ALB
  │     └── dev-other (E3LC30816FMUSK): dev.eshop*.cz/sk/pl, dev.webshop*.hu
  │           └── origin: dev-ALB (wymaga potwierdzenia)
  │
  ├── prod-ALB (internet-facing, active)
  │     ├── prod-frontend-ALB-TG → rshop-prod-Klaster/rshop-prod-frontend-svc1 (Renault, port 3000)
  │     ├── prod-frontend2-ALB-TG → rshop-prod-Klaster/rshop-prod-frontend-svc2 (Dacia, port 3000)
  │     ├── prod-api-ALB-TG1 → rshop-prod-Klaster/rshop-prod-api-svc (port 8080)
  │     ├── prod-backoffice-ALB-TG1 → rshop-prod-Klaster/rshop-prod-backoffice-svc (port 8080)
  │     ├── akcesoria2-prod-dacia-TG → akcesoria2-prod-Klaster/akcesoria2-prod-dacia-svc (port 3000)
  │     └── akcesoria2-prod-renault-TG → akcesoria2-prod-Klaster/akcesoria2-prod-renault-svc (port 3000)
  │
  └── dev-ALB (internet-facing, active)
        ├── dev-frontend-ALB-TG → rshop-dev-Klaster/rshop-dev-frontend-svc1 (Renault)
        ├── dev-frontend2-ALB-TG → rshop-dev-Klaster/rshop-dev-frontend-svc2 (Dacia)
        ├── dev-api-ALB-TG → rshop-dev-Klaster/rshop-dev-api-svc
        └── dev-backoffice-ALB-TG → rshop-dev-Klaster/rshop-dev-backoffice-svc

ECS Fargate → RDS SQL Server (eu-central-1)
  ├── prod: sqlserver-web, db.t3.large, 20GB, no MultiAZ
  └── dev: sqlserver-ex (Express Edition!), db.t3.small, 20GB, no MultiAZ

S3 (static assets)
  ├── rshop-prod → prod CloudFront origin
  └── rshop-dev → dev
```

---

## ECS / runtime config

### rshop-prod-Klaster

| Serwis | Desired | Running | Pending | Task Definition | Port | Status |
|--------|---------|---------|---------|-----------------|------|--------|
| rshop-prod-api-svc | 1 | 1 | 0 | prod-api-task:391 | 8080 | ACTIVE |
| rshop-prod-backoffice-svc | 1 | 1 | 0 | prod-backoffice-task:392 | 8080 | ACTIVE |
| rshop-prod-frontend-svc1 (Renault) | 1 | 1 | 0 | prod-frontend-task:960 | 3000 | ACTIVE |
| rshop-prod-frontend-svc2 (Dacia) | 1 | 1 | 0 | prod-frontend-task:961 | 3000 | ACTIVE |

### rshop-dev-Klaster

| Serwis | Desired | Running | Pending | Status |
|--------|---------|---------|---------|--------|
| rshop-dev-api-svc | 1 | 1 | 0 | ACTIVE |
| rshop-dev-backoffice-svc | 1 | 1 | 0 | ACTIVE |
| rshop-dev-frontend-svc1 (Renault) | 1 | 1 | 0 | ACTIVE |
| rshop-dev-frontend-svc2 (Dacia) | 1 | 1 | 0 | ACTIVE |

### akcesoria2-prod-Klaster

| Serwis | Desired | Running | Pending | Status |
|--------|---------|---------|---------|--------|
| akcesoria2-prod-dacia-svc | 1 | 1 | 0 | ACTIVE |
| akcesoria2-prod-renault-svc | 1 | 1 | 0 | ACTIVE |

**Uwaga:** Dev ECSStack (`dev-ECSStack-1BLAWHL0P6JKO`) był aktualizowany 2026-04-30 — po tym jak root `dev` stack wpadł w UPDATE_ROLLBACK_COMPLETE (2026-04-28). ECS jest deployowany poza root stack orchestration.

---

## ECR repozytoria

| Repozytorium | URI | Aktywne środowisko |
|--------------|-----|--------------------|
| rshopapp-prod | 943111679945.dkr.ecr.eu-central-1.amazonaws.com/rshopapp-prod | prod |
| rshopapp-dev | 943111679945.dkr.ecr.eu-central-1.amazonaws.com/rshopapp-dev | dev |
| rshopapp-qa | 943111679945.dkr.ecr.eu-central-1.amazonaws.com/rshopapp-qa | brak klastra/stosu |
| rshopapp-uat | 943111679945.dkr.ecr.eu-central-1.amazonaws.com/rshopapp-uat | brak klastra/stosu |
| akcesoria2-prod | 943111679945.dkr.ecr.eu-central-1.amazonaws.com/akcesoria2-prod | akcesoria2-prod |

---

## CloudFormation — struktura stacków

### prod (root: `prod`)

Nested stacks: VPCStack, SGStack, IAMStack, DBStack, ECSStack, S3Stack, CFStack, ALBStack
Templates na S3: `https://rshop-cf.s3.eu-central-1.amazonaws.com/*.yml`
IaC lokalne: `cloudformation/root.yml` + `cloudformation/*.yml` (prawdopodobnie kopia; source of truth = rshop-cloudformation repo)

### dev (root: `dev`)

Nested stacks: VPCStack, SGStack, EndPiontsStack, IAMStack, ALBStack, DBStack (conditional), ECSStack, S3Stack, CFStack
Templates na S3: `https://rshop-cf.s3.eu-central-1.amazonaws.com/dev/*.yml`
IaC lokalne: `cloudformation/dev/root-dev.yml` + `cloudformation/dev/*.yml`
**Status: UPDATE_ROLLBACK_COMPLETE — zablokowany od 2026-04-28**

### akcesoria2-prod (root: `akcesoria2-prod`)

Nested stacks: ECRStack, IAMStack, SGStack, ECSStack, SVCStack
IaC lokalne: `cloudformation/akcesoria2/`

---

## Zasoby kluczowe

| Zasób | Identyfikator | Źródło | Pewność |
|-------|---------------|--------|---------|
| Account ID | 943111679945 | live AWS | wysoka |
| prod-ALB | prod-ALB-1431454853.eu-central-1.elb.amazonaws.com | live AWS | wysoka |
| dev-ALB | dev-ALB-2024598218.eu-central-1.elb.amazonaws.com | live AWS | wysoka |
| prod VPC | vpc-08c5016cee20ad2ae, CIDR 10.0.0.0/16 | live AWS | wysoka |
| dev VPC | vpc-0befdfd9f1b71ebf6, CIDR 10.0.0.0/16 | live AWS | wysoka |
| RDS prod | pssa61v1phykq0, sqlserver-web, db.t3.large | live AWS | wysoka |
| RDS dev | dev-dbstack-ez6jh7wsba94-sqldatabase-t5q3rgolza5p, sqlserver-ex, db.t3.small | live AWS | wysoka |
| CloudFront prod-PL | EHVSOBMPOXLM7 | live AWS | wysoka |
| CloudFront prod-Foreign | ET4SVT8DC9P9M | live AWS | wysoka |
| CloudFront dev-LT/LV/EE | E12KV5NOV0I551 | live AWS | wysoka |
| CloudFront dev-other | E3LC30816FMUSK | live AWS | wysoka |
| rshop-cf S3 bucket | rshop-cf | live AWS | wysoka |
| Template S3 | rshop-cf.s3.eu-central-1.amazonaws.com | IaC | wysoka |

---

## VPC / Sieć

| VPC | CIDR | Tag | ID |
|-----|------|-----|----|
| prod | 10.0.0.0/16 | rshop-prod-VPC | vpc-08c5016cee20ad2ae |
| dev | 10.0.0.0/16 | rshop-dev-VPC | vpc-0befdfd9f1b71ebf6 |
| default | 172.31.0.0/16 | cos_dev | vpc-0f46b727b63c49da3 |

Oba środowiska mają identyczny CIDR (10.0.0.0/16) — brak VPC peering, brak konfliktu.
Default VPC otagowany jako "cos_dev" — przeznaczenie wymaga potwierdzenia.

VPC endpoints (dev): EndPiontsStack wdrożony (UPDATE_COMPLETE 2026-04-18).

---

## S3 Buckets

| Bucket | Cel | Uwagi |
|--------|-----|-------|
| rshop-cf | CloudFormation templates | source of truth dla CFN deployów |
| rshop-prod | Statyczne assety prod | CloudFront origin |
| rshop-dev | Statyczne assety dev | dev CloudFront / ALB |
| rshop-dev-backup | Backup dev | cel wymaga potwierdzenia |
| rshop-dev-bk | Backup dev | duplikat? |
| rshopp-logs | Logi | typo w nazwie (rshopp zamiast rshop) |
| rshop-temp | Tymczasowy | do usunięcia? |
| rshop-tmp | Tymczasowy | do usunięcia? |
| 943111679945-terraform-state-bucket | Terraform state | skąd Terraform w projekcie CFN? |
| terraform-states-rshop | Terraform state | drugi bucket — duplikat? |

---

## ACM Certyfikaty

Certyfikaty są w `us-east-1` (wymagane przez CloudFront).

| ARN | Środowisko | Zakres |
|-----|-----------|--------|
| ...certificate/9405d596 | prod-PL CF | sklep.renault.pl, sklep.dacia.pl |
| ...certificate/87c23dae | prod-Foreign CF | CZ, SK, HU (Foreign) |
| ...certificate/173ae59f | prod-Foreign2 CF | CZ, SK, HU (Foreign2) |
| ...certificate/3be77743 | dev CF | dev.eshop*.pl/cz/sk/hu |
| ...certificate/74a3fdc8 | dev-Foreign2 CF | dev.eshop*.lt/lv/ee |

Status certyfikatów nieweryfikowany live (eu-central-1 ACM call zwróciła brak wyników; certyfikaty są w us-east-1).

---

## Secrets Manager

Brak sekretów w eu-central-1 (CLI zwróciła pusty output). Sekrety mogą być przechowywane inaczej (SSM Parameter Store, hardcoded w parametrach CFN, Jenkins credentials). Wymaga weryfikacji.

---

## Observability

**Runtime health (live, 2026-05-01):**

| Element | Status | Uwagi |
|---------|--------|-------|
| prod ECS — wszystkie serwisy | 1/1 running, ACTIVE | potwierdzono live |
| dev ECS — wszystkie serwisy | 1/1 running, ACTIVE | potwierdzono live |
| akcesoria2-prod ECS | 1/1 running, ACTIVE | potwierdzono live |
| prod-ALB | active | internet-facing |
| dev-ALB | active | internet-facing |
| prod RDS | available | sqlserver-web, db.t3.large |
| dev RDS | available | sqlserver-ex, db.t3.small |

**CloudWatch alarms:** BRAK — describe-alarms zwróciła pusty output.

**Log groups:**

| Log group | Retencja | Uwagi |
|-----------|----------|-------|
| /ecs/rshop-prod | 1 dzień | produkcja — krytycznie niska retencja |
| /ecs/rshop-dev | 1 dzień | |
| /ecs/akcesoria2/prod | 14 dni | jedyny z wystarczającą retencją |
| /ecs/api | 1 dzień | nazwa bez środowiska — niejednoznaczna |
| /esc/backoffice | 1 dzień | **typo: /esc/ zamiast /ecs/** |
| /ecs/Rshop-frontend | 1 dzień | wielka litera w nazwie — niespójna konwencja |
| /ecs/jumphost-dev | 7 dni | |
| /ecs/jumphost-prod | 7 dni | |
| /ecs/jumphost | 1 dzień | |
| /ecs/jumhost-qa | 1 dzień | **typo: jumhost zamiast jumphost** |
| /ecs/nmap | 1 dzień | artefakt diagnostyczny |
| /aws/ecs/containerinsights/rshop-prod-Klaster/performance | 1 dzień | Container Insights |
| /aws/ecs/containerinsights/rshop-qa-Klaster/performance | 1 dzień | QA klaster nie istnieje — orphaned |
| RDSOSMetrics | 1 dzień | |

---

## Znane problemy / dług techniczny

🔥 **CRITICAL**:

| Problem | Priorytet | Evidence | Opis |
|---------|-----------|----------|------|
| dev stack zablokowany | 🔥 CRITICAL | CFN event: `jenkinsit not authorized to perform rds:ModifyDBSubnetGroup` | Brak `rds:ModifyDBSubnetGroup` w polityce `jenkinsit` IAM user; dev-VPCStack, dev-IAMStack, dev-S3Stack w UPDATE_ROLLBACK_COMPLETE od 2026-04-28; pełne aktualizacje infra dev niemożliwe przez CFN root |
| Brak CloudWatch alarms | 🔥 CRITICAL | describe-alarms: pusty output | Zero alertingu; każda awaria wykrywana przez użytkowników |

**WYSOKI:**

| Problem | Priorytet | Evidence | Opis |
|---------|-----------|----------|------|
| 1-dniowa retencja logów prod | WYSOKI | describe-log-groups | Niemożliwe dochodzenie incydentów starszych niż 24h |
| Brak MultiAZ RDS | WYSOKI | describe-db-instances: MultiAZ=False | Prod i dev RDS bez MultiAZ — single point of failure |
| Dev ECS deployowany poza root stack | WYSOKI | ECSStack UPDATE_COMPLETE 2026-04-30, root UPDATE_ROLLBACK_COMPLETE 2026-04-28 | Brak orchestracji przez CFN root; drift między stanem infra a IaC |

**ŚREDNI:**

| Problem | Priorytet | Evidence | Opis |
|---------|-----------|----------|------|
| Dwa Terraform state buckets | ŚREDNI | live AWS | 943111679945-terraform-state-bucket, terraform-states-rshop — po co Terraform w projekcie CFN? |
| Sierota: rshop-qa log group | ŚREDNI | /aws/ecs/containerinsights/rshop-qa-Klaster/performance | QA klaster nie istnieje, log group pozostała |
| Log group typos | ŚREDNI | /esc/backoffice, /ecs/jumhost-qa | Błędne ścieżki mogą pominąć logi |
| Temp S3 buckets | ŚREDNI | rshop-temp, rshop-tmp | Niezdefiniowany cel; potencjalnie opuszczone |
| RDS dev drift: sqlserver-ex vs IaC sqlserver-ee | ŚREDNI | IaC root-dev.yml default: sqlserver-ee; live: sqlserver-ex | Express Edition ma limit 10GB RAM, 1 CPU, 10GB DB; potencjalna niezgodność z prod |

**INFO:**

| Problem | Priorytet | Evidence | Opis |
|---------|-----------|----------|------|
| ECR qa/uat bez środowiska | INFO | ECR repos: rshopapp-qa, rshopapp-uat | Repozytoria istnieją, klastry nie |
| Default VPC otagowany "cos_dev" | INFO | VPC tag: cos_dev | Co to jest cos_dev? |
| Sekrety — metoda przechowywania nieznana | INFO | SM: brak sekretów | Możliwy SSM, Jenkins, lub CFN parametry |

---

## Tagging (governance / FinOps)

Szczegółowy audit tagów: `[[rshop-tagging-baseline-2026-04-24]]`
Remediacja: `[[rshop-tagging-remediation-2026-04-24]]`

Prod CFN templates mają tagi: `Project`, `Environment`, `Owner=DC-devops`, `ManagedBy=cloudformation`, `CostCenter=DC`.
Dev CFN templates (root-dev.yml) — brak jawnych tagów na nested stackach (wymagają sprawdzenia).

Znany problem z przeszłości: `apply-pack tagging` ustawiał `Project=infra-rshop` zamiast `rshop`.

---

## Różnice IaC vs Runtime

| Obszar | IaC | Runtime AWS | Ocena |
|--------|-----|-------------|-------|
| RDS dev engine | sqlserver-ee (default w root-dev.yml) | sqlserver-ex | rozbieżność |
| Dev ECS deployment | zarządzany przez CFN root | deployowany bezpośrednio (poza root stack) | rozbieżność |
| Dev root stack | powinien być UP_TO_DATE | UPDATE_ROLLBACK_COMPLETE | rozbieżność |
| Prod templates | lokalne w infra-rshop | źródło: rshop-cloudformation repo | wymaga potwierdzenia |
| dev S3Stack | UPDATE_ROLLBACK_COMPLETE | bucket rshop-dev istnieje | niezgodność CFN state vs resource |

---

## Pewność ustaleń

| Obszar | Pewność | Evidence |
|--------|---------|----------|
| Account ID, IAM principal | wysoka | sts get-caller-identity |
| ECS cluster/service state | wysoka | describe-clusters + describe-services |
| ALB state | wysoka | describe-load-balancers |
| RDS state | wysoka | describe-db-instances |
| CloudFront distributions | wysoka | list-distributions |
| CFN stack statuses | wysoka | list-stacks |
| Dev stack root cause | wysoka | stack-events: AccessDenied na rds:ModifyDBSubnetGroup |
| VPC/sieć | wysoka | describe-vpcs |
| S3 buckets | wysoka | list-buckets |
| ECR repos | wysoka | describe-repositories |
| Log groups/retencja | wysoka | describe-log-groups |
| CloudWatch alarms | wysoka — brak zdefiniowanych | describe-alarms: empty |
| Sekrety | niska | SM empty; możliwy SSM/Jenkins |
| ACM cert status | niska | wywołanie w eu-central-1; certy w us-east-1 |
| Prod CFN templates (rshop-cloudformation) | niska | repo nie załadowane |
| Routing ALB → usługi (reguły listenerów) | średnia | TG potwierdzone, reguły nie sprawdzone |
| Target health (faktyczny) | średnia | HealthyCount=threshold, nie actual healthy |

---

## Dostęp diagnostyczny

```bash
# ECS task health — prod
aws ecs describe-services --cluster rshop-prod-Klaster \
  --services rshop-prod-api-svc rshop-prod-backoffice-svc rshop-prod-frontend-svc1 rshop-prod-frontend-svc2 \
  --profile rshop --region eu-central-1

# Zatrzymane taski (diagnoza crashu)
aws ecs list-tasks --cluster rshop-prod-Klaster --desired-status STOPPED \
  --profile rshop --region eu-central-1

# ALB target health — prod
# najpierw pobierz TG ARN, potem:
aws elbv2 describe-target-health --target-group-arn <arn> \
  --profile rshop --region eu-central-1

# Dev stack rollback events
aws cloudformation describe-stack-events --stack-name dev \
  --profile rshop --region eu-central-1 \
  --query 'StackEvents[?ResourceStatus==`UPDATE_FAILED`].[ResourceType,LogicalResourceId,ResourceStatusReason]'

# VPCStack failure root cause (Jenkins IAM)
aws cloudformation describe-stack-events \
  --stack-name dev-VPCStack-FFQTYHECIX9M \
  --profile rshop --region eu-central-1 \
  --query 'StackEvents[?ResourceStatus==`UPDATE_FAILED`].[LogicalResourceId,ResourceStatusReason]'
```

---

## Powiązane

- [[rshop-tagging-baseline-2026-04-24]]
- [[rshop-tagging-remediation-2026-04-24]]
- [[vpc-endpoints-tagging-audit-2026-04-24]]
- [[finops-rshop]]
