# Reusable Prompts

Gotowe promptu do użycia z AI (Claude, Copilot) w typowych zadaniach DevOps.

#ai #prompts #patterns

---

## Terraform — review modułu

```
Przejrzyj ten moduł Terraform pod kątem:
1. Bezpieczeństwo: otwarte security groups, publiczne zasoby, brak szyfrowania
2. Taggowanie: czy wszystkie zasoby mają wymagane tagi (Environment, Project, ManagedBy, Owner, CostCenter)
3. Nazewnictwo: kebab-case, konwencja {projekt}-{env}-{typ}
4. Dobre praktyki: lifecycle rules, prevent_destroy na krytycznych zasobach
5. Nieużywane zmienne lub outputy

[wklej kod modułu]
```

## AWS IAM — analiza polityki

```
Przeanalizuj tę politykę IAM pod kątem zasady least privilege.
Wskaż:
- Zbyt szerokie uprawnienia (*, wildcards)
- Akcje które powinny być bardziej granularne
- Brakujące warunki (Condition block)
- Sugerowane zmiany z uzasadnieniem

[wklej JSON polityki]
```

## Incident post-mortem — draft

```
Na podstawie tego timeline incydentu napisz draft post-mortem w formacie blameless.
Sekcje: summary, timeline, root cause, contributing factors, action items (P0-P3).
Timeline:
[wklej timeline]
```

## Dockerfile — review

```
Przejrzyj ten Dockerfile pod kątem:
1. Security: brak non-root user, COPY vs ADD, sekrety w warstwie
2. Optymalizacja rozmiaru: niepotrzebne warstwy, multi-stage build
3. Cache efficiency: kolejność warstw
4. Best practices: healthcheck, ENTRYPOINT vs CMD

[wklej Dockerfile]
```

## Koszt AWS — analiza

```
Mam te dane z AWS Cost Explorer. Pomóż mi zidentyfikować:
1. Top 3 nieoczekiwane wzrosty kosztów
2. Zasoby które prawdopodobnie mogą być zoptymalizowane
3. Rekomendacje konkretnych akcji

[wklej dane kosztów]
```

## GitHub Actions — debug workflow

```
Ten GitHub Actions workflow failuje. Przeanalizuj logi i wskaż:
1. Przyczynę błędu
2. Konkretny step i linia
3. Sugerowane poprawki

Logi:
[wklej logi]

Workflow YAML:
[wklej workflow]
```

## Architecture decision — RFC

```
Pomóż mi napisać krótkie RFC (Architecture Decision Record) dla tej decyzji.
Format: kontekst, opcje rozważane, decyzja, konsekwencje, alternatywy odrzucone.

Decyzja: [opisz decyzję]
Kontekst: [opisz problem]
```
