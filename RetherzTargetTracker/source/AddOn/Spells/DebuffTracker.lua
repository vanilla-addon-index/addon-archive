local debuffTooltip = CreateFrame("GameTooltip", "RTT_DebuffTooltip", nil, "GameTooltipTemplate")
debuffTooltip:SetOwner(UIParent, "ANCHOR_NONE");

function RTT_DebuffTrackMissing(bar, name)
  if(name == "Faerie Fire (Feral)") then
    name = "Faerie Fire";
  end
  for i=1,RetherzTargetTracker.DebuffCount do
    if(RTT_BarData[bar].debuffs[i].name == name
    and RTT_BarData[bar].debuffs[i].timestamp < GetTime()) then
      return true;
    end
  end
end

function RTT_DebuffTestTarget()
  if(UnitExists("target")) then
    local target = GetRaidTargetIndex("target");
    if(target ~= nil and not UnitIsFriend("target", "player")) then
      local time = GetTime();
      local debuffs = {};
      for i=1, RetherzTargetTracker.DebuffCount do
        table.insert(debuffs, RTT_TrackedDebuffs[i]);
      end
      for i=1, 16 do
         RTT_DebuffTooltip:SetUnitDebuff("target", i);
         local text = RTT_DebuffTooltipTextLeft1:GetText();
		     RTT_DebuffTooltip:ClearLines();
         if(text == nil) then
            i = 16;
          else
            if(RTT_DebuffIsTracked(text)) then
              for k, v in pairs(debuffs) do
                if(v == text) then
                  debuffs[k] = "";
                  if(RTT_DebuffTrackMissing(target, v)) then
                    if(RTT_PlayerHasPermission()) then
                      RTT_SendPermanent(target, v);
                    else
                      RTT_Bar_SetDebuffPermanent(target, v);
                    end
                  end
                end
              end
            end
          end
      end
      for k, v in pairs(debuffs) do
        RTT_UntrackDebuff(target, v, time);
      end
    end
  end
end

function RTT_DebuffIsTracked(name)
  for i=1, RetherzTargetTracker.DebuffCount do
    if(RTT_TrackedDebuffs[i] == name) then
      return true;
    end
  end
  return false;
end

function RTT_UntrackDebuff(bar, name, time)
  for i=1, RetherzTargetTracker.DebuffCount do
    if(RTT_BarData[bar].debuffs[i].name == name
    and RTT_BarData[bar].debuffs[i].timestamp > time) then
      if(RTT_PlayerHasPermission()) then
        RTT_SendUntrack(bar, name);
      else
        RTT_BarData[bar].debuffs[i].timestamp = 0;
      end
    end
  end
end

function RTT_RecieveDebuff(bar, name)
  for i=1, RetherzTargetTracker.DebuffCount do
    if(RTT_BarData[bar].debuffs[i].name == name) then
        RTT_BarData[bar].debuffs[i].timestamp = 0;
    end
  end
end
