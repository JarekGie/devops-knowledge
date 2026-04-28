# Current Focus

> Co jest ważne w tym tygodniu / sprincie. Nie lista todo — priorytety.

## Główny cel

```
Przełączony kontekst roboczy: rshop Tag Policy remediation.
Skupić się najpierw na odblokowaniu bezpiecznej granicy deployu CloudFormation:
CFN-MUT-001 mutable nested TemplateURL powoduje ukrytą mutację VPCStack podczas app deploy.
Po usunięciu/obejściu tego ryzyka wrócić do CFN fix dla ECS PropagateTags /
EnableECSManagedTags przed ponownym włączeniem Tag Policies LLZ.
Wejście przez `40-runbooks/incidents/rshop-tag-policy-readiness.md` oraz
`_chatgpt/context-packs/rshop-tag-policy.md`.
Nowy wzorzec: `40-runbooks/aws/cloudformation-nested-template-mutability-hazard.md`.
Maspex zapisany i przesunięty do standby.
```

## Projekty aktywne

| Projekt | Status | Następny krok |
|---------|--------|---------------|
| rshop | aktywny | najpierw wyeliminować hidden VPCStack mutation (`CFN-MUT-001`: mutable nested `TemplateURL`); potem wrócić do ECS PropagateTags CFN patch |
| maspex | standby | UAT observability wdrożone; nadal otwarte: patch `next-core-app`, potwierdzenie `/_next/image`, Redis secret |
| puzzler-b2b | standby | IaC sync+builder gotowe; czeka na: ECR obrazy + Ocelot config w pbms-backend |
| vault governance | standby | Knowledge Boundaries wdrożone; oczekuje ręcznego frontmatter w clients/mako/ + _chatgpt/ + llz/ |
| BMW AI Taskforce | scaffold gotowy | 20-projects/clients/bmw/ai-taskforce/ — czeka na pierwsze materiały od klienta |
| cloud-support-as-a-service | scaffold gotowy | 20-projects/internal/cloud-support-as-a-service/ — czeka na wypełnienie |
| devops-toolkit | w tle | Cloud Detective zapisany jako robocza capability; bez aktywnej pracy |
| devops-platform | w tle | |
| devops-business | w tle | |

## Priorytety tygodnia

1. rshop: nie retry root stack app deploy dopóki mutable nested `TemplateURL` / VPCStack mutation nie jest rozwiązana.
2. rshop: przygotować bezpieczną granicę deployu: version-pinned nested templates, immutable artifact path albo rozdzielenie app/infra pipeline.
3. rshop: po ustabilizowaniu deploy boundary przygotować minimalne CFN zmiany dla ECS Services i walidować najpierw dev.
4. Utrzymać Maspex jako zapisany kontekst standby, nie mieszać sesji roboczej.

## Aktywni klienci

| Klient | Temat | Deadline |
|--------|-------|----------|
| Mako | rshop Tag Policy remediation | |

## Blokery / otwarte pętle

- [ ] `rshop-cloudformation/cloudformation/{api,backoffice,frontend,frontend2}.yml` bez `PropagateTags`, `EnableECSManagedTags` i tagów ECS Service
- [ ] `infra-rshop/cloudformation/akcesoria2/svc.yml` ma tagi, ale brakuje `PropagateTags: SERVICE` i `EnableECSManagedTags: true`
- [ ] `rshop` root/nested CFN używa mutowalnych `TemplateURL`; app-only deploy może replayować nowsze nested templates (`CFN-MUT-001`)
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
