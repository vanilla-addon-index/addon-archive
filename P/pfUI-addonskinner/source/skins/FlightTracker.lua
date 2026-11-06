pfUI.addonskinner:RegisterSkin("FlightTracker", function()
    local penv = pfUI:GetEnvironment()
    local StripTextures = penv.StripTextures
    local CreateBackdrop = penv.CreateBackdrop
    local CreateBackdropShadow = penv.CreateBackdropShadow
    local SkinScrollbar = penv.SkinScrollbar
    local font = pfUI_config.global.font_default

    local function ApplyBackdrop(frame)
        if not frame or frame.pfUI_skinned then return false end
        StripTextures(frame)
        CreateBackdrop(frame)
        CreateBackdropShadow(frame)
        frame.pfUI_skinned = true
        return true
    end

    local function UpdateFonts(fontStrings)
        for _, fontString in pairs(fontStrings) do
            if fontString then
                local _, size, flags = fontString:GetFont()
                fontString:SetFont(font, size or 12, flags or "")
            end
        end
    end

    local function SetOutlineFont(fontString, size)
        if fontString then
            fontString:SetFont(font, size, "OUTLINE")
        end
    end

    local function HookFunction(object, funcName, callback)
        if not object or not object[funcName] then return end
        local original = object[funcName]
        object[funcName] = function(...)
            local result = original(unpack(arg))
            callback()
            return result
        end
    end

    -- Timer Frame
    local function SkinTimerFrame()
        local timer = FlightTrackerTimer
        if not timer or not ApplyBackdrop(timer) then return end

        SetOutlineFont(timer.destText, 12)
        SetOutlineFont(timer.zoneText, 10)
        SetOutlineFont(timer.timerText, 16)

        local originalOnSizeChanged = timer:GetScript("OnSizeChanged")
        timer:SetScript("OnSizeChanged", function()
            if originalOnSizeChanged then originalOnSizeChanged() end
            local scale = math.max(this:GetHeight() / 64, 0.8)
            SetOutlineFont(this.destText, 12 * scale)
            SetOutlineFont(this.zoneText, 10 * scale)
            SetOutlineFont(this.timerText, 16 * scale)
        end)

        -- Respect current hideBorder state after skinning
        if FlightTrackerDB and FlightTrackerDB.settings and FlightTrackerDB.settings.hideBorder then
            if timer.backdrop then timer.backdrop:Hide() end
            if timer.backdrop_shadow then timer.backdrop_shadow:Hide() end
        end
    end

    -- Main GUI
    local function SkinMainGUI()
        local main = FlightTrackerMain
        if not main then return end

        ApplyBackdrop(main)
        UpdateFonts({
            main.statFlights,
            main.statTime,
            main.statGold,
            main.statLongest,
            main.statLongestRoute
        })
        ApplyBackdrop(FlightTrackerOptionsMenu)
    end

    -- Checklist
    local function SkinChecklist()
        local cl = FlightTrackerChecklist
        if not cl then return end

        ApplyBackdrop(cl)

        local scrollBar = getglobal("FlightTrackerChecklistScrollScrollBar")
        if scrollBar then
            SkinScrollbar(scrollBar)
        end
    end

    SkinTimerFrame()
    if FlightTrackerMain then SkinMainGUI() end
    if FlightTrackerChecklist then SkinChecklist() end

    if FlightTracker then
        if FlightTracker.GUI then
            HookFunction(FlightTracker.GUI, "Create", SkinMainGUI)
        end
        HookFunction(FlightTracker, "CreateTimerFrame", SkinTimerFrame)
        if FlightTracker.Checklist then
            HookFunction(FlightTracker.Checklist, "Create", SkinChecklist)
        end

        FlightTracker.ApplyTimerBorderVisibility = function(self)
            local timer = FlightTrackerTimer
            if not timer then return end
            if FlightTrackerDB.settings.hideBorder then
                timer:SetBackdrop(nil)
                if timer.backdrop then timer.backdrop:Hide() end
                if timer.backdrop_shadow then timer.backdrop_shadow:Hide() end
                timer.resizer:Hide()
                timer.help:Hide()
            else
                if timer.backdrop then timer.backdrop:Show() end
                if timer.backdrop_shadow then timer.backdrop_shadow:Show() end
                timer.resizer:Show()
                timer.help:Show()
            end
        end
    end

    pfUI.addonskinner:UnregisterSkin("FlightTracker")
end)
