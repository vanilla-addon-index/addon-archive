# CLAUDE.md

## Reference
- **Client UI source** (BCC, `2.5.6.68502`), the authority on what an API
  returns: `$HOME/.projects/lua/wow-ui-source.git/classic_anniversary`
- **Other addons**, ModUi among them:
  `$HOME/.projects/lua/wow-2.5.x-addons.git/master`
- **Keys of `_G`:** `api-dumps/WowApiDump_20260822.txt`


## Layout
Each top-level `RollFor*/` directory is one addon: `src/` is exactly what ships
(the `.toc`, `libs/`, and the modules in its own `src/`, so core's are
`RollFor/src/src/*.lua`), `test/` is its tests, and editor config sits beside
the two. `test/common/` is the test harness the addons share.

No folder in the repo is installable as it stands, on purpose: `RollFor/` has no
`.toc` at its top, and `RollFor/src/` has the wrong name. Players get the zip
`scripts/bundle.sh` builds; `scripts/install.sh` mirrors the same into a local
AddOns directory. Don't "fix" this by moving a `.toc` up a level.

## Running the scripts
Every script runs in Docker, one service each in `docker-compose.yaml`, images
in `docker/`:

    docker compose run --rm test
    docker compose run --rm check
    BUNDLE_DIR=<dir> docker compose run --rm bundle
    ADDONS_DIR=<dir> docker compose run --rm install

Require names in tests:

- **Harness modules by addon-qualified name:**
  `require( "RollForSoftRes/test/utils" )`, never `"test/utils"`. A bare name
  depends on which addon's root comes first on `package.path`, and an extension
  puts core's first.
- **Shared ones by `test/common/`:** `"test/common/luaunit"`,
  `"test/common/mocks/Chat"`.
- **Mocks that still differ per addon** as `"mocks/ChatApi"`, found relative to
  the test directory.
- `RollForRaidRes` and `RollForSoftResIt` have no harness of their own; they use
  `RollForSoftRes/test/`.


## Checks: scripts/check.sh
Run it alongside the tests, never instead of them -- they catch disjoint
things. It runs `lua-language-server` at Hint level and lists test cases luaunit
never ran (any case not named `should_*`). Run it after:

- any change to `---@` annotations, including adding one;
- renaming anything -- a rename can quietly shadow another local;
- moving or inserting a function -- a doc block left above the wrong function
  silently transfers its `---@param`/`---@return` to it.

It checks one workspace per addon, plus `test/common/`, never the repo root: the
per-addon harnesses define the same types, and one workspace over all of them
reports each as a duplicate. Each addon's `.luarc.json` names what it can see;
an extension lists `../RollFor/src`, not `../RollFor` whole, which would pull in
core's test harness.

Neither check catches:

- **Duplicate spec-table names across files.** Harmless at run time, since each
  test file runs as its own process, but worth fixing.
- **Anything visual.** Frame layout, dropdowns and options pages need a human in
  the client.


## Developing external extensions
An external extension lives in its own repo and references this one as a git
submodule pinned to a commit. When it needs something RollFor doesn't have yet:

1. Make the change here, with its tests, and commit it.
2. Point the extension's submodule at that commit, fetched straight from the
   local clone; it doesn't have to be pushed yet:

       git -C <submodule> fetch <local rollfor clone> <sha>
       git -C <submodule> checkout <sha>

3. Test the extension against the real RollFor in the submodule. Never stub
   RollFor to stand in for a change the submodule doesn't have: a test that
   fails on the old commit and passes on the new one is the point.
4. Run the extension's tests and checks.
5. Commit the extension's change and the submodule bump together.
6. Push RollFor before the extension. Until then its submodule names a commit a
   fresh clone or CI can't fetch.
