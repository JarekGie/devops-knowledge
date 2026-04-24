---
title: Vendorzy i wzorce architektoniczne AIOps
tags:
  - research
  - ai4devops
  - aiops
  - vendors
  - patterns
created: 2026-04-24
status: draft-scaffold
---

# Vendorzy i wzorce architektoniczne AIOps

> Interesują nas wzorce, nie reklamy.
> Dla każdego vendora: co architektonicznie *reprezentuje*, nie co *sprzedaje*.
> Wszystkie oceny są robocze i oparte na publicznej dokumentacji + community.

Powiązane: [[README]] | [[AI4DEVOPS_REFERENCE_MODEL]] | [[ITSM_AI_OPPORTUNITIES]]

---

## Jak czytać tę notatkę

Każdy vendor jest opisany przez:
- **Wzorzec architektoniczny** — co ten system faktycznie robi od środka
- **Kluczowa innowacja** — co wyróżnia architekturę
- **Słabe strony / pytania** — co jest problematyczne lub niejasne
- **Co można z tego zabrać** — idea niezależna od konkretnego produktu

---

## Dynatrace Davis

### Wzorzec architektoniczny

**Topology-aware correlation engine.**

Davis nie koreluje alertów statystycznie — buduje *topologiczny model środowiska* (Smartscape) i koreluje zdarzenia w kontekście rzeczywistych zależności serwisów.

```
[Metryki + logi + traces]
        │
        ▼
[Smartscape — dynamiczny graf zależności]
        │
        ▼
[Davis AI — korelacja + RCA na grafie]
        │
        ▼
[Problem card — jeden incydent, nie 200 alertów]
```

### Kluczowa innowacja

- Autodiscovery zależności w runtime (OneAgent) → nie potrzeba ręcznego CMDB
- Problem card: Davis agreguje do jednego zdarzenia, nie flood alertów
- Causal AI: hipoteza root cause oparta na topologii, nie samej korelacji czasowej

### Słabe strony / pytania

- OneAgent = vendor lock-in na poziomie infrastruktury
- Koszt Smartscape przy dużych środowiskach
- Black box — trudno zrozumieć dlaczego Davis podjął konkretną decyzję
- Czy topology discovery skaluje się na hybryd (on-prem + multi-cloud)?

### Co można zabrać

**Wzorzec:** *Graf zależności jako podstawa korelacji* — bez topologii, korelacja to statystyka na szumie.

---

## IBM Watson AIOps (Instana + AIOps)

### Wzorzec architektoniczny

**Multi-source aggregation + NLP dla log anomaly detection.**

Watson AIOps łączy sygnały z wielu źródeł (logi, metryki, topologia, tickety ITSM) i używa NLP do analizy logów bez wcześniejszego definiowania reguł.

```
[Logi + metryki + zdarzenia + ITSM tickety]
        │
        ▼
[Normalizacja + Feature extraction]
        │
        ▼
[Unsupervised ML — pattern matching na logach]
        │
        ▼
[Story — pogrupowane zdarzenia z hipotezą RCA]
```

### Kluczowa innowacja

- Log anomaly detection bez reguł — model uczy się normalności
- "Story" jako narracyjny widok incydentu (kontekst dla człowieka)
- Integracja z ServiceNow — zamknięta pętla (detection → ticket → resolution)

### Słabe strony / pytania

- Długi czas uczenia modelu (tygodnie dla nowego środowiska)
- NLP na logach działa dobrze dla angielskiego — co z lokalizowanymi aplikacjami?
- Integracja z non-IBM stackiem (AWS native, GCP) — jak złożona?
- Czy "Story" jest faktycznie zrozumiały dla L1 support bez treningu?

### Co można zabrać

**Wzorzec:** *Unsupervised log learning* — nie musisz definiować reguł; model uczy się co jest normalne.

---

## PagerDuty AIOps

### Wzorzec architektoniczny

**Noise reduction + incident intelligence na poziomie alert pipeline.**

PagerDuty AIOps jest wbudowany w istniejący workflow on-call — nie wymaga nowej platformy observability. Działa jako warstwa nad istniejącymi narzędziami.

```
[Alerty z N źródeł — Datadog, CloudWatch, Prometheus...]
        │
        ▼
[Event Intelligence — deduplication + grouping]
        │
        ▼
[Intelligent alert grouping — jeden incident z wielu alertów]
        │
        ▼
[Similar incidents — historia analogicznych incydentów]
        │
        ▼
[On-call workflow — routing, eskalacja, handoff]
```

### Kluczowa innowacja

- "Meets you where you are" — integruje się z istniejącymi tools bez wymiany
- Similar incidents: pokazuje jak podobne incydenty były rozwiązywane w przeszłości
- Postmortems AI-assisted: automatyczny draft postmortem z danych incydentu

### Słabe strony / pytania

- Wartość rośnie proporcjonalnie do ilości danych historycznych (problem cold start)
- Koszt vs. wartość dla małych teamów (< 5 osób on-call)
- Grouping opiera się na korelacji czasowej + contentu alertu — nie na topologii
- Jak działa dla incydentów bez poprzedników (nowa infrastruktura)?

### Co można zabrać

**Wzorzec:** *Augmentacja istniejącego workflow, nie wymiana* — AI jako warstwa nad narzędziami, nie nowe centrum dowodzenia.

---

## ServiceNow Now Assist

### Wzorzec architektoniczny

**LLM embedded w ITSM workflow — generative AI dla agentów i self-service.**

Now Assist nie jest systemem detekcji — jest AI warstwą wewnątrz ServiceNow ITSM. Skupia się na generowaniu treści i podsumowań, nie na korelacji sygnałów.

```
[Ticket / Incident otwarty w ServiceNow]
        │
        ▼
[Now Assist — LLM w kontekście danych ITSM]
        │
        ├──▶ [Summarization — podsumowanie dla agenta L2]
        ├──▶ [Resolution suggestions — podobne sprawy + KB]
        ├──▶ [Auto-response drafts — szkic odpowiedzi do klienta]
        └──▶ [Search — NL query na bazie wiedzy]
```

### Kluczowa innowacja

- LLM z kontekstem CMDB ServiceNow — model wie, co jest w grafie zasobów
- Case summarization: instant context dla agenta który przejmuje ticket
- Closed-loop: od wykrycia do zamknięcia incydentu w jednej platformie

### Słabe strony / pytania

- Pełna wartość tylko w ekosystemie ServiceNow (im więcej masz w SNow, tym lepiej)
- LLM hallucination w sugestiach resolution — bez ground truth weryfikacji
- Koszt platformy ServiceNow + Now Assist dla SME
- Jak utrzymać jakość KB który zasilacza LLM?

### Co można zabrać

**Wzorzec:** *Contextual LLM* — LLM bez kontekstu danych CMDB/ITSM daje generyczne odpowiedzi; z kontekstem jest użyteczny dla konkretnej sprawy.

---

## Moogsoft

### Wzorzec architektoniczny

**Situation-based clustering + unsupervised ML dla noise reduction.**

Moogsoft (teraz part of Dell) był pionierem podejścia opartego na "Situation" — automatycznym grupowaniu zdarzeń w semantyczne clustery bez uprzednio zdefiniowanych reguł korelacji.

```
[Events z monitoring tools]
        │
        ▼
[Noise reduction — deduplication]
        │
        ▼
[Situation clustering — ML grouping bez reguł]
        │
        ▼
[Situation room — wspólna przestrzeń pracy dla ops team]
        │
        ▼
[Learning feedback loop — człowiek potwierdza/koryguje]
```

### Kluczowa innowacja

- Unsupervised situation clustering — nie potrzeba definiowania reguł korelacji
- Feedback loop: operator koryguje clustering → model się uczy
- Situation room: kontekst incydentu w jednym miejscu dla całego zespołu

### Słabe strony / pytania

- Jak "Situation" różni się od "Alert group" po kilku tygodniach bez konfiguracji?
- Feedback loop wymaga dyscypliny operatorów — co jeśli nie ma czasu na korektę?
- Integracja z cloud-native toolchain (ECS, Kubernetes events, CloudWatch)?
- Status po przejęciu przez Dell — roadmapa produktu?

### Co można zabrać

**Wzorzec:** *Zamknięta pętla uczenia* — system AIOps który uczy się od operatorów przez feedback, nie tylko od danych historycznych.

---

## Synteza wzorców

| Wzorzec | Kto reprezentuje | Kiedy stosować |
|---------|-----------------|----------------|
| Topology-aware correlation | Dynatrace | Gdy masz pełne pokrycie observability i zależy Ci na RCA |
| Unsupervised log learning | IBM Watson | Gdy logi są głównym źródłem sygnału i nie chcesz pisać reguł |
| Alert pipeline augmentation | PagerDuty | Gdy masz dobre narzędzia alertingowe i chcesz redukować szum |
| Contextual LLM in workflow | ServiceNow | Gdy masz ITSM jako centrum i zależy Ci na agent experience |
| Feedback-loop clustering | Moogsoft | Gdy chcesz stopniowo uczyć system bez big-bang konfiguracji |

## Questions to revisit later

- Który z tych wzorców jest najbliższy temu, co [[../../60-toolkit/cloud-detective/README\|Cloud Detective]] może zbudować jako lekka capability?
- Czy open source odpowiedniki (OpenTelemetry + własny ML) są realistyczne dla małego projektu?
- Jak te wzorce sprawdzają się bez dużych danych historycznych (nowe środowisko)?
- Czy któryś z tych vendorów ma ścieżkę dla SME / boutique DevOps shop?
- Jak mierzyć skuteczność tych systemów bez ground truth labeli incydentów?

#research #ai4devops #aiops #vendors #patterns
