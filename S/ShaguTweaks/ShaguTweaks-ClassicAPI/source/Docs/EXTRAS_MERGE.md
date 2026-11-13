# ShaguTweaks Extras ClassicAPI: what moved where

Since version 3.7 the modules of Dusk's [ShaguTweaks Extras ClassicAPI](https://octowow.st/git/Dusk/ShaguTweaks-Extras-ClassicAPI) are part of this addon, so you no longer need to install it. This page lists where every module went, what was left out and why.

Copied from Extras commit `8e14bb4` (2026-09-18). Credits and licenses are in `THIRD_PARTY_NOTICES.md`.

## What to do when updating

From 3.8.6, Cooldown Numbers uses ClassicAPI's native countdown text when
`countdownForCooldowns` is enabled. It preserves ShaguTweaks' colors, rounding
and duration threshold. The addon leaves that global CVar unchanged; when it is
off, or the required native APIs are unavailable, the existing Lua renderer
continues to work. Legacy Model indicators retain their sweep and use a native
child for numbers when supported.

For custom-module authors: 3.8.6 removes unused `ShaguTweaks.L` data sections
`bagtypes`, `itemtypes`, `hunterpaging`, `critters`, `dyndebuffs`, `judgements`,
`interrupts`, `resurrections`, `spells`, `debuffs` and `totems`. The `class` and
`customcast` sections remain. Custom modules using the removed tables must
supply their own data or use client APIs.

1. Install this addon (3.7 or newer).
2. Disable or delete the `ShaguTweaks-extras` folder in `Interface\AddOns`. While it stays enabled, its older copies replace the built-in ones, and a message in chat reminds you at login.
3. Your on/off choices carry over, because the modules kept their names.

## Where the modules went

Open the settings with **Esc → Advanced Options**.

| Module | Now in category |
|---|---|
| Dragonflight Gryphons | Action Bar |
| Floating Actionbar | Action Bar |
| Hide Macro Text | Action Bar |
| Mouseover Right, Mouseover Right 2 | Action Bar |
| Reagent Counter | Action Bar |
| Center Vertical Actionbar | Action Bar |
| Show Bags, Show Micro Menu | Action Bar |
| Center Text Input Box | Chat & Social |
| Block NPC Spam | Chat & Social |
| Enable Text Shadow | Chat & Social |
| Chat Timestamps | Chat & Social |
| World Chat Hider | Chat & Social |
| Loot Quality | Loot |
| Macro Icons, Macro Tweaks | **Macro** (new category) |
| Buy Em All | **Merchant** (new category) |
| MiniMap Framerate & Latency | Minimap & World Map |
| Reveal World Map | Minimap & World Map |
| Cursor Tooltip, Hide Combat Tooltip, Metric Range | Tooltip & Items |
| Unit Frame Abbreviated Names | Unit Frames |

The textures these modules use (the gryphons and the XP bar) moved to this addon's `img` folder.

## Left out, and why

| Module | Reason |
|---|---|
| **Raid Frames**, with all its options (Show Aggro Indicators, Show Combat Feedback, Use Compact Layout, Show Dispel Indicators, Show Group Headers, Show Healing Predictions, Hide Party Frames, Use As Party Frames) | Not wanted in this fork. I use Puppeteer for Raid/Party/Focus frames. |
| **Bag Item Click** and **Bag Search Bar** | [Bagshui](https://octowow.st/git/OEVG/Bagshui) already has a search box and sends items to trade, the auction house and mail on right-click. |
| **Auction Alt-Buy** | [aux](https://octowow.st/git/Dusk/aux-addon-ClassicAPI) already buys out or cancels with Alt+click on a row. |

## Removed later

| Module | Version | Reason |
|---|---|---|
| **Key-Down Casting** and **Alt Self-Cast** | 3.7.1 | ClassicAPI now has the game's own `ActionButtonUseKeyDown` setting. Type `/console ActionButtonUseKeyDown 1` once instead. Details in the [changelog](../CHANGELOG.md). |
| **Debuff Timer** | 3.8 | [TargetFrameBuff](https://octowow.st/git/OEVG/TargetFrameBuff) already provides target buff/debuff countdowns with ClassicAPI. Use its timer settings instead of running overlapping timers in ShaguTweaks. |
| **Auto Dismount** | 3.8.1 | ClassicAPI provides Auto Dismount, Auto Stand and Auto Cancel Form. |
| **AoE Loot** | 3.8.6 | Removed in favor of a dedicated area-looting addon. Use [AutoAreaLoot](https://github.com/rotaruandrei93/AutoAreaLoot) for this functionality; check its README for required dependencies. The old ShaguTweaks setting is retired automatically. |
| **Nameplate Castbar**, **Nameplate Scale** and **Nameplate Class Colors** | 3.8 | Enabling these together with another nameplate addon can cause conflicts because both addons modify the same nameplates. Use one dedicated nameplate addon instead; alternatives are listed below. |

### Nameplate alternatives

Choose one to handle your nameplates:

- [BlizzNameplatesPlus](https://github.com/Wurmschwanz/BlizzNameplatesPlus) for a similar Blizzard-like appearance.
- [UnitPlates](https://github.com/Redbu11dev/UnitPlates) for more detailed nameplates.
- [ShaguPlates](https://github.com/Dinkleberrrg/ShaguPlates) for extensive customization.
