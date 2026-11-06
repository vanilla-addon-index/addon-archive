#!/usr/bin/env python3
"""
TurtleTongue Unified Database Crawler

Crawls Turtle WoW database (database.turtlecraft.gg) for NPCs, quests, and books.
Supports concurrent fetching for speed and --recrawl to update existing entries.

All databases use consistent format: {"entries": {"<id>": {...}}, "metadata": {...}}
where <id> is the URL entry ID (e.g., ?npc=823 → key "823").

Modes:
  npc    — NPC names, display IDs, and races (via DBC file mapping)
  quest  — Quest text (Description, Progress, Completion) and quest giver info
  object — Book/object content (fast-path: skips non-books automatically)

Usage:
    python crawler.py --mode npc --start 1 --end 100000 --workers 10
    python crawler.py --mode quest --start 1 --end 110000 --workers 10
    python crawler.py --mode object --start 1 --end 400000 --workers 20
    python crawler.py --mode quest --recrawl --workers 10
    python crawler.py --mode quest --start 1 --end 10000 --workers 1 --delay 0.1
"""

import argparse
import json
import re
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import requests
from bs4 import BeautifulSoup, NavigableString

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

BASE_URL = "https://database.turtlecraft.gg/"
DEFAULT_HEADERS = {
    "User-Agent": "TurtleTongue/1.0 (game addon, non-commercial)"
}

PROJECT_ROOT = Path(__file__).parent.parent
DATA_PATH = PROJECT_ROOT / "data"
DBC_PATH = DATA_PATH

OUTPUT_PATHS = {
    "npc": DATA_PATH / "npc_database.json",
    "quest": DATA_PATH / "quest_database.json",
    "object": DATA_PATH / "object_database.json",
}

SAVE_INTERVAL = 100  # Save to disk every N found entries

# Thread-local storage for per-thread HTTP sessions (connection pooling)
_thread_local = threading.local()


def _get_session():
    """Get or create a thread-local requests.Session for connection pooling."""
    if not hasattr(_thread_local, "session"):
        _thread_local.session = requests.Session()
        _thread_local.session.headers.update(DEFAULT_HEADERS)
    return _thread_local.session


# ---------------------------------------------------------------------------
# DBC file loading (NPC mode only)
# ---------------------------------------------------------------------------

_dbc_cache = None


def load_dbc_files():
    """Load DBC CSV files into lookup dictionaries for race mapping."""
    global _dbc_cache
    if _dbc_cache is not None:
        return _dbc_cache

    print("Loading DBC files...")

    # CreatureDisplayInfo: DisplayID → [all columns]
    display_info = {}
    with open(DBC_PATH / "CreatureDisplayInfo.csv", "r", encoding="utf-8") as f:
        for line in f.readlines()[1:]:
            parts = line.strip().split(",")
            if len(parts) >= 4:
                display_id = parts[0].strip('"')
                display_info[display_id] = [p.strip('"') for p in parts]

    # CreatureDisplayInfoExtra: ExtendedID → (DisplayRaceID, DisplaySexID)
    display_extra = {}
    with open(DBC_PATH / "CreatureDisplayInfoExtra.csv", "r", encoding="utf-8") as f:
        for line in f.readlines()[1:]:
            parts = line.strip().split(",")
            if len(parts) >= 3:
                ext_id = parts[0].strip('"')
                race_id = parts[1].strip('"')
                sex_id = parts[2].strip('"')  # 0=male, 1=female
                display_extra[ext_id] = (race_id, sex_id)

    # ChrRaces: RaceID → RaceName
    races = {}
    with open(DBC_PATH / "ChrRaces.csv", "r", encoding="utf-8") as f:
        for line in f.readlines()[1:]:
            parts = line.strip().split(",")
            if len(parts) >= 18:
                race_id = parts[0].strip('"')
                race_name = parts[17].strip('"')
                races[race_id] = race_name

    # CreatureModelData: ModelID → creature type name
    model_data = {}
    with open(DBC_PATH / "CreatureModelData.csv", "r", encoding="utf-8") as f:
        for line in f.readlines()[1:]:
            parts = line.strip().split(",")
            if len(parts) >= 3:
                model_id = parts[0].strip('"')
                model_name = parts[2].strip('"')
                if "\\" in model_name:
                    full_name = model_name.split("\\")[-1].replace(".mdx", "")
                    name = full_name.split(" ")[0]
                    for suffix in ["Melee", "Ranged", "War", "Boss", "Champion"]:
                        name = name.replace(suffix, "")
                else:
                    name = model_name
                model_data[model_id] = name

    print(f"  {len(display_info)} display, {len(display_extra)} extra, "
          f"{len(races)} races, {len(model_data)} models")

    _dbc_cache = (display_info, display_extra, races, model_data)
    return _dbc_cache


def map_display_id_to_race_and_sex(display_id, display_info, display_extra, races, model_data):
    """Map a DisplayID to (race, sex) using the DBC chain.

    Returns (race_name, sex_str) where sex_str is "male", "female", or "unknown".
    """
    SEX_MAP = {"0": "male", "1": "female"}

    if not display_id or display_id == "0":
        return ("Unknown", "unknown")

    display_row = display_info.get(display_id)
    if not display_row or len(display_row) < 4:
        return ("Unknown", "unknown")

    model_id = display_row[1]
    extended_id = display_row[3] if len(display_row) > 3 else "0"

    # Primary: ExtendedDisplayInfoID → ChrRaces + sex
    if extended_id and extended_id != "0":
        extra = display_extra.get(extended_id)
        if extra:
            race_id, sex_id = extra
            if race_id and race_id != "0":
                race_name = races.get(race_id, "Unknown")
                sex = SEX_MAP.get(sex_id, "unknown")
                if race_name:
                    return (race_name, sex)

    # Fallback: ModelID → CreatureModelData → creature type (no sex info)
    if model_id and model_id != "0":
        model_name = model_data.get(model_id, "")
        if model_name:
            return (model_name, "unknown")

    return ("Unknown", "unknown")


# ---------------------------------------------------------------------------
# NPC extraction
# ---------------------------------------------------------------------------

def extract_npc_data(html, npc_id, dbc):
    """Extract NPC name, display ID, and race from an NPC page."""
    if "Display ID:" not in html:
        return None

    soup = BeautifulSoup(html, "html.parser")

    title = soup.find("h1")
    if not title:
        return None

    npc_name = title.get_text(strip=True)
    if not npc_name:
        return None
    npc_name = npc_name.replace(" - NPCs", "").strip()

    display_match = re.search(r"Display ID:\s*(\d+)", html)
    if not display_match:
        return None
    display_id = display_match.group(1)

    display_info, display_extra, races, model_data = dbc
    race, sex = map_display_id_to_race_and_sex(display_id, display_info, display_extra, races, model_data)

    result = {
        "name": npc_name,
        "display_id": display_id,
        "race": race,
    }
    if sex != "unknown":
        result["sex"] = sex
    return result


# ---------------------------------------------------------------------------
# Quest extraction
# ---------------------------------------------------------------------------

def extract_quest_data(html, quest_id):
    """Extract quest text sections from a quest page."""
    soup = BeautifulSoup(html, "html.parser")

    main = soup.find(id="main-contents")
    if not main:
        return None

    text_div = main.find("div", class_="text")
    if not text_div:
        return None

    h1 = text_div.find("h1")
    if not h1:
        return None
    title = h1.get_text(strip=True)
    if not title:
        return None

    sections = _extract_sections(text_div)
    description = sections.get("Description", "")
    progress = sections.get("Progress", "")
    completion = sections.get("Completion", "")

    if not description and not progress and not completion:
        return None

    quest_giver = ""
    quest_giver_id = ""
    quest_ender = ""
    quest_ender_id = ""
    side = ""
    level = ""
    required_level = ""

    quick_facts = _find_quick_facts_table(soup)
    if quick_facts:
        qf_text = quick_facts.get_text()

        level_match = re.search(r"Level:\s*(\d+)", qf_text)
        if level_match:
            level = level_match.group(1)

        required_match = re.search(r"Requires level:\s*(\d+)", qf_text)
        if required_match:
            required_level = required_match.group(1)

        side_match = re.search(r"Side:\s*([^\n]+)", qf_text)
        if side_match:
            side = side_match.group(1).strip()

        npc_links = _extract_npc_links(quick_facts)
        if npc_links.get("start"):
            quest_giver = npc_links["start"]["name"]
            quest_giver_id = npc_links["start"]["id"]
        if npc_links.get("end"):
            quest_ender = npc_links["end"]["name"]
            quest_ender_id = npc_links["end"]["id"]

    result = {
        "title": title,
        "quest_giver": quest_giver,
        "quest_giver_id": quest_giver_id,
        "description": description,
        "progress": progress,
        "completion": completion,
    }

    if quest_ender and quest_ender != quest_giver:
        result["quest_ender"] = quest_ender
        result["quest_ender_id"] = quest_ender_id
    if side:
        result["side"] = side
    if level:
        result["level"] = level
    if required_level:
        result["required_level"] = required_level

    return result


# ---------------------------------------------------------------------------
# Object/Book extraction
# ---------------------------------------------------------------------------

def extract_object_data(html, object_id):
    """Extract book/object content text from an object page."""
    soup = BeautifulSoup(html, "html.parser")

    main = soup.find(id="main-contents")
    if not main:
        return None

    text_div = main.find("div", class_="text")
    if not text_div:
        return None

    h1 = text_div.find("h1")
    if not h1:
        return None
    name = h1.get_text(strip=True)
    if not name:
        return None

    pages = _extract_book_pages(html)
    if pages:
        content = "\n\n".join(pages)
        return {
            "name": name,
            "content": content,
            "pages": pages,
            "type": "book",
        }

    sections = _extract_sections(text_div)
    content_text = sections.get("Content", "")
    if content_text:
        return {
            "name": name,
            "content": content_text,
            "type": "object",
        }

    return None


# ---------------------------------------------------------------------------
# Shared HTML helpers
# ---------------------------------------------------------------------------

def _extract_sections(text_div):
    """Extract text sections from div.text, preserving paragraph breaks from <br/><br/>."""
    sections = {}
    current_section = None
    br_count = 0

    for child in text_div.children:
        if hasattr(child, "name") and child.name == "h3":
            current_section = child.get_text(strip=True)
            sections[current_section] = []
            br_count = 0
        elif current_section:
            if hasattr(child, "name") and child.name == "br":
                br_count += 1
                continue

            text = None
            if isinstance(child, NavigableString):
                text = str(child).strip()
            elif hasattr(child, "get_text"):
                text = child.get_text(strip=True)

            if text:
                if br_count >= 2 and sections[current_section]:
                    sections[current_section].append("\n\n")
                sections[current_section].append(text)
            br_count = 0

    result = {}
    for section, texts in sections.items():
        combined = " ".join(texts).strip()
        combined = re.sub(r" *\n\n *", "\n\n", combined)
        combined = _clean_text(combined)
        if combined:
            result[section] = combined

    return result


def _clean_text(text):
    """Clean extracted text of HTML/JS artifacts. Preserves player markers and paragraph breaks."""
    text = re.sub(r"ge\('[^']*'\)\.appendChild\([^)]*\);", "", text)
    text = re.sub(r"ge\('[^']*'\)\.[^;]*;", "", text)
    text = re.sub(r"\s*See also\s*$", "", text)
    # Collapse horizontal whitespace but preserve \n paragraph breaks
    text = re.sub(r"[^\S\n]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = text.strip()
    # NOTE: Player markers (<name>, <class>, <race>, <grin>, <cough>, $G, $B etc.)
    # are intentionally preserved for later substitution — see scripts/text_sub.py
    return text


def _extract_book_pages(html):
    """Extract multi-page book content from JavaScript Book() pattern."""
    match = re.search(r"new Book\(\{[^}]*pages:\s*\[(.*?)\]\s*\}", html, re.DOTALL)
    if not match:
        return None

    pages_str = match.group(1)
    raw_pages = re.findall(r"'((?:[^'\\]|\\.)*?)'", pages_str)
    if not raw_pages:
        return None

    pages = []
    for page in raw_pages:
        page = page.replace("\\n", "\n")
        page = page.replace("\\r", "\r")
        page = page.replace("\\/", "/")
        page = page.replace("\\'", "'")
        page = page.replace('\\"', '"')
        page = page.replace("\\\\", "\\")
        page = _clean_book_page(page)
        if page:
            pages.append(page)

    return pages if pages else None


def _clean_book_page(text):
    """Strip WoW client rich text markup and normalize whitespace for TTS.

    Handles three formats found in book/object content:
    1. WoW rich text: <HTML><BODY><H1 align="center">...<BR/>...
    2. HTML line breaks: <br /><br />
    3. Plain text with \\r\\n
    """
    # Strip WoW rich text tags (with optional attributes)
    text = re.sub(r"</?(?:HTML|BODY|H1|H2|H3|P|BR)\b[^>]*/?>", "\n", text, flags=re.IGNORECASE)
    # Strip <br /> style tags
    text = re.sub(r"<br\s*/?>", "\n", text, flags=re.IGNORECASE)
    # Normalize \r\n to \n
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    # Collapse 3+ newlines to paragraph break, strip excess whitespace per line
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r" ?\n ?", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def _find_quick_facts_table(soup):
    """Find the Quick Facts table in the page."""
    for table in soup.find_all("table"):
        text = table.get_text()
        if "Quick Facts" in text or ("Start" in text and "End" in text):
            return table
    return None


def _extract_npc_links(quick_facts):
    """Extract Start/End NPC links from Quick Facts table."""
    result = {}
    npc_links = []
    for link in quick_facts.find_all("a"):
        href = link.get("href", "")
        npc_match = re.search(r"\?npc=(\d+)", href)
        if npc_match:
            npc_links.append({
                "name": link.get_text(strip=True),
                "id": npc_match.group(1),
            })

    if len(npc_links) >= 1:
        result["start"] = {"name": npc_links[0]["name"], "id": npc_links[0]["id"]}
    if len(npc_links) >= 2:
        result["end"] = {"name": npc_links[1]["name"], "id": npc_links[1]["id"]}
    elif len(npc_links) == 1:
        result["end"] = result.get("start", {})

    return result


# ---------------------------------------------------------------------------
# Database I/O
# ---------------------------------------------------------------------------

def load_database(path):
    """Load existing database. Returns {"entries": {}, "metadata": {}}."""
    if path.exists():
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        # Handle old NPC format: {"npc_database": {...}} → {"entries": {...}}
        if "npc_database" in data and "entries" not in data:
            return {
                "entries": data["npc_database"],
                "metadata": data.get("metadata", {}),
                "_old_format": True,
            }
        if "entries" not in data:
            return {"entries": {}, "metadata": data.get("metadata", {})}
        return data
    return {"entries": {}, "metadata": {}}


def save_database(data, path):
    """Save database to JSON file."""
    # Strip internal flags before saving
    clean = {k: v for k, v in data.items() if not k.startswith("_")}
    with open(path, "w", encoding="utf-8") as f:
        json.dump(clean, f, indent=2, ensure_ascii=False)


# ---------------------------------------------------------------------------
# Fetch worker (called by each thread)
# ---------------------------------------------------------------------------

MAX_RETRIES = 3
RETRY_BACKOFF = [1.0, 3.0, 7.0]  # seconds between retries on 403


def _fetch_one(entry_id, mode, dbc_data=None, delay=0):
    """
    Fetch a single page and extract data. Thread-safe.

    Returns (entry_id, data_dict, status) where status is "found"/"skip"/"error".
    Retries on HTTP 403 (rate limiting) with exponential backoff.
    """
    session = _get_session()
    url = f"{BASE_URL}?{mode}={entry_id}"

    response = None
    for attempt in range(MAX_RETRIES + 1):
        try:
            response = session.get(url, timeout=15)
        except requests.exceptions.RequestException:
            return (entry_id, None, "error")

        if response.status_code == 403 and attempt < MAX_RETRIES:
            time.sleep(RETRY_BACKOFF[attempt])
            continue
        break

    if delay > 0:
        time.sleep(delay)

    if response is None or response.status_code != 200:
        return (entry_id, None, "skip")

    html = response.text

    if mode == "npc":
        if "Quick Facts" not in html:
            return (entry_id, None, "skip")
        data = extract_npc_data(html, entry_id, dbc_data)

    elif mode == "quest":
        if "Quick Facts" not in html:
            return (entry_id, None, "skip")
        data = extract_quest_data(html, entry_id)

    elif mode == "object":
        # Fast-path: skip pages with no book/content data
        if "new Book" not in html and "<h3>" not in html:
            return (entry_id, None, "skip")
        data = extract_object_data(html, entry_id)

    else:
        return (entry_id, None, "skip")

    if data:
        return (entry_id, data, "found")
    return (entry_id, None, "skip")


# ---------------------------------------------------------------------------
# Crawl engine
# ---------------------------------------------------------------------------

def crawl(mode, ids, db_data, output_path, workers=10, delay=0,
          save_every=None, dbc_data=None):
    """
    Crawl a list of IDs using concurrent workers.

    Results are collected in the main thread — no locking needed for entries dict.
    """
    if save_every is None:
        save_every = 1 if mode == "object" else SAVE_INTERVAL
    entries = db_data["entries"]
    total = len(ids)
    found = 0
    skipped = 0
    errors = 0
    processed = 0
    last_save_found = 0
    start_time = time.time()

    print(f"\nCrawling {total} {mode} IDs with {workers} worker(s)...")

    with ThreadPoolExecutor(max_workers=workers) as executor:
        future_to_id = {
            executor.submit(_fetch_one, eid, mode, dbc_data, delay): eid
            for eid in ids
        }

        for future in as_completed(future_to_id):
            try:
                entry_id, data, status = future.result()
            except Exception as e:
                errors += 1
                processed += 1
                continue

            if status == "found":
                entries[str(entry_id)] = data
                found += 1

                # Periodic save
                if found - last_save_found >= save_every:
                    db_data["metadata"] = {
                        "last_updated": time.strftime("%Y-%m-%d %H:%M:%S"),
                        "mode": mode,
                        "total_entries": len(entries),
                        "in_progress": True,
                    }
                    save_database(db_data, output_path)
                    last_save_found = found
                    print(f"\n  [Saved {len(entries)} entries]")

            elif status == "error":
                errors += 1
            else:
                skipped += 1

            processed += 1

            if processed % 100 == 0 or processed == total:
                elapsed = time.time() - start_time
                rate = processed / elapsed if elapsed > 0 else 0
                eta = (total - processed) / rate if rate > 0 else 0
                pct = int(processed / total * 50)
                bar = "█" * pct + "░" * (50 - pct)
                print(
                    f"\r  [{bar}] {processed}/{total} | "
                    f"Found: {found} | Skip: {skipped} | Err: {errors} | "
                    f"ETA: {eta/60:.1f}min",
                    end="", flush=True,
                )

    elapsed = time.time() - start_time
    print(f"\n\nCompleted in {elapsed/60:.1f} minutes")
    print(f"Found: {found} | Skipped: {skipped} | Errors: {errors}")

    return found


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="TurtleTongue Unified Database Crawler"
    )
    parser.add_argument(
        "--mode", choices=["npc", "quest", "object"], required=True,
        help="What to crawl: npc, quest, or object (books)",
    )
    parser.add_argument(
        "--start", type=int, default=1,
        help="Starting ID (default: 1)",
    )
    parser.add_argument(
        "--end", type=int, default=None,
        help="Ending ID (default: 100000/npc, 110000/quest, 400000/object)",
    )
    parser.add_argument(
        "--workers", type=int, default=10,
        help="Concurrent workers (default: 10)",
    )
    parser.add_argument(
        "--delay", type=float, default=0,
        help="Per-request delay in seconds (default: 0)",
    )
    parser.add_argument(
        "--force", action="store_true",
        help="Start fresh, ignore existing database",
    )
    parser.add_argument(
        "--recrawl", action="store_true",
        help="Re-fetch only existing entries (update with latest parser)",
    )
    parser.add_argument(
        "--save-every", type=int, default=SAVE_INTERVAL,
        help=f"Save every N found entries (default: {SAVE_INTERVAL})",
    )

    args = parser.parse_args()

    # Default end IDs per mode
    if args.end is None:
        args.end = {"npc": 100000, "quest": 110000, "object": 400000}[args.mode]

    output_path = OUTPUT_PATHS[args.mode]

    print("=" * 60)
    print(f"TurtleTongue {args.mode.upper()} Crawler")
    print("=" * 60)

    # Load DBC files for NPC mode
    dbc_data = None
    if args.mode == "npc":
        dbc_data = load_dbc_files()

    # Load existing database
    if args.force:
        db_data = {"entries": {}, "metadata": {}}
        print("Force mode: starting fresh")
    else:
        db_data = load_database(output_path)

    existing_count = len(db_data["entries"])
    print(f"Existing entries: {existing_count}")

    # Old NPC format (keyed by name) can't be extended — must re-crawl
    if db_data.get("_old_format") and not args.force and not args.recrawl:
        print("\nOld NPC database format detected (keyed by name instead of ID).")
        print("Use --force to re-crawl with new format (old data will be replaced).")
        return

    # Build ID list
    if args.recrawl:
        if existing_count == 0:
            print("No existing entries to recrawl.")
            return

        # Detect old NPC format (keyed by name, not ID)
        if db_data.get("_old_format"):
            first_key = next(iter(db_data["entries"]), "")
            if first_key and not first_key.isdigit():
                print("Old NPC database format (keyed by name). Use --force to re-crawl with new format.")
                return

        ids = sorted(int(k) for k in db_data["entries"].keys())
        print(f"Recrawl mode: re-fetching {len(ids)} existing entries")
    else:
        # Range scan: skip already-crawled IDs
        existing_ids = set(db_data["entries"].keys())
        ids = [i for i in range(args.start, args.end + 1) if str(i) not in existing_ids]
        total_range = args.end - args.start + 1
        skip_count = total_range - len(ids)
        if skip_count > 0:
            print(f"Skipping {skip_count} already-crawled IDs")

    if not ids:
        print("Nothing to crawl.")
        return

    # Crawl
    start_time = time.time()

    try:
        found = crawl(
            mode=args.mode,
            ids=ids,
            db_data=db_data,
            output_path=output_path,
            workers=args.workers,
            delay=args.delay,
            save_every=args.save_every,
            dbc_data=dbc_data,
        )
    except KeyboardInterrupt:
        print("\n\nInterrupted — saving progress...")
        found = 0  # partial

    # Final save
    db_data["metadata"] = {
        "last_updated": time.strftime("%Y-%m-%d %H:%M:%S"),
        "mode": args.mode,
        "total_entries": len(db_data["entries"]),
    }
    if not args.recrawl:
        db_data["metadata"]["id_range"] = f"{args.start}-{args.end}"
    save_database(db_data, output_path)

    total_time = time.time() - start_time
    print(f"\n{'=' * 60}")
    print(f"Total entries: {len(db_data['entries'])}")
    print(f"New/updated: {found}")
    print(f"Total time: {total_time/60:.1f} minutes")
    print(f"Saved to: {output_path}")


if __name__ == "__main__":
    main()
