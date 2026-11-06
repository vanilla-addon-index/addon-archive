-- TurtleHonorSpyEnhanced: slash command registration
-- All command logic lives in feature files; this file only routes.

SLASH_HONORSPY1 = "/hs"
SLASH_HONORSPY2 = "/honorspy"

SLASH_HSVER1 = "/hsver"

SlashCmdList["HONORSPY"] = function(msg)
	local cmd = string.lower(msg or "")

	if cmd == "overlay" then
		THSE:OverlayToggle()

	elseif cmd == "history" then
		THSE:HistoryOpen()

	elseif cmd == "version" or cmd == "ver" then
		local ver = GetAddOnMetadata("TurtleHonorSpyEnhanced", "Version") or "?"
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cffFFD100TurtleHonorSpyEnhanced|r v" .. ver .. " by Citrin (Tel'Abim)",
			1, 0.82, 0)

	elseif cmd == "minimap" then
		THSE:MinimapToggle()

	elseif cmd == "help" or cmd == "?" or cmd == "" then
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cffFFD100TurtleHonorSpyEnhanced|r commands:", 1, 0.82, 0)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  |cffffff00/hs overlay|r  — Toggle overlay", 1, 1, 1)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  |cffffff00/hs history|r  — Toggle honor history window", 1, 1, 1)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  |cffffff00/hs minimap|r  — Toggle minimap button", 1, 1, 1)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  |cffffff00/hs version|r  — Show addon version", 1, 1, 1)
	else
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cffFFD100TurtleHonorSpyEnhanced:|r Unknown command '" .. cmd ..
			"'. Try |cffffff00/hs help|r.", 1, 0.82, 0)
	end
end

-- /hsver — debug / diagnostics / version tools
SlashCmdList["HSVER"] = function(msg)
	local cmd = string.lower(msg or "")

	if cmd == "debug" then
		THSE:DebugLog()

	elseif cmd == "database" then
		THSE:DebugDatabase()

	elseif cmd == "version debug" then
		THSE:VersionToggleDebug()

	elseif cmd == "users req" then
		THSE:VersionSendRequest()

	elseif cmd == "users reset" then
		THSE:VersionResetUsers()

	elseif cmd == "users" then
		THSE:VersionListUsers()

	elseif cmd == "debug scoreboard" then
		local cache = THSE:HistoryGetBGScoreRank()
		if not cache then
			DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100THSE:|r BG score cache not available.", 1, 0.3, 0.3)
		else
			local count = 0
			for name, rank in pairs(cache) do
				DEFAULT_CHAT_FRAME:AddMessage("  " .. name .. " = " .. tostring(rank), 0.7, 0.7, 0.7)
				count = count + 1
			end
			DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100THSE:|r Scoreboard cache: " .. count .. " entries.", 1, 0.82, 0)
		end

	elseif cmd == "debug scoreboard raw" then
		if type(GetNumBattlefieldScores) ~= "function" then
			DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100THSE:|r GetNumBattlefieldScores not available.", 1, 0.3, 0.3)
		else
			if RequestBattlefieldScoreData then RequestBattlefieldScoreData() end
			local n = GetNumBattlefieldScores()
			DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100THSE:|r Raw BG scores (" .. n .. " entries):", 1, 0.82, 0)
			for i = 1, n do
				local r1, r2, r3, r4, r5, r6, r7, r8, r9, r10 = GetBattlefieldScore(i)
				DEFAULT_CHAT_FRAME:AddMessage(
					"  [" .. i .. "] " ..
					tostring(r1) .. " | " .. tostring(r2) .. " | " .. tostring(r3) .. " | " ..
					tostring(r4) .. " | " .. tostring(r5) .. " | " .. tostring(r6) .. " | " ..
					tostring(r7) .. " | " .. tostring(r8) .. " | " .. tostring(r9) .. " | " ..
					tostring(r10), 0.6, 0.8, 0.6)
			end
		end

	elseif cmd == "tick reset" then
		local hs = THSE.GetDB()
		if hs and hs.honorHistory then
			local removed = 0
			local i = 1
			while i <= table.getn(hs.honorHistory) do
				if hs.honorHistory[i].type == "tick" then
					table.remove(hs.honorHistory, i)
					removed = removed + 1
				else
					i = i + 1
				end
			end
			DEFAULT_CHAT_FRAME:AddMessage(
				"|cffFFD100THSE:|r Removed " .. removed .. " tick entries.", 1, 0.82, 0)
		else
			DEFAULT_CHAT_FRAME:AddMessage(
				"|cffFFD100THSE:|r No history to clean.", 1, 0.3, 0.3)
		end

	elseif cmd == "debug drift" then
		THSE:DebugDrift()

	else
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cffFFD100TurtleHonorSpyEnhanced:|r v" .. (THSE.version or "?"), 1, 0.82, 0)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  /hsver debug — full debug dump (copy window)", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  /hsver debug drift — honor drift analysis (copy window)", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  /hsver debug scoreboard — BG scoreboard cache", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  /hsver database — DB state summary (chat)", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  /hsver users [req|reset] — addon user tracking", 0.7, 0.7, 0.7)
		DEFAULT_CHAT_FRAME:AddMessage(
			"  /hsver version debug — toggle version comm debug", 0.7, 0.7, 0.7)
	end
end
