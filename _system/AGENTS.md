# AGENTS — Kontrakt dla agentów LLM

> Wspólny kontrakt dla Claude Code, Codex, ChatGPT i każdego innego agenta pracującego z tym vault.
> Nadrzędny wobec domyślnych zachowań modelu.

---

## Język i format

- Cała treść notatek operacyjnych w **języku polskim**
- Kod, komendy, nazwy plików, identyfikatory zasobów — po angielsku
- Nie tłumacz terminologii technicznej (CloudFormation, Terraform, ECS — bez tłumaczenia)
- Unikaj emoji, chyba że użytkownik wyraźnie prosi

## Struktura notatek

- Format: **objaw/problem → kontekst → rozwiązanie → uwagi**
- Każda notatka standalone — zero zależności "przeczytaj X przed Y"
- Krótkie sekcje z nagłówkami zamiast długich esejów
- Preferuj jawne założenia nad domyślnymi

## Nazewnictwo i organizacja

- Nazwy plików: `kebab-case`, bez dat w nazwie (data do frontmatter)
- Nie przenoś ani nie zmieniaj nazw istniejących plików bez wyraźnego powodu
- Nie usuwaj notatek archiwalnych — nawet jeśli wyglądają nieaktualnie
- Wiki-linki `[[nazwa-notatki]]` — zachowaj, nie zamieniaj na URL-e
- Nie duplikuj treści między notatkami — linkuj zamiast kopiować

## Przy tworzeniu i edycji

- Przed zapisem sprawdź czy właściwy katalog istnieje (`ls`)
- Użyj istniejącej notatki jeśli pasuje — zaktualizuj zamiast tworzyć nową
- Przy tworzeniu podsumowań katalogów — aktualizuj zamiast dodawać duplikaty
- Nie twórz plików README ani dokumentacji bez wyraźnej prośby
- Preferuj małe, konkretne zmiany nad dużymi refaktorami

## Kontekst dla ChatGPT

- ChatGPT nie ma dostępu do filesystem — kontekst musi być eksportowany ręcznie
- Przy przygotowaniu kontekstu: kompaktowe paczki, nie surowe dumpy plików
- Format: nagłówek → zakres → kluczowe decyzje → stan → następny krok
- Szczegóły w: `_system/CHATGPT_WORKFLOW.md`

## NotebookLM — warstwa syntezy

- NotebookLM **nie jest** źródłem prawdy — jest warstwą syntezy na skurowanych paczkach z vault
- Używaj do: briefingów, contradiction check, decision pack, handoff pack, gap analysis
- Wynik NotebookLM musi trafić do vault jako notatka syntezy **zanim** zostanie użyty przez agenta
- Przepływ: `vault → NotebookLM synthesis → notatka w vault → Claude/Codex execution`
- Pełny kontrakt: `_system/NOTEBOOKLM_CONTRACT.md`

## Priorytet folderów (od najwyższego)

1. `02-active-context/` — bieżący stan operacyjny
2. `40-runbooks/` — procedury incydentowe
3. `20-projects/` — projekty klientów i wewnętrzne
4. `30-standards/` — konwencje i standardy
5. `50-patterns/` — wzorce i playbooki
6. `90-reference/` — komendy i snippety

## Triggery zapisu (wykonaj natychmiast)

| Zdarzenie | Gdzie zapisać |
|-----------|---------------|
| Zmiana aktywnego zadania | `02-active-context/now.md` |
| Decyzja architektoniczna | `80-architecture/decision-log.md` |
| Nowy incydent | `40-runbooks/incidents/` |
| Nowa konwencja | `30-standards/` |
| Koniec sesji roboczej | `now.md` + `session-log.md` projektu |

## Ograniczenia i zakazy

- Nie używaj `--no-verify` ani nie pomijaj hooków git bez wyraźnej prośby
- Nie rób force-push na main bez potwierdzenia
- Nie usuwaj zasobów AWS bez potwierdzenia
- Nie uruchamiaj `terraform apply` bez wyraźnego "tak" od użytkownika

---

## Kontrakt dla dokumentów kontekstowych (LLM_CONTEXT)

### Obowiązkowe sekcje

Każdy dokument kontekstowy (`_chatgpt/context-packs/*.md`) MUSI zawierać:

1. **Kim jestem** — rola, środowisko, kontekst użytkownika
2. **Opis systemu** — czym jest projekt/platforma, zakres
3. **Zakres (scope boundaries)** — co obejmuje, czego NIE obejmuje
4. **Źródła prawdy** — gdzie jest stan runtime (IaC, AWS), ostrzeżenie że vault = dokumentacja
5. **Stan obecny** — co wdrożone, co działa
6. **Plan / roadmapa** — co planowane, priorytety
7. **Aktualny fokus** — 3-5 priorytetów bieżącego okresu
8. **Ryzyka / HRI** — High Risk Issues, nie ogólniki
9. **Decyzje architektoniczne** — podjęte decyzje z uzasadnieniem
10. **Pytania otwarte** — nierozstrzygnięte kwestie
11. **Jak używać** — instrukcja użycia z LLM

### Wymagania jakościowe

Dokument MUSI być:
- **konkretny** — realne dane (ARNy, account IDs, ścieżki), brak ogólników
- **aktualny** — odzwierciedla rzeczywisty stan AWS i IaC
- **standalone** — używalny bez dodatkowego kontekstu

Dokument NIE może:
- zawierać marketingowego języka ("platforma klasy enterprise", "best-in-class")
- być generowany bez analizy rzeczywistego stanu (nie na podstawie wyobrażeń)
- być oderwany od IaC — każde twierdzenie o stanie musi mieć pokrycie w Terraform/CFN/AWS

### Zasady aktualizacji

Każda aktualizacja dokumentu MUSI:
- zaktualizować pole `**Zaktualizowano:**` w nagłówku
- zaktualizować sekcję "Aktualny fokus" jeśli zmienia się priorytet
- NIE usuwać istniejących sekcji — tylko rozszerzać lub korygować
