# rshop — Tag Policy remediation plan

#aws #ecs #incident #todo

Kontekst: następstwo incydentu [[rshop-prod-503-2026-04-20]].
Tag Policies (LLZ) zostały wycofane przez `terraform destroy`. Przed ich ponownym wdrożeniem
wymagane są zmiany w CFN.

## Stan audytu (2026-04-20)

### rshop-prod-Klaster — GOTOWE

| Serwis | Environment | Project | propagateTags |
|--------|-------------|---------|---------------|
| backoffice-svc | prod | rshop | SERVICE ✓ |
| frontend-svc1  | prod | rshop | SERVICE ✓ |
| frontend-svc2  | prod | rshop | SERVICE ✓ |
| api-svc        | prod | rshop | SERVICE ✓ |

Drift: prod ma `propagateTags=SERVICE` ale CFN tego nie definiuje — zostało ustawione ręcznie lub
przez starszą wersję szablonów z S3 (`rshop-cf.s3`).

### rshop-dev-Klaster — WYMAGA NAPRAWY

| Serwis | Environment | Project | propagateTags |
|--------|-------------|---------|---------------|
| backoffice-svc | dev | rshop | NONE ✗ |
| frontend-svc1  | dev | rshop | NONE ✗ |
| frontend-svc2  | dev | rshop | NONE ✗ |
| api-svc        | dev | rshop | NONE ✗ |

### akcesoria2-prod-Klaster — WYMAGA NAPRAWY

| Serwis | Environment | Project | propagateTags |
|--------|-------------|---------|---------------|
| akcesoria2-prod-dacia-svc   | prod | akcesoria2 | NONE ✗ |
| akcesoria2-prod-renault-svc | prod | akcesoria2 | NONE ✗ |

Dodatkowe ryzyko: `Project=akcesoria2` — sprawdzić czy ta wartość jest w `allowedValues`
Tag Policy LLZ przed wdrożeniem (poza zakresem tego zadania).

## Problem w CFN

### rshop-cloudformation (frontend.yml, frontend2.yml, backoffice.yml, api.yml)
Brak `PropagateTags` i brak `Tags` na `AWS::ECS::Service`.
Prod jest poprawny przez drift — CFN nie odzwierciedla rzeczywistości.

### aws-projects/infra-rshop/cloudformation/akcesoria2/svc.yml
`Tags` zdefiniowane poprawnie, ale brak `PropagateTags: SERVICE`.

## Fix CFN — co dodać

Do każdego `AWS::ECS::Service` w obu repozytoriach dodać:

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

Repozytoria:
- `~/projekty/mako/rshop-cloudformation/cloudformation/` — frontend/frontend2/backoffice/api
- `~/projekty/mako/aws-projects/infra-rshop/cloudformation/akcesoria2/svc.yml` — DaciaSvc/RenaultSvc

## Bezpieczna kolejność operacji

```
1. Fix CFN templates (PropagateTags: SERVICE + Tags)
2. Deploy dev (rshop-dev) → weryfikacja
3. Deploy prod (rshop-prod) → weryfikacja
4. Sprawdzić allowedValues w LLZ Tag Policy dla Project=akcesoria2
5. DOPIERO WTEDY wdrożyć Tag Policies przez Terraform
```

NIGDY: Tag Policies aktywne → CFN update (nowy ENI podczas deploy = violation = prod down)

## Inne ustalenia

- Redis i RabbitMQ: nie istnieją w koncie rshop (943111679945)
- Jedyne zewnętrzne połączenie aplikacji: SQL Server RDS
  - prod: `pssa61v1phykq0.cwm5edu9get5.eu-central-1.rds.amazonaws.com`
  - dev:  `dev-dbstack-*.cwm5edu9get5.eu-central-1.rds.amazonaws.com`
- Task definitions: 3 kontenery (api, backoffice, frontend/frontend2) + jumphost
- Brak `EnableECSManagedTags` w żadnym szablonie

## Checklist przed wdrożeniem Tag Policies

- [ ] Dodać `PropagateTags: SERVICE` do CFN rshop-cloudformation (dev templates)
- [ ] Dodać `PropagateTags: SERVICE` do CFN rshop-cloudformation (prod templates)
- [ ] Dodać `PropagateTags: SERVICE` do akcesoria2/svc.yml
- [ ] Deploy na dev, weryfikacja ENI tagów
- [ ] Deploy na prod, weryfikacja ENI tagów
- [ ] Potwierdzić `akcesoria2` w allowedValues LLZ Tag Policy
- [ ] Wdrożyć Tag Policies przez Terraform

---

*Utworzono: 2026-04-20*
