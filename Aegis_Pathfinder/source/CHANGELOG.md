# Changelog

All notable changes to **Aegis: Pathfinder**.

Format loosely follows [Keep a Changelog](https://keepachangelog.com/).
The version here matches `## Version` in `Aegis_Pathfinder.toc` and the number
in the load message and the options window's About page — quote it in bug
reports.

> ⚠️ Releases marked **restart** add or remove a `.lua` file or a texture. WoW
> 1.12 reads the file list at startup, so `/reload` won't pick them up — you
> need to fully restart the client. Everything else is `/reload`-safe.

> **One push, one MINOR.** A body of work that lands in one merge takes a
> single MINOR bump, and every change inside it — each phase, each fix found
> along the way — is a PATCH under it. The MINOR moves again at the next body
> of work, not at the next feature within this one.

---

## [0.26.0] — restart

### Fixed
- **Icepoint Rock is offered at the level its quests are for.** The guide
  was called Icepoint Rock (40-50), so **Where next?** offered it from
  level 39, a level before the Northeast Passage will take you, and at 40
  sent you there for Ice Crawlers of 41-43, Icepoint Whiteclaws of 44-46
  and a level 48 elite. Its five quests are level 45 to 48. It is now
  **Icepoint Rock (44-47)** and is first offered at 43. Your place in it,
  its tab, its star and its spot in the recent list carry over to the new
  name.
- **The guide gets you onto the boat.** Inunquaq only offers The Northeast
  Passage once you have done his **Crawling for Meat**, which no guide sent
  you to, so a character that had not done it at 17 found no boat at all.
  The guide now starts with it: 8 Crawler Meat from the Raging Reef
  Crawlers on the beach beside him. A character that has already done it
  skips the three steps.
- The guide's opening note says what the trip is: the level 40 boat, five
  quests, and the one that needs a group.

## [0.25.0]

### Fixed
- **Goblins no longer jump ahead through their guides.** With pfQuest on,
  the guide reads which races a quest is for, and ticks a quest done when
  it is not for yours. Goblin and High Elf had swapped bits, so a Goblin
  read every Horde quest as not for its race: step 1 jumped to step 100,
  and The Barrens (12-15) skipped straight to the Crossroads. The race bits
  are now pfQuest's own. Undead and High Elves had never been checked at
  all, because the client calls them Scourge and BloodElf.
- **Goblins are sent for Conscript of the Horde.** The Barrens (12-15)
  showed the Razor Hill and Far Watch steps only to Orcs, Trolls and Undead,
  though Goblins land in Durotar and can take the quest.
- **The guide no longer covers the quest log.** It sat above Blizzard's
  windows whatever you clicked. It now shares their layer: clicking the
  quest log, your bags or the character panel brings them in front, and
  clicking the guide brings it back. The options window and guide browser
  still open over the guide.
- **Delete cheapest item weighs greys by what they fetch.** A grey whose
  price was unknown counted as worth nothing, so a stack of five fangs went
  before a single grey chestpiece that sold for less. The price now comes
  from the server through ClassicAPI, Turtle WoW's own items included, and
  a grey of unknown price is offered only when no grey with a price is
  there.
- **Messenger to Darkshire is no longer in Westfall (12-17).** It needs
  level 18, so the guide sent you to Lakeshire for a quest you could not
  take yet.

## [0.24.0]

### Fixed
- **No more boat from Menethil Harbor to Auberdine.** Turtle WoW has none:
  Auberdine's boat sails to Stormwind Harbor (and to Rut'theran Village and
  Alah'Thalas), and Menethil's to Theramore. The Alliance guides still sent
  you to the Menethil dock: "Travel to Auberdine by boat from Menethil Harbor"
  in Optimized Darkshore (12-14), and about 30 legs like it across the
  Optimized, RestedXP and RestedXP Hardcore packs and the zone guides. Each
  now uses the boats that sail:
  - **To Darkshore:** the boat from Stormwind Harbor. From Ironforge, the
    Deeprun Tram to Stormwind first.
  - **From Darkshore:** the boat to Stormwind Harbor. On to Loch Modan by the
    tram and Ironforge, or on to the Wetlands by flying to Menethil Harbor,
    or to Thelsamar and north through Dun Algaz if you don't have that flight
    path yet.
  - RestedXP no longer has Humans skip over the mountains from Dun Morogh
    into the Wetlands, or send Night Elves round through the Wetlands and
    Loch Modan, only to catch that boat. The cooking and First Aid notes for
    the wait now come at Stormwind Harbor.
  - The Westfall (12-17) zone guide now ends in Loch Modan, where its next
    guide starts, instead of sailing to Auberdine.
  - The Theramore–Menethil boat still sails, and the steps that use it are
    unchanged.
- `Tools/verify.py` fails any guide step that sails between Menethil Harbor
  and Auberdine.

## [0.23.4]

### Changed
- **New stat weights for the item score.** Players reported odd weights, a
  leveling Affliction warlock's Stamina far too low among them. OctoPawn's
  defaults are replaced by weights worked out from the game's own formulas
  for every class and spec, then moved most of the way toward Pawn's Classic
  Era scales (HawsJon's):
  - **Two sets, leveling and 60.** Below 60, Stamina, Spirit and regen count
    for more, because they keep you going between pulls. At 60, crit and hit
    count for more. The scores change over the moment you reach 60.
  - **Tanks use the tank set from the start.** Protection warriors and
    paladins, bears and the shaman tank weigh Stamina, Defense and avoidance
    at every level.
  - **A ranged weapon's DPS is its own stat.** A bow's, gun's, crossbow's,
    wand's or thrown weapon's DPS is now *Ranged Weapon DPS*. A hunter's bow
    counts for far more than its melee weapon, and a leveling caster's wand
    counts for something.
  - Turtle WoW's own stats (Fortune, Avoidance, Lifesteal and the like) keep
    OctoPawn's weight, rescaled.
- **Your own changes start again.** Changes made to the old weights are
  cleared once, and a line in chat says so. You can still change weights on
  the Item Score page. Changes are now kept apart for the leveling and 60
  sets, and **Reset weights** puts the set you are on back to the defaults.
  The page says which set it shows.
- **Exported weights carry every stat.** The defaults now differ from
  OctoPawn's, so a scale pasted into OctoPawn or another character still
  arrives whole.

## [0.23.3]

### Fixed
- **The item score reads tooltips right.** Four reading mistakes made some
  items score far off, whatever the weights:
  - **Mana and health per 5 always read as 5.** "Restores 12 mana per 5 sec."
    scored as 5, and so did "Restores 2 …": the number was taken from the
    "5" in the stat's own name. It is the line's number now.
  - **Spell crit counted as melee crit as well.** A Retribution Paladin rated
    a caster's spell crit ring above a melee crit one, and a warrior got crit
    points from it. Ranged crit no longer counts as melee crit either.
  - **Mana per 5 also counted as a mana pool**, "+5 mana" on top of the regen.
  - **"Damage and healing" counted only as spell power.** A Holy Priest scored
    "+22 damage and healing" at 12 and "+44 healing" at 64, though the first
    heals for all 22. It now counts as healing as well; a healer's spell
    power weight is for its damage side.

## [0.23.2]

### Fixed
- **Class quests start where you are at level 10.** A Human warrior's Defensive
  Stance guide sent you to Stormwind to take A Warrior's Training from Ilsa
  Corbin. The same quest is given in Goldshire by Lyria Du Lac, where a
  level-10 Human is, and that is where it starts now; you go on to Stormwind
  for Harry Burlguard as before. Below level 20, a class quest given both in
  your starting zone and in the city is picked up in the starting zone.
  Checked across every class and race; three more change:
  - a Horde warrior's Veteran Uzzek, from Tarshaw Jaggedscar in Razor Hill
    rather than Sorek in Orgrimmar;
  - an Undead hunter's The Hunter's Path, from Dark Ranger Lanissa in Tirisfal
    Glades rather than Noel Bearfinger in the Undercity;
  - a Gnome hunter's The Hunter's Path, from Thorgas Grimson in Dun Morogh
    rather than Olmin Burningbeard in Ironforge.

## [0.23.1]

### Fixed
- **The cheapest crafting route no longer asks for 92 Hunting Spears.** With
  selling leftovers to a merchant on (the default), what a merchant pays for a
  craft came off its cost. A Hunting Spear is listed as selling for 4g 5s, more
  than its Bronze Bars cost, so every spear cost nothing to the planner, which
  kept crafting them long after they went green: 92 for 40 points, and 92 Iron
  Lanterns for 160–200. The leftovers were then counted as about 300 gold back.
  - A craft now costs what its reagents cost. What a merchant pays never
    chooses the route, so a recipe going green gives way to one still orange
    or yellow when that is cheaper per point.
  - The total is what the route costs. What a merchant would pay for the
    leftovers is said beside it, "leftovers sell for about …", and is no longer
    taken off. The switch now reads *Say what a merchant pays for what is left
    over*; off, that line goes, and the route stays the same.

## [0.23.0]

### Fixed
- **Quest icons no longer mark mobs with no guide open.** Mousing over or
  targeting anyone a quest in your log wanted put a raid marker on them even
  with the guide closed, or no guide loaded at all. They now mark only while a
  guide is open. Hidden in combat or a dungeon by the Appearance page, the
  guide still counts as open. The target buttons and macros mark as before,
  since you press them.

## [0.22.24]

### Changed
- **Sword and Board is called Protection.** A Warrior's or Paladin's shield
  build reads "Warrior Protection leveling" in the menu, and "Protection
  leveling, then Fury at 60" before your spec at 60 (Bear likewise: "Bear
  leveling, then …"). A character following Sword and Board follows
  Protection without a click. Its Modern Spellbook plans are "Pathfinder:
  Protection leveling to 30"; a spec's, "Pathfinder: Fury to 30" or
  "Pathfinder: Fury at 60".

### Fixed
- **The talent strips, tidied** after the first look in game:
  - the card's line is shorter, so it isn't cut off: "Rank 1 of 3 in
    Protection · at level 21";
  - on Modern Spellbook's window the menu is wider and the card fills the room
    up to the buttons, so neither is cut short, and every piece hangs from the
    strip's top at set places;
  - NEXT sits clear of the badge on the talent's top right, on both windows.
- **The guide browser's star no longer covers what a row says on the right**
  ("Dungeon", "Raid", a percentage): while the star and arrow show, the words
  move left of them.

## [0.22.23] — restart

### Added
- **The Talent Advisor on Modern Spellbook's talent window.** With
  [Modern Spellbook](https://github.com/lioryx/ModernSpellBook) (by lioryx)
  and its talents on (`/msb talents`), its window is marked as Blizzard's is:
  - every tree at once: the badges, the gold ring and NEXT on the next point,
    and NEXT POINT HERE by its tree's name, in the expanded view too;
  - a strip over the window: the build to follow, the card for the next
    point, and *Plan to my level*, *Whole build as a plan* and *Share*;
  - the marks step aside while it shows a plan.
- **Plans in Modern Spellbook.** *Plan to my level* (21 points at 30) and
  *Whole build as a plan* (51) save the build in its plan list, as
  "Pathfinder: Sword and Board to 30" or "Pathfinder: Sword and Board", and
  make it the plan its window shows. Its *Apply* learns the points; Pathfinder
  never spends one. A plan is the ranks you have, then the build's next
  points, so points already off the build don't stop it applying.
- **Share and plan.** The build as Modern Spellbook's share string
  (`MSB1-WARRIOR-…`), selected to copy, for its *Import* or a friend; and
  *Follow a shared build*: paste such a string and the advisor follows it, the
  tree with the most points first, a row at a time, as **Shared build** in the
  menu. Turtle WoW has prerequisites in the same row (Holy's Divine Favor
  needs Holy Shock), so those are taken first within the row. Every build of
  every class goes into a string and back, and fits Turtle's trees that way.
- **A card when you level up** with a point: "Level 30: a talent point. Take
  Shield Slam (rank 1 of 1) in Protection.", with *Open talents* and *Later*;
  and the talents button lit gold with the points to spend on it. Both on the
  Extras page's new *Point out a talent point* (on).

### Changed
- **Louder marks on Blizzard's talent window**, as in the mock-up: the next
  point's ring and NEXT in gold; a card under the menu with the talent's icon,
  "Take Deep Wounds" and "Rank 3 of 3, in Arms · 1 point to spend"; badges
  green while points are to take and a tick once taken; the next tree's tab
  lit gold.

## [0.22.22]

### Fixed
- **Teldrassil's "Gnarlpine Hold" (step 87) ticks once you take The Glowing
  Fruit.** The step carries the fruit's quest, so it is done once that quest
  is in your log. But a change to the quest log only made the guide look again
  on accept and objective steps, so after taking the fruit the step stayed
  until something else made the guide look.
  - A change to the quest log now rechecks any travel step.
  - The quest automation looks past any travel step, not only an optional
    one, to the next step's NPC or object: clicking the Strange Fruited Plant
    takes The Glowing Fruit with Gnarlpine Hold still showing.

## [0.22.21]

### Fixed
- **The guide follows your quests after you change zone.** RestedXP's 13-15
  Westfall opens on "Travel to Elwynn Forest", its way out of Elwynn. It only
  ticked within yards of one spot near the Westfall border, so a player who
  flew from Stormwind into Westfall had the guide stay on it while the
  Westfall quests went by. In RestedXP such steps never hold the guide up,
  and here they no longer do:
  - A travel step is done on reaching the zone or subzone its title names,
    with "Travel to", "Travel towards", "Run to" and the like dropped.
    "Travel to Westfall" ticks anywhere in Westfall, not only at its point.
  - An optional travel step (RestedXP's `#sticky` and `#completewith`) is
    passed once you are in the next step's zone, or once the next step is
    done. The 1,885 travel and hearth steps marked so in the two RestedXP
    packs no longer wait at their spot.
  - Talking to the next step's NPC on such a step picks and accepts the quest
    as usual.
- **Quests under a collapsed header.** The quest log's functions only see the
  rows in sight, so a guide quest under a collapsed header looked never
  accepted: its hand-in was skipped and its progress stood still. The game
  keeps which headers are collapsed by their place in the list, so one
  collapsed in Elwynn can land on Westfall's. When one of the guide's quests is
  hidden like this, the headers open (as RestedXP does), and chat says why
  once. A hand-in for a quest on your quest list is never skipped as missing.

## [0.22.20] — restart

### Added
- **Attunement guides.** The quests that open each raid and dungeon, one
  guide each, per side, in a new **Attunements and keys** folder under the
  guide browser's Dungeons, with an orange AT badge:
  - **Raids:** Molten Core, Onyxia's Lair (Drakefire Amulet for the
    Alliance, Blood of the Black Dragon Champion for the Horde), Blackwing
    Lair, Naxxramas, and Turtle WoW's Emerald Sanctum (Into the Dream I–VI),
    Lower Karazhan Halls (The Key to Karazhan I–X) and Tower of Karazhan
    (the Scepter of Medivh).
  - **Dungeons:** Upper Blackrock Spire's Seal of Ascension, Scholomance's
    Skeleton Key, Blackrock Depths' Shadowforge Key, and Turtle WoW's
    Karazhan Crypts (The Mystery of Karazhan for the Alliance, The Depths of
    Karazhan for the Horde).
  - Each says Raid or Dungeon in the folder, and **Attuned** once you've
    handed in its last quest. Home suggests one you've started, and the
    first you can start.
  - Built from pfQuest, pfQuest-turtle and CMaNGOS the way the class quest
    guides are (`Tools/build/build_attunement_guides.py`): each side gets
    its own parts where the chains differ, such as Karazhan's parts III–V.

## [0.22.19]

### Added
- **Sword and Board and Bear leveling builds.** A Warrior or Paladin can
  level with a shield, and a Druid as a bear. The Talent Advisor's *Build to
  follow* (on the Extras page and the strip over the talent window) lists
  each on its own ("Warrior Sword and Board leveling") or then your spec at 60
  ("Sword and Board, then Protection at 60"). All three are checked point by
  point against Turtle WoW's trees.
  - **Warrior:** Shield Specialization, Toughness and Improved Revenge first,
    Last Stand at 25, Shield Slam at 30, Concussion Blow at 40, then Arms'
    Tactical Mastery and Deep Wounds (16/0/35).
  - **Paladin:** Redoubt and Precision first, Shield Specialization, Holy
    Shield at 30 with Reckoning, Righteous Strikes, Bulwark of the Righteous
    at 41, then Holy's Divine Strength and Divine Intellect (10/41/0).
  - **Druid:** Ferocity, Thick Hide and Feral Instinct first, Feral Charge at
    28, Heart of the Wild by 39, Leader of the Pack at 40, then Balance's
    Omen of Clarity at 60 (11/40/0).

## [0.22.18]

### Fixed
- **"Leveling" has one L wherever you see it.** The Talent Advisor's menu
  and strip ("Leveling, then Protection at 60"), its tooltip line ("Warrior
  leveling puts 3 points here"), the Item Score page, the guide browser's
  "Hide finished and outleveled guides" and the out-leveled chat line said
  "levelling". Saved settings are unchanged.
- **First Aid's route.** It asked for 29 Linen Bandages for 1–45 and 5 Heavy
  Linen Bandages for 45–100, fewer than the skill points, and sent you to
  train Journeyman at 45, five points before you can. It now follows the
  usual route: Linen to 40, Heavy Linen to 80 with Journeyman at 50, Wool to
  115 and on as before. Every count is worked out from the bandage's skill
  colours, the same way as the other crafting guides.
- **"Grind to level N" waits for the level.** 43 RestedXP grind steps
  ("Grind to level 10", "Grind to 6", "Make sure you are level 38") were
  passed over at once. They now hold the guide until you get there and tick
  themselves, as level notes do. One marked optional still doesn't hold you
  up. Grinding to an amount of XP is left as it was.
- **Onyxia Attunement isn't under Levels 1–20 any more.** RestedXP's Onyxia
  Attunement and Scholomance Key have no level range, so the guide browser
  filed Onyxia Attunement at the bottom of RestedXP's Levels 1–20. They're
  now under Dungeons, in a folder of their own, **Attunements and keys**.

## [0.22.17]

### Changed
- **Hints open beside the guide, not over it.** Hovering the step arrows, a
  tab, a step or any other part of the guide used to put the hint over the
  steps. Now it opens beside the guide: on its right when the guide is on the
  left of the screen, on its left when it is on the right, level with what
  you hover. With no room beside it, the hint goes under the guide in the top
  half of the screen and over it in the bottom half.

## [0.22.16]

### Changed
- **The crafting guides follow CraftRoute's routes.** Alchemy,
  Blacksmithing, Cooking, Enchanting, Engineering, Jewelcrafting,
  Leatherworking, Survival and Tailoring now take the cheapest way to 300 as
  [CraftRoute](https://github.com/Kitymeowmeow-turt/CraftRoute)'s own
  planner works it out, from the auction prices in its sample scan (30 July
  2026). The old routes asked for fewer crafts than skill points in 63
  places (Jewelcrafting's 10 Malachite Rings for 50–70 among them). Now each
  count is the average number of attempts it takes, rounded up, and when a
  later recipe uses what a step makes, the step says "Keep them for" that
  recipe. Where nobody was selling something in that scan (the fish in
  Cooking, some ore, Survival's wood), it was costed at three times what a
  merchant pays, and the guide's first step names it. Trainers, ranks,
  tomes and the Artisan quests are as before; First Aid and Mining keep
  their routes.

### Fixed
- Cooking's Artisan hand-in no longer says "Tanaris, Gadgetzan." twice.

## [0.22.15]

### Changed
- **The action buttons snap together.** Let go of Active Items, Active
  Targets or Macros near another of them, or near the guide, and it snaps
  flush against it, side by side or one under the other, lined up.
- **The action buttons close with the guide.** Close the guide (its ✕, the
  minimap button, `/apg`) and they go too; open it and they come back. When
  the guide hides itself in combat or a dungeon, the Appearance page's
  switches still decide.

## [0.22.14]

### Fixed
- **Dungeon guides send you to a town only if its quests are for you.**
  Shadowfang Keep sent every Alliance player to Darnassus first and then to
  Stormwind, for one quest only Priests, Mages, Warlocks and Druids can
  take, and only once they have done the quest before it. That trip now
  carries the quest's classes and waits on that quest. Thirteen other
  dungeon guides had trips like it.
- **Shadowfang Keep starts in Stormwind**, where the Alliance's 22-30s are.

## [0.22.13]

### Fixed
- **"AceConsole-2.0.lua:151: invalid option in `format'".** A chat line with a
  percent sign in it -- "Gloves: a +12% upgrade" -- went through
  string.format and stopped with that error. Lines are printed as written
  now.
- **Level notes tick themselves.** Teldrassil (1-12)'s "Level 10 Required"
  waited for a click after you reached 10. It, and the 145 other level notes
  in the zone and Optimized guides ("Level 31: you should be around level 31
  now"), tick when you reach the level, and show the auto-tick mark. Below
  the level you can still tick them yourself.
- **Reaching a level no longer ticks a quest step that needs it.** Optimized
  Teldrassil's "Turn in Taming the Beast (Part 1)" needs level 10; on it as
  you reached 10, it was ticked without the quest being handed in. A level
  up now ticks only grind steps and level notes.

## [0.22.12] — restart

### Added
- **The Talent Advisor**, on Blizzard's own talent window (and pfUI's skin of
  it), as the mock-up showed:
  - each talent shows a badge with the points the build puts there: green
    while some are still to take, quiet once you have them all, amber "+N"
    for points the build doesn't put there;
  - the talent your next point goes to glows, with NEXT over it, and its
    tree's tab has a dot; the window opens on that tree;
  - a strip above the window: *Following* and the build, as a menu to pick
    another; where the next point goes ("Next: Deep Wounds, rank 3 of 3");
    and how many points are off the build. Off the build, it carries on from
    the closest point; it never says to respec;
  - a talent's tooltip says how many points the build puts there, and "Your
    next point goes here." on the next one.
- **What it follows:** your class's levelling build until 60, then your
  spec's: the one picked on the Item Score page, or the one your talents lean
  to. At 60, with all 51 points on the levelling build, it says once in chat
  that your spec's build is ready for when you respec.
- **On a level up** it names the talent to take: "Level 22: a talent point to
  spend. Take Deep Wounds (rank 3 of 3) in Arms."
- **Extras -> Talent Advisor:** its switch (on), *Build to follow*, *Name the
  talent to take in chat when I level up* (on), and *Open the talent window*.
- Each build is checked against the talent tree your game has before it is
  followed. One that doesn't fit says why, in the strip and once in chat,
  and isn't followed. It never spends a point.

### Changed
- The README's Extras and Dungeons page pictures are drawn again from the
  current code: the Talent Advisor's settings, and the boss notes' role.

## [0.22.11]

### Added
- **Boss steps in the dungeon guides.** Inside, each guide has a step for
  every boss, in order, saying what the fight does -- "At two-thirds and at
  one-third health he stuns everyone with Smite Stomp and goes to his chest
  to change weapons" -- with a line each for the **Tank**, **Healer** and
  **Damage**: where to face him, what to dispel and which classes can, what
  to interrupt or kill first. Hover the step, or see them under it in focus
  mode. A quest that needs a boss dead comes straight after his step.
- **My role in dungeons** (Options -> Dungeons -> Boss notes): All roles to
  start; pick Tank, Healer or Damage to see only your line.
- **A boss's step ticks itself when he dies**, from the combat log. The Seven
  in Blackrock Depths tick on Doom'rel, the last. A rare boss's step says he
  is not always there, and is passed over.
- What the bosses do comes from InstanceJournal and CMaNGOS. Some Turtle WoW
  bosses have no data yet -- Dragonmaw Retreat, Crescent Grove, Stormwrought
  Ruins, Gilneas City, Hateforge Quarry, most of Windhorn Canyon, and those
  Turtle added to older dungeons: their steps say "Pathfinder has no notes on
  this fight yet." and still tick themselves.

## [0.22.10]

### Fixed
- **A class quest guide finishing no longer replaces the guide in your first
  tab.** Handing back, it took your route pack's guide for your level
  whenever that was a different one -- so a paladin on Optimized Redridge
  (18-20) was put on RestedXP Hardcore's Redridge guide when Tome of Valor
  finished. The first tab now keeps its guide unless you have out-levelled
  it, and then goes on to that guide's next one at your level.
- **Picking a guide in the guide browser opens it in a new tab and changes
  nothing else.** Right-click and the pane's **Load** button loaded it over
  the guide you were on; they are gone, and the pane's button is **Open in a
  new tab**. Picking a RestedXP guide no longer switches your route pack
  either: the switch loaded the pack's own guide in place of yours. Choose
  the pack on Options -> Route.

## [0.22.9]

### Added
- **`/apg talents`**, for the Talent Advisor to come: saves your class's
  talent trees as the game has them -- every talent's place, ranks,
  prerequisites and tooltip -- for your account. Turtle WoW has changed some
  trees, and the advisor's builds are checked against these. Once on a
  character of each class (a level-1 one will do); it says which classes
  are in so far.

## [0.22.8]

### Changed
- **Level-up announcements** are worded "Pathfinder: ...": the emote reads
  "<you> Pathfinder: I just leveled up from 22 to 23! (2 hours 1 minute)",
  and party and guild get "Pathfinder: I leveled up from 22 to 23! (2 hours
  1 minute)". The emote is ticked to start with; party and guild are still
  off until ticked.

### Added
- **Talent Advisor (coming soon)** on the Extras page: its switch, dimmed
  and held off, until the advisor arrives.
- The README's options pictures are all of the current pages now, drawn
  from the addon's code, the Extras page among them.

## [0.22.7] — restart

### Added
- **An Extras page**, after Gear and Item Score, as Zygor's has (a new file,
  Extras.lua):
  - **Show Pathfinder chat messages** (on). Off, the routine lines stay out
    of your chat: the load message, the login's progress summary, flights
    taken, what was bought, sold, repaired or deleted, upgrades found and put
    on, a branch or starting zone handed over. Errors, warnings and replies
    to what you click or type still show.
  - **Show detailed reputation gains** (off): after the client's line, where
    the faction stands and how far to the next rank -- "Stormwind +25:
    Honored 4,350 / 12,000, 7,650 to Revered".
  - **Announce level-ups to:** Emote, Party chat and Guild chat, each off
    until ticked. The emote reads "<you> Aegis: Pathfinder: I just leveled up
    from 22 to 23! (2 hours 1 minute)"; party and guild get "I leveled up
    from 22 to 23! (2 hours 1 minute)". The time comes from the guide
    browser's level tracker, and is left out for a level it did not count
    from the start. Nothing goes to a party or guild you are not in.

## [0.22.6] — restart

### Added
- **A Maps page**, after Navigation, as Zygor's has: what the addon draws on
  the world map and the minimap, on the zone's own map.
  - **Reveal the whole map** (on): the places you have not been, a little
    dimmer than the ones you have. It stands down while pfUI's own map reveal
    is on, and for Cartographer or MetaMap's fog of war module.
  - **Show the step on the map** (on): the step's quest givers, hand-ins and
    kill areas, and the creatures that drop what it collects, from pfQuest's
    database; and the place the step's note gives. Each is named when you
    mouse over it. Without pfQuest, only the note's place.
  - **A trail from me to the waypoint** (on), dots or dashes, marching
    toward it on the world map when you and it are on the zone it shows. On
    the minimap too when Astrolabe is loaded (TomTom-TWOW brings it), as far
    as the minimap reaches.
  - **Rare creatures near my level** (off), with **Icon size** and
    **See-through icons**: where the rares and rare elites within four levels
    of yours can spawn -- 293 rares and 147 rare elites, from pfQuest-turtle's
    database (a new file, Rares.lua). Whether one is up, 1.12 can't say.

## [0.22.5]

### Added
- **The Appearance page: more for the guide window.**
  - **Guide window opacity**, under Transparency: how see-through it makes
    the guide, 20% to 100% (half, as before, to start with). The text stays
    solid.
  - **Guide browser opacity**, 40% to 100%.
  - **Step text size**, 80% to 140%: the steps' titles and notes, and the
    rows that hold them.
  - **Show the progress bar**, on as before. Off, the steps move up into its
    place.
  - **Grow upward from where I put it**, for a guide at the bottom of the
    screen: its bottom edge stays where you left it. The header stays on top.
  - **Hide the guide in dungeons and raids**, with **Show it again when I
    leave** under it; **Hide the guide in combat**, with **Hide the action
    buttons in combat too** under it. Hidden so, the guide still counts as
    open.
- **The Step Display page:**
  - **Steps shown in focus mode**, 1 to 5: the step you are on and the ones
    after it.
  - **Skip setting my hearthstone** and **Skip discovering new flight paths**.
  - **Party sync**, on as before. Off, there is no party icon and invitations
    are declined without a popup.

## [0.22.4] — restart

### Added
- **The Action Buttons page does more**, as Zygor's does:
  - **Which way each window grows**: Active Items and Active Targets each
    right (as before), left, up or down. A window you have dragged grows
    from the matching corner, where you left it; until then it hangs under
    the guide.
  - **Button size**, 60% to 150%, for the three small windows, on top of the
    window scale.
  - **Buttons to show**: quest items, talk to NPC, kill enemy, and delete
    cheapest item. One left out goes from its window; the macros, the key
    bindings and the quest icons still have them all.
  - **Delete cheapest item.** With your bags full, a button after the items
    offers the cheapest thing in them: a grey first, then whatever a vendor
    pays least for, by the whole stack. It never offers the guide's items,
    your hearthstone or quest items, and asks before deleting anything that
    is not grey. A quiver's or soul bag's empty slots don't count as room.
    1.12 doesn't tell addons what vendors pay, so the prices come from the
    CMaNGOS database (a new file, SellPrices.lua); Turtle WoW's own items
    aren't in it and are offered only when grey.
  - **Mark whoever the target buttons target**, on as before. Off, the
    buttons only target; quest icons still mark by themselves.

## [0.22.3] — restart

### Added
- **The Automation page does more**, as Zygor's does:
  - **All quests, not only the guide's**, under accepting and turning in
    quests (off to start with). It takes every quest an NPC offers and
    hands in every finished one, but never a grey quest, and it leaves two
    places in your quest log for the guide's.
  - **Pick the guide's quest from an NPC's list**, which it always did, is
    now a setting (on). Off, the list is yours to click; the quest you open
    is still accepted and handed in.
  - **Take the step's flight when I open the flight master's map** (off).
    "Fly to Orgrimmar" flies to the town; "Fly to Westfall" to the zone's
    flight path, but only when you know just one there. With two, it says
    to pick one rather than guess.
  - **Buy what the step says to buy, at its vendor** (on). A buy step that
    names its item buys as many as you still need, no more than the vendor
    has or you can pay for.
  - **A "Sell greys" button** on the vendor window (on), and **Sell greys
    automatically** as the window opens (off). Either says how many went and
    for how much.
  - **Repair automatically**: not at all (to start with), or with your own
    money. 1.12 has no guild bank, so there is no guild repair.
- Hold Shift as you open a quest giver, a flight master or a vendor and none
  of it happens, as Shift already did for quests.

## [0.22.2]

### Changed
- **The options window's pages follow Zygor's**, in the addon's look. After
  Route, Dungeons and Filters come Appearance, Step Display, Automation,
  Action Buttons and Navigation, then Gear and Item Score, Maintenance and
  About. The settings that were on **Behaviour** have moved, each keeping
  what you had it set to, and the Behaviour page is gone:
  - **Appearance**: the minimap button, and the guide window's *Lock window*
    and *Transparency*, which were only in the guide's menu. They are in
    both places now, as one setting.
  - **Step Display**: skip suggested follow-ups, offer custom zones between
    guides, offer class quests at their level; and *Ask before inviting my
    party*, the share popup's "don't ask again" as a setting you can turn
    back on.
  - **Automation**: accept and turn in the guide's quests, track quests.
  - **Action Buttons**: the Active Items, Active Targets and Macros windows,
    and quest icons.
- **The Gear Finder's Upgrade sources are five boxes**: Dungeons, Raids,
  Quest rewards, Reputation vendors and Crafted gear. The last three were
  switches of their own and keep what those were set to. Tick only Dungeons
  and it looks nowhere else.

### Fixed
- The Gear page's note still said the Gear Finder only looked in dungeons
  ticked on the Dungeons page, which stopped being true in 0.22.1.

## [0.22.1]

### Fixed
- **Many Gear Finder slots said *No upgrade found* when there were
  upgrades.** Two causes:
  - It skipped every dungeon unticked on the **Dungeons** page. Those ticks
    say which dungeons' quests the route takes in, and the first-time setup
    unticks most of them for the route, so a character could be left with
    one dungeon to look in. The Gear Finder now looks in every dungeon at
    your level, ticked or not. Its own **Upgrade sources** decide where it
    looks, as Zygor's do.
  - Quest rewards that need no level to wear, which is most of them, were
    taken as level 0. So they all counted as long outgrown and none was
    weighed. They now count at their quest's level.
- **The character panel's ✕ showed over the Gear Finder,** beside the page's
  own. It is hidden while the Gear Finder is open, and back on the other
  pages.
- **The Gear Finder could not be dragged.** Dragging the page now moves the
  character panel, as pfUI lets you drag its other pages.
- **The cog in the Gear Finder's footer did nothing** unless the options
  were already open. It now opens them at the Gear page.
- **Switching to a spec with no dungeon to suggest took the spec dropdown
  with it,** leaving no way back from there. The dropdown stays, with the
  logo where the loading screen goes and the reason under it.

## [0.22.0] — restart

### Added
- **The Gear Finder is a tab on the character panel**, laid out like
  Zygor's, after Character, Reputation, Skills and Honor. It replaces the
  Gear Finder window. `/apg finder` and **Open the Gear Finder** in the
  options open the panel on it.
  - **A cell per slot**, as the character sheet has them: the slot's biggest
    upgrade, how much better it is, where it drops and who drops it, and *at
    level N* if you can't wear it yet. A slot with none says *No upgrade
    found*; one you wear nothing in says *Empty slot*. Rings and trinkets have
    two cells each, never showing the same item.
  - **Click a cell** for every upgrade for that slot, biggest first, with
    drop chances. Pick the one you want and the cell shows it as *Your pick*.
    Picks are kept for the character, and forgotten once you wear the item
    or it stops being an upgrade.
  - **The suggested dungeon**: its loading screen, the dungeon the cells'
    items drop in most (by how many slots it upgrades, then by how much),
    arrows through the others, the spec it scores for, and **Open the guide**
    for its dungeon guide. Picking a different item can change it, at once.
  - Works with pfUI: the tab is skinned like pfUI's tabs and sits in their row.
- **Upgrade sources** on the options' Gear page: **Dungeons** and **Raids**,
  two checkboxes side by side. **Raids** replaces the window's *Include raids*
  switch, and still says the first look takes a minute or two. With both
  unticked, the Gear Finder says it has nowhere to look.

### Changed
- The Gear Finder now keeps every upgrade for a slot, not just the best three,
  so a slot's list has them all.
- A one-hander a dual wielder would put in the off hand is an off-hand
  upgrade, under the slot it would replace.

## [0.21.3]

### Fixed
- **The minimap button was bigger than the others round the minimap.** The
  logo is a solid disc, and at 32 pixels it filled the whole space a stock
  button takes, where theirs is a 30-pixel gold ring round a 20-pixel icon.
  It is now 26 pixels across.
- **The minimap button was reported as not dragging round the minimap.** It
  now switches the mouse and movement on itself, as pfQuest's button does,
  rather than relying on the client's defaults. Drag it with the left
  button; where you leave it is saved.

## [0.21.2]

### Fixed
- **An old ClassicAPI gave a Lua error and an empty guide list.** On a
  ClassicAPI older than v1.5.9, Pathfinder said in chat that it wouldn't
  load, but went on loading the guides at login anyway. Before v1.3.11,
  ClassicAPI doesn't add the `coroutine` library that loading uses, so this
  threw `Core.lua:799: attempt to index global 'coroutine'` and the guide
  browser showed "No guides here." Pathfinder now stops cleanly, and the
  chat message says which ClassicAPI version it found ("none" if it isn't
  installed). To fix it, update
  [ClassicAPI](https://github.com/brues-code/ClassicAPI) to v1.5.9 or newer.

## [0.21.1] — restart

### Added
- **Shadowfang Keep shows its loading screen** in the guide browser, the
  last dungeon guide still on the game's generic one. Every dungeon guide
  now shows the screen Turtle WoW shows on the way in.

### Fixed
- **Picking a guide threw TomTom errors when TomTom hadn't started.**
  TomTom-TWOW stops starting up when the arrow position it saved is one the
  game won't take, and every call into it after that fails. Pathfinder now
  treats a TomTom that didn't start as not there, and uses the next arrow
  addon or its own. To get TomTom going again, clear its saved arrow
  position and reload:
  `/run for _,p in pairs(TomTomDB and TomTomDB.profiles or {}) do if p.arrow then p.arrow.location=nil end end ReloadUI()`

## [0.21.0] — restart

### Added
- **A guide browser like Zygor's,** in place of the old guide list. Open it
  with the `+` on the tab bar, or **Guide menu** in the guide's ≡ menu.
  - Down the left: a search box and the categories. **Leveling** holds
    Optimized, RestedXP, RestedXP Hardcore, the zone guides (by continent)
    and the custom zones. Then **Dungeons**, **Class Quests**,
    **Professions** and **Favorites**.
  - Reputations, Dailies, Events, Gold, Pets & Mounts and Titles are there,
    greyed, as coming soon.
  - A folder too long to read is split into levels 1-20, 20-40 and 40-60.
  - Point at a guide and the right of the window shows it: a picture, the
    levels it's for, how far through it you are, and **Load** and **Open
    beside the route** buttons.
  - Pointing at a guide also puts up a star, which keeps it in Favorites,
    and an arrow, which opens it.
  - The clicks are the old list's. Left-click opens a guide beside the one
    you're on, right-click loads it in this tab, and shift-click resets it.
- **Every guide has a picture.**
  - A zone guide shows its zone's map **fully explored**: every area drawn
    in, whether you've been there or not. A custom zone shows Turtle WoW's
    own explored map of it, which the addon carries.
  - A dungeon guide shows the loading screen Turtle WoW shows on the way
    in, which the addon carries for every dungeon but Shadowfang Keep. So
    does a route leg named for one, such as Optimized's Uldaman.
  - A class quest shows your class's crest and colour, and the chain's spell
    or reward.
  - A profession shows its icon.
- **HOME** is four panels:
  - the guides you opened last;
  - suggested guides: your route's next leg, class quests, and ticked
    dungeons and custom zones at your level, each with why;
  - a level tracker: the time you've spent at each level, the one you're on
    counting up, with **See more** for every level;
  - a gold tracker: what you've earned today and this week.
  The time and gold are counted while you play, from the first time a
  character runs this version. Gold earned is every rise in your money, with
  nothing taken off for spending. The ⋮ hides any panel you don't want.
- **CURRENT** lists the guides open in the guide window. **RECENT** lists the
  last 30 you opened, by category.
- **The list's ⋮** has four switches:
  - colour guides by how they suit your level (grey once you've outlevelled
    one, green, then yellow, orange and red the further short of it you
    are);
  - tick the guides you've finished;
  - hide finished and outlevelled guides;
  - star the suggested guides.
- **The routes' dungeon runs are under Dungeons.** Optimized's Uldaman and
  Sunken Temple legs, and RestedXP's Scholomance Key, are in an **On the
  routes** folder at the top of Dungeons, each saying whose route it's on,
  not among the route's zones.
- The browser can be resized from its corner. It reopens at that size, where
  you left it, on the tab or category you left it on.
- **The guide window's ≡ menu,** like Zygor's: Guide menu, Setup wizard,
  **Lock window** (no dragging or resizing until you untick it),
  **Transparency** (a see-through panel), Reset window, Reload and Settings.
  The ≡ chip used to open the settings straight away.

### Changed
- The guide list's level filter is gone. HOME's suggested guides, and the
  list's switch that hides outlevelled guides, do its job.
- Reset window also puts the browser back to its own size.

### Not yet checked in game
- Shadowfang Keep shows the game's generic dungeon screen until the addon
  has its own.

### Credits
- The fully explored maps use pfUI's map reveal data (MIT, Shagu): where
  each area's art sits on its zone's map.
- The dungeon loading screens and the custom zones' maps are Turtle WoW's,
  from its client: the art of its Mysteries of Azeroth, Lionel Schramm's
  among it.

## [0.20.0] — restart

### Added
- **Class quest guides.** Every class quest chain has a guide of its own,
  under the guide list's new **Class** tab. That's 139 guides across the
  two sides:
  - the warlock's Voidwalker to the Dreadsteed;
  - the druid's Bear Form, Aquatic Form and Cure Poison;
  - the hunter's Taming the Beast and Rhok'delar;
  - the paladin's Redemption to the Charger;
  - the shaman's totems and the priest's racial spells;
  - the warrior's stances and weapons;
  - Turtle WoW's own, the level-60 ones and the chains that need a group.
  The tab lists only your class's guides, and only the ones your race has
  a way through.
- **Each race gets the chain that starts at home.** An Undead warlock's
  Voidwalker is Carendin Halgar's, in the Undercity. An Orc's is Gan'rul
  Bloodeye's, in Orgrimmar. A Goblin's starts with Dabbling In Darkness on
  Blackstone Island.
  - Turtle WoW's High Elves and Goblins follow the race they share a chain
    with, unless they have their own. A High Elf paladin's Redemption is
    the Human's, after Paragon of Light. A High Elf hunter tames with
    Damilara Sunsorrow in Alah'Thalas.
- **Every step has somewhere to go.** A class guide picks up each quest,
  points the arrow at its objectives and hands it in.
  - For a quest inside a dungeon or raid, the arrow goes to the door
    (Scholomance, for the Charger's Darkreaver).
  - What one quest needs from another comes first: the Charger's horse feed
    before the spirit's quest.
  - A quest's own item, the Taming Rod say, is on the Active Items button.
  - Each guide ends with the chain's last hand-in, so it finishes by itself.
- **A class quest at your level.** When you reach a class quest's level, a
  small window offers its guide, like the dungeon window does.
  - Open puts the guide in a tab beside the route, and finishing it brings
    you back to the route.
  - Each is offered once.
  - It isn't offered when your route already takes you through it (the
    Optimized routes do the warlock's Voidwalker), or when it's done.
  - It isn't offered more than five levels after the chain's level. By
    then you've most likely done it, perhaps before Pathfinder could see.
    The Class tab still lists it.
  - A chain with a dungeon, raid or elite in it is offered only in Group
    mode.
  - With a dungeon to offer at the same level, the dungeon's window comes
    first and the class quest's when you close it.
  - *Offer class quests at their level*, on the options window's Behaviour
    page, turns it off.
- A **CL** badge on a class quest guide's tab.

### Fixed
- **The dungeon window's buttons sat in the wrong place.** They were
  placed against the Where next? window, not their own. Now each window's
  buttons sit in that window.
- **Two dungeon guide steps pointed the arrow at the wrong place.** Every
  place in a step's note goes on that step's zone map, and two notes gave
  places in another zone:
  - Blackrock Depths' way in gave the Searing Gorge's door, which was put
    in the Burning Steppes. The note still names the Searing Gorge, without
    the place.
  - The Alliance Sunken Temple's Rhapsody's Kalimdor Kocktail gave places
    in Tanaris on a Feralas step. The note still says the livers are also
    in Tanaris.

### For contributors
- `Tools/build/build_class_guides.py` writes `Guides/Class/`. It builds the
  chains from pfQuest, pfQuest-turtle and CMaNGOS' quest table, and caches
  what it read in `Tools/data/class_quests.json`. GUIDE_AUTHORING.md says
  how to correct it.
- `Tools/tests/test_classguides.lua` parses every class guide as each race of
  its class sees it.
- The dungeon and class guide tests now fail on a note that gives a place in
  a zone other than the step's.

## [0.19.0] — restart

### Added
- **Notes that have you pick something up tick themselves.** Bingles'
  four tools in Loch Modan are one note each. Each one now ticks when that
  tool is in your bags, as a quest objective does, and shows the ⟳ that
  says so.
  - 101 notes like these in the Optimized and zone guides now tick
    themselves. Each is a note naming one item a quest wants.
  - One you pick up ahead of its note ticks as soon as the guide reaches
    it.
- **An arrow for RestedXP's "Travel to Kalimdor" steps.** Some RestedXP
  steps give a point on the continent's map rather than a zone's: "Travel
  to Kalimdor", "Travel to Eastern Kingdoms", and the dungeon-quest steps
  at Wailing Caverns, Blackfathom Deeps and Uldaman. These 75 steps in 14
  guides had no waypoint.
  - With TomTom, they now get a pin on the continent's map, and TomTom's
    arrow and Pathfinder's point across the continent to it.
  - pfQuest, Cartographer and MetaMap can only place a point in a zone, so
    they still set none for these steps, and say nothing in chat.

### Fixed
- **Leaving a starting zone waited for your next login.** When you
  outlevel a starting zone's guide (Elwynn Forest, Durotar and the rest,
  from level 12), Pathfinder should move you onto the shared route at
  once. It didn't: two parts of the addon each handled the level-up, and
  the one loaded second replaced the other. The move only happened the
  next time you logged in.
  - One level-up handler now does both jobs. It ticks a step that was
    waiting for your level, then checks whether you've finished the
    starting zone.
  - The check now uses your new level. The game can still report the
    old one at that moment.
- **A "Travel to Kalimdor" step could tick in the wrong place.** Pathfinder's
  own arrival check read a continent's point on the map of the zone you
  were in. Standing on the same numbers there, in the Barrens say, ticked
  the step nowhere near the Wailing Caverns. It now measures the distance
  on the continent's map. That needs Astrolabe, which TomTom-TWOW brings.
  Within 30 yards counts as arrived, because these points are only written
  to a tenth of a percent of the whole continent.

### Changed
- **The Optimized guides' first step** no longer says it follows
  "VanillaGuide's optimized quest order"; it says "an optimized quest
  order". The addons Pathfinder grew from are credited on the options
  window's About page, in the README and in CONTRIBUTORS.md.

### Removed
- **`/vg`.** It was the command of TurtleGuide, the addon Pathfinder grew
  from. Use `/apg`, or `/pathfinder`.
- **The `TurtleGuide` name for guide files.** A guide written for
  TurtleGuide registers itself with `TurtleGuide:RegisterGuide`; it now
  needs `AegisPathfinder:RegisterGuide`. Every guide that comes with
  Pathfinder already uses it.
- **The rest of what was left of TourGuide, TurtleGuide and
  VanillaGuide+:** TourGuide's widget library (`WidgetWarlock.lua`, whose
  removal is why this release needs a restart), its unused translations
  (help text, and option labels for addons and windows that are gone), two
  textures nothing drew, and settings nothing read.
  - Your progress from TurtleGuide still carries over, as before.
- An unused glow texture, left over from the step circle's old look.

### For contributors
- Everything that doesn't ship is under `Tools/`: the checks
  (`Tools/run_tests.sh`, `Tools/verify.py`), the tests in `Tools/tests/`,
  the generators and importers in `Tools/build/`, and what they read in
  `Tools/data/`. CONTRIBUTING.md says where everything is.
- The QuestShell+ format is documented in `docs/QUESTSHELL_PLUS.md`.

## [0.18.0]

### Added
- **A ticked dungeon's guide, offered at the middle of its levels.** When
  you reach the middle of the level range of a dungeon you ticked in the
  setup (The Deadmines (17-24) at 21), a small window offers its dungeon
  guide. You can open it in a tab beside the route, or choose "Not now".
  - Each dungeon is offered once, whatever you answer. Nothing is offered
    once you're past a dungeon's top level, have finished its guide, or
    already have it open.
  - If several are due at once, they're listed together. Opening one keeps
    the others in the window.
  - It checks when you level up, when you log in and when you finish the
    setup.
  - It covers the dungeons the setup asks about. Turtle WoW's own dungeons
    start ticked, so they stay with "dungeons along the way".
  - The Dungeons page in the options has a switch to turn it off, and
    Solo Self-Found holds it off.

## [0.17.0]

### Changed
- **The target macro takes the nearest, then the next one out on each
  press.** AegisTarget used to be a `/target` line per target, and `/target`
  keeps whoever you already have targeted when they have the name. So with
  three Crocolisks around, every press stayed on the same one. Now:
  - The first press takes the nearest of the step's targets, each press
    after it the next one further out, then back round to the nearest. Dead
    ones are skipped.
  - The macro is `/apg target`, the same on every step. `/apg target`, the
    key binding and the Macros window's tile all do the same.
  - Clicking a target's button in Active Targets again moves on to the next
    one by that name.
  - Looking round puts no raid marks on the mobs it passes, only on the one
    it takes.
  - It uses ClassicAPI's `TargetNearest`. Without it, or when none of the
    step's targets turn up that way (a quest giver further off, say), it
    targets by name as before. When it finds nobody, your target is left as
    it was.

## [0.16.2]

### Fixed
- **"Cannot find zone "Redridge", using current zone." on every step.** A
  step with no zone of its own is in the guide's zone, read from the guide's
  title, and some titles shorten it: Optimized Redridge (18-20) is in
  Redridge Mountains, but the map has no "Redridge". So each step's waypoint
  went on the zone you were standing in, and chat said so.
  - Shortened zone names are now read as the map's names, in guide titles and
    in steps' zone tags: Redridge, Stranglethorn, Tirisfal, Un'Goro,
    Stonetalon, Hinterlands, Hillsbrad, Alterac, Arathi, Dustwallow, Barrens
    and Stormwind.
  - The Stranglethorn (39-40) guide's steps had their zone written wrong, and
    a Hunter step in RestedXP's Darkshore/Ashenvale guide had a zone and
    coordinates from another map. Both are fixed.
  - Dungeon guides' "outside too" points now say which zone they're in (the
    one the entrance is in), instead of the dungeon's name.
  - RestedXP's "Travel to Kalimdor" and "Travel to Eastern Kingdoms" steps
    give a point on the continent's map, which no arrow here can point at.
    They now set no waypoint and print nothing, where before they put one at
    the same numbers in the zone you were in.

## [0.16.1]

### Fixed
- **Errors with some forks of pfQuest.** Pathfinder reads pfQuest's quest,
  NPC and object tables to place quest-giver waypoints, and uses pfQuest's
  map to put waypoints and its arrow on the step. It assumed every one of
  those tables and functions was there, and a fork without one gave errors.
  - Each table is now checked before it's read; a missing one just means no
    waypoint from it.
  - pfQuest is only used for waypoints when all the map functions Pathfinder
    needs are there. Otherwise another waypoint addon takes them.

## [0.16.0]

### Added
- **Badges that say what a guide is**, on its tab. `XP` for a leveling guide
  as before, plus:
  - `PF` (blue) for a profession guide or crafting route;
  - `DG` (violet) for a dungeon guide;
  - `HC` (red) for a hardcore guide.

  A placeholder guide still says `TPL`.

### Fixed
- **Ticks moved to other steps when a filter changed.** The addon remembers a
  tick by the step's name and its place in the guide.
  - That place was counted among the steps the filters kept. Switching group
    mode, Auction House steps, a dungeon or Solo Self-Found added or removed
    steps, so every later step's place changed, and the ticks saved against
    the old places landed on other steps.
  - A step's place is now counted among all the guide's steps, so filters
    don't move it.
  - Your ticks move over to the new places once, the first time each guide
    loads. A guide with nothing filtered keeps the places it always had.

## [0.15.5]

### Fixed
- **The AegisTarget macro had a blank icon**, in the Macros window and on
  an action bar.
  - The stock macro functions pick an icon by its place in the game's
    macro-icon list. The game fills that list only when something asks for
    it.
  - The addon read the list once, while it was still empty, and saved the
    macro with an icon from an empty list: nothing.
  - Macros are now written through ClassicAPI's macro functions, which take
    the icon by name. AegisTarget wears Hunter's Mark's icon, and AegisItem
    the quest item's own icon, which the stock list doesn't have.
  - A macro already made blank gets its icon at the next update.
  - Without ClassicAPI's macro functions, the list is read again until the
    game has filled it.

## [0.15.4]

### Fixed
- **Active Targets sent you to crocolisks in other zones.** For Loch Modan's
  Crocolisk Hunting, the targets and the AegisTarget macro were Elder
  Saltwater Crocolisks, Wetlands Crocolisks and the like, never a Loch
  Crocolisk.
  - Crocolisk Meat and Skin drop from every crocolisk in the world, and more
    often from those elsewhere. The targets were simply the likeliest drops
    anywhere.
  - Now the creatures the quest wants killed or looted come from where the
    step is: the step's zone, then the guide's zone, then the zone you're in.
    Only when none of those has any does it fall back to everyone.
  - Quest icons mark by the zone you're in the same way.

## [0.15.3]

### Fixed
- **The guide kept closing in combat.** Escape closed it. In a fight, Escape
  is what clears your target or cancels a spell, so the guide went with it.
  Escape no longer closes the guide; its ✕ does. Escape still closes the
  options, the guide list, the Gear finder and the other windows opened from
  the guide.

## [0.15.2]

### Fixed
- **"QuestTracker.lua:177: attempt to call method 'GetObjectiveInfo'"**, and
  the "ItemScore.lua:72 ... field 'db'" error with it. Both came from Core.lua
  stopping part-way as it loaded.
  - At load, Core.lua reads the game's races from ClassicAPI, and every
    race's side with them.
  - The game's race table also lists creature races with no side, and
    ClassicAPI gives nothing for their side. Reading that nothing stopped
    Core.lua at that line.
  - Everything after that line was never set up: the saved settings, and
    much of the guide. Every error that followed was a symptom.
  - Races with no side are now skipped. Without ClassicAPI at all, the addon
    now says so instead of failing.

## [0.15.1]

### Fixed
- **"ItemScore.lua:72: attempt to index field 'db' (a nil value)"**, around
  login. The item score, the Gear Advisor and the Gear finder listen for
  your gear arriving and for zoning in from the moment their files load,
  which can be before the addon has loaded its saved settings. They went
  looking for the settings and stopped with that error. Those events are now
  ignored until the settings are loaded, and your worn gear is recorded then
  instead.

## [0.15.0] — restart

### Added
- **A switch for each arrow.** The **Arrows** section on the **Navigation**
  page has one each for Pathfinder's, TomTom's and pfQuest's arrow, in place
  of the one-choice dropdown. Turn on any combination: each arrow that is on
  points at the step, even when another addon is the one taking the
  waypoints.
  - pfQuest's switch is pfQuest's own arrow setting, the one `/db arrow`
    changes. Off, pfQuest's arrow is off altogether, so it no longer points at
    the nearest quest objective as a second arrow.
  - TomTom's switch keeps its arrow off the guide's waypoints; waypoints you
    make yourself still use it.
  - An addon that isn't loaded has its switch dimmed, and the note names it.

### Changed
- **Steps the addon ticks for you have a small ⟳ inside their circle**, in
  place of a glow that looked like the circle was out of focus. An empty
  circle is one only you can tick; a filled one is done. The ⟳ is a new
  texture, hence the restart.
- **The step's accent bar runs down past its objectives.** The bar down the
  left edge, and the faint wash, now reach past the objective bars to the
  footer, so the bars read as part of the step.

### Fixed
- **Objective bars were still short in game.** 4 of 5 Crocolisk Meat was
  about half full, and 4 of 6 skins about two fifths. The width the client
  reports for these bars isn't the width it draws them at, so any fill sized
  from it comes out wrong. They're now the client's own status bars, which
  fill to the count themselves. The guide's progress bar under the step
  number gets the same fix.

## [0.14.0]

### Added
- **Dungeons along the way.** Switch on *Offer dungeon guides along the way*
  on the options' **Dungeons** page, and finishing a guide asks **Where next?**
  with the guides of the dungeons you ticked that fit your level, under the
  custom zones: up to four, lowest first. One opens in a tab beside your
  route. It is off to start with, and Solo Self-Found holds it off.
- **Turtle WoW's own dungeons on the Dungeons page**, as chips of their own:
  Frostmane Hollow, Windhorn Canyon, Dragonmaw Retreat, Stormwrought Ruins,
  Crescent Grove, Gilneas City and Hateforge Quarry. No route guide has steps
  for them; ticked, the Gear finder looks in them, and their guides can be
  offered along the way.
- **Red and green switches**, on the **Appearance** page: every switch green
  when on and red when off, whatever the theme.
- **A bar for each objective.** The meter under the step has a line for each
  thing the quest wants, each with its count and its own bar. Crocolisk
  Hunting shows the meat and the skins.

### Changed
- **Switches take the theme's colours again**, as they did before 0.12.7;
  red and green is now the switch above. RavenCraft's on switch is a near
  white, since grey on grey did not say whether a switch was on.
- **The route preview fills the Route page**, down to the bottom, and shows
  more legs as the window is made taller.

### Fixed
- **The Scale slider jumped to 60% at a touch and would not move.** It sits in
  the options window it scales, so each step rescaled the window under the
  cursor and the slider chased itself to the bottom. While you drag, only its
  number moves; the windows take the size when you let go.
- **A guide went back to step 1.** Opened partway, it went to the quest your
  log shows work at, such as Loch Modan's Crocolisk Hunting, 27 steps in. The
  next update then went back to the guide's first note, which the log cannot
  tick: "1 of 58, 0 done". Now the notes, runs, flight paths and hearths
  before a quest you have picked up or finished count as done. One before a
  quest you have not picked up still waits for you.
- **An objective's bar showed less than its count**: 4 of 5 Crocolisk Meat
  was a third full. The bar was sized from its width at the moment it was
  drawn, which can be stale. It now keeps the count and sizes itself again
  when its width changes.

## [0.13.1] — restart

### Added
- **Dungeon guides.** The guide list has a **Dungeons** tab with a guide for
  every dungeon, for your side. Pick one and it:
  - goes round the towns to pick up every quest for the dungeon, doing the
    quests before them on the way;
  - puts the arrow on the entrance;
  - has you do what each quest wants inside;
  - hands everything in after.

  A chain that needs another visit, such as Uldaman's necklace, gets another
  run. A quest whose chain starts somewhere the guide does not go, such as a
  class chain or another dungeon's quests, is optional: it shows once you have
  done the quest before it. Quests given where the guide does not go are named
  in a note at the top. The guides cover Ragefire Chasm to Blackrock Depths,
  and Turtle WoW's own dungeons:
  - Windhorn Canyon, new in patch 1.18.1;
  - Frostmane Hollow, which also has a Horde guide for cross-faction groups;
  - Dragonmaw Retreat, Crescent Grove, Stormwrought Ruins, Gilneas City and
    Hateforge Quarry.
- **Windhorn Canyon's quests**, on both sides:
  - Alliance: In Search of Tauren Relics, from Ironforge.
  - Horde: Relics of the Windhorn Tribe and The Wrath of Malgan, from Sagh's
    Refuge.
  - Horde: Cairne's Destroy the Deathtotem, by way of Grimtotem Spying.
  - Horde, Shaman only: Vortalus' Edict.
- **Windhorn Canyon and Frostmane Hollow in the Gear finder**, with each
  boss's loot and its drop chance. Windhorn Canyon is at 26-30, Frostmane
  Hollow at 13-20.
- The data comes from two new sources:
  - [InstanceJournal](https://github.com/Arthur-Helias/InstanceJournal) by
    Arthur-Helias gives each dungeon's quests, entrance and levels, and the
    two new dungeons' loot.
  - [The Kludge Bureau's pfQuest-turtle](https://github.com/The-Kludge-Bureau/pfQuest-turtle)
    gives patch 1.18.1's quests.

## [0.13.0] — restart

### Added
- **The Optimized Horde route runs Uldaman and the Sunken Temple**, as the
  Alliance route already does, so the first-time setup now recommends both
  for the Horde.
  - *Uldaman (46-46)*, after Feralas, picks up Necklace Recovery in
    Orgrimmar, Reclaimed Treasures in the Undercity, Uldaman Reagent Run in
    Kargath and Solution to Doom from Theldurin, runs the dig site and the
    instance, and hands everything in on the way back, the Platinum Discs to
    Thunder Bluff included. Tanaris (49-50) takes the discs to the Uldum
    Pedestal, and the Burning Steppes' stop in Thunder Bluff finishes the
    chain. That is 13 quests.
  - *Sunken Temple (53-53)*, after the Burning Steppes, hands in Return to
    Fel'Zerul in Stonard, picks up The Temple of Atal'Hakkar and runs the
    temple: Into the Depths, Secret of the Circle, Zapper Fuel, Jammal'an and
    the Essence of Eranikus. Then it hands in the Fetishes in Stonard and
    Jammal'an at Shadra'Alor. Into the Depths is now picked up from Marvon
    after The Stone Circle. Zapper Fuel, which the route picked up and never
    handed in, goes back to Larion in Marshal's Refuge on the way to
    Silithus. That is 9 quests.
  - Without the dungeon ticked, each leg is a single note.

## [0.12.8]

### Added
- **More than one spec, as Pawn does.** The Item Score page has a switch for
  each spec of your class; yours is always on. Every spec that is on gets its
  own line on item tooltips, with its score and upgrade percentage.
- **The best you have worn, per spec.** Each spec that is on remembers the
  best items you have worn in each slot -- the best two rings and trinkets --
  as your gear changes, and an item is weighed against those rather than what
  you have on, so the healing set in your bags does not hide a tank upgrade.
  **Forget best items** starts again from what you wear. With nothing
  remembered yet, the comparison is with what you wear, as before.
- **Drops for your other specs.** When something new in your bags beats your
  best for another spec that is on, the chat names it once, with the gain.
  Your own spec's upgrades still go to the Gear Advisor's window. There is a
  switch for it on the same page.

## [0.12.7]

### Added
- **Window scale.** A **Scale** slider on the options window's Appearance
  page, 60% to 150%, sizes every Pathfinder window at once: the guide, the
  options, the shopping list, the Active Items and Targets windows and the
  rest. It is kept per profile.

### Changed
- **The step title wraps.** In focus mode the guide's step title wraps to the
  window's width instead of ending in "..." -- drag the grip narrower and the
  title takes more lines, and the step grows to hold them. The overview list
  keeps one line a step, so it still scrolls.
- **Switches are green when on and red when off,** whatever the theme. In some
  themes an on switch and an off one were near enough the same grey.

## [0.12.6]

### Fixed
- **Optional quests that follow another are offered once it is done.** A
  step like "A Rescue OOX-22/FE! |PRE|2766| |O|" waits for its prerequisite,
  but the guides give that as a quest id and the addon looked for it among
  the steps' names, so it never found it and the step was never offered.
  Now the id is checked against the server's record of your quests and the
  guide's own turn-ins, and a list of ids needs all of them. Affected: Rescue
  OOX-22/FE!, The Newest Member of the Family and An OOX of Your Own
  (Optimized Alliance), Proof of Deed, At Last! and Further Mysteries (zone
  guides). Prerequisites given by name work as before.

## [0.12.5] — restart

### Added
- **The Optimized Alliance route runs the Sunken Temple.** A new leg after the
  Burning Steppes, *Sunken Temple (56-56)*, picks up Into The Temple of
  Atal'Hakkar in Stormwind, runs the temple -- the Atal'ai tablets, Into the
  Depths, Secret of the Circle, Jammal'an and the Essence of Eranikus -- and
  hands in Jammal'an at Shadra'Alor and the tablets in Stormwind before
  Silithus. Into the Depths is picked up from Marvon after The Stone Circle,
  and the Hinterlands now offers Jammal'an the Prophet, which was optional and
  so never offered. The Sunken Temple adds 13 quests to the route. Without
  the Sunken Temple ticked, the leg is a single note.

### Fixed
- RestedXP Alliance: Jammal'an the Prophet is picked up at the Altar of Zul
  and handed in on the way to the Plaguelands, by way of the Hinterlands.

## [0.12.4]

### Fixed
- **Dungeon quest chains the guides started and never finished.** With the
  dungeon ticked, each now gets its missing pick-up, dungeon step or hand-in
  where the route already passes the quest's NPC:
  - RestedXP Alliance: Into the Depths and Secret of the Circle in the Sunken
    Temple; Mortality Wanes handed in in Darnassus on the Feralas leg; The
    Dragon's Eye handed in to Haleh above Mazthoril after the last guide
    hearths to Everlook (RXP Hardcore too).
  - RXP Hardcore Horde: a stop in Thunder Bluff between the Swamp of Sorrows
    and Tanaris for the Platinum Discs, Portents of Uldum and Seeing What
    Happens, so the Uldum Pedestal chain in Tanaris can start; Deadmire is
    handed in on the same stop. The Badlands detour at 42 no longer offers To
    the Undercity for Yagyin's Digest, which needs Solution to Doom first, and
    Necklace Recovery is handed in after Uldaman instead of straight after it
    is accepted. Shadowshard Fragments is picked up and handed in in
    Orgrimmar around Maraudon.
  - RestedXP Horde: Necklace Recovery (once you have looted the necklace in
    Uldaman) and Shadowshard Fragments in Orgrimmar; The Power to Destroy...
    for Undead, from Varimathras on the way to Ragefire Chasm.
  - Optimized: the Burning Steppes guides take a Blackrock Depths group in
    for A Taste of Flame (Alliance) and Lost Thunderbrew Recipe (Horde) and
    hand them in; the Horde picks up Yuka Screwspigot in Tanaris too.
- Left as they are, because the route cannot finish them: The Prophecy of
  Mosh'aru, Nekrum's Medallion and The God Hakkar (their first step is only
  handed in after the Zul'Farrak run), Tiara of the Deep (a mage quest's
  follow-up), Jammal'an and Zapper Fuel where the route never returns to the
  Hinterlands or never runs the Sunken Temple, Going, Going, Guano! (its
  guano drops only with the quest, which needs level 30, after the Razorfen
  Kraul run), and Badlands Reagent Run on the Hardcore route, which does no
  Badlands questing.

## [0.12.3]

### Added
- **The Optimized Alliance route runs Uldaman.** Its Uldaman guide was notes
  only; it now takes you from Gadgetzan to Ironforge, Loch Modan and the
  Badlands for the quests, through the dig site and the instance, and back
  to Ironforge to hand them in -- the Platinum Discs up to Seeing What
  Happens, which Tanaris finishes at the Uldum Pedestal. Uldaman adds 21
  quests and is recommended for the Alliance in the setup.

### Fixed
- Steps tracking the wrong quest in the Optimized Alliance guides: Tanaris's
  Seeing What Happens (2946) and Return to Ironforge (2977) were both Portents
  of Uldum's id, Yuka Screwspigot (4324) was Divino-matic Rod's, and the
  Hinterlands' Jammal'an the Prophet (1446) was The God Hakkar's. The Uldum
  steps were also optional, and an optional accept is never offered, so the
  chain never started; with Uldaman ticked it now runs. Yuka Screwspigot
  sends you to Blackrock Depths' quests, so it is tagged for Blackrock Depths,
  not Zul'Farrak. The filter review records follow the corrected ids.
- The Optimized Badlands guide hands in Badlands Reagent Run and Find Agmond
  but never picked them up; it now stops in Loch Modan for them on the way.

## [0.12.2]

### Fixed
- **Steps meant for a race now reach it.** About 500 steps in the RestedXP,
  RXP Hardcore and zone guides had class or race tags that no character
  could match, so they were hidden from everyone they were written for:
  - `|R|NightElf|` (the client says "Night Elf"): some 150 steps every Night
    Elf skipped.
  - Races inside class tags, where the RestedXP converter folded "Orc Rogue
    or Troll Rogue" into `|C|Rogue/Troll/Rogue| |R|Orc|`, and "not a Shaman
    or Warrior, or any Undead" into `|C|!Shaman/!Warrior/Undead|`. An Undead
    Warrior never saw The Forgotten Pools, and with it Wailing Caverns'
    Leaders of the Fang and Nara Wildmane, which now count in the setup.
    Night Elf mages, priests and rogues missed 27 Darkshore steps the same
    way.
  - Comma lists: `|R|Orc, Troll|`, `|R|Scourge, Undead|`, `|C|Warlock, Mage|`.
  Each was rewritten from the filter in RestedXP's own guide. Where it reads
  "class A, or race B", the step is now two steps that never overlap.
- `Tools/verify.py` checks that every class tag names classes and every race
  tag races, as the client gives them.

## [0.12.1]

### Removed
- **Kamisayo Speedrun is hidden until its guides are added.** None of the
  pack's guides were ever in the addon -- the guide is only shared on
  Kamisayo's Discord -- so picking it stopped on its first leg. It is no
  longer offered in the setup, the options window or `/vg RoutePack`, and a
  character that had it moves to **RestedXP** when it logs in. The route is
  kept in `Routes/Routes.lua`, ready for when the guides come.

## [0.12.0] — restart

### Changed
- **The dungeon step of the setup counts quests, and recommends for the guide
  you picked.** Each dungeon says how many quests it adds to your route, and
  a quest counts only if your guide takes you all the way through it on your
  race's route: sends you to pick it up, has you do first whatever the server
  wants done before it, and sends you to hand it in. A quest whose chain runs
  through another dungeon counts once that one is ticked too ("1 quest (+4
  with Deadmines)"). **Recommended** is now per guide pack and race: the
  dungeons that add five quests or more. It was one list per faction, from
  counting the RestedXP guides' steps.
  - RestedXP recommends 6 to 9 dungeons by race, RXP Hardcore 9 to 11; the
    Optimized guides take you through few dungeon quests, so they recommend
    the Sunken Temple for the Alliance and none for the Horde.
- **Your route decides what comes next.** Finishing a guide on your route
  goes on to the route's next leg for your guide pack and race; a guide's own
  next guide is the way on only off the route. RestedXP's paths part at 19 --
  the Eastern Kingdoms races through Redridge and the Deadmines, Night Elves
  through Darkshore -- and a guide can name only one next.

### Fixed
- **The Optimized guides stopped at 30 and again at 40** (and the Alliance's
  at 50): those guides named no next guide. The High Elf and Goblin starting
  zones handed you to the older zone guides instead of the Optimized ones.
- **Routes that named guides that do not exist**: the Horde's Optimized
  Stonetalon Mountains legs, RestedXP's Wetlands and Southern Barrens, and
  from 42 the Alliance's RXP Hardcore route, which named the Horde's guides;
  the Horde's has no 41-42 Badlands or 45-46 Feralas, and now skips them.
  RestedXP's routes follow its guides again, with the Alliance's 29-30
  Ashenvale, 35-37 Desolace, 40-40 Dustwallow Marsh, 40-41 Desolace, 43-44
  Tanaris/Dustwallow, 50-50 Stranglethorn, 51-51 Blasted Lands and 59-59
  Winterspring/Silithus, and the Horde's 41-41 Desolace, that it skipped.
- **Next guides that did not exist**: the RestedXP converter had left its
  folder names in them ("RestedXP Horde 22-30\22-24 Hillsbrad").
- **Dungeon quests the guides never finished**:
  - Gnomeregan's four quests were never handed in (RestedXP and RXP
    Hardcore, Alliance), nor Red Silk Bandanas (RestedXP).
  - Blackfathom Deeps, Horde: Allegiance to the Old Gods' second part was
    picked up before the first was handed in, and never handed in; Baron
    Aquanis had another quest's id, and no pick-up or hand-in.
  - In Search of Thaelrid was never handed in (RXP Hardcore, Alliance).
  - Brother Paxton was handed in before it was picked up, with the
    Deadmines ticked, and Ink Supplies with it (RXP Hardcore).
  - An Unholy Alliance was handed in only with Scarlet Monastery ticked, not
    Razorfen Downs, where it is done.

### Added
- **`Tools/build_dungeon_quests.py`** checks every dungeon quest along every
  route against the server's quest rules (CMaNGOS classic-db's, and
  pfQuest-turtle's for Turtle WoW's own quests), writes `DungeonQuests.lua`,
  and with `--report` says which do not count and why.
- **`Tools/test_routes.lua`**: every route leg and next guide exists.

## [0.11.1]

### Changed
- **Moonwhisper Coast's group quests are for Group mode**: Price of Betrayal,
  Draenethyst Recovery (inside Timbermaw Hold, at 60) and the zone's bosses --
  Mothshroud Falls, Serpents Without Heads, Keeper of the Broken Grove, Shade
  Mother, A Star That Calls Back -- and every quest that follows from them.
  Solo, the Horde's Moonhoof story stops before Shade Mother, and the
  Alliance skips the trip to Darnassus for Word to the High Priestess.

## [0.11.0] — restart

### Added
- **Moonwhisper Coast (52-60)**, the zone patch 1.18.1 added north of
  Azshara, with a guide for each side: Moro'gai Village's draenei for both,
  Sunsworn Camp and Narvalis Point for the Alliance, Moonhoof Village and
  Moonhoof Retreat for the Horde. The Horde's stories go out to Azshara and
  Mulgore and back, and the guide goes with them. Where next? offers it from
  51, and it is under the guide list's **Custom** tab.
  - Written from quest data players have gathered
    ([ryanmr82's pfQuest-turtle](https://github.com/ryanmr82/pfQuest-turtle)),
    not a server's database, so expect gaps: quests nobody is on record as
    giving, and the ones picked up elsewhere, show only once they are in
    your log. Tell us where it sends you wrong.
- **`Tools/build_zone_guide.py`** writes a zone's guides from a
  pfQuest-turtle checkout -- prerequisites, then level, then the nearest
  thing to do -- so the guide can be written again as the data grows.

### Docs
- The authoring notes gave `|C|` and `|R|` lists with commas; the parser
  splits them on `/`, and matches races as the client names them
  (`Night Elf`).

## [0.10.0]

### Fixed
- **Stat names wrapped on the Item Score page**: "Armor Penetration",
  "Casting Regen %" and the like broke onto two cramped lines. The name
  column is wider and the weight's field narrower, so every name stays on
  one line.

### Added
- **[docs/TESTING.md](docs/TESTING.md)**: the in-game test pass, what only a
  real client can check, section by section. Copy it into an issue and tick
  it off before a release.

## [0.9.1]

### Added
- **The Gear finder looks beyond drops**: at 60 much of the best gear is not
  one. Each switched in the options' Gear page, on to start with:
  - **Quest rewards** from quests you have still to do, on your side and for
    your class — *Quest: Strength of Mount Mugamba (Friendly, Zandalar
    Tribe)*.
  - **Reputation gear** a vendor sells at a rank — *Revered with Stormpike
    Guard*.
  - **Crafted gear** — *Blacksmithing 300 · made by a crafter*, or just the
    profession when it is yours. Gear that binds on pickup counts only if you
    have the profession, and under Solo Self-Found all crafted gear does.

  Near your level only (up to ten levels under it): there are thousands.
- **Turning raids on in the Gear finder says it takes a while**: the first
  time, hundreds of raid items load from the server, a minute or two. The
  window says so too while they load.

---

## [0.9.0]

### Fixed
- **Uneven gaps in the options** around labels that only just fit, such as
  "Pick it for me when quests turn in by themselves": they were counted as
  two lines and drawn on one. A label that fits is one line now.
- **Resizing the options window lays each page out again**: a label that
  stops wrapping gives its line back and the rows under it move up, instead
  of leaving a gap.
- **The Gear finder's note at 60** named every dungeon it looked in — all of
  them, at 60 — and ran over the list. It names up to four and counts the
  rest ("from 26 dungeons and 9 raids").

### Changed
- **The README shows Pathfinder in game**, and the options window's Route,
  Dungeons, Behaviour and Gear pages.

---

## [0.8.0]

### Changed
- **The Gear finder knows Turtle WoW's vanilla dungeons and raids as Turtle
  has them**, not as they were in 2006: the bosses Turtle added (Molten Core's
  Incindis and Basalthar, Deadmines and Blackrock additions and more), loot
  moved from one boss to another, new items on old bosses (VanCleef's Spiked
  Defias Spaulders), and drops Turtle took out. From pfQuest-turtle, over the
  CMaNGOS loot it had.
- **The README's screenshots sit with their features**: party sharing under
  *Play together*, the first-time setup under *Guides*, the helper windows
  under *Quest helpers*.

---

## [0.7.0]

### Changed
- **Solo Self-Found is solo.** Turning it on now also leaves out group quests
  and dungeon quests, not only trading and the Auction House. Group mode, the
  Auction House switch and the dungeon chips read off and can't be clicked
  until it is off again — in the options and in the first-time setup, which
  skips its dungeons step. The Gear finder looks in no dungeons. What they
  were set to is kept, and comes back when Self-Found goes off.
- **The README has screenshots**: the guide in the world, a quest target and
  the macros, and sharing a guide with your party.

### Added
- **The options window resizes** from a grip in its bottom-right corner:
  wider or taller, and it keeps the size. `/apg resetpanels` puts it back.

### Fixed
- **Long option labels were cut off** at the window's edge ("Pick it for me
  when quests turn in by themselves", "Quest icons: mark quest NPCs as you
  mouse over them"). A label that does not fit now wraps onto a second line.

---

## [0.6.3]

### Added
- **Right-click the step arrows to jump to your place.** Clicked round the
  guide to look back or ahead? Right-click the arrow pointing where you were
  and you're there, with every tick the arrows changed on the way put back
  (and any quest you finished meanwhile kept). Without clicking round, a
  right-click goes to where the guide would open — the quest your log shows
  work at, else the first step not done. The arrows' tooltips say so.

---

## [0.6.2]

### Added
- **The Gear finder looks in Turtle WoW's own dungeons and raids**: Dragonmaw
  Retreat, Crescent Grove, Stormwrought Ruins, Gilneas City, Hateforge Quarry,
  Karazhan Crypt, The Black Morass, Stormwind Vault, and the Emerald Sanctum
  and Tower of Karazhan raids — their bosses' drops and how often, from
  pfQuest-turtle, at the levels their creatures are. The game is asked what
  Turtle's own items are the first time, so the list can take a few seconds
  to fill in, once. Walking into one names its upgrades, as for any dungeon.

---

## [0.6.1] — restart

### Changed
- **The minimap button is the Aegis: Pathfinder logo**, in its own colours,
  at the stock minimap buttons' size, with the theme's accent ring round it on
  hover. It replaces the green shield. The logo is a new texture file, so
  restart the client rather than `/reload`.
- **The README matches the rest of the Aegis series**: badges for the servers
  and what the addon needs, the logo, a Discord link, and a section a feature.

---

## [0.6.0]

### Changed
- **The stat weights are a page of the options now, not a window of their
  own**: **Item Score**, listed under **Gear**, laid out as Zygor's is. Your
  spec, *Show all stats*, and every weight down the left with a box each;
  beside them the OctoPawn string with **Import** and **Export**; **Reset**
  under them. `/apg gear` and **Stat weights** on the Gear page turn to it.

---

## [0.5.0]

### Changed
- **The options window has pages**, with the categories down the left as
  Zygor's options have them: Route, Dungeons, Filters, Appearance, Gear,
  Behaviour, Navigation, Maintenance, About. One page at a time, scrolling
  only when it is taller than the window; the **Credits** button is on About.
- **The README is short**: what you get, installing, the main commands. Every
  feature in detail is in [docs/FEATURES.md](docs/FEATURES.md).

### Fixed
- **A new character opened at the end of the guide** — far into the High Elf
  quests, say — with every step before it counted as done. Where a guide
  opens kept the last step not done rather than the first. It now opens at
  the step your quest log shows work at, else the first step not done.
  Progress was always saved per character; this only made a fresh one look
  far along.
- The guide no longer paints a hand-in further down as done because you have
  not picked that quest up yet.
- Hovering **Solo Self-Found** raised an error (`Theme.lua:1270: bad argument
  #1 to 'ipairs'`).
- `/apg trackquests` and `/apg skipfollowups` raised an error while the
  options window was open.
- The **Arrow** list stayed on screen when the options window closed with it
  open.

---

## [0.4.2] — restart

### Added
- **Gear finder**, the third part of Gear (`/apg finder`, or **Gear finder**
  in the options): for each slot, the best few upgrades that drop in the
  dungeons you run, with who drops them, where, and how often. It looks in
  the dungeons starting no more than three levels above you, on your side,
  ticked under **Dungeons** — and in raids if you ask. Walking into a dungeon
  names its upgrades in chat. The loot is the CMaNGOS database's, for every
  vanilla dungeon and raid — bosses a script summons (Ragnaros, Nefarian,
  Darkmaster Gandling, the Edge of Madness) included; Turtle WoW's own
  dungeons are not in it yet.

### Changed
- **Weapon skills are out of the item score** (+Swords, +Daggers and the
  rest): the Gear window lists the stats Zygor's does.

---

## [0.4.1] — restart

### Added
- **Gear Advisor**, the second part of Gear, switched under **Gear** in the
  options:
  - Upgrades you pick up pop up with **Equip** or **Decline**; declined items
    are not offered again until you clear the list. In a fight, Equip waits.
  - **Equip upgrades for me** (off until you turn it on) never equips an item
    that would bind to you; that one still asks.
  - The best quest reward is marked — the biggest upgrade, or the one a vendor
    pays most for — and, with **pick it for me** on and quests turning in by
    themselves, taken. Sell prices come from the CMaNGOS database.
  - Upgrades are bordered in the default bags.
  - Off, or off at level 60, when you want.

### Changed
- **Auction House tags go on the step that sends you there, not on the
  quest.** A quest you can do by fishing, farming a drop or finding a vendor
  now stays with Auction House steps off: *The Family and the Fishing Pole*,
  *Catch of the Day*, *Fish in a Bucket*, *Look To The Stars*. Notes about
  farming (Green Hills pages to keep, the Treasure Map, Morrowgrain, Silk
  Cloth) are no longer hidden either. Quests that need a crafted item —
  *Ineptitude + Chemicals = Fun*, *Chasing A-Me 01*, *The Blazno Touch* and the
  Tel'Abim alchemy, engineering and enchanting quests — still are.

---

## [0.4.0] — restart

### Added
- **Item score**, the first part of Gear. Every item's tooltip says what it
  is worth to your spec and how it compares with what you wear: green `+12%`
  for an upgrade, red for worse, *empty slot*, or *not for you* for what you
  cannot use; an item you are too low for says the level it becomes one at.
  - Stats are read off the tooltip, weighted for your class and spec, with
    soft caps. Rings, trinkets and one-handers are weighed against the slot
    they would replace, two-handers against both hands; enchants are left out.
  - Your spec follows your talents, or the one you pick; the levelling spec
    until you have talents.
  - The weights are OctoPawn's (MIT) for every class and spec. The **Gear**
    window (`/apg gear`, or **Stat weights** in the options) lets you change
    any of them, reset them, and export or import them in OctoPawn's format.
  - A switch in the options takes the line off tooltips.

---

## [0.3.1]

### Added
- **Solo Self-Found mode**, as RestedXP has: for a character that never
  trades and never uses the Auction House, every step that needs either is
  left out, and the Auction House switch is held off while it is on. A switch
  under **Filters**, a choice in the first-time setup, and `/apg ssf`. Guide
  authors can mark a step that needs another player with `|TRADE|`.

### Changed
- **Some filter tags come off again, on a second look:**
  - The paladin *Tome of Divinity* and the druid *Gathering the Cure* chains
    no longer count as Auction House quests. Linen Cloth drops from
    humanoids; Earthroot, Lunar Fungus and Kodo Horns are gathered or drop.
  - Westfall's trip to Stormwind for *Shipment to Stormwind* is no longer a
    group step. Its note mentions Hogger, but the step isn't his.

---

## [0.3.0]

### Added
- **Mining says where to mine.** Each step of the Mining route, for your
  faction: where to mine the ore a smelting step uses (Copper, Tin, Silver,
  Iron, Gold, Truesilver, Thorium), and, for the stretches that level by
  mining alone, the zones with most of the veins that can still raise your
  skill. From pfQuest's ore nodes and the CMaNGOS database's vein loot.

### Changed
- **The Auction House, Group and Dungeon switches now cover the Optimized and
  zone guides**, as they always did the RestedXP ones — the tags the owner
  approved in the filter review. In Solo mode those guides leave out elite
  and group quests, and the quests that follow on from them; with Auction
  House steps off they leave out quests that need an item most players buy;
  a dungeon's quests show while that dungeon is ticked. The defaults (Solo,
  Auction House steps off) mean fewer steps than before on these guides.

---

## [0.2.0]

### Added
- **Herbalism, Skinning and Fishing guides**, 1–300 — the last three
  professions, until now placeholders. Each skill band is one step naming
  where to go, for your faction, with the levels this addon's zone guides
  spend there:
  - Herbalism: the zones with most of the herbs that can still raise your
    skill, and which herbs to look for, counted from pfQuest's node data
    (Turtle WoW's new zones included).
  - Skinning: the levels of beast worth skinning, and the zones with most of
    them.
  - Fishing: the zones where nothing gets away at your skill; the Expert book
    from Old Man Heming; Nat Pagle's Artisan quest with where each fish is
    caught, or Katoom the Angler for the Horde.
- Every rank names your faction's trainers, capital cities first, and points
  the arrow at the nearest.

---

## [0.1.0] — restart

The first numbered build. Everything below was already in the addon; from here
on, each change gets its own entry.

### Added
- **Leveling guides**: the Optimized routes (Joana's), RestedXP and RXP
  Hardcore route packs, zone guides, and the Turtle-lineage custom zones, with
  automatic accepting, completing and turning in of quests.
- **The guide panel**: one step at a time or the whole guide, up to eight
  guides open as tabs, a navigation arrow, server themes (Day, Night, Turtle
  WoW, OctoWoW, RavenCraft, Capybara Paradise, Aegis), and a first-time setup.
- **Where next?**: custom zones offered between guides when they fit your level.
- **Active items, active targets and macros**, as RestedXP has, and **quest
  icons** — raid markers on the NPCs and mobs your quests want.
- **Profession guides** for eleven professions, a **shopping list** that can go
  to Aegis: Exchange, and the **cheapest crafting route** at today's prices,
  with its own auction scan and a "load as guide" button.
- **Sharing a guide with your party** (beta): progress under each step, and a
  finished step waits for everyone.

---

[0.26.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.25.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.24.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.23.4]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.23.3]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.23.2]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.23.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.23.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.24]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.23]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.22]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.21]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.20]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.19]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.18]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.17]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.16]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.15]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.14]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.13]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.12]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.11]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.10]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.9]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.8]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.7]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.6]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.5]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.4]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.3]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.2]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.22.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.21.3]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.21.2]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.21.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.21.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.20.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.19.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.18.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.17.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.16.2]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.16.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.16.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.15.5]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.15.4]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.15.3]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.15.2]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.15.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.15.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.14.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.13.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.13.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.12.8]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.12.7]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.12.6]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.12.5]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.12.4]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.12.3]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.12.2]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.12.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.12.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.11.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.11.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.10.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.9.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.9.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.8.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.7.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.6.3]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.6.2]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.6.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.6.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.5.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.4.2]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.4.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.4.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.3.1]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.3.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.2.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
[0.1.0]: https://github.com/Torchlite-bit/Aegis_Pathfinder/releases
