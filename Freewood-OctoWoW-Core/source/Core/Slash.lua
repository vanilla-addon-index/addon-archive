-- Freewood-OctoWoW-Core: Slash-Befehle  (/freewood und /fw)

local ADDON, FW = ...

SLASH_FREEWOOD1 = "/freewood"
SLASH_FREEWOOD2 = "/fw"

local function PrintHelp()
    local L = FW.L
    FW:Print(L.SLASH_HELP_TITLE)
    for i = 1, 7 do
        print("  " .. L["SLASH_HELP_" .. i])
    end
end

local function Handle(msg)
    local L = FW.L
    msg = strtrim(msg or ""):lower()
    local cmd = msg:match("^(%S*)")

    if cmd == "" then
        FW.UI:Toggle()
    elseif cmd == "settings" or cmd == "config" or cmd == "options" then
        FW.UI:Show("settings")
    elseif cmd == "exchange" or cmd == "export" or cmd == "import" then
        FW.UI:Show("exchange")
    elseif cmd == "minimap" then
        FW.Minimap:SetHidden(not FW.settings.minimap.hide)
    elseif cmd == "modules" then
        if #FW.moduleList == 0 then
            FW:Print(L.SLASH_NO_MODULES)
        else
            for _, mod in ipairs(FW.moduleList) do
                FW:Print(mod.name, mod.version and ("v" .. mod.version) or "", "(" .. mod.state .. ")")
            end
        end
    elseif cmd == "debug" then
        FW.settings.debug = not FW.settings.debug
        FW:Print(FW.settings.debug and L.SLASH_DEBUG_ON or L.SLASH_DEBUG_OFF)
    elseif cmd == "reset" then
        FW.UI:ResetPosition()
        FW:Print(L.SLASH_RESET_DONE)
    elseif cmd == "version" then
        local _, _, _, toc = GetBuildInfo()
        FW:Print(string.format(L.SLASH_VERSION, FW.version, FW.API_VERSION, tostring(toc or "?")))
    else
        PrintHelp()
    end
end

SlashCmdList["FREEWOOD"] = Handle
