# E2E Testing

#toolkit #testing

## Strategia testów

| Poziom | Co testuje | Kiedy |
|--------|-----------|-------|
| Unit | logika transformacji danych, walidacja kontraktów | zawsze w CI |
| Integration | wywołania AWS SDK (mocki) | zawsze w CI |
| E2E | prawdziwe konto AWS sandbox | przed releasem |

## E2E — wymagania środowiska

```bash
# Zmienne środowiskowe do E2E
export AWS_PROFILE=toolkit-sandbox
export TOOLKIT_E2E_ACCOUNT=123456789012
export TOOLKIT_E2E_REGION=eu-west-1

# Uruchomienie E2E
make test-e2e
```

## Konto sandbox

- Dedykowane konto AWS do testów
- Minimalne zasoby do testowania audytów
- IAM role z odpowiednimi uprawnieniami read-only
- Czyszczone automatycznie po testach

## Scenariusze E2E

| Scenariusz | Komenda | Oczekiwany wynik |
|-----------|---------|-----------------|
| Audyt IAM — konto z issues | `audit iam` | findings z HIGH severity |
| Audyt tagging — zasoby bez tagów | `audit tagging` | lista ARN bez tagów |
| FinOps report | `finops report` | valid Markdown output |

## Walidacja output

Każdy test E2E waliduje:
1. Exit code = 0 (lub oczekiwany kod błędu)
2. Output jest valid JSON
3. Output spełnia JSON Schema kontraktu
4. Kluczowe pola są obecne i niepuste

## Powiązane

- [[contracts-index]]
- [[architecture-overview]]
