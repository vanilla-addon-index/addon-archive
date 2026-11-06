# Shaman Weapon Imbue Warning

<img width="800" height="450" alt="WoWScrnShot_102526_145214_0" src="https://github.com/user-attachments/assets/e5e4de0f-880f-4b86-b37b-f7e7dfd39c32" />

A standalone addon for OctoWoW with ClassicAPI. It displays a warning near the top center of the screen when all of these are true:

- The character is a Shaman.
- The character is in combat.
- A main-hand item is equipped without a Shaman weapon imbue.

The warning clears when combat ends, the main-hand slot is empty, or a Shaman imbue is detected. It recognizes Rockbiter, Windfury, Flametongue, and Frostbrand. Other temporary enchants such as poisons and oils do not count as imbues.

ClassicAPI is required because its `C_Item.GetWeaponEnchantInfo()` extension reports the enchant ID; the stock 1.12 API only reports whether an enchant exists.

## Install

Copy the `ShamanWeaponImbueWarning` folder into `Interface\AddOns`, then enable **Shaman Weapon Imbue Warning** from the character selection AddOns menu.
