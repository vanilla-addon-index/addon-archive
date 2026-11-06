#!/usr/bin/env python3
"""
Turtle's Epoch Batch Voice Generator

Generates voice lines for all quest/object/manual entries using Fish Speech S2 Pro
via HTTP API server. Outputs .wav files at deterministic paths and a
voice_manifest.lua with durations.

Requires Fish Speech API server running:
    cd fish-speech && python tools/api_server.py --device cuda

Voice selection hierarchy:
  1. Tier 3 custom NPC → samples/custom/{npc}/
  2. Base race + sex   → samples/{race}_{sex}/
  3. Creature type     → samples/creature/{type}/ (or {type}_{sex}/ for centaur/naga)
  4. Narrator fallback → samples/narrator/

Per-NPC voice uniqueness:
  - Each NPC gets a deterministic seed from DJB2(name)
  - Seed controls which reference clips are selected and generation temperature
  - First generated line saved as .voice_anchor.wav for cross-line consistency

Usage:
    python scripts/generate_voice.py --source quests
    python scripts/generate_voice.py --source objects
    python scripts/generate_voice.py --source manual
    python scripts/generate_voice.py --source all
    python scripts/generate_voice.py --source all --missing-only
    python scripts/generate_voice.py --quest-id 123 --force
    python scripts/generate_voice.py --dry-run --source quests   # preview without generating
"""

import argparse
import base64
import io
import json
import os
import re
import shutil
import subprocess
import sys
import wave
from pathlib import Path

import requests

PROJECT_ROOT = Path(__file__).parent.parent
DATA_DIR = PROJECT_ROOT / "data"
SOUNDS_DIR = PROJECT_ROOT / "sounds"
SAMPLES_DIR = PROJECT_ROOT / "samples"

# Add scripts/ to path for imports
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))
from text_sub import substitute_text, load_player_config
from analyze_quest_races import normalize_race
from audio_effects import (
    resolve_config_key, get_donor_samples_dir,
    clear_config_cache, apply_voice_effects,
    normalize_loudness,
)
from emotion_tagger import load_emotion_cache, get_tagged_text

# ─── Tier 3 named NPCs ───────────────────────────────────────────────────
TIER3_NPCS = {
    "Thrall": "thrall",
    "Archmage Ansirem Runeweaver": "archmage_ansirem_runeweaver",
    "Tirion Fordring": "tirion_fordring",
    "Lord Tirion Fordring": "tirion_fordring",  # alias (quest 5944 ender)
    "Varimathras": "varimathras",
    "Chromie": "chromie",
    "Nathanos Blightcaller": "nathanos_blightcaller",
    "Highlord Bolvar Fordragon": "highlord_bolvar_fordragon",
    "Cairne Bloodhoof": "cairne_bloodhoof",
    "King Magni Bronzebeard": "king_magni_bronzebeard",
    "Gazlowe": "gazlowe",
    "Vereesa Windrunner": "vereesa_windrunner",
    "Tyrande Whisperwind": "tyrande_whisperwind",
    "Lady Sylvanas Windrunner": "lady_sylvanas_windrunner",
    "Vol'jin": "voljin",
    "Rexxar": "rexxar",
    "Lady Jaina Proudmoore": "lady_jaina_proudmoore",
}

# Gendered creature types (have {type}_male and {type}_female sample folders)
GENDERED_CREATURES = {"Centaur", "Naga"}

# Temperature range for per-NPC voice variation (Fish Speech range 0.1-1.0, default 0.8)
TEMP_MIN = 0.65
TEMP_MAX = 0.85
TEMP_CUSTOM = 0.75  # Tier 3 named NPCs (same base — expressiveness comes from samples)

# Fish Speech API defaults
DEFAULT_SERVER_URL = "http://127.0.0.1:8080"
DEFAULT_CHUNK_LENGTH = 200
DEFAULT_MAX_NEW_TOKENS = 2048

# ─── DJB2 hash (must match core/Init.lua HashKey exactly) ────────────────
def djb2_hash(key):
    """Compute first 8 hex chars of DJB2 hash. Matches Lua HashKey()."""
    if not key:
        return "00000000"
    h = 5381
    for ch in key:
        h = (h * 33 + ord(ch)) % 4294967296
    return f"{h:08x}"


def normalize_name(name):
    """Normalize NPC name for file paths. Matches Lua NormalizeName()."""
    if not name:
        return "unknown"
    name = name.lower()
    name = re.sub(r"\s+", "_", name)
    name = re.sub(r"[^\w]", "", name)
    if not name:
        return "unknown"
    return name


def split_narrator_segments(text):
    """Split text into NPC-voiced and narrator-voiced segments.

    Multi-word stage directions in <angle brackets> become narrator segments.
    Single-word markers like <name> are already resolved by text_sub.

    Returns list of (text, is_narrator) tuples. Empty segments are removed.
    """
    parts = re.split(r'(<[^<>]+>)', text)

    segments = []
    for part in parts:
        part = part.strip()
        if not part:
            continue
        if part.startswith('<') and part.endswith('>'):
            inner = part[1:-1].strip()
            if inner:
                segments.append((inner, True))
        else:
            segments.append((part, False))

    return segments if segments else [(text, False)]


def concatenate_wavs(wav_paths, output_path, gap_ms=300):
    """Concatenate multiple WAV files into one, with silence gaps between segments."""
    if not wav_paths:
        return
    if len(wav_paths) == 1:
        shutil.move(str(wav_paths[0]), str(output_path))
        return

    output_path.parent.mkdir(parents=True, exist_ok=True)

    with wave.open(str(wav_paths[0]), 'rb') as wf:
        params = wf.getparams()

    gap_frames = int(params.framerate * gap_ms / 1000)
    silence = b'\x00' * (gap_frames * params.sampwidth * params.nchannels)

    with wave.open(str(output_path), 'wb') as outfile:
        outfile.setparams(params)
        for i, path in enumerate(wav_paths):
            with wave.open(str(path), 'rb') as infile:
                outfile.writeframes(infile.readframes(infile.getnframes()))
            if i < len(wav_paths) - 1 and gap_ms > 0:
                outfile.writeframes(silence)


def get_wav_duration(path):
    """Get duration of a .wav or .ogg file in seconds."""
    import soundfile as sf
    info = sf.info(str(path))
    return info.duration


def wav_to_ogg(wav_path):
    """Convert a WAV file to OGG Vorbis (quality 2, mono) and delete the WAV.

    Returns the path to the .ogg file. Two-pass encode: wav → ogg → ogg.
    A single-pass encode of certain Fish Speech output (post-effects) produces
    OGG streams that some WoW audio stacks (notably WINE) silently reject
    even though ffprobe/any normal player accepts them. Re-encoding the ogg
    through libvorbis normalizes the packet layout and consistently produces
    a file WoW will play. -ar 44100 + -f ogg match Blizzard's standard format.

    -q:a 2 (~96 kbps): empirically required for cross-platform playback. The
    WoW 3.3.5 client and some WINE audio stacks are bitrate-sensitive — higher
    settings (q:a 4 / q:a 6) intermittently produce files with non-monotonic
    granulepos that look fine to ffprobe but play silent in-game. q:a 2
    reliably normalizes the timestamps. See AGENTS.md.
    """
    ogg_path = wav_path.with_suffix(".ogg")
    intermediate = wav_path.with_suffix(".tmp.ogg")
    vorbis_args = ["-c:a", "libvorbis", "-q:a", "2", "-ar", "44100",
                   "-ac", "1", "-f", "ogg"]
    subprocess.run(
        ["ffmpeg", "-y", "-i", str(wav_path)] + vorbis_args +
        [str(intermediate), "-loglevel", "error"],
        check=True,
    )
    subprocess.run(
        ["ffmpeg", "-y", "-i", str(intermediate)] + vorbis_args +
        [str(ogg_path), "-loglevel", "error"],
        check=True,
    )
    intermediate.unlink()
    wav_path.unlink()
    return ogg_path


# ─── Voice profile resolution ────────────────────────────────────────────
def resolve_voice_profile(npc_name, race, sex):
    """Resolve which sample folder to use for an NPC.

    Returns (sample_dir, is_custom) tuple.
    """
    # Tier 3: custom voice
    if npc_name in TIER3_NPCS:
        custom_dir = SAMPLES_DIR / "custom" / TIER3_NPCS[npc_name]
        if custom_dir.is_dir():
            return custom_dir, True

    # Normalize race
    if not race or race == "Narrator":
        return SAMPLES_DIR / "narrator", False

    # Gendered creature types
    if race in GENDERED_CREATURES:
        sex_label = sex if sex in ("male", "female") else "male"
        creature_dir = SAMPLES_DIR / "creature" / f"{race.lower()}_{sex_label}"
        if creature_dir.is_dir():
            return creature_dir, False

    # Other creature types (non-base races)
    base_races = {
        "Human", "Dwarf", "Night Elf", "Gnome", "High Elf",
        "Orc", "Troll", "Undead", "Tauren", "Goblin",
    }
    if race not in base_races:
        creature_folder = race.lower().replace(" ", "_")
        creature_dir = SAMPLES_DIR / "creature" / creature_folder
        if creature_dir.is_dir():
            return creature_dir, False
        # Creature folder missing → narrator fallback
        return SAMPLES_DIR / "narrator", False

    # Base race + sex
    sex_label = sex if sex in ("male", "female") else "male"
    race_folder = race.lower().replace(" ", "_")
    race_dir = SAMPLES_DIR / f"{race_folder}_{sex_label}"
    if race_dir.is_dir():
        return race_dir, False

    # Fallback
    return SAMPLES_DIR / "narrator", False


def get_sample_files(sample_dir):
    """Get list of .wav files from a sample directory."""
    if not sample_dir.is_dir():
        return []
    return sorted(p for p in sample_dir.iterdir() if p.suffix.lower() == ".wav")


def select_samples_for_npc(sample_files, npc_seed, is_custom):
    """Select which samples to use for a specific NPC.

    Custom NPCs (Tier 3): use all samples directly.
    Others: use seed to pick a deterministic subset for voice variation.
    """
    if is_custom or len(sample_files) <= 2:
        return sample_files

    # Use seed to shuffle then take a subset (3-5 files)
    import random
    rng = random.Random(npc_seed)
    shuffled = list(sample_files)
    rng.shuffle(shuffled)
    count = min(len(shuffled), rng.randint(3, min(5, len(shuffled))))
    return shuffled[:count]


def npc_temperature(npc_seed, is_custom):
    """Deterministic temperature for an NPC. Custom NPCs use TEMP_CUSTOM."""
    if is_custom:
        return TEMP_CUSTOM
    import random
    rng = random.Random(npc_seed)
    return rng.uniform(TEMP_MIN, TEMP_MAX)


# ─── NPC database lookup ─────────────────────────────────────────────────
def load_npc_database():
    """Load NPC database and build name → (race, sex) lookup."""
    path = DATA_DIR / "npc_database.json"
    with open(path, encoding="utf-8") as f:
        db = json.load(f)

    npc_map = {}
    for entry_id, entry in db["entries"].items():
        name = entry.get("name", "").strip()
        if not name:
            continue
        raw_race = entry.get("race", "")
        norm = normalize_race(raw_race) if raw_race else None
        sex = entry.get("sex", "unknown")
        race = norm if norm else "Narrator"

        # Keep best entry for duplicate names
        if name in npc_map:
            existing_race, existing_sex = npc_map[name]
            # Prefer known race/sex
            score_new = (2 if race != "Narrator" else 0) + (1 if sex != "unknown" else 0)
            score_old = (2 if existing_race != "Narrator" else 0) + (1 if existing_sex != "unknown" else 0)
            if score_new <= score_old:
                continue
        npc_map[name] = (race, sex)
    return npc_map


# ─── Build generation work items ─────────────────────────────────────────
def build_quest_items(npc_map, quest_id_filter=None):
    """Build work items from quest_database.json."""
    path = DATA_DIR / "quest_database.json"
    if not path.exists():
        print("Warning: quest_database.json not found, skipping quests")
        return []

    with open(path, encoding="utf-8") as f:
        db = json.load(f)

    items = []
    field_to_dialog = {
        "description": "quest_detail",
        "progress": "quest_progress",
        "completion": "quest_complete",
    }

    # Map dialog type → NPC name field
    npc_field_for_dialog = {
        "description": "quest_giver",
        "progress": "quest_ender",
        "completion": "quest_ender",
    }

    for quest_id, quest in db["entries"].items():
        if quest_id_filter and quest_id != str(quest_id_filter):
            continue

        title = quest.get("title", "").strip()
        if not title:
            continue

        for field, dialog_type in field_to_dialog.items():
            text = quest.get(field, "").strip()
            if not text:
                continue

            # Resolve NPC(s) for this dialog line. May be a list if multiple
            # NPCs share the same quest (e.g. AQ war-effort quests with a
            # giver in every capital).
            npc_field = npc_field_for_dialog[field]
            npc_value = quest.get(npc_field, "")
            if isinstance(npc_value, list):
                npc_names = [n.strip() for n in npc_value if n and n.strip()]
            else:
                npc_names = [npc_value.strip()] if npc_value and npc_value.strip() else []

            if not npc_names:
                # Fallback to quest_giver
                fallback = quest.get("quest_giver", "")
                if isinstance(fallback, list):
                    npc_names = [n.strip() for n in fallback if n and n.strip()]
                else:
                    npc_names = [fallback.strip()] if fallback and fallback.strip() else []

            if not npc_names:
                npc_names = [""]  # produce one "unknown" narrator entry

            # Hash key = quest title + quest ID (stable, globally unique across chain steps)
            key_str = f"{title}_{quest_id}"

            for npc_name in npc_names:
                # Look up race/sex
                if npc_name and npc_name in npc_map:
                    race, sex = npc_map[npc_name]
                else:
                    race, sex = "Narrator", "unknown"

                items.append({
                    "npc_name": npc_name or "unknown",
                    "race": race,
                    "sex": sex,
                    "dialog_type": dialog_type,
                    "key_str": key_str,
                    "text": text,
                    "source": "quest",
                    "source_id": quest_id,
                })

        # Item-start craftsman's writs are readable inventory quest items.
        # Generate narrator item text so ITEM_TEXT_READY can play them directly.
        description = quest.get("description", "").strip()
        if title.startswith("Craftsman's Writ - ") and description:
            items.append({
                "npc_name": title,
                "race": "Narrator",
                "sex": "unknown",
                "dialog_type": "item_p1",
                "key_str": f"{title}_page1",
                "text": description,
                "source": "quest_item",
                "source_id": quest_id,
            })

    return items


def build_object_items():
    """Build work items from object_database.json (books, plaques, etc.)."""
    path = DATA_DIR / "object_database.json"
    if not path.exists():
        print("Warning: object_database.json not found, skipping objects")
        return []

    with open(path, encoding="utf-8") as f:
        db = json.load(f)

    items = []
    for obj_id, obj in db["entries"].items():
        name = obj.get("name", "").strip()
        if not name:
            continue

        obj_type = obj.get("type", "")

        if obj_type == "book" and "pages" in obj:
            # Multi-page book
            for i, page_text in enumerate(obj["pages"], 1):
                page_text = page_text.strip()
                if not page_text:
                    continue
                key_str = f"{name}_page{i}"
                items.append({
                    "npc_name": name,
                    "race": "Narrator",
                    "sex": "unknown",
                    "dialog_type": f"book_p{i}",
                    "key_str": key_str,
                    "text": page_text,
                    "source": "object",
                    "source_id": obj_id,
                })
        else:
            # Single-page content (plaque, sign, etc.)
            content = obj.get("content", "").strip()
            if not content:
                continue
            key_str = f"{name}_page1"
            items.append({
                "npc_name": name,
                "race": "Narrator",
                "sex": "unknown",
                "dialog_type": "book_p1",
                "key_str": key_str,
                "text": content,
                "source": "object",
                "source_id": obj_id,
            })

    return items


def build_manual_items(npc_map):
    """Build work items from manual_entries.json."""
    path = DATA_DIR / "manual_entries.json"
    if not path.exists():
        print("Warning: manual_entries.json not found, skipping manual entries")
        return []

    with open(path, encoding="utf-8") as f:
        db = json.load(f)

    items = []
    for entry in db.get("entries", []):
        entry_type = entry.get("type", "")
        text = entry.get("text", "").strip()
        if not text:
            continue

        if entry_type == "gossip":
            npc_name = entry.get("npc", "").strip()
            # Race/sex: explicit override or auto-resolve from npc_database
            race = entry.get("race")
            sex = entry.get("sex")
            if not race and npc_name and npc_name in npc_map:
                race, sex = npc_map[npc_name]
            elif not race:
                race, sex = "Narrator", "unknown"
            if not sex:
                sex = "unknown"
            # Key: normalized text (we control both sides)
            norm_text = re.sub(r"[^a-z0-9]", "", text.lower())[:50]
            key_str = norm_text
            items.append({
                "npc_name": npc_name or "unknown",
                "race": race,
                "sex": sex,
                "dialog_type": "gossip",
                "key_str": key_str,
                "text": text,
                "source": "manual",
                "source_id": entry.get("id", ""),
            })

        elif entry_type == "quest_greeting":
            npc_name = entry.get("npc", "").strip()
            race = entry.get("race")
            sex = entry.get("sex")
            if not race and npc_name and npc_name in npc_map:
                race, sex = npc_map[npc_name]
            elif not race:
                race, sex = "Narrator", "unknown"
            if not sex:
                sex = "unknown"
            key_str = entry.get("key", npc_name or "unknown")
            items.append({
                "npc_name": npc_name or "unknown",
                "race": race,
                "sex": sex,
                "dialog_type": "quest_greeting",
                "key_str": key_str,
                "text": text,
                "source": "manual",
                "source_id": entry.get("id", ""),
            })

        elif entry_type == "item_text":
            name = entry.get("name", "").strip()
            page = entry.get("page", 1)
            key_str = f"{name}_page{page}"
            items.append({
                "npc_name": name or "unknown",
                "race": "Narrator",
                "sex": "unknown",
                "dialog_type": f"item_p{page}",
                "key_str": key_str,
                "text": text,
                "source": "manual",
                "source_id": entry.get("id", ""),
            })

    return items


def compute_output_path(item):
    """Compute the output .wav path for a work item."""
    race_lower = item["race"].lower().replace(" ", "_") if item["race"] else "narrator"
    name_norm = normalize_name(item["npc_name"])
    hash_hex = djb2_hash(item["key_str"])
    dialog_type = item["dialog_type"]
    return SOUNDS_DIR / race_lower / name_norm / f"{dialog_type}_{hash_hex}.wav"


def voice_anchor_path(item):
    """Path to the voice anchor file for an NPC."""
    race_lower = item["race"].lower().replace(" ", "_") if item["race"] else "narrator"
    name_norm = normalize_name(item["npc_name"])
    return SOUNDS_DIR / race_lower / name_norm / ".voice_anchor.wav"


# ─── TTS generation ──────────────────────────────────────────────────────
def check_server(server_url):
    """Check if Fish Speech API server is reachable. Returns the URL or exits."""
    try:
        r = requests.get(f"{server_url}/v1/health", timeout=5)
        r.raise_for_status()
        print(f"Fish Speech API server OK at {server_url}")
        return server_url
    except requests.ConnectionError:
        print(f"Error: Fish Speech API server not reachable at {server_url}")
        print("Start with: cd fish-speech && python tools/api_server.py --device cuda")
        sys.exit(1)
    except Exception as e:
        print(f"Error connecting to Fish Speech API: {e}")
        sys.exit(1)


def _build_references(speaker_wavs, max_duration=60.0, per_clip_max=12.0):
    """Build API reference list from WAV file paths.

    Returns list of dicts with base64-encoded audio and empty text.
    Fish Speech supports audio-only voice cloning without transcripts.

    Limits total reference audio to max_duration seconds. At ~21.5 tokens/sec,
    60s ≈ 1290 tokens — well within the 4096 KV cache cap.

    Each clip is trimmed to at most per_clip_max seconds (taken from the
    center of the clip, where speech is most representative). Longer clips
    give the model richer prosodic context (sentence flow, natural pauses)
    for better cloning quality.
    """
    references = []
    total_seconds = 0.0
    for wav_path in speaker_wavs:
        try:
            with wave.open(str(wav_path), 'rb') as wf:
                nframes = wf.getnframes()
                framerate = wf.getframerate()
                nchannels = wf.getnchannels()
                sampwidth = wf.getsampwidth()
                dur = nframes / framerate
        except Exception:
            continue

        budget_left = max_duration - total_seconds
        if budget_left <= 0.5:
            break

        # Determine how much of this clip to use
        use_seconds = min(dur, per_clip_max, budget_left)

        if use_seconds >= dur - 0.1:
            # Clip is short enough — use the whole thing
            audio_bytes = Path(wav_path).read_bytes()
            actual_dur = dur
        else:
            # Extract the center portion of the clip
            use_frames = int(use_seconds * framerate)
            start_frame = (nframes - use_frames) // 2
            with wave.open(str(wav_path), 'rb') as wf:
                wf.setpos(start_frame)
                raw = wf.readframes(use_frames)
            # Re-encode as a valid WAV in memory
            buf = io.BytesIO()
            with wave.open(buf, 'wb') as out_wf:
                out_wf.setnchannels(nchannels)
                out_wf.setsampwidth(sampwidth)
                out_wf.setframerate(framerate)
                out_wf.writeframes(raw)
            audio_bytes = buf.getvalue()
            actual_dur = use_seconds

        references.append({
            "audio": base64.b64encode(audio_bytes).decode("ascii"),
            "text": "",
        })
        total_seconds += actual_dur
    return references


# ─── ALL CAPS emphasis injection ──────────────────────────────────────────────
_ROMAN_RE = re.compile(r'^[IVXivx]+$')
_CAPS_RUN_RE = re.compile(r'\b([A-Z]{2,}(?:\s+[A-Z]{2,})*)\b')
_TAG_RE = re.compile(r'\[[^\]]+\]')


def _inject_caps_emphasis(text):
    """Insert [emphasis] before ALL CAPS sequences that lack nearby emotion tags.

    Fish Speech's normalize=True lowercases text, losing ALL CAPS emphasis.
    This preserves authorial intent by injecting [emphasis] tags.
    Skips: roman numerals, pure-consonant abbreviations, contractions.
    """
    orig = text  # keep original for pre-text lookups

    def _should_tag(m):
        caps = m.group(1)
        words = caps.split()
        # Skip roman numerals (II, III, IV, IX, etc.)
        if len(words) == 1 and _ROMAN_RE.match(caps):
            return m.group(0)
        # Skip single short words (2 chars) — likely abbreviations (SI, BS, NG)
        if len(words) == 1 and len(caps) <= 2:
            return m.group(0)
        # Skip single words with no vowel — abbreviations (FTZ, XT, etc.)
        if len(words) == 1 and not re.search(r'[AEIOU]', caps):
            return m.group(0)
        # Skip contractions (DON'T → regex matched "DON")
        if m.end() < len(orig) and orig[m.end()] == "'":
            return m.group(0)
        # Skip if there's already a [tag] within 30 chars before
        pre_start = max(0, m.start() - 30)
        pre_text = orig[pre_start:m.start()]
        if _TAG_RE.search(pre_text):
            return m.group(0)
        return f'[emphasis] {caps}'

    return _CAPS_RUN_RE.sub(_should_tag, text)


def _tts_request(server_url, text, references, output_path,
                 temperature=0.8, repetition_penalty=1.1, top_p=0.8,
                 seed=None, chunk_length=200, max_new_tokens=2048):
    """Send a single TTS request to Fish Speech API server."""
    # Collapse newlines/paragraph breaks to single space — they cause
    # audio artifacts (slithering/pauses).
    text = re.sub(r'\s*\n+\s*', ' ', text).strip()
    # Inject [emphasis] before ALL CAPS words/phrases for vocal stress.
    text = _inject_caps_emphasis(text)
    payload = {
        "text": text,
        "references": references,
        "temperature": temperature,
        "repetition_penalty": repetition_penalty,
        "top_p": top_p,
        "format": "wav",
        "chunk_length": chunk_length,
        "max_new_tokens": max_new_tokens,
        "use_memory_cache": "on",
        "streaming": False,
        "normalize": True,
    }
    if seed is not None:
        payload["seed"] = seed

    r = requests.post(
        f"{server_url}/v1/tts",
        json=payload,
        headers={"content-type": "application/json"},
        timeout=300,
    )
    r.raise_for_status()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(r.content)


def generate_one(server_url, text, speaker_wavs, output_path, temperature=0.8,
                 repetition_penalty=1.1, top_p=0.8, seed=None,
                 chunk_length=200, max_new_tokens=2048):
    """Generate a single voice line via Fish Speech API.

    Args:
        server_url: Fish Speech API server URL
        text: Text to speak
        speaker_wavs: List of Path objects for reference audio
        output_path: Where to write the output .wav
        temperature: Generation temperature (0.1-1.0, higher = more expressive)
        repetition_penalty: Penalize repeated patterns (0.9-2.0)
        top_p: Nucleus sampling threshold (0.1-1.0)
        seed: Deterministic seed (None = random)
        chunk_length: Text chunk length for synthesis (100-1000)
        max_new_tokens: Maximum tokens to generate
    """
    output_path.parent.mkdir(parents=True, exist_ok=True)
    references = _build_references(speaker_wavs)

    _tts_request(server_url, text, references, output_path,
                 temperature=temperature,
                 repetition_penalty=repetition_penalty,
                 top_p=top_p, seed=seed,
                 chunk_length=chunk_length,
                 max_new_tokens=max_new_tokens)


# ─── Voice manifest generation ───────────────────────────────────────────
def generate_manifest(generated_files):
    """Write data/voice_manifest.lua with path → duration mapping."""
    manifest_path = DATA_DIR / "voice_manifest.lua"

    lines = [
        "-- Auto-generated voice manifest for Turtle's Epoch",
        "-- Maps sound path → duration in seconds",
        f"-- {len(generated_files)} voice files",
        "-- DO NOT EDIT MANUALLY — regenerate with: python scripts/generate_voice.py",
        "",
        "TT_VOICE_MANIFEST = {",
    ]

    for wav_path in sorted(generated_files):
        try:
            duration = get_wav_duration(wav_path)
        except Exception as e:
            print(f"  Warning: cannot read duration for {wav_path}: {e}")
            continue

        # Convert to addon-relative path with escaped backslashes for Lua string literals
        # Lua 5.0 interprets \X as escape sequences — we need \\ in the .lua source
        # so the runtime string contains single backslashes
        # Always use .ogg extension — wav files are converted to ogg before deployment
        rel = wav_path.relative_to(PROJECT_ROOT).with_suffix(".ogg")
        wow_path = str(rel).replace("/", "\\\\")
        full_wow_path = f"Interface\\\\AddOns\\\\TurtlesEpoch\\\\{wow_path}"
        lines.append(f'  ["{full_wow_path}"] = {duration:.3f},')

    lines.append("}")
    lines.append("")

    manifest_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"Voice manifest written: {manifest_path} ({len(generated_files)} entries)")


def to_wow_sound_path(wav_path):
    """Convert a project file path to the addon path used at runtime."""
    rel = wav_path.relative_to(PROJECT_ROOT)
    wow_path = str(rel).replace("/", "\\")
    return f"Interface\\AddOns\\TurtlesEpoch\\{wow_path}"


def lua_quote(text):
    """Quote a Python string as a valid Lua double-quoted string literal."""
    text = text.replace("\\", "\\\\")
    text = text.replace('"', '\\"')
    text = text.replace("\n", "\\n")
    text = text.replace("\r", "\\r")
    text = text.replace("\t", "\\t")
    return f'"{text}"'


def normalize_lookup_title(title):
    """Normalize quest title for resilient runtime remapping."""
    title = title.lower().strip()
    title = re.sub(r"\|c[0-9a-f]{8}", "", title)
    title = title.replace("|r", "")
    title = re.sub(r"[^a-z0-9\s]", " ", title)
    title = re.sub(r"\s+", " ", title).strip()
    return title


def normalize_lookup_text_sig(text):
    """Normalize quest detail text to a compact signature key.

    Resolves $G male:female; tokens to the male form so the sig matches the
    runtime text WoW substitutes for male players (the male form is also what
    text_sub.py uses when generating voiced audio). Female-player matches fall
    through to the NPC-index last-resort fallback in EventHandler.lua.
    """
    # $G a:b; → a (male form). Six occurrences across the database.
    text = re.sub(r"\$[Gg]\s*([^:;]*?)\s*:\s*[^;]*;", r"\1", text)
    text = text.lower().strip()
    text = re.sub(r"\|c[0-9a-f]{8}", "", text)
    text = text.replace("|r", "")
    text = re.sub(r"[^a-z0-9\s]", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    # Prefix signature keeps lookup table compact while still distinctive.
    return text[:220]


def generate_quest_sound_lookup(quest_items):
    """Write quest title -> dialog type -> canonical sound path lookup."""
    lookup_path = DATA_DIR / "quest_sound_lookup.lua"
    lookup = {}
    norm_detail_lookup = {}
    # Per-dialog-type text-signature lookups.
    # Text content is unique per quest even when titles collide, so this
    # disambiguates same-title/same-NPC quest chains without needing GetQuestID().
    text_sig_by_type = {
        "quest_detail": {},
        "quest_complete": {},
        "quest_progress": {},
        "quest_greeting": {},
    }

    for item in quest_items:
        if item.get("source") != "quest":
            continue

        key_str = item.get("key_str", "")
        dialog_type = item.get("dialog_type", "")
        if not key_str or not dialog_type:
            continue

        # key_str is "title_questID" — use it as the lookup key as-is,
        # but also derive the raw title (without _questID suffix) for the
        # norm_title lookup which must work without knowing the quest ID.
        source_id = item.get("source_id", "")
        raw_title = key_str
        if source_id:
            suffix = "_" + str(source_id)
            if raw_title.endswith(suffix):
                raw_title = raw_title[:-len(suffix)]

        title = key_str  # keep original variable for TT_QUEST_SOUND_LOOKUP keys

        title_map = lookup.setdefault(title, {})
        # Use .ogg extension for all paths
        sound_path = to_wow_sound_path(compute_output_path(item).with_suffix(".ogg"))
        if dialog_type not in title_map:
            title_map[dialog_type] = sound_path

            if dialog_type == "quest_detail":
                norm_title = normalize_lookup_title(raw_title)
                # Always overwrite so the last (highest quest_id) wins for same-title quests
                if norm_title:
                    norm_detail_lookup[norm_title] = sound_path

        # Build text-sig lookup for all quest dialog types.
        # Store a LIST of paths so multi-giver quests (AQ war effort etc.)
        # can be disambiguated by NPC folder at runtime.
        if dialog_type in text_sig_by_type:
            text_sig = normalize_lookup_text_sig(item.get("text", ""))
            if text_sig:
                bucket = text_sig_by_type[dialog_type].setdefault(text_sig, [])
                if sound_path not in bucket:
                    bucket.append(sound_path)

    lines = [
        "-- Auto-generated quest title -> canonical sound path lookup for Turtle's Epoch",
        "-- Used for item-started quests and other no-NPC quest UI flows",
        f"-- {len(lookup)} quest titles",
        "-- DO NOT EDIT MANUALLY — regenerate with: python scripts/generate_voice.py",
        "",
        "TT_QUEST_SOUND_LOOKUP = {",
    ]

    for title in sorted(lookup):
        lines.append(f"  [{lua_quote(title)}] = {{")
        dialog_map = lookup[title]
        for dialog_type in sorted(dialog_map):
            lines.append(f"    {dialog_type} = {lua_quote(dialog_map[dialog_type])},")
        lines.append("  },")

    lines.append("}")
    lines.append("")
    lines.append("TT_QUEST_DETAIL_BY_NORM_TITLE = {")
    for norm_title in sorted(norm_detail_lookup):
        lines.append(f"  [{lua_quote(norm_title)}] = {lua_quote(norm_detail_lookup[norm_title])},")
    lines.append("}")

    for dt_name, lua_var in [
        ("quest_detail",   "TT_QUEST_DETAIL_BY_TEXTSIG"),
        ("quest_complete", "TT_QUEST_COMPLETE_BY_TEXTSIG"),
        ("quest_progress", "TT_QUEST_PROGRESS_BY_TEXTSIG"),
        ("quest_greeting", "TT_QUEST_GREETING_BY_TEXTSIG"),
    ]:
        lines.append("")
        lines.append(f"{lua_var} = {{")
        for text_sig in sorted(text_sig_by_type[dt_name]):
            paths = text_sig_by_type[dt_name][text_sig]
            if len(paths) == 1:
                # Backwards-compatible: single path stored as string
                lines.append(f"  [{lua_quote(text_sig)}] = {lua_quote(paths[0])},")
            else:
                # Multi-giver quest: list of paths, runtime picks by NPC folder
                items = ", ".join(lua_quote(p) for p in paths)
                lines.append(f"  [{lua_quote(text_sig)}] = {{ {items} }},")
        lines.append("}")
    lines.append("")

    lookup_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"Quest sound lookup written: {lookup_path} ({len(lookup)} titles)")


# ─── Main ─────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="Turtle's Epoch batch voice generator"
    )
    parser.add_argument(
        "--source", choices=["quests", "objects", "manual", "all"],
        default="all", help="Which data source to generate from (default: all)"
    )
    parser.add_argument(
        "--quest-id", type=int, default=None,
        help="Generate voices for a specific quest ID only"
    )
    parser.add_argument(
        "--npc", type=str, action="append", default=None,
        help="Generate voices for a specific NPC name only (repeatable, case-insensitive substring match)"
    )
    parser.add_argument(
        "--race", type=str, action="append", default=None,
        help="Filter by normalized race (repeatable, case-insensitive, e.g. Orc, Furbolg, Narrator)"
    )
    parser.add_argument(
        "--missing-only", action="store_true",
        help="Only generate voices for missing .wav files"
    )
    parser.add_argument(
        "--force", action="store_true",
        help="Regenerate all (deletes voice anchors for affected NPCs)"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Preview what would be generated without running TTS"
    )
    parser.add_argument(
        "--temperature", type=float, default=None,
        help="Override generation temperature (0.1-1.0, default: per-NPC variation 0.65-0.85)"
    )
    parser.add_argument(
        "--repetition-penalty", type=float, default=1.1,
        help="Repetition penalty (default: 1.1, range 0.9-2.0)"
    )
    parser.add_argument(
        "--top-p", type=float, default=0.8,
        help="Nucleus sampling threshold (default: 0.8, range 0.1-1.0)"
    )
    parser.add_argument(
        "--server-url", type=str, default=DEFAULT_SERVER_URL,
        help=f"Fish Speech API server URL (default: {DEFAULT_SERVER_URL})"
    )
    parser.add_argument(
        "--chunk-length", type=int, default=DEFAULT_CHUNK_LENGTH,
        help=f"Text chunk length for synthesis (default: {DEFAULT_CHUNK_LENGTH}, range 100-1000)"
    )
    parser.add_argument(
        "--max-new-tokens", type=int, default=DEFAULT_MAX_NEW_TOKENS,
        help=f"Maximum tokens to generate (default: {DEFAULT_MAX_NEW_TOKENS}, 0 = no limit)"
    )
    parser.add_argument(
        "--manifest-only", action="store_true",
        help="Only regenerate voice_manifest.lua from existing .wav files"
    )
    parser.add_argument(
        "--emotions", action="store_true", default=False,
        help="Use emotion-tagged text from emotion cache (run emotion_tagger.py first)"
    )
    parser.add_argument(
        "--no-emotions", action="store_true",
        help="Explicitly disable emotion tags even if cache exists"
    )
    args = parser.parse_args()

    # ── Manifest-only mode ────────────────────────────────────────────
    if args.manifest_only:
        print("Scanning for existing .wav and .ogg files...")
        all_wavs = sorted(SOUNDS_DIR.rglob("*.wav")) + sorted(SOUNDS_DIR.rglob("*.ogg"))
        # Exclude voice anchors
        all_wavs = [p for p in all_wavs if p.stem != ".voice_anchor"]
        print(f"Found {len(all_wavs)} voice files")
        npc_map = load_npc_database()
        generate_quest_sound_lookup(build_quest_items(npc_map))
        generate_manifest(all_wavs)
        return

    # ── Load data ─────────────────────────────────────────────────────
    print("Loading NPC database...")
    npc_map = load_npc_database()
    print(f"  {len(npc_map)} NPCs loaded")

    player_config = load_player_config()

    # ── Load emotion cache ────────────────────────────────────────────
    emotion_cache = {}
    use_emotions = args.emotions and not args.no_emotions
    if use_emotions:
        emotion_cache = load_emotion_cache()
        if emotion_cache:
            print(f"  Emotion cache: {len(emotion_cache)} tagged entries loaded")
        else:
            print("  Emotion cache: empty (run emotion_tagger.py first, or use --no-emotions)")
            use_emotions = False

    # ── Build work items ──────────────────────────────────────────────
    items = []
    if args.source in ("quests", "all"):
        quest_items = build_quest_items(npc_map, quest_id_filter=args.quest_id)
        items.extend(quest_items)
        print(f"  Quests: {len(quest_items)} voice lines")

    if args.source in ("objects", "all") and not args.quest_id:
        object_items = build_object_items()
        items.extend(object_items)
        print(f"  Objects: {len(object_items)} voice lines")

    if args.source in ("manual", "all") and not args.quest_id and not args.npc:
        manual_items = build_manual_items(npc_map)
        items.extend(manual_items)
        print(f"  Manual: {len(manual_items)} voice lines")

    # ── Filter: --npc ─────────────────────────────────────────────
    if args.npc:
        npc_filters = [n.lower() for n in args.npc]
        items = [item for item in items if any(f in item["npc_name"].lower() for f in npc_filters)]
        print(f"  Filtered to {len(args.npc)} NPC(s): {len(items)} voice lines")

    # ── Filter: --race ────────────────────────────────────────────
    if args.race:
        race_filters = [r.lower() for r in args.race]
        items = [item for item in items if item["race"].lower() in race_filters]
        print(f"  Filtered to race(s) {', '.join(args.race)}: {len(items)} voice lines")

    if not items:
        print("No work items to generate.")
        return

    print(f"\nTotal: {len(items)} voice lines to process")

    # ── Filter: missing-only ──────────────────────────────────────────
    if args.missing_only:
        before = len(items)
        items = [item for item in items
                 if not compute_output_path(item).exists()
                 and not compute_output_path(item).with_suffix(".ogg").exists()]
        print(f"  After --missing-only filter: {len(items)} (skipped {before - len(items)} existing)")

    if not items:
        print("All voice files already exist. Nothing to generate.")
        return

    # ── Dry run ───────────────────────────────────────────────────────
    if args.dry_run:
        print(f"\n=== DRY RUN: {len(items)} voice lines ===\n")

        # Summarize by race
        from collections import Counter
        race_counts = Counter(item["race"] for item in items)
        source_counts = Counter(item["source"] for item in items)
        dialog_counts = Counter(item["dialog_type"] for item in items)

        print("By race:")
        for race, count in race_counts.most_common():
            print(f"  {race}: {count}")

        print("\nBy source:")
        for source, count in source_counts.most_common():
            print(f"  {source}: {count}")

        print("\nBy dialog type:")
        for dt, count in dialog_counts.most_common():
            print(f"  {dt}: {count}")

        # Show first 10 items
        print(f"\nFirst 10 items:")
        for item in items[:10]:
            out_path = compute_output_path(item)
            print(f"  {out_path.relative_to(PROJECT_ROOT)}")
            print(f"    NPC: {item['npc_name']} | Race: {item['race']} | Sex: {item['sex']}")
            print(f"    Text: {item['text'][:80]}...")
        return

    # ── Initialize TTS ────────────────────────────────────────────────
    server_url = check_server(args.server_url)

    # Load narrator samples for stage direction segments
    narrator_samples = get_sample_files(SAMPLES_DIR / "narrator")
    if not narrator_samples:
        print("  WARNING: No narrator samples found — stage directions will use NPC voice")

    # ── Group items by NPC for voice anchor management ────────────────
    from collections import defaultdict
    npc_items = defaultdict(list)
    for item in items:
        npc_key = (item["npc_name"], item["race"], item["sex"])
        npc_items[npc_key].append(item)

    print(f"\n{len(npc_items)} unique NPCs to voice")

    # ── Generate ──────────────────────────────────────────────────────
    generated_files = []
    total = len(items)
    done = 0
    errors = 0

    for (npc_name, race, sex), npc_work in npc_items.items():
        npc_seed = int(djb2_hash(npc_name), 16)
        is_custom = npc_name in TIER3_NPCS

        # Resolve voice profile
        sample_dir, is_custom_profile = resolve_voice_profile(npc_name, race, sex)
        sample_files = get_sample_files(sample_dir)

        if not sample_files:
            print(f"  WARNING: No samples for {npc_name} ({race}/{sex}) in {sample_dir}")
            done += len(npc_work)
            errors += len(npc_work)
            continue

        # Resolve voice config profile (donor voice + post-processing effects)
        config_key = resolve_config_key(npc_name, race, sex, sample_dir, TIER3_NPCS)

        # Donor voice: if config specifies a donor, use donor's samples for TTS
        donor_dir = get_donor_samples_dir(config_key) if config_key else None
        if donor_dir:
            donor_files = get_sample_files(donor_dir)
            if donor_files:
                print(f"  Using donor voice: {donor_dir.relative_to(SAMPLES_DIR)} → {config_key}")
                sample_files = donor_files
            else:
                print(f"  WARNING: Donor dir {donor_dir} has no .wav files, using own samples")

        # Select samples for this NPC
        selected_samples = select_samples_for_npc(sample_files, npc_seed, is_custom_profile)
        temp = args.temperature if args.temperature is not None else npc_temperature(npc_seed, is_custom_profile)

        # Voice anchor handling
        anchor = voice_anchor_path(npc_work[0])

        if args.force and anchor.exists():
            anchor.unlink()

        # If anchor exists, use it as reference for all lines
        if anchor.exists():
            reference_wavs = [anchor]
        else:
            reference_wavs = selected_samples

        for i, item in enumerate(npc_work):
            done += 1
            out_path = compute_output_path(item)

            # Skip existing unless --force
            if out_path.exists() and not args.force:
                generated_files.append(out_path)
                continue

            # Apply emotion tags from cache first (before substitution,
            # so cache stays player-config-independent)
            clean_text = item["text"]
            if use_emotions and emotion_cache:
                clean_text = get_tagged_text(
                    emotion_cache, item.get("source", "quest"),
                    item.get("source_id", "0"), item["dialog_type"],
                    clean_text
                )

            # Substitute player markers in text (<name>, $G, etc.)
            clean_text = substitute_text(clean_text, player_config)
            clean_text = clean_text.strip()
            if not clean_text:
                continue

            progress = f"[{done}/{total}]"
            print(f"  {progress} {out_path.relative_to(PROJECT_ROOT)}")

            try:
                segments = split_narrator_segments(clean_text)
                has_narrator = any(is_narr for _, is_narr in segments)

                if not has_narrator or not narrator_samples:
                    # Pure NPC voice — no segmentation needed
                    generate_one(server_url, clean_text, reference_wavs, out_path,
                                temperature=temp,
                                repetition_penalty=args.repetition_penalty,
                                top_p=args.top_p,
                                seed=npc_seed,
                                chunk_length=args.chunk_length,
                                max_new_tokens=args.max_new_tokens)

                    # Voice anchor from pure NPC line (saved clean, before effects)
                    if not anchor.exists() and not is_custom_profile:
                        anchor.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(out_path, anchor)
                        reference_wavs = [anchor]

                    # Apply post-processing effects (pitch shift, reverb, EQ)
                    apply_voice_effects(out_path, config_key)

                    # Normalize loudness for consistent volume across all clips
                    normalize_loudness(out_path)

                    # Convert WAV → OGG inline; no separate conversion step needed
                    out_path = wav_to_ogg(out_path)
                    generated_files.append(out_path)

                else:
                    # Mixed NPC + narrator segments
                    npc_segs = sum(1 for _, n in segments if not n)
                    narr_segs = sum(1 for _, n in segments if n)
                    print(f"    → {len(segments)} segments ({npc_segs} NPC, {narr_segs} narrator)")

                    temp_wavs = []
                    for seg_idx, (seg_text, is_narrator) in enumerate(segments):
                        seg_text = seg_text.strip()
                        if not seg_text:
                            continue
                        tmp_path = out_path.parent / f".seg_{out_path.stem}_{seg_idx}.wav"
                        if is_narrator:
                            print(f"      [NARRATOR] {seg_text[:60]}{'...' if len(seg_text) > 60 else ''}")
                            generate_one(server_url, seg_text, narrator_samples, tmp_path,
                                        temperature=0.75,
                                        repetition_penalty=args.repetition_penalty,
                                        top_p=args.top_p,
                                        chunk_length=args.chunk_length,
                                        max_new_tokens=args.max_new_tokens)
                        else:
                            print(f"      [NPC] {seg_text[:60]}{'...' if len(seg_text) > 60 else ''}")
                            generate_one(server_url, seg_text, reference_wavs, tmp_path,
                                        temperature=temp,
                                        repetition_penalty=args.repetition_penalty,
                                        top_p=args.top_p,
                                        seed=npc_seed,
                                        chunk_length=args.chunk_length,
                                        max_new_tokens=args.max_new_tokens)
                            # Save first NPC segment as voice anchor (clean, before effects)
                            if not anchor.exists() and not is_custom_profile:
                                anchor.parent.mkdir(parents=True, exist_ok=True)
                                shutil.copy2(tmp_path, anchor)
                                reference_wavs = [anchor]
                            # Apply post-processing to NPC segment
                            apply_voice_effects(tmp_path, config_key)

                        # Normalize each segment individually so NPC and narrator
                        # segments enter the concat at matched loudness levels
                        normalize_loudness(tmp_path)
                        temp_wavs.append(tmp_path)

                    if temp_wavs:
                        concatenate_wavs(temp_wavs, out_path)
                    # Clean up temp segment files
                    for tmp in temp_wavs:
                        tmp.unlink(missing_ok=True)

                    # Convert concatenated WAV → OGG inline
                    if out_path.exists():
                        out_path = wav_to_ogg(out_path)
                    generated_files.append(out_path)

            except Exception as e:
                # Clean up any leftover temp files on error
                for tmp in out_path.parent.glob(f".seg_{out_path.stem}_*.wav"):
                    tmp.unlink(missing_ok=True)
                print(f"    ERROR: {e}")
                errors += 1

    # ── Summary ───────────────────────────────────────────────────────
    print(f"\n=== Generation complete ===")
    print(f"  Generated: {len(generated_files)}")
    print(f"  Errors: {errors}")
    print(f"  Total processed: {done}")

    # ── Cleanup ────────────────────────────────────────────────────
    clear_config_cache()

    # ── Write voice manifest ──────────────────────────────────────────
    if generated_files:
        # Include ALL existing ogg + wav files, not just newly generated ones
        all_files = sorted(SOUNDS_DIR.rglob("*.ogg")) + sorted(SOUNDS_DIR.rglob("*.wav"))
        all_files = [p for p in all_files if p.stem != ".voice_anchor"]
        generate_quest_sound_lookup(build_quest_items(npc_map))
        generate_manifest(all_files)


if __name__ == "__main__":
    main()
