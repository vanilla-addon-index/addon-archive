-- Combat Log 112: standalone log window for WoW 1.12 / Turtle WoW (Octo WoW).
-- pfUI-style flat theme, resizable, white text, source/direction/distance filters.
-- Damage events come from Nampower. Names for arbitrary NPCs need SuperWoW (or any
-- addon that lets UnitName() accept a GUID). Distance uses UnitXP_SP3 if present.
-- Written for Lua 5.0 (no '#', no '%', no select/gmatch).

CombatLog112DB = CombatLog112DB or {}

local DEFAULTS = {
    maxLines = 300,
    heal     = true,
    fontSize = 12,
    w        = 640,
    h        = 330,
    scope    = "me",    -- me | party | raid
    dir      = "both",  -- in | out | both
    dist     = 0,       -- yards, 0 = max (no limit)
}

local CL = { lines = {}, filtered = {}, hasFilter = false, pos = {}, neg = {},
                offset = 0, stick = true, visible = 1, rows = {}, dirty = true }
local frame, titleText, slider
local btnScope, btnDir, btnDist
local DB

----------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------
local function msg(t)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[CLog]|r "..t) end
end

-- bit test without bit library: is bit with value 'b' set in n?
local function hasBit(n, b)
    n = tonumber(n) or 0
    return math.floor(n / b) - 2 * math.floor(n / (b * 2)) == 1
end

-- normalise a GUID string so "0x000..ABC", "0xabc" and "ABC" compare equal
local normCache, normCount = {}, 0
local function norm(g)
    if not g then return nil end
    local s = normCache[g]
    if s then return s end
    s = string.upper(tostring(g))
    s = string.gsub(s, "^0X0*", "")
    if s == "" then s = "0" end
    if normCount > 5000 then normCache = {}; normCount = 0 end
    normCache[g] = s; normCount = normCount + 1
    return s
end

local function unitGuid(unit)
    if GetUnitGUID then
        local ok, g = pcall(GetUnitGUID, unit)
        if ok and g and g ~= 0 and g ~= "" then return g end
    end
    if UnitExists then
        local ok, e, g = pcall(UnitExists, unit)
        if ok and e and type(g) == "string" then return g end
    end
    return nil
end

----------------------------------------------------------------------
-- names
----------------------------------------------------------------------
local names, nameCount, missT = {}, 0, {}
local function setName(n, nm)
    if not names[n] then
        nameCount = nameCount + 1
        if nameCount > 3000 then names = {}; nameCount = 1 end
    end
    names[n] = nm
end

local function learn(unit)
    if UnitExists(unit) then
        local g = norm(unitGuid(unit))
        if g then
            local nm = UnitName(unit)
            if nm then setName(g, nm) end
        end
    end
end

local TOKENS = {"player","target","targettarget","mouseover","pet","focus","party1","party2","party3","party4"}

local function nameOf(guid)
    local n = norm(guid)
    if not n then return "?" end
    local c = names[n]
    if c then return c end
    local now = GetTime and GetTime() or 0
    if missT[n] and now - missT[n] < 3 then return "Unit:"..string.sub(n, -4) end
    -- GUID as unit token (SuperWoW / ClassicAPI)
    local ok, nm = pcall(UnitName, guid)
    if ok and nm and nm ~= "" then setName(n, nm); return nm end
    -- standard tokens
    for _, unit in ipairs(TOKENS) do
        if UnitExists(unit) and norm(unitGuid(unit)) == n then
            local u = UnitName(unit)
            if u then setName(n, u); return u end
        end
    end
    missT[n] = now
    return "Unit:"..string.sub(n, -4)
end

----------------------------------------------------------------------
-- spells / schools
----------------------------------------------------------------------
local spellCache = {}
local function spellName(id)
    if not id or id == 0 then return "Spell" end
    if spellCache[id] then return spellCache[id] end
    local n
    if GetSpellNameAndRankForId then
        local ok, name = pcall(GetSpellNameAndRankForId, id)
        if ok and name then n = name end
    end
    if not n and SpellInfo then
        local ok, name = pcall(SpellInfo, id)
        if ok and name then n = name end
    end
    n = n or ("SpellID:"..tostring(id))
    spellCache[id] = n
    return n
end

-- Nampower sends the school as an index (0 = Physical ... 6 = Arcane)
local SCHOOLS = {[0]="Physical",[1]="Holy",[2]="Fire",[3]="Nature",[4]="Frost",[5]="Shadow",[6]="Arcane"}
local SCHOOL_MASK = {[8]="Nature",[16]="Frost",[32]="Shadow",[64]="Arcane"}
local function schoolName(s)
    s = tonumber(s)
    if not s then return "" end
    return SCHOOLS[s] or SCHOOL_MASK[s] or ("School "..s)
end

local MISS = {[1]="Miss",[2]="Resist",[3]="Dodge",[4]="Parry",[5]="Block",[6]="Evade",
              [7]="Immune",[8]="Immune",[9]="Deflect",[10]="Absorb",[11]="Reflect"}
local VSTATE = {[0]="Miss",[2]="Dodge",[3]="Parry",[5]="Block",[6]="Evade",[7]="Immune",[8]="Deflect"}

local function clock()
    if date then return date("%H:%M:%S") end
    return string.format("%.1f", GetTime and GetTime() or 0)
end

----------------------------------------------------------------------
-- filters: scope / direction / distance
----------------------------------------------------------------------
local active = {}   -- normalised guids of the units in the chosen scope

function CL:RebuildScope()
    local set = {}
    local function add(unit)
        if UnitExists(unit) then
            local g = norm(unitGuid(unit))
            if g then
                set[g] = true
                local nm = UnitName(unit)
                if nm then setName(g, nm) end
            end
        end
    end
    add("player"); add("pet")
    if DB.scope ~= "me" then
        for i = 1, 4 do add("party"..i); add("partypet"..i) end
        if DB.scope == "raid" then
            for i = 1, 40 do add("raid"..i); add("raidpet"..i) end
        end
    end
    active = set
end

-- returns "OUT" / "IN" or nil when the event should be hidden
local function classify(cg, tg)
    local side
    if active[norm(cg) or ""] then side = "OUT"
    elseif active[norm(tg) or ""] then side = "IN"
    else return nil end
    if DB.dir == "in" and side ~= "IN" then return nil end
    if DB.dir == "out" and side ~= "OUT" then return nil end
    return side
end

local function distanceTo(guid)
    if not UnitXP then return nil end
    local ok, d = pcall(UnitXP, "distanceBetween", "player", guid)
    if ok and type(d) == "number" and d >= 0 then return d end
    return nil
end

local function passDistance(side, cg, tg)
    local limit = DB.dist
    if not limit or limit <= 0 then return true end
    local other = (side == "OUT") and tg or cg
    if active[norm(other) or ""] then return true end
    local d = distanceTo(other)
    if not d then
        if not CL.warnedDist then
            CL.warnedDist = true
            CL:AddLine("Distance unavailable (UnitXP missing or GUID not accepted), showing all.")
        end
        return true
    end
    return d <= limit
end

----------------------------------------------------------------------
-- pfUI theme
----------------------------------------------------------------------
local function parseColor(str, r, g, b, a)
    if type(str) == "string" then
        local _, _, cr, cg, cb, ca = string.find(str, "([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,?%s*([%d%.]*)")
        if cr then return tonumber(cr), tonumber(cg), tonumber(cb), tonumber(ca) or a end
    end
    return r, g, b, a
end

local function themeColors()
    local bg  = {0.08, 0.08, 0.08, 0.92}
    local bor = {0.25, 0.25, 0.25, 1}
    if pfUI_config and pfUI_config.appearance and pfUI_config.appearance.border then
        local c = pfUI_config.appearance.border
        bg[1], bg[2], bg[3], bg[4] = parseColor(c.background, bg[1], bg[2], bg[3], bg[4])
        bor[1], bor[2], bor[3], bor[4] = parseColor(c.color, bor[1], bor[2], bor[3], bor[4])
        if bg[4] > 0.95 then bg[4] = 0.92 end
    end
    return bg, bor
end

local function themeFont()
    if pfUI_config and pfUI_config.global and pfUI_config.global.font_default then
        local f = pfUI_config.global.font_default
        if f and f ~= "" then
            if string.find(f, "\\") or string.find(f, "/") then return f end
            return "Interface\\AddOns\\pfUI\\fonts\\"..f..".ttf"
        end
    end
    if pfUI and pfUI.font_default then return pfUI.font_default end
    return STANDARD_TEXT_FONT or "Fonts\\ARIALN.TTF"
end

local FLAT = {
    bgFile = "Interface\\BUTTONS\\WHITE8X8",
    edgeFile = "Interface\\BUTTONS\\WHITE8X8",
    tile = false, tileSize = 0, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function flatBackdrop(f, alphaOverride)
    local bg, bor = themeColors()
    f:SetBackdrop(FLAT)
    f:SetBackdropColor(bg[1], bg[2], bg[3], alphaOverride or bg[4])
    f:SetBackdropBorderColor(bor[1], bor[2], bor[3], bor[4])
end

local function makeButton(parent, text, w, h, tipTitle, tipText)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(w); b:SetHeight(h)
    flatBackdrop(b, 1)
    b:SetBackdropColor(0.12, 0.12, 0.12, 1)
    local fs = b:CreateFontString(nil, "OVERLAY")
    fs:SetFont(themeFont(), 11, "OUTLINE")
    fs:SetPoint("CENTER", b, "CENTER", 0, 0)
    fs:SetText(text)
    fs:SetTextColor(1, 1, 1, 1)
    b.text = fs
    b:SetScript("OnEnter", function()
        b:SetBackdropBorderColor(0.2, 1, 0.8, 1)
        if tipTitle then
            GameTooltip:SetOwner(b, "ANCHOR_BOTTOM")
            GameTooltip:SetText(tipTitle, 1, 1, 1)
            if tipText then GameTooltip:AddLine(tipText, 0.8, 0.8, 0.8, 1) end
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function()
        local _, bor = themeColors()
        b:SetBackdropBorderColor(bor[1], bor[2], bor[3], bor[4])
        GameTooltip:Hide()
    end)
    return b
end

----------------------------------------------------------------------
-- layout / refresh
----------------------------------------------------------------------
local HEADER, FOOTER, PAD = 28, 20, 8

local function getRow(i)
    local fs = CL.rows[i]
    if not fs then
        fs = frame:CreateFontString(nil, "ARTWORK")
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        fs:SetTextColor(1, 1, 1, 1)
        CL.rows[i] = fs
    end
    return fs
end

-- keyword search: all plain words must appear (any order); "-word" excludes lines containing it
function CL:Match(line)
    local l = string.lower(line)
    for _, w in ipairs(self.neg) do
        if string.find(l, w, 1, true) then return false end
    end
    for _, w in ipairs(self.pos) do
        if not string.find(l, w, 1, true) then return false end
    end
    return true
end

function CL:SetKeyword(text)
    text = string.lower(text or "")
    self.pos, self.neg = {}, {}
    for w in string.gfind(text, "%S+") do
        if string.sub(w, 1, 1) == "-" then
            if string.len(w) > 1 then table.insert(self.neg, string.sub(w, 2)) end
        else
            table.insert(self.pos, w)
        end
    end
    self.hasFilter = (table.getn(self.pos) + table.getn(self.neg)) > 0
    self.filtered = {}
    if self.hasFilter then
        for _, line in ipairs(self.lines) do
            if self:Match(line) then table.insert(self.filtered, line) end
        end
    end
    self.offset = 0; self.stick = true
    self:Refresh()
end

function CL:Clear()
    self.lines = {}; self.filtered = {}
    self.offset = 0; self.stick = true
    self:Refresh()
end

-- the list currently shown (filtered or full)
function CL:View()
    if self.hasFilter then return self.filtered end
    return self.lines
end

function CL:Refresh()
    if not frame or not frame:IsShown() then return end
    local src = self:View()
    local total = table.getn(src)
    local vis = self.visible
    local maxOff = total - vis
    if maxOff < 0 then maxOff = 0 end
    if self.stick then self.offset = maxOff end
    if self.offset > maxOff then self.offset = maxOff end
    if self.offset < 0 then self.offset = 0 end

    for i = 1, vis do
        local idx = i + self.offset
        local fs = CL.rows[i]
        if fs then
            if idx <= total then
                fs:SetText(src[idx]); fs:Show()
            else
                fs:SetText(""); fs:Hide()
            end
        end
    end

    if slider then
        self.updating = true
        slider:SetMinMaxValues(0, maxOff)
        slider:SetValue(self.offset)
        self.updating = false
        if maxOff == 0 then slider:Hide() else slider:Show() end
    end
end

function CL:Layout()
    if not frame then return end
    local size = DB.fontSize
    local rowH = size + 3
    local areaH = frame:GetHeight() - HEADER - FOOTER
    local vis = math.floor(areaH / rowH)
    if vis < 1 then vis = 1 end
    self.visible = vis
    local w = frame:GetWidth() - PAD - 18
    if w < 50 then w = 50 end
    local font = themeFont()
    for i = 1, vis do
        local fs = getRow(i)
        fs:SetFont(font, size, "")
        fs:SetTextColor(1, 1, 1, 1)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -HEADER - (i - 1) * rowH)
        fs:SetWidth(w); fs:SetHeight(rowH)
    end
    for i = vis + 1, table.getn(CL.rows) do CL.rows[i]:Hide() end
    if titleText then titleText:SetFont(font, size, "OUTLINE") end
    self:Refresh()
end

function CL:AddLine(text)
    local line = "["..clock().."] "..text
    table.insert(self.lines, line)
    local max = (DB and DB.maxLines) or 300
    while table.getn(self.lines) > max do table.remove(self.lines, 1) end
    if self.hasFilter and self:Match(line) then
        table.insert(self.filtered, line)
        while table.getn(self.filtered) > max do table.remove(self.filtered, 1) end
    end
    if frame and frame:IsShown() then self:Refresh() end
end

----------------------------------------------------------------------
-- filter buttons
----------------------------------------------------------------------
local SCOPES = {"me", "party", "raid"}
local DIRS   = {"both", "in", "out"}
local DISTS  = {40, 80, 0}
local SCOPE_LABEL = {me = "Me", party = "Party", raid = "Raid"}
local DIR_LABEL   = {both = "Both", ["in"] = "Incoming", out = "Outgoing"}

local function distLabel(d)
    if not d or d <= 0 then return "Max" end
    return tostring(d)
end

local function cycle(list, cur)
    for i = 1, table.getn(list) do
        if list[i] == cur then return list[i + 1] or list[1] end
    end
    return list[1]
end

local function updateButtons()
    if btnScope then btnScope.text:SetText(SCOPE_LABEL[DB.scope] or "Me") end
    if btnDir then btnDir.text:SetText(DIR_LABEL[DB.dir] or "Both") end
    if btnDist then btnDist.text:SetText(distLabel(DB.dist)) end
end

function CL:FilterChanged()
    updateButtons()
    self:RebuildScope()
    self:AddLine("Filter: "..(SCOPE_LABEL[DB.scope] or "?").." / "..(DIR_LABEL[DB.dir] or "?").." / "..distLabel(DB.dist)..(DB.dist > 0 and " yd" or ""))
end

----------------------------------------------------------------------
-- window
----------------------------------------------------------------------
local function savePosition()
    if not frame then return end
    local l, t = frame:GetLeft(), frame:GetTop()
    if l and t then DB.x = l; DB.y = t end
    DB.w = frame:GetWidth(); DB.h = frame:GetHeight()
end

local function makeWindow()
    if frame then return end
    frame = CreateFrame("Frame", "CombatLog112Frame", UIParent)
    frame:SetWidth(DB.w); frame:SetHeight(DB.h)
    if DB.x and DB.y then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", DB.x, DB.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true); frame:SetResizable(true)
    frame:SetMinResize(480, 120)
    frame:SetMaxResize(1400, 900)
    frame:EnableMouse(true); frame:EnableMouseWheel(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); savePosition() end)
    flatBackdrop(frame)

    -- header
    titleText = frame:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(themeFont(), DB.fontSize, "OUTLINE")
    titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -8)
    titleText:SetText("Combat Log")
    titleText:SetTextColor(1, 1, 1, 1)

    local sep = frame:CreateTexture(nil, "ARTWORK")
    sep:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    sep:SetVertexColor(0.25, 0.25, 0.25, 1)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -(HEADER - 4))
    sep:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -(HEADER - 4))

    local close = makeButton(frame, "x", 18, 18)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() frame:Hide(); DB.shown = false end)

    local clear = makeButton(frame, "Clear", 44, 18)
    clear:SetPoint("RIGHT", close, "LEFT", -4, 0)
    clear:SetScript("OnClick", function() CL:Clear() end)

    btnDist = makeButton(frame, "Max", 40, 18, "Distance", "Only show events whose other party is within this range (yards). Max = no limit.")
    btnDist:SetPoint("RIGHT", clear, "LEFT", -10, 0)
    btnDist:SetScript("OnClick", function() DB.dist = cycle(DISTS, DB.dist); CL:FilterChanged() end)

    btnDir = makeButton(frame, "Both", 64, 18, "Direction", "Incoming, outgoing or both, relative to the chosen group.")
    btnDir:SetPoint("RIGHT", btnDist, "LEFT", -3, 0)
    btnDir:SetScript("OnClick", function() DB.dir = cycle(DIRS, DB.dir); CL:FilterChanged() end)

    btnScope = makeButton(frame, "Me", 46, 18, "Source", "Me (and pet), Party, or Raid.")
    btnScope:SetPoint("RIGHT", btnDir, "LEFT", -3, 0)
    btnScope:SetScript("OnClick", function() DB.scope = cycle(SCOPES, DB.scope); CL:FilterChanged() end)
    updateButtons()

    -- keyword search box
    local box = CreateFrame("EditBox", "CombatLog112Search", frame)
    box:SetHeight(18)
    box:SetPoint("LEFT", titleText, "RIGHT", 12, 0)
    box:SetPoint("RIGHT", btnScope, "LEFT", -8, 0)
    flatBackdrop(box, 1)
    box:SetBackdropColor(0.05, 0.05, 0.05, 1)
    box:SetFont(themeFont(), 11, "")
    box:SetTextColor(1, 1, 1, 1)
    box:SetTextInsets(5, 5, 0, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(60)
    local hint = box:CreateFontString(nil, "OVERLAY")
    hint:SetFont(themeFont(), 11, "")
    hint:SetPoint("LEFT", box, "LEFT", 5, 0)
    hint:SetTextColor(0.5, 0.5, 0.5, 1)
    hint:SetText("Search...")
    local function paintBox()
        local _, bor = themeColors()
        if box.focused or box:GetText() ~= "" then
            box:SetBackdropBorderColor(0.2, 1, 0.8, 1)
        else
            box:SetBackdropBorderColor(bor[1], bor[2], bor[3], bor[4])
        end
        if box:GetText() == "" and not box.focused then hint:Show() else hint:Hide() end
    end
    box:SetScript("OnTextChanged", function() paintBox(); CL:SetKeyword(box:GetText()) end)
    box:SetScript("OnEditFocusGained", function() box.focused = true; paintBox() end)
    box:SetScript("OnEditFocusLost", function() box.focused = false; paintBox() end)
    box:SetScript("OnEnterPressed", function() box:ClearFocus() end)
    box:SetScript("OnEscapePressed", function()
        if box:GetText() ~= "" then box:SetText("") else box:ClearFocus() end
    end)
    box:SetScript("OnEnter", function()
        GameTooltip:SetOwner(box, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Search", 1, 1, 1)
        GameTooltip:AddLine("Type words to show only matching lines (any order), e.g. 'mind blast'.", 0.8, 0.8, 0.8, 1)
        GameTooltip:AddLine("Put - before a word to hide it, e.g. 'shadow -melee'.", 0.8, 0.8, 0.8, 1)
        GameTooltip:AddLine("Enter = leave the box, Esc = clear text.", 0.8, 0.8, 0.8, 1)
        GameTooltip:Show()
    end)
    box:SetScript("OnLeave", function() GameTooltip:Hide() end)
    CL.box = box
    paintBox()

    -- scrollbar
    slider = CreateFrame("Slider", nil, frame)
    slider:SetOrientation("VERTICAL")
    slider:SetWidth(8)
    slider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -HEADER)
    slider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, FOOTER)
    slider:SetMinMaxValues(0, 0)
    slider:SetValueStep(1)
    slider:SetValue(0)
    slider:SetThumbTexture("Interface\\BUTTONS\\WHITE8X8")
    local thumb = slider:GetThumbTexture()
    thumb:SetWidth(8); thumb:SetHeight(26)
    thumb:SetVertexColor(0.4, 0.4, 0.4, 1)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    track:SetVertexColor(0.15, 0.15, 0.15, 1)
    track:SetAllPoints(slider)
    slider:SetScript("OnValueChanged", function()
        if CL.updating then return end
        local total = table.getn(CL:View())
        local maxOff = total - CL.visible
        if maxOff < 0 then maxOff = 0 end
        CL.offset = math.floor(slider:GetValue() + 0.5)
        CL.stick = (CL.offset >= maxOff)
        CL:Refresh()
    end)

    frame:SetScript("OnMouseWheel", function()
        local total = table.getn(CL:View())
        local maxOff = total - CL.visible
        if maxOff < 0 then maxOff = 0 end
        local o = CL.offset - arg1 * 3
        if o < 0 then o = 0 end
        if o > maxOff then o = maxOff end
        CL.offset = o
        CL.stick = (o >= maxOff)
        CL:Refresh()
    end)

    -- resize grips (both bottom corners, large hit area, drawn above everything)
    local function makeGrip(corner)
        local grip = CreateFrame("Button", nil, frame)
        grip:SetWidth(24); grip:SetHeight(24)
        grip:SetFrameLevel(frame:GetFrameLevel() + 20)
        local mirror = (corner == "BOTTOMLEFT")
        if mirror then
            grip:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
        else
            grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        end
        grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        local n, p, h = grip:GetNormalTexture(), grip:GetPushedTexture(), grip:GetHighlightTexture()
        if n then n:SetVertexColor(1, 1, 1, 0.9) end
        if mirror then
            if n then n:SetTexCoord(1, 0, 0, 1) end
            if p then p:SetTexCoord(1, 0, 0, 1) end
            if h then h:SetTexCoord(1, 0, 0, 1) end
        end
        grip:SetScript("OnMouseDown", function()
            -- anchor to TOPLEFT first so sizing behaves the same from either corner
            local l, t = frame:GetLeft(), frame:GetTop()
            if l and t then
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
            end
            frame:StartSizing(corner)
        end)
        grip:SetScript("OnMouseUp", function()
            frame:StopMovingOrSizing(); savePosition(); CL:Layout()
        end)
        return grip
    end
    makeGrip("BOTTOMRIGHT")
    makeGrip("BOTTOMLEFT")

    frame:SetScript("OnSizeChanged", function() CL:Layout() end)
    frame:SetScript("OnShow", function() CL:Layout() end)

    CL:Layout()
    frame:Hide()   -- always start hidden; open with /clog
end

----------------------------------------------------------------------
-- events
----------------------------------------------------------------------
local function registerEvents()
    local f = CreateFrame("Frame", "CombatLog112EventFrame")
    local acc, tick = 0, 0
    f:SetScript("OnUpdate", function()
        acc = acc + arg1
        if acc < 1 then return end
        acc = 0
        tick = tick + 1
        if tick >= 5 then tick = 0; CL.dirty = true end   -- pets change GUIDs
        if CL.dirty then CL.dirty = false; CL:RebuildScope() end
    end)

    f:SetScript("OnEvent", function()
        local e = event
        if e == "SPELL_DAMAGE_EVENT_SELF" or e == "SPELL_DAMAGE_EVENT_OTHER" then
            -- targetGuid, casterGuid, spellId, amount, mitigationStr, hitInfo, spellSchool, effectAuraStr
            local target, caster, id, amount, mitigation, hit, school, aura = arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8
            local side = classify(caster, target)
            if not side or not passDistance(side, caster, target) then return end
            local crit = hasBit(hit, 2) and " CRIT" or ""
            local dot = ""
            if aura then
                local _, _, at = string.find(aura, "(%d+),(%d+),(%d+),(%d+)")
                if at == "3" or at == "89" then dot = " (periodic)" end
            end
            local mit = ""
            if mitigation and mitigation ~= "" then
                local _, _, ab, bl, rs = string.find(mitigation, "(%-?%d+),(%-?%d+),(%-?%d+)")
                local parts = ""
                if ab and tonumber(ab) ~= 0 then parts = parts.." "..ab.." absorbed" end
                if bl and tonumber(bl) ~= 0 then parts = parts.." "..bl.." blocked" end
                if rs and tonumber(rs) ~= 0 then parts = parts.." "..rs.." resisted" end
                if parts ~= "" then mit = " ("..string.sub(parts, 2)..")" end
            end
            CL:AddLine(string.format("%s  %s -> %s: %s %s%s%s [%s]%s",
                side, nameOf(caster), nameOf(target), spellName(id),
                tostring(amount or "?"), crit, dot, schoolName(school), mit))

        elseif e == "AUTO_ATTACK_SELF" or e == "AUTO_ATTACK_OTHER" then
            -- attackerGuid, targetGuid, totalDamage, hitInfo, victimState, ...
            local a, b, d, h, vs = arg1, arg2, arg3, arg4, arg5
            local side = classify(a, b)
            if not side or not passDistance(side, a, b) then return end
            local dmg = tonumber(d) or 0
            local what
            if dmg == 0 then
                what = VSTATE[tonumber(vs) or -1] or (hasBit(h, 16) and "Miss") or "0"
                what = "melee "..string.upper(what)
            else
                what = "melee "..dmg..(hasBit(h, 128) and " CRIT" or "")
            end
            CL:AddLine(string.format("%s  %s -> %s: %s", side, nameOf(a), nameOf(b), what))

        elseif e == "SPELL_MISS_SELF" or e == "SPELL_MISS_OTHER" then
            -- targetGuid, casterGuid, spellId, missInfo
            local side = classify(arg2, arg1)
            if not side or not passDistance(side, arg2, arg1) then return end
            local why = MISS[tonumber(arg4) or -1] or tostring(arg4 or "?")
            CL:AddLine(string.format("%s  %s -> %s: %s %s",
                side, nameOf(arg2), nameOf(arg1), spellName(arg3), string.upper(why)))

        elseif e == "SPELL_HEAL_BY_SELF" or e == "SPELL_HEAL_BY_OTHER" or e == "SPELL_HEAL_ON_SELF" then
            -- targetGuid, casterGuid, spellId, amount, critical, periodic
            if not DB.heal then return end
            local target, caster, id, amount, crit, periodic = arg1, arg2, arg3, arg4, arg5, arg6
            -- one heal can arrive through two events (you heal yourself, or someone heals you): drop the copy
            local key = tostring(target)..tostring(caster)..tostring(id)..tostring(amount)
            local now = GetTime()
            if key == CL.lastHeal and now - (CL.lastHealT or 0) < 0.25 then return end
            CL.lastHeal = key; CL.lastHealT = now
            local side = classify(caster, target)
            if not side or not passDistance(side, caster, target) then return end
            CL:AddLine(string.format("%s  %s -> %s: %s +%s%s%s [Heal]",
                side, nameOf(caster), nameOf(target), spellName(id), tostring(amount or "?"),
                (tonumber(crit) == 1) and " CRIT" or "",
                (tonumber(periodic) == 1) and " (periodic)" or ""))

        elseif e == "PLAYER_TARGET_CHANGED" then
            learn("target")
        elseif e == "UPDATE_MOUSEOVER_UNIT" then
            learn("mouseover")
        else
            -- roster / pet / zone changes
            CL.dirty = true
        end
    end)
    f:RegisterEvent("SPELL_DAMAGE_EVENT_SELF")
    f:RegisterEvent("SPELL_DAMAGE_EVENT_OTHER")
    f:RegisterEvent("AUTO_ATTACK_SELF")
    f:RegisterEvent("AUTO_ATTACK_OTHER")
    f:RegisterEvent("SPELL_MISS_SELF")
    f:RegisterEvent("SPELL_MISS_OTHER")
    f:RegisterEvent("SPELL_HEAL_BY_SELF")
    f:RegisterEvent("SPELL_HEAL_BY_OTHER")
    f:RegisterEvent("SPELL_HEAL_ON_SELF")
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    f:RegisterEvent("PARTY_MEMBERS_CHANGED")
    f:RegisterEvent("RAID_ROSTER_UPDATE")
    f:RegisterEvent("UNIT_PET")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    CL.eventFrame = f
end

----------------------------------------------------------------------
-- slash command  (key "CLOG" needs SLASH_CLOG1, SLASH_CLOG2 ...)
----------------------------------------------------------------------
SLASH_CLOG1 = "/clog"
SLASH_CLOG2 = "/combatlog112"
SlashCmdList["CLOG"] = function(input)
    if not frame then return end
    input = string.lower(input or "")
    local _, _, cmd, arg = string.find(input, "^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd or ""; arg = arg or ""
    if cmd == "hide" or (cmd == "" and frame:IsShown()) then
        frame:Hide(); DB.shown = false
    elseif cmd == "show" or cmd == "" then
        frame:Show(); DB.shown = true; CL:Layout()
    elseif cmd == "clear" then
        CL:Clear()
    elseif cmd == "find" then
        if CL.box then CL.box:SetText(arg) end
    elseif cmd == "scope" then
        if arg == "me" or arg == "party" or arg == "raid" then DB.scope = arg; CL:FilterChanged()
        else msg("usage: /clog scope me|party|raid") end
    elseif cmd == "dir" then
        if arg == "in" or arg == "out" or arg == "both" then DB.dir = arg; CL:FilterChanged()
        else msg("usage: /clog dir in|out|both") end
    elseif cmd == "dist" then
        local n = tonumber(arg)
        if arg == "max" then DB.dist = 0; CL:FilterChanged()
        elseif n and n >= 5 and n <= 500 then DB.dist = math.floor(n); CL:FilterChanged()
        else msg("usage: /clog dist <5-500>|max") end
    elseif cmd == "heal" then
        if arg == "on" then DB.heal = true; msg("healing shown")
        elseif arg == "off" then DB.heal = false; msg("healing hidden")
        else msg("usage: /clog heal on|off") end
    elseif cmd == "font" then
        local n = tonumber(arg)
        if n and n >= 8 and n <= 24 then DB.fontSize = math.floor(n); CL:Layout()
        else msg("usage: /clog font 8-24") end
    elseif cmd == "lines" then
        local n = tonumber(arg)
        if n and n >= 20 and n <= 5000 then DB.maxLines = math.floor(n)
        else msg("usage: /clog lines 20-5000") end
    elseif cmd == "reset" then
        DB.x = nil; DB.y = nil; DB.w = DEFAULTS.w; DB.h = DEFAULTS.h
        frame:ClearAllPoints(); frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:SetWidth(DB.w); frame:SetHeight(DB.h)
        frame:Show(); DB.shown = true
    else
        msg("/clog [show|hide|clear|reset]   /clog find <words> (-word excludes, empty = off)")
        msg("/clog scope me|party|raid   /clog dir in|out|both   /clog dist <yards>|max")
        msg("/clog font <8-24>   /clog lines <20-5000>   /clog heal on|off")
        msg("Drag to move, drag the bottom-right corner to resize.")
    end
end

----------------------------------------------------------------------
-- init
----------------------------------------------------------------------
local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function()
    DB = CombatLog112DB
    for k, v in pairs(DEFAULTS) do
        if DB[k] == nil then DB[k] = v end
    end
    if DB.maxLines == 120 then DB.maxLines = DEFAULTS.maxLines end
    makeWindow()
    CL:RebuildScope()
    registerEvents()
    -- Nampower only sends these events when its CVars are on (default off)
    if GetNampowerVersion and GetCVar and SetCVar then
        local function enableCVar(name)
            local ok, v = pcall(GetCVar, name)
            if ok and tostring(v) ~= "1" then pcall(SetCVar, name, "1") end
            local ok2, v2 = pcall(GetCVar, name)
            return ok2 and tostring(v2) == "1"
        end
        enableCVar("NP_EnableAutoAttackEvents")
        if not enableCVar("NP_EnableSpellHealEvents") then
            CL:AddLine("Warning: could not enable NP_EnableSpellHealEvents, healing will not show (update Nampower?).")
        end
    end
    CL:AddLine("Ready. /clog help for commands. Filter: "..(SCOPE_LABEL[DB.scope] or "Me").." / "..(DIR_LABEL[DB.dir] or "Both").." / "..distLabel(DB.dist))
    if not GetNampowerVersion then
        CL:AddLine("Warning: Nampower not detected, no damage events will arrive.")
    end
    if not SUPERWOW_VERSION then
        CL:AddLine("Note: SuperWoW not detected, NPC names may show as Unit:XXXX.")
    end
end)
