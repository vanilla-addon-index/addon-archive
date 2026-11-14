# GearRack

**v1.0.0** · Gear sets, trinket priorities and weapon swaps for **WoW 1.12.1** (build 5875).

- Save full or partial gear sets, give them icons and keys.
- Swap items from an equipment bar or your character window.
- Weapons swap at once, even while you cast or mount; a swap the game refuses is retried.
- Two trinket slots, each with its own priority list, profiles and swap delays.
- Large cooldown numbers, rarity borders and poison timers on your gear.
- Optional automation: change gear when you mount, shapeshift, enter a zone and more.

## Requirements

The latest release of each client extension, loaded:
[ClassicAPI](https://github.com/brues-code/ClassicAPI),
[SuperWoW](https://github.com/balakethelock/SuperWoW) and
[NamPower](https://github.com/Emyrk/nampower).

GearRack prints a message in chat if one is missing.

## Install

1. With WoW closed, click **Code → Download ZIP** on this page.
2. Extract it into `Interface/AddOns` and rename the folder to **GearRack**, so that
   `Interface/AddOns/GearRack/GearRack.toc` exists.
3. Enable **GearRack** in the character-screen addon list.

## Getting started

- **Purple gear** minimap button: opens **Gear sets**. Right-click for the bar options.
- **PvP trinket** minimap button: opens **Trinkets**. Right-click for its options.
- Hover a button on the equipment bar to pick another item for that slot.
- Alt-click a slot in your character window to add it to the bar or remove it.

To make a set: open **Gear sets**, click the slots to include, type a name, pick an
icon and press **Save**. **Bind Key** gives it a key.
Drag a saved set (its icon, its row in the set list, or the Sets flyout) onto an
action bar: GearRack makes a character macro `/gr equip <set>` for it.

## Example: rogue poisons by target

Some enemies shrug off a poison: Instant Poison is Nature damage, and in our raids
it does not land on elementals and giants. One event can swap your weapons to the
right poison every time you pick a target, even mid-fight.

| Set | Main hand | Off hand | Poison | Used against |
| --- | --- | --- | --- | --- |
| 🟢 **Instant** | Satyr's Claw (+5 Weapon Damage) | Distracting Dagger | Instant Poison VI | everything else |
| 🟣 **Dissolvent** | Satyr's Claw (Crusader) | Anasterian's Legacy | Dissolvent Poison II | Elemental, Giant, Mechanical, Undead |

A set remembers the exact copy of each item, so even two identical daggers with
different poisons belong to different sets. Poisons stay on the weapons waiting
in your bags.

**1. Save two sets.** Wear each pair, open `/gr` → **Sets**, light up only the main
hand and off hand, type the name and press **Save**.

**2. Make the event.** **Events** → **New**:

| Field | Value |
| --- | --- |
| Name | `Rogue:Poisons` |
| Trigger | `PLAYER_TARGET_CHANGED` |
| Delay | `0.2` |

```lua
-- Only enemies
if not UnitCanAttack("player", "target") then return end

-- Creature types that get the Dissolvent weapons
local dissolvent = { Elemental = true, Giant = true, Mechanical = true, Undead = true }

-- Everything else gets the Instant weapons
local set = "Instant"
if dissolvent[UnitCreatureType("target") or ""] then set = "Dissolvent" end

if not GearRack.IsSetEquipped(set) then GearRack.EquipSet(set) end
```

**3. Switch it on.** Save, click the event's **?** icon and pick **Instant**, tick the
event and **Enable events**, then close the window.

> [!TIP]
> Not sure what a mob is? Target it and type
> `/run print(UnitCreatureType("target"), UnitName("target"))`.
> Add a type to the list with `Demon = true,` and so on.

> [!NOTE]
> Weapons swap at once, also in combat. The 0.2 second delay
> means tab-targeting through a pack swaps once, on the mob you stop at.
> **Key Bindings → GearRack → Toggle Events** turns all events off or on with one key.

More scripts: [Event examples](docs/EVENT_EXAMPLES.md).

## Commands

`/gearrack` works the same as `/gr`. **Game Menu > AddOn Options > GearRack** has
**Gear sets** and **Trinkets** buttons.

| Command | Does |
| --- | --- |
| `/gr` | Open or close Gear sets |
| `/gr equip <set>` | Equip a set |
| `/gr toggle <set>` | Equip a set, or put back the gear it replaced |
| `/gr bar` | Show or hide the equipment bar |
| `/gr lock`, `/gr unlock`, `/gr scale .85` | Lock, unlock or scale the bar |
| `/gr layout` | Order the bar's buttons |
| `/gr queues` | Trinket priority lists |
| `/gr trinkets` | Show or hide the trinket buttons |
| `/gr keys` | Open Key Bindings |
| `/gr reset bar`, `/gr reset events` | Reset the bar, or restore the included events (asks first) |

Set and profile names may contain spaces.

## More

- [Equipment, sets and macros](docs/USER_GUIDE.md)
- [Trinkets](docs/TRINKETS.md)
- [Automation (events)](docs/EVENTS.md)
- [Event examples](docs/EVENT_EXAMPLES.md): poisons by target, boss weapons, combat swaps and more
