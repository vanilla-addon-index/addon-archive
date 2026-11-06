-- BananaBank: Trash-Anzeige und -Verkauf (nur auf Bank-Chars)
-- * Tooltip-Hinweis und Muenz-Symbol an Taschen- und Bankfach-Items
-- * Fenster am Haendler: Vorschau und "Trash verkaufen"
-- * Knopf an der Bank: "Trash holen" (legt Trash aus den Bankfaechern in die Taschen)
-- * Erloes wird als "Trash income" im Buch gebucht

local BB = BananaBank
local UI = BB.UI
local C = UI.C
local T = function(k) return BB.T(k) end
local getn = table.getn
local WHITE = UI.WHITE

UI.trashModule = true
UI.TS = { merchant = false, running = nil }

local COIN = "Interface\\Icons\\INV_Misc_Coin_01"

-- ------------------------------------------------------------
-- Tooltip
-- ------------------------------------------------------------
local function addTrashLines(tt, id, count)
  if not id or not BB:IsBank() then return end
  local ov, o = BB:TrashOverride(id)
  if BB:IsTrash(id) then
    local v = BB:VendorValue(id) or 0
    tt:AddLine(T("TRASH_TT"), 1, 0.42, 0.33)
    if v > 0 then tt:AddLine(string.format(T("TRASH_TT2"), BB.Money(v), BB.Money(v * (count or 1))), 0.85, 0.85, 0.85) end
    if ov then tt:AddLine(string.format(T("TRASH_MANUAL"), T("TRASH_STATE_T"), o.by or "?"), 0.7, 0.85, 1) end
    tt:AddLine(T("TRASH_MID_HINT"), 0.6, 0.6, 0.6)
    tt:Show()
  elseif ov then
    tt:AddLine(string.format(T("TRASH_MANUAL"), T("TRASH_STATE_N"), o.by or "?"), 0.7, 0.85, 1)
    tt:AddLine(T("TRASH_MID_HINT"), 0.6, 0.6, 0.6)
    tt:Show()
  end
end

local function hookTooltip()
  if UI.trashTipHooked or not GameTooltip then return end
  UI.trashTipHooked = true
  local origBag = GameTooltip.SetBagItem
  if origBag then
    GameTooltip.SetBagItem = function(self, bag, slot)
      local a, b = origBag(self, bag, slot)
      local ok = pcall(function()
        local link = GetContainerItemLink(bag, slot)
        if link then
          local _, count = GetContainerItemInfo(bag, slot)
          addTrashLines(self, BB.ParseLink(link), count)
        end
      end)
      return a, b
    end
  end
  local origInv = GameTooltip.SetInventoryItem
  if origInv then
    GameTooltip.SetInventoryItem = function(self, unit, slot)
      local a, b, c = origInv(self, unit, slot)
      if unit == "player" and slot and slot > 23 then
        pcall(function()
          local link = GetInventoryItemLink(unit, slot)
          if link then addTrashLines(self, BB.ParseLink(link), GetInventoryItemCount and GetInventoryItemCount(unit, slot)) end
        end)
      end
      return a, b, c
    end
  end
end

-- ------------------------------------------------------------
-- Muenz-Symbol an Items (Taschen und Bankfaecher)
-- ------------------------------------------------------------
local function markButton(button, bag, slot)
  if not button then return end
  -- Mittelklick empfangen (Links- und Rechtsklick bleiben wie sie waren)
  if not button.bbClicks and button.RegisterForClicks and BB:IsBank() then
    button.bbClicks = true
    if not pcall(function() button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp") end) then
      button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
  end
  local show = false
  if BB:IsBank() then
    local link = GetContainerItemLink(bag, slot)
    if link then
      local id = BB.ParseLink(link)
      show = id and BB:IsTrash(id) and true or false
    end
  end
  if show and not button.bbCoin then
    local t = button:CreateTexture(nil, "OVERLAY")
    t:SetTexture(COIN)
    t:SetWidth(14)
    t:SetHeight(14)
    t:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.bbCoin = t
  end
  if button.bbCoin then
    if show then button.bbCoin:Show() else button.bbCoin:Hide() end
  end
end

-- Mittelklick auf ein Item: Trash umschalten (Bestandsliste, Taschen, Bankfaecher)
function UI:TrashMiddle(id)
  if not id or not BB:IsBank() then return end
  local want, state = BB:TrashToggle(id)
  if want == nil then
    BB:Print("|cffff4040" .. string.format(T("ERR_NOT_BANK"), BB.BANK_RANK_LABEL or "") .. "|r")
    return
  end
  local key = want and "TRASH_SET_T" or "TRASH_SET_N"
  if state == "a" then key = "TRASH_SET_A" end
  BB:Print(string.format(T(key), BB:ColoredName(id)))
  self:TrashRefreshMarks()
  self:Refresh()
end

local function slotItemId(bag, slot)
  local link = GetContainerItemLink(bag, slot)
  return link and BB.ParseLink(link) or nil
end

local function hookBags()
  if UI.trashBagHooked then return end
  UI.trashBagHooked = true
  -- Taschenfelder: Mittelklick abfangen, alles andere wie gewohnt
  if ContainerFrameItemButton_OnClick then
    local origClick = ContainerFrameItemButton_OnClick
    ContainerFrameItemButton_OnClick = function(button, ignoreShift)
      if button == "MiddleButton" and BB:IsBank() then
        local id = slotItemId(this:GetParent():GetID(), this:GetID())
        if id then UI:TrashMiddle(id) end
        return
      end
      return origClick(button, ignoreShift)
    end
  end
  if BankFrameItemButtonGeneric_OnClick then
    local origBankClick = BankFrameItemButtonGeneric_OnClick
    BankFrameItemButtonGeneric_OnClick = function(button)
      if button == "MiddleButton" and BB:IsBank() then
        local id = slotItemId(-1, this:GetID())
        if id then UI:TrashMiddle(id) end
        return
      end
      return origBankClick(button)
    end
  end
  if ContainerFrame_Update then
    local orig = ContainerFrame_Update
    ContainerFrame_Update = function(frame)
      orig(frame)
      pcall(function()
        local name = frame:GetName()
        local bag = frame:GetID()
        for i = 1, (frame.size or 0) do
          local b = getglobal(name .. "Item" .. i)
          if b then markButton(b, bag, b:GetID()) end
        end
      end)
    end
  end
  if BankFrameItemButton_Update then
    local origBank = BankFrameItemButton_Update
    BankFrameItemButton_Update = function(button)
      origBank(button)
      pcall(function() markButton(button, -1, button:GetID()) end)
    end
  end
end

-- offene Taschen und die Bank neu zeichnen (nach Aenderung der Grenze, nach dem Verkauf)
function UI:TrashRefreshMarks()
  pcall(function()
    for i = 1, 13 do
      local f = getglobal("ContainerFrame" .. i)
      if f and f:IsShown() and ContainerFrame_Update then ContainerFrame_Update(f) end
    end
    if BankFrame and BankFrame:IsShown() and BankFrameItemButton_Update then
      for i = 1, 24 do
        local b = getglobal("BankFrameItem" .. i)
        if b then BankFrameItemButton_Update(b) end
      end
    end
  end)
end

-- ------------------------------------------------------------
-- Fenster am Haendler
-- ------------------------------------------------------------
function UI:BuildTrashWindow()
  if self.trashWin or not MerchantFrame then return end
  local f = CreateFrame("Frame", "BananaBankTrash", MerchantFrame)
  self.trashWin = f
  f:SetWidth(232)
  f:SetHeight(150)
  f:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", -30, -14)
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 24,
    insets = { left = 7, right = 7, top = 7, bottom = 7 },
  })
  f:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.97)
  f:Hide()
  local logo = f:CreateTexture(nil, "OVERLAY")
  logo:SetTexture(COIN)
  logo:SetWidth(26)
  logo:SetHeight(26)
  logo:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -12)
  local title = self:Font(f, 14, C.gold, UI.FONT_TITLE)
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 44, -14)
  self:Loc(title, "TRASH_TITLE")
  f.l1 = self:Font(f, 11, C.text)
  f.l1:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -46)
  f.l1:SetWidth(204)
  f.l1:SetHeight(14)
  f.l2 = self:Font(f, 12, C.gold)
  f.l2:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -62)
  f.l2:SetWidth(204)
  f.l2:SetHeight(15)
  f.l3 = self:Font(f, 10, C.muted)
  f.l3:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -80)
  f.l3:SetWidth(204)
  f.l3:SetHeight(26)
  f.l3:SetJustifyV("TOP")
  f.sell = self:Button(f, 204, 24, "TRASH_SELL", function() UI:TrashSellStart() end, "primary")
  f.sell:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 36)
  f.prev = self:Button(f, 204, 20, "TRASH_PREVIEW", function() UI:TrashPreview() end)
  f.prev:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 12)
end

function UI:RefreshTrashWindow()
  local f = self.trashWin
  if not f then return end
  if not (self.TS.merchant and BB:IsBank()) then
    f:Hide()
    return
  end
  f:Show()
  local plan, total = BB:TrashPlan()
  local items = 0
  for i = 1, getn(plan) do items = items + plan[i].c end
  f.l1:SetText(string.format(T("TRASH_COUNT"), getn(plan), items))
  f.l2:SetText(string.format(T("TRASH_INCOME"), BB.Money(total)))
  local sbank, ibank = BB:TrashInBank()
  f.l3:SetText(T("TRASH_LIMIT") .. (sbank > 0 and ("\n" .. string.format(T("TRASH_IN_BANK"), sbank, ibank)) or ""))
  if self.TS.running then
    f.sell.fs:SetText(T("TRASH_RUNNING"))
    f.sell:SetOn(false)
  else
    f.sell.fs:SetText(T("TRASH_SELL"))
    f.sell:SetOn(getn(plan) > 0)
  end
  f.prev:SetOn(getn(plan) > 0)
end

function UI:TrashPreview()
  local plan, total = BB:TrashPlan()
  BB:Print(string.format(T("TRASH_PREVIEW_HEAD"), getn(plan), BB.Money(total)))
  local shown = 0
  for i = 1, getn(plan) do
    if shown < 15 then
      local p = plan[i]
      DEFAULT_CHAT_FRAME:AddMessage("  " .. p.c .. "x " .. BB:ColoredName(p.id) .. "  " .. BB.Money(p.v * p.c))
      shown = shown + 1
    end
  end
  if getn(plan) > shown then DEFAULT_CHAT_FRAME:AddMessage("  ... +" .. (getn(plan) - shown)) end
end

-- ------------------------------------------------------------
-- Verkauf
-- Der Erloes ist das, was der Haendler wirklich gezahlt hat (Geld vorher/nachher). Items, die nach dem Verkauf noch
-- in der Tasche liegen, lassen sich nicht verkaufen und gelten ab dann als "kein Trash".
-- ------------------------------------------------------------
function UI:TrashSellStart()
  if self.TS.running or not self.TS.merchant or not BB:IsBank() then return end
  local plan = BB:TrashPlan()
  if getn(plan) == 0 then return end
  self.TS.running = { list = plan, idx = 1, tried = {}, tick = 0, money0 = GetMoney() }
  self:RefreshTrashWindow()
end

-- nach dem Verkauf kurz warten, dann abrechnen
function UI:TrashSellFinish(aborted)
  local run = self.TS.running
  if not run or run.settling then return end
  run.settling = true
  run.aborted = aborted
  BB:After(1.0, function() UI:TrashSellSettle() end, "trashsettle")
  self:RefreshTrashWindow()
end

function UI:TrashSellSettle()
  local run = self.TS.running
  self.TS.running = nil
  if not run then return end
  local failed, sold, items = {}, 0, 0
  for i = 1, getn(run.tried) do
    local p = run.tried[i]
    local link = GetContainerItemLink(p.bag, p.slot)
    local same = false
    if link and BB.ParseLink(link) == p.id then
      local _, count = GetContainerItemInfo(p.bag, p.slot)
      if (count or 1) == p.c then same = true end
    end
    if same then
      if not failed[p.id] then
        failed[p.id] = true
        BB:SetTrashOverride(p.id, "n")
        BB:Print(string.format(T("TRASH_NOSELL"), BB:ColoredName(p.id)))
      end
    else
      sold = sold + 1
      items = items + p.c
    end
  end
  local income = GetMoney() - (run.money0 or GetMoney())
  if income > 0 and sold > 0 then
    -- als "Trash income" im Buch, mit dem tatsaechlich gezahlten Betrag
    BB:AddLedger({ k = "trash", p = "Trash income", m = income, n = BB:Me(), c = items })
    BB:Print(string.format(T("TRASH_DONE"), sold, items, BB.Money(income)))
    BB:ScheduleSnapshot(3)
  elseif run.aborted then
    BB:Print(T("TRASH_ABORT"))
  end
  self:TrashRefreshMarks()
  self:Refresh()
  self:RefreshTrashWindow()
end

local sellFrame = CreateFrame("Frame")
sellFrame:SetScript("OnUpdate", function()
  local run = UI.TS.running
  if not run or run.settling then return end
  run.tick = run.tick + (arg1 or 0)
  if run.tick < 0.12 then return end
  run.tick = 0
  if not UI.TS.merchant then return UI:TrashSellFinish(true) end
  local p = run.list[run.idx]
  if not p then return UI:TrashSellFinish(false) end
  run.idx = run.idx + 1
  local link = GetContainerItemLink(p.bag, p.slot)
  if not link then return end
  local id = BB.ParseLink(link)
  local _, count = GetContainerItemInfo(p.bag, p.slot)
  if id ~= p.id or (count or 1) ~= p.c then return end
  if not BB:IsTrash(id) then return end
  if CursorHasItem() then ClearCursor() end
  UseContainerItem(p.bag, p.slot)
  table.insert(run.tried, p)
end)

-- ------------------------------------------------------------
-- Knopf an der Bank: Trash aus den Bankfaechern in die Taschen holen
-- ------------------------------------------------------------
function UI:BuildTrashFetchButton()
  if self.trashFetch then return end
  -- eigenes Fenster neben der Bank (nicht am BankFrame: Taschen-Addons ersetzen oder verstecken ihn)
  local f = CreateFrame("Frame", "BananaBankTrashFetch", UIParent)
  f:SetWidth(232)
  f:SetHeight(116)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() this.moved = true end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:SetBackdrop({
    bgFile = WHITE, edgeFile = "Interface\Tooltips\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  f:SetBackdropColor(0.03, 0.045, 0.11, 0.98)
  f:SetBackdropBorderColor(C.brass[1], C.brass[2], C.brass[3], 1)
  f:Hide()
  local logo = f:CreateTexture(nil, "OVERLAY")
  logo:SetTexture(COIN)
  logo:SetWidth(26)
  logo:SetHeight(26)
  logo:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
  local title = self:Font(f, 14, C.gold, UI.FONT_TITLE)
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 42, -14)
  self:Loc(title, "TRASH_FETCH_TITLE")
  f.l1 = self:Font(f, 11, C.text)
  f.l1:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -44)
  f.l1:SetWidth(204)
  f.l1:SetHeight(14)
  f.l2 = self:Font(f, 10, C.muted)
  f.l2:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -60)
  f.l2:SetWidth(204)
  f.l2:SetHeight(26)
  f.l2:SetJustifyV("TOP")
  f.btn = self:Button(f, 204, 24, "", function() UI:TrashFetchStart() end, "primary")
  f.btn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 12)
  self.trashFetch = f
end

function UI:RefreshTrashFetch()
  local f = self.trashFetch
  if not f then return end
  if not (BB:IsBank() and BB.bankOpen) then
    f:Hide()
    return
  end
  local stacks, items = BB:TrashInBank()
  if stacks == 0 then
    f:Hide()
    return
  end
  if not f.moved then
    f:ClearAllPoints()
    if BankFrame and BankFrame:IsVisible() then
      f:SetPoint("TOPLEFT", BankFrame, "TOPRIGHT", -30, -14)
    else
      f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -60, -260)
    end
  end
  f.l1:SetText(string.format(T("TRASH_COUNT_BANK"), stacks, items))
  f.l2:SetText(T("TRASH_FETCH_HINT"))
  f.btn.fs:SetText(string.format(T("TRASH_FETCH"), stacks))
  f.btn:SetOn(not self.TS.fetching)
  f:Show()
end

function UI:TrashFetchStart()
  if self.TS.fetching or not BB.bankOpen then return end
  local list = {}
  for _, bag in ipairs(BB.BANK_LIST) do
    for slot = 1, (GetContainerNumSlots(bag) or 0) do
      local link = GetContainerItemLink(bag, slot)
      if link then
        local id = BB.ParseLink(link)
        if id and BB:IsTrash(id) then table.insert(list, { bag = bag, slot = slot, id = id }) end
      end
    end
  end
  if getn(list) == 0 then return end
  self.TS.fetching = { list = list, idx = 1, tick = 0, moved = 0 }
  self:RefreshTrashFetch()
end

local fetchFrame = CreateFrame("Frame")
fetchFrame:SetScript("OnUpdate", function()
  local run = UI.TS.fetching
  if not run then return end
  run.tick = run.tick + (arg1 or 0)
  if run.tick < 0.2 then return end
  run.tick = 0
  local done = false
  if not BB.bankOpen then
    done = true
  elseif not BB:HasFreeBagSlot() then
    BB:Print("|cffff4040" .. T("ERR_BAGS_FULL") .. "|r")
    done = true
  else
    local p = run.list[run.idx]
    if not p then
      done = true
    else
      run.idx = run.idx + 1
      local link = GetContainerItemLink(p.bag, p.slot)
      if link and BB.ParseLink(link) == p.id then
        if CursorHasItem() then ClearCursor() end
        UseContainerItem(p.bag, p.slot)
        run.moved = run.moved + 1
      end
    end
  end
  if done then
    UI.TS.fetching = nil
    if run.moved > 0 then BB:Print(string.format(T("TRASH_FETCHED"), run.moved)) end
    UI:RefreshTrashFetch()
    UI:TrashRefreshMarks()
  end
end)

-- ------------------------------------------------------------
-- Liste der manuellen Entscheidungen
-- ------------------------------------------------------------
local LIST_ROWS = 12

function UI:BuildTrashList()
  if self.trashList then return end
  local f = CreateFrame("Frame", "BananaBankTrashList", UIParent)
  self.trashList = f
  f:SetWidth(380)
  f:SetHeight(86 + LIST_ROWS * 22 + 40)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
  f:SetFrameStrata("DIALOG")
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
  tinsert(UISpecialFrames, "BananaBankTrashList")
  local h = self:Font(f, 18, C.gold, UI.FONT_TITLE)
  h:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -22)
  self:Loc(h, "TRASH_LIST_TITLE")
  local hint = self:Font(f, 10, { 0.70, 0.72, 0.80 })
  hint:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -46)
  hint:SetWidth(324)
  hint:SetHeight(24)
  hint:SetJustifyV("TOP")
  self:Loc(hint, "TRASH_LIST_HINT")
  f.rows = {}
  for i = 1, LIST_ROWS do
    local r = CreateFrame("Frame", nil, f)
    r:SetHeight(20)
    r:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -78 - (i - 1) * 22)
    r:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -78 - (i - 1) * 22)
    r.name = self:Font(r, 11, C.text)
    r.name:SetPoint("LEFT", r, "LEFT", 0, 0)
    r.name:SetWidth(190)
    r.name:SetHeight(13)
    r.state = self:Font(r, 10, C.muted)
    r.state:SetPoint("LEFT", r, "LEFT", 196, 0)
    r.state:SetWidth(90)
    local idx = i
    r.del = self:Button(r, 22, 18, "x", function()
      local e = UI.trashListRows and UI.trashListRows[idx]
      if e then
        BB:SetTrashOverride(e.id, "a")
        UI:TrashRefreshMarks()
        UI:Refresh()
        UI:RefreshTrashList()
      end
    end, "danger")
    r.del:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    f.rows[i] = r
  end
  f.empty = self:Font(f, 11, C.muted)
  f.empty:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -86)
  self:Loc(f.empty, "TRASH_LIST_EMPTY")
  f.page = 1
  f.prev = self:Button(f, 26, 20, "<", function() f.page = f.page - 1 UI:RefreshTrashList() end, "flat")
  f.prev:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 26, 22)
  f.pageFs = self:Font(f, 11, C.text)
  f.pageFs:SetPoint("LEFT", f.prev, "RIGHT", 4, 0)
  f.pageFs:SetWidth(50)
  f.pageFs:SetJustifyH("CENTER")
  f.next = self:Button(f, 26, 20, ">", function() f.page = f.page + 1 UI:RefreshTrashList() end, "flat")
  f.next:SetPoint("LEFT", f.prev, "RIGHT", 58, 0)
  f.reset = self:Button(f, 130, 22, "TRASH_LIST_RESET", function()
    BB:TrashResetAll()
    UI:TrashRefreshMarks()
    UI:Refresh()
    UI:RefreshTrashList()
  end, "danger")
  f.reset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -120, 22)
  f.close = self:Button(f, 90, 22, "TRASH_LIST_CLOSE", function() f:Hide() end)
  f.close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 22)
end

function UI:RefreshTrashList()
  local f = self.trashList
  if not f then return end
  local list = {}
  for id, o in pairs(BananaBankDB.trashOv or {}) do
    if o.s ~= "a" then table.insert(list, { id = id, s = o.s, by = o.by }) end
  end
  table.sort(list, function(a, b) return (BB:ItemInfo(a.id) or "") < (BB:ItemInfo(b.id) or "") end)
  local pages = math.floor((getn(list) - 1) / LIST_ROWS) + 1
  if pages < 1 then pages = 1 end
  if f.page > pages then f.page = pages end
  if f.page < 1 then f.page = 1 end
  UI.trashListRows = {}
  for i = 1, LIST_ROWS do
    local r = f.rows[i]
    local e = list[(f.page - 1) * LIST_ROWS + i]
    UI.trashListRows[i] = e
    if e then
      r.name:SetText(BB:ColoredName(e.id))
      if e.s == "t" then
        r.state:SetText(T("TRASH_STATE_T"))
        r.state:SetTextColor(1, 0.42, 0.33)
      else
        r.state:SetText(T("TRASH_STATE_N"))
        r.state:SetTextColor(0.5, 0.9, 0.5)
      end
      r:Show()
    else
      r:Hide()
    end
  end
  if getn(list) == 0 then f.empty:Show() else f.empty:Hide() end
  f.pageFs:SetText(f.page .. " / " .. pages)
  f.prev:SetOn(f.page > 1)
  f.next:SetOn(f.page < pages)
  f.reset:SetOn(getn(list) > 0)
end

function UI:OpenTrashList()
  self:BuildTrashList()
  self.trashList:Show()
  self:RefreshTrashList()
end

-- ------------------------------------------------------------
-- Ereignisse
-- ------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("MERCHANT_SHOW")
ev:RegisterEvent("MERCHANT_CLOSED")
ev:RegisterEvent("MERCHANT_UPDATE")
ev:RegisterEvent("BANKFRAME_OPENED")
ev:RegisterEvent("BANKFRAME_CLOSED")
ev:RegisterEvent("BAG_UPDATE")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
local acc = 0
ev:SetScript("OnEvent", function()
  if event == "PLAYER_ENTERING_WORLD" then
    hookTooltip()
    hookBags()
    BB:After(5, function() if BB.TrashMigrate and BB:IsBank() then BB:TrashMigrate() end end, "trashmigrate")
  elseif event == "MERCHANT_SHOW" then
    UI.TS.merchant = true
    UI:BuildTrashWindow()
    UI:RefreshTrashWindow()
  elseif event == "MERCHANT_CLOSED" then
    UI.TS.merchant = false
    if UI.TS.running and not UI.TS.running.settling then UI:TrashSellFinish(true) end
    UI:RefreshTrashWindow()
  elseif event == "MERCHANT_UPDATE" then
    UI:RefreshTrashWindow()
  elseif event == "BANKFRAME_OPENED" then
    UI:BuildTrashFetchButton()
    -- dieses Ereignis kommt vor dem des Hauptmoduls (BB.bankOpen ist noch nicht gesetzt): spaeter nochmal pruefen
    BB:After(0.4, function() UI:RefreshTrashFetch() end, "trashfetch1")
    BB:After(1.5, function() UI:RefreshTrashFetch() end, "trashfetch2")
  elseif event == "BANKFRAME_CLOSED" then
    UI.TS.fetching = nil
    UI:RefreshTrashFetch()
  elseif event == "BAG_UPDATE" then
    acc = 0.3
  end
end)
local poll = 0
ev:SetScript("OnUpdate", function()
  -- solange die Bank offen ist, das Fetch-Fenster regelmaessig nachziehen (Taschen-Addons, spaete Scans)
  poll = poll + (arg1 or 0)
  if poll >= 2 then
    poll = 0
    if BB.bankOpen and UI.trashFetch and not UI.trashFetch:IsShown() and BB:IsBank() then UI:RefreshTrashFetch() end
  end
  if acc > 0 then
    acc = acc - (arg1 or 0)
    if acc <= 0 then
      acc = 0
      if UI.TS.merchant then UI:RefreshTrashWindow() end
      if BB.bankOpen then UI:RefreshTrashFetch() end
    end
  end
end)

-- ------------------------------------------------------------
-- Items beim allerersten Oeffnen vom Server abfragen (Namen, Tooltips, Rezept-Anforderungen)
-- Nur einmal je Account; danach nur noch von Hand mit /bb items. Gedrosselt, mit Abbrechen.
-- ------------------------------------------------------------
UI.PL = { run = nil }

local function plTip()
  if not UI.plTip then
    UI.plTip = CreateFrame("GameTooltip", "BananaBankLoadTip", UIParent, "GameTooltipTemplate")
    UI.plTip:SetOwner(UIParent, "ANCHOR_NONE")
  end
  return UI.plTip
end

local function plFrame()
  if UI.plFrame then return UI.plFrame end
  local f = CreateFrame("Frame", "BananaBankLoadFrame", UIParent)
  UI.plFrame = f
  f:SetWidth(260)
  f:SetHeight(64)
  f:SetPoint("TOP", UIParent, "TOP", 0, -120)
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop({
    bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  f:SetBackdropColor(0.03, 0.045, 0.11, 0.97)
  f:SetBackdropBorderColor(C.brass[1], C.brass[2], C.brass[3], 1)
  f:Hide()
  f.title = UI:Font(f, 12, C.gold, UI.FONT_TITLE)
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -9)
  f.title:SetText("BananaBank")
  f.txt = UI:Font(f, 11, C.text)
  f.txt:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -26)
  f.txt:SetWidth(240)
  f.txt:SetHeight(14)
  f.bar = UI:QBar(f, 170, 12)
  f.bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 9)
  f.cancel = UI:Button(f, 66, 16, "", function() UI:PreloadStop(true) end, "danger")
  f.cancel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 8)
  f.cancel.fs:SetText(T("PRELOAD_CANCEL"))
  return f
end

-- IDs, die dieser Client nicht kennt. Nur Werte aus den Bestaenden verifizierter Bank-Chars, in sinnvollem Bereich.
function UI:PreloadList()
  local list = {}
  local stock = BB:GetStock()
  for id in pairs(stock) do
    if type(id) == "number" and id > 0 and id < 100000 and not GetItemInfo(id) then table.insert(list, id) end
  end
  table.sort(list)
  return list
end

function UI:PreloadStart(manual)
  if self.PL.run then return end
  local list = self:PreloadList()
  if getn(list) == 0 then
    if manual then BB:Print(T("PRELOAD_NONE")) end
    return false
  end
  self.PL.run = { list = list, idx = 1, tick = 0, total = getn(list), manual = manual }
  local f = plFrame()
  f:Show()
  self:PreloadShow()
  return true
end

function UI:PreloadShow()
  local run = self.PL.run
  local f = self.plFrame
  if not run or not f then return end
  local n = run.idx - 1
  f.txt:SetText(string.format(T("PRELOAD_TITLE"), n, run.total))
  f.bar:Set(n, run.total, "open")
end

function UI:PreloadStop(cancelled)
  local run = self.PL.run
  self.PL.run = nil
  if self.plFrame then self.plFrame:Hide() end
  BananaBankDB.itemsPreloaded = time()
  if run then
    BB:Print(string.format(T(cancelled and "PRELOAD_CANCELLED" or "PRELOAD_DONE"), run.idx - 1))
  end
  self:Refresh()
end

local plAcc, plWatch = 0, 0
local plEv = CreateFrame("Frame")
plEv:SetScript("OnUpdate", function()
  local dt = arg1 or 0
  local run = UI.PL.run
  if run then
    run.tick = run.tick + dt
    if run.tick >= 0.25 then
      run.tick = 0
      local id = run.list[run.idx]
      if not id then return UI:PreloadStop(false) end
      run.idx = run.idx + 1
      if not GetItemInfo(id) then pcall(function() plTip():SetHyperlink("item:" .. id .. ":0:0:0") end) end
      UI:PreloadShow()
    end
    return
  end
  -- erstes Oeffnen von BananaBank: einmal anstossen, sobald es einen Bestand gibt
  plWatch = plWatch + dt
  if plWatch < 1 then return end
  plWatch = 0
  local db = BananaBankDB
  if not db or db.itemsPreloaded or not UI.frame or not UI.frame:IsVisible() or not BB:Ready() then return end
  if BB.Count(BB:GetStock()) == 0 then return end   -- noch kein Bestand angekommen: spaeter
  if UI:PreloadStart(false) == false then db.itemsPreloaded = time() end
end)
