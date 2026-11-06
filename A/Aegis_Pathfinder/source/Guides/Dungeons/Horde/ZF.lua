-- Dungeon guide: Zul'Farrak, Horde
-- Written by Tools/build/build_dungeon_guides.py from pfQuest and InstanceJournal: do not edit it here.

AegisPathfinder:RegisterGuide("Dungeons/Zul'Farrak (44-54)", nil, "Horde", function()

return [[

N Zul'Farrak |N|Every quest for Zul'Farrak: picked up, then the way in, what each asks for inside, and the hand-ins after|

R Durotar |N|Travel to Durotar| |Z|Durotar|
A Tabetha's Task |QID|2861| |N|Deino (42.7, 9.6)| |Z|Durotar|

R Dustwallow Marsh |N|Travel to Dustwallow Marsh| |Z|Dustwallow Marsh|
T Tabetha's Task |QID|2861| |N|Tabetha (46, 57.1)| |Z|Dustwallow Marsh|
A Tiara of the Deep |QID|2846| |N|Tabetha (46, 57.1)| |Z|Dustwallow Marsh|

F Freewind Post |N|Fly to Freewind Post in Thousand Needles| |Z|Thousand Needles| |O| |PRE|40526|
A End Ukorz Sandscalp |QID|40527| |N|Champion Taza'go (85.7, 91)| |Z|Thousand Needles| |O| |PRE|40526|

F Gadgetzan |N|Fly to Gadgetzan in Tanaris| |Z|Tanaris|
A Screecher Spirits |QID|3520| |N|Yeh'kinya (67, 22.4)| |Z|Tanaris|
A Divino-matic Rod |QID|2768| |N|Chief Engineer Bilgewhizzle (52.5, 28.5)| |Z|Tanaris|
A Troll Temper |QID|3042| |N|Trenton Lighthammer (51.4, 28.7)| |Z|Tanaris|
A Scarab Shells |QID|2865| |N|Tran'rek (51.6, 26.8)| |Z|Tanaris| |O| |PRE|2864|
A The Farraki Ancient |QID|41811| |N|Zalsu the Wanderer (38.9, 34.4)| |Z|Tanaris|
A Drifting Across the Sand |QID|40519| |N|Hansu Go'sha (40.6, 72.5)| |Z|Tanaris|

F Camp Mojache |N|Fly to Camp Mojache in Feralas| |Z|Feralas|
C Screecher Spirits |QID|3520| |N|Kill Vale Screechers and Rogue Vale Screechers, and use Yeh'kinya's Bramble on their bodies for 3 Screecher Spirits (48.5, 49.6) (44.7, 37.6) (58.1, 49)| |Z|Feralas|

F Gadgetzan |N|Fly to Gadgetzan in Tanaris| |Z|Tanaris|
T Screecher Spirits |QID|3520| |N|Yeh'kinya (67, 22.4)| |Z|Tanaris|
A The Prophecy of Mosh'aru |QID|3527| |N|Yeh'kinya (67, 22.4)| |Z|Tanaris|

R Zul'Farrak |N|In the north-west of Tanaris, through the desert gate (39.2, 20.1)| |Z|Tanaris|
C Scarab Shells |QID|2865| |N|Get 5 Uncracked Scarab Shells| |O|
C Troll Temper |QID|3042| |N|Get 20 Vials of Troll Temper|
C Tiara of the Deep |QID|2846| |N|Get the Tiara of the Deep|
C Drifting Across the Sand |QID|40519| |N|Venture into Zul'Farrak and find the Ancient Troll Remains|
C Divino-matic Rod |QID|2768| |N|Get the Divino-matic Rod|
C The Prophecy of Mosh'aru |QID|3527| |N|Get the First and Second Mosh'aru Tablets|
C End Ukorz Sandscalp |QID|40527| |N|Slay Ukorz Sandscalp and Ruuzlu within Zul'Farrak| |O|
K Zerillis |N|Rare: not always here. Net roots a player, and Frost Shot slows.| |HEAL|Dispel Frost Shot's slow (Magic: Priest, Paladin).| |BOSS|Zerillis| |O|
K Theka the Martyr |N|Fevered Plague is a disease; at 30% he turns into a beetle that physical damage can't hurt.| |HEAL|Cure Fevered Plague (Disease: Priest, Shaman, Paladin).| |DPS|From 30% only spells hurt him: casters finish him.| |BOSS|Theka the Martyr|
K Antu'sul |N|He drops Healing Wards and Earthgrab Totems, calls basilisks at 75% and 25%, and heals himself at 20%.| |TANK|Pick up the basilisks.| |DPS|Kill each Healing Ward at once; interrupt his heal.| |BOSS|Antu'sul|
K Witch Doctor Zum'rah |N|He raises zombies from the graves, drops a Ward of Zum'rah, heals his allies, and casts Shadow Bolt Volley.| |TANK|Gather the zombies.| |HEAL|Shadow Bolt Volley hits everyone.| |DPS|Kill the ward; interrupt Healing Wave and Shadow Bolt Volley.| |BOSS|Witch Doctor Zum'rah|
K Shadowpriest Sezz'ziz |N|He heals and renews his allies, casts Shadow Bolt, and Psychic Scream fears everyone near him.| |HEAL|Fear Ward or Tremor Totem help.| |DPS|Interrupt his Heal; dispel or Purge his Renew.| |BOSS|Shadowpriest Sezz'ziz|
K Chief Ukorz Sandscalp |N|Wide Slash hits in front, he frenzies at 60%, calls Sandfury Slaves at 30%, and now and then drops his threat.| |TANK|Taunt him back when he drops threat; face him away.| |DPS|Kill the slaves.| |BOSS|Chief Ukorz Sandscalp|
K Gahz'rilla |N|Summoned with the Mallet of Zul'Farrak at his pool. Gahz'rilla Slam knocks back everyone near, Freeze Solid freezes a player, and Icicle hits.| |TANK|Keep your back to a wall.| |HEAL|Dispel Freeze Solid (Magic: Priest, Paladin).| |BOSS|Gahz'rilla|
K Zel'jeb the Ancient |N|Pathfinder has no notes on this fight yet.| |BOSS|Zel'jeb the Ancient|
C The Farraki Ancient |QID|41811| |N|Venture in Zul'Farrak, and slay Zel'jeb the Ancient|
K Farraki Arena |N|Pathfinder has no notes on this fight yet.|

N Back outside |N|Out of Zul'Farrak, in Tanaris|
T Scarab Shells |QID|2865| |N|Tran'rek (51.6, 26.8)| |Z|Tanaris| |O|
T Troll Temper |QID|3042| |N|Trenton Lighthammer (51.4, 28.7)| |Z|Tanaris|
T Divino-matic Rod |QID|2768| |N|Chief Engineer Bilgewhizzle (52.5, 28.5)| |Z|Tanaris|
T The Farraki Ancient |QID|41811| |N|Zalsu the Wanderer (38.9, 34.4)| |Z|Tanaris|
T The Prophecy of Mosh'aru |QID|3527| |N|Yeh'kinya (67, 22.4)| |Z|Tanaris|
T Drifting Across the Sand |QID|40519| |N|Hansu Go'sha (40.6, 72.5)| |Z|Tanaris|

F Freewind Post |N|Fly to Freewind Post in Thousand Needles| |Z|Thousand Needles| |O| |PRE|40526|
T End Ukorz Sandscalp |QID|40527| |N|Champion Taza'go (85.7, 91)| |Z|Thousand Needles| |O|

R Dustwallow Marsh |N|Travel to Dustwallow Marsh| |Z|Dustwallow Marsh|
T Tiara of the Deep |QID|2846| |N|Tabetha (46, 57.1)| |Z|Dustwallow Marsh|

R Durotar |N|Travel to Durotar| |Z|Durotar| |O| |PRE|2935|
A The Spider God |QID|2936| |N|Master Gadrin (55.9, 74.7)| |Z|Durotar| |O| |PRE|2935|

N Zul'Farrak again |N|What you have handed in leads back to Zul'Farrak|

R Zul'Farrak |N|In the north-west of Tanaris, through the desert gate (39.2, 20.1)| |Z|Tanaris|
T The Spider God |QID|2936| |N|Tablet of Theka| |O|

N Done |N|That is every quest for Zul'Farrak|

]]
end)
