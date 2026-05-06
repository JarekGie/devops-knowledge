---
title: Cloud Practice — Ownership & Scope
tags:
  - cloud-practice
  - governance
  - decision
updated: 2026-05-06
---

# Cloud Practice — Ownership & Scope

#cloud-practice #governance #decision

> Definicja zakresu roli, granic odpowiedzialności i modelu współpracy.
> Dokument do sign-off z zarządem w fazie 0–30 dni.

---

## Rola

**Tytuł roboczy:** AWS / Cloud Technical Leader
**Ewolucja z:** Senior DevOps / SRE Engineer

> [!warning] Do uzgodnienia z zarządem
> Formalny tytuł, OKRy i zakres — do ustalenia do końca fazy 0-30. Ten dokument jest draftem.

---

## Co jest MOJE (ownership)

| Obszar | Opis |
|--------|------|
| AWS Partnership | Status, programy, relacja z PAM/PDM, MDF |
| Competency | Roadmap, evidence collection, submission readiness |
| Cloud Standards | IaC, tagging, naming, governance baseline |
| Architecture Review | Well-Architected reviews, cloud architecture decisions |
| LLZ | Platform standard dla MakoLab — [[20-projects/internal/llz/context\|LLZ context]] |
| FinOps | Przeglądy kosztów, optymalizacja, savings tracking |
| Reusable Patterns | ECS, monitoring, CI/CD, account baseline |
| Toolkit | [[60-toolkit/architecture-overview\|devops-toolkit]] jako evidence engine |
| Technical Opportunities | Identyfikacja i wsparcie techniczne szans sprzedażowych |
| Cloud Practice Dashboard | Ten vault, ten system |

---

## Co WSPIERÁM (support, nie ownership)

| Obszar | Kto owneuje | Moja rola |
|--------|-------------|-----------|
| Delivery projektów klientów | PM / Tech Lead projektu | Architecture review, cloud advisory |
| Presales | Account Manager / Sales | Technical scoping, estimation, Solution Design |
| Bezpieczeństwo | CISO / Security | Cloud security controls, compliance input |
| HR / Hiring | HR | Profil techniczny kandydatów cloud |
| Budżet | CFO / Zarząd | FinOps insights, rekomendacje |

---

## Co NIE JEST MOJE

> [!danger] Poza scopem
> - Day-to-day operations projektów klientów (to jest delivery team)
> - Sprzedaż (to jest sales — ja wspieram technicznie, nie prowadzę deals)
> - Decyzje biznesowe o kierunku firmy (to jest zarząd)
> - Help desk / support tier 1-2 (to jest support team)

---

## Mapa stakeholderów

### Zarząd

| Potrzeba | Co dostarczam |
|----------|---------------|
| Visibility na cloud capability | Cloud Capability Map, quarterly review |
| ROI z partnership | Partnership tier benefits, MDF, deal registration |
| Ryzyko cloud | Governance baseline, audit readiness |
| Możliwości rynkowe | Competency jako differentiator, presales support |

**Rytm:** Monthly update (nie ad-hoc). Format: 1 strona, metryki, decyzje do podjęcia.

### AWS (PAM / PDM)

| Potrzeba | Co dostarczam |
|----------|---------------|
| Aktywny partner | Regularne rozmowy, programy, certyfikacje |
| Evidence dla competency | Dokumentacja projektów, case studies |
| Wspólne pipeline | Identyfikacja deal registration, co-sell opportunities |

**Rytm:** Min. co-miesięcznie z PAM. Kwartalny QBR jeśli partnership level na to pozwala.

### Presales / Account Manager

| Potrzeba | Co dostarczam |
|----------|---------------|
| Technical scoping dla ofert | Architecture input, estimation, PoC guidance |
| Differentiators | Competency, LLZ, reusable patterns jako selling points |
| Odpowiedzi na RFP/RFI | Technical sections, compliance, cloud architecture |

**Rytm:** On-demand + co-tygodniowy quick sync (pipeline review).

### Delivery Teams

| Potrzeba | Co dostarczam |
|----------|---------------|
| Cloud standards | IaC templates, LLZ modules, reusable patterns |
| Architecture review | Well-Architected lens, cloud best practices |
| Problemy techniczne | Senior advisory (nie operational support) |

**Rytm:** Architecture review na starcie projektu + checkpoints. Nie daily-ops.

### Governance / Compliance

| Potrzeba | Co dostarczam |
|----------|---------------|
| Cloud compliance | Tagging policy, IAM standards, audit readiness |
| Evidence | Raporty z toolkit, WAR findings |
| Polityki | Cloud governance baseline |

**Rytm:** Quarterly review compliance posture. Input do audytów.

---

## Granice — co robię kiedy

```
Nowy projekt AWS        → Architecture review (TAX) przed startem
Oferta dla klienta      → Technical scoping + review (nie jestem PM)
Problem operacyjny      → Advisory, nie naprawa (delivery team operuje)
Nowy certyfikat w firmie → Tracking, nie wymuszanie (rekomendacja)
Decyzja architektoniczna → Input + recommendation, decyzja u project tech lead
```

---

## Istniejące inicjatywy — stan wejściowy

| Inicjatywa | Status | Link |
|-----------|--------|------|
| LLZ — Light Landing Zone | W toku | [[20-projects/internal/llz/progress-tracker\|LLZ tracker]] |
| FinOps | Aktywne | [[70-finops/optimization-log\|FinOps log]] |
| devops-toolkit | Aktywny development | [[60-toolkit/architecture-overview\|Toolkit arch]] |
| IaC Standards | Zdefiniowane | [[30-standards/iac-standard\|IaC standard]] |
| AWS Tagging | Zdefiniowane | [[30-standards/aws-tagging-standard\|Tagging standard]] |
| AWS Partnership | ❓ status do weryfikacji | [[partnership/status]] |
| Competency | ❓ do zmapowania | [[competency/tracker]] |

---

## Historia decyzji

| Data | Decyzja | Kontekst |
|------|---------|---------|
| 2026-05-06 | Utworzenie cloud practice space w vault | Ewolucja roli → AWS Technical Leader |
| ❓ | Sign-off zakresu roli z zarządem | Do uzyskania w fazie 0-30 |
