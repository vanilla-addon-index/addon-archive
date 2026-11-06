RANGEMELEE_VERSION = "3.4.0"

RANGEMELEE_RANGED_SLOT = 0
RANGEMELEE_RANGED_WEAPONS = { "Bow", "Crossbow", "Rifle" }
RANGEMELEE_INITIALIZED = nil

Fetch_PlayerInfo = nil
Fetch_Timer = 0
Fetch_Done = nil


function RangeMelee_Msg(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("RangeMelee: " .. message)
    end
end


function Fetch_UnitInit()
    local playerName = UnitName("player")

    if playerName == nil
    or playerName == "Unknown Entity"
    or playerName == UNKNOWNBEING
    or playerName == UNKNOWNOBJECT then
        return
    end

    Fetch_PlayerInfo = playerName .. " of " .. GetCVar("realmName")
    Fetch_Done = 1
end


function Fetch_OnUpdate(elapsed)
    Fetch_Timer = Fetch_Timer + elapsed

    if not Fetch_Done and Fetch_Timer > 0.2 then
        Fetch_UnitInit()
        Fetch_Timer = 0
    end
end


function RangeMelee_GetDB()
    if RangeMeleeSettings == nil then
        RangeMeleeSettings = {}
    end

    if Fetch_PlayerInfo == nil then
        return nil
    end

    if RangeMeleeSettings[Fetch_PlayerInfo] == nil then
        RangeMeleeSettings[Fetch_PlayerInfo] = {}
    end

    local db = RangeMeleeSettings[Fetch_PlayerInfo]

    if db.Enabled == nil then
        db.Enabled = 1
    end

    if db.PageDefault == nil then
        db.PageDefault = 1
    end

    if db.PageMelee == nil then
        db.PageMelee = 2
    end

    -- Range detection and ranged-slot detection are always automatic.
    -- These assignments also reset settings from older versions.
    db.AutoPageRange = 1
    db.Ranged_Slot = 0

    return db
end


function RangeMelee_IsRangedWeaponTexture(texture)
    if texture == nil then
        return false
    end

    for i = 1, getn(RANGEMELEE_RANGED_WEAPONS) do
        if string.find(texture, RANGEMELEE_RANGED_WEAPONS[i]) then
            return true
        end
    end

    return false
end


function RangeMelee_UpdateSlots()
    local db = RangeMelee_GetDB()

    if db == nil then
        return
    end

    -- Always use automatic detection.
    RANGEMELEE_RANGED_SLOT = 0

    for i = 1, 72 do
        local texture = GetActionTexture(i)

        if RangeMelee_IsRangedWeaponTexture(texture) then
            RANGEMELEE_RANGED_SLOT = i
            break
        end
    end
end


function RangeMelee_SetActionPage(page)
    if page == nil or page < 1 or page > 6 then
        page = 1
    end

    local currentPage = CURRENT_ACTIONBAR_PAGE or 1

    if currentPage ~= page then
        CURRENT_ACTIONBAR_PAGE = page
        ChangeActionBarPage()
    end
end


function RangeMelee_HasValidTarget()
    if not UnitExists("target") then
        return false
    end

    if not UnitCanAttack("player", "target") then
        return false
    end

    if UnitIsDead("target") then
        return false
    end

    return true
end


function RangeMelee_IsMeleeRange()
    if not RangeMelee_HasValidTarget() then
        return false
    end

    -- CheckInteractDistance index 3 is the melee-range test used
    -- by the original macros. Accept either 1 or true.
    if CheckInteractDistance("target", 3) then
        return true
    end

    return false
end


function RangeMelee_DeterminePage()
    local db = RangeMelee_GetDB()

    if db == nil then
        return 1
    end

    if db.Enabled == 0 then
        return db.PageDefault
    end

    if RangeMelee_IsMeleeRange() then
        return db.PageMelee
    end

    -- No valid target, target not in melee range, or an unknown
    -- distance all use the default page.
    return db.PageDefault
end


function RangeMelee_Apply()
    local desiredPage = RangeMelee_DeterminePage()

    if desiredPage == nil then
        desiredPage = 1
    end

    RangeMelee_SetActionPage(desiredPage)
end


function RangeMelee_RescanAndApply()
    RangeMelee_UpdateSlots()
    RangeMelee_Apply()
end


function RangeMelee_GetNumber(command)
    local number

    for value in string.gfind(command, "%d+") do
        number = tonumber(value)
    end

    return number
end


function RangeMelee_Status()
    local db = RangeMelee_GetDB()

    if db == nil then
        RangeMelee_Msg("not ready yet")
        return
    end

    local currentPage = CURRENT_ACTIONBAR_PAGE or 1
    local targetStatus = "no valid target"
    local rangeStatus = "not in melee range"

    if RangeMelee_HasValidTarget() then
        targetStatus = "valid hostile target"

        if RangeMelee_IsMeleeRange() then
            rangeStatus = "melee range"
        end
    end

    RangeMelee_Msg("Status:")
    RangeMelee_Msg("enabled: " .. db.Enabled)
    RangeMelee_Msg("target: " .. targetStatus)
    RangeMelee_Msg("range: " .. rangeStatus)
    RangeMelee_Msg("detected ranged slot: " .. RANGEMELEE_RANGED_SLOT)
    RangeMelee_Msg("current page: " .. currentPage)
    RangeMelee_Msg("default page: " .. db.PageDefault)
    RangeMelee_Msg("melee page: " .. db.PageMelee)
end


function RangeMelee_Help()
    RangeMelee_Msg("RangeMelee commands:")
    RangeMelee_Msg("/rm status - show current status")
    RangeMelee_Msg("/rm on - enable the addon")
    RangeMelee_Msg("/rm off - disable the addon")
    RangeMelee_Msg("/rm page default <1-6> - set default page")
    RangeMelee_Msg("/rm page melee <1-6> - set melee page")
    RangeMelee_Msg("")
    RangeMelee_Msg("Page 1: default, ranged, or no target")
    RangeMelee_Msg("Page 2: melee-range target")
    RangeMelee_Msg("Ranged-slot detection is automatic.")
end


function RangeMelee_SetPage(command, pageType)
    local db = RangeMelee_GetDB()
    local page = RangeMelee_GetNumber(command)

    if page == nil or page < 1 or page > 6 then
        RangeMelee_Msg("page must be a number from 1 to 6")
        return
    end

    if pageType == "default" then
        db.PageDefault = page
        RangeMelee_Msg("default page set to " .. page)

    elseif pageType == "melee" then
        db.PageMelee = page
        RangeMelee_Msg("melee page set to " .. page)
    end

    RangeMelee_RescanAndApply()
end


function RangeMelee_SlashCommand(message)
    if message == nil then
        message = ""
    end

    local db = RangeMelee_GetDB()

    if db == nil then
        RangeMelee_Msg("not ready yet")
        return
    end

    local command = string.lower(message)

    if command == "" or command == "help" then
        RangeMelee_Help()

    elseif command == "status" then
        RangeMelee_Status()

    elseif command == "on" or command == "enable" then
        db.Enabled = 1
        RangeMelee_Msg("enabled")
        RangeMelee_RescanAndApply()

    elseif command == "off" or command == "disable" then
        db.Enabled = 0
        RangeMelee_SetActionPage(db.PageDefault)
        RangeMelee_Msg("disabled")

    elseif string.find(command, "^page%s+default%s+%d+$") then
        RangeMelee_SetPage(command, "default")

    elseif string.find(command, "^page%s+melee%s+%d+$") then
        RangeMelee_SetPage(command, "melee")

    else
        RangeMelee_Help()
    end
end


function RangeMelee_Init()
    RangeMelee_GetDB()
    RangeMelee_UpdateSlots()

    this:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    this:RegisterEvent("PLAYER_TARGET_CHANGED")
    this:RegisterEvent("PLAYER_REGEN_DISABLED")
    this:RegisterEvent("PLAYER_REGEN_ENABLED")
    this:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
    this:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

    SLASH_RANGEMELEE1 = "/rm"
    SlashCmdList["RANGEMELEE"] = RangeMelee_SlashCommand

    RangeMelee_Msg("loaded")

    UIErrorsFrame:AddMessage(
        "RangeMelee AddOn loaded",
        1.0,
        1.0,
        1.0,
        1.0,
        UIERRORS_HOLD_TIME
    )

    RANGEMELEE_INITIALIZED = 1
end


function RangeMelee_OnEvent(event)
    if event == "ACTIONBAR_SLOT_CHANGED"
    or event == "PLAYER_TARGET_CHANGED"
    or event == "PLAYER_REGEN_DISABLED"
    or event == "PLAYER_REGEN_ENABLED"
    or event == "ACTIONBAR_PAGE_CHANGED"
    or event == "PLAYER_EQUIPMENT_CHANGED" then

        RangeMelee_RescanAndApply()
    end
end


function RangeMelee_Update(elapsed)
    if not Fetch_Done then
        return
    end

    if not RANGEMELEE_INITIALIZED then
        RangeMelee_Init()
        return
    end

    local db = RangeMelee_GetDB()

    if db == nil then
        return
    end

    if db.Enabled == 0 then
        return
    end

    RangeMelee_Apply()
end
