---
title: Jak korzystać z dashboardów monitoringowych AWS (monitoring-nagios-bot)
project: aws-cloud-platform
type: confluence-page
audience: technical-manager
updated: 2026-05-03
---

# Jak korzystać z dashboardów monitoringowych AWS

**Dla kogo:** Kierowniczka techniczna / tech lead bez backgroundu DevOps  
**Konto monitoringowe:** `monitoring-nagios-bot` (814662658531)  
**Region główny:** Europa (Frankfurt) — `eu-central-1`  
**Ostatnia aktualizacja:** 2026-05-03

---

## 1. Wprowadzenie

### Czym jest konto monitoringowe

W naszej organizacji mamy wiele kont AWS — każdy produkt (RShop, Booking Online, Dacia Asystent itd.) działa w osobnym koncie. Zamiast logować się do każdego z nich oddzielnie, całość widoczności zebraliśmy w jednym miejscu: koncie `monitoring-nagios-bot`.

Możesz myśleć o nim jak o **sali operacyjnej** — wszystkie dane spływają tutaj automatycznie.

### Dlaczego wszystkie dane są w jednym miejscu

Mechanizm nazywa się **cross-account observability** (AWS OAM). Konta produkcyjne „wysyłają" swoje metryki i logi do konta monitoringowego. Ty widzisz je wszystkie w jednym panelu — bez konieczności przełączania się między kontami.

### Czego można się spodziewać na dashboardach

W koncie monitoringowym znajdziesz trzy rodzaje informacji:

| Typ | Co pokazuje | Gdzie |
|-----|-------------|-------|
| **Operacyjne** | Wydajność aplikacji: błędy, czas odpowiedzi, ruch | CloudWatch → Dashboards |
| **Bezpieczeństwo** | Podejrzane aktywności, naruszenia konfiguracji | Security Hub, GuardDuty |
| **Zgodność** | Czy zasoby spełniają polityki firmy | AWS Config |

---

## 2. Jak się dostać do dashboardów

### Krok 1 — Zaloguj się do AWS Console

1. Otwórz: **https://console.aws.amazon.com**
2. Zaloguj się przy użyciu swojego konta IAM (e-mail + hasło + MFA jeśli wymagane)
3. Jeśli masz dostęp przez SSO (logowanie firmowe) — użyj przycisku **"Sign in with SSO"**

### Krok 2 — Przełącz się na konto monitoringowe

Po zalogowaniu sprawdź w prawym górnym rogu, które konto jest aktywne.

Jeśli nie jest to `monitoring-nagios-bot`:
1. Kliknij nazwę konta w prawym górnym rogu
2. Wybierz **"Switch role"**
3. Wpisz:
   - Account ID: `814662658531`
   - Role name: `OrganizationAccountAccessRole` (lub inna rola jaką masz przypisaną)
   - Display name: np. `monitoring`

> **Do potwierdzenia w środowisku:** dokładna nazwa roli do której masz dostęp — skonsultuj z DevOps.

### Krok 3 — Upewnij się, że jesteś w regionie Frankfurt

W prawym górnym rogu obok nazwy konta powinno być `Europe (Frankfurt)` lub `eu-central-1`. Jeśli nie — kliknij i zmień.

> Niektóre dashboardy Health Notifications są w regionie `us-east-1` (Wirginia Północna) — to normalne dla usług globalnych AWS.

---

### Nawigacja do konkretnych narzędzi

#### CloudWatch (dashboardy operacyjne)

1. W wyszukiwarce na górze wpisz: `CloudWatch`
2. W lewym menu wybierz: **Dashboards**
3. Zobaczysz listę dostępnych dashboardów

#### Security Hub (bezpieczeństwo)

1. W wyszukiwarce wpisz: `Security Hub`
2. Kliknij **Findings** lub **Summary** w lewym menu

#### AWS Config (zgodność konfiguracji)

1. W wyszukiwarce wpisz: `Config`
2. Kliknij **Rules** lub **Dashboard** w lewym menu

#### GuardDuty (wykrywanie zagrożeń)

1. W wyszukiwarce wpisz: `GuardDuty`
2. Kliknij **Findings** w lewym menu

---

## 3. Typy dashboardów i jak je czytać

### 3.1 CloudWatch — dashboardy operacyjne

#### Co zobaczysz

W CloudWatch → Dashboards znajdziesz dashboardy przygotowane przez DevOps. Dostępne dashboardy:

| Nazwa | Co pokazuje |
|-------|-------------|
| **Organization Health Overview** | Przegląd całej organizacji — główny panel startowy |
| **SLO — RShop** | Wskaźniki wydajności sklepu RShop |
| **SLO — Booking Online** | Wskaźniki wydajności Booking Online |
| **SLO — Dacia Asystent** | Wskaźniki wydajności Dacia Asystent |
| **Cost Explorer summary** | Przegląd kosztów |

#### Najważniejsze wskaźniki na dashboardach SLO

Każdy dashboard SLO pokazuje dwie rzeczy:

**Error rate (wskaźnik błędów)** — jaki procent żądań do aplikacji kończy się błędem.
- ✅ Norma: poniżej 1%
- ⚠️ Uwaga: 1–5%
- 🔴 Problem: powyżej 5%

**Latency p99 (czas odpowiedzi)** — czas oczekiwania na odpowiedź dla 99% użytkowników.
- ✅ Norma dla RShop: poniżej 2 sekund
- ✅ Norma dla Booking / Dacia: poniżej 3 sekund
- 🔴 Problem: przekroczenie tych progów

#### Jak interpretować wykresy

**Spike (nagły skok)** — krótki, jednorazowy wzrost na wykresie, który wraca do normy.
- Zazwyczaj nie wymaga reakcji — może to być jednorazowy ruch lub deploy
- Jeśli spike trwa dłużej niż 5–10 minut → zgłoś do DevOps

**Utrzymany wzrost** — wykres idzie w górę i nie wraca.
- Wymaga analizy → zgłoś do DevOps

**Brak danych (pusta linia lub przerwa w wykresie)** — aplikacja przestała wysyłać metryki.
- Może oznaczać, że usługa nie działa
- Może też oznaczać problem z monitoringiem
- Zawsze zgłoś do DevOps jeśli brak danych trwa ponad 15 minut

**Alarm w kolorze czerwonym / pomarańczowym** — CloudWatch automatycznie zaznacza przekroczenie progu. Kolor na wykresie lub ikonka przy alarmie.

---

### 3.2 Bezpieczeństwo — GuardDuty i Security Hub

#### Czym jest „finding"

**Finding** = zdarzenie, które system bezpieczeństwa uznał za potencjalnie podejrzane. Nie każdy finding to incydent — część to fałszywe alarmy lub niskie ryzyko.

Analogia: finding to jak alarm w samochodzie. Może oznaczać włamanie, ale może też reagować na silny wiatr.

#### Poziomy severity (powagi)

| Poziom | Kolor | Co oznacza |
|--------|-------|------------|
| **CRITICAL** | Czerwony | Poważne zagrożenie — natychmiastowa reakcja DevOps |
| **HIGH** | Pomarańczowy | Wysokie ryzyko — eskaluj do DevOps w ciągu 24h |
| **MEDIUM** | Żółty | Umiarkowane ryzyko — DevOps ocenia w normalnym trybie |
| **LOW** | Niebieski | Niskie ryzyko — tło, najczęściej nie wymaga akcji |
| **INFORMATIONAL** | Szary | Informacja — nie wymaga reakcji |

#### Gdzie patrzeć w Security Hub

**Summary** — strona główna Security Hub. Pokazuje:
- Liczbę aktywnych findingów w podziale na severity
- Trendy (czy liczba rośnie czy maleje)
- Najgorsze konta

**Findings** — lista wszystkich zdarzeń. Możesz filtrować po:
- `Severity` — wybierz CRITICAL lub HIGH żeby zobaczyć najważniejsze
- `Workflow status: NEW` — tylko nieprzetworzone przez DevOps
- `Record state: ACTIVE` — tylko aktywne

#### Kiedy reagować na finding w Security Hub

| Sytuacja | Co robić |
|----------|----------|
| CRITICAL lub HIGH, status NEW | Zgłoś do DevOps natychmiast |
| CRITICAL lub HIGH, status NOTIFIED lub RESOLVED | DevOps już pracuje — możesz zapytać o status |
| MEDIUM, status NEW | Zgłoś do DevOps w normalnym trybie (nie pilne) |
| LOW lub INFORMATIONAL | Nie wymaga akcji z Twojej strony |

#### GuardDuty — co pokazuje

GuardDuty to system wykrywający podejrzane zachowania na kontach AWS. Przykłady findingów:

- Logowanie z nieznanej lokalizacji geograficznej
- Wykonanie niezwykłej liczby wywołań API
- Próba dostępu do zablokowanych zasobów
- Podejrzane wzorce ruchu sieciowego

Zasada: jeśli widzisz finding HIGH lub CRITICAL w GuardDuty → eskaluj do DevOps bez analizowania.

---

### 3.3 Zgodność — AWS Config

#### Co to jest AWS Config

AWS Config sprawdza, czy zasoby w chmurze spełniają zdefiniowane zasady (reguły). Wyobraź sobie audytora, który co chwilę sprawdza czy konfiguracja spełnia wymagania polityki firmy.

#### Co oznaczają statusy

| Status | Co oznacza |
|--------|------------|
| ✅ **COMPLIANT** | Zasób spełnia regułę — wszystko OK |
| ❌ **NON_COMPLIANT** | Zasób nie spełnia reguły — wymaga analizy |
| ⬜ **NOT_APPLICABLE** | Reguła nie dotyczy tego zasobu — ignoruj |
| ⏳ **INSUFFICIENT_DATA** | Config jeszcze nie sprawdził — poczekaj |

#### Wdrożone reguły — co sprawdzają

| Reguła | Co sprawdza | Priorytet |
|--------|-------------|-----------|
| `CLOUD_TRAIL_ENABLED` | Czy włączone jest śledzenie aktywności | Wysoki |
| `IAM_ROOT_ACCESS_KEY_CHECK` | Czy konto główne (root) nie ma aktywnych kluczy API | Wysoki |
| `MULTI_REGION_CLOUD_TRAIL_ENABLED` | Czy śledzenie działa we wszystkich regionach | Wysoki |
| `S3_BUCKET_PUBLIC_READ_PROHIBITED` | Czy publiczne odczyty z S3 są zablokowane | Wysoki |
| `S3_BUCKET_PUBLIC_WRITE_PROHIBITED` | Czy publiczne zapisy do S3 są zablokowane | Wysoki |

#### Dlaczego NON_COMPLIANT nie zawsze to incydent

Przykłady NON_COMPLIANT które NIE są incydentem:
- Konto w stanie SUSPENDED (zawieszone) — reguły go dotyczą, ale konto jest nieaktywne
- Zasoby tymczasowe (sandbox, testy) — mogą mieć inne standardy
- Nowe konto tuż po utworzeniu — Config potrzebuje czasu na skanowanie

Przykłady NON_COMPLIANT które SĄ poważne:
- `S3_BUCKET_PUBLIC_READ_PROHIBITED` — NONCOMPLIANT na koncie produkcyjnym = publiczne dane
- `IAM_ROOT_ACCESS_KEY_CHECK` — NONCOMPLIANT = aktywny klucz API na koncie root

> **Zasada:** NON_COMPLIANT na koncie produkcyjnym (planodkupow, RShop, Booking_Online, dacia-asystent, CC) → eskaluj do DevOps.

---

## 4. Najczęstsze scenariusze

### Scenariusz A: „Widzę czerwony alarm na dashboardzie CloudWatch"

1. Sprawdź **który dashboard** i **który wskaźnik** jest czerwony (error rate? latency? coś innego?)
2. Sprawdź **od kiedy** — kliknij alarm, zobaczysz historię
3. Sprawdź czy to **ciągłe** czy **jednorazowe**
4. Jeśli alarm trwa ponad 10 minut → **zgłoś do DevOps**

Informacje do przekazania DevOps:
- Nazwa dashboardu i wskaźnika
- Godzina początku alarmu
- Obecna wartość vs próg (np. „error rate 3.5%, próg 1%")

---

### Scenariusz B: „Widzę NON_COMPLIANT w AWS Config"

1. Sprawdź **która reguła** jest niezgodna
2. Sprawdź **które konto** i **który zasób**
3. Oceń czy to konto produkcyjne czy testowe/zawieszone

**Jeśli konto produkcyjne** → zgłoś do DevOps (nie jest to awaria, ale wymaga naprawy w ciągu 48h)

**Jeśli konto zawieszone (SUSPENDED)** → możesz zignorować lub zapytać DevOps przy okazji

**Jeśli reguła dotyczy S3 lub CloudTrail na koncie produkcyjnym** → zgłoś do DevOps priorytetowo

---

### Scenariusz C: „Widzę wzrost ruchu lub kosztów"

W Cost Explorer summary na CloudWatch lub w AWS Cost Explorer:

1. Sprawdź **który serwis** generuje wzrost
2. Sprawdź **które konto**
3. Porównaj z poprzednim tygodniem/miesiącem

Normalne przyczyny wzrostu (nie eskaluj):
- Kampania marketingowa → więcej użytkowników → więcej ruchu
- Koniec miesiąca / rozliczenia cykliczne
- Nowy deploy, który włączył dodatkowe zasoby (DevOps powinien był poinformować)

Nienormalne przyczyny (eskaluj do DevOps):
- Nagły 2–3x wzrost bez powodu biznesowego
- Wzrost na koncie testowym/sandbox
- Nieznana usługa pojawiła się w kosztach

---

### Scenariusz D: „Widzę finding HIGH w Security Hub"

1. Kliknij finding aby zobaczyć szczegóły
2. Sprawdź:
   - **Title** — krótki opis co się stało
   - **Account** — które konto dotyczy
   - **Workflow status** — czy DevOps już to widział
3. Jeśli `Workflow status = NEW` → **zgłoś do DevOps w ciągu 24h**
4. Jeśli `Workflow status = NOTIFIED` → DevOps jest w toku, możesz zapytać o status
5. Jeśli `Workflow status = RESOLVED` → sprawa zamknięta

Informacje do przekazania DevOps:
- Finding ID (widoczny w szczegółach)
- Tytuł findingu
- Konto i region

---

### Scenariusz E: „Dostałam e-mail z alertem AWS Health"

E-maile przychodzą na adres `ops@makolab.com` i `glpi-aws-alerts@makolab.pl`.

Format tematu: `[GLPI][AWS][HEALTH][NAZWA_KONTA][REGION][SERWIS][ISSUE] KOD_ZDARZENIA`

Co robić:
1. Przeczytaj opis zdarzenia w treści maila
2. Sprawdź którego konta i serwisu dotyczy
3. Przekaż do właściciela workloadu (jeśli dotyczy konkretnej aplikacji) + poinformuj DevOps
4. DevOps śledzi zdarzenie i komunikuje się z AWS Support jeśli potrzeba

---

## 5. Czego NIE robić

### Nie traktuj automatycznie jako incydentu

| Co widzisz | Dlaczego to nie incydent |
|------------|------------------------|
| LOW / INFORMATIONAL w Security Hub | Tło szumu bezpieczeństwa — znane, śledzone przez DevOps |
| NON_COMPLIANT na koncie SUSPENDED | Konto jest wyłączone, reguły nie mają znaczenia operacyjnego |
| Jednorazowy spike na wykresie (trwa < 5 min) | Chwilowy szczyt ruchu, deploy, restart usługi |
| INSUFFICIENT_DATA w Config | Config jeszcze nie ocenił zasobu — poczekaj |
| Stare findingi (Workflow: RESOLVED) | Sprawa zamknięta przez DevOps |
| Wzrost kosztów po nowym projekcie/kampanii | Planowany wzrost, nie anomalia |

### Nie klikaj „Remediate", „Disable", „Delete" ani nic podobnego

Konsola AWS daje wiele przycisków które mogą zmienić konfigurację. Jako obserwator dashboardów — nie musisz i nie powinieneś nic zmieniać. Jeśli coś wymaga naprawy → DevOps to robi.

### Nie interpretuj jednego wskaźnika w izolacji

Wzrost CPU sam w sobie to nie problem jeśli błędy są 0% i czas odpowiedzi jest normalny. Zawsze patrz na kombinację wskaźników.

---

## 6. Kiedy eskalować do DevOps

### Eskaluj natychmiast (pilne)

| Sytuacja | Przykład |
|----------|----------|
| CRITICAL finding w Security Hub lub GuardDuty | Finding z tytułem „Unauthorized API Call" na koncie produkcyjnym |
| Alarm error rate > 5% na produkcji i trwa > 10 min | RShop error rate 7%, alarm aktywny od 15 minut |
| Brak danych na dashboardzie przez > 15 min | Wykres SLO Booking Online — brak linii od 20 minut |
| Email AWS Health z kategorią `issue` lub `investigation` | Temat: [GLPI][AWS][HEALTH][RShop][...][RDS][ISSUE] |
| Nieznany zasób lub konto pojawia się w raportach | W Security Hub pojawia się konto którego nie znasz |

### Eskaluj w normalnym trybie (nie pilne, w ciągu 24–48h)

| Sytuacja | Przykład |
|----------|----------|
| HIGH finding w Security Hub, status NEW | Nowy finding wysoki priorytet, DevOps nie widział |
| NON_COMPLIANT na koncie produkcyjnym | Config raportuje brak CloudTrail na koncie RShop |
| Utrzymany wzrost latency powyżej SLO | Dacia Asystent p99 = 5 sekund od wczoraj |
| Wzrost kosztów > 30% bez wyjaśnienia biznesowego | Koszty EC2 wzrosły x2 w tym tygodniu |

### Informacje które warto przekazać przy eskalacji

```
1. Co widzisz (screenshot lub opis)
2. Gdzie (konto, region, serwis, dashboard)
3. Od kiedy
4. Czy coś się zmieniło w biznesie (kampania, nowy launch, planowany deploy)
```

---

## 7. TL;DR dla kierowniczki — 5 punktów

**1. Gdzie patrzeć na co dzień**
→ CloudWatch → Dashboards → `Organization Health Overview` + dashboardy SLO
→ Security Hub → Summary (liczba HIGH/CRITICAL powinna być bliska 0)

**2. Co jest ważne (wymaga reakcji)**
→ Alarm SLO trwa ponad 10 minut
→ Security Hub: nowe finding HIGH lub CRITICAL
→ Brak danych na dashboardzie ponad 15 minut
→ E-mail AWS Health z kategorią `issue`

**3. Co możesz ignorować**
→ LOW / INFORMATIONAL w Security Hub
→ Jednorazowe spike'i na wykresach (< 5 minut)
→ NON_COMPLIANT na kontach SUSPENDED
→ Findingi ze statusem RESOLVED

**4. Kiedy reagować**
→ CRITICAL / HIGH + status NEW = eskaluj do DevOps
→ Trwały alarm SLO (> 10 min) = eskaluj do DevOps
→ Wzrost kosztów bez wyjaśnienia = zapytaj DevOps

**5. Czego nie robić**
→ Nie klikaj żadnych przycisków Remediate / Delete / Disable
→ Nie interpretuj jednego wskaźnika w izolacji
→ Nie zakładaj że brak alarmów = wszystko OK — sprawdzaj aktywnie

---

## Appendix — dla DevOps

### Mapowanie dashboard → źródło danych

| Dashboard / widok | Źródło danych | Mechanizm |
|-------------------|---------------|-----------|
| CloudWatch SLO dashboards | Metryki z kont RShop, Booking, Dacia, planodkupow | OAM links → monitoring sink `observabilitySink` |
| Organization Health Overview | Metryki agregowane z wielu kont | OAM cross-account, management account sink |
| Security Hub Findings | GuardDuty, Config, Security Hub findings ze wszystkich kont | Security Hub delegated admin (monitoring account) |
| GuardDuty Findings | GuardDuty detectors na wszystkich kontach member | GuardDuty delegated admin (monitoring account) |
| AWS Config Rules | Config recorders na 11 kontach member | CloudFormation StackSet z management account |
| AWS Health e-maile | AWS Health API (us-east-1, wszystkie konta) | EventBridge → Lambda `health-notify` → SNS |

### Gdzie to jest skonfigurowane w Terraform

| Komponent | Moduł Terraform | Opis |
|-----------|----------------|------|
| CloudWatch OAM (sinks + links) | `platform/monitoring/` | OAM sink w monitoring account, OAM links w kontach workload |
| SLO alarms i dashboardy | `platform/monitoring/` | CloudWatch Alarms i Dashboard resources |
| Security Hub org-wide | `platform/security/security-hub/` | Delegated admin + org config + standardy FSBP/CIS |
| GuardDuty org-wide | `security/guardduty/` | Delegated admin + org auto-enable |
| AWS Config org-wide | `platform/security/config/` | Aggregator + StackSet dla recorderów + 5 reguł |
| Health notifications | `platform/health-notifications/` | EventBridge rule → Lambda → SNS |
| Budgets i anomaly detection | `platform/budgets/` + `platform/finops/` | AWS Budgets per konto + Cost Anomaly Detection |

### SLO thresholds (do alertów CloudWatch)

| Workload | Konto | Error rate SLO | Latency p99 SLO |
|----------|-------|---------------|-----------------|
| RShop | 943111679945 | < 1% | < 2 s |
| Booking_Online | 128264038676 | < 1% | < 3 s |
| dacia-asystent | 074412166613 | < 1% | < 3 s |

### Dostęp do konsoli — role

Rola do użycia: `OrganizationAccountAccessRole` w koncie `814662658531` (monitoring-nagios-bot).

Profile AWS CLI: `cd-monitoring-nagios-bot` (generowany przez `scripts/generate-cloud-detective-profiles.sh`).

> Do potwierdzenia w środowisku: lista użytkowników IAM z dostępem do konta monitoring — weryfikacja w IAM.
