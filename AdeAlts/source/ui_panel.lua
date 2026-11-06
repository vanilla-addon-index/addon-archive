-- Ade Alts: ui_panel
local AA = AdeAlts

-- main panel ----------------------------------------------------------
AA.P = CreateFrame("Frame", nil, AA.M)
AA.P:SetWidth(558)
AA.P:SetHeight(350)
AA.P:SetPoint("TOPLEFT", AA.M, "TOPLEFT", 210, -66)
AA.SkinFrame(AA.P, 0.6)

AA.hIcon = AA.P:CreateTexture(nil, "ARTWORK")
AA.hIcon:SetWidth(36)
AA.hIcon:SetHeight(36)
AA.hIcon:SetPoint("TOPLEFT", AA.P, "TOPLEFT", 10, -8)
AA.hName = AA.P:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
AA.hName:SetPoint("TOPLEFT", AA.hIcon, "TOPRIGHT", 8, -2)
AA.hInfo = AA.P:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
AA.hInfo:SetPoint("TOPLEFT", AA.hName, "BOTTOMLEFT", 0, -3)
AA.hGold = AA.P:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
AA.hGold:SetPoint("TOPRIGHT", AA.P, "TOPRIGHT", -12, -10)
AA.hGold:SetJustifyH("RIGHT")
AA.hAge = AA.P:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
AA.hAge:SetPoint("TOPRIGHT", AA.P, "TOPRIGHT", -12, -28)
AA.hAge:SetJustifyH("RIGHT")
AA.hProf = AA.P:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
AA.hProf:SetPoint("TOPLEFT", AA.hInfo, "BOTTOMLEFT", 0, -3)
AA.hProf:SetJustifyH("LEFT")
AA.hdr = { AA.hIcon, AA.hName, AA.hInfo, AA.hGold, AA.hAge, AA.hProf }

AA.tabs = {}
local function MakeTab(key, label, x)
  local b = CreateFrame("Button", "AdeAltsTab" .. key, AA.P, "UIPanelButtonTemplate")
  b:SetWidth(110)
  b:SetHeight(20)
  b:SetPoint("TOPLEFT", AA.P, "TOPLEFT", x, -58)
  b:SetText(label)
  b.key = key
  b:SetScript("OnClick", function()
    AA.view = this.key
    AA.db.view = AA.view
    AA.RefreshManager()
  end)
  AA.tabs[key] = b
  table.insert(AA.hdr, b)
end
MakeTab("bags", "Bags & Bank", 8)
MakeTab("equip", "Equipment", 122)
MakeTab("profs", "Professions", 236)

local function UpdateGrid(B)
  local n = table.getn(B.list)
  FauxScrollFrame_Update(B.sf, math.ceil(n / AA.COLS), AA.GROWS, AA.CELL)
  local off = FauxScrollFrame_GetOffset(B.sf)
  for r = 1, AA.GROWS do
    for c = 1, AA.COLS do
      local b = B.cells[(r - 1) * AA.COLS + c]
      local e = B.list[(off + r - 1) * AA.COLS + c]
      if b then
        if e then
          b.itemId = e[1]
          b.icon:SetTexture(AA.ItemTex(e[1]))
          if e[2] > 1 then b.count:SetText(tostring(e[2])) else b.count:SetText("") end
          local qr, qg, qb = AA.ItemColor(e[1])
          b:SetBackdropBorderColor(qr, qg, qb, 1)
          b:Show()
        else
          b.itemId = nil
          b:Hide()
        end
      end
    end
  end
end

function AA.AddCell(B)
  local b = CreateFrame("Button", nil, B)
  b:SetWidth(AA.CELL - 2)
  b:SetHeight(AA.CELL - 2)
  b:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  b:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
  b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
  b.box = B
  b:EnableMouseWheel(true)
  b:SetScript("OnMouseWheel", function() AA.ScrollWheel(this.box.sf, AA.CELL) end)
  b:SetScript("OnEnter", function() AA.ItemTip(this) end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:Hide()
  table.insert(B.cells, b)
end

local function MakeBox(ttl, scrollName)
  local B = CreateFrame("Frame", nil, AA.P)
  B:SetWidth(270)
  B:SetHeight(298)
  B:SetPoint("TOPLEFT", AA.P, "TOPLEFT", 6, -84)
  AA.SkinFrame(B, 0.5)
  B.title = B:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  B.title:SetPoint("TOPLEFT", B, "TOPLEFT", 10, -7)
  B.title:SetText(ttl)
  B.note = B:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  B.note:SetPoint("TOPRIGHT", B, "TOPRIGHT", -10, -9)
  B.empty = B:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  B.empty:SetPoint("CENTER", B, "CENTER", 0, 0)
  B.empty:SetWidth(220)
  B.empty:Hide()
  B.ttl = ttl
  B.bagBtns = {}
  B.list = {}
  B.cells = {}
  B.sf = CreateFrame("ScrollFrame", scrollName, B, "FauxScrollFrameTemplate")
  B.sf:SetPoint("TOPLEFT", B, "TOPLEFT", 0, -62)
  B.sf:SetPoint("BOTTOMRIGHT", B, "BOTTOMRIGHT", -26, 4)
  B.sf:SetScript("OnVerticalScroll", function()
    FauxScrollFrame_OnVerticalScroll(AA.CELL, function() UpdateGrid(B) end)
  end)
  B:EnableMouseWheel(true)
  B:SetScript("OnMouseWheel", function() AA.ScrollWheel(this.sf, AA.CELL) end)
  return B
end

AA.BI = MakeBox("Inventory", "AdeAltsInvScroll")
AA.BB = MakeBox("Bank", "AdeAltsBankScroll")

-- one small button per bag: icon with "used/size" underneath
local function MakeBagBtn(B, i)
  local b = CreateFrame("Button", nil, B)
  b:SetWidth(36)
  b:SetHeight(36)
  b:SetPoint("TOPLEFT", B, "TOPLEFT", 6 + (i - 1) * 37, -25)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetWidth(22)
  b.icon:SetHeight(22)
  b.icon:SetPoint("TOP", b, "TOP", 0, 0)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.txt = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.txt:SetPoint("TOP", b.icon, "BOTTOM", 0, -1)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine(this.label or "Bag")
    GameTooltip:AddLine(this.used .. " of " .. this.size .. " slots used (" .. (this.size - this.used) .. " free)", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  B.bagBtns[i] = b
  return b
end

local function FillColor(used, size)
  local f = size > 0 and used / size or 0
  if f >= 0.95 then return "|cffff4040" elseif f >= 0.75 then return "|cffffd100" end
  return "|cff40ff40"
end

-- info: "size:used:bagItemId~..." (nil = not cached); bank: true for the bank box
function AA.ShowBagStrip(B, info, bank)
  local n, tu, ts = 0, 0, 0
  if info and info ~= "" then
    for size, used, id in string.gfind(info, "(%d+):(%d+):(%d+)") do
      n = n + 1
      size, used, id = tonumber(size), tonumber(used), tonumber(id)
      tu, ts = tu + used, ts + size
      local b = B.bagBtns[n] or MakeBagBtn(B, n)
      b.size, b.used = size, used
      if id > 0 then
        b.icon:SetTexture(AA.ItemTex(id))
        b.label = AA.ItemName(id)
      else
        b.icon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
        b.label = bank and "Bank" or "Backpack"
      end
      b.txt:SetText(FillColor(used, size) .. used .. "/" .. size .. "|r")
      b:Show()
    end
  end
  for i = n + 1, table.getn(B.bagBtns) do B.bagBtns[i]:Hide() end
  if n > 0 then
    B.title:SetText(B.ttl .. "  " .. FillColor(tu, ts) .. tu .. "/" .. ts .. "|r")
  else
    B.title:SetText(B.ttl)
  end
end

function AA.SetBoxList(B, list)
  B.list = list or {}
  if B.ctx ~= AA.selKey then      -- only jump to the top when another character is shown
    B.ctx = AA.selKey
    AA.ResetScroll(B.sf)
  end
  UpdateGrid(B)
end

-- search results ------------------------------------------------------
AA.S = CreateFrame("Frame", nil, AA.P)
AA.S:SetWidth(546)
AA.S:SetHeight(338)
AA.S:SetPoint("TOPLEFT", AA.P, "TOPLEFT", 6, -6)
AA.SkinFrame(AA.S, 0.5)
AA.S:Hide()

AA.stitle = AA.S:CreateFontString(nil, "OVERLAY", "GameFontNormal")
AA.stitle:SetPoint("TOPLEFT", AA.S, "TOPLEFT", 10, -8)

AA.resList = {}
AA.resRows = {}
AA.ssf = CreateFrame("ScrollFrame", "AdeAltsSearchScroll", AA.S, "FauxScrollFrameTemplate")
AA.ssf:SetPoint("TOPLEFT", AA.S, "TOPLEFT", 0, -26)
AA.ssf:SetPoint("BOTTOMRIGHT", AA.S, "BOTTOMRIGHT", -26, 4)
AA.ssf:SetScript("OnVerticalScroll", function() FauxScrollFrame_OnVerticalScroll(AA.SROWH, AA.UpdateResults) end)
AA.S:EnableMouseWheel(true)
AA.S:SetScript("OnMouseWheel", function() AA.ScrollWheel(AA.ssf, AA.SROWH) end)

function AA.MakeResRow()
  local r = CreateFrame("Button", nil, AA.S)
  r:SetHeight(AA.SROWH - 2)
  r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetWidth(18)
  r.icon:SetHeight(18)
  r.icon:SetPoint("LEFT", r, "LEFT", 2, 0)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
  r.name:SetJustifyH("LEFT")
  r.cnt = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.cnt:SetWidth(50)
  r.cnt:SetJustifyH("RIGHT")
  r.who = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  r.who:SetWidth(130)
  r.who:SetJustifyH("LEFT")
  r.where = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  r.where:SetWidth(90)
  r.where:SetJustifyH("LEFT")
  r:EnableMouseWheel(true)
  r:SetScript("OnMouseWheel", function() AA.ScrollWheel(AA.ssf, AA.SROWH) end)
  r:SetScript("OnEnter", function() AA.ItemTip(this) end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  r:Hide()
  table.insert(AA.resRows, r)
end

AA.UpdateResults = function()
  FauxScrollFrame_Update(AA.ssf, table.getn(AA.resList), AA.SROWS, AA.SROWH)
  local off = FauxScrollFrame_GetOffset(AA.ssf)
  for i = 1, AA.SROWS do
    local r = AA.resRows[i]
    local e = AA.resList[off + i]
    if r then
      if e and e.recipe then
        r.itemId = nil
        r.icon:SetTexture("Interface\\Icons\\INV_Scroll_03")
        r.name:SetText(e.name)
        r.name:SetTextColor(0.4, 0.8, 1)
        r.cnt:SetText("recipe")
        r.who:SetText("|cff" .. AA.ClassHex(e.char.class) .. e.char.name .. "|r")
        r.where:SetText(e.where)
        r:Show()
      elseif e then
        r.itemId = e.id
        r.icon:SetTexture(AA.ItemTex(e.id))
        r.name:SetText(e.name)
        r.name:SetTextColor(AA.ItemColor(e.id))
        r.cnt:SetText("x" .. e.n)
        r.who:SetText("|cff" .. AA.ClassHex(e.char.class) .. e.char.name .. "|r")
        r.where:SetText(e.where)
        r:Show()
      else
        r.itemId = nil
        r:Hide()
      end
    end
  end
end

