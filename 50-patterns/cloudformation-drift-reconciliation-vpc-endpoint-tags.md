---
date: 2026-04-24
tags: [cloudformation, drift, vpc-endpoint, tags, operations]
domain: patterns
---

# CloudFormation Drift Reconciliation — VPC Endpoint Tags

## Problem

`AWS::EC2::VPCEndpoint` może znaleźć się w stanie, w którym:
- template CloudFormation zawiera oczekiwane tagi
- stack ma status `UPDATE_COMPLETE`
- live resource nadal nie ma fizycznie nałożonych tagów

To tworzy operational drift między desired state i live AWS.

## Kluczowy sygnał ostrzegawczy

Nie wolno zakładać, że `UPDATE_COMPLETE` oznacza poprawnie zaaplikowane tagi na `AWS::EC2::VPCEndpoint`.

Dla tego resource type potrzebna jest walidacja live:
- `aws ec2 describe-vpc-endpoints`
- porównanie live tags z template tags
- porównanie logical ID ↔ physical ID

## Safe reconciliation pattern

### Phase 1 — Read-only evidence

1. pobrać live stan endpointów
2. potwierdzić `State=available`
3. zapisać evidence artifact
4. sprawdzić, które tagi są obecne, a które brakują

### Phase 2 — Desired state evidence

1. `aws cloudformation describe-stack-resources`
2. `aws cloudformation get-template`
3. `aws cloudformation describe-stacks`
4. potwierdzić mapping logical → physical
5. potwierdzić, że template rzeczywiście wymaga danego tagu
6. potwierdzić parametry stacka, z których wynikają oczekiwane wartości

### Phase 3 — Mutation planning

Jeśli live tag jest nieobecny, a desired state w CFN jest potwierdzony, bezpieczny plan manualnej rekonsyliacji to:

```bash
aws ec2 create-tags \
  --resources <vpce-id> \
  --tags Key=<Key>,Value=<Value> \
  --profile <profile> \
  --region <region>
```

Zasady:
- jedna komenda per endpoint
- dodawać tylko brakujące tagi
- nie nadpisywać istniejących wartości bez jawnego uzasadnienia
- nie używać replacement ani recreation

### Phase 4 — Post-check

Po wykonaniu trzeba potwierdzić:
- endpoint IDs bez zmian
- `ServiceName` bez zmian
- `State=available`
- wymagane tagi obecne
- focused compliance query zwraca `[]`

## Kiedy NIE wykonywać create-tags

Nie wykonywać manualnego `create-tags`, jeśli:
- endpoint nie jest `available`
- physical ID nie zgadza się z mappingiem CFN
- template nie potwierdza danego tagu jako desired state
- istnieje ryzyko, że manualny tag wprowadzi rozjazd z CFN zamiast go zamknąć

## Operational lesson

Dla `AWS::EC2::VPCEndpoint`:
- `UPDATE_COMPLETE` nie jest wystarczającym dowodem zgodności tagów
- ręczne `ec2 create-tags` może być poprawną formą drift reconciliation
- warunkiem jest wcześniejsze udowodnienie desired state w CFN

## Risks

- replacement risk: zero dla `ec2 create-tags`
- dataplane risk: expected none
- control-plane risk: niski
- wpływ na endpoint ENIs: brak automatycznej propagacji tagów z endpointu na ENI

## Evidence checklist

- live endpoint dump zapisany do artefaktu
- stack resource mapping potwierdzony
- template tags potwierdzone
- stack parameters potwierdzone
- prepared commands reviewed
- post-check query prepared
- compliance query prepared
