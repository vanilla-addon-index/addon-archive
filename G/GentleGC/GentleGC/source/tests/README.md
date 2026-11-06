# Tests

Plain Lua 5.0 scripts with stubbed game functions. Run them from the
repository root; the game never loads them.

    tests/run_all.sh            # all tests, uses lua5.0
    tests/run_all.sh lua        # all tests, other interpreter

Single test: `lua5.0 tests/test_stock.lua GentleGC.lua`

| File | Covers |
|------|--------|
| test_stock.lua | stock Lua 5.0 collector |
| test_factor.lua | the client's 1.25x collector rule |
| test_threshold.lua | threshold handling |
| test_combat_auto.lua | automatic collections in combat |
| test_raid.lua | careful mode, other addons' collections, garbage rate |
| test_hitch.lua | freeze detector |
| test_classicapi.lua | ClassicAPI client mod |
| test_weirdperf.lua | weirdperformance.dll collector |
| test_unknown_context.lua | event context shown for unattributed collections and threshold changes |
| test_native_memory.lua | ClassicAPI per-addon memory, companion fallback, client info lines |
| test_wp_minor.lua | weirdperformance minor sweeps vs unknown collections |
| test_memory.lua | per-addon memory (also needs `!!!!GentleGC_Memory/GentleGC_Memory.lua` as the second argument) |
