# Current Focus

> Co jest ważne w tym tygodniu / sprincie. Nie lista todo — priorytety.

## Główny cel

```
Przełączony kontekst roboczy: rshop Tag Policy remediation.
Skupić się najpierw na odblokowaniu bezpiecznej granicy deployu CloudFormation:
CFN-MUT-001 mutable nested TemplateURL powoduje ukrytą mutację VPCStack podczas app deploy.
Mitigation wykonany w Jenkinsfiles BE dla dev:
  - dev targetuje dev-ECSStack-1BLAWHL0P6JKO zamiast root dev
  - dodany pre-execute change-set guard dla app-only scope
  - qa/uat bez zmiany zachowania
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
| rshop | aktywny | po nocnym ECSStack-only rollback sprawdzić app logs dla API 500/backoffice startup; nie wracać do root deploy; potem permanent fix nested `TemplateURL` i powrót do ECS PropagateTags CFN patch |
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
