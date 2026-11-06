# **RallyHelper** — Modern World Buff Tracker for Turtle WoW

<img width="640" height="640" alt="RallyLogo" src="https://github.com/user-attachments/assets/d3519b5c-a137-4a76-ac6e-d33b8a07fffd" />

**RallyHelper** is a lightweight, accurate, and clean world buff tracker designed specifically for **Turtle WoW**.

It focuses on reliability, minimal chat spam, and modern quality-of-life features.

**Current Version: 1.4.5**

---

## ✨ Key Features

- **Realm-specific Timers**  
  Timers are now saved per realm. Switching realms no longer shows timers from the previous realm.

- **Verified Buff Detection**  
  Buff events are only accepted after verification from multiple sources. Unconfirmed buffs are shown clearly.

- **Improved Server Restart Detection**  
  Better detection of server restarts and automatic timer reset.

- **Zero Spam Design**  
  No heartbeats, no version spam, no periodic messages — only actual buff events.

- **Modern Scalable UI** (since 1.4.0)  
  - Completely redesigned layout with icons  
  - Faction filter (Horde / Alliance / Both)  
  - Resizable, scalable, draggable  
  - Hover fade effect  
  - Fully pfUI compatible

- **Settings Window**  
  Easy access to faction filter, UI scale, size, lock, sound settings, and more.

- **Unconfirmed Buffs Window**  
  Scrollable list of buffs that have not yet been fully verified.

- **Enhanced Minimap Button**  
  - Left Click → Toggle main UI  
  - Alt + Click → Open Settings  
  - Shift + Click → Share timers to chat  
  - Middle Click → Open Unconfirmed window  
  - Right Click → Print status  
  - Alt + Drag → Reposition button

- **Darkmoon Faire Detection**  
  Automatically detects DMF NPCs and records the last seen zone.

- **Customizable Sounds**  
  Individual sounds per buff with volume control.

---

## 📦 Installation

1. Download the latest release ZIP from GitHub.
2. Extract the folder into your `Interface/AddOns` directory.
3. Make sure the folder is named exactly **RallyHelper**.
4. Restart the game or type `/reload`.

---

## 🧭 Commands (`/rally`)

- `/rally` — Toggle the main UI
- `/rally status` — Print current timers in chat
- `/rally share` — Insert current timers into chat edit box
- `/rally request` — Request timers from other players
- `/rally settings` — Open the settings window
- `/rally reset` — Reset UI position and size
- `/rally users` — Show number of active RallyHelper users (anonymous)

**Sound & Toast:**
- `/rallysound on|off`
- `/rallysound volume <0-100>`
- `/rallytoast chat|ui|none`

**Ignore System:**
- `/rallyignore add|remove|list <name>`

---

## 📷 Screenshots


<img width="395" height="204" alt="both" src="https://github.com/user-attachments/assets/14c098d9-e93d-4019-ac46-ef514c695bd5" />

<img width="343" height="149" alt="alliance" src="https://github.com/user-attachments/assets/6188037e-2495-4de2-ae74-a81d508aab6f" />

<img width="327" height="180" alt="horde" src="https://github.com/user-attachments/assets/09dc2b01-ebb9-489d-b12a-4de99cb23129" />

![Settings](https://github.com/user-attachments/assets/b092ca3e-c64e-4c23-b5dd-428e304e5181)

---

## 🧾 Changelog (Summary)

**1.4.5** (Latest)
- Timers are now saved **per realm** (no more cross-realm timer leakage)
- Significantly improved server restart detection
- Minor stability and code improvements

**1.4.0** (Major Update)
- Completely redesigned modern UI
- New settings window
- Faction filter (Horde / Alliance / Both)
- Unconfirmed buffs window
- Better synchronization and pfUI compatibility

For the full changelog, see [CHANGELOG.md](CHANGELOG.md).

---

## ⚠️ Notes

- Works great with **pfUI**.
- If you experience sync issues with very old addons (e.g. LazyPig), try disabling them.
- Timers are intentionally saved per realm.

---

## ❤️ Support & License

RallyHelper is completely free and open source (MIT License).  
Donations are welcome but never required:

[Ko-fi](https://ko-fi.com/weirdpuppy94)

