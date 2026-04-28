# Current Focus

> Co jest ważne w tym tygodniu / sprincie. Nie lista todo — priorytety.

## Główny cel

```
Przełączony kontekst roboczy: rshop Tag Policy remediation.
Skupić się na CFN fix dla ECS PropagateTags / EnableECSManagedTags przed ponownym
włączeniem Tag Policies LLZ.
Wejście przez `40-runbooks/incidents/rshop-tag-policy-readiness.md` oraz
`_chatgpt/context-packs/rshop-tag-policy.md`.
Maspex zapisany i przesunięty do standby.
```

## Projekty aktywne

| Projekt | Status | Następny krok |
|---------|--------|---------------|
| rshop | aktywny | przygotować CFN patche: `rshop-cloudformation` 4 pliki ECS Service + `infra-rshop/cloudformation/akcesoria2/svc.yml`; potem deploy dev -> weryfikacja ENI -> deploy prod |
| maspex | standby | UAT observability wdrożone; nadal otwarte: patch `next-core-app`, potwierdzenie `/_next/image`, Redis secret |
| puzzler-b2b | standby | IaC sync+builder gotowe; czeka na: ECR obrazy + Ocelot config w pbms-backend |
| vault governance | standby | Knowledge Boundaries wdrożone; oczekuje ręcznego frontmatter w clients/mako/ + _chatgpt/ + llz/ |
| BMW AI Taskforce | scaffold gotowy | 20-projects/clients/bmw/ai-taskforce/ — czeka na pierwsze materiały od klienta |
| cloud-support-as-a-service | scaffold gotowy | 20-projects/internal/cloud-support-as-a-service/ — czeka na wypełnienie |
| devops-toolkit | w tle | Cloud Detective zapisany jako robocza capability; bez aktywnej pracy |
| devops-platform | w tle | |
| devops-business | w tle | |

## Priorytety tygodnia

1. rshop: przygotować minimalne CFN zmiany dla ECS Services, bez refaktoru szablonów.
2. rshop: wdrożyć najpierw dev i potwierdzić `propagateTags=SERVICE`, `enableECSManagedTags=true` oraz tagi na nowych ENI.
3. rshop: dopiero po dev przejść na prod i akcesoria2; Tag Policies LLZ zostają wyłączone do pełnej walidacji.
4. Utrzymać Maspex jako zapisany kontekst standby, nie mieszać sesji roboczej.

## Aktywni klienci

| Klient | Temat | Deadline |
|--------|-------|----------|
| Mako | rshop Tag Policy remediation | |

## Blokery / otwarte pętle

- [ ] `rshop-cloudformation/cloudformation/{api,backoffice,frontend,frontend2}.yml` bez `PropagateTags`, `EnableECSManagedTags` i tagów ECS Service
- [ ] `infra-rshop/cloudformation/akcesoria2/svc.yml` ma tagi, ale brakuje `PropagateTags: SERVICE` i `EnableECSManagedTags: true`
- [ ] sprawdzić `Project=akcesoria2` w allowedValues LLZ Tag Policy przed re-enable
- [ ] Maspex standby: `next-core-app` ma lokalny patch `app/api/slogan/route.ts`; lokalnie `npm run typecheck` nie działa, bo brakuje `tsc`
- [ ] Maspex standby: Redis connection string do Secrets Manager `maspex/preprod/api` nadal otwarte

## Powiązane

- [[now]] — co robię w tej chwili
- [[open-loops]] — rzeczy w toku bez zakończenia
- [[waiting-for]] — czekam na
- [[decision-log]] — decyzje do podjęcia

---

*Tydzień: 2026-W17*
