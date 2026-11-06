-- LockpickTooltip
-- Adds required lockpicking skill to tooltips for lockpickable items/objects
-- Compatible with WoW 1.12.1 (Vanilla)

-- string.match does not exist in Lua 5.0 (WoW 1.12); use string.find with captures
local function GetItemIDFromLink(link)
    if not link then return nil end
    local _, _, idStr = string.find(link, "item:(%d+)")
    return tonumber(idStr)
end

-------------------------------------------------------------------------------
-- SETTINGS
-- LockpickTooltipDB is a SavedVariable persisted across sessions.
-- colorMode: "simple"  = green (pickable) / red (too low)
--            "match"   = copy the colour of the game's own "Locked" text
-------------------------------------------------------------------------------
LockpickTooltipDB = LockpickTooltipDB or { colorMode = "simple" }

-------------------------------------------------------------------------------
-- LOCKPICKING SKILL REQUIREMENTS
--
-- Formula for chests/lockboxes in vanilla:
--   Chest lock level roughly = (item level * 5) capped at 300
--   Lockboxes have explicit known values listed below.
--
-- Sources: Wowhead Vanilla, WoWWiki, in-game testing community data
-------------------------------------------------------------------------------

-- Item lockboxes: itemID -> required lockpicking skill
-- Skill shown is the "orange" threshold (when the box first gives skill-ups)
-- All IDs verified against wowhead.com/classic
local LOCKBOX_ITEMS = {
    -- Junkboxes (pickpocket loot)
    [16882] = 25,   -- Battered Junkbox  (drops from lvl 20-30 mobs)
    [16883] = 100,  -- Worn Junkbox      (drops from lvl 30-40 mobs)
    [16884] = 175,  -- Sturdy Junkbox    (drops from lvl 40-50 mobs)
    [16885] = 250,  -- Heavy Junkbox     (drops from lvl 50-60 mobs)

    -- Crafted / dropped lockboxes
    [4632]  = 60,   -- Ornate Bronze Lockbox
    [4633]  = 75,   -- Heavy Bronze Lockbox
    [4634]  = 85,   -- Iron Lockbox
    [4636]  = 125,  -- Strong Iron Lockbox
    [4637]  = 180,  -- Steel Lockbox
    [4638]  = 225,  -- Reinforced Steel Lockbox
    [5758]  = 225,  -- Mithril Lockbox
    [5759]  = 225,  -- Thorium Lockbox
    [5760]  = 225,  -- Eternium Lockbox

    -- Engineering lockboxes / misc
    [13541] = 150,  -- Gnomish Lock Box
}

-- Gameobject names -> required lockpicking skill
-- In 1.12.1 we can check GameTooltip target via mouseover; object names are
-- the most reliable hook available since object IDs aren't directly exposed
-- in the 1.12 API the same way item IDs are.
-- Doors always use simple green/red colouring regardless of colour mode setting
local LOCKABLE_DOORS = {
    ["Ironclad Cove Gate"]          = 150,  -- Deadmines
    ["Water Gate"]                  = 150,  -- Deadmines
    ["Gnomeregan Door"]             = 150,  -- Gnomeregan backdoor
    ["Gnomeregan Entry Door"]       = 150,  -- Gnomeregan backdoor (alternate name)
    ["Armory Door"]                 = 175,  -- Scarlet Monastery Armory
    ["Cathedral Door"]              = 175,  -- Scarlet Monastery Cathedral
    ["Searing Gorge Gate"]          = 225,  -- Loch Modan / Searing Gorge gate
    ["Prison Door"]                 = 250,  -- Blackrock Depths prison cells
    ["Shadowforge Door"]            = 250,  -- Blackrock Depths Shadowforge gates
    ["Shadowforge Lock"]            = 250,  -- Blackrock Depths Shadowforge mechanism (alternate name)
    ["Crescent Door"]               = 300,  -- Dire Maul
    ["Gordok Inner Door"]           = 300,  -- Dire Maul North
    ["Hidden Reach Door"]           = 300,  -- Dire Maul
    ["Scholomance Door"]            = 280,  -- Scholomance main entrance
    ["Service Entrance Door"]       = 300,  -- Stratholme servant's entrance
    ["Stratholme Gate"]             = 300,  -- Stratholme (alternate name)
}

local LOCKABLE_OBJECTS = {
    -- ===== Rogue training objects =====
    ["Buccaneer's Strongbox"]       = 0,    -- Horde rogue quest, ship near Ratchet in The Barrens
    ["Practice Lockbox"]            = 0,    -- Alliance rogue quest, Alther's Mill in Redridge

    -- ===== Silverpine Forest =====
    ["Decrepit Chest"]              = 1,

    -- ===== The Barrens / Ashenvale =====
    ["Battered Chest"]              = 1,
    ["Waterlogged Footlocker"]      = 70,   -- Ashenvale, Redridge (150 in Desolace; handled in AppendObjectLockLine)

    -- ===== Stonetalon / Hillsbrad / Wetlands / Badlands =====
    -- Multiple variants with different requirements; handled in AppendObjectLockLine
    ["Battered Footlocker"]         = 70,

    -- ===== Shadowfang Keep =====
    ["Arugal's Footlocker"]         = 175,

    -- ===== Gnomeregan =====
    ["Large Toolbox"]               = 150,
    ["Toolbox"]                     = 100,

    -- ===== Stormwind Stockades =====
    ["Footlocker"]                  = 100,

    -- ===== Razorfen Kraul / Downs =====
    ["Razorfen Footlocker"]         = 125,

    -- ===== Scarlet Monastery =====
    ["Ornate Chest"]                = 150,
    ["Gilded Chest"]                = 175,

    -- ===== Uldaman =====
    ["Uldaman Cache"]               = 150,
    ["Uldaman Footlocker"]          = 175,
    ["Stone Cache"]                 = 175,

    -- ===== Zul'Farrak =====
    ["Zul'Farrak Chest"]            = 175,

    -- ===== Maraudon =====
    ["Maraudon Chest"]              = 200,

    -- ===== Sunken Temple =====
    ["Sunken Temple Chest"]         = 200,
    ["Troll Chest"]                 = 175,
    -- Mossy Footlocker: 175 in Desolace/Swamp of Sorrows, 225 in Azshara; handled in AppendObjectLockLine
    ["Mossy Footlocker"]            = 175,

    -- ===== Badlands / Searing Gorge / Tanaris =====
    -- Dented Footlocker: 175 in Badlands, 200/225 in Searing Gorge, 225 in Tanaris; handled in AppendObjectLockLine
    ["Dented Footlocker"]           = 175,

    -- ===== Searing Gorge =====
    ["Slag Pit Footlocker"]         = 200,  -- Lower Slag Pit
    ["Searing Gorge Footlocker"]    = 225,  -- Upper Slag Pit

    -- ===== Blackrock Depths =====
    ["Dwarven Chest"]               = 225,
    ["Shadowforge Cache"]           = 280,
    ["Shadowforge Chest"]           = 280,
    ["Relic Coffer"]                = 280,
    ["Dark Iron Strongbox"]         = 280,

    -- ===== Blackrock Spire =====
    ["Smoldering Chest"]            = 275,  -- LBRS/UBRS
    ["Large Iron Bound Chest"]      = 25,   -- Low level zones
    ["Large Mithril Bound Chest"]   = 275,  -- LBRS

    -- ===== Dire Maul =====
    ["Dusty Lockbox"]               = 250,
    ["Crumbling Chest"]             = 225,
    ["Dire Maul Chest"]             = 250,

    -- ===== Scholomance =====
    ["Scholomance Cache"]           = 275,
    ["Viewing Room Cabinet"]        = 275,
    ["Cabinet of Spells"]           = 275,

    -- ===== Stratholme =====
    ["Stratholme Supply Crate"]     = 275,
    ["Stratholme Chest"]            = 275,

    -- ===== Eastern Plaguelands =====
    ["Mossflayer Chest"]            = 225,
    ["Lich's Box"]                  = 275,
    ["Scarlet Footlocker"]          = 250,  -- Eastern Plaguelands

    -- ===== Silithus =====
    ["Silithid Cache"]              = 250,
    ["Hive'Ashi Chest"]             = 250,

    -- ===== Generic outdoor chests =====
    ["Rusty Chest"]                 = 1,
    ["Solid Chest"]                 = 175,
    ["Large Solid Chest"]           = 175,
    ["Treasure Chest"]              = 175,
    ["Sunken Chest"]                = 200,
    ["Scarab Chest"]                = 200,
    ["Elvish Chest"]                = 125,
    ["Embossed Chest"]              = 175,
    ["Wicker Chest"]                = 100,
    ["Strongbox"]                   = 175,
}

-------------------------------------------------------------------------------
-- COLOUR HELPER
-- Returns true if the player can pick the lock, false otherwise.
-- Returns nil if the player has no lockpicking skill.
-------------------------------------------------------------------------------
local function CanPickLock(required)
    required = tonumber(required) or 0
    for i = 1, GetNumSkillLines() do
        local name, _, _, rank = GetSkillLineInfo(i)
        if name == "Lockpicking" then
            return tonumber(rank) >= required
        end
    end
    return false
end

-------------------------------------------------------------------------------
-- TOOLTIP HOOKS
-------------------------------------------------------------------------------
local orig_SetItem      = GameTooltip.SetItem
local orig_SetBagItem   = GameTooltip.SetBagItem
local orig_SetLootItem  = GameTooltip.SetLootItem
local orig_SetQuestItem = GameTooltip.SetQuestItem
local orig_SetQuestLogItem = GameTooltip.SetQuestLogItem
local orig_SetHyperlink = GameTooltip.SetHyperlink

-- Returns the colour code to use for a tooltip line.
-- "simple" mode: green if pickable, red if not.
-- "match"  mode: copy the r,g,b from the game's own "Locked" text line,
--                but only if a Locked line is actually present and skill-gated
--                (i.e. its colour is not just default white/grey descriptive text).
--                Falls back to simple if no usable Locked line is found.
local function GetLineColor(pickable)
    if LockpickTooltipDB.colorMode == "match" then
        for i = 1, 30 do
            local left = getglobal("GameTooltipTextLeft" .. i)
            if not left then break end
            local t = left:GetText()
            if t and string.find(t, "Locked") then
                local r, g, b = left:GetTextColor()
                r = r or 0
                g = g or 0
                b = b or 0
                -- Only use this colour if it looks like a skill-gated line:
                -- skill-gated Locked lines are red, orange, yellow, green, or grey
                -- but NOT plain white (r~1, g~1, b~1) which is just descriptive text
                local isWhite = r > 0.9 and g > 0.9 and b > 0.9
                if not isWhite then
                    local ri = math.floor(r * 255)
                    local gi = math.floor(g * 255)
                    local bi = math.floor(b * 255)
                    return string.format("|cff%02x%02x%02x", ri, gi, bi)
                end
            end
        end
    end
    -- simple mode or no usable Locked line found
    if pickable then
        return "|cff00ff00"
    else
        return "|cffff2020"
    end
end

-- Append lockpick line for a known item ID
local function AppendItemLockLine(itemID)
    if not itemID then return end
    local req = LOCKBOX_ITEMS[itemID]
    if req then
        local pickable = CanPickLock(req)
        local color = GetLineColor(pickable)
        if pickable then
            GameTooltip:AddLine(color .. "Pickable (" .. req .. ")|r")
        else
            GameTooltip:AddLine(color .. "Skill Level Too Low (" .. req .. ")|r")
        end
        GameTooltip:Show()
    end
end

-- Returns "red" if the "Locked" line is red (skill too low),
-- "other" if Locked is present but any other colour (orange/yellow/green/grey = pickable),
-- nil if no Locked line found.
local function GetLockedLineColor()
    for i = 1, 30 do
        local left = getglobal("GameTooltipTextLeft" .. i)
        if not left then break end
        local t = left:GetText()
        if t and string.find(t, "Locked") then
            local r, g, b = left:GetTextColor()
            r = r or 0
            g = g or 0
            b = b or 0
            -- Red: high red channel, low green and blue
            if r > 0.8 and g < 0.3 and b < 0.3 then
                return "red"
            else
                return "other"
            end
        end
    end
    return nil
end

-- Returns true if the tooltip contains a "Locked" line (any colour)
local function IsTooltipLocked()
    return GetLockedLineColor() ~= nil
end

-- Helper to display a line for objects with multiple possible skill requirements.
-- Uses the colour of the game's own "Locked" text to determine which variant it is:
-- If "Locked" is red and playerSkill is between low and high, it must be the higher variant.
local function AddMultiLevelLine(levels)
    -- Single level: straightforward
    if table.getn(levels) == 1 then
        local req = levels[1]
        local pickable = CanPickLock(req)
        local color = GetLineColor(pickable)
        if pickable then
            GameTooltip:AddLine(color .. "Pickable (" .. req .. ")|r")
        else
            GameTooltip:AddLine(color .. "Skill Level Too Low (" .. req .. ")|r")
        end
        GameTooltip:Show()
        return
    end

    -- Multiple levels: use the Locked line colour to disambiguate
    local lockedColor = GetLockedLineColor()
    local low  = levels[1]
    local high = levels[table.getn(levels)]

    if lockedColor == "red" and CanPickLock(low) then
        -- Locked is red but player can pick the low variant - must be the higher one
        local color = GetLineColor(false)
        GameTooltip:AddLine(color .. "Skill Level Too Low (" .. high .. ")|r")
    elseif lockedColor == "red" then
        -- Locked is red and player can't pick either - too low for even the lowest
        local color = GetLineColor(false)
        GameTooltip:AddLine(color .. "Skill Level Too Low (" .. low .. ")|r")
    else
        -- Locked is not red (orange/yellow/green/grey) - player can pick it
        local color = GetLineColor(true)
        GameTooltip:AddLine(color .. "Pickable (" .. low .. ")|r")
    end
    GameTooltip:Show()
end

-- Append lockpick line for a known object name
local function AppendObjectLockLine(name)
    if not name then return end

    -- Doors: always use simple green/red, no colour matching
    local doorReq = LOCKABLE_DOORS[name]
    if doorReq then
        if CanPickLock(doorReq) then
            GameTooltip:AddLine("|cff00ff00Pickable (" .. doorReq .. ")|r")
        else
            GameTooltip:AddLine("|cffff2020Skill Level Too Low (" .. doorReq .. ")|r")
        end
        GameTooltip:Show()
        return
    end

    if not IsTooltipLocked() then return end

    local zone = GetRealZoneText()

    -- -----------------------------------------------------------------------
    -- Battered Footlocker: varies by zone
    -- Stonetalon Mountains: 70 or 110
    -- Wetlands:             70 or 115
    -- Hillsbrad Foothills:  110
    -- Badlands:             150
    -- -----------------------------------------------------------------------
    if name == "Battered Footlocker" then
        if zone == "Stonetalon Mountains" then
            AddMultiLevelLine({70, 110})
        elseif zone == "Wetlands" then
            AddMultiLevelLine({70, 115})
        elseif zone == "Hillsbrad Foothills" then
            AddMultiLevelLine({110})
        elseif zone == "Badlands" then
            AddMultiLevelLine({150})
        else
            AddMultiLevelLine({70, 110})  -- fallback: show both common levels
        end
        return
    end

    -- -----------------------------------------------------------------------
    -- Waterlogged Footlocker: 70 in Ashenvale/Redridge, 150 in Desolace
    -- -----------------------------------------------------------------------
    if name == "Waterlogged Footlocker" then
        if zone == "Desolace" then
            AddMultiLevelLine({150})
        else
            AddMultiLevelLine({70, 115})
        end
        return
    end

    -- -----------------------------------------------------------------------
    -- Mossy Footlocker: 175 in Desolace/Swamp of Sorrows, 225 in Azshara
    -- -----------------------------------------------------------------------
    if name == "Mossy Footlocker" then
        if zone == "Azshara" then
            AddMultiLevelLine({225})
        else
            AddMultiLevelLine({175})
        end
        return
    end

    -- -----------------------------------------------------------------------
    -- Dented Footlocker: 175 in Badlands, 200 or 225 in Searing Gorge, 225 in Tanaris
    -- -----------------------------------------------------------------------
    if name == "Dented Footlocker" then
        if zone == "Badlands" then
            AddMultiLevelLine({175})
        elseif zone == "Searing Gorge" then
            AddMultiLevelLine({200, 225})
        elseif zone == "Tanaris" then
            AddMultiLevelLine({225})
        else
            AddMultiLevelLine({175, 225})  -- fallback
        end
        return
    end

    -- -----------------------------------------------------------------------
    -- All other objects: single fixed requirement
    -- -----------------------------------------------------------------------
    local req = LOCKABLE_OBJECTS[name]
    if req then
        local pickable = CanPickLock(req)
        local color = GetLineColor(pickable)
        if pickable then
            GameTooltip:AddLine(color .. "Pickable (" .. req .. ")|r")
        else
            GameTooltip:AddLine(color .. "Skill Level Too Low (" .. req .. ")|r")
        end
        GameTooltip:Show()
    end
end

-------------------------------------------------------------------------------
-- Hook SetItem (used for world objects / bags in some cases)
-------------------------------------------------------------------------------
GameTooltip.SetItem = function(self, itemType, index)
    orig_SetItem(self, itemType, index)
    local name = GameTooltipTextLeft1:GetText()
    AppendObjectLockLine(name)
end

-------------------------------------------------------------------------------
-- Hook SetBagItem - called when hovering items in your bags
-------------------------------------------------------------------------------
GameTooltip.SetBagItem = function(self, bag, slot)
    orig_SetBagItem(self, bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if link then
        local itemID = GetItemIDFromLink(link)
        AppendItemLockLine(itemID)
    end
end

-------------------------------------------------------------------------------
-- Hook SetLootItem - called for loot window items
-------------------------------------------------------------------------------
GameTooltip.SetLootItem = function(self, slot)
    orig_SetLootItem(self, slot)
    local link = GetLootSlotLink(slot)
    if link then
        local itemID = GetItemIDFromLink(link)
        AppendItemLockLine(itemID)
    end
end

-------------------------------------------------------------------------------
-- Hook SetQuestItem / SetQuestLogItem
-------------------------------------------------------------------------------
GameTooltip.SetQuestItem = function(self, qtype, index)
    orig_SetQuestItem(self, qtype, index)
    local link = GetQuestItemLink(qtype, index)
    if link then
        local itemID = GetItemIDFromLink(link)
        AppendItemLockLine(itemID)
    end
end

GameTooltip.SetQuestLogItem = function(self, qtype, index)
    orig_SetQuestLogItem(self, qtype, index)
    local link = GetQuestLogItemLink(qtype, index)
    if link then
        local itemID = GetItemIDFromLink(link)
        AppendItemLockLine(itemID)
    end
end

-------------------------------------------------------------------------------
-- Hook SetHyperlink - used by chat links, merchant windows, etc.
-------------------------------------------------------------------------------
GameTooltip.SetHyperlink = function(self, link)
    orig_SetHyperlink(self, link)
    if link then
        local itemID = GetItemIDFromLink(link)
        AppendItemLockLine(itemID)
    end
end

-------------------------------------------------------------------------------
-- WORLD OBJECT TOOLTIP HOOK
-- In 1.12.1, game objects (chests, doors) do not register as units, so
-- UnitName("mouseover") returns nil for them. The reliable fix is hooking
-- GameTooltip's OnShow script, which fires for ALL tooltips including world
-- objects, then reading the name from the first tooltip text line.
-------------------------------------------------------------------------------
local orig_OnShow = GameTooltip:GetScript("OnShow")
GameTooltip:SetScript("OnShow", function()
    if orig_OnShow then orig_OnShow() end
    local name = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
    if name then
        AppendObjectLockLine(name)
    end
end)

-------------------------------------------------------------------------------
-- MERCHANT / TRADE WINDOW SUPPORT
-- Hook into merchant item tooltip display
-------------------------------------------------------------------------------
local orig_SetMerchantItem = GameTooltip.SetMerchantItem
if orig_SetMerchantItem then
    GameTooltip.SetMerchantItem = function(self, index)
        orig_SetMerchantItem(self, index)
        local link = GetMerchantItemLink(index)
        if link then
            local itemID = GetItemIDFromLink(link)
            AppendItemLockLine(itemID)
        end
    end
end

-------------------------------------------------------------------------------
-- TRADE SKILL / CRAFTING WINDOW
-------------------------------------------------------------------------------
local orig_SetTradeSkillItem = GameTooltip.SetTradeSkillItem
if orig_SetTradeSkillItem then
    GameTooltip.SetTradeSkillItem = function(self, index, reagentIndex)
        orig_SetTradeSkillItem(self, index, reagentIndex)
        local link
        if reagentIndex then
            link = GetTradeSkillReagentItemLink(index, reagentIndex)
        else
            link = GetTradeSkillItemLink(index)
        end
        if link then
            local itemID = GetItemIDFromLink(link)
            AppendItemLockLine(itemID)
        end
    end
end

-------------------------------------------------------------------------------
-- SLASH COMMAND - /lpt or /lockpick - list known lockpickable items
-------------------------------------------------------------------------------
SLASH_LOCKPICKTIP1 = "/lpt"
SLASH_LOCKPICKTIP2 = "/lockpick"

SlashCmdList["LOCKPICKTIP"] = function(msg)
    local arg = string.lower(msg or "")
    if arg == "items" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00LockpickTooltip - Known Lockboxes/Items:|r")
        for id, req in pairs(LOCKBOX_ITEMS) do
            local name = GetItemInfo(id)
            if name then
                DEFAULT_CHAT_FRAME:AddMessage("  |cffaaddff" .. name .. "|r - Requires: " .. req)
            end
        end
    elseif arg == "objects" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00LockpickTooltip - Known Lockable Objects:|r")
        for name, req in pairs(LOCKABLE_OBJECTS) do
            DEFAULT_CHAT_FRAME:AddMessage("  |cffaaddff" .. name .. "|r - Requires: " .. req)
        end
    elseif arg == "color" or arg == "colour" then
        if LockpickTooltipDB.colorMode == "simple" then
            LockpickTooltipDB.colorMode = "match"
            DEFAULT_CHAT_FRAME:AddMessage("|cffffff00LockpickTooltip|r: Color mode set to |cffaaddffMatch|r - tooltip text will match the game's Locked color.")
        else
            LockpickTooltipDB.colorMode = "simple"
            DEFAULT_CHAT_FRAME:AddMessage("|cffffff00LockpickTooltip|r: Color mode set to |cffaaddffSimple|r - |cff00ff00green|r = pickable, |cffff2020red|r = too low.")
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00LockpickTooltip|r (1.2.0) - Tooltip skill hints for rogues")
        DEFAULT_CHAT_FRAME:AddMessage("Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffaaddff/lpt items|r   - list known lockboxes")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffaaddff/lpt objects|r - list known lockable objects")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffaaddff/lpt color|r   - toggle color mode (currently: " .. LockpickTooltipDB.colorMode .. ")")
        DEFAULT_CHAT_FRAME:AddMessage("Color modes: |cffaaddffSimple|r = green/red  |  |cffaaddffMatch|r = mirrors game Locked color")
    end
end

DEFAULT_CHAT_FRAME:AddMessage("|cffffff00LockpickTooltip|r (1.2.0) loaded. Type |cffaaddff/lpt|r for help.")
