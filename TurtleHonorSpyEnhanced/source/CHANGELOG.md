# Changelog

## v2.2

**Features:**
- 4-state compact mode: normal, compact, merged, super compact
- Merged mode: consecutive kills/bonus/quests collapsed into summary rows
- `/hs export`: copy-paste window with compact honor/rank data dump
- Daily BG display: icon on day header, name in tooltip, `daily=` in export
- Green scroll-up arrow icon for rank progression entries

**Fixes:**
- Weekly reset issues: decay bar, day-split, negative ticks, expand button
- `GetPVPLastWeekStats` return value order; backfill on every login
- Daily BG cycle: slot 3 cleared (Sunnyglade disabled, future Thorn Gorge)

## v2.1.1

**Features:**
- "Honor per 1%" stat in day and week tooltips
- Decay detection and display in day tooltip
- Chained rank gain calculation: group gains now sum to the day total
- Compact entries button: merges consecutive kills, bonus, and quest turn-ins into summary rows with detailed tooltips

**Fixes:**
- Rank progress filter excluding entries at exactly 0% progress
- Rank progress not attributed to groups due to server update timing

## v2.1

**Features:**
- Honor History window: scrollable log grouped by day, week, and session

**Fixes:**
- Day/week honor amount colors now visually distinct

## v2.0

**Features:**
- Rework for Patch 1.18.1 new PvP system
- New overlay layout with rank progress bar

**Fixes:**
- Removed legacy systems (pool correction, RP curve, bracket optimization)
