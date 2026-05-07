# Current Focus

> Co jest ważne w tym tygodniu / sprincie. Nie lista todo — priorytety.

## Główny cel

```
Aktywny kontekst roboczy: puzzler-b2b / PBMS
Stan vault zapisany 2026-05-07 po przełączeniu z Maspex.
  - AWS profile: puzzler-pbms
  - account: 698220459519
  - region: eu-west-2
  - repo infra: ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
  - context: 20-projects/clients/mako/puzzler-b2b/session-log.md

Główna oś puzzler-pbms teraz:
  1. aws sts get-caller-identity --profile puzzler-pbms  (weryfikacja credentials)
  2. commit staged envs/dev/services.tf:
       git commit -m "fix(dev): align Terraform drift guardrails with QA ownership model"
  3. zdecydować co zrobić z untracked docs/db-access.md
  4. opcjonalnie: uat/prod secrets.tf parity (ignore_changes gaps)

Stan wejściowy z vault:
  - DEV i QA jumphosty: jumphost-v11 linux/amd64, operator-safe, ECS Exec OK, SSH OK, DocDB tunnel OK
  - staged: envs/dev/services.tf (usunięto local.azuread_secrets, 7x merge -> local.docdb_secrets)
  - terraform -chdir=envs/dev plan: No changes
  - untracked, nie commitować: docs/db-access.md
  - apply NIE wykonany od jumphosta

Ryzyka / uwagi:
  - terraform plan w DEV używa placeholderów dla sensitive TF_VAR; No changes = guardrail safe
  - uat/prod secrets.tf może nie mieć parity ignore_changes — sprawdzić przed apply QA/UAT/PROD
  - ECS healthStatus jumphostów: UNKNOWN (brak healthchecka w image); nie blokuje, ale uwaga

Wejście:
  - `02-active-context/now.md`
  - `20-projects/clients/mako/puzzler-b2b/session-log.md`
```

## Projekty aktywne

| Projekt | Status | Następny krok |
|---------|--------|---------------|
| puzzler-b2b / PBMS | aktywny | commit staged `envs/dev/services.tf`; decyzja o `docs/db-access.md`; uat/prod parity |
| maspex | standby | czeka na SSL certs od klienta; obserwować Redis circuit + ECS memory przy kolejnym teście |
| rshop | standby | utrzymać zakaz root deploy; wrócić później do permanent fix nested `TemplateURL` i ECS PropagateTags CFN patch |
| vault governance | standby | Knowledge Boundaries wdrożone; oczekuje ręcznego frontmatter w clients/mako/ + _chatgpt/ + llz/ |
| BMW AI Taskforce | scaffold gotowy | 20-projects/clients/bmw/ai-taskforce/ — czeka na pierwsze materiały od klienta |
| cloud-support-as-a-service | scaffold gotowy | 20-projects/internal/cloud-support-as-a-service/ — czeka na wypełnienie |
| devops-toolkit | w tle | Cloud Detective zapisany jako robocza capability; bez aktywnej pracy |
| devops-platform | w tle | |
| devops-business | w tle | |

## Priorytety tygodnia

1. Puzzler-pbms: `aws sts get-caller-identity --profile puzzler-pbms` — weryfikacja credentials przed czymkolwiek.
2. Puzzler-pbms: commit staged `envs/dev/services.tf` guardrail parity.
3. Puzzler-pbms: decyzja o `docs/db-access.md` (untracked, nie commitować przez przypadek).
4. Puzzler-pbms: uat/prod `secrets.tf` parity dla `ignore_changes` — sprawdzić przed kolejnym apply.
5. Maspex w standby — nie dotykać bez explicit switch z powrotem.

## Aktywni klienci

| Klient | Temat | Deadline |
|--------|-------|----------|
| Mako | Puzzler-B2B / PBMS — IaC guardrail commit + db-access decyzja | |

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
