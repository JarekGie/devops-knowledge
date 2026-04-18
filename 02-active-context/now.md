# Teraz

> Aktualizuj przy każdej zmianie kontekstu. To jest twój punkt wejścia po przerwie.

## Aktywne zadanie

```
Zadanie:    LLZ governance — aws-cloud-platform IaC
Projekt:    LLZ (Light Landing Zone) — MakoLab platform standard
Status:     SCP + tag policies LIVE w AWS (2026-04-18), repo na gitlab
```

## Gdzie skończyłem

```
Ostatni krok:  terraform apply + push do gitlab (886364a, 3287f4c)
               SCP live: quarantine deny-all (p-wxsdn4cy), workloads baseline (p-flr98jkj)
               Tag policies zaktualizowane + wartości zweryfikowane live

Finding:       Żadne konto nie używa klient/projekt tagów (lowercase LLZ)
               Używają Project/Environment (PascalCase). Enforcement martwy
               dopóki LLZ standard nie wdrożony na projektach.

Następny krok: Sprawdzić rshop tagi live (profil rshop dostępny)
               Zdecydować o modules/platform/ w terraform-aws-modules
               Rozstrzygnąć CC i Admin MakoLab

Pliki:         ~/projekty/mako/aws-projects/aws-cloud-platform/organization/governance/
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

*Ostatnia aktualizacja: 2026-04-18 13:51 — sesja aktywna*
