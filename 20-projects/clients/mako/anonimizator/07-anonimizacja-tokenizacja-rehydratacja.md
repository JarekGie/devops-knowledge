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

## Reversible vs irreversible anonymization

### Model A — reversible tokenization

Przykład:

```text
db-prod-01 -> HOST_014
```

W tym modelu system zapisuje mapowanie między oryginałem a tokenem. Odpowiedź LLM może zostać później lokalnie zrehydratowana.

Zalety:
- umożliwia odtworzenie wyniku w kontekście realnego dokumentu,
- zachowuje relacje między encjami,
- pasuje do pracy operatorskiej, gdzie odpowiedź LLM ma zostać użyta w realnym środowisku,
- pozwala wykrywać, które tokeny wróciły w odpowiedzi.

Wady:
- mapping store staje się zasobem krytycznym,
- wymaga kontroli dostępu do rehydratacji,
- wymaga audytu operacji,
- w razie wycieku mapowania anonimizacja traci sens.

Ryzyko:
- nieautoryzowana rehydratacja,
- błędne mapowanie,
- wyciek mapowania,
- zależność bezpieczeństwa od jakości storage i uprawnień.

Wpływ na architekturę:
- potrzebny storage mapowań,
- potrzebne ID runu,
- potrzebny model uprawnień do rehydratacji,
- potrzebny audyt dostępu do mapowań.

Wpływ na compliance:
- mapowanie należy traktować jak dane wysokiego ryzyka,
- wymagane decyzje o retencji,
- wymagane potwierdzenie, kto może odtwarzać dane.

Sensowność dla PoC:
- wysoka, jeśli pierwotny use case zakłada lokalną pracę na odpowiedzi i możliwość jej późniejszego osadzenia w realnym kontekście.

### Model B — one-way sanitization

Przykład:

```text
db-prod-01 -> production database host
```

W tym modelu nie zapisujemy dokładnego mapowania do wartości oryginalnej. Dane są uogólniane albo redagowane.

Zalety:
- mniejsza wrażliwość storage,
- prostszy model dostępu,
- mniejsze ryzyko deanonimizacji przez wyciek mapowania,
- lepsze dla scenariuszy, gdzie nie trzeba odtwarzać dokumentu.

Wady:
- brak pełnej rehydratacji,
- większe ryzyko utraty precyzji,
- trudniej utrzymać stabilne relacje między encjami,
- odpowiedź LLM może być mniej operacyjna.

Ryzyko:
- zbyt duża generalizacja,
- utrata istotnego kontekstu,
- trudniejsze porównanie odpowiedzi z oryginałem.

Wpływ na architekturę:
- mapping store może być ograniczony albo zbędny,
- nadal potrzebny raport redakcji,
- rehydratacja pełna nie jest możliwa.

Wpływ na compliance:
- prostszy argument bezpieczeństwa,
- nadal trzeba potwierdzić, czy uogólniony dokument może być wysyłany do zewnętrznego LLM.

Sensowność dla PoC:
- średnia jako wariant porównawczy,
- niższa, jeśli PoC ma sprawdzać pełny cykl anonimizacja -> LLM -> rehydratacja.

### Rekomendacja robocza

Na start reversible tokenization wydaje się bardziej zgodne z pierwotnym use case: praca z dokumentem klienta przez LLM, ale z możliwością lokalnego odtworzenia kontekstu po stronie operatora.

To nie oznacza decyzji docelowej. Oznacza kierunek dla PoC, który pozwala sprawdzić najtrudniejszą część procesu: bezpieczne mapowanie i rehydratację.

## Tokeny ślepe vs tokeny semantyczne

### Tokeny ślepe

Przykład:

```text
SECRET_001
```

Zalety:
- ujawniają mało kontekstu,
- są proste do generowania,
- zmniejszają ryzyko odgadnięcia realnej wartości.

Wady:
- mogą obniżać jakość odpowiedzi LLM,
- nie zawsze zachowują rolę encji w architekturze,
- odpowiedź może być mniej użyteczna operacyjnie.

### Tokeny semantyczne

Przykład:

```text
AWS_ACCOUNT_ID_003
```

Zalety:
- pomagają modelowi zrozumieć typ encji,
- zachowują semantykę dokumentu bez ujawniania wartości,
- poprawiają jakość analizy architektonicznej i bezpieczeństwa.

Wady:
- ujawniają więcej kontekstu,
- mogą zdradzać technologię, typ zasobu lub klasę systemu,
- wymagają spójnej taksonomii tokenów.

### Wpływ na jakość odpowiedzi LLM

Token `VALUE_001` daje modelowi mniej informacji niż `AWS_ACCOUNT_ID_003` albo `DATABASE_HOST_014`.

W analizach DevOps/security typ encji często jest istotny. Model nie musi znać realnego konta AWS, ale powinien wiedzieć, że token reprezentuje konto AWS, a nie osobę albo sekret.

### Ryzyko ujawniania kontekstu

Token semantyczny może ujawniać, że klient używa AWS, konkretnego typu usługi albo modelu organizacji. To może być akceptowalne dla PoC, ale wymaga jawnej decyzji.

Do ustalenia:
- czy typ technologii jest wrażliwy,
- czy klasy tokenów powinny być konfigurowalne per klient,
- czy dla niektórych klas używać tokenów ślepych.

### Collision avoidance

Tokeny powinny być:
- unikalne per run,
- stabilne dla tej samej wartości w ramach runu,
- typowane,
- odporne na kolizje między klasami.

Przykład:

```text
HOST_001 != SECRET_001
```

Nawet jeśli licznik jest ten sam, przestrzeń nazw tokenów jest inna.

### Zachowanie semantyki dokumentu

Semantyczne tokeny ułatwiają zachowanie relacji:

```text
SERVICE_001 używa AWS_ACCOUNT_ID_003 i łączy się z DATABASE_HOST_014.
```

To jest bardziej użyteczne dla LLM niż:

```text
ENTITY_001 używa ENTITY_002 i łączy się z ENTITY_003.
```

### Hipoteza robocza

Semantyczne tokeny mogą być lepsze dla PoC, bo zwiększają jakość odpowiedzi LLM i lepiej zachowują sens dokumentów technicznych.

Ryzyko ujawnienia kontekstu trzeba kontrolować przez ograniczoną taksonomię tokenów i review zanonimizowanego materiału przed eksportem.

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
