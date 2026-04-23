# Threat model

To jest prosty model zagrożeń dla koncepcji anonimizatora. Nie jest to formalny STRIDE, ale używa myślenia STRIDE-lite tam, gdzie pomaga.

## Assets

| Aktywo | Dlaczego ważne |
|---|---|
| Dokument wejściowy | Może zawierać dane klienta, sekrety, topologię, dane osobowe i informacje operacyjne. |
| Mapping store | Łączy tokeny z wartościami oryginalnymi; kompromitacja oznacza deanonimizację. |
| Zanonimizowany eksport | Trafia do LLM; nadal może zawierać semantycznie wrażliwy kontekst. |
| Odpowiedź LLM | Może zawierać tokeny, błędne wnioski, próby obejścia albo fragmenty wejścia. |
| Proces rehydratacji | Odtwarza realne wartości; wymaga kontroli dostępu i audytu. |
| Konfiguracja recognizerów | Decyduje, co jest wykrywane; błędy mogą powodować przecieki. |
| Logi i audyt | Mogą pomagać w rozliczalności, ale same nie mogą zawierać raw danych. |

## Trust boundaries

Granice zaufania:
- lokalny input od operatora,
- parser dokumentów,
- silnik detekcji,
- mapping store,
- adapter LLM,
- zewnętrzny LLM,
- moduł rehydratacji,
- logi/audyt.

Najważniejsza granica: raw dokument i mapping store nie przechodzą do zewnętrznego LLM.

## Attack surfaces

Powierzchnie ataku:
- upload dokumentu,
- parsery PDF/DOCX/XLSX,
- custom recognizery i regexy,
- prompt budowany dla LLM,
- odpowiedź LLM,
- endpoint rehydratacji,
- storage mapowań,
- logi,
- konfiguracja modelu i providerów.

## Abuse scenarios

### Wyciek mapping store

Atakujący uzyskuje dostęp do mapowania tokenów. Może połączyć zanonimizowany eksport i odpowiedź LLM z realnymi wartościami.

Skutek: pełna deanonimizacja runu.

Ograniczenia:
- szyfrowanie,
- split access,
- krótka retencja,
- audyt odczytu,
- brak mapowań w logach.

### Malicious document injection

Dokument zawiera instrukcje dla LLM albo payload próbujący obejść kontrakt.

Skutek: model może próbować wypisać dane, ignorować zasady albo prosić o mapowanie.

Ograniczenia:
- traktować dokument jako niezaufany input,
- stały system prompt,
- skan prompt injection,
- walidacja odpowiedzi.

### Operator misuse

Operator celowo albo przypadkowo eksportuje zły dokument, omija review albo rehydratuje bez potrzeby.

Skutek: naruszenie procesu i potencjalny wyciek.

Ograniczenia:
- role,
- approval,
- audit trail,
- ograniczona retencja,
- jasny operating model.

### Model hallucination corrupting tokens

Model zmienia token, tworzy nowy token albo miesza placeholdery.

Skutek: rehydratacja może być błędna albo wynik traci sens.

Ograniczenia:
- kontrakt dla LLM,
- walidacja tokenów w odpowiedzi,
- blokada rehydratacji, jeśli tokeny nie przechodzą walidacji.

### Nieautoryzowana rehydratacja

Użytkownik bez prawa uruchamia rehydratację albo uzyskuje dostęp do wyniku po rehydratacji.

Skutek: ujawnienie danych wrażliwych.

Ograniczenia:
- osobna rola rehydrator,
- audyt,
- opcjonalna akceptacja drugiej osoby,
- least privilege.

## Highest-risk paths

1. Raw dokument -> zewnętrzny LLM bez pełnej anonimizacji.
2. Mapping store -> nieautoryzowany odczyt.
3. Zanonimizowany dokument z semantycznymi tokenami -> ujawnienie zbyt dużego kontekstu.
4. Odpowiedź LLM -> rehydratacja bez walidacji tokenów.
5. Logi -> przypadkowy zapis raw danych lub mapowania.

## Do ustalenia

- Czy PoC wymaga kontroli dostępu, czy wystarczy lokalny single-user model.
- Jak długo istnieje mapping store.
- Czy rehydratacja wymaga approval.
- Czy odpowiedź LLM jest traktowana jako artefakt klienta.
