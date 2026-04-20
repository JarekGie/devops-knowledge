from __future__ import annotations

import logging
import re
from typing import Optional

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


async def _get_course_id_from_page(page: Page) -> tuple[int, str]:
    """
    Wyciąga course_id ze strony kursu (DOM / window variables).
    # ADAPTER: Udemy może zmienić strukturę window variables lub atrybutów DOM
    """
    debug = await page.evaluate("""
        () => ({
            hasUD: typeof window.UD !== 'undefined',
            UDkeys: typeof window.UD !== 'undefined' ? Object.keys(window.UD) : [],
            hasInitialState: typeof window.__INITIAL_STATE__ !== 'undefined',
            bodyAttrs: Array.from(document.body.attributes).map(a => a.name + '=' + a.value.slice(0, 40)),
            metaCourseid: (document.querySelector('meta[name="courseid"]') || {}).content || null,
        })
    """)
    logger.debug("Page debug: %s", debug)

    result = await page.evaluate("""
        () => {
            // Metoda 1: window.UD.serverSideProps
            try {
                const c = window.UD.serverSideProps.course;
                if (c && c.id) return {id: c.id, title: c.title || ''};
            } catch(e) {}

            // Metoda 2: window.UD.meReporter lub podobne
            try {
                const id = window.UD.courseId || window.UD.course_id;
                if (id) return {id: parseInt(id), title: ''};
            } catch(e) {}

            // Metoda 3: data-clp-course-id na body lub dowolnym elemencie
            for (const attr of ['data-clp-course-id', 'data-course-id']) {
                const el = document.querySelector('[' + attr + ']');
                if (el) return {id: parseInt(el.getAttribute(attr)), title: document.title};
            }

            // Metoda 4: meta tag
            const meta = document.querySelector('meta[name="courseid"]');
            if (meta && meta.content) return {id: parseInt(meta.content), title: document.title};

            // Metoda 5: szukaj "courseId": w skryptach
            for (const s of document.scripts) {
                const m = s.text.match(/"courseId"\\s*:\\s*(\\d+)/);
                if (m) return {id: parseInt(m[1]), title: ''};
                const m2 = s.text.match(/"course_id"\\s*:\\s*(\\d+)/);
                if (m2) return {id: parseInt(m2[1]), title: ''};
            }

            // Metoda 6: URL /learn/lecture/ — course ID nieznany, ale spróbuj z __INITIAL_STATE__
            try {
                const state = window.__INITIAL_STATE__;
                if (state) {
                    const json = JSON.stringify(state);
                    const m = json.match(/"id":(\\d+),"title"/);
                    if (m) return {id: parseInt(m[1]), title: ''};
                }
            } catch(e) {}

            return null;
        }
    """)

    if result and result.get("id"):
        return int(result["id"]), result.get("title", "")

    raise RuntimeError(
        "Nie można znaleźć course_id na stronie kursu. "
        "Sprawdź logi DEBUG żeby zobaczyć dostępne window variables."
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

    await page.goto(course_url, wait_until="networkidle", timeout=30000)
    actual_url = page.url
    page_title = await page.title()
    logger.debug("Strona po goto: url=%s title=%s", actual_url, page_title)

    course_id, course_title = await _get_course_id_from_page(page)
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
