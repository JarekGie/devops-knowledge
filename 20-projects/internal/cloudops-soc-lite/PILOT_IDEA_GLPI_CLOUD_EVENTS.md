---
title: CloudOps/SOC-lite — pilot GLPI + cloud events
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

# Pilot — GLPI + Cloud Events

> [!warning] STATUS: HIPOTEZA / EXPLORACJA
> Poniższy pilot jest propozycją roboczą — nie zatwierdzonym projektem.

---

## Cel pilota

Sprawdzić, czy automatyczne tworzenie **Problems w GLPI** z cloud events:
1. zmniejsza liczbę przegapionych AWS Health notifications
2. daje Cloud Support Team jedno miejsce do śledzenia cloud-originated issues
3. jest wystarczająco prosto wdrożalne, żeby dogfooding był możliwy w ciągu 2–4 tygodni

**Kryterium sukcesu pilota:** przez 2 tygodnie co najmniej jeden realny AWS Health event
tworzy Problem w GLPI zanim ktokolwiek zauważy go ręcznie.

---

## Scope pilota — intentionally small

### Co wchodzi w zakres pilota

| Sygnał wejściowy | Akcja | Docelowe miejsce |
|-----------------|-------|-----------------|
| **AWS Health** — scheduled maintenance, service degradation | Automatyczne tworzenie GLPI Problem | GLPI Problems (kategoria: Cloud Health) |
| **GuardDuty** — HIGH severity findings | Trigger Wazuh alert → trigger GLPI Problem | GLPI Problems (kategoria: Security Finding) |

Tylko 2 sygnały, tylko 1 środowisko (wybrane konto dev/internal), tylko team Cloud Support.

### Czego NIE robić na starcie

- **Nie:** integracja z PROD kontami klientów — najpierw własne środowisko
- **Nie:** budowanie UI / dashboard do pilota — GLPI Problem list wystarczy
- **Nie:** automatyczne zamykanie Problems — to manual przez inżyniera
- **Nie:** pełna integracja Security Hub, CloudTrail, Config — to faza 2+
- **Nie:** SLA-owanie Problemów z pilotem — brak presji przed walidacją
- **Nie:** onboarding innych teamów do GLPI przed dogfooding przez Cloud Support
- **Nie:** tworzenie nowej roli „SOC analyst" — operuje istniejący engineer on-call

---

## Architektura techniczna pilota (wersja minimalna)

### Wariant A — AWS Health → GLPI bezpośrednio (preferowany)

```
AWS Health ─► EventBridge Rule
                    │
                    ▼
             Lambda (bridge)
                    │
             GLPI REST API
                    │
                    ▼
             GLPI Problem created
             (kategoria, opis, severity z Health event)
```

**Co robi Lambda:**
- Odbiera EventBridge event (AWS Health notification)
- Mapuje pola: event type, service, region, affected accounts → GLPI Problem fields
- Wywołuje `POST /apirest.php/Problem` w GLPI
- Loguje do CloudWatch (czy Problem został założony)

**GLPI REST API** — GLPI ma wbudowane REST API, endpoint `/apirest.php/Problem`
wymaga auth token. Brak oficjalnego AWS connector — to właśnie ten gluecode.

### Wariant B — GuardDuty → Wazuh → GLPI (bardziej złożony)

```
GuardDuty ─► Security Hub ─► SQS ─► Wazuh integration
                                          │
                               Wazuh active response
                                          │
                               Webhook → Lambda → GLPI
```

Wariant B jest bardziej złożony i wymaga Wazuh active response skonfigurowanego.
**Rekomendacja:** zacznij od Wariantu A (AWS Health → GLPI), Wariant B jako krok drugi.

---

## Wzorce webhook/event

### AWS EventBridge rule — AWS Health

```json
{
  "source": ["aws.health"],
  "detail-type": [
    "AWS Health Event",
    "AWS Health Abuse Event"
  ],
  "detail": {
    "eventTypeCategory": ["scheduledChange", "issue", "accountNotification"]
  }
}
```

### Przykładowy AWS Health event payload (wycinek)

```json
{
  "version": "0",
  "source": "aws.health",
  "detail-type": "AWS Health Event",
  "detail": {
    "eventArn": "arn:aws:health:eu-west-1::event/RDS/...",
    "service": "RDS",
    "eventTypeCode": "AWS_RDS_PLANNED_LIFECYCLE_EVENT",
    "eventTypeCategory": "scheduledChange",
    "statusCode": "open",
    "startTime": "2026-04-24T12:00:00Z",
    "endTime": "2026-04-24T18:00:00Z",
    "eventDescription": [{ "language": "en_US", "latestDescription": "..." }],
    "affectedEntities": [{ "entityValue": "db-instance-id" }]
  }
}
```

### Mapowanie na GLPI Problem fields

| AWS Health field | GLPI Problem field | Uwagi |
|------------------|--------------------|-------|
| `service` + `eventTypeCode` | `name` | np. „AWS_RDS_PLANNED_LIFECYCLE_EVENT" |
| `latestDescription` | `content` | treść jako opis problemu |
| `startTime` / `endTime` | `time_to_resolve` | jeśli scheduled change ma okno |
| `statusCode: open/closed` | `status: 1=New / 8=Closed` | mapowanie ITIL |
| `HIGH/MEDIUM` severity | `urgency` + `impact` | AWS Health nie ma explicit severity, ale type category wyznacza |
| region + account | Tag / custom field | do dodania jako GLPI ITILCategory |

### GuardDuty finding — przykładowy severity trigger

```
HIGH severity (>= 7.0) → Wazuh alert → GLPI Problem
MEDIUM severity (4.0–6.9) → Wazuh alert (logowanie, bez GLPI)
LOW severity (< 4.0) → Wazuh log only
```

---

## Definicja pilota „gotowy"

Pilot uznajemy za gotowy do uruchomienia gdy:

- [ ] Lambda function zdeplojowana na internal account
- [ ] EventBridge rule aktywna (AWS Health events)
- [ ] GLPI API token skonfigurowany (read-write, tylko Problems category)
- [ ] Jeden test event przesłany manualnie przez `aws health describe-events --test` lub mockowy payload
- [ ] Problem pojawia się w GLPI z prawidłową kategorią

Czas estymowany do „gotowy": 4–8 godzin inżynierskich (1 dzień).

---

## Open questions

- [ ] Kto jest właścicielem GLPI instancji? Czy IT ops ma access do konfiguracji API?
- [ ] Czy GLPI Problems module jest używany? Czy jest skonfigurowany workflow dla Cloud Problems?
- [ ] Czy mamy konto AWS (internal) gdzie możemy testować EventBridge bez ryzyka dla klientów?
- [ ] Czy AWS Health Organizational View jest włączony? Czy widzimy zdarzenia ze wszystkich kont?
- [ ] Kto będzie przypisany jako domyślny assignee dla Cloud Problems w GLPI?
- [ ] Jakie jest akceptowalne SLO dla acknowledging Problem (czas do pierwszego spojrzenia)?

---

## Risks / anti-patterns

- **Anti-pattern:** budowanie zaawansowanego mappera od razu — start simple, 5 fields, jeden kategoria
- **Anti-pattern:** zakładanie problemów na każdy CloudWatch alarm — to będzie noise;
  Health events to właściwy entry point (signal quality > quantity)
- **Risk:** GLPI API może mieć ograniczony rate limit lub wymagać specyficznej wersji —
  weryfikuj wersję GLPI przed implementacją (`/apirest.php?debug`)
- **Risk:** Lambda w Lambda cold-start może powodować opóźnienia — dla Health events
  to akceptowalne (nie są real-time critical)

---

## Powiązane notatki

- [[CLOUDOPS_SOC_LITE_HYPOTHESIS]] — szerszy kontekst hipotezy
- [[EXISTING_CAPABILITIES_AS_FOUNDATION]] — GLPI i Wazuh jako foundation
- [[INCUBATION_STRATEGY]] — dlaczego zaczynamy od dogfooding
- [[CONNECTION_TO_LLZ_AND_NIS2]] — Health events jako compliance signal
- [[../../../10-areas/cloud-support/README|Cloud Support area]] — kontekst operacyjny
