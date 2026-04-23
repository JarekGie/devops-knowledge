# Ryzyka

| Ryzyko | Opis | Skutek | Prawdopodobieństwo | Priorytet | Możliwe ograniczenie |
|---|---|---|---|---|---|
| False negative w detekcji | Dane wrażliwe nie zostaną wykryte. | Wyciek do LLM. | Wysokie | Krytyczny | Warstwowa detekcja, test corpus, review przed eksportem. |
| False positive niszczący sens | System ukryje za dużo lub złe fragmenty. | LLM da słabą albo błędną odpowiedź. | Wysokie | Wysoki | Typy tokenów, preview, ręczna korekta. |
| Wyciek mapowania tokenów | Mapa oryginał-token zostanie ujawniona. | Pełna deanonimizacja danych. | Średnie | Krytyczny | Szyfrowanie, Vault, least privilege, audyt dostępu. |
| Prompt injection w dokumencie | Dokument zawiera instrukcje dla modelu. | Próba obejścia kontraktu lub exfiltration. | Średnie | Wysoki | Sanitizacja promptu, stały system prompt, izolacja mapowań. |
| Nieautoryzowana rehydratacja | Użytkownik bez prawa odtwarza wartości. | Ujawnienie danych klienta. | Średnie | Krytyczny | Role, approval, audit trail. |
| Brak polityki użycia AI | Nie wiadomo co wolno wysyłać i komu. | Ryzyko organizacyjne/compliance. | Wysokie | Krytyczny | Potwierdzenie z security/compliance. |
| Zbyt szeroki scope PoC | Próba obsługi zbyt wielu formatów i workflow. | Brak dowiezienia PoC. | Wysokie | Wysoki | Ograniczyć formaty i źródła wejścia. |
| Uzależnienie od jednego modelu | Pipeline działa tylko z jednym LLM/parsers. | Vendor lock-in albo kruchość jakości. | Średnie | Średni | Kontrakt modelu, adaptery, test porównawczy. |
| Uzależnienie od jednego parsera | Ekstrakcja zawodzi dla części dokumentów. | Błędna anonimizacja. | Wysokie | Wysoki | Tika + alternatywa, testy formatów. |
| Dokumenty binarne / skany | Brak tekstu lub słaba jakość OCR. | Pominięcie danych wrażliwych. | Średnie | Wysoki | Poza zakresem startowym albo ręczny gate. |
| Koszt custom recognizerów | Reguły domenowe starzeją się i wymagają utrzymania. | Dług utrzymaniowy. | Wysokie | Wysoki | Właściciel reguł, test corpus, wersjonowanie. |
| Logi z przeciekami | Aplikacja loguje surowy tekst lub mapowanie. | Ujawnienie danych w telemetryce. | Średnie | Krytyczny | Redakcja logów, zakaz logowania raw, testy. |
| Kolizje tokenów | Błędne mapowanie wartości. | Niepoprawna rehydratacja. | Niskie/Średnie | Wysoki | Deterministyczne ID per run, constraints. |

## Uwagi

Największe ryzyka nie są związane z samym frameworkiem webowym. Krytyczne są detekcja, kontrola mapowań, audyt i decyzje organizacyjne.
