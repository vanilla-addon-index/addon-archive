-- =========================================================================
-- BananaCraft -- Rezeptkatalog
--
-- Beruf  ->  Stufe / Kategorie  ->  Rezept, mit Tooltips und Qualitaetsfarben.
-- Die Daten liegen in BananaCraft_Catalog.lua (BCRAFT_Catalog, BCRAFT_CraftSpells,
-- BCRAFT_Enchants). Zu jedem Rezept zeigt der Katalog, welche Gildenmitglieder es
-- herstellen koennen (aus der normalen BananaCraft-Datenbank). Die Suche nach
-- dem Namen bleibt: sie durchsucht alle Berufe auf einmal.
--
-- Lua 5.0 (WoW 1.12): kein #, kein %, kein string.match, kein select, kein ...
-- =========================================================================

local tlen = table.getn
local ICONPATH = "Interface\\Icons\\"

-- Qualitaetsfarben (wie im Spiel). 0 = Verzauberung (keine Qualitaet), 6 = Ueberschrift
local QCOL = {
  [0] = "|cffffd200", [1] = "|cffffffff", [2] = "|cff1eff00",
  [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000", [6] = "|cffffd200",
}
local QRGB = {
  [0] = { 1, 0.82, 0 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 },
  [3] = { 0, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 }, [6] = { 1, 0.82, 0 },
}
local function qcol(q) return QCOL[q] or QCOL[1] end
local function qrgb(q) return QRGB[q] or QRGB[1] end

-- Stufen mit Fertigkeitsbereich (nur fuer die Anzeige)
local TIER_RANGE = {
  Apprentice = "1-75", Journeyman = "75-150", Expert = "150-225", Artisan = "225-300",
}

-- kuerzere Anzeigenamen fuer die Berufsliste
local PROF_LABEL = { ["Crafted Epic Weapons"] = "Epic Weapons" }

local ROWS = 15
local ROW_H = 26
local MAX_CATS = 28
local MAX_RESULTS = 400

local S = {
  prof = 1, cat = 1, search = "", offset = 0,
  onlyCrafters = false, onlineOnly = false,
  list = {}, index = {}, gather = {}, tooltipTarget = nil,
}
local f            -- das Fenster
local profBtns, catBtns, rowFrames = {}, {}, {}

local function T(key, fallback)
  return (BCRAFT_L and BCRAFT_L[key]) or fallback or key
end

-- Item-ID, die zu einer Katalogzeile gehoert (fuer den Tooltip), sonst nil
local function itemIdOf(r)
  local kind, id = r[1], r[2]
  if kind == "i" then return id end
  if kind == "s" then
    local sp = BCRAFT_CraftSpells[id]
    if sp and sp[1] and sp[1] ~= 0 then return sp[1] end
  elseif kind == "e" then
    local it = BCRAFT_Enchants[id]
    if it and it ~= 0 then return it end
  end
  return nil
end

local function skillText(r)
  if r[6] == 0 and r[7] == 0 and r[8] == 0 and r[9] == 0 then return "" end
  return string.format("|cffff7f3f%d|r |cffffff00%d|r |cff3fbf3f%d|r |cff7f7f7f%d|r", r[6], r[7], r[8], r[9])
end

-- ------------------------------------------------------------------
-- Hersteller aus der BananaCraft-Datenbank
-- ------------------------------------------------------------------
local function buildIndex()
  S.index = {}
  S.gather = {}
  if BCRAFT_GetRecipeRows then
    local rows = BCRAFT_GetRecipeRows()
    for i = 1, tlen(rows) do
      local rr = rows[i]
      S.index[rr.prof .. ":" .. rr.recipe] = rr
    end
  end
  -- Sammelberufe: Spieler mit Fertigkeitswert
  if BCRAFT_GetGatherers then
    for pi = 1, tlen(BCRAFT_Catalog) do
      local p = BCRAFT_Catalog[pi]
      if p.gather then S.gather[p.db] = BCRAFT_GetGatherers(p.db) end
    end
  end
end

local function crafterCounts(dbProf, name)
  local rr = S.index[dbProf .. ":" .. name]
  if not rr then return 0, 0, nil end
  local on = 0
  for i = 1, tlen(rr.crafters) do
    if rr.crafters[i].online then on = on + 1 end
  end
  return tlen(rr.crafters), on, rr
end

-- Hersteller (Handwerksberufe) bzw. Sammler (Bergbau/Kraeuterkunde) zu einer Zeile.
-- Rueckgabe: gesamt, online, Liste der Personen, Rezeptzeile (nur Handwerk)
local function countsFor(p, r)
  if p.gather then
    local list = S.gather[p.db] or {}
    local req = r[6] or 0
    local total, online = 0, 0
    local matched = {}
    for i = 1, tlen(list) do
      local g = list[i]
      if g.rank >= req then
        total = total + 1
        table.insert(matched, g)
        if g.online then online = online + 1 end
      end
    end
    return total, online, matched, nil
  end
  local total, online, rr = crafterCounts(p.db, r[5])
  return total, online, rr and rr.crafters or nil, rr
end

-- ------------------------------------------------------------------
-- Liste aufbauen
-- ------------------------------------------------------------------
local function passes(p, r)
  if not (S.onlyCrafters or S.onlineOnly) then return true end
  local total, online = countsFor(p, r)
  if S.onlyCrafters and total == 0 then return false end
  if S.onlineOnly and online == 0 then return false end
  return true
end

local function rebuildList()
  local list = {}
  if S.search ~= "" then
    -- Suche nach dem Namen ueber alle Berufe und Kategorien
    local q = string.lower(S.search)
    local seen = {}
    for pi = 1, tlen(BCRAFT_Catalog) do
      local p = BCRAFT_Catalog[pi]
      for ci = 1, tlen(p.cats) do
        local c = p.cats[ci]
        for ri = 1, tlen(c.rows) do
          local r = c.rows[ri]
          if r[1] ~= "h" and string.find(string.lower(r[5]), q, 1, true) then
            local k = r[1] .. r[2] .. p.db
            if not seen[k] and passes(p, r) then
              seen[k] = true
              table.insert(list, { p = p, c = c, r = r })
              if tlen(list) >= MAX_RESULTS then break end
            end
          end
        end
      end
    end
  else
    local p = BCRAFT_Catalog[S.prof]
    local c = p and p.cats[S.cat]
    if c then
      for ri = 1, tlen(c.rows) do
        local r = c.rows[ri]
        if r[1] == "h" or passes(p, r) then
          table.insert(list, { p = p, c = c, r = r })
        end
      end
    end
  end
  S.list = list
end

-- ------------------------------------------------------------------
-- Tooltip
-- ------------------------------------------------------------------
local function ensureCacheTip()
  if not BCRAFT_CacheTip then
    BCRAFT_CacheTip = CreateFrame("GameTooltip", "BCRAFT_CacheTip", nil, "GameTooltipTemplate")
    BCRAFT_CacheTip:SetOwner(UIParent, "ANCHOR_NONE")
  end
  return BCRAFT_CacheTip
end

-- Item vom Server laden lassen (nur auf ausdruecklichen Wunsch, Rechtsklick)
local function queryItem(id)
  local tip = ensureCacheTip()
  tip:SetOwner(UIParent, "ANCHOR_NONE")
  tip:SetHyperlink("item:" .. id .. ":0:0:0")
end

local function showTooltip(row)
  local e = row.entry
  if type(e) ~= "table" then return end
  local r, p = e.r, e.p
  local kind, id = r[1], r[2]
  local itemID = itemIdOf(r)
  local q = r[4]
  local rgb = qrgb(q)

  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")

  local drawn = false
  if itemID and GetItemInfo(itemID) then
    -- Item ist im Cache des Clients: der normale Item-Tooltip
    GameTooltip:SetHyperlink("item:" .. itemID .. ":0:0:0")
    drawn = true
  elseif kind == "e" then
    GameTooltip:SetHyperlink("enchant:" .. id)
    drawn = true
  end
  if not drawn then
    GameTooltip:SetText(r[5], rgb[1], rgb[2], rgb[3])
    if itemID then
      GameTooltip:AddLine(T("CAT_NOCACHE", "Item not in the client cache yet - right-click loads it from the server."), 0.6, 0.6, 0.6, 1)
    end
  end

  -- Zusatzinfos zum Rezept
  GameTooltip:AddLine(" ")
  local sk = skillText(r)
  if sk ~= "" then
    GameTooltip:AddLine(T("CAT_SKILL", "Skill:") .. " " .. sk, 1, 1, 1)
  end
  local sp = (kind == "s") and BCRAFT_CraftSpells[id] or nil
  if sp then
    local rg = sp[6]
    if rg and tlen(rg) > 0 then
      GameTooltip:AddLine(T("CAT_REAGENTS", "Reagents:"), 1, 0.82, 0)
      for i = 1, tlen(rg) do
        local nm = GetItemInfo(rg[i][1])
        GameTooltip:AddLine("  " .. rg[i][2] .. "x " .. (nm or ("Item " .. rg[i][1])), 0.9, 0.9, 0.9)
      end
    end
    if sp[2] and sp[2] > 0 then
      GameTooltip:AddLine(T("CAT_CASTTIME", "Cast time:") .. " " .. sp[2] .. " s", 0.8, 0.8, 0.8)
    end
    if sp[4] and sp[4] ~= "" then
      GameTooltip:AddLine(T("CAT_TOOLS", "Tools:") .. " " .. sp[4], 0.8, 0.8, 0.8)
    end
    if sp[5] and sp[5] ~= "" and not (itemID and GetItemInfo(itemID)) then
      GameTooltip:AddLine(sp[5], 0.7, 1, 0.7, 1)
    end
  end

  -- wer in der Gilde das herstellen bzw. abbauen/ernten kann
  local total, online, people = countsFor(p, r)
  if total > 0 and people then
    GameTooltip:AddLine(" ")
    local fmt = p.gather and T("CAT_GATHERERS_N", "Gatherers: %d (%d online)") or T("CAT_CRAFTERS_N", "Crafters: %d (%d online)")
    GameTooltip:AddLine(string.format(fmt, total, online), 0.3, 1, 0.3)
    local shown = 0
    for i = 1, tlen(people) do
      local cr = people[i]
      if shown < 6 then
        local col = cr.online and "|cff3ddc4a" or "|cff8c8c8c"
        local alt = cr.altOf and (" |cffcc99ff(" .. T("ALT_OF", "Alt of") .. " " .. cr.altOf .. ")|r") or ""
        GameTooltip:AddLine(col .. cr.player .. "|r" .. alt .. " |cffaaaaaa" .. cr.rank .. "/" .. cr.maxRank .. "|r")
        shown = shown + 1
      end
    end
    if tlen(people) > shown then
      GameTooltip:AddLine("... +" .. (tlen(people) - shown), 0.6, 0.6, 0.6)
    end
  else
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(p.gather and T("CAT_GATHERER_NONE", "Nobody known yet.") or T("CAT_CRAFTER_NONE", "No known crafter in the guild"), 0.6, 0.6, 0.6, 1)
  end
  GameTooltip:AddLine(T("CAT_HINT_CLICK", "Click: details and whisper"), 0.5, 0.5, 0.5)
  GameTooltip:Show()
end

-- ------------------------------------------------------------------
-- Materialien aus dem Spielclient lesen (Tooltip "enchant:<id>" listet "Reagents: Name (n), ...")
-- Noetig fuer Verzauberungen (keine Reagenzien in den Katalogdaten) und fuer Itemnamen,
-- die der Client noch nicht kennt.
-- ------------------------------------------------------------------
local scanTip = nil
local reagentCache = {}

local function clientReagents(spellID)
  if reagentCache[spellID] ~= nil then return reagentCache[spellID] or nil end
  if not scanTip then
    scanTip = CreateFrame("GameTooltip", "BCRAFT_ScanTip", nil, "GameTooltipTemplate")
  end
  scanTip:SetOwner(UIParent, "ANCHOR_NONE")
  scanTip:ClearLines()
  local ok = pcall(function() scanTip:SetHyperlink("enchant:" .. spellID) end)
  local result = nil
  if ok then
    local label = SPELL_REAGENTS or "Reagents: "
    for i = 2, scanTip:NumLines() do
      local fs = getglobal("BCRAFT_ScanTipTextLeft" .. i)
      local txt = fs and fs:GetText()
      if txt and string.sub(txt, 1, string.len(label)) == label then
        result = {}
        local list = string.sub(txt, string.len(label) + 1)
        for part in string.gfind(list, "[^,]+") do
          local nm = string.gsub(part, "^%s+", "")
          nm = string.gsub(nm, "%s+$", "")
          local cnt = 1
          local _, _, base, c = string.find(nm, "^(.-)%s*%((%d+)%)$")
          if base then nm = base; cnt = tonumber(c) end
          if nm ~= "" then table.insert(result, { count = cnt, name = nm }) end
        end
        break
      end
    end
  end
  scanTip:Hide()
  -- nur dauerhaft merken, wenn etwas gefunden wurde (Client-Daten koennen spaeter nachladen)
  if result and tlen(result) > 0 then reagentCache[spellID] = result else reagentCache[spellID] = nil; return nil end
  return result
end

-- Materialliste fuer eine Katalogzeile: Katalogdaten, Namen/Fehlendes vom Client ergaenzt
local function reagentsFor(r)
  local kind, id = r[1], r[2]
  local list = {}
  local sp = (kind == "s") and BCRAFT_CraftSpells[id] or nil
  local client = (kind == "s" or kind == "e") and clientReagents(id) or nil
  if sp and sp[6] and tlen(sp[6]) > 0 then
    for i = 1, tlen(sp[6]) do
      local rg = sp[6][i]
      local nm = GetItemInfo(rg[1])
      if not nm and client and tlen(client) == tlen(sp[6]) and client[i] then nm = client[i].name end
      table.insert(list, { count = rg[2], name = nm or ("Item " .. rg[1]) })
    end
  elseif client then
    list = client
  end
  return list
end

-- ------------------------------------------------------------------
-- Rezept-Popup (Materialien, Hersteller, Whisper) fuer eine Katalogzeile
-- ------------------------------------------------------------------
local function openPopup(entry)
  local r, p = entry.r, entry.p
  local total, online, people, rr = countsFor(p, r)
  local sp = (r[1] == "s") and BCRAFT_CraftSpells[r[2]] or nil

  -- gescannte Rezeptdaten (richtige Reagenznamen) bevorzugen
  local rdata = rr and rr.recipeData
  if type(rdata) ~= "table" or not rdata.reagents or tlen(rdata.reagents) == 0 then
    local reagents = reagentsFor(r)
    rdata = {
      name = r[5],
      reagents = reagents,
      itemID = itemIdOf(r),
      icon = ICONPATH .. r[3],
      description = sp and sp[5] ~= "" and sp[5] or nil,
    }
  end

  BCRAFT_ShowRecipePopup({
    recipe = r[5],
    prof = p.db,
    recipeData = rdata,
    crafters = people or {},
    gather = p.gather and true or nil,
  })
  -- Detailfenster exakt rechts neben dem Katalog, bei zu wenig Platz darueber
  if BCRAFT_RecipePopup then BCRAFT_PlaceNextToCatalog(BCRAFT_RecipePopup, false) end
end

-- ------------------------------------------------------------------
-- Anzeige
-- ------------------------------------------------------------------
local function updateRows()
  if not f then return end
  local total = tlen(S.list)
  local maxOff = math.max(0, total - ROWS)
  if S.offset > maxOff then S.offset = maxOff end
  if S.offset < 0 then S.offset = 0 end

  S.settingSlider = true
  f.slider:SetMinMaxValues(0, maxOff)
  f.slider:SetValue(S.offset)
  S.settingSlider = false

  local searching = (S.search ~= "")
  for i = 1, ROWS do
    local row = rowFrames[i]
    local e = S.list[S.offset + i]
    row.entry = nil
    if not e then
      row:Hide()
    else
      local r = e.r
      row:Show()
      -- Fertigkeitswerte und Hersteller-Zahlen stehen nur noch im Tooltip.
      -- In der Suche zeigt die rechte Seite, in welchem Beruf/welcher Kategorie ein Treffer liegt.
      if r[1] == "h" then
        row.icon:Hide()
        row.name:SetWidth(340)
        row.name:SetText("|cffffd200" .. r[5] .. "|r")
        row.skill:SetText("")
      else
        row.entry = e
        row.icon:Show()
        row.icon:SetTexture(ICONPATH .. r[3])
        if searching then
          row.name:SetWidth(190)
          row.name:SetText(qcol(r[4]) .. r[5] .. "|r")
          row.skill:SetText("|cffaaaaaa" .. e.p.key .. " > " .. e.c.name .. "|r")
        else
          row.name:SetWidth(340)
          row.name:SetText(qcol(r[4]) .. r[5] .. "|r")
          row.skill:SetText("")
        end
      end
      row.crafters:SetText("")
    end
  end

  -- Kopfzeile und Trefferzahl
  local p = BCRAFT_Catalog[S.prof]
  local c = p and p.cats[S.cat]
  if searching then
    f.header:SetText(T("CAT_SEARCH_RESULTS", "Search results") .. ": " .. total)
  elseif c then
    local path = (c.name == p.key) and p.key or (p.key .. " > " .. c.name)
    f.header:SetText("|cffffd200" .. path .. "|r  (" .. total .. ")")
  end
end

local function refreshAll()
  if not f then return end
  rebuildList()
  updateRows()
end

local function markSelection()
  for i = 1, tlen(profBtns) do
    local b = profBtns[i]
    if b.index == S.prof and S.search == "" then b.sel:Show() else b.sel:Hide() end
  end
  for i = 1, MAX_CATS do
    local b = catBtns[i]
    if b:IsShown() and b.index == S.cat and S.search == "" then b.sel:Show() else b.sel:Hide() end
  end
end

local function layoutCats()
  local p = BCRAFT_Catalog[S.prof]
  local y = 0
  for i = 1, MAX_CATS do
    local b = catBtns[i]
    local c = p and p.cats[i]
    if c then
      if c.gap then y = y + 8 end
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", f.catPanel, "TOPLEFT", 6, -6 - y)
      y = y + 17
      local nm = c.name
      if TIER_RANGE[nm] then nm = nm .. " |cff999999(" .. TIER_RANGE[nm] .. ")|r" end
      b.text:SetText(nm)
      b.index = i
      b:Show()
    else
      b:Hide()
    end
  end
  markSelection()
end

local function selectProf(i)
  S.prof = i
  S.cat = 1
  S.offset = 0
  if S.search ~= "" then
    S.search = ""
    f.search:SetText("")
  end
  layoutCats()
  refreshAll()
  markSelection()
end

local function selectCat(i)
  S.cat = i
  S.offset = 0
  if S.search ~= "" then
    S.search = ""
    f.search:SetText("")
  end
  refreshAll()
  markSelection()
end

-- ------------------------------------------------------------------
-- Fenster
-- ------------------------------------------------------------------
local function backdrop(frame, small)
  if small then
    frame:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.75)
  else
    frame:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
  end
end

local function checkbox(name, text, x, onClick)
  local cb = CreateFrame("CheckButton", name, f, "UICheckButtonTemplate")
  cb:SetWidth(22)
  cb:SetHeight(22)
  cb:SetPoint("TOPLEFT", f, "TOPLEFT", x, -42)
  getglobal(name .. "Text"):SetText(text)
  cb:SetScript("OnClick", function() onClick(this:GetChecked() and true or false) end)
  return cb
end

local function buildWindow()
  f = CreateFrame("Frame", "BCRAFT_BrowserFrame", UIParent)
  BCRAFT_Browser = f
  f:SetWidth(800)
  f:SetHeight(560)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetFrameStrata("DIALOG")
  backdrop(f, false)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:EnableMouseWheel(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  tinsert(UISpecialFrames, "BCRAFT_BrowserFrame")

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -16)
  title:SetText(T("CAT_TITLE", "BananaCraft - Catalog"))
  f.title = title

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

  -- Sprache (EN / DE) und Einstellungen oben rechts
  local function langButton(code, label, anchorTo, x)
    local b = CreateFrame("Button", nil, f)
    b:SetWidth(22)
    b:SetHeight(16)
    b:SetPoint("RIGHT", anchorTo, "LEFT", x, 0)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetAllPoints(b)
    fs:SetText(label)
    b.fs = fs
    b.code = code
    b:SetScript("OnClick", function()
      BCRAFT_SetLocale(this.code)
      BCRAFT_ApplyLocale()
    end)
    return b
  end

  local gearBtn = CreateFrame("Button", nil, f)
  gearBtn:SetWidth(18)
  gearBtn:SetHeight(18)
  gearBtn:SetPoint("RIGHT", close, "LEFT", -6, 0)
  local gearTex = gearBtn:CreateTexture(nil, "ARTWORK")
  gearTex:SetAllPoints(gearBtn)
  gearTex:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
  gearBtn:SetScript("OnClick", function() BCRAFT_ToggleSettings() end)
  gearBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText(T("GEAR_TOOLTIP", "Settings"))
    GameTooltip:Show()
  end)
  gearBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.deBtn = langButton("deDE", "DE", gearBtn, -8)
  f.enBtn = langButton("enUS", "EN", f.deBtn, -2)

  -- Suche + Filter
  local sl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sl:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -48)
  sl:SetText(T("SEARCH_LABEL", "Search:"))
  f.searchLabel = sl

  local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  search:SetWidth(200)
  search:SetHeight(20)
  search:SetPoint("LEFT", sl, "RIGHT", 10, 0)
  search:SetAutoFocus(false)
  search:SetScript("OnEnterPressed", function() this:ClearFocus() end)
  search:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  search:SetScript("OnEditFocusGained", function()
    BCRAFT_SearchFocused = true
    BCRAFT_ActiveSearchBox = this
  end)
  search:SetScript("OnEditFocusLost", function() BCRAFT_SearchFocused = false end)
  search:SetScript("OnTextChanged", function()
    S.search = this:GetText() or ""
    S.offset = 0
    refreshAll()
    markSelection()
  end)
  f.search = search

  f.cbCrafters = checkbox("BCRAFT_BrowserCBCrafters", T("CAT_ONLY_CRAFTERS", "Only with crafters"), 330, function(on)
    S.onlyCrafters = on
    refreshAll()
  end)
  f.cbOnline = checkbox("BCRAFT_BrowserCBOnline", T("CAT_ONLY_ONLINE", "Only online"), 500, function(on)
    S.onlineOnly = on
    refreshAll()
  end)

  -- Linke Spalte: Berufe
  local profPanel = CreateFrame("Frame", nil, f)
  profPanel:SetWidth(150)
  profPanel:SetHeight(440)
  profPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -76)
  backdrop(profPanel, true)
  f.profPanel = profPanel

  -- Mittlere Spalte: Stufen / Kategorien
  local catPanel = CreateFrame("Frame", nil, f)
  catPanel:SetWidth(196)
  catPanel:SetHeight(440)
  catPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 172, -76)
  backdrop(catPanel, true)
  f.catPanel = catPanel

  -- Rechte Spalte: Rezepte
  local listPanel = CreateFrame("Frame", nil, f)
  listPanel:SetWidth(408)
  listPanel:SetHeight(440)
  listPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 374, -76)
  backdrop(listPanel, true)
  f.listPanel = listPanel

  local header = listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  header:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 10, -8)
  header:SetJustifyH("LEFT")
  f.header = header

  -- Berufsbuttons (Sammelberufe stehen am Ende unter einer eigenen Ueberschrift)
  local py = 6
  local gatherLabelDone = false
  for i = 1, tlen(BCRAFT_Catalog) do
    local p = BCRAFT_Catalog[i]
    if p.gather and not gatherLabelDone then
      gatherLabelDone = true
      py = py + 6
      local gl = profPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      gl:SetPoint("TOPLEFT", profPanel, "TOPLEFT", 10, -py)
      gl:SetTextColor(0.6, 0.6, 0.6)
      f.gatherLabel = gl
      py = py + 14
    end
    local b = CreateFrame("Button", nil, profPanel)
    b:SetWidth(138)
    b:SetHeight(26)
    b:SetPoint("TOPLEFT", profPanel, "TOPLEFT", 6, -py)
    py = py + 27
    b.index = i
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hl:SetBlendMode("ADD")
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints(b)
    b.sel:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    b.sel:Hide()
    local ic = b:CreateTexture(nil, "ARTWORK")
    ic:SetWidth(20)
    ic:SetHeight(20)
    ic:SetPoint("LEFT", b, "LEFT", 4, 0)
    ic:SetTexture(ICONPATH .. p.icon)
    local tx = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tx:SetPoint("LEFT", ic, "RIGHT", 6, 0)
    tx:SetJustifyH("LEFT")
    tx:SetText(PROF_LABEL[p.key] or p.key)
    b:SetScript("OnClick", function() selectProf(this.index) end)
    profBtns[i] = b
  end

  -- Kategoriebuttons (Pool)
  for i = 1, MAX_CATS do
    local b = CreateFrame("Button", nil, catPanel)
    b:SetWidth(184)
    b:SetHeight(17)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hl:SetBlendMode("ADD")
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints(b)
    b.sel:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    b.sel:Hide()
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("LEFT", b, "LEFT", 4, 0)
    b.text:SetJustifyH("LEFT")
    b:SetScript("OnClick", function() selectCat(this.index) end)
    b:Hide()
    catBtns[i] = b
  end

  -- Rezeptzeilen
  for i = 1, ROWS do
    local row = CreateFrame("Button", nil, listPanel)
    row:SetWidth(372)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 6, -28 - (i - 1) * ROW_H)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(row)
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hl:SetBlendMode("ADD")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(22)
    row.icon:SetHeight(22)
    row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetWidth(176)
    row.name:SetJustifyH("LEFT")
    row.skill = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.skill:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
    row.skill:SetWidth(150)
    row.skill:SetJustifyH("LEFT")
    row.crafters = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.crafters:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.crafters:SetWidth(60)
    row.crafters:SetJustifyH("RIGHT")
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnEnter", function() showTooltip(this) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function()
      local e = this.entry
      if type(e) ~= "table" then return end
      if arg1 == "RightButton" then
        local id = itemIdOf(e.r)
        if id then
          queryItem(id)
          GameTooltip:Hide()
        end
      else
        openPopup(e)
      end
    end)
    rowFrames[i] = row
  end

  -- Scrollbalken + Mausrad
  local sb = CreateFrame("Slider", "BCRAFT_BrowserScroll", listPanel)
  sb:SetOrientation("VERTICAL")
  sb:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -6, -26)
  sb:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -6, 8)
  sb:SetWidth(16)
  sb:SetMinMaxValues(0, 0)
  sb:SetValue(0)
  sb:SetValueStep(1)
  sb:SetBackdrop({
    bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  local thumb = sb:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  thumb:SetWidth(16)
  thumb:SetHeight(24)
  sb:SetThumbTexture(thumb)
  sb:SetScript("OnValueChanged", function()
    if S.settingSlider then return end
    S.offset = math.floor(this:GetValue() + 0.5)
    updateRows()
  end)
  f.slider = sb

  local function wheel()
    local delta = arg1
    if type(delta) ~= "number" then return end
    S.offset = S.offset - delta * 3
    updateRows()
  end
  f:SetScript("OnMouseWheel", wheel)
  listPanel:EnableMouseWheel(true)
  listPanel:SetScript("OnMouseWheel", wheel)

  -- Fusszeile: Version, Kurzstatistik, Datenbank teilen
  local foot = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  foot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 16)
  foot:SetTextColor(0.6, 0.6, 0.6)
  f.foot = foot

  local stats = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  stats:SetPoint("BOTTOM", f, "BOTTOM", -60, 16)
  stats:SetTextColor(0.6, 0.6, 0.6)
  f.stats = stats

  local shareBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  shareBtn:SetWidth(240)
  shareBtn:SetHeight(24)
  shareBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -22, 12)
  shareBtn:SetScript("OnClick", function() BCRAFT_ShareDatabase() end)
  f.shareBtn = shareBtn

  -- Daten regelmaessig auffrischen, solange das Fenster offen ist
  f:SetScript("OnShow", function()
    S.tick = 0
    if BCRAFT_CleanupOld then BCRAFT_CleanupOld() end
    buildIndex()
    refreshAll()
    markSelection()
  end)
  f:SetScript("OnUpdate", function()
    S.tick = (S.tick or 0) + arg1
    if S.tick < 4 then return end
    S.tick = 0
    buildIndex()
    updateRows()
  end)

  layoutCats()
  BCRAFT_RelocalizeCatalog()
  f:Hide()
  return f
end

-- ------------------------------------------------------------------
-- Oeffentliche Funktionen
-- ------------------------------------------------------------------
-- Texte nach einem Sprachwechsel neu setzen (und beim Bauen des Fensters)
function BCRAFT_RelocalizeCatalog()
  if not f then return end
  f.title:SetText(T("CAT_TITLE", "BananaCraft - Catalog"))
  f.searchLabel:SetText(T("SEARCH_LABEL", "Search:"))
  getglobal("BCRAFT_BrowserCBCraftersText"):SetText(T("CAT_ONLY_CRAFTERS", "Only with crafters"))
  getglobal("BCRAFT_BrowserCBOnlineText"):SetText(T("CAT_ONLY_ONLINE", "Only online"))
  f.shareBtn:SetText(T("SHARE_BUTTON", "Share database with guild"))
  if f.gatherLabel then f.gatherLabel:SetText(T("CAT_GATHER_HEADER", "Gathering")) end
  f.foot:SetText("v" .. (BCRAFT_VERSION or ""))
  f.stats:SetText(BCRAFT_StatsText and BCRAFT_StatsText() or "")
  local cur = BCRAFT_GetLocale and BCRAFT_GetLocale() or "enUS"
  if f.deBtn and f.deBtn.fs then
    if cur == "deDE" then f.deBtn.fs:SetTextColor(1, 0.82, 0) else f.deBtn.fs:SetTextColor(0.5, 0.5, 0.5) end
  end
  if f.enBtn and f.enBtn.fs then
    if cur == "enUS" then f.enBtn.fs:SetTextColor(1, 0.82, 0) else f.enBtn.fs:SetTextColor(0.5, 0.5, 0.5) end
  end
  if f:IsShown() then refreshAll() end
end

function BCRAFT_ToggleCatalog()
  if not BCRAFT_Catalog or tlen(BCRAFT_Catalog) == 0 then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd200BananaCraft:|r Katalogdaten fehlen (BananaCraft_Catalog.lua).")
    return
  end
  local win = f or buildWindow()
  if win:IsShown() then win:Hide() else win:Show() end
end

-- Fenster neben den Katalog setzen: rechts daneben; wenn dort kein Platz ist
-- (und preferLeft) links daneben; sonst ueber dem Katalog (rechts oben).
function BCRAFT_PlaceNextToCatalog(win, preferLeft)
  if not f or not f:IsShown() or not win then return end
  win:SetFrameStrata("FULLSCREEN_DIALOG")
  local screenW = UIParent:GetRight()
  local fl, fr = f:GetLeft(), f:GetRight()
  local w = win:GetWidth()
  win:ClearAllPoints()
  if type(screenW) ~= "number" or type(fr) ~= "number" or type(fl) ~= "number" or type(w) ~= "number" then
    win:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -70)
    return
  end
  if fr + w + 2 <= screenW then
    win:SetPoint("TOPLEFT", f, "TOPRIGHT", 0, 0)
  elseif preferLeft and fl - w - 2 >= 0 then
    win:SetPoint("TOPRIGHT", f, "TOPLEFT", 0, 0)
  else
    win:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -70)
  end
end

function BCRAFT_RefreshCatalog()
  if f and f:IsShown() then
    buildIndex()
    refreshAll()
    if f.stats then f.stats:SetText(BCRAFT_StatsText and BCRAFT_StatsText() or "") end
  end
end

-- fuer Tests / Diagnose
function BCRAFT_CatalogState() return S end

-- /bc checkmats: prueft, ob jede Rezeptzeile Materialien hat (Enchanting braucht den Client)
function BCRAFT_CheckMaterials()
  local total, withMats, noRecipe = 0, 0, 0
  local missing = {}
  for pi = 1, tlen(BCRAFT_Catalog) do
    local p = BCRAFT_Catalog[pi]
    for ci = 1, tlen(p.cats) do
      local rows = p.cats[ci].rows
      for ri = 1, tlen(rows) do
        local r = rows[ri]
        if r[1] == "s" or r[1] == "e" then
          if not p.gather then
            total = total + 1
            if tlen(reagentsFor(r)) > 0 then withMats = withMats + 1
            else table.insert(missing, p.key .. " > " .. r[5]) end
          end
        elseif r[1] == "i" and not p.gather then
          noRecipe = noRecipe + 1
        end
      end
    end
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cffffff00BananaCraft checkmats:|r " .. withMats .. "/" .. total .. " Rezepte mit Materialien, " .. noRecipe .. " reine Item-Zeilen ohne Rezept.")
  for i = 1, math.min(tlen(missing), 25) do
    DEFAULT_CHAT_FRAME:AddMessage("  |cffff6060ohne Material:|r " .. missing[i])
  end
  if tlen(missing) > 25 then DEFAULT_CHAT_FRAME:AddMessage("  ... +" .. (tlen(missing) - 25)) end
  if BananaCraftDB then BananaCraftDB.matCheck = { total = total, ok = withMats, missing = missing } end
end
