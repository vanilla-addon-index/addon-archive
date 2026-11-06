-- Search the player's known and currently exposed game content.
-- Nothing in this module scans the full spell database or chooses an item.
-- -- VimFinder is a standalone addon: it needs only the client. Another addon
-- -- (VimWow) may replace the hooks below to fit the finder into its own
-- -- keys, bag and window focus.
-- VimFinder is a standalone addon: it needs only the client and the shared
-- options window (VimWowSettings), where its tab sets its key. Another addon
-- (VimWow) may replace the hooks below to fit the finder into its bag and
-- window focus.
-- VimWowFinder = {}
-- local Finder = VimWowFinder
-- Finder.owner = CreateFrame("Frame", "VimWowFinderOwner", UIParent)
-- Finder.capture = CreateFrame("Frame", "VimWowFinderCapture", UIParent)
-- Finder.toggle = CreateFrame("Button", "VimWowFinderToggle", UIParent)
-- Finder.closeButton = CreateFrame("Button", "VimWowFinderClose", UIParent)
-- Finder.up = CreateFrame("Button", "VimWowFinderUp", UIParent)
-- Finder.down = CreateFrame("Button", "VimWowFinderDown", UIParent)
VimFinder = {}
local Finder = VimFinder
Finder.owner = CreateFrame("Frame", "VimFinderOwner", UIParent)
Finder.capture = CreateFrame("Frame", "VimFinderCapture", UIParent)
Finder.toggle = CreateFrame("Button", "VimFinderToggle", UIParent)
Finder.closeButton = CreateFrame("Button", "VimFinderClose", UIParent)
Finder.up = CreateFrame("Button", "VimFinderUp", UIParent)
Finder.down = CreateFrame("Button", "VimFinderDown", UIParent)
Finder.results = {}
Finder.rows = {}

-- -- The key binding window lists the finder under its own header.
-- BINDING_HEADER_VIMFINDER = "VimFinder"
-- BINDING_NAME_VIMFINDER = "Open the finder"
-- -- Alt+Space opens the finder until the player binds the finder a key of
-- -- their own in the key binding window.
-- The finder's key is set on its tab in VimWow Settings, which names it
-- by this; the game's key binding window does not list it.
-- BINDING_NAME_VIMFINDER = "Open the finder"
-- The finder's key is set on its tab in VimWow Settings. Without
-- ClassicAPI's override bindings that key is a game key binding to the
-- Bindings.xml command, which the key binding window lists too.
BINDING_HEADER_VIMFINDER = "VimFinder"
BINDING_NAME_VIMFINDER = "Open the finder"
local DEFAULT_KEYS = {"ALT-SPACE"}

-- Hooks. Alone, the finder takes its keys unless a key is being set in
-- VimWow Settings, opens the bags and claims no window focus.
function Finder:IsActive()
    -- return true
    return not VimWowBindingsCapturing
end
-- The keys the finder binds itself while closed, as first, second: those
-- set on its tab in VimWow Settings, else Alt+Space.
function Finder:OpenKeys()
    -- if type(GetBindingKey) == "function" and GetBindingKey("VIMFINDER") then
    --     return nil, nil
    -- end
    -- return DEFAULT_KEYS[1], DEFAULT_KEYS[2]
    if VimWowSettings and VimWowSettings.BindingKeys then
        return VimWowSettings:BindingKeys("VimFinder", "VIMFINDER", DEFAULT_KEYS)
    end
    return DEFAULT_KEYS[1], DEFAULT_KEYS[2]
end
-- A choice is about to open a window (now, or once the server answers
-- within the given seconds).
function Finder:ExpectWindow(seconds)
end
-- Opens the bags, before the finder closes. Opening, never toggling, keeps
-- an open bag open.
function Finder:ShowBags()
    if type(OpenBackpack) == "function" then OpenBackpack() end
    if type(OpenBag) == "function" and type(GetContainerNumSlots) == "function" then
        for bag = 1, 4 do
            if (GetContainerNumSlots(bag) or 0) > 0 then OpenBag(bag) end
        end
    end
end
-- After the finder closed on a bag choice: the item's bag and slot, or
-- nothing for Disenchant, whose item the player picks.
function Finder:SelectBagSlot(bag, slot)
end

local function visible(name)
    local frame = getglobal(name)
    return frame and frame:IsVisible()
end

local function inCombat()
    return type(UnitAffectingCombat) == "function"
        and UnitAffectingCombat("player")
end

local function add(list, kind, name, detail, index, book)
    if name and name ~= "" then
        local item = {kind = kind, name = name, detail = detail or kind,
            index = index, book = book}
        table.insert(list, item)
        return item
    end
end

-- local professions = {"Alchemy", "Blacksmithing", "Cooking", "Enchanting",
--     "Engineering", "First Aid", "Leatherworking", "Tailoring"}
-- Fishing casts toward the player's facing and needs no target.
local professions = {"Alchemy", "Blacksmithing", "Cooking", "Enchanting",
    "Engineering", "First Aid", "Fishing", "Leatherworking", "Tailoring"}

-- These spellbook entries are combat controls or require a chosen target.
-- They add noise to a finder intended for inspection and safe utility casts.
local hiddenSpells = {attack = true, shoot = true, attach = true,
    ["auto attack"] = true, ["auto shot"] = true}

-- -- The spell API does not identify target-free casts. Keep this list narrow:
-- -- these summon a companion beside the player, with no unit or ground target.
-- local companionSummons = {["summon imp"] = true,
--     ["summon voidwalker"] = true, ["summon succubus"] = true,
--     ["summon incubus"] = true, ["summon felhunter"] = true,
--     ["summon felguard"] = true}
-- The spell API does not identify target-free casts. Keep this list narrow:
-- these summon a companion or place an object beside the player, with no
-- unit or ground target.
local companionSummons = {["summon imp"] = true,
    ["summon voidwalker"] = true, ["summon succubus"] = true,
    ["summon incubus"] = true, ["summon felhunter"] = true,
    ["summon felguard"] = true, ["basic campfire"] = true}

local function isProfession(name)
    for _, profession in ipairs(professions) do
        if name == profession or name == getglobal(string.upper(
            string.gsub(profession, " ", "_"))) then return true end
    end
end

local function canActivate(item)
    -- if item.kind == "tracking" or item.kind == "trade"
    --     or item.kind == "craft" then return true end
    -- if item.kind == "tracking" or item.kind == "trade"
    --     or item.kind == "craft" or item.kind == "bag" then return true end
    -- if item.kind == "tracking" or item.kind == "trade"
    --     or item.kind == "craft" or item.kind == "bag"
    --     or item.kind == "window" then return true end
    if item.kind == "tracking" or item.kind == "trade"
        or item.kind == "craft" or item.kind == "bag"
        or item.kind == "window" or item.kind == "recipe" then return true end
    if item.kind ~= "spell" then return false end
    if hiddenSpells[string.lower(item.name)] then return false end
    if item.name == "Disenchant" or isProfession(item.name) then return true end
    if type(IsPassiveSpell) == "function"
        and IsPassiveSpell(item.index, "spell") then return false end
    if type(IsHarmfulSpell) == "function"
        and IsHarmfulSpell(item.index, "spell") then return false end
    if companionSummons[string.lower(item.name)] then return true end
    local spellID
    if type(GetSpellInfo) == "function" then
        local _, _, _, _, _, _, _, _, _, id = GetSpellInfo(item.index, "spell")
        spellID = id
    end
    if C_Spell and type(C_Spell.IsSelfBuff) == "function" and spellID
        and C_Spell.IsSelfBuff(spellID) then return true end
    if type(IsHelpfulSpell) == "function"
        and type(IsHarmfulSpell) == "function"
        and IsHelpfulSpell(item.index, "spell") then
        return "self"
    end
    return false
end

-- Every known recipe of the character's professions, their windows open
-- or not (the user, 2026-10-18: derived from the professions the
-- character has, never listed by hand). With ClassicAPI: a profession is a
-- spellbook spell whose skill line (C_SpellBook.GetSpellSkillLine) the
-- character has (GetSkillLineRank) and that has craftable recipes
-- (C_TradeSkillUI.GetTradeSkillListRecipes, the line's full list from the
-- client's data); the recipes known are IsPlayerSpell's. A scan runs at
-- each opening, so a recipe learned since shows at once.
local recipeLines = {}   -- skillID -> {{spellID, createdItem}, ...}, read once
local skillOfSpell = {}  -- spellID -> {skillID, line name} or false, read once
local function recipeAPI()
    return C_SpellBook and type(C_SpellBook.GetSpellSkillLine) == "function"
        and type(C_SpellBook.GetSkillLineRank) == "function"
        and C_TradeSkillUI and type(C_TradeSkillUI.GetTradeSkillListRecipes) == "function"
        and type(GetSpellInfo) == "function" and type(IsPlayerSpell) == "function"
end

local function lineRecipes(skillID)
    if recipeLines[skillID] == nil then
        local recipes = {}
        for _, row in ipairs(C_TradeSkillUI.GetTradeSkillListRecipes(skillID, "") or {}) do
            local spellID = row.spellID or row[1]
            -- if spellID then
            -- A recipe has skill-up levels; a class line's item spells
            -- (Demonology's Create Soulstone) have none, so that line is no
            -- profession and Enter never casts one of its spells to open
            -- it (FD11, 2026-10-24). VimWow's native recipe icons take the
            -- same rows.
            local grey = row.trivialLevel or row[3] or 0
            local green = row.greenLevel or row[4] or 0
            if spellID and (grey > 0 or green > 0) then
                table.insert(recipes, {spellID = spellID, createdItem = row.createdItem or row[5]})
            end
        end
        recipeLines[skillID] = recipes
    end
    return recipeLines[skillID]
end

-- The professions with recipes among the spellbook's spells (list's
-- "spell" entries): {{name, skillID, slot}, ...}, the spell named as its
-- line (Cooking, not Basic Campfire) opening the window.
local function professionLines(list)
    local lines, byID = {}, {}
    if not recipeAPI() then return lines end
    for _, item in ipairs(list) do
        if item.kind == "spell" then
            local _, _, _, _, _, _, _, _, _, spellID = GetSpellInfo(item.index, "spell")
            if spellID and skillOfSpell[spellID] == nil then
                local lineName, skillID = C_SpellBook.GetSpellSkillLine(spellID)
                skillOfSpell[spellID] = skillID and {skillID, lineName} or false
            end
            local skill = spellID and skillOfSpell[spellID]
            if skill and C_SpellBook.GetSkillLineRank(skill[1])
                and table.getn(lineRecipes(skill[1])) > 0 then
                local line = byID[skill[1]]
                if not line then
                    line = {name = skill[2] or item.name, skillID = skill[1], slot = item.index}
                    byID[skill[1]] = line
                    table.insert(lines, line)
                end
                if item.name == skill[2] then line.slot = item.index end
            end
        end
    end
    return lines
end
Finder.ProfessionLines = professionLines

function Finder:Scan()
    local list = {}
    if type(GetNumSpellTabs) == "function" and type(GetSpellTabInfo) == "function"
        and type(GetSpellName) == "function" then
        for tab = 1, GetNumSpellTabs() or 0 do
            local _, _, offset, count = GetSpellTabInfo(tab)
            for slot = (offset or 0) + 1, (offset or 0) + (count or 0) do
                local name, rank = GetSpellName(slot, "spell")
                local detail = "Known spell"
                if rank and rank ~= "" then detail = detail .. " · " .. rank end
                if name and not hiddenSpells[string.lower(name)] then
                    add(list, "spell", name, detail, slot, "spell")
                end
            end
        end
    end
    if type(HasPetSpells) == "function" and type(GetSpellName) == "function" then
        local count = HasPetSpells()
        if type(count) == "number" then
            local book = BOOKTYPE_PET or "pet"
            for slot = 1, count do
                local name, rank = GetSpellName(slot, book)
                local detail = "Known pet spell"
                if rank and rank ~= "" then detail = detail .. " · " .. rank end
                add(list, "petspell", name, detail, slot, book)
            end
        end
    end
    if type(GetNumTrackingTypes) == "function"
        and type(GetTrackingInfo) == "function" then
        for i = 1, GetNumTrackingTypes() or 0 do
            local name, _, active, _, spellID = GetTrackingInfo(i)
            local tracker = add(list, "tracking", name,
                active and "Tracking is on · Enter to turn off"
                    or "Tracking is off · Enter to turn on", i, spellID)
            if tracker then
                tracker.active = active
                for _, spell in ipairs(list) do
                    if spell.kind == "spell" and spell.name == name then
                        tracker.spellSlot = spell.index
                        break
                    end
                end
            end
        end
    end
    if visible("TradeSkillFrame") and type(GetNumTradeSkills) == "function"
        and type(GetTradeSkillInfo) == "function" then
        for i = 1, GetNumTradeSkills() or 0 do
            local name, kind = GetTradeSkillInfo(i)
            if kind ~= "header" then
                add(list, "trade", name, "Profession recipe · Enter to select", i)
            end
        end
    end
    if visible("CraftFrame") and type(GetNumCrafts) == "function"
        and type(GetCraftInfo) == "function" then
        for i = 1, GetNumCrafts() or 0 do
            local name, _, kind = GetCraftInfo(i)
            if kind ~= "header" then
                add(list, "craft", name, "Craft recipe · Enter to select", i)
            end
        end
    end
    -- the known recipes of every profession (above), but those of the
    -- window open, listed already
    local listed = {}
    for _, item in ipairs(list) do
        if item.kind == "trade" or item.kind == "craft" then listed[item.name] = true end
    end
    for _, line in ipairs(professionLines(list)) do
        for _, recipe in ipairs(lineRecipes(line.skillID)) do
            if IsPlayerSpell(recipe.spellID) then
                local name = GetSpellInfo(recipe.spellID)
                if name and not listed[name] then
                    listed[name] = true
                    local item = add(list, "recipe", name, line.name .. " recipe · Enter to open",
                        recipe.spellID, line.slot)
                    if item then item.createdItem = recipe.createdItem end
                end
            end
        end
    end
    if type(GetContainerNumSlots) == "function"
        and type(GetContainerItemLink) == "function" then
        for bag = 0, 4 do
            for slot = 1, GetContainerNumSlots(bag) or 0 do
                local link = GetContainerItemLink(bag, slot)
                -- local name = link and string.match(link, "%[([^%]]+)%]")
                -- Lua 5.0 has no string.match (ClassicAPI adds it).
                local _, _, name = string.find(link or "", "%[([^%]]+)%]")
                -- if name then add(list, "bag", name,
                --     "In bag " .. bag .. ", slot " .. slot, slot, bag) end
                if name then add(list, "bag", name, "In bag " .. bag
                    .. ", slot " .. slot .. " · Enter to show", slot, bag) end
            end
        end
    end
    -- Every window the client's key bindings open, keyed or not: the
    -- toggles under the Interface header of its key binding list, by the
    -- client's own names.
    if type(GetNumBindings) == "function" and type(GetBinding) == "function"
        and type(RunBinding) == "function" then
        local header
        for i = 1, GetNumBindings() or 0 do
            local command = GetBinding(i)
            if command and string.sub(command, 1, 6) == "HEADER" then
                header = command
            elseif command and header == "HEADER_INTERFACE"
                and (string.find(command, "^TOGGLE") or string.find(command, "^OPEN")) then
                add(list, "window", getglobal("BINDING_NAME_" .. command) or command,
                    "Window · Enter to open or close", i, command)
            end
        end
    end
    self.catalog = list
    self:Search()
end

-- A contiguous match ranks ahead of initials/subsequence matches.
local function score(name, query)
    if query == "" then return 0 end
    local lower = string.lower(name)
    local start = string.find(lower, query, 1, true)
    if start then return 100 - start end
    local from, gaps = 1, 0
    for i = 1, string.len(query) do
        local found = string.find(lower, string.sub(query, i, i), from, true)
        if not found then return nil end
        gaps = gaps + found - from
        from = found + 1
    end
    return 20 - gaps
end
-- The bag search highlights slots with the same fuzzy match.
Finder.Score = score

-- Use a content identity rather than a spell slot or bag position, which can
-- change between sessions. Kind keeps similarly named actions separate.
local function usageKey(item)
    return item.kind .. ":" .. item.name
end

-- local function useCount(item)
--     local counts = type(VimWowDB) == "table" and VimWowDB.finderUsage
local function useCount(item)
    local counts = type(VimFinderDB) == "table" and VimFinderDB.usage
    local count = type(counts) == "table" and counts[usageKey(item)]
    return type(count) == "number" and count > 0 and count or 0
end

-- function Finder:RecordUse(item)
--     if type(VimWowDB) ~= "table" then return end
--     if type(VimWowDB.finderUsage) ~= "table" then
--         VimWowDB.finderUsage = {}
--     end
--     local key = usageKey(item)
--     VimWowDB.finderUsage[key] = useCount(item) + 1
-- end
-- How often each choice was used, saved per account in VimFinderDB.
function Finder:RecordUse(item)
    if type(VimFinderDB) ~= "table" then VimFinderDB = {} end
    if type(VimFinderDB.usage) ~= "table" then
        VimFinderDB.usage = {}
    end
    local key = usageKey(item)
    VimFinderDB.usage[key] = useCount(item) + 1
end

function Finder:Search()
    local query = string.lower(self.edit:GetText() or "")
    local matches = {}
    for _, item in ipairs(self.catalog or {}) do
        local rank = score(item.name, query)
        if rank then
            item.usage = useCount(item)
            -- Familiar choices can break close search matches, but cannot
            -- overtake a much better text match.
            item.score = rank + (query ~= "" and math.min(item.usage * 2, 10) or 0)
            table.insert(matches, item)
        end
    end
    table.sort(matches, function(a, b)
        if query == "" and a.usage ~= b.usage then
            return a.usage > b.usage
        end
        if a.score ~= b.score then return a.score > b.score end
        if a.usage ~= b.usage then return a.usage > b.usage end
        if a.name ~= b.name then return a.name < b.name end
        if a.kind ~= b.kind then
            if a.kind == "tracking" then return true end
            if b.kind == "tracking" then return false end
        end
        return a.kind < b.kind
    end)
    self.results = matches
    self.selected = 1
    self:Draw()
end

function Finder:Tooltip(item)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self.frame, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMRIGHT", 12, 0)
    local shown, supported
    if (item.kind == "spell" or item.kind == "petspell")
        and GameTooltip.SetSpell then
        supported = true
        shown = GameTooltip:SetSpell(item.index, item.book)
    elseif item.kind == "tracking" and item.spellSlot
        and GameTooltip.SetSpell then
        supported = true
        shown = GameTooltip:SetSpell(item.spellSlot, "spell")
    elseif item.kind == "tracking" and item.book
        and GameTooltip.SetSpellByID then
        supported = true
        shown = GameTooltip:SetSpellByID(item.book)
    elseif item.kind == "trade" and GameTooltip.SetTradeSkillItem then
        supported = true
        shown = GameTooltip:SetTradeSkillItem(item.index)
    elseif item.kind == "craft" and GameTooltip.SetCraftSpell then
        supported = true
        shown = GameTooltip:SetCraftSpell(item.index)
    elseif item.kind == "bag" and GameTooltip.SetBagItem then
        supported = true
        shown = GameTooltip:SetBagItem(item.book, item.index)
    -- a recipe: the item it makes, else the recipe's spell
    elseif item.kind == "recipe" and item.createdItem and item.createdItem > 0
        and GameTooltip.SetHyperlink then
        supported = true
        shown = GameTooltip:SetHyperlink("item:" .. item.createdItem .. ":0:0:0")
    elseif item.kind == "recipe" and GameTooltip.SetSpellByID then
        supported = true
        shown = GameTooltip:SetSpellByID(item.index)
    end
    if not supported or shown == false then
        if GameTooltip.SetText then GameTooltip:SetText(item.name) end
        if GameTooltip.AddLine then GameTooltip:AddLine(item.detail) end
    end
    GameTooltip:Show()
end

-- The window's layout: the dialog look of the Game Menu and popups.
local WIDTH, HEIGHT = 520, 300
local ROW_LEFT, ROW_TOP, ROW_HEIGHT = 26, 60, 24
local ROW_WIDTH = WIDTH - 2 * ROW_LEFT
local WINDOW_ICON = "Interface\\Icons\\INV_Misc_Book_09"
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Each result's icon, as the client's own windows show it.
local function iconFor(item)
    local texture
    if (item.kind == "spell" or item.kind == "petspell")
        and type(GetSpellTexture) == "function" then
        texture = GetSpellTexture(item.index, item.book)
    elseif item.kind == "tracking" and type(GetTrackingInfo) == "function" then
        local _
        _, texture = GetTrackingInfo(item.index)
    elseif item.kind == "trade" and type(GetTradeSkillIcon) == "function" then
        texture = GetTradeSkillIcon(item.index)
    elseif item.kind == "craft" and type(GetCraftIcon) == "function" then
        texture = GetCraftIcon(item.index)
    elseif item.kind == "bag" and type(GetContainerItemInfo) == "function" then
        texture = GetContainerItemInfo(item.book, item.index)
    elseif item.kind == "window" then
        texture = WINDOW_ICON
    -- elseif item.kind == "recipe" and type(GetSpellInfo) == "function" then
    --     local _
    --     _, _, texture = GetSpellInfo(item.index)
    -- A recipe shows the item it makes, as the profession window does: many
    -- crafting spells have only the client's placeholder face as their own
    -- icon. The spell's icon is kept for a recipe that makes no item
    -- (enchanting) or whose item the client has not cached yet.
    elseif item.kind == "recipe" then
        local _
        if item.createdItem and item.createdItem > 0 and type(GetItemInfo) == "function" then
            _, _, _, _, _, _, _, _, texture = GetItemInfo(item.createdItem)
        end
        if not texture and type(GetSpellInfo) == "function" then
            _, _, texture = GetSpellInfo(item.index)
        end
    end
    return texture or UNKNOWN_ICON
end

-- function Finder:Draw()
--     local count = table.getn(self.results)
--     if self.selected > count then self.selected = count end
--     if self.selected < 1 then self.selected = 1 end
--     local first = math.max(1, self.selected - 5)
--     self.selectionBackground:Hide()
--     for i, row in ipairs(self.rows) do
--         local item = self.results[first + i - 1]
--         if item then
--             row:SetText((first + i - 1 == self.selected and "> " or "  ")
--                 .. item.name .. "  —  " .. item.detail)
--             if canActivate(item) then row:SetTextColor(1, 1, 1)
--             else row:SetTextColor(0.52, 0.52, 0.52) end
--             if first + i - 1 == self.selected then
--                 self.selectionBackground:ClearAllPoints()
--                 self.selectionBackground:SetPoint("TOPLEFT", self.frame,
--                     "TOPLEFT", 13, -40 - i * 23 + 2)
--                 self.selectionBackground:Show()
--             end
--             row:Show()
--         else row:Hide() end
--     end
-- Each row: the result's icon, its name in white (grey when Enter only
-- shows it), and what it is on the right; the gold quest log bar marks the
-- selected one.
function Finder:Draw()
    local count = table.getn(self.results)
    if self.selected > count then self.selected = count end
    if self.selected < 1 then self.selected = 1 end
    local first = math.max(1, self.selected - 5)
    self.selectionBackground:Hide()
    for i, row in ipairs(self.rows) do
        local item = self.results[first + i - 1]
        local detail, icon = self.details[i], self.icons[i]
        if item then
            row:SetText(item.name)
            detail:SetText(item.detail)
            icon:SetTexture(iconFor(item))
            if canActivate(item) then
                row:SetTextColor(1, 1, 1)
                detail:SetTextColor(0.65, 0.65, 0.65)
            else
                -- row:SetTextColor(0.52, 0.52, 0.52)
                -- detail:SetTextColor(0.52, 0.52, 0.52)
                -- A lighter grey, readable under the gold selection bar too.
                row:SetTextColor(0.7, 0.7, 0.7)
                detail:SetTextColor(0.7, 0.7, 0.7)
            end
            if first + i - 1 == self.selected then
                self.selectionBackground:ClearAllPoints()
                self.selectionBackground:SetPoint("TOPLEFT", self.frame,
                    "TOPLEFT", ROW_LEFT - 4, -ROW_TOP - (i - 1) * ROW_HEIGHT)
                self.selectionBackground:Show()
            end
            row:Show(); detail:Show(); icon:Show()
        else row:Hide(); detail:Hide(); icon:Hide() end
    end
    -- self.count:SetText(count .. " results")
    self.count:SetText(count .. (count == 1 and " result" or " results"))
    local selected = self.results[self.selected]
    if selected then self:Tooltip(selected)
    elseif GameTooltip and GameTooltip.IsOwned
        and GameTooltip:IsOwned(self.frame) then GameTooltip:Hide() end
end

function Finder:Move(delta)
    if not self.frame:IsVisible() then return end
    self.selected = math.max(1, math.min(table.getn(self.results),
        (self.selected or 1) + delta))
    self:Draw()
end

local function scrollRecipe(kind, index, total)
    local frameName = kind == "trade" and "TradeSkillListScrollFrame"
        or "CraftListScrollFrame"
    local displayed = kind == "trade" and
        (TRADE_SKILLS_DISPLAYED or 19) or (CRAFTS_DISPLAYED or 8)
    local height = kind == "trade" and
        (TRADE_SKILL_HEIGHT or 16) or (CRAFT_SKILL_HEIGHT or 16)
    local scroll = getglobal(frameName)
    if not scroll or type(FauxScrollFrame_GetOffset) ~= "function"
        or type(FauxScrollFrame_SetOffset) ~= "function" then return end
    local offset = FauxScrollFrame_GetOffset(scroll) or 0
    if index <= offset then offset = index - 1
    elseif index > offset + displayed then offset = index - displayed end
    offset = math.max(0, math.min(total - displayed, offset))
    FauxScrollFrame_SetOffset(scroll, offset)
    local bar = getglobal(frameName .. "ScrollBar")
    if bar then bar:SetValue(offset * height) end
end

-- A recipe chosen from a closed (or another) profession window: its
-- window opens, then the recipe is selected in it, as Enter on an open
-- window's recipe does. True once it is selected.
function Finder:SelectPendingRecipe()
    local pending = self.pendingRecipe
    if not pending then return false end
    if visible("TradeSkillFrame") and type(GetNumTradeSkills) == "function"
        and type(TradeSkillFrame_SetSelection) == "function" then
        for i = 1, GetNumTradeSkills() or 0 do
            local name, kind = GetTradeSkillInfo(i)
            if kind ~= "header" and name == pending.name then
                scrollRecipe("trade", i, GetNumTradeSkills())
                TradeSkillFrame_SetSelection(i)
                if type(TradeSkillFrame_Update) == "function" then TradeSkillFrame_Update() end
                self.pendingRecipe = nil
                return true
            end
        end
    end
    if visible("CraftFrame") and type(GetNumCrafts) == "function"
        and type(CraftFrame_SetSelection) == "function" then
        for i = 1, GetNumCrafts() or 0 do
            local name, _, kind = GetCraftInfo(i)
            if kind ~= "header" and name == pending.name then
                scrollRecipe("craft", i, GetNumCrafts())
                CraftFrame_SetSelection(i)
                if type(CraftFrame_Update) == "function" then CraftFrame_Update() end
                self.pendingRecipe = nil
                return true
            end
        end
    end
    return false
end

-- Waits for the window a recipe opened (its server answer), a few seconds.
local recipeWaiter = CreateFrame("Frame", "VimFinderRecipeWaiter", UIParent)
recipeWaiter:Hide()
recipeWaiter:SetScript("OnUpdate", function()
    local pending = Finder.pendingRecipe
    if not pending or GetTime() > pending.untilTime then
        Finder.pendingRecipe = nil
        recipeWaiter:Hide()
    elseif Finder:SelectPendingRecipe() then
        recipeWaiter:Hide()
    end
end)

function Finder:Activate()
    local item = self.results[self.selected]
    -- if not item or inCombat() then return end
    -- -- Windows open in combat, as their keys do.
    -- if not item or (inCombat() and item.kind ~= "window") then return end
    -- Windows open and spells (pet spells, tracking) cast in combat, as
    -- their keys do (the user, 2026-10-15: Rockbiter Weapon); bag items,
    -- trade skills and crafts still wait.
    local castable = item and (item.kind == "spell" or item.kind == "petspell" or item.kind == "tracking")
    if not item or (inCombat() and item.kind ~= "window" and not castable) then return end
    local action = canActivate(item)
    if not action then return end
    if item.kind == "window" then
        self:RecordUse(item)
        self:Close()
        -- The window it opens takes focus; one it closes claims nothing.
        -- if VimWowPanelFocus then VimWowPanelFocus:ClaimNext(0.5) end
        self:ExpectWindow(0.5)
        RunBinding(item.book)
    elseif item.kind == "tracking" and item.active
        and type(CancelTrackingBuff) == "function" then
        CancelTrackingBuff()
        self:RecordUse(item)
        self:Scan()
    elseif item.kind == "tracking" and type(SetTracking) == "function" then
        SetTracking(item.index)
        self:RecordUse(item)
        self:Scan()
    elseif item.kind == "trade" and visible("TradeSkillFrame")
        and type(TradeSkillFrame_SetSelection) == "function" then
        scrollRecipe("trade", item.index, GetNumTradeSkills())
        TradeSkillFrame_SetSelection(item.index)
        if type(TradeSkillFrame_Update) == "function" then TradeSkillFrame_Update() end
        self:RecordUse(item)
        self:Close()
    elseif item.kind == "craft" and visible("CraftFrame")
        and type(CraftFrame_SetSelection) == "function" then
        scrollRecipe("craft", item.index, GetNumCrafts())
        CraftFrame_SetSelection(item.index)
        if type(CraftFrame_Update) == "function" then CraftFrame_Update() end
        self:RecordUse(item)
        self:Close()
    elseif item.kind == "recipe" then
        -- its profession's window (cast as Enter on the profession does),
        -- then the recipe selected there; at once when it is open already
        self.pendingRecipe = {name = item.name, untilTime = GetTime() + 3}
        self:RecordUse(item)
        self:Close()
        if not self:SelectPendingRecipe() and type(CastSpell) == "function" then
            self:ExpectWindow(3)
            CastSpell(item.book, "spell")
            recipeWaiter:Show()
        end
    -- elseif item.kind == "bag" then
    --     -- Opens the combined bag with that item's slot selected.
    --     if not VimWowCombinedBags then return end
    --     VimWowCombinedBags:Show()
    --     self:RecordUse(item)
    --     self:Close()
    --     if VimWowPanelFocus and VimWowPanelFocus.Select
    --         and VimWowPanelFocus:Select("bags") and VimWowNavigator then
    --         VimWowNavigator:Refresh()
    --         VimWowNavigator:SelectBagSlot(item.book, item.index)
    --     end
    elseif item.kind == "bag" then
        -- Opens the bags; a host (VimWow) selects that item's slot.
        self:ShowBags()
        self:RecordUse(item)
        self:Close()
        self:SelectBagSlot(item.book, item.index)
    elseif item.kind == "spell" and item.name == "Disenchant" then
        -- The player must click an item; never auto-select or destroy one.
        if type(CastSpell) ~= "function" then return end
        CastSpell(item.index, "spell")
        self:RecordUse(item)
        -- VimWowCombinedBags:Show()
        -- self:Close()
        -- if VimWowPanelFocus and VimWowPanelFocus.Select
        --     and VimWowPanelFocus:Select("bags")
        --     and VimWowNavigator then VimWowNavigator:Refresh() end
        self:ShowBags()
        self:Close()
        self:SelectBagSlot()
    elseif item.kind == "spell" and action == "self" then
        if type(CastSpellByName) == "function" then
            -- A spell that opens a window (Smelting, Poisons) gives it focus
            -- once the server answers.
            -- if VimWowPanelFocus then VimWowPanelFocus:ClaimNext(3) end
            self:ExpectWindow(3)
            CastSpellByName(item.name, true)
            self:RecordUse(item)
            self:Close()
        end
    elseif item.kind == "spell" and type(CastSpell) == "function" then
        -- A profession (Tailoring, Enchanting) gives its window focus once
        -- the server answers.
        -- if VimWowPanelFocus then VimWowPanelFocus:ClaimNext(3) end
        self:ExpectWindow(3)
        CastSpell(item.index, "spell")
        self:RecordUse(item)
        self:Close()
    end
end

function Finder:KeyMove(key, delta)
    local now = GetTime()
    if self.lastKey == key and now - (self.lastKeyAt or 0) < 0.02 then return end
    self.lastKey, self.lastKeyAt = key, now
    self:Move(delta)
end

function Finder:Close()
    self.frame:Hide()
    self.edit:ClearFocus()
    self.capture:EnableKeyboard(false)
    self.ctrlLeft, self.ctrlRight = nil, nil
    self:RefreshBindings()
    if GameTooltip and GameTooltip.IsOwned
        and GameTooltip:IsOwned(self.frame) then GameTooltip:Hide() end
end

function Finder:Toggle()
    if self.frame:IsVisible() then return end
    -- if not VimWow_IsEnabled() then return end
    if not self:IsActive() then return end
    local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if focus and focus ~= self.edit then return end
    self.frame:Show()
    self:RefreshBindings()
    self.edit:SetText("")
    self:Scan()
    self.edit:SetFocus()
    self.ctrlLeft = IsLeftControlKeyDown and IsLeftControlKeyDown() or nil
    self.ctrlRight = IsRightControlKeyDown and IsRightControlKeyDown() or nil
    if self.ctrlLeft or self.ctrlRight then
        self.edit:ClearFocus()
        self.capture:EnableKeyboard(true)
    end
end

-- Finder.frame = CreateFrame("Frame", "VimWowFinderFrame", UIParent)
Finder.frame = CreateFrame("Frame", "VimFinderFrame", UIParent)
-- Finder.frame:SetWidth(600)
-- Finder.frame:SetHeight(260)
Finder.frame:SetWidth(WIDTH)
Finder.frame:SetHeight(HEIGHT)
Finder.frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 95)
-- Finder.frame:SetFrameStrata("DIALOG")
-- Over every window and unit frame (some unit frame bars draw above DIALOG),
-- under tooltips.
Finder.frame:SetFrameStrata("FULLSCREEN_DIALOG")
-- Finder.frame:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background",
--     edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 12,
--     insets = {left = 3, right = 3, top = 3, bottom = 3}})
-- The dialog look of the Game Menu and the popups: dark marble, silver
-- border, and the title on a header plate.
Finder.frame:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = {left = 11, right = 12, top = 12, bottom = 11}})
-- The marble lets about 40% of the world through; a black layer under it
-- (one layer below the finder, still over every window and unit frame)
-- leaves about 15%, enough to notice a change behind the finder. As the
-- finder's child it shows, hides and fades with it.
Finder.shade = CreateFrame("Frame", "VimFinderShade", Finder.frame)
Finder.shade:SetFrameStrata("FULLSCREEN")
Finder.shade:SetPoint("TOPLEFT", Finder.frame, "TOPLEFT", 11, -12)
Finder.shade:SetPoint("BOTTOMRIGHT", Finder.frame, "BOTTOMRIGHT", -12, 11)
Finder.shadeTexture = Finder.shade:CreateTexture(nil, "BACKGROUND")
Finder.shadeTexture:SetTexture("Interface/Buttons/WHITE8X8")
Finder.shadeTexture:SetVertexColor(0, 0, 0, 0.63)
Finder.shadeTexture:SetAllPoints(Finder.shade)
Finder.header = Finder.frame:CreateTexture(nil, "ARTWORK")
Finder.header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
Finder.header:SetWidth(256)
Finder.header:SetHeight(64)
Finder.header:SetPoint("TOP", Finder.frame, "TOP", 0, 12)
Finder.title = Finder.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
Finder.title:SetPoint("TOP", Finder.header, "TOP", 0, -14)
Finder.title:SetText("Finder")
-- Finder.selectionBackground = Finder.frame:CreateTexture(nil, "ARTWORK")
-- Finder.selectionBackground:SetTexture("Interface/Buttons/WHITE8X8")
-- Finder.selectionBackground:SetVertexColor(0.03, 0.03, 0.03, 0.55)
-- Finder.selectionBackground:SetWidth(574)
-- Finder.selectionBackground:SetHeight(22)
-- The quest log's selection bar, in gold.
Finder.selectionBackground = Finder.frame:CreateTexture(nil, "ARTWORK")
Finder.selectionBackground:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
Finder.selectionBackground:SetBlendMode("ADD")
Finder.selectionBackground:SetVertexColor(1, 0.82, 0, 1)
Finder.selectionBackground:SetWidth(ROW_WIDTH + 8)
Finder.selectionBackground:SetHeight(ROW_HEIGHT)
Finder.selectionBackground:Hide()
Finder.capture:SetFrameStrata("TOOLTIP")
Finder.capture:EnableKeyboard(false)
-- Finder.edit = CreateFrame("EditBox", "VimWowFinderInput", Finder.frame,
--     "InputBoxTemplate")
Finder.edit = CreateFrame("EditBox", "VimFinderInput", Finder.frame,
    "InputBoxTemplate")
Finder.edit:SetAutoFocus(false)
-- Finder.edit:SetWidth(550)
-- Finder.edit:SetHeight(28)
-- Finder.edit:SetPoint("TOP", Finder.frame, "TOP", 0, -15)
-- The template's left cap reaches 5 pixels left of the box.
Finder.edit:SetWidth(ROW_WIDTH - 13)
Finder.edit:SetHeight(20)
Finder.edit:SetPoint("TOPLEFT", Finder.frame, "TOPLEFT", ROW_LEFT + 9, -30)
-- Finder.count = Finder.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
-- Finder.count:SetPoint("BOTTOMRIGHT", Finder.frame, "BOTTOMRIGHT", -15, 10)
Finder.count = Finder.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
Finder.count:SetPoint("BOTTOMRIGHT", Finder.frame, "BOTTOMRIGHT", -ROW_LEFT, 20)
-- The keys, in green, as the client's own key labels.
Finder.hints = Finder.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
Finder.hints:SetPoint("BOTTOMLEFT", Finder.frame, "BOTTOMLEFT", ROW_LEFT, 20)
Finder.hints:SetTextColor(0.65, 0.65, 0.65)
Finder.hints:SetText("|cff00ff00Enter|r Use   |cff00ff00Tab|r / "
    .. "|cff00ff00Ctrl+J/K|r Move   |cff00ff00Esc|r Close")
Finder.details = {}
Finder.icons = {}
-- for i = 1, 8 do
--     local row = Finder.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
--     row:SetPoint("TOPLEFT", Finder.frame, "TOPLEFT", 18, -40 - i * 23)
--     row:SetWidth(560)
--     Finder.rows[i] = row
-- end
for i = 1, 8 do
    local top = -ROW_TOP - (i - 1) * ROW_HEIGHT
    local icon = Finder.frame:CreateTexture(nil, "OVERLAY")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("TOPLEFT", Finder.frame, "TOPLEFT", ROW_LEFT, top - 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    Finder.icons[i] = icon
    local row = Finder.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row:SetPoint("TOPLEFT", Finder.frame, "TOPLEFT", ROW_LEFT + 28, top - 6)
    row:SetWidth(ROW_WIDTH / 2 - 28)
    row:SetHeight(14)
    row:SetJustifyH("LEFT")
    Finder.rows[i] = row
    local detail = Finder.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail:SetPoint("TOPRIGHT", Finder.frame, "TOPRIGHT", -ROW_LEFT - 2, top - 7)
    detail:SetWidth(ROW_WIDTH / 2)
    detail:SetHeight(12)
    detail:SetJustifyH("RIGHT")
    Finder.details[i] = detail
end
Finder.edit:SetScript("OnTextChanged", function() Finder:Search() end)
Finder.edit:SetScript("OnEscapePressed", function() Finder:Close() end)
Finder.edit:SetScript("OnEnterPressed", function() Finder:Activate() end)
Finder.edit:SetScript("OnTabPressed", function()
    Finder:Move(IsShiftKeyDown and IsShiftKeyDown() and -1 or 1)
end)
-- The 1.12 EditBox consumes arrows before OnKeyDown in the stock client.
-- Keep this route for clients that forward them; Tab is the native fallback.
Finder.edit:SetScript("OnKeyDown", function(_, key)
    -- The 1.12 client passes the key in arg1 (ClassicAPI also passes it).
    key = key or arg1
    if key == "UP" then Finder:Move(-1)
    elseif key == "DOWN" then Finder:Move(1)
    elseif key == "J" and IsControlKeyDown and IsControlKeyDown() then
        Finder:Move(1)
    elseif key == "K" and IsControlKeyDown and IsControlKeyDown() then
        Finder:Move(-1)
    end
end)
Finder.capture:SetScript("OnKeyDown", function(_, key)
    key = key or arg1
    if not Finder.frame:IsVisible() or not (Finder.ctrlLeft or Finder.ctrlRight)
        then return end
    if key == "J" or key == "DOWN" then Finder:KeyMove("next", 1)
    elseif key == "K" or key == "UP" then Finder:KeyMove("previous", -1)
    elseif key == "ESCAPE" then Finder:Close()
    elseif key == "ENTER" then Finder:Activate() end
end)
Finder.toggle:SetScript("OnClick", function() Finder:Toggle() end)
Finder.closeButton:SetScript("OnClick", function() Finder:Close() end)
Finder.up:SetScript("OnClick", function() Finder:KeyMove("previous", -1) end)
Finder.down:SetScript("OnClick", function() Finder:KeyMove("next", 1) end)
Finder.frame:Hide()

-- Whether the finder may be open and take its keys: its host allows it and
-- no other text box has the keyboard.
function Finder:Allowed()
    if not self:IsActive() then return false end
    local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    return not (focus and focus ~= self.edit)
end

-- function Finder:RefreshBindings(active)
--     if active == nil then
--         active = VimWow_IsEnabled() and not VimWowBindingsCapturing
--             and type(SetOverrideBindingClick) == "function"
--             and type(ClearOverrideBindings) == "function"
--         local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
--         if focus and focus ~= self.edit then active = false end
--     end
--     local binding = active and VimWow_BindingSignature("VIMWOWFINDER",
--         {"ALT-SPACE"}) or ""
-- Override bindings come from ClassicAPI; without them the finder still
-- opens from its key binding and keeps Esc, Enter, Tab and Ctrl+J/K.
-- Without ClassicAPI's override bindings the keys set on the finder's tab
-- are game key bindings to its Bindings.xml command: a key is taken only
-- while no other binding has it, and a key the tab no longer names is given
-- back. VimFinderDB.gameKeys keeps the keys bound this way. Nothing is set
-- before the client's own bindings have loaded (PLAYER_ENTERING_WORLD).
function Finder:ApplyGameBindings(first, second)
    if type(SetBinding) ~= "function" or type(GetBindingAction) ~= "function" then
        return
    end
    if type(VimFinderDB) ~= "table" then VimFinderDB = {} end
    if type(VimFinderDB.gameKeys) ~= "table" then VimFinderDB.gameKeys = {} end
    local held = VimFinderDB.gameKeys
    local wanted = {}
    if first then wanted[first] = true end
    if second then wanted[second] = true end
    local changed = false
    for key in pairs(held) do
        if not wanted[key] then
            if GetBindingAction(key) == "VIMFINDER" then
                SetBinding(key)
                changed = true
            end
            held[key] = nil
        end
    end
    for key in pairs(wanted) do
        local action = GetBindingAction(key)
        if action == nil or action == "" then
            SetBinding(key, "VIMFINDER")
            changed = true
            held[key] = true
        elseif action == "VIMFINDER" then
            held[key] = true
        end
    end
    if changed and type(SaveBindings) == "function" then
        SaveBindings(type(GetCurrentBindingSet) == "function"
            and GetCurrentBindingSet() or 1)
    end
end

function Finder:RefreshBindings(active)
    if type(SetOverrideBindingClick) ~= "function" then
        if not self.bindingsReadyAt or GetTime() < self.bindingsReadyAt then return end
        local first, second = self:OpenKeys()
        local wanted = tostring(first) .. "," .. tostring(second)
        if wanted ~= self.gameBinding then
            self.gameBinding = wanted
            self:ApplyGameBindings(first, second)
        end
        return
    end
    -- With ClassicAPI the key is an override binding. The game key bindings
    -- the finder set in a session without it are given back once: kept,
    -- the old key still opened the finder after a key change on the Finder
    -- tab. Bindings the player set in the key binding window stay.
    if not self.gameKeysReleased and self.bindingsReadyAt and GetTime() >= self.bindingsReadyAt then
        self.gameKeysReleased = true
        self:ApplyGameBindings(nil, nil)
    end
    if active == nil then active = self:Allowed() end
    active = active and type(SetOverrideBindingClick) == "function"
        and type(ClearOverrideBindings) == "function"
    local first, second
    if active then first, second = self:OpenKeys() end
    local binding = active and (tostring(first) .. "," .. tostring(second)) or ""
    if active and self.frame:IsVisible() then binding = binding .. ":navigation" end
    if binding == self.binding then return end
    if type(ClearOverrideBindings) == "function" then
        ClearOverrideBindings(self.owner)
    end
    if active then
        -- VimWow_Override(self.owner, "VIMWOWFINDER",
        --     {"ALT-SPACE"}, self.toggle, true)
        local toggle = self.toggle:GetName()
        if first then SetOverrideBindingClick(self.owner, true, first, toggle) end
        if second then SetOverrideBindingClick(self.owner, true, second, toggle) end
        if self.frame:IsVisible() then
            SetOverrideBindingClick(self.owner, true, "ESCAPE",
                self.closeButton:GetName())
            SetOverrideBindingClick(self.owner, true, "CTRL-K", self.up:GetName())
            SetOverrideBindingClick(self.owner, true, "CTRL-J", self.down:GetName())
            SetOverrideBindingClick(self.owner, true, "CTRL-UP", self.up:GetName())
            SetOverrideBindingClick(self.owner, true, "CTRL-DOWN", self.down:GetName())
        end
    end
    self.binding = binding
end

Finder.owner:SetScript("OnUpdate", function()
    -- Ctrl was released last frame (MODIFIER_STATE_CHANGED): typing again.
    if Finder.refocus then
        Finder.refocus = nil
        if Finder.frame:IsVisible() and not (Finder.ctrlLeft or Finder.ctrlRight) then
            Finder.capture:EnableKeyboard(false)
            Finder.edit:SetFocus()
        end
    end
    -- Without ClassicAPI (which brings IsLeftControlKeyDown and the
    -- MODIFIER_STATE_CHANGED event) Ctrl is read each frame while the
    -- finder is open, so Ctrl+J/K still move.
    if type(IsLeftControlKeyDown) ~= "function" and Finder.frame:IsVisible()
        and type(IsControlKeyDown) == "function" then
        local held = IsControlKeyDown() and true or false
        if held ~= ((Finder.ctrlLeft or Finder.ctrlRight) and true or false) then
            Finder.ctrlLeft, Finder.ctrlRight = held or nil, nil
            if held then
                Finder.edit:ClearFocus()
                Finder.capture:EnableKeyboard(true)
            else
                Finder.capture:EnableKeyboard(false)
                Finder.edit:SetFocus()
            end
        end
    end
    local now = GetTime()
    if now < (Finder.nextUpdate or 0) then return end
    Finder.nextUpdate = now + 0.5
    -- local active = VimWow_IsEnabled() and not VimWowBindingsCapturing
    --     and type(SetOverrideBindingClick) == "function"
    --     and type(ClearOverrideBindings) == "function"
    -- local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    -- if focus and focus ~= Finder.edit then active = false end
    local active = Finder:Allowed()
    if not active and Finder.frame:IsVisible() then Finder:Close() end
    Finder:RefreshBindings(active)
    if Finder.frame:IsVisible() then
        -- Finder.frame:SetAlpha(inCombat() and 0.22 or 0.86)
        -- Opaque out of combat: the dialog background's own see-through
        -- shows enough of the world to notice a change there.
        -- Finder.frame:SetAlpha(inCombat() and 0.22 or 1)
        -- 60% in combat: 22% was too faint to read (the user, 2026-10-15).
        Finder.frame:SetAlpha(inCombat() and 0.6 or 1)
    end
end)
-- for _, event in ipairs({"SPELLS_CHANGED", "TRADE_SKILL_UPDATE",
--     "CRAFT_UPDATE", "BAG_UPDATE", "UNIT_PET", "PET_BAR_UPDATE",
--     "MODIFIER_STATE_CHANGED"}) do
for _, event in ipairs({"SPELLS_CHANGED", "TRADE_SKILL_UPDATE",
    "CRAFT_UPDATE", "BAG_UPDATE", "UNIT_PET", "PET_BAR_UPDATE",
    "MODIFIER_STATE_CHANGED", "PLAYER_ENTERING_WORLD"}) do
    Finder.owner:RegisterEvent(event)
end
Finder.owner:SetScript("OnEvent", function()
    -- The client's key bindings have loaded: game bindings may be set a
    -- second later (RefreshBindings, without ClassicAPI).
    if event == "PLAYER_ENTERING_WORLD" then
        Finder.bindingsReadyAt = Finder.bindingsReadyAt or GetTime() + 1
        return
    end
    if not Finder.frame:IsVisible() then return end
    if event == "MODIFIER_STATE_CHANGED" then
        local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
        if focus and focus ~= Finder.edit then Finder:Close(); return end
        if arg1 == "LCTRL" then Finder.ctrlLeft = arg2 == 1
        elseif arg1 == "RCTRL" then Finder.ctrlRight = arg2 == 1
        else return end
        -- A focused 1.12 EditBox consumes Ctrl+J/K before bindings dispatch.
        -- Release focus while Ctrl is held, then resume typing on release.
        if Finder.ctrlLeft or Finder.ctrlRight then
            Finder.edit:ClearFocus()
            Finder.capture:EnableKeyboard(true)
        else
            -- Finder.capture:EnableKeyboard(false)
            -- Finder.edit:SetFocus()
            -- The search box takes the keyboard back on the next frame
            -- (OnUpdate). This event fires before the client handles the
            -- Ctrl release; a search box focused now takes that release,
            -- and the client then keeps Ctrl held (IsControlKeyDown) after
            -- a Ctrl key opened the finder, until Ctrl is pressed again.
            Finder.refocus = true
        end
    -- else Finder:Scan() end
    else
        -- A rescan keeps the selected result, so Enter still uses the one
        -- shown after a bag, spell or pet update.
        local current = Finder.results and Finder.results[Finder.selected]
        local key = current and usageKey(current)
        Finder:Scan()
        for i, item in ipairs(key and Finder.results or {}) do
            if usageKey(item) == key then
                Finder.selected = i
                Finder:Draw()
                break
            end
        end
    end
end)

-- The finder's tab in VimWow Settings: its key, kept in VimFinderDB.
Finder.settings = {
    id = "VimFinder", name = "Finder", order = 150,
    db = function()
        if type(VimFinderDB) ~= "table" then VimFinderDB = {} end
        return VimFinderDB
    end,
    bindings = {{action = "VIMFINDER", defaults = DEFAULT_KEYS}},
    -- A new key is bound at once.
    onChange = function() Finder.binding = nil end,
}
if VimWowSettings and VimWowSettings.Register then
    VimWowSettings:Register(Finder.settings)
end
