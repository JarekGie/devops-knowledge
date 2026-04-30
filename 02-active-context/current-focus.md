# Current Focus

> Co jest ważne w tym tygodniu / sprincie. Nie lista todo — priorytety.

## Główny cel

```
Przełączony kontekst roboczy: rshop.
Stan vault zapisany 2026-04-30 po pracach shared vault / governance / Maspex.

Główna oś rshop:
  1. utrzymać bezpieczną granicę deployu CloudFormation,
  2. nie wracać do root stack app deploy,
  3. domknąć permanentną remediację CFN-MUT-001,
  4. dopiero potem wrócić do ECS Tag Policy readiness.

CFN-MUT-001:
  mutable nested TemplateURL powoduje ukrytą mutację VPCStack podczas app deploy.
  Mitigation wykonany w Jenkinsfiles BE dla dev:
  - dev targetuje dev-ECSStack-1BLAWHL0P6JKO zamiast root dev
  - dodany pre-execute change-set guard dla app-only scope
  - qa/uat bez zmiany zachowania

Ostatnia awaria nocna:
  - nie była powrotem CFN-MUT-001
  - root dev nie został dotknięty
  - VPCStack/SiecDB nie pojawiły się
  - ECSStack-only rollback wynikał z ECS/application NotStabilized

Wejście:
  - `02-active-context/now.md`
  - `40-runbooks/incidents/rshop-dev-ecsstack-rollback-2026-04-29.md`
  - `40-runbooks/aws/cloudformation-nested-template-mutability-hazard.md`
  - `40-runbooks/incidents/rshop-tag-policy-readiness.md`
  - `_chatgpt/context-packs/rshop-tag-policy.md`

Maspex zapisany i przesunięty do standby.
```

## Projekty aktywne

| Projekt | Status | Następny krok |
|---------|--------|---------------|
| rshop | aktywny | sprawdzić app logs dla API 500/backoffice startup po ECSStack-only rollback; utrzymać zakaz root deploy; przygotować permanent fix nested `TemplateURL`; potem wrócić do ECS PropagateTags CFN patch |
| maspex | standby | Load test report zapisany; Terraform observability/WAF patch przygotowany, ale nie apply; blokada: UAT remote state digest S3/DynamoDB wymaga kontrolowanej conditional korekty przed `terraform plan` |
| puzzler-b2b | standby | IaC sync+builder gotowe; czeka na: ECR obrazy + Ocelot config w pbms-backend |
| vault governance | standby | Knowledge Boundaries wdrożone; oczekuje ręcznego frontmatter w clients/mako/ + _chatgpt/ + llz/ |
| BMW AI Taskforce | scaffold gotowy | 20-projects/clients/bmw/ai-taskforce/ — czeka na pierwsze materiały od klienta |
| cloud-support-as-a-service | scaffold gotowy | 20-projects/internal/cloud-support-as-a-service/ — czeka na wypełnienie |
| devops-toolkit | w tle | Cloud Detective zapisany jako robocza capability; bez aktywnej pracy |
| devops-platform | w tle | |
| devops-business | w tle | |

## Priorytety tygodnia

1. rshop: po nocnym teście Jenkins dev path traktować routing jako potwierdzony na poziomie CFN-MUT-001 mitigation; awaria była ECS/app `NotStabilized`, nie root/VPC.
2. rshop: nie używać root stack `dev` jako app deploy path; root deploy tylko jako świadomy infra rollout.
3. rshop: przygotować permanent fix: version-pinned nested templates / immutable artifact paths + pipeline guard jako standard.
4. rshop: po ustabilizowaniu deploy boundary przygotować minimalne CFN zmiany dla ECS Services i walidować najpierw dev.
5. Utrzymać Maspex jako zapisany kontekst standby, nie mieszać sesji roboczej; powrót tylko po explicit switch i prechecku remote state.

## Aktywni klienci

| Klient | Temat | Deadline |
|--------|-------|----------|
| Mako | rshop Tag Policy remediation | |

## Blokery / otwarte pętle

- [ ] `rshop-cloudformation/cloudformation/{api,backoffice,frontend,frontend2}.yml` bez `PropagateTags`, `EnableECSManagedTags` i tagów ECS Service
- [ ] `infra-rshop/cloudformation/akcesoria2/svc.yml` ma tagi, ale brakuje `PropagateTags: SERVICE` i `EnableECSManagedTags: true`
- [ ] `rshop` root/nested CFN używa mutowalnych `TemplateURL`; app-only deploy przez root może replayować nowsze nested templates (`CFN-MUT-001`)
- [ ] Jenkins mitigation dla dev zapisany w `~/projekty/mako/eshop-cicd/jenkinsfiles/BE/{eshop-dev-aws,eshop-dev-aws-scan-2}.jenkinsfile`; nocny test nie dotknął root/VPC, ale ECS/app rollout padł na `NotStabilized`
- [ ] sprawdzić `Project=akcesoria2` w allowedValues LLZ Tag Policy przed re-enable
- [ ] Maspex standby: Terraform UAT plan blokuje stary/osierocony digest w `terraform-locks-969209893152`; safe recovery opisane w `02-active-context/now.md`
- [ ] Maspex standby: `infra-maspex` ma lokalny patch observability/WAF niezaaplikowany: WAF admin allowlist + Athena/Glue per-path CloudFront logs

## Powiązane

- [[now]] — co robię w tej chwili
- [[open-loops]] — rzeczy w toku bez zakończenia
- [[waiting-for]] — czekam na
- [[decision-log]] — decyzje do podjęcia

---

*Tydzień: 2026-W17*
