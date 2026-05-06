---
title: secure-ai-anonymizer — data classification
domain: private-rnd
origin: own
classification: restricted
llm_exposure: restricted
cross_domain_export: prohibited
source_of_truth: vault
created: 2026-05-07
updated: 2026-05-07
---

# Data Classification — secure-ai-anonymizer

> Model klasyfikacji danych obsługiwanych przez system. Niezależny od [[CLASSIFICATION_MODEL]] vaultu — dotyczy danych przepływających przez pipeline anonimizacji, nie notatek vault.

---

## Klasy danych wejściowych

### Klasa A — Dane identyfikujące osoby (PII)

**Definicja:** Dane umożliwiające identyfikację osoby fizycznej (RODO).

| Typ | Przykłady | Obowiązkowość tokenizacji |
|-----|---------|--------------------------|
| Imię i nazwisko | Jan Kowalski | Obowiązkowa |
| Email | jan.kowalski@firma.com | Obowiązkowa |
| Numer telefonu | +48 123 456 789 | Obowiązkowa |
| Data urodzenia | 1985-03-15 | Obowiązkowa |
| PESEL | 85031512345 | Obowiązkowa |
| Adres zamieszkania | ul. Kwiatowa 5, 00-001 Warszawa | Obowiązkowa |

**Ryzyko wycieku:** CRITICAL — regulacje RODO, odpowiedzialność prawna.

---

### Klasa B — Dane infrastruktury klienta

**Definicja:** Identyfikatory zasobów, adresy, topologia sieci, konfiguracja systemów klienta.

| Typ | Przykłady | Obowiązkowość tokenizacji |
|-----|---------|--------------------------|
| AWS Account ID | 864277686382 | Obowiązkowa |
| AWS ARN | arn:aws:ecs:eu-west-2:... | Obowiązkowa |
| IP addresses | 10.0.1.45, 34.240.12.5 | Obowiązkowa |
| CIDR blocks | 10.0.0.0/16, 172.16.0.0/12 | Obowiązkowa |
| Hostnames/FQDNs | db.prod.client.internal | Obowiązkowa |
| VPC/Subnet IDs | vpc-0123456789abcdef | Zalecana |
| Resource names | prod-web-cluster, rds-main | Zalecana (z kontekstem) |

**Ryzyko wycieku:** HIGH — ujawnia topologię infrastruktury klienta, umożliwia targeted attacks.

---

### Klasa C — Dane uwierzytelniające i sekrety

**Definicja:** Credentials, klucze, tokeny, hasła, connection strings.

| Typ | Przykłady | Obowiązkowość tokenizacji |
|-----|---------|--------------------------|
| AWS Access Keys | AKIAIOSFODNN7EXAMPLE | Obowiązkowa + alert |
| AWS Secret Keys | wJalrXUtnFEMI/... | Obowiązkowa + alert |
| Hasła do baz | password=secret123 | Obowiązkowa |
| Connection strings | mongodb://user:pass@host | Obowiązkowa |
| API keys | Bearer eyJhbGci... | Obowiązkowa |
| JWT tokens | eyJ... | Obowiązkowa |
| SSH private keys | -----BEGIN RSA... | Obowiązkowa + alert |
| TLS certificates | -----BEGIN CERTIFICATE... | Obowiązkowa |

**Ryzyko wycieku:** CRITICAL — bezpośredni dostęp do systemów klienta.

**Dodatkowe działanie:** Wykrycie Klasy C aktywuje alert operatora z zaleceniem rotacji klucza.

---

### Klasa D — Dane organizacyjne i biznesowe

**Definicja:** Informacje o strukturze organizacyjnej, procesach, decyzjach biznesowych klienta.

| Typ | Przykłady | Obowiązkowość tokenizacji |
|-----|---------|--------------------------|
| Nazwy klientów / partnerów | BMW, Maspex | Obowiązkowa |
| Nazwy projektów wewnętrznych | Projekt Phoenix | Zalecana |
| Budżety / koszty | $12,500/miesiąc | Obowiązkowa |
| Daty kluczowych zdarzeń | deadline 2026-06-15 | Zalecana |
| Dane kontaktowe organizacji | procurement@client.com | Obowiązkowa |

**Ryzyko wycieku:** MEDIUM — potencjalny wyciek informacji poufnych klienta.

---

### Klasa E — Metadane techniczne (niska wrażliwość)

**Definicja:** Dane techniczne, które nie identyfikują bezpośrednio klienta ani nie dają dostępu do systemów.

| Typ | Przykłady | Obowiązkowość tokenizacji |
|-----|---------|--------------------------|
| Wersje oprogramowania | nginx/1.24.0 | Opcjonalna (recognizer ostrzeżenie) |
| Nazwy usług AWS bez kontekstu | ECS, ALB, RDS | Nie tokeniizuj |
| Regiony AWS | eu-west-2 | Zalecana (z kontekstem) |
| Porty sieciowe | 443, 27017 | Opcjonalna |
| Klucze JIRA | PROJ-1234 | Zalecana (identyfikuje projekt) |

**Ryzyko wycieku:** LOW — samo w sobie nie identyfikuje klienta, ale w kombinacji może.

---

## Polityka "minimum necessary"

Przed tokenizacją sprawdź: czy ten fragment dokumentu jest potrzebny dla zadania LLM?

Jeśli fragment zawiera tylko Klasę E (metadane techniczne) i nie jest konieczny → usuń przed wysyłką zamiast tokenizować.

Tokenizacja nie jest substytutem oceny minimum necessary.

---

## Typy dokumentów i oczekiwane klasy danych

| Typ dokumentu | Typowe klasy | Ryzyko |
|--------------|-------------|--------|
| Terraform `.tf` | B, C (w tfvars) | HIGH |
| cloud-detective output | B | HIGH |
| `docker-compose.yml` | B, C | CRITICAL |
| `values.yaml` (Helm) | B, C | HIGH |
| CloudWatch logs | A, B | HIGH |
| DOCX spec klienta | A, D | HIGH |
| PDF architektura | B, D | MEDIUM |
| `.env` / `secrets.*` | C | CRITICAL |
| Meeting notes | A, D | MEDIUM |
| YAML CI/CD (GitHub Actions) | B, C | CRITICAL |

---

## Klasy danych a LLM routing

| Klasa | Sanitized? | Dozwolone narzędzia LLM |
|-------|-----------|------------------------|
| A (PII) | Tak | Claude API, ChatGPT Enterprise |
| B (Infra) | Tak | Claude API, ChatGPT Enterprise |
| C (Secrets) | Tak — + alert | Claude API, ChatGPT Enterprise |
| D (Business) | Tak | Claude API, ChatGPT Enterprise |
| E (Metadane) | Opcjonalnie | Dowolne LLM |
| Bez sanitizacji | NIE | PROHIBITED (patrz [[LLM_EXPORT_POLICY]]) |

**Zasada:** System nie routuje automatycznie do LLM. Operator kopiuje sanitized document manualnie. System tylko generuje sanitized output + waliduje że jest poprawnie zanonimizowany.
