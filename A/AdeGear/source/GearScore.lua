-- GearScore: one number for gear that does not depend on class, spec or role, so it can be compared
-- between players. Every stat has a fixed base weight (roughly how much of an item's "budget" it takes),
-- armor is divided by what the armor type normally gives (so plate does not beat cloth just for armor),
-- weapons count their dps, and effects (procs, use effects) add a small flat amount.
-- It works for your own gear (/adeg gs) and for players you hover (tooltip line, read by inspecting them).
-- Target: Lua 5.0.

local AG = AdeGear
local GS = {}
AG.GearScore = GS

----------------------------------------------------------------------
-- Base weights (one point of the stat = this much score). Tune here.
----------------------------------------------------------------------

local WEIGHT = {
  STR = 1, AGI = 1, STA = 1, INT = 1, SPI = 1,
  AP = 0.5, RAP = 0.5, FERAL_AP = 0.5,
  SP = 1, HEAL = 0.5,
  CRIT = 14, HIT = 12, SPELLCRIT = 14, SPELLHIT = 12, HASTE_ATTACK = 15, HASTE_CAST = 15,
  DODGE = 14, PARRY = 14, BLOCK = 8, BLOCKVAL = 0.5, DEFENSE = 3,
  MP5 = 2.5, CASTREGEN = 3, HP5 = 1,
  HEALTH = 0.1, MANA = 0.07,
  ARMORPEN = 0.3, LIFESTEAL = 8, THORNS = 0.8, PROC_DMG = 0.3,
}
local W_RES = 1        -- one point of one resistance
local W_DMG = 0.8      -- spell damage of one school
local W_SKILL = 6      -- +1 weapon skill

-- armor is divided by this: about what an item of that type gives compared with cloth of the same level
local ARMOR_DIV = { Cloth = 1, Leather = 2.5, Mail = 5, Plate = 9, Shield = 9 }
local W_ARMOR = 0.1
-- weapons: a melee weapon can cost as much as two or three other items on classes that never use it
-- (hunters, casters), so melee dps counts a third and wand dps a third of that; bows, guns and thrown count half
local W_DPS = 2 / 3    -- melee weapon dps
local W_WAND = 1 / 3   -- wand dps
local W_RANGED = 1     -- bow, crossbow, gun, thrown dps
-- without item level, quality stands in for it: rares and epics carry more stats and stronger effects than
-- their stats alone show (by quality 0-5: poor, common, uncommon, rare, epic, legendary)
local QUALITY_MULT = { [0] = 1, [1] = 1, [2] = 1, [3] = 1.08, [4] = 1.2, [5] = 1.5 }
local W_EFFECT = 4     -- each effect line (proc, use ...), up to 3 per item
local MAX_EFFECTS = 3

GS.SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
local SLOT_NAME = {
  [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet",
  [9] = "Wrist", [10] = "Hands", [11] = "Finger 1", [12] = "Finger 2", [13] = "Trinket 1", [14] = "Trinket 2",
  [15] = "Back", [16] = "Main hand", [17] = "Off hand", [18] = "Ranged",
}

----------------------------------------------------------------------
-- One item
----------------------------------------------------------------------

function GS.Item(it)
  if not it or not it.slot or it.bag or it.slot == "AMMO" or it.slot == "SHIRT" or it.slot == "TABARD" then return 0 end
  local sum = 0
  for k, v in pairs(it.stats or {}) do
    if k == "ARMOR" then
      local div = ARMOR_DIV[it.armorKind or ""] or 1
      sum = sum + v / div * W_ARMOR
    elseif WEIGHT[k] then
      sum = sum + v * WEIGHT[k]
    elseif string.find(k, "^RES_") then
      sum = sum + v * W_RES
    elseif string.find(k, "^DMG_") then
      sum = sum + v * W_DMG
    elseif string.find(k, "^SKILL_") then
      sum = sum + v * W_SKILL
    end
  end
  local dps = it.weapon and it.weapon.dps or it.dps
  if dps and dps > 0 then
    if it.weaponKind == "Wand" then
      sum = sum + dps * W_WAND
    elseif it.slot == "RANGED" then
      sum = sum + dps * W_RANGED
    else
      sum = sum + dps * W_DPS
    end
  end
  local fx = table.getn(it.special or {})
  if fx > MAX_EFFECTS then fx = MAX_EFFECTS end
  sum = sum + fx * W_EFFECT
  if sum < 0 then sum = 0 end
  local q = it.quality or 1
  if q > 5 then q = 5 end
  return sum * (QUALITY_MULT[q] or 1)
end

----------------------------------------------------------------------
-- Items by link, remembered for the session (the same item gives the same score)
----------------------------------------------------------------------

local itemCache = {}

-- returns score, complete. complete is false when the game has not given the item's data yet
function GS.Link(link)
  local str = AG.Items.ItemString(link)
  if not str then return 0, false end
  local hit = itemCache[str]
  if hit then return hit, true end
  local it = AG.Items.FromLink(str)
  if not it or not it.slot then return 0, false end
  local score = GS.Item(it)
  itemCache[str] = score
  return score, true
end

-- a "GearScore: N" line on the tooltip of an item (once)
function GS.ItemLine(tooltip, link)
  if not AG.Get("gearscore") or not tooltip or not tooltip.AddLine or not link then return end
  local score, ok = GS.Link(link)
  if not ok or score <= 0 then return end
  local name = tooltip:GetName()
  for i = 1, tooltip:NumLines() do
    local fs = getglobal(name .. "TextLeft" .. i)
    local text = fs and fs:GetText()
    if text and string.find(text, "GearScore", 1, true) then return end
  end
  local c = AG.C.accent
  tooltip:AddLine("GearScore: " .. math.floor(score + 0.5), c[1], c[2], c[3])
  tooltip:Show()
end

----------------------------------------------------------------------
-- Your own gear
----------------------------------------------------------------------

-- returns total, list of { slot, name, link, score }
function GS.Own()
  local total, list = 0, {}
  for i = 1, table.getn(GS.SLOTS) do
    local slot = GS.SLOTS[i]
    local link = GetInventoryItemLink("player", slot)
    if link then
      local score = GS.Link(link)
      total = total + score
      table.insert(list, { slot = slot, name = SLOT_NAME[slot], link = link, score = score })
    end
  end
  return total, list
end

----------------------------------------------------------------------
-- Other players: read by inspecting them, remembered for the session
----------------------------------------------------------------------

local players = {}     -- name -> { score, count, partial, t }
local MAX_PLAYERS = 1000   -- remembered for the whole session; when this many are stored the oldest half is dropped
local count = 0
local lastNotify = 0

function GS.CachedCount() return count end

function GS.Reset()
  local n = count
  count = 0
  players = {}
  failed = {}
  itemCache = {}
  if AG.Compare and AG.Compare.Flush then AG.Compare.Flush() end
  return n
end

local function ReadUnit(unit)
  local total, count, missing = 0, 0, 0
  for i = 1, table.getn(GS.SLOTS) do
    local link = GetInventoryItemLink(unit, GS.SLOTS[i])
    if link then
      local score, ok = GS.Link(link)
      if ok then
        total = total + score
        count = count + 1
      else
        missing = missing + 1
      end
    end
  end
  return total, count, missing
end

local function Token(name)
  if UnitIsUnit("mouseover", "player") then return "player" end
  if UnitIsUnit("mouseover", "target") then return "target" end
  return "mouseover"
end

local function HasLine()
  for i = 1, GameTooltip:NumLines() do
    local fs = getglobal("GameTooltipTextLeft" .. i)
    local text = fs and fs:GetText()
    if text and string.find(text, "GearScore", 1, true) then return true end
  end
  return false
end

local function Remember(name, entry)
  if not players[name] then
    count = count + 1
    if count > MAX_PLAYERS then
      -- drop the oldest half
      local times = {}
      for k, v in pairs(players) do table.insert(times, v.t) end
      table.sort(times)
      local cut = times[math.floor(table.getn(times) / 2)]
      for k, v in pairs(players) do
        if v.t <= cut then players[k] = nil; count = count - 1 end
      end
    end
  end
  players[name] = entry
end

local function ScoreText(entry)
  local text = "GearScore: " .. math.floor(entry.score + 0.5)
  if entry.partial then text = text .. "  (" .. entry.count .. " items read)" end
  return text
end

local function AddLine(entry)
  local _, class = UnitClass("mouseover")
  local c = AG.ClassColor[class or ""] or AG.C.accent
  GameTooltip:AddLine(ScoreText(entry), c[1], c[2], c[3])
  GameTooltip:Show()
end

local job = nil   -- { name, tries, sent }
local failed = {} -- name -> time before which we do not try again

local function Work()
  local name = UnitName("mouseover")
  if not name or not UnitIsPlayer("mouseover") or not GameTooltip:IsShown() then job = nil return end
  if HasLine() then return end
  if not AG.Get("gearscore") then return end

  if UnitIsUnit("mouseover", "player") then
    local total, list = GS.Own()
    AddLine({ score = total, count = table.getn(list) })
    return
  end

  local entry = players[name]
  local now = GetTime()
  if entry and not (IsShiftKeyDown() and (now - entry.t) > 3) then
    AddLine(entry)
    return
  end

  -- needs a look at their gear
  if InspectFrame and InspectFrame:IsShown() then return end
  local unit = Token(name)
  if CanInspect and not CanInspect(unit) then return end
  if failed[name] and now < failed[name] then return end
  if not job or job.name ~= name then job = { name = name, tries = 0, sent = 0 } end
  if job.sent > 0 and now - job.sent < 0.5 then return end   -- give the server time to answer
  if job.sent > 0 then
    local total, count, missing = ReadUnit(unit)
    if count > 0 and (missing == 0 or job.tries >= 4) then
      local e = { score = total, count = count, partial = (missing > 0), t = now }
      Remember(name, e)
      job = nil
      AddLine(e)
      return
    end
  end
  if now - lastNotify < 1 then return end
  if job.tries >= 5 then
    -- nothing came back (too far, or they cannot be inspected): try again later, show nothing
    failed[name] = now + 10
    job = nil
    return
  end
  job.tries = job.tries + 1
  job.sent = now
  lastNotify = now
  NotifyInspect(unit)
end

local driver = CreateFrame("Frame")
local acc = 0
driver:SetScript("OnUpdate", function()
  acc = acc + arg1
  if acc < 0.15 then return end
  acc = 0
  if UnitExists("mouseover") and UnitIsPlayer("mouseover") then
    local ok, err = pcall(Work)
    if not ok then AG.lastError = tostring(err) end
  else
    job = nil
  end
end)

----------------------------------------------------------------------
-- Window with your own items (/adeg gs)
----------------------------------------------------------------------

local win = nil
local ROW_H = 18

local function Create()
  if win then return win end
  local rows = table.getn(GS.SLOTS)
  local f = AG.W.Window("AdeGearScore", "GearScore", 400, 34 + rows * ROW_H + 40, "DIALOG")
  win = f
  if not AG.LoadPos(f) then f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
  f.rows = {}
  for i = 1, rows do
    local row = CreateFrame("Button", nil, f)
    row:SetWidth(380)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -34 - (i - 1) * ROW_H)
    row.slot = AG.W.Text(row, 11, AG.C.dim)
    row.slot:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.slot:SetWidth(70)
    row.slot:SetHeight(14)
    row.name = AG.W.Text(row, 12, AG.C.text)
    row.name:SetPoint("LEFT", row, "LEFT", 74, 0)
    row.name:SetWidth(240)
    row.name:SetHeight(14)
    row.score = AG.W.Text(row, 12, AG.C.accent, "RIGHT")
    row.score:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.score:SetWidth(60)
    row:SetScript("OnEnter", function()
      if this.link then
        GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetHyperlink(this.link)
        GameTooltip:Show()
      end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.rows[i] = row
  end
  f.total = AG.W.Text(f, 13, AG.C.accent, "CENTER")
  f.total:SetPoint("BOTTOM", f, "BOTTOM", 0, 18)
  f.total:SetWidth(380)
  f.note = AG.W.Text(f, 10, AG.C.dim, "CENTER")
  f.note:SetPoint("BOTTOM", f, "BOTTOM", 0, 5)
  f.note:SetWidth(380)
  f.note:SetText("Same for every class. Other players: hover them close by. /adeg gs reset forgets scores.")
  return f
end

function GS.Show()
  local f = Create()
  local total, list = GS.Own()
  for i = 1, table.getn(GS.SLOTS) do
    local row = f.rows[i]
    row.link = nil
    row.slot:SetText(SLOT_NAME[GS.SLOTS[i]])
    row.name:SetText("")
    row.score:SetText("")
  end
  for i = 1, table.getn(list) do
    for j = 1, table.getn(GS.SLOTS) do
      if GS.SLOTS[j] == list[i].slot then
        local row = f.rows[j]
        row.link = list[i].link
        row.name:SetText(list[i].link)
        row.score:SetText(math.floor(list[i].score + 0.5))
      end
    end
  end
  f.total:SetText("GearScore: " .. math.floor(total + 0.5))
  f:Show()
end

function GS.Toggle()
  if win and win:IsShown() then win:Hide() else GS.Show() end
end

----------------------------------------------------------------------
-- Your score on the character window (click: the list of your items)
----------------------------------------------------------------------

local label = nil

function GS.PlaceLabel()
  if not label then return end
  label:ClearAllPoints()
  local off = AdeGearDB and AdeGearDB.gsOffset
  if off and off[1] and off[2] then
    -- where you dragged it, measured from the middle of the character window
    label:SetPoint("CENTER", CharacterFrame, "CENTER", off[1], off[2])
  elseif AG.Get("gsPos") == "top" then
    label:SetPoint("TOP", CharacterFrame, "TOP", 0, -50)
  else
    label:SetPoint("BOTTOM", CharacterFrame, "BOTTOM", 0, 14)
  end
end

function GS.UpdateLabel()
  if not label then return end
  if not AG.Get("gearscore") then label:Hide() return end
  local ok, total = pcall(GS.Own)
  if ok and total then
    local _, class = UnitClass("player")
    local c = AG.ClassColor[class] or AG.C.accent
    label.text:SetTextColor(c[1], c[2], c[3])
    label.text:SetText("GearScore: " .. math.floor(total + 0.5))
    label:Show()
  end
end

local function MakeLabel()
  if label or not CharacterFrame then return end
  local b = CreateFrame("Button", "AdeGearScoreLabel", CharacterFrame)
  label = b
  b:SetWidth(150)
  b:SetHeight(16)
  b:SetFrameLevel(CharacterFrame:GetFrameLevel() + 6)
  b.text = AG.W.Text(b, 12, AG.C.accent, "CENTER")
  b.text:SetAllPoints(b)
  b:SetMovable(true)
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", function() this:StartMoving() end)
  b:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local lx, ly = this:GetCenter()
    local cx, cy = CharacterFrame:GetCenter()
    if lx and cx then
      -- same scale for both (the label is a child of the window)
      AdeGearDB = AdeGearDB or {}
      AdeGearDB.gsOffset = { lx - cx, ly - cy }
    end
    GS.PlaceLabel()
  end)
  b:SetScript("OnClick", function() GS.Toggle() end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:AddLine("GearScore", AG.C.accent[1], AG.C.accent[2], AG.C.accent[3])
    GameTooltip:AddLine("Same scale for every class. Click: your items. Drag: move.", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:SetScript("OnShow", function() GS.UpdateLabel() end)
  GS.PlaceLabel()
  GS.UpdateLabel()
end

local lev = CreateFrame("Frame")
lev:RegisterEvent("PLAYER_ENTERING_WORLD")
lev:RegisterEvent("UNIT_INVENTORY_CHANGED")
lev:SetScript("OnEvent", function()
  if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then return end
  MakeLabel()
  if label and CharacterFrame:IsShown() then GS.UpdateLabel() end
end)

local oldConfig = AG.OnConfig
AG.OnConfig = function(key, value)
  if oldConfig then oldConfig(key, value) end
  if key == "gearscore" then GS.UpdateLabel() end
  if key == "gsPos" then GS.PlaceLabel() end
end
