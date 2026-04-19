from __future__ import annotations

import re

_TIMESTAMP_RE = re.compile(
    r"^\d{1,2}:\d{2}:\d{2}[.,]\d{3}\s*-->\s*\d{1,2}:\d{2}:\d{2}[.,]\d{3}.*$"
)
_CUE_NUMBER_RE = re.compile(r"^\d+$")
_INLINE_TIMESTAMP_RE = re.compile(r"<\d{2}:\d{2}:\d{2}\.\d{3}>")
_HTML_TAG_RE = re.compile(r"<[^>]+>")
_SENTENCE_END_RE = re.compile(r"[.?!…]$")


def normalize_vtt(raw: str) -> str:
    """Konwertuje surowy VTT na czysty tekst z podziałem na akapity."""
    lines = raw.splitlines()
    cleaned: list[str] = []

    for line in lines:
        line = line.strip()
        if not line:
            continue
        if line.startswith("WEBVTT") or line.startswith("NOTE"):
            continue
        if _TIMESTAMP_RE.match(line):
            continue
        if _CUE_NUMBER_RE.match(line):
            continue
        line = _INLINE_TIMESTAMP_RE.sub("", line)
        line = _HTML_TAG_RE.sub("", line).strip()
        if line:
            cleaned.append(line)

    # Usuń sąsiadujące duplikaty (nakładające się okna czasowe w VTT)
    deduped: list[str] = []
    for line in cleaned:
        if not deduped or line != deduped[-1]:
            deduped.append(line)

    # Sklej w akapity: nowy akapit po zdaniu kończącym się znakiem końca
    paragraphs: list[str] = []
    buffer: list[str] = []

    for line in deduped:
        buffer.append(line)
        if _SENTENCE_END_RE.search(line):
            paragraphs.append(" ".join(buffer))
            buffer = []

    if buffer:
        paragraphs.append(" ".join(buffer))

    return "\n\n".join(paragraphs)
