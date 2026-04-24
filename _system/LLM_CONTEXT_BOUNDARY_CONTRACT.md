---
title: Kontrakt granic kontekstu LLM
domain: shared-concept
origin: own
classification: internal
llm_exposure: allowed
cross_domain_export: allowed
source_of_truth: vault
created: 2026-04-24
updated: 2026-04-24
---

# Kontrakt granic kontekstu LLM

> Zasady dla każdej sesji z zewnętrznym modelem językowym:
> Claude, ChatGPT, Codex, NotebookLM, Gemini i każdy inny.

Powiązane: [[DOMAIN_ISOLATION_CONTRACT]] | [[PROMPT_BOUNDARY_CHECKLIST]] | [[KNOWLEDGE_BOUNDARIES]]

---

## Zasada nadrzędna

> **Jedna sesja LLM = jedna domena wrażliwości.**

Nie łącz `client-work` + `internal-product-strategy` + `private-rnd` w jednym prompcie.

Jeśli potrzebne jest porównanie między domenami, użyj wyłącznie neutralnego `shared-concept` albo przygotuj zanonimizowane summary z jawnym oznaczeniem jako derived insight.

---

## Zasady sesji według domeny

### Sesja dotycząca `client-work`

**MUST** zawierać wyłącznie materiały danego klienta + `shared-concept`.

**MUST NOT** zawierać materiałów innego klienta, `internal-product-strategy` ani `private-rnd`.

**MUST** mieć ustawione `classification: confidential` minimum na wszystkich materiałach wejściowych.

**SHOULD** używać modeli z polityką no-training (np. Claude API, ChatGPT Teams/Enterprise) dla materiałów `confidential`.

**MUST NOT** wynik sesji dotyczącej `client-work` być bezpośrednio kopiowany do notatek `internal-product-strategy` ani `private-rnd`.

---

### Sesja dotycząca `internal-product-strategy`

**MUST** zawierać wyłącznie materiały MakoLab + `shared-concept`.

**MUST NOT** zawierać materiałów klientowskich nawet w formie „przykładu" lub „analogii".

**MAY** przywoływać `private-rnd` jako cytację techniczną, ale nie jako `source_of_truth`.

**SHOULD** wyniki zapisywać w `20-projects/internal/<projekt>/` a nie w `_chatgpt/context-packs/`.

---

### Sesja dotycząca `private-rnd`

**MUST** zawierać wyłącznie własne notatki + `shared-concept`.

**MUST NOT** zawierać materiałów klientowskich ani strategii MakoLab.

**SHOULD** mieć `llm_exposure: restricted` gdy notatka zawiera niedojrzałe hipotezy lub wrażliwe dane techniczne.

---

### Sesja dotycząca `shared-concept`

**MAY** zawierać materiały ze wszystkich domen w formie neutralnych wzorców.

**MUST NOT** zawierać żadnych danych identyfikujących klientów ani konkretnych systemów produkcyjnych.

---

## Klasyfikacja narzędzi LLM według ryzyka

| Narzędzie | Typ | Dopuszczalna klasyfikacja | Uwagi |
|-----------|-----|--------------------------|-------|
| Claude Code (lokalny) | agent | internal / confidential | przetwarza lokalnie, wynik nie opuszcza maszyny |
| Claude API (Anthropic) | API | internal / confidential | polityka no-training na API |
| ChatGPT (Free/Plus) | web UI | public / internal | dane mogą trafić do treningu |
| ChatGPT Teams/Enterprise | web UI | internal / confidential | polityka no-training |
| GitHub Copilot | IDE | internal | w zależności od konfiguracji org |
| NotebookLM | web UI | internal / confidential | Google; nie przekazuj `restricted` |
| Codex (GitHub) | agent | internal | nie przekazuj credentiali ani konfigu klienta |
| Gemini | web UI | public / internal | ostrożność z confidential |

---

## Zasady przygotowania paczki kontekstowej

**MUST** paczka kontekstowa dla LLM zawierać wyłącznie notatki z jednej domeny + `shared-concept`.

**MUST NOT** paczka zawierać surowych danych (credentiali, connection stringów, IP, ARNów produkcyjnych).

**SHOULD** paczka mieć nagłówek identyfikujący domenę i właściciela.

**SHOULD** paczka zawierać nie więcej niż 8–12 dokumentów (patrz [[../NOTEBOOKLM_CONTRACT]]).

---

## Zasady wyjścia z sesji LLM

**MUST** każdy wynik sesji LLM dotyczący `client-work` być zapisany w przestrzeni klienta, nie globalnie.

**MUST** każdy wynik sesji LLM dotyczący `internal-product-strategy` być zapisany w `20-projects/internal/`.

**MUST NOT** wynik sesji LLM być traktowany jako `source_of_truth` — vault zawsze jest nadrzędny.

**SHOULD** wyniki zawierające derived insights z `client-work` być jawnie oznaczone przed zapisem do innej domeny.

---

## Obsługa naruszenia granicy

Gdy zauważysz, że sesja LLM przekroczyła granicę domenową:

1. Przerwij sesję.
2. Nie zapisuj wyjścia do vault bez pełnego przeglądu.
3. Oceń, czy wyjście zawiera dane z niedozwolonej domeny.
4. Jeśli tak — usuń naruszające fragmenty przed zapisem.
5. Dodaj notatkę do `01-inbox/` z opisem incydentu granic.
6. Zaktualizuj [[BOUNDARY_REVIEW_REPORT]] jeśli incydent wskazuje na systemowy problem.
