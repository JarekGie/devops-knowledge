# devops-toolkit — Decyzje

Lokalne decyzje projektowe. Decyzje architektoniczne cross-projektowe → [[decision-log]].

---

### 2026-04-17 — Model stateless: dane klienta nigdy w repo toolkit

**Kontekst:** Toolkit obsługuje wielu klientów. Ryzyko wycieku danych między klientami lub przypadkowego commitu danych do repozytorium silnika.

**Decyzja:** Repo toolkit zawiera WYŁĄCZNIE kod silnika. Wszystkie artefakty projektowe żyją w `<client-repo>/.devops-toolkit/`. Zasada non-negotiable, weryfikowana przez `make contract-check`.

**Konsekwencje:** Każda operacja wymaga wskazania projektu (CLI flag / workspace lookup / auto-discovery). Brak stanu lokalnego w toolkit repo = brak cache między sesjami.

**Alternatywy odrzucone:** Centralne storage w toolkit repo — odrzucone ze względu na ryzyko data leakage między klientami.

---

### 2026-04-17 — Pipeline-as-code: audyty definiowane w YAML

**Kontekst:** Dodanie nowego audytu wymagało zmian w wielu miejscach kodu (rejestr, dispatcher, dokumentacja).

**Decyzja:** Definicje audytów w plikach YAML (`audits/*.yaml`). Cztery rejestry YAML: collectors, normalizers, sanitizers, rules. Dodanie audytu = wpis w rejestrze + skrypt; bez zmian w silniku.

**Konsekwencje:** Niższy próg dodania nowego audytu. YAML jest source of truth dla pipeline'u. Ryzyko: błędy w YAML trudniejsze do złapania niż błędy kompilacji.

**Alternatywy odrzucone:** Klasy Python per audyt (zbyt dużo boilerplate, trudniejsze utrzymanie dla kolejnych deweloperów).

---

### 2026-04-17 — Security-by-design: sanityzacja obowiązkowa przed AI

**Kontekst:** Toolkit wysyła dane do AI (Claude) w celu generowania analiz. Surowe dane AWS zawierają ARNy, account ID, nazwy zasobów klientów.

**Decyzja:** Dane przechodzą przez sanitizer przed jakimkolwiek kontaktem z AI. AI otrzymuje TYLKO `sanitized/` + `findings/`. Raw data nigdy nie opuszcza środowiska klienta. Egzekwowane na poziomie silnika, nie opcjonalne.

**Konsekwencje:** Bezpieczne użycie zewnętrznego AI nawet dla wrażliwych klientów. Koszt: dodatkowy etap przetwarzania, konieczność utrzymania sanitizerów.

**Alternatywy odrzucone:** Ręczna selekcja co wysłać do AI — odrzucone (zbyt łatwo o błąd ludzki).

---

### 2026-04-17 — Plugin/Capability pattern dla złożonych audytów

**Kontekst:** Część audytów wymaga złożonej logiki wieloetapowej (np. observability-ready = warstwa decyzyjna na aws-logging-audit).

**Decyzja:** Interfejs `BasePlugin` z kontraktem: `name`, `description`, `input/output schema`, metoda `execute(ProjectContext, project_config) → PluginResult`. Toolkit zapisuje artefakty; plugin nie wykonuje I/O.

**Konsekwencje:** Pluginy są testowalne w izolacji. Dodanie nowej capability nie wymaga zmian w CLI. Stateless by design.

**Alternatywy odrzucone:** Inline kod w CLI (nieczytelne, trudne do testowania przy 40+ komendach).

---

### 2026-04-17 — Dual-mode collectors: standalone + engine

**Kontekst:** Potrzeba uruchamiania collectorów zarówno bezpośrednio (debug, development) jak i przez silnik pipeline'u.

**Decyzja:** Każdy collector przyjmuje opcjonalny argument — ścieżkę output. Bez argumentu: standalone (zapisuje do `output/<type>/raw.json + report.md`). Z argumentem: engine mode (zapisuje JSON pod podaną ścieżką).

**Konsekwencje:** Prostszy debug i development bez potrzeby uruchamiania całego pipeline'u. Interface oparty na jednym argumencie — minimalna kompleksowość.

**Alternatywy odrzucone:** Osobne skrypty dla każdego trybu (duplikacja kodu).

---

### 2026-04-17 — Trójwarstwowa konfiguracja: engine / workspace / project

**Kontekst:** Toolkit działa na wielu maszynach operatorów, z wieloma klientami i wieloma projektami per klient.

**Decyzja:** Trzy warstwy konfiguracji z osobnymi plikami i zakresami odpowiedzialności. Resolucja projektu: CLI flag → workspace lookup → auto-discovery (skan CWD w górę) → błąd z instrukcją.

**Konsekwencje:** Operator może obsługiwać dowolną liczbę klientów z jednej instalacji toolkit. Auto-discovery działa "magicznie" gdy CWD jest wewnątrz projektu klienckiego.

**Alternatywy odrzucone:** Pojedynczy plik konfiguracyjny (nie skalowalny przy multi-client setup).

---

### 2026-04-17 — Dokumentacja kontraktów po polsku

**Kontekst:** Zespół jest polskojęzyczny. Kontrakty są wewnętrznymi standardami, nie publiczną dokumentacją.

**Decyzja:** Dokumentacja techniczna architektury w angielskim (`ARCHITECTURE.md`, `docs/*.md`). Kontrakty i standardy deweloperskie w polskim (`docs/kontrakty/`).

**Konsekwencje:** Kontrakty są zrozumiałe dla całego zespołu bez bariery językowej. Potencjalny problem przy onboardingu anglojęzycznych kontrybutorów (mało prawdopodobne w obecnym kontekście).

**Alternatywy odrzucone:** Wszystko po angielsku — odrzucone (kontrakty to dokumenty wewnętrzne, czytelność ważniejsza niż ogólna dostępność).
