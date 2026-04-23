# Anonimizacja, tokenizacja, rehydratacja

## Mechanizm logiczny

1. Ekstrakcja
   - pobranie tekstu i struktury z dokumentu,
   - zachowanie podstawowych informacji: akapity, tabele, nagłówki, bloki kodu.

2. Detekcja encji
   - reguły regex,
   - recognizery domenowe,
   - NER,
   - parsery specyficzne dla formatów technicznych.

3. Decyzja co anonimizować
   - zgodnie z polityką,
   - zależnie od klasy danych,
   - z możliwością ręcznej akceptacji w PoC.

4. Podstawienie tokenów
   - `SECRET_001`,
   - `HOST_014`,
   - `PERSON_003`,
   - `CLIENT_002`,
   - `SERVICE_007`,
   - `ACCOUNT_001`.

5. Zapis mapowania
   - oryginał,
   - token,
   - klasa danych,
   - lokalizacja w dokumencie,
   - confidence,
   - metoda detekcji.

6. Przekazanie materiału do LLM
   - wyłącznie wersja zanonimizowana,
   - bez mapowania,
   - z kontraktem zachowania placeholderów.

7. Odbiór wyniku
   - odpowiedź nadal zawiera tokeny,
   - model nie zgaduje wartości oryginalnych.

8. Rehydratacja
   - lokalna,
   - kontrolowana,
   - audytowana,
   - dostępna tylko dla uprawnionego operatora.

## Przykład

Przed:

```text
Service payment-api connects to postgres://user:pass@orders-db.internal:5432/orders.
Owner: Jan Kowalski <jan.kowalski@example.com>
```

Po anonimizacji:

```text
Service SERVICE_001 connects to SECRET_001.
Owner: PERSON_001 <EMAIL_001>
```

## Kluczowe ryzyka

| Ryzyko | Opis |
|---|---|
| Błędna detekcja | System nie rozpozna danych wrażliwych i wyśle je do LLM. |
| Częściowa detekcja | Zostanie ukryty tylko fragment sekretu lub identyfikatora. |
| Uszkodzenie semantyki | Po anonimizacji dokument przestanie być zrozumiały. |
| Kolizje tokenów | Dwie różne wartości dostaną ten sam token albo jedna wartość wiele tokenów. |
| Niepoprawna rehydratacja | Odpowiedź zostanie złożona z błędnymi wartościami. |
| Prompt injection | Dokument może zawierać instrukcje próbujące wymusić ujawnienie danych lub ignorowanie kontraktu. |
| Data exfiltration przez treść | Model może zostać nakłoniony do wypisania tokenów w niepożądanej formie lub próby rekonstrukcji danych. |

## Do ustalenia

- Czy mapowanie ma mieć TTL.
- Czy rehydratacja ma wymagać osobnej akceptacji.
- Czy operator widzi wszystkie wykryte encje przed eksportem.
