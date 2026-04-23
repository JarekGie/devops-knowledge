# Cloud Detective — pytania otwarte

## Architektura

- Czy Cloud Detective jest osobną capability, packiem, flow czy nazwą zbiorczą?
- Czy potrzebuje osobnego modelu runa?
- Czy korzysta wyłącznie z istniejących `raw/`, `normalized/`, `sanitized/`, `findings/`?
- Czy potrzebny jest osobny model topologii środowiska?
- Jak obsłużyć projekty hybrid: Terraform + CloudFormation + ręczne zasoby?

## Public API / UX

- Czy ma istnieć komenda `toolkit cloud-detective`?
- Czy lepsze jest `toolkit audit-pack cloud-detective`?
- Czy to powinien być alias do zestawu istniejących audit packów?
- Jak mocno nazwa ma być widoczna w CLI?
- Czy UI ma mieć osobną kartę Cloud Detective?

## Relacja do istniejących komend

- Czym Cloud Detective różni się od `discover-aws`?
- Czym różni się od `toolkit audit`?
- Czym różni się od `audit-pack aws-logging` i `observability-ready`?
- Czym różni się od `finops-report`?
- Czy powinien uruchamiać istniejące komendy, czy tylko agregować ich wyniki?

## Model raportów

- Czy głównym artefaktem ma być raport onboardingowy?
- Czy głównym artefaktem ma być raport operatorski?
- Czy głównym artefaktem ma być zestaw findings?
- Jaki minimalny output powinien być uznany za MVP?
- Czy raport ma mieć sekcję "potwierdzone fakty / hipotezy / pytania"?

## Bezpieczeństwo i dane

- Jak wymusić, że raw data nie trafią do AI?
- Czy sanitized context pack dla AI ma być generowany automatycznie?
- Czy normalized data mogą być używane do raportu lokalnego, ale nie do AI?
- Jak oznaczać artefakty safe / not safe?
- Czy Cloud Detective potrzebuje dodatkowych testów data boundary?

## Integracja z wiedzą zespołową

- Czy raport ma linkować do runbooków?
- Czy output ma wspierać Obsidian / Confluence?
- Czy capability ma generować pytania do zespołu po discovery?
- Jak uniknąć sytuacji, gdzie raport zastępuje aktualną dokumentację zamiast ją uzupełniać?

## Naming

- Czy "Cloud Detective" to nazwa robocza, czy docelowa?
- Kiedy naming marketingowy ma sens?
- Czy dla prywatnego toolkitu wystarczy neutralna nazwa typu `environment-assessment`?
- Czy nazwa nie sugeruje osobnego produktu?

## Roadmapa

- Co jest MVP?
- Czy MVP ma działać tylko dla AWS?
- Czy MVP wymaga UI?
- Czy MVP wymaga FinOps?
- Czy najpierw wystarczy raport składany z istniejących audit packów?

## Decyzje do podjęcia później

- Public API.
- Minimalny raport.
- Model danych topologii.
- Zakres AWS services w pierwszej wersji.
- Integracja z UI.
- Poziom automatyzacji AI.
- Czy tworzyć osobną roadmapę dla Cloud Detective.
