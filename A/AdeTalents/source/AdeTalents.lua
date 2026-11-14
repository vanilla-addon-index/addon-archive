-- AdeTalents: shared talent ranks and talent data for the Ade addons.
-- Target: WoW 1.12 client (Lua 5.0): no # operator, no string.gmatch, no select().

AdeTalents = AdeTalents or {}
local AT = AdeTalents
AT.version = "1.2.3"

local ranks = {}      -- [talent name] = current rank
local maxranks = {}   -- [talent name] = max rank
local info = {}       -- [talent name] = { tab, tabName, index, tier, column }
local localNames = {} -- [talent name] = the name the client shows
local ready = false
local callbacks = {}

local function Msg(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffAdeTalents|r: " .. text)
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

-- true once the talents of the current character have been read
function AT.IsReady()
  return ready
end

-- current rank of a talent by its English name, 0 if not learned or unknown
function AT.GetRank(name)
  return ranks[name] or 0
end

-- maximum rank of a talent, nil if the talent does not exist for this class
function AT.GetMaxRank(name)
  return maxranks[name]
end

-- true if at least one point is spent in the talent
function AT.Has(name)
  return (ranks[name] or 0) > 0
end

-- table { tab, tabName, index, tier, column } or nil
function AT.GetInfo(name)
  return info[name]
end

-- fn() is called after the talents were read and something changed
function AT.RegisterCallback(fn)
  table.insert(callbacks, fn)
end

----------------------------------------------------------------------
-- Talent effects data (Data\<CLASS>.lua, stored in AdeTalents.Data)
-- This is reference data only: it knows what a talent does at each rank.
-- Your real ranks come from the game (GetRank), never from this data.
----------------------------------------------------------------------

local function Round(x)
  return math.floor(x * 10000 + 0.5) / 10000
end

local function ClassData()
  local _, class = UnitClass("player")
  local all = AT.Data
  return all and class and all[class]
end

-- Raw data of a talent of your class, or nil. Fields:
--   tab, tier, col, max, req (list of requirement lines),
--   text (description, numbers written as {1} {2} ...),
--   n (the numbers at rank 1), k (one letter per number:
--   r = grows with the rank, c = same at every rank, v = a different value
--   at every rank (listed in v[i][rank]), ? = unknown),
--   conf ("exact", "assumed" or "partial")
function AT.GetData(name)
  local d = ClassData()
  return d and d.talents and d.talents[name]
end

-- Numbers of a talent at a rank (default: your current rank).
-- Returns values, confidence. values[i] is the number {i} of the text,
-- false when that number is unknown.
-- Returns nil when the rank is 0, above the max rank, or there is no data.
function AT.GetValues(name, rank)
  local t = AT.GetData(name)
  if not t then return nil end
  if not rank then rank = ranks[name] or 0 end
  if rank < 1 or rank > t.max then return nil end
  local values = {}
  for i = 1, table.getn(t.n) do
    local kind = string.sub(t.k, i, i)
    if kind == "r" then
      values[i] = Round(t.n[i] * rank)
    elseif kind == "c" then
      values[i] = t.n[i]
    elseif kind == "v" then
      local list = t.v and t.v[i]
      values[i] = (list and list[rank]) or false
    else
      values[i] = false
    end
  end
  return values, t.conf
end

-- Description of a talent with the numbers of a rank filled in
-- (default: your current rank), or nil like GetValues.
function AT.GetText(name, rank)
  local t = AT.GetData(name)
  if not t then return nil end
  local values = AT.GetValues(name, rank)
  if not values then return nil end
  local text = string.gsub(t.text, "{(%d+)}", function(i)
    local v = values[tonumber(i)]
    if v then return string.format("%g", v) end
    return "?"
  end)
  return text
end

-- What the talent does for you right now:
-- { rank, max, values, confidence, text }, or nil when you have no points in it
-- (or there is no data). Other addons can use this directly.
function AT.GetEffect(name)
  local rank = ranks[name] or 0
  if rank < 1 then return nil end
  local values, conf = AT.GetValues(name, rank)
  if not values then return nil end
  return { rank = rank, max = maxranks[name], values = values, confidence = conf, text = AT.GetText(name, rank) }
end

----------------------------------------------------------------------
-- Reading talents
----------------------------------------------------------------------

-- English name of the talent at a position (tab, tier, column), from the data.
-- Positions are the same in every client language, so this works on a localized client.
local posIndex, posClass
local function EnglishName(tab, tier, column)
  local d = ClassData()
  if not d or not d.talents then return nil end
  local _, class = UnitClass("player")
  if posClass ~= class then
    posIndex = {}
    for name, t in pairs(d.talents) do
      posIndex[t.tab .. ":" .. t.tier .. ":" .. t.col] = name
    end
    posClass = class
  end
  return posIndex[tab .. ":" .. tier .. ":" .. column]
end

-- the talent name as the client shows it (for display), nil if unknown
function AT.GetLocalName(name)
  return localNames[name]
end

local function Scan()
  local tabs = GetNumTalentTabs()
  if not tabs or tabs < 1 then return false, false end

  local newRanks, newMax, newInfo, newLocal = {}, {}, {}, {}
  local total = 0
  local changed = false

  for tab = 1, tabs do
    local tabName = GetTalentTabInfo(tab)
    local n = GetNumTalents(tab)
    for i = 1, n do
      local name, icon, tier, column, rank, maxRank = GetTalentInfo(tab, i)
      if name then
        local localName = name
        name = EnglishName(tab, tier, column) or localName
        newRanks[name] = rank or 0
        newMax[name] = maxRank
        newInfo[name] = { tab = tab, tabName = tabName, index = i, tier = tier, column = column }
        newLocal[name] = localName
        total = total + 1
        if ranks[name] ~= (rank or 0) then changed = true end
      end
    end
  end

  if total < 1 then return false, false end

  ranks, maxranks, info, localNames = newRanks, newMax, newInfo, newLocal
  if not ready then changed = true end
  ready = true
  return true, changed
end

local function FireCallbacks()
  for i = 1, table.getn(callbacks) do
    local ok, err = pcall(callbacks[i])
    if not ok then Msg("callback error: " .. tostring(err)) end
  end
end

-- the client may not hand over talents right after login, so retry until they arrive
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CHARACTER_POINTS_CHANGED")
frame:RegisterEvent("SPELLS_CHANGED")

local dirty, elapsed, tries = false, 1, 0

frame:SetScript("OnEvent", function()
  dirty = true
  tries = 0
  elapsed = 1
end)

frame:SetScript("OnUpdate", function()
  if not dirty then return end
  elapsed = elapsed + arg1
  if elapsed < 1 then return end
  elapsed = 0
  tries = tries + 1
  local ok, changed = Scan()
  if ok then
    dirty = false
    if changed then FireCallbacks() end
  elseif tries >= 30 then
    dirty = false
  end
end)

----------------------------------------------------------------------
-- Tooltip dump: saves the full text of every talent to AdeTalentsDB,
-- so the talent data of a class can be copied from the game, not typed.
----------------------------------------------------------------------

local tip = CreateFrame("GameTooltip", "AdeTalentsScanTip", UIParent, "GameTooltipTemplate")

local function Clean(text)
  if not text then return nil end
  text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
  text = string.gsub(text, "|r", "")
  return text
end

-- The tooltip keeps the text of its right-hand column from the previous talent,
-- so every line is emptied before a new talent is loaded.
local MAXLINES = 40

local function ScrubTip()
  tip:ClearLines()
  for i = 1, MAXLINES do
    local left = getglobal("AdeTalentsScanTipTextLeft" .. i)
    local right = getglobal("AdeTalentsScanTipTextRight" .. i)
    if left then left:SetText("") end
    if right then right:SetText("") end
  end
end

local function ReadTip(tab, index)
  tip:SetOwner(UIParent, "ANCHOR_NONE")
  ScrubTip()
  tip:SetTalent(tab, index)
  local lines = {}
  for i = 1, tip:NumLines() do
    local left = getglobal("AdeTalentsScanTipTextLeft" .. i)
    local right = getglobal("AdeTalentsScanTipTextRight" .. i)
    local l = Clean(left and left:GetText())
    local r = Clean(right and right:GetText())
    if r and r ~= "" then
      table.insert(lines, (l or "") .. " | " .. r)
    elseif l then
      table.insert(lines, l)
    end
  end
  tip:Hide()
  return lines
end

function AT.Dump()
  local tabs = GetNumTalentTabs()
  if not tabs or tabs < 1 then
    Msg("talents are not available yet, try again in a few seconds")
    return false
  end

  local _, class = UnitClass("player")
  local out = {
    class = class,
    level = UnitLevel("player"),
    version = AT.version,
    tabs = {},
  }

  local count = 0
  for tab = 1, tabs do
    local tabName, icon, points = GetTalentTabInfo(tab)
    local t = { name = tabName, points = points, talents = {} }
    for i = 1, GetNumTalents(tab) do
      local name, icon2, tier, column, rank, maxRank = GetTalentInfo(tab, i)
      if name then
        table.insert(t.talents, {
          name = name,
          tier = tier,
          column = column,
          rank = rank,
          max = maxRank,
          tip = ReadTip(tab, i),
        })
        count = count + 1
      end
    end
    table.insert(out.tabs, t)
  end

  AdeTalentsDB = AdeTalentsDB or {}
  AdeTalentsDB.dumps = AdeTalentsDB.dumps or {}
  AdeTalentsDB.dumps[class] = out

  Msg("saved " .. count .. " talents of " .. tostring(class) .. ". Type /reload or log out to write the file.")
  return true
end

----------------------------------------------------------------------
-- Other client languages: Locale\<locale>.lua fills
--   AT.SpellNames  English spell name -> name of the client
--   AT.TextFixes   { Lua pattern, replacement } for parts of the text the game gets wrong
--   AT.TextRu      English talent name -> { text = new description with {1} {2}, name = new title }
----------------------------------------------------------------------

local nameMap, nameOrder, mapHasTabs

-- the name the client shows for an English spell name (the English name if unknown)
function AT.GetSpellName(english)
  local names = AT.SpellNames
  return names and names[english] or english
end

-- spell names plus the names of the talent trees of this class (they are in the texts too)
local function BuildMap()
  nameMap = {}
  for english, local_ in pairs(AT.SpellNames) do nameMap[english] = local_ end
  mapHasTabs = false
  local d = ClassData()
  if d and d.tabs and GetNumTalentTabs() > 0 then
    for i = 1, table.getn(d.tabs) do
      local localTab = GetTalentTabInfo(i)
      if localTab and localTab ~= "" then
        if not nameMap[d.tabs[i]] then nameMap[d.tabs[i]] = localTab end
        mapHasTabs = true
      end
    end
  end
  nameOrder = {}
  for english in pairs(nameMap) do table.insert(nameOrder, english) end
  table.sort(nameOrder, function(a, b)
    if string.len(a) ~= string.len(b) then return string.len(a) > string.len(b) end
    return a < b
  end)
end

local function HasCyrillic(text)
  return string.find(text, "[\208\209]") ~= nil
end

-- replaces English spell names in a line of the client's text with the client's names
-- (lines without any Russian letters are not touched)
function AT.Localize(text)
  if not AT.SpellNames or not text or not HasCyrillic(text) then return text end
  if not nameMap or not mapHasTabs then BuildMap() end
  for i = 1, table.getn(nameOrder) do
    local english = nameOrder[i]
    local from = 1
    while true do
      local s, e = string.find(text, english, from, true)
      if not s then break end
      local before = string.sub(text, s - 1, s - 1)
      local after = string.sub(text, e + 1, e + 1)
      if (s > 1 and string.find(before, "[A-Za-z]")) or string.find(after, "[A-Za-z]") then
        from = e + 1
      else
        local replacement = nameMap[english]
        text = string.sub(text, 1, s - 1) .. replacement .. string.sub(text, e + 1)
        from = s + string.len(replacement)
      end
    end
  end
  if AT.TextFixes then
    for i = 1, table.getn(AT.TextFixes) do
      local fix = AT.TextFixes[i]
      text = string.gsub(text, fix[1], fix[2])
    end
  end
  return text
end

local function IsYellow(fs)
  local r, g, b = fs:GetTextColor()
  return r and r > 0.9 and g > 0.7 and g < 0.95 and b < 0.3
end

local function Fill(template, values)
  return (string.gsub(template, "{(%d+)}", function(n) return tostring(values[tonumber(n)]) end))
end

-- the game splits the description of a talent into many lines: rebuild the tooltip with one description line
local function RebuildSingle(tooltip, text)
  local lines = {}
  for i = 1, tooltip:NumLines() do
    local l = getglobal("GameTooltipTextLeft" .. i)
    local r = getglobal("GameTooltipTextRight" .. i)
    local lr, lg, lb = l:GetTextColor()
    local rr, rg, rb = r:GetTextColor()
    table.insert(lines, { l:GetText() or "", r:GetText() or "", lr, lg, lb, rr, rg, rb, IsYellow(l) })
  end
  tooltip:ClearLines()
  local done = false
  for i = 1, table.getn(lines) do
    local x = lines[i]
    if x[9] then
      if not done then
        done = true
        tooltip:AddLine(text, 1, 0.82, 0, 1)
      end
    elseif x[2] ~= "" then
      tooltip:AddDoubleLine(x[1], x[2], x[3], x[4], x[5], x[6], x[7], x[8])
    else
      tooltip:AddLine(x[1], x[3], x[4], x[5])
    end
  end
end

-- puts our own Russian text into the tooltip of a talent whose description in the game is outdated
local function ApplyOverride(tooltip, tab, index)
  if not AT.TextRu then return end
  local _, _, tier, column, rank, maxRank = GetTalentInfo(tab, index)
  local english = EnglishName(tab, tier, column)
  local o = english and AT.TextRu[english]
  if not o then return end
  local shown = rank or 0
  if shown < 1 then shown = 1 end
  if o.single then
    local values = AT.GetValues(english, 1)
    if values then RebuildSingle(tooltip, Fill(o.text, values)) end
    return
  end
  local yellow = 0
  for i = 1, tooltip:NumLines() do
    local left = getglobal("GameTooltipTextLeft" .. i)
    if o.name and i == 1 then left:SetText(o.name) end
    if left and left:GetText() and IsYellow(left) then
      yellow = yellow + 1
      local r = shown + yellow - 1
      local values = AT.GetValues(english, r)
      if values and r <= (maxRank or r) then left:SetText(Fill(o.text, values)) end
    end
  end
end

-- talent tooltips mention spells by their English name: show the client's names
local origSetTalent = GameTooltip.SetTalent
GameTooltip.SetTalent = function(self, tab, index)
  origSetTalent(self, tab, index)
  if not AT.SpellNames then return end
  ApplyOverride(self, tab, index)
  for i = 1, self:NumLines() do
    for _, side in ipairs({ "Left", "Right" }) do
      local fs = getglobal("GameTooltipText" .. side .. i)
      local text = fs and fs:GetText()
      if text then
        local changed = AT.Localize(text)
        if changed ~= text then fs:SetText(changed) end
      end
    end
  end
  self:Show()
end

-- /adet check: English words that are still left in the tooltips of this class after translating
function AT.Check()
  if not AT.SpellNames then
    Msg("nothing to check: this client language has no translation file")
    return
  end
  if not ready then
    Msg("talents are not read yet")
    return
  end
  local left, seen, count = {}, {}, 0
  for tab = 1, GetNumTalentTabs() do
    for index = 1, GetNumTalents(tab) do
      local _, _, tier, column = GetTalentInfo(tab, index)
      local english = EnglishName(tab, tier, column)
      if not (AT.TextRu and AT.TextRu[english]) then
        local lines = ReadTip(tab, index)
        for i = 1, table.getn(lines) do
          local text = AT.Localize(lines[i])
          if string.len(text) >= 1000 and not seen["long" .. english] then
            seen["long" .. english] = true
            count = count + 1
            table.insert(left, english .. ": TEXT TOO LONG, the game cuts it")
          end
          if HasCyrillic(text) then
            string.gsub(text, "[A-Za-z][A-Za-z][A-Za-z]+", function(word)
              if not seen[word .. english] then
                seen[word .. english] = true
                count = count + 1
                table.insert(left, (english or "?") .. ": " .. word)
              end
            end)
          end
        end
      end
    end
  end
  local _, class = UnitClass("player")
  AdeTalentsDB = AdeTalentsDB or {}
  AdeTalentsDB.check = AdeTalentsDB.check or {}
  AdeTalentsDB.check[class] = left
  Msg("untranslated English words left: " .. count .. " (saved, /reload writes the file)")
  for i = 1, math.min(count, 15) do DEFAULT_CHAT_FRAME:AddMessage("  " .. left[i]) end
end

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------

local function List()
  if not ready then
    Msg("talents are not read yet")
    return
  end
  local tabs = GetNumTalentTabs()
  for tab = 1, tabs do
    local tabName, icon, points = GetTalentTabInfo(tab)
    Msg(tostring(tabName) .. " (" .. tostring(points) .. " points)")
    for i = 1, GetNumTalents(tab) do
      local name, icon2, tier, column, rank, maxRank = GetTalentInfo(tab, i)
      if name and rank and rank > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("  " .. name .. " " .. rank .. "/" .. maxRank)
      end
    end
  end
end

-- finds a talent by its English name or by the name the client shows
local function FindName(query)
  local exact = query
  query = string.lower(query)
  for name in pairs(ranks) do
    if string.lower(name) == query then return name end
  end
  for name, localName in pairs(localNames) do
    if localName == exact or string.lower(localName) == query then return name end
  end
  return nil
end

local function ShowEffect(query)
  local name = FindName(query)
  if not name then
    Msg("no talent named '" .. query .. "' in your class")
    return
  end
  Msg(name .. ": rank " .. (ranks[name] or 0) .. "/" .. tostring(maxranks[name]))
  if not AT.GetData(name) then
    DEFAULT_CHAT_FRAME:AddMessage("  no data for this talent")
    return
  end
  local e = AT.GetEffect(name)
  if not e then
    DEFAULT_CHAT_FRAME:AddMessage("  no points spent: no effect")
    return
  end
  DEFAULT_CHAT_FRAME:AddMessage("  [" .. tostring(e.confidence) .. "] " .. tostring(e.text))
end

SLASH_ADETALENTS1 = "/adet"
SLASH_ADETALENTS2 = "/adetalents"
SlashCmdList["ADETALENTS"] = function(msg)
  msg = msg or ""
  local lower = string.lower(msg)
  if lower == "dump" then
    AT.Dump()
  elseif lower == "list" then
    List()
  elseif lower == "check" then
    AT.Check()
  elseif string.find(lower, "^effect%s") then
    ShowEffect(string.sub(msg, 8))
  else
    Msg("v" .. AT.version)
    DEFAULT_CHAT_FRAME:AddMessage("  /adet list - talents you have points in")
    DEFAULT_CHAT_FRAME:AddMessage("  /adet effect <talent> - what the talent does at your current rank")
    DEFAULT_CHAT_FRAME:AddMessage("  /adet check - English words left in the translated tooltips (not English clients)")
    DEFAULT_CHAT_FRAME:AddMessage("  /adet dump - save every talent tooltip of this class to the saved variables file")
  end
end
