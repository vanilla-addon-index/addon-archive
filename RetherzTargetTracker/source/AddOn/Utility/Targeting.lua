local hasCleared = false;
RTT_Symbols = {
  [1] = {
    state = false;
    name = "Star";
    target = "TARGET_NAME";
    health = 100;
  },
  [2] = {
    state = false;
    name = "Circle";
    target = "TARGET_NAME";
    health = 100;
  },
  [3] = {
    state = false;
    name = "Diamond";
    target = "TARGET_NAME";
    health = 100;
  },
  [4] = {
    state = false;
    name = "Triangle";
    target = "TARGET_NAME";
    health = 100;
  },
  [5] = {
    state = false;
    name = "Moon";
    target = "TARGET_NAME";
    health = 100;
  },
  [6] = {
    state = false;
    name = "Square";
    target = "TARGET_NAME";
    health = 100;
  },
  [7] = {
    state = false;
    name = "Cross";
    target = "TARGET_NAME";
    health = 100;
  },
  [8] = {
    state = false;
    name = "Skull";
    target = "TARGET_NAME";
    health = 100;
  },
}

local TargetIndex = 8;

function RTT_TexCoord(i)
  i = i / 4;
  if(i > 1) then
    return i - 1.25, i - 1, 0.25, 0.5;
  else
    return i - 0.25, i, 0, 0.25;
  end
end

function RTT_TargetsExist()
  for i=1, 8 do
    if(RTT_Symbols[i].state) then
      return true;
    end
  end
  return false;
end

function RTT_TestTarget()
  if(UnitExists("target") and not UnitIsDead("target")) then
    local i = GetRaidTargetIndex("target");
    if(i ~= nil and RTT_Symbols[i].target ~= UnitName("target") and not UnitIsFriend("target", "player")) then
      if(RTT_PlayerHasPermission()) then
        RTT_SendSetTarget("target", i);
      else
        RTT_ActivateBar(i, UnitName("target"));
      end
    elseif(i ~= nil and UnitIsFriend("target", "player") and RTT_Symbols[i].state) then
      RTT_Remove("target");
    end
  end
end

function RTT_GetExistingTargets()
  local t = {}
  for i = 0, GetNumRaidMembers() do
    local ts = tonumber(GetRaidTargetIndex("raid" .. i .. "target"));
    if(ts ~= nil and t[ts] == nil) then
      table.insert(t, ts);
    end
    for i = 0, GetNumPartyMembers() do
      local ts = tonumber(GetRaidTargetIndex("party" .. i .. "target"));
      if(ts ~= nil and t[ts] == nil) then
        table.insert(t, ts);
      end
    end
  end
  return t;
end

function RTT_GetTarget(target, symbol)
  if(UnitExists(target) and GetRaidTargetIndex(target) == symbol) then
    TargetUnit(target);
    --use action configured id (slot) i.e auto attack.
    return true;
  end
  return false;
end

function RTT_Remove(unit)
  local i = GetRaidTargetIndex(unit);
  if(i ~= 0 and i ~= nil) then
    RTT_Symbols[i].state = false;
    SetRaidTarget(unit, 0);
    if(RTT_PlayerHasPermission()) then
      RTT_SendTargetData("RM", i);
    end
    return true;
  end
  return false;
end

function RTT_RecieveRemove(i)
  if(i ~= nil or i < 1 or i > 8) then
    return
  end
  RTT_Symbols[i].state = false;
  RTT_KillBar(i);
end

function RTT_RecieveClear()
  for i=1, 8 do
    RTT_Symbols[i].state = false;
    RTT_KillBar(i);
  end
end

function RTT_SetHealth(unit, health)
  RTT_Symbols[unit].health = health;
  getglobal("RTT_Bar" .. unit .. "HealthLabel"):SetText(health .. "%");
end

function RTT_NextTargetIndex()
  local i = TargetIndex;
  if(RTT_Symbols[i].state ~= false) then
    RTT_TargetIndexIncrement();
    return i;
  else
    for c=1, 8 do
      RTT_TargetIndexIncrement();
      if(RTT_Symbols[c].state ~= false) then
        RTT_TargetIndexIncrement();
        return c;
      end
    end
  end
end

function RTT_TargetIndexIncrement()
  if(TargetIndex == 1) then
    TargetIndex = 8;
  end
end

function RTT_TargetIndexReset()
  TargetIndex = 8;
end
