# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SP_Revenge is a World of Warcraft 1.12 (Vanilla) addon for Warriors that displays an alert and countdown timer when the Revenge ability becomes available after blocking, dodging, or parrying an attack.

## Architecture

This is a standard WoW 1.12 addon using the legacy API:

- **SP_Revenge.toc** - Addon manifest (Interface 11200 = WoW 1.12)
- **SP_Revenge.xml** - UI frame definitions and event bindings
- **SP_Revenge.lua** - All addon logic

### Key Components

**Frame Structure (XML):**
- `SP_R_Frame` - Main container frame (hidden by default)
- `SP_R_FrameShadowTime` - Yellow background bar showing full 4-second window
- `SP_R_FrameTime` - Red foreground bar showing usable time (accounts for Revenge cooldown)
- `SP_R_FrameText` - Countdown text overlay

**Event Flow (Lua):**
1. `SP_R_OnLoad` registers combat events for block/dodge/parry detection
2. `SP_R_OnEvent` parses combat log messages to detect defensive procs and Revenge usage
3. `ResetTimer` triggers the 4-second window, checking Revenge's cooldown state
4. `SP_R_OnUpdate` decrements timer and updates display each frame

**Note:** This addon is designed for Turtle WoW, where Revenge has a 4-second proc window (vs 5 seconds in standard 1.12).

**Revenge Proc Detection:**
- `CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES` - creature attacks you dodge/parry
- `CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES` - player attacks you dodge/parry
- `CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS` - creature attacks you block (blocks still "hit")
- `CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS` - player attacks you block
- Patterns matched: "You dodge", "You parry", "blocked"

**Settings:**
- Stored in `SP_R_GS` (SavedVariables)
- Configurable via `/rev` or `/revenge` slash commands
- Options: position (x,y), dimensions (w,h), border (b), alpha (a), scale (s), sound

## WoW 1.12 API Notes

- Uses implicit `this`, `event`, `arg1` globals (not passed as function parameters)
- `getglobal()` for frame references by name
- `GetSpellName()`/`GetSpellCooldown()` with `BOOKTYPE_SPELL`
- Combat detection via string pattern matching on `CHAT_MSG_*` events
