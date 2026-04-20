from __future__ import annotations

import asyncio
import logging
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

import click

from .browser import UdemyBrowser
from .config import Config, DEFAULT_OUTPUT_SUBDIR, DEFAULT_STORAGE_STATE
from .discovery import discover_course
from .extraction import extract_transcript
from . import manifest as mf
from .normalization import normalize_vtt
from .renderer import slugify
from .writer import lecture_path, section_dir, write_course, write_lecture, write_section

logger = logging.getLogger("udemy_obsidian")


def _setup_logging(verbose: bool) -> None:
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s  %(levelname)-8s  %(message)s",
        datefmt="%H:%M:%S",
        stream=sys.stderr,
    )


@click.group()
def cli() -> None:
    """Eksporter transkryptów Udemy → Obsidian vault."""


# ---------------------------------------------------------------------------
# import-cookies
# ---------------------------------------------------------------------------

@cli.command("import-cookies")
@click.option(
    "--storage-state",
    default=str(DEFAULT_STORAGE_STATE),
    show_default=True,
)
@click.option("--verbose", is_flag=True)
def import_cookies(storage_state: str, verbose: bool) -> None:
    """Importuje ciasteczka Udemy z zainstalowanego Chrome (bez logowania)."""
    import json
    import browser_cookie3

    _setup_logging(verbose)
    state_path = Path(storage_state)

    click.echo("Czytam ciasteczka Udemy z Chrome…")
    try:
        jar = browser_cookie3.chrome(domain_name="udemy.com")
    except Exception as exc:
        click.echo(f"BŁĄD: nie można odczytać ciasteczek Chrome: {exc}", err=True)
        sys.exit(1)

    cookies = []
    for c in jar:
        cookies.append({
            "name": c.name,
            "value": c.value,
            "domain": c.domain if c.domain.startswith(".") else f".{c.domain}",
            "path": c.path or "/",
            "expires": int(c.expires) if c.expires else -1,
            "httpOnly": bool(getattr(c, "_rest", {}).get("HttpOnly", False)),
            "secure": bool(c.secure),
            "sameSite": "None",
        })

    if not cookies:
        click.echo("BŁĄD: nie znaleziono ciasteczek Udemy. Upewnij się, że jesteś zalogowany w Chrome.", err=True)
        sys.exit(1)

    state = {"cookies": cookies, "origins": []}
    state_path.parent.mkdir(parents=True, exist_ok=True)
    state_path.write_text(json.dumps(state, indent=2, ensure_ascii=False))
    click.echo(f"Zapisano {len(cookies)} ciasteczek → {state_path}")


# ---------------------------------------------------------------------------
# login
# ---------------------------------------------------------------------------

@cli.command()
@click.option(
    "--storage-state",
    default=str(DEFAULT_STORAGE_STATE),
    show_default=True,
    help="Ścieżka do pliku z zapisaną sesją przeglądarki.",
)
@click.option("--verbose", is_flag=True)
def login(storage_state: str, verbose: bool) -> None:
    """Otwiera przeglądarkę do ręcznego zalogowania i zapisuje sesję."""
    _setup_logging(verbose)
    asyncio.run(_login(Path(storage_state)))


async def _login(storage_state_path: Path) -> None:
    click.echo("Otwieranie przeglądarki — zaloguj się do Udemy.")
    async with UdemyBrowser(storage_state_path, headless=False) as browser:
        page = await browser.new_page()
        await page.goto("https://www.udemy.com/join/login-popup/")
        await asyncio.get_event_loop().run_in_executor(
            None, input, "\nNaciśnij Enter po zakończeniu logowania…\n"
        )
        await browser.save_state()
    click.echo(f"Sesja zapisana: {storage_state_path}")


# ---------------------------------------------------------------------------
# export
# ---------------------------------------------------------------------------

@cli.command()
@click.option("--course-url", required=True, help="URL kursu Udemy.")
@click.option("--vault", required=True, type=click.Path(), help="Ścieżka do vault Obsidian.")
@click.option("--output-subdir", default=DEFAULT_OUTPUT_SUBDIR, show_default=True)
@click.option("--language", default="en", show_default=True, help="Preferowany język napisów.")
@click.option("--headless/--no-headless", default=False, show_default=True)
@click.option("--reuse-session/--no-reuse-session", default=True, show_default=True)
@click.option("--storage-state", default=str(DEFAULT_STORAGE_STATE), show_default=True)
@click.option("--force", is_flag=True, help="Nadpisz już wyeksportowane wykłady.")
@click.option("--dry-run", is_flag=True, help="Symulacja — nie zapisuje plików.")
@click.option("--save-raw", is_flag=True, help="Zapisz surowe pliki VTT w podkatalogu raw/.")
@click.option("--only-section", type=int, default=None, help="Eksportuj tylko wskazaną sekcję (numer).")
@click.option("--only-lecture", type=int, default=None, help="Eksportuj tylko wskazany wykład (numer globalny).")
@click.option("--verbose", is_flag=True)
def export(
    course_url: str,
    vault: str,
    output_subdir: str,
    language: str,
    headless: bool,
    reuse_session: bool,
    storage_state: str,
    force: bool,
    dry_run: bool,
    save_raw: bool,
    only_section: Optional[int],
    only_lecture: Optional[int],
    verbose: bool,
) -> None:
    """Eksportuje transkrypty kursu Udemy do vault Obsidian."""
    _setup_logging(verbose)

    config = Config(
        vault=Path(vault).expanduser().resolve(),
        output_subdir=output_subdir,
        language=language,
        headless=headless,
        reuse_session=reuse_session,
        force=force,
        dry_run=dry_run,
        save_raw=save_raw,
        storage_state=Path(storage_state),
        only_section=only_section,
        only_lecture=only_lecture,
        verbose=verbose,
    )

    asyncio.run(_export(course_url, config))


async def _export(course_url: str, config: Config) -> None:
    storage_path = config.storage_state if config.reuse_session else Path("/dev/null")

    async with UdemyBrowser(storage_path, headless=config.headless) as browser:
        page = await browser.new_page()

        if not await browser.is_logged_in(page):
            click.echo(
                "BŁĄD: Nie jesteś zalogowany. Uruchom najpierw:\n"
                f"  python -m udemy_obsidian login --storage-state {config.storage_state}",
                err=True,
            )
            sys.exit(1)

        course = await discover_course(
            browser, page, course_url,
            only_section=config.only_section,
            only_lecture=config.only_lecture,
        )

        course_root = config.output_root / slugify(course.slug)
        manifest_path = course_root / "_manifest.json"

        existing_manifest = mf.load(manifest_path)
        manifest = existing_manifest or mf.new_manifest(course.id, course.title, course_url)
        manifest.last_run = datetime.now(timezone.utc).isoformat()

        stats: dict[str, int] = {"total": 0, "exported": 0, "no_transcript": 0, "skipped": 0, "errors": 0}

        for section in course.sections:
            for lecture in section.lectures:
                stats["total"] += 1
                exported_at = datetime.now(timezone.utc).isoformat()

                try:
                    result = await extract_transcript(browser, page, lecture, config.language)

                    if result is None:
                        logger.info("[%03d] %-50s  → brak napisów", lecture.global_index, lecture.title[:50])
                        mf.record_no_transcript(manifest, lecture.id, lecture.title)
                        stats["no_transcript"] += 1

                        write_lecture(
                            course_root, course, section, lecture,
                            transcript=None,
                            exported_at=exported_at,
                            language=config.language,
                            dry_run=config.dry_run,
                        )
                        continue

                    raw_vtt, lang_code = result
                    clean_text = normalize_vtt(raw_vtt)
                    text_hash = mf.content_hash(clean_text)

                    if not config.force and mf.is_already_exported(existing_manifest, lecture.id, text_hash):
                        logger.info("[%03d] %-50s  → pominięto (bez zmian)", lecture.global_index, lecture.title[:50])
                        stats["skipped"] += 1
                        continue

                    lpath = write_lecture(
                        course_root, course, section, lecture,
                        transcript=clean_text,
                        exported_at=exported_at,
                        language=lang_code,
                        raw_vtt=raw_vtt if config.save_raw else None,
                        save_raw=config.save_raw,
                        dry_run=config.dry_run,
                    )

                    mf.record_exported(manifest, lecture.id, lecture.title, str(lpath), text_hash)
                    stats["exported"] += 1
                    logger.info("[%03d] %-50s  ✓", lecture.global_index, lecture.title[:50])

                except Exception as exc:
                    logger.error("[%03d] %-50s  BŁĄD: %s", lecture.global_index, lecture.title[:50], exc)
                    mf.record_error(manifest, lecture.id, lecture.title, str(exc))
                    stats["errors"] += 1

            write_section(course_root, course, section, dry_run=config.dry_run)

        write_course(config.output_root, course, stats, dry_run=config.dry_run)
        mf.save(manifest, manifest_path, dry_run=config.dry_run)

        click.echo(
            f"\nGotowe: {stats['exported']} wyeksportowanych, "
            f"{stats['skipped']} pominiętych, "
            f"{stats['no_transcript']} bez transkryptu, "
            f"{stats['errors']} błędów"
        )
        if config.dry_run:
            click.echo("(dry-run — żadne pliki nie zostały zapisane)")
