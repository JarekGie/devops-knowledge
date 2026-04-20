
Utworzone przez Jarosław Gołąb w lut 14, 2026 25 views since 14 Feb 2026
1. Cel dokumentu
Celem dokumentu jest:
opisanie aktualnego stanu AWS Organization w Makolab,
przedstawienie różnicy pomiędzy stanem sprzed porządkowania a stanem obecnym,
określenie braków względem standardów AWS,
zdefiniowanie dalszych działań prowadzących do poziomu Partner-Ready.
2. Stan wymagany (AWS Partner-Ready)
Zgodnie z rekomendacjami AWS Well-Architected Framework oraz best practices AWS Organizations, organizacja powinna posiadać:
2.1 Struktura organizacyjna
Wyraźne oddzielenie Governance od Workloads
Minimalizacja kont bezpośrednio pod ROOT
Brak pustych OU
Każde konto posiada przypisanego właściciela
2.2 Logging i audyt
Organization CloudTrail (multi-region)
Centralne przechowywanie logów (Log Archive Account)
Włączona walidacja plików logów
Brak zależności od niedokończonych narzędzi (np. Control Tower)
2.3 Bezpieczeństwo (Security Baseline)
Dedykowane konto Security
GuardDuty włączony organizacyjnie
Delegated Admin dla usług security
AWS Config + Aggregator
Minimalne reguły compliance
2.4 Preventive Controls (SCP)
Deny Leave Organization
Deny Disable CloudTrail
Deny Disable GuardDuty
Deny Disable Config
3. Stan przed porządkowaniem (Przed Faza A)
3.1 Organizacja
Niedokończone wdrożenie AWS Control Tower
Historyczne StackSety CT
Role i policy AWSControlTower*
Log groupy i artefakty CT
Trail CT wskazujący na zamknięte konto
Część kont bezpośrednio pod ROOT
Puste OU
Konta bez przypisanego właściciela
3.2 Ryzyka
Niejasny model odpowiedzialności
Potencjalne ryzyko bezpieczeństwa
Trudność w audycie
Brak formalnego modelu governance
Brak centralnego modelu bezpieczeństwa
4. Stan po porządkowaniu (Po Faza A – dzisiaj)
4.1 Usunięte elementy
Wszystkie StackSety AWS Control Tower
Role AWSControlTower*
Lokalne policy AWSControlTower*
Log groupy aws-controltower/*
Nieużywane trail’e Control Tower
Artefakty CT w CloudFormation
4.2 Weryfikacja kosztów
CloudTrail aktywny i poprawnie działający
AWS Config generuje minimalne koszty
GuardDuty obecnie wyłączony
Koszt usług security marginalny (< 1% kosztów organizacji)
4.3 Inwentaryzacja
Pełna lista kont
Pełna lista OU
Wykryte puste OU
Wykryte konta bez przypisanego ownera
Snapshot „ORG CLEAN” zapisany jako dowód stanu
4.4 Aktualna ocena dojrzałości

Obszar
Ocena
Logging	Wysoki
Struktura OU	Niski
Threat Detection	Bardzo niski
Preventive Controls	Brak
Partner Readiness	~50–60%
5. Luki do poziomu Partner-Ready
5.1 Braki strukturalne
Brak dedykowanego konta Security
Zbyt wiele kont pod ROOT
Puste OU do usunięcia
Brak formalnego przypisania ownerów kont
5.2 Braki w bezpieczeństwie
GuardDuty niewłączony organizacyjnie
Brak delegated admin
Brak Config Aggregator
Brak minimalnych SCP
6. Plan działań (Faza B – Governance Baseline)
Etap 1 – Uporządkowanie struktury
Usunięcie pustych OU
Wydzielenie OU:
Governance
Workloads
Migracja kont z ROOT do odpowiednich OU
Etap 2 – Security Foundation
Utworzenie dedykowanego konta Security
Włączenie GuardDuty (org-level)
Konfiguracja delegated admin
Włączenie AWS Config + Aggregator
Etap 3 – Preventive Controls
Wdrożenie minimalnych SCP
Zabezpieczenie przed wyłączeniem logów i security
Etap 4 – Cleanup Legacy
Zamknięcie nieużywanych kont
Formalne przypisanie ownerów
Dokumentacja governance
Szacowany koszt wdrożenia:
~20–50 USD miesięcznie (<1% kosztów organizacji)
7. Wartość biznesowa
Zmniejszenie ryzyka operacyjnego i bezpieczeństwa
Przygotowanie pod AWS Partner Review
Zwiększenie transparentności odpowiedzialności
Skalowalny model dla nowych projektów
Ustandaryzowanie modelu zarządzania chmurą
8. Status inicjatywy
Faza A – Stabilizacja i Cleanup: ✅ Zakończona
Faza B – Governance Baseline: 🔄 Planowana
