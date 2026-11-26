# OctoPad

A gamepad layer for **OctoWoW** and other 1.12 (Interface 11200) servers. It lets you play, navigate
windows and manage your bags with a controller and minimal mouse or keyboard use. The settings and
overall design follow [ConsolePort](https://github.com/seblindfors/ConsolePort); the key layout follows
[ConsoleExperienceClassic](https://github.com/pepordev/ConsoleExperienceClassic).

> **Status: untested in-game.** Written against the 1.12 API and OctoWoW's protected-function rules and
> checked for structure only. `/opad debug` and the System page show what the addon sees.

## Features

- **Context-aware buttons.** Every button has a *game action* and a *window action*. B can cast an ability
  and also close the bag or map when one is open.
- **Window navigation.** Bags (default, pfUI, Bagshui), map, character, spellbook, merchants, quests,
  popups, the game menu and more are driven by a focus ring and the D-pad.
- **Smart default focus.** Quest windows start on *Accept* or *Complete Quest*, gossip on *Continue*,
  popups on their main button.
- **Soft target.** The nameplated unit nearest the screen centre gets a slowly pulsing
  name in red / yellow / green by reaction and the game's mouseover tooltip with your quest kill counts.
- **Smart target** for spells, buffs, attacks, pets and items, each category switchable.
- **Thumb-stick radial menu** for character, spellbook, talents, bags, quests, map, OctoPad settings and
  the game menu.
- **Button hint bar** showing what each button does for the open window.
- **ConsolePort-style settings**: a category sidebar, a controller diagram for editing buttons (d-pad and
  face-button crosses with LB / RB in the middle, following the selected controller), and LB / RB to
  switch categories.
- **pfUI theme.** Background, border colour and font follow your pfUI profile, and the settings window,
  its buttons and highlights, the HUD buttons (including LB / RB in the cross centres), hint bar, radial,
  soft-target card, icon picker and focus ring use pfUI's rounded backdrop. A neutral flat theme is used
  without pfUI.
- **Controller glyph icons** (Xbox, PlayStation, Switch Pro) in the HUD, hint bar and settings.
- **Icon picker** for system actions, like the macro icon dialog.
- **Secure mode.** Jump, Run and targeting use Blizzard's own key commands, so OctoWoW's
  "blocked from an action only available to the Blizzard UI" popup does not appear.
- **HUD** with two independent crosses (d-pad and face buttons), per-button size and position, and
  pfUI-aware positioning.
- **Profiles:** Console Experience and WoW: Forever. **Glyphs:** Xbox, PlayStation, Switch Pro.
- **Minimap button.**

## Install

1. Copy the `OctoPad` folder to `Interface\AddOns\`.
2. Log in. On first run OctoPad applies the controller keys and says so in chat.
3. Click the minimap button or type `/opad` to open settings.
4. Drag abilities onto the HUD buttons (or pick one up and click a button).

Disable ConsoleExperienceClassic first, since both use keys 1-0. OctoPad detects it and leaves your keys
alone while it is loaded (`/opad bind force` overrides this).

Optional: **pfUI** (positioning and skin), **SuperWoW** (full soft-target tooltips),
[Interact.dll](https://github.com/luskanek/Interact) (a real Interact action).

## Steam Input setup

The 1.12 client has no gamepad API, so a tool outside the game turns controller buttons into keys.
Steam Input is the easiest. This matches the ConsoleExperienceClassic Steam layout.

| Controller input | Send this key |
|---|---|
| Face buttons: bottom / left / top / right | `1` / `2` / `3` / `4` |
| D-pad: Down / Left / Up / Right | `5` / `6` / `7` / `8` |
| Right bumper (RB) | `9` |
| Left bumper (LB) | `0` |
| Left trigger (LT), held | `Left Shift` |
| Right trigger (RT), held | `Left Ctrl` |
| Start / Menu / `+` | `Shift` + `Escape` (radial menu) |
| Select / View / `-` | `M` (world map) |
| Left stick | `W A S D` |
| Right stick | Mouse, plus a held key for the camera (see below) |
| Left-stick click | `Num Lock` (auto-run), optional |

Face buttons are listed by physical position. AntiMicroX or JoyToKey work with the same table.

### Manual setup in Steam Input (no template)

The same steps are on the **Steam setup** page of OctoPad's menu. Steam's menu names can differ slightly between versions.

1. Add WoW to Steam: *Games > Add a Non-Steam Game to My Library*, browse to `WoW.exe`. Always start the game from Steam.
2. In the Library, right-click the game > *Properties > Controller*: **Enable Steam Input**.
3. In game, press the Steam / Guide button > *Controller Layout > Edit Layout*. If no template is offered, choose
   *Templates > Keyboard (WASD) and Mouse* and change it as below.
4. Face buttons, bumpers and D-pad: the keys in the table above (face buttons by position).
5. Triggers: set *Full Pull* to Left Shift (LT) and Left Ctrl (RT), held.
6. Start: Left Shift + Escape (use *Add extra command*). View / Select: M.
7. Left stick: *Directional Pad* with W A S D, click = Num Lock. Right stick: *Joystick Mouse*, with **`** (held) on its
   outer ring / soft press and no right mouse click (see below).
8. Switch Pro with Steam's *Use Nintendo Button Layout* on: choose the "Switch Pro (Nintendo)" style on the Overview page.
9. Save the layout (*Export Layout*, personal), then press **Apply** on the Overview page. *Last input* shows each press.

### Right stick camera without clicking things

If the right stick holds the **right mouse button** to turn the camera, the game sees every release as a
right-click on whatever was under the cursor, and targets, attacks or talks to it. OctoPad has a camera
key that turns the camera with no mouse button at all:

1. In game the key is **`** (backtick / grave) by default, bound automatically when it is free. Another key:
   `/opad camerakey <KEY>` (also under Key Bindings, *OctoPad - Extras*, *Camera (hold)*). Avoid F12, Steam's screenshot key.
2. In Steam Input, on the right stick: keep the output as **Mouse**, and where it sends **Right Mouse Click**
   while the stick is pushed (for example the outer ring or a touch/soft-press activator), send **`** instead, held.

While a window or OctoPad's menu is open the key does nothing, so the stick simply moves the cursor there.

## Settings

Open with the minimap button or `/opad`. **LB / RB** switch categories when the menu has focus.

| Page | What it holds |
|---|---|
| **Overview** | Binding status, last input, detected addons, controller style, profile, Apply / Repair / Remove, auto-repair, secure mode |
| **Bindings** | Controller diagram (d-pad cross with LB, face cross with RB) and a layer selector (None / LT / RT / LT+RT). Click a button to set its game action, window action and icon |
| **Interface** | Window navigation, smart focus, hint bar, adding windows, listing recognised windows |
| **World** | Soft target, radial stick, chord layer |
| **HUD** | Visibility, scales, position, layout editor, selected-button size and nudge |
| **System** | Minimap button and shape, resets, diagnostics |

Minimap button: left-click settings, right-click show / hide HUD, shift-click radial, drag to move.

### Editing bindings

Open the **Bindings** page, click a button on the controller diagram (each shows what it does), then click its **Game action**
or **Window action** row. A picker opens with icons grouped into Move / Target / Combat / Menus; click one to assign it, or
choose Default / None. Clicking an already selected button opens its game-action picker straight away. The picker's **Change icon...** button (for system actions) opens the icon chooser. **Hold** selects the layer: None (nothing held), LT, LT + RT or RT. In the Selected button section, click the action's icon to change the icon, or its name button to pick another action. The window action's keycap icon opens the window-control icon chooser (**Chevron**, the default; Retro keyboard; or pfUI colours), which applies to every window control on the HUD too.

## Context-aware buttons

Each of the 40 slots has two assignments:

| | Runs when | Examples |
|---|---|---|
| **Game action** | no window has focus | an action bar ability, Jump, Target enemy, Map |
| **Window action** | a window is open | Confirm, Back, Up / Down / Left / Right, Next / Prev tab, Right-click, Shift-click, Scroll |

Defaults for the buttons without a trigger held:

| Button | Window action |
|---|---|
| A | Confirm (click) |
| X | Right-click |
| Y | Shift-click |
| B | Back / close |
| D-pad | Move focus |
| RB / LB | Next / previous tab |
| LT + D-pad Down / Up | Scroll |
| LT + Y | Destroy the focused bag item |

While a window is open the HUD tiles switch to keycaps (ENTER, ESC, arrows, TAB, SHIFT, PG, DEL ...) showing their window action: retro beveled keys normally, flat rounded keys in your pfUI colours when pfUI is loaded.

### Bars

| Button | Key | None | LT | RT | LT+RT |
|---|---|---|---|---|---|
| A (bottom) | 1 | 1 | 11 | 21 | 31 |
| X (left) | 2 | 2 | 12 | 22 | 32 |
| Y (top) | 3 | 3 | 13 | 23 | 33 |
| B (right) | 4 | 4 | 14 | 24 | 34 |
| D-pad Down | 5 | 5 | 15 | 25 | 35 |
| D-pad Left | 6 | 6 | 16 | 26 | 36 |
| D-pad Up | 7 | 7 | 17 | 27 | 37 |
| D-pad Right | 8 | 8 | 18 | 28 | 38 |
| RB | 9 | 9 | 19 | 29 | 39 |
| LB | 0 | 10 | 20 | 30 | 40 |

Slot numbers match ConsoleExperienceClassic. Bar 1 follows your stance or form bar.

## Window navigation

When a window opens, a bright pulsing focus ring (border, glow and a light tint) lands on its most likely button (small items such as bag slots also get an intense outer glow; larger interface elements get the border and a tint covering the ring) and shows that element's tooltip.

| Control | Result |
|---|---|
| D-pad | Move the ring to the nearest clickable element in that direction |
| A | Click |
| X | Right-click (use, equip, sell, buy) |
| Y | Shift-click (split stack, link) |
| B | Cancel the item on the cursor, then close the window |
| RB / LB | Next / previous tab |
| LT + Up / Down | Scroll the focused list |

- **Smart default focus** (also when a quest or gossip window opens while a bag is already focused, e.g. a quest started from an item): *Accept* on a new quest, *Complete Quest* when turning in, *Continue* on
  gossip and quest progress, the main button on popups, and the **Hearthstone** in bags. Otherwise the
  first element.
- **Loot rolls** (Need / Greed / Pass, including rare and unique items and the "will bind it to you"
  confirmation) are navigable: the ring starts on Need (Greed if Need is not allowed). Blizzard's roll
  frames and pfUI-style roll windows are recognised. While a roll is open your buttons act as window
  controls; choose or Pass to get your abilities back.
- **Stack splitting** (Shift-click / Y on a stack): the split window is driven directly. D-pad Left / Right
  change the amount by 1, Down / Up by 5, A confirms, B cancels. While it is open it no longer captures
  the number keys, so the controller keys reach OctoPad.
- **Popups and drop-downs** are modal: only their buttons are focusable. A accepts, B cancels.
- **World map:** D-pad Left / Right changes continent, Up / Down changes zone, A zooms to your zone,
  X / B zoom out.
- **Destroy item:** with the focus ring on an item in a bag or bank (default bags, pfUI, Bagshui), press
  **LT + Y**. OctoPad picks the item up (through the game API, so the held LT / Shift does not turn it into a split) and asks "Destroy <item>?"; A destroys it, B cancels and puts it back.
  The hint bar shows *Destroy* when an item is focused. Reassign it under Bindings > Window action
  (*Destroy item*). If the client blocks `DeleteCursorItem` the function is logged under `/opad debug`.
- **Moving items:** A on a bag slot picks the item up, A on another slot drops it.
- **Bag addons:** default bags, pfUI bag and bank, and Bagshui are recognised. Other inventory windows are
  detected automatically (a visible frame named like bag / bank / inventory / backpack / keyring with at
  least three item slots). To add one by hand, use *Add window under mouse* or `/opad window <FrameName>`.
  `/opad windows` lists what is recognised.
- **Hint bar:** a strip at the top of the screen shows the current Confirm, Back, Right-click, Shift-click
  and tab buttons as glyph icons for your controller. The Confirm label follows the focused button (Accept, Complete Quest ...). Right-click and shift-click hints only appear on item slots.

### Lists: trainers, professions, auctions, mail

Opening a trainer puts the focus on the first skill you can learn (or on **Train** when one is already selected).
Professions and crafting land on the craftable recipe that still gives skill-ups (orange, then yellow, green, grey),
or on **Create** when a craftable one is selected. After you pick an entry the focus jumps to the button that acts on it:

| You pick | Focus moves to |
|---|---|
| Quest reward | Complete Quest |
| Trainer skill | Train |
| Recipe (professions, enchanting, pet training) | Create |
| Auction (browse / bids) | Buyout, else Bid |
| Your auction | Cancel Auction |
| Mail | Take item, else Take money, else Reply |
| Gossip / quest title | the next page's most likely button |

If the picked entry can't be used (a skill you can't learn yet, a recipe without materials) the focus stays where it is.

## Soft target

Of the units whose nameplates are already visible, the one nearest the screen centre gets a **name colour that pulses slowly**, coloured by reaction: red for hostile, yellow for neutral, green for friendly. The game's own mouseover tooltip is shown. Only one unit
is highlighted. Your real target is not changed, and OctoPad never turns nameplates on for you.

- Shows name, level and health, plus **your quest kill counts** for that unit, read from the quest log
  (for example `Boar slain: 3/10`, green once complete).
- Needs nameplates: `V` (enemies) and `Ctrl+V` (friendly), or pfUI nameplates.
- With **SuperWoW**, OctoPad calls `SetMouseoverUnit` to make the soft-selected unit your real mouseover and
  shows the game's own tooltip for it, so tooltip addons such as pfQuest add their lines as usual (OctoPad adds
  its quest lines only when pfQuest is absent). Without SuperWoW it falls back to its own small card.
- Hidden while a window is open or while editing the layout. `/opad soft on|off`.
- The visible cursor cannot be moved onto the unit: the 1.12 API has no way to position the mouse.
- **Items and world objects cannot be detected.**

## Smart target

Action-bar buttons pick their own target, like a mouseover macro. On by default; the master switch and five
category switches are on the World page (`/opad smart on|off`, `/opad smart <spells|buffs|attacks|pets|other> on|off`).

| Category | Covers | Target used |
|---|---|---|
| Spells | damage, crowd control, debuffs | soft/mouseover enemy, else your current target |
| Buffs and heals | helpful spells | soft/mouseover friend, else your friendly target, else **yourself** |
| Attacks and weapons | Attack, Auto Shot, Shoot, Throw, equipped weapons | the soft/mouseover enemy becomes your target first |
| Pets | Mend Pet, Revive Pet ... | your pet |
| Items and other | "Use:" items, consumables | helpful ones on yourself; harmful ones retarget the soft enemy |

- Casting at a unit other than your target needs **SuperWoW** (`CastSpellByName` with a unit). Without it, only
  "helpful spell with no friendly target -> self" applies.
- Attacks and items can only change your real target (`TargetUnit`); if the client blocked that function
  (see `/opad debug`) it is skipped. Spells, buffs and pets leave your target alone.
- Macros are left alone.
- Known spells (heals, buffs, attacks and debuffs of every class, English names) come from a built-in list;
  only unknown spells are guessed from the tooltip.
- **Per button:** Bindings page > select a button > *Smart target*: Automatic, As is (never redirect),
  Always on me, or Soft target. That overrides the guess for that button only.

## Auto deselect

After you talk to an NPC (gossip, quests, vendor, trainer, bank, flight master, auction house, mail, petition) the game keeps it
targeted. When the window closes OctoPad clears that target, so the nameplates and the soft select are not held back.
NPCs without a dialog (pressing Interact opens nothing) are deselected about 1.5 seconds after Interact. Only the NPC you talked to is cleared, never players or targets you chose afterwards. `/opad deselect on|off`.
(Needs `ClearTarget`; if OctoWoW blocks it, `/opad debug` lists it and the feature does nothing.)

## Radial menu

Open with `Shift+Escape` (Start), shift-click the minimap button, or the *Radial* action.

- **Left thumb stick** selects one of eight entries: Character, Spellbook, Talents, Bags, Quests, Map,
  OctoPad settings, Game menu. The stick must send `W A S D` (see Steam Input); other keys:
  `/opad stick <up> <left> <down> <right>`.
- **Bottom face button** confirms, **right face button** closes.
- In combat, or with the stick option off, the **D-pad** selects instead.

**Chord layer** (optional, LB+RB sends `ALT-1`..`ALT-8`): A Map, X Radial, Y Character, B Bags,
Down Chat, Left Spellbook, Right Talents, Up Quests.

## HUD and layout

By default (Auto) the d-pad cross sits to the left and the face-button cross to the right of the main action bar (pfUI's or Blizzard's), spread a little away from it so they stay clear of the nameplates (pfUI's Nostalgia layout included). Without a detected bar they sit far left and right of the bottom centre. Other positions are on the HUD page.

HUD buttons are grayed out when their action has no target in range (a soft-selected or mouseover unit counts as a possible target), and items show their stack count in the corner.

```
          [ Up ]                          [ Y ]
    [Left][ LB ][Right]             [ X ][ RB ][ B ]
         [ Down ]                         [ A ]
      (d-pad cross)                  (face-button cross)
```

- Two independent crosses with LB / RB in the centre, each with its own scale and position.
- Holding LT / RT switches the HUD to that bar. Hover a button for its slot and actions.
- **Edit layout:** drag a button to move it, scroll over it to resize (24-96 px), drag the blue handle above
  a cross to move the whole cross. The HUD page has size, nudge and reset controls.
- **pfUI:** both crosses are registered as movable frames (`/pfui` > Unlock) and positions are stored in
  the pfUI profile. Fonts and border colours follow pfUI, and the minimap button follows its square minimap.

## Controller-style icons for system actions

System actions (Jump, Map, Bags, Target enemy ...) get icons that follow the selected controller:
- **Menu** shows the controller's Start / Menu / Options / + button and **Setup** its Select / View / Share / - button.
- Every other action is a bold chevron / line pictogram tinted for the controller: Xbox green, PlayStation blue, Switch red.
They change when you change the glyph style. Turn them off on the HUD page to get the old ability icons back; icons you picked yourself always win.

## Icons

System actions (Jump, Back, Map, ...) have customisable icons; abilities always show their own.
In **Bindings** select a button and click *Choose icon*. The picker has the macro icon list (48 per page),
a search box, a type-your-own name field, and an *Apply to all buttons using this action* option.
`/opad icon <slot> <IconName or path or default>`.

## Secure mode

OctoWoW protects some functions (Jump, auto-run, targeting, attack). Calling them from an addon triggers
a "blocked" popup, so OctoPad binds those keys to Blizzard's own commands instead:

`JUMP`, `TOGGLEAUTORUN`, `SITORSTAND`, `TARGETNEARESTENEMY` / `TARGETPREVIOUSENEMY`,
`TARGETNEARESTFRIEND` / `TARGETPREVIOUSFRIEND`, `ASSISTTARGET`, `TARGETPET`, `STARTATTACK`,
`STOPATTACK`, `PETATTACK`.

- Those buttons do not flash on the HUD and are not reported as last input; the action still happens.
- When a window is open and the button has a window action, the key switches to OctoPad's handler and
  switches back afterwards (not during combat; applied right after).
- If the client blocks anything else, OctoPad logs the function name (Overview page, `/opad debug`).

## Profiles and glyphs

All settings (slots, smart target, HUD layout, icons, profile, glyph style ...) are stored **per character**. A character that logs in for the first time with this version starts from a copy of your previous shared settings and then changes independently. `/opad reset` only resets the current character.

| Profile | Summary |
|---|---|
| **Console Experience** (default) | Jump and Interact on the face buttons (Xbox / PlayStation: A / Cross = Jump, X / Square = Interact; Nintendo: X = Jump, A = Interact), RT + RB = Auto-run, LT + LB = Sit / stand; the rest are ability slots |
| **WoW: Forever** | LB / RB target friendly / hostile, A Jump, X Interact, Y Inspect, B Back, with pet, assist and clear-target on trigger layers |

| Style | Use for |
|---|---|
| Xbox, PlayStation | Standard glyphs and colours |
| Switch Pro (default) | Steam mapping by **position** ("Use Nintendo Button Layout" off) |
| Switch Pro (Nintendo) | Steam mapping by **letter** ("Use Nintendo Button Layout" on) |

Switch Pro buttons are labelled LT / RT (ZL / ZR) and LB / RB (L / R). If the wrong HUD button lights up,
try the other Switch style. Capture can send `Print Screen`; Home stays with Steam.

## Commands

`/opad` or `/octopad` opens the menu.

| Command | Effect |
|---|---|
| `/opad bind` / `repair` / `unbind` | Apply / re-apply / remove the controller keys (`bind force` overrides the ConsoleExperienceClassic check) |
| `/opad profile ce` or `forever` | Profile |
| `/opad style xbox`, `ps`, `switch`, `switchn` | Glyph style |
| `/opad slot <1-40> <ACTION or none or default>` | Game action (`/opad actions` lists them) |
| `/opad ui <1-40> <ROLE or none or default>` | Window action |
| `/opad icon <1-40> <name or default>` | Icon for a system action |
| `/opad native on\|off` | Secure mode |
| `/opad uimode on\|off` | Window navigation |
| `/opad smartfocus on\|off` | Smart default focus |
| `/opad hints on\|off` | Hint bar |
| `/opad soft on\|off` | Soft target |
| `/opad deselect on\|off` | Deselect NPCs after talking to them |
| `/opad smart on\|off` | Smart target master switch (add a category name to toggle it) |
| `/opad stick <up> <left> <down> <right>` | Keys the radial reads from the left stick |
| `/opad camerakey <KEY>` | Key for the right-stick camera (hold); see Steam Input setup |
| `/opad window <FrameName>` / `window mouse` / `windows` | Add or list navigable windows |
| `/opad edit` | Layout edit mode |
| `/opad hud on\|off`, `scale <0.5-2>`, `resetpos` | HUD |
| `/opad minimap on\|off` | Minimap button |
| `/opad chords on\|off`, `radial` | Chord layer, radial menu |
| `/opad reset` | Wipe settings and reload |
| `/opad debug` | Bindings, last input, soft target, SuperWoW, blocked functions |
| `/opad probe` / `probe test` | What this client allows: SuperWoW, GUIDs, UnitXP SP3, Interact.dll, blocked functions (`test` also tries a few harmless protected calls) |

Key bindings also appear under **Esc > Key Bindings > OctoPad**.

## Limits

- Which functions OctoWoW protects is undocumented. Unexpected blocks are logged by name.
- The focus ring reaches buttons and check boxes. Sliders, edit boxes and the map's click area need the
  mouse (or the map's own D-pad controls). Typing needs a keyboard.
- Windows that call protected functions from their own click handlers (for example using a bag item) can
  still raise the popup.
- Dragging spells onto Blizzard's real action bars needs the mouse; use the HUD buttons.
- Not included: Forever's switchable action-bar sets, ConsoleExperienceClassic's virtual keyboard and
  cast / XP bars, auto spell rank.

## Troubleshooting

First step for anything that "does nothing": `/opad probe` (and `/opad probe test` with a target selected). It shows
which client extensions are present and which protected functions this client blocks.


| What you see | Fix |
|---|---|
| "OctoPad has been blocked ..." popup | `/opad debug` shows the function; keep **Secure mode** on |
| Bindings *not applied / partly overwritten* | Overview > **Apply / Repair**; keep auto-repair on |
| A button does nothing | The key is not reaching the game: check the Steam Input table |
| A button acts as Back / Confirm instead of casting | A window is open; close it or set that button's window action to *none* |
| No focus ring on pfUI / Bagshui bags | `/opad windows` with the bag open; then *Add window under mouse* |
| No soft highlights | Turn nameplates on (`V` / `Ctrl+V`); hidden while windows are open |
| Radial stick does nothing | The stick must send `W A S D`, or set `/opad stick ...`; not available in combat |
| ConsoleExperienceClassic detected | Disable one of the two |
| Keys misbehave after removing the addon | Click **Remove** (or `/opad unbind`) before deleting the folder |

## Credits

[ConsolePort](https://github.com/seblindfors/ConsolePort) (design reference),
[ConsoleExperienceClassic](https://github.com/pepordev/ConsoleExperienceClassic) (layout, slots, defaults),
Blizzard's "Explore WoW: Forever with a Gamepad" guide (Forever logic),
[pfUI](https://github.com/shagu/pfUI), [Interact](https://github.com/luskanek/Interact).
Independent addon, not affiliated with Blizzard, OctoWoW or the projects above.
