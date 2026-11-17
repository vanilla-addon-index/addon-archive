# pfQuest xpGuide 1.1.2 (formerly Easy Route 0.9.8)

## Latest changes

**Version 1.1.2**

- **Fixed: the arrow pointed at another quest ("Finish A Good Friend" but the arrow went to The Woodland Protector).** A quest to
  finish that pfQuest has no objective spot for (a talk or delivery quest) left the step with no place, so pfQuest's own arrow
  showed the nearest objective of any quest in your log. The step now points at where the quest is handed in.

**Version 1.1.1**

- **2x now uses real quest experience.** The Fast guides on 2x keep the quests that give the most experience, until a visit has
  about half of its quest experience (you gain double, so half is enough), with the quests that lead to them. Before, they were
  ranked by quest level. The values are the 1.12 quest experience from classicdb.ch (`tools/classicdb_quest_xp.json`, 3,401 quests);
  a quest it does not list (53% of the zone data's quests are listed; the rest are mostly this server's own quests) counts as the
  middle quest of its level. 1x is unchanged.

**Version 1.1.0**

- **xpGuide Fast route: my own fast guide, by class and profession.** Two fast routes, one per faction (Alliance 51 guides, Horde
  52), 1 to 60, written from the addon's own quest, zone and trainer data. They are listed as "xpGuide Fast Alliance 1-30 / 30-60" and the same for Horde.
  They follow your class (a class trainer visit every ten levels, and only the quests your class can take), your professions
  (First Aid, Cooking, Fishing, Survival and the nine primary ones: trainer visits, and herbs, ore and skins on the way) and your race.
- **Picking a Fast guide asks first.** A small window asks for 1x or 2x experience (**1x is the default**) and your professions.
  The class's two primary professions are ticked (Warrior: Mining, Blacksmithing; Hunter: Skinning, Leatherworking; Mage: Tailoring,
  Enchanting; Druid: Herbalism, Alchemy ...) with First Aid and Cooking; professions you already have are ticked from your skill list
  and show your skill ("Mining 150/300"; "not learned" otherwise). Two primary professions at most. "Start the guide" keeps the answers.
- **The rate is shown.** The step box's heading reads "1x exp, xpGuide Fast 1-30, on Casual", and Settings' guide line names it too.
- **2x keeps the better half.** On 2x the route keeps the higher-level half of each zone's quests (with the quests that lead to
  them); on 1x it keeps them all. `/xpg xp 1` or `/xpg xp 2`, or Settings -> Character. Changing it keeps your place.
  It only affects the xpGuide Fast guides.
- **Character tab in Settings** (7 tabs now, window 640 wide): experience rate, primary and secondary professions with your skill in each.
  Tick one to plan for it before you learn it. `/xpg prof [name on|off]` does the same from chat.
- **Difficulty works on the Fast guides.** Elite quests are in the guides now: Casual and Medium leave them out, Hard keeps them.
- **Fixed: "The Balance of Nature" was accepted twice at once.** Part 2 is offered only after Part 1 is handed in, so the guide now
  hands Part 1 in and accepts Part 2 in the next step. The same goes for every chain whose parts share a name and a giver.
- Limits: Survival has no trainer data (generic steps). The 2x choice ranks quests by level, not by true experience.

- **Usage and Features are tabs of Settings.** The Help window is gone: Settings now has seven tabs (Guides, Configuration, Auto mode,
  Helpers, Usage, Features) and the bottom row is only Close. The two text tabs scroll with the mouse wheel or the arrows beside
  them. `/xpg help`, `/xpg features` and Shift-clicking the minimap icon open Settings on the right tab. The window is a little
  wider (580) so six page buttons fit in a row.
- **Difficulty checked, kept.** It does change the guides: across the route, Bethink, VanillaGuide and fast-route guides Casual
  leaves out group, elite, escort, dungeon and "risky" quests and Hard keeps them (about 1 to 8 % of a guide's steps differ, most on the
  fast routes), it sets how far above you a quest may be before the guide warns, what a grind bridge levels to, and the Easy / Medium /
  Hard line on enemy tooltips. What did nothing was the old "director" that once ranked quests for a window that no longer exists
  (`ER.Plan`, `Candidates`, `Hubs`, `WhereNext`, `ChainIdeas`, `GrindSpots`, `WhyQuest`) and six of each difficulty's numbers that only
  it read (`behind`, `ahead`, `prefer`, `leaveAt`, `elites`, `travel`). They are removed, with `Data\Mobs.lua` (the 360 KB of mob
  places only it used) and the self-test lines that called it.

- **VanillaGuide steps rewritten as a short action line and a tip.** The list already names a step by its first quest line
  ("Hand in X", "Accept Y"); what was under it was the guide's whole sentence, often just those same words again plus a
  coordinate ("Turn in X at (59, 44) and accept Y"). The converter now leaves out the clauses that only say what the quest
  lines say, so a hand-in or pick-up step is just its lines, and a step keeps a tip only when the guide gave advice ("in a cove
  just west of the cave", "go turn in Etched Sigil at your class trainer"). 395 tips were left out altogether and the rest kept as
  the guide wrote them; steps with a quest to do keep their sentence whole, since the arrow takes its spot from it. A step with no
  quest of its own ("Hearth to Dolanaar", "Run east through Deadwind Pass...") now has a short title made from its first clause,
  808 steps. Steps the guide's authors had commented out in their tables (about 80, and placeholder "." lines) are no longer
  in the guides: the converter had read them as live.

- **VanillaGuide: a line with two stops is now two steps.** Some lines hand in and take quests in one place, then send you on
  ("Turn in Webwood Egg, accept Tenaron's Summons, then run up the ramp to the top of the tree and hand it in at (59, 39).
  Accept Crown of the Earth pt.1"). They were one step, so Crown of the Earth was offered at the first stop and Tenaron's
  Summons was never handed in. The guide data is now split at "then run / go / head / fly ..." when the first stop has quests of
  its own and the next one does too: step one turns in Webwood Egg and takes Tenaron's Summons, step two (at 59, 39) hands in
  Tenaron's Summons, and the step after it, in the same place, takes Crown of the Earth (what is taken after a hand-in is its
  own step, since it can only be taken once the hand-in is done). "Hand it in" is written out as that quest's hand-in. 21 lines
  changed this way (for example Zenn's Bidding, A Dark Threat Looms, It's A Secret to Everybody, Morrowgrain Research). Lines that say "do X,
  then run back and turn it in" are left as they were: their hand-in step is already made.

- **VanillaGuide: the arrow goes where the line says a quest is done.** A VanillaGuide line has one map spot, often a
  stop between two things ("get Webwood Ichor from a Webwood Spider (57, 32). Get Webwood Egg ... at (57, 26) inside
  the cave" has its spot at (57, 36)). On a Finish step the arrow now takes the spot from the quest's own sentence in
  the line. It finds the quest where the guide names it as a quest, not a place of the same name ("Grind up to the
  Jasperlode Mine at (61, 53) ... for The Jasperlode Mine"). After "... at (81, 42) for Extinguish the Firegut then run
  back to (84, 68)" it takes the spot before "for <quest>", not the hand-in spot after "then". When the sentence has
  no spot, the line's map spot is used as before. About 510 Finish steps have a spot of their own in the text; 34 of
  them now point somewhere else than before, in each case where the line says. (From a fix in another chat, extended
  with the sentence rules.) Bethink's guides and the fast routes already have a map spot per objective, so they are
  unchanged.

- **Chain lines in the step list.** The tabbed-in steps with short guide lines are gone; their lines broke off at every
  step of another quest in between. Each quest chain now has its own line in a narrow lane between the tick boxes and
  the step text, like a metro map. The line runs unbroken in the chain's colour from the chain's first step to its
  last, even through other quests' steps in between, and the chain's shape sits on the line at each of its own steps.
  Chains that overlap get side-by-side lanes (up to five); a chain that starts after another has ended reuses its lane.
  Hovering a step brings its chain's whole line to full strength, as well as lighting the chain's other steps. A
  chain with only one step in the list, or a sixth chain at once, keeps its shape beside the step number as before.

- **VanillaGuide: "do it, then turn it in" lines get their hand-in step.** Some VanillaGuide lines do a quest and hand
  it in in one go ("Do The Woodland Protector pt.2 at (56, 46). Run back and turn it in at (57, 45)."). Only the "do"
  part was a step, so once the objective was done the guide went on without ever asking you to hand the quest in. Each
  such line now gets a hand-in step of its own right after, with the arrow on the quest's hand-in NPC: 30 hand-ins
  added across the VanillaGuide guides. A line that leaves the hand-in for later ("don't turn it in yet", "when you get
  the chance"), or does several quests at once, stays as the guide has it.

- **More nameplate markers, all in the same style.** Besides the skull on mobs to kill, nameplates now show a **sack**
  on mobs that drop an item a quest needs, **!** on whoever gives the current step's quest, and **?** on whoever takes
  it back (friendly nameplates show with Shift-V). Every marker sits left of the level, has the thin dark border, and
  has its chain's shape behind it when its quest is in a marked chain.
- **Settings: "Configuration" page.** The page with the guide's options is now called Configuration.
- **Auto mode page redesigned.** The Auto mode tick sits on top, with its ticks under small headings: Quest givers,
  Travel, Vendors. While Auto mode is off they are greyed and cannot be clicked (they keep their setting for when it is
  back on). The hearthstone button, which works with Auto mode off too, has its own heading. The reward rule moved into
  the quest tick's tooltip.
- **Helpers page redesigned.** The ticks are grouped under headings: Arrow, Enemies and NPCs, Tips and warnings, Look
  and other. "Skulls on quest enemies" is now "Quest markers on nameplates", and its tooltip explains each marker.

- **Skull markers left of the mob's level.** The marker on a quest mob's nameplate now sits just left of its level
  instead of above its name (pfUI's own level text when pfUI draws the nameplate). When the mob's quest is part of a
  chain marked in the step list, that chain's shape (circle, square, triangle, ...) sits behind the skull, filled in a
  darker shade of the chain's colour and only a little bigger than the skull, so you can see which chain the mob is
  for. The skull has a thin dark border so it stands out from the shape, and the shape always ends a few pixels before
  the level, so neither covers the number. Mobs for quests in no chain get the skull only.
- **"Move on?" when you reach the guide's top level.** When your level reaches the top of the guide's levels, the tips
  box under the steps (where the money question is asked) asks whether to move on to the next guide, with Move on and
  Stay here. It is asked once per guide. The next guide is the guide's own "next", else the next one up of the same
  kind (Bethink's after Bethink's, VanillaGuide's after VanillaGuide's), preferring your zone and race. The casual route
  is never asked: it moves on by itself.
- **Guide picking is part of Settings.** The separate guide menu is gone. Settings now opens with a **Guides** page: the
  groups on the left, the group's guides on the right, the one running now in green and the best one for you in gold,
  with the about text on the tooltip. Click a guide to follow it. The list scrolls (mouse wheel or arrows), so every
  guide of a big group shows; the old menu cut off VanillaGuide 40-60 after 22 guides. Every "Pick a guide" (the
  welcome window, `/xpg`, the end of a guide) opens this page.
- **The guide options have their own page.** The old "Guide" page is now **Configuration** (lock, next guide,
  check-ins, money steps, text size, difficulty, start again, stop, find my place).

- **Nameplate markers in the chain's colour.** A quest mob's marker takes the colour of its quest's chain mark in the
  step list, so the mob and the steps it is for match. A quest in no chain keeps the usual colour (the accent with pfUI,
  gold without). This works for the pfUI skull and the game's skull alike.
- **VanillaGuide: no more skipping a quest's objectives.** Some VanillaGuide lines only say "go do it" without marking the
  objective ("Accept The Balance of Nature pt.1 ... go do it by killing mobs"). The next line then picked up the
  follow-up, so nothing followed doing or handing in the first quest, and the guide went straight on. The converter now
  puts a "Finish" step for the first quest before the line that picks up its follow-up, and the hand-in on that line.
  That is 41 Finish steps and 74 hand-ins over all the guides. The Finish step points at RestedXP's place for the
  objective, else where the guide said to do it.
- **VanillaGuide: class quests for their class only.** The guides give everyone one class's quest ("Etched Sigil" is
  the Hunter's). Such a quest is now only a step for its class, so other classes are not held up by a quest they cannot
  get.

- **Chain marks for colour-blind players.** Each chain now has its own shape as well as its own colour: circle,
  square, triangle, diamond, ring, plus, down triangle, bar. Shape alone tells two chains apart. The colours are the
  Okabe-Ito set, chosen to stay distinct with the common colour-vision differences. The tooltip names the shape
  ("Webwood Venom chain (diamond), part 4 of 9").
- **The mouse over a step lights its chain.** The other steps in view of the same chain (or chains) light up in the
  chain's colour, from the step or its tick box, and go back when the mouse leaves. They stay lit while you scroll.
- **Smooth skull markers.** With pfUI, quest mobs' nameplates show a small smooth minimalist skull (Media\IconSkull,
  drawn like the footer icons) in the accent colour on a dark outline, instead of the blocky pin made of squares. Bright
  for the current step's mobs, softer for the rest of the quest log. Without pfUI it stays the game's gold skull.

- **Chain colours in the step list.** Each quest chain with two or more of its quests in the guide gets its own colour,
  in the order its first quest appears. Every step about one of its quests shows a small mark in that colour, left of
  the step number. Steps of the same chain can be told apart from another chain's even where the guide goes back and
  forth between them (Teldrassil: The Woodland Protector and A Good Friend alternate). The guide's order is unchanged.
  A step with quests of two or three chains shows a mark for each. The indent line of a chain's later steps takes the
  chain's colour, and hovering a step names its chain and the part ("Webwood Venom chain, part 4 of 9").

- **Skipping a step that picks up quests of several chains.** About 630 steps pick up two or more quests at once (Fast
  route 272, VanillaGuide 221, Bethink 139), often from different chains before either is done. Skipping such a step
  only looked at its first quest. Fixed:
  - its button stands for every quest of the step ("You skipped The Woodland Protector and A Good Friend");
  - it stays while any of them can still be done. Before, the first quest being handed in or going grey skipped it
    for good, although the other chain's quest was still open. It is skipped for good only when none can be done;
  - a later skipped step of any of its chains is not a button of its own: it comes back with this one. Before, only the
    first quest's chain counted;
  - a skipped step whose quest can still be done can always be taken back. The skip's "left out" marks made it look
    done, so it could not.
  Checked as it was: abandoning one quest of such a step holds back only that quest's chain, and picking it up again
  brings back only that chain, while the other chain's done steps stay done.

- **VanillaGuide: the arrow points at the right person.** Each VanillaGuide line has one map spot, usually where the
  quest is done. On a line like "Accept The Balance of Nature from Conservator Ilthalaine, then kill the boars at
  (57, 45)", the arrow went to the boars, not to Ilthalaine. 139 of 344 pick-up steps pointed 40 or more yards from
  the quest giver, or into another zone. The arrow on these steps now follows the line part by part:
  - a quest to pick up: its quest giver (the addon's quest data, else RestedXP's place), when in the step's zone;
  - a quest to do: the guide's spot;
  - a quest to hand in: the hand-in NPC (RestedXP's place, else pfQuest's), else the guide's spot.
- **VanillaGuide: zone names and labels fixed.** 62 spots had zone names the game does not use ("Iron Forge",
  "Stormwind", "darnassus", "Un'Goro" with a curly apostrophe, "Tarren Mill"), so the arrow could not place them.
  17 spots had the wrong zone, e.g. "Desolace 62,36" for Gazlowe in Ratchet (The Barrens 62.7,36.2). Both are fixed when
  the guides are converted.
- **Fixed:** a hand-in place lost its y coordinate ("a and f()" in Lua keeps only f's first result), which would have
  broken the arrow on such a step.

- **VanillaGuide's guides.** The English guides from VanillaGuide (VanillaGuide Enhanced): Joana's and Brian Kopps'
  1-60 guides, 123 sections, about 3,000 steps. They are built in as their own groups, last in the guide menu:
  "VanillaGuide 1-20", "20-40" and "40-60", for your faction. Each starting zone (Cold Ridge Valley, Elwynn,
  Teldrassil, Durotar, Mulgore, Deathknell) is marked for its races and goes on to the shared 12-60 route.
  - Each item of the guide is one step, in the guide's words, with its colour tags kept as colours: quests gold, people
    green, items orange, places grey, quests the guide says to skip red. The step's map spot is the arrow's place.
  - The guides name quests rather than number them. Each name is matched to the addon's quest data by faction, chain
    part ("pt.2" is the second quest of that name in its chain), zone and level. Typos and extras like "(escort)" or
    "Fuel for Zapping" are matched too. 3,423 of 3,440 quest mentions matched; the rest are not quest names ("Class
    quest", "Welcome!") and stay as words. Matched quests are followed in your quest log like any other guide.
  - The guide menu has room for 16 groups.
  - **Fixed:** the menu called any group named "<word> 1-20" a fast route. Only the fast routes' own groups are relabelled now.

- **Bethink's Guide.** Bethink's 63 Guidelime zone guides (Guidelime_Bethink 1.0.8) are built in, as their own groups
  in the guide menu after the fast routes: "Bethink's Guide 1-20", "20-40" and "40-60", for your faction. Each starting
  zone guide is marked for its races, and each guide goes on to Bethink's next one.
  - **Converted, not run through Guidelime.** Each line of Bethink's guides is one step, in Bethink's own words with the
    quest names filled in. Its tags become what this addon follows: pick-ups, objectives, hand-ins, places (the arrow),
    level targets, hearth, set hearth, flight paths, flights, trainers, vendors, items to collect or use. Optional
    steps show "on the way". Steps for primary professions are left out (your choice); Cooking, Fishing and First Aid
    stay. The guides for Skyborne (a race of the guides' own server) are only offered to that race.
  - **Quests the addon does not know** (the guides' server has its own quests) are looked up in pfQuest's database. A
    quest still without a name becomes a step you tick by hand, so the guide never gets stuck on it.
  - The guide menu has room for 12 groups (it had 6), and a guide's tooltip there shows Bethink's description of it.
  - Licence: Bethink's guides are GPLv3 (`LICENSE-Bethink.txt`); `Data/Bethink.lua` notes what was changed.

- **Hints on bare Finish and hand-in steps.** On the Casual route, every "Finish X" and "Hand in X" step had no
  instructions: Teldrassil 86 of 86, Elwynn Forest 82 of 82, and the same in every zone. Only pick-up steps had a "Talk
  to ..." line. Such a step now shows the quest's own short hint under it, for example "Bring the Partially Filled Vessel
  to Corithras Moonrage in Dolanaar.". The hint comes from your quest log (saved when you accepted the quest), else
  pfQuest's copy, else the journal. Steps that have instructions of their own (most Fast route steps) are left as they
  are. The hint is also in the step's tooltip in the list.

- **Picking an abandoned quest up again goes back by itself.** The step box line "You took … again. Click to go back to
  its steps." is gone: the guide goes straight back to the quest's steps, then carries on where you were.
- **The list does not scroll past a step you can go back to.** After abandoning or skipping a quest, its button stays in
  view at the top of the list as the guide moves on (the step you are on is always in the step box).
- **The footer counts them:** "2 steps to go back to", between the arrow and the close icons. Click it to show the first
  of them in the list.
- **Skipped quests are buttons too.** A quest you skip yourself (Skip step, or ticking a later step) gets the same button
  in the list, with "Click to go back and do it". It goes back to the step with what the skip left out. Only the top of a
  skipped chain is a button; its later quests come back with it.
- **Grey quests are no longer offered back.** An abandoned or skipped quest that has gone grey (too easy for you now)
  loses its button and is skipped for good, even one still in your quest log.

- **Abandoned quests can be taken back.** When you abandon a quest, the guide passes over its work and hand-in steps.
  These now show the skip mark, and hovering says you abandoned the quest. The list used to refuse to take them back,
  because a hand-in whose quest is not in your log counted as finished.
  - **Pick the quest up again from its giver:** its steps come back by themselves, including work you had done before
    abandoning (a quest picked up again starts from nothing). The guide stays where you are. The step box shows "You
    took <quest> again. Click to go back to its steps."; after them, the guide carries on where you were.
  - **Or click one of its steps in the list:** the guide goes back to where you pick the quest up, with its steps back.
  - **The rest of its chain comes back too.** Abandoning a quest also holds back the quests that need it first, so the
    guide passed over their pick-ups, work and hand-ins as well. Picking it up again, or clicking any of those steps, now
    brings back every later quest of the chain, on every branch, that is not handed in yet. Going back, the guide walks
    the whole chain again, then carries on where you were. Example: Crown of the Earth 921, then 928, 929, 933, 7383 and
    935 in Teldrassil.
  - **Go back from the list, not the step box.** An abandoned quest's pick-up step in the list looks like a button (outline
    and fill in the accent colour, gold title), with the tooltip "Click to go back and pick it up again". One click goes
    back to where you pick the quest up, so the arrow points at the quest giver. Nothing about it is added to the step box.
  - **Only while it can be picked up.** The button stays as long as the game would offer the quest. Once it would not
    (handed in, or the quest before it in its chain not handed in), the quest and the rest of its chain are skipped for
    good: skip mark, no button, not offered back.
  - **Fixed:** the list showed some steps of an abandoned quest with the "completed" tick: its pick-up, and steps that
    also pick up its follow-up (where the guide had recorded them as done). Every step of an abandoned quest and its chain
    behind you now shows the skip mark until the quest is picked up again.
  - **Fixed:** after picking the quest up again, the brought-back steps still showed a tick or skip mark until you clicked
    each one. They now show as still to do (empty box, white title) straight away.
  - **Fixed:** a hand-in within a minute of abandoning and picking up the same quest again was taken for another abandon.
    A hand-in through the Complete button now always counts, and picking a quest up again forgets the abandon.
  - **Fixed:** the chain lookup could return a chain the quest was not on (for a quest whose prerequisite starts several
    chains, e.g. Kobold Camp Cleanup after A Threat Within). It now always runs through the quest itself. This also makes
    the list's chain indenting right for such quests.

- **Completed and skipped steps look different in the step list.** A completed step (its work done or its quest handed
  in) keeps the tick and a grey title. A skipped one shows a skip mark (») in its box instead of a tick and an amber
  title. That covers steps you skipped and steps the guide passed over (a quest you never took, not needed, or you went
  past it). The tooltip says which.
- **Finish steps point at the objective, not at the hand-in.** On the Casual route, a "Finish" step whose quest has no
  objective place in the route data (pfQuest has none for objectives like "use the phial at the moonwell") pointed at the
  quest giver's spot, often where the quest is handed in too. Example: "Finish Crown of the Earth (Filled Crystal Phial
  0/1)" pointed at Tenaron Stormgrip instead of the moonwell. Such steps now use RestedXP's place for that quest's
  objective, then pfQuest's objective location, and the giver's spot only when neither exists. The check over every
  race's route changed 129 quests, 117 of them by 60 yards or more. For example, all four Crown of the Earth moonwells,
  Ishamuhale, Alien Ecology, Hand of Iruxos, Raene's Cleansing, WANTED: Murkdeep!, A New Plague and The Chill of Death.
- **Hand-in steps without a hand-in place** in the route data now use RestedXP's hand-in place in the same zone, instead
  of the giver's spot. 45 differed by 80 yards or more. The worst were Of Forgotten Memories and Of Lost Honor (now
  Tirion Fordring), The Twilight Lexicon and True Believers (now Hermit Ortell) and The Master's Glaive.

- **Zone count fixed ("Teldrassil: 2/47 done" after 18 finished steps).** The heading counts the zone's *quests* handed
  in, and it only knew about hand-ins that went through the addon's hook on the game's Complete button. A hand-in step
  ticks off as soon as the quest leaves your log, so hand-ins the hook missed ticked their steps but never reached the
  count. That happens when another addon hands quests in through its own copy of the game's function, or for quests
  handed in before the addon was installed. A quest leaving the log now also counts as handed in when:
  - its reward window was open in the last minute, or
  - it was complete when it left, or
  - pfQuest's history says it was handed in.
  A quest you abandon is never counted. The heading now reads "Teldrassil: 4/47 **quests**", so it is clear it counts
  quests, not steps.
- **Skipped steps stay in the list.** On the Casual route a step you skip marks its quest as left out, which used to
  make the step vanish from the list, so it could not be unticked there. It now stays listed, ticked, until you take it
  back.

- **Text size picker.** Settings → Guide → Text size is now a left arrow, the size and a right arrow, as in the bag
  stack split (8 to 24). Click the number to follow pfQuest's size again.
- **Smooth footer icons.** The cog, arrow, x, padlock (shut and open) and the resize grip are small anti-aliased line
  pictures (`Media\Icon*.tga`) tinted in the theme's colours, instead of square dots. The footer is 20 px tall and sits
  6 px under the list, and the icons are 4 px in from the window's edges, so no border runs over them.
- **Unskip brings the chain back.** Unskip previous (or unticking the skipped step in the list) also takes back what the
  skip left out: the skipped quests are no longer marked as left out, so the rest of their chains return, and the steps
  the guide passed over because of the skip are back.
- **Finished quests cannot be skipped.** A step whose quest is complete in your log (only the hand-in left) shows
  **Finished** instead of Skip step, and its tick box in the list does not skip it. A step behind you that was done
  cannot be unticked.
- **Chains in the step list.** A chain's later steps are tabbed in under the step that starts the chain, with a thin
  guide line; the row's tooltip names the chain's first quest.

### Earlier in 1.0.0

- **Feedback removed.** The quest rating window, notebook, rating line and Feedback settings page are gone. The two
  options that lived there ("Tell my party when I hand in", "Popup on a chain's first quest") moved to Settings → Helpers.
- **Welcome window removed.** Help now has two pages: **Usage** (short, with the dependencies) and **Features** (main
  features and the change history). `/xpg features` opens the second.
- **Text size.** The guide's text follows pfQuest's font and its quest tracker's size (12 by default, up from the game's
  small font). Settings → Guide → Text size and `/xpg font <n|pfquest>` change it. List rows and the step box grow with it.
- **Footer icons.** Flat icons drawn like the resize grip, with no borders, lit in the accent on mouse-over:
  - the **cog** opens Settings directly (no menu);
  - the **arrow** beside it switches pfQuest's arrow → the guide's own → off;
  - **x** (hide) and a **padlock** (lock, shown shut when locked) sit beside the resize grip.
  - The version text is gone from the footer.
- **Mob markers with pfUI.** The nameplate skulls become a flat accent marker with a thin dark edge: bright for the mobs
  the current step needs, softer for the rest of the quest log. Without pfUI the gold skull stays.
- **Less repetition.** The step box no longer has the "Zone: X/N done" line (the heading has it) or "Stuck? Skip this
  step" (the Skip button does it). The arrow's label no longer says "pfQuest xpGuide".
- **Unskip previous.** Right after you skip a step, an **Unskip previous** button appears beside **Skip step** and takes
  you back to it. It goes away once the guide moves on.
- **The list stays put.** Ticking or skipping a step yourself no longer scrolls the list so only the newest step shows;
  it only scrolls if the current step would leave view. When the guide moves on by itself, the list keeps the last 3 done
  steps in view above the current one.

## Renamed: pfQuest xpGuide

- **Name.** The addon is now **pfQuest_xpGuide** (folder and `.toc`). Its title is "pfQuest xpGuide", and chat lines
  start with "xpGuide:".
- **Command.** `/xpg`. The old `/er` and `/easyroute` are gone.
- **Clean break from Easy Route.** The saved variables (`pfQuest_xpGuideDB`), global names, frame names, pfQuest map node
  id and nameplate marks are all new. pfQuest xpGuide starts with default settings, and it cannot clash with an Easy Route
  copy still in the AddOns folder.
- **Version.** 1.0.0.
- **Credits in the docs.** The windows no longer end in a "Made by" line; they show "pfQuest xpGuide v1.0.0". The `.toc` has no Author or website line. The original author,
  stealthzi, is credited in the Credits section of `README.md`.

## New: the guide window, laid out like RestedXP Guides

One window replaces Easy Route's step window and its simple-mode quest list (new `GuideWindow.lua`). It follows RestedXP
Guides' layout, from the top:

- **The step box.** The current step.
  - **Heading:** the guide's name and its group and difficulty are at the top, inside the box. On the Casual route the
    name is the zone and how far you are in it ("Elwynn Forest: 4/51 quests"). When the window is narrow, the name is
    shortened and the progress is kept.
  - **Lines:** each line has a tick box, ticked when the game says it is done, and an icon for what it is. The icons are
    the game's own: pick up, hand in, quest work, collect, use, level, talk, hearthstone, fly, boat, zone, vendor, grind.
  - **Steps you tick yourself** are ticked from the box. A quest line's box always shows what the game says.
  - **The extra lines stay in the box, as before:** warnings, reasons, the level line, the chain, the hearthstone
    button, where the route goes next and "Next guide".
- **"On the way".** Side steps get a second box, with its heading inside.
- **The step list.** Every step of the guide that fits you, with its number.
  - The current step is marked with a coloured bar and tint, steps behind you are ticked and dimmed, and the rest are
    slightly dimmed.
  - The list follows the guide, keeping the last 3 done steps above the current one. Scroll it with the mouse wheel or
    its scroll bar.
  - Right-click or double-click a step for its menu: "Go to step N", "Skip its quest...". It is the game's own drop-down,
    which pfUI skins.
- **The footer.**
  - **The cog** opens Settings; the **arrow**, **x**, **padlock** and grip are described under Latest changes.
  - **The grip** resizes the window, from 220 to 460 wide and 80 to 640 tall.

**Moving, locking, hiding.** Drag the step boxes, the list or the footer to move the window. Its place and size are saved.
**Lock the window** (the padlock, or Settings → Guide) stops moving and resizing.

**Other windows.** The tips box sits under the window and matches its width.

**Simple mode is gone.** Its quest list has no counterpart in RestedXP's layout. The "Simple mode" tick in Settings is now
"Lock the guide window".

**With pfUI's look:**

- The step box's gold border and the current step's bar are OctoPad's accent.
- The tick boxes and the list's scroll bar get pfUI's skins.

**Not taken from RestedXP:** no RestedXP code, textures or logos. Their art is RestedXP's branding, and their code is
CC BY-NC-SA. Only the layout and how it works were followed.

## Changed: skipping a step is one click

- **Skip step.** A **Skip step** button sits inside the step box, top right, next to the guide's name. On a step you
  tick yourself it reads **Mark done**.
- **Tick boxes in the list.** Every step in the list has a tick box:
  - Tick the current step to finish or skip it.
  - Tick a later step to skip it: the guide passes over it when it gets there. Untick it to do it after all.
  - Untick a step behind you to go back to it.
  - Right-click and double-click still open the step's menu.
- **Help and Welcome.** The "Quest data" and "Thanks to" lines are gone from these windows. Those credits are in
  `README.md`.

## Fixed

- **Text under a border.** The "Step X of N" badge and the Skip button sat across the step box's top border, as in
  RestedXP's layout, and the border showed through their text. Making the badge solid was not enough. Now nothing sits on
  a border:
  - The banner and the "Step X of N" badge are gone. The guide's details are in the step box's heading, and the list
    shows where you are.
  - The Skip button is inside the box.
  - "On the way" is a heading inside its box.
- **Step boxes against the list.** The step box sat right on the banner, so pfUI's borders, drawn outside each frame,
  overlapped. The boxes now keep 12 px from each other and from the list.
- **Guide menu too close.** "Pick a guide" sat 8 px from the guide window, so pfUI's borders, drawn outside each window,
  met or overlapped. It now opens 14 px away, or 24 px with pfUI's look.
- **pfUI look, gold borders.** Under pfUI's look, a gold border set before the theme was applied stayed grey instead of
  becoming the accent. The theme read only the first colour value.

## Tested

The harness was renamed along with the addon. Every check below ran on `pfQuest_xpGuide`:

| Check | Result |
|---|---|
| Guide window: smooth footer icons clear of borders, cog, arrow cycle, lock, hide, Unskip previous (with the skipped chain's steps and quest marks coming back), finished quests not skippable, chain steps tabbed in, list hold/follow, text size picker, Help pages, Human and Orc, with and without pfUI | all pass |
| Theme and close buttons, Human and Orc, with and without pfUI | all pass |
| brues pfQuest arrow (with and without pfUI) and real SmartArrow, Human and Orc | all pass |
| Nameplate markers, with and without pfUI | all pass |
| Short playthroughs with pfQuest and with pfUI, Human and Orc | clean |

The harness had a bug: it reported a quest's "complete" flag in the wrong return slot, so it never saw a quest as
complete. Now that it does, playthroughs advance much faster, and the arrow test plays 40 rounds instead of 300 so the
guide is still running when the test checks the arrow.
Only the likely set-ups were run this round, not the full 7-setup matrix.
Not tested: the real game client.

---

# Easy Route 0.9.9 (patched from 0.9.8)

## Fixed: "RouteRun.lua:552: attempt to call a number value" on the Casual route (issue #1)

**Cause.** The 1.12 client runs Lua 5.0. In Lua 5.0, `ipairs` is its own loop iterator. It only *starts* a loop when it gets
exactly one argument. Given a second argument, it assumes it is already mid-loop and returns `1, t[1]` instead of an iterator.

`ER.RouteReader.ReadVisit` returns two values (`areas, bad`). So `for _, area in ipairs(ER.RouteReader.ReadVisit(v))` hands
`ipairs` two arguments, and the `for` loop then tries to call the number `1`. Later Lua versions (5.1+) ignore the extra
argument, so the bug is invisible outside the game client. That is also why the Fast route (RestedXP guides) works: it never
reads a Casual-route visit.

The Casual route reads visits in several places (lines 133, 519, 552, ... of `RouteRun.lua`), so the error can surface at any
of them. In testing under exact Lua 5.0 `ipairs` rules, the original crashed on the Casual route for every race and every
difficulty, not only Alliance. A client where another addon replaces `ipairs` will not show it.

**Fix.** Every `ipairs` whose argument is a function call now gets that call wrapped in an extra pair of parentheses:
`ipairs((f(x)))`. This is the standard Lua way to keep only the first return value. 56 call sites in 9 files (Adapt, Auto,
Director, Grind, Recorder, RouteRun, Simple, Steps, Tracker) are covered, so a helper that gains a second return value later
cannot bring the bug back. Nothing else about those loops changed.

## New: Casual route for Turtle WoW High Elves and Goblins

The route plan has paths only for the eight original races, so High Elves and Goblins had no Casual route at all. They now
borrow a path of their faction once they leave their own starting zone:

- **High Elf** follows the Human path (Elwynn Forest, Westfall, Redridge, Duskwood, ...).
- **Goblin** follows the Orc path (Durotar, The Barrens, ...).

The route only starts by itself when the character is standing in a zone of that path, so nobody is pulled out of their
starting zone. Before that, it is available from the guide menu. The race name is matched with or without a space
("High Elf" / "HighElf").

## New: one arrow with pfQuest (brues-code fork)

With [brues-code/pfQuest](https://github.com/brues-code/pfQuest) installed, there are no longer two arrows on screen. Easy
Route hides its own arrow and steers pfQuest's world-space arrow instead.

**How it works.** Easy Route adds the guide's next place as a pfQuest map node with `arrow = true` and makes it the arrow's
target with `pfQuest.route.SetTarget`. This is the hand-off pfQuest's `route.lua` documents for addons such as TurtleGuide.
pfQuest's arrow then shows the step's words as its title, "Easy Route, <zone>" as its description, and its own distance. It
also points across zones on the same continent.

- **A pfQuest node you clicked is left alone.** Easy Route only clears the arrow's target when that target is still its own.
- **`/er arrow`** hides Easy Route's guidance as before. pfQuest's arrow then goes back to your nearest quest objective.
- **`/er stop`** clears Easy Route's node and target.
- **Fallbacks.** Easy Route shows its own arrow, as before, when:
  - pfQuest's arrow is switched off (`/db arrow`);
  - a pfQuest without the world-space arrow is installed (the original pfQuest, or no pfQuest);
  - you turn the feature off with **`/er pfarrow`** or the new **Settings → Helpers → Use pfQuest's arrow** tickbox.
- **Self-test.** `/er selftest` reports which arrow is in use.

When the guide's next place is on another continent, pfQuest's arrow points at your nearest pfQuest objective until you
cross over. The place stays marked on the map.

## New: route-aware arrow with pfQuest SmartArrow

With **pfQuest SmartArrow** installed and on, it plans the way to each place in your guide. SmartArrow then shows the
route in pfQuest's arrow, and Easy Route's own arrow stays hidden. The route uses:

- real zone exits, your flight paths, boats, zeppelins, the tram;
- walked roads and NPC patrol roads;
- paths around obstacles and away from hostile camps.

**How it works.** Easy Route hands the guide's place to SmartArrow through its public
`pfQuestSmartArrow:SetWaypoint(zone, x, y, title)`. That works on every pfQuest build SmartArrow runs on: brues-code or
lightblade, with or without ClassicAPI. It includes OctoWoW's lightblade pfQuest on a plain 1.12 client, where pfQuest's
own arrow can't be steered.

**How it behaves:**

- **The step's words are the arrow's title.** SmartArrow's line under it gives the way: "Go to Westfall via ...", "Fly
  to ...". The waypoint is marked like those of other guide addons, so there is no "Arrived at" line on every step.
- **Your own choice wins.** A waypoint you set with `/smartarrow way`, or a pfQuest node you click, is followed until you
  clear it. Then the guide's place goes back in.
- **Otherwise the arrow works as before:**
  - **brues pfQuest:** with SmartArrow absent, or switched off (`/smartarrow off`), pfQuest's arrow points straight at
    the place.
  - **Any other pfQuest:** with SmartArrow absent or off, Easy Route's own arrow shows.
  - **Easy Route's own arrow also shows** when pfQuest's arrow is off (`/db arrow`), when SmartArrow can't place the
    zone (a zone missing from its map data, such as a Turtle WoW zone), or when you turn it off with `/er pfarrow` or
    **Settings → Helpers → Use pfQuest's arrow**.
- `/er arrow` and `/er stop` clear Easy Route's waypoint.
- `/er selftest` says which arrow is in use.
- pfQuest-SmartArrow is an optional dependency in the `.toc`, so it loads first.

## New: pfUI's look, the OctoPad way

With pfUI loaded (made for the brues-code fork that OctoWoW uses), Easy Route's windows follow pfUI and OctoPad's design.
The new `Theme.lua` copies OctoPad's theme helpers.

- **Colours and font.** The background and border come from your pfUI profile, and the accent is OctoPad's cyan
  (`#33ffcc`). The font is pfUI's, at each text's own size.
- **Windows.** pfUI's rounded backdrop replaces every Blizzard dialog and tooltip border. The gold border that marks the
  step box and the tips box becomes the accent.
- **Buttons.** All buttons are OctoPad's flat buttons. Their border lights up in the accent on mouse-over, and a selected
  button gets an accent border, a tinted fill and accent text.
- **Other controls.**
  - Close buttons are OctoPad's flat "x", centred where each window put its own close button.
  - Checkboxes, input boxes and scroll bars use pfUI's own skins.
- **Icons and highlights.**
  - Icon buttons (the gears) get a rounded border and a cropped icon that lights up on mouse-over.
  - Icons (the book) are cropped pfUI-style.
  - List highlights are a soft accent tint, like OctoPad's focus tint.
- **Settings window.** It is laid out like OctoPad's settings:
  - a darker category sidebar on the left, with one button per page;
  - the title in the top left: "Easy Route" in the accent, "settings" and the version in grey;
  - each page under a small upper-case accent header with a thin accent line, and the page's description in grey.
- **Step window.** The "Step X of N" tab and the "x" overlap the step box's top edge. They are lifted above the box, so
  its border does not run through them.
- **Minimap button.** It sits on the edge of pfUI's square minimap, as OctoPad's does, unless pfUI's minimap module is off.
- **Without pfUI**, or with the look switched off, nothing changes: every window keeps its current look and the Settings
  page buttons stay along the top. To switch, use **Settings → Helpers → Use pfUI's look** or **`/er theme`**, then
  `/reload`.
- **How it reaches every window.** The theme recognises Blizzard's own textures, so windows only call it once. Windows
  are styled the moment they open and checked once a second for rows added later. Each window's own scripts are never
  replaced.
- pfUI is now an optional dependency in the `.toc`, so it loads first.

## Other

- Version is now 0.9.9 (`Core.lua`, `EasyRoute.toc`).
- No saved-variable changes; existing `EasyRouteDB` data, ratings and positions carry over.

## How this was tested

Outside the game, using a headless 1.12 stand-in. The addon ran under a Lua interpreter with:

- Lua 5.1+ library functions removed.
- Lua 5.0's exact `ipairs` behaviour.
- The WoW API and frames stubbed.
- pfQuest present and absent.

Scenarios:

- A full 1-60 playthrough for every race, five classes and all three difficulties.
- Switching from the Fast route to the Casual route from the guide menu.
- A fuzzer that runs every `/er` command and clicks every button and tooltip at levels 1, 25 and 50.

| | Original 0.9.8 | Patched 0.9.9 |
|---|---|---|
| Strict Lua 5.0 smoke matrix (120 runs) | 24 clean (only the races with no route) | 120 clean |
| Full matrix (700 runs) | not run | 700 clean |
| Smoke matrix with the brues pfQuest arrow (60 runs) | n/a | 60 clean |
| pfQuest arrow checks (6 races, about 280 places each) | n/a | all pass, 0 target mismatches |
| Regression with pfUI, and with pfUI + brues pfQuest (120 runs) | n/a | 120 clean |
| Theme checks (10 races, with and without pfUI) | n/a | all pass |
| With the real pfQuest SmartArrow 0.10.0 (10 races, about 90 places each) | n/a | all pass, 0 waypoint mismatches, a route planned every time |
| Regression: nothing, pfUI, SmartArrow, pfUI + SmartArrow (240 runs) | n/a | 240 clean |

The pfUI look was tested against a stand-in of pfUI's backdrop and skin helpers: what each control becomes, and that
nothing changes without pfUI. How it looks on screen has not been seen. pfQuest SmartArrow was tested with its real code, on a stand-in of the lightblade pfQuest on a plain 1.12 client
(SmartArrow's "maps" mode). The brues pfQuest arrow was tested against a stand-in of its `route.lua`/`map.lua` behaviour. The real fork needs the
ClassicAPI DLL, which can't run outside the game.

Not tested: the real game client, Turtle WoW's own custom zones and quests, how the borrowed paths play for High Elves and
Goblins in practice, and the real pfQuest arrow in game.
