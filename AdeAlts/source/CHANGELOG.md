# Changelog

## 1.3.0
- Classic Blizzard window style for everyone without pfUI (dialog-style main windows, tooltip-style panels). With pfUI installed the pfUI look is still used.
- New setting **Window style**: Auto / Blizzard / pfUI (also `/ade style auto|blizz|pfui`). Takes effect immediately.
- Cooldowns window and the login popup follow the chosen style too.
- Minimap button redrawn as a standard round button with the gold ring, so it matches the other buttons in pfUI's panel and on the minimap.

## 1.2.5
- Item tooltips now show how many of the item your other alts carry (bags / bank, per alt).
- Fixed: alt info could be added twice to a tooltip.

## 1.2.4
- Fixed: recipe items whose name differs from the crafted item (e.g. Pattern: Guardian Bracers -> Guardian Leather Bracers) showed no alt info. Recipes are now identified by item id.

## 1.2.3
- Guild / party / raid chat sync is now **off by default**; enable it with `/ade chat`. Shared-file sync (SuperWoW) is unaffected.

## 1.2.2
- Fixed: lists (recipes, bags, bank, search results) jumped back to the top every few seconds.
- Fixed: a dropped profession stayed in the list (the shared file / chat brought it back). Dropped professions are now remembered and the removal syncs between accounts.

## 1.2.1
- `/ade del` now also ignores the character afterwards (it was re-added by the next chat broadcast). New `/ade unignore <name>` and `/ade chat` (switch guild / party / raid sync off).

## 1.2.0
- Professions view reworked: **Known / Missing** recipes per profession, required skill level in front of every
  recipe (coloured by how close it is to the current skill), sort by **Level** or **Name**.
- Missing recipes show where they come from (Trainer, Vendor, Drop, Quest, Chest, Fishing, ...).
- Tooltip on every recipe: item tooltip, required skill, source, recipe items and what your other alts know.
- Recipe items (Pattern / Recipe / Plans / Formula / ...) now list which alts already know the recipe or can learn it.
- Jewelcrafting is tracked. Bundled recipe database (credits in CREDITS.md).

## 1.1.1
- Fixed: wrong icon / name on bank bags (bag item is now matched by the client's bag name). Added `/ade bags`.

## 1.1
- Inventory and Bank panels show every bag (icon, used/size, tooltip with free slots) and the total used/size in the panel title. Synced between accounts.

## 1.0
- Equipment tab: three columns (6 / 6 / 5 slots) with icon, quality-coloured item name and tooltip.
- Settings: background colour picker.
- Fixed: hunter *Survival* talent line was shown as the Survival profession.
- Fishing, Skinning and Herbalism no longer ask for a recipe scan.
- Code split into several files (avoids Lua 5.0 local / upvalue limits).

## 0.4
- Professions with skill levels and known recipes, equipped gear, cooldown window opacity.

## 0.3 / 0.2
- Settings window (scale, size, opacity), sorting, gold and level fixes, per-alt inventory and bank.

## 0.1
- Cooldown tracker (Salt Shaker, Transmutes, Mooncloth), minimap button, login popup, cross-account sync.
