-- WTBox_Glossary.lua
-- Custom glossary additions, kept separate from WoWTranslate so its updates
-- never overwrite them. Entries are merged into WoWTranslate's glossary
-- tables when WTBox loads.
--
-- Incoming (Chinese -> English):  WTBox_InGlossary["<chinese>"] = "<english>"
-- Outgoing (English -> Chinese):  WTBox_OutGlossary["<english>"] = "<chinese>"
--
-- Outgoing keys match case-sensitively against whole words, so add both
-- capitalizations when in doubt. Keep outgoing entries to unambiguous WoW
-- terms; everyday words would get force-replaced mid-sentence.
--
-- This file is meant to grow over time from mined chat logs (see /wtb log).

WTBox_InGlossary = {}
WTBox_OutGlossary = {}

-- Example seed entries (Arathi Basin callouts; incoming AB terms already
-- exist in WoWTranslate itself):
WTBox_OutGlossary["lumber mill"] = "伐木场"
WTBox_OutGlossary["Lumber Mill"] = "伐木场"
WTBox_OutGlossary["blacksmith"] = "铁匠铺"
WTBox_OutGlossary["Blacksmith"] = "铁匠铺"
WTBox_OutGlossary["stables"] = "马厩"
WTBox_OutGlossary["Stables"] = "马厩"
WTBox_OutGlossary["gold mine"] = "金矿"
WTBox_OutGlossary["Gold Mine"] = "金矿"

local function merge(src, dst)
    if not src or not dst then return 0 end
    local n = 0
    for k, v in pairs(src) do
        dst[k] = v
        n = n + 1
    end
    return n
end

function WTBox_MergeGlossaries()
    local n = 0
    n = n + merge(WTBox_InGlossary, WoWTranslateGlossary)
    n = n + merge(WTBox_OutGlossary, WoWTranslateOutGlossary)
    return n
end
