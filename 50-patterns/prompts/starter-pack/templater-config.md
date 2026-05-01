# 🎯 Cel

Chcę skonfigurować plugin Templater w Obsidian tak, żeby:

- frontmatter był automatycznie wstawiany przy tworzeniu nowego pliku
    
- zmienne typu `<% tp.file.title %>` były automatycznie renderowane
    
- działało to dla folderu `50-patterns/prompts/` i jego subfolderów
    

---

# 📥 Kontekst

Struktura vault:

- templates/frontmatter/prompt.md (template)
    
- 50-patterns/prompts/ (docelowe pliki promptów)
    

Problem:

- template się wstawia jako tekst
    
- zmienne `<% ... %>` NIE są renderowane
    
- np. `title: <% tp.file.title %>` zostaje literalnie
    

---

# ⚙️ Zadanie

Przeprowadź mnie przez debug i konfigurację Templater tak, żeby to działało poprawnie.

---

# 📊 Oczekiwany format odpowiedzi

## 1. Root cause (najbardziej prawdopodobny)

## 2. Checklista debug (krok po kroku)

- konkretne rzeczy do sprawdzenia w settings
    
- gdzie kliknąć
    
- co powinno być ustawione
    

## 3. Poprawna konfiguracja (docelowa)

- dokładne wartości:
    
    - Template folder
        
    - Trigger
        
    - Folder Templates mapping
        

## 4. Test końcowy

- jak sprawdzić, że działa
    

## 5. Typowe błędy

- np. subfoldery, trailing slash, stare pliki
    

---

# 🚫 Guardrails

- zakładaj, że używam Obsidian desktop
    
- nie sugeruj pluginów poza Templater
    
- nie zakładaj dostępu do mojego systemu
    
- dawaj konkretne kroki, nie ogólniki
    

---

# 🧩 Dodatkowy kontekst

Chcę to mieć jako stabilny workflow pod tworzenie promptów dla LLM (Claude / ChatGPT / Codex), więc zależy mi na automatyzacji i powtarzalności.