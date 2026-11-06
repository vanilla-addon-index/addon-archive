# ShaguDPS 4.6.0

For WoW 1.18.1 clients, Interface 11200, Lua 5.0.

## Dispels

- Added a single Dispels mode. Select it in the mode menu, then reopen the
  menu to choose Done or Received for that window.
- Count successful curse, disease, poison and magic aura removals, including
  offensive dispels. Failed attempts and casts alone do not count.
- Tooltips show removed auras, players involved and dispelling abilities when
  ClassicAPI supplies them. Unknown abilities remain explicitly labelled;
  no spell is guessed from the aura removed.
- Record aggregate counts in Current, Overall and saved boss fights. Old
  fights without recorded data show a missing-data message.
- Recording requires ClassicAPI with combat-log support, independently of
  the chosen damage parser. No full event timeline is stored.

## Newer ClassicAPI support

- Show named damage shields such as Thorns when supplied. Older or ambiguous
  events retain Reflect (School) labels. Damage ownership is unchanged.
- Valid positive event overhealing overrides the health-based approximation.
  A zero remains ambiguous on older builds: it is used directly only after
  this session has observed positive overhealing and the target is visible
  with an absolute maximum health above 100. Other cases use the health
  fallback. ClassicAPI predicts overhealing client-side; it is not server-
  authoritative. Older builds, Nampower and the chat parser remain supported.
- These changes enrich future data; earlier saved breakdowns are not rewritten.

## Display and threat

- Matching windows share sorted display data; unchanged rows skip repainting.
  Rates using live fight duration still update, while reports, resizing,
  scrolling and settings changes redraw as needed. Threat bypasses paint skips.
- Label server percentages as percentages of the pull threshold, confirmed
  in game at range and in melee. Pull Aggro displays 100%; its raw threat
  threshold remains 110% of tank threat in melee or 130% at range.
- Use target GUIDs and switch generations to reject replies associated with
  older outstanding requests. The payload has no target/request ID, so reply
  loss, reordering or other addons can still prevent definitive attribution.
- Regular polling remains at 0.5 seconds, with immediate target-switch requests.

## Updating

Exit WoW, back up the addon and SavedVariables, and replace the ShaguDPS folder
inside Interface/AddOns with the folder in this ZIP. Restart the client.
Existing settings and boss history remain supported. Newer ClassicAPI behavior
requires an installed DLL build that contains the relevant combat-log updates.

## Validation

Lua 5.0 compilation and mocked regression checks cover old/new heal suffixes,
named/unnamed shields and dispels, counter storage, saved fights, display cache
invalidation, column layout, target safeguards and diagnostics. The new named
spell and healing paths still need in-game verification with the newer DLL.
