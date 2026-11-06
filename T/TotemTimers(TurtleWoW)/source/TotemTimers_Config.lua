local TT = _G.TotemTimersAddon

local function ClampScale(value)
    if value < 0.5 then
        return 0.5
    elseif value > 1.5 then
        return 1.5
    end

    return value
end

local function ClampThreshold(value)
    if value < 1 then
        return 1
    elseif value > 30 then
        return 30
    end

    return value
end

SLASH_TOTEMTIMERS1 = "/tt"
SlashCmdList["TOTEMTIMERS"] = function(msg)
    msg = string.lower(msg or "")

    if msg == "lock" then
        TotemTimersDB.locked = not TotemTimersDB.locked
        TT.UpdateAnchorState()
        print("TotemTimers anchor " .. (TotemTimersDB.locked and "locked" or "unlocked"))
    elseif msg == "compact" then
        TotemTimersDB.compact = not TotemTimersDB.compact
        TT.ApplyLayout()
        print("TotemTimers compact mode " .. (TotemTimersDB.compact and "enabled" or "disabled"))
    elseif msg == "vertical" then
        TotemTimersDB.vertical = not TotemTimersDB.vertical
        TT.ApplyLayout()
        print("TotemTimers vertical layout " .. (TotemTimersDB.vertical and "enabled" or "disabled"))
    elseif string.find(msg, "scale", 1, true) == 1 then
        local _, _, scaleText = string.find(msg, "^scale%s+([%d%.]+)$")
        local value = tonumber(scaleText)
        if value then
            TotemTimersDB.scale = ClampScale(value)
            TT.ApplyLayout()
            print(string.format("TotemTimers scale set to %.2f", TotemTimersDB.scale))
        else
            print("/tt scale 0.5 - 1.5")
        end
    elseif string.find(msg, "twist", 1, true) == 1 then
        local _, _, thresholdText = string.find(msg, "^twist%s+(%d+)$")
        local value = tonumber(thresholdText)
        if value then
            TotemTimersDB.twistThreshold = ClampThreshold(value)
            TT.UpdateTwistHelper()
            print("TotemTimers twist warning set to " .. TotemTimersDB.twistThreshold .. " seconds")
        else
            print("/tt twist 1 - 30")
        end
    elseif msg == "reset" then
        TT.ResetAnchorPosition()
        TotemTimersDB.scale = 1
        TotemTimersDB.twistThreshold = 10
        TT.ApplyLayout()
        TT.UpdateTwistHelper()
        print("TotemTimers position, scale, and twist warning reset")
    elseif msg == "test" then
        TT.ACTIVE.Fire = {
            element = "Fire",
            name = "Searing Totem",
            start = GetTime(),
            duration = 30,
        }
        TT.UpdateButton("Fire", 30, "Searing Totem")
        TT.UpdateTwistHelper()
        print("TotemTimers test timer started")
    else
        print("/tt lock | compact | vertical | scale <0.5-1.5> | twist <1-30> | reset | test")
    end
end
