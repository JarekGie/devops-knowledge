# Cloud Detective — use case'y robocze

## 1. Onboarding nowego klienta / środowiska

Cel: szybko zrozumieć konto, projekt lub repo infrastruktury.

Wejście:

- repo klienta,
- dostęp read-only do AWS,
- `.devops-toolkit/project.yaml` albo dane do onboardingu.

Oczekiwany output:

- raport startowy,
- mapa głównych zasobów,
- lista luk i pytań,
- wskazanie kolejnych audytów.

Wartość operatorska: mniej czasu na ręczne rozpoznanie.

Ryzyka / ograniczenia:

- brak pełnej wiedzy bez dostępu do IaC,
- brak pełnej wiedzy bez tagów,
- różne konta mogą mieć różną jakość danych.

## 2. Read-only discovery AWS

Cel: zebrać obraz środowiska bez zmian w zasobach.

Wejście:

- AWS profile,
- region,
- zakres usług do sprawdzenia.

Oczekiwany output:

- raw artifacts lokalnie w repo klienta,
- normalized summary,
- sanitized findings.

Wartość operatorska: powtarzalne discovery zamiast ręcznego zestawu komend.

Ryzyka / ograniczenia:

- uprawnienia read-only mogą być niepełne,
- multi-account wymaga osobnego modelu,
- discovery nie zastępuje wiedzy aplikacyjnej.

## 3. Wygenerowanie raportu operatorskiego

Cel: dostać krótki techniczny raport do dalszej pracy.

Wejście:

- wyniki discovery,
- wyniki audit packów,
- opcjonalnie kontekst IaC.

Oczekiwany output:

- raport Markdown,
- lista findings,
- otwarte pytania,
- rekomendowane read-only checks.

Wartość operatorska: szybki dokument roboczy dla zespołu lub klienta.

Ryzyka / ograniczenia:

- raport nie może udawać pewności tam, gdzie dane są niepełne,
- trzeba oddzielać fakty od hipotez.

## 4. FinOps assessment jako wejście do dalszej pracy

Cel: zidentyfikować kosztowe punkty startowe.

Wejście:

- Cost Explorer,
- tagi,
- okres raportowania,
- opcjonalnie środowisko.

Oczekiwany output:

- koszt per service / usage type,
- delta,
- untagged cost,
- pytania o ownership i środowiska.

Wartość operatorska: szybki start do rozmowy FinOps.

Ryzyka / ograniczenia:

- brak tagów ogranicza jakość wniosków,
- Cost Explorer ma opóźnienia,
- nie każdy wzrost kosztów oznacza problem.

## 5. Governance / tagging / observability assessment

Cel: sprawdzić podstawowe standardy operacyjne.

Wejście:

- audit packi tagging,
- aws-logging,
- observability-ready,
- opcjonalnie IaC.

Oczekiwany output:

- stan tagowania,
- stan logowania,
- gaps,
- blocker / warning / investigate.

Wartość operatorska: szybkie określenie, czy środowisko jest operowalne.

Ryzyka / ograniczenia:

- część wyników może być `UNKNOWN`,
- mapowanie Terraform może być niepełne,
- capability nie zastępuje ręcznej review krytycznych systemów.

## 6. Przyspieszenie analizy incydentu

Cel: szybciej ustalić topologię i punkty obserwowalne przy incydencie.

Wejście:

- projekt,
- region,
- usługa / domena / symptom,
- istniejące logi i metryki.

Oczekiwany output:

- ścieżka requestu lub zależności,
- dostępne log groups,
- brakujące telemetry,
- lista read-only checks.

Wartość operatorska: mniej czasu na szukanie, gdzie w ogóle patrzeć.

Ryzyka / ograniczenia:

- incydent nadal wymaga analizy człowieka,
- discovery może być zbyt wolne dla ostrego firefightu,
- brak telemetry ogranicza diagnozę.

## 7. Pytania i edge case'y

- Co z multi-account?
- Co z organizacjami, gdzie nie ma IaC?
- Co z projektami hybrydowymi Terraform + CloudFormation?
- Czy output ma być jeden raport, czy kilka artefaktów?
- Jak oznaczać poziom pewności findings?
- Jak odróżnić "brak danych" od "brak problemu"?
