-- Ade Alts: ui_profs
local AA = AdeAlts

-- professions view ----------------------------------------------------
AA.PS = CreateFrame("Frame", nil, AA.P)
AA.PS:SetPoint("TOPLEFT", AA.P, "TOPLEFT", 6, -84)
AA.PS:SetWidth(230)
AA.PS:SetHeight(300)
AA.SkinFrame(AA.PS, 0.5)
AA.PS:Hide()
AA.PS.title = AA.PS:CreateFontString(nil, "OVERLAY", "GameFontNormal")
AA.PS.title:SetPoint("TOPLEFT", AA.PS, "TOPLEFT", 10, -7)
AA.PS.title:SetText("Professions")
AA.PS.empty = AA.PS:CreateFontString(nil, "OVERLAY", "GameFontDisable")
AA.PS.empty:SetPoint("CENTER", AA.PS, "CENTER", 0, 0)
AA.PS.empty:SetWidth(200)
AA.PS.empty:Hide()
AA.PS.rows = {}
for i = 1, 8 do
  local r = CreateFrame("Button", nil, AA.PS)
  r:SetHeight(36)
  r:SetPoint("TOPLEFT", AA.PS, "TOPLEFT", 8, -28 - (i - 1) * 36)
  r:SetPoint("TOPRIGHT", AA.PS, "TOPRIGHT", -8, -28 - (i - 1) * 36)
  r.sel = r:CreateTexture(nil, "BACKGROUND")
  r.sel:SetAllPoints(r)
  r.sel:SetTexture(0.2, 0.5, 0.9, 0.35)
  r.sel:Hide()
  r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 6, -4)
  r.rank = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  r.rank:SetPoint("TOPRIGHT", r, "TOPRIGHT", -6, -4)
  r.rank:SetJustifyH("RIGHT")
  r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
  r:SetScript("OnClick", function()
    AA.profSel = this.prof
    AA.RefreshManager()
  end)
  r:Hide()
  AA.PS.rows[i] = r
end

AA.PR = CreateFrame("Frame", nil, AA.P)
AA.PR:SetPoint("TOPLEFT", AA.P, "TOPLEFT", 242, -84)
AA.PR:SetWidth(304)
AA.PR:SetHeight(300)
AA.SkinFrame(AA.PR, 0.5)
AA.PR:Hide()
AA.PR.title = AA.PR:CreateFontString(nil, "OVERLAY", "GameFontNormal")
AA.PR.title:SetPoint("TOPLEFT", AA.PR, "TOPLEFT", 10, -7)
AA.PR.note = AA.PR:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
AA.PR.note:SetPoint("TOPRIGHT", AA.PR, "TOPRIGHT", -10, -9)
AA.PR.empty = AA.PR:CreateFontString(nil, "OVERLAY", "GameFontDisable")
AA.PR.empty:SetPoint("CENTER", AA.PR, "CENTER", 0, 0)
AA.PR.empty:SetWidth(240)
AA.PR.empty:Hide()

-- mode / sort buttons (second header row)
local function MakeRecBtn(label, field, value, x, w)
  local b = CreateFrame("Button", nil, AA.PR, "UIPanelButtonTemplate")
  b:SetWidth(w)
  b:SetHeight(18)
  b:SetPoint("TOPLEFT", AA.PR, "TOPLEFT", x, -26)
  b:SetText(label)
  b.field, b.value = field, value
  b:SetScript("OnClick", function()
    AA.db[this.field] = this.value
    AA.ResetScroll(AA.PR.sf)
    AA.RefreshManager()
  end)
  return b
end
AA.PR.btns = {
  MakeRecBtn("Known", "recMode", "known", 10, 60),
  MakeRecBtn("Missing", "recMode", "missing", 74, 64),
  MakeRecBtn("Level", "recSort", "level", 160, 54),
  MakeRecBtn("Name", "recSort", "name", 218, 54),
}
AA.PR.sortLabel = AA.PR:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
AA.PR.sortLabel:SetPoint("RIGHT", AA.PR.btns[3], "LEFT", -4, 0)
AA.PR.sortLabel:SetText("Sort:")

AA.recList, AA.recRows = {}, {}
AA.PR.sf = CreateFrame("ScrollFrame", "AdeAltsRecipeScroll", AA.PR, "FauxScrollFrameTemplate")
AA.PR.sf:SetPoint("TOPLEFT", AA.PR, "TOPLEFT", 0, -48)
AA.PR.sf:SetPoint("BOTTOMRIGHT", AA.PR, "BOTTOMRIGHT", -26, 4)
AA.PR.sf:SetScript("OnVerticalScroll", function() FauxScrollFrame_OnVerticalScroll(AA.RROWH, AA.UpdateRecipes) end)
AA.PR:EnableMouseWheel(true)
AA.PR:SetScript("OnMouseWheel", function() AA.ScrollWheel(AA.PR.sf, AA.RROWH) end)

function AA.MakeRecRow()
  local r = CreateFrame("Button", nil, AA.PR)
  r:SetHeight(AA.RROWH - 2)
  r.lvl = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.lvl:SetPoint("LEFT", r, "LEFT", 2, 0)
  r.lvl:SetWidth(34)
  r.lvl:SetJustifyH("LEFT")
  r.src = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  r.src:SetPoint("RIGHT", r, "RIGHT", -2, 0)
  r.src:SetJustifyH("RIGHT")
  r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.text:SetPoint("LEFT", r.lvl, "RIGHT", 2, 0)
  r.text:SetJustifyH("LEFT")
  r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  r:EnableMouseWheel(true)
  r:SetScript("OnMouseWheel", function() AA.ScrollWheel(AA.PR.sf, AA.RROWH) end)
  r:SetScript("OnEnter", function() AA.RecipeTip(this) end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  r:Hide()
  table.insert(AA.recRows, r)
end

AA.UpdateRecipes = function()
  FauxScrollFrame_Update(AA.PR.sf, table.getn(AA.recList), AA.RROWS, AA.RROWH)
  local off = FauxScrollFrame_GetOffset(AA.PR.sf)
  local missing = AA.db and AA.db.recMode == "missing"
  local rank = AA.recRank or 0
  for i = 1, table.getn(AA.recRows) do
    local r = AA.recRows[i]
    local e = nil
    if i <= AA.RROWS then e = AA.recList[off + i] end
    if e then
      r.entry = e
      if e.skill > 0 then
        r.lvl:SetText(AA.RecipeColor(e, rank) .. e.skill .. "|r")
      else
        r.lvl:SetText("|cff808080?|r")
      end
      r.text:SetText(e.name)
      if missing and e.cr then
        r.src:SetText(AA.CraftSource(e.cr))
      else
        r.src:SetText("")
      end
      r:Show()
    else
      r.entry = nil
      r:Hide()
    end
  end
end
