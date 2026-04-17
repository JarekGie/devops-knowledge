# System wtyczek

#toolkit #plugins

## Koncepcja

Każda kategoria komend (audit, finops, iac) to osobna wtyczka.  
Toolkit ładuje wtyczki dynamicznie przez contract registry.

## Interfejs wtyczki

```python
# Przykładowy interfejs (pseudokod)
class PluginContract:
    name: str                    # np. "audit.iam"
    description: str
    input_schema: dict           # JSON Schema
    output_schema: dict          # JSON Schema
    
    def execute(self, input: dict) -> dict:
        ...
```

## Rejestracja wtyczek

```
# Wzorzec: wtyczka rejestruje się przez konwencję nazewnictwa
# lub explicite w config

plugins/
├── audit_iam.py      → komenda "audit iam"
├── audit_s3.py       → komenda "audit s3"
└── finops_report.py  → komenda "finops report"
```

## Contract validation

Każda komenda waliduje input przed wykonaniem.  
Output jest zawsze walidowany przed zwróceniem.

## Zasady

1. Wtyczka nie zna innych wtyczek
2. Wtyczka nie ma side effects poza AWS API calls (read-only domyślnie)
3. Write operations wymagają explicit `--confirm` flag
4. Wtyczka zawsze zwraca valid JSON nawet przy błędzie

## Powiązane

- [[contracts-index]]
- [[architecture-overview]]
