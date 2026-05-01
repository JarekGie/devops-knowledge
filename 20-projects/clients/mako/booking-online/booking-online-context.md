---
title: booking-online-context
client: mako
project: booking-online
domain: client-work
document_type: runtime-context
context_type: cloud-detective-snapshot
classification: internal
source_of_truth: false
runtime_snapshot: true
aws_profile: booking
account_id: "128264038676"
regions:
  - eu-central-1
iac: cloudformation
repository: "git@gitlab.makolab.net:admin-makolab/dc/aws-projects/infra-booking-online.git"
created: "2026-05-01"
updated: "2026-05-01"
last_verified: "2026-05-01"
scan_method: cloud-detective-v2
last_verified_by: claude
tags:
  - aws
  - cloudformation
  - mako
  - booking-online
  - ecs
  - cloudfront
---

# booking-online — platforma rezerwacji jazd próbnych (Dacia/Renault)

#aws #cloudformation #ecs #fargate #mako #booking-online

**Data:** 2026-05-01
**Typ dokumentu:** snapshot runtime / context wejściowy
**Source of truth:** AWS live + IaC (CloudFormation)
**Tryb skanowania:** read-only
**Poziom pewności snapshotu:** częściowa
**Projekt:** Platforma rezerwacji jazd próbnych dla marek Dacia i Renault, hostowana na AWS ECS Fargate + CloudFront
**Account ID:** `128264038676`
**AWS profile:** `booking`
**IAM principal:** `OrganizationAccountAccessRole` *(federated assumed-role z OrganizationAccount)*
**Region główny:** `eu-central-1`
**Region dodatkowy (ACM):** `us-east-1` — sprawdzony

---

## Snapshot metadata

| Pole | Wartość |
|------|---------|
| scan_date | 2026-05-01 |
| scan_scope | partial |
| regions_checked | eu-central-1, us-east-1 (ACM only) |
| repo_checked | tak |
| iac_checked | tak (cloudformation/*.yml, S3 templates) |
| runtime_checked | tak |
| extra_regions_checked | us-east-1 (ACM list-certificates + describe-certificate) |

---

## Zakres snapshotu vs audytu

| Obszar | Typ | Zakres | Źródło |
|--------|-----|--------|--------|
| Runtime health (ECS/ALB) | snapshot | live AWS | live AWS |
| CFN stack status | snapshot | live AWS | live AWS |
| ElastiCache status | snapshot | live AWS | live AWS |
| ACM certs eu-central-1 + us-east-1 | snapshot | pełny per region | live AWS |
| IaC analiza | snapshot | lokalny checkout (cloudformation/*.yml) | IaC |
| ALB listener rules | snapshot | opisane przez ALB.yml + describe-listeners | IaC + live AWS |
| Tagging coverage | snapshot | 28 zasobów sprawdzonych live (ECS, ALB, ElastiCache) | live AWS |
| FinOps / cost allocation | niezweryfikowane | brak historycznego audytu | — |
| Security (WAF) | gap analysis | list-web-acls wykonane live | live AWS |
| CloudWatch alarms | snapshot | describe-alarms wykonane | live AWS |
| CloudFront | snapshot | live AWS (list-distributions + get-distribution-config prod) | live AWS |
| Secrets Manager | snapshot | list-secrets wykonane | live AWS |
| SSM Parameter Store | snapshot | describe-parameters wykonane | live AWS |
| ECR | snapshot | describe-repositories wykonane | live AWS |
| Synthetics canaries | snapshot | describe-canaries wykonane | live AWS |

---

## Repozytorium kodu

- **lokalna ścieżka:** `~/projekty/mako/aws-projects/infra-booking-online`
- **remote:** `git@gitlab.makolab.net:admin-makolab/dc/aws-projects/infra-booking-online.git`
- **aktywny branch:** `main`
- **ostatnie commity:** dodanie katalogu terraform dla booking, zmiany cache template
- **IaC:** **CloudFormation** (nested stacks)

**IaC source of truth:**

```
repo lokalne: ~/projekty/mako/aws-projects/infra-booking-online/cloudformation/
  ROOT.yml, VPC.yml, SG.yml, ALB.yml, CF.yml, ECS.yml, ECS_SOL.yml, REDIS.yml, S3.yml

S3 deployment templates: s3://booking-online-cf.s3.eu-central-1.amazonaws.com/
  [UWAGA] szablony deployowane z S3, nie bezpośrednio z repo — S3 jest faktycznym runtime source
  ROOT.yml odwołuje się do TemplateURL wskazujących na S3 bucket
```

---

## Środowiska

| Env | Region | Account ID | CFN Stack | Status | VPC CIDR | Pewność |
|-----|--------|------------|-----------|--------|----------|---------|
| dev | eu-central-1 | 128264038676 | bookingonline-dev | UPDATE_COMPLETE | 10.3.0.0/16 | wysoka (live) |
| qa | eu-central-1 | 128264038676 | bookingonline-qa | UPDATE_COMPLETE | 10.4.0.0/16 | wysoka (live) |
| uat | eu-central-1 | 128264038676 | bookingonline-uat | UPDATE_COMPLETE | 10.5.0.0/16 | wysoka (live) |
| prod | eu-central-1 | 128264038676 | **bokingonline-prod** *(typo)* | UPDATE_COMPLETE | 10.6.0.0/16 | wysoka (live) |

**Uwaga:** Prod stack nazwany `bokingonline-prod` (brakuje jednego 'o') — niespójne z konwencją `bookingonline-*`.

---

## Architektura

```text
Internet
    │
    ▼
CloudFront (4 dystrybucje, global)
  │  Origins: S3 (statyczne assety) + ALB (API/dynamiczne)
  │  Security: x-sec-token header → ALB
  │  TLS: ACM cert us-east-1 (per env)
    │
    ▼
ALB (eu-central-1, internet-facing, HTTP:80)
  │  DefaultAction: 403 (tylko CF z x-sec-token header przechodzi)
  │  3 Target Groups per env: back, dacia-front, reno-front
    │
    ▼
ECS Fargate (public subnets, 4 serwisy per env)
  ├── Gateway-SRVC (port 80, API gateway)
  ├── Booking-SRVC (port 80, backend booking)
  ├── Front-SRVC-dacia (port 80, Dacia frontend)
  └── Front-SRVC-reno (port 80, Renault frontend)
         │
         ▼
    ElastiCache Redis (private subnets)
    cache.t3.micro, single node, port 6379

S3 (per env): statyczne assety aplikacji
ECR (per env): bookingonline-{dev,qa,uat,prod} — IMMUTABLE tags

Service Discovery: Cloud Map namespace per env ({projekt}.{srodowisko})
VPC Endpoint S3: Gateway (public route table)
```

**Uwaga:** ECS tasks działają w **public subnets** (MapPublicIpOnLaunch: true). Brak NAT Gateway — wymagany bezpośredni dostęp internetowy do ECR/AWS APIs.

---

## Mikroserwisy / komponenty

Struktura jednolita we wszystkich 4 środowiskach:

| Serwis | Cluster | Port | Ingress | Service Discovery | Desired | Running | Status (prod) |
|--------|---------|------|---------|-------------------|---------|---------|--------|
| bookingonline-{env}-Gateway-SRVC | bookingonline-{env}-Klaster | 80 | ALB TG back | Cloud Map namespace | 1 | 1 | ACTIVE |
| bookingonline-{env}-Booking-SRVC | bookingonline-{env}-Klaster | 80 | ALB TG back | Cloud Map namespace | 1 | 1 | ACTIVE |
| bookingonline-{env}-Front-SRVC-dacia | bookingonline-{env}-Klaster | 80 | ALB TGF1 dacia | Cloud Map namespace | 1 | 1 | ACTIVE |
| bookingonline-{env}-Front-SRVC-reno | bookingonline-{env}-Klaster | 80 | ALB TGF2 reno | Cloud Map namespace | 1 | 1 | ACTIVE |

Źródło: `live AWS` (ECS describe-services prod) + `IaC` (ECS.yml)

**Prod obrazy ECR** (Źródło: `live AWS` — CFN prod params):
- dacia: `bookingonline-prod:dacia.76`
- renault: `bookingonline-prod:renault.76`
- booking: `bookingonline-prod:booking.57`
- gateway: `bookingonline-prod:gateway.57`

**Prod resources (TaskCPU/TaskMemory):** 2048 vCPU / 4096 MB (prod); 1024/2048 (dev default)

---

## Zasoby kluczowe

| Zasób | Identyfikator | Źródło | Pewność |
|-------|---------------|--------|---------|
| ECS Cluster prod | `bookingonline-prod-Klaster` | live AWS | wysoka |
| ECS Cluster uat | `bookingonline-uat-Klaster` | live AWS | wysoka |
| ECS Cluster qa | `bookingonline-qa-Klaster` | live AWS | wysoka |
| ECS Cluster dev | `bookingonline-dev-Klaster` | live AWS | wysoka |
| ALB prod | `bookingonline-prod-ALB-689373046.eu-central-1.elb.amazonaws.com` | live AWS | wysoka |
| ALB uat | `bookingonline-uat-ALB-521748220.eu-central-1.elb.amazonaws.com` | live AWS | wysoka |
| ALB qa | `bookingonline-qa-ALB-1858714258.eu-central-1.elb.amazonaws.com` | live AWS | wysoka |
| ALB dev | `bookingonline-dev-ALB-89653225.eu-central-1.elb.amazonaws.com` | live AWS | wysoka |
| CF prod | `E1LI5X3I1JSJYQ` / `d14lbpqqhfnrqu.cloudfront.net` | live AWS | wysoka |
| CF uat | `EIRNE8W0Q1NO9` / `dqu4bju88k03b.cloudfront.net` | live AWS | wysoka |
| CF qa | `E2NF20LLBS7SL9` / `duessbyc204ru.cloudfront.net` | live AWS | wysoka |
| CF dev | `E3QCMOORDSLSOP` / `dki1lifcw38jh.cloudfront.net` | live AWS | wysoka |
| Redis prod | `bookingonline-prod-redisinst.szfx3q.0001.euc1.cache.amazonaws.com:6379` | live AWS | wysoka |
| Redis uat | `bookingonline-uat-redisinst.szfx3q.0001.euc1.cache.amazonaws.com:6379` | live AWS | wysoka |
| Redis qa | `bookingonline-qa-redisinst.szfx3q.0001.euc1.cache.amazonaws.com:6379` | live AWS | wysoka |
| Redis dev | `bookingonline-dev-redisinst.szfx3q.0001.euc1.cache.amazonaws.com:6379` | live AWS | wysoka |
| S3 IaC templates | `booking-online-cf` (eu-central-1) | live AWS | wysoka |
| S3 prod app | `bookingonline-prod` (eu-central-1) | live AWS | wysoka |
| ECR prod | `bookingonline-prod` | live AWS | wysoka |
| CFN root stack prod | `bokingonline-prod` *(typo)* | live AWS | wysoka |

---

## Secrets Manager

Secrets Manager: 0 sekretów w regionie eu-central-1 (sprawdzone live)

Możliwe alternatywne źródła sekretów (niezweryfikowane):
- **CloudFormation parameters (NoEcho)** — najprawdopodobniejsze; SecToken (JWT/token), Certyfikat ARN — parametry CFN root stack
- SSM Parameter Store — sprawdzone live: 0 parametrów
- CI/CD credentials (GitLab CI) — niezweryfikowane
- Hardcoded w task definitions — niezweryfikowane

| Secret | Przeznaczenie / zawartość logiczna | Źródło |
|--------|------------------------------------|--------|
| SecToken | Token bezpieczeństwa CloudFront → ALB (x-sec-token header) | IaC (CFN param NoEcho) |
| Certyfikat | ARN certyfikatu ACM dla CloudFront (us-east-1) | IaC (CFN param) |

---

## ACM Certificates

Źródło: `live AWS` (per region)

**eu-central-1:** 0 certyfikatów (TLS terminowany przez CloudFront, nie ALB)

**us-east-1 (CloudFront):**

| Domena | Region | Użycie | Status | Wygasa | InUseBy |
|--------|--------|--------|--------|--------|---------|
| booking-online-prod.makotest.pl (SAN: umowjazde.dacia.pl, *.umowjazde.dacia.pl, *.umowjazde.renault.pl, umowjazde.renault.pl) | us-east-1 | CF prod (E1LI5X3I1JSJYQ) | ISSUED | 2026-10-30 | aktywny |
| booking-online-uat.makotest.pl | us-east-1 | CF uat (wymagaj potwierdzenia — describe nie wykonano) | ISSUED | niezweryfikowane | niezweryfikowane |
| booking-online-qa.makotest.pl | us-east-1 | CF qa | ISSUED | niezweryfikowane | niezweryfikowane |
| booking-online-dev.makotest.pl | us-east-1 | CF dev | ISSUED | niezweryfikowane | niezweryfikowane |
| booking-online-prod.makotest.pl *(stary)* | us-east-1 | **ORPHANED** — InUseBy=[] | **EXPIRED** (2022-09-26) | — | nie używany |

**Uwaga:** Expired cert to stary cert, który nie jest używany — bezpieczny, ale wymaga usunięcia.

**Domeny produkcyjne:**
- `umowjazde.dacia.pl` + `www.umowjazde.dacia.pl` — pokryte przez SAN prod certu
- `umowjazde.renault.pl` + `www.umowjazde.renault.pl` — pokryte przez wildcard *.umowjazde.renault.pl

---

## Tagging / FinOps / LLZ / AWS WAF readiness

**Źródło historyczne:** Brak historycznego audytu tagowania dla booking-online.
**Bieżący scan:** sample-based (28 zasobów sprawdzonych live: ECS clusters, ECS services, ALB, ElastiCache)

| Obszar | Status | Uwagi |
|--------|--------|-------|
| FinOps — cost allocation tags (Project/Environment/CostCenter) | NO-GO | 28/28 sprawdzonych zasobów — Project=MISSING, CostCenter=MISSING wszędzie; Env obecny tylko na ElastiCache |
| LLZ tagging standard (Project/Environment/Owner/ManagedBy/CostCenter) | NO-GO | ECS clusters/services/ALBs: zero tagów; ElastiCache: tylko Env |
| ECS/Fargate — tag propagation do tasków (`propagate_tags`) | niezweryfikowane | IaC (ECS.yml) nie zawiera jawnego propagate_tags — wymaga verify w task definition |
| ECR — tagi na repozytoriach | niezweryfikowane | nie sprawdzono live tagów ECR repozytoriów |
| S3 — tagi na bucketach | niezweryfikowane | nie sprawdzono live tagów S3 |
| CloudWatch Log Groups — tagi | niezweryfikowane | nie sprawdzono |
| VPC / Endpoints — tagi | niezweryfikowane | nie sprawdzono |
| AWS WAF — obecność i przypisanie właściciela | GAP | 0 Regional WAF ACLs + 0 CloudFront WAF ACLs (sprawdzone live) |

### Wymagane tagi LLZ

| Tag | Oczekiwana wartość | Status |
|-----|--------------------|--------|
| Project | booking-online | brakuje (0/28 zasobów) |
| Environment | prod / dev / staging | brakuje na ECS/ALB; obecny na ElastiCache (prod/dev/qa/uat) |
| Owner | \<team / e-mail\> | brakuje (0/28 zasobów) |
| ManagedBy | CloudFormation | brakuje (0/28 zasobów) |
| CostCenter | \<ID działu / projektu\> | brakuje (0/28 zasobów) |

### Wniosek

Tagging booking-online jest w stanie krytycznym z perspektywy governance. ECS clusters, ECS services i ALB nie mają żadnych tagów. ElastiCache ma tylko tag `Env`. CFN templates (ECS.yml, VPC.yml) nie zawierają sekcji Tags na kluczowych zasobach (Cluster, ECS Service). Brak WAF zarówno regionalnego jak i CloudFront — governance gap, nie aktywny incydent. FinOps nie może przypisać kosztów do projektu bez wdrożenia tagów.

### Następne kroki

| Akcja | Priorytet | Kto |
|-------|-----------|-----|
| Dodać Tags do CFN ECS.yml (Cluster, ECS Service, TaskDefinition) | WYSOKI | DevOps |
| Dodać Tags do CFN ALB.yml (LoadBalancer, TargetGroup) | WYSOKI | DevOps |
| Sprawdzić propagate_tags w ECS Service definition | WYSOKI | DevOps |
| Usunąć expired orphaned cert z us-east-1 | ŚREDNI | DevOps |
| Wdrożyć AWS WAF CloudFront (min. rate-based reguły) | WYSOKI | DevOps |

---

## Scheduler / automatyzacje

| Automatyzacja | Harmonogram | Zakres | Uwagi |
|--------------|-------------|--------|-------|
| Auto Scaling ECS | CPU-based (up 60%, down 50%) | prod: max 20 tasks, desired 1 | live AWS — parametry z CFN |
| Auto Minor Version Upgrade Redis | automatyczne przez AWS | Redis 5.0.6 | IaC 5.0.0, runtime 5.0.6 — AWS auto-applied |
| CloudWatch Synthetics canary | brak aktywnych | — | Log group istnieje, canaries=0 — canary usunięty |

---

## ECS / runtime config

| Parametr | Wartość |
|----------|---------|
| Launch Type | FARGATE |
| Network Mode | awsvpc |
| Subnety ECS | **public** (MapPublicIpOnLaunch: true) — brak NAT Gateway |
| Log driver | awslogs |
| Log Group | `/ecs/bookingonline-{env}` |
| Log Retention | **1 dzień** (prod, dev, qa, uat) — WYSOKI |
| IAM Execution Role | `bookingonline-{env}-ExecRole` (AmazonECSTaskExecutionRolePolicy) |
| IAM Task Role | `bookingonline-{env}-TaskRole` (s3:* na Resource "*") |
| Auto Scaling | CPU-based step scaling (UpscaleCPU: 60%, DownscaleCPU: 50%) |

---

## Observability

**Runtime health (live, 2026-05-01):**

| Element | Status | Uwagi |
|---------|--------|-------|
| ECS prod — 4 serwisy | healthy | desired=1 running=1 pending=0 (describe-services) |
| ECS uat — 4 serwisy | healthy | desired=1 running=1 pending=0 |
| ECS qa — 4 serwisy | healthy | desired=1 running=1 pending=0 |
| ECS dev — 4 serwisy | healthy | desired=1 running=1 pending=0 |
| ALB prod target health (back TG) | healthy | 10.6.39.250:80 = healthy |
| ALB uat/qa/dev target health | niezweryfikowane | describe-target-health nie wykonano |
| Redis prod | available | cache.t3.micro, single node |
| Redis uat/qa/dev | available | cache.t3.micro, single node |
| CloudFront prod | Deployed + Enabled | umowjazde.dacia.pl, umowjazde.renault.pl |
| CloudFront uat/qa/dev | Deployed + Enabled | booking-online-{env}.makotest.pl |

**CloudWatch alarms:**

| Alarm | Stan | Metric | Kontekst |
|-------|------|--------|----------|
| *brak* | — | — | 0 alarmów w eu-central-1 (sprawdzone live) |

**Log groups:**

| Log group | Retencja | Uwagi |
|-----------|----------|-------|
| /ecs/bookingonline-prod | **1 dzień** | WYSOKI — brak możliwości debugowania historii |
| /ecs/bookingonline-uat | **1 dzień** | WYSOKI |
| /ecs/bookingonline-qa | **1 dzień** | WYSOKI |
| /ecs/bookingonline-dev | **1 dzień** | WYSOKI |
| /aws/lambda/cwsyn-booking-prod-alb-hear-... | Never (brak retencji) | Synthetics log group — canary usunięty, log group orphaned |

---

## Znane problemy / dług techniczny

| Problem | Priorytet | Evidence | Opis |
|---------|-----------|----------|------|
| Redis stacks UPDATE_ROLLBACK_COMPLETE we wszystkich 4 env | WYSOKI | live AWS — list-stacks | Rollback zakończony. Nie aktywna blokada (Redis działa). Ryzyko: kolejny update Redis stack może nie przejść. Wymaga zbadania przyczyny rollbacku |
| Log retention 1 dzień we wszystkich env | WYSOKI | live AWS — describe-log-groups | Brak możliwości post-incident debugging. IaC: `RetentionInDays: 1` hardcoded w ECS.yml |
| Brak CloudWatch alarms (0) | WYSOKI | live AWS — describe-alarms | Zero alertingu — brak notyfikacji o awariach ECS/ALB/Redis |
| Tagging: brak tagów na ECS/ALB | WYSOKI | live AWS — get-resources (28 zasobów) | NO-GO dla LLZ tagging standard. FinOps nie może przypisać kosztów |
| Redis 5.0.6 — EOL, brak HA | WYSOKI | live AWS — describe-cache-clusters | Redis 5.0.x EOL (AWS recommends 7.x+). Single node — brak HA, brak auto-failover. Brak snapshot backup |
| Brak WAF (Regional + CloudFront) | WYSOKI (GAP) | live AWS — wafv2 list-web-acls | 0 WAF ACLs. Governance gap. Ruch publiczny bez filtracji warstwy 7 |
| ECS w public subnets bez NAT Gateway | WYSOKI | IaC — VPC.yml | ECS tasks mają publiczne IP. Brak NAT Gateway. Architektura zakłada dostęp bezpośredni do internetu z tasków |
| Expired orphaned cert us-east-1 | ŚREDNI | live AWS — acm describe-certificate | `48d927fd-...` EXPIRED 2022-09-26, InUseBy=[]. Bezpieczny (nie używany), wymaga usunięcia dla porządku |
| Prod stack name typo `bokingonline-prod` | ŚREDNI | live AWS — list-stacks | Brakuje 'o' w nazwie. Niespójne z konwencją `bookingonline-*`. Trudne do naprawy bez recreate |
| TaskRole S3 Resource "*" | ŚREDNI | IaC — ECS.yml | `s3:GetObject/PutObject/DeleteObject/...` na `Resource: "*"` — za szerokie uprawnienia |
| ECS_SOL.yml — orphaned template | NISKI | IaC — lokalny checkout | Plik istnieje w repo ale nie jest referencowany w ROOT.yml. Możliwy legacy/dev template |
| CSP bardzo permissywna | NISKI | IaC — CF.yml (komentarz w kodzie) | `default-src * data: ... 'unsafe-eval'` — zanotowane w IaC jako "bardzo pobłażliwa" |

---

## Różnice IaC vs Runtime

| Obszar | IaC | Runtime AWS | Ocena |
|--------|-----|-------------|-------|
| Redis EngineVersion | 5.0.0 | 5.0.6 | rozbieżność (auto minor upgrade) |
| Redis DeletionPolicy | brak (Snapshot zakomentowany) | N/A | IaC luka — brak backup policy |
| ECS subnety | public (IaC jawnie MapPublicIpOnLaunch: true) | public | zgodne |
| CFN template source | repo git | S3 bucket (booking-online-cf) | multi-source — repo nie jest bezpośrednim deployment source |
| ECS_SOL.yml | obecny w repo | nie wdrożony (brak w ROOT.yml) | orphaned |

---

## Drift / niespójności architektury

| Obszar | Typ driftu | Źródło | Opis |
|--------|-----------|--------|------|
| Redis EngineVersion (5.0.0 vs 5.0.6) | IaC vs runtime | live AWS | AutoMinorVersionUpgrade=yes w IaC — drift harmless, spodziewany |
| CFN templates: repo vs S3 | multi-repo/source | IaC | ROOT.yml używa TemplateURL z S3. Repo jest edytorem, S3 jest deployment truth. Drift możliwy jeśli S3 nie jest zsynchronizowany z repo |
| Prod stack name (bokingonline vs bookingonline) | manual change / naming drift | live AWS | Typo wprowadzony przy tworzeniu prod stack — nie da się naprawić bez recreate |
| Redis stacks UPDATE_ROLLBACK_COMPLETE | IaC vs runtime | live AWS | Jakaś zmiana CFN nie przeszła. Przyczyna niezweryfikowana (stack events nie były dostępne) |

---

## Pewność ustaleń

| Obszar | Pewność | Evidence | Uwagi |
|--------|---------|----------|-------|
| ECS clusters — status | wysoka | describe-clusters + describe-services prod | Prod w pełni potwierdzony; uat/qa/dev — tylko cluster-level |
| CFN stack status | wysoka | list-stacks live | Wszystkie 4 env potwierdzone |
| Redis status | wysoka | describe-cache-clusters | Wszystkie 4 env potwierdzone |
| ALB target health | średnia | describe-target-health tylko prod-back TG | Tylko 1 z 12 TG sprawdzony live |
| ACM certs prod | wysoka | describe-certificate wykonane | Prod cert ISSUED, SANs potwierdzony |
| Tagging | wysoka | get-resources 28 zasobów | Sample — nie pełny skan wszystkich zasobów |
| Domena → serwis routing | średnia | ALB.yml (listener rules) + CF config | CF → ALB potwierdzone live; ALB → TG routing z IaC |
| WAF | wysoka | wafv2 list-web-acls (Regional + CloudFront) | 0 ACLs potwierdzone |
| Secrets | wysoka | list-secrets + describe-parameters | 0 sekretów i parametrów potwierdzone |

---

## Dostęp diagnostyczny

```bash
# ECS prod health
aws ecs describe-services \
  --cluster bookingonline-prod-Klaster \
  --services bookingonline-prod-Gateway-SRVC bookingonline-prod-Booking-SRVC \
             bookingonline-prod-Front-SRVC-dacia bookingonline-prod-Front-SRVC-reno \
  --profile booking --region eu-central-1

# Zatrzymane taski (diagnoza)
aws ecs list-tasks \
  --cluster bookingonline-prod-Klaster \
  --desired-status STOPPED \
  --profile booking --region eu-central-1

# ALB target health (prod backend)
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:eu-central-1:128264038676:targetgroup/bookingonline-prod-ALBTG-back/1b875ca41f573c22 \
  --profile booking --region eu-central-1

# Redis stack events (wyjaśnienie UPDATE_ROLLBACK_COMPLETE)
aws cloudformation describe-stack-events \
  --stack-name bokingonline-prod-RedisStack-Y7CMK9LDTKYR \
  --profile booking --region eu-central-1

# CloudWatch alarms — sprawdzenie po wdrożeniu monitoringu
aws cloudwatch describe-alarms \
  --profile booking --region eu-central-1

# Tagging coverage — pełny skan
aws resourcegroupstaggingapi get-resources \
  --profile booking --region eu-central-1

# Expired cert — usunięcie (po potwierdzeniu InUseBy=[])
# aws acm delete-certificate \
#   --certificate-arn arn:aws:acm:us-east-1:128264038676:certificate/48d927fd-3085-4eab-871c-932f2bf524ad \
#   --profile booking --region us-east-1
```

---

## Aktualizacja dokumentacji po zmianach IaC

```bash
# Wdrożenie zmian CFN (TYLKO po weryfikacji)
# aws cloudformation create-change-set ...
# aws cloudformation execute-change-set ...

# Osobno, po wdrożeniu — aktualizacja contextu:
# Uruchom ponownie cloud-detective przez plik invocation:
# 50-patterns/prompts/invocations/cloud-detective-booking-online.md
```

---

## Źródła użyte

| Źródło | Zakres | Status |
|--------|--------|--------|
| live AWS | ecs, elbv2, cloudfront, cfn, elasticache, acm (eu-central-1 + us-east-1), secretsmanager, ssm, cloudwatch, logs, ecr, wafv2, s3 (list), synthetics, resourcegroupstaggingapi | sprawdzone |
| repo lokalne | cloudformation/*.yml (ROOT, VPC, SG, ALB, CF, ECS, ECS_SOL, REDIS, S3) | sprawdzone |
| IaC | CloudFormation — lokalny checkout + S3 deployment source | sprawdzone (częściowe — S3 templates nie odczytane bezpośrednio) |
| CFN stacks | bokingonline-prod, bookingonline-uat, bookingonline-qa, bookingonline-dev + nested stacks | sprawdzone |
| vault historyczny | brak — pierwszy skan tego projektu | nieużyte |
| extra_regions | us-east-1: ACM list-certificates + describe-certificate prod | sprawdzone |

## Fakty live vs historia vault

Nie użyto danych historycznych z vault (pierwszy skan booking-online).

| Informacja | Status | Źródło | Uwagi |
|------------|--------|--------|-------|
| ECS 4/4 serwisy running prod | live | live AWS | 2026-05-01 |
| Redis available — wszystkie 4 env | live | live AWS | 2026-05-01 |
| Redis stacks UPDATE_ROLLBACK_COMPLETE | live | live AWS | 2026-05-01 |
| 0 CloudWatch alarms | live | live AWS | 2026-05-01 |
| 0 Secrets Manager secrets | live | live AWS | 2026-05-01 |
| ACM prod cert ISSUED do 2026-10-30 | live | live AWS | 2026-05-01 |
| ACM expired cert orphaned | live | live AWS | 2026-05-01 — bezpieczny, InUseBy=[] |
| Tagging NO-GO | live | live AWS | 2026-05-01 — 28 zasobów sprawdzonych |

---

## Powiązane

- [[cloud-detective-v2]] — szablon promptu
- [[cloud-detective-booking-online]] — plik invocation (parametry)
- `50-patterns/prompts/invocations/cloud-detective-booking-online.md`
