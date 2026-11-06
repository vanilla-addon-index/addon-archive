# Outfitter
Outfitter is an equipment management addon which gives you fast access to multiple outfits.

Updated and development continued for WoW 1.18.1 Clients.

# Pepo changes
- Added small display of current outfits that can be enabled in options
- Added 'Trash' and 'Boss' outfits that will be used depending on level of target
- Added 'BeastTrash', 'UndeadTrash', 'DemonTrash', and 'Critter' outfits that will be applied after the regular Trash outfit depending on target creature type

# 1.6.0 changes

## Client mod support (optional)
Outfitter runs unchanged on a stock 1.12.1 client. If SuperWoW or ClassicAPI is
installed it uses them automatically. Type `/outfitter mods` to see what was detected.

| Feature | Stock client | With SuperWoW or ClassicAPI |
|---|---|---|
| Riding outfit | Guesses from buff tooltip text (English "speed"/"Riding" wording) | Uses the client's mounted flag: every mount, every locale, no false positives from speed buffs |
| Buff scanning | Tooltip-scans every unrecognised buff on every aura change | Each distinct buff is tooltip-scanned once per session (cached by spell ID) |
| Swimming outfit (new) | Worn while the breath bar is showing (underwater) | Worn whenever you swim, including at the surface; leaves after 1s out of the water |
| Boss/Trash target outfits | Re-evaluates when name or level changes | Re-evaluates per mob (GUID) |

Nampower and UnitXP SP3 are detected and listed, but Outfitter doesn't use them:
nothing they add (spell queueing, cast timing, distance, line of sight, camera)
improves equipment management.

## Fixes (all clients)
- Sunnyglade Valley outfit never equipped (zone was missing from the zone list)
- "Disable outfit when in instances" only worked in AQ20/AQ40/ZG/ES/BM/K40; it now uses `IsInInstance()` so MC, BWL, Onyxia, Naxxramas and 5-man dungeons count
- Boss outfit also applies to targets classified as world bosses whose level is visible
- Beast/Undead/Demon/Critter target outfits work on German and French clients (creature types were hard-coded in English)
- **Gear stripped after a crash:** after a crash the client's item cache is discarded, so for the first seconds after login equipped items can't be read. Outfitter took that as "every slot is empty", saved it as a temporary outfit on top of your stack, and the next outfit change (mounting, entering a city, targeting) moved all your gear into your bags. Outfitter now waits until your equipped items can actually be read (up to 30s) before comparing or equipping anything, ignores reads where several slots empty at once, and discards a leftover "strip" outfit saved by an earlier crash
- Two accidental global variables (`vOutfit`, `vCommands`) made local
- Added `## Title` to the TOC (the version string is built from it)