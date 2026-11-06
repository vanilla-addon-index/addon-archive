-- RelationshipsAttune: UI.lua
-- Left raid list is a FauxScrollFrame so it never overflows the box.
-- Step rows on the right have hover tooltips (name / desc / where to start),
-- are clickable to expand extra info, and highlight green when complete.
-- Pure Lua, no XML, 1.12 / Lua 5.0 compatible (Turtle/Octo).

RelationshipsAttune = RelationshipsAttune or {}
local RA = RelationshipsAttune
local L  = RelationshipsAttune_L
RA.UI = {}
local UI = RA.UI

-- Textures
local TEX_WHITE     = "Interface\\Buttons\\WHITE8X8"
local TEX_CHECK     = "Interface\\RaidFrame\\ReadyCheck-Ready"
local TEX_CROSS     = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local TEX_WAIT      = "Interface\\RaidFrame\\ReadyCheck-Waiting"
local TEX_QMARK     = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Colors
local C_DONE       = { 0.20, 0.90, 0.30 }
local C_PARTIAL    = { 0.95, 0.80, 0.20 }
local C_NONE       = { 0.90, 0.30, 0.30 }
local C_UNKNOWN    = { 0.55, 0.55, 0.55 }
local C_TURTLE     = { 0.55, 0.85, 1.00 }
local C_KEYS       = { 0.95, 0.75, 0.35 }
local C_INPROGRESS = { 1.00, 0.60, 0.15 }  -- orange: quest accepted / step in progress

-- ---------------------------------------------------------------
-- Force-complete confirmation dialogs (StaticPopup)
-- In vanilla 1.12, StaticPopup OnAccept is called as OnAccept(dialog.data),
-- so the data arrives as arg1 (Lua 5.0 vararg). `this` inside OnAccept is
-- NOT the dialog frame, so this.data is nil. We stash the data on the
-- dialog itself via OnShow (which does run with this = dialog) and read
-- it back from arg1 with a dialog fallback for safety.
-- ---------------------------------------------------------------
StaticPopupDialogs = StaticPopupDialogs or {}

local function RATTUNE_StashData()
    -- OnShow runs with `this` = the dialog frame. StaticPopup_Show already
    -- assigns dialog.data, but we snapshot it into an upvalue table so the
    -- OnAccept closures can find it even on clients that don't forward arg1.
    if this then RATTUNE_LastPopupData = this.data end
end

-- Attunement id awaiting the user's confirmation for a force / unforce.
-- StaticPopup OnAccept in vanilla 1.12 does not reliably receive dialog.data
-- as arg1, so we snapshot the id here at click time and read it back on accept.
RATTUNE_PendingForceAtt = nil

StaticPopupDialogs["RATTUNE_FORCE_ATT"] = {
    text = "Force complete the entire \"%s\" attunement?\n\nEvery step will be marked as done for tracking. You can undo this later.",
    button1 = "Force Complete",
    button2 = "Cancel",
    OnAccept = function()
        local id = RATTUNE_PendingForceAtt
        RATTUNE_PendingForceAtt = nil
        if id then RA:SetAttForced(id, true) end
    end,
    OnCancel = function() RATTUNE_PendingForceAtt = nil end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 1,
}

StaticPopupDialogs["RATTUNE_UNFORCE_ATT"] = {
    text = "Undo forced completion for \"%s\"?\n\nProgress will revert to real, scanned state.",
    button1 = "Undo",
    button2 = "Cancel",
    OnAccept = function()
        local id = RATTUNE_PendingForceAtt
        RATTUNE_PendingForceAtt = nil
        if id then RA:SetAttForced(id, false) end
    end,
    OnCancel = function() RATTUNE_PendingForceAtt = nil end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 1,
}


local selectedPlayer = nil
local selectedRaid   = nil

-- Layout constants
local FRAME_W, FRAME_H  = 1120, 600
local LEFT_W            = 300
local ROW_H             = 41
local STEP_ROW_H        = 28
local STEP_EXPAND_H     = 74
local HEADER_H          = 60
local VISIBLE_RAIDS     = 11

-- ---------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------
local function statusColor(prog)
    if not prog or not prog.applicable then return C_UNKNOWN end
    if prog.done then return C_DONE end
    if prog.doneCount and prog.doneCount > 0 then return C_PARTIAL end
    return C_NONE
end

local function fs(parent, text, size, r, g, b, flags)
    local f = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if text then f:SetText(text) end
    f:SetFont("Fonts\\FRIZQT__.TTF", size or 11, flags or "")
    if r then f:SetTextColor(r, g, b) end
    return f
end

local function iconTex(parent, path, size)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetWidth(size); t:SetHeight(size)
    if path then t:SetTexture(path) end
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return t
end

local function solid(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetTexture(TEX_WHITE)
    t:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
    return t
end

local function resolveStepIcon(step)
    if step.icon then return step.icon end
    if step.type == "item" and step.id and GetItemIcon then
        local i = GetItemIcon(step.id)
        if i then return i end
    end
    return TEX_QMARK
end

local function categoryColor(cat)
    if cat == "Turtle" then return C_TURTLE end
    if cat == "Keys & Access" then return C_KEYS end
    return { 1, 1, 1 }
end

-- ---------------------------------------------------------------
-- Root frame
-- ---------------------------------------------------------------
local frame
local playerTabs   = {}
local raidButtons  = {}
local stepRows     = {}
local detail       = {}

function UI:Build()
    if frame then return end

    frame = CreateFrame("Frame", "RelationshipsAttuneFrame", UIParent)
    frame:SetWidth(FRAME_W); frame:SetHeight(FRAME_H)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true); frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    -- Solid opaque overlay to make the window much less transparent
    -- (the DialogBox background alone is quite see-through in vanilla).
    frame.bgSolid = solid(frame, "BACKGROUND", 0.04, 0.05, 0.08, 0.94)
    frame.bgSolid:SetPoint("TOPLEFT",     frame, "TOPLEFT",      12, -13)
    frame.bgSolid:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -13,  12)
    -- Subtle gold-tinted top plate for the header
    frame.bgHeader = solid(frame, "BACKGROUND", 0.12, 0.10, 0.06, 0.55)
    frame.bgHeader:SetPoint("TOPLEFT",  frame.bgSolid, "TOPLEFT",  0, 0)
    frame.bgHeader:SetPoint("TOPRIGHT", frame.bgSolid, "TOPRIGHT", 0, 0)
    frame.bgHeader:SetHeight(28)
    frame:Hide()

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)

    -- Small title at the top left of the UI
    frame.title = fs(frame, "Relationships Attunement", 11, 1, 0.82, 0, "OUTLINE")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)

    -- Player selector strip sits below the title inside the existing header
    -- space; do not move the divider or columns.
    frame.playerStrip = CreateFrame("Frame", nil, frame)
    frame.playerStrip:SetPoint("TOPLEFT",  frame, "TOPLEFT",  20, -36)
    frame.playerStrip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -36)
    frame.playerStrip:SetHeight(22)

    local div = solid(frame, "ARTWORK", 1, 0.82, 0, 0.35)
    div:SetPoint("TOPLEFT",  frame, "TOPLEFT",  16, -66)
    div:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -66)
    div:SetHeight(1)

    -- Left column
    frame.leftPane = CreateFrame("Frame", nil, frame)
    frame.leftPane:SetPoint("TOPLEFT",    frame, "TOPLEFT",   16, -72)
    frame.leftPane:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 50)
    frame.leftPane:SetWidth(LEFT_W)

    -- Panel backing for the left list, dark and mostly opaque
    local leftBG = solid(frame.leftPane, "BACKGROUND", 0.02, 0.03, 0.05, 0.60)
    leftBG:SetAllPoints(frame.leftPane)

    frame.leftScroll = CreateFrame("ScrollFrame", "RelationshipsAttuneRaidScroll",
                                   frame.leftPane, "FauxScrollFrameTemplate")
    frame.leftScroll:SetPoint("TOPLEFT",     frame.leftPane, "TOPLEFT",  0, 0)
    frame.leftScroll:SetPoint("BOTTOMRIGHT", frame.leftPane, "BOTTOMRIGHT", -20, 0)
    frame.leftScroll:SetScript("OnVerticalScroll", function()
        FauxScrollFrame_OnVerticalScroll(ROW_H + 2, function() UI:RenderRaidList() end)
    end)
    frame.leftPane:EnableMouseWheel(true)
    frame.leftPane:SetScript("OnMouseWheel", function()
        local step = ROW_H + 2
        local off = FauxScrollFrame_GetOffset(frame.leftScroll) or 0
        local total = table.getn(RelationshipsAttune_Data)
        off = off - (arg1 or 0)
        if off < 0 then off = 0 end
        if off > (total - VISIBLE_RAIDS) then off = total - VISIBLE_RAIDS end
        if off < 0 then off = 0 end
        frame.leftScroll:SetVerticalScroll(off * step)
        FauxScrollFrame_OnVerticalScroll(step, function() UI:RenderRaidList() end)
    end)

    -- Vertical divider
    local vdiv = solid(frame, "ARTWORK", 1, 0.82, 0, 0.30)
    vdiv:SetPoint("TOPLEFT",    frame.leftPane, "TOPRIGHT", 4, 0)
    vdiv:SetPoint("BOTTOMLEFT", frame.leftPane, "BOTTOMRIGHT", 4, 0)
    vdiv:SetWidth(1)

    -- Right column
    frame.rightPane = CreateFrame("Frame", nil, frame)
    frame.rightPane:SetPoint("TOPLEFT",     frame.leftPane, "TOPRIGHT", 14, 0)
    frame.rightPane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 50)

    local rightBG = solid(frame.rightPane, "BACKGROUND", 0.02, 0.03, 0.05, 0.50)
    rightBG:SetAllPoints(frame.rightPane)

    detail.icon = iconTex(frame.rightPane, TEX_QMARK, 40)
    detail.icon:SetPoint("TOPLEFT", frame.rightPane, "TOPLEFT", 4, -4)

    detail.name = fs(frame.rightPane, "", 15, 1, 0.82, 0, "OUTLINE")
    detail.name:SetPoint("TOPLEFT", detail.icon, "TOPRIGHT", 10, -2)

    detail.category = fs(frame.rightPane, "", 10, 0.75, 0.75, 0.75)
    detail.category:SetPoint("TOPLEFT", detail.name, "BOTTOMLEFT", 0, -2)

    -- Force Complete (attunement-level) button. Sits in the top-right of the
    -- right pane, hidden when viewing another player's data.
    detail.forceBtn = CreateFrame("Button", nil, frame.rightPane, "UIPanelButtonTemplate")
    detail.forceBtn:SetWidth(150); detail.forceBtn:SetHeight(20)
    detail.forceBtn:SetPoint("TOPRIGHT", frame.rightPane, "TOPRIGHT", -4, -4)
    detail.forceBtn:SetText("Force Complete")
    detail.forceBtn:SetScript("OnClick", function()
        local attId = selectedRaid
        if not attId then return end
        local att
        local data = RelationshipsAttune_Data
        for i = 1, table.getn(data) do
            if data[i].id == attId then att = data[i]; break end
        end
        if not att then return end
        RATTUNE_PendingForceAtt = attId
        if RA:IsAttForced(attId) then
            StaticPopup_Show("RATTUNE_UNFORCE_ATT", att.name)
        else
            StaticPopup_Show("RATTUNE_FORCE_ATT", att.name)
        end
    end)

    -- Progress bar: give it explicit left+right anchors AND a border so it
    -- always has a resolvable width, then size the fill from that width.
    detail.barBG = solid(frame.rightPane, "BORDER", 0, 0, 0, 0.90)
    detail.barBG:SetPoint("TOPLEFT",  frame.rightPane, "TOPLEFT",  4, -HEADER_H)
    detail.barBG:SetPoint("TOPRIGHT", frame.rightPane, "TOPRIGHT", -4, -HEADER_H)
    detail.barBG:SetHeight(18)

    -- Thin gold outline for the bar
    local blt = solid(frame.rightPane, "ARTWORK", 1, 0.82, 0, 0.55)
    blt:SetPoint("TOPLEFT",     detail.barBG, "TOPLEFT",     0, 0)
    blt:SetPoint("TOPRIGHT",    detail.barBG, "TOPRIGHT",    0, 0)
    blt:SetHeight(1)
    local blb = solid(frame.rightPane, "ARTWORK", 1, 0.82, 0, 0.55)
    blb:SetPoint("BOTTOMLEFT",  detail.barBG, "BOTTOMLEFT",  0, 0)
    blb:SetPoint("BOTTOMRIGHT", detail.barBG, "BOTTOMRIGHT", 0, 0)
    blb:SetHeight(1)

    detail.barFill = solid(frame.rightPane, "ARTWORK", 0.20, 0.75, 0.30, 0.95)
    detail.barFill:SetPoint("TOPLEFT",    detail.barBG, "TOPLEFT",    1, -1)
    detail.barFill:SetPoint("BOTTOMLEFT", detail.barBG, "BOTTOMLEFT", 1,  1)
    detail.barFill:SetWidth(1)

    detail.barText = fs(frame.rightPane, "", 12, 1, 1, 1, "OUTLINE")
    detail.barText:SetPoint("CENTER", detail.barBG, "CENTER", 0, 0)

    -- Step host
    frame.stepHost = CreateFrame("Frame", nil, frame.rightPane)
    frame.stepHost:SetPoint("TOPLEFT",     frame.rightPane, "TOPLEFT",     4, -HEADER_H - 26)
    frame.stepHost:SetPoint("BOTTOMRIGHT", frame.rightPane, "BOTTOMRIGHT", -4, 0)
    -- Vanilla clients can report an unresolved height for a frame positioned by
    -- two anchors during the first render. Give the expanded-step area a fixed
    -- resolved height so six default-expanded rows reach the same bottom line as
    -- the left pane instead of stopping early with a blank band underneath.
    frame.stepHost:SetHeight(FRAME_H - 72 - 50 - HEADER_H - 26)
    frame.stepHost.page = 0
    frame.stepHost.pageCount = 1
    frame.stepHost:EnableMouseWheel(true)
    frame.stepHost:SetScript("OnMouseWheel", function()
        -- arg1 = +1 wheel up = previous page, -1 wheel down = next page.
        local delta = arg1 or 0
        local p = (frame.stepHost.page or 0) - delta
        local pc = frame.stepHost.pageCount or 1
        if p < 0 then p = 0 end
        if p > pc - 1 then p = pc - 1 end
        frame.stepHost.page = p
        UI:RenderDetail()
    end)
    -- Also accept wheel events over the whole right pane so the user does not
    -- have to hover the exact step area.
    frame.rightPane:EnableMouseWheel(true)
    frame.rightPane:SetScript("OnMouseWheel", function()
        local script = frame.stepHost:GetScript("OnMouseWheel")
        if script then script() end
    end)

    -- Bottom buttons (Sync Group removed)
    local mmBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    mmBtn:SetWidth(120); mmBtn:SetHeight(22)
    mmBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 14)
    mmBtn:SetText("Toggle Minimap")
    mmBtn:SetScript("OnClick", function()
        if RA.Minimap then RA.Minimap:Toggle() end
    end)

    local scanBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    scanBtn:SetWidth(80); scanBtn:SetHeight(22)
    scanBtn:SetPoint("RIGHT", mmBtn, "LEFT", -6, 0)
    scanBtn:SetText("Rescan")
    scanBtn:SetScript("OnClick", function()
        RA:ScanQuestLog(); RA:ScanBags(); RA:RecomputeAll(); UI:Refresh()
    end)

    local hint = fs(frame, "Hover Over A Step For Details - Click To Minimise And Expand A Step. Type \"/Attune\" To Open This Panel.",
                    10, 0.75, 0.75, 0.75)
    hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 20)

    -- One-shot delayed refresh: on first Show, frame widths need a tick to settle
    -- (barBG:GetWidth() can return 0 the first time), so we re-render after a short delay.
    frame._pending = 0
    frame:SetScript("OnUpdate", function()
        if not this._needsRelayout then return end
        this._pending = (this._pending or 0) + (arg1 or 0)
        if this._pending >= 0.05 then
            this._needsRelayout = false
            this._pending = 0
            UI:Refresh()
        end
    end)
    frame:SetScript("OnShow", function()
        this._needsRelayout = true
        this._pending = 0
    end)
end

-- ---------------------------------------------------------------
-- Data helpers
-- ---------------------------------------------------------------
local function playerList()
    local youLabel
    if RA.playerName then
        local fac = RA.playerFaction or "Neutral"
        youLabel = RA.playerName .. "  |  " .. fac
    else
        youLabel = L.UI_YOU
    end
    local list = { { key = nil, label = youLabel, isYou = true } }
    if RelationshipsAttuneDB and RelationshipsAttuneDB.players then
        for key, p in pairs(RelationshipsAttuneDB.players) do
            if key ~= RA.playerKey and key ~= RA.playerName then
                table.insert(list, { key = key, label = p.name or key })
            end
        end
    end
    return list
end

local function progressFor(playerKey, attId)
    if playerKey == nil then
        return RelationshipsAttuneCharDB.progress[attId]
    end
    local p = RelationshipsAttuneDB.players[playerKey]
    return p and p.progress and p.progress[attId] or nil
end

local function isExpanded(attId, i)
    local e = RelationshipsAttuneCharDB.expanded
    -- Default to expanded for every step, including rows created after scroll.
    -- Only an explicit false from a manual click collapses a row.
    if e and e[attId] and e[attId][i] == false then return nil end
    return true
end

local function toggleExpanded(attId, i)
    local e = RelationshipsAttuneCharDB.expanded
    if not e[attId] then e[attId] = {} end
    if isExpanded(attId, i) then
        e[attId][i] = false
    else
        e[attId][i] = nil
    end
end

-- ---------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------
local function renderPlayerTabs()
    local list = playerList()
    for i = 1, table.getn(playerTabs) do playerTabs[i]:Hide() end

    local x = 0
    for i = 1, table.getn(list) do
        local entry = list[i]
        local b = playerTabs[i]
        if not b then
            b = CreateFrame("Button", nil, frame.playerStrip)
            b:SetHeight(20)
            b.bg = solid(b, "BACKGROUND", 1, 1, 1, 0.10)
            b.bg:SetAllPoints(b)
            b.text = fs(b, "", 11, 1, 1, 1)
            b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
            playerTabs[i] = b
        end
        b.entry = entry
        b.text:SetText(entry.label)
        local w = b.text:GetStringWidth() + 20
        b:SetWidth(w)
        b:ClearAllPoints()
        b:SetPoint("LEFT", frame.playerStrip, "LEFT", x, 0)
        x = x + w + 4

        local isSel = (entry.key == selectedPlayer)
        if entry.isYou then
            local fac = RA.playerFaction
            if fac == "Alliance" then
                b.bg:SetVertexColor(0.20, 0.45, 1.00, isSel and 0.55 or 0.30)
                b.text:SetTextColor(0.60, 0.80, 1.00)
            elseif fac == "Horde" then
                b.bg:SetVertexColor(0.90, 0.15, 0.15, isSel and 0.55 or 0.30)
                b.text:SetTextColor(1.00, 0.65, 0.55)
            else
                b.bg:SetVertexColor(1, 0.82, 0, isSel and 0.45 or 0.20)
                b.text:SetTextColor(1, 0.95, 0.85)
            end
        else
            b.bg:SetVertexColor(1, 0.82, 0, isSel and 0.45 or 0.12)
            b.text:SetTextColor(1, isSel and 0.95 or 0.85, isSel and 0.6 or 0.85)
        end
        b:SetScript("OnClick", function()
            selectedPlayer = this.entry.key
            UI:Refresh()
        end)
        b:Show()
    end
end

function UI:RenderRaidList()
    local data = RelationshipsAttune_Data
    local total = table.getn(data)

    FauxScrollFrame_Update(frame.leftScroll, total, VISIBLE_RAIDS, ROW_H + 2)
    local offset = FauxScrollFrame_GetOffset(frame.leftScroll) or 0

    for i = 1, table.getn(raidButtons) do raidButtons[i]:Hide() end

    for row = 1, VISIBLE_RAIDS do
        local i = row + offset
        if i <= total then
            local att = data[i]
            local b = raidButtons[row]
            if not b then
                b = CreateFrame("Button", nil, frame.leftPane)
                b:SetHeight(ROW_H)
                b.bg = solid(b, "BACKGROUND", 1, 1, 1, 0.08)
                b.bg:SetAllPoints(b)
                b.sel = solid(b, "BORDER", 1, 0.82, 0, 0.25)
                b.sel:SetAllPoints(b); b.sel:Hide()
                b.icon = iconTex(b, TEX_QMARK, 26)
                b.icon:SetPoint("LEFT", b, "LEFT", 4, 0)
                b.name = fs(b, "", 12, 1, 1, 1, "OUTLINE")
                b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 8, -1)
                b.count = fs(b, "", 10, 0.8, 0.8, 0.8)
                b.count:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 8, 1)
                b.status = b:CreateTexture(nil, "OVERLAY")
                b.status:SetWidth(16); b.status:SetHeight(16)
                b.status:SetPoint("RIGHT", b, "RIGHT", -6, 0)
                raidButtons[row] = b
            end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT",  frame.leftPane, "TOPLEFT",  0, -(row - 1) * (ROW_H + 2))
            b:SetWidth(LEFT_W - 20)

            b.icon:SetTexture(att.icon or TEX_QMARK)
            b.att = att

            local prog = progressFor(selectedPlayer, att.id)
            local color = statusColor(prog)
            b.name:SetText(att.name)
            local nc = categoryColor(att.category)
            b.name:SetTextColor(nc[1], nc[2], nc[3])

            if prog and prog.applicable then
                b.count:SetText(prog.doneCount .. " / " .. prog.total .. " steps")
                b.count:SetTextColor(color[1], color[2], color[3])
                if prog.done then
                    b.status:SetTexture(TEX_CHECK)
                    b.bg:SetVertexColor(0.20, 0.90, 0.30, 0.25)
                elseif (prog.doneCount or 0) > 0 then
                    b.status:SetTexture(TEX_WAIT)
                    b.bg:SetVertexColor(1, 1, 1, 0.08)
                else
                    b.status:SetTexture(TEX_CROSS)
                    b.bg:SetVertexColor(1, 1, 1, 0.08)
                end
                b.status:Show()
            else
                b.count:SetText("N/A for your faction")
                b.count:SetTextColor(C_UNKNOWN[1], C_UNKNOWN[2], C_UNKNOWN[3])
                b.status:Hide()
                b.bg:SetVertexColor(1, 1, 1, 0.05)
            end

            if selectedRaid == att.id then b.sel:Show() else b.sel:Hide() end
            b:SetScript("OnClick", function()
                selectedRaid = this.att.id
                frame.stepHost.page = 0
                UI:Refresh()
            end)
            b:Show()
        end
    end
end

local function stepTypeLabel(kind)
    if kind == "quest" then return "Quest"
    elseif kind == "item" then return "Item"
    elseif kind == "rep"  then return "Reputation"
    elseif kind == "level" then return "Level" end
    return kind or ""
end

local function setStepTooltip(row)
    row.frame:EnableMouse(true)
    row.frame:SetScript("OnEnter", function()
        local step = this.step
        if not step then return end
        GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
        GameTooltip:AddLine(step.name or "?", 1, 0.82, 0)
        GameTooltip:AddLine(stepTypeLabel(step.type), 0.6, 0.8, 1)
        if step.desc then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(step.desc, 0.9, 0.9, 0.9, 1)
        end
        if step.start then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Where to start:", 1, 0.82, 0)
            GameTooltip:AddLine(step.start, 0.9, 0.9, 0.9, 1)
        end
        if step.faction then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Faction: " .. step.faction, 0.7, 0.7, 0.7)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to expand / collapse.", 0.5, 0.85, 1)
        GameTooltip:Show()
    end)
    row.frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.frame:RegisterForClicks("LeftButtonUp")
    row.frame:SetScript("OnMouseUp", function()
        local step = this.step
        if not step or not this.attId then return end
        toggleExpanded(this.attId, this.stepIndex)
        UI:RenderDetail()
    end)
end

-- Compute a reliable width for the progress bar even before layout settles.
local function computeBarWidth()
    local w = detail.barBG:GetWidth()
    if not w or w < 10 then
        local l, r = detail.barBG:GetLeft(), detail.barBG:GetRight()
        if l and r then w = r - l end
    end
    if not w or w < 10 then
        w = (frame.rightPane:GetWidth() or 0) - 8
    end
    if not w or w < 10 then
        w = FRAME_W - LEFT_W - 40
    end
    return w
end

function UI:RenderDetail()
    local data = RelationshipsAttune_Data
    if not selectedRaid then selectedRaid = data[1] and data[1].id end
    local att
    for i = 1, table.getn(data) do
        if data[i].id == selectedRaid then att = data[i]; break end
    end
    if not att then return end

    detail.icon:SetTexture(att.icon or TEX_QMARK)
    detail.name:SetText(att.name)
    local cat = att.category
    if cat == "Turtle" then
        detail.category:SetText("Turtle / Octo custom content  |  " .. (att.faction or "Both"))
        detail.category:SetTextColor(C_TURTLE[1], C_TURTLE[2], C_TURTLE[3])
    elseif cat == "Keys & Access" then
        detail.category:SetText("Keys & Access (dungeon shortcut)  |  " .. (att.faction or "Both"))
        detail.category:SetTextColor(C_KEYS[1], C_KEYS[2], C_KEYS[3])
    else
        detail.category:SetText("Vanilla content  |  " .. (att.faction or "Both"))
        detail.category:SetTextColor(0.85, 0.85, 0.85)
    end

    local prog = progressFor(selectedPlayer, att.id)
    local done = prog and prog.doneCount or 0
    local total = prog and prog.total or table.getn(att.steps)
    local pct = (total > 0) and (done / total) or 0
    if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end

    local barW = computeBarWidth()
    -- Fill uses SetWidth from the left edge. barFill is anchored to barBG's
    -- TOPLEFT and BOTTOMLEFT, so its width fully controls the visible fill.
    local fillW = math.max(1, (barW - 2) * pct)
    detail.barFill:SetWidth(fillW)

    local c = statusColor(prog)
    detail.barFill:SetVertexColor(c[1], c[2], c[3], 0.95)
    detail.barText:SetText(done .. " / " .. total .. "  (" .. math.floor(pct * 100 + 0.5) .. "%)")

    -- Update attunement-level Force button (only for your own data)
    if detail.forceBtn then
        if selectedPlayer ~= nil then
            detail.forceBtn:Hide()
        else
            if RA:IsAttForced(att.id) then
                detail.forceBtn:SetText("Undo Force Complete")
            else
                detail.forceBtn:SetText("Force Complete")
            end
            detail.forceBtn:Show()
        end
    end

    -- Build applicable step list
    local applicable = {}
    for i = 1, table.getn(att.steps) do
        local step = att.steps[i]
        if RA:StepApplies(step) then
            table.insert(applicable, { idx = i, step = step })
        end
    end

    for i = 1, table.getn(stepRows) do stepRows[i].frame:Hide() end

    -- Page-based layout: 5 steps per page, no partial rows.
    local PER_PAGE = 5
    local totalSteps = table.getn(applicable)
    local pageCount = math.ceil(totalSteps / PER_PAGE)
    if pageCount < 1 then pageCount = 1 end
    frame.stepHost.pageCount = pageCount
    local page = frame.stepHost.page or 0
    if page > pageCount - 1 then page = pageCount - 1 end
    if page < 0 then page = 0 end
    frame.stepHost.page = page

    local startI = page * PER_PAGE + 1
    local endI   = startI + PER_PAGE - 1
    if endI > totalSteps then endI = totalSteps end

    local y = 0

    for slot = 1, PER_PAGE do
        local si = startI + slot - 1
        if si > endI then
            local r = stepRows[slot]
            if r then r.frame:Hide() end
        else
        local entry   = applicable[si]
        local step    = entry.step
        local origIdx = entry.idx
        local expanded = isExpanded(att.id, origIdx)
        local rowH = expanded and STEP_EXPAND_H or STEP_ROW_H

        local row = stepRows[slot]
        if not row then
            row = {}
            row.frame = CreateFrame("Button", nil, frame.stepHost)
            row.bg = solid(row.frame, "BACKGROUND", 1, 1, 1, 0.06)
            row.bg:SetAllPoints(row.frame)
            row.icon = iconTex(row.frame, TEX_QMARK, 22)
            row.icon:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 4, -3)
            row.type = fs(row.frame, "", 9, 0.7, 0.7, 0.7)
            row.type:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 36, -2)
            row.name = fs(row.frame, "", 12, 1, 1, 1)
            row.name:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 36, -15)
            row.name:SetPoint("RIGHT", row.frame, "RIGHT", -32, 0)
            row.name:SetJustifyH("LEFT")
            row.status = row.frame:CreateTexture(nil, "OVERLAY")
            row.status:SetWidth(18); row.status:SetHeight(18)
            row.status:SetPoint("TOPRIGHT", row.frame, "TOPRIGHT", -8, -4)
            row.extra = fs(row.frame, "", 10, 0.90, 0.90, 0.90)
            row.extra:SetPoint("TOPLEFT",  row.frame, "TOPLEFT", 36, -32)
            row.extra:SetPoint("TOPRIGHT", row.frame, "TOPRIGHT", -8, -32)
            row.extra:SetJustifyH("LEFT")
            row.extra:SetJustifyV("TOP")
            setStepTooltip(row)
            stepRows[slot] = row
        end
        row.frame.step      = step
        row.frame.attId     = att.id
        row.frame.stepIndex = origIdx

        row.frame:SetHeight(rowH)
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT",  frame.stepHost, "TOPLEFT",  0, y)
        row.frame:SetPoint("TOPRIGHT", frame.stepHost, "TOPRIGHT", 0, y)

        row.icon:SetTexture(resolveStepIcon(step))
        row.type:SetText(stepTypeLabel(step.type))
        row.name:SetText(step.name or "?")

        local ok = prog and prog.steps and prog.steps[origIdx]
        local inProg = prog and prog.stepsInProgress and prog.stepsInProgress[origIdx]
        if ok then
            row.status:SetTexture(TEX_CHECK); row.status:Show()
            row.name:SetTextColor(C_DONE[1], C_DONE[2], C_DONE[3])
            row.bg:SetVertexColor(0.20, 0.90, 0.30, 0.28)
        elseif inProg then
            row.status:SetTexture(TEX_WAIT); row.status:Show()
            row.name:SetTextColor(C_INPROGRESS[1], C_INPROGRESS[2], C_INPROGRESS[3])
            row.bg:SetVertexColor(C_INPROGRESS[1], C_INPROGRESS[2], C_INPROGRESS[3], 0.22)
        elseif prog and prog.applicable then
            row.status:SetTexture(TEX_CROSS); row.status:Show()
            row.name:SetTextColor(1, 1, 1)
            row.bg:SetVertexColor(1, 1, 1, 0.06)
        else
            row.status:SetTexture(TEX_WAIT); row.status:Show()
            row.name:SetTextColor(C_UNKNOWN[1], C_UNKNOWN[2], C_UNKNOWN[3])
            row.bg:SetVertexColor(1, 1, 1, 0.04)
        end

        if expanded then
            local txt = ""
            if step.desc  then txt = txt .. step.desc end
            if step.start then
                if txt ~= "" then txt = txt .. "\n\n" end
                txt = txt .. "|cffffd200Where:|r " .. step.start
            end
            if txt == "" and step.type ~= "level" then txt = "No extra info provided." end
            row.extra:SetText(txt)
            row.extra:Show()
        else
            row.extra:SetText("")
            row.extra:Hide()
        end

        row.frame:Show()

        y = y - (rowH + 4)
        end
    end
end

function UI:Refresh()
    if not frame or not frame:IsShown() then return end
    renderPlayerTabs()
    self:RenderRaidList()
    self:RenderDetail()
end

function UI:Init() self:Build() end

function UI:IsShown()
    return frame and frame:IsShown()
end

function UI:Show()
    self:Build()
    if not selectedRaid then
        selectedRaid = RelationshipsAttune_Data[1] and RelationshipsAttune_Data[1].id
    end
    if frame.stepHost then frame.stepHost.page = 0 end
    frame:Show()
    self:Refresh()
end

function UI:Hide() if frame then frame:Hide() end end

function UI:Toggle()
    self:Build()
    if frame:IsShown() then frame:Hide() else self:Show() end
end
