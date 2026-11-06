-- AnySCT menu.lua -- "Mark as targetSCT" in the unit right-click menus (target, party and raid frames;
-- pfUI uses the same Blizzard UnitPopup dropdowns). Hooks the 1.12 UnitPopup system:
--   UnitPopupButtons / UnitPopupMenus   register the button, inserted before CANCEL
--   UnitPopup_ShowMenu                  sets the label: Mark as targetSCT / Unmark targetSCT
--   UnitPopup_HideButtons               hides the entry for hostile units and non-players
--   UnitPopup_OnClick                   handles our value, everything else goes to the original
-- Everything is guarded so a missing menu table or function never errors.

AnySCT_Menu = {}
local M = AnySCT_Menu

local KEY = "ANYSCT_TOGGLE"
-- Menus the client opens for a unit: PLAYER (other players, incl. hostile), PARTY, RAID, FRIEND list.
-- NPC targets open "RAID_TARGET_ICON" (the title is the icon list); the key is added to it at
-- level 1 only and removed again for the nested icon submenu of the player menus.
local MENUS = { "PLAYER", "PARTY", "RAID", "FRIEND" }
M.KEY = KEY

local origShow, origHide, origClick

-- The name the menu is about: captured when the menu opened (ShowMenu wrapper), else the unit's
-- current name. Never dd.name: for NPC targets that is the menu title.
local function nameOf(dd)
    if type(dd) ~= "table" then return nil end
    if dd.anyName then return dd.anyName end
    if dd.unit then return UnitName(dd.unit) end
    return nil
end

local function listed(name)
    return name ~= nil and AnySCT_Core.state.byName[name] ~= nil
end

function M.Label(name)
    if listed(name) then return "Unmark targetSCT" end
    return "Mark as targetSCT"
end

-- true when the entry must not be offered: no name, or the player themself (own events are never shown)
function M.Hidden(dd)
    if type(dd) ~= "table" then return true end
    local n = nameOf(dd)
    if n == nil then return true end
    return n == UnitName("player")
end

-- Add (or remove) the key in the NPC menu depending on the menu level.
local function syncIconMenu(which)
    local menu = UnitPopupMenus["RAID_TARGET_ICON"]
    if type(menu) ~= "table" then return end
    local level = UIDROPDOWNMENU_MENU_LEVEL or 1
    local at
    for i = 1, table.getn(menu) do
        if menu[i] == KEY then at = i end
    end
    if level == 1 and which == "RAID_TARGET_ICON" then
        if not at then table.insert(menu, KEY) end
    elseif at then
        table.remove(menu, at)
    end
end

-- Mark / unmark. unit (optional) lets the list learn the GUID of a unit outside the group.
function M.Toggle(name, unit)
    local C = AnySCT_Core
    if C.state.byName[name] then
        C.RemoveSource(name)
        C.Print(name .. " is no longer a targetSCT")
    else
        -- what is known about the unit decides the default of the threat switch (pets, mobs and hostile
        -- players off; players on)
        local info
        if unit and UnitIsPlayer and UnitCanAttack then
            info = { player = UnitIsPlayer(unit) and true or false, friendly = not UnitCanAttack("player", unit) }
        end
        C.AddSource(name, "manual", nil, info)
        if unit and C.SeeUnit then C.SeeUnit(name, unit) end
        -- no token from the menu (or it did not resolve): look at target / targettarget / mouseover
        if C.ProbeLoose then C.ProbeLoose() end
        C.Print(name .. " marked as targetSCT")
    end
end

local function insertKey(menu)
    if type(menu) ~= "table" then return end
    local n = table.getn(menu)
    local at = n + 1
    for i = 1, n do
        if menu[i] == KEY then return end
        if menu[i] == "CANCEL" then at = i; break end
    end
    table.insert(menu, at, KEY)
end

-- Installs the hooks once. Returns true when the UnitPopup tables exist.
function M.Install()
    if M.installed then return true end
    if type(UnitPopupButtons) ~= "table" or type(UnitPopupMenus) ~= "table" then return false end
    UnitPopupButtons[KEY] = { text = "Mark as targetSCT", dist = 0 }
    for i = 1, table.getn(MENUS) do insertKey(UnitPopupMenus[MENUS[i]]) end

    if type(UnitPopup_ShowMenu) == "function" then
        origShow = UnitPopup_ShowMenu
        UnitPopup_ShowMenu = function(dropdownMenu, which, unit, name, userData)
            syncIconMenu(which)
            local n = unit and UnitName(unit) or ((not unit) and name) or nil
            if type(dropdownMenu) == "table" then dropdownMenu.anyName = n end
            UnitPopupButtons[KEY].text = M.Label(n)
            return origShow(dropdownMenu, which, unit, name, userData)
        end
    end
    if type(UnitPopup_HideButtons) == "function" then
        origHide = UnitPopup_HideButtons
        UnitPopup_HideButtons = function()
            origHide()
            local dd = getglobal(UIDROPDOWNMENU_INIT_MENU)
            if type(dd) ~= "table" or type(UnitPopupShown) ~= "table" then return end
            local menu = UnitPopupMenus[dd.which]
            if type(menu) ~= "table" then return end
            for i = 1, table.getn(menu) do
                if menu[i] == KEY and M.Hidden(dd) then UnitPopupShown[i] = 0 end
            end
        end
    end
    if type(UnitPopup_OnClick) == "function" then
        origClick = UnitPopup_OnClick
        UnitPopup_OnClick = function()
            if this and this.value == KEY then
                local dd = getglobal(UIDROPDOWNMENU_INIT_MENU)
                local n = nameOf(dd)
                if n then M.Toggle(n, dd.unit) end
                return
            end
            return origClick()
        end
    end
    M.installed = true
    return true
end
