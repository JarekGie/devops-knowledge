# Bootstrap — [Project Name]

> Szablon. Zastąp `[Project Name]` i wypełnij każdą sekcję danymi projektu.
> Ten plik to punkt wejścia po przerwie — ma dać pełny kontekst w 60 sekund.

## Szybki stan

```
PROJEKT:  [nazwa]
ACCOUNT:  [id] | [region] | profile: [aws-profile]
REPO:     [ścieżka lokalna]
BRANCH:   [aktywna gałąź]
VAULT:    [ścieżka do notatek]
```

## Otwarte zadania

| ID | Opis | Stan | GO? |
|----|------|------|-----|
| D1 | [opis driftu] | open | nie |
| P1 | [opis zadania] | conditional_go | wymagane |

## Zasady bezpieczeństwa

- **AWS:** READ ONLY domyślnie — tylko `describe*`, `get*`, `list*`, `metric queries`
- **Terraform:** `plan` wolny; `apply` wymaga osobnego GO
- **Git:** push bez force; destructive ops wymagają potwierdzenia
- **Żadnych zmian bez GO:** [wymień specyficzne dla projektu]

## Kluczowe pliki

| Plik | Zawartość |
|------|-----------|
| `[repo]/terraform/envs/prod/` | Terraform PROD |
| `[vault]/session-log.md` | historia sesji |

## Startup checklist

1. Przeczytaj `profiles/[projekt]/profile.yaml` — otwarte zadania
2. Przeczytaj `[vault]/session-log.md` — ostatnie 2 wpisy
3. Sprawdź `02-active-context/now.md` — bieżący focus
4. **Nie wykonuj żadnego apply bez GO** — safety_mode w profile.yaml

## Cross-references

- [[session-log]] — historia operacyjna
- [[now]] — bieżący aktywny kontekst
