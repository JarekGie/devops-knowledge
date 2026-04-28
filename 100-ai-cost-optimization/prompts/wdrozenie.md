Zaktualizuj mój vault oraz kontrakty agentów o warstwę **Cost-Aware Agent Execution Policy (AI FinOps lite)**.

Kontekst:  
Mam istniejące kontrakty komunikacyjne dla Claude/Codex, context packs oraz governance w `_system/`. Chcę dodać nową warstwę sterowania kosztami tokenów i routingiem modeli, ale bez naruszania obecnych zasad, workflow ani istniejących kontraktów. Zmiany mają być addytywne, nie destrukcyjne.

Cel:  
Wprowadzić politykę, w której agent działa świadomie kosztowo, dobiera "tier" modelu do klasy zadania, minimalizuje zużycie tokenów i stosuje escalation zamiast premium-by-default.

Utwórz nowy dokument:

`_system/AI_COST_AWARE_AGENT_CONTRACT.md`

Zawartość dokumentu ma obejmować:

## 1. Purpose

Definicja celu:

- optimize token usage
    
- preserve output quality
    
- use premium reasoning only when justified
    
- treat context window as scarce resource
    

## 2. Model Tier Policy

Zdefiniuj 3 poziomy:

Tier S (low-cost/default)

- drafting
    
- markdown
    
- formatting
    
- checklist generation
    
- routine refactoring
    

Tier M (standard reasoning)

- IaC review
    
- RCA synthesis
    
- medium-complexity architecture
    

Tier P (premium reasoning)

- deep architecture
    
- threat modeling
    
- difficult debugging
    
- long-context analysis
    

Dodaj escalation rule:  
small → medium → premium only when justified.

## 3. Cost-Aware Execution Rules

Uwzględnij zasady:

- prefer lowest capable model
    
- avoid premium-by-default
    
- use diffs over full rewrites
    
- concise-by-default responses unless expanded output requested
    
- reuse prior context, avoid re-summarizing stable context
    
- use minimal sufficient context
    

## 4. Confidence / Escalation Policy

Dodaj policy:

- escalate only when ambiguity unresolved
    
- escalate on contradiction or failed validation
    
- avoid model escalation when confidence high
    

## 5. Token Frugality Guidelines

Uwzględnij:

- reduce redundant output
    
- prefer references over reinlining large context
    
- minimize context burn in vault workflows
    
- treat long context as expensive resource
    

## 6. Integration

Przeanalizuj, które istniejące pliki kontraktowe warto lekko rozszerzyć (bez przepisywania ich od nowa), np:

- AGENTS.md
    
- kontrakt komunikacji
    
- context-pack conventions
    

Dodaj tylko minimalne odwołania do nowego kontraktu.

## 7. Deliverables

Przygotuj:

- gotowy plik markdown
    
- propozycję frontmatter (domain, tags, classification)
    
- changelog zmian
    
- krótką notę jak ten kontrakt może później sterować prawdziwym model routerem (np API routing)
    

Ważne constraints:

- Nie zmieniaj istniejącej logiki kontraktów.
    
- Nie usuwaj nic działającego.
    
- Nie rób rewolucji w vault.
    
- Addytywnie dołóż warstwę cost-aware.
    
- Zachowaj styl i strukturę istniejącego vault governance.
    

Na końcu oceń, czy ten kontrakt lepiej sklasyfikować jako governance, LLMOps czy FinOps (lub hybrydę) i uzasadnij.