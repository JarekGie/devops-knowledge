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
