-- Freewood-Core: Tooltip-Einstellungen (Standard fuer alle Module)
-- Das Freewood-Design und der Tooltip an der Maus gehoeren dem Core. Module melden ihre Zusatzinfos mit
-- FW.Tooltips.RegisterOption(key, labelKey, { default = true, order = 10, available = function() return true end }) an;
-- sie erscheinen dann unter Einstellungen -> Tooltips. Lesen: FW.Tooltips.Get(key), Schreiben: FW.Tooltips.Set(key, wert).
-- Aenderungen melden sich ueber FW:Fire("QUEST_TIP_CHANGED", key) (Name bleibt aus Kompatibilitaet zu den Modulen).

local FW = _G.Freewood
if not FW then return end

local T = {}
FW.Tooltips = T

local BG = { 0.059, 0.075, 0.122, 0.97 }
local GOLD = { 0.616, 0.471, 0.149, 1 }
local WHITE = "Interface\\Buttons\\WHITE8X8"
local TIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "FreewoodCmpTip1", "FreewoodCmpTip2" }

local defaults = { tipSkin = false, tipCursor = false }
local options = {}                      -- Zusatzoptionen der Module

local function Store()
    local s = FW.settings
    if not s then return nil end
    if type(s.tooltips) ~= "table" then s.tooltips = {} end
    return s.tooltips
end

function T.Raw(key)
    local st = Store()
    return st and st[key]
end

function T.Get(key)
    local st = Store()
    local v = st and st[key]
    if v == nil then return defaults[key] end
    return v
end

function T.Set(key, value)
    local st = Store()
    if not st then return end
    st[key] = value
    FW:Fire("QUEST_TIP_CHANGED", key)
end

-- Alte Werte uebernehmen (Modul ruft es einmal mit seinen gespeicherten Werten auf); nur wenn im Core noch nichts steht
function T.Migrate(old)
    local st = Store()
    if not st or type(old) ~= "table" then return end
    for k, v in pairs(old) do
        if type(k) == "string" and k:sub(1, 3) == "tip" and st[k] == nil and type(v) == "boolean" then
            st[k] = v
        end
    end
end

function T.RegisterOption(key, labelKey, def)
    def = def or {}
    if defaults[key] == nil then
        if type(def.default) == "number" then defaults[key] = def.default else defaults[key] = def.default ~= false end
    end
    for _, o in ipairs(options) do
        if o.key == key then return end
    end
    options[#options + 1] = { key = key, label = labelKey, order = def.order or 100, available = def.available,
        min = def.min, max = def.max, step = def.step }
    table.sort(options, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.key < b.key
    end)
    if T.RefreshSettings then T.RefreshSettings() end
end

------------------------------------------------------------------------
-- Design
------------------------------------------------------------------------

local function SkinOn(tt)
    if not tt.SetBackdrop then return end
    tt:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    tt:SetBackdropColor(BG[1], BG[2], BG[3], BG[4])
    tt:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], GOLD[4])
    tt.fwSkinned = true
end

local function SkinOff(tt)
    if not tt.fwSkinned or not tt.SetBackdrop then return end
    tt:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 } })
    tt:SetBackdropColor(0.09, 0.09, 0.19, 1)
    tt:SetBackdropBorderColor(1, 1, 1, 1)
    tt.fwSkinned = nil
end

local hooked = {}
local function Apply(tt)
    if T.Get("tipSkin") == true then SkinOn(tt) else SkinOff(tt) end
end

function T.Hook(tt)
    if not tt or hooked[tt] or not tt.HookScript then return end
    hooked[tt] = true
    tt:HookScript("OnShow", function(self) pcall(Apply, self) end)
    pcall(tt.HookScript, tt, "OnTooltipSetItem", function(self) pcall(Apply, self) end)
    pcall(tt.HookScript, tt, "OnTooltipSetUnit", function(self) pcall(Apply, self) end)
    pcall(Apply, tt)
end

local function HookAll()
    for _, name in ipairs(TIPS) do T.Hook(_G[name]) end
end

------------------------------------------------------------------------
-- Tooltip an der Maus (nur Welt: Gegner, Objekte; Inventar bleibt am Item)
------------------------------------------------------------------------

local follow = _G.CreateFrame("Frame")
follow:SetScript("OnUpdate", function()
    if T.Get("tipCursor") ~= true then return end
    local tt = _G.GameTooltip
    if not tt or not tt:IsShown() then return end
    local owner = tt.GetOwner and tt:GetOwner()
    if owner ~= _G.UIParent then return end
    local x, y = _G.GetCursorPosition()
    local s = _G.UIParent:GetEffectiveScale()
    local ts = tt:GetEffectiveScale()
    if not x or not s or s == 0 or not ts or ts == 0 then return end
    x, y = x / s, y / s
    local w, h = (tt:GetWidth() or 0) * ts / s, (tt:GetHeight() or 0) * ts / s
    local sw, sh = _G.UIParent:GetWidth(), _G.UIParent:GetHeight()
    local px = x + 16
    if px + w > sw then px = x - 16 - w end
    local py = y + 16
    if py + h > sh then py = y - 16 - h end
    if px < 0 then px = 0 end
    if py < 0 then py = 0 end
    tt:ClearAllPoints()
    tt:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", px * s / ts, py * s / ts)
end)

local function Reapply()
    HookAll()
    for _, name in ipairs(TIPS) do
        local tt = _G[name]
        if tt then pcall(Apply, tt) end
    end
end

FW:On("QUEST_TIP_CHANGED", function(key)
    if key == "tipSkin" then Reapply() end
end, T)

local init = _G.CreateFrame("Frame")
init:RegisterEvent("PLAYER_ENTERING_WORLD")
init:SetScript("OnEvent", function() Reapply() end)

------------------------------------------------------------------------
-- Einstellungen (Unter-Reiter "Tooltips")
------------------------------------------------------------------------

local UI = FW.UI
if UI and UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("tooltips", {
        order = 10,
        category = "tooltips",
        height = 300,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.TIPSET_HEADER)
            local note = UI.CreateLabel(f, L.TIPSET_NOTE, { size = 11, color = "textDim", justifyV = "TOP" })
            stack:Add(note, { fit = true, gap = 8 })
            local boxes, made = {}, {}
            local function Box(key, label)
                local cb = UI.CreateCheckbox(f, label, function() return T.Get(key) == true end,
                    function(on) T.Set(key, on and true or false) end)
                stack:Add(cb, { fit = true, gap = 6 })
                boxes[#boxes + 1] = cb
                return cb
            end
            local function Slider(o)
                local text = FW.L[o.label] or o.label
                local val = UI.CreateLabel(f, "", { size = 12 })
                stack:Add(val, { fit = true, gap = 6 })
                local key = o.key
                local sl = UI.CreateSlider(f, 200, {
                    min = o.min, max = o.max, step = o.step or 1,
                    get = function() return tonumber(T.Get(key)) or o.min end,
                    set = function(v)
                        T.Set(key, v)
                        val:SetText(string.format(text, v))
                    end,
                })
                sl.onText = function(v) val:SetText(string.format(text, v)) end
                stack:Add(sl, { height = 20, gap = 4 })
                boxes[#boxes + 1] = sl
            end
            Box("tipSkin", L.TIPSET_SKIN)
            Box("tipCursor", L.TIPSET_CURSOR)
            function f.Refresh()
                T.lastError = nil
                for _, o in ipairs(options) do
                    if not made[o.key] and (not o.available or o.available()) then
                        made[o.key] = true
                        local okb, err
                        if o.max then
                            okb, err = pcall(Slider, o)
                        else
                            okb, err = pcall(Box, o.key, FW.L[o.label] or o.label)
                        end
                        if not okb then T.lastError = tostring(err) end
                    end
                end
                for _, cb in ipairs(boxes) do cb:Refresh() end
                stack:Layout()
            end
            T.settingsFrame = f
            f.Refresh()
            return f
        end,
        refresh = function(frame)
            frame.Refresh()
        end,
    })
    function T.RefreshSettings()
        local f = T.settingsFrame
        if f and f.Refresh then f.Refresh() end
    end
end

-- Diagnose: /fwtips zeigt, welche Module Optionen angemeldet haben
_G.SLASH_FWTIPS1 = "/fwtips"
_G.SlashCmdList = _G.SlashCmdList or {}
_G.SlashCmdList["FWTIPS"] = function()
    local function say(t) if _G.DEFAULT_CHAT_FRAME then _G.DEFAULT_CHAT_FRAME:AddMessage("|cff9d7826Freewood Tooltips:|r " .. t) end end
    say("Optionen angemeldet: " .. #options .. ", Abschnitt gebaut: " .. tostring(T.settingsFrame ~= nil) .. ", Quest-Modul: " .. tostring(FW.Quest ~= nil or (_G.FreewoodQuestDB ~= nil)))
    for _, o in ipairs(options) do
        local av = (not o.available) or o.available()
        say("  " .. o.key .. " verfuegbar=" .. tostring(av and true or false) .. " Wert=" .. tostring(T.Get(o.key)))
    end
    if T.lastError then say("Fehler: " .. T.lastError) end
end
