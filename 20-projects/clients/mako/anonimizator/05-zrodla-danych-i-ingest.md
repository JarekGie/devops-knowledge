# Źródła danych i ingest

## Możliwe źródła wejścia

Potencjalne źródła dokumentów:
- ręczny upload plików,
- lokalny katalog roboczy,
- repozytorium Git,
- system ticketowy,
- skrzynka mailowa,
- share plikowy,
- eksport z Confluence / SharePoint,
- paczka ZIP od klienta,
- logi lub artefakty diagnostyczne.

Status rzeczywistych źródeł: Do ustalenia.

## Tryb manualny

Użytkownik wybiera pliki lokalnie i uruchamia pipeline.

Zalety:
- najprostszy do PoC,
- najmniej integracji,
- łatwiej kontrolować zakres danych,
- prostszy audyt eksperymentu.

Wady:
- ręczna praca,
- ryzyko pomyłki w wyborze plików,
- brak automatycznej synchronizacji z systemami źródłowymi.

## Tryb półautomatyczny

System przetwarza pliki z ustalonego katalogu lub paczki eksportowej.

Zalety:
- nadal prosty,
- powtarzalny,
- łatwiejszy do automatyzacji w PoC.

Wady:
- trzeba kontrolować kto i co wrzuca do katalogu,
- potrzebna polityka czyszczenia danych,
- katalog roboczy może stać się nieformalnym storage danych klienta.

## Tryb zintegrowany

Integracje z repo, ticketingiem, mailem lub share.

Zalety:
- docelowo wygodne,
- mniej ręcznej pracy,
- możliwy audyt źródła.

Wady:
- większa powierzchnia ryzyka,
- więcej uprawnień,
- konieczność obsługi wielu API i formatów,
- trudniejsze testowanie.

## Minimalny sensowny start dla PoC

Na start najlepiej ograniczyć wejście do ręcznego uploadu kilku sztucznych plików testowych.

Minimalny zestaw:
- 1 plik Markdown / TXT,
- 1 PDF tekstowy,
- 1 DOCX,
- 1 XLSX,
- 1 plik techniczny typu Terraform/YAML/JSON.

Nie zaczynać od mail ingestion ani skanowanych PDF jako domyślnej ścieżki.

## Do ustalenia

- Czy dokumenty testowe mogą być syntetyczne.
- Czy PoC może użyć fragmentów realnych dokumentów po ręcznym oczyszczeniu.
- Czy zanonimizowane wyniki mają być zapisywane na dysku.
