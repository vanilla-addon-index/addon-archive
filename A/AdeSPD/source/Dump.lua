-- Text dump of spell tooltips (spellbook and trainer window) for the author: with the real texts of a
-- client language the tooltip patterns of that language can be written. Saved in AdeSPDDump.
-- No '#', no '%', no select(), no string.match (Lua 5.0).

local A = AdeSPD
local try = A.try

local scanTip
local function Tip()
  if scanTip then return scanTip end
  scanTip = CreateFrame("GameTooltip", "AdeSPDScanTip", UIParent, "GameTooltipTemplate")
  return scanTip
end

local function Capture(tt)
  local out = {}
  local n = tt:NumLines() or 0
  local i
  for i = 1, n do
    local l = getglobal("AdeSPDScanTipTextLeft" .. i)
    local r = getglobal("AdeSPDScanTipTextRight" .. i)
    local a = l and l:GetText() or ""
    local b = r and r:GetText() or ""
    if b ~= "" then out[i] = a .. "  <TAB>  " .. b else out[i] = a end
  end
  return out
end

local function Store()
  if type(AdeSPDDump) ~= "table" then AdeSPDDump = {} end
  local D = AdeSPDDump
  D.locale = try(GetLocale)
  local _, build = GetBuildInfo()
  D.build = build
  if type(D.trainer) ~= "table" then D.trainer = {} end
  if type(D.book) ~= "table" then D.book = {} end
  return D
end

local function Count(t)
  local n, k = 0, nil
  for k in pairs(t) do n = n + 1 end
  return n
end

-- Every service of the open trainer window.
function A.DumpTrainer(silent)
  if type(GetNumTrainerServices) ~= "function" then return 0 end
  local D = Store()
  local tt = Tip()
  local n = GetNumTrainerServices() or 0
  local added, i = 0, nil
  for i = 1, n do
    local name, rank, category = GetTrainerServiceInfo(i)
    if name and category ~= "header" then
      tt:SetOwner(UIParent, "ANCHOR_NONE")
      tt:ClearLines()
      tt:SetTrainerService(i)
      local lines = Capture(tt)
      local desc = try(GetTrainerServiceDescription, i)
      local key = name .. "|" .. tostring(rank or "")
      local old = D.trainer[key]
      if not old then added = added + 1 end
      D.trainer[key] = { name = name, rank = rank or "", category = category, lines = lines, desc = desc }
    end
  end
  tt:Hide()
  if not silent and added > 0 then
    A.Print("trainer dump: " .. added .. " new spells saved (" .. Count(D.trainer) .. " in total). The file is written when you log out or /reload.")
  end
  return added
end

-- Every spell of your spellbook.
function A.DumpBook()
  local D = Store()
  local tt = Tip()
  local tabs = try(GetNumSpellTabs) or 0
  local t, i
  local n = 0
  for t = 1, tabs do
    local _, _, off, num = GetSpellTabInfo(t)
    for i = off + 1, off + num do
      local name, rank = GetSpellName(i, "spell")
      if name then
        tt:SetOwner(UIParent, "ANCHOR_NONE")
        tt:ClearLines()
        tt:SetSpell(i, "spell")
        local id = A.IdFor and A.IdFor(name, A.RankNum(rank)) or nil
        D.book[name .. "|" .. tostring(rank or "")] = { name = name, rank = rank or "", id = id, lines = Capture(tt) }
        n = n + 1
      end
    end
  end
  tt:Hide()
  A.Print("spellbook dump: " .. n .. " spells saved (" .. Count(D.book) .. " in total). The file is written when you log out or /reload.")
  return n
end

function A.DumpStatus()
  local D = Store()
  A.Print("dump: trainer spells " .. Count(D.trainer) .. ", spellbook spells " .. Count(D.book) .. ", language " .. tostring(D.locale)
    .. ", automatic trainer dump " .. ((A.DB.dump ~= false) and "on" or "off"))
end

function A.DumpClear()
  AdeSPDDump = {}
  A.Print("dump cleared")
end
