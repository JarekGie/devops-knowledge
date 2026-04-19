# Teraz

> Aktualizuj przy każdej zmianie kontekstu. To jest twój punkt wejścia po przerwie.

## Aktywne zadanie

```
Zadanie:    infra-bbmt CFN tagging — QA controlled rebuild
Projekt:    LLZ (Light Landing Zone) — MakoLab platform standard
Status:     AKTYWNE — strategia: delete + redeploy (rollback porzucony)
```

## Gdzie skończyłem

```
Stan:          planodkupow-qa = UPDATE_ROLLBACK_FAILED
               Diagnoza kompletna (2026-04-19):
               - RabbitMQStack: UPDATE_ROLLBACK_FAILED / BasicBroker (Lambda 403)
               - DBStack: UPDATE_ROLLBACK_FAILED / SQLDatabase (cancelled)
               - RedisStack: rollback zakończony sukcesem
               - Root stack failuje na RedisStack: "Stack does not exist"
               continue-update-rollback: PORZUCONE

Strategia:     DELETE + REDEPLOY (controlled rebuild)
Runbook:       40-runbooks/incidents/planodkupow-qa-cfn-rebuild.md

Następny krok:
               FAZA 0: Freeze Jenkins pipeline
               FAZA 1: Snapshot RDS (obowiązkowy)
               FAZA 3: delete-stack planodkupow-qa
               FAZA 4: Cleanup orphan resources
               FAZA 5: Redeploy

Pliki:         ~/projekty/mako/aws-projects/infra-bbmt/cloudformation/ROOT.yml (LLZ tags)
               ~/projekty/mako/aws-projects/infra-bbmt/cloudformation/REDIS.yml (5.0.6)
               S3 rollback: VersionId Qn8EJ.mwtuYz43GF1JEl.JeV6t2OOsEQ
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

*Ostatnia aktualizacja: 2026-04-19 09:56 — sesja aktywna*
