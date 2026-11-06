-- Vanilla widgets use plain geometry; no clipping, masks, secret values or retail templates.
local ns = DoesItDieVanilla
if not ns.ready then return end
local db, testUntil
local widgets = {}
local colors = { [1]={1,.65,.25}, [2]={1,.9,.3}, [4]={1,.3,.1}, [8]={.3,1,.3},
    [16]={.3,.7,1}, [32]={.7,.3,1}, [64]={.8,.5,1} }

local function resolve(path)
    local value = _G
    for key in string.gmatch(path or "", "[^.]+") do
        if type(value) ~= "table" then return end
        value = value[key]
    end
    if value ~= _G then return value end
end
ns.resolveFrame = resolve

local function make(host, isTarget)
    local frame = CreateFrame("Frame", nil, host)
    frame:SetAllPoints(host)
    frame:SetFrameLevel(host:GetFrameLevel() + 10)
    local iconFrame = CreateFrame("Frame", isTarget and "DoesItDieVanillaSkull" or nil,
        isTarget and UIParent or frame)
    if isTarget then iconFrame:SetFrameStrata("HIGH") end
    iconFrame:SetFrameLevel(host:GetFrameLevel() + 30)
    iconFrame:Hide()
    local icon = iconFrame:CreateTexture(nil, "OVERLAY")
    -- Ship the asset ourselves: client distributions differ in their UI archives.
    local textureLoaded = icon:SetTexture("Interface\\AddOns\\DoesItDie\\Textures\\Skull.tga")
    icon:SetTexCoord(0, 1, 0, 1)
    local label = frame:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    label:SetPoint("CENTER", frame, "CENTER", 0, 0)
    local w = { frame=frame, host=host, icon=icon, iconFrame=iconFrame, label=label,
        textureLoaded=textureLoaded, segments={} }
    table.insert(widgets, w)
    return w
end

local function hide(w)
    if w then w.frame:Hide(); w.iconFrame:Hide() end
end

local function anchorIcon(w, kind)
    local size = kind == "target" and math.min(db.skullSize, 64) or 18
    w.icon:SetWidth(size)
    w.icon:SetHeight(size)
    w.iconFrame:SetWidth(size)
    w.iconFrame:SetHeight(size)
    w.iconFrame:ClearAllPoints()
    w.icon:ClearAllPoints()
    local portrait = kind == "target" and (resolve(db.customIconAnchor)
        or (w.pfFrame and w.pfFrame.portrait and w.pfFrame.portrait:IsVisible() and w.pfFrame.portrait)
        or (not w.pfFrame and not resolve(db.customHealthBar) and
            (TargetFramePortrait or TargetPortrait or (TargetFrame and TargetFrame.portrait))))
    if portrait then
        w.iconFrame:SetPoint("CENTER", portrait, "CENTER", db.skullOffsetX, db.skullOffsetY)
    else
        w.iconFrame:SetPoint("RIGHT", w.host, "LEFT", -3, 0)
    end
    w.icon:SetPoint("CENTER", w.iconFrame, "CENTER", 0, 0)
end

local function draw(w, unit, kind)
    local host = w.host
    if kind == "target" and not db.targetEnabled then return hide(w) end
    if not host:IsVisible() or not UnitExists(unit) or UnitIsDead(unit)
        or not UnitCanAttack("player", unit) then return hide(w) end
    local list, damage = ns.dotBreakdownForUnit(unit)
    if damage <= 0 then return hide(w) end
    local hp, maximum = ns.health(unit)
    w.frame:Show()
    anchorIcon(w, kind)
    local showSkull, showLabel, showMarkers = db.showSkull, db.showLabel, db.showMarkers
    if kind == "plate" then
        showSkull, showLabel, showMarkers = db.plateShowSkull, db.plateShowLabel, db.plateShowMarkers
    elseif kind == "focus" then
        showSkull, showLabel, showMarkers = db.focusShowSkull, db.focusShowLabel, db.focusShowMarkers
    end
    if showSkull and hp and damage >= hp then
        w.icon:Show(); w.iconFrame:Show()
    else w.icon:Hide(); w.iconFrame:Hide() end
    if showLabel then
        w.label:ClearAllPoints()
        if kind == "target" then
            local name = w.pfFrame and host or (not resolve(db.customHealthBar)
                and (TargetFrameName or (TargetFrame and TargetFrame.name)))
            w.label:SetPoint("BOTTOM", name or host, "TOP", 0, 8)
        elseif kind == "plate" then
            local cast = w.plateLayout and w.plateLayout.castbar
            w.label:SetPoint("TOP", cast and cast:IsVisible() and cast or host, "BOTTOM", 0, -6)
        else
            w.label:SetPoint("CENTER", w.frame, "CENTER", 0, 0)
        end
        w.label:SetText(string.format("DoTs: %d%s", math.floor(damage + .5), hp and "" or " (HP unknown)"))
        w.label:Show()
    else w.label:Hide() end
    for _, texture in ipairs(w.segments) do texture:Hide() end
    if not maximum or not showMarkers then return end
    local width, height = host:GetWidth(), host:GetHeight()
    -- The shaded area covers the final part of the current health fill that DoTs can remove.
    local config = w.pfFrame and w.pfFrame.config
    -- Stock 1.12 StatusBars expose SetOrientation but not GetOrientation.
    local vertical = config and config.verticalbar == "1"
    if kind == "plate" and w.plateLayout then
        vertical = pfUI_config and pfUI_config.nameplates
            and pfUI_config.nameplates.verticalhealth == "1"
    end
    local inverted = config and config.invert_healthbar == "1"
    local length = vertical and height or width
    local right = length * math.min(1, hp / maximum)
    local start = length - right
    for i, entry in ipairs(list) do
        local span = math.min(right, length * entry.damage / maximum)
        if span > 0 then
            local texture = w.segments[i]
            if not texture then
                texture = w.frame:CreateTexture(nil, "ARTWORK")
                texture:SetTexture("Interface\\Buttons\\WHITE8X8")
                w.segments[i] = texture
            end
            local color = colors[entry.school] or colors[32]
            texture:SetVertexColor(color[1], color[2], color[3], db.fillOpacity / 200)
            texture:ClearAllPoints()
            local offset = inverted and start or math.max(0, right-span)
            if vertical then
                texture:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, offset)
                texture:SetWidth(width); texture:SetHeight(span)
            else
                texture:SetPoint("TOPLEFT", host, "TOPLEFT", offset, 0)
                texture:SetWidth(span); texture:SetHeight(height)
            end
            texture:Show()
            right = right-span
            start = start+span
        end
    end
end

local target, focus
local plates = {}
local function pfUnit(unit)
    local frame = pfUI and pfUI.uf and pfUI.uf[unit]
    if frame and frame.hp and frame.hp.bar then return frame end
end
local function move(w, bar, pfFrame)
    if w.host ~= bar then
        hide(w)
        w.frame:SetParent(bar)
        w.frame:ClearAllPoints(); w.frame:SetAllPoints(bar)
        w.frame:SetFrameLevel(bar:GetFrameLevel() + 10)
        w.host = bar
    end
    w.pfFrame = pfFrame
end
local function attach()
    local custom = resolve(db and db.customHealthBar)
    local pfTarget = not custom and pfUnit("target")
    local bar = custom or (pfTarget and pfTarget.hp.bar) or TargetFrameHealthBar
    if bar then
        if not target then target = make(bar, true) end
        move(target, bar, pfTarget)
    end
    local customFocus = resolve(db and db.customFocusHealthBar)
    local pfFocus = not customFocus and pfUnit("focus")
    local focusBar = customFocus or (pfFocus and pfFocus.hp.bar) or FocusFrameHealthBar
    if focusBar then
        if not focus then focus = make(focusBar) end
        move(focus, focusBar, pfFocus)
    elseif focus then
        hide(focus)
        focus = nil
    end
    return bar ~= nil
end

local function plateBar(plate)
    local replacement = plate.nameplate
    if replacement and replacement.health then
        if replacement.health:IsVisible() then return replacement.health, replacement end
        return nil -- pfUI owns this plate; never decorate its hidden originals.
    end
    if plate.healthbar and plate.healthbar:IsVisible() then return plate.healthbar end
    local original = replacement and replacement.original
    local bar = original and (original.health or original.healthbar)
    if bar and bar:IsVisible() then return bar end
    -- ClassicAPI returns the engine plate. The stock health bar is a direct child.
    -- Skip our own overlay frames and avoid guessing by a mob's display name.
    local children = { plate:GetChildren() }
    for _, child in ipairs(children) do
        if child:GetObjectType() == "StatusBar" and child:IsVisible() then return child end
    end
end

local function refresh()
    if not db then return end
    ns.tracking.housekeep(GetTime())
    local inRaid = GetNumRaidMembers() > 0
    local blocked = (inRaid and db.disableInRaid)
        or (not inRaid and GetNumPartyMembers() > 0 and db.disableInParty)
    if blocked then
        for _, w in ipairs(widgets) do hide(w) end
        return
    end
    attach() -- pfUI can create or replace its unit frames after our ADDON_LOADED.
    if target then draw(target, "target", "target") end
    if focus then
        if db.focusMode ~= "off" then draw(focus, "focus", "focus") else hide(focus) end
    end
    for _, w in pairs(plates) do hide(w) end
    if db.nameplateMode ~= "off" then
        for _, unit in ipairs(C_NamePlate.GetNamePlateGUIDs()) do
            local plate = C_NamePlate.GetNamePlateForGUID(unit)
            if plate and UnitExists(unit) then
                local bar, layout = plateBar(plate)
                if bar then
                    local w = plates[plate]
                    if not w or w.host ~= bar then
                        hide(w)
                        w = make(bar)
                        plates[plate] = w
                    end
                    w.plateLayout = layout
                    draw(w, unit, "plate")
                end
            end
        end
    end
    if testUntil and GetTime() < testUntil and target then
        target.frame:Show()
        anchorIcon(target, "target")
        target.icon:Show()
        target.iconFrame:Show()
    end
end

ns.display = {
    setDb=function(value) db=value end,
    attach=attach,
    hasHealthBar=function() return target ~= nil end,
    animate=function() end,
    forgetTracedDamage=function() end,
    testSkull=function(seconds)
        testUntil=GetTime()+seconds; refresh()
        if target then
            ns.print("Skull test: texture loaded=" .. tostring(target.textureLoaded)
                .. " overlay visible=" .. tostring(target.iconFrame:IsVisible())
                .. " size=" .. tostring(target.iconFrame:GetWidth()))
        end
    end,
    schoolColors=colors,
    skullStatus=function()
        local hp = ns.health("target")
        local damage = ns.tracking.targetRemainingDamage()
        ns.print("Skull enabled=" .. tostring(db.showSkull) .. " damage=" .. tostring(damage)
            .. " HP=" .. tostring(hp) .. " overlay=" .. tostring(target and target.iconFrame:IsShown())
            .. " texture loaded=" .. tostring(target and target.textureLoaded))
        ns.print("Target frame: " .. (target and target.pfFrame and "pfUI" or "Blizzard/custom"))
    end,
}
ns.refresh = refresh
ns.playFlash = function() end
ns.probeNameplates = function()
    ns.print("ClassicAPI reports " .. #C_NamePlate.GetNamePlates() .. " nameplate(s). Stock bars supported; /did status for API details.")
end
ns.toggleExecuteProbe = function() ns.print("The Forever execute probe is not included in this Vanilla port.") end
