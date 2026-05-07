---
title: drp-tfs-context
client: mako
project: drp-tfs
domain: client-work
document_type: runtime-context
context_type: cloud-detective-snapshot
classification: internal
source_of_truth: false
runtime_snapshot: true
aws_profile: drp-tfs
account_id: "613448424242"
regions:
  - eu-central-1
iac: terraform
repository: "/Users/jaroslaw.golab/projekty/mako/drp_tfs + /Users/jaroslaw.golab/projekty/mako/dc-terraform/terraform-aws/environments/drp-tfs"
created: "2026-05-07"
updated: "2026-05-07"
last_verified: "2026-05-07"
scan_method: cloud-detective-v2
last_verified_by: codex
tags:
  - aws
  - terraform
  - eks
  - kubernetes
  - mako
  - drp-tfs
---

# drp-tfs — runtime context

#aws #terraform #eks #kubernetes #mako #drp-tfs

**Data:** 2026-05-07  
**Typ dokumentu:** snapshot runtime / context wejściowy  
**Source of truth:** AWS live + Kubernetes live + IaC + Terraform state  
**Tryb skanowania:** read-only  
**Poziom pewności snapshotu:** częściowa  
**Projekt:** DRP środowiska TFS/Toyota Finance Services na AWS EKS, z MongoDB na EC2 i aplikacją wdrożoną przez Helm/Kubernetes.  
**OrgAccountID:** nieustalone w bieżącym skanie  
**Account ID:** `613448424242`  
**Role:** nieustalone  
**AWS profile:** `drp-tfs`  
**IAM principal:** `aws_cli`  
**Region główny:** `eu-central-1`

---

## Snapshot metadata

| Pole | Wartość |
|------|---------|
| scan_date | 2026-05-07 |
| scan_scope | partial |
| regions_checked | eu-central-1 |
| repo_checked | tak, dwa repo/source paths |
| iac_checked | częściowo, Terraform + Helm manifests |
| runtime_checked | częściowo, AWS + Kubernetes read-only |
| extra_regions_checked | us-east-1 ACM checked ad hoc; brak certyfikatów |

---

## Zakres snapshotu vs audytu

| Obszar | Typ | Zakres | Źródło |
|--------|-----|--------|--------|
| Runtime health EKS/Kubernetes | snapshot | EKS cluster, nodes, deployments, pods, services, ingress | live AWS + Kubernetes |
| AWS runtime | snapshot | EC2, VPC, EKS, ELBv2, RDS, ElastiCache, Secrets Manager, CloudWatch, CFN, ACM, ECR, WAF, SQS, EventBridge | live AWS |
| IaC analiza | snapshot | lokalne repo `drp_tfs` + `dc-terraform/.../drp-tfs` | IaC |
| Tagging coverage | snapshot | sample-based przez `resourcegroupstaggingapi get-resources` | live AWS |
| FinOps / cost allocation | audit partial | budget modules w IaC; brak pełnej walidacji Budgets API | IaC |
| Security / WAF | gap analysis | WAF regional checked, lista pusta | live AWS |
| ACM certs | snapshot | eu-central-1 + us-east-1 | live AWS |

---

## Repozytorium kodu

IaC source of truth:
- `/Users/jaroslaw.golab/projekty/mako/drp_tfs`: aplikacja, Helm/K8s manifests, Terraform legacy/env DRP; remote `git@gitlab.makolab.net:admin-makolab/dc/drp_tfs.git`; branch `main`; lokalnie dirty: `terraform-aws/modules/mongo-ec2/playbook/group_vars/all.yml`, `terraform-aws/modules/mongo-ec2/playbook/roles/mongo/tasks/50-discovery.yml`.
- `/Users/jaroslaw.golab/projekty/mako/dc-terraform/terraform-aws/environments/drp-tfs`: Terraform dla CodeCommit / cost management; remote `git@gitlab.makolab.net:admin-makolab/dc/dc-terraform.git`; branch `main`; clean.

Manifest invocation zawiera uszkodzony `repo_path` (`�~/projekty/mako//drp-tfs`). Rzeczywisty lokalny checkout znaleziono jako `~/projekty/mako/drp_tfs`; dodatkowo istnieje środowisko Terraform w `dc-terraform`.

---

## Środowiska

| Env | Region | Account ID | Status | VPC CIDR | Pewność |
|-----|--------|------------|--------|----------|---------|
| drp / tfs-prod | eu-central-1 | 613448424242 | PARTIAL: EKS active, większość deploymentów running; aktywne problemy niżej | 172.35.0.0/23 | wysoka dla AWS/EKS, częściowa dla aplikacji |

State bucket:
- `613448424242-terraform-state-bucket`

State keys:
- `drp/terraform.tfstate` (`drp_tfs/terraform-aws/environments/DRP/backend.tf`)
- `global/terraform.tfstate` (`dc-terraform/.../drp-tfs/backend.tf`)

Lock table: `terraform-state-lock`

---

## Architektura

```text
Internet
  -> NLB a6fc56eb10f214c71bdec4b1f9d1cc67
     listeners TCP:80, 443, 1024, 6060
     -> Kubernetes Service tfs-prod/haproxy-kubernetes-ingress (LoadBalancer)
        -> Ingress tfs-prod/tfs-ingress (HAProxy)
           -> tfs-prod frontend/API NodePort services

EKS drp-tfs-eks-cluster (v1.30)
  nodegroup general: 4 x c5a.4xlarge, ON_DEMAND
  namespaces: infrastructure, tfs-prod, kube-system

Data plane:
  MongoDB replica set on EC2:
    drp-tfs-mongo-0/1/2, m6i.large, private subnets
  DB instance EC2:
    drp-tfs-db-instance, t3.2xlarge
  Redis + ActiveMQ in Kubernetes namespace infrastructure
  EFS CSI present

Access:
  drp-tfs-jumphost, t3.medium, public IP, SSH restricted to Mako VPN + named operator IP
```

Przypisanie domeny `toyota.finance.makolab.com` do ingress jest potwierdzone w Kubernetes Ingress TLS, ale publiczny LB endpoint ma aktywny problem synchronizacji (`EXTERNAL-IP <pending>`).

---

## Mikroserwisy / komponenty

ECS nie jest używany w bieżącym runtime: `aws ecs list-clusters` zwrócił pustą listę. Runtime aplikacji działa na EKS/Kubernetes.

| Serwis | Cluster | Port | Ingress | Service Discovery | ECS Exec | Desired | Running/Available | Status |
|--------|---------|------|---------|-------------------|----------|---------|-------------------|--------|
| EKS cluster | drp-tfs-eks-cluster | Kubernetes API | public endpoint `0.0.0.0/0` | Kubernetes DNS | n/d | 1 | ACTIVE | OK z ryzykiem security |
| nodegroup general | drp-tfs-eks-cluster | n/d | private nodes | n/d | n/d | 4 | 4 Ready | OK |
| haproxy-kubernetes-ingress | drp-tfs-eks-cluster | 80/443/1024/6060 | Service LoadBalancer | Kubernetes service | n/d | 2 | 2/2 | PARTIAL: LB pending |
| tfs-prod application services | drp-tfs-eks-cluster | 80/8080 | HAProxy ingress / NodePort | Kubernetes service | n/d | mixed | większość Ready | PARTIAL |
| tfs-prod-leasing-filters-api-service | drp-tfs-eks-cluster | 8080 | przez cloud-api-gateway / ingress path | Kubernetes service | n/d | 2 | 0 | CRITICAL |
| tfs-prod-leasing-filters-core-service | drp-tfs-eks-cluster | 8080 | internal service | Kubernetes service | n/d | 2 | 0 | CRITICAL |
| ActiveMQ | drp-tfs-eks-cluster | 8161/61616 | NodePort internal | Kubernetes service | n/d | 1 | 1 | OK |
| Redis failover | drp-tfs-eks-cluster | 26379 | ClusterIP | Kubernetes service | n/d | 3 | 3 | OK |

---

## Zasoby kluczowe

| Zasób | Identyfikator | Źródło | Pewność |
|-------|---------------|--------|---------|
| AWS account | 613448424242 | live AWS STS | wysoka |
| VPC | `vpc-0b925ce682aa1146a`, `172.35.0.0/23` | live AWS + IaC | wysoka |
| EKS | `drp-tfs-eks-cluster`, v1.30, ACTIVE | live AWS + Kubernetes | wysoka |
| Nodegroup | `general`, 4 x `c5a.4xlarge`, ON_DEMAND | live AWS + Kubernetes | wysoka |
| NLB | `a6fc56eb10f214c71bdec4b1f9d1cc67`, internet-facing | live AWS | wysoka |
| MongoDB EC2 | `drp-tfs-mongo-0/1/2`, `m6i.large` | live AWS + IaC | wysoka |
| Jumphost | `drp-tfs-jumphost`, `t3.medium` | live AWS + IaC | wysoka |
| DB EC2 | `drp-tfs-db-instance`, `t3.2xlarge` | live AWS + IaC | wysoka |
| ECR repos | 49 repositories under `tfs/*` + `drp-tfs-ecr` | live AWS | wysoka |
| CodeCommit | `drp-tfs` | IaC + resource tagging API | średnia |

---

## Secrets Manager

Secrets Manager: 0 sekretów w regionie `eu-central-1` (sprawdzone live).

Możliwe alternatywne źródła sekretów (częściowo zweryfikowane):
- Kubernetes Secret `tfs-prod-secret` referenced by Helm workloads (wartości nieodczytywane)
- Kubernetes ConfigMap `tfs-prod-config` (referencja potwierdzona)
- CI/CD credentials (Jenkins/CodeBuild) — niezweryfikowane
- hardcoded / manifest files — wymaga osobnego secret hygiene review

| Secret | Przeznaczenie / zawartość logiczna | Źródło |
|--------|------------------------------------|--------|
| `tfs-prod-secret` | Kubernetes Secret mount dla workloadów TFS; wartości nieodczytywane | Kubernetes metadata |

---

## ACM Certificates

| Domena | Region | Status | Uwagi |
|--------|--------|--------|-------|
| `drp-tfs-test.makotest.pl` | eu-central-1 | FAILED | nieużywany wg `InUseBy=null` |
| `*.finance.makolab.com` | eu-central-1 | EXPIRED | nieużywany wg `InUseBy=null`; TLS w Kubernetes wskazuje secret `prod-cert` |
| brak | us-east-1 | brak certyfikatów | sprawdzone live |

---

## Tagging / FinOps / LLZ / AWS WAF readiness

**Źródło historyczne:** `[[20-projects/internal/llz/nis2-aws-live-state-2026-05-04]]` i `[[20-projects/internal/llz/context]]` wspominają konto `drp-tfs`, ale bieżący plik nie duplikuje audytu LLZ.  
**Bieżący scan:** sample-based przez `resourcegroupstaggingapi get-resources`.

| Obszar | Status | Uwagi |
|--------|--------|-------|
| FinOps — cost allocation tags (Project/Environment/CostCenter) | PARTIAL | część zasobów ma `Project`/`Environment`, brak spójnego `CostCenter`; w `dc-terraform` istnieją budget modules |
| LLZ tagging standard (Project/Environment/Owner/ManagedBy/CostCenter) | PARTIAL | częste tagi: `environment`, `department`, `provisioner`; braki `Owner`, `ManagedBy`, `CostCenter`; mieszana wielkość `Environment` vs `environment` |
| ECS/Fargate — tag propagation do tasków | nie dotyczy | ECS clusters: 0; workload na EKS |
| ECR — tagi na repozytoriach | PARTIAL | ECR sprawdzony live; większość repo ma `scanOnPush=false`, tagi niezweryfikowane per repo |
| S3 — tagi na bucketach | niezweryfikowane | S3 buckets nie były listowane w tym skanie |
| CloudWatch Log Groups — tagi | niezweryfikowane | log groups sprawdzone, tagi log groups nie |
| VPC / Endpoints — tagi | PARTIAL | VPC/subnets mają `Environment`, `department`, `provisioner`, ale bez pełnego LLZ setu |
| AWS WAF — obecność i przypisanie właściciela | GAP | `wafv2 list-web-acls --scope REGIONAL` zwrócił pustą listę; brak aktywnego incydentu WAF |

### Wymagane tagi LLZ

| Tag | Oczekiwana wartość | Status |
|-----|--------------------|--------|
| Project | `drp-tfs` | częściowo obecny |
| Environment | `drp` | obecny niespójnie jako `Environment` i `environment` |
| Owner | team/e-mail | brakuje / nieustalone |
| ManagedBy | Terraform / Helm / eksctl | częściowo jako `provisioner=terraform`, brak spójnego `ManagedBy` |
| CostCenter | ID działu/projektu | brakuje / nieustalone |

### Wniosek

Zgodność governance jest częściowa: kluczowe zasoby mają tagi operacyjne, ale nie spełniają spójnie LLZ/FinOps tag setu. Brak WAF jest governance gap, nie aktywny incydent runtime.

### Następne kroki

| Akcja | Priorytet | Kto |
|-------|-----------|-----|
| Ujednolicić tagi `Project`, `Environment`, `Owner`, `ManagedBy`, `CostCenter` w Terraform/Helm | ŚREDNI | platform / project owner |
| Włączyć image scanning dla ECR repos albo udokumentować wyjątek | ŚREDNI | platform / security |
| Zweryfikować WAF-readiness dla publicznego ingress | ŚREDNI | platform / security |

---

## Scheduler / automatyzacje

| Automatyzacja | Harmonogram | Zakres | Uwagi |
|--------------|-------------|--------|-------|
| EventBridge `AutoScalingManagedRule` | event-driven | EC2 Auto Scaling interruptions/rebalance | AWS managed |
| EventBridge `DevOpsGuruManagedRuleForCodeGuruProfiler-DO_NOT_DELETE` | event-driven | CodeGuru Profiler recommendations | AWS managed |
| Runtime scheduler | nieustalone | brak wykrytych custom rules | live AWS |
| Budgets | Terraform modules | VPC/ECS/ELB/EKS daily budgets | IaC only; Budgets API niezweryfikowane |

---

## ECS / runtime config

| Parametr | Wartość |
|----------|---------|
| ECS clusters | 0 |
| Runtime orchestrator | EKS / Kubernetes |
| EKS version | 1.30 |
| Node runtime | Amazon Linux 2, containerd 1.7.29 |
| Nodegroup | `general`, 4 nodes, `c5a.4xlarge` |
| EKS endpoint | public access enabled, private access disabled |
| EKS publicAccessCidrs | `0.0.0.0/0` |
| Workload namespace | `tfs-prod` |
| Infra namespace | `infrastructure` |
| Ingress controller | HAProxy Kubernetes Ingress |
| App deploy method | Helm (`helm.sh/chart=tfs-0.1`) |

---

## Observability

**Runtime health (live, 2026-05-07):**

| Element | Status | Uwagi |
|---------|--------|-------|
| EKS cluster | ACTIVE | live AWS |
| EKS nodes | 4/4 Ready | Kubernetes live |
| Most tfs-prod deployments | OK | większość deploymentów Available |
| `tfs-prod-leasing-filters-api-service` | CRITICAL | 2 desired, 0 available, CrashLoopBackOff |
| `tfs-prod-leasing-filters-core-service` | CRITICAL | 2 desired, 0 available, CrashLoopBackOff |
| HAProxy LoadBalancer service | CRITICAL | `EXTERNAL-IP <pending>`; event: mixed protocol not supported for LoadBalancer |
| NLB listener target groups | CRITICAL | target health queries for listener TGs returned no registered targets |
| RDS / DocumentDB / ElastiCache managed services | brak | live AWS returned empty lists |

**CloudWatch alarms:**

| Alarm | Stan | Metric | Kontekst / czy aktualny? |
|-------|------|--------|--------------------------|
| brak | n/d | n/d | `describe-alarms` returned empty lists |

**Log groups:**

| Log group | Retencja | Uwagi |
|-----------|----------|-------|
| `/aws/containerinsights/drp-tfs-eks-cluster/application` | 30 | Container Insights |
| `/aws/containerinsights/drp-tfs-eks-cluster/dataplane` | 30 | Container Insights |
| `/aws/containerinsights/drp-tfs-eks-cluster/host` | 30 | Container Insights |
| `/aws/containerinsights/drp-tfs-eks-cluster/performance` | 30 | Container Insights |
| `/aws/eks/drp-tfs-eks-cluster/cluster` | 30 | log group exists, but EKS control plane logging disabled live |
| `/aws/codebuild/tfs-drp-build` | 30 | CodeBuild |
| `/aws/codebuild/tfs-drp-destroy` | 30 | CodeBuild |
| `gb-vpn`, `pl-vpn`, `uk-vpn`, `vpn` | 30 | VPN logs |

---

## Znane problemy / dług techniczny

| Problem | Priorytet | Evidence | Opis |
|---------|-----------|----------|------|
| `leasing-filters-api-service` i `leasing-filters-core-service` down | CRITICAL | Kubernetes: 2 desired, 0 available, `CrashLoopBackOff`; logs: MongoDB `REPLICA_SET_GHOST`, timeout waiting for primary | Aplikacje nie widzą zainicjowanego primary w Mongo replica set; health endpoint zwraca 503 |
| Publiczny ingress nie ma gotowego LoadBalancer endpointu | CRITICAL | Kubernetes service `haproxy-kubernetes-ingress`: `EXTERNAL-IP <pending>`; event `mixed protocol is not supported for LoadBalancer`; AWS target groups dla listenerów NLB puste | Ruch zewnętrzny przez NLB prawdopodobnie nie dochodzi do ingress; wymaga rozdzielenia TCP/UDP albo korekty service annotations/spec |
| EKS API endpoint publiczny dla `0.0.0.0/0` | WYSOKI | `resourcesVpcConfig.endpointPublicAccess=true`, `publicAccessCidrs=["0.0.0.0/0"]` | Brak ograniczenia CIDR na control plane API; nie jest awarią runtime, ale istotne ryzyko security |
| EKS control plane logging disabled | WYSOKI | `clusterLogging.enabled=false` dla api/audit/authenticator/controllerManager/scheduler | Utrudnia audyt i RCA; log group istnieje, ale konfiguracja EKS nie wysyła control plane logs |
| Brak CloudWatch alarms | WYSOKI | `describe-alarms` returned empty lists | Governance/observability gap; nie jest dowodem aktywnej awarii |
| ECR scanOnPush disabled dla większości `tfs/*` repos | ŚREDNI | `ecr describe-repositories`: większość repo `ScanOnPush=false` | Security hygiene gap; `drp-tfs-ecr` ma scanOnPush=true |
| Stare/stale target groups w wielu VPC | ŚREDNI | `describe-target-groups` pokazuje target groups w VPC innych niż aktywne `vpc-0b925...` | Prawdopodobne osierocone zasoby po poprzednich klastrach/ingressach; wymaga review przed cleanup |
| Tagging niespójny | ŚREDNI | `resourcegroupstaggingapi` sample: `environment`/`Environment`, brak pełnego LLZ setu | FinOps/LLZ gap |
| Manifest invocation ma błędny `repo_path` | NISKI | `repo_path: �~/projekty/mako//drp-tfs`; lokalnie istnieje `drp_tfs` | Może prowadzić agentów do złej ścieżki |

---

## Różnice IaC vs Runtime

| Obszar | IaC | Runtime AWS/K8s | Ocena |
|--------|-----|-----------------|-------|
| EKS version | `1.30` | `1.30` | zgodne |
| Nodegroup size | desired/min/max 4 | 4 Ready nodes | zgodne |
| Node AMI type | `drp.tfvars` wskazuje `AL2023_X86_64_STANDARD`, `main.tf` przekazuje module defaults/`AL2_x86_64` live | rozbieżność / wymaga review |
| Mongo EC2 | 3 nodes, `m6i.large`, Route53 `drp.internal` | 3 running EC2, aplikacja widzi `REPLICA_SET_GHOST` | runtime problem |
| Ingress LoadBalancer | Helm service LoadBalancer z mixed TCP+UDP 443 | sync failure: mixed protocol not supported | rozbieżność / runtime problem |
| ECS | cost module ma ECS budget | ECS clusters 0 | naming/legacy budget, nie runtime ECS |
| Secrets | AWS Secrets Manager nieużywany | Kubernetes Secret referenced | zgodne z K8s pattern, ale secret source wymaga hygiene review |

---

## Drift / niespójności architektury

| Obszar | Typ driftu | Źródło | Opis |
|--------|-----------|--------|------|
| NLB target groups | IaC vs runtime / unknown | live AWS + K8s | Aktywny NLB ma listenery do target groups bez targetów; K8s LoadBalancer service pending |
| Mongo replica set | runtime | Kubernetes logs + EC2 live | Mongo hosts reachable, ale jako `REPLICA_SET_GHOST`; brak primary widocznego dla app |
| Multi-repo IaC | multi-repo | lokalny filesystem | `drp_tfs` i `dc-terraform/.../drp-tfs` zarządzają różnymi częściami projektu |
| Tagging | governance drift | live AWS | Mieszane tag keys i brak pełnego LLZ setu |
| Security groups `launch-wizard-*` | unknown/manual change | live AWS | SG bez tagów z publicznym 22/80/ICMP; niepowiązanie z workloadem nieustalone |

---

## Pewność ustaleń

| Obszar | Pewność | Evidence | Uwagi |
|--------|---------|----------|-------|
| Account/region | wysoka | STS + region commands | konto 613448424242 |
| EKS/Kubernetes runtime | wysoka | `aws eks describe-*`, `kubectl get/describe` | read-only, bez zmian |
| ECS absence | wysoka | `aws ecs list-clusters` empty | ECS budget w IaC nie oznacza runtime ECS |
| Managed DB absence | wysoka | RDS/DocDB/ElastiCache describe empty | Mongo działa na EC2/K8s Redis |
| CloudFront absence | wysoka | `cloudfront list-distributions` null | brak distributions |
| IaC completeness | częściowa | lokalne pliki bez `terraform plan` | nie uruchamiano planu zgodnie z template |
| Tagging | częściowa | sample-based API | pełny tagging audit osobno |
| Root cause leasing filters | średnia | logi Mongo timeout + REPLICA_SET_GHOST | wymaga sprawdzenia Mongo replica set na hostach |

---

## Dostęp diagnostyczny

```bash
# Diagnoza: AWS identity
aws sts get-caller-identity --profile drp-tfs --region eu-central-1

# Diagnoza: EKS health
aws eks describe-cluster --name drp-tfs-eks-cluster \
  --profile drp-tfs --region eu-central-1

AWS_PROFILE=drp-tfs kubectl get nodes -o wide
AWS_PROFILE=drp-tfs kubectl get deployments -n tfs-prod
AWS_PROFILE=drp-tfs kubectl get pods -n tfs-prod

# Diagnoza: leasing filters crash
AWS_PROFILE=drp-tfs kubectl describe deployment -n tfs-prod tfs-prod-leasing-filters-api-service
AWS_PROFILE=drp-tfs kubectl describe deployment -n tfs-prod tfs-prod-leasing-filters-core-service
AWS_PROFILE=drp-tfs kubectl logs -n tfs-prod deploy/tfs-prod-leasing-filters-api-service --tail=100
AWS_PROFILE=drp-tfs kubectl logs -n tfs-prod deploy/tfs-prod-leasing-filters-core-service --tail=100

# Diagnoza: LoadBalancer pending
AWS_PROFILE=drp-tfs kubectl describe service -n tfs-prod haproxy-kubernetes-ingress
aws elbv2 describe-listeners --load-balancer-arn <nlb-arn> \
  --profile drp-tfs --region eu-central-1
aws elbv2 describe-target-health --target-group-arn <tg-arn> \
  --profile drp-tfs --region eu-central-1
```

```bash
# OPCJONALNE — tylko po świadomej decyzji operatora.
# NIE jest częścią automatycznego cloud-detective read-only scan.
terraform plan -refresh=false
```

---

## Aktualizacja dokumentacji po zmianach IaC

Nigdy nie łącz `terraform apply` z generowaniem dokumentacji — to dwa osobne kroki.

```bash
terraform apply
# osobno, po apply:
# uruchom ponownie cloud-detective przez plik invocation
```

---

## Źródła użyte

| Źródło | Zakres | Status |
|--------|--------|--------|
| live AWS | STS, EC2, EKS, ECS, ELBv2, RDS, DocDB, ElastiCache, Secrets Manager, CloudFormation, CloudWatch, Logs, ACM, CloudFront, ECR, SQS, EventBridge, Service Discovery, WAF, Resource Groups Tagging API | sprawdzone częściowo |
| Kubernetes live | nodes, namespaces, deployments, services, pods, ingress, describe service/deployments, selected logs | sprawdzone częściowo |
| repo lokalne | `/Users/jaroslaw.golab/projekty/mako/drp_tfs` | sprawdzone częściowo |
| repo lokalne | `/Users/jaroslaw.golab/projekty/mako/dc-terraform/terraform-aws/environments/drp-tfs` | sprawdzone częściowo |
| IaC | Terraform backend/main/locals/tfvars, Helm/K8s manifests by file index | sprawdzone częściowo |
| CFN stacks | AWS Config StackSet instance, eksctl CloudWatch agent serviceaccount stack | sprawdzone |
| vault historyczny | LLZ notes references only | użyte minimalnie |
| extra_regions | us-east-1 ACM only | sprawdzone |

## Fakty live vs historia vault

| Informacja | Status | Źródło | Uwagi |
|------------|--------|--------|-------|
| Account `613448424242` | live | STS | principal `aws_cli` |
| EKS `drp-tfs-eks-cluster` ACTIVE | live | AWS EKS | v1.30 |
| Leasing filters down | live | Kubernetes + logs | active CrashLoopBackOff |
| LoadBalancer pending | live | Kubernetes service event + ELB target health | active issue |
| Brak AWS Secrets Manager secrets | live | AWS Secrets Manager | region eu-central-1 |
| Konto drp-tfs w LLZ | historyczna | `20-projects/internal/llz/*` | użyte tylko jako kontekst organizacyjny |

---

## Self-check przed zapisem

- [x] Oznaczono źródła kluczowych informacji.
- [x] Oddzielono fakty live od danych historycznych.
- [x] CRITICAL użyto tylko dla aktywnego impactu potwierdzonego live.
- [x] "Brak" użyto tam, gdzie komenda zwróciła pusty wynik.
- [x] `us-east-1` sprawdzono dla ACM tylko jako zakres pomocniczy.
- [x] Secrets Manager pusty opisany z fallback sources.
- [x] Przypisania ingress/LB opisane z evidence i ograniczeniami.
- [x] CFN `UPDATE_ROLLBACK_COMPLETE` nie wystąpił.
- [x] Multi-repo opisane.
- [x] Snapshot metadata uzupełnione.
- [x] Źródła użyte i fakty live vs historia vault uzupełnione.
- [x] Tagging / FinOps / LLZ / WAF readiness ma statusy.
- [x] Brak WAF opisany jako GAP, nie runtime incident.
- [x] ACM sprawdzono w `eu-central-1` i `us-east-1`.
- [x] Frontmatter zawiera `scan_method: cloud-detective-v2` i `last_verified_by`.
- [x] Nie uruchomiono `terraform apply`, `destroy`, `update`, `delete`.

---

## Powiązane

- [[20-projects/internal/llz/nis2-aws-live-state-2026-05-04]]
- [[20-projects/internal/llz/context]]
- [[50-patterns/prompts/invocations/cloud-detective-drp-tfs]]
