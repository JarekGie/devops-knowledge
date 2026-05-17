# mfs-onboarding — Session Log

Format: data, co zrobiono, gdzie skończono, co następne.

---

## 2026-05-17 — Cloud detective snapshot + analiza logów 24h

**Cel:** pierwszy pełny cloud-detective snapshot projektu + analiza logów (24h).

**Co zrobiono:**
1. Wygenerowano plik invocation: `50-patterns/prompts/invocations/cloud-detective-mfs-onboarding.md`
2. Wykonano cloud-detective snapshot GCP runtime (live gcloud + kubectl)
3. Przygotowano ChatGPT context pack: `_chatgpt/context-packs/mfs-onboarding-gcp.md`
4. Wykonano pełną analizę logów 24h (prompt evidence-first, read-only)

**Pliki:**
- `mfs-onboarding-context.md` — runtime snapshot (pewność: częściowa, IaC niezweryfikowane)
- `log-analysis-2026-05-17.md` — analiza logów 24h

**Kluczowe ustalenia (context snapshot):**
- Namespace `rci-onboarding-dev` → `SPRING_PROFILES_ACTIVE=prod`; namespace `rci-onboarding-prod` PUSTY (276d)
- Brak resource limits/requests i probes na kontenerach
- Secret Manager API disabled — sekrety w K8s Secrets
- SSH/RDP firewall otwarte na 0.0.0.0/0
- Fluent-bit DaemonSet disabled — logi przez Cloud Logging → GCS (nie OpenSearch)
- Repo IaC `~/projekty/mako/mfs-orchestration` nieznalezione lokalnie

**Kluczowe ustalenia (analiza logów 24h):**
- System stabilny: 0 restartów, 0 błędów app, 0 OOMKilled
- Brak HTTP access logów — HAProxy loguje do syslog bez sidecar
- Aktywne skanowanie exploit (ThinkPHP RCE, PHP pearcmd) dociera do podów; Tomcat odrzuca
- Port 6060 HAProxy (stats) wystawiony na internet — potwierdzono przez TLS scan
- Ruch aplikacyjny: ~500 req/24h przez RequestFilter; szczyt 10:00 UTC

**Nie wykonano (intentionally):**
- terraform plan/apply
- żadnych zmian w GCP/K8s
- Redis FLUSHALL (nie dotyczy — projekt GCP, nie Maspex)

**Gdzie skończono:** Raport logów zapisany, vault zaktualizowany.

**Następne kroki:**
1. Sklonować repo IaC (`git clone ...` → `~/projekty/mako/mfs-orchestration`)
2. Sprawdzić `target-pools get-health` — stan L4 LB
3. Sprawdzić HAProxy haproxy.cfg pod kątem konfiguracji logowania
4. Decyzja: syslog sidecar dla HAProxy (jedyna droga do HTTP access logów)
5. Decyzja: resource limits + readiness probe dla deployment
6. Decyzja: zamknięcie portów 6060/SSH/RDP (firewall hardening)
