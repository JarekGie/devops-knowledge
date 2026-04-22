# PBMS — Puzzler B2B Management System

#aws #ecs #fargate #documentdb #terraform #pbms #mako

**Data:** 2026-04-22
**Projekt:** Puzzler B2B — mikroserwisowa aplikacja .NET na ECS Fargate

---

## Repozytorium kodu

- lokalna ścieżka: `~/projekty/mako/aws-projects/infra-puzzler-b2b-final`
- remote: `git@gitlab.makolab.net:admin-makolab/dc/aws-projects/infra-pbms.git`
- aktywny branch: `feat/dev-jumphost-runtime-secret`
- IaC: **Terraform** >= 1.5.0

---

## Środowiska

| Env  | Region       | Account ID   | Status       | VPC CIDR     |
|------|--------------|-------------|--------------|--------------|
| dev  | eu-west-2    | 698220459519 | **wdrożony** | 10.0.0.0/16  |
| qa   | eu-central-1 | CHANGE_ME    | template     | 10.1.0.0/16  |
| uat  | eu-central-1 | CHANGE_ME    | template     | 10.2.0.0/16  |
| prod | eu-central-1 | CHANGE_ME    | template     | 10.3.0.0/16  |

State bucket: `698220459519-terraform-state` (eu-central-1)  
State key: `infra-puzzler-b2b/{env}/terraform.tfstate`

---

## Architektura

```
Internet
    ↓
CloudFront
    ↓
ALB (pbms-api-dev.makotest.pl)
    ├── /health → gateway (priority 100)
    └── * → gateway

gateway (ECS Fargate, 8080)
    ├── pbms-core-dev.pbms.local:8080      (Cloud Map)
    ├── pbms-delivery-dev.pbms.local:8080  (Cloud Map)
    └── pbms-notifier-dev.pbms.local:8080  (Cloud Map)

worker (ECS Fargate, SQS scaling)
    └── SQS: infra-puzzler-b2b-dev-jobs

jumphost (ECS Fargate, ECS Exec SSH)
    └── DocumentDB :27017 (VPN only: 195.117.107.110/32)

DocumentDB (db.t3.medium, single AZ, dev)
```

---

## Mikroserwisy

| Serwis    | Port | Ingress     | Cloud Map               | ECS Exec |
|-----------|------|-------------|-------------------------|----------|
| gateway   | 8080 | ALB public  | pbms-gateway-dev.pbms.local | ✅ |
| core      | 8080 | VPC only    | pbms-core-dev.pbms.local    | ❌ |
| delivery  | 8080 | VPC only    | pbms-delivery-dev.pbms.local| ❌ |
| notifier  | 8080 | VPC only    | pbms-notifier-dev.pbms.local| ❌ |
| frontend  | 8080 | ALB public  | —                           | ❌ |
| worker    | —    | SQS trigger | —                           | ❌ |
| jumphost  | —    | ECS Exec    | —                           | ❌ |

---

## Zasoby kluczowe (dev)

| Zasób | Identyfikator |
|-------|--------------|
| ECS Cluster | `infra-puzzler-b2b-dev-puzzler` |
| ALB domain | `pbms-api-dev.makotest.pl` |
| DocumentDB | db.t3.medium, cluster_size=1, port 27017 |
| SQS | `infra-puzzler-b2b-dev-jobs` |
| Cloud Map namespace | `pbms.local` |
| CloudWatch dashboard | `infra-puzzler-b2b-dev-operations` |
| ACM cert (gateway) | `arn:aws:acm:eu-west-2:698220459519:certificate/746159be-102d-48c3-9b9b-8c528ce991da` |
| ACM cert (frontend) | `arn:aws:acm:eu-west-2:698220459519:certificate/cf230910-81ec-4cc9-8b90-425dd614ff92` |

---

## Secrets Manager (dev)

| Secret | Zawartość |
|--------|-----------|
| `infra-puzzler-b2b/dev/docdb` | host, port, user, pass, connection strings |
| `infra-puzzler-b2b/dev/azuread` | TenantId, ClientId, ClientSecret, ClientSecretId |
| `infra-puzzler-b2b/dev/jumphost-ssh` | authorized_keys |

Azure AD tenant: `e9b3ed81-433b-4ed3-896f-23b572a61437`

---

## Scheduler (dev/qa, FinOps)

Serwisy zatrzymują się automatycznie poza godzinami pracy:

```
Start: cron(0 7 ? * MON-FRI *) — 07:00 Europe/Warsaw
Stop:  cron(0 19 ? * MON-FRI *) — 19:00 Europe/Warsaw
Serwisy: gateway, core, delivery, notifier (desired_count 0↔1)
```

---

## ECS Config (dev)

| Parametr | Wartość |
|----------|---------|
| CPU (serwisy) | 512 |
| Memory (serwisy) | 1024 MB |
| CPU (worker) | 1024 |
| Memory (worker) | 2048 MB |
| ASPNETCORE_ENVIRONMENT | DEV |
| health check | `/health` |

Worker scaling: SQS-based, `sqs_scale_out_threshold=1`, `max_capacity=2`

---

## Znane problemy / dług techniczny

| Problem | Priorytet | Opis |
|---------|-----------|------|
| Worker image | 🔴 | `worker_image = "nginx:latest"` — ECR repo puste, obraz nie zbudowany |
| Sensitive data w tfvars | 🔴 | Azure AD credentials + DocDB password w terraform.tfvars — przenieść do `.env` / CI/CD vars |
| Service Discovery | 🟡 | Cloud Map — taski mogą nie rejestrować się (patch do modułu app-stack) |
| Frontend repo | 🟡 | `pbms-dev.makotest.pl` — brak reguły ALB w tym repo, osobny stack |
| QA/UAT/prod | 🟡 | Templates z CHANGE_ME — niezwdrożone |

---

## Dostęp diagnostyczny

### ECS Exec (gateway)
```bash
aws ecs execute-command \
  --cluster infra-puzzler-b2b-dev-puzzler \
  --task <task-id> \
  --container gateway \
  --interactive \
  --command "/bin/bash" \
  --region eu-west-2
```

### DocumentDB przez jumphost
```bash
# 1. ECS Exec do jumphost (VPN required: 195.117.107.110/32)
# 2. mongo --host <docdb-endpoint>:27017 --tls --tlsCAFile /etc/ssl/certs/...
```

---

## Powiązane

- [[pbms-troubleshoot]] — runbook diagnostyczny
- lokalna ścieżka: `~/projekty/mako/aws-projects/infra-puzzler-b2b-final`
