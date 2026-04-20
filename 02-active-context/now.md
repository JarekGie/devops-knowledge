# Teraz

> Aktualizuj przy każdej zmianie kontekstu. To jest twój punkt wejścia po przerwie.

## Aktywne zadanie

```
Zadanie:    planodkupow-qa — środowisko odtworzone, drift do naprawienia
Projekt:    infra-bbmt (planodkupow)
Status:     GOTOWE — środowisko działa, jest jeden drift do wyeliminowania
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

*Ostatnia aktualizacja: 2026-04-20 08:20 — sesja aktywna*
