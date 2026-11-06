# Auto Spell Rank

Automatically updates action bar spells to their highest learned rank.

## Overview

When you learn a new spell rank, this feature automatically:
1. Scans your action bars for the older rank
2. Replaces it with the highest rank from your spellbook
3. Notifies you of the update

No more manually dragging new spell ranks to your bars!

## How It Works

### Automatic Updates
- Triggers when you learn a new spell (`LEARNED_SPELL_IN_TAB` event)
- Also runs on login to catch any missed updates
- Only updates spells that have ranks (ignores items, macros, etc.)

### Detection
The addon:
1. Reads the tooltip of each action bar slot
2. Identifies spells with ranks (e.g., "Fireball (Rank 4)")
3. Searches your spellbook for higher ranks
4. Replaces outdated spells automatically

## Configuration

| Setting | Description | Default |
|---------|-------------|---------|
| Auto-update spells | Enable automatic rank updates | On |

Find this setting in the "Action Bars" section of config (`/ce`).

## Slash Commands

| Command | Description |
|---------|-------------|
| `/cerank` | Show available commands |
| `/cerank debug` | Scan and display all spells on action bars |
| `/cerank update` | Manually update all spells to highest rank |

## Debug Output

Using `/cerank debug` shows:
```
Slot 1: Fireball (Rank 3) OUTDATED -> Rank 5
Slot 2: Frostbolt (Rank 4) OK
Slot 3: Ice Block (no rank)
...
```

- **OUTDATED** (red): Higher rank available
- **OK** (green): Already at highest rank
- **(no rank)**: Spell doesn't have ranks, or is an item/macro

## Manual Update Button

In the Action Bars config section, click **"Update Ranks Now"** to:
- Immediately scan all action bars
- Update any outdated spells
- See results in chat

## What Gets Updated

✅ **Updated:**
- Spells with ranks (Rank 1, Rank 2, etc.)
- All 120 action bar slots (main + bonus bars)

❌ **Not Updated:**
- Items
- Macros
- Spells without ranks (passive abilities, etc.)
- Pet abilities (only player spellbook is scanned)

## Notifications

When spells are updated, you'll see:
```
[CE AutoRank] Updated Fireball from Rank 3 to Rank 5 (slot 1)
[CE AutoRank] Updated 2 spell(s) to highest rank.
```

## Tips

- Works great when leveling and learning new ranks frequently
- Run `/cerank debug` to verify your bars are up to date
- Disable if you intentionally use lower rank spells (downranking)
- Safe to use - only replaces exact spell matches
