# Stack PoC

To jest roboczy kierunek techniczny, nie decyzja architektoniczna.

| Komponent | Rola | Dlaczego ma sens | Ryzyka / uwagi | Konieczne na MVP |
|---|---|---|---|---|
| Python 3.12 | Runtime backendu i pipeline | Dobry ekosystem parserów, NLP i integracji | Trzeba pilnować dependency hygiene | Tak |
| FastAPI | Mały API / lokalny interfejs | Prosty start, dobre typowanie, szybki PoC | UI/API może rozrosnąć się za wcześnie | Warunkowo |
| PostgreSQL | Storage metadanych i mapowań | Relacyjny model dla runs, tokens, audit | Mapowania są wrażliwe, wymagają kontroli dostępu | Warunkowo |
| Redis | Queue/cache/locki | Przydatny dla jobów i statusów | Nie zaczynać od zbyt dużej asynchroniczności | Nie |
| Celery | Job processing | Dobre dla ekstrakcji i cięższych zadań | Dodaje operacyjną złożoność | Nie na minimalny MVP |
| Apache Tika | Ekstrakcja tekstu z wielu formatów | Szerokie pokrycie formatów | JVM, jakość ekstrakcji różna per format | Warunkowo |
| Unstructured | Ekstrakcja dokumentów i struktury | Przydatne dla PDF/DOCX/tabel | Może być ciężkie zależnościowo | Warunkowo |
| Presidio | PII detection / anonymization | Gotowe recognizery i pipeline PII | Wymaga strojenia języka i domeny | Tak, jeśli działa dla PL w PoC |
| spaCy | NER i custom pipeline | Możliwość recognizerów domenowych | Modele PL i jakość detekcji do sprawdzenia | Warunkowo |
| Custom recognizers / regex packi | Sekrety, cloud IDs, infra patterns | Konieczne dla DevOps/IaC/logów | Koszt utrzymania i false positives | Tak |
| Ollama | Lokalny LLM do testów | Pozwala sprawdzić wariant offline/local | Jakość może być niższa niż modele komercyjne | Warunkowo |
| Vault | Docelowe przechowywanie mapowań/sekretów | Naturalny kierunek dla danych wrażliwych | Za ciężki jako pierwszy krok bez decyzji operacyjnej | Nie na start |

## Czego nie dokładać na start

Na start nie dokładać:
- OpenSearch,
- Qdrant,
- ciężkiego OCR jako domyślnej ścieżki,
- enterprise workflow engine,
- enterprise policy engine,
- wielu providerów LLM naraz,
- integracji mail/repo/ticketing,
- rozbudowanego UI administracyjnego.

## Minimalny wariant techniczny

Najmniejszy sensowny PoC:
- Python,
- prosty CLI albo FastAPI endpoint,
- ekstrakcja dla kilku formatów,
- Presidio + regex/custom recognizers,
- lokalny zapis mapowania w pliku lub małej bazie testowej,
- ręczny eksport zanonimizowanego materiału,
- ręczna rehydratacja wyniku.

## Do ustalenia

- Czy PoC wymaga UI.
- Czy PostgreSQL jest potrzebny od pierwszego dnia.
- Czy Vault ma być warunkiem bezpieczeństwa przed pracą na dokumentach realnych.
