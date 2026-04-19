from __future__ import annotations

import logging
from typing import Optional

from playwright.async_api import Page

from .browser import UdemyBrowser
from .models import CaptionTrack, Lecture

logger = logging.getLogger(__name__)


def _pick_track(captions: list[CaptionTrack], language: str) -> Optional[CaptionTrack]:
    lang = language.lower().replace("-", "_")
    # Dokładne dopasowanie języka
    for c in captions:
        if lang in c.language_code.lower():
            return c
    # Fallback do angielskiego
    for c in captions:
        if "en" in c.language_code.lower():
            return c
    # Fallback do pierwszego dostępnego
    return captions[0] if captions else None


async def fetch_raw_vtt(browser: UdemyBrowser, page: Page, track: CaptionTrack) -> str:
    logger.debug("Pobieranie VTT [%s]: %s", track.language_code, track.url)
    try:
        return await browser.fetch_text(page, track.url)
    except Exception as exc:
        logger.warning("Błąd pobierania napisów %s: %s", track.url, exc)
        return ""


async def extract_transcript(
    browser: UdemyBrowser,
    page: Page,
    lecture: Lecture,
    language: str = "en",
) -> Optional[tuple[str, str]]:
    """
    Zwraca (raw_vtt, language_code) lub None jeśli brak napisów.
    """
    if not lecture.captions:
        return None

    track = _pick_track(lecture.captions, language)
    if track is None:
        return None

    raw = await fetch_raw_vtt(browser, page, track)
    if not raw:
        return None

    return raw, track.language_code
