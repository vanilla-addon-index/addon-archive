-- =========================
-- QuestShell UI — Guides Popup (with Faction Toggle, late-load safe)
-- Opaque black background (ignores global opacity).
-- Vanilla/Turtle (Lua 5.0) safe.
-- =========================

QuestShellUI = QuestShellUI or {}

-- ---------- locals ----------
local popup, overlay, scroll, child
local rowPool = {}
local btnAlliance, btnHorde, titleFS
local pumpFrame -- late-load refresher

-- --- Faction helpers / pref ---
local function _EnsureDB()
    QuestShellDB = QuestShellDB or {}; QuestShellDB.ui = QuestShellDB.ui or {}
    if QuestShellDB.ui.factionPref == nil then
        local pf = UnitFactionGroup and UnitFactionGroup("player") or "Alliance"
        if string.lower(pf or "") == "horde" then QuestShellDB.ui.factionPref = "Horde" else QuestShellDB.ui.factionPref = "Alliance" end
    end
end
local function _SetFactionPref(f)
    _EnsureDB(); if f == "Alliance" or f == "Horde" then QuestShellDB.ui.factionPref = f end
end
local function _FactionPref() _EnsureDB(); return QuestShellDB.ui.factionPref or "Alliance" end

-- ---------- guide helpers ----------
local function _GuideMeta(name)
    if QS_GuideMeta then return QS_GuideMeta(name) end
    local g = QuestShellGuides and QuestShellGuides[name]
    if type(g) == "table" then return g end
    return { title = tostring(name or "?"), steps = {} }
end

-- Filter by faction and order by minLevel, maxLevel, then title
local function _AllGuidesOrdered(faction)
    faction = faction or _FactionPref()
    local t, i = {}, 1
    for k, g in pairs(QuestShellGuides or {}) do
        local gf = (type(g)=="table" and g.faction) or nil
        if (not gf) or gf == faction then t[i] = k; i = i + 1 end
    end
    table.sort(t, function(a,b)
        local A = _GuideMeta(a); local B = _GuideMeta(b)
        local amin = (A and A.minLevel) or 0; local bmin = (B and B.minLevel) or 0
        if amin ~= bmin then return amin < bmin end
        local amax = (A and A.maxLevel) or 0; local bmax = (B and B.maxLevel) or 0
        if amax ~= bmax then return amax < bmax end
        local at = (A and A.title) or a; local bt = (B and B.title) or b
        return tostring(at) < tostring(bt)
    end)
    return t
end

local function _FmtTitle(meta)
    local title = (meta and meta.title) or "Guide"
    local a,b = meta and meta.minLevel, meta and meta.maxLevel
    if a or b then title = string.format("%s  %s-%s", title, tostring(a or "?"), tostring(b or "?")) end
    return title
end

local function _AcquireRow(i)
    if rowPool[i] then return rowPool[i] end
    local r = CreateFrame("Button", "QuestShellGuideRow"..tostring(i), child)
    r:SetHeight(20)

    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints(r)
    r.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    r.bg:SetVertexColor(1,1,1,0)

    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    r.hl:SetBlendMode("ADD")
    r.hl:SetAlpha(0.18)
    r.hl:SetAllPoints(r)

    r.check = r:CreateTexture(nil, "ARTWORK")
    r.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    r.check:SetWidth(14); r.check:SetHeight(14)
    r.check:SetPoint("LEFT", r, "LEFT", 6, 0)
    r.check:Hide()

    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", r, "LEFT", 24, 0)
    r.text:SetPoint("RIGHT", r, "RIGHT", -6, 0)
    r.text:SetJustifyH("LEFT")

    rowPool[i] = r
    return r
end

local function _ReleaseRows(fromIndex)
    local i = fromIndex
    while rowPool[i] do rowPool[i]:Hide(); i = i + 1 end
end

-- ---------- UI ----------
local function _StyleFactionButtons()
    if not btnAlliance or not btnHorde then return end
    local sel = _FactionPref()
    local function setBtn(b, on)
        if not b then return end
        local tex = b.tex
        if on then
            if tex then tex:SetVertexColor(1, 1, 0.2) end
            b:SetBackdropColor(0.20, 0.20, 0.20, 1.0)
        else
            if tex then tex:SetVertexColor(1, 1, 1) end
            b:SetBackdropColor(0.10, 0.10, 0.10, 1.0)
        end
    end
    setBtn(btnAlliance, sel == "Alliance")
    setBtn(btnHorde,   sel == "Horde")
end

-- Build/refresh rows for current faction
local function _RefreshList()
    if not popup then return end
    local names = _AllGuidesOrdered(_FactionPref())
    local y, i = 0, 1
    local cur = QuestShell and QuestShell.activeGuide

    while names[i] do
        local key  = names[i]
        local meta = _GuideMeta(key)
        local row  = _AcquireRow(i)

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
        row:SetPoint("RIGHT",   child, "RIGHT", 0, 0)

        row.text:SetText(_FmtTitle(meta))
        if key == cur then row.check:Show() else row.check:Hide() end

        local zebra = (math.mod(i, 2) == 0) and 0.10 or 0.06
        row.bg:SetVertexColor(1,1,1, key == cur and 0.12 or zebra)

        row:SetScript("OnClick", function()
            if QuestShell and QuestShell.LoadGuide then QuestShell.LoadGuide(key) end
            popup:Hide()
        end)

        row:Show()
        y = y + 22
        i = i + 1
    end

    _ReleaseRows(i)
    child:SetHeight(math.max(1, y))
    if scroll and scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    _StyleFactionButtons()
end

-- tiny refresher to catch late-loaded guides
local function _StartPump()
    if not pumpFrame then
        pumpFrame = CreateFrame("Frame", "QuestShellGuidesPump")
    end
    pumpFrame._elapsed, pumpFrame._total, pumpFrame._lastCount = 0, 0, 0
    pumpFrame:SetScript("OnUpdate", function()
        local dt = arg1 or 0
        pumpFrame._elapsed = pumpFrame._elapsed + dt
        pumpFrame._total   = pumpFrame._total + dt
        if pumpFrame._elapsed >= 0.2 then
            pumpFrame._elapsed = 0
            -- if count grew for current faction -> refresh
            local n = 0; local faction = _FactionPref()
            for _,g in pairs(QuestShellGuides or {}) do
                local gf = (type(g)=="table" and g.faction) or nil
                if (not gf) or gf == faction then n = n + 1 end
            end
            if n ~= pumpFrame._lastCount then
                pumpFrame._lastCount = n
                _RefreshList()
            end
        end
        -- stop after ~1.2s
        if pumpFrame._total >= 1.2 then pumpFrame:SetScript("OnUpdate", nil) end
    end)
end

local function _EnsurePopup()
    if popup then return end

    overlay = CreateFrame("Button", "QuestShellGuidesOverlay", UIParent)
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata("FULLSCREEN_DIALOG")
    overlay:EnableMouse(true)
    overlay:SetScript("OnClick", function() popup:Hide() end)
    overlay:Hide()

    popup = CreateFrame("Frame", "QuestShellGuidesPopup", UIParent)
    popup:SetWidth(320); popup:SetHeight(310)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetBackdrop({
        bgFile="Interface\\Buttons\\WHITE8x8",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=12,
        insets={ left=4, right=4, top=4, bottom=4 }
    })
    popup:SetBackdropColor(0,0,0,1.0)

    titleFS = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleFS:SetPoint("TOPLEFT", popup, "TOPLEFT", 8, -6)
    titleFS:SetText("QuestShell – Guides")

    -- Faction toggle bar
    local bar = CreateFrame("Frame", "QuestShellGuidesFactionBar", popup)
    bar:SetPoint("TOPLEFT", popup, "TOPLEFT", 8, -26)
    bar:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -8, -26)
    bar:SetHeight(22)

    local function makeBtn(name, label, xLeft)
        local b = CreateFrame("Button", name, bar)
        b:SetWidth(74); b:SetHeight(20)
        b:SetPoint("LEFT", bar, "LEFT", xLeft, 0)
        b:SetBackdrop({
            bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileSize=16, edgeSize=12,
            insets={ left=3, right=3, top=3, bottom=3 }
        })
        b:SetBackdropColor(0.10,0.10,0.10,1.0)
        b.tex = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.tex:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.tex:SetText(label)
        return b
    end

    btnAlliance = makeBtn("QuestShellBtnAlliance", "Alliance", 0)
    btnHorde    = makeBtn("QuestShellBtnHorde",    "Horde",    84)

    btnAlliance:SetScript("OnClick", function()
        _SetFactionPref("Alliance"); _StyleFactionButtons()
        if scroll then scroll:SetVerticalScroll(0) end
        if child then child:SetHeight(1) end
        QuestShellUI.ApplyAlpha_Menu()
        _RefreshList()
        _StartPump()
    end)
    btnHorde:SetScript("OnClick", function()
        _SetFactionPref("Horde"); _StyleFactionButtons()
        if scroll then scroll:SetVerticalScroll(0) end
        if child then child:SetHeight(1) end
        QuestShellUI.ApplyAlpha_Menu()
        _RefreshList()
        _StartPump()
    end)

    -- Scrollframe below the faction bar
    scroll = CreateFrame("ScrollFrame", "QuestShellGuidesScroll", popup, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", popup, "TOPLEFT", 8, - (26 + 22 + 6))
    scroll:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -28, 8)

    child = CreateFrame("Frame", "QuestShellGuidesScrollChild", scroll)
    scroll:SetScrollChild(child)
    child:SetWidth(320-8-28)
    child:SetHeight(1)

    popup:SetScript("OnShow", function() overlay:Show(); _RefreshList(); _StartPump() end)
    popup:SetScript("OnHide", function() overlay:Hide(); if pumpFrame then pumpFrame:SetScript("OnUpdate", nil) end end)
    popup:Hide()
end

-- Expose a safe internal refresh if anyone else wants to poke it
function QuestShellUI._RefreshGuidesListInternal()
    _RefreshList()
end

function QuestShellUI.ToggleMenu(anchor)
    _EnsureDB()
    _EnsurePopup()
    if popup:IsShown() then
        popup:Hide()
    else
        popup:ClearAllPoints()
        if (not anchor) or (anchor == popup) then
            popup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        else
            popup:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -2, -2)
        end
        _RefreshList()
        popup:Show()
        _StartPump()
    end
end

-- keep for API symmetry, but menu ignores global alpha on purpose
function QuestShellUI.ApplyAlpha_Menu()
    if popup then popup:SetBackdropColor(0,0,0,1.0) end
end
