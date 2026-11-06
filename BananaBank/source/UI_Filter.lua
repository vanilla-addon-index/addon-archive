-- BananaBank UI Teil 7: Bestand im Auktionshaus-Stil (Kategorienbaum, Ergebnisse nach Kategorien, Symbol- und Listenansicht)

local BB = BananaBank
local UI = BB.UI
local C = UI.C
local T = function(k) return BB.T(k) end
local getn = table.getn
local WHITE = UI.WHITE

UI.filterModule = true

-- ------------------------------------------------------------
-- Bestand im Auktionshaus-Stil: Kategorienbaum links, Ergebnisse nach Kategorien, Symbol- oder Listenansicht
-- ------------------------------------------------------------
local FONT = UI.FONT
local ICON, GAPX = 24, 3
local PER_ROW = 11
local V_ROW_H = 26
local V_ROWS = 12
local TREE_H = 18
local TREE_ROWS = 17

local PROF_OF = { herb = "alch", ore = "bs", leather = "lw", cloth = "tail" }

-- Gruppe eines Eintrags: Berufe (Material oder Rezept), BOE nach Slot, Traenke, Taschen, Sonstiges
local function groupKey(entry)
  local k = entry.k or "other"
  if PROF_OF[k] then return "prof:" .. PROF_OF[k] .. ":mat" end
  if k == "trade" then return "prof:" .. (entry.s or "other") .. ":mat" end
  if k == "recipe" then return "prof:" .. (entry.s or "other") .. ":rec" end
  if k == "boe" then return "boe:" .. (entry.s or "other") end
  return k
end

local GROUP_ORDER, GROUP_INDEX
local function groupOrder()
  if GROUP_ORDER then return GROUP_ORDER end
  GROUP_ORDER = {}
  for i = 1, getn(BB.PROFS) do
    table.insert(GROUP_ORDER, "prof:" .. BB.PROFS[i] .. ":mat")
    table.insert(GROUP_ORDER, "prof:" .. BB.PROFS[i] .. ":rec")
  end
  for i = 1, getn(BB.BOE_SUBS) do table.insert(GROUP_ORDER, "boe:" .. BB.BOE_SUBS[i]) end
  table.insert(GROUP_ORDER, "boe:other")
  table.insert(GROUP_ORDER, "potion")
  table.insert(GROUP_ORDER, "bag")
  table.insert(GROUP_ORDER, "other")
  GROUP_INDEX = {}
  for i = 1, getn(GROUP_ORDER) do GROUP_INDEX[GROUP_ORDER[i]] = i end
  return GROUP_ORDER
end

local function groupLabel(key)
  local _, _, prof, kind = string.find(key, "^prof:(%a+):(%a+)$")
  if prof then
    return T("SUB_" .. string.upper(prof)) .. "  -  " .. T(kind == "mat" and "TF_MAT_ALL" or "TF_REC_ALL")
  end
  local _, _, sub = string.find(key, "^boe:(%a+)$")
  if sub then return T("TF_BOE_ALL") .. "  -  " .. T("SUB_" .. string.upper(sub)) end
  return BB:CatName(key)
end

-- Baum: ein Knoten ist sichtbar, wenn sein Elternknoten sichtbar und aufgeklappt ist
local function parentKey(key)
  local _, _, p = string.find(key, "^(.*):[^:]+$")
  return p
end

local function treeNodes(cur)
  cur = cur or "all"
  local out, shown = {}, {}
  local list = BB.TYPE_FILTERS
  for i = 1, getn(list) do
    local e = list[i]
    local pk = parentKey(e.key)
    local visible = (pk == nil)
    if pk and shown[pk] then
      visible = (cur == pk) or (string.sub(cur, 1, string.len(pk) + 1) == pk .. ":")
    end
    if visible then
      shown[e.key] = true
      local hasKids = false
      local nxt = list[i + 1]
      if nxt and string.sub(nxt.key, 1, string.len(e.key) + 1) == e.key .. ":" then hasKids = true end
      table.insert(out, { key = e.key, label = e.label, depth = e.depth, parent = hasKids, header = e.header })
      -- die frei benennbaren Lagertypen stehen direkt unter der Ueberschrift "Nur ansehen"
      if e.key == "hdrview" then
        local types = BB:DepotTypes()
        for j = 1, getn(types) do
          table.insert(out, { key = "depot:" .. types[j].id, label = types[j].name, literal = true, depth = 0 })
        end
      end
    end
  end
  return out
end

local function smallSlot(parent)
  local s = UI:Slot(parent, ICON)
  s.count:SetFont(FONT, 9, "OUTLINE")
  s.coin = s:CreateTexture(nil, "OVERLAY")
  s.coin:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
  s.coin:SetWidth(11)
  s.coin:SetHeight(11)
  s.coin:SetPoint("TOPLEFT", s, "TOPLEFT", 0, 0)
  s.coin:Hide()
  s.badge:SetFont(FONT, 8, "OUTLINE")
  s.res:SetFont(FONT, 8, "OUTLINE")
  s.glow:SetWidth(32)
  s.glow:SetHeight(32)
  -- Mittelklick (Trash) braucht AnyUp; faellt das aus, bleiben Links- und Rechtsklick
  if not pcall(function() s:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp") end) then s:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
  s:SetScript("OnClick", function() UI:OnSlotClick(this, arg1) end)
  s:SetScript("OnEnter", function() UI:OnSlotEnter(this) end)
  s:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return s
end

function UI:BuildStockView(p)
  local S = self.stock
  S.treeOffset = 0

  -- nur die Listenansicht (Symbole entfernt)
  S.viewChips = {}
  S.view = "list"

  -- Kategorienbaum
  local tree = self:Panel(p, 124, 0)
  tree:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -30)
  tree:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 26)
  tree:EnableMouseWheel(true)
  tree:SetScript("OnMouseWheel", function()
    S.treeOffset = S.treeOffset - arg1 * 3
    UI:RefreshTree()
  end)
  S.tree = tree
  S.treeRows = {}
  for i = 1, TREE_ROWS do
    local b = CreateFrame("Button", nil, tree)
    b:SetHeight(TREE_H - 1)
    b:SetPoint("TOPLEFT", tree, "TOPLEFT", 4, -5 - (i - 1) * TREE_H)
    b:SetPoint("TOPRIGHT", tree, "TOPRIGHT", -4, -5 - (i - 1) * TREE_H)
    b:EnableMouseWheel(true)
    b:SetScript("OnMouseWheel", function()
      S.treeOffset = S.treeOffset - arg1 * 3
      UI:RefreshTree()
    end)
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetTexture(WHITE)
    b.sel:SetAllPoints(b)
    b.sel:SetVertexColor(1, 0.82, 0.26, 0.28)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(WHITE)
    hl:SetAllPoints(b)
    hl:SetVertexColor(1, 0.82, 0.3, 0.14)
    b.fs = self:Font(b, 11, { 0.88, 0.90, 0.96 })
    b.fs:SetHeight(14)
    b:SetScript("OnClick", function()
      if not this.node or this.node.header then return end
      PlaySound("igMainMenuOptionCheckBoxOn")
      if S.type == this.node.key and this.node.parent then S.type = "all" else S.type = this.node.key end
      -- Lager zeigen immer ihren eigenen Bestand, nicht eine einzelne Bank
      if string.sub(S.type, 1, 6) == "depot:" then S.bank = nil end
      UI:RefreshStock()
    end)
    S.treeRows[i] = b
  end

  -- Ergebnisfeld
  local res = self:Panel(p, 0, 0)
  res:SetPoint("TOPLEFT", p, "TOPLEFT", 130, -30)
  res:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -238, 26)
  S.resPanel = res
  local sf = CreateFrame("ScrollFrame", "BananaBankStockScroll", res, "FauxScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", res, "TOPLEFT", 0, -3)
  sf:SetPoint("BOTTOMRIGHT", res, "BOTTOMRIGHT", -26, 3)
  sf:SetScript("OnVerticalScroll", function() FauxScrollFrame_OnVerticalScroll(V_ROW_H, function() UI:RefreshStockView() end) end)
  sf.offset = 0
  S.sf = sf
  local function wheel()
    local sb = getglobal("BananaBankStockScrollScrollBar")
    if sb then sb:SetValue(sb:GetValue() - arg1 * V_ROW_H * 2) end
  end
  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", wheel)
  res:EnableMouseWheel(true)
  res:SetScript("OnMouseWheel", wheel)

  S.vrows = {}
  for i = 1, V_ROWS do
    local r = CreateFrame("Frame", nil, res)
    r:SetHeight(V_ROW_H)
    r:SetPoint("TOPLEFT", res, "TOPLEFT", 6, -4 - (i - 1) * V_ROW_H)
    r:SetPoint("TOPRIGHT", res, "TOPRIGHT", -28, -4 - (i - 1) * V_ROW_H)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", wheel)
    r.hfs = self:Font(r, 12, C.gold)
    r.hfs:SetPoint("LEFT", r, "LEFT", 2, -2)
    r.hfs:SetWidth(330)
    r.hfs:SetHeight(14)
    r.hline = r:CreateTexture(nil, "ARTWORK")
    r.hline:SetTexture(WHITE)
    r.hline:SetHeight(1)
    r.hline:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 2)
    r.hline:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 2)
    r.hline:SetVertexColor(C.brass[1], C.brass[2], C.brass[3], 0.6)
    r.slots = {}
    for j = 1, PER_ROW do
      local s = smallSlot(r)
      s:SetPoint("LEFT", r, "LEFT", (j - 1) * (ICON + GAPX), 0)
      r.slots[j] = s
    end
    -- Listenzeile: Klickflaeche ueber die ganze Zeile
    r.lbtn = CreateFrame("Button", nil, r)
    r.lbtn:SetAllPoints(r)
    if not pcall(function() r.lbtn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp") end) then r.lbtn:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    r.lbtn:SetScript("OnClick", function() UI:OnSlotClick(this, arg1) end)
    r.lbtn:SetScript("OnEnter", function() UI:OnSlotEnter(this) end)
    r.lbtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.lbtn:EnableMouseWheel(true)
    r.lbtn:SetScript("OnMouseWheel", wheel)
    r.ltint = r:CreateTexture(nil, "BACKGROUND")
    r.ltint:SetTexture(WHITE)
    r.ltint:SetAllPoints(r)
    r.ltint:SetVertexColor(1, 0.3, 0.2, 0.12)
    r.ltint:Hide()
    local lhl = r.lbtn:CreateTexture(nil, "HIGHLIGHT")
    lhl:SetTexture(WHITE)
    lhl:SetAllPoints(r.lbtn)
    lhl:SetVertexColor(1, 0.82, 0.3, 0.12)
    r.lname = self:Font(r, 11, C.text)
    r.lname:SetPoint("LEFT", r, "LEFT", ICON + 8, 0)
    r.lname:SetWidth(168)
    r.lname:SetHeight(13)
    r.lcnt = self:Font(r, 11, C.gold)
    r.lcnt:SetPoint("LEFT", r, "LEFT", ICON + 182, 0)
    r.lcnt:SetWidth(58)
    r.lcnt:SetJustifyH("RIGHT")
    r.lprice = self:Font(r, 10, C.muted)
    r.lprice:SetPoint("LEFT", r, "LEFT", ICON + 244, 0)
    r.lprice:SetWidth(76)
    r.lprice:SetJustifyH("RIGHT")
    S.vrows[i] = r
  end
  S.empty = self:Font(res, 13, C.muted)
  S.empty:SetPoint("CENTER", res, "CENTER", -10, 0)
  S.empty:SetJustifyH("CENTER")
  S.empty:SetWidth(320)
end

function UI:RefreshTree()
  local S = self.stock
  if not S or not S.treeRows then return end
  local nodes = treeNodes(S.type)
  local max = getn(nodes) - TREE_ROWS
  if max < 0 then max = 0 end
  if S.treeOffset > max then S.treeOffset = max end
  if S.treeOffset < 0 then S.treeOffset = 0 end
  for i = 1, TREE_ROWS do
    local b = S.treeRows[i]
    local n = nodes[S.treeOffset + i]
    b.node = n
    if not n then
      b:Hide()
    else
      b:Show()
      local on = (S.type == n.key) and not n.header
      b.fs:ClearAllPoints()
      b.fs:SetPoint("LEFT", b, "LEFT", 4 + n.depth * 10, 0)
      b.fs:SetWidth(108 - n.depth * 10)
      local label = n.literal and n.label or T(n.label)
      if n.parent then
        local open = (S.type == n.key) or (string.sub(S.type or "", 1, string.len(n.key) + 1) == n.key .. ":")
        label = (open and "- " or "+ ") .. label
      end
      b.fs:SetText(label)
      if n.header then
        b.fs:SetTextColor(0.55, 0.70, 1)
        b.sel:Hide()
      elseif on then
        b.fs:SetTextColor(1, 0.95, 0.7)
        b.sel:Show()
      else
        b.fs:SetTextColor(0.88, 0.90, 0.96)
        b.sel:Hide()
      end
    end
  end
end

local function fillSlot(s, entry, basket)
  s.id = entry.id
  s.icon:SetTexture(BB.FullTex(entry.e.t))
  s:SetQuality(entry.e.q)
  if BB:ItemBlockText(BB:Me(), entry.id) then
    s.icon:SetVertexColor(0.65, 0.3, 0.3)   -- laut Regelsatz nicht anfragbar
  elseif entry.avail > 0 then s.icon:SetVertexColor(1, 1, 1) else s.icon:SetVertexColor(0.35, 0.35, 0.35) end
  s.count:SetText(entry.avail > 1 and entry.avail or (entry.avail == 1 and "" or "0"))
  if entry.res > 0 then s.res:SetText(entry.res) else s.res:SetText("") end
  if s.coin then
    if BB:IsTrash(entry.id) then s.coin:Show() else s.coin:Hide() end
  end
  if basket[entry.id] then s.badge:SetText("x" .. basket[entry.id]) else s.badge:SetText("") end
  s:Show()
end

-- Zeilen der Ergebnisliste: Ueberschriften, Symbolzeilen oder Listenzeilen
local function buildRows(list, view)
  groupOrder()
  local groups, keys = {}, {}
  for i = 1, getn(list) do
    local key = groupKey(list[i])
    if not GROUP_INDEX[key] then key = "other" end
    if not groups[key] then groups[key] = {} table.insert(keys, key) end
    table.insert(groups[key], list[i])
  end
  table.sort(keys, function(a, b) return GROUP_INDEX[a] < GROUP_INDEX[b] end)
  local rows = {}
  for i = 1, getn(keys) do
    local g = groups[keys[i]]
    table.sort(g, function(a, b)
      if (a.e.q or 1) ~= (b.e.q or 1) then return (a.e.q or 1) > (b.e.q or 1) end
      return (a.e.n or "") < (b.e.n or "")
    end)
    table.insert(rows, { head = groupLabel(keys[i]) .. "  |cff9a9cb3(" .. getn(g) .. ")|r" })
    if view == "list" then
      for j = 1, getn(g) do table.insert(rows, { item = g[j] }) end
    else
      local j = 1
      while j <= getn(g) do
        local line = {}
        for k = j, math.min(j + PER_ROW - 1, getn(g)) do table.insert(line, g[k]) end
        table.insert(rows, { items = line })
        j = j + PER_ROW
      end
    end
  end
  return rows
end

function UI:RefreshStockView(list)
  local S = self.stock
  if not S or not S.vrows then return end
  if list then S.lastList = list else list = S.lastList or {} end
  -- Ansichtswahl: rechtsbuendig in der oberen Zeile (Position im Build)
  for i = 1, getn(S.viewChips) do
    S.viewChips[i]:SetActive(S.viewChips[i].key == S.view)
  end
  if S.type ~= "all" and not BB:FindTypeFilter(S.type) then
    local depotId = string.sub(S.type, 1, 6) == "depot:" and string.sub(S.type, 7)
    if not (depotId and BB:DepotTypeById(depotId)) then S.type = "all" end
  end
  self:RefreshTree()
  -- bei geaenderten Suchkriterien wieder nach oben
  local sig = table.concat({ tostring(S.bank), tostring(S.type), S.filter, S.search, tostring(S.onlyAvail), tostring(S.onlyTrash), S.view }, "|")
  if S.sig ~= sig then
    S.sig = sig
    local sb = getglobal("BananaBankStockScrollScrollBar")
    if sb then sb:SetValue(0) end
    S.sf.offset = 0
  end
  local rows = buildRows(list, S.view)
  local offset = 0
  S.busy = true
  if FauxScrollFrame_Update then FauxScrollFrame_Update(S.sf, getn(rows), V_ROWS, V_ROW_H) end
  offset = (FauxScrollFrame_GetOffset and FauxScrollFrame_GetOffset(S.sf)) or S.sf.offset or 0
  S.busy = false
  local basket = BananaBankDB.basket
  for i = 1, V_ROWS do
    local r = S.vrows[i]
    local d = rows[offset + i]
    r.hfs:Hide()
    r.hline:Hide()
    r.ltint:Hide()
    r.lbtn:Hide()
    r.lname:SetText("")
    r.lcnt:SetText("")
    r.lprice:SetText("")
    for j = 1, PER_ROW do r.slots[j].id = nil r.slots[j]:Hide() end
    r.lbtn.id = nil
    if d then
      r:Show()
      if d.head then
        r.hfs:SetText(d.head)
        r.hfs:Show()
        r.hline:Show()
      elseif d.items then
        for j = 1, getn(d.items) do fillSlot(r.slots[j], d.items[j], basket) end
      else
        local e = d.item
        fillSlot(r.slots[1], e, basket)
        r.lbtn.id = e.id
        r.lbtn:Show()
        local qc = BB.QUALITY_COLOR[e.e.q or 1] or BB.QUALITY_COLOR[1]
        local nm = e.e.n or "?"
        if BB:IsTrash(e.id) then
          nm = "|cffff6a55" .. T("TRASH_TAG") .. "|r " .. nm
          r.ltint:Show()
        end
        r.lname:SetText(nm)
        r.lname:SetTextColor(qc[1], qc[2], qc[3])
        local txt = tostring(e.avail)
        if e.res > 0 then
          -- mehr reserviert als im Bestand: rot
          txt = txt .. (e.res > (e.e.c or 0) and " |cffff4040(" or " |cffff8000(") .. e.res .. ")|r"
        end
        r.lcnt:SetText(txt)
        local u = BB:GetPrice(e.id)
        if u then r.lprice:SetText(BB.Money(u)) end
      end
    else
      r:Hide()
    end
  end
end
