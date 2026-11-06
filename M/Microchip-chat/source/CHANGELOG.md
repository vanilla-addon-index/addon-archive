# Microchip-chat — CHANGELOG

## v0.9.0 — Default font size for all channels

- Added a numeric **Default chat font size** field under `/mchat options` → **General → Window & Controls**.
- Enter a whole number from **9 to 20 pt** and press Enter or **APPLY** to update all existing chat tabs, including detached windows and Combat Log.
- Newly created tabs inherit the configured default font size.
- Per-tab font controls remain available for individual adjustments after applying the global default.
- Added `/mchat defaultfont 14` as a shortcut to apply a default size to all tabs.
- Existing per-tab font sizes are preserved on upgrade until the global Apply control is used.

## v0.8.9 — Clear message history

- Added **Clear All History** to `/mchat options` → General → History Limits.
- Confirm or cancel before deleting saved messages.
- Clearing removes all retained chat and combat messages, as well as the currently displayed message feeds in the main and detached windows.
- Tabs, window positions, filters, history limits, appearance options, and other settings are unaffected.
- New messages continue appearing normally after clearing; cleared messages cannot be recovered.


## v0.8.8 — Detachable chat windows

- Detach individual chat tabs into independent windows. Keep General on one side of the screen and Combat Log, Guild, or another tab on the other.
- Configure a tab under `/mchat options` → tab → CHANNELS → **DETACH WINDOW**. Choose **DOCK WINDOW** to move it back.
- Drag a detached window by its title bar; resize using its bottom-right RESIZE control. Window locking applies to all chat windows.
- Each detached chat window has its own compact view, expandable history, mouse-wheel navigation, TOP/BOTTOM buttons, clickable names and links, and Combat Log mini-tabs where applicable.
- Windows reuse per-channel message history without copying it. Retention limits and World filters continue to work as before.
- Positions and dimensions persist between sessions. Each tab returns to its saved detached/docked state at login.
- The native chat input follows the chat window currently being used. Only one chat input is created, preserving Enter and slash-command behavior.
- Keep at least one tab in the original dock so its controls remain accessible.
- Slash commands: `/mchat window detach 2` and `/mchat window dock 2` (tab numbers start at 1).
- Preserved the compact-history renderer and the vanilla Lua 5.0 upvalue limit.

---

# Microchip-chat

**Microchip-chat** is a customizable, New World-inspired chat replacement for **OctoWoW's modified World of Warcraft 1.12 client**. It keeps live chat compact while making older messages easy to find, without the default WoW chat window taking up screen space.

## Screenshots

**Live chat** — a compact chat feed with tabs and auto-hiding controls.

![Microchip-chat live chat](screenshots/live-chat.png)

**Chat history** — the same window expands upward to browse earlier messages.

![Microchip-chat expanded history](screenshots/chat-history.png)

*Screenshots show an earlier version of the toolbar branding.*

## Features

- **Minimal live chat:** Messages scroll upward, include timestamps, and can fade after a configurable number of seconds. Message fading can also be disabled.
- **Expandable history:** Scroll through previous messages in the same window, jump to the oldest or newest messages, and configure retention separately for each channel. Older messages are loaded on demand for smoother browsing.
- **Custom chat tabs:** Create tabs with their own channel selections, message colors, font sizes, and filters. The default chat tab enables supported channels except LFT.
- **Combat Log:** A separate combat tab with **All Events** and **What Happened to Me** views.
- **Built-in filtering:** Block words or phrases and filter World chat advertisements independently for each tab. No separate WorldChatFilter installation is needed.
- **Class-colored names:** Player names use class colors when the client can identify their class. Names remain clickable for whispers and other player interactions.
- **Clickable links:** Supports WoW item links and web addresses. Clicking a web address opens a text field so you can copy it with **Ctrl+C**.
- **Customizable appearance:** Adjust window, button, and interface-text colors; move, resize, or lock the chat window; and configure the auto-hiding toolbar.

## Installation

1. Extract the `Microchip-chat` folder into `World of Warcraft/Interface/AddOns/`.
2. Check that `Microchip-chat.toc` is directly inside the addon folder.
3. Start the game and enter `/mchat options` to customize the interface.

Use `/mchat history` to toggle expanded history. The older `/osc` command is also supported.

## Credits

Includes a built-in World chat filtering implementation adapted from [WorldChatFilter](https://github.com/papafru/WorldChatFilter). See `WORLDFILTER_LICENSE.txt` in the addon for attribution and license details.
