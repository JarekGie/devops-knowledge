# ChatGPT Context Pack — planodkupow operations / FinOps / incidents

Data aktualizacji: 2026-05-20 (pełna rewizja — dodano audit FinOps kwiecień 2026)

Ten plik jest syntetyczną paczką kontekstu do rozmów z ChatGPT o `planodkupow`.
Zakres: historia incydentów CFN/RabbitMQ + pełny audit FinOps/governance z kwietnia 2026.

---

## 1. Executive Summary — projekt

`planodkupow` w koncie AWS `333320664022` (`eu-central-1`, profil CLI `plan`).

**Historia incydentów (do kwietnia 2026):**
- QA `UPDATE_ROLLBACK_FAILED` po deployu LLZ/tagging → pełny rebuild środowiska
- Oddzielny incydent RabbitMQ na QA (brak uprawnień IAM → pętla rollback)
- Oddzielny incydent RabbitMQ na UAT (EOL broker → auto-upgrade AWS → rollback chaos)
- Refaktor architektoniczny: RabbitMQ wychodiz z lifecycle root stacka (docelowo SSM parameter `MQCS`)

**Audyt FinOps/governance (kwiecień 2026):**
- Total spend: ~$905/miesiąc (baseline po rebuild z 19 kwietnia)
- Zidentyfikowany waste: **$432+/miesiąc**
- Największe pojedyncze problemy: CloudWatch log retention (164 GB, NEVER_EXPIRES), ECS PropagateTags=NONE ($267 untagged), orphan QA broker bez tagów ($21/mo)
- Status SCP tag enforcement: **NO-GO** — 7 z 8 checków nie przechodzi

---

## 2. Fakty operacyjne — środowiska i konto

```text
AWS account: 333320664022
Region:      eu-central-1
CLI profile: plan

Środowiska:
  QA:
    root stack:  planodkupow-qa (CREATE_COMPLETE)
    cluster:     planodkupow-qa-Klaster
    VPC (active): vpc-007d115c41f079bf3 (nowa, po rebuild)
    VPC (orphan): vpc-02f804baee8a3f048 (stara, stack DELETE_COMPLETE)
    Architektura: public subnet + IGW (brak NAT w nowej VPC)

  UAT:
    root stack:  planodkupow-uat (UPDATE_ROLLBACK_COMPLETE — stack w stanie failed!)
    cluster:     planodkupow-uat-Klaster
    VPC:         vpc-0b91c465aa64ba545
    Tag schema:  POLSKA (Srodowisko=uat, Projekt=planodkupow) — nieaktywna w Cost Explorer

  PROD:
    Niepotwierdzony zakres w tym audycie — brak danych z vaultu
```

**KRYTYCZNE:** UAT stack jest w stanie `UPDATE_ROLLBACK_COMPLETE`. CloudFormation NIE może bezpiecznie zarządzać UAT bez resolucji tego stanu.

---

## 3. Historia incydentów CFN / RabbitMQ

### 3.1 QA — główny incydent CFN rebuild

- **Trigger:** deploy LLZ/tagów
- **Pierwotna przyczyna:** Redis `5.0.0` EOL → AWS uruchomił Replace → zablokował rollback
- **Efekty uboczne odkryte podczas recovery:**
  - RabbitMQ `3.8.6` EOL
  - `mq.t3.micro` nienspierane dla nowych brokerów RabbitMQ (wymagało `mq.m5.large`/`mq.m7g.medium`)
  - zewnętrzny rekord DNS blokujący CloudFront
  - brak `DeletionPolicy: Retain` na RDS / DB SG
  - zły `HealthCheckPath` (`/signin`) dla Ocelot gateway
- **Recovery:** delete + redeploy, manual backup, kilka iteracji cleanup

**Skutek finansowy:** rebuild z 19 kwietnia permanentnie podniósł koszt konta o ~$262/miesiąc:

| Serwis | Przed rebuild/dzień | Po rebuild/dzień | Delta/miesiąc |
|--------|--------------------|--------------------|--------------|
| Amazon MQ | $1.72 | $5.58 | **+$115.80** |
| CloudWatch | $0.94 | $4.19 | **+$97.50** |
| Amazon ECS | $12.86 | $14.48 | **+$48.60** |

### 3.2 QA — incydent RabbitMQ (oddzielny)

- **Root cause:** brak uprawnień IAM dla deployment identity: `mq:UpdateBroker`, `mq:RebootBroker`
- `continue-update-rollback --resources-to-skip` odblokował stack ale zostawił semantycznie niebezpieczny stan i utrwalił drift
- **Strategia recovery:** recreate nowego brokera → cutover ECS przez parametr `MQCS` → usuń stary broker

### 3.3 UAT — incydent RabbitMQ

- Broker auto-upgrade'owany przez AWS do `3.13.7`, ale template nadal `3.8.6`
- Deploy wszedł w rollback próbujący przywrócić EOL `3.8.6` → pętla
- **Recovery:** `continue-update-rollback` + skip child stacków + dopięcie uprawnień IAM

### 3.4 Kierunek architektoniczny — RabbitMQ

- **Decyzja:** RabbitMQ ma wyjść z lifecycle root stacka
- `KlasterStack` pobiera `MQCS` z SSM: `/planodkupow/<env>/rabbitmq/mqcs`
- **Cel:** zmniejszenie blast radius root deployów, osobny lifecycle messagingu

---

## 4. Billing — Current State (kwiecień 2026)

### 4.1 Total spend

| Metric | Wartość |
|--------|---------|
| Total spend (incl. Tax, 25 dni) | **$1,127.11** |
| Monthly run-rate (ex-Tax) | **~$905/miesiąc** |
| Environment=qa attributed | $159.27 (14.1%) |
| Environment=uat attributed | $148.80 (13.2%) |
| **No Environment tag** | **$819.03 (72.7%)** |

### 4.2 Największe koszty wg serwisu

| Serwis | Miesięczny run-rate |
|--------|---------------------|
| Amazon ECS | ~$402/mo |
| Amazon VPC | ~$201/mo |
| AWS CloudTrail | ~$98/mo |
| Amazon MQ | **~$167/mo** (post-chaos) |
| Amazon RDS | ~$80/mo |
| AmazonCloudWatch | **~$126/mo** (post-chaos) |
| Amazon ElastiCache | ~$49/mo |
| Amazon ELB | ~$39/mo |
| Global Accelerator | $14.98/mo |
| AWS Transfer Family | ~$9/mo (UAT-only) |

### 4.3 Untagged bucket — co tak naprawdę siedzi w $819

| Składnik | Kwota | Usuwalny? |
|----------|-------|-----------|
| Tax (strukturalny) | $210.76 | NIE |
| ECS task compute (brak PropagateTags) | $267.23 | TAK — fix PropagateTags |
| VPC networking (NAT, endpoints, transfer) | $161.60 | CZĘŚCIOWO — stara VPC do usunięcia |
| CloudTrail trail | $81.36 | TAK — otagować |
| EC2-Other (EIPs, ENIs, transfer) | $31.15 | CZĘŚCIOWO |
| CloudWatch (untagged log groups) | $16.43 | TAK — otagować |
| MQ orphan broker | $21.20 | TAK — otagować lub usunąć |
| Global Accelerator | $14.98 | TAK — otagować lub wycofać |
| ECR repos | $7.60 | TAK — otagować |
| WAF | $4.99 | TAK — otagować |

**Kluczowy wniosek:** Untagged $819 to NIE jest UAT ukryty pod polskimi tagami.
UAT jest widoczny jako `Environment=uat` ($148.80). Polskie klucze `Srodowisko` i `Projekt`
są **nieaktywne** w Cost Explorer — zwracają $0 niezależnie od wartości.

---

## 5. Identified Waste — $432+/miesiąc

### 5.1 Priorytet H1 — zero-risk (bezpieczne natychmiast)

| Priorytet | Akcja | Oszczędności |
|-----------|-------|-------------|
| 1 | Set retention=30d na UAT MQ log groups (164 GB, NEVER_EXPIRES) | **~$350+/mo** po expiry |
| 2 | Tag QA MQ broker `planodkupow-qa-rabbitmq-cheap` (0 tagów) | Poprawa CE attribution |
| 3 | Usuń orphan chaos-day MQ log groups (3 brokerów) | Zatrzymanie narastania |
| 4 | Release unassociated EIP 3.77.136.162 | $3.60/mo |
| 5 | Tag 6 EIPs, 3 ECR repos, WAF WebACL | Poprawa CE attribution |

### 5.2 Priorytet H2 — CFN template (low risk, deployment window)

| Zmiana | Impact |
|--------|--------|
| `PropagateTags: SERVICE` na wszystkich `AWS::ECS::Service` | Przenosi $267/mo z untagged do attributted |
| Tag blocks na CloudWatch log group resources w CFN | Zapobiega drift tagów |
| Adopt MQ broker do CFN stack lub dokumentuj ManagedBy=manual | Governance |

### 5.3 Priorytet H3 — business decision (nieodwracalne lub wpływ na ruch)

| Akcja | Oszczędności | Zależności |
|-------|-------------|-----------|
| Usuń 4 orphan VPC endpoints w starej QA VPC | $28.80/mo | Potwierdź brak ruchu przez starą VPC |
| Usuń NAT nat-08adf3e0a226779a7 + release EIP 3.76.77.101 | $3.60+/mo | Potwierdź zero bytesOut przez 7 dni |
| Downsize QA MQ z mq.m7g.medium na mq.t3.micro | ~$10/mo | Maintenance window; restart brokera |
| Usuń Global Accelerator (0 traffic confirmed) | $14.98/mo | Potwierdź 0 ruchu; blokuje cleanup starej VPC |
| Pełny decommission starej QA VPC | Removes orphan cost | GA → endpoints → NAT → EIP → IGW → VPC |

---

## 6. Tagging — stan obecny

### 6.1 Dwa równoległe schematy tagów (problem fundamentalny)

| Tag key | QA (nowy schemat) | UAT (stary schemat) | CE filter "no Environment" |
|---------|------------------|--------------------|-----------------------------|
| Project | `Project=planodkupow` | `Projekt=planodkupow` (POLSKIE!) | UAT widoczne jako UNTAGGED |
| Environment | `Environment=qa` | `Srodowisko=uat` (POLSKIE!) | UAT widoczne jako UNTAGGED |
| Owner | `Owner=DC-devops` | `Maintainer=DC-devops` | UAT widoczne jako UNTAGGED |
| ManagedBy | `ManagedBy=cloudformation` | `Provisioner=cloudformation` | UAT widoczne jako UNTAGGED |
| CostCenter | `CostCenter=DC` | **BRAK** | — |

**Polskie klucze `Srodowisko` i `Projekt` nie są aktywne jako Cost Allocation Tags.**

### 6.2 Compliance maturity: Level 2 z 5

| Level | Status |
|-------|--------|
| L1: jakieś tagi na zasobach | ✓ |
| L2: zdefiniowany schemat, częściowo wdrożony | ✓ — ale split QA/UAT |
| L3: schemat spójny we wszystkich środowiskach | ✗ — UAT używa złych kluczy |
| L4: tag policies / SCPs wymuszają compliance | ✗ |
| L5: automated drift detection + remediation | ✗ |

### 6.3 GO/NO-GO dla SCP tag enforcement: **NO-GO**

| Check | Status |
|-------|--------|
| Core resources tagged (VPC, RDS, ALB, TG, Redis, ECS cluster) | ✓ |
| ECS Services PropagateTags=SERVICE | ✗ — 26/28 usług ma NONE |
| MQ broker tagged | ✗ — QA broker zero tagów |
| CloudWatch Log Groups tagged | ✗ — żadna |
| EIPs tagged | ✗ — wszystkie zero tagów |
| VPC endpoints tagged | ✗ — governance tags absent |
| ECR repos tagged | ✗ |
| WAF tagged | ✗ |

---

## 7. Orphan network — stara QA VPC

**Stara QA VPC `vpc-02f804baee8a3f048`:**
- Odpowiadający stack `planodkupow-qa-VPCStack-1OHNJ84RQI8K2` jest `DELETE_COMPLETE`
- VPC, NAT, 4 endpoints, IGW — retained artifacts, wciąż aktywne i naliczające koszty
- BLOKADA: Global Accelerator ma ENIs w tej starej VPC → VPC nie może być usunięta bez GA

**Mapa zasobów orphan:**

```text
vpc-02f804baee8a3f048 (stara QA VPC)
├── nat-08adf3e0a226779a7 → EIP 3.76.77.101 (~$32-50/mo)
├── vpce-0f06338f894336448 — ecr.api ($7.20/mo)
├── vpce-0066f4327e86d8687 — ecr.dkr ($7.20/mo)
├── vpce-0dcfc106af654bae6 — secretsmanager ($7.20/mo)
├── vpce-093fc974c5ae750f4 — logs ($7.20/mo)
├── igw-0862c2814f8c0265b (IGW — $0 ale blokuje cleanup)
└── Global Accelerator ENIs (52.223.4.64, 166.117.244.150 — $14.98/mo, health: Unknown)
```

**Kolejność cleanup (po GO od business):**
1. Confirm GA 0 traffic → remove GA endpoint groups → delete GA
2. Delete 4 legacy VPC endpoints
3. Delete NAT nat-08adf3e0a226779a7
4. Release EIP 3.76.77.101
5. Detach + delete IGW igw-0862c2814f8c0265b
6. Delete subnets starej VPC
7. Delete VPC vpc-02f804baee8a3f048

---

## 8. Amazon MQ — szczegóły

### Aktywne brokery

| BrokerName | Type | Created | Tags | Cost/mo |
|-----------|------|---------|------|---------|
| planodkupow-qa-rabbitmq-cheap | mq.m7g.medium | 2026-04-21 | **ZERO** | ~$21+ |
| planodkupow-uat-RabbitMQ | mq.t3.micro | 2021-08-11 | Stary schemat PL | ~$7-10 |

**Problem:** QA broker `planodkupow-qa-rabbitmq-cheap`:
- Stworzony ręcznie podczas chaos day 19 kwietnia
- Nie jest zasobem w żadnym aktywnym CFN stacku
- `mq.m7g.medium` — droższy niż wymagany do QA; rozważ downgrade do `mq.t3.micro`
- Candidat do adopcji do CFN lub do dokumentacji jako `ManagedBy: manual`

**Chaos-day orphan log groups (brokery usunięte, logi zostały):**

| LogGroup | Retention | Status |
|---------|-----------|--------|
| /aws/amazonmq/broker/b-5cb3fcb4-*/... | NEVER_EXPIRES | DELETE candidate |
| /aws/amazonmq/broker/b-b70793a7-*/... | NEVER_EXPIRES | DELETE candidate |
| /aws/amazonmq/broker/b-9df801b4-*/... | NEVER_EXPIRES | DELETE candidate |

**UAT broker log groups — DOMINANT COST:**
| LogGroup | StoredGB | Retention | Monthly cost |
|---------|---------|-----------|-------------|
| .../b-2d26b881.../connection | 134.96 GB | NEVER_EXPIRES | **~$454/mo ongoing** |
| .../b-2d26b881.../channel | 29.29 GB | NEVER_EXPIRES | **~$98/mo ongoing** |

→ Fix: `put-retention-policy --retention-in-days 30` — auto-purge starszych logów.

---

## 9. Najważniejsze wzorce operacyjne (lessons learned)

### 9.1 Wzorce awarii

- Root CFN update dotykał zbyt wielu nested stacków naraz
- Drift między live state a internal state CFN był krytyczny
- `continue-update-rollback` ze skip może odblokować stack ale zostawić semantycznie niebezpieczny stan
- EOL wersje silników (Redis `5.0.0`, RabbitMQ `3.8.6`) nie są wykrywane przez zwykłą walidację template
- AWS auto-upgrade EOL brokerów MQ → zmiana wersji w runtime vs template = natychmiastowy rollback conflict

### 9.2 Wzorce bezpiecznej pracy

- Nie mieszać tagowania z większymi refaktorami
- Przy wrażliwych stackach: opierać się na change setach z resource-level details
- Preferować wąskie child-stack update lub operacje API zamiast szerokich update root stacka
- Weryfikować NAT/GA ruch przez CloudWatch metrics PRZED cleanup
- `orphan suspect != orphan confirmed` — walidacja z zespołem projektowym przed cleanup

---

## 10. Zalecenia dla ChatGPT

- Traktuj `planodkupow` jako środowisko o podwyższonym ryzyku rollback / drift / blast radius
- UAT stack jest w stanie `UPDATE_ROLLBACK_COMPLETE` — nie zakładaj, że CFN może bezpiecznie zarządzać UAT
- Nie zakładaj, że root stack update jest bezpieczny tylko dlatego, że zmiana wydaje się mała
- Przy RabbitMQ zakładaj: osobny lifecycle, SSM parameter dla `MQCS`, brak dużych root update
- Polskie klucze `Srodowisko`/`Projekt` są nieaktywne w Cost Explorer — nie używaj ich do CE queries
- Przy propozycji planów działań:
  - rozdzielaj QA / UAT (i ewentualnie PROD)
  - klasyfikuj: SAFE / CAUTION / DO NOT TOUCH
  - preferuj read-only diagnostykę i minimal-scope change sets
  - sekwencja cleanup starej VPC musi zachować kolejność: GA → endpoints → NAT → EIP → IGW → subnets → VPC

---

## 11. Pliki źródłowe w vault

```text
# Historia incydentów (vault 40-runbooks/)
40-runbooks/incidents/planodkupow-qa-cfn-rebuild.md
40-runbooks/incidents/planodkupow-qa-postmortem.md
40-runbooks/incidents/planodkupow-qa-execution-log.md
40-runbooks/incidents/planodkupow-qa-rabbitmq-rollback-failed.md
40-runbooks/incidents/planodkupow-uat-rabbitmq-rollback-failed.md
40-runbooks/planodkupow-tagging-finops.md
40-runbooks/planodkupow-rabbitmq-cfn-refactor.md

# Audyty FinOps/governance (kwiecień 2026)
20-projects/clients/mako/planodkupow/planodkupow-orphan-network-investigation-2026-04-24.md
20-projects/clients/mako/planodkupow/planodkupow-finops-governance-audit-2026-04-25.md
20-projects/clients/mako/planodkupow/planodkupow-qa-tagging-audit-2026-04-25.md
20-projects/clients/mako/planodkupow/planodkupow-ce-audit-2026-04-26.md
20-projects/clients/mako/planodkupow/planodkupow-runtime-verification-2026-04-26.md
```

---

## 12. Prompt startowy do ChatGPT

```text
Poniżej przekazuję syntetyczny kontekst operacyjny projektu planodkupow z vaulta devops-knowledge.
Kontekst obejmuje dwa zakresy: (1) historię incydentów CFN/RabbitMQ z początku 2026, (2) pełny
audit FinOps/governance z kwietnia 2026.

Konto AWS: 333320664022, region eu-central-1, profil CLI: plan.
Monthly run-rate: ~$905/mo. Zidentyfikowany waste: $432+/mo.
UAT stack jest w stanie UPDATE_ROLLBACK_COMPLETE.
Polskie tagi (Srodowisko, Projekt) są nieaktywne w Cost Explorer.

Zasady pracy z tym kontekstem:
- Nie zakładaj, że root stack update jest bezpieczny — zawsze analizuj blast radius
- Przy MQ zakładaj osobny lifecycle od root stacka (SSM MQCS)
- Cleanup starej QA VPC wymaga sekwencji: GA → endpoints → NAT → EIP → IGW → VPC
- Klasyfikuj propozycje jako SAFE / CAUTION / DO NOT TOUCH
- Rozdzielaj QA / UAT w każdej rekomendacji
```
