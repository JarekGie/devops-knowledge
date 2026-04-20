# LLM_CONTEXT — 30-standards

## Cel katalogu

Standardy i konwencje obowiązujące w organizacji — AWS tagging, IaC, CI/CD, naming. Source of truth dla decyzji "jak to powinno być".

## Zakres tematyczny

Wszystko co jest **obowiązującym standardem** — nie wzorcem do rozważenia, ale regułą do stosowania.

## Najważniejsze notatki

| Plik | Opis |
|------|------|
| `aws-tagging-standard.md` | Wymagane tagi AWS (Project, Environment, ManagedBy, Owner) + Tag Policies |
| `iac-standard.md` | Konwencje Terraform: backend S3, versions.tf, struktura envs/ |
| `cicd-standard.md` | Pipeline patterns, branch strategy |
| `naming-conventions.md` | Nazewnictwo zasobów AWS, repozytoriów, plików |
| `documentation-standard.md` | Format notatek w vault |

## Konwencje nazewnicze

- Pliki: `<domena>-standard.md` lub `<domena>-conventions.md`
- Nie twórz `standard-v2.md` — aktualizuj istniejący plik

## Powiązania z innymi katalogami

- `[[../10-areas/]]` — wiedza domenowa będąca podstawą standardów
- `[[../80-architecture/decision-log]]` — ADR dokumentujące skąd pochodzi standard
- `[[../20-projects/internal/llz/]]` — LLZ implementuje te standardy

## Wiedza trwała vs robocza

- **Trwała (całość):** standardy zmieniają się rzadko i celowo
- Przy zmianie standardu: zaktualizuj plik + dodaj wpis do `80-architecture/decision-log.md`

## Jak przygotować kontekst dla ChatGPT

1. Skopiuj relevant standard (np. `aws-tagging-standard.md`)
2. Kontekst wystarczający do rozmowy o compliance lub audycie

---

## Ostatnia aktualizacja kontekstu

2026-04-20 — standardy stabilne

## Najważniejsze linki

- `[[aws-tagging-standard]]`
- `[[iac-standard]]`
- `[[naming-conventions]]`
