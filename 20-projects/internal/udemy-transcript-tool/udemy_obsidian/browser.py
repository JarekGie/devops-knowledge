from __future__ import annotations

import logging
from pathlib import Path
from typing import Any, Optional

from playwright.async_api import (
    BrowserContext,
    Page,
    async_playwright,
)

logger = logging.getLogger(__name__)

_USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/124.0.0.0 Safari/537.36"
)

# ADAPTER: selektor elementu potwierdzającego zalogowanie
_LOGGED_IN_SELECTOR = '[data-purpose="header-login"], [data-purpose="user-dropdown"]'


class UdemyBrowser:
    def __init__(self, storage_state_path: Path, headless: bool = False) -> None:
        self.storage_state_path = storage_state_path
        self.headless = headless
        self._playwright = None
        self._browser = None
        self._context: Optional[BrowserContext] = None

    async def __aenter__(self) -> "UdemyBrowser":
        self._playwright = await async_playwright().start()
        self._browser = await self._playwright.chromium.launch(headless=self.headless)

        storage_state: Optional[str] = None
        if self.storage_state_path.exists():
            storage_state = str(self.storage_state_path)
            logger.info("Ładowanie zapisanej sesji: %s", storage_state)

        self._context = await self._browser.new_context(
            storage_state=storage_state,
            viewport={"width": 1280, "height": 900},
            user_agent=_USER_AGENT,
        )
        return self

    async def __aexit__(self, *_: Any) -> None:
        if self._context:
            await self._context.close()
        if self._browser:
            await self._browser.close()
        if self._playwright:
            await self._playwright.stop()

    async def new_page(self) -> Page:
        assert self._context is not None
        return await self._context.new_page()

    async def save_state(self) -> None:
        assert self._context is not None
        self.storage_state_path.parent.mkdir(parents=True, exist_ok=True)
        await self._context.storage_state(path=str(self.storage_state_path))
        logger.info("Sesja zapisana: %s", self.storage_state_path)

    async def is_logged_in(self, page: Page) -> bool:
        await page.goto("https://www.udemy.com/", wait_until="domcontentloaded")
        try:
            # ADAPTER: selektor nagłówka po zalogowaniu
            await page.wait_for_selector('[data-purpose="user-dropdown"]', timeout=6000)
            return True
        except Exception:
            return False

    async def fetch_json(self, page: Page, url: str) -> Any:
        """Pobiera JSON przez sesję przeglądarki (ciasteczka dołączane automatycznie)."""
        result = await page.evaluate(
            """async (url) => {
                const r = await fetch(url, {
                    credentials: "include",
                    headers: {
                        "Accept": "application/json, text/plain, */*",
                        "X-Requested-With": "XMLHttpRequest"
                    }
                });
                if (!r.ok) throw new Error("HTTP " + r.status + " " + url);
                return r.json();
            }""",
            url,
        )
        return result

    async def fetch_text(self, page: Page, url: str) -> str:
        """Pobiera tekst (np. VTT) przez sesję przeglądarki."""
        result = await page.evaluate(
            """async (url) => {
                const r = await fetch(url, {credentials: "include"});
                if (!r.ok) throw new Error("HTTP " + r.status + " " + url);
                return r.text();
            }""",
            url,
        )
        return result
