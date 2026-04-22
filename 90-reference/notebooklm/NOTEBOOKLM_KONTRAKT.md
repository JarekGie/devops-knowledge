# NOTEBOOKLM_KONTRAKT

## Kontrakt operacyjny NotebookLM

## Rola

NotebookLM sluzy do:

DOPUSZCZALNE:

- synteza zrodel
- contradiction check
- gap analysis
- pattern extraction
- artifact generation
- przygotowanie briefingow i map zaleznosci

NIEDOPUSZCZALNE:

- source of truth dla live state
- zatwierdzanie zmian produkcyjnych
- destructive runbooks bez walidacji czlowieka
- decyzje apply/rollback bez weryfikacji w IaC i runtime

## Zasada jezyka

DOMYSLNY JEZYK WSZYSTKICH TWORZONYCH ARTEFAKTOW:
POLSKI

Dotyczy:

- odpowiedzi na ask
- raportow
- flashcards
- quizow
- mind maps (etykiety)
- slide decks
- data tables (naglowki)
- notatek zapisywanych do vault

### Regula

Jesli uzytkownik nie wskaze wyraznie innego jezyka:

- tworz wszystko po polsku
- zachowuj polska terminologie techniczna, gdy naturalna
- nazwy AWS/CLI pozostawiaj oryginalne

### Override

Inny jezyk jest dopuszczalny tylko wtedy, gdy prompt jawnie zawiera override, na przyklad:

- respond in English
- generate report in English
- output for customer in English

Wtedy tylko dany artefakt moze byc przygotowany w innym jezyku.

## Prompt safety contract

Dla promptow analitycznych preferowany wzorzec:

```text
Oddziel:
- fakty potwierdzone
- hipotezy
- sprzecznosci
- luki

Nie zgaduj.
Opieraj sie wylacznie na zrodlach.
Oznacz slabo wspierane twierdzenia.
```

To powinno byc domyslne dla wszystkich promptow analitycznych.

## Provenance rule

Kazdy artefakt z NotebookLM powinien miec metadane:

```yaml
notebook:
  created_from: Runtime-Incidents
  generated: 2026-04-22
  sources:
    - 20-projects/clients/mako/pbms/context.md
    - 40-runbooks/incidents/planodkupow-qa-postmortem.md
  reviewed_by_human: true
  status: draft
```

Bez provenance artefakt nie trafia do `findings/`.

## Artifact review gate

Przed przeniesieniem do findings sprawdz:

- czy model nie przesadzil z uogolnieniem (`always`, `never`)
- czy cytowane fakty rzeczywiscie sa w zrodlach
- czy recommendations nie sa halucynowane

Dopiero po review artefakt moze zostac awansowany do findingu.

## Notebook typy

### Runtime-Incidents

cross-project incident synthesis

### LLZ-Controls

kontrolki, guardrails, governance patterns

### FinOps-Reference

referencyjne analizy kosztowe

### CloudFormation-Recovery

RCA + recovery primitives

## Naming convention

Artefakty zapisuj deterministycznie:

```text
YYYY-MM-DD-briefing-v1.md
YYYY-MM-DD-mind-map.json
YYYY-MM-DD-gap-analysis.md
```

## Minimalny workflow

```text
1. Curated sources -> NotebookLM
2. Ask / contradiction / gap analysis
3. Generate artifact
4. Download to artifacts/
5. Human review
6. Promote distilled insights into findings/
```

Dopiero findings moga wplywac na runbooki.

## Bardzo wazna zasada

```text
assist reasoning
never replace verification
```
