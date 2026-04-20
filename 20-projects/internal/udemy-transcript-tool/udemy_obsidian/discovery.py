from __future__ import annotations

import logging
import re
from typing import Any, Optional

from playwright.async_api import Page

from .browser import UdemyBrowser
from .config import API_BASE
from .models import CaptionTrack, Course, Lecture, Section

logger = logging.getLogger(__name__)

# ADAPTER: parametry pól API — jeśli Udemy zmieni schemat, edytuj tutaj
_CURRICULUM_FIELDS = (
    "?page_size=1400"
    "&fields[lecture]=id,title,asset"
    "&fields[asset]=captions"
    "&fields[chapter]=id,title,sort_order"
)


def extract_slug(course_url: str) -> str:
    match = re.search(r"/course/([^/?#]+)", course_url)
    if not match:
        raise ValueError(f"Nie można wyodrębnić sluga kursu z URL: {course_url}")
    return match.group(1)


async def _get_course_id_from_network(page: Page, course_url: str) -> tuple[int, str]:
    """
    Przechwytuje network requests podczas ładowania strony kursu.
    Udemy's JS robi API calls z course ID w URL — wyciągamy go stamtąd.
    # ADAPTER: wzorzec URL API może się zmienić
    """
    course_info: dict = {"id": None, "title": ""}

    def on_response(response: Any) -> None:
        url = response.url
        m = re.search(r"/api-2\.0/courses/(\d+)/", url)
        if m and course_info["id"] is None:
            course_info["id"] = int(m.group(1))
            logger.debug("course_id z network: %s (url=%s)", course_info["id"], url)

    page.on("response", on_response)
    try:
        await page.goto(course_url, wait_until="networkidle", timeout=30000)
    finally:
        page.remove_listener("response", on_response)

    if course_info["id"]:
        return course_info["id"], course_info["title"]

    raise RuntimeError(
        "Nie można znaleźć course_id w ruchu sieciowym. "
        "Upewnij się, że jesteś zalogowany i masz dostęp do kursu."
    )


async def discover_course(
    browser: UdemyBrowser,
    page: Page,
    course_url: str,
    only_section: Optional[int] = None,
    only_lecture: Optional[int] = None,
) -> Course:
    slug = extract_slug(course_url)
    logger.info("Odkrywanie kursu: %s", slug)

    course_id, course_title = await _get_course_id_from_network(page, course_url)
    if not course_title:
        course_title = slug
    logger.info("Kurs: %s (id=%s)", course_title, course_id)

    curriculum_url = f"{API_BASE}/courses/{course_id}/subscriber-curriculum-items/{_CURRICULUM_FIELDS}"
    curriculum = await browser.fetch_json(page, curriculum_url)

    sections: list[Section] = []
    current_section: Optional[Section] = None
    section_idx = 0
    global_lecture_idx = 0

    for item in curriculum.get("results", []):
        cls = item.get("_class")

        if cls == "chapter":
            section_idx += 1
            current_section = Section(
                id=item["id"],
                index=section_idx,
                title=item["title"],
                lectures=[],
            )
            sections.append(current_section)

        elif cls == "lecture" and current_section is not None:
            global_lecture_idx += 1
            lecture_idx_in_section = len(current_section.lectures) + 1

            asset = item.get("asset") or {}
            # ADAPTER: struktura captions w odpowiedzi API
            captions = [
                CaptionTrack(
                    language_code=c.get("locale_id", ""),
                    url=c["url"],
                    file_name=c.get("file_name", ""),
                )
                for c in asset.get("captions", [])
                if c.get("url")
            ]

            lecture = Lecture(
                id=item["id"],
                title=item["title"],
                section_title=current_section.title,
                section_index=current_section.index,
                lecture_index=lecture_idx_in_section,
                global_index=global_lecture_idx,
                url=f"https://www.udemy.com/course/{slug}/learn/lecture/{item['id']}",
                captions=captions,
                has_transcript=bool(captions),
            )
            current_section.lectures.append(lecture)

    # Filtrowanie gdy użytkownik chce tylko jedną sekcję lub wykład
    if only_section is not None:
        sections = [s for s in sections if s.index == only_section]
    if only_lecture is not None:
        for s in sections:
            s.lectures = [l for l in s.lectures if l.global_index == only_lecture]
        sections = [s for s in sections if s.lectures]

    total_lectures = sum(len(s.lectures) for s in sections)
    logger.info("Znaleziono %d sekcji, %d wykładów", len(sections), total_lectures)

    return Course(
        id=course_id,
        title=course_title,
        slug=slug,
        url=course_url,
        sections=sections,
    )
