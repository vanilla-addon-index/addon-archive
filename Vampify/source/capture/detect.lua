-- Vampify -- which Vampirism sources the player is wearing.
--
-- Vampirism is not a stat field but a passive item spell (45420-45424 = 1-5%), so it can only be
-- read from the RENDERED tooltip.
--
-- THE TRAP: item-borne and enchant-borne sources use DISJOINT wording --
--   item:    "1% of damage dealt is returned as healing."
--   enchant: "Increase vampirism by 1%."        (Enchant Bracer/Boots - Vampirism, 57146/57148)
-- Matching only the first phrase would silently miss every enchant. A single item can carry both,
-- so never stop at the first match in a slot.

VampifyDetect = {}
local D = VampifyDetect

-- Pure: accessors are injected, so this is WoW-free and offline-testable.
function D.scan(getLink, setTooltip, readLines)
    local out = {}
    for slot = 1, 19 do
        local link = getLink(slot)
        if link then
            setTooltip(link)
            local lines = readLines(slot) or {}
            for i = 1, table.getn(lines) do
                local text = lines[i]
                if text then
                    local low = string.lower(text)
                    local _, _, pct = string.find(low, "(%d+)%%")
                    if pct then
                        if string.find(low, "returned as healing", 1, true) then
                            table.insert(out, { slot = slot, percent = tonumber(pct), kind = "item" })
                        elseif string.find(low, "vampirism", 1, true) then
                            table.insert(out, { slot = slot, percent = tonumber(pct), kind = "enchant" })
                        end
                    end
                end
            end
        end
    end
    return out
end

-- SetHyperlink in 1.12 needs the BARE "item:id:enchant:suffix:unique" form. Handing it the full
-- link (with |cff..|Hitem:..|h[Name]|h|r) fails with "Unknown link type" -- confirmed in-game
-- 2026-08-10, where it failed on all 19 equipped slots at once and the detector therefore reported
-- "no sources" for gear that was plainly equipped. This is a known trap already documented by a
-- companion telemetry addon's instrumentation; this addon reproduced the bug by porting the pure
-- scan but rewriting the wiring. Pure, so the extraction itself is covered by tests.
function D.bareLink(link)
    if type(link) ~= "string" then return nil end
    local _, _, bare = string.find(link, "(item:%d+:%d+:%d+:%d+)")
    if bare then return bare end
    -- Some links carry fewer fields.
    local _, _, loose = string.find(link, "(item:%d+[:%d]*)")
    return loose or link
end

function D.summarise(sources)
    local sum, n = 0, table.getn(sources)
    for i = 1, n do sum = sum + (sources[i].percent or 0) end
    return sum / 100, n
end

-- ---- WoW wiring ------------------------------------------------------------------------------

local sources, epoch, listeners = {}, 0, {}
local tip, pending

local function ensureTip()
    if tip then return tip end
    -- Created ONCE at module scope: frame handles are finite. Owned by WorldFrame rather than
    -- UIParent, which can flash visible on /reload. Never the global GameTooltip -- that fires
    -- every other addon's OnTooltipSetItem hooks 19 times per rescan.
    tip = CreateFrame("GameTooltip", "VampifyScanTooltip", nil, "GameTooltipTemplate")
    tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    return tip
end

local lineBuf = {}
local function readLines()
    -- The tooltip's FontStrings are REUSED, so ClearLines() before each SetHyperlink is what keeps
    -- the previous item's text out of this scan, and NumLines() bounds the read to real lines.
    --
    -- Deliberately NOT filtered on fs:IsVisible(): this tooltip is owned by WorldFrame with
    -- ANCHOR_NONE and is never shown, so its FontStrings report invisible even when their text is
    -- current. Filtering on visibility would silently return zero lines for every item -- the same
    -- silent-zero failure mode as the bare-link bug above. A companion capture addon's proven
    -- detector does not filter either.
    -- Filled DENSELY with table.insert: GetText() returns nil for a blank line, and an indexed
    -- assignment would leave a hole. table.getn on a table with holes is undefined in Lua 5.0, and
    -- D.scan bounds its loop with exactly that -- so a hole could truncate the scan before the
    -- Vampirism line and lose the source silently.
    VampifyConst.resetList(lineBuf)   -- see the comment there: nil-ing indices is not enough in 5.0
    local n = tip:NumLines()
    for i = 1, n do
        local fs = getglobal("VampifyScanTooltipTextLeft"..i)
        local t = fs and fs:GetText()
        if t then table.insert(lineBuf, t) end
    end
    return lineBuf
end

local emptyScan
local retries = 0
local function doScan()
    ensureTip()
    emptyScan = false
    local found = D.scan(
        function(slot) return GetInventoryItemLink("player", slot) end,
        function(link)
            tip:ClearLines()                        -- mandatory, see readLines()
            tip:SetOwner(WorldFrame, "ANCHOR_NONE") -- re-assert in case another addon stole it
            local bare = D.bareLink(link)
            if not bare then emptyScan = true return end
            -- pcall: one unparseable link must not abort the whole 19-slot scan. Without this the
            -- error propagates out of OnUpdate, doScan never reaches its epoch bump, and the addon
            -- sits at zero sources forever while throwing an error every time gear changes.
            if not pcall(function() tip:SetHyperlink(bare) end) then emptyScan = true return end
            -- An uncached item renders nothing; SetHyperlink itself asks the server for it.
            if tip:NumLines() == 0 then emptyScan = true end
        end,
        readLines)
    if emptyScan then
        -- A slot rendered nothing, so this scan cannot distinguish "no Vampirism" from "item not
        -- cached yet" -- waits of ~25 s have been observed. Retry rather than commit a zero.
        --
        -- The condition is emptyScan ALONE, deliberately: what a still-cold slot might be carrying
        -- has nothing to do with what the other slots already yielded. An earlier version also
        -- required `table.getn(found) == 0`, which disarmed the retry the moment ONE source warmed
        -- up -- so a player wearing an item plus a bracer enchant committed the item alone and ran
        -- the rest of the session on a percentage and a per-hit floor that were both too low. That
        -- is invisible from the inside: the rows, the session total and the accumulator all agree
        -- on the understated figure, so no invariant can catch it.
        --
        -- This covers the COLD START too, where `sources` is still empty and committing would leave
        -- the addon dormant for the whole session (5.11) until the next gear change.
        --
        -- Cost of the wider condition: a slot that can NEVER render (an unparseable link hitting the
        -- pcall above) now spends the full retry budget before every commit. Bounded by the cap
        -- below, and the previously committed `sources` stay live throughout -- only a cold start
        -- has nothing to fall back on.
        retries = retries + 1
        if retries <= 40 then return false end     -- ~40 * 0.2 s, then accept reality
    end
    retries = 0
    sources = found
    epoch = epoch + 1
    for i = 1, table.getn(listeners) do listeners[i](sources, epoch) end
    return true
end

function D.getSources() return sources end
function D.getEpoch()   return epoch end
function D.onChange(fn) table.insert(listeners, fn) end

-- Cheap change detection: UNIT_INVENTORY_CHANGED fires constantly (bags, ammo, durability), so
-- compare the 19 links first and only pay for a tooltip parse on a real change.
local lastLinks = {}
local function linksChanged()
    local changed = false
    for slot = 1, 19 do
        local l = GetInventoryItemLink("player", slot)
        if l ~= lastLinks[slot] then lastLinks[slot] = l; changed = true end
    end
    return changed
end

if CreateFrame then
    local f = CreateFrame("Frame", "VampifyDetectFrame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("UNIT_INVENTORY_CHANGED")
    f:SetScript("OnEvent", function()
        if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then return end
        if not linksChanged() and event ~= "PLAYER_ENTERING_WORLD" then return end
        pending = 0   -- coalesce bursts: parse on the next OnUpdate, not once per event
    end)
    f:SetScript("OnUpdate", function()
        if not pending then return end
        pending = pending + arg1
        if pending < 0.2 then return end
        pending = nil
        if not doScan() then pending = 0 end   -- uncached tooltip: try again shortly
    end)
end
