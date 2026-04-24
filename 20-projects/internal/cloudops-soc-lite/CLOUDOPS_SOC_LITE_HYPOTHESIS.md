---
title: CloudOps/SOC-lite — hipoteza capability
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

# CloudOps/SOC-lite — hipoteza capability

> [!warning] STATUS: HIPOTEZA / EXPLORACJA
> To NIE jest decyzja architektoniczna ani zatwierdzona roadmapa.
> Każde zdanie opisuje wstępne przemyślenia — nie przyjęte kierunki.

---

## Geneza pomysłu

### Trigger 1 — pytanie z góry (top-down)

CEO zapytał Head of Cloud: **„czy jesteśmy w stanie wystawić SOC?"**

Pytanie było ogólne, bez doprecyzowania zakresu. Head of Cloud podjął wstępną próbę
eksploracji tematu przez **szerokie spotkanie brainstormingowe** z kilkoma osobami.

**Wynik: pomysł zablokował się na starcie.** Zbyt szeroka dyskusja, zbyt dużo
perspektyw naraz, brak wspólnego języka. Ludzie wychodzili z różnymi wyobrażeniami
tego co „SOC" oznacza. Energia się rozwiała.

**Lesson learned:** szerokie burze mózgów zabijają wczesne pomysły infrastructure capability.
Najpierw small-circle incubation — potem rozszerzenie → patrz [[INCUBATION_STRATEGY]].

### Trigger 2 — ból operacyjny (bottom-up)

Niezależnie od powyższego, pojawił się **realny ból operacyjny**:

- **AWS Health events** docierały spóźnione lub w ogóle nie docierały do właściwych
  osób w Cloud Support Team
- Powiadomienia o maintenance windows, service degradation, planned actions
  były niewidoczne w codziennym workflow
- Brak automatycznego tworzenia ticketów w GLPI dla zdarzeń chmurowych

**Rozmowa z technical managerem** (DevOps/Cloud) doprowadziła do konkretnego pomysłu pilota:
integracja AWS Health → GLPI Problems, żeby cloud events automatycznie
trafiały do istniejącego ITSM workflow.

To było pierwsze zdarzenie gdzie hipoteza nabrała kształtu operacyjnego, nie strategicznego.

---

## Working hypothesis

> Nie budować „SOC" od razu. Zacząć od capability, którą sami zjemy.

Zamiast „budujemy SOC", myśleć trójwymiarowo:

| Warstwa | Co robimy | Narzędzie/mechanizm |
|---------|-----------|---------------------|
| **Prevent** | Standaryzacja i governance przed incydentem | LLZ (tagging, scaffold, observability baseline) |
| **Detect** | Korelacja zdarzeń, anomalie, findings | Wazuh + AWS findings (GuardDuty, Security Hub, Health) |
| **Respond** | Zarządzanie incydentem, eskalacja, dowód | GLPI Problems + on-call workflow |

Cały model opiera się na **istniejących komponentach** — nie wymaga zakupu ani budowy
nowych systemów od zera. Hipoteza brzmi: te trzy warstwy już istnieją w rudymentarnej formie;
trzeba je połączyć i zhardować, zanim pomyśli się o ofercie dla klientów.

---

## Odróżnienie: SOC enterprise vs SOC-lite capability

| Wymiar | SOC enterprise | SOC-lite capability (nasza hipoteza) |
|--------|----------------|--------------------------------------|
| Zakres | Pełne monitorowanie bezpieczeństwa 24/7, SIEM, SOC analysts | CloudOps + security findings triage dla własnego środowiska |
| SIEM | Dedykowany (Splunk, Sentinel, QRadar...) | Wazuh jako punkt korelacji + AWS native findings |
| Personel | Dedykowani analitycy SOC | Istniejący Cloud Support Team z rozszerzonymi capability |
| Klient | Klienci zewnętrzni od razu | Najpierw sami dla siebie (dogfooding) |
| Inwestycja | Duża, wielomiesięczna | Minimalna — integracje na istniejącym stacku |
| Ryzyko | Wysokie | Niskie — pilot jest reversible |

### Cloud Support extension, nie security-only initiative

Kluczowe założenie: **to jest rozszerzenie modelu Cloud Support 24/7**, nie osobna
inicjatywa bezpieczeństwa. Gdybyśmy zaczęli od narracji „robimy SOC" — natychmiast
pojawia się pytanie o compliance, certyfikacje (ISO 27001, SOC 2), dedykowany zespół.

Zamiast tego: **robimy Cloud Support lepszym** przez:
- lepszą widoczność cloud events (AWS Health → GLPI)
- aktywne wykrywanie zamiast reaktywnego reagowania
- dowód incydentowy w istniejącym ITSM

Jeśli to zadziała — wtedy można rozmawiać o brandingu jako capability dla klientów.

---

## Open questions

- [ ] Czy Head of Cloud i CEO są na tym samym poziomie definicji „SOC"? Czy pytanie CEO było o security-only czy o CloudOps maturity?
- [ ] Czy technical manager, który zaproponował GLPI integration, ma bandwidth na pilota?
- [ ] Czy Wazuh jest wystarczająco dojrzały jako correlation engine dla AWS findings, czy potrzebujemy dodatkowego gluecode?
- [ ] Jaki jest minimalny PoC, który można pokazać w ciągu 2–4 tygodni?
- [ ] Czy GLPI Problems workflow jest wystarczająco dopasowany do cloud incident model, czy wymaga rozszerzenia?
- [ ] Czy on-call coverage jest wystarczająca do Respond layer — czy to gap do adresowania osobno?

---

## Risks / anti-patterns

- **Anti-pattern:** próba budowania „ServiceNow replacement" — GLPI ma ograniczenia,
  nie próbować ich przezwyciężyć zamiast pilota
- **Anti-pattern:** zacznij od zewnętrznych klientów — bez dogfooding najpierw
- **Anti-pattern:** certyfikacja SOC 2 / ISO jako warunek startu — to bloker, nie cel
- **Risk:** GLPI nie ma natywnego AWS integration — wymaga gluecode (Lambda/webhook),
  co jest małym ale realnym tech debt
- **Risk:** Wazuh może generować false positives dla AWS findings — potrzebny tuning,
  który wymaga czasu

---

## Powiązane notatki

- [[EXISTING_CAPABILITIES_AS_FOUNDATION]] — mapa istniejących komponentów
- [[PILOT_IDEA_GLPI_CLOUD_EVENTS]] — minimalny pilot
- [[INCUBATION_STRATEGY]] — strategia inkubacji bez zabijania pomysłu
- [[CONNECTION_TO_LLZ_AND_NIS2]] — powiązania z LLZ i regulacjami
- [[../../cloud-support-as-a-service/service-vision|Cloud Support — wizja usługi]]
- [[../../cloud-support-as-a-service/operating-model|Cloud Support — model operacyjny]]
- [[../llz/context|LLZ — Light Landing Zone]]
- [[../../../10-areas/observability/README|Observability area]]
