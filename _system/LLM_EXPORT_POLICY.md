---
title: Polityka eksportu wiedzy do LLM
domain: shared-concept
origin: own
classification: internal
llm_exposure: allowed
cross_domain_export: allowed
source_of_truth: vault
created: 2026-04-24
updated: 2026-04-24
---

# Polityka eksportu wiedzy do LLM

> Reguluje wynoszenie treści z vault do narzędzi LLM i innych kanałów egress.
> Ten dokument dotyczy zarówno promptów ad hoc, jak i paczek kontekstowych, uploadów i source packów.

Powiązane: [[PROMPT_BOUNDARY_CHECKLIST]] | [[LLM_CONTEXT_BOUNDARY_CONTRACT]] | [[CLASSIFICATION_MODEL]]

---

## Zakres polityki

Polityka obejmuje wysyłanie treści do:
- ChatGPT,
- Claude,
- NotebookLM,
- modeli lokalnych lub self-hosted.

Eksport oznacza każde przekazanie treści poza vault, w tym:
- wklejenie prompta,
- upload pliku,
- synchronizację context packa,
- indeksowanie źródeł przez notebook albo agenta,
- trwałe zapisanie treści w zewnętrznym systemie LLM.

---

## Zasady nadrzędne

- Treść `restricted` **MUST NOT** być eksportowana do zewnętrznych modeli LLM.
- Treść `confidential` **MUST** przejść minimalizację i anonimizację przed eksportem, chyba że polityka narzędzia i przypadek użycia zostały jawnie zaakceptowane jako bezpieczne.
- Treść `internal` **SHOULD** być ograniczana do minimum niezbędnego dla zadania.
- Treść `public` **MAY** być eksportowana bez dodatkowych kontroli, o ile nie miesza domen wrażliwych.
- Każdy eksport **MUST** respektować [[DOMAIN_ISOLATION_CONTRACT]] i zasadę jednej domeny na sesję.

---

## Profile narzędzi

### ChatGPT

Obejmuje web UI i produkty OpenAI. Warianty z gwarancją no-training **MUST** być odróżniane od wariantów konsumenckich.

### Claude

Obejmuje web UI, API i agentowe użycie Claude. Wariant zewnętrzny **MUST** być traktowany jako egress poza vault.

### NotebookLM

NotebookLM **MUST** być traktowany jako zewnętrzna warstwa syntezy. Upload źródeł jest eksportem danych.

### Local / self-hosted models

Modele lokalne lub self-hosted **MAY** obsługiwać wyższe klasy wrażliwości, ale tylko jeśli:
- runtime jest kontrolowany lokalnie,
- storage i logowanie są pod kontrolą właściciela,
- nie istnieje zewnętrzna retransmisja danych,
- źródła nie opuszczają zaufanego środowiska wykonania.

Brak takiej pewności oznacza, że model **MUST** być traktowany jak zewnętrzny.

---

## Macierz decyzyjna

| Klasyfikacja | ChatGPT | Claude | NotebookLM | Local / self-hosted |
|--------------|---------|--------|------------|---------------------|
| `public` | ALLOWED | ALLOWED | ALLOWED | ALLOWED |
| `internal` | ALLOWED WITH MINIMIZATION | ALLOWED WITH MINIMIZATION | ALLOWED WITH MINIMIZATION | ALLOWED |
| `confidential` | ANONYMIZATION REQUIRED / OTHERWISE PROHIBITED | ANONYMIZATION REQUIRED / OTHERWISE PROHIBITED | ANONYMIZATION REQUIRED / OTHERWISE PROHIBITED | ALLOWED WITH LOCAL CONTROLS |
| `restricted` | PROHIBITED | PROHIBITED | PROHIBITED | ALLOWED ONLY IF FULLY LOCAL AND NO EGRESS |

---

## Reguły według klasy wrażliwości

### `public`

- **allowed:** ChatGPT, Claude, NotebookLM, modele lokalne/self-hosted
- **anonymization required:** nie
- **prohibited:** nie, o ile treść rzeczywiście nie zawiera ukrytych danych wewnętrznych

### `internal`

- **allowed:** ChatGPT, Claude, NotebookLM, modele lokalne/self-hosted
- **anonymization required:** zalecana minimalizacja; pełna anonimizacja nie jest zawsze wymagana
- **prohibited:** eksport całych folderów, dumpów vault i mieszanych paczek domenowych

Wymóg:
- eksport `internal` **MUST** ograniczać się do treści potrzebnej do wykonania zadania,
- treść `internal` **SHOULD NOT** zawierać roadmap, sekretów ani identyfikatorów środowisk, jeśli nie są niezbędne.

### `confidential`

- **allowed:** tylko po anonimizacji i minimalizacji; preferowane kanały o niskim ryzyku i jawnej kontroli użycia
- **anonymization required:** tak, obowiązkowo dla zewnętrznych modeli
- **prohibited:** wysyłanie surowych materiałów klientowskich, surowych logów, niezanonimizowanych notatek ze spotkań, strategii cenowej i danych finansowych

Wymóg:
- eksport `confidential` **MUST** usuwać dane identyfikujące klienta, systemy, osoby, liczby i artefakty środowiskowe,
- jeśli pełna anonimizacja nie jest możliwa, eksport **MUST NOT** nastąpić do modelu zewnętrznego.

### `restricted`

- **allowed:** wyłącznie model lokalny lub self-hosted bez egress, pod pełną kontrolą właściciela
- **anonymization required:** nie wystarcza do automatycznego dopuszczenia eksportu zewnętrznego
- **prohibited:** ChatGPT, Claude, NotebookLM i każdy inny zewnętrzny model

Wymóg:
- jeśli treść zawiera credentiale, sekrety, dane osobowe, surowe dane produkcyjne albo materiały NDA, eksport zewnętrzny **MUST NOT** nastąpić w żadnej formie.

---

## Minimalny test przed eksportem

Przed każdym eksportem wykonaj trzy pytania kontrolne:

1. Czy materiał zawiera więcej informacji niż jest potrzebne do zadania?
2. Czy odbiorca LLM musi znać tożsamość klienta, systemu lub środowiska?
3. Czy ten sam efekt można osiągnąć przez `shared-concept`, anonimizację albo model lokalny?

Jeśli odpowiedź na pytanie 2 brzmi `nie`, dane identyfikujące **MUST** zostać usunięte.

---

## Wymagania dokumentacyjne

Jeśli eksport dotyczy `confidential` albo `restricted`, operator **SHOULD** zapisać:
- jakie narzędzie zostało użyte,
- jaką klasę miały dane wejściowe,
- jaki zakres anonimizacji wykonano,
- gdzie zapisano wynik,
- czy wynik wymagał dalszego oczyszczenia przed zapisaniem do vault.

W przypadku wątpliwości obowiązuje decyzja bezpieczniejsza: nie eksportować.
