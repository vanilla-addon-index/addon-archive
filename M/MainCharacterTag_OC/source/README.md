# MainCharacterTag_OC

![Version](https://img.shields.io/badge/version-1.7-blue) ![Interface](https://img.shields.io/badge/OctoWoW_1.18-1.12.1-yellow)

A lightweight World of Warcraft addon for OctoWoW (1.18) or other 1.12.1 WoW clients that automatically tags your guild chat messages with your main character's name when playing on alts.

## What it does

When you chat in **Guild** or **Guild Officer** chat on an alt, your messages are automatically prefixed with your main's name so guildmates always know who they're talking to.

**Example:** Playing on your alt `Shadowpoke` with main set to `Thunderbash`:
> **Shadowpoke (Thunderbash): Hey all, it's me just on my alt!**

Messages sent from your main character are unaffected.

## Installation

1. Download and unzip the addon
2. Remove `-main` from the folder name if downloaded from GitHub (it should be `MainCharacterTag_OC`)
3. Place the `MainCharacterTag_OC` folder in:
   ```
   World of Warcraft/Interface/AddOns/
   ```
4. Restart WoW or reload your UI (`/reload`)
5. Enable **MainCharacterTag_OC** on the character select screen

## Usage

Type `/mct` or `/mainchartag` to open the options window.

Enter your main character's name and click **Save**. That's it.

## Options

| Command | Description |
|---|---|
| `/mct` | Toggle the options window |
| `/mainchartag` | Toggle the options window (alternate) |

## Notes

- Only affects **Guild** (`/g`) and **Guild Officer** (`/o`) chat
- Messages starting with `.`, `/`, or `#` are never prefixed
- Achievement spam filter is off by default and can be toggled in the options window
- Shellcoin price system message filter is off by default and can be toggled in the options window
- Your main's name is saved between sessions per character
- Works on any number of alts
- No performance impact — only runs when you send a guild message

## Changelog

### 1.7
- Changed Shellcoin filter to match messages starting with `Shellcoin price` instead of `Shellcoin`

### 1.6
- Added checkbox to hide `Shellcoin price` system messages (default: off)

### 1.5
- Added checkbox in options to toggle filtering of `has earned the achievement` messages in guild and officer chat (default: off)

### 1.4
- Achievement messages (`has earned the achievement`) are now hidden from guild and officer chat

### 1.3
- Messages starting with `.` (server commands), `/` (slash commands), and `#` (macro directives) are now ignored by the prefix hook

### 1.2
- Fixed an issue where logging in on an alt could trigger unintended chat messages from other addons during the login sequence
- Fixed macro directives (e.g. `#showtooltip`) incorrectly being sent to guild chat

### 1.0
- Initial release
