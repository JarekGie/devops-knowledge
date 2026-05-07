# Current Focus

> Co jest ważne w tym tygodniu / sprincie. Nie lista todo — priorytety.

## Główny cel

```
Aktywny kontekst roboczy: puzzler-b2b / PBMS.
Stan vault zapisany 2026-05-07 po finalnej remediacji DEV/QA jumphostów:
  - AWS profile puzzler-pbms działa: account 698220459519, user makolab-ci,
  - DEV jumphost operational: task def :11, image jumphost-v11, ECS Exec OK, SSH OK, tunnel OK,
  - QA jumphost operational: task def :4, image jumphost-v11, ECS Exec OK, SSH OK, tunnel OK,
  - image jumphost-v11 pushed as linux/amd64 to DEV and QA ECR,
  - digest: sha256:4cd031cee7da3f5b874f3fadab93399a945ff4ccfecb6a333a4a7ed70f13e66d,
  - Dockerfile fixed: no UsePAM, AllowTcpForwarding yes via sed replacement,
  - Terraform db-jumphost now supports enable_execute_command; DEV/QA enabled,
  - targeted apply done only for jumphost task/service and jumphost_ssh secret version,
  - explicit aws ecs update-service done for jumphost only due to task_definition ignore_changes,
  - commits created:
      12fac50 fix(jumphost): stabilize sshd runtime and amd64 image build
      a5e5598 fix(terraform): enable ecs exec and normalize jumphost key handling
  - infra repo still has staged pre-existing envs/dev/services.tf guardrail parity change,
  - infra repo still has untracked docs/db-access.md.

Główna oś puzzler-pbms teraz:
  1. commit staged DEV guardrail parity change,
  2. nie mieszać untracked docs/db-access.md bez decyzji,
  3. opcjonalnie uat/prod secrets parity,
  4. opcjonalnie cleanup docs/context: stare wzmianki QA jumphost DOWN są już nieaktualne,
  5. przy kolejnych zmianach pamiętać, że ecs-service ignoruje task_definition i container_definitions.

Stan wejściowy z vault:
  - AWS profile: puzzler-pbms
  - region: eu-west-2
  - konto: 698220459519
  - repo infra: ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
  - context: 20-projects/clients/mako/puzzler-b2b/puzzler-b2b-context.md

Ryzyka / uwagi po ostatniej pracy:
  - staged envs/dev/services.tf to wcześniejsza guardrail parity zmiana, nie część jumphost commitów
  - docs/db-access.md untracked w infra repo — nie stagingować przypadkiem
  - envs/dev/.env istnieje jako pusty plik
  - runtime ECS task definitions nie zmienią się bez CI/CD albo force-replace
  - QA jumphost wcześniejszy blocker arm64-only / CannotPullContainerError rozwiązany przez jumphost-v11
  - healthStatus ECS tasków jumphosta = UNKNOWN, bo brak container healthcheck

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
| puzzler-b2b / PBMS | aktywny | DEV/QA jumphosty ustabilizowane; commit staged `envs/dev/services.tf`; potem decyzja o `docs/db-access.md` |
| maspex | standby | Load test report 19:00 zapisany; Redis reboot i CloudFront invalidation wykonane; obserwować przy kolejnym teście Redis circuit + ECS memory; Terraform observability/WAF patch nadal bez apply |
| rshop | standby | utrzymać zakaz root deploy; wrócić później do permanent fix nested `TemplateURL` i ECS PropagateTags CFN patch |
| vault governance | standby | Knowledge Boundaries wdrożone; oczekuje ręcznego frontmatter w clients/mako/ + _chatgpt/ + llz/ |
| BMW AI Taskforce | scaffold gotowy | 20-projects/clients/bmw/ai-taskforce/ — czeka na pierwsze materiały od klienta |
| cloud-support-as-a-service | scaffold gotowy | 20-projects/internal/cloud-support-as-a-service/ — czeka na wypełnienie |
| devops-toolkit | w tle | Cloud Detective zapisany jako robocza capability; bez aktywnej pracy |
| devops-platform | w tle | |
| devops-business | w tle | |

## Priorytety tygodnia

1. puzzler-pbms: commit staged DEV guardrail parity change w `infra-puzzler-b2b-final`.
2. puzzler-pbms: nie stagingować przypadkiem `docs/db-access.md` bez review.
3. puzzler-pbms: opcjonalnie uat/prod `secrets.tf` parity dla `ignore_changes`.
4. puzzler-pbms: opcjonalnie zaktualizować dłuższy `puzzler-b2b-context.md`, bo nadal ma historyczne wpisy QA jumphost DOWN.
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
- [ ] puzzler-pbms: opcjonalnie dodać healthcheck do obrazu/modułu jumphosta, bo ECS healthStatus jest UNKNOWN

## Powiązane

- [[now]] — co robię w tej chwili
- [[open-loops]] — rzeczy w toku bez zakończenia
- [[waiting-for]] — czekam na
- [[decision-log]] — decyzje do podjęcia

---

*Tydzień: 2026-W19*
