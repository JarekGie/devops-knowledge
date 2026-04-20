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
        # channel="chrome" używa zainstalowanego Google Chrome zamiast Chromium
        # — omija Cloudflare bot detection
        self._browser = await self._playwright.chromium.launch(
            headless=self.headless,
            channel="chrome",
        )

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
        # Daj użytkownikowi czas na rozwiązanie Cloudflare captcha jeśli się pojawi
        try:
            await page.wait_for_selector('[data-purpose="user-dropdown"]', timeout=60000)
            await self.save_state()
            return True
        except Exception:
            return False

    async def fetch_json(self, page: Page, url: str) -> Any:
        """Pobiera JSON przez page.request (cookies z kontekstu dołączane automatycznie)."""
        assert self._context is not None
        cookies = await self._context.cookies("https://www.udemy.com")
        access_token = next((c["value"] for c in cookies if c["name"] == "access_token"), None)
        csrf_token = next((c["value"] for c in cookies if c["name"] == "csrftoken"), None)

        headers: dict[str, str] = {
            "Accept": "application/json, text/plain, */*",
            "X-Requested-With": "XMLHttpRequest",
            "Referer": "https://www.udemy.com/",
        }
        if access_token:
            headers["Authorization"] = f"Bearer {access_token}"
        if csrf_token:
            headers["X-Csrftoken"] = csrf_token

        logger.debug("fetch_json cookies: access_token=%s csrf=%s", bool(access_token), bool(csrf_token))

        response = await self._context.request.get(url, headers=headers)
        if not response.ok:
            raise RuntimeError(f"HTTP {response.status} {url}")
        return await response.json()

    async def fetch_text(self, page: Page, url: str) -> str:
        """Pobiera tekst (np. VTT) przez page.request."""
        assert self._context is not None
        response = await self._context.request.get(url)
        if not response.ok:
            raise RuntimeError(f"HTTP {response.status} {url}")
        return await response.text()
