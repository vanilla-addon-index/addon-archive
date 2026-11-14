-- Upgrade arrows on item icons (bags, bank) and /adeg best.
-- A green arrow on a bag item means: better than what you wear in that slot, for your role.
-- Target: Lua 5.0.

local AG = AdeGear
local Arrows = {}
AG.Arrows = Arrows

local made = {}   -- button -> arrow frame

-- the arrow is drawn from plain colored textures (stem + stepped head), so it needs no game art
local function MakeArrow(button)
  local f = CreateFrame("Frame", nil, button)
  f:SetWidth(9)
  f:SetHeight(11)
  f:SetFrameLevel(button:GetFrameLevel() + 5)
  f:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
  f:EnableMouse(false)
  local function Bar(layer, r, g, b, w, h, x, y)
    local t = f:CreateTexture(nil, layer)
    t:SetTexture(r, g, b, 1)
    t:SetWidth(w)
    t:SetHeight(h)
    t:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, y)
    return t
  end
  -- each part: width, height, x, y (stem and a stepped head), black outline 1px bigger, then green
  local parts = {
    { 3, 5, 3, 0 },    -- stem
    { 7, 1, 1, 5 },    -- head, wide
    { 5, 1, 2, 6 },
    { 3, 1, 3, 7 },
    { 1, 1, 4, 8 },
  }
  for i = 1, table.getn(parts) do
    local p = parts[i]
    Bar("BACKGROUND", 0, 0, 0, p[1] + 2, p[2] + 2, p[3] - 1, p[4] - 1)
  end
  for i = 1, table.getn(parts) do
    local p = parts[i]
    Bar("ARTWORK", 0.1, 0.85, 0.15, p[1], p[2], p[3], p[4])
  end
  f:Hide()
  return f
end

local function Mark(button, link)
  if not button then return end
  local show = false
  if link and AG.Get("enabled") and AG.Get("arrows") then
    local r = AG.Compare.Quick(link)
    if r and r.state == "ok" and AG.Compare.IsUpgrade(r) then show = true end
  end
  local a = made[button]
  if show then
    if not a then a = MakeArrow(button); made[button] = a end
    a:Show()
  elseif a then
    a:Hide()
  end
end

----------------------------------------------------------------------
-- Blizzard bags and bank
----------------------------------------------------------------------

local function UpdateContainer(frame)
  if not frame or not frame.GetName then return end
  local name = frame:GetName()
  local bag = frame:GetID()
  local size = frame.size or GetContainerNumSlots(bag)
  if not name or not bag or not size then return end
  for i = 1, size do
    local button = getglobal(name .. "Item" .. i)
    if button then
      Mark(button, GetContainerItemLink(bag, button:GetID()))
    end
  end
end

local function RefreshBlizzard()
  for i = 1, NUM_CONTAINER_FRAMES or 13 do
    local f = getglobal("ContainerFrame" .. i)
    if f and f:IsShown() then pcall(UpdateContainer, f) end
  end
  if BankFrame and BankFrame:IsShown() then
    for i = 1, 24 do
      local b = getglobal("BankFrameItem" .. i)
      if b then Mark(b, GetContainerItemLink(-1, b:GetID())) end
    end
  end
end

----------------------------------------------------------------------
-- pfUI bags (its own buttons): found by their bag and slot numbers
----------------------------------------------------------------------

local function RefreshPfui()
  if not pfUI or not pfUI.bags then return end
  for bag, data in pairs(pfUI.bags) do
    if type(data) == "table" and type(data.slots) == "table" then
      for slot, s in pairs(data.slots) do
        local button = s and (s.frame or s)
        if button and button.GetObjectType and type(bag) == "number" and type(slot) == "number" and button:IsVisible() then
          Mark(button, GetContainerItemLink(bag, slot))
        end
      end
    end
  end
end

local dirty, wait = false, 0

-- something changed the verdicts (the options window): redraw soon
function Arrows.Touch()
  dirty = true
  wait = 0.2
end

function Arrows.Refresh()
  pcall(RefreshBlizzard)
  pcall(RefreshPfui)
end

function Arrows.HideAll()
  for b, a in pairs(made) do a:Hide() end
end

-- reports what it found, for /adeg arrows debug
function Arrows.Debug()
  local n = 0
  for b, a in pairs(made) do
    n = n + 1
  end
  local open = 0
  for i = 1, NUM_CONTAINER_FRAMES or 13 do
    local f = getglobal("ContainerFrame" .. i)
    if f and f:IsShown() then open = open + 1 end
  end
  local pf = "no"
  if pfUI and pfUI.bags then
    pf = "yes"
    local cnt = 0
    for bag, data in pairs(pfUI.bags) do if type(data) == "table" and data.slots then cnt = cnt + 1 end end
    pf = "yes, " .. cnt .. " bags with slots"
  end
  AG.Msg("arrows: " .. tostring(AG.Get("arrows")) .. ", arrow icons made: " .. n .. ", Blizzard bags open: " .. open .. ", pfUI bags: " .. pf)
end

----------------------------------------------------------------------
-- When to refresh
----------------------------------------------------------------------

local ev = CreateFrame("Frame")
ev:RegisterEvent("BAG_UPDATE")
ev:RegisterEvent("UNIT_INVENTORY_CHANGED")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("CHARACTER_POINTS_CHANGED")
ev:RegisterEvent("SPELLS_CHANGED")
ev:RegisterEvent("SKILL_LINES_CHANGED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("BANKFRAME_OPENED")
ev:SetScript("OnEvent", function()
  if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then return end
  if event ~= "BAG_UPDATE" and event ~= "BANKFRAME_OPENED" then AG.Compare.Flush() end
  if event == "BAG_UPDATE" then AG.Compare.Flush() end
  dirty = true
  wait = 0.3
end)
ev:SetScript("OnUpdate", function()
  if not dirty then return end
  wait = wait - arg1
  if wait <= 0 then
    dirty = false
    Arrows.Refresh()
  end
end)

-- when the game redraws a bag, redraw our arrows too
if type(ContainerFrame_Update) == "function" then
  local original = ContainerFrame_Update
  ContainerFrame_Update = function(frame)
    original(frame)
    if AG.Get("arrows") then pcall(UpdateContainer, frame) end
  end
end

-- toggled from the options or /adeg arrows
local oldConfig = AG.OnConfig
AG.OnConfig = function(key, value)
  if oldConfig then oldConfig(key, value) end
  if key == "arrows" then
    if value then Arrows.Refresh() else Arrows.HideAll() end
  elseif key ~= "pos" then
    -- role, leveling mix, weapon scale ... change every verdict: work them out again
    AG.Compare.Flush()
    dirty = true
    wait = 0.1
  end
end

----------------------------------------------------------------------
-- /adeg best: a small window with the upgrades waiting in your bags
----------------------------------------------------------------------

local ROWS, ROW_H = 12, 20
local WIDTH = 520
local win = nil
local entries = {}
local offset = 0

local function Collect()
  local found, later = {}, {}
  for bag = 0, 4 do
    local n = GetContainerNumSlots(bag) or 0
    for slot = 1, n do
      local link = GetContainerItemLink(bag, slot)
      if link then
        local r = AG.Compare.Quick(link)
        if r and AG.Compare.IsUpgrade(r) then
          local entry = { link = link, r = r }
          if r.state == "ok" then table.insert(found, entry) else table.insert(later, entry) end
        end
      end
    end
  end
  local function Sort(list)
    table.sort(list, function(a, b)
      local pa = a.r.pct or 1000
      local pb = b.r.pct or 1000
      return pa > pb
    end)
  end
  Sort(found)
  Sort(later)
  local list = {}
  if table.getn(found) > 0 then
    table.insert(list, { header = "You can wear now (" .. table.getn(found) .. "), best first" })
    for i = 1, table.getn(found) do table.insert(list, found[i]) end
  end
  if table.getn(later) > 0 then
    table.insert(list, { header = "Better, but not usable yet (" .. table.getn(later) .. "): level, training or profession" })
    for i = 1, table.getn(later) do table.insert(list, later[i]) end
  end
  return list
end

local function Draw()
  if not win then return end
  local total = table.getn(entries)
  local maxOffset = total - ROWS
  if maxOffset < 0 then maxOffset = 0 end
  if offset > maxOffset then offset = maxOffset end
  if offset < 0 then offset = 0 end
  for i = 1, ROWS do
    local row = win.rows[i]
    local e = entries[offset + i]
    row.entry = e
    if not e then
      row:Hide()
    else
      row:Show()
      if e.header then
        row.name:SetText("")
        row.where:SetText("")
        row.pct:SetText("")
        row.head:SetText(e.header)
      else
        local r = e.r
        row.head:SetText("")
        row.name:SetText(e.link)
        if r.empty then
          row.where:SetText(r.label .. " (empty)")
        else
          row.where:SetText(r.label .. ": replaces " .. r.name)
        end
        local pts = string.format("%+.0f", r.gain)
        if r.gain < 10 then pts = string.format("%+.1f", r.gain) end
        if r.pct then
          local p = string.format("%+.1f%%", r.pct)
          if r.pct >= 100 then p = string.format("%+d%%", math.floor(r.pct + 0.5)) end
          row.pct:SetText(p .. " (" .. pts .. ")")
        else
          row.pct:SetText(pts .. " pts")
        end
      end
    end
  end
  if total == 0 then
    win.empty:Show()
    win.footer:SetText("")
  else
    win.empty:Hide()
    if total > ROWS then
      win.footer:SetText("Mouse wheel scrolls: " .. (offset + 1) .. "-" .. math.min(offset + ROWS, total) .. " of " .. total)
    else
      win.footer:SetText("")
    end
  end
end

local function Create()
  if win then return win end
  local f = AG.W.Window("AdeGearBest", "Upgrades in your bags", WIDTH, 34 + ROWS * ROW_H + 26, "DIALOG")
  win = f
  if not AG.LoadPos(f) then f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
  f.rows = {}
  for i = 1, ROWS do
    local row = CreateFrame("Button", nil, f)
    row:SetWidth(WIDTH - 20)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -34 - (i - 1) * ROW_H)
    row.head = AG.W.Text(row, 11, AG.C.gold)
    row.head:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.head:SetWidth(WIDTH - 24)
    row.head:SetHeight(14)
    row.name = AG.W.Text(row, 12, AG.C.text)
    row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.name:SetWidth(170)
    row.name:SetHeight(14)
    row.where = AG.W.Text(row, 11, AG.C.dim)
    row.where:SetPoint("LEFT", row, "LEFT", 176, 0)
    row.where:SetWidth(200)
    row.where:SetHeight(14)
    row.pct = AG.W.Text(row, 12, AG.C.good, "RIGHT")
    row.pct:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.pct:SetWidth(120)
    row:SetScript("OnEnter", function()
      if this.entry and this.entry.link then
        GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetHyperlink(this.entry.link)
        GameTooltip:Show()
      end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.rows[i] = row
  end
  f.empty = AG.W.Text(f, 12, AG.C.dim, "CENTER")
  f.empty:SetPoint("CENTER", f, "CENTER", 0, -6)
  f.empty:SetText("No upgrades in your bags (the bank is not checked)")
  f.footer = AG.W.Text(f, 10, AG.C.dim, "CENTER")
  f.footer:SetPoint("BOTTOM", f, "BOTTOM", 0, 8)
  f.footer:SetWidth(WIDTH - 20)
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function()
    offset = offset - arg1 * 3
    Draw()
  end)
  return f
end

function Arrows.Best()
  local f = Create()
  entries = Collect()
  offset = 0
  Draw()
  f:Show()
end
