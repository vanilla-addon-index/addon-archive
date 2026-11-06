# Questie-Octo 1.0.57 Zone Level Range Audit

Date: 2026-08-21

## Sources and authority

- Current user-supplied `DBFilesClient.zip`: authoritative current Octo client AreaTable / WorldMapArea identity and faction ownership.
- Current user-supplied `BlizzardInterfaceCode` extraction: authoritative native World Map hover behavior.
- User-supplied LevelRange-Turtle 2.2.0 and LevelRange-Octo 2.0.4: behavior/range references.
- Current Turtle release/source material remains preferred for post-reference zone level ranges such as Moonwhisper Coast.

## Coverage

Questie-Octo has level ranges for 53 outdoor leveling zones. Every one of those AreaTable IDs has a valid current WorldMapArea entry.

The remaining map 0/1 WorldMapArea contexts that are not assigned leveling ranges are not missing leveling zones. They are special/helper contexts: GM Island, The Deadmines entrance, Wailing Caverns entrance, Maraudon entrance, Gnomeregan entrance, Blackrock Mountain, Scarlet Monastery entrance, Uldaman entrance, Gates of Ahn'Qiraj, Caverns of Time, Dire Maul entrance, Timbermaw Tunnels, Timbermaw Hold entrance, and Windhorn Canyon entrance/Windhorn Caverns.

No additional normal 1.18.1 leveling zone is missing from the integrated table.

## Westfall regression in 1.0.56

Westfall was present in the table at AreaTable ID 40 with range 10-20, but the current client contains two AreaTable records whose localized display name is exactly `Westfall`: IDs 40 and 206.

Questie-Octo 1.0.56 deliberately made its client name index duplicate-safe. Because the hover resolver only had the display name at that point, `Westfall` became ambiguous and the tooltip was hidden instead of guessing. This is why other zones worked while Westfall did not.

The native World Map does provide an unambiguous identity: Blizzard's `WorldMapButton_OnUpdate` calls `UpdateMapHighlight`, which sets the exact highlight texture. The outdoor Westfall region uses WorldMapArea texture `Westfall`, and ClassicAPI's current WorldMapArea mapping resolves that texture to AreaTable 40.

1.0.57 therefore resolves continent hovers in this order:

1. native WorldMapHighlight texture -> current WorldMapArea/AreaTable ID;
2. capital/subzone alias if applicable;
3. duplicate-safe current-client/package display-name fallback.

This preserves localization support while eliminating the Westfall collision and future-proofs other duplicate display names.

## Faction / diplomacy audit

Current AreaTable faction-group masks were checked for all 53 supported zones:

- `2` = Alliance-owned
- `4` = Horde-owned
- `0` = Contested

This agrees with LevelRange's historical ownership for every overlapping zone. Questie-Octo displays the result relative to the current player, matching LevelRange behavior:

- same faction -> **Friendly** (green)
- opposite faction -> **Hostile** (red)
- faction mask 0 -> **Contested** (brown/gold)

Current custom-zone examples:

| Zone | Levels | Current client ownership | Display |
| --- | ---: | --- | --- |
| Thalassian Highlands | 1-10 | Alliance | Friendly for Alliance / Hostile for Horde |
| Blackstone Island | 1-10 | Horde | Friendly for Horde / Hostile for Alliance |
| Gilneas | 39-46 | Contested | Contested |
| Icepoint Rock | 40-50 | Contested | Contested |
| Gillijim's Isle | 48-53 | Contested | Contested |
| Lapidis Isle | 48-53 | Contested | Contested |
| Moonwhisper Coast | 50-56 | Contested | Contested |
| Tel'Abim | 54-60 | Contested | Contested |
| Scarlet Enclave | 55-60 | Contested | Contested |
| Hyjal | 58-60 | Contested | Contested |
| Northwind | 28-34 | Contested | Contested |
| Balor | 29-34 | Contested | Contested |
| Grim Reaches | 33-38 | Contested | Contested |

## Scope kept intentionally narrow

Questie-Octo keeps one `Show Zone Level Ranges` toggle. When enabled it shows the level range and diplomacy line together. It does not import LevelRange's fishing skill, instance list, raid list, slash commands, SavedVariables, or XML options window.
