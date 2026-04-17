# CLAUDE.md

Ten plik zawiera instrukcje dla Claude Code (claude.ai/code) podczas pracy z tym repozytorium.

## Czym jest to repo

Operacyjny vault wiedzy oparty na Obsidian dla starszego inżyniera DevOps/SRE (Jarosław Gołąb). Nie wiki — narzędzie pracy. Zaprojektowany pod pracę z częstymi przerwaniami i szybki powrót do kontekstu po przerwie.

## Kontrakt vaultu (non-negotiable)

- **Język:** cała treść notatek po polsku; kod, komendy, nazwy plików mogą być po angielsku
- **Struktura notatki:** objaw/problem → kontekst → rozwiązanie/działania → uwagi. Nigdy długich teoretycznych wstępów.
- **Każda notatka musi działać standalone** — zero zależności "przeczytaj sekcję 1 przed sekcją 3"
- **Brak pustych plików** — każdy plik musi zawierać realną wartość operacyjną lub gotowy do użycia szablon
- **Nazwy plików:** kebab-case, krótkie, bez sufiksów `final`/`v2`/`new`/`copy`
- **Linki:** używaj `[[wiki-links]]` do nawigacji między notatkami; nie powtarzaj treści w wielu miejscach
- **Mirror dokumentacji i minikursów:** każda zmiana w `docs/` lub `docs/course/` w repo devops-toolkit musi być odzwierciedlona w vault (`60-toolkit/` lub dedykowanej notatce). Vault jest jedynym miejscem do którego użytkownik wraca — jeśli dokumentacja nie jest tam, jej nie ma.

## Zachowanie Claude podczas rozmowy

**Każdy wątek rozmowy, który generuje wiedzę operacyjną, musi być natychmiast zapisany do vault.**

Zasady zapisu:
- Nie czekaj na koniec rozmowy — zapisuj w trakcie, gdy tylko pojawi się wartościowa treść
- Wybierz właściwy katalog zgodnie z priorytetem folderów (patrz niżej)
- Nazwa pliku: kebab-case, opisowa, bez dat w nazwie (data trafia do frontmatter jeśli potrzebna)
- Format: zgodny z kontraktem vaultu (objaw → kontekst → rozwiązanie → uwagi)
- Nie pytaj "czy mam zapisać?" — zapisz i poinformuj gdzie

**Obowiązkowe triggery zapisu — wykonaj natychmiast gdy wystąpi:**

| Zdarzenie | Co zapisać | Gdzie |
|-----------|-----------|-------|
| Git cleanup / synchronizacja repo | co znaleziono, co zrobiono, branche, PR | `session-log.md` projektu |
| Decyzja o priorytecie / co robimy dalej | wybór i uzasadnienie | `session-log.md` + `now.md` |
| Zmiana aktywnego zadania | nowe zadanie, następny krok, plik | `02-active-context/now.md` |
| Implementacja / zmiana kodu | co zmieniono, branch, testy | `session-log.md` projektu |
| Nowa konwencja lub standard | treść konwencji | `30-standards/` lub `CLAUDE.md` |
| Koniec sesji roboczej | stan, następny krok | `now.md` + `session-log.md` |

**Zasada kontrolna:** po każdej odpowiedzi zawierającej decyzję, działanie lub wiedzę — sprawdź czy vault jest aktualny. Jeśli nie — zapisz przed następną odpowiedzią.

Mapowanie typów rozmów na katalogi:

| Temat rozmowy | Gdzie zapisać |
|---------------|---------------|
| Problem z projektem / decyzja projektowa | `20-projects/internal/<projekt>/` lub `20-projects/client/<klient>/` |
| Incydent, awaria, diagnoza | `40-runbooks/` lub `02-active-context/` |
| Nowa komenda / snippet / wzorzec | `90-reference/` lub `50-patterns/` |
| Standard lub konwencja | `30-standards/` |
| Kontekst bieżącej pracy | `02-active-context/now.md` |
| Wiedza dziedzinowa (AWS, Terraform itd.) | `10-areas/<domena>/` |
| Decyzja architektoniczna | `80-architecture/decision-log.md` |
| Coś niejasnego / do sortowania | `01-inbox/` (tymczasowo) |

## Priorytety folderów (od najwyższego)

1. `02-active-context/` — bieżący stan operacyjny (now.md, current-focus.md, open-loops.md, waiting-for.md)
2. `40-runbooks/` — procedury incydentowe i operacyjne
3. `20-projects/` — notatki projektów wewnętrznych i klienckich
4. `30-standards/` — tagi, IaC, CI/CD, konwencje nazewnictwa
5. `50-patterns/` — wzorce debugowania, migracji, przeglądu FinOps
6. `90-reference/` — komendy, snippety, słowniczek

## Struktura vault

```
00-start-here/       ← zasady użycia vault, persona
01-inbox/            ← tymczasowe przechwytywanie (nie archiwum)
02-active-context/   ← żywy dashboard operacyjny
10-areas/            ← aws/, terraform/, cicd/, observability/, cloud-support/, business/
20-projects/         ← internal/, client/, reference/
30-standards/        ← aws-tagging, iac, cicd, naming, documentation
40-runbooks/         ← aws/, ecs/, kubernetes/, terraform/, networking/, incidents/
50-patterns/         ← debugging, migration, incident-analysis, finops, reusable-prompts
60-toolkit/          ← projekt CLI devops-toolkit (architektura, kontrakty, komendy, audyty)
70-finops/           ← przeglądy kosztów, optymalizacja, oszczędności
80-architecture/     ← ADR (decision-log), mapy systemów, zasady platformy
90-reference/        ← commands/, snippets/, glossary/, vendors/
templates/           ← kopiuj przed użyciem, nigdy nie edytuj oryginałów
```

## Praca z zewnętrznymi repozytoriami projektów

Każda notatka projektu w `20-projects/` może zawierać sekcję z lokalną ścieżką do repozytorium kodu:

```markdown
## Repozytorium kodu
- lokalna ścieżka: `~/projekty/client/<nazwa>/`
- remote: https://github.com/org/repo
```

Zasady dla Claude:
- Na początku rozmowy o projekcie — czytaj notatkę projektu i ustal lokalną ścieżkę repo
- Mając ścieżkę lokalną, możesz czytać i edytować pliki tamtego repo bezpośrednio
- Sama URL do GitHuba nie wystarczy — repo musi być sklonowane lokalnie
- Jeśli ścieżki nie ma w notatce, zapytaj użytkownika zanim zaczniesz szukać

## Architektura devops-toolkit

`60-toolkit/` śledzi stateless CLI (`toolkit <komenda> [opcje]`) z architekturą plugin/command-router. Kluczowe koncepcje:

- Każda komenda jest zdefiniowana przez **kontrakt** (schemat wejścia/wyjścia) w `60-toolkit/contracts/` — kontrakty są source of truth, implementacja jest wtórna
- Komendy komponują się przez JSON piping: `toolkit audit iam --output json | toolkit report generate --format markdown`
- Warstwy: CLI Entry → Command Router → Command/Plugin → AWS SDK → Output Layer (JSON/MD/CSV)
- Zobacz [[architecture-overview]], [[contracts-index]], [[command-catalog]]

## Wzorzec runbooka

Runbooki muszą zachowywać kolejność sekcji:
1. Objaw / symptom
2. Zakres / scope
3. Szybkie komendy
4. Decision points
5. Rollback / safety
6. Findings / notes

Szablon: `templates/runbook-template.md`

## Polityka inbox

`01-inbox/` jest tymczasowy. Elementy starsze niż 1 tydzień to backlog, nie archiwum. Przenoś lub usuwaj — nie akumuluj.

## Konwencje tagowania notatek

Używaj `#aws`, `#terraform`, `#incident`, `#finops`, `#todo`, `#decision` do wyszukiwania cross-vault.

## Kontekst persony

Użytkownik: doświadczony DevOps/SRE, AWS-primary (też GCP/Azure), ADHD. System musi redukować obciążenie pamięci. Modularne notatki z szybkim dostępem działają dobrze; linearne checklisty i długie sekwencyjne dokumenty — nie. Zobacz [[persona]] dla pełnego profilu.
