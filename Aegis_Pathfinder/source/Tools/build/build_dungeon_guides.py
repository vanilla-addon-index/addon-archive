#!/usr/bin/env python3
"""Write a guide for each dungeon: every quest for it, then the way in.

    python3 Tools/build/build_dungeon_guides.py                  # write Guides/Dungeons/
    python3 Tools/build/build_dungeon_guides.py --check          # fail if they are stale
    python3 Tools/build/build_dungeon_guides.py --dump ULDA      # print one, with what it left out
    python3 Tools/build/build_dungeon_guides.py --pfquest DIR --pfquest-turtle DIR --instancejournal DIR
                                                           # read the quest data again first

A dungeon guide is picked from the guide list, not reached on a route. It
goes round the towns in DUNGEONS' order picking up every quest for the
dungeon -- and doing the quests before them that the towns on the way give
-- then puts the arrow on the entrance. Inside, it takes you through what
each quest wants and hands in what ends there; on the way back, the towns in
reverse, it hands in the rest and picks up what they lead to. A chain that
needs another visit -- a quest you are given only once you have handed one
in outside -- gets another run.

A quest whose chain starts somewhere the guide does not go -- a long chain in
another zone, another dungeon's quests -- is in the guide, but optional
(|O|) and offered once the quest before it is handed in (|PRE|): it shows for
a character who has done that, and sends nobody off to do it. Quests given
where the guide does not go at all are named in a note at the top.

Which quests belong to a dungeon is InstanceJournal's
(https://github.com/Arthur-Helias/InstanceJournal, public domain), a Turtle
WoW addon that lists every instance's quests, with each dungeon's levels and
entrance. The quests themselves -- who gives and takes them, what they ask
for and where, the quests before them -- are pfQuest's, with pfQuest-turtle
over them: The Kludge Bureau's fork
(https://github.com/The-Kludge-Bureau/pfQuest-turtle), which has patch
1.18.1's. SKIP, ADD, FIX, TASK and FAR correct what the data gets wrong.

Reading them takes a minute and all three checkouts, so what the guides are
written from is kept in Tools/data/dungeon_guides.json: --check, and a change
to DUNGEONS, need none of them.
"""

import argparse
import glob
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CACHE = os.path.join(ROOT, "Tools", "data", "dungeon_guides.json")
BOSSES = os.path.join(ROOT, "Tools", "data", "dungeon_bosses.json")
OUT = os.path.join(ROOT, "Guides", "Dungeons")

ALLIANCE, HORDE = 1 | 4 | 8 | 64 | 512, 2 | 16 | 32 | 128 | 256
SIDES = (("Alliance", ALLIANCE), ("Horde", HORDE))
CLASSES = ((1, "Warrior"), (2, "Paladin"), (4, "Hunter"), (8, "Rogue"),
           (16, "Priest"), (64, "Shaman"), (128, "Mage"), (256, "Warlock"),
           (1024, "Druid"))
ALL_CLASSES = 1 | 2 | 4 | 8 | 16 | 64 | 128 | 256 | 1024
RACES = ((1, "Human"), (2, "Orc"), (4, "Dwarf"), (8, "Night Elf"), (16, "Undead"),
         (32, "Tauren"), (64, "Gnome"), (128, "Troll"), (256, "Goblin"),
         (512, "High Elf"))
RUNS = 6           # visits at most
AFTER = 5          # levels past the dungeon's a quest after it may be

# Each dungeon, by the code the setup and |D| tags use:
#   title     what the guide list calls it
#   name      what the client calls it inside: the RUN step to the entrance
#             is named so, and completes as you walk in
#   levels    the setup's range for it
#   areas     pfQuest's areas for it
#   zone      where the entrance is, entrance the point the arrow goes to
#             (a meeting stone's, from pfQuest, where there is one) and
#             enter how to find it
# and per side, "towns": the places to go, in order, the entrance's zone
# last; a town can come twice, for a chain that goes there and back. The
# hand-ins are on the way back, in "back" (else "towns" reversed). "travel"
# says how to get to a town -- (action, where, note) -- where "Travel to"
# would not do.
DUNGEONS = {
    "RFC": {
        "title": "Ragefire Chasm", "name": "Ragefire Chasm", "levels": (13, 18), "areas": [2437], "journal": ["rfc"],
        "zone": "Orgrimmar", "entrance": (53.0, 48.6),
        "enter": "The entrance is in the Cleft of Shadow",
        # Thrall's Hidden Enemies start at Skull Rock, in Durotar.
        "Horde": {"towns": ["Thunder Bluff", "Undercity", "Orgrimmar", "Durotar", "Orgrimmar"],
                  "back": ["Orgrimmar", "Undercity", "Thunder Bluff"]},
    },
    "WC": {
        "title": "Wailing Caverns", "name": "Wailing Caverns", "levels": (17, 24), "areas": [718], "journal": ["wc"],
        "zone": "The Barrens", "entrance": (46.1, 35.8),
        "enter": "The cave mouth is in the rocks south-west of the Crossroads, below the great skull",
        "Alliance": {"towns": ["Darnassus", "Darkshore", "The Barrens"]},
        # The Barrens Oases chain goes from Thunder Bluff to the Barrens and
        # back to Nara Wildmane, who sends you in for the Fanglords.
        "Horde": {"towns": ["Orgrimmar", "Thunder Bluff", "The Barrens", "Thunder Bluff", "The Barrens"],
                  "back": ["The Barrens", "Thunder Bluff", "Orgrimmar"]},
    },
    "DM": {
        "title": "The Deadmines", "name": "The Deadmines", "levels": (17, 24), "areas": [1581, 5138], "journal": ["deadmines"],
        "zone": "Westfall", "entrance": (42.5, 72.7),
        "enter": "In Moonbrook: through the Defias hideout under the inn, and down the mine",
        "Alliance": {"towns": ["Stormwind City", "Redridge Mountains", "Elwynn Forest", "Westfall"]},
        "Horde": {"towns": ["Undercity", "Westfall"]},
    },
    "SFK": {
        "title": "Shadowfang Keep", "name": "Shadowfang Keep", "levels": (22, 30),
        "areas": [209, 236, 5132, 5150, 5161, 5169, 5173, 5177], "journal": ["sfk"],
        "zone": "Silverpine Forest", "entrance": (42.8, 67.5),
        "enter": "The keep stands on the hill above Pyrewood Village",
        # Stormwind first: the Alliance's 22-30s are round it, and Darnassus
        # is a detour from anywhere.
        "Alliance": {"towns": ["Stormwind City", "Darnassus", "Silverpine Forest"]},
        "Horde": {"towns": ["Undercity", "Silverpine Forest"]},
    },
    "STOCKADES": {
        "title": "The Stockade", "name": "The Stockade", "levels": (24, 32), "areas": [717], "journal": ["stockades"],
        "zone": "Stormwind City", "entrance": (50.8, 67.6),
        "enter": "The prison's door is on the canal between the Mage Quarter and the Trade District",
        "Alliance": {"towns": ["Wetlands", "Redridge Mountains", "Duskwood", "Westfall", "Stormwind City"]},
    },
    "BFD": {
        "title": "Blackfathom Deeps", "name": "Blackfathom Deeps", "levels": (24, 32), "areas": [719, 2797], "journal": ["bfd"],
        "zone": "Ashenvale", "entrance": (14.1, 14.4),
        "enter": "Out along the Zoram Strand to the sunken temple in the north-west; swim down into it",
        "Alliance": {"towns": ["Ironforge", "Darnassus", "Darkshore", "Ashenvale"]},
        # Tsunaman's Trouble in the Deeps is at Sun Rock Retreat, Grimtotem
        # Spying at Freewind Post; Blackfathom Villainy ends in Thunder Bluff.
        "Horde": {"towns": ["Thousand Needles", "Stonetalon Mountains", "Ashenvale"],
                  "back": ["Ashenvale", "Stonetalon Mountains", "Thunder Bluff", "Thousand Needles"]},
    },
    "GNOMER": {
        "title": "Gnomeregan", "name": "Gnomeregan", "levels": (29, 38), "areas": [721, 5134, 5152, 5162], "journal": ["gnomeregan"],
        "zone": "Dun Morogh", "entrance": (24.4, 39.6),
        "enter": "Gnomeregan's front door is in the valley west of Kharanos",
        "Alliance": {"towns": ["Stormwind City", "Ironforge", "Dun Morogh"]},
        # Rig Wars leads on to Scooty in Booty Bay.
        "Horde": {"towns": ["Orgrimmar", "Dun Morogh"], "back": ["Dun Morogh", "Orgrimmar", "Stranglethorn Vale"],
                  "travel": {"Dun Morogh": ("R", "Dun Morogh", "Ride into Dun Morogh by way of the Wetlands and Loch Modan: Gnomeregan is west of Kharanos")}},
    },
    "RFK": {
        "title": "Razorfen Kraul", "name": "Razorfen Kraul", "levels": (29, 38), "areas": [491, 1717], "journal": ["rfk"],
        "zone": "The Barrens", "entrance": (40.8, 89.4),
        "enter": "In the south of the Barrens, west of the Thousand Needles road, among the thorns",
        # The Crone of the Kraul and Lonebrow's Journal: Falfindel in Feralas.
        "Alliance": {"towns": ["Stormwind City", "Darnassus", "Feralas", "The Barrens"]},
        "Horde": {"towns": ["Undercity", "Orgrimmar", "Thunder Bluff", "The Barrens"]},
    },
    "SM": {
        "title": "Scarlet Monastery", "name": "Scarlet Monastery", "levels": (34, 45),
        "areas": [796, 5135, 5136, 5153, 5163], "journal": ["smgy", "smlib", "smarm", "smcath"],
        "zone": "Tirisfal Glades", "entrance": (83.0, 33.6),
        "enter": "In the north-east of Tirisfal Glades: the Graveyard, Library, Armory and Cathedral all open off the monastery's courtyard",
        # In the Name of the Light: Brother Crowley in Stormwind, Brother
        # Anton in Desolace, Raleigh the Devout in Southshore.
        "Alliance": {"towns": ["Stormwind City", "Ironforge", "Desolace", "Hillsbrad Foothills", "Tirisfal Glades"]},
        "Horde": {"towns": ["Thunder Bluff", "Orgrimmar", "Undercity", "Tirisfal Glades"]},
    },
    "RFD": {
        "title": "Razorfen Downs", "name": "Razorfen Downs", "levels": (37, 46), "areas": [722, 1316], "journal": ["rfd"],
        "zone": "The Barrens", "entrance": (49.6, 94.5),
        "enter": "In the south-east of the Barrens, at the top of the thorny ramp by the Great Lift",
        "Alliance": {"towns": ["Stormwind City", "Darnassus", "The Barrens"]},
        "Horde": {"towns": ["Undercity", "Thunder Bluff", "Orgrimmar", "The Barrens"]},
    },
    "ULDA": {
        "title": "Uldaman", "name": "Uldaman", "levels": (41, 51), "areas": [1337, 1517], "journal": ["ulda"],
        "zone": "Badlands", "entrance": (43.0, 13.9),
        "enter": "In the north of the Badlands: past the dig site (39.6, 18.5) to the temple doors",
        # Murdaloc, before Agmond's Fate, is done in the Badlands and handed
        # in in Loch Modan: there and back before going in.
        "Alliance": {"towns": ["Ironforge", "Loch Modan", "Badlands", "Loch Modan", "Badlands"],
                     "back": ["Badlands", "Loch Modan", "Ironforge"]},
        "Horde": {"towns": ["Orgrimmar", "Undercity", "Badlands"], "back": ["Badlands", "Undercity", "Orgrimmar", "Thunder Bluff"]},
    },
    "ZF": {
        "title": "Zul'Farrak", "name": "Zul'Farrak", "levels": (44, 54), "areas": [1176, 978], "journal": ["zf"],
        "zone": "Tanaris", "entrance": (39.2, 20.1),
        "enter": "In the north-west of Tanaris, through the desert gate",
        # Tabetha's Tiara of the Deep, Wizzle Brassbolts' Gahz'rilla, the
        # Screecher Spirits Yeh'kinya sends to Feralas before the Prophecy,
        # and for the Horde, Master Gadrin's Spider God in Sen'jin Village.
        "Alliance": {"towns": ["Dustwallow Marsh", "Thousand Needles", "Tanaris", "Feralas", "Tanaris"],
                     "back": ["Tanaris", "Thousand Needles", "Dustwallow Marsh"]},
        "Horde": {"towns": ["Durotar", "Dustwallow Marsh", "Thousand Needles", "Tanaris", "Feralas", "Tanaris"],
                  "back": ["Tanaris", "Thousand Needles", "Dustwallow Marsh", "Durotar"]},
    },
    "MARA": {
        "title": "Maraudon", "name": "Maraudon", "levels": (46, 55), "areas": [2100], "journal": ["mara"],
        "zone": "Desolace", "entrance": (29.2, 63.0),
        "enter": "In the south-west of Desolace: down into the Maraudon caves, and through the purple or the orange crystal door",
        # Shadowshard Fragments: Archmage Tervosh in Theramore, Uthel'nay in
        # Orgrimmar.
        "Alliance": {"towns": ["Dustwallow Marsh", "Desolace"]},
        "Horde": {"towns": ["Durotar", "Desolace"]},
    },
    "ST": {
        "title": "Sunken Temple", "name": "The Temple of Atal'Hakkar", "levels": (50, 60), "areas": [1477, 5137, 5154], "journal": ["st"],
        "zone": "Swamp of Sorrows", "entrance": (70.1, 54.6),
        "enter": "The entrance is at the bottom of the Pool of Tears",
        # The Alliance's way in starts in Stormwind: the temple found, the
        # Hinterlands, Rhapsody's cocktail from Feralas and Tanaris, back to
        # Stormwind for the tablets. The Stone Circle is in Ratchet, and
        # Haze of Evil's chain in Un'Goro and Feralas.
        "Alliance": {"towns": ["Stormwind City", "Swamp of Sorrows", "Stormwind City", "The Hinterlands",
                               "Un'Goro Crater", "Feralas", "Tanaris", "The Barrens", "Tanaris",
                               "The Hinterlands", "Stormwind City", "Swamp of Sorrows"],
                     "back": ["Swamp of Sorrows", "The Hinterlands", "Stormwind City", "Un'Goro Crater", "Tanaris"],
                     "travel": {"The Barrens": ("F", "Ratchet", "Fly to Ratchet in the Barrens")}},
        # The Horde's: Uzer'i in Feralas to Marvon, Larion's chain in Un'Goro
        # and Ratchet, and Fel'Zerul's by way of the Hinterlands.
        "Horde": {"towns": ["Feralas", "Tanaris", "Un'Goro Crater", "The Barrens", "Tanaris",
                            "Swamp of Sorrows", "The Hinterlands", "Swamp of Sorrows"],
                  "back": ["Swamp of Sorrows", "The Hinterlands", "Un'Goro Crater", "Tanaris"],
                  "travel": {"The Barrens": ("F", "Ratchet", "Fly to Ratchet in the Barrens")}},
    },
    "BRD": {
        "title": "Blackrock Depths", "name": "Blackrock Depths", "levels": (52, 60), "areas": [1584, 5140], "journal": ["brd"],
        "zone": "Burning Steppes", "entrance": (29.5, 38.1),
        # No place in the Searing Gorge here: a step's points are all put on
        # its own zone's map, the Burning Steppes'.
        "enter": "Into Blackrock Mountain from the Burning Steppes -- or from the Searing Gorge -- and take the chains down to Blackrock Depths' portal at the bottom of the mountain",
        "Alliance": {"towns": ["Ironforge", "Badlands", "Searing Gorge", "Burning Steppes"]},
        "Horde": {"towns": ["Undercity", "Badlands", "Searing Gorge", "Burning Steppes"]},
    },
    # Turtle WoW's own, InstanceJournal's levels and entrances.
    "FH": {
        "title": "Frostmane Hollow", "name": "Frostmane Hollow", "levels": (13, 20), "areas": [5734, 5735],
        "journal": ["fh"], "zone": "Dun Morogh", "entrance": (66.9, 40.3),
        "enter": "By the Ironforge Airfield, in the east of Dun Morogh; the meeting stone is just south (65.9, 42.4)",
        # Brohann Caskbelly's Evenpike in Stormwind, Shandlar Thethis' pelt
        # in Alah'Thalas; Mountaineer Granitebeard is at the airfield.
        "Alliance": {"towns": ["Stormwind City", "Alah'Thalas", "Dun Morogh"]},
        # Cross-faction groups: the Horde can run it too, for Ranix
        # Crackbolt's quest, given and taken inside.
        "Horde": {"towns": ["Dun Morogh"],
                  "enter": "Ride into Dun Morogh by way of the Wetlands and Loch Modan. The entrance is by the Ironforge Airfield, in the east; the meeting stone is just south (65.9, 42.4)"},
    },
    "DMR": {
        "title": "Dragonmaw Retreat", "name": "Dragonmaw Retreat", "levels": (26, 35), "areas": [5600, 5601],
        "journal": ["dmr"], "zone": "Wetlands", "entrance": (67.3, 63.3),
        "enter": "In the east of the Wetlands, below Grim Batol",
        "Alliance": {"towns": ["Wetlands"]},
        # Okul's Cavernweb Extract is at Hammerfall, Shara Blazen's A Blaze
        # Unending in the Alterac Mountains.
        "Horde": {"towns": ["Alterac Mountains", "Arathi Highlands", "Wetlands"]},
    },
    "WHC": {
        "title": "Windhorn Canyon", "name": "Windhorn Canyon", "levels": (26, 30), "areas": [5641, 5731],
        "journal": ["whc"], "zone": "Thousand Needles", "entrance": (64.6, 45.9),
        "enter": "Into the Windhorn Caverns, in the east of Thousand Needles by the meeting stone (64, 53.7): the canyon is at their far end",
        "Alliance": {"towns": ["Ironforge", "Thousand Needles"]},
        # Cliffwatcher Longhorn's Grimtotem Spying, at Freewind Post, leads
        # to Cairne in Thunder Bluff, who sends you in for Stormhoof; Shovu,
        # at the Earthen Ring in Stonetalon, sends a Shaman for Vortalus.
        "Horde": {"towns": ["Stonetalon Mountains", "Thousand Needles", "Thunder Bluff", "Thousand Needles"],
                  "back": ["Thousand Needles", "Thunder Bluff", "Stonetalon Mountains"]},
    },
    "CG": {
        "title": "Crescent Grove", "name": "Crescent Grove", "levels": (33, 39), "areas": [5077],
        "journal": ["cg"], "zone": "Ashenvale", "entrance": (51.0, 77.3),
        "enter": "In the south of Ashenvale",
        "Alliance": {"towns": ["Darnassus", "Ashenvale"]},
        "Horde": {"towns": ["Ashenvale"]},
    },
    "SWR": {
        "title": "Stormwrought Ruins", "name": "Stormwrought Ruins", "levels": (32, 44), "areas": [5628, 5570],
        "journal": ["swr"], "zone": "Balor", "entrance": (57.1, 60.1),
        "enter": "Stormwrought Castle, on the cliffs of Balor",
        "Alliance": {"towns": ["Grim Reaches", "Balor"]},
        "Horde": {"towns": ["Grim Reaches", "Balor"]},
    },
    "GC": {
        "title": "Gilneas City", "name": "Gilneas City", "levels": (43, 52), "areas": [5208, 5180],
        "journal": ["gc"], "zone": "Gilneas", "entrance": (27.4, 30.1),
        "enter": "The gates of Gilneas City, in the north-west of Gilneas",
        "Alliance": {"towns": ["Gilneas"]},
        "Horde": {"towns": ["Gilneas"]},
    },
    "HQ": {
        "title": "Hateforge Quarry", "name": "Hateforge Quarry", "levels": (51, 60), "areas": [5103, 5098, 5101],
        "journal": ["hq"], "zone": "Burning Steppes", "entrance": (97.5, 59.1),
        "enter": "At the far eastern edge of the Burning Steppes",
        "Alliance": {"towns": ["Burning Steppes"]},
        "Horde": {"towns": ["Burning Steppes"]},
    },
}
# How to get to a town, per side, where "Travel to" would not do: a flight
# to the town the step is named for, which completes as you land there.
TRAVEL = {
    "Alliance": {
        "Tanaris": ("F", "Gadgetzan", "Fly to Gadgetzan in Tanaris"),
        "The Hinterlands": ("F", "Aerie Peak", "Fly to Aerie Peak in the Hinterlands"),
        "Swamp of Sorrows": ("F", "Nethergarde Keep", "Fly to Nethergarde Keep in the Blasted Lands, and ride north into the Swamp of Sorrows"),
        "Un'Goro Crater": ("F", "Marshal's Refuge", "Fly to Marshal's Refuge in Un'Goro Crater"),
        "Loch Modan": ("F", "Thelsamar", "Fly to Thelsamar in Loch Modan"),
        "Wetlands": ("F", "Menethil Harbor", "Fly to Menethil Harbor in the Wetlands"),
        "Hillsbrad Foothills": ("F", "Southshore", "Fly to Southshore in Hillsbrad Foothills"),
        "Feralas": ("F", "Thalanaar", "Fly to Thalanaar in Feralas"),
        "Stranglethorn Vale": ("F", "Booty Bay", "Fly to Booty Bay in Stranglethorn Vale"),
        "Darkshore": ("F", "Auberdine", "Fly to Auberdine in Darkshore"),
        "Ashenvale": ("F", "Astranaar", "Fly to Astranaar in Ashenvale"),
        "Westfall": ("F", "Sentinel Hill", "Fly to Sentinel Hill in Westfall"),
        "Redridge Mountains": ("F", "Lakeshire", "Fly to Lakeshire in Redridge Mountains"),
        "Duskwood": ("F", "Darkshire", "Fly to Darkshire in Duskwood"),
        "Desolace": ("F", "Nijel's Point", "Fly to Nijel's Point in Desolace"),
        "Searing Gorge": ("F", "Thorium Point", "Fly to Thorium Point in the Searing Gorge"),
        "Burning Steppes": ("F", "Morgan's Vigil", "Fly to Morgan's Vigil in the Burning Steppes"),
    },
    "Horde": {
        "Tanaris": ("F", "Gadgetzan", "Fly to Gadgetzan in Tanaris"),
        "The Hinterlands": ("F", "Revantusk Village", "Fly to Revantusk Village in the Hinterlands"),
        "Swamp of Sorrows": ("F", "Stonard", "Fly to Stonard in the Swamp of Sorrows"),
        "Un'Goro Crater": ("F", "Marshal's Refuge", "Fly to Marshal's Refuge in Un'Goro Crater"),
        "Feralas": ("F", "Camp Mojache", "Fly to Camp Mojache in Feralas"),
        "Thousand Needles": ("F", "Freewind Post", "Fly to Freewind Post in Thousand Needles"),
        "Stonetalon Mountains": ("F", "Sun Rock Retreat", "Fly to Sun Rock Retreat in the Stonetalon Mountains"),
        "Stranglethorn Vale": ("F", "Booty Bay", "Fly to Booty Bay in Stranglethorn Vale"),
        "Badlands": ("F", "Kargath", "Fly to Kargath in the Badlands"),
        "Ashenvale": ("F", "Splintertree Post", "Fly to Splintertree Post in Ashenvale"),
        "Arathi Highlands": ("F", "Hammerfall", "Fly to Hammerfall in the Arathi Highlands"),
        "Silverpine Forest": ("F", "The Sepulcher", "Fly to the Sepulcher in Silverpine Forest"),
        "Desolace": ("F", "Shadowprey Village", "Fly to Shadowprey Village in Desolace"),
        "Searing Gorge": ("F", "Thorium Point", "Fly to Thorium Point in the Searing Gorge"),
        "Burning Steppes": ("F", "Flame Crest", "Fly to Flame Crest in the Burning Steppes"),
    },
}

# Quests no dungeon guide should take, that a chain pulls in: repeatable
# turn-ins, a profession's chain, a zone's own quests.
SKIP = {
    8588, 8589, 60032,                   # Heavy Leather
    224, 237, 263, 217,                  # In Defense of the King's Lands: Loch Modan's troggs
    3375,                                # Replacement Phial: only if you lose the one you have
    41277, 41278, 41279, 41280, 41281, 41282, 41333, 41334,   # Thegren's gemology
    819, 821, 822,                       # Chen's Empty Keg: the Barrens' own
    2951, 2952, 2953, 4601, 4602, 4603, 4604, 4605, 4606,     # The Sparklematic 5200's grime, again and again
    5381, 5581,                          # Taiga Wisemane's, in Desolace, not Maraudon
    6642, 6643, 6644, 6645, 6646, 41126, # Favor Amongst the Brotherhood: over and over, for reputation
    7736, 8241, 8242,                    # Restoring Fiery Flux Supplies: likewise
    8961,                                # Three Kings of Flame: Blackrock Spire's and the Molten Core's too
    7944,                                # Your Fortune Awaits You: the Darkmoon Faire's
}
# Where the data has no giver or taker for a quest: qid -> {"start"/"end":
# [(kind, id)]}.
FIX = {
    2278: {"start": [("O", 131474)], "end": [("O", 131474)]},    # The Platinum Discs: the Discs of Norgannon
    3446: {"end": [("O", 148836)]},                              # Into the Depths: the Altar of Hakkar
    3373: {"end": [("O", 148512)]},                              # The Essence of Eranikus: the Essence Font
}
# Quests InstanceJournal does not list for a dungeon that belong to it.
ADD = {
    "ST": [3528],                        # The God Hakkar: the egg is filled inside
    "GNOMER": [2841],                    # Rig Wars: pfQuest has no Thermaplugg to drop the blueprints
    "MARA": [7041],                      # Vyletongue Corruption, the Alliance's: the vial is filled inside
}
# What the data has no spawns for: qid -> where the objective is ("in" for
# inside the dungeon), the points there, and what the step says.
TASK = {
    709: ("Badlands", [(39.3, 18.8)], "Loot the Tablet of Ryun'eh from the Ancient Chest in the dig site, outside the instance"),
    3520: ("Feralas", [(48.5, 49.6), (44.7, 37.6), (58.1, 49.0)],
           "Kill Vale Screechers and Rogue Vale Screechers, and use Yeh'kinya's Bramble on their bodies for 3 Screecher Spirits"),
    7029: ("in", [], None), 7041: ("in", [], None),      # Vyletongue Corruption: the vial and the vines
    # Windhorn Canyon's, which the 1.18.1 data has the text of and no more.
    41976: ("in", [], "Gather 8 Windhorn Relics in the canyon"),
    41977: ("in", [], "Gather 8 Windhorn Relics in the canyon"),
    41978: ("in", [], "Kill 20 Blackwind Villagers"),
    41939: ("in", [], "Banish Ambassador Vortalus, the elemental figurehead"),
    41982: ("in", [], "Kill Prophet Stormhoof, the leader of the Deathtotem"),
    42038: ("Dun Morogh", [(70.1, 39.7), (66.8, 38.6), (67.2, 40.9)],
            "Kill 8 Frostmane Scouts, 6 Frostmane Drudges and 6 Frostmane Mystics round the airfield"),
    4134: ("in", [], "Kill Hurley Blackbreath and his cronies in the Grim Guzzler for the Lost Thunderbrew Recipe"),
    3525: ("in", [], "Protect Belnistrasz while he extinguishes the idol: speak with him when your group is ready"),
    3528: ("in", [], "Use the Egg of Hakkar at the Altar of Hakkar, and kill the Hakkari Bloodkeepers as the Avatar comes: "
                     "fill the egg with their blood, then kill the Avatar of Hakkar"),
}
# Quests the data takes for a word with their giver that need another
# dungeon's run first: The Ancient Egg is Gahz'rilla's, in Zul'Farrak.
FAR = {4787, 40466}      # and To Purchase Secret Information is Jabbey's, in Steamwheedle Port
# An NPC pfQuest places in two zones, where the maps overlap: the one it
# stands in.
NATIVE = {"Torwa Pathfinder": "Un'Goro Crater"}
ARTICLE = {"Badlands": "the Badlands", "Undercity": "the Undercity"}
EVENT = {"Listen", "Behold", "Face", "Defend", "Protect", "Escort", "Watch", "Accompany", "Guard"}


# --------------------------------------------------------------------------
# Reading pfQuest
# --------------------------------------------------------------------------

IJ_CLASSES = {"Warrior": 1, "Paladin": 2, "Hunter": 4, "Rogue": 8, "Priest": 16, "Shaman": 64,
              "Mage": 128, "Warlock": 256, "Druid": 1024}


def journal(path):
    """InstanceJournal's instances and quests: {file: [quest ids]}, and
    {qid: {"class": mask, "pre": [ids]}}."""
    lists = {}
    for f in glob.glob(os.path.join(path, "db", "dungeons", "*.lua")):
        text = open(f, encoding="utf-8").read()
        m = re.search(r"\.Quests\s*=\s*\{(.*?)\}\s*\n", text, re.S)
        lists[os.path.basename(f)[:-4]] = [int(q) for q in re.findall(r"IJDB\.Q\[(\d+)\]", m.group(1))] if m else []
    quests = {}
    text = open(os.path.join(path, "db", "quests.lua"), encoding="utf-8").read()
    for m in re.finditer(r"\nQ\[(\d+)\] = \{(.*?)\n\}", text, re.S):
        body = m.group(2)
        cls = re.search(r"RequiredClass = \{([^}]*)\}", body)
        pre = re.search(r"RequiredQuests = \{([^}]*)\}", body)
        quests[int(m.group(1))] = {
            "class": sum(IJ_CLASSES.get(c, 0) for c in re.findall(r"IMCL\.(\w+)", cls.group(1))) if cls else 0,
            "pre": [int(q) for q in re.findall(r"Q\[(\d+)\]", pre.group(1))] if pre else [],
        }
    return lists, quests


def collect(pfquest, turtle, instancejournal):
    """Every dungeon's quests, the quests around them, and what the guides
    need to know of each."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from build_zone_guide import Data, Quest, entries, parse, seq, clusters
    data = Data(turtle, pfquest)
    # Data reads the Turtle quest table. pfQuest's fills in the rest, and
    # what a Turtle entry leaves out: the 1.18.1 scrape has no class on some.
    tq = entries(Data.path(turtle, "quests", "-turtle"))
    removed = {q for q, t in tq.items() if t is None}
    for q, t in entries(Data.path(pfquest, "quests", "")).items():
        if t and q not in removed:
            data.quests[q] = dict(parse(t), **data.quests.get(q, {}))
    tt = entries(Data.path(turtle, "quests", "-turtle", True))
    for q, t in entries(Data.path(pfquest, "quests", "", True)).items():
        if t and q not in tt:
            data.text[q] = {k: v for k, v in parse(t).items() if isinstance(v, str)}
    for q, fix in FIX.items():
        for key, whom in fix.items():
            part = data.quests[q].setdefault(key, {})
            for kind, i in whom:
                part.setdefault(kind, {})[len(part.get(kind, {})) + 1] = i
    # InstanceJournal's class and the quest before, where pfQuest has none:
    # Vortalus' Edict is the Shaman's.
    lists, ij = journal(instancejournal)
    for q, v in ij.items():
        t = data.quests.get(q)
        if not t:
            continue
        if v["class"] and not t.get("class"):
            t["class"] = v["class"]
        if v["pre"] and not t.get("pre"):
            t["pre"] = {i + 1: p for i, p in enumerate(v["pre"])}

    def ids(t, key, kind):
        return [i for i in seq((t.get(key) or {}).get(kind)) if isinstance(i, int)]

    def usable(q):
        t = data.quests.get(q)
        return t and q not in removed and q not in SKIP and not t.get("skill") and not t.get("event")

    model = {"quests": {}, "dungeons": {}, "missing": {}}
    wanted = set()
    for code, d in DUNGEONS.items():
        picked = [q for f in d["journal"] for q in lists.get(f, [])] + ADD.get(code, [])
        model["missing"][code] = sorted({q for q in picked if q not in data.quests})
        picked = sorted({q for q in picked if usable(q)})
        model["dungeons"][code] = picked
        wanted |= set(picked)

    # The quests before them, all the way back, and those after.
    def pre_of(q):
        return [p for p in seq((data.quests.get(q) or {}).get("pre")) if isinstance(p, int)]
    todo = list(wanted)
    while todo:
        for p in pre_of(todo.pop()):
            if usable(p) and p not in wanted:
                wanted.add(p)
                todo.append(p)
    after = {}
    for q in data.quests:
        for p in pre_of(q):
            after.setdefault(p, []).append(q)
    todo = list(wanted)
    while todo:
        for f in after.get(todo.pop(), []):
            if usable(f) and f not in wanted:
                wanted.add(f)
                todo.append(f)

    cfg = {"text": {}, "pre": {}, "spots": {}, "npc": {}, "places": [], "skip": set()}
    all_areas = {a for d in DUNGEONS.values() for a in d["areas"]}
    for q in sorted(wanted):
        t = data.quests[q]
        qo = Quest(data, q, 0, cfg)
        model["quests"][str(q)] = {
            "title": qo.title, "lvl": qo.lvl, "min": qo.min, "race": qo.race, "class": qo.cls,
            "pre": [p for p in pre_of(q) if usable(p)],
            "doing": qo.needs_c, "explore": bool(ids(t, "obj", "A")),
            "task": qo.task() if qo.needs_c else "", "text": qo.objective,
            "givers": [place(data, k, i) for k, i in qo.starters],
            "items": [{"id": i, "name": data.name("I", i), "from": [place(data, k, j) for k, j in data.drops(i)[:6]]}
                      for i in qo.start_items],
            "takers": [place(data, k, i) for k, i in qo.enders],
            "obj": objective_spots(data, qo, all_areas, clusters),
        }
    return model


def place(data, kind, i):
    """An NPC or object: its name, and its spawns by zone, the first of each."""
    by = {}
    for x, y, z in data.spawns(kind, i):
        by.setdefault(data.zone(z) or str(z), [round(x, 1), round(y, 1), z])
    return {"name": data.name(kind, i), "at": by}


def objective_spots(data, qo, areas, clusters):
    """Where a quest's objectives are: {zone, or dungeon area id: [points]}."""
    pts = {}
    things = [(k, i) for k in ("U", "O") for i in qo.obj[k]]
    for item in qo.obj["I"]:
        things += data.drops(item)
    for kind, i in things:
        for x, y, z in data.spawns(kind, i):
            key = str(z) if z in areas else data.zone(z)
            if key:
                pts.setdefault(key, []).append((x, y))
    return {k: [[round(p[0], 1), round(p[1], 1)] for p in clusters(v)] for k, v in pts.items()}


# --------------------------------------------------------------------------
# One guide
# --------------------------------------------------------------------------

def fmt(p):
    def n(v):
        return ("%.1f" % v).rstrip("0").rstrip(".")
    return "(%s, %s)" % (n(p[0]), n(p[1]))


class Who:
    def __init__(self, name, inside=False, zone=None, point=None, item=None):
        self.name, self.inside, self.zone, self.point, self.item = name, inside, zone, point, item


class Guide:
    """One dungeon's guide for one side."""

    def __init__(self, model, code, side, mask):
        self.code, self.side, self.mask = code, side, mask
        self.d = DUNGEONS[code]
        cfg = self.d[side]
        self.areas = {str(a) for a in self.d["areas"]}
        self.towns = cfg["towns"]
        self.back = cfg.get("back") or list(reversed(self.towns))
        self.travel = dict(TRAVEL[side], **(cfg.get("travel") or {}))
        self.q = {int(k): dict(v) for k, v in model["quests"].items()
                  if (not v["race"] or v["race"] & mask) and int(k) not in SKIP}
        # A quest that follows only the other side's is not this side's.
        known = {int(k) for k in model["quests"]}
        gone = True
        while gone:
            gone = [q for q, v in self.q.items()
                    if v["pre"] and all(p in known and p not in self.q for p in v["pre"])]
            for q in gone:
                del self.q[q]
        for q, v in self.q.items():
            # An escort or an event is something to do, where it is given.
            words = v["text"].split()
            if words and words[0] in EVENT:
                v["doing"] = True
            # What a step says: the task, or the whole objective where that
            # is all the task kept ("Return"), or where a place is to be found.
            if v["explore"]:
                v["task"] = "Explore: %s" % (v["text"] or v["title"])
            elif len(v["task"]) < 16:
                v["task"] = v["text"] or v["task"]
        for q, (zone, spots, task) in TASK.items():
            if q in self.q:
                key = str(self.d["areas"][0]) if zone == "in" else zone
                self.q[q] = dict(self.q[q], doing=True, task=task or self.q[q]["text"],
                                 obj=dict(self.q[q]["obj"], **{key: [list(p) for p in spots]}))
        self.core = [q for q in model["dungeons"][code] if q in self.q]
        for q in ADD.get(code, ()):
            if q in self.q and q not in self.core:
                self.core.append(q)
        self.left_out = []
        self.lines = []
        self.bosses = model.get("bosses", {}).get(code, [])

    # -- the bosses ----------------------------------------------------------

    def boss_for(self, q):
        """Which boss a quest's objective is about, by its name in the task
        ("Kill Edwin VanCleef", "Bring Mutanus's head"): its index in
        self.bosses, or None."""
        v = self.q[q]
        text = "%s %s" % (v["task"], v["text"])
        best = None
        for i, b in enumerate(self.bosses):
            for name in {b["name"], b.get("creature") or b["name"]}:
                if name in text and (best is None or len(name) > best[1]):
                    best = (i, len(name))
        return best and best[0]

    def boss_step(self, b):
        """K <boss>: what it does, what each role does about it, and whose
        death ticks it. A rare one is optional: it is not always there."""
        import dungeon_tactics as tactics
        t = tactics.TACTICS.get(b["id"])
        if t:
            note = t["note"]
        elif b.get("creature") and not b.get("spells") and not b["journal"]:
            note = "No special abilities known."
        else:
            note = "Pathfinder has no notes on this fight yet."
        if b["rare"]:
            note = "Rare: not always here. " + note
        tags = ["|N|%s|" % note]
        for role in ("tank", "heal", "dps"):
            if t and t[role]:
                tags.append("|%s|%s|" % (role.upper(), t[role]))
        watch = tactics.WATCH.get(b["id"], [b.get("creature") or b["name"]])
        if watch:
            tags.append("|BOSS|%s|" % ";".join(watch))
        if b["rare"]:
            tags.append("|O|")
        self.lines.append(" ".join(["K %s" % b["name"]] + tags))

    # -- where things are ----------------------------------------------------

    def who(self, people):
        """The first of a quest's givers or takers inside the dungeon, else
        in the earliest of its towns, else anywhere."""
        best = None
        for p in people:
            if p["name"] in NATIVE and NATIVE[p["name"]] in p["at"]:
                zone = NATIVE[p["name"]]
                return Who(p["name"], zone=zone, point=p["at"][zone][:2])
            here = p["at"].get(self.d["zone"])
            for zone, pt in p["at"].items():
                if str(pt[2]) in self.areas:
                    # pfQuest's area for a dungeon takes in the ground by its
                    # door: one that is on the zone's map as well stands out
                    # there -- Uldaman's dig site, Gnomeregan's facility.
                    if here:
                        return Who(p["name"], zone=self.d["zone"], point=here[:2])
                    return Who(p["name"], inside=True)
                if zone in self.towns or zone in self.back:
                    rank = self.towns.index(zone) if zone in self.towns else len(self.towns)
                    if best is None or rank < best[0]:
                        best = (rank, Who(p["name"], zone=zone, point=pt[:2]))
        if best:
            return best[1]
        for p in people:
            for zone, pt in sorted(p["at"].items(), key=lambda kv: kv[1][2] >= 5000):
                return Who(p["name"], zone=zone, point=pt[:2])
        return Who(people[0]["name"]) if people else None

    def giver(self, q):
        v = self.q[q]
        if v["givers"]:
            return self.who(v["givers"])
        for it in v["items"]:
            # An item that starts a quest: where it drops -- inside, when
            # pfQuest does not know and the quest is the dungeon's.
            src = self.who(it["from"]) if it["from"] else None
            inside = src.inside if src else q in self.core
            return Who(it["name"], inside=inside, zone=src and src.zone, item=it["id"])
        return None

    def taker(self, q):
        # No one to take it back, in the data: whoever gave it ("return to
        # Master Gadrin").
        v = self.q[q]
        return self.who(v["takers"] or v["givers"])

    def reachable(self, w):
        return w and (w.inside or w.zone in self.towns or w.zone in self.back)

    def work(self, q):
        """Where a quest's objectives are: "in", a town, None for nothing to
        do but hand it in -- or "far", somewhere the guide does not go."""
        v = self.q[q]
        if q in FAR:
            return "far"
        if v["explore"]:
            # A place to find, and pfQuest does not say where: inside, or
            # for a quest before the dungeon's, by its entrance.
            return "in" if q in self.core else self.d["zone"]
        if not v["doing"]:
            return None
        if any(k in self.areas for k in v["obj"]):
            return "in"
        if not v["obj"]:
            # Something to do the data has no spawns for: inside, if it is
            # given and taken there -- the Idol after the Altar -- else a
            # walk to whoever takes it.
            g, t = self.giver(q), self.taker(q)
            if g and g.inside and t and t.inside:
                return "in"
            names = (self.d["title"], self.d["name"]) + tuple(self.d.get("aka", ()))
            return "in" if q in self.core and any(n in v["text"] for n in names) else None
        for town in [self.d["zone"]] + self.towns:
            if town in v["obj"]:
                return town
        return "far"

    # -- which quests ------------------------------------------------------------

    def select(self):
        """take: {qid: "core" | "before" | "after"}; optional: {qid: [the
        quests before it the guide does not do]}."""
        take, optional = {}, {}

        def fine(q):
            return (self.reachable(self.giver(q)) and self.reachable(self.taker(q)) and
                    self.work(q) != "far")

        def before(q, seen):
            """Take the quests before q the guide can do; the rest, missing."""
            gaps = []
            for p in self.q[q]["pre"]:
                if p not in self.q or p in take:
                    continue
                if p in seen or not fine(p):
                    gaps.append(p)
                    continue
                if not before(p, seen | {p}):
                    take[p] = "before"
                else:
                    gaps.append(p)
            return gaps
        for q in sorted(self.core, key=lambda q: self.q[q]["lvl"]):
            if not fine(q):
                self.left_out.append(q)
                continue
            take[q] = "core"
            gaps = before(q, {q})
            if gaps:
                optional[q] = gaps
        # What they lead to, while it stays on the way: a word, a delivery,
        # or more inside.
        grew = True
        while grew:
            grew = False
            for q, v in sorted(self.q.items()):
                pres = [p for p in v["pre"] if p in self.q]
                if q in take or not pres or not all(p in take for p in pres):
                    continue
                if not fine(q) or self.work(q) not in (None, "in"):
                    continue
                if v["lvl"] > self.d["levels"][1] + AFTER:
                    continue
                take[q] = "after"
                grew = True
        # A quest started by an item that drops is there only for whoever has
        # the item; and a quest after an optional one is optional too.
        for q in take:
            g = self.giver(q)
            if g and g.item and q not in optional:
                optional[q] = []
        grew = True
        while grew:
            grew = False
            for q in take:
                if q not in optional and any(p in optional for p in self.q[q]["pre"]):
                    optional[q] = [p for p in self.q[q]["pre"] if p in optional]
                    grew = True
        self.take, self.optional = take, optional

    # -- writing -------------------------------------------------------------

    def where(self, q, zone):
        """ (x, y) ... for the objectives in the zone, and the other zones
        where they are found too -- by name: every point in a step's note is
        put on its own zone's map."""
        obj = self.q[q]["obj"]
        out = " ".join(fmt(p) for p in obj.get(zone, []))
        others = [z for z, pts in sorted(obj.items())
                  if z != zone and z not in self.areas and z in self.towns + self.back and pts]
        if others:
            out += "%s-- also in %s" % (" " if out else "", "; ".join(others))
        return " " + out if out else ""

    def step(self, action, title, q=None, note="", zone=None, use=None, extra=None):
        tags = []
        if q:
            tags.append("|QID|%d|" % q)
        if note:
            tags.append("|N|%s|" % note)
        if zone:
            tags.append("|Z|%s|" % zone)
        if use:
            tags.append("|U|%d|" % use)
        if q:
            v = self.q[q]
            if v["class"] and v["class"] & ALL_CLASSES != ALL_CLASSES:
                tags.append("|C|%s|" % "/".join(n for b, n in CLASSES if v["class"] & b))
            if v["race"] and v["race"] & self.mask != self.mask:
                tags.append("|R|%s|" % "/".join(n for b, n in RACES if v["race"] & b))
            if q in self.optional or (use and action == "A"):
                tags.append("|O|")
            if self.optional.get(q) and action == "A":
                tags.append("|PRE|%s|" % ", ".join(str(p) for p in self.optional[q]))
        tags.extend(extra or [])
        self.lines.append(" ".join(["%s %s" % (action, title)] + tags))

    def trip_tags(self, steps):
        """What a trip to a town is for: only the classes, or races, that
        every quest there is for -- Darnassus for Shadowfang Keep is one
        Priest, Mage, Warlock and Druid quest -- and, when every quest there
        is optional and waits on the same quest first, that wait."""
        tags, classes, races = [], 0, 0
        for _, q, _ in steps:
            v = self.q[q]
            c = v["class"] if v["class"] and v["class"] & ALL_CLASSES != ALL_CLASSES else 0
            r = v["race"] if v["race"] and v["race"] & self.mask != self.mask else 0
            if classes is not None:
                classes = classes | c if c else None
            if races is not None:
                races = races | r if r else None
        if classes:
            tags.append("|C|%s|" % "/".join(n for b, n in CLASSES if classes & b))
        if races:
            tags.append("|R|%s|" % "/".join(n for b, n in RACES if races & b))
        pres = {tuple(self.optional[q]) if self.optional.get(q) else None for _, q, _ in steps}
        if len(pres) == 1 and None not in pres and all(q in self.optional for _, q, _ in steps):
            tags.append("|O|")
            tags.append("|PRE|%s|" % ", ".join(str(p) for p in pres.pop()))
        return tags

    def gap(self):
        if self.lines and self.lines[-1] != "":
            self.lines.append("")

    def build(self):
        self.select()
        # Quests for the dungeon given where the guide does not go -- most of
        # them a class's -- named, so nobody misses one.
        elsewhere = []
        for q in self.left_out:
            v, g = self.q[q], self.giver(q)
            if g and g.zone and not g.item and v["lvl"] <= self.d["levels"][1] + AFTER:
                who = "%s%s" % (v["title"], " (%s)" % "/".join(n for b, n in CLASSES if v["class"] & b)
                                if v["class"] and v["class"] & ALL_CLASSES != ALL_CLASSES else "")
                elsewhere.append("%s, from %s in %s" % (who, g.name, g.zone))
        if elsewhere:
            self.step("N", "Given elsewhere", note="Also for %s, not on this guide's way: %s" % (
                self.d["title"], "; ".join(elsewhere)))
        done, log, did = set(), set(), set()
        order = sorted(self.take, key=lambda q: (self.q[q]["lvl"], q))

        def ready(q):
            return all(p in done for p in self.q[q]["pre"] if p in self.take)

        def complete(q):
            return q in did or not self.work(q)

        def in_town(zone, leaving):
            steps, changed = [], True
            while changed:
                changed = False
                for q in order:
                    t = self.taker(q)
                    if q in log and t and not t.inside and t.zone == zone and complete(q):
                        steps.append(("T", q, t))
                        log.discard(q)
                        done.add(q)
                        changed = True
                for q in order:
                    g = self.giver(q)
                    if q not in log and q not in done and g and not g.inside and g.zone == zone and ready(q):
                        if q in self.optional and not leaving and self.work(q) not in ("in", self.d["zone"]):
                            continue     # someone else's chain: offered on the way back
                        steps.append(("A", q, g))
                        log.add(q)
                        changed = True
                for q in order:
                    if q in log and q not in did and self.work(q) == zone:
                        steps.append(("C", q, None))
                        did.add(q)
                        changed = True
            return steps

        def inside():
            steps, changed = [], True
            while changed:
                changed = False
                for q in order:
                    g = self.giver(q)
                    if q not in log and q not in done and g and g.inside and ready(q):
                        steps.append(("A", q, g))
                        log.add(q)
                        changed = True
                    if q in log and q not in did and self.work(q) == "in":
                        steps.append(("C", q, None))
                        did.add(q)
                        changed = True
                    t = self.taker(q)
                    if q in log and t and t.inside and complete(q):
                        steps.append(("T", q, t))
                        log.discard(q)
                        done.add(q)
                        changed = True
            return steps

        def nearest_first(zone, steps):
            """The town's steps from one NPC to the nearest next, each once
            what it needs is done: a turn-in after its objectives, an accept
            after the quest before it."""
            def point(s):
                action, q, w = s
                if action == "C":
                    pts = self.q[q]["obj"].get(zone)
                    return tuple(pts[0]) if pts else None
                return tuple(w.point) if w and w.point else None
            left, out, placed, here = list(steps), [], set(), None
            while left:
                def ok(s):
                    action, q, _ = s
                    needs = []
                    if action == "A":
                        needs = [("T", p) for p in self.q[q]["pre"]]
                    elif action == "C":
                        needs = [("A", q)]
                    elif action == "T":
                        needs = [("A", q), ("C", q)]
                    return all(n in placed or not any((a, b) == n for a, b, _ in left) for n in needs)
                ready = [s for s in left if ok(s)] or left[:1]
                if here:
                    ready.sort(key=lambda s: math.hypot(*(a - b for a, b in zip(point(s), here))) if point(s) else 0)
                pick = ready[0]
                left.remove(pick)
                out.append(pick)
                placed.add((pick[0], pick[1]))
                here = point(pick) or here
            return out

        def write_town(zone, steps, leaving):
            if not steps:
                return
            steps = nearest_first(zone, steps)
            self.gap()
            if leaving and zone == self.d["zone"]:
                self.step("N", "Back outside", note="Out of %s, in %s" % (self.d["title"], ARTICLE.get(zone, zone)))
            elif zone in self.travel:
                action, where, note = self.travel[zone]
                self.step(action, where, note=note, zone=zone, extra=self.trip_tags(steps))
            else:
                self.step("R", zone, note="Travel to %s" % ARTICLE.get(zone, zone), zone=zone,
                          extra=self.trip_tags(steps))
            for action, q, w in steps:
                v = self.q[q]
                if action == "C":
                    self.step("C", v["title"], q, v["task"] + self.where(q, zone), zone)
                elif w.item:
                    self.step("A", v["title"], q, "%s: right-click it to start the quest" % w.name, zone, use=w.item)
                else:
                    self.step(action, v["title"], q, "%s %s" % (w.name, fmt(w.point)) if w.point else w.name, zone)

        for run in range(1, RUNS + 1):
            before = len(done)
            going = [(z, in_town(z, False)) for z in self.towns]
            there = inside()
            if run > 1 and not there:
                # Nothing more inside: the last of the hand-ins -- unless
                # they lead back in again.
                for zone, steps in going:
                    write_town(zone, steps, False)
                for zone in self.back:
                    write_town(zone, in_town(zone, True), False)
                if any(self.work(q) == "in" and q not in did for q in log):
                    continue
                break
            if run > 1:
                self.gap()
                self.step("N", "%s again" % self.d["title"],
                          note="What you have handed in leads back to %s" % self.d["title"])
            for zone, steps in going:
                write_town(zone, steps, False)
            self.gap()
            enter = self.d[self.side].get("enter") or self.d["enter"]
            self.step("R", self.d["name"], note="%s %s" % (enter, fmt(self.d["entrance"])),
                      zone=self.d["zone"])
            # The bosses in the order you meet them -- all of them the first
            # time in, and after that those a quest sends you back for -- each
            # with the quest objectives that are about it, and their hand-ins
            # where those are inside, straight after.
            after = {}
            tied = {q: self.boss_for(q) for a, q, _ in there if a == "C"}
            tied = {q: i for q, i in tied.items() if i is not None}
            rest = []
            for s in there:
                if s[1] in tied and s[0] in ("C", "T"):
                    after.setdefault(tied[s[1]], []).append(s)
                else:
                    rest.append(s)
            self.inside_steps(rest)
            for i, b in enumerate(self.bosses):
                if run == 1 or i in after:
                    self.boss_step(b)
                    self.inside_steps(after.get(i, []))
            for zone in self.back:
                write_town(zone, in_town(zone, True), True)
            if len(done) == before:
                break
        self.unfinished = [q for q in self.take if q not in done and q not in self.optional]
        return self.lines

    def inside_steps(self, steps):
        """Write steps inside the dungeon."""
        for action, q, w in steps:
            v = self.q[q]
            if action == "C":
                # The points outside are in the entrance's zone: say so, or
                # the step's zone is the guide's -- the dungeon, which is not
                # a map the arrow can point on.
                outside = " ".join(fmt(p) for p in v["obj"].get(self.d["zone"], []))
                self.step("C", v["title"], q, v["task"] + (", outside too %s" % outside if outside else ""),
                          self.d["zone"] if outside else None)
            elif w.item:
                self.step("A", v["title"], q, "%s: right-click it to start the quest" % w.name, use=w.item)
            else:
                self.step(action, v["title"], q, w.name)

    def report(self):
        out = []
        for q in self.left_out:
            v, g, t = self.q[q], self.giver(q), self.taker(q)
            out.append("left out %d %s: from %s, to %s, work %s" % (
                q, v["title"], g and (g.zone or "?"), t and (t.zone or "?"), self.work(q)))
        for q in self.unfinished:
            out.append("unfinished %d %s" % (q, self.q[q]["title"]))
        for q in sorted(self.take):
            v = self.q[q]
            if not self.work(q) and re.search(r"\d|^(Collect|Kill|Slay|Bring|Gather|Get|Recover|Retrieve|Find)\b", v["text"]):
                out.append("talk only? %d %s: %s" % (q, v["title"], v["text"][:90]))
        return out


def lua_guide(code, side, lines):
    d = DUNGEONS[code]
    name = "Dungeons/%s (%d-%d)" % (d["title"], d["levels"][0], d["levels"][1])
    return "\n".join([
        "-- Dungeon guide: %s, %s" % (d["title"], side),
        "-- Written by Tools/build/build_dungeon_guides.py from pfQuest and InstanceJournal: do not edit it here.",
        "",
        'AegisPathfinder:RegisterGuide("%s", nil, "%s", function()' % (name, side),
        "",
        "return [[",
        "",
        "N %s |N|Every quest for %s: picked up, then the way in, what each asks for inside, and the hand-ins after|"
        % (d["title"], d["title"]),
        "",
    ] + lines + ["", "N Done |N|That is every quest for %s|" % d["title"], "", "]]", "end)", ""])


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--pfquest", help="shagu/pfQuest")
    ap.add_argument("--pfquest-turtle", help="a pfQuest-turtle checkout")
    ap.add_argument("--instancejournal", help="an InstanceJournal checkout")
    ap.add_argument("--check", action="store_true", help="fail if the guides are not what it would write")
    ap.add_argument("--dump", metavar="CODE", help="print one dungeon's guides and what they leave out")
    args = ap.parse_args()
    if args.pfquest or args.pfquest_turtle or args.instancejournal:
        if not (args.pfquest and args.pfquest_turtle and args.instancejournal):
            sys.exit("--pfquest, --pfquest-turtle and --instancejournal go together")
        model = collect(args.pfquest, args.pfquest_turtle, args.instancejournal)
        with open(CACHE, "w", encoding="utf-8") as fh:
            json.dump(model, fh, indent=0, sort_keys=True, ensure_ascii=False)
            fh.write("\n")
    model = json.load(open(CACHE, encoding="utf-8"))
    # The bosses, from build_dungeon_bosses.py; the notes on them are in
    # dungeon_tactics.py.
    model["bosses"] = json.load(open(BOSSES, encoding="utf-8"))
    files = {}
    for code in DUNGEONS:
        for side, mask in SIDES:
            if side not in DUNGEONS[code]:
                continue
            g = Guide(model, code, side, mask)
            lines = g.build()
            if args.dump == code:
                print("==== %s, %s" % (code, side))
                print("\n".join(lines))
                for r in g.report():
                    print("  !", r)
            files[os.path.join(OUT, side, "%s.lua" % code)] = lua_guide(code, side, lines)
    if args.dump:
        return
    # A Guides.xml per side, as the Optimized guides have, each listing its
    # own folder's files.
    for side, _ in SIDES:
        xml = ['<Ui xmlns="http://www.blizzard.com/wow/ui/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
               'xsi:schemaLocation="http://www.blizzard.com/wow/ui/\n..\\FrameXML\\UI.xsd">',
               "\t<!-- %s dungeon guides: written by Tools/build/build_dungeon_guides.py -->" % side]
        for path in sorted(files):
            if os.path.dirname(path) == os.path.join(OUT, side):
                xml.append('\t<Script file="%s"/>' % os.path.basename(path))
        files[os.path.join(OUT, side, "Guides.xml")] = "\n".join(xml + ["</Ui>", ""])
    stale = []
    for path, text in sorted(files.items()):
        old = open(path, encoding="utf-8").read() if os.path.exists(path) else None
        if old == text:
            continue
        if args.check:
            stale.append(os.path.relpath(path, ROOT))
        else:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(text)
            print("wrote %s" % os.path.relpath(path, ROOT))
    if stale:
        sys.exit("out of date: %s -- run python3 Tools/build/build_dungeon_guides.py" % ", ".join(stale))


if __name__ == "__main__":
    main()
