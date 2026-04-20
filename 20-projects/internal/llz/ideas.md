---
type: ideas-backlog
updated: 2026-04-20
tags: [llz, architecture, toolkit, org-audit, plugin-api, observability]
---

# LLZ — Idee i backlog architektoniczny

> Surowy materiał do przyszłych sesji implementacyjnych. Zapisuj tu pomysły zanim trafią do kodu.
> Format: problem → idea → dlaczego warto → ryzyko → status.

## Dokumentacja LLZ — zrobić raz, pod AWS review

**Decyzja (2026-04-20):** Dokumentacja LLZ ma być przygotowana od razu z myślą o AWS Competencies i Well-Architected Framework review — nie jako dokumentacja wewnętrzna do późniejszego przepisania.

**Dlaczego:** Jeśli kiedykolwiek będzie review z AWS SA (Partner Program, WAFR), przepisywanie od zera to podwójna robota i ryzyko niespójności.

**Co oznacza w praktyce:**
- Struktura zgodna z Well-Architected pillars (Operational Excellence, Security, Reliability, Performance, Cost, Sustainability)
- Każda decyzja architektoniczna udokumentowana jako ADR z uzasadnieniem
- Dowody wdrożenia (screenshots, terraform outputs, policy ARNs) jako artefakty
- Gap analysis z mapowaniem do konkretnych WAF best practices

**Status:** Backlog — zaczynamy gdy LLZ Faza B ruszy lub będzie konkretna data review.

---

## IDEA-001 — Tryb organizacyjny (org-scope)

**Problem:**
Toolkit jest projektowy — jeden `project.yaml` = jeden kontekst AWS. Audyt organizacji
(N kont, cross-account) wymaga iteracji i agregacji których obecna architektura nie obsługuje.

**Idea:**
Nowy scope `org` obok obecnego `project`. Komenda `toolkit org-audit` iteruje po kontach
organizacji (Organizations API), zakłada role (`sts:AssumeRole` per konto), uruchamia
istniejące audit-packi per konto, agreguje wyniki.

```
toolkit org-audit tagging       # tagging coverage dla całej org
toolkit org-audit aws-logging   # observability gaps per konto
toolkit org-audit llz-basic     # LLZ compliance per projekt
```

**Dlaczego warto:**
- Jeden raport dla zarządu/compliance zamiast N ręcznych uruchomień
- Identyfikacja outlierów (konto bez tagów, bez logów) bez ręcznej pracy
- Naturalny driver: AWS competency, ISO27001, audyty klientów

**Ryzyko:**
- Throttling API przy dużej liczbie kont — wymaga rate limiting
- `sts:AssumeRole` musi być skonfigurowany per konto (nie zawsze jest)
- Aggregacja wyników to nietrywialny problem (format, deduplication)

**Status:** Idea — nie zaczęte. Driver: AWS competency + org governance.

---

## IDEA-002 — Plugin API jako publiczny kontrakt

**Problem:**
Toolkit ma wewnętrzny system pluginów (używany przez LLZ). Nie jest sformalizowany
jako publiczne API — kontrakt jest de facto (BasePlugin), nie explicite.

**Idea:**
Sformalizuj `BasePlugin` jako wersjonowany kontrakt z dokumentacją:
- jasno zdefiniowany interfejs wejście/wyjście
- versioned API (`plugin_api_version: "1"` w `plugin.py`)
- pluginy zewnętrzne mogą być rejestrowane bez modyfikacji core

```python
class MyPlugin(BasePlugin):
    api_version = "1"
    def run(self, context: ProjectContext) -> PluginResult: ...
```

**Dlaczego warto:**
- Każdy devops może dodać plugin bez znajomości internals toolkitu
- LLZ plugins, org plugins, client-specific plugins — ta sama podstawa
- Testowalność — plugin contract jest jasny, mock context jest prosty

**Ryzyko:**
- Przedwczesna generalizacja — publiczne API ma sens przy 3+ zewnętrznych konsumentach
- Utrzymanie backwards compatibility po formalnym ogłoszeniu kontraktu
- Teraz mamy wewnętrzne użycie — konwencja może wystarczyć

**Status:** Idea — nie zaczęte. Warunek: poczekaj na 2-3 nowe pluginy external.

---

## IDEA-003 — Scope model: project vs org

**Problem:**
Obecne pluginy dostają kontekst jednego projektu. Org-audit wymaga innego kontekstu
(org-level). Te dwa modele nie mogą dzielić tego samego plugin contract bez komplikacji.

**Idea:**
Wprowadź explicit `scope` do kontekstu pluginu:

```
toolkit/
  core/
    engine/          ← obecny, stabilny
    plugin-api/      ← sformalizowany BasePlugin
  scope/
    project/         ← ProjectContext (obecny: project.yaml + lokalne pliki)
    org/             ← OrgContext (nowy: Organizations API + N kont)
```

Plugin deklaruje obsługiwany scope. Org orchestrator może reużywać project-scope
pluginy per konto (wywołuje je w pętli z OrgContext→ProjectContext per konto).

**Dlaczego warto:**
- Org-audit korzysta z istniejących audit-packów bez duplikacji kodu
- Jeden plugin = jedna odpowiedzialność, działa w obu scopach
- Czysta separacja: orchestrator = iteracja + aggregacja, plugin = analiza

**Ryzyko:**
- Musi być zaprojektowane przed implementacją IDEA-001 i IDEA-002 — inaczej rebuild
- Context serialization/deserialization między scopami może być nietrywialny

**Status:** Idea — blokuje IDEA-001. Design decision przed kodowaniem.

---

## IDEA-004 — Confluence jako publish target (LLM wiki pattern)

**Problem:**
Drafting dokumentów do Confluence jest powolny bez AI-assist. Screenshoty i linki
zewnętrzne nie są częścią workflow LLM.

**Idea:**
Vault Obsidian = przestrzeń robocza + LLM wiki (Karpathy pattern).
Confluence = publish target, nie workspace.

Workflow:
1. Draft + burza mózgów tutaj (AI-assist, screenshoty jako kontekst)
2. Screenshoty wklejane bezpośrednio w rozmowie → Claude czyta → wiedza do notatki
3. Gotowy dokument → publikacja przez MCP Atlassian (jest podłączony)

**Dlaczego warto:**
- Vault staje się LLM-friendly knowledge base — każda sesja zaczyna się z kontekstem
- Confluence dostaje polished output zamiast draft
- Screenshoty stają się częścią procesu (nie blokerem)

**Status:** Częściowo zaimplementowane (vault struktura gotowa). MCP Atlassian dostępny.

---

## IDEA-005 — Observability onboarding dla istniejących projektów CFN

**Problem:**
Projekty CloudFormation (np. rshop) nie mają ALB access logs, CloudFront logging,
VPC Flow Logs. Toolkit wykrywa luki (`audit-pack aws-logging`) ale nie może ich
automatycznie naprawić przez Terraform (projekt jest w CFN, nie TF).

**Idea:**
Dla projektów CFN: toolkit generuje patch plan jako **CFN template diff** (nie Terraform).
Operator dostaje konkretne zmiany do `alb.yml`, `cf.yml` etc. gotowe do wklejenia.

Długoterminowo: migracja kluczowych projektów CFN do Terraform → toolkit może
automatycznie aplikować zmiany przez `aws-logging-patch-plan`.

**Status:** Backlog. rshop: ALB+CF logging ~$5/mies., VPC Flow Logs do przemyślenia.
Szczegóły: `20-projects/clients/mako/finops-rshop.md`.

---

## IDEA-006 — SLA/SLO baseline z CloudWatch

**Problem:**
Brak formalnych SLO dla projektów klientów. Metryki są w CloudWatch ale nikt
ich nie agreguje w zdefiniowane cele.

**Idea:**
Toolkit capability: `toolkit audit-pack slo-baseline` — czyta CloudWatch metryki
(ALB RequestCount, 5xx rate, TargetResponseTime) i generuje:
- obecny baseline availability (ostatnie 30 dni)
- proponowane SLO (np. 99.5% availability, p50 latency <200ms)
- error budget (ile "downtime" zostało w miesiącu)

**Ograniczenia:**
- Latency p95/p99 niedostępne bez ALB access logs
- Per-endpoint breakdown niedostępny bez access logs
- Availability SLO: TAK z CloudWatch. Latency SLO: tylko średnia.

**Status:** Idea — nie zaczęte. Wymaga ALB access logs dla pełnego SLO.

---

## Decyzje architektoniczne do podjęcia

| Decyzja | Opcje | Status |
|---------|-------|--------|
| Kiedy sformalizować plugin API? | teraz / po 3+ external plugins / nigdy | Otwarta |
| Scope model — kiedy projektować? | przed IDEA-001 / razem z IDEA-001 | Otwarta |
| CFN vs TF dla nowych projektów rshop? | zostać na CFN / migrować do TF | Otwarta |
| Org-audit driver — co go wyzwoli? | AWS competency / klient / compliance | Otwarta |
