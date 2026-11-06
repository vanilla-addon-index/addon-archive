AutoReputationBar = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0")

function AutoReputationBar:OnInitialize() 
	AutoReputationBar.gains = {}
end

function AutoReputationBar:OnEnable()
	self:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
end

SLASH_REP1 = "/rep"
SlashCmdList["REP"] = function(command)
	AutoReputationBar:Debug()
end

function AutoReputationBar:CHAT_MSG_COMBAT_FACTION_CHANGE(text, player, lang, channel, player2, special, zonechanid, chindex, chbasename) 

	local startpos, endpos, faction, change = string.find(text, "Your (.*) reputation has increased by ([0-9]*)");
--	DEFAULT_CHAT_FRAME:AddMessage("faction is "..(faction or "nil") ..", change is ".. (change or "nil"))
	if faction and change then
		if not AutoReputationBar.gains[faction] then
			AutoReputationBar.gains[faction] = change
		else
			AutoReputationBar.gains[faction] = AutoReputationBar.gains[faction] + change
		end
		local name = GetWatchedFactionInfo()
		if name ~= nil and name ~= faction then	-- if nothing shown then leave bar alone
			local n = GetNumFactions()
			for i=1, n do
				local fname = GetFactionInfo(i)
				if fname == faction then
		--			DEFAULT_CHAT_FRAME:AddMessage("compare "..fname.." to "..faction..", isHeader="..
		--				(isHeader and "true" or "false")..", watched="..(iswatched and "true" or "false"))
					DEFAULT_CHAT_FRAME:AddMessage("Switching to "..fname)
					SetWatchedFactionIndex(i)
				end
			end
		end
	end

--	DEFAULT_CHAT_FRAME:AddMessage("faction: text= "..text..", player="..player..", lang="..lang..", channel="..channel
--	..", player2="..player2..", special="..special..", zonechan"..zonechanid..", chindex="..chindex..", chbasename= "..chbasename)
end

function AutoReputationBar:Debug()
    local n = GetNumFactions()
    local name,standing,min,max,value,id = GetWatchedFactionInfo()
	if name == nil then
		DEFAULT_CHAT_FRAME:AddMessage("Not watching any reputation")
	else
		DEFAULT_CHAT_FRAME:AddMessage("Watching "..name)
	end
--  for i=1, n do
--		local fname, fdesc, _, _, _, _, _, canToggle, isHeader, _, _, iswatched,
--			 _, fid = GetFactionInfo(i)
--		if not isHeader then
--			DEFAULT_CHAT_FRAME:AddMessage(fname .. (iswatched and "(watched)" or ""))
--		end
--	end

	for key,value in pairs(AutoReputationBar.gains) do 
		DEFAULT_CHAT_FRAME:AddMessage("Gained "..value.." rep with "..key.." this session")
	end
end
