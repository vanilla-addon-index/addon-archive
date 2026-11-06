<p align="center"><img src=".github/logo.png" alt="PandaUI logo" width="64"></p>

# PandaUI

**Rediscover Azeroth. Keep the soul of Vanilla, without the interface friction.**

A complete interface overhaul built for **OctoWoW** (1.12.1 client).

> [!IMPORTANT]
> ## Install PandaUI
> 1. [Download the latest release](https://github.com/Tom75VN/PandaUI/releases/latest/download/PandaUI.zip).
> 2. Extract the archive into `Interface\AddOns\` in your OctoWoW folder.
> 3. Rename the extracted `pandaUI-master` folder to `pandaUI` by removing `-master`.
> 4. Confirm that `pandaUI.toc` is directly inside the `pandaUI` folder, then launch the game or reload the interface.

![PandaUI: Classic WoW, Modern and Modern WoW](screenshots/main-screenshot.jpg)

## Three interfaces, one addon

Pick the look you want in the settings; every feature works in all three.

- **Classic WoW**: keep the native interface you know, with all of PandaUI's features.
- **Modern**: a clean, minimalist flat design.
- **Modern WoW**: the look and feel of the Retail interface.

| Classic WoW | Modern | Modern WoW |
|---|---|---|
| ![Classic WoW theme](screenshots/theme-classic-wow.jpg) | ![Modern theme](screenshots/theme-modern.jpg) | ![Modern WoW theme](screenshots/theme-modern-wow.jpg) |

## Main features

### Visual Edit Mode

Move any element, snap it to a grid or place it freely. Unit frames, action bars, bags, cast bars, XP and reputation bars, the quest tracker and more all live in one edit mode, and the layout is kept across reloads.

![Visual Edit Mode](screenshots/edit-mode.jpg)

### Quick Binding

Hover an action slot and press a key. No trip through nested menus.

![Quick Binding mode](screenshots/quickbinding.jpg)

### Settings in one place

PandaUI's options sit inside the game settings window, next to Video, Sound and Interface. Switch theme, toggle features, and open Edit Mode from the same screen. The interface is available in **English, French, Russian and Chinese**.

![PandaUI settings](screenshots/settings-addon.jpg)

### 10 configurable action bars

Control the number of buttons, rows, size, spacing and cooldown display for each bar.

### Unit frames, nameplates and combat feedback

- Modern unit frames with real enemy HP and mana numbers.
- Nameplates, colour-coded debuffs, a cast bar and a swing timer.
- Party frames with buffs, debuffs, heal prediction and HoT timers.

![Party frames](screenshots/party-frame.jpg)

### Raid frames

Up to 8 groups of 5, with class-coloured health, power, heal prediction, your own HoTs, debuffs and dispel highlights.

![Raid frames](screenshots/raid.jpg)

### Restyled windows

Quest Log, Character, Spellbook, Talents, Social and more share one consistent style.

**Character**

![Character window](screenshots/character.jpg)

**Spellbook and Professions**

![Professions window](screenshots/professions.jpg)

![Spellbook](screenshots/spellbook.jpg)

**Crafting** with recipe search, difficulty filter and a recipe tracker you can keep on screen.

![Crafting window](screenshots/crafting.jpg)

### Talent build advisor and equipment sets

Follow a Leveling, PvP or Raid build: the advisor highlights the talent to pick next and flags points spent outside the build. Save and swap equipment sets from the Character window.

![Talents and Build Advisor](screenshots/talents.jpg)

### Bags and bank

A unified bag and bank window with sorting, search and one-click junk selling.

**Category view**: switch the bag to sort your items into categories automatically: Quest Items, Potions, Buffs, Cloth, Gems, Trade Goods, Recipes and more. Collapse any category you don't need, mark favorites to keep them at the top, and see every free slot as a single "Empty" counter. The bank uses the same view.

| Category view | Unified bag |
|---|---|
| ![Bag category view](screenshots/bags-categories.jpg) | ![Unified bag](screenshots/bags-unified.jpg) |

## Extras

- Saved bank, viewable anywhere.
- Item sell prices and item comparison.
- Auto-sorting into specialty bags.
- World map coordinates and zone level ranges.
- XP and reputation bars with rested XP.
- Low-health and loss-of-control screen warnings.
- Profession recipe tracker on screen.

## Roadmap

- **Important:** fix the minimap moving after a relog or `/reload` for some players.
- Browse the bags and bank of your other characters on this account.
- First-run setup wizard: pick a theme and a ready-made layout for DPS, Healer or Tank, plus a few basic options.

## Get started

Use `/pui` to open the settings, `/pui unlock` to arrange supported elements, `/pui bind` to enter Quick Binding mode, and `/pui help` for the full list.

## Version

Current release: **0.13.4**

[See what changed](CHANGELOG.md).

## Acknowledgements

PandaUI is a port of [UnrealUI](https://github.com/Tom75VN/UnrealUI) 0.10.2 to the OctoWoW client.

[pfUI](https://github.com/shagu/pfUI) by Eric Mauser (Shagu) is used as a technical and design reference during PandaUI development. pfUI is not bundled with PandaUI.

The Modern WoW theme includes art from DragonflightUI-Reforged and Blizzard UI assets. Sources are listed in the `ATTRIBUTION.md` files under [media/Textures](media/Textures/), and talent build sources in [TALENT_ADVISOR_SOURCES.md](TALENT_ADVISOR_SOURCES.md).

## License

PandaUI's code is distributed under the [MIT License](LICENSE). Third-party and Blizzard art keeps its original ownership, as noted in the attribution files.
