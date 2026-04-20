# Workflow: ChatGPT + vault

> ChatGPT nie ma dostępu do filesystem. Kontekst musi być przygotowany i wklejony ręcznie.
> Ten dokument opisuje realistyczny, semi-automatyczny workflow.

---

## Ograniczenia techniczne

- ChatGPT (web) — brak dostępu do plików vault, brak integracji z git
- Automatic save "po każdej rozmowie" — **niemożliwe bez zewnętrznej integracji**
- Co jest możliwe: skrypty generujące szablony + dyscyplina ręcznego zapisu

## Workflow po rozmowie z ChatGPT

### Krok 1 — Zapisz podsumowanie (2-3 minuty)

```bash
# Generuje nowy plik z szablonu w _chatgpt/conversations/
./scripts/new-chatgpt-context.sh "Tytuł rozmowy" "zakres"
```

Uzupełnij w pliku:
- co było problemem
- jakie decyzje podjęto
- co zadziałało / nie zadziałało
- następne kroki
- kontekst do wklejenia przy powrocie do tematu

### Krok 2 — Zaktualizuj właściwy katalog (jeśli potrzeba)

Jeśli rozmowa dotyczyła konkretnego projektu:
- Zaktualizuj `20-projects/<projekt>/session-log.md`
- Zaktualizuj `02-active-context/now.md` jeśli zmienił się kontekst pracy

### Krok 3 — Opcjonalnie: przygotuj paczkę kontekstu

Jeśli temat będzie kontynuowany:
- Skopiuj plik `_chatgpt/conversations/<plik>.md` do `_chatgpt/context-packs/`
- Skróć do <2000 tokenów
- Dodaj do `_chatgpt/INDEX.md`

---

## Jak przygotować kontekst przed rozmową z ChatGPT

### Kontekst projektowy (konkretny projekt)

```
1. Otwórz 20-projects/<projekt>/context.md
2. Otwórz 02-active-context/now.md (sekcja projektu)
3. Otwórz 20-projects/<projekt>/session-log.md (ostatni wpis)
4. Wklej wszystko do ChatGPT jako "Kontekst:"
```

### Kontekst domenowy (np. AWS, Terraform)

```
1. Otwórz 10-areas/<domena>/LLM_CONTEXT.md
2. Dodaj relevant runbooki z 40-runbooks/
3. Dodaj relevant snippety z 90-reference/
```

### Kontekst globalny (nie wiesz od czego zacząć)

```
1. Wklej zawartość _system/LLM_CONTEXT_GLOBAL.md
2. Wklej sekcję "Aktywne zadanie" z now.md
```

---

## Format paczki kontekstu (template)

```markdown
## Kontekst dla ChatGPT — [tytuł]

**Projekt:** [nazwa]
**Data:** [data]
**Zakres:** [co omawiamy]

### Stan obecny
[2-5 zdań o aktualnym stanie]

### Kluczowe decyzje
- [decyzja 1]
- [decyzja 2]

### Pliki i zasoby
- [ścieżka lub ARN]

### Pytanie / problem
[co chcesz rozwiązać]
```

---

## Co jest automatyczne, co ręczne

| Czynność | Tryb | Narzędzie |
|----------|------|-----------|
| Generowanie szablonu notatki | Automatyczne | `scripts/new-chatgpt-context.sh` |
| Zapis podsumowania rozmowy | **Ręczne** | Edytor, template |
| Aktualizacja now.md | Semi-auto | Claude Code trigger |
| Aktualizacja session-log.md | Semi-auto | Claude Code trigger |
| Eksport do `context-packs/` | **Ręczne** | Kopiowanie + edycja |
| Wklejenie kontekstu do ChatGPT | **Ręczne** | Zawsze |

---

## Kiedy używać ChatGPT zamiast Claude Code

- Gdy potrzebujesz "drugiej opinii" bez kontekstu vault
- Gdy Claude Code ma problem z długim kontekstem
- Gdy chcesz szybką odpowiedź bez narzędzi
- Przy przygotowaniu dokumentacji dla zewnętrznych odbiorców (klientów, AWS SA)
