# Current Focus

> Co jest ważne w tym tygodniu / sprincie. Nie lista todo — priorytety.

## Główny cel

```
Przełączony kontekst roboczy: maspex troubleshooting.
Skupić się na UAT / preprod w repo Terraform `infra-maspex` i wejść przez aktywne wpisy w troubleshooting.
```

## Projekty aktywne

| Projekt | Status | Następny krok |
|---------|--------|---------------|
| maspex | aktywny | po admin CloudFront fix: dopilnować push/PR commita `4810f3c`; otwarty follow-up: Redis secret dla preprod |
| devops-toolkit | w tle | |
| devops-platform | w tle | |
| devops-business | w tle | |

## Priorytety tygodnia

1.
2. Maspex: domknąć repo po live fixie admin CloudFront (`feat/preprod-zaslepka` ahead 1) albo przejść do preprod Redis secret.
3. Utrzymać pozostałe tematy jako kontekst poboczny, nie aktywny.

## Aktywni klienci

| Klient | Temat | Deadline |
|--------|-------|----------|
| Mako | Maspex troubleshooting | |

## Blokery / otwarte pętle

- [ ] `infra-maspex` ma lokalny commit `4810f3c` niepushowany (`feat/preprod-zaslepka` ahead 1)
- [ ] Redis connection string do Secrets Manager `maspex/preprod/api` nadal otwarte

## Powiązane

- [[now]] — co robię w tej chwili
- [[open-loops]] — rzeczy w toku bez zakończenia
- [[waiting-for]] — czekam na
- [[decision-log]] — decyzje do podjęcia

---

*Tydzień: 2026-W17*
