---
title: BMW AI Taskforce — kontrakt granic danych
domain: client-work
origin: own
classification: confidential
llm_exposure: restricted
cross_domain_export: prohibited
source_of_truth: vault
created: 2026-04-24
updated: 2026-04-24
---

# BMW AI Taskforce — kontrakt granic danych

> Formalne zasady zarządzania danymi klientowskimi BMW w tym vault.
> Obowiązuje wszystkich agentów LLM pracujących z tymi materiałami.

---

## Identyfikacja klienta

- **Klient:** BMW (pełna nazwa wg NDA / umowy — tu nie umieszczamy)
- **Projekt:** AI Taskforce
- **Klasyfikacja umowna:** *[np. NDA — do uzupełnienia z umowy]*
- **Data obowiązywania:** *[do uzupełnienia]*

---

## Granice danych — co MUST NOT opuścić tej przestrzeni

**MUST NOT** opuścić tej przestrzeni vault bez jawnej anonimizacji:

- Nazwy systemów IT BMW
- Nazwy działów, procesów, projektów BMW
- Dane liczbowe z systemów BMW (SLO, wolumeny, koszty)
- Imiona i nazwiska pracowników BMW
- Materiały prezentacyjne oznaczone jako poufne przez BMW
- Transkrypty spotkań z BMW

---

## Co MAY być eksportowane jako derived insight

Po przejściu przez procedurę [[../../../../_system/DERIVATIVE_INSIGHT_RULES|Derived Insight Rules]]:

- Ogólne wzorce organizacyjne (bez identyfikacji BMW)
- Statystyki uogólnione (bez konkretnych wartości)
- Wnioski architektoniczne jako neutralne hipotezy

---

## Zasady użycia LLM dla tych materiałów

| Narzędzie | Status | Warunek |
|-----------|--------|---------|
| Claude Code (lokalny) | ALLOWED | tylko materiały BMW + shared-concept |
| Claude API | ALLOWED | no-training; tylko materiały BMW + shared-concept |
| ChatGPT Enterprise | ALLOWED | no-training; tylko materiały BMW + shared-concept |
| ChatGPT Free/Plus | PROHIBITED | dane mogą trafić do treningu |
| NotebookLM | RESTRICTED | nie umieszczaj materiałów `restricted` |
| GitHub Copilot | RESTRICTED | sprawdź konfigurację org |

---

## Zasada pochodnych wniosków dla BMW

> [!important] Zasada kluczowa
> Wnioski z analizy materiałów BMW MUST NOT być kopiowane do:
> - `20-projects/internal/cloud-support-as-a-service/` jako własne pomysły,
> - `60-toolkit/` ani `30-research/ai4devops/` jako własne hipotezy,
> - `_chatgpt/context-packs/` w mieszanym kontekście.
>
> Jedyna dopuszczalna ścieżka: anonimizacja + generalizacja + jawne oznaczenie `derived insight` zgodnie z [[../../../../_system/DERIVATIVE_INSIGHT_RULES|Derived Insight Rules]].

---

## Incydenty granicy danych

*Jeśli dane BMW trafiły przypadkowo poza tę przestrzeń — odnotuj tutaj:*

| Data | Co się stało | Akcja naprawcza |
|------|-------------|-----------------|
| — | — | — |
