# OctoPad - development

This folder is the source of the OctoPad add-on (`OctoPad/`), the tools that build it, and offline tests.
It is a git repository: `git log` shows every change, and any version can be restored with `git checkout`.

## Layout

| Path | What |
|---|---|
| `OctoPad/OctoPad.lua` | Core: settings, migrations, profiles, styles, bindings, slash commands |
| `OctoPad/OctoPadHUD.lua` | The on-screen crosses, radial menu |
| `OctoPad/OctoPadUI.lua` | Window navigation engine (focus ring, D-pad movement, clicks) |
| `OctoPad/OctoPadAdapters.lua` | **Everything window-specific**: most likely buttons, D-pad filters, what follows a pick |
| `OctoPad/OctoPadSpells.lua` | Known helpful / harmful spells for smart target |
| `OctoPad/OctoPadWorld.lua` | Soft target, smart target, hint bar, auto deselect |
| `OctoPad/OctoPadMenu.lua` | Settings window (pages use the `Stack` layout helper) |
| `OctoPad/OctoPadIcons.lua` | Icon picker |
| `OctoPad/OctoPadProbe.lua` | `/opad probe`: what the client allows |
| `OctoPad/Glyphs`, `OctoPad/Icons` | Generated textures (see tools) |
| `tools/` | Texture generators and `build.py` |
| `tests/run.lua` | Offline logic tests against a stub WoW API |

## Build

```
python3 tools/build.py                # structural checks + OctoPad.zip in this folder
python3 tools/build.py --icons        # regenerate Glyphs/ and Icons/ (needs Pillow)
python3 tools/build.py --bump minor   # bump the version in OctoPad.lua and the .toc
```

The checks count blocks against `end`s per file, warn about Lua 5.1-only syntax (`#`, `string.match`), and run
`xmllint` on Bindings.xml. They are not a Lua parser: run the tests and try it in game.

## Tests

```
lua tests/run.lua                     # Lua 5.1 or newer
```

Covers settings migrations, Jump / Interact defaults per controller style, adapter matching and the spell list.

## Common changes

- **A window's focus is wrong** -> add or edit its entry in `OctoPadAdapters.lua` (fields are documented at the top).
- **Smart target picks the wrong target for a spell** -> add the spell to `OctoPadSpells.lua`.
- **A saved setting changes shape or meaning** -> append a function to `OP.MIGRATIONS` in `OctoPad.lua`
  (never edit or reorder the existing ones).
- **A new settings row** -> use the page's `Stack` (`L:Check`, `L:Pair`, `L:Label`, `L:Button`, `L:Slider`).
- **Something might be blocked on this client** -> check `/opad probe test` first.

The add-on targets the 1.12 client's Lua 5.0: no `#`, no `string.match` / `gmatch`, use `table.getn`,
`string.find` captures and `math.mod`.
