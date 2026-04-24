---
title: Proces wyjątków granic domen
domain: shared-concept
origin: own
classification: internal
llm_exposure: allowed
cross_domain_export: allowed
source_of_truth: vault
created: 2026-04-24
updated: 2026-04-24
---

# Proces wyjątków granic domen

> Kontrolowany proces dla przypadków, w których wiedza może przekroczyć granicę domenową.
> To jest mechanizm wyjątków, nie alternatywa dla [[DOMAIN_ISOLATION_CONTRACT]] ani [[DERIVATIVE_INSIGHT_RULES]].

Powiązane: [[DOMAIN_ISOLATION_CONTRACT]] | [[DERIVATIVE_INSIGHT_RULES]] | [[CLASSIFICATION_MODEL]]

---

## Purpose

Proces wyjątków istnieje wyłącznie po to, aby umożliwić kontrolowane przeniesienie wiedzy przez granicę domenową, gdy:
- istnieje uzasadniona potrzeba operacyjna lub architektoniczna,
- wiedza została przekształcona do postaci pochodnej,
- ryzyko ujawnienia źródła zostało ocenione jako akceptowalne.

Każdy wyjątek **MUST** być traktowany jako odstępstwo od reguły bazowej.

Każdy wyjątek **MUST NOT** służyć do legalizacji bezpośredniego kopiowania treści klientowskich, decyzji R&D ani strategii produktowej między domenami.

---

## Allowed Exceptions

Wyjątek **MAY** być rozważony tylko wtedy, gdy przepływ ma następujący wzorzec:

```text
client-work
  -> generalized insight
  -> shared-concept only
```

Warunki obowiązkowe:
- materiał źródłowy **MUST** pochodzić z jednej, jawnie wskazanej domeny źródłowej,
- transformacja **MUST** usunąć nazwy klientów, systemów, osób, środowisk, identyfikatory i parametry umożliwiające rekonstrukcję źródła,
- wynik **MUST** opisywać wzorzec, klasę problemu, hipotezę albo model referencyjny,
- wynik **MUST** trafić wyłącznie do domeny `shared-concept`,
- wynik **MUST** być jawnie oznaczony jako `derived insight`,
- wyjątek **MUST** być udokumentowany przed użyciem poza domeną źródłową.

Wyjątek **MAY** dotyczyć tylko obniżenia szczegółowości i zwiększenia ogólności. Nie dotyczy przenoszenia treści operacyjnych 1:1.

---

## Prohibited Exceptions

Poniższe wzorce są bezwzględnie zabronione:

```text
client-work -> private-rnd
client-work -> internal-product-strategy
```

Wyjątek od powyższego zakazu **MUST NOT** zostać zatwierdzony, chyba że istnieje jawna transformacja:

```text
client-work
  -> generalized insight
  -> shared-concept
```

Nawet po takiej transformacji przepływ bezpośredni do `private-rnd` lub `internal-product-strategy` **MUST NOT** być traktowany jako wyjątek graniczny. Dalsze użycie jest dozwolone wyłącznie przez warstwę `shared-concept`, zgodnie z [[DERIVATIVE_INSIGHT_RULES]].

Dodatkowo:
- wyjątek **MUST NOT** obniżać klasyfikacji poniżej klasy rodzica lub źródła bez jawnej dokumentacji,
- wyjątek **MUST NOT** służyć obejściu polityki `llm_exposure: prohibited`,
- wyjątek **MUST NOT** obejmować danych `restricted`,
- wyjątek **MUST NOT** mieszać materiałów wielu klientów w jednym wniosku pochodnym.

---

## Review Procedure

1. Właściciel notatki źródłowej **MUST** opisać proponowany przepływ: źródło, cel, uzasadnienie i plan generalizacji.
2. Wnioskodawca **MUST** wykazać, że użycie `shared-concept` nie może zostać zastąpione istniejącą wiedzą neutralną.
3. Przed zatwierdzeniem **MUST** zostać wykonany przegląd anonimizacji i ryzyka rekonstrukcji źródła.
4. Przegląd **MUST** potwierdzić, że wynik końcowy nie zawiera commitments, roadmapy, design decisions ani deliverables z domeny źródłowej.
5. Zatwierdzenie **MUST** być jawne i zapisane w notatce docelowej albo w rejestrze przeglądu granic.
6. Jeśli istnieje wątpliwość co do anonimizacji, wyjątek **MUST NOT** zostać zatwierdzony.

Minimalne role kontrolne:
- autor transformacji,
- reviewer granicy domenowej,
- właściciel domeny docelowej.

Jedna osoba **MUST NOT** pełnić wszystkich trzech ról równocześnie dla materiału `confidential`.

---

## Documentation Requirements

Każdy zatwierdzony wyjątek **MUST** zawierać:
- datę przeglądu,
- plik źródłowy lub zakres źródła,
- domenę źródłową,
- domenę docelową,
- klasyfikację źródła i wynikową klasyfikację po transformacji,
- uzasadnienie biznesowe lub architektoniczne,
- opis wykonanej anonimizacji i generalizacji,
- nazwę reviewera,
- decyzję: `approved` albo `rejected`.

Notatka docelowa **MUST** zawierać ślad pochodzenia, np.:

```yaml
related_domains:
  - client-work (derived, anonymized, boundary-exception, 2026-04-24)
```

oraz blok:

```markdown
> [!note] Boundary exception
> Treść w tej notatce została dopuszczona przez kontrolowany proces wyjątku granicznego.
> Zakres: client-work -> generalized insight -> shared-concept
> Data przeglądu: YYYY-MM-DD
```

Brak tej dokumentacji oznacza, że wyjątek jest nieważny.
