# LLM DLP Gateway — kierunek produktowy

## Pytanie strategiczne

Czy to jest tylko anonimizator dokumentów, czy zalążek szerszej capability:
- secure AI gateway,
- DLP for LLM,
- policy broker,
- LLM firewall?

Na tym etapie nie rozstrzygamy. Ta notatka porządkuje możliwe kierunki.

## Wariant 1: tylko anonimizator

Opis: narzędzie lokalne do przetworzenia dokumentu, wygenerowania wersji zanonimizowanej i opcjonalnej rehydratacji wyniku.

Zalety:
- mały zakres,
- szybki PoC,
- mniejsza złożoność operacyjna,
- łatwiej zmierzyć skuteczność.

Wady:
- nie rozwiązuje szerszego problemu kontroli użycia LLM,
- nie zarządza politykami modeli,
- nie obejmuje runtime promptów poza dokumentami.

Sensowność teraz: wysoka.

## Wariant 2: secure AI gateway

Opis: kontrolowany punkt przejścia między użytkownikiem/narzędziem a modelami LLM. Gateway egzekwuje zasady: co wolno wysłać, do którego modelu, z jakim logowaniem.

Zalety:
- centralizuje kontrolę outbound do LLM,
- może egzekwować polityki,
- może dać audyt użycia AI.

Wady:
- duży zakres,
- wymaga integracji z narzędziami użytkowników,
- wymaga modelu tożsamości i uprawnień,
- może być przedwczesną komplikacją dla MVP.

Sensowność teraz: jako kierunek, nie jako pierwszy PoC.

## Wariant 3: DLP for LLM

Opis: warstwa wykrywania i blokowania danych wrażliwych przed promptem do LLM.

Zalety:
- blisko obecnego problemu,
- użyteczne także poza dokumentami,
- może działać jako biblioteka, CLI lub gateway.

Wady:
- wymaga wysokiej jakości detekcji,
- false negative są krytyczne,
- false positive mogą blokować pracę,
- wymaga ciągłego strojenia recognizerów.

Sensowność teraz: silna hipoteza produktowa, ale PoC powinien zacząć od dokumentów.

## Wariant 4: policy broker

Opis: komponent decydujący, który model można użyć dla danego typu danych, klienta, klasy dokumentu i celu.

Zalety:
- porządkuje governance,
- może wymusić allowlist modeli,
- pozwala różnicować polityki per klient lub klasyfikację.

Wady:
- wymaga formalnych polityk,
- bez decyzji organizacyjnych będzie pustą abstrakcją,
- za duży zakres na pierwszy PoC.

Sensowność teraz: do odłożenia.

## Wariant 5: LLM firewall

Opis: warstwa analizująca prompt i odpowiedź LLM pod kątem naruszeń polityk, exfiltration, prompt injection i niebezpiecznego zachowania.

Zalety:
- obejmuje wejście i wyjście,
- może chronić przed prompt injection,
- może blokować odpowiedzi naruszające kontrakt.

Wady:
- trudna jakość detekcji,
- ryzyko fałszywego poczucia bezpieczeństwa,
- wymaga jasnych reguł i testów adversarialnych.

Sensowność teraz: elementy można testować w PoC, ale nie budować pełnego firewalla.

## Hipoteza robocza

Najbezpieczniejszy kierunek etapowania:
1. Lokalny anonimizator dokumentów.
2. DLP checks dla promptu po anonimizacji.
3. Walidacja odpowiedzi przed rehydratacją.
4. Dopiero później gateway/policy broker, jeśli pojawi się realna potrzeba organizacyjna.

## Do ustalenia

- Czy problem występuje tylko dla dokumentów, czy szerzej dla promptów do LLM.
- Czy MakoLab potrzebuje centralnego punktu kontroli użycia AI.
- Czy klienci wymagają audytu użycia LLM.
- Czy rozwiązanie ma być prywatnym narzędziem, wewnętrznym standardem, czy capability dla klientów.
