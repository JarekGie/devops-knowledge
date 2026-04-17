# Jak używać tego vaulta

## Zasady nawigacji

**Szybki start pracy:** otwórz [[now]] albo [[current-focus]]  
**Niespodziewany problem:** `40-runbooks/` → wybierz folder → README → konkretny runbook  
**Coś do zapamiętania, ale nie wiadomo gdzie:** wrzuć do `01-inbox/quick-capture.md`  
**Nowy projekt:** skopiuj `templates/project-note-template.md` do `20-projects/`  
**Decyzja do udokumentowania:** skopiuj `templates/decision-template.md` do `80-architecture/`

## Reguły zapisu

- Notatka musi działać **bez czytania całego folderu**
- Jeśli notatka ma więcej niż 3 sekcje — rozważ podział
- Linki wiki `[[nazwa]]` zamiast powtarzania treści
- Nie kopiuj informacji — linkuj
- Tagi: `#aws`, `#terraform`, `#incident`, `#finops`, `#todo`, `#decision`

## Priorytety folderów

```
02-active-context/   ← czytasz codziennie
40-runbooks/         ← otwierasz w trakcie problemu
30-standards/        ← referencja przy code review / nowym projekcie
50-patterns/         ← otwierasz przy debugging / refactorze
60-toolkit/          ← projekt devops-toolkit
80-architecture/     ← ADR, decyzje, mapy systemów
```

## Inbox → archiwum

`01-inbox/` to tymczasowe miejsce. Rzeczy, które tam leżą > 1 tydzień, są zaległościami — nie archiwum.  
Przenoś lub kasuj. Nie akumuluj.

## Szablony

Wszystkie szablony są w `templates/`. Kopiuj plik, zmień nazwę, uzupełnij.  
Nie edytuj oryginałów szablonów — duplikuj je.
