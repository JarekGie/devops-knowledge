---
title: CloudOps/SOC-lite — powiązanie z LLZ i NIS2
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

# Powiązanie z LLZ i NIS2

> [!warning] STATUS: HIPOTEZA / EXPLORACJA
> Poniższe powiązania są hipotezami strategicznymi, nie gotową architekturą.

---

## LLZ jako Prevent layer

Light Landing Zone (LLZ) to de facto warstwa **Prevent** w modelu SOC-lite:

| LLZ capability | Rola w Prevent | Wartość dla SOC-lite |
|----------------|---------------|---------------------|
| **Scaffold conformance** (Terraform structure) | Redukuje ryzyko błędów konfiguracyjnych jako klasy | Mniej „self-inflicted" incydentów do Detect/Respond |
| **Observability readiness** (logging coverage) | Zapewnia, że jest co logować i alarmować | Bez logów nie ma Detect — LLZ jest warunkiem wstępnym |
| **Tagging governance** (Tag Policies) | Traceability: kto jest właścicielem zasobu, co to jest | Security findings mają kontekst (projekt, env, owner) |

**Relacja:** LLZ nie jest częścią SOC-lite pilota, ale jest jego **prerequisitem**.
Jeśli projekt nie przeszedł przez LLZ baseline, cloud findings są trudniejsze w
interpretacji (brak tagów = brak kontekstu dla GuardDuty finding).

### LLZ jako sensor/control plane

Wyobrażam sobie LLZ jako warstwę **konfiguracji środowiska** przed monitoringiem:

```
LLZ (Prevent) ──► stan konfiguracji jest poprawny
                        │
                        ▼
CloudWatch / GuardDuty / Health (Detect) ──► anomalie od stanu poprawnego
                        │
                        ▼
GLPI Problems + on-call (Respond) ──► akcja
```

LLZ findings (np. „brak VPC Flow Logs", „missing required tags") mogą być traktowane
jako **Config findings** i powinny trafić do Detect layer jako drift od standardu —
a nie tylko jako jednorazowy audyt.

**Hipoteza:** `toolkit audit-pack aws-logging` mógłby być uruchamiany periodycznie
(np. nightly) i wysyłać diff findings do GLPI jako Problems kategorii „Config Drift".

---

## Central monitoring/logging jako fundament Detect

Bez centralnego logowania nie ma skutecznego Detect. LLZ observability readiness
jest minimalnym standardem, który każdy projekt musi spełnić przed podłączeniem
do SOC-lite Detect layer.

**Zależność:**
- Projekt audytowany przez `aws-logging` → wyniki w `logging-matrix.json`
- Projekty z `ready_to_operate: true` (po fixie gaps) → mogą być podłączone do Wazuh/Security Hub
- Projekty bez logging baseline → Detect layer nie ma co detectować

To tworzy **natural onboarding gate**: zanim projekt trafi do SOC-lite, musi przejść
LLZ observability check. Dobra architektura — nie sztuczna bariera.

---

## NIS2 — kontext regulacyjny

NIS2 (Dyrektywa UE o bezpieczeństwie sieci i informacji, transpozycja w Polsce 2025+)
wprowadza wymagania dla podmiotów istotnych i kluczowych, w tym dla dostawców
usług zarządzanych (managed services).

MakoLab jako dostawca Cloud Support i managed infrastructure może wpaść pod
zakres NIS2 jako **podmiot świadczący usługi zaufania lub zarządzane usługi IT**
dla klientów z sektorów objętych dyrektywą.

### Co NIS2 wymaga (uproszczenie robocze)

| Wymaganie NIS2 | Jak SOC-lite może pomóc |
|----------------|------------------------|
| **Zgłaszanie incydentów** (24h wstępne, 72h szczegółowe) | GLPI Problem jako incident record z timestampem i dowodami |
| **Zarządzanie ryzykiem** (polityki, ocena ryzyka) | LLZ jako udokumentowany standard baseline |
| **Środki techniczne** (monitoring, logging) | CloudWatch + Wazuh + Security Hub jako udokumentowany stack |
| **Continuity** (BCP, RTO/RPO) | LLZ tagging + observability jako prerequisit dla RTO oceny |
| **Łańcuch dostaw** (dostawcy muszą spełniać wymagania) | MakoLab może być wymagany do wykazania capability przez klientów NIS2 |

> [!important] Zastrzeżenie
> Powyższe NIE jest analizą prawną. Przed użyciem NIS2 jako argumentu sprzedażowego
> wymagana jest weryfikacja z prawnikiem/compliance. Niektóre podmioty MakoLab
> mogą nie podpadać pod NIS2 — to wymaga klasyfikacji.

### Audytowalność / incident evidence

Niezależnie od NIS2, **audytowalność** jest wartością samą w sobie:

- GLPI Problem z timestampem, assignee, akcjami = **dowód incydentowy**
- GuardDuty findings + CloudTrail = **co się stało, kto to zrobił**
- AWS Health + GLPI = **kiedy wiedzieliśmy o problemie infrastruktury**

Klient, który pyta „co zrobiliście podczas incydentu i kiedy?" — chce tego właśnie.
SOC-lite daje odpowiedź; email thread nie daje.

---

## Możliwy future link: Managed Detection + Cloud Support 24/7

**Hipoteza długoterminowa** (Phase 3 z [[INCUBATION_STRATEGY]]):

Cloud Support 24/7 + SOC-lite capability = **Managed Detection & Response dla cloud workloads**

| Wariant | Co oferujemy | Target klient |
|---------|-------------|--------------|
| **Cloud Support 24/7 (obecny)** | Reaktywne wsparcie, monitoring uptime | AWS customers z potrzebą 24/7 support |
| **Cloud Support + CloudOps visibility** | Proactive health alerts, cloud event tracking | Klienci chcący zmniejszyć MTTR |
| **Managed Detection (future)** | GuardDuty triage, anomalie, proactive security | Klienci pod NIS2 lub z security requirements |

Nie jest to Services portfolio decision — to **exploration thread**. Wymaga:
- walidacji Phase 1 pilota
- rozmowy z sales / Head of Cloud o segment fit
- oceny czy klienci faktycznie za to płacą

---

## Open questions

- [ ] Czy MakoLab jest objęty NIS2 jako podmiot? Kto to powinien odpowiedzieć (legal/compliance)?
- [ ] Czy klienci MakoLab w sektorach objętych NIS2 (energia, transport, finanse...)
  pytają o capability detection/logging od swoich dostawców IT?
- [ ] Jak LLZ observability baseline ma się do wymagań raportowania NIS2?
  Czy istnieje nakładka (mapping LLZ controls → NIS2 requirements)?
- [ ] Czy AWS Security Hub posiada gotowe compliance frameworks dla NIS2 lub
  ISO 27001 które można użyć jako starting point?
- [ ] Czy GLPI jest wystarczającym narzędziem do incident evidence dla audytora,
  czy wymagany jest dedykowany case management?

---

## Risks / anti-patterns

- **Anti-pattern:** używanie NIS2 jako primary driver dla pilota — to zbyt odległy
  cel; primary driver to ból operacyjny (AWS Health events)
- **Anti-pattern:** zakładanie, że LLZ compliance = NIS2 compliance — to nieprawda;
  LLZ jest baseline operacyjny, nie certyfikacja bezpieczeństwa
- **Risk:** klienci MakoLab mogą być pod NIS2 zanim MakoLab jest gotowy — to ryzyko
  reputacyjne, nie tylko operacyjne
- **Risk:** regulacje mogą ewoluować szybciej niż budowa capability — nie buduj pod
  konkretną wersję regulacji, buduj pod trwałe capability

---

## Powiązane notatki

- [[CLOUDOPS_SOC_LITE_HYPOTHESIS]] — geneza i working hypothesis
- [[EXISTING_CAPABILITIES_AS_FOUNDATION]] — Wazuh, GLPI jako Detect/Respond
- [[INCUBATION_STRATEGY]] — faza 3 jako potencjalna managed detection offering
- [[PILOT_IDEA_GLPI_CLOUD_EVENTS]] — minimalny pilot
- [[../llz/context|LLZ — Light Landing Zone]] — Prevent layer szczegóły
- [[../llz/wymagania-makolab/analiza-ryzyka|LLZ — analiza ryzyka]]
- [[../../cloud-support-as-a-service/service-vision|Cloud Support — wizja usługi]]
- [[../../../10-areas/observability/README|Observability area]]
