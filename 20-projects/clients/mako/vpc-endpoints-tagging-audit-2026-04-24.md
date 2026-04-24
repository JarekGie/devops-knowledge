---
date: 2026-04-24
project: rshop
tags: [rshop, tagging, finops, vpc-endpoints, audit, tag-policy]
domain: client-work/mako
---

# RSHOP VPC ENDPOINTS — AUDIT TAGOWANIA 2026-04-24

Audyt read-only. Żadne zasoby AWS nie zostały zmienione.
Konto: 943111679945 (eu-central-1), profil CLI `rshop`.
Kontekst: kontynuacja po remediacji ECS ENI tag propagation (rshop-dev ✓, rshop-prod ✓, akcesoria2-prod ✓).

---

## 1. Wynik jednym zdaniem

**8/8 VPC Endpoints nie ma tagu `Project`. Dev 4/4 nie ma też `Environment`. Root cause: drift CFN — szablony już mają poprawne tagi, ale nie zostały re-deploy'owane. Fix: no-op CFN update obu stacków.**

---

## 2. Macierz zgodności

| Endpoint ID | Środowisko | Usługa | Typ | Project | Environment | Owner | ManagedBy | CostCenter | Status |
|-------------|-----------|--------|-----|---------|-------------|-------|-----------|-----------|--------|
| vpce-05174e681737bc7a0 | prod | logs | Interface | **BRAK** | ✓ prod | ✓ | ✓ | ✓ | PARTIAL |
| vpce-04ab55e932a54733f | prod | ecr.api | Interface | **BRAK** | ✓ prod | ✓ | ✓ | ✓ | PARTIAL |
| vpce-00482d667b910fe3e | prod | ecr.dkr | Interface | **BRAK** | ✓ prod | ✓ | ✓ | ✓ | PARTIAL |
| vpce-0ad2e4f5d5005bf1f | prod | s3 | Gateway | **BRAK** | ✓ prod | ✓ | ✓ | ✓ | PARTIAL |
| vpce-06fbbcc50008abf6d | dev | s3 | Gateway | **BRAK** | **BRAK** | ✓ | ✓ | ✓ | FAIL |
| vpce-0adbca724b31df149 | dev | ecr.api | Interface | **BRAK** | **BRAK** | ✓ | ✓ | ✓ | FAIL |
| vpce-055c1e81bc384fe77 | dev | ecr.dkr | Interface | **BRAK** | **BRAK** | ✓ | ✓ | ✓ | FAIL |
| vpce-04a529e00f650ba57 | dev | logs | Interface | **BRAK** | **BRAK** | ✓ | ✓ | ✓ | FAIL |

**Podsumowanie:**
- Łącznie: 8 endpointów
- Zgodnych (PASS): **0**
- Częściowych (PARTIAL): **4** (prod — brakuje tylko Project)
- Niezgodnych (FAIL): **4** (dev — brakuje Project + Environment)
- Brakujące tagi: Project = 8/8, Environment = 4/8

---

## 3. Analiza root cause — drift CFN

### Kluczowe odkrycie

Oba szablony CloudFormation **już zawierają kompletne definicje tagów** (`Project/Environment/Owner/ManagedBy/CostCenter`):

**prod-VPCStack-PUE148866VHC** (template):
```yaml
Tags:
  - Key: Name
    Value: !Join ['-', [!Ref 'Projekt', !Ref 'Srodowisko', 'ecr-api-endpoint']]
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

**dev-EndPiontsStack-1J46NEV2QF038** (template): identyczna struktura tagów.

Parametry stacków:
- prod: `Projekt=rshop`, `Srodowisko=prod` ✓
- dev: `Projekt=rshop`, `Srodowisko=dev` ✓

### Wyjaśnienie driftu

Szablony zostały zaktualizowane (dodano `Project` i `Environment` do tagów endpointów) **po** ostatnim wdrożeniu stacków, które zmieniło zasób `AWS::EC2::VPCEndpoint`. Kolejne update'y stacków (prod: 2026-04-05, dev: 2026-04-18) dotyczyły innych zasobów — CFN nie zmodyfikował endpointów i nie nałożył nowych tagów.

CFN drift detection (`DetectStackResourceDrift`) dla `AWS::EC2::VPCEndpoint` zwraca `ValidationError: Drift detection is not supported for the specified ResourceType` — drift potwierdzony empirycznie przez porównanie żywych tagów z templatem.

### Struktura stacków

| Środowisko | Stack z endpointami | Ostatnia aktualizacja |
|-----------|---------------------|-----------------------|
| prod | `prod-VPCStack-PUE148866VHC` | 2026-04-05 |
| dev | `dev-EndPiontsStack-1J46NEV2QF038` | 2026-04-18 |

**Uwaga:** dev stack ma literówkę w nazwie: `EndPiontsStack` (brak `i`). Stack created 2024-10-14 — oddzielony od dev-VPCStack.

---

## 4. Ocena blokera Tag Policy

### Czy VPC Endpoints blokują re-enable Tag Policy?

**Odpowiedź: ZALEŻY OD SCOPE POLITYKI.**

LLZ Tag Policy incydent 2026-04-20 dotyczył `ec2:network-interface` (ENI). VPC Endpoints mają osobny resource type: `ec2:vpc-endpoint`. Jeśli LLZ Tag Policy wymagaj tagów na `ec2:vpc-endpoint` — wtedy **tak, blokują**. Jeśli polityka obejmuje tylko `ec2:network-interface` — **bezpośrednio nie blokują**.

**WAŻNA uwaga:** Interface VPC Endpoints (ecr.api, ecr.dkr, logs) tworzą wewnętrzne ENI w subnets — po 1 ENI na każdą AZ. Te ENI **nie dziedziczą tagów endpointu** automatycznie (nie ma mechanizmu analogicznego do ECS PropagateTags). Jeśli Tag Policy obejmuje ENI generowane przez VPC Endpoints, brak `Project` na endpoincie nie powoduje braku na ENI (ENI generowane przez PrivateLink mogą mieć inne tagi lub nie mieć żadnych).

**Rekomendacja ostrożności:** Przed re-enable Tag Policies:
1. Zweryfikować zakres LLZ Tag Policy (czy obejmuje `ec2:vpc-endpoint`)
2. Sprawdzić czy ENI generowane przez interface endpoints (3 prod + 3 dev × 3 AZ = 18 ENI) mają wymagane tagi

---

## 5. Implikacje FinOps

### Związek z kosztem "untagged VpcEndpoint-Hours"

VPC Endpoints bez tagu `Project=rshop` są widoczne w Cost Explorer jako zasoby **untagged** — nie przypisane do projektu. Korelacja z wcześniej obserwowanym kosztem ~$59.62 untagged VpcEndpoint-Hours:

| Typ | Liczba | Koszt/endpoint/miesiąc | Łączny koszt/miesiąc |
|-----|--------|------------------------|---------------------|
| Interface (ecr.api, ecr.dkr, logs) | 6 | ~$21.60 (3 AZ × $0.01/h × 720h) | ~$129.60 |
| Gateway (S3) | 2 | $0.00 (darmowe) | $0.00 |
| **Łącznie** | **8** | — | **~$129.60** |

Kwota ~$59.62 odpowiada około połowie miesięcznego kosztu 6 interface endpoints — może reprezentować fragment okresu rozliczeniowego lub Cost Explorer raportuje tylko część cost allocation period.

**Wniosek:** Pełne otagowanie endpointów przypisuje ~$129.60/miesiąc do projektu `rshop` w raportach FinOps. Brak tagów = ciemna plama w FinOps attribution.

---

## 6. Ocena bezpieczeństwa remediacji

### Najlepsze podejście

**Fix: no-op CloudFormation update** — nie trzeba ręcznie tagować ani nic tworzyć.

Kroki (wymagają uprawnień do CFN):
```bash
# PROD — zaktualizuj VPCStack poprzez root stack prod
aws cloudformation create-change-set \
  --stack-name prod \
  --change-set-name vpc-endpoint-tags-2026-XX-XX \
  --use-previous-template \
  --include-nested-stacks \
  --parameters [wszystkie 25 parametrów UsePreviousValue=true] \
  --profile rshop

# DEV — zaktualizuj EndPiontsStack poprzez root stack dev
aws cloudformation create-change-set \
  --stack-name dev \
  --change-set-name vpc-endpoint-tags-2026-XX-XX \
  --use-previous-template \
  --include-nested-stacks \
  --parameters [wszystkie parametry UsePreviousValue=true] \
  --profile rshop
```

**Dlaczego bezpieczne:**
- `AWS::EC2::VPCEndpoint` z dodaniem/zmianą tagu = Modify, Replacement=False
- Nie zmienia routing table, subnet IDs, security groups, service name
- Gateway endpoints: bezpieczna zmiana tagu
- Interface endpoints: bezpieczna zmiana tagu (nie powoduje restartu ENI)

**NIE stosować:**
- `aws ec2 create-tags` (ominęłoby CFN → utrzymałoby drift)
- Ręczna edycja tagów w konsoli (te same powody)

**Priorytet:** Medium. Nie blokuje aktywności ECS (endpointy działają). Blokuje FinOps attribution i potencjalnie Tag Policy enforcement scope (zależnie od definicji polityki).

---

## 7. Podsumowanie i następne kroki

### Co zrobić przed re-enable Tag Policies (kontekst incydentu 2026-04-20)

| Akcja | Pilność | Wykonawca |
|-------|---------|-----------|
| Sprawdzić scope LLZ Tag Policy: czy `ec2:vpc-endpoint` jest objęty | HIGH | DevOps + LLZ/Platform team |
| Sprawdzić ENI generowane przez interface endpoints — czy mają wymagane tagi | HIGH | DevOps |
| CFN no-op update na `prod` root stack (naprawi prod VPCStack tagi) | MEDIUM | DevOps |
| CFN no-op update na `dev` root stack (naprawi dev EndPiontsStack tagi) | MEDIUM | DevOps |

### Zidentyfikowane nie-blokery (już naprawione lub poza scope)

- rshop-prod ECS Services: GO ✓ (2026-04-24)
- rshop-dev ECS Services: GO ✓ (2026-04-24)
- akcesoria2-prod ECS Services: GO ✓ (2026-04-24)

---

*Audyt: read-only, 2026-04-24. Żadne zasoby AWS nie zostały zmienione.*
*Artefakty: `/tmp/vpc-endpoints-raw-2026-04-24.json`, `/tmp/vpc-endpoints-gap-2026-04-24.json`*
*Powiązane: [[rshop-tagging-baseline-2026-04-24]] | [[finops-rshop]]*
