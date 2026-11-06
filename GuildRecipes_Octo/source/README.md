# GuildRecipes Octo

**Version:** 2.0  
**Author:** sica42 (forked by Glowrot then Olzon)
**Game Version:** OctoWoW (1.12.1)

A standalone replacement for GuildRecipes, built specifically for OctoWoW. Lets guild members share and browse each other's tradeskill recipes in-game, with automatic syncing whenever players come online.

Uses its own saved variables and communication channel — will **not** sync with players running the original GuildRecipes addon. Players still on the old addon will receive a whisper letting them know (if you have that option enabled).

---

## Installation

### Option A — GitAddonsManager (recommended)

GitAddonsManager is a free tool that installs and updates addons directly from GitHub with one click. It's the easiest way to stay up to date.

1. Download GitAddonsManager:
   - **Windows:** https://gitlab.com/woblight/GitAddonsManager/-/jobs/artifacts/master/download?job=Win64
   - **Linux:** https://woblight.gitlab.io/overview/gitaddonsmanager/
2. Open GitAddonsManager and point it at your OctoWoW `Interface\AddOns\` folder if it doesn't detect it automatically.
3. Click **Add addon** and paste in the repository URL:
   ```
   https://octowow.st/git/olzon/GuildRecipes_Octo.git
   ```
4. Click **Download/Update**. GitAddonsManager will clone the addon into your AddOns folder automatically.
5. To update in the future, just open GitAddonsManager and click **Update all**.

### Option B — Manual install

1. Download the latest release as a ZIP from the repository.
2. Extract the `GuildRecipes_Octo` folder into your `Interface\AddOns\` directory, so the path looks like:
   ```
   Interface\AddOns\GuildRecipes_Octo\GuildRecipes_Octo.toc
   ```
3. Launch OctoWoW (or `/reload` if already in-game).

> **Note:** The `assets` folder (fonts and button textures) must be present inside `GuildRecipes_Octo\assets\`. It is included in the repository and will be present if you use GitAddonsManager or download the full ZIP.

---

## Getting started

The addon syncs automatically. When you log in, it requests the latest recipe data from online guild members. When you open a tradeskill or enchanting window, your recipes are shared with the guild.

Open the recipe browser with `/gro toggle` or bind a key under **Key Bindings → GuildRecipes Octo**.

---

## Slash Commands

| Command | Description |
|---|---|
| `/gro` | Show help |
| `/gro toggle` | Toggle the recipe window open/closed |
| `/gro show` / `/gro hide` | Show or hide the recipe window |
| `/gro refresh` | Request updated tradeskills from online guild members |
| `/gro players` | List all players with synced tradeskill data |
| `/gro remove_player <Name>` | Manually remove a player's data |
| `/gro clear` | Clear all synced tradeskill data |
| `/gro versioncheck` | See which version of the addon guild members are running |
| `/gro legacywarning` | Toggle whisper warnings to players on the old addon (default: off) |
| `/gro debug` | Toggle debug output |

---

## Notes

- **Data is per-character.** Each character maintains its own synced database.
- **Syncing is passive.** No manual action is needed — the addon handles it automatically when you log in and open tradeskill windows.
- **Legacy warning** (`/gro legacywarning`) is off by default. When enabled, anyone in the guild still running the original GuildRecipes addon will receive a one-time whisper per session letting them know it has been replaced.
