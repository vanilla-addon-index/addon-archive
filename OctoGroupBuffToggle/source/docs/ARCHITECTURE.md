# GroupBuffToggle — code architecture and runtime dataflow

**Audited:** `GroupBuffToggle.lua` (303 lines), `GroupBuffToggle.toc`, Git commits and migration scripts. October 27, 2026; **static review only**.

## Single-module package

```text
GroupBuffToggle.toc
  Interface: 11200 | Version: 1.2.0
  SavedVariables: GroupBuffsDB  (account-wide)
  GroupBuffToggle.lua
     ├─ default party and target frame references
     ├─ 4 party grids of 16 icon buttons
     ├─ 1 target grid of 16 icon buttons
     ├─ group + target Blizzard UICheckButtonTemplate controls
     ├─ event handling / 0.5-second polling
     └─ /groupbuffs command dispatch
```

There is no dependency/library, network synchronization, hidden targeting routine or alternative unit-frame abstraction. The source calls the built-in game's `UnitBuff` and `GameTooltip:SetUnitBuff` APIs.

## Default state and persistence

```text
GroupBuffsDB = {
  enabled = false,          -- party buff icons
  targetEnabled = false,    -- target buff icons
  groupCheckbox = true,     -- party checkbox affordance
  targetCheckbox = true     -- target checkbox affordance
}
```

On `VARIABLES_LOADED`, each key is populated **only if nil**, preserving saved user choices. The source doesn't restore default values on every login. This is an **account-wide** table declared as `SavedVariables`, not per-character. The previous README claimed only two settings, but the post-September-10 source has four.

`BuffsEnabled` and `TargetBuffsEnabled` require strict true; the checkbox-visibility functions require only **not false**, so missing checkbox keys behave as enabled even before initialization.

## Frame creation and placement

**Party:** for members 1–4, `CreateMemberBuffs` finds `PartyMemberFrameN`, then creates one container under `UIParent` anchored `TOPLEFT` to the party frame's `TOPRIGHT` with offset **(8,-4)**. Each container has 16 buttons, `MAX_BUFFS=16`; `ICONS_PER_ROW=8`, `ICON_SIZE=20`, `ICON_GAP=2`. Position of button i is computed using `math.mod(i-1,8)` for the column and `math.floor((i-1)/8)` for the row.

**Target:** one container anchored to `TargetFrame` `TOPRIGHT` at offset **(38,-18)**, also 16 icons in two rows. The target checkbox is positioned beside `TargetFrame` at offset **(4,-38)**. The party checkbox sits below the **highest-index visible, existing** party frame, found scanning member 4 down to 1, offset **(4,-6)** from its bottom-left.

The icons use native textures from `UnitBuff`, cropped via tex coords (0.07..0.93) and a subtle border texture from the game's `UI-Debuff-Overlays` sheet. That **border texture** does not make the displayed auras debuffs: the source only calls **UnitBuff**, not **UnitDebuff**.

## Refresh path and visibility

```text
VARIABLES_LOADED  -> initialize defaults, create checkboxes, UpdateAll
PLAYER_ENTERING_WORLD
PARTY_MEMBERS_CHANGED  ---> UpdateAll()
UNIT_AURA
OnUpdate every 0.5s ----> UpdateAll()

UpdateAll:
  for member in 1..4: UpdateMember(member)
  UpdateCheckboxPosition()
  UpdateTargetBuffs()
```

`UpdateMember` reparents position relative to the live party frame, then hides its container if party overlay disabled, unit doesn't exist, or the frame isn't shown. Otherwise each of the 16 slots calls `UnitBuff("partyN", index)`, sets the icon texture and visible state, and remembers the unit and buff index for hover.

`UpdateTargetBuffs` similarly hides its grid when target buff display disabled, target absent or `TargetFrame` hidden; its checkbox is visible only if `targetCheckbox` and target/frame visibility conditions all hold. It queries `UnitBuff("target", i)` only when enabled with a target.

**Important:** a visible checkbox flag isn't the same thing as enabled overlay. Hiding the checkbox leaves the overlay's independent saved flag unchanged.

If all four party and one target grid are visible, each full refresh can query up to **80 aura slots** (4×16 + 16) in addition to frame/checkbox work. Combined with a twice-per-second poll this is **up to about 160 periodic UnitBuff queries per second**, excluding event-triggered updates. This is a theoretical source-level maximum, **not** a measured performance result.

## Hover and update semantics

Party buttons set `button.unit="partyN"` and `buffIndex=i` when a buff is found; target buttons set their unit/index at frame creation. On hover, `GameTooltip:SetUnitBuff(this.unit,this.buffIndex)` displays the native buff tooltip; on leave it hides the tooltip.

The addon currently displays **only icons**, not remaining duration, stacks, source player, dispellability or buffs beyond the 16th. It has no persistent aura log or personal data collection mechanism.

On each periodic refresh the source adjusts positions and current buff icon visibility, but it doesn't replace default party/target frame internals. Custom unit-frame addons that remove those named frames won't be supported by this code without adaptation.

## Commands

The sole registered slash command is `/groupbuffs`. After trimming/lowercasing, its parser expects two tokens: **control** and **on/off/toggle**.

| Control aliases | Saved key |
| --- | --- |
| `group`, `party` | `enabled` |
| `groupbox`, `groupcheckbox`, `partybox` | `groupCheckbox` |
| `target` | `targetEnabled` |
| `targetbox`, `targetcheckbox` | `targetCheckbox` |

Invalid or empty messages print syntax and current state. Valid commands modify one key, print new state, update visible checkbox checks and call `UpdateAll`.

## Migration, licensing and test limits

September 18 changed old **OctoGroupBuffToggle** identity and root variable **OctoGroupBuffsDB** to **GroupBuffToggle / GroupBuffsDB**. `Upgrade-SavedData.ps1` maps old/new TOC variable names, copies source to backups, rewrites only root assignments in newly created files and refuses overwrites. A separate `tests/test_upgrade.ps1` fixture builds synthetic temporary SavedVariables trees to check Unicode, backups, original retention and refusal behavior.

The repository includes **MIT LICENSE** with Babuni.dev copyright and [v1.2.0 release](https://github.com/babunidev/GroupBuffToggle/releases/tag/v1.2.0) with ZIP/checksum files. Historic release notes **report** syntax/migration verification. Neither game-client validation nor execution of scripts was performed in this review.
