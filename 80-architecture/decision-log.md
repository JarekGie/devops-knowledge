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

### ADR-002 — 2026-04-25 — ManagedBy=cloudformation na ręcznie utworzonym SG (planodkupow QA jumphost)
**Status:** accepted  
**Kontekst:** SG `bastionhost-qa` dla jumphosta QA w projekcie planodkupow musiał zostać utworzony przez AWS CLI (out-of-band), ponieważ VPC stack `planodkupow-qa-VPCStack-1V91EF1UIC85A` ma status `UPDATE_ROLLBACK_COMPLETE` i nie może być bezpiecznie aktualizowany. Każdy tagowany zasób w nowej QA VPC (`vpc-007d115c41f079bf3`) ma `ManagedBy=cloudformation`.  
**Decyzja:** SG oznaczony `ManagedBy=cloudformation` mimo CLI creation. `ManagedBy` w tym projekcie opisuje przynależność do domeny operacyjnej DC-devops, nie literalną metodę utworzenia zasobu. Alternatywa `ManagedBy=manual` tworzyłaby singleton prowadzący do false positive w audytach i potencjalnego wykluczenia z FinOps grouping oraz przyszłej Tag Policy.  
**Konsekwencje:** Zasób jest spójny z baselineiem — 100% tagowanych zasobów w VPC ma `cloudformation`. Brak dryftu w audytach. Wyjątek nie jest samoistny — wymaga normalizacji przez IaC gdy stack wróci do bezpiecznego stanu aktualizacji.  
**Alternatywy odrzucone:** `ManagedBy=manual` (singleton, false positive w audytach, ryzyko exclusion z Tag Policy allowed values); `ManagedBy=operations` (niestandaryzowane w tym accountcie).  
**Exit strategy:** Znormalizować przez IaC (import zasobu do CFN lub recreate przez stack) gdy `planodkupow-qa-VPCStack` wróci do stanu `UPDATE_COMPLETE`.

---

<!-- Dodawaj kolejne decyzje poniżej -->
