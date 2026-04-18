---
project: llz
type: internal
tags: [llz, terraform, governance, platform, mako]
created: 2026-04-18
---

# LLZ — Light Landing Zone

> Kontekst ładowany na początku każdej sesji LLZ. Standalone — bez zależności od innych notatek.

## Co to jest LLZ

**Light Landing Zone (LLZ)** to standard platformowy MakoLab dla projektów Terraform. Definiuje minimalne wymagania strukturalne, scaffoldowe i politykowe które projekt musi spełniać żeby działać na platformie MakoLab.

LLZ NIE jest:
- pełnym AWS Landing Zone (multi-account, Control Tower)
- narzędziem do provisjonowania infrastruktury
- frameworkiem Terraform (nie narzuca modułów)

LLZ JEST:
- kontraktem "LLZ-ready" — zestawem reguł statycznych które projekt Terraform musi spełniać
- podstawą do onboardingu projektów na platformę
- narzędziem audytu zgodności przed deploymentem

## Zakresy LLZ v1

| Obszar | ID | Plugin | Opis |
|--------|----|--------|------|
| Struktura projektu | A | `llz-project-structure` | `envs/`, `project.yaml`, `README.md`, `.gitignore` |
| Scaffold każdego env | B | `llz-scaffold-conformance` | `backend.tf`, `versions.tf`, `terraform.tfvars`, brak placeholderów |
| Polityki workloadowe | C | `llz-policy-conformance` | scheduler, tagging, FinOps billing_profile |

LLZ v1 dotyczy wyłącznie **projektów Terraform**. CloudFormation (np. rshop) ma osobny kontrakt CFN tagging.

## Toolkit — jak uruchamiać

```bash
# Audit LLZ-readiness projektu
toolkit audit-pack llz-basic --project-root ~/projekty/mako/infra-myapp

# Wyniki w:
.devops-toolkit/runs/<run-id>/findings/
```

Lokalna ścieżka toolkit: `~/projekty/devops/devops-toolkit`

## Stan obecny (2026-04-18)

```
Toolkit LLZ:       zaimplementowany (plugins + pack + kontrakt)
Onboarding org:    nie rozpoczęty
Projekty LLZ-ready: nieznany — wymaga audytu
```

## Cel

Przygotować organizację (MakoLab / projekty klientów) do LLZ:
1. Audyt istniejących projektów Terraform — które są LLZ-ready, które nie
2. Onboarding projektów nie-zgodnych — uzupełnienie scaffoldu
3. Integracja LLZ check w CI/CD (Jenkins/Atlantis)
4. Dokumentacja procesu dla devopsów

## Powiązane

- [[session-log]] — historia sesji LLZ
- [[progress-tracker]] — stan onboardingu projektów
- [[../devops-toolkit/context]] — toolkit
- `60-toolkit/llz-audit.md` — dokumentacja operatorska
- Kontrakt: `devops-toolkit/docs/kontrakty/39-kontrakt-llz.md`
