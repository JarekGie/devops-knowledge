# Klasy danych wrażliwych

| Klasa | Przykłady | Ryzyko wycieku | Anonimizacja |
|---|---|---:|---|
| Sekrety i dane uwierzytelniające | hasła, tokeny API, JWT, klucze SSH, private keys, connection stringi | Krytyczne | Zawsze |
| Dane sieciowe i infrastrukturalne | IP, CIDR, hostnames, domeny prywatne, ARNy, ID kont AWS, nazwy subnetów | Wysokie | Zawsze lub warunkowo |
| Dane personalne i kontaktowe | imiona, nazwiska, maile, telefony, stanowiska, identyfikatory pracowników | Wysokie | Zawsze, chyba że zatwierdzono inaczej |
| Dane kontraktowe / vendorowe / klientowskie | nazwy klientów, vendorów, numery umów, SLA, warunki handlowe | Wysokie | Warunkowo, zależnie od celu analizy |
| Dane architektoniczne i operacyjne | nazwy systemów, zależności, topologia, runbooki, procedury awaryjne | Średnie/Wysokie | Warunkowo |
| Logika biznesowa | reguły rabatowe, procesy klienta, scoring, warunki decyzyjne | Średnie/Wysokie | Zależnie od kontekstu |
| Dane konfiguracyjne aplikacji | env vars, feature flags, nazwy kolejek, bucketów, topiców, endpointy | Średnie/Wysokie | Zawsze dla sekretów, warunkowo dla reszty |
| Identyfikatory systemów i zależności | nazwy repo, service names, database names, queue names, project codes | Średnie | Warunkowo |

## Uwagi

Nie każda nazwa systemu musi być usunięta. Czasem zachowanie relacji jest ważniejsze niż pełne ukrycie każdego identyfikatora.

Przykład:
- `payment-api` może stać się `SERVICE_001`,
- `orders-db` może stać się `DATABASE_001`,
- relacja `SERVICE_001 -> DATABASE_001` powinna zostać zachowana.

## Do ustalenia

- Które klasy anonimizować zawsze.
- Które klasy anonimizować zależnie od klienta.
- Czy nazwy klientów zawsze zastępować tokenami.
- Czy domeny publiczne traktować jako dane wrażliwe.
