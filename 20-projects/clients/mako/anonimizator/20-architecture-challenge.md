# Architecture challenge

To jest krytyczny przegląd koncepcji. Celowo zakłada, że część założeń może być błędna, a system może stworzyć nowe ryzyka zamiast je ograniczyć.

## 1. Założenia, które mogą być fałszywe

| Założenie | Co jeśli jest błędne | Konsekwencje |
|---|---|---|
| Anonimizacja jest wystarczająca, żeby bezpiecznie wysłać dokument do LLM. | Sanitizacja usuwa tylko oczywiste dane, ale zostawia kontekst pozwalający odtworzyć klienta, system albo incydent. | Fałszywe poczucie bezpieczeństwa; realny wyciek mimo braku sekretów literalnych. |
| Placeholdery nie wyciekną semantycznie. | Tokeny typu `AWS_ACCOUNT_ID_003`, `PAYMENT_SERVICE_001` albo relacje między nimi ujawniają technologię, domenę biznesową lub topologię. | Zanonimizowany dokument nadal może być informacją wrażliwą. |
| LLM nie zrekonstruuje części danych kontekstowo. | Model zna publiczne nazwy systemów, domen, klientów, vendorów albo wzorce architektoniczne i potrafi zgadywać. | Ryzyko reidentyfikacji, szczególnie przy mało ogólnych tokenach i unikalnych opisach. |
| Mapping store da się bezpiecznie chronić. | Store trafi do logów, backupu, lokalnego dysku, eksportu debugowego albo zostanie odczytany przez nieuprawnionego operatora. | Kompromitacja mapping store oznacza pełną deanonimizację runu. |
| Rehydratacja nie tworzy nowej klasy ryzyka. | Odpowiedź LLM po rehydratacji staje się nowym dokumentem zawierającym dane klienta i rekomendacje modelu. | Powstaje artefakt o niejasnej klasyfikacji, retencji i odpowiedzialności. |
| Operator zawsze rozumie, co eksportuje. | Preview jest długie, nieczytelne albo false negative są trudne do zauważenia. | Human review staje się rytuałem, nie kontrolą. |
| Prompt systemowy wystarczy do obrony przed prompt injection. | Model mimo promptu wykonuje instrukcje ukryte w dokumencie albo miesza je z zadaniem użytkownika. | Odpowiedź może naruszać kontrakt, prosić o mapowanie albo wypisać zbyt dużo. |
| Synthetic PoC dobrze przewidzi zachowanie na realnych dokumentach. | Sztuczne dokumenty są zbyt czyste, regularne i przewidywalne. | PoC wygląda dobrze, ale system załamuje się na realnym materiale. |

## 2. Gdzie ten pomysł może się nie skalować

### Custom recognizers maintenance burden

Custom recognizery będą żyły tak długo, jak żyją formaty dokumentów, style zespołów, nazwy vendorów i technologie klientów. To nie jest jednorazowa konfiguracja.

Ryzyko:
- reguły będą rosnąć bez właściciela,
- false positive będą obchodzone ręcznie,
- false negative będą odkrywane dopiero po incydencie.

### Drift reguł

Reguły będą dryfować względem:
- nowych typów sekretów,
- nowych providerów cloud,
- nowych formatów IaC,
- nowych narzędzi klientów,
- zmian języka dokumentacji.

Jeśli nie ma test corpus i procesu wersjonowania reguł, jakość detekcji będzie spadać bez widocznego sygnału.

### False negatives przy różnych typach dokumentów

PDF, DOCX, XLSX, Markdown, logi i IaC mają inne struktury. Jedna metoda ekstrakcji nie da jednolitego wyniku.

Problem: system może wyglądać dobrze na Markdown, ale gubić dane w:
- tabelach XLSX,
- stopkach PDF,
- komentarzach Terraform,
- zmiennych w YAML,
- tekstach rozbitych przez parser.

### Problem tabel, diagramów, skanów

Tabele i diagramy niosą relacje. Sama ekstrakcja tekstu może je zniszczyć.

Skanowane PDF-y są jeszcze trudniejsze:
- OCR może błędnie odczytać sekret,
- dane mogą pozostać w obrazie,
- układ dokumentu może być częścią znaczenia.

OCR-heavy pipeline jako domyślna ścieżka nadal wygląda jak przedwczesna komplikacja dla MVP, ale brak obsługi skanów trzeba jawnie traktować jako ograniczenie.

### Vendor-specific naming chaos

Nazwy vendorów i klientów często nie mają formalnego wzorca. Mogą wyglądać jak zwykłe słowa.

Przykład problemu:
- nazwa projektu może być jednocześnie nazwą repo, hosta, konta cloud i kampanii,
- skrót klienta może być krótki i nieodróżnialny od zwykłego słowa.

### Wielojęzyczne dokumentacje

Dokumenty mogą mieszać polski, angielski i język domenowy. Detektory PII i NER mogą mieć różną jakość per język.

Ryzyko: system będzie lepszy dla angielskich dokumentów technicznych niż dla polskich notatek operacyjnych.

### IaC edge cases

Terraform, CloudFormation i skrypty mogą zawierać:
- sekrety w zmiennych,
- sekrety zakodowane w base64,
- interpolacje,
- ARNy,
- nazwy kont,
- endpointy,
- komentarze z instrukcjami,
- heredoc z konfiguracją aplikacji,
- zakomentowane stare wartości.

Skanowanie IaC wymaga parserów albo przynajmniej reguł świadomych składni. Regex-only będzie szczególnie kruche.

## 3. Czy tokenizacja może zniszczyć reasoning LLM

Istnieje fundamentalny paradoks:

Im więcej anonimizujesz, tym mniej model rozumie.

Jeśli dokument:

```text
SERVICE_001 komunikuje się z SERVICE_002 w REGION_001 przez HOST_003.
```

zastąpi zbyt wiele informacji, model może widzieć tylko graf pustych encji. Wtedy odpowiedź będzie poprawna formalnie, ale mało użyteczna.

### Punkt, w którym bezpieczeństwo zabija wartość

Taki punkt istnieje.

Objawy:
- model daje ogólne rekomendacje,
- nie rozpoznaje wzorców architektonicznych,
- nie odróżnia sekretu od zwykłego identyfikatora,
- nie widzi krytyczności komponentów,
- nie rozumie, czy mowa o dev, UAT czy prod,
- nie potrafi ocenić blast radius.

### Wniosek krytyczny

Anonimizacja nie jest monotonicznie dobra. Więcej anonimizacji nie zawsze oznacza lepszy system.

Potrzebny jest świadomy kompromis:
- co musi być ukryte zawsze,
- co może być zastąpione tokenem semantycznym,
- co można zostawić jako kontekst,
- co wymaga local-only analizy.

Jeśli takiego modelu decyzji nie ma, system będzie albo niebezpieczny, albo bezużyteczny.

## 4. Czy to powinno być raczej policy engine niż anonimizator

Alternatywna hipoteza: problemem nie jest tylko anonimizacja. Problemem jest decyzja, czy dany materiał w ogóle może opuścić lokalną granicę.

Możliwe decyzje:
- `local-only` — analiza tylko lokalnym modelem albo bez LLM,
- `allowed to export` — eksport po anonimizacji,
- `human review required` — wymagana akceptacja,
- `forbidden` — materiał nie może być eksportowany.

### Dlaczego sam anonimizator może być za prosty

Anonimizator zakłada, że większość dokumentów da się oczyścić i wysłać.

To może być błędne. Niektóre dokumenty mogą być zbyt wrażliwe, unikalne lub podatne na reidentyfikację nawet po tokenizacji.

### Policy broker jako warstwa decyzji

Policy broker mógłby brać pod uwagę:
- klasę dokumentu,
- klienta,
- typ danych wykrytych,
- confidence detekcji,
- model docelowy,
- cel użycia,
- poziom ryzyka,
- wymóg approval.

### Wniosek krytyczny

Jeśli rozwiązanie ma być używane na realnych dokumentach klientów, sam "sanitize and send" może być zbyt naiwny.

PoC może nadal zacząć od anonimizatora, ale powinien sprawdzać, czy potrzebny jest wcześniejszy gate decyzyjny.

## 5. Najbardziej niebezpieczne failure modes

### 1. False negative i eksport raw danych

Co się dzieje:
- system nie wykrywa sekretu, danych osobowych albo unikalnego identyfikatora,
- operator akceptuje eksport,
- dane trafiają do zewnętrznego LLM.

Jak dochodzi do awarii:
- parser zgubił strukturę,
- recognizer nie zna formatu,
- dane są w komentarzu albo tabeli,
- review było powierzchowne.

Blast radius:
- od pojedynczego dokumentu do pełnej dokumentacji klienta, zależnie od batcha.

Jak wykrywać:
- test corpus z seeded secrets,
- sampling manualny,
- logowanie klas detekcji bez wartości,
- porównanie wielu detektorów.

Jak ograniczać:
- małe batche,
- manual preview,
- blokada eksportu przy niskim confidence,
- local-only dla formatów wysokiego ryzyka.

### 2. Mapping store compromise

Co się dzieje:
- ktoś uzyskuje dostęp do mapowania tokenów.

Jak dochodzi do awarii:
- mapping zapisany lokalnie bez szyfrowania,
- backup,
- log debugowy,
- zbyt szerokie uprawnienia,
- brak retencji.

Blast radius:
- wszystkie dokumenty i odpowiedzi w danym runie,
- potencjalnie wiele runów, jeśli storage jest współdzielony.

Jak wykrywać:
- audyt odczytu,
- alert na export mappingu,
- brak dostępu poza procesem rehydratacji.

Jak ograniczać:
- envelope encryption,
- split access,
- TTL,
- osobne uprawnienia do rehydratacji,
- brak mapowań w logach.

### 3. Prompt injection steruje odpowiedzią LLM

Co się dzieje:
- dokument zawiera instrukcję,
- model wykonuje ją zamiast kontraktu systemowego.

Jak dochodzi do awarii:
- brak delimitera danych,
- brak skanu prompt injection,
- model myli treść dokumentu z poleceniem.

Blast radius:
- odpowiedź może zawierać żądania mapowania, pełny input, błędne instrukcje albo szkodliwe rekomendacje.

Jak wykrywać:
- walidacja odpowiedzi,
- reguły wykrywania fraz injection,
- testy adversarialne.

Jak ograniczać:
- stały system prompt,
- dokument jako quoted data,
- brak mapowania w kontekście modelu,
- blokada rehydratacji odpowiedzi naruszającej kontrakt.

### 4. Semantyczne tokeny umożliwiają reidentyfikację

Co się dzieje:
- tokeny nie ujawniają wartości, ale ujawniają wystarczająco dużo kontekstu.

Jak dochodzi do awarii:
- token zawiera typ technologii,
- opis architektury jest unikalny,
- model lub odbiorca zna klienta z publicznych informacji.

Blast radius:
- częściowa reidentyfikacja klienta, systemu lub incydentu.

Jak wykrywać:
- review zanonimizowanego dokumentu pod kątem uniqueness,
- klasyfikacja kontekstu,
- test "czy człowiek z branży zgadnie klienta".

Jak ograniczać:
- tryb tokenów ślepych dla wyższych klas ryzyka,
- uogólnianie niektórych relacji,
- policy gate przed eksportem.

### 5. Błędna rehydratacja zmienia sens wyniku

Co się dzieje:
- odpowiedź LLM zawiera zmieniony token,
- system podstawia złą wartość,
- operator otrzymuje błędny wynik.

Jak dochodzi do awarii:
- model halucynuje token,
- tokeny kolidują,
- rehydrator nie waliduje pełnej listy tokenów.

Blast radius:
- błędna rekomendacja operacyjna,
- błędna dokumentacja,
- potencjalnie zmiana w systemie na podstawie złego wyniku.

Jak wykrywać:
- walidacja tokenów przed rehydratacją,
- diff tokenów wejście/wyjście,
- blokada nieznanych tokenów.

Jak ograniczać:
- deterministic token map,
- strict rehydration mode,
- manual review po rehydratacji,
- brak automatycznego wykonania rekomendacji.
