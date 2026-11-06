-- EGM tab 2: Create Order on the AH "Auction" art: left panel = the order form (like Create Auction),
-- right list = own open orders (like the Auctions list), bottom right = Close. AuctionFrame coordinates.
EGM = EGM or {}
local T = {}
local f, itemBtn, itemName, linkBox, qtyBox, gBox, sBox, cBox, r24, r48, r7d, totalText, budgetText, errText, createBtn
local rows = {}
local ROWS, ROW_H = 13, 21
local heads = {}
local scroll
local searchText, results = "", {}
local QCOLOR = { [0] = "|cff9d9d9d", "|cffffffff", "|cff1eff00", "|cff0070dd", "|cffa335ee", "|cffff8000" }
local cur = { item = nil, name = nil, tex = nil, stack = 1 }
local hours = 24
local lastPick = nil

-- remember the last bag slot picked up: 1.12 has no GetCursorInfo
local origPickup = PickupContainerItem
if origPickup then
  PickupContainerItem = function(bag, slot) lastPick = { bag = bag, slot = slot }; return origPickup(bag, slot) end
end

local function num(b) return math.floor(tonumber(b and b:GetText() or "") or 0) end
local function price() return num(gBox) * 10000 + num(sBox) * 100 + num(cBox) end
local function setPrice(c)
  c = c or 0
  gBox:SetText(math.floor(c / 10000)); sBox:SetText(math.floor(math.mod(c, 10000) / 100)); cBox:SetText(math.mod(c, 100))
end

-- right list: search results while the search box holds 2+ letters, else the own open orders
local function refreshList()
  local searching = string.len(searchText) >= 2
  local list = {}
  if searching then
    list = results
    heads[1]:SetText("Search Results (" .. table.getn(results) .. (table.getn(results) >= 200 and "+" or "") .. ")")
    heads[2]:SetText("Stack"); heads[3]:SetText("Your Last Price"); heads[4]:SetText("")
  else
    local me = EGM.Util.player()
    local all = EGM.Orders.list()
    for i = 1, table.getn(all) do if all[i].buyer == me and (all[i].state == "open" or all[i].state == "transit") then table.insert(list, all[i]) end end
    heads[1]:SetText("Your Open Orders"); heads[2]:SetText("Open"); heads[3]:SetText("Unit Price"); heads[4]:SetText("Expires")
  end
  FauxScrollFrame_Update(scroll, table.getn(list), ROWS, ROW_H)
  local off = FauxScrollFrame_GetOffset(scroll)
  for i = 1, ROWS do
    local r, e = rows[i], list[i + off]
    r.entry, r.order = nil, nil
    if e and searching then
      r.entry = e
      r.icon:SetTexture(e.tex)
      r.name:SetText((QCOLOR[e.q] or "") .. e.name .. "|r")
      r.open:SetText(e.stack)
      local lp = EGM.Orders.lastFor(e.id)
      r.price:SetText(lp and EGM.Util.money(lp) or "|cff9d9d9d-|r")
      r.exp:SetText("")
      if cur.item == e.id then r:LockHighlight() else r:UnlockHighlight() end
      r:Show()
    elseif e then
      r.order = e
      r.icon:SetTexture(e.tex or "Interface\\Icons\\INV_Misc_QuestionMark")
      r.name:SetText(e.name or "?")
      r.open:SetText(e.open .. " / " .. e.qty)
      r.price:SetText(EGM.Util.money(e.price))
      r.exp:SetText(e.state == "transit" and "|cff7fbfffin transit|r" or EGM.Util.left(e.exp))
      r:UnlockHighlight()
      r:Show()
    else r:Hide() end
  end
  if searching and table.getn(results) == 0 then
    errText:SetText(EGM.ItemSearch and EGM.ItemSearch.available() and "|cff9d9d9dNo tradeable item matches.|r" or "|cffff2020Item list missing.|r")
  end
end

local function update()
  if not f then return end
  if cur.item then
    itemName:SetText(cur.name or ("Item " .. cur.item))
    SetItemButtonTexture(itemBtn, cur.tex or "Interface\\Icons\\INV_Misc_QuestionMark")
  else
    itemName:SetText("|cff9d9d9dSearch or drag an item|r")
    SetItemButtonTexture(itemBtn, nil)
  end
  totalText:SetText("Total " .. EGM.Util.money(price() * num(qtyBox)))
  local avail = EGM.Budget and EGM.Budget.available() or 0
  budgetText:SetText("Budget: " .. EGM.Util.money(math.max(0, avail)))
  local why = EGM.Budget and EGM.Budget.blocked()
  if why then errText:SetText("|cffff2020" .. why .. "|r") end
  r24:SetChecked(hours == 24); r48:SetChecked(hours == 48); r7d:SetChecked(hours == 168)
  if cur.item and num(qtyBox) > 0 and price() > 0 and not why then createBtn:Enable() else createBtn:Disable() end
  refreshList()
end

local function setItem(id, name)
  id = tonumber(id); if not id then return end
  local info = EGM.Util.itemInfo(id)
  cur.item, cur.name, cur.tex, cur.stack = id, (info and info.name) or name, info and info.tex, (info and info.stack) or 1
  errText:SetText("")
  local p, q = EGM.Orders.lastFor(id)
  if p then setPrice(p); qtyBox:SetText(q) end
  update()
end

local function fromCursor()
  if not CursorHasItem() or not lastPick then return end
  local link = GetContainerItemLink(lastPick.bag, lastPick.slot)
  ClearCursor()
  local id, name = EGM.Util.itemIdFromLink(link)
  if id then setItem(id, name) end
end

local function text(parent, font, x, y, s)
  local fs = parent:CreateFontString(nil, "ARTWORK", font)
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  if s then fs:SetText(s) end
  return fs
end

local function box(name, w, x, y, numeric)
  local e = CreateFrame("EditBox", name, f, "InputBoxTemplate")
  e:SetWidth(w); e:SetHeight(16)
  e:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
  e:SetAutoFocus(false)
  if numeric then e:SetNumeric(true) end
  e:SetScript("OnTextChanged", function() update() end)
  e:SetScript("OnEnterPressed", function() this:ClearFocus() end)
  e:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  return e
end

local function radio(name, x, y, label, h)
  local b = CreateFrame("CheckButton", name, f, "UIRadioButtonTemplate")
  b:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
  local t = getglobal(name .. "Text")
  if not t then t = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"); t:SetPoint("LEFT", b, "RIGHT", 2, 0) end
  t:SetText(label)
  b:SetScript("OnClick", function() hours = h; update() end)
  return b
end

local function header(name, label, x, w)
  local h = CreateFrame("Button", name, f, "WhoFrameColumnHeaderTemplate")
  h:SetPoint("TOPLEFT", f, "TOPLEFT", x, -51)
  if WhoFrameColumn_SetWidth then WhoFrameColumn_SetWidth(w, h) else h:SetWidth(w) end
  h:SetText(label)
  h:Disable()
  return h
end

-- right list (split out of T.build: Lua 5.0 allows at most 32 upvalues per function)
local function buildList()
  heads[1] = header("EGMCreateHeadItem", "Your Open Orders", 219, 250)
  heads[2] = header("EGMCreateHeadOpen", "Open", 467, 80)
  heads[3] = header("EGMCreateHeadPrice", "Unit Price", 545, 130)
  heads[4] = header("EGMCreateHeadExp", "Expires", 673, 90)
  for i = 1, ROWS do
    local r = CreateFrame("Button", "EGMCreateRow" .. i, f)
    r:SetWidth(540); r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", f, "TOPLEFT", 222, -74 - (i - 1) * ROW_H)
    r:SetHighlightTexture("Interface\\HelpFrame\\HelpFrameButton-Highlight", "ADD")
    r:GetHighlightTexture():SetTexCoord(0, 1, 0, 0.578125) -- the AH uses only the top of this texture (AuctionBrowseButtonTemplate)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetWidth(18); r.icon:SetHeight(18); r.icon:SetPoint("LEFT", r, "LEFT", 0, 0)
    r.name = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"); r.name:SetPoint("LEFT", r, "LEFT", 22, 0); r.name:SetWidth(220); r.name:SetJustifyH("LEFT")
    r.open = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"); r.open:SetPoint("LEFT", r, "LEFT", 250, 0)
    r.price = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"); r.price:SetPoint("LEFT", r, "LEFT", 328, 0)
    r.exp = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"); r.exp:SetPoint("LEFT", r, "LEFT", 456, 0)
    r:SetScript("OnClick", function()
      if this.entry then setItem(this.entry.id, this.entry.name); linkBox:ClearFocus() end
    end)
    r:SetScript("OnEnter", function()
      local id = (this.entry and this.entry.id) or (this.order and this.order.item)
      if not id then return end
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      if GetItemInfo(id) then GameTooltip:SetHyperlink("item:" .. id .. ":0:0:0")
      else GameTooltip:SetText((this.entry and this.entry.name) or (this.order and this.order.name) or "?", 1, 1, 1) end
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:Hide()
    rows[i] = r
  end
  scroll = CreateFrame("ScrollFrame", "EGMCreateScroll", f, "FauxScrollFrameTemplate")
  scroll:SetWidth(560); scroll:SetHeight(ROWS * ROW_H)
  scroll:SetPoint("TOPRIGHT", f, "TOPRIGHT", -40, -72)
  scroll:SetScript("OnVerticalScroll", function() FauxScrollFrame_OnVerticalScroll(ROW_H, refreshList) end)
end

function T.build(parent)
  f = parent

  -- left panel: the order form (Create Auction positions)
  -- box 1 (y -75..-271): item (-83/-98), unit price (-153/-167), duration (-203, radios stacked) = Create Auction's start price + duration
  text(f, "GameFontNormalSmall", 28, -83, "Order Item")
  itemBtn = CreateFrame("Button", "EGMCreateItemButton", f, "ItemButtonTemplate")
  itemBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -98)
  itemBtn:RegisterForDrag("LeftButton")
  itemBtn:SetScript("OnReceiveDrag", fromCursor)
  itemBtn:SetScript("OnClick", fromCursor)
  itemBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    if cur.item and GetItemInfo(cur.item) then GameTooltip:SetHyperlink("item:" .. cur.item .. ":0:0:0")
    else GameTooltip:SetText("Type a name into the box below and pick it from the list, drag an item here, or shift-click one in your bags.", 1, 1, 1) end
    GameTooltip:Show()
  end)
  itemBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  itemName = f:CreateFontString("EGMCreateItemName", "ARTWORK", "GameFontNormal")
  itemName:SetPoint("TOPLEFT", itemBtn, "TOPRIGHT", 6, -1)
  itemName:SetWidth(140); itemName:SetHeight(14); itemName:SetJustifyH("LEFT")
  linkBox = box("EGMCreateLinkBox", 128, 78, -120, false)
  -- search box: typing lists every tradeable item whose name matches; Enter takes an item ID, a link or the first hit
  linkBox:SetScript("OnTextChanged", function()
    searchText = this:GetText() or ""
    results = (EGM.ItemSearch and string.len(searchText) >= 2) and EGM.ItemSearch.find(searchText, 200) or {}
    errText:SetText("")
    FauxScrollFrame_SetOffset(scroll, 0)
    refreshList()
  end)
  linkBox:SetScript("OnEnterPressed", function()
    local t = this:GetText() or ""
    local id, name = EGM.Util.itemIdFromLink(t)
    if not id then id = tonumber(t) end
    if not id and results[1] then id, name = results[1].id, results[1].name end
    if id then setItem(id, name); this:SetText(""); this:ClearFocus() else errText:SetText("|cffff2020Unknown item.|r") end
  end)

  text(f, "GameFontNormalSmall", 28, -153, "Unit Price")
  gBox = box("EGMCreateGold", 46, 34, -167, true)
  text(f, "GameFontNormalSmall", 82, -170, "|cffffd700g|r")
  sBox = box("EGMCreateSilver", 24, 98, -167, true)
  text(f, "GameFontNormalSmall", 124, -170, "|cffc7c7cfs|r")
  cBox = box("EGMCreateCopper", 24, 140, -167, true)
  text(f, "GameFontNormalSmall", 166, -170, "|cffeda55fc|r")

  text(f, "GameFontNormalSmall", 28, -203, "Duration")
  -- three rows at 16 px so they stay inside the first box (ends near y -264)
  r24 = radio("EGMCreate24", 31, -214, "24 Hours", 24)
  r48 = radio("EGMCreate48", 31, -230, "48 Hours", 48)
  r7d = radio("EGMCreate7d", 31, -246, "7 Days", 168)

  -- box 2 (y -278..-344): quantity + total = Create Auction's buyout price
  text(f, "GameFontNormalSmall", 28, -297, "Quantity")
  qtyBox = box("EGMCreateQtyBox", 50, 34, -311, true)
  totalText = f:CreateFontString("EGMCreateTotal", "ARTWORK", "GameFontHighlightSmall")
  totalText:SetPoint("LEFT", qtyBox, "RIGHT", 10, 0)

  -- box 3 (y -354..-380): budget = Create Auction's deposit line
  budgetText = f:CreateFontString("EGMCreateBudget", "ARTWORK", "GameFontNormal")
  budgetText:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -364)

  errText = f:CreateFontString("EGMCreateError", "ARTWORK", "GameFontHighlightSmall")
  errText:SetPoint("TOPLEFT", f, "TOPLEFT", 224, -354)
  errText:SetWidth(560); errText:SetJustifyH("LEFT")

  createBtn = CreateFrame("Button", "EGMCreateButton", f, "UIPanelButtonTemplate")
  createBtn:SetWidth(191); createBtn:SetHeight(20)
  createBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 39)
  createBtn:SetText("Create Order")
  createBtn:SetScript("OnClick", function()
    local oid, err = EGM.Orders.create(cur.item, cur.name, cur.tex, cur.stack, price(), num(qtyBox), hours)
    if not oid then errText:SetText("|cffff2020" .. tostring(err) .. "|r"); return end
    errText:SetText("|cff20ff20Order #" .. EGM.Util.shortId(oid) .. " created.|r")
    if PlaySound then PlaySound("LOOTWINDOWCOINSOUND") end
    update()
  end)

  -- right: own open orders (Auctions list positions)
  buildList()
  local note = f:CreateFontString("EGMCreateNote", "ARTWORK", "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", f, "TOPLEFT", 224, -380) -- at the bottom edge of the list area (2026-11-05: more room for results)
  note:SetWidth(560); note:SetJustifyH("LEFT")
  note:SetText("|cffffd100Multiple Deliveries:|r Your order may be fulfilled by several guild members in separate C.O.D. mails. Keep enough space in your mailbox to receive deliveries. A full mailbox may delay or prevent delivery.")

  local close = CreateFrame("Button", "EGMCreateCloseButton", f, "UIPanelButtonTemplate")
  close:SetWidth(80); close:SetHeight(22)
  close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 14)
  close:SetText("Close")
  close:SetScript("OnClick", function() EGM.UI.hide() end)

  -- shift-click on a bag item while this tab is open picks it
  local origClick = ContainerFrameItemButton_OnClick
  if origClick then
    ContainerFrameItemButton_OnClick = function(button, ignoreShift)
      if button == "LeftButton" and IsShiftKeyDown() and not ignoreShift and f:IsVisible() then
        local id, name = EGM.Util.itemIdFromLink(GetContainerItemLink(this:GetParent():GetID(), this:GetID()))
        if id then setItem(id, name); return end
      end
      return origClick(button, ignoreShift)
    end
  end
  update()
end

function T.refresh() update() end

if EGM.UI and EGM.UI.registerTab then EGM.UI.registerTab(2, T.build, T.refresh, "Auction")
else EGM.PendingTabs = EGM.PendingTabs or {}; table.insert(EGM.PendingTabs, { index = 2, build = T.build, refresh = T.refresh, art = "Auction" }) end
