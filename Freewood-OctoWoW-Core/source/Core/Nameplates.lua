-- Freewood-OctoWoW-Core: Namensplaketten anpassen (Balkenbreite, Name, Level, Rahmen) und die zugehoerigen Einstellungen.
-- Frueher im Quest-Modul (QuestTargetMarks/QuestPlateSettings); laeuft jetzt ohne Quest-Modul. Werte: FW.Plates.Get/Set,
-- gespeichert in den Core-Einstellungen. Die Quest-Symbole (Logo) bleiben im Quest-Modul.

local FW = _G.Freewood
if not FW then return end
local UI = FW.UI

local P = {}
FW.Plates = P

local defaults = { plateCustom = false, plateW = 160, plateBorderOff = false, plateNameSize = 0, plateLvlGap = 2, plateY = 0 }

local function Store()
    local s = FW.settings
    if not s then return nil end
    if type(s.plates) ~= "table" then s.plates = {} end
    return s.plates
end

function P.Get(key)
    local st = Store()
    local v = st and st[key]
    if v == nil then return defaults[key] end
    return v
end

function P.Set(key, value)
    local st = Store()
    if not st then return end
    st[key] = value
    FW:Fire("PLATES_CHANGED", key)
    FW:Fire("QUEST_PLATE_CHANGED", key)     -- Quest-Modul: Symbole neu setzen
    P.dirty = true
end

-- Alte Werte aus den Quest-Einstellungen uebernehmen (einmalig, nur wenn im Core noch nichts steht)
function P.Migrate(old)
    local st = Store()
    if not st or type(old) ~= "table" then return end
    for k in pairs(defaults) do
        if st[k] == nil and old[k] ~= nil and type(old[k]) == type(defaults[k]) then st[k] = old[k] end
    end
end

------------------------------------------------------------------------
-- Anpassung
-- Wie ShaguPlates: Name und Level werden als EIGENE Texte auf einem eigenen Rahmen gezeichnet, die Originaltexte der Plakette nur
-- ausgeblendet (Hide). SetFont/SetScale auf den Originalteilen stuerzt den Client ab, auf eigenen Texten nicht.
-- Am Lebensbalken aendern wir nur Breite/Hoehe/Anker, am Rahmen nur Hide/Show. Ausgangswerte merkt sich das Addon pro Plakette.
------------------------------------------------------------------------

local BAR_W = 160
local FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"
local origs = setmetatable({}, { __mode = "k" })
local overlays = setmetatable({}, { __mode = "k" })
local customOff = false
P.Overlays = overlays

local function LookParts(plate)
    local bar = plate:GetChildren()
    local border, glow, name, level = plate:GetRegions()
    if not (bar and bar.SetWidth and name and name.GetFont and level and level.GetText) then return nil end
    return bar, border, name, level, glow
end

local function SavePoint(f)
    local pt, rel, relPt, x, y = f:GetPoint(1)
    return { pt, rel, relPt, x or 0, y or 0 }
end

local function Overlay(plate, font, size, flags)
    local ov = overlays[plate]
    if ov then return ov end
    local ok, f = pcall(_G.CreateFrame, "Frame", nil, plate)
    if not ok or not f then return nil end
    if f.EnableMouse then f:EnableMouse(false) end
    f:SetFrameStrata("HIGH")
    ov = { frame = f, size = size }
    ov.hl = f:CreateTexture(nil, "BACKGROUND")
    ov.hl:SetTexture(1, 1, 1, 0.3)
    ov.hl:Hide()
    ov.name = f:CreateFontString(nil, "OVERLAY")
    ov.name:SetFont(font, size, flags)
    ov.level = f:CreateFontString(nil, "OVERLAY")
    ov.level:SetFont(font, size, flags)
    overlays[plate] = ov
    return ov
end

local function CopyText(src, dst)
    local t = src:GetText()
    dst:SetText(t or "")
    local r, g, b, a = src:GetTextColor()
    if r then dst:SetTextColor(r, g, b, a or 1) end
end

local function ApplyLook(plate)
    local on = (not customOff) and P.Get("plateCustom") == true
    local o = origs[plate]
    if not on and not o then return end
    local bar, border, name, level, glow = LookParts(plate)
    if not bar then return end
    if not o then
        local path, size, flags = name:GetFont()
        o = { w = bar:GetWidth(), h = bar:GetHeight(), barPt = SavePoint(bar),
              font = path or FALLBACK_FONT, size = size or 12, flags = flags,
              glowAlpha = glow and glow.GetAlpha and glow:GetAlpha() or 1 }
        origs[plate] = o
    end
    local ov = overlays[plate]
    if not on then
        bar:SetWidth(o.w) bar:SetHeight(o.h)
        local b = o.barPt
        if b[1] then bar:ClearAllPoints() bar:SetPoint(b[1], b[2], b[3], b[4], b[5]) end
        if border then border:Show() end
        name:Show() level:Show()
        if glow and glow.SetAlpha then glow:SetAlpha(o.glowAlpha or 1) end
        if ov then ov.frame:Hide() end
        origs[plate] = nil
        return
    end
    local w = math.max(40, math.min(200, tonumber(P.Get("plateW")) or BAR_W))
    local h = math.floor(o.h * w / o.w * 10 + 0.5) / 10
    if math.abs(bar:GetWidth() - w) > 0.4 then bar:SetWidth(w) end
    if math.abs(bar:GetHeight() - h) > 0.4 then bar:SetHeight(h) end
    -- Balken mittig halten: Ausgangs-Anker um die halbe Breitendifferenz verschieben
    local b = o.barPt
    if b[1] then
        local dx = (o.w - w) / 2
        local x = b[4]
        if b[1]:find("LEFT") then x = x + dx elseif b[1]:find("RIGHT") then x = x - dx end
        bar:ClearAllPoints()
        bar:SetPoint(b[1], b[2], b[3], x, b[5] + (tonumber(P.Get("plateY")) or 0))
    end
    if border then
        if P.Get("plateBorderOff") == true then border:Hide() else border:Show() end
    end
    -- eigene Texte fuer Name und Level
    local ns = tonumber(P.Get("plateNameSize")) or 0
    local size = (ns >= 8) and ns or o.size
    ov = Overlay(plate, o.font, size, o.flags)
    if not ov then return end
    if ov.size ~= size then
        ov.size = size
        pcall(ov.name.SetFont, ov.name, o.font, size, o.flags)
        pcall(ov.level.SetFont, ov.level, o.font, size, o.flags)
    end
    ov.frame:Show()
    if name:IsShown() then name:Hide() end
    if level:IsShown() then level:Hide() end
    ov.name:ClearAllPoints()
    ov.name:SetPoint("BOTTOM", bar, "TOP", 0, 2)
    ov.level:ClearAllPoints()
    ov.level:SetPoint("LEFT", bar, "RIGHT", tonumber(P.Get("plateLvlGap")) or 2, 0)
    CopyText(name, ov.name)
    CopyText(level, ov.level)
    -- Mouseover-Leuchten: das Original (zu gross) unsichtbar, dafuer ein eigenes Rechteck genau um den Balken
    if glow and glow.SetAlpha then
        if glow:GetAlpha() ~= 0 then glow:SetAlpha(0) end
        ov.hl:ClearAllPoints()
        ov.hl:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
        ov.hl:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
        if glow:IsShown() then ov.hl:Show() else ov.hl:Hide() end
    end
end

P.ApplyLook = ApplyLook

local function PlateList()
    local NP = _G.C_NamePlate
    if not (NP and NP.GetNamePlates) then return nil end
    local ok, plates = pcall(NP.GetNamePlates)
    if ok and type(plates) == "table" then return plates end
    return nil
end

-- Alle sichtbaren Plaketten durchgehen (wenige, alle 0,25 s); ist die Anpassung aus und nichts mehr veraendert, ruht es
local f = _G.CreateFrame("Frame")
local acc = 0
local anyChanged = false
f:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + (elapsed or 0)
    if acc < 0.25 then return end
    acc = 0
    local on = P.Get("plateCustom") == true
    if not on and not anyChanged then return end
    local plates = PlateList()
    if not plates then return end
    for _, plate in ipairs(plates) do pcall(ApplyLook, plate) end
    anyChanged = on
end)
local function Touch() anyChanged = true end
FW:On("PLATES_CHANGED", Touch, P)
if FW.RegisterEvent then
    FW:RegisterEvent("NAME_PLATE_UNIT_ADDED", function() acc = 1 end, P)   -- neue Plakette sofort anpassen
end

------------------------------------------------------------------------
-- Einstellungen (Reiter "Quests und Hinweise")
------------------------------------------------------------------------

if UI and UI.RegisterSettingsSection then
    local function StepRow(parent, onMinus, onPlus)
        local row = CreateFrame("Frame", nil, parent)
        row:SetHeight(30)
        local plus = UI.CreateButton(row, "+", 24, 22, onPlus, "default")
        plus:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        local minus = UI.CreateButton(row, "-", 24, 22, onMinus, "default")
        minus:SetPoint("RIGHT", plus, "LEFT", -4, 0)
        local lbl = UI.CreateLabel(row, "", { size = 12 })
        lbl:SetPoint("LEFT", row, "LEFT", 0, 0)
        lbl:SetPoint("RIGHT", minus, "LEFT", -8, 0)
        lbl:SetWordWrap(true)
        return row, lbl
    end

    local function Step(key, lo, hi, def, d, zero)
        local v = tonumber(P.Get(key)) or def
        local n = v + d
        if zero and v == 0 and d > 0 then n = lo elseif zero and v <= lo and d < 0 then n = 0 end
        P.Set(key, math.max(zero and 0 or lo, math.min(hi, n)))
    end

    UI:RegisterSettingsSection("plates", {
        category = "quest",
        order = 120,
        height = 330,
        build = function(parent)
            local L = FW.L
            local f2, stack = UI.CreateSection(parent, L.QUEST_PLATESET_HEADER)
            local note = UI.CreateLabel(f2, L.QUEST_PLATESET_NOTE, { size = 11, color = "textDim", justifyV = "TOP" })
            stack:Add(note, { fit = true, gap = 8 })
            local boxes = {}
            local function Box(key, label)
                local cb = UI.CreateCheckbox(f2, label, function() return P.Get(key) == true end,
                    function(on) P.Set(key, on and true or false) end)
                stack:Add(cb, { fit = true, gap = 4 })
                boxes[#boxes + 1] = cb
            end
            Box("plateCustom", L.QUEST_OPT_PLATECUSTOM)
            Box("plateBorderOff", L.QUEST_OPT_PLATEBORDER)
            local labels = {}
            local function Row(key, lo, hi, def, step, zero, fmt)
                local row, lbl = StepRow(f2, function() Step(key, lo, hi, def, -step, zero) end, function() Step(key, lo, hi, def, step, zero) end)
                stack:Add(row, { height = 30, stretch = true, gap = 4 })
                labels[#labels + 1] = function() lbl:SetText(fmt(tonumber(P.Get(key)) or def)) end
            end
            Row("plateW", 40, 200, 160, 10, false, function(v) return string.format(L.QUEST_PLATEW_LABEL, v) end)
            Row("plateNameSize", 8, 20, 0, 1, true, function(v)
                return string.format(L.QUEST_PLATENAME_LABEL, v >= 8 and tostring(v) or L.QUEST_PLATENAME_STD)
            end)
            Row("plateLvlGap", -10, 20, 2, 1, false, function(v) return string.format(L.QUEST_PLATELVL_LABEL, v) end)
            Row("plateY", -40, 40, 0, 2, false, function(v) return string.format(L.QUEST_PLATEY_LABEL, v) end)
            function f2.Refresh()
                for _, cb in ipairs(boxes) do cb:Refresh() end
                for _, fn in ipairs(labels) do fn() end
                stack:Layout()
            end
            FW:On("PLATES_CHANGED", function() if f2:IsVisible() then f2.Refresh() end end, f2)
            stack:Layout()
            return f2
        end,
        refresh = function(frame) frame.Refresh() end,
    })
end
