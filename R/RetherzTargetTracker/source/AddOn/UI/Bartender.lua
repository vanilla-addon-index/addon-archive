function RTT_Bar_DebuffUpdate(bar, index)
  if(not RTT_BarData[bar].debuffs[index].active) then
    return
  end
  local timeLeft = RTT_Round(RTT_BarData[bar].debuffs[index].timestamp - GetTime());
  local label = getglobal("RTT_Bar" .. bar .. "DebuffTextureLabel" .. index);
  local texture = getglobal("RTT_Bar" .. bar .. "DebuffTexture" .. index);
  if(timeLeft > 0) then
    texture:SetAlpha(1);
    label:SetAlpha(1);
    if(RTT_BarData[bar].debuffs[index].timestamp == 99999999999) then
      timeLeft= "N/A";
    end
    label:SetText(timeLeft);
  else
    texture:SetAlpha(0.25);
    label:SetAlpha(0.25);
    label:SetText("");
    RTT_BarData[bar].debuffs[index].active = false;
  end
end

function RTT_Bar_SetDebuff(bar, name)
  for i=1, RetherzTargetTracker.DebuffCount do
    if(name == RTT_BarData[bar].debuffs[i].name) then
      RTT_BarData[bar].debuffs[i].timestamp = GetTime()
        + RTT_SpellData_GetDuration(name) - 1;
        RTT_BarData[bar].debuffs[i].active = true;
    end
  end
end

function RTT_Bar_SetDebuffPermanent(bar, name)
  for i=1, RetherzTargetTracker.DebuffCount do
    if(name == RTT_BarData[bar].debuffs[i].name and RTT_BarData[bar].debuffs[i].timestamp < GetTime()) then
        RTT_BarData[bar].debuffs[i].timestamp = 99999999999;
        RTT_BarData[bar].debuffs[i].active = true;
    end
  end
end

function RTT_SetTrackedDebuff(i, name)
  for d=1, 8 do
    RTT_BarData[d].debuffs[i].name = name;
    local t = getglobal("RTT_Bar" .. d .. "DebuffTexture" .. i);
    t:SetTexture(RTT_SpellData_GetIcon(name));
  end
end

function RTT_UpdateHealth()
  if(not UnitExists("target") or UnitIsFriend("target", "player")) then
    return
  end
  local i = GetRaidTargetIndex("target");
  if(i ~= nil and UnitHealth("target") ~= RTT_Symbols[i].health) then
    RTT_SetHealth(i, UnitHealth("target"));
    if((UnitExists("targettarget")
      and UnitName("targettarget") == UnitName("player"))
      or not UnitExists("targettarget") and (IsPartyLeader() or IsRaidLeader() or IsRaidOfficer())) then
        RTT_SendTargetData(i, UnitHealth("target"));
    end
  end
end

function RTT_KillBar(i)
  for c=1, RetherzTargetTracker.DebuffCount do
    RTT_BarData[i].debuffs[c].timestamp = 0;
    local label = getglobal("RTT_Bar" .. i .. "DebuffTextureLabel" .. c);
    local texture = getglobal("RTT_Bar" .. i .. "DebuffTexture" .. c);
    texture:SetAlpha(0.25);
    label:SetAlpha(0.25);
    label:SetText("");
  end
  local f = getglobal("RTT_Bar" .. i);
  f:SetAlpha(0.5);
  local t = getglobal("RTT_Bar" .. i .. "NameLabel");
  t:SetText("");
  local t = getglobal("RTT_Bar" .. i .. "HealthLabel");
  t:SetText("");
  RTT_Symbols[i].target = "";
  RTT_Symbols[i].health = 0;
  RTT_Symbols[i].state = false;
end

function RTT_ActivateBar(bar, name)
    bar = tonumber(bar);
    local o = getglobal("RTT_Bar" .. bar .. "NameLabel");
    if(o == nil or tonumber(name) ~= nil) then
      return
    end
    o:SetText(name);
    RTT_Symbols[bar].target = name;
    RTT_Symbols[bar].state = true;
    local f = getglobal("RTT_Bar" .. bar);
    f:SetAlpha(1);
    for i=1, 4 do
      local label = getglobal("RTT_Bar" .. bar .. "DebuffTextureLabel" .. i);
      local texture = getglobal("RTT_Bar" .. bar .. "DebuffTexture" .. i);
      RTT_BarData[bar].debuffs[i].timestamp = 0;
      texture:SetAlpha(0.25);
      label:SetAlpha(0.25);
      label:SetText("");
    end
end
