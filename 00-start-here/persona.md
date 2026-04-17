# Persona — Jarosław Gołąb

## Kim jestem

Doświadczony inżynier DevOps / SRE. Pracuję głównie z AWS, uzupełniająco z GCP i Azure.

## Stack techniczny

**IaC:** Terraform, Terragrunt, CloudFormation, Helm  
**CI/CD:** GitHub Actions, GitLab CI, Jenkins, Make  
**Infrastruktura:** ECS, EKS, GKE, ALB, CloudFront, VPC, RDS, DocumentDB, Redis

## Priorytety

- Automatyzacja powtarzalnych operacji
- Standardy i wzorce zamiast ad-hoc rozwiązań
- Architektura i FinOps jako pierwszoklasowe priorytety
- Audyty AWS — jakość, koszty, bezpieczeństwo
- Debugowanie systemów rozproszonych

## Model biznesowy

DevOps-as-a-Service: pakiety godzinowe, model B2B, zdalna realizacja.  
Klienci otrzymują powtarzalne wyniki, nie jednorazowe usługi.

## devops-toolkit

Bezstanowe CLI — control plane dla AWS, FinOps, audytów IaC i raportów.  
Budowane w oparciu o kontrakty, interfejsy i wzorce wielokrotnego użytku.  
Szczegóły: [[architecture-overview]], [[contracts-index]]

## Jak myślę

- Kontrakty i interfejsy przed implementacją
- Wzorce wielokrotnego użytku zamiast jednorazowych rozwiązań
- Determinizm: jeśli coś nie jest powtarzalne, nie nadaje się do skali
- Praktyczne rozwiązania > teoria i dokumentacja dla dokumentacji

## ADHD — implikacje dla systemu wiedzy

**Działa dobrze:**
- Szybki dostęp do izolowanych fragmentów informacji
- Modularne notatki — każda działa niezależnie
- Krótkie bloki kontekstu
- Fragmenty wielokrotnego użytku (snippety, szablony, komendy)

**Nie działa:**
- Długie liniowe instrukcje
- Gigantyczne checklisty
- Notatki, które wymagają czytania od początku do końca
- Systemy, które "piszesz zanim możesz zacząć"

**Zasada vaulta:** wejdź, znajdź, użyj. System musi redukować obciążenie pamięci, nie zwiększać.
