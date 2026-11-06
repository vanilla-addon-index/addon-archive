# Group Buff Toggle

**Creator:** Babuni.dev · **Version:** 1.2.0 · **Game:** World of Warcraft Vanilla 1.12 · **Interface:** 11200 · **License:** [MIT](LICENSE)

**Group Buff Toggle** is a lightweight, Blizzard-style addon that places **up to 16 beneficial aura icons beside each of four default party-member frames** and, independently, **up to 16 beside the default target frame**. Two familiar **Buffs** checkboxes make those overlays easy to switch on or off. The checkboxes can also be independently hidden via slash commands.

**Both buff displays begin switched off**, so installing the addon does not immediately put new buff icons on the screen. Both checkbox-visibility preferences begin on, but a checkbox appears only while its corresponding party or target unit frame is available. The four switches are saved **account-wide**.

The addon *displays buffs only*. It does **not** apply, remove, prioritize, cast, dispel, track remaining durations, show debuffs as a separate list, or automatically choose a target.

## Install and enable

Copy the project folder so that the source and manifest are here:

```text
World of Warcraft/
└── Interface/
    └── AddOns/
        └── GroupBuffToggle/
            ├── GroupBuffToggle.toc
            └── GroupBuffToggle.lua
```

Restart WoW or run `/reload`. Enable **Group Buff Toggle** at character selection. The [published v1.2.0 release](https://github.com/babunidev/GroupBuffToggle/releases/tag/v1.2.0) provides [GroupBuffToggle.zip](https://github.com/babunidev/GroupBuffToggle/releases/download/v1.2.0/GroupBuffToggle.zip) and a SHA256SUMS text file. The release exists; its files were **not downloaded and checksum-verified in this documentation audit**.

The addon has no required external library and no configuration window. It is specifically built for **default Blizzard PartyMemberFrame1–4 and TargetFrame anchors**, not for substitute party/target frames from other UI addons.

## How to use it

With a party, tick **Buffs** below the lowest currently visible party frame to show member buffs in two eight-icon rows beside each displayed party member. Untick it to hide them. Select a target, then tick its separate **Buffs** checkbox to display that unit's buffs. Hover a buff icon for the native **GameTooltip**.

The checkboxes themselves appear only in context: the party control requires a visible, populated party frame; the target control requires a visible target frame with a target. A missing checkbox when solo or without a target does **not** mean the account setting has been lost.

### Four independent controls

| Saved key in `GroupBuffsDB` | Default | Command | Effect |
| --- | --- | --- | --- |
| `enabled` | **false** | `/groupbuffs group on\|off\|toggle` | Show/hide **party buff icons** |
| `groupCheckbox` | **true** | `/groupbuffs groupbox on\|off\|toggle` | Show/hide the **party Buffs checkbox** |
| `targetEnabled` | **false** | `/groupbuffs target on\|off\|toggle` | Show/hide **target buff icons** |
| `targetCheckbox` | **true** | `/groupbuffs targetbox on\|off\|toggle` | Show/hide the **target Buffs checkbox** |

Type `/groupbuffs` alone to see help and the status of all four controls. For example, `/groupbuffs group on` turns on party buffs, while `/groupbuffs groupbox off` hides only their checkbox. **Hiding a checkbox does not disable its buff icons**; slash controls still work.

Aliases accepted by the source: `party` for `group`; `groupcheckbox` or `partybox` for `groupbox`; `targetcheckbox` for `targetbox`. All take `on`, `off`, or `toggle` as a separate second argument. The addon does not register a separate `/targetbuffs` command.

The README previously said “stores only two settings,” but that described the initial display toggles; **current v1.2.0 code actually persists all four settings**. This source-based correction is part of the present documentation review.

## Buff layout and refresh

Each of four party rows and the target row is a **16-icon, two-row (8+8)** grid. Each icon is **20×20 px**, with **2 px** spacing. The party grid sits to the right of its corresponding frame, and the target grid also sits beside the normal target frame. The addon reads `UnitBuff("party1" .. "party4", index)` and `UnitBuff("target", index)` for **indices 1–16**, shows the texture when present, and hides an absent buff button.

It refreshes on `VARIABLES_LOADED`, `PLAYER_ENTERING_WORLD`, `PARTY_MEMBERS_CHANGED`, and `UNIT_AURA`, as well as a simple **0.5-second** periodic refresh. Tooltips use `GameTooltip:SetUnitBuff` with the unit and buff index. The code doesn't store item IDs, party/target names or a permanent buff history.

**Limits:** this is party-plus-target, **not raid-frame integration**; it shows buff textures, **not durations or charge overlays**. Stacks returned by `UnitBuff` are not rendered. A buff can appear or disappear with up to approximately a half-second timer delay in cases not covered by immediate events. Client and addon interoperability weren't independently tested in this audit.

## Upgrade from the old name: Octo Group Buff Toggle

The addon originally used folder/TOC **OctoGroupBuffToggle**, saved variable **OctoGroupBuffsDB** and title **Octo Group Buff Toggle**. The September 18 rename changed the folder/script and root variable. **Simply replacing files is not enough to recover an old SavedVariables file under its former name.**

1. Exit WoW completely and **back up your WTF SavedVariables folders**.
2. Install the new **GroupBuffToggle** folder beside the original **OctoGroupBuffToggle** directory.
3. On Windows/PowerShell, open the new addon folder and run:

```powershell
.\Upgrade-SavedData.ps1 -ClientPath "C:\Games\World of Warcraft" -PreviousAddonName "OctoGroupBuffToggle"
```

The helper reads the actual TOC declarations, finds saved files, copies backups to `AddonUpgradeBackups`, writes renamed copies without replacing any existing target file, and changes **only top-level** variable assignments from the old to new names. It does **not execute saved Lua** and leaves old files intact. Verify the copied settings, then disable the old addon. Do not run this while WoW is open.

On Linux, back up and manually copy the old `WTF/Account/.../SavedVariables/OctoGroupBuffToggle.lua` to the corresponding **GroupBuffToggle.lua**, and change the top-level assignment to **GroupBuffsDB**. Don't alter values inside the table; preserve the original until you verify the settings.

The [migration fixture](tests/test_upgrade.ps1) is present in the repository and simulates saved-data moves, backups, Unicode text and overwrite refusal. It **was not executed in this audit**.

## Compatibility, license and development

The addon uses WoW 1.12-era frame names and old Lua callback conventions. Replacement unit-frame addons may move or remove those frames; their support is not claimed. No Lua/game client tests were performed during this documentation audit.

**License:** The repository includes an explicit **[MIT License](LICENSE)** with `Copyright (c) 2026 Babuni.dev`. Preserve that notice in copies/substantial portions as required by the license. Unlike projects in this audit with no license, this repository has already made its source reuse terms explicit.

Project history: the **September 10, 2026** first upload introduced the two buff displays, and a same-day revision added independent checkbox visibility and four slash controls. **September 18** renamed Octo Group Buff Toggle to Group Buff Toggle and added migration tooling; **October 26** standardized Babuni.dev attribution and created the first documentation scaffold. This review expands those records without changing gameplay.

[Concept](CONCEPT.md) · [Roadmap](ROADMAP.md) · [Changelog](CHANGELOG.md) · [Architecture](docs/ARCHITECTURE.md) · [Interaction design](docs/DESIGN.md) · [Content and data](docs/CONTENT.md) · [Decisions](docs/DECISIONS.md) · [Development journal](docs/DEVLOG.md) · [AI collaboration](docs/AI_COLLABORATION.md) · [AI/developer instructions](AGENTS.md)

**Original idea and creative authority:** Babuni.dev. **Assistant's contribution in this review:** source/history analysis, editorial documentation, Git commit and verification only.
