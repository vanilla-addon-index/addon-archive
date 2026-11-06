# This fork

SimpleActionSets, maintained for the **World of Fiedel** realm (bade.dev) and shipped
through its launcher. Kept as a fork rather than a set of patches because the changes are
behavioural, not cosmetic, and they need to keep working on a Steam Deck.

## Lineage

- `0ldi/SimpleActionSets` — the original.
- `pepopo978/SimpleActionSets` — the fork this one is taken from, at
  `e2486ad2169333c1e69f18815224fb7962269ca0` (2025-12-25, "debounce UNIT_INVENTORY_CHANGED
  and BAG_UPDATE"), which is upstream's newest commit.
- This fork's `upstream-main` branch is pinned at exactly that commit and never moves except
  to follow upstream. **`git diff upstream-main..master` is our entire delta**, permanently.

Neither upstream repo carries a LICENSE, so this is formally all-rights-reserved and is
redistributed on that understanding, unchanged from how the addon already reached players.
Original authorship and copyright remain with the upstream authors; the fork banner above
records the chain.

## Why the changes exist

Action bar contents live on the *server*. One character logged in from two devices — a Steam
Deck on a gamepad UI and a desktop on mouse and keyboard — shares all 120 action slots, so
each device overwrites the other's layout. This addon already had the two halves needed to
fix that (snapshot and restore, plus Turtle's Goblin Brainwashing Device dual-spec hooks);
what it lacked was doing it automatically and without erroring.

The work here, in order:

1. Crash fixes — a load-order race that makes the API hooks index a nil table before
   `VARIABLES_LOADED`, a nil concatenation on the login path, and a gossip hook that could
   swallow clicks on the Brainwashing Device (upstream issue #4).
2. Performance — the spellbook was scanned linearly twice per occupied slot, so applying a
   set cost tens of thousands of `GetSpellName` calls in a single frame.
3. New-install defaults: applying a set applies its empty bars and buttons too (clears them)
   instead of silently skipping them, which is what "empty" meant before.
4. The active set stays in sync with the real bars automatically — dragging a spell onto a
   bar (or off it) updates and saves the set that's currently applied, no manual Save As.
5. **Spec-aware silent login restore**, replacing the old raw-backup "Auto restore actions"
   (whole-layout snapshot, no notion of which set or spec, confirm popup on any mismatch).
   At login this targets a *named* set and, when the character's talents identify one,
   prefers the set for the CURRENT spec over whatever this device merely had active last —
   the fix for logging out on the PC in one spec, respeccing on a Deck, and coming back to
   the PC without the stale spec-1 set silently clearing every spec-2-only spell. Gated on
   the spellbook being populated first: a silent restore has no confirm click to buy time the
   way the popup it replaces did.

Not yet done: the Brainwashing Device's own spec-switch delay (`SetDelayedChange`) is still a
fixed ~1 second wait for the spell burst to land, not the server's own "Specialization
Activated" message. Login restore (item 5) is unrelated to and does not fix this.

Fixes that are not specific to this realm are offered back upstream; each commit message
names the upstream issue or PR it corresponds to.

## Storage is deliberately device-local

`## SavedVariables` (not `PerCharacter`) puts the store in
`WTF/Account/<ACCOUNT>/SavedVariables/SimpleActionSets.lua`, which is **inside the client
install**. The WoF launcher lists `WTF/` under `preserve`, so it is never touched by an
update. That, and only that, is what makes a Deck's bars and a desktop's bars independent.
Do not "improve" this into a shared or server-visible store — the separation is the feature.

## How it ships

Vendored by sha, not by branch, from
`wow_server_development/distribution/addons/sources.toml`, materialised by `addons/sync.py`
into the launcher's addon tree. Moving the pin is a deliberate act with a provenance record.

The offline test harness for this addon lives in that repo, at `distribution/mods/sas/` —
it runs against the vendored bytes rather than a working copy, and it is the gate before
anything is published.
