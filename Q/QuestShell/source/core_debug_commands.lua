-- =========================
-- QuestShell core_debug_commands.lua
-- /qsd on|off   -> toggle debug logs
-- =========================
SLASH_QSDEBUG1 = "/qsd"
SlashCmdList = SlashCmdList or {}
SlashCmdList["QSDEBUG"] = function(msg)
    local m = (msg or ""):lower()
    if m == "on" or m == "1" or m == "true" then
        QuestShell = QuestShell or {}; QuestShell.debug = true
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffcc66ff[QuestShell:DBG]|r ON") end
    elseif m == "off" or m == "0" or m == "false" then
        QuestShell = QuestShell or {}; QuestShell.debug = false
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffcc66ff[QuestShell:DBG]|r OFF") end
    else
        local state = (QuestShell and QuestShell.debug) and "ON" or "OFF"
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffcc66ff[QuestShell:DBG]|r "..state.."  (use /qsd on|off)") end
    end
end

-- NEW: /qsresync to manually re-mark accepted quests
SLASH_QSRESYNC1 = "/qsresync"
SlashCmdList.QSRESYNC = function()
    if QS_PassiveResyncAccepts then QS_PassiveResyncAccepts() end
    if QuestShellUI_UpdateAll then QuestShellUI_UpdateAll() end
    QS_Print("QuestShell: resynced ACCEPT steps.")
end

SLASH_QSDEBUG1 = "/qsdebug"
SlashCmdList["QSDEBUG"] = function(msg)
    msg = string.lower(tostring(msg or ""))

    local new
    if msg == "on" or msg == "1" or msg == "true" then
        new = true
    elseif msg == "off" or msg == "0" or msg == "false" then
        new = false
    else
        -- toggle if no/unknown arg
        new = not ((QuestShell and QuestShell.debug) or QuestShell_Debug or false)
    end

    -- set both (compat)
    QuestShell = QuestShell or {}
    QuestShell.debug = new
    QuestShell_Debug = new

    -- (optional) persist account-wide
    QuestShellDB = QuestShellDB or {}; QuestShellDB.ui = QuestShellDB.ui or {}
    QuestShellDB.ui.debugPref = new

    if new then
        QS_Print("Debugging ON")
    else
        QS_Print("Debugging OFF")
    end
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("VARIABLES_LOADED")
    f:SetScript("OnEvent", function()
        -- apply persisted preference if present
        if QuestShellDB and QuestShellDB.ui and type(QuestShellDB.ui.debugPref) == "boolean" then
            QuestShell = QuestShell or {}
            QuestShell.debug = QuestShellDB.ui.debugPref
            QuestShell_Debug = QuestShellDB.ui.debugPref
        end
    end)
end

