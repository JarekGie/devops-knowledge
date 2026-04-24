# ChatGPT Context Pack — rshop Tag Policy remediation

> Wklej całość na początku rozmowy z ChatGPT.

**Zakres:** rshop — CFN fix ECS PropagateTags, tag remediation, pre-audit data (2026-04-24)
**Data audytu:** 2026-04-24 (read-only, AWS CLI, konto 943111679945)

---

## Rola i kontekst

Senior DevOps/SRE. Projekt rshop = e-commerce Renault/Dacia (sklep.renault.pl i 7 innych domen). AWS ECS Fargate, CloudFormation, eu-central-1, konto 943111679945, profil CLI `rshop`.

Był incydent PROD (2026-04-20): HTTP 503 przez ECS TagPolicyViolation. Tag Policies LLZ są aktualnie WYŁĄCZONE. Przed ponownym wdrożeniem wymagane zmiany CFN.

---

## Infrastruktura

```
AWS Account:  943111679945
Region:       eu-central-1
IaC:          CloudFormation (nie Terraform)
Profile CLI:  rshop

Klastry ECS:
  rshop-prod-Klaster     → sklep.renault.pl, eshop.renault.{cz,sk,hu}, dacia equiv.
  rshop-dev-Klaster
  akcesoria2-prod-Klaster → akcesoria.{renault,dacia}.pl

Serwisy ECS (prod):
  rshop-prod-backoffice-svc  rshop-prod-frontend-svc1
  rshop-prod-frontend-svc2   rshop-prod-api-svc

Serwisy ECS (dev — identyczna struktura nazw):
  rshop-dev-backoffice-svc  rshop-dev-frontend-svc1
  rshop-dev-frontend-svc2   rshop-dev-api-svc

Serwisy ECS (akcesoria2):
  akcesoria2-prod-dacia-svc  akcesoria2-prod-renault-svc

Baza danych: SQL Server RDS (eu-central-1) — jedyne zewnętrzne połączenie
Redis/RabbitMQ: nie istnieją w tym koncie
```

---

## Root cause incydentu (2026-04-20)

ECS Fargate tworzy ENI (Elastic Network Interface) przy każdym nowym tasku. Tag Policy LLZ wymaga tagów `Environment` + `Project` na `ec2:network-interface`. Serwisy miały `propagateTags=SERVICE` (lub NONE) ustawione manualnie po incydencie, ale szablony CFN **nigdy nie zawierały** `PropagateTags: SERVICE`. Następny deploy przez CFN zresetuje propagateTags do domyślnego (NONE) → ENI bez tagów → TagPolicyViolation → task nie startuje → 503.

Fix doraźny 2026-04-20: `terraform destroy` Tag Policies (LLZ). Serwisy wstały automatycznie.

---

## Aktualny stan (potwierdzony AWS CLI 2026-04-24)

### ECS services — propagateTags

| Klaster | Serwis | propagateTags LIVE | propagateTags CFN | enableECSManagedTags | ENI tagowane? |
|---------|--------|-------------------|-------------------|---------------------|---------------|
| prod | backoffice-svc | SERVICE (drift) | **BRAK** | True (drift) | TAK (tymczasowo) |
| prod | frontend-svc1 | SERVICE (drift) | **BRAK** | True (drift) | TAK (tymczasowo) |
| prod | frontend-svc2 | SERVICE (drift) | **BRAK** | True (drift) | TAK (tymczasowo) |
| prod | api-svc | SERVICE (drift) | **BRAK** | True (drift) | TAK (tymczasowo) |
| dev | backoffice-svc | **NONE** | **BRAK** | False | **NIE** |
| dev | frontend-svc1 | **NONE** | **BRAK** | False | **NIE** |
| dev | frontend-svc2 | **NONE** | **BRAK** | False | **NIE** |
| dev | api-svc | **NONE** | **BRAK** | False | **NIE** |
| akcesoria2 | dacia-svc | **NONE** | **BRAK** | False | **NIE** |
| akcesoria2 | renault-svc | **NONE** | **BRAK** | False | **NIE** |

**WNIOSEK:** Wszystkie 10 serwisów ECS = NO-GO dla Tag Policy re-enable.
Prod działa tylko dlatego, że tagi zostały ustawione ręcznie po incydencie — każdy update stacku CFN je zresetuje.

### CFN templates — co brakuje (potwierdzone grep)

| Plik | PropagateTags | EnableECSManagedTags | Tags na ECS Service |
|------|--------------|----------------------|---------------------|
| `rshop-cloudformation/cloudformation/api.yml` | **BRAK** | **BRAK** | **BRAK** |
| `rshop-cloudformation/cloudformation/backoffice.yml` | **BRAK** | **BRAK** | **BRAK** |
| `rshop-cloudformation/cloudformation/frontend.yml` | **BRAK** | **BRAK** | **BRAK** |
| `rshop-cloudformation/cloudformation/frontend2.yml` | **BRAK** | **BRAK** | **BRAK** |
| `infra-rshop/cloudformation/akcesoria2/svc.yml` | **BRAK** | **BRAK** | **JEST** (Name/Project/Environment/Owner/ManagedBy/CostCenter) |

### Schemat tagowania w koncie

W koncie współistnieją 3 schematy (potwierdzone):
- **LLZ/nowy** (CFN-managed): `Project`, `Environment`, `Owner`, `ManagedBy`, `CostCenter`, `Name`
- **Legacy Tribecloud**: `Client`, `Maintainer`, `Provisioner`, `Team`, `typ` — na starych zasobach (VPC cos_dev, dev-ALB, S3 rshop-cf)
- **Hybryda lowercase** (manual, drift prod): `owner`, `environment`, `application`, `service` — dodane ręcznie do prod serwisów po incydencie

Konflikt case-sensitivity: `Owner=DC-devops` i `owner=platform` istnieją jednocześnie na prod serwisach. Tag Policy AWS jest case-sensitive.

---

## Co dokładnie trzeba dodać do CFN

### Przypadek A — rshop-cloudformation (api/backoffice/frontend/frontend2.yml)

Do każdego `AWS::ECS::Service` dodać:

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
    Value: <backoffice|api|frontend-renault|frontend-dacia>
```

Parametry (`!Ref Projekt`, `!Ref Srodowisko`) istnieją już w szablonach — używane w innych zasobach.

### Przypadek B — akcesoria2/svc.yml (DaciaSvc, RenaultSvc)

Tags **już są** zdefiniowane poprawnie. Brakuje tylko 2 linii per serwis:

```yaml
PropagateTags: SERVICE
EnableECSManagedTags: true
```

---

## Lokalne ścieżki repozytoriów

```
~/projekty/mako/rshop-cloudformation/cloudformation/
  api.yml
  backoffice.yml
  frontend.yml
  frontend2.yml

~/projekty/mako/aws-projects/infra-rshop/cloudformation/akcesoria2/
  svc.yml
```

---

## Bezpieczna kolejność deploymentów

```
1. Fix CFN rshop-cloudformation (4 pliki) — feature branch, code review
2. Deploy dev (aws cloudformation update-stack)
   → weryfikacja: aws ecs describe-services --query propagateTags → SERVICE
   → weryfikacja ENI tagów na nowym tasku
3. Deploy prod
4. Fix CFN akcesoria2/svc.yml + deploy
5. Weryfikacja allowedValues LLZ Tag Policy: czy 'akcesoria2' jest w Project allowedValues
   (sprawdzić w repo aws-cloud-platform / LLZ terraform)
6. terraform apply Tag Policies (LLZ)
7. Monitoring 24h: CloudTrail na TagPolicyViolation, ECS desiredCount vs runningCount
```

**ZASADA:** Nigdy Tag Policies aktywne przy deploymencie bez naprawionych szablonów.
**ROLLBACK:** terraform destroy Tag Policies (jak 2026-04-20) — odblokuje ECS natychmiast.

---

## Inne luki (nie blokują ECS, ale blokują pełny Tag Policy compliance)

| Problem | Zasób | Priorytet |
|---------|-------|-----------|
| Brak Project+Environment | VPC Endpoints (8 sztuk, prod+dev) | WYSOKIE |
| Brak Project/Owner/ManagedBy/CostCenter | ECR rshopapp-prod/qa/uat | WYSOKIE |
| Stary schemat Tribecloud | dev-ALB, VPC cos_dev | WYSOKIE |
| Brak tagów | S3 orphany (rshop-dev-backup, rshop-dev-bk, rshop-temp, terraform-states-rshop) | ŚREDNIE |
| Brak tagów | CloudWatch Log Groups (wszystkie 15) | NISKIE |
| Retencja 1 dzień | /ecs/rshop-prod, /ecs/rshop-dev | NISKIE (odrębny problem) |

### Orphany QA (środowisko usunięte marzec 2026)

- task definition `qa-api-task:335` — aktywna, nieużywana
- task definition `jumhost-qa:5` — aktywna, nieużywana
- log group `/ecs/jumhost-qa` — literówka w nazwie, storedBytes=0
- log group `/aws/ecs/containerinsights/rshop-qa-Klaster/performance` — storedBytes=0
- ECR `rshopapp-qa`, `rshopapp-uat` — repozytoria istnieją, niekompletne tagi

---

## Szybki prompt dla ChatGPT

```
Pracujesz nad projektem rshop (e-commerce Renault/Dacia) w AWS eu-central-1, konto 943111679945, profil rshop. IaC: CloudFormation.

KONTEKST:
- Incydent PROD 2026-04-20: ECS TagPolicyViolation → HTTP 503. Przyczyna: ENI Fargate tasks
  tworzone bez tagów bo CFN nie ma PropagateTags: SERVICE w żadnym z szablonów.
- Fix doraźny: terraform destroy Tag Policies (LLZ). Aktualnie Tag Policies WYŁĄCZONE.
- rshop-prod: propagateTags=SERVICE ustawione ręcznie (drift), ale CFN tego nie odzwierciedla
  — każdy deploy przez CFN zresetuje do NONE → awaria przy ponownym re-enable Tag Policies.
- rshop-dev: propagateTags=NONE, nie taguje ENI wcale.
- akcesoria2-prod: Tags zdefiniowane w svc.yml, ale brak PropagateTags — ENI bez tagów.

REPOZYTORIA (lokalne):
  ~/projekty/mako/rshop-cloudformation/cloudformation/ → api/backoffice/frontend/frontend2.yml
  ~/projekty/mako/aws-projects/infra-rshop/cloudformation/akcesoria2/svc.yml

CO DODAĆ do każdego AWS::ECS::Service w rshop-cloudformation:
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

CO DODAĆ do DaciaSvc/RenaultSvc w akcesoria2/svc.yml (Tags już są):
  PropagateTags: SERVICE
  EnableECSManagedTags: true

KOLEJNOŚĆ: dev deploy → weryfikacja ENI tagów → prod deploy → akcesoria2 deploy →
  weryfikacja allowedValues LLZ Tag Policy (Project=akcesoria2?) → terraform apply Tag Policies.
```
