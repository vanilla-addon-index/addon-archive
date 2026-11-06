# Aegis: Pathfinder — features in full

Everything the addon does, in detail. The [README](../README.md) is the short
version.

## Commands

| Command | |
|---|---|
| `/apg` | Open the objectives panel |
| `/apg next` / `prev` | Step forward or back |
| `/apg goto <n>` | Jump to a step |
| `/apg reset` | Reset progress in the current guide |
| `/apg resetpanels` | Put every window back where it opens by default |
| `/apg materials` | The shopping list: reagents for this craft, or the rest of the guide |
| `/apg exchange` | Send the guide's remaining crafts to Aegis: Exchange, or take them back out |
| `/apg craft` | The crafting route window: the cheapest way to level a profession at today's prices |
| `/apg share` | Share the guide you are on with your party, or stop sharing (beta) |
| `/apg gear` | The options at **Item Score**: the stat weights behind the item score |
| `/apg finder` | The Gear Finder tab on the character panel: upgrades in the dungeons you run |
| `/apg talents` | Save your class's talent trees, as the game has them, for checking the Talent Advisor's builds |
| `/apg ssf` | Solo Self-Found on or off |
| `/apg setup` | Run the first-time setup again: your guide, its features and your dungeons |
| `/apg target` | Target and mark the step's next active target (put it in a macro) |
| `/apg useitem` | Use the first active item |

`/pathfinder` does the same thing. There is deliberately no `/aegis` —
that belongs to another addon in the Aegis suite.

The objectives panel is the addon's main window, so a bare `/apg` opens it, and
it opens with the client. Escape doesn't close it, so clearing a target in a
fight leaves it where it is; its ✕ does. The Aegis shield on the edge of the minimap does the
same on a click; right-click it for the options window, and drag it to move it
round the minimap. The options window's **Appearance** page can hide it, as can
`/apg minimapbutton`.

The options window can be resized from its bottom-right corner, wider or
taller, and keeps the size; `/apg resetpanels` puts it back. It lists its
pages down the left, after Zygor's from Appearance on:

- **Route**: race and route pack.
- **Dungeons** and **Filters**.
- **Appearance**: server theme, switch colours, window scale; the guide
  window -- *Lock window* and *Transparency* (also in its ≡ menu), how
  see-through Transparency makes it, the guide browser's opacity, the steps'
  text size, the progress bar, growing upward; hiding the guide in dungeons
  and raids or in combat; the minimap button. See **The guide window's
  look**, below.
- **Step Display**: how many steps focus mode shows, skipping hearthstone and
  flight path steps, what comes between guides (follow-ups, custom zones,
  class quests), and party sync. See **Step Display**, below.
- **Automation**: quests (the guide's or all of them), flights, buying,
  selling greys and repairing -- see **Automation**, below.
- **Action Buttons**: the Active Items, Active Targets and Macros windows and
  quest icons; which way the windows grow and their size; which buttons they
  show; the target buttons' raid marker -- see **Action Buttons**, below.
- **Navigation**: waypoints and arrows.
- **Maps**: revealing the world map, the step's places on it, an ant trail to
  the waypoint, and the rares near your level -- see **Maps**, below.
- **Gear** and under it **Item Score** (the stat weights).
- **Extras**: the addon's routine chat lines, detailed reputation gains,
  level-up announcements, and the Talent Advisor -- see **Extras** and
  **Talent Advisor**, below.
- **Maintenance** (rescan, error log, setup) and **About** (version and
  credits).

The Behaviour page those settings were on is gone; each kept its value.

## What it does

**Routes.** Pick a route pack on the options window's **Route** page: Optimized (Joana's
routes), RestedXP, or RXP Hardcore. (Kamisayo Speedrun, a Horde Warrior pack, is
hidden until its guides are added; a character that had it moves to RestedXP.)
A preview underneath shows the route your race takes under it, as many legs as
the page has room for: a taller window shows more of it. Your race's
starting zone is selected for you, and all races merge into a shared route
after level 12.

**Tabs.** Up to eight guides open at once, one per tab. The bar shows up to
four at a time — fewer on a narrow panel — and arrows either side (or the
mouse wheel over the bar) scroll through the rest; the tab you are on is
always brought into view. The first is your main route — what the addon
advances along on its own. A guide picked in the guide browser opens in a tab
of its own -- or its tab, if it has one -- so the guide you are reading keeps
its tab and its place; picking a guide never changes your route pack. When a
class quest or other branch guide finishes, it closes and hands back to the
first tab, which keeps its guide unless you have out-levelled it; then it
moves on to that guide's next one at your level. Each tab remembers its own
place. A badge on each tab says what the guide is: XP
for leveling, PF for a profession, DG for a dungeon, CL for a class quest, HC for hardcore. Every tab can be closed; close them all and the
panel waits, empty, for you to pick one.

**The guide browser.** The `+` on the tab bar, or **Guide menu** in the guide
window's ≡ menu, opens it, laid out like Zygor's. Down the left: a search box
and the categories -- **Leveling** (Optimized, RestedXP, RestedXP Hardcore,
the zone guides by continent, and the custom zones), **Dungeons**, **Class
Quests**, **Professions** and **Favorites** -- with Reputations, Dailies,
Events, Gold, Pets & Mounts and Titles greyed as coming soon. A long folder
is split by level. Point at a guide and the right of the window shows it: a
picture, its levels, how far through it you are, and **Open in a new tab**. The picture is the game's art: a zone guide's zone
on the world map with every area explored, the loading screen Turtle WoW shows
on the way into a dungeon, a
class quest's crest and spell, a profession's icon. Pointing at a guide also
puts up a star, which keeps it in Favorites, and an arrow, which opens it.
The list's ⋮ colours guides by how they suit your level (grey once you have
outlevelled one, green, then yellow, orange and red the further short of it
you are), ticks the ones you have finished, hides finished and outlevelled
ones, and stars the suggested ones.

**HOME** is four panels -- the guides you opened last, suggested guides (the
route's next leg, class quests, ticked dungeons and custom zones at your
level, each with why), the time you have spent at each level, and the gold
you have earned today and this week -- and the ⋮ hides any of them. Time and
gold are counted while you play, from the first time a character runs
0.21.0; gold earned is every rise in your money, with nothing taken off for
spending. **CURRENT** is the guides open in the guide window; **RECENT** the
last 30 you opened, by category. The window can be resized from its corner
and remembers where you left it.

**The guide window's menu.** The ≡ chip at the top left of the guide: **Guide
menu**, **Setup wizard**, **Lock window** (it cannot be dragged or resized
until unlocked), **Transparency** (a see-through panel), **Reset window**,
**Reload** and **Settings**.

**Dungeons.** Toggle which of 15 dungeons you intend to run. Opting in promotes
their setup and prerequisite steps to mandatory; opting out hides them. A blue
dot marks the dungeons the guide you are currently on actually has steps for.
Under them, **Turtle WoW's own**: Frostmane Hollow, Windhorn Canyon, Dragonmaw
Retreat, Stormwrought Ruins, Crescent Grove, Gilneas City and Hateforge Quarry.
No route guide has steps for these; ticked, their dungeon guides can be offered
along the way. These ticks are for the route: the Gear Finder looks in every
dungeon at your level, ticked or not.

**Dungeons along the way.** Switch on *Offer dungeon guides along the way*, on
the same page, and finishing a guide asks **Where next?** with the dungeon
guides of the ticked dungeons that fit your level listed under the custom
zones -- up to four, lowest first. A dungeon fits as a custom zone does: you
are inside its level range or one short of it, below its top, and have not
finished its guide. Pick one and it opens in a tab beside the route. It is off
to start with, and Solo Self-Found holds it off.

**A dungeon at your level.** Reach the middle of a ticked dungeon's levels -- The
Deadmines (17-24) at 21 -- and a small window offers its dungeon guide: open it
in a tab beside the route, or not now. Each dungeon is offered once, whatever
the answer, and not at all once you are past its top level, have finished its
guide, or already have it open. It covers the dungeons the setup asks about
(ticking dungeons there is what switches it on for you); Turtle WoW's own stay
with *dungeons along the way*, since they start ticked. It looks when you level
up, when you log in and when you finish the setup. *Offer a dungeon's guide at
the middle of its levels*, on the Dungeons page, turns it off; Solo Self-Found
holds it off.

**Dungeon guides.** The guide browser's **Dungeons** category has a guide for each
dungeon, for your side: every leveling dungeon from Ragefire Chasm to
Blackrock Depths, and Turtle WoW's own -- Frostmane Hollow, Windhorn Canyon
(new in patch 1.18.1), Dragonmaw Retreat, Crescent Grove, Stormwrought Ruins,
Gilneas City and Hateforge Quarry. Pick one and it:

- goes round the towns that give the dungeon's quests, picking each up, and
  does the quests before them on the way -- the Alliance's Sunken Temple
  starts in Stormwind and goes by the Hinterlands, Un'Goro, Feralas, Tanaris
  and Ratchet;
- puts the arrow on the entrance, with how to find it;
- inside, has you do what each quest wants, and picks up and hands in what is
  given and taken there;
- on the way back, hands in the rest, and picks up what they lead to. A chain
  that needs another visit -- Uldaman's necklace, Gnomeregan's formulas --
  gets another run.

A trip to a town is only for those its quests are for: a Warrior's Shadowfang
Keep guide never goes to Darnassus, whose one quest is a Priest's, Mage's,
Warlock's and Druid's, and theirs goes only once the quest before it is done.

A quest whose chain starts somewhere the guide does not go (another dungeon's,
a class chain in a far zone) is in it but optional: it shows once you have
the quest before it done. Class quests show only for that class. Quests given
where the guide does not go are named in a note at the top. Frostmane Hollow
has a Horde guide too, for cross-faction groups: its one quest is given and
taken inside.

Which quests belong to a dungeon comes from InstanceJournal, a Turtle WoW
addon that lists every instance's quests, and the quests themselves from
pfQuest-turtle, patch 1.18.1's included (`Tools/build/build_dungeon_guides.py`).

**Boss steps.** Inside, a dungeon guide has a step for each boss, in the order
InstanceJournal lists them, and a quest that needs a boss dead comes straight
after that boss's step. Each step says what the fight does, then what to watch
for as each role:

- **Tank** (blue): where to face him, what to pick up, when you lose threat;
- **Healer**: who takes the damage, what to dispel or cure and which classes
  can;
- **Damage** (red): what to interrupt or kill first, when to stop or move.

Hover the step for its lines, or see them under it in focus mode. Options ->
Dungeons -> **My role in dungeons** shows only your role's line: All roles
(to start), Tank, Healer or Damage. A boss's step ticks itself when the combat
log says he dies; a fight with several bosses ticks on the last (the Seven in
Blackrock Depths on Doom'rel). A rare boss's step says he is not always there
and can be passed over. The arrow does not point inside a dungeon.

What each boss does comes from InstanceJournal's abilities for Turtle WoW's
own and from CMaNGOS -- its spells and its scripts -- for the rest
(`Tools/build/build_dungeon_bosses.py`); the notes are written in
`Tools/build/dungeon_tactics.py`. Some Turtle WoW bosses have no data
anywhere yet -- Dragonmaw Retreat, Crescent Grove, Stormwrought Ruins, Gilneas
City, Hateforge Quarry, most of Windhorn Canyon, and those Turtle added to
older dungeons -- and their steps say "Pathfinder has no notes on this fight
yet." They still tick themselves.

**Class quest guides.** The guide browser's **Class Quests** category has a guide for each of
your class's quest chains -- the warlock's Voidwalker, Succubus, Felhunter,
Felsteed, Infernal and Dreadsteed; the druid's Bear Form, Aquatic Form and
Cure Poison; the hunter's Taming the Beast and Rhok'delar; the paladin's
Redemption and Charger; the shaman's totems; the priest's racial spells;
Turtle WoW's own, the level-60 ones and the chains that need a dungeon or a
raid among them. It lists only your class's, and only those your race has a
way through. Each race gets the chain that starts at home: an Undead
warlock's Voidwalker is Carendin Halgar's in the Undercity, an Orc's Gan'rul
Bloodeye's in Orgrimmar, and a Goblin's starts with Dabbling In Darkness on
Blackstone Island. Turtle WoW's High Elves and Goblins go the way of the race
they share it with -- a High Elf paladin's Redemption is the Human's, after
Paragon of Light -- unless they have their own (a High Elf hunter's taming is
Damilara Sunsorrow's in Alah'Thalas). Below level 20, a quest given both in
the starting zone and in the city is picked up in the starting zone, where you
are: a Human warrior's A Warrior's Training from Lyria Du Lac in Goldshire, a
Horde warrior's Veteran Uzzek from Razor Hill's trainer. A guide picks up each quest, sends the
arrow where its objectives are (a dungeon's door, for one inside), hands it
in, and does what one quest needs of another first: the Charger's horse feed
before the spirit's quest. It ends with the chain's last hand-in, so it
finishes by itself.

**Attunement guides.** The quests that open each raid and dungeon, a guide
each, per side, under the guide browser's Dungeons category in **Attunements
and keys**, with an orange AT badge:

- **Raids:** Molten Core (Attunement to the Core), Onyxia's Lair (the
  Alliance's Drakefire Amulet, the Horde's Blood of the Black Dragon
  Champion), Blackwing Lair (Blackhand's Command), Naxxramas (The Dread
  Citadel) and Turtle WoW's own: Emerald Sanctum (Into the Dream I to VI),
  Lower Karazhan Halls (The Key to Karazhan I to X) and Tower of Karazhan
  (the Scepter of Medivh).
- **Dungeons:** Upper Blackrock Spire (Seal of Ascension), Scholomance (the
  Skeleton Key), Blackrock Depths' inner city (the Shadowforge Key) and
  Turtle WoW's Karazhan Crypts (the Alliance's Mystery of Karazhan, the
  Horde's Depths of Karazhan).

Each is built the way the class quest guides are: every quest picked up, done
and handed in, the arrow on whoever gives it and where its objectives are,
and the way into the dungeon or raid a part is done in. Raids come first in
the folder, by level; each says Raid or Dungeon, and **Attuned** once its last
quest is handed in (Naxxramas by any of its three versions). RestedXP's
Onyxia Attunement and Scholomance Key follow, saying RestedXP. Home suggests
an attunement you have started, and the first you can start. Its picture is
the loading screen of what it opens, where the addon has one.

**A class quest at your level.** Reach the level a class quest starts at and a
small window, like the dungeon's, offers its guide: open it in a tab beside
the route, and when it is done you are back on the route; or not now. Each is
offered once, and not at all when your route has it already (a leg still to
come picks up one of its quests), when it is done (its last quest handed in, or
its guide finished), more than five levels after it (most likely done before
Pathfinder could see; the Class tab still has it), or, for a chain with a
dungeon, a raid or an elite in it,
unless you play in a group -- Solo Self-Found is solo. With a dungeon to offer
at the same level, the dungeon's window comes first and the class quest's when
it closes. It looks when you level up, when you log in and when you finish the
setup; *Offer class quests at their level*, under **Step Display**, turns it off.

The chains come from pfQuest, pfQuest-turtle and CMaNGOS' quest table: which
quest follows which, which races each is for, and what one gives that another
needs (`Tools/build/build_class_guides.py`). The raid tiers' armour exchanges
-- Zul'Gurub's, Ahn'Qiraj's, Naxxramas', the dungeon set's upgrade -- are not
class quests in that sense, and have no guide.

**Filters.** Solo or group mode, and whether Auction House steps appear.
Defaults follow the route pack you chose. They act on every route pack: in
Solo mode the Optimized and zone guides leave out elite and group quests, and
the quests that follow on from them; with Auction House steps off they leave
out quests that need an item most players buy there. Changing a filter keeps
your ticks on the steps they were on: a step is known by its place among all
the guide's steps, not only the ones the filters keep.

**Solo Self-Found.** For a character that plays alone, never trades and never
uses the Auction House: group quests, dungeon quests and every step that trades
or uses the Auction House are left out. While it is on, the group mode and
Auction House switches and the dungeon chips are held off and can't be clicked
-- in the options and in the first-time setup -- and the Gear finder looks in
no dungeons. What they were set to is kept, and comes back when it goes off.
It is a switch under **Filters**, a choice in the first-time setup, and
`/apg ssf`.

**First-time setup.** The first time the addon loads on a character, a short
setup asks three things, as RestedXP does:

1. **Your guide**: Optimized (quest-optimized 1-60, every race), RestedXP
   Speedrun, or Hardcore Survival. Only guides with a route for your race are
   offered.
2. **Features**: Auction House steps, Solo Self-Found, group quests, dungeons.
3. **Dungeons** (when dungeons are on): the dungeons your faction can run, with
   level ranges and how many quests each adds to your route, plus
   **Recommended**, **All** and **None**. A quest counts only if the guide you
   picked takes you all the way through it on your race's route: sends you to
   pick it up, has you do first whatever the server wants done before it, and
   sends you to hand it in. A quest whose chain runs through another dungeon
   counts once that one is ticked too -- "1 quest (+4 with Deadmines)" for the
   Stockade until the Deadmines is. **Recommended** picks the dungeons that add
   five quests or more, for the guide you picked: RestedXP and RXP Hardcore
   take you through many, the Optimized guides through few, so each has its
   own.

It starts from what the character already has, so an existing character can
finish it without changing anything, and it keeps your place in your guide
unless you pick a different one. Where the chosen guides do not mark a kind of
step yet, it says so. Closing it keeps your current settings. Run it again with
`/apg setup` or **Run setup** on the options window's **Maintenance** page.

**Your route decides what comes next.** Finish a guide on your route and the
next is the route's next leg for your guide pack and race -- RestedXP, for
one, sends the Eastern Kingdoms races through Redridge at 19 and Night Elves
through Darkshore. A guide you picked off the route goes on where its own
next guide says.

**Custom zones between guides.** When you finish a guide and a custom zone
fits your level, a small **Where next?** window asks whether to carry on with
the route or take the custom zone. Finish Redridge Mountains (27-28) at 28, for
example, and it offers the next Optimized guide or Northwind (28-34). A custom
zone opens in a tab beside the route, with the route's next guide waiting in the
first tab. Finish the custom zone and it asks again: back to the route, at the
guide for the level you are by then, or on to the next custom zone that fits. A
zone fits when you are inside its level range or one short of it, below its top,
and have not finished it; with none that fit, nothing is asked. Closing the
window carries on with the route. The options window can switch it off (*Offer
custom zones between guides*, under **Step Display**). The custom zones are also under the guide
list's **Custom** tab at any time.

**Moonwhisper Coast (52-60)**, which came with patch 1.18.1, has a guide for
each side: the draenei of Moro'gai Village for both, Sunsworn Camp and Narvalis
Point for the Alliance, Moonhoof Village and Moonhoof Retreat for the Horde,
with the Horde's trips to Azshara and Mulgore and back where its stories go.
It is written from quest data players have gathered, not from a server's
database, and that data is still growing: quests nobody is on record as giving,
and the ones that start elsewhere, show only once they are in your log. Its
bosses, Price of Betrayal and Draenethyst Recovery are group quests: in Solo
mode they are left out, with what follows them -- for the Horde, the Moonhoof
story from Shade Mother on.

**Professions.** Ten 1–300 routes with trainers, craft counts, reagents and
recipe sources, tracked against your actual skill level. See below.

**Shopping list.** On a guide with reagents the panel's footer carries a
**Shopping list** button (or `/apg materials`). It pops out beside the guide
with what you need and what your bags already hold — `12/40 Peacebloom` —
short lines in gold, covered ones dimmed, updating as your bags change. The tab
at the top switches between **This step** (the craft you are on or coming up
to) and **Whole route** (everything still ahead, counted from where you
actually are rather than from step one, so it is the number you want at the
auction house).

With [Aegis: Exchange](https://github.com/Torchlite-bit/Aegis_Exchange)
loaded, **Send to Exchange** at the bottom of the list (or `/apg exchange`)
puts each craft still ahead on Exchange's Crafting tab, where its shopping
list prices every line at the auction house. It stays in step: finish a craft
and it leaves Exchange too; finish the route and the list is gone. **Remove
from Exchange** takes it all back out. Recipes you captured in Exchange
yourself are never touched — if one shares a name with a craft on the route,
it is set aside while the route's stands in for it and put back afterwards.
Exchange's demo mode has to be off.

**Cheapest crafting route.** **Cheapest route** on the shopping list (or
`/apg craft`) opens a window that works out the cheapest way from your skill to
300 in a profession at today's prices, as
[CraftRoute](https://github.com/Kitymeowmeow-turt/CraftRoute) does — without
needing CraftRoute. It shows the total, what it is made of (reagents and
recipes, and beside them what a merchant would pay for the leftovers -- never
taken off the cost, and never used to choose the route), and a row per recipe: the
skill band, how many crafts, the reagents and what the step costs. Hover a row
for how the recipe is learned, what to buy and what gets made first.

- **Prices** come from merchants (built in) and the auction house: press **Scan
  prices** with the auction house open and it searches for each reagent and
  recipe the profession could use, the route's own first, keeping every
  listing so forty of something is priced as forty. With Aegis: Exchange
  loaded its prices are used too. A reagent nobody has a price for is never
  counted as free: the route avoids it, or says it has no price.
- **Your recipes**: open your profession window once and the recipes you know
  cost nothing to learn; drop and reputation recipes are only used once you
  know them.
- **Load as guide** turns the route into a guide, *Alchemy (cheapest route)*
  and so on, in the Professions list: the authored guide's trainers, level and
  rank steps (and the Expert cookbook and Artisan quest for Cooking) placed
  where your skill cap runs out, with the planned crafts in between. It is kept
  between sessions and replaced when you plan again.

It plans Alchemy, Blacksmithing, Cooking, Enchanting, Engineering,
Jewelcrafting, Leatherworking, Survival and Tailoring, from 1,095 recipes whose
thresholds, reagents and sources come from CraftRoute's data (with its
author's permission); the planner itself is this addon's own.

**Active items and targets.** Two small windows, as RestedXP has, hang under
the guide. **Active Items** has a button for every item the guide wants you to
use — the current step's, and those for any quest in your log that is not done
yet. **Active Targets** has a button for whoever the step wants you to find: the
quest's giver or hand-in, what it wants killed, what drops what it wants
collected, the trainer a profession step sends you to. Click one to target it
and mark it for what the quest wants with them (see **Quest icons**).
`/apg target` takes the nearest of the step's targets, then the next one out
each time you press it, and back round -- so three Crocolisks are three presses,
not the same one three times. A macro with just that line works like
RestedXP's; clicking a target's button again moves on the same way, to the next
one by that name. Both also have key bindings under
*Aegis: Pathfinder* in the key bindings menu. Targets come from pfQuest's
database, so quest steps need pfQuest; profession steps name their trainers
themselves. What the quest wants killed or looted is looked for where the step
is: Crocolisk Hunting in Loch Modan targets Loch Crocolisks, not the likelier
crocolisks of the Wetlands. With none there, it is those where you are, then
everyone. Either window can be dragged anywhere, or switched off under
**Action Buttons** in the options.

**Action Buttons.** The options window's page for those windows:

- **Layout.** Which way Active Items and Active Targets each grow -- right
  (the first button at the left), left, up or down, a row or a column. A
  window you have dragged grows from the matching corner, where you left it;
  until then it hangs under the guide. Let go of one near another, or near
  the guide, and it snaps flush against it, side by side or one under the
  other. **Button size**, 60% to 150%, on top of the window scale, for the
  three small windows. Close the guide and the three go with it; when the
  guide hides itself in combat or a dungeon, the Appearance page's switches
  say whether they go too.
- **Buttons to show**: **Quest items**, **Talk to NPC** (talking and
  interacting), **Kill enemy** (killing and looting), and **Delete cheapest
  item**. Leaving one out takes its buttons out of the window; the macros,
  the key bindings and the quest icons still have them.
- **Delete cheapest item.** With your bags full, a button after the items
  offers the cheapest thing in them to make room: a grey first, then
  whatever a vendor pays least for, by the whole stack. It never offers the
  guide's items, your hearthstone or what no vendor buys (quest items), and
  asks before deleting anything that is not grey. A quiver's or soul bag's
  empty slots are not room. 1.12 does not tell an addon what a vendor pays,
  so the price is ClassicAPI's -- the server's own, Turtle WoW's items too --
  or, failing that, the CMaNGOS database's (SellPrices.lua). A grey neither
  knows the price of is offered only when no grey with a price is in your
  bags; it no longer counts as worthless.
- **Mark whoever the target buttons target** (on). Off, the buttons only
  target; quest icons still mark by themselves.

**Quest icons.** Mouse over or target anyone a quest wants and the right raid
marker goes on them by itself, as RestedXP's Quest Icons do:

| Marker | Means | Who |
|---|---|---|
| Star | Talk | Gives or takes the quest; the trainer or vendor a profession step names |
| Square | Interact | A friendly NPC the quest's objectives involve |
| Skull | Kill | An enemy the quest wants killed |
| Cross | Loot | An enemy that drops what the quest wants collected |

It covers the current step and every quest in your log: what an unfinished
quest wants killed or looted, and who takes a finished one. It marks only
while a guide is open: with no guide, or the guide closed, nobody is marked
(hidden in combat or a dungeon by the Appearance page, it still counts as
open). It never replaces a
marker already there (a party member's, say), skips players and corpses, and
stays out of raids, where markers belong to the leaders. Someone marked for
killing who turns out not to be attackable gets a square instead. Quest-log
marks need pfQuest and ClassicAPI (which gives the log's quest ids); without
ClassicAPI only the current step is marked. The options window can switch it
off, under **Action Buttons**.

**Macros.** A third small window, **Macros**, holds two real macros the addon
writes into your character's macro book and keeps up to date: **AegisTarget**,
which is `/apg target` -- the nearest of the step's targets, then the next one
out each press, marked -- and **AegisItem**, which uses the quest item the step needs
and wears that item's icon. Drag either tile onto an action bar once; from then
on the macro follows the guide by itself, step after step. Clicking a tile does
what its macro does. They are made the first time there is something for them
to do, use two of your 18 character macro slots (the window says so if none are
free), and are never rewritten while the macro window is open. The options
window can switch it off, under **Action Buttons**, which also stops the macros
being made or updated.

**Sharing a guide with your party (beta).** Playing a guide with someone else
is awkward when neither of you can see which step the other is on. In a party,
click the party icon at the right of the guide panel's step row (or
`/apg share`) and confirm; everyone in the party running Aegis: Pathfinder gets
a popup, and accepting opens the guide in a new tab. From then on:

- Under the step, each member sharing it is listed with their progress on it —
  `Ghanndraine [3/6]`, `[done]` — or which step they are on, if another.
- A step you have finished waits until everyone sharing has finished it too,
  then the guide moves on for all of you. Nobody is pulled back to someone who
  is behind: you wait where you are. The skip arrow still moves you on alone.
- The icon is gold while nobody has accepted yet, lit once someone has, and a
  second click stops sharing. Leaving the group leaves the share.

Steps are matched by what they are (the quest, or the step's title), not by
number, so characters whose guides differ by a class or race step still line
up; a partner on a step you do not have is shown but cannot hold you. The
confirmation has a "Don't warn me again" box.

**Server themes.** **Server theme**, on the options window's **Appearance**
page, recolours the addon:
Turtle WoW is the original green, OctoWoW purple, RavenCraft grey, Capybara
Paradise tan, Aegis red, and Day (amber, lighter panels) and Night (moonlight
blue, deeper panels). It applies at once, arrow and progress bars included, with
no reload. Themes are colours only. Every theme is checked for readability:
accents and text keep a WCAG contrast of at least 4.5:1 against the panels.
Switches take the theme's colours, RavenCraft's a near white when on so it
does not read grey on grey. **Red and green switches**, on the same page, makes
every switch green when on and red when off, whatever the theme.

**Window scale.** The same page has a **Scale** slider, 60% to 150%, for every
Pathfinder window at once -- the guide, the options, the shopping list, the
Active Items and Targets windows and the rest. In focus mode the guide's step
title wraps to the window's width, so dragging the grip narrower shows the whole
title on more lines instead of cutting it off. While you drag the slider only
its number moves; the windows take the new size when you let go, so the
options window does not shrink out from under the cursor.

**Automatic advancement.** Accepting, completing and turning in quests, binding
a hearthstone, and collecting tagged items all resolve themselves. So do travel
steps, once a waypoint provider is active, and on reaching the zone or subzone
they name -- "Travel to Westfall" by any road or by flight. An optional travel
step, RestedXP's way to a place rather than a stop, is passed once you are in
the next step's zone or have done the next step, as RestedXP does. Quests
under a collapsed header in the quest log are out of the client's sight; when
one of the guide's is, the headers are opened so the guide can follow it. A note that has you pick something
up for a quest -- Bingles' four tools in Loch Modan, one note each -- ticks
when the item is in your bags, and one you pick up ahead of its note ticks
when the guide gets there. A step the addon can finish for you
has a small ⟳ inside its circle, so you know when not to reach for it; an
empty circle is one only you can tick, and a filled one is done.

**The guide window's look.** On the options window's **Appearance** page:

- **Transparency**, and under it **Guide window opacity** (20% to 100%, half
  to start with): how much of the game shows through the guide's panel; its
  text stays solid. **Guide browser opacity** (40% to 100%) fades the whole
  guide browser.
- **Step text size**, 80% to 140%: the steps' titles and notes, and the rows
  that hold them.
- **Show the progress bar**: the 4px rule of how far through the guide you
  are. Off, the steps move up into its place.
- **Grow upward from where I put it**, for a guide at the bottom of the
  screen: its bottom edge stays where you left it, and it grows up when a
  step needs more room. (Zygor flips its viewer upside-down; here the header
  stays on top.)
- **Hide the guide in dungeons and raids**, with **Show it again when I
  leave** under it (on); **Hide the guide in combat**, with **Hide the action
  buttons in combat too** under it. Hidden so, the guide still counts as open;
  only its ✕ closes it.

**Step Display.** On the page of that name:

- **Steps shown in focus mode**, 1 to 5: the step you are on and the ones
  after it, under its objectives. Overview still shows the whole guide.
- **Skip setting my hearthstone** and **Skip discovering new flight paths**:
  those steps are left out of the guide. A later step may still say to hearth
  or fly there; it is not rewritten.
- **Party sync** (on): the party icon on the step row and invitations from
  your party. Off, the icon goes and invitations are declined without a
  popup. **Ask before inviting my party** sits under it.

**Automation.** The options window's **Automation** page, as Zygor's:

- **Quests.** *Accept and turn in the guide's quests*, and under it *All
  quests, not only the guide's* (off to start with) and *Pick the guide's
  quest from an NPC's list* (on). All quests takes every quest an NPC offers
  and hands in every finished one, but never a grey quest, and it leaves two
  places in your quest log for the guide's. With picking from a list off,
  the quest you open is still accepted and handed in; the list is yours.
  *Track quests automatically* is here too.
- **Travel.** *Take the step's flight when I open the flight master's map*
  (off to start with). "Fly to Orgrimmar" flies to the town; "Fly to
  Westfall" to the zone's flight path, only when you know one there -- with
  two, it asks you to pick rather than guess.
- **Inventory.** *Buy what the step says to buy, at its vendor* (on): open
  the vendor on a buy step that names its item and it buys as many as you
  still need, no more than the vendor has or you can pay for. A **Sell
  greys** button on the vendor window (on), and *Sell greys automatically*
  as the window opens (off); either says how many went and for how much.
  *Repair automatically*: not at all (to start with), or with your own
  money. 1.12 has no guild bank, so there is no guild repair.

Hold Shift as you open a quest giver, a flight master or a vendor and none
of it happens.

**Maps.** What the addon draws on the world map and the minimap, on the
options window's **Maps** page. All of it on the zone's own map, never a
continent's:

- **Reveal the whole map** (on): the places you have not been, drawn a little
  dimmer than the ones you have, from pfUI's reveal data (MapOverlays.lua).
  It stands down while pfUI's own map reveal is on, and for Cartographer or
  MetaMap's fog of war module.
- **Show the step on the map** (on): the step's quest givers, hand-ins and
  kill areas -- and the creatures that drop what it collects -- from
  pfQuest's database, as icons and spots on the zone you are looking at, with
  their names when you mouse over them; and the place the step's note gives.
  Without pfQuest, only the note's place.
- **A trail from me to the waypoint** (on), and its **Style**, dots or dashes:
  in the theme's colour, marching toward the waypoint, when you and it are in
  the zone the map shows. On the minimap too when Astrolabe is loaded
  (TomTom-TWOW brings it): eight dots from you toward it, as far as the
  minimap reaches. Without Astrolabe there is no minimap trail -- 1.12 alone
  can't say how many yards the minimap shows.
- **Rare creatures near my level** (off), with **Icon size** and **See-through
  icons** under it: every place a rare or rare elite within four levels of
  yours can spawn, from pfQuest-turtle's database (Rares.lua, about 440 of
  them). Whether one is up right now, 1.12 can't say.

**Extras.** On the options window's **Extras** page:

- **Show Pathfinder chat messages** (on). Off, the routine lines stay out of
  your chat: the load message, the login's progress summary, flights taken,
  what was bought, sold, repaired or deleted, upgrades found and put on, a
  branch or starting zone handed over, follow-ups skipped. Errors, warnings
  and replies to what you click or type -- a button, a slash command, Rescan
  -- still show.
- **Show detailed reputation gains** (off). When a reputation goes up, a line
  after the client's own says where it stands and how far to the next rank:
  "Stormwind +25: Honored 4,350 / 12,000, 7,650 to Revered". A faction under
  a header you have closed on the reputation panel is found too, and the
  header is closed again.
- **Announce level-ups to:** Emote (ticked to start with), Party chat and
  Guild chat (each off until ticked). The emote reads "<you> Pathfinder: I
  just leveled up from 22 to 23! (2 hours 1 minute)"; party and guild get
  "Pathfinder: I leveled up from 22 to 23! (2 hours 1 minute)". The time is
  how long you spent at the level just left, from the guide browser's level
  tracker, and is left out for a level it did not count from the start (the
  one you were on when you installed the addon). Nothing goes to a party or
  guild you are not in.
- **Talent Advisor** (on): marks where your points go on the talent window --
  see **Talent Advisor**, below. *Build to follow*: levelling, then your spec
  (to start with), your class's levelling build, or any spec's build at 60.
  A Warrior or Paladin can level as **Protection** instead, and a Druid as
  **Bear**: each on its own ("Warrior Protection leveling"), or then your spec
  at 60 ("Protection leveling, then Fury at 60").
  *Name the talent to take in chat when I level up* (on). *Point out a
  talent point: a card when I level up, and the talents button lit* (on).
  *Open the talent window*.

**Talent Advisor** (`TalentAdvisor.lua`, `TalentWindow.lua`,
`TalentModern.lua`). Which talent each point goes to, on Blizzard's own talent
window (and pfUI's skin of it), and on Modern Spellbook's:

- **The build.** Your class's levelling build until 60 -- a point a level from
  10 -- then your spec's: the spec picked on the Item Score page, or the one
  your talents lean to. At 60 it keeps the levelling build while every point
  is on it, and once all 51 are spent says your spec's build is ready for
  when you respec; after a respec it follows your spec's. Pick another on the
  Extras page or from the strip above the talent window. Some classes have
  another levelling build: Protection for a Warrior (with a shield, Shield
  Slam at 30 and Concussion Blow at 40) or a Paladin (Holy Shield at 30,
  Bulwark of the Righteous at 41), and Bear for a Druid (Feral Charge at 28,
  Leader of the Pack at 40).
- **On the window.** Each talent of the tree shown has a badge with the points
  the build puts there: green while some are still to take, a tick once you
  have them all, amber "+N" for points you have that the build does not put
  there. The talent your next point goes to has a gold ring and "NEXT", and
  its tree's tab a gold dot and a gold light; the window opens on that tree.
- **The strip** above the window: *Following* and the build, as a menu, and a
  card for the next point: the talent's icon, "Take Deep Wounds" and "Rank 3
  of 3 in Arms · 1 point to spend" ("Next: Impale" and "... · at level 30"
  with none to spend). Under it, how many points are off the build.
  Off the build it carries on from the build's closest point you can take; it
  never says to respec.
- **Off the window**, so a point is not missed: a card on a level up, "Level
  30: a talent point", "Take Shield Slam (rank 1 of 1) in Protection.", with
  *Open talents* and *Later* (gone by itself after half a minute, and not
  while a talent window is open); and the talents button lit gold with the
  points to spend on it. Both go with *Point out a talent point* on Extras.
- **On Modern Spellbook's window** ([Modern Spellbook](https://github.com/lioryx/ModernSpellBook)
  by lioryx, with its talents on, `/msb talents`): the same badges, ring and
  NEXT on every tree at once, and "NEXT POINT HERE" by the next point's tree's
  name; the strip over its window with the build, the card and three buttons.
  While it shows a plan, the marks step aside.
  - *Plan to my level* (21 points at 30) and *Whole build as a plan* save the
    build in Modern Spellbook's plan list, as "Pathfinder: Protection leveling
    to 30" or "Pathfinder: Protection leveling", and make it the plan its window
    shows: its *Apply* learns the points. A plan is the ranks you have, then
    the build's next points, so points already off the build don't stop it
    applying. Its list holds 20; full, the plan is still shown but not saved.
  - *Share* opens **Share and plan**: the build as Modern Spellbook's share
    string (`MSB1-WARRIOR-…`), selected to copy, for its *Import* or a friend;
    *Follow a shared build* takes such a string, yours or anyone's, and the
    advisor follows it -- the tree with the most points first, a row at a
    time, a prerequisite before what needs it -- as **Shared build** in the
    menu. Another class's string, or one that can't be taken so, is refused
    with why. And the two plan buttons, with their points.
- **The tooltip** of a talent adds "Pathfinder: Warrior leveling puts 3
  points here." -- ": done." once you have them, "; you have N" past them --
  and "Your next point goes here."
- **In chat**: on a level up, "Level 22: a talent point to spend. Take Deep
  Wounds (rank 3 of 3) in Arms."; at 60 with all 51 spent on the levelling
  build, once, "All 51 points are spent. Your Fury build is ready for when you
  respec: pick it under Following on the talent window to see it."
- **Checked first.** Each build is checked against the tree your game has:
  every talent there, no more ranks than it has, each point learnable in its
  order, 51 in all. One that does not fit says why, in the strip and once in
  chat ("The Warrior leveling build doesn't fit your talent tree (it has no
  Master Strike), so the Talent Advisor won't follow it."), and is not
  followed.
- It only marks and names; it never spends a point.

The builds (`TalentBuilds.lua`, written by `Tools/build/talent_builds.py`) are
made on Turtle WoW's own trees: `/apg talents` saves your class's trees --
every talent's place, ranks, prerequisites and tooltip -- for your account.
Once on a character of each class (a level-1 one will do) and all nine are in
the saved settings file,
`WTF\Account\<account>\SavedVariables\Aegis_Pathfinder.lua`; again after a
game update that changes the trees.

**One step, or all of them.** The panel opens on the step you are on and
nothing else, with its note in full and a meter underneath: a line for each
thing the quest wants killed or collected, with its count and a bar filled to
it -- Crocolisk Hunting's 4 of 5 meat is a bar four fifths full, with its
skins on a bar of their own. The step's accent bar down the left runs on
beside them, so they read as part of the step. The expand button in the header swaps
that for the whole guide when you want to look ahead. The panel sizes itself
to what it shows; the grip in its corner sets the width, and how tall it may
grow.

**Your place in the guide.** The arrows beside the step number move a step
back or skip one, and they change what is ticked as they go. Right-click them
to get back: after clicking round, a right-click on the arrow that points at
where you were takes you there and puts back every tick (and quest completion)
the arrows changed on the way -- a quest you finished in the meantime stays
finished. Without clicking round, a right-click takes you to where the guide
would open: the quest your log shows work at, else the first step not done.
If your place is the other way, it says which arrow to right-click.

**Hints beside the guide.** Hovering anything on the guide -- the arrows, a
tab, a step -- opens its hint beside the guide, not over the steps: on its
right when the guide is on the left of the screen, on its left when it is on
the right, level with what you hover. With no room beside it, the hint goes
under the guide in the top half of the screen and over it in the bottom half.

**Where a guide opens.** At the quest your log shows work at. The notes, runs,
flight paths and hearths before it can't be read from the log, so each counts
as done when the next quest after it is one you have picked up or finished;
otherwise the guide went straight back to its first note. One before a quest
you have not picked up stays, and the guide still takes you there.

**A navigation arrow.** It points at the current objective and says how far and
how long, floating on the world with no window around it. It needs a waypoint
provider; with none, or with no waypoint for this step, it hides rather than
pointing somewhere arbitrary. RestedXP's "Travel to Kalimdor" and "Travel to
Eastern Kingdoms" steps give a point on the continent's map rather than a
zone's: TomTom takes it and points across the continent, and so does
Pathfinder's arrow. pfQuest, Cartographer and MetaMap only place points in a
zone, so they set none for those steps.

**Which arrows.** The **Arrows** section on the options' **Navigation** page
has a switch for each: Pathfinder's, TomTom's and pfQuest's. Turn on one, two,
all three or none; each one that is on points at the step, whichever addon
takes the waypoints. pfQuest's switch is pfQuest's own arrow setting, the one
`/db arrow` changes, so off is off in pfQuest too, and pfQuest stops pointing
at the nearest quest objective as well. TomTom's off keeps its arrow off the
guide's waypoints; waypoints you make yourself still use it. An addon that
isn't loaded has its switch held off. By default it is Pathfinder's alone,
and the waypoint addon keeps its map pins either way.

## Gear

**Item score.** Every item's tooltip gets a line: what the item is worth to
your spec, and how it compares with what you wear in that slot — green and
`+12%` for an upgrade, red for worse, *empty slot* where you wear nothing, *not
for you* for armour, weapons or classes you cannot use. An item you are too
low for says the level it becomes an upgrade at.

- **The score** is the item's stats — read off its tooltip, as a 1.12 client
  gives nothing else — weighted for your class and spec, with soft caps on hit,
  crit, defence and the like so that stacking one stat does not run away. Each
  line counts as what it says: spell crit as spell crit (not melee crit too),
  "Restores 12 mana per 5 sec." as 12 regen (not a mana pool as well), and
  "damage and healing" as both spell power and healing.
- **Your spec** is the talent tree you have put most points into, or the one
  you pick; with no talents yet, your class's usual levelling spec.
- **Comparing:** a ring or trinket is weighed against the weaker of the two you
  wear, a one-hander against either hand once you can dual wield, a two-hander
  against both hands together. Enchants are left out on both sides.
- **The weights** are worked out from the game's own formulas for every class
  and spec, each in one unit -- a point of attack power (ranged attack power
  for hunters), of spell damage, of healing, or of Stamina for tanks -- and
  then moved most of the way toward Pawn's Classic Era scales (HawsJon's).
  There are two sets: **leveling**, used until 60, where Stamina, Spirit and
  regen count for more because they keep you going between pulls, and **60**,
  for pre-raid gear, where crit and hit count for more. The scores change over
  to the 60 set the moment you reach 60. Tanks (Protection warriors and
  paladins, bears, the shaman tank) use their one set at every level. A bow's,
  gun's, crossbow's, wand's or thrown weapon's DPS is its own stat, **ranged
  weapon DPS**: a hunter's bow counts for far more than its melee weapon, and
  a leveling caster's wand for something. Turtle WoW's own stats (Fortune,
  Avoidance, Lifesteal and the like) keep OctoPawn's weight, rescaled.
- **The Item Score page**, in the options window under **Gear** (`/apg gear`,
  or **Stat weights** on the Gear page), lists the weights in use down the
  left with a box each, as Zygor's does, and says which set they are. Change
  any of them -- a change is kept for the set it was made in, so one made
  while leveling is not carried to 60 -- pick another spec, **Reset weights**
  to put the set back to the defaults, or import and export them as a string
  OctoPawn reads too. An export holds every stat, so the scale arrives whole
  wherever the defaults differ. Changes made to the old (OctoPawn's) weights
  were cleared once in 0.23.4, with a line in chat saying so.
- **More than one spec, as Pawn does.** The Item Score page has a switch for
  each spec of your class. Yours is always on; switch on another -- the tank
  set you carry, the healing set -- and every tooltip gets a line for it too,
  with its score and upgrade percentage. Each spec that is on remembers the
  best items you have worn in each slot (the best two rings and trinkets), as
  your gear changes, and an item is weighed against those rather than what you
  happen to have on: the healing set in your bags does not hide a tank upgrade.
  **Forget best items** starts again from what you wear.
- **Drops for your other specs.** When something new in your bags beats the
  best you have worn for another spec that is on, the chat says so once:
  "*[Tower Shield]* is an upgrade for your Protection gear (+12%)." (What is in
  your bags at login is not new.) Your own spec's upgrades go to the Gear
  Advisor's window, as before. Switch it off on the same page.

**Gear Advisor.** It watches for upgrades, as Zygor's does, and is switched
under **Gear** in the options:

- **Upgrades as you pick them up.** When something in your bags beats what you
  wear and you can wear it now, a window says so: the item, how much better,
  what it replaces, and **Equip** or **Decline**. Declined items are not offered
  again until you **Clear declined items**. In a fight, Equip waits for the
  fight to end.
- **Equip upgrades for me** puts them on without asking — never one that binds
  when equipped; that one still asks. Off until you turn it on.
- **Quest rewards.** When a quest offers a choice, the best one is marked: the
  biggest upgrade, or, with none, the one a vendor pays most for. With **pick it
  for me** on, and quests turning in by themselves, it is taken.
- **Your bags.** Upgrades get a border in the default bag frames.
- It can be switched off, or off at level 60.

**Gear Finder.** A tab on the character panel, after Character, Reputation,
Skills and Honor (`/apg finder`, or **Open the Gear Finder** in the options),
laid out like Zygor's:

- **A cell per slot**, as the character sheet has them: two columns of eight,
  and the ranged slot under the suggested dungeon. Each shows the slot's
  biggest upgrade: the item, how much better it is (+54%, or *Empty slot* for
  a slot you wear nothing in), where it drops and who drops it, and *at level
  24* if you cannot wear it yet. A slot with none shows its empty picture and
  *No upgrade found*. Rings and trinkets have two cells each, never the same
  item in both. Shirt and tabard are left out: they have no stats.
- **Click a cell** for the slot's list: every upgrade for it, biggest first,
  each with its gain, dungeon, boss and drop chance. Click one to make it the
  cell's -- it is marked *Your pick* -- or **Clear my pick** for the biggest
  again. Picks are kept for the character, and forgotten once you wear the
  item or it is no longer an upgrade.
- **The suggested dungeon**, on the right: its loading screen, the spec it
  scores for (change it there), the dungeon the cells' items drop in most --
  by how many slots it upgrades, then by how much they add up to -- with its
  levels, how many upgrades and which slots. Arrows step through the other
  dungeons in that order, and **Open the guide** opens its dungeon guide.
  Picking a different item can change the suggestion; it changes at once.
  Quest, reputation and crafted gear have cells, but do not count towards it.
- With nothing to suggest -- a spec whose upgrades are all quest rewards, say --
  it says why, and the spec stays there to switch back.
- The footer says where it looked; the cog opens the options at the Gear
  page. Drag the page to move the character panel. Its own ✕ closes the
  character panel, as closing any of its pages does.

- **Upgrade sources**, five checkboxes in the options, two to a row:
  **Dungeons**, **Raids**, **Quest rewards**, **Reputation vendors** and
  **Crafted gear**. Tick only Dungeons and it looks nowhere else. Dungeons
  and Raids are Zygor's two -- 1.12 has no difficulties to tick. It looks in the dungeons that
  start no more than three levels above you, on your side -- ticked on the
  **Dungeons** page or not, as those ticks are which dungeons' quests the route
  takes in; with **Raids** ticked, in the raids at your level too. Items up to
  three levels above you count, marked with their level. With nothing ticked
  it says it has nowhere to look.
- Each drop is weighed with the item score, for your spec, as tooltips are.
- Walking into a dungeon names its upgrades in chat.
- The loot tables are the CMaNGOS database's for every vanilla dungeon and
  raid, and pfQuest-turtle's for Turtle WoW's own: Dragonmaw Retreat,
  Crescent Grove, Stormwrought Ruins, Gilneas City, Hateforge Quarry, Karazhan
  Crypt, The Black Morass, Stormwind Vault, and the Emerald Sanctum and Tower
  of Karazhan raids. Their levels are read off their creatures. Frostmane
  Hollow and Windhorn Canyon are newer than that data: theirs are
  InstanceJournal's, with its levels and each boss's chances. pfQuest-turtle
  does not say what Turtle's own items are, so the game is asked the first
  time -- a list may fill in over a few seconds, once.
- The vanilla dungeons and raids are as Turtle WoW has them: pfQuest-turtle's
  changes are laid over the CMaNGOS loot -- bosses Turtle added (Molten
  Core's Incindis and Basalthar, among others), loot moved between bosses,
  new items, and drops taken out. Where Turtle only changed a shared loot
  table, the CMaNGOS chance stands.
- Not only drops -- at 60 much of the best gear is not one. Each a box under
  Upgrade sources, ticked to start with (they were switches before 0.22.2,
  and keep what those were set to):
  - **Quest rewards** from quests you have still to do, on your side and for
    your class, that you can take within three levels: *Quest: Title*, with
    the reputation it needs where it needs one (*Honored, Argent Dawn*). Most
    rewards need no level to wear; those count at their quest's level, so one
    from a quest ten levels below you is left out as outgrown.
  - **Reputation gear** a vendor sells at a rank: *Revered with Stormpike
    Guard · the quartermaster*.
  - **Crafted gear**: *Blacksmithing 300*, and *made by a crafter* when you
    are not one. Crafted gear that binds on pickup counts only if you have the
    profession -- and under Solo Self-Found, all of it does.
  These are looked at near your level only, up to ten levels under it: there
  are thousands, each loaded to be weighed. They are vanilla's, from the
  CMaNGOS database; Turtle's own quests and recipes are not in it.
- Ticking **Raids** says the first look takes a minute or two: hundreds more
  items to load, once.

## Professions

| Authored | |
|---|---|
| Alchemy, Blacksmithing, Cooking, Enchanting, Engineering, First Aid, Jewelcrafting, Leatherworking, Mining, Survival, Tailoring | Full 1–300 crafting routes |
| Herbalism, Skinning, Fishing | 1–300 by where to go — see **Gathering** below |

The crafting guides follow [CraftRoute](https://github.com/Kitymeowmeow-turt/CraftRoute)'s
routes: the cheapest way to 300 as CraftRoute's own planner works it out, from
the auction prices in its sample scan (30 July 2026). Each craft count is the
average number of attempts it takes, rounded up, so a step never asks for
fewer crafts than the skill points it covers. Where CraftRoute makes more of
something than the skill needs, because a later recipe uses it, the step says
"Keep them for" that recipe. Its scan had no listing for most things you
gather yourself — the fish in Cooking, some ore, Survival's wood — so those
were costed at three times what a merchant pays, and the guide's first step
names them. Mining's route is from the reference document. First Aid's is the
usual one (Linen to 40, Heavy Linen to 80, Wool to 115 and so on), with each
count worked out from the bandage's skill colours the same way, and
Journeyman trained at 50, where it can be.

These are fixed routes, chosen once. For one planned from today's prices
instead, see **Cheapest crafting route** above — it keeps the authored guide's
trainer and rank steps and replaces only the crafts.

Each authored guide says what to craft in each skill band and how many, the
reagents (the shopping list totals what the rest of the route still needs, and
can send it to Aegis: Exchange) and where the recipe comes from.

Every rank is a step of its own: your faction's trainers, what the rank needs
and what it costs. Primary crafts wait for the character level a rank needs
(Apprentice 5, Journeyman 10, Expert 20, Artisan 35) with a "Reach level N"
step that clears itself once you are there. With pfQuest installed the step
points the arrow at the nearest of its trainers. Cooking and First Aid do not
train Expert or Artisan: the guide sends you to buy the Expert tome, and at
skill 225 — the point the route cannot pass without it — walks you through
the Artisan quest, level 40 and what to bring included.

Reagents and recipe sources come from the same recipe data the cheapest route
uses. Trainers come from the reference document, and Engineering's, which it
does not cover, from the CMaNGOS 1.12 database: every NPC whose
trainer list teaches that rank, in the zone pfQuest puts them in. Artisan is
Buzzek Bracketswing in Gadgetzan (Tanaris) for both factions. Trainers the
Turtle-lineage servers added in their own new zones are not in those databases,
so are not listed.

Steps complete themselves on the numbers the game reports: a craft or
gathering step when your skill reaches its target, a rank when your skill cap
does. Open a guide part-way through and it goes straight to where you are.

### Gathering

Herbalism, Skinning and Fishing level by going somewhere, not by making
something, so each skill band is one step naming the best places for it — for
your faction, with the levels this addon's own zone guides spend there, so you
can pick one your character suits:

- **Herbalism** — the zones with most of the herbs that can still raise your
  skill in that band, counted from pfQuest's node database (Turtle WoW's new
  zones included), and which herbs to look for there.
- **Skinning** — the levels of beast worth skinning in the band, and the zones
  with most of them (normal creatures, no elites), from the CMaNGOS database.
- **Fishing** — the zones where nothing gets away at your skill (every catch
  can raise it, wherever you fish). Expert is a book, *Expert Fishing - The
  Bass and You*, from Old Man Heming in Booty Bay; Artisan is Nat Pagle's quest
  in Dustwallow Marsh, with where each of the four fish is caught — or, for
  the Horde, Katoom the Angler in The Hinterlands trains it.

Each rank is a step with your faction's trainers, capital cities first; with
pfQuest the arrow points at the nearest. Gathering ranks mostly need no
character level; where the trainer data says one does — Artisan Skinning at
35, Fishing at 5 to start and 35 for Artisan — a "Reach level N" step waits
for it.

Where the reference had no recipe for a skill range, the guide says so rather
than inventing one. Mining's mid-range gaps are real, and it tells you to go
mine nodes — and where: for your faction, the zones with most of the veins
that can still raise your skill. Each of its smelting steps says where to
mine the ore it uses, too.

## Servers

Turtle WoW, OctoWoW, Capybara Paradise and RavenCraft share the quests and
places these guides use, so the same guides work on all of them. The **Server
theme** option is colours only. For quest-giver lookups, use the
pfQuest pack for your server: `pfQuest-octo` on OctoWoW, `pfQuest-turtle`
elsewhere.
