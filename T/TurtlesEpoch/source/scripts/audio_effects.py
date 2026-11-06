#!/usr/bin/env python3
"""
Audio post-processing for TurtleTongue voice generation.

Reads per-profile JSON configs from data/voice_configs/ and applies effects
to TTS output. Supports donor voice routing (use a different sample set
for TTS generation, then post-process to target character).

Config schema (data/voice_configs/{profile}.json):
  {
    "donor_voice": null | "human_female" | "creature/dragon" | ...,
    "pitch_shift": 0,          // semitones to shift TTS output
    "reverb": 0.0,             // wet mix 0.0-1.0
    "reverb_decay": 0.6,       // reverb tail seconds
    "bass_boost_db": 0,        // low-shelf gain below 250 Hz
    "treble_boost_db": 0,      // high-shelf gain above 4000 Hz
    "saturation": 0.0,         // harmonic saturation 0.0-1.0 (gritty/raspy)
    "speed": 1.0,               // playback speed 0.7-1.3 (1.0 = normal, <1 = slower)
    "status": "untested",      // untested / testing / approved
    "test_quest_id": null,     // for quick test regeneration
    "notes": ""
  }
"""

import json
import numpy as np
import librosa
import soundfile as sf
from pathlib import Path
from scipy.signal import butter, sosfilt, fftconvolve


PROJECT_ROOT = Path(__file__).parent.parent
CONFIGS_DIR = PROJECT_ROOT / "data" / "voice_configs"
SAMPLES_DIR = PROJECT_ROOT / "samples"

# ─── Config loading ───────────────────────────────────────────────────────

_config_cache = {}  # profile_name → config dict


def load_voice_config(profile_name):
    """Load a voice config JSON for a profile. Returns dict or None."""
    if profile_name in _config_cache:
        return _config_cache[profile_name]

    path = CONFIGS_DIR / f"{profile_name}.json"
    if not path.exists():
        _config_cache[profile_name] = None
        return None

    with open(path, encoding="utf-8") as f:
        config = json.load(f)

    _config_cache[profile_name] = config
    return config


def clear_config_cache():
    """Clear the in-memory config cache."""
    _config_cache.clear()


def save_voice_config(profile_name, config):
    """Save a voice config JSON file."""
    path = CONFIGS_DIR / f"{profile_name}.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    _config_cache[profile_name] = config


# ─── Profile key resolution ──────────────────────────────────────────────

def resolve_config_key(npc_name, race, sex, sample_dir, tier3_npcs=None):
    """Determine which voice config profile applies.

    Resolution order:
      1. Tier 3 custom NPCs (by custom folder name)
      2. Creature types (by sample_dir under creature/)
      3. Base race + sex (e.g. gnome_female, tauren_male)
      4. Narrator

    Returns config key string or None if no config exists.
    """
    # Tier 3 custom
    if tier3_npcs and npc_name in tier3_npcs:
        custom_name = tier3_npcs[npc_name]
        if load_voice_config(custom_name) is not None:
            return custom_name

    # Creature type
    if sample_dir and sample_dir.parent.name == "creature":
        creature_key = sample_dir.name
        if load_voice_config(creature_key) is not None:
            return creature_key

    # Base race + sex
    if race and race != "Narrator":
        race_lower = race.lower().replace(" ", "_")
        sex_key = sex if sex in ("male", "female") else "male"
        race_sex_key = f"{race_lower}_{sex_key}"
        if load_voice_config(race_sex_key) is not None:
            return race_sex_key

    # Narrator
    if load_voice_config("narrator") is not None:
        return "narrator"

    return None


def get_donor_samples_dir(config_key):
    """Get the donor voice sample directory for a config, or None.

    When a config has donor_voice set, the TTS engine should use the donor's samples
    instead of the profile's own samples for generation.

    Returns Path to donor sample dir, or None if no donor configured.
    """
    config = load_voice_config(config_key)
    if not config or not config.get("donor_voice"):
        return None

    donor = config["donor_voice"]
    donor_dir = SAMPLES_DIR / donor
    if donor_dir.is_dir():
        return donor_dir

    return None


def has_effects(config_key):
    """Check if a config has any post-processing effects enabled."""
    config = load_voice_config(config_key)
    if not config:
        return False
    return bool(
        config.get("pitch_shift", 0)
        or config.get("reverb", 0)
        or config.get("bass_boost_db", 0)
        or config.get("treble_boost_db", 0)
        or config.get("saturation", 0)
        or config.get("speed", 1.0) != 1.0
    )


# ─── DSP building blocks ─────────────────────────────────────────────────

def _add_reverb(y, sr, amount=0.2, decay=0.6):
    """Add reverb via convolution with synthetic impulse response."""
    n_samples = int(sr * decay)
    if n_samples < 1:
        return y
    t = np.linspace(0, decay, n_samples)
    rng = np.random.RandomState(42)
    impulse = np.exp(-t / (decay * 0.25)) * rng.randn(n_samples) * 0.02
    impulse[0] = 1.0
    peak = np.max(np.abs(impulse))
    if peak > 0:
        impulse /= peak

    wet = fftconvolve(y, impulse, mode='full')[:len(y)]
    rms_dry = np.sqrt(np.mean(y ** 2)) + 1e-10
    rms_wet = np.sqrt(np.mean(wet ** 2)) + 1e-10
    wet *= rms_dry / rms_wet

    return y * (1.0 - amount) + wet * amount


def _bass_boost(y, sr, gain_db=3.0, cutoff=250):
    """Low-shelf boost below cutoff frequency."""
    nyq = sr / 2
    if cutoff >= nyq:
        return y
    sos = butter(2, cutoff, btype='low', fs=sr, output='sos')
    low = sosfilt(sos, y)
    gain = 10 ** (gain_db / 20) - 1.0
    return y + low * gain


def _treble_boost(y, sr, gain_db=3.0, cutoff=4000):
    """High-shelf boost above cutoff frequency."""
    nyq = sr / 2
    if cutoff >= nyq:
        return y
    sos = butter(2, cutoff, btype='high', fs=sr, output='sos')
    high = sosfilt(sos, y)
    gain = 10 ** (gain_db / 20) - 1.0
    return y + high * gain


def _saturate(y, amount=0.3):
    """Harmonic saturation via tanh soft clipping.

    Adds odd harmonics that create a gritty, raspy "cigarette voice" quality.
    Amount 0.0 = clean, 0.3 = subtle grit, 0.7 = heavy rasp, 1.0 = aggressive.
    """
    if amount <= 0:
        return y
    drive = 1.0 + amount * 8.0  # map 0-1 to 1-9x drive
    wet = np.tanh(drive * y)
    # Blend: more amount = more saturated signal
    blend = min(amount, 1.0)
    return y * (1.0 - blend) + wet * blend


def _time_stretch(y, sr, speed=1.0):
    """Change tempo without affecting pitch via phase vocoder.

    speed < 1.0 = slower (e.g. 0.9 = 10% slower), speed > 1.0 = faster.
    """
    if speed == 1.0:
        return y
    return librosa.effects.time_stretch(y, rate=speed)


# ─── Loudness normalization ──────────────────────────────────────────────

# Target RMS in linear amplitude (~-15.5 dBFS).  Every output WAV is scaled
# so its RMS matches this value, making all clips sound equally loud in-game.
# Matches the typical loudness of WC3 voice reference samples.
TARGET_RMS = 0.17  # ≈ -15.4 dBFS

def normalize_loudness(wav_path):
    """Normalize a WAV file to a consistent loudness (TARGET_RMS) in-place.

    Scales audio so RMS matches TARGET_RMS, then hard-clips at ±1.0.
    Peaks that overshoot are the emphatic/emotional parts of speech —
    we keep the full dynamic range and only clip the very tips that
    would exceed the WAV format ceiling.  A few clipped samples at
    transient peaks are inaudible.
    """
    wav_path = Path(wav_path)
    y, sr = librosa.load(str(wav_path), sr=None)

    rms = np.sqrt(np.mean(y ** 2))
    if rms < 1e-8:          # essentially silence — leave it alone
        return

    y *= TARGET_RMS / rms
    np.clip(y, -1.0, 1.0, out=y)

    sf.write(str(wav_path), y, sr)


# ─── Post-processing: apply effects to generated output ──────────────────

def apply_voice_effects(wav_path, config_key):
    """Apply post-processing effects to a generated WAV file in-place.

    Reads the config for config_key and applies effects in order:
      1. Pitch shift (librosa phase vocoder)
      2. Reverb (synthetic impulse response convolution)
      3. Bass boost (low-shelf filter)
      4. Treble boost (high-shelf filter)
      5. Normalize to prevent clipping

    Args:
        wav_path:    Path to WAV file (modified in-place)
        config_key:  Key into voice configs, or None to skip
    """
    if not config_key:
        return

    config = load_voice_config(config_key)
    if not config:
        return

    pitch = config.get("pitch_shift", 0)
    reverb = config.get("reverb", 0)
    bass = config.get("bass_boost_db", 0)
    treble = config.get("treble_boost_db", 0)
    saturation = config.get("saturation", 0)
    speed = config.get("speed", 1.0)

    if not (pitch or reverb or bass or treble or saturation or speed != 1.0):
        return

    wav_path = Path(wav_path)
    y, sr = librosa.load(str(wav_path), sr=None)

    if speed != 1.0:
        y = _time_stretch(y, sr, speed=speed)

    if pitch:
        y = librosa.effects.pitch_shift(y, sr=sr, n_steps=pitch)

    if saturation:
        y = _saturate(y, amount=saturation)

    if reverb:
        decay = config.get("reverb_decay", 0.6)
        y = _add_reverb(y, sr, amount=reverb, decay=decay)

    if bass:
        y = _bass_boost(y, sr, gain_db=bass)

    if treble:
        y = _treble_boost(y, sr, gain_db=treble)

    # Prevent clipping
    peak = np.max(np.abs(y))
    if peak > 0.95:
        y *= 0.95 / peak

    sf.write(str(wav_path), y, sr)
