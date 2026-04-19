# udemy-obsidian

Lokalne narzędzie CLI do eksportu transkryptów z kursów Udemy do vault Obsidian.

> **Ważna uwaga prawna:** Narzędzie działa wyłącznie na kursach, do których masz legalny dostęp (wykupione lub darmowe). Nie służy do obchodzenia zabezpieczeń, DRM ani systemów płatności.

---

## Co robi

1. Otwiera przeglądarkę Chromium (Playwright) i pozwala na ręczne zalogowanie do Udemy
2. Zapisuje sesję lokalnie — kolejne uruchomienia nie wymagają logowania
3. Odkrywa strukturę kursu (sekcje → wykłady → napisy VTT) przez API Udemy
4. Pobiera napisy przez uwierzytelnioną sesję przeglądarki
5. Czyści tekst VTT (usuwa znaczniki czasowe, duplikaty, tagi HTML)
6. Zapisuje pliki Markdown do vault Obsidian w strukturze zgodnej z projektem `aws-cloudops-exam`
7. Prowadzi manifest — ponowne uruchomienie pomija wykłady bez zmian

---

## Założenia i ograniczenia

- Napisy muszą być dostępne w odtwarzaczu Udemy (nie wszystkie wykłady je mają)
- Selektory DOM i endpointy API są oznaczone jako `# ADAPTER` — Udemy może je zmienić
- Narzędzie nie pobiera wideo, tylko tekst transkryptu
- Wymaga macOS z Python 3.11+

---

## Instalacja

```bash
# Utwórz środowisko wirtualne
python3.11 -m venv .venv
source .venv/bin/activate

# Zainstaluj zależności
pip install -e .

# Zainstaluj przeglądarkę Playwright
playwright install chromium
```

---

## Pierwsze uruchomienie — logowanie

```bash
python -m udemy_obsidian login
```

Otworzy się okno przeglądarki. Zaloguj się normalnie do Udemy. Po zamknięciu okna sesja zostanie zapisana do `.state/udemy-storage-state.json`.

Możesz też wskazać inną lokalizację pliku sesji:

```bash
python -m udemy_obsidian login --storage-state /inna/sciezka/session.json
```

---

## Eksport kursu

```bash
python -m udemy_obsidian export \
  --course-url "https://www.udemy.com/course/aws-certified-sysops-administrator-associate/" \
  --vault "/Users/jaroslaw.golab/projekty/devops/devops-knowledge"
```

### Przykładowe opcje

```bash
# Dry-run — sprawdź co zostałoby zapisane bez zapisywania
python -m udemy_obsidian export \
  --course-url "..." \
  --vault "/ścieżka/do/vault" \
  --dry-run

# Tylko sekcja nr 3
python -m udemy_obsidian export \
  --course-url "..." \
  --vault "..." \
  --only-section 3

# Wymuś ponowny eksport (ignoruj manifest)
python -m udemy_obsidian export \
  --course-url "..." \
  --vault "..." \
  --force

# Polskie napisy, zapisz surowe VTT
python -m udemy_obsidian export \
  --course-url "..." \
  --vault "..." \
  --language pl \
  --save-raw

# Inny podkatalog w vault
python -m udemy_obsidian export \
  --course-url "..." \
  --vault "..." \
  --output-subdir "10-areas/aws"
```

---

## Struktura wyjściowa w vault

```
vault/
└── 20-projects/internal/aws-cloudops-exam/udemy/
    └── <course-slug>/
        ├── _course.md          ← indeks kursu
        ├── _manifest.json      ← stan eksportu
        └── 01-introduction/
            ├── _section.md     ← indeks sekcji
            ├── 001-welcome.md
            └── 002-overview.md
```

---

## Wznawianie po przerwaniu

Narzędzie zapisuje `_manifest.json` po każdym wykładzie. Ponowne uruchomienie tego samego polecenia automatycznie pominie już wyeksportowane wykłady (chyba że użyjesz `--force`).

---

## Rozwiązywanie problemów

| Problem | Rozwiązanie |
|---------|-------------|
| "Nie jesteś zalogowany" | Uruchom `python -m udemy_obsidian login` |
| Kurs nie znaleziony | Sprawdź URL kursu, upewnij się że masz do niego dostęp |
| Brak napisów dla wykładu | Nie wszystkie wykłady mają transkrypt — to normalne |
| Selektory DOM nie działają | Zaktualizuj stałe oznaczone `# ADAPTER` w `browser.py` i `discovery.py` |
| Błąd Playwright | Uruchom `playwright install chromium` |

---

## Gdzie dostosować selektory

Udemy regularnie zmienia frontend. Miejsca do edycji oznaczone są `# ADAPTER`:

- `browser.py` — selektor sprawdzający zalogowanie
- `discovery.py` — pola API curriculum, endpoint wyszukiwania kursu
