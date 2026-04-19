from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional


@dataclass
class CaptionTrack:
    language_code: str
    url: str
    file_name: str


@dataclass
class Lecture:
    id: int
    title: str
    section_title: str
    section_index: int
    lecture_index: int    # within section
    global_index: int     # across entire course
    url: str
    captions: list[CaptionTrack] = field(default_factory=list)
    has_transcript: bool = False


@dataclass
class Section:
    id: int
    index: int
    title: str
    lectures: list[Lecture] = field(default_factory=list)


@dataclass
class Course:
    id: int
    title: str
    slug: str
    url: str
    sections: list[Section] = field(default_factory=list)


@dataclass
class ManifestLecture:
    lecture_id: int
    title: str
    status: str           # exported | no_transcript | error | skipped
    file_path: Optional[str]
    content_hash: Optional[str]
    exported_at: Optional[str]
    error: Optional[str] = None


@dataclass
class Manifest:
    course_id: int
    course_title: str
    course_url: str
    last_run: str
    lectures: dict[str, ManifestLecture] = field(default_factory=dict)  # key = str(lecture_id)
