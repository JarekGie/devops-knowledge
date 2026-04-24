# Decision Log — Architektura

Rejestr decyzji architektonicznych. Jedna sekcja = jedna decyzja.  
Dla szczegółowych ADR: kopiuj `templates/decision-template.md`.

#architecture #decisions

## Format

```
### ADR-NNN — YYYY-MM-DD — Tytuł decyzji
**Status:** accepted | deprecated | superseded by ADR-NNN
**Kontekst:** dlaczego ta decyzja była potrzebna
**Decyzja:** co postanowiono
**Konsekwencje:** co z tego wynika (pozytywne i negatywne)
**Alternatywy odrzucone:** co rozważano
```

---

## Decyzje

### ADR-001 — 2026-04-17 — Stateless CLI jako wzorzec dla toolkit
**Status:** accepted  
**Kontekst:** devops-toolkit musi działać w różnych środowiskach (CI, lokalne, multi-klient) bez zarządzania lokalnym state  
**Decyzja:** toolkit jest bezstanowy — żadnego lokalnego DB, state w AWS (S3/DynamoDB jeśli potrzeba), output zawsze do stdout  
**Konsekwencje:** prostszy deployment, łatwiejsze testowanie, brak problem synchronizacji state; wymaga że każda komenda jest self-contained  
**Alternatywy odrzucone:** lokalna SQLite DB (zbyt dużo friction przy CI), API server (za dużo overhead dla CLI)

---

### EXP-001 — 2026-04-24 — CloudOps/SOC-lite: exploration thread otwarty

**Status:** exploration (nie decyzja — brak zatwierdzenia)

**Kontekst:** CEO zapytał Head of Cloud o możliwość wystawienia SOC. Wczesna próba
szerokiej burzy mózgów zakończyła się bez efektu. Równoległy ból operacyjny (AWS Health
events docierające spóźnione) zainicjował konkretny pomysł: integracja AWS Health → GLPI.

**Eksplorowana hipoteza:** Zamiast budowania SOC enterprise, połączyć istniejące capability
(GLPI, Wazuh, LLZ, on-call) w model Prevent → Detect → Respond, zaczynając od pilota
AWS Health → GLPI Problems (dogfooding przez Cloud Support Team).

**Nie jest to decyzja architektoniczna.** Pilot jest wymagany przed jakąkolwiek decyzją.

**Notatki:** [[../20-projects/internal/cloudops-soc-lite/CLOUDOPS_SOC_LITE_HYPOTHESIS]]

<!-- Dodawaj kolejne decyzje poniżej -->
