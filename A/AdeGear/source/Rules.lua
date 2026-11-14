-- Step 2: can this character use the item, and which slot would it replace?
--
-- What you can use "right now" is read from the game (skill list: weapon skills and armor
-- proficiencies, spell book: Dual Wield). The class tables below only decide the wording:
-- "never", "learn it at level N" or "train it". If your server differs, fix the tables.

local AG = AdeGear
local Rules = {}
AG.Rules = Rules

local CLASS_PLURAL = {
  WARRIOR = "Warriors", PALADIN = "Paladins", HUNTER = "Hunters", ROGUE = "Rogues", PRIEST = "Priests",
  SHAMAN = "Shamans", MAGE = "Mages", WARLOCK = "Warlocks", DRUID = "Druids",
}

-- level at which the class gets the armor type (missing = never)
local ARMOR_LEVEL = {
  WARRIOR = { Cloth = 1, Leather = 1, Mail = 1, Plate = 40 },
  PALADIN = { Cloth = 1, Leather = 1, Mail = 1, Plate = 40 },
  HUNTER = { Cloth = 1, Leather = 1, Mail = 40 },
  SHAMAN = { Cloth = 1, Leather = 1, Mail = 40 },
  ROGUE = { Cloth = 1, Leather = 1 },
  DRUID = { Cloth = 1, Leather = 1 },
  PRIEST = { Cloth = 1 }, MAGE = { Cloth = 1 }, WARLOCK = { Cloth = 1 },
}

-- name of the proficiency in the skill list
local ARMOR_SKILL = { Cloth = "Cloth", Leather = "Leather", Mail = "Mail", Plate = "Plate Mail" }

-- weapon skills a class can learn
local WEAPONS = {
  WARRIOR = { "Axes", "Two-Handed Axes", "Maces", "Two-Handed Maces", "Swords", "Two-Handed Swords", "Daggers",
    "Fist Weapons", "Polearms", "Staves", "Bows", "Crossbows", "Guns", "Thrown" },
  PALADIN = { "Axes", "Two-Handed Axes", "Maces", "Two-Handed Maces", "Swords", "Two-Handed Swords", "Polearms" },
  HUNTER = { "Axes", "Two-Handed Axes", "Daggers", "Fist Weapons", "Polearms", "Staves", "Swords",
    "Two-Handed Swords", "Bows", "Crossbows", "Guns", "Thrown" },
  ROGUE = { "Axes", "Daggers", "Fist Weapons", "Maces", "Swords", "Bows", "Crossbows", "Guns", "Thrown" },
  PRIEST = { "Maces", "Daggers", "Staves", "Wands" },
  SHAMAN = { "Axes", "Two-Handed Axes", "Daggers", "Fist Weapons", "Maces", "Two-Handed Maces", "Staves" },
  MAGE = { "Daggers", "Swords", "Staves", "Wands" },
  WARLOCK = { "Daggers", "Swords", "Staves", "Wands" },
  DRUID = { "Daggers", "Fist Weapons", "Maces", "Two-Handed Maces", "Staves", "Polearms" },
}

local SHIELD_CLASS = { WARRIOR = true, PALADIN = true, SHAMAN = true }
local RELIC = { PALADIN = "Libram", DRUID = "Idol", SHAMAN = "Totem" }
local DUAL_LEVEL = { ROGUE = 10, WARRIOR = 20, HUNTER = 20, SHAMAN = 40 }

local ARMOR_SLOTS = {
  HEAD = true, SHOULDER = true, CHEST = true, WRIST = true, HANDS = true, WAIST = true, LEGS = true, FEET = true,
}

local WEAPON_SKILL = {
  Axe = "Axes", Mace = "Maces", Sword = "Swords", Dagger = "Daggers", ["Fist Weapon"] = "Fist Weapons",
  Polearm = "Polearms", Staff = "Staves", Bow = "Bows", Crossbow = "Crossbows", Gun = "Guns",
  Wand = "Wands", Thrown = "Thrown",
}

local SLOT_ID = {
  HEAD = 1, NECK = 2, SHOULDER = 3, SHIRT = 4, CHEST = 5, WAIST = 6, LEGS = 7, FEET = 8, WRIST = 9,
  HANDS = 10, BACK = 15, TABARD = 19,
}

local SLOT_LABEL = {
  [0] = "Ammo",
  [1] = "Head", [2] = "Neck", [3] = "Shoulder", [4] = "Shirt", [5] = "Chest", [6] = "Waist", [7] = "Legs",
  [8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Finger 1", [12] = "Finger 2", [13] = "Trinket 1",
  [14] = "Trinket 2", [15] = "Back", [16] = "Main hand", [17] = "Off hand", [18] = "Ranged", [19] = "Tabard",
}
Rules.SlotLabel = SLOT_LABEL

local function Has(list, name)
  for i = 1, table.getn(list or {}) do
    if list[i] == name then return true end
  end
  return false
end

----------------------------------------------------------------------
-- What the character knows (read from the game, cached until it changes)
----------------------------------------------------------------------

local state = { dirty = true, skills = nil, spells = {}, ignoreUntil = 0 }

local function ReadSkills()
  if SkillFrame and SkillFrame:IsVisible() then return state.skills end
  local n = GetNumSkillLines()
  if not n or n < 1 then return nil end
  -- skills inside closed headers are not listed, so open all headers and close them again
  local closed, any = {}, false
  for i = 1, n do
    local name, header, expanded = GetSkillLineInfo(i)
    if header and not expanded then closed[name] = true; any = true end
  end
  if any then ExpandSkillHeader(0) end
  local set = {}
  n = GetNumSkillLines()
  for i = 1, n do
    local name, header, _, rank = GetSkillLineInfo(i)
    if name and not header then set[name] = tonumber(rank) or true end
  end
  if any then
    for i = GetNumSkillLines(), 1, -1 do
      local name, header = GetSkillLineInfo(i)
      if header and closed[name] then CollapseSkillHeader(i) end
    end
    state.ignoreUntil = GetTime() + 1
  end
  return set
end

local function ReadSpells()
  local set = {}
  local i = 1
  while true do
    local name = GetSpellName(i, BOOKTYPE_SPELL)
    if not name then break end
    set[name] = true
    i = i + 1
  end
  return set
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:SetScript("OnEvent", function()
  if event == "SKILL_LINES_CHANGED" and GetTime() < state.ignoreUntil then return end
  state.dirty = true
end)

function Rules.Context()
  local _, class = UnitClass("player")
  if state.dirty then
    state.dirty = false
    state.skills = ReadSkills()
    state.spells = ReadSpells()
  end
  return {
    class = class,
    level = UnitLevel("player"),
    skills = state.skills,   -- nil when the skill list could not be read
    dual = state.spells["Dual Wield"] and true or false,
  }
end

----------------------------------------------------------------------
-- Can the character use the item?
-- returns { state, lines, level }
--   state: ok, itemlevel (ok later), train, level (class gets it later), never, classlock, notgear
----------------------------------------------------------------------

local RANK = { ok = 1, itemlevel = 2, train = 3, need = 3, prof = 3, level = 4, never = 5, classlock = 5, notgear = 6 }

local function Worse(res, st, line, level)
  if RANK[st] > RANK[res.state] then
    res.state = st
    res.level = level
  end
  table.insert(res.lines, line)
end

local function Plural(class)
  return CLASS_PLURAL[class] or class
end

local function CheckWeaponSkill(res, ctx, skill)
  if ctx.skills then
    if ctx.skills[skill] then return end
    if Has(WEAPONS[ctx.class], skill) then
      Worse(res, "train", "You haven't learned " .. skill .. " yet, train it at a weapon master.")
    else
      Worse(res, "never", Plural(ctx.class) .. " can't use " .. skill .. ".")
    end
  else
    if not Has(WEAPONS[ctx.class], skill) then
      Worse(res, "never", Plural(ctx.class) .. " can't use " .. skill .. ".")
    end
  end
end

function Rules.Check(item, ctx)
  local res = { state = "ok", lines = {} }
  if not item or not item.slot or item.bag then
    res.state = "notgear"
    table.insert(res.lines, "This is not something you wear.")
    return res
  end

  if item.classes and not item.classes[ctx.class] then
    Worse(res, "classlock", "This item is only for other classes.")
  end

  local slot = item.slot

  -- profession needed to wear it: "Requires Cooking (130)"
  if item.reqSkill and ctx.skills then
    local rs = item.reqSkill
    local have = ctx.skills[rs.name]
    if not have then
      Worse(res, "prof", "You need " .. rs.name .. " (" .. rs.level .. ") to wear this, you don't have that profession.")
    elseif type(have) == "number" and have < rs.level then
      Worse(res, "prof", "You need " .. rs.name .. " " .. rs.level .. " to wear this, you have " .. have .. ".")
    end
  end

  -- ammunition needs a ranged weapon that fires it
  if slot == "AMMO" then
    local rw = AG.Items.FromSlot(18)
    local kind = rw and rw.weaponKind
    local fires = nil
    if kind == "Gun" then fires = "Bullet" elseif kind == "Bow" or kind == "Crossbow" then fires = "Arrow" end
    if not fires then
      Worse(res, "need", "Equip a bow, crossbow or gun first, then you can use ammunition.")
    elseif item.ammoKind and item.ammoKind ~= fires then
      Worse(res, "need", "Your " .. string.lower(kind) .. " fires " .. string.lower(fires) .. "s, this is " .. string.lower(item.ammoKind) .. "s.")
    end
  end

  -- armor type
  if ARMOR_SLOTS[slot] and item.armorKind and ARMOR_SKILL[item.armorKind] then
    local kind = item.armorKind
    local skill = ARMOR_SKILL[kind]
    local gate = ARMOR_LEVEL[ctx.class] and ARMOR_LEVEL[ctx.class][kind]
    local known = ctx.skills and ctx.skills[skill]
    if not known then
      if not gate then
        Worse(res, "never", Plural(ctx.class) .. " can't wear " .. kind .. ".")
      elseif ctx.level < gate then
        Worse(res, "level", Plural(ctx.class) .. " learn " .. skill .. " at level " .. gate .. ", you are level " .. ctx.level .. ".", gate)
      end
      -- level is high enough: armor proficiencies come with the level, no training needed
    end
  end

  -- shield
  if item.armorKind == "Shield" then
    local known = ctx.skills and ctx.skills["Shield"]
    if not known and not SHIELD_CLASS[ctx.class] then
      Worse(res, "never", Plural(ctx.class) .. " can't use shields.")
    end
  end

  -- libram, idol, totem
  if item.armorKind == "Libram" or item.armorKind == "Idol" or item.armorKind == "Totem" then
    if RELIC[ctx.class] ~= item.armorKind then
      Worse(res, "never", Plural(ctx.class) .. " can't use " .. string.lower(item.armorKind) .. "s.")
    end
  end

  -- weapons
  if item.weaponKind and WEAPON_SKILL[item.weaponKind] then
    local skill = WEAPON_SKILL[item.weaponKind]
    if slot == "TWOHAND" and (item.weaponKind == "Axe" or item.weaponKind == "Mace" or item.weaponKind == "Sword") then
      skill = "Two-Handed " .. skill
    end
    CheckWeaponSkill(res, ctx, skill)

    if slot == "OFFHAND" and not ctx.dual then
      local gate = DUAL_LEVEL[ctx.class]
      if not gate then
        Worse(res, "never", Plural(ctx.class) .. " can't dual wield.")
      elseif ctx.level < gate then
        Worse(res, "level", Plural(ctx.class) .. " learn Dual Wield at level " .. gate .. ", you are level " .. ctx.level .. ".", gate)
      else
        Worse(res, "train", "You haven't learned Dual Wield yet.")
      end
    end
  end

  if item.reqLevel and item.reqLevel > ctx.level then
    Worse(res, "itemlevel", "You need level " .. item.reqLevel .. " to wear it, you are level " .. ctx.level .. ".", item.reqLevel)
  end

  if res.state == "ok" then table.insert(res.lines, "You can use this item.") end
  return res
end

----------------------------------------------------------------------
-- Where would the item go, and what does it replace?
-- returns a list of { slot = id, label, equipped = item or nil, notes = { text } }
----------------------------------------------------------------------

function Rules.Targets(item, ctx, getEquipped)
  getEquipped = getEquipped or AG.Items.FromSlot
  local out = {}
  if not item or not item.slot then return out end

  local function add(id)
    local t = { slot = id, label = SLOT_LABEL[id], equipped = getEquipped(id), notes = {} }
    table.insert(out, t)
    return t
  end

  local s = item.slot
  if s == "FINGER" then
    add(11); add(12)
  elseif s == "TRINKET" then
    add(13); add(14)
  elseif s == "ONEHAND" then
    local main = add(16)
    local mh = main.equipped
    if mh and mh.slot == "TWOHAND" then
      table.insert(main.notes, "replaces your two-hander")
    end
    if item.weaponKind and ctx.dual then
      local off = add(17)
      if mh and mh.slot == "TWOHAND" then
        table.insert(off.notes, "you need a one-hander in the main hand first")
      end
    end
  elseif s == "MAINHAND" then
    add(16)
  elseif s == "TWOHAND" then
    local main = add(16)
    local oh = getEquipped(17)
    if oh then table.insert(main.notes, "also takes off your off hand: " .. oh.name) end
  elseif s == "OFFHAND" then
    local off = add(17)
    local mh = getEquipped(16)
    if mh and mh.slot == "TWOHAND" and item.weaponKind then
      table.insert(off.notes, "can't be used with a two-hander in the main hand")
    end
  elseif s == "HELD" then
    add(17)
  elseif s == "RANGED" then
    add(18)
  elseif s == "AMMO" then
    add(0)
  elseif SLOT_ID[s] then
    add(SLOT_ID[s])
  end
  return out
end
