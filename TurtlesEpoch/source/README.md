# UPDATE:

All future updates will be done for Capybara WoW. I am retiring work on epoch's wotlk client, it should still work fine with the latest release.

# Turtle's Epoch

> *"Every quest you accepted. Every NPC who sent you into the wilderness. Every book you found in a dusty corner of the world. They all had a voice — you just couldn't hear it."*

AI-generated voice lines for NPC quest text, books, and world objects in [Turtle WoW](https://turtlecraft.gg/) (1.12). Race-specific voice cloning via Fish Speech S2 Pro. Full dialog frame with 3D portraits and voice playback. Pure plug-and-play — pre-generated voices distributed as a release download.

Small showcase:

https://drive.proton.me/urls/RVF5W4DKF8#qT8yTPkOsIvR

---

## Why This Exists

Turtle WoW was one of those rare servers that actually felt like it got vanilla. Over time it grew way past what anyone expected, with new zones, new races, and a ton of custom questlines that somehow still felt like they belonged in the game.

It never had voice acting though. Everything was just text, like old school WoW always was.

Then Blizzard shut it down.

Playing through all that custom content made me realize how much good writing just gets skipped or skimmed. This started as a small side project to mess around with giving that text a voice.

The goal wasn’t to rely on some paid API or cloud service. It all runs locally, something you can download, tweak, and actually own. Nothing crazy, just a pipeline that works and sounds decent enough.

This addon was inspired by two excellent projects:

- **[BetterQuest](https://github.com/tlplayer/BetterQuest)** — the sound queue architecture, the 0.1s delay trigger pattern, the NPC database approach, and the manifest-based duration tracking all trace back to studying BetterQuest's clean implementation.
- **[AI_Voiceover](https://github.com/mrthinger/wow-voiceover)** — proved that AI-generated voice acting for WoW addon content is a real, working concept and not just a thought experiment.

Turtle's Epoch builds on both: wider race coverage (65 voice profiles vs a handful), local generation with no paid services, and support for Turtle WoW's custom NPCs and questlines that don't appear in the retail database.

---

## What It Does

- Adds synthesized voice acting to quest givers, books, plaques, world objects, and stage-direction text
- **65 voice profiles**: 10 playable races (gendered) + 28 creature types + 16 iconic named NPCs + narrator
- Per-NPC voice uniqueness — two Orc quest givers sound distinct but share Orc-ish qualities
- Voice anchor system — each NPC sounds consistent across all their dialog lines
- 16,686 pre-generated playable voice clips with manifest durations
- Over 16,000 emotion-tagged lines for expressive speech (joy, anger, sorrow, fear, etc.)
- Compact overlay dialog frame with 3D NPC portrait, voice playback queue, Skip and Clear Queue controls
- Draggable, position-saved dialog window
- Per-race, per-creature-type, and per-named-NPC voice toggles
- Inventory-item-triggered quests (right-click a note or writ) play the correct voice automatically
- Play buttons in the Quest Log to replay any quest voice on demand

### Voice Coverage

| Category | Profiles | Quest Lines |
|----------|----------|-------------|
| Base races (gendered) | 20 | ~15,500 |
| Creature types | 28 | ~900 |
| Named NPCs (Thrall, Sylvanas, etc.) | 16 | ~300 |
| Narrator (books, objects, fallback) | 1 | ~500 |
| **Total** | **65** | **~17,900+** |

---

## Installation (Players)

No Python, no GPU, no configuration. Just download, extract, play.

1. Download the **addon zip** from the [Releases](https://codeberg.org/Mejiro/TurtlesEpoch/releases) page
2. Extract to `Interface/AddOns/TurtlesEpoch/`
3. Download the **voice pack zip** from the same release page
4. Extract the voice pack into the same `TurtlesEpoch/` folder 
5. Launch the game — voices play automatically during quest dialog and object/book interactions

Your folder should look like:
```
Interface/AddOns/TurtlesEpoch/
├── TurtlesEpoch.toc
├── core/
├── data/
│   ├── npc_data.lua
│   └── voice_manifest.lua    ← from voice pack
├── sounds/                    ← from voice pack
│   ├── human/
│   ├── orc/
│   └── ...
└── textures/
```

### Slash Commands

| Command | Description |
|---------|-------------|
| `/te` | Show help |
| `/te toggle` | Enable/disable voice playback |
| `/te skip` | Skip current audio clip, advance queue |
| `/te clear` | Clear the entire playback queue |
| `/te show` | Re-open the voice dialog frame if dismissed |
| `/te config` | Open the voice settings panel |
| `/te status` | Show version, NPC count, queue state |
| `/te debug` | Toggle debug chat output (for troubleshooting) |

### Troubleshooting

- **No voices playing**: Check that `sounds/` folder exists inside the addon directory and contains `.ogg` files. Run `/te status` to confirm the addon loaded.
- **Addon not showing in list**: Verify the folder structure — `TurtlesEpoch.toc` must be directly inside `Interface/AddOns/TurtlesEpoch/`, not nested in a subfolder.
- **Lua errors**: Enable "Show Lua Errors" in Interface → Help. Report the error text as an issue.
- **Some `.ogg` files silent (especially under WINE / Linux)**: Update to v1.1.1 — the voice pack is now re-encoded at `-q:a 2` (was `-q:a 4`). The Vorbis decoder used by some audio stacks is bitrate-sensitive and intermittently rejects higher-bitrate files due to non-monotonic granulepos. `-q:a 2` (~96 kbps) reliably normalizes timestamps for cross-platform playback.

### Changelog

**v1.1.1** (current)
- Fix: `.ogg` encoding bitrate dropped to `-q:a 2` (~96 kbps) across the entire pipeline (`generate_voice.py` `wav_to_ogg()` and `convert_to_ogg.sh`). Higher bitrates intermittently produced files with non-monotonic granulepos that played silent under some Vorbis decoders, especially WINE. `-q:a 2` reliably normalizes the packet timestamps.

**v1.1**
- Fix: same-NPC quest chains no longer overwrite each other in the lookup table; multi-part quests with the same title now match the correct dialog text.
- Fix: multi-giver quests (war effort etc.) disambiguate by NPC folder.
- Fix: `.ogg` files re-encoded through libvorbis so playback works reliably on all client / OS combinations (notably WINE on Linux).
- New per-NPC greeting mute toggle in Settings (cuts the brief NPC voiceline that plays when a dialog opens).

**v1.0**
- Initial release. 18,391 voice clips across 65 voice profiles.


---

## Power User Guide

### Voice Toggle Settings

Voices can be enabled or disabled by category. Disabled categories fall back to silent quest interaction (vanilla behavior). All categories are enabled by default. Settings persist across sessions via SavedVariables.

Open the settings panel with `/te config`. Three columns of checkboxes:
- **Base Races + Narrator** — Human, Dwarf, Night Elf, Gnome, High Elf, Orc, Troll, Undead, Tauren, Goblin, Narrator
- **Creature Types** — Furbolg, Dragon, Ogre, and 25 more non-playable creature voices
- **Custom NPCs** — Thrall, Sylvanas, Jaina, Cairne, Magni, and 11 other named characters with unique voices

Disabling a race silences only that voice category. Books and objects (Narrator) have their own toggle.

### Reporting Missing or Incorrect Voices

Some dialog types are not automatically crawled and must be added manually:

- **Quest greetings** — the multi-quest NPC intro text (e.g., "I have several tasks for you")
- **Notable gossip** — lore-significant NPC conversations
- **Inventory items** — notes, letters, and readable items only visible in-game

To report missing content, open an issue with the NPC name, the dialog text, and where you encountered it.

### Adding Manual Entries (CLI)

If you have the repository cloned, you can add entries yourself:

```bash
# Add a gossip line (race/sex auto-resolved from NPC database)
python scripts/add_entry.py --type gossip --npc "Guard Thomas" \
  --text "The Defias are causing trouble in the area."

# Add a quest greeting
python scripts/add_entry.py --type quest_greeting --npc "Marshal McBride" \
  --text "Ah, another newcomer to Northshire."

# Add an inventory item (always uses narrator voice)
python scripts/add_entry.py --type item_text --name "Weathered Letter" \
  --text "Dear adventurer, if you are reading this..."

# List all manual entries
python scripts/add_entry.py --list

# Remove an entry by ID
python scripts/add_entry.py --remove 3
```

Race and sex are auto-resolved from the NPC database (13,500+ entries). Override with `--race` and `--sex` if the NPC is missing or misidentified.

---

## Developer Guide

Building voice packs from scratch. Requires Python 3.11+, a CUDA GPU with ~22 GB VRAM, and the Fish Speech S2 Pro model weights.

### Personalizing Your Voice Pack

One of the best features of generating your own pack: **NPCs can refer to you by name and class**.

The distributed voice pack uses generic substitutions (`$N` → "adventurer", class omitted). But if you generate your own pack, you can set your actual character name, race, and class so that NPCs address you personally. An Orc quest giver might say "Well done, <your name>" instead of "Well done, adventurer."

```bash
# Set up your character
python scripts/player_config.py

# Shows a prompt like:
#   Character name: Smooky
#   Race: Troll
#   Class: Shaman
#   Gender: male
# Saves to data/player_config.json

# Then generate with your personal config
python scripts/generate_voice.py --source all --emotions
```

Your config is used at generation time for all `$N` / `$C` / `$R` / `$G` text substitutions. The resulting voice pack is personalized to your character. This is especially satisfying for Turtle WoW's custom quests, which use player names frequently.

### Environment Setup

```bash
# 1. Clone both repos side by side
git clone codeberg.org:Mejiro/TurtlesEpoch.git
git clone https://github.com/fishaudio/fish-speech.git

# 2. Create venv (Python 3.11 recommended)
cd TurtlesEpoch
python -m venv .ttsvenv
source .ttsvenv/bin/activate   # returns RC=1 on some shells — this is normal

# 3. Install PyTorch + CUDA (adjust cu version for your GPU)
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu130

# 4. Install Fish Speech (editable, --no-deps to preserve our PyTorch version)
cd ../fish-speech && pip install -e . --no-deps

# 5. Install all runtime dependencies
cd ../TurtlesEpoch && pip install -r scripts/requirements.txt

# 6. Install DAC codec (separate due to protobuf pin conflict)
pip install descript-audio-codec

# 7. Download Fish Speech S2 Pro model weights (~11 GB)
#    Place in fish-speech/checkpoints/s2-pro/
#    Files: config.json, tokenizer.json, model-*.safetensors, codec.pth, etc.
```

### KV Cache Patch (Required for 24 GB GPUs)

Fish Speech defaults to a 32,768-token KV cache (~4.8 GB VRAM). Patch it down to 4,096 tokens to avoid OOM. There are **3 `setup_caches()` calls** in the inference file that all need patching:

In `fish-speech/fish_speech/models/text2semantic/inference.py`:

```python
# Line ~282 (generate_long function)
kv_limit = min(model.config.max_seq_len, 4096)

# Line ~765 (launch_thread_safe_queue worker)
kv_seq_len = min(model.config.max_seq_len, 4096)

# Line ~888 (inference_worker_v2)
max_seq_len=min(model.config.max_seq_len, 4096),
```

If you only patch one site, the other code paths will still allocate the full 32K cache and OOM. All three must be changed.

This saves ~4.2 GB VRAM. The 4,096 cap is safe — with `max_new_tokens=2048` and 45s reference audio, the worst case is ~3,016 tokens, well under the limit.

### Starting the API Server

```bash
cd fish-speech
PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True \
  python tools/api_server.py --device cuda --compile
```

- `--compile` enables `torch.compile()` — first request is ~60-90s slower, subsequent requests 2-4x faster
- `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True` prevents VRAM fragmentation
- Wait for "Startup done" before generating

### Voice Generation

```bash
cd TurtlesEpoch

# Generate all voices (quests + books + manual entries)
python scripts/generate_voice.py --source all --emotions

# Generate only missing voices (incremental)
python scripts/generate_voice.py --source all --missing-only --emotions

# Generate a specific race
python scripts/generate_voice.py --race Orc --emotions --force

# Generate a specific NPC
python scripts/generate_voice.py --npc "Thrall" --emotions --force

# Generate a single quest by ID
python scripts/generate_voice.py --quest-id 776 --force

# Dry run (preview without generating)
python scripts/generate_voice.py --source all --dry-run

# Rebuild manifest from existing files only
python scripts/generate_voice.py --manifest-only
```

**Key flags:**
| Flag | Description |
|------|-------------|
| `--source quests\|objects\|manual\|all` | Which database to generate from |
| `--emotions` / `--no-emotions` | Use LLM-tagged emotion markers (default: on) |
| `--force` | Regenerate existing files (deletes voice anchors too) |
| `--missing-only` | Only generate files that don't exist yet |
| `--npc NAME` | Filter to specific NPC(s) (repeatable, substring match) |
| `--race RACE` | Filter to specific race(s) (repeatable, exact match) |
| `--quest-id N` | Generate a single quest |
| `--temperature` | TTS temperature (default varies per NPC via seed) |
| `--dry-run` | Preview generation plan without calling TTS |

### Emotion Tagging

Emotion tags are injected into quest text via a local LLM before TTS generation. Tags use Fish Speech's inline `[tag]` syntax (e.g., `[excited]`, `[solemn]`, `[angry]`).

```bash
# Tag all quest text (cached to data/emotion_cache.json)
python scripts/emotion_tagger.py

# Re-tag a specific quest (e.g., after fixing a typo)
python scripts/emotion_tagger.py --quest-id 8734 --retag

# Tag only a specific NPC
python scripts/emotion_tagger.py --npc "Thrall"

# Inspect cached tags for a quest
python scripts/emotion_tagger.py --show --quest-id 8734
```

**Important**: The emotion cache (`data/emotion_cache.json`) is independent from `quest_database.json`. If you edit quest text, you must `--retag` that quest — otherwise `--emotions` will send the old cached text to Fish Speech.

Backend: Ollama with `glm-4.7-flash:latest` (local, free). 69 allowed tags with 4-layer validation.

### Voice Profile System

Each of the 65 voice profiles has a JSON config in `data/voice_configs/`:

```json
{
  "donor_voice": null,
  "pitch_shift": 0,
  "reverb": 0.0,
  "reverb_decay": 0.6,
  "bass_boost_db": 0,
  "treble_boost_db": 0,
  "saturation": 0.0,
  "speed": 1.0,
  "status": "approved",
  "test_quest_id": null,
  "notes": ""
}
```

**Donor voice**: Profiles with extreme fundamental frequencies (gnome, goblin, imp, etc.) use a clean human voice for TTS generation, then pitch-shift the output to the target range. Set `donor_voice` to a path relative to `samples/` (e.g., `"human_male"`).

**Post-processing effects** (applied after TTS, before final output):
- `pitch_shift` — semitones to shift
- `reverb` / `reverb_decay` — wet mix and tail length
- `bass_boost_db` / `treble_boost_db` — shelf EQ
- `saturation` — harmonic distortion for gritty voices
- `speed` — time-stretch (1.0 = normal)

**Voice anchors**: The first line generated for an NPC is saved as `.voice_anchor.wav` (clean, before effects). All subsequent lines use this anchor as reference, ensuring consistent voice across dialog types. `--force` deletes anchors for regeneration.

**Per-NPC uniqueness**: Each NPC gets a deterministic seed from their name (DJB2 hash), which controls sample subset selection and temperature variation (0.65–0.85). Same NPC name always produces the same voice.

### Profile Tuning Workflow

```bash
# 1. Generate test lines for a profile
python scripts/generate_voice.py --race Ogre --npc "Lard" --force --emotions

# 2. Listen to output in sounds/ogre/lard/

# 3. Tweak data/voice_configs/ogre.json (adjust effects)

# 4. Regenerate and compare
python scripts/generate_voice.py --race Ogre --npc "Lard" --force --emotions

# 5. Once satisfied, set "status": "approved" in the config

# 6. Generate full race
python scripts/generate_voice.py --race Ogre --emotions --force
```

### Voice Sample Directory

Drop 4-6 `.wav` recordings (~15s each) per profile folder:

```
samples/
├── human_male/            # Base race profiles (10 races × 2 genders)
├── human_female/
├── orc_male/, orc_female/
├── ...
├── narrator/              # Default voice for books, objects, fallback
├── creature/
│   ├── furbolg/           # Single-voice creature types
│   ├── dragon/
│   ├── centaur_male/      # Gendered creature types
│   ├── centaur_female/
│   ├── naga_male/
│   ├── naga_female/
│   └── ...
└── custom/
    ├── thrall/            # Tier 3 named NPCs — unique voice per character
    ├── tyrande_whisperwind/
    └── ...
```

### Other Scripts

| Script | Purpose |
|--------|---------|
| `scripts/crawler.py` | Crawl NPC/quest/object data from database.turtlecraft.gg |
| `scripts/enrich_sex.py` | Three-pass sex detection from DBC files |
| `scripts/convert_to_lua.py` | Convert `npc_database.json` → `npc_data.lua` |
| `scripts/analyze_quest_races.py` | Race normalization map + quest analysis |
| `scripts/generate_report.py` | Voice profile statistics report |
| `scripts/extract_wc3_sounds.py` | Extract WC3 Reforged sounds via CascLib |
| `scripts/player_config.py` | Interactive player character setup |
| `scripts/audio_effects.py` | Per-profile DSP post-processing |

### Packaging a Release

```bash
# 1. Generate all voices
python scripts/generate_voice.py --source all --emotions

# 2. Voice pack contents: sounds/ + data/voice_manifest.lua
#    Package as voice-pack.zip

# 3. Addon code: everything except sounds/, samples/, scripts/, reference/
#    Package as TurtlesEpoch-v1.0.0.zip

# 4. Attach both zips to a Codeberg release
```

See [AGENTS.md](AGENTS.md) for full architecture documentation, API constraints, and design decisions.

---

## Credits

- **[BetterQuest](https://github.com/esinam/BetterQuest)** by esinam — sound queue architecture, NPC database design, event trigger patterns
- **[AI_Voiceover](https://github.com/mrthinger/wow-ai-voiceover)** by mrthinger — proof of concept for AI voice acting in WoW addons
- **[VanillaStoryline](https://www.curseforge.com/wow/addons/vanilla-storyline)** — dialog frame UI patterns and 3D portrait rendering
- **[Fish Speech](https://github.com/fishaudio/fish-speech)** by the Fish Audio team — the TTS engine that makes this possible
- **Turtle WoW** — years of love poured into a world worth preserving

---

## Legal

This is an unofficial fan project. See [DISCLAIMER.md](DISCLAIMER.md) for full legal information.

**Short version**: no Blizzard assets included, all audio is original AI synthesis, no affiliation with Blizzard/Microsoft/Turtle WoW team, non-commercial, EU-hosted.

## License

This project is licensed under the [MIT License](LICENSE).
