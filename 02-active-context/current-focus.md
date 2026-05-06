# Current Focus

> Co jest ważne w tym tygodniu / sprincie. Nie lista todo — priorytety.

## Główny cel

```
Przełączony kontekst roboczy: puzzler-b2b / PBMS.
Stan vault zapisany 2026-05-06 po pracach Maspex UAT:
  - raport load testu 2026-05-05 19:00 CEST zapisany,
  - Redis UAT maspex-uat node 0001 zrestartowany i wrócił do available,
  - CloudFront UAT API E3J76RNXIE2YIG invalidation /* zakończone jako Completed,
  - Maspex przesunięty do standby.

Główna oś puzzler-pbms:
  1. najpierw potwierdzić live AWS credentials dla profilu puzzler-pbms,
  2. sprawdzić aktualny live state dev/QA po ostatnim snapshotcie,
  3. zabezpieczyć repo przed przypadkowym commitem sekretów / authorized_keys,
  4. zweryfikować QA jumphost i ECR image missing,
  5. dopiero potem wracać do Terraform plan / IaC sync.

Stan wejściowy z vault:
  - AWS profile: puzzler-pbms
  - region: eu-west-2
  - konto: 698220459519
  - repo infra: ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
  - context: 20-projects/clients/mako/puzzler-b2b/puzzler-b2b-context.md

Ryzyka z ostatniego scan:
  - 2026-05-05 credentials puzzler-pbms były expired / SignatureDoesNotMatch
  - authorized_keys untracked na root repo + literówka .gitignore
  - envs/dev/.env untracked
  - QA IaC rozbudowane i niezatwierdzone
  - QA jumphost DOWN wg ostatniego live snapshotu: ECR image missing

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
| puzzler-b2b / PBMS | aktywny | precheck `aws sts get-caller-identity --profile puzzler-pbms`; potem live state dev/QA i repo working tree risk check |
| maspex | standby | Load test report 19:00 zapisany; Redis reboot i CloudFront invalidation wykonane; obserwować przy kolejnym teście Redis circuit + ECS memory; Terraform observability/WAF patch nadal bez apply |
| rshop | standby | utrzymać zakaz root deploy; wrócić później do permanent fix nested `TemplateURL` i ECS PropagateTags CFN patch |
| vault governance | standby | Knowledge Boundaries wdrożone; oczekuje ręcznego frontmatter w clients/mako/ + _chatgpt/ + llz/ |
| BMW AI Taskforce | scaffold gotowy | 20-projects/clients/bmw/ai-taskforce/ — czeka na pierwsze materiały od klienta |
| cloud-support-as-a-service | scaffold gotowy | 20-projects/internal/cloud-support-as-a-service/ — czeka na wypełnienie |
| devops-toolkit | w tle | Cloud Detective zapisany jako robocza capability; bez aktywnej pracy |
| devops-platform | w tle | |
| devops-business | w tle | |

## Priorytety tygodnia

1. puzzler-pbms: potwierdzić aktualne credentials i account identity przed jakimkolwiek live scan.
2. puzzler-pbms: sprawdzić repo `infra-puzzler-b2b-final` pod kątem untracked sekretów i lokalnych zmian przed `git add` / Terraform.
3. puzzler-pbms: zweryfikować dev/QA ECS, ECR i QA jumphost względem snapshotu 2026-05-01/05.
4. puzzler-pbms: ustalić, czy QA ECR image missing nadal blokuje jumphost.
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
- [ ] puzzler-pbms: potwierdzić czy profile credentials nadal expired czy już odświeżone
- [ ] puzzler-pbms: sprawdzić `authorized_keys` untracked i `.gitignore` literówkę
- [ ] puzzler-pbms: sprawdzić `envs/dev/.env` untracked / brak ignore rule
- [ ] puzzler-pbms: zweryfikować QA jumphost i ECR image tag

## Powiązane

- [[now]] — co robię w tej chwili
- [[open-loops]] — rzeczy w toku bez zakończenia
- [[waiting-for]] — czekam na
- [[decision-log]] — decyzje do podjęcia

---

*Tydzień: 2026-W19*
