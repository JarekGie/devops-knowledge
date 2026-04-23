# Red-team questions

Lista pytań do przyszłego review. Nie odpowiadamy tu na wszystkie; celem jest wymuszenie niewygodnego testowania koncepcji.

1. Co jeśli dokument zawiera prompt injection ukryty w komentarzach kodu?
2. Co jeśli prompt injection jest w komórce XLSX, której operator nie widzi w preview?
3. Co jeśli LLM zmodyfikuje identyfikator placeholdera, np. `HOST_014` na `HOST_041`?
4. Co jeśli dwa różne sekrety zostaną ztokenizowane do tej samej klasy i operator uzna je za zamienne?
5. Co jeśli operator eksportuje dokument przed sanitizacją przez pomyłkę workflow?
6. Co jeśli model odpowie syntetycznie, ale zrekonstruuje nazwę klienta z kontekstu?
7. Co jeśli semantyczne tokeny ujawnią, że dokument dotyczy konkretnego dostawcy, regionu albo technologii?
8. Co jeśli dokument po anonimizacji nadal jest unikalny i identyfikowalny?
9. Co jeśli mapping store trafi do backupu, logów albo katalogu synchronizowanego z chmurą?
10. Co jeśli rehydratacja zostanie uruchomiona przez osobę, która nie powinna widzieć danych oryginalnych?
11. Co jeśli parser PDF zgubi stopkę z danymi osobowymi?
12. Co jeśli OCR błędnie odczyta sekret i recognizer go nie wykryje?
13. Co jeśli sekret jest zakodowany base64 albo składany przez interpolację Terraform?
14. Co jeśli CloudFormation/Terraform zawiera sekret w heredoc albo komentarzu?
15. Co jeśli model poprosi użytkownika o dostarczenie mapowania tokenów, żeby "poprawić jakość odpowiedzi"?
16. Co jeśli odpowiedź LLM zawiera instrukcję, która po rehydratacji staje się wrażliwa?
17. Co jeśli użytkownik skopiuje zrehydratowaną odpowiedź do zewnętrznego narzędzia bez kontroli?
18. Co jeśli false positive usunie krytyczny kontekst i model da błędną rekomendację bezpieczeństwa?
19. Co jeśli false negative dotyczy nie sekretu, tylko unikalnej relacji architektonicznej?
20. Co jeśli klasyfikacja dokumentu powinna zakazać eksportu niezależnie od anonimizacji?
21. Co jeśli lokalny PoC działa na syntetycznych dokumentach, ale realne dokumenty mają chaos formatów?
22. Co jeśli custom recognizery przestaną być utrzymywane po pierwszej wersji?
23. Co jeśli operator będzie traktował "brak wykrytych sekretów" jako gwarancję bezpieczeństwa?
24. Co jeśli model halucynuje dodatkowy placeholder, którego nie ma w mapping store?
25. Co jeśli system zapisze raw input w trace, exception albo request dump?
26. Co jeśli review preview jest zbyt długie i stanie się formalnością?
27. Co jeśli różni klienci mają sprzeczne wymagania co do tego, co wolno eksportować?
28. Co jeśli zewnętrzny LLM zmieni politykę retencji albo sposób przetwarzania danych?
29. Co jeśli model lokalny użyty do sanity-check ma gorszą detekcję niż zakładamy?
30. Co jeśli "anonimizator" stanie się nieformalną furtką do wysyłania danych klienta do LLM bez zgody?
