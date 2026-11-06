--[[
	Slash.lua
		This is the slash command handler for Bagnon
		Author: Tuller, McPewPew, Fostercare5988
		Built for ClassicAPI
--]]

if not Bagnon_EngineReady then
	return
end

function BagnonSlash_DisplayHelp()
	BagnonMsg(BAGNON_HELP_TITLE);
	BagnonMsg(BAGNON_HELP_HELP);
	BagnonMsg(BAGNON_HELP_SHOWBAGS);
	BagnonMsg(BAGNON_HELP_SHOWBANK);
	BagnonMsg(BAGNON_HELP_SORT);
	BagnonMsg(BAGNON_HELP_FREESLOTS);
	BagnonMsg(BAGNON_HELP_ENCHANTS);

	BagnonMsg(BAGNON_FOREVER_HELP_DELETE_CHARACTER)
end

local argsBuffer = {}

SlashCmdList["BagnonCOMMAND"] = function(msg)
	if(not msg or msg == "") then
		BagnonOptions_Toggle()
	else
		table.wipe(argsBuffer)
		for word in string.gmatch(msg, "[^%s]+") do
			table.insert(argsBuffer, word)
		end
		local cmd = string.lower(argsBuffer[1] or "")

		if(cmd == BAGNON_COMMAND_HELP) then
			BagnonSlash_DisplayHelp();
		elseif(cmd == BAGNON_COMMAND_SHOWBANK) then
			BagnonFrame_Toggle("Banknon");
		elseif(cmd == BAGNON_COMMAND_SHOWBAGS) then
			BagnonFrame_Toggle("Bagnon");
		elseif(cmd == BAGNON_COMMAND_SORT) then
			if Banknon:IsShown() and not Bagnon_IsCachedFrame(Banknon) and Bagnon_AtBank() then
				Bagnon_RequestSort(true)
			else
				if Bagnon_IsCachedFrame(Bagnon) then
					BagnonMsg(BAGNON_CANNOT_SORT_OFFLINE)
				else
					Bagnon_RequestSort(false)
				end
			end
		elseif(cmd == BAGNON_COMMAND_FREESLOTS) then
			if BagnonSets.showFreeSlots == 0 then
				BagnonSets.showFreeSlots = 1
				BagnonMsg(BAGNON_FREESLOTS_ENABLED)
			else
				BagnonSets.showFreeSlots = 0
				BagnonMsg(BAGNON_FREESLOTS_DISABLED)
			end
			BagnonOptions_RefreshHeader()
		elseif(cmd == BAGNON_COMMAND_ENCHANTS) then
			if BagnonSets.enchantBadges == 0 then
				BagnonSets.enchantBadges = 1
				BagnonMsg(BAGNON_ENCHANTS_ENABLED)
			else
				BagnonSets.enchantBadges = 0
				BagnonMsg(BAGNON_ENCHANTS_DISABLED)
			end
			BagnonOptions_RefreshItems()
		elseif(cmd == BAGNON_FOREVER_COMMAND_DELETE_CHARACTER) then
			if not argsBuffer[2] then
				BagnonMsg(BAGNON_FOREVER_HELP_DELETE_CHARACTER)
			else
				local realm = argsBuffer[3] and table.concat(argsBuffer, " ", 3) or GetRealmName()
				BagnonForever_RemovePlayer(argsBuffer[2], realm)
			end
		end
	end
end

SLASH_BagnonCOMMAND1 = "/bagnon";
SLASH_BagnonCOMMAND2 = "/bgn";
SLASH_BagnonCOMMAND3 = "/bo";
