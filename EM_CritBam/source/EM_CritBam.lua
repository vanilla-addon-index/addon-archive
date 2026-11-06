-- should be in a lib
print_func = function (addonName)
	return function (msg)
		if (msg == nil) then
			return;
		end
		DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8080" .. addonName .. ":|r " .. msg);
	end
end

function AddSlashCommand (name, func, cmd)
	_G = getfenv();
	SlashCmdList[name]	= func;
	local command		= cmd;	
	if strsub(command, 1, 1) ~= '/' then
		command = '/' .. command;
	end
	_G["SLASH_" .. name .. "1"] = command;
end



-- addon structure
local EM_CritBam = {};

EM_CritBam.version		= "0.1";
EM_CritBam.print		= print_func("EM_CritBam");
EM_CritBam.frame		= CreateFrame("Frame", nil);
EM_CritBam.events		= 
{
	"COMBAT_TEXT_UPDATE",
	"CHAT_MSG_SPELL_SELF_DAMAGE",
	"CHAT_MSG_COMBAT_SELF_HITS",
}
EM_CritBam.dmgSpell		= "Your (.+) crits (.+) for (%d+)";
EM_CritBam.dmgWeapon	= "You crit (.+) for (%d+)";

-- addon funcs
function EM_CritBam.PlaySound()
	PlaySoundFile("Interface\\AddOns\\EM_CritBam\\bam.ogg");
end



-- Events
local function Startup()

	AddSlashCommand("EMCRITBAM_SLASHCMD",
		function()
			EM_CritBam.print("EM_CritBam loaded");
		end,
	"emcritbam")

	for _, event in pairs(EM_CritBam.events) do
		EM_CritBam.frame:RegisterEvent(event)
	end
	
	EM_CritBam.frame:SetScript("OnEvent", OnEvent);
	
	EM_CritBam.print("EM_CritBam version " .. EM_CritBam.version .. " loaded!");
	
end



function OnEvent(self, event, ...)
	
	if (event == "COMBAT_TEXT_UPDATE") then
		if (arg1 == "HEAL_CRIT") then
			EM_CritBam.PlaySound();
			EM_CritBam.print("HEAL CRIT from " .. arg2 .. " for " .. arg3 ..  "!");
		end
	else
		for spell, mob, damage in string.gfind(arg1, EM_CritBam.dmgSpell) do
			EM_CritBam.PlaySound();
			EM_CritBam.print("DMG CRIT with " .. spell .. " for " .. damage..  "!");
		end		
		for mob, damage in string.gfind(arg1, EM_CritBam.dmgWeapon) do
			EM_CritBam.PlaySound();
			EM_CritBam.print("DMG CRIT for " .. damage .. "!");
		end
	end

end



-- Start
Startup();
