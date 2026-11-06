# Talent Templates Guide

This document explains how to create and register talent templates for GuideLime Vanilla.

## Table of Contents

- [Overview](#overview)
- [Template Format](#template-format)
- [Tree / Row / Column Reference](#tree--row--column-reference)
- [Registering a Template](#registering-a-template)
- [Templates with Respec](#templates-with-respec)
- [Setting a Default Template](#setting-a-default-template)
- [Finding Talent Positions](#finding-talent-positions)
- [Complete Example](#complete-example)
- [Quick Reference](#quick-reference)

---

## Overview

Talent templates tell the addon which talent to suggest at each level (10-60). When a player levels up, a toast notification shows which talent to pick, and a green highlight appears on the suggested talent in the talent frame.

Templates are registered via the API and can be bundled with guide packs or as standalone addons.

---

## Template Format

Each template is a Lua table mapping **player level** to **talent position**:

```lua
{
    [level] = {tree, row, col},
}
```

| Field | Type | Description |
|-------|------|-------------|
| `level` | number | Player level (10-60). First talent point at level 10. |
| `tree` | number | Talent tree index (1, 2, or 3). See class reference below. |
| `row` | number | Row in the talent tree (1-7). Row 1 is the top. |
| `col` | number | Column position (1-4). Leftmost is 1. |

**Row unlock requirements:**
| Row | Points required in tree |
|-----|------------------------|
| 1 | 0 points |
| 2 | 5 points |
| 3 | 10 points |
| 4 | 15 points |
| 5 | 20 points |
| 6 | 25 points |
| 7 | 30 points |

When the same `{tree, row, col}` appears on consecutive levels, it means adding ranks to the same talent.

---

## Tree / Row / Column Reference

### Class Talent Trees

| Class | Tree 1 | Tree 2 | Tree 3 |
|-------|--------|--------|--------|
| **Warrior** | Arms | Fury | Protection |
| **Paladin** | Holy | Protection | Retribution |
| **Hunter** | Beast Mastery | Marksmanship | Survival |
| **Rogue** | Assassination | Combat | Subtlety |
| **Priest** | Discipline | Holy | Shadow |
| **Shaman** | Elemental | Enhancement | Restoration |
| **Mage** | Arcane | Fire | Frost |
| **Warlock** | Affliction | Demonology | Destruction |
| **Druid** | Balance | Feral | Restoration |

### Reading a Talent Position

Example: `{3, 2, 1}` for a Paladin means:
- Tree **3** = Retribution
- Row **2** = Second row (requires 5 points in Retribution)
- Column **1** = Leftmost talent in that row

---

## Registering a Template

```lua
GLV:RegisterTalentTemplate(class, name, templateType, talents)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `class` | string | Uppercase class name: `"WARRIOR"`, `"PALADIN"`, etc. |
| `name` | string | Display name shown in the settings dropdown |
| `templateType` | string | `"leveling"` or `"endgame"` |
| `talents` | table | Level-to-talent mapping `{[level] = {tree, row, col}}` |

### Basic Example

```lua
local GLV = LibStub("GuidelimeVanilla")
if not GLV then return end

GLV:RegisterTalentTemplate("MAGE", "Frost Leveling", "leveling", {
    [10] = {3, 1, 2},   -- Improved Frostbolt 1/5
    [11] = {3, 1, 2},   -- Improved Frostbolt 2/5
    [12] = {3, 1, 2},   -- Improved Frostbolt 3/5
    [13] = {3, 1, 2},   -- Improved Frostbolt 4/5
    [14] = {3, 1, 2},   -- Improved Frostbolt 5/5
    [15] = {3, 2, 1},   -- Elemental Accuracy 1/3
    -- ... continues to level 60
})
```

---

## Templates with Respec

For builds that change spec mid-leveling (e.g., Retribution 10-40 then Crimson Paladin 40-60), use the optional 5th parameter:

```lua
GLV:RegisterTalentTemplate(class, name, templateType, talents, respec)
```

| Field | Type | Description |
|-------|------|-------------|
| `respec.respecAt` | number | Level that triggers the respec notification |
| `respec.message` | string | Custom message shown in the toast (optional) |
| `respec.talents` | table | Phase 2 talent mapping (same format as main talents) |

### How it Works

1. **Levels 10 to respecAt-1**: Uses the main `talents` table (Phase 1)
2. **Level respecAt**: Shows a gold toast notification telling the player to reset talents
3. **Levels respecAt+**: Uses `respec.talents` table (Phase 2)

After a respec, the highlight calculates the correct talent using:
`playerLevel - unspentPoints + 1`

So at level 41 with 32 unspent points (after reset): `41 - 32 + 1 = 10` → shows the level 10 talent from Phase 2.

### Respec Example

```lua
GLV:RegisterTalentTemplate("PALADIN", "10-60 Crimson Paladin", "leveling", {
    -- Phase 1: Retribution (levels 10-40)
    [10] = {3, 1, 3},   -- Benediction 1/5
    [11] = {3, 1, 3},   -- Benediction 2/5
    -- ... (all talents up to level 40)
    [40] = {3, 5, 2},   -- Repentance 1/1
}, {
    respecAt = 41,
    message = "Reset your talents at a class trainer!",
    talents = {
        -- Phase 2: Crimson Templar (levels 10-60, post-respec)
        [10] = {1, 1, 2},   -- Divine Strength 1/5
        [11] = {1, 1, 2},   -- Divine Strength 2/5
        -- ... (complete build from 10 to 60)
        [60] = {3, 7, 2},   -- Crusader Strike 1/1
    }
})
```

### Important Notes

- Phase 2 `talents` must start at level **10** (it's a full rebuild from scratch)
- Phase 2 should cover all levels from 10 to 60
- The respec state persists across `/reload`
- Changing template in settings resets the respec state
- If the default message is fine, you can omit `message` (defaults to "Reset your talents at a class trainer!")

---

## Setting a Default Template

To make your template the default for a class:

```lua
GLV.DefaultTalentTemplates = GLV.DefaultTalentTemplates or {}
GLV.DefaultTalentTemplates["PALADIN"] = "10-60 Crimson Paladin"
```

The name must match exactly the name used in `RegisterTalentTemplate()`.

---

## Finding Talent Positions

### Using TurtleCraft

1. Go to [talents.turtlecraft.gg](https://talents.turtlecraft.gg)
2. Build your spec
3. Count the position: tree (1/2/3), row (top=1), column (left=1)
4. Save the URL in a comment for reference

### Using /glvtalent in-game

With debug mode on:
```
/glvtalent debug
```

Open the talent frame and the addon will log talent positions in chat:
```
[Talents] Found talent 'Improved Frostbolt' at index 3
[Talents] Suggested: Improved Frostbolt in Frost (row 1, col 2)
```

### Tips

- Comment each line with the talent name and rank
- Include a link to the build URL for reference
- Row/column values match what you see visually in the talent frame

---

## Complete Example

A full template file for a guide pack addon:

```lua
-- MyPack/TalentTemplates/Warrior.lua

local GLV = LibStub("GuidelimeVanilla")
if not GLV then return end

-- Arms Leveling Build (levels 10-60)
-- https://talents.turtlecraft.gg/warrior?points=...
GLV:RegisterTalentTemplate("WARRIOR", "Arms Leveling", "leveling", {
    -- Arms tree (tree 1)
    [10] = {1, 1, 2},   -- Deflection 1/5
    [11] = {1, 1, 2},   -- Deflection 2/5
    [12] = {1, 1, 2},   -- Deflection 3/5
    [13] = {1, 1, 2},   -- Deflection 4/5
    [14] = {1, 1, 2},   -- Deflection 5/5

    [15] = {1, 2, 3},   -- Improved Rend 1/3
    [16] = {1, 2, 3},   -- Improved Rend 2/3
    [17] = {1, 2, 3},   -- Improved Rend 3/3

    [18] = {1, 3, 2},   -- Deep Wounds 1/3
    [19] = {1, 3, 2},   -- Deep Wounds 2/3
    [20] = {1, 3, 2},   -- Deep Wounds 3/3

    -- ... continues to level 60
    [60] = {2, 3, 2},   -- Enrage 1/5
})

-- Arms → Fury Respec Build (levels 10-60)
-- Plays Arms until 40, then respecs to Fury
GLV:RegisterTalentTemplate("WARRIOR", "Arms → Fury (Respec 40)", "leveling", {
    -- Phase 1: Arms (levels 10-40)
    [10] = {1, 1, 2},   -- Deflection 1/5
    -- ... Arms talents up to 40
    [40] = {1, 7, 1},   -- Mortal Strike 1/1
}, {
    respecAt = 41,
    message = "Respec to Fury at your class trainer!",
    talents = {
        -- Phase 2: Fury (full rebuild 10-60)
        [10] = {2, 1, 3},   -- Cruelty 1/5
        -- ... Fury build from 10 to 60
        [60] = {1, 3, 2},   -- Deep Wounds 3/3
    }
})
```

---

## Quick Reference

| API | Description |
|-----|-------------|
| `GLV:RegisterTalentTemplate(class, name, type, talents)` | Register a basic template |
| `GLV:RegisterTalentTemplate(class, name, type, talents, respec)` | Register with respec |
| `GLV:GetTalentTemplates(class, filterType)` | Get all templates for a class |
| `GLV:GetTalentTemplateNames(class, filterType)` | Get template names for dropdowns |
| `GLV:GetActiveTemplate(class)` | Get active template name |
| `GLV:GetTemplateTalents(template, class)` | Get correct talents table (resolves respec phase) |

| Setting | Description |
|---------|-------------|
| `{"Talents", "ActiveTemplate", class}` | Selected template name |
| `{"Talents", "RespecDone", class}` | Respec phase tracking (true/nil) |
| `{"Talents", "Enabled"}` | Feature toggle |
| `{"Talents", "ShowPopupOnLevelUp"}` | Toast notification toggle |
| `{"Talents", "HighlightInFrame"}` | Talent frame highlight toggle |
