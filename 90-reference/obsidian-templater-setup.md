---
title: Obsidian Templater — konfiguracja folder templates i auto-renderowanie
tags: [obsidian, templater, workflow, tools]
created: 2026-05-01
---

# Objaw

Plugin Templater wstawia template jako plain text — zmienne `<% tp.file.title %>` nie są renderowane. Frontmatter zawiera literalne `<% ... %>` zamiast wartości.

# Kontekst

Obsidian + Templater plugin. Template folder: `templates/`, subfolderze z szablonami, np. `templates/frontmatter/prompt.md`. Folder docelowy: `50-patterns/prompts/` i subfolderze.

# Rozwiązanie

## Wymagana konfiguracja (Settings → Templater)

| Ustawienie | Wartość |
|---|---|
| Template folder location | `templates` (bez slash, bez trailing slash) |
| Trigger Templater on new file creation | **ON** |
| Folder Templates → dodaj wpis | folder: `50-patterns/prompts`, template: `templates/frontmatter/prompt.md` |

Subfolderze dziedziczą mapping automatycznie — jeden wpis dla `50-patterns/prompts` obejmuje `50-patterns/prompts/starter-pack/` itd.

## Wyłącz core plugin Templates

Settings → Core plugins → Templates → **OFF**. Jeśli oba pluginy są aktywne, core Templates wstawia plik bez renderowania zmiennych.

## Re-procesowanie istniejących plików

Istniejące pliki ze zmiennymi nie są auto-procesowane. Otwórz plik i wywołaj:
```
Ctrl+P → Templater: Replace templates in the active file
```

# Uwagi

- Ścieżka w Folder Templates: bez leading slash, bez trailing slash (`50-patterns/prompts` nie `/50-patterns/prompts/`)
- Template folder musi wskazywać na korzeń drzewa szablonów (`templates`), nie na podfolder (`templates/frontmatter`)
- Trigger Templater on new file creation jest domyślnie OFF — to najczęstsza przyczyna problemu
- Core plugin "Szablony" (Templates) w polskiej wersji Obsidian — wyłącz, bo blokuje Templater; łatwo przeoczyć bo nazwa różni się od angielskiej "Templates"
- Konfiguracja zweryfikowana jako działająca: 2026-05-01
