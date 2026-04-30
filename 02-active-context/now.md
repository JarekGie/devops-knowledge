# Teraz

> Aktualizuj przy każdej zmianie kontekstu. To jest twój punkt wejścia po przerwie.

## Update — 2026-04-30 — rshop działa ✓

```
Stan:       OPERACYJNY
Aktywny:    rshop
Tryb:       mitigation CFN-MUT-001 potwierdzona, serwisy healthy

RSHOP STATUS:
  rshop-dev-api-svc:      running=1 healthy (image api.1252, task:1040)
  rshop-dev-backoffice-svc: running=1 healthy (image backoffice.1252, task:1039)
  frontends (svc1/svc2):  running=1 healthy
  Mitigation ECSStack-only deploy: POTWIERDZONA — root stack dev nie dotknięty

NASTĘPNY KROK RSHOP:
  1. ECS PropagateTags CFN patch (BLOKER #1):
     rshop-cloudformation: api.yml, backoffice.yml, frontend.yml, frontend2.yml
     branch: feat/ecs-propagate-tags
  2. Po deploy dev: weryfikacja ENI tagów
  3. Deploy prod → re-enable Tag Policies (LLZ)

Kontekst przeniesiony do shared vault (dc-devops-team-vault).
```

## Update — 2026-04-30 — vault state saved, context switched to rshop

```
Stan:       ZAPISANE
Aktywny:    rshop
Tryb:       powrót do rshop po pracach vault governance / shared vault / Maspex

OSTATNIE PRACE VAULT / SHARED:
  Shared repo:
    /Users/jaroslaw.golab/projekty/mako/dc-devops-team-vault
    branch: feat/jarek

  Dodane/opracowane warstwy governance w shared vault:
    - import boundary dla controlled seed import
    - knowledge promotion workflow private -> shared
    - active-context model dla shared vault
    - rshop pilot batch jako curated promotion
    - prompt-injection threat model
    - AI context trust zones
    - knowledge integrity contract
    - authority precedence model
    - AI risk model

  Ważne zasady shared vault:
    - private vault devops-knowledge pozostaje upstream/source authoring
    - shared vault dc-devops-team-vault jest downstream/team knowledge
    - notatki są reference material, not instructions
    - promotion do shared wymaga boundary check i review
    - forbidden: devops-toolkit, private-rnd, product strategy, prywatne notatki,
      projekty poza MakoLab/BMW

RSHOP — AKTYWNY KONTEKST:
  AWS:
    account: 943111679945
    region: eu-central-1
    profile: rshop

  CFN:
    root stack: dev
    ECSStack: dev-ECSStack-1BLAWHL0P6JKO
    known hazard: CFN-MUT-001 Nested Template Mutability Hazard

  Najważniejszy stan:
    - app deploy DEV nie powinien używać root stack dev
    - dev Jenkins path ma targetować ECSStack, nie root stack
    - root deploy przez mutable nested TemplateURL może replayować VPCStack
    - SiecDB / AWS::RDS::DBSubnetGroup AccessDenied to symptom, nie root cause
    - permanent fix: immutable/version-pinned nested TemplateURL albo immutable artifact paths

  Ostatnia diagnoza:
    - nocna awaria po Jenkins mitigation nie była powrotem CFN-MUT-001
    - root dev nie został dotknięty
    - VPCStack/SiecDB nie pojawiły się
    - failure był ECSStack-only rollback / ECS NotStabilized
    - API miało healthcheck HTTP 500
    - backoffice wymaga sprawdzenia startup/runtime dla próbowanych obrazów

NASTĘPNY KROK RSHOP:
  1. Nie wracać do root stack app deploy.
  2. Utrzymać ECSStack-only dev deploy path + change-set guard.
  3. Sprawdzić aplikacyjne przyczyny ECS NotStabilized dla API/backoffice.
  4. Zaprojektować permanent fix CFN-MUT-001:
     immutable nested TemplateURL / versionId / immutable release artifact paths.
  5. Dopiero po stabilizacji deploy boundary wrócić do ECS tag propagation fix
     pod LLZ Tag Policies.

Maspex:
  zapisany jako standby; nie mieszać z aktywną sesją rshop.
```

## Update — 2026-04-29 — rshop DEV Jenkins overnight failure diagnosis

```
Stan:       ZAPISANE
Zakres:     rshop DEV Jenkins / CloudFormation / ECS read-only diagnosis

Najważniejszy wniosek:
  Nocna awaria nie była powrotem CFN-MUT-001.
  Root stack dev nie został dotknięty przez app deploy.
  VPCStack/SiecDB nie pojawiły się w nocnej ścieżce awarii.

AWS EVIDENCE:
  Root stack:
    dev = UPDATE_ROLLBACK_COMPLETE
    LastUpdatedTime = 2026-04-28T16:41:09Z
    brak nowych nocnych zdarzeń root/VPC/SiecDB

  ECSStack:
    dev-ECSStack-1BLAWHL0P6JKO = UPDATE_ROLLBACK_COMPLETE
    UPDATE_IN_PROGRESS User Initiated = 2026-04-28T21:46:07Z
    UPDATE_ROLLBACK_IN_PROGRESS = 2026-04-29T00:46:22Z
    UPDATE_ROLLBACK_COMPLETE = 2026-04-29T00:54:05Z

  Leaf failure:
    api child stack -> ApiSvc UPDATE_FAILED
      Resource handler returned message: "Exceeded attempts to wait"
      HandlerErrorCode: NotStabilized

    backoffice child stack -> BackofficeSvc UPDATE_FAILED
      Resource handler returned message: "Exceeded attempts to wait"
      HandlerErrorCode: NotStabilized

ECS CURRENT STATE:
  rshop-dev-api-svc:
    desired=1 running=1 pending=0 rollout=COMPLETED
    task definition dev-api-task:1040
    image api.1252
    target health healthy

  rshop-dev-backoffice-svc:
    desired=1 running=1 pending=0 rollout=COMPLETED
    task definition dev-backoffice-task:1039
    image backoffice.1252
    target health healthy

  Frontends:
    unchanged, running healthy

RUNTIME SIGNALS:
  API podczas nieudanego rollout miało ALB healthcheck failures HTTP 500.
  Backoffice miało powtarzane replacement/registration/draining events.
  Późniejszy list-tasks --desired-status STOPPED nie zwrócił task ARN,
  więc szczegóły stopped task containers nie były dostępne w późnym odczycie.

JENKINS LOG:
  Nie znaleziono lokalnego aktualnego console logu z tej nocy.
  Znalezione pliki #1292 dev.txt i #1342 dev.txt są stare i pokazują dawny root deploy,
  więc nie są dowodem dla tej awarii.

KLASYFIKACJA:
  - Jenkins-only failure: NIE
  - CloudFormation rollback: TAK, ograniczony do ECSStack
  - ECS/application rollout failure: TAK
  - guard failure: brak dowodu
  - AWS CLI/Jenkins sandbox issue: brak dowodu
  - CFN-MUT-001 recurrence: NIE

ZAPIS TRWAŁY:
  - 40-runbooks/incidents/rshop-dev-ecsstack-rollback-2026-04-29.md

NASTĘPNY KROK:
  1. Nie rerunować ślepo.
  2. Sprawdzić logi aplikacyjne dla obrazów próbowanych w tym rollout:
     API healthcheck 500 i backoffice startup/runtime.
  3. Utrzymać app deploy path przez ECSStack, nie root dev.
  4. Permanentnie naprawić CFN-MUT-001 przez immutable TemplateURL / artifact paths.
```

## Podsumowanie dnia — 2026-04-28

```
Stan:       ZAPISANE
Zakres:     rshop forensics + AI Cost Optimization governance + reusable CFN runbook pattern

RSHOP:
  - Zdiagnozowano fail deployu DEV po execute-change-set:
    pierwsza realna awaria = VPCStack / SiecDB / AWS::RDS::DBSubnetGroup
    błąd = AccessDenied na rds:ModifyDBSubnetGroup dla usera jenkinsit
  - Ustalono, że IAM nie jest root cause, tylko symptomem ukrytej mutacji infra.
  - Forensics wykazał pattern:
    app-only deploy -> root stack update -> mutable nested TemplateURL -> nowszy vpc-dev.yml z S3
    -> tag delta na zasobach VPC/SiecDB -> próba ModifyDBSubnetGroup.
  - Drift check VPCStack: IN_SYNC, SiecDB PropertyDifferences=[].
  - Wniosek operacyjny:
    NIE dodawać ślepo rds:ModifyDBSubnetGroup; najpierw wyeliminować hidden VPCStack mutation
    albo jawnie zatwierdzić infra/tag rollout.

UTWORZONE / ZAKTUALIZOWANE:
  - 20-projects/clients/mako/rshop-tagging-remediation-2026-04-24.md
    dopisano DEV CFN deploy failure + forensics mutable TemplateURL.
  - 40-runbooks/aws/cloudformation-nested-template-mutability-hazard.md
    nowy reusable runbook pattern: CFN-MUT-001 Nested Template Mutability Hazard.
  - _system/AI_COST_AWARE_AGENT_CONTRACT.md
    nowy kontrakt Cost-Aware Agent Execution Policy / AI FinOps lite.
  - AGENTS.md, CLAUDE.md, CODEX.md, LLM_CONTEXT_GLOBAL.md, CHATGPT_WORKFLOW.md,
    _chatgpt/README.md, _chatgpt/templates/context-pack-template.md
    minimalne addytywne linki do cost-aware contract.
  - 100-ai-cost-optimization/prompts/
    przenośna biblioteka promptów 01-06 + README dla rollout/audit/context optimization/model tiering/AI FinOps.

NASTĘPNY KROK RSHOP:
  1. Nie retry root app deploy dopóki VPCStack mutation nie jest wyjaśniona/wyeliminowana.
  2. Rozdzielić app deploy od infra/tag rollout albo przypiąć nested TemplateURL do immutable artifactu.
  3. Dopiero potem wrócić do pierwotnego ECS PropagateTags/EnableECSManagedTags fix.

NIE RUSZANE:
  - .obsidian/workspace.json — zmiana lokalnego workspace Obsidian
  - 10-areas/private/Subskrypcje.md — osobna nieśledzona notatka
```

## Update — 2026-04-28 wieczór — rshop CFN-MUT-001 Jenkins mitigation

```
Stan:       ZAPISANE
Zakres:     rshop DEV deploy path mitigation w eshop-cicd Jenkinsfiles

AWS / CFN:
  - Root stack dev po kolejnych testach Jenkins ponownie reprodukował CFN-MUT-001:
    app-intended root deploy -> VPCStack -> SiecDB -> rds:ModifyDBSubnetGroup AccessDenied.
  - Minimalny recovery pattern nadal: continue-update-rollback z resources-to-skip:
    dev-VPCStack-FFQTYHECIX9M.SiecDB.
  - Cascade resources typu RouteTables / InternetGateway miały "Resource update cancelled";
    nie są samodzielnym powodem do rozszerzania skip listy bez świeżego evidence.

ECS HOTFIX TEST:
  - ECSStack-only change set 1253 został reviewowany i wykonany kontrolowanie.
  - Runtime 1253 nie był stabilny:
    API 1253 -> ALB healthcheck HTTP 500.
    Backoffice 1253 -> EssentialContainerExited / exit code 139.
  - CFN/ECS może zostawiać nowe TaskDefinition revisions po rollbacku;
    UPDATE_ROLLBACK_COMPLETE nie oznacza automatycznie runtime quiescence.

JENKINS MITIGATION:
  Repo: ~/projekty/mako/eshop-cicd
  Pliki zmienione:
    - jenkinsfiles/BE/eshop-dev-aws.jenkinsfile
    - jenkinsfiles/BE/eshop-dev-aws-scan-2.jenkinsfile

  Co zmieniono:
    - dla params.Envi == 'dev' CloudFormation target = dev-ECSStack-1BLAWHL0P6JKO
      zamiast root stack dev
    - qa/uat zostają na dotychczasowym UpEnv/root flow
    - dev używa ECSStack params: apiimg/backofficeimg lowercase + reszta UsePreviousValue
    - dev nie wysyła root-only params: ALBDNS, DB, CF cert/domain, Engine*, DeployDB
    - dev create-change-set ma --include-nested-stacks
    - dodany pre-execute guard blokujący VPCStack/DBStack/SGStack/IAMStack/S3Stack/CFStack/SiecDB
      oraz AWS::EC2/RDS/IAM/S3/ElasticLoadBalancingV2
    - allowed dev scope: api/backoffice nested stacks + AWS::ECS::TaskDefinition/AWS::ECS::Service

Review:
  - eshop-dev-aws-scan-2.jenkinsfile przeszedł review PASS dla:
    dev stack target, qa/uat unchanged, lowercase ECS params, no root-only dev params,
    include-nested-stacks, guard before execute, execute/wait using CfnStackName,
    changeSetIdBackend scoping unchanged.

Następny krok:
  - Kontrolowany Jenkins test dev po upewnieniu się, że root dev/ECSStack nie są w toku.
  - Nadal traktować to jako mitigation deployment path, nie permanent fix.
  - Permanent fix: immutable nested TemplateURL pinning / release artifact paths + runtime guard.
```

## Aktywne teraz: rshop — Tag Policy remediation

```
Stan:       KONTEKST PRZEŁĄCZONY (2026-04-28)
Cel:        przygotować CFN fix dla ECS Tag Policy readiness przed re-enable LLZ Tag Policies

Wejście:
  - 02-active-context/current-focus.md
  - _chatgpt/context-packs/rshop-tag-policy.md
  - 40-runbooks/incidents/rshop-tag-policy-readiness.md
  - 20-projects/clients/mako/rshop-tagging-baseline-2026-04-24.md

Następny krok:
  1. Przetestować Jenkins dev path po mitigation: app deploy ma iść do dev-ECSStack-1BLAWHL0P6JKO, nie root dev
  2. Utrzymać zakaz root stack app deploy do czasu immutable TemplateURL pinning / release artifact paths
  3. Po stabilnym deploy boundary wrócić do ECS PropagateTags/EnableECSManagedTags fix

Maspex:
  zapisany jako standby; nie mieszać z bieżącą sesją rshop.
```

## Standby: Maspex — load test analysis + Terraform observability/WAF work

```
Stan:       ZAPISANE / STANDBY (2026-04-28 późny wieczór)
Repo:       ~/projekty/mako/aws-projects/infra-maspex
Env:        terraform/envs/uat
AWS:        profile maspex-cli, region eu-west-1, account 969209893152

LOAD TEST REPORT:
  - Utworzono raport:
    20-projects/clients/mako/maspex/load-test-analysis-2026-04-28-1730-cest.md
  - Okno analizy: 2026-04-28 15:15-16:15 UTC, rozszerzone 15:00-16:30 UTC.
  - Wniosek: ruch testowy widoczny głównie 15:40-16:00 UTC.
    CloudFront ~1.04M requests, ALB/API ~575k requests.
  - Brak potwierdzonej saturacji ECS / ALB / Redis.
  - Autoscaling API nie skalował, bo CPU/memory były poniżej progów.
  - Luka: brak CloudFront CacheHitRate/OriginRequests/OriginLatency datapoints
    oraz brak per-path metrics dla /api/slogan, /_next/image*, /_next/static/*.

TERRAFORM CHANGES PREPARED, NOT APPLIED:
  Repo ma lokalne zmiany:
    - terraform/envs/uat/main.tf
    - terraform/envs/uat/waf.tf
    - terraform/envs/uat/cloudfront_observability.tf
    - terraform/modules/cloudfront-site/main.tf
    - terraform/modules/cloudfront-site/variables.tf

  Implementacja:
    - CloudFront module dostał opcjonalne web_acl_id.
    - UAT admin CloudFront ma dostać WAFv2 CLOUDFRONT allowlist:
      195.117.107.110/32, 91.233.19.251/32.
    - WAF tworzony przez provider aws.us_east_1, scope CLOUDFRONT.
    - API CloudFront nie jest ograniczane WAF-em.
    - Observability: Athena database + Glue table nad istniejącymi CloudFront standard logs
      z prefixu s3://maspex-uat-access-logs-969209893152/cloudfront/maspex-uat/api/
      oraz named query grupujące /api/slogan, /_next/image*, /_next/static/* po x_edge_result_type.

VALIDATION:
  - terraform fmt dla zmienionych plików: OK.
  - terraform validate w terraform/envs/uat: OK.
  - terraform plan: BLOKADA backendu remote state, nie błąd kodu.

REMOTE STATE BACKEND DIAGNOSIS:
  Backend UAT:
    bucket = terraform-state-969209893152
    key = maspex/uat/terraform.tfstate
    dynamodb_table = terraform-locks-969209893152
    region = eu-west-1

  Evidence:
    - S3 latest state exists, versioning enabled.
    - S3 latest LastModified: 2026-04-28T06:46:38Z
    - S3 latest ETag / local md5: 891cfb7b5e1475192a717c12ca9fae1a
    - State parses as Terraform state v4, Terraform 1.5.7, serial 123, resources 97.
    - DynamoDB UAT md5 item:
      LockID = terraform-state-969209893152/maspex/uat/terraform.tfstate-md5
      Digest = 48a21bb5c16aa5ce693a2734910bd456
    - Brak aktywnego lock itemu bez suffixu -md5.
    - Digest 48a21... odpowiada starej wersji S3 z 2026-04-23T10:00:16Z.
    - shared i preprod mają digest zgodny z aktualnym S3 ETag.

  Wniosek:
    Najbardziej prawdopodobny root cause = stary/osierocony digest w DynamoDB
    dla UAT, nie uszkodzony state.

  Safe recovery, DO NOT RUN automatically:
    conditional update tylko rekordu Digest:
      old = 48a21bb5c16aa5ce693a2734910bd456
      new = 891cfb7b5e1475192a717c12ca9fae1a
    Wykonać dopiero po freeze Terraform dla UAT i ponownym prechecku S3/DDB.

NIE ROBIĆ:
  - nie apply Terraform przed zdrowym planem
  - nie usuwać locków
  - nie cofać wersji S3 state
  - nie edytować state ręcznie
  - nie aktualizować digest bez condition-expression i świeżego prechecku

POWRÓT DO MASPEX:
  1. Precheck S3 head-object + DDB get-item + brak lock itemu.
  2. Conditional update DDB digest, jeśli ETag nadal 891cfb...
  3. terraform init -reconfigure -backend-config=backend.hcl
  4. terraform validate
  5. terraform plan -no-color
  6. Review plan: expected add WAF/IPSet/Athena/Glue + in-place web_acl_id only on admin CF.
```

## Zamknięte: vault — CloudOps/SOC-lite discovery thread ✓

```
Stan:       DONE (2026-04-24)
Lokalizacja: 20-projects/internal/cloudops-soc-lite/

Utworzone:
  README.md                           — discovery index + exploratory kanban
  CLOUDOPS_SOC_LITE_HYPOTHESIS.md     — geneza, working hypothesis (Prevent/Detect/Respond)
  EXISTING_CAPABILITIES_AS_FOUNDATION.md — mapa GLPI/Wazuh/Nagios/on-call + current/future-state diagram
  PILOT_IDEA_GLPI_CLOUD_EVENTS.md     — minimalny pilot: AWS Health → GLPI + GuardDuty → Wazuh
  INCUBATION_STRATEGY.md              — small-circle first; 3 fazy dogfooding→internal→customer-facing
  CONNECTION_TO_LLZ_AND_NIS2.md       — LLZ jako Prevent layer, NIS2 kontekst, audytowalność

Kluczowe hipotezy:
  - Nie "SOC", lecz CloudOps visibility capability na istniejącym stacku
  - Prevent (LLZ) → Detect (Wazuh + AWS findings) → Respond (GLPI + on-call)
  - Adoption before branding — najpierw dogfooding przez Cloud Support Team
  - AWS Health → GLPI Problems jako minimalny pilot (Lambda bridge + EventBridge)

Powiązania:
  ↔ 20-projects/internal/cloud-support-as-a-service/
  ↔ 20-projects/internal/llz/
  ↔ 10-areas/observability/
```

## Zamknięte: vault — governance layer knowledge boundaries ✓

```
Stan:       DONE (2026-04-24)
Zakres:     separacja domen BMW / Cloud Support as a Service / private-rnd / shared-concept

Utworzone:
  _system/:
    KNOWLEDGE_BOUNDARIES.md     — mapa domen, szybka reguła decyzyjna
    CLASSIFICATION_MODEL.md     — 7 klas domen + 4 klasy wrażliwości + dopuszczalne wartości frontmatter
    DOMAIN_ISOLATION_CONTRACT.md — 7 reguł MUST/MUST NOT
    LLM_CONTEXT_BOUNDARY_CONTRACT.md — zasady sesji LLM: jedna sesja = jedna domena
    ORIGIN_METADATA_CONTRACT.md — obowiązkowy frontmatter dla nowych notatek
    DERIVATIVE_INSIGHT_RULES.md — legalna ścieżka przeniesienia wiedzy z client-work
    PROMPT_BOUNDARY_CHECKLIST.md — 12 pytań przed każdym promptem do LLM
    BOUNDARY_REVIEW_REPORT.md   — raport audytowy + akcje ręczne do wykonania

  20-projects/clients/bmw/ai-taskforce/ — 8 plików (scaffold klientowski)
  20-projects/internal/cloud-support-as-a-service/ — 8 plików (scaffold strategii)
  60-toolkit/cloud-detective/ — research-boundaries.md + ai4devops-relationship.md

Zaktualizowane:
  30-research/ai4devops/README.md — frontmatter + kontrakt domeny + callout boundary
  _system/LLM_CONTEXT_GLOBAL.md — zasada globalna: jedna sesja = jedna domena
  00-start-here/how-to-use-this-vault.md — sekcja Knowledge safety model

Oczekujące (ręczne — z BOUNDARY_REVIEW_REPORT.md):
  - Dodać frontmatter do 20-projects/clients/mako/*/troubleshooting.md
  - Dodać frontmatter do _chatgpt/context-packs/*.md
  - Przejrzeć 90-reference/notebooklm/
  - Rozstrzygnąć klasyfikację llz/ (internal-product-strategy vs private-rnd)
  - Dodać frontmatter do 60-toolkit/README.md i kontraktów komend
```

## Zamknięte: vault — AI4DevOps research space ✓

```
Stan:       DONE (2026-04-24)
Lokalizacja: 30-research/ai4devops/

Utworzone:
  README.md                    — mapa pojęć, hipotezy, relacje z LLZ/toolkit
  AI4DEVOPS_REFERENCE_MODEL.md — 5-warstwowa architektura referencyjna
  ITSM_AI_OPPORTUNITIES.md     — mapa 6 procesów ITIL × AI
  VENDORS_AND_PATTERNS.md      — Dynatrace/IBM/PagerDuty/ServiceNow/Moogsoft
  AI_SECURITY_IN_DEVOPS.md     — prompt injection, agent security, guardrails
  CLOUD_DETECTIVE_CONNECTIONS.md — hipotezy ewolucji cloud-detective
```

## Zamknięte: puzzler-b2b — sync + builder IaC ✓

```
Stan:       DONE (2026-04-24)
Repo:       ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
Zakres:     envs/dev — nowe serwisy Sync i Builder za gateway

Zmiany:
  - services.tf: module "sync_service" (L343) + module "builder_service" (L384)
  - service_discovery.tf: pbms-sync-dev.pbms.local + pbms-builder-dev.pbms.local
  - variables.tf: sync_image + builder_image (default nginx:latest)
  - terraform.tfvars: placeholders z # BLOCKER

Walidacja: terraform validate → SUCCESS
terraform plan: wymaga aktywnej sesji AWS (puzzler-pbms)

BLOCKER: Ocelot routes + SwaggerForOcelot są w kodzie gateway (pbms-backend),
nie w tym repo. Dev team musi dodać w ocelot.json:
  /sync/{everything} → pbms-sync-dev.pbms.local:8080/{everything}   [SwaggerKey: Sync]
  /builder/{everything} → pbms-builder-dev.pbms.local:8080/api/{everything}   [SwaggerKey: Builder]

BLOCKER: zastąp nginx:latest docelowymi URI ECR po zbudowaniu obrazów
Notatka: 20-projects/clients/mako/puzzler-b2b/troubleshooting.md
```

## Zamknięte: maspex — CloudFront / observability infra sprint ✓

```
Stan:       DONE (2026-04-24) — terraform apply wykonany
Repo:       ~/projekty/mako/aws-projects/infra-maspex
Branch:     feat/preprod-zaslepka
Env:        UAT | AWS profile: maspex-cli | Region: eu-west-1

Co wdrożono (terraform apply — 5 added, 2 changed, 0 destroyed):

  CloudFront `E3J76RNXIE2YIG` (kapsel.makotest.pl):
    - nowy behavior `/_next/image*` → cache policy image_optimizer (QS=all, min_ttl=0, default=86400)
    - nowy behavior `/favicon.ico` → cache policy static_assets (86400s)
    - /favicon.ico walidacja: Hit from cloudfront ✓ | Cache-Control: max-age=31536000

  CloudWatch monitoring:
    - metric filter RedisCircuitOpenCount + alarm maspex-uat-api-redis-circuit-open
    - dashboard rows 11-12: CF CacheHitRate / OriginRequests / Redis Circuit Open
    - Logs Insights: top-request-paths + next-image-and-favicon-origin-hits

Otwarte po stronie app teamu:
  - potwierdzić czy /_next/image z realnymi URL-ami daje Hit from cloudfront
  - sprawdzić minimumCacheTTL w next.config.js (jeśli < 86400: rozważyć image_cache_min_ttl=86400)
  - patch aplikacyjny next-core-app (resolveCount Redis-only) — nadal lokalny, niecommitowany

Notatka: 20-projects/clients/mako/maspex/troubleshooting.md
```

## Zamknięte: Cloud Detective — robocze miejsce w vault ✓

```
Stan:       DONE (2026-04-23)
Zakres:     robocza przestrzeń do myślenia o Cloud Detective jako capability devops-toolkit
Lokalizacja: 60-toolkit/cloud-detective/

Utworzone pliki:
  - README.md
  - vision.md
  - boundaries.md
  - use-cases.md
  - open-questions.md

Kluczowe założenia zapisane:
  - Cloud Detective nie jest osobnym produktem ani silnikiem
  - capability / warstwa rozpoznania i oceny środowiska wewnątrz prywatnego devops-toolkit
  - zachowuje granice danych toolkitu: raw nie do AI, dane klienta w repo klienta
  - decyzje o API, raporcie, UI i brandingu są nadal otwarte

Następny kontekst: Maspex troubleshooting.
```

## Zamknięte: maspex UAT admin-panel — CloudFront static origin policy ✓

```
Stan:       DONE (2026-04-23)
Repo:       ~/projekty/mako/aws-projects/infra-maspex
Branch:     feat/preprod-zaslepka
Commit:     4810f3c fix uat admin cloudfront static origin policy

Objaw:
  - /auth/login przez CloudFront 200, ale login wyglądał jak surowy HTML
  - /_next/static/* przez CloudFront zwracało 502
  - kontener/admin-panel serwował assety poprawnie lokalnie

Root cause:
  - admin CloudFront ordered behaviors /_next/static/* i /static/* miały cache policy,
    ale nie miały origin_request_policy_id
  - default behavior miał Managed-AllViewer, więc dynamiczne ścieżki działały
  - statyczne behavior'y nie forwardowały poprawnego viewer request context do ALB origin

Fix:
  - w module cloudfront_site dla admin distribution dodano:
    static_path_origin_request_policy_ids:
      /_next/static/* -> 216adef6-5c7f-47e4-b989-5492eafa07d3
      /static/*       -> 216adef6-5c7f-47e4-b989-5492eafa07d3

Apply:
  - AWS_PROFILE=maspex-cli terraform -chdir=terraform/envs/uat apply -no-color -auto-approve
  - wynik: 0 added, 1 changed, 0 destroyed
  - zmieniony zasób: module.cloudfront_site.aws_cloudfront_distribution.this[0]
  - dystrybucja: E3R9U1TWNUJZ11

Post-apply:
  - CloudFront status: Deployed
  - invalidation: IC6KFOVSRK9VLU54BZTSVGGQXE
  - /auth/login: 200
  - CSS / JS / font assety: 200

Notatka:    20-projects/clients/mako/maspex/troubleshooting.md
```

## Aktywne: PBMS backend — Swagger Core 500

```
Stan:       ZDIAGNOZOWANE KODOWO (2026-04-22)
Repo app:   ~/projekty/mako/pbms-backend
Objaw:      /swagger/docs/v1/Core -> HTTP 500

Architektura:
  - gateway używa SwaggerForOcelot
  - /swagger/docs/v1/Core pobiera downstream:
    http://pbms-core-qa:8080/swagger/v1/swagger.json

Najmocniejszy trop:
  - Core response DTO:
      MediaModel.DeliveryDefinition
      SupplyResponse.DeliveryDefinition
  - typ: IMediaDeliveryModel
  - interface ma SwaggerSubType(...)
  - konfiguracja polimorfizmu w ConfigureSwaggerOptions.cs jest zakomentowana

Wniosek:
  500 najpewniej powstaje w Core Swagger generation przy schemacie
  interfejsu IMediaDeliveryModel, nie w gateway routingu.

Minimalny fix:
  - zmienić tylko typ DeliveryDefinition w:
    PBMS.Core/Models/Media/MediaModel.cs
    PBMS.Core/Models/Supply/SupplyResponse.cs
  - z IMediaDeliveryModel -> object

Walidacja:
  1. http://pbms-core-qa:8080/swagger/v1/swagger.json
  2. /swagger/docs/v1/Core
```

## Zamknięte: LLZ audit-pack llz-waf-readonly patch ✓

```
Stan:       DONE (2026-04-20)
Co:         6 bugów naprawionych w 6 pluginach (cloudtrail/observability/tagging/scp + region fallback)
Testy:      129/129 PASS (było 121 — dodano 8 behavioral tests)
Kluczowe:   llz.required_tags + llz.monitoring_account_id + llz.workloads_ou_name wymagane w project.yaml
Notatka:    20-projects/internal/llz/session-log.md (2026-04-20 patch)
```

## Zamknięte: planodkupow QA — RabbitMQ UPDATE_ROLLBACK_FAILED + RECREATE + CUTOVER ✓

```
Stan:       DONE (2026-04-21 ~13:50 UTC+2)

Root cause: planodkupow-auto brak mq:UpdateBroker + mq:RebootBroker → AccessDenied na update + rollback
            CFN drift (frozen mq.t3.micro vs real mq.m5.large) → każdy deploy próbował UpdateBroker

Incydent 1 (09:09): mq:UpdateBroker AccessDenied → naprawa: dodano ręcznie
Incydent 2 (10:02): mq:RebootBroker AccessDenied na rollback → naprawa: policy v5
Recovery x3: continue-update-rollback z skip PN8W0DD6SK1U.BasicBroker (profil plan)

Drift fix (zamiast IMPORT): RECREATE + CUTOVER
  Nowy broker: b-f231815d, planodkupow-qa-rabbitmq-cheap, mq.m7g.medium (~$66/mies. vs $197 m5.large)
  Cutover: change set mqcs-cutover-to-new-broker na KlasterStack-1F8B7693FIMIX
           UPDATE_COMPLETE, 14/14 ECS serwisów healthy
  Stary broker: b-5cb3fcb4 — DELETION_IN_PROGRESS (usunięty 2026-04-21 profilem plan)

IAM policy planodkupow-auto-CFN-Describe-Fix:
  v5: + mq:RebootBroker
  v6: + mq:CreateBroker, mq:DeleteBroker

Stan końcowy:
  - root planodkupow-qa:              UPDATE_ROLLBACK_COMPLETE
  - planodkupow-qa-KlasterStack:      UPDATE_COMPLETE ✓
  - Broker QA aktywny: b-f231815d, mq.m7g.medium, RUNNING
  - Stary broker b-5cb3fcb4:          DELETION_IN_PROGRESS

OTWARTE:
  - cloudformation:ContinueUpdateRollback na planodkupow-auto (opcjonalnie, breakglass)
  - RabbitMQStack nadal w root stack → plan migracji gotowy (patrz niżej)

Runbook:    40-runbooks/incidents/planodkupow-qa-rabbitmq-rollback-failed.md
```

## Zamknięte: planodkupow QA — CFN refaktor (RabbitMQ poza root stack) ✓

```
Stan:       DONE (2026-04-21 22:42)

Wykonane:
  - SSM /planodkupow/qa/rabbitmq/mqcs (String, Version 2) ✓
  - ROOT.yml patchowany z deployed template jako bazy (nie z repo!) ✓
  - Change set remove-rabbitmq-safe-1776803624 — EXECUTED ✓
  - Root stack: UPDATE_COMPLETE ✓
  - RabbitMQStack: usunięty z root ✓
  - ECS: 14/14 running, 0 pending ✓

Kluczowe lekcje:
  - patchuj DEPLOYED template (get-template), nie wersję z repo
  - tag drift = DBStack DirectModification = rollback przez SQLDatabase replacement
  - ssm-secure nie działa dla nested stack params → tylko ssm + String
  - continue-update-rollback wymaga dwóch kroków (nested + root)

Runbook:    40-runbooks/planodkupow-rabbitmq-cfn-refactor.md
```

## Zamknięte: planodkupow — audyt tagów FinOps (Faza 1) ✓

```
Stan:       DONE (2026-04-21)

Wyniki:
  - QA: nowy schemat (Project/Environment/Owner/ManagedBy/CostCenter) — kompletny
  - UAT: stary schemat (Maintainer/Provisioner/Team/Client/typ) — brakuje Owner/ManagedBy/CostCenter
  - CloudFront QA (EORCEYNXGKU9K): BRAK TAGÓW — DO NOT TOUCH
  - CloudFront UAT (x3): stary schemat — DO NOT TOUCH
  - RDS UAT: tagować bezpośrednio przez rds add-tags-to-resource (NIE przez CFN)
  - CostCenter nie ma odpowiednika w starym schemacie → konieczna addytywna zmiana

Decyzja wymagana przed Fazą 3:
  - Czy Owner=DC-devops właściwy dla UAT (był Maintainer=3rd party - Tribecloud)?
  - Potwierdzenie CostCenter=DC dla UAT

Runbook:    40-runbooks/planodkupow-tagging-finops.md
```

## Zamknięte: planodkupow QA — FinOps remediation sprint ✓ (P1.1 pending compliance gate)

```
Stan:       SPRINT CLOSED (2026-04-26) — P1.1 execution pending compliance gate
Projekt:    planodkupow, 333320664022, eu-central-1, profil: plan

Zrobione:
  runtime-verification-2026-04-26.md  — skompilowane evidence ze wszystkich live CLI runs:
    ECS PropagateTags: 26/28 serwisów = NONE (UAT) → tag propagation broken
    MQ orphan: b-f231815d (nowy QA broker) — ZERO tagów, poza CFN stackiem
    CW log groups: 164.39 GB, 93 grupy NEVER_EXPIRES (UAT broker b-2d26b881 dominant)
    VPC endpoints: 4 orphan w starym VPC (out-of-scope nowego QA VPC)
    EIP: 1 unassociated ($3.60/mies. waste)
    WAF, GA, ECR: zero governance tags

  remediation-runbook-2026-04-26.md  — 4-fazowy runbook (P0/P1/P2/P3), 4 rundy patchy:
    P0: snapshot collection (read-only) — wykonany w dry-run
    P1.1: CloudWatch retention (4 etapy), DRY_RUN=true — wykonany, wynik walidowany
    Kluczowe poprawki w runbooku:
      - rollback: delete-retention-policy (NIE: retention-in-days 0 — invalid API value)
      - risk: MEDIUM compliance (NIE: zero)
      - scope: snapshot-locked targeting (NIE: live prefix re-query → scope expansion risk)
      - shell: while IFS= read -r (NIE: for-in — zsh word-split bug)
      - broker b-52e41f96 dodany do CHAOS_PATTERN (odkryty dopiero w P0.3)
      - savings: $4.67/mies. storage (NIE: $58/mies. — błąd ×12-24)
    Split retention: RETENTION_DAYS_ACTIVE=90 (Stage 1 UAT broker), RETENTION_DAYS_ORPHAN=30 (Stage 2+3 chaos)

Kluczowe ustalenia:
  - $97-126/mies. CW wzrost = ingestion z ECS logów (jednorazowy), NIE storage MQ
  - Storage CW: $4.93/mies. (164 GB × $0.03), savings po retention fix: $4.67/mies.
  - GO verdict na P1.1 — warunkowo: wymaga team confirmation na 90-day retention policy

Otwarte (poza scope zamkniętego sprintu):
  - P1.1 execution: czeka na compliance sign-off → flip DRY_RUN=false
  - P1.2–P1.9: MQ tagging, WAF/GA/ECR tagging, EIP release
  - P2 (ECS PropagateTags): wymaga scheduled deploy window
  - P3 (old VPC teardown): wymaga 7-day metric gate + business sign-off

Artefakty:
  20-projects/clients/mako/planodkupow-runtime-verification-2026-04-26.md
  20-projects/clients/mako/planodkupow-ce-audit-2026-04-26.md
  40-runbooks/incidents/planodkupow-remediation-runbook-2026-04-26.md
```

## Zamknięte: standard IaC + ECS Competency mapping ✓

```
Stan:       DONE (2026-04-21)

Pliki:
  - 20-projects/clients/mako/wdrozenie-standardow-organizacji/standard-iac-tagging-naming.md
    Dodana sekcja 8a: ECS patterns (PropagateTags, Capacity Providers, Container Insights,
    CloudFront ingress, GuardDuty Runtime Monitoring)
  - 20-projects/clients/mako/wdrozenie-standardow-organizacji/ecs-competency-llz-mapping.md
    Mapa: LLZ kontrola → ECS-XXX requirement ID, backlog remediacji, WAFR skrót
  - 20-projects/clients/mako/wdrozenie-standardow-organizacji/aws-competency-certyfikaty-bloker.md
    Twardy bloker: 0/3 Pro/Specialty, brakuje 4/8 wymaganych certyfikatów
  - _chatgpt/context-packs/llz.md — zaktualizowany (cfn_messaging_audit, planodkupow status)

Kluczowe wnioski:
  - ECS-011 (runtime security) + LLZ EPIC 4 GuardDuty = ten sam backlog item
  - ECS-018 (observability) blokuje oba projekty — priorytet #1 do naprawy
  - WAFR zero-HRI = automatyczne spełnienie Common Requirements (shortcut)
  - Certyfikaty: brak Pro/Specialty = formalny bloker aplikacji Competency
    Rekomendacja: DevOps Engineer Pro + Security Specialty (Jarosław)
```

## Zamknięte: maspex UAT/preprod — monitoring + CloudFront + .gitignore ✓

```
Stan:       DONE (2026-04-22)

UAT:
  - SNS topic maspex-uat-alarms + email subscription jaroslaw.golab@makolab.com
  - Wszystkie alarmy CloudWatch (11) podłączone do SNS
  - CloudWatch Logs Insights: nowy query errors-by-path
  - CloudFront API (E3J76RNXIE2YIG / kapsel.makotest.pl):
    behaviors /_next/static/* + /landing/* z min_ttl=86400
  - ECS service lifecycle: ignore_changes = [desired_count, task_definition]
    → GitLab CI/CD zarządza task definitions, Terraform nie nadpisuje

Preprod:
  - ALB routing fix: admin_panel_domain=twojkapsel.pl → "Not Found" naprawiony
  - CloudFront static caching: /_next/static/* + /static/* dodane

Repo:
  - terraform.tfvars commitowane (branch chore/add-tfvars, mergowane na main)
  - .gitignore: **/.claude/settings.local.json + .codex/ zignorowane
  - branch chore/add-tfvars mergowany → main aktualny

TODO:
  - SNS subscription wymaga potwierdzenia email (klik "Confirm subscription")
  - Redis connection string do Secrets Manager: maspex/preprod/api (otwarte)
```

## Aktywne: planodkupow UAT — CFN refaktor (RabbitMQ poza root stack)

```
Stan:       DO WDROŻENIA
Stack:      planodkupow-uat (UPDATE_ROLLBACK_COMPLETE)
Broker UAT: b-2d26b881-79f2-4c3c-8b77-06c1a0fb0b29, mq.t3.micro, RUNNING

Następne kroki (według runbooka):
  1. Zweryfikuj stan stacka i brokera UAT
  2. aws ssm put-parameter /planodkupow/uat/rabbitmq/mqcs (String, nie SecureString)
  3. get-template ze stacka → patch (MQCS + usuń RabbitMQStack)
  4. Upload ROOT.yml → s3://planodkupow-cf/ROOT.yml
  5. Change set — walidacja (HARD STOP jeśli DBStack Static/Direct)
  6. Execute + monitoring

Runbook:    40-runbooks/planodkupow-rabbitmq-cfn-refactor.md
Repo:       ~/projekty/mako/aws-projects/infra-bbmt
```

## Zamknięte: planodkupow UAT — RabbitMQ UPDATE_ROLLBACK_FAILED ✓

```
Zadanie:    planodkupow UAT — RabbitMQ UPDATE_ROLLBACK_FAILED
Projekt:    planodkupow (333320664022), eu-central-1, profil: plan
Repo:       ~/projekty/mako/aws-projects/infra-bbmt

Status:     DONE OPERACYJNIE (2026-04-21)

Wykonane:
  - root stack odblokowany: continue-update-rollback z skip:
    planodkupow-uat-RabbitMQStack-1XMB1IYDKWTXU.BasicBroker
  - root planodkupow-uat: UPDATE_ROLLBACK_COMPLETE
  - RabbitMQ child stack: minimalny sync EngineVersion 3.8.6 -> 3.13, UPDATE_COMPLETE
  - Redis child stack: minimalny sync EngineVersion 5.0.0 -> 5.0.6, UPDATE_COMPLETE
  - IAM dla planodkupow-auto: baseline CFN read + ValidateTemplate/CreateChangeSet/DescribeChangeSet/ExecuteChangeSet

Ważny wniosek:
  - root CFN formalnie rusza wszystkie nested stacki w eventach
  - realne resource-level zmiany przy app deployu z --use-previous-template dotyczą tylko KlasterStack (ECS)

Preflight:
  - app-only deploy na root stacku z --use-previous-template: GO
  - root deploy z aktualnym ROOT.yml jako szeroki change set: nadal NOT SAFE

Runbook:    40-runbooks/incidents/planodkupow-uat-rabbitmq-rollback-failed.md
```

## Zamknięte: LLZ context pack + AGENTS kontrakt ✓

```
Stan:       DONE (2026-04-20)
Co:         _chatgpt/context-packs/llz.md — pełny kontekst LLZ dla LLM (11 sekcji)
            _system/AGENTS.md — kontrakt dla dokumentów kontekstowych
Następne:   Faza B — GuardDuty org-wide (HRI, EPIC 4)
```

## Zamknięte: LLZ WAF checklist ✓

```
Stan:       Gotowe (2026-04-20)
Plik:       20-projects/internal/llz/waf-checklist.md
Wynik:      ~30% WAF-ready, 4 HRI, quick wins zidentyfikowane
HRI:        GuardDuty (SEC 4), SCP (SEC 1), IR plan (SEC 10), DR plan (REL 13)
```

## Zamknięte: LLZ health-notifications ✓ WDROŻONE + ZWERYFIKOWANE

```
Stan:       APPLY COMPLETE (2026-04-20) + test OK (2026-04-22)
Repo:       ~/projekty/mako/aws-projects/aws-cloud-platform/platform/health-notifications/
Architektura (finalna):
  - 11 member accounts (us-east-1): IAM role health-eventbridge-forward + EventBridge rule → monitoring bus
  - monitoring-nagios-bot (us-east-1): bus health-aggregation + rule → Lambda health-notify
  - Lambda (Python 3.12, us-east-1): nazwy kont z env var → formatuje email → SNS eu-central-1
  - SNS: nowy topic health-notifications na monitoring-nagios-bot + subskrypcja email potwierdzona
  - Filtr: tylko statusCode=open, category=issue|investigation

Weryfikacja (2026-04-22):
  - Lambda invoke bezpośredni → StatusCode 200, brak błędów, SNS publish OK
  - Email testowy wysłany: [AWS Health] EC2 open — planodkupow (eu-central-1)
  - Infrastruktura w pełni sprawna; brak realnych eventów od 20.04 (normalny stan)

Koszt:      ~$0.00/miesiąc
Notatka:    20-projects/internal/llz/session-log.md
```

## Stan UAT po sesji 2026-04-21

```
Stan końcowy:
  - root planodkupow-uat: UPDATE_ROLLBACK_COMPLETE
  - RabbitMQStack: UPDATE_COMPLETE
  - RedisStack:    UPDATE_COMPLETE
  - DBStack:       UPDATE_COMPLETE

RabbitMQ:
  Broker: b-2d26b881-79f2-4c3c-8b77-06c1a0fb0b29
  State:  RUNNING
  Ver:    3.13.7
  Type:   mq.t3.micro

Redis:
  EngineVersion: 5.0.6
  NodeType:      cache.t3.micro
  Status:        available

IAM:
  planodkupow-auto-CFN-Describe-Fix -> default v3
  validate-template / create-change-set / describe-change-set działają profilem planodkupow-auto

Deploy pattern:
  ostatni udany root app deploy formalnie rusza 9 nested stacków,
  ale realne resource-level zmiany występują tylko w KlasterStack (ECS services + task definitions)
```

## Zamknięte: maspex preprod + CloudFront ✓

```
Stan:       DONE (2026-04-21)
            ALB: maspex-preprod-1322298306.eu-west-1.elb.amazonaws.com
            Redis: maspex-preprod.zwowz5.0001.euw1.cache.amazonaws.com:6379
            CloudFront: E17VHHQJ29MVAB → d1epwako2iigq8.cloudfront.net
            Domena: twojkapsel.pl + www.twojkapsel.pl
            HTTP→HTTPS redirect: aktywny
            Static caching: /_next/static/* + /static/* (min_ttl=86400)

TODO:       - Wpisać Redis do Secrets Manager maspex/preprod/api
            - DNS wysłany klientowi (CNAME → d1epwako2iigq8.cloudfront.net)
            - Warning w modules/alb/main.tf:65 (niekrytyczny)

Notatka:    20-projects/clients/mako/maspex/troubleshooting.md
```

## Zamknięte: maspex UAT — CloudFront static caching + lukasz.fuchs SSM ✓

```
Stan:       DONE (2026-04-21)

CloudFront static caching:
  Problem:  Cache-Control: max-age=0 → CloudFront nie cachował (Miss from cloudfront)
  Fix:      aws_cloudfront_cache_policy (min_ttl=86400) + ordered_cache_behavior
            /_next/static/* + /static/* na dystrybucji E3R9U1TWNUJZ11
  Efekt:    Statyki cachowane 24h; dynamiczne requesty bez zmian

lukasz.fuchs SSM:
  Policy:   maspex-uat-redis-ssm-access (v2) — ECS Exec + SSM + cloudshell:*
  Redis:    maspex-uat.zwowz5.0001.euw1.cache.amazonaws.com:6379
  Dostęp:   CloudShell → ecs execute-command → redis-cli

Drift ECS:  task_definition v31→v24 na service_api — NIE naprawiony (decyzja CI/CD vs TF)

Notatka:    20-projects/clients/mako/maspex/troubleshooting.md
```

## Zawieszone: udemy-transcript-tool

```
Stan:       CDP zaimplementowane, czeka na test
Blokada:    Chrome musi być uruchomiony z --remote-debugging-port=9222
Następny krok:
            1. Zamknąć Chrome (Cmd+Q)
            2. Uruchomić z flagą:
               /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
                 --remote-debugging-port=9222 \
                 --user-data-dir="$HOME/Library/Application Support/Google/Chrome" &
            3. Sprawdzić: curl -s http://localhost:9222/json/version | python3 -m json.tool
            4. bash run.sh (dry-run --verbose)
Projekt:    20-projects/internal/udemy-transcript-tool
Pliki:      udemy_obsidian/browser.py — tryb CDP w __aenter__
            udemy_obsidian/cli.py    — flaga --cdp-url
            run.sh                   — gotowe komendy
```

## Aktywne: rshop — Tag Policy remediation (audit DONE, czeka na CFN fix)

```
Stan:       AUDIT DONE (2026-04-24) — Tag Policies nadal WYŁĄCZONE
Incydent:   40-runbooks/incidents/rshop-prod-503-2026-04-20.md (RESOLVED)
Plan:       40-runbooks/incidents/rshop-tag-policy-readiness.md

Audyt AWS: 2026-04-24, konto 943111679945, eu-central-1
Pliki:
  - 20-projects/clients/mako/rshop-tagging-baseline-2026-04-24.md  ← pełny raport
  - 40-runbooks/incidents/rshop-tag-policy-readiness.md             ← runbook re-enable

Top 5 blokerów przed re-enable Tag Policies:
  1. [KRYTYCZNE] rshop-cloudformation: brak PropagateTags/Tags/EnableECSManagedTags
     w 4 plikach (api/backoffice/frontend/frontend2.yml) — każdy CFN deploy resetuje
     propagateTags do NONE → natychmiastowa awaria po re-enable
  2. [KRYTYCZNE] akcesoria2/svc.yml: Tags są, ale brak PropagateTags: SERVICE
     i EnableECSManagedTags: true — 2 linie na serwis
  3. [KRYTYCZNE] Weryfikacja allowedValues LLZ Tag Policy dla Project=akcesoria2
     (może nie być w allowedValues — sprawdzić w terraform LLZ)
  4. [WYSOKIE] dev-ALB stary schemat Tribecloud (brakuje Project/Owner/CostCenter/ManagedBy)
  5. [WYSOKIE] ECR rshopapp-prod/qa/uat: brakuje Project, Owner, ManagedBy, CostCenter

Następny krok: przygotować CFN patche (krok 1 i 2 z listy blokerów)
  → branch feat/ecs-propagate-tags w rshop-cloudformation
  → commit 4 pliki + akcesoria2/svc.yml
  → deploy na dev → weryfikacja ENI → deploy prod
```

## Zamknięte: rshop-prod-503 ✓

```
Stan:       RESOLVED (2026-04-20)
Incydent:   40-runbooks/incidents/rshop-prod-503-2026-04-20.md
Plan:       40-runbooks/incidents/rshop-tag-policy-remediation.md
```

## Zamknięte: BMW AI Taskforce — ITSM AI Mapping Excel ✓

```
Stan:       DONE (2026-04-28)
Pliki:      20-projects/clients/bmw/ai-taskforce/ai-taskforce.xlsx      ← oryginał EN
            20-projects/clients/bmw/ai-taskforce/ai-taskforce-pl.xlsx   ← kopia PL
Session:    20-projects/clients/bmw/ai-taskforce/session-log.md

Co zrobiono:
  - Arkusz Excel wzbogacony jako senior AIOps/ITSM/EA konsultant
  - Manage Problems: skorygowano 50% → 20–30% (halucynacje RCA, brak full observability)
  - Manage Knowledge: podniesiono do 40–55% (GenAI impact na drafting/search)
  - Kolumna "Saving" → "Effort Reduction Potential"
  - Nowe kolumny: Prerequisites / Maturity Required + AI Type Classification
  - Uzupełniono brakujące wiersze: Svc Configuration, Capacity, IT Service Continuity
  - Dodano 3 nowe wiersze: Change Management, CMDB/Asset Mgmt, Cloud Ops/SRE
  - Executive summary: high value/low risk vs high risk/advanced maturity
  - Polska wersja: ai-taskforce-pl.xlsx — pełne tłumaczenie treści + nazwy arkuszy

Otwarte:
  - Development section (Plan→Deploy) nadal bez AI data w arkuszu
  - Ewentualny transfer do pptx
  - Omówienie prerequisites maturity z BMW
```

## Gdzie skończyłem

```
Aktywny projekt: MASPEX
Stan:          CloudFront /api/slogan cache GOTOWE DO APPLY (przygotowane 2026-04-26)
Repo:          ~/projekty/mako/aws-projects/infra-maspex
Branch:        feat/preprod-zaslepka (wypchnięty na GitLab)

Następny krok (WEJŚCIE PO PRZERWIE):
  1. terraform apply UAT — CloudFront /api/slogan behavior
  2. Weryfikacja: curl → Miss, potem Hit na /api/slogan?page=1&sortBy=votes_desc
  3. Obserwacja CacheHitRate na dashboard maspex-uat-overview ~15 min

⚠️ Uwagi przed apply:
  - ECS lifecycle zmiana (ignore_changes bez desired_count) dotyka UAT + preprod
    Sprawdź desired_count w UAT tfvars przed apply
  - /api/slogan trailing slash: behavior nie obejmuje /api/slogan/ — sprawdzić po apply

Notatka projektu: 20-projects/clients/mako/maspex/
Ostatni raport:   20-projects/clients/mako/maspex/cloudfront-audit-2026-04-26.md
```

## Kontekst środowiska

```
AWS Account:  333320664022 (planodkupow)
Region:       eu-central-1
Profil CLI:   plan
Stack:        planodkupow-qa (CREATE_COMPLETE)
              planodkupow-uat (UPDATE_ROLLBACK_COMPLETE)
```

## Kluczowe pliki

```
Repo root:    ~/projekty/mako/aws-projects/infra-bbmt
~/projekty/mako/aws-projects/infra-bbmt/cloudformation/ROOT.yml
~/projekty/mako/aws-projects/infra-bbmt/cloudformation/ECS.yml  (LogGroup DeletionPolicy: Retain)
~/projekty/mako/aws-projects/infra-bbmt/cloudformation/MSSQL.yml (DeletionPolicy: Retain, HasSnapshot)
~/projekty/mako/aws-projects/infra-bbmt/cloudformation/RMQ.yml  (3.13, mq.m5.large)
```

## Stan repo

```bash
Branch: main
Dirty:  cloudformation/ECS.yml
        cloudformation/MSSQL.yml
        cloudformation/REDIS.yml
        cloudformation/RMQ.yml
        cloudformation/ROOT.yml
        cloudformation/ROOT_CLEANED_DEV.yml
        .gitignore (untracked)
        .DS_Store
```

## Dokumentacja

- [[planodkupow-qa-postmortem]] — pełne RCA z sesji 1+2
- [[planodkupow-qa-execution-log]] — szczegółowy log operacyjny

## UAT — czerwone flagi / otwarte kwestie

```
Root safe-minimal:
  root change set z aktualnym ROOT.yml nadal formalnie dotyka 9 nested stacków — nie używać jako "minimalnego" syncu
S3 planodkupow-uat: 0 obiektów — podejrzane, sprawdzić z dev teamem.
RDS: DeletionProtection: False — włączyć prewencyjnie.
RabbitMQ: template drift naprawiony minimalnie na child stacku; nie wracać do 3.8.6.
```

---

*Ostatnia aktualizacja: 2026-04-30 12:36 — sesja aktywna*
