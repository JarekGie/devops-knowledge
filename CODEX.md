# CODEX.md

Ten plik zawiera instrukcje dla Codexa podczas pracy z tym repozytorium.

## Czym jest to repo

Operacyjny vault wiedzy oparty na Obsidian dla starszego inżyniera DevOps/SRE (Jarosław Gołąb). Nie wiki i nie magazyn długich opisów. To narzędzie pracy do szybkiego wejścia w temat po przerwie, obsługi incydentów, projektów AWS/Terraform i rozwoju `devops-toolkit`.

## Kontrakt Codexa (non-negotiable)

- **Język:** treść notatek po polsku; kod, komendy, nazwy plików, identyfikatory i ścieżki mogą być po angielsku
- **Struktura notatki:** objaw/problem → kontekst → rozwiązanie/działania → uwagi; bez długich teoretycznych wstępów
- **Notatka ma działać standalone:** nie zakładaj czytania innych sekcji w określonej kolejności
- **Brak pustych plików:** nowy plik musi dawać wartość operacyjną albo być gotowym szablonem
- **Nazwy plików:** `kebab-case`, krótko, bez `final`, `v2`, `new`, `copy`
- **Linkowanie:** preferuj `[[wiki-links]]`; nie duplikuj tej samej treści w wielu notatkach
- **Ścieżki:** przed zapisem sprawdź realną strukturę katalogów; jeśli użytkownik poda błędną ścieżkę, popraw ją i jasno to zakomunikuj
- **Inspect first:** zanim coś zmienisz, przeczytaj istniejący plik i dopiero potem edytuj; nie traktuj vaulta jak greenfield
- **Małe zmiany:** preferuj aktualizację istniejącej notatki zamiast tworzenia nowej
- **Mirror dokumentacji:** jeśli zmienia się dokumentacja `devops-toolkit`, odzwierciedl to w `60-toolkit/`

## Jak Codex ma pracować

- Najpierw zrozum strukturę vaulta i kontekst zadania, dopiero potem edytuj
- Nie pytaj o zgodę na zapis notatki, jeśli rozmowa generuje realną wiedzę operacyjną
- Zanim utworzysz nowy plik, sprawdź czy istnieje lepsze miejsce do aktualizacji
- Nie wykonuj destrukcyjnych operacji na git lub plikach bez wyraźnej prośby
- Nie nadpisuj cudzych zmian tylko dlatego, że są niewygodne; dostosuj się do stanu repo
- Jeśli coś jest niejasne, przyjmij ostrożne założenie i zaznacz je w odpowiedzi

## Zasady zapisu do vaulta

Każdy wątek, który generuje wiedzę operacyjną, decyzję, nową konwencję albo użyteczny wynik diagnozy, ma zostać zapisany od razu.

Zasady:
- zapisuj w trakcie pracy, nie dopiero na końcu sesji
- wybierz katalog zgodnie z priorytetem folderów
- nazwa pliku opisowa, bez daty w nazwie
- jeśli treść pasuje do istniejącej notatki, aktualizuj ją zamiast dublować
- po zapisie poinformuj krótko gdzie wiedza trafiła

## Obowiązkowe triggery zapisu

| Zdarzenie | Co zapisać | Gdzie |
|-----------|-----------|-------|
| Zmiana aktywnego zadania | bieżący fokus, następny krok, blokery | `02-active-context/now.md` |
| Implementacja lub zmiana kodu | co zmieniono, w jakim repo, jakie testy uruchomiono | `session-log.md` projektu |
| Decyzja projektowa | wybór i uzasadnienie | notatka projektu + `now.md` jeśli wpływa na bieżący fokus |
| Incydent lub diagnoza awarii | objaw, zakres, komendy, findings | `40-runbooks/` lub `02-active-context/` |
| Nowy standard lub konwencja | reguła i zakres obowiązywania | `30-standards/` lub plik kontraktowy agenta |
| Koniec sesji roboczej | stan, otwarte kwestie, następny krok | `02-active-context/now.md` + `session-log.md` projektu |

## Priorytet folderów

1. `02-active-context/` — bieżący stan pracy
2. `40-runbooks/` — diagnozy i procedury operacyjne
3. `20-projects/` — decyzje i stan projektów
4. `30-standards/` — standardy i konwencje
5. `50-patterns/` — wzorce, reusable flows
6. `90-reference/` — komendy, snippety, glossary

## Mapowanie tematów na katalogi

| Temat | Gdzie zapisać |
|-------|---------------|
| Problem w konkretnym projekcie | `20-projects/internal/<projekt>/` lub `20-projects/clients/<klient>/` |
| Incydent, awaria, diagnoza | `40-runbooks/` |
| Stan bieżącej pracy | `02-active-context/now.md` |
| Standard lub polityka | `30-standards/` |
| Nowa komenda, snippet, szybki lookup | `90-reference/` |
| Wzorzec postępowania | `50-patterns/` |
| Decyzja architektoniczna | `80-architecture/decision-log.md` |
| Materiał nieposortowany | `01-inbox/` tymczasowo |

## Praca z repozytoriami projektów

- Zacznij od notatki projektu w `20-projects/` i ustal lokalną ścieżkę repo
- Sama nazwa projektu lub URL do remote nie wystarcza, jeśli repo nie jest znane lokalnie
- Jeśli ścieżka nie jest zapisana, zapytaj użytkownika zamiast zgadywać
- Po wykonaniu pracy w repo wróć z wynikiem do vaulta: `session-log.md`, `now.md`, runbook lub standard

## Praca z plikami i zmianami

- Czytaj przed edycją
- Szukaj tekstu przez `rg`, nie przez wolniejsze narzędzia, jeśli nie ma powodu
- Ręczne zmiany w plikach wykonuj przez patch, nie przez nadpisywanie całego pliku bez potrzeby
- Zachowuj istniejący styl notatki lub dokumentu, chyba że jest wyraźnie placeholderowy
- Nie przenoś plików i nie zmieniaj nazw bez konkretnego powodu

## NotebookLM

Whenever a prompt, task, or instruction mentions `notebooklm`, `NotebookLM`, `notebook`, `notatnik NotebookLM`, or asks to create/update NotebookLM sources, the canonical vault location is:

`90-reference/notebooklm/`

Zasady:
- nie tworz rownoleglych folderow notebookow pod `30-notebooks/`, `20-projects/` ani `40-runbooks/`, chyba ze uzytkownik wyraznie tego zazada
- kazdy notebook NotebookLM ma miec osobny katalog pod `90-reference/notebooklm/<notebook-name>/`
- rekomendowana struktura:
  - `README.md`
  - `sources.md`
  - `notebook-contract.md`
  - `prompts/`
  - `findings/`
  - `artifacts/`
  - `conversations/`

## Sandbox i bezpieczeństwo

- Zakładaj, że filesystem może być współdzielony i brudny
- Nie cofaj zmian użytkownika
- Nie używaj destrukcyjnych komend typu `git reset --hard`, `git checkout --`, `rm -rf` poza jasno uzgodnionym zakresem
- Jeśli komenda wymaga eskalacji lub wyjścia poza sandbox, poproś o to tylko wtedy, gdy jest to naprawdę potrzebne do zadania

## devops-toolkit — model pracy

`60-toolkit/` opisuje stateless CLI `toolkit <komenda> [opcje]`.

Zasady:
- kontrakty są ważniejsze niż implementacja
- lokalny vault jest skrótem i mapą pojęć, ale szczegółowe source of truth może siedzieć w repo `devops-toolkit`
- przy pracy nad toolkit najpierw ustal, czy zmienia się kontrakt, public API, czy tylko implementacja
- przy zmianie zachowania komendy sprawdź wpływ na `architecture-overview`, `contracts-index`, `command-catalog` i notatki kursowe

## Wzorzec runbooka

Runbook ma zaczynać się od rzeczy użytecznych w kryzysie:
1. Objaw / symptom
2. Zakres / scope
3. Szybkie komendy
4. Decision points
5. Rollback / safety
6. Findings / notes

Szablon: `templates/runbook-template.md`

## Polityka inbox

`01-inbox/` jest miejscem przejściowym. Nie zostawiaj tam rzeczy, które już mają oczywiste miejsce docelowe.

## Kontekst użytkownika

Użytkownik jest doświadczonym DevOps/SRE, działa w środowisku z częstymi przerwaniami, głównie AWS, ale też GCP/Azure. Vault ma redukować koszt przełączania kontekstu. Priorytet ma konkret, nawigacja i szybki powrót do pracy, nie estetyka dokumentacji.

## Powiązane

- `CLAUDE.md` — kontrakt referencyjny, na którym oparto ten plik
- `_system/AGENTS.md` — wspólny kontrakt dla wszystkich agentów
- `00-start-here/persona.md` — profil użytkownika
