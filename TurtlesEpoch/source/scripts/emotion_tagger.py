#!/usr/bin/env python3
"""
TurtleTongue Emotion Tagger

Injects Fish Speech S2 emotion tags ([tag]) into quest/object text for expressive
voice generation. Tags are cached to disk so they survive voice regeneration.

Backends:
  - ollama: Local LLM via Ollama HTTP API (free, private, requires local model)
  - openai: OpenAI-compatible API (GPT-4o-mini etc., fast, costs money)
  - skip:   No tagging — raw text passed through (fastest, least expressive)

Cache:
  data/emotion_cache.json — maps cache_key → tagged text. One-time cost per text.
  Cache is NOT invalidated by --force in generate_voice.py — only by explicit
  --clear-cache or --retag flags here.

Usage:
    # Tag all quest texts using local Ollama
    python scripts/emotion_tagger.py --source quests --backend ollama --model glm-4.7-flash:latest

    # Tag a single quest
    python scripts/emotion_tagger.py --source quests --quest-id 4974 --backend ollama

    # Tag using OpenAI-compatible API
    python scripts/emotion_tagger.py --source quests --backend openai --model gpt-4o-mini

    # Preview what would be tagged (dry-run)
    python scripts/emotion_tagger.py --source quests --dry-run

    # Clear cache and retag
    python scripts/emotion_tagger.py --source quests --backend ollama --retag

    # Show cached tags for a quest
    python scripts/emotion_tagger.py --show --quest-id 4974

API usage (from generate_voice.py):
    from emotion_tagger import load_emotion_cache, get_tagged_text
    cache = load_emotion_cache()
    tagged = get_tagged_text(cache, "quest", 4974, "quest_detail", raw_text)
"""

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
DATA_DIR = PROJECT_ROOT / "data"
CACHE_PATH = DATA_DIR / "emotion_cache.json"

# ─── Fish Speech S2 emotion tags ─────────────────────────────────────────
# Official "Recommended Tags" from Fish Audio's inline tags guide:
#   https://fish.audio/blog/how-to-use-inline-tags-in-fish-audio-s2/
# These are well-tested and produce consistently strong results.
# Fish S2 also supports free-form tags but quality is less predictable.

# All official tags that we allow the LLM to use
ALLOWED_TAGS = {
    # Breathing & Vocal Reactions (official)
    "clears throat", "inhalation", "inhale", "exhale", "sigh",
    "panting", "breathing", "gasp",
    # Vocal Sounds (official)
    "groan", "moaning", "sobbing", "crying", "laughing",
    "chuckling", "giggle",
    # Pacing (official)
    "pause", "short pause", "long pause",
    # Voice Style (official)
    "whispering", "whispering voice", "soft voice", "low voice",
    "loud voice", "shouting",
    # Emotion (official)
    "excited", "angry", "sad",
    # From README "Rich Emotion Library" (official)
    "emphasis", "tsk", "singing", "laughing tone", "interrupting",
    "excited tone", "volume up", "echo", "low volume", "whisper",
    "screaming", "loud", "surprised", "delight", "volume down",
    "clearing throat", "shocked",
    # Free-form descriptors confirmed working in Fish docs/examples
    "whisper in small voice", "super happy",
    # WoW-appropriate free-form (natural language — Fish supports these)
    "commanding voice", "threatening voice", "mocking tone",
    "solemn voice", "gentle voice", "warm voice", "cold voice",
    "urgent voice", "hesitant voice", "confident voice",
    "proud voice", "defiant voice",
    # Short forms the LLM naturally produces — map to same Fish tags
    "commanding", "threatening", "solemn", "gentle", "warm",
    "cold", "urgent", "hesitant", "confident", "proud", "defiant",
}

# ─── LLM system prompt ──────────────────────────────────────────────────
SYSTEM_PROMPT = """You are an emotion tagger for a World of Warcraft text-to-speech system using Fish Speech S2.

Your task: Insert [tag] markers into quest dialogue text to guide expressive voice generation. Tags go INLINE directly before the text they affect. A tag's effect lasts until the next tag or end of text.

CRITICAL: The original text is SACRED. You must not change a single character of the original text.
Every word, space, punctuation mark, capitalization, and line break must remain exactly as given.
Your ONLY permitted action is inserting [tag] markers between existing words. Nothing else.

Rules:
1. Place [tag] before the phrase it should color. Don't over-tag — 1-4 tags per paragraph is ideal.
2. Tags are lowercase, inside square brackets. Tags are SHORT (1-3 words max).
3. NEVER modify, remove, rephrase, reorder, correct spelling, or add ANY words to the original text. Only INSERT [tag] markers. This includes trailing punctuation — if the text ends with "!" or "?" or ".", your output must end with that same character.
4. NEVER wrap sentences or phrases in square brackets. Brackets are ONLY for short emotion tags like [angry] or [soft voice]. WRONG: [Battle gear], [Haha...], [Mind your head], [Bear in mind]. These are original text words — they must NOT be in brackets.
5. Consider the speaker's race/role and the quest context for appropriate emotions.
6. Match the dramatic arc: quest descriptions often build tension, completions are often triumphant or grateful.
7. Use strong tags for exclamation marks (!), ALL CAPS, and dramatic moments.
8. Use subtle tags for exposition and lore passages.
9. For very short texts (1-2 sentences), one tag at the start is usually enough.
10. Return ONLY the tagged text, nothing else. No explanations, no markdown, no commentary.
11. You MUST only use tags from the approved list below. Do NOT invent new tags.
12. Preserve ALL angle-bracket markers like <name>, <race>, <class> EXACTLY as-is including the angle brackets. NEVER convert <name> to [name] or <class> to [class]. These are game placeholders, NOT tags.
13. NEVER change onomatopoeia, repeated characters, or unusual spellings (e.g. "Haha...", "whirrrr", "grrr", "Ooooh"). They are intentional.
14. Preserve ALL quotation marks exactly where they appear. If text starts with " it must remain.

=== APPROVED TAGS ===

Emotion: [angry], [sad], [excited], [surprised], [delight], [shocked]
Voice style: [whispering], [soft voice], [low voice], [loud voice], [shouting], [screaming]
Vocal reactions: [sigh], [gasp], [groan], [laughing], [chuckling], [sobbing], [crying]
Breathing: [inhale], [exhale], [panting], [clears throat]
Pacing: [pause], [short pause], [long pause], [emphasis]
Style: [commanding], [commanding voice], [threatening], [threatening voice], [mocking tone], [solemn], [solemn voice], [gentle], [gentle voice], [warm], [warm voice], [cold], [cold voice], [urgent], [urgent voice], [hesitant], [hesitant voice], [confident], [confident voice], [proud], [proud voice], [defiant], [defiant voice]

=== QUEST PATTERNS ===
- Battle/combat: [commanding], [shouting], [angry], [urgent]
- Lore/story: [solemn], [soft voice], [low voice], [pause]
- Reward/completion: [warm], [proud], [excited], [delight]
- Villain dialogue: [threatening], [cold], [mocking tone], [low voice]
- Sad/tragic: [sad], [soft voice], [sobbing], [sigh], [pause]
- Humor: [laughing], [chuckling], [excited], [mocking tone]

=== CORRECT EXAMPLE ===
Input: "The beast has been slain! You have saved our village, <name>."
Output: "[excited] The beast has been slain! [warm] You have saved our village, <name>."

=== WRONG (NEVER DO THIS) ===
[The beast has been slain! You have saved our village, <name>.]
^ WRONG: Do NOT wrap text inside brackets. Brackets are ONLY for short tags.

[Haha...] I never thought I'd see this day.
^ WRONG: "Haha..." is original text, not a tag. Write: [laughing] Haha... I never thought I'd see this day.

[class], listen closely.
^ WRONG: <class> is a game placeholder. Write: <class>, [solemn] listen closely.

[Mind your head]! I don't want it to get in the way!
^ WRONG: "Mind your head" is original text. Write: [shouting] Mind your head! I don't want it to get in the way!"""

USER_PROMPT_TEMPLATE = """Speaker: {npc_name} ({race}, {sex})
Dialog type: {dialog_type}
Quest title: {quest_title}

Text to tag:
{text}"""


# ─── Cache management ────────────────────────────────────────────────────
def load_emotion_cache():
    """Load emotion cache from disk. Returns dict."""
    if CACHE_PATH.exists():
        with open(CACHE_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}


def save_emotion_cache(cache):
    """Save emotion cache to disk."""
    CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(CACHE_PATH, "w", encoding="utf-8") as f:
        json.dump(cache, f, ensure_ascii=False, indent=2)


def make_cache_key(source_type, source_id, dialog_type):
    """Build a deterministic cache key.

    Examples:
        quest_4974_quest_detail
        object_1234_book_p1
        manual_1_gossip
    """
    return f"{source_type}_{source_id}_{dialog_type}"


def get_tagged_text(cache, source_type, source_id, dialog_type, raw_text):
    """Look up tagged text from cache. Returns raw_text if not cached."""
    key = make_cache_key(source_type, source_id, dialog_type)
    return cache.get(key, raw_text)


# ─── Emote marker handling ───────────────────────────────────────────────
# Multi-word angle-bracket markers like <Thrall slams a fist down.> are
# emote/stage directions that become narrator segments at generation time.
# We strip them entirely before sending to the LLM, then reinsert after
# tagging. The LLM never sees them — no placeholders, no confusion.

def _strip_emotes(text):
    """Remove multi-word <emote> markers, recording their positions.

    Single-word markers like <name>, <class>, <race> are left alone.
    Returns (clean_text, emote_list) where emote_list contains
    (anchor_words_before, original_marker, anchor_words_after) tuples.
    """
    emotes = []

    def _record(match):
        inner = match.group(1)
        # Single-word markers (no spaces) → keep as-is
        if ' ' not in inner:
            return match.group(0)
        emotes.append(match)
        return "\x00"  # temporary sentinel

    # First pass: mark emote positions with sentinels
    marked = re.sub(r'<([^<>]+)>', _record, text)

    if not emotes:
        return text, []

    # Build anchor-based emote records
    parts = marked.split("\x00")
    emote_records = []
    for i, emote_match in enumerate(emotes):
        before_text = parts[i]
        after_text = parts[i + 1] if i + 1 < len(parts) else ""
        # Get last 3 words before emote (stripping whitespace/newlines)
        before_words = before_text.split()[-3:]
        # Get first 3 words after emote
        after_words = after_text.split()[:3]
        emote_records.append({
            "marker": emote_match.group(0),  # full <...> text
            "before": " ".join(before_words),
            "after": " ".join(after_words),
            "at_start": not before_text.strip(),
            "at_end": not after_text.strip(),
            "whitespace_before": before_text[len(before_text.rstrip()):] if before_text.rstrip() != before_text else "",
            "whitespace_after": after_text[:len(after_text) - len(after_text.lstrip())] if after_text.lstrip() != after_text else "",
        })

    # Second pass: remove sentinels to produce clean text
    clean = text
    for emote_match in reversed(emotes):
        start, end = emote_match.start(), emote_match.end()
        # Remove the emote and collapse surrounding whitespace sensibly
        before = clean[:start].rstrip()
        after = clean[end:].lstrip()
        # Preserve paragraph breaks (\n\n) if present on either side
        ws_before = clean[len(before):start]
        ws_after = clean[end:end + (len(clean[end:]) - len(after))]
        # Use the more significant whitespace
        if "\n\n" in ws_before or "\n\n" in ws_after:
            separator = "\n\n"
        elif "\n" in ws_before or "\n" in ws_after:
            separator = "\n"
        elif before and after:
            separator = " "
        else:
            separator = ""
        clean = before + separator + after

    return clean, emote_records


def _reinsert_emotes(tagged_text, emote_records):
    """Reinsert emote markers into tagged text using anchor word matching."""
    if not emote_records:
        return tagged_text

    result = tagged_text
    for rec in emote_records:
        marker = rec["marker"]

        if rec["at_start"]:
            # Emote was at the very start of text
            result = marker + " " + result.lstrip()
            continue

        if rec["at_end"]:
            # Emote was at the very end of text
            result = result.rstrip() + " " + marker
            continue

        # Find the anchor (last words before the emote) in the result
        # Strip [tags] for matching purposes
        anchor = rec["before"]
        if anchor:
            # Search in the tag-stripped version to find position, then map back
            result_no_tags = re.sub(r'\[[^\]]+\]\s*', '', result)
            anchor_pos = result_no_tags.find(anchor)
            if anchor_pos >= 0:
                # Map position back to the tagged version
                # Walk both strings in parallel
                no_tag_idx = 0
                real_idx = 0
                while no_tag_idx < anchor_pos + len(anchor) and real_idx < len(result):
                    if result[real_idx] == '[':
                        # Skip tag
                        tag_end = result.find(']', real_idx)
                        if tag_end >= 0:
                            real_idx = tag_end + 1
                            # Skip whitespace after tag
                            while real_idx < len(result) and result[real_idx] == ' ':
                                real_idx += 1
                            continue
                    no_tag_idx += 1
                    real_idx += 1

                # Insert emote at real_idx
                # Determine appropriate whitespace
                ws = rec.get("whitespace_before", "") or " "
                if "\n\n" in ws:
                    ws = "\n\n"
                elif "\n" in ws:
                    ws = "\n"
                else:
                    ws = " "
                ws_after = rec.get("whitespace_after", "") or " "
                if "\n\n" in ws_after:
                    ws_after = "\n\n"
                elif "\n" in ws_after:
                    ws_after = "\n"
                else:
                    ws_after = " "
                result = result[:real_idx] + ws + marker + ws_after + result[real_idx:].lstrip()
                continue

        # Fallback: try after_anchor
        after_anchor = rec["after"]
        if after_anchor:
            result_no_tags = re.sub(r'\[[^\]]+\]\s*', '', result)
            after_pos = result_no_tags.find(after_anchor)
            if after_pos >= 0:
                # Map back and insert before
                no_tag_idx = 0
                real_idx = 0
                while no_tag_idx < after_pos and real_idx < len(result):
                    if result[real_idx] == '[':
                        tag_end = result.find(']', real_idx)
                        if tag_end >= 0:
                            real_idx = tag_end + 1
                            while real_idx < len(result) and result[real_idx] == ' ':
                                real_idx += 1
                            continue
                    no_tag_idx += 1
                    real_idx += 1
                result = result[:real_idx] + marker + " " + result[real_idx:]
                continue

        # Last resort: append
        result = result.rstrip() + " " + marker

    return result


# ─── Backend: Ollama ─────────────────────────────────────────────────────
def tag_with_ollama(text, npc_name, race, sex, dialog_type, quest_title,
                    model="glm-4.7-flash:latest", base_url="http://localhost:11434"):
    """Tag text using local Ollama instance."""
    import urllib.request
    import urllib.error

    user_msg = USER_PROMPT_TEMPLATE.format(
        npc_name=npc_name, race=race, sex=sex,
        dialog_type=dialog_type, quest_title=quest_title, text=text,
    )

    payload = json.dumps({
        "model": model,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_msg},
        ],
        "stream": False,
        "think": False,
        "options": {
            "temperature": 0.3,
            "top_p": 0.9,
            "num_predict": 2048,
        },
    }).encode("utf-8")

    req = urllib.request.Request(
        f"{base_url}/api/chat",
        data=payload,
        headers={"Content-Type": "application/json"},
    )

    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            result = json.loads(resp.read().decode("utf-8"))
        raw_content = result["message"]["content"]
        cleaned, reason = _clean_llm_response(raw_content, text)
        return cleaned, raw_content, reason
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")[:200]
        print(f"    WARNING: Ollama HTTP {e.code}: {body}")
        return None, None, f"Ollama HTTP {e.code}"
    except urllib.error.URLError as e:
        print(f"    WARNING: Ollama request failed: {e}")
        return None, None, f"Ollama connection error: {e}"
    except (KeyError, json.JSONDecodeError) as e:
        print(f"    WARNING: Ollama response parse error: {e}")
        return None, None, f"Ollama parse error: {e}"


# ─── Backend: OpenAI-compatible API ──────────────────────────────────────
def tag_with_openai(text, npc_name, race, sex, dialog_type, quest_title,
                    model="gpt-4o-mini", api_key=None, base_url="https://api.openai.com/v1"):
    """Tag text using OpenAI-compatible API."""
    import urllib.request
    import urllib.error

    if not api_key:
        api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        print("    ERROR: No API key. Set OPENAI_API_KEY env var or use --api-key")
        return None

    user_msg = USER_PROMPT_TEMPLATE.format(
        npc_name=npc_name, race=race, sex=sex,
        dialog_type=dialog_type, quest_title=quest_title, text=text,
    )

    payload = json.dumps({
        "model": model,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_msg},
        ],
        "temperature": 0.3,
        "max_tokens": 2048,
    }).encode("utf-8")

    req = urllib.request.Request(
        f"{base_url}/chat/completions",
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            result = json.loads(resp.read().decode("utf-8"))
        raw_content = result["choices"][0]["message"]["content"]
        cleaned, reason = _clean_llm_response(raw_content, text)
        return cleaned, raw_content, reason
    except urllib.error.URLError as e:
        print(f"    WARNING: OpenAI request failed: {e}")
        return None, None, f"OpenAI connection error: {e}"
    except (KeyError, IndexError, json.JSONDecodeError) as e:
        print(f"    WARNING: OpenAI response parse error: {e}")
        return None, None, f"OpenAI parse error: {e}"


# ─── Response cleaning ───────────────────────────────────────────────────
def _clean_llm_response(response, original_text):
    """Validate and clean LLM response.

    Returns (cleaned_text, rejection_reason) tuple.
    On success: (tagged_text, None)
    On failure: (None, "reason string")
    """
    if not response or not response.strip():
        return None, "empty response from LLM"

    response = response.strip()

    # Strip markdown code fences if LLM wrapped it
    if response.startswith("```"):
        lines = response.split("\n")
        # Remove first and last lines (fences)
        if lines[-1].strip() == "```":
            lines = lines[1:-1]
        else:
            lines = lines[1:]
        response = "\n".join(lines).strip()

    # Strip leading/trailing quotes — but only if the original text itself
    # does NOT start with a quote (to avoid eating content quotes in quest text
    # like '"And so it begins..."')
    # Check both ASCII and Unicode smart quotes (\u201c/\u201d/\u2018/\u2019)
    _ANY_QUOTE = ('"', "'", '\u201c', '\u201d', '\u2018', '\u2019')
    orig_trimmed = original_text.strip()
    orig_starts_quote = any(orig_trimmed.startswith(q) for q in _ANY_QUOTE)
    if not orig_starts_quote:
        if (response.startswith('"') and response.endswith('"')) or \
           (response.startswith("'") and response.endswith("'")):
            response = response[1:-1]

    # Strip any tags that are not in ALLOWED_TAGS.
    # Max allowed tag length is 30 chars (longest real tag: "whisper in small voice" = 22).
    # LLMs sometimes wrap entire paragraphs in [...] — those are NOT tags.
    MAX_TAG_LEN = 30

    # Game placeholders that the LLM sometimes confuses with emotion tags
    GAME_PLACEHOLDERS = {"name", "class", "race"}

    # Identify [brackets] that exist verbatim in the original text.
    # These are content (e.g. "Suggested Players [5]"), not emotion tags.
    original_brackets = set(re.findall(r'\[[^\]]+\]', original_text))

    stripped_tags = []

    def _validate_tag(match):
        full_match = match.group(0)  # e.g. "[5]" or "[warm]"
        tag_content = match.group(1).strip().lower()
        # Preserve brackets that exist verbatim in original text (content, not tags)
        # e.g. "Suggested Players [5]" → [5] is content, not a tag
        if full_match in original_brackets:
            return full_match
        # Restore game placeholders that LLM confused with tags
        # e.g. <class> → [class] → restore to <class>
        if tag_content in GAME_PLACEHOLDERS:
            stripped_tags.append((tag_content, "restored as game placeholder"))
            return f"<{tag_content}>"
        if len(tag_content) > MAX_TAG_LEN:
            # Not a tag — LLM wrapped text in brackets. Preserve content.
            stripped_tags.append((tag_content[:40] + "...", "too long (paragraph wrapped in brackets)"))
            return match.group(1)
        if tag_content in ALLOWED_TAGS:
            return f"[{tag_content}]"
        # Tag not recognized — restore original text content instead of deleting.
        # The LLM wrapped original text in brackets (e.g. "Haha..." → [haha...]).
        # Returning the content preserves the text; case reconstruction fixes casing.
        stripped_tags.append((tag_content, "not in ALLOWED_TAGS"))
        return match.group(1)

    response = re.sub(r'\[([^\]]+)\]', _validate_tag, response)
    # Clean up double spaces left by stripped tags
    response = re.sub(r'  +', ' ', response)

    # Validate: stripped response should match original text.
    # Only strip emotion tags (ALLOWED_TAGS) — preserve content brackets like [5].
    def _strip_emotion_tags_only(text):
        def _repl(m):
            tag = m.group(1).strip().lower()
            if tag in ALLOWED_TAGS:
                return ''  # Strip emotion tag + trailing whitespace
            return m.group(0)  # Preserve content brackets
        return re.sub(r'\[([^\]]+)\]\s*', _repl, text)

    stripped = _strip_emotion_tags_only(response)
    stripped = re.sub(r'\s+', ' ', stripped).strip()
    original_norm = re.sub(r'\s+', ' ', original_text).strip()

    # Normalize Unicode: LLMs convert smart quotes/dashes to ASCII equivalents.
    # 284 quest texts use \u201c/\u201d smart quotes — normalize both sides.
    def _normalize_unicode(s):
        return (s.replace('\u201c', '"').replace('\u201d', '"')
                 .replace('\u2018', "'").replace('\u2019', "'"))
    stripped = _normalize_unicode(stripped)
    original_norm = _normalize_unicode(original_norm)

    if stripped == original_norm:
        return response, None

    # Fix: LLM sometimes drops trailing punctuation (e.g. "honor!" → "honor").
    # If the only difference is missing trailing punct, restore it.
    if original_norm and original_norm[-1] in '!?.' and stripped == original_norm[:-1]:
        response = response.rstrip() + original_norm[-1]
        return response, None

    # Case-insensitive check — if text content matches but case was mangled,
    # reconstruct by extracting tags and re-inserting into original text
    stripped_compact = stripped.replace(" ", "").lower()
    original_compact = original_norm.replace(" ", "").lower()

    if stripped_compact != original_compact:
        # Text was actually modified — build detailed reason
        # Find first difference
        diff_detail = ""
        for i, (a, b) in enumerate(zip(stripped, original_norm)):
            if a != b:
                ctx_s = stripped[max(0, i-20):i+20]
                ctx_o = original_norm[max(0, i-20):i+20]
                diff_detail = f" | first diff at pos {i}: got {repr(a)} expected {repr(b)} | stripped: ...{ctx_s}... | original: ...{ctx_o}..."
                break
        else:
            diff_detail = f" | length mismatch: stripped={len(stripped)} vs original={len(original_norm)}"
        tag_info = ""
        if stripped_tags:
            tag_info = " | stripped tags: " + ", ".join(f"[{t}] ({r})" for t, r in stripped_tags)
        return None, f"text modified by LLM{diff_detail}{tag_info}"

    # Case was mangled by LLM. Extract [tag] positions and rebuild from original.
    # Walk both response and original_text in parallel, copying tags from response
    # but text from original.
    result = []
    orig_idx = 0  # position in original_text
    resp_idx = 0  # position in response

    while resp_idx < len(response):
        # Copy any [tag] from response
        if response[resp_idx] == '[':
            end = response.find(']', resp_idx)
            if end != -1:
                result.append(response[resp_idx:end + 1])
                resp_idx = end + 1
                continue
        # Skip whitespace in response after tags, but consume from original
        if response[resp_idx].isspace() and orig_idx < len(original_text) and original_text[orig_idx].isspace():
            result.append(original_text[orig_idx])
            resp_idx += 1
            orig_idx += 1
        elif response[resp_idx].isspace() and (orig_idx >= len(original_text) or not original_text[orig_idx].isspace()):
            # Extra whitespace after tag — keep it
            result.append(response[resp_idx])
            resp_idx += 1
        elif orig_idx < len(original_text) and response[resp_idx].lower() == original_text[orig_idx].lower():
            # Same char, possibly different case — use original's case
            result.append(original_text[orig_idx])
            resp_idx += 1
            orig_idx += 1
        elif orig_idx < len(original_text):
            # Mismatch — try to resync by consuming both
            result.append(original_text[orig_idx])
            resp_idx += 1
            orig_idx += 1
        else:
            resp_idx += 1

    # Append any remaining original text
    if orig_idx < len(original_text):
        result.append(original_text[orig_idx:])

    return ''.join(result), None


# ─── Work item builders (reuse from generate_voice.py pattern) ───────────
def _load_npc_database():
    """Load NPC database for race/sex lookup."""
    npc_path = DATA_DIR / "npc_database.json"
    if not npc_path.exists():
        return {}
    with open(npc_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    npc_map = {}
    for entry_id, info in data.get("entries", {}).items():
        name = info.get("name", "").strip()
        if name:
            npc_map[name] = info
    return npc_map


def _is_emote_only(text):
    """Check if text is purely stage directions (emote markers) or has no real words.

    Text like '<Thrall grunts.>' becomes a narrator segment — emotion
    tagging is pointless since the narrator reads it as a stage direction.
    Also catches texts like '...' or '???' that have no alphanumeric content.
    """
    stripped = re.sub(r'<[^<>]+>', '', text).strip()
    if not stripped:
        return True
    # No alphanumeric chars → nothing meaningful to tag (e.g. "...", "???")
    return not re.search(r'[a-zA-Z0-9]', stripped)


def _is_placeholder_text(text):
    """Check if text is developer placeholder/temp content, not real quest text."""
    return bool(re.match(r'^temp text\b', text.strip(), re.IGNORECASE))


def _build_tag_items(source, npc_map, quest_id_filter=None, npc_filter=None,
                     race_filter=None):
    """Build list of items to tag.

    Each item: {source_type, source_id, dialog_type, npc_name, race, sex,
                quest_title, text}

    Args:
        npc_filter: list of NPC name substrings (case-insensitive) to include.
        race_filter: list of normalized race names (case-insensitive) to include.

    Skips emote-only entries (e.g. '<Thrall grunts.>') since those become
    narrator segments where emotion tags are not used.
    """
    npc_filter_lower = [n.lower() for n in npc_filter] if npc_filter else None
    sys.path.insert(0, str(PROJECT_ROOT / "scripts"))
    from analyze_quest_races import normalize_race

    items = []

    if source in ("quests", "all"):
        quest_path = DATA_DIR / "quest_database.json"
        if quest_path.exists():
            with open(quest_path, "r", encoding="utf-8") as f:
                quest_data = json.load(f)

            for qid, quest in quest_data.get("entries", {}).items():
                if quest_id_filter and int(qid) != quest_id_filter:
                    continue

                title = quest.get("title", "")

                # Quest detail (description) → quest giver
                if quest.get("description"):
                    npc_name = quest.get("quest_giver", "Unknown")
                    npc_info = npc_map.get(npc_name, {})
                    raw_race = npc_info.get("race", "")
                    race = normalize_race(raw_race) if raw_race else "Narrator"
                    sex = npc_info.get("sex", "unknown")
                    items.append({
                        "source_type": "quest",
                        "source_id": qid,
                        "dialog_type": "quest_detail",
                        "npc_name": npc_name,
                        "race": race,
                        "sex": sex,
                        "quest_title": title,
                        "text": quest["description"],
                    })

                # Quest progress → quest ender (or giver)
                if quest.get("progress"):
                    npc_name = quest.get("quest_ender", quest.get("quest_giver", "Unknown"))
                    npc_info = npc_map.get(npc_name, {})
                    raw_race = npc_info.get("race", "")
                    race = normalize_race(raw_race) if raw_race else "Narrator"
                    sex = npc_info.get("sex", "unknown")
                    items.append({
                        "source_type": "quest",
                        "source_id": qid,
                        "dialog_type": "quest_progress",
                        "npc_name": npc_name,
                        "race": race,
                        "sex": sex,
                        "quest_title": title,
                        "text": quest["progress"],
                    })

                # Quest completion → quest ender (or giver)
                if quest.get("completion"):
                    npc_name = quest.get("quest_ender", quest.get("quest_giver", "Unknown"))
                    npc_info = npc_map.get(npc_name, {})
                    raw_race = npc_info.get("race", "")
                    race = normalize_race(raw_race) if raw_race else "Narrator"
                    sex = npc_info.get("sex", "unknown")
                    items.append({
                        "source_type": "quest",
                        "source_id": qid,
                        "dialog_type": "quest_complete",
                        "npc_name": npc_name,
                        "race": race,
                        "sex": sex,
                        "quest_title": title,
                        "text": quest["completion"],
                    })

    if source in ("objects", "all") and not quest_id_filter:
        obj_path = DATA_DIR / "object_database.json"
        if obj_path.exists():
            with open(obj_path, "r", encoding="utf-8") as f:
                obj_data = json.load(f)

            for oid, obj in obj_data.get("entries", {}).items():
                name = obj.get("name", "Unknown")
                if obj.get("pages"):
                    for pi, page in enumerate(obj["pages"]):
                        if page.strip():
                            items.append({
                                "source_type": "object",
                                "source_id": oid,
                                "dialog_type": f"book_p{pi+1}",
                                "npc_name": name,
                                "race": "Narrator",
                                "sex": "unknown",
                                "quest_title": name,
                                "text": page,
                            })
                elif obj.get("content"):
                    items.append({
                        "source_type": "object",
                        "source_id": oid,
                        "dialog_type": "book_p1",
                        "npc_name": name,
                        "race": "Narrator",
                        "sex": "unknown",
                        "quest_title": name,
                        "text": obj["content"],
                    })

    # Filter out emote-only entries — they become narrator stage directions
    # Filter out dev placeholder text (e.g. "temp text 02 - description")
    items = [item for item in items
             if not _is_emote_only(item["text"]) and not _is_placeholder_text(item["text"])]

    # Filter by NPC name (case-insensitive substring match)
    if npc_filter_lower:
        items = [item for item in items
                 if any(f in item["npc_name"].lower() for f in npc_filter_lower)]

    # Filter by race (case-insensitive exact match on normalized race)
    if race_filter:
        race_filter_lower = [r.lower() for r in race_filter]
        items = [item for item in items
                 if (item["race"] or "").lower() in race_filter_lower]

    return items


# ─── Main tagging loop ───────────────────────────────────────────────────
def tag_items(items, cache, backend, model, api_key=None, base_url=None,
              retag=False, dry_run=False, batch_size=50, debug=False):
    """Tag all items, updating cache in place. Returns count of newly tagged items."""
    tagged_count = 0
    skipped_count = 0
    error_count = 0
    total = len(items)

    for i, item in enumerate(items):
        key = make_cache_key(item["source_type"], item["source_id"], item["dialog_type"])

        # Skip if already cached (unless retag)
        if key in cache and not retag:
            skipped_count += 1
            continue

        if dry_run:
            print(f"  [{i+1}/{total}] Would tag: {key} ({item['npc_name']})")
            tagged_count += 1
            continue

        text = item["text"]
        npc_name = item["npc_name"]
        race = item["race"]
        sex = item["sex"]
        dialog_type = item["dialog_type"]
        quest_title = item["quest_title"]

        # Strip multi-word emote markers — LLM gets clean text only
        clean_text, emote_records = _strip_emotes(text)

        # Normalize paragraph breaks (\n\n) → single space for LLM.
        # LLMs (especially glm-4.7-flash) consistently drop text after \n\n.
        # We record break positions and restore them in the tagged output.
        newline_records = []
        llm_text = clean_text
        while "\n\n" in llm_text:
            pos = llm_text.index("\n\n")
            # Anchor: last few words before the break
            before = llm_text[:pos].split()[-3:]
            newline_records.append(" ".join(before))
            llm_text = llm_text[:pos] + " " + llm_text[pos:].lstrip("\n")

        print(f"  [{i+1}/{total}] {key} ({npc_name}, {race})")

        # Call the appropriate backend with retry logic
        max_retries = 5
        tagged = None
        raw_response = None
        reason = None

        for attempt in range(1, max_retries + 1):
            if backend == "ollama":
                url = base_url or "http://localhost:11434"
                tagged, raw_response, reason = tag_with_ollama(
                    llm_text, npc_name, race, sex, dialog_type,
                    quest_title, model=model, base_url=url)
            elif backend == "openai":
                url = base_url or "https://api.openai.com/v1"
                tagged, raw_response, reason = tag_with_openai(
                    llm_text, npc_name, race, sex, dialog_type,
                    quest_title, model=model, api_key=api_key,
                    base_url=url)
            else:
                tagged, raw_response, reason = None, None, "no backend"
                break

            if tagged:
                break

            if attempt < max_retries:
                print(f"    retry {attempt}/{max_retries}: {reason}")

        if tagged:
            # Restore \n\n paragraph breaks using anchor words
            for anchor in newline_records:
                if anchor:
                    # Find the anchor in the tagged text (skip [tags])
                    escaped = re.escape(anchor)
                    # Match anchor followed by optional [tag] and a space
                    pattern = f"({escaped})\\s+"
                    tagged = re.sub(pattern, f"\\1\n\n", tagged, count=1)

            # Reinsert emote markers into the tagged output
            tagged = _reinsert_emotes(tagged, emote_records)
            cache[key] = tagged
            tagged_count += 1
            # Show a preview
            preview = tagged[:100].replace("\n", " ")
            print(f"    → {preview}{'...' if len(tagged) > 100 else ''}")
        else:
            error_count += 1
            print(f"    → FAILED: {reason}")
            if debug:
                orig_preview = text[:200].replace("\n", "\\n")
                print(f"    ┊ ORIGINAL: {orig_preview}{'...' if len(text) > 200 else ''}")
                if raw_response:
                    raw_preview = raw_response[:300].replace("\n", "\\n")
                    print(f"    ┊ LLM RETURNED: {raw_preview}{'...' if len(raw_response) > 300 else ''}")
            # Cache the raw untagged text after all retries exhausted.
            # This prevents wasting API calls on texts the LLM can't handle
            # (e.g. it consistently drops small words). Use --retag to retry.
            cache[key] = text
            print(f"    → Cached raw text (no emotions) to prevent future retries")

        # Incremental save every batch_size items
        if tagged_count > 0 and tagged_count % batch_size == 0:
            save_emotion_cache(cache)
            print(f"    [cache saved: {len(cache)} entries]")

        # Small delay to avoid overwhelming the LLM
        if backend == "ollama":
            time.sleep(0.05)
        elif backend == "openai":
            time.sleep(0.1)

    return tagged_count, skipped_count, error_count


# ─── CLI ─────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="TurtleTongue emotion tagger — inject [tags] into quest text"
    )
    parser.add_argument(
        "--source", choices=["quests", "objects", "all"],
        default="all", help="Which data source to tag (default: all)"
    )
    parser.add_argument(
        "--quest-id", type=int, default=None,
        help="Tag a specific quest ID only"
    )
    parser.add_argument(
        "--npc", action="append", default=None,
        help="Filter by NPC name (case-insensitive substring, repeatable)"
    )
    parser.add_argument(
        "--race", action="append", default=None,
        help="Filter by normalized race (case-insensitive, repeatable, e.g. Orc, Furbolg, Narrator)"
    )
    parser.add_argument(
        "--backend", choices=["ollama", "openai", "skip"],
        default="ollama", help="LLM backend to use (default: ollama)"
    )
    parser.add_argument(
        "--model", type=str, default=None,
        help="Model name (default: glm-4.7-flash:latest for ollama, gpt-4o-mini for openai)"
    )
    parser.add_argument(
        "--api-key", type=str, default=None,
        help="API key for openai backend (or set OPENAI_API_KEY env var)"
    )
    parser.add_argument(
        "--base-url", type=str, default=None,
        help="Base URL override (default: http://localhost:11434 for ollama, https://api.openai.com/v1 for openai)"
    )
    parser.add_argument(
        "--retag", action="store_true",
        help="Re-tag even if already cached"
    )
    parser.add_argument(
        "--clear-cache", action="store_true",
        help="Clear the entire emotion cache before tagging"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Preview what would be tagged without calling LLM"
    )
    parser.add_argument(
        "--show", action="store_true",
        help="Show cached tags (combine with --quest-id to filter)"
    )
    parser.add_argument(
        "--stats", action="store_true",
        help="Show cache statistics"
    )
    parser.add_argument(
        "--debug", action="store_true",
        help="Show original text and raw LLM response on failures"
    )
    args = parser.parse_args()

    # ── Default model per backend ─────────────────────────────────────
    if args.model is None:
        if args.backend == "ollama":
            args.model = "glm-4.7-flash:latest"
        elif args.backend == "openai":
            args.model = "gpt-4o-mini"
        else:
            args.model = "skip"

    # ── Show mode ─────────────────────────────────────────────────────
    if args.show:
        cache = load_emotion_cache()
        if not cache:
            print("Emotion cache is empty.")
            return

        for key, tagged in sorted(cache.items()):
            if args.quest_id:
                if f"quest_{args.quest_id}_" not in key:
                    continue
            print(f"\n{'='*60}")
            print(f"Key: {key}")
            print(f"{'='*60}")
            print(tagged)
        return

    # ── Stats mode ────────────────────────────────────────────────────
    if args.stats:
        cache = load_emotion_cache()
        if not cache:
            print("Emotion cache is empty.")
            return

        from collections import Counter
        source_counts = Counter()
        type_counts = Counter()
        tag_counts = []

        for key, tagged in cache.items():
            parts = key.split("_", 2)
            if len(parts) >= 2:
                source_counts[parts[0]] += 1
            if len(parts) >= 3:
                type_counts[parts[2]] += 1
            tags = re.findall(r'\[([^\]]+)\]', tagged)
            tag_counts.append(len(tags))

        print(f"Total cached entries: {len(cache)}")
        print(f"\nBy source:")
        for src, count in source_counts.most_common():
            print(f"  {src}: {count}")
        print(f"\nBy dialog type:")
        for dt, count in type_counts.most_common():
            print(f"  {dt}: {count}")
        if tag_counts:
            print(f"\nTags per entry: min={min(tag_counts)}, max={max(tag_counts)}, "
                  f"avg={sum(tag_counts)/len(tag_counts):.1f}")

        # Top 20 most used tags
        all_tags = Counter()
        for tagged in cache.values():
            for tag in re.findall(r'\[([^\]]+)\]', tagged):
                all_tags[tag] += 1
        if all_tags:
            print(f"\nTop 20 tags:")
            for tag, count in all_tags.most_common(20):
                print(f"  [{tag}]: {count}")
        return

    # ── Clear cache ───────────────────────────────────────────────────
    if args.clear_cache:
        if CACHE_PATH.exists():
            CACHE_PATH.unlink()
            print("Emotion cache cleared.")
        else:
            print("No cache to clear.")
        if args.backend == "skip":
            return

    # ── Build work items ──────────────────────────────────────────────
    print("Loading NPC database...")
    npc_map = _load_npc_database()
    print(f"  {len(npc_map)} NPCs loaded")

    items = _build_tag_items(args.source, npc_map, quest_id_filter=args.quest_id,
                             npc_filter=args.npc, race_filter=args.race)
    if args.npc:
        print(f"  Filtered to NPC(s): {', '.join(args.npc)}")
    if args.race:
        print(f"  Filtered to race(s): {', '.join(args.race)}")
    print(f"  {len(items)} text entries to process")

    if not items:
        print("No items to tag.")
        return

    # ── Load cache ────────────────────────────────────────────────────
    cache = load_emotion_cache()
    print(f"  {len(cache)} entries already cached")

    # ── Tag ───────────────────────────────────────────────────────────
    if args.backend == "skip":
        print("Backend: skip — no emotion tags will be added")
        return

    print(f"\nTagging with backend={args.backend}, model={args.model}")
    tagged, skipped, errors = tag_items(
        items, cache, args.backend, args.model,
        api_key=args.api_key, base_url=args.base_url,
        retag=args.retag, dry_run=args.dry_run,
        debug=args.debug,
    )

    # ── Save ──────────────────────────────────────────────────────────
    if tagged > 0 and not args.dry_run:
        save_emotion_cache(cache)

    print(f"\n=== Tagging complete ===")
    print(f"  Tagged: {tagged}")
    print(f"  Skipped (cached): {skipped}")
    print(f"  Errors: {errors}")
    print(f"  Cache total: {len(cache)} entries")


if __name__ == "__main__":
    main()
