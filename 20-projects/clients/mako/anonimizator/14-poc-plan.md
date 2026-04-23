# PoC plan

## Cel PoC

Sprawdzić, czy lokalna anonimizacja dokumentów pozwala bezpiecznie przekazać materiał do LLM i uzyskać użyteczną odpowiedź bez oczywistych przecieków danych wrażliwych.

## Zakres PoC

PoC obejmuje:
- kilka sztucznych dokumentów testowych,
- jeden pipeline: wejście -> ekstrakcja -> anonimizacja -> wysyłka do testowego LLM -> odpowiedź -> rehydratacja,
- ręczny wybór modelu,
- ręczną akceptację eksportu,
- podstawowy audyt runu.

PoC nie obejmuje:
- automatycznego mail ingestion,
- integracji z repozytoriami,
- integracji z ticketingiem,
- masowej obróbki dokumentów,
- pełnej klasyfikacji DLP,
- enterprise workflow engine.

## Dokumenty testowe

Przygotować syntetyczne dokumenty:
- Markdown z opisem architektury,
- PDF tekstowy z tabelą kontaktów i systemów,
- DOCX z opisem procesu,
- XLSX z listą systemów / właścicieli / środowisk,
- Terraform/YAML z udawanymi sekretami i identyfikatorami.

## Pipeline PoC

1. Upload lub wskazanie plików lokalnych.
2. Ekstrakcja tekstu i podstawowej struktury.
3. Detekcja danych wrażliwych.
4. Podmiana na tokeny.
5. Zapis mapowania.
6. Preview materiału po anonimizacji.
7. Ręczna akceptacja eksportu.
8. Wysyłka do testowego LLM.
9. Odbiór odpowiedzi.
10. Rehydratacja lokalna.
11. Ocena wyniku.

## Metryki sukcesu PoC

- liczba wykrytych encji per klasa,
- liczba false negative znalezionych ręcznie,
- liczba false positive niszczących sens,
- czy odpowiedź LLM jest użyteczna,
- czy placeholdery zostały zachowane,
- czy rehydratacja działa deterministycznie,
- czas ręcznego review.

## Warunki uznania PoC za obiecujący

PoC jest obiecujący, jeśli:
- brak oczywistych przecieków w zanonimizowanym materiale,
- rehydratacja działa poprawnie,
- sens dokumentu jest zachowany,
- LLM daje sensowną odpowiedź na materiale po anonimizacji,
- operator rozumie, co zostało zanonimizowane,
- proces da się audytować bez logowania raw danych.

## Konkret do przygotowania przed startem

- 5 sztucznych dokumentów testowych.
- Lista klas danych dla pierwszej detekcji.
- Minimalny regex/custom recognizer pack.
- Jeden prompt systemowy dla LLM.
- Jedna formatka raportu z runu.
