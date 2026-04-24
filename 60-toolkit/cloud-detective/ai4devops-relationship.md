---
title: Cloud Detective — relacja do AI4DevOps research
domain: private-rnd
origin: own
classification: restricted
llm_exposure: restricted
cross_domain_export: prohibited
source_of_truth: vault
created: 2026-04-24
updated: 2026-04-24
---

# Cloud Detective — relacja do AI4DevOps research

> Opisuje jak `60-toolkit/cloud-detective/` i `30-research/ai4devops/` współistnieją bez mieszania domen.

Powiązane: [[README]] | [[research-boundaries]] | [[../../30-research/ai4devops/CLOUD_DETECTIVE_CONNECTIONS|AI4DevOps — hipotezy ewolucji Cloud Detective]]

---

## Podział odpowiedzialności

| Folder | Domena | Co zawiera |
|--------|--------|-----------|
| `30-research/ai4devops/` | `shared-concept` | Neutralne wzorce AIOps, ITSM, modele referencyjne — bez specyfiki cloud-detective |
| `60-toolkit/cloud-detective/` | `private-rnd` | Hipotezy i architektura specyficzna dla cloud-detective, implementacja |

---

## Jak korzystać z `30-research/ai4devops/` w kontekście cloud-detective

**ALLOWED:**
- Linkowanie do wzorców z `30-research/ai4devops/` jako referencji
- Cytowanie modeli referencyjnych jako inspiracji
- Mapowanie warstw modelu referencyjnego na architekturę cloud-detective

**MUST NOT:**
- Kopiowanie treści z `30-research/ai4devops/` do tego folderu
- Modyfikowanie notatek `shared-concept` aby zawierały hipotezy cloud-detective
- Przenoszenie hipotez cloud-detective do `30-research/ai4devops/` jako „neutralnych wzorców"

---

## Hipotezy cloud-detective oparte na wzorcach AI4DevOps

Poniższe hipotezy z [[../../30-research/ai4devops/CLOUD_DETECTIVE_CONNECTIONS|CLOUD_DETECTIVE_CONNECTIONS]] należą do tej domeny (`private-rnd`), nie do `shared-concept`:

| Hipoteza | Status | Opis |
|----------|--------|------|
| H-CD1 — Tags-as-CMDB | nieweryfikowana | Tagi AWS jako lekki substytut CMDB dla kontekstu |
| H-CD2 — Discovery snapshot | nieweryfikowana | `discover-aws` jako input dla LLM reasoning |
| H-CD3 — Findings as signal | nieweryfikowana | Diff findings w czasie jako quasi-signal feed |
| H-CD4 — LLM findings summary | nieweryfikowana | Opcjonalny krok LLM summary po audycie |
| H-CD5 — Context dla agentów | wczesna | Context graph jako input dla autonomicznych agentów |

---

## Dlaczego ta separacja jest ważna

`30-research/ai4devops/` może być swobodnie używany w sesjach LLM z kontekstem `internal-product-strategy` (Cloud Support as a Service) jako neutralna inspiracja.

Gdyby hipotezy cloud-detective były w `30-research/ai4devops/`, automatycznie trafiałyby do sesji LLM o strategii MakoLab — naruszając izolację `private-rnd` od `internal-product-strategy`.

Separacja chroni niezależność badań własnych od strategii komercyjnej.
