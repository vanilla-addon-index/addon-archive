# Gromissingcrafts

A World of Warcraft addon for Turtle WoW (and OctoWoW) that helps players track crafting recipes they haven't learned yet across their characters.

Gromissingcrafts is a from-scratch rebuild of [MissingCrafts](https://github.com/refaim/MissingCrafts) with **no Ace3** anywhere in the addon — Ace3's embedded framework (AceAddon/AceDB/AceGUI/AceHook/AceLocale) is a common source of cross-addon conflicts on non-standard 1.12 clients like Turtle WoW/OctoWoW, since every addon that bundles its own copy shares the same global Ace3 registry. Gromissingcrafts is built entirely on native vanilla WoW frames instead, and adds support for Turtle WoW's custom **Survival** profession.

## Features

- **Integrated Profession Window**: Attaches directly to the profession frame you have open, and moves with it
- **Enhanced Item Tooltips**: Shows which of your characters can learn recipes from items and their current learning status
- **Search**: Filter the current profession's missing recipes by name
- **Recipe Source Information**: Displays how to obtain each missing recipe (Vendor, Quest, Drop, etc.) where known
- **Multiple Profession Frame Support**: Works with default WoW frames and popular profession addons
- **All Vanilla Crafting Professions**, plus Turtle WoW's Jewelcrafting, Disguise, and **Survival**
- **pfUI-friendly**: Detects pfUI and anchors/sizes itself accordingly
- **No Ace3**: nothing here can collide with another addon's bundled Ace3 libraries
- **Multi-Language Support**: English, German, French, Spanish, Portuguese, Russian, Korean, Chinese (Simplified), Chinese (Traditional)

## How to Use

1. Open any crafting profession window
2. Click the recipe button in the upper right corner of the profession frame
3. The Gromissingcrafts window opens attached to it, showing every recipe for that profession you haven't learned on your current character
4. Type in the search box to filter by recipe name
5. Hover over recipes to see their source information

## Survival profession data

Turtle WoW's Survival profession has no public numeric recipe database that could be reliably scraped for this addon, so `lib/LibCrafts-1.0/Professions/Turtle/Survival.lua` is built entirely from a real player's own data: a skill-up table, a `/gmc dump` of their known trade skill entries (real result item ids), and a `/gmc dump` of both trainer NPCs' full service lists (every recipe on offer, known or not). Between the three, it's now the **full recipe list, skill 1 through 300** — 87 recipes. The only known gap is two skill-295 items taught by a recipe item rather than the trainer directly (Oil-Powered Cooker, Prospector's Magnifying Lens), left out rather than mis-tagged.

**All 87 now have a real result item id** — the last 43 (skill 155-300) were confirmed by hand against octowow.st's database. 7 recipes also have a confirmed real spell id; the other 80 use a safe placeholder (900001+, nowhere near any real spell id range) since the client API has no way to read a recipe's actual spell id under any window — only its name and, for known trade-skill entries, its result item. This doesn't affect accuracy: the addon matches "known vs. missing" by recipe **name**, and the recipe tooltip always prefers a real result item id over the spell id, which every entry now has — a placeholder spell id never actually surfaces anywhere.

The one remaining gap: two skill-295 items (Oil-Powered Cooker, Prospector's Magnifying Lens) are taught by a recipe item rather than the trainer directly, and neither their spell id nor item id is confirmed, so they're left out rather than mis-tagged.

If you ever want to confirm one of the placeholder spell ids for real: open the Survival trade skill window in-game once you've learned it and run `/gmc dump`, or look it up directly at `octowow.st/db/?spell=<id>` if you find one — **grab the Item ID, not the Display ID shown on the same page**, they're different numbers.

## Supported Profession Windows

- Default WoW profession windows
- Turtle WoW improved Trade Skill window
- [**AdvancedTradeSkillWindow**](https://github.com/laytya/AdvancedTradeSkillWindow-vanilla)
- [**AdvancedTradeSkillWindow2**](https://github.com/Shellyoung/AdvancedTradeSkillWindow2)
- [**Artisan**](https://github.com/Otari98/Artisan)
- [**pfUI**](https://github.com/shagu/pfUI)'s trade skill frame styling

## Relationship to MissingCrafts

Gromissingcrafts started as a straight port of [MissingCrafts](https://github.com/refaim/MissingCrafts) v1.4.1, replacing every Ace3-backed piece with a native equivalent and adding Survival. `LibCrafts-1.0`, `LibCraftingProfessions-1.0`, and `LibItemTooltip-1.0` — the three data/plumbing libraries MissingCrafts already built on top of — were never Ace3-dependent to begin with, so they carry over largely unchanged (plus the Survival additions above).

## Acknowledgments
- Built on top of [MissingCrafts](https://github.com/refaim/MissingCrafts) by Roman Kharitonov
- Inspired by [MissingTradeSkillsList](https://github.com/refaim/MissingTradeSkillsList)
