# Optional automation

Open **Gear sets → Events**. Enable the master toggle and choose a saved set for each desired event. Automation starts disabled.

Each event has a name, trigger, delay and Lua script. A positive delay waits until that long after the latest trigger, combining repeated triggers into one action. Zero runs immediately. Disabling events, changing their set, opening the gear editor or leaving the world cancels delayed actions.

## Included events

Mount, Town, Plaguelands and Travel Form change gear when you enter or leave their conditions. Low Mana equips below 50% mana and restores above 75%. Swimming equips when the breath timer begins and does not restore gear when you leave water. Armor and trinket changes wait for combat to end.

Included class, item, zone and chat patterns assume an English client. Custom server content may need an edited event.

**Reset events** or `/gr reset events` asks, then restores the included events and deletes your own. Sets keep their restore data.

## Writing a script

Within an event, `GearRack.EquipSet()`, `GearRack.LoadSet()` and `GearRack.ToggleSet()` use its chosen set. Pass a name to use another set. `GearRack.IsSetEquipped("PvP")` checks a set. Trigger values are available through the client's `arg1`/`arg2` variables.

```lua
if IsMounted() then
    GearRack.EquipSet()
else
    GearRack.LoadSet()
end
```

The **Test** button runs the entered script once. It can reveal script errors but does not check that you chose the correct trigger or delay. Save the definition and enable its event when you are ready to use it.

More scripts to copy, such as rogue poisons by target: [Event examples](EVENT_EXAMPLES.md).
