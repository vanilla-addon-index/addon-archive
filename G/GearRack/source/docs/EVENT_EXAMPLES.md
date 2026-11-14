# Event examples

Events let GearRack change gear by itself when something happens in the game:
you change target, enter combat, mount, enter a zone and so on. This page shows
how to make one and gives examples you can copy.

## Making an event

1. Open **Gear sets** (`/gr`) and click the **Events** tab.
2. Click **New** and fill in:
   - **Name** – anything, for example `Rogue:Poisons by target`. Starting with
     your class and a colon lets **Show All** hide it on other characters.
   - **Trigger** – the game event that runs the script, for example
     `PLAYER_TARGET_CHANGED`.
   - **Delay** – seconds to wait after the last trigger. `0` runs at once.
   - **Script** – the Lua code from the examples below.
3. Click **Save**.
4. In the events list, click the event's **icon** and choose a set. Every
   event needs a set before it can run, even if the script names its own sets.
5. Tick the event's checkbox, and tick **Enable events** at the top.

**Test** runs the script once, to catch typing mistakes. Events pause while the
Gear sets window is open; close it to let them run.

## What a script can do

| Code | Does |
| --- | --- |
| `GearRack.EquipSet()` | Equip the event's set |
| `GearRack.EquipSet("Name")` | Equip the set called Name |
| `GearRack.LoadSet()` | Put back the gear the event's set replaced |
| `GearRack.ToggleSet("Name")` | Equip Name, or put back the old gear if Name is worn |
| `GearRack.IsSetEquipped("Name")` | `true` when everything in Name is worn |

Weapons swap at once, also during combat and casts; if the game refuses a
weapon, GearRack tries again a moment later. Armor and trinkets wait until combat ends.

Useful game questions:

| Code | Answers |
| --- | --- |
| `UnitExists("target")` | Do I have a target? |
| `UnitCanAttack("player", "target")` | Is the target an enemy? |
| `UnitCreatureType("target")` | `"Beast"`, `"Elemental"`, `"Giant"`, `"Undead"`, `"Demon"`, `"Dragonkin"`, `"Humanoid"`, `"Mechanical"`... |
| `UnitName("target")` | The target's name |
| `UnitClassification("target")` | `"normal"`, `"elite"`, `"rare"`, `"rareelite"`, `"worldboss"` |
| `UnitIsPlayer("target")` | Is the target a player? |
| `UnitAffectingCombat("player")` | Am I in combat? |
| `GetRealZoneText()` | The zone, for example `"Molten Core"` |
| `IsMounted()` | Am I mounted? |

To see what the game says about a mob, target it and type:

```
/run print(UnitCreatureType("target"), UnitName("target"), UnitClassification("target"))
```

## Rogue: poisons by target

The idea: one gear set per poison loadout, and an event that picks the right
set when you target something.

Make two sets that only contain your weapons (main hand and off hand), for
example **Poison A** (your Instant weapons) and **Poison B** (your Dissolvent
weapons).

### By creature type

Trigger `PLAYER_TARGET_CHANGED`, delay `0.2` (so tab-targeting through a pack
swaps once, on the mob you stop at).

```lua
if not UnitCanAttack("player", "target") then return end
local kind = UnitCreatureType("target")
local set = "Poison A"
if kind == "Elemental" or kind == "Giant" then
  set = "Poison B"
end
if not GearRack.IsSetEquipped(set) then GearRack.EquipSet(set) end
```

The example follows your observation that elementals and giants ignore Instant
Poison. Check immunities on your own server and change the types to match.

### By name, with exceptions

Names win over types, so one odd mob does not need its own creature type.

```lua
if not UnitCanAttack("player", "target") then return end
local name, kind = UnitName("target"), UnitCreatureType("target")
local set = "Poison A"
if name == "Core Hound" or name == "Ancient Core Hound" then
  set = "Poison A"
elseif kind == "Elemental" or kind == "Giant" then
  set = "Poison B"
end
if not GearRack.IsSetEquipped(set) then GearRack.EquipSet(set) end
```

### A table for a whole raid

Easy to extend: add a line per creature type or name.

```lua
if not UnitCanAttack("player", "target") then return end
local byName = {
  ["Core Hound"] = "Poison A",
  ["Ancient Core Hound"] = "Poison A",
}
local byType = {
  Elemental = "Poison B",
  Giant = "Poison B",
  Beast = "Poison A",
  Undead = "Poison A",
}
local set = byName[UnitName("target")] or byType[UnitCreatureType("target") or ""] or "Poison A"
if not GearRack.IsSetEquipped(set) then GearRack.EquipSet(set) end
```

### Only inside one raid

Add this as the first line of any script above:

```lua
if GetRealZoneText() ~= "Molten Core" then return end
```

## More ideas

### Bosses get your best weapons

Trigger `PLAYER_TARGET_CHANGED`, delay `0.2`.

```lua
if UnitClassification("target") == "worldboss" then
  if not GearRack.IsSetEquipped("Boss") then GearRack.EquipSet("Boss") end
end
```

### PvP set against players, PvE set otherwise

Trigger `PLAYER_TARGET_CHANGED`, delay `0.2`.

```lua
if not UnitCanAttack("player", "target") then return end
local set = UnitIsPlayer("target") and "PvP" or "PvE"
if not GearRack.IsSetEquipped(set) then GearRack.EquipSet(set) end
```

### Shield when combat starts, two-hander when it ends

Trigger `PLAYER_REGEN_DISABLED` (entering combat):

```lua
GearRack.EquipSet("Shield")
```

Make a second event with trigger `PLAYER_REGEN_ENABLED` (leaving combat):

```lua
GearRack.EquipSet("Two-hander")
```

### Low health: defensive weapons

Trigger `UNIT_HEALTH`, delay `0`. `arg1` is the unit whose health changed.

```lua
if arg1 ~= "player" then return end
local health = UnitHealth("player") / UnitHealthMax("player")
if health < 0.3 and not GEARRACK_LOW then
  GearRack.EquipSet() GEARRACK_LOW = 1
elseif health > 0.6 and GEARRACK_LOW then
  GearRack.LoadSet() GEARRACK_LOW = nil
end
```

A name in capitals like `GEARRACK_LOW` remembers something between runs. Pick
a different name for each event.

### A zone set

Trigger `ZONE_CHANGED_NEW_AREA`, delay `1`.

```lua
local inside = GetRealZoneText() == "Blackwing Lair"
if inside and not GEARRACK_BWL then
  GearRack.EquipSet() GEARRACK_BWL = 1
elseif not inside and GEARRACK_BWL then
  GearRack.LoadSet() GEARRACK_BWL = nil
end
```

### While a buff is on you

Trigger `GEARRACK_BUFFS_CHANGED`. `arg1` holds your buffs by name and by icon.

```lua
local active = arg1["Arcane Power"]
if active and not GEARRACK_AP then
  GearRack.EquipSet() GEARRACK_AP = 1
elseif not active and GEARRACK_AP then
  GearRack.LoadSet() GEARRACK_AP = nil
end
```

### After using a trinket

Trigger `GEARRACK_ITEMUSED`. `arg1` is the item's name, `arg2` its slot.

```lua
if arg1 == "Insignia of the Horde" then GearRack.EquipSet() end
```

### When your attack is dodged

Trigger `GEARRACK_DODGED`. It fires when a target dodges your swing, spell or
shot. `arg1` is that unit's GUID. The two **Warrior:Overpower** events use it.

```lua
if arg1 == UnitGUID("target") then GearRack.EquipSet() end
```

## Tips

- Start with the **Test** button and watch chat for red error lines.
- Use a small delay (`0.2`) on `PLAYER_TARGET_CHANGED`, so quickly cycling
  targets does not swap on every mob.
- `if not GearRack.IsSetEquipped(set)` stops repeated requests for a set you
  already wear.
- Weapon-only sets swap in combat. Sets with armor wait until combat ends.
- **Enable events** at the top turns every event off at once, if something
  goes wrong mid-fight.
