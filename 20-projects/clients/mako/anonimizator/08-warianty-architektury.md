# Warianty architektury

## Wariant A: local-first + external LLM po anonimizacji

Opis: ingest, ekstrakcja, detekcja, tokenizacja i mapowanie działają lokalnie. Do zewnętrznego LLM trafia tylko materiał zanonimizowany.

Zalety:
- ogranicza ekspozycję danych klienta,
- pozwala korzystać z jakości zewnętrznych modeli,
- dobry kompromis dla PoC,
- łatwiej audytować granicę eksportu.

Wady:
- nadal istnieje ryzyko false negative,
- wymaga solidnego kontraktu dla LLM,
- trzeba zabezpieczyć mapowanie tokenów,
- jakość odpowiedzi zależy od zachowania semantyki po anonimizacji.

Poziom bezpieczeństwa: średni/wysoki, zależnie od jakości detekcji i kontroli eksportu.

Złożoność wdrożenia: średnia.

Złożoność utrzymania: średnia.

Sensowność dla PoC: wysoka.

## Wariant B: fully local

Opis: cały pipeline, włącznie z modelem LLM, działa lokalnie lub w kontrolowanym środowisku bez zewnętrznego outbound.

Zalety:
- najmocniejsza kontrola danych,
- mniejsze ryzyko wysyłki do zewnętrznych usług,
- prostsza argumentacja bezpieczeństwa.

Wady:
- jakość lokalnych modeli może być niższa,
- większe wymagania sprzętowe,
- utrzymanie modeli i runtime jest osobnym kosztem,
- trudniej korzystać z najnowszych modeli komercyjnych.

Poziom bezpieczeństwa: wysoki, jeśli środowisko lokalne jest poprawnie zabezpieczone.

Złożoność wdrożenia: średnia/wysoka.

Złożoność utrzymania: średnia/wysoka.

Sensowność dla PoC: średnia, dobra jako ścieżka porównawcza.

## Wariant C: hybrydowy z orkiestracją

Opis: lokalny pipeline anonimizacji, kontrolowany eksport, integracja z wieloma modelami, workflow zatwierdzeń, audyt, role i polityki.

Zalety:
- docelowo najbardziej kompletne podejście,
- wspiera role i akceptacje,
- możliwy wybór modelu według polityki,
- lepszy audyt procesu.

Wady:
- zbyt duży zakres na start,
- dużo decyzji organizacyjnych,
- ryzyko zbudowania platformy zanim problem zostanie potwierdzony,
- większy koszt utrzymania.

Poziom bezpieczeństwa: potencjalnie wysoki, ale zależy od jakości implementacji procesu.

Złożoność wdrożenia: wysoka.

Złożoność utrzymania: wysoka.

Sensowność dla PoC: niska jako pierwszy krok; dobra jako kierunek późniejszy.

## Rekomendacja robocza

Najbardziej sensowny na start wydaje się wariant A: local-first z kontrolowanym eksportem zanonimizowanej treści.

Powód: pozwala szybko sprawdzić wartość i ryzyka bez budowy pełnego workflow engine. Wariant fully local warto zostawić jako porównanie bezpieczeństwa i jakości. Wariant hybrydowy traktować jako możliwy kierunek po PoC.
