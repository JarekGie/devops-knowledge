---
title: Cloud Opportunities — Tracker
tags:
  - cloud-practice
  - opportunity
updated: 2026-05-06
---

# Cloud Opportunities — Tracker

#cloud-practice #opportunity

> Technical opportunities, presales requests, architecture advisory.
> Nie pipeline sprzedażowy — to jest log technicznych zaangażowań.

---

## Aktywne oportunities

| Klient / Projekt | Typ | Status | Owner (sales) | Moja rola | Deadline |
|-----------------|-----|--------|--------------|-----------|---------|
| — | — | — | — | — | — |

**Typy:**
- `presales` — wsparcie techniczne przed podpisaniem kontraktu
- `advisory` — konsultacja architektoniczna dla istniejącego klienta
- `rfp` — odpowiedź na zapytanie ofertowe
- `poc` — proof of concept
- `migration` — migracja do AWS
- `review` — Well-Architected Review

---

## Workflow technicznego wsparcia presales

> [!tip] Jak to działa
>
> ```
> Sales zgłasza opportunity
>       ↓
> Tech scoping (moja rola): 1-2h rozmowa z klientem / review RFP
>       ↓
> Output: Architecture sketch + effort estimate + differentiators
>       ↓
> Review z sales → idzie do oferty
>       ↓
> Po wygraniu → handoff do delivery (architecture decision doc)
> ```

**SLA dla presales requests:**
- Proste scope / feasibility: odpowiedź w 24h
- Architecture sketch: 2-3 dni robocze
- Pełna solution design: ustalane indywidualnie (zależy od złożoności)

---

## Differentiatory do użycia w presales

> Czym się wyróżniamy — gotowe punkty do użycia w ofertach i rozmowach.

| Differentiator | Opis | Artefakt |
|---------------|------|---------|
| LLZ — Light Landing Zone | Gotowy, powtarzalny baseline AWS account | [[20-projects/internal/llz/context\|LLZ]] |
| IaC standardy | Terraform standardy zdefiniowane i używane | [[30-standards/iac-standard\|IaC Standard]] |
| FinOps capability | Regularne przeglądy kosztów, toolkit do audytów | [[70-finobs/optimization-log\|FinOps]] |
| devops-toolkit | CLI do audytów IaC / tagging / compliance | [[60-toolkit/architecture-overview\|Toolkit]] |
| AWS Partnership | ❓ (tier do weryfikacji) | [[partnership/status]] |
| AWS Competency | ❓ (do uzyskania) | [[competency/tracker]] |
| Well-Architected | Capability do WAR review u klientów | — |

---

## Backlog inicjatyw — do priorytetyzacji

> Pomysły i inicjatywy cloudowe bez właściciela lub bez decyzji o starcie.
> Nie todo-lista — backlog do regularnego przeglądu.

| Inicjatywa | Typ | Wartość | Wysiłek | Priorytet |
|-----------|-----|---------|---------|----------|
| LLZ — rozszerzenie o FinOps guardrails | internal | wysoka | średni | 🔴 |
| Reusable ECS pattern (microservice template) | pattern | wysoka | średni | 🔴 |
| Well-Architected Review offering dla klientów | offering | wysoka | niski | 🟡 |
| Monitoring baseline (CloudWatch standard stack) | pattern | średnia | średni | 🟡 |
| AWS account onboarding playbook | process | średnia | niski | 🟡 |
| Multi-account governance (Control Tower?) | governance | wysoka | wysoki | 🟠 |
| CI/CD standard pipeline template | pattern | średnia | średni | 🟠 |
| ❓ inne do dodania po fazie 0-30 | — | — | — | — |

---

## Zamknięte oportunities (archiwum)

| Klient | Typ | Wynik | Data | Lekcje |
|--------|-----|-------|------|--------|
| — | — | — | — | — |
