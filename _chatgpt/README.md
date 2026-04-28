# _chatgpt — Przestrzeń eksportów dla ChatGPT

> ChatGPT nie ma dostępu do vault. Ten katalog to pomost między vault a ChatGPT.

---

## Do czego służy

- `conversations/` — podsumowania rozmów z ChatGPT (po każdej ważnej sesji)
- `context-packs/` — gotowe paczki kontekstu do wklejenia przed rozmową
- `templates/` — szablony do nowych notatek i paczek

## Jak używać

**Przed rozmową:** skopiuj odpowiednią paczkę z `context-packs/` do schowka → wklej do ChatGPT.

**Po rozmowie:** uruchom skrypt lub skopiuj szablon → uzupełnij → zapisz w `conversations/`.

```bash
# Nowa notatka po rozmowie:
./scripts/new-chatgpt-context.sh "Tytuł rozmowy" "zakres"
```

## Co tu przechowywać, czego nie

| Tak | Nie |
|-----|-----|
| Podsumowania decyzji z ChatGPT | Surowe logi rozmów (za długie) |
| Kontekst do ponownego wklejenia | Duplikaty tego co jest w projektach |
| Paczki tematyczne (np. "LLZ Faza B") | Pliki większe niż ~50KB |

## Cost-aware context packs

- Paczka ma zawierać minimalny kontekst wystarczający do zadania, nie pełny dump vault
- Preferuj linki do źródeł prawdy i krótkie evidence zamiast powtarzania stabilnego kontekstu
- Dobór modelu i długości promptu powinien respektować `_system/AI_COST_AWARE_AGENT_CONTRACT.md`

## Powiązania

- Workflow: `[[_system/CHATGPT_WORKFLOW]]`
- Kontekst globalny: `[[_system/LLM_CONTEXT_GLOBAL]]`
- Aktywny stan: `[[02-active-context/now]]`
- Cost-aware execution: `[[_system/AI_COST_AWARE_AGENT_CONTRACT]]`
