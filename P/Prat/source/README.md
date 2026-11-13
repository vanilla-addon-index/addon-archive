# Prat

A framework addon for chat frame modules for World of Warcraft (this build targets the OctoWoW / Turtle WoW client, Interface version 11200).

> **Note:** I am not the author of this addon. This is a third-party mod (Prat Development Team, laytya, Qxcl, and contributors — see credits below). This README is my own notes for using and configuring it.

## Table of Contents

- [What it does](#what-it-does)
- [Installation](#installation)
- [Opening the options](#opening-the-options)
- [Modules & Options](#modules--options)
  - [Buttons](#buttons)
  - [ChannelColorMemory](#channelcolormemory)
  - [ChannelNames](#channelnames)
  - [ChannelSeparator](#channelseparator)
  - [ChatTabs](#chattabs)
  - [Editbox](#editbox)
  - [Fading](#fading)
  - [FontSize](#fontsize)
  - [Highlight](#highlight)
  - [History](#history)
  - [Justify](#justify)
  - [Keybindings](#keybindings)
  - [Notification](#notification)
  - [PlayerNames](#playernames)
  - [PopupMessage](#popupmessage)
  - [Scroll](#scroll)
  - [StickyChannels](#stickychannels)
  - [TellTarget](#telltarget)
  - [Timestamps](#timestamps)
  - [UrlCopy](#urlcopy)
  - [Who](#who)
- [Slash Commands](#slash-commands)
- [Troubleshooting](#troubleshooting)
  - [Annoying sound plays whenever your name is mentioned](#annoying-sound-plays-whenever-your-name-is-mentioned)
  - [Sound spams repeatedly while your pet is attacking](#sound-spams-repeatedly-while-your-pet-is-attacking)
  - [Turning on "Debugging" does nothing](#turning-on-debugging-does-nothing)
- [Credits](#credits)

## What it does

Prat replaces and extends the default chat frame with a large set of independent modules, covering things like tabs, timestamps, fading, scrolling, font size, player name formatting, channel name abbreviation, popup notifications, and more. Every module can be toggled on/off and configured individually through the in-game options panel.

## Installation

Place the `Prat` folder in your `Interface/AddOns/` directory (already done if you're reading this from that folder), then enable **Prat** on the character selection AddOns list.

## Opening the options

- `/prat` — opens the graphical options panel (Waterfall UI).
- `/pratcl` — opens the same options as a command-line/console menu.

## Modules & Options

### Buttons
Chat window menu and buttons options. `ChatMenu` toggles the chat menu button on/off.

### ChannelColorMemory
Remembers the color you've set for a channel by its name, so channel colors persist across sessions/relogs. Has an on/off toggle.

### ChannelNames
Abbreviates channel names (e.g. Say, Yell, Guild, Officer, Party, Raid, Whisper) in the chat window, with a per-channel-type settings group.

### ChannelSeparator
Adds a visual separator between chat channels in the chat settings/channel list menu. Has an on/off toggle.

### ChatTabs
Chat window tab options, including a `SetMode` setting to change tab behavior.

### Editbox
Controls the chat editbox appearance, e.g. `Alpha` to set its transparency.

### Fading
Chat window text fading options — fades old chat text out over time. Has a `TextFade` group to configure fading per window.

### FontSize
Chat window font size options, with a `SetMode` setting to choose how font sizes are applied (e.g. globally vs per window).

### Highlight
Text highlighting options for chat windows. Has an on/off toggle.

### History
Chat history options — configure how many lines of history are kept per chat window.

### Justify
Chat window text justification (alignment) options, configurable per window.

### Keybindings
Adds keybindings related to chat (see the in-game Key Bindings menu, Prat section).

### Notification
Chat channel notification options. Has an on/off toggle for the module.

### PlayerNames
Player name formatting options:
- `Brackets` — style of brackets around player names (e.g. `[Name]`, `<Name>`, or none).
- Common name coloring options, including a custom color picker.
- `Mark self` — toggles special color-marking of your own name whenever it appears in chat, with its own color picker. **This is also what triggers a notification sound** — see [Troubleshooting](#annoying-sound-plays-whenever-your-name-is-mentioned).
- Module on/off toggle.

### PopupMessage
Shows a popup message (with sound) whenever your name appears in chat.
- `Toggle` — module on/off.
- `ShowMode` — `ALL` or `INDIVIDUAL` (per chat window).
- `Show` — per chat-window toggles for which windows trigger popups (only relevant in `INDIVIDUAL` mode).

### Scroll
Chat window scrolling options, including toggling mouse-wheel scrolling.

### StickyChannels
Keeps your last-used chat channel "sticky" so it stays selected, configurable per chat type.

### TellTarget
Adds a `/tt` slash command to whisper your current target. Has an on/off toggle.

### Timestamps
Adds timestamps to chat lines, with a `ShowMode` setting to choose the timestamp format/behavior.

### UrlCopy
Formats URLs posted in chat so they can be clicked/copied, with a `Show Brackets` toggle.

### Who
Adds channel-related actions and a `/chatwho` command to list users on a channel.

## Slash Commands

| Command | Description |
|---|---|
| `/prat` | Open the Prat options panel (GUI) |
| `/pratcl` | Open the Prat options as a command-line menu |
| `/tt` | Whisper your current target (from the TellTarget module) |
| `/chatwho` | List users on a channel (from the Who module) |

## Troubleshooting

### Annoying sound plays whenever your name is mentioned

Prat plays the default "FriendJoinGame" sound every time someone says your name in chat. This comes from two separate modules and can be disabled from either:

1. Open options with `/prat`.
2. Go to **PlayerNames** → turn off **Mark self**.
3. Go to **PopupMessage** → turn off **Toggle** (this disables the popup entirely, including its sound).

If you still want the popup or the self-color highlighting but not the sound, note that in this version the sound is hard-wired into those features (there's no separate "mute sound" checkbox) — disabling the feature itself is currently the only way to stop the sound.

### Sound spams repeatedly while your pet is attacking

With **Mark self** (PlayerNames) turned on, having a pet out and attacking can cause the "FriendJoinGame" sound to spam repeatedly, once per combat message. This happens because pet combat log lines (e.g. your pet's attacks) also contain your character's name, so every single one of those messages re-triggers the same self-name match and plays the sound again.

Workaround: turn off **Mark self** in PlayerNames options (`/prat` → PlayerNames → Mark self) while your pet is fighting, or keep it disabled entirely if you use a pet class regularly.

### Turning on "Debugging" does nothing

At the top of the `/prat` (or `/pratcl`) options list there's a **Debugging** toggle. This comes from the Ace2 framework (`AceDebug-2.0`), not from a Prat module — enabling it just sets an internal `debugging` flag on the root `Prat` addon object. It only produces output if some code actually calls `self:Debug(...)` while that flag is on.

In this build, none of the Prat modules (or `Prat.lua` itself) ever call `:Debug()`, `:LevelDebug()`, or similar — so there is nothing wired up to print. Turning the toggle on/off is expected to have **no visible effect in-game**; it isn't broken, it's just an unused hook left over from the Ace2 framework that this version of Prat doesn't take advantage of.

## Credits

Prat Development Team, laytya, Qxcl, and contributors: Industrial, Ammo, Cirk, Yris, Leuchtturm, AnduinLothar, Satrina, 昏睡墨鱼&月色狼影, RuWOW team.

Website: https://github.com/Qxcl/Prat-turtle
