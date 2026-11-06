-- Ade Alts: core
AdeAlts = {}
local AA = AdeAlts

-- AdeAlts : profession cooldown tracker for Turtle WoW / 1.12 clients (Lua 5.0)
-- Tracks Salt Shaker, Transmutes, Mooncloth (and any "Transmute: ..." recipe) per character.
-- Command: /pcd   Minimap button: auto-docked by pfUI's addon button panel.

AA.ADDON  = "AdeAlts"
AA.VERSION = "1.3.0"
AA.PREFIX = "PCDT"
AA.DAY = 86400
AA.RDATA = {}      -- recipe database, filled by the data_*.lua files
local HOUR = 3600

-- Fallback durations (seconds). The real remaining time is read from the recipe tooltip when possible.
AA.DEFAULTS = {
  ["Mooncloth"]                      = 4 * AA.DAY,
  ["Transmute: Arcanite"]            = 2 * AA.DAY,
  ["Transmute: Iron to Gold"]        = 2 * AA.DAY,
  ["Transmute: Mithril to Truesilver"] = 2 * AA.DAY,
}

-- Items tracked through their bag cooldown.
AA.ITEMS = {
  [15846] = { key = "Salt Shaker", cd = 3 * AA.DAY },
}

-- max possible cooldown per item key; anything beyond it is a bogus client value
local ITEMCD = {}
AA.ITEMNAME = {}
for id, it in pairs(AA.ITEMS) do ITEMCD[it.key] = it.cd; AA.ITEMNAME[string.lower(it.key)] = it end

function AA.ClampRecord(c)
  local changed = false
  local lim = time()
  for key, cd in pairs(ITEMCD) do
    local e = c.cds and c.cds[key]
    if e and e > lim + cd + 60 then
      c.cds[key] = lim + cd
      changed = true
    end
  end
  return changed
end

-- the hunter "Survival" talent tree is also a skill line (rank 1/1); the real profession has a max of 75+
function AA.BadProf(name, maxr)
  return name == "Survival" and (not maxr or maxr <= 1)
end

-- professions without a recipe list (nothing to scan)
AA.NORECIPES = { Fishing = 1, Skinning = 1, Herbalism = 1 }

AA.timers = {}
AA.prov = {}
local alerted = {}
AA.scanning, AA.dirty = false, false
AA.lastScan, AA.lastReply, AA.lastBroadcast = 0, 0, 0
AA.bagDirty = false
AA.loaded = false
AA.fileDirty, AA.lastFileWrite = false, 0
AA.LEGACY = "ProfCDTracker"
AA.FILE = "AdeAlts"   -- <WoW folder>\imports\AdeAlts.txt (SuperWoW)

----------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------
function AA.Print(m)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccAdeAlts|r: " .. m)
end

function AA.After(sec, fn)
  table.insert(AA.timers, { t = GetTime() + sec, fn = fn })
end

function AA.IsTracked(name)
  return AA.DEFAULTS[name] or string.find(name, "^Transmute")
end

function AA.FormatTime(s)
  s = math.floor(s)
  local d = math.floor(s / AA.DAY)
  local h = math.floor(math.mod(s, AA.DAY) / HOUR)
  local m = math.floor(math.mod(s, HOUR) / 60)
  if d > 0 then return d .. "d " .. h .. "h" end
  if h > 0 then return h .. "h " .. m .. "m" end
  if m > 0 then return m .. "m" end
  return s .. "s"
end

function AA.ClassHex(class)
  local col = RAID_CLASS_COLORS and class and RAID_CLASS_COLORS[class]
  if col then
    return string.format("%02x%02x%02x", math.floor(col.r * 255), math.floor(col.g * 255), math.floor(col.b * 255))
  end
  return "ffffff"
end

function AA.ParseDuration(text)
  local total, found = 0, false
  for n, u in string.gfind(text, "(%d+)%s*(%a+)") do
    n = tonumber(n)
    u = string.lower(u)
    local fm
    if string.find(u, "^d") then fm = AA.DAY
    elseif string.find(u, "^h") then fm = HOUR
    elseif string.find(u, "^m") then fm = 60
    elseif string.find(u, "^s") then fm = 1 end
    if AA.f then total = total + n * AA.f; found = true end
  end
  if found then return total end
  return nil
end

function AA.SetCD(key, exp)
  if not AA.me then return end
  exp = math.floor(exp)
  local old = AA.me.cds[key]
  if old == nil or math.abs(old - exp) > 5 or ((old == 0) ~= (exp == 0)) then
    AA.me.cds[key] = exp
    AA.me.updated = time()
    AA.dirty = true
  end
end

