# Teraz

> Aktualizuj przy każdej zmianie kontekstu. To jest twój punkt wejścia po przerwie.

## Aktywne zadanie

```
Zadanie:    infra-bbmt CFN tagging — QA w UPDATE_ROLLBACK_FAILED
Projekt:    LLZ (Light Landing Zone) — MakoLab platform standard
Status:     BLOCKED — zostawione do poniedziałku, nic nie kasujemy
```

## Gdzie skończyłem

```
Stan:          planodkupow-qa = UPDATE_ROLLBACK_FAILED
               VPCStack: Internal Failure
               RabbitMQStack/BasicBroker: Lambda "This account is suspended"
               CFN nie pozwala skipować nested stacków → pętla bez wyjścia

Następny krok (poniedziałek):
               1. Sprawdzić status:
                  aws cloudformation describe-stacks --stack-name planodkupow-qa \
                    --profile plan --region eu-central-1 \
                    --query 'Stacks[0].StackStatus' --output text

               2. Jeśli dalej FAILED: zdecydować AWS Support vs delete+redeploy QA

               3. Po przywróceniu: deploy z Replace template + ROOT.yml z S3
                  (tagi na 8 stackach + REDIS 5.0.6)

Pliki:         ~/projekty/mako/aws-projects/infra-bbmt/cloudformation/ROOT.yml (zmieniony)
               ~/projekty/mako/aws-projects/infra-bbmt/cloudformation/REDIS.yml (5.0.6)
               S3 rollback: VersionId Qn8EJ.mwtuYz43GF1JEl.JeV6t2OOsEQ (ROOT.yml pre-zmian)
               20-projects/internal/llz/session-log.md
```

## Kontekst środowiska

```
AWS Account:
Region:
Env:          [ ] dev  [ ] staging  [ ] prod
Profil CLI:
```

## Otwarte terminale / sesje

- [ ] terminal 1 —
- [ ] terminal 2 —

## Szybkie linki

- [[current-focus]]
- [[open-loops]]
- [[command-catalog]]
- [[debugging-patterns]]

---

*Ostatnia aktualizacja: 2026-04-19 08:18 — sesja aktywna*
