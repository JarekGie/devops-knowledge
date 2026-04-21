# planodkupow — Bezpieczne tagowanie pod FinOps i przyszłe SCP

#aws #cloudformation #tagging #finops #planodkupow #governance

**Data:** 2026-04-21
**Status:** PLAN — Faza 1 (inwentaryzacja) nie rozpoczęta

---

## Założenia operacyjne

- **UAT traktujemy jak PROD** — żadnych eksperymentów, tylko sprawdzone na QA zmiany
- Domeny nie są zarządzane przez nas → CloudFront **wyłączony z pierwszej fali**
- Tagowanie jako osobna operacja — nie łączyć z deployami ani innymi refaktorami
- RabbitMQ już wyciągnięty z root lifecycle (QA done) — nie mieszać

---

## Cel

Przygotować planodkupow do FinOps / SCP governance w sposób:
- etapowy i odwracalny
- z minimalnym blast radius
- bez ryzyka dla CloudFront i ścieżki ruchu publicznego

---

## Model docelowy tagów

### Minimalny zestaw

| Klucz | Opis |
|-------|------|
| `Project` | nazwa projektu |
| `Environment` | qa / uat / prod |
| `Owner` | właściciel operacyjny |
| `ManagedBy` | cloudformation / terraform / manual |
| `CostCenter` | centrum kosztów |

Opcjonalnie później: `System`, `DataClassification`, `BusinessUnit`

### Istniejące tagi planodkupow (potencjalne mapowanie)

- `Projekt` → semantycznie = `Project`
- `Srodowisko` → semantycznie = `Environment`

Jeśli FinOps może opierać się na mapowaniu nazw na wejściu → realna zmiana w AWS może być mała (tylko uzupełnienie braków: `Owner`, `ManagedBy`, `CostCenter`).

---

## Strategia: mapowanie vs zmiana realnych tagów

### Scenariusz A — mapowanie wystarcza (preferowany)

Jeśli `Projekt` i `Srodowisko` istnieją konsekwentnie:
- traktujemy je logicznie jako `Project` i `Environment`
- zmieniamy tylko brakujące: `Owner`, `ManagedBy`, `CostCenter`
- minimalna zmiana w AWS

### Scenariusz B — konieczna zmiana nazw tagów

Jeśli narzędzia / zasady wymagają dokładnie `Project` i `Environment`:
1. QA → analiza change seta → decyzja
2. UAT dopiero po walidacji

---

## Klasyfikacja zasobów

### SAFE — można tagować w pierwszej fali

- VPC / subnety / route tables
- Security groups
- S3 buckety
- Log groups
- ECS cluster
- IAM roles
- ECR repositories
- Stack-level tags na bezpiecznych nested stackach (jeśli nie wywołują side effects)

### CAUTION — tylko po analizie change seta

- DBStack / RDS (historycznie: rollback przez SQLDatabase replacement)
- Redis
- ALB / listener / routing (jeśli tag wywołuje update path)
- Nested stacks z parametrami dynamicznymi

### DO NOT TOUCH — pierwsza fala

- **CloudFront** — global propagation, domeny poza naszą kontrolą, ryzyko ruchowe
- Wszystko związane z publiczną ścieżką domenową

---

## Fazy wdrożenia

### Faza 1 — Inwentaryzacja (read-only)

```bash
# Tagi na zasobach QA
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Srodowisko,Values=qa \
  --region eu-central-1 --profile plan \
  --query 'ResourceTagMappingList[*].{ARN:ResourceARN,Tags:Tags}' \
  --output json

# Tagi na zasobach UAT
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Srodowisko,Values=uat \
  --region eu-central-1 --profile plan \
  --query 'ResourceTagMappingList[*].{ARN:ResourceARN,Tags:Tags}' \
  --output json
```

Wynik: tabela zasobów z obecnymi tagami, klasyfikacja A/B/C/D:

| Klasa | Opis |
|-------|------|
| A | Już zgodne semantycznie |
| B | Zgodne po mapowaniu |
| C | Brakujące |
| D | Chaotyczne / niejednoznaczne |

### Faza 2 — Decyzja projektowa

1. Ustal docelowy słownik
2. Zdecyduj: mapowanie czy zmiana realnych nazw
3. Zatwierdź wykluczenie CloudFront z pierwszej fali

### Faza 3 — QA (walidacja)

1. Osobny change set — bez żadnych innych zmian
2. Tylko bezpieczne zasoby (klasa SAFE)
3. Główne watchpointy: DBStack, CFStack

**Hard stop jeśli change set pokaże:**
- `Replacement: true` gdziekolwiek
- `DELETE` na jakimkolwiek zasobie
- Static/DirectModification na DBStack lub CFStack
- Realny resource change na RDS / CloudFront / ALB / Redis

### Faza 4 — UAT (po pozytywnej walidacji QA)

- Tylko to, co QA pokazało jako bezpieczne
- Bez CloudFront w pierwszej fali
- Osobne okno operacyjne, aktywny monitoring

---

## Kryteria powodzenia

### Sukces

- Change set bez replacementów
- Brak realnych zmian na zasobach krytycznych
- Brak rollbacku
- Tagi lub mapowanie gotowe do użycia przez FinOps

### Porażka

- Root update dotyka DB / CloudFront w sposób nieakceptowalny
- Tagowanie uruchamia realne update'y resource-level
- Brak możliwości rozdzielenia bezpiecznych i niebezpiecznych zasobów

---

## Powiązane

- [[planodkupow-rabbitmq-cfn-refactor]] — historia blast radius i lekcje z DBStack
- Incydent SQLDatabase: `CloudFormation cannot update a stack when a custom-named resource requires replacing` — trigger: tag DirectModification na DBStack

---

*Utworzono: 2026-04-21 | Status: PLAN — do rozpoczęcia od Fazy 1*
