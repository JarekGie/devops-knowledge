---
title: Checklista granicy prompta — przed wysłaniem do LLM
domain: shared-concept
origin: own
classification: internal
llm_exposure: allowed
cross_domain_export: allowed
source_of_truth: vault
created: 2026-04-24
updated: 2026-04-24
---

# Checklista granicy prompta

> Wypełnij przed wysłaniem prompta do: ChatGPT, Claude, NotebookLM, Codex, Gemini lub innego LLM.
> Jeśli którekolwiek pytanie wskazuje na problem — zatrzymaj się i rozwiąż go przed wysłaniem.

Powiązane: [[LLM_CONTEXT_BOUNDARY_CONTRACT]] | [[DOMAIN_ISOLATION_CONTRACT]] | [[DERIVATIVE_INSIGHT_RULES]] | [[LLM_EXPORT_POLICY]]

---

## Checklista (wypełnij mentalnie lub na papierze)

### Blok 1 — Zawartość prompta

- [ ] **Czy prompt zawiera dane identyfikujące klienta?**
  Nazwy firm, systemów klienta, imion i nazwisk, ARNów z konta klienta.
  → Jeśli TAK: użyj tylko w przestrzeni klienta lub zanonimizuj przed wysłaniem.

- [ ] **Czy prompt zawiera credentiale, klucze, sekrety?**
  Hasła, tokeny, connection stringi, API keys, SSH keys.
  → Jeśli TAK: STOP. Usuń. MUST NOT trafiać do żadnego zewnętrznego LLM.

- [ ] **Czy prompt zawiera dane produkcyjne klienta?**
  Logi, metryki, konfiguracje systemów klienta.
  → Jeśli TAK: zanonimizuj albo użyj lokalnego modelu.

- [ ] **Czy prompt zawiera prywatne R&D?**
  Nieopublikowane hipotezy, architekturę toolkit/cloud-detective, niezamknięte decyzje.
  → Jeśli TAK: użyj `llm_exposure: restricted` i skurowanej paczki.

- [ ] **Czy prompt zawiera strategię produktową MakoLab?**
  Roadmapy, ceny usług, plany biznesowe, dane finansowe.
  → Jeśli TAK: użyj tylko narzędzi z polityką no-training (Claude API, ChatGPT Enterprise).

---

### Blok 2 — Mieszanie domen

- [ ] **Czy mieszam więcej niż jedną domenę wrażliwości?**
  Sprawdź: czy w prompcie są materiały `client-work` + `private-rnd` razem?
  Czy są materiały różnych klientów razem?
  → Jeśli TAK: rozdziel na oddzielne sesje.

- [ ] **Czy mogę użyć neutralnego `shared-concept` zamiast źródłowych danych?**
  Wzorce z `30-research/ai4devops/` zamiast konkretnych przypadków klientowskich.
  Ogólne runbooki z `40-runbooks/` zamiast konfiguratcji klienta.
  → Jeśli TAK: użyj neutralnych wzorców.

- [ ] **Czy mój prompt przypadkowo sugeruje powiązanie klienta z hipotezą produktową?**
  Np. „klient X ma problem Y, dlatego nasz produkt powinien Z".
  → Jeśli TAK: rozdziel na dwie osobne sesje.

---

### Blok 3 — Narzędzie LLM

- [ ] **Czy używam właściwego narzędzia dla tej klasy wrażliwości?**

  | Klasyfikacja | Bezpieczne narzędzia |
  |-------------|---------------------|
  | `public` | dowolne |
  | `internal` | Claude API, ChatGPT Teams/Enterprise, lokalny model |
  | `confidential` | Claude API, ChatGPT Enterprise — sprawdź politykę no-training |
  | `restricted` | PROHIBITED dla zewnętrznych LLM; lokalny model lub brak LLM |

- [ ] **Czy narzędzie które wybieram ma politykę no-training dla moich danych?**
  ChatGPT Free/Plus → dane mogą trafić do treningu (nie dla confidential).
  ChatGPT Enterprise → no-training (ok dla confidential).
  Claude API → no-training (ok dla confidential).
  NotebookLM → Google; nie wysyłaj `restricted`.

- [ ] **Czy ten eksport jest zgodny z [[LLM_EXPORT_POLICY]]?**
  Sprawdź: klasyfikacja materiału, typ narzędzia i czy wymagane jest anonimizowanie.
  → Jeśli NIE: zatrzymaj eksport.

- [ ] **Czy przygotowałem minimalny zakres danych do egress?**
  Nie wysyłaj całych notatek, jeśli wystarczy fragment albo wzorzec `shared-concept`.
  → Jeśli NIE: przytnij input.

- [ ] **Czy próbuję obniżyć klasyfikację tylko po to, żeby użyć zewnętrznego LLM?**
  → Jeśli TAK: STOP. To wymaga [[BOUNDARY_EXCEPTION_PROCESS]], a nie cichego override.

---

### Blok 4 — Output i zapis

- [ ] **Czy output z tej sesji może bezpiecznie trafić do innej domeny?**
  Jeśli sesja dotyczyła `client-work` → wynik MUST zostać w przestrzeni klienta lub przejść przez [[DERIVATIVE_INSIGHT_RULES]].
  Jeśli sesja dotyczyła `private-rnd` → wynik SHOULD zostać w `60-toolkit/` lub `30-research/`.

- [ ] **Czy wiem, gdzie w vault zapisać wynik tej sesji?**
  → Jeśli nie wiesz: zapisz w `01-inbox/` z datą i tematem.

- [ ] **Czy wynik zawiera fakty wymagające weryfikacji przed zapisem do vault?**
  LLM może halucynować. Weryfikuj ARNy, liczby, ścieżki plików przed zapisem.

---

## Szybki decision tree

```
START: Czy prompt zawiera restricted (klucze, credentiale)?
  TAK → STOP. Usuń. Nie wysyłaj.
  NIE → Czy prompt zawiera client-work?
    TAK → Czy używasz no-training LLM?
      NIE → STOP. Zmień narzędzie lub zanonimizuj.
      TAK → Czy prompt zawiera TYLKO dane tego klienta + shared-concept?
        NIE → STOP. Rozdziel sesje.
        TAK → OK. Wynik zapisz w przestrzeni klienta.
    NIE → Czy prompt miesza internal-product-strategy + private-rnd?
      TAK → Rozdziel sesje lub użyj tylko shared-concept.
      NIE → OK. Wynik zapisz w odpowiedniej domenie.
```

---

## Kiedy NIE potrzebujesz tej checklisty

- Sesja wyłącznie na `shared-concept` (wzorce, runbooki ogólne, dokumentacja techniczna).
- Sesja wyłącznie z własnym kodem w lokalnym repozytorium bez danych klienta.
- Szybkie pytanie techniczne bez kontekstu projektowego.
