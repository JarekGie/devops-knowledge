---
date: 2026-04-24
project: rshop
tags: [rshop, tagging, finops, vpc-endpoints, audit, tag-policy]
domain: client-work/mako
---

# RSHOP VPC ENDPOINTS — AUDIT I REMEDIATION STATUS 2026-04-24

Audyt rozpoczął się jako read-only. Notatka została zaktualizowana o finalny stan po manual drift reconciliation wykonanym później tego samego dnia.
Konto: 943111679945 (eu-central-1), profil CLI `rshop`.
Kontekst: kontynuacja po remediacji ECS ENI tag propagation (rshop-dev ✓, rshop-prod ✓, akcesoria2-prod ✓).

---

## 1. Wynik jednym zdaniem

**Stan końcowy po remediacji:** dev 4/4 endpointy zgodne, prod 3/4 interface endpoints zgodne, prod S3 gateway pozostaje wyjątkiem pending CFN alignment. Root cause pozostał ten sam: drift między live AWS i desired state/oczekiwaniem operacyjnym.**

---

## 2. Macierz zgodności

| Endpoint ID | Środowisko | Usługa | Typ | Project | Environment | Owner | ManagedBy | CostCenter | Status |
|-------------|-----------|--------|-----|---------|-------------|-------|-----------|-----------|--------|
| vpce-05174e681737bc7a0 | prod | logs | Interface | ✓ rshop | ✓ prod | ✓ | ✓ | ✓ | GO |
| vpce-04ab55e932a54733f | prod | ecr.api | Interface | ✓ rshop | ✓ prod | ✓ | ✓ | ✓ | GO |
| vpce-00482d667b910fe3e | prod | ecr.dkr | Interface | ✓ rshop | ✓ prod | ✓ | ✓ | ✓ | GO |
| vpce-0ad2e4f5d5005bf1f | prod | s3 | Gateway | **BRAK** | ✓ prod | ✓ | ✓ | ✓ | EXCEPTION |
| vpce-06fbbcc50008abf6d | dev | s3 | Gateway | ✓ rshop | ✓ dev | ✓ | ✓ | ✓ | GO |
| vpce-0adbca724b31df149 | dev | ecr.api | Interface | ✓ rshop | ✓ dev | ✓ | ✓ | ✓ | GO |
| vpce-055c1e81bc384fe77 | dev | ecr.dkr | Interface | ✓ rshop | ✓ dev | ✓ | ✓ | ✓ | GO |
| vpce-04a529e00f650ba57 | dev | logs | Interface | ✓ rshop | ✓ dev | ✓ | ✓ | ✓ | GO |

**Podsumowanie:**
- Łącznie: 8 endpointów
- Zgodnych (GO): **7**
- Wyjątki: **1**
- Brakujące tagi: `Project` = 1/8, `Environment` = 0/8

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

Późniejsza remediacja manualna potwierdziła dodatkowo:
- dla dev 4/4 `ec2 create-tags` skutecznie wyrównał live z desired state
- dla prod 3 interface endpoints `ec2 create-tags` skutecznie dodał `Project=rshop`
- prod S3 gateway endpoint został świadomie wyłączony z manualnego runu, bo template `prod-VPCStack-PUE148866VHC` nie potwierdzał tagów dla `EcrS3Endpoint`

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

## 6. Ocena bezpieczeństwa remediacji (ZAKTUALIZOWANE 2026-04-24)

### Odkrycie krytyczne: CFN bug w tag update dla AWS::EC2::VPCEndpoint

**Głęboka analiza (2026-04-24) wykazała, że no-op CFN update może NIE naprawić driftu.**

**Oś czasu:**
- 2024-10-14: stack stworzony (bez Project/Environment w szablonie)
- 2026-04-06: S3 `endpoints-dev.yml` zaktualizowany (dodano Project/Environment)
- 2026-04-18: stack update z nowym szablonem → WSZYSTKIE 4 endpointy UPDATE_COMPLETE → **tagi nadal nie ma na live resources**

CFN Resource Schema potwierdza `tagUpdatable: true`, handler update ma `ec2:CreateTags`. Jednak CFN wyraportował UPDATE_COMPLETE, a tagi nie pojawiły się. To potwierdza bug w handlerze lub silent failure podczas CreateTags.

### Implikacja dla change set

Change set `--use-previous-template` najprawdopodobniej zwróci **0 zmian** (EMPTY), ponieważ CFN's internal state (po UPDATE_COMPLETE 2026-04-18) zakłada że tagi są już zaaplikowane.

### Jedyna bezpieczna opcja: aws ec2 create-tags

```bash
# DEV — 4 endpointy, 2 tagi, 0 zmian infrastruktury
aws ec2 create-tags \
  --region eu-central-1 \
  --profile rshop \
  --resources vpce-0adbca724b31df149 vpce-055c1e81bc384fe77 \
              vpce-06fbbcc50008abf6d vpce-04a529e00f650ba57 \
  --tags Key=Project,Value=rshop Key=Environment,Value=dev
```

Właściwości: instant, reversible, 0 infrastruktura impact, nie zastępuje żadnego zasobu.

To podejście zostało użyte operacyjnie 2026-04-24 dla:
- dev 4/4 endpoints
- prod 3/4 interface endpoints

**Uwaga:** Nie tworzy driftu CFN — CFN już ma w internal state że tagi "są" (po UPDATE_COMPLETE z 2026-04-18). `create-tags` ustawia live state zgodny z tym co CFN myśli że jest → likwiduje rzeczywisty drift.

### Alternatywa: weryfikacja czy change set cokolwiek widzi

```bash
aws cloudformation create-change-set \
  --region eu-central-1 --profile rshop \
  --stack-name dev-EndPiontsStack-1J46NEV2QF038 \
  --change-set-name vpc-endpoint-tag-drift-check-2026-04-24 \
  --use-previous-template \
  --parameters \
    ParameterKey=PrivateSubnetA,UsePreviousValue=true \
    ParameterKey=PrivateSubnetB,UsePreviousValue=true \
    ParameterKey=PrivateSubnetC,UsePreviousValue=true \
    ParameterKey=PRTC,UsePreviousValue=true \
    ParameterKey=PRTB,UsePreviousValue=true \
    ParameterKey=VPCID,UsePreviousValue=true \
    ParameterKey=Projekt,UsePreviousValue=true \
    ParameterKey=Srodowisko,UsePreviousValue=true \
    ParameterKey=PRTA,UsePreviousValue=true \
    ParameterKey=SrvSG,UsePreviousValue=true
# → Inspekcja (NIE execute). Jeśli Changes=[] → potwierdzony bug CFN state. Cleanup: delete-change-set.
```

**Priorytet remediacji:** Medium. Endpointy działają. Fix tagów nie wpływa na routing ani connectivity.

---

## 7. Podsumowanie i następne kroki

### Co zrobić przed re-enable Tag Policies (kontekst incydentu 2026-04-20)

| Akcja | Pilność | Wykonawca |
|-------|---------|-----------|
| Sprawdzić scope LLZ Tag Policy: czy `ec2:vpc-endpoint` jest objęty | HIGH | DevOps + LLZ/Platform team |
| Sprawdzić ENI generowane przez interface endpoints — czy mają wymagane tagi | HIGH | DevOps |
| PROD S3 gateway endpoint: wyrównać desired state CFN dla `EcrS3Endpoint`, potem wykonać reconciliation | MEDIUM | DevOps |
| Utrzymywać manual `create-tags` jako wzorzec awaryjny dla `AWS::EC2::VPCEndpoint` handler drift | MEDIUM | DevOps |

### Zidentyfikowane nie-blokery (już naprawione lub poza scope)

- rshop-prod ECS Services: GO ✓ (2026-04-24)
- rshop-dev ECS Services: GO ✓ (2026-04-24)
- akcesoria2-prod ECS Services: GO ✓ (2026-04-24)

---

*Audyt rozpoczęty jako read-only, następnie uzupełniony o wykonany stan remediacji 2026-04-24.*
*Artefakty: `/tmp/vpc-endpoints-raw-2026-04-24.json`, `/tmp/vpc-endpoints-gap-2026-04-24.json`*
*Powiązane: [[rshop-tagging-baseline-2026-04-24]] | [[finops-rshop]] | [[rshop-tagging-remediation-2026-04-24]]*
