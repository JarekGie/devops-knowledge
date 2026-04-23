# Porównanie z istniejącymi klasami produktów

To nie jest market research. To porównanie koncepcyjne: do jakich klas rozwiązań podobny jest pomysł i czego można się z nich nauczyć.

## DLP

### Podobieństwa

- Wykrywanie danych wrażliwych.
- Decyzja, czy dane mogą opuścić granicę zaufania.
- Potrzeba polityk, klasyfikacji i audytu.
- Ryzyko false positive i false negative.

### Różnice

- Klasyczne DLP często działa na mailach, endpointach, storage albo sieci.
- Tutaj potrzebne jest zachowanie semantyki dla LLM, nie tylko blokada.
- Tokenizacja i rehydratacja są bardziej centralne niż w prostym DLP.

### Czego można się nauczyć

- Same detektory nie wystarczą; potrzebne są polityki.
- Alert fatigue i false positives mogą zabić adopcję.
- DLP bez właściciela reguł degraduje się z czasem.

## Secrets scanning

### Podobieństwa

- Detekcja sekretów, tokenów, kluczy, connection stringów.
- Wysoki koszt false negative.
- Potrzeba custom patterns dla narzędzi i providerów.

### Różnice

- Secrets scanning zwykle odpowiada "znaleziono/nie znaleziono".
- Anonimizator musi zachować dokument użyteczny dla reasoning LLM.
- Nie wszystkie dane wrażliwe są sekretami.

### Czego można się nauczyć

- Reguły muszą być testowane na corpusie.
- Entropia i regexy są pomocne, ale niewystarczające.
- Trzeba rozróżniać sekrety aktywne, przykładowe i fałszywe.

## API gateways

### Podobieństwa

- Kontrolowany punkt przejścia.
- Możliwość egzekwowania polityk.
- Audyt requestów i decyzji.

### Różnice

- API gateway zwykle nie rozumie głęboko treści dokumentu.
- Tutaj potrzebna jest analiza semantyczna i strukturalna.
- Rehydratacja nie jest typowym problemem API gateway.

### Czego można się nauczyć

- Centralny punkt kontroli jest użyteczny, ale może stać się bottleneckiem.
- Polityki muszą być jawne i testowalne.
- Bypass kanałami bocznymi jest realnym ryzykiem.

## Secure AI gateways

### Podobieństwa

- Kontrola wejścia do LLM.
- Możliwość wyboru modeli według polityki.
- Audyt użycia AI.
- Potrzeba ochrony przed prompt injection i data exfiltration.

### Różnice

- Secure AI gateway zwykle działa runtime dla promptów.
- Tutaj pierwszy use case dotyczy dokumentów i lokalnej rehydratacji.
- Mapping store jest specyficznym aktywem, którego gateway może nie mieć.

### Czego można się nauczyć

- Samo "maskowanie" danych może nie wystarczyć.
- Potrzebna jest walidacja odpowiedzi, nie tylko wejścia.
- Governance modeli jest osobną osią architektury.

## Confidential computing patterns

### Podobieństwa

- Próba zmniejszenia zaufania do środowiska przetwarzania.
- Ochrona danych w użyciu albo na granicy przetwarzania.
- Silny nacisk na granice zaufania.

### Różnice

- Confidential computing chroni wykonanie, ale nie rozwiązuje semantycznego wycieku do LLM.
- Anonimizator pracuje na treści i meaning, nie tylko na izolacji runtime.
- Rehydratacja i token semantics są poza typowym modelem confidential computing.

### Czego można się nauczyć

- Granice zaufania muszą być formalnie nazwane.
- Klucze i mapping store są centralnym elementem bezpieczeństwa.
- Techniczna izolacja nie zastępuje polityki eksportu.

## Prompt firewalls

### Podobieństwa

- Wykrywanie prompt injection.
- Kontrola promptu i odpowiedzi.
- Blokowanie lub oznaczanie ryzykownych treści.

### Różnice

- Prompt firewall często działa na krótkich promptach, nie na złożonych dokumentach.
- Dokument może zawierać tabele, kod, komentarze i formatowanie.
- Fałszywe blokady mogą uniemożliwić sensowną analizę dokumentacji.

### Czego można się nauczyć

- Trzeba analizować wejście i wyjście.
- Nie można polegać wyłącznie na system prompt.
- Warto mieć tryb ostrzeżenia i tryb blokady.

## Wniosek roboczy

Pomysł nie jest tylko anonimizatorem, jeśli ma działać bezpiecznie na realnych dokumentach.

Najbliższe klasy koncepcyjne:
- DLP for LLM,
- secure AI gateway,
- prompt firewall z lokalnym pre-processingiem,
- secrets scanning rozszerzony o rehydratację.

Ryzyko: jeśli nazwiemy to tylko anonimizatorem, możemy zignorować potrzebę policy decision: czy dokument w ogóle wolno eksportować.
