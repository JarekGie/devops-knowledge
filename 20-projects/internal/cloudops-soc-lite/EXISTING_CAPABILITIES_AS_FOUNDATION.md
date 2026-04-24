---
title: CloudOps/SOC-lite — istniejące capability jako fundament
type: hypothesis
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

# Istniejące capability jako fundament SOC-lite

> [!warning] STATUS: HIPOTEZA / EXPLORACJA
> Poniższy mapping opisuje obecny stan wiedzy — nie audyt wdrożeń.
> Każdy komponent wymaga osobnej weryfikacji dojrzałości przed podłączeniem.

---

## Komponenty foundation (obecny stan)

### GLPI — Problems workflow

| Atrybut | Stan |
|---------|------|
| Rola w hipotezie | Respond layer — ITSM, tracking incydentów, dowód |
| Aktualny use case | Helpdesk IT, ticketing, asset management |
| Potencjał extension | Problems module jako cloud incident tracker |
| Gap | Brak natywnej integracji z AWS — wymaga webhook/API gluecode |
| Ryzyko | Problems workflow może nie mapować się 1:1 na cloud incident lifecycle |

GLPI ma moduł **Problems** (odróżniony od Incidents w ITIL). Hipoteza: cloud events
(AWS Health, GuardDuty finding, CloudWatch alarm breach) powinny tworzyć Problems,
nie Incidents — bo są zdarzeniami systemowymi wymagającymi analizy przyczyny,
nie tylko szybkiego fixa.

### Wazuh — security/event correlation

| Atrybut | Stan |
|---------|------|
| Rola w hipotezie | Detect layer — korelacja eventów, security findings |
| Aktualny use case | Host-based IDS, log collection z serwerów |
| Potencjał extension | Ingest AWS GuardDuty findings, CloudTrail events, Security Hub alerts |
| Gap | AWS integration wymaga custom ruleset i decoder dla AWS event format |
| Ryzyko | False positive rate bez tuningu może być wysoki; bandwidth na tuning jest ograniczony |

Wazuh ma AWS integration module (oficjalny, SQS-based). Pobiera zdarzenia z:
- CloudTrail (przez S3 + SQS)
- GuardDuty (przez SQS)
- VPC Flow Logs (przez S3 + SQS)
- Macie (przez S3 + SQS)

To istniejący mechanizm — nie trzeba go budować od zera.

### Nagios / obecny monitoring

| Atrybut | Stan |
|---------|------|
| Rola w hipotezie | Baseline availability monitoring (poza AWS-native) |
| Aktualny use case | On-premise / infra monitoring, ping checks, service checks |
| Potencjał extension | Trigger dla on-call, integracja z GLPI przez passive checks |
| Gap | Nagios nie ma świadomości AWS-specific context (region, account, service health) |
| Limitacja | Nie zastąpi CloudWatch dla AWS workloads — rola uzupełniająca |

### On-call / eskalacje

| Atrybut | Stan |
|---------|------|
| Rola w hipotezie | Respond layer — human-in-the-loop dla zdarzeń wymagających akcji |
| Aktualny use case | Dyżury Cloud Support 24/7 (zakładam istniejące pokrycie) |
| Potencjał extension | Eskalacja z GLPI Problem do on-call duty engineer |
| Gap | Niejasne czy on-call coverage obejmuje weekendy / off-hours dla AWS Health events |
| Do weryfikacji | Istniejąca procedura eskalacji i progi alarmowania |

---

## Potencjalne źródła cloud signals

| Sygnał | Usługa AWS | Typ | Priorytet pilota | Dojrzałość |
|--------|-----------|-----|-----------------|-----------|
| Maintenance windows, service degradation | **AWS Health** | Operacyjny | ⭐⭐⭐ wysoki | Produkcyjny |
| Anomalie behawioralne, kompromitacja kont | **GuardDuty** | Bezpieczeństwo | ⭐⭐⭐ wysoki | Produkcyjny |
| Centralne agregowanie findings | **Security Hub** | Bezpieczeństwo/Compliance | ⭐⭐ średni | Produkcyjny |
| Metryki, alarmy, breaches | **CloudWatch Alarms** | Operacyjny | ⭐⭐ średni | Produkcyjny |
| API calls, kto co zrobił, kiedy | **CloudTrail** | Audit/Forensics | ⭐ niższy | Produkcyjny |
| Drift od standardów, missing tags, exposed resources | **Config / LLZ findings** | Governance | ⭐⭐ średni | Dojrzewa (LLZ) |
| Anomalie w stored data, PII exposure | **Macie** | Bezpieczeństwo danych | ⭐ niższy | Opcjonalny |
| Suspicious network flows | **VPC Flow Logs** | Sieć | ⭐ niższy | Wymaga Wazuh tuning |

**Rekomendacja dla pilota:** zacząć od AWS Health (najwyższy operacyjny impact, najprostszy format) + GuardDuty (bezpośredni link do Wazuh existing integration).

---

## Diagram logiczny: current-state vs future-state

### Current state

```
AWS Events ──────────────────────────────► EMAIL (spóźnione/niezauważone)
                                               │
CloudWatch Alarms ──────────────────────► SNS ─► Email
                                               │
GuardDuty findings ─────────────────────► (Console only, nikt nie patrzy regularnie)
                                               │
Nagios checks ──────────────────────────► Email/SMS (on-call)
                                               │
GLPI ───────────────────────────────────► Ręczne tickety (helpdesk, nie cloud events)
```

**Problem:** silosy. Każdy sygnał trafia inną ścieżką. Brak korelacji.
Brak centralnego miejsca „co się dzieje z naszą chmurą teraz."

---

### Future-state (hipoteza, po pilotcie)

```
AWS Health ──────────────┐
GuardDuty ───────────────┤
Security Hub ────────────┼──► GLPI Problems ──► On-call escalation
CloudWatch breach ───────┤         │
Config/LLZ findings ─────┘         │
                                   │
Wazuh ───────────────────────────►─┘  (Wazuh jako korelacja → trigger GLPI)
(+ CloudTrail, VPC Flow Logs)
                                   │
                                   ▼
                          Dashboard/visibility
                          (CloudWatch Dashboards lub Wazuh UI)
```

**Cel future-state:**
- Jeden punkt wejścia dla cloud-originated events
- Automatyczne zakładanie Problems (nie ręczne)
- On-call wie co jest, bo GLPI mu mówi

---

## Luki do wypełnienia przed pilotem

1. **Brak AWS → GLPI connector** — nie istnieje gotowe rozwiązanie; potrzebny webhook
   lub Lambda bridge (patrz [[PILOT_IDEA_GLPI_CLOUD_EVENTS]])
2. **Wazuh bez AWS ruleset** — default rules istnieją, ale wymagają tuningu pod nasz
   use case (fałszywe alarmy na normalną aktywność deployment pipeline)
3. **Brak zdefiniowanego triage workflow** — kto patrzy na Problem w GLPI w nocy?
   Jaki jest próg eskalacji? To proces, nie technologia.
4. **Security Hub nieaktywny lub nieużywany** — weryfikacja czy jest włączony i
   poprawnie skonfigurowany na wszystkich kontach

---

## Open questions

- [ ] Czy Wazuh jest faktycznie używany do correlation today, czy działa jako log collector tylko?
- [ ] Jakie Security Hub controls są aktualnie enabled? Ile failing findings jest teraz?
- [ ] Czy GLPI Problems module jest używany przez Cloud Support Team, czy tylko Incidents?
- [ ] Kto jest właścicielem GuardDuty konfiguracji w organizacji AWS?
- [ ] Czy AWS Health Organizational View jest skonfigurowany (dostęp do health events
  dla wszystkich kont organizacji), czy tylko per-account?

---

## Risks / anti-patterns

- **Anti-pattern:** próba podłączenia WSZYSTKICH sygnałów naraz — alert fatigue zabije
  pilota szybciej niż brak danych
- **Anti-pattern:** zakładanie, że Wazuh = SIEM; to correlation engine, nie full SIEM
- **Risk:** jeśli Security Hub nie jest włączony — mała praca onboardingowa, ale
  wymaga buy-in od ops/security team przed pilotem

---

## Powiązane notatki

- [[CLOUDOPS_SOC_LITE_HYPOTHESIS]] — geneza i working hypothesis
- [[PILOT_IDEA_GLPI_CLOUD_EVENTS]] — minimalny pilot
- [[CONNECTION_TO_LLZ_AND_NIS2]] — LLZ jako Prevent layer
- [[../llz/context|LLZ — Light Landing Zone]] — observability + governance baseline
- [[../../../10-areas/observability/README|Observability area]] — monitoring stack
- [[../../../10-areas/cloud-support/README|Cloud Support area]] — quotas, cases
