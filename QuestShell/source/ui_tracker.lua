-- =========================
-- QuestShell UI — Tracker (translucent)
-- Mini "use item" button; prefers step.itemId/itemName, falls back to objectives.
-- Renders FLIGHTPATH and FLY steps.
-- Vanilla/Turtle (Lua 5.0) safe.
-- =========================

QuestShellUI = QuestShellUI or {}

-- ---------- Saved vars / opacity ----------
local function EnsureDB()
    QuestShellDB = QuestShellDB or {}
    QuestShellDB.ui = QuestShellDB.ui or {}
    if QuestShellDB.ui.trackerX == nil then QuestShellDB.ui.trackerX = 250 end
    if QuestShellDB.ui.trackerY == nil then QuestShellDB.ui.trackerY = -140 end
    if QuestShellDB.ui.trackerW == nil then QuestShellDB.ui.trackerW = 360 end
    if QuestShellDB.ui.trackerH == nil then QuestShellDB.ui.trackerH = 160 end
    if QuestShellDB.ui.locked   == nil then QuestShellDB.ui.locked   = false end
    if QuestShellDB.ui.trackerFontScale == nil then QuestShellDB.ui.trackerFontScale = 1.0 end
    if QuestShellDB.ui.backdropAlpha == nil then QuestShellDB.ui.backdropAlpha = 1.0 end
end
local function PanelA()
    EnsureDB()
    local a = QuestShellDB.ui.backdropAlpha or 1.0
    if a < 0 then a = 0 elseif a > 1 then a = 1 end
    return a
end

-- ---------- Constants ----------
local TEX_TALK   = "Interface\\GossipFrame\\GossipGossipIcon"
local TEX_ACCEPT = "Interface\\GossipFrame\\AvailableQuestIcon"
local TEX_TURNIN = "Interface\\GossipFrame\\ActiveQuestIcon"
local TEX_KILL   = "Interface\\Icons\\Ability_DualWield"
local TEX_LOOT   = "Interface\\Icons\\INV_Misc_Bag_08"
local TEX_OTHER  = "Interface\\Icons\\INV_Misc_Note_01"
local TEX_BULLET = "Interface\\Buttons\\UI-CheckBox-Up"
local TEX_CHECK  = "Interface\\Buttons\\UI-CheckBox-Check"
local TEX_RUN    = "Interface\\Icons\\Ability_Rogue_Sprint"
local TEX_USE    = "Interface\\Icons\\INV_Misc_Gear_02"
local TEX_FLIGHT = "Interface\\Minimap\\Tracking\\FlightMaster"

local LEFT_PAD, RIGHT_PAD = 8, 10
local SLOT_W, GAP = 12, 4
local ROW_VGAP = 3

-- ---------- Frame state ----------
local tracker, header, headerStepFS, chk
local content, rowPool
local baseHeaderSize, baseRowSize = nil, nil

-- Mini Use-Item button
local mini, miniIcon, miniCountFS
local _miniLastItemId, _miniLastItemName, _miniNextPoll = nil, nil, 0

local function ContentWidth() return (content and content:GetWidth() or 320) end
local function ClampAndPlace(f, x, y, fw, fh)
    if not f or not UIParent then return end
    f:ClearAllPoints(); f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x or 0, y or 0); f:Show()
    local sw, sh = UIParent:GetWidth() or 1024, UIParent:GetHeight() or 768
    local cx, cy = x or 0, y or 0
    local ww, hh = fw or (f:GetWidth() or 360), fh or (f:GetHeight() or 160)
    if cx > sw - ww then cx = sw - ww end
    if cx < 0 then cx = 0 end
    if cy > 0 then cy = 0 end
    if cy < -(sh - hh) then cy = -(sh - hh) end
    f:ClearAllPoints(); f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", cx, cy)
    return cx, cy
end

-- ---------- Row pool ----------
local function EnsureRowPool() if rowPool then return end; rowPool = {} end
local function AcquireRow(i)
    EnsureRowPool()
    if rowPool[i] then return rowPool[i] end

    local r = CreateFrame("Frame", "QuestShellTrackerRow"..tostring(i), content)
    r:SetHeight(14)

    r.bullet = r:CreateTexture(nil, "ARTWORK")
    r.bullet:SetWidth(SLOT_W); r.bullet:SetHeight(SLOT_W)
    r.bullet:SetTexture(TEX_BULLET)

    r.check = r:CreateTexture(nil, "OVERLAY")
    r.check:SetWidth(SLOT_W); r.check:SetHeight(SLOT_W)
    r.check:SetTexture(TEX_CHECK)
    r.check:SetPoint("CENTER", r.bullet, "CENTER", 0, 0)

    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetWidth(SLOT_W); r.icon:SetHeight(SLOT_W)

    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.text:SetJustifyH("LEFT")

    rowPool[i] = r
    return r
end
local function ReleaseRows(fromIndex) if not rowPool then return end; local i=fromIndex; while rowPool[i] do rowPool[i]:Hide(); i=i+1 end end

-- ---------- Font scale ----------
local function QS_TrackerApplyFontScale()
    local scale = (QuestShellDB and QuestShellDB.ui and QuestShellDB.ui.trackerFontScale) or 1.3
    if headerStepFS then
        local f,s,fl = headerStepFS:GetFont()
        if not baseHeaderSize then baseHeaderSize = s or 12 end
        headerStepFS:SetFont(f, math.floor(baseHeaderSize * scale + 0.5), fl)
    end
    if rowPool then
        local i = 1
        while rowPool[i] do
            local fs = rowPool[i].text
            if fs then
                local f,s,fl = fs:GetFont()
                if not baseRowSize then baseRowSize = s or 12 end
                fs:SetFont(f, math.floor(baseRowSize * scale + 0.5), fl)
            end
            i = i + 1
        end
    end
end

-- ---------- Build rows ----------
local function BuildRows(step, fallbackTitle, forceComplete)
    local rows, c = {}, 0
    local stype = string.upper(step and step.type or "")

    if stype == "ACCEPT" or stype == "TURNIN" then
        local npc = step and step.npc
        local who = (type(npc) == "table" and npc.name) or (type(npc) == "string" and npc) or "the quest giver"
        c=c+1; rows[c] = { icon=TEX_TALK, text=("Talk to "..who), bullet=false }
        c=c+1; rows[c] = { icon=(stype=="TURNIN" and TEX_TURNIN or TEX_ACCEPT), text=(step and step.title) or "", bullet=false }

    elseif stype == "TRAVEL" then
        local note = (step and step.note) or "Travel to the marked location."
        local cmeta = step and step.coords or {}
        local where = ""
        if cmeta and cmeta.x and cmeta.y then
            local z = cmeta.map or ""
            where = string.format("(%.1f, %.1f %s)", cmeta.x, cmeta.y, z)
        end
        c=c+1; rows[c] = { icon=TEX_RUN, text=note, bullet=false }
        if where ~= "" then c=c+1; rows[c] = { icon=nil, text=where, bullet=false } end

    elseif stype == "USE_ITEM" then
        local nameTxt = step and (step.itemName or ("Item ID "..tostring(step.itemId or "?")))
        local tar = (step and step.npc and step.npc.name) and (" with "..step.npc.name.." selected") or ""
        local line = "Use: "..(nameTxt or "item")..tar
        c=c+1; rows[c] = { icon=TEX_USE, text=line, bullet=false }

    elseif stype == "FLIGHTPATH" then
        local who = (step and step.npc and step.npc.name) or "the flight master"
        local note = (step and step.note) or ("Speak to "..who.." and learn the flight path.")
        c=c+1; rows[c] = { icon=TEX_FLIGHT, text=note, bullet=false }

    elseif stype == "FLY" then
        local who = (step and step.npc and step.npc.name) or "the flight master"
        local dest = (step and step.destination) or "your destination"
        local base = (step and step.note) or ("Speak to "..who.." and fly to "..dest..".")
        c=c+1; rows[c] = { icon=TEX_FLIGHT, text=base, bullet=false }

    else
        local note = (step and step.note) or (fallbackTitle or "")
        c=c+1; rows[c] = { icon=nil, text=note, bullet=false }
        local orows = QS_BuildObjectiveRows and QS_BuildObjectiveRows(step, forceComplete) or {}
        local j = 1
        while j <= table.getn(orows) do
            local R = orows[j]
            local kind = R.kind or "other"
            local icon = (kind=="kill" and TEX_KILL) or (kind=="loot" and TEX_LOOT) or TEX_OTHER
            c=c+1; rows[c] = { icon=icon, text=(R.text or ""), bullet=true, done=(R.done and true or false) }
            j = j + 1
        end
    end
    return rows
end

local function RenderRows(rows)
    local prev = nil
    local i = 1
    while rows and rows[i] do
        local data = rows[i]
        local r = AcquireRow(i)

        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", prev or content, prev and "BOTTOMLEFT" or "TOPLEFT", 0, prev and -ROW_VGAP or 0)

        r.bullet:ClearAllPoints(); r.bullet:SetPoint("LEFT", r, "LEFT", 0, 0)
        if data.bullet then
            r.bullet:Show()
            if data.done then r.check:SetAlpha(1); r.check:SetVertexColor(0.20, 1.00, 0.20)
            else r.check:SetAlpha(0); r.check:SetVertexColor(1,1,1) end
        else
            r.bullet:Hide(); r.check:SetAlpha(0); r.check:SetVertexColor(1,1,1)
        end

        local x = SLOT_W + GAP
        if data.icon then r.icon:Show(); r.icon:SetTexture(data.icon); r.icon:ClearAllPoints(); r.icon:SetPoint("LEFT", r, "LEFT", x, 0); x = x + SLOT_W + GAP
        else r.icon:Hide() end

        r.text:ClearAllPoints(); r.text:SetPoint("LEFT", r, "LEFT", x, 0)
        r.text:SetWidth(ContentWidth() - x); r.text:SetText(data.text or "")
        if data.bullet and data.done then r.text:SetTextColor(0.60, 1.00, 0.60) else r.text:SetTextColor(1,1,1) end

        r:SetWidth(ContentWidth())
        r:SetHeight(r.text:GetHeight() + 2)
        r:Show()

        prev = r; i = i + 1
    end
    ReleaseRows(i)
    QS_TrackerApplyFontScale()
end

-- ---------- Header ----------
local function UpdateHeaderStep()
    local steps = (QS_GuideData and QS_GuideData()) or {}
    local n = table.getn(steps or {})

    local function isEligible(i)
        local s = steps[i]; if not s then return false end
        return (not QS_StepIsEligible) or QS_StepIsEligible(s)
    end

    local curIdx = 1
    local st = QS_GuideState and QS_GuideState() or nil
    if st and st.currentStep then curIdx = st.currentStep end

    local cur = 0; local i = 1
    while i <= math.min(curIdx, n) do if isEligible(i) then cur = cur + 1 end; i = i + 1 end
    if cur == 0 and n > 0 then cur = 1 end

    headerStepFS:SetText("Step "..tostring(cur))
end

-- ---------- Item helpers ----------
local function _NameFromItemLink(link)
    if not link or link == "" then return nil end
    local _, _, name = string.find(link, "%[(.+)%]")
    if name and name ~= "" then return name end
    if GetItemInfo then
        local nm = GetItemInfo(link)
        if nm and nm ~= "" then return nm end
    end
    return nil
end

local function _FindItemInBags_ByIdOrName(id, name)
    if QS_FindItemInBags_ByIdOrName then
        local b,s = QS_FindItemInBags_ByIdOrName(id, name)
        if b and s then return b,s end
    end
    if QS_FindItemInBags and id then
        local b,s = QS_FindItemInBags(id)
        if b and s then return b,s end
    end
    if not name or name == "" then return nil, nil end
    local want = string.lower(name)
    for b=0,4 do
        local slots = (GetContainerNumSlots and GetContainerNumSlots(b)) or 0
        for s=1,slots do
            local link = GetContainerItemLink and GetContainerItemLink(b,s)
            if link then
                local nm = _NameFromItemLink(link)
                if nm and string.lower(nm) == want then
                    return b, s
                end
            end
        end
    end
    return nil, nil
end

local function _CountItemInBags_ByIdOrName(id, name)
    if QS_CountItemInBags and id then
        local c = QS_CountItemInBags(id)
        if c then return c end
    end
    if not name or name == "" then return 0 end
    local want = string.lower(name)
    local total = 0
    for b=0,4 do
        local slots = (GetContainerNumSlots and GetContainerNumSlots(b)) or 0
        for s=1,slots do
            local link = GetContainerItemLink and GetContainerItemLink(b,s)
            if link then
                local nm = _NameFromItemLink(link)
                if nm and string.lower(nm) == want then
                    local _, _, count = GetContainerItemInfo(b, s)
                    total = total + (count or 1)
                end
            end
        end
    end
    return total
end

-- Prefer step.itemId/itemName; also check objectives for kind="use_item"
local function _FindUseItemForStep(step)
    if not step then return nil, nil end
    if step.itemId or step.itemName then
        return step.itemId, step.itemName
    end
    local stype = string.upper(step.type or "")
    if stype == "COMPLETE" and step.objectives and type(step.objectives)=="table" then
        local i=1
        while step.objectives[i] do
            local o = step.objectives[i]
            if o and string.lower(o.kind or "")=="use_item" then
                return (o.itemId or nil), (o.label or o.name or step.itemName or nil)
            end
            i = i + 1
        end
    end
    return nil, nil
end

local function _MiniUseItemClick()
    if (not _miniLastItemId) and (not _miniLastItemName) then return end
    local b,s = _FindItemInBags_ByIdOrName(_miniLastItemId, _miniLastItemName)
    if b and s and UseContainerItem then
        UseContainerItem(b, s)
    else
        if QS_Print then QS_Print("Item not found in bags.") end
    end
end

local function _MiniEnsure()
    if mini then return end
    mini = CreateFrame("Button", "QuestShellMiniUse", header)
    mini:SetWidth(24); mini:SetHeight(24)
    mini:SetPoint("RIGHT", header, "RIGHT", -28, 0)

    miniIcon = mini:CreateTexture(nil, "BACKGROUND")
    miniIcon:SetAllPoints(mini)
    miniIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    miniCountFS = mini:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    miniCountFS:SetPoint("BOTTOMRIGHT", mini, "BOTTOMRIGHT", -1, 1)
    miniCountFS:SetText("")

    mini:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mini:SetScript("OnClick", _MiniUseItemClick)
    mini:SetScript("OnEnter", function()
        if (not _miniLastItemId) and (not _miniLastItemName) then return end
        local b,s = _FindItemInBags_ByIdOrName(_miniLastItemId, _miniLastItemName)
        if not b or not s then return end
        if GameTooltip and GameTooltip.SetBagItem then
            GameTooltip:SetOwner(mini, "ANCHOR_RIGHT")
            GameTooltip:SetBagItem(b, s)
            GameTooltip:Show()
        end
    end)
    mini:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    mini:SetScript("OnUpdate", function()
        _miniNextPoll = _miniNextPoll + (arg1 or 0)
        if _miniNextPoll < 0.25 then return end
        _miniNextPoll = 0
        if (not _miniLastItemId) and (not _miniLastItemName) then return end
        if not mini:IsShown() then return end
        local c = _CountItemInBags_ByIdOrName(_miniLastItemId, _miniLastItemName) or 0
        if c > 1 then miniCountFS:SetText(tostring(c)) else miniCountFS:SetText("") end
    end)
end

local function _ShowMiniForStep(step)
    _MiniEnsure()
    local id, name = _FindUseItemForStep(step)
    if (not id) and (not name or name == "") then
        mini:Hide()
        _miniLastItemId, _miniLastItemName = nil, nil
        return
    end

    _miniLastItemId, _miniLastItemName = id, name

    local tex = nil
    do
        local b,s = _FindItemInBags_ByIdOrName(id, name)
        if b and s and GetContainerItemInfo then
            local t = GetContainerItemInfo(b, s)
            tex = t
        end
        if (not tex) and id and GetItemInfo then
            local _nm,_link,_q,_ilvl,_req,_type,_sub,_stack,_equip, texture = GetItemInfo(id)
            tex = texture
        end
    end
    miniIcon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")

    local c = _CountItemInBags_ByIdOrName(id, name) or 0
    if c > 1 then miniCountFS:SetText(tostring(c)) else miniCountFS:SetText("") end

    mini:Show()
end

-- ---------- Create tracker ----------
local function CreateTracker()
    EnsureDB(); if tracker then return end

    tracker = CreateFrame("Frame", "QuestShellTracker", UIParent)
    tracker:SetWidth(QuestShellDB.ui.trackerW or 360)
    tracker:SetHeight(QuestShellDB.ui.trackerH or 160)
    tracker:SetFrameStrata("DIALOG")
    tracker:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=16,
        insets={ left=4, right=4, top=4, bottom=4 }
    })
    tracker:SetBackdropColor(0,0,0, PanelA())

    tracker:SetMovable(true); tracker:EnableMouse(true); tracker:SetClampedToScreen(true)
    tracker:SetResizable(true); tracker:SetMinResize(260, 120); tracker:SetMaxResize(700, 320)
    tracker:SetScript("OnSizeChanged", function()
        EnsureDB(); QuestShellDB.ui.trackerW, QuestShellDB.ui.trackerH = tracker:GetWidth(), tracker:GetHeight()
        QuestShellUI.Update()
    end)

    local x = QuestShellDB.ui.trackerX or 250
    local y = QuestShellDB.ui.trackerY or -140
    x, y = ClampAndPlace(tracker, x, y, tracker:GetWidth(), tracker:GetHeight())
    QuestShellDB.ui.trackerX, QuestShellDB.ui.trackerY = x, y

    local grip = CreateFrame("Button", "QuestShellTrackerSize", tracker)
    grip:SetWidth(16); grip:SetHeight(16)
    grip:SetPoint("BOTTOMRIGHT", tracker, "BOTTOMRIGHT", -4, 4)
    local gtex = grip:CreateTexture(nil, "ARTWORK"); gtex:SetAllPoints(grip)
    gtex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetScript("OnMouseDown", function() tracker:StartSizing() end)
    grip:SetScript("OnMouseUp", function() tracker:StopMovingOrSizing(); QuestShellDB.ui.trackerW, QuestShellDB.ui.trackerH = tracker:GetWidth(), tracker:GetHeight() end)

    header = CreateFrame("Frame", "QuestShellTrackerHeader", tracker)
    header:SetPoint("TOPLEFT", tracker, "TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", tracker, "TOPRIGHT", -4, -4)
    header:SetHeight(24)
    header:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=12,
        insets={ left=3, right=3, top=3, bottom=3 }
    })
    header:SetBackdropColor(0,0,0, PanelA())
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton","RightButton")
    header:SetFrameLevel(tracker:GetFrameLevel()+10)
    header:SetScript("OnDragStart", function()
        EnsureDB(); if QuestShellDB.ui.locked then return end
        tracker:StartMoving(); tracker.isMoving = true
    end)
    header:SetScript("OnDragStop", function()
        if tracker.isMoving then
            tracker:StopMovingOrSizing(); tracker.isMoving = nil
            local _,_,_,sx,sy = tracker:GetPoint()
            sx, sy = ClampAndPlace(tracker, sx, sy, tracker:GetWidth(), tracker:GetHeight())
            QuestShellDB.ui.trackerX, QuestShellDB.ui.trackerY = sx, sy
        end
    end)

    headerStepFS = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    headerStepFS:SetPoint("LEFT", header, "LEFT", 6, 0)
    headerStepFS:SetText("Step 1")

    chk = CreateFrame("CheckButton", "QuestShellTrackerHeaderCheck", header, "UICheckButtonTemplate")
    chk:SetWidth(16); chk:SetHeight(16)
    chk:SetPoint("RIGHT", header, "RIGHT", -6, 0)
    chk:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    chk:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    chk:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    local ct = chk:CreateTexture(nil, "OVERLAY"); ct:SetTexture("Interface\\Buttons\\UI-CheckBox-Check"); ct:SetVertexColor(0.35, 0.75, 1.0); ct:SetAllPoints(chk)
    chk:SetCheckedTexture(ct)
    chk:SetScript("OnClick", function()
        local st = QS_GuideState and QS_GuideState() or nil
        if not st then return end
        local cur = st.currentStep or 1
        if QS_UI_SetStepCompleted then QS_UI_SetStepCompleted(cur, chk:GetChecked()) end
    end)

    _MiniEnsure(); mini:Hide()

    content = CreateFrame("Frame", "QuestShellTrackerContent", tracker)
    content:SetPoint("TOPLEFT", tracker, "TOPLEFT", LEFT_PAD, -(4+24+6))
    content:SetPoint("RIGHT", tracker, "RIGHT", -RIGHT_PAD, 0)
    content:SetHeight(1)

    tracker:Show()
    QS_TrackerApplyFontScale()
end

-- ---------- Public API ----------
function QuestShellUI.Update(title, typ, body)
    if not tracker then CreateTracker() end
    local steps = (QS_GuideData and QS_GuideData()) or {}
    UpdateHeaderStep()

    local step = QS_CurrentStep and QS_CurrentStep() or nil
    local st = QS_GuideState and QS_GuideState() or nil
    local cur = (st and st.currentStep) or 1
    local forceComplete = (QS_UI_IsStepCompleted and QS_UI_IsStepCompleted(cur)) and true or false

    local rows = BuildRows(step, title or "", forceComplete)
    RenderRows(rows)

    _ShowMiniForStep(step)

    if QS_UI_IsStepCompleted then chk:SetChecked(forceComplete) end
end

function QuestShellUI.SetFontScale(scale)
    if not scale then return end
    if scale < 0.6 then scale = 0.6 end
    if scale > 1.8 then scale = 1.8 end
    QuestShellDB = QuestShellDB or {}; QuestShellDB.ui = QuestShellDB.ui or {}
    QuestShellDB.ui.trackerFontScale = scale
    QS_TrackerApplyFontScale()
    QuestShellUI.Update()
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("VARIABLES_LOADED")
boot:SetScript("OnEvent", function() CreateTracker() end)
