# NOTEBOOKLM — Kontrakt warstwy syntezy

> NotebookLM nie jest źródłem prawdy. Jest warstwą syntezy: przetwarza wyselekcjonowane fragmenty vault
> i zwraca ustrukturyzowany wynik do vault. Nic poza tym.
> Kontrakt nadrzędny wobec domyślnych zachowań narzędzia.

---

## Zasady operacyjne (non-negotiable)

1. **Vault jest jedynym źródłem prawdy.** NotebookLM nie posiada własnego stanu. Każdy fakt musi mieć pokrycie w źródle z vault.
2. **NotebookLM nie zastępuje vault.** Żaden wynik NotebookLM nie może być traktowany jako decyzja bez zapisu w vault.
3. **NotebookLM nie jest archiwum.** Notebooki nie przechowują aktywnej wiedzy — notatki syntezy zawsze trafiają do vault.
4. **NotebookLM nie zastępuje agentów.** Claude i Codex wykonują; NotebookLM tylko syntetyzuje z zamkniętego, skurowanego zestawu źródeł.
5. **Każde wejście do NotebookLM jest paczką źródłową — nigdy surowym dumpem vault.**

### Dozwolone zastosowania

| Zastosowanie | Opis |
|--------------|------|
| **briefing generation** | Szybkie streszczenie stanu projektu/domeny z wielu notatek |
| **contradiction check** | Wykrycie sprzeczności między notatkami z tego samego zakresu |
| **decision pack** | Zebranie faktów i kontekstu przed konkretną decyzją architektoniczną |
| **handoff pack** | Paczka przejęcia kontekstu między sesjami lub osobami |
| **gap analysis** | Identyfikacja brakujących informacji w zestawie źródeł |

### Niedozwolone zastosowania

- Generowanie runbooków bez weryfikacji w vault
- Zastępowanie Claude/Codex przy decyzjach implementacyjnych
- Używanie jako "drugi brain" równoległy do vault
- Przechowywanie historii konwersacji jako zastępstwo notatek

---

## Topologia notebooków

**Zasada: jeden notebook per domena, nie per projekt.**

### Notebook: Governance

**Zakres:** LLZ, NIS2, Competency Framework, WAF controls, polityki platformy

**Typowe źródła:**
- `20-projects/internal/llz/`
- `30-standards/`
- `80-architecture/decision-log.md`
- `10-areas/` (sekcje compliance i security)

**Kiedy używać:** przegląd stanu compliance, przygotowanie argumentacji do decyzji platformowych, sprawdzenie spójności polityk

---

### Notebook: Toolkit

**Zakres:** devops-toolkit — kontrakty, system pluginów, publiczne API, audyty, architektura CLI

**Typowe źródła:**
- `60-toolkit/`
- `60-toolkit/contracts/`
- `80-architecture/decision-log.md` (sekcje toolkit)

**Kiedy używać:** briefing przed rozwojem nowej komendy, sprawdzenie spójności kontraktów, przygotowanie dokumentacji publicznego API

---

### Notebook: Runtime/Incident

**Zakres:** rshop, planodkupow, pbms, maspex — wzorce operacyjne, runbooki, postmortem, analiza incydentów

**Typowe źródła:**
- `40-runbooks/`
- `20-projects/clients/`
- `02-active-context/` (bez now.md — zbyt ulotny)
- `50-patterns/`

**Kiedy używać:** analiza wzorców przed incydentem, przygotowanie handoffu operacyjnego, cross-project synthesis

---

### Notebook efemeryczny (opcjonalny)

**Zakres:** jednorazowe śledztwo, konkretna decyzja, ograniczony czas życia

**Zasady:**
- Twórz tylko gdy problem wykracza poza jeden notebook domenowy
- Usuń po zamknięciu tematu (nie archiwizuj)
- Nigdy nie ładuj całego vault — tylko dokumenty ściśle dotyczące problemu
- Maksymalny czas życia: 2 tygodnie od ostatniego użycia

---

## Cykl życia notebooka

### Kiedy tworzyć notebook domenowy

- Domena ma min. 5 notatek operacyjnych w vault
- Pytania cross-note pojawiają się więcej niż raz w miesiącu
- Istnieje potrzeba regularnych briefingów lub handoffów w tej domenie

### Kiedy archiwizować notebook

- Domena jest nieaktywna przez > 3 miesiące
- Większość źródeł jest zdezaktualizowanych i nie ma planu ich odświeżenia
- Zakres notebooka został wchłonięty przez inny notebook domenowy

**Przy archiwizacji:** wyeksportuj ostatnie podsumowanie stanu jako notatkę do vault (`20-projects/` lub `10-areas/`), następnie usuń notebook.

### Kiedy używać efemerycznego zamiast domenowego

Użyj efemerycznego gdy:
- Problem jest cross-domenowy i nie pasuje do żadnego notebooka domenowego
- Zagadnienie jest jednorazowe (konkretna awaria, jednorazowa decyzja)
- Chcesz załadować źródła spoza standardowego zestawu notebooka domenowego

---

## Kontrakt wejściowy — source packs

**NotebookLM zawsze otrzymuje skurowaną paczkę źródłową. Nigdy surowy vault.**

### Jak składać paczkę źródłową

1. Zidentyfikuj zakres pytania (projekt, domena, zdarzenie)
2. Wybierz maksymalnie **8–12 plików** bezpośrednio dotyczących zakresu
3. Wyklucz pliki ulotne (`now.md`, pliki tymczasowe, inbox starszy niż tydzień)
4. Wyklucz pliki z innej domeny, nawet jeśli powiązane tematycznie
5. Dodaj `_system/LLM_CONTEXT_GLOBAL.md` jako orientację jeśli NotebookLM jest nowym notebookiem lub sesją

### Wymagany skład paczki (minimum)

| Element | Obowiązkowy? |
|---------|-------------|
| Notatka projektu lub domeny (index/overview) | Tak |
| Aktualne notatki źródłowe dotyczące tematu | Tak |
| `decision-log.md` jeśli temat dotyczy decyzji | Jeśli dotyczy |
| Runbook lub postmortem jeśli temat dotyczy operacji | Jeśli dotyczy |
| `now.md` | Nie — zbyt ulotny |
| Całe katalogi bez selekcji | Nigdy |

---

## Kontrakt wyjściowy — struktura odpowiedzi

**Każdy wynik NotebookLM musi zachować poniższą strukturę. Wynik bez tej struktury jest odrzucany i nie trafia do vault.**

```
## Zakres
<jedno zdanie: co było analizowane i na podstawie jakich źródeł>

## Fakty potwierdzone ze źródeł
<lista faktów z odniesieniem do konkretnego dokumentu źródłowego>

## Sprzeczności
<lista sprzeczności znalezionych między źródłami; BRAK jeśli nie znaleziono>

## Brakujące informacje
<czego brakuje w zestawie źródeł do pełnej odpowiedzi na pytanie>

## Sugerowany następny krok
<jedno konkretne działanie: co zapisać, co zaktualizować, co zbadać>

## Pliki do aktualizacji w vault
<lista ścieżek plików vault, które powinny zostać zaktualizowane na podstawie syntezy>
```

### Zasady jakości wyjścia

- Fakty bez pokrycia w źródłach muszą być jawnie oznaczone jako `[spekulacja]`
- Wynik nie może zawierać rekomendacji implementacyjnych bez wcześniejszej weryfikacji w vault
- Każdy fakt z sekcji "Fakty potwierdzone" musi mieć nazwę dokumentu źródłowego

---

## Protokół interakcji z agentami

### Przepływ handoffu

```
vault (source packs)
  → NotebookLM synthesis
    → notatka syntezy w vault (_chatgpt/context-packs/ lub 02-active-context/)
      → Claude / Codex execution
```

**Każdy krok jest obowiązkowy. Nie pomijaj zapisu do vault między NotebookLM a agentem.**

### Jak Claude/Codex używa wyjścia NotebookLM

1. Odczytaj notatkę syntezy z vault (nie surowy output NotebookLM)
2. Sekcja "Pliki do aktualizacji" → wykonaj jako listę zadań
3. Sekcja "Sugerowany następny krok" → traktuj jako sygnał, nie rozkaz; weryfikuj z `now.md`
4. Sekcja "Sprzeczności" → rozwiąż przed implementacją, nie po
5. Sekcja "Brakujące informacje" → zgłoś użytkownikowi jeśli blokuje zadanie

### Gdzie zapisać notatkę syntezy

| Typ syntezy | Gdzie zapisać |
|-------------|---------------|
| Briefing projektu | `20-projects/<projekt>/` |
| Briefing domenowy | `10-areas/<domena>/` |
| Wynik contradiction check | obok pliku z największą liczbą sprzeczności |
| Decision pack | `80-architecture/decision-log.md` (jako nowy wpis) |
| Handoff pack | `02-active-context/` lub `20-projects/<projekt>/` |
| Gap analysis | `01-inbox/` z datą i tematem |

---

## Szablony promptów NotebookLM

### 1. Briefing

```
Jesteś analitykiem dokumentacji. Na podstawie załadowanych źródeł:

1. Opisz aktualny stan [projektu/domeny] w 3-5 zdaniach.
2. Wymień 3 najważniejsze aktywne decyzje lub ryzyka.
3. Zidentyfikuj co jest nieaktualne lub niepotwierdzone w źródłach.
4. Zaproponuj jeden plik vault do natychmiastowej aktualizacji.

Odpowiedź sformatuj zgodnie z kontraktem wyjściowym:
Zakres / Fakty potwierdzone / Sprzeczności / Brakujące informacje / Następny krok / Pliki do aktualizacji
```

---

### 2. Contradiction Check

```
Przeanalizuj załadowane dokumenty pod kątem sprzeczności.

Szukaj:
- Różnych wartości dla tych samych parametrów (np. rozmiary instancji, limity, CIDR)
- Sprzecznych decyzji architektonicznych opisanych w różnych plikach
- Nieaktualnych stwierdzeń które kolidują z nowszymi dokumentami

Dla każdej sprzeczności podaj:
- Plik A i konkretne twierdzenie
- Plik B i konkretne twierdzenie
- Ocenę: który dokument jest prawdopodobnie aktualny i dlaczego

Odpowiedź sformatuj zgodnie z kontraktem wyjściowym.
```

---

### 3. Decision Pack

```
Przygotowuję decyzję: [opisz decyzję w jednym zdaniu].

Na podstawie załadowanych źródeł:
1. Jakie fakty są potwierdzone i istotne dla tej decyzji?
2. Jakie wcześniejsze decyzje (z decision-log lub runbooków) są powiązane?
3. Jakie ryzyka lub sprzeczności mogą wpłynąć na decyzję?
4. Czego brakuje w źródłach, żeby podjąć tę decyzję pewnie?

NIE sugeruj decyzji — tylko dostarcz fakty i kontekst.

Odpowiedź sformatuj zgodnie z kontraktem wyjściowym.
```

---

### 4. Handoff Pack

```
Przygotowuję handoff dla: [odbiorca lub sesja].

Na podstawie załadowanych źródeł stwórz paczkę przekazania kontekstu:
1. Stan aktualny: co jest wdrożone i działa
2. Aktywne zadania: co jest w toku, gdzie są blokery
3. Otwarte decyzje: co nie zostało rozstrzygnięte
4. Ryzyka: co może się posypać w ciągu 72 godzin
5. Następny krok: jedno konkretne działanie dla odbiorcy

Paczka musi być standalone — odbiorca nie ma dostępu do vault.

Odpowiedź sformatuj zgodnie z kontraktem wyjściowym.
```

---

### 5. Gap Analysis

```
Analizuję kompletność dokumentacji dla: [zakres, np. "wdrożenie LLZ" / "runbooki ECS"].

Na podstawie załadowanych źródeł:
1. Co jest udokumentowane i aktualne?
2. Co jest udokumentowane, ale prawdopodobnie nieaktualne (brak daty lub sprzeczność)?
3. Czego brakuje całkowicie (typowe dla tego zakresu a nieobecne w źródłach)?
4. Które luki są krytyczne operacyjnie (incydent bez tego runbooka = problem)?

Dla każdej krytycznej luki zaproponuj nazwę pliku i katalog w vault.

Odpowiedź sformatuj zgodnie z kontraktem wyjściowym.
```

---

## Minimalny dodatek do struktury vault

Żadna reorganizacja nie jest wymagana. Dodaj tylko jeden opcjonalny katalog jeśli potrzebny:

```
02-active-context/
  notebooklm-synthesis/     ← notatki syntezy z sesji NotebookLM (opcjonalny)
    <data>-<temat>.md
```

Alternatywnie: używaj `_chatgpt/context-packs/` dla notatek syntezy — format jest kompatybilny.

---

*Kontrakt wersja 1.0 — obowiązuje od pierwszej sesji NotebookLM z tym vault.*
