# TurtleCalendar — Project Status & Handoff Document

> **Last Updated:** 2026-11-04 18:55 (Antigravity Assistant)  
> **Status:** Production Ready (v1.4.7)  
> **Target Engine:** Turtle WoW 1.18.1 / Vanilla 1.12.1 Client (Turtle WoW & Capybara Paradise realms)  
> **Active Verification:** `python tools/run_tests.py` → **ALL 5 CHECKS PASS** (Native Lua 5.0.3 syntax compiler, Lua 5.0 AST compliance, AST global leaks, 50 live runtime tests, and WoW AddOn Auditor & Engine Resilience)

---

## 1. Current Architecture
* **Purpose**: In-game calendar showing raid & instance reset timers, world buffs, server events, and world boss lockout tracking for Turtle WoW.
* **Core Components**:
  - `TurtleCalendar.lua`: Calendar grid rendering, reset calculations, character lockout synchronization, box framework.
    - **Layout Grid**: Perfectly symmetrical 2-row layout:
      - **Row 1 (6 single boxes @ 204px + 5px gap = 1249px, height 222px)**: `Raid 40`, `Onyxia`, `Karazhan`, `Zul'Gurub`, `Timbermaw Hold`, `Edge of Madness (Zul'Gurub)`.
      - **Row 2 (2 double boxes @ 413px + 2 single boxes @ 204px = 1249px, height 184px)**: `Battleground` (under Raid 40 + Onyxia), `Darkmoon Faire` (under Karazhan + ZG), `Instances` (under Timbermaw Hold), and `World Bosses` (directly under Zul'Gurub Edge of Madness).
  - `WorldBosses.lua`: Hybrid world boss lockout tracking (server-side `GetSavedInstanceInfo` prioritization with 7-day client kill tracking fallback, group kill-ID minting and non-blocking sync).
  - `WorldBuffs.lua`: Tracking timers and countdowns for Onyxia / Nefarian head drops, Rend buff, and Hakkar heart.
  - `MinimapIcon.lua`: Minimap button integration with tooltip preview of upcoming resets.
  - `translations/`: Localization tables for English, Spanish, Traditional & Simplified Chinese.
  - `tools/`: Automated verification suite (`python tools/run_tests.py`, `tools/test_world_bosses.lua`).
* **Slash Command**: `/turtlecalendar` or `/tc` toggles the calendar interface; `/tc wb` manages world boss tracking.

---

## 2. Invariant Rules (DO NOT TOUCH)
1. **Timezone & Reset Calculations**:
   - Turtle WoW resets occur on server time (CET/CEST). Do not hardcode local client timezone offsets; use `GetServerTime()` or delta comparisons.
2. **Non-Blocking Calendar Math**:
   - Day and lockout matrix generation must execute lazily when the calendar window is opened, never inside the background `OnUpdate` loop.
3. **SavedVariables Integrity**:
   - Multicharacter lockout data (`TurtleCalendarDB` / `TurtleCalendarGlobalOptions`) must be defensively read; if corrupt or empty, reset gracefully without throwing errors on load.
4. **Lua 5.0 Closure Upvalues**:
   - Never exceed 32 upvalues in any closure. Internal state must be grouped in module tables (`D`).

---

## 3. Active Backlog & Next Steps
- [x] Tested and verified on Turtle WoW 1.18.1 & Capybara Paradise.
- [x] Full world boss UI box wired into calendar window with dynamic dropdown toggle and hover tooltip.
- [x] Symmetrical 2-row layout: `World Bosses` sits directly under Zul'Gurub Edge of Madness (`eom`), with height 184px matching Row 2.
- [x] Group sync via `CHAT_MSG_ADDON` with zero broadcast storm cascades ($O(N)$ traffic).
- [x] Live runtime verification suite passing 46/46 tests on native Lua 5.0.3 VM.
- [x] Integrated WoW Addon Auditor & Engine Resilience gate (`audit_addon.py`) verifying 0 criticals/warnings.
- [x] Real-time clock auto-calibration via `GetSavedInstanceInfo`, `m.db.use_server_time` server timezone toggle, dynamic weekly reset calculation, and guarded Kalimdor skybox offset.
- [x] Epistemically grounded Edge of Madness (EOM) boss rotation and timers against multi-week Chronicle combat telemetry: 12-day interval (exactly 4 Zul'Gurub 3-day lockouts) anchored to `2026-10-23 04:00 UTC` with server-specific boss progression: Gri'lek -> Wushoolay -> Hazza'rah -> Renataki. Verified retroactively against Oct 6 Hazza'rah kill, Oct 26 Gri'lek kill, and live Nov 4 Wushoolay rollover (Next reset: Monday, Nov 16, 2026 at 04:00 UTC).
