-- Debugger: a panel listing everything blocked this session, and a simulation that runs
-- dummy data through the addon's real code paths to check that everything still works

local SS = SI_Shared.SS
local T_Time = SI_Shared.T_Time
local MAX_ENTRIES = 500

-- Duration values (T_Time) and menu options by name
local TI_RELOG, TI_FOREVER = T_Time[1], T_Time[6]
local TI_LEGACY_AUTOBLOCK = 1e31 -- compatibility check for old saved filter entries
local OPT_HOUR, OPT_FOREVER = 2, 6

local entries = {}
local gui = nil
local messages = nil
local subtitle = nil

local m = {}

local formatEntry = function(e)
	local source = e.source and e.source ~= "" and ("[" .. e.source .. "] ") or ""
	return "|cff808080" .. e.time .. "|r  " .. source .. "|cffffd100" .. e.name .. "|r: " .. e.text
end

local isEnabled = function()
	return SI_Global.Mods[m.mod.Name].Enabled
end

m.refresh = function()
	subtitle:SetText(SS.LogTitle)
	messages:ClearLines()
	for i = 1, table.getn(entries) do
		messages:AddLine(formatEntry(entries[i]))
	end
	gui.empty = table.getn(entries) == 0 or nil
	if gui.empty then
		messages:AddLine(isEnabled() and SS.LogEmpty or "Enable Debugger to record blocked messages.", .5, .5, .5)
	end
end

m.onBlock = function(text, name, source)
	local e = { time = date("%H:%M"), name = name, source = source, text = text }
	table.insert(entries, e)
	if table.getn(entries) > MAX_ENTRIES then
		table.remove(entries, 1)
	end

	if gui and gui:IsShown() then
		if gui.empty then
			messages:ClearLines()
			gui.empty = nil
		end
		messages:AddLine(formatEntry(e))
	end
end

------------- Simulation

local G = getfenv(0)
local results, passed, failed

local check = function(label, ok, detail)
	if ok then
		passed = passed + 1
		table.insert(results, "|cff20ff20PASS|r " .. label)
	else
		failed = failed + 1
		table.insert(results, "|cffff2020FAIL|r " .. label .. (detail and (" |cff808080(" .. detail .. ")|r") or ""))
	end
end

local eq = function(label, got, want)
	check(label, got == want, "got " .. tostring(got) .. ", expected " .. tostring(want))
end

-- Replaces tbl[key] for the current section; restored afterwards, also after errors
local stubs = {}
local stub = function(tbl, key, value)
	table.insert(stubs, { tbl, key, tbl[key] })
	tbl[key] = value
end
local unstubAll = function()
	for i = table.getn(stubs), 1, -1 do
		local s = stubs[i]
		s[1][s[2]] = s[3]
	end
	stubs = {}
end

-- Counts calls by name: calls.CloseTrade == 1
local calls
local counter = function(key)
	return function()
		calls[key] = (calls[key] or 0) + 1
	end
end

-- One chat event through the same check every chat frame uses; true if hidden
local chat = function(event, msg, sender, channel)
	SI_ChatCacheReset()
	return SI_IsChatIgnored(event, msg, sender, nil, channel) and true or false
end

local lastPrinted = function(printed)
	return printed[table.getn(printed)] or ""
end

local ignore = function(name, duration, reason)
	SI_AddIgnore_New(name, true, duration or TI_FOREVER, reason)
end

local sections = {}

table.insert(sections, { "Spam list", function()
	SI_AddIgnore_New("Dummysoft", true, TI_FOREVER, "Summoning ads", true, OPT_FOREVER)
	local index = SI_BannedGetIndex("Dummysoft")
	check("Spam mode is saved", index and SI_BannedIsSoft(index))
	check("Spam entries are not name blocks", not SI_FilterIsPlayerIgnored("Dummysoft"))
	SI_Global.BanOptPublic = false
	check("Public ads are blocked even with public filtering off", chat("CHAT_MSG_CHANNEL", "Summoning 4g", "Dummysoft", "6. World"))
	local allowed = {"WHISPER", "PARTY", "RAID", "RAID_LEADER", "RAID_WARNING", "GUILD", "OFFICER", "SAY", "YELL", "EMOTE", "TEXT_EMOTE", "BATTLEGROUND"}
	for _, kind in pairs(allowed) do
		check("Spam mode allows " .. kind, not chat("CHAT_MSG_" .. kind, "hello", "Dummysoft"))
	end
	local sent
	stub(G, "SI_SendChatMessage_Old", function() sent = true end)
	SI_Global.WhisperBlock, SI_Global.WhisperUnignore = true, true
	SI_SendChatMessage_New("hello", "WHISPER", nil, "dummysoft")
	check("Outgoing whispers remain allowed", sent)
	check("Whispering retains the Spam entry", SI_BannedIsSoft(SI_BannedGetIndex("Dummysoft")))
	SI_BannedChangeMode("Dummysoft", false)
	check("Switching to Ignore enables name blocking", SI_FilterIsPlayerIgnored("Dummysoft"))
	SI_BannedChangeMode("Dummysoft", true)
	check("Switching back restores Spam mode", SI_BannedIsSoft(SI_BannedGetIndex("Dummysoft")))
	SI_BannedSetDuration(SI_BannedGetIndex("Dummysoft"), time() - 1)
	SI_BannedCheckTimes(true)
	check("Timed Spam entries expire", not SI_BannedGetIndex("Dummysoft"))
end })

table.insert(sections, { "Ignore list", function(printed)
	SI_Global.BanDuration = OPT_FOREVER
	SI_AddIgnore_New("dUMMYONE")
	eq("Names are stored capitalized", SI_GetIgnoreName_New(1), "Dummyone")
	eq("Ignore list has one entry", SI_GetNumIgnores_New(), 1)
	check("Ignoring prints a confirmation", string.find(lastPrinted(printed), "Dummyone", 1, true))
	check("Ignored player is recognized", SI_FilterIsPlayerIgnored("Dummyone"))
	SI_AddOrDelIgnore_New("dummyone", true)
	check("/ignore in another case toggles them off", not SI_BannedGetIndex("Dummyone"))

	SI_AddIgnore_New("Dummytwo", true, nil, "gold spam")
	local i = SI_BannedGetIndex("Dummytwo")
	eq("Reason is stored", i and SI_BannedGetReason(i), "gold spam")
	eq("GetIgnoreName stays plain for other addons", i and SI_GetIgnoreName_New(i), "Dummytwo")
	eq("Default duration option is remembered", i and SI_BannedGetOption(i), OPT_FOREVER)
	SI_BannedChangeReason("Dummytwo", "   ")
	check("A blank reason clears it", i and SI_BannedGetReason(i) == nil)

	SI_BannedChangeDuration("Dummytwo", OPT_HOUR)
	i = SI_BannedGetIndex("Dummytwo")
	local left = i and SI_BannedGetDuration(i) - time()
	check("Hour duration ends in an hour", left and left > 3500 and left <= 3600, tostring(left))
	eq("Changed duration option is remembered", i and SI_BannedGetOption(i), OPT_HOUR)
	SI_BannedSetDuration(i, time() + 90 * 60)
	eq("Time left rounds up to hours", SI_FormatTimeNoColor(SI_BannedGetDuration(i)), "2 Hours")
	SI_BannedSetDuration(i, time() + 10 * 60)
	eq("Time left under an hour shows minutes", SI_FormatTimeNoColor(SI_BannedGetDuration(i)), "10 Mins")
	eq("Forever shows as Forever", SI_FormatTimeNoColor(TI_FOREVER), SS.TimeForever)
	SI_AddIgnore_New("Dummytwo", true)
	i = SI_BannedGetIndex("Dummytwo")
	eq("Ignoring again resets to the default duration", i and SI_BannedGetOption(i), OPT_FOREVER)
	SI_AddIgnore_New("Dummytwo", true, TI_RELOG)
	i = SI_BannedGetIndex("Dummytwo")
	eq("A duration set directly has no menu option", i and SI_BannedGetOption(i), nil)
	SI_AddIgnore_New("Dummytwo", true, time() + 3600)
	i = SI_BannedGetIndex("Dummytwo")
	SI_BannedSetDuration(i, time() - 1)
	local expired = SI_BannedCheckTimes(true)
	check("Expired timed ignore is removed", table.getn(expired) == 1 and expired[1] == "Dummytwo"
		and not SI_BannedGetIndex("Dummytwo"))

	ignore("Dummyrelog", TI_RELOG)
	ignore("Dummyauto", TI_LEGACY_AUTOBLOCK, "test")
	ignore("Dummyforever")
	SI_BannedClearRelog()
	check("Until Relog and legacy Auto-Block entries clear at login",
		not SI_BannedGetIndex("Dummyrelog") and not SI_BannedGetIndex("Dummyauto"))
	check("Forever entry survives login", SI_BannedGetIndex("Dummyforever") ~= nil)

	ignore("Dummyzed")
	SI_SetSelectedIgnore_New(SI_BannedGetIndex("Dummyzed"))
	ignore("Dummyearly", TI_RELOG)
	check("List is sorted by duration", SI_BannedGetIndex("Dummyearly") < SI_BannedGetIndex("Dummyzed"))
	eq("Selection stays on the same player after sorting",
		SI_GetIgnoreName_New(SI_GetSelectedIgnore_New()), "Dummyzed")

	SI_AddIgnore_New(UnitName("player"), true)
	check("You can't ignore yourself", not SI_BannedGetIndex(UnitName("player")))
end })

table.insert(sections, { "Chat channels", function()
	ignore("Dummyspam")
	local o = SI_Global
	o.BanOptWhisper, o.BanOptSay, o.BanOptYell, o.BanOptBg, o.BanOptPublic, o.BanOptEmote = true, true, true, true, true, true
	o.BanOptParty, o.BanOptGuild, o.BanOptOfficer = false, false, false

	check("Whisper is hidden", chat("CHAT_MSG_WHISPER", "hi", "Dummyspam"))
	check("Say is hidden", chat("CHAT_MSG_SAY", "hi say", "Dummyspam"))
	check("Yell is hidden", chat("CHAT_MSG_YELL", "hi yell", "Dummyspam"))
	check("Emote is hidden", chat("CHAT_MSG_EMOTE", "waves", "Dummyspam"))
	check("Text emote is hidden", chat("CHAT_MSG_TEXT_EMOTE", "Dummyspam waves at you.", "Dummyspam"))
	check("Public channel is hidden", chat("CHAT_MSG_CHANNEL", "wts stuff", "Dummyspam", "2. Trade - City"))
	check("Battleground is hidden", chat("CHAT_MSG_BATTLEGROUND", "hi bg", "Dummyspam"))
	check("AFK auto-reply is hidden (Whispers)", chat("CHAT_MSG_AFK", "Away", "Dummyspam"))
	check("DND auto-reply is hidden (Whispers)", chat("CHAT_MSG_DND", "Busy", "Dummyspam"))
	check("Party shows while its option is off", not chat("CHAT_MSG_PARTY", "hi party", "Dummyspam"))
	check("Guild shows while its option is off", not chat("CHAT_MSG_GUILD", "hi guild", "Dummyspam"))
	o.BanOptParty = true
	check("Party is hidden once enabled", chat("CHAT_MSG_PARTY", "hi party", "Dummyspam"))
	check("Raid counts as party", chat("CHAT_MSG_RAID", "hi raid", "Dummyspam"))
	o.BanOptWhisper = false
	check("Whisper shows with Whispers off", not chat("CHAT_MSG_WHISPER", "hi again", "Dummyspam"))
	check("AFK reply shows with Whispers off", not chat("CHAT_MSG_AFK", "Away again", "Dummyspam"))
	o.BanOptWhisper = true

	check("Other players' messages show", not chat("CHAT_MSG_SAY", "hi", "Dummynice"))
	check("Your own messages always show", not chat("CHAT_MSG_SAY", "hi", UnitName("player")))
	check("'X is ignoring you' notice shows", not chat("CHAT_MSG_IGNORED", "", "Dummyspam"))

	check("Blocked messages are logged for the player", SI_LogHasName("Dummyspam"))
	local n = table.getn(SI_Log)
	chat("CHAT_MSG_WHISPER", "hi", "Dummyspam")
	eq("The same message is logged only once", table.getn(SI_Log), n)

	SI_ChatCacheReset()
	local first = SI_IsChatIgnored("CHAT_MSG_SAY", "cache test", "Dummyspam")
	o.BanOptSay = false
	local second = SI_IsChatIgnored("CHAT_MSG_SAY", "cache test", "Dummyspam")
	check("All chat frames get the same answer for one message", first and second)
end })

table.insert(sections, { "System messages", function()
	ignore("Dummyspam")
	local sys = function(msg) return chat("CHAT_MSG_SYSTEM", msg) end

	SI_Global.BanOptInvite = true
	check("Group invite notice from an ignored player is hidden", sys(string.format(ERR_INVITED_TO_GROUP_S, "Dummyspam")))
	check("Guild invite notice is hidden", sys(string.format(ERR_INVITED_TO_GUILD_SS, "Dummyspam", "Knights (EU)")))
	check("Invite notice from others shows", not sys(string.format(ERR_INVITED_TO_GROUP_S, "Dummynice")))
	SI_Global.BanOptInvite = false
	check("Invite notice shows with Invites off", not sys(string.format(ERR_INVITED_TO_GROUP_S, "Dummyspam")))
	check("Server's 'no longer ignored' notice is hidden", sys(string.format(ERR_IGNORE_REMOVED_S, "Dummynice")))
	check("Other system messages show", not sys("Dummy system message."))

	SI_SuppressCancelMessage()
	check("'Duel cancelled.' is hidden right after declining", sys(ERR_DUEL_CANCELLED))
	check("'Trade cancelled.' is hidden right after declining", sys(ERR_TRADE_CANCELLED))
	local shown = false
	stub(G, "SI_UIErrorsFrame_AddMessage_Old", function() shown = true end)
	SI_UIErrorsFrame_AddMessage_New(UIErrorsFrame, ERR_TRADE_CANCELLED)
	check("... and kept off the screen", not shown)
	SI_UIErrorsFrame_AddMessage_New(UIErrorsFrame, "Dummy error")
	check("Other on-screen errors still show", shown)

	local _, _, a, b = SI_StringFindPattern("Dummyspam invites you join Knights (EU).", "%s invites you join %s.")
	check("Formats with special characters match", a == "Dummyspam" and b == "Knights (EU)", tostring(a) .. ", " .. tostring(b))
	_, _, a, b = SI_StringFindPattern("Gilde <Foo-Bar>: Dummyspam", "Gilde %2$s: %1$s")
	check("Reordered (%1$s) formats match", a == "Dummyspam" and b == "<Foo-Bar>", tostring(a) .. ", " .. tostring(b))
	check("Messages with extra text don't match", SI_StringFindPattern("Dummyspam has invited you. Extra", "%s has invited you.") == nil)
end })

table.insert(sections, { "Your whispers", function(printed)
	ignore("Dummyspam")
	local sent
	stub(G, "SI_SendChatMessage_Old", function(msg, chatType, lang, target) sent = target or chatType end)

	SI_Global.WhisperBlock, SI_Global.WhisperUnignore = true, false
	sent = nil
	SI_SendChatMessage_New("hi", "WHISPER", nil, "dummyspam")
	check("Whisper to an ignored player is stopped", sent == nil)
	check("... with a message saying why", string.find(lastPrinted(printed), "Dummyspam", 1, true))

	SI_Global.WhisperBlock, SI_Global.WhisperUnignore = false, true
	sent = nil
	SI_SendChatMessage_New("hi", "WHISPER", nil, "dummyspam")
	eq("Whisper goes out as typed with 'Unignore if I whisper'", sent, "dummyspam")
	check("... and unignores them", not SI_BannedGetIndex("Dummyspam"))

	SI_Global.WhisperBlock = true
	ignore("Dummyauto", TI_LEGACY_AUTOBLOCK, "test")
	sent = nil
	SI_SendChatMessage_New("hi", "WHISPER", nil, "Dummyauto")
	eq("Legacy Auto-Block entries do not stop whispers", sent, "Dummyauto")
	sent = nil
	SI_SendChatMessage_New("hi", "SAY")
	eq("Say is never stopped", sent, "SAY")
end })

table.insert(sections, { "Block listeners", function()
	local told
	table.insert(SI_BlockListeners, function(text, name) told = name end)
	ignore("Dummyspam")
	chat("CHAT_MSG_SAY", "listener test", "Dummyspam")
	eq("Debugger listeners are told about blocks", told, "Dummyspam")
end })

table.insert(sections, { "Invites and duels", function()
	ignore("Dummyspam")
	calls = {}
	stub(G, "DeclineGroup", counter("DeclineGroup"))
	stub(G, "DeclineGuild", counter("DeclineGuild"))
	stub(G, "CancelDuel", counter("CancelDuel"))
	stub(G, "SI_StaticPopup_Show_Old", counter("popup"))
	SI_Global.BanOptInvite, SI_Global.BanOptDuel = true, true

	SI_StaticPopup_Show_New("PARTY_INVITE", "Dummyspam")
	check("Group invite from an ignored player is declined", calls.DeclineGroup == 1 and not calls.popup)
	SI_StaticPopup_Show_New("GUILD_INVITE", "Dummyspam", "Knights")
	check("Guild invite is declined", calls.DeclineGuild == 1 and not calls.popup)
	SI_StaticPopup_Show_New("DUEL_REQUESTED", "Dummyspam")
	check("Duel is cancelled", calls.CancelDuel == 1 and not calls.popup)
	check("... and 'Duel cancelled.' is suppressed", SI_IsCancelMessage(ERR_DUEL_CANCELLED))
	check("Declined invites are logged", SI_LogHasName("Dummyspam"))

	SI_StaticPopup_Show_New("PARTY_INVITE", "Dummynice")
	eq("Invite from others shows the popup", calls.popup, 1)
	SI_Global.BanOptInvite, SI_Global.BanOptDuel = false, false
	SI_StaticPopup_Show_New("PARTY_INVITE", "Dummyspam")
	SI_StaticPopup_Show_New("DUEL_REQUESTED", "Dummyspam")
	check("With Invites and Duels off the popups show", calls.popup == 3 and calls.DeclineGroup == 1 and calls.CancelDuel == 1)
end })

table.insert(sections, { "Trades", function()
	ignore("Dummyspam")
	calls = {}
	local npc = "Dummyspam"
	local realUnitName, realUnitIsPlayer = UnitName, UnitIsPlayer
	stub(G, "UnitName", function(unit)
		if unit == "NPC" or unit == "dummyunit" then return npc end
		return realUnitName(unit)
	end)
	stub(G, "UnitIsPlayer", function(unit)
		if unit == "dummyunit" then return 1 end
		return realUnitIsPlayer(unit)
	end)
	stub(G, "CloseTrade", counter("CloseTrade"))
	stub(G, "SI_TradeFrame_OnEvent_Old", counter("frame"))
	stub(G, "SI_InitiateTrade_Old", counter("initiate"))
	stub(G, "event", nil)
	local trade = function(ev)
		G.event = ev
		SI_TradeFrame_OnEvent_New()
	end
	SI_Global.BanOptTrade = true

	trade("TRADE_SHOW")
	eq("Trade from an ignored player is closed", calls.CloseTrade, 1)
	trade("TRADE_CLOSED")
	SI_InitiateTrade_New("dummyunit")
	eq("Trades you start go to the game", calls.initiate, 1)
	trade("TRADE_SHOW")
	trade("TRADE_UPDATE")
	eq("A trade you started with them stays open", calls.CloseTrade, 1)
	trade("TRADE_CLOSED")
	trade("TRADE_SHOW")
	eq("Their next trade is closed again", calls.CloseTrade, 2)
	check("... and 'Trade cancelled.' is suppressed", SI_IsCancelMessage(ERR_TRADE_CANCELLED))
	trade("TRADE_CLOSED")
	SI_Global.BanOptTrade = false
	trade("TRADE_SHOW")
	eq("With Trades off the trade stays open", calls.CloseTrade, 2)
	trade("TRADE_CLOSED")
	SI_Global.BanOptTrade = true
	npc = "Dummynice"
	trade("TRADE_SHOW")
	eq("Trades from others stay open", calls.CloseTrade, 2)
end })

table.insert(sections, { "Settings", function()
	SI_Global = { WhisperUnignore = true, BanOptSay = true, BanDuration = 3 }
	SI_LoadSettings()
	eq("Old settings: unchecked options stay off", SI_Global.BanOptYell, false)
	eq("Old settings: chosen duration is kept", SI_Global.BanDuration, 3)
	eq("Old settings: migrated once", SI_Global.SettingsVersion, 1)
	eq("Old settings get the new group warning default", SI_Global.WarnIgnoredPlayers, true)
	SI_Global.WarnIgnoredPlayers = false
	SI_LoadSettings()
	eq("Disabled group warnings stay disabled", SI_Global.WarnIgnoredPlayers, false)
	SI_Global.BanOptDuel = nil
	SI_LoadSettings()
	eq("New options get their default", SI_Global.BanOptDuel, true)
	SI_Global = nil
	SI_LoadSettings()
	eq("A fresh install gets the defaults", SI_Global.BanOptWhisper, true)
	eq("A fresh install enables group warnings", SI_Global.WarnIgnoredPlayers, true)
	SI_Global = { SettingsVersion = 1, WarnIgnoredGroup = false, WarnIgnoredMenu = true }
	SI_LoadSettings()
	eq("Combined warnings preserve the original disabled preference", SI_Global.WarnIgnoredPlayers, false)
	check("Separate warning settings are retired", SI_Global.WarnIgnoredGroup == nil and SI_Global.WarnIgnoredMenu == nil)
end })

table.insert(sections, { "Debugger", function()
	table.insert(SI_BlockListeners, m.onBlock)
	ignore("Dummyspam")
	local n = table.getn(entries)
	chat("CHAT_MSG_WHISPER", "debugger test", "Dummyspam")
	eq("Debugger records blocked messages", table.getn(entries), n + 1)
	local e = entries[table.getn(entries)]
	check("... with player and source", e and e.name == "Dummyspam" and e.source == "W")
end })

table.insert(sections, { "Group warnings", function(printed)
	local realUnitName = UnitName
	local party, raid = {}, {}
	stub(G, "GetNumPartyMembers", function() return table.getn(party) end)
	stub(G, "GetNumRaidMembers", function() return table.getn(raid) end)
	stub(G, "UnitName", function(unit)
		local _, _, i = string.find(unit, "^party(%d+)$")
		if i then return party[tonumber(i)] end
		_, _, i = string.find(unit, "^raid(%d+)$")
		if i then return raid[tonumber(i)] end
		return realUnitName(unit)
	end)
	SI_Global.WarnIgnoredPlayers = true
	ignore("Dummyignored", TI_FOREVER, "Left the dungeon early")
	SI_AddIgnore_New("Dummyads", true, TI_FOREVER, "Summoning ads", true)
	ignore("Dummyexpired", time() - 1)
	ignore("Dummyauto", TI_LEGACY_AUTOBLOCK)
	party = {"Dummyignored", "Dummynice", "Dummyads", "Dummyexpired"}
	SI_CheckIgnoredGroup()
	eq("Only active full ignores trigger a warning", table.getn(printed), 1)
	check("Warning includes name and saved reason", string.find(lastPrinted(printed), "Dummyignored", 1, true)
		and string.find(lastPrinted(printed), "Left the dungeon early", 1, true))
	check("Warning is yellow", string.find(lastPrinted(printed), "|cffffff00", 1, true))
	check("Warning name is a player link", string.find(lastPrinted(printed), "|Hplayer:Dummyignored|h[Dummyignored]|h", 1, true))
	check("Party warning says party", string.find(lastPrinted(printed), "in your party", 1, true))
	SI_CheckIgnoredGroup()
	eq("Repeated roster events do not repeat warnings", table.getn(printed), 1)
	party = {"Dummynice", "Dummyignored"}
	SI_CheckIgnoredGroup()
	eq("Reordering members does not repeat warnings", table.getn(printed), 1)
	raid = {UnitName("player"), "Dummyignored", "Dummynice", "Dummyauto"}
	SI_CheckIgnoredGroup()
	eq("Raid conversion and legacy auto-block do not warn", table.getn(printed), 1)
	ignore("Dummyraid")
	table.insert(raid, "Dummyraid")
	SI_CheckIgnoredGroup()
	eq("New ignored raid member triggers a warning", table.getn(printed), 2)
	check("Raid warning says raid", string.find(lastPrinted(printed), "in your raid", 1, true))
	check("Warning works without a reason", not string.find(lastPrinted(printed), "Reason:", 1, true))
	party, raid = {}, {}
	SI_CheckIgnoredGroup()
	party = {"Dummyignored"}
	SI_CheckIgnoredGroup()
	eq("Joining a new group warns again", table.getn(printed), 3)
	party = {}
	SI_CheckIgnoredGroup()
	SI_Global.WarnIgnoredPlayers = false
	party = {"Dummyignored"}
	SI_CheckIgnoredGroup()
	eq("Disabled option suppresses warnings", table.getn(printed), 3)
	SI_Global.WarnIgnoredPlayers = true
	SI_CheckIgnoredGroup()
	eq("Enabling the option does not repeat existing members", table.getn(printed), 3)
	party = {"Dummyignored", UNKNOWN or "Unknown"}
	stub(G, "UNKNOWN", "Unknown")
	SI_CheckIgnoredGroup()
	party = {"Unknown", "Dummyignored"}
	SI_CheckIgnoredGroup()
	party = {"Dummyraid", "Dummyignored"}
	SI_CheckIgnoredGroup()
	eq("Delayed names warn once without repeating known members", table.getn(printed), 4)
end })

table.insert(sections, { "Player menu warnings", function(printed)
	ignore("Dummymenu", TI_FOREVER, "Left the dungeon early")
	SI_AddIgnore_New("Dummyads", true, TI_FOREVER, nil, true)
	ignore("Dummyexpired", time() - 1)
	ignore("Dummyauto", TI_LEGACY_AUTOBLOCK)
	SI_Global.WarnIgnoredPlayers = true
	stub(G, "UIDROPDOWNMENU_MENU_LEVEL", 1)
	local originalCalls = 0
	local menu, data = {}, {}
	stub(G, "SI_UnitPopup_ShowMenu_Old", function(dropdown, which, unit, name, userData)
		originalCalls = originalCalls + 1
		check("Player menu arguments are preserved", dropdown == menu and which == "FRIEND"
			and not unit and name == "dummymenu" and userData == data)
		eq("Warning appears before the menu opens", table.getn(printed), 1)
		return "menu-result"
	end)
	local result = UnitPopup_ShowMenu(menu, "FRIEND", nil, "dummymenu", data)
	eq("Original player menu still opens", originalCalls, 1)
	eq("Original menu return value is preserved", result, "menu-result")
	check("Menu warning includes linked name and reason", string.find(lastPrinted(printed), "|Hplayer:Dummymenu|h[Dummymenu]|h", 1, true)
		and string.find(lastPrinted(printed), "Left the dungeon early", 1, true))
	check("Chat name menu warning does not claim group membership", not string.find(lastPrinted(printed), "in your", 1, true))
	stub(G, "SI_UnitPopup_ShowMenu_Old", function() end)
	stub(G, "UnitIsPlayer", function(unit) return unit == "target" end)
	local realUnitName = UnitName
	stub(G, "UnitName", function(unit)
		if unit == "target" then return "Dummymenu" end
		return realUnitName(unit)
	end)
	UnitPopup_ShowMenu(menu, "PLAYER", "target")
	eq("Unit menus resolve the player name", table.getn(printed), 2)
	UIDROPDOWNMENU_MENU_LEVEL = 2
	UnitPopup_ShowMenu(menu, "PLAYER", "target")
	eq("Submenus do not repeat warnings", table.getn(printed), 2)
	UIDROPDOWNMENU_MENU_LEVEL = 1
	UnitPopup_ShowMenu(menu, "PLAYER", "npc", "Dummymenu")
	UnitPopup_ShowMenu(menu, "FRIEND", nil, "Dummyads")
	UnitPopup_ShowMenu(menu, "FRIEND", nil, "Dummyexpired")
	UnitPopup_ShowMenu(menu, "FRIEND", nil, "Dummyauto")
	UnitPopup_ShowMenu(menu, "FRIEND", nil, "Dummynice")
	UnitPopup_ShowMenu(menu, "SELF", "player", UnitName("player"))
	eq("NPCs, Spam, expired, auto-block and unignored players do not warn", table.getn(printed), 2)
	SI_Global.WarnIgnoredPlayers = false
	UnitPopup_ShowMenu(menu, "PLAYER", "target")
	eq("The shared warning option disables menu warnings", table.getn(printed), 2)
end })

local runSection = function(title, fn)
	table.insert(results, "|cffffd100" .. title .. "|r")
	local ok, err = SI_Sandbox(fn)
	unstubAll()
	if not ok then
		check("Section finished without errors", false, tostring(err))
	end
end

m.simulate = function()
	results, passed, failed = {}, 0, 0
	-- Keep the simulation's blocks out of the real list
	local realEntries = entries
	entries = {}

	for i = 1, table.getn(sections) do
		runSection(sections[i][1], sections[i][2])
	end

	entries = realEntries

	subtitle:SetText("Simulation results")
	messages:ClearLines()
	gui.empty = nil
	for i = 1, table.getn(results) do
		messages:AddLine(results[i])
	end
	local color = failed == 0 and "|cff20ff20" or "|cffff2020"
	messages:AddLine(color .. "Simulation: " .. passed .. " passed, " .. failed .. " failed|r")
end

------------- Panel

m.createUI = function(frame)
	gui = SI_FrameCreateFrame("SI_Debugger", 300, frame, -10, 0)
	gui:SetHeight(300)

	SI_FrameCreateHeader(gui, m.mod.Name, 12, -15)
	subtitle = gui:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	subtitle:SetPoint("TOP", gui, "TOP", 0, -32)
	subtitle:SetText(SS.LogTitle)

	messages = SI_FrameCreateLog("SI_DebuggerMessages", gui, 40, MAX_ENTRIES)

	local simulate = SI_FrameCreateButton("SI_DebuggerSimulate", gui, "Simulate", 85, "BOTTOMLEFT", 15, 14, m.simulate)
	simulate:SetScript("OnEnter", function()
		GameTooltip:SetOwner(simulate, "ANCHOR_RIGHT")
		GameTooltip:SetText("Simulate")
		GameTooltip:AddLine("Runs dummy players, messages, invites, duels, trades and player warnings through the addon and checks every result. Your ignore list, settings and logs are not touched.", 1, 1, 1, 1)
		GameTooltip:Show()
	end)
	simulate:SetScript("OnLeave", function() GameTooltip:Hide() end)

	SI_FrameCreateButton("SI_DebuggerCopy", gui, "Copy", 85, "BOTTOM", 0, 14, function()
		SI_ShowCopyText(m.mod.Name .. " - " .. subtitle:GetText(), messages:GetAllText())
	end)
	SI_FrameCreateButton("SI_DebuggerLog", gui, "Show Log", 85, "BOTTOMRIGHT", -15, 14, m.refresh)

	gui:SetScript("OnShow", m.refresh)
end

m.toggle = function()
	SI_ToggleModPanel(gui)
end

m.mod = {
	["Name"] = "Debugger",
	["Description"] = "Lists everything blocked this session, and can simulate blocks to check that everything works.",
	["Help"] = "Click 'View' to open the list: time, where it was blocked (W = whisper, S = say, Y = yell, P = party, a number = that chat channel), the player and their message. Trades, duels and invites are listed too. Only records while enabled; each player's own log is always available via the icon on their ignore list row. 'Simulate' runs dummy data through the addon and lists every check as PASS or FAIL.",
	["CreateUI"] = m.createUI,
	["OnEdit"] = m.toggle,
	["EditText"] = "View",
	["OnBlock"] = m.onBlock,
}

local f = CreateFrame("frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	SI_ModInstall(m.mod)
end)
