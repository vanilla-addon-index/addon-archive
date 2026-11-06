-- ButtonForge Classic - core
local BF = BFClassic

SLASH_BUTTONFORGECLASSIC1 = "/bf"
SLASH_BUTTONFORGECLASSIC2 = "/bfc"

local function BFC_Parse(msg)
    msg = string.lower(msg or "")
    local cmd = msg
    local a = nil
    local b = nil

    local p = string.find(msg, " ")
    if p then
        cmd = string.sub(msg, 1, p - 1)
        local rest = string.sub(msg, p + 1)
        local p2 = string.find(rest, " ")
        if p2 then
            a = string.sub(rest, 1, p2 - 1)
            b = string.sub(rest, p2 + 1)
        else
            a = rest
        end
    end

    return cmd, a, b, msg
end

function BF:PrintHelp()
    self:Print(self.Version)
    self:Print("/bf new  - create a new bar")
    self:Print("/bf delete - delete the active bar")
    self:Print("/bf list - list bars")
    self:Print("/bf cols 6 - set active bar to 6 columns")
    self:Print("/bf rows 2 - set active bar to 2 rows")
    self:Print("/bf size 6 2 - set columns/rows")
    self:Print("/bf scale 1.2 - scale active bar")
    self:Print("/bf lock - lock active bar position")
    self:Print("/bf unlock - unlock active bar position")
    self:Print("/bf actionlock - lock actions (Shift + Drag overrides)")
    self:Print("/bf actionunlock - unlock actions")
    self:Print("/bf menu - open/close minimap configuration menu")
    self:Print("/bf config - toggle configure mode")
    self:Print("/bf keybind - toggle keybind mode")
    self:Print("/bf bg - toggle active bar background")
    self:Print(self:T("TOGGLE_ALL_BG_HELP"))
    self:Print("/bf grid - toggle active bar empty slots")
    self:Print("/bf mouseover - toggle mouseover mode for active bar")
    self:Print("/bf mouseoverdelay 1.5 - set mouseover hide delay in seconds")
    self:Print("/bf slots - show internal Vanilla slots")
    self:Print("/bf reset - reset settings")
end

SlashCmdList["BUTTONFORGECLASSIC"] = function(msg)
    local cmd, a, b, fullmsg = BFC_Parse(msg)

    if cmd == "new" then
        BF:CreateBar()
    elseif cmd == "delete" or cmd == "del" then
        BF:DeleteActiveBar()
    elseif cmd == "reset" then
        -- Reset only ButtonForge's saved layout/settings.
        -- Do NOT touch WoW keybindings here; those are managed separately.
        ButtonForgeClassicCharDB = nil
        ReloadUI()
    elseif cmd == "list" then
        BF:ListBars()
    elseif cmd == "cols" then
        BF:SetActiveBarCols(tonumber(a))
    elseif cmd == "rows" then
        BF:SetActiveBarRows(tonumber(a))
    elseif cmd == "size" then
        BF:SetActiveBarSize(tonumber(a), tonumber(b))
    elseif cmd == "scale" then
        BF:SetActiveBarScale(tonumber(a))
    elseif cmd == "lock" then
        BF:SetActiveBarLocked(true)
    elseif cmd == "unlock" then
        BF:SetActiveBarLocked(false)
    elseif cmd == "actionlock" or cmd == "alock" then
        BF:SetActiveBarActionsLocked(true)
    elseif cmd == "actionunlock" or cmd == "aunlock" then
        BF:SetActiveBarActionsLocked(false)
    elseif cmd == "menu" or cmd == "options" then
        BF:ToggleMinimapMenu()
    elseif cmd == "config" or cmd == "edit" then
        BF:ToggleConfigMode()
    elseif cmd == "keybind" or cmd == "kb" then
        BF:ToggleKeybindMode()
    elseif cmd == "bg" or cmd == "background" then
        if a == "all" then
            BF:ToggleAllBarBackgrounds()
        else
            BF:ToggleActiveBarBackground()
        end
    elseif cmd == "grid" then
        BF:ToggleBarGrid(BF:GetActiveBar())
    elseif cmd == "mouseover" or cmd == "mo" then
        BF:ToggleActiveBarMouseover()
    elseif cmd == "mouseoverdelay" or cmd == "modelay" then
        BF:SetActiveBarMouseoverDelay(a)
    elseif cmd == "slots" then
        BF:Print("ButtonForge Classic uses Vanilla ActionSlots " .. tostring(BF.ActionSlotStart) .. " to " .. tostring(BF.ActionSlotEnd) .. ".")
        local i
        for i = BF.ActionSlotStart, BF.ActionSlotEnd do
            if HasAction and HasAction(i) then
                BF:Print("Slot " .. tostring(i) .. ": " .. BF:T("SLOT_OCCUPIED"))
            end
        end
    else
        BF:PrintHelp()
    end
end

BF.EventFrame = CreateFrame("Frame")
BF.EventFrame:RegisterEvent("VARIABLES_LOADED")
BF.EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
BF.EventFrame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        BF:EnsureDB()
        BF:Print("Character profile: " .. tostring(ButtonForgeClassicDB.profileKey or "Unknown"))
        BF:LoadBars()
        BF:CreateMinimapButton()
        BF:ApplyConfigModeToAllBars()
        -- Do not clear or rebuild WoW bindings on login.
        -- WoW loads the current character binding set by itself.
        BF:RefreshAllHotkeys()
        BF:Print(BF:T("ADDON_LOADED"))
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- HasAction() is reliable now. Reclaim stale reservations left by
        -- empty, resized or previously deleted buttons.
        BF:ReclaimUnusedActionSlots()
    end
end)
