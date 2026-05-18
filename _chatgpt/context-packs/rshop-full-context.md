---
title: ChatGPT Context Pack — rshop (pełny)
project: rshop
client: mako
type: context-pack
scope: full
domain: client-work
classification: internal
created: 2026-05-18
updated: 2026-05-18
source_files:
  - 20-projects/clients/mako/rshop/rshop-context.md
  - 20-projects/clients/mako/rshop/session-log.md
  - 20-projects/clients/mako/rshop/finops-rshop.md
  - 20-projects/clients/mako/rshop/rca-ecs-deploy-failure-2026-05-08.md
  - 20-projects/clients/mako/rshop/rshop-p99-latency-findings.md
  - 20-projects/clients/mako/rshop/acm-cert-migration-2026-05-08.md
  - _chatgpt/context-packs/rshop-p99-latency.md
  - _chatgpt/context-packs/rshop-tag-policy.md
tags: [chatgpt, context-pack, rshop, aws, cloudformation, ecs, full-context]
---

# Paczka kontekstu — rshop (pełny)

> Wklej całość na początku rozmowy z ChatGPT.
> Zakres: pełny kontekst projektu rshop — architektura, stan środowisk, problemy aktywne, historia.

**Data przygotowania:** 2026-05-18
**Snapshot runtime:** 2026-05-01 (częściowy); uzupełniony o sesje do 2026-05-18

---

## Kim jestem / styl odpowiedzi

Senior DevOps/SRE, AWS multi-account (Organizations), głównie ECS Fargate + CloudFormation. ADHD.
Styl: werdykt na górze, fakty z dowodami, krótkie sekcje, nie tłumacz oczywistych rzeczy, podążaj za nowym wątkiem.

---

## Projekt rshop

Wielorynkowa platforma e-commerce Renault i Dacia. Obsługuje PL/CZ/SK/HU/LT/LV/EE — dwie marki (Renault + Dacia) jako osobne frontend-svc w jednym klastrze ECS.

```
AWS Account:  943111679945
Region:       eu-central-1 (główny) + us-east-1 (ACM dla CloudFront)
IaC:          CloudFormation
CLI profile:  rshop
CI/CD:        Jenkins
Repo IaC:     ~/projekty/mako/aws-projects/infra-rshop (git@gitlab.makolab.net:admin-makolab/dc/aws-projects/infra-rshop.git)
Repo CI/CD:   ~/projekty/mako/eshop-cicd
IAM CI/CD:    jenkinsit (IAM user)
```

---

## Architektura

```
Internet
  ├── CloudFront (4 dystrybucje)
  │     ├── EHVSOBMPOXLM7 — prod-PL (sklep.renault.pl, sklep.dacia.pl, bo.sklep.*)
  │     ├── ET4SVT8DC9P9M — prod-Foreign (bo.webshop.renault.hu, eshop.dacia.cz, .sk)
  │     ├── E12KV5NOV0I551 — dev-Baltic (dev.eshoprenault.lt/lv, devb.eshopdacia.lv)
  │     └── E3LC30816FMUSK — dev-CZ/SK/HU (dev.eshopdacia.sk/cz, dev.eshopdacia.cz)
  │
  ├── prod-ALB → prod-ALB-1431454853.eu-central-1.elb.amazonaws.com
  │     ├── prod-frontend-svc1     (rshop-prod-Klaster, port 3000, Renault)
  │     ├── prod-frontend-svc2     (rshop-prod-Klaster, port 3000, Dacia)
  │     ├── prod-api-svc           (rshop-prod-Klaster, port 8080)
  │     ├── prod-backoffice-svc    (rshop-prod-Klaster, port 8080)
  │     ├── akcesoria2-renault-svc (akcesoria2-prod-Klaster, port 3000)
  │     └── akcesoria2-dacia-svc   (akcesoria2-prod-Klaster, port 3000)
  │
  └── dev-ALB → dev-ALB-2024598218.eu-central-1.elb.amazonaws.com
        ├── dev-frontend-svc1/2   (rshop-dev-Klaster)
        ├── dev-api-svc
        └── dev-backoffice-svc

ECS Fargate → RDS SQL Server
  prod: sqlserver-web, db.t3.large, SingleAZ (SPOF!), id: pssa61v1phykq0
  dev:  sqlserver-ex (Express Edition), db.t3.small, id: dev-dbstack-ez6jh7wsba94-...

Secrets: Secrets Manager = 0 sekretów (sprawdzone live). Prawdopodobnie SSM Param Store lub CFN params.
Brak: Redis, RabbitMQ, EventBridge rules (lista pusta), AWS WAF (0 ACL — REGIONAL + CF)
```

Uwaga: routing ALB → serwis przez listener rules — nie weryfikowane. TG potwierdzone, listener rules nie.

---

## Stan środowisk (ostatni znany)

| Env | ECS | CFN root | Uwagi |
|-----|-----|----------|-------|
| prod | 4/4 ACTIVE, desired=1, running=1 ✅ | UPDATE_COMPLETE (2026-04-30) | Wszystko działa |
| dev | 4/4 ACTIVE, desired=1, running=1 ✅ | UPDATE_ROLLBACK_COMPLETE (2026-05-12, po recovery) | FE deploy naprawiony 2026-05-14 |
| akcesoria2-prod | 2/2 ACTIVE ✅ | UPDATE_COMPLETE (2026-04-24) | OK |
| qa | brak klastra | brak stacka | Środowisko usunięte |
| uat | brak klastra | brak stacka | Nie istnieje runtime |

---

## VPC / Sieć

| VPC | ID | CIDR |
|-----|----|------|
| prod | vpc-08c5016cee20ad2ae | 10.0.0.0/16 |
| dev | vpc-0befdfd9f1b71ebf6 | 10.0.0.0/16 |
| default ("cos_dev") | vpc-0f46b727b63c49da3 | 172.31.0.0/16 |

VPC Endpoints (8, oba VPC): ECR API + DKR, CloudWatch Logs, S3 Gateway.

---

## ACM Certyfikaty

| Domena | ARN suffix | Wygasa | Status | Używany przez |
|--------|-----------|--------|--------|--------------|
| sklep.renault.pl | `…/c4c0fa76-…` | 2026-10-01 | ISSUED | CF prod-PL (EHVSOBMPOXLM7) |
| webshop.renault.hu | `…/hu-cert` | 2026-07-09 | ISSUED | CF prod-Foreign (ET4SVT8DC9P9M) |
| *.skleprenault.pl (NOWY) | `72123357-5a77-4b60-84b1-f59e5282270e` | **2026-11-22** | ISSUED | CF dev (E3LC30816FMUSK) |
| *.skleprenault.pl (STARY) | `3be77743-e90b-4d21-ba97-c6193c8bc977` | ~~2026-05-13~~ | ISSUED | InUse=[] — do usunięcia po 2026-05-23 |
| dev.eshoprenault.lt | `173ae59f-…` | **EXPIRED 2024-08-08** | EXPIRED | InUse=False — orphan, do usunięcia |
| dev.eshopdacia.lt | `…/lv-cert` | 2026-11-04 | ISSUED | CF dev-Baltic (E12KV5NOV0I551) |

**Akcja 2026-05-08:** Migracja dev CF E3LC30816FMUSK na nowy cert (72123357). Stary odpięty, 4 aliasy HU usunięte (NXDOMAIN). Zweryfikowane openssl. Stary cert nie usunięty — rollback możliwy.

---

## CloudFormation — struktura IaC

```
infra-rshop/cloudformation/
  root.yml             — prod root (Default env: prod)
  dev/root-dev.yml     — dev root (UWAGA: lokalna wersja różni się od S3 — walidacja params DB)
  dev/*.yml            — dev templates
  akcesoria2/*.yml     — akcesoria2 templates

S3 artifact bucket: rshop-cf (TemplateURL source dla deployów)
UWAGA: Lokalna kopia != zawsze to co deploy — templates publikowane na S3 przed deployem.
```

Nested stacks prod: VPCStack, SGStack, IAMStack, DBStack, ALBStack, ECSStack (+ sub-stacks per serwis), S3Stack, CFStack.

---

## CI/CD (Jenkins)

| Pipeline | Plik | Cel | Status |
|----------|------|-----|--------|
| FE prod | `jenkinsfiles/FE/r-shop-all.jenkinsfile` | Deploy frontend prod | Naprawiony 2026-05-12 |
| FE dev scan | `jenkinsfiles/FE/r-shop-all-dev-scan.jenkinsfile` | Deploy + skan (Trivy/Sonar/OWASP) | Naprawiony 2026-05-12 + 2026-05-14 |

**Kluczowa poprawka (2026-05-12/14):** Dev FE deploy celował w root stack `dev` → update uruchamiał VPC/DB/IAM stacks → crash. Fix: deploy celuje teraz wyłącznie w child stacki `FrontendRenault` i `FrontendDacia`.

Dev FE deploy — sygnały poprawnego uruchomienia:
- Log: `DEV FE deploy uses child stacks only`
- Change-set names: `changeSet-<build>-FrontendRenault` / `changeSet-<build>-FrontendDacia`
- BRAK: `create-change-set --stack-name dev-ECSStack-1BLAWHL0P6JKO`

ECS child stacks dev:
- `dev-ECSStack-1BLAWHL0P6JKO-FrontendRenault-PO8N6MN3IGSI`
- `dev-ECSStack-1BLAWHL0P6JKO-FrontendDacia-1F7C2JWZJFSKZ`

---

## Aktywne problemy i dług techniczny

### KRYTYCZNE / WYSOKI

| Problem | Evidence | Opis |
|---------|----------|------|
| 0 CloudWatch alarms | describe-alarms: pusta lista | Brak monitoringu na jakimkolwiek zasobie. Awaria wykrywana przez użytkowników lub Jenkins, nie alertami. |
| Retencja logów prod: 1 dzień | /ecs/rshop-prod, 137 MB | Niemożliwe RCA incydentów >24h. Uniemożliwiło pełne RCA 2026-05-08. |
| Retencja logów dev: 1 dzień | /ecs/rshop-dev, 8.2 MB | RCA niemożliwe. Root cause ECS crash 2026-05-08 nieznany przez 1-day log retention. |
| Brak AWS WAF | wafv2: 0 ACLs (REGIONAL + CF) | Brak OWASP top 10, rate limiting, bot protection na prod ALB + CloudFront. |
| p99 latency ALB prod | peaks do 12s, alarm flapping | External Renault/Dacia API bez timeout/circuit breaker + single ECS task (desired=1). |
| RDS prod SingleAZ | describe-db-instances: MultiAZ=False | sqlserver-web, db.t3.large — SPOF dla produkcyjnej bazy. |

### ŚREDNI

| Problem | Evidence | Opis |
|---------|----------|------|
| Tag Policy LLZ wyłączone | terraform destroy po incydencie 2026-04-20 | Przed re-enable: fix CFN templates (PropagateTags: SERVICE) wymagany we wszystkich 10 serwisach. |
| Dev root stack UPDATE_ROLLBACK_COMPLETE | CFN list-stacks | Naprawione 2026-05-12, ale root CFN dev nie jest deploywany przez CI/CD — ECSStack osobno. |
| jenkinsit brak rds:ModifyDBSubnetGroup (trwale) | CFN events AccessDenied | Temp policy dodana i usunięta. Bez trwałego fix każdy przyszły CFN dev VPCStack update failuje. |
| Dev tagging CFN stacks | resourcegroupstaggingapi | dev nested stacks mają tylko Project+Environment, brak Owner/ManagedBy/CostCenter. |
| Orphaned S3 buckets | S3 list-buckets | rshop-temp, rshop-tmp, rshopp-logs (typo), 2× terraform state buckets. |
| ECR qa/uat bez runtime | ECR list-repositories | rshopapp-qa + rshopapp-uat — klastry/stacki nie istnieją. |

### NISKI / INFO

| Problem | Opis |
|---------|------|
| Orphaned log groups | /esc/backoffice (typo /esc/), /ecs/Rshop-frontend, /ecs/api, /ecs/jumhost-qa (typo + QA nie istnieje), /ecs/nmap |
| Cert stary `3be77743` | Wygasł 2026-05-13, InUseBy=[], do usunięcia po 2026-05-23 |
| Cert orphan `173ae59f` | EXPIRED 2024-08-08, do usunięcia |
| Dev ECSStack poza CFN root | ECSStack deploywany bezpośrednio (poza root orchestration) |
| 2× terraform state S3 buckets | Skąd Terraform w projekcie CFN? Wymaga wyjaśnienia. |

---

## p99 Latency — root causes (zidentyfikowane, nienaprawione)

Stack: ASP.NET Core, ECS Fargate desired=1, SQL Server RDS, ALB.

| Priorytet | Endpoint | Problem | Max |
|-----------|----------|---------|-----|
| P1 | `/api/Services/categories` + `/api/Services/category/{cat}/bir/{bir}/vin/{vin}` | Sync call do zewnętrznego API Renault/Dacia DMS, brak timeout (czeka do 12s), brak circuit breaker, brak cache per VIN | 12 307ms |
| P1 | `/api/Tires` | Zewnętrzne API, brak timeout | 6 642ms |
| P2 | `/api/pdf` / `/api/PDF` | CPU-bound PDF generation blokuje ASP.NET thread pool | 4 382ms |
| P2 | `/api/Accessories` | `ORDER BY NEWID()` → full table scan (EF Core anti-pattern) | ~2s |

Wzmacniacz: desired=1 → jeden wolny request blokuje wątki, reszta kolejkuje się.

Rekomendacje (nie wdrożone):
- Polly HttpClient z timeout ≤5s + circuit breaker na external API
- Cache per BIR/VIN (IMemoryCache, TTL 24h)
- ECS desired=2 + autoscaling (ALBRequestCountPerTarget ~500)
- `ORDER BY NEWID()` → shuffle po stronie aplikacji

---

## Tag Policy Incident — kontekst (2026-04-20)

ECS Fargate tworzy ENI przy każdym nowym tasku. LLZ Tag Policy wymagała tagów `Environment`+`Project` na `ec2:network-interface`. CFN nigdy nie miało `PropagateTags: SERVICE` → ENI bez tagów → TagPolicyViolation → HTTP 503.
Fix doraźny: `terraform destroy Tag Policies`. Aktualnie **Tag Policies WYŁĄCZONE**.

Przed ponownym re-enable wymagane:
- Dodać `PropagateTags: SERVICE` + `EnableECSManagedTags: true` do wszystkich 10 serwisów ECS w CFN
- rshop-cloudformation (4 pliki): api.yml, backoffice.yml, frontend.yml, frontend2.yml
- infra-rshop/cloudformation/akcesoria2/svc.yml (Tags już są, brakuje tylko tych 2 linii)

---

## FinOps (kwiecień 2026)

```
Total MTD April: $959.96 (vs $1114.36 poprzedni miesiąc, -13.9%)
Prod:     $386.91 | Dev: $95.42 | QA: $0.30 | Untagged: $477.32 (49.7%!)
Forecast 30d: ~$664 (na podstawie avg last 7 days $22/dzień)

Top serwisy (MTD April):
  VPC          $125.34
  ECS Fargate  $125.09
  RDS          $123.98
  CloudWatch   $55.77

ALB access logs: WYŁĄCZONE (koszt: ~$1-4/mies. na S3 — warto włączyć)
CloudFront std logging: WYŁĄCZONE (koszt: <$1/mies. — warto włączyć)
VPC Flow Logs: WYŁĄCZONE (rekomendacja: S3, nie CloudWatch — $2-8/mies.)
```

---

## Observability — CloudWatch Log Groups (prod)

| Log group | Retencja | Stored | Status |
|-----------|----------|--------|--------|
| /ecs/rshop-prod | **1 dzień** | 137 MB | ⚠️ produkcja — krytycznie niska |
| /esc/backoffice | 1 dzień | 0 | **typo /esc/ zamiast /ecs/** |
| /aws/ecs/containerinsights/rshop-prod-Klaster/performance | 1 dzień | 0 | |

CW Alarms: **0** (describe-alarms: pusta lista)

---

## Kluczowe komendy diagnostyczne

```bash
# ECS — stan prod
aws ecs describe-services \
  --cluster rshop-prod-Klaster \
  --services rshop-prod-api-svc rshop-prod-backoffice-svc rshop-prod-frontend-svc1 rshop-prod-frontend-svc2 \
  --profile rshop --region eu-central-1 \
  --query 'services[*].{Name:serviceName,Status:status,Desired:desiredCount,Running:runningCount}'

# ALB target health
aws elbv2 describe-target-health \
  --target-group-arn <arn> --profile rshop --region eu-central-1

# p99 latency — CloudWatch Logs Insights
# Log group: /ecs/rshop-prod
# Query: filter @message like /Request finished/ | parse @message /(?<duration>[0-9]+\.[0-9]+)ms/ | sort duration desc | limit 20

# CFN dev stack status
aws cloudformation describe-stacks \
  --stack-name dev --profile rshop --region eu-central-1 \
  --query 'Stacks[0].{Status:StackStatus,Updated:LastUpdatedTime}'

# ACM cert status
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:943111679945:certificate/72123357-5a77-4b60-84b1-f59e5282270e \
  --profile rshop --region us-east-1 \
  --query 'Certificate.{Status:Status,Expires:NotAfter,RenewalStatus:RenewalSummary.RenewalStatus}'
```

---

## Otwarte zadania (backlog, nie zakończone)

```
[ ] Zwiększyć retencję /ecs/rshop-prod z 1d → min 30 dni (P0)
[ ] Zwiększyć retencję /ecs/rshop-dev z 1d → min 14 dni (P0)
[ ] Dodać CloudWatch alarms (ECS TargetNotHealthy, ALB p99, ECS RunningTaskCount) (P0)
[ ] Fix CFN templates: PropagateTags: SERVICE (przed re-enable LLZ Tag Policies)
[ ] Re-enable LLZ Tag Policies (po fix CFN)
[ ] Polly timeout + circuit breaker na external API Renault/Dacia (P1, dev team)
[ ] ECS autoscaling desired_count=2 dla prod-api-svc (P1)
[ ] Dodać rds:ModifyDBSubnetGroup do Rshop-dev-policy (jenkinsit trwały fix)
[ ] Włączyć ALB access logs → S3 (koszt ~$2/mies.)
[ ] Włączyć VPC Flow Logs → S3 (koszt ~$2-8/mies.)
[ ] Usunąć stary cert 3be77743 (po 2026-05-23)
[ ] Usunąć orphaned cert 173ae59f (EXPIRED 2024-08-08)
[ ] CloudWatch alarm DaysToExpiry < 30 dla nowego certu dev (72123357)
[ ] Cleanup orphaned S3 buckets: rshop-temp, rshop-tmp, rshopp-logs
[ ] Otagować dev CFN stacks (Owner/ManagedBy/CostCenter w root-dev.yml)
[ ] Wyjaśnić skąd 2× terraform state buckets w projekcie CFN
[ ] RDS prod: rozważyć MultiAZ (aktualnie SingleAZ — SPOF)
[ ] AWS WAF: wdrożyć (min. rate limiting + OWASP managed rules)
```

---

## Historia kluczowych incydentów

| Data | Incydent | Status |
|------|----------|--------|
| 2026-04-20 | ECS TagPolicyViolation → HTTP 503 prod | Zamknięty (Tag Policies disabled) |
| 2026-04-28 | Dev root stack UPDATE_ROLLBACK_FAILED (rds:ModifyDBSubnetGroup denied) | Zamknięty 2026-05-12 |
| 2026-05-04 | ALB p99 >2s flapping alarm (Services API Renault/Dacia) | Zidentyfikowany, nienaprawiony |
| 2026-05-08 | ECS deploy failure dev (NotStabilized, rollback) — root cause nieznany | Zamknięty (auto-rollback) |
| 2026-05-08 | ACM cert *.skleprenault.pl wygasający (2026-05-13) | Zamknięty (migracja na nowy cert) |
| 2026-05-12 | Dev root stack recovery + FE Jenkinsfile fix | Zamknięty |
| 2026-05-14 | FE dev deploy separation (child stacks only) | Zamknięty |

---

## Jak używać tej paczki w ChatGPT

**Podaj na początku rozmowy: tę paczkę + konkretne pytanie.**

Przykłady promptów:
- "Pomóż mi napisać CloudFormation snippet dodający PropagateTags: SERVICE do ECS Service resource"
- "Jak skonfigurować CloudWatch alarm na ECS RunningTaskCount dla rshop?"
- "Napisz Polly HttpClient policy z timeout 5s i circuit breaker dla ASP.NET Core"
- "Jak bezpiecznie dodać rds:ModifyDBSubnetGroup do policy jenkinsit?"

**Nie używaj do:** decyzji runtime AWS bez live verification.
**Dane wrażliwe w tej paczce:** Account ID 943111679945 — nie wklejaj do publicznych forów.
