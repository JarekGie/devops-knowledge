---
title: CloudOps/SOC-lite — discovery index
type: index
domain: internal-product-strategy
origin: own
classification: internal
llm_exposure: allowed
cross_domain_export: summary-only
source_of_truth: vault
status: exploration
created: 2026-04-24
updated: 2026-04-24
---

# CloudOps / SOC-lite — discovery thread

> [!warning] WSZYSTKO TU JEST HIPOTEZĄ
> Ten katalog dokumentuje exploration, nie decyzje architektoniczne ani zatwierdzoną roadmapę.
> Zmiany statusu notatek wymagają jawnego oznaczenia.

---

## Kontekst

Exploration hypothesis wokół pytania: **czy istniejące capability (GLPI, Wazuh, LLZ, on-call)
można połączyć w spójną warstwę CloudOps visibility, zanim zbudujemy cokolwiek nowego?**

Wywołane przez: CEO → Head of Cloud → pytanie o SOC + realny ból operacyjny z AWS Health events.

**Model myślowy:**
```
Prevent (LLZ) → Detect (Wazuh + AWS findings) → Respond (GLPI + on-call)
```

---

## Notatki w tym katalogu

| Notatka | Zawartość | Status |
|---------|-----------|--------|
| [[CLOUDOPS_SOC_LITE_HYPOTHESIS]] | Geneza, working hypothesis, odróżnienie SOC enterprise vs lite | hipoteza |
| [[EXISTING_CAPABILITIES_AS_FOUNDATION]] | Mapa GLPI, Wazuh, Nagios, on-call + diagram current/future state | hipoteza |
| [[PILOT_IDEA_GLPI_CLOUD_EVENTS]] | Minimalny pilot: AWS Health → GLPI + GuardDuty → Wazuh | propozycja |
| [[INCUBATION_STRATEGY]] | Dlaczego small-circle first; 3 fazy: dogfooding → internal platform → customer-facing | obserwacja |
| [[CONNECTION_TO_LLZ_AND_NIS2]] | LLZ jako Prevent layer, NIS2 kontekst, audytowalność | hipoteza |

---

## Powiązane obszary vault

- [[../../cloud-support-as-a-service/service-vision|Cloud Support — wizja usługi]] — parent initiative
- [[../../cloud-support-as-a-service/operating-model|Cloud Support — model operacyjny]]
- [[../llz/context|LLZ — Light Landing Zone]] — Prevent layer
- [[../../../10-areas/observability/README|Observability area]] — monitoring stack
- [[../../../10-areas/cloud-support/README|Cloud Support area]] — quotas, AWS cases
- [[../../../80-architecture/platform-principles|Platform principles]] — zasady platformy

---

## Open threads (exploratory kanban)

| Temat | Stan | Priorytet |
|-------|------|-----------|
| AWS Health → GLPI pilot (Lambda bridge) | ⬜ nie started | wysoki |
| GuardDuty → Wazuh ingest verification | ⬜ nie started | średni |
| Security Hub — czy jest włączony w org? | ⬜ do sprawdzenia | wysoki |
| LLZ periodic audit → Config Drift findings | ⬜ idea | niski |
| NIS2 scope assessment (MakoLab) | ⬜ wymaga legal | niski |
| Phase 1 dogfooding — kryterium sukcesu | ⬜ do ustalenia | wysoki |

---

## Kto jest zaangażowany

*[Do uzupełnienia — nie dokumentuję nazwisk bez ich wiedzy]*

- Head of Cloud (sponsor pytania)
- Technical Manager DevOps/Cloud (inicjator GLPI integration idea)
- Cloud Support Team (primary users pilota)
