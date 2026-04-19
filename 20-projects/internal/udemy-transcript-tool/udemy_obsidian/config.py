from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

UDEMY_BASE = "https://www.udemy.com"
API_BASE = f"{UDEMY_BASE}/api-2.0"

DEFAULT_STORAGE_STATE = Path(".state/udemy-storage-state.json")
DEFAULT_OUTPUT_SUBDIR = "20-projects/internal/aws-cloudops-exam/udemy"


@dataclass
class Config:
    vault: Path
    output_subdir: str = DEFAULT_OUTPUT_SUBDIR
    language: str = "en"
    headless: bool = False
    reuse_session: bool = True
    force: bool = False
    dry_run: bool = False
    verbose: bool = False
    save_raw: bool = False
    storage_state: Path = field(default_factory=lambda: DEFAULT_STORAGE_STATE)
    only_section: Optional[int] = None
    only_lecture: Optional[int] = None

    @property
    def output_root(self) -> Path:
        return self.vault / self.output_subdir
