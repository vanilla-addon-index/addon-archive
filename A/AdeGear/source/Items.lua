-- Step 1: reads an item tooltip and turns it into a table.
-- Parse() works on plain text lines, so it can be tested without the game.
--
-- item = {
--   name, quality (0-5), slot ("CHEST", "ONEHAND", "TWOHAND", "FINGER" ...), slotText,
--   armorKind ("Cloth" "Leather" "Mail" "Plate" "Shield" "Libram" "Idol" "Totem"),
--   weaponKind ("Sword" "Dagger" "Bow" "Wand" ...),
--   weapon = { min, max, speed, dps, school },
--   stats = { STR=, AGI=, STA=, INT=, SPI=, ARMOR=, AP=, SP=, HEAL=, CRIT=, HIT=, MP5=, ... },
--   reqLevel, classes = { PRIEST = true }, setName, setBonus = { lines },
--   special = { "Equip: ...", "Use: ..." }   -- effects that are not numbers we understand
--   unparsed = { "..." }                      -- lines we could not read at all
-- }

local AG = AdeGear
local Items = {}
AG.Items = Items

local STATS = { Strength = "STR", Agility = "AGI", Stamina = "STA", Intellect = "INT", Spirit = "SPI" }
local ENCHANT = { Armor = "ARMOR", Health = "HEALTH", Mana = "MANA", Defense = "DEFENSE" }

local SLOT_TEXT = {
  ["Head"] = "HEAD", ["Neck"] = "NECK", ["Shoulder"] = "SHOULDER", ["Back"] = "BACK",
  ["Chest"] = "CHEST", ["Robe"] = "CHEST", ["Shirt"] = "SHIRT", ["Tabard"] = "TABARD",
  ["Wrist"] = "WRIST", ["Hands"] = "HANDS", ["Waist"] = "WAIST", ["Legs"] = "LEGS",
  ["Feet"] = "FEET", ["Finger"] = "FINGER", ["Trinket"] = "TRINKET",
  ["One-Hand"] = "ONEHAND", ["Two-Hand"] = "TWOHAND", ["Main Hand"] = "MAINHAND",
  ["Off Hand"] = "OFFHAND", ["Held In Off-hand"] = "HELD",
  ["Ranged"] = "RANGED", ["Thrown"] = "RANGED", ["Relic"] = "RANGED",
}

local WEAPON_KIND = {
  ["Axe"] = 1, ["Mace"] = 1, ["Sword"] = 1, ["Dagger"] = 1, ["Fist Weapon"] = 1, ["Polearm"] = 1,
  ["Staff"] = 1, ["Bow"] = 1, ["Crossbow"] = 1, ["Gun"] = 1, ["Wand"] = 1, ["Thrown"] = 1,
  ["Fishing Pole"] = 1, ["Miscellaneous"] = 1,
}

local ARMOR_KIND = {
  ["Cloth"] = 1, ["Leather"] = 1, ["Mail"] = 1, ["Plate"] = 1, ["Shield"] = 1,
  ["Idol"] = 1, ["Libram"] = 1, ["Totem"] = 1, ["Miscellaneous"] = 1,
}

-- "Equip:" lines whose numbers we understand: { pattern, stat key }
local EQUIP = {
  { "^Equip: When struck in combat inflicts (%d+) %a+ damage to the attacker%.?$", "THORNS" },
  { "^Equip: Increases attack power by (%d+)%.?$", "AP" },
  { "^Equip: %+(%d+) Attack Power%.?$", "AP" },
  { "^Equip: Increases ranged attack power by (%d+)%.?$", "RAP" },
  { "^Equip: %+(%d+) ranged Attack Power%.?$", "RAP" },
  { "^Equip: Increases damage and healing done by magical spells and effects by up to (%d+)%.?$", "SP" },
  { "^Equip: Increases healing done by spells and effects by up to (%d+)%.?$", "HEAL" },
  { "^Equip: Improves your chance to get a critical strike with spells by (%d+%.?%d*)%%%.?$", "SPELLCRIT" },
  { "^Equip: Improves your chance to hit with spells by (%d+%.?%d*)%%%.?$", "SPELLHIT" },
  { "^Equip: Improves your chance to get a critical strike by (%d+%.?%d*)%%%.?$", "CRIT" },
  { "^Equip: Improves your chance to hit by (%d+%.?%d*)%%%.?$", "HIT" },
  { "^Equip: Restores (%d+) mana per 5 sec%.?$", "MP5" },
  { "^Equip: Allows (%d+)%% of your Mana regeneration to continue while casting%.?$", "CASTREGEN" },
  { "^Equip: Restores (%d+) health per 5 sec%.?$", "HP5" },
  { "^Equip: Increases your chance to dodge an attack by (%d+%.?%d*)%%%.?$", "DODGE" },
  { "^Equip: Increases your chance to parry an attack by (%d+%.?%d*)%%%.?$", "PARRY" },
  { "^Equip: Increases your chance to block attacks with a shield by (%d+%.?%d*)%%%.?$", "BLOCK" },
  { "^Equip: Increases the block value of your shield by (%d+)%.?$", "BLOCKVAL" },
  { "^Equip: Increased Defense %+(%d+)%.?$", "DEFENSE" },
}

-- plain lines (enchants and base values): { pattern, stat key }
local PLAIN = {
  { "^(%d+) Armor$", "ARMOR" },
  { "^%+(%d+) Armor$", "ARMOR" },
  { "^Armor %+(%d+)$", "ARMOR" },
  { "^Health %+(%d+)$", "HEALTH" },
  { "^(%d+) Block$", "BLOCKVAL" },
  { "^%+(%d+) Attack Power$", "AP" },
  { "^%+(%d+) Healing Spells$", "HEAL" },
  { "^%+(%d+) Spell Damage$", "SP" },
  { "^%+(%d+) Mana$", "MANA" },
  { "^%+(%d+) Health$", "HEALTH" },
  { "^%+(%d+) Defense$", "DEFENSE" },
  { "^Mana Regen %+(%d+) per 5 sec%.?$", "MP5" },
  { "^%+(%d+) health every 5 sec%.?$", "HP5" },
  { "^%+(%d+) mana every 5 sec%.?$", "MP5" },
}

local SKIP = {
  "^Binds when", "^Soulbound", "^Unique", "^Durability", "^Quest Item", "^Conjured", "^Sell Price",
  "^Heroic", "^Requires Level", "^Classes:", "^\"", "^Item Level", "^This Item Begins",
  "^<Right Click", "^Right Click", "^Not yet", "^Already known", "^Cooldown", "^Charges",
  -- reputation requirement: "Requires Wildhammer Clan -- Revered"
  "^Requires .+ %-%- Neutral", "^Requires .+ %-%- Friendly", "^Requires .+ %-%- Honored",
  "^Requires .+ %-%- Revered", "^Requires .+ %-%- Exalted",
  -- tools and shield spikes, nothing to value
  "^Mining %+", "^Skinning %+", "^Herbalism %+", "^Fishing %+", "^Iron Spike",
}

local function Clean(t)
  if not t then return "" end
  t = string.gsub(t, "|c%x%x%x%x%x%x%x%x", "")
  t = string.gsub(t, "|r", "")
  t = string.gsub(t, "^%s+", "")
  t = string.gsub(t, "%s+$", "")
  return t
end

local function Add(stats, key, value)
  stats[key] = (stats[key] or 0) + value
end

-- quality from the color of the name line
function Items.QualityOf(c)
  if not c then return 1 end
  local best, bestD = 1, 99
  for q = 0, 5 do
    local qc = AG.Q[q]
    local d = math.abs(qc[1] - c[1]) + math.abs(qc[2] - c[2]) + math.abs(qc[3] - c[3])
    if d < bestD then best, bestD = q, d end
  end
  return best
end

local function UpperKey(text)
  text = string.upper(text)
  text = string.gsub(text, "[^%w]+", "_")
  return text
end

local function ClassList(text)
  local set = {}
  for name in string.gfind(text, "(%a+)") do
    set[string.upper(name)] = true
  end
  return set
end

local ParseText

-- stats of a short text such as "+15 Strength." or "Improves your chance to hit by 1%."
local function StatsOfText(text)
  local plain = string.gsub(text, "%.$", "")
  local tmp = { stats = {}, special = {}, unparsed = {}, reqLevel = 0 }
  ParseText(tmp, plain)
  if next(tmp.stats) then return tmp.stats, true end
  tmp = { stats = {}, special = {}, unparsed = {}, reqLevel = 0 }
  ParseText(tmp, "Equip: " .. text)
  if next(tmp.stats) then return tmp.stats, true end
  return {}, false
end

-- set bonus line: "(6) Set: ..." (needs 6 pieces) or "Set: ..." (already active)
local function SetLine(it, t, c)
  local s, e, n, text = string.find(t, "^%((%d+)%) Set: (.+)$")
  local active
  if s then
    n = tonumber(n)
  else
    s, e, text = string.find(t, "^Set: (.+)$")
    if not s then return false end
    n = nil
    active = true
  end
  it.set = it.set or { pieces = {}, bonuses = {} }
  if active == nil then
    active = false
    if c and c[2] > c[1] + 0.3 then active = true end
  end
  local stats, ok = StatsOfText(text)
  -- a bonus that is switched off shows how many pieces it needs; a switched on one does not. The number
  -- is remembered the first time it is seen, so later the addon knows when a bonus would stop.
  local setName = it.set.name
  if setName and AdeGearDB then
    AdeGearDB.setN = AdeGearDB.setN or {}
    local key = setName .. "|" .. text
    if n then AdeGearDB.setN[key] = n elseif AdeGearDB.setN[key] then n = AdeGearDB.setN[key] end
    -- the fewest pieces it was ever seen switched on with is an upper limit for its number
    if active and it.set.have then
      AdeGearDB.setMin = AdeGearDB.setMin or {}
      local old = AdeGearDB.setMin[key]
      if not old or it.set.have < old then AdeGearDB.setMin[key] = it.set.have end
    end
  end
  local minHave = nil
  if setName and AdeGearDB and AdeGearDB.setMin then minHave = AdeGearDB.setMin[setName .. "|" .. text] end
  table.insert(it.set.bonuses, { n = n, text = text, active = active, stats = stats, understood = ok, minHave = minHave })
  it.set.inList = false
  return true
end

-- true when the line was understood (stats, requirements, ...)
-- c is the color of the line (set pieces and set bonuses use it)
ParseText = function(it, t, c)
  local s, e, c1, c2, c3

  -- names of the set pieces follow the set header; yellow = equipped
  if it.set and it.set.inList then
    if SetLine(it, t, c) then return true end
    local have = false
    if c and c[1] > 0.7 then have = true end
    table.insert(it.set.pieces, { name = t, equipped = have })
    return true
  end
  if SetLine(it, t, c) then return true end

  s, e, c1, c2 = string.find(t, "^Requires (.+) %((%d+)%)$")
  if s and not string.find(t, ",") then
    it.reqSkill = { name = c1, level = tonumber(c2) }
    return true
  end

  for i = 1, table.getn(SKIP) do
    if string.find(t, SKIP[i]) then
      -- keep the numbers of these two
      s, e, c1 = string.find(t, "^Requires Level (%d+)")
      if s then it.reqLevel = tonumber(c1) end
      s, e, c1 = string.find(t, "^Classes: (.+)$")
      if s then it.classes = ClassList(c1) end
      return true
    end
  end

  -- haste: "Increases your attack and casting speed by 1%", only attack speed, only casting speed
  s, e, c1 = string.find(t, "^Equip: Increases your attack and casting speed by (%d+%.?%d*)%%%.?$")
  if s then
    Add(it.stats, "HASTE_ATTACK", tonumber(c1))
    Add(it.stats, "HASTE_CAST", tonumber(c1))
    return true
  end
  s, e, c1 = string.find(t, "^Equip: Increases your attack speed by (%d+%.?%d*)%%%.?$")
  if s then Add(it.stats, "HASTE_ATTACK", tonumber(c1)) return true end
  s, e, c1 = string.find(t, "^Equip: Increases your casting speed by (%d+%.?%d*)%%%.?$")
  if s then Add(it.stats, "HASTE_CAST", tonumber(c1)) return true end

  -- life steal: "1% of damage dealt is returned as healing."
  s, e, c1 = string.find(t, "^Equip: (%d+%.?%d*)%% of damage dealt is returned as healing%.?$")
  if s then Add(it.stats, "LIFESTEAL", tonumber(c1)) return true end

  -- armor penetration: "Your attacks ignore 10 of the target's armor."
  s, e, c1 = string.find(t, "^Equip: Your attacks ignore (%d+) of the target's armor%.?$")
  if s then Add(it.stats, "ARMORPEN", tonumber(c1)) return true end

  s, e, c1 = string.find(t, "^Adds (%d+%.?%d*) damage per second%.?$")
  if s then it.ammoDps = tonumber(c1) return true end

  s, e, c1 = string.find(t, "^%((%d+%.?%d*) damage per second%)$")
  if s then it.dps = tonumber(c1) return true end

  s, e, c1, c2 = string.find(t, "^%+%s*(%d+) %- (%d+) (%a+) Damage$")
  if s then
    it.weapon = it.weapon or {}
    it.weapon.extra = (it.weapon.extra or 0) + (tonumber(c1) + tonumber(c2)) / 2
    return true
  end

  -- stat lines: +5 Agility, -3 Spirit
  s, e, c1, c2, c3 = string.find(t, "^([%+%-])(%d+) (%a+)$")
  if s and STATS[c3] then
    local v = tonumber(c2)
    if c1 == "-" then v = -v end
    Add(it.stats, STATS[c3], v)
    return true
  end

  -- enchant lines (green, after the stats): "Stamina +1", "Armor +30", "Fire Resistance +5"
  s, e, c1, c2 = string.find(t, "^(%a+) %+(%d+)$")
  if s then
    local key = STATS[c1] or ENCHANT[c1]
    if key then Add(it.stats, key, tonumber(c2)) return true end
  end
  s, e, c1, c2 = string.find(t, "^(%a+) Resistance %+(%d+)$")
  if s and (c1 == "Fire" or c1 == "Frost" or c1 == "Nature" or c1 == "Shadow" or c1 == "Arcane") then
    Add(it.stats, "RES_" .. string.upper(c1), tonumber(c2))
    return true
  end

  -- resistance, also a minus ("-6 Fire Resistance")
  s, e, c1, c2, c3 = string.find(t, "^([%+%-])(%d+) (%a+) Resistance$")
  if s then
    local v = tonumber(c2)
    if c1 == "-" then v = -v end
    Add(it.stats, "RES_" .. string.upper(c3), v)
    return true
  end

  -- spell damage of one school written plainly: "+14 Arcane Spell Damage"
  s, e, c1, c2 = string.find(t, "^%+(%d+) (%a+) Spell Damage$")
  if s and (c2 == "Arcane" or c2 == "Fire" or c2 == "Frost" or c2 == "Holy" or c2 == "Nature" or c2 == "Shadow") then
    Add(it.stats, "DMG_" .. string.upper(c2), tonumber(c1))
    return true
  end

  -- weapon enchant: "Weapon Damage +1" adds to every hit
  s, e, c1 = string.find(t, "^Weapon Damage %+(%d+)$")
  if s then
    it.weapon = it.weapon or {}
    it.weapon.extra = (it.weapon.extra or 0) + tonumber(c1)
    return true
  end
  s, e, c1 = string.find(t, "^%+(%d+) All Resistances$")
  if s then
    local list = { "FIRE", "FROST", "NATURE", "SHADOW", "ARCANE" }
    for i = 1, 5 do Add(it.stats, "RES_" .. list[i], tonumber(c1)) end
    return true
  end

  -- armor kit: "Reinforced Armor +24" or "Reinforced Armor +24/+3 Stamina"
  s, e, c1, c2, c3 = string.find(t, "^Reinforced Armor %+(%d+)/%+(%d+) (%a+)$")
  if s and STATS[c3] then
    Add(it.stats, "ARMOR", tonumber(c1))
    Add(it.stats, STATS[c3], tonumber(c2))
    return true
  end
  s, e, c1 = string.find(t, "^Reinforced Armor %+(%d+)$")
  if s then Add(it.stats, "ARMOR", tonumber(c1)) return true end

  for i = 1, table.getn(PLAIN) do
    s, e, c1 = string.find(t, PLAIN[i][1])
    if s then Add(it.stats, PLAIN[i][2], tonumber(c1)) return true end
  end

  for i = 1, table.getn(EQUIP) do
    s, e, c1 = string.find(t, EQUIP[i][1])
    if s then Add(it.stats, EQUIP[i][2], tonumber(c1)) return true end
  end

  s, e, c1, c2 = string.find(t, "^Equip: Increases damage done by (%a+) spells and effects by up to (%d+)%.?$")
  if s then Add(it.stats, "DMG_" .. string.upper(c1), tonumber(c2)) return true end

  s, e, c1, c2 = string.find(t, "^Equip: Increased (.+) %+(%d+)%.?$")
  if s then Add(it.stats, "SKILL_" .. UpperKey(c1), tonumber(c2)) return true end

  -- bonus that works only in druid forms
  s, e, c1 = string.find(t, "^Equip: %+(%d+) Attack Power in Cat, Bear, Dire Bear, and Moonkin forms only%.?$")
  if s then Add(it.stats, "FERAL_AP", tonumber(c1)) return true end

  -- any other "Equip: +5 All Resistances." style line: read it like the same line without "Equip:"
  s, e, c1 = string.find(t, "^Equip: (.+)$")
  if s then
    local plain = string.gsub(c1, "%.$", "")
    local tmp = { stats = {}, special = {}, unparsed = {}, reqLevel = 0 }
    ParseText(tmp, plain)
    if next(tmp.stats) then
      for k, v in pairs(tmp.stats) do Add(it.stats, k, v) end
      return true
    end
  end

  -- "60 to 100 Shadow damage": the middle value counts (the plain pattern below would take the 100)
  local lo, hi
  s, e, lo, hi = string.find(t, "^Chance on hit: .-(%d+) to (%d+) %a+ damage")
  if s then
    Add(it.stats, "PROC_DMG", (tonumber(lo) + tonumber(hi)) / 2)
    table.insert(it.special, t)
    return true
  end
  s, e, c1 = string.find(t, "^Chance on hit: .-(%d+) %a+ damage")
  if s then
    Add(it.stats, "PROC_DMG", tonumber(c1))
    table.insert(it.special, t)
    return true
  end

  if string.find(t, "^Equip:") or string.find(t, "^Use:") or string.find(t, "^Chance on hit:") then
    table.insert(it.special, t)
    return true
  end

  s, e, c1 = string.find(t, "^(%d+) Slot (.+)$")
  if s then it.bag = true return true end

  -- set header: "Dragonmaw Battlegarb (4/7)", 4 pieces equipped of 7
  s, e, c1, c2, c3 = string.find(t, "^(.+) %((%d+)/(%d+)%)$")
  if s then
    it.set = it.set or { pieces = {}, bonuses = {} }
    it.set.name, it.set.have, it.set.total = c1, tonumber(c2), tonumber(c3)
    it.set.inList = true
    return true
  end
  return false
end

-- lines: { { l = left text, r = right text or nil, c = { r, g, b } of the left text }, ... }
local function ParseLines(lines)
  local n = table.getn(lines)
  if n == 0 then return nil end
  local it = { stats = {}, special = {}, unparsed = {}, reqLevel = 0 }
  it.name = Clean(lines[1].l)
  it.quality = Items.QualityOf(lines[1].c)

  for i = 2, n do
    local l, r = Clean(lines[i].l), Clean(lines[i].r)
    if l ~= "" or r ~= "" then
      local handled = false
      if l ~= "" and r ~= "" then
        local s, e, c1, c2, c3
        local sp = nil
        s, e, sp = string.find(r, "^Speed (%d+%.?%d*)$")
        if s then
          s, e, c1, c2 = string.find(l, "^(%d+) %- (%d+) Damage$")
          if s then
            it.weapon = it.weapon or {}
            it.weapon.min, it.weapon.max, it.weapon.speed = tonumber(c1), tonumber(c2), tonumber(sp)
            handled = true
          else
            s, e, c1, c2, c3 = string.find(l, "^(%d+) %- (%d+) (%a+) Damage$")
            if s then
              it.weapon = it.weapon or {}
              it.weapon.min, it.weapon.max, it.weapon.speed = tonumber(c1), tonumber(c2), tonumber(sp)
              it.weapon.school = c3
              handled = true
            end
          end
        elseif SLOT_TEXT[l] and not it.slot then
          it.slot = SLOT_TEXT[l]
          it.slotText = l
          if WEAPON_KIND[r] then it.weaponKind = r end
          if ARMOR_KIND[r] then it.armorKind = r end
          handled = true
        end
      elseif l ~= "" and r == "" then
        if SLOT_TEXT[l] and not it.slot then
          it.slot = SLOT_TEXT[l]
          it.slotText = l
          if l == "Thrown" then it.weaponKind = "Thrown" end
          handled = true
        elseif (l == "Wand" or l == "Bow" or l == "Gun" or l == "Crossbow") and not it.slot then
          -- some tooltips show only the kind of a ranged weapon
          it.slot = "RANGED"
          it.slotText = "Ranged"
          it.weaponKind = l
          handled = true
        else
          handled = ParseText(it, l, lines[i].c)
        end
      end
      if not handled then
        local text = l
        if r ~= "" then text = l .. " | " .. r end
        table.insert(it.unparsed, text)
      end
    end
  end
  if it.set then it.set.inList = nil end
  -- ammunition: "Adds 12.5 damage per second", no slot line. Arrow or bullet from the name if the type is unknown.
  if it.ammoDps and not it.slot then
    it.slot = "AMMO"
    it.slotText = "Ammo"
    if string.find(it.name, "Arrow") then it.ammoKind = "Arrow"
    elseif string.find(it.name, "Bullet") or string.find(it.name, "Shot") then it.ammoKind = "Bullet" end
  end

  if it.weapon and it.weapon.min then
    it.weapon.avg = (it.weapon.min + it.weapon.max) / 2
    it.weapon.dps = (it.weapon.avg + (it.weapon.extra or 0)) / it.weapon.speed
    if it.dps then it.weapon.dps = it.dps end
  end
  return it
end

----------------------------------------------------------------------
-- Reading tooltips of the game
----------------------------------------------------------------------

local tip = CreateFrame("GameTooltip", "AdeGearScanTip", UIParent, "GameTooltipTemplate")
local MAXLINES = 40

-- the tooltip keeps old right-hand text, so every line is emptied first
local function Scrub()
  tip:ClearLines()
  for i = 1, MAXLINES do
    local left = getglobal("AdeGearScanTipTextLeft" .. i)
    local right = getglobal("AdeGearScanTipTextRight" .. i)
    if left then left:SetText("") end
    if right then right:SetText("") end
  end
end

-- Plans, Pattern, Recipe, Formula, Schematic: the tooltip of a recipe also shows the item it makes.
-- We judge that item, not the recipe. Falls back to the recipe itself if the item is not shown.
local RECIPE = { "^Plans?: ", "^Pattern: ", "^Recipe: ", "^Formula: ", "^Schematic: ", "^Design: " }

function Items.Parse(lines)
  local n = table.getn(lines)
  if n > 3 then
    local name = Clean(lines[1].l)
    local isRecipe = false
    for k = 1, table.getn(RECIPE) do
      if string.find(name, RECIPE[k]) then isRecipe = true end
    end
    if isRecipe then
      local use = nil
      for k = 2, n do
        if string.find(Clean(lines[k].l), "^Use: Teaches you how to") then use = k break end
      end
      if use then
        local first = nil
        for k = use + 1, n do
          if Clean(lines[k].l) ~= "" then first = k break end
        end
        if first then
          local sub = {}
          for k = first, n do
            local t = Clean(lines[k].l)
            if k > first and string.find(t, "^Requires .+%(%d+%)") then break end
            table.insert(sub, lines[k])
          end
          if table.getn(sub) > 1 then
            local it = ParseLines(sub)
            if it and it.slot then
              it.recipe = name
              return it
            end
          end
        end
      end
    end
  end
  return ParseLines(lines)
end

local function ReadLines()
  local lines = {}
  for i = 1, tip:NumLines() do
    local left = getglobal("AdeGearScanTipTextLeft" .. i)
    local right = getglobal("AdeGearScanTipTextRight" .. i)
    local l = left and left:GetText()
    local r = right and right:GetText()
    local c = nil
    if left then
      local cr, cg, cb = left:GetTextColor()
      if cr then c = { cr, cg, cb } end
    end
    if r == "" then r = nil end
    table.insert(lines, { l = l, r = r, c = c })
  end
  return lines
end

-- "item:id:enchant:suffix:unique" from a link or an item string
function Items.ItemString(link)
  if not link then return nil end
  local s, e, str = string.find(link, "(item:%d+:%d+:%d+:%d+)")
  if str then return str end
  s, e, str = string.find(link, "(item:%d+)")
  return str
end

local cache = {}

function Items.FromLink(link)
  local str = Items.ItemString(link)
  if not str then return nil end
  if cache[str] then return cache[str] end
  tip:SetOwner(UIParent, "ANCHOR_NONE")
  Scrub()
  tip:SetHyperlink(str)
  local it = Items.Parse(ReadLines())
  tip:Hide()
  if it and it.name ~= "" then
    it.link = str
    local _, _, _, _, itype, subtype, _, _, texture = GetItemInfo(str)
    it.icon = texture
    if itype == "Projectile" then
      it.slot = "AMMO"
      it.slotText = "Ammo"
      if subtype == "Arrow" or subtype == "Bullet" then it.ammoKind = subtype end
    end
    -- set pieces are read again every time: how many pieces you wear (and which bonuses are on) changes with your gear
    if not it.set then cache[str] = it end
    return it
  end
  return nil
end

-- equipped item of the player by inventory slot id (not cached: gear changes)
function Items.FromSlot(id)
  tip:SetOwner(UIParent, "ANCHOR_NONE")
  Scrub()
  local has = tip:SetInventoryItem("player", id)
  if not has then
    tip:Hide()
    return nil
  end
  local it = Items.Parse(ReadLines())
  tip:Hide()
  if it then
    it.link = GetInventoryItemLink("player", id)
    it.icon = GetInventoryItemTexture("player", id)
    if id == 0 and it.link then
      local _, _, _, _, itype, subtype = GetItemInfo(Items.ItemString(it.link) or it.link)
      if itype == "Projectile" and (subtype == "Arrow" or subtype == "Bullet") then it.ammoKind = subtype end
    end
    it.equippedSlot = id
  end
  return it
end

-- remember lines we could not read, so the parser can be extended from real items
function Items.LogUnparsed(it)
  if not it or table.getn(it.unparsed) == 0 then return end
  AdeGearDB = AdeGearDB or {}
  AdeGearDB.unparsed = AdeGearDB.unparsed or {}
  local count = 0
  for _ in pairs(AdeGearDB.unparsed) do count = count + 1 end
  for i = 1, table.getn(it.unparsed) do
    local line = it.unparsed[i]
    -- profession requirements of recipes are not gear lines
    if not AdeGearDB.unparsed[line] and count < 400 and not string.find(line, "^Requires ") then
      AdeGearDB.unparsed[line] = it.name
      count = count + 1
    end
  end
end

----------------------------------------------------------------------
-- Text for the panel and the chat
----------------------------------------------------------------------

local LABEL = {
  WEAPON_RANGED = "Ranged weapon dps", WEAPON_MELEE = "Weapon dps", AMMO_DPS = "Ammo dps",
  STR = "Strength", AGI = "Agility", STA = "Stamina", INT = "Intellect", SPI = "Spirit", ARMOR = "Armor",
  AP = "Attack power", RAP = "Ranged attack power", SP = "Spell power (all)", HEAL = "Healing power",
  FERAL_AP = "Attack power (druid forms)", CASTREGEN = "Mana regen while casting %", HASTE_ATTACK = "Attack speed %", HASTE_CAST = "Casting speed %", ARMORPEN = "Armor penetration", LIFESTEAL = "Damage returned as healing %", WEAPON_WAND = "Wand dps", WEAPON_HIT = "Average hit", SPELLCRIT = "Spell crit %", SPELLHIT = "Spell hit %", CRIT = "Crit %", HIT = "Hit %",
  MP5 = "Mana per 5 sec", HP5 = "Health per 5 sec", DODGE = "Dodge %", PARRY = "Parry %",
  BLOCK = "Block chance %", BLOCKVAL = "Block value", THORNS = "Damage to attackers", PROC_DMG = "Chance on hit damage", DEFENSE = "Defense", MANA = "Mana", HEALTH = "Health",
}

function Items.Label(key)
  if LABEL[key] then return LABEL[key] end
  local s, e, rest = string.find(key, "^RES_(.+)$")
  if s then return string.upper(string.sub(rest, 1, 1)) .. string.lower(string.sub(rest, 2)) .. " resistance" end
  s, e, rest = string.find(key, "^DMG_(.+)$")
  if s then return string.upper(string.sub(rest, 1, 1)) .. string.lower(string.sub(rest, 2)) .. " spell power" end
  s, e, rest = string.find(key, "^SKILL_(.+)$")
  if s then
    rest = string.gsub(rest, "_", " ")
    return string.upper(string.sub(rest, 1, 1)) .. string.lower(string.sub(rest, 2)) .. " skill"
  end
  return key
end

local ORDER = { "WEAPON_RANGED", "WEAPON_WAND", "WEAPON_MELEE", "WEAPON_HIT", "AMMO_DPS", "ARMOR", "STR", "AGI", "STA", "INT", "SPI", "AP", "RAP", "SP", "HEAL", "CRIT", "HIT", "SPELLCRIT", "SPELLHIT", "HASTE_ATTACK", "HASTE_CAST", "ARMORPEN", "LIFESTEAL", "MP5", "CASTREGEN", "HP5" }

-- stat keys in a stable, readable order
function Items.SortedKeys(stats)
  local keys, seen = {}, {}
  for i = 1, table.getn(ORDER) do
    if stats[ORDER[i]] then table.insert(keys, ORDER[i]); seen[ORDER[i]] = true end
  end
  local rest = {}
  for k in pairs(stats) do
    if not seen[k] then table.insert(rest, k) end
  end
  table.sort(rest)
  for i = 1, table.getn(rest) do table.insert(keys, rest[i]) end
  return keys
end

function Items.NumText(v)
  if v == math.floor(v) then return string.format("%d", v) end
  return string.format("%.1f", v)
end
