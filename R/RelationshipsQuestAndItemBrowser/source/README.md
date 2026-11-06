<img src="https://i.postimg.cc/15cJh6y2/hfgh.gif"/>
<img src="https://i.postimg.cc/7ZHXx66D/sdfsdf.gif"/>

# Relationships Quest And Item Browser

A World of Warcraft addon for **OctoWoW** that turns every quest and item link into something you can click, browse, search, and cross-reference — all from a single movable window.

---

## 🚀 Features

### 🟢 Clickable [+] buttons on chat links
- Every quest link (`[Quest Name]`) and item link (`[Item Name]`) that appears in any chat window gets a small green **[+]** icon overlaid next to it.
- **Click the [+]** → the quest or item opens inside the RQL browser instantly.
- The original Blizzard link is untouched — normal shift-click to link, tooltips, and the default quest popup still work.
- Multiple links on the same message stack their **[+]** icons together (`+ + +`) so nothing gets lost.
- **Line-wrap aware:** if a chat message wraps to a second (or third) line, the **[+]** buttons follow the message and appear at the end of the actual wrapped line — never floating off the right edge of the chat frame. If the row of **[+]** icons would exit the frame, they wrap down to the next line too.
- Works across all `ChatFrame1`–`ChatFrame7` tabs; buttons hide automatically when messages scroll off screen.

### 🔎 Quest browser (`/rql`)
- Full-text search across quest **titles, objectives, and descriptions**.
- Filter dropdowns:
  - **Level range** — All, 1‑9, 10‑19, … 60+
  - **Type** — Normal, Dungeon, Raid, PvP / Battleground, Class, Profession, Elite
  - **Faction** — Alliance, Horde, Both / Neutral
  - **Source** — Vanilla, Turtle-exclusive
- Results are sortable and paginated with a scrollable list.
- Every result row is clickable and opens the quest detail view.

### 📜 Quest detail view
When you open a quest (via a chat **[+]**, a search result, or `/rql quest <id>`), you get:
- Quest **title** with color-coded difficulty relative to your level
- **Level**, **faction**, **type**, and **source** tags
- Full **objective** and **description** text from the bundled database
- **Starter NPC**, **turn-in NPC**, and **objective targets** (NPCs, objects, items)
- **Prerequisite quests** — each rendered as a clickable button so you can walk the whole chain
- **Related items** — each rendered as a clickable button that opens the item view
- Coordinates for starters/turn-ins/targets when the database has them
- A shift-clickable link so you can share the quest back into chat

### 📦 Item browser & item detail
- Separate **Item Search** bar for finding items by name.
- Item detail shows the icon, name, quality color, item type/subtype, required level, and full tooltip text.
- **"Used in quests"** section lists every bundled quest that references this item — click any entry to jump straight to that quest.
- Works for items you've never seen before, using the game's tooltip cache.

### 🧭 Movable, resizable browser window
- Drag the title bar to move.
- Remembers position between sessions (saved per character).
- Close with the `X`, `Escape`, or by re-running `/rql`.

### 📚 Bundled quest & item database
Ships with data extracted from **pfQuest** and **pfQuest-turtle**, covering:
- Vanilla WoW quests (all factions, all zones)
- Turtle WoW / OctoWoW custom quests and items
- NPC, object, and zone name lookups
- No external database addon required — it just works offline.

---

## 🎮 Slash commands

| Command | What it does |
|---|---|
| `/rql` | Open the quest browser |
| `/rql search <text>` | Open browser and run a text search |
| `/rql level 20-29` | Filter by level bracket |
| `/rql type dungeon` | Filter by quest type |
| `/rql faction alliance` | Filter by faction |
| `/rql source turtle` | Show only Turtle-exclusive quests |
| `/rql quest <id>` | Jump straight to a specific quest by ID |
| `/rql items <text>` | Open item browser and search |
| `/rql item <id>` | Jump straight to a specific item by ID |
| `/rql reset` | Clear all filters |

Aliases: `/questbrowser`, `/rqib`, `/questitembrowser` all work identically to `/rql`.

---

## 📥 Installation

1. Download or clone this repository.
2. Copy the `RelationshipsQuestAndItemBrowser` folder into your WoW install:
   ```
   Interface\AddOns\RelationshipsQuestAndItemBrowser\
   ```
3. Launch WoW. At the character select screen click **AddOns** and make sure **Relationships Quest And Item Browser** is enabled.
4. Log in. You'll see a green welcome line in chat confirming it has loaded.
5. Type `/rql` to open the browser, or wait for the next quest/item link and click the green **[+]**.

---

## 🙏 Credits

- Quest and NPC data adapted from [**pfQuest**] and **pfQuest-turtle** by shagu & contributors.
- Built for the OctoWoW communities.
