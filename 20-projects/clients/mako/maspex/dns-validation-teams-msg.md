# Wiadomość Teams dla klienta — walidacja certyfikatu SSL

> Gotowe do wklejenia. Usuń ten nagłówek przed wysłaniem.

---

Cześć,

Przygotowujemy przełączenie domeny **twojkapsel.pl** na środowisko produkcyjne. Żeby SSL działał poprawnie na wszystkich adresach, potrzebujemy dodania 4 rekordów DNS (walidacja certyfikatu AWS).

Proszę o dodanie poniższych rekordów CNAME w Cloudflare:

---

**Rekord 1**
Typ: CNAME
Nazwa: `_38d6a94242bfd37422838d3e07fd286c.twojkapsel.pl`
Wartość: `_940513cb65e2b80c74b89833ab576d0b.jkddzztszm.acm-validations.aws`

---

**Rekord 2**
Typ: CNAME
Nazwa: `_93e30ab42d58f640c33e13bd6e6f4b65.www.twojkapsel.pl`
Wartość: `_f4dc790cf04d008870112cca42ab3cdd.jkddzztszm.acm-validations.aws`

---

**Rekord 3**
Typ: CNAME
Nazwa: `_e7e7b98d03b0717e585cbc0af745574f.test.twojkapsel.pl`
Wartość: `_ef314654a6600ad0d52080e30cf6ea41.jkddzztszm.acm-validations.aws`

---

**Rekord 4**
Typ: CNAME
Nazwa: `_7508ba16731584ebe5a9d4b93ec9a06a.www.test.twojkapsel.pl`
Wartość: `_f1e8da8167ed877a5cb2335900bbda05.jkddzztszm.acm-validations.aws`

---

Po dodaniu rekordów walidacja następuje automatycznie (zazwyczaj 2–5 minut). Nie ma potrzeby informowania nas — sprawdzimy status samodzielnie przed przełączeniem.

Osobno wyślę informację kiedy będziemy gotowi do zmiany docelowego CNAME dla `twojkapsel.pl`.

Dzięki!
