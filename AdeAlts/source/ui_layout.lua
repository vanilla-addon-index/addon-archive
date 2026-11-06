-- Ade Alts: ui_layout
local AA = AdeAlts


-- layout: everything follows the configured window width / height --------------------------
function AA.Layout()
  local W = (AA.db and AA.db.width) or AA.DEF_W
  local H = (AA.db and AA.db.height) or AA.DEF_H
  if W < 640 then W = 640 end
  if H < 420 then H = 420 end
  AA.M:SetWidth(W)
  AA.M:SetHeight(H)
  local ph = H - 100
  local pw = W - 222
  AA.L:SetHeight(ph)
  AA.P:SetWidth(pw)
  AA.P:SetHeight(ph)

  -- alt list
  AA.LROWS = math.max(1, math.floor((ph - 40) / AA.ROWH))
  while table.getn(AA.altRows) < AA.LROWS do AA.MakeAltRow() end
  for i, r in ipairs(AA.altRows) do
    r:Hide()
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", AA.L, "TOPLEFT", 8, -36 - (i - 1) * AA.ROWH)
  end

  -- inventory / bank boxes and their item grids
  local bw = math.floor((pw - 18) / 2)
  local bh = ph - 90
  AA.COLS = math.max(1, math.floor((bw - 37) / AA.CELL))
  AA.GROWS = math.max(1, math.floor((bh - 68) / AA.CELL))
  AA.BI:SetWidth(bw)
  AA.BI:SetHeight(bh)
  AA.BB:SetWidth(bw)
  AA.BB:SetHeight(bh)
  AA.BB:ClearAllPoints()
  AA.BB:SetPoint("TOPLEFT", AA.P, "TOPLEFT", 12 + bw, -84)
  local boxes = { AA.BI, AA.BB }
  for _, B in ipairs(boxes) do
    while table.getn(B.cells) < AA.COLS * AA.GROWS do AA.AddCell(B) end
    for i, b in ipairs(B.cells) do
      b:Hide()
      b:ClearAllPoints()
      local r = math.floor((i - 1) / AA.COLS)
      local c = math.mod(i - 1, AA.COLS)
      b:SetPoint("TOPLEFT", B, "TOPLEFT", 9 + c * AA.CELL, -66 - r * AA.CELL)
    end
  end

  -- equipment view
  AA.LayoutEquip(pw - 12, bh)

  -- professions view
  local psw = 230
  local prw = pw - 12 - psw - 6
  AA.PS:SetWidth(psw)
  AA.PS:SetHeight(bh)
  AA.PR:SetWidth(prw)
  AA.PR:SetHeight(bh)
  AA.PR:ClearAllPoints()
  AA.PR:SetPoint("TOPLEFT", AA.P, "TOPLEFT", 12 + psw, -84)
  AA.RROWS = math.max(1, math.floor((bh - 56) / AA.RROWH))
  while table.getn(AA.recRows) < AA.RROWS do AA.MakeRecRow() end
  for i, r in ipairs(AA.recRows) do
    r:Hide()
    r:SetWidth(prw - 36)
    r.src:SetWidth(math.floor((prw - 36) * 0.38))
    r.text:SetWidth(prw - 36 - 40 - math.floor((prw - 36) * 0.38))
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", AA.PR, "TOPLEFT", 10, -50 - (i - 1) * AA.RROWH)
  end

  -- search results
  local sw, sh = pw - 12, ph - 12
  AA.S:SetWidth(sw)
  AA.S:SetHeight(sh)
  AA.SROWS = math.max(1, math.floor((sh - 36) / AA.SROWH))
  while table.getn(AA.resRows) < AA.SROWS do AA.MakeResRow() end
  local rowW = sw - 40
  local nameW = rowW - 322
  if nameW < 120 then nameW = 120 end
  for i, r in ipairs(AA.resRows) do
    r:Hide()
    r:SetWidth(rowW)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", AA.S, "TOPLEFT", 8, -30 - (i - 1) * AA.SROWH)
    r.name:SetWidth(nameW)
    r.cnt:ClearAllPoints()
    r.cnt:SetPoint("LEFT", r, "LEFT", 32 + nameW, 0)
    r.who:ClearAllPoints()
    r.who:SetPoint("LEFT", r, "LEFT", 96 + nameW, 0)
    r.where:ClearAllPoints()
    r.where:SetPoint("LEFT", r, "LEFT", 230 + nameW, 0)
  end

  AA.RefreshManager()
end
