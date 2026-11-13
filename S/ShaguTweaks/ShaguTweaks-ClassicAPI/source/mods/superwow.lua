-- SuperWoW compatibility
--
-- https://github.com/balakethelock/SuperWoW
--
-- This module adds GUID based cast and channel data to the
-- libcast library that is used to query enemy casting infos.

-- Skip module initialization if SuperWoW is not running.
if not GetPlayerBuffID or not CombatLogAdd or not SpellInfo then return end

local T = ShaguTweaks.T
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
  title = T["Super WoW Compatibility"],
  description = T["Adds compatibility for the SuperWoW client mod."],
  expansions = { ["vanilla"] = true },
  category = T["General"],
  enabled = true,
})

module.enable = function(self)
  if self.listener then return end
  local enemyTitle = T["Enemy Castbars"]
  local enabled = ShaguTweaks_config[enemyTitle]
  if enabled == nil then
    local consumer = ShaguTweaks.mods[enemyTitle]
    enabled = consumer and consumer.enabled and 1 or 0
  end
  if enabled ~= 1 then return end
  local libcast = ShaguTweaks.libcast
  local playerName = UnitName("player")
  local lastPrune = -1

  local function Changed(guid)
    if libcast.OnRemoteChanged then libcast.OnRemoteChanged(guid) end
  end

  local unitcast = CreateFrame("Frame")
  self.listener = unitcast
  unitcast:RegisterEvent("UNIT_CASTEVENT")
  unitcast:SetScript("OnEvent", function()
    local guid = arg1
    local event_type = arg3
    local spellID = arg4

    if type(guid) ~= "string" or type(spellID) ~= "number" then return end
    -- Player timing belongs to ClassicAPI (or Hunter-only local emulation).
    if guid == API.UnitGUID("player") then return end
    local now = GetTime()
    if now - lastPrune >= .5 then libcast:Prune(now); lastPrune = now end

    if event_type == "START" or event_type == "CAST" or event_type == "CHANNEL" then
      -- human readable argument list
      local timer = arg5
      if type(timer) ~= "number" or timer ~= timer or timer <= 0 or timer > 600000 then
        local cast = libcast.db[guid]
        if cast and cast.spellID == spellID then libcast.db[guid] = nil; Changed(guid) end
        return
      end

      -- A complete native record needs no second Lua copy. Keep SuperWoW
      -- timing only where the native unit-token query cannot provide it.
      local token = API.UnitTokenFromGUID(guid)
      if token then
        local name, finish
        if event_type == "CHANNEL" then
          local a, b, c, d, e, f = API.GetChannelInfo(token)
          name, finish = a, f
        else
          local a, b, c, d, e, f = API.GetCastInfo(token)
          name, finish = a, f
        end
        if name and finish and finish > now * 1000 then libcast.db[guid] = nil; return end
      end

      -- get spell info from spell id
      local spell, icon, _
      spell, _, icon = SpellInfo(spellID)

      -- set fallback values
      spell = spell or UNKNOWN
      icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"

      -- add cast action to the database
      local cast = libcast.db[guid]
      if not cast then
        -- Cache only a bounded number of live remote records, even in long
        -- sessions with unique NPC GUIDs. No permanent cleanup OnUpdate.
        local count, earliest, expiry = 0, nil, nil
        for key, entry in pairs(libcast.db) do
          if key ~= playerName then
            count = count + 1
            local ending = entry.start + entry.casttime/1000
            if not expiry or ending < expiry then earliest, expiry = key, ending end
          end
        end
        if count >= 128 and earliest then libcast.db[earliest] = nil end
        cast = {}
        libcast.db[guid] = cast
      end

      cast.cast = spell
      cast.rank = nil
      cast.start = now
      cast.casttime = timer
      cast.icon = icon
      cast.channel = event_type == "CHANNEL" or false
      cast.spellID = spellID

      -- write state variable
      ShaguTweaks.superwow_active = true
      Changed(guid)
    elseif event_type == "FAIL" then
      local cast = libcast.db[guid]

      -- Ignore a delayed FAIL for an older spell. Otherwise it can erase a
      -- newer cast from the same GUID that already replaced it in the cache.
      if cast and cast.spellID == spellID then
        libcast.db[guid] = nil
        Changed(guid)
      end
    end
  end)
end
