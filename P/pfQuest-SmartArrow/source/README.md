# pfQuest SmartArrow

An add-on for pfQuest's arrow on the 1.12 client, for the [brues-code](https://github.com/brues-code/pfQuest) and [lightblade](https://octowow.st/git/lightblade/pfQuest) pfQuest builds, with or without ClassicAPI. It needs pfQuest and doesn't work without it.
pfQuest's arrow points in a straight line at the nearest objective. With pfQuest SmartArrow, the same arrow follows the way you would actually get there. It adds only what pfQuest can't tell you:

```
            ▲                                         ▲
      [30] Kill Raptors                          [5] Kobold Candles
  Go to Arathi Highlands via Thandol Span        Enter Fargodeep Mine
     1.4k yd   total ~6m 10s                       310 yd   total ~1m 08s
                                            Objective is down in the mine: Fargodeep Mine
```

The title, objective text and distance are pfQuest's own. The line under the title shows the current travel step (a zone exit, a flight, a boat). On the last stretch it shows pfQuest's objective text again. Notes appear underneath only when something is special about the spot.

## What it does

- **Walks around things, not through them.** Within a zone, the arrow follows a planned path around trees and buildings such as Aldrassil, Northshire Abbey and Anvilmar, and around anything you have bumped into before. It prefers paths you have walked (mostly roads) and keeps away from hostile camps that are dangerous at your level. It aims a few yards ahead along that path, so it leads you round corners.
- **Shows the real path on the map.** pfQuest's straight dotted line from you to the objective is replaced on the world map and minimap by the planned path, in the same style. pfQuest's line between objectives, and its "routes" and "routeminimap" settings, are untouched.
- **Walks a terrain-checked network.** Between zones and across big zones, the route follows a network of zone borders, mountain passes, tunnels and city gates. The straight walks between them were checked against the game's own collision data, and blocked ones are left out. That covers 42 classic zones, from Waypoint Tracker.
- **Takes real zone exits.** It walks you through real zone exits (Dun Algaz, Thandol Span, Mor'shan, the Great Lift...) instead of pointing over a mountain range.
- **Uses your flight paths.** It learns which flight paths this character has every time you open a flight map, and only plans flights between those. Use `/smartarrow taxi all` to plan with every flight path, or `/smartarrow taxi none` for none.
- **Crosses continents.** It knows the boats, the zeppelins, the Deeprun Tram and the Rut'theran portal, and only uses the ones your faction can take. pfQuest's arrow just hides when the objective is on another continent.
- **Picks objectives by travel time.** It goes for the objective that is quickest to reach, not the one that looks closest on the map. It stays within the same watched or unwatched group pfQuest picked from. If you clicked a node, or sort by level, pfQuest's choice is kept.
- **Flags tricky spots.** When the objective is in a cave or mine, at the top of a tower, or on another level from you, a short note says so. The full route is still available in chat with `/smartarrow route`.
- **Gets better as you play.** When you walk from one zone into another somewhere the data doesn't know about, it saves that spot as a new crossing. When you walk into a cave or building, it saves the doorway, how far the place extends, and how far it goes up or down. The next time an objective is inside, the arrow sends you to the doorway first (`/smartarrow learn`).
- **Sets manual waypoints:** `/smartarrow way Wetlands, 10.5 60.2 Menethil`. Other addons can call `pfQuestSmartArrow:SetWaypoint(zoneId, x, y, title)`.
- **It is pfQuest's arrow, not a second one.** It draws into pfQuest's own arrow frame and uses the objectives pfQuest already lists for it (`pfQuest.route.worldcoords`). pfQuest's arrow settings keep working: `/db arrow` turns it on and off (routing goes off with it), Shift-drag moves it, Shift-wheel and the config slider scale it. `/smartarrow off` puts pfQuest's original straight-line arrow back. No pfQuest files are changed.

## How the route is planned between zones

`data/walknet.lua` holds 870 points: 100 border crossings, 749 passes and 21 city gates. There are also 754 surveyed links between areas, such as crossings, tunnels, gates and the Freewind Post lift, and 15 wall segments. Every straight walk the source checked against the game's terrain collision is marked clear (741) or blocked (138).

Rules for the planner:
- **Inside an area, walking straight is allowed** unless it was found blocked or crosses a wall.
- **Between areas, you go through a surveyed link.**
- **Passes far apart are joined only if they were checked clear.**

A few places are small areas of their own: the Dun Algaz tunnel, Ironforge's approach and Dun Morogh's north gate. You count as inside one when you're within its circle on the map.

The source is Waypoint Tracker's network for WoW: Forever. Its positions match the classic world to the yard. Forever reshaped Mulgore, Redridge Mountains, the Eastern Plaguelands and Stonetalon Mountains, so those zones use this addon's own zone exits (`data/travel.lua`) instead.

## How the walking path is planned

pfQuest has no terrain or road data; its coordinates are flat points. So each stretch you walk is planned from three sources:

| Source | Where it comes from | Effect |
|---|---|---|
| **Obstacles** | A few built in (`data/obstacles.lua`): Aldrassil, Northshire Abbey and Anvilmar, each placed at the centre of the NPCs pfQuest has inside it. The rest are learned. | Paths never cut through one. You can still walk into a building whose trainer you're visiting. |
| **Structures** | Obstacles you go *up*, with their only way on and off. Aldrassil is measured from Questie's spawn data: the 22 NPCs on the tree reach 54 yards from its centre, and ground wildlife starts at 56, so the base is solid to about 45 yards. Its ramp starts next to Gilshalan Windwalker, where a sentinel guards the entrance. | Anything on the tree (trainers, the inn, Tenaron Stormgrip) is reached by walking to the ramp's foot first. From up on the tree, you're routed back down the ramp. |
| **Roads** | Built in (`data/roads.lua`): about 16,000 points of NPC patrol paths across 47 zones, from QuestieDB. Guards, sentinels and couriers patrol roads, and every patrol follows ground the game knows is passable. | Used like walked trails: 25% cheaper and trusted, so routes follow real roads from your very first walk. |
| **Trails** | The paths you actually walk, recorded every 12 yards (up to 30,000 points). | Walked ground costs 25% less, so routes follow roads you've used, and anything walked is known to be passable. |
| **Danger** | pfQuest's spawn data for hostile mobs, weighted by level against yours. Elites count triple; grey mobs and critters don't count. | Paths are charged extra for crossing camps, so they skirt them when the detour is worth it. `/smartarrow safety 0-3` sets how hard. |

**Getting out.** If you end up inside an obstacle (inside Aldrassil's trunk, say), the way out follows the path you walked in on, from your recorded trail. Walking straight out through the wall is priced six times higher, so it's used only when no trail exists. Whether you're up on the tree or at ground level is told from your height against the ground you last stood on, so at ground level you aren't sent round to the ramp for nothing. If the arrow still points into a wall, type `/smartarrow stuck`. That marks the spot ahead as blocked and replans at once.

**Learning obstacles.** When something blocks you, the client either slides you along it, so you move much slower than usual while facing the arrow, or stops you dead after running. Either way, a small circle is added in front of you and the path is replanned around it. Bumping into the same thing again enlarges the circle. Walking through the middle of a learned circle later deletes it, so a wrong guess cleans itself up.

**Remembered routes.** Every walking stretch you finish is saved as the way you actually walked it, simplified to a few corners. That includes the walk round anything you bumped into. Up to 400 are kept, the least recently used going first. The next time you walk between the same two places, in either direction, the saved route is used as it is: no planning, and a dotted line that doesn't change. That covers the usual quest trip, out to the objective and back to the quest giver. It works even if you start up to 30 yards off the route. A remembered route that gets you stuck is forgotten and replaced by the next walk. `/smartarrow forget routes` clears them.

**The dotted line holds still.** The line keeps its first good guess. A better plan (after you bump into something, say) replaces it only once you've walked 30 yards since it was drawn, or straight away for a new objective. The arrow always follows the newest plan, so it steers round the obstacle at once even while the line is held.

**Limits.** Away from the built-in roads and obstacles, in a place you've never been, the first walk is still a straight line until you bump into something or walk it once. Water, cliffs you'd fall from, and steep slopes are not known in advance.

## Notes under the arrow

Notes show up only when there is something to say, three lines at most:

| When | Note |
|---|---|
| The objective is in a known cave, mine or crypt, and you are outside | "Objective is down in the mine: Fargodeep Mine". If you have never walked in, it adds that the entrance will be remembered once you do |
| The objective is in a known tower | "Objective is at the top of Tower of Azora" |
| You are inside, on the last stretch, and the place has another level | "Goes down: keep descending", "Has an upper level: go up", or "Several levels here: check above and below" |
| You pinned a note within 40 yards of the objective | your text |

There are two sources of known places:

- **A built-in list** (`data/places.lua`) of about 55 quest caves, mines, crypts and tower tops on both continents. The positions come from VanillaGuide's step coordinates, wherever a step sends you into a cave or to the top of a tower. The list only labels a place and never moves the arrow.
- **Places you have walked into.** They are detected with `IsIndoors()` and the sub-zone name, and their measured shape replaces the built-in circle. A remembered doorway becomes a real waypoint ("Enter Fargodeep Mine").

pfQuest's coordinates have no height. "Another level" therefore means the place itself has one, measured from your own height while you were inside. It doesn't mean pfQuest knows the objective's floor. For spots the addon can't work out, pin your own note: stand there and type `/smartarrow note second floor, stairs behind the bar`.

## Waypoints from other addons

Any addon that hands pfQuest's arrow a waypoint is routed too. That means a node added with `pfMap:AddNode{ ..., arrow = true }` and selected with `pfQuest.route.SetTarget`, which is what guide addons do. If its title is already an instruction, it is shown as written. No other addon is needed: without one, the arrow simply routes to your quest objectives.

## Which pfQuest

SmartArrow works with these pfQuest builds and picks the right mode by itself at login:

| pfQuest | Client | How positions are read |
|---|---|---|
| [brues-code pfQuest](https://github.com/brues-code/pfQuest) | with ClassicAPI | pfQuest's own world coordinates (`pfQuest.route.worldcoords`, `pfMap:GetWorldPos`) |
| [lightblade pfQuest](https://octowow.st/git/lightblade/pfQuest) | with ClassicAPI | `UnitPosition` and `C_Map` from the client; objectives from `pfQuest.route.coords` |
| lightblade pfQuest | plain 1.12 | your zone-map position (`GetPlayerMapPosition`) and the zone table in `data/zones.lua` |

**On a plain 1.12 client:**

- **Zone positions.** 41 zones and cities are placed exactly. They're fitted from the walking network's points, which carry both map and world positions. Five maps are estimates, accurate to within about 150 yards: Mulgore, Redridge Mountains, the Eastern Plaguelands, Stonetalon Mountains and Stormwind. The first time you walk into one of them from a neighbouring zone, SmartArrow measures it from your last position across the border and prints a line in chat. From then on, positions there are exact.
- **Flight paths.** The 1.12 flight map only gives names and positions on its own small map. When you open it, SmartArrow places each flight master from pfQuest's own flight-master list. It goes by zone, and where a zone has several flight masters, by where they sit on the flight map. Open a flight map once per character, as before.
- **Your height** isn't available, so the notes about upper and lower levels inside caves and buildings don't appear, and on Aldrassil you're always routed by the ramp.
- **Objectives** are the ones pfQuest's arrow can see, the ones on your current zone's map, which is how this pfQuest's own arrow works too.
- **Facing** comes from pfQuest's minimap-arrow fallback.

## Install

1. Install one of the pfQuest builds in the table above. pfQuest SmartArrow is a required-dependency addon: the game won't load it without pfQuest.
2. Copy the `pfQuest-SmartArrow` folder into `Interface\AddOns\`, next to `pfQuest`. The folder name must match the `.toc` name.
3. Keep pfQuest's arrow turned on (`/db arrow`).

If pfQuest is missing, or has no arrow route SmartArrow can read, pfQuest SmartArrow prints one line at login saying why and stays inactive, leaving pfQuest untouched.

## Commands

`/smartarrow` (or the short `/psa`) lists everything.

| Command | |
|---|---|
| `/smartarrow on\|off` | Route pfQuest's arrow, or let it point in a straight line again |
| `/smartarrow notes` | Show or hide the notes under the arrow (right-click the arrow does the same) |
| `/smartarrow note <text>` / `note` | Pin a note where you stand, or remove the nearest one |
| `/smartarrow smart` | Turn picking objectives by travel time on or off |
| `/smartarrow taxi known\|all\|none` | Which flight paths the route may use |
| `/smartarrow learn` | Turn learning of zone borders, cave and building entrances, and obstacles on or off |
| `/smartarrow stuck` | The arrow points into a wall: mark the spot ahead as blocked and go round it |
| `/smartarrow trails` | Turn recording the paths you walk on or off |
| `/smartarrow safety 0-3` | How hard to avoid hostile mobs: 0 ignores them, 1 (default) skirts camps, 3 avoids them hard |
| `/smartarrow path` | Show or hide the planned path on the world map and minimap |
| `/smartarrow forget borders\|places\|obstacles\|trails\|routes\|all` | Forget learned data (your notes are kept) |
| `/smartarrow way [zone,] x y [title]` | Set a waypoint. With no arguments, clear it |
| `/smartarrow route` | Print the full route, step by step, in chat |

Moving and scaling are pfQuest's: Shift-drag moves the arrow, and Shift and the mouse wheel change its size. Right-click it to show or hide the notes.

## How routing works

`graph.lua` keeps a travel graph in world coordinates (yards):

- **the walking network**: about 870 surveyed zone borders, passes, gates and lifts from Waypoint Tracker (`data/walknet.lua`)
- **connectors**: hand-made zone exits where the network has no data (`data/travel.lua`), plus the ones it learned
- **docks**: the two ends of each boat, zeppelin, tram or portal, with a fixed travel time
- **taxi**: the flight masters this character knows, linked to each other at about flight speed

Walking between two points in the same zone costs the straight-line distance plus 10%. Crossing into another zone anywhere other than a connector costs 2.5× the distance plus a flat 4,000 yards. That keeps short hops over a ridge (Ironforge to Menethil is about 1,300 yards as the crow flies) from beating the real road, so the planner goes around through real exits. The times on screen use real distances; the penalties only affect which route is chosen. It still finds a route when the data has a gap. A single-source Dijkstra from the player ranks every pfQuest objective by travel time. A new route for the same objective has to come out the same twice in a row before it replaces the old one, so the arrow doesn't flip between two routes that take about the same time.

### Keeping it smooth

Planning is kept out of the way of the frame rate:

- The route is re-planned only when it could come out different: you moved about 12 yards, pfQuest's objectives changed, you left the drawn path, something new was learned, or 6 seconds passed. It is checked every 1.5 s.
- The route search, the graph rebuild after learning something, and the planning of walking paths round obstacles all run as background jobs. Each gets about 2 ms a frame and pauses until the next frame when that's used up. The arrow keeps its current plan for the few frames a job takes. Walking into an unknown rock on busy ground, the test walk's worst frame is about 2 ms. Planning the same path in one go takes 15–25 ms.
- Remembered routes need no planning at all.
- The dotted line is redrawn at most once per 30 yards walked, and only when its shape changed. Dots are reused in place, and only the ones whose spot changed are moved. The minimap only works through the part of the route inside its circle.
- The walking network's edges are worked out once, while the loading screen is up. Later rebuilds reuse them.

Planning speed is running speed (7 yd/s), or 60% mount speed from level 40. Change that with `pfQuestSmartArrow_config.mountlevel` or `pfQuestSmartArrow_config.speed`.

## Fixing the data

Obstacles are circles in `data/obstacles.lua`: zone map percent plus a radius in yards. Place a new one at the centre of the NPCs inside the building or tree if pfQuest has some.


Every zone exit in `data/travel.lua` was checked against the real world rectangles of the zones it joins (from WorldMapArea.dbc), so each point lies inside both zones. Each exit counts as reached within about 60 yards. If one is off, fix the `x`/`y` (zone map percent on that `zone`), or just walk through the spot and let it be learned.

Built-in caves and towers live in `data/places.lua`. The `name` must be the sub-zone name the minimap shows inside, so it matches what the addon learns.

## Credits

The arrow, its texture and its settings are pfQuest's. The idea of zone-to-zone travel legs and directions like "Go to [zone]" comes from [EasyRoute](https://octowow.st/git/stealthzi/EasyRoute) by stealthzi, whose travel notes were also used to double-check a few coordinates. pfQuest SmartArrow contains no EasyRoute code and does not use EasyRoute at runtime. The cave, mine and tower positions, and the Aldrassil ramp, were checked against VanillaGuide (mrmr's addon of Joana's guide); only coordinates and the kind of place were taken, not guide text. The ramp's foot at Gilshalan Windwalker is from a classicdb comment on "Tenaron's Summons".

The walking network in `data/walknet.lua` is converted from [Waypoint Tracker](https://github.com/sanjaygbhat/wowforever-waypoint-tracker) by sanjaygbhat. Its network was built from the WoW: Forever client's tables and [Mapzeroth](https://github.com/tr0tsky0/Mapzeroth) by tr0tsky0. Both are MIT-licensed; their copyright and licence notices are kept at the top of that file, as the MIT licence requires.

The built-in roads in `data/roads.lua`, and Aldrassil's measurements, come from [QuestieDB](https://github.com/Questie/QuestieDB): NPC patrol waypoints and spawn positions, which QuestieDB took from Questie and Questie from cmangos. QuestieDB states that its content may be copied under GPLv3 terms, so `data/roads.lua` is distributed under GPLv3. The addon as a whole is released under GPLv3 to match.

## Licence

Copyright (C) 2026 pfQuest SmartArrow contributors.

pfQuest SmartArrow is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License or (at your option) any later version. It is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See [LICENSE.md](LICENSE.md) for the full text.

pfQuest itself, and its arrow texture that this addon draws with, belong to pfQuest and keep pfQuest's own licence; they are not part of this package. `data/walknet.lua` includes MIT-licensed material (Waypoint Tracker, Mapzeroth) whose notices are reproduced in that file.
