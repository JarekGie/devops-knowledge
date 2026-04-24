---
title: Cloud Detective — granice domeny badawczej
domain: private-rnd
origin: own
classification: restricted
llm_exposure: restricted
cross_domain_export: prohibited
source_of_truth: vault
created: 2026-04-24
updated: 2026-04-24
---

# Cloud Detective — granice domeny badawczej

> Kontrakt opisujący co należy, a co nie należy do domeny `private-rnd` dla Cloud Detective i devops-toolkit.

Powiązane: [[README]] | [[ai4devops-relationship]] | [[../../_system/DOMAIN_ISOLATION_CONTRACT|Domain Isolation Contract]]

---

## Czym jest ta domena

`60-toolkit/cloud-detective/` należy do domeny `private-rnd`:
- Prywatne badania i rozwój
- Hipotezy architektoniczne własne
- Kod i kontrakty devops-toolkit
- Niemające bezpośredniego związku z kontraktami klientowskimi MakoLab

---

## Co MUST znajdować się w tej domenie

- Hipotezy techniczne i architektoniczne cloud-detective
- Kontrakty komend devops-toolkit (`60-toolkit/contracts/`)
- Dokumentacja CLI i wzorce implementacji
- Własne eksperymenty i PoC

---

## Co MUST NOT znajdować się w tej domenie

**Materiały klientowskie:**
- Dane infrastruktury klientów
- Konfiguracje systemów klientów
- Wyniki audytów konkretnych środowisk klientów (te są w `20-projects/clients/<klient>/`)

**Strategia produktowa MakoLab:**
- Roadmapa Cloud Support as a Service
- Modele cenowe ani oferty komercyjne
- Decyzje zarządcze MakoLab

---

## Co MAY wchodzić z zewnątrz

**Ze `shared-concept`:**
- Wzorce z `30-research/ai4devops/` jako inspiracja
- Ogólne modele referencyjne AIOps
- Neutralna wiedza techniczna

**Z `internal-product-strategy`:**
- Tylko jawne derived insights z oznaczeniem źródła i daty
- Nie: surowa strategia Cloud Support as a Service

---

## Zasada współistnienia z AI4DevOps research

Cloud Detective MUST NOT duplikować ani importować treści z `30-research/ai4devops/`.

Cloud Detective MAY linkować do `30-research/ai4devops/` jako źródła neutralnych wzorców.

`30-research/ai4devops/` MUST NOT zawierać hipotez specyficznych dla cloud-detective — te są tutaj.

Szczegóły: [[ai4devops-relationship]]

---

## Zasady użycia LLM

- Sesje LLM dla cloud-detective MUST zawierać tylko materiały `private-rnd` + `shared-concept`
- MUST NOT zawierać materiałów klientowskich ani strategii Cloud Support as a Service
- Przed sesją: [[../../_system/PROMPT_BOUNDARY_CHECKLIST|Prompt Boundary Checklist]]
