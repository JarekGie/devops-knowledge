# LLM_CONTEXT — 90-reference

## Cel katalogu

Szybkie wyszukiwanie — komendy, snippety, słowniczek, vendorzy. Odpowiedź na "jak to się znowu robiło?".

## Zakres tematyczny

- `commands/` — komendy CLI gotowe do skopiowania (AWS, Terraform, git, kubectl)
- `snippets/` — fragmenty kodu, konfiguracji (HCL, YAML, Python)
- `glossary/` — słowniczek terminów (szczególnie skrótów i wewnętrznych pojęć)
- `vendors/` — notatki o zewnętrznych dostawcach i narzędziach

## Najważniejsze notatki

> ⚠️ Podkatalogi zawierają głównie README.md — sekcje do wypełnienia przy pierwszej sesji.

## Konwencje nazewnicze

- `commands/aws-*.md` — komendy per serwis AWS
- `snippets/<technologia>-*.md` — snippety per technologia
- Preferuj krótkie pliki per temat, nie jeden duży plik

## Powiązania z innymi katalogami

- `[[../40-runbooks/]]` — runbooki linkują do komend stąd
- `[[../50-patterns/]]` — wzorce używają snippetów stąd
- `[[../10-areas/]]` — wiedza domenowa uzupełniana przez komendy

## Wiedza trwała vs robocza

- **Trwała (całość):** komendy i snippety nie wygasają (sprawdzaj wersje API)
- Aktualizuj gdy zmieni się składnia CLI lub API

## Jak przygotować kontekst dla ChatGPT

1. Skopiuj relevant komendy/snippety
2. Ten katalog to "附録" — dodaj do głównego kontekstu problemu
3. ChatGPT może uzupełnić brakujące komendy jeśli dasz mu kontekst problemu

---

## Ostatnia aktualizacja kontekstu

2026-04-20 — katalog do rozbudowania (stub READMEs)

## Najważniejsze linki

- `[[commands/README]]`
- `[[snippets/README]]`
- `[[glossary/README]]`
