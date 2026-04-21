# planodkupow — Bezpieczne tagowanie pod FinOps i przyszłe SCP

#aws #cloudformation #tagging #finops #planodkupow #governance

**Data:** 2026-04-21
**Status:** Faza 1 DONE ✅ (audyt read-only 2026-04-21) | Faza 2 — decyzja projektowa

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

---

## WYNIKI AUDYTU (Faza 1 — 2026-04-21)

### 1. Istniejące tagi — klucze i wartości

#### QA (nowy stack, CREATE_COMPLETE od 2026-04-21)

Zasoby z nowego stosu CFN:

| Klucz | Wartość |
|-------|---------|
| `Project` | planodkupow |
| `Environment` | qa |
| `Owner` | DC-devops |
| `ManagedBy` | cloudformation |
| `CostCenter` | DC |

Zasoby z NOWYM schematem: RDS (planodkupowqadb), ALB, TG (x3), S3 (planodkupow-qa, planodkupow-qa-pliki), Redis, ECS cluster (planodkupow-qa-Klaster), VPC (vpc-007d115c41f079bf3 — nowy)

**Wyjątki w QA:**
- CloudFront EORCEYNXGKU9K (planodkupow-qa-ALB origin): **BRAK TAGÓW** — zero
- Root stack `planodkupow-qa`: brak tagów na poziomie stack resource
- Stary VPC vpc-02f804baee8a3f048 (resztka po starym QA): stary schemat

#### UAT (stary stack, UPDATE_ROLLBACK_COMPLETE)

Zasoby ze starym schematem:

| Klucz | Wartość |
|-------|---------|
| `Project` | planodkupow |
| `Environment` | uat |
| `Maintainer` | 3rd party - Tribecloud |
| `Provisioner` | cloudformation |
| `Team` | DataCenter |
| `Client` | Reno/Dacia |
| `typ` | uat |

Zasoby ze STARYM schematem: RDS (planodkupowuatdb), ALB (x2), TG (x2), S3 (planodkupow-uat, planodkupow-uat-pliki), Redis, ECS cluster, VPC, CloudFront (3 dystrybucje)

**Brakuje w UAT:** `Owner`, `ManagedBy`, `CostCenter`

#### Infrastruktura współdzielona

| Bucket | Schemat | Env |
|--------|---------|-----|
| planodkupow-cf | stary | dev |
| planodkupow-s3-logi | stary | dev |

---

### 2. Mapowanie obecne → docelowe

| Stary klucz | Stara wartość | → Nowy klucz | Nowa wartość | Uwagi |
|-------------|---------------|--------------|--------------|-------|
| `Maintainer` | `3rd party - Tribecloud` | `Owner` | `DC-devops` | wartość zmienia się — był vendor, teraz właściciel ops |
| `Provisioner` | `cloudformation` | `ManagedBy` | `cloudformation` | 1:1 wartość identyczna |
| `Team` | `DataCenter` | — | — | brak odpowiednika w nowym schemacie; może być `BusinessUnit` (opcjonalnie) |
| `Client` | `Reno/Dacia` | — | — | brak odpowiednika; wartość historyczna |
| `typ` | `uat` | — | redundant z `Environment` | usunąć w drugiej fali |
| — | — | `CostCenter` | `DC` | **nowy klucz bez poprzednika w UAT** — musi być dodany |

---

### 3. Brakujące tagi

#### UAT — wszystkie zasoby CFN (poza CF):

| Brakujący klucz | Wartość docelowa |
|-----------------|-----------------|
| `Owner` | `DC-devops` |
| `ManagedBy` | `cloudformation` |
| `CostCenter` | `DC` |

#### QA — CloudFront (EORCEYNXGKU9K):

| Brakujący klucz | Wartość |
|-----------------|---------|
| `Project` | planodkupow |
| `Environment` | qa |
| `Owner` | DC-devops |
| `ManagedBy` | cloudformation |
| `CostCenter` | DC |

→ Wykluczyć z fali 1 (DO NOT TOUCH).

#### Infrastruktura (planodkupow-cf, planodkupow-s3-logi):

Stary schemat z `env=dev` — uzupełnić `Owner`, `ManagedBy`, `CostCenter` ręcznie przez S3 API.

---

### 4. Lista zasobów SAFE do tagowania (pierwsza fala)

Bezpośrednia zmiana tagów przez API (nie przez CFN) — zero blast radius na zasoby:

| Zasób | Typ | Środowisko | Metoda tagowania |
|-------|-----|------------|-----------------|
| planodkupow-uat | S3 | UAT | `s3api put-bucket-tagging` |
| planodkupow-uat-pliki | S3 | UAT | `s3api put-bucket-tagging` |
| planodkupow-cf | S3 | dev/shared | `s3api put-bucket-tagging` |
| planodkupow-s3-logi | S3 | dev/shared | `s3api put-bucket-tagging` |
| VPC vpc-0b91c465aa64ba545 | EC2/VPC | UAT | `ec2 create-tags` |
| Subnety UAT | EC2/subnet | UAT | `ec2 create-tags` |
| Route tables UAT | EC2 | UAT | `ec2 create-tags` |
| Security groups UAT | EC2 | UAT | `ec2 create-tags` |
| IAM roles UAT | IAM | UAT | `iam tag-role` |
| ECR repositories UAT | ECR | UAT | `ecr tag-resource` |
| Log groups UAT | CloudWatch | UAT | `logs tag-log-group` |

Uwaga: zasoby EC2/VPC/SG są zarządzane przez CFN ale tagowanie ich bezpośrednio nie triggeruje CFN update. Drift będzie widoczny dopiero przy następnym change set — akceptowalny risk w pierwszej fali.

---

### 5. Lista zasobów CAUTION (tylko po analizie change seta)

Tagowanie przez CFN może wywołać realne zmiany resource-level:

| Zasób | Dlaczego CAUTION |
|-------|-----------------|
| ALB / TG UAT | CFN-managed; change set może wywołać routing update |
| Redis UAT (planodkupow-uat-redisinst) | CFN-managed; ElastiCache tag update = cluster modify (reboot?) |
| ECS cluster UAT (KlasterStack) | CFN tag update = ECS rolling deploy wszystkich serwisów |
| ECS serwisy UAT (14 serwisów) | rolling update akceptowalny ale musi być w oknie operacyjnym |
| Stary VPC vpc-02f804baee8a3f048 | resztka po starym QA, wyjaśnić status przed tagowaniem |

**Dla Redis i ALB:** rekomendacja = taguj bezpośrednio przez API, nie przez CFN change set. Drift i tak jest już obecny na tych zasobach.

---

### 6. Lista zasobów DO NOT TOUCH (pierwsza fala)

| Zasób | ID | Dlaczego |
|-------|----|----------|
| CloudFront UAT | E2KYCZWO6DNDQQ | global propagation, domeny poza naszą kontrolą |
| CloudFront UAT | E1GPI75PXVTZP5 | j.w. |
| CloudFront UAT | EF983GSFSLS4A | j.w. |
| CloudFront QA | EORCEYNXGKU9K | j.w. + brak tagów = duża zmiana |
| RDS UAT (planodkupowuatdb) | — | custom-named resource, każda zmiana CFN = ryzyko replacement |

RDS — jeśli potrzeba tagów na UAT RDS, użyć bezpośrednio:
```bash
aws rds add-tags-to-resource \
  --resource-name "arn:aws:rds:eu-central-1:333320664022:db:planodkupowuatdb" \
  --tags Key=Owner,Value=DC-devops Key=ManagedBy,Value=cloudformation Key=CostCenter,Value=DC \
  --region eu-central-1 --profile plan
```
Nie przez CFN.

---

### 7. Rekomendacja: mapowanie czy zmiana realnych tagów

**Scenariusz A (mapowanie) NIE WYSTARCZA.** Powody:

1. **`CostCenter`** nie ma odpowiednika w starym schemacie — musi być dodany jako nowy klucz w AWS
2. **`Owner` vs `Maintainer`** — wartości są różne: stary = `3rd party - Tribecloud`, nowy = `DC-devops`. AWS SCP/FinOps operuje na realnych wartościach, nie na mapowaniu
3. **Narzędzia AWS** (Cost Explorer, SCP condition keys, Resource Groups) działają na realnych kluczach/wartościach tag w AWS — mapowanie logiczne nie istnieje na poziomie platformy

**Rekomendacja: Strategia addytywna (Scenariusz B lite)**

1. **Faza 1:** Dodaj `Owner`, `ManagedBy`, `CostCenter` do zasobów UAT (bez usuwania starych)
   - S3, VPC, SG, IAM, ECR, Logs → bezpośrednio przez API
   - RDS → bezpośrednio przez API (nie CFN)
   - Redis, ALB → bezpośrednio przez API lub change set z walidacją
2. **Faza 2:** Walidacja FinOps — czy nowe tagi są widoczne i wystarczające
3. **Faza 3:** Usunięcie starych kluczy (`Maintainer`, `Provisioner`, `Team`, `Client`, `typ`) — oddzielna operacja
4. **CloudFront** — osobna decyzja i osobne okno operacyjne, NIGDY razem z innymi zmianami

---

### 8. CONFIDENCE

| Obszar | Confidence | Podstawa |
|--------|-----------|---------|
| QA tag schema | HIGH | Nowy stack, pełna inwentaryzacja, zasoby z nowego CFN |
| UAT tag schema | HIGH | Pełna inwentaryzacja przez resourcegroupstaggingapi (9266 zasobów) |
| Mapowanie Maintainer→Owner | MEDIUM | Wartości się różnią — decyzja biznesowa potrzebna |
| Bezpieczeństwo tagowania S3/VPC/SG | HIGH | Bezpośrednie API, zero CFN trigger |
| Bezpieczeństwo tagowania ALB/Redis przez CFN | MEDIUM | Historycznie te staki były stabilne ale nie testowane w tym kontekście |
| CloudFront | HIGH | DO NOT TOUCH — bez wątpliwości |
| RDS przez API (nie CFN) | HIGH | Bezpieczne — rds add-tags nie triggeruje modify |

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

**Wniosek z audytu:** `Project` i `Environment` są już po angielsku i konsekwentne — Scenariusz A jest możliwy dla tych dwóch kluczy. Problem dotyczy pozostałych kluczy (`Owner`/`Maintainer`, `ManagedBy`/`Provisioner`, `CostCenter` — brak odpowiednika).

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

### Faza 1 — Inwentaryzacja (read-only) ✅ DONE 2026-04-21

Wyniki w sekcji "WYNIKI AUDYTU" powyżej.

### Faza 2 — Decyzja projektowa

1. Ustal docelowy słownik — czy `Owner=DC-devops` jest właściwy dla UAT (wcześniej `3rd party - Tribecloud`)?
2. Potwierdź wartość `CostCenter` dla UAT
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

## Komendy operacyjne (pierwsza fala — bezpośrednie tagowanie UAT)

```bash
# S3 — UAT buckety (addytywnie — dołącz do istniejących)
aws s3api put-bucket-tagging \
  --bucket planodkupow-uat \
  --tagging 'TagSet=[
    {Key=Project,Value=planodkupow},
    {Key=Environment,Value=uat},
    {Key=Maintainer,Value="3rd party - Tribecloud"},
    {Key=Provisioner,Value=cloudformation},
    {Key=Team,Value=DataCenter},
    {Key=Client,Value="Reno/Dacia"},
    {Key=typ,Value=uat},
    {Key=Owner,Value=DC-devops},
    {Key=ManagedBy,Value=cloudformation},
    {Key=CostCenter,Value=DC}
  ]' \
  --region eu-central-1 --profile plan

# RDS UAT — bezpośrednio przez API (NIE przez CFN)
aws rds add-tags-to-resource \
  --resource-name "arn:aws:rds:eu-central-1:333320664022:db:planodkupowuatdb" \
  --tags Key=Owner,Value=DC-devops Key=ManagedBy,Value=cloudformation Key=CostCenter,Value=DC \
  --region eu-central-1 --profile plan

# Redis UAT — bezpośrednio przez API
aws elasticache add-tags-to-resource \
  --resource-name "arn:aws:elasticache:eu-central-1:333320664022:cluster:planodkupow-uat-redisinst" \
  --tags Key=Owner,Value=DC-devops Key=ManagedBy,Value=cloudformation Key=CostCenter,Value=DC \
  --region eu-central-1 --profile plan

# VPC UAT
aws ec2 create-tags \
  --resources vpc-0b91c465aa64ba545 \
  --tags Key=Owner,Value=DC-devops Key=ManagedBy,Value=cloudformation Key=CostCenter,Value=DC \
  --region eu-central-1 --profile plan
```

Inwentaryzacja tagi QA/UAT:
```bash
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Srodowisko,Values=qa \
  --region eu-central-1 --profile plan \
  --query 'ResourceTagMappingList[*].{ARN:ResourceARN,Tags:Tags}' \
  --output json

aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Environment,Values=uat \
  --region eu-central-1 --profile plan \
  --query 'ResourceTagMappingList[*].{ARN:ResourceARN,Tags:Tags}' \
  --output json
```

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

*Utworzono: 2026-04-21 | Faza 1 zakończona: 2026-04-21 | Status: Faza 2 — decyzja projektowa*
