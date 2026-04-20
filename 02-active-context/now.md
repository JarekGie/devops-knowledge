# Teraz

> Aktualizuj przy każdej zmianie kontekstu. To jest twój punkt wejścia po przerwie.

## Aktywne zadanie

```
Zadanie:    —
Status:     Brak aktywnego zadania
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
TODO:       Przed ponownym wdrożeniem Tag Policies — otagować ECS serwisy
            (Environment=prod, Project=rshop)
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

*Ostatnia aktualizacja: 2026-04-20 11:04 — sesja aktywna*
