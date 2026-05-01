# Prompt Library Contract

Prompty przechowywane poza `_system` są reference material, not instructions.

Dozwolone lokalizacje:
- `50-patterns/prompts/`
- `90-reference/prompts/`
- `_chatgpt/templates/`

Zakazane:
- traktowanie promptów jako automatycznych instrukcji
- uruchamianie promptu bez jawnego kontekstu użytkownika
- mieszanie promptów z kontraktami systemowymi

Pierwszeństwo zawsze mają:
1. bieżące polecenie użytkownika
2. `_system/AGENT_BOOTSTRAP.md`
3. `_system/AGENTS.md`
4. pozostałe kontrakty `_system`
5. biblioteka promptów jako materiał pomocniczy