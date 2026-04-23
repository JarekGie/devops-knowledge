# Notatki robocze

## Obserwacje

- Problem jest bardziej o kontroli procesu niż o samym endpointcie API.
- Regexy będą konieczne dla sekretów i infrastruktury, ale nie wystarczą dla danych domenowych.
- Mapowanie tokenów jest najwrażliwszym artefaktem całego procesu.
- Warto rozdzielać anonimizację od rehydratacji.

## Hipotezy

- Local-first z ręcznym eksportem wystarczy do pierwszego PoC.
- Największym źródłem false negative będą dokumenty półstrukturalne: PDF, DOCX, XLSX.
- Największym kosztem utrzymania będą custom recognizery dla danych domenowych.
- Wariant fully local może być potrzebny dla klientów lub dokumentów o wyższej klasyfikacji.

## Rzeczy do sprawdzenia

- Czy MakoLab ma formalną politykę użycia zewnętrznych LLM.
- Czy zanonimizowany dokument nadal podlega ograniczeniom klienta.
- Czy Vault jest wymagany dla mapowania tokenów.
- Czy istnieją reprezentatywne sztuczne dokumenty testowe.
- Jak Presidio radzi sobie z językiem polskim i dokumentami technicznymi.
- Jak zachować strukturę tabel przy anonimizacji.

## Pomysły architektoniczne

- Każdy run ma własny namespace tokenów.
- Tokeny powinny być typowane: `SECRET_`, `PERSON_`, `HOST_`, `SERVICE_`.
- Pipeline powinien generować raport detekcji przed eksportem.
- Rehydratacja powinna być osobną akcją z audytem.
- Warto mieć tryb dry-run bez eksportu do LLM.

## Decyzje odłożone

- CLI vs lokalny web UI.
- PostgreSQL vs pliki lokalne na PoC.
- Vault od pierwszej wersji vs później.
- Model ręcznie wybierany vs policy-based.
- Czy PoC może używać realnych dokumentów po ręcznym oczyszczeniu.

## Miejsce na dalsze notatki

-
