from __future__ import annotations

import logging
from pathlib import Path

from .models import Course, Lecture, Section
from .renderer import slugify, render_course, render_lecture, render_section

logger = logging.getLogger(__name__)


def section_dir(root: Path, section: Section) -> Path:
    return root / f"{section.index:02d}-{slugify(section.title)}"


def lecture_path(root: Path, section: Section, lecture: Lecture) -> Path:
    return section_dir(root, section) / f"{lecture.global_index:03d}-{slugify(lecture.title)}.md"


def raw_vtt_path(root: Path, section: Section, lecture: Lecture) -> Path:
    return section_dir(root, section) / "raw" / f"{lecture.global_index:03d}-{slugify(lecture.title)}.vtt"


def write_lecture(
    root: Path,
    course: Course,
    section: Section,
    lecture: Lecture,
    transcript: str | None,
    exported_at: str,
    language: str,
    raw_vtt: str | None = None,
    save_raw: bool = False,
    dry_run: bool = False,
) -> Path:
    path = lecture_path(root, section, lecture)
    content = render_lecture(lecture, course, transcript, exported_at, language)

    if not dry_run:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        logger.debug("Zapisano: %s", path)

        if save_raw and raw_vtt:
            rp = raw_vtt_path(root, section, lecture)
            rp.parent.mkdir(parents=True, exist_ok=True)
            rp.write_text(raw_vtt, encoding="utf-8")
    else:
        logger.info("[dry-run] Pominięto zapis: %s", path)

    return path


def write_section(
    root: Path,
    course: Course,
    section: Section,
    dry_run: bool = False,
) -> Path:
    path = section_dir(root, section) / "_section.md"
    content = render_section(section, course)

    if not dry_run:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        logger.debug("Zapisano sekcję: %s", path)
    else:
        logger.info("[dry-run] Pominięto zapis sekcji: %s", path)

    return path


def write_course(
    root: Path,
    course: Course,
    stats: dict[str, int],
    dry_run: bool = False,
) -> Path:
    course_root = root / slugify(course.slug)
    path = course_root / "_course.md"
    content = render_course(course, stats)

    if not dry_run:
        course_root.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        logger.debug("Zapisano kurs: %s", path)
    else:
        logger.info("[dry-run] Pominięto zapis kursu: %s", path)

    return path
