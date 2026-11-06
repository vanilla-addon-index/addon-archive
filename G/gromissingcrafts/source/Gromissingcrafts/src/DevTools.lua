setfenv(1, Gromissingcrafts)

--[[
Turtle WoW's own trade skill / craft / trainer windows don't expose a
recipe's spell id or required skill level through the client API - the only
reliably scriptable facts are a recipe's exact name, and (trade skill/craft
only) its resulting item id. "/gmc dump" walks whichever of those three
windows is open and prints what it can, so gaps in lib/LibCrafts-1.0
(Survival's especially) can be filled in with precise lookups instead of
fuzzy name searches. The trainer window is the most complete source - it
lists every recipe the trainer offers whether you've learned it or not -
but only the trade skill/craft windows expose item ids, and only for
recipes you already know.
]]

---@class DevTools
DevTools = {}

---@param itemLink string|nil
---@return number|nil
local function extractItemId(itemLink)
    if itemLink == nil then
        return nil
    end
    local _, _, id = strfind(itemLink, "item:(%d+)")
    return id and tonumber(id) or nil
end

---@param text string
local function printLine(text)
    DEFAULT_CHAT_FRAME:AddMessage(text)
end

---@return boolean
local function dumpTradeSkillFrame()
    local name, curRank, maxRank = GetTradeSkillLine()
    if name == nil then
        return false
    end

    printLine(format("|cff40bf40Gromissingcrafts|r: dumping '%s' (rank %d/%d)", name, curRank or 0, maxRank or 0))

    for i = 1, GetNumTradeSkills() do
        local skillName, skillType = GetTradeSkillInfo(i)
        if skillType ~= "header" then
            local itemId = extractItemId(GetTradeSkillItemLink(i))
            printLine(format("  [%d] %s -> item %s (%s)", i, skillName or "?", itemId and tostring(itemId) or "?", skillType or "?"))
        end
    end

    printLine("Look each item id up on your realm's database to get the exact spell id and skill level, then add:")
    printLine("  module:NewCraft(spellId, \"Recipe Name\", skillLevel, {SpellSource.Trainer}):SetResult(itemId):Save()")
    return true
end

---@return boolean
local function dumpCraftFrame()
    local name, curRank, maxRank = GetCraftDisplaySkillLine()
    if name == nil then
        return false
    end

    printLine(format("|cff40bf40Gromissingcrafts|r: dumping '%s' (rank %d/%d)", name, curRank or 0, maxRank or 0))

    for i = 1, GetNumCrafts() do
        local skillName, _, skillType = GetCraftInfo(i)
        if skillType ~= "header" then
            local itemId = extractItemId(GetCraftItemLink(i))
            printLine(format("  [%d] %s -> item %s (%s)", i, skillName or "?", itemId and tostring(itemId) or "?", skillType or "?"))
        end
    end
    return true
end

--[[
The trainer window lists every service the trainer offers, known or not -
unlike the trade skill window (which only ever shows recipes you've already
learned). No item link exists for a trainer entry though (you're learning a
spell, not previewing a crafted item), so this only gets names, not ids.
GetTrainerServiceInfo's exact return order isn't confirmed for this client,
so both candidate "type" slots are printed and checked for the header filter.
]]
---@return boolean
local function dumpTrainerFrame()
    local count = GetNumTrainerServices()
    if count == nil then
        return false
    end

    printLine(format("|cff40bf40Gromissingcrafts|r: dumping trainer list (%d services)", count))

    for i = 1, count do
        local serviceName, b, c = GetTrainerServiceInfo(i)
        if b ~= "header" and c ~= "header" then
            printLine(format("  [%d] %s (%s / %s)", i, serviceName or "?", tostring(b), tostring(c)))
        end
    end

    printLine("No item ids here - cross-reference these names against your realm's database, or check the trade skill window (item ids) after learning each one.")
    return true
end

---@param frameName string
local function reportFrame(frameName)
    local frame = getglobal(frameName)
    if frame == nil then
        printLine(format("  %s: does not exist on this client", frameName))
        return
    end
    local ok, visible = pcall(function() return frame:IsVisible() end)
    printLine(format("  %s: exists, IsVisible()=%s", frameName, ok and tostring(visible) or "error calling IsVisible"))
end

--[[
Nothing matched. Rather than guess again blind, report exactly what does and
doesn't exist on this client so the real cause (wrong frame name? visibility
check failing? something else entirely?) can be fixed instead of guessed at.
]]
local function diagnose()
    printLine("|cffff8040Gromissingcrafts|r: no supported window detected. Diagnostics:")
    reportFrame("TradeSkillFrame")
    reportFrame("CraftFrame")
    reportFrame("TrainerFrame")
    reportFrame("ClassTrainerFrame")
    local ok, numServices = pcall(GetNumTrainerServices)
    if not ok then
        printLine("  GetNumTrainerServices() = error calling it")
    else
        printLine(format("  GetNumTrainerServices() = %s", numServices == nil and "nil" or tostring(numServices)))
    end
end

local function dump()
    if getglobal("TradeSkillFrame") ~= nil and TradeSkillFrame:IsVisible() and dumpTradeSkillFrame() then
        return
    end
    if getglobal("CraftFrame") ~= nil and CraftFrame:IsVisible() and dumpCraftFrame() then
        return
    end
    if getglobal("TrainerFrame") ~= nil and TrainerFrame:IsVisible() and dumpTrainerFrame() then
        return
    end
    -- This client names the trainer window ClassTrainerFrame (used for both
    -- class and profession trainers), not the vanilla-standard TrainerFrame -
    -- confirmed via /gmc dump's own diagnostics.
    if getglobal("ClassTrainerFrame") ~= nil and ClassTrainerFrame:IsVisible() and dumpTrainerFrame() then
        return
    end
    diagnose()
end

function DevTools:Create()
    -- Must land in the REAL global table, not this addon's isolated
    -- environment - the client's slash-command dispatcher scans real _G for
    -- SLASH_* variables, and a bare assignment here would only ever set
    -- Gromissingcrafts.SLASH_GROMISSINGCRAFTS1 (writes don't fall through
    -- the environment's __index like reads do).
    setglobal("SLASH_GROMISSINGCRAFTS1", "/gromissingcrafts")
    setglobal("SLASH_GROMISSINGCRAFTS2", "/gmc")
    SlashCmdList["GROMISSINGCRAFTS"] = function(msg)
        local command = strlower(msg or "")
        if command == "dump" then
            dump()
        else
            printLine("|cff40bf40Gromissingcrafts|r: /gmc dump - print recipe names (+ item ids where available) from the open trade skill, craft, or trainer window")
        end
    end
end
