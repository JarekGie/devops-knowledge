from __future__ import annotations

import hashlib
import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from .models import Manifest, ManifestLecture

logger = logging.getLogger(__name__)


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def load(path: Path) -> Optional[Manifest]:
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        lectures = {
            k: ManifestLecture(**v)
            for k, v in data.get("lectures", {}).items()
        }
        return Manifest(
            course_id=data["course_id"],
            course_title=data["course_title"],
            course_url=data["course_url"],
            last_run=data["last_run"],
            lectures=lectures,
        )
    except Exception as exc:
        logger.warning("Błąd wczytywania manifestu %s: %s", path, exc)
        return None


def save(manifest: Manifest, path: Path, dry_run: bool = False) -> None:
    data = {
        "course_id": manifest.course_id,
        "course_title": manifest.course_title,
        "course_url": manifest.course_url,
        "last_run": manifest.last_run,
        "lectures": {
            k: {
                "lecture_id": v.lecture_id,
                "title": v.title,
                "status": v.status,
                "file_path": v.file_path,
                "content_hash": v.content_hash,
                "exported_at": v.exported_at,
                "error": v.error,
            }
            for k, v in manifest.lectures.items()
        },
    }
    if not dry_run:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
        logger.debug("Manifest zapisany: %s", path)


def content_hash(text: str) -> str:
    return hashlib.sha256(text.encode()).hexdigest()[:16]


def is_already_exported(manifest: Optional[Manifest], lecture_id: int, current_hash: Optional[str]) -> bool:
    if manifest is None:
        return False
    entry = manifest.lectures.get(str(lecture_id))
    if entry is None:
        return False
    if entry.status != "exported":
        return False
    if current_hash and entry.content_hash != current_hash:
        return False
    return True


def record_exported(
    manifest: Manifest,
    lecture_id: int,
    title: str,
    file_path: str,
    text_hash: str,
) -> None:
    manifest.lectures[str(lecture_id)] = ManifestLecture(
        lecture_id=lecture_id,
        title=title,
        status="exported",
        file_path=file_path,
        content_hash=text_hash,
        exported_at=_now_iso(),
    )


def record_no_transcript(manifest: Manifest, lecture_id: int, title: str) -> None:
    manifest.lectures[str(lecture_id)] = ManifestLecture(
        lecture_id=lecture_id,
        title=title,
        status="no_transcript",
        file_path=None,
        content_hash=None,
        exported_at=_now_iso(),
    )


def record_error(manifest: Manifest, lecture_id: int, title: str, error: str) -> None:
    manifest.lectures[str(lecture_id)] = ManifestLecture(
        lecture_id=lecture_id,
        title=title,
        status="error",
        file_path=None,
        content_hash=None,
        exported_at=_now_iso(),
        error=error,
    )


def new_manifest(course_id: int, course_title: str, course_url: str) -> Manifest:
    return Manifest(
        course_id=course_id,
        course_title=course_title,
        course_url=course_url,
        last_run=_now_iso(),
    )
