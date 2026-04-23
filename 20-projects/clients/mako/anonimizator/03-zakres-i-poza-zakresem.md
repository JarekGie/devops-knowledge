# Zakres i poza zakresem

## W zakresie

Na start w zakresie analizy i PoC:
- ingest dokumentów,
- ekstrakcja tekstu i podstawowej struktury,
- wykrywanie danych wrażliwych,
- tokenizacja / placeholdery,
- mapowanie oryginał <-> token,
- eksport do zewnętrznego LLM dopiero po anonimizacji,
- rehydratacja wyniku,
- podstawowy audyt procesu,
- ręczne zatwierdzanie krytycznych kroków,
- jawne raportowanie co zostało zanonimizowane.

## Poza zakresem na start

Poza zakresem pierwszego PoC:
- pełny enterprise workflow engine,
- OCR-heavy pipeline jako domyślna ścieżka,
- automatyczne podejmowanie decyzji biznesowych przez LLM,
- obsługa wszystkich możliwych formatów i edge-case'ów,
- pełna klasyfikacja dokumentów klasy DLP enterprise,
- automatyczny ingest z maili jako domyślna ścieżka,
- integracja z każdym repozytorium i ticketingiem,
- policy engine enterprise,
- magiczne bezpieczeństwo bez jawnych zasad i polityk,
- automatyczna rehydratacja bez kontroli dostępu.

## Granica odpowiedzialności PoC

PoC ma odpowiedzieć, czy lokalna anonimizacja i rehydratacja są technicznie sensowne dla wybranej próbki dokumentów.

PoC nie ma udowodnić pełnej zgodności organizacyjnej ani zastąpić procesu security/compliance.

## Do ustalenia

- Minimalny zestaw formatów na PoC.
- Poziom audytu wymagany od pierwszej wersji.
- Czy PoC może używać zewnętrznego LLM, czy tylko testowego lokalnego modelu.
