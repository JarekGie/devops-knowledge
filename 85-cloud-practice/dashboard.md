---
title: Cloud Practice — Dashboard
tags:
  - cloud-practice
  - dashboard
aliases:
  - cloud-dashboard
  - cloud-practice-dashboard
updated: 2026-05-06
---

# Cloud Practice — Dashboard

#cloud-practice

> Punkt wejścia. Aktualizuj co tydzień. Cała nawigacja zaczyna się tutaj.

---

## Aktualny fokus

> [!info] Tydzień 1 — Faza 0–30 dni
> **Priorytet:** Foundation & Ownership — zmapowanie status quo przed działaniem
>
> Nie buduj niczego nowego, dopóki nie rozumiesz co już istnieje.

```
Faza aktywna:    0–30 dni — Foundation & Ownership
Obecny tydzień:  1 / 4
Główny cel:      Uzyskanie dostępu + review status quo
Następny review: 2026-05-13
```

---

## Status roadmapy

| Faza | Status | ETA |
|------|--------|-----|
| **0–30 dni** — Foundation & Ownership | 🟡 W toku | 2026-06-05 |
| **30–60 dni** — Standards & Competency | ⬜ Oczekuje | 2026-07-05 |
| **60–90 dni** — Scaling & Integration | ⬜ Oczekuje | 2026-08-05 |

→ Szczegóły: [[roadmap]]

---

## Open loops — faza 0–30 dni

> [!todo] Blokery i krytyczne akcje
> - [ ] Uzyskać dostęp do AWS Partner Central
> - [ ] Zidentyfikować PAM / PDM (Partner Development Manager)
> - [ ] Sprawdzić aktualny tier AWS Partnership (Select / Advanced / Premier)
> - [ ] Zebrać listę certyfikacji AWS w firmie (kto ma co)
> - [ ] Ustalić scope cloud practice z zarządem — formal sign-off
> - [ ] Zmapować istniejące inicjatywy cloudowe (LLZ, FinOps, toolkit, monitoring)
> - [ ] Zidentyfikować jedno quick win do pokazania w ciągu 30 dni

---

## Nawigacja — strategiczne

| Dokument | Opis |
|----------|------|
| [[roadmap]] | 30-60-90 roadmap + milestones |
| [[ownership]] | Scope, granice odpowiedzialności, stakeholders |
| [[partnership/status]] | AWS Partnership tier, programy, kontakty |
| [[competency/tracker]] | Competency tracking — status, luki, evidence |
| [[opportunities/tracker]] | Tech opportunities, presales requests |

---

## Nawigacja — integracje z vaultem

| Obszar | Link |
|--------|------|
| LLZ | [[20-projects/internal/llz/progress-tracker\|LLZ Progress Tracker]] |
| LLZ context | [[20-projects/internal/llz/context\|LLZ Context]] |
| FinOps | [[70-finops/optimization-log\|FinOps Optimization Log]] |
| FinOps savings | [[70-finops/savings-ideas\|Savings Ideas]] |
| IaC standard | [[30-standards/iac-standard\|IaC Standard]] |
| Tagging | [[30-standards/aws-tagging-standard\|AWS Tagging Standard]] |
| Architecture decisions | [[80-architecture/decision-log\|ADR Log]] |
| Toolkit | [[60-toolkit/architecture-overview\|Toolkit Architecture]] |

---

## AWS Partnership — pulse

| Parametr | Stan | Gdzie |
|----------|------|-------|
| Tier | ❓ do weryfikacji | [[partnership/status]] |
| PAM / PDM | ❓ do ustalenia | [[partnership/status]] |
| MDF dostępny | ❓ | [[partnership/status]] |
| Aktywne programy | ❓ | [[partnership/status]] |
| Competency submission | ❓ | [[competency/tracker]] |

---

## Competency — pulse

| Competency | Status | Evidence gap | ETA |
|-----------|--------|-------------|-----|
| ❓ do zidentyfikowania | — | — | — |

→ [[competency/tracker]] po pełne zestawienie

---

## Opportunities — pulse

| Projekt / Lead | Typ | Status | Owner |
|---------------|-----|--------|-------|
| ❓ | — | — | — |

→ [[opportunities/tracker]] po pełne zestawienie

---

## Rytm pracy

> [!tip]- Expand: rytm dzienny / tygodniowy / miesięczny
>
> **Codziennie (5 min)**
> - Sprawdź open loops → co jest blokowane?
> - Zaktualizuj fokus jeśli zmiana priorytetu
>
> **Tygodniowo (30 min) — każdy poniedziałek**
> - Aktualizuj status tabel (partnership pulse, competency pulse)
> - Przetwórz `01-inbox/` → przypisz do właściwego miejsca
> - Dodaj nowe evidence artefakty do [[competency/tracker]]
> - Sprawdź open opportunities
>
> **Miesięcznie (2h) — pierwszy poniedziałek miesiąca**
> - Review postępu roadmapy → aktualizuj ETA
> - Update [[partnership/status]] po rozmowach z AWS
> - Review [[competency/tracker]] → sprawdź luki vs submission ETA
> - Archiwizuj zamknięte oportunities
> - Zaktualizuj [[ownership]] jeśli zmieniły się granice lub stakeholders
>
> **Faza gate (co 30 dni)**
> - Ocena: które deliverables z fazy zostały zrealizowane?
> - Decyzja: czy startujemy następną fazę czy przedłużamy?
> - Aktualizacja roadmapy i dashboardu

---

## Konwencje nazewnicze

| Typ pliku | Format |
|-----------|--------|
| Notatka z rozmowy AWS | `partnership/notes/YYYY-MM-DD-temat.md` |
| Evidence artefakt | `competency/evidence/YYYY-MM-DD-serwis-projekt.md` |
| Architecture review | `reviews/YYYY-MM-DD-projekt-war.md` (od fazy 2) |
| Decyzja strategiczna | [[80-architecture/decision-log]] |

**Tagi tej przestrzeni:**
`#cloud-practice` `#partnership` `#competency` `#opportunity` `#evidence` `#governance`
