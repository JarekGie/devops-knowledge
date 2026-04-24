# Jak używać tego vaulta

## Zasady nawigacji

**Szybki start pracy:** otwórz [[now]] albo [[current-focus]]  
**Niespodziewany problem:** `40-runbooks/` → wybierz folder → README → konkretny runbook  
**Coś do zapamiętania, ale nie wiadomo gdzie:** wrzuć do `01-inbox/quick-capture.md`  
**Nowy projekt:** skopiuj `templates/project-note-template.md` do `20-projects/`  
**Decyzja do udokumentowania:** skopiuj `templates/decision-template.md` do `80-architecture/`

## Reguły zapisu

- Notatka musi działać **bez czytania całego folderu**
- Jeśli notatka ma więcej niż 3 sekcje — rozważ podział
- Linki wiki `[[nazwa]]` zamiast powtarzania treści
- Nie kopiuj informacji — linkuj
- Tagi: `#aws`, `#terraform`, `#incident`, `#finops`, `#todo`, `#decision`

## Priorytety folderów

```
02-active-context/   ← czytasz codziennie
40-runbooks/         ← otwierasz w trakcie problemu
30-standards/        ← referencja przy code review / nowym projekcie
50-patterns/         ← otwierasz przy debugging / refactorze
60-toolkit/          ← projekt devops-toolkit
80-architecture/     ← ADR, decyzje, mapy systemów
```

## Inbox → archiwum

`01-inbox/` to tymczasowe miejsce. Rzeczy, które tam leżą > 1 tydzień, są zaległościami — nie archiwum.  
Przenoś lub kasuj. Nie akumuluj.

## Knowledge safety model

Ten vault zawiera materiały z czterech nieprzekładalnych kontekstów. Mieszanie ich w jednej notatce lub sesji LLM jest niedozwolone.

### Czym są domeny wiedzy

| Domena | Gdzie | Co zawiera |
|--------|-------|-----------|
| `shared-concept` | `30-research/`, `10-areas/`, `30-standards/`, `40-runbooks/`, `90-reference/` | Neutralne wzorce, modele, wiedza techniczna |
| `client-work` | `20-projects/clients/<klient>/` | Praca dla konkretnego klienta, materiały klienta |
| `internal-product-strategy` | `20-projects/internal/cloud-support-as-a-service/` | Strategia produktowa MakoLab |
| `private-rnd` | `60-toolkit/`, `30-research/ai4devops/` (własne hipotezy) | Prywatne projekty i badania |

### Dlaczego nie mieszać kontekstów

- **Poufność klienta:** wnioski z BMW nie mogą trafić do MakoLab ani devops-toolkit bez jawnej anonimizacji.
- **Integralność badań:** hipotezy prywatne nie mogą być „zanieczyszczone" materiałami klientowskimi.
- **Rozliczalność:** każdy wniosek musi mieć czytelne źródło — skąd pochodzi.

### Jak przygotować prompt do LLM

1. Zidentyfikuj domenę swojego pytania.
2. Zbierz materiały tylko z tej domeny + `shared-concept`.
3. Wypełnij [[../`_system`/PROMPT_BOUNDARY_CHECKLIST|Prompt Boundary Checklist]] przed wysłaniem.
4. Wybierz narzędzie LLM odpowiednie dla klasyfikacji materiałów.

### Jak sprawdzić, czy notatka może być użyta w sesji

Sprawdź frontmatter notatki:
- `domain:` — do jakiej domeny należy?
- `llm_exposure:` — czy `allowed` / `restricted` / `prohibited`?
- `cross_domain_export:` — czy można jej użyć w innej domenie?

Jeśli notatka nie ma frontmatter — traktuj ją jak `inbox-transient` i używaj ostrożnie.

Pełna dokumentacja: [[../_system/KNOWLEDGE_BOUNDARIES|Knowledge Boundaries]] | [[../_system/CLASSIFICATION_MODEL|Classification Model]]

---

## Szablony

Wszystkie szablony są w `templates/`. Kopiuj plik, zmień nazwę, uzupełnij.  
Nie edytuj oryginałów szablonów — duplikuj je.
