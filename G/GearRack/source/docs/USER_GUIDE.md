# Equipment and macros

## Equipment bar

Hover an equipment button to choose a carried item. Alt-click character-sheet slots to add or remove buttons. Alt-click the character model or the set editor's chosen icon to add or remove Sets. Alt-drag moves the bar.

Open **Gear sets → Bar layout** to reorder buttons with **Up** and **Down**. The order follows the bar's growth direction, including vertical and reversed bars. **Show gear-set button on the bar** hides or restores Sets at its chosen position. Reordering keeps the bar's position, scale and spacing.

**Equipment options** controls orientation, growth, flyouts, key labels and tooltips. Equipment buttons always have rarity borders and large centered gold cooldown numbers. Weapon-enchant labels show the remaining time and warn about low poison charges.

`/gr bar` shows or hides the bar. `/gr lock`, `/gr unlock` and `/gr scale .85` adjust it. **Reset Bar** restores its position and scale while keeping sets and enabled buttons.

## Menus

The purple gear minimap button opens **Gear sets**; the yellow PvP trinket opens **Trinkets**. Right-click either button for its options. Drag the icons to move them independently.

Shift-click the gear button to open the saved-set menu, or the editor when no visible sets exist. Equipment options can change this gesture to show or hide the bar. Right-click the Sets bar button to open its editor.

Buttons inside each editor switch between **Gear sets** and **Trinkets**. **Back** or **Escape** returns from Bar layout to the previous Gear sets tab. Escape first closes an open set chooser or event editor, then closes the main editor on the next press. **X** closes the menus. Closing an editor also cancels unfinished key capture.

## Saved sets and keys

Open `/gr sets`, select the slots, enter a name, choose an icon and save. Partial sets leave other slots alone. The **X/20** count includes selected slots and explicit empty-slot choices. Save again to keep edits to an existing set.

A set remembers the exact copy of each item it saved, so two identical weapons with different poisons can belong to two sets. If that copy is gone (sold, banked or replaced), any copy of the item does. Sets saved before this keep matching any copy until you save them again.

Choosing a saved set takes priority for every slot it contains. Armor and trinkets wait for combat to end; eligible weapons may change during combat. With **Keep manual choices** enabled (the default), trinket slots included in the set remain protected from their priority queues until you resume them using the queue checkbox or Alt-click. If the option is off, automatic queues may continue after the whole set finishes. Slots omitted from the set keep their existing queue and hold settings.

Bind a set with **Bind Key** or WoW's Key Bindings menu. The menu supports account/character profiles and two keys per action. **Bind Key** replaces that set's keys; Escape during capture clears them. Closing the editor cancels unfinished capture.

**Click again to restore gear** makes selecting an already-equipped set from its flyout restore the gear it replaced, while alive and out of combat. Shift-click offers the same restore action without enabling that option.

## Queued changes

A clicked weapon swaps at once, even while you cast or mount; it waits only for item locks and cursor actions, and a swap the game refuses is retried. Clicking it repeatedly keeps it queued; choosing another weapon replaces that slot's choice. GearRack follows the selected copy when it moves between bags and equipment.

Armor and trinkets wait for combat to end. Eligible weapon changes can proceed while those slots wait. Armor in saved sets waits for casts and the global cooldown. Death pauses pending changes until resurrection; loading screens pause them until you enter the world. Reloading clears unfinished requests.

If an item disappears from your carried equipment, its request clears. Full bags produce a warning and wait for space. Editing or deleting a waiting set preserves the replacement set's saved details.

## Bank transfers

Wait for a bank transfer to finish before starting another. Equipment choices made during that wait resume afterward. If a transfer cannot be confirmed within five seconds, GearRack stops it and asks you to check your bags before trying again. Closing the bank, death or a loading screen stops the bank transfer.

## Macros

```lua
/run GearRack.EquipSet("PvP")
/run GearRack.ToggleSet("PvP")
/run GearRack.LoadSet("PvP") -- restore gear displaced by this set
/run GearRack.SwapPoison() -- off hand
/run GearRack.SwapPoison(16) -- main hand
```

Poison swapping chooses an identical carried weapon with a different active temporary enchant. Finish any cursor action or active set swap first. If several copies match, provide the desired enchant ID as the second argument: `GearRack.SwapPoison(17, enchantID)`.

`GearRack.QueueItem(itemID, equipmentSlot)` chooses a carried item by numeric ID. Item links or exact names work too. Slot 16 is main hand and 17 is off hand. Use the flyout when you need to select a particular copy.

## Resets

**Reset Bar** retains saved sets and enabled buttons. `/gr reset events` asks, then restores the included events and deletes your own. `/gr trinkets reset` confirms clearing trinket options, positions, priorities, profiles and holds, then reloads. Equipment settings and sets remain.
