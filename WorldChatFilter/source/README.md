# World Chat Filter

> **Latest stable release: [v1.1.2](https://github.com/papafru/WorldChatFilter/releases/tag/v1.1.2).** This hotfix expands German social-guild invitation and Polish recruitment detection. Development changes were validated separately on `v1.1.2-dev`. Older releases, including v1.1.1 and v1.1.0, remain in the [release history](https://github.com/papafru/WorldChatFilter/releases).

**Keep the conversation. Filter the noise.**

**World Chat Filter** is a lightweight, rule-based chat addon for Vanilla-style World of Warcraft. It filters unwanted advertisements from the **`World` channel**, leaving room for normal conversations.

> [!IMPORTANT]
> **World only.** This addon does **not** filter actual **Trade, General, LookingForGroup, Guild, Party, Raid, or Whisper** chat. The *Trade* setting means **trade advertisements posted in World**.

## Features

- **Context-aware spam detection:** Combines advertising intent with context, rather than blocking every message containing a certain word.
- **Ad categories:** Trade (WTS/WTB/selling), group finding (LFG/LFM, raids, elite quests), guild recruitment, services (crafting, enchants, boosts, summons/taxi), and repeated messages.
- **Language-aware guild detection:** Curated signals from multiple languages and some transliterations, improved in v1.1.1 for Swedish, Polish, Spanish and French guild ads, and in v1.1.2 for German community invitations and additional Polish guild recruiting. No guild names or player names are blacklisted.
- **Sensitivity:** **Careful**, **Balanced** (default), or **Aggressive**.
- **Blizzard-style settings:** Dropdown menu with toggles, a circular minimap icon, and **Shift + drag** to reposition it.
- **World chat colors:** Optional World-only tint; four presets with swatches, plus a built-in **RGB Color Picker**. Default color: **Dusty Gold** (`#D1B77F`). The tint is local and can be disabled.
- **Statistics:** Dark Arcane statistics window with session/all-time counts per category and confirmation before resetting lifetime counts.
- **Help / Commands (v1.1):** Dark Arcane in-game help with General, Custom Filters and Tools tabs. `/wcf help` opens the panel instead of printing a command list in chat.
- **Diagnostics:** Explain sample classifications and troubleshoot channel identification.
- **Custom World-only filters (v1.1):** Personal blocked-player and word/phrase lists managed in a compact **Dark Arcane** two-tab panel with unified slate/bronze controls, Dusty Gold accents, and Partial/Whole Word matching for text entries. Right-click **Block/Unblock from World Chat** on chat player names. Nothing is added to WoW's global ignore list.
- **No dependencies:** Works without SocialChat or external libraries.

## Compatibility

- Built for the **Vanilla WoW 1.12 API** (`## Interface: 11200`) and **1.18-based custom clients**.
- Tested in-game on an **OctoWoW 1.18** client. Other 1.12/1.18 clients may differ.
- Assumes the channel is actually named **`World`**; numbered positions such as `4. World` and `5. World` are handled dynamically.
- Filtering is **client-side**: it cannot stop other people from posting or change what they see.

## Installation

**GitHub addon managers:** Add this repository URL directly: `https://github.com/papafru/WorldChatFilter`. The addon `.toc` and `.lua` files are at the repository root so compatible managers can detect and install it as `WorldChatFilter`.

**Manual installation:**

1. Download **[WorldChatFilter-v1.1.2.zip](https://github.com/papafru/WorldChatFilter/releases/download/v1.1.2/WorldChatFilter-v1.1.2.zip)** from the [v1.1.2 GitHub Release](https://github.com/papafru/WorldChatFilter/releases/tag/v1.1.2). Use the named release asset, not the auto-generated **Source code (ZIP)**, because only the release asset comes prepackaged in a `WorldChatFilter/` folder.
2. Close WoW and extract the ZIP.
3. Copy the **`WorldChatFilter`** directory into `World of Warcraft/Interface/AddOns/`.
4. Make sure this file exists: `Interface/AddOns/WorldChatFilter/WorldChatFilter.toc` (no extra nesting).
5. Start the game and type **`/wcf`** to open the settings menu.

**Upgrading from a beta:** Replace only `Interface/AddOns/WorldChatFilter/`; **do not delete your `WTF/.../SavedVariables/WorldChatFilter.lua`** file. The existing `WorldChatFilterDB` settings and statistics are preserved.

**Coming from the old SocialChat:** This addon has **no SocialChat dependency** and does not itself import the old SocialChat settings. If you already migrated, the old helper is no longer needed.

## Settings

Click the minimap icon or type `/wcf`. Available controls include:

- Enable/disable filtering and individual categories.
- Choose **Careful**, **Balanced**, or **Aggressive** detection.
- Open the **World Chat Color** submenu to enable the tint, choose a preset, open **Choose Custom Color...**, or reset to **Dusty Gold**.
- Open the **Statistics**, **Help / Commands** and **Custom Filters** Dark Arcane panels; reset session/all-time counters with in-window confirmation.

Preset colors:

| Preset | Color |
| --- | --- |
| Warm Stone | `#C9B8A2` |
| Soft Sage | `#A9BDA5` |
| Muted Lavender | `#B8A9CE` |
| Dusty Gold (default) | `#D1B77F` |

The color is applied to **new World messages only**, not previously displayed lines. When filtering or the tint is disabled, the addon restores the previous channel color while it is running. It does not write a new global chat color preference. Other chat-color addons may conflict.

## Slash commands

| Command | Action |
| --- | --- |
| `/wcf` | Open the settings menu |
| `/wcf toggle` | Toggle World filtering ON/OFF; suitable for an in-game macro |
| `/wcf custom` | Open blocked-player and blocked-phrase manager |
| `/wcf custom on` / `/wcf custom off` | Enable / disable personal lists |
| `/wcf block player NAME` / `/wcf unblock player NAME` | Manage a blocked World player |
| `/wcf block text PHRASE` | Block a case-insensitive text substring in World |
| `/wcf block word PHRASE` | Block a word/phrase with word-boundary matching |
| `/wcf unblock text PHRASE` | Remove a blocked word or phrase |
| `/wcf stats` | Toggle the statistics panel |
| `/wcf on` / `/wcf off` | Enable / disable filtering |
| `/wcf status` | Print current filter status and counts |
| `/wcf mode careful` | Lower detection sensitivity |
| `/wcf mode balanced` | Default sensitivity |
| `/wcf mode aggressive` | Higher detection sensitivity |
| `/wcf color on` / `/wcf color off` | Enable / disable World chat tint |
| `/wcf color picker` | Open the RGB Color Picker |
| `/wcf color reset` | Restore the Dusty Gold preset |
| `/wcf test <message>` | Explain the decision for a sample message |
| `/wcf debug` | Toggle classification reasons in chat |
| `/wcf channeldebug` | Toggle channel metadata diagnostics |
| `/wcf help` | Open the in-game Help / Commands window |

## How it works

1. **Check the channel first.** Only messages whose actual channel name is `World` are eligible for filtering. Conflicting or unrecognized channel metadata is allowed through, not blocked.
2. **Evaluate advertising intent.** The classifier combines recruitment wording, roles/classes, item links, contact instructions, prices, activities, destination lists, repeated posts, and other context.
3. **Apply filters and sensitivity.** Messages that meet the chosen threshold are hidden locally and counted in statistics.

For example, `LF 1Healer Hinterlands Elites` is a group-finding advertisement, while `What does LF1Mage mean?` is an ordinary question. This is a **rule-based classifier, not an AI model**; misses and false positives are still possible.

## Privacy and troubleshooting

- **World ads still appear:** Check `/wcf status` and verify the channel is named `World`. Try `/wcf test <message>` or temporarily use `/wcf channeldebug`.
- **Regular chat is hidden:** Try Careful sensitivity and report the text and the `/wcf test` explanation.
- **Errors or conflicts:** Mention the exact client version and other chat/color addons. The legacy chat event hook can conflict with another addon replacing the same handler.
- **No network telemetry:** The addon does not transmit chat messages, player names, or statistics to an external service.

Please redact player names and private information from screenshots before opening a public issue.

## Screenshots

Three screenshots of the actual **v1.1 Dark Arcane Blizzard** interface on OctoWoW 1.18.

### Custom Filters

Blocked Players and Words & Phrases, with partial/whole-word matching and a World-only block list.

![World Chat Filter v1.1 — Custom Filters](https://github.com/user-attachments/assets/fe01b6ef-b251-4957-bba9-f9e921b7f0db)

### Statistics

Per-character category, session and all-time counts, including Custom filters.

![World Chat Filter v1.1 — Statistics](https://github.com/user-attachments/assets/add029db-3b51-4314-ac73-b3b95dc4d2a2)

### Help / Commands

A searchable-by-tab in-game guide to the supported slash commands.

![World Chat Filter v1.1 — Help and Commands](https://github.com/user-attachments/assets/47ffc44a-dbf4-45e6-8d36-74155da7e2c3)

### Minimap and settings

![World Chat Filter minimap icon](docs/screenshots/minimap-icon.webp)

![World Chat Filter settings menu](docs/screenshots/settings-menu.webp)

## Contributing and license

Report missed ads **and** false positives so we can improve context recognition without resorting to player/guild blacklists. See [CONTRIBUTING.md](CONTRIBUTING.md) and the [changelog](CHANGELOG.md).

Distributed under the [MIT License](LICENSE).