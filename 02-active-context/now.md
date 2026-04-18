# Teraz

> Aktualizuj przy każdej zmianie kontekstu. To jest twój punkt wejścia po przerwie.

## Aktywne zadanie

```
Zadanie:    infra-bbmt CFN tagging — incydent QA, czekamy na rollback
Projekt:    LLZ (Light Landing Zone) — MakoLab platform standard
Status:     BLOCKED — planodkupow-qa zakleszczony na rollback VPCStack
```

## Gdzie skończyłem

```
Ostatni krok:  Deployment QA z Tags na nested stackach + fix Redis 5.0.6
               Padł na Redis EOL (5.0.0) — fixed REDIS.yml → 5.0.6 (wgrane na S3)
               VPCStack rollback deadlock — czekamy na UPDATE_ROLLBACK_FAILED

Następny krok: Sprawdzić status planodkupow-qa:
               aws cloudformation describe-stacks --stack-name planodkupow-qa \
                 --profile plan --query 'Stacks[0].StackStatus' --output text

               Jak UPDATE_ROLLBACK_FAILED:
               aws cloudformation continue-update-rollback \
                 --stack-name planodkupow-qa --resources-to-skip VPCStack \
                 --profile plan --region eu-central-1

               Jak UPDATE_ROLLBACK_COMPLETE:
               deploy QA od nowa z Replace template + ROOT.yml z S3

Pliki:         ~/projekty/mako/aws-projects/infra-bbmt/cloudformation/ROOT.yml (zmieniony)
               ~/projekty/mako/aws-projects/infra-bbmt/cloudformation/REDIS.yml (zmieniony, 5.0.6)
               S3 poprzednia wersja ROOT.yml: VersionId Qn8EJ.mwtuYz43GF1JEl.JeV6t2OOsEQ
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

*Ostatnia aktualizacja: 2026-04-18 21:07 — sesja aktywna*
