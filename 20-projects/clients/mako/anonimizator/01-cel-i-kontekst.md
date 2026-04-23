# Cel i kontekst

## Kontekst

To jest robocze uporządkowanie pomysłu Tomka dotyczącego lokalnego anonimizatora dokumentów klientów przed użyciem LLM.

Główna intencja: umożliwić bezpieczniejszą pracę z zewnętrznymi modelami językowymi na materiale pochodzącym z dokumentacji klienta, bez wysyłania danych wrażliwych w formie jawnej.

## Cel

Celem nie jest zbudowanie finalnego systemu od razu. Celem jest zrozumienie:
- jakie dane mogą pojawiać się w dokumentach,
- co musi zostać wykryte lokalnie,
- co powinno zostać zastąpione tokenem,
- jak przechowywać mapowanie tokenów,
- jak rehydratować odpowiedź modelu,
- jakie decyzje bezpieczeństwa i operacyjne są wymagane.

## Typy dokumentów

Dokumenty mogą mieć różne formaty:
- tekst zwykły,
- Markdown,
- PDF,
- DOCX,
- XLSX,
- CSV,
- skrypty,
- Terraform,
- YAML / JSON,
- pliki konfiguracyjne,
- logi,
- fragmenty dokumentacji architektonicznej.

Obsługa wszystkich formatów na starcie nie jest założeniem. To wymaga osobnej decyzji zakresowej.

## Wymagany lokalny etap

Minimalny sensowny przepływ:
1. Lokalny ingest dokumentu.
2. Lokalna ekstrakcja tekstu i struktury.
3. Lokalna detekcja danych wrażliwych.
4. Lokalna tokenizacja / anonimizacja.
5. Zapis mapowania oryginał -> token.
6. Eksport wyłącznie materiału zanonimizowanego do LLM.
7. Rehydratacja odpowiedzi, jeśli jest zatwierdzona i potrzebna.

## Status

To nie jest gotowy projekt wdrożeniowy. To przestrzeń do uporządkowania problemu, wariantów i ryzyk przed decyzją o PoC.

## Do ustalenia

- Czy pierwszym interfejsem ma być CLI, lokalny web UI czy mała usługa.
- Czy mapowanie tokenów ma być trzymane lokalnie, w bazie, czy w Vault.
- Czy eksport do zewnętrznego LLM wymaga osobnej akceptacji człowieka.
- Jakie dokumenty są reprezentatywne dla pierwszego PoC.
