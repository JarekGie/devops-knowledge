# Session Log — udemy-transcript-tool

## 2026-04-20 — CDP implementation

### Problem
Cloudflare blokuje kazda nawigacje Playwright na udemy.com — pokazuje "Weryfikowanie..."
nawet przy channel="chrome" i zapisanej sesji. cf_clearance fingerprint nie pasuje
do nowego kontekstu przegladarki.

### Rozwiazanie: CDP (Chrome Remote Debugging Protocol)
Zamiast uruchamiac nowego Chrome — podlaczamy sie do istniejacego przez CDP.
Istniejacy Chrome ma wazny cf_clearance i sesje Udemy.

### Zmiany w kodzie
- `browser.py` — nowy parametr `cdp_url: Optional[str]`
  - jesli podany: `playwright.chromium.connect_over_cdp(cdp_url)` zamiast launch
  - przejmuje istniejacy context[0] z polaczonej przegladarki
  - `save_state()` jest no-op w trybie CDP (zewnetrzna przegladarka)
  - `is_logged_in()` szybka weryfikacja (10s zamiast 60s)
  - `__aexit__` nie zamyka zewnetrznej przegladarki — tylko odlacza
- `config.py` — pole `cdp_url: Optional[str] = None`
- `cli.py` — flaga `--cdp-url` w komendzie `export`
- `run.sh` — zaktualizowany z instrukcjami CDP

### Status
ZAWIESZONE — czeka na uruchomienie Chrome z --remote-debugging-port=9222

### Nastepny krok
```bash
# Terminal 1: uruchom Chrome z CDP
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --user-data-dir="$HOME/Library/Application Support/Google/Chrome" &

# Weryfikacja
curl -s http://localhost:9222/json/version | python3 -m json.tool

# Terminal 2: uruchom eksport
cd ~/projekty/devops/devops-knowledge/20-projects/internal/udemy-transcript-tool
bash run.sh
```

---

## Historia problemow (sesje wczesniejsze)

| Problem | Rozwiazanie |
|---------|-------------|
| pip install -e . fail | pyproject.toml: setuptools.build_meta, python>=3.9 |
| Cloudflare blokuje login | import-cookies z browser-cookie3 |
| HTTP 403 na API calls | Bearer token z access_token cookie |
| HTTP 403 nadal | Przelaczenie na przechwytywanie odpowiedzi sieciowych |
| wait_until="networkidle" timeout | Zmiana na "load" + asyncio.Future 30s |
| Curriculum nie przechwycony | Udemy cachuje curriculum — dodano fallback na landing page |
| Cloudflare na kazda nawigacje | CDP (w toku) |
