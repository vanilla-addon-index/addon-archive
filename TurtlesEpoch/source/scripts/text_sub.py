#!/usr/bin/env python3
"""
TurtleTongue Text Substitution Utility

Replaces WoW player markers in quest/gossip text with values from player_config.json.

Markers handled:
  <name>  → player character name (or "adventurer" if not configured)
  <class> → player class (or "hero")
  <race>  → player race (or "traveler")
  $N/$n   → same as <name> (raw format, sometimes not converted by website)
  $C/$c   → same as <class>
  $R/$r   → same as <race>
  $B/$b   → line break (stripped for TTS)
  $Gmale:female; → gender-dependent text (picks based on player gender)
  $NNNNw  → item count references (dynamic, stripped for TTS)
  <grin>, <cough>, etc. → emote markers (stage directions, stripped for TTS)

Usage:
    from scripts.text_sub import substitute_text, load_player_config

    config = load_player_config()
    clean = substitute_text("Hello <name>, brave <class>!", config)
    # → "Hello Arthas, brave Paladin!"
"""

import html
import json
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
CONFIG_PATH = PROJECT_ROOT / "data" / "player_config.json"

DEFAULTS = {
    "name": "adventurer",
    "class": "hero",
    "race": "traveler",
    "gender": "male",
}

# Emote markers — single-word cues like <grin>, <cough>, etc.
# These are stripped for TTS. Multi-word stage directions are preserved
# (e.g. <Myzrael speaks.>) and routed to narrator voice in generate_voice.py.
EMOTE_MARKERS = {
    "grin", "cough", "sigh", "laugh", "chuckle", "snort", "hiccup",
    "burp", "roar", "growl", "hiss", "snarl", "sob", "cry", "gasp",
    "yawn", "sneeze", "wink", "nod", "shrug", "flex", "bow",
    "salute", "wave", "point", "clap", "cheer", "dance",
    # Variant/plural forms found in quest data
    "weeze", "mutters", "hic", "drool", "coughs", "laughs",
}


# HTML tags that should always be stripped during text cleanup.
HTML_TAGS = {
    "a", "b", "br", "center", "div", "em", "font", "hr", "i", "img",
    "li", "ol", "p", "small", "span", "strong", "table", "td", "th",
    "tr", "u", "ul",
}


def load_player_config():
    """Load player config, falling back to defaults for missing fields."""
    config = dict(DEFAULTS)
    if CONFIG_PATH.exists():
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            saved = json.load(f)
        config.update(saved)
    return config


def _html_tag_replace(match):
    """Replace HTML-like tags.

    - Strip real HTML markup (<BR>, <IMG ...>, </FONT>, etc.)
    - Strip known one-word emote cues (<grin>, <cough>, ...)
    - Preserve stage-direction content in angle brackets for narrator splitting
      (e.g. <Myzrael speaks.>)
    """
    tag = match.group(0)

    # Closing tags are HTML by definition.
    if re.match(r"^<\s*/", tag):
        return ""

    # Tags with attributes (<IMG src=...>, <FONT color=...>) are HTML.
    if re.search(r"\w+\s*=", tag):
        return ""

    # Single-word bracket tags: could be emote, HTML, or placeholders.
    inner = re.match(r"^<\s*([A-Za-z][\w-]*)\s*/?\s*>$", tag)
    if inner:
        emote = inner.group(1).lower()
        if emote in EMOTE_MARKERS:
            return ""
        if emote in HTML_TAGS:
            return ""
        # Leave unrecognized single-word markers as-is (e.g. <name>)
        return tag

    # Multi-word <...> blocks are treated as stage directions and preserved.
    return tag


def substitute_text(text, config=None):
    """
    Replace all player markers in text with configured values.

    Args:
        text: Raw quest/gossip text with markers
        config: Player config dict (loaded from player_config.json if None)

    Returns:
        Text ready for TTS generation
    """
    if config is None:
        config = load_player_config()

    name = config.get("name", DEFAULTS["name"])
    cls = config.get("class", DEFAULTS["class"])
    race = config.get("race", DEFAULTS["race"])
    gender = config.get("gender", DEFAULTS["gender"])

    # Replace <name>, <class>, <race> (case-insensitive)
    text = re.sub(r"<name>", name, text, flags=re.IGNORECASE)
    text = re.sub(r"<class>", cls, text, flags=re.IGNORECASE)
    text = re.sub(r"<race>", race, text, flags=re.IGNORECASE)

    # Replace raw $N/$C/$R/$B markers (sometimes not converted by website)
    text = text.replace("$N", name).replace("$n", name)
    text = text.replace("$C", cls).replace("$c", cls)
    text = text.replace("$R", race).replace("$r", race)
    text = text.replace("$B", " ").replace("$b", " ")

    # Handle $G gender markers: $Gmale_form:female_form; or $Gmale_form:female_form,
    # Tolerates: missing semicolons ($Gboy:girl,), spaces ($G Brother : Sister;),
    # lowercase ($gman:woman)
    def _gender_replace(match):
        male_form = match.group(1).strip()
        female_form = match.group(2).strip()
        return female_form if gender == "female" else male_form

    text = re.sub(r"\$[Gg]\s*([^:;]+?)\s*:\s*([^;,]+?)\s*[;,]", _gender_replace, text)

    # Replace $NNNNw item count references with natural placeholder
    # These are dynamic server-side values (e.g. "$2071w thick leather" = "many thick leather")
    text = re.sub(r"\$\d+w", "many", text)

    # Strip all remaining $ signs — by this point all legitimate markers ($G, $N, $C, $R, $B,
    # $NNNNw) have been processed. Any leftover $ is a crawl artifact (e.g. "$ Lieutenant")
    text = text.replace("$", "")

    # Strip HTML tags: <IMG src="..." />, <BR>, <HR>, <FONT ...>, etc.
    # These leak through from crawled book/object text (e.g. PvP rank badge images)
    text = re.sub(r"<[^>]+/?>", _html_tag_replace, text)

    # Decode HTML entities: &amp; → &, &lt; → <, etc.
    text = html.unescape(text)

    # Clean up extra whitespace
    text = re.sub(r"\s+", " ", text).strip()

    return text
