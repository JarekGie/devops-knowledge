# ChatGPT Context Pack — planodkupow operations / incidents

Data aktualizacji: 2026-04-24

Ten plik jest syntetyczną paczką kontekstu do rozmów z ChatGPT o `planodkupow`.
Zakres obejmuje wyłącznie to, co już istnieje w vault: runbooki, troubleshooting, RCA,
postmortem i decyzje operacyjno-architektoniczne związane z CloudFormation, RabbitMQ,
tagging/FinOps i recovery środowisk.

## 1. Executive Summary

`planodkupow` w koncie AWS `333320664022` (`eu-central-1`, profil CLI `plan`) ma historię
kilku powiązanych incydentów infrastrukturalnych:
- QA `UPDATE_ROLLBACK_FAILED` po deployu LLZ/tagging,
- osobne incydenty RabbitMQ na QA i UAT,
- refaktor architektury RabbitMQ, aby wyjść z lifecycle root stacka,
- prace przygotowawcze pod bezpieczne tagowanie / FinOps / przyszłe SCP.

Najważniejszy wzorzec problemów:
- root stack CloudFormation miał zbyt szeroki blast radius,
- zmiany pozornie aplikacyjne lub taggingowe mogły dotknąć RabbitMQ / Redis / DB / ALB,
- rollbacky były blokowane przez EOL, drift, brak uprawnień IAM i zależności między nested stackami.

Najważniejszy kierunek naprawy:
- ograniczać scope deployów,
- traktować RabbitMQ jako osobny lifecycle,
- unikać szerokich root update bez bardzo dokładnej analizy change setów,
- tagowanie wdrażać etapowo, addytywnie i bez łączenia z innymi refaktorami.

## 2. Stan obecny w vault

- QA przeszło przez pełny rebuild po `UPDATE_ROLLBACK_FAILED`.
- UAT miało osobny incydent RabbitMQ zablokowany przez drift + rollback do EOL wersji.
- QA miało też osobny incydent RabbitMQ związany z brakami IAM (`mq:UpdateBroker`, `mq:RebootBroker`) i pętlą rollback.
- W vault jest już zapisana decyzja architektoniczna, że RabbitMQ powinno wyjść z lifecycle root stacka i być spięte z KlasterStack przez SSM parameter `MQCS`.
- W vault jest też plan bezpiecznego tagowania pod FinOps/SCP, z wyraźnym podziałem na `SAFE`, `CAUTION`, `DO NOT TOUCH`.

## 3. Najważniejsze fakty operacyjne

### Środowiska i konto

```text
AWS account: 333320664022
Region: eu-central-1
CLI profile: plan

QA:
  root stack: planodkupow-qa
  cluster:    planodkupow-qa-Klaster

UAT:
  root stack: planodkupow-uat
  cluster:    planodkupow-uat-Klaster
```

### QA — główny incydent CFN rebuild

- Incydent zaczął się po deployu LLZ/tagów.
- Przyczyna pierwotna: Redis `5.0.0` EOL, co uruchomiło Replace i rozbiło rollback.
- W trakcie recovery odkryto dodatkowe problemy:
  - RabbitMQ `3.8.6` EOL,
  - `mq.t3.micro` niewspierane dla nowych brokerów RabbitMQ,
  - zewnętrzny rekord DNS blokujący CloudFront,
  - brak `DeletionPolicy: Retain` na RDS / DB SG,
  - zły `HealthCheckPath` (`/signin`) dla Ocelot gateway.
- Recovery wymagało delete + redeploy, backupu, retain resources i kilku iteracji cleanup.

### QA — RabbitMQ incident (oddzielny)

- Root cause: brak wymaganych uprawnień IAM dla deployment identity:
  - `mq:UpdateBroker`
  - `mq:RebootBroker`
- `continue-update-rollback --resources-to-skip` zamroził CFN internal state i utrwalił drift.
- Wybrano strategię:
  - recreate nowego brokera,
  - cutover ECS przez parametr `MQCS`,
  - usunięcie starego brokera.

### UAT — RabbitMQ incident

- Broker był już auto-upgrade’owany przez AWS do `3.13.7`, ale template nadal miał `3.8.6`.
- Deploy wszedł w rollback, który próbował przywrócić EOL `3.8.6`.
- Recovery wymagało:
  - `continue-update-rollback` na root stacku z poprawnym `resources-to-skip`,
  - osobnego sync child stacków RabbitMQ i Redis,
  - dopięcia brakujących uprawnień IAM do deployment identity.

### Tagging / FinOps

- QA ma nowy schemat tagów (`Project`, `Environment`, `Owner`, `ManagedBy`, `CostCenter`) na dużej części zasobów.
- UAT ma starszy schemat (`Maintainer`, `Provisioner`, `Team`, `Client`, `typ`) plus `Project` / `Environment`.
- Strategia zapisana w vault:
  - nie robić wielkiego refaktoru tagów jednym ruchem,
  - najpierw operacja addytywna,
  - CloudFront wyłączony z pierwszej fali,
  - RDS i część zasobów tagować bezpośrednio przez API, nie przez szeroki update CFN.

### RabbitMQ — docelowy kierunek architektoniczny

- RabbitMQ ma wyjść z root stacka.
- `KlasterStack` ma pobierać `MQCS` z SSM:

```text
/planodkupow/<env>/rabbitmq/mqcs
```

- Cel: zmniejszyć blast radius root deployów i oddzielić lifecycle messaging od deployów aplikacyjnych.

## 4. Wzorce i lekcje

### Wzorce awarii

- root update dotykał zbyt wielu nested stacków,
- drift między live state a internal state CFN był krytyczny,
- `continue-update-rollback` ze skip może odblokować stack, ale zostawić semantycznie niebezpieczny stan,
- EOL wersje silników nie są wcześnie wykrywane przez zwykłą walidację template,
- zasoby poza pełną kontrolą (DNS, manualne endpointy, manualne SG, orphan resources) potrafią zablokować recovery.

### Wzorce bezpiecznej pracy

- najpierw backup i audyt ręcznych zależności,
- nie mieszać tagowania z większymi refaktorami,
- nie ufać temu, że root `UPDATE_*` oznacza realną zmianę zasobów,
- przy wrażliwych stackach opierać się na change setach i weryfikacji resource-level details,
- preferować wąskie child-stack update lub operacje API zamiast szerokich update root stacka.

## 5. Zalecenia dla ChatGPT podczas pracy z tym kontekstem

- Traktuj `planodkupow` jako środowisko o podwyższonym ryzyku rollback / drift / blast radius.
- Nie zakładaj, że root stack update jest bezpieczny tylko dlatego, że zmiana wydaje się mała.
- Jeśli proponujesz plan działań:
  - rozdzielaj QA / UAT / PROD,
  - zaznaczaj co jest `SAFE`, `CAUTION`, `DO NOT TOUCH`,
  - preferuj read-only diagnostykę i minimal-scope change sets,
  - zaznaczaj kiedy potrzebny jest owner domeny / zewnętrzny DNS / ręczna koordynacja.
- Przy RabbitMQ zakładaj model:
  - osobny lifecycle,
  - SSM parameter dla `MQCS`,
  - brak dużych root update tylko po to, żeby zsynchronizować messaging.

## 6. Pliki źródłowe w vault

To są wszystkie znalezione notatki `planodkupow` w vault, które należy traktować jako źródła:

```text
40-runbooks/incidents/planodkupow-qa-cfn-rebuild.md
40-runbooks/incidents/planodkupow-qa-postmortem.md
40-runbooks/incidents/planodkupow-qa-execution-log.md
40-runbooks/incidents/planodkupow-qa-rabbitmq-rollback-failed.md
40-runbooks/incidents/planodkupow-uat-rabbitmq-rollback-failed.md
40-runbooks/planodkupow-tagging-finops.md
40-runbooks/planodkupow-rabbitmq-cfn-refactor.md
```

## 7. Krótki prompt startowy do ChatGPT

```text
Poniżej przekazuję syntetyczny kontekst operacyjny projektu planodkupow z vaulta devops-knowledge.
Traktuj go jako źródło prawdy dla historii incydentów, RabbitMQ, CloudFormation, tagging/FinOps i decyzji architektonicznych.
Nie proponuj szerokich root stack update bez wyraźnego uzasadnienia i analizy blast radius.
Jeśli rekomendujesz działania, rozdziel SAFE / CAUTION / DO NOT TOUCH oraz QA / UAT / PROD.
```
