# Changelog

## 1.89.1 (19 November 2026)

- Reduce world map countdowns to 9 px.
- Place the northern zeppelin countdowns above their pins for Grom’gol and Kargath in Durotar, and for Undercity at Grom’gol.

## 1.89 (19 November 2026)

- Show OctoBus dock countdowns on 14 boat and zeppelin pins on the Blizzard world map. Use each pin’s physical dock and retain its server filters.
- Display OctoBus estimates and restart marks. Refresh countdowns while the map is open, including when the OctoBus window is hidden.
- Reuse labels when map pins are recycled and allow the OctoBus integration to initialize after Atlas.

## 1.88 (15 November 2026)

- Adopt Hapto’s load-on-demand split. Keep the minimap button, slash commands, and world map markers available at login. Load maps, loot, quests, profession features, and item tooltip hooks on first use.
- Add `/atlascfm status` and `/atlascfm preload`.
- Give searches submitted with Enter or the Search button priority over suggestions while the index builds.
- Fix list removal for the Lua 5.0 index traversal and the stock timer fallback.

## 1.87 fork changes (26 October 2026)

- Add **Show Drop Rate on Tooltips**, enabled by default. Show the recorded rate beside its loot source when available.
- Ship English UI strings and quest data only. Share one English table per localization namespace.
