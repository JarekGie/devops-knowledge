# Anonimizator dokumentów klientów dla pracy z LLM

## Cel przestrzeni

To jest robocza przestrzeń do analizy pomysłu lokalnego anonimizatora dokumentów klientów przed użyciem zewnętrznych LLM.

Nie jest to finalna architektura, backlog wdrożeniowy ani materiał ofertowy. Celem jest uporządkowanie problemu, pytań, ryzyk, wariantów technicznych i możliwego PoC.

## Stan obecny

Etap: discovery / koncepcja / PoC thinking.

Na tym etapie:
- nie ma zatwierdzonej architektury,
- nie ma wybranego stacku docelowego,
- nie ma potwierdzonego modelu operacyjnego,
- nie ma potwierdzonych procedur organizacyjnych dotyczących AI,
- nie ma decyzji, czy rozwiązanie ma być narzędziem lokalnym, usługą wewnętrzną czy częścią większego toolkitu.

## Po co powstała ta przestrzeń

Pomysł wymaga rozdzielenia kilku tematów:
- bezpieczeństwo danych klienta,
- lokalna detekcja i anonimizacja danych wrażliwych,
- zachowanie sensu dokumentu po anonimizacji,
- możliwość pracy z LLM bez wysyłania surowych danych,
- kontrolowana rehydratacja odpowiedzi,
- audyt procesu i odpowiedzialność za decyzje.

## Nowe osie dodane w drugim przebiegu

- threat modeling,
- prompt injection,
- token semantics,
- strategiczny kierunek produktowy.

## Critical Architecture Review

Trzeci przebieg dodaje krytyczny przegląd koncepcji:
- [[20-architecture-challenge]] — ukryte założenia, failure modes i pytanie, czy anonimizator nie powinien być policy brokerem.
- [[21-red-team-questions]] — lista pytań red-teamowych do future review.
- [[22-porownanie-z-istniejacymi-klasami-produktow]] — porównanie koncepcyjne z DLP, secrets scanning, secure AI gateways i prompt firewalls.

## Czego jeszcze nie wiemy

- Jakie źródła dokumentów będą obsługiwane.
- Jakie klasy danych są krytyczne dla MakoLab i klientów.
- Czy mapowania tokenów mają trafiać do Vault.
- Kto zatwierdza eksport do zewnętrznego LLM.
- Jakie są obowiązujące polityki AI / compliance.
- Czy PoC ma być lokalnym narzędziem operatorskim, małą usługą webową czy pipeline CLI.

## Dokumenty

- [[01-cel-i-kontekst]] — cel pomysłu, kontekst Tomka i ramy problemu.
- [[02-problem-do-rozwiazania]] — problem techniczny i organizacyjny.
- [[03-zakres-i-poza-zakresem]] — co wchodzi w zakres startowy, a co nie.
- [[04-pytania-otwarte]] — pytania wymagające decyzji lub doprecyzowania.
- [[05-zrodla-danych-i-ingest]] — źródła danych i modele ingestu.
- [[06-klasy-danych-wrazliwych]] — klasyfikacja danych do wykrywania.
- [[07-anonimizacja-tokenizacja-rehydratacja]] — logiczny przepływ anonimizacji i rehydratacji.
- [[08-warianty-architektury]] — warianty architektury i robocza rekomendacja.
- [[09-stack-poc]] — możliwy stack PoC, bez traktowania go jako dogmatu.
- [[10-ryzyka]] — tabela ryzyk technicznych, procesowych i bezpieczeństwa.
- [[11-bezpieczenstwo-i-zgodnosc]] — obszary do sprawdzenia z security/compliance.
- [[12-operating-model]] — możliwe role i ręczny model PoC.
- [[13-utrzymanie-i-koszt-zlozonosci]] — koszt złożoności i utrzymania.
- [[14-poc-plan]] — mały, kontrolowany plan PoC.
- [[15-kontrakt-dla-llm]] — roboczy kontrakt i przykładowe prompty.
- [[16-notatki-robocze]] — luźne obserwacje, hipotezy i decyzje odłożone.
- [[17-prompt-injection-i-data-exfiltration]] — prompt injection i exfiltration w kontekście dokumentów.
- [[18-threat-model]] — prosty model zagrożeń dla pipeline.
- [[19-llm-dlp-gateway-kierunek-produktowy]] — hipoteza, czy to zalążek secure AI gateway / DLP for LLM.
- [[20-architecture-challenge]] — krytyczny przegląd założeń i failure modes.
- [[21-red-team-questions]] — pytania red-teamowe do przeglądu koncepcji.
- [[22-porownanie-z-istniejacymi-klasami-produktow]] — porównanie z klasami rozwiązań pokrewnych.

## Zasada robocza

Raw dokumenty klienta nie powinny trafiać do zewnętrznego LLM. Model zewnętrzny może dostać wyłącznie materiał po lokalnej anonimizacji, zgodnie z jawnym kontraktem i kontrolą procesu.
