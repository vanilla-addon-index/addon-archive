local DuelDenial = CreateFrame("Frame", "NO_WORLD_BUFF_DUEL_DENIAL", UIParent);
local ru_buffTool = CreateFrame("GameTooltip", "ru_buff", UIParent, "GameTooltipTemplate");
ru_buffTool:SetOwner(UIParent, "ANCHOR_NONE");
DuelDenial:RegisterEvent("DUEL_REQUESTED")
local SayLoud = {};

local function Buffed(sBuff, target)
  for i=1,64,1 do
    ru_buffTool:ClearLines();
    ru_buffTool:SetUnitBuff(target, i);
    local buff = ru_buffTextLeft1:GetText();
    if (not buff) then
      break
    end;
    if (string.find(string.lower(buff),string.lower(sBuff))) then
      return true;
    end
  end
  return false;
end

local function Debuffed(sBuff, target)
  for i=1,64,1 do
    ru_buffTool:ClearLines();
    ru_buffTool:SetUnitDebuff(target, i);
    local buff = ru_buffTextLeft1:GetText();
    if (not buff) then
      break
    end;
    if (string.find(string.lower(buff),string.lower(sBuff))) then
      return true;
    end
  end
  return false;
end

local function BuffDebuff(sBuff, target)
	local t1 = Buffed(sBuff, target);
	if(t1 == true) then return true; end;
	local t2 = Debuffed(sBuff, target);
	if(t2 == true) then return true; end;
	return false;
end

local function PrintMSG(str)
	SendChatMessage(str ,"SAY");
end

DuelDenial:SetScript("OnEvent", function()
	local sT = UnitName("target");
	TargetByName(arg1, true);
	if(BuffDebuff("Sayge's Dark Fort","target") == true or BuffDebuff("Rallying Cry of the Dragonslayer","target") == true or BuffDebuff("Songflower Serenade","target") == true or BuffDebuff("Warchief's Blessing","target") == true or BuffDebuff("Spirit of Zoralar","target") == true or BuffDebuff("Traces of Silithyst","target") == true or BuffDebuff("Fengus's Ferocity","target") == true or BuffDebuff("Mol'dar's Moxie","target") == true or BuffDebuff("Slip'kik's Savvy","target") == true or BuffDebuff("Flask of the Titan","target") == true or BuffDebuff("Supreme Power","target") == true) then
		for x,y in pairs(SayLoud) do
			if(GetTime()-y >= 25) then
				SayLoud[x] = nil;
			end
		end
		if(not SayLoud[arg1]) then
			PrintMSG("[Duel Declined]:  {World Buff/Flask} Trash Player => " .. arg1 .. " detected.");
			SayLoud[arg1] = GetTime();
		end
		CancelDuel();
	end
	if(sT) then
		TargetByName(sT, true);
	else
		ClearTarget();
	end
end)

local info = ChatTypeInfo["SYSTEM"];
DEFAULT_CHAT_FRAME:AddMessage("Duel Denial loaded.", info.r, info.g, info.b, info.id);
