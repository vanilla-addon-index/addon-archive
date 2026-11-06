# ShaguDPS 4.5.0

For WoW 1.18.1 clients, Interface 11200, Lua 5.0.

## Meter display

- Totals, rates and percentages align in separate columns in every mode.
- DPS, HPS and TPS display as whole numbers: `100K (1000 DPS) [100%]`.
- Compact totals use uppercase K/M; percentages have at most one decimal.
- Optional class icons in Damage, Heal and Threat (enabled by default).
- New Blizzard Retail (Modern) texture, with modern colors for all nine classes.
  Select it under Bar Texture or use `/sdps texture 8`.
- Wider target names and a centered target/Threat title group.

## Threat

- Fixed missing players caused by decimal threat values and percentages.
- Request fresh data immediately on target changes and display replies immediately.
- Regular polling remains at 0.5 seconds; replies may be shared with TWThreat.
- TPS uses a rolling five-second average and resets on threat reductions.
- Clear old bars on target death, combat end, leaving the group, or three seconds
  without a reply. Resume when fresh data arrives.
- Show the 110–130% pull threshold range when your row is absent from the reply.
  The threshold bar marks its upper end; it has no TPS value.
- Refresh threat windows without marking Damage and Heal windows for refresh.

## Fight history

- Prevent duplicate wipe entries from post-fight healing and targeted corpses.
- Use ClassicAPI destination GUIDs to identify boss deaths, retaining chat
  detection for older clients and unresolved GUIDs.
- Existing saved history is retained; old duplicate entries are not removed.

## Diagnostics

- `/sdps threatdebug`: measure requests, replies and changed replies for ten seconds.
- `/sdps perf`: sample addon memory and CPU for ten seconds where supported.
  CPU profiling requires `/console scriptProfile 1` followed by `/reload`.
  After testing, use `/console scriptProfile 0` and `/reload` to disable its overhead.

## Install or update

1. Exit WoW and back up your existing addon and character SavedVariables.
2. Extract the ZIP into `Interface/AddOns`, keeping the folder named `ShaguDPS`.
3. Restart WoW so the new texture file is available.
4. Set class icons and bar texture in `/sdps config` as desired.

ClassicAPI, Nampower and SuperWoW remain optional. The chat combat parser is
available on a plain client. Live threat requires the supported server addon
message API and a grouped player targeting an engaged elite or boss.
New ClassicAPI functionality is detected by API availability.

The retail texture's source attribution and rights notice are included in
`img/bars/BlizzardRetailBar-attribution.txt`.
