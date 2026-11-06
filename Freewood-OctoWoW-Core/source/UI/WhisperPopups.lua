-- Freewood-OctoWoW-Core: kleine verschiebbare Fluesterfenster (nur ausserhalb des Kampfes). UNGEPRUEFT im Spiel.
-- Auslöser: CHAT_MSG_WHISPER / CHAT_MSG_WHISPER_INFORM. Der Verlauf liegt in Core/ChatLog.lua (Schluessel "w:<Name>").

local ADDON, FW = ...

local UI = FW.UI
local CL = FW.ChatLog
local G = _G

local Pop = {}
FW.WhisperPopups = Pop

local W, H = 330, 230
local MAX_OPEN = 4
local wins = {}          -- wins[name] = Fenster
local openOrder = {}     -- Namen in Oeffnungsreihenfolge
local pending = {}       -- nach dem Kampf (wieder) zu oeffnen
local inCombat = false

local function RemoveAt(t, idx)
    local n = table.getn(t)
    local k = idx
    while k < n do t[k] = t[k + 1]; k = k + 1 end
    t[n] = nil
end

local function PosDB()
    local d = G.FreewoodDB
    if type(d) ~= "table" then return {} end
    if type(d.chatPopupPos) ~= "table" then d.chatPopupPos = {} end
    return d.chatPopupPos
end

local function Time(t)
    if not (t and G.date) then return "" end
    local ok, s = pcall(G.date, "%H:%M", t)
    return ok and s or ""
end

local function InfoText(name)
    local r = CL.Detail(name)
    if not r then return FW.L.POP_INFO_NONE end
    local parts = {}
    if r.l then parts[table.getn(parts) + 1] = tostring(r.l) end
    if r.r then parts[table.getn(parts) + 1] = r.r end
    local cn = r.cn
    if not cn and r.c then
        cn = (G.LOCALIZED_CLASS_NAMES_MALE and G.LOCALIZED_CLASS_NAMES_MALE[r.c])
            or (string.upper(string.sub(r.c, 1, 1)) .. string.lower(string.sub(r.c, 2)))
    end
    if cn then parts[table.getn(parts) + 1] = cn end
    local txt = table.concat(parts, " ")
    if r.g and r.g ~= "" then txt = "<" .. r.g .. "> " .. txt end
    if txt == "" then return FW.L.POP_INFO_NONE end
    return txt
end

local function AddLine(win, ln)
    local mine = ln.o ~= nil
    local nameCol = mine and "|cff6fa8dc" or "|cffff9ff3"
    local text = "|cff9a978c" .. Time(ln.t) .. "|r " .. nameCol .. (ln.s or "?") .. "|r: " .. (ln.m or "")
    win.log:AddMessage(text, 0.9, 0.89, 0.84)
end

local function FillNew(win)
    local lines = CL.Lines("w:" .. win.name) or {}
    local n = table.getn(lines)
    local from = win.shown
    if from == 0 then from = math.max(0, n - 25) end
    local i = from + 1
    while i <= n do
        AddLine(win, lines[i])
        i = i + 1
    end
    win.shown = n
end

local function Place(win)
    local pos = PosDB()[win.name]
    win:ClearAllPoints()
    if pos and pos.l and pos.b then
        win:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos.l, pos.b)
    else
        local idx = table.getn(openOrder)
        win:SetPoint("CENTER", UIParent, "CENTER", 220 - idx * 28, 160 - idx * 28)
    end
end

local function Hide(win, keepPending)
    if not win then return end
    win:Hide()
    win.edit:ClearFocus()
    local k = 1
    while k <= table.getn(openOrder) do
        if openOrder[k] == win.name then RemoveAt(openOrder, k); break end
        k = k + 1
    end
    if not keepPending then pending[win.name] = nil end
end

local function Create(name)
    local L = FW.L
    local win = UI.CreatePanel(UIParent, "bgDeep", "gold")
    win.name = name
    win.shown = 0
    win.flash = 0
    win:SetSize(W, H)
    win:SetFrameStrata("DIALOG")
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:Hide()

    local head = CreateFrame("Button", nil, win)
    head:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0)
    head:SetPoint("TOPRIGHT", win, "TOPRIGHT", -160, 0)   -- Knoepfe liegen ausserhalb der Zugflaeche
    head:SetHeight(44)
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() win:StartMoving() end)
    head:SetScript("OnDragStop", function()
        win:StopMovingOrSizing()
        local l, b = win:GetLeft(), win:GetBottom()
        if l and b then PosDB()[name] = { l = l, b = b } end
    end)

    win.title = UI.CreateLabel(win, name, { font = "heading", size = 14, color = "gold", justify = "LEFT" })
    win.title:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -8)
    win.title:SetPoint("TOPRIGHT", win, "TOPRIGHT", -160, -8)
    win.info = UI.CreateLabel(win, "", { size = 11, color = "textDim", justify = "LEFT" })
    win.info:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -26)
    win.info:SetPoint("TOPRIGHT", win, "TOPRIGHT", -12, -26)

    local close = UI.CreateButton(win, "x", 24, 22, function() Hide(win, false) end)
    close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -6, -6)
    close:SetFrameLevel(head:GetFrameLevel() + 3)
    local tab = UI.CreateButton(win, L.POP_TAB, 52, 22, function()
        CL.requestKey = "w:" .. name
        Hide(win, false)
        if UI.Show then UI:Show("channels") end
    end)
    tab:SetPoint("RIGHT", close, "LEFT", -4, 0)
    tab:SetFrameLevel(head:GetFrameLevel() + 3)
    local inv = UI.CreateButton(win, L.POP_INVITE, 60, 22, function()
        local Ch = FW.Channels
        if Ch and Ch.Invite then Ch.Invite(name) end
    end)
    inv:SetPoint("RIGHT", tab, "LEFT", -4, 0)
    inv:SetFrameLevel(head:GetFrameLevel() + 3)

    local logBox = UI.CreatePanel(win, "bg", "bronze")
    logBox:SetPoint("TOPLEFT", win, "TOPLEFT", 8, -48)
    logBox:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -8, 40)
    local log = CreateFrame("ScrollingMessageFrame", nil, logBox)
    log:SetPoint("TOPLEFT", logBox, "TOPLEFT", 6, -6)
    log:SetPoint("BOTTOMRIGHT", logBox, "BOTTOMRIGHT", -6, 6)
    if not pcall(log.SetFont, log, UI.GetFontPath("body"), 12, "") then
        pcall(log.SetFont, log, "Fonts\\FRIZQT__.TTF", 12, "")
    end
    log:SetJustifyH("LEFT")
    log:SetMaxLines(120)
    log:SetFading(false)
    log:EnableMouseWheel(true)
    log:SetScript("OnMouseWheel", function(self, delta)
        delta = delta or arg1 or 0
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)
    win.log = log

    local ibox = UI.CreatePanel(win, "bg", "bronze")
    ibox:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 8, 8)
    ibox:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -8, 8)
    ibox:SetHeight(26)
    local edit = CreateFrame("EditBox", nil, ibox)
    edit:SetAutoFocus(false)
    edit:SetPoint("TOPLEFT", ibox, "TOPLEFT", 6, -3)
    edit:SetPoint("BOTTOMRIGHT", ibox, "BOTTOMRIGHT", -6, 3)
    edit:SetMaxLetters(255)
    if not edit:SetFont(UI.GetFontPath("body"), 12, "") then edit:SetFont("Fonts\\FRIZQT__.TTF", 12, "") end
    edit:SetTextColor(UI.Color("text"))
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function(self)
        local txt = self:GetText() or ""
        if txt ~= "" then CL.Send("whisper", name, txt) end
        self:SetText("")
        self:SetFocus()
    end)
    win.edit = edit

    -- Kopf blinkt golden bei neuer Nachricht, Infozeile aktualisiert sich
    local acc, infoAcc = 0, 0
    win:SetScript("OnUpdate", function(_, el)
        el = el or arg1 or 0
        if win.flash > 0 then
            win.flash = win.flash - el
            if win.flash > 0 then
                local on = math.mod(math.floor(win.flash * 4), 2) == 1
                if on then win.title:SetTextColor(UI.Color("goldLight")) else win.title:SetTextColor(UI.Color("text")) end
            else
                win.title:SetTextColor(UI.Color("gold"))
            end
        end
        infoAcc = infoAcc + el
        if infoAcc >= 1 then
            infoAcc = 0
            win.info:SetText(InfoText(name))
        end
    end)
    return win
end

function Pop.Open(name)
    local win = wins[name]
    if not win then
        win = Create(name)
        wins[name] = win
    end
    if not win:IsShown() then
        openOrder[table.getn(openOrder) + 1] = name
        Place(win)
        win:Show()
        -- zu viele offen: das aelteste schliessen
        while table.getn(openOrder) > MAX_OPEN do
            local old = wins[openOrder[1]]
            Hide(old, false)
        end
    end
    win.info:SetText(InfoText(name))
    FillNew(win)
    win.flash = 1.5
    return win
end

local function CanShow()
    if inCombat then return false end
    if G.UnitAffectingCombat and G.UnitAffectingCombat("player") then return false end
    local s = FW.settings
    if s and s.whisperPopup == false then return false end
    if UI.window and UI.window:IsShown() and not (s and s.whisperPopupAlways == true) then return false end
    return true
end

local function Notify(name)
    if type(name) ~= "string" or name == "" then return end
    CL.Ask(name)
    local win = wins[name]
    if win and win:IsShown() then
        FillNew(win)
        win.flash = 1.5
        return
    end
    if CanShow() then
        Pop.Open(name)
    elseif inCombat or (G.UnitAffectingCombat and G.UnitAffectingCombat("player")) then
        pending[name] = true
    end
end

FW:RegisterEvent("CHAT_MSG_WHISPER", function(text, sender) Notify(sender) end)
FW:RegisterEvent("CHAT_MSG_WHISPER_INFORM", function(text, target) Notify(target) end)

-- Kampf beginnt: alle Fenster schliessen (Namen merken); Kampf vorbei: wieder oeffnen
FW:RegisterEvent("PLAYER_REGEN_DISABLED", function()
    inCombat = true
    local names, k = {}, 1
    while k <= table.getn(openOrder) do names[k] = openOrder[k]; k = k + 1 end
    k = 1
    while k <= table.getn(names) do
        pending[names[k]] = true
        Hide(wins[names[k]], true)
        k = k + 1
    end
end)

FW:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    inCombat = false
    local names = {}
    for name in pairs(pending) do names[table.getn(names) + 1] = name end
    pending = {}
    local k = 1
    while k <= table.getn(names) do
        if CanShow() then Pop.Open(names[k]) end
        k = k + 1
    end
end)

if G.UnitAffectingCombat and G.UnitAffectingCombat("player") then inCombat = true end
