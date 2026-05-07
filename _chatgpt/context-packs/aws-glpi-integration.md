# Paczka kontekstu — AWS Health → GLPI Integration

> Wklej całość na początku rozmowy z ChatGPT. Cel: <1500 tokenów.

**Zakres:** Implementacja pilota: AWS Health events → GLPI Problems (MakoLab internal)
**Data przygotowania:** 2026-05-07

---

## Kim jestem / kontekst roli

Senior DevOps/SRE, AWS multi-account (Organizations o-5c4d5k6io1, 12 kont), Terraform + Python, ECS Fargate. Pracuję nad integracją alertów AWS z GLPI (nasz ITSM).

---

## Stan obecny

Mamy **działający łańcuch eventów**: EventBridge (konta źródłowe) → cross-account bus `health-aggregation` (monitoring account 814662658531, us-east-1) → Lambda `health-notify` (python3.12) → SNS `health-notifications` → email do mnie.

GLPI **nie jest jeszcze podpięte** — ostatnim krokiem jest tylko email. Chcemy dodać GLPI Problem creation jako drugi output Lambdy lub osobny Lambda connector.

---

## Kluczowe fakty — infrastruktura

- **11/12 kont** forwarduje Health events na central bus (gap: makolab_dc 864277686382 — do naprawy Terraformem, osobna sprawa)
- **Central bus ARN:** `arn:aws:events:us-east-1:814662658531:event-bus/health-aggregation`
- **Lambda health-notify:** `arn:aws:lambda:us-east-1:814662658531:function:health-notify` — python3.12, handler: `main.handler`, timeout 30s, 128MB
- Lambda dostaje event → wzbogaca o nazwę konta (env var ACCOUNT_NAMES) → publikuje do SNS
- **Brak DLQ** w całym łańcuchu (to osobny task)
- **Nieużywany SNS topic:** `arn:aws:sns:us-east-1:814662658531:health-ops-alerts` — prawdopodobnie placeholder dla GLPI

## Kluczowe fakty — GLPI

- GLPI REST API endpoint: `POST /apirest.php/Problem`
- Autentykacja: token (szczegóły do ustalenia z IT ops)
- Open questions: czy Problems module jest skonfigurowany, kto będzie assignee, jaki workflow

## Co chcemy łapać (decyzja)

Tylko **issue + open** na start. Nie: investigation (za dużo false positives), scheduledChange (faza 2), accountNotification (nie nadaje się do ticketów).

```json
{
  "source": ["aws.health"],
  "detail-type": ["AWS Health Event"],
  "detail": {
    "eventTypeCategory": ["issue"],
    "statusCode": ["open"]
  }
}
```

## Mapowanie AWS Health → GLPI Problem

| AWS Health field | GLPI Problem field |
|---|---|
| `service` + `eventTypeCode` | `name` |
| `latestDescription` | `content` |
| `startTime` / `endTime` | `time_to_resolve` (jeśli scheduled) |
| `statusCode: open` | `status: 1` (New) |
| region + account_name | tag / category |
| issue category | priority: LOW na start |

---

## Architektura docelowa (preferowana)

**Opcja A — rozszerz istniejącą Lambdę:**
```
EventBridge → Lambda health-notify → SNS (email, jak teraz)
                                   → GLPI REST API POST /Problem (nowy output)
```

**Opcja B — osobny Lambda connector (cleaner separation):**
```
EventBridge → Lambda health-notify → SNS health-notifications (email)
                                   → SNS health-glpi-connector (nowy topic)
                                       └── Lambda glpi-connector → GLPI REST API
```

Preferuję Opcję B (SRP, łatwiej testować, SNS jako buffer), ale chętnie omówię tradeoffs.

---

## Pytanie

Pomóż mi zaprojektować **Lambdę glpi-connector** (python3.12):
1. Odbiera event z SNS (który jest wzbogaconym AWS Health eventem z health-notify)
2. Mapuje pola na GLPI Problem fields (tabela wyżej)
3. Wywołuje GLPI REST API `POST /apirest.php/Problem` z auth tokenem z Secrets Manager
4. Loguje wynik do CloudWatch (sukces / błąd / conflict)
5. Idempotentność: nie tworzy duplikatu jeśli Problem dla `eventArn` już istnieje

Potrzebuję: kod Lambdy, schemat request body dla GLPI REST API Problems, jak sprawdzić duplikaty (GLPI API), jak przechowywać token (Secrets Manager pattern), obsługa błędów.
