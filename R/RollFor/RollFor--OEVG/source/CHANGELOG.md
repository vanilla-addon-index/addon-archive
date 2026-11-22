# Changelog

## 4.8.3 · 2026-11-21

### Fixed

- Applied Salahaja's ClassicAPI minimap fix. Button releases trigger one click, and finishing a drag leaves the current window state alone.
- Defaulted missing main-spec +1 counts to zero and included the count in tie-break broadcasts. This fixes comparisons against nil for raiders receiving tie data from older clients.
- Hid and released partially drawn rows when a roll-popup render fails. The original error is still reported.

The minimap and tie-break fixes were documented on 2026-11-01.

### Performance

- Reused the group roster and its case-insensitive name lookup until a roster event invalidates the cache or it expires.
- Limited automatic soft-reserve matching and RollFor version broadcasts from roster events to membership changes. Imports rerun matching, clearing an import resets it, and roster events can refresh the minimap's reservation status once per minute.

## 4.8.2 · 2026-10-27

Inherited from prodigeomix.

- Updated Raidres SR+ v3.2 imports to keep the highest points value when a player reserves the same item more than once.
- Protected soft-reserved rare BoE and BoP items from automatic below-threshold looting.
- Deferred switching to Group Loot until active looting and rolling finish. Removed combat-state tracking that could switch loot modes during wipes, Feign Death, or Vanish.
- Updated the Zul'Gurub and Ahn'Qiraj boss lists, including the AQ40 zone entry.
- Guarded FrameXML methods missing from the Vanilla client and removed an invisible frame that could intercept clicks. [Upstream version commit](https://github.com/prodigeomix/RollFor/commit/d377c67)

## 4.8.1 · 2026-10-25

Inherited from prodigeomix.

- Fixed the loot window closing unexpectedly and hardened automatic transitions back to Group Loot. [Upstream fix](https://github.com/prodigeomix/RollFor/commit/ddd281d)
