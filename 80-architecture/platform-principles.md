# Zasady platformy

Niezmienniki projektowe — zasady, które nadpisują lokalne decyzje.

#architecture #principles

## Zasady infrastruktury

1. **Infrastructure as Code** — wszystko w IaC, nic ręcznie w produkcji
2. **Immutable infrastructure** — nie patchuj instancji, deplouj nowe
3. **Least privilege** — najwęższe uprawnienia IAM jakie są możliwe
4. **Encryption everywhere** — dane at rest i in transit zawsze szyfrowane
5. **Tagging enforcement** — zasób bez tagów = zasób niczyj

## Zasady aplikacji / serwisów

1. **Stateless** — serwisy nie trzymają stanu lokalnie
2. **Health checks** — każdy serwis ma endpoint healthcheck
3. **Graceful shutdown** — SIGTERM obsługiwany, połączenia zamykane czysto
4. **12-Factor** — konfiguracja przez zmienne środowiskowe, nie pliki

## Zasady CI/CD

1. **One artifact per build** — ten sam image przechodzi przez wszystkie envs
2. **Approval gate na prod** — żaden deploy na produkcję bez ręcznego zatwierdzenia
3. **Rollback w < 5 minut** — architektura musi umożliwiać szybki rollback
4. **Sekrety poza kodem** — zawsze Secrets Manager / SSM

## Zasady FinOps

1. **Tag before create** — zasoby tworzone z tagami, nie tagowane po fakcie
2. **Cost visibility per project** — każdy projekt musi mieć osobną alokację kosztów
3. **Idle resources = waste** — regularne przeglądy, automatyczne raporty

## Zasady DevOps-as-a-Service

1. **Powtarzalność > jednorazowość** — każde rozwiązanie musi być wzorcem
2. **Kontrakt przed implementacją** — definiuj interfejs zanim napiszesz kod
3. **Raport = produkt** — klient płaci za wyniki, nie za czas

## Powiązane

- [[decision-log]]
- [[iac-standard]]
- [[aws-tagging-standard]]
- [[cicd-standard]]
