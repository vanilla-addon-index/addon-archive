-- Ade Alts: ui_show
local AA = AdeAlts

local function ShowSearch(q)
  for _, o in ipairs(AA.hdr) do o:Hide() end
  AA.BI:Hide()
  AA.BB:Hide()
  AA.EQ:Hide()
  AA.PS:Hide()
  AA.PR:Hide()
  AA.resList = {}
  local total, chars = 0, {}
  for _, k in ipairs(AA.SortedAlts()) do
    local c = AA.db.chars[k]
    for w = 1, 2 do
      local list = c.inv
      if w == 2 then list = c.bank end
      if list then
        for _, e in ipairs(list) do
          local nm = AA.ItemName(e[1])
          if string.find(string.lower(nm), q, 1, true) then
            local where = "Bags"
            if w == 2 then where = "Bank" end
            table.insert(AA.resList, { id = e[1], n = e[2], name = nm, char = c, where = where })
            total = total + e[2]
            chars[k] = true
          end
        end
      end
    end
    if c.prof then
      for pname, pr in pairs(c.prof) do
        if pr.rec then
          for _, rn in ipairs(pr.rec) do
            if string.find(string.lower(rn), q, 1, true) then
              table.insert(AA.resList, { recipe = true, n = 0, name = rn, char = c, where = pname })
              chars[k] = true
            end
          end
        end
      end
    end
  end
  table.sort(AA.resList, function(a, b)
    if a.name ~= b.name then return a.name < b.name end
    if a.char.name ~= b.char.name then return a.char.name < b.char.name end
    return a.where < b.where
  end)
  local nc = 0
  for k in pairs(chars) do nc = nc + 1 end
  if table.getn(AA.resList) == 0 then
    AA.stitle:SetText("No items matching \"" .. q .. "\" in cached bags / banks.")
  else
    AA.stitle:SetText(table.getn(AA.resList) .. " stack group(s), " .. total .. " item(s) on " .. nc .. " alt(s)   |cff808080(item   count   alt   location)|r")
  end
  if AA.sctx ~= q then
    AA.sctx = q
    AA.ResetScroll(AA.ssf)
  end
  AA.UpdateResults()
  AA.S:Show()
end

local function ProfSummary(c)
  if not c.prof then return "|cff808080professions: not scanned yet|r" end
  local list = {}
  for name, pr in pairs(c.prof) do table.insert(list, { name = name, r = pr.r or 0, m = pr.m or 0 }) end
  if table.getn(list) == 0 then return "|cff808080no professions|r" end
  table.sort(list, function(a, b)
    if a.r ~= b.r then return a.r > b.r end
    return a.name < b.name
  end)
  local parts = {}
  for _, e in ipairs(list) do
    local col = "ffd100"
    if e.m > 0 and e.r >= e.m then col = "40ff40" end
    table.insert(parts, "|cffb0b0b0" .. e.name .. "|r |cff" .. col .. e.r .. "|r")
  end
  return table.concat(parts, "    ")
end

local function ShowBags(c)
  AA.BI:Show()
  AA.BB:Show()
  AA.BI.empty:Hide()
  AA.SetBoxList(AA.BI, c.inv)
  AA.ShowBagStrip(AA.BI, c.invBags, false)
  if c.invTs and c.invTs > 0 then
    AA.BI.note:SetText("updated " .. AA.Ago(c.invTs))
  else
    AA.BI.note:SetText("")
    AA.BI.empty:SetText("Not cached yet.\nLog in on this character once.")
    AA.BI.empty:Show()
  end

  AA.BB.empty:Hide()
  if c.bankTs and c.bankTs > 0 then
    AA.SetBoxList(AA.BB, c.bank)
    AA.ShowBagStrip(AA.BB, c.bankBags, true)
    AA.BB.note:SetText("updated " .. AA.Ago(c.bankTs))
  else
    AA.SetBoxList(AA.BB, {})
    AA.ShowBagStrip(AA.BB, nil, true)
    AA.BB.note:SetText("")
    AA.BB.empty:SetText("Bank not cached yet.\nOpen the bank on this character once.")
    AA.BB.empty:Show()
  end
end

local function ShowEquip(c)
  AA.EQ:Show()
  if c.eqTs and c.eqTs > 0 then
    AA.EQ.note:SetText("updated " .. AA.Ago(c.eqTs))
    AA.EQ.empty:Hide()
  else
    AA.EQ.note:SetText("")
    AA.EQ.empty:SetText("Equipment not cached yet.\nLog in on this character once.")
    AA.EQ.empty:Show()
  end
  for i, b in ipairs(AA.EQ.cells) do
    local ref = c.equip and c.equip[b.slotId]
    if ref then
      local _, _, sid = string.find(ref, "^(%d+)")
      local id = tonumber(sid)
      b.itemStr = ref
      b.itemId = id
      b.icon:SetTexture(AA.ItemTex(id))
      b.name:SetText(AA.ItemName(id))
      local qr, qg, qb = AA.ItemColor(id)
      b.name:SetTextColor(qr, qg, qb)
      b.slot:SetText(b.slotName)
      b.frame:SetBackdropBorderColor(qr, qg, qb, 1)
    else
      b.itemStr = nil
      b.itemId = nil
      b.icon:SetTexture("Interface\\Buttons\\UI-EmptySlot")
      b.name:SetText(b.slotName)
      b.name:SetTextColor(0.45, 0.45, 0.45)
      b.slot:SetText("")
      b.frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end
  end
end

local function ShowProfs(c)
  AA.PS:Show()
  AA.PR:Show()
  local names = {}
  if c.prof then
    for name in pairs(c.prof) do table.insert(names, name) end
  end
  table.sort(names)
  local found = false
  for _, n in ipairs(names) do if n == AA.profSel then found = true end end
  if not found then AA.profSel = names[1] end
  if table.getn(names) == 0 then
    AA.PS.empty:SetText("No professions cached yet.\nLog in on this character once.")
    AA.PS.empty:Show()
  else
    AA.PS.empty:Hide()
  end
  for i = 1, 8 do
    local r = AA.PS.rows[i]
    local name = names[i]
    if name then
      local pr = c.prof[name]
      r.prof = name
      r.name:SetText(name)
      local rank, mx = pr.r or 0, pr.m or 0
      if mx > 0 and rank >= mx then
        r.rank:SetText("|cff40ff40" .. rank .. " / " .. mx .. "|r")
      else
        r.rank:SetText("|cffffd100" .. rank .. " / " .. mx .. "|r")
      end
      if AA.NORECIPES[name] then
        r.sub:SetText("")
      elseif pr.rec and table.getn(pr.rec) > 0 then
        local kn, ms = AA.RecipeCounts(c, name)
        if ms then
          r.sub:SetText(kn .. " known, |cffff8040" .. ms .. " missing|r")
        else
          r.sub:SetText(kn .. " recipes known")
        end
      else
        r.sub:SetText("recipes not scanned yet")
      end
      if name == AA.profSel then r.sel:Show() else r.sel:Hide() end
      r:Show()
    else
      r:Hide()
    end
  end
  local pr = AA.profSel and c.prof and c.prof[AA.profSel]
  local mode = (AA.db.recMode == "missing") and "missing" or "known"
  local sort = (AA.db.recSort == "name") and "name" or "level"
  AA.recRank = (pr and pr.r) or 0
  AA.recList = {}
  for _, bt in ipairs(AA.PR.btns) do
    local cur = (bt.field == "recMode" and mode) or sort
    if bt.value == cur then bt:Disable() else bt:Enable() end
  end
  if AA.profSel then
    AA.PR.title:SetText((mode == "missing" and "Missing recipes: " or "Known recipes: ") .. AA.profSel)
  else
    AA.PR.title:SetText("Recipes")
  end
  if AA.profSel and AA.NORECIPES[AA.profSel] then
    AA.PR.note:SetText("")
    AA.PR.empty:SetText("|cff808080" .. AA.profSel .. " has no recipes to track.|r")
    AA.PR.empty:Show()
  elseif pr and pr.rts and pr.rts > 0 then
    AA.recList = AA.RecipeList(c, AA.profSel, mode, sort)
    if mode == "missing" and not AA.RDATA[AA.profSel] then
      AA.PR.note:SetText("")
      AA.PR.empty:SetText("|cff808080No recipe database for " .. AA.profSel .. ".|r")
      AA.PR.empty:Show()
    else
      AA.PR.note:SetText(table.getn(AA.recList) .. (mode == "missing" and " missing" or " known") .. ", updated " .. AA.Ago(pr.rts))
      if table.getn(AA.recList) == 0 then
        AA.PR.empty:SetText(mode == "missing" and "|cff40ff40Nothing missing!|r" or "")
        AA.PR.empty:Show()
      else
        AA.PR.empty:Hide()
      end
    end
  else
    AA.PR.note:SetText("")
    if AA.profSel then
      AA.PR.empty:SetText("Recipes not scanned yet.\nOpen the " .. AA.profSel .. " window on " .. c.name .. " once\n(clear its filters first).")
    else
      AA.PR.empty:SetText("")
    end
    AA.PR.empty:Show()
  end
  local ctx = tostring(AA.selKey) .. "|" .. tostring(AA.profSel) .. "|" .. mode .. "|" .. sort
  if AA.recCtx ~= ctx then        -- periodic refreshes must not throw the list back to the top
    AA.recCtx = ctx
    AA.ResetScroll(AA.PR.sf)
  end
  AA.UpdateRecipes()
end

local function ShowChar()
  AA.S:Hide()
  for _, o in ipairs(AA.hdr) do o:Show() end
  AA.BI:Hide()
  AA.BB:Hide()
  AA.EQ:Hide()
  AA.PS:Hide()
  AA.PR:Hide()
  local c = AA.db.chars[AA.selKey]
  if not c then return end
  AA.view = AA.db.view or "bags"
  for k, tb in pairs(AA.tabs) do
    if k == AA.view then tb:Disable() else tb:Enable() end
  end
  AA.SetClassTex(AA.hIcon, c.class)
  AA.hName:SetText("|cff" .. AA.ClassHex(c.class) .. c.name .. "|r")
  local lv = "?"
  if c.level and c.level > 0 then lv = c.level end
  AA.hInfo:SetText("Level " .. lv .. " " .. AA.ClassName(c.class) .. "   |cff808080" .. c.realm .. "|r")
  AA.hProf:SetText(ProfSummary(c))
  AA.hGold:SetText(AA.Money(c.gold))
  AA.hAge:SetText("character data: " .. AA.Ago(c.dataTs))
  if AA.view == "equip" then
    ShowEquip(c)
  elseif AA.view == "profs" then
    ShowProfs(c)
  else
    ShowBags(c)
  end
end

local footer = AA.M:CreateFontString(nil, "OVERLAY", "GameFontNormal")
footer:SetPoint("BOTTOMLEFT", AA.M, "BOTTOMLEFT", 16, 14)
local fstat = AA.M:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
fstat:SetPoint("BOTTOMRIGHT", AA.M, "BOTTOMRIGHT", -16, 14)

AA.RefreshManager = function()
  if not AA.db or not AA.M:IsVisible() then return end
  if not AA.selKey or not AA.db.chars[AA.selKey] then AA.selKey = AA.myKey end
  if not AA.selKey or not AA.db.chars[AA.selKey] then
    for k in pairs(AA.db.chars) do AA.selKey = k break end
  end
  local tot, n = 0, 0
  for k, c in pairs(AA.db.chars) do
    tot = tot + (c.gold or 0)
    n = n + 1
  end
  footer:SetText("Total gold of " .. n .. " alts:  " .. AA.Money(tot))
  if ImportFile and ExportFile then
    fstat:SetText("SuperWoW file sync: |cff40ff40on|r")
  else
    fstat:SetText("SuperWoW file sync: |cffff6060off|r (data of other accounts will not update)")
  end
  AA.UpdateAltList()
  local q = string.lower(AA.sbox:GetText() or "")
  q = string.gsub(q, "^%s+", "")
  q = string.gsub(q, "%s+$", "")
  if string.len(q) >= 2 then ShowSearch(q) else ShowChar() end
end

AA.sbox:SetScript("OnEscapePressed", function()
  if this:GetText() ~= "" then this:SetText("") else this:ClearFocus() end
end)
AA.sbox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
AA.sbox:SetScript("OnTextChanged", function() AA.RefreshManager() end)

AA.M:SetScript("OnShow", function()
  if AA.FileMerge then AA.FileMerge() end
  AA.RefreshManager()
end)
