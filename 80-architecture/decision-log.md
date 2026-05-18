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

### ADR-003 — 2026-05-07 — secure-ai-anonymizer: local-first + tokenization architecture

**Status:** accepted  
**Kontekst:** Inicjacja projektu secure-ai-anonymizer — pipeline anonimizacji dokumentów klientów przed eksportem do zewnętrznych LLM. Potrzeba technicznego egzekwowania DOMAIN_ISOLATION_CONTRACT i LLM_EXPORT_POLICY vault.  
**Decyzja:** (1) Local-first deployment — dane wrażliwe nie opuszczają środowiska operatora; (2) Tokenization z semantic tags `[KLASA_N]` zamiast masking lub pseudonymization; (3) Presidio + spaCy + custom recognizers jako silnik detekcji; (4) Zewnętrzny LLM wyłącznie po tokenizacji, nigdy automatycznie; (5) PostgreSQL + pgcrypto jako mapping store; (6) Ollama jako sanity-check (nie gatekeeper).  
**Konsekwencje:** Rehydration możliwa, audit trail kompletny, pipeline deterministyczny, offline operability. Trade-off: operator musi manualnie wysyłać do LLM (nie auto-routing) — celowy wybór dla bezpieczeństwa.  
**Alternatywy odrzucone:** Cloud-hosted pipeline (narusza local-first + data sovereignty); masking zamiast tokenizacji (brak rehydration); cloud API do detekcji PII (narusza offline + local-first); automatyczny routing do LLM (niezgodny z LLM_EXPORT_POLICY).  
**Szczegółowe ADR:** `20-projects/internal/secure-ai-anonymizer/adr/` (ADR-001 do ADR-007)

---

### ADR-004 — 2026-05-18 — rshop: BE dev deploy używa bezpośrednich ChangeSetów na child stackach
**Status:** accepted  
**Kontekst:** `eshop-dev-aws-scan-2.jenkinsfile` (BE pipeline) tworzył ChangeSet na parent stacku `dev-ECSStack-1BLAWHL0P6JKO`, co powodowało cascade update do wszystkich nested stacków (FrontendRenault, FrontendDacia, DBStack itd.). Guard (`allowedStacks`) błędnie dopuszczał FE stacki. `aws cloudformation wait` timeoutował po ~15 min.  
**Decyzja:** Dev backend deploy tworzy ChangeSety bezpośrednio na child stackach `api` i `backoffice` (odkrytych przez `describe-stack-resources`), nigdy na parent stacku. Parametr obrazu: `api` i `backoffice` (potwierdzone z CFN templates). Pozostałe parametry: `UsePreviousValue=true` (odkryte dynamicznie). Polling przez `waitUntil(initialRecurrencePeriod: 60000) + timeout(4h)` zamiast `aws cloudformation wait`.  
**Guardrails:** (1) abort jeśli odkryty physical stack == parent; (2) abort jeśli ChangeSet StackId == parent ARN; (3) denied resource types: EC2, RDS, IAM, S3, ELB; (4) abort jeśli changeSet empty/FAILED; (5) abort jeśli stack IN_PROGRESS przed execute.  
**Konsekwencje:** BE dev deploy dotyka wyłącznie `api` i `backoffice` child stacków. FE stacki i infrastruktura są nienaruszalne przez BE pipeline. 4h timeout eliminuje Jenkins abort przy wolnych ECS rolling deployach.  
**Alternatywy odrzucone:** ChangeSet na parent z `--no-execute-changeset` (nie istnieje); ChangeSet na parent z filtetem guard (guard nie może zatrzymać cascade przed create — ryzyko race condition); `aws cloudformation wait` (Max attempts exceeded po ~15 min).  
**Implementacja:** `jenkinsfiles/BE/eshop-dev-aws-scan-2.jenkinsfile`, analogia do `jenkinsfiles/FE/r-shop-all-dev-scan.jenkinsfile` (FE fix z 2026-05-12).  
**Uwaga:** Non-dev path (qa/uat) bez zmian — ChangeSet na parent stack pozostaje.

---

<!-- Dodawaj kolejne decyzje poniżej -->
