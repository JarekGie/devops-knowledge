---
title: CloudOps/SOC-lite — strategia inkubacji
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

# Strategia inkubacji — CloudOps/SOC-lite

> [!warning] STATUS: HIPOTEZA / EXPLORACJA
> Ta notatka dokumentuje obserwację o tym jak NIE zabijać wczesnych pomysłów.
> Nie jest prescriptive roadmapą.

---

## Kluczowa obserwacja

**Szerokie burze mózgów zabijają infrastructure capability pomysły.**

Kiedy pytanie brzmi „czy jesteśmy w stanie wystawić SOC?" i zapraszamy 6–8 osób
do brainstormu bez wspólnej definicji pojęć — efektem jest:

- każdy wychodzi z innym wyobrażeniem SOC (security-only? cloudops? 24/7 monitoring?)
- energia się rozwiewa w dyskusji o scope zamiast skupiać się na problemie
- ludzie bez operational context próbują definiować wymagania dla capability,
  której nie używają
- brak „właściciela" pomysłu → nikt nie ciągnie go dalej po spotkaniu

**Zaobserwowany wzorzec porażki:**
```
Top-down idea → Broad meeting → Scope sprawling → Energy dissipation → Idea dies
```

**Wzorzec sukcesu (hipoteza):**
```
Operational pain → Small-circle → Working prototype → Dogfooding → Expansion
```

---

## Zasada: capability musi być używana przez własny zespół najpierw

Nie ma sensu budować SOC-lite dla klientów, jeśli my sami:
- nie używamy AWS Health systematycznie
- nie mamy centralnego widoku na GuardDuty findings
- nie mamy procesu od cloud event do GLPI Problem

**Dogfooding nie jest opcją — jest warunkiem koniecznym.**

Jeśli po 4 tygodniach pilotu Cloud Support Team powie „to nie wnosi wartości" — hipoteza
jest sfalsyfikowana i dobrze wiemy to szybko, bez dużych inwestycji.
Jeśli powie „to nam naprawdę pomaga" — mamy podstawę do rozszerzenia.

---

## Zasada: adoption before branding

Nie nazywaj tego „SOC" na zewnątrz dopóki nie masz:
1. działającego pilota używanego przez własny team
2. zrozumienia co faktycznie dostarczasz (nie co chcesz dostarczać)
3. choćby jednego klienta-pilota, który widzi wartość

Przedwczesne branding jako „SOC" tworzy oczekiwania (certyfikacje, 24/7 analysts,
compliance frameworks), których nie spełnisz na wczesnym etapie.

**Working name podczas inkubacji:** CloudOps visibility capability.  
**Docelowy branding:** do ustalenia po pilotcie.

---

## Trzy fazy

### Phase 1 — Dogfooding (teraz)

**Czas:** 4–8 tygodni  
**Scope:** tylko Cloud Support Team, tylko internal accounts  
**Cel:** odpowiedź na pytanie „czy to faktycznie pomaga nam operować lepiej?"

| Co robimy | Czego nie robimy |
|-----------|-----------------|
| Pilot AWS Health → GLPI Problems | Branding zewnętrzny |
| GuardDuty → Wazuh (jeśli Wariant B gotowy) | Onboarding klientów |
| Iteracja na podstawie własnego doświadczenia | Budowanie pełnego SIEM |
| Dokumentacja co działa, co nie | Certyfikacje |

**Kryterium wyjścia z Phase 1:**
- Pilot działa >2 tygodnie bez interwencji
- Team używa GLPI Problems dla cloud events (nie emaila)
- Mamy listę „co chcemy dodać w następnej fazie"

---

### Phase 2 — Internal platform capability

**Czas:** 2–4 miesiące po Phase 1  
**Scope:** wszystkie internal projekty MakoLab na AWS, wybrany klient-pilot  
**Cel:** udowodnienie wartości dla szerzej rozumianego portfolio

| Co robimy | Czego nie robimy |
|-----------|-----------------|
| Rozszerzenie na więcej kont AWS | Masowy rollout |
| Security Hub jako centralne aggregator | Budowanie dedykowanego dashboardu od zera |
| Wazuh ruleset refinement | Zatrudnianie SOC analysts |
| Proste SLO dla Problem acknowledgment | Formalna oferta cennikowa |

**Kryterium wyjścia z Phase 2:**
- Widoczność cloud events dla ≥5 projektów
- Czas do acknowledgment Problem < X godzin (do ustalenia po Phase 1)
- Jeden klient zewnętrzny widzi wartość w cloud event visibility

---

### Phase 3 — Potential customer-facing service

**Czas:** 6–12 miesięcy po Phase 1 (jeśli Phase 2 waliduje hipotezę)  
**Scope:** oferta jako część Cloud Support 24/7  
**Cel:** monetyzacja lub differentiation usługi Cloud Support

| Co wchodzi w zakres | Co wymaga osobnej decyzji |
|--------------------|--------------------------|
| Cloud event visibility jako add-on do Cloud Support | Dedykowany SOC team |
| Tygodniowe/miesięczne raporty cloud health dla klientów | SOC 2 / ISO 27001 certyfikacja |
| Proactive alerting (nie reaktywny) | Pełny SIEM deployment |
| Standardowy onboarding klienta | Pricing i model biznesowy (osobna notatka) |

> [!note]
> Phase 3 jest warunkowa — zależy od walidacji Phase 1 i 2.
> Nie projektuj Phase 3 zanim Phase 1 nie działa.

---

## Jak decydować o przejściu między fazami

Nie kalendarzowo — oparte na sygnałach:

| Sygnał | Co oznacza |
|--------|-----------|
| Team aktywnie używa GLPI Problems (nie emaila) | Phase 1 sukces |
| Inny team pyta „jak wy to macie?" | Sygnał Phase 2 |
| Klient pyta o visibility na cloud events | Sygnał Phase 3 readiness |
| Team ignoruje Problems po pierwszym tygodniu | Phase 1 porażka → redesign pilota |

---

## Open questions

- [ ] Kto jest sponsorem wewnętrznym (Head of Cloud? Technical Manager?) — bez sponsora
  każda faza będzie walczyć o bandwidth
- [ ] Czy jest team, który może poświęcić 4–8h na Phase 1 pilot w ciągu 2 tygodni?
- [ ] Czy jest klient, który wyraził zainteresowanie proactive cloud health visibility?
- [ ] Jakie są KPI sukcesu Phase 1? (liczba Problemów auto-created? czas do ack?)
- [ ] Jak się to ma do roadmapy Cloud Support 24/7 — czy jest konflikt priorytetów?

---

## Risks / anti-patterns

- **Anti-pattern:** skipowanie Phase 1 bo „wiemy, że to działa" — nie wiemy;
  dogfooding jest discovery, nie formalnością
- **Anti-pattern:** duże spotkanie strategiczne po Phase 1 zanim mamy dane — najpierw
  dane, potem decyzja
- **Risk:** Phase 1 może pokazać, że GLPI nie jest właściwym narzędziem do cloud Problems —
  to cenna informacja, nie porażka inicjatywy
- **Risk:** bandwidth Cloud Support Team jest ograniczony — Phase 1 musi być małe
  żeby się zmieściło między operacyjnymi obowiązkami

---

## Powiązane notatki

- [[CLOUDOPS_SOC_LITE_HYPOTHESIS]] — geneza i working hypothesis
- [[PILOT_IDEA_GLPI_CLOUD_EVENTS]] — Phase 1 pilot szczegóły
- [[EXISTING_CAPABILITIES_AS_FOUNDATION]] — foundation dla każdej fazy
- [[CONNECTION_TO_LLZ_AND_NIS2]] — regulacyjny kontekst dla Phase 3
- [[../../cloud-support-as-a-service/service-vision|Cloud Support — wizja usługi]]
- [[../../cloud-support-as-a-service/roi-hypotheses|Cloud Support — hipotezy ROI]]
