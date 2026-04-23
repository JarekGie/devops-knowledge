# Pytania otwarte

| Pytanie | Status | Wpływ na architekturę |
|---|---|---|
| Skąd biorą się dane? | Do ustalenia | Definiuje ingest, uprawnienia i retencję. |
| Czy źródłem jest mail, ręczne wrzucanie, share, repo czy ticketing? | Do ustalenia | Decyduje, czy potrzebne są integracje, czy wystarczy upload manualny. |
| Czy wrażliwe dane mają od razu trafiać do Vault? | Do ustalenia | Wpływa na storage mapowań i model dostępu do rehydratacji. |
| Czy potrzebna jest automatyzacja przepływu między lokalnym i zewnętrznym LLM? | Do ustalenia | Decyduje, czy wystarczy ręczny eksport, czy potrzebna orkiestracja. |
| Czy MakoLab ma procedury regulujące wykorzystanie AI? | Do ustalenia | Może zablokować eksport do zewnętrznych LLM lub wymusić dodatkowe akceptacje. |
| Kto ma być właścicielem procesu? | Do ustalenia | Wpływa na role, audyt i odpowiedzialność operacyjną. |
| Kto akceptuje ryzyko? | Do ustalenia | Wpływa na bramki zatwierdzeń i zakres danych. |
| Czy dokument po anonimizacji ma być archiwizowany? | Do ustalenia | Wpływa na storage, retencję i klasyfikację danych po anonimizacji. |
| Czy potrzebny jest ślad audytowy rehydratacji? | Do ustalenia | Wpływa na logowanie, role i integralność mapowań. |
| Czy system ma działać offline-only, czy dopuszcza kontrolowany outbound? | Do ustalenia | Decyduje o wariancie architektury i modelu integracji z LLM. |
| Czy użytkownik ma wybierać model ręcznie, czy przez policy engine? | Do ustalenia | Wpływa na UX i zasady eksportu. |
| Czy mapowanie tokenów może być przechowywane per sesja, czy długoterminowo? | Do ustalenia | Wpływa na retencję, koszt i bezpieczeństwo. |
| Czy zanonimizowany dokument nadal jest traktowany jako dane klienta? | Do ustalenia | Wpływa na retencję, eksport i kontrolę dostępu. |
| Kto zatwierdza listę klas danych wrażliwych? | Do ustalenia | Wpływa na reguły detekcji i odpowiedzialność za false negative. |
| Czy wymagane są raporty dla klienta lub audytu wewnętrznego? | Do ustalenia | Wpływa na model raportowania i przechowywanie metadanych procesu. |
