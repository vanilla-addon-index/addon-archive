FriendHostile_VERSION = "1.4.4"

FH_PlayerInfo = nil
FH_Timer = 0
FH_Done = nil
FH_Initialized = nil
FH_InApply = nil
FH_PendingPage = nil
FH_PendingDelay = 0
FH_LoggingOut = nil

function FH_Print(s)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(s)
    end
end

function FH_UnitInit()
    local playerName = UnitName("player")
    if playerName == nil or playerName == "Unknown Entity" or playerName == UNKNOWNBEING or playerName == UNKNOWNOBJECT then
        return
    end

    FH_PlayerInfo = playerName .. " of " .. GetCVar("realmName")
    FH_Done = 1
end

function FH_OnUpdate(arg1)
    FH_Timer = FH_Timer + arg1

    if not FH_Done and FH_Timer > 0.2 then
        FH_UnitInit()
        FH_Timer = 0
    end

    if FH_PendingPage ~= nil and not FH_LoggingOut then
        FH_PendingDelay = FH_PendingDelay - arg1
        if FH_PendingDelay <= 0 then
            local page = FH_PendingPage
            FH_PendingPage = nil
            FH_PendingDelay = 0
            FH_SetActionPage(page)
        end
    end
end

function FH_GetDB()
    if FriendHostileSettings == nil then
        FriendHostileSettings = {}
    end

    if FH_PlayerInfo == nil then
        return nil
    end

    if FriendHostileSettings[FH_PlayerInfo] == nil then
        FriendHostileSettings[FH_PlayerInfo] = {}
    end

    local db = FriendHostileSettings[FH_PlayerInfo]

    if db.Enabled == nil then db.Enabled = 1 end
    if db.PageFriendly == nil then db.PageFriendly = 1 end
    if db.PageHostile == nil then db.PageHostile = 2 end
    if db.NoTargetMode == nil then db.NoTargetMode = 1 end
    if db.StoredPage == nil then db.StoredPage = 1 end

    return db
end

function FH_SetActionPage(page)
    if page < 1 or page > 6 then
        page = 1
    end

    local current = CURRENT_ACTIONBAR_PAGE or 1
    if current == page then
        return
    end

    CURRENT_ACTIONBAR_PAGE = page
    ChangeActionBarPage()
end

function FH_QueuePage(page)
    if page < 1 or page > 6 then
        page = 1
    end

    if FH_LoggingOut then
        return
    end

    if FH_PendingPage == page then
        return
    end

    FH_PendingPage = page
    FH_PendingDelay = 0.15
end

function FH_SaveCurrentPage(db)
    if db then
        db.StoredPage = CURRENT_ACTIONBAR_PAGE or db.StoredPage or 1
    end
end

function FH_DeterminePage()
    local db = FH_GetDB()
    if not db then
        return 1
    end

    if db.Enabled == 0 then
        return db.PageFriendly
    end

    if not UnitExists("target") then
        if db.NoTargetMode == 1 then
            return db.PageFriendly
        elseif db.NoTargetMode == 2 then
            return db.PageHostile
        elseif db.NoTargetMode == 3 then
            return db.StoredPage
        end
        return db.PageFriendly
    end

    if UnitIsFriend("player", "target") == 1 then
        return db.PageFriendly
    end

    return db.PageHostile
end

function FH_Apply()
    if FH_InApply or FH_LoggingOut then
        return
    end

    FH_InApply = 1
    local db = FH_GetDB()
    if db then
        local desired = FH_DeterminePage()
        if desired ~= nil then
            FH_QueuePage(desired)
        end
    end
    FH_InApply = nil
end

function FH_Status()
    local db = FH_GetDB()
    if db == nil then
        FH_Print("not ready yet")
        return
    end

    local current = CURRENT_ACTIONBAR_PAGE or 1
    local noTargetText = "friendly"
    if db.NoTargetMode == 2 then
        noTargetText = "hostile"
    elseif db.NoTargetMode == 3 then
        noTargetText = "current"
    end

    FH_Print("Status:")
    FH_Print("enabled: " .. db.Enabled)
    FH_Print("friendly: " .. db.PageFriendly)
    FH_Print("hostile: " .. db.PageHostile)
    FH_Print("no target: " .. noTargetText)
    FH_Print("stored: " .. db.StoredPage)
    FH_Print("current: " .. current)
end

function FH_Help()
    FH_Print("FriendHostile commands:")
    FH_Print("/fh on|off")
    FH_Print("/fh no")
    FH_Print("/fh friendly <1-6>")
    FH_Print("/fh hostile <1-6>")
    FH_Print("/fh status")
end

function FH_SetPageFromCommand(kind, page)
    local db = FH_GetDB()
    if db == nil then
        FH_Print("not ready yet")
        return
    end

    if page ~= nil and page >= 1 and page <= 6 then
        if kind == "friendly" then
            db.PageFriendly = page
            FH_Print("friendly: " .. page)
        elseif kind == "hostile" then
            db.PageHostile = page
            FH_Print("hostile: " .. page)
        end
        FH_Apply()
    else
        FH_Print("page must be 1-6")
    end
end

function FH_SetNoTargetMode(value)
    local db = FH_GetDB()
    if db == nil then
        FH_Print("not ready yet")
        return
    end

    if value == 1 then
        db.NoTargetMode = 1
        FH_Print("no target: friendly")
    elseif value == 2 then
        db.NoTargetMode = 2
        FH_Print("no target: hostile")
    elseif value == 3 then
        FH_SaveCurrentPage(db)
        db.NoTargetMode = 3
        FH_Print("no target: current")
    else
        db.NoTargetMode = 1
        FH_Print("no target: friendly")
    end

    FH_Apply()
end

function FH_ToggleEnabled()
    local db = FH_GetDB()
    if db == nil then
        FH_Print("not ready yet")
        return
    end

    if db.Enabled == 1 then
        db.Enabled = 0
        FH_Print("enabled: 0")
        FH_QueuePage(db.PageFriendly)
    else
        db.Enabled = 1
        FH_Print("enabled: 1")
        FH_Apply()
    end
end

function FH_SlashCommand(msg)
    if msg == nil then
        msg = ""
    end

    local db = FH_GetDB()
    if db == nil then
        FH_Print("not ready yet")
        return
    end

    local command = string.lower(msg)

    if command == "" or command == "help" then
        FH_Help()

    elseif command == "status" then
        FH_Status()

    elseif command == "on" or command == "off" or command == "enable" or command == "disable" then
        FH_ToggleEnabled()

    elseif command == "no" then
        if db.NoTargetMode == 1 then
            FH_SetNoTargetMode(2)
        elseif db.NoTargetMode == 2 then
            FH_SetNoTargetMode(3)
        else
            FH_SetNoTargetMode(1)
        end

    elseif string.find(command, "^friendly%s+%d+$") then
        local page = nil
        for w in string.gfind(command, "%d+") do
            page = tonumber(w)
        end
        FH_SetPageFromCommand("friendly", page)

    elseif string.find(command, "^hostile%s+%d+$") then
        local page = nil
        for w in string.gfind(command, "%d+") do
            page = tonumber(w)
        end
        FH_SetPageFromCommand("hostile", page)

    else
        FH_Help()
    end
end

function FH_Init()
    FH_GetDB()
    FH_Frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    FH_Frame:RegisterEvent("PLAYER_LOGOUT")
    FH_Initialized = 1
    FH_LoggingOut = nil
    FH_Apply()
end

function FH_OnEvent(event)
    if event == "PLAYER_TARGET_CHANGED" then
        FH_Apply()
    elseif event == "PLAYER_LOGOUT" then
        FH_LoggingOut = 1
        FH_PendingPage = nil
        FH_PendingDelay = 0
    end
end

function FH_Update(elapsed)
    if not FH_Done then
        return
    end

    if not FH_Initialized then
        FH_Init()
    end
end

SLASH_FRIENDHOSTILE1 = "/fh"
SlashCmdList["FRIENDHOSTILE"] = FH_SlashCommand
