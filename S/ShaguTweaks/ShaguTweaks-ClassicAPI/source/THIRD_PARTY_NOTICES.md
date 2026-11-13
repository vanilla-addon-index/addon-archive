# ShaguTweaks-ClassicAPI third-party notices

This file records third-party material, upstream sources, external runtime
dependencies, and development references known to ShaguTweaks-ClassicAPI.

It is intentionally additive: source comments, Git history, upstream license
notices, and README credits remain part of the provenance trail and should not
be removed merely because this summary exists.

## ShaguTweaks

ShaguTweaks-ClassicAPI is a fork of ShaguTweaks:

- Source: https://github.com/shagu/ShaguTweaks
- Copyright (c) 2021 Eric Mauser (Shagu)
- License: MIT

The original MIT license remains at the repository root in `LICENSE` and an
additional preserved copy is stored in `LICENSES/ShaguTweaks-MIT.txt`.

The MIT grant applies to material for which the upstream copyright holder had
the right to grant those permissions. It does not by itself establish ownership
or relicensing authority over unrelated third-party or game-derived assets that
may have been present in an upstream package.

## TokensWorth/ShaguTweaks-mods

Extended frame support in `mods/move-unitframes.lua` contains code adapted
from `TokensWorth/ShaguTweaks-mods`:

- Upstream module: `mods/move-unitframes-extended.lua`
- Source: https://github.com/TokensWorth/ShaguTweaks-mods
- Copyright (c) 2022 GryllsAddons
- License: MIT

The following modules, merged from ShaguTweaks-Extras-ClassicAPI, also
contain code adapted from `TokensWorth/ShaguTweaks-mods` (as recorded by that
project):

- `mods/actionbar-mouseover-common.lua`
- `mods/actionbar-mouseover-bar-right.lua`
- `mods/actionbar-mouseover-bar-right2.lua`
- `mods/actionbar-hide-macro.lua`
- `mods/unitframes-abbrev-names.lua`
- `mods/cursor-tooltip.lua`
- `mods/hide-combat-tooltip.lua`
- `mods/minimap-framerate-latency.lua`
- `mods/chat-npc-spam.lua`
- `mods/world-chat-hider.lua`
- `mods/loot-quality.lua`

The preserved license text is stored in
`LICENSES/ShaguTweaks-mods-MIT.txt`.

## ShaguTweaks-Extras-ClassicAPI

These modules were merged from Dusk-92's ShaguTweaks-Extras-ClassicAPI
(commit `8e14bb4`, 2026-09-18), itself a fork of paokkerkir's
ShaguTweaks-extras:

- Action bar: `actionbar-df-gryphon.lua`, `actionbar-right-center.lua`,
  `actionbar-reagents.lua`, `actionbar-float.lua`,
  `reduced-actionbar-bags.lua`, `reduced-actionbar-micromenu.lua`,
  `actionbar-mouseover-common.lua`, `actionbar-mouseover-bar-right.lua`,
  `actionbar-mouseover-bar-right2.lua`, `actionbar-hide-macro.lua`
- Merchant: `buy-em-all.lua`
- Loot: `loot-quality.lua`
- Tooltip & items: `metric-range.lua`, `cursor-tooltip.lua`,
  `hide-combat-tooltip.lua`
- Unit frames: `unitframes-abbrev-names.lua`
- Minimap & world map: `minimap-framerate-latency.lua`, `worldmap-reveal.lua`
- Macro: `macro-icons.lua`, `macro-tweaks.lua`
- Chat & social: `chat-filter-common.lua`, `chat-npc-spam.lua`,
  `world-chat-hider.lua`, `chat-input-center.lua`, `chat-text-shadow.lua`,
  `chat-timestamps.lua`

Their option categories, texture paths and one chat message were changed for
the merge; the rest of the code is unchanged. The textures
`img/df-gryphon.tga`, `img/df-gryphon-beta.tga`, `img/df-wyvern.tga` and
`img/xpbar.tga` come from the same tree (see `Docs/ASSET_PROVENANCE.md`).

- Sources: https://octowow.st/git/Dusk/ShaguTweaks-Extras-ClassicAPI and
  https://github.com/paokkerkir/ShaguTweaks-extras
- Copyright (c) 2025 Eric Mauser (Shagu)
- License: MIT

The preserved license text is stored in
`LICENSES/ShaguTweaks-extras-MIT.txt`.

## brues-code/pfUI

The Swing Timer and Wand Timer in `mods/swing-timer.lua` are ported from
pfUI's swing timer module and restyled, and the Loot History window in
`mods/loot-history.lua` is ported from pfUI's loot history module and rebuilt
with stock 1.12 widgets:

- Upstream modules: `modules/swingtimer.lua`, `modules/loothistory.lua`
- Source: https://github.com/brues-code/pfUI
- Copyright (c) 2016-2021 Eric Mauser (Shagu) and contributors
- License: MIT

The preserved license text is stored in `LICENSES/pfUI-MIT.txt`.

## ClassicAPI

ClassicAPI is a required external runtime dependency used by
ShaguTweaks-ClassicAPI.

- Source: https://github.com/brues-code/ClassicAPI
- The upstream repository includes the GNU General Public License version 3.
- ClassicAPI itself is **not bundled** in this addon repository.

A verbatim copy of the upstream license document is preserved in
`LICENSES/ClassicAPI-GPL-3.0.txt` for reference. Including that license text
does not relicense ShaguTweaks-ClassicAPI under the GPL and does not imply that
ClassicAPI binaries or source are distributed as part of this addon.

## AoELoot

Before 3.8.6, `mods/aoe-loot.lua` was adapted from the standalone AoELoot
addon provided to the project by Sandrea. The module has since been removed;
this historical attribution remains for earlier releases:

- Original addon title: `AoELoot`
- Original metadata credit: Sandrea / ChatGPT
- Former adapted module: `mods/aoe-loot.lua`

The supplied package did not include an upstream URL or a separate license
file. This notice records the known provenance and preserves attribution; it
does not infer additional licensing terms.

## SuperWoW

SuperWoW is an optional external runtime dependency/fallback used by some
compatibility paths.

- Source: https://github.com/balakethelock/SuperWoW
- SuperWoW is **not bundled** in this addon repository.
- Its upstream license is preserved verbatim in
  `LICENSES/SuperWoW-LICENSE.txt`.

The upstream SuperWoW license has its own restrictions. This notice records the
dependency and preserves its license; it does not extend those terms to
ShaguTweaks-ClassicAPI or grant additional rights in SuperWoW.

## pfUI and zUI

pfUI and zUI are credited in the project README as sources of additional code
ideas and development reference.

This notice does **not** make a broader claim that either project is bundled in
whole, nor does it infer a license for unspecified material. Any specific
future copied or substantially adapted component should be documented with its
exact source, affected files, and applicable license at the time it is added.

## Turtle WoW-like environments

ShaguTweaks-ClassicAPI contains compatibility logic intended for Turtle WoW-like
server/client environments. Compatibility, testing, naming, or behavioral
reference does not create an affiliation, endorsement, partnership, or
ownership relationship with those projects or their maintainers.

## Artwork and screenshots

Artwork under `img/` and screenshots under `screenshots/` are tracked
separately in `Docs/ASSET_PROVENANCE.md`.

A project-level software license does not automatically prove ownership or
relicensing authority for every visual asset in an upstream project. The asset
manifest therefore records exact upstream matches without making broader
ownership claims.

## Project identity and trademarks

The canonical repository maintained by Dusk-92 is:

- https://github.com/Dusk-92/ShaguTweaks-ClassicAPI

Forks, mirrors, package caches, and modified copies hosted elsewhere are
independent unless this canonical project explicitly states otherwise.

World of Warcraft and Blizzard Entertainment names, marks, and game assets
remain the property of their respective rights holders. Other project names and
trademarks remain the property of their respective owners.

See `PROJECT_IDENTITY.md` for the full project-identity notice.

## Preservation rule

Do not remove historical source comments, attribution notes, license notices,
compatibility explanations, or provenance records simply because newer
documentation summarizes them.

When replacing or substantially rewriting third-party-derived material, update
the provenance record rather than erasing the earlier history.


## OEVG2 customization and BetterBlizzFrames texture

This repository imports a source snapshot of Dusk/ShaguTweaks-ClassicAPI downloaded on 2026-10-24 and adds English-only loading and unit-frame customizations described in README.md.

`img/BlizzardRetailBar.tga` was obtained from:
https://github.com/Bodify/BetterBlizzFrames/blob/main/media/blizzTex/BlizzardRetailBar.tga

BetterBlizzFrames' repository license states **All Rights Reserved**, copyright (c) 2023-2026 Bodify. This asset is not covered by this repository's original ShaguTweaks MIT license. The source project's notice does not establish separate provenance or permissions for any underlying game artwork.


## Modern mana bar texture

`img/BlizzardRetailBarCrop2.tga` is copied unchanged from BetterBlizzFrames:
https://github.com/Bodify/BetterBlizzFrames/blob/main/media/blizzTex/BlizzardRetailBarCrop2.tga

Source Git blob: `bb412b3fa538a6c91671d06ccbfd1e820f4c2876`.
BetterBlizzFrames: All Rights Reserved, Copyright (c) 2023-2026 Bodify.
This asset retains its original rights and is not relicensed under MIT.
The mana tint follows BetterBlizzFrames' default `PowerBarColor.MANA` lookup:
RGB `(0, 0, 1)`. The selected texture is its `Blizzard Retail Bar Crop 2` preset.


## Native retail resource artwork

`img/ModernPowerMana.tga`, `img/ModernPowerRage.tga`, `img/ModernPowerFocus.tga` and `img/ModernPowerEnergy.tga` are cropped/resized exports of Blizzard's `interface/hud/uiunitframe2x.blp` (FileDataID 4642466), client build 12.1.5.70448, retrieved from https://wago.tools/api/casc/4642466?version=12.1.5.70448 .

Matching atlas metadata and conversion details are recorded in `Docs/MODERN_MANA.md`. These are Blizzard game assets, not original artwork or assets relicensed under the software's MIT license. The previous BetterBlizzFrames grayscale asset attribution remains part of the history.


### Frame-specific resource exports

Additional img/ModernPower*Class.tga, *Target.tga, *Small.tga and *Party.tga variants use the matching Blizzard atlas crops documented in Docs/MODERN_MANA.md. Player/target/small variants come from FileDataID 4642466; party variants come from FileDataID 4681512, interface/hud/uipartyframe.blp. Both were retrieved for build 12.1.5.70448 from wago.tools. All resource exports now use bilinear resizing to compact power-of-two TGA dimensions. These remain Blizzard game artwork; no MIT relicensing is asserted.

## Additional ClassicAPI implementation reference (3.8.2)

brues-code/pfUI at commit 560343bd746e00898606cf756bdfe533a4823110 was reviewed for native action-range subscription ownership and the separation of incoming-heal estimation from frame overlays. Source: https://github.com/brues-code/pfUI . The focused ShaguTweaks implementations retain their own frame and module architecture.

The swing/wand timer also adapts that commit's `modules/swingtimer.lua` native duration/text-binding, fill-edge anchoring and cancellable boundary-timer approach (MIT, Shagu and contributors). ShaguTweaks retains its classic artwork, movement, colors, grace behavior and older-API fallback.

Energy/mana tick phase locking and native fill-edge spark movement were also
adapted from that commit's `modules/energytick.lua`; native equipment comparison
was informed by `modules/eqcompare.lua` (MIT, Shagu and contributors). Existing
ShaguTweaks presentation and older-API paths remain separate.
