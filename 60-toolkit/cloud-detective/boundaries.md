# Cloud Detective — granice i odpowiedzialności

## Granica capability

Cloud Detective ma rozpoznawać i oceniać środowisko.

Nie powinien samodzielnie wykonywać zmian. Jeśli kiedyś prowadzi do remediacji, to przez istniejące zasady toolkitu:

- audit-first,
- plan / dry-run,
- jawny operator decision point,
- artefakty w repo klienta.

## Granica danych

Artefakty klienta zostają po stronie klienta:

```text
<client-repo>/.devops-toolkit/
  runs/
  reports/
  prompts/
```

Repo `devops-toolkit` pozostaje silnikiem, nie magazynem danych.

## Granica IP / organizacja / klient

`devops-toolkit` jest moim prywatnym assetem.

Może być używany w różnych organizacjach i dla różnych klientów.

Zasady:

- repo toolkitu nie przechowuje danych klientów,
- artefakty per klient pozostają po stronie klienta,
- dane operacyjne nie są commitowane do repo toolkitu,
- granica między silnikiem a artefaktami klienta musi pozostać twarda,
- Cloud Detective nie może tej granicy rozmywać.

## Granica względem AI

Zasada pozostaje bez zmian:

- `raw/` nie trafia do AI,
- `normalized/` nadal traktować jako dane klienta,
- do AI mogą trafiać tylko `sanitized/` i `findings/`,
- raport AI musi bazować na danych po sanitizacji,
- Cloud Detective nie może obchodzić tego modelu.

## Granica względem MakoLabu

Cloud Detective może być używany w pracy dla MakoLabu, ale nie jest na tym etapie produktem MakoLabu.

To robocza capability prywatnego toolkitu. Trzeba pilnować rozdziału:

- prywatny silnik,
- artefakty klienta,
- wiedza i dokumenty organizacyjne,
- ewentualne przyszłe materiały ofertowe.

## Poza zakresem

- Publiczna oferta.
- Osobny produkt.
- Własna baza danych.
- Przechowywanie danych klientów w repo toolkitu.
- Automatyczne remediacje.
- Pełny system asset inventory.

## Otwarte pytania

- Czy Cloud Detective potrzebuje osobnego manifestu runa?
- Czy raport powinien mieć własny model danych, czy używać istniejącego finding model?
- Jak długo przechowywać artefakty discovery w repo klienta?
- Czy sanitized context pack dla AI powinien być osobnym outputem?
