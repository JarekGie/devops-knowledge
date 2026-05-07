# Current Focus

> Co jest ważne w tym tygodniu / sprincie. Nie lista todo — priorytety.

## Główny cel

```
Aktywny kontekst roboczy: drp-tfs (klient mako)
Stan vault zapisany 2026-05-07 po przełączeniu z puzzler-pbms.
  - AWS profile: drp-tfs
  - account: 613448424242
  - region: eu-central-1
  - repo: ~/projekty/mako/drp_tfs
           ~/projekty/mako/dc-terraform/terraform-aws/environments/drp-tfs
  - context: 20-projects/clients/mako/drp-tfs/drp-tfs-context.md

Główna oś drp-tfs teraz:
  1. aws sts get-caller-identity --profile drp-tfs  (weryfikacja credentials)
  2. CRITICAL: diagnoza Mongo replica set — REPLICA_SET_GHOST, brak primary
     leasing-filters-api 0/2 i core-service 0/2 crashloop przez brak Mongo primary
  3. CRITICAL: diagnoza haproxy LoadBalancer EXTERNAL-IP <pending>
     mixed TCP+UDP protocol, NLB target groups puste
  4. po naprawie: live check serwisów + powtórzyć cloud-detective

Stan wejściowy z vault:
  - EKS drp-tfs-eks-cluster v1.30, nodegroup 4/4 Ready
  - większość tfs-prod deploymentów: running
  - MongoDB replica set EC2: drp-tfs-mongo-0/1/2
  - drp_tfs repo lokalnie dirty (mongo-ec2 playbook)

Ryzyka:
  - repo drp_tfs dirty — nie commitować bez review
  - repo_path w invocation manifest uszkodzony (�~/projekty/mako//drp-tfs)

Wejście:
  - `02-active-context/now.md`
  - `20-projects/clients/mako/drp-tfs/drp-tfs-context.md`
```

## Projekty aktywne

| Projekt | Status | Następny krok |
|---------|--------|---------------|
| drp-tfs | aktywny | CRITICAL: Mongo replica set + haproxy LoadBalancer pending |
| puzzler-b2b / PBMS | standby | CI/CD audit done; commit staged services.tf; decyzja AzureAd QA; decyzja docs/db-access.md |
| maspex | standby | czeka na SSL certs od klienta |
| rshop | standby | utrzymać zakaz root deploy; wrócić później do permanent fix nested `TemplateURL` i ECS PropagateTags CFN patch |
| vault governance | standby | Knowledge Boundaries wdrożone; oczekuje ręcznego frontmatter w clients/mako/ + _chatgpt/ + llz/ |
| BMW AI Taskforce | scaffold gotowy | 20-projects/clients/bmw/ai-taskforce/ — czeka na pierwsze materiały od klienta |
| cloud-support-as-a-service | scaffold gotowy | 20-projects/internal/cloud-support-as-a-service/ — czeka na wypełnienie |
| devops-toolkit | w tle | Cloud Detective zapisany jako robocza capability; bez aktywnej pracy |
| devops-platform | w tle | |
| devops-business | w tle | |

## Priorytety tygodnia

1. drp-tfs: `aws sts get-caller-identity --profile drp-tfs` — weryfikacja credentials.
2. drp-tfs: CRITICAL Mongo replica set — zbadać primary status na EC2 (mongo-0/1/2).
3. drp-tfs: CRITICAL haproxy LoadBalancer — mixed protocol fix lub workaround.
4. drp-tfs: po naprawie — powtórzyć live check leasing-filters + cloud-detective.
5. Puzzler-pbms w standby — CI/CD audit gotowy; wrócić gdy decyzja o AzureAd QA.

## Aktywni klienci

| Klient | Temat | Deadline |
|--------|-------|----------|
| Mako | drp-tfs — CRITICAL: Mongo replica set + haproxy LoadBalancer | |

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
