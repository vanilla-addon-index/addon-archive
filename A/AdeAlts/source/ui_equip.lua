-- Ade Alts: ui_equip (equipped gear: 3 columns of 6 / 6 / 5 slots)
local AA = AdeAlts

-- inventory slot id, label, column, row
local EQSLOTS = {
  { 1,  "Head",      1, 0 }, { 2,  "Neck",      1, 1 }, { 3,  "Shoulders", 1, 2 },
  { 15, "Back",      1, 3 }, { 5,  "Chest",     1, 4 }, { 9,  "Wrists",    1, 5 },
  { 10, "Hands",     2, 0 }, { 6,  "Waist",     2, 1 }, { 7,  "Legs",      2, 2 },
  { 8,  "Feet",      2, 3 }, { 11, "Ring 1",    2, 4 }, { 12, "Ring 2",    2, 5 },
  { 13, "Trinket 1", 3, 0 }, { 14, "Trinket 2", 3, 1 }, { 16, "Main hand", 3, 2 },
  { 17, "Off hand",  3, 3 }, { 18, "Ranged",    3, 4 },
}

AA.EQ = CreateFrame("Frame", nil, AA.P)
AA.EQ:SetPoint("TOPLEFT", AA.P, "TOPLEFT", 6, -84)
AA.EQ:SetWidth(546)
AA.EQ:SetHeight(300)
AA.SkinFrame(AA.EQ, 0.5)
AA.EQ:Hide()
AA.EQ.title = AA.EQ:CreateFontString(nil, "OVERLAY", "GameFontNormal")
AA.EQ.title:SetPoint("TOPLEFT", AA.EQ, "TOPLEFT", 10, -7)
AA.EQ.title:SetText("Equipped gear")
AA.EQ.note = AA.EQ:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
AA.EQ.note:SetPoint("TOPRIGHT", AA.EQ, "TOPRIGHT", -10, -9)
AA.EQ.empty = AA.EQ:CreateFontString(nil, "OVERLAY", "GameFontDisable")
AA.EQ.empty:SetPoint("CENTER", AA.EQ, "CENTER", 0, 0)
AA.EQ.empty:Hide()

AA.EQ.cells = {}
for i, def in ipairs(EQSLOTS) do
  local b = CreateFrame("Button", nil, AA.EQ)
  b.slotId = def[1]
  b.slotName = def[2]
  b.col = def[3]
  b.row = def[4]
  -- icon with a quality coloured border
  b.frame = CreateFrame("Frame", nil, b)
  b.frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  b.frame:SetBackdropColor(0.04, 0.04, 0.04, 0.85)
  b.frame:SetPoint("LEFT", b, "LEFT", 0, 0)
  b.icon = b.frame:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", b.frame, "TOPLEFT", 3, -3)
  b.icon:SetPoint("BOTTOMRIGHT", b.frame, "BOTTOMRIGHT", -3, 3)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  b.name:SetPoint("TOPLEFT", b.frame, "TOPRIGHT", 8, -3)
  b.name:SetJustifyH("LEFT")
  b.slot = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  b.slot:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -2)
  b.slot:SetJustifyH("LEFT")
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
  b:SetScript("OnEnter", function() AA.ItemTip(this) end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  AA.EQ.cells[i] = b
end

-- positions the slots for a box of the given size
function AA.LayoutEquip(W, H)
  local EQ = AA.EQ
  EQ:SetWidth(W)
  EQ:SetHeight(H)
  local colW = math.floor((W - 20 - 2 * 8) / 3)
  local rh = math.floor((H - 40) / 6)
  if rh > 52 then rh = 52 end
  if rh < 30 then rh = 30 end
  local isz = rh - 8
  for _, b in ipairs(EQ.cells) do
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", EQ, "TOPLEFT", 10 + (b.col - 1) * (colW + 8), -34 - b.row * rh)
    b:SetWidth(colW)
    b:SetHeight(rh - 4)
    b.frame:SetWidth(isz)
    b.frame:SetHeight(isz)
    b.name:SetWidth(colW - isz - 12)
    b.slot:SetWidth(colW - isz - 12)
  end
end
