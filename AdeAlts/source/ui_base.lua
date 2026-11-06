-- Ade Alts: ui_base
local AA = AdeAlts

----------------------------------------------------------------------
-- alts manager window (opened by the minimap button or /ade)
----------------------------------------------------------------------
local CLASSICON = {
  WARRIOR = { 0, .25, 0, .25 },  MAGE = { .25, .5, 0, .25 },    ROGUE = { .5, .75, 0, .25 },
  DRUID   = { .75, 1, 0, .25 },  HUNTER = { 0, .25, .25, .5 },  SHAMAN = { .25, .5, .25, .5 },
  PRIEST  = { .5, .75, .25, .5 }, WARLOCK = { .75, 1, .25, .5 }, PALADIN = { 0, .25, .5, .75 },
}
local QCOL = {
  [0] = { .62, .62, .62 }, [1] = { 1, 1, 1 }, [2] = { .12, 1, 0 },
  [3] = { 0, .44, .87 }, [4] = { .64, .21, .93 }, [5] = { 1, .5, 0 },
}
AA.CELL = 33
AA.COLS, AA.GROWS = 7, 8       -- recalculated by Layout()
AA.ROWH, AA.LROWS = 42, 7
AA.SROWH, AA.SROWS = 22, 13
AA.DEF_W, AA.DEF_H = 780, 490
AA.RROWH, AA.RROWS = 18, 12
AA.view, AA.profSel = "bags", nil

local function Commas(n)
  local str = tostring(n)
  while true do
    local k
    str, k = string.gsub(str, "^(-?%d+)(%d%d%d)", "%1,%2")
    if k == 0 then break end
  end
  return str
end

function AA.Money(c)
  c = c or 0
  local g = math.floor(c / 10000)
  local s = math.floor(math.mod(c, 10000) / 100)
  local cc = math.mod(c, 100)
  return "|cffffd700" .. Commas(g) .. "g|r |cffc7c7cf" .. s .. "s|r |cffeda55f" .. cc .. "c|r"
end

function AA.Ago(ts)
  if not ts or ts == 0 then return "never" end
  local d = time() - ts
  if d < 90 then return "just now" end
  return AA.FormatTime(d) .. " ago"
end

function AA.ClassName(token)
  if not token or token == "" then return "" end
  return string.upper(string.sub(token, 1, 1)) .. string.lower(string.sub(token, 2))
end

function AA.ItemName(id)
  local it = AA.db and AA.db.items and AA.db.items[id]
  return (it and it.n) or ("item:" .. id)
end

function AA.ItemTex(id)
  local it = AA.db and AA.db.items and AA.db.items[id]
  if it and it.t and it.t ~= "" then return "Interface\\Icons\\" .. it.t end
  return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function AA.ItemColor(id)
  local it = AA.db and AA.db.items and AA.db.items[id]
  local c = QCOL[(it and it.q) or 1] or QCOL[1]
  return c[1], c[2], c[3]
end

function AA.SortedAlts()
  local list = {}
  for k in pairs(AA.db.chars) do table.insert(list, k) end
  local mode = AA.db.sort or "level"
  table.sort(list, function(a, b)
    local ca, cb = AA.db.chars[a], AA.db.chars[b]
    if mode == "level" then
      local la, lb = ca.level or 0, cb.level or 0
      if la ~= lb then return la > lb end
    end
    if ca.name ~= cb.name then return ca.name < cb.name end
    return a < b
  end)
  return list
end

function AA.SetClassTex(tex, class)
  local co = class and CLASSICON[class]
  if co then
    tex:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
    tex:SetTexCoord(co[1], co[2], co[3], co[4])
  else
    tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    tex:SetTexCoord(0, 1, 0, 1)
  end
end

-- main frame ----------------------------------------------------------
AA.M = CreateFrame("Frame", "AdeAltsManager", UIParent)
AA.M:SetWidth(AA.DEF_W)
AA.M:SetHeight(AA.DEF_H)
AA.M:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
AA.M:SetFrameStrata("HIGH")
AA.M:SetMovable(true)
AA.M:EnableMouse(true)
AA.M:RegisterForDrag("LeftButton")
AA.M:SetScript("OnDragStart", function() this:StartMoving() end)
AA.M:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
AA.M:Hide()
AA.SkinFrame(AA.M, 0.95, false, true)
table.insert(UISpecialFrames, "AdeAltsManager")

local mtitle = AA.M:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
mtitle:SetPoint("TOPLEFT", AA.M, "TOPLEFT", 16, -12)
mtitle:SetText("Ade Alts |cff808080v" .. AA.VERSION .. "|r")

local mclose = CreateFrame("Button", nil, AA.M, "UIPanelCloseButton")
mclose:SetPoint("TOPRIGHT", AA.M, "TOPRIGHT", -4, -4)

AA.cdbtn = CreateFrame("Button", nil, AA.M, "UIPanelButtonTemplate")
AA.cdbtn:SetWidth(90)
AA.cdbtn:SetHeight(20)
AA.cdbtn:SetPoint("TOPRIGHT", AA.M, "TOPRIGHT", -40, -10)
AA.cdbtn:SetText("Cooldowns")
AA.cdbtn:SetScript("OnClick", function() AA.ToggleWindow() end)

-- search --------------------------------------------------------------
local slabel = AA.M:CreateFontString(nil, "OVERLAY", "GameFontNormal")
slabel:SetPoint("TOPLEFT", AA.M, "TOPLEFT", 16, -40)
slabel:SetText("Search items:")

AA.sbox = CreateFrame("EditBox", "AdeAltsSearch", AA.M)
AA.sbox:SetWidth(280)
AA.sbox:SetHeight(22)
AA.sbox:SetPoint("LEFT", slabel, "RIGHT", 10, 0)
AA.sbox:SetFontObject(ChatFontNormal)
AA.sbox:SetAutoFocus(false)
AA.sbox:SetMaxLetters(40)
AA.sbox:SetTextInsets(6, 6, 2, 2)
AA.sbox:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 8, edgeSize = 8,
  insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
AA.sbox:SetBackdropColor(0.1, 0.1, 0.1, 1)

local shint = AA.M:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
shint:SetPoint("LEFT", AA.sbox, "RIGHT", 10, 0)
shint:SetText("name of an item in bags or bank of any alt")

-- alt list ------------------------------------------------------------
AA.L = CreateFrame("Frame", nil, AA.M)
AA.L:SetWidth(190)
AA.L:SetHeight(350)
AA.L:SetPoint("TOPLEFT", AA.M, "TOPLEFT", 12, -66)
AA.SkinFrame(AA.L, 0.6)

AA.altRows = {}
local lsf = CreateFrame("ScrollFrame", "AdeAltsListScroll", AA.L, "FauxScrollFrameTemplate")
lsf:SetPoint("TOPLEFT", AA.L, "TOPLEFT", 0, -32)
lsf:SetPoint("BOTTOMRIGHT", AA.L, "BOTTOMRIGHT", -26, 4)
lsf:SetScript("OnVerticalScroll", function() FauxScrollFrame_OnVerticalScroll(AA.ROWH, AA.UpdateAltList) end)
AA.L:EnableMouseWheel(true)
AA.L:SetScript("OnMouseWheel", function() AA.ScrollWheel(lsf, AA.ROWH) end)

local sortBtns = {}
local sortLabel = AA.L:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sortLabel:SetPoint("TOPLEFT", AA.L, "TOPLEFT", 10, -12)
sortLabel:SetText("Sort by:")
local function MakeSort(mode, label, x)
  local b = CreateFrame("Button", "AdeAltsSort" .. mode, AA.L, "UIPanelButtonTemplate")
  b:SetWidth(52)
  b:SetHeight(18)
  b:SetPoint("TOPLEFT", AA.L, "TOPLEFT", x, -8)
  b:SetText(label)
  b.mode = mode
  b:SetScript("OnClick", function()
    AA.db.sort = this.mode
    AA.ResetScroll(lsf)
    AA.RefreshManager()
  end)
  sortBtns[mode] = b
end
MakeSort("level", "Level", 64)
MakeSort("name", "Name", 120)

function AA.MakeAltRow()
  local r = CreateFrame("Button", nil, AA.L)
  r:SetWidth(158)
  r:SetHeight(AA.ROWH - 2)
  r.sel = r:CreateTexture(nil, "BACKGROUND")
  r.sel:SetAllPoints(r)
  r.sel:SetTexture(0.2, 0.5, 0.9, 0.35)
  r.sel:Hide()
  r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetWidth(32)
  r.icon:SetHeight(32)
  r.icon:SetPoint("LEFT", r, "LEFT", 4, 0)
  r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, -2)
  r.name:SetWidth(112)
  r.name:SetJustifyH("LEFT")
  r.info = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.info:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
  r.info:SetWidth(112)
  r.info:SetJustifyH("LEFT")
  r:EnableMouseWheel(true)
  r:SetScript("OnMouseWheel", function() AA.ScrollWheel(lsf, AA.ROWH) end)
  r:SetScript("OnClick", function()
    AA.selKey = this.key
    if AA.sbox:GetText() ~= "" then AA.sbox:SetText("") end
    AA.RefreshManager()
  end)
  r:Hide()
  table.insert(AA.altRows, r)
end

AA.UpdateAltList = function()
  if not AA.db then return end
  local keys = AA.SortedAlts()
  for mode, b in pairs(sortBtns) do
    if (AA.db.sort or "level") == mode then b:Disable() else b:Enable() end
  end
  FauxScrollFrame_Update(lsf, table.getn(keys), AA.LROWS, AA.ROWH)
  local off = FauxScrollFrame_GetOffset(lsf)
  for i = 1, AA.LROWS do
    local r = AA.altRows[i]
    local k = keys[off + i]
    if k then
      local c = AA.db.chars[k]
      r.key = k
      AA.SetClassTex(r.icon, c.class)
      r.name:SetText("|cff" .. AA.ClassHex(c.class) .. c.name .. "|r")
      local lv = "?"
      if c.level and c.level > 0 then lv = c.level end
      r.info:SetText("Lv " .. lv .. " " .. AA.ClassName(c.class))
      if k == AA.selKey then r.sel:Show() else r.sel:Hide() end
      r:Show()
    else
      r:Hide()
    end
  end
end

