-- Options window: General, Leveling, Weights, Talents. Settings are saved; the weights page
-- and the talents page show demo content in this prototype.

local AG = AdeGear
local Opt = {}
AG.Options = Opt

local WIDTH, HEIGHT = 430, 580
local INNER = WIDTH - 32
local TABS = { "General", "Leveling", "Weights", "Talents" }

local syncList = {}   -- widgets that follow config values

local function Track(widget)
  table.insert(syncList, widget)
  return widget
end

function Opt.Sync()
  for i = 1, table.getn(syncList) do
    if syncList[i].Sync then syncList[i]:Sync() end
  end
  if Opt.current == 3 and Opt.RefreshWeights then Opt.RefreshWeights() elseif Opt.current == 4 and Opt.RefreshTalents then Opt.RefreshTalents() end
  if Opt.damageSlider then
    if AG.Get("playstyle") == 1 then Opt.damageSlider:SetAlpha(1) else Opt.damageSlider:SetAlpha(0.4) end
  end
  if Opt.choices then
    for i = 1, table.getn(Opt.choices) do
      local c = Opt.choices[i]
      local cur = AG.Get(c.key)
      c.button:SetActive(cur == c.value)
    end
  end
end

-- a row of buttons where exactly one value of a config key is chosen
local function Choice(parent, key, labels, width, values)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetWidth(INNER)
  holder:SetHeight(22)
  Opt.choices = Opt.choices or {}
  local x = 0
  for i = 1, table.getn(labels) do
    local b = AG.W.Button(holder, labels[i], width, 22, nil)
    b:SetPoint("TOPLEFT", holder, "TOPLEFT", x, 0)
    local value = i
    if values then value = values[i] end
    b.onclick = function() AG.Set(key, value) end
    table.insert(Opt.choices, { key = key, value = value, button = b })
    x = x + width + 4
  end
  return holder
end

-- simple top-to-bottom placement inside a page
local function Stack(page)
  local s = { page = page, y = 12 }
  s.add = function(self, widget, height, indent)
    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT", self.page, "TOPLEFT", 14 + (indent or 0), -self.y)
    self.y = self.y + height
  end
  return s
end

local function Note(parent, text, color)
  local fs = AG.W.Text(parent, 11, color or AG.C.dim)
  fs:SetWidth(INNER)
  fs:SetText(text)
  return fs
end

----------------------------------------------------------------------
-- Pages
----------------------------------------------------------------------

local function BuildGeneral(page)
  local s = Stack(page)
  s:add(Track(AG.W.Check(page, "Show the comparison when hovering items", "enabled", INNER)), 26)
  s:add(Track(AG.W.Check(page, "Show the tooltip of the equipped item next to it", "showEquipped", INNER)), 26)
  s:add(Track(AG.W.Check(page, "Only compare while Shift is held", "shiftOnly", INNER)), 26)
  s:add(Track(AG.W.Check(page, "Upgrade arrows on item icons (bags, vendors)", "arrows", INNER)), 26)
  s:add(Track(AG.W.Check(page, "GearScore on item and player tooltips and the character window", "gearscore", INNER)), 26)
  s:add(Track(AG.W.Check(page, "Minimap button", "minimap", INNER)), 26)
  local lookLabel = AG.W.Text(page, 12, AG.C.gold)
  lookLabel:SetText("Window look (/reload applies)")
  s:add(lookLabel, 18)
  s:add(Choice(page, "look", { "Auto", "pfUI", "Vanilla" }, 90, { "auto", "pfui", "blizzard" }), 34)

  local label = AG.W.Text(page, 12, AG.C.gold)
  label:SetText("Detail level")
  s:add(label, 18)
  s:add(Choice(page, "detail", { "Compact", "Normal", "Detailed" }, 90), 36)

  local roleLabel = AG.W.Text(page, 12, AG.C.gold)
  roleLabel:SetText("Role")
  s:add(roleLabel, 18)
  s:add(Choice(page, "role", { "Auto", "Tank", "Healer", "Damage" }, 90, { "auto", "tank", "heal", "dmg" }), 30)

  local mode = AG.W.Text(page, 12, AG.C.gold)
  mode:SetText("How do you play?")
  s:add(mode, 18)
  s:add(Choice(page, "playstyle", { "Solo", "Party", "Raids" }, 90), 30)
  Opt.damageSlider = Track(AG.W.Slider(page, "Damage share while soloing", "damageShare", 0, 60, 5, INNER - 10, "%"))
  s:add(Opt.damageSlider, 40)
  s:add(Note(page, "Solo: tanks and healers also count damage, so they can kill things while leveling. Party and Raids: the addon works out your role from your talents and values it fully, with no damage share. Raids also count level 63 bosses: hit and defense caps, more value for weapon skill, and for healers more value for mana regen."), 52)
end

local function BuildLeveling(page)
  local s = Stack(page)
  s:add(Track(AG.W.Check(page, "Tanks and healers also count damage while soloing", "leveling", INNER)), 28)
  s:add(Track(AG.W.Slider(page, "Damage share is gone at level", "fadeLevel", 40, 60, 5, INNER - 10, "")), 42)
  s:add(Track(AG.W.Check(page, "Casters count wand dps while soloing", "wand", INNER)), 28)
  s:add(Note(page, "The damage share is set on the General tab. It fades out linearly until the level chosen here, so at level 60 a healer is judged as a healer only."), 44)
end

----------------------------------------------------------------------
-- Weights tab: what the addon calculated for you, and your own values on top
----------------------------------------------------------------------

local W_ROWS, W_H = 12, 24
local wState = { list = {}, offset = 0 }

local function NumText(v)
  if v == nil then return "" end
  local a = math.abs(v)
  if a >= 10 then return string.format("%.1f", v) end
  if a >= 1 then return string.format("%.2f", v) end
  return string.format("%.3f", v)
end

local function ManualTable(class, create)
  if not AdeGearDB then return nil end
  if create then
    AdeGearDB.manual = AdeGearDB.manual or {}
    AdeGearDB.manual[class] = AdeGearDB.manual[class] or {}
  end
  return AdeGearDB.manual and AdeGearDB.manual[class]
end

-- what to show in the TALENT EFFECT column: the talent and rank of a note like "Toughness 3/5: armor from items +6%",
-- or, for notes that are not talents ("Agility: 1 crit% per 20 at your level"), the text after the colon, dimmed
local function ShortWhy(notes)
  if not notes then return "", false end
  for i = 1, table.getn(notes) do
    local s, e, name, rank = string.find(notes[i], "^(.-) (%d+/%d+): ")
    if s then return name .. " " .. rank, true end
  end
  local text = notes[1]
  if string.find(text, "^set by you") then return "set by you", false end
  local s, e = string.find(text, ": ", 1, true)
  if s then text = string.sub(text, e + 1) end
  return text, false
end

local function ChangedByUser()
  if AG.Compare and AG.Compare.Flush then AG.Compare.Flush() end
  if AG.Arrows and AG.Arrows.Touch then AG.Arrows.Touch() end
  if AG.Inspect and AG.Inspect.Hide then AG.Inspect.Hide() end
end

local function CountManual(class)
  local m = ManualTable(class)
  local n = 0
  if m then for k, v in pairs(m) do n = n + 1 end end
  return n
end

function Opt.RefreshWeights()
  local page = Opt.pages and Opt.pages[3]
  if not page or not page.rowsBuilt then return end
  local w, c = AG.Weights.ForPlayer(true)
  wState.list = {}
  if not w or not c then
    page.head:SetText("No stat values for this character yet")
    wState.class = nil
  else
    wState.class = c.class
    local m = ManualTable(c.class)
    local order = {}
    for i = 1, table.getn(w.order or {}) do table.insert(order, w.order[i]) end
    for k, v in pairs(w.weights) do
      if string.find(k, "^SKILL_") and v ~= 0 then table.insert(order, k) end
    end
    for i = 1, table.getn(order) do
      local k = order[i]
      local text, isTalent = ShortWhy(w.why[k])
      table.insert(wState.list, { key = k, auto = w.weights[k] or 0, why = text, talent = isTalent, manual = m and m[k] })
    end
    local cls = string.upper(string.sub(c.class, 1, 1)) .. string.lower(string.sub(c.class, 2))
    local n = CountManual(c.class)
    local text = cls .. " " .. c.level .. ", " .. AG.Weights.MixText(w)
    if n > 0 then text = text .. "  (" .. n .. " set by you)" end
    page.head:SetText(text)
  end
  local total = table.getn(wState.list)
  local maxOff = total - W_ROWS
  if maxOff < 0 then maxOff = 0 end
  if wState.offset > maxOff then wState.offset = maxOff end
  if wState.offset < 0 then wState.offset = 0 end
  Opt.filling = true
  for i = 1, W_ROWS do
    local r = page.rows[i]
    local e = wState.list[wState.offset + i]
    r.entry = e
    if not e then
      r.frame:Hide()
    else
      r.frame:Show()
      r.name:SetText(AG.Items.Label(e.key))
      if e.manual then r.name:SetTextColor(AG.C.accent[1], AG.C.accent[2], AG.C.accent[3]) else r.name:SetTextColor(AG.C.text[1], AG.C.text[2], AG.C.text[3]) end
      r.auto:SetText(NumText(e.auto))
      r.why:SetText(e.why)
      if e.talent then r.why:SetTextColor(AG.C.gold[1], AG.C.gold[2], AG.C.gold[3]) else r.why:SetTextColor(AG.C.dim[1], AG.C.dim[2], AG.C.dim[3]) end
      if e.manual then r.edit:SetText(tostring(e.manual)) else r.edit:SetText("") end
    end
  end
  Opt.filling = false
  if total > W_ROWS then
    page.foot:SetText("AUTO is calculated from your class, talents and role. Type a number to use your own value; empty = auto. Mouse wheel scrolls (" .. (wState.offset + 1) .. "-" .. math.min(wState.offset + W_ROWS, total) .. " of " .. total .. ").")
  else
    page.foot:SetText("AUTO is calculated from your class, talents and role. Type a number to use your own value; empty = auto.")
  end
end

local function BuildWeights(page)
  page.head = AG.W.Text(page, 12, AG.C.gold)
  page.head:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -12)
  page.head:SetWidth(INNER - 80)
  page.head:SetHeight(14)

  local reset = AG.W.Button(page, "Reset", 60, 20, function()
    if wState.class and AdeGearDB and AdeGearDB.manual then AdeGearDB.manual[wState.class] = nil end
    ChangedByUser()
    Opt.RefreshWeights()
  end)
  reset:SetPoint("TOPRIGHT", page, "TOPRIGHT", -14, -9)

  local h1 = AG.W.Text(page, 10, AG.C.dim)
  h1:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -34)
  h1:SetText("STAT")
  local h2 = AG.W.Text(page, 10, AG.C.dim, "RIGHT")
  h2:SetPoint("TOPLEFT", page, "TOPLEFT", 140, -34)
  h2:SetWidth(60)
  h2:SetText("AUTO")
  local h3 = AG.W.Text(page, 10, AG.C.dim)
  h3:SetPoint("TOPLEFT", page, "TOPLEFT", 214, -34)
  h3:SetText("TALENT EFFECT")
  local h4 = AG.W.Text(page, 10, AG.C.dim, "RIGHT")
  h4:SetPoint("TOPRIGHT", page, "TOPRIGHT", -14, -34)
  h4:SetText("YOUR VALUE")

  page.rows = {}
  for i = 1, W_ROWS do
    local y = -48 - (i - 1) * W_H
    local f = CreateFrame("Frame", nil, page)
    f:SetWidth(INNER)
    f:SetHeight(W_H)
    f:SetPoint("TOPLEFT", page, "TOPLEFT", 14, y)
    local r = { frame = f }
    r.name = AG.W.Text(f, 12)
    r.name:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -4)
    r.name:SetWidth(126)
    r.name:SetHeight(14)
    r.auto = AG.W.Text(f, 12, AG.C.text, "RIGHT")
    r.auto:SetPoint("TOPLEFT", f, "TOPLEFT", 126, -4)
    r.auto:SetWidth(60)
    r.why = AG.W.Text(f, 11, AG.C.gold)
    r.why:SetPoint("TOPLEFT", f, "TOPLEFT", 200, -5)
    r.why:SetWidth(138)
    r.why:SetHeight(14)
    r.edit = AG.W.Edit(f, 56, 20)
    r.edit:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -2)
    r.edit.row = r
    r.edit:SetScript("OnTextChanged", function()
      if Opt.filling then return end
      local row = this.row
      if not row.entry or not wState.class then return end
      local text = string.gsub(this:GetText() or "", ",", ".")
      local v = tonumber(text)
      local m = ManualTable(wState.class, true)
      if v then m[row.entry.key] = v else m[row.entry.key] = nil end
      row.entry.manual = v
      if v then row.name:SetTextColor(AG.C.accent[1], AG.C.accent[2], AG.C.accent[3]) else row.name:SetTextColor(AG.C.text[1], AG.C.text[2], AG.C.text[3]) end
      ChangedByUser()
    end)
    page.rows[i] = r
  end
  page.foot = Note(page, "")
  page.foot:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -48 - W_ROWS * W_H - 6)
  page.foot:SetHeight(40)
  page.rowsBuilt = true
  page:EnableMouseWheel(true)
  page:SetScript("OnMouseWheel", function()
    wState.offset = wState.offset - arg1 * 3
    Opt.RefreshWeights()
  end)
end

----------------------------------------------------------------------
-- Talents tab: the talents that changed your values, with their ranks
----------------------------------------------------------------------

local T_ROWS, T_H = 8, 40
local tState = { list = {}, offset = 0 }

function Opt.RefreshTalents()
  local page = Opt.pages and Opt.pages[4]
  if not page or not page.rowsBuilt then return end
  if AdeTalents and AdeTalents.version then
    local ready = "not read yet"
    if AdeTalents.IsReady and AdeTalents.IsReady() then ready = "talents read" end
    page.status:SetText("AdeTalents v" .. AdeTalents.version .. " (" .. ready .. ")")
  else
    page.status:SetText("AdeTalents not found: talents are NOT counted")
  end
  tState.list = {}
  local w = AG.Weights.ForPlayer(true)
  if w then
    local byName, order = {}, {}
    local keys = {}
    for i = 1, table.getn(w.order or {}) do table.insert(keys, w.order[i]) end
    for k, v in pairs(w.why) do
      local known = false
      for i = 1, table.getn(keys) do if keys[i] == k then known = true end end
      if not known then table.insert(keys, k) end
    end
    for i = 1, table.getn(keys) do
      local notes = w.why[keys[i]]
      for j = 1, table.getn(notes or {}) do
        local s, e, name, r, mx, text = string.find(notes[j], "^(.-) (%d+)/(%d+): (.+)$")
        if s then
          local t = byName[name]
          if not t then
            t = { name = name, rank = r .. "/" .. mx, texts = {} }
            byName[name] = t
            table.insert(order, t)
          end
          local dup = false
          for q = 1, table.getn(t.texts) do if t.texts[q] == text then dup = true end end
          if not dup then table.insert(t.texts, text) end
        end
      end
    end
    for i = 1, table.getn(order) do
      order[i].text = table.concat(order[i].texts, "; ")
      table.insert(tState.list, order[i])
    end
  end
  local total = table.getn(tState.list)
  local maxOff = total - T_ROWS
  if maxOff < 0 then maxOff = 0 end
  if tState.offset > maxOff then tState.offset = maxOff end
  if tState.offset < 0 then tState.offset = 0 end
  for i = 1, T_ROWS do
    local r = page.rows[i]
    local t = tState.list[tState.offset + i]
    if not t then
      r.frame:Hide()
    else
      r.frame:Show()
      r.name:SetText(t.name)
      r.rank:SetText(t.rank)
      r.text:SetText(t.text)
    end
  end
  if total == 0 then
    page.note:SetText("No talent changes any value yet. Spend points in talents that affect your gear (armor, Intellect, block ...) and open this tab again.")
  elseif total > T_ROWS then
    page.note:SetText("Mouse wheel scrolls (" .. (tState.offset + 1) .. "-" .. math.min(tState.offset + T_ROWS, total) .. " of " .. total .. "). Updates when you open this tab.")
  else
    page.note:SetText("Updates when you open this tab, so a respec shows here.")
  end
end

local function BuildTalents(page)
  local head = AG.W.Text(page, 12, AG.C.gold)
  head:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -12)
  head:SetText("Talents that change the value of gear")
  page.status = AG.W.Text(page, 11, AG.C.dim)
  page.status:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -30)
  page.status:SetWidth(INNER)
  page.status:SetHeight(14)
  Opt.talentStatus = page.status

  page.rows = {}
  for i = 1, T_ROWS do
    local row = CreateFrame("Frame", nil, page)
    row:SetWidth(INNER)
    row:SetHeight(T_H - 6)
    row:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -50 - (i - 1) * T_H)
    AG.Style(row, "inset")
    local r = { frame = row }
    r.name = AG.W.Text(row, 12, AG.C.text)
    r.name:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
    r.name:SetWidth(INNER - 70)
    r.name:SetHeight(14)
    r.rank = AG.W.Text(row, 12, AG.C.accent, "RIGHT")
    r.rank:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -4)
    r.text = AG.W.Text(row, 11, AG.C.gold)
    r.text:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -19)
    r.text:SetWidth(INNER - 16)
    r.text:SetHeight(13)
    page.rows[i] = r
  end
  page.note = Note(page, "")
  page.note:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -50 - T_ROWS * T_H - 2)
  page.note:SetHeight(30)
  page.rowsBuilt = true
  page:EnableMouseWheel(true)
  page:SetScript("OnMouseWheel", function()
    tState.offset = tState.offset - arg1 * 2
    Opt.RefreshTalents()
  end)
end

local function UpdateTalentStatus()
  Opt.RefreshWeights()
  Opt.RefreshTalents()
end

----------------------------------------------------------------------
-- Window with tabs
----------------------------------------------------------------------

function Opt.Select(index)
  for i = 1, table.getn(Opt.pages) do
    if i == index then Opt.pages[i]:Show() else Opt.pages[i]:Hide() end
    Opt.tabs[i]:SetActive(i == index)
  end
  Opt.current = index
  if index == 3 then Opt.RefreshWeights() elseif index == 4 then Opt.RefreshTalents() end
end

function Opt.Create()
  if Opt.frame then return Opt.frame end
  local f = AG.W.Window("AdeGearOptions", "AdeGear options", WIDTH, HEIGHT, "FULLSCREEN_DIALOG")
  Opt.frame = f
  if not AG.LoadPos(f) then f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end

  Opt.tabs = {}
  Opt.pages = {}
  local builders = { BuildGeneral, BuildLeveling, BuildWeights, BuildTalents }
  local tw = math.floor((WIDTH - 28 - 3 * 4) / 4)
  for i = 1, table.getn(TABS) do
    local b = AG.W.Button(f, TABS[i], tw, 22, nil)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 14 + (i - 1) * (tw + 4), -38)
    b.onclick = function() Opt.Select(i) end
    Opt.tabs[i] = b

    local page = CreateFrame("Frame", nil, f)
    page:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -66)
    page:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
    AG.Style(page, "inset")
    page:Hide()
    Opt.pages[i] = page
    builders[i](page)
  end
  Opt.Select(1)
  Opt.Sync()
  return f
end

function Opt.Toggle()
  local f = Opt.Create()
  if f:IsShown() then
    f:Hide()
  else
    UpdateTalentStatus()
    Opt.Sync()
    f:Show()
  end
end
