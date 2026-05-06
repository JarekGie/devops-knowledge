---
title: AWS Competency — Tracker
tags:
  - cloud-practice
  - competency
  - evidence
updated: 2026-05-06
last_reviewed: null
---

# AWS Competency — Tracker

#cloud-practice #competency #evidence

> Tracking statusu competency, luk w evidence i timeline submission.
> Aktualizuj co tydzień (evidence) i co miesiąc (status, ETA).

---

## Targetowane Competency

> ⚠️ Do ustalenia po weryfikacji statusu partnerstwa i rozmowie z PAM.
> Poniżej propozycja oparta na istniejącym portfolio — do walidacji.

| Competency | Priorytet | Status | Gap assessment | ETA submission |
|-----------|----------|--------|---------------|---------------|
| **DevOps** | 🔴 Wysoki — core capability | ❓ | ❓ | ❓ |
| **Well-Architected** | 🟡 Średni — low barrier | ❓ | ❓ | ❓ |
| **Migration** | 🟡 Średni — project portfolio | ❓ | ❓ | ❓ |
| **Security** | 🟠 Do oceny | ❓ | ❓ | ❓ |
| **Data & Analytics** | ⬜ Niska | ❓ | ❓ | ❓ |

**Uwaga:** Competency wymaga:
1. Minimum 2 customer references (case studies) z tym obszarem
2. Certyfikacje AWS w danym obszarze
3. Przejście AWS Technical Validation (review przez AWS Solution Architect)
4. Aktywne partnerstwo (min. Select tier)

---

## Wymagania per Competency — DevOps (priorytet)

> Szczegóły wymagań: [AWS DevOps Competency](https://aws.amazon.com/partners/competencies/devops/)

### Technical Validation Requirements

| Wymaganie | Status | Artefakty |
|-----------|--------|---------|
| CI/CD implementation (najlepiej AWS CodePipeline lub podobne) | ❓ | — |
| Infrastructure as Code (Terraform / CDK / CloudFormation) | 🟡 Mamy standardy | [[30-standards/iac-standard\|IaC Standard]] |
| Monitoring & Observability | ❓ | — |
| Security integration w pipeline | ❓ | — |
| Auto-scaling demonstrable | ❓ | — |

### Customer References Required: 2+

| Projekt / Klient | Status | Evidence | AWS Review |
|-----------------|--------|---------|-----------|
| ❓ | — | — | — |
| ❓ | — | — | — |

---

## Evidence — co jest, co brakuje

> Każdy projekt AWS to potencjalny evidence. Mapuj projekty → wymagania competency.

### Istniejące artefakty

| Artefakt | Typ | Competency | Link |
|---------|-----|-----------|------|
| LLZ — account baseline | IaC, Security | DevOps, Security | [[20-projects/internal/llz/context\|LLZ]] |
| AWS Tagging Standard | Governance | DevOps | [[30-standards/aws-tagging-standard\|Tagging]] |
| IaC Standard | IaC | DevOps | [[30-standards/iac-standard\|IaC]] |
| devops-toolkit | Automation | DevOps | [[60-toolkit/architecture-overview\|Toolkit]] |
| FinOps reviews | Cost optimization | Well-Architected | [[70-finobs/optimization-log\|FinOps]] |
| ❓ projekty klientów | — | — | — |

### Luki do wypełnienia

> [!todo] Evidence gaps — faza 0-30 dni
> - [ ] Lista projektów klientów AWS z ostatnich 2 lat (z PM-ami)
> - [ ] Które z tych projektów mają zgodę klienta na case study?
> - [ ] Czy mamy cokolwiek udokumentowanego do re:Use jako evidence?
> - [ ] Review: czy toolkit może generować raporty compliance jako artefakty?

---

## Evidence Log

> Każdy nowy artefakt dodaj tutaj. Szablon: `evidence/YYYY-MM-DD-serwis-projekt.md`

| Data | Projekt | Typ evidence | Competency | Plik |
|------|---------|-------------|-----------|------|
| — | — | — | — | — |

---

## Timeline submission

> *Uzupełnij po gap assessment w fazie 0-30 dni.*

| Competency | Gap closure ETA | Submission ETA | AWS Review ETA | Status |
|-----------|----------------|---------------|---------------|--------|
| DevOps | ❓ | ❓ | ❓ | ❓ |
| Well-Architected | ❓ | ❓ | ❓ | ❓ |

---

## Well-Architected Reviews — tracking

> WAR jako evidence + wartość dla klientów + wymaganie programu WAP.

| Projekt | Data | Pillars | Findings | Status | Artefakt |
|---------|------|---------|----------|--------|---------|
| — | — | — | — | — | — |

**Procedura WAR:**
1. Umówić call z klientem (lub wewnętrzny projekt)
2. Przeprowadzić review przez AWS Well-Architected Tool
3. Zidentyfikować HRI (High Risk Items)
4. Udokumentować findings + remediation plan
5. Plik evidence: `competency/evidence/YYYY-MM-DD-war-projekt.md`

---

## Notatki z AWS Technical Validation

> AWS SA przegląda evidence i przeprowadza technical review.
> Notatki z tych rozmów tu.

| Data | Temat | Outcome |
|------|-------|---------|
| — | — | — |
