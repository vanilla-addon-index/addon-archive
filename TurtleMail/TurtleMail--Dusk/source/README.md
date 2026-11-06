# 📬 TurtleMail — Turtle WoW

A lightweight mailbox enhancement for **World of Warcraft 1.12**, maintained for **Turtle WoW 1.18.x / Octo-like environments**.

TurtleMail improves the Vanilla mail interface with faster mail handling, multiple attachments, recipient autocomplete, mail logging and useful Auction House / returned-mail indicators.

> This fork keeps the original TurtleMail workflow while adding a compatibility and safety layer for modern Turtle WoW 1.12 environments.

## 📦 Installation

1. Download the addon.
2. Make sure the addon folder is named `TurtleMail`.
3. Copy it to:

   `World of Warcraft\Interface\AddOns\TurtleMail`

4. Restart the game.
5. Make sure **TurtleMail** is enabled in the AddOns menu.

No additional addon is required for the core functionality.

## ✨ Features

- Quickly open multiple mails.
- Quickly send multiple item attachments.
- Recipient name autocomplete.
- Automatically learns names from received mail.
- Auction House mail indicators.
- Returned-mail indicators.
- Displays the amount of gold collected while opening mail.
- Apply **Cash on Delivery (COD)** to the first attachment or all outgoing mails.
- Optional logging for sent and received mail.
- Dedicated mail log interface.
- Multiple localization support.
- Vanilla-style mailbox integration.

## 🖱️ Mail controls

### Inbox

**Right-click** an inbox entry to automatically:

1. Loot attached gold.
2. Loot the attached item.
3. Delete the empty letter.

COD mail is intentionally ignored by automatic opening and right-click collection.

### Attachments

- **Right-click** an inventory item to add it to an outgoing mail.
- **Left-drag** an inventory item to add it to the attachment list.
- **Right-click** an inventory item to add it to the trade frame.

## 📝 Mail logging

Mail logging is disabled by default.

Enable or disable it with:

`/tm log`

When enabled, TurtleMail records sent and received mail information in its dedicated log.

## ⚙️ Commands

| Command | Description |
|---|---|
| `/tm` | Display TurtleMail help |
| `/turtlemail` | Long version of `/tm` |
| `/tm help` | Display TurtleMail commands |
| `/tm log` | Toggle mail logging |
| `/tm clear sent` | Clear the sent-mail log |
| `/tm clear received` | Clear the received-mail log |
| `/tm clear names` | Clear saved autocomplete recipient names |

## 🔧 Turtle WoW compatibility

Version **1.4.12** extends the compatibility, safety, and performance layer for Turtle WoW 1.18.x environments.

The compatibility work is isolated in `TurtleMailFix.lua` so the original TurtleMail code remains easier to compare with upstream versions.

### Main fixes

- Fixed `MailHorizontalBarLeft` / `MailHorizontalBarRight` nil crashes.
- Added validation and repair for malformed autocomplete SavedVariables.
- Fixed learning sender names for recipient autocomplete.
- Fixed persistent autocomplete timestamp aging across client restarts.
- Fixed sent-money logging.
- Added safer inbox index and COD handling.
- Prevented stale Auction House and returned-mail icons.
- Added guards for missing or replaced mailbox frames.
- Improved package-frame safety.
- Added safer handling for malformed log entries.
- Fixed calendar tooltip nil/stale-value cases.
- Rebound the safer `OnUpdate` handler correctly after loading the compatibility layer.
- Prevented the send queue from remaining stuck when an attachment becomes unavailable during sending.
- Fixed `MailMailButton` nil crashes while enabling/disabling or clearing the send form, and hardened the paired subject edit-box reference.
- Restored the missing **Open Mail** button with an idempotent recovery path.
- Reduced first-open mailbox stutter by removing Open Mail layout repair from `MAIL_INBOX_UPDATE` and only changing the button when its state is actually wrong.
- Made Open Mail recovery fully lazy on mailbox open: normal openings now leave the existing button completely untouched, matching Otari-style behavior; full repair only runs if the button is missing, hidden, or re-parented.

The complete technical audit is available in [`AUDIT.md`](AUDIT.md).

## 🛡️ Compatibility notes

TurtleMail directly interacts with several Blizzard mailbox functions and frames.

Most standard Turtle WoW setups should work normally, but addons that heavily replace or re-parent the default mail interface may conflict with TurtleMail.

The compatibility layer keeps the upstream workflow intact where possible and only replaces fragile paths when needed for compatibility or safety.

## 🌍 Localization

TurtleMail includes localization support for:

- English
- French
- German
- Spanish
- Russian

## 🔧 Compatibility

- World of Warcraft 1.12
- Interface version `11200`
- Turtle WoW 1.18.x
- Octo-like Vanilla environments
- Vanilla Blizzard mailbox UI
- Optional pfUI integration

## 📜 Version

Current test version:

**1.4.11**

Based on upstream **TurtleMail 1.4.5**.

Version 1.4.10 keeps the **Open Mail** recovery from 1.4.9 but makes it lightweight: the button is repaired on load/mailbox open only when needed, instead of being re-parented and re-anchored on every inbox refresh. This avoids repeated layout work during the initial mailbox update burst.

Version 1.4.11 also removes the per-call `pack()`/`unpack()` allocation from TurtleMail's `GetContainerItemInfo` hook. The native return count is detected once at login and preserved exactly (up to 12 values), while normal bag queries use fixed local values. This reduces garbage collection pressure during bag/mailbox refreshes without changing mail behavior.

## 🖼️ Screenshots

![TurtleMail](https://i.imgur.com/H0MUmXd.png)

![TurtleMail](https://i.imgur.com/LM7tRcx.png)

## 📜 Project identity & licensing

TurtleMail is an independent community-maintained fork with this known source
chain:

- [shirsig/Mail](https://github.com/shirsig/Mail)
- [sica42/TurtleMail](https://github.com/sica42/TurtleMail)
- this maintained fork

No explicit project-wide license was identified in the two known upstream
repositories during the provenance audit, so this fork does **not** claim to
relicense inherited code.

Compatibility with **World of Warcraft**, **Turtle WoW / Octo-like
environments**, or **pfUI** does not imply affiliation, endorsement, or
sponsorship.

For details, see:

- [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
- [PROJECT_IDENTITY.md](PROJECT_IDENTITY.md)
- [Docs/CODE_PROVENANCE.md](Docs/CODE_PROVENANCE.md)
- [Docs/ASSET_PROVENANCE.md](Docs/ASSET_PROVENANCE.md)
- [LICENSES/](LICENSES/)

## 🙏 Credits

Original TurtleMail addon by **shirsig / sica**.

Upstream maintenance by **sica42**.

Turtle WoW compatibility fixes and additional maintenance by **Dusk-92**.

This fork aims to preserve the original TurtleMail experience while improving compatibility and stability on modern Vanilla server environments.
