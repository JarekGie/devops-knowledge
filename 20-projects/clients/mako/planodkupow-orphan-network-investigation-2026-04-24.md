---
date: 2026-04-24
project: planodkupow
client: mako
tags: [planodkupow, aws, network, vpc, nat, vpc-endpoint, investigation, read-only]
domain: client-work/mako
---

# Planodkupow — legacy network artifacts investigation (read-only)

## Executive Summary

Wynik śledztwa read-only z 2026-04-24:
- wykryto dwie QA VPC o tym samym `Name`
- nowa QA VPC jest aktywnie używana przez ECS/ALB/RDS/broker
- stara QA VPC zawiera NAT + 4 standard endpoints i wygląda na `orphan suspect`
- AMQ PrivateLink endpoints są aktywnymi zależnościami i **NIE** są orphanami
- brak dowodu, że NAT i stare endpointy są dziś na ścieżce ruchu ECS
- brak także twardego dowodu, że nie są używane przez inne ręczne integracje

Kluczowe zastrzeżenie operacyjne:

`orphan suspect != orphan confirmed`

Ta notatka zapisuje podejrzenia do walidacji z zespołem projektowym. Nie jest to decyzja wykonawcza ani zgoda na cleanup.

## Findings

### Confirmed

- W koncie istnieją dwie różne QA VPC o tym samym `Name=planodkupow-qa-VPC`:
  - `vpc-007d115c41f079bf3` — nowa QA VPC
  - `vpc-02f804baee8a3f048` — starsza QA VPC
- Nowa QA VPC `vpc-007d115c41f079bf3` jest powiązana z aktywnym stackiem `planodkupow-qa-VPCStack-1V91EF1UIC85A`.
- Nowa QA VPC jest aktywnie używana przez:
  - QA ECS cluster i wszystkie running services
  - QA ALB
  - QA RDS
  - QA broker Amazon MQ
- UAT działa w osobnej aktywnej VPC `vpc-0b91c465aa64ba545`.
- NAT Gateway `nat-08adf3e0a226779a7` znajduje się wyłącznie w starej QA VPC `vpc-02f804baee8a3f048`.
- NAT routuje tylko stare prywatne subnety tej starszej QA VPC:
  - `subnet-044777a4a035cb0ab`
  - `subnet-09ab9fdda1c1d2dea`
- Cztery standardowe VPC endpoints znajdują się wyłącznie w starej QA VPC:
  - `vpce-0f06338f894336448` — `ecr.api`
  - `vpce-0066f4327e86d8687` — `ecr.dkr`
  - `vpce-0dcfc106af654bae6` — `secretsmanager`
  - `vpce-093fc974c5ae750f4` — `logs`
- Dwa AMQ PrivateLink endpoints są aktywnymi zależnościami:
  - `vpce-0973cb43ab01ac289` — UAT broker `b-2d26b881-79f2-4c3c-8b77-06c1a0fb0b29`
  - `vpce-0aab2367ad6396bd9` — QA broker `b-f231815d-d0dd-42c5-aeb8-c2aeeaa3f803`
- Aktywne QA ECS tasks nie siedzą w starej QA VPC. Wszystkie running QA tasks są w nowej QA VPC.
- Aktywne UAT ECS tasks są w UAT VPC.
- Historyczny stack lineage dla starej QA VPC istnieje, ale odpowiadający stack jest dziś `DELETE_COMPLETE`:
  - `planodkupow-qa-VPCStack-1OHNJ84RQI8K2`

### Suspected

- Stara QA VPC `vpc-02f804baee8a3f048` wygląda na `orphan suspect`.
- NAT `nat-08adf3e0a226779a7` wygląda na `orphan suspect`.
- Cztery standardowe endpointy w starej QA VPC wyglądają na `orphan suspect`.
- Część retained security groups i innych zasobów sieciowych ze starego QA wygląda na residual artifacts po starszym środowisku.
- Starsze zasoby oznaczone historycznymi tagami `aws:cloudformation:*` po stackach dziś `DELETE_COMPLETE` mogą być retained artifacts, a nie aktywnym targetem bieżącego IaC.

### Unknown

- Czy istnieją ręczne integracje poza CloudFormation korzystające ze starej QA VPC, NAT lub starych endpointów.
- Czy istnieją manual hosts / tools / batch korzystające ze starej QA VPC.
- Czy istnieją zależności legacy poza ECS/ALB/RDS/Amazon MQ, których nie widać w podstawowym inventory.
- Jaki jest formalny ownership QA broker `planodkupow-qa-rabbitmq-cheap`, który jest aktywny, ale nie jest widoczny jako nested resource w aktywnym root stacku QA.
- Czy brak datapoints dla metryk NAT oznacza realnie brak ruchu, czy tylko brak zwróconego evidence w użytym zakresie metryk.

## Risk Statement

**DO NOT TREAT THIS AS CLEANUP APPROVAL**

Usunięcie:
- starej QA VPC
- NAT `nat-08adf3e0a226779a7`
- 4 legacy endpoints
- retained security groups

bez walidacji z zespołem projektowym może spowodować outage.

Wprost:

**blind cleanup could be catastrophic.**

Ta notatka nie autoryzuje żadnej mutacji i nie identyfikuje żadnego zasobu jako zatwierdzonego kandydata do usunięcia.

## Decision (important)

**Decision: HOLD**

- no cleanup decision made
- no deletion candidate approved
- no mutation recommended before project owner validation

Planned next step:
- omówić w poniedziałek z zespołem projektowym
- potwierdzić, czy istnieją manual workloads/dependencies poza IaC
- dopiero po tym ewentualny osobny cleanup assessment

## Classification update

Korekta interpretacyjna:

Wcześniejsze `endpoint tagging gap` oraz `NAT tagging gap` mogą być częściowo skażone przez legacy orphan-suspect assets i nie powinny być interpretowane automatycznie jako aktywne compliance blockers bez dalszej analizy.

To jest ważna korekta epistemiczna:
- nie każdy untagged lub legacy-tagged zasób jest aktywnym blockerem compliance
- część może należeć do warstwy residual / legacy / orphan suspect
- klasyfikacja musi rozdzielać aktywne zasoby od retained artifacts i active external dependencies

## Evidence Appendix

### VPC IDs

- nowa QA VPC: `vpc-007d115c41f079bf3`
- stara QA VPC: `vpc-02f804baee8a3f048`
- UAT VPC: `vpc-0b91c465aa64ba545`
- default VPC: `vpc-6e1d9904`

### NAT ID

- `nat-08adf3e0a226779a7`

### Endpoint IDs

- `vpce-0973cb43ab01ac289` — UAT AMQ PrivateLink
- `vpce-0f06338f894336448` — QA `ecr.api` w starej QA VPC
- `vpce-0066f4327e86d8687` — QA `ecr.dkr` w starej QA VPC
- `vpce-0dcfc106af654bae6` — QA `secretsmanager` w starej QA VPC
- `vpce-093fc974c5ae750f4` — QA `logs` w starej QA VPC
- `vpce-0aab2367ad6396bd9` — QA AMQ PrivateLink

### Stare / nowe QA VPC mapping

- aktywna QA:
  - root stack: `planodkupow-qa`
  - VPC stack: `planodkupow-qa-VPCStack-1V91EF1UIC85A`
  - VPC: `vpc-007d115c41f079bf3`
- starsza QA lineage:
  - historyczny VPC stack: `planodkupow-qa-VPCStack-1OHNJ84RQI8K2`
  - VPC: `vpc-02f804baee8a3f048`
  - status stacka: `DELETE_COMPLETE`

### DELETE_COMPLETE lineage dla starego stacka

Potwierdzone w historii CFN:
- `planodkupow-qa-VPCStack-1OHNJ84RQI8K2` — `DELETE_COMPLETE`
- historyczne QA root i nested stacks z 2021 również są `DELETE_COMPLETE`

To wzmacnia hipotezę `legacy residual artifacts`, ale samo w sobie nadal nie jest dowodem braku użycia.

## Lessons Learned

Krótka notatka ADR-style:

W auditach należy rozdzielać:
1. active compliance gaps
2. legacy residual artifacts
3. orphan suspects
4. active external dependencies

To rozróżnienie ma znaczenie operacyjne i poznawcze:
- zmniejsza ryzyko błędnego cleanupu
- ogranicza fałszywe compliance blockers
- poprawia jakość klasyfikacji w przyszłym refactorze `devops-toolkit`

## Cross-References

- [planodkupow-tagging-finops.md](/Users/jaroslaw.golab/projekty/devops/devops-knowledge/40-runbooks/planodkupow-tagging-finops.md)
