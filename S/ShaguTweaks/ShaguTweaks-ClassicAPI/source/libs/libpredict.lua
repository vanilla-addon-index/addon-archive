-- ClassicAPI supplies cast timing, not incoming heal amounts. Learn our own
-- direct heals and receive explicit-duration vanilla HealComm announcements.
local _G = ShaguTweaks.GetGlobalEnv()
local API = ShaguTweaks.API
local P = { pending = {}, enabled = false }
ShaguTweaks.libpredict = P
local learned, driver, player, sentGUID, sentTarget, sentSpell, activeGUID
local elapsed = 0
local equipment, equipmentReady = {}, false
local sharedHooks = {}
local hotAmounts, hotUnits = {}, {}
local trackedUnits = {"player", "target"}
local function HotTotal(unit)
  local state = hotUnits[unit]
  if not state or state.guid ~= UnitGUID(unit) then return 0 end
  local total, now = 0, GetTime()
  for _, hot in ipairs(state.entries) do if hot.expires > now then total = total + hot.amount end end
  return total
end
local function HotPending()
  local now = GetTime()
  for _, state in pairs(hotUnits) do
    for _, hot in ipairs(state.entries) do if hot.expires > now then return true end end
  end
  return false
end
local function EquipmentChanged()
  if not _G.GetInventoryItemLink then return false end
  local changed = false
  for slot = 1, 19 do
    local link = GetInventoryItemLink("player", slot)
    if equipment[slot] ~= link then changed = true end
    equipment[slot] = link
  end
  local ready = equipmentReady
  equipmentReady = true
  return ready and changed
end
local function Notify(target) if P.changed then P.changed(target) end end
local function Expire()
  elapsed = elapsed + (arg1 or 0)
  if elapsed < .1 then return end
  elapsed = 0
  local now, any = GetTime(), false
  for target, senders in pairs(P.pending) do
    local changed, remaining = false, false
    for sender, heal in pairs(senders) do
      if heal.expires <= now then senders[sender] = nil; changed = true
      else remaining = true; any = true end
    end
    if not remaining then P.pending[target] = nil end
    if changed then Notify(target) end
  end
  for _, state in pairs(hotUnits) do
    for i = table.getn(state.entries), 1, -1 do
      if state.entries[i].expires <= now then
        table.remove(state.entries, i)
        Notify(state.name)
      else any = true end
    end
  end
  if not any then driver:SetScript("OnUpdate", nil) end
end
function P:HealStop(sender)
  if not sender then return end
  for target, senders in pairs(self.pending) do
    if senders[sender] then
      senders[sender] = nil
      if not next(senders) then self.pending[target] = nil end
      Notify(target)
    end
  end
  if driver and not next(self.pending) and not HotPending() then driver:SetScript("OnUpdate", nil) end
end
function P:Heal(sender, target, amount, milliseconds)
  amount, milliseconds = tonumber(amount), tonumber(milliseconds)
  if not self.enabled or self.external or not sender or not target or target == "" or not amount or not milliseconds
    or amount <= 0 or amount > 10000000 or milliseconds <= 0 or milliseconds > 600000 then return end
  self:HealStop(sender)
  local senders = self.pending[target]
  if not senders then senders = {}; self.pending[target] = senders end
  senders[sender] = { amount = amount, expires = GetTime() + milliseconds / 1000 }
  Notify(target)
  elapsed = 0
  driver:SetScript("OnUpdate", Expire)
end
function P:UnitGetIncomingHeals(unit)
  if not self.enabled or not UnitExists(unit) or UnitIsDeadOrGhost(unit) then return 0 end
  if self.external then
    local guid = UnitGUID(unit)
    local amount = guid and self.external.GetIncomingHealing(guid)
    return type(amount) == "number" and amount > 0 and amount or 0
  end
  local senders = self.pending[UnitName(unit)]
  local sum, now = HotTotal(unit), GetTime()
  if senders then
    for _, heal in pairs(senders) do if heal.expires > now then sum = sum + heal.amount end end
  end
  return sum
end
local function RefreshHots(unit)
  if unit ~= "player" and unit ~= "target" then return end
  local state = hotUnits[unit]
  if not state then state = {entries={}}; hotUnits[unit] = state end
  state.guid, state.name = UnitGUID(unit), UnitName(unit)
  local auras, count, now = _G.C_UnitAuras, 0, GetTime()
  if auras and UnitExists(unit) and not UnitIsDeadOrGhost(unit) and UnitCanAssist("player", unit) then
    for index = 1, 48 do
      local name, duration, expires, source, spell, guid
      if type(auras.UnitBuff) == "function" then
        local n, _, _, _, d, e, s, _, _, id = auras.UnitBuff(unit, index)
        name, duration, expires, source, spell = n, d, e, s, id
        guid = source and UnitGUID(source)
      end
      if (not name or not guid) and type(auras.GetAuraDataByIndex) == "function" then
        local aura = auras.GetAuraDataByIndex(unit, index, "HELPFUL")
        if aura then
          name, duration, expires, spell = aura.name, aura.duration, aura.expirationTime, aura.spellId
          guid = aura.sourceGUID or (aura.sourceUnit and UnitGUID(aura.sourceUnit))
        end
      end
      if not name then break end
      local byCaster = guid and hotAmounts[guid]
      local amount = byCaster and byCaster[spell]
      if amount and expires and expires > now then
        count = count + 1
        local hot = state.entries[count] or {}
        state.entries[count] = hot
        hot.amount, hot.expires = amount, expires
      end
    end
  end
  for index = table.getn(state.entries), count+1, -1 do state.entries[index] = nil end
  -- Lua 5.0 caches the length used by table.remove; direct slot reuse must
  -- update it explicitly, or an expired/refreshed HoT can leave stale entries.
  table.setn(state.entries, count)
  Notify(state.name)
  if count > 0 then elapsed = 0; driver:SetScript("OnUpdate", Expire) end
end
local function TryShared()
  local shared = _G.PTHealPredict
  if type(shared) ~= "table" or type(shared.GetIncomingHealing) ~= "function"
    or type(shared.HookUpdates) ~= "function" then return false end
  -- Puppeteer uses SuperWoW GUIDs; never hand it incompatible identifiers.
  local _, guid = UnitExists("player")
  if not guid or guid ~= UnitGUID("player") then return false end
  P.external, P.source = shared, "Puppeteer"
  learned, activeGUID, sentGUID, sentTarget, sentSpell = nil, nil, nil, nil, nil
  if driver then driver:UnregisterAllEvents(); driver:SetScript("OnUpdate", nil) end
  for name in pairs(P.pending) do P.pending[name] = nil end
  hotUnits, hotAmounts = {}, {}
  if not sharedHooks[shared] then
    shared.HookUpdates(function(changedGUID)
      if not P.enabled or P.external ~= shared then return end
      for _, unit in ipairs(trackedUnits) do
        if UnitGUID(unit) == changedGUID then Notify(UnitName(unit)) end
      end
    end)
    sharedHooks[shared] = true
  end
  Notify(UnitName("player")); Notify(UnitName("target"))
  return true
end
local function Broadcast(message)
  if _G.AceLibrary and AceLibrary.HasInstance and AceLibrary:HasInstance("HealComm-1.0") then return end
  local channel = GetNumRaidMembers() > 0 and "RAID" or GetNumPartyMembers() > 0 and "PARTY"
  if channel then SendAddonMessage("HealComm", message, channel) end
end
local function StopOwn(guid)
  if guid and activeGUID and guid ~= activeGUID then return end
  P:HealStop(player)
  if activeGUID then Broadcast("Healstop") end
  activeGUID = nil
end
local function RefreshOwn()
  if not sentSpell or not learned[sentSpell] then return end
  local name, _, _, startTime, endTime = API.UnitCastingInfo("player")
  if not name or not startTime or not endTime then return end
  local remaining = endTime - GetTime() * 1000
  if remaining <= 0 then return end
  activeGUID = sentGUID
  P:Heal(player, sentTarget or player, learned[sentSpell], remaining)
  Broadcast("Heal/" .. (sentTarget or player) .. "/" .. learned[sentSpell] .. "/" .. math.floor(remaining) .. "/")
end
function P:ParseComm(sender, message)
  if type(sender) ~= "string" or type(message) ~= "string" then return end
  if message == "Healstop" or message == "GrpHealstop" or message == "001F" then self:HealStop(sender); return end
  local _, _, target, amount, duration = string.find(message, "^Heal/([^/]+)/(%d+)/(%d+)/$")
  if target then self:Heal(sender, target, amount, duration); return end
  local _, _, delay = string.find(message, "^Healdelay/(%d+)/$")
  delay = tonumber(delay)
  if delay and delay <= 60000 then
    for name, senders in pairs(self.pending) do
      if senders[sender] then senders[sender].expires = senders[sender].expires + delay/1000; Notify(name) end
    end
  end
end
local function Reset()
  for target in pairs(P.pending) do P.pending[target] = nil; Notify(target) end
  for unit, state in pairs(hotUnits) do hotUnits[unit] = nil; Notify(state.name) end
  if driver then driver:SetScript("OnUpdate", nil) end
  activeGUID, sentGUID, sentTarget, sentSpell = nil, nil, nil, nil
end
local function OnEvent()
  if event == "ADDON_LOADED" then
    TryShared()
  elseif event == "UNIT_AURA" then
    RefreshHots(arg1)
  elseif event == "PLAYER_TARGET_CHANGED" then
    RefreshHots("target")
  elseif event == "CHAT_MSG_ADDON" then
    if arg1 == "HealComm" and (arg3 == "PARTY" or arg3 == "RAID" or arg3 == "BATTLEGROUND") then P:ParseComm(arg4, arg2) end
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    if arg2 == "SPELL_PERIODIC_HEAL" and arg4 and arg8 and arg12 and tonumber(arg15)
      and tonumber(arg15) > 0 and arg18 ~= true and arg18 ~= 1 then
      -- Learn only ticks landing on one of the two displayed units. Keep
      -- direct and periodic amounts separate (Regrowth uses both).
      if arg8 == UnitGUID("player") or arg8 == UnitGUID("target") then
        local amounts = hotAmounts[arg4] or {}
        hotAmounts[arg4] = amounts
        amounts[arg12] = tonumber(arg15)
        if arg8 == UnitGUID("player") then RefreshHots("player") end
        if arg8 == UnitGUID("target") then RefreshHots("target") end
      end
      return
    end
    if arg2 == "SPELL_HEAL" and arg4 == UnitGUID("player") and arg12 and tonumber(arg15)
      and tonumber(arg15) > 0 and arg18 ~= true and arg18 ~= 1 then learned[arg12] = tonumber(arg15) end
  elseif event == "PLAYER_ENTERING_WORLD" then
    if TryShared() then return end
    player = UnitName("player"); Reset()
    if EquipmentChanged() then for spell in pairs(learned) do learned[spell] = nil end end
    RefreshHots("player"); RefreshHots("target")
  elseif event == "UNIT_INVENTORY_CHANGED" or event == "PLAYER_LEVEL_UP" or event == "CHARACTER_POINTS_CHANGED" then
    if event ~= "UNIT_INVENTORY_CHANGED" or (arg1 == "player" and EquipmentChanged()) then
      for spell in pairs(learned) do learned[spell] = nil end
      local guid = UnitGUID("player")
      if guid then hotAmounts[guid] = nil end
      StopOwn()
      RefreshHots("player"); RefreshHots("target")
    end
  elseif arg1 == "player" then
    if event == "UNIT_SPELLCAST_SENT" then
      sentTarget = arg2 and arg2 ~= "" and (UnitExists(arg2) and UnitName(arg2) or arg2) or player
      sentGUID, sentSpell = arg3, arg4
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" then
      if arg2 == sentGUID then RefreshOwn() end
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
      or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_SUCCEEDED" then StopOwn(arg2) end
  end
end
function P:Enable()
  if self.enabled then return end
  self.enabled = true
  if TryShared() then return end
  self.source = "ClassicAPI + HealComm"
  player = UnitName("player")
  learned = {} -- Session-only: actual gear/talent/level changes invalidate estimates.
  if EquipmentChanged() then
    local guid = UnitGUID("player")
    if guid then hotAmounts[guid] = nil end
  end
  driver = driver or CreateFrame("Frame")
  driver:SetScript("OnEvent", OnEvent)
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  driver:RegisterEvent("ADDON_LOADED")
  driver:RegisterEvent("PLAYER_TARGET_CHANGED")
  API.RegisterUnitEvent(driver,"UNIT_AURA","player","target")
  driver:RegisterEvent("CHAT_MSG_ADDON")
  driver:RegisterEvent("UNIT_INVENTORY_CHANGED")
  -- Form changes can produce SPELLS_CHANGED without changing any heal amount.
  -- New spell ranks have separate spell IDs and learn independently.
  driver:RegisterEvent("PLAYER_LEVEL_UP")
  driver:RegisterEvent("CHARACTER_POINTS_CHANGED")
  local native = {"UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "COMBAT_LOG_EVENT_UNFILTERED"}
  for _, name in ipairs(native) do if _G.C_EventUtils.IsEventValid(name) then driver:RegisterEvent(name) end end
  elapsed = 0
  RefreshHots("player"); RefreshHots("target")
end
function P:Disable()
  self.enabled = false
  self.external = nil
  if driver then driver:UnregisterAllEvents() end
  Reset()
end
