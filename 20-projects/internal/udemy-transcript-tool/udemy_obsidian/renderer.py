from __future__ import annotations

import re
import unicodedata
from typing import Optional

from .models import Course, Lecture, Section


def slugify(text: str) -> str:
    text = unicodedata.normalize("NFKD", text)
    text = text.encode("ascii", "ignore").decode("ascii")
    text = text.lower()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"[\s_]+", "-", text)
    return text.strip("-")[:80]


def render_lecture(
    lecture: Lecture,
    course: Course,
    transcript: Optional[str],
    exported_at: str,
    language: str,
) -> str:
    tags = [
        "courses",
        "udemy",
        slugify(course.title),
        slugify(lecture.section_title),
    ]
    tags_yaml = "\n".join(f"  - {t}" for t in tags)
    has_transcript = transcript is not None

    frontmatter = (
        f"---\n"
        f"type: course-lecture\n"
        f"source: udemy\n"
        f'course: "{course.title}"\n'
        f'section: "{lecture.section_title}"\n'
        f'lecture: "{lecture.title}"\n'
        f"lecture_index: {lecture.lecture_index}\n"
        f"section_index: {lecture.section_index}\n"
        f'url: "{lecture.url}"\n'
        f'exported_at: "{exported_at}"\n'
        f'language: "{language}"\n'
        f"has_transcript: {str(has_transcript).lower()}\n"
        f"tags:\n{tags_yaml}\n"
        f"---"
    )

    transcript_body = transcript if transcript else "*Brak transkryptu dla tego wykładu.*"

    return f"{frontmatter}\n\n# {lecture.title}\n\n## Transkrypt\n\n{transcript_body}\n\n## Notatki\n\n"


def render_section(section: Section, course: Course) -> str:
    links = "\n".join(
        f"- [[{lecture.global_index:03d}-{slugify(lecture.title)}|{lecture.title}]]"
        for lecture in section.lectures
    )
    return (
        f"# {section.title}\n\n"
        f"**Kurs:** {course.title}  \n"
        f"**Sekcja:** {section.index}\n\n"
        f"## Wykłady\n\n{links}\n"
    )


def render_course(course: Course, stats: dict[str, int]) -> str:
    section_links = "\n".join(
        f"- [[{s.index:02d}-{slugify(s.title)}/_section|{s.title}]]"
        for s in course.sections
    )
    exported = stats.get("exported", 0)
    total = stats.get("total", 0)
    no_transcript = stats.get("no_transcript", 0)
    errors = stats.get("errors", 0)

    return (
        f"# {course.title}\n\n"
        f"**Źródło:** {course.url}  \n"
        f"**Eksport:** {exported}/{total} wykładów  \n"
        f"**Bez transkryptu:** {no_transcript}  \n"
        f"**Błędy:** {errors}\n\n"
        f"## Sekcje\n\n{section_links}\n"
    )
