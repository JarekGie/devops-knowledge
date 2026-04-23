# Problem do rozwiązania

## Problem techniczny

Dokumenty klientów mogą zawierać dane, których nie wolno bezrefleksyjnie wysłać do zewnętrznego LLM:
- sekrety,
- tokeny,
- connection stringi,
- nazwy systemów,
- topologię sieci,
- dane osobowe,
- dane kontraktowe,
- dane operacyjne,
- szczegóły architektury,
- informacje o podatnościach lub incydentach.

Jednocześnie zbyt agresywna anonimizacja może zniszczyć sens dokumentu. Model powinien nadal rozumieć relacje typu: system A komunikuje się z bazą B przez komponent C, ale nie musi znać realnych nazw, adresów i sekretów.

## Problem organizacyjny

Nie wystarczy technicznie zamienić tekstu. Trzeba ustalić:
- kto odpowiada za proces,
- kto może uruchamiać anonimizację,
- kto zatwierdza eksport do LLM,
- kto może rehydratować odpowiedź,
- czy dokumenty po anonimizacji są archiwizowane,
- czy mapowania tokenów podlegają retencji,
- czy obowiązują polityki AI w MakoLab lub u klienta.

Status tych decyzji: Do ustalenia.

## Dlaczego wysyłka surowych dokumentów jest ryzykowna

Ryzyka:
- naruszenie NDA lub umowy z klientem,
- ujawnienie sekretów,
- ujawnienie topologii i zależności systemów,
- niekontrolowane utrwalenie danych w zewnętrznej usłudze,
- brak audytu kto, kiedy i co wysłał,
- trudność w późniejszym udowodnieniu zakresu ujawnionych danych.

## Dlaczego regex-only nie wystarczy

Regexy są potrzebne, ale nie wystarczą, bo:
- wiele danych wrażliwych nie ma stabilnego formatu,
- nazwy projektów i systemów są domenowe,
- PDF/DOCX/XLSX mogą rozbijać tekst i kontekst,
- ten sam ciąg może być bezpieczny albo wrażliwy zależnie od kontekstu,
- część danych jest w tabelach, nagłówkach, komentarzach albo strukturze pliku.

Regex-only będzie miał false negative i false positive. To może być element pipeline, nie jedyny mechanizm.

## Dlaczego samo LLM jako detektor też nie wystarczy

LLM jako detektor jest problematyczny, bo:
- żeby wykryć dane, musiałby zobaczyć surowy materiał,
- wynik nie jest deterministyczny,
- nie gwarantuje kompletności,
- może zostać zmanipulowany prompt injection w treści dokumentu,
- trudno oprzeć audyt bezpieczeństwa wyłącznie na deklaracji modelu.

LLM może pomagać w analizie materiału po anonimizacji albo w trybie lokalnym, ale nie powinien być jedyną granicą bezpieczeństwa.

## Trudność właściwa

Najtrudniejsze nie jest samo API. Najtrudniejsze jest połączenie:
- jakości detekcji,
- zachowania semantyki dokumentu,
- bezpieczeństwa mapowania tokenów,
- kontroli eksportu,
- audytu,
- czytelnego operating modelu.
