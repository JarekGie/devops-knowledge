---
date: 2026-04-24
project: rshop
tags: [rshop, tagging, finops, audit, tag-policy]
domain: client-work/mako
---

# RSHOP AWS TAGGING BASELINE — 2026-04-24

Audyt przeprowadzony: 2026-04-24, konto 943111679945 (eu-central-1), profil CLI `rshop`.
Kontekst: po incydencie 2026-04-20 (Tag Policy violation → ENI ENI tagging → prod 503) i tymczasowym wyłączeniu Tag Policies przez `terraform destroy`.

---

## 1. Executive Summary

Konto rshop posiada **dwa schematy tagowania** funkcjonujące równocześnie: nowy schemat LLZ (`Project/Environment/Owner/ManagedBy/CostCenter`) stosowany w prod/dev/akcesoria2 przez CloudFormation oraz stary schemat legacy (`Client/Maintainer/Provisioner/Team/typ`) widoczny w zasobach zarządzanych wcześniej przez Tribecloud (VPC cos\_dev, S3 rshop-cf, rshop-tmp, rshopp-logs). Wszystkie trzy środowiska ECS mają **propagateTags=NONE** w CFN (drift w prod: runtime SERVICE, niezarządzany przez CFN). Zadania (tasks) i interfejsy sieciowe (ENI) **nie dziedziczą tagów serwisów** — to był bezpośredni powód incydentu 2026-04-20. Przed ponownym wdrożeniem Tag Policies wymagane są zmiany w 5 szablonach CFN (rshop: api/backoffice/frontend/frontend2 + akcesoria2: svc.yml) oraz weryfikacja allowedValues dla projektu `akcesoria2` w LLZ Tag Policy. Zasoby niemanaged CFN (rshop-temp, rshop-dev-backup, rshop-dev-bk, terraform-states-rshop, ECR rshopapp-qa/uat, niektóre VPC endpoints) mają niekompletne lub zerowe tagi. Log groups mają retencję 1 dzień (prod/dev) — brak tagów, brak retencji.

---

## 2. Zaobserwowane klucze tagów w koncie

### Schemat LLZ / nowy (stosowany przez CloudFormation od ~2022 na zasobach rshop-prod i rshop-dev)

| Klucz | Typowe wartości | Pokrycie |
|-------|----------------|----------|
| `Project` | rshop, akcesoria2 | wysoki (CFN-managed) |
| `Environment` | prod, dev | wysoki (CFN-managed) |
| `Owner` | DC-devops, DC/IT | wysoki (CFN-managed prod/dev, akcesoria2) |
| `ManagedBy` | cloudformation | wysoki (CFN-managed) |
| `CostCenter` | DC | wysoki (CFN-managed) |
| `Name` | rshop-prod-X | wysoki (CFN-managed) |
| `Service` | backoffice, api, frontend-renault, frontend-dacia | częściowy (ECS services) |

### Schemat legacy / Tribecloud (zasoby stare, ręcznie tworzone)

| Klucz | Typowe wartości |
|-------|----------------|
| `Client` | Reno/Dacia |
| `Maintainer` | 3rd party - Tribecloud |
| `Provisioner` | manual, cloudformation |
| `Team` | DataCenter |
| `typ` | dev |

### Schemat hybryda (rshop-prod ECS services — drift po manualnej interwencji 2026-04-20)

Na serwisach rshop-prod widoczne są dodatkowe tagi poza CFN-schematem, dodane ręcznie lub przez inny mechanizm:
- `owner` = platform (małe litery, inne niż `Owner`)
- `environment` = prod (małe litery, inne niż `Environment`)
- `application` = rshop
- `service` = rshop-prod-backoffice-svc (pełna nazwa serwisu)

**Wniosek:** W koncie współistnieją 3 różne schematy tagowania. Konflikt case-sensitivity (`Owner` vs `owner`, `Environment` vs `environment`) może powodować nieprzewidywalne wyniki polityk tagowania AWS.

---

## 3. Podsumowanie per środowisko

### rshop-prod

- **CloudFormation stacks:** prod, prod-VPCStack, prod-SGStack, prod-IAMStack, prod-ALBStack, prod-ECSStack, prod-DBStack, prod-S3Stack, prod-CFStack + sub-stacki ECS dla backoffice/api/frontend-renault/frontend-dacia
- **Tags na stackach:** Project=rshop, Environment=prod, Owner=DC-devops, ManagedBy=cloudformation, CostCenter=DC — **kompletne** (potwierdzone)
- **ECS services (4):** rshop-prod-{backoffice,api,frontend-svc1,frontend-svc2}-svc — propagateTags=**SERVICE** (drift runtime vs CFN), enableECSManagedTags=**True** (drift), tags kompletne (z hybrydą owner/environment lowercase)
- **ALB prod-ALB:** Project/Environment/Owner/ManagedBy/CostCenter/Name — **kompletne**
- **RDS prod (pssa61v1phykq0):** Project/Environment/Owner/ManagedBy/CostCenter/Name — **kompletne**
- **S3 rshop-prod:** Project/Environment/Owner/ManagedBy/CostCenter/Name — **kompletne** (CFN-managed)
- **VPC Endpoints (prod, 4):** Owner/ManagedBy/CostCenter/Name — brakuje **Project** (2/4) i **Environment** (0/4) (potwierdzone)
- **VPC rshop-prod-VPC:** kompletne

### rshop-dev

- **CloudFormation stacks:** dev, dev-VPCStack, dev-SGStack, dev-IAMStack, dev-ECSStack + sub-stacki — tags na sub-stackach: Project/Environment/Owner/ManagedBy/CostCenter — kompletne, ale root stack `dev` i `dev-ECSStack-1BLAWHL0P6JKO` mają **puste Tags**
- **ECS services (4):** rshop-dev-{backoffice,api,frontend-svc1,frontend-svc2}-svc — propagateTags=**NONE**, enableECSManagedTags=**False**, tags na serwisach kompletne (Project/Environment/Owner/ManagedBy/CostCenter)
- **ALB dev-ALB:** stary schemat (Maintainer/Provisioner/Team/Client/typ) — zarządzany przez `dev-alb-ownership` CFN stack (migrated) — brakuje Owner, ManagedBy=cloudformation, ale brakuje CostCenter i Project (potwierdzone)
- **RDS dev:** Project/Environment/Owner/ManagedBy/CostCenter/Name — kompletne
- **S3 rshop-dev:** kompletne (CFN-managed)
- **S3 rshop-dev-backup:** brak tagów
- **S3 rshop-dev-bk:** brak tagów
- **VPC Endpoints (dev, 4):** Owner/ManagedBy/CostCenter/Name — brakuje **Project** i **Environment** (wszystkie 4) (potwierdzone)
- **VPC cos\_dev (vpc-0f46b727b63c49da3):** stary schemat Tribecloud (Client/Provisioner/Team/Maintainer), ale ma też Environment/Project (inferred: legacy VPC)

### akcesoria2-prod

- **CloudFormation stacks:** akcesoria2-prod (root, puste Tags), akcesoria2-prod-ECSStack, akcesoria2-prod-SGStack, akcesoria2-prod-IAMStack, akcesoria2-prod-ECRStack, akcesoria2-prod-SVCStack — sub-stacki mają Project=akcesoria2, Environment=prod, Owner=DC/IT, ManagedBy=cloudformation, CostCenter=DC
- **ECS services (2):** akcesoria2-prod-{dacia,renault}-svc — propagateTags=**NONE**, enableECSManagedTags=**False**, tags kompletne (Project/Environment/Owner/ManagedBy/CostCenter/Name)
- **CFN template svc.yml:** Tags zdefiniowane na ECS services (Name/Project/Environment/Owner/ManagedBy/CostCenter) — brakuje `PropagateTags` i `EnableECSManagedTags`

### QA / UAT / orphany

- **rshop-qa-Klaster:** log group `/aws/ecs/containerinsights/rshop-qa-Klaster/performance` istnieje (storedBytes=0) — potwierdza, że klaster QA był usunięty ale log group nie (lub recreated). Brak aktywnych serwisów/stacków QA.
- **ECR rshopapp-qa:** istnieje (tags: Environment=qa, typ=qa) — brak Project, brak Owner, ManagedBy, CostCenter (potwierdzone braki)
- **ECR rshopapp-uat:** istnieje (tags: Environment=uat, typ=uat) — analogiczne braki
- **task-definition qa-api-task:335:** istnieje w ECS — remnant po środowisku QA (usuniętym marzec 2026)
- **task-definition jumhost-qa:5:** istnieje — orphan
- **log group `/ecs/jumhost-qa`:** istnieje — orphan (literówka w nazwie)

---

## 4. ECS — gotowość do Tag Policy

### rshop-prod (cluster: rshop-prod-Klaster)

| Serwis | propagateTags (live) | propagateTags (CFN) | enableECSManagedTags | Tags na serwisie | ENI dziedziczą tagi | Gotowość Tag Policy |
|--------|---------------------|---------------------|---------------------|-----------------|--------------------|--------------------|
| rshop-prod-backoffice-svc | SERVICE (drift) | **BRAK** | True (drift) | Project/Env/Owner/ManagedBy/CC + hybrid lowercase | **TAK** (runtime, drift) | NO-GO — CFN nie odzwierciedla, redeployment zresetuje |
| rshop-prod-frontend-svc1 | SERVICE (drift) | **BRAK** | True (drift) | Project/Env/Owner/ManagedBy/CC + hybrid lowercase | **TAK** (runtime, drift) | NO-GO — jak wyżej |
| rshop-prod-frontend-svc2 | SERVICE (drift) | **BRAK** | True (drift) | Project/Env/Owner/ManagedBy/CC + hybrid lowercase | **TAK** (runtime, drift) | NO-GO — jak wyżej |
| rshop-prod-api-svc | SERVICE (drift) | **BRAK** | True (drift) | Project/Env/Owner/ManagedBy/CC + hybrid lowercase | **TAK** (runtime, drift) | NO-GO — CFN nie odzwierciedla |

**Uwaga krytyczna:** rshop-prod aktualnie NIE produkuje nowych ENI bez tagów (propagateTags=SERVICE runtime), ale CFN template nie zawiera `PropagateTags: SERVICE`. Każdy deploy przez CFN (update stack) zresetuje propagateTags do domyślnego (NONE) i ponownie złamie Tag Policy.

### rshop-dev (cluster: rshop-dev-Klaster)

| Serwis | propagateTags (live) | propagateTags (CFN) | enableECSManagedTags | Tags na serwisie | ENI dziedziczą tagi | Gotowość Tag Policy |
|--------|---------------------|---------------------|---------------------|-----------------|--------------------|--------------------|
| rshop-dev-backoffice-svc | NONE | BRAK | False | kompletne | **NIE** | NO-GO |
| rshop-dev-frontend-svc1 | NONE | BRAK | False | kompletne | **NIE** | NO-GO |
| rshop-dev-frontend-svc2 | NONE | BRAK | False | kompletne | **NIE** | NO-GO |
| rshop-dev-api-svc | **SERVICE** ✓ | BRAK | **True** ✓ | kompletne | **TAK** ✓ | **GO** — zwalidowane 2026-04-24 |

### akcesoria2-prod (cluster: akcesoria2-prod-Klaster)

| Serwis | propagateTags (live) | propagateTags (CFN) | enableECSManagedTags | Tags na serwisie | ENI dziedziczą tagi | Gotowość Tag Policy |
|--------|---------------------|---------------------|---------------------|-----------------|--------------------|--------------------|
| akcesoria2-prod-dacia-svc | NONE | BRAK | False | kompletne (Name/Project/Env/Owner/ManagedBy/CC) | **NIE** | NO-GO |
| akcesoria2-prod-renault-svc | NONE | BRAK | False | kompletne (Name/Project/Env/Owner/ManagedBy/CC) | **NIE** | NO-GO |

---

## 5. Pokrycie tagów per rodzina zasobów

| Rodzina | Liczba zasobów | Project | Environment | Owner | ManagedBy | CostCenter | Uwagi |
|---------|---------------|---------|-------------|-------|-----------|-----------|-------|
| ECS Cluster (3) | 3 | TAK | TAK | PARTIAL | PARTIAL | PARTIAL | brak tagów na klastrze akcesoria2-prod (inferred z nazwy) |
| ECS Service (10) | 10 | TAK | TAK | TAK (9/10) | TAK (9/10) | TAK (9/10) | dev-ALB cluster svc brakujące Owner/CC |
| ECS Task Definition | ~25 aktywnych | n/d | n/d | n/d | n/d | n/d | task-defs nie mają tagów w koncie |
| CloudFormation Stack (34) | 34 | TAK (32) | TAK (32) | TAK (prod/akcesoria2) | TAK (CFN-managed) | TAK (prod/akcesoria2) | root stacki (dev, prod, akcesoria2-prod) mają puste Tags |
| VPC (3) | 3 | TAK | TAK | PARTIAL | PARTIAL | PARTIAL | cos\_dev = stary schemat |
| Subnet (15) | 15 | TAK | TAK | PARTIAL | PARTIAL | PARTIAL | 3 subnety w cos\_dev VPC bez Owner/CC |
| Security Group (15) | 15 | TAK (12) | TAK (12) | TAK (12) | TAK (12) | TAK (12) | default SG + launch-wizard-1 = brak tagów |
| VPC Endpoint (8) | 8 | PARTIAL (4) | PARTIAL (4) | TAK | TAK | TAK | prod endpoints brakuje Project; dev brakuje Project+Environment |
| ALB (2) | 2 | TAK (1) | TAK (1) | PARTIAL | PARTIAL | PARTIAL | dev-ALB stary schemat (Tribecloud) |
| RDS (2) | 2 | TAK | TAK | TAK | TAK | TAK | kompletne |
| S3 (10) | 10 | TAK (7) | TAK (7) | PARTIAL | PARTIAL | PARTIAL | rshop-dev-backup/bk/temp = 0 tagów; terraform-states-rshop = 0 tagów |
| ECR (5) | 5 | PARTIAL (2) | TAK | NIE (3) | NIE (3) | NIE (3) | rshopapp-qa/uat/prod brakuje Project/Owner/ManagedBy/CostCenter |
| CloudFront (4) | 4 | ? | ? | ? | ? | ? | CloudFront jest global — nie sprawdzono tagów (poza scope eu-central-1) |
| CloudWatch Log Group (15) | 15 | NIE | NIE | NIE | NIE | NIE | brak tagów na log groups; retencja 1d na prod/dev |
| VPC Endpoint (ENI) | ~wiele | **BRAK** | **BRAK** | **BRAK** | **BRAK** | **BRAK** | ENI nie dziedziczą — root cause incydentu |

---

## 6. Wysokoimpaktowe luki tagowania (ranking)

### #1 — KRYTYCZNE: Brak PropagateTags/EnableECSManagedTags w CFN (wszystkie środowiska)

- **Co:** Żaden z 5 szablonów CFN nie zawiera `PropagateTags: SERVICE` ani `EnableECSManagedTags: true`
- **Skutek:** Każdy deploy przez CFN zresetuje propagateTags do NONE. ENI nowych zadań nie będą tagowane. Kolejne uruchomienie Tag Policies → natychmiastowe naruszenie → 503.
- **Pliki:** api.yml, backoffice.yml, frontend.yml, frontend2.yml (rshop-cloudformation) + svc.yml (akcesoria2)
- **Status:** potwierdzone

### #2 — KRYTYCZNE: Brak Tags na ECS Services w CFN (rshop-cloudformation)

- **Co:** api.yml, backoffice.yml, frontend.yml, frontend2.yml — `AWS::ECS::Service` nie ma sekcji `Tags`
- **Skutek:** Tagi serwisów pochodzą z tags propagacji stacku CFN, nie z resource-level Tags. Przy Tag Policy resource-level, tag compliance serwisu zależy od mechanizmu propagacji — nieprzewidywalne.
- **Status:** potwierdzone (grep na 4 plikach: 0 trafień dla Tags w sekcji ECS Service)

### #3 — WYSOKIE: Konflikt schematów tagowania (case-sensitivity)

- **Co:** Tagi na rshop-prod serwisach zawierają zarówno `Owner=DC-devops` jak i `owner=platform`, `Environment=prod` i `environment=prod`
- **Skutek:** Tag Policy AWS jest case-sensitive. Jeśli polityka wymaga `Environment` z wartością `prod`, tag `environment` nie spełni wymogu.
- **Status:** potwierdzone

### #4 — WYSOKIE: Brak tagów na VPC Endpoints (prod i dev)

- **Co:** Wszystkie 8 VPC Endpoints nie mają `Project` i/lub `Environment`
- **Skutek:** Przy Tag Policy wymagającej Project+Environment na ec2 (VPC endpoints są ec2:VpcEndpoint) — violation
- **Status:** potwierdzone

### #5 — WYSOKIE: ECR repozytoria rshopapp-qa/uat/prod niekompletnie otagowane

- **Co:** rshopapp-qa, rshopapp-uat — brakuje Project, Owner, ManagedBy, CostCenter; rshopapp-prod — brakuje Project
- **Skutek:** ECR objęty Tag Policy → violation przy re-enable
- **Status:** potwierdzone

### #6 — ŚREDNIE: S3 orphany bez tagów

- **Co:** rshop-dev-backup, rshop-dev-bk, rshop-temp, terraform-states-rshop — brak jakichkolwiek tagów
- **Skutek:** Niewidoczne w raportach FinOps; potencjalne violation Tag Policy
- **Status:** potwierdzone

### #7 — ŚREDNIE: Stary schemat na dev-ALB i VPC cos_dev

- **Co:** dev-ALB używa Tribecloud-schema (Client/Maintainer/Provisioner/Team/typ); VPC cos\_dev analogicznie
- **Skutek:** Niezgodność z LLZ Tag Policy; brak ManagedBy=cloudformation
- **Status:** potwierdzone

### #8 — NISKIE: Brak tagów na CloudWatch Log Groups

- **Co:** Wszystkie log groups (15) nie mają żadnych tagów. Retencja 1 dzień na /ecs/rshop-prod i /ecs/rshop-dev — ryzyko utraty logów przy incydentach.
- **Skutek:** Niewidoczne w FinOps; retencja 1d = utrata logów starszych niż 1 dzień (potencjalny problem audytowy)
- **Status:** potwierdzone

---

## 7. QA / UAT / orphany

### Znalezione remnants po środowisku QA (usuniętym marzec 2026)

| Zasób | ID / Nazwa | Stan | Akcja |
|-------|-----------|------|-------|
| ECS task definition | qa-api-task:335 | ACTIVE | deregister (jeśli nieużywane) |
| ECS task definition | jumhost-qa:5, :4, :3, :2, :1 | ACTIVE | deregister |
| CloudWatch Log Group | /aws/ecs/containerinsights/rshop-qa-Klaster/performance | storedBytes=0, retention=1d | można usunąć |
| CloudWatch Log Group | /ecs/jumhost-qa | storedBytes=0, retention=1d | usunąć (literówka w nazwie) |
| ECR repository | rshopapp-qa | istnieje, tagi: Environment=qa, typ=qa | ocena: czy pipeline QA będzie reaktywowany? |

### ECR rshopapp-uat

- Repozytorium istnieje, tagi: Environment=uat, typ=uat — brakuje Owner, ManagedBy, CostCenter, Project
- Środowisko UAT nieaktywne (brak stacków UAT w CFN). Status: orphan lub remnant
- **Uwaga:** loggroup `/esc/backoffice` (literówka!) istnieje — storedBytes=0

### Zasoby bez przypisania środowiska

- `terraform-states-rshop`: S3 bucket bez tagów
- `943111679945-terraform-state-bucket`: tags tylko Environment=dev, typ=dev — brakuje Project, Owner, ManagedBy, CostCenter
- `dynamodb/terraform-state-lock`: brakuje Project (confirmed)

---

## 8. Własność CloudFormation

| Stack/Zasób | Szablon | Repo | Właściciel |
|-------------|---------|------|-----------|
| prod-* stacks | własne repo cfn | rshop-cloudformation/cloudformation/ | DC-devops |
| dev-* stacks | własne repo cfn | rshop-cloudformation/cloudformation/ | DC-devops |
| akcesoria2-prod-* stacks | aws-projects | infra-rshop/cloudformation/akcesoria2/ | DC/IT |
| dev-ALB (dev-alb-ownership) | inline/migracja | nieznany | DC-devops (legacy Tribecloud) |
| cos\_dev VPC | ręczny/Tribecloud | brak (manual) | legacy — Tribecloud |
| rshop-cf, rshop-tmp, rshopp-logs S3 | ręczny | brak (manual) | legacy — Tribecloud |

---

## 9. Ocena gotowości do Tag Policy

> Definicja: "gotowy" = ponowne wdrożenie LLZ Tag Policies (przez terraform apply) nie spowoduje naruszenia dla żadnego zasobu w scope polityki.

| Zakres | Gotowość | Uzasadnienie |
|--------|----------|-------------|
| rshop-prod ECS Services | **NO-GO** | propagateTags=SERVICE tylko runtime (drift), CFN nie ma PropagateTags/Tags — następny deploy CFN resetuje do NONE → TagPolicyViolation na ENI |
| rshop-dev ECS Services | **NO-GO** | propagateTags=NONE, CFN nie ma PropagateTags — ENI nigdy nie są tagowane |
| akcesoria2-prod ECS Services | **NO-GO** | propagateTags=NONE, CFN nie ma PropagateTags — ENI nigdy nie są tagowane |
| rshop-prod VPC/Subnets/SG | **PARTIAL** | CFN-managed zasoby mają kompletne tagi; VPC endpoints brakuje Project |
| rshop-dev VPC/Subnets/SG | **PARTIAL** | CFN-managed zasoby mają tagi; VPC endpoints brakuje Project+Environment; dev-ALB stary schemat |
| ECR repozytoria | **NO-GO** | rshopapp-prod/qa/uat brakuje wymaganych tagów |
| S3 buckets | **PARTIAL** | CFN-managed mają tagi; orphany (backup/bk/temp/terraform-states) bez tagów |
| CloudWatch Log Groups | **NO-GO** | brak tagów na wszystkich log groups |
| RDS | **TAK** | kompletne tagi na obu instancjach |
| ALB prod | **TAK** | kompletne tagi |
| ALB dev | **NO-GO** | stary schemat Tribecloud — brakuje Owner, CostCenter, ManagedBy, Project |

**Ogólna ocena: NO-GO** — re-enable Tag Policies bez uprzedniego fix CFN + tag remediation spowoduje powtórkę incydentu 2026-04-20.

---

## 10. Rekomendowane następne kroki

### Priorytet 1 — BLOKERZY (przed re-enable Tag Policies)

1. **Fix CFN: rshop-cloudformation** — dodać do każdego `AWS::ECS::Service` (api.yml, backoffice.yml, frontend.yml, frontend2.yml):
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
   ```

2. **Fix CFN: akcesoria2/svc.yml** — dodać `PropagateTags: SERVICE` i `EnableECSManagedTags: true` do DaciaSvc i RenaultSvc (Tags już są zdefiniowane — tylko 2 linie brakuje per serwis)

3. **Deploy dev → weryfikacja** — uruchomić update stack na dev, sprawdzić czy nowe ENI (ENI Fargate task) mają tagi

4. **Deploy prod** — po walidacji dev

5. **Weryfikacja allowedValues** — sprawdzić czy LLZ Tag Policy allowedValues dla `Project` zawiera `akcesoria2` (nie tylko `rshop`)

### Priorytet 2 — Tag remediation (nie blokuje Tag Policy re-enable jeśli poza scopem)

6. **VPC Endpoints (8)** — dodać Project+Environment do wszystkich (prod: 4 endpoints, dev: 4 endpoints) — można przez CFN lub CLI (endpointy są w EndPoinTs/EndPoints stackach)

7. **ECR repozytoria** — dodać Project, Owner, ManagedBy, CostCenter do rshopapp-prod/qa/uat/dev

8. **S3 orphany** — otagować lub usunąć: rshop-dev-backup, rshop-dev-bk, rshop-temp, terraform-states-rshop

9. **dev-ALB** — zmigować na nowy schemat tagów (dodać Owner=DC-devops, CostCenter=DC, Project=rshop; zachować istniejące jako addytywne)

### Priorytet 3 — Cleanup

10. **Orphany QA:** deregister task definitions qa-api-task, jumhost-qa; usunąć log groups /ecs/jumhost-qa, /aws/ecs/containerinsights/rshop-qa-Klaster/performance

11. **Retencja log groups:** zmienić /ecs/rshop-prod i /ecs/rshop-dev z 1 dnia na min. 14 lub 30 dni

12. **Konflikt case:** ustalić czy tagi `owner`/`environment` (lowercase) na prod serwisach mogą zostać usunięte, lub czy są wymagane przez inny system

---

## Załącznik: Stan ECS task definitions (aktywne)

| Task Definition | Wersja | Klaster | Środowisko |
|----------------|--------|---------|-----------|
| prod-backoffice-task | :388 | rshop-prod-Klaster | prod |
| prod-frontend-task | :957, :956 | rshop-prod-Klaster | prod (2 serwisy) |
| prod-api-task | :387 | rshop-prod-Klaster | prod |
| dev-backoffice-task | :1039 | rshop-dev-Klaster | dev |
| dev-frontend-task | :1893, :1892 | rshop-dev-Klaster | dev |
| dev-api-task | :1040 | rshop-dev-Klaster | dev |
| akcesoria2-prod-dacia | :7 | akcesoria2-prod-Klaster | prod |
| akcesoria2-prod-renault | :7 | akcesoria2-prod-Klaster | prod |
| qa-api-task | :335 | brak (QA usunięte) | **orphan** |
| jumhost-qa | :5 | brak | **orphan** |

---

---

## 11. Log walidacji — 2026-04-24 (popołudnie)

### rshop-dev-api-svc — force-new-deployment + weryfikacja ENI

**Kontekst:** Change set `propagateTags=SERVICE` + `enableECSManagedTags=true` wykonany wcześniej, ale żaden nowy task nie wystartował — aktywny task żył od 2026-04-14. ENI starego taska miał `TagSet=[]`.

**Wykonano:**
1. PRE-CHECK: desired=1, running=1, pending=0, propagateTags=SERVICE, enableECSManagedTags=true → GO
2. `aws ecs update-service --force-new-deployment` na `rshop-dev-api-svc`
3. Rollout: IN\_PROGRESS (pending=1) → COMPLETED w ~2 minuty

**Nowy task:**
- ARN: `arn:aws:ecs:eu-central-1:943111679945:task/rshop-dev-Klaster/3db0d4e07c1d48ed9ebe5bbbc5ecf0a3`
- Created: `2026-04-24T19:17:11`
- ENI: `eni-018a89285883e88ff`

**Tagi na nowym ENI — wszystkie 6 wymaganych:**

| Tag | Wartość |
|-----|---------|
| Project | rshop |
| Environment | dev |
| Owner | DC-devops |
| ManagedBy | cloudformation |
| CostCenter | DC |
| Service | api |
| aws:ecs:clusterName | rshop-dev-Klaster *(ECS managed)* |
| aws:ecs:serviceName | rshop-dev-api-svc *(ECS managed)* |

**Verdict:** Tag propagation działa end-to-end. `rshop-dev-api-svc` → **GO**.

**Następny krok:** Force-new-deployment na pozostałe 3 dev serwisy (backoffice, frontend-svc1, frontend-svc2) po wykonaniu identycznego change setu dla każdego. Procedura identyczna — ten sam pre-check przed każdym.

---

*Audyt: read-only, brak zmian w AWS. Dane z: aws ecs/cloudformation/resourcegroupstaggingapi/ec2/elbv2/rds/s3api/ecr (eu-central-1, 2026-04-24).*
*Walidacja ENI: 2026-04-24 19:17 (force-new-deployment rshop-dev-api-svc).*
*Powiązane: [[rshop-tag-policy-readiness]] | [[finops-rshop]]*
