-- EGM tab 3: My Orders on the AH "Bid" art: full list (Bids positions), shipments in the row tooltip,
-- bottom right Cancel Remaining + Close. AuctionFrame coordinates.
EGM = EGM or {}
local T = {}
local ROWS, ROW_H = 16, 20
local f, scroll, rows, cancelBtn, msg
local data, selected = {}, nil
local COLS = { { "Item", 230 }, { "Unit Price", 100 }, { "Ordered", 62 }, { "Paid", 50 }, { "In Transit", 72 }, { "Open", 50 }, { "State", 80 }, { "Expires", 70 } }
local STATE_COLOR = { open = "|cff20ff20", transit = "|cff7fbfff", filled = "|cffffd100", cancelled = "|cff9d9d9d", expired = "|cff9d9d9d" }
local STATE_TEXT = { open = "open", transit = "in transit", filled = "filled", cancelled = "cancelled", expired = "expired" }

local function collect()
  data = {}
  local me = EGM.Util.player()
  local list = EGM.Orders.list()
  for i = 1, table.getn(list) do if list[i].buyer == me then table.insert(data, list[i]) end end
  table.sort(data, function(a, b)
    local aa, ba = (a.state == "open" or a.state == "transit") and 0 or 1, (b.state == "open" or b.state == "transit") and 0 or 1
    if aa ~= ba then return aa < ba end
    return a.created > b.created
  end)
end

local function tooltip(owner, o)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine((o.name or "?") .. "  |cff9d9d9d#" .. EGM.Util.shortId(o.oid) .. "|r")
  GameTooltip:AddLine(o.qty .. " x " .. EGM.Util.moneyPlain(o.price) .. "  -  " .. o.state, 1, 1, 1)
  local ships = EGM.Orders.shipments(o.oid)
  if table.getn(ships) == 0 then GameTooltip:AddLine("No deliveries yet.", 0.6, 0.6, 0.6) end
  for i = 1, table.getn(ships) do
    local s = ships[i]
    local st = s.paid and "|cff20ff20Paid|r" or s.returned and "|cffff2020Returned|r" or s.seen and "|cffffd100Seen, unpaid|r" or "In transit"
    GameTooltip:AddLine((s.seller or "?") .. ": " .. s.qty .. "x  C.O.D. " .. EGM.Util.moneyPlain(s.cod) .. "  " .. st, 1, 1, 1)
  end
  GameTooltip:Show()
end

-- Tooltip for a bar button that also works while the button is disabled: 1.12 sends no OnEnter to a disabled
-- button, so a transparent frame on top takes the mouse only then.
local function explain(btn, coverName, title, text, whyOff)
  local function show(owner, off)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(title, 1, 0.82, 0)
    GameTooltip:AddLine(text, 1, 1, 1, 1)
    if off then GameTooltip:AddLine(whyOff, 1, 0.3, 0.3, 1) end
    GameTooltip:Show()
  end
  btn:SetScript("OnEnter", function() show(btn, false) end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local cover = CreateFrame("Frame", coverName, f)
  cover:SetAllPoints(btn)
  cover:SetFrameLevel(btn:GetFrameLevel() + 2)
  cover:SetScript("OnEnter", function() show(cover, true) end)
  cover:SetScript("OnLeave", function() GameTooltip:Hide() end)
  cover:EnableMouse(false)
  return cover
end

-- the cover takes the mouse only while its button is disabled
local function syncTip(cover, enabled)
  if cover then cover:EnableMouse(not enabled) end
end

local function update()
  if not f then return end
  collect()
  local n = table.getn(data)
  FauxScrollFrame_Update(scroll, n, ROWS, ROW_H)
  local off = FauxScrollFrame_GetOffset(scroll)
  for i = 1, ROWS do
    local r, o = rows[i], data[i + off]
    if o then
      r.order = o
      r.icon:SetTexture(o.tex or "Interface\\Icons\\INV_Misc_QuestionMark")
      r.cells[1]:SetText(o.name or "?")
      r.cells[2]:SetText(EGM.Util.money(o.price))
      r.cells[3]:SetText(o.qty); r.cells[4]:SetText(o.paid); r.cells[5]:SetText(o.transit); r.cells[6]:SetText(o.open)
      r.cells[7]:SetText((STATE_COLOR[o.state] or "") .. (STATE_TEXT[o.state] or o.state) .. "|r")
      r.cells[8]:SetText(o.state == "open" and EGM.Util.left(o.exp) or "-")
      if o.oid == selected then r:LockHighlight() else r:UnlockHighlight() end
      r:Show()
    else r.order = nil; r:Hide() end
  end
  if n == 0 then msg:SetText("You have no orders yet. Use Create Order.") else msg:SetText("") end
  local o = selected and EGM.Orders.get(selected)
  local canCancel = o and (o.state == "open" or o.state == "transit") and true or false
  if canCancel then cancelBtn:Enable() else cancelBtn:Disable() end
  syncTip(T.cancelTip, canCancel)
  local canRecv = o and o.transit > 0 and true or false
  if T.recvBtn then if canRecv then T.recvBtn:Enable() else T.recvBtn:Disable() end end
  syncTip(T.recvTip, canRecv)
end

function T.build(parent)
  f = parent
  local x = 27
  for c = 1, table.getn(COLS) do
    local h = CreateFrame("Button", "EGMMyOrdersHead" .. c, f, "WhoFrameColumnHeaderTemplate")
    -- the first header starts right of the portrait (x 65, like BidQualitySort); its column still starts at x 27 below
    local hx, hw = x, COLS[c][2]
    if c == 1 then hx, hw = 65, COLS[c][2] - 38 end
    h:SetPoint("TOPLEFT", f, "TOPLEFT", hx, -52)
    if WhoFrameColumn_SetWidth then WhoFrameColumn_SetWidth(hw, h) else h:SetWidth(hw) end
    h:SetText(COLS[c][1]); h:Disable()
    x = x + COLS[c][2] - 2
  end
  rows = {}
  for i = 1, ROWS do
    local r = CreateFrame("Button", "EGMMyOrdersRow" .. i, f)
    r:SetHeight(ROW_H); r:SetWidth(x - 30)
    r:SetPoint("TOPLEFT", f, "TOPLEFT", 27, -76 - (i - 1) * ROW_H)
    r:SetHighlightTexture("Interface\\HelpFrame\\HelpFrameButton-Highlight", "ADD")
    r:GetHighlightTexture():SetTexCoord(0, 1, 0, 0.578125) -- the AH uses only the top of this texture (AuctionBrowseButtonTemplate)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetWidth(17); r.icon:SetHeight(17); r.icon:SetPoint("LEFT", r, "LEFT", 2, 0)
    r.cells = {}
    local cx = 22
    for c = 1, table.getn(COLS) do
      local fs = r:CreateFontString(nil, "ARTWORK", c == 1 and "GameFontNormalSmall" or "GameFontHighlightSmall")
      fs:SetPoint("LEFT", r, "LEFT", (c == 1) and cx or (cx - 18), 0); fs:SetWidth(COLS[c][2] - 24); fs:SetJustifyH("LEFT")
      r.cells[c] = fs
      cx = cx + COLS[c][2] - 2
    end
    r:SetScript("OnClick", function() if this.order then selected = this.order.oid; update() end end)
    r:SetScript("OnEnter", function() if this.order then tooltip(this, this.order) end end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = r
  end
  scroll = CreateFrame("ScrollFrame", "EGMMyOrdersScroll", f, "FauxScrollFrameTemplate")
  scroll:SetWidth(760); scroll:SetHeight(ROWS * ROW_H)
  scroll:SetPoint("TOPRIGHT", f, "TOPRIGHT", -40, -74)
  scroll:SetScript("OnVerticalScroll", function() FauxScrollFrame_OnVerticalScroll(ROW_H, update) end)
  msg = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  msg:SetPoint("TOP", f, "TOP", 0, -120)

  local close = CreateFrame("Button", "EGMMyOrdersClose", f, "UIPanelButtonTemplate")
  close:SetWidth(80); close:SetHeight(22)
  close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 14)
  close:SetText("Close")
  close:SetScript("OnClick", function() EGM.UI.hide() end)
  cancelBtn = CreateFrame("Button", "EGMMyOrdersCancel", f, "UIPanelButtonTemplate")
  cancelBtn:SetWidth(126); cancelBtn:SetHeight(22)
  cancelBtn:SetPoint("RIGHT", close, "LEFT", 2, 0)
  cancelBtn:SetText("Cancel Remaining")
  local recvBtn = CreateFrame("Button", "EGMMyOrdersReceived", f, "UIPanelButtonTemplate")
  recvBtn:SetWidth(126); recvBtn:SetHeight(22)
  recvBtn:SetPoint("RIGHT", cancelBtn, "LEFT", 0, 0)
  recvBtn:SetText("Mark Received")
  recvBtn:SetScript("OnClick", function()
    if not selected then return end
    local ok, err = EGM.Orders.markReceived(selected)
    if not ok then EGM.Util.print(err) end
  end)
  T.recvBtn = recvBtn
  T.recvTip = explain(recvBtn, "EGMMyOrdersReceivedTip", "Mark Received",
    "Confirm that you received and paid the deliveries of this order. Only needed when you paid a C.O.D. while EGM could not see it (addon off, other client).",
    "Select one of your orders with deliveries in transit.")
  T.cancelTip = explain(cancelBtn, "EGMMyOrdersCancelTip", "Cancel Remaining",
    "Cancel what is not delivered yet. Deliveries already on their way stay valid and can still be paid.",
    "Select one of your open or in-transit orders.")
  cancelBtn:SetScript("OnClick", function()
    if not selected then return end
    local ok, err = EGM.Orders.cancel(selected)
    if not ok then EGM.Util.print(err) end
  end)
  update()
end

function T.refresh() update() end

if EGM.UI and EGM.UI.registerTab then EGM.UI.registerTab(3, T.build, T.refresh, "Bid")
else EGM.PendingTabs = EGM.PendingTabs or {}; table.insert(EGM.PendingTabs, { index = 3, build = T.build, refresh = T.refresh, art = "Bid" }) end
