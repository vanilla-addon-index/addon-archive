local AssignIndex = 8;

function RTT_AssignFree()
  if(RTT_PlayerHasPermission()) then
    for i=8, 1, -1 do
      if(RTT_Symbols[i].state ~= true) then
        RTT_Remove("target");
        SetRaidTarget("target", i);
        RTT_SendSetTarget("target", i);
        RTT_Symbols[i].state = true;
        return true;
      end
    end
  end
  return false;
end

function RTT_AssignFreeMO()
  if(RTT_PlayerHasPermission()) then
    for i=8, 1, -1 do
      if(RTT_Symbols[i] ~= true) then
        RTT_Remove("mouseover");
        SetRaidTarget("mouseover", i);
        RTT_SendSetTarget("mouseover", i);
        RTT_Symbols[i].state = true;
        return true;
      end
    end
  end
  return false;
end

function RTT_AssignNext()
  if(RTT_PlayerHasPermission()) then
    RTT_Remove("target");
    RTT_Symbols[AssignIndex].state = true;
    SetRaidTarget("target", AssignIndex);
    RTT_SendSetTarget("target", AssignIndex);
    if(AssignIndex == 1) then
      AssignIndex = 8;
    else
      AssignIndex = AssignIndex - 1;
    end
    return true;
  else
    return false;
  end
end

function RTT_AssignNextMO()
  if(RTT_PlayerHasPermission()) then
    RTT_Remove("mouseover");
    RTT_Symbols[AssignIndex].state = true;
    SetRaidTarget("mouseover", AssignIndex);
    RTT_SendSetTarget("mouseover", AssignIndex);
    if(AssignIndex == 1) then
      AssignIndex = 8;
    else
      AssignIndex = AssignIndex - 1;
    end
    return true;
  else
    return false;
  end
end

function RTT_ClearSymbols()
  if(not RTT_PlayerHasPermission()) then
    return
  end

  for i =1, 8 do
    SetRaidTarget("player", i);
    RTT_Symbols[i].state = false;
  end
  AssignIndex = 8;
  RTT_SendTargetData("C");
  hasCleared = true;
end

function RTT_Clear()
  if(hasCleared) then
    hasCleared = false;
    SetRaidTarget("player", 0);
  end
end

function RTT_ClearTarget()
  if(not UnitExists("target")) then
    return false;
  end
  RTT_Remove("target");
end

function RTT_ClearMO()
  if(not UnitExists("mouseover")) then
    return false;
  end
  RTT_Remove("mouseover");
end


function RTT_Target(symbol)
  for i = 0, GetNumRaidMembers() do
    if(RTT_GetTarget("raid" .. i .. "target", symbol)) then
      RTT_UseAction();
      return true;
    end
    for i = 0, GetNumPartyMembers() do
      if(RTT_GetTarget("party" .. i .. "target", symbol)) then
        RTT_UseAction();
        return true;
      end
    end
  end
  return false;
end

function RTT_TargetNext()
  if(not UnitExists("target")) then
    RTT_TargetIndexReset();
  else
  local i = GetRaidTargetIndex("target");
    if(i == nil) then
      RTT_TargetIndexReset();
    end
  end
  RTT_Target(RTT_NextTargetIndex());
end
