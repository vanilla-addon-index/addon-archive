-- Guide step accessor (post-chapter migration)
local function QS_GetStepsForGuide(name)
    local g = QuestShellGuides and QuestShellGuides[name]
    if type(g) == "table" then
        if g.steps then return g.steps end
        if g.chapters and g.chapters[1] and g.chapters[1].steps then return g.chapters[1].steps end
    end
    return {}
end

-- =========================
-- QuestShell UI — Steps (keeps scroll, correct header)
-- Vanilla/Turtle (Lua 5.0)
-- =========================

QuestShellUI = QuestShellUI or {}

-- ---------- Saved vars / alpha ----------
local function EnsureDB()
    QuestShellDB = QuestShellDB or {}
    QuestShellDB.ui = QuestShellDB.ui or {}
    if QuestShellDB.ui.listX == nil then QuestShellDB.ui.listX = 560 end
    if QuestShellDB.ui.listY == nil then QuestShellDB.ui.listY = -220 end
    if QuestShellDB.ui.listW == nil then QuestShellDB.ui.listW = 360 end
    if QuestShellDB.ui.listH == nil then QuestShellDB.ui.listH = 320 end
    if QuestShellDB.ui.locked == nil then QuestShellDB.ui.locked = false end
    if QuestShellDB.ui.backdropAlpha == nil then QuestShellDB.ui.backdropAlpha = 1.0 end
end
local function PanelA()
    EnsureDB()
    local a = QuestShellDB.ui.backdropAlpha or 1.0
    if a < 0 then a = 0 elseif a > 1 then a = 1 end
    return a
end

-- ---------- Textures ----------
local TEX_TALK   = "Interface\\GossipFrame\\GossipGossipIcon"
local TEX_ACCEPT = "Interface\\GossipFrame\\AvailableQuestIcon"
local TEX_TURNIN = "Interface\\GossipFrame\\ActiveQuestIcon"
local TEX_KILL   = "Interface\\Icons\\Ability_DualWield"
local TEX_LOOT   = "Interface\\Icons\\INV_Misc_Bag_08"
local TEX_OTHER  = "Interface\\Icons\\INV_Misc_Note_01"
local TEX_BULLET = "Interface\\Buttons\\UI-CheckBox-Up"
local TEX_CHECK  = "Interface\\Buttons\\UI-CheckBox-Check"

local TEX_HEARTH  = "Interface\\Icons\\INV_Misc_Rune_01"
local TEX_CLASSES = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"

local CLASS_COORDS = {
  WARRIOR={0.00,0.25,0.00,0.25}, MAGE={0.25,0.50,0.00,0.25}, ROGUE={0.50,0.75,0.00,0.25},
  DRUID  ={0.75,1.00,0.00,0.25}, HUNTER={0.00,0.25,0.25,0.50}, SHAMAN={0.25,0.50,0.25,0.50},
  PRIEST ={0.50,0.75,0.25,0.50}, WARLOCK={0.75,1.00,0.25,0.50}, PALADIN={0.00,0.25,0.50,0.75},
}
local function SetClassIcon(tex)
    if not tex then return end
    tex:SetTexture(TEX_CLASSES)
    local _, class = UnitClass("player")
    local c = CLASS_COORDS[class or ""]
    if c then tex:SetTexCoord(c[1],c[2],c[3],c[4]) else tex:SetTexCoord(0,1,0,1) end
end

-- ---------- Layout ----------
local GUTTER_BULLET_W = 12
local GUTTER_GAP       = 4
local ICON_W           = 12
local ROW_VGAP         = 2
local CHECKBOX_W       = 16

local STEP_GAP         = 4
local ZEBRA_ODD_ALPHA  = 0.03
local ZEBRA_EVEN_ALPHA = 0.06
local SELECT_ALPHA     = 0.10

local TEXT_X = GUTTER_BULLET_W + GUTTER_GAP + ICON_W + GUTTER_GAP

-- ---------- State ----------
local listFrame, headerTitle, headerLevelFS, headerStepFS
local scroll, scrollChild, rowPool, meterFS
local _lastSteps, _lastCurrentIndex, _lastCompletedMap
local _lastGuideKey = nil

local _heightCache, _cachedWidthKey = {}, nil
local function ClearHeightCache() _heightCache = {} end

-- ---------- Helpers ----------
local function ClampAndPlace(f, x, y, fw, fh)
    if not f or not UIParent then return end
    f:ClearAllPoints(); f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x or 0, y or 0); f:Show()
    local sw, sh = UIParent:GetWidth() or 1024, UIParent:GetHeight() or 768
    local cx, cy = x or 0, y or 0
    local ww, hh = fw or (f:GetWidth() or 360), fh or (f:GetHeight() or 320)
    if cx > sw - ww then cx = sw - ww end
    if cx < 0 then cx = 0 end
    if cy > 0 then cy = 0 end
    if cy < -(sh - hh) then cy = -(sh - hh) end
    f:ClearAllPoints(); f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", cx, cy)
    return cx, cy
end

local function MeasureTextHeight(text, width)
    local w = math.max(1, width or 200)
    local key = tostring(w).."|"..(text or "")
    local h = _heightCache[key]
    if h then return h end

    meterFS:ClearAllPoints()
    meterFS:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -2000, 2000)
    meterFS:SetAlpha(0); meterFS:Show()
    meterFS:SetWidth(w); meterFS:SetText(text or "")
    h = meterFS:GetHeight() or 0
    if h <= 0 then
        local _, lh = meterFS:GetFont(); if not lh or lh <= 0 then lh = 12 end
        local _, nl = string.gsub(text or "", "\n", ""); h = (nl+1)*lh
    end
    h = math.ceil(h)
    _heightCache[key] = h
    return h
end

local function _SB() return (getglobal and getglobal("QuestShellStepsScrollScrollBar")) or nil end
local function _GetScroll()
    local sb = _SB()
    if sb and sb.GetValue then return sb:GetValue() or 0 end
    if scroll and scroll.GetVerticalScroll then return scroll:GetVerticalScroll() or 0 end
    return 0
end
local function _SetScroll(v)
    local sb = _SB()
    if sb and sb.SetValue then sb:SetValue(v) end
    if scroll and scroll.SetVerticalScroll then scroll:SetVerticalScroll(v) end
end

local function _RefreshScrollBar()
    if not scroll or not scrollChild then return end
    local viewH = scroll:GetHeight() or 1
    local contentH = scrollChild:GetHeight() or 1
    local range = contentH - viewH
    if range < 0 then range = 0 end

    local sb = _SB()
    if sb and sb.SetMinMaxValues then
        sb:SetMinMaxValues(0, range)
        local cur = sb:GetValue() or 0
        if cur > range then cur = range end
        if range == 0 then cur = 0 end
        sb:SetValue(cur)
        if scroll.SetVerticalScroll then scroll:SetVerticalScroll(cur) end

        local up = getglobal and getglobal("QuestShellStepsScrollScrollBarScrollUpButton")
        local down = getglobal and getglobal("QuestShellStepsScrollScrollBarScrollDownButton")
        if range == 0 then if up and up.Hide then up:Hide() end; if down and down.Hide then down:Hide() end
        else if up and up.Show then up:Show() end; if down and down.Show then down:Show() end end
    end
end

-- ---------- Header (uses provided steps + currentIndex) ----------
local function SetHeaderFromGuide(steps, currentIndex)
    local gmeta = (QS_GuideMeta and QS_GuideMeta()) or {}
    local title = gmeta.title or "QuestShell"
    local minL, maxL = gmeta.minLevel, gmeta.maxLevel
    local levels = ""
    if minL or maxL then levels = "  "..tostring(minL or "?").."-"..tostring(maxL or "?") end
    headerTitle:SetText("|cffffee00"..title.."|r")
    headerLevelFS:SetText(levels)

    steps = steps or {}
    local n = table.getn(steps or {})

    local function eligible(i)
        local s = steps[i]; if not s then return false end
        return (not QS_StepIsEligible) or QS_StepIsEligible(s)
    end

    local total, i = 0, 1
    while i <= n do if eligible(i) then total = total + 1 end; i = i + 1 end

    local curIdx = currentIndex or 1
    if curIdx < 1 then curIdx = 1 end; if curIdx > n then curIdx = n end

    local cur, j = 0, 1
    while j <= curIdx do if eligible(j) then cur = cur + 1 end; j = j + 1 end
    if cur == 0 and total > 0 then cur = 1 end

    headerStepFS:SetText("Step "..tostring(cur).."/"..tostring(total))
end

-- ---------- Row factory ----------
local function MakeRow(index)
    local row = CreateFrame("Button", "QuestShellStepRow"..tostring(index), scrollChild)
    row:SetHeight(24)
    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, - (index-1)*24)
    row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)

    row.chk = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.chk:SetWidth(16); row.chk:SetHeight(16)
    row.chk:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.chk:SetScript("OnClick", function()
        if not row._index then return end
        if QS_UI_SetStepCompleted then QS_UI_SetStepCompleted(row._index, row.chk:GetChecked()) end
    end)

    row.lines = {}
    local k = 1
    while k <= 8 do
        local bullet = row:CreateTexture(nil, "ARTWORK")
        bullet:SetWidth(12); bullet:SetHeight(12)
        bullet:SetTexture(TEX_BULLET); bullet:Hide()

        local check = row:CreateTexture(nil, "OVERLAY")
        check:SetWidth(12); check:SetHeight(12)
        check:SetTexture(TEX_CHECK); check:SetPoint("CENTER", bullet, "CENTER", 0, 0); check:SetAlpha(0)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(12); icon:SetHeight(12); icon:Hide()

        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT"); fs:SetJustifyV("TOP"); fs:SetText(""); fs:Hide()

        row.lines[k] = { bullet=bullet, check=check, icon=icon, fs=fs }
        k = k + 1
    end

    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row:GetHighlightTexture():SetBlendMode("ADD")
    row:GetHighlightTexture():SetAlpha(0.18)

    row:SetScript("OnClick", function()
        if row._index and QuestShell and QuestShell.JumpToStep then QuestShell.JumpToStep(row._index) end
    end)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    row.bg:SetVertexColor(1,1,1,0)

    row.sep = row:CreateTexture(nil, "ARTWORK")
    row.sep:SetTexture("Interface\\Buttons\\WHITE8x8")
    row.sep:SetHeight(1)
    row.sep:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", TEXT_X, 0)
    row.sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -CHECKBOX_W-2, 0)
    row.sep:SetVertexColor(1,1,1,0.06)

    return row
end

local function ResizeRowsToWidth()
    if not scrollChild then return end
    local w = scrollChild:GetWidth() or 322
    local contentW = w - (CHECKBOX_W + 12)
    local textW = contentW - TEXT_X
    local newKey = tostring(textW)
    if newKey ~= _cachedWidthKey then ClearHeightCache(); _cachedWidthKey = newKey end
    local i = 1
    while rowPool and rowPool[i] do
        local r = rowPool[i]
        if r.lines then
            local k = 1
            while r.lines[k] do
                local L = r.lines[k]
                if L and L.fs then L.fs:SetWidth(textW) end
                k = k + 1
            end
        end
        i = i + 1
    end
end

-- ---------- Build visual rows ----------
local function BuildRows(step, fallbackTitle, forceComplete)
    local rows, c = {}, 0
    local stype = string.upper(step and step.type or "")

    if stype == "ACCEPT" or stype == "TURNIN" then
        local npc = step and step.npc
        local who = (type(npc) == "table" and npc.name) or (type(npc) == "string" and npc) or "the quest giver"
        c=c+1; rows[c] = { bullet=false, icon=TEX_TALK, text=("Talk to "..who) }
        c=c+1; rows[c] = { bullet=false, icon=(stype=="TURNIN" and TEX_TURNIN or TEX_ACCEPT), text=(step and step.title) or "" }

    elseif stype == "TRAVEL" then
        local note = (step and step.note) or "Travel to the marked location."
        local cmeta = step and step.coords or {}
        local where = ""
        if cmeta and cmeta.x and cmeta.y then
            local z = cmeta.map or ""
            where = string.format("(%.1f, %.1f %s)", cmeta.x, cmeta.y, z)
        end
        c=c+1; rows[c] = { bullet=false, icon=nil, text=note }
        if where ~= "" then c=c+1; rows[c] = { bullet=false, icon=nil, text=where } end

    elseif stype == "USE_ITEM" then
        local nameTxt = step and (step.itemName or ("Item ID "..tostring(step.itemId or "?")))
        local tar = (step and step.npc and step.npc.name) and (" with "..step.npc.name.." selected") or ""
        c=c+1; rows[c] = { bullet=false, icon="Interface\\Icons\\INV_Misc_Gear_02", text=("Use: "..(nameTxt or "item")..tar) }

    elseif stype == "FLIGHTPATH" then
        c=c+1; rows[c] = { bullet=false, icon="Interface\\Minimap\\Tracking\\FlightMaster", text=(step and step.note) or "Speak to the flight master and learn the flight path." }

    elseif stype == "FLY" then
        local dest = (step and step.destination) or "your destination"
        c=c+1; rows[c] = { bullet=false, icon="Interface\\Minimap\\Tracking\\FlightMaster", text=(step and step.note) or ("Fly to "..dest..".") }

    else
        local note = (step and step.note) or (fallbackTitle or "")
        c=c+1; rows[c] = { bullet=false, icon=nil, text=note }
        local orows = QS_BuildObjectiveRows and QS_BuildObjectiveRows(step, forceComplete) or {}
        local j = 1
        while j <= table.getn(orows) do
            local R = orows[j]
            local kind = R.kind or "other"
            local icon = (kind=="kill" and TEX_KILL) or (kind=="loot" and TEX_LOOT) or TEX_OTHER
            c=c+1; rows[c] = { bullet=true, icon=icon, text=(R.text or ""), done=(R.done and true or false) }
            j = j + 1
        end
    end
    return rows
end

-- ---------- Render ----------
local function RebuildContent(steps, currentIndex, completedMap)
    local total = (steps and table.getn(steps)) or 0
    local y = 0
    local w = scrollChild:GetWidth() or 322
    local contentW = w - (CHECKBOX_W + 12)
    local textW = math.max(1, contentW - TEXT_X)

    local i, j = 1, 1
    while i <= total do
        local step = steps[i]
        local eligible = (not QS_StepIsEligible) or QS_StepIsEligible(step)
        if eligible then
            local row = rowPool and rowPool[j] or MakeRow(j)
            rowPool = rowPool or {}; rowPool[j] = row
            row._index = i

            local isCompleted = (completedMap and completedMap[i]) or false
            row.chk:SetChecked(isCompleted)

            local baseAlpha = (math.mod(i, 2) == 0) and ZEBRA_EVEN_ALPHA or ZEBRA_ODD_ALPHA
            local tint = (i == currentIndex) and SELECT_ALPHA or baseAlpha
            row.bg:SetVertexColor(1,1,1, tint)

            local lines = BuildRows(step, step and step.title or "", isCompleted)
            local cy = 0

            local k = 1
            while row.lines[k] do
                local slot = row.lines[k]; local data = lines[k]
                if data then
                    local anchorY = -cy

                    slot.bullet:ClearAllPoints(); slot.bullet:SetPoint("TOPLEFT", row, "TOPLEFT", 0, anchorY)
                    if data.bullet then
                        slot.bullet:Show()
                        if data.done then slot.check:SetAlpha(1); slot.check:SetVertexColor(0.20,1.00,0.20) else slot.check:SetAlpha(0) end
                    else
                        slot.bullet:Hide(); slot.check:SetAlpha(0)
                    end

                    slot.icon:ClearAllPoints(); slot.icon:SetPoint("TOPLEFT", row, "TOPLEFT", GUTTER_BULLET_W + GUTTER_GAP, anchorY)
                    if data.icon then slot.icon:Show(); slot.icon:SetTexture(data.icon) else slot.icon:Hide() end

                    local txt = data.text or ""
                    slot.fs:ClearAllPoints(); slot.fs:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_X, anchorY)
                    slot.fs:SetWidth(textW); slot.fs:SetText(txt)
                    if data.done then slot.fs:SetTextColor(0.6,1.0,0.6) else slot.fs:SetTextColor(1,1,1) end
                    slot.fs:Show()

                    local h = MeasureTextHeight(txt, textW)
                    if h < ICON_W then h = ICON_W end
                    cy = cy + h + ROW_VGAP
                else
                    slot.bullet:Hide(); slot.check:SetAlpha(0); slot.icon:Hide(); slot.fs:SetText(""); slot.fs:Hide()
                end
                k = k + 1
            end

            if cy > 0 then cy = cy - ROW_VGAP end
            local rowH = math.max(20, cy)
            row:SetHeight(rowH)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
            row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)

            row.chk:ClearAllPoints()
            row.chk:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, - math.floor(rowH/2 - CHECKBOX_W/2))

            y = y + rowH + STEP_GAP
            row:Show()

            j = j + 1
        end
        i = i + 1
    end

    while rowPool and rowPool[j] do rowPool[j]:Hide(); j = j + 1 end

    if y < 1 then y = 1 end
    scrollChild:SetHeight(y)
    _RefreshScrollBar()

    -- header now uses the same steps/currentIndex passed in
    SetHeaderFromGuide(steps, currentIndex)
end

local function Relayout()
    if not listFrame or not _lastSteps then return end
    ResizeRowsToWidth()
    RebuildContent(_lastSteps, _lastCurrentIndex, _lastCompletedMap)
end

-- ---------- Create frame ----------
local function CreateList()
    EnsureDB(); if listFrame then return end
    rowPool = {}

    listFrame = CreateFrame("Frame", "QuestShellSteps", UIParent)
    listFrame:SetWidth(QuestShellDB.ui.listW or 360)
    listFrame:SetHeight(QuestShellDB.ui.listH or 320)
    listFrame:SetFrameStrata("DIALOG")
    listFrame:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=16,
        insets={ left=4, right=4, top=4, bottom=4 }
    })
    listFrame:SetBackdropColor(0,0,0, PanelA())

    meterFS = listFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    meterFS:SetAlpha(0); meterFS:Show()

    listFrame:SetMovable(true); listFrame:EnableMouse(true); listFrame:SetClampedToScreen(true)
    listFrame:SetResizable(true); listFrame:SetMinResize(280,180); listFrame:SetMaxResize(700,700)
    listFrame:SetScript("OnSizeChanged", function()
        QuestShellDB.ui.listW, QuestShellDB.ui.listH = listFrame:GetWidth(), listFrame:GetHeight()
        if scrollChild then scrollChild:SetWidth(listFrame:GetWidth() - 38) end
        Relayout()
        _RefreshScrollBar()
    end)

    local x = QuestShellDB.ui.listX or 560
    local y = QuestShellDB.ui.listY or -220
    x, y = ClampAndPlace(listFrame, x, y, listFrame:GetWidth(), listFrame:GetHeight())
    QuestShellDB.ui.listX, QuestShellDB.ui.listY = x, y

    local header = CreateFrame("Frame", "QuestShellStepsHeader", listFrame)
    header:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -4, -4)
    header:SetHeight(24)
    header:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=12,
        insets={ left=3, right=3, top=3, bottom=3 }
    })
    header:SetBackdropColor(0,0,0, PanelA())
    header:EnableMouse(true); header:RegisterForDrag("LeftButton","RightButton")
    header:SetFrameLevel(listFrame:GetFrameLevel()+10)
    header:SetScript("OnDragStart", function()
        EnsureDB(); if QuestShellDB.ui.locked then return end
        listFrame:StartMoving(); listFrame.isMoving = true
    end)
    header:SetScript("OnDragStop", function()
        if listFrame.isMoving then
            listFrame:StopMovingOrSizing(); listFrame.isMoving = nil
            local _,_,_,sx,sy = listFrame:GetPoint()
            sx, sy = ClampAndPlace(listFrame, sx, sy, listFrame:GetWidth(), listFrame:GetHeight())
            QuestShellDB.ui.listX, QuestShellDB.ui.listY = sx, sy
        end
    end)

    local hearth = CreateFrame("Button", "QuestShellStepsMenuBtn", header)
    hearth:SetWidth(18); hearth:SetHeight(18); hearth:SetPoint("LEFT", header, "LEFT", 6, 0)
    local htex = hearth:CreateTexture(nil, "ARTWORK"); htex:SetAllPoints(hearth); htex:SetTexture(TEX_HEARTH)
    hearth:SetScript("OnClick", function()
        if QuestShellUI and QuestShellUI.ToggleMenu then QuestShellUI.ToggleMenu(hearth) end
    end)

    local classIcon = header:CreateTexture(nil, "ARTWORK")
    classIcon:SetWidth(18); classIcon:SetHeight(18)
    classIcon:SetPoint("LEFT", hearth, "RIGHT", 6, 0)
    SetClassIcon(classIcon)

    headerTitle = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerTitle:SetPoint("LEFT", classIcon, "RIGHT", 6, 0); headerTitle:SetText("Guide")

    headerLevelFS = header:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    headerLevelFS:SetPoint("LEFT", headerTitle, "RIGHT", 4, 0); headerLevelFS:SetText("")

    headerStepFS = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    headerStepFS:SetPoint("RIGHT", header, "RIGHT", -6, 0); headerStepFS:SetText("Step 1/1")

    scroll = CreateFrame("ScrollFrame", "QuestShellStepsScroll", listFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 8, - (4+24+6))
    scroll:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -28, 8)

    scrollChild = CreateFrame("Frame", "QuestShellStepsScrollChild", scroll)
    scroll:SetScrollChild(scrollChild)
    scrollChild:SetHeight(1)
    scrollChild:SetWidth((QuestShellDB.ui.listW or 360) - 38)

    local sGrip = CreateFrame("Button", "QuestShellStepsSize", listFrame)
    sGrip:SetWidth(16); sGrip:SetHeight(16)
    sGrip:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -4, 4)
    local sTex = sGrip:CreateTexture(nil, "ARTWORK"); sTex:SetAllPoints(sGrip)
    sTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    sGrip:SetScript("OnMouseDown", function() listFrame:StartSizing() end)
    sGrip:SetScript("OnMouseUp", function()
        listFrame:StopMovingOrSizing()
        if scrollChild then scrollChild:SetWidth(listFrame:GetWidth() - 38) end
        Relayout()
        _RefreshScrollBar()
    end)

    listFrame:Show()
    -- initial header uses current guide meta, 0 steps / index 1
    SetHeaderFromGuide({}, 1)
end

-- ---------- Public API ----------
function QuestShellUI.ToggleList()
    if not listFrame then CreateList() end
    if listFrame:IsShown() then listFrame:Hide() else listFrame:Show() end
end

function QuestShellUI.UpdateList(steps, currentIndex, completedMap)
    if not listFrame then CreateList() end

    local guideKey = QuestShell and QuestShell.activeGuide or nil
    local resetToTop = (_lastGuideKey ~= guideKey)
    _lastGuideKey = guideKey

    local prevScroll = resetToTop and 0 or _GetScroll()

    _lastSteps, _lastCurrentIndex, _lastCompletedMap = steps, currentIndex, completedMap
    ClearHeightCache()
    RebuildContent(steps, currentIndex, completedMap)

    local sb = (getglobal and getglobal("QuestShellStepsScrollScrollBar")) or nil
    if sb and sb.GetMinMaxValues then
        local _, max = sb:GetMinMaxValues()
        if not max then max = 0 end
        if prevScroll < 0 then prevScroll = 0 end
        if prevScroll > max then prevScroll = max end
        _SetScroll(prevScroll)
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("VARIABLES_LOADED")
boot:SetScript("OnEvent", function() CreateList() end)
