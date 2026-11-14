-- AdeSPD events and slash commands.

local A = AdeSPD
local Round = A.Round
local try = A.try

local function MergeDefaults()
  if type(AdeSPDDB) ~= "table" then AdeSPDDB = {} end
  local k, v
  for k, v in pairs(A.DB) do
    if AdeSPDDB[k] == nil then AdeSPDDB[k] = v end
  end
  A.DB = AdeSPDDB
end

local function EnableNampowerEvents()
  -- Registering the events is enough from Nampower 4.5.0; older builds need the CVars.
  local cv = { "NP_EnableSpellHealEvents", "NP_EnableAuraCastEvents", "NP_EnableSpellGoEvents" }
  local i
  for i = 1, 3 do pcall(SetCVar, cv[i], "1") end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
frame:RegisterEvent("SPELL_DAMAGE_EVENT_SELF")
frame:RegisterEvent("SPELL_HEAL_BY_SELF")
frame:RegisterEvent("PLAYER_COMBO_POINTS")
frame:RegisterEvent("TRAINER_SHOW")
frame:RegisterEvent("TRAINER_UPDATE")
frame:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    if arg1 == "AdeSPD" then
      MergeDefaults()
      A.Detect()
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    A.Detect()
    A.MarkGearDirty()
    EnableNampowerEvents()
    A.InstallHooks()
    if not A.np then
      A.Print("Nampower not found: only the built-in coefficient table works (no talents, buffs or learning).")
    end
    A.RefreshIndex(false)
  elseif event == "SPELLS_CHANGED" then
    if A.np and not A.IsScanning() then A.RefreshIndex(false) end
  elseif event == "UNIT_INVENTORY_CHANGED" then
    if arg1 == "player" then A.MarkGearDirty() end
  elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
    if A.DB.dump ~= false and A.DumpTrainer then
      local ok, err = pcall(A.DumpTrainer, event == "TRAINER_UPDATE")
      if not ok then A.DB.lasterror = err end
    end
  elseif event == "PLAYER_COMBO_POINTS" then
    -- remember the last non-zero count: a finisher spends the points before its damage event arrives
    local n = 0
    if GetComboPoints then n = GetComboPoints() or 0 end
    local prev = A.cpNow or 0
    local now = GetTime and GetTime() or 0
    if n < prev then
      A.spent, A.spentT = prev, now                  -- points used up (a new point right after, Ruthlessness, must not count)
    elseif n > prev and A.spent and now - (A.spentT or 0) > 0.5 then
      A.spent = nil
    end
    A.cpNow = n
    if n > 0 then A.cp = n end
  elseif event == "SPELL_DAMAGE_EVENT_SELF" then
    A.OnDamage(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
  elseif event == "SPELL_HEAL_BY_SELF" then
    A.OnHeal(arg1, arg2, arg3, arg4, arg5, arg6)
  end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function OnOff(msg, cur)
  if msg == "on" then return true end
  if msg == "off" then return false end
  return not cur
end

local function Status()
  local nver = ""
  if type(GetNampowerVersion) == "function" then
    local a, b, c = GetNampowerVersion()
    nver = " v" .. tostring(a) .. "." .. tostring(b) .. "." .. tostring(c)
  end
  A.Print("Nampower: " .. (A.np and ("found" .. nver) or "NOT found"))
  A.Print("SuperWoW: " .. (A.swow and "found" or "not found (optional)"))
  A.Print("ClassicAPI spell power: " .. (A.capi and "found" or "not found (gear + buff scan is used)"))
  local DB = A.DB
  A.Print("enabled=" .. tostring(DB.enabled) .. " mods=" .. tostring(DB.mods) .. " learn=" .. tostring(DB.learn)
    .. " book=" .. tostring(DB.spellbook) .. " detail=" .. tostring(DB.detail) .. " prefer=" .. tostring(DB.prefer))
  A.Print("client language: " .. tostring(try(GetLocale)) .. ", numbers from the spell record (extra lines): " .. tostring(A.RecordMode())
    .. " (/spd record on|off|auto)")
  local nk, nl = 0, 0
  local k
  for k in pairs(A.idByKey) do nk = nk + 1 end
  for k in pairs(DB.learned) do nl = nl + 1 end
  A.Print("learner events skipped: " .. A.SkipCount() .. " (see /spd why)")
  A.Print("indexed spell ranks: " .. nk .. (A.IsScanning() and " (indexing...)" or "") .. ", spells with combat data: " .. nl)
  if DB.lasterror then A.Print("last error: " .. tostring(DB.lasterror)) end
end

local function Debug()
  Status()
  local heal, src = A.SpellPower(true, nil)
  local hc = A.ComputedSpellPower(true, nil)
  A.Print("healing power: " .. Round(heal) .. " (" .. src .. "), gear+buff scan: " .. Round(hc))
  local s
  for s = 2, 7 do
    local v, sr = A.SpellPower(false, s)
    local c = A.ComputedSpellPower(false, s)
    A.Print(A.SCHOOL_NAMES[s] .. ": " .. Round(v) .. " (" .. sr .. "), gear+buff scan: " .. Round(c))
  end
  A.Print("attack power: " .. Round((A.AttackPower(false))) .. ", ranged attack power: " .. Round((A.AttackPower(true))))
  A.Print("If the two numbers differ while buffs are active, the API value includes (or misses) them.")
end

local function Auras()
  local ids, n = A.PlayerAuraIds()
  A.Print(n .. " auras found")
  local k, i
  for k = 1, n do
    local I = A.Info(ids[k])
    if I then
      local desc = ""
      for i = 1, 3 do
        local e = I.eff[i]
        if e.aura == 13 or e.aura == 79 or e.aura == 135 or e.aura == 136 then
          desc = desc .. " [aura " .. e.aura .. " value " .. (e.bp + 1) .. " mask " .. e.misc .. "]"
        end
      end
      A.Print(ids[k] .. " " .. tostring(I.name) .. desc)
    else
      A.Print(ids[k] .. " (no record)")
    end
  end
end

local function Probe(name)
  if name == "" or name == "<spell>" then A.Print("/spd probe <spell name>, e.g. /spd probe Holy Fire") return end
  local id = try(GetSpellIdForName, name)
  if type(id) ~= "number" or id <= 0 then A.Print("spell not found in your spellbook: " .. name) return end
  local I = A.Info(id)
  A.Print(name .. " id " .. id .. " (highest rank)")
  if not I then return end
  local i
  for i = 1, 3 do
    local e = I.eff[i]
    if e.type ~= 0 or e.aura ~= 0 then
      local lo, hi = A.Range(e, I)
      A.Print("  effect " .. i .. ": type " .. e.type .. " aura " .. e.aura .. " base " .. e.bp .. " sides " .. e.sides
        .. " perLevel " .. e.rppl .. " amp " .. e.amp .. " trigger " .. e.trig .. "  -> range " .. lo .. ".." .. hi)
      if e.trig > 0 then
        local T = A.Info(e.trig)
        if T then
          local j
          for j = 1, 3 do
            local te = T.eff[j]
            if te.type ~= 0 or te.aura ~= 0 then
              local tlo, thi = A.Range(te, T)
              A.Print("    triggered " .. e.trig .. " " .. tostring(T.name) .. " effect " .. j .. ": type " .. te.type
                .. " aura " .. te.aura .. " range " .. tlo .. ".." .. thi .. " school " .. T.school)
            end
          end
        end
      end
    end
  end
  local wk = A.WeaponKind(I)
  A.Print("  attack power mode: " .. tostring(A.UsesAP(I, AdeSPD_Data[I.en or I.name] or (AdeSPD_Melee and AdeSPD_Melee[I.en or I.name])))
    .. ", ranged " .. tostring(A.IsRanged(I, nil)) .. ", weapon effect " .. tostring(wk) .. ", combo points " .. tostring(A.HasCombo(I)))
  local P = A.Parts(I)
  A.Print("  parts: direct dmg " .. tostring(P.d) .. ", dot " .. tostring(P.o) .. ", direct heal " .. tostring(P.hd)
    .. ", hot " .. tostring(P.ho) .. ", school " .. I.school .. ", level " .. I.spellLevel .. "/" .. I.baseLevel .. "/" .. I.maxLevel)
  local mid = A.ModSpellId(I)
  local t
  local types = { 0, 22, 7, 10, 14, 24 }
  local names = { "damage", "dot", "crit", "cast time", "cost", "bonus damage" }
  for t = 1, 6 do
    local f, m = A.Mods(mid, types[t])
    A.Print("  modifier " .. names[t] .. " (spell " .. mid .. "): flat " .. f .. ", multiplier x" .. m)
  end
end

-- Runs the tooltip code over every weapon damage ability in your spellbook and lists the ones that end up
-- without a "Total damage" line, with their text, so the wording can be added.
local function WeaponCheck()
  if not A.np then A.Print("needs Nampower") return end
  local tip = getglobal("AdeSPDWeaponTip")
  if not tip then tip = CreateFrame("GameTooltip", "AdeSPDWeaponTip", nil, "GameTooltipTemplate") end
  local seen, okn, bad = {}, 0, 0
  local tabs = try(GetNumSpellTabs) or 0
  local t, i, k
  for t = 1, tabs do
    local _, _, off, num = GetSpellTabInfo(t)
    for i = off + num, off + 1, -1 do                       -- highest rank of a name comes last in the book
      local n, r = GetSpellName(i, "spell")
      if n and not seen[n] then
        seen[n] = true
        local id = A.IdFor(n, A.RankNum(r))
        local I = id and A.Info(id)
        if I and A.WeaponKind(I) and not A.IsPassive(I) then
          tip:SetOwner(WorldFrame, "ANCHOR_NONE")
          tip:ClearLines()
          tip:SetSpell(i, "spell")
          A.Process(tip)
          local has, text = false, nil
          for k = 2, tip:NumLines() do
            local fs = getglobal("AdeSPDWeaponTipTextLeft" .. k)
            local tx = fs and fs:GetText()
            if tx then
              if string.find(tx, "Total damage", 1, true) then has = true end
              if not text and string.find(tx, "damage", 1, true) then text = tx end
            end
          end
          if has then
            okn = okn + 1
          else
            bad = bad + 1
            A.Print(n .. ": no total. " .. string.gsub(text or "(no damage text)", "|c%x%x%x%x%x%x%x%x", ""))
          end
        end
      end
    end
  end
  A.Print("weapon abilities with a total line: " .. okn .. ", without: " .. bad)
end

local function Explain()
  A.Print(A.last or "hover a spell first, then run /spd explain")
end

local function WhySpell(name)
  local want = string.lower(name)
  local any = false
  local id, cnt
  for id, cnt in pairs(A.seen) do
    local I = A.Info(id)
    local nm = I and I.name or ""
    local own = A.trigOwner[id]
    local OI = own and A.Info(own)
    if string.lower(nm) == want or (OI and string.lower(OI.name or "") == want) then
      any = true
      A.Print("event spell " .. id .. " (" .. nm .. ")" .. (own and (" owner " .. own) or "") .. ": " .. cnt
        .. " events, last skip: " .. tostring(A.skipById[id] or "none"))
    end
  end
  if any then
    local k
    for k = 1, 8 do
      if A.notes[k] then A.Print("  " .. A.notes[k]) end
    end
    if A.outliers and A.outliers > 0 then A.Print("  hits dropped as outliers: " .. A.outliers) end
    for id, cnt in pairs(A.DB.learned) do
      local I = A.Info(id)
      if I and string.lower(I.name or "") == want then
        local mean, n, se = A.LearnedStats(id, "d")
        if mean then
          local s = A.DB.learned[id].d
          A.Print(string.format("  id %d: %d hits, coefficient %.4f, error %.4f, weight %s, avg power x points %d, final %s",
            id, n, mean, se, tostring(s.w), (s.p or 0) / (n > 0 and n or 1), tostring(A.LearnedFinal(id, "d"))))
        end
      end
    end
  end
  if not any then
    local list, n = "", 0
    for id, cnt in pairs(A.seen) do
      if n < 10 then
        local I = A.Info(id)
        list = list .. " " .. id .. "=" .. cnt .. (I and ("(" .. tostring(I.name) .. ")") or "(no record)")
        n = n + 1
      end
    end
    A.Print("no damage / heal events matched '" .. name .. "'. Spell ids seen since login:" .. (n > 0 and list or " none"))
  end
end

local function Why(rest)
  if rest and rest ~= "" then WhySpell(rest) return end
  A.Print("learner: " .. A.SkipCount() .. " events skipped so far, last reasons:")
  local i, any = nil, false
  for i = 1, 12 do
    if A.skips[i] then
      any = true
      A.Print("  " .. A.skips[i])
    end
  end
  if not any then A.Print("  none") end
  local k, anyn = nil, false
  for k = 1, 6 do
    if A.notes[k] then
      if not anyn then A.Print("recent combo point measurements:") anyn = true end
      A.Print("  " .. A.notes[k])
    end
  end
  if A.outliers and A.outliers > 0 then A.Print("hits dropped as outliers: " .. A.outliers) end
end

local function Compare()
  local DB = A.DB
  local any = false
  local id, L
  for id, L in pairs(DB.learned) do
    local I = A.Info(id)
    local nm = I and I.name or tostring(id)
    local rk = I and I.rank or ""
    local part
    local names = { d = "direct", o = "over time", hd = "direct heal", ho = "heal over time" }
    for _, part in ipairs({ "d", "o", "hd", "ho" }) do
      local mean, cnt, se = A.LearnedStats(id, part)
      if mean then
        any = true
        local tv = ""
        local e = AdeSPD_Data[(I and I.en) or nm]
        if e then
          local base = string.sub(part, -1)                  -- "d" or "o"
          local isHeal = (string.len(part) == 2)
          if e[base] and ((e.heal and isHeal) or ((not e.heal) and not isHeal)) then
            tv = string.format(", table %.1f%%", e[base] * 100)
          end
        end
        A.Print(string.format("%s %s %s: learned %.1f%% +-%.1f (%d hits)%s", nm, rk, names[part],
          mean * 100, se * 100, cnt, tv))
      end
    end
  end
  if not any then A.Print("no combat data yet") end
end

local function Forget(arg)
  local DB = A.DB
  if arg == "all" then
    DB.learned = {}
    A.Print("all combat data deleted")
    return
  end
  local id, L, removed = nil, nil, 0
  local ids = {}
  for id in pairs(DB.learned) do
    local I = A.Info(id)
    if I and string.lower(I.name or "") == string.lower(arg) then table.insert(ids, id) end
  end
  local k
  for k = 1, table.getn(ids) do
    DB.learned[ids[k]] = nil
    removed = removed + 1
  end
  A.Print(removed .. " spell(s) forgotten")
end

-- Runs a command that prints a lot and shows its output in the AdeSPD window (chat when /spd window off).
local function Run(title, fn, a)
  if not A.DB.window then fn(a) return end
  A.capture = {}
  local ok, err = pcall(fn, a)
  local buf = A.capture
  A.capture = nil
  if not ok then table.insert(buf, "error: " .. tostring(err)) end
  if table.getn(buf) == 0 then return end
  if not A.ShowWindow(title, buf) then
    local i
    for i = 1, table.getn(buf) do A.Print(buf[i]) end
  end
end

SLASH_ADESPD1 = "/spd"
SLASH_ADESPD2 = "/adespd"
SlashCmdList["ADESPD"] = function(msg)
  msg = msg or ""
  local _, _, cmd, rest = string.find(msg, "^(%S*)%s*(.-)$")
  cmd = string.lower(cmd or "")
  rest = rest or ""
  local DB = A.DB
  if cmd == "on" or cmd == "off" then
    DB.enabled = (cmd == "on")
    A.Print(DB.enabled and "enabled" or "disabled")
  elseif cmd == "book" then
    DB.spellbook = OnOff(string.lower(rest), DB.spellbook)
    A.Print("spellbook tooltips " .. (DB.spellbook and "changed too" or "left untouched (action bars only)"))
  elseif cmd == "detail" then
    DB.detail = OnOff(string.lower(rest), DB.detail)
    A.Print("detail line " .. (DB.detail and "on" or "off"))
  elseif cmd == "mods" then
    DB.mods = OnOff(string.lower(rest), DB.mods)
    A.Print("talent/buff modifiers " .. (DB.mods and "on" or "off"))
  elseif cmd == "learn" then
    DB.learn = OnOff(string.lower(rest), DB.learn)
    A.Print("combat learning " .. (DB.learn and "on" or "off"))
  elseif cmd == "log" then
    DB.log = OnOff(string.lower(rest), DB.log)
    A.Print("event log " .. (DB.log and "on" or "off"))
  elseif cmd == "prefer" then
    rest = string.lower(rest)
    if rest == "table" or rest == "learned" then
      DB.prefer = rest
      A.Print("prefer " .. rest .. " coefficients")
    else
      A.Print("/spd prefer table | learned")
    end
  elseif cmd == "dump" then
    local v = string.lower(rest or "")
    if v == "book" then A.DumpBook()
    elseif v == "clear" then A.DumpClear()
    elseif v == "off" then DB.dump = false A.DumpStatus()
    elseif v == "on" then DB.dump = true A.DumpStatus()
    else A.DumpStatus() A.Print("/spd dump book (spellbook texts) | on | off (automatic trainer dump) | clear. Visit a trainer to save its spells.") end
  elseif cmd == "record" then
    local v = string.lower(rest or "")
    if v == "on" or v == "off" or v == "auto" then
      DB.record = v
      A.Print("record mode " .. v .. (A.RecordMode() and ": numbers come from the spell record, added as extra lines" or ": numbers are written into the tooltip text (English)"))
    else
      A.Print("/spd record on | off | auto   (now " .. tostring(DB.record) .. ", active: " .. tostring(A.RecordMode()) .. ")")
    end
  elseif cmd == "status" then
    Status()
  elseif cmd == "debug" then
    Run("AdeSPD debug", Debug)
  elseif cmd == "auras" then
    Run("AdeSPD auras", Auras)
  elseif cmd == "probe" then
    Run("AdeSPD probe " .. rest, Probe, rest)
  elseif cmd == "weapon" then
    Run("AdeSPD weapon abilities", WeaponCheck)
  elseif cmd == "explain" then
    Run("AdeSPD explain", Explain)
  elseif cmd == "why" then
    Run("AdeSPD why", Why, rest)
  elseif cmd == "compare" then
    Run("AdeSPD compare", Compare)
  elseif cmd == "armor" then
    DB.armor = OnOff(string.lower(rest), DB.armor)
    A.Print("target armor in physical tooltip numbers " .. (DB.armor and "on" or "off"))
  elseif cmd == "window" then
    DB.window = OnOff(string.lower(rest), DB.window)
    A.Print("output window " .. (DB.window and "on" or "off (chat)"))
  elseif cmd == "forget" then
    if rest == "" then A.Print("/spd forget <spell name> | all") else Forget(rest) end
  elseif cmd == "rescan" then
    A.RefreshIndex(true)
  elseif cmd == "scan" then
    local v = tonumber(rest)
    if v and v >= 1000 then DB.maxId = v A.Print("scan limit " .. v) else A.Print("/spd scan <max spell id>, now " .. DB.maxId) end
  else
    A.Print("/spd on | off | armor | window | record | dump | book | detail | mods | learn | prefer table|learned | status | debug | auras | probe <spell> | weapon | explain | why [spell] | compare | forget <spell>|all | log | rescan | scan <maxid>")
  end
end
