#!/usr/bin/env python3
"""The item score's stat weights, and ItemScoreData.lua written from them.

    python3 Tools/build/build_weights.py --pawn <path to a Pawn checkout>
    python3 Tools/build/build_weights.py

With --pawn the weights are worked out afresh and kept in
Tools/data/stat_weights.json. Without it, ItemScoreData.lua is written from
that file and from OctoPawn's tooltip patterns, soft caps and labels in
Tools/data/octopawn.json (import_octopawn.py keeps that one).

The weights are worked out from the game's own formulas. Each spec is weighed
in one unit: a point of attack power (ranged attack power for hunters), of
spell damage (casters), of healing (healers) or of Stamina (tanks). There are
two sets: leveling, worked out at level 30 with quest greens, used below 60;
and 60, for pre-raid gear. Tanks use their 60 set at every level.

1% more crit or hit is worth about a hundredth of what a point of damage
stands on: the attack power a melee hit is made of (its own, plus 14 for
each point of weapon DPS), or a spell's base damage over its coefficient
plus spell damage. A spec's talents raise or lower that (Impale, Ice Shards,
damage over time that never crits). Agility and Intellect add their share of
crit, at the rate for the level. Stamina, Spirit and mana are set for
leveling's downtime and danger, and are worth little in a raid.

Then each weight at 60 is moved three-quarters of the way to Pawn's Classic
Era scale for the spec (HawsJon's weights, as Pawn ships them), on a log
scale, and the leveling weight moves by the same factor -- except the stats
set for leveling (LEVELING_SET), which keep their leveling weight, never
below the one at 60. Pawn is a reference only: its file is read where it
lies, at build time, and none of it is kept -- only the weights worked out
here. Stats the model does not work out (Turtle WoW's own, resistances,
speed) keep OctoPawn's weight, rescaled to the spec's unit.
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "ItemScoreData.lua")
OCTOPAWN = os.path.join(ROOT, "Tools", "data", "octopawn.json")
WEIGHTS = os.path.join(ROOT, "Tools", "data", "stat_weights.json")

CLASS_ORDER = ["WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"]

# A stat the scorer adds that OctoPawn has not: a bow's, gun's, crossbow's,
# wand's or thrown weapon's DPS, apart from a melee weapon's.
EXTRA_LABELS = {"RANGED DPS": "RANGED WEAPON DPS"}

LEV, MAX = 30, 60

# Mechanics at 60.
AP_PER_STR = {"WARRIOR": 2, "PALADIN": 2, "SHAMAN": 2, "DRUID": 2, "ROGUE": 1, "HUNTER": 1}
AGI_PER_CRIT = {"WARRIOR": 20, "PALADIN": 20, "SHAMAN": 20, "DRUID": 20, "ROGUE": 29, "HUNTER": 53}
INT_PER_CRIT = {"MAGE": 59.5, "WARLOCK": 60.6, "PRIEST": 59.2, "DRUID": 60.0, "SHAMAN": 59.5, "PALADIN": 54.0}
AP_PER_DPS = 14.0

# What a point of damage stands on, in the spec's unit, at each level.
PHYS_E = {LEV: 550.0, MAX: 1900.0}
SPELL_B = {LEV: 250.0, MAX: 1000.0}


def per_level(v60, level):
    """Agility or Intellect per 1% crit falls with level, roughly in step."""
    return v60 * level / 60.0


def r(x):
    if x >= 10:
        return round(x, 1)
    if x >= 1:
        return round(x, 2)
    return round(x, 3)


def rescale_extras(octo, out, old_unit_stat, new_unit_value):
    """Stats the model does not work out keep OctoPawn's weight, rescaled to
    the new unit."""
    f = new_unit_value / octo[old_unit_stat] if octo.get(old_unit_stat) else 1.0
    for k in ("FORTUNE", "AVOIDANCE", "LIFESTEAL", "RESILIENCE", "MOVEMENT SPEED", "MOUNT SPEED",
              "FIRE RESISTANCE", "FROST RESISTANCE", "SHADOW RESISTANCE", "NATURE RESISTANCE",
              "ARCANE RESISTANCE", "ALL RESISTANCES", "ARMOR PENETRATION", "EXTRA ATTACK",
              "ATTACK POWER UNDEAD", "SPELL DAMAGE UNDEAD", "HEALTH PER 5"):
        if k in octo and k not in out:
            out[k] = octo[k] * f


# ----------------------------------------------------------------------------
# Physical damage: unit 1 attack power (hunters: 1 ranged attack power)

PHYS = {
    # spec: (crit mult, hit mult, weapon mult, notes)
    ("WARRIOR", "Arms"): (1.2, 1.0, 1.2, "Mortal Strike, Slam and Whirlwind hit with the weapon; Impale and Deep Wounds lift crit."),
    ("WARRIOR", "Fury"): (1.3, 1.2, 0.9, "Two weapons: each hand's DPS counts for that hand; Flurry lifts crit; more white swings miss."),
    ("ROGUE", "Assassination"): (1.3, 1.1, 0.9, "Lethality and Relentless Strikes lift crit; daggers."),
    ("ROGUE", "Combat"): (1.1, 1.2, 1.0, "Sinister Strike hits with the weapon; two weapons swing white."),
    ("ROGUE", "Subtlety"): (1.1, 1.0, 0.9, ""),
    ("PALADIN", "Retribution"): (1.1, 1.0, 1.0, "A slow two-hander: Seal of Command and Crusader Strike hit with it."),
    ("SHAMAN", "Enhancement"): (1.3, 1.1, 1.1, "Windfury and Stormstrike hit with the weapon; Flurry lifts crit."),
    ("DRUID", "FeralCat"): (1.1, 1.0, 0.0, "In cat form a weapon's DPS does nothing: only its stats and feral attack power count."),
    ("HUNTER", "BeastMastery"): (1.1, 1.0, 1.15, "Aimed and Multi-Shot add to the bow's damage; the pet does much of the work."),
    ("HUNTER", "Marksmanship"): (1.3, 1.0, 1.2, "Mortal Shots lifts crit."),
    ("HUNTER", "Survival"): (1.2, 1.0, 1.1, ""),
}


def physical(cls, level, crit_m, hit_m, wpn_m):
    E = PHYS_E[level]
    crit = E / 100.0 * crit_m
    hit = E / 100.0 * hit_m
    w = {}
    hunter = cls == "HUNTER"
    w["ATTACK POWER"] = 1.0
    if hunter:
        w["RANGED ATTACK POWER"] = 1.0
        w["STRENGTH"] = 0.1                       # melee attack power only
        agi_ap = 2.0                             # 2 ranged attack power
        w["DPS"] = 1.0 if level == MAX else 3.0    # the melee weapon: a stat stick
        w["RANGED DPS"] = AP_PER_DPS * wpn_m
        w["RANGED CRIT"] = crit
        w["CRIT"] = crit                          # plain crit counts for both
        w["RANGED HASTE"] = hit * 0.9
    else:
        w["STRENGTH"] = AP_PER_STR[cls]
        agi_ap = 1.0 if cls in ("ROGUE", "DRUID") else 0.0
        w["DPS"] = AP_PER_DPS * wpn_m
        w["RANGED DPS"] = 0.5 if level == LEV else 0.2   # a thrown weapon or bow to pull with
        w["CRIT"] = crit
    if cls == "DRUID":
        w["FERAL ATTACK POWER"] = 1.0
        w["DPS"] = 0.0
        w["RANGED DPS"] = 0.0
    w["HIT"] = hit
    w["AGILITY"] = agi_ap + crit / per_level(AGI_PER_CRIT[cls], level) + (0.1 if level == LEV else 0.04)
    w["HASTE"] = hit * 0.9
    # Surviving while you level; next to nothing in a raid.
    w["STAMINA"] = (0.8 if hunter else 1.0) if level == LEV else 0.25
    w["HEALTH"] = w["STAMINA"] / 10.0
    w["ARMOR"] = 0.05 if level == LEV else 0.02
    w["SPIRIT"] = 0.3 if level == LEV and cls in ("WARRIOR", "ROGUE") else (0.15 if level == LEV else 0.02)
    w["DODGE"] = crit * (0.5 if level == LEV else 0.1)
    w["PARRY"] = 0.0 if hunter or cls == "DRUID" else crit * (0.4 if level == LEV else 0.1)
    w["DEFENSE"] = 0.4 if level == LEV else 0.1
    # Mana, for the classes that have it.
    if cls in ("PALADIN", "SHAMAN", "HUNTER"):
        w["INTELLECT"] = 0.6 if level == LEV else 0.35
        w["MANA"] = w["INTELLECT"] / 15.0
        w["MANA PER 5"] = 1.2 if level == LEV else 0.8
        w["SPIRIT"] = 0.2 if level == LEV else 0.05
    if cls == "DRUID":
        w["INTELLECT"] = 0.25 if level == LEV else 0.15    # shifting costs mana
        w["MANA"] = w["INTELLECT"] / 15.0
        w["MANA PER 5"] = 0.6 if level == LEV else 0.3
    if cls == "PALADIN":
        w["SPELL POWER"] = 0.4 if level == LEV else 0.3      # Seal of Righteousness, Consecration
        w["HOLY DAMAGE"] = w["SPELL POWER"]
        w["SPELL CRIT"] = 0.0
        w["HOLY CRIT"] = crit * 0.2
    if cls == "SHAMAN":
        w["SPELL POWER"] = 0.4 if level == LEV else 0.25     # shocks
        w["NATURE DAMAGE"] = w["SPELL POWER"] * 0.8
        w["FROST DAMAGE"] = w["SPELL POWER"] * 0.6
        w["FIRE DAMAGE"] = w["SPELL POWER"] * 0.5
    w["BLOCK"] = crit * 0.2 if level == LEV and cls in ("PALADIN", "SHAMAN", "WARRIOR") else 0.0
    w["BLOCK VALUE"] = 0.15 if level == LEV and cls in ("PALADIN", "SHAMAN", "WARRIOR") else 0.0
    w["HEALING"] = 0.15 if level == LEV and cls in ("PALADIN", "SHAMAN", "DRUID") else 0.0
    return w


# ----------------------------------------------------------------------------
# Casters: unit 1 spell damage

CASTERS = {
    # spec: (crit bonus, main schools, int mana value (lev, max), spirit (lev, max), stamina (lev, max), notes)
    ("MAGE", "Arcane"): (0.5, {"ARCANE DAMAGE": 1.0, "FROST DAMAGE": 0.6, "FIRE DAMAGE": 0.3}, (0.4, 0.35), (0.35, 0.15), (0.4, 0.12), "Arcane Meditation keeps some Spirit regen while casting."),
    ("MAGE", "Fire"): (0.9, {"FIRE DAMAGE": 1.0, "FROST DAMAGE": 0.3, "ARCANE DAMAGE": 0.3}, (0.35, 0.25), (0.35, 0.05), (0.4, 0.12), "Ignite adds 40% of each crit."),
    ("MAGE", "Frost"): (1.0, {"FROST DAMAGE": 1.0, "FIRE DAMAGE": 0.25, "ARCANE DAMAGE": 0.2}, (0.35, 0.25), (0.35, 0.05), (0.4, 0.12), "Ice Shards doubles a crit."),
    ("WARLOCK", "Affliction"): (0.25, {"SHADOW DAMAGE": 1.0, "FIRE DAMAGE": 0.25}, (0.15, 0.1), (0.5, 0.08), (0.85, 0.3), "Damage over time never crits; Life Tap turns health into mana and Drain Life keeps you up, so Stamina and Spirit (health regen) carry you while leveling."),
    ("WARLOCK", "Demonology"): (0.5, {"SHADOW DAMAGE": 1.0, "FIRE DAMAGE": 0.4}, (0.2, 0.15), (0.35, 0.05), (0.7, 0.3), "Demonic Embrace and the pet: Stamina is worth more."),
    ("WARLOCK", "Destruction"): (1.0, {"FIRE DAMAGE": 0.85, "SHADOW DAMAGE": 1.0}, (0.2, 0.15), (0.3, 0.05), (0.6, 0.2), "Ruin doubles a crit; Shadow Bolt is the main spell, Immolate and Conflagrate the fire."),
    ("PRIEST", "Shadow"): (0.25, {"SHADOW DAMAGE": 1.0, "HOLY DAMAGE": 0.2}, (0.35, 0.2), (0.6, 0.1), (0.5, 0.15), "Mind Flay and Shadow Word: Pain never crit; Spirit Tap makes Spirit the leveling regen."),
    ("DRUID", "Balance"): (0.75, {"NATURE DAMAGE": 1.0, "ARCANE DAMAGE": 0.9}, (0.35, 0.25), (0.35, 0.1), (0.45, 0.15), "Vengeance lifts Wrath's and Starfire's crits."),
    ("SHAMAN", "Elemental"): (1.0, {"NATURE DAMAGE": 1.0, "FIRE DAMAGE": 0.5, "FROST DAMAGE": 0.4}, (0.35, 0.25), (0.3, 0.1), (0.45, 0.15), "Elemental Fury doubles a crit."),
}


def caster(cls, level, crit_b, schools, intv, spiv, stav):
    B = SPELL_B[level]
    i = 0 if level == LEV else 1
    crit = B / 100.0 * crit_b
    hit = B / 100.0
    w = {"SPELL DAMAGE": 1.0, "SPELL POWER": 1.0}
    for k, v in schools.items():
        w[k] = v
    w["SPELL CRIT"] = crit
    w["SPELL HIT"] = hit
    w["HASTE"] = hit * 0.9
    w["INTELLECT"] = intv[i] + crit / per_level(INT_PER_CRIT[cls], level)
    w["MANA"] = intv[i] / 15.0
    w["SPIRIT"] = spiv[i]
    w["STAMINA"] = stav[i]
    w["HEALTH"] = stav[i] / 10.0
    w["MANA PER 5"] = (1.5 if level == LEV else 2.0) * (0.6 if cls == "WARLOCK" else 1.0)
    w["CASTING REGEN"] = 2.0 if level == LEV else 1.5
    w["SPELL PENETRATION"] = 0.3 if level == LEV else 0.6
    w["HEALING"] = 0.25 if level == LEV and cls in ("PRIEST", "DRUID", "SHAMAN") else 0.05
    w["ARMOR"] = 0.03 if level == LEV else 0.01
    w["DODGE"] = 1.0 if level == LEV else 0.2
    w["DEFENSE"] = 0.2 if level == LEV else 0.05
    w["DPS"] = 0.05
    w["RANGED DPS"] = 3.0 if level == LEV else 0.5     # the wand that finishes a mob
    w["AGILITY"] = 0.03
    w["STRENGTH"] = 0.02
    return w


# ----------------------------------------------------------------------------
# Healers: unit 1 healing

HEALERS = {
    # spec: (mp5 (lev,max), int (lev,max), spirit (lev,max), crit (lev,max), damage side (lev,max), notes)
    ("PRIEST", "Holy"): ((1.5, 2.5), (0.5, 0.7), (0.6, 0.7), (3.0, 6.0), (0.4, 0.1), "Spirit keeps the mana coming between pulls; Holy Fire and Smite while leveling."),
    ("PRIEST", "Discipline"): ((1.5, 2.5), (0.6, 0.8), (0.6, 0.6), (3.0, 6.0), (0.5, 0.15), "Mental Strength makes Intellect worth more."),
    ("PALADIN", "Holy"): ((1.3, 2.0), (0.6, 1.0), (0.3, 0.15), (5.0, 12.0), (0.4, 0.15), "Illumination refunds the mana of a healing crit: crit and Intellect count double."),
    ("DRUID", "Restoration"): ((1.5, 2.5), (0.5, 0.6), (0.6, 0.6), (2.5, 5.0), (0.4, 0.1), ""),
    ("SHAMAN", "Restoration"): ((1.5, 2.5), (0.5, 0.6), (0.4, 0.3), (3.0, 6.0), (0.4, 0.1), "Mana per 5 over Spirit: shamans regenerate little from Spirit."),
}


def healer(cls, level, mp5, intv, spiv, critv, dmg):
    i = 0 if level == LEV else 1
    w = {"HEALING": 1.0, "SPELL POWER": dmg[i], "SPELL DAMAGE": dmg[i]}
    w["MANA PER 5"] = mp5[i]
    w["INTELLECT"] = intv[i]
    w["MANA"] = intv[i] / 20.0
    w["SPIRIT"] = spiv[i]
    w["SPELL CRIT"] = critv[i]
    if cls in ("PALADIN", "PRIEST"):
        w["HOLY CRIT"] = critv[i]
        w["HOLY DAMAGE"] = dmg[i]
    w["CASTING REGEN"] = 2.6 if level == MAX else 2.0
    w["STAMINA"] = 0.5 if level == LEV else 0.15
    w["HEALTH"] = w["STAMINA"] / 10.0
    w["SPELL HIT"] = 0.3 if level == LEV else 0.05
    w["HASTE"] = 3.0 if level == LEV else 5.0
    w["ARMOR"] = 0.03 if level == LEV else 0.01
    w["DODGE"] = 1.0 if level == LEV else 0.2
    w["DEFENSE"] = 0.2 if level == LEV else 0.05
    w["DPS"] = 0.05
    w["RANGED DPS"] = 2.0 if level == LEV and cls == "PRIEST" else 0.3
    w["AGILITY"] = 0.03
    w["STRENGTH"] = 0.15 if cls in ("PALADIN", "SHAMAN") and level == LEV else 0.02
    return w


# ----------------------------------------------------------------------------
# Tanks: unit 1 Stamina, the same set at every level.

TANKS = {
    ("WARRIOR", "Protection"): "Stamina, Defense and avoidance at every level, as a tank levels in a group.",
    ("PALADIN", "Protection"): "Holy Shield and Consecration make spell damage threat.",
    ("DRUID", "FeralBear"): "Bears cannot parry or block; armor counts several times over in bear form.",
    ("SHAMAN", "EnhancementTank"): "Turtle WoW's shaman tank: shield, shocks for threat.",
}


def tank(cls, spec):
    bear = spec == "FeralBear"
    w = {"STAMINA": 1.0, "HEALTH": 0.1}
    w["DEFENSE"] = 1.5
    w["DODGE"] = 15.0
    w["PARRY"] = 0.0 if bear else 13.0
    w["BLOCK"] = 0.0 if bear else (9.0 if cls == "PALADIN" else 7.0)
    w["BLOCK VALUE"] = 0.0 if bear else (0.35 if cls == "PALADIN" else 0.25)
    w["ARMOR"] = 0.13 if bear else 0.1
    w["AGILITY"] = (15.0 / 20.0) + 2 * w["ARMOR"] + (0.2 if bear else 0.0)
    w["STRENGTH"] = 0.45 if bear else 0.35
    w["ATTACK POWER"] = 0.2 if bear else 0.15
    if bear:
        w["FERAL ATTACK POWER"] = 0.2
    w["HIT"] = 7.0
    w["CRIT"] = 3.0
    w["DPS"] = 0.0 if bear else 3.0
    w["RANGED DPS"] = 0.3 if not bear else 0.0
    w["SPIRIT"] = 0.02
    if cls in ("PALADIN", "SHAMAN"):
        w["SPELL POWER"] = 0.5 if cls == "PALADIN" else 0.3
        w["HOLY DAMAGE" if cls == "PALADIN" else "NATURE DAMAGE"] = w["SPELL POWER"]
        w["INTELLECT"] = 0.3
        w["MANA"] = 0.02
        w["MANA PER 5"] = 0.6
    if cls == "DRUID":
        w["INTELLECT"] = 0.1
    return w


# ----------------------------------------------------------------------------
# Pawn's Classic Era scales, on our stat names and units: the calibration.

PAWN_DUMP = r"""
-- Pawn's ClassicHawsJon.lua adds its scales through a function it hands to
-- Pawn; that function is caught here and run with the game stubbed out.
local path = arg[1]
local fh = assert(io.open(path, "rb"))
local text = string.gsub(fh:read("*a"), "^\239\187\191", "")
fh:close()
local scales, provider = {}, nil
local function noop() end
local env = setmetatable({
	VgerCore = { IsClassic = true },
	PawnLocal = { UI = {} },
	PawnAddPluginScaleProvider = function(_, _, fn) provider = fn end,
	PawnAddPluginScaleFromTemplate = function(_, class, spec, t)
		table.insert(scales, { class = class, spec = spec, stats = t })
		return {}
	end,
	PawnGetClassInfo = function() return "Class" end,
	PawnIgnoreStatValue = -1000000, SECONDARYHANDSLOT = "Off Hand",
	pairs = pairs, ipairs = ipairs, select = select, table = table, string = string, math = math,
	tonumber = tonumber, tostring = tostring, type = type,
}, { __index = function() return noop end })
local f = assert(loadstring(text))
setfenv(f, env)
f()
-- The scales are added first; what follows them needs the game, and may stop.
pcall(provider or env.PawnClassicScaleProvider_AddScales)
for _, e in ipairs(scales) do
	if e.spec and type(e.stats) == "table" then
		for k, v in pairs(e.stats) do
			if type(v) == "number" then io.write(e.class, "\t", e.spec, "\t", k, "\t", string.format("%.6f", v), "\n") end
		end
	end
end
"""

PAWN_CLASS = {1: "WARRIOR", 2: "PALADIN", 3: "HUNTER", 4: "ROGUE", 5: "PRIEST", 7: "SHAMAN", 8: "MAGE", 9: "WARLOCK", 11: "DRUID"}
PAWN_SPEC = {
    "WARRIOR": ["Arms", "Fury", "Protection"], "PALADIN": ["Holy", "Protection", "Retribution"],
    "HUNTER": ["BeastMastery", "Marksmanship", "Survival"], "ROGUE": ["Assassination", "Combat", "Subtlety"],
    "PRIEST": ["Discipline", "Holy", "Shadow"], "SHAMAN": ["Elemental", "Enhancement", "Restoration"],
    "MAGE": ["Arcane", "Fire", "Frost"], "WARLOCK": ["Affliction", "Demonology", "Destruction"],
    "DRUID": ["Balance", "FeralCat", "FeralBear", "Restoration"],
}
PAWN_MAP = {
    "Strength": ["STRENGTH"], "Agility": ["AGILITY"], "Stamina": ["STAMINA"], "Intellect": ["INTELLECT"],
    "Spirit": ["SPIRIT"], "Ap": ["ATTACK POWER"], "Rap": ["RANGED ATTACK POWER"], "FeralAp": ["FERAL ATTACK POWER"],
    "HitRating": ["HIT"], "CritRating": ["CRIT"], "SpellHitRating": ["SPELL HIT"], "SpellCritRating": ["SPELL CRIT"],
    "Mp5": ["MANA PER 5"], "Hp5": ["HEALTH PER 5"], "Healing": ["HEALING"],
    "SpellDamage": ["SPELL POWER", "SPELL DAMAGE"], "FireSpellDamage": ["FIRE DAMAGE"],
    "FrostSpellDamage": ["FROST DAMAGE"], "ArcaneSpellDamage": ["ARCANE DAMAGE"], "ShadowSpellDamage": ["SHADOW DAMAGE"],
    "NatureSpellDamage": ["NATURE DAMAGE"], "HolySpellDamage": ["HOLY DAMAGE"], "Armor": ["ARMOR"],
    "DefenseRating": ["DEFENSE"], "DodgeRating": ["DODGE"], "ParryRating": ["PARRY"], "BlockRating": ["BLOCK"],
    "BlockValue": ["BLOCK VALUE"], "Health": ["HEALTH"], "Mana": ["MANA"], "SpellPenetration": ["SPELL PENETRATION"],
}
UNIT_STAT = {"Damage (physical)": "ATTACK POWER", "Damage (spells)": "SPELL DAMAGE", "Healing": "HEALING", "Tanking": "STAMINA"}


def find_pawn_scales(path):
    if os.path.isfile(path):
        return path
    for dirpath, _, files in os.walk(path):
        if "ClassicHawsJon.lua" in files:
            return os.path.join(dirpath, "ClassicHawsJon.lua")
    sys.exit("No ClassicHawsJon.lua under %s" % path)


def pawn_reference(path, roles):
    """{ "CLASS:Spec": { stat: weight in the spec's unit } } from Pawn."""
    with tempfile.TemporaryDirectory() as tmp:
        script = os.path.join(tmp, "pawn_dump.lua")
        with open(script, "w") as fh:
            fh.write(PAWN_DUMP)
        raw = subprocess.run(["lua5.1", script, find_pawn_scales(path)],
                             check=True, capture_output=True, text=True).stdout
    scales = {}
    for line in raw.splitlines():
        cls, spec, stat, v = line.split("\t")
        cls = PAWN_CLASS.get(int(float(cls)))
        if not cls:
            continue
        key = "%s:%s" % (cls, PAWN_SPEC[cls][int(float(spec)) - 1])
        scales.setdefault(key, {})[stat] = float(v)
    out = {}
    for key, s in scales.items():
        mine = {}
        for k, v in s.items():
            for t in PAWN_MAP.get(k, []):
                mine[t] = v
        mine["DPS"] = s.get("Dps", 0) + s.get("MeleeDps", 0)
        mine["RANGED DPS"] = s.get("Dps", 0) + s.get("RangedDps", 0)
        mine["HASTE"] = s.get("HasteRating", 0) or s.get("SpellHasteRating", 0)
        cls = key.split(":")[0]
        if cls == "HUNTER":
            mine["RANGED CRIT"] = mine.get("CRIT", 0)
        if key not in roles:
            continue
        unit = "RANGED ATTACK POWER" if cls == "HUNTER" else UNIT_STAT[roles[key]]
        base = mine.get(unit)
        if not base and unit == "RANGED ATTACK POWER":
            base = mine.get("ATTACK POWER")
        base = base or 1.0
        out[key] = {k: v / base for k, v in mine.items() if v and v > -1000}
    return out


PULL = 0.75
# A bow's DPS is 14 ranged attack power on every Auto Shot; Pawn's is kept out.
KEEP = {("HUNTER", "RANGED DPS")}
DERIVED = {"HEALTH", "MANA"}
# Set for leveling's downtime and danger; a non-tank's dodge, parry and block
# are a share of crit, and move with it.
LEVELING_SET = {"STAMINA", "HEALTH", "SPIRIT", "INTELLECT", "MANA", "MANA PER 5", "CASTING REGEN",
                "DEFENSE", "ARMOR"}


def factors(cls, pawn, mx):
    """How far each weight at 60 moves toward Pawn's: new / old."""
    f = {}
    for k, v in mx.items():
        pv = pawn.get(k)
        if not pv or pv <= 0 or not v or v <= 0 or (cls, k) in KEEP or k in DERIVED:
            continue
        f[k] = (pv * (v / pv) ** (1 - PULL)) / v
    return f


def work_out(octo_weights, pawn_path):
    specs = {}
    for (cls, spec), (cm, hm, wm, note) in PHYS.items():
        specs[(cls, spec)] = dict(lev=physical(cls, LEV, cm, hm, wm), max=physical(cls, MAX, cm, hm, wm),
                                  unit="ranged attack power" if cls == "HUNTER" else "attack power",
                                  unit_stat="RANGED ATTACK POWER" if cls == "HUNTER" else "ATTACK POWER",
                                  notes=note, role="Damage (physical)")
    for (cls, spec), (cb, sch, iv, sv, stv, note) in CASTERS.items():
        specs[(cls, spec)] = dict(lev=caster(cls, LEV, cb, sch, iv, sv, stv), max=caster(cls, MAX, cb, sch, iv, sv, stv),
                                  unit="spell damage", unit_stat="SPELL DAMAGE", notes=note, role="Damage (spells)")
    for (cls, spec), (m5, iv, sv, cv, dm, note) in HEALERS.items():
        specs[(cls, spec)] = dict(lev=healer(cls, LEV, m5, iv, sv, cv, dm), max=healer(cls, MAX, m5, iv, sv, cv, dm),
                                  unit="healing", unit_stat="HEALING", notes=note, role="Healing")
    for (cls, spec), note in TANKS.items():
        specs[(cls, spec)] = dict(lev=None, max=tank(cls, spec), unit="Stamina", unit_stat="STAMINA",
                                  notes=note, role="Tanking")

    roles = {"%s:%s" % k: e["role"] for k, e in specs.items()}
    pawn = pawn_reference(pawn_path, roles)
    if not pawn:
        sys.exit("Read no scales from Pawn's file")
    # A spec Pawn has no scale for (Turtle WoW's shaman tank) is left as worked out.
    for key in sorted(set(roles) - set(pawn)):
        print("Pawn has no scale for %s: left as worked out" % key)

    result = {}
    for (cls, spec), e in specs.items():
        key = "%s:%s" % (cls, spec)
        lev, mx = e["lev"], e["max"]
        f = factors(cls, pawn.get(key, {}), mx)
        for k in list(mx):
            if k in f:
                mx[k] *= f[k]
        if "MANA" in mx and "INTELLECT" in f:
            mx["MANA"] *= f["INTELLECT"]
        if "HEALTH" in mx and "STAMINA" in f:
            mx["HEALTH"] *= f["STAMINA"]
        if lev is not None:
            for k in list(lev):
                if k in LEVELING_SET:
                    if k in mx and mx[k] > lev[k]:
                        lev[k] = mx[k]
                elif k in f:
                    lev[k] *= f[k]
        entry = {"class": cls, "spec": spec, "role": e["role"], "unit": e["unit"], "notes": e["notes"]}
        octo = octo_weights[cls][spec]
        for name, w in (("leveling", lev), ("max", mx)):
            if w is None:
                continue
            rescale_extras(octo, w, e["unit_stat"], w.get(e["unit_stat"], 1.0))
            entry[name] = {k: r(v) for k, v in sorted(w.items()) if r(v) != 0}
        result[key] = entry

    have = {"%s:%s" % (c, s) for c in octo_weights for s in octo_weights[c]}
    if have != set(result):
        sys.exit("Specs differ from OctoPawn's: %s" % sorted(have ^ set(result)))
    return result


# ----------------------------------------------------------------------------
# ItemScoreData.lua

def lua_str(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def num(v):
    s = ("%.4f" % float(v)).rstrip("0").rstrip(".")
    return s or "0"


def weights_table(lua, name, specs, which):
    lua.append("\t%s = {" % name)
    by_class = {}
    for e in specs.values():
        if which in e:
            by_class.setdefault(e["class"], {})[e["spec"]] = e[which]
    for cls in CLASS_ORDER + sorted(set(by_class) - set(CLASS_ORDER)):
        if cls not in by_class:
            continue
        lua.append("\t\t%s = {" % cls)
        for spec in sorted(by_class[cls]):
            lua.append("\t\t\t%s = {" % spec)
            for stat in sorted(by_class[cls][spec]):
                lua.append("\t\t\t\t[%s] = %s," % (lua_str(stat), num(by_class[cls][spec][stat])))
            lua.append("\t\t\t},")
        lua.append("\t\t},")
    lua.append("\t},")


def write_data():
    with open(OCTOPAWN, encoding="utf-8") as fh:
        octo = json.load(fh)
    with open(WEIGHTS, encoding="utf-8") as fh:
        specs = json.load(fh)["specs"]
    labels = dict(octo["labels"])
    labels.update(EXTRA_LABELS)
    stats = sorted(labels)

    lua = [
        "-- ItemScoreData.lua",
        "--",
        "-- GENERATED FILE -- do not edit by hand.",
        "-- Weights:   this addon's own, worked out from the game's formulas and",
        "--            calibrated toward Pawn's Classic Era scales (HawsJon's), in",
        "--            Tools/data/stat_weights.json. Turtle WoW's own stats keep",
        "--            OctoPawn's weight, rescaled.",
        "-- Patterns:  OctoPawn's stat patterns, soft caps and labels",
        "--            (https://github.com/iGreed1993/OctoPawn)",
        "-- Generator: Tools/build/build_weights.py (OctoPawn's data through",
        "--            Tools/build/import_octopawn.py)",
        "--",
        "-- OctoPawn's licence, which covers its data:",
        "--",
    ]
    lua += ["-- " + l if l else "--" for l in octo["licence"].split("\n")]
    lua += ["", "AegisPathfinder.ItemScoreData = {"]

    lua.append("\t-- Every stat the scorer knows, in a fixed order (the options panel's).")
    lua.append("\tstats = {")
    for s in stats:
        lua.append("\t\t%s," % lua_str(s))
    lua.append("\t},")

    lua.append("\t-- How the options panel names a stat.")
    lua.append("\tlabels = {")
    for s in stats:
        if labels[s] != s:
            lua.append("\t\t[%s] = %s," % (lua_str(s), lua_str(labels[s])))
    lua.append("\t},")

    lua.append("\t-- class -> spec -> stat -> weight at level 60 (a stat with no weight counts 0).")
    weights_table(lua, "weights", specs, "max")
    lua.append("\t-- The same below level 60. A spec not here -- the tanks -- uses its 60 set.")
    weights_table(lua, "leveling", specs, "leveling")

    lua.append("\t-- { upper-case text on a tooltip line, the stat it adds to }. In order:")
    lua.append("\t-- a line's first match for a stat wins, so the specific come first.")
    lua.append("\tpatterns = {")
    for pat, stat in octo["patterns"]:
        lua.append("\t\t{ %s, %s }," % (lua_str(pat), lua_str(stat)))
    lua.append("\t},")

    lua.append("\t-- Soft caps: past `cap`, each further point counts `after` of one.")
    lua.append("\tsoftcaps = {")
    for stat in sorted(octo["softcaps"]):
        cap, after = octo["softcaps"][stat]
        lua.append("\t\t[%s] = { cap = %s, after = %s }," % (lua_str(stat), num(cap), num(after)))
    lua.append("\t},")
    lua.append("}")
    lua.append("")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lua))
    print("wrote %s: %d specs (%d with a leveling set), %d stats, %d patterns, %d soft caps"
          % (os.path.relpath(OUT, ROOT), len(specs), sum(1 for e in specs.values() if "leveling" in e),
             len(stats), len(octo["patterns"]), len(octo["softcaps"])))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--pawn", help="a Pawn checkout (or its ClassicHawsJon.lua): work the weights out afresh")
    args = ap.parse_args()
    if args.pawn:
        with open(OCTOPAWN, encoding="utf-8") as fh:
            octo = json.load(fh)
        specs = work_out(octo["weights"], args.pawn)
        about = ("The item score's stat weights, written by Tools/build/build_weights.py: 'max' is the "
                 "set at level 60, 'leveling' the set below it (none for the tanks, who use 'max'). "
                 "Each spec's unit is a point of the stat named in 'unit'.")
        with open(WEIGHTS, "w", encoding="utf-8") as fh:
            json.dump({"about": about, "specs": specs}, fh, indent=1, sort_keys=True)
            fh.write("\n")
        print("wrote %s: %d specs" % (os.path.relpath(WEIGHTS, ROOT), len(specs)))
    write_data()
    return 0


if __name__ == "__main__":
    sys.exit(main())
