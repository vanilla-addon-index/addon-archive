--         --------------------------------
--        |  Configuration                 |
--         --------------------------------

-- font
local font_size       = 14;

--         --------------------------------
--        |  Don't edit below              |
--         --------------------------------

tankhelperframe = CreateFrame("Frame","tankhelperframe",UIParent)

local backdrop = {
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
			tile="false",
			tileSize="8",
			edgeSize="8",
			insets={
				left="2",
				right="2",
				top="2",
				bottom="2"
			}
	}

-- Frame
tankhelperframe:SetWidth(160); tankhelperframe:SetHeight(50);
tankhelperframe:SetMovable(1); tankhelperframe:EnableMouse(1);
tankhelperframe:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
tankhelperframe:SetFrameStrata("BACKGROUND")
tankhelperframe:SetBackdrop(backdrop)
tankhelperframe:SetBackdropColor(0,0,0,1)

-- Events
tankhelperframe:RegisterEvent("ADDON_LOADED")
tankhelperframe:RegisterEvent("UNIT_AURA")
tankhelperframe:RegisterEvent("UNIT_ATTACK")
tankhelperframe:RegisterEvent("UNIT_ATTACK_POWER")
tankhelperframe:RegisterEvent("UNIT_ATTACK_SPEED")
tankhelperframe:RegisterEvent("UNIT_DAMAGE")
tankhelperframe:RegisterEvent("UNIT_RESISTANCES")
tankhelperframe:RegisterEvent("PLAYER_TARGET_CHANGED")

tankhelperframe:SetScript("OnEvent", function() TankHelper_OnEvent(event, arg1) end)

local ArmorMiti = 0

-- Moving the frame
tankhelperframe:SetScript("OnMouseDown", function()
	if IsShiftKeyDown() then
		if arg1 == "LeftButton" then tankhelperframe:StartMoving()
		elseif arg1 == "RightButton" then
			if ArmorMiti == 0 then
				DEFAULT_CHAT_FRAME:AddMessage("TankHelper: Armor mitigation calculation |cffFF0000ON")
				ArmorMiti = 1
			else
				DEFAULT_CHAT_FRAME:AddMessage("TankHelper: Armor mitigation calculation |cffFF0000OFF")
				ArmorMiti = 0
			end
			TankHelper_OnEvent()
		end
	end
end)
tankhelperframe:SetScript("OnMouseUp", function() tankhelperframe:StopMovingOrSizing() end)
tankhelperframe:SetScript("OnDragStop", function() tankhelperframe:StopMovingOrSizing() end)

-- Text
local mobstats = tankhelperframe:CreateFontString();
mobstats:SetFontObject(GameFontNormal);
mobstats:SetPoint("Topleft", tankhelperframe, "Topleft", 2, -3);
mobstats:SetJustifyH("LEFT")
mobstats:SetJustifyV("TOP")

local font, size, flags = GameFontNormal:GetFont();
mobstats:SetFont(font, font_size, "OUTLINE");

-- Chat command
function TankHelperFrameOptions(cmd)
	if cmd == nil or cmd == "" then -- Commands list
		DEFAULT_CHAT_FRAME:AddMessage("TankHelper commands list: show | hide | reset | scale {default 1.0} | alpha {default 1.0}\nShift+Left mouse drag to move, Shift+Right mouse click to toggle armor mitigation.")
		return
	end
	cmd = string.lower(cmd)
	if cmd == "hide" then
		tankhelperframe:Hide()
		DEFAULT_CHAT_FRAME:AddMessage("TankHelper hidden. Type /tankhelper show to enable")
		TankHelper_show = 0
		return
	end
	if cmd == "show" then
		tankhelperframe:Show()
		DEFAULT_CHAT_FRAME:AddMessage("TankHelper shown. Type /tankhelper hide to disable")
		TankHelper_show = 1
		return
	end
	if cmd == "reset" then
		tankhelperframe:Show()
		tankhelperframe:ClearAllPoints()
		tankhelperframe:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		tankhelperframe:SetScale(1)
		tankhelperframe:SetAlpha(1)
		TankHelper_show = 1
		TankHelper_scale = 1
		TankHelper_alpha = 1
		ArmorMiti = 0
		DEFAULT_CHAT_FRAME:AddMessage("TankHelper options reset")
		return
	end
	local THargumentsplit = string.find(cmd, "%s")
	if THargumentsplit then
		DEFAULT_CHAT_FRAME:AddMessage(THargumentsplit)
		arg1 = string.sub(cmd, 1 , THargumentsplit-1)
		arg2 = string.sub(cmd, THargumentsplit+1)
		arg2num = tonumber(arg2)
		if not arg2num then
			DEFAULT_CHAT_FRAME:AddMessage("TankHelper: Inappropriate command syntax")
			return
		end
		if arg1 == "scale" then
			tankhelperframe:ClearAllPoints()
			tankhelperframe:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
			DEFAULT_CHAT_FRAME:AddMessage("TankHelper: Set frame scale to "..arg2num)
			tankhelperframe:SetScale(arg2num)
			TankHelper_scale = arg2num
			return
		end
		if arg1 == "alpha" then
			DEFAULT_CHAT_FRAME:AddMessage("TankHelper: Set frame alpha to "..arg2num)
			tankhelperframe:SetAlpha(arg2num)
			TankHelper_alpha = arg2num
			return
		end
	end
end

SLASH_TANKHELPER1 = '/tankhelper'
SlashCmdList.TANKHELPER = TankHelperFrameOptions

local function mitigated(dmg)
	local armor = UnitResistance("player", 0)
	if armor < 0 then armor = 0 end
	local target_level = UnitLevel("target")
	local tmpvalue = 0.1 * armor / (8.5 * target_level + 40)
	tmpvalue = tmpvalue / (1 + tmpvalue)
	if tmpvalue < 0 then tmpvalue = 0 end
	if tmpvalue > 0.75 then tmpvalue = 0.75 end
	return dmg - (dmg * tmpvalue)
end

function TankHelper_OnEvent()
if (event == "ADDON_LOADED") and (arg1 == "TankHelper") then
	if TankHelper_show == nil then -- if first time loading
		TankHelper_show = 1
		TankHelper_scale = 1
		TankHelper_alpha = 1
	end
	tankhelperframe:SetScale(TankHelper_scale) -- load saved settings. It seems position saves on its own.
	tankhelperframe:SetAlpha(TankHelper_alpha)
	if TankHelper_show == 0 then
		tankhelperframe:Hide()
	end
	return
end
if(UnitExists("target") and not UnitIsPlayer("target")) then
	--Swing damage
	lowDmg, hiDmg, offlowDmg, offhiDmg, posBuff, negBuff, percentmod = UnitDamage("target");
	if ArmorMiti == 1 then
		lowDmg = floor(mitigated(lowDmg))
		hiDmg = ceil(mitigated(hiDmg))
	end
	local swingstring = "|cffFFFFFFSwing:"..floor(lowDmg).."-"..ceil(hiDmg);
	if (offlowDmg > 1) then -- means the mob has an offhand weapon
		swingstring = swingstring.." |cffFF0000DW!";
	end
	
	--Attack power
	base, buff, debuff = UnitAttackPower("target");
	local currentap = base + buff + debuff;
	local apstring = "|cffFFFFFFAP: "..currentap.."/"..base;
	local apdiff = base - currentap
	if UnitLevel("player") == 60 and apdiff <= 110 then -- warns when mob does not have demo shout or demo roar
		apstring = apstring.." |cffFF0000DEMO!";
	end
	
	--Attack Speed
	mainSpeed = UnitAttackSpeed("target");
	local speedstring = "|cffFFFFFFAS: "..string.format("%.2f", mainSpeed);
	
	--Estimated DPS
	local dpscalc = floor(lowDmg*0.5/mainSpeed + hiDmg*0.5/mainSpeed)
	if ArmorMiti == 1 then
		dpscalc = "|cff74B72E"..dpscalc -- Green color if armor mitigation is toggled on, just for clarity
	end
	
	--Print combined text
	mobstats:SetText(swingstring.."\n"
					..apstring.."\n"
					..speedstring.." | DPS: "..dpscalc);
else mobstats:SetText(" "); --if not targeting an enemy mob, print nothing.
end
end
