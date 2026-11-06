-- GUI.lua
-- Handles visual interface, manual slider inputs, and the utility interface.

local PAD = 20
local FRAME_W = 300
local LABEL_W = 40
local SLIDER_W = FRAME_W - PAD * 2 - LABEL_W - 4

-- Helper: Scans inventory for any fishing lure and returns total count
-- Cached lure count — only rescanned when inventory changes
local cachedLureCount = 0
local lureCountDirty = true

local function GetLureCount()
    if not lureCountDirty then return cachedLureCount end
    lureCountDirty = false
    local lures = { "Shiny Bauble", "Nightcrawlers", "Aquadynamic Fish Attractor", "Bright Baubles", "Fleshless Bone", "Aquadynamic Fish Lens" }
    local count = 0
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local name = FishingVolume.GetItemName(link)
                if name then
                    for _, lureName in pairs(lures) do
                        if name == lureName then
                            local _, qty = GetContainerItemInfo(bag, slot)
                            count = count + (qty or 1)
                        end
                    end
                end
            end
        end
    end
    cachedLureCount = count
    return count
end

-- Invalidate cache when inventory changes
local invWatcher = CreateFrame("Frame")
invWatcher:RegisterEvent("BAG_UPDATE")
invWatcher:SetScript("OnEvent", function() lureCountDirty = true end)

-- Helper: Calculates percentage safely and consistently
local function GetChestPercent(fish, chests)
    local total = fish + chests
    if total == 0 then return "0.0%" end
    return string.format("%.1f%%", (chests / total) * 100)
end

-- ================================================================
-- ZONE FISHING SKILL
-- ================================================================

-- Zone fishing data sourced from El's Extreme Angling (Vanilla 1.12.1)
-- min  = minimum skill to catch anything at all
-- full = skill required for 100% catch rate (no get-aways)
local ZONE_SKILL = {
    -- Tier 1a: min 1, 100% at 25
    ["Dun Morogh"]                = { min = 1,   full = 25  },
    ["Durotar"]                   = { min = 1,   full = 25  },
    ["Elwynn Forest"]             = { min = 1,   full = 25  },
    ["Mulgore"]                   = { min = 1,   full = 25  },
    ["Teldrassil"]                = { min = 1,   full = 25  },
    ["Tirisfal Glades"]           = { min = 1,   full = 25  },
    -- Tier 1b: min 1, 100% at 75
    ["The Barrens"]               = { min = 1,   full = 75  },
    ["Blackfathom Deeps"]         = { min = 1,   full = 75  },
    ["Darkshore"]                 = { min = 1,   full = 75  },
    ["Darnassus"]                 = { min = 1,   full = 75  },
    ["The Deadmines"]             = { min = 1,   full = 75  },
    ["Ironforge"]                 = { min = 1,   full = 75  },
    ["Loch Modan"]                = { min = 1,   full = 75  },
    ["Orgrimmar"]                 = { min = 1,   full = 75  },
    ["Silverpine Forest"]         = { min = 1,   full = 75  },
    ["Stormwind City"]            = { min = 1,   full = 75  },
    ["Thunder Bluff"]             = { min = 1,   full = 75  },
    ["Undercity"]                 = { min = 1,   full = 75  },
    ["The Wailing Caverns"]       = { min = 1,   full = 75  },
    ["Westfall"]                  = { min = 1,   full = 75  },
    -- Tier 2: min 55, 100% at 150
    ["Ashenvale"]                 = { min = 55,  full = 150 },
    ["Duskwood"]                  = { min = 55,  full = 150 },
    ["Hillsbrad Foothills"]       = { min = 55,  full = 150 },
    ["Redridge Mountains"]        = { min = 55,  full = 150 },
    ["Stonetalon Mountains"]      = { min = 55,  full = 150 },
    ["Wetlands"]                  = { min = 55,  full = 150 },
    -- Tier 3: min 130, 100% at 225
    ["Alterac Mountains"]         = { min = 130, full = 225 },
    ["Arathi Highlands"]          = { min = 130, full = 225 },
    ["Desolace"]                  = { min = 130, full = 225 },
    ["Dustwallow Marsh"]          = { min = 130, full = 225 },
    ["Scarlet Monastery"]         = { min = 130, full = 225 },
    ["Stranglethorn Vale"]        = { min = 130, full = 225 },
    ["Swamp of Sorrows"]          = { min = 130, full = 225 },
    ["Thousand Needles"]          = { min = 130, full = 225 },
    -- Tier 4: min 205, 100% at 300
    ["Azshara"]                   = { min = 205, full = 300 },
    ["Felwood"]                   = { min = 205, full = 300 },
    ["Feralas"]                   = { min = 205, full = 300 },
    ["The Hinterlands"]           = { min = 205, full = 300 },
    ["Maraudon"]                  = { min = 205, full = 300 },
    ["Moonglade"]                 = { min = 205, full = 300 },
    ["Tanaris"]                   = { min = 205, full = 300 },
    ["The Temple of Atal'Hakkar"] = { min = 205, full = 300 },
    ["Un'Goro Crater"]            = { min = 205, full = 300 },
    ["Western Plaguelands"]       = { min = 205, full = 300 },
    -- Tier 5: min 280, 100% at 375
    ["Burning Steppes"]           = { min = 280, full = 375 },
    ["Blasted Lands"]             = { min = 280, full = 375 },
    ["Deadwind Pass"]             = { min = 280, full = 375 },
    ["Eastern Plaguelands"]       = { min = 280, full = 375 },
    ["Searing Gorge"]             = { min = 280, full = 375 },
    ["Silithus"]                  = { min = 280, full = 375 },
    ["Winterspring"]              = { min = 280, full = 375 },
}

-- Cached — refreshed on login, zone change, or after each catch
local zoneCache = { zone = nil, data = nil, skill = nil }

local function GetPlayerFishingSkill()
    for i = 1, GetNumSkillLines() do
        local name, _, _, rank, _, modifier = GetSkillLineInfo(i)
        if name == "Fishing" then
            return (tonumber(rank) or 0) + (tonumber(modifier) or 0)
        end
    end
    return 0
end

function FishingVolume.RefreshZoneSkill()
    local zone = GetZoneText()
    zoneCache.zone  = (zone and zone ~= "") and zone or nil
    zoneCache.data  = zoneCache.zone and ZONE_SKILL[zoneCache.zone]
    zoneCache.skill = GetPlayerFishingSkill()
end

-- Returns r,g,b colour for the 100% catch rate number based on player skill.
-- Green  = at or above full, Orange = below full but above min, Red = below min, Gray = unknown
local function ZoneSkillColor()
    local data, skill = zoneCache.data, zoneCache.skill
    if not data or not skill then return 0.67, 0.67, 0.67 end
    if skill >= data.full then return 0.0,  0.8, 0.0  end  -- green:  100% catch rate
    if skill >= data.min  then return 1.0,  0.6, 0.0  end  -- orange: catching but get-aways
    return 1.0, 0.2, 0.2                                    -- red:    can't catch anything
end

-- ================================================================
-- Updates the visual state of the Delay Slider based on the checkbox.
local function UpdateDelaySliderState(frame)
    if not frame.delaySlider or not frame.muteOnStopCheck then return end

    local muteOnStop = FishingVolume.GetSetting("muteOnStop")
    local r, g, b = 1.0, 0.82, 0
    local wr, wg, wb = 1.0, 1.0, 1.0

    if muteOnStop then
        r, g, b, wr, wg, wb = 0.5, 0.5, 0.5, 0.5, 0.5, 0.5
        frame.delaySlider:EnableMouse(false)
        frame.delaySlider:SetAlpha(0.5)
        if frame.delaySlider.editBox then frame.delaySlider.editBox:EnableMouse(false) end
    else
        frame.delaySlider:EnableMouse(true)
        frame.delaySlider:SetAlpha(1.0)
        if frame.delaySlider.editBox then frame.delaySlider.editBox:EnableMouse(true) end
    end

    local text = getglobal("FVDelaySliderText")
    if text then text:SetTextColor(r, g, b) end
    if frame.delaySlider.editBox then
        frame.delaySlider.editBox:SetTextColor(wr, wg, wb)
    end
    local thumb = frame.delaySlider:GetThumbTexture()
    if thumb then thumb:SetVertexColor(r, g, b) end
    frame.delaySlider:SetBackdropBorderColor(muteOnStop and 0.1 or 0.2, muteOnStop and 0.1 or 0.2, muteOnStop and 0.1 or 0.2, 1)
end

-- Shared state update — called for both the main frame and the mini panel.
function UpdateUtilityButtons(frame)
    if not frame.fishBtn or not frame.lureBtn then return end

    local mhLink = GetInventoryItemLink("player", 16)
    local mhName = FishingVolume.GetItemName(mhLink)
    local hasPole    = mhName and string.find(mhName, "Pole")
    local lureCount  = GetLureCount()

    local goldR, goldG, goldB = 1.0, 0.82, 0
    local darkR, darkG, darkB = 0.2, 0.2, 0.2

    -- RAID WARNING ALERTS
    local hasLure, expires = GetWeaponEnchantInfo()
    if frame.hadLure ~= nil then
        if frame.hadLure and not hasLure and not FishingVolume.intentionalSwap then
            PlaySound("RaidWarning")
            UIErrorsFrame:AddMessage("LURE EXPIRED!", 1, 0, 0, 1)
        end
        if frame.lastLureCount and frame.lastLureCount > 0 and lureCount == 0 then
            PlaySound("RaidWarning")
            UIErrorsFrame:AddMessage("OUT OF LURES!", 1, 0, 0, 1)
        end
    end
    frame.hadLure = hasLure
    frame.lastLureCount = lureCount

    local function SetBorder(btn, r, g, b, a)
        -- Always store the resting colour so OnLeave restores the correct value
        btn._restR, btn._restG, btn._restB, btn._restA = r, g, b, a or 1
        -- Skip the visual update while hovered — the hover highlight is showing
        if btn.isHovered then return end
        local cr, cg, cb = btn:GetBackdropBorderColor()
        if math.abs((cr or 0) - r) < 0.01 and math.abs((cg or 0) - g) < 0.01
           and math.abs((cb or 0) - b) < 0.01 then return end
        btn:SetBackdropBorderColor(r, g, b, a or 1)
    end

    local function SetEnabled(btn, enabled, textR, textG, textB)
        local wasEnabled = btn._fvEnabled
        if wasEnabled == enabled then return end
        btn._fvEnabled = enabled
        if enabled then
            btn:Enable()
            btn:SetAlpha(1.0)
            btn:GetFontString():SetTextColor(textR, textG, textB)
        else
            btn:Disable()
            btn:SetAlpha(0.4)
            btn:GetFontString():SetTextColor(0.5, 0.5, 0.5)
            if not btn.isHovered then
                btn:SetBackdropBorderColor(0.1, 0.1, 0.1, 0.5)
            end
        end
    end

    if frame.poleBtn then
        SetBorder(frame.poleBtn, hasPole and goldR or darkR, hasPole and goldG or darkG, hasPole and goldB or darkB, 1)
    end

    if frame.weapBtn then
        local savedMH = FishingVolume.GetSetting("savedMainHand")
        local showGold = (not hasPole) and savedMH
        SetBorder(frame.weapBtn, showGold and goldR or darkR, showGold and goldG or darkG, showGold and goldB or darkB, 1)
    end

    if hasPole then
        SetEnabled(frame.fishBtn, true, goldR, goldG, goldB)
        local isFishing = (CastingBarFrame:IsVisible() and CastingBarText:GetText() == "Fishing")
        SetBorder(frame.fishBtn, isFishing and goldR or darkR, isFishing and goldG or darkG, isFishing and goldB or darkB, 1)
    else
        SetEnabled(frame.fishBtn, false)
    end

    if hasPole and lureCount > 0 then
        SetEnabled(frame.lureBtn, true, goldR, goldG, goldB)
        if hasLure then
            SetBorder(frame.lureBtn, goldR, goldG, goldB, 1)
        else
            SetBorder(frame.lureBtn, 1, 0, 0, 1)
        end
    else
        SetEnabled(frame.lureBtn, false)
    end

    if frame.lureTimeText then
        local timeStr = "None"
        if hasLure then
            local seconds = math.floor(expires / 1000)
            timeStr = (seconds > 60) and (math.ceil(seconds / 60) .. "m") or (seconds .. "s")
        end
        if frame._lastTimeStr ~= timeStr then
            frame._lastTimeStr = timeStr
            frame.lureTimeText:SetText("Time remaining on lure: " .. timeStr)
        end
        if frame._lastLureCount ~= lureCount then
            frame._lastLureCount = lureCount
            frame.lureInvText:SetText("Lures in inventory: " .. lureCount)
        end
        -- Zone skill display (data refreshed externally; just render cache here)
        if frame.zoneNameText and frame.zoneReqText then
            local GOLD  = "|cffffd100"
            local WHITE = "|cffffffff"
            local RESET = "|r"

            local zoneName = zoneCache.zone or "Unknown"
            local data     = zoneCache.data
            local skill    = zoneCache.skill or 0

            local fullStr = data and tostring(data.full) or "?"
            local nr, ng, nb = ZoneSkillColor()
            local numHex = string.format("%02x%02x%02x",
                math.floor(nr * 255), math.floor(ng * 255), math.floor(nb * 255))
            local numColor = "|cff" .. numHex

            -- Fish% via El's Angling: (skill / full)^2, capped at 100%
            -- Cast success%: (skill - min) / (full - min), capped at 100%
            local successPct, junkPct
            if not data then
                successPct, junkPct = nil, nil
            elseif skill >= data.full then
                successPct, junkPct = 100, 0
            elseif skill < data.min then
                successPct, junkPct = 0, 100
            else
                local ratio = skill / data.full
                local fishPct = math.floor(ratio * ratio * 100 + 0.5)
                junkPct    = 100 - fishPct
                local sRatio = (skill - data.min) / (data.full - data.min)
                successPct = math.floor(sRatio * 100 + 0.5)
            end

            local cacheKey = zoneName .. fullStr .. tostring(skill)
            if frame._lastZoneKey ~= cacheKey then
                frame._lastZoneKey = cacheKey

                frame.zoneNameText:SetText(
                    GOLD .. "Zone: " .. RESET .. WHITE .. zoneName .. RESET)

                frame.zoneReqText:SetText(
                    GOLD .. "Skill requirement: " .. RESET ..
                    numColor .. fullStr .. RESET ..
                    WHITE .. " (" .. skill .. ")" .. RESET)

                if successPct ~= nil then
                    frame.zoneSuccessText:SetText(
                        GOLD .. "Success chance: " .. RESET ..
                        WHITE .. successPct .. "%" .. RESET)
                    frame.zoneFishText:SetText(
                        GOLD .. "Junk chance: " .. RESET ..
                        WHITE .. junkPct .. "%" .. RESET)
                else
                    frame.zoneSuccessText:SetText(GOLD .. "Success chance: " .. RESET .. WHITE .. "?" .. RESET)
                    frame.zoneFishText:SetText(GOLD .. "Junk chance: " .. RESET .. WHITE .. "?" .. RESET)
                end
            end
        end
    end

    if frame.statSessionText then
        local GOLD  = "|cffffd100"
        local WHITE = "|cffffffff"
        local RESET = "|r"

        local sFish   = FishingVolume.sessionFish or 0
        local sChests = FishingVolume.sessionChests or 0
        local tFish   = FishingVolume.GetSetting("totalFish") or 0
        local tChests = FishingVolume.GetSetting("totalChests") or 0

        if frame._lastSFish ~= sFish or frame._lastSChests ~= sChests then
            frame._lastSFish, frame._lastSChests = sFish, sChests
            frame.statSessionText:SetText(
                GOLD .. "Session: " .. RESET ..
                WHITE .. sFish .. RESET ..
                GOLD .. " Fish | " .. RESET ..
                WHITE .. sChests .. RESET ..
                GOLD .. " Chests (" .. RESET ..
                WHITE .. GetChestPercent(sFish, sChests) .. RESET ..
                GOLD .. ")" .. RESET)
        end
        if frame._lastTFish ~= tFish or frame._lastTChests ~= tChests then
            frame._lastTFish, frame._lastTChests = tFish, tChests
            frame.statTotalText:SetText(
                GOLD .. "Lifetime: " .. RESET ..
                WHITE .. tFish .. RESET ..
                GOLD .. " Fish | " .. RESET ..
                WHITE .. tChests .. RESET ..
                GOLD .. " Chests (" .. RESET ..
                WHITE .. GetChestPercent(tFish, tChests) .. RESET ..
                GOLD .. ")" .. RESET)
        end
    end

    if frame.lureStatus then
        local statusText
        if hasLure then
            local s = math.floor(expires / 1000)
            statusText = "Lure: " .. ((s > 60) and (math.ceil(s/60) .. "m") or (s .. "s"))
        elseif lureCount == 0 then
            statusText = "No lure in inventory"
        else
            statusText = "No lure active"
        end
        if frame._lastLureStatus ~= statusText then
            frame._lastLureStatus = statusText
            frame.lureStatus:SetText(statusText)
            if hasLure then
                frame.lureStatus:SetTextColor(goldR, goldG, goldB)
            else
                frame.lureStatus:SetTextColor(1, 0.3, 0.3)
            end
        end
    end
end

local function StripBlizzard(obj, isSlider)
    local name = obj:GetName()
    if not name then return end
    local textures = { "Left", "Middle", "Right", "DisabledLeft", "DisabledMiddle", "DisabledRight" }
    for _, tex in pairs(textures) do
        if getglobal(name..tex) then getglobal(name..tex):SetTexture(nil) end
    end
    if obj.GetNormalTexture    and obj:GetNormalTexture()    then obj:GetNormalTexture():SetTexture(nil)    end
    if obj.GetPushedTexture    and obj:GetPushedTexture()    then obj:GetPushedTexture():SetTexture(nil)    end
    if obj.GetHighlightTexture and obj:GetHighlightTexture() then obj:GetHighlightTexture():SetTexture(nil) end
    if obj.GetDisabledTexture  and obj:GetDisabledTexture()  then obj:GetDisabledTexture():SetTexture(nil)  end
    if isSlider and obj.GetThumbTexture then
        local thumb = obj:GetThumbTexture()
        if thumb then
            thumb:SetTexture(1.0, 0.82, 0)
            thumb:SetWidth(12) thumb:SetHeight(14)
        end
    end
end

local function ApplyPFStyle(obj, isButton)
    obj:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    obj:SetBackdropColor(0, 0, 0, 1)
    obj:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    if isButton then
        obj:SetScript("OnEnter", function()
            this.isHovered = true
            this:SetBackdropBorderColor(1.0, 0.82, 0, 1)
        end)
        obj:SetScript("OnLeave", function()
            this.isHovered = false
            local r = this._restR or 0.2
            local g = this._restG or 0.2
            local b = this._restB or 0.2
            local a = this._restA or 1
            this:SetBackdropBorderColor(r, g, b, a)
        end)
    end
end

function FishingVolume_OnLoad(frame)
    tinsert(UISpecialFrames, "FishingVolumeFrame")
    frame:RegisterForDrag("LeftButton")
    frame:RegisterEvent("UNIT_INVENTORY_CHANGED")

    ApplyPFStyle(frame, false)
    frame:SetBackdropColor(0, 0, 0, 0.85)

    FishingVolumeTitleText:ClearAllPoints()
    FishingVolumeTitleText:SetPoint("TOP", frame, "TOP", 0, -10)
    FishingVolumeTitleText:SetTextColor(1.0, 0.82, 0)

    local close = CreateFrame("Button", "FVUpperCloseBtn", frame)
    close:SetWidth(18) close:SetHeight(18)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    ApplyPFStyle(close, true)
    local xText = close:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    xText:SetAllPoints(close)
    xText:SetJustifyH("CENTER")
    xText:SetJustifyV("MIDDLE")
    xText:SetText("X")
    xText:SetTextColor(0.7, 0.2, 0.2)
    close:SetScript("OnClick", function() frame:Hide() end)

    local function MakeSlider(name, label, minVal, maxVal, step, yOff, saveFn)
        local s = CreateFrame("Slider", name, frame, "OptionsSliderTemplate")
        s:SetMinMaxValues(minVal, maxVal) s:SetValueStep(step)
        s:SetWidth(SLIDER_W) s:SetHeight(14)
        s:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, yOff)

        local labelObj = getglobal(name .. "Text")
        labelObj:SetText(label)
        labelObj:SetTextColor(1.0, 0.82, 0)
        labelObj:ClearAllPoints()
        labelObj:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 3)

        getglobal(name .. "Low"):Hide() getglobal(name .. "High"):Hide()

        local vt = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        vt:SetWidth(LABEL_W)
        vt:SetJustifyH("RIGHT")
        vt:SetPoint("LEFT", s, "RIGHT", 4, 0)
        s.valText = vt

        local eb = CreateFrame("EditBox", name.."Edit", s)
        eb:SetFontObject(GameFontHighlightSmall)
        eb:SetWidth(45) eb:SetHeight(14)
        eb:SetPoint("CENTER", vt, "CENTER", 0, 0)
        eb:SetJustifyH("LEFT")
        eb:SetAutoFocus(false)
        eb:SetNumeric(true)
        eb:SetMaxLetters(4)
        s.editBox = eb

        s:SetScript("OnValueChanged", function()
            local val = math.floor(this:GetValue())
            local suffix = (name == "FVDelaySlider") and "s" or "%"
            s.valText:SetText(val .. suffix)
            if not s.isTyping then eb:SetText(val .. suffix) end
            if saveFn then saveFn(val) end
        end)

        eb:SetScript("OnEditFocusGained", function() s.isTyping = true; s.valText:SetAlpha(0) end)
        eb:SetScript("OnEditFocusLost", function()
            s.isTyping = false; s.valText:SetAlpha(1)
            local suffix = (name == "FVDelaySlider") and "s" or "%"
            this:SetText(math.floor(s:GetValue()) .. suffix)
        end)
        eb:SetScript("OnEnterPressed", function()
            local txt = this:GetText()
            txt = string.gsub(txt, "%%", ""); txt = string.gsub(txt, "s", "")
            local val = tonumber(txt) or 0
            if val > maxVal then val = maxVal elseif val < minVal then val = minVal end
            s:SetValue(val); this:ClearFocus()
        end)
        eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)

        StripBlizzard(s, true); ApplyPFStyle(s, false)
        return s
    end

    frame.fishSlider  = MakeSlider("FVFishSlider",  "Fishing Volume",  0, 100, 1, -55,
        function(val) FishingVolume.SetSetting("fishingVolume", val / 100) end)
    frame.soundSlider = MakeSlider("FVSoundSlider", "Restored Volume", 0, 100, 1, -95,
        function(val) FishingVolume.SetSetting("soundVolume", val / 100) end)
    frame.delaySlider = MakeSlider("FVDelaySlider", "Restore Delay",   0,  60, 1, -140,
        function(val) FishingVolume.SetSetting("muteDelay", val) end)

    local chk = CreateFrame("CheckButton", "FVMuteOnStopCheck", frame, "OptionsCheckButtonTemplate")
    chk:SetWidth(18) chk:SetHeight(18)
    chk:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -185)
    StripBlizzard(chk, false)
    ApplyPFStyle(chk, true)
    local chkText = getglobal(chk:GetName().."Text")
    chkText:SetText("Restore Volume Automatically when not Fishing")
    chkText:SetTextColor(1.0, 0.82, 0)
    chkText:SetPoint("LEFT", chk, "RIGHT", 5, 0)
    local checkTex = chk:GetCheckedTexture()
    if checkTex then
        checkTex:SetTexture(1, 0.82, 0, 0.8)
        checkTex:ClearAllPoints()
        checkTex:SetPoint("TOPLEFT", chk, "TOPLEFT", 5, -5)
        checkTex:SetPoint("BOTTOMRIGHT", chk, "BOTTOMRIGHT", -5, 5)
    end
    chk:SetScript("OnClick", function()
        FishingVolume.SetSetting("muteOnStop", this:GetChecked() == 1)
        UpdateDelaySliderState(frame)
    end)
    local chkLabelBtn = CreateFrame("Button", nil, frame)
    chkLabelBtn:SetPoint("TOPLEFT", chk, "TOPLEFT", 0, 0)
    chkLabelBtn:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -PAD, -205)
    chkLabelBtn:SetScript("OnClick", function() chk:Click() end)
    chkLabelBtn:SetScript("OnEnter", function() chk.isHovered = true end)
    chkLabelBtn:SetScript("OnLeave", function() chk.isHovered = false; UpdateDelaySliderState(frame) end)
    frame.muteOnStopCheck = chk

    local chkRecast = CreateFrame("CheckButton", "FVAutoRecastCheck", frame, "OptionsCheckButtonTemplate")
    chkRecast:SetWidth(18) chkRecast:SetHeight(18)
    chkRecast:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -207)
    StripBlizzard(chkRecast, false)
    ApplyPFStyle(chkRecast, true)
    local chkRecastText = getglobal(chkRecast:GetName().."Text")
    chkRecastText:SetText("Left-click for re-cast Fishing")
    chkRecastText:SetTextColor(1.0, 0.82, 0)
    chkRecastText:SetPoint("LEFT", chkRecast, "RIGHT", 5, 0)
    local checkRecastTex = chkRecast:GetCheckedTexture()
    if checkRecastTex then
        checkRecastTex:SetTexture(1, 0.82, 0, 0.8)
        checkRecastTex:ClearAllPoints()
        checkRecastTex:SetPoint("TOPLEFT", chkRecast, "TOPLEFT", 5, -5)
        checkRecastTex:SetPoint("BOTTOMRIGHT", chkRecast, "BOTTOMRIGHT", -5, 5)
    end
    chkRecast:SetScript("OnClick", function()
        FishingVolume.SetSetting("autoRecast", this:GetChecked() == 1)
    end)
    local chkRecastLabelBtn = CreateFrame("Button", nil, frame)
    chkRecastLabelBtn:SetPoint("TOPLEFT", chkRecast, "TOPLEFT", 0, 0)
    chkRecastLabelBtn:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -PAD, -227)
    chkRecastLabelBtn:SetScript("OnClick", function() chkRecast:Click() end)
    chkRecastLabelBtn:SetScript("OnEnter", function() chkRecast.isHovered = true end)
    chkRecastLabelBtn:SetScript("OnLeave", function() chkRecast.isHovered = false; UpdateDelaySliderState(frame) end)
    frame.autoRecastCheck = chkRecast

    -- ----------------------------------------------------------------
    -- UTILITY BUTTONS  (4 buttons, 2 rows × 2 columns)
    --   Row 1: [Equip Pole]  [Equip Weapons]
    --   Row 2: [Cast Fishing] [Apply Lure]
    -- ----------------------------------------------------------------
    local btnW = (FRAME_W - PAD * 2 - 6) / 2
    local function CreateStyledButton(name, text, parent)
        local b = CreateFrame("Button", name, parent or frame, "UIPanelButtonTemplate")
        b:SetWidth(btnW) b:SetHeight(22)
        b:SetText(text); b:GetFontString():SetTextColor(1.0, 0.82, 0)
        StripBlizzard(b, false); ApplyPFStyle(b, true)
        return b
    end

    -- Row 1
    FVPoleBtn = CreateStyledButton("FVPoleBtn", "Equip Pole")
    FVPoleBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -233)
    FVPoleBtn:SetScript("OnClick", function()
        FishingVolume:EquipPole()
        UpdateUtilityButtons(frame)
        if FVMiniPanel and FVMiniPanel:IsVisible() then UpdateUtilityButtons(FVMiniPanel) end
    end)
    frame.poleBtn = FVPoleBtn

    FVWeapBtn = CreateStyledButton("FVWeapBtn", "Equip Weapons")
    FVWeapBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + btnW + 6, -233)
    FVWeapBtn:SetScript("OnClick", function()
        FishingVolume:EquipWeapons()
        UpdateUtilityButtons(frame)
        if FVMiniPanel and FVMiniPanel:IsVisible() then UpdateUtilityButtons(FVMiniPanel) end
    end)
    frame.weapBtn = FVWeapBtn

    -- Row 2
    FVFishBtn = CreateStyledButton("FVFishBtn", "Cast Fishing")
    FVFishBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -260)
    FVFishBtn:SetScript("OnClick", function()
        FishingVolume:CastFishing()
        UpdateUtilityButtons(frame)
        if FVMiniPanel and FVMiniPanel:IsVisible() then UpdateUtilityButtons(FVMiniPanel) end
    end)
    frame.fishBtn = FVFishBtn

    FVLureBtn = CreateStyledButton("FVLureBtn", "Apply Lure")
    FVLureBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + btnW + 6, -260)
    FVLureBtn:SetScript("OnClick", function()
        FishingVolume:ApplyBestLure()  -- FIX: was incorrectly calling ApplyLure()
        UpdateUtilityButtons(frame)
        if FVMiniPanel and FVMiniPanel:IsVisible() then UpdateUtilityButtons(FVMiniPanel) end
    end)
    frame.lureBtn = FVLureBtn

    -- ----------------------------------------------------------------
    -- INFO LABELS
    -- ----------------------------------------------------------------
    local function MakeInfoText(y, size)
        local t = frame:CreateFontString(nil, "OVERLAY", size or "GameFontHighlightSmall")
        t:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
        t:SetWidth(FRAME_W - PAD * 2)
        t:SetJustifyH("LEFT")
        return t
    end

    frame.lureTimeText = MakeInfoText(-295)
    frame.lureInvText  = MakeInfoText(-310)

    -- Zone section divider
    local divZ = frame:CreateTexture(nil, "ARTWORK")
    divZ:SetHeight(1); divZ:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -328)
    divZ:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -328); divZ:SetTexture(0.3, 0.3, 0.3, 1)

    -- Zones browser button — full width of the right column, same height as utility buttons
    local btnZones = CreateStyledButton("FVZonesBrowserBtn", "Zones")
    btnZones:SetWidth(btnW)
    btnZones:SetHeight(22)
    btnZones:ClearAllPoints()
    btnZones:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + btnW + 6, -333)
    btnZones:SetScript("OnClick", function()
        if FishingVolume_ToggleZonesFrame then FishingVolume_ToggleZonesFrame() end
    end)

    -- Zone name sits in the left column next to the Zones button
    local zoneNameText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneNameText:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -338)
    zoneNameText:SetWidth(btnW)
    zoneNameText:SetJustifyH("LEFT")
    frame.zoneNameText = zoneNameText

    frame.zoneReqText     = MakeInfoText(-353)
    frame.zoneSuccessText = MakeInfoText(-368)
    frame.zoneFishText    = MakeInfoText(-383)

    -- Stats section divider
    local divS = frame:CreateTexture(nil, "ARTWORK")
    divS:SetHeight(1); divS:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -400)
    divS:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -400); divS:SetTexture(0.3, 0.3, 0.3, 1)

    frame.statSessionText = MakeInfoText(-410)
    frame.statTotalText   = MakeInfoText(-425)

    -- Bottom divider above Save / Close
    local divB = frame:CreateTexture(nil, "ARTWORK")
    divB:SetHeight(1); divB:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -445)
    divB:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -445); divB:SetTexture(0.3, 0.3, 0.3, 1)

    -- Save button
    local saveBtn = CreateStyledButton("FVSaveBtn", "Save")
    saveBtn:SetWidth(btnW) saveBtn:SetHeight(22)
    saveBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -450)
    saveBtn:SetScript("OnClick", function()
        -- Settings are saved live via slider OnValueChanged and checkbox OnClick.
        -- This button provides explicit confirmation and closes the panel.
        DEFAULT_CHAT_FRAME:AddMessage("|cff33cc99FishingVolume:|r Settings saved.")
    end)

    -- Close button
    local closeBottomBtn = CreateStyledButton("FVCloseBtn", "Close")
    closeBottomBtn:SetWidth(btnW) closeBottomBtn:SetHeight(22)
    closeBottomBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + btnW + 6, -450)
    closeBottomBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Instantly refresh when gear changes (equip/unequip)
    frame:SetScript("OnEvent", function()
        if event == "UNIT_INVENTORY_CHANGED" then
            UpdateUtilityButtons(frame)
        end
    end)

    -- Periodic refresh so lure timer and cast state stay current
    frame._elapsed = 0
    frame:SetScript("OnUpdate", function()
        frame._elapsed = frame._elapsed + arg1
        if frame._elapsed >= 0.5 then
            frame._elapsed = 0
            UpdateUtilityButtons(frame)
        end
    end)
end

function FishingVolume_OnShow(frame)
    frame.fishSlider:SetValue(FishingVolume.GetSetting("fishingVolume") * 100)
    frame.soundSlider:SetValue((FishingVolume.GetSetting("soundVolume") or 0) * 100)
    frame.delaySlider:SetValue(FishingVolume.GetSetting("muteDelay"))
    frame.muteOnStopCheck:SetChecked(FishingVolume.GetSetting("muteOnStop"))
    frame.autoRecastCheck:SetChecked(FishingVolume.GetSetting("autoRecast"))
    UpdateDelaySliderState(frame)
    FishingVolume.RefreshZoneSkill()
    UpdateUtilityButtons(frame)
end

-- ================================================================
-- MINI PANEL
-- ================================================================

function FishingVolume_CreateMiniPanel()
    if FVMiniPanel then return end

    local frame = CreateFrame("Frame", "FVMiniPanel", UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetWidth(180)
    frame:SetHeight(100)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.92)
    frame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    frame:Hide()

    tinsert(UISpecialFrames, "FVMiniPanel")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", frame, "TOP", 0, -6)
    title:SetText("Fishing Volume Mini")
    title:SetTextColor(1.0, 0.82, 0)

    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetWidth(14) closeBtn:SetHeight(14)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
    closeBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    closeBtn:SetBackdropColor(0, 0, 0, 1)
    closeBtn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    local xStr = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    xStr:SetAllPoints(closeBtn)
    xStr:SetJustifyH("CENTER") xStr:SetJustifyV("MIDDLE")
    xStr:SetText("X") xStr:SetTextColor(0.7, 0.2, 0.2)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    closeBtn:SetScript("OnEnter", function() this:SetBackdropBorderColor(1, 0.2, 0.2, 1) end)
    closeBtn:SetScript("OnLeave", function() this:SetBackdropBorderColor(0.2, 0.2, 0.2, 1) end)

    local mPAD  = 8
    local mBtnW = (180 - mPAD * 2 - 4) / 2  -- two columns with a 4px gap
    local mBtnH = 22

    local function MakeMiniBtn(text, xOff, yOff)
        local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        b:SetWidth(mBtnW) b:SetHeight(mBtnH)
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", xOff, yOff)
        b:SetText(text)
        b:GetFontString():SetTextColor(1.0, 0.82, 0)
        b:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        b:SetBackdropColor(0, 0, 0, 1)
        b:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
        b:SetScript("OnEnter", function()
            this.isHovered = true
            this:SetBackdropBorderColor(1.0, 0.82, 0, 1)
        end)
        b:SetScript("OnLeave", function()
            this.isHovered = false
            local r = this._restR or 0.2
            local g = this._restG or 0.2
            local bv = this._restB or 0.2
            local a = this._restA or 1
            this:SetBackdropBorderColor(r, g, bv, a)
        end)

        if b:GetNormalTexture()    then b:GetNormalTexture():SetTexture(nil)    end
        if b:GetPushedTexture()    then b:GetPushedTexture():SetTexture(nil)    end
        if b:GetHighlightTexture() then b:GetHighlightTexture():SetTexture(nil) end
        if b:GetDisabledTexture()  then b:GetDisabledTexture():SetTexture(nil)  end

        -- Wrap Enable/Disable to suppress Blizzard textures re-appearing
        b._Enable  = b.Enable
        b._Disable = b.Disable
        b.Enable = function(self)
            self._Enable(self)
            if self:GetNormalTexture()   then self:GetNormalTexture():SetTexture(nil)   end
            if self:GetDisabledTexture() then self:GetDisabledTexture():SetTexture(nil) end
        end
        b.Disable = function(self)
            self._Disable(self)
            if self:GetNormalTexture()   then self:GetNormalTexture():SetTexture(nil)   end
            if self:GetDisabledTexture() then self:GetDisabledTexture():SetTexture(nil) end
        end

        return b
    end

    -- Layout: left col = mPAD, right col = mPAD + mBtnW + 4
    local col1 = mPAD
    local col2 = mPAD + mBtnW + 4

    --   Row 1: Equip Pole | Equip Weapons
    --   Row 2: Cast Fish  | Apply Lure
    local poleBtn = MakeMiniBtn("Equip Pole",    col1, -22)
    local weapBtn = MakeMiniBtn("Equip Weapons", col2, -22)
    local fishBtn = MakeMiniBtn("Fish",          col1, -48)
    local lureBtn = MakeMiniBtn("Apply Lure",    col2, -48)

    poleBtn:SetScript("OnClick", function()
        FishingVolume:EquipPole()
        UpdateUtilityButtons(frame)
        if FishingVolumeFrame and FishingVolumeFrame:IsVisible() then UpdateUtilityButtons(FishingVolumeFrame) end
    end)
    weapBtn:SetScript("OnClick", function()
        FishingVolume:EquipWeapons()
        UpdateUtilityButtons(frame)
        if FishingVolumeFrame and FishingVolumeFrame:IsVisible() then UpdateUtilityButtons(FishingVolumeFrame) end
    end)
    fishBtn:SetScript("OnClick", function()
        FishingVolume:CastFishing()
    end)
    lureBtn:SetScript("OnClick", function()
        FishingVolume:ApplyBestLure()
        UpdateUtilityButtons(frame)
        if FishingVolumeFrame and FishingVolumeFrame:IsVisible() then UpdateUtilityButtons(FishingVolumeFrame) end
    end)

    frame.poleBtn = poleBtn
    frame.weapBtn = weapBtn
    frame.fishBtn = fishBtn
    frame.lureBtn = lureBtn

    local lureStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lureStatus:SetPoint("BOTTOM", frame, "BOTTOM", 0, 6)
    lureStatus:SetTextColor(1, 1, 1)
    frame.lureStatus = lureStatus

    frame:SetScript("OnShow", function()
        UpdateUtilityButtons(frame)
    end)

    frame.elapsed = 0
    frame:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed > 0.5 then
            UpdateUtilityButtons(frame)
            this.elapsed = 0
        end
    end)
end

-- FIX: This function was called from MinimapButton.lua and FishingVolume.lua
-- but was never defined, making the mini panel completely inaccessible.
function FishingVolume_ToggleMiniPanel()
    FishingVolume_CreateMiniPanel()
    if FVMiniPanel:IsVisible() then
        FVMiniPanel:Hide()
    else
        FVMiniPanel:Show()
    end
end

-- ================================================================
-- ZONES BROWSER (canonical implementation — ZonesBrowser.lua defers here)
-- ================================================================

local FVZonesFrame = nil

local function FVStyleBtn(b, active)
    local n = b:GetName()
    if n then
        local t = { "Left","Middle","Right","DisabledLeft","DisabledMiddle","DisabledRight" }
        for _, v in pairs(t) do
            if getglobal(n..v) then getglobal(n..v):SetTexture(nil) end
        end
    end
    if b:GetNormalTexture()    then b:GetNormalTexture():SetTexture(nil)    end
    if b:GetPushedTexture()    then b:GetPushedTexture():SetTexture(nil)    end
    if b:GetHighlightTexture() then b:GetHighlightTexture():SetTexture(nil) end
    if b:GetDisabledTexture()  then b:GetDisabledTexture():SetTexture(nil)  end

    b:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    b:SetBackdropColor(0, 0, 0, 1)

    if active then
        b:SetBackdropBorderColor(1.0, 0.82, 0, 1)
    else
        b:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    end
end

local function FVGetFishingSkill()
    for i = 1, GetNumSkillLines() do
        local name, _, _, rank, _, modifier = GetSkillLineInfo(i)
        if name == "Fishing" then
            return (tonumber(rank) or 0), (tonumber(modifier) or 0)
        end
    end
    return 0, 0
end

local function FVLvlC(lvl, pl)
    local d = lvl - pl
    if d >= 5 then      return "|cffff3333"
    elseif d >= 3 then  return "|cffff9900"
    elseif d >= -2 then return "|cffffff00"
    elseif d >= -5 then return "|cff00cc00"
    else                return "|cffaaaaaa"
    end
end

local function FVFishC(full, min)
    local base, bonus = FVGetFishingSkill()
    local total = base + bonus
    if total >= full then     return 0.0, 0.8, 0.0
    elseif total >= min then  return 1.0, 0.6, 0.0
    else                      return 1.0, 0.2, 0.2
    end
end

local function FVSetBtnColor(btn, full, min, active)
    local r, g, b = FVFishC(full, min)
    if active then
        btn:GetFontString():SetTextColor(r, g, b)
    else
        btn:GetFontString():SetTextColor(r*0.6, g*0.6, b*0.6)
    end
end

-- Returns the display label for a bracket button, e.g. "Skill 1-25  74%"
local function FVBracketLabel(minSkill, full)
    local base, bonus = FVGetFishingSkill()
    local skill = base + bonus
    local pct
    if skill >= full then
        pct = "100%"
    elseif skill < minSkill then
        pct = "0%"
    else
        local sRatio = (skill - minSkill) / (full - minSkill)
        pct = math.floor(sRatio * 100 + 0.5) .. "%"
    end
    return "Skill " .. minSkill .. "-" .. full .. "  " .. pct
end

-- Refreshes all six bracket button labels (called on open and after skill changes)
local function FVRefreshBracketLabels()
    if not FVZonesFrame then return end
    local brackets = {
        { btn = FVZonesFrame.btn1, min = 1,   full = 25  },
        { btn = FVZonesFrame.btn2, min = 1,   full = 75  },
        { btn = FVZonesFrame.btn3, min = 55,  full = 150 },
        { btn = FVZonesFrame.btn4, min = 130, full = 225 },
        { btn = FVZonesFrame.btn5, min = 205, full = 300 },
        { btn = FVZonesFrame.btn6, min = 280, full = 375 },
    }
    for _, b in ipairs(brackets) do
        if b.btn then b.btn:SetText(FVBracketLabel(b.min, b.full)) end
    end
end

local function FVUpdateSkill()
    if not FVZonesFrame or not FVZonesFrame.skillText then return end
    local base, bonus = FVGetFishingSkill()
    local total = base + bonus
    local G  = "|cffffd100"  -- gold
    local W  = "|cffffffff"  -- white
    local GR = "|cff00cc00"  -- green  (bonus / total)
    local R  = "|r"
    local s = G.."Fishing: "..R..W..base..R
    if bonus > 0 then
        s = s..W.." ("..R..GR.."+"..bonus.." = "..total..R..W..")"..R
    end
    FVZonesFrame.skillText:SetText(s)
    FVRefreshBracketLabels()
end

local function FVShowBracket1()
    local pl = UnitLevel("player")
    local nl = string.char(10)
    local EK = "|cff9999ffEK:|r "
    local KL = "|cffff9999KL:|r "

    FVZonesFrame.zoneList:SetText(
        EK .. "|cffffd100Dun Morogh|r (" .. FVLvlC(1,pl) .. "1|r-" .. FVLvlC(10,pl) .. "10|r)" .. nl ..
        EK .. "|cffffd100Elwynn Forest|r (" .. FVLvlC(1,pl) .. "1|r-" .. FVLvlC(10,pl) .. "10|r)" .. nl ..
        EK .. "|cffffd100Tirisfal Glades|r (" .. FVLvlC(1,pl) .. "1|r-" .. FVLvlC(10,pl) .. "10|r)" .. nl ..
        KL .. "|cffffd100Durotar|r (" .. FVLvlC(1,pl) .. "1|r-" .. FVLvlC(10,pl) .. "10|r)" .. nl ..
        KL .. "|cffffd100Mulgore|r (" .. FVLvlC(1,pl) .. "1|r-" .. FVLvlC(10,pl) .. "10|r)" .. nl ..
        KL .. "|cffffd100Teldrassil|r (" .. FVLvlC(1,pl) .. "1|r-" .. FVLvlC(10,pl) .. "10|r)"
    )

    FVStyleBtn(FVZonesFrame.btn1, true)
    FVStyleBtn(FVZonesFrame.btn2, false)
    FVStyleBtn(FVZonesFrame.btn3, false)
    FVStyleBtn(FVZonesFrame.btn4, false)
    FVStyleBtn(FVZonesFrame.btn5, false)
    FVStyleBtn(FVZonesFrame.btn6, false)

    FVSetBtnColor(FVZonesFrame.btn1, 25, 1, true)
    FVSetBtnColor(FVZonesFrame.btn2, 75, 1, false)
    FVSetBtnColor(FVZonesFrame.btn3, 150, 55, false)
    FVSetBtnColor(FVZonesFrame.btn4, 225, 130, false)
    FVSetBtnColor(FVZonesFrame.btn5, 300, 205, false)
    FVSetBtnColor(FVZonesFrame.btn6, 375, 280, false)
end

local function FVShowBracket2()
    local pl = UnitLevel("player")
    local nl = string.char(10)
    local EK = "|cff9999ffEK:|r "
    local KL = "|cffff9999KL:|r "

    FVZonesFrame.zoneList:SetText(
        EK .. "|cffffd100Ironforge|r (" .. FVLvlC(1,pl) .. "1|r-" .. FVLvlC(10,pl) .. "10|r)" .. nl ..
        EK .. "|cffffd100Stormwind City|r (" .. FVLvlC(1,pl) .. "1|r-" .. FVLvlC(10,pl) .. "10|r)" .. nl ..
        EK .. "|cffffd100Undercity|r (" .. FVLvlC(1,pl) .. "1|r-" .. FVLvlC(10,pl) .. "10|r)" .. nl ..
        EK .. "|cffffd100Loch Modan|r (" .. FVLvlC(10,pl) .. "10|r-" .. FVLvlC(20,pl) .. "20|r)" .. nl ..
        EK .. "|cffffd100Silverpine Forest|r (" .. FVLvlC(10,pl) .. "10|r-" .. FVLvlC(20,pl) .. "20|r)" .. nl ..
        EK .. "|cffffd100Westfall|r (" .. FVLvlC(10,pl) .. "10|r-" .. FVLvlC(20,pl) .. "20|r)" .. nl ..
        EK .. "|cffffd100The Deadmines|r (" .. FVLvlC(15,pl) .. "15|r-" .. FVLvlC(20,pl) .. "20|r)" .. nl ..
        KL .. "|cffffd100Darnassus|r (" .. FVLvlC(1,pl) .. "1|r-" .. FVLvlC(10,pl) .. "10|r)" .. nl ..
        KL .. "|cffffd100Orgrimmar|r (" .. FVLvlC(1,pl) .. "1|r-" .. FVLvlC(10,pl) .. "10|r)" .. nl ..
        KL .. "|cffffd100Thunder Bluff|r (" .. FVLvlC(1,pl) .. "1|r-" .. FVLvlC(10,pl) .. "10|r)" .. nl ..
        KL .. "|cffffd100Darkshore|r (" .. FVLvlC(10,pl) .. "10|r-" .. FVLvlC(20,pl) .. "20|r)" .. nl ..
        KL .. "|cffffd100The Barrens|r (" .. FVLvlC(10,pl) .. "10|r-" .. FVLvlC(25,pl) .. "25|r)" .. nl ..
        KL .. "|cffffd100The Wailing Caverns|r (" .. FVLvlC(15,pl) .. "15|r-" .. FVLvlC(25,pl) .. "25|r)" .. nl ..
        KL .. "|cffffd100Blackfathom Deeps|r (" .. FVLvlC(20,pl) .. "20|r-" .. FVLvlC(30,pl) .. "30|r)"
    )

    FVStyleBtn(FVZonesFrame.btn1, false)
    FVStyleBtn(FVZonesFrame.btn2, true)
    FVStyleBtn(FVZonesFrame.btn3, false)
    FVStyleBtn(FVZonesFrame.btn4, false)
    FVStyleBtn(FVZonesFrame.btn5, false)
    FVStyleBtn(FVZonesFrame.btn6, false)

    FVSetBtnColor(FVZonesFrame.btn1, 25, 1, false)
    FVSetBtnColor(FVZonesFrame.btn2, 75, 1, true)
    FVSetBtnColor(FVZonesFrame.btn3, 150, 55, false)
    FVSetBtnColor(FVZonesFrame.btn4, 225, 130, false)
    FVSetBtnColor(FVZonesFrame.btn5, 300, 205, false)
    FVSetBtnColor(FVZonesFrame.btn6, 375, 280, false)
end

local function FVShowBracket3()
    local pl = UnitLevel("player")
    local nl = string.char(10)
    local EK = "|cff9999ffEK:|r "
    local KL = "|cffff9999KL:|r "

    FVZonesFrame.zoneList:SetText(
        EK .. "|cffffd100Hillsbrad Foothills|r (" .. FVLvlC(15,pl) .. "15|r-" .. FVLvlC(25,pl) .. "25|r)" .. nl ..
        EK .. "|cffffd100Redridge Mountains|r (" .. FVLvlC(15,pl) .. "15|r-" .. FVLvlC(25,pl) .. "25|r)" .. nl ..
        EK .. "|cffffd100Duskwood|r (" .. FVLvlC(18,pl) .. "18|r-" .. FVLvlC(30,pl) .. "30|r)" .. nl ..
        EK .. "|cffffd100Wetlands|r (" .. FVLvlC(20,pl) .. "20|r-" .. FVLvlC(30,pl) .. "30|r)" .. nl ..
        KL .. "|cffffd100Stonetalon Mountains|r (" .. FVLvlC(15,pl) .. "15|r-" .. FVLvlC(27,pl) .. "27|r)" .. nl ..
        KL .. "|cffffd100Ashenvale|r (" .. FVLvlC(18,pl) .. "18|r-" .. FVLvlC(30,pl) .. "30|r)"
    )

    FVStyleBtn(FVZonesFrame.btn1, false)
    FVStyleBtn(FVZonesFrame.btn2, false)
    FVStyleBtn(FVZonesFrame.btn3, true)
    FVStyleBtn(FVZonesFrame.btn4, false)
    FVStyleBtn(FVZonesFrame.btn5, false)
    FVStyleBtn(FVZonesFrame.btn6, false)

    FVSetBtnColor(FVZonesFrame.btn1, 25, 1, false)
    FVSetBtnColor(FVZonesFrame.btn2, 75, 1, false)
    FVSetBtnColor(FVZonesFrame.btn3, 150, 55, true)
    FVSetBtnColor(FVZonesFrame.btn4, 225, 130, false)
    FVSetBtnColor(FVZonesFrame.btn5, 300, 205, false)
    FVSetBtnColor(FVZonesFrame.btn6, 375, 280, false)
end

local function FVShowBracket4()
    local pl = UnitLevel("player")
    local nl = string.char(10)
    local EK = "|cff9999ffEK:|r "
    local KL = "|cffff9999KL:|r "

    FVZonesFrame.zoneList:SetText(
        EK .. "|cffffd100Arathi Highlands|r (" .. FVLvlC(25,pl) .. "25|r-" .. FVLvlC(35,pl) .. "35|r)" .. nl ..
        EK .. "|cffffd100Scarlet Monastery|r (" .. FVLvlC(28,pl) .. "28|r-" .. FVLvlC(45,pl) .. "45|r)" .. nl ..
        EK .. "|cffffd100Alterac Mountains|r (" .. FVLvlC(30,pl) .. "30|r-" .. FVLvlC(40,pl) .. "40|r)" .. nl ..
        EK .. "|cffffd100Stranglethorn Vale|r (" .. FVLvlC(30,pl) .. "30|r-" .. FVLvlC(45,pl) .. "45|r)" .. nl ..
        EK .. "|cffffd100Swamp of Sorrows|r (" .. FVLvlC(35,pl) .. "35|r-" .. FVLvlC(45,pl) .. "45|r)" .. nl ..
        KL .. "|cffffd100Thousand Needles|r (" .. FVLvlC(25,pl) .. "25|r-" .. FVLvlC(35,pl) .. "35|r)" .. nl ..
        KL .. "|cffffd100Desolace|r (" .. FVLvlC(30,pl) .. "30|r-" .. FVLvlC(40,pl) .. "40|r)" .. nl ..
        KL .. "|cffffd100Dustwallow Marsh|r (" .. FVLvlC(35,pl) .. "35|r-" .. FVLvlC(45,pl) .. "45|r)"
    )

    FVStyleBtn(FVZonesFrame.btn1, false)
    FVStyleBtn(FVZonesFrame.btn2, false)
    FVStyleBtn(FVZonesFrame.btn3, false)
    FVStyleBtn(FVZonesFrame.btn4, true)
    FVStyleBtn(FVZonesFrame.btn5, false)
    FVStyleBtn(FVZonesFrame.btn6, false)

    FVSetBtnColor(FVZonesFrame.btn1, 25, 1, false)
    FVSetBtnColor(FVZonesFrame.btn2, 75, 1, false)
    FVSetBtnColor(FVZonesFrame.btn3, 150, 55, false)
    FVSetBtnColor(FVZonesFrame.btn4, 225, 130, true)
    FVSetBtnColor(FVZonesFrame.btn5, 300, 205, false)
    FVSetBtnColor(FVZonesFrame.btn6, 375, 280, false)
end

local function FVShowBracket5()
    local pl = UnitLevel("player")
    local nl = string.char(10)
    local EK = "|cff9999ffEK:|r "
    local KL = "|cffff9999KL:|r "

    FVZonesFrame.zoneList:SetText(
        EK .. "|cffffd100The Hinterlands|r (" .. FVLvlC(40,pl) .. "40|r-" .. FVLvlC(50,pl) .. "50|r)" .. nl ..
        EK .. "|cffffd100Western Plaguelands|r (" .. FVLvlC(51,pl) .. "51|r-" .. FVLvlC(58,pl) .. "58|r)" .. nl ..
        KL .. "|cffffd100Feralas|r (" .. FVLvlC(40,pl) .. "40|r-" .. FVLvlC(50,pl) .. "50|r)" .. nl ..
        KL .. "|cffffd100Tanaris|r (" .. FVLvlC(40,pl) .. "40|r-" .. FVLvlC(50,pl) .. "50|r)" .. nl ..
        KL .. "|cffffd100Azshara|r (" .. FVLvlC(45,pl) .. "45|r-" .. FVLvlC(55,pl) .. "55|r)" .. nl ..
        KL .. "|cffffd100Maraudon|r (" .. FVLvlC(46,pl) .. "46|r-" .. FVLvlC(55,pl) .. "55|r)" .. nl ..
        KL .. "|cffffd100Felwood|r (" .. FVLvlC(48,pl) .. "48|r-" .. FVLvlC(55,pl) .. "55|r)" .. nl ..
        KL .. "|cffffd100Moonglade|r (" .. FVLvlC(55,pl) .. "55|r-" .. FVLvlC(60,pl) .. "60|r)"
    )

    FVStyleBtn(FVZonesFrame.btn1, false)
    FVStyleBtn(FVZonesFrame.btn2, false)
    FVStyleBtn(FVZonesFrame.btn3, false)
    FVStyleBtn(FVZonesFrame.btn4, false)
    FVStyleBtn(FVZonesFrame.btn5, true)
    FVStyleBtn(FVZonesFrame.btn6, false)

    FVSetBtnColor(FVZonesFrame.btn1, 25, 1, false)
    FVSetBtnColor(FVZonesFrame.btn2, 75, 1, false)
    FVSetBtnColor(FVZonesFrame.btn3, 150, 55, false)
    FVSetBtnColor(FVZonesFrame.btn4, 225, 130, false)
    FVSetBtnColor(FVZonesFrame.btn5, 300, 205, true)
    FVSetBtnColor(FVZonesFrame.btn6, 375, 280, false)
end

local function FVShowBracket6()
    local pl = UnitLevel("player")
    local nl = string.char(10)
    local EK = "|cff9999ffEK:|r "
    local KL = "|cffff9999KL:|r "

    FVZonesFrame.zoneList:SetText(
        EK .. "|cffffd100Blasted Lands|r (" .. FVLvlC(45,pl) .. "45|r-" .. FVLvlC(55,pl) .. "55|r)" .. nl ..
        EK .. "|cffffd100Burning Steppes|r (" .. FVLvlC(50,pl) .. "50|r-" .. FVLvlC(58,pl) .. "58|r)" .. nl ..
        EK .. "|cffffd100Deadwind Pass|r (" .. FVLvlC(55,pl) .. "55|r-" .. FVLvlC(60,pl) .. "60|r)" .. nl ..
        EK .. "|cffffd100Eastern Plaguelands|r (" .. FVLvlC(53,pl) .. "53|r-" .. FVLvlC(60,pl) .. "60|r)" .. nl ..
        EK .. "|cffffd100Searing Gorge|r (" .. FVLvlC(43,pl) .. "43|r-" .. FVLvlC(50,pl) .. "50|r)" .. nl ..
        KL .. "|cffffd100Silithus|r (" .. FVLvlC(55,pl) .. "55|r-" .. FVLvlC(60,pl) .. "60|r)" .. nl ..
        KL .. "|cffffd100Winterspring|r (" .. FVLvlC(53,pl) .. "53|r-" .. FVLvlC(60,pl) .. "60|r)"
    )

    FVStyleBtn(FVZonesFrame.btn1, false)
    FVStyleBtn(FVZonesFrame.btn2, false)
    FVStyleBtn(FVZonesFrame.btn3, false)
    FVStyleBtn(FVZonesFrame.btn4, false)
    FVStyleBtn(FVZonesFrame.btn5, false)
    FVStyleBtn(FVZonesFrame.btn6, true)

    FVSetBtnColor(FVZonesFrame.btn1, 25, 1, false)
    FVSetBtnColor(FVZonesFrame.btn2, 75, 1, false)
    FVSetBtnColor(FVZonesFrame.btn3, 150, 55, false)
    FVSetBtnColor(FVZonesFrame.btn4, 225, 130, false)
    FVSetBtnColor(FVZonesFrame.btn5, 300, 205, false)
    FVSetBtnColor(FVZonesFrame.btn6, 375, 280, true)
end

function FishingVolume_ToggleZonesFrame()
    if not FVZonesFrame then
        FVZonesFrame = CreateFrame("Frame", "FVZonesFrameWnd", UIParent)
        FVZonesFrame:SetWidth(260)
        FVZonesFrame:SetHeight(340)
        FVZonesFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        FVZonesFrame:SetMovable(true)
        FVZonesFrame:EnableMouse(true)
        FVZonesFrame:SetClampedToScreen(true)
        FVZonesFrame:RegisterForDrag("LeftButton")
        FVZonesFrame:SetScript("OnDragStart", function() this:StartMoving() end)
        FVZonesFrame:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
        FVZonesFrame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        FVZonesFrame:SetBackdropColor(0, 0, 0, 0.92)
        FVZonesFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
        FVZonesFrame:Hide()
        tinsert(UISpecialFrames, "FVZonesFrameWnd")

        local title = FVZonesFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        title:SetPoint("TOP", FVZonesFrame, "TOP", 0, -10)
        title:SetText("Fishing Zones")
        title:SetTextColor(1.0, 0.82, 0)

        local closeBtn = CreateFrame("Button", nil, FVZonesFrame)
        closeBtn:SetWidth(14) closeBtn:SetHeight(14)
        closeBtn:SetPoint("TOPRIGHT", FVZonesFrame, "TOPRIGHT", -4, -4)
        closeBtn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        closeBtn:SetBackdropColor(0, 0, 0, 1)
        closeBtn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
        local xStr = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        xStr:SetAllPoints(closeBtn)
        xStr:SetJustifyH("CENTER") xStr:SetJustifyV("MIDDLE")
        xStr:SetText("X") xStr:SetTextColor(0.7, 0.2, 0.2)
        closeBtn:SetScript("OnClick", function() FVZonesFrame:Hide() end)
        closeBtn:SetScript("OnEnter", function() this:SetBackdropBorderColor(1, 0.2, 0.2, 1) end)
        closeBtn:SetScript("OnLeave", function() this:SetBackdropBorderColor(0.2, 0.2, 0.2, 1) end)

        local skillText = FVZonesFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        skillText:SetPoint("TOP", FVZonesFrame, "TOP", 0, -22)
        FVZonesFrame.skillText = skillText

        local topDiv = FVZonesFrame:CreateTexture(nil, "ARTWORK")
        topDiv:SetHeight(1)
        topDiv:SetPoint("TOPLEFT",  FVZonesFrame, "TOPLEFT",  10, -34)
        topDiv:SetPoint("TOPRIGHT", FVZonesFrame, "TOPRIGHT", -10, -34)
        topDiv:SetTexture(0.3, 0.3, 0.3, 1)

        local btn1 = CreateFrame("Button", nil, FVZonesFrame, "UIPanelButtonTemplate")
        btn1:SetWidth(240) btn1:SetHeight(20)
        btn1:SetPoint("TOPLEFT", FVZonesFrame, "TOPLEFT", 10, -38)
        btn1:SetText(FVBracketLabel(1, 25))
        FVStyleBtn(btn1, false)
        btn1:SetScript("OnClick", function() FVShowBracket1() end)

        local btn2 = CreateFrame("Button", nil, FVZonesFrame, "UIPanelButtonTemplate")
        btn2:SetWidth(240) btn2:SetHeight(20)
        btn2:SetPoint("TOPLEFT", FVZonesFrame, "TOPLEFT", 10, -58)
        btn2:SetText(FVBracketLabel(1, 75))
        FVStyleBtn(btn2, false)
        btn2:SetScript("OnClick", function() FVShowBracket2() end)

        local btn3 = CreateFrame("Button", nil, FVZonesFrame, "UIPanelButtonTemplate")
        btn3:SetWidth(240) btn3:SetHeight(20)
        btn3:SetPoint("TOPLEFT", FVZonesFrame, "TOPLEFT", 10, -78)
        btn3:SetText(FVBracketLabel(55, 150))
        FVStyleBtn(btn3, false)
        btn3:SetScript("OnClick", function() FVShowBracket3() end)

        local btn4 = CreateFrame("Button", nil, FVZonesFrame, "UIPanelButtonTemplate")
        btn4:SetWidth(240) btn4:SetHeight(20)
        btn4:SetPoint("TOPLEFT", FVZonesFrame, "TOPLEFT", 10, -98)
        btn4:SetText(FVBracketLabel(130, 225))
        FVStyleBtn(btn4, false)
        btn4:SetScript("OnClick", function() FVShowBracket4() end)

        local btn5 = CreateFrame("Button", nil, FVZonesFrame, "UIPanelButtonTemplate")
        btn5:SetWidth(240) btn5:SetHeight(20)
        btn5:SetPoint("TOPLEFT", FVZonesFrame, "TOPLEFT", 10, -118)
        btn5:SetText(FVBracketLabel(205, 300))
        FVStyleBtn(btn5, false)
        btn5:SetScript("OnClick", function() FVShowBracket5() end)

        local btn6 = CreateFrame("Button", nil, FVZonesFrame, "UIPanelButtonTemplate")
        btn6:SetWidth(240) btn6:SetHeight(20)
        btn6:SetPoint("TOPLEFT", FVZonesFrame, "TOPLEFT", 10, -138)
        btn6:SetText(FVBracketLabel(280, 375))
        FVStyleBtn(btn6, false)
        btn6:SetScript("OnClick", function() FVShowBracket6() end)

        local div = FVZonesFrame:CreateTexture(nil, "ARTWORK")
        div:SetHeight(1)
        div:SetPoint("TOPLEFT",  FVZonesFrame, "TOPLEFT",  10, -162)
        div:SetPoint("TOPRIGHT", FVZonesFrame, "TOPRIGHT", -10, -162)
        div:SetTexture(0.3, 0.3, 0.3, 1)

        local zoneList = FVZonesFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        zoneList:SetPoint("TOPLEFT",     FVZonesFrame, "TOPLEFT",  10, -172)
        zoneList:SetPoint("BOTTOMRIGHT", FVZonesFrame, "BOTTOMRIGHT", -10, 10)
        zoneList:SetJustifyH("LEFT")
        zoneList:SetJustifyV("TOP")
        zoneList:SetNonSpaceWrap(true)
        FVZonesFrame.zoneList = zoneList

        FVZonesFrame.btn1 = btn1
        FVZonesFrame.btn2 = btn2
        FVZonesFrame.btn3 = btn3
        FVZonesFrame.btn4 = btn4
        FVZonesFrame.btn5 = btn5
        FVZonesFrame.btn6 = btn6
    end

    if FVZonesFrame:IsVisible() then
        FVZonesFrame:Hide()
    else
        FVZonesFrame:ClearAllPoints()
        FVZonesFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        FVUpdateSkill()
        FVShowBracket1()
        FVZonesFrame:Show()
    end
end
