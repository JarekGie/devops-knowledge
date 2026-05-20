# Context Pack — Puzzler B2B (PBMS) — pełny kontekst projektowy

> Wklej całość na początku rozmowy z ChatGPT.
> Dane wejściowe: live AWS scan 2026-05-01 + IaC scan 2026-05-06 + main branch 2026-05-06.
> **Snapshot — weryfikuj live przed działaniem.**

**Projekt:** Puzzler B2B / PBMS (Puzzler B2B Management System)
**Klient:** MakoLab
**Data przygotowania:** 2026-05-20
**Ostatni live scan:** 2026-05-01 (credentials expired 2026-05-05)

---

## Kim jestem / kontekst roli

Senior DevOps/SRE. Zarządzam infrastrukturą AWS klienta. AWS multi-account (Organizations), Terraform >= 1.5.0, ECS Fargate. Projekt mikroserwisowy (.NET) na AWS.

---

## Projekt — overview

PBMS to mikroserwisowa aplikacja .NET wdrożona na ECS Fargate. Środowiska dev i QA aktywne, UAT i prod — tylko IaC templates (niezweryfikowane live). Główne komponenty: API Gateway, Core, Delivery, Notifier, Frontend, Builder, Sync, Worker, Jumphost (SSH tunnel do DocumentDB).

---

## Identyfikatory AWS

```
AWS profile:    puzzler-pbms
Account ID:     698220459519
Region:         eu-west-2
IAM principal:  makolab-ci (IAM user)
```

**Uwaga:** Credentials `puzzler-pbms` były expired 2026-05-05. Zawsze zacznij od:
```bash
aws sts get-caller-identity --profile puzzler-pbms
```

---

## IaC

```
Repo lokalne:   ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
Remote GitLab:  git@gitlab.makolab.net:admin-makolab/dc/aws-projects/infra-pbms.git
Branch:         main (clean 2026-05-06)
IaC tool:       Terraform >= 1.5.0
State backend:  S3 698220459519-terraform-state (eu-central-1) + DynamoDB lock
```

State keys: `infra-puzzler-b2b/{dev,qa,uat,prod}/terraform.tfstate`

---

## Środowiska

| Env | VPC CIDR    | Status                          |
|-----|-------------|---------------------------------|
| dev | 10.0.0.0/16 | aktywny — live verified         |
| qa  | 10.1.0.0/16 | aktywny — live verified         |
| uat | 10.2.0.0/16 | tylko IaC template              |
| prod| 10.3.0.0/16 | tylko IaC template              |

Wszystkie środowiska w tym samym koncie (`698220459519`).

---

## Architektura

```
Internet
  ├── CloudFront E2UE2U5RBCIYKZ → ALB dev (brak custom domain/CNAME)
  ├── ALB dev: infra-puzzler-b2b-dev-puzzler-1365062480.eu-west-2.elb.amazonaws.com
  └── ALB QA:  infra-puzzler-b2b-qa-puzzler-495374675.eu-west-2.elb.amazonaws.com
       (QA — brak CloudFront, tylko ALB)

ECS Cluster dev: infra-puzzler-b2b-dev-puzzler
ECS Cluster QA:  infra-puzzler-b2b-qa-puzzler
```

### Serwisy ECS (dev / QA — stan 2026-05-01)

| Serwis      | dev     | QA      | Uwagi                              |
|-------------|---------|---------|-------------------------------------|
| gateway     | 0/0 ⏸   | 0/0 ⏸   | scheduler: start 07:00 stop 19:00  |
| core        | 0/0 ⏸   | 0/0 ⏸   | jw.                                |
| delivery    | 0/0 ⏸   | 0/0 ⏸   | jw.                                |
| notifier    | 0/0 ⏸   | 0/0 ⏸   | jw.                                |
| front       | 1/1 ✓   | 1/1 ✓   | ALB TG port 3000                   |
| builder     | 1/1 ✓   | 1/1 ✓   | Cloud Map                          |
| sync        | 1/1 ✓   | 1/1 ✓   | Cloud Map                          |
| jumphost    | 1/1 ✓   | 0/1 ⚠   | QA: ECR image missing              |
| worker      | 0/0     | 0/0     | desired:0 permanentnie (intentional?) |

**Scheduler:** AppAutoScaling ScheduledAction (nie EventBridge). 16 akcji potwierdzonych live. Wzorzec: MON-FRI 07:00/19:00 Europe/Warsaw.

---

## Database

```
DocumentDB dev: infra-puzzler-b2b-dev-puzzler-mongo.cluster-c1moyqeoccm2.eu-west-2.docdb.amazonaws.com:27017
DocumentDB QA:  infra-puzzler-b2b-qa-puzzler-mongo.cluster-c1moyqeoccm2.eu-west-2.docdb.amazonaws.com:27017
Engine: 5.0.0 (oba env) — Amazon DocumentDB
```

SQS: `infra-puzzler-b2b-{dev,qa}-jobs` + DLQ `...-jobs-dlq` (oba env)

---

## Secrets Manager

| Secret | Zawartość logiczna |
|--------|--------------------|
| `infra-puzzler-b2b/dev/docdb` | host, port, user, password, database_core/automation/notifier, connection strings |
| `infra-puzzler-b2b/dev/jumphost-ssh` | authorized_keys (SSH public keys) |
| `infra-puzzler-b2b/dev/azuread` | TenantId, ClientId, ClientSecret |
| `infra-puzzler-b2b/qa/docdb` | jw. (QA) |
| `infra-puzzler-b2b/qa/jumphost-ssh` | authorized_keys (QA) |
| `infra-puzzler-b2b/qa/azuread` | jw. (QA) |

Nie wklejaj wartości sekretów do rozmów LLM.

---

## Jumphost (SSH tunnel do DocumentDB)

ECS Fargate service na Alpine + sshd. Używany do dostępu developerskiego do DocumentDB przez SSH port forwarding.

**Ważny gotcha:** Alpine domyślnie `AllowTcpForwarding no`. Fix przez `sed -i 's/AllowTcpForwarding no/AllowTcpForwarding yes/g' /etc/ssh/sshd_config` w Dockerfile. `echo >> ...` NIE DZIAŁA — sshd bierze pierwsze wystąpienie.

```bash
# Pobierz public IP taska (zmienia się przy restarcie):
aws ecs list-tasks --cluster infra-puzzler-b2b-dev-puzzler \
  --service-name infra-puzzler-b2b-dev-jumphost \
  --desired-status RUNNING --profile puzzler-pbms --region eu-west-2

# Tunel SSH do DocumentDB dev
ssh -i ~/.ssh/jumphost_dev -N -L 27017:<docdb-endpoint>:27017 <user>@<jumphost-public-ip>
```

Klucz SSH: `~/.ssh/jumphost_dev` (ed25519). Port 22 dostępny tylko z `195.117.107.110/32` (biuro MakoLab — po VPN lub z biura).

---

## ACM Certs (eu-west-2)

| Domena | Env |
|--------|-----|
| pbms-api-dev.makotest.pl | dev gateway |
| pbms-dev.makotest.pl | dev frontend |
| pbms-api-qa.makotest.pl | QA gateway |
| pbms-qa.makotest.pl | QA frontend |

---

## Terraform drift guardrails (dodane 2026-05-06)

| Zasób | Ignorowany atrybut | Powód |
|-------|-------------------|-------|
| `aws_ecs_task_definition` | `container_definitions` | CI/CD owns images |
| `aws_ecs_service` | `desired_count` | Scheduler owns count |
| `aws_secretsmanager_secret_version` | `secret_string` | Operator rotuje poza TF |

Po guardrails: `terraform plan` na dev = 0 add/change/destroy.

---

## Znane problemy (stan 2026-05-06)

| Problem | Prioryt | Status |
|---------|---------|--------|
| QA jumphost DOWN — ECR image missing (`infra-puzzler-b2b-app-qa:jumphost`) | WYSOKI | niezweryfikowany po 2026-05-06 |
| credentials puzzler-pbms expired (SignatureDoesNotMatch 2026-05-05) | WYSOKI | niezweryfikowany |
| `authorized_keys` untracked + gitignore literówka `autorized_keys` | ŚREDNI | OTWARTE |
| `envs/dev/.env` untracked, brak reguły gitignore | NISKI | OTWARTE |
| Worker desired:0 (dev+QA) — nieustalone czy celowe | INFO | OTWARTE |
| CloudFront dev bez custom domain (alias=0) | INFO | — |

---

## Komendy diagnostyczne

```bash
# tożsamość
aws sts get-caller-identity --profile puzzler-pbms

# stan serwisów dev
aws ecs describe-services \
  --cluster infra-puzzler-b2b-dev-puzzler \
  --services infra-puzzler-b2b-dev-gateway infra-puzzler-b2b-dev-core \
    infra-puzzler-b2b-dev-delivery infra-puzzler-b2b-dev-notifier \
    infra-puzzler-b2b-dev-front infra-puzzler-b2b-dev-builder \
    infra-puzzler-b2b-dev-sync infra-puzzler-b2b-dev-jumphost infra-puzzler-b2b-dev-worker \
  --profile puzzler-pbms --region eu-west-2 \
  --query 'services[*].{name:serviceName,desired:desiredCount,running:runningCount}'

# jumphost dev — public IP
aws ecs list-tasks \
  --cluster infra-puzzler-b2b-dev-puzzler \
  --service-name infra-puzzler-b2b-dev-jumphost \
  --desired-status RUNNING --profile puzzler-pbms --region eu-west-2

# repo preflight przed zmianami IaC
cd ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
git status --short
git check-ignore -v authorized_keys envs/dev/.env

# terraform plan (zawsze po refresh credentials)
cd envs/dev && terraform init -backend-config=backend.tf && terraform plan -refresh=false
```

---

## Powiązane context packs

- `_chatgpt/context-packs/puzzler-b2b-jumphost.md` — szczegółowy kontekst jumphost (historia napraw, iteracje obrazów, ECS Exec)
