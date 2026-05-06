---
title: Cloud Practice — Roadmap 30-60-90
tags:
  - cloud-practice
  - roadmap
  - decision
updated: 2026-05-06
---

# Cloud Practice — Roadmap 30-60-90

#cloud-practice #decision

> Żywy dokument. Aktualizuj co miesiąc lub przy zmianie priorytetu.
> Nie checklista — mapa kierunku z deliverables.

---

## Faza 1 — 0–30 dni: Foundation & Ownership

**Cel:** Wejść w rolę. Zrozumieć stan zanim cokolwiek zbudujesz.

**ETA:** do 2026-06-05

> [!abstract] Zasada tej fazy
> Mierz, mapuj, ustalaj — nie buduj. Quick wins są ok, ale nie kosztem rozumienia stanu.

### Priorytety

- [ ] Uzyskać dostęp do AWS Partner Central — weryfikacja tier, programy, MDF
- [ ] Zidentyfikować PAM / PDM — ustalić rytm rozmów (co-miesięczny minimum)
- [ ] Review aktualnego statusu certyfikacji w firmie — kto ma co, co wygasa
- [ ] Zmapować istniejące inicjatywy cloudowe: LLZ, FinOps, toolkit, tagging, monitoring
- [ ] Formal sign-off zakresu roli z zarządem — co jest moje, co nie
- [ ] Zbudować backlog inicjatyw (rough list, bez estymowania)
- [ ] Zidentyfikować jedno quick win do pokazania w ciągu 30 dni
- [ ] Pierwsze rozmowy z presales: jak wygląda dziś wsparcie techniczne sprzedaży?
- [ ] Zidentyfikować aktualnie aktywne projekty AWS i ich health

### Deliverables fazy 1

| Deliverable | Status | Link |
|-------------|--------|------|
| Cloud Practice Dashboard | ✅ | [[dashboard]] |
| AWS Partnership Status | ⬜ | [[partnership/status]] |
| Competency Roadmap v1 | ⬜ | [[competency/tracker]] |
| Ownership Map | ⬜ | [[ownership]] |
| Lista inicjatyw (backlog) | ⬜ | [[opportunities/tracker]] |
| Scope cloud practice (signed) | ⬜ | [[ownership]] |

### Wskaźniki sukcesu fazy 1

- Mam dostęp do Partner Central i wiem jaki jest nasz tier
- Wiem jakie competency możemy realistycznie targetować i kiedy
- Zarząd i ja mamy wspólne rozumienie zakresu roli
- Mam backlog inicjatyw z grubą priorytetyzacją

---

## Faza 2 — 30–60 dni: Standards & Competency

**Cel:** Zbudować spójny operating model dla cloud delivery i zebrać evidence.

**ETA:** do 2026-07-05

> [!abstract] Zasada tej fazy
> Standards i evidence idą razem. Każdy standard który tworzysz to potencjalny dowód na competency.

### Priorytety

- [ ] Sformalizować standardy IaC (na bazie istniejącego [[30-standards/iac-standard]])
- [ ] Zbudować governance baseline — kto approveuje co, jak
- [ ] FinOps baseline — regularne review, zidentyfikować oszczędności
- [ ] Well-Architected baseline — zidentyfikować luki w aktywnych projektach
- [ ] Competency evidence collection — zebrać artefakty z istniejących projektów
- [ ] Integracja toolkit jako evidence engine — generowanie raportów compliance/tagging
- [ ] Reusable patterns v1: ECS microservice, monitoring baseline, CI/CD baseline
- [ ] Pierwsze architecture reviews w aktywnych projektach AWS
- [ ] AWS Opportunity Workflow — jak technicznie wspieramy presales?
- [ ] Rozbudowa LLZ: [[20-projects/internal/llz/progress-tracker]]

### Deliverables fazy 2

| Deliverable | Status | Link |
|-------------|--------|------|
| AWS Standards v1 | ⬜ | — |
| LLZ roadmap (updated) | ⬜ | [[20-projects/internal/llz/context\|LLZ]] |
| FinOps baseline | ⬜ | [[70-finops/optimization-log\|FinOps]] |
| Governance baseline | ⬜ | — |
| Competency Evidence Tracker | ⬜ | [[competency/tracker]] |
| Reusable Architecture Patterns v1 | ⬜ | [[50-patterns/]] |
| Cloud Review Process | ⬜ | — |
| AWS Opportunity Workflow | ⬜ | [[opportunities/tracker]] |

### Wskaźniki sukcesu fazy 2

- Mamy ≥3 projektów z udokumentowanym evidence dla co najmniej 1 competency
- Toolkit generuje raporty które można użyć jako evidence
- Przynajmniej 1 Well-Architected Review przeprowadzony i udokumentowany
- Standards są używane w nowych projektach, nie tylko dokumentowane

---

## Faza 3 — 60–90 dni: Scaling & Organizational Integration

**Cel:** Przekształcić inicjatywę w realny organizational capability.

**ETA:** do 2026-08-05

> [!abstract] Zasada tej fazy
> Repeatability > heroism. Procesy które działają bez ciebie.

### Priorytety

- [ ] Formalizacja cloud operating model
- [ ] Cloud review jako część lifecycle projektów (nie opcjonalny add-on)
- [ ] Competency submission readiness — czy mamy wystarczające evidence?
- [ ] Rozszerzenie współpracy: delivery teams, presales, governance
- [ ] Reusable offerings v1 — co możemy reużywać sprzedażowo/delivery
- [ ] Standaryzacja onboarding nowych projektów AWS
- [ ] Cloud Capability Map — co potrafimy, co możemy zaoferować
- [ ] Vendor Partnership Strategy — roadmap AWS Partnership na 12 miesięcy
- [ ] Identyfikacja kolejnych competency do targetowania
- [ ] Ostrożny skan multi-cloud (nie priorytet, nie chaos)

### Deliverables fazy 3

| Deliverable | Status | Link |
|-------------|--------|------|
| Cloud Operating Model | ⬜ | — |
| Competency Submission Readiness Report | ⬜ | [[competency/tracker]] |
| Reusable Cloud Offerings | ⬜ | — |
| Cloud Architecture Review Board (process) | ⬜ | — |
| AWS Technical Standards v2 | ⬜ | — |
| Vendor Partnership Strategy | ⬜ | [[partnership/status]] |
| Cloud Capability Map | ⬜ | — |
| Cloud Delivery Playbook | ⬜ | — |

### Wskaźniki sukcesu fazy 3

- Competency submission złożona lub konkretna data złożenia w kalendarzu
- Cloud review odbywa się w ≥50% nowych projektów AWS
- Mamy ≥2 reusable patterns aktywnie używanych w delivery
- Zarząd ma visibility na postęp przez regularne update (nie ad-hoc)

---

## Decyzje do podjęcia (backlog strategiczny)

> Pytania bez odpowiedzi — wymagają danych lub rozmów przed decyzją.

- **Którą competency targetujemy jako pierwszą?** → zależy od review fazy 1
- **Jaki jest realny timeline certyfikacji?** → zależy od luki między stanem a wymaganiami
- **Multi-cloud: kiedy i czy?** → po stabilizacji AWS jako primary
- **Jak wygląda model wsparcia presales?** → zależy od rozmów z zarządem i sprzedażą
- **LLZ: internal product vs. reusable offering?** → decyzja strategiczna z zarządem

---

## Poza 90 dni — kierunki

*Nie roadmapa — kierunki do myślenia strategicznego. Uzupełnij po fazie 3.*

- Kolejna competency AWS
- AWS Public Sector (jeśli relewantne)
- Well-Architected Partner Program formalizacja
- Cloud Center of Excellence model
- Multi-cloud strategy (GCP/Azure alignment)
- Partner-led opportunities (deal registration, MDF)
