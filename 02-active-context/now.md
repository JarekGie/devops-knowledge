# Teraz

> Aktualizuj przy każdej zmianie kontekstu. To jest twój punkt wejścia po przerwie.

## Aktywne zadanie

```
Zadanie:    planodkupow UAT — zakleszczony deployment
Projekt:    planodkupow (333320664022), eu-central-1, profil: plan
Status:     CZEKA NA ODPOWIEDŹ DEVA — zablokowane na RabbitMQ
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

## Zamknięte: LLZ health-notifications ✓ WDROŻONE

```
Stan:       APPLY COMPLETE (2026-04-20) — działa, email potwierdzony
Repo:       ~/projekty/mako/aws-projects/aws-cloud-platform/platform/health-notifications/
Architektura (finalna):
  - 11 member accounts (us-east-1): IAM role health-eventbridge-forward + EventBridge rule → monitoring bus
  - monitoring-nagios-bot (us-east-1): bus health-aggregation + rule → Lambda health-notify
  - Lambda (Python 3.12, us-east-1): nazwy kont z env var → formatuje email → SNS eu-central-1
  - SNS: nowy topic health-notifications na monitoring-nagios-bot + subskrypcja email potwierdzona
  - Filtr: tylko statusCode=open, category=issue|investigation

Koszt:      ~$0.00/miesiąc
Notatka:    20-projects/internal/llz/session-log.md
```

## Stan UAT po sesji 2026-04-20

```
Co zrobiono:
  - Dodano managed policy planodkupow-auto-CFN-Describe-Fix do planodkupow-auto
    (mq:DescribeBroker + rds:DescribeDBInstances)
  - DBStack:        UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS → powinien sam dojść
  - RedisStack:     UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS → powinien sam dojść
  - RabbitMQStack:  UPDATE_ROLLBACK_FAILED — zablokowane (patrz niżej)

Prawdziwy problem RabbitMQ:
  Deployment próbował: 3.8.6/t3.micro → 3.13/m5.large (broker replacement)
  Rollback próbuje wrócić do: 3.8.6 — AWS wycofał tę wersję z API
  Błąd: "Broker engine version [3.8.6] is invalid. Valid values: [4.2, 3.13]"
  Broker jest RUNNING (t3.micro, RUNNING) — dane bezpieczne

Wszystkie warianty --resources-to-skip zawiodły:
  BasicBroker                   → "does not belong to stack planodkupow-uat"
  RabbitMQStack                 → "Nested stacks could not be skipped"
  RabbitMQStack.BasicBroker     → "Stack [RabbitMQStack] does not exist"
  Bezpośrednio na nested stack  → "cannot be invoked on child stacks"

Opcje (czekamy na decyzję deva):
  A. AWS Support — ręczny reset stanu nested stack, 0 ryzyka, wolno
  B. Change set naprzód — deploy od nowa z naprawionym IAM, broker replacement
     (t3.micro/3.8.6 → m5.large/3.13), wymaga okna serwisowego
  C. Minimalne change set — dodać DeletionPolicy: Retain w S3 i odblokować
     przez change set bez ruszania brokera (ryzykowne)
```

## Zamknięte: maspex preprod ✓

```
Stan:       APPLY COMPLETE (2026-04-20)
            ALB: maspex-preprod-1322298306.eu-west-1.elb.amazonaws.com
            Redis: maspex-preprod.zwowz5.0001.euw1.cache.amazonaws.com:6379

TODO:       Wpisać do Secrets Manager maspex/preprod/api:
            aws secretsmanager put-secret-value \
              --secret-id arn:aws:secretsmanager:eu-west-1:969209893152:secret:maspex/preprod/api-STbBy3 \
              --secret-string '{"ConnectionStrings__Redis":"redis://maspex-preprod.zwowz5.0001.euw1.cache.amazonaws.com:6379"}' \
              --profile maspex-cli --region eu-west-1

            Gdy klient dostarczy certyfikaty/domenę:
            → terraform.tfvars: cloudfront_enabled=true + cert ARNs + domeny → plan + apply
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
Stan:          planodkupow-qa = CREATE_COMPLETE ✓ (2026-04-19 22:18)
               S3 przywrócone: 297 obj + 1293 obj ✓
               Backup buckety usunięte ✓
               
Drift:         ALB TG health check path zmieniony poza CFN:
               CFN myśli: HealthCheckPath = /signin
               Faktycznie działa: HealthCheckPath = /api/health
               
               Powód: Ocelot gateway (build 1244+) nie ma trasy /signin
               Fix tymczasowy: modify-target-group bezpośrednio na AWS
               Fix docelowy: update-stack z HealthCheckPath=/api/health
                             (po potwierdzeniu endpointu z dev teamem)

Następny krok:
               1. Rozmowa z dev teamem: jaki jest prawidłowy health check endpoint
                  dla Ocelot gateway w nowych buildach?
               2. update-stack planodkupow-qa z HealthCheckPath=<potwierdzony endpoint>
               3. Rozważyć też update UAT (RabbitMQ mq.t3.micro — ten sam bug co QA)
```

## Kontekst środowiska

```
AWS Account:  333320664022 (planodkupow)
Region:       eu-central-1
Profil CLI:   plan
Stack:        planodkupow-qa (CREATE_COMPLETE)
              planodkupow-uat (UPDATE_ROLLBACK_FAILED — RabbitMQStack)
```

## Kluczowe pliki

```
~/projekty/mako/aws-projects/infra-bbmt/cloudformation/ROOT.yml
~/projekty/mako/aws-projects/infra-bbmt/cloudformation/ECS.yml  (LogGroup DeletionPolicy: Retain)
~/projekty/mako/aws-projects/infra-bbmt/cloudformation/MSSQL.yml (DeletionPolicy: Retain, HasSnapshot)
~/projekty/mako/aws-projects/infra-bbmt/cloudformation/RMQ.yml  (3.13, mq.m5.large)
```

## Dokumentacja

- [[planodkupow-qa-postmortem]] — pełne RCA z sesji 1+2
- [[planodkupow-qa-execution-log]] — szczegółowy log operacyjny

## UAT — czerwone flagi (z audytu 2026-04-19)

```
RabbitMQ: mq.t3.micro — ten sam bug co QA. Jeśli UAT zostanie odbudowany,
          potrzebuje mq.m5.large (już naprawione w RMQ.yml).
S3 planodkupow-uat: 0 obiektów — podejrzane, sprawdzić z dev teamem.
RDS: DeletionProtection: False — włączyć prewencyjnie.
VPC Endpoint: 1x Interface — zablokuje subnet delete przy ewentualnym rebuild.
```

---

*Ostatnia aktualizacja: 2026-04-20 20:56 — sesja aktywna*
