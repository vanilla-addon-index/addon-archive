--[[
  TankSuite - Announcer
  Announces your failed taunts (resisted / missed / immune / dodged / parried...),
  the taunts and defensive cooldowns you use, and - in Main Tank mode - every
  miss / dodge / parry during the first seconds of a pull.

  Failures are read from the combat log chat lines (Blizzard GlobalStrings first,
  English lines as a fallback), so it also works in French and other clients.
  Spell use is read from SuperWoW's UNIT_CASTEVENT.
]]

local TS = TankSuite
local A = { lastSent = {}, inCombat = false, combatStart = 0, lastTarget = nil }
TS.Announcer = A

----------------------------------------------------------------------
-- Tracked spells
----------------------------------------------------------------------
-- kind: taunt (can fail, can be announced when used) | cd (announced when used)
A.SPELLS = {
  taunt       = { kind = "taunt", ids = { 355 }, en = "Taunt" },
  growl       = { kind = "taunt", ids = { 6795 }, en = "Growl" },
  mocking     = { kind = "taunt", ids = { 694, 7400, 7402, 20559, 20560 }, en = "Mocking Blow" },
  reckoning   = { kind = "taunt", ids = {}, en = "Hand of Reckoning" },
  earthshaker = { kind = "taunt", ids = {}, en = "Earthshaker Slam" },
  shout       = { kind = "taunt", cd = true, ids = { 1161 }, en = "Challenging Shout" },
  roar        = { kind = "taunt", cd = true, ids = { 5209 }, en = "Challenging Roar" },
  shieldwall  = { kind = "cd", ids = { 871 }, en = "Shield Wall" },
  laststand   = { kind = "cd", ids = { 12975, 12976 }, en = "Last Stand" },
  gem         = { kind = "cd", ids = {}, en = "Gift of Life" },
}
A.FAIL_KEYS = { "taunt", "growl", "mocking", "reckoning", "earthshaker", "shout", "roar" }
A.USED_KEYS = { "taunt", "growl", "mocking", "reckoning", "earthshaker" }
A.CD_KEYS = { "shieldwall", "laststand", "gem", "shout", "roar" }

A.nameToKey = {}
A.keyToName = {}

function A.BuildSpellNames()
  A.nameToKey, A.keyToName = {}, {}
  for key, s in pairs(A.SPELLS) do
    local shown
    for i = 1, table.getn(s.ids) do
      local n = TS.SpellName(s.ids[i])
      if n then
        A.nameToKey[n] = key
        shown = shown or n
      end
    end
    A.nameToKey[s.en] = A.nameToKey[s.en] or key
    A.keyToName[key] = shown or s.en
  end
end

----------------------------------------------------------------------
-- Combat log line parsing
----------------------------------------------------------------------
-- turn a Blizzard format string ("Your %s was resisted by %s.") into a Lua
-- pattern. Handles positional formats ("%2$s") used by some translations.
-- Returns the pattern and capNum: capNum[argIndex] = capture index.
function A.Compile(fmt)
  local pat = "^"
  local capOfArg = {}
  local caps = 0
  local seq = 0
  local i, n = 1, string.len(fmt)
  while i <= n do
    local c = string.sub(fmt, i, i)
    if c == "%" then
      local s, e, num = string.find(fmt, "^(%d)%$s", i + 1)
      if s then
        caps = caps + 1
        capOfArg[tonumber(num)] = caps
        pat = pat .. "(.+)"
        i = e + 1
      elseif string.sub(fmt, i + 1, i + 1) == "s" then
        caps = caps + 1
        seq = seq + 1
        capOfArg[seq] = caps
        pat = pat .. "(.+)"
        i = i + 2
      else
        pat = pat .. "%%"
        i = i + 1
      end
    else
      if string.find(c, "[%^%$%(%)%.%[%]%*%+%-%?]") then pat = pat .. "%" .. c else pat = pat .. c end
      i = i + 1
    end
  end
  return pat .. "$", capOfArg
end

-- { global name, english fallback, reason, spellArg, targetArg }
local SPELL_DEFS = {
  { "SPELLRESISTSELFOTHER", "Your %s was resisted by %s.", "resist", 1, 2 },
  { "SPELLMISSSELFOTHER", "Your %s missed %s.", "miss", 1, 2 },
  { "SPELLIMMUNESELFOTHER", "Your %s failed. %s is immune.", "immune", 1, 2 },
  { "IMMUNESPELLSELFOTHER", "%s is immune to your %s.", "immune", 2, 1 },
  { "SPELLDODGEDSELFOTHER", "Your %s was dodged by %s.", "dodge", 1, 2 },
  { "SPELLPARRIEDSELFOTHER", "Your %s is parried by %s.", "parry", 1, 2 },
  { "SPELLBLOCKEDSELFOTHER", "Your %s was blocked by %s.", "block", 1, 2 },
  { "SPELLEVADEDSELFOTHER", "Your %s was evaded by %s.", "evade", 1, 2 },
  { "SPELLREFLECTSELFOTHER", "Your %s was reflected by %s.", "reflect", 1, 2 },
}
-- white hits: { global name, english fallback, reason }
local MELEE_DEFS = {
  { "MISSEDSELFOTHER", "You miss %s.", "miss" },
  { "VSDODGESELFOTHER", "You attack. %s dodges.", "dodge" },
  { "VSPARRYSELFOTHER", "You attack. %s parries.", "parry" },
  { "VSBLOCKSELFOTHER", "You attack. %s blocks.", "block" },
  { "VSEVADESELFOTHER", "You attack. %s evades.", "evade" },
  { "VSIMMUNESELFOTHER", "You attack but %s is immune.", "immune" },
}

local spellPatterns, meleePatterns

local function AddPattern(list, fmt, entry)
  if not fmt or fmt == "" then return end
  for i = 1, table.getn(list) do
    if list[i].fmt == fmt then return end
  end
  local pat, capOfArg = A.Compile(fmt)
  entry.fmt, entry.pat, entry.cap = fmt, pat, capOfArg
  table.insert(list, entry)
end

function A.BuildPatterns()
  spellPatterns, meleePatterns = {}, {}
  for i = 1, table.getn(SPELL_DEFS) do
    local d = SPELL_DEFS[i]
    local local_fmt = getglobal(d[1])
    AddPattern(spellPatterns, local_fmt, { reason = d[3], spellArg = d[4], targetArg = d[5] })
    AddPattern(spellPatterns, d[2], { reason = d[3], spellArg = d[4], targetArg = d[5] })
  end
  for i = 1, table.getn(MELEE_DEFS) do
    local d = MELEE_DEFS[i]
    local local_fmt = getglobal(d[1])
    AddPattern(meleePatterns, local_fmt, { reason = d[3], targetArg = 1 })
    AddPattern(meleePatterns, d[2], { reason = d[3], targetArg = 1 })
  end
end

-- returns reason, spellName, targetName  (or nil)
function A.ParseSpell(msg)
  if not spellPatterns then A.BuildPatterns() end
  for i = 1, table.getn(spellPatterns) do
    local p = spellPatterns[i]
    local _, _, c1, c2 = string.find(msg, p.pat)
    if c1 then
      local caps = { c1, c2 }
      return p.reason, caps[p.cap[p.spellArg]], caps[p.cap[p.targetArg]]
    end
  end
  return nil
end

-- returns reason, targetName  (or nil)
function A.ParseMelee(msg)
  if not meleePatterns then A.BuildPatterns() end
  for i = 1, table.getn(meleePatterns) do
    local p = meleePatterns[i]
    local _, _, c1 = string.find(msg, p.pat)
    if c1 then return p.reason, c1 end
  end
  return nil
end

----------------------------------------------------------------------
-- Message building
----------------------------------------------------------------------
function A.Template(name)
  local custom = TS.db.announce.messages[name]
  if custom and custom ~= "" then return custom end
  return TS.L("msg_" .. name)
end

function A.DefaultTemplate(name)
  return TS.L("msg_" .. name)
end

-- replace {s} {r} {t} {m} {l}; values are inserted verbatim
function A.Format(template, ctx)
  local function sub(msg, token, value)
    return (string.gsub(msg, token, function() return value end))
  end
  local msg = template
  msg = sub(msg, "{s}", ctx.spell or "")
  msg = sub(msg, "{r}", ctx.reason or "")
  msg = sub(msg, "{t}", ctx.target or "")
  msg = sub(msg, "{m}", ctx.mark or "")
  msg = sub(msg, "{l}", ctx.level or "")
  msg = string.gsub(msg, "%s%s+", " ")
  return TS.Trim(msg)
end

-- who was the taunt aimed at? (name from the log line, extra data from the unit)
local function TargetUnit(targetName)
  if not targetName then return nil end
  local lt = A.lastTarget
  if lt and (GetTime() - lt.t) < 5 and UnitName(lt.guid) == targetName then return lt.guid end
  if UnitName("target") == targetName then return "target" end
  return nil
end

-- a real unit id: area spells (Challenging Shout...) report an empty / null target
local function IsUnitId(id)
  return type(id) == "string" and id ~= "" and id ~= "0x0000000000000000"
end

local function MarkText(unit)
  if not unit then return "" end
  local idx = GetRaidTargetIndex(unit)
  if idx and idx >= 1 and idx <= 8 then return "[" .. TS.L("mark_" .. idx) .. "]" end
  return ""
end

local function LevelText(unit)
  if not unit then return "" end
  local lvl = UnitLevel(unit)
  if not lvl then return "" end
  if lvl < 0 then return "??" end
  return tostring(lvl)
end

function A.SpellLabel(key)
  return A.keyToName[key] or (A.SPELLS[key] and A.SPELLS[key].en) or key
end

----------------------------------------------------------------------
-- Sending
----------------------------------------------------------------------
function A.Allow(key, interval)
  local now = GetTime()
  local last = A.lastSent[key]
  if last and (now - last) < interval then return false end
  A.lastSent[key] = now
  return true
end

function A.Send(msg, channel)
  local cfg = TS.db.announce
  if msg == "" then return end
  if channel == "SELF" then
    TS.Print(msg)
    return
  end
  local inRaid = GetNumRaidMembers() > 0
  local inParty = GetNumPartyMembers() > 0
  if cfg.groupOnly and not (inRaid or inParty) then return end

  if channel == "GROUP" or channel == "GROUP_RW" then
    if inRaid then
      if channel == "GROUP_RW" and IsRaidOfficer() then
        SendChatMessage(msg, "RAID_WARNING")
      else
        SendChatMessage(msg, "RAID")
      end
    elseif inParty then
      SendChatMessage(msg, "PARTY")
    end
  elseif channel == "RAID" then
    if inRaid then SendChatMessage(msg, "RAID") elseif inParty then SendChatMessage(msg, "PARTY") end
  elseif channel == "RAID_WARNING" then
    if inRaid and IsRaidOfficer() then
      SendChatMessage(msg, "RAID_WARNING")
    elseif inRaid then
      SendChatMessage(msg, "RAID")
    elseif inParty then
      SendChatMessage(msg, "PARTY")
    end
  elseif channel == "PARTY" then
    if inParty or inRaid then SendChatMessage(msg, "PARTY") end
  elseif channel == "CHANNEL" then
    local idx = GetChannelName(cfg.customChannel)
    if idx and idx > 0 then
      SendChatMessage(msg, "CHANNEL", nil, idx)
    else
      TS.Print(TS.Lf("channel_missing", cfg.customChannel, cfg.customChannel))
    end
  else
    SendChatMessage(msg, channel) -- SAY / YELL
  end
end

-- one place that turns an event into a chat line
-- template: fail | used | cd | opening
function A.Emit(template, key, reason, spell, target, unit, channel)
  local cfg = TS.db.announce
  local ctx = {
    spell = spell or A.SpellLabel(key),
    reason = reason and TS.L("reason_" .. reason) or "",
    target = target or "",
    mark = MarkText(unit),
    level = LevelText(unit),
  }
  local msg = A.Format(A.Template(template), ctx)
  A.Send(msg, channel or cfg.failChannel)
  if cfg.alertSelf and template == "fail" then
    UIErrorsFrame:AddMessage(msg, 1, 0.3, 0.3, 1, 3)
  end
  return msg
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
function A.MainTankActive()
  local mt = TS.db.announce.mainTank
  return mt.enabled and A.inCombat and (GetTime() - A.combatStart) <= mt.duration
end

local function IsDualWielding()
  local f = getglobal("OffhandHasWeapon")
  return f and f() and true or false
end

-- own spell line: "Your Taunt was resisted by X."
function A.OnSpellMessage(msg)
  local cfg = TS.db.announce
  if not cfg.enabled then return end
  local reason, spell, target = A.ParseSpell(msg)
  if not reason then return end
  local key = A.nameToKey[spell]
  if key and A.SPELLS[key].kind == "taunt" then
    if cfg.fail[key] and A.Allow("fail_" .. key, 1.5) then
      A.Emit("fail", key, reason, spell, target, TargetUnit(target), cfg.failChannel)
    end
  elseif not key then
    -- any other ability: only interesting while opening a pull as main tank
    if A.MainTankActive() and (reason == "miss" or reason == "dodge" or reason == "parry") then
      if A.Allow("opening", 1.0) then
        A.Emit("opening", nil, reason, spell, target, TargetUnit(target), cfg.failChannel)
      end
    end
  end
end

-- own white hit line: "You miss X." / "You attack. X dodges."
function A.OnMeleeMessage(msg)
  local cfg = TS.db.announce
  if not cfg.enabled or not A.MainTankActive() then return end
  local reason, target = A.ParseMelee(msg)
  if not reason then return end
  if reason ~= "miss" and reason ~= "dodge" and reason ~= "parry" then return end
  if cfg.mainTank.skipDual and IsDualWielding() then return end
  if A.Allow("opening", 1.0) then
    A.Emit("opening", nil, reason, TS.L("melee"), target, TargetUnit(target), cfg.failChannel)
  end
end

-- SuperWoW UNIT_CASTEVENT: arg1 caster guid, arg2 target guid, arg3 event type, arg4 spell id
function A.OnCastEvent(event, casterGuid, targetGuid, kind, spellId)
  if kind ~= "CAST" or not spellId then return end
  -- mobs cast all the time in a raid: only look at ourselves and the group
  if not TS.Roster.byGuid[casterGuid] then return end
  local name = TS.SpellName(spellId)
  if not name then return end
  TS.Roster.OnCast(casterGuid, name)
  if casterGuid ~= TS.Roster.playerGuid then return end

  local cfg = TS.db.announce
  local key = A.nameToKey[name]
  if not key then return end
  local spell = A.SPELLS[key]
  if not cfg.enabled then return end

  if spell.kind == "taunt" then
    local unit = IsUnitId(targetGuid) and targetGuid or nil
    A.lastTarget = unit and { guid = unit, t = GetTime() } or nil
    if cfg.used[key] and A.Allow("used_" .. key, 1.0) then
      A.Emit("used", key, nil, name, unit and UnitName(unit) or nil, unit, cfg.infoChannel)
    end
  end
  if (spell.kind == "cd" or spell.cd) and cfg.cd[key] and A.Allow("cd_" .. key, 2.0) then
    A.Emit("cd", key, nil, name, nil, nil, cfg.infoChannel)
  end
end

----------------------------------------------------------------------
-- Salvation removal (optional): tanks do not want a threat-reducing blessing
----------------------------------------------------------------------
local SALVATION_TEX = {
  ["interface\\icons\\spell_holy_sealofsalvation"] = true,
  ["interface\\icons\\spell_holy_greaterblessingofsalvation"] = true,
}

local function PlayerHasTankStance()
  local _, class = UnitClass("player")
  if class == "WARRIOR" or class == "DRUID" then
    local want = (class == "WARRIOR") and "defensivestance" or "bearform"
    for i = 1, GetNumShapeshiftForms() do
      local tex, _, active = GetShapeshiftFormInfo(i)
      if active and tex and string.find(string.lower(tex), want, 1, true) then return true end
    end
  elseif class == "PALADIN" then
    local i = 0
    while i < 40 do
      local idx = GetPlayerBuff(i, "HELPFUL")
      if idx < 0 then break end
      local tex = GetPlayerBuffTexture(idx)
      if tex and string.find(string.lower(tex), "sealoffury", 1, true) then return true end
      i = i + 1
    end
  end
  return false
end

function A.RemoveSalvation()
  local cfg = TS.db.announce
  if not cfg.removeSalvation then return end
  if not (cfg.mainTank.enabled or PlayerHasTankStance()) then return end
  local i = 0
  while i < 40 do
    local idx = GetPlayerBuff(i, "HELPFUL")
    if idx < 0 then break end
    local tex = GetPlayerBuffTexture(idx)
    if tex and SALVATION_TEX[string.lower(tex)] then
      CancelPlayerBuff(idx)
      if cfg.notifySalvation then TS.Print(TS.L("salvation_removed")) end
      return
    end
    i = i + 1
  end
end

----------------------------------------------------------------------
-- Test
----------------------------------------------------------------------
-- prints a sample of every message in the chat window (nothing is sent to others)
function A.Test()
  local cfg = TS.db.announce
  TS.Print(TS.Lf("test_header", cfg.failChannel, cfg.infoChannel))
  A.Emit("fail", "taunt", "resist", A.SpellLabel("taunt"), TS.L("test_mob"), nil, "SELF")
  A.Emit("fail", "growl", "immune", A.SpellLabel("growl"), TS.L("test_mob"), nil, "SELF")
  A.Emit("used", "taunt", nil, A.SpellLabel("taunt"), TS.L("test_mob"), nil, "SELF")
  A.Emit("cd", "shieldwall", nil, A.SpellLabel("shieldwall"), nil, nil, "SELF")
  A.Emit("opening", nil, "dodge", TS.L("melee"), TS.L("test_mob"), nil, "SELF")
end

----------------------------------------------------------------------
-- Wiring
----------------------------------------------------------------------
TS.OnInit(function()
  A.BuildSpellNames()
  A.BuildPatterns()
end)

TS.On("CHAT_MSG_SPELL_SELF_DAMAGE", function(event, msg) if TS.db and msg then A.OnSpellMessage(msg) end end)
TS.On("CHAT_MSG_SPELL_SELF_BUFF", function(event, msg) if TS.db and msg then A.OnSpellMessage(msg) end end)
TS.On("CHAT_MSG_COMBAT_SELF_MISSES", function(event, msg) if TS.db and msg then A.OnMeleeMessage(msg) end end)
TS.On("UNIT_CASTEVENT", function(event, a1, a2, a3, a4)
  if TS.db then A.OnCastEvent(event, a1, a2, a3, a4) end
end)
TS.On("PLAYER_REGEN_DISABLED", function()
  A.inCombat = true
  A.combatStart = GetTime()
end)
TS.On("PLAYER_REGEN_ENABLED", function() A.inCombat = false end)
TS.On("PLAYER_AURAS_CHANGED", function()
  if TS.db and TS.db.announce.removeSalvation then A.RemoveSalvation() end
end)
