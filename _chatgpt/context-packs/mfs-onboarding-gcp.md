# Paczka kontekstu — mfs-onboarding (GCP / rci-orchestration)

> Wklej całość na początku rozmowy z ChatGPT. Cel: <1500 tokenów.

**Zakres:** GKE, Spring Boot, OpenSearch, Terraform, Kubernetes, GCP project rci-orchestration
**Data przygotowania:** 2026-05-17

---

## Kim jestem / kontekst roli

Senior DevOps/SRE, AWS primary ale też GCP. Zarządzam infrastrukturą klienta MakoLab (projekt RCI). Stack: GKE, Terraform, Kubernetes, Spring Boot. Vault wiedzy operacyjnej w Obsidian.

## Stan obecny

Projekt `mfs-onboarding` to serwis onboardingowy RCI deployowany na GKE w GCP project `rci-orchestration` (europe-west2). Właśnie wykonałem pierwszy pełny cloud-detective snapshot. Runtime działa (3/3 pods healthy), ale wykryłem kilka istotnych problemów wymagających decyzji / działania.

Kluczowy dylemat: **prod workload działa w namespace `rci-onboarding-dev`** z `SPRING_PROFILES_ACTIVE=prod`, podczas gdy namespace `rci-onboarding-prod` jest pusty od 276 dni. Nie wiem czy to celowa decyzja czy zaniedbanie.

Repo IaC (`~/projekty/mako/mfs-orchestration`) nie jest sklonowane lokalnie — analiza Terraform niemożliwa bez niego.

## Kluczowe fakty

- GKE cluster `rci-cluster`: europe-west2, 5x e2-medium, K8s 1.33.10
- App: Spring Boot, image `onboarding-master:ver-64`, 3 repliki, NodePort 8080
- Ingress: HAProxy → `onboarding.rciservices.eu`, external IP `35.189.115.120`
- OpenSearch: VM n2-standard-2 (CentOS Stream 9), public IP `35.189.90.45`
- Fluent-bit DaemonSet: **wyłączony** (`soft-disabled=true`) — logi przez Cloud Logging sink → GCS, nie przez Fluent-bit → OpenSearch
- Secret Manager API: **wyłączone** — sekrety jako K8s Secrets
- Brak resource limits, liveness/readiness probes, HPA na deploymencie
- SSH firewall otwarte na `0.0.0.0/0` (dwie reguły: default i rci VPC)
- Terraform state: `gs://rci-remote-terraform-state/prod/state/`
- Artifact Registry: `europe-west1-docker.pkg.dev/rci-orchestration/mfs-onboarding/`
- Monitoring dashboards: "OpenSearch instance monitoring", "GCE & Network Monitoring"; 0 uptime checks; alert policies niezweryfikowane
- Grafana: running (ClusterIP), brak zewnętrznego ingress — dostęp niezweryfikowany

## Zasoby

```
GCP Project:     rci-orchestration (number: 38390674701)
Region:          europe-west2
GKE cluster:     rci-cluster
Namespace prod:  rci-onboarding-dev  (! prod workload, dev name)
Namespace empty: rci-onboarding-prod (puste od 276 dni)
External IP:     35.189.115.120 (HAProxy LB)
OpenSearch IP:   35.189.90.45 (VM publiczne)
TF state:        gs://rci-remote-terraform-state/prod/state/
Logs bucket:     gs://rci-logs-prod-europe-west2
Artifact Reg:    europe-west1-docker.pkg.dev/rci-orchestration/mfs-onboarding/
Context vault:   20-projects/clients/mako/mfs-onboarding/mfs-onboarding-context.md
```

## Pytanie

{{CZEGO POTRZEBUJESZ — uzupełnij przed wklejeniem do ChatGPT}}

Przykłady:
- "Jak bezpiecznie wyjaśnić/naprawić naming dev/prod namespace bez downtime?"
- "Jak skonfigurować resource limits i probes dla Spring Boot na GKE?"
- "Jak włączyć Secret Manager i zmigrować K8s Secrets?"
- "Jak przywrócić Fluent-bit → OpenSearch pipeline?"
