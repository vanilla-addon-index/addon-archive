# Questline development

Read [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for architecture, behavior, validation, and client limitations. Database formats are in [database/SCHEMA.md](database/SCHEMA.md); party synchronization is in [docs/PARTY_PROTOCOL.md](docs/PARTY_PROTOCOL.md).

- Target English OctoWoW / Vanilla 1.12 and Lua 5.0. Do not introduce modern WoW APIs or Lua syntax without a supported fallback.
- OctoQuestDatabase is the sole source of truth. `database/*.json` is an imported snapshot; `Data/` is generated. Submit data corrections to OctoQuestDatabase; do not add local overrides or fallback databases. Refresh with `npm run import`, then `node tools/build.js`. `database-source.json` pins an exact shared content revision; adopting another revision requires `npm run import -- --update-lock`. The shared checkout is a build dependency only; releases include generated Lua and notices.
- Run `node tests/run.js` for runtime changes. For shared-tooltip changes, also run `node ../ClassicBestiary/tests/run.js` when that sibling addon is available.
- Preserve quest-log headers/selection, native tooltip fading, other addons' tooltip lines, and saved user preferences. Never guess objective matches by their position.
- Keep README.md focused on players, following the short introduction, screenshots, Features, and Commands format. Put implementation notes and test details in the development documentation.
