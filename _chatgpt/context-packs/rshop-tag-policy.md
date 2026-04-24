# ChatGPT Context Pack — rshop Tag Policy remediation

> Wklej całość na początku rozmowy z ChatGPT.

**Zakres:** rshop — ECS TagPolicyViolation, CFN fix, FinOps backlog tagowania
**Data przygotowania:** 2026-04-24

---

## Kim jestem / kontekst roli

Senior DevOps/SRE, AWS multi-account (Organizations), Terraform + CloudFormation, ECS Fargate.
Pracuję nad klientem `mako/rshop` — e-commerce Renault/Dacia (sklep.renault.pl i spółka).

---

## Infrastruktura rshop

```
AWS Account: 943111679945
Region: eu-central-1
Profile: rshop
IaC: CloudFormation (nie Terraform)

Klastry ECS:
  rshop-prod-Klaster — sklep.renault.pl, eshop.renault.{cz,sk,hu}, dacia equiv.
  rshop-dev-Klaster

Serwisy ECS Fargate:
  rshop-prod-backoffice-svc   → /admin
  rshop-prod-frontend-svc1    → Renault domains
  rshop-prod-frontend-svc2    → Dacia domains
  rshop-prod-api-svc          → /api* (NIE było dotknięte incydentem)

Repozytoria CFN:
  ~/projekty/mako/rshop-cloudformation/cloudformation/
    api.yml, backoffice.yml, frontend.yml, frontend2.yml
  ~/projekty/mako/aws-projects/infra-rshop/cloudformation/akcesoria2/svc.yml
    DaciaSvc, RenaultSvc (akcesoria2-prod-Klaster)

Baza danych: SQL Server RDS (eu-central-1) — jedyne zewnętrzne połączenie aplikacji
Redis/RabbitMQ: NIE ISTNIEJĄ w tym koncie
```

---

## Incydent PROD (2026-04-20)

**Objaw:** HTTP 503 na 3 serwisach (backoffice, frontend-svc1, frontend-svc2).
API działało bez problemu.

**Root cause:** `TagPolicyViolation` — ECS Fargate nie może otagować ENI przy starcie taska.

```
StopCode:   TaskFailedToStart
StopReason: Unexpected EC2 error while attempting to tag the network
            interface: TagPolicyViolation
```

**Mechanizm:**
- 2026-04-19: Tag Policies LLZ wdrożone przez Terraform (`llz-environment`, `llz-project`)
  wymagające tagów `Environment` + `Project` na `ec2:network-interface`
- ECS Fargate tworzy nowy ENI przy każdym starcie taska
- Serwisy mają `propagateTags=SERVICE`, ale `Tags=null` w ECS → ENI bez tagów → violation
- API-svc przeżyło: task był aktywny od 2026-04-17, ENI już istniał, brak nowego startu

**Fix zastosowany (doraźny):**
`terraform destroy` na Tag Policies — ECS automatycznie ponowił próbę, serwisy wstały.

**Status:** Tag Policies są wyłączone. Przed ponownym wdrożeniem wymagane zmiany CFN.

---

## Stan audytu tagowania (po incydencie)

| Klaster | Serwis | propagateTags | Tags w CFN | Stan |
|---------|--------|---------------|------------|------|
| prod | backoffice-svc | SERVICE ✓ | brak | drift (set ręcznie) |
| prod | frontend-svc1 | SERVICE ✓ | brak | drift |
| prod | frontend-svc2 | SERVICE ✓ | brak | drift |
| prod | api-svc | SERVICE ✓ | brak | drift |
| dev | backoffice-svc | NONE ✗ | brak | wymaga naprawy |
| dev | frontend-svc1 | NONE ✗ | brak | wymaga naprawy |
| dev | frontend-svc2 | NONE ✗ | brak | wymaga naprawy |
| dev | api-svc | NONE ✗ | brak | wymaga naprawy |
| akcesoria2-prod | dacia-svc | NONE ✗ | jest | brak PropagateTags |
| akcesoria2-prod | renault-svc | NONE ✗ | jest | brak PropagateTags |

Prod ma `propagateTags=SERVICE` przez drift — CFN go nie definiuje.
akcesoria2 ma `Tags` zdefiniowane w CFN, ale brak `PropagateTags: SERVICE`.

---

## Fix CFN — co dodać

Do każdego `AWS::ECS::Service` w obu repozytoriach:

```yaml
PropagateTags: SERVICE
EnableECSManagedTags: true
Tags:
  - Key: Environment
    Value: !Ref Srodowisko
  - Key: Project
    Value: !Ref Projekt
  - Key: ManagedBy
    Value: cloudformation
```

Pliki do zmiany:
- `rshop-cloudformation/cloudformation/frontend.yml`
- `rshop-cloudformation/cloudformation/frontend2.yml`
- `rshop-cloudformation/cloudformation/backoffice.yml`
- `rshop-cloudformation/cloudformation/api.yml`
- `infra-rshop/cloudformation/akcesoria2/svc.yml` (DaciaSvc, RenaultSvc)

---

## Bezpieczna kolejność operacji

```
1. Fix CFN templates (PropagateTags: SERVICE + Tags + EnableECSManagedTags)
2. Deploy dev (rshop-dev) → weryfikacja ENI tagów w AWS Console
3. Deploy prod (rshop-prod) → weryfikacja ENI tagów
4. Sprawdzić czy allowedValues LLZ Tag Policy obejmuje Project=akcesoria2
5. DOPIERO WTEDY wdrożyć Tag Policies przez Terraform
```

ZASADA: nigdy nie wdrażać Tag Policies gdy CFN nie jest poprawiony.
Nowy deploy = nowy ENI = TagPolicyViolation = prod down.

---

## FinOps backlog tagowania (stan 2026-04-18)

Pokrycie tagów: **44.2%** (55.8% kosztów bez tagu `Environment`).
Koszt MTD: $584.83 (+30% vs poprzedni okres).

Problemy z tagowaniem CFN (toolkit apply-pack tagging):
- 11/27 stacków bez wymaganych tagów
- root stacki (`dev`, `prod`) mają 0 tagów — propagacja kaskaduje na nested → toolkit blokuje
- toolkit blokuje każdą modyfikację zasobu przez CFN propagację tagów (safety check)
  → wymaga poprawki w toolkicie (`validate_tag_only_changeset`)

Observability gaps (audit-pack aws-logging):
- ALB access logs: NOT_ENABLED (prod + dev)
- CloudFront logging: NOT_ENABLED (4 dystrybucje)
- VPC Flow Logs: NOT_ENABLED (3 VPC) — rekomendacja: S3 nie CW Logs ($2-8/mies. vs $45-135/mies.)

Root stacki wymagają tagowania przez IaC (w szablonie deployującym root stack), nie przez toolkit apply-pack.

---

## Szybki prompt dla ChatGPT

```
Pracujesz nad projektem rshop (e-commerce Renault/Dacia) w AWS (eu-central-1, konto 943111679945).
Infrastruktura: ECS Fargate, CloudFormation, profil AWS: rshop.

Kontekst:
- Był incydent PROD 503 z powodu TagPolicyViolation — ECS nie mógł otagować ENI przy starcie tasków
- Root cause: Tag Policy LLZ wymaga Environment + Project na ec2:network-interface,
  ECS Fargate tworzy ENI przy każdym starcie, serwisy mają propagateTags=SERVICE ale Tags=null w CFN
- Fix doraźny: terraform destroy na Tag Policies (serwisy wstały automatycznie)
- Tag Policies są WYŁĄCZONE — można bezpiecznie deployować, ale przed ponownym wdrożeniem
  polityk trzeba naprawić CFN

Repozytoria CFN (lokalne):
  ~/projekty/mako/rshop-cloudformation/cloudformation/ (api/backoffice/frontend/frontend2.yml)
  ~/projekty/mako/aws-projects/infra-rshop/cloudformation/akcesoria2/svc.yml

Do każdego AWS::ECS::Service dodać:
  PropagateTags: SERVICE
  EnableECSManagedTags: true
  Tags:
    - Key: Environment
      Value: !Ref Srodowisko
    - Key: Project
      Value: !Ref Projekt
    - Key: ManagedBy
      Value: cloudformation

Kolejność: dev deploy → weryfikacja ENI tagów → prod deploy → weryfikacja → Tag Policies Terraform.
NIGDY: Tag Policies aktywne podczas deployu bez naprawionych szablonów.
```
