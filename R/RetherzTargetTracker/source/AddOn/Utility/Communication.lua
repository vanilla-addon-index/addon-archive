local COMMUNICATION_VERSION = "0";     --TODO: Handle error message alerting new version is available.
local initialized = false;

function RTT_CommunicationInitialize()
  if(not initialized) then
    initialized = true;
    RTT_PREFIX_SPELL = RTT_PREFIX_SPELL .. COMMUNICATION_VERSION;
    RTT_PREFIX_TARGET = RTT_PREFIX_TARGET .. COMMUNICATION_VERSION;
  end
end

function RTT_HandleMessageData(prefix, data, sender)
  if(prefix == RTT_PREFIX_SPELL) then
    RTT_HandleSpellData(data);
    --todo pass data to spell data handler
  elseif(prefix == RTT_PREFIX_TARGET) then
    RTT_HandleTargetData(data, sender);
  end
end

function RTT_HandleTargetData(data, sender)
  if(data == "C") then
    if(not RTT_SenderHasPermission(sender)) then
      return;
    end
    RTT_RecieveClear();
  else
    local c, i = RTT_StringSplit(data, "_");
    local hc = tonumber(c);
    local n = tonumber(i);
    if(n ~= nil and hc ~= nil and hc > 0 and hc < 9 and RTT_Symbols[hc].state) then
      RTT_SetHealth(hc, n);
      return;
    end
    if(c == "RM") then
      if(not RTT_SenderHasPermission(sender)) then
        return;
      end
      RTT_RecieveRemove(i);
    else
      RTT_ActivateBar(i, c)
    end
  end
end

function RTT_HandleSpellData(data)
  local name, symbol = RTT_StringSplit(data, "_");
  if(name == "RM") then
    local _, buffName, target = RTT_StringSplit(data, "_");
    RTT_RecieveDebuff(tonumber(target), buffName);
  elseif(name == "PM") then
    local _, buffName, target = RTT_StringSplit(data, "_");
    RTT_Bar_SetDebuffPermanent(tonumber(target), buffName);
  else
    RTT_Bar_SetDebuff(tonumber(symbol), name);
  end
end

function RTT_SendAddonMessage(prefix, msg)
  if(GetNumRaidMembers() == 0) then
    SendAddonMessage(prefix, msg, "PARTY");
  else
    SendAddonMessage(prefix, msg, "RAID");
  end
end

function RTT_PlayerHasPermission()
  return (IsPartyLeader() or IsRaidLeader() or IsRaidOfficer());
end

function RTT_SenderHasPermission(sender)
  if(GetNumRaidMembers() > 0) then
  for i = 0, GetNumRaidMembers() do
    if(UnitName("raid" .. i) == sender) then
      local _, rank, _, _, _, _, _, _, _ = GetRaidRosterInfo(i);
      return  rank > 0;
    end
  end
  else
    for i = 0, GetNumPartyMembers() do
      if(UnitName("party" .. i) == sender) then
        return UnitIsPartyLeader("party" .. i);
      end
    end
  end
  return false;
end

function RTT_SendTargetData(...)
  local s = "";
  local n = getn(arg);
  for i = 1, n do
    s = s .. arg[i]
    if(i ~= n) then
      s = s .. "_";
    end
  end
  RTT_SendAddonMessage(RTT_PREFIX_TARGET, s);
end

function RTT_SendSetTarget(unit, i)
  if(not UnitIsFriend(unit, "player") and i ~= nil and UnitName(unit) ~= nil) then
    RTT_SendTargetData(UnitName(unit), i);
    RTT_SendTargetData(i, UnitHealth(unit));
  end
end

function RTT_SendSpellData(...)
  local s = "";
  local n = getn(arg);
  for i = 1, n do
    s = s .. arg[i]
    if(i ~= n) then
      s = s .. "_";
    end
  end
  RTT_SendAddonMessage(RTT_PREFIX_SPELL, s);
end

function RTT_SpellCastSent()
  if(not RTT_CastSpellData.sent and GetTime() - RTT_CastSpellData.timestamp > 0) then
    RTT_SendSpellData(RTT_CastSpellData.name, RTT_CastSpellData.symbol);
    RTT_CastSpellData.sent = true;
  end
end

function RTT_SendUntrack(target, buffName)
  RTT_SendSpellData("RM", buffName, target);
end

function RTT_SendPermanent(target, buffName)
  RTT_SendSpellData("PM", buffName, target);
end
