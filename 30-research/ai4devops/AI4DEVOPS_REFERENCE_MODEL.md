---
title: AI4DevOps — Model referencyjny architektury
tags:
  - research
  - ai4devops
  - architecture
  - reference-model
created: 2026-04-24
status: draft-scaffold
---

# AI4DevOps — Model referencyjny architektury

> Szkic roboczy. Każda warstwa to zestaw pytań, nie gotowa implementacja.
> Celem jest mapa przestrzeni — nie blueprint systemu.

Powiązane: [[README]] | [[VENDORS_AND_PATTERNS]] | [[CLOUD_DETECTIVE_CONNECTIONS]]

## Przegląd warstw

```
┌─────────────────────────────────────────────────────────┐
│  5. GOVERNANCE / HUMAN-IN-LOOP                          │
│     zatwierdzenia, audit trail, rollback, polityki      │
├─────────────────────────────────────────────────────────┤
│  4. AUTOMATION LAYER                                    │
│     akcje, remediacja, runbooki, pipeline triggers      │
├─────────────────────────────────────────────────────────┤
│  3. REASONING LAYER                                     │
│     korelacja, RCA, priorytyzacja, rekomendacje         │
├─────────────────────────────────────────────────────────┤
│  2. CONTEXT / CMDB GRAPH                                │
│     tożsamość zasobu, zależności, historia, własność    │
├─────────────────────────────────────────────────────────┤
│  1. SIGNAL INGESTION                                    │
│     metryki, logi, alerty, zdarzenia, traces            │
└─────────────────────────────────────────────────────────┘
```

---

## Warstwa 1 — Signal Ingestion

### Co wchodzi

| Typ sygnału | Przykłady | Latencja |
|-------------|-----------|----------|
| Metryki | CPU, memory, latency, error rate | real-time (~1s) |
| Logi | aplikacyjne, systemowe, audit | near-real-time |
| Distributed traces | Jaeger, X-Ray, Zipkin | near-real-time |
| Zdarzenia infrastruktury | ECS task stop, EC2 state change | event-driven |
| Zmiany konfiguracji | Terraform apply, deploy, config drift | on-event |
| Tickety i zmiany ITSM | incydenty, change requests | low-frequency |

### Otwarte pytania

- Skąd wiemy, które sygnały są diagnostyczne, a które szum?
- Jak normalizować sygnały z różnych platform (AWS, GCP, on-prem) do wspólnego formatu?
- Czy sygnały z CI/CD (test failures, build times) są częścią tej warstwy?
- Jaki jest minimalny set sygnałów dla użytecznej korelacji?

---

## Warstwa 2 — Context / CMDB Graph

> [!note] Hipoteza: to jest najsłabiej rozwiązana warstwa w większości systemów AIOps.

### Co reprezentuje

Graf środowiska: zasoby, ich właściwości, relacje i historia.

```
Service A ──uses──▶ Database B
Service A ──deployed-by──▶ Pipeline C
Service A ──owned-by──▶ Team X
Service A ──runs-on──▶ ECS Cluster Y
Alert Z ──triggered-on──▶ Service A
```

### Minimalne węzły grafu

| Węzeł | Atrybuty kluczowe |
|-------|-------------------|
| Service | nazwa, owner, środowisko, tier |
| Infrastructure resource | type, ARN/ID, region, tagi |
| Deployment | timestamp, artefakt, zmiana |
| Alert/Event | czas, severity, źródło |
| Change | kto, co, kiedy, tickets |

### Otwarte pytania

- Czy klasyczne CMDB (ServiceNow, Device42) to dobry punkt startowy, czy za ciężkie?
- Jak utrzymać świeżość grafu bez continuous discovery (kosztowne)?
- Czy graf musi być persystowany, czy może być budowany on-demand z tagów i API?
- Jaki jest minimalny viable context graph dla projektu z 5 serwisami?
- Jak modelować zależności, których nie widać w konfiguracji (runtime coupling)?

---

## Warstwa 3 — Reasoning Layer

### Funkcje

| Funkcja | Opis | Podejście |
|---------|------|-----------|
| Korelacja alertów | Grupowanie alertów z tego samego root cause | ML clustering / rule engine |
| Anomaly detection | Odchylenie od baseline | statistical / ML |
| Root Cause Analysis | Hipoteza co spowodowało incydent | graph traversal + LLM |
| Priorytyzacja | Ranking ważności zdarzeń | scoring model |
| Rekomendacja akcji | Sugestia następnego kroku | LLM + runbook matching |

### Otwarte pytania

- Gdzie LLM dodaje wartość vs. gdzie jest overkill (prosty rule engine wystarczy)?
- Jak oceniać jakość RCA bez ground truth (każdy incydent jest unikalny)?
- Jak zapobiec halucynacji modelu gdy kontekst środowiska jest niekompletny?
- Czy reasoning powinien być wyjaśnialny (explainable AI) — wymóg compliance?
- Jak obsłużyć brak historii dla nowego środowiska?

---

## Warstwa 4 — Automation Layer

### Poziomy automatyzacji

| Poziom | Opis | Przykład |
|--------|------|---------|
| L0 — Notify | Tylko powiadomienie | Alert na Slack |
| L1 — Suggest | Sugestia akcji dla człowieka | „Rozważ restart serwisu X" |
| L2 — Assisted | Człowiek zatwierdza, system wykonuje | Propozycja runbooka + 1-click |
| L3 — Supervised | System działa, człowiek monitoruje | Auto-scaling z alertem |
| L4 — Autonomous | Pełna automatyzacja bez nadzoru | ⚠ Tylko dla niskiego ryzyka |

> [!warning] Zasada domyślna
> Domyślny poziom dla operacji produkcyjnych: **L2**.
> L4 wyłącznie dla odwracalnych, idempotentnych akcji niskiego ryzyka.

### Otwarte pytania

- Jak definiować granicę „niskiego ryzyka" dla L3/L4?
- Czy automatyczne rollbacki deploymentu to L3 czy L4?
- Jak audit trail dla akcji autonomicznych spełnia wymagania compliance?
- Kto jest właścicielem decyzji gdy agent podejmuje błędną akcję?

---

## Warstwa 5 — Governance / Human-in-Loop

### Mechanizmy

| Mechanizm | Cel |
|-----------|-----|
| Approval gates | Zatwierdzenie przed wykonaniem akcji |
| Dry-run mode | Podgląd co agent zrobi bez wykonania |
| Audit trail | Niemodyfikowalny log decyzji i akcji agenta |
| Rollback policy | Automatyczny lub manualny rollback po błędzie |
| Scope limits | Co agent może, a czego nie może dotknąć |
| Blast radius control | Limity zakresu zmian (np. max 1 serwis naraz) |

### Otwarte pytania

- Czy governance powinna być konfigurowalna per środowisko (dev vs prod)?
- Jak modele uprawnień (IAM, RBAC) mapują się na uprawnienia agenta?
- Czy agent powinien mieć własną tożsamość (IAM role) odróżnialną od człowieka?
- Jak obsługiwać scenariusz gdy agent działa poprawnie, ale człowiek nie rozumie dlaczego?
- Kto definiuje, co jest „poza zakresem" agenta?

---

## Questions to revisit later

- Czy te 5 warstw to właściwa abstrakcja, czy brakuje czegoś fundamentalnego?
- Jak ta architektura skaluje się od 1 serwisu do 100 serwisów?
- Czy warstwa kontekstowa (W2) może być zewnętrzna (np. tags-as-CMDB) bez dedykowanej bazy grafowej?
- Jakie są realistyczne koszty utrzymania reasoning layer (LLM API calls)?
- Czy ten model ma sens dla małego projektu AWS bez enterprise ITSM?

#research #ai4devops #architecture #reference-model
