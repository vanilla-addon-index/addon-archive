local Addon = ForgedPetHappiness or {}
ForgedPetHappiness = Addon

Addon.DEFAULTS = {
    point = "CENTER",
    x = 0,
    y = -180,
    width = 220,
    height = 16,
    locked = false,
    hidden = false,
    value = 100,
}

function Addon.Clamp(value, minVal, maxVal)
    if value < minVal then
        return minVal
    elseif value > maxVal then
        return maxVal
    end
    return value
end