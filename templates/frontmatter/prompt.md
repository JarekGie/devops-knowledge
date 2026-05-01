---
title: <% tp.file.title %>
domain: client-work
use_case:
llm_target: any
aws_profile:
repozytorium:
region: eu-central-1
environment: dev
tags: [prompt]
created: <% tp.date.now("YYYY-MM-DD") %>
updated: <% tp.date.now("YYYY-MM-DD") %>
---

# 🎯 Cel

<uzupełnij>

---

# 📥 Kontekst wejściowy

## Zakres

- konto / profil AWS: <% tp.frontmatter.aws_profile || "<uzupełnij>" %>
- region: <% tp.frontmatter.region || "eu-central-1" %>
- środowisko: <% tp.frontmatter.environment || "<dev/prod>" %>
- repozytorium: <% tp.frontmatter.repozytorium || "<opcjonalnie>" %>

## Dane

<wklej dane wejściowe>

---

# ⚙️ Zadanie dla agenta

1. <krok 1>
2. <krok 2>
3. <krok 3>

---

# 📊 Oczekiwany format odpowiedzi

## Werdykt

## Evidence

## Hipotezy

## Rekomendowane działania

## Ryzyka

---

# 🚫 Guardrails

- nie wykonuj operacji write
- nie zakładaj brakujących danych
- oddziel fakty od hipotez