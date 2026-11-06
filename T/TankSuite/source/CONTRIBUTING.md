# Contributing to TankSuite

## Reporting a bug

Open an issue with the bug report template and include:

- the server and client build you play on
- your SuperWoW version and any nameplate addon (pfUI, ShaguPlates…)
- the exact Lua error text shown in chat, if any
- steps to reproduce

## Code rules

The addon runs on the **Lua 5.0** interpreter of the 1.12 client. Code that is valid in modern Lua can break it:

- no `#` length operator: use `table.getn(t)`
- no `%` modulo operator: use `math.mod(a, b)`
- no `string.match`, `string.gmatch` or `select`: use `string.find` and `string.gfind`
- no `...` varargs: use `arg` or explicit parameters
- a function may hold at most 32 upvalues
- optional APIs go through `getglobal("Name")`, never a bare global
- wrap event handlers in `TS.Safe` so one error cannot break the addon

Other rules:

- Keep every user-visible string in `Locale.lua`, in both `en` and `fr`.
- The 1.12 client reads strings as **UTF-8**. Write accented characters as UTF-8 decimal escapes (`é` = `\195\169`, `ç` = `\195\167`), not as Latin-1 escapes such as `\233`: those are invalid UTF-8 and the client drops them along with the letters after them.
- Add any new setting to `TS.defaults` in `Core.lua`. Do not write into `TankSuiteDB` without a default.
- Keep the version in `TankSuite.toc` and `Core.lua` (`TS.version`) identical. CI checks this.

## Pull requests

1. Fork the repository and create a branch from `main`.
2. Keep each pull request focused on one change.
3. Describe what you tested in game.
4. Update `CHANGELOG.md` under `Unreleased`.

## Releases

Maintainers release by pushing a tag `vX.Y.Z` that matches the version in `TankSuite.toc`. The release workflow builds `TankSuite-X.Y.Z.zip` and publishes it.
