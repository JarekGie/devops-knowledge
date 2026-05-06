---
title: secure-ai-anonymizer — context
domain: private-rnd
origin: own
classification: restricted
llm_exposure: restricted
cross_domain_export: prohibited
source_of_truth: vault
created: 2026-05-07
updated: 2026-05-07
tags: [private-rnd, secure-ai, anonymizer, tokenization, llm-safety]
---

# secure-ai-anonymizer

> Lokalny pipeline anonimizacji danych klientów umożliwiający bezpieczne użycie zewnętrznych LLM bez wycieku danych wrażliwych.

## Czym jest ten projekt

System przetwarzania dokumentów klientów (pre-processing przed wysyłką do zewnętrznych LLM):
- **parsuje** dokumenty (PDF, DOCX, XLSX, Terraform, YAML, logi, exporty),
- **klasyfikuje** zawartość pod kątem wrażliwości,
- **wykrywa** dane wrażliwe (PII, infra IDs, sekrety, dane finansowe),
- **tokenizuje** dane — zastępuje wartości wrażliwe tokenami placeholder,
- **tworzy** zaszyfrowany mapping token → oryginał,
- **generuje** sanitized document gotowy do eksportu do zewnętrznego LLM,
- **umożliwia** rehydratację — przywrócenie oryginalnych wartości po odpowiedzi LLM,
- **tworzy** audit trail każdej operacji.

To **nie jest**: chatbot, klasyczny RAG, AI app, pipeline generatywny.

To jest: **secure AI enablement platform** dla software house / cloud practice — warstwa bezpieczeństwa między danymi klientów a zewnętrznymi LLM.

## Motywacja

Trzy problemy praktyczne obserwowane w pracy operacyjnej:

1. **cloud-detective + onboarding AWS** — scan infrastruktury klientów generuje dokumenty z account IDs, CIDR blokami, ARNami, sekretami. Użycie LLM (ChatGPT/Claude) wymaga ręcznej anonimizacji lub ryzyko wycieku.

2. **DOMAIN_ISOLATION_CONTRACT vault** — governance vault wymaga anonimizacji przed eksportem do zewnętrznych LLM. Obecnie procesem ręcznym, podatnym na błędy.

3. **Onboarding klientów na MakoLab** — dokumentacja klientów (architektury, diagramy, specyfikacje) zawiera dane wrażliwe. Praca nad nimi z LLM wymaga technicznego egzekwowania polityki eksportu.

Inicjator: Tomasz Polkowski (Head of Cloud), 2026-05-07.

## Czym nie jest — granice projektu

| Poza zakresem | Dlaczego |
|---------------|---------|
| Multi-tenant SaaS | Złożoność nie jest uzasadniona w MVP |
| Automatyczny routing do LLM | Operator decyduje kiedy i do jakiego LLM |
| OCR pipeline | Apache Tika + pdfplumber wystarczą w v1 |
| Keycloak / Vault | Faza 1: PostgreSQL + envelope encryption |
| OpenSearch / Qdrant | Faza 2 / 3 — wyszukiwanie semantyczne |
| Workflow engine | Manual review jest celowy w MVP |
| Generatywny AI | System nie generuje treści — sanitizuje |

## Kontekst organizacyjny

- **MakoLab** — software house ~150 osób, AWS primary, cloud practice w budowie
- **Cel** — wewnętrzna platforma enablement dla engineering team i cloud practice
- **Nie jest produktem** — jest enablerem dla innych produktów i usług
- **Właściciel** — Jarosław Gołąb (Cloud Practice Lead)
- **Sponsor** — Tomasz Polkowski (Head of Cloud)

## Powiązania w vault

- [[cloud-detective]] — pierwszy use case: sanitize scan output przed eksportem do ChatGPT
- [[vault-llm-governance]] — governance który projekt technicznie egzekwuje
- [[DOMAIN_ISOLATION_CONTRACT]] — reguły izolacji domen które system ma enforceować technicznie
- [[LLM_EXPORT_POLICY]] — polityki eksportu jako requirements dla recognizerów
- [[DERIVATIVE_INSIGHT_RULES]] — output systemu może generować derived insights
- [[NOTEBOOKLM_CONTRACT]] — sanitized documents jako source packs dla NotebookLM

## Open questions

1. **Token format** — UUID v4 vs hash(value+salt) vs semantic tag (`[CLIENT_NAME_1]`)? Semantic tagi są czytelniejsze dla LLM, UUID są bardziej anonymizujące.
2. **Recognizer scope v1** — czy infra-specific regex + Presidio wystarczą? Gdzie granica custom recognizerów?
3. **Ollama model selection** — który lokalny model do sanity-check klasyfikacji? (llama3.2, mistral, gemma2)
4. **Audit trail granularity** — per token czy per document? Co jest minimumem dla compliance?
5. **Rehydration access control** — kto może rehydratować? Czy token map jest per-user czy per-project?
6. **Granica MVP/PoC** — czy MVP powinien działać jako CLI (low complexity) czy jako FastAPI service?

## Status projektu

| Pole | Wartość |
|------|---------|
| Faza | PoC planning |
| Właściciel | Jarosław Gołąb |
| Sponsor | Tomasz Polkowski |
| Data inicjacji | 2026-05-07 |
| Repozytorium | TBD — `~/projekty/devops/secure-ai-anonymizer` |
| Roadmap | [[roadmap]] |
| MVP scope | [[mvp-scope]] |
| Architektura | [[architecture]] |
| Zagrożenia | [[threat-model]] |
