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
