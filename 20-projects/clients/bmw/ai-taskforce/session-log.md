---
title: BMW AI Taskforce — session log
domain: client-work
origin: own
classification: confidential
llm_exposure: restricted
cross_domain_export: prohibited
source_of_truth: vault
created: 2026-04-27
updated: 2026-04-27
---

# BMW AI Taskforce — Session Log

---

## 2026-04-27 — ITSM AI Mapping — wzbogacenie arkusza Excel

**Stan:** DONE

### Co zrobiono

Wzbogacono arkusz `ai-taskforce.xlsx` (sheet: ` MakoLab AI tools (SOL)`) jako senior konsultant AIOps/ITSM/Enterprise Architecture.

**Korekty istniejących wierszy:**
- `Manage Problems`: obniżono `Saving` z **50% → 20–30%** (optimistic 35–40% z warunkami). Uzasadnienie: halucynacje LLM w RCA multi-service, brak single-source-of-truth dla trace correlation w typowym enterprise. Oryginalna wartość była marketingowa, nie operacyjna.
- `Manage Service Requests`: doprecyzowano zakres — 20–35% **tylko przy dojrzałym katalogu**, ~5% bez niego.
- `Manage Knowledge`: podniesiono do **40–55%** (z 40%) — GenAI ma mierzalny wpływ na drafting i search velocity.
- Uzupełniono wcześniej puste wiersze: Manage Service Configuration, Manage Capacity, Manage IT Service Continuity.

**Nowe kolumny (dodane do każdego wiersza):**
- `H`: **Prerequisites / Maturity Required** — monitoring quality, tracing, CMDB, structured KB, governance guardrails
- `I`: **AI Type Classification** — Assistive / Analytical / Generative / Autonomous (z ograniczeniami scope)

**Zmiana nazwy kolumny:**
- `Saving` → **Effort Reduction Potential**

**Nowe wiersze (zielone w Excelu):**
- `Change Management` — risk scoring, CAB preparation, impact analysis, rollback recommendation, change summary generation
- `Configuration / CMDB / Asset Management` — dependency discovery, CMDB enrichment, drift detection, ownership inference
- `Cloud Operations / SRE` — AWS Health triage, GuardDuty enrichment, cost anomaly explanation, Terraform drift, runbook copilots

### Executive summary (kluczowe wnioski)

**High value / low risk:**
1. Manage Knowledge (40–55%) — najlepszy ROI, niski blast radius
2. Manage Events — alert deduplication (30–50% noise reduction), mierzalne w pierwszym kwartale
3. Change Management — CAB prep automation (20–30%)
4. Manage Service Requests — virtual agents dla dobrze zdefiniowanych katalogów

**High risk / wymaga dojrzałości:**
1. Manage Problems RCA — halucynacje, wymaga full observability + senior sign-off
2. CMDB automation — częściowe CMDB jest gorsze niż manualne (garbage propagation)
3. Incidents auto-remediation — wymaga ścisłego governance scope
4. Cloud Ops security enrichment — AI daje kontekst, nie decyzję

### Plik

```
20-projects/clients/bmw/ai-taskforce/ai-taskforce.xlsx
Sheet: MakoLab AI tools (SOL)
Wiersze danych: 21–32 (12 obszarów ITSM)
```

### Następne kroki (otwarte)

- Zdecydować czy Development section (Plan/Prepare/Create/Build/Test/Release/Deploy) też wymaga wypełnienia AI tools/Saving — arkusz ma te kolumny puste
- Ewentualne przeniesienie tabeli do PowerPoint (ai-taskforce.pptx)
- Omówienie z BMW: gotowość prerequisites — szczególnie CMDB i observability maturity
