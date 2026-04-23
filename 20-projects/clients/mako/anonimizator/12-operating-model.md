# Operating model

## Role do rozważenia

### Osoba dostarczająca dokument

Wrzuca dokument do procesu. Może to być konsultant, DevOps, architekt, project owner albo inna osoba pracująca z dokumentacją klienta.

Do ustalenia: kto formalnie może dostarczać dokumenty.

### Operator anonimizacji

Uruchamia pipeline i sprawdza wynik detekcji przed eksportem.

Odpowiedzialność:
- wybór plików,
- uruchomienie anonimizacji,
- review wykrytych encji,
- decyzja czy materiał jest gotowy do eksportu.

### Osoba wybierająca model

Wybiera zewnętrzny albo lokalny model.

Do ustalenia:
- czy wybór modelu jest ręczny,
- czy lista modeli jest ograniczona polityką.

### Osoba zatwierdzająca eksport

Akceptuje wysłanie zanonimizowanego materiału do LLM.

W PoC może to być ta sama osoba co operator, ale docelowo warto rozdzielić role.

### Osoba rehydratująca wynik

Ma dostęp do mapowania tokenów i może odtworzyć wartości.

To rola wysokiego ryzyka. Dostęp powinien być ograniczony i audytowany.

### Audytor

Przegląda metadane procesu:
- kto uruchomił run,
- kiedy,
- jakie klasy danych wykryto,
- czy był eksport,
- czy była rehydratacja.

## Minimalny operating model dla PoC

Proces ręczny i kontrolowany:
1. Operator wybiera kilka sztucznych dokumentów testowych.
2. Operator uruchamia lokalny pipeline.
3. Operator przegląda listę wykrytych encji.
4. Operator zatwierdza eksport zanonimizowanego materiału do testowego LLM.
5. Operator zapisuje odpowiedź modelu.
6. Operator uruchamia rehydratację lokalnie.
7. Operator zapisuje krótką notatkę z wynikami PoC.

Ograniczenia PoC:
- brak automatycznego mail ingestion,
- brak integracji z repo/ticketingiem,
- brak pracy na masowych dokumentach,
- brak automatycznej rehydratacji bez człowieka.

## Do ustalenia

- Czy PoC może mieć jedną osobę w wielu rolach.
- Czy docelowo eksport wymaga akceptacji drugiej osoby.
- Kto jest właścicielem polityki rehydratacji.
