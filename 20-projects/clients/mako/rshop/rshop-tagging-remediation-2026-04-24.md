---
date: 2026-04-24
project: rshop
client: mako
tags: [rshop, tagging, remediation, finops, ecs, vpc-endpoints, tag-policy]
domain: client-work/mako
---

# RSHOP TAGGING REMEDIATION — 2026-04-24

## Executive Summary

Remediacja tagowania wykonana 2026-04-24 objęła ECS ENI tag propagation oraz manual drift reconciliation tagów na VPC Endpoints.

Stan końcowy:
- `rshop-dev`: 4/4 ECS services validated
- `rshop-prod`: 4/4 ECS services validated
- `akcesoria2-prod`: 2/2 ECS services validated

Łącznie:
- 10/10 ECS services confirmed with correct ENI tag propagation

Wymagane tagi zwalidowane:
- `Project`
- `Environment`
- `Owner`
- `ManagedBy`
- `CostCenter`
- `Service`

## ECS Remediation Pattern

### CloudFormation patch

Wzorzec remediacji ECS services:
- `PropagateTags: SERVICE`
- `EnableECSManagedTags: true`

### Safe nested change-set inspection approach

Bezpieczny przebieg dla nested stacks:
1. przygotować change set na root stacku z `--use-previous-template`
2. użyć `--include-nested-stacks`
3. sprawdzić root stack
4. zejść do nested ECS stack
5. zejść do poziomu pojedynczych service stacków
6. potwierdzić, że zmiany dotyczą wyłącznie `Properties/PropagateTags` i `Properties/EnableECSManagedTags`
7. dopiero po tej inspekcji wykonać change set

### Force-new-deployment validation method

Po wdrożeniu patcha sama zmiana CFN nie backfilluje tagów na istniejących taskach i ich ENI.

Wymagany wzorzec walidacji:
1. pre-check `propagateTags` i `enableECSManagedTags`
2. `aws ecs update-service --force-new-deployment`
3. poczekać na rollout do stanu completed
4. zidentyfikować nowy task
5. zidentyfikować ENI nowego taska
6. potwierdzić komplet tagów na ENI

### ENI evidence verification method

Evidence powinno potwierdzać:
- nowy task ARN po rollout
- nowy ENI ID przypisany do taska
- obecność tagów `Project`, `Environment`, `Owner`, `ManagedBy`, `CostCenter`, `Service`
- obecność ECS managed tags: `aws:ecs:serviceName`, `aws:ecs:clusterName`

### Finding

Istotne odkrycie operacyjne:
- istniejące taski nie dostają backfillu tagów
- tylko nowo uruchomione taski otrzymują poprawne tagi na ENI

To należy traktować jako reusable operational pattern dla ECS/Fargate remediation po zmianie `PropagateTags`.

## VPC Endpoint Drift Reconciliation

### DEV

Manual drift reconciliation wykonany dla 4 endpointów:
- `vpce-06fbbcc50008abf6d`
- `vpce-0adbca724b31df149`
- `vpce-055c1e81bc384fe77`
- `vpce-04a529e00f650ba57`

Dodane tagi:
- `Project=rshop`
- `Environment=dev`

Wynik po wykonaniu:
- focused compliance check zwrócił `[]`
- wszystkie endpointy pozostały `available`

### PROD

Manual drift reconciliation wykonany dla 3 interface endpoints:
- `vpce-05174e681737bc7a0`
- `vpce-04ab55e932a54733f`
- `vpce-00482d667b910fe3e`

Dodany tag:
- `Project=rshop`

Jawny wyjątek:
- `vpce-0ad2e4f5d5005bf1f` (`s3` gateway) pozostał bez manualnej zmiany, pending CFN alignment

### Handler drift finding

Istotne odkrycie:
- `CloudFormation UPDATE_COMPLETE` dla `AWS::EC2::VPCEndpoint` nie gwarantował, że tagi zostały fizycznie nałożone na live resource

Wniosek operacyjny:
- dla `AWS::EC2::VPCEndpoint` należy porównywać live tags z desired state template
- status CFN nie jest sam w sobie wystarczającym dowodem zgodności tagów

## FinOps Implications

Efekt remediacji:
- attribution dla `VpcEndpoint-Hours` uległ istotnej poprawie
- udział kosztów untagged powinien spaść w kolejnych raportach FinOps
- overall tagging coverage dla zakresu rshop powinna się poprawić

## Tag Policy Readiness

Stan po remediacji:
- zakres `rshop` jest conditionally ready do re-enable Tag Policy
- nie ma jednak evidence dla wszystkich kont i całego organization scope

Wniosek:
- można mówić o gotowości warunkowej dla zakresu rshop
- nie należy rozszerzać tego wniosku na cały AWS Organization bez osobnego evidence

## DEV CFN Deploy Failure — 2026-04-28

Objaw:
- Jenkins `create-change-set` przeszedł poprawnie
- `execute-change-set` zostało wywołane
- waiter zakończył się terminalnie: `Waiter StackUpdateComplete failed`

Kontekst:
- stack root: `dev`
- region: `eu-central-1`
- profil: `rshop`
- problem wystąpił po naprawie wcześniejszych parametrów `ALBDNS` / TG ARN

Root cause:
- pierwszym realnym błędem nie był ECS ani TagPolicyViolation
- leaf failure: `dev-VPCStack-FFQTYHECIX9M` → `SiecDB` (`AWS::RDS::DBSubnetGroup`)
- CloudFormation działał jako `arn:aws:iam::943111679945:user/jenkinsit`
- brak uprawnienia `rds:ModifyDBSubnetGroup`

Evidence:
```text
2026-04-28T09:04:42.267000+00:00
Stack: dev-VPCStack-FFQTYHECIX9M
Resource: SiecDB
Type: AWS::RDS::DBSubnetGroup
Status: UPDATE_FAILED
Reason: User arn:aws:iam::943111679945:user/jenkinsit is not authorized to perform rds:ModifyDBSubnetGroup on arn:aws:rds:eu-central-1:943111679945:subgrp:dev-vpcstack-ffqtyhecix9m-siecdb-fspddhruuczb because no identity-based policy allows the rds:ModifyDBSubnetGroup action
```

Rollback noise:
- `ECSStack`, `IAMStack`, `S3Stack` miały `Resource update cancelled`
- ECS child stacks `api` i `backoffice` miały wyłącznie `Resource update cancelled`
- runtime ECS po rollbacku był healthy: 4/4 services `Desired=1`, `Running=1`, `Pending=0`, rollout completed
- target groups `dev-api-ALB-TG` i `dev-backoffice-ALB-TG` miały healthy targets

Wniosek operacyjny:
- wcześniejsza hipoteza permission-only została odrzucona po głębszym forensics
- `rds:ModifyDBSubnetGroup` był symptomem, nie root cause
- przed retry root stack nie należy ślepo dodawać uprawnienia; najpierw trzeba usunąć/obejść unintended VPCStack mutation

### Forensics: dlaczego app-only deploy dotknął `SiecDB`

Wynik read-only forensics:
- `changeSet-1253` nie był już dostępny (`ChangeSetNotFound`), więc nie da się odtworzyć `ResourceChange.Details`
- root `VPCStack` przekazuje tylko `Projekt` i `Srodowisko`; parametry ALB/TG nie idą do VPCStack
- `VPCStack` używa stałego `TemplateURL`: `https://rshop-cf.s3.eu-central-1.amazonaws.com/dev/vpc-dev.yml`
- obiekt S3 `dev/vpc-dev.yml` został podmieniony 2026-03-21/2026-04-06 względem wersji 2024-10-14
- diff wersji S3 pokazuje dodanie tagów `Project`, `Environment`, `Owner`, `ManagedBy`, `CostCenter` do zasobów VPC, w tym `SiecDB`
- eventy VPCStack pokazują `UPDATE_IN_PROGRESS` dla wielu zasobów tagowanych oraz `SiecDB`; `SiecDB` kończy na `AccessDenied: rds:ModifyDBSubnetGroup`
- drift detection po fakcie: `IN_SYNC`, `DriftedStackResourceCount=0`; `SiecDB` bez `PropertyDifferences`

Wniosek:
- przyczyną nie był live drift ani ALB/TG parameter propagation
- app-only deploy odświeżył nested stack przez stały, nieversionowany `TemplateURL` i wciągnął wcześniej podmieniony VPC template
- mutacja `SiecDB` była efektem tag-related template delta / replay nested stack template, nie świadomą zmianą aplikacyjną
- przed kolejnym retry należy wyeliminować unintended VPCStack mutation albo świadomie zatwierdzić infra/tag rollout z odpowiednimi IAM permissions

## DEV Deploy Path Mitigation — Jenkinsfiles — 2026-04-28

Status:
- mitigation przygotowany i reviewowany w repo `~/projekty/mako/eshop-cicd`
- nie jest to permanent fix dla mutable TemplateURL, tylko bezpieczniejsza granica app deploy dla DEV

Zmodyfikowane pliki:
- `jenkinsfiles/BE/eshop-dev-aws.jenkinsfile`
- `jenkinsfiles/BE/eshop-dev-aws-scan-2.jenkinsfile`

Zmiana:
- dla `params.Envi == 'dev'` CloudFormation target został przełączony z root stack `dev` na `dev-ECSStack-1BLAWHL0P6JKO`
- dla `qa` i `uat` zachowanie pozostaje bez zmian (`CfnStackName = UpEnv`)
- dev używa parametrów ECSStack:
  - `apiimg`
  - `backofficeimg`
  - pozostałe ECSStack params z `UsePreviousValue=true`
- dev nie przekazuje root-only params:
  - `ALBDNS`
  - `MasterUsername`, `MasterUserPassword`
  - `Engine`, `EngineVersion`
  - `DBInstanceClass`, `DBSnapshotIdentifier`, `DeployDB`
  - `CertyfikatCF`, `AltDomains`, `AltDomainsForeign2`, `CertyfikatCFForeign2`
- dev `create-change-set` używa `--include-nested-stacks`
- przed `execute-change-set` działa guard:
  - blokuje `VPCStack`, `DBStack`, `SGStack`, `IAMStack`, `S3Stack`, `CFStack`, `SiecDB`
  - blokuje typy `AWS::EC2::*`, `AWS::RDS::*`, `AWS::IAM::*`, `AWS::S3::*`, `AWS::ElasticLoadBalancingV2::*`
  - dopuszcza tylko `api`, `backoffice`, `AWS::ECS::TaskDefinition`, `AWS::ECS::Service`

Review `eshop-dev-aws-scan-2.jenkinsfile`:
- PASS: dev targetuje `dev-ECSStack-1BLAWHL0P6JKO`, nie root `dev`
- PASS: `qa/uat` bez zmiany zachowania
- PASS: dev image params to lowercase `apiimg` / `backofficeimg`
- PASS: root-only params nie są wysyłane dla dev
- PASS: `--include-nested-stacks` tylko dla dev
- PASS: guard działa przed execute
- PASS: execute i wait używają `CfnStackName`
- PASS: `changeSetIdBackend` scope zgodny z wcześniejszym wzorcem

Następne kroki:
- wykonać kontrolowany test Jenkins dev path dopiero gdy CFN root/ECSStack są w stanie terminalnym
- traktować ten fix jako mitigation deploy path, nie permanentną naprawę architektury
- permanent fix: immutable `TemplateURL` pinning / release artifact paths oraz guard jako standard pipeline

## Evidence References

Kluczowe evidence z 2026-04-24:
- change set safety review
- ENI tag validation results
- endpoint compliance query returning `[]`
- manual drift reconciliation commands used

Powiązane notatki:
- [[rshop-tagging-baseline-2026-04-24]]
- [[vpc-endpoints-tagging-audit-2026-04-24]]
- [[finops-rshop]]
- [[cloudformation-drift-reconciliation-vpc-endpoint-tags]]
