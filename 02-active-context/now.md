# Teraz

> Aktualizuj przy każdej zmianie kontekstu. To jest twój punkt wejścia po przerwie.

## Aktywne: przełączenie kontekstu — infra-puzzler-b2b-final

```
Stan:       ACTIVE (2026-04-22)
Repo:       ~/projekty/mako/aws-projects/infra-puzzler-b2b-final
Projekt:    PBMS / Puzzler B2B
Env:        dev
Region:     eu-west-2

Punkt wejścia:
  - 20-projects/clients/mako/pbms/context.md
  - 40-runbooks/pbms-troubleshoot.md
  - 20-projects/clients/mako/puzzler-b2b/troubleshooting.md

Kluczowe fakty:
  - IaC: Terraform >= 1.5.0
  - ECS cluster: infra-puzzler-b2b-dev-puzzler
  - ALB: pbms-api-dev.makotest.pl
  - health check aplikacji: /health
  - aktywny branch z kontekstu: feat/dev-jumphost-runtime-secret

Uwagi:
  - To jest przełączenie kontekstu, nie nowa operacja.
  - UAT/prod poza zakresem do czasu jawnego polecenia.
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

## Zamknięte: rshop-prod-503 ✓

```
Stan:       RESOLVED — wszystkie 3 serwisy running=1 (2026-04-20)
Incydent:   40-runbooks/incidents/rshop-prod-503-2026-04-20.md
Plan:       40-runbooks/incidents/rshop-tag-policy-remediation.md
TODO:       Fix CFN (PropagateTags: SERVICE) na dev + akcesoria2 przed
            ponownym wdrożeniem Tag Policies przez Terraform
```

## Gdzie skończyłem

```
Stan:          planodkupow-qa = UPDATE_COMPLETE ✓ (2026-04-22 14:44 UTC+2)
               Dzisiejszy root update zakończony po długim UPDATE_IN_PROGRESS
               Jenkins timeout był fałszywym alarmem — AWS domknął operację

Diagnoza:      W trakcie update Gateway-SRVC wpadał w pętlę restartów:
               register target -> 404 na health check /signin -> unhealthy ->
               stop task -> replace task
               ECS osiągnął steady state dopiero o 2026-04-22 14:41 UTC+2

Potwierdzone:
               QA runtime:
                 - TG HealthCheckPath = /signin
                 - target zwracał 404 / Target.ResponseCodeMismatch
               UAT parameter:
                 - HealthCheckPath = /api/health

Fix przygotowany:
               Param-only, QA only, bez zmian template i bez uploadu do S3
               Change set: qa-healthcheck-api-health-1776862141
               Status: CREATE_COMPLETE
               Zmiana docelowa: HealthCheckPath = /api/health

Walidacja:
               SAFE
               - brak Replacement=True
               - brak zmian RabbitMQ
               - DBStack tylko Dynamic/ResourceAttribute
               - jedyna statyczna zmiana: ALBStack <- HealthCheckPath

Następny krok:
               Jeśli chcesz wykonać fix, uruchomić:
               aws cloudformation execute-change-set \
                 --stack-name planodkupow-qa \
                 --change-set-name qa-healthcheck-api-health-1776862141 \
                 --region eu-central-1 \
                 --profile plan
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

*Ostatnia aktualizacja: 2026-04-22 11:37 — sesja aktywna*
