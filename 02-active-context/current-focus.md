# Current Focus

> Co jest ważne w tym tygodniu / sprincie. Nie lista todo — priorytety.

## Główny cel

```
Aktywny kontekst roboczy: Maspex / Kapsel.
Stan vault zapisany 2026-05-07 po przełączeniu z puzzler-pbms:
  - AWS profile: maspex-cli
  - account: 969209893152
  - region główny: eu-west-1
  - repo infra: ~/projekty/mako/aws-projects/infra-maspex
  - context: 20-projects/clients/mako/maspex/maspex-context.md
  - troubleshooting: 20-projects/clients/mako/maspex/troubleshooting.md
  - last report: 20-projects/clients/mako/maspex/load-test-analysis-2026-05-05-1900-cest.md

Główna oś Maspex teraz:
  1. live check UAT po Redis reboot / CloudFront invalidation,
  2. obserwować Redis circuit/write-through przy kolejnym teście,
  3. obserwować memory maspex-api, bo ostatni test podniósł ją ~17% -> ~57%,
  4. osobno zbadać maspex-bot health check failures / replacements,
  5. wrócić do lokalnego patcha observability/WAF tylko po plan review.

Stan wejściowy z vault:
  - UAT CloudFront API distribution: E3J76RNXIE2YIG, alias kapsel.makotest.pl
  - UAT ECS cluster: maspex-uat
  - UAT services: maspex-api, maspex-admin-panel, maspex-bot
  - UAT Redis: ElastiCache maspex-uat, standalone single-node, node 0001
  - Redis reboot wykonany, final status available
  - CloudFront invalidation /* wykonany, final status Completed
  - ostatni sanity: curl -I https://kapsel.makotest.pl/api/health -> HTTP/2 200

Ryzyka / uwagi po ostatniej pracy:
  - Redis infrastructure była zdrowa metrycznie, ale app-level Redis circuit był otwarty przez cały test.
  - 924,582 VOTE_CACHE_WRITETHROUGH_FAIL i 906,504 Redis circuit open w teście 19:00.
  - HTTP/ALB/ECS bez degradacji: 0 ELB 5XX, 0 Target 5XX, 0 unhealthy hosts, 0 task churn API.
  - maspex-api memory rosła bez recovery między falami; obserwować próg autoscaling 75%.
  - maspex-bot ma osobny problem health check / replacements.
  - preprod API historycznie DOWN 0/3 przez IAM AccessDenied do secretu.
  - Terraform UAT plan może blokować osierocony digest w terraform-locks-969209893152.
  - infra-maspex lokalny patch observability/WAF nadal bez apply.

Wejście:
  - `02-active-context/now.md`
  - `20-projects/clients/mako/maspex/maspex-context.md`
  - `20-projects/clients/mako/maspex/troubleshooting.md`
  - `20-projects/clients/mako/maspex/load-test-analysis-2026-05-05-1900-cest.md`
  - `_chatgpt/context-packs/makolab-projects-vault-context.md`
```

## Projekty aktywne

| Projekt | Status | Następny krok |
|---------|--------|---------------|
| maspex | aktywny | live check UAT / Redis circuit + ECS memory; ewentualnie review patcha observability/WAF |
| puzzler-b2b / PBMS | standby | DEV/QA jumphosty ustabilizowane; później commit staged `envs/dev/services.tf` i decyzja o `docs/db-access.md` |
| rshop | standby | utrzymać zakaz root deploy; wrócić później do permanent fix nested `TemplateURL` i ECS PropagateTags CFN patch |
| vault governance | standby | Knowledge Boundaries wdrożone; oczekuje ręcznego frontmatter w clients/mako/ + _chatgpt/ + llz/ |
| BMW AI Taskforce | scaffold gotowy | 20-projects/clients/bmw/ai-taskforce/ — czeka na pierwsze materiały od klienta |
| cloud-support-as-a-service | scaffold gotowy | 20-projects/internal/cloud-support-as-a-service/ — czeka na wypełnienie |
| devops-toolkit | w tle | Cloud Detective zapisany jako robocza capability; bez aktywnej pracy |
| devops-platform | w tle | |
| devops-business | w tle | |

## Priorytety tygodnia

1. Maspex: zweryfikować bieżącą tożsamość AWS `maspex-cli`, zanim robić live check albo Terraform.
2. Maspex: obserwować UAT po Redis reboot; szczególnie Redis circuit/write-through i memory `maspex-api`.
3. Maspex: jeśli wracamy do IaC, najpierw `terraform plan` i ocena blokady digest w `terraform-locks-969209893152`.
4. Maspex: osobno zbadać `maspex-bot` health check failures.
5. Puzzler-pbms pozostaje zapisany jako standby; nie mieszać staged `envs/dev/services.tf` bez explicit switch.

## Aktywni klienci

| Klient | Temat | Deadline |
|--------|-------|----------|
| Mako | Maspex / Kapsel UAT load-test follow-up + observability | |

## Blokery / otwarte pętle

- [ ] `rshop-cloudformation/cloudformation/{api,backoffice,frontend,frontend2}.yml` bez `PropagateTags`, `EnableECSManagedTags` i tagów ECS Service
- [ ] `infra-rshop/cloudformation/akcesoria2/svc.yml` ma tagi, ale brakuje `PropagateTags: SERVICE` i `EnableECSManagedTags: true`
- [ ] `rshop` root/nested CFN używa mutowalnych `TemplateURL`; app-only deploy przez root może replayować nowsze nested templates (`CFN-MUT-001`)
- [ ] Jenkins mitigation dla dev zapisany w `~/projekty/mako/eshop-cicd/jenkinsfiles/BE/{eshop-dev-aws,eshop-dev-aws-scan-2}.jenkinsfile`; nocny test nie dotknął root/VPC, ale ECS/app rollout padł na `NotStabilized`
- [ ] sprawdzić `Project=akcesoria2` w allowedValues LLZ Tag Policy przed re-enable
- [ ] Maspex: Terraform UAT plan blokuje stary/osierocony digest w `terraform-locks-969209893152`; safe recovery opisane w `02-active-context/now.md`
- [ ] Maspex: `infra-maspex` ma lokalny patch observability/WAF niezaaplikowany: WAF admin allowlist + Athena/Glue per-path CloudFront logs
- [ ] Maspex: Redis write-through/circuit breaker app-level po load teście 2026-05-05 19:00
- [ ] Maspex: `maspex-api` memory climbing podczas kolejnego testu
- [ ] Maspex: `maspex-bot` health check failures / replacements
- [ ] puzzler-pbms: commit staged `envs/dev/services.tf` guardrail parity
- [ ] puzzler-pbms: zdecydować co zrobić z untracked `docs/db-access.md`
- [ ] puzzler-pbms: uat/prod `secrets.tf` parity dla `ignore_changes`
- [ ] puzzler-pbms: opcjonalnie dodać healthcheck do obrazu/modułu jumphosta, bo ECS healthStatus jest UNKNOWN

## Powiązane

- [[now]] — co robię w tej chwili
- [[open-loops]] — rzeczy w toku bez zakończenia
- [[waiting-for]] — czekam na
- [[decision-log]] — decyzje do podjęcia

---

*Tydzień: 2026-W19*
