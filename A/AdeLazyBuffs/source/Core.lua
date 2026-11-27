-- AdeLazyBuffs core: learns which Blessing / Seal you cast on whom, keeps timers, recasts.
-- Written for the Lua 5.0 client: no '#', no '%', no select(), no string.match.
--
-- How it works
--   * Your own casts are watched (CastSpellByName / CastSpell / UseAction hooks). A cast of a Blessing,
--     Greater Blessing or Seal is confirmed when the buff icon shows up on the target (or the spell went
--     on cooldown), then remembered: who got which blessing, which seal you use.
--   * Every second a light check runs. A remembered blessing is recast out of combat when the time left
--     is under the threshold; the Seal is recast whenever you have no seal on you.
--   * Time left: on yourself it is read from the game; on others it is counted from your own cast.

local A = AdeLazyBuffs

A.DEFAULTS = {
  enabled   = true,
  auto      = true,   -- cast automatically
  seals     = true,   -- keep the seal up
  useTimer  = true,   -- rebuff by time left; off = only when the buff is gone (dispelled, cancelled)
  debug     = false,  -- print why nothing is cast
  remind    = true,   -- reminder window when a blessing is due
  remindLock = false, -- reminder window cannot be dragged
  alpha     = 1,      -- settings window background opacity
  remindSize = 14,    -- reminder text size
  remindFont = 1,     -- index in A.FONTS (Reminder.lua)
  trigger   = "any",   -- what makes a cast happen: any (key, wheel, target change), wheel, key (own key binding)
  miniHide  = false,  -- hide the minimap button
  normalAt  = 120,    -- recast a normal blessing when this many seconds are left
  greaterAt = 180,    -- recast a Greater blessing when this many seconds are left
  normalDur = 600,    -- durations, corrected from your own casts (the game reports them for yourself)
  greaterDur = 1800,
}

-- Spell recognition per class. Spell names are matched by their start (English and Russian client);
-- icon file names (lower case) are the fallback and work on any client.
-- kinds: "blessing" = single-target buff you remember per player, "greater" = group buff,
--        "self" = buff on yourself only (armors, shouts, shields), "seal" = Paladin seal (kept up in a fight).
local PROFILES = {
  PALADIN = {
    names = {
      { "greater",  { "Greater Blessing", "Великое благословение" } },
      { "blessing", { "Blessing of", "Благословение" } },
      { "seal",     { "Seal of", "Печать" } },
    },
    icons = {
      spell_holy_fistofjustice = "blessing", spell_holy_sealofwisdom = "blessing",
      spell_holy_sealofsalvation = "blessing", spell_magic_magearmor = "blessing",
      spell_nature_lightningshield = "blessing", spell_holy_prayerofhealing02 = "blessing",
      ability_thunderbolt = "seal", ability_warrior_innerrage = "seal", spell_holy_sealofwrath = "seal",
      spell_holy_healingaura = "seal", spell_holy_righteousnessaura = "seal", spell_holy_holysmite = "seal",
    },
    -- short utility blessings: never remembered
    exclude = { spell_holy_sealofprotection = true, spell_holy_sealofvalor = true, spell_holy_sealofsacrifice = true },
  },
  MAGE = {
    names = {
      { "greater",  { "Arcane Brilliance", "Чародейская гениальность" } },
      { "blessing", { "Arcane Intellect", "Чародейский интеллект" } },
      { "self",     { "Frost Armor", "Ice Armor", "Mage Armor", "Морозный доспех", "Ледяной доспех", "Магический доспех" } },
    },
    icons = {
      spell_holy_arcaneintellect = "greater", spell_holy_magicalsentry = "blessing",
      spell_frost_frostarmor02 = "self", spell_frost_frostarmor = "self", spell_magearmor = "self",
    },
  },
  PRIEST = {
    names = {
      { "greater",  { "Prayer of Fortitude", "Prayer of Spirit", "Prayer of Shadow Protection", "Молитва стойкости", "Молитва духа", "Молитва защиты от темной магии" } },
      { "blessing", { "Power Word: Fortitude", "Divine Spirit", "Shadow Protection", "Слово силы: Стойкость", "Божественный дух", "Защита от темной магии" } },
      { "self",     { "Inner Fire", "Внутренний огонь" } },
    },
    icons = {
      spell_holy_prayeroffortitude = "greater", spell_holy_prayerofspirit = "greater",
      spell_holy_prayerofshadowprotection = "greater",
      spell_holy_wordfortitude = "blessing", spell_holy_divinespirit = "blessing", spell_shadow_antishadow = "blessing",
      spell_holy_innerfire = "self",
    },
  },
  DRUID = {
    names = {
      { "greater",  { "Gift of the Wild", "Дар дикой природы" } },
      { "blessing", { "Mark of the Wild", "Thorns", "Знак дикой природы", "Шипы" } },
      { "self",     { "Omen of Clarity", "Ясность мысли" } },
    },
    icons = {
      spell_nature_giftofthewild = "greater", spell_nature_regeneration = "blessing",
      spell_nature_thorns = "blessing", spell_nature_crystalball = "self",
    },
  },
  WARLOCK = {
    names = {
      { "blessing", { "Unending Breath", "Бесконечное дыхание" } },
      { "self",     { "Demon Skin", "Demon Armor", "Демонская кожа", "Демонский доспех" } },
    },
    icons = {
      spell_shadow_demonbreath = "blessing", spell_shadow_ritualofsacrifice = "self", spell_shadow_ragingscream = "self",
    },
  },
  WARRIOR = {
    names = { { "self", { "Battle Shout", "Боевой крик" } } },
    icons = { ability_warrior_battleshout = "self" },
  },
  SHAMAN = {
    names = { { "self", { "Lightning Shield", "Щит молний" } } },
    icons = { spell_nature_lightningshield = "self" },
  },
}
A.PROFILES = PROFILES

A.book    = {}   -- [spell name] = { slot, tex, key, kind }
A.sealTex = {}   -- [icon key] = true for every seal in the spellbook
A.exp     = {}   -- [player name] = { spell, at }   expiry time (GetTime) of your blessing on that player
A.seen    = {}   -- [player name] = { t, key, has } cached icon check
A.attempt = {}   -- [player name] = time of the last automatic cast
A.backoff = {}   -- [player name] = no automatic cast before this time (after a failure)
A.pending = nil  -- a cast waiting for confirmation

local function HasPrefix(name, list)
  local i
  for i = 1, table.getn(list) do
    if string.sub(name, 1, string.len(list[i])) == list[i] then return true end
  end
  return false
end

local function IconKey(tex)
  if not tex then return "" end
  local s = string.gsub(tex, "^.*\\", "")
  return string.lower(s)
end
A.IconKey = IconKey

local function StripRank(name)
  if not name then return nil end
  local s = string.gsub(name, "%s*%(.-%)%s*$", "")
  return s
end

local function Round(x) return math.floor(x + 0.5) end

-- "greater", "blessing", "self", "seal" or nil
function A.Kind(name, tex)
  local prof = A.cls and PROFILES[A.cls]
  if not name or not prof then return nil end
  local key = IconKey(tex)
  if prof.exclude and prof.exclude[key] then return nil end
  local i
  for i = 1, table.getn(prof.names) do
    if HasPrefix(name, prof.names[i][2]) then return prof.names[i][1] end
  end
  return prof.icons[key]
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------

function A.Init()
  if type(AdeLazyBuffsDB) ~= "table" then AdeLazyBuffsDB = {} end
  local d = AdeLazyBuffsDB
  local k, v
  for k, v in pairs(A.DEFAULTS) do
    if d[k] == nil then d[k] = v end
  end
  if type(d.targets) ~= "table" then d.targets = {} end
  if type(d.dur) ~= "table" then d.dur = {} end
  local _, cls = UnitClass("player")
  A.cls = cls
  if cls ~= "PALADIN" and not d.durInit then
    d.durInit = true            -- other classes: buffs last 30 minutes, group buffs an hour, until learned from your casts
    d.normalDur = 1800
    d.greaterDur = 3600
  end
  if (d.ver or 0) < 2 then
    -- version 0.1.0 wrote the slider minimum over the thresholds when the window was first opened
    d.normalAt = A.DEFAULTS.normalAt
    d.greaterAt = A.DEFAULTS.greaterAt
    d.castMethod = nil
    d.ver = 2
  end
  if d.ver < 3 then
    -- entries were keyed by player name, now by player + buff family (several buffs per player)
    local old = d.targets
    d.targets = {}
    local nm, e
    for nm, e in pairs(old) do
      if type(e) == "table" and e.spell then
        local ek = nm .. "|bless"
        e.name, e.key = nm, ek
        d.targets[ek] = e
      end
    end
    d.ver = 3
  end
  A.DB = d
end

function A.ScanBook()
  A.book = {}
  A.sealTex = {}
  local i = 1
  while true do
    local name = GetSpellName(i, BOOKTYPE_SPELL)
    if not name then break end
    local tex = GetSpellTexture(i, BOOKTYPE_SPELL)
    local kind = A.Kind(name, tex)
    if kind then
      local key = IconKey(tex)
      A.book[name] = { slot = i, tex = tex, key = key, kind = kind }   -- later ranks overwrite earlier ones
      if kind == "seal" then A.sealTex[key] = true end
    end
    i = i + 1
  end
end

---------------------------------------------------------------------------
-- Buff helpers
---------------------------------------------------------------------------

-- Does the unit carry a buff with this icon?
function A.HasIcon(unit, key)
  local i
  for i = 1, 32 do
    local tex = UnitBuff(unit, i)
    if not tex then return false end
    if IconKey(tex) == key then return true end
  end
  return false
end

-- Your own buffs: icon keys and seconds left.
function A.PlayerBuffs()
  local tx, lf, n = {}, {}, 0
  local i
  for i = 0, 31 do
    local idx = GetPlayerBuff(i, "HELPFUL")
    if not idx or idx < 0 then break end
    local tex = GetPlayerBuffTexture(idx)
    if tex then
      n = n + 1
      tx[n] = IconKey(tex)
      lf[n] = GetPlayerBuffTimeLeft(idx) or 0
    end
  end
  return tx, lf, n
end

local function LeftOf(key, tx, lf, n)
  local i
  for i = 1, n do
    if tx[i] == key then return lf[i] end
  end
  return nil
end

-- player name -> unit id (player, party, raid)
function A.GroupMap()
  local map = {}
  local me = UnitName("player")
  if me then map[me] = "player" end
  local i, u, nm
  local nr = GetNumRaidMembers()
  if nr and nr > 0 then
    for i = 1, nr do
      u = "raid" .. i
      nm = UnitName(u)
      if nm and not map[nm] then map[nm] = u end
    end
  else
    for i = 1, GetNumPartyMembers() do
      u = "party" .. i
      nm = UnitName(u)
      if nm and not map[nm] then map[nm] = u end
    end
  end
  return map
end

local function UnitFor(name, map)
  map = map or A.GroupMap()
  if map[name] then return map[name] end
  if UnitExists("target") and UnitName("target") == name then return "target" end
  return nil
end

-- Can we buff this unit right now?
local function Ready(unit)
  if not UnitExists(unit) or not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) then return false end
  if not UnitIsFriend("player", unit) or not UnitIsPlayer(unit) then return false end
  if unit == "player" then return true end
  if not UnitIsVisible(unit) then return false end
  if not CheckInteractDistance(unit, 4) then return false end
  -- do not get flagged for PvP by buffing a flagged player
  if UnitIsPVP(unit) and not UnitIsPVP("player") then return false end
  return true
end

local function SpellReady(info)
  local s, d = GetSpellCooldown(info.slot, BOOKTYPE_SPELL)
  return (not s) or s == 0 or (not d) or d == 0
end

-- Default durations (seconds) by spell icon, from the SmartBuff tables; learned values win.
local ICON_DUR = {
  spell_holy_magicalsentry = 1800, spell_holy_arcaneintellect = 3600,
  spell_frost_frostarmor02 = 1800, spell_frost_frostarmor = 1800, spell_magearmor = 1800,
  spell_holy_wordfortitude = 1800, spell_holy_prayeroffortitude = 3600,
  spell_holy_divinespirit = 1800, spell_holy_prayerofspirit = 3600,
  spell_shadow_antishadow = 600, spell_holy_prayerofshadowprotection = 1200, spell_holy_innerfire = 600,
  spell_nature_regeneration = 1800, spell_nature_giftofthewild = 3600, spell_nature_thorns = 600,
  spell_nature_crystalball = 600, spell_shadow_ritualofsacrifice = 1800, spell_shadow_ragingscream = 1800,
  spell_shadow_demonbreath = 600, ability_warrior_battleshout = 120, spell_nature_lightningshield = 600,
}

-- Buffs that replace each other (single and group version, the armors): one remembered entry per family.
local FAMILY = {
  spell_holy_magicalsentry = "int", spell_holy_arcaneintellect = "int",
  spell_frost_frostarmor02 = "armor", spell_frost_frostarmor = "armor", spell_magearmor = "armor",
  spell_shadow_ritualofsacrifice = "armor", spell_shadow_ragingscream = "armor",
  spell_holy_wordfortitude = "fort", spell_holy_prayeroffortitude = "fort",
  spell_holy_divinespirit = "spirit", spell_holy_prayerofspirit = "spirit",
  spell_shadow_antishadow = "shadow", spell_holy_prayerofshadowprotection = "shadow",
  spell_nature_regeneration = "motw", spell_nature_giftofthewild = "motw",
}

function A.Fam(spell)
  local info = A.book[spell]
  if not info then return spell end
  if A.cls == "PALADIN" then return "bless" end       -- one blessing per player
  return FAMILY[info.key] or info.key
end

-- key of a remembered entry: player + buff family
function A.EKey(name, spell)
  return name .. "|" .. A.Fam(spell)
end

function A.Dur(spell, greater)
  local d = A.DB.dur and A.DB.dur[spell]
  if d then return d end
  local info = A.book[spell]
  if info and ICON_DUR[info.key] then return ICON_DUR[info.key] end
  if greater then return A.DB.greaterDur or 1800 end
  return A.DB.normalDur or 600
end

-- Seconds left at which a blessing is rebuffed: the slider for its kind (normal / Greater), but never more
-- than half of that blessing's own duration (learned from your casts), so short buffs are not recast at once.
local function Threshold(e)
  local at = e.greater and A.DB.greaterAt or A.DB.normalAt
  local dur = A.Dur(e.spell, e.greater)
  at = at or 120
  if dur and at > dur * 0.5 then at = dur * 0.5 end
  return at
end

function A.SetDue(list)
  A.due = list
  if A.RefreshReminder then A.RefreshReminder() end
end

-- Icon check of another player, cached for 5 seconds.
local function IconState(ek, unit, key)
  local t = GetTime()
  local s = A.seen[ek]
  if not s or s.key ~= key or (t - s.t) >= 5 then
    s = { t = t, key = key, has = A.HasIcon(unit, key) }
    A.seen[ek] = s
  end
  return s.has
end

-- Seconds left of your blessing on a player, and whether the buff is gone.
-- Returns nil when we cannot tell now (out of range, spell unknown); 0, true when the buff is gone.
function A.Remaining(name, e, unit, tx, lf, n)
  local info = A.book[e.spell]
  if not info then return nil end
  if name == A.me then
    local left = LeftOf(info.key, tx, lf, n)
    if not left then return 0, true end
    return left, false
  end
  if not unit or not Ready(unit) then return nil end
  local t = GetTime()
  local ek = e.key or A.EKey(name, e.spell)
  if not IconState(ek, unit, info.key) then
    A.exp[ek] = nil
    return 0, true
  end
  local x = A.exp[ek]
  if not x or x.spell ~= e.spell then
    -- buff is there but we never saw it being cast (after a relog): assume it needs a refresh soon
    x = { spell = e.spell, at = t + Threshold(e) + 60 }
    A.exp[ek] = x
  end
  return x.at - t, false
end

---------------------------------------------------------------------------
-- Memory
---------------------------------------------------------------------------

A.noAdopt = {}   -- [entry key] = true: forgotten by you, do not adopt the buff that is still on you

local function Remember(name, spell, greater, cls)
  local ek = A.EKey(name, spell)
  local e = A.DB.targets[ek]
  local changed = (not e) or e.spell ~= spell
  A.DB.targets[ek] = { name = name, key = ek, spell = spell, greater = greater and true or false, class = cls }
  A.noAdopt[ek] = nil
  A.noAdoptAll = nil
  return changed
end

-- key = one entry (player + buff family); nil = everything
function A.Forget(key)
  if key == nil then
    A.DB.targets = {}
    A.exp = {}
    A.seen = {}
    A.noAdoptAll = true
    return
  end
  A.DB.targets[key] = nil
  A.exp[key] = nil
  A.seen[key] = nil
  A.noAdopt[key] = true
end

function A.ForgetPlayer(name)
  local k, e
  local keys = {}
  for k, e in pairs(A.DB.targets) do
    if e.name == name then table.insert(keys, k) end
  end
  for k = 1, table.getn(keys) do A.Forget(keys[k]) end
end

-- keys of all remembered entries, sorted by player name and spell
function A.SortedNames()
  local list = {}
  local k
  for k in pairs(A.DB.targets) do table.insert(list, k) end
  local T = A.DB.targets
  table.sort(list, function(a, b)
    local x = string.lower(T[a].name) .. " " .. T[a].spell
    local y = string.lower(T[b].name) .. " " .. T[b].spell
    return x < y
  end)
  return list
end

-- Buffs of your own that are on you but not remembered yet are adopted: self buffs always, single / group
-- buffs only when you are alone (otherwise they may come from another player of your class).
local function Adopt(tx, lf, n)
  if A.noAdoptAll then return end
  local solo = (GetNumPartyMembers() == 0) and (GetNumRaidMembers() == 0)
  local spell, info
  for spell, info in pairs(A.book) do
    local k = info.kind
    if k == "self" or (solo and (k == "blessing" or k == "greater")) then
      local ek = A.EKey(A.me, spell)
      if not A.DB.targets[ek] and not A.noAdopt[ek] and LeftOf(info.key, tx, lf, n) then
        Remember(A.me, spell, k == "greater", A.cls)
        A.Print(A.TF("Remembered: %s on %s", spell, A.me))
      end
    end
  end
end

---------------------------------------------------------------------------
-- Cast tracking
---------------------------------------------------------------------------

local function StartPending(spell, kind, unit, info, auto)
  local name = UnitName(unit)
  if not name then return nil end
  local cd0 = GetSpellCooldown(info.slot, BOOKTYPE_SPELL)
  A.pending = {
    spell = spell, kind = kind, unit = unit, name = name, key = A.EKey(name, spell), t = GetTime(), auto = auto,
    had = A.HasIcon(unit, info.key), cd0 = cd0 or 0,
  }
  return A.pending
end

-- Called from the cast hooks for casts that did not come from this addon.
function A.NoteCast(spell, tgt)
  if not A.active or not A.DB or not A.DB.enabled then return end
  spell = StripRank(spell)
  local info = spell and A.book[spell]
  if not info then
    if A.DB.debug and spell then A.Print("cast ignored (not a buff I know): " .. tostring(spell)) end
    return
  end
  local kind = info.kind
  local unit
  if kind == "seal" or kind == "self" then
    unit = "player"
  elseif tgt == 1 or tgt == true or tgt == "player" then
    unit = "player"
  elseif type(tgt) == "string" and tgt ~= "" and UnitExists(tgt) then
    unit = tgt
  elseif UnitExists("target") and UnitIsFriend("player", "target") then
    unit = "target"
  else
    unit = "player"
  end
  if not UnitIsPlayer(unit) or not UnitIsFriend("player", unit) then return end
  StartPending(spell, kind, unit, info, false)
end

function A.NoteAction(slot, onSelf)
  if not A.active or not HasAction(slot) or GetActionText(slot) then return end
  if not A.tip then
    A.tip = CreateFrame("GameTooltip", "AdeLazyBuffsTip", nil, "GameTooltipTemplate")
  end
  A.tip:SetOwner(UIParent, "ANCHOR_NONE")
  A.tip:ClearLines()
  A.tip:SetAction(slot)
  local fs = getglobal("AdeLazyBuffsTipTextLeft1")
  local name = fs and fs:GetText()
  if name then A.NoteCast(name, onSelf) end
end

function A.InstallHooks()
  if A.hooked then return end
  A.hooked = true
  local oldByName, oldSpell, oldAction = CastSpellByName, CastSpell, UseAction
  -- the originals get exactly the arguments they were called with (an extra nil can break SuperWoW)
  CastSpellByName = function(spell, arg2)
    if not A.internal then pcall(A.NoteCast, spell, arg2) end
    if arg2 ~= nil then return oldByName(spell, arg2) end
    return oldByName(spell)
  end
  CastSpell = function(index, book)
    if not A.internal and A.active and book == BOOKTYPE_SPELL then
      local nm = GetSpellName(index, book)
      if nm then pcall(A.NoteCast, nm, nil) end
    end
    return oldSpell(index, book)
  end
  UseAction = function(slot, cursor, onSelf)
    if not A.internal then pcall(A.NoteAction, slot, onSelf) end
    if onSelf ~= nil then
      oldAction(slot, cursor, onSelf)
    elseif cursor ~= nil then
      oldAction(slot, cursor)
    else
      oldAction(slot)
    end
    if not A.internal then A.Input("key") end
  end
  -- mouse wheel, like SmartBuff
  local oldIn, oldOut = CameraZoomIn, CameraZoomOut
  CameraZoomIn = function(x)
    A.Input("wheel")
    return oldIn(x)
  end
  CameraZoomOut = function(x)
    A.Input("wheel")
    return oldOut(x)
  end
end

local function Confirm(p, unit)
  local DB = A.DB
  local info = A.book[p.spell]
  if not info then return end
  if p.kind == "seal" then A.sealBackoff = nil end

  if p.kind == "seal" then
    if DB.seal ~= p.spell then
      DB.seal = p.spell
      if not p.auto then A.Print(A.TF("Remembered seal: %s", p.spell)) end
    end
    return
  end

  local greater = (p.kind == "greater")
  local dur = A.Dur(p.spell, greater)
  if p.name == A.me then
    -- the game tells the real duration for yourself
    local tx, lf, n = A.PlayerBuffs()
    local left = LeftOf(info.key, tx, lf, n)
    if left and left > 0 and left < 120 then return end       -- short buff, not worth keeping up
    if left and left >= 120 then
      dur = Round(left / 5) * 5
      DB.dur[p.spell] = dur
    end
  end

  local _, cls = UnitClass(unit)
  local changed = Remember(p.name, p.spell, greater, cls)
  local t = GetTime()
  local ek = A.EKey(p.name, p.spell)
  A.exp[ek] = { spell = p.spell, at = t + dur }
  A.seen[ek] = nil
  A.backoff[ek] = nil

  if greater and cls then
    -- a Greater Blessing covers the whole class (other group buffs: the whole party): take every group member
    -- that now has it
    local map = A.GroupMap()
    local n2, u2
    for n2, u2 in pairs(map) do
      if n2 ~= p.name and UnitIsVisible(u2) then
        local _, c2 = UnitClass(u2)
        if (A.cls ~= "PALADIN" or c2 == cls) and A.HasIcon(u2, info.key) then
          Remember(n2, p.spell, true, c2)
          local ek2 = A.EKey(n2, p.spell)
          A.exp[ek2] = { spell = p.spell, at = t + dur }
          A.seen[ek2] = nil
        end
      end
    end
  end

  if changed and not p.auto then
    A.Print(A.TF("Remembered: %s on %s", p.spell, p.name))
  end
end

local function Fail(p)
  if not p.auto then return end
  if p.kind == "seal" then
    A.sealBackoff = GetTime() + 3          -- the seal has its own backoff: it must not block your blessings
  elseif p.key then
    A.backoff[p.key] = GetTime() + 10
  end
end

-- Checks a pending cast: confirm it, drop it, or keep waiting.
function A.UpdatePending(t)
  local p = A.pending
  if not p then return end
  local age = t - p.t
  if p.failed then
    A.pending = nil
    Fail(p)
    return
  end
  if age < 0.5 then return end
  local info = A.book[p.spell]
  if not info then A.pending = nil return end

  local unit = UnitFor(p.name)
  local has = unit and UnitExists(unit) and A.HasIcon(unit, info.key)
  local s = GetSpellCooldown(info.slot, BOOKTYPE_SPELL)
  local cdChanged = s and s > 0 and s ~= p.cd0
  if has and ((not p.had) or cdChanged) then
    A.pending = nil
    Confirm(p, unit)
  elseif age > 2.5 then
    A.pending = nil
    if A.DB.debug and p.auto then
      local function yn(b) if b then return "yes" end return "no" end
      A.Print("no result after the cast: buff on target=" .. yn(has) .. ", cooldown started=" .. yn(cdChanged))
    end
    Fail(p)
  end
end

---------------------------------------------------------------------------
-- Casting
---------------------------------------------------------------------------

-- Casts the way SmartBuff does (SMARTBUFF_doCast):
--   yourself: CastSpellByName(name, 1)
--   others:   CastSpell(slot, "spell") + SpellTargetUnit(unit), after clearing a friendly target
--             that would take the spell, and with auto self cast switched off for a moment.
local function RestoreTarget(oldName, wasPlayer)
  if oldName then
    if wasPlayer then TargetByName(oldName, true) else TargetLastTarget() end
  end
end

function A.CastOn(spell, unit, info, kind)
  A.internal = true
  if GetCVar("autoSelfCast") == "1" then
    A.autoSelfBack = GetTime() + 1
    SetCVar("autoSelfCast", "0")
  end

  local oldTarget, oldWasPlayer
  if unit ~= "player" and not UnitIsUnit("target", unit) and not UnitIsEnemy("player", "target") then
    oldWasPlayer = UnitIsPlayer("target")
    oldTarget = UnitName("target")
    ClearTarget()
  end

  local ok, err
  if unit == "player" then
    local nm = GetSpellName(info.slot, BOOKTYPE_SPELL) or spell
    ok, err = pcall(CastSpellByName, nm, 1)
    if SpellIsTargeting() then
      if kind == "seal" then SpellStopTargeting() else SpellTargetUnit(unit) end
    end
  else
    ok, err = pcall(CastSpell, info.slot, BOOKTYPE_SPELL)
    if SpellIsTargeting() then
      if SpellCanTargetUnit(unit) then SpellTargetUnit(unit) else SpellStopTargeting() end
    end
  end
  if not ok and A.DB.debug then A.Print("cast error: " .. tostring(err)) end

  RestoreTarget(oldTarget, oldWasPlayer)
  A.internal = false
end

local function StartCast(spell, kind, unit, info)
  -- the game ignores casts that do not come from something you did (seen on OctoWoW):
  -- the timer only decides, the cast waits for the next key press, mouse wheel or target change
  if A.src == "timer" and not A.timerCast then
    if A.DB.debug and (GetTime() - (A.waitT or 0)) >= 3 then
      A.waitT = GetTime()
      A.Print("due: " .. spell .. " on " .. tostring(UnitName(unit)) .. " - waiting for your next key press, mouse wheel or target change")
    end
    return false
  end
  local p = StartPending(spell, kind, unit, info, true)
  if not p then return false end
  A.attempt[p.key] = GetTime()
  if A.DB.debug then
    A.Print("cast " .. spell .. " on " .. tostring(p.name) .. " (" .. tostring(A.src or "timer") .. ")")
  end
  A.CastOn(spell, unit, info, kind)
  if A.DB.debug then
    local cs, cd = GetSpellCooldown(info.slot, BOOKTYPE_SPELL)
    A.Print("  after the cast: targeting=" .. tostring(SpellIsTargeting() and "yes" or "no") .. ", cooldown start=" .. tostring(cs) .. " dur=" .. tostring(cd))
  end
  return true
end

-- Reasons not to cast anything now.
local function Blocked(t)
  if UnitIsDeadOrGhost("player") or UnitOnTaxi("player") then return true end
  if A.castUntil and t < A.castUntil then return true end        -- you are casting / channeling something
  if SpellIsTargeting() then return true end
  if LootFrame and LootFrame:IsVisible() then return true end
  if MerchantFrame and MerchantFrame:IsVisible() then return true end
  if TradeFrame and TradeFrame:IsVisible() then return true end
  return false
end

-- Eating, drinking or mounted: a cast would cancel it.
-- Icons of the Food / Drink buffs while eating or drinking, and of mounts. (The "Well Fed" buff, icon
-- spell_misc_food, is not eating and must not block anything.)
local function Busy(tx, n)
  local i
  for i = 1, n do
    local k = tx[i]
    if string.find(k, "^inv_drink") or string.find(k, "^inv_misc_fork") or string.find(k, "^ability_mount_")
       or string.find(k, "^inv_misc_food") then
      return true, k
    end
  end
  return false
end

local function HasSeal(tx, n)
  local i
  for i = 1, n do
    if A.sealTex[tx[i]] then return true end
  end
  return false
end

-- In a fight: you are in combat, or your target is an attackable enemy that is in combat
-- (training dummies do not always put you in combat yourself).
local function InFight()
  if UnitAffectingCombat("player") then return true end
  if UnitExists("target") and UnitCanAttack("player", "target") and UnitAffectingCombat("target") then return true end
  return false
end

-- One pass. force = from the key binding / "/alb now": ignores the auto switch and rested areas.
function A.Tick(force, src)
  local DB = A.DB
  if not A.active or not DB or not DB.enabled then return end
  local t = GetTime()
  A.src = src or "timer"
  if A.pending then
    A.UpdatePending(t)
    return
  end

  -- "/alb debug on": says why nothing is cast (at most every 4 seconds)
  local function Skip(why)
    if DB.debug and (t - (A.dbgT or 0)) >= 1.5 then
      A.dbgT = t
      A.Print("not casting: " .. why)
    end
  end

  local canCast = force or DB.auto
  local fight = InFight()
  -- cities, inns: everything off, but a fight (quest mob, PvP, training dummy) switches that rule off
  if not force and IsResting() and not fight then
    A.SetDue(nil)
    Skip("rested area and no fight")
    return
  end
  local blocked = Blocked(t)
  local tx, lf, n = A.PlayerBuffs()
  local busy, busyIcon = Busy(tx, n)
  Adopt(tx, lf, n)
  if blocked then Skip("busy: dead, taxi, casting, vendor/loot window or targeting") end
  if busy then Skip("eating, drinking or mounted (buff icon " .. tostring(busyIcon) .. ")") end
  local free = canCast and not blocked and not busy

  -- Seal: no global cooldown problem, so it is kept up in a fight too
  -- (only in a fight: out of combat the seal is not worth casting)
  if free and fight and DB.seals and DB.seal then
    local info = A.book[DB.seal]
    if not info then
      Skip("seal " .. DB.seal .. " is not in the spellbook")
    elseif HasSeal(tx, n) then
      -- a seal is on you: nothing to do
    elseif (A.sealBackoff or 0) > t then
      Skip("the last seal cast did nothing, waiting 3 seconds")
    elseif not SpellReady(info) then
      Skip("seal is on cooldown")
    elseif (t - (A.sealTry or 0)) < 2 then
      -- just tried
    else
      if StartCast(DB.seal, "seal", "player", info) then
        A.sealTry = t
        return
      end
    end
  end

  -- Blessings share the global cooldown: never in a fight
  if fight or UnitIsDeadOrGhost("player") then
    A.SetDue(nil)
    Skip("in a fight: blessings wait")
    return
  end

  local map = A.GroupMap()
  local due = {}
  local ek, e
  for ek, e in pairs(DB.targets) do
    local name = e.name
    local unit = map[name]
    local info = unit and A.book[e.spell]
    if info then
      -- due when the buff is gone (dispelled, cancelled, died), or - with the timer on - when little time is left
      local rem, gone = A.Remaining(name, e, unit, tx, lf, n)
      if rem and (gone or (DB.useTimer and rem <= Threshold(e))) and Ready(unit) then
        table.insert(due, { key = ek, name = name, spell = e.spell, greater = e.greater, rem = rem, gone = gone, unit = unit, info = info })
      end
    end
  end
  table.sort(due, function(x, y) return x.rem < y.rem end)
  A.SetDue(due)
  if not free then return end

  local i
  for i = 1, table.getn(due) do
    local d = due[i]
    if (A.backoff[d.key] or 0) <= t and ((A.attempt[d.key] or 0) + 3) <= t and SpellReady(d.info) then
      StartCast(d.spell, d.info.kind, d.unit, d.info)
      return
    end
  end
  if table.getn(due) == 0 then Skip("nothing is due") end
end

-- "/alb why": the state the automatic pass looks at (diagnostics, English only)
function A.Why()
  local DB = A.DB
  local t = GetTime()
  local tx, lf, n = A.PlayerBuffs()
  local function yn(b) if b then return "yes" end return "no" end
  A.Print("class=" .. tostring(A.cls) .. " active=" .. yn(A.active) .. " enabled=" .. yn(DB.enabled) .. " auto=" .. yn(DB.auto) .. " seals=" .. yn(DB.seals) .. " SuperWoW=" .. yn(A.swow))
  A.Print("resting=" .. yn(IsResting()) .. " combat=" .. yn(UnitAffectingCombat("player")) .. " targetInCombat=" .. yn(UnitExists("target") and UnitAffectingCombat("target")) .. " fight=" .. yn(InFight()))
  A.Print("blocked=" .. yn(Blocked(t)) .. " busy=" .. yn(Busy(tx, n)) .. " pending=" .. yn(A.pending) .. " timer=" .. yn(DB.useTimer))
  local info = DB.seal and A.book[DB.seal]
  A.Print("seal=" .. tostring(DB.seal) .. " inSpellbook=" .. yn(info) .. " onYou=" .. yn(HasSeal(tx, n)) .. " ready=" .. yn(info and SpellReady(info)))
  local k, c = 0, 0
  local i
  for i = 1, n do
    k = k + 1
    if A.sealTex[tx[i]] then c = c + 1 end
  end
  A.Print("buffs on you=" .. k .. " (seal icons among them: " .. c .. ")")
  local keys = ""
  for i = 1, n do keys = keys .. tx[i] .. " " end
  A.Print("your buff icons: " .. keys)
  A.Print("seal icon: " .. tostring(info and info.key))
end

-- Called from user input (mouse wheel, key press, target change): casts are tried in the middle of
-- something you did yourself, like SmartBuff does.
function A.Input(src)
  if A.internal or not A.active or not A.DB or not A.DB.enabled then return end
  local t = GetTime()
  -- what counts as input is a setting: any button, only the mouse wheel, or only your own key
  local mode = A.DB.trigger
  if mode == "key" then return end
  if mode == "wheel" and src ~= "wheel" then return end
  if (t - (A.inputT or 0)) < 0.5 then return end
  A.inputT = t
  pcall(A.Tick, false, src)
end

-- Key binding entry point
function AdeLazyBuffs_Now()
  if not A.active then return end
  local ok, err = pcall(A.Tick, true, "key binding")
  if not ok then A.Print(A.TF("Error: %s", tostring(err))) end
end
