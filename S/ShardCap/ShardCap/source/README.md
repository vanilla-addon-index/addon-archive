# ShardCap

[![ClassicAPI](https://img.shields.io/badge/ClassicAPI-Optional-yellow.svg)](https://github.com/brues-code/ClassicAPI)
[![Nampower](https://img.shields.io/badge/Nampower-Optional-yellow.svg)](https://github.com/brues-code/nampower)

Keeps your Soul Shards at a chosen cap, merges partial stacks, and sorts shards and warlock reagents into soul bags. Lightweight and silent by default.

For **WoW 1.12.1 and OctoWoW / TurtleWoW 1.18.1**. Current version: **2.1.1**. Client mods are optional; slash commands work without them.

## What it does

- **Trims to the cap when you leave combat** (or any time your bags change out of combat).
- **Deletes exactly the excess:** supports stacks of 3 on 1.18.1, splitting a stack if needed.
  With 13 shards and a cap of 12, it deletes 1 shard.
- **Merges partial stacks** (e.g. 1 + 2 → 3) so shards use as few slots as possible.
- **Soul bag aware:** deletes shards in normal bags first (backpack first), keeps the ones in your
  soul bag, and moves loose shards into free soul bag slots. Soul bag can be in any bag slot.
- **Warlock reagents in the soul bag (1.18.1):** Demonic Figurines and Infernal
  Stones are moved into free soul bag slots, filling from the end of the bag. Enough slots are always kept
  free to hold your shard cap (e.g. cap 12 at 3 per slot = 4 slots), so reagents never crowd out shards.
  Skipped on servers where shards don't stack. If the server refuses the move anyway, it stops
  after one notice and doesn't retry that session.
- **Cursor and lock checks:** waits while you hold an item on the cursor and skips locked stacks.
  Deletion matches Soul Shards by their exact item ID.
- **Options window** (needs ClassicAPI): Game Menu → AddOn Options → ShardCap, or `/shardcap options`.
- Settings from ShardCap 1.x are migrated automatically.

## Options window

With ClassicAPI installed, ShardCap adds two pages to the AddOn Options window:

- **ShardCap** — live counts (`Soul Shards: 5/12`, reagents, shards and reagents in the bank),
  the cap (slider 0–100, or type any value up to 200 in the box), chat notifications,
  trimming during combat, and a **Trim now** button.
- **Soul Bag** — moving shards into the soul bag, moving Demonic Figurines / Infernal Stones,
  and automatic or manual soul bag selection per bag slot.

Changes apply immediately. **Cancel** (or Escape) restores the settings you had when you opened the
window, and **Defaults** resets the page you are on. Restoring settings does not undo items already deleted or moved.

## Install

Put the `ShardCap` folder (containing `ShardCap.toc`) in `Interface/AddOns/`, replacing the old one.
If you download the repository as an archive, rename the extracted folder to `ShardCap` first —
WoW only loads an addon whose folder name matches its `.toc` file. Disable ShardCapPlus if you have
it — the addon warns you if both are on.

## Commands (`/shardcap` or `/scap`)

| Command | Effect |
|---|---|
| `/shardcap 12` | Set the cap (0–200) |
| `/shardcap` or `/shardcap status` | Show shard and reagent counts, soul bags, and settings |
| `/shardcap delete` | Trim right now, even in combat |
| `/shardcap spam` | Toggle chat notifications |
| `/shardcap sort` | Toggle merging/moving shards into the soul bag |
| `/shardcap combat` | Toggle trimming during combat |
| `/shardcap reagents` | Toggle moving Demonic Figurines / Infernal Stones into the soul bag |
| `/shardcap soulbag auto` or `/shardcap soulbag 1-4` | Auto-detect, or toggle a bag slot as a soul bag (choose a number from 1 to 4) |
| `/shardcap options` | Open the options window (ClassicAPI) |
| `/shardcap reset` | Restore defaults |

## Client mods (optional, auto-detected)

- **[ClassicAPI](https://github.com/brues-code/ClassicAPI)** provides the options window, bank counts,
  locale-independent soul bag detection, cursor-free moves and merges, and batched bag updates.
  Newer builds also reduce garbage during bag scans by reusing an item-info buffer.
- **[Nampower](https://github.com/brues-code/nampower)** provides item IDs and stack counts directly
  when ClassicAPI's container API is unavailable. Without either mod, ShardCap uses the vanilla API.

## Tests

`tests/test.lua` runs the addon against a mock 1.12 client (stacking, soul bags, combat, cursor,
locked items, migration, options window). Run it from the repo root with a Lua 5.0 interpreter: `lua tests/test.lua`.

## Credits

Based on the original [ShardCap](https://github.com/dogmax/ShardCap), with stacking support inspired by
[ShardCapPlus](https://github.com/akzkak/ShardCapPlus) and soul-bag sorting inspired by
[voxan-dev's fork](https://github.com/voxan-dev/ShardCap).
