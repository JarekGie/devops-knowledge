# Minikurs Self-Test

#toolkit #self-test #minikurs

Mirror: `~/projekty/devops/devops-toolkit/docs/self-test-mini-course.md`

---

## Po co self-test

Dwa pytania na które odpowiada:
1. Czy toolkit jest poprawnie okablowany po zmianie?
2. Czy projekt jest gotowy do normalnego użycia lub release gate?

---

## Kiedy uruchamiać

```bash
# Po merge, rebase, refaktorze — quick check
toolkit self-test --scope quick

# Przed release / freeze
toolkit self-test --scope release --project-root /path/to/project

# Tylko projekt (bez toolkit)
toolkit self-test --scope project --project-root /path/to/project

# Tylko IaC / platforma
toolkit self-test --scope platform --project-root /path/to/project

# Tylko UI operatorski
toolkit self-test --scope ui
```

---

## Zakresy i co sprawdzają

| Scope | Co weryfikuje |
|-------|---------------|
| `quick` | CLI wiring, runtime, operator console, FinOps extraction, E2E split |
| `release` | quick + project readiness |
| `project` | onboarding files, FILL_IN, contracts, IaC structure |
| `platform` | IaC/platforma projektu |
| `ui` | routing konsoli, static assets, rejestracja komend |

---

## Debugging wyników

| Failure | Zwykle oznacza |
|---------|----------------|
| `runtime` | Brak zależności, zły interpreter, launcher drift |
| `ui` | Routing konsoli, static assets, rejestracja komend |
| `finops` | Output markers, normalized keys, copy/export contract drift |
| `e2e` | Odkrywanie scenariuszy lub safe-vs-strict validation drift |
| `project` | Brak onboarding files, nierozwiązane `FILL_IN`, słaba struktura IaC |

Pełny wynik strukturalny: `results.json` w katalogu runu.

---

## Przykłady

```bash
toolkit self-test --scope quick
toolkit self-test --scope ui
toolkit self-test --scope project --project-root ~/projekty/acme/infra-webapp
toolkit self-test --scope release --project-root ~/projekty/acme/infra-webapp
toolkit self-test --scope quick --format json
```

---

## Powiązane

- [[minikurs-shuttle-audit]]
- [[minikurs-operator]]
- [[command-catalog]]
