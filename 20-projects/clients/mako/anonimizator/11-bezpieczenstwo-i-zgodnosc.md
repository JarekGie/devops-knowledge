# Bezpieczeństwo i zgodność

To nie jest porada prawna. To lista obszarów do potwierdzenia z bezpieczeństwem / compliance / właścicielem procesu.

## Obszary do sprawdzenia

### Klasyfikacja informacji

Do ustalenia:
- jakie klasy informacji istnieją w MakoLab,
- jak klasyfikować dokumenty klientów,
- czy zanonimizowany dokument nadal jest informacją klienta.

### Polityki AI

Do ustalenia:
- czy istnieje polityka wykorzystania zewnętrznych LLM,
- jakie modele/usługi są dopuszczone,
- czy wymagane są zgody klienta.

### Retencja

Do ustalenia:
- jak długo trzymać raw input,
- jak długo trzymać zanonimizowany output,
- jak długo trzymać mapowanie tokenów,
- kiedy usuwać runy PoC.

### Dostęp do danych wejściowych

Wymagane zasady:
- minimalny dostęp,
- brak przypadkowego współdzielenia katalogów roboczych,
- brak logowania raw dokumentu.

### Dostęp do mapowań tokenów

Mapowanie jest krytyczne. Jeśli wycieknie, anonimizacja traci sens.

Do ustalenia:
- czy mapowanie trafia do Vault,
- kto może je odczytać,
- czy wymagany jest approval dla rehydratacji.

### Audyt operacji

Audyt powinien obejmować:
- kto uruchomił run,
- jakie pliki przetworzono,
- jakie klasy danych wykryto,
- czy eksport do LLM został zatwierdzony,
- kto wykonał rehydratację.

Bez logowania wartości surowych.

### Kontrola eksportu do zewnętrznych usług

Do ustalenia:
- czy outbound ma być blokowany domyślnie,
- czy model jest wybierany ręcznie,
- czy potrzebny allowlist providerów/modeli.

### Wymagania klienta / NDA / kontrakty

Do ustalenia:
- czy konkretne umowy zabraniają wysyłki nawet zanonimizowanych danych,
- czy klient musi zaakceptować taki proces,
- czy potrzebny jest opis procesu w dokumentacji projektowej.

### Logowanie bez przecieków

Zasady:
- nie logować raw content,
- nie logować token mapping,
- nie logować sekretów,
- logować tylko metadane procesu.

### Least privilege

Role powinny mieć minimalne uprawnienia:
- operator,
- audytor,
- admin,
- reviewer eksportu.

### Rozdział ról

Do ustalenia:
- czy osoba uruchamiająca anonimizację może też rehydratować,
- czy rehydratacja wymaga drugiej osoby,
- kto ma prawo eksportu do LLM.

## Wymaga potwierdzenia

Wymaga potwierdzenia z bezpieczeństwem / compliance / właścicielem procesu:
- dopuszczalność zewnętrznych LLM,
- status zanonimizowanego dokumentu,
- wymagania audytu,
- retencja,
- model uprawnień.
