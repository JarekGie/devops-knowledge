from __future__ import annotations

import asyncio
import json
import logging
import re
from typing import Any, Optional

from playwright.async_api import Page, Response

from .browser import UdemyBrowser
from .config import API_BASE
from .models import CaptionTrack, Course, Lecture, Section

logger = logging.getLogger(__name__)


def extract_slug(course_url: str) -> str:
    match = re.search(r"/course/([^/?#]+)", course_url)
    if not match:
        raise ValueError(f"Nie można wyodrębnić sluga kursu z URL: {course_url}")
    return match.group(1)


async def discover_course(
    browser: UdemyBrowser,
    page: Page,
    course_url: str,
    only_section: Optional[int] = None,
    only_lecture: Optional[int] = None,
) -> Course:
    slug = extract_slug(course_url)
    logger.info("Odkrywanie kursu: %s", slug)

    # Przechwyć course_id i curriculum bezpośrednio z ruchu sieciowego
    # Udemy's własny JS robi te API calls — nie musimy ich powielać
    # # ADAPTER: wzorce URL API mogą się zmienić
    course_id_holder: list[int] = []
    curriculum_holder: list[dict] = []

    async def on_response(response: Response) -> None:
        url = response.url

        # Wyciągnij course_id z dowolnego API call
        if not course_id_holder:
            m = re.search(r"/api-2\.0/courses/(\d+)/", url)
            if m:
                course_id_holder.append(int(m.group(1)))
                logger.debug("course_id z network: %s", course_id_holder[0])

        # Przechwyć curriculum
        if not curriculum_holder and "subscriber-curriculum-items" in url:
            try:
                body = await response.body()
                data = json.loads(body)
                if data.get("results"):
                    curriculum_holder.append(data)
                    logger.debug("Curriculum przechwycony: %d items", len(data["results"]))
            except Exception as exc:
                logger.debug("Błąd parsowania curriculum response: %s", exc)

    page.on("response", on_response)
    try:
        await page.goto(course_url, wait_until="networkidle", timeout=60000)
    finally:
        page.remove_listener("response", on_response)

    if not course_id_holder:
        raise RuntimeError(
            "Nie można znaleźć course_id w ruchu sieciowym. "
            "Upewnij się, że jesteś zalogowany i masz dostęp do kursu."
        )

    course_id = course_id_holder[0]
    logger.info("Kurs: %s (id=%s)", slug, course_id)

    # Jeśli curriculum nie został przechwycony (strona była z cache),
    # nawiguj do pierwszego wykładu żeby wymusić API call
    if not curriculum_holder:
        logger.info("Curriculum nie przechwycony — wymuszam reload strony kursu")
        page.on("response", on_response)
        try:
            base_url = re.sub(r"/learn/.*", "", course_url)
            await page.goto(base_url, wait_until="networkidle", timeout=60000)
        finally:
            page.remove_listener("response", on_response)

    if not curriculum_holder:
        raise RuntimeError(
            f"Nie udało się przechwycić listy wykładów dla kursu {course_id}. "
            "Spróbuj otworzyć kurs w przeglądarce i uruchomić eksport ponownie."
        )

    curriculum = curriculum_holder[0]

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
        title=slug,
        slug=slug,
        url=course_url,
        sections=sections,
    )
