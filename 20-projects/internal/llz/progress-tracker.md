---
updated: 2026-04-18
---

# LLZ — Progress Tracker

Stan onboardingu projektów Terraform do standardu LLZ v1.

## Legenda

| Status | Znaczenie |
|--------|-----------|
| ✅ LLZ-ready | Wszystkie reguły A+B+C przechodzą |
| ⚠️ Partial | Część reguł przechodzi, znane luki |
| ❌ Not audited | Audit nie był uruchamiany |
| 🔧 In progress | Onboarding w toku |
| ➖ N/A | Projekt CloudFormation — inny kontrakt |

## Projekty

| Projekt | Typ IaC | Status | Ostatni audit | Uwagi |
|---------|---------|--------|---------------|-------|
| mako/rshop | CloudFormation | ➖ N/A | — | CFN tagging contract, nie LLZ |
| | | | | |

> Wypełnij po uruchomieniu `toolkit audit-pack llz-basic` na każdym projekcie.

## Jak przeprowadzić audit

```bash
cd ~/projekty/mako/<infra-projekt>
toolkit audit-pack llz-basic

# Lub z podaniem ścieżki:
toolkit audit-pack llz-basic --project-root ~/projekty/mako/<infra-projekt>
```

Wyniki zapisują się do `.devops-toolkit/runs/<run-id>/`. Wypełnij tabelę powyżej po każdym audycie.

## Typowe luki (z kontraktu LLZ v1)

**Obszar A — Struktura:**
- Brak `.devops-toolkit/project.yaml`
- Brak `envs/` — projekt nie ma środowiskowej struktury katalogów

**Obszar B — Scaffold:**
- `backend.tf` z lokalnym backendem zamiast S3
- Nieuzupełnione placeholdery `<TO_FILL>` w `backend.tf`
- Brak `versions.tf`

**Obszar C — Polityki:**
- Brak `finops.billing_profile` w `project.yaml`
- Brak `cloud.profile` w `project.yaml`
- Brak deklaracji schedulera (jeśli wymagany)
