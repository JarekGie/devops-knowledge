---
title: Model granic wiedzy — przegląd
domain: shared-concept
origin: own
classification: internal
llm_exposure: allowed
cross_domain_export: allowed
source_of_truth: vault
created: 2026-04-24
updated: 2026-04-24
---

# Model granic wiedzy vault

> Dokument przeglądowy. Szczegółowe definicje w dokumentach powiązanych.
> Czytaj ten plik zanim załadujesz jakikolwiek materiał do LLM.

Powiązane: [[CLASSIFICATION_MODEL]] | [[DOMAIN_ISOLATION_CONTRACT]] | [[LLM_CONTEXT_BOUNDARY_CONTRACT]] | [[PROMPT_BOUNDARY_CHECKLIST]] | [[BOUNDARY_EXCEPTION_PROCESS]] | [[LLM_EXPORT_POLICY]]

---

## Dlaczego granice wiedzy są konieczne

Ten vault zawiera materiały z co najmniej czterech nieprzekładalnych kontekstów:

| Kontekst | Przykład | Ryzyko mieszania |
|----------|---------|-----------------|
| Praca klientowska BMW | materiały AI Taskforce | wyciek do toolkit / strategii MakoLab |
| Strategia MakoLab | Cloud Support as a Service roadmapa | wpływ na analizę neutralną / klientowską |
| Prywatne R&D | devops-toolkit, cloud-detective | pomylenie hipotez własnych z wiedzą klientowską |
| Neutralna wiedza | wzorce AIOps, ITSM, architektura | jedyna domena, która może być swobodnie cytowana |

Mieszanie tych kontekstów — nawet nieintencjonalne — prowadzi do:
- naruszenia poufności danych klienta,
- „zanieczyszczenia" strategii produktowej cudzymi pomysłami bez jawnego źródłowania,
- halucynacji LLM opartych na połączonych kontekstach,
- braku rozliczalności skąd pochodzi dany wniosek.

---

## Mapa domen

```
┌─────────────────────────────────────────────────┐
│  VAULT                                          │
│                                                 │
│  ┌──────────────┐   ┌──────────────────────┐   │
│  │ client-work  │   │ internal-product-    │   │
│  │              │   │ strategy             │   │
│  │ BMW AI       │   │ Cloud Support as     │   │
│  │ Taskforce    │   │ a Service            │   │
│  │              │   │                      │   │
│  │ confidential │   │ internal/confidential│   │
│  └──────┬───────┘   └──────────┬───────────┘   │
│         │  PROHIBITED          │ summary-only   │
│         │         ┌────────────┘               │
│         │         ▼                            │
│  ┌──────▼──────────────────┐                  │
│  │     shared-concept      │◄─────────────────┐│
│  │ 30-research/ai4devops/  │                  ││
│  │ wzorce, ITSM, AIOps     │                  ││
│  │ public / internal       │                  ││
│  └──────────────┬──────────┘                  ││
│                 │ allowed                      ││
│                 ▼                              ││
│  ┌──────────────────────┐                     ││
│  │    private-rnd       │─────────────────────┘│
│  │ devops-toolkit       │ allowed (read)        │
│  │ cloud-detective      │                       │
│  │ restricted           │                       │
│  └──────────────────────┘                       │
│                                                 │
│  wyjątek graniczny:                              │
│  client-work -> generalized insight ->          │
│  shared-concept only                             │
└─────────────────────────────────────────────────┘
```

### Legenda przepływu danych

| Strzałka | Znaczenie |
|----------|-----------|
| `PROHIBITED` | Dane nie mogą przepływać w żadnym kierunku |
| `summary-only` | Tylko zanonimizowane, uogólnione wnioski z jawnym oznaczeniem |
| `allowed (read)` | Możliwy dostęp do wzorców, bez importowania treści |
| `allowed` | Swobodna cytacja i linkowanie |

---

## Szybka reguła decyzyjna

Przed użyciem notatki w sesji LLM zadaj pytanie:

```
1. Z jakiej domeny pochodzi notatka?
2. Z jakiej domeny pochodzi moje pytanie do LLM?
3. Czy te domeny mogą się spotkać?
   - shared-concept + cokolwiek → TAK
   - client-work + client-work (ten sam klient) → TAK
   - client-work + cokolwiek innego → NIE
   - internal-product-strategy + shared-concept → TAK (z ostrożnością)
   - internal-product-strategy + client-work → NIE
   - private-rnd + shared-concept → TAK
   - private-rnd + client-work → NIE
   - private-rnd + internal-product-strategy → NIE (chyba że jawnie derived)
```

---

## Dokumenty governance systemu

| Dokument | Zakres |
|----------|--------|
| [[CLASSIFICATION_MODEL]] | Definicje klas domen, wrażliwości i reguł dziedziczenia |
| [[DOMAIN_ISOLATION_CONTRACT]] | Kontrakty izolacji z MUST/MUST NOT |
| [[BOUNDARY_EXCEPTION_PROCESS]] | Kontrolowany proces wyjątków granicznych |
| [[LLM_CONTEXT_BOUNDARY_CONTRACT]] | Zasady sesji LLM |
| [[ORIGIN_METADATA_CONTRACT]] | Obowiązkowy frontmatter notatek |
| [[DERIVATIVE_INSIGHT_RULES]] | Zasady pochodnych wniosków między domenami |
| [[LLM_EXPORT_POLICY]] | Polityka egress i eksportu treści do narzędzi LLM |
| [[PROMPT_BOUNDARY_CHECKLIST]] | Checklista przed wysłaniem prompta |
| [[BOUNDARY_REVIEW_REPORT]] | Raport audytowy stanu vault |
