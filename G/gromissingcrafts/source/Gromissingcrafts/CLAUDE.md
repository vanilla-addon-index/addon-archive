# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Gromissingcrafts is a World of Warcraft Classic (Turtle WoW/OctoWoW) addon that helps players track crafting recipes they haven't learned yet on their current character. It is a from-scratch, Ace3-free rebuild of [MissingCrafts](https://github.com/refaim/MissingCrafts), built because Turtle-style 1.12 clients frequently break when multiple addons each bundle their own copy of Ace3 (AceAddon/AceDB/AceGUI/AceHook/AceLocale share a single global registry, so mismatched versions/instances taint or clobber each other). Everything here is built on native `CreateFrame` + manual scripting, with no Blizzard UI templates and no Ace3.

## Architecture

### Environment Layer
- **`src/Environment.lua`**: Creates an isolated global environment using `setfenv(1, Gromissingcrafts)` that prevents global namespace pollution while maintaining access to WoW API
- Every `.lua` file must begin with `setfenv(1, Gromissingcrafts)` to work within this isolated environment
- Provides utility functions: `erase()` for table cleanup, `tpop()` for safe key removal

### Database Layer (`src/db/`)
Repository pattern implementation with clean domain models:

- **`Database.lua`**: Manages the `GromissingcraftsDatabase` SavedVariable directly (no AceDB) via a small get-or-create helper that auto-vivifies `global.realmToNameToCharacter[realm][name]` with default fields
- **`Character.lua`**: Domain model representing a character with profession knowledge and skill level checking
- **`CharacterRepository.lua`**: Data access layer for character CRUD operations
- **`CraftRepository.lua`**: Complex repository finding missing recipes based on character filters, handles craft sources mapping

### UI Layer (`src/ui/`)
Native-frame component system, no widget framework, and **no Blizzard UI templates on anything interactive** (`UIDropDownMenuTemplate`, `UIPanelButtonTemplate`, `InputBoxTemplate`, `UIPanelScrollFrameTemplate` were all tried and all got their input handling broken by pfUI's skinning — see git history). Every interactive frame is hand-built (manual backdrop/textures) and every one of them sets `SetFrameStrata("DIALOG")` explicitly, because **strata is not inherited from a parent frame** on this client — leaving it unset was silently losing click priority to whatever else was on screen underneath.

- **`UIManager.lua`**: Central coordinator managing window lifecycle, profession frame events, and component interactions. Hooks `MovePanelToLeft`/`MovePanelToCenter` via the local `hookGlobalFunction` helper (see `ui/Tools.lua`) — **not** the native `hooksecurefunc`, which isn't reliably present on true-1.12-era clients
- **`window/Window.lua`**: Main window — a plain `CreateFrame("Frame", ..., UIParent)` with a `DialogBox` backdrop, fixed `"DIALOG"` strata, **anchored directly to the profession frame** (`SetPoint("TOPLEFT", professionFrame.widget, "TOPRIGHT", ...)`) so it moves with it automatically via WoW's native anchor propagation — no drag support of its own, not meant to be repositioned independently
- **`filters/FiltersPanel.lua`**: Plain frame holding just a search box (the profession/character dropdown filters were removed by request — the window is already scoped to whichever profession frame it's attached to, and always the current character)
- **`filters/SearchField.lua`**: Hand-built `EditBox`, no template
- **`list/CraftsList.lua`**: **Not** a native `ScrollFrame` + `SetScrollChild` — that combination wasn't clipping its content reliably on this client (rows kept spilling past the frame's own height regardless of template). Instead it's a fixed pool of row widgets sized to exactly fill the visible area (the same technique Blizzard's own `FauxScrollFrame`-based lists use), with a scroll offset into the data. The scrollbar (bigger than Blizzard's default, click-and-drag capable) is fully custom too, built the same template-free way.
- **`list/CraftsListItem.lua`**: Individual recipe row — always was plain frames, unchanged from upstream
- **`TooltipEnhancer.lua`**: Enhances item tooltips with recipe learning status for each character (via `LibItemTooltip`, which was never Ace-based)
- **`window/OpenButton.lua`**: Toggle button that appears on profession frames to show/hide the main window
- **`DataStateManager.lua`**: State management for UI data synchronization and event coordination — tracks current character/profession/search query and re-queries `CraftRepository` on change
- **`VanillaFramePool.lua`**: Efficient frame reuse system for performance optimization
- **`window/PlacementPolicy.lua`**: Geometry/anchor rules per profession-frame type (now relative offsets from the profession frame's `TOPRIGHT`, not absolute screen coordinates), including pfUI detection (`IsAddOnLoaded("pfUI")`)

### Localization (`src/locale/`)
- **`Tools.lua`**: Minimal AceLocale-free replacement — one shared `L` table. `enUS.lua` loads **first** (see the `.toc` order) and populates every key as the fallback; every other locale file only receives the live table (and thus only gets to override keys) when `GetLocale()` matches its own code
- Multiple language files (enUS, ruRU, deDE, frFR, esES, ptBR, koKR, zhCN, zhTW)

### Dev tooling
- **`src/DevTools.lua`**: `/gromissingcrafts` (alias `/gmc`) slash command. `dump` walks whichever trade skill/craft window is open (`GetTradeSkillInfo`/`GetCraftInfo` + item-link parsing) and prints each recipe's exact name and result item id, since neither spell id nor required skill level is exposed by the client API for known recipes. Used to grow `lib/LibCrafts-1.0/Professions/Turtle/Survival.lua` with confirmed data instead of guesses.

## Key Technical Features

### Event-Driven Architecture
- Uses LibCraftingProfessions events (`LCP_SKILLS_UPDATE`, `LCP_FRAME_SHOW`, `LCP_FRAME_CLOSE`) for real-time updates
- Automatic profession data synchronization when skills are learned
- Dynamic UI updates when profession frames open/close

### Data Persistence
- Cross-realm character data storage with automatic cleanup, stored directly in `GromissingcraftsDatabase`
- Profession knowledge tracking with skill level requirements
- Recipe source mapping from LibCrafts constants to internal enums

## External Dependencies

### Kept from MissingCrafts (none of these were ever Ace3-dependent)
- **LibStub**: tiny library-versioning shim, not part of the Ace3 conflict surface
- **LibCraftingProfessions-1.0**: Profession frame detection and skill tracking across multiple addon types (extended here with `Survival`)
- **LibCrafts-1.0**: Comprehensive crafting recipe database with source information (extended here with `Professions/Turtle/Survival.lua`)
- **LibItemTooltip-1.0**: Tooltip enhancement framework (hooks `GameTooltip`/`ItemRefTooltip` methods directly)

### Removed entirely
- AceAddon-3.0, AceDB-3.0, AceGUI-3.0, AceHook-3.0, AceLocale-3.0 — see `README.md` and the plan history for the replacement mapping

## Supported Profession Addons

- Default WoW profession frames
- AdvancedTradeSkillWindow (ATSW)
- AdvancedTradeSkillWindow2 (ATSW2)
- Artisan
- pfUI

Different frame types require different initialization delays and positioning strategies — see `PlacementPolicy.lua`.

## Development Guidelines

### Code Style
- Extensive use of Lua `---@` type annotations for documentation and IDE support
- Object-oriented patterns using metatables with `self` parameters
- Acquire/release pattern for UI components to prevent memory leaks
- Repository pattern for clean data access abstraction

### File Loading Order
Files must load in the order given in `Gromissingcrafts.toc`:
1. `LibStub` + the three data libraries
2. `src/Environment.lua`, `src/Compatibility.lua`
3. Database layer files
4. Locale files — **`enUS.lua` must stay first** among locale files (see `locale/Tools.lua`)
5. UI component files
6. `src/DevTools.lua`
7. `src/Gromissingcrafts.lua` — main addon bootstrap (plain `ADDON_LOADED` event frame, no AceAddon)

### No live-client testing available in this environment
Changes here are verified statically (Lua syntax checks, manual trace-throughs, cross-checking renamed globals). Real acceptance testing has to happen in-game on OctoWoW/Turtle WoW.

### Lessons learned the hard way (read before touching UI code)
- **No Blizzard UI templates on interactive frames.** pfUI (and likely other skinning addons) hook/reskin recognized templates and this repeatedly broke click handling for dynamically-created widgets — first `UIDropDownMenuTemplate`, then `UIPanelButtonTemplate`, then `InputBoxTemplate`. Build interactive widgets from bare `CreateFrame` + manual backdrop/textures instead (see `Dropdown` history, `SearchField.lua`, `OpenButton.lua`).
- **Set `SetFrameStrata` explicitly on every interactive frame**, not just the top-level window. It is not inherited from a parent in this client; an unset child silently defaults to `"MEDIUM"` and can lose click priority to something else on screen even while it visually renders on top.
- **Native `ScrollFrame` + `SetScrollChild` did not reliably clip its content** on this client, template or no template. `CraftsList.lua` uses a fixed-size row pool instead (see that file's header comment).
- **Anchor to the frame you want to track, not to a computed absolute position.** The window used to snapshot the profession frame's screen coordinates once and reposition on a few known hooks; now it's anchored directly via `SetPoint(..., professionFrame.widget, ...)` so it tracks automatically, including drags, with no extra code.
