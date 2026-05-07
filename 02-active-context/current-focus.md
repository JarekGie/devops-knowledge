# Current Focus

> Co jest ważne w tym tygodniu / sprincie. Nie lista todo — priorytety.

## Główny cel

```
Przełączony kontekst roboczy: puzzler-b2b / PBMS.
Stan vault zapisany 2026-05-07 po drp-tfs cloud-detective i powrocie na puzzler-pbms:
  - drp-tfs snapshot zapisany w 20-projects/clients/mako/drp-tfs/drp-tfs-context.md,
  - drp-tfs standby z CRITICAL: leasing-filters CrashLoopBackOff + haproxy LB pending,
  - AWS profile puzzler-pbms działa: account 698220459519, user makolab-ci,
  - QA ownership model sprawdzony względem DEV,
  - DEV envs/dev/services.tf dostosowany do QA: bez AzureAd ECS secret injection,
  - terraform fmt/validate OK,
  - terraform plan DEV = No changes,
  - apply NIE wykonany,
  - infra repo ma staged envs/dev/services.tf oraz untracked docs/db-access.md.

Główna oś puzzler-pbms:
  1. commit staged DEV guardrail change,
  2. utrzymać zakaz apply bez ponownego plan review,
  3. opcjonalnie sprawdzić uat/prod/secrets.tf parity,
  4. opcjonalnie force-replace task definitions tylko jeśli potrzebny runtime cleanup,
  5. nie mieszać untracked docs/db-access.md z commitem guardrails bez decyzji.

Stan wejściowy z vault:
  - AWS profile: puzzler-pbms
  - region: eu-west-2
  - konto: 698220459519
  - repo infra: ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
  - context: 20-projects/clients/mako/puzzler-b2b/puzzler-b2b-context.md

Ryzyka z ostatniego scan:
  - apply nie był wykonany po DEV parity change; plan był no-op
  - docs/db-access.md untracked w infra repo — nie stagingować przypadkiem
  - envs/dev/.env istnieje jako pusty plik
  - runtime ECS task definitions nie zmienią się bez CI/CD albo force-replace
  - QA jumphost wcześniejszy blocker ECR image missing został naprawiony tagiem jumphost-v10 wg ostatniego stanu IaC, ale live recheck można zrobić przy kolejnej sesji

Wejście:
  - `02-active-context/now.md`
  - `20-projects/clients/mako/puzzler-b2b/puzzler-b2b-context.md`
  - `20-projects/clients/mako/puzzler-b2b/troubleshooting.md`
  - `20-projects/clients/mako/puzzler-b2b/context.md`
  - `_chatgpt/context-packs/makolab-projects-vault-context.md`
```

## Projekty aktywne

| Projekt | Status | Następny krok |
|---------|--------|---------------|
| puzzler-b2b / PBMS | aktywny | commit staged `envs/dev/services.tf`; potem opcjonalnie uat/prod secrets parity albo runtime cleanup task definitions |
| maspex | standby | Load test report 19:00 zapisany; Redis reboot i CloudFront invalidation wykonane; obserwować przy kolejnym teście Redis circuit + ECS memory; Terraform observability/WAF patch nadal bez apply |
| rshop | standby | utrzymać zakaz root deploy; wrócić później do permanent fix nested `TemplateURL` i ECS PropagateTags CFN patch |
| vault governance | standby | Knowledge Boundaries wdrożone; oczekuje ręcznego frontmatter w clients/mako/ + _chatgpt/ + llz/ |
| BMW AI Taskforce | scaffold gotowy | 20-projects/clients/bmw/ai-taskforce/ — czeka na pierwsze materiały od klienta |
| cloud-support-as-a-service | scaffold gotowy | 20-projects/internal/cloud-support-as-a-service/ — czeka na wypełnienie |
| devops-toolkit | w tle | Cloud Detective zapisany jako robocza capability; bez aktywnej pracy |
| devops-platform | w tle | |
| devops-business | w tle | |

## Priorytety tygodnia

1. puzzler-pbms: commit staged DEV guardrail change w `infra-puzzler-b2b-final`.
2. puzzler-pbms: nie stagingować przypadkiem `docs/db-access.md` bez review.
3. puzzler-pbms: opcjonalnie uat/prod `secrets.tf` parity dla `ignore_changes`.
4. puzzler-pbms: opcjonalnie runtime cleanup ECS task definitions po decyzji.
5. Utrzymać Maspex jako zapisany kontekst standby, nie mieszać z bieżącą sesją; powrót tylko po explicit switch.

## Aktywni klienci

| Klient | Temat | Deadline |
|--------|-------|----------|
| Mako | puzzler-b2b / PBMS live state + IaC hygiene | |

## Blokery / otwarte pętle

- [ ] `rshop-cloudformation/cloudformation/{api,backoffice,frontend,frontend2}.yml` bez `PropagateTags`, `EnableECSManagedTags` i tagów ECS Service
- [ ] `infra-rshop/cloudformation/akcesoria2/svc.yml` ma tagi, ale brakuje `PropagateTags: SERVICE` i `EnableECSManagedTags: true`
- [ ] `rshop` root/nested CFN używa mutowalnych `TemplateURL`; app-only deploy przez root może replayować nowsze nested templates (`CFN-MUT-001`)
- [ ] Jenkins mitigation dla dev zapisany w `~/projekty/mako/eshop-cicd/jenkinsfiles/BE/{eshop-dev-aws,eshop-dev-aws-scan-2}.jenkinsfile`; nocny test nie dotknął root/VPC, ale ECS/app rollout padł na `NotStabilized`
- [ ] sprawdzić `Project=akcesoria2` w allowedValues LLZ Tag Policy przed re-enable
- [ ] Maspex standby: Terraform UAT plan blokuje stary/osierocony digest w `terraform-locks-969209893152`; safe recovery opisane w `02-active-context/now.md`
- [ ] Maspex standby: `infra-maspex` ma lokalny patch observability/WAF niezaaplikowany: WAF admin allowlist + Athena/Glue per-path CloudFront logs
- [ ] puzzler-pbms: commit staged `envs/dev/services.tf` guardrail parity
- [ ] puzzler-pbms: zdecydować co zrobić z untracked `docs/db-access.md`
- [ ] puzzler-pbms: uat/prod `secrets.tf` parity dla `ignore_changes`
- [ ] puzzler-pbms: runtime cleanup ECS task definitions tylko po explicit decision

## Powiązane

- [[now]] — co robię w tej chwili
- [[open-loops]] — rzeczy w toku bez zakończenia
- [[waiting-for]] — czekam na
- [[decision-log]] — decyzje do podjęcia

---

*Tydzień: 2026-W19*
