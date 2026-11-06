# In-game test pass

The offline checks (`sh Tools/run_tests.sh`) prove the logic against a stubbed
1.12 API. They cannot prove that a window looks right, that a texture loads,
or that the server answers the way the stub does. This list is what only a
real client can check. Run it before a release.

**How to use it.** A ticked box has passed in game; an empty one has not been
tried yet, or has changed since it last passed (its wording changes with it, so
the old tick doesn't carry over). Say which ones passed and they get ticked
here. For anything wrong, add a screenshot, the version (Options → About), and
what the **Error log** says (Options → Maintenance).

Passed so far: the 2026-09-28 pass (sections 1–11 as they were then; party
sharing only lightly) and the Gear Finder tab at 0.22.1 (2026-10-01).
Screenshots at 0.22.23 (2026-10-03) showed the talent strips and marks on
Blizzard's window and with pfUI (the README's pictures); 0.22.24 tidied what
they showed, so those items wait for a look on 0.22.24. A screenshot at
0.22.24 shows Modern Spellbook's strip and marks (the README's picture).

Start with a **full client restart** (not `/reload`): new textures and files
are only found at startup.

---

## 1. Loading

- [x] The load message in chat names the version you installed.
- [x] No Lua error on login (the Error log is empty).
- [ ] `/apg` and `/pathfinder` open and close the guide; `/vg` is not
      Pathfinder's any more (the client says it doesn't know it).
- [ ] The guide, the options window and the guide browser fade in as they open.
- [ ] A character that used TurtleGuide, on a fresh install with no
      Pathfinder save, keeps its progress, and chat says it was imported.
- [ ] The minimap button is the Aegis: Pathfinder logo, round, in its own
      colours, no bigger than the other buttons round the minimap; hovering
      it shows a green ring and a tooltip.
- [x] Click toggles the guide; right-click opens the options; dragging walks it
      round the minimap and it stays there after `/reload`.

## 2. First-time setup (a new character, or `/apg setup`)

- [x] Step 1 offers only guides with a route for your race.
- [x] Step 2: turning **Solo Self-Found** on dims Auction House, Group quests
      and Dungeons, and they can't be clicked; off again, they come back as they
      were.
- [x] With Dungeons on (and Self-Found off) there is a step 3; the list shows
      levels and the quests each adds; Recommended / All / None work, and
      Recommended changes with the guide picked in step 1 (RestedXP ticks
      many, Optimized few). Untick the Deadmines: the Stockade says "(+4 with
      Deadmines)"; tick it again and the count goes back up.
- [x] Finishing a guide on RestedXP as a Human at 19 goes on to Redridge; as a
      Night Elf, to Darkshore/Ashenvale. On Optimized, finishing the 30 guide
      goes on to 30-31, and the 40 one to 40-41.
- [x] Finish: the chat line says what was set up, and the guide reloads.

## 3. The guide

- [x] A new character opens at step 1, not at the end.
- [ ] In a fight, Escape clears your target and the guide stays open; its ✕
      still closes it. Escape still closes the options and the guide browser.
- [x] Loch Modan (17-18), Crocolisk Hunting: Active Targets and the
      AegisTarget macro name Loch Crocolisk, not the Wetlands or Stranglethorn
      crocolisks.
- [x] The Macros window's AegisTarget tile, and the macro on an action bar,
      show Hunter's Mark's icon, not a blank square; AegisItem shows the quest
      item's own icon.
- [ ] Tick a few steps, then switch group mode or a dungeon chip: the ticks
      stay on the same steps, and after `/reload` too.
- [ ] The guide and Blizzard's windows: open the quest log over the guide,
      then click the guide -- it comes in front; click the quest log -- it
      goes back in front. The options window and guide browser still open
      over the guide.
- [ ] A new Goblin on Optimized: after Blackstone Island, The Barrens
      (12-15) starts at Razor Hill with Conscript of the Horde, and steps do
      not jump ahead with pfQuest on. A High Elf on Optimized Elwynn does not
      skip Alliance quests either.
- [ ] Full bags with a stack of greys and a single cheaper grey: Delete
      cheapest item offers the single one.
- [ ] Finish a guide at 39 or 42: Where next? does not offer Icepoint Rock.
      At 43 it offers Icepoint Rock (44-47), which starts with Crawling for
      Meat beside Inunquaq in northern Darkshore, then the Northeast Passage.
      A character that had Icepoint Rock (40-50) open keeps its tab and its
      place in it after the update.
- [ ] Boats: Optimized Darkshore (12-14) says to take the boat from
      Stormwind Harbor to Auberdine, not from Menethil. Its "Stormwind Harbor"
      steps tick on stepping into the harbor, and the boat lands at
      Auberdine. In RestedXP 13-15 Westfall and 16-19 Darkshore, the
      "wait for the boat" steps point at the docks the Stormwind boat really
      uses (Auberdine's at 32.4, 43.7 was the Menethil boat's).
- [ ] Tabs: a leveling guide says XP, a profession guide or crafting route PF,
      a dungeon guide DG, a class quest guide CL, a hardcore guide HC.
- [x] A guide opened partway -- Loch Modan (17-18) with Crocolisk Hunting in
      the log -- opens at that quest and stays there as the log updates and
      after `/reload`; it does not drop back to step 1, 0 done.
- [x] A quest with two things to collect (Crocolisk Hunting: meat and skins)
      shows a bar for each under the step, each filled to its count (4 of 5
      is four fifths full, 4 of 6 two thirds); a finished one stays, full.
      The guide's own progress bar under the step number matches "N of M".
- [x] The step's accent bar down the left edge runs on past the bars to the
      footer.
- [x] A step the addon ticks itself (a quest objective, travel with a waypoint
      addon) has a small ⟳ in its circle; a note has an empty circle; a done
      step is filled, with no ⟳.
- [x] Accepting, completing and handing in a quest ticks its steps by itself.
- [ ] Optimized Loch Modan, Bingles' tools (Bingles' Supplies): each of the
      four notes has a ⟳ and ticks when that tool is in your bags. Pick up
      one ahead of its note and it ticks as soon as the guide reaches it.
- [ ] A RestedXP "Grind to level 10" step (Teldrassil 6-11) has a ⟳ and holds
      the guide until 10, then ticks; an optional one ("Grind to 6", Elwynn)
      does not hold it.
- [ ] RestedXP 13-15 Westfall opens on "Travel to Elwynn Forest". Fly from
      Stormwind to Sentinel Hill: it ticks as you land, and the guide moves on
      to Farmer Furlbrow and follows the Westfall quests as you do them.
      Walking in through Elwynn ticks it too.
- [ ] RestedXP Hardcore 13-15 Westfall's "Travel to Westfall" ticks as you
      cross into Westfall, wherever you cross.
- [ ] On a travel step, talk to the next step's NPC: the quest is picked and
      accepted, and the guide moves past the travel step.
- [ ] Teldrassil (1-12), step 87 "Gnarlpine Hold" on a Night Elf Warrior,
      Hunter, Rogue or Priest: it ticks on entering Gnarlpine Hold. Click the
      Strange Fruited Plant: The Glowing Fruit is accepted and the guide moves
      on to Pools of Arlithrien.
- [ ] Collapse the quest log's header over a quest the guide is on: the
      header opens again within a moment, chat says why once, and the guide
      still ticks that quest's progress and hand-in.
- [x] ◀ and ▶ step back and on; the tick marks the step done.
- [x] Click ◀ a few times, then **right-click ▶**: back at your place, with the
      steps ticked as they were. Same the other way (▶ a few times, right-click ◀).
- [x] Right-clicking the arrow pointing away from your place says which to use.
- [x] Hovering ◀ / ▶ mentions the right-click.
- [ ] Hints over the guide open beside it, not over the steps: with the guide
      on the left of the screen, on its right, level with what you hover; on
      the right of the screen, on its left. Drag the guide wide across the
      screen: under it near the top of the screen, over it near the bottom.
- [x] Several tabs: open a second guide beside the first; each keeps its place.
- [x] Finishing a guide next to a custom zone at your level asks **Where next?**
- [x] The expand button swaps one step for the whole guide; the grip resizes it.
- [x] **Moonwhisper Coast** (52-60, both sides): Where next? offers it from 51;
      the arrow points where each step says. Its quest data is gathered by
      players, so note any step that sends you to the wrong place, any quest
      it never mentions, and any it asks for that you can't get. In Solo mode
      its bosses and what follows them are gone; in Group mode they are back.

## 4. Arrow and waypoints

- [x] With TomTom or pfQuest, the arrow points at the step and counts down the
      distance.
- [ ] With TomTom, a RestedXP "Travel to Kalimdor" or "Travel to Eastern
      Kingdoms" step (the Onyxia attunement guides have them) gets a pin on
      the continent's map, and TomTom's arrow and ours point at it. With
      only pfQuest there is no waypoint for the step, and nothing in chat.
- [x] Options → Navigation → Arrows: each switch turns its arrow on and off,
      and any two or all three can point at once. With TomTom taking the
      waypoints, pfQuest's arrow still points at the step when it is on.
- [x] pfQuest's switch off hides pfQuest's arrow altogether; `/db arrow` turns
      it back on and the switch shows it on. An addon that isn't loaded has
      its switch dimmed, and the note names it.

## 5. Options window

- [x] Opens beside the guide; categories down the left; the page shown is
      marked and named in the strip under the title.
- [x] Every page opens at its top; a long page (Gear) scrolls, a short one
      doesn't show a scroll bar.
- [ ] No label is cut off or crowded, on any page (Gear and Action Buttons especially).
- [ ] The pages are Route, Dungeons, Filters, Appearance, Step Display,
      Automation, Action Buttons, Navigation, Maps, Gear (Item Score under it),
      Extras, Maintenance, About; no Behaviour. Each setting that was on Behaviour is
      on its new page as it was set.
- [ ] Appearance → *Lock window* and *Transparency* do what the guide's ≡ menu
      does, and each shows what the other set.
- [ ] Automation → *All quests*: an NPC with a quest the guide does not want
      gives it, and takes a finished one; a grey quest is left; with 18
      quests in the log, nothing more is taken. Off: only the guide's.
- [ ] Automation → *Pick the guide's quest from an NPC's list* off: the list
      stays open for you; the quest you click is still accepted.
- [ ] Automation → *Take the step's flight*: on a "Fly to …" step, opening the
      flight master's map flies there. On a zone with two flight paths you
      know, it says to pick one.
- [ ] Automation → buying: on a buy step (Soothing Spices in Southshore), the
      vendor sells you what is still needed, and says so.
- [ ] The **Sell greys** button sits on the vendor window, clear of its
      title and items (with pfUI too), and sells the greys, saying for how
      much. *Sell greys automatically* does it as the window opens.
- [ ] *Repair automatically* → *With my own money* repairs at a repairing
      vendor and says the cost; not with too little money.
- [ ] Holding Shift as any of these windows opens: nothing happens by itself.
- [ ] Appearance → *Guide window opacity* changes how see-through
      Transparency makes the guide (held off while Transparency is off);
      *Guide browser opacity* fades the browser, and it fades in to that.
- [ ] *Step text size* at 140%: titles and notes bigger, rows taller, nothing
      overlapping, in focus mode and overview.
- [ ] *Show the progress bar* off: the bar goes and the steps move up.
- [ ] *Grow upward*: with the guide near the bottom of the screen, a long step
      grows it upward; drag it, reload, and its bottom edge is where you left it.
- [ ] *Hide the guide in dungeons and raids*: entering an instance hides it;
      leaving shows it again (or not, with *Show it again* off). A battleground
      leaves it alone.
- [ ] *Hide the guide in combat* (and the action buttons): gone in a fight,
      back after it; a guide you had closed stays closed.
- [ ] Step Display → *Steps shown in focus mode* 3: the step and the next two,
      under its objective meter.
- [ ] *Skip setting my hearthstone* / *Skip discovering new flight paths*: those
      steps leave the guide at once.
- [ ] *Party sync* off: no party icon; an invitation from a party member is
      declined with no popup.
- [ ] Action Buttons → *Active items grow* Left, Up, Down: the buttons run
      that way; drag the window, change it again, and it grows from the
      matching corner where you left it.
- [ ] *Button size* makes the three small windows bigger and smaller, on top
      of the window scale.
- [ ] Unticking *Talk to NPC* or *Kill enemy* takes those target buttons out;
      the AegisTarget macro still cycles them all.
- [ ] With bags full (a quiver's room doesn't count), a delete button with the
      cheapest grey appears after the items and deletes it; with no greys it
      asks first, naming the item and its price; *Keep it* keeps it.
- [ ] *Mark whoever the target buttons target* off: a target button targets
      without a raid marker; quest icons still mark on mouseover.
- [ ] Step Display → *Ask before inviting my party* off: the party icon shares
      without the popup; the popup's "don't ask again" turns it off here.
- [ ] Maps → *Reveal the whole map*: on a zone you have only partly explored,
      the rest shows, a little dimmer, lined up with what you have explored;
      off, it goes at once. With pfUI's own reveal on, only pfUI's shows.
- [ ] *Show the step on the map* (with pfQuest): on an accept step the giver's
      icon is on the zone's map, named on mouseover; on a kill step, spots
      where they are; a step whose note gives "(x, y)" has the note icon there.
      Another zone's map shows none of them.
- [ ] *A trail from me to the waypoint*: dots from you to the waypoint on the
      world map, marching toward it and following you as you move; *Dashes*
      draws dashes. With TomTom-TWOW loaded, dots on the minimap too, inside
      its edge, at every zoom and indoors.
- [ ] Extras → *Show Pathfinder chat messages* off, then `/reload`: no load
      message or progress summary; selling greys or taking a flight says
      nothing; a button with nothing to do still says why, and Rescan still
      answers.
- [ ] *Show detailed reputation gains*: a reputation quest's hand-in adds
      "Faction +N: Rank x / y, z to Next" after the client's line, with the
      numbers the reputation panel shows; also for a faction under a header
      you closed, which stays closed.
- [ ] *Announce level-ups to* Emote, ticked to start with: on a level up
      others nearby see "<you> Pathfinder: I just leveled up from X to Y!",
      with how long the level took (none for the level you installed on).
      Party and Guild, once ticked: "Pathfinder: I leveled up from X to Y!"
      there; nothing when you are in neither.
- [ ] **Talent Advisor** (Extras): on to start with. *Open the talent window*
      opens it (from level 10; before, it says when talents come).
- [ ] The talent window opens on the tree your next point goes to. Each of its
      talents in the build has a badge with the build's points: green while
      some are to take, a tick once you have them; the next one has a gold
      ring with NEXT over it, clear of the badge on its top right, and its tab
      a gold dot and light. Click another tab: its talents are marked, no
      ring, the tab stays lit.
- [ ] The strip above the window: PATHFINDER, *Following* and the build on one
      row; under it a card with the talent's icon in gold, "Take <talent>" and
      "Rank r of n in <tree> · 1 point to spend" ("Next: <talent>" and "… at
      level N" without a point). Neither line is cut short. It sits on the window's top
      edge, as wide as it, and moves with it; with pfUI, on pfUI's frame.
- [ ] Level up (10+) with the talent window shut: a card at the bottom right,
      "Level N: a talent point", the talent to take, *Open talents* and
      *Later*; Open talents opens the window and the card goes. Later puts it
      away; left alone it goes in half a minute. The talents button on the
      action bar glows gold with the points to spend on it until they're
      spent. Neither with *Point out a talent point* off.
- [ ] **With Modern Spellbook** (and `/msb talents` on): open the talents. A
      strip over its window: PATHFINDER, *Following*, the card, and *Plan to my
      level*, *Whole build as a plan*, *Share*. The menu and the card's two
      lines are not cut short, and the card reaches the buttons. Every tree's
      talents have their badges, the next one the gold ring and NEXT (clear of
      its badge), and its tree "NEXT POINT HERE" by its name. Expand a tree:
      its talents are marked too. Switch it to a plan: the marks go, the strip
      stays.
- [ ] Modern Spellbook: *Plan to my level* -- chat says "Saved "Pathfinder: …
      to <level>" in Modern Spellbook's plans: N points"; its window shows the
      plan, its list has it, and its *Apply* learns the points. *Whole build as
      a plan*: 51. Pressing either again replaces the same-named plan.
- [ ] Modern Spellbook: *Share* opens Share and plan with the build's string
      selected; Ctrl+C copies it, typing over it does nothing. Paste it into
      Modern Spellbook's Import: the same build. Paste a friend's string (or
      one Modern Spellbook's Share gives for a plan you made) into *Follow a
      shared build*: "Following it", the menu says Shared build, and the marks
      follow it. Another class's string says so.
- [ ] Put a point where the build doesn't: that talent's badge says "+1" in
      amber, the strip "1 point off the build. It carries on from the closest
      point.", and the glow moves to the build's next point you can take.
- [ ] Hover a talent in the build: the tooltip ends "Pathfinder: <build> puts N
      points here." (": done." once you have them), and "Your next point goes
      here." on the glowing one.
- [ ] Pick another build from the strip's menu: the marks follow it, and the
      Extras page's *Build to follow* shows it; and the other way round.
- [ ] Warrior or Paladin: the menu has "Protection leveling, then <spec> at
      60" and "<Class> Protection leveling"; a Druid "Bear leveling, then …" and
      "Druid Bear leveling". Picking one marks Protection's (or Feral's)
      talents from 10. A character that followed Sword and Board on 0.22.23
      follows Protection on 0.22.24 with nothing to pick, and its Modern
      Spellbook plan is "Pathfinder: Protection leveling to <level>".
- [ ] Switch the Talent Advisor off: the window has no strip, badges or glow,
      and the tooltip no line, at once. On again: back.
- [ ] Level up (10+): "Level N: a talent point to spend. Take <talent> (rank r
      of n) in <tree>." in chat; nothing with *Name the talent to take in chat*
      off.
- [ ] At 60, spend the 51st point on the levelling build: chat says once that
      your spec's build is ready; the strip says so, and the menu reads
      "Leveling (done), then <spec>". After a respec it follows your spec's.
- [ ] `/apg talents` says it saved your class's trees, with each tree's number
      of talents and the classes saved so far; after logging out, the saved
      settings file has them under `talenttrees`, with each talent's tooltip.
- [ ] *Rare creatures near my level*: rare icons on the zone's map at a few
      levels either side of yours (Westfall at 18: Foe Reaper 4000), named
      with their level on mouseover; *Icon size* and *See-through icons* change
      them at once.
- [x] Drag the corner grip: the window grows wider and taller, and every page
      re-lays itself without gaps; it keeps the size after `/reload`.
- [x] `/apg resetpanels` puts it back to its first size and place.
- [x] A dropdown left open closes when you change page or close the window.
- [x] **Filters**: turning Solo Self-Found on holds Group mode, Auction House
      and every dungeon chip off (dimmed, unclickable), and the Dungeons page
      says why; off again, they are as they were.
- [x] **Appearance**: each theme recolours everything at once, no reload.
- [x] Switches follow the theme; RavenCraft's on switch is near white. Turn on
      **Red and green switches**: every switch is green when on and red when
      off, in every theme; off again, they follow the theme. It is kept after
      `/reload`.
- [x] Drag the **Scale** slider: only its number moves while you hold it; let
      go and every window takes that size. It never jumps to 60%.
- [x] **Route**: the preview reaches the bottom of the page; drag the window
      taller and it shows more legs.
- [x] **Dungeons**: Turtle WoW's own dungeons have chips. Turn on *Offer
      dungeon guides along the way*, tick one at your level, and finish a
      guide: Where next? lists its dungeon guide under the custom zones, and
      it opens in a tab beside the route.
- [ ] **A dungeon at your level**: with The Deadmines or Wailing Caverns ticked
      in the setup, level up to 21 (their guides say 17-24): a small window
      offers the dungeon guide. Open puts it in a tab beside the route; Not now
      closes it, and it is not offered again after a `/reload` or relog.
- [ ] **Boss steps**: open The Deadmines' guide. After the entrance there is a
      step for each boss, Rhahk'Zor to Cookie; Kill Edwin VanCleef comes
      straight after VanCleef's step on the run the quest sends you in; Miner
      Johnson's says he is rare, and is passed over. Hover Mr. Smite's step:
      the note, then Tank (blue), Healer and Damage (red) lines. Turn on focus
      mode: the same lines under the step.
- [ ] Options -> Dungeons -> **My role in dungeons**: All roles to start; pick
      Healer and only the Healer line shows, on the tooltip and in focus mode,
      at once. Back to All roles.
- [ ] Kill a boss with his step showing: it ticks itself, and the guide moves
      on. In Blackrock Depths, the Seven's step ticks on Doom'rel, not before.
- [ ] A Turtle WoW boss with no data (Jared Voss in The Deadmines) says
      "Pathfinder has no notes on this fight yet." and still ticks on his
      death.

## 5a. The guide browser (the `+` on the tab bar, or ≡ → Guide menu)

- [ ] It opens on HOME, beside the guide, and fades in. Its header, sidebar,
      middle and right pane line up, and the sidebar's and right pane's
      bottom corners follow the window's rounded ones.
- [ ] HOME: Guides history lists what you opened last; Suggested guides
      lists your route's next leg, a class quest, ticked dungeons and custom
      zones at your level, each with why; Level tracker counts up the level
      you are at, and See more lists every level; Gold tracker rises when you
      loot or sell, in gold, silver and copper colours, and starts again
      tomorrow.
- [ ] The ⋮ on HOME hides and shows each panel; the rest move up.
- [ ] Each category opens; Leveling's folders open into their guides
      (Optimized → Levels 20-40), and the back chevron comes back up. The
      Coming Soon rows are greyed, and say so when pointed at.
- [ ] Pointing at a guide shows it on the right. **Check the pictures load**:
      a zone guide (Optimized → Darkshore) shows Darkshore's map fully
      explored -- the areas in their places, no gaps between tiles; a city
      guide's map whole; a dungeon (The Deadmines, Scarlet Monastery) its
      loading screen, not stretched; a class quest (Voidwalker) the class
      crest in the corner, the panel in the class's colour, the spell in the
      middle; a profession its icon. Note any that are blank.
- [ ] Every custom zone (Northwind, Gilneas, Tel'Abim, Moonwhisper Coast,
      Scarlet Enclave and the rest) shows its own map, whole, with no
      glitches.
- [ ] Every dungeon shows the loading screen Turtle WoW shows on the way in,
      whole, not squashed, with no logo or bars.
- [ ] Dungeons starts with **On the routes**: Optimized's Uldaman and Sunken
      Temple, each saying whose route; they are no longer in Optimized's
      Levels 40-60.
- [ ] Point at a guide in a list that says something on the right (Raid,
      Dungeon, a percentage): its star and arrow come up and the words move
      left of them, nothing overlapping. A favourite's star stays, the words
      beside it.
- [ ] Next under Dungeons, **Attunements and keys**: the raids first (Onyxia's
      Lair, Molten Core, Blackwing Lair, Tower of Karazhan, Emerald Sanctum,
      Lower Karazhan Halls, Naxxramas), then the dungeons' keys, each saying
      Raid or Dungeon, then RestedXP's Onyxia Attunement and Scholomance Key,
      saying RestedXP. Each of ours has an orange AT badge on its tab.
- [ ] Follow an attunement you have done (Attunement to the Core, say): the
      folder says **Attuned**. One you have started is on Home's suggestions.
- [ ] An Alliance Onyxia attunement sends you to Bolvar in Stormwind Keep and
      to Reginald Windsor at the gates of Stormwind. Note any step that sends
      you somewhere wrong in Turtle WoW's own chains (Emerald Sanctum, both
      Karazhans, the Crypts).
- [ ] Click a guide (left or right) or **Open in a new tab**: it opens in a
      new tab, and the guide you were on keeps its tab and place. A RestedXP
      guide does the same and leaves the route pack as it was (Options ->
      Route). Shift-click resets a finished guide.
- [ ] On Optimized Redridge (18-20) at 20, take a class quest guide (a
      paladin's Tome of Valor) to its end: its tab closes and you are back on
      Optimized Redridge, whatever the route pack.
- [ ] The row's star keeps a guide in Favorites, and stays lit there; the
      arrow opens it.
- [ ] The list's ⋮: colours by level (grey outlevelled, green in range,
      yellow, orange, red), ticks on finished guides, hiding finished and
      outlevelled ones, stars on suggested ones -- each switch takes at once
      and is kept after a `/reload`.
- [ ] Typing in the search box lists the guides with that in their name;
      Escape clears it and goes back to where you were.
- [ ] CURRENT lists the guides open in the guide window, the route first;
      RECENT the ones opened lately, by category.
- [ ] The corner grip resizes it (no smaller than 820x520); the list shows
      more rows as it grows; it reopens at that size and place, on the tab or
      category it was left on.
- [ ] **Return to Main** shows in the header while a guide is open beside
      the route, and takes you back.

## 5b. The guide window's ≡ menu

- [ ] The ≡ chip opens the menu under it, above every window; Escape and any
      item but the two switches close it.
- [ ] Guide menu opens the browser; Setup wizard the setup; Settings the
      options, all beside the guide.
- [ ] Lock window: the guide cannot be dragged and its grip is gone; untick
      and both come back; kept after a `/reload`.
- [ ] Transparency: the panel's body goes see-through and its shadow goes;
      kept after a `/reload`, and it survives a theme change.
- [ ] Reset window puts the windows back, the browser at its own size.
- [ ] Reload reloads the UI.

## 5c. Class quests

- [ ] The guide browser's Class Quests lists your class's guides only, lowest
      level first.
- [ ] A Goblin warlock's **Warlock: Voidwalker (10)**: Dabbling In Darkness on
      Blackstone Island, then Gan'rul Bloodeye in Orgrimmar; an Undead's goes to
      Carendin Halgar in the Undercity. Each quest's steps tick as you go, and
      the guide finishes by itself on the last hand-in.
- [ ] A Human warrior's **Warrior: Defensive Stance (10)** starts in Goldshire:
      A Warrior's Training from Lyria Du Lac, then Stormwind for Harry
      Burlguard. A Horde warrior's takes Veteran Uzzek from Tarshaw Jaggedscar
      in Razor Hill; an Undead hunter's The Hunter's Path from Dark Ranger
      Lanissa in Tirisfal Glades; a Gnome hunter's from Thorgas Grimson in Dun
      Morogh. A Night Elf's Elanaria is still pointed to in Darnassus.
- [ ] On a character whose route does not take it (RestedXP or a zone guide),
      reaching a class quest's level brings **A class quest at your level**:
      Open puts the guide in a tab beside the route, and finishing it brings
      you back to the route. Not now closes it, and it is not offered again
      after a `/reload`.
- [ ] On the Optimized route, whose legs take a warlock to the Voidwalker, it
      is not offered.
- [ ] Reaching the middle of a ticked dungeon and a class quest's level at the
      same level up: the dungeon's window first, the class quest's when you
      close it.
- [ ] Options → Step Display → *Offer class quests at their level* off: nothing
      is offered.
- [ ] A chain with a dungeon or raid in it (the Charger, Rhok'delar) is offered
      only in Group mode.
- [ ] A step whose quest is inside a dungeon points the arrow at its door
      (the Charger's Scholomance step).

## 6. Gear

- [x] Item tooltips show the item score line: `+12%` green for an upgrade,
      red for worse, *empty slot*, *not for you*.
- [ ] As a healer (Holy priest, Restoration druid or shaman, Holy paladin):
      an item with "Restores 8 mana per 5 sec." scores more than one with 4
      (both used to read as 5), and a "+damage and healing" item scores close
      to a "+healing" one of about twice the number, not a third of it. As a
      warrior, a caster's spell crit item scores nothing for crit.
- [x] **Item Score** page (under Gear): the spec picker, every weight on one
      line each (no wrapped names), editing a box changes the tooltips,
      Show all stats lengthens the page, Export → Import round-trips.
- [ ] Below 60 the Item Score page says *Leveling weights, until level 60*;
      at 60 it says *Level 60 weights* and the boxes change -- on reaching 60
      too, without a reload. As Protection or a bear: *Tank weights, the same
      at every level*, at any level.
- [ ] A hunter: a bow's tooltip line weighs its DPS far above a melee
      weapon's of the same DPS (*Ranged Weapon DPS* on the Item Score page).
      A caster below 60: a wand's DPS counts.
- [ ] With weights changed before 0.23.4: one chat line at login says they
      were cleared, and the page shows the defaults; not again at the next
      login. A change made below 60 is gone at 60, and back below it.
- [ ] **Reset weights** puts a changed set back to the defaults, and the page
      says so.
- [ ] Export holds every stat; pasted into OctoPawn, its weights match.
- [x] `/apg gear` opens the options at Item Score, and again closes them.
- [x] Gear Advisor: loot an upgrade → a pop-up with Equip / Decline; Equip puts
      it on; Decline is remembered; in a fight Equip waits.
- [x] A quest with reward choices: the best one is marked.
- [x] Upgrades are bordered in the bags.

## 7. Gear Finder (`/apg finder`)

- [x] The character panel has a **Gear Finder** tab after Honor (after
      Reputation's neighbour when there is no Pet tab), looking like the
      others; clicking it shows the Gear Finder over the panel, wider than
      it, with the tabs still underneath.
- [x] Only the page's own ✕ shows at its top right, not the character
      panel's as well; back on the character sheet, the panel's ✕ is back.
- [x] Clicking Character, or pressing C, goes back to the character sheet;
      the ✕ and Escape close the panel.
- [x] Dragging the page moves the character panel, with or without pfUI.
- [x] With **pfUI**: the tab is skinned like pfUI's tabs and sits in their
      row, and the page lines up with pfUI's panel.
- [x] At a levelling character: a cell per slot with its biggest upgrade,
      the gain, where it drops, and *at level N* for one you cannot wear
      yet; *No upgrade found* with the slot's empty picture where there is
      none; *Empty slot* for a slot you wear nothing in. Long names end in
      "..." rather than running into the next line.
- [x] Hovering a cell shows the item's tooltip.
- [x] Clicking a cell opens its list beside it: every upgrade, biggest
      first, with the drop chance; picking one marks the cell *Your pick*,
      and **Clear my pick** undoes it. A pick survives a /reload, and goes
      once you equip the item.
- [x] The suggested dungeon shows its loading screen, the dungeon with most
      of the cells' items, its levels and slots; the arrows step through the
      rest and go round; picks that move the most upgrades elsewhere change
      it at once. **Open the guide** opens that dungeon's guide.
- [x] The spec dropdown changes the spec, and the cells follow. A spec with
      no dungeon to suggest keeps the dropdown, to switch back.
- [x] Slots fill from dungeons unticked on the Dungeons page too, and from
      quest rewards (most need no level).
- [x] Quest, reputation and crafted gear (*Quest: …*, *Revered with …*,
      *Blacksmithing 300 …*) have cells but are never the suggestion.
- [ ] Options → Gear: **Upgrade sources** has five boxes, two to a row:
      **Dungeons**, **Raids**, **Quest rewards**, **Reputation vendors**,
      **Crafted gear**, the last three ticked as their old switches were.
      Dungeons alone: only dungeon drops in the cells. Ticking Raids says in
      chat it takes a minute or two, and the cells fill in as items load.
      With nothing ticked the footer says it has nowhere to look. The cog in the footer opens the options at this
      page, whether or not they were open.
- [x] At 60: every dungeon, Turtle's own included; Molten Core shows Turtle's
      bosses (Incindis, Basalthar).
- [x] Walking into a dungeon names its upgrades in chat.
- [x] Switching the Gear Finder off in the options takes the tab away.
- [x] With Solo Self-Found on: no dungeons, and crafted gear only from your own
      professions.

## 8. Professions

- [ ] A profession guide from the guide browser advances on your skill.
- [ ] First Aid: 41 Linen Bandages to 40, then Heavy Linen to 50, Journeyman
      at 50 (not before), Heavy Linen on to 80, Wool to 115.
- [ ] A crafting guide's first step says the route is CraftRoute's; each
      craft step's count is enough for its skill points (Jewelcrafting no
      longer asks for 10 Malachite Rings for 50–70), and extra crafts a later
      recipe uses say "Keep them for".
- [x] **Shopping list** (`/apg materials`): counts what your bags hold, and
      **This step** / **Whole route** switch.
- [x] **Cheapest route** (`/apg craft`): plans, **Scan prices** at the auction
      house fills prices in, **Load as guide** adds the planned guide.
- [ ] Cheapest route for Survival from 90: no step asks for 92 Hunting Spears
      (or 92 Iron Lanterns at 160). The total is what the route costs; the
      breakdown says "leftovers sell for about …" beside it, and turning *Say
      what a merchant pays for what is left over* off takes that line away
      without changing a single step.
- [x] With Aegis: Exchange loaded: **Send to Exchange** puts the crafts on its
      Crafting tab, and Remove takes them back out.

## 9. Quest helpers

- [x] **Active Items**: a button for the step's quest item; clicking uses it.
- [x] **Active Targets**: a button for the step's NPC or mob; clicking targets
      and marks it.
- [x] Quest icons: mousing over a quest NPC or mob puts the right raid marker
      on it (star to talk, skull to kill, cross to loot, square to interact).
- [ ] Close the guide with its ✕ (or close every tab, so no guide is loaded):
      mousing over or targeting a quest mob leaves it unmarked. Open the guide
      again: it is marked. With *Hide the guide in combat* on, a quest mob you
      target in a fight is still marked.
- [x] **Macros**: AegisTarget and AegisItem appear in your character macros and
      follow the guide from an action bar.
- [ ] Drag Active Targets close under or beside Active Items (or the guide):
      let go and it snaps flush against it, lined up; dropped further away, it
      stays where you put it. After `/reload`, still there.
- [ ] Close the guide (its ✕, or the minimap button): the action buttons go
      too, and come back when you open it. In combat with *Hide the guide in
      combat* on and *the action buttons too* off, they stay.
- [ ] With several of a step's mobs around (Crocolisk Hunting), AegisTarget
      takes the nearest, each press after it the next one out, then back to
      the nearest; a dead one is skipped; targeting something else first, the
      next press starts at the nearest again.

## 10. Party sharing

- [x] In a party, the party icon asks to share; your partner gets a pop-up and
      the guide opens in a new tab.
- [x] Each of you shows under the step with your progress; a finished step
      waits for the other.
- [x] Leaving the group stops sharing.

## 11. The rest

- [x] Options → About → **Credits** opens beside the options and closes with
      them.
- [x] Options → Maintenance: **Rescan progress**, **Error log**, **Run setup**.
- [x] The slash commands in the README all do what they say.
