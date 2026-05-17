---
title: "Log Analysis — mfs-onboarding — 2026-05-17"
date: 2026-05-17
type: log-analysis
environment: prod
project: mfs-onboarding
gcp_project: rci-orchestration
analyst: claude-sonnet-4-6
---

# Raport analizy logów — mfs-onboarding

## VERDICT

**System działa stabilnie. Brak evidence awarii, błędów aplikacyjnych ani problemów infrastrukturalnych w ostatnich 24h.**

Krytyczna luka: **brak HTTP access logów** — HAProxy nie loguje ruchu HTTP do Cloud Logging (syslog bez sidecar). Nie jest możliwe potwierdzenie liczby requestów, rozkładu statusów HTTP, latency ani ścieżek z błędami. Wszystkie wnioski o ruchu HTTP opierają się wyłącznie na minimalistycznych logach aplikacji (`Request logged` bez URL/status/latency).

Wykryto aktywne skanowanie bezpieczeństwa osiągające pody aplikacji — Tomcat odrzuca ataki na poziomie parsowania HTTP, brak RCE. Wymaga uwagi.

---

## Zakres analizy

| Parametr | Wartość |
|----------|---------|
| GCP project | rci-orchestration |
| Region | europe-west2 |
| Cluster | rci-cluster (K8s 1.33.10-gke.1115000) |
| Namespace aplikacji | rci-onboarding-dev (prod workload) |
| Czas analizy | ostatnie 24h: 2026-05-16T13:14 UTC — 2026-05-17T13:16 UTC |
| Źródła logów sprawdzone | Cloud Logging: stdout/stderr (haproxy-controller, rci-onboarding-dev), k8s_node events, gce_instance |
| Źródła logów niedostępne | HAProxy HTTP access logs (syslog), OpenSearch VM OS logs, GCEGuestAgent/OSConfigAgent |

**Jak zmienić zakres czasu:**
```bash
# Ostatnia 1h:
gcloud logging read "..." --freshness=2h --limit=500

# Ostatnie 7 dni:
gcloud logging read "..." --freshness=168h --limit=1000

# Konkretny przedział (UTC):
gcloud logging read "... timestamp>=\"2026-05-16T10:00:00Z\" timestamp<=\"2026-05-16T12:00:00Z\"" --limit=500
```

---

## Fakty

Tylko informacje potwierdzone przez komendy wykonane w tej sesji:

1. Architektura ruchu: Internet → GCP TCP Target Pool (L4, port 80/443) → HAProxy NodePort 31515/30430 → Service rci-onboarding-dev (NodePort 30901) → 3 pody (10.48.0.5, 10.48.2.8, 10.48.4.7:8080)
2. HAProxy HTTP access logi są kierowane do syslog (nie stdout/stderr) — w Cloud Logging nie istnieją
3. Aplikacja loguje każdy request jako `Request logged` (c.m.r.config.RequestFilter) bez URL, statusu, latency
4. W 24h zalogowano ~500 requestów przez RequestFilter, szczyt o 10:00 UTC (100 wpisów)
5. 4 ataki bezpieczeństwa dotarły do podów aplikacji (PHP pearcmd + ThinkPHP RCE), wszystkie odrzucone przez Tomcat z `IllegalArgumentException`
6. 5 błędów TLS ClientHello na porcie 6060 HAProxy (port statystyk) z IP 66.132.172.100 i 66.132.172.137 — zewnętrzne skanery
7. Wszystkie 3 pody: Running, 0 restartów w 27h, 0 OOMKilled, CPU 2-3m, Memory 226-255Mi
8. 5 node warnings `NodeSysctlChange` (net.netfilter.nf_conntrack_acct=1) na wszystkich 5 nodach o 16:16-16:33 UTC 2026-05-16
9. 1 kubelet warning dla secret volume mount (pod systemowy, nie aplikacyjny, jednorazowy)
10. GCP health check sprawdza HAProxy `/healthz` na porcie 30137 co 8s (timeout 1s, unhealthy threshold 3)
11. OpenSearch VM: RUNNING, 0 logów OS dostępnych w Cloud Logging w ostatnich 24h
12. Brak events w namespace rci-onboarding-dev, brak non-Normal events w klastrze (ostatnie 24h)

---

## Load Balancer / Ingress

| Komponent | Źródło logów | Logi dostępne | HTTP access logi | Evidence |
|-----------|--------------|---------------|------------------|----------|
| GCP TCP Target Pool L4 | — | nie dotyczy (L4, brak HTTP log) | brak | `gcloud compute backend-services list` → 0 items |
| GCP HTTP(S) LB | — | nie istnieje | brak | `gcloud compute url-maps list` → 0 items |
| HAProxy (K8s Ingress Controller) | Cloud Logging stdout/stderr | stdout: **puste** | **brak** | HAProxy loguje HTTP do syslog (nie stdout); brak syslog sidecar |
| HAProxy stderr (port 6060) | Cloud Logging stderr | **5 wpisów / 24h** | nie dotyczy | TLS scan z 66.132.172.100/137 |

**Rozkład HTTP statusów:** `brak evidence` — HTTP access logi niedostępne.

**Latency:** `brak evidence` — HAProxy nie loguje do Cloud Logging.

**Backend health check (GCP):**
- Health check `a6b33017894a44e3d88106baaa935ee0` → port `30137` (HAProxy healthz), path `/healthz`
- checkInterval: 8s, timeout: 1s, unhealthyThreshold: 3
- Target pool ma 5 instancji (wszystkie 5 GKE nodes)
- Stan health checks: `brak evidence` — `gcloud compute target-pools get-health` nie wykonano

**HAProxy stderr — TLS scan na porcie 6060:**

| Czas (UTC) | Źródłowy IP | Port docelowy | Opis |
|-----------|-------------|---------------|------|
| 2026-05-16T16:00–10 (3× w 01:00) | brak evidence per IP — patrz stderr | 6060 (stats) | TLS ClientHello na HTTP-only porcie statystyk |
| 2026-05-17T09:59 | 66.132.172.137 | 6060 | j.w. |
| 2026-05-17T10:00 | 66.132.172.137 | 6060 | j.w. |
| 2026-05-17T10:32 | 66.132.172.100 | 6060 | j.w. |
| 2026-05-17T10:33 | 66.132.172.100 | 6060 | j.w. |

Wnioski: Port 6060 jest wystawiony na internet przez regułę firewall `k8s-fw-a6b33017894a44e3d88106baaa935ee0`. Skanery próbują TLS na HTTP port — błąd niekrytyczny, ale port statystyk nie powinien być dostępny zewnętrznie.

---

## GKE / Kubernetes

| Namespace | Deployment | Pods ready | Restarty | Events krytyczne | OOMKilled | Probe failures | Evidence |
|-----------|-----------|-----------|---------|------------------|-----------|----------------|---------|
| rci-onboarding-dev | rci-onboarding-dev | 3/3 | 0 (27h) | brak | brak | brak (brak probes) | live kubectl |
| haproxy-controller | haproxy-kubernetes-ingress | 2/2 | 0 (26h) | brak | brak | brak | live kubectl |
| observability | grafana | 1/1 | 0 (26h) | brak | brak | brak | live kubectl |
| logging | fluent-bit-opensearch | 0/0 (disabled) | — | — | — | — | live kubectl |

**Node warnings (wszystkie 5 nodów, 2026-05-16T16:16-16:33 UTC):**

| Reason | Message | Ocena |
|--------|---------|-------|
| `NodeSysctlChange` | `net.netfilter.nf_conntrack_acct: "1"` | INFO — informacyjny sysctl zmieniony poza GKE (unmanaged). Typowe przy node pool operacjach lub zewnętrznej konfiguracji. Brak wpływu na aplikację. |

**Kubelet warning (jednorazowy, 2026-05-16T10:26 UTC):**
- `nestedpendingoperations` — failed volume mount dla `kubernetes.io/secret/3ac1d8ed...`
- Pod systemowy (nie aplikacyjny), jednorazowe, brak powtórzeń — `brak dalszego wpływu`

**Zasoby (live, kubectl top):**

| Pod | CPU | Memory | Node memory% |
|-----|-----|--------|-------------|
| 85tb9 | 3m | 255Mi | node 2b: 51% |
| 9j4l4 | 2m | 226Mi | node 2a: 59% |
| mgvhs | 2m | 233Mi | node 2c: 62% |

Niska utilization CPU. Memory na nodach 44–62% — umiarkowana, brak pressure. Brak resource limits na kontenerach → nie można określić marginesu bezpieczeństwa.

---

## Aplikacja

**RequestFilter traffic (24h, ~500 requestów przez Cloud Logging sink):**

| Godzina UTC | Liczba "Request logged" | Trend |
|------------|------------------------|-------|
| 2026-05-16 21:00 | 5 | – |
| 2026-05-16 22:00 | 8 | – |
| 2026-05-16 23:00 | 5 | – |
| 2026-05-17 00:00–03:00 | ~3 | noc, minimalny ruch |
| 2026-05-17 04:00–05:00 | ~8 | – |
| 2026-05-17 06:00 | 22 | wzrost |
| 2026-05-17 07:00 | 64 | szczyt poranny |
| 2026-05-17 08:00 | 57 | – |
| 2026-05-17 09:00 | 49 | – |
| 2026-05-17 10:00 | 100 | **szczyt dobowy** |
| 2026-05-17 11:00 | 85 | – |
| 2026-05-17 12:00 | 73 | – |
| 2026-05-17 13:00 (partial) | 21 | – |

⚠️ Uwaga: Cloud Logging sink ma limit 500 wpisów. Prawdziwa liczba requestów może być wyższa — `brak evidence` dla pełnego wolumenu.

**Błędy aplikacyjne — ataki bezpieczeństwa:**

| Czas (UTC) | Pod | Typ ataku | Path (skrócony) | Wynik |
|-----------|-----|-----------|-----------------|-------|
| 2026-05-16T21:00:09 | 85tb9 | ThinkPHP RCE | `/public/index.php?s=/index/\think\app/invokefunction...` | Odrzucony — `IllegalArgumentException` (Tomcat RFC 7230) |
| 2026-05-16T21:00:10 | mgvhs | ThinkPHP RCE | j.w. | Odrzucony |
| 2026-05-16T21:00:11 | 9j4l4 | PHP pearcmd path traversal + code injection | `/index.php?lang=../../../../pearcmd...<?echo(md5("hi"));?>...` | Odrzucony |
| 2026-05-17T11:18:27 | 85tb9 | PHP pearcmd path traversal + code injection | j.w. | Odrzucony |

Wnioski:
- Ataki dotarły **bezpośrednio do podów aplikacji** (past HAProxy) — HAProxy nie blokuje malformed requests na poziomie path
- Tomcat (Spring Boot embedded) odrzuca je na etapie parsowania nagłówka HTTP — brak RCE
- Wzorzec: 3 pody w tym samym czasie (~01:00 UTC) = automatyczny scanner skanujący wszystkie endpointy
- Brak WAF ani żadnej warstwy blokowania exploit patterns przed aplikacją

---

## VM / GCE / OpenSearch

| Instance | Zone | Status | Logi OS w Cloud Logging | Evidence |
|----------|------|--------|-------------------------|---------|
| opensearch-instance | europe-west2-a | RUNNING | **brak** — GCEGuestAgent/OSConfigAgent nie logują do Cloud Logging | live gcloud |
| GKE nodes (5×) | 2a/2b/2c | RUNNING | serialconsole (1 wpis: hrtimer interrupt, niekrytyczny) | Cloud Logging |

**opensearch-instance (serial console):**
- Jedyny wpis w 24h: `hrtimer: interrupt took 1433213 ns` (2026-05-17T12:28 UTC) — kernel timing warning, niekrytyczne, typowe dla VM
- Stan OS, utilization CPU/disk/memory: `brak evidence` — brak agenta monitorującego w Cloud Logging
- Czy OpenSearch process działa: `brak evidence` — brak logów aplikacyjnych OpenSearch w Cloud Logging

**Fluent-bit → OpenSearch pipeline:** DaemonSet soft-disabled (0/0 desired, `node selector: soft-disabled=true`). Logi aplikacji **nie są kierowane do OpenSearch**. Aktualny flow: Cloud Logging → sink GCS.

---

## Korelacja czasowa

| Przedział (UTC) | LB / HAProxy | GKE / Nodes | Aplikacja | VM / OpenSearch | Wniosek |
|----------------|-------------|-------------|-----------|-----------------|---------|
| 2026-05-16 16:16–16:33 | brak evidence | NodeSysctlChange (5 nodów) | brak logów | brak logów | GKE node pool operacja lub zewnętrzna konfiguracja sysctl. Brak wpływu na aplikację. |
| 2026-05-16 21:00–01:00 (UTC) | brak evidence | brak events | 4 ataki (ThinkPHP, pearcmd) | brak logów | Automatyczny scanner przeskanował wszystkie 3 pody. Odrzucone przez Tomcat. Ruch nocny aplikacji: 3-8 req/h. |
| 2026-05-17 07:00–10:00 | brak evidence | brak events | szczyt 64-100 req/h | brak logów | Normalny ruch roboczy. Brak anomalii w dostępnych logach. |
| 2026-05-17 10:32–10:33 | TLS scan na porcie 6060 | brak events | brak błędów | brak logów | Scanner z 66.132.172.100 uderzył w port statystyk HAProxy. Niezwiązane z ruchem aplikacyjnym. |

---

## Hipotezy

**[HIPOTEZA 1] Prawdziwy wolumen ruchu HTTP jest znacznie wyższy niż ~500 req/24h**
- Dlaczego możliwa: Cloud Logging sink jest skonfigurowany z filtrem `logName="projects/.../logs/stdout"` dla `rci-onboarding-dev`. Log sink może mieć limit przepustowości lub aplikacja loguje tylko część requestów przez RequestFilter.
- Evidence wspierające: RequestFilter loguje "Request logged" bez szczegółów — może być skonfigurowany do logowania tylko wybranych requestów (np. tylko /api/*, albo tylko zalogowanych userów)
- Czego brakuje do potwierdzenia: HAProxy HTTP access logs; konfiguracja klasy RequestFilter w kodzie aplikacji

**[HIPOTEZA 2] Port 6060 HAProxy jest dostępny z internetu przez regułę firewall**
- Dlaczego możliwa: Reguła `k8s-fw-a6b33017894a44e3d88106baaa935ee0` otwiera porty 80, 443, 1024, **6060** na `0.0.0.0/0`. HAProxy service wystawia port 6060 na NodePort 30452.
- Evidence wspierające: TLS skan z zewnętrznych IP skutecznie trafił na port 6060 (błędy w logach)
- Czego brakuje do potwierdzenia: `gcloud compute firewall-rules describe k8s-fw-...` (źródłowe IP 0.0.0.0/0 potwierdzone wcześniej)

**[HIPOTEZA 3] OpenSearch nie otrzymuje świeżych logów aplikacyjnych od dłuższego czasu**
- Dlaczego możliwa: Fluent-bit DaemonSet disabled, aktualne logi idą do GCS — nie do OpenSearch
- Evidence wspierające: `kubectl get ds -n logging → desired=0, soft-disabled=true`
- Czego brakuje do potwierdzenia: Data ostatniego logu w OpenSearch, konfiguracja `soft-disabled` (kiedy i dlaczego wyłączono)

---

## Ryzyka

| Ryzyko | Kategoria | Poziom | Evidence |
|--------|-----------|--------|---------|
| Brak HTTP access logów — niemożność detekcji anomalii, błędów, attacków | Observability | WYSOKI | HAProxy syslog bez sidecar |
| Aktywne skanowanie exploit (ThinkPHP, pearcmd) dotiera do podów | Security | WYSOKI | 4 udokumentowane próby; Tomcat odrzuca, ale brak blokady przed aplikacją |
| Port 6060 (HAProxy stats) wystawiony na internet | Security | WYSOKI | TLS scan z zewnętrznych IP potwierdził dostępność |
| SSH/RDP otwarte na 0.0.0.0/0 (default VPC + rci VPC) | Security | WYSOKI | `gcloud compute firewall-rules list` (odkryto w poprzednim scanie) |
| Brak resource limits → OOM/CPU throttle niemierzalne | Operational | WYSOKI | `kubectl describe deploy → resources: {}` |
| Brak liveness/readiness probes → traffic do unhealthy poda | Operational | WYSOKI | `kubectl describe deploy` brak Liveness/Readiness |
| Memory nodów 44-62% bez limits → brak headroom | Operational | ŚREDNI | `kubectl top nodes` |
| OpenSearch bez świeżych logów (Fluent-bit disabled) | Observability | ŚREDNI | live kubectl |
| GCE VM OpenSearch bez monitoringu w Cloud Logging | Observability | ŚREDNI | brak GCEGuestAgent w Cloud Logging |
| Brak uptime checks dla onboarding.rciservices.eu | Observability | ŚREDNI | `gcloud monitoring uptime list-configs` → 0 |

---

## Braki w observability

| Co nie dało się potwierdzić | Przyczyna | Impact |
|-----------------------------|-----------|--------|
| HTTP request count, statusy (2xx/4xx/5xx), latency | HAProxy loguje do syslog — brak syslog sidecar w kontenerze | Niemożna ocenić błędów HTTP, latency SLO, anomalii ruchu |
| URL/path per request, response codes z aplikacji | RequestFilter loguje tylko `Request logged` bez szczegółów | Brak korelacji błędów z endpointami |
| Pełny wolumen requestów (>500 może być limit sink) | Cloud Logging sink bez gwarancji kompletności | Ryzyko false negative przy niskim ruchu w logach |
| Stan OpenSearch process (czy działa, logi aplikacyjne) | GCEGuestAgent nie loguje do Cloud Logging; brak agenta OS | OpenSearch health nieznany |
| GCP health check status (czy nody są healthy w Target Pool) | `get-health` nie wykonano | Nieznany stan L4 LB |
| Alert policies | `gcloud alpha monitoring` wymaga komponentu nieinstalowanego interaktywnie | Monitoring alertów nieznany |
| Konfiguracja RequestFilter (jakie requesty loguje) | Brak repo IaC lokalnie, brak dostępu do kodu aplikacji | Niejasne czy ~500 req/24h to pełny ruch |

---

## Następne kroki

### Read-only follow-up

```bash
# 1. Stan health checks Target Pool (czy nody są healthy)
gcloud compute target-pools get-health a6b33017894a44e3d88106baaa935ee0 \
  --region europe-west2 --project rci-orchestration

# 2. HAProxy stats page (wewnętrznie przez kubectl port-forward)
kubectl port-forward -n haproxy-controller deployment/haproxy-kubernetes-ingress 1024:1024
# Następnie: curl http://localhost:1024/haproxy-runtime-monitor

# 3. Sprawdź dokładną konfigurację HTTP access log w HAProxy
kubectl exec -n haproxy-controller deployment/haproxy-kubernetes-ingress \
  -- cat /etc/haproxy/haproxy.cfg 2>/dev/null | grep -i log

# 4. Sprawdź czy RequestFilter loguje wszystkie requesty czy subset
# (wymaga dostępu do kodu aplikacji lub konfiguracji Spring)

# 5. Sklonuj repo IaC dla pełnej analizy Terraform
git clone <REPO_URL> ~/projekty/mako/mfs-orchestration

# 6. Stan OpenSearch — sprawdź czy process działa przez SSH lub serial console
gcloud compute ssh opensearch-instance --zone europe-west2-a --project rci-orchestration \
  -- "systemctl status opensearch; df -h; free -m" --dry-run  # tylko planowanie
```

### Low-risk change proposals (wymagają zatwierdzenia)

| Akcja | Uzasadnienie | Ryzyko |
|-------|-------------|--------|
| Dodać syslog sidecar do HAProxy deployment (np. `haproxy-syslog`) | Jedyna droga do HTTP access logów | Niski — dodanie kontenera sidecar |
| Skonfigurować Cloud Monitoring uptime check dla `onboarding.rciservices.eu` | Podstawowy health monitoring endpointu | Brak |
| Dodać resource limits/requests do deployment | Ochrona przed OOM i CPU starvation | Niski — wymaga kalibracji wartości |
| Dodać readiness probe (`/actuator/health` lub `/health`) | Traffic routing do zdrowych podów | Niski — wymaga potwierdzenia health endpoint w Spring Boot |

### Dangerous actions requiring approval

| Akcja | Ryzyko | Dlaczego wymaga zatwierdzenia |
|-------|--------|-------------------------------|
| Zamknięcie portów 6060, SSH (0.0.0.0/0) w firewall | Może przerwać istniejące połączenia, CI/CD, administrację | Modyfikacja firewall — wymaga inventory wszystkich użytkowników reguł |
| Włączenie Secret Manager API + migracja K8s Secrets | Zmiana sposobu dostarczania sekretów do podów | Wymaga rolling deploy lub restart podów |
| Re-enable Fluent-bit DaemonSet | Nieznane dlaczego wyłączono — może być celowe | Wymaga wyjaśnienia powodu wyłączenia |

---

## READ-ONLY COMMANDS USED

```bash
# Kontekst i autentykacja
gcloud auth list
gcloud config get project
kubectl config current-context

# Discovery LB / Ingress
kubectl get ingress -A -o wide
kubectl get svc -A -o wide
kubectl get pods -A -o wide | grep -i haproxy
kubectl get endpoints -n rci-onboarding-dev
kubectl describe ingress rci-onboarding-ingress -n rci-onboarding-dev
gcloud compute forwarding-rules list --project rci-orchestration
gcloud compute backend-services list --project rci-orchestration
gcloud compute url-maps list --project rci-orchestration
gcloud compute target-http-proxies list --project rci-orchestration
gcloud compute target-https-proxies list --project rci-orchestration
gcloud compute target-pools list --project rci-orchestration
gcloud compute http-health-checks describe a6b33017894a44e3d88106baaa935ee0 --project rci-orchestration
gcloud logging logs list --project rci-orchestration

# HAProxy config i logi
kubectl get configmap -n haproxy-controller
kubectl get deployment haproxy-kubernetes-ingress -n haproxy-controller -o jsonpath=...
gcloud logging read (haproxy-controller stdout, freshness=25h, limit=200)
gcloud logging read (haproxy-controller stderr, freshness=25h, limit=500)

# GKE / Kubernetes
kubectl get deploy,rs,pods,svc,endpoints,ingress -n rci-onboarding-dev -o wide
kubectl get pods -n rci-onboarding-dev --show-labels
kubectl get events -n rci-onboarding-dev --sort-by=.lastTimestamp
kubectl get events -A --sort-by=.lastTimestamp | grep -v Normal
kubectl describe pods -n rci-onboarding-dev
kubectl top pods -n rci-onboarding-dev
kubectl top nodes

# Logi aplikacji
gcloud logging read (rci-onboarding-dev stdout, severity>=ERROR, freshness=25h, limit=200)
gcloud logging read (rci-onboarding-dev stderr, freshness=25h, limit=100)
gcloud logging read (rci-onboarding-dev stdout "Request logged", freshness=25h, limit=500)
gcloud logging read (rci-onboarding-dev stdout "IllegalArgumentException", freshness=25h, limit=200)

# VM / Nodes
gcloud compute instances list --project rci-orchestration
gcloud logging read (gce_instance severity>=WARNING, freshness=25h, limit=100)
gcloud logging read (gce_instance all, freshness=25h, limit=30)
gcloud logging read (k8s_node severity>=WARNING, freshness=25h, limit=50)
gcloud logging read (GCEGuestAgent/OSConfigAgent, europe-west2-a, freshness=25h, limit=20)
```

## DANGEROUS ACTIONS NOT PERFORMED

```
- Nie zrestartowano żadnych podów
- Nie patchowano żadnych deploymentów, serwisów, ingressów
- Nie modyfikowano reguł firewall
- Nie modyfikowano log sinków ani IAM
- Nie wykonywano terraform plan/apply
- Nie modyfikowano konfiguracji HAProxy
- Nie re-enableowano Fluent-bit DaemonSet
- Nie włączano Secret Manager API
- Nie skalowano deploymentów
- Nie wchodzono (exec) na żadne pody ani VM
```
