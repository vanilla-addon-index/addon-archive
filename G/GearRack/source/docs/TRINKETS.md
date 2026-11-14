# Trinkets

## Buttons and drawer

Left-click an equipped trinket to use it; right-click opens **Trinkets** for that slot. Both the trinket and equipment bars support these shortcuts. Hover a trinket to open its carried-item drawer.

In the trinket drawer, left-click selects a copy for the upper slot and right-click selects it for the lower slot. The equipment flyout follows its **Trinket click mapping** option. Shift-click links an item to an open chat edit box.

Selecting the same pending trinket again cancels it. A different choice replaces it. `/gr trinkets` shows or hides the equipped buttons, `/gr queues` opens priorities and `/gr trinkets opt` opens options.

## Keys and display

Open **Key Bindings → GearRack** and assign **Use Trinket 1 (Upper slot)** and **Use Trinket 2 (Lower slot)**. The keys use the currently equipped item after swaps.

**Show key labels** changes the displayed keys without changing assignments. **Show trinket bar** controls the equipped buttons. Cooldown numbers disappear when an item is ready. Tooltips, Shift-only lists and ready alerts follow the same options in Gear sets.

While unlocked, drag, resize or rotate the windows using their controls. Hiding or locking a window stops its movement and resizing. Options also include docking and list columns.

```text
/gr trinkets lock
/gr trinkets unlock
/gr trinkets scale main .85
/gr trinkets scale menu .85
```

## Priority lists

Arrange each slot's list in `/gr queues`, then enable its checkbox or Alt-click the worn trinket. Automatic priorities start disabled.

- Ordinary entries replace a worn item when cooldown state permits.
- **High Priority** can replace an otherwise-ready item.
- **Swap Delay** keeps an item equipped for its effect duration.
- **Pause Queue** suspends the queue while that item is equipped.
- **Stop Queue Here** ends the active part of the list.

An enabled queue can fill an empty slot with an eligible listed trinket. Ready or passive trinkets stay equipped instead of repeatedly exchanging identical copies. Another ready copy can replace a cooling-down copy when the list permits. The two slots choose separate copies.

Queues continue to reconsider their choices while combat prevents swapping. If an equipped item becomes ready, a list changes or its queue is paused, an outdated automatic choice is cancelled or replaced. Manual choices take priority.

## Manual choices

**Keep manual choices** is enabled by default. A manual item pauses the affected slot's queue. A saved set takes priority for all slots it contains while it equips; its armor and trinkets wait for combat to end. Included trinket queues remain paused afterward when **Keep manual choices** is on. If the option is off, automatic queues may continue after the full set finishes. Omitted slots keep their existing queue and hold settings.

A red gear and unchecked queue box indicate a manual hold. Check the box or Alt-click its trinket to resume.

**Stop Queue On Swap** can additionally disable a queue when you manually choose a clickable trinket from the drawer. Passive manual drawer choices disable their queue regardless. Turning off **Keep manual choices** releases its holds; each queue's on/off setting remains separate.

## Profiles and macros

Profiles save and restore priority order. `/gr trinkets load top Raid Fire Resist` loads **Raid Fire Resist**; use `bottom` for the other slot. Profile names may contain spaces and retain case.

Items whose details are still loading show a placeholder temporarily. A misspelled or unavailable list that finds no items leaves the existing order intact. A partially valid list loads found entries and reports missing ones. Carried trinkets removed from a list can return at the end when it refreshes; place the stop marker to limit automatic choices.

```lua
/run GearRack.SetTrinketQueue(0,"ON")
/run GearRack.SetTrinketQueue(1,"PAUSE")
/run GearRack.SetTrinketQueue(1,"RESUME")
/run GearRack.SetTrinketQueue(1,"SORT","Earthstrike","Diamond Flask")
```

Slot 0 is upper and slot 1 is lower. ON/RESUME release manual holds. OFF/PAUSE stop automatic choices while preserving pending manual choices.

`/gr trinkets reset` confirms clearing trinket options, positions, queues, profiles and holds, then reloads. Equipment sets and equipment-bar settings remain.
