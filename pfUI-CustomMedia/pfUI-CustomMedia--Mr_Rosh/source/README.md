# pfUI-CustomMedia

<img src="https://i.imgur.com/CuRkjdU.jpeg" width="512">

**pfUI-CustomMedia** is a lightweight plugin for [pfUI](https://github.com/shagu/pfUI). It adds custom textures for unitframes, castbars, experience bars, action buttons, and gryphons, along with additional styling for pfUI's interface elements.

## Installation (Vanilla, 1.12)

1. Download the [latest version](https://github.com/mr-rosh/pfUI-CustomMedia/archive/master.zip).
2. Unpack the archive and rename `pfUI-CustomMedia-master` to `pfUI-CustomMedia`.
3. Copy the folder into `Wow-Directory/Interface/AddOns`.
4. Restart WoW.

## Installation (The Burning Crusade, 2.4.3)

1. Download the [latest version](https://github.com/mr-rosh/pfUI-CustomMedia/archive/master.zip).
2. Unpack the archive and rename `pfUI-CustomMedia-master` to `pfUI-CustomMedia-tbc`.
3. Copy the folder into `Wow-Directory/Interface/AddOns`.
4. Restart WoW.

## Changelog

### 2.3.9 (2026-10-24)

- Replace deprecated Lua 5.1 APIs (`string.gfind`, `table.getn`, `getfenv`, `setfenv`) with modern equivalents.
- Capture `event`/`arg1` into locals in all `OnEvent`/`OnUpdate` handlers (Classic 1.12-safe).
- Cache resolved button frames so `_G` lookups are not repeated on every update pass.
- Skip redundant `SetTexCoord` calls in staticbars when the bar fill fraction hasn't changed.
- Cache `GetScreenHeight()` per dropdown menu open instead of querying every frame.
- Remove dead `translations`/`L()` indirection in buttons module.
- Bump version to 2.3.9; add `## SavedVariables` to both TOCs.

### 2.3.8 (2026-10-18)

- Add new statusbar textures and fonts to the selection menus.
- Add a pfUI styled scrollbar and mouse wheel scrolling to dropdown menus; menus open upward when there isn’t enough space below.
- Fix gryphon positioning, dragging, and anchor handling.
- Add a position reset option that preserves gryphon appearance and anchor settings.
- Clean up gryphon texture options and dropdown behavior.
- Simplify gryphon reset controls and improve their layout.

### 2.2.0 (2026-10-17)

- Remove menu entries for the missing Karla font and Sword button background.
- Apply custom backgrounds to pfUI buttons even when they are hidden.
- Guard optional pfUI menus and GUI methods against Lua errors.
- Prevent duplicate gryphon entries and keep font menu ordering stable.
