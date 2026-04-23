# Utrzymanie i koszt złożoności

## Co będzie tanie i proste

Relatywnie proste:
- mały lokalny pipeline CLI,
- ręczny upload plików,
- podstawowe regexy dla sekretów i identyfikatorów cloud,
- zapis prostych metadanych runu,
- ręczna rehydratacja na małej próbce,
- testowe prompty dla LLM.

## Co będzie drogie i trudne

Trudne elementy:
- jakość detekcji dla wielu formatów,
- obsługa PDF/DOCX/XLSX bez utraty struktury,
- detekcja danych domenowych klienta,
- rozpoznawanie zależności architektonicznych bez niszczenia sensu,
- bezpieczne mapowanie tokenów,
- kontrola dostępu do rehydratacji,
- audyt bez logowania danych wrażliwych,
- utrzymanie custom recognizerów.

## Gdzie powstanie dług utrzymaniowy

Dług powstanie głównie w:
- regułach detekcji,
- wyjątkach per format,
- słownikach domenowych,
- test corpus,
- integracjach ingestu,
- politykach per klient,
- obsłudze false positive i false negative.

## Najbardziej kruche elementy

Najbardziej kruche:
- parsery dokumentów,
- OCR,
- rozpoznawanie nazw własnych,
- regexy dla sekretów podobnych do zwykłego tekstu,
- rehydratacja tekstu po zmianach modelu,
- zachowanie tabel i bloków kodu.

## Rozpoznawanie danych domenowych

Dane domenowe będą wymagały strojenia, bo nie zawsze mają format techniczny.

Przykłady:
- nazwa klienta,
- kod projektu,
- nazwa systemu,
- nazwa vendorowego produktu,
- nazwa kampanii,
- nazwa środowiska.

Tego nie da się stabilnie rozwiązać tylko ogólnym modelem PII.

## Podsumowanie

Największy koszt nie leży w samym API czy UI. Największy koszt leży w jakości detekcji, politykach bezpieczeństwa i kontroli procesu.
