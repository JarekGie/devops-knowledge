---
title: "ADR-001: Local-First Architecture"
domain: private-rnd
origin: own
classification: restricted
llm_exposure: restricted
cross_domain_export: prohibited
source_of_truth: vault
created: 2026-05-07
updated: 2026-05-07
status: accepted
---

# ADR-001 — Local-First Architecture

**Status:** Accepted  
**Data:** 2026-05-07

---

## Kontekst

System anonimizacji przetwarza dane wrażliwe klientów: PII, dane infrastruktury, sekrety. Decyzja o modelu deploymentu (cloud vs local) ma bezpośrednie implikacje bezpieczeństwa i governance.

Opcje rozważane:
1. **Local-first** — cały pipeline działa lokalnie; cloud jest opcjonalny i kontrolowany
2. **Cloud-hosted service** — pipeline w chmurze (np. AWS Lambda + S3 + RDS)
3. **Hybrid** — parsing lokalnie, inference w chmurze

---

## Decyzja

**Wybrany: Local-first (opcja 1)**

System musi być uruchamialny lokalnie, bez żadnych zewnętrznych zależności runtime.

---

## Uzasadnienie

**1. Dane wrażliwe nie opuszczają środowiska operatora**

Original documents i token maps muszą pozostać lokalne. Jakikolwiek cloud dependency w critical path stwarza ryzyko niezamierzonego wycieku (np. przez SDK internals, log shipping do cloud, accidental S3 bucket exposure).

**2. Compliance z vault governance**

[[DOMAIN_ISOLATION_CONTRACT]] i [[LLM_EXPORT_POLICY]] zakazują wysyłania `restricted` danych do zewnętrznych LLM. Local-first jest techniczną implementacją tej polityki: system fizycznie nie może wysłać danych jeśli nie ma zewnętrznych połączeń.

**3. Offline operability**

Operator musi móc pracować w środowiskach bez internetu (klient on-premise, VPN, restricted network). Cloud dependency byłby blokerem.

**4. Deterministyczność i audytowalność**

Pipeline lokalny jest w pełni kontrolowany przez operatora. Żadne zewnętrzne API nie zmienia zachowania systemu.

**5. Prostota MVP**

Cloud deployment wymaga IAM, VPC, encryption at rest, backup policy — przed MVP to overengineering.

---

## Konsekwencje

**Pozytywne:**
- Zero cloud costs w PoC i MVP
- Pełna kontrola operatora nad danymi
- Offline operability
- Latencja lokalna < latencja cloud

**Negatywne:**
- Wymaga instalacji Docker + PostgreSQL + Redis lokalnie
- Skalowanie horyzontalne wymaga redesignu (przyszły problem)
- Brak centralnego audit log dla wielu operatorów (Faza 2)

**Implikacje dla przyszłości:**
- Faza 2 może dodać cloud deployment jako opcjonalny overlay, ale nie jako wymaganie
- Architektura MVP musi być zaprojektowana tak, żeby cloud deployment był addy-on, nie refactor
