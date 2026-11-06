-- Freewood-OctoWoW-Codex: Flugfenster
--
-- Waehrend eines Fluges mit dem Flugmeister: kleines Fenster mit Zielname, verbleibender Zeit und einem ablaufenden Balken.
-- Ist die Flugdauer der Route noch unbekannt (noch nie geflogen oder empfangen), zaehlt es die vergangene Zeit hoch.

local ADDON, NS = ...

local FW = _G.Freewood
local Codex = NS and NS.Codex
local Taxi = NS and NS.Taxi
if not FW or not Codex or not Taxi or not FW.UI then
    return
end
local UI = FW.UI

local WIDTH, HEIGHT, BAR_H = 250, 50, 8
local win

local function Settings()
    local db = Codex.db
    if not db then return {} end
    db.settings = db.settings or {}
    return db.settings
end

function Taxi.WindowOn()
    return Settings().taxiWindow ~= false
end

local function SavePos()
    if not win then return end
    local point, _, rel, x, y = win:GetPoint(1)
    if point then Settings().taxiWinPos = { point = point, rel = rel, x = x, y = y } end
end

local function ApplyPos()
    win:ClearAllPoints()
    local p = Settings().taxiWinPos
    if type(p) == "table" and p.point and p.x and p.y then
        win:SetPoint(p.point, UIParent, p.rel or p.point, p.x, p.y)
    else
        win:SetPoint("TOP", UIParent, "TOP", 0, -150)
    end
end

local function Build()
    local f = UI.CreatePanel(UIParent, "bg", "gold")
    f:SetSize(WIDTH, HEIGHT)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePos() end)
    win = f
    ApplyPos()

    f.title = UI.CreateLabel(f, "", { size = 12, color = "goldLight" })
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -7)
    f.title:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -7)
    f.title:SetHeight(14)

    f.time = UI.CreateLabel(f, "", { size = 11, color = "text" })
    f.time:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -2)
    f.time:SetPoint("TOPRIGHT", f.title, "BOTTOMRIGHT", 0, -2)
    f.time:SetHeight(13)

    f.barBg = f:CreateTexture(nil, "ARTWORK")
    f.barBg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
    f.barBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 8)
    f.barBg:SetHeight(BAR_H)
    f.barBg:SetColorTexture(UI.Color("card"))

    f.fill = f:CreateTexture(nil, "OVERLAY")
    f.fill:SetPoint("BOTTOMLEFT", f.barBg, "BOTTOMLEFT", 0, 0)
    f.fill:SetHeight(BAR_H)
    f.fill:SetColorTexture(UI.Color("gold"))

    f.acc = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        self.acc = self.acc + (elapsed or 0)
        if self.acc < 0.1 then return end
        self.acc = 0
        local fl = Taxi.flight
        if not fl or not Taxi.WindowOn() then self:Hide() return end
        local L = FW.L
        local el = (GetTime and GetTime() or 0) - fl.t0
        if self.shownName ~= fl.name then
            self.shownName = fl.name
            self.title:SetText(string.format(L.CODEX_TAXI_TITLE, fl.name))
        end
        local full = self.barBg:GetWidth() or (WIDTH - 20)
        if fl.exp and fl.exp > 0 then
            local left = fl.exp - el
            if left > 0 then
                self.time:SetText(string.format(L.CODEX_TAXI_LEFT, Taxi.Duration(math.ceil(left))))
                self.fill:SetColorTexture(UI.Color("gold"))
                self.fill:SetWidth(math.max(1, full * left / fl.exp))
            else
                self.time:SetText(L.CODEX_TAXI_ARRIVING)
                self.fill:SetColorTexture(UI.Color("success"))
                self.fill:SetWidth(1)
            end
        else
            self.time:SetText(string.format(L.CODEX_TAXI_UNKNOWN, Taxi.Duration(el)))
            self.fill:SetColorTexture(UI.Color("bronze"))
            self.fill:SetWidth(math.max(1, full * ((el % 4) / 4)))
        end
    end)
    f:Hide()
    return f
end

-- Das Fenster zeigt sich, sobald ein Flug laeuft
local watch = CreateFrame("Frame")
local acc = 0
watch:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + (elapsed or 0)
    if acc < 0.25 then return end
    acc = 0
    if Taxi.flight and Taxi.WindowOn() then
        if not win then win = Build() end
        if not win:IsShown() then win.shownName = nil; win:Show() end
    end
end)

if UI.RegisterSettingsSection then
    UI:RegisterSettingsSection("codex-taxi", {
        category = "database",
        order = 108,
        height = 140,
        build = function(parent)
            local L = FW.L
            local f, stack = UI.CreateSection(parent, L.CODEX_TAXI_HEADER)
            local note = UI.CreateLabel(f, L.CODEX_TAXI_NOTE, { size = 11, color = "textDim", justifyV = "TOP" })
            stack:Add(note, { fit = true, gap = 8 })
            local cb = UI.CreateCheckbox(f, L.CODEX_TAXI_SWITCH, function() return Taxi.WindowOn() end,
                function(on) Settings().taxiWindow = on and true or false end)
            stack:Add(cb, { fit = true, gap = 6 })
            local cp = UI.CreateCheckbox(f, L.CODEX_TAXI_PLAN, function() return Taxi.PlannerOn() end,
                function(on) Settings().taxiPlan = on and true or false end)
            stack:Add(cp, { fit = true, gap = 6 })
            function f.Refresh() cb:Refresh(); cp:Refresh(); stack:Layout() end
            stack:Layout()
            return f
        end,
        refresh = function(frame) frame.Refresh() end,
    })
end
