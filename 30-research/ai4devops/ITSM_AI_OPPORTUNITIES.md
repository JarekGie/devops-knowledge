---
title: ITSM + AI — Mapa szans
tags:
  - research
  - ai4devops
  - itsm
  - itil
created: 2026-04-24
status: draft-scaffold
---

# ITSM + AI — Mapa szans

> Mapowanie procesów ITSM/ITIL na możliwości augmentacji AI.
> Perspektywa praktyczna — nie teoretyczna.
> Placeholdery ROI oznaczone `[ROI: TBD]` do uzupełnienia na podstawie danych z projektów.

Powiązane: [[README]] | [[AI4DEVOPS_REFERENCE_MODEL]] | [[VENDORS_AND_PATTERNS]]

---

## Jak czytać tę mapę

Dla każdego procesu ITSM:
- **Obecny ból** — co faktycznie boli bez AI
- **AI augmentation** — co AI może dodać
- **Poziom gotowości** — jak dojrzała jest technologia
- **Ryzyko** — co może pójść źle
- **ROI placeholder** — do zmierzenia

Poziomy gotowości: `🟢 dojrzałe` | `🟡 eksperymentalne` | `🔴 wczesna faza`

---

## 1. Incident Management

### Obecny ból

- Alert fatigue — zbyt wiele alertów, zbyt mało sygnału
- Czas do diagnozy (MTTD) wysoki przy nowym stacku
- Ręczne korelowanie zdarzeń z wielu źródeł
- Wiedza tacit — tylko senior wie co sprawdzić

### AI augmentation

| Możliwość | Opis | Gotowość | Ryzyko |
|-----------|------|----------|--------|
| Alert grouping / deduplication | Grupowanie alertów z tego samego root cause | 🟢 | False grouping ukrywa osobne problemy |
| Anomaly detection | Wykrycie odchylenia od baseline zanim threshold | 🟢 | Baseline drift — model uczy się złego stanu |
| LLM-assisted RCA | Hipoteza root cause z kontekstem środowiska | 🟡 | Halucynacje, brak kontekstu = zły trop |
| Runbook matching | Dopasowanie procedury do symptomów | 🟡 | Złe dopasowanie opóźnia właściwą akcję |
| Automatic severity classification | AI ocenia priorytet incydentu | 🟡 | Over/underclassification = niewłaściwa eskalacja |
| Incident summary generation | Automatyczny handoff summary do kolejnej zmiany | 🟢 | Pominięcie kluczowego faktu |

**ROI placeholder:**
- `[ROI: Redukcja MTTD — TBD na podstawie danych UAT maspex]`
- `[ROI: Redukcja alert fatigue — TBD: liczba alertów / tydzień przed vs po]`

---

## 2. Event Management

### Obecny ból

- Tysiące zdarzeń, z których większość to szum
- Brak korelacji między zdarzeniami z różnych warstw (infra, app, biznes)
- Brak automatycznego filtrowania w oknie maintenance

### AI augmentation

| Możliwość | Opis | Gotowość | Ryzyko |
|-----------|------|----------|--------|
| Event noise reduction | Filtrowanie zdarzeń niezwiązanych z realnym problemem | 🟢 | Pominięcie sygnału, który był ważny |
| Cross-layer correlation | Korelacja infra event + app error + business KPI | 🟡 | Fałszywe korelacje = błędne diagnozy |
| Topology-aware filtering | Filtrowanie na bazie zależności między serwisami | 🟡 | Wymaga aktualnego CMDB/grafu |
| Maintenance window awareness | AI wie o planowanych zmianach i tłumi alerty | 🟢 | Pomijane alerty w niezaplanowanych oknach |

**ROI placeholder:**
- `[ROI: Redukcja MTTD przez szybszą korelację — TBD]`

---

## 3. Change Management

### Obecny ból

- Ocena ryzyka zmiany jest ręczna i często niedoszacowana
- Brak korelacji między wdrożeniem a incydentem po fakcie
- Trudno stwierdzić, czy zmiana wpłynęła na metryki

### AI augmentation

| Możliwość | Opis | Gotowość | Ryzyko |
|-----------|------|----------|--------|
| Change risk scoring | AI ocenia ryzyko zmiany na podstawie historii i zakresu | 🟡 | Nowe typy zmian bez historii = brak danych |
| Impact blast radius estimation | Przewidywanie zakresu wpływu zmiany | 🟡 | Nieznane zależności runtime |
| Post-change correlation | Automatyczne powiązanie incydentów z ostatnią zmianą | 🟢 | Correlation ≠ causation |
| Rollback recommendation | AI sugeruje rollback gdy metryki się pogarszają | 🟡 | Zbyt agresywne rollbacki przerywają migracje |
| Change calendar conflicts | AI wykrywa konflikt zmian w tym samym oknie | 🟢 | Wymaga strukturyzowanych danych change |

**ROI placeholder:**
- `[ROI: Redukcja change-induced incidents — TBD]`
- `[ROI: Przyspieszenie risk assessment — TBD godziny/tygodniowo]`

---

## 4. Service Request Management

### Obecny ból

- Powtarzalne requesty obsługiwane manualnie
- Routing do niewłaściwego zespołu
- Brak samoobsługi dla prostych przypadków

### AI augmentation

| Możliwość | Opis | Gotowość | Ryzyko |
|-----------|------|----------|--------|
| Request classification & routing | AI klasyfikuje i routuje ticket do właściwego zespołu | 🟢 | Misrouting gdy opis niejasny |
| Self-service suggestion | Bot sugeruje rozwiązanie przed eskalacją | 🟢 | Zły fallback = frustracja użytkownika |
| Fulfillment automation | AI automatycznie realizuje proste requesty (np. reset hasła) | 🟢 | Uprawnienia agenta muszą być ściśle ograniczone |
| SLA prediction | Przewidywanie czy SLA zostanie dotrzymane | 🟡 | Zły model = false sense of security |

**ROI placeholder:**
- `[ROI: Redukcja manualnej obsługi requestów — TBD h/miesiąc]`

---

## 5. Capacity Management

### Obecny ból

- Ręczne prognozowanie — spreadsheets z trendami
- Reagowanie zamiast prewencja
- Trudność w korelowaniu wzrostu biznesowego z potrzebami infrastruktury

### AI augmentation

| Możliwość | Opis | Gotowość | Ryzyko |
|-----------|------|----------|--------|
| Demand forecasting | Prognozowanie zużycia na podstawie wzorców | 🟢 | Sezony bez precedensu (nowy klient, nowa funkcja) |
| Anomalous consumption detection | Wykrycie nagłego wzrostu bez biznesowego uzasadnienia | 🟢 | Fałszywe alarmy przy normalnych skokach |
| Right-sizing recommendations | AI sugeruje rozmiar instancji/serwisów | 🟢 | Kontekst aplikacyjny musi być znany |
| FinOps integration | Połączenie prognoz z kosztami | 🟡 | Modele kosztów zmieniają się (ceny AWS) |

**ROI placeholder:**
- `[ROI: Redukcja over-provisioning — TBD % kosztów infrastruktury]`

---

## 6. Availability Management

### Obecny ból

- SLO/SLA monitoring reaktywny
- Trudno przewidzieć degradację zanim osiągnie próg
- Brak korelacji między dostępnością a doświadczeniem użytkownika

### AI augmentation

| Możliwość | Opis | Gotowość | Ryzyko |
|-----------|------|----------|--------|
| Predictive availability | Wykrycie trendu degradacji zanim breach SLO | 🟡 | Wymaga dobrego modelu baseline |
| User-experience correlation | Korelacja metryki infrastruktury z UX (error rate, latency) | 🟢 | Proxy metryki ≠ realne UX |
| SLO burn rate alerting | Alert gdy burn rate wskazuje na breach zanim nastąpi | 🟢 | Dojrzałe (Google SRE book) |
| Failure mode prediction | Przewidywanie możliwych trybów awarii na podstawie historii | 🔴 | Mało danych, dużo szumu |

**ROI placeholder:**
- `[ROI: Poprawa MTTR przez wcześniejszą detekcję — TBD]`
- `[ROI: Redukcja SLO breaches — TBD %]`

---

## Podsumowanie — priorytety eksploracji

| Proces | Potencjał AI | Dojrzałość rynkowa | Trudność impl. |
|--------|-------------|-------------------|----------------|
| Incident | ⭐⭐⭐ | 🟢 | średnia |
| Event | ⭐⭐⭐ | 🟢 | średnia |
| Change | ⭐⭐ | 🟡 | wysoka |
| Service Request | ⭐⭐ | 🟢 | niska |
| Capacity | ⭐⭐ | 🟢 | średnia |
| Availability | ⭐⭐⭐ | 🟡 | wysoka |

## Questions to revisit later

- Które z tych szans mają sens dla projektów bez enterprise ITSM (tylko Jira + Slack + PagerDuty)?
- Czy ROI dla małych teamów (2-5 ops) jest w ogóle mierzalny?
- Jak ITIL 4's Value Streams mapują się na AI augmentation inaczej niż klasyczne procesy?
- Które obszary wymagają CMDB, a które działają bez niego?
- Kiedy AI w change managemencie staje się wymogiem compliance (np. SOC 2)?

#research #ai4devops #itsm #itil
