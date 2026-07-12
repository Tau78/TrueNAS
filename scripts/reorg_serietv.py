#!/usr/bin/env python3
"""
Reorganize SerieTV library on TrueNAS.
Run: ssh -o BatchMode=yes root@truenas.local 'python3 /mnt/Share/Downloads/scripts/reorg_serietv.py'
Optional: DRY_RUN=true python3 ...
"""

from __future__ import annotations

import logging
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path("/mnt/Share/SerieTV")
LOG_PATH = Path("/mnt/Share/Downloads/scripts/reorg_serietv.log")
DRY_RUN = os.environ.get("DRY_RUN", "false").lower() in ("1", "true", "yes")

SKIP_SHOWS = frozenset(
    {
        "Tom and Jerry",
        "Melrose Place 2009",
        "La Signora in Giallo (1997)",
    }
)

ORPHAN_SEASONS = ("Season 07", "Season 10")
LA_SIGNORA = "La Signora in Giallo (1997)"

MELROSE_1992_SHOW = "Melrose Place (1992)"
MELROSE_SOURCE_RE = re.compile(
    r"Melrose\s+Place\s+1992.*Season\s*(\d+)",
    re.IGNORECASE,
)
MELROSE_SEASON_MAP = {2: "02", 3: "03", 4: "04", 5: "05", 7: "07"}

VIDEO_EXT = {
    ".mkv",
    ".mp4",
    ".avi",
    ".m4v",
    ".wmv",
    ".mov",
    ".ts",
    ".mpeg",
    ".mpg",
    ".webm",
}

SEASON_DIR_RE = re.compile(r"^Season\s*(\d+)\s*$", re.IGNORECASE)
SEASON_IN_FILENAME = re.compile(
    r"(?i)(?:S(\d{1,2})E(\d{1,2})|(\d{1,2})x(\d{1,2}))"
)
SINGLE_SEASON_IN_NAME = re.compile(
    r"(?i)(?:\bS0?1\b|Stagione\s*1\b|Season\s*1(?!\d)\b)"
)

log = logging.getLogger("reorg_serietv")


def setup_logging() -> None:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    handlers: list[logging.Handler] = [
        logging.FileHandler(LOG_PATH, encoding="utf-8"),
        logging.StreamHandler(sys.stdout),
    ]
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=handlers,
    )
    log.info("=== reorg_serietv start (DRY_RUN=%s) ===", DRY_RUN)
    log.info("ROOT=%s", ROOT)


def is_video(path: Path) -> bool:
    return path.is_file() and path.suffix.lower() in VIDEO_EXT


def season_folder_name(num: int) -> str:
    return f"Season {num:02d}"


def extract_season_from_filename(name: str) -> int | None:
    m = SEASON_IN_FILENAME.search(name)
    if not m:
        return None
    for g in m.groups():
        if g is not None:
            return int(g)
    return None


def run_chmod_755() -> None:
    log.info("Applying chmod -R 755 under %s", ROOT)
    if DRY_RUN:
        log.info("[DRY_RUN] would run: chmod -R 755 %s", ROOT)
        return
    subprocess.run(
        ["chmod", "-R", "755", str(ROOT)],
        check=False,
    )


def safe_move(src: Path, dst: Path, skip_duplicate: bool = True) -> bool:
    if not src.exists():
        log.warning("Source missing, skip: %s", src)
        return False
    if dst.exists() and skip_duplicate:
        log.warning("Duplicate basename, skip: %s (dest exists)", dst.name)
        return False
    log.info("MOVE %s -> %s", src, dst)
    if DRY_RUN:
        return True
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(src), str(dst))
    return True


def safe_rename(src: Path, dst: Path) -> bool:
    if not src.exists():
        log.warning("Rename source missing: %s", src)
        return False
    if dst.exists():
        log.warning("Rename target exists, skip: %s", dst)
        return False
    log.info("RENAME %s -> %s", src, dst)
    if DRY_RUN:
        return True
    shutil.move(str(src), str(dst))
    return True


def remove_empty_dir(path: Path) -> None:
    if not path.is_dir():
        return
    try:
        if any(path.iterdir()):
            return
    except OSError:
        return
    log.info("RMDIR empty %s", path)
    if not DRY_RUN:
        path.rmdir()


def merge_orphan_seasons() -> None:
    """A) Move root Season 07/10 into La Signora in Giallo (1997)."""
    target_show = ROOT / LA_SIGNORA
    if not target_show.is_dir():
        log.error("Target show missing for orphan merge: %s", target_show)
        return
    for season_name in ORPHAN_SEASONS:
        orphan = ROOT / season_name
        if not orphan.is_dir():
            log.info("No orphan folder: %s", orphan)
            continue
        dest_season = target_show / season_name
        if not DRY_RUN:
            dest_season.mkdir(parents=True, exist_ok=True)
        for item in sorted(orphan.iterdir()):
            if item.is_file():
                safe_move(item, dest_season / item.name)
            elif item.is_dir():
                for f in sorted(item.rglob("*")):
                    if f.is_file():
                        safe_move(f, dest_season / f.name)
        remove_empty_dir(orphan)


def melrose_1992_consolidation() -> None:
    """B) Consolidate Melrose Place 1992 loose season packs."""
    show_dir = ROOT / MELROSE_1992_SHOW
    if not show_dir.exists() and not DRY_RUN:
        show_dir.mkdir(parents=True, exist_ok=True)
    elif DRY_RUN:
        log.info("[DRY_RUN] would ensure %s exists", show_dir)

    for entry in sorted(ROOT.iterdir()):
        if not entry.is_dir():
            continue
        if entry.name == MELROSE_1992_SHOW:
            continue
        m = MELROSE_SOURCE_RE.search(entry.name)
        if not m:
            continue
        season_num = int(m.group(1))
        suffix = MELROSE_SEASON_MAP.get(season_num)
        if not suffix:
            log.info("Melrose folder skipped (unmapped season %s): %s", season_num, entry.name)
            continue
        dest = show_dir / f"Season {suffix}"
        if not DRY_RUN:
            dest.mkdir(parents=True, exist_ok=True)
        for item in sorted(entry.rglob("*")):
            if item.is_file():
                safe_move(item, dest / item.name)
            elif item.is_dir() and item != entry:
                for f in sorted(item.rglob("*")):
                    if f.is_file():
                        safe_move(f, dest / f.name)
        remove_empty_dir(entry)


def has_season_subdirs(folder: Path) -> bool:
    for child in folder.iterdir():
        if child.is_dir() and SEASON_DIR_RE.match(child.name):
            return True
    return False


def flat_videos_at_depth_one(folder: Path) -> list[Path]:
    return [p for p in folder.iterdir() if is_video(p)]


def maybe_prefix_show_name(show_name: str, filename: str) -> str:
    """Prefix filename with show name if it does not already contain it."""
    norm_show = re.sub(r"[^\w]+", "", show_name, flags=re.UNICODE).lower()
    norm_file = re.sub(r"[^\w]+", "", Path(filename).stem, flags=re.UNICODE).lower()
    if norm_show and norm_show in norm_file:
        return filename
    return f"{show_name} - {filename}"


def organize_flat_by_filename_season(folder: Path, show_name: str) -> None:
    """C) Flat videos with SxxExx / NxNN -> Season XX subfolders."""
    videos = flat_videos_at_depth_one(folder)
    if not videos:
        return
    by_season: dict[int, list[Path]] = {}
    for v in videos:
        sn = extract_season_from_filename(v.name)
        if sn is None:
            continue
        by_season.setdefault(sn, []).append(v)
    if not by_season:
        return
    for season_num, files in sorted(by_season.items()):
        dest_dir = folder / season_folder_name(season_num)
        if not DRY_RUN:
            dest_dir.mkdir(parents=True, exist_ok=True)
        for f in files:
            new_name = maybe_prefix_show_name(show_name, f.name)
            safe_move(f, dest_dir / new_name)


def organize_single_season_flat(folder: Path) -> None:
    """D) Folder name implies season 1 -> Season 01/."""
    if not SINGLE_SEASON_IN_NAME.search(folder.name):
        return
    videos = flat_videos_at_depth_one(folder)
    if not videos:
        return
    dest_dir = folder / season_folder_name(1)
    if not DRY_RUN:
        dest_dir.mkdir(parents=True, exist_ok=True)
    for f in videos:
        safe_move(f, dest_dir / f.name)


def special_renames() -> None:
    """E) One-off show folder fixes."""
    simpsons_old = ROOT / "Simpsons - Season One"
    simpsons_new = ROOT / "The Simpsons"
    if simpsons_old.is_dir():
        if simpsons_new.is_dir():
            dest = simpsons_new / season_folder_name(1)
            if not DRY_RUN:
                dest.mkdir(parents=True, exist_ok=True)
            for f in flat_videos_at_depth_one(simpsons_old):
                safe_move(f, dest / f.name)
            remove_empty_dir(simpsons_old)
        else:
            safe_rename(simpsons_old, simpsons_new)
            src_for_files = simpsons_new if simpsons_new.is_dir() else simpsons_old
            dest = simpsons_new / season_folder_name(1)
            if not DRY_RUN:
                dest.mkdir(parents=True, exist_ok=True)
            for f in flat_videos_at_depth_one(src_for_files):
                safe_move(f, dest / f.name)

    last_of_us = ROOT / "The Last of Us Stagione 2"
    if last_of_us.is_dir():
        show = ROOT / "The Last of Us"
        dest = show / season_folder_name(2)
        if not DRY_RUN:
            show.mkdir(parents=True, exist_ok=True)
            dest.mkdir(parents=True, exist_ok=True)
        for f in flat_videos_at_depth_one(last_of_us):
            safe_move(f, dest / f.name)
        remove_empty_dir(last_of_us)

    last_frontier_old = ROOT / "The Last Frontier S01e01-05 (1080p Ita Eng Spa h265 10bit SubS) byMe7alh"
    last_frontier_new = ROOT / "The Last Frontier"
    if last_frontier_old.is_dir():
        dest = last_frontier_new / season_folder_name(1)
        if last_frontier_new.exists():
            pass
        elif not DRY_RUN:
            last_frontier_old.rename(last_frontier_new)
        else:
            log.info("RENAME %s -> %s", last_frontier_old, last_frontier_new)
        target = last_frontier_new if last_frontier_new.exists() or DRY_RUN else last_frontier_old
        dest = target / season_folder_name(1)
        if not DRY_RUN:
            dest.mkdir(parents=True, exist_ok=True)
        src = last_frontier_old if last_frontier_old.is_dir() else last_frontier_new
        for f in flat_videos_at_depth_one(src):
            safe_move(f, dest / f.name)
        if last_frontier_old.is_dir():
            remove_empty_dir(last_frontier_old)

    boris = ROOT / "Boris Stagione 1"
    if boris.is_dir():
        show = ROOT / "Boris"
        if not show.exists() and not DRY_RUN:
            show.mkdir(parents=True, exist_ok=True)
        dest = show / season_folder_name(1)
        if not DRY_RUN:
            dest.mkdir(parents=True, exist_ok=True)
        for f in flat_videos_at_depth_one(boris):
            safe_move(f, dest / f.name)
        for sub in boris.iterdir():
            if sub.is_dir():
                for f in sub.rglob("*"):
                    if f.is_file():
                        safe_move(f, dest / f.name)
        remove_empty_dir(boris)

    stargate_wrong = ROOT / "Stargates Atlantis"
    stargate_right = ROOT / "Stargate Atlantis"
    if stargate_wrong.is_dir():
        if stargate_right.exists() and stargate_right != stargate_wrong:
            target = stargate_right
            for f in flat_videos_at_depth_one(stargate_wrong):
                sn = extract_season_from_filename(f.name)
                if sn is None:
                    m = re.search(r"(?i)(\d+)x(\d+)", f.name)
                    sn = int(m.group(1)) if m else 1
                dest_dir = target / season_folder_name(sn)
                if not DRY_RUN:
                    dest_dir.mkdir(parents=True, exist_ok=True)
                safe_move(f, dest_dir / f.name)
            remove_empty_dir(stargate_wrong)
        else:
            safe_rename(stargate_wrong, stargate_right)
            src_for_files = stargate_right if stargate_right.is_dir() else stargate_wrong
            for f in flat_videos_at_depth_one(src_for_files):
                sn = extract_season_from_filename(f.name) or 1
                dest_dir = stargate_right / season_folder_name(sn)
                if not DRY_RUN:
                    dest_dir.mkdir(parents=True, exist_ok=True)
                safe_move(f, dest_dir / f.name)


def fix_unstructured_shows() -> None:
    """Manual fixes for shows without standard SxxExx in filenames."""
    fixes: list[tuple[str, int, re.Pattern[str] | None]] = [
        ("Nikita", 1, re.compile(r"(?i)NKT(\d{2})")),
        ("Serial Experiments Lain", 1, re.compile(r"(?i)ep(\d{1,2})")),
        ("Sherlock", 1, re.compile(r"(?i)^(\d{1,2})\.")),
        ("Curon (2020) - Season 1 Complete - 720p x264 ITA (ENG SUBS) [BRSHNKV]", 1, re.compile(r"(?i)Curon\s*(\d{1,2})")),
        ("Minù", 1, re.compile(r"(?i)^(\d{3})\s*-")),
        ("I Pilastri della Terra", 1, re.compile(r"(?i)^(\d)\.parte")),
        ("Proteggi La Mia Terra", 1, re.compile(r"(?i)^(\d{1,2})")),
        ("Nana", 1, re.compile(r"(?i)^(\d{1,2})")),
        ("Hogan", 1, re.compile(r"(?i)^(\d{1,2})\s")),
        ("Kidd Video", 1, re.compile(r"(?i)Episode\s*#?(\d{1,2})")),
        ("Sampei", 1, re.compile(r"(?i)^(\d{3})\s")),
        ("La Banda Dei Cinque", 1, re.compile(r"(?i)S01ep(\d{2})")),
        ("CuteHoney", 1, re.compile(r"(?i)^(\d{1,2})")),
    ]

    for folder_name, default_season, ep_re in fixes:
        folder = ROOT / folder_name
        if not folder.is_dir() or has_season_subdirs(folder):
            continue
        videos = flat_videos_at_depth_one(folder)
        if not videos:
            continue
        show_short = folder_name.split(" - ")[0].split(" (")[0]
        for f in videos:
            m = ep_re.search(f.name) if ep_re else None
            ep = int(m.group(1)) if m else 1
            sn = default_season
            dest_dir = folder / season_folder_name(sn)
            if not DRY_RUN:
                dest_dir.mkdir(parents=True, exist_ok=True)
            stem = Path(f.name).stem
            ext = f.suffix
            new_name = f"{show_short} - s{sn:02d}e{ep:02d} - {stem}{ext}"
            safe_move(f, dest_dir / new_name)

    # V: subfolder "2" -> Season 02
    v_dir = ROOT / "V"
    if v_dir.is_dir():
        sub2 = v_dir / "2"
        if sub2.is_dir():
            dest = v_dir / season_folder_name(2)
            if not DRY_RUN:
                dest.mkdir(parents=True, exist_ok=True)
            for f in flat_videos_at_depth_one(sub2):
                m = re.search(r"(?i)^(\d{1,2})\.", f.name)
                ep = int(m.group(1)) if m else 1
                new_name = f"V - s02e{ep:02d} - {f.name}"
                safe_move(f, dest / new_name)
            remove_empty_dir(sub2)

    # Big Bang Theory: subdirs 03, 04, 11 -> Season 03/04/11
    bbt = ROOT / "Big Bang Theory"
    if bbt.is_dir():
        for sub in bbt.iterdir():
            if sub.is_dir() and sub.name.isdigit():
                sn = int(sub.name)
                dest = bbt / season_folder_name(sn)
                if not DRY_RUN:
                    dest.mkdir(parents=True, exist_ok=True)
                for f in flat_videos_at_depth_one(sub):
                    if SEASON_IN_FILENAME.search(f.name):
                        safe_move(f, dest / f.name)
                        continue
                    m = re.search(r"(?i)^(\d{1,2})\.", f.name)
                    ep = int(m.group(1)) if m else 1
                    new_name = f"The Big Bang Theory - s{sn:02d}e{ep:02d} - {f.name}"
                    safe_move(f, dest / new_name)
                remove_empty_dir(sub)

    # Ultraman: Season 02/03 exist but files need sXXeYY prefix
    ultra = ROOT / "Ultraman"
    if ultra.is_dir() and has_season_subdirs(ultra):
        for season_dir in ultra.iterdir():
            m = SEASON_DIR_RE.match(season_dir.name)
            if not m:
                continue
            sn = int(m.group(1))
            for f in flat_videos_at_depth_one(season_dir):
                if SEASON_IN_FILENAME.search(f.name):
                    continue
                ep_m = re.search(r"(?i)^(\d{1,3})\s*-", f.name)
                ep = int(ep_m.group(1)) if ep_m else 1
                new_name = f"Ultraman - s{sn:02d}e{ep:02d} - {f.name}"
                safe_move(f, season_dir / new_name)


def is_show_candidate(path: Path) -> bool:
    if not path.is_dir():
        return False
    if path.name in ORPHAN_SEASONS:
        return False
    if path.name in SKIP_SHOWS:
        return False
    return True


def process_show_folders() -> None:
    """C + D for each eligible show under ROOT."""
    for entry in sorted(ROOT.iterdir()):
        if not is_show_candidate(entry):
            log.info("Skip show processing: %s", entry.name)
            continue
        if has_season_subdirs(entry):
            log.info("Already has Season subdirs, skip flat organize: %s", entry.name)
            continue
        organize_single_season_flat(entry)
        if has_season_subdirs(entry):
            continue
        organize_flat_by_filename_season(entry, entry.name)


def delete_empty_directories() -> None:
    """F) Remove empty directories under ROOT (deepest first)."""
    if not ROOT.is_dir():
        return
    dirs = sorted(
        [p for p in ROOT.rglob("*") if p.is_dir()],
        key=lambda p: len(p.parts),
        reverse=True,
    )
    for d in dirs:
        remove_empty_dir(d)
    if DRY_RUN:
        log.info("[DRY_RUN] would also prune empty dirs via find -delete")
        return
    subprocess.run(
        [
            "find",
            str(ROOT),
            "-mindepth",
            "1",
            "-type",
            "d",
            "-empty",
            "-delete",
        ],
        check=False,
    )


def main() -> int:
    setup_logging()
    if not ROOT.is_dir():
        log.error("ROOT does not exist: %s", ROOT)
        return 1
    try:
        special_renames()
        merge_orphan_seasons()
        melrose_1992_consolidation()
        fix_unstructured_shows()
        process_show_folders()
        delete_empty_directories()
        run_chmod_755()
        delete_empty_directories()
    except Exception:
        log.exception("Fatal error during reorganization")
        return 1
    log.info("=== reorg_serietv finished ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
