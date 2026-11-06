# TurtleCalendar
**Version:** 1.4.4  
**Game Version:** Turtle WoW & Capybara Paradise (Interface 11200 / Lua 5.0)

Shows you a clean, balanced in-game calendar with all relevant reset timers:
* **Raid lockouts** for all your characters (Raid 40, Onyxia, Karazhan, Zul'Gurub, Timbermaw Hold, Zul'Gurub Edge of Madness)
* **World Boss lockout tracking** with 7-day rolling timers and silent group synchronization
* **Battleground of the day** (Arathi Basin, Warsong Gulch, Alterac Valley, Blood Ring Arena, Thorn Gorge)
* **Darkmoon Faire location** and upcoming schedule (Thunder Bluff & Elwynn Forest / Goldshire)
* **Dungeon/Instance lockout timers**
* **World buffs timers** (Onyxia / Nefarian head drops, Rend Blackhand, Heart of Hakkar)

Use `/turtlecalendar` or `/tc` to toggle the calendar, or assign a hotkey in Key Bindings.

Right-click the calendar background or header to adjust options:
* Toggle visibility of individual raid boxes, world bosses, or battleground/DMF cards.
* Toggle condensed timers.
* Toggle date display.

---

## 🐲 World Boss Lockout Tracking

TurtleCalendar includes client-side tracking and group synchronization for outdoor World Bosses on Turtle WoW and Capybara Paradise realms:

### How It Works
1. **Hybrid Lockout Resolver**: Checks server-side instance saves (`GetSavedInstanceInfo`) first. If the server does not report outdoor world bosses in the instance list, it automatically falls back to client-side combat log detection.
2. **7-Day Rolling Lockout**: When a boss dies, TurtleCalendar records the timestamp and applies Turtle WoW's 7-day reuse cooldown (`604,800` seconds).
3. **Unique Group Kill-ID (`AZUR-XXXXXX`)**: When your group kills a boss, the addon generates a unique Kill-ID and silently broadcasts it across the hidden addon channel (`CHAT_MSG_ADDON`) so everyone in your party/raid receives the identical Kill-ID and timestamp.
4. **Graveyard / Disconnect Protection**: If you died and released to the graveyard or were briefly out of combat log range when the boss died, receiving the kill sync packet from a party member within 60 seconds automatically records your lockout.
5. **Anti-False-Positive Filter**: Defensively ignores boss adds, shades, images, and minions (e.g. *Shade of Taerar* will never accidentally trigger Taerar's lockout).
6. **Cross-Character Alt Tracker**: Hovering over any boss row in the calendar displays whether any of your other characters on the realm are currently locked.

### Tracked World Bosses (11 Bosses)
* **Vanilla World Bosses**: Azuregos (*Azshara*), Lord Kazzak (*Blasted Lands*)
* **Dragons of Nightmare**: Emeriss, Lethon, Taerar, Ysondre (*Duskwood, Hinterlands, Feralas, Ashenvale*)
* **Custom Turtle WoW Bosses**: Nerubian Overseer, Dark Reaver of Karazhan (*Deadwind Pass*), Ostarius, Concavius, Cow King

---

## 🧰 Slash Commands

### General Commands
* `/tc` or `/turtlecalendar` — Toggle the calendar window.
* `/tc help` — Show all general slash commands.
* `/tc reset` — Manually reset current instance timer.
* `/tc minimap` — Toggle the minimap button.
* `/tc dateformat [format]` — Set custom date format (default: `%d.%m.%Y`).

### World Boss Commands (`/tc wb`)
* `/tc wb` or `/tc wb status` — Print your character's current world boss lockouts in chat (including alts).
* `/tc wb share` — Announce your locked world bosses to `/say` (or party/raid chat).
* `/tc wb share guild` — Announce your world boss lockouts to `/guild` chat.
* `/tc wb who` — Query party/raid members to check who shares your exact Kill-ID.
* `/tc wb kill <boss> [days_ago]` — Manually record a boss kill (e.g. `/tc wb kill reaver` or `/tc wb kill reaver 2` for a kill 2 days ago).
* `/tc wb clear <boss>` — Clear a specific boss lockout (e.g. `/tc wb clear reaver`).
* `/tc wb log` — List recorded kill timestamps and unique group IDs.
* `/tc wb track` — Toggle combat death detection on/off.
* `/tc wb reset` — Clear all world boss lockout data for your current character.
* `/tc wb test` — *(Testing)* Populate test kills to verify UI and sync.
* `/tc wb debug` — Dump raw stored world boss tables to chat.

---

## 📦 Installation

> [!IMPORTANT]
> **Folder Name Requirement:**
> The addon directory inside `Interface\AddOns\` **MUST** be named exactly `TurtleCalendar`.
> If you downloaded a ZIP from GitHub, it may extract as `TurtleCalendar-main`. You **must rename** the folder to `TurtleCalendar`, otherwise World of Warcraft will not recognize or load the addon.

1. Download or clone the addon.
2. Place the folder into your `World of Warcraft\Interface\AddOns\` directory.
3. Verify the folder name is `TurtleCalendar`.
4. Launch/restart WoW and ensure `TurtleCalendar` is checked in the AddOns menu at character select.

---

## 🙏 Credits & Attribution

* **Original Creator:** [sica42](https://github.com/sica42/TurtleCalendar) — Created the original TurtleCalendar addon for Turtle WoW.
* **Capybara Paradise Support:** Adapted by Melchz with 2026 raid reset anchors for Eversong Wilds, Basin of Stars, and Gehennas.
* **Chinese Localization:** Community contributions for font and translation fixes.

---

## 📄 License

MIT License — do what you want with it. Credits appreciated but not required.

## 中文版本

TurtleCalendar(乌龟日历)插件适用于经典魔兽Vanilla(1.12)版本的插件。

本仓库主要是对源仓库中的中文本地化不生效的问题进行了修复，未做其他更改。

> 注意：部分翻译调整基于个人的游戏化和理解习惯，不一定适应所有人的语言习惯。由爱好者贡献，仅用于个人学习交流，请勿用于商业用途。

# 乌龟日历

**版本:** 0.10

显示游戏内所有相关计时器的日历：
- 团队副本锁定时间
- 世界首领(World Bosses)锁定计时与队伍同步 (7天滚动CD，支持小队/团队自动同步)
- 每日战场
- 暗月马戏团地点
- 副本计时器
- 世界BUFF计时器

其他内容请看上面的英文（感觉没太大必要翻译，懒得弄~）

修改内容：

**0.10**

- 修复原作者的多语言机制根本不会生效的问题
- 修复中文的字体没带导致文字不会显示的问题
- 修复部分文本没有翻译的问题
- 修复一些文本机翻不对的翻译
- 增加标题的本地化
- 增加默认的中文地区的时间格式
