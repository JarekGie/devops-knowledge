# Cloud Detective — wizja robocza

## Problem

Wejście w nowe środowisko cloud jest często wolne i fragmentaryczne.

Typowe objawy:

- brak szybkiej mapy środowiska,
- wiedza rozproszona między AWS, Terraform, CI/CD, runbookami i ludźmi,
- ręczne zbieranie danych zajmuje zbyt dużo czasu,
- raport operatorski trzeba składać od zera,
- assessment FinOps / governance / observability startuje bez wspólnego obrazu,
- discovery musi być read-only, żeby nie zwiększać ryzyka.

## Hipoteza wartości

Cloud Detective może skrócić czas od "nie znam środowiska" do "mam techniczny obraz startowy".

Robocza wartość:

- szybsze wejście w środowisko,
- szybsze wytworzenie mapy i raportu,
- mniej ręcznego zbierania danych,
- lepszy punkt startowy do FinOps / governance / observability assessment,
- lepsze wsparcie pracy konsultacyjnej i operatorskiej.

## Dla kogo

- operator DevOps/SRE wchodzący w nowe konto lub projekt,
- konsultant robiący assessment,
- osoba przygotowująca onboarding środowiska,
- zespół potrzebujący bazowego raportu technicznego.

Nie ograniczać myślenia wyłącznie do klientów MakoLabu.

## Efekt operacyjny

Minimalny efekt powinien być konkretny:

- gdzie jestem,
- jakie są główne zasoby,
- jakie są zależności,
- jakie są oczywiste luki,
- co warto sprawdzić dalej,
- które dane są potwierdzone, a które są hipotezą.

## Jakie capability mogą wchodzić w skład

Hipotezy:

- AWS discovery,
- topology summary,
- ownership / tagging assessment,
- FinOps starting point,
- observability readiness,
- logging coverage,
- IaC detection,
- risk and gap summary,
- onboarding report,
- sanitized AI context pack dla dalszej analizy.

## Czego nie chcemy zbudować

- Kolejnego pełnego CMDB.
- Systemu, który przechowuje dane klientów w repo toolkitu.
- Automatycznego narzędzia naprawczego bez audit-first i dry-run.
- Marketingowego wrappera bez realnego outputu.
- AI procesu, który czyta raw AWS data.

## Otwarte pytania

- Czy Cloud Detective ma być packiem, komendą, flow czy nazwą capability?
- Jaki jest najmniejszy sensowny raport?
- Czy discovery ma być tylko AWS na start?
- Jak silnie integrować to z UI?
- Jak mierzyć skuteczność: czas onboardingu, jakość raportu, liczba znalezionych luk?
