# Minikurs operatora — devops-toolkit

#toolkit #operator #minikurs

Mirror: `~/projekty/devops/devops-toolkit/docs/operator/minikurs-pl.md`

---

## Szybki flow E2E

```bash
cd ~/projekty/mako/aws-projects/infra-rshop
toolkit onboard              # jednorazowo — tworzy .devops-toolkit/project.yaml
toolkit here                 # weryfikacja kontekstu projektu
awsume rshop-prod            # aktywacja AWS
toolkit work                 # pełny kontekst: profil, konto, region
toolkit audit                # pełny audit infrastruktury
toolkit audit-pack finops-basic
toolkit finops-report . --period last-full-month
cat .devops-toolkit/reports/finops-summary.md
```

---

## 1. Onboarding projektu

```bash
cd ~/projekty/mako/aws-projects/infra-rshop
toolkit onboard
# → tworzy .devops-toolkit/project.yaml
# → wykrywa: klienta, projekt, IaC type (CFN/TF/CDK)
toolkit here            # weryfikacja
toolkit contract init   # opcjonalnie: tworzy contracts.yaml
```

---

## 2. Kontekst AWS przed pracą

```bash
toolkit work            # sprawdź profil, konto, region
awsume mako-prod        # lub:
eval $(toolkit aws-login)
toolkit work            # ponowna weryfikacja
```

---

## 3. Audit infrastruktury

```bash
toolkit audit                                          # auto-detekcja projektu z CWD
toolkit audit mako/infra-rshop                        # explicit
toolkit audit --project-root ~/projekty/.../infra-rshop

# Artefakty trafiają wyłącznie do repo klienta:
.devops-toolkit/runs/<YYYYMMDD-HHMMSS-audit>/
  raw/        ← surowe dane AWS (nigdy do AI)
  normalized/ ← zagregowane
  sanitized/  ← bez identyfikatorów (wejście dla AI)
  findings/   ← ustrukturyzowane znaleziska
  results/    ← wyniki reguł
  manifest.yaml
```

---

## 4. Audit-pack

```bash
toolkit audit-pack finops-basic      # idle storage, cost hotspots, tagging
toolkit audit-pack tagging           # pełny audyt tagowania
toolkit audit-pack aws-logging       # logowanie i observability
toolkit audit-pack observability-ready
toolkit audit-pack terraform-standard
toolkit audit-pack llz-basic
```

### aws-logging — statusy

| Status | Znaczenie |
|--------|-----------|
| `NOT_ENABLED` | Logging możliwy, ale brak ścieżki source→destination |
| `ENABLED_BUT_EMPTY` | Destination istnieje, ale brak danych historycznych |
| `ENABLED_AND_HAS_DATA` | Destination ma dane — OK |
| `ORPHANED_DESTINATION` | Destination bez aktywnego source |
| `UNKNOWN` | Za mało dowodów — nie zgaduje |

Patch plan: `toolkit audit-pack aws-logging --patch-plan`

---

## 5. FinOps workflow

```bash
awsume rshop-prod
cd ~/projekty/rshop/infra

toolkit finops-report . --period last-full-month         # executive (domyślny)
toolkit finops-report . --period mtd --audience technical
toolkit finops-report . --period last-full-month --env prod

cat .devops-toolkit/reports/finops-summary.md
```

Szczegóły: [[finops-reporting]]

---

## 6. Nowy projekt Terraform

```bash
cd ~/projekty/acme
toolkit terraform init-project \
  --project-name acme-web \
  --envs dev,prod \
  --region eu-central-1

cd acme-web
toolkit terraform bootstrap-backend   # tworzy S3 bucket + DynamoDB

# Uzupełnij backend.tf w każdym envs/<env>/
grep -r "FILL_IN" .devops-toolkit/
grep -r "CHANGE_ME" envs/

cd envs/dev && terraform init && terraform plan
cd ../.. && toolkit check
```

---

## 7. Self-test i contract

```bash
toolkit self-test --scope quick          # po merge/refaktorze
toolkit self-test --scope release --project-root /path/to/project
toolkit contract show                    # kontrakt projektu
toolkit contract check                   # walidacja IaC
make contract-check                      # walidacja toolkit repo
```

---

## Zasady operacyjne

| Zasada | Dlaczego |
|--------|----------|
| `toolkit work` przed auditem | Sprawdza account/region |
| Nie commituj `.devops-toolkit/` | Wrażliwe dane — jest w .gitignore |
| Onboarduj przez `toolkit onboard` | Poprawna struktura bez błędów |
| Artefakty tylko w `.devops-toolkit/runs/` | Toolkit jest stateless |

---

## Typowe błędy

| Błąd | Rozwiązanie |
|------|-------------|
| `toolkit: command not found` | `cd devops-toolkit && make install` |
| `not inside a DevOps Toolkit project` | `toolkit onboard` |
| `account: unavailable` | `awsume <profil>` |
| `bucket = FILL_IN` po scaffold | `toolkit terraform bootstrap-backend` |
| LLZ-B-010/011/012 po scaffold | Uzupełnij `project.yaml` |
| `terraform init` — FILL_IN w backend | Uzupełnij `backend.tf` po bootstrap |

---

## Powiązane

- [[command-catalog]]
- [[finops-reporting]]
- [[minikurs-finops]]
- [[minikurs-self-test]]
