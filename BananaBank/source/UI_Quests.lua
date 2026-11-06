-- BananaBank UI Teil 4: Gildenquests (Reiter, Editor, Tracker, Meldung)

local BB = BananaBank
local UI = BB.UI
local C = UI.C
local T = function(k) return BB.T(k) end
local getn = table.getn
local floor = math.floor
local WHITE, FONT, FONT_TITLE = UI.WHITE, UI.FONT, UI.FONT_TITLE

UI.questModule = true
UI.q = { view = "quests", filter = "active", page = 1, sel = nil, period = "all" }

local LIST_ROWS = 6
local ROW_H = 44
local ITEM_ROWS = 5   -- sichtbare Zeilen; mehr Eintraege (Items + Gold-Ziele, bis 6) scrollen
local HELPER_ROWS = 5
local RANK_ROWS = 9

-- Farbwelt: Gold fuer den Sieg, Silber und Bronze dahinter, Zustaende klar getrennt
local MEDAL = { { 1.00, 0.82, 0.26 }, { 0.80, 0.83, 0.92 }, { 0.86, 0.52, 0.22 } }
local STATE_COLOR = {
  open = { 1.00, 0.70, 0.18 },
  complete = { 0.35, 0.88, 0.42 },
  expired = { 0.78, 0.40, 0.36 },
  closed = { 0.42, 0.64, 0.98 },
  cancelled = { 0.52, 0.52, 0.58 },
}
local STATE_WEIGHT = { open = 1, complete = 2, expired = 3, closed = 4, cancelled = 5 }

local function hex(c)
  return string.format("%02x%02x%02x", floor(c[1] * 255), floor(c[2] * 255), floor(c[3] * 255))
end

-- Fortschrittsfarbe: warm bei wenig, gold in der Mitte, gruen bei fertig
local function progColor(p, state)
  if state == "cancelled" or state == "expired" then return { 0.50, 0.50, 0.56 } end
  if state == "closed" then return { 0.38, 0.60, 0.95 } end
  if p >= 1 then return { 0.30, 0.86, 0.38 } end
  if p < 0.34 then return { 1.00, 0.56, 0.16 } end
  if p < 0.67 then return { 1.00, 0.82, 0.26 } end
  return { 0.74, 0.90, 0.30 }
end

local function timeLeft(due)
  local s = due - time()
  if s <= 0 then return nil end
  local d = floor(s / 86400)
  local h = floor(mod(s, 86400) / 3600)
  if d > 0 then return d .. "d " .. h .. "h" end
  return h .. "h " .. floor(mod(s, 3600) / 60) .. "m"
end

-- ------------------------------------------------------------
-- Baustein: Fortschrittsbalken
-- ------------------------------------------------------------
local BAR_BACKDROP = {
  bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 8,
  insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

function UI:QBar(parent, w, h, left)
  local b = CreateFrame("Frame", nil, parent)
  b:SetWidth(w)
  b:SetHeight(h)
  b:SetBackdrop(BAR_BACKDROP)
  b:SetBackdropColor(0.012, 0.02, 0.05, 1)
  b:SetBackdropBorderColor(C.brass[1], C.brass[2], C.brass[3], 0.95)
  local fill = b:CreateTexture(nil, "ARTWORK")
  fill:SetTexture(WHITE)
  fill:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
  fill:SetHeight(h - 4)
  b.fill = fill
  local shine = b:CreateTexture(nil, "OVERLAY")
  shine:SetTexture(WHITE)
  shine:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
  shine:SetPoint("BOTTOMRIGHT", b, "RIGHT", -2, 0)
  shine:SetGradientAlpha("VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.20)
  b.fs = self:Font(b, h >= 14 and 10 or 9, { 1, 1, 1 }, FONT, "OUTLINE")
  if left then
    b.fs:SetPoint("LEFT", b, "LEFT", 7, 0)
    b.fs:SetWidth(w - 12)
    b.fs:SetJustifyH("LEFT")
  else
    b.fs:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.fs:SetJustifyH("CENTER")
  end
  b.inner = w - 4
  -- p = 0..1, col = Farbe, label = Text im Balken
  b.SetValue = function(self2, p, col, label)
    if p > 1 then p = 1 end
    if p < 0 then p = 0 end
    if p <= 0 then
      fill:Hide()
    else
      fill:Show()
      fill:SetWidth(math.max(1, floor(b.inner * p)))
      fill:SetGradientAlpha("VERTICAL", col[1] * 0.50, col[2] * 0.50, col[3] * 0.50, 1, col[1], col[2], col[3], 1)
    end
    b.fs:SetText(label or "")
  end
  b.Set = function(self2, cur, tot, state)
    local p = 0
    if tot > 0 then p = cur / tot end
    b:SetValue(p, progColor(p, state), cur .. " / " .. tot)
  end
  return b
end

-- Kopfzeile eines Panels im Stil des Spendenbuchs
local function panelHead(self, pnl, key, size)
  local t = self:Font(pnl, size or 14, C.gold, FONT_TITLE)
  t:SetPoint("TOPLEFT", pnl, "TOPLEFT", 12, -9)
  self:Loc(t, key)
  self:HLine(pnl, -29, 10, -10, C.brass, 0.9)
  return t
end

local COIN_TEX = "Interface\\Icons\\INV_Misc_Coin_01"

local function goldTooltip(owner, bank)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine(string.format(T("QD_GOLD_NAME"), bank), C.gold[1], C.gold[2], C.gold[3])
  GameTooltip:AddLine(string.format(T("QD_GOLD_TIP"), bank), 0.8, 0.8, 0.8, 1)
  GameTooltip:Show()
end

local function sortedGoldBanks(q)
  local names = {}
  for bank in pairs(q.gold or {}) do table.insert(names, bank) end
  table.sort(names)
  return names
end

local function itemTooltip(owner, q, id)
  if GetItemInfo(id) then
    UI:ItemTooltip(owner, id)
  else
    local n, qual = BB:QuestItemInfo(q, id)
    local col = BB.QUALITY_COLOR[qual or 1] or BB.QUALITY_COLOR[1]
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(n, col[1], col[2], col[3])
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(T("QX_ITEM_HINT"), 0.5, 0.7, 1)
  GameTooltip:AddLine(T("QX_ITEM_HINT2"), 0.5, 0.7, 1)
  GameTooltip:Show()
end

local function sortedItemIds(q)
  local ids = {}
  for id in pairs(q.items) do table.insert(ids, id) end
  table.sort(ids)
  return ids
end

-- Icon einer Quest: das gewaehlte, sonst das Icon des ersten Items
function UI:QuestIconTex(q)
  if q.ic and q.ic ~= "" then return BB.FullTex(q.ic) end
  local ids = sortedItemIds(q)
  if ids[1] then
    local _, _, tex = BB:QuestItemInfo(q, ids[1])
    return BB.FullTex(tex)
  end
  return BB.FullTex("")
end

-- Tooltip der Quest: eigener Text, darunter Bedarf und Fortschritt
function UI:QuestTooltip(owner, q)
  if not q then return end
  local s = BB:QuestStats()[q.id]
  local done, need = s and s.done or 0, s and s.need or BB:QuestNeed(q)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine(q.title, C.gold[1], C.gold[2], C.gold[3])
  if q.tip and q.tip ~= "" then GameTooltip:AddLine(q.tip, 1, 1, 1, 1) end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(string.format(T("QX_TT_NEED"), BB.Count(q.items) + BB.Count(q.gold or {})), 0.62, 0.64, 0.74)
  local pc = (need > 0 and done >= need) and STATE_COLOR.complete or STATE_COLOR.open
  GameTooltip:AddLine(string.format(T("QX_TT_PROGRESS"), done, need), pc[1], pc[2], pc[3])
  GameTooltip:AddLine(T("QX_TT_HINT"), 0.5, 0.7, 1)
  GameTooltip:Show()
end

-- Text in die Chat-Eingabezeile legen (oeffnet sie, falls noetig)
function UI:ChatInsert(text)
  local eb = ChatFrameEditBox
  if eb and eb:IsVisible() then
    eb:Insert(text)
    return true
  end
  if ChatFrame_OpenChat then
    ChatFrame_OpenChat(text)
    return true
  end
  return false
end

-- Klick auf ein Quest-Item: Shift = in den Chat bzw. den offenen Editor, Strg = in eine neue Quest
function UI:ItemClick(q, id, button)
  if button ~= "LeftButton" or not id then return end
  local name, quality, tex = BB:QuestItemInfo(q, id)
  if IsShiftKeyDown() then
    if self.qe and self.qe:IsVisible() then
      self:QuestAddItem(id, { n = name, q = quality, t = tex })
    else
      self:ChatInsert(BB:ItemLinkText(id, name, quality))
    end
  elseif IsControlKeyDown() then
    if not BB:CanManageQuests() then
      BB:Print("|cffff4040" .. T("ERR_QUEST_NOPERM") .. "|r")
      return
    end
    if not (self.qe and self.qe:IsVisible()) then self:OpenQuestEditor(nil) end
    self:QuestAddItem(id, { n = name, q = quality, t = tex })
  end
end

-- ------------------------------------------------------------
-- Reiter Gildenquests
-- ------------------------------------------------------------
function UI:BuildQuests(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetAllPoints(parent)
  p:Hide()
  self.pages.quests = p
  local Q = self.q
  Q.page_frame = p

  -- obere Leiste: Ansichten links, Neue Quest rechts
  Q.chipQuests = self:Chip(p, 84, "QV_QUESTS", function() Q.view = "quests" UI:RefreshQuests() end)
  Q.chipQuests:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -2)
  Q.chipRank = self:Chip(p, 84, "QV_RANKING", function() Q.view = "rank" UI:RefreshQuests() end)
  Q.chipRank:SetPoint("LEFT", Q.chipQuests, "RIGHT", 4, 0)
  Q.newBtn = self:Button(p, 130, 22, "QBTN_NEW", function() UI:OpenQuestEditor(nil) end, "primary")
  Q.newBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
  Q.summary = self:Font(p, 11, C.muted)
  Q.summary:SetJustifyH("RIGHT")

  -- ===== Ansicht Quests =====
  local v1 = CreateFrame("Frame", nil, p)
  v1:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -30)
  v1:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
  Q.v1 = v1

  local list = self:Panel(v1, 236, 0)
  list:SetPoint("TOPLEFT", v1, "TOPLEFT", 0, 0)
  list:SetPoint("BOTTOMLEFT", v1, "BOTTOMLEFT", 0, 0)
  panelHead(self, list, "QH_QUESTS")
  Q.filters = {}
  local fdefs = { { "active", "QF_ACTIVE" }, { "done", "QF_DONE" }, { "all", "QF_ALL" } }
  local prevChip
  for i = 1, 3 do
    local fd = fdefs[i]
    local chip = self:Chip(list, 66, fd[2], function() Q.filter = fd[1] Q.page = 1 UI:RefreshQuests() end)
    if prevChip then chip:SetPoint("LEFT", prevChip, "RIGHT", 4, 0) else chip:SetPoint("TOPLEFT", list, "TOPLEFT", 12, -36) end
    Q.filters[fd[1]] = chip
    prevChip = chip
  end
  Q.rows = {}
  for i = 1, LIST_ROWS do
    local row = CreateFrame("Button", nil, list)
    row:SetHeight(ROW_H - 2)
    row:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -62 - (i - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -8, -62 - (i - 1) * ROW_H)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetTexture(WHITE)
    row.bg:SetAllPoints(row)
    row.bg:SetGradientAlpha("HORIZONTAL", 1, 0.82, 0.26, 0.20, 1, 0.82, 0.26, 0)
    row.accent = row:CreateTexture(nil, "ARTWORK")
    row.accent:SetTexture(WHITE)
    row.accent:SetWidth(3)
    row.accent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
    row.accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 1)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(WHITE)
    hl:SetAllPoints(row)
    hl:SetVertexColor(1, 0.82, 0.3, 0.10)
    row.ico = self:Slot(row, 30)
    row.ico:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.ico:SetQuality(1)
    row.ico:SetScript("OnEnter", function() UI:QuestTooltip(this, BananaBankDB.quests[this.qid]) end)
    row.ico:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.ico:SetScript("OnClick", function()
      -- Klick auf das Icon wirkt wie ein Klick auf die Zeile
      local r = this:GetParent()
      this = r
      r:GetScript("OnClick")()
    end)
    row.title = self:Font(row, 12, C.text)
    row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 44, -5)
    row.title:SetWidth(112)
    row.title:SetHeight(14)
    row.tag = self:Font(row, 10, C.muted)
    row.tag:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -6)
    row.tag:SetJustifyH("RIGHT")
    row.bar = self:QBar(row, 166, 12)
    row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 44, 4)
    row.index = i
    row:SetScript("OnClick", function()
      local e = Q.shown and Q.shown[this.index]
      if e then
        if IsShiftKeyDown() then
          UI:ChatInsert(BB:QuestChatText(e.q))
          return
        end
        Q.sel = e.q.id
        PlaySound("igMainMenuOptionCheckBoxOn")
        UI:RefreshQuests()
      end
    end)
    table.insert(Q.rows, row)
  end
  Q.listEmpty = self:Font(list, 11, C.muted)
  Q.listEmpty:SetPoint("TOPLEFT", list, "TOPLEFT", 14, -74)
  Q.listEmpty:SetWidth(208)
  Q.listEmpty:SetJustifyV("TOP")
  Q.prev = self:Button(list, 24, 18, "<", function() Q.page = Q.page - 1 UI:RefreshQuests() end)
  Q.prev:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 12, 10)
  Q.next = self:Button(list, 24, 18, ">", function() Q.page = Q.page + 1 UI:RefreshQuests() end)
  Q.next:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -12, 10)
  Q.pageFs = self:Font(list, 11, C.muted)
  Q.pageFs:SetPoint("BOTTOM", list, "BOTTOM", 0, 13)
  Q.pageFs:SetJustifyH("CENTER")

  -- Detail
  local d = self:Panel(v1, 0, 0)
  d:SetPoint("TOPLEFT", v1, "TOPLEFT", 244, 0)
  d:SetPoint("BOTTOMRIGHT", v1, "BOTTOMRIGHT", 0, 0)
  Q.detail = d
  Q.none = self:Font(d, 12, C.muted)
  Q.none:SetPoint("CENTER", d, "CENTER", 0, 0)
  Q.none:SetJustifyH("CENTER")

  local dc = CreateFrame("Frame", nil, d)
  dc:SetAllPoints(d)
  Q.dc = dc
  Q.ico = self:Slot(dc, 40)
  Q.ico:SetPoint("TOPLEFT", dc, "TOPLEFT", 14, -9)
  Q.ico:SetQuality(1)
  Q.ico:SetScript("OnEnter", function() UI:QuestTooltip(this, BananaBankDB.quests[Q.sel]) end)
  Q.ico:SetScript("OnLeave", function() GameTooltip:Hide() end)
  Q.ico:SetScript("OnClick", function()
    local q = BananaBankDB.quests[Q.sel]
    if q and IsShiftKeyDown() then UI:ChatInsert(BB:QuestChatText(q)) end
  end)
  Q.title = self:Font(dc, 17, C.gold)
  Q.title:SetPoint("TOPLEFT", dc, "TOPLEFT", 62, -11)
  Q.title:SetWidth(430)
  Q.title:SetHeight(20)
  Q.meta = self:Font(dc, 10, C.muted)
  Q.meta:SetPoint("TOPLEFT", dc, "TOPLEFT", 62, -36)
  Q.meta:SetWidth(250)
  Q.meta:SetHeight(12)
  Q.text = self:Font(dc, 11, { 0.82, 0.82, 0.78 })
  Q.text:SetPoint("TOPLEFT", dc, "TOPLEFT", 14, -56)
  Q.text:SetWidth(478)
  Q.text:SetHeight(28)
  Q.text:SetJustifyV("TOP")
  self:GlowLine(dc, -86, 14, -14)

  -- Aktionen unter der Trennlinie: in den Gildenchat posten, neu ausschreiben
  Q.postBtn = self:Button(dc, 118, 18, "QB_POST", function()
    local q = BananaBankDB.quests[Q.sel]
    if q then BB:PostQuestToGuild(q) end
  end)
  Q.postBtn:SetPoint("TOPLEFT", dc, "TOPLEFT", 14, -90)
  Q.repeatBtn = self:Button(dc, 68, 18, "QB_REPEAT", function()
    local q = BananaBankDB.quests[Q.sel]
    if q then UI:OpenQuestCloseDialog(q, "repeat") end
  end)
  Q.repeatBtn:SetPoint("LEFT", Q.postBtn, "RIGHT", 6, 0)

  -- Verwalter-Knoepfe rechts auf der Meta-Zeile
  Q.cancelBtn = self:Button(dc, 68, 18, "QB_CANCEL_QUEST", function(b) UI:QuestConfirm(b, "QB_CANCEL_QUEST", function()
    local q = BananaBankDB.quests[Q.sel]
    if q then BB:SetQuestStatus(q, "cancelled") end
  end) end, "danger")
  Q.cancelBtn:SetPoint("TOPRIGHT", dc, "TOPRIGHT", -12, -90)
  -- Abschliessen oeffnet den Dialog: nur abschliessen oder direkt neu ausschreiben
  Q.closeBtn = self:Button(dc, 68, 18, "QB_CLOSE", function()
    local q = BananaBankDB.quests[Q.sel]
    if q then UI:OpenQuestCloseDialog(q, "close") end
  end, "ok")
  Q.closeBtn:SetPoint("RIGHT", Q.cancelBtn, "LEFT", -4, 0)
  Q.editBtn = self:Button(dc, 68, 18, "QB_EDIT", function()
    local q = BananaBankDB.quests[Q.sel]
    if q then UI:OpenQuestEditor(q) end
  end)
  Q.editBtn:SetPoint("RIGHT", Q.closeBtn, "LEFT", -4, 0)
  Q.payBtn = self:Button(dc, 68, 18, "QB_PAYOUT", function()
    local q = BananaBankDB.quests[Q.sel]
    if q then UI:OpenPayoutDialog(q) end
  end, "ok")
  Q.payBtn:SetPoint("RIGHT", Q.editBtn, "LEFT", -4, 0)

  -- Scrollbalken fuer die Item-/Gold-Zeilen (nur sichtbar, wenn mehr Eintraege als Zeilen da sind)
  local isf = CreateFrame("ScrollFrame", "BananaBankQuestItemScroll", dc, "FauxScrollFrameTemplate")
  isf:SetPoint("TOPLEFT", dc, "TOPLEFT", 14, -112)
  isf:SetPoint("BOTTOMRIGHT", dc, "TOPRIGHT", -46, -112 - ITEM_ROWS * 26)
  isf:SetScript("OnVerticalScroll", function()
    FauxScrollFrame_OnVerticalScroll(26, function() UI:RefreshQuestDetail() end)
  end)
  isf:EnableMouseWheel(true)
  isf:SetScript("OnMouseWheel", function()
    local sb = getglobal("BananaBankQuestItemScrollScrollBar")
    if sb then sb:SetValue(sb:GetValue() - arg1 * 26) end
  end)
  Q.itemSF = isf

  -- Item-Zeilen
  Q.items = {}
  for i = 1, ITEM_ROWS do
    local r = CreateFrame("Frame", nil, dc)
    r:SetHeight(24)
    r:SetPoint("TOPLEFT", dc, "TOPLEFT", 14, -112 - (i - 1) * 26)
    r:SetPoint("TOPRIGHT", dc, "TOPRIGHT", -52, -112 - (i - 1) * 26)
    r.slot = self:Slot(r, 24)
    r.slot:SetPoint("LEFT", r, "LEFT", 0, 0)
    r.slot:SetScript("OnEnter", function()
      local q = BananaBankDB.quests[Q.sel]
      if this.goldBank then goldTooltip(this, this.goldBank) return end
      if q and this.id then itemTooltip(this, q, this.id) end
    end)
    r.slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- normale Item-Tooltips und Shift-/Strg-Klick, auch ueber dem ganzen Zeilenbereich
    r.slot:SetScript("OnClick", function()
      local q = BananaBankDB.quests[Q.sel]
      if q then UI:ItemClick(q, this.id, arg1) end
    end)
    r:EnableMouse(true)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function()
      local sb = getglobal("BananaBankQuestItemScrollScrollBar")
      if sb then sb:SetValue(sb:GetValue() - arg1 * 26) end
    end)
    r:SetScript("OnEnter", function()
      local q = BananaBankDB.quests[Q.sel]
      if this.goldBank then goldTooltip(this, this.goldBank) return end
      if q and this.slot.id then itemTooltip(this.slot, q, this.slot.id) end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnMouseUp", function()
      local q = BananaBankDB.quests[Q.sel]
      if q then UI:ItemClick(q, this.slot.id, arg1) end
    end)
    r.name = self:Font(r, 11, C.text)
    r.name:SetPoint("LEFT", r, "LEFT", 32, 0)
    r.name:SetWidth(120)
    r.name:SetHeight(13)
    r.bar = self:QBar(r, 216, 16, true)
    r.bar:SetPoint("LEFT", r, "LEFT", 156, 0)
    r.rest = self:Font(r, 10, C.muted)
    r.rest:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    r.rest:SetWidth(64)
    r.rest:SetJustifyH("RIGHT")
    table.insert(Q.items, r)
  end

  -- unten links: beste Helfer
  local hp = self:Panel(dc, 240, 104)
  hp:SetPoint("BOTTOMLEFT", dc, "BOTTOMLEFT", 8, 6)
  panelHead(self, hp, "QH_HELPERS", 13)
  Q.helpers = {}
  for i = 1, HELPER_ROWS do
    local row = CreateFrame("Frame", nil, hp)
    row:SetHeight(13)
    row:SetPoint("TOPLEFT", hp, "TOPLEFT", 10, -33 - (i - 1) * 13)
    row:SetPoint("TOPRIGHT", hp, "TOPRIGHT", -10, -33 - (i - 1) * 13)
    row.crown = row:CreateTexture(nil, "OVERLAY")
    row.crown:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    row.crown:SetWidth(12)
    row.crown:SetHeight(12)
    row.crown:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.rank = self:Font(row, 11, C.goldDim, FONT_TITLE)
    row.rank:SetPoint("LEFT", row, "LEFT", 14, 0)
    row.rank:SetWidth(16)
    row.name = self:Font(row, 11, C.text)
    row.name:SetPoint("LEFT", row, "LEFT", 32, 0)
    row.name:SetWidth(118)
    row.name:SetHeight(12)
    row.val = self:Font(row, 10, C.muted)
    row.val:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.val:SetJustifyH("RIGHT")
    table.insert(Q.helpers, row)
  end
  Q.helpEmpty = self:Font(hp, 10, C.muted)
  Q.helpEmpty:SetPoint("TOPLEFT", hp, "TOPLEFT", 12, -38)
  self:Loc(Q.helpEmpty, "QC_HELPERS_EMPTY")

  -- unten rechts: dein Beitrag
  local mp = self:Panel(dc, 240, 104)
  mp:SetPoint("BOTTOMRIGHT", dc, "BOTTOMRIGHT", -8, 6)
  panelHead(self, mp, "QH_MINE", 13)
  Q.mine = self:Font(mp, 12, C.gold)
  Q.mine:SetPoint("TOPLEFT", mp, "TOPLEFT", 12, -34)
  Q.mine:SetWidth(216)
  Q.mine:SetHeight(14)
  Q.mineRank = self:Font(mp, 10, C.muted)
  Q.mineRank:SetPoint("TOPLEFT", mp, "TOPLEFT", 12, -50)
  Q.mineRank:SetWidth(216)
  Q.mineRank:SetHeight(12)
  Q.how = self:Font(mp, 10, { 0.70, 0.72, 0.80 })
  Q.how:SetPoint("TOPLEFT", mp, "TOPLEFT", 12, -64)
  Q.how:SetWidth(216)
  Q.how:SetHeight(26)
  Q.how:SetJustifyV("TOP")
  Q.trackBtn = self:Button(mp, 96, 18, "QB_TRACK", function()
    local q = BananaBankDB.quests[Q.sel]
    if not q then return end
    BananaBankDB.qtrack[q.id] = (not BananaBankDB.qtrack[q.id]) or nil
    UI:RefreshQuestTracker()
    UI:RefreshQuests()
  end)
  Q.trackBtn:SetPoint("TOPRIGHT", mp, "TOPRIGHT", -10, -8)

  -- ===== Ansicht Ranking =====
  local v2 = CreateFrame("Frame", nil, p)
  v2:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -30)
  v2:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
  v2:Hide()
  Q.v2 = v2

  local rp = self:Panel(v2, 470, 0)
  rp:SetPoint("TOPLEFT", v2, "TOPLEFT", 0, 0)
  rp:SetPoint("BOTTOMLEFT", v2, "BOTTOMLEFT", 0, 0)
  panelHead(self, rp, "QH_RANKING")
  Q.periodMonth = self:Chip(rp, 70, "QP_MONTH", function() Q.period = "month" UI:RefreshQuests() end)
  Q.periodMonth:SetPoint("TOPRIGHT", rp, "TOPRIGHT", -12, -9)
  Q.periodAll = self:Chip(rp, 70, "QP_ALL", function() Q.period = "all" UI:RefreshQuests() end)
  Q.periodAll:SetPoint("RIGHT", Q.periodMonth, "LEFT", -4, 0)
  Q.rrows = {}
  for i = 1, RANK_ROWS do
    local row = CreateFrame("Frame", nil, rp)
    row:SetHeight(28)
    row:SetPoint("TOPLEFT", rp, "TOPLEFT", 10, -36 - (i - 1) * 30)
    row:SetPoint("TOPRIGHT", rp, "TOPRIGHT", -10, -36 - (i - 1) * 30)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetTexture(WHITE)
    row.bg:SetAllPoints(row)
    row.bg:SetGradientAlpha("HORIZONTAL", 1, 0.82, 0.26, 0.16, 1, 0.82, 0.26, 0)
    row.rank = self:Font(row, 15, C.goldDim, FONT_TITLE)
    row.rank:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.rank:SetWidth(26)
    row.name = self:Font(row, 12, C.text)
    row.name:SetPoint("LEFT", row, "LEFT", 36, 5)
    row.name:SetWidth(150)
    row.name:SetHeight(13)
    row.sub = self:Font(row, 9, C.muted)
    row.sub:SetPoint("LEFT", row, "LEFT", 36, -7)
    row.sub:SetWidth(150)
    row.bar = self:QBar(row, 230, 16)
    row.bar:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    table.insert(Q.rrows, row)
  end
  Q.rankEmpty = self:Font(rp, 11, C.muted)
  Q.rankEmpty:SetPoint("TOPLEFT", rp, "TOPLEFT", 14, -44)
  self:Loc(Q.rankEmpty, "QR_EMPTY")
  Q.rule = self:Font(rp, 9, { 0.62, 0.64, 0.74 })
  Q.rule:SetPoint("BOTTOMLEFT", rp, "BOTTOMLEFT", 12, 8)
  Q.rule:SetWidth(446)
  Q.rule:SetHeight(24)
  Q.rule:SetJustifyV("BOTTOM")
  self:Loc(Q.rule, "QR_RULE")

  local you = self:Panel(v2, 272, 108)
  you:SetPoint("TOPRIGHT", v2, "TOPRIGHT", 0, 0)
  panelHead(self, you, "QH_YOU")
  Q.youBig = self:Font(you, 26, C.gold, FONT_TITLE)
  Q.youBig:SetPoint("TOPLEFT", you, "TOPLEFT", 14, -40)
  Q.youSub = self:Font(you, 10, C.muted)
  Q.youSub:SetPoint("TOPLEFT", you, "TOPLEFT", 14, -78)
  Q.youSub:SetWidth(244)

  local win = self:Panel(v2, 272, 0)
  win:SetPoint("TOPRIGHT", you, "BOTTOMRIGHT", 0, -8)
  win:SetPoint("BOTTOMRIGHT", v2, "BOTTOMRIGHT", 0, 0)
  panelHead(self, win, "QH_WINNERS")
  Q.winners = {}
  for i = 1, 8 do
    local fs = self:Font(win, 11, C.text)
    fs:SetPoint("TOPLEFT", win, "TOPLEFT", 14, -38 - (i - 1) * 19)
    fs:SetWidth(246)
    fs:SetHeight(13)
    table.insert(Q.winners, fs)
  end
  Q.winEmpty = self:Font(win, 10, C.muted)
  Q.winEmpty:SetPoint("TOPLEFT", win, "TOPLEFT", 14, -40)
  self:Loc(Q.winEmpty, "QR_EMPTY")

  self:BuildQuestTracker()
end

-- Zweiklick-Bestaetigung fuer Abschliessen und Abbrechen
function UI:QuestConfirm(btn, key, action)
  if btn.armed then
    btn.armed = false
    btn.fs:SetText(T(key))
    BB:Cancel("qconfirm" .. key)
    action()
    return
  end
  btn.armed = true
  btn.fs:SetText(T("QB_SURE"))
  BB:After(3, function()
    btn.armed = false
    btn.fs:SetText(T(key))
  end, "qconfirm" .. key)
end

function UI:QuestFiltered()
  local out = {}
  local f = self.q.filter
  for _, q in pairs(BananaBankDB.quests) do
    local st = BB:QuestState(q)
    local active = st == "open" or st == "complete"
    if f == "all" or (f == "active" and active) or (f == "done" and not active) then
      table.insert(out, { q = q, st = st })
    end
  end
  table.sort(out, function(a, b)
    if a.st ~= b.st then return STATE_WEIGHT[a.st] < STATE_WEIGHT[b.st] end
    if a.q.ts ~= b.q.ts then return a.q.ts > b.q.ts end
    return a.q.id < b.q.id
  end)
  return out
end

function UI:RefreshQuests()
  local Q = self.q
  if not Q.rows then return end
  local can = BB:CanManageQuests()
  Q.summary:ClearAllPoints()
  if can then
    Q.newBtn:Show()
    Q.summary:SetPoint("RIGHT", Q.newBtn, "LEFT", -12, 0)
  else
    Q.newBtn:Hide()
    Q.summary:SetPoint("TOPRIGHT", Q.page_frame, "TOPRIGHT", -4, -6)
  end
  Q.chipQuests:SetActive(Q.view == "quests")
  Q.chipRank:SetActive(Q.view == "rank")
  local nActive = 0
  for _, q in pairs(BananaBankDB.quests) do
    if BB:QuestIsActive(q) then nActive = nActive + 1 end
  end
  Q.summary:SetText(string.format(T("QSUM"), nActive))
  if Q.view == "rank" then
    Q.v1:Hide()
    Q.v2:Show()
    self:RefreshQuestRanking()
    return
  end
  Q.v2:Hide()
  Q.v1:Show()
  for key, chip in pairs(Q.filters) do chip:SetActive(Q.filter == key) end

  -- Liste
  local list = self:QuestFiltered()
  Q.shown = nil
  local pages = floor((getn(list) - 1) / LIST_ROWS) + 1
  if pages < 1 then pages = 1 end
  if Q.page > pages then Q.page = pages end
  if Q.page < 1 then Q.page = 1 end
  Q.pageFs:SetText(Q.page .. "/" .. pages)
  Q.prev:SetOn(Q.page > 1)
  Q.next:SetOn(Q.page < pages)
  -- Auswahl gueltig halten
  local found = false
  for i = 1, getn(list) do
    if list[i].q.id == Q.sel then found = true end
  end
  if not found then Q.sel = list[1] and list[1].q.id or nil end

  local shown = {}
  for i = 1, LIST_ROWS do
    local e = list[(Q.page - 1) * LIST_ROWS + i]
    local row = Q.rows[i]
    shown[i] = e
    if e then
      local q, st = e.q, e.st
      local s = BB:QuestStats()[q.id]
      local col = STATE_COLOR[st]
      row.accent:SetVertexColor(col[1], col[2], col[3], 1)
      row.title:SetText(q.title)
      row.qid = q.id
      row.ico.qid = q.id
      row.ico.icon:SetTexture(UI:QuestIconTex(q))
      local selected = q.id == Q.sel
      if selected then
        row.title:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        row.bg:Show()
      else
        row.title:SetTextColor(C.text[1], C.text[2], C.text[3])
        row.bg:Hide()
      end
      row.tag:SetText(T("QS_" .. string.upper(st)))
      row.tag:SetTextColor(col[1], col[2], col[3])
      row.bar:Set(s and s.done or 0, s and s.need or 1, st)
      row:Show()
    else
      row:Hide()
    end
  end
  Q.shown = shown
  if list[1] then
    Q.listEmpty:SetText("")
  else
    Q.listEmpty:SetText(T("QD_EMPTY"))
  end
  self:RefreshQuestDetail()
end

function UI:RefreshQuestDetail()
  local Q = self.q
  local q = Q.sel and BananaBankDB.quests[Q.sel]
  if not q then
    Q.dc:Hide()
    Q.none:SetText(T("QD_NONE"))
    Q.none:Show()
    return
  end
  Q.none:Hide()
  Q.dc:Show()
  local st = BB:QuestState(q)
  local s = BB:QuestStats()[q.id]
  local col = STATE_COLOR[st]

  Q.title:SetText(q.title)
  Q.ico.icon:SetTexture(UI:QuestIconTex(q))
  local meta = "|cff" .. hex(col) .. T("QS_" .. string.upper(st)) .. "|r"
  meta = meta .. "  -  " .. string.format(T("QD_BY"), q.c or "?")
  if q.due and q.due > 0 then
    local left = timeLeft(q.due)
    if left then
      local dc = { 0.40, 0.88, 0.45 }
      if q.due - time() < 86400 then dc = { 1.00, 0.35, 0.30 } elseif q.due - time() < 3 * 86400 then dc = { 1.00, 0.65, 0.20 } end
      meta = meta .. "  -  |cff" .. hex(dc) .. string.format(T("QD_DUE_LEFT"), left) .. "|r"
    else
      meta = meta .. "  -  |cff" .. hex(STATE_COLOR.expired) .. T("QD_DUE_OVER") .. "|r"
    end
  end
  Q.meta:SetText(meta)
  if q.text and q.text ~= "" then
    Q.text:SetText("\"" .. q.text .. "\"")
  else
    Q.text:SetText("")
  end

  -- Verwalter
  local manage = BB:CanManageQuests() and q.s == "open"
  if manage then
    Q.cancelBtn:Show()
    Q.closeBtn:Show()
    Q.editBtn:Show()
    if st == "complete" and BB.Count(q.items) > 0 then Q.payBtn:Show() else Q.payBtn:Hide() end
  else
    Q.cancelBtn:Hide()
    Q.closeBtn:Hide()
    Q.editBtn:Hide()
    Q.payBtn:Hide()
  end

  -- Posten (nur aktive Quests) und Wiederholen (jede Quest) fuer Quest-Verwalter
  local canManage = BB:CanManageQuests()
  if canManage and BB:QuestIsActive(q) then Q.postBtn:Show() else Q.postBtn:Hide() end
  if canManage then Q.repeatBtn:Show() else Q.repeatBtn:Hide() end

  -- Items
  local ids = sortedItemIds(q)
  local banks = sortedGoldBanks(q)
  -- offene Ziele zuerst, erledigte danach
  local open, done = {}, {}
  for i = 1, getn(ids) do
    local e = { id = ids[i] }
    if ((s and s.eff[ids[i]]) or 0) >= q.items[ids[i]] then table.insert(done, e) else table.insert(open, e) end
  end
  for i = 1, getn(banks) do
    local e = { bank = banks[i] }
    if ((s and s.geff[banks[i]]) or 0) >= q.gold[banks[i]] then table.insert(done, e) else table.insert(open, e) end
  end
  local ent = open
  for i = 1, getn(done) do table.insert(ent, done[i]) end
  local total = getn(ent)
  local offset = 0
  if Q.itemSF and FauxScrollFrame_Update then
    FauxScrollFrame_Update(Q.itemSF, total, ITEM_ROWS, 26)
    offset = FauxScrollFrame_GetOffset(Q.itemSF)
    if type(offset) ~= "number" then offset = 0 end
  end
  for i = 1, ITEM_ROWS do
    local r = Q.items[i]
    local idx = offset + i
    local id = ent[idx] and ent[idx].id
    local gbank = ent[idx] and ent[idx].bank
    r.goldBank, r.slot.goldBank = gbank, gbank
    if gbank then
      local goal = q.gold[gbank]
      local got = (s and s.geff[gbank]) or 0
      r.slot.id = nil
      r.slot.icon:SetTexture(COIN_TEX)
      r.slot:SetQuality(1)
      r.name:SetText(string.format(T("QD_GOLD_NAME"), gbank))
      r.name:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
      local p = goal > 0 and got / goal or 0
      r.bar:SetValue(p, progColor(p, st), BB.GoldText(got) .. " / " .. BB.GoldText(goal))
      if got >= goal then
        r.rest:SetText(T("QD_ITEM_DONE"))
        r.rest:SetTextColor(STATE_COLOR.complete[1], STATE_COLOR.complete[2], STATE_COLOR.complete[3])
      else
        r.rest:SetText("-" .. BB.GoldText(goal - got))
        r.rest:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
      end
      r:Show()
    elseif id then
      local need = q.items[id]
      local got = (s and s.eff[id]) or 0
      local name, quality, tex = BB:QuestItemInfo(q, id)
      local qc = BB.QUALITY_COLOR[quality or 1] or BB.QUALITY_COLOR[1]
      r.slot.id = id
      r.slot.icon:SetTexture(BB.FullTex(tex))
      r.slot:SetQuality(quality)
      r.name:SetText(name)
      r.name:SetTextColor(qc[1], qc[2], qc[3])
      r.bar:Set(got, need, st)
      if got >= need then
        r.rest:SetText(T("QD_ITEM_DONE"))
        r.rest:SetTextColor(STATE_COLOR.complete[1], STATE_COLOR.complete[2], STATE_COLOR.complete[3])
      else
        r.rest:SetText(string.format(T("QD_LEFT"), need - got))
        r.rest:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
      end
      r:Show()
    else
      r:Hide()
    end
  end

  -- beste Helfer
  local top = BB:QuestTop(q)
  local maxC = top[1] and math.max(top[1].c, 1) or 1
  for i = 1, HELPER_ROWS do
    local row = Q.helpers[i]
    local t = top[i]
    if t then
      local m = MEDAL[i]
      row.rank:SetText(i .. ".")
      row.name:SetText(t.p)
      local vtxt = ""
      if t.c > 0 then vtxt = t.c .. " " .. T("UNIT_ITEMS") end
      if t.g and t.g > 0 then vtxt = vtxt .. (vtxt ~= "" and "  " or "") .. BB.GoldText(t.g) end
      row.val:SetText(vtxt)
      if m then
        row.rank:SetTextColor(m[1], m[2], m[3])
        row.name:SetTextColor(m[1], m[2], m[3])
      else
        row.rank:SetTextColor(C.goldDim[1], C.goldDim[2], C.goldDim[3])
        row.name:SetTextColor(C.text[1], C.text[2], C.text[3])
      end
      if i == 1 then row.crown:Show() else row.crown:Hide() end
      row:Show()
    else
      row:Hide()
    end
  end
  if top[1] then Q.helpEmpty:Hide() else Q.helpEmpty:Show() end

  -- dein Beitrag
  local me = BB:Me()
  local mineC, mineG, minePos = 0, 0, 0
  for i = 1, getn(top) do
    if top[i].p == me then
      mineC, mineG, minePos = top[i].c, top[i].g or 0, i
    end
  end
  local needAll = s and s.need or 1
  -- Gold zaehlt in ganzen Gold als Einheit, wie beim Fortschritt
  local mineU = mineC + floor(mineG / BB.GOLD)
  if mineU > 0 then
    local mtxt = ""
    if mineC > 0 then mtxt = string.format(T("QC_MINE"), mineC) end
    if mineG > 0 then mtxt = mtxt .. (mtxt ~= "" and "  " or "") .. string.format(T("QC_MINE_GOLD"), BB.GoldText(mineG)) end
    Q.mine:SetText(mtxt)
    Q.mineRank:SetText(string.format(T("QC_RANK"), minePos, getn(top), floor(mineU * 100 / math.max(needAll, 1))))
  else
    Q.mine:SetText(T("QC_NONE"))
    Q.mineRank:SetText("")
  end
  Q.how:SetText(string.format(T("QC_HOW"), BB:MainBank()))
  if BB:QuestIsActive(q) then
    Q.trackBtn:Show()
    local tracked = BananaBankDB.qtrack[q.id]
    Q.trackBtn.fs:SetText(T(tracked and "QB_UNTRACK" or "QB_TRACK"))
  else
    Q.trackBtn:Hide()
  end
end

function UI:RefreshQuestRanking()
  local Q = self.q
  Q.periodAll:SetActive(Q.period == "all")
  Q.periodMonth:SetActive(Q.period == "month")
  local since
  if Q.period == "month" then
    local d = date("*t")
    since = time({ year = d.year, month = d.month, day = 1, hour = 0, min = 0, sec = 0 })
  end
  local list = BB:QuestRanking(since)
  local me = BB:Me()
  local maxPts = list[1] and math.max(list[1].pts, 0.1) or 1
  local myPos
  for i = 1, getn(list) do
    if list[i].p == me then myPos = i end
  end
  for i = 1, RANK_ROWS do
    local row = Q.rrows[i]
    local r = list[i]
    if r then
      local m = MEDAL[i]
      local c = m or C.text
      row.rank:SetText(i .. ".")
      row.rank:SetTextColor((m or C.goldDim)[1], (m or C.goldDim)[2], (m or C.goldDim)[3])
      row.name:SetText(r.p)
      row.name:SetTextColor(c[1], c[2], c[3])
      row.sub:SetText(string.format(T("QR_SUB"), r.c, r.nq))
      row.bar:SetValue(r.pts / maxPts, m or { 0.62, 0.50, 0.20 }, string.format("%.1f", r.pts) .. " " .. T("QR_PTS"))
      if r.p == me then row.bg:Show() else row.bg:Hide() end
      row:Show()
    else
      row:Hide()
    end
  end
  if list[1] then Q.rankEmpty:Hide() else Q.rankEmpty:Show() end
  if myPos then
    local r = list[myPos]
    Q.youBig:SetText(string.format(T("QR_YOU"), myPos))
    local m = MEDAL[myPos]
    if m then Q.youBig:SetTextColor(m[1], m[2], m[3]) else Q.youBig:SetTextColor(C.gold[1], C.gold[2], C.gold[3]) end
    Q.youSub:SetText(string.format(T("QR_YOU_SUB"), r.pts, r.c, r.nq))
  else
    Q.youBig:SetText(T("QR_YOU_NONE"))
    Q.youBig:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    Q.youSub:SetText("")
  end
  -- Quest-Sieger
  local qs = {}
  for _, q in pairs(BananaBankDB.quests) do
    if q.s ~= "cancelled" then
      local top = BB:QuestTop(q)
      if top[1] then table.insert(qs, { q = q, w = top[1].p, st = BB:QuestState(q) }) end
    end
  end
  table.sort(qs, function(a, b) return a.q.ts > b.q.ts end)
  for i = 1, 8 do
    local fs = Q.winners[i]
    local e = qs[i]
    if e then
      local sc = STATE_COLOR[e.st]
      fs:SetText("|cff" .. hex(sc) .. e.q.title .. "|r  |cffa0a2b8>|r  |cff" .. hex(MEDAL[1]) .. e.w .. "|r")
      fs:Show()
    else
      fs:Hide()
    end
  end
  if qs[1] then Q.winEmpty:Hide() else Q.winEmpty:Show() end
end

-- ------------------------------------------------------------
-- Editor: neue Quest anlegen oder bestehende bearbeiten
-- ------------------------------------------------------------
local function numberOf(box, default)
  local n = tonumber(box:GetText())
  if not n then return default end
  return floor(n)
end

function UI:BuildQuestEditor()
  if self.qe then return end
  local f = CreateFrame("Frame", "BananaBankQuestEditor", UIParent)
  self.qe = f
  f:SetWidth(540)
  f:SetHeight(606)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:SetBackdrop({
    bgFile = WHITE,
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  f:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 1)
  self:Solid(f, 12, 1)
  f:Hide()
  tinsert(UISpecialFrames, "BananaBankQuestEditor")

  local head = f:CreateTexture(nil, "BORDER")
  head:SetTexture(WHITE)
  head:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -12)
  head:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -12, -56)
  head:SetGradientAlpha("VERTICAL", C.bg[1], C.bg[2], C.bg[3], 0, C.blue[1], C.blue[2], C.blue[3], 0.75)
  f.heading = self:Font(f, 22, C.gold, FONT_TITLE)
  f.heading:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -22)
  self:GlowLine(f, -56, 20, -20)

  local function label(key, y)
    local fs = self:Font(f, 10, C.goldDim)
    fs:SetPoint("TOPLEFT", f, "TOPLEFT", 28, y)
    self:Loc(fs, key)
    return fs
  end

  label("QE_NAME", -66)
  f.name = self:EditBox("BananaBankQuestName", f, 424)
  f.name:SetPoint("TOPLEFT", f, "TOPLEFT", 30, -80)
  f.name:SetMaxLetters(BB.QUEST_TITLE_LEN)

  -- Icon der Quest (Klick oeffnet die Auswahl)
  local iconL = self:Font(f, 10, C.goldDim)
  iconL:SetPoint("TOPLEFT", f, "TOPLEFT", 470, -66)
  self:Loc(iconL, "QX_ICON")
  f.iconBtn = self:Slot(f, 36)
  f.iconBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 472, -76)
  f.iconBtn:SetQuality(1)
  f.iconBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine(T("QX_ICON_TIP"), 1, 1, 1)
    GameTooltip:Show()
  end)
  f.iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.iconBtn:SetScript("OnClick", function() UI:OpenIconPicker() end)

  label("QE_TEXT", -108)
  local tp = self:Panel(f, 488, 62)
  tp:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -122)
  f.text = CreateFrame("EditBox", "BananaBankQuestText", tp)
  f.text:SetMultiLine(true)
  f.text:SetAutoFocus(false)
  f.text:SetFontObject("ChatFontNormal")
  f.text:SetMaxLetters(BB.QUEST_TEXT_LEN)
  f.text:SetWidth(466)
  f.text:SetHeight(50)
  f.text:SetPoint("TOPLEFT", tp, "TOPLEFT", 10, -7)
  f.text:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  tp:EnableMouse(true)
  tp:SetScript("OnMouseDown", function() f.text:SetFocus() end)

  -- eigener Tooltip-Text (wie bei einem Makro)
  label("QX_TIP", -194)
  local tip = self:Panel(f, 488, 62)
  tip:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -208)
  f.tip = CreateFrame("EditBox", "BananaBankQuestTip", tip)
  f.tip:SetMultiLine(true)
  f.tip:SetAutoFocus(false)
  f.tip:SetFontObject("ChatFontNormal")
  f.tip:SetMaxLetters(BB.QUEST_TIP_LEN)
  f.tip:SetWidth(466)
  f.tip:SetHeight(50)
  f.tip:SetPoint("TOPLEFT", tip, "TOPLEFT", 10, -7)
  f.tip:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  tip:EnableMouse(true)
  tip:SetScript("OnMouseDown", function() f.tip:SetFocus() end)

  label("QE_ITEMS", -280)
  local hint = self:Font(f, 9, { 0.62, 0.64, 0.74 })
  hint:SetPoint("TOPRIGHT", f, "TOPRIGHT", -26, -281)
  hint:SetJustifyH("RIGHT")
  self:Loc(hint, "QE_ITEMS_HINT")

  local ip = self:Panel(f, 488, 6 * 28 + 10)
  ip:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -294)
  f.empty = self:Font(ip, 11, C.muted)
  f.empty:SetPoint("CENTER", ip, "CENTER", 0, 0)
  self:Loc(f.empty, "QE_ITEMS_EMPTY")
  f.rows = {}
  f.items = {}
  for i = 1, BB.QUEST_MAX_ITEMS do
    local r = CreateFrame("Frame", nil, ip)
    r:SetHeight(26)
    r:SetPoint("TOPLEFT", ip, "TOPLEFT", 10, -7 - (i - 1) * 28)
    r:SetPoint("TOPRIGHT", ip, "TOPRIGHT", -10, -7 - (i - 1) * 28)
    r.slot = self:Slot(r, 24)
    r.slot:SetPoint("LEFT", r, "LEFT", 0, 0)
    r.slot:SetScript("OnEnter", function()
      if this.id then
        UI:ItemTooltip(this, this.id)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(T("QX_ITEM_HINT"), 0.5, 0.7, 1)
        GameTooltip:Show()
      end
    end)
    r.slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.slot:SetScript("OnClick", function()
      -- im Editor selbst: Shift-Klick legt den Item-Link in die Chat-Eingabezeile
      if arg1 == "LeftButton" and IsShiftKeyDown() and this.id then
        local it
        for k = 1, getn(f.items) do if f.items[k].id == this.id then it = f.items[k] end end
        if it then UI:ChatInsert(BB:ItemLinkText(it.id, it.n, it.q)) end
      end
    end)
    r.name = self:Font(r, 12, C.text)
    r.name:SetPoint("LEFT", r, "LEFT", 34, 0)
    r.name:SetWidth(250)
    r.name:SetHeight(14)
    r.amt = self:EditBox("BananaBankQuestAmt" .. i, r, 56)
    r.amt:SetPoint("LEFT", r, "LEFT", 300, 0)
    r.amt:SetNumeric(true)
    r.amt:SetMaxLetters(5)
    r.amt:SetJustifyH("CENTER")
    local idx = i
    r.amt:SetScript("OnTextChanged", function()
      local it = f.items[idx]
      if it then it.need = tonumber(this:GetText()) or it.need end
    end)
    r.del = self:Button(r, 22, 20, "x", function()
      table.remove(f.items, idx)
      UI:RefreshQuestEditor()
    end, "danger")
    r.del:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    table.insert(f.rows, r)
  end

  -- Frist und Reservierung
  local dueL = self:Font(f, 11, C.text)
  dueL:SetPoint("TOPLEFT", f, "TOPLEFT", 30, -506)
  self:Loc(dueL, "QE_DUE")
  f.due = self:EditBox("BananaBankQuestDue", f, 46)
  f.due:SetPoint("TOPLEFT", f, "TOPLEFT", 296, -501)
  f.due:SetNumeric(true)
  f.due:SetMaxLetters(3)
  f.due:SetJustifyH("CENTER")
  f.gold = {}
  f.goldBtn = self:Button(f, 160, 20, "", function() UI:OpenGoldDialog() end)
  f.goldBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 354, -501)
  f.reserve = true
  f.chk = self:Check(f, "QE_RESERVE", function() return f.reserve end, function(v) f.reserve = v end)
  f.chk:SetWidth(440)
  f.chk:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -532)

  f.cancel = self:Button(f, 110, 26, "QE_CANCEL", function() f:Hide() end)
  f.cancel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -154, 22)
  f.save = self:Button(f, 120, 26, "QE_SAVE", function() UI:SaveQuestEditor() end, "ok")
  f.save:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 22)
end

function UI:OpenQuestEditor(q)
  if not BB:CanManageQuests() then
    BB:Print("|cffff4040" .. T("ERR_QUEST_NOPERM") .. "|r")
    return
  end
  self:BuildQuestEditor()
  local f = self.qe
  f.editing = q
  f.items = {}
  f.meta = {}
  f.gold = {}
  if q then
    for _, bank in ipairs(sortedGoldBanks(q)) do
      table.insert(f.gold, { bank = bank, g = floor(q.gold[bank] / BB.GOLD) })
    end
    f.heading:SetText(T("QE_TITLE_EDIT"))
    f.name:SetText(q.title)
    f.text:SetText(q.text or "")
    f.tip:SetText(q.tip or "")
    f.icon = (q.ic and q.ic ~= "") and q.ic or nil
    f.reserve = q.rs == 1
    local ids = sortedItemIds(q)
    for i = 1, getn(ids) do
      local n, quality, tex = BB:QuestItemInfo(q, ids[i])
      table.insert(f.items, { id = ids[i], need = q.items[ids[i]], n = n, q = quality, t = tex })
    end
    local days = 0
    if q.due and q.due > 0 and q.due > time() then days = math.ceil((q.due - time()) / 86400) end
    f.dueOrig = days
    f.due:SetText(days > 0 and tostring(days) or "")
  else
    f.heading:SetText(T("QE_TITLE_NEW"))
    f.name:SetText("")
    f.text:SetText("")
    f.tip:SetText("")
    f.icon = nil
    f.reserve = true
    f.dueOrig = nil
    f.due:SetText("")
  end
  f.chk.Update()
  self:RefreshQuestEditor()
  f:Show()
  f.name:SetFocus()
end

function UI:RefreshQuestEditor()
  local f = self.qe
  if not f then return end
  for i = 1, BB.QUEST_MAX_ITEMS do
    local r = f.rows[i]
    local it = f.items[i]
    if it then
      local qc = BB.QUALITY_COLOR[it.q or 1] or BB.QUALITY_COLOR[1]
      r.slot.id = it.id
      r.slot.icon:SetTexture(BB.FullTex(it.t))
      r.slot:SetQuality(it.q)
      r.name:SetText(it.n)
      r.name:SetTextColor(qc[1], qc[2], qc[3])
      r.amt:SetText(tostring(it.need or 1))
      r:Show()
    else
      r:Hide()
    end
  end
  if f.items[1] then f.empty:Hide() else f.empty:Show() end
  f.goldBtn.fs:SetText(string.format(T("QE_GOLD_BTN"), getn(f.gold)))
  -- Icon: gewaehltes, sonst das des ersten Items
  local tex
  if f.icon and f.icon ~= "" then tex = BB.FullTex(f.icon)
  elseif f.items[1] then tex = BB.FullTex(f.items[1].t)
  else tex = BB.FullTex("") end
  f.iconBtn.icon:SetTexture(tex)
end

-- ------------------------------------------------------------
-- Gold-Ziele: je ein Bank-Char mit einem Goldbetrag (Spende per Post)
-- ------------------------------------------------------------
local GOLD_ROWS = BB.QUEST_MAX_GOLD

function UI:BuildGoldDialog()
  if self.qg then return end
  local f = CreateFrame("Frame", "BananaBankGoldGoals", UIParent)
  self.qg = f
  f:SetWidth(400)
  f:SetHeight(86 + GOLD_ROWS * 28 + 84)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:SetBackdrop({
    bgFile = WHITE, edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  f:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 1)
  f:Hide()
  local h = self:Font(f, 18, C.gold, FONT_TITLE)
  h:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -22)
  self:Loc(h, "QE_GOLD_TITLE")
  f.hint = self:Font(f, 10, { 0.70, 0.72, 0.80 })
  f.hint:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -46)
  f.hint:SetWidth(344)
  f.hint:SetHeight(28)
  f.hint:SetJustifyV("TOP")
  self:Loc(f.hint, "QE_GOLD_HINT")
  f.rows = {}
  for i = 1, GOLD_ROWS do
    local r = CreateFrame("Frame", nil, f)
    r:SetHeight(24)
    r:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -82 - (i - 1) * 28)
    r:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -82 - (i - 1) * 28)
    local idx = i
    r.bank = self:Button(r, 190, 22, "", function(b) UI:OpenGoldBankPicker(b, idx) end, "flat")
    r.bank:SetPoint("LEFT", r, "LEFT", 0, 0)
    r.amt = self:EditBox("BananaBankGoldAmt" .. i, r, 60)
    r.amt:SetPoint("LEFT", r, "LEFT", 202, 0)
    r.amt:SetNumeric(true)
    r.amt:SetMaxLetters(5)
    r.amt:SetJustifyH("CENTER")
    r.amt:SetScript("OnTextChanged", function()
      local g = UI.qe and UI.qe.gold[idx]
      if g then g.g = tonumber(this:GetText()) or g.g end
    end)
    r.unit = self:Font(r, 12, C.gold)
    r.unit:SetPoint("LEFT", r.amt, "RIGHT", 6, 0)
    r.unit:SetText("g")
    r.del = self:Button(r, 22, 20, "x", function()
      table.remove(UI.qe.gold, idx)
      UI:RefreshGoldDialog()
    end, "danger")
    r.del:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    f.rows[i] = r
  end
  f.add = self:Button(f, 130, 22, "QE_GOLD_ADD", function(b) UI:OpenGoldBankPicker(b, nil) end)
  f.add:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 28, 24)
  f.ok = self:Button(f, 120, 24, "QE_GOLD_OK", function() f:Hide() end, "ok")
  f.ok:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 24)
  f:SetScript("OnHide", function()
    UI:CloseRankPicker()
    if UI.qe then UI:RefreshQuestEditor() end
  end)
end

function UI:RefreshGoldDialog()
  local f, ed = self.qg, self.qe
  if not f or not ed then return end
  for i = 1, GOLD_ROWS do
    local r = f.rows[i]
    local g = ed.gold[i]
    if g then
      r.bank.fs:SetText(g.bank)
      r.amt:SetText(tostring(g.g or 1))
      r:Show()
    else
      r:Hide()
    end
  end
  if getn(ed.items) + getn(ed.gold) < BB.QUEST_MAX_ITEMS and getn(ed.gold) < GOLD_ROWS then f.add:Show() else f.add:Hide() end
end

-- Bank-Char waehlen: neu (idx = nil) oder einen vorhandenen Eintrag ersetzen
function UI:OpenGoldBankPicker(btn, idx)
  local ed = self.qe
  if not ed then return end
  local used = {}
  for i = 1, getn(ed.gold) do
    if i ~= idx then used[ed.gold[i].bank] = true end
  end
  local entries = {}
  local names = BB:BankList()
  for i = 1, getn(names) do
    if not used[names[i]] then table.insert(entries, { label = names[i], value = names[i] }) end
  end
  if getn(entries) == 0 then return end
  self:OpenPicker(btn, entries, function(name)
    if idx and ed.gold[idx] then
      ed.gold[idx].bank = name
    else
      table.insert(ed.gold, { bank = name, g = 5 })
    end
    UI:RefreshGoldDialog()
  end, true)
end

function UI:OpenGoldDialog()
  if not self.qe then return end
  self:BuildGoldDialog()
  self.qg:Show()
  self:RefreshGoldDialog()
end

-- Item einfuegen (Shift-Klick in der Tasche, Strg-Klick im Bestand)
function UI:QuestAddItem(id, meta)
  local f = self.qe
  if not f or not id then return end
  for i = 1, getn(f.items) do
    if f.items[i].id == id then
      f.items[i].need = (f.items[i].need or 0) + 1
      self:RefreshQuestEditor()
      return
    end
  end
  if getn(f.items) + getn(f.gold) >= BB.QUEST_MAX_ITEMS then
    BB:Print("|cffff4040" .. string.format(T("ERR_QUEST_ITEM_MAX"), BB.QUEST_MAX_ITEMS) .. "|r")
    return
  end
  local name, quality, tex = BB:ItemInfo(id)
  if string.sub(name, 1, 1) == "#" then
    if meta and meta.n and string.sub(meta.n, 1, 1) ~= "#" then
      name, quality, tex = meta.n, meta.q or 1, meta.t or ""
    else
      BB:Print("|cffff4040" .. T("ERR_QUEST_ITEM_UNKNOWN") .. "|r")
      return
    end
  end
  table.insert(f.items, { id = id, need = 1, n = name, q = quality, t = tex })
  self:RefreshQuestEditor()
end

function UI:SaveQuestEditor()
  local f = self.qe
  local items, meta = {}, {}
  for i = 1, getn(f.items) do
    local it = f.items[i]
    local need = numberOf(f.rows[i].amt, it.need or 1)
    if need < 1 then need = 1 end
    if need > 99999 then need = 99999 end
    items[it.id] = need
    meta[it.id] = { n = it.n, q = it.q or 1, t = it.t or "" }
  end
  local gold = {}
  for i = 1, getn(f.gold) do
    local g = f.gold[i]
    if g.bank and g.g and g.g >= 1 then gold[g.bank] = g.g * BB.GOLD end
  end
  local title, text = f.name:GetText(), f.text:GetText()
  local days = numberOf(f.due, 0)
  if days < 0 then days = 0 end
  local q
  if f.editing then
    local dueArg = days
    if f.dueOrig and days == f.dueOrig then dueArg = nil end
    if BB:EditQuest(f.editing, title, text, items, meta, dueArg, f.reserve, f.icon or "", f.tip:GetText(), gold) then q = f.editing end
  else
    q = BB:CreateQuest(title, text, items, meta, days, f.reserve, f.icon or "", f.tip:GetText(), gold)
  end
  if q then
    f:Hide()
    self.q.sel = q.id
    self.q.filter = "active"
    self.q.view = "quests"
    self:RefreshQuests()
  end
end

-- Shift-Klick auf ein Item in der Tasche fuegt es in den offenen Editor ein
local origBagClick = ContainerFrameItemButton_OnClick
if origBagClick then
  ContainerFrameItemButton_OnClick = function(button, ignoreShift)
    if button == "LeftButton" and IsShiftKeyDown() and not ignoreShift and UI.qe and UI.qe:IsVisible() then
      local link = GetContainerItemLink(this:GetParent():GetID(), this:GetID())
      local id = BB.ParseLink(link)
      if id then
        UI:QuestAddItem(id)
        return
      end
    end
    return origBagClick(button, ignoreShift)
  end
end

-- ------------------------------------------------------------
-- Tracker: verfolgte Quests als kleines Fenster am Rand
-- ------------------------------------------------------------
local TRACK_MAX = 5

function UI:BuildQuestTracker()
  if self.tracker then return end
  local f = CreateFrame("Frame", "BananaBankTracker", UIParent)
  self.tracker = f
  f:SetWidth(236)
  f:SetHeight(60)
  f:SetFrameStrata("MEDIUM")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    BananaBankDB.qpos = { this:GetLeft(), this:GetTop() }
  end)
  local pos = BananaBankDB.qpos
  f:ClearAllPoints()
  if pos and pos[1] and pos[2] then
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])
  else
    f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -46, -250)
  end
  f:SetBackdrop(UI.BACKDROP_PANEL)
  f:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.72)
  f:SetBackdropBorderColor(C.brass[1], C.brass[2], C.brass[3], 0.85)
  f:Hide()

  f.head = self:Font(f, 13, C.gold, FONT_TITLE)
  f.head:SetPoint("TOPLEFT", f, "TOPLEFT", 11, -9)
  self:Loc(f.head, "QT_TITLE")
  f.line = f:CreateTexture(nil, "ARTWORK")
  f.line:SetTexture(WHITE)
  f.line:SetHeight(1)
  f.line:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -26)
  f.line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -26)
  f.line:SetGradientAlpha("HORIZONTAL", 1, 0.82, 0.26, 0.9, 1, 0.82, 0.26, 0)

  f.titles = {}
  f.names = {}
  f.vals = {}
  for i = 1, TRACK_MAX do
    local b = CreateFrame("Button", nil, f)
    b:SetWidth(214)
    b:SetHeight(15)
    b.ico = b:CreateTexture(nil, "ARTWORK")
    b.ico:SetWidth(14)
    b.ico:SetHeight(14)
    b.ico:SetPoint("LEFT", b, "LEFT", 0, 0)
    b.ico:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.fs = self:Font(b, 11, C.gold)
    b.fs:SetPoint("LEFT", b, "LEFT", 18, 0)
    b.fs:SetWidth(196)
    b.fs:SetHeight(13)
    b.index = i
    b:SetScript("OnEnter", function() UI:QuestTooltip(this, BananaBankDB.quests[this.qid]) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function()
      local id = this.qid
      if not id then return end
      if IsShiftKeyDown() then
        local tq = BananaBankDB.quests[id]
        if tq then UI:ChatInsert(BB:QuestChatText(tq)) end
        return
      end
      UI:Init()
      UI.q.sel = id
      UI.q.view = "quests"
      UI.q.filter = "active"
      UI.frame:Show()
      UI:ShowPage("quests")
    end)
    table.insert(f.titles, b)
  end
  for i = 1, TRACK_MAX * BB.QUEST_MAX_ITEMS do
    local n = self:Font(f, 10, C.text)
    n:SetWidth(150)
    n:SetHeight(12)
    local v = self:Font(f, 10, C.text)
    v:SetWidth(60)
    v:SetJustifyH("RIGHT")
    table.insert(f.names, n)
    table.insert(f.vals, v)
  end
end

function UI:RefreshQuestTracker()
  local f = self.tracker
  if not f then return end
  local db = BananaBankDB
  if db.qtrackerHidden or not BB:Ready() then
    f:Hide()
    return
  end
  local list = {}
  for id in pairs(db.qtrack) do
    local q = db.quests[id]
    if q and BB:QuestIsActive(q) then
      table.insert(list, q)
    elseif not q or q.s ~= "open" then
      db.qtrack[id] = nil
    end
  end
  table.sort(list, function(a, b) return a.ts < b.ts end)
  if getn(list) == 0 then
    f:Hide()
    return
  end
  local y = 32
  local li = 0
  for i = 1, TRACK_MAX do
    local b = f.titles[i]
    local q = list[i]
    if q then
      local stats = BB:QuestStats()[q.id]
      local done = stats and stats.complete
      b.qid = q.id
      b.ico:SetTexture(UI:QuestIconTex(q))
      b.fs:SetText(q.title)
      if done then b.fs:SetTextColor(STATE_COLOR.complete[1], STATE_COLOR.complete[2], STATE_COLOR.complete[3])
      else b.fs:SetTextColor(C.gold[1], C.gold[2], C.gold[3]) end
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", f, "TOPLEFT", 11, -y)
      b:Show()
      y = y + 16
      local ids = sortedItemIds(q)
      for k = 1, getn(ids) do
        li = li + 1
        local n, v = f.names[li], f.vals[li]
        local id = ids[k]
        local need = q.items[id]
        local got = (stats and stats.eff[id]) or 0
        local name = BB:QuestItemInfo(q, id)
        n:SetText(name)
        local c = got >= need and STATE_COLOR.complete or { 0.84, 0.84, 0.80 }
        n:SetTextColor(c[1], c[2], c[3])
        v:SetText(got .. "/" .. need)
        local vc = got >= need and STATE_COLOR.complete or progColor(got / need, "open")
        v:SetTextColor(vc[1], vc[2], vc[3])
        n:ClearAllPoints()
        n:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -y)
        v:ClearAllPoints()
        v:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -y)
        n:Show()
        v:Show()
        y = y + 13
      end
      local gb = sortedGoldBanks(q)
      for k = 1, getn(gb) do
        li = li + 1
        local n, v = f.names[li], f.vals[li]
        local goal = q.gold[gb[k]]
        local got = (stats and stats.geff[gb[k]]) or 0
        n:SetText(string.format(T("QD_GOLD_NAME"), gb[k]))
        local c = got >= goal and STATE_COLOR.complete or { 0.84, 0.84, 0.80 }
        n:SetTextColor(c[1], c[2], c[3])
        v:SetText(BB.GoldText(got) .. "/" .. BB.GoldText(goal))
        local vc = got >= goal and STATE_COLOR.complete or progColor(got / goal, "open")
        v:SetTextColor(vc[1], vc[2], vc[3])
        n:ClearAllPoints()
        n:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -y)
        v:ClearAllPoints()
        v:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -y)
        n:Show()
        v:Show()
        y = y + 13
      end
      y = y + 5
    else
      b:Hide()
    end
  end
  for i = li + 1, getn(f.names) do
    f.names[i]:Hide()
    f.vals[i]:Hide()
  end
  f:SetHeight(y + 6)
  f:Show()
end

function UI:ToggleQuestTracker()
  local db = BananaBankDB
  db.qtrackerHidden = not db.qtrackerHidden or nil
  if db.qtrackerHidden then
    BB:Print(T("QT_HIDDEN"))
  else
    BB:Print(T("QT_SHOWN"))
  end
  self:RefreshQuestTracker()
end

-- ------------------------------------------------------------
-- Meldung in der Bildschirmmitte (neue Quest, Quest erfuellt)
-- ------------------------------------------------------------
function UI:ShowQuestToast(title, sub, big)
  if not self.toast then
    local f = CreateFrame("Frame", "BananaBankToast", UIParent)
    self.toast = f
    f:SetWidth(470)
    f:SetHeight(76)
    f:SetPoint("TOP", UIParent, "TOP", 0, -150)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetBackdrop(UI.BACKDROP_PANEL)
    f:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 0.95)
    f.glow = f:CreateTexture(nil, "BORDER")
    f.glow:SetTexture(WHITE)
    f.glow:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    f.glow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    f.glow:SetGradientAlpha("VERTICAL", 0.05, 0.08, 0.16, 0, 1, 0.82, 0.26, 0.16)
    f.t = self:Font(f, 22, C.gold, FONT_TITLE)
    f.t:SetPoint("TOP", f, "TOP", 0, -14)
    f.t:SetJustifyH("CENTER")
    f.t:SetWidth(440)
    f.s = self:Font(f, 12, C.text)
    f.s:SetPoint("TOP", f, "TOP", 0, -44)
    f.s:SetJustifyH("CENTER")
    f.s:SetWidth(440)
    f.age = 0
    f:SetScript("OnUpdate", function()
      this.age = this.age + (arg1 or 0)
      local a = 1
      if this.age < 0.3 then a = this.age / 0.3
      elseif this.age > 5.5 then a = 1 - (this.age - 5.5) / 1.0 end
      if this.age > 6.5 then
        this:Hide()
        return
      end
      this:SetAlpha(a)
    end)
    f:Hide()
  end
  local f = self.toast
  f.t:SetText(title)
  if big then f.t:SetTextColor(STATE_COLOR.complete[1], STATE_COLOR.complete[2], STATE_COLOR.complete[3])
  else f.t:SetTextColor(C.gold[1], C.gold[2], C.gold[3]) end
  f.s:SetText(sub)
  f.age = 0
  f:SetAlpha(0)
  f:Show()
  PlaySound(big and "igQuestListComplete" or "igQuestLogOpen")
end

-- ------------------------------------------------------------
-- Auszahlung: reservierte Mengen einer erfuellten Quest an einen Empfaenger schicken
-- ------------------------------------------------------------
function UI:OpenPayoutDialog(q)
  local f = self.payDlg
  if not f then
    f = CreateFrame("Frame", nil, UIParent)
    f:SetWidth(340)
    f:SetHeight(150)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    f:SetBackdrop({
      bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.015, 0.025, 0.06, 1)
    f:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 1)
    f.title = self:Font(f, 13, C.gold)
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
    f.title:SetWidth(310)
    f.title:SetHeight(16)
    f.hint = self:Font(f, 10, C.muted)
    f.hint:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -34)
    f.hint:SetWidth(312)
    f.hint:SetHeight(40)
    f.hint:SetJustifyV("TOP")
    f.lbl = self:Font(f, 11, { 0.88, 0.90, 0.96 })
    f.lbl:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -84)
    f.lbl:SetText(T("PAY_TO"))
    f.edit = self:EditBox("BananaBankPayTo", f, 170)
    f.edit:SetPoint("TOPLEFT", f, "TOPLEFT", 110, -80)
    f.edit:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    f.ok = self:Button(f, 120, 20, "PAY_GO", function()
      local q2 = f.q
      if not q2 then return end
      local r, err = BB:CreateQuestPayout(q2, f.edit:GetText())
      if not r then
        BB:Print("|cffff4040" .. T(err == "EMPTY" and "PAY_EMPTY" or (err == "CLOSED" and "PAY_CLOSED" or "PAY_NONAME")) .. "|r")
        return
      end
      f:Hide()
      BB:Print(string.format(T("PAY_DONE"), r.id, r.p))
      if BB:IsBank() and UI.bank then
        UI.bank.current = r
        UI:ShowPage("bank")
      end
      UI:Refresh()
    end, "ok")
    f.ok:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 12)
    f.no = self:Button(f, 90, 20, "PAY_CANCEL", function() f:Hide() end)
    f.no:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 12)
    self.payDlg = f
  end
  f.q = q
  f.title:SetText(T("PAY_TITLE"))
  f.hint:SetText(T("PAY_HINT"))
  f.edit:SetText(q.c or "")
  f:Show()
end

-- ------------------------------------------------------------
-- Icon-Auswahl (die Icon-Liste der Makro-Oberflaeche des Spiels)
-- ------------------------------------------------------------
local PICK_COLS, PICK_ROWS, PICK_SIZE = 8, 6, 34

local function pickList()
  if UI.pickList then return UI.pickList end
  local list = {}
  if GetNumMacroIcons and GetMacroIconInfo then
    for i = 1, GetNumMacroIcons() do
      local tex = GetMacroIconInfo(i)
      if tex then table.insert(list, BB.ShortTex(tex)) end
    end
  end
  UI.pickList = list
  return list
end

local function pickTile(parent, x, y)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(PICK_SIZE - 2)
  b:SetHeight(PICK_SIZE - 2)
  b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints(b)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
  hl:SetBlendMode("ADD")
  hl:SetAllPoints(b)
  b:SetScript("OnClick", function() UI:PickIcon(this.tex) end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine(this.tex or "", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

function UI:BuildIconPicker()
  if self.picker then return end
  local f = CreateFrame("Frame", "BananaBankIconPicker", UIParent)
  self.picker = f
  f:SetWidth(PICK_COLS * PICK_SIZE + 36)
  f:SetHeight(122 + PICK_ROWS * PICK_SIZE + 36)
  f:SetPoint("CENTER", UIParent, "CENTER", 240, 10)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:EnableMouse(true)
  f:SetBackdrop({
    bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  f:SetBackdropColor(0.015, 0.025, 0.06, 1)
  f:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 1)
  f:Hide()
  tinsert(UISpecialFrames, "BananaBankIconPicker")
  f.page = 1

  local title = self:Font(f, 13, C.gold)
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
  self:Loc(title, "QX_PICK_TITLE")
  local def = self:Button(f, PICK_COLS * PICK_SIZE, 18, "QX_PICK_DEFAULT", function() UI:PickIcon(nil) end)
  def:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -34)
  local il = self:Font(f, 10, C.goldDim)
  il:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -60)
  self:Loc(il, "QX_PICK_ITEMS")
  f.itemTiles = {}
  for i = 1, BB.QUEST_MAX_ITEMS do
    table.insert(f.itemTiles, pickTile(f, 16 + (i - 1) * PICK_SIZE, -76))
  end
  f.tiles = {}
  for r = 0, PICK_ROWS - 1 do
    for c = 0, PICK_COLS - 1 do
      table.insert(f.tiles, pickTile(f, 16 + c * PICK_SIZE, -122 - r * PICK_SIZE))
    end
  end
  f.prev = self:Button(f, 24, 18, "<", function() f.page = f.page - 1 UI:RefreshIconPicker() end)
  f.prev:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 12)
  f.next = self:Button(f, 24, 18, ">", function() f.page = f.page + 1 UI:RefreshIconPicker() end)
  f.next:SetPoint("LEFT", f.prev, "RIGHT", 4, 0)
  f.pageFs = self:Font(f, 10, C.muted)
  f.pageFs:SetPoint("LEFT", f.next, "RIGHT", 8, 0)
  local close = self:Button(f, 80, 18, "QX_PICK_CLOSE", function() f:Hide() end)
  close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 12)
end

function UI:RefreshIconPicker()
  local f = self.picker
  if not f then return end
  local ed = self.qe
  for i = 1, BB.QUEST_MAX_ITEMS do
    local t = f.itemTiles[i]
    local it = ed and ed.items[i]
    if it and it.t and it.t ~= "" then
      t.tex = it.t
      t.icon:SetTexture(BB.FullTex(it.t))
      t:Show()
    else
      t:Hide()
    end
  end
  local list = pickList()
  local per = PICK_COLS * PICK_ROWS
  local pages = math.max(1, math.ceil(getn(list) / per))
  if f.page > pages then f.page = pages end
  if f.page < 1 then f.page = 1 end
  for i = 1, per do
    local t = f.tiles[i]
    local tex = list[(f.page - 1) * per + i]
    if tex then
      t.tex = tex
      t.icon:SetTexture(BB.FullTex(tex))
      t:Show()
    else
      t:Hide()
    end
  end
  f.pageFs:SetText(string.format(T("QX_PICK_PAGE"), f.page, pages))
  f.prev:SetOn(f.page > 1)
  f.next:SetOn(f.page < pages)
end

function UI:OpenIconPicker()
  if not self.qe then return end
  self:BuildIconPicker()
  self.picker.page = 1
  self:RefreshIconPicker()
  self.picker:Show()
end

-- tex = nil: zurueck zum Standard (Icon des ersten Items)
function UI:PickIcon(tex)
  local ed = self.qe
  if ed then
    ed.icon = tex
    self:RefreshQuestEditor()
  end
  if self.picker then self.picker:Hide() end
end

-- ------------------------------------------------------------
-- Dialog: Quest abschliessen und direkt neu ausschreiben / Quest wiederholen
-- ------------------------------------------------------------
function UI:OpenQuestCloseDialog(q, mode)
  local f = self.closeDlg
  if not f then
    f = CreateFrame("Frame", "BananaBankCloseDlg", UIParent)
    self.closeDlg = f
    f:SetWidth(410)
    f:SetHeight(300)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    f:SetBackdrop({
      bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.015, 0.025, 0.06, 1)
    f:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 1)
    f:Hide()
    tinsert(UISpecialFrames, "BananaBankCloseDlg")

    f.title = self:Font(f, 15, C.gold, FONT_TITLE)
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
    f.title:SetWidth(378)
    f.title:SetHeight(18)
    f.info = self:Font(f, 10, C.muted)
    f.info:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -38)
    f.info:SetWidth(378)
    f.info:SetHeight(28)
    f.info:SetJustifyV("TOP")

    f.again = true
    f.optOnly = self:Check(f, "QX_OPT_ONLY", function() return not f.again end, function() f.again = false f.Sync() end)
    f.optOnly:SetWidth(370)
    f.optOnly:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -72)
    f.optAgain = self:Check(f, "QX_OPT_AGAIN", function() return f.again end, function() f.again = true f.Sync() end)
    f.optAgain:SetWidth(370)
    f.optAgain:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -96)

    f.nameL = self:Font(f, 11, C.text)
    f.nameL:SetPoint("TOPLEFT", f, "TOPLEFT", 32, -134)
    self:Loc(f.nameL, "QX_NEW_NAME")
    f.nameE = self:EditBox("BananaBankCloseName", f, 230)
    f.nameE:SetPoint("TOPLEFT", f, "TOPLEFT", 140, -130)
    f.nameE:SetMaxLetters(BB.QUEST_TITLE_LEN)
    f.nameE:SetScript("OnTextChanged", function() f.Sync() end)
    f.daysL = self:Font(f, 11, C.text)
    f.daysL:SetPoint("TOPLEFT", f, "TOPLEFT", 32, -164)
    f.daysL:SetWidth(280)
    self:Loc(f.daysL, "QX_DAYS")
    f.daysE = self:EditBox("BananaBankCloseDays", f, 46)
    f.daysE:SetPoint("TOPLEFT", f, "TOPLEFT", 336, -160)
    f.daysE:SetNumeric(true)
    f.daysE:SetMaxLetters(3)
    f.daysE:SetJustifyH("CENTER")
    f.daysE:SetScript("OnTextChanged", function() f.Sync() end)
    f.reserve = true
    f.chk = self:Check(f, "QE_RESERVE", function() return f.reserve end, function(v) f.reserve = v end)
    f.chk:SetWidth(360)
    f.chk:SetPoint("TOPLEFT", f, "TOPLEFT", 30, -190)

    f.sum = self:Font(f, 10, C.muted)
    f.sum:SetPoint("TOPLEFT", f, "TOPLEFT", 32, -220)
    f.sum:SetWidth(356)
    f.sum:SetHeight(30)
    f.sum:SetJustifyV("TOP")

    f.ok = self:Button(f, 230, 22, "QX_OK_BOTH", function() UI:ConfirmQuestClose() end, "ok")
    f.ok:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 14)
    f.no = self:Button(f, 100, 22, "QE_CANCEL", function() f:Hide() end)
    f.no:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)

    -- Felder nur aktiv, wenn neu ausgeschrieben wird; Zusammenfassung und Knopftext folgen der Auswahl
    f.Sync = function()
      f.optOnly.Update()
      f.optAgain.Update()
      local a = f.again and 1 or 0.35
      f.nameE:SetAlpha(a)
      f.daysE:SetAlpha(a)
      f.nameL:SetAlpha(a)
      f.daysL:SetAlpha(a)
      f.chk:SetAlpha(a)
      f.nameE:EnableMouse(f.again)
      f.daysE:EnableMouse(f.again)
      f.chk:EnableMouse(f.again)
      if not f.again then
        f.nameE:ClearFocus()
        f.daysE:ClearFocus()
        f.sum:SetText("")
        f.ok.fs:SetText(T("QX_OK_CLOSE"))
      else
        local days = numberOf(f.daysE, 0)
        local due = days > 0 and string.format(T("QX_SUM_DUE"), date("%d.%m.", time() + days * 86400)) or T("QX_SUM_NODUE")
        local qq = f.q
        f.sum:SetText(string.format(T("QX_SUMMARY"), qq and BB.Count(qq.items) or 0, due, qq and BB:QuestNeed(qq) or 0))
        f.ok.fs:SetText(T(f.mode == "close" and "QX_OK_BOTH" or "QX_OK_REPEAT"))
      end
    end
  end
  if not BB:CanManageQuests() then
    BB:Print("|cffff4040" .. T("ERR_QUEST_NOPERM") .. "|r")
    return
  end
  f.q = q
  f.mode = mode
  f.again = true
  f.reserve = q.rs == 1
  f.title:SetText(T(mode == "close" and "QX_CLOSE_TITLE" or "QX_REPEAT_TITLE"))
  f.info:SetText(T(mode == "close" and "QX_CLOSE_INFO" or "QX_REPEAT_INFO"))
  if mode == "close" then
    f.optOnly:Show()
    f.optAgain:Show()
  else
    f.optOnly:Hide()
    f.optAgain:Hide()
  end
  f.nameE:SetText(BB:NextQuestTitle(q.title))
  local days = BB:QuestSpanDays(q)
  f.daysE:SetText(days > 0 and tostring(days) or "")
  f.chk.Update()
  f.Sync()
  f:Show()
end

function UI:ConfirmQuestClose()
  local f = self.closeDlg
  local q = f and f.q
  if not q then return end
  local Q = self.q
  if f.mode == "close" and not f.again then
    BB:SetQuestStatus(q, "closed")
    f:Hide()
    self:RefreshQuests()
    return
  end
  local days = numberOf(f.daysE, 0)
  if days < 0 then days = 0 end
  local nq = BB:RepeatQuest(q, f.nameE:GetText(), days, f.reserve, f.mode == "close")
  if nq then
    f:Hide()
    Q.sel = nq.id
    Q.filter = "active"
    Q.view = "quests"
    BB:Print(string.format(T("QMSG_REPEATED"), nq.title))
    self:RefreshQuests()
  end
end

function UI:QuestLinkTooltip(id)
  local q = BananaBankDB.quests[id]
  if not ItemRefTooltip then return end
  ShowUIPanel(ItemRefTooltip)
  ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
  if not q then
    ItemRefTooltip:AddLine(T("QX_LINK_UNKNOWN"), 1, 0.65, 0.2, 1)
    ItemRefTooltip:Show()
    return
  end
  local s = BB:QuestStats()[q.id]
  local done, need = s and s.done or 0, s and s.need or BB:QuestNeed(q)
  ItemRefTooltip:AddLine(q.title, C.gold[1], C.gold[2], C.gold[3])
  if q.text and q.text ~= "" then ItemRefTooltip:AddLine(q.text, 1, 1, 1, 1) end
  ItemRefTooltip:AddLine(" ")
  local ids = {}
  for iid in pairs(q.items) do table.insert(ids, iid) end
  table.sort(ids)
  for i = 1, getn(ids) do
    local iid = ids[i]
    local n, qual = BB:QuestItemInfo(q, iid)
    local col = BB.QUALITY_COLOR[qual or 1] or BB.QUALITY_COLOR[1]
    local got = s and s.eff[iid] or 0
    ItemRefTooltip:AddDoubleLine(n, got .. " / " .. q.items[iid], col[1], col[2], col[3], 0.8, 0.8, 0.8)
  end
  ItemRefTooltip:AddLine(" ")
  local pc = (need > 0 and done >= need) and STATE_COLOR.complete or STATE_COLOR.open
  ItemRefTooltip:AddLine(string.format(T("QX_TT_PROGRESS"), done, need), pc[1], pc[2], pc[3])
  if q.due and q.due > 0 then ItemRefTooltip:AddLine(string.format(T("QD_DUE_LEFT"), date("%d.%m.", q.due)), 0.8, 0.8, 0.8) end
  ItemRefTooltip:Show()
end

-- Shift-Klick auf einen Item-Link im Chat uebernimmt das Item in den offenen Quest-Editor
local origSetItemRef = SetItemRef
if origSetItemRef then
  SetItemRef = function(link, text, button)
    -- Klick auf [Gildenquest: ...] im Chat: Tooltip mit Beschreibung und Fortschritt
    if link and string.sub(link, 1, 8) == "bbquest:" then
      UI:QuestLinkTooltip(string.sub(link, 9))
      return
    end
    if IsShiftKeyDown() and UI.qe and UI.qe:IsVisible() and link and string.sub(link, 1, 5) == "item:" then
      local id, name, quality = BB.ParseLink(text or link)
      if id then
        UI:QuestAddItem(id, { n = name, q = quality })
        return
      end
    end
    return origSetItemRef(link, text, button)
  end
end
