# Spyglass

Why? I'm lazy and I don't want to type on the db the name of the npc and search for the specific npc I'm looking for.

_WOTLK version [here](https://github.com/Taeko-ar/Spyglass/tree/3.3.5a)_

## Features

- **Configurable Database URL**: Prompt-based setup UI on first load. Easily switch between preconfigured presets (like OctoWoW DB, Classic DB, etc.) or type in your own custom server database URL!
- **Startup Suggestions**: Displays a smart suggestion (`https://octowow.st/db/`) on first startup that you can click to automatically fill.

## Dependencies

- **WoW 1.12.1 (Vanilla)**: Because the base Vanilla client does not natively expose precise NPC IDs to the Lua API, **this addon utilizes [SuperWow](https://github.com/balakethelock/SuperWoW)** for exact ID extraction.

*If neither of these native IDs are found (or you don't run SuperWoW), the addon features an automatic smart-fallback that generates a URL to query the database by the NPC's actual name rather than their exact database ID.*

## How it Works

1. Target an NPC, find an Item/Quest/Spell Link in the chat, or open your inventory bags.
2. **Right-click** an NPC target frame, **Ctrl+Right-Click** a chat link, or **Ctrl+Right-Click** any inventory item.
3. A small dropdown context menu will appear by your cursor. Click **Spyglass Lookup**.
4. A popup window will appear on your screen containing a direct link to the NPC or Item.
5. The URL text is automatically highlighted, so you can instantly press `Ctrl+C` to copy it and paste it into your browser.

## Commands

- `/spyglass` (or `/qdb`) - Force a database lookup on your current target via chat instead of using the right-click menu.
- `/spyglass setup` - Reopen the database URL configuration panel.
- `/spyglass toggle` - Enable or disable the addon.
- `/spyglass debug` - Toggles the debug mode.
- `/spyglass help` - Shows a list of available slash commands.

## Translations

This plugin has translations and support for Spanish and Portuguese.

## Supported Unitframes

The right-click context menu seamlessly intercepts interaction for most commonly used Vanilla Unitframe addons natively:
- **Default Blizzard Target Frames**
- **pfUI** (`pfTarget`)
- **LunaUnitFrames** (`LunaTargetFrame`)
- **XPerl** (`XPerl_Target`)
- **Shadowed Unit Frames** (`SUFUnittarget`)
- **DiscordUnitFrames** (`DUF_TargetFrame`)

*Note: The addon also explicitly hooks into the overarching `ClickCastFrames` API protocol, granting it universal out-of-the-box compatibility with almost any obscure or custom unit frame addon.*
