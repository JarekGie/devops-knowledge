---
title: mfs-onboarding-context
client: mako
project: mfs-onboarding
domain: client-work
document_type: runtime-context
context_type: cloud-detective-snapshot
classification: internal
source_of_truth: false
runtime_snapshot: true
cloud: gcp
gcp_project_id: rci-orchestration
gcp_project_number: "38390674701"
auth_method: gcloud_interactive
regions:
  - europe-west2
extra_regions: []
iac: terraform
repository: "~/projekty/mako/mfs-orchestration (niezweryfikowane — repo nie znalezione lokalnie)"
created: "2026-05-17"
updated: "2026-05-17"
last_verified: "2026-05-17"
scan_method: cloud-detective-v2
last_verified_by: claude-sonnet-4-6
tags:
  - gcp
  - gke
  - terraform
  - mako
  - mfs-onboarding
  - rci-orchestration
---

# mfs-onboarding — RCI Orchestration (GCP)

#gcp #gke #terraform #mako #mfs-onboarding

**Data:** 2026-05-17
**Typ dokumentu:** snapshot runtime / context wejściowy
**Source of truth:** GCP live + Kubernetes runtime
**Tryb skanowania:** read-only
**Poziom pewności snapshotu:** częściowa — runtime GCP w pełni przeskanowany; IaC niezweryfikowane (repo lokalne nie znalezione)
**Projekt:** Spring Boot onboarding service deployowany na GKE w GCP project `rci-orchestration`, klient RCI/MakoLab
**Account:** jaroslaw.golab@makolab.com
**GCP Project ID:** `rci-orchestration`
**GCP Project Number:** `38390674701`
**Region główny:** `europe-west2`

---

## Snapshot metadata

| Pole | Wartość |
|------|---------|
| scan_date | 2026-05-17 |
| scan_scope | partial |
| regions_checked | europe-west2 |
| repo_checked | nie — repo `~/projekty/mako/mfs-orchestration` nie znalezione lokalnie |
| iac_checked | nie |
| runtime_checked | tak — GKE, Compute, GCS, Logging, IAM, Networking |
| extra_regions_checked | nie dotyczy |

---

## Zakres snapshotu vs audytu

| Obszar | Typ | Zakres | Źródło |
|--------|-----|--------|--------|
| Runtime health (GKE/Pods/Services) | snapshot | live GCP | live GCP |
| Networking / VPC | snapshot | live GCP | live GCP |
| IAM service accounts | snapshot | live GCP | live GCP |
| IaC analiza | snapshot | niezweryfikowane (brak repo) | - |
| Terraform state | snapshot | lokalizacja potwierzona (GCS bucket) | live GCP |
| Tagging / labels coverage | snapshot | sample-based | live GCP |
| FinOps / cost allocation | audit | niezweryfikowane | - |
| Secret management | snapshot | Secret Manager API disabled | live GCP |
| Observability | snapshot | częściowe | live GCP |

---

## Repozytorium kodu

- lokalna ścieżka: `~/projekty/mako/mfs-orchestration` — **nie znalezione** (katalog nie istnieje)
- remote: niezweryfikowane
- aktywny branch: niezweryfikowane
- IaC: **Terraform** (Źródło: `goog-terraform-provisioned` label na zasobach + state bucket w GCS)
- Terraform state: `gs://rci-remote-terraform-state/prod/state/`

---

## Środowiska

| Env | Region | GCP Project | Status | Pewność |
|-----|--------|-------------|--------|---------|
| prod (faktyczny) | europe-west2 | rci-orchestration | aktywny | wysoka — live |
| dev (namespace) | europe-west2 | rci-orchestration | aktywny (ale Spring=prod!) | wysoka — live |

> ⚠️ **Uwaga naming:** namespace `rci-onboarding-dev` uruchamia `SPRING_PROFILES_ACTIVE=prod`. Namespace `rci-onboarding-prod` jest pusty. Środowisko produkcyjne działa w namespace nazwanym "dev". Patrz sekcja Znane problemy.

---

## Architektura

```
Internet (0.0.0.0/0)
  │
  ▼ 35.189.115.120 (TCP Load Balancer / Target Pool, europe-west2)
  │
  ▼ HAProxy Ingress Controller (haproxy-controller namespace)
    Deployment: haproxy-kubernetes-ingress, 2/2 Running
    Service: LoadBalancer 35.189.115.120:80,443,1024,6060
    TLS: onboarding.rciservices.eu → secret prod-cert
  │
  ▼ rci-onboarding-dev Service (NodePort 8080:30901)
  │
  ▼ Deployment: rci-onboarding-dev (3/3 Running)
    Image: europe-west1-docker.pkg.dev/rci-orchestration/mfs-onboarding/onboarding-master:ver-64
    Spring profile: prod  ← !! namespace = dev, ale profile = prod
    Namespace: rci-onboarding-dev

GKE Cluster: rci-cluster (europe-west2, 5x e2-medium)
  Namespaces aktywne z workloadem:
  - rci-onboarding-dev  ← PROD workload (Spring=prod)
  - rci-onboarding-prod ← PUSTY
  - haproxy-controller  ← Ingress
  - observability       ← Grafana (ClusterIP only)
  - logging             ← Fluent-bit (DISABLED)

OpenSearch VM: opensearch-instance (n2-standard-2, CentOS Stream 9)
  Public IP: 35.189.90.45 (rci-public subnet 10.0.2.0/24)
  Ports: 5601 (Dashboards), 9200 (API) ← whitelist IP
  Logstash: port 5555 ← z GKE pod range + specific IP

GCS:
  rci-logs-prod-europe-west2  ← Cloud Logging sink (stdout+stderr z rci-onboarding-dev)
  rci-remote-terraform-state  ← Terraform state

Artifact Registry:
  europe-west1-docker.pkg.dev/rci-orchestration/mfs-onboarding/
  └── onboarding-master:ver-64 (aktywny)
```

---

## Mikroserwisy / komponenty

| Serwis | Namespace | Type | External | Port | Desired | Running | Status |
|--------|-----------|------|----------|------|---------|---------|--------|
| rci-onboarding-dev | rci-onboarding-dev | NodePort | nie | 8080→30901 | 3 | 3 | ✅ Running |
| haproxy-kubernetes-ingress | haproxy-controller | LoadBalancer | 35.189.115.120 | 80,443,1024,6060 | 2 | 2 | ✅ Running |
| grafana | observability | ClusterIP | nie | 3000 | 1 | 1 | ✅ Running |
| fluent-bit-opensearch | logging | DaemonSet | nie | 2020 | 0 | 0 | ⚠️ DISABLED |
| opensearch-instance | (VM, nie K8s) | Compute Engine | 35.189.90.45 | 5601, 9200 | - | RUNNING | ✅ Running |

---

## Zasoby kluczowe

| Zasób | Identyfikator | Źródło | Pewność |
|-------|---------------|--------|---------|
| GKE Cluster | `rci-cluster` (europe-west2) | live GCP | wysoka |
| Container Image | `europe-west1-docker.pkg.dev/rci-orchestration/mfs-onboarding/onboarding-master:ver-64` | live K8s | wysoka |
| Artifact Registry repo | `mfs-onboarding` (DOCKER) | live GCP | wysoka |
| External IP (Ingress) | `35.189.115.120` | live GCP | wysoka |
| OpenSearch VM | `opensearch-instance` (europe-west2-a, n2-standard-2) | live GCP | wysoka |
| OpenSearch Public IP | `35.189.90.45` | live GCP | wysoka |
| TF state bucket | `gs://rci-remote-terraform-state/prod/state/` | live GCP | wysoka |
| Logs bucket | `gs://rci-logs-prod-europe-west2` | live GCP | wysoka |
| Hostname (TLS) | `onboarding.rciservices.eu` | live K8s ingress | wysoka |
| VPC | `rci-orchestration` (custom mode) | live GCP | wysoka |

---

## Secret Manager

Secret Manager API **nie jest włączone** w projekcie `rci-orchestration`.

Sekrety aplikacyjne są przechowywane jako Kubernetes Secrets:

| Secret | Namespace | Typ | Przeznaczenie |
|--------|-----------|-----|---------------|
| `prod-cert` | rci-onboarding-dev | kubernetes.io/tls | TLS cert dla onboarding.rciservices.eu |
| `regcred` | rci-onboarding-dev | kubernetes.io/dockerconfigjson | Pull image z Artifact Registry (stary) |
| `gcpcred` | rci-onboarding-dev | kubernetes.io/dockerconfigjson | Pull image z Artifact Registry (nowy, 275d) |

Możliwe alternatywne źródła sekretów aplikacyjnych (niezweryfikowane):
- Kubernetes ConfigMap (brak poza kube-root-ca.crt — 0 ConfigMaps aplikacyjnych)
- Hardcoded w aplikacji lub kontenerze — do weryfikacji
- CI/CD credentials (pipeline niezweryfikowany)

---

## Networking

| Zasób | Wartość |
|-------|---------|
| VPC główna | `rci-orchestration` (custom subnet mode) |
| Subnet private | `rci-private`: 10.0.1.0/24 (europe-west2) |
| Subnet public | `rci-public`: 10.0.2.0/24 (europe-west2) |
| Subnet GKE PE | `gke-rci-cluster-1990db8b-pe-subnet`: 172.16.0.0/28 (europe-west2) |
| VPC default | auto-mode (legacy, wiele regionów) |

### Firewall — uwagi bezpieczeństwa

| Reguła | Risk |
|--------|------|
| `default-allow-ssh` (0.0.0.0/0 → port 22) | ⚠️ WYSOKI — SSH otwarty na cały internet (default VPC) |
| `default-allow-rdp` (0.0.0.0/0 → port 3389) | ⚠️ WYSOKI — RDP otwarty na cały internet |
| `rci-orchestration-allow-ssh` (0.0.0.0/0 → port 22) | ⚠️ WYSOKI — SSH otwarty (rci VPC) |
| `opensearch` (whitelist IPs → 5601, 9200) | ✅ IP-restricted |
| `logstash` (34.142.105.34 → 5555) | ✅ IP-restricted |

---

## Observability

**Runtime health (live, 2026-05-17):**

| Element | Status | Uwagi |
|---------|--------|-------|
| rci-onboarding-dev pods | ✅ 3/3 Running, 0 restarts | Uptime 26h (ostatni restart ~2026-05-16) |
| HAProxy Ingress | ✅ 2/2 Running | |
| Grafana | ✅ 1/1 Running | ClusterIP — brak zewnętrznego ingress (niezweryfikowane czy jest osobny dostęp) |
| Fluent-bit | ⚠️ DISABLED | `soft-disabled=true` node selector — 0/0 desired. Logi trafiają do GCS przez Cloud Logging sink (nie przez Fluent-bit) |
| OpenSearch VM | ✅ RUNNING | n2-standard-2, CentOS Stream 9 |

**Cloud Logging sinks:**

| Sink | Destination | Scope |
|------|-------------|-------|
| rci-k8s-app-logs-to-gcs | `gs://rci-logs-prod-europe-west2` | stdout z rci-onboarding-dev |
| rci-k8s-app-stderr-to-gcs | `gs://rci-logs-prod-europe-west2` | stderr z rci-onboarding-dev |

**Log-based metrics:**
- `rci_onboarding_dev_stdout_errors` — zlicza Exception, IllegalArgumentException, HTTP parse errors
- `rci_onboarding_dev_stdout_total` — zlicza wszystkie stdout logi

**Monitoring dashboards:**
- "OpenSearch instance monitoring"
- "GCE & Network Monitoring"

**Uptime checks:** 0 skonfigurowanych

**Alert policies:** niezweryfikowane (wymaga `gcloud alpha` lub Console)

---

## Tagging / FinOps / GCP Labels readiness

**Bieżący scan:** sample-based (OpenSearch VM — jedyny zasób z potwierdzonym labelem `goog-terraform-provisioned: true`)

| Obszar | Status | Uwagi |
|--------|--------|-------|
| GCP Labels — GKE cluster | niezweryfikowane | `gcloud container clusters describe` nie wykonano |
| GCP Labels — Compute Engine | PARTIAL | opensearch-instance: `goog-terraform-provisioned: true`; brak labels aplikacyjnych (env, project, owner) |
| GCP Labels — GCS buckets | niezweryfikowane | |
| GCP Labels — Artifact Registry | niezweryfikowane | |
| K8s labels na podach | niezweryfikowane | kubectl describe nie sprawdzono pod kątem labels |
| IAM — service account governance | PARTIAL | 6 SA, w tym `claude-gcp-report-reader` — celowy SA dla raportowania Claude |
| Secret Manager | GAP | API wyłączone; sekrety w K8s Secrets |
| GCP Cost allocation labels | niezweryfikowane | |

### Wymagane labels (GCP odpowiednik LLZ)

| Label | Status |
|-------|--------|
| `environment` / `env` | niezweryfikowane |
| `project` | niezweryfikowane |
| `managed-by` | PARTIAL (goog-terraform-provisioned na VM) |
| `owner` / `team` | niezweryfikowane |

### Wniosek

Brak Secret Manager API i K8s Secrets jako jedyne przechowywanie sekretów aplikacyjnych to istotna luka governance. Labels/tagi GCP nie były weryfikowane w pełnym zakresie — wymagany dedykowany audyt. Brak uptime checks i alert policies — luka observability.

### Następne kroki

| Akcja | Priorytet | Kto |
|-------|-----------|-----|
| Wyjaśnić naming: namespace "dev" z SPRING=prod | WYSOKI | DevOps / Dev |
| Włączyć Secret Manager API, migrować sekrety z K8s Secrets | WYSOKI | DevOps |
| Dodać resource limits/requests do deployment | WYSOKI | DevOps / Dev |
| Dodać liveness/readiness probes | WYSOKI | DevOps / Dev |
| Zamknąć `default-allow-ssh` i `default-allow-rdp` na 0.0.0.0/0 | WYSOKI | DevOps |
| Skonfigurować HPA | ŚREDNI | DevOps |
| Skonfigurować uptime checks i alert policies | ŚREDNI | DevOps |
| Zlokalizować / sklonować repo IaC lokalnie | ŚREDNI | DevOps |
| Audyt GCP labels coverage | NISKI | DevOps |

---

## GKE / runtime config

| Parametr | Wartość |
|----------|---------|
| Cluster | `rci-cluster` |
| Location | `europe-west2` (regional) |
| Status | RUNNING |
| Kubernetes version | 1.33.10-gke.1115000 |
| Node pool | `primary-node-pool`, e2-medium, 5 nodes (2a: 2, 2b: 1, 2c: 2) |
| Deployment image | `onboarding-master:ver-64` |
| Replicas | 3/3 Running |
| Strategy | RollingUpdate (maxSurge 25%, maxUnavailable 25%) |
| Resource limits | **brak** (resources: {}) |
| Resource requests | **brak** |
| Liveness probe | **brak** |
| Readiness probe | **brak** |
| HPA | **brak** |
| Spring profile | `prod` (przez env SPRING_PROFILES_ACTIVE) |
| Ingress class | `haproxy` |
| TLS hostname | `onboarding.rciservices.eu` |

---

## Znane problemy / dług techniczny

| Problem | Priorytet | Evidence | Opis |
|---------|-----------|----------|------|
| Namespace naming vs Spring profile mismatch | WYSOKI | `kubectl get deployment -n rci-onboarding-dev` → `SPRING_PROFILES_ACTIVE=prod` | Namespace nazywa się `rci-onboarding-dev`, ale aplikacja działa z profile=prod. Namespace `rci-onboarding-prod` jest pusty. Ryzyko: deployments do złego namespace, konfuzja operacyjna. |
| Brak resource limits/requests | WYSOKI | `kubectl describe deploy` → `resources: {}` | Brak limitów CPU/Memory na kontenerach. Ryzyko OOM kill i noisy-neighbour na node. |
| Brak liveness/readiness probes | WYSOKI | `kubectl describe deploy` → brak Liveness/Readiness | K8s nie ma mechanizmu usunięcia broken poda z rotacji. Traffic może trafiać na unhealthy pod. |
| Secret Manager API wyłączone | WYSOKI | `gcloud secrets list` → SERVICE_DISABLED | Sekrety aplikacyjne w K8s Secrets (base64, bez audytu dostępu, bez rotacji). Brak Secret Manager = brak centralnego miejsca zarządzania sekretami. |
| SSH otwarty na 0.0.0.0/0 (dwie reguły) | WYSOKI | Firewall: `default-allow-ssh`, `rci-orchestration-allow-ssh` | SSH dostępny z całego internetu na obu VPC. Wymaga ograniczenia do IP biurowych / Identity-Aware Proxy. |
| RDP otwarty na 0.0.0.0/0 | WYSOKI | Firewall: `default-allow-rdp` | Brak maszyn Windows w projekcie — reguła powinna być usunięta. |
| Fluent-bit DaemonSet disabled | ŚREDNI | `kubectl get ds -n logging` → desired=0, `soft-disabled=true` | Logi aplikacyjne trafiają do GCS przez Cloud Logging sink (nie przez Fluent-bit → OpenSearch). OpenSearch może nie otrzymywać świeżych logów aplikacyjnych. |
| Brak HPA | ŚREDNI | `kubectl get hpa -A` → No resources found | Brak autoskalowania. Przy wzroście ruchu — stałe 3 repliki. |
| Brak uptime checks | ŚREDNI | `gcloud monitoring uptime list-configs` → 0 | Brak monitoringu dostępności endpointu `onboarding.rciservices.eu`. |
| Repo IaC lokalnie nieznalezione | ŚREDNI | `find ~/projekty/mako/mfs-orchestration` → not found | Brak lokalnego checkout IaC uniemożliwia analizę kodu Terraform. |
| Grafana bez zewnętrznego ingress | NISKI | Service type: ClusterIP, brak ingress w `observability` ns | Grafana niedostępna zewnętrznie przez standardową ścieżkę; prawdopodobnie dostęp przez port-forward lub inny mechanizm — niezweryfikowane. |
| Image region mismatch | NISKI | Image: `europe-west1-docker.pkg.dev/...`, cluster: europe-west2 | Artifact Registry w europe-west1, GKE w europe-west2. Może powodować dodatkowe koszty transferu i minimalnie wolniejszy pull. |

---

## Różnice IaC vs Runtime

| Obszar | IaC | Runtime GCP | Ocena |
|--------|-----|-------------|-------|
| Terraform kod | niezweryfikowane (brak repo) | - | nieustalone |
| Terraform state | gs://rci-remote-terraform-state/prod/state/ | zgodne z label `goog-terraform-provisioned` na VM | wymaga potwierdzenia |
| Wszystkie pozostałe obszary | niezweryfikowane | live GCP | nieustalone — brak repo IaC |

---

## Drift / niespójności architektury

| Obszar | Typ driftu | Źródło | Opis |
|--------|-----------|--------|------|
| Namespace naming vs runtime config | manual change / design | live K8s | `rci-onboarding-dev` namespace + `SPRING_PROFILES_ACTIVE=prod` — prawdopodobna intencjonalna decyzja, ale powoduje konfuzję i ryzyko operacyjne |
| Fluent-bit → OpenSearch | design/disabled | live K8s | Architektura zakłada logi przez Fluent-bit, ale DaemonSet disabled. Rzeczywisty flow: Cloud Logging → GCS sink |
| rci-onboarding-prod namespace: pusty | nieustalone | live K8s | Namespace istnieje od 276 dni, ale 0 zasobów. Porzucony czy planowany? |

---

## Pewność ustaleń

| Obszar | Pewność | Evidence | Uwagi |
|--------|---------|----------|-------|
| GKE runtime health | wysoka | live kubectl | 3/3 pods running |
| Networking / IP | wysoka | live gcloud | firewall, forwarding rules, subnets |
| Observability | średnia | live kubectl + gcloud | Grafana bez ingress — dostęp niezweryfikowany |
| Terraform IaC | niska | brak repo | tylko state bucket potwierdzony |
| Spring app config | wysoka | live K8s env | SPRING_PROFILES_ACTIVE=prod w namespace dev |
| Secret management | wysoka | live gcloud | Secret Manager API disabled; K8s Secrets potwierdzone |

---

## Dostęp diagnostyczny

```bash
# Autentykacja GCP (przed pierwszym użyciem w sesji)
gcloud auth login
gcloud config set project rci-orchestration

# GKE credentials
gcloud container clusters get-credentials rci-cluster --region europe-west2 --project rci-orchestration

# Diagnoza: status podów
kubectl get pods -n rci-onboarding-dev

# Diagnoza: deployment details
kubectl describe deployment rci-onboarding-dev -n rci-onboarding-dev

# Diagnoza: logi aplikacji
kubectl logs -n rci-onboarding-dev -l app=rci-onboarding-dev --tail=100

# Diagnoza: zasoby klastra
kubectl top nodes
kubectl top pods -n rci-onboarding-dev

# Diagnoza: OpenSearch VM status
gcloud compute instances describe opensearch-instance --zone europe-west2-a --project rci-orchestration

# Diagnoza: Cloud Logging — ostatnie błędy aplikacji
gcloud logging read 'resource.type="k8s_container" resource.labels.namespace_name="rci-onboarding-dev" severity>=ERROR' \
  --project rci-orchestration --limit 50 --format "table(timestamp,textPayload)"
```

---

## Źródła użyte

| Źródło | Zakres | Status |
|--------|--------|--------|
| live GCP (gcloud) | GKE, Compute, GCS, Artifact Registry, Logging, IAM, Networking, Firewall | sprawdzone |
| live K8s (kubectl) | Deployments, Services, Ingress, Secrets, ConfigMaps, Namespaces, DaemonSets | sprawdzone |
| IaC (Terraform) | niezweryfikowane — repo lokalne nie znalezione | niesprawdzone |
| vault historyczny | nie użyto — nowy projekt | nieużyte |

## Fakty live vs historia vault

Nie użyto danych historycznych z vault. Wszystkie ustalenia pochodzą z live GCP (2026-05-17).

---

## Powiązane

- [[cloud-detective-mfs-onboarding]] — plik invocation
- `50-patterns/prompts/invocations/cloud-detective-mfs-onboarding.md`
