local ADDON_NAME = "Forged_PetHappiness"
local Addon = ForgedPetHappiness or {}
ForgedPetHappiness = Addon

local DEFAULTS = Addon.DEFAULTS
if type(DEFAULTS) ~= "table" then
    DEFAULTS = {
        point = "CENTER",
        x = 0,
        y = -180,
        width = 220,
        height = 16,
        locked = false,
        hidden = false,
        value = 100
    }
    Addon.DEFAULTS = DEFAULTS
end

local Clamp = Addon.Clamp
if type(Clamp) ~= "function" then
    Clamp = function(value, minVal, maxVal)
        if value < minVal then
            return minVal
        elseif value > maxVal then
            return maxVal
        end
        return value
    end
    Addon.Clamp = Clamp
end

local GetPetDietTooltipText = Addon.GetPetDietTooltipText
if type(GetPetDietTooltipText) ~= "function" then
    GetPetDietTooltipText = function()
        if not UnitExists("pet") then
            return "No active pet"
        end
        return "Unknown"
    end
    Addon.GetPetDietTooltipText = GetPetDietTooltipText
end

local mainframe = CreateFrame("Frame", "ForgedPetHappinessFrame", UIParent)
local happinessBarFrame
local happinessBar
local happinessBarText
local petXpBarFrame
local petXpBar
local petXpBarText
local petInfoText
local loyaltyInfoText
local petTrainingPointsLabelText
local petTrainingPointsText
local petDietIconFrame
local petDietIconTexture
local helpIconFrame
local helpIconTexture

local happinessValue = 0
local hasPet = false
local initialized = false
local db
local backupDb
local feedEffectText
local feedEffectActive = false
local feedEffectSwapInterval = 1
local feedEffectStartedAt = 0
local FirstPatternCapture
local IsFeedEffectFadeMessage
local GetCurrentHappinessBarText
local UpdateHappinessBarText
local UpdateVisual

local function GetCharacterKey()
    local playerName = UnitName and UnitName("player") or nil
    if not playerName or playerName == "" then
        return nil
    end

    local realmName = GetRealmName and GetRealmName() or "UnknownRealm"
    return realmName .. ":" .. playerName
end

local function SyncBackupDb()
    if not db or not backupDb then
        return
    end

    for key, _ in pairs(DEFAULTS) do
        backupDb[key] = db[key]
    end
end

local function SavePosition()
    local point, _, _, x, y = mainframe:GetPoint(1)
    db.point = point
    db.x = x
    db.y = y
    SyncBackupDb()
end

function ForgedPetHappiness_Print(message)
    if type(message) ~= "string" then
        message = tostring(message)
    end

    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    elseif ChatFrame1 and ChatFrame1.AddMessage then
        ChatFrame1:AddMessage(message)
    end
end

local function ApplyPosition()
    mainframe:ClearAllPoints()
    mainframe:SetPoint(db.point, UIParent, db.point, db.x, db.y)
end

local function UpdateBarColor()
    if happinessValue == 3 then
        happinessBar:SetStatusBarColor(0.2, 0.8, 0.2)
    elseif happinessValue == 2 then
        happinessBar:SetStatusBarColor(0.9, 0.75, 0.2)
    elseif happinessValue == 1 then
        happinessBar:SetStatusBarColor(0.9, 0.2, 0.2)
    else
        happinessBar:SetStatusBarColor(0.4, 0.4, 0.4)
    end
end

local function ClearFeedEffectOverride()
    feedEffectText = nil
    feedEffectActive = false
    feedEffectStartedAt = 0
end

local function SetFeedEffectOverride(effectText)
    if type(effectText) ~= "string" or effectText == "" then
        return
    end

    feedEffectText = effectText
    feedEffectActive = true
    if GetTime then
        local now = GetTime()
        if type(now) == "number" then
            feedEffectStartedAt = now
        else
            feedEffectStartedAt = 0
        end
    else
        feedEffectStartedAt = 0
    end
end

local function GetFeedEffectOverride()
    if not feedEffectActive or type(feedEffectText) ~= "string" or feedEffectText == "" then
        return nil
    end

    return feedEffectText
end

local function NormalizeFeedEffectAmount(rawAmount)
    local amount = tonumber(rawAmount)
    if type(amount) ~= "number" or amount == 0 then
        return nil
    end

    if amount > 0 then
        return string.format("+%d", amount)
    end

    return string.format("%d", amount)
end

local function ExtractFeedEffectAmount(message)
    if type(message) ~= "string" or message == "" then
        return nil
    end

    local directFeedEffectAmount = FirstPatternCapture(message,
        "gains%s+([%+%-]?%d+)%s+Happin+e?s?s?%s+from%s+Feed%s+Pet%s+Effect%.?")
    if directFeedEffectAmount then
        return NormalizeFeedEffectAmount(directFeedEffectAmount)
    end

    local messageLower = string.lower(message)
    local mentionsPet = string.find(messageLower, "pet", 1, true) ~= nil
    local mentionsFeeding = string.find(messageLower, "feed", 1, true) ~= nil or
        string.find(messageLower, "eat", 1, true) ~= nil or
        string.find(messageLower, "happiness", 1, true) ~= nil or
        string.find(messageLower, "happinness", 1, true) ~= nil

    if not mentionsPet or not mentionsFeeding then
        return nil
    end

    local signedAmount = FirstPatternCapture(message, "([+-]%d+)")
    if signedAmount then
        return NormalizeFeedEffectAmount(signedAmount)
    end

    local unsignedAmount = FirstPatternCapture(message, "(%d+)")
    if unsignedAmount then
        return NormalizeFeedEffectAmount(unsignedAmount)
    end

    return nil
end

IsFeedEffectFadeMessage = function(message)
    if type(message) ~= "string" or message == "" then
        return false
    end

    local messageLower = string.lower(message)
    return string.find(messageLower, "feed pet effect fades", 1, true) ~= nil or
        string.find(messageLower, "feed pet effect fades from", 1, true) ~= nil
end

local function HandleFeedEffectChatMessage(message)
    if IsFeedEffectFadeMessage(message) then
        ClearFeedEffectOverride()
        UpdateHappinessBarText()
        return
    end

    local effectAmount = ExtractFeedEffectAmount(message)
    if not effectAmount then
        return
    end

    SetFeedEffectOverride(string.format("%s Feed Pet Effect", effectAmount))
    UpdateHappinessBarText()
end

FirstPatternCapture = function(text, pattern)
    if type(text) ~= "string" then
        return nil
    end

    if string.match then
        return string.match(text, pattern)
    end

    local _, _, captured = string.find(text, pattern)
    return captured
end

local function ForEachPatternCapture(text, pattern, callback)
    if type(text) ~= "string" then
        return
    end

    if string.gmatch then
        for captured in string.gmatch(text, pattern) do
            callback(captured)
        end
        return
    end

    if string.gfind then
        for captured in string.gfind(text, pattern) do
            callback(captured)
        end
        return
    end

    local startIndex = 1
    while true do
        local startPos, endPos, captured = string.find(text, pattern, startIndex)
        if not startPos then
            break
        end
        callback(captured)
        if endPos < startIndex then
            startIndex = startIndex + 1
        else
            startIndex = endPos + 1
        end
    end
end

local function NormalizeTrainingPointsValue(value)
    local numberValue = tonumber(value)
    if type(numberValue) ~= "number" and type(value) == "string" then
        local extracted = FirstPatternCapture(value, "([-+]?%d+)")
        if extracted then
            numberValue = tonumber(extracted)
        end
    end

    if type(numberValue) ~= "number" then
        return nil
    end

    if numberValue > 32767 and numberValue <= 65535 then
        numberValue = numberValue - 65536
    end

    if numberValue > 2147483647 then
        numberValue = math.fmod(numberValue, 4294967296)
        if numberValue > 2147483647 then
            numberValue = numberValue - 4294967296
        end
    elseif numberValue < -2147483648 then
        numberValue = math.fmod(numberValue, 4294967296)
        if numberValue < -2147483648 then
            numberValue = numberValue + 4294967296
        end
    end

    return numberValue
end

local function ExtractNonNegativeFromRawValue(value)
    if type(value) == "number" then
        if value >= 0 and value <= 10000 then
            return value
        end
        return nil
    end

    if type(value) ~= "string" then
        return nil
    end

    local bestCandidate = nil
    ForEachPatternCapture(value, "([-+]?%d+)", function(token)
        local candidate = tonumber(token)
        if type(candidate) == "number" and candidate >= 0 and candidate <= 10000 then
            if bestCandidate == nil or candidate < bestCandidate then
                bestCandidate = candidate
            end
        end
    end)

    return bestCandidate
end

local function GetTrainingPointsFromUiText()
    if not PetTrainingPointText or not PetTrainingPointText.GetText then
        return nil
    end

    local uiText = PetTrainingPointText:GetText()
    if type(uiText) ~= "string" or uiText == "" then
        return nil
    end

    local extracted = FirstPatternCapture(uiText, "([-+]?%d+)")
    if not extracted then
        return nil
    end

    local value = tonumber(extracted)
    if type(value) ~= "number" then
        return nil
    end

    return value
end

local ResolveTrainingPointsValue

local function ResolveNonNegativeTrainingPointsFallback(primaryValue, secondaryValue)
    local primaryFallback = ExtractNonNegativeFromRawValue(primaryValue)
    if type(primaryFallback) == "number" then
        return primaryFallback
    end

    local secondaryFallback = ExtractNonNegativeFromRawValue(secondaryValue)
    if type(secondaryFallback) == "number" then
        return secondaryFallback
    end

    return nil
end

local function ResolveCurrentTrainingPoints()
    local petTrainingPoints = nil

    if GetPetTrainingPoints then
        local petTrainingPointsPrimary, petTrainingPointsSecondary = GetPetTrainingPoints()
        petTrainingPoints = ResolveTrainingPointsValue(petTrainingPointsPrimary, petTrainingPointsSecondary)
    end

    if petTrainingPoints == nil or petTrainingPoints == -1 then
        local uiTrainingPoints = GetTrainingPointsFromUiText()
        if type(uiTrainingPoints) == "number" then
            petTrainingPoints = uiTrainingPoints
        end
    end

    return petTrainingPoints
end

local function UpdateTrainingPointsDisplay(petTrainingPoints)
    if type(petTrainingPoints) == "number" then
        petTrainingPointsLabelText:SetText("TP")
        petTrainingPointsLabelText:SetTextColor(1, 1, 1)
        petTrainingPointsText:SetText(string.format("%d", petTrainingPoints))

        if petTrainingPoints < 0 then
            petTrainingPointsText:SetTextColor(1, 0.2, 0.2)
        elseif petTrainingPoints == 0 then
            petTrainingPointsText:SetTextColor(1, 1, 1)
        else
            petTrainingPointsText:SetTextColor(0.2, 0.9, 0.2)
        end
    else
        petTrainingPointsLabelText:SetText("TP")
        petTrainingPointsLabelText:SetTextColor(1, 1, 1)
        petTrainingPointsText:SetText("N/A")
        petTrainingPointsText:SetTextColor(1, 1, 1)
    end
end

ResolveTrainingPointsValue = function(primaryValue, secondaryValue)
    local primaryRaw = tonumber(primaryValue)
    local secondaryRaw = tonumber(secondaryValue)
    local primaryNumber = NormalizeTrainingPointsValue(primaryValue)
    local secondaryNumber = NormalizeTrainingPointsValue(secondaryValue)

    local primaryWasWrappedMax = (primaryRaw == 65535 or primaryRaw == 4294967295)
    local secondaryWasWrappedMax = (secondaryRaw == 65535 or secondaryRaw == 4294967295)

    if type(primaryNumber) == "number" and type(secondaryNumber) == "number" then
        if primaryWasWrappedMax and primaryNumber == -1 and secondaryNumber >= 0 then
            return secondaryNumber
        end

        if secondaryWasWrappedMax and secondaryNumber == -1 and primaryNumber >= 0 then
            return primaryNumber
        end

        if primaryNumber == -1 and secondaryNumber >= 0 then
            return secondaryNumber
        end

        if secondaryNumber == -1 and primaryNumber >= 0 then
            return primaryNumber
        end

        if math.abs(primaryNumber) > 10000 and math.abs(secondaryNumber) <= 10000 then
            return secondaryNumber
        end

        if math.abs(secondaryNumber) > 10000 and math.abs(primaryNumber) <= 10000 then
            return primaryNumber
        end

        if primaryNumber >= 0 and secondaryNumber >= 0 then
            local minValue = math.min(primaryNumber, secondaryNumber)
            local maxValue = math.max(primaryNumber, secondaryNumber)

            if maxValue >= (minValue * 10) and (maxValue - minValue) >= 100 then
                return minValue
            end
        end

        if primaryNumber < 0 then
            return primaryNumber
        end

        if secondaryNumber < 0 then
            local fallback = ResolveNonNegativeTrainingPointsFallback(primaryValue, secondaryValue)
            if type(fallback) == "number" then
                return fallback
            end
            if secondaryNumber == -1 then
                return nil
            end
            return secondaryNumber
        end

        if primaryNumber == -1 then
            local fallback = ResolveNonNegativeTrainingPointsFallback(primaryValue, secondaryValue)
            if type(fallback) == "number" then
                return fallback
            end
            return nil
        end

        return primaryNumber
    end

    if type(primaryNumber) == "number" then
        if math.abs(primaryNumber) > 10000 then
            return nil
        end
        if primaryNumber == -1 then
            local fallback = ResolveNonNegativeTrainingPointsFallback(primaryValue, secondaryValue)
            if type(fallback) == "number" then
                return fallback
            end
            return nil
        end
        return primaryNumber
    end

    if type(secondaryNumber) == "number" then
        if math.abs(secondaryNumber) > 10000 then
            return nil
        end
        if secondaryNumber == -1 then
            local fallback = ResolveNonNegativeTrainingPointsFallback(primaryValue, secondaryValue)
            if type(fallback) == "number" then
                return fallback
            end
            return nil
        end
        return secondaryNumber
    end

    return nil
end

GetCurrentHappinessBarText = function(state, stateText)
    local activeFeedEffectText = GetFeedEffectOverride()
    if activeFeedEffectText then
        if GetTime then
            local now = GetTime()
            if type(now) == "number" then
                local elapsed = now - (feedEffectStartedAt or 0)
                if elapsed < 0 then
                    elapsed = 0
                end

                local phase = math.floor(elapsed / feedEffectSwapInterval)
                if math.mod(phase, 2) == 0 then
                    return activeFeedEffectText
                end
            end
        else
            return activeFeedEffectText
        end
    end

    if state == 1 or state == 2 or state == 3 then
        return string.format("Happiness (%s)", stateText)
    end

    return "Happiness N/A"
end

UpdateHappinessBarText = function()
    if not happinessBarText then
        return
    end

    local state = happinessValue
    local stateText = "No Pet"
    if state == 3 then
        stateText = "Happy"
    elseif state == 2 then
        stateText = "Content"
    elseif state == 1 then
        stateText = "Unhappy"
    end

    happinessBarText:SetText(GetCurrentHappinessBarText(state, stateText))
end

UpdateVisual = function()
    if not happinessBar or not happinessBarText or not petXpBar or not petXpBarText or not petInfoText or
        not loyaltyInfoText or not petTrainingPointsLabelText or not petTrainingPointsText then
        return
    end

    happinessBar:SetValue(happinessValue)
    UpdateBarColor()

    if petDietIconFrame then
        if UnitExists("pet") then
            petDietIconFrame:Show()
        else
            petDietIconFrame:Hide()
        end
    end

    local state = happinessValue

    if UnitExists("pet") then
        local petLevel = UnitLevel("pet")
        local playerLevel = UnitLevel("player")
        local petFamily = UnitCreatureFamily and UnitCreatureFamily("pet") or nil
        local petName = UnitName and UnitName("pet") or nil
        local petXP, petXPMax = nil, nil
        local petTrainingPoints = nil
        local loyaltyLevelRaw, loyaltyNameRaw = nil, nil
        local loyaltyLevel = nil
        local loyaltyName = nil

        if GetPetLoyalty then
            loyaltyLevelRaw, loyaltyNameRaw = GetPetLoyalty()
        end

        if GetPetExperience then
            petXP, petXPMax = GetPetExperience()
        end

        petTrainingPoints = ResolveCurrentTrainingPoints()

        if type(loyaltyLevelRaw) == "number" then
            loyaltyLevel = loyaltyLevelRaw
            loyaltyName = loyaltyNameRaw
        elseif type(loyaltyNameRaw) == "number" then
            loyaltyLevel = loyaltyNameRaw
            loyaltyName = loyaltyLevelRaw
        else
            loyaltyLevel = tonumber(loyaltyLevelRaw) or tonumber(loyaltyNameRaw)
            loyaltyName = loyaltyNameRaw or loyaltyLevelRaw
        end

        if loyaltyName and type(loyaltyName) ~= "string" then
            loyaltyName = tostring(loyaltyName)
        end

        if not petFamily or petFamily == "" then
            petFamily = "Unknown"
        end

        local petNameSuffix = ""
        local hasCustomName = false
        if petName and petName ~= "" then
            local petNameLower = string.lower(petName)
            local isUnknownName = (petNameLower == "unknown")
            if not isUnknownName then
                if petFamily and petFamily ~= "" then
                    hasCustomName = petNameLower ~= string.lower(petFamily)
                else
                    hasCustomName = true
                end
            else
                hasCustomName = false
            end
        end

        if hasCustomName then
            petNameSuffix = string.format(" (%s)", petName)
        end

        if petLevel and petLevel > 0 then
            petInfoText:SetText(string.format("Level %d %s%s", petLevel, petFamily, petNameSuffix))
        else
            petInfoText:SetText(string.format("Level ? %s%s", petFamily, petNameSuffix))
        end

        if loyaltyLevel and loyaltyName and loyaltyName ~= "" then
            loyaltyInfoText:SetText(string.format("Loyalty Level %d (%s)", loyaltyLevel, loyaltyName))
        elseif loyaltyLevel then
            loyaltyInfoText:SetText(string.format("Loyalty Level %d", loyaltyLevel))
        elseif loyaltyName and loyaltyName ~= "" then
            loyaltyInfoText:SetText(string.format("%s", loyaltyName))
        else
            loyaltyInfoText:SetText("(Loyalty Unknown)")
        end

        UpdateTrainingPointsDisplay(petTrainingPoints)

        if petXP and petXPMax and petXPMax > 0 then
            petXpBar:SetMinMaxValues(0, petXPMax)
            petXpBar:SetValue(petXP)
            petXpBarText:SetText(string.format("XP %d/%d", petXP, petXPMax))
        else
            petXpBar:SetMinMaxValues(0, 100)
            petXpBar:SetValue(0)
            petXpBarText:SetText("XP N/A")
        end

        if type(petLevel) == "number" and type(playerLevel) == "number" and petLevel == playerLevel then
            petXpBarText:SetText("Max Level")
        end
    else
        petInfoText:SetText("No active pet")
        loyaltyInfoText:SetText("")
        petTrainingPointsLabelText:SetText("")
        petTrainingPointsText:SetText("")
        petXpBar:SetMinMaxValues(0, 100)
        petXpBar:SetValue(0)
        petXpBarText:SetText("XP N/A")
    end

    UpdateHappinessBarText()
end

local function SyncToGameState(forceSnap)
    if not happinessBar or not happinessBarText then
        return
    end

    hasPet = UnitExists("pet") and true or false
    if db and db.hidden then
        mainframe:Hide()
    else
        mainframe:Show()
    end

    if not hasPet then
        happinessValue = 0
        ClearFeedEffectOverride()
        UpdateVisual()
        return
    end

    local state = GetPetHappiness and GetPetHappiness() or nil
    if state == 1 or state == 2 or state == 3 then
        happinessValue = state
    else
        happinessValue = 0
    end

    UpdateVisual()
end

local function ToggleLock(locked)
    db.locked = locked
    SyncBackupDb()
    -- Keep mouse enabled so icon buttons remain clickable even while locked.
    mainframe:EnableMouse(true)

    if locked then
        happinessBarText:SetTextColor(1, 1, 1)
        if petXpBarText then
            petXpBarText:SetTextColor(1, 1, 1)
        end
        if petInfoText then
            petInfoText:SetTextColor(1, 0.82, 0)
        end
        if loyaltyInfoText then
            loyaltyInfoText:SetTextColor(1, 1, 1)
        end
    else
        happinessBarText:SetTextColor(0.8, 0.95, 1)
        if petXpBarText then
            petXpBarText:SetTextColor(0.8, 0.95, 1)
        end
        if petInfoText then
            petInfoText:SetTextColor(1, 0.82, 0)
        end
        if loyaltyInfoText then
            loyaltyInfoText:SetTextColor(0.8, 0.95, 1)
        end
    end
end

local function OpenPetInfoTab()
    if not UnitExists("pet") then
        ForgedPetHappiness_Print("Forged Pet Happiness: no active pet to show.")
        return
    end

    if ToggleCharacter then
        ToggleCharacter("PetPaperDollFrame")
    end

    if CharacterFrame then
        if ShowUIPanel then
            ShowUIPanel(CharacterFrame)
        else
            CharacterFrame:Show()
        end
    end

    if CharacterFrame_ShowSubFrame then
        CharacterFrame_ShowSubFrame("PetPaperDollFrame")
    end

    if CharacterFrameTab2 and CharacterFrameTab2.Click then
        CharacterFrameTab2:Click()
    elseif CharacterFrameTab3 and CharacterFrameTab3.Click then
        CharacterFrameTab3:Click()
    elseif CharacterFrameTab4 and CharacterFrameTab4.Click then
        CharacterFrameTab4:Click()
    end

    if not CharacterFrame_ShowSubFrame and not CharacterFrameTab2 then
        ForgedPetHappiness_Print("Forged Pet Happiness: unable to open pet tab on this client.")
    end
end

local function HandleHelpIconClick(button)
    if button and button ~= "LeftButton" then
        return
    end

    OpenPetInfoTab()

    if GameTooltip and helpIconFrame and GameTooltip:IsOwned(helpIconFrame) then
        GameTooltip:Hide()
    end
end

local function InitializeAddon()
    if initialized then
        return
    end

    if not ForgedPetHappinessCharDB then
        ForgedPetHappinessCharDB = {}
    end

    if not ForgedPetHappinessDB then
        ForgedPetHappinessDB = {}
    end

    db = ForgedPetHappinessCharDB

    local characterKey = GetCharacterKey()
    if characterKey then
        if type(ForgedPetHappinessDB.characters) ~= "table" then
            ForgedPetHappinessDB.characters = {}
        end
        if type(ForgedPetHappinessDB.characters[characterKey]) ~= "table" then
            ForgedPetHappinessDB.characters[characterKey] = {}
        end
        backupDb = ForgedPetHappinessDB.characters[characterKey]
    end

    if next(db) == nil and backupDb and next(backupDb) ~= nil then
        for key, _ in pairs(DEFAULTS) do
            if backupDb[key] ~= nil then
                db[key] = backupDb[key]
            end
        end
    end

    if next(db) == nil and ForgedPetHappinessDB then
        for key, value in pairs(DEFAULTS) do
            if ForgedPetHappinessDB[key] ~= nil then
                db[key] = ForgedPetHappinessDB[key]
            end
        end
    end

    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then
            db[key] = value
        end
    end

    SyncBackupDb()

    mainframe:SetWidth(db.width)
    mainframe:SetHeight(db.height + 76)
    mainframe:SetFrameStrata("MEDIUM")

    happinessBarFrame = CreateFrame("Frame", nil, mainframe)
    happinessBarFrame:SetParent(mainframe)
    happinessBarFrame:SetPoint("TOPLEFT", mainframe, "TOPLEFT", 6, -40)
    happinessBarFrame:SetWidth(db.width - 12)
    happinessBarFrame:SetHeight(db.height + 5)

    happinessBarFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = {
            left = 2,
            right = 2,
            top = 2,
            bottom = 2
        }
    })
    happinessBarFrame:SetBackdropColor(0, 0, 0, 0.5)
    happinessBarFrame:SetBackdropBorderColor(.7, .7, .7, 1)

    happinessBar = CreateFrame("StatusBar", nil, happinessBarFrame)
    happinessBar:SetParent(happinessBarFrame)
    happinessBar:SetPoint("TOPLEFT", happinessBarFrame, "TOPLEFT", 3, -4)
    happinessBar:SetPoint("TOPRIGHT", happinessBarFrame, "TOPRIGHT", -4, 0)
    happinessBar:SetHeight(13)
    happinessBar:SetMinMaxValues(0, 3)
    happinessBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

    happinessBar.bg = happinessBar:CreateTexture(nil, "BACKGROUND")
    happinessBar.bg:SetAllPoints(happinessBar)
    happinessBar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    happinessBar.bg:SetVertexColor(0.15, 0.15, 0.15, 0.9)

    happinessBarText = happinessBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    happinessBarText:SetParent(happinessBar)
    happinessBarText:SetPoint("CENTER", happinessBar, "CENTER", 0, 1)
    happinessBarText:SetJustifyH("CENTER")

    petXpBarFrame = CreateFrame("Frame", nil, mainframe)
    petXpBarFrame:SetParent(mainframe)
    petXpBarFrame:SetPoint("TOPLEFT", mainframe, "TOPLEFT", 6, -62)
    petXpBarFrame:SetWidth(db.width - 12)
    petXpBarFrame:SetHeight(db.height + 5)
    petXpBarFrame:SetBackdropBorderColor(.7, .7, .7, 1)

    petXpBarFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = {
            left = 2,
            right = 2,
            top = 2,
            bottom = 2
        }
    })
    petXpBarFrame:SetBackdropColor(0, 0, 0, 0.5)

    petXpBar = CreateFrame("StatusBar", nil, petXpBarFrame)
    petXpBar:SetParent(petXpBarFrame)
    petXpBar:SetPoint("TOPLEFT", petXpBarFrame, "TOPLEFT", 3, -4)
    petXpBar:SetPoint("TOPRIGHT", petXpBarFrame, "TOPRIGHT", -4, 0)
    petXpBar:SetHeight(13)
    petXpBar:SetMinMaxValues(0, 100)
    petXpBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    petXpBar:SetStatusBarColor(0.25, 0.45, 0.9)

    petXpBar.bg = petXpBar:CreateTexture(nil, "BACKGROUND")
    petXpBar.bg:SetAllPoints(petXpBar)
    petXpBar.bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    petXpBar.bg:SetVertexColor(0.15, 0.15, 0.15, 0.9)

    petXpBarText = petXpBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    petXpBarText:SetParent(petXpBar)
    petXpBarText:SetPoint("CENTER", petXpBar, "CENTER", 0, 1)
    petXpBarText:SetJustifyH("CENTER")
    petXpBarText:SetText("XP N/A")

    petInfoText = mainframe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    petInfoText:SetPoint("TOPLEFT", mainframe, "TOPLEFT", 8, -9)
    petInfoText:SetJustifyH("LEFT")
    petInfoText:SetText("No active pet")

    loyaltyInfoText = mainframe:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    loyaltyInfoText:SetPoint("TOPLEFT", mainframe, "TOPLEFT", 8, -25)
    loyaltyInfoText:SetJustifyH("CENTER")
    loyaltyInfoText:SetText("")

    petTrainingPointsLabelText = mainframe:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    petTrainingPointsLabelText:SetJustifyH("RIGHT")
    petTrainingPointsLabelText:SetText("")

    petTrainingPointsText = mainframe:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    petTrainingPointsText:SetPoint("TOPRIGHT", mainframe, "TOPRIGHT", -8, -26)
    petTrainingPointsText:SetJustifyH("RIGHT")
    petTrainingPointsText:SetText("")

    petTrainingPointsLabelText:SetPoint("RIGHT", petTrainingPointsText, "LEFT", -3, 0)

    petDietIconFrame = CreateFrame("Frame", nil, mainframe)
    petDietIconFrame:SetPoint("TOPRIGHT", mainframe, "TOPRIGHT", -27, -8)
    petDietIconFrame:SetWidth(16)
    petDietIconFrame:SetHeight(16)
    petDietIconFrame:SetFrameStrata(mainframe:GetFrameStrata())
    petDietIconFrame:SetFrameLevel(mainframe:GetFrameLevel() + 1)
    petDietIconFrame:EnableMouse(true)

    petDietIconFrame:SetScript("OnEnter", function()
        if not GameTooltip then
            return
        end

        GameTooltip:SetOwner(petDietIconFrame, "ANCHOR_RIGHT")
        GameTooltip:SetText("Pet diet")
        GameTooltip:AddLine(GetPetDietTooltipText(), 1, 1, 1, true)
        GameTooltip:Show()
    end)

    petDietIconFrame:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    petDietIconTexture = petDietIconFrame:CreateTexture(nil, "OVERLAY")
    petDietIconTexture:SetAllPoints(petDietIconFrame)
    petDietIconTexture:SetTexture("Interface\\Icons\\INV_Misc_Food_15")
    petDietIconFrame:Show()

    helpIconFrame = CreateFrame("Button", nil, mainframe)
    helpIconFrame:SetPoint("TOPRIGHT", mainframe, "TOPRIGHT", -7, -8)
    helpIconFrame:SetWidth(16)
    helpIconFrame:SetHeight(16)
    helpIconFrame:SetFrameStrata(mainframe:GetFrameStrata())
    helpIconFrame:SetFrameLevel(mainframe:GetFrameLevel() + 1)
    helpIconFrame:EnableMouse(true)
    helpIconFrame:RegisterForClicks("AnyUp", "AnyDown")

    helpIconFrame:SetScript("OnEnter", function()
        if not GameTooltip then
            return
        end

        GameTooltip:SetOwner(helpIconFrame, "ANCHOR_RIGHT")
        GameTooltip:SetText("Help")
        GameTooltip:AddLine("Left-click: open character pet tab", 0.8, 0.95, 1, true)
        GameTooltip:AddLine("/fph [lock, unlock, reset, hide, show, pet]", 1, 1, 1, true)
        GameTooltip:Show()
    end)

    helpIconFrame:SetScript("OnClick", function(_, button)
        HandleHelpIconClick(button)
    end)

    helpIconFrame:SetScript("OnMouseUp", function(_, button)
        HandleHelpIconClick(button)
    end)

    helpIconFrame:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    helpIconTexture = helpIconFrame:CreateTexture(nil, "OVERLAY")
    helpIconTexture:SetAllPoints(helpIconFrame)
    helpIconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    helpIconFrame:Show()

    mainframe:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {
            left = 2,
            right = 2,
            top = 2,
            bottom = 2
        }
    })
    mainframe:SetBackdropColor(0, 0, 0, 0.5)
    mainframe:SetBackdropBorderColor(.7, .7, .7, 1)

    mainframe:RegisterForDrag("LeftButton")
    mainframe:SetMovable(true)
    mainframe:SetClampedToScreen(true)
    mainframe:SetScript("OnDragStart", function()
        if not db.locked then
            mainframe:StartMoving()
        end
    end)
    mainframe:SetScript("OnDragStop", function()
        mainframe:StopMovingOrSizing()
        SavePosition()
    end)
    mainframe:SetScript("OnUpdate", function()
        if feedEffectActive then
            UpdateHappinessBarText()
        end
    end)

    ApplyPosition()
    if db.hidden then
        mainframe:Hide()
    else
        mainframe:Show()
    end
    happinessValue = Clamp(db.value or 0, 0, 3)
    ToggleLock(db.locked)

    SLASH_ForgedPetHAPPINESS1 = "/fph"
    SlashCmdList.ForgedPetHAPPINESS = function(msg)
        local input = string.lower(string.gsub(msg or "", "^%s*(.-)%s*$", "%1"))

        if input == "lock" then
            ToggleLock(true)
            ForgedPetHappiness_Print("Forged Pet Happiness: locked")
        elseif input == "unlock" then
            ToggleLock(false)
            ForgedPetHappiness_Print("Forged Pet Happiness: unlocked")
        elseif input == "reset" then
            db.point = DEFAULTS.point
            db.x = DEFAULTS.x
            db.y = DEFAULTS.y
            SyncBackupDb()
            ApplyPosition()
            ForgedPetHappiness_Print("Forged Pet Happiness: position reset")
        elseif input == "hide" then
            db.hidden = true
            SyncBackupDb()
            mainframe:Hide()
            ForgedPetHappiness_Print("Forged Pet Happiness: hidden")
        elseif input == "show" then
            db.hidden = false
            db.point = DEFAULTS.point
            db.x = DEFAULTS.x
            db.y = DEFAULTS.y
            SyncBackupDb()
            ApplyPosition()
            mainframe:Show()
            ForgedPetHappiness_Print("Forged Pet Happiness: shown at center")
        elseif input == "pet" then
            OpenPetInfoTab()
        else
            ForgedPetHappiness_Print("Forged Pet Happiness commands: /fph lock, /fph unlock, /fph reset, /fph hide, /fph show, /fph pet")
        end
    end

    initialized = true
    ForgedPetHappiness_Print("Forged Pet Happiness loaded. Type /fph show if the frame is off-screen.")
    SyncToGameState(true)
end

mainframe:SetScript("OnEvent", function(self, evt, a1)
    evt = evt or event
    a1 = a1 or arg1

    if evt == "ADDON_LOADED" then
        if a1 == ADDON_NAME or a1 == "Forged Pet Happiness" then
            InitializeAddon()
        end
    elseif evt == "PLAYER_LOGIN" then
        InitializeAddon()
        SyncToGameState(true)
    elseif evt == "PLAYER_ENTERING_WORLD" then
        SyncToGameState(false)
    elseif evt == "UNIT_HAPPINESS" then
        SyncToGameState(false)
    elseif evt == "UNIT_PET" and a1 == "player" then
        ClearFeedEffectOverride()
        SyncToGameState(true)
    elseif evt == "UNIT_PET_EXPERIENCE" then
        if not a1 or a1 == "pet" then
            SyncToGameState(false)
        end
    elseif evt == "PLAYER_XP_UPDATE" then
        SyncToGameState(false)
    elseif evt == "CHAT_MSG_COMBAT_XP_GAIN" then
        SyncToGameState(false)
    elseif evt == "CHAT_MSG_SYSTEM" or evt == "CHAT_MSG_SPELL_SELF_BUFF" or
        evt == "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF" or evt == "CHAT_MSG_SPELL_PET_DAMAGE" or
        evt == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS" or evt == "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS" or
        evt == "CHAT_MSG_SPELL_PERIODIC_PET_BUFFS" or evt == "CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS" or
        evt == "CHAT_MSG_SPELL_AURA_GONE_SELF" or evt == "CHAT_MSG_SPELL_AURA_GONE_PARTY" or
        evt == "CHAT_MSG_SPELL_AURA_GONE_OTHER" then
        HandleFeedEffectChatMessage(a1)
    elseif evt == "PET_BAR_UPDATE" or evt == "PET_UI_UPDATE" then
        SyncToGameState(false)
    end
end)

mainframe:RegisterEvent("ADDON_LOADED")
mainframe:RegisterEvent("PLAYER_LOGIN")
mainframe:RegisterEvent("PLAYER_ENTERING_WORLD")
mainframe:RegisterEvent("UNIT_HAPPINESS")
mainframe:RegisterEvent("UNIT_PET")
mainframe:RegisterEvent("UNIT_PET_EXPERIENCE")
mainframe:RegisterEvent("PLAYER_XP_UPDATE")
mainframe:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
mainframe:RegisterEvent("CHAT_MSG_SYSTEM")
mainframe:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
mainframe:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF")
mainframe:RegisterEvent("CHAT_MSG_SPELL_PET_DAMAGE")
mainframe:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")
mainframe:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS")
mainframe:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_PET_BUFFS")
mainframe:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS")
mainframe:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
mainframe:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_PARTY")
mainframe:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_OTHER")
mainframe:RegisterEvent("PET_BAR_UPDATE")
mainframe:RegisterEvent("PET_UI_UPDATE")

mainframe:SetScript("OnHide", function()
    if db then
        db.value = happinessValue
        SyncBackupDb()
    end
end)
