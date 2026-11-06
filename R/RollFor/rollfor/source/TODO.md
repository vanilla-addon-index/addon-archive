# TODO

## Finish sharing the test harness

`test/common/` holds what was byte-identical across every harness: `luaunit`,
`mocking`, `gui_helpers` and eleven mocks. The rest is still copied per addon,
and each copy has drifted, so a fix to one is a fix to one.

The harnesses live in `RollFor/test/`, `RollForSoftRes/test/`,
`RollForAutoLoot/test/` and `RollForGargul/test/`. `RollForRaidRes` and
`RollForSoftResIt` borrow `RollForSoftRes`'s.

### `utils.lua` and `IntegrationTestBuilder.lua`

The big one. Each extension forked core's and added its own loading on top
(`RollForSoftRes`'s `load_extension`, for one):

| File | Core | `RollForSoftRes` | `RollForAutoLoot` | `RollForGargul` |
|---|---|---|---|---|
| `utils.lua` | 1370 lines | 1616, 280 differ | 1484, 134 differ | 1489, 139 differ |
| `IntegrationTestBuilder.lua` | 373 lines | 443, 122 differ | 493, 126 differ | -- |

Merging them needs an extension point in core's harness -- a way for an
extension's tests to load its own modules after RollFor's and before
PLAYER_LOGIN, the way the client does -- rather than a copy of the whole file.
Once there is one, the extensions' `utils.lua` shrink to that hook, and the
`RollForX/test/utils` require names can collapse into `test/common/utils`.

### Mocks that differ

Brackets group the copies that are identical to each other:

| Mock | Versions |
|---|---|
| `ChatApi` | 4: every copy differs |
| `LootFrame` | 4: every copy differs |
| `OptionsFrame` | 4: every copy differs |
| `RollingPopup` | 4: every copy differs |
| `FrameBuilder` | 2: [core] [SoftRes, AutoLoot, Gargul] |
| `PopupBuilder` | 2: [core] [SoftRes, AutoLoot, Gargul] |
| `LootList` | 2: [core, SoftRes] [AutoLoot, Gargul] |
| `SoftResSource` | 2: [core] [AutoLoot, Gargul] |
| `SoftResAwardedLootDecorator` | 1: [AutoLoot, Gargul], not in core |

For each: diff the versions, and if one is a superset of the others (as
`gui_helpers` was), move it to `test/common/mocks/`, rewrite the
`"mocks/X"` requires -- including the `mock = "mocks/X"` strings in module
registries -- and run `scripts/test.sh` and `scripts/check.sh`. Where they
genuinely disagree, the disagreement is the thing to resolve first.

### When it is done

Every harness type is defined once, so the per-addon workspaces in
`scripts/check.sh` stop being needed to avoid duplicate warnings (they may still
be worth keeping: each `.luarc.json` is what proves an addon only reaches what
its TOC depends on). Update the Layout and Diagnostics sections of `CLAUDE.md`.

## README

### Soft-Res setup

The steps in `README.md` walk through one site's export, and the screenshots
(`docs/raidres-*.jpg`) don't match the site the text names. Replace them with
the provider extensions: `RollForSoftResIt` for softres.it and `RollForRaidRes`
for raidres.top, each pointing at its own README for the import steps.

### Commands

`README.md` lists the roll and soft-res commands only. Document the rest:
`/rf <item> <seconds>`, `/htr`, `/award`, `/unaward`, `/rfreset announce`,
`/rf versioncheck`, and a bare `/rf` opening the options window.

### GIFs

Recreate the GIFs and screenshots in `docs/` against the current UI.
