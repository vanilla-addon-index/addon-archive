#!/usr/bin/env python3
"""Write a guide for each class quest milestone: the Voidwalker, Bear Form,
the Felsteed, Rhok'delar -- one guide each, per side.

    python3 Tools/build/build_class_guides.py              # write Guides/Class/
    python3 Tools/build/build_class_guides.py --check      # fail if they are stale
    python3 Tools/build/build_class_guides.py --list       # the milestones, and each race's chain
    python3 Tools/build/build_class_guides.py --pfquest DIR --pfquest-turtle DIR --cmangos FILE
                                                     # read the quest data again first

A milestone is a chain of class quests that ends in something the class
keeps: a spell or form (Summon Voidwalker, Bear Form, Redemption, a totem),
a mount (Felsteed, Warhorse, Dreadsteed, Charger) or a class item (the
Enchanted Gold Bloodrobe, Rhok'delar, Benediction). The raid tiers' armour
exchanges -- Zul'Gurub's Paragons of Power, Ahn'Qiraj's and Naxxramas'
sets, the dungeon set's upgrade and Turtle WoW's tier vendors -- are not
class quests in that sense, and are left out.

Chains are found from the data: pfQuest's "quests before", CMaNGOS'
NextQuestInChain and PrevQuestId. Chains that end in the same thing are one
milestone, and each race gets the chain that starts in its home city: an
Undead warlock's Voidwalker is Carendin Halgar's, in the Undercity; an Orc's
is Gan'rul Bloodeye's, in Orgrimmar. A quest that only sends you to the
chain -- "Heeding the Call", "Gan'rul's Summons" -- is optional (|O|): the
chain's first quest is given without it. A milestone with a group, dungeon
or raid quest in it is a group milestone: it is offered only in Group mode
(NextGuideFrame.lua), though its guide is in the list for anyone.

The guide itself is simple: each quest in order, picked up, done and handed
in, with the arrow on whoever gives it, the place its objectives are, and
whoever takes it back. A quest inside a dungeon or raid points at the way in.
What can be done where you are comes first -- a hand-in, then a pick-up --
and a quest that gives what another asks for is handed in before that one's
objectives. Each race's steps are merged into one guide, |R| on the ones not
every race takes; at the end of each file, RegisterClassMilestones tells the
offer each milestone's level, quests and last hand-in, per race.

Reading the data takes all three sources, so what the guides are written
from is kept in Tools/data/class_quests.json: --check needs none of them.
The data is pfQuest's (https://github.com/shagu/pfQuest), with The Kludge
Bureau's pfQuest-turtle (https://github.com/The-Kludge-Bureau/pfQuest-turtle)
over it for Turtle WoW's races and quests, and CMaNGOS classic-db's
quest_template for the chains, quest types and rewards.
"""

import argparse
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, "Tools", "data", "class_quests.json")
OUT = os.path.join(ROOT, "Guides", "Class")

ALLIANCE, HORDE = 1 | 4 | 8 | 64 | 512, 2 | 16 | 32 | 128 | 256
SIDES = (("Alliance", ALLIANCE), ("Horde", HORDE))
CLASSES = ((1, "Warrior"), (2, "Paladin"), (4, "Hunter"), (8, "Rogue"),
           (16, "Priest"), (64, "Shaman"), (128, "Mage"), (256, "Warlock"),
           (1024, "Druid"))
# As UnitRace names them, which is what Parser.lua matches |R| against.
RACES = ((1, "Human"), (2, "Orc"), (4, "Dwarf"), (8, "Night Elf"), (16, "Undead"),
         (32, "Tauren"), (64, "Gnome"), (128, "Troll"), (256, "Goblin"),
         (512, "High Elf"))

# Where each race's class trainers are: a chain given here is that race's.
HOME = {
    "Human": ["Stormwind City", "Elwynn Forest"],
    "Dwarf": ["Ironforge", "Dun Morogh"],
    "Gnome": ["Ironforge", "Dun Morogh"],
    "Night Elf": ["Darnassus", "Teldrassil"],
    "High Elf": ["Alah'Thalas", "Thalassian Highlands"],
    "Orc": ["Orgrimmar", "Durotar"],
    "Troll": ["Orgrimmar", "Durotar"],
    "Goblin": ["Blackstone Island", "Orgrimmar", "Durotar"],
    "Undead": ["Undercity", "Tirisfal Glades"],
    "Tauren": ["Thunder Bluff", "Mulgore"],
}
# Where each race is before level 20: its starting zone. A quest given both
# there and in the city is picked up there -- a level-10 Human warrior takes
# A Warrior's Training from Lyria Du Lac in Goldshire, not Ilsa Corbin in
# Stormwind.
START = {
    "Human": "Elwynn Forest", "Dwarf": "Dun Morogh", "Gnome": "Dun Morogh",
    "Night Elf": "Teldrassil", "High Elf": "Thalassian Highlands",
    "Orc": "Durotar", "Troll": "Durotar", "Goblin": "Blackstone Island",
    "Undead": "Tirisfal Glades", "Tauren": "Mulgore",
}
YOUNG = 20

# The world map's zones (Tools/verify.py's MAP_ZONES): a step's waypoint has
# to be on one of them.
MAP_ZONES = {
    "Ashenvale", "Azshara", "Darkshore", "Darnassus", "Desolace", "Durotar", "Dustwallow Marsh",
    "Felwood", "Feralas", "Moonglade", "Mulgore", "Orgrimmar", "Silithus", "Stonetalon Mountains",
    "Tanaris", "Teldrassil", "The Barrens", "Thousand Needles", "Thunder Bluff", "Un'Goro Crater",
    "Winterspring",
    "Alterac Mountains", "Arathi Highlands", "Badlands", "Blasted Lands", "Burning Steppes",
    "Deadwind Pass", "Dun Morogh", "Duskwood", "Eastern Plaguelands", "Elwynn Forest",
    "Hillsbrad Foothills", "Ironforge", "Loch Modan", "Redridge Mountains", "Searing Gorge",
    "Silverpine Forest", "Stormwind City", "Stranglethorn Vale", "Swamp of Sorrows",
    "The Hinterlands", "Tirisfal Glades", "Undercity", "Western Plaguelands", "Westfall", "Wetlands",
}
# Turtle WoW's own zones. Their maps overlap the old ones, and pfQuest puts
# one NPC in both -- Furen Longbeard in Stormwind and in Northwind: the old
# zone is the one to name, unless the new one is home.
TURTLE_ZONES = {
    "Alah'Thalas", "Balor", "Blackstone Island", "Gillijim's Isle", "Gilneas", "Grim Reaches",
    "Hyjal", "Icepoint Rock", "Lapidis Isle", "Moonwhisper Coast", "Northwind",
    "Scarlet Enclave", "Tel'Abim", "Thalassian Highlands",
}
MAP_ZONES |= TURTLE_ZONES

MIN_LEVEL = 4        # below this a class quest is a starting zone's, and its guide has it

# The raid tiers' and the dungeon set's exchanges: who hands them out.
EXCHANGE_NPCS = {
    "Al'tabim the All-Seeing", "Zanza the Restless", "Deliana", "Mokvar", "Anthion Harmon",
    "Kandrostrasz", "Vethsera", "Andorgos", "Keyl Swiftclaw", "Windcaller Yessendra", "Warden Haro",
    "Mataus the Wrathcaster", "Melus Ironeye", "Kazud Fireforged", "Geldra Bronzewhiskers",
    "Hierophant Nerseus", "Anelace the Clairvoyant", "Hanvar the Righteous", "Anachronos",
    "Huntsman Leopold", "Rohan the Assassin", "Father Inigo Montoy", "Korfax, Champion of the Light",
    "Commander Eligor Dawnbringer", "Rimblat Earthshatter", "Rayne", "Archmage Angela Dosantos",
    "Lieutenant General Andorov",
    # Zul'Gurub's, on Yojamba Isle, and the Ahn'Qiraj war effort's.
    "Jin'rokh the Breaker", "Maywiki of Zuldazar", "Falthir the Sightless", "Geologist Larksbane",
}
# Quests left out: 7666, Again Into the Great Ossuary, is the Charger's
# fight again for one who lost it, not a step of the chain.
SKIP = {7666}

# CMaNGOS quest_template Type: group, raid, dungeon.
GROUP_TYPES = {1, 62, 81}


# --------------------------------------------------------------------------
# Reading the data
# --------------------------------------------------------------------------

def collect(pfquest, turtle, cmangos):
    """Every class quest worth a guide, and what the guides need of each."""
    from build_zone_guide import Data, Quest, entries, parse, seq, clusters
    from build_gathering import Dump
    data = Data(turtle, pfquest)
    tq = entries(Data.path(turtle, "quests", "-turtle"))
    removed = {q for q, t in tq.items() if t is None}
    for q, t in entries(Data.path(pfquest, "quests", "")).items():
        if t and q not in removed:
            data.quests[q] = dict(parse(t), **data.quests.get(q, {}))
    tt = entries(Data.path(turtle, "quests", "-turtle", True))
    for q, t in entries(Data.path(pfquest, "quests", "", True)).items():
        if t and q not in tt:
            data.text[q] = {k: v for k, v in parse(t).items() if isinstance(v, str)}

    db = Dump(cmangos)
    cm = {int(r["entry"]): r for r in db.rows("quest_template")}
    namecol = [c for c in db.columns("spell_template") if c.lower().startswith("spellname")][0]
    spells = {int(r["Id"]): r[namecol] for r in db.rows("spell_template")}
    items = {int(r["entry"]): (r["name"], int(r["Quality"])) for r in db.rows("item_template")}

    def cmi(q, key):
        r = cm.get(q)
        return int(r.get(key) or 0) if r else 0

    def one_class(t):
        c = t.get("class") or 0
        names = [n for b, n in CLASSES if c & b]
        return names[0] if len(names) == 1 else None

    cfg = {"text": {}, "pre": {}, "spots": {}, "npc": {}, "places": [], "skip": set()}
    model = {"quests": {}}
    for q, t in sorted(data.quests.items()):
        cls = one_class(t)
        if not cls or q in removed or q in SKIP or t.get("event") or t.get("skill"):
            continue
        qo = Quest(data, q, 0, cfg)
        if qo.min < MIN_LEVEL or "DEPRECATED" in qo.title or "CANCELLED" in qo.title:
            continue
        spell = cmi(q, "RewSpell") or cmi(q, "RewSpellCast")
        rewards = [cmi(q, "RewItemId%d" % i) for i in range(1, 5)] + \
                  [cmi(q, "RewChoiceItemId%d" % i) for i in range(1, 7)]
        gives = [i for i in rewards if i]
        src = cmi(q, "SrcItemId")
        need = {cmi(q, "ReqItemId%d" % i) for i in range(1, 5)} | set(qo.obj["I"])
        model["quests"][str(q)] = {
            "gives": gives, "need": sorted(i for i in need if i),
            "src": src if src and re.match(r"(Use|Using)\b", qo.objective or "") else 0,
            "title": qo.title, "class": cls, "min": qo.min, "lvl": qo.lvl,
            "race": qo.race, "cmrace": cmi(q, "RequiredRaces"),
            "pre": [p for p in seq(t.get("pre")) if isinstance(p, int)],
            "prev": cmi(q, "PrevQuestId"), "next": cmi(q, "NextQuestInChain"),
            "excl": cmi(q, "ExclusiveGroup"), "type": cmi(q, "Type"),
            "turtle": q not in cm,
            "spell": spells.get(spell, "") if spell else "",
            "rewards": [items[i][0] for i in rewards if i and items.get(i, ("", 0))[1] >= 3],
            "doing": qo.needs_c, "task": qo.task() if qo.needs_c else "", "text": qo.objective,
            "givers": [place(data, k, i) for k, i in qo.starters],
            "items": [{"id": i, "name": data.name("I", i), "from": [place(data, k, j) for k, j in data.drops(i)[:6]]}
                      for i in qo.start_items],
            "takers": [place(data, k, i) for k, i in qo.enders],
            "obj": objective_spots(data, qo, clusters),
        }
    return model


def place(data, kind, i):
    """An NPC or object: its name, and its spawns by zone, the first of each."""
    by = {}
    for x, y, z in data.spawns(kind, i):
        by.setdefault(data.zone(z) or str(z), [round(x, 1), round(y, 1)])
    return {"name": data.name(kind, i), "at": by}


def objective_spots(data, qo, clusters):
    """Where a quest's objectives are: {zone: [points]}."""
    pts = {}
    things = [(k, i) for k in ("U", "O") for i in qo.obj[k]]
    for item in qo.obj["I"]:
        things += data.drops(item)
    for kind, i in things:
        for x, y, z in data.spawns(kind, i):
            zone = data.zone(z)
            if zone:
                pts.setdefault(zone, []).append((x, y))
    return {k: [[round(p[0], 1), round(p[1], 1)] for p in clusters(v)] for k, v in pts.items()}


# --------------------------------------------------------------------------
# Chains and milestones
# --------------------------------------------------------------------------

def links(quests):
    """q -> the class quests straight after it, and straight before it."""
    after, before = {}, {}
    for q, t in quests.items():
        for p in set(t["pre"]) | ({abs(t["prev"])} if t["prev"] else set()):
            if p in quests and p != q:
                after.setdefault(p, set()).add(q)
                before.setdefault(q, set()).add(p)
        n = t["next"]
        if n in quests and n != q:
            after.setdefault(q, set()).add(n)
            before.setdefault(n, set()).add(q)
    return after, before


def components(quests, after, before):
    """The chains: class quests joined by what comes before and after."""
    seen, out = set(), []
    for q in sorted(quests):
        if q in seen:
            continue
        todo, comp = [q], set()
        while todo:
            c = todo.pop()
            if c in comp:
                continue
            comp.add(c)
            todo += list(after.get(c, ())) + list(before.get(c, ()))
        seen |= comp
        out.append(sorted(comp))
    return out


def exchange(quests, comp):
    """A raid tier's or the dungeon set's exchange, not a class quest."""
    for q in comp:
        for w in quests[q]["givers"] + quests[q]["takers"]:
            if w["name"] in EXCHANGE_NPCS:
                return True
    return False


def breadcrumb_links(quests, after, before):
    """Quests that only send you to a chain name no quest after them: The
    Tome of Nobility, from Stormwind's paladin trainer to Duthorian Rall;
    Turtle WoW's Dabbling In Darkness, from Blackstone Island to Gan'rul
    Bloodeye. One that asks for nothing but walking, and ends with someone
    who gives the class a quest at its level, for the same races, leads to
    that quest -- where a chain starts, not part-way. A priest's racial
    spell is given in every capital under one title, each copy handed in to
    the same trainer: a copy does not lead to another."""
    by_giver = {}
    for q, t in quests.items():
        for w in t["givers"]:
            by_giver.setdefault((t["class"], w["name"]), []).append(q)
    for b, t in quests.items():
        if t["doing"] or after.get(b) or before.get(b):
            continue
        for w in t["takers"]:
            for q in by_giver.get((t["class"], w["name"]), []):
                n = quests[q]
                starts = not n["prev"] if not n["turtle"] else not n["pre"]
                shared = not mask_of(t) or not mask_of(n) or mask_of(t) & mask_of(n)
                copy = n["title"] == t["title"] and n["excl"] > 0
                if (q != b and starts and shared and not copy
                        and abs(n["min"] - t["min"]) <= 2):
                    after.setdefault(b, set()).add(q)
                    before.setdefault(q, set()).add(b)


# What a milestone is called, by the spell its last quest teaches.
SPELL_NAMES = {
    "Summon Voidwalker": "Voidwalker", "Summon Succubus": "Succubus", "Summon Felhunter": "Felhunter",
    "Summon Felsteed": "Felsteed", "Inferno": "Infernal", "Ritual of Doom": "Doomguard",
    "Summon Dreadsteed": "Dreadsteed", "Training Lesson": "Taming the Beast", "Taming Lesson": "Taming the Beast",
    "Summon Warhorse": "Warhorse", "Summon Charger": "Charger", "Stoneskin Totem": "Earth Totem",
    "Searing Totem": "Fire Totem", "Healing Stream Totem": "Water Totem", "Swift Wind": "Air Totem",
    "Path of Defense": "Defensive Stance", "Path of the Berserker": "Berserker Stance",
    "Conjure Water": "Arcane Refreshment", "Teleport to Azshara Tower": "Magecraft",
}
# ...and where the spell says nothing, by its last quest's title.
TITLE_NAMES = {
    "Training the Beast": "Taming the Beast", "Taming the Beast": "Taming the Beast",
    "A Demonstration of Skill": "Taming the Beast", "The Tome of Valor": "Tome of Valor",
    "The Tome of Nobility": "Warhorse", "The Tome of Divinity": "Redemption", "The Symbol of Life": "Redemption",
    "Seeking the Kor Gem": "Tome of Valor", "Bailor's Ore Shipment": "Tome of Valor",
    "The Test of Righteousness": "Tome of Valor",
}


# Chains named outright, by any quest in them: a race's own quest at the
# same level as another race's is one milestone, and each race gets its own.
CHAIN_NAMES = {}
for _name, _ids in {
    "Level 10 Quest": [1860, 1861, 1879, 1880, 40338, 40339, 41257, 1881, 1882, 1883, 1884, 41181, 41182,
                       1858, 1859, 1963, 1885, 1886, 1898, 1899, 1978, 2206, 41262],
    "Warrior's Weapon": [1666, 1667, 1680, 1681, 1682, 1686, 1692, 1693, 1502, 1503, 1820, 1821, 1822],
    "Defensive Stance": [41202, 41261],
    "Level 20 Armor": [1823, 1824, 1825, 1838, 1698, 1699, 1702],
    "Whirlwind Weapon": [1791, 1792],
    "Way of the Spirits": [40343, 40349, 40530],
    "Verigan's Fist": [1653, 1654, 1806, 1442],
    "Charger": [7645],
    "Benediction": [7621, 7622],
    "Blood of Morphaz": [8254, 8257],
    "Rhok'delar": [7632, 7636],
    "Enchanted Gold Bloodrobe": [1796, 4786],
    "Orb of Orahil": [1799, 4964],
    "Mage's Wand": [1947, 1952],
    "The Darkreaver Menace": [7667, 7668],
    "Celestial Power": [1953, 1958],
}.items():
    for _q in _ids:
        CHAIN_NAMES[_q] = _name
# A priest's racial spells: every race's, as one milestone at each level --
# by the spell, or the title where the data has no spell.
RACIAL_TITLES = {
    "Desperate Prayer": "Racial Spell", "Stars of Elune": "Racial Spell", "Returning Home": "Racial Spell",
    "Touch of Weakness": "Racial Spell", "Hex of Weakness": "Racial Spell",
    "Arcane Feedback": "Second Racial Spell", "Resillience of the Mountain": "Second Racial Spell",
    "Elune's Grace": "Second Racial Spell", "Shadowguard": "Second Racial Spell",
    "Devouring Plague": "Second Racial Spell",
}
RACIAL_SPELLS = {
    "Desperate Prayer": "Racial Spell", "Starshards": "Racial Spell", "Touch of Weakness": "Racial Spell",
    "Hex of Weakness": "Racial Spell", "Feedback": "Second Racial Spell", "Fear Ward": "Second Racial Spell",
    "Elune's Grace": "Second Racial Spell", "Shadowguard": "Second Racial Spell",
    "Devouring Plague": "Second Racial Spell",
}


def milestone_name(quests, comp, after):
    """By a name given the chain, the spell it teaches, else its last quest."""
    for q in comp:
        if q in CHAIN_NAMES:
            return CHAIN_NAMES[q]
    for q in sorted(comp, key=lambda q: (-quests[q]["min"], q)):
        if quests[q]["spell"] in RACIAL_SPELLS:
            return RACIAL_SPELLS[quests[q]["spell"]]
        if quests[q]["title"] in RACIAL_TITLES:
            return RACIAL_TITLES[quests[q]["title"]]
    for q in sorted(comp, key=lambda q: (-quests[q]["min"], q)):
        if quests[q]["spell"]:
            return SPELL_NAMES.get(quests[q]["spell"], quests[q]["spell"])
    # A loop in the data leaves no last quest: then any of them.
    finals = sorted([q for q in comp if not (after.get(q, set()) & set(comp))] or comp,
                    key=lambda q: (-quests[q]["min"], q))
    for q in finals:
        if quests[q]["title"] in TITLE_NAMES:
            return TITLE_NAMES[quests[q]["title"]]
    return quests[finals[0]]["title"]


def split_at_spells(quests, comp, after, before):
    """A chain that teaches a spell part-way -- Defensive Stance, then a
    weapon -- is two milestones: the spell, and what comes after it. The
    spell's part is often solo when the rest is not."""
    comp = set(comp)
    for q in sorted(comp, key=lambda q: (quests[q]["min"], q)):
        if quests[q]["spell"] and after.get(q, set()) & comp:
            tail, todo = set(), list(after[q] & comp)
            while todo:
                c = todo.pop()
                if c in tail or c == q:
                    continue
                tail.add(c)
                todo += list(after.get(c, set()) & comp)
            head = comp - tail
            if tail and q in head:
                return [sorted(head)] + split_at_spells(quests, sorted(tail), after, before)
    return [sorted(comp)]


def race_bit(name):
    return dict((n, b) for b, n in RACES)[name]


# The races each class could be before Turtle WoW added its own.
CLASS_RACES = {
    "Warrior": 1 | 2 | 4 | 8 | 16 | 32 | 64 | 128, "Paladin": 1 | 4, "Hunter": 2 | 4 | 8 | 32 | 128,
    "Rogue": 1 | 2 | 4 | 8 | 16 | 64 | 128, "Priest": 1 | 4 | 8 | 16 | 128, "Shaman": 2 | 32 | 128,
    "Mage": 1 | 16 | 64 | 128, "Warlock": 1 | 2 | 16 | 64, "Druid": 8 | 32,
}


def settle_masks(quests):
    """The race masks to go by. Where the quest is given in one side's
    cities, that side's: A Lesson to Learn from Darnassus is the Night
    Elf's, though CMaNGOS names the Tauren. And where a quest is given by
    every trainer, a copy each, and the copies' masks differ -- the
    warlock's In Search of Menara Voidrender, whose masks are shuffled
    between cities -- any copy is for the whole of its side, and the one at
    home is picked. (A priest's racial spell's copies agree, and are kept.)"""
    homes = {z: (ALLIANCE if race_bit(r) & ALLIANCE else HORDE) for r, zs in HOME.items() for z in zs}
    family = {}
    for q, t in quests.items():
        if t["excl"] > 0:
            family.setdefault((t["class"], t["excl"], t["title"]), []).append(q)
    out = {}
    for q, t in quests.items():
        t = dict(t)
        # Given only in one side's cities: anywhere else, by anyone, is either side's.
        sides = {homes.get(z, 0) for z in zones_of(t, "givers")}
        t["side"] = sides.pop() if len(sides) == 1 else 0
        copies = family.get((t["class"], t["excl"], t["title"]), [q])
        if len({(quests[c]["race"], quests[c]["cmrace"]) for c in copies}) > 1:
            t["race"] = t["cmrace"] = 0
        out[q] = t
    return out


def allows(t, race):
    """Whether `race` is named on a quest: on a classic quest, by both
    CMaNGOS' race mask and pfQuest's, each where it names any of the side's
    races; on Turtle WoW's own, by pfQuest-turtle's.

    A Turtle WoW race on a classic quest: where pfQuest-turtle names races
    on it, narrower than the side, whether it names this one (the High Elf
    warrior's Grimand Elmore is the Human's); otherwise whether the quest is
    for every race of the side that had the class (a paladin's Charger is
    for Humans and Dwarves, so a High Elf's too; a Night Elf's own is not)."""
    bit = race_bit(race)
    side = ALLIANCE if bit & ALLIANCE else HORDE
    if t.get("side") and not t["side"] & side:
        return False
    masks = [m for m in (t["race"], 0 if t["turtle"] else t["cmrace"]) if m]
    if masks and not any(m & side for m in masks):
        return False
    pfm = t["race"] & side
    pf = not pfm or bool(pfm & bit)
    if t["turtle"]:
        return pf
    cm = t["cmrace"] & side
    if bit < 256:
        return pf and (not cm or bool(cm & bit))
    if not cm or (pfm and pfm != side):
        return pf
    had = CLASS_RACES[t["class"]] & side
    return cm & had == had


def taken_by(quests, comp, race, after):
    """The quests of a chain `race` can take. pfQuest-turtle names Turtle
    WoW's races on some quests of a chain and not the rest -- a Goblin
    shaman on the second Call of Earth, not the first -- so a Turtle race
    goes the way of the classic race it shares most with (a quest it is
    named on, or one such a quest leads to: Paragon of Light leads a High
    Elf paladin to the Human's Tome of Divinity), and takes that race's
    quests with its own. Named on none, it does not take the chain."""
    named = {q for q in comp if allows(quests[q], race)}
    if race_bit(race) < 256 or not named:
        return named
    side = ALLIANCE if race_bit(race) & ALLIANCE else HORDE
    cls = quests[comp[0]]["class"]
    near = named | {n for q in named for n in after.get(q, ())}
    best, best_key = set(), None
    for bit, host in RACES:
        if bit >= 256 or not bit & side & CLASS_RACES[cls]:
            continue
        theirs = {q for q in comp if allows(quests[q], host)}
        key = (len(near & theirs), len(set(HOME[host]) & set(HOME[race])), -bit)
        if key[0] and (best_key is None or key > best_key):
            best, best_key = theirs, key
    return named | best


def zones_of(t, key):
    return [z for w in t[key] for z in w["at"]]


def home_score(quests, qs, race):
    home = HOME[race]
    return sum(1 for q in qs for z in zones_of(quests[q], "givers") if z in home)


def mask_of(t):
    """The races a quest is for, Turtle WoW's included: 0 is any."""
    if not t["turtle"] and t["cmrace"]:
        return t["cmrace"] | (t["race"] & (256 | 512))
    return t["race"]


def fit(quests, qs, race):
    """How well quests suit a race: given in its home, then made for it (the
    fewer races they are for, on the whole, the better)."""
    width = sum(bin(mask_of(quests[q]) or 1023).count("1") for q in qs) / float(len(qs))
    return (home_score(quests, qs, race), -width)


def requires(quests, s, q):
    """Whether quest s needs q done. CMaNGOS' PrevQuestId says so -- naming,
    now and then, the other side's copy of q (the Aquatic Form's Trial of
    the Lake)."""
    p = abs(quests[s]["prev"])
    return p == q or (p in quests and quests[p]["title"] == quests[q]["title"])


def chain_for(quests, comp, race, after, before):
    """The quests of one chain a race does, in order: one of each set of
    alternatives -- CMaNGOS' ExclusiveGroup, and quests that only send you
    to the same place -- the one given nearest home. None when the race
    cannot reach the chain's end."""
    qs = sorted(taken_by(quests, comp, race, after))
    groups = {}
    for q in qs:
        g = quests[q]["excl"]
        if g > 0:
            groups.setdefault(("excl", g), []).append(q)
    inside = set(qs)
    for q in qs:
        nexts = after.get(q, set()) & inside
        if (not quests[q]["doing"] and not (before.get(q, set()) & inside) and nexts
                and not any(requires(quests, n, q) for n in nexts)):
            groups.setdefault(("to", frozenset(nexts)), []).append(q)
    drop = set()
    for alts in groups.values():
        best = max(alts, key=lambda q: (fit(quests, [q], race), -q))
        drop |= set(alts) - {best}
    qs = [q for q in qs if q not in drop]
    finals = {q for q in comp if not (after.get(q, set()) & set(comp))} or set(comp)
    if not finals & set(qs):
        return []
    # In order: a quest after all those before it; the lowest level first.
    left, out = set(qs), []
    while left:
        ready = [q for q in left if not (before.get(q, set()) & left)]
        if not ready:
            ready = list(left)
        q = min(ready, key=lambda q: (quests[q]["min"], q))
        out.append(q)
        left.remove(q)
    return out


def optional(quests, q, seq, after):
    """A quest that only sends you to the chain: it asks for nothing, it is
    first, and what follows is given without it."""
    t = quests[q]
    if t["doing"] or seq[0] != q or len(seq) < 2:
        return False
    nexts = [n for n in seq if n in after.get(q, set())]
    return bool(nexts) and not any(requires(quests, n, q) for n in nexts)


def is_group(quests, seq):
    for q in seq:
        t = quests[q]
        if t["type"] in GROUP_TYPES:
            return True
        if t["obj"] and not any(z in MAP_ZONES for z in t["obj"]):
            return True
    return False


def milestones(model):
    """[{class, name, side, races: {race: [quests]}, group}] by class and level."""
    # A quest with no one to give it and nothing to start it from cannot be
    # followed.
    quests = settle_masks({q: t for q, t in model["quests"].items()
                           if (t["givers"] or t["items"]) and q not in SKIP})
    after, before = links(quests)
    breadcrumb_links(quests, after, before)
    comps = [part for c in components(quests, after, before) if not exchange(quests, c)
             for part in split_at_spells(quests, c, after, before)]
    named = {}
    for comp in comps:
        key = (quests[comp[0]]["class"], milestone_name(quests, comp, after))
        named.setdefault(key, []).append(comp)
    out = []
    for (cls, name), comps in sorted(named.items()):
        for side, mask in SIDES:
            races = {}
            for bit, race in RACES:
                if not bit & mask:
                    continue
                best, best_key = None, None
                for comp in comps:
                    seq = chain_for(quests, comp, race, after, before)
                    if not seq:
                        continue
                    key = (fit(quests, seq, race), -len(seq), -min(seq))
                    if best is None or key > best_key:
                        best, best_key = seq, key
                if best:
                    races[race] = best
            if races:
                level = min(min(quests[q]["min"] for q in seq if not optional(quests, q, seq, after))
                            for seq in races.values())
                group = any(is_group(quests, seq) for seq in races.values())
                out.append({"class": cls, "name": name, "side": side, "races": races,
                            "level": level, "group": group})
    out.sort(key=lambda m: (m["class"], m["level"], m["name"], m["side"]))
    return out, quests, after


# --------------------------------------------------------------------------
# Writing a guide
# --------------------------------------------------------------------------

# The way into an instance a quest is done in, where the dungeon guides do
# not say: the zone its door is in, where, and what the step says.
MORE_ENTRANCES = {
    "Scholomance": ("Western Plaguelands", (69.0, 72.7), "On Caer Darrow, the island in Darrowmere Lake"),
    "Zul'Gurub": ("Stranglethorn Vale", (54.2, 17.6), "In the north-east of Stranglethorn Vale"),
    "Onyxia's Lair": ("Dustwallow Marsh", (52.9, 78.2), "The cave in the Wyrmbog, in the south of Dustwallow Marsh"),
    "Dire Maul": ("Feralas", None, "The ruined city in the middle of Feralas"),
    "Ruins of Ahn'Qiraj": ("Silithus", None, "Beyond the Scarab Wall, in the far south of Silithus"),
    "Tower of Karazhan": ("Deadwind Pass", None, "Karazhan, the tower in Deadwind Pass"),
}


# NPCs pfQuest has no spawns for -- they appear when summoned, or stand
# inside -- where a class quest's step can still send you: {name: (zone or
# instance, what the step says)}.
PLACES = {
    "Vartrus the Ancient": ("Felwood", "in Irontree Woods, in the north of Felwood"),
    "Hastat the Ancient": ("Felwood", "in Irontree Woods, in the north of Felwood"),
    "Stoma the Ancient": ("Felwood", "in Irontree Woods, in the north of Felwood"),
    "Lorekeeper Lydros": ("Dire Maul", "in the library of Dire Maul's west wing"),
    "Lorekeeper Javon": ("Dire Maul", "in the library of Dire Maul's west wing"),
}


def entrances():
    """{instance, as its zone text inside: (zone, (x, y) or None, text)}."""
    from build_dungeon_guides import DUNGEONS
    out = {}
    for d in DUNGEONS.values():
        # A second place in the text would be put on this zone's map.
        text = re.sub(r"\s*\(\d+(\.\d+)?, \d+(\.\d+)?\)", "", d["enter"])
        for n in (d["title"], d["name"]):
            out[n] = (d["zone"], tuple(d["entrance"]), text)
    for wing in ("Graveyard", "Library", "Armory", "Cathedral"):
        out["Scarlet Monastery " + wing] = out["Scarlet Monastery"]
    for n in ("Blackrock Mountain", "Blackrock Spire", "Blackwing Lair", "Molten Core"):
        out[n] = (out["Blackrock Depths"][0], out["Blackrock Depths"][1], "In Blackrock Mountain, from the Burning Steppes")
    out.update(MORE_ENTRANCES)
    return out


def fmt(p):
    def n(v):
        return ("%.1f" % v).rstrip("0").rstrip(".")
    return "(%s, %s)" % (n(p[0]), n(p[1]))


ARTICLE = {"Badlands": "the Badlands", "Undercity": "the Undercity", "The Barrens": "the Barrens",
           "The Hinterlands": "the Hinterlands"}
# The other side's cities: a summoning circle there is no help.
CITIES = {"Alliance": {"Stormwind City", "Ironforge", "Darnassus", "Alah'Thalas"},
          "Horde": {"Orgrimmar", "Undercity", "Thunder Bluff"}}
WIDE = 5     # an objective found in more zones than this is found anywhere: no place is named
KIND = {"T": 0, "A": 1, "C": 2}


class Spot:
    """Where something is: a zone on the world map and a point, or inside an
    instance, or nowhere the data knows."""

    def __init__(self, name, zone=None, point=None, inside=None, item=None, text=None):
        self.name, self.zone, self.point, self.inside, self.item = name, zone, point, inside, item
        self.text = text

    def place(self):
        return self.inside or self.zone


class ClassGuide:
    """One milestone's guide for one side: each race's chain, in steps, and
    the races' steps put together."""

    def __init__(self, quests, after, before, m, doors):
        self.q, self.after, self.before, self.m, self.doors = quests, after, before, m, doors
        self.travel = self.flights(m["side"])
        self.last = {}      # the races of a chain -> the quest its guide ends handing in

    @staticmethod
    def flights(side):
        from build_dungeon_guides import TRAVEL
        return TRAVEL[side]

    # -- where things are ------------------------------------------------------

    def spot(self, people, prefer, first=()):
        """Where to meet one of `people`. Each one's place goes by `prefer`:
        pfQuest puts one NPC on two maps -- Darnassus' and Teldrassil's --
        and the city is the one to name. Of different people, one in a
        `first` zone comes before the rest: Goldshire's trainer before
        Stormwind's, for a level-10 Human."""
        best = None
        for p in people:
            mine = None
            for zone, pt in p["at"].items():
                if zone in MAP_ZONES:
                    rank = (0, prefer.index(zone)) if zone in prefer else (2 if zone in TURTLE_ZONES else 1, 0)
                    cand = Spot(p["name"], zone, pt[:2])
                elif zone in self.doors:
                    rank, cand = (3, 0), Spot(p["name"], inside=zone)
                else:
                    continue
                if mine is None or rank < mine[0]:
                    mine = (rank, cand)
            if mine:
                key = (0 if mine[1].zone in first else 1,) + mine[0]
                if best is None or key < best[0]:
                    best = (key, mine[1])
        if best:
            return best[1]
        for p in people:
            if p["name"] in PLACES:
                where, text = PLACES[p["name"]]
                if where in MAP_ZONES:
                    return Spot(p["name"], zone=where, text=text)
                return Spot(p["name"], inside=where, text=text)
        return Spot(people[0]["name"]) if people else None

    def giver(self, q, prefer, first=()):
        t = self.q[q]
        if t["givers"]:
            return self.spot(t["givers"], prefer, first)
        for it in t["items"]:
            src = self.spot(it["from"], prefer) if it["from"] else None
            return Spot(it["name"], zone=src and src.zone, inside=src and src.inside, item=it["id"],
                        point=None)
        return None

    def taker(self, q, prefer, first=()):
        t = self.q[q]
        return self.spot(t["takers"] or t["givers"], prefer, first)

    def work(self, q, prefer):
        """Where a quest's objectives are: (zone, points, other zones),
        (None, instance, others) inside, or None -- anywhere, or nothing to
        go to."""
        t = self.q[q]
        if not t["doing"] or not t["obj"] or len(t["obj"]) > WIDE:
            return None
        foreign = CITIES["Horde" if self.m["side"] == "Alliance" else "Alliance"]
        zones = [z for z in t["obj"] if z in MAP_ZONES and z not in foreign]
        if zones:
            zones.sort(key=lambda z: (z not in prefer, prefer.index(z) if z in prefer else 0,
                                      z in TURTLE_ZONES, -len(t["obj"][z]), z))
            return (zones[0], t["obj"][zones[0]], zones[1:] + [z for z in t["obj"] if z in self.doors])
        inside = sorted(z for z in t["obj"] if z in self.doors)
        if inside:
            return (None, inside[0], inside[1:])
        return None

    # -- one race's chain --------------------------------------------------------

    def home(self, races):
        """Where a chain's races start from: their class trainers' cities."""
        return [z for r in races for z in HOME[r]]

    def first(self, races, x):
        """Below level YOUNG, the races' starting zones: of two people who
        give or take quest `x`, the one there comes first."""
        return [START[r] for r in races] if self.q[x]["min"] < YOUNG else []

    def plan(self, seq, races):
        """The steps for one chain: [(line without |R|, ...)]."""
        q, after, before = self.q, self.after, self.before
        opt = {x for x in seq if optional(q, x, seq, after)}
        inseq = set(seq)
        home = self.home(races)
        events = []
        for x in seq:
            events.append(("A", x))
            if q[x]["doing"]:
                events.append(("C", x))
            events.append(("T", x))
        deps = {e: set() for e in events}

        def needs(a, b):
            """Whether event a waits, however far back, on event b."""
            seen, todo = set(), [a]
            while todo:
                c = todo.pop()
                if c == b:
                    return True
                if c not in seen:
                    seen.add(c)
                    todo += list(deps[c])
            return False
        for x in seq:
            t = q[x]
            if t["doing"]:
                deps[("C", x)].add(("A", x))
                deps[("T", x)].add(("C", x))
            else:
                deps[("T", x)].add(("A", x))
            for p in before.get(x, set()) & inseq:
                if p in opt:
                    continue
                if t["prev"] < 0 and p == -t["prev"]:
                    # Given only while the one before is in the log: taken
                    # alongside it, and done first -- the Charger's horse
                    # feed, for the spirit.
                    deps[("A", x)].add(("A", p))
                    deps[("C", p) if q[p]["doing"] else ("T", p)].add(("T", x))
                else:
                    deps[("A", x)].add(("T", p))
        # An item one quest gives that another asks for: that one handed in
        # first, where it can be.
        for x in seq:
            need = set(q[x]["need"])
            wait = ("C", x) if q[x]["doing"] else ("T", x)
            for p in seq:
                if p != x and need & set(q[p]["gives"]) and not needs(("T", p), wait):
                    deps[wait].add(("T", p))
        order = {e: i for i, e in enumerate(events)}
        where = {}

        def place(e, here):
            kind, x = e
            prefer = ([here] if here else []) + home
            if kind == "A":
                s = self.giver(x, prefer, self.first(races, x))
            elif kind == "T":
                s = self.taker(x, prefer, self.first(races, x))
            else:
                w = self.work(x, prefer)
                s = None if w is None else Spot(None, zone=w[0], inside=None if w[0] else w[1])
                if s is None and q[x]["doing"] and not q[x]["obj"]:
                    # Something to do the data has no place for: by whoever
                    # takes it -- the censer is Rohan's, in Ironforge.
                    t = self.taker(x, prefer)
                    s = t and Spot(None, zone=t.zone, inside=t.inside)
            return s

        lines, done, here, left = [], set(), None, list(events)
        while left:
            ready = [e for e in left if deps[e] <= done] or [min(left, key=order.get)]

            # What can be done where you are first -- a hand-in before a
            # pick-up -- else the chain's next thing, and the way there. A quest
            # that only sends you to the chain is picked up wherever you have
            # it, and handed in once you are there anyway.
            def key(e):
                s = place(e, here)
                p = s.place() if s else None
                near = p is None or p == here or (e[1] in opt and e[0] == "A")
                return (0 if near else 1, 0 if near or e[1] not in opt else 1, KIND[e[0]] if near else 0, order[e])
            e = min(ready, key=key)
            s = place(e, here)
            p = s.place() if s else None
            if p and p != here and e[1] not in opt:
                # There, and what is there first: a hand-in before the next
                # pick-up.
                lines.append(self.go(p))
                here = p
                continue
            left.remove(e)
            done.add(e)
            lines.append(self.step(e, s, here, e[1] in opt, home))
            if e[0] == "T":
                self.last[tuple(races)] = e[1]
        return lines

    def go(self, p):
        if p in self.doors:
            zone, point, text = self.doors[p]
            return "R %s |N|%s%s| |Z|%s|" % (p, text, " " + fmt(point) if point else "", zone)
        if p in self.travel:
            action, town, note = self.travel[p]
            return "%s %s |N|%s| |Z|%s|" % (action, town, note, p)
        return "R %s |N|Travel to %s| |Z|%s|" % (p, ARTICLE.get(p, p), p)

    def step(self, e, s, here, opt, home):
        kind, x = e
        t = self.q[x]
        tags = ["|QID|%d|" % x]
        zone, use = None, None
        if kind == "C":
            w = self.work(x, ([here] if here else []) + home)
            task = t["task"] or t["text"] or t["title"]
            if w and w[0]:
                # The zone named by the points, so a place in the task's
                # words -- "for the Great Cat Spirit in Moonglade" -- is not
                # taken for theirs.
                note = "%s -- %s %s" % (task, ARTICLE.get(w[0], w[0]), " ".join(fmt(p) for p in w[1][:4]))
                zone = w[0]
                if w[2]:
                    note += "; also in %s" % ", ".join(ARTICLE.get(z, z) for z in w[2][:3])
            elif w:
                note = "%s, inside %s" % (task, w[1])
                if w[2]:
                    note += " (or %s)" % ", ".join(w[2][:2])
            else:
                note = task
            # The quest's own item, used for it: the Taming Rod.
            use = t.get("src") or None
        elif s is None:
            note = "the quest's giver" if kind == "A" else "whoever gave it"
        elif s.item:
            use = s.item
            src = s.place()
            note = "%s%s: right-click it to start the quest" % (s.name, " -- from %s" % src if src else "")
        elif s.text:
            zone = s.zone
            note = "%s, %s" % (s.name, s.text)
        elif s.zone:
            zone = s.zone
            note = "%s %s" % (s.name, fmt(s.point)) if s.point else s.name
        elif s.inside:
            note = "%s, inside %s" % (s.name, s.inside)
        else:
            note = s.name
        tags.append("|N|%s|" % note.replace("|", "/"))
        if zone:
            tags.append("|Z|%s|" % zone)
        if use:
            tags.append("|U|%d|" % use)
        if self.m.get("class"):
            tags.append("|C|%s|" % self.m["class"])
        if opt and kind != "C":
            tags.append("|O|")
        return " ".join(["%s %s" % (kind, t["title"])] + tags)

    # -- the races together --------------------------------------------------------

    def build(self):
        variants = {}
        for race, seq in self.m["races"].items():
            variants.setdefault(tuple(seq), []).append(race)
        order = [r for _, r in RACES]
        merged = []
        for seq, races in sorted(variants.items(), key=lambda kv: min(order.index(r) for r in kv[1])):
            races = sorted(races, key=order.index)
            merged = merge(merged, [(line, set(races)) for line in self.plan(list(seq), races)])
        everyone = set(self.m["races"])
        out = []
        for line, races in merged:
            if races != everyone:
                line += " |R|%s|" % "/".join(r for r in order if r in races)
            out.append(line)
        return out


def merge(a, b):
    """Two lists of (line, races) in one, each in its own order: a line both
    have, once, for the races of both."""
    n, m = len(a), len(b)
    lcs = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(n - 1, -1, -1):
        for j in range(m - 1, -1, -1):
            lcs[i][j] = lcs[i + 1][j + 1] + 1 if a[i][0] == b[j][0] else max(lcs[i + 1][j], lcs[i][j + 1])
    out, i, j = [], 0, 0
    while i < n or j < m:
        if i < n and j < m and a[i][0] == b[j][0]:
            out.append((a[i][0], a[i][1] | b[j][1]))
            i, j = i + 1, j + 1
        elif j >= m or (i < n and lcs[i + 1][j] >= lcs[i][j + 1]):
            out.append(a[i])
            i += 1
        else:
            out.append(b[j])
            j += 1
    return out


def guide_name(m):
    return "Class/%s: %s (%d)" % (m["class"], m["name"], m["level"])


def describe(quests, m):
    """What the guide's first step says: what the milestone gives, and who
    it is for."""
    seqs = list(m["races"].values())
    last = [s[-1] for s in seqs]
    gives = []
    for x in sorted(set(q for s in seqs for q in s), key=lambda q: (quests[q]["min"], q)):
        t = quests[x]
        if t["spell"] and t["spell"] not in gives:
            gives.append(t["spell"])
    for x in last:
        for r in quests[x]["rewards"]:
            if r not in gives:
                gives.append(r)
    what = "The %s class quest%s" % (m["class"].lower(), "s" if max(len(s) for s in seqs) > 1 else "")
    if gives:
        what += ", for %s" % " and ".join(gives[:3])
    what += ", from level %d" % m["level"]
    if m["group"]:
        what += ". Some of it needs a group: a dungeon, a raid or an elite"
    return what


def lua_class(cls, side, ms, quests, after, before, doors):
    """A class's guides for one side, and its milestones for the offer."""
    body = ["-- Class quest guides: %s, %s" % (cls, side),
            "-- Written by Tools/build/build_class_guides.py from pfQuest, pfQuest-turtle and CMaNGOS: "
            "do not edit it here.", ""]
    last = {}
    for m in ms:
        name = guide_name(m)
        cg = ClassGuide(quests, after, before, m, doors)
        lines = cg.build()
        for races, q in cg.last.items():
            for race in races:
                last[(name, race)] = q
        body += ['AegisPathfinder:RegisterGuide("%s", nil, "%s", function()' % (name, side), "",
                 "return [[", "",
                 # Read, not ticked: the guide opens at its first quest.
                 "N %s |N|%s| |C|%s| |O|" % (m["name"], describe(quests, m), cls), ""]
        body += lines
        body += ["", "]]", "end)", ""]
    # What the offer needs of each: the level each race can start it, the
    # quests that say a route does it or it is done, and whether it needs a group.
    body.append("AegisPathfinder:RegisterClassMilestones(\"%s\", \"%s\", {" % (side, cls.upper()))
    for m in ms:
        races = []
        for race in [r for _, r in RACES if r in m["races"]]:
            seq = m["races"][race]
            core = [x for x in seq if not optional(quests, x, seq, after)]
            level = min(quests[x]["min"] for x in core)
            races.append('["%s"] = { level = %d, last = %d, quests = { %s } }' % (
                race, level, last[(guide_name(m), race)], ", ".join(str(x) for x in core)))
        body.append('\t{ guide = "%s", group = %s, races = {' % (guide_name(m), "true" if m["group"] else "false"))
        body += ["\t\t%s," % r for r in races]
        body.append("\t} },")
    body += ["})", ""]
    return "\n".join(body)


def write_all(model, check=False):
    ms, quests, after = milestones(model)
    before = {}
    for p, ns in after.items():
        for n in ns:
            before.setdefault(n, set()).add(p)
    doors = entrances()
    files = {}
    for side, _ in SIDES:
        names = []
        for _, cls in CLASSES:
            mine = [m for m in ms if m["class"] == cls and m["side"] == side]
            if mine:
                path = os.path.join(OUT, side, "%s.lua" % cls)
                files[path] = lua_class(cls, side, mine, quests, after, before, doors)
                names.append(os.path.basename(path))
        xml = ['<Ui xmlns="http://www.blizzard.com/wow/ui/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
               'xsi:schemaLocation="http://www.blizzard.com/wow/ui/\n..\\FrameXML\\UI.xsd">',
               "\t<!-- %s class quest guides: written by Tools/build/build_class_guides.py -->" % side]
        xml += ['\t<Script file="%s"/>' % n for n in names]
        files[os.path.join(OUT, side, "Guides.xml")] = "\n".join(xml + ["</Ui>", ""])
    stale = []
    for path, text in sorted(files.items()):
        old = open(path, encoding="utf-8").read() if os.path.exists(path) else None
        if old == text:
            continue
        if check:
            stale.append(os.path.relpath(path, ROOT))
        else:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(text)
            print("wrote %s" % os.path.relpath(path, ROOT))
    # A file no milestone writes any more.
    for side, _ in SIDES:
        for path in glob.glob(os.path.join(OUT, side, "*")):
            if path not in files:
                stale.append(os.path.relpath(path, ROOT) + " (not written any more)")
    if stale:
        sys.exit("out of date: %s -- run python3 Tools/build/build_class_guides.py" % ", ".join(stale))


def load(path=CACHE):
    with open(path, encoding="utf-8") as f:
        raw = json.load(f)
    raw["quests"] = {int(q): t for q, t in raw["quests"].items()}
    return raw


def summary(model):
    quests = model["quests"]
    after, before = links(quests)
    breadcrumb_links(quests, after, before)
    for comp in components(quests, after, before):
        if exchange(quests, comp):
            continue
        cls = quests[comp[0]]["class"]
        finals = [q for q in comp if not (after.get(q, set()) & set(comp))]
        print("%-8s %2d %s" % (cls, min(quests[q]["min"] for q in comp),
              " | ".join("%d %s%s" % (q, quests[q]["title"], (" [" + quests[q]["spell"] + "]") if quests[q]["spell"] else "")
                         for q in finals)))
        print("           all: %s" % ", ".join("%d%s" % (q, "T" if quests[q]["turtle"] else "") for q in comp))


def listing(model):
    ms, quests, after = milestones(model)
    for m in ms:
        print("%-8s %2d %-26s %-8s%s" % (m["class"], m["level"], m["name"], m["side"], "  GROUP" if m["group"] else ""))
        chains = {}
        for race, seq in m["races"].items():
            chains.setdefault(tuple(seq), []).append(race)
        for seq, rs in chains.items():
            print("      %-32s %s" % ("/".join(rs), ", ".join(
                ("(%d)" if optional(quests, q, list(seq), after) else "%d") % q for q in seq)))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pfquest")
    ap.add_argument("--pfquest-turtle")
    ap.add_argument("--cmangos")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--summary", action="store_true")
    a = ap.parse_args()
    if a.pfquest or a.pfquest_turtle or a.cmangos:
        if not (a.pfquest and a.pfquest_turtle and a.cmangos):
            sys.exit("--pfquest, --pfquest-turtle and --cmangos go together")
        model = collect(a.pfquest, a.pfquest_turtle, a.cmangos)
        with open(CACHE, "w", encoding="utf-8") as f:
            json.dump(model, f, indent=1, sort_keys=True, ensure_ascii=False)
            f.write("\n")
        print("wrote %s: %d quests" % (os.path.relpath(CACHE, ROOT), len(model["quests"])))
    model = load()
    if a.summary:
        summary(model)
    if a.list:
        listing(model)
    if not (a.summary or a.list):
        write_all(model, a.check)


if __name__ == "__main__":
    main()
