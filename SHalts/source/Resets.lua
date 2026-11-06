-------------------------------------------------------------------------------
-- IRC: instance reset counter and raid lockouts.
--
-- The server allows 5 instance resets per hour. Each character keeps its own
-- list of up to 5 timers that count down from one hour. A timer starts only when
-- the game confirms a reset, so a reset that fails (someone is still inside)
-- starts nothing. Timers are stored as clock times, so they stay right through
-- logging out. Coin looted inside an instance is added to the newest timer.
--
-- Raid lockouts are read from the game's saved-instance list and kept per
-- character, so you can see which of your characters are locked.
-------------------------------------------------------------------------------
local S = SHAlts

S.Try("Resets.lua", function()

local RESET_DURATION = 3600    -- one hour, in seconds
local MAX_RESETS = 5           -- the server allows 5 per hour
local COALESCE = 8             -- reset messages this close together are one reset action
S.RESET_DURATION = RESET_DURATION
S.MAX_RESETS = MAX_RESETS

local GOLD_W = GOLD or "Gold"
local SILVER_W = SILVER or "Silver"
local COPPER_W = COPPER or "Copper"

local lastActive            -- active timers last time we looked, for the alerts

function S.IRCPrint(text)
	if text and text ~= "" then DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffIRC:|r " .. text) end
end

-------------------------------------------------------------------------------
-- Formatting
-------------------------------------------------------------------------------
function S.FormatClock(sec)
	if sec < 0 then sec = 0 end
	return string.format("%02d:%02d", math.floor(sec / 60), math.floor(math.mod(sec, 60)))
end

-- copper -> "Xg YYs ZZc", coloured
function S.MoneyGSC(c)
	c = c or 0
	return string.format("|cffffd700%dg|r |cffc7c7cf%02ds|r |cffeda55f%02dc|r",
		math.floor(c / 10000), math.floor(math.mod(c, 10000) / 100), math.mod(c, 100))
end

local function ParseMoney(msg)
	local _, _, g = string.find(msg, "(%d+) " .. GOLD_W)
	local _, _, s = string.find(msg, "(%d+) " .. SILVER_W)
	local _, _, c = string.find(msg, "(%d+) " .. COPPER_W)
	return (tonumber(g) or 0) * 10000 + (tonumber(s) or 0) * 100 + (tonumber(c) or 0)
end

-------------------------------------------------------------------------------
-- Timers
-------------------------------------------------------------------------------
-- a character's active timers, oldest first (reads only, changes nothing)
function S.ResetView(c)
	local out = {}
	local now = time()
	local src = (c and c.resets) or {}
	for i = 1, table.getn(src) do
		local e = src[i]
		if e and e.t and now - e.t < RESET_DURATION then table.insert(out, e) end
	end
	table.sort(out, function(a, b) return a.t < b.t end)
	while table.getn(out) > MAX_RESETS do table.remove(out, 1) end
	return out
end

-- drop expired timers from the character being played
local function Prune()
	local c = S.GetChar()
	c.resets = S.ResetView(c)
	return c.resets
end

-- One reset action can reset several dungeons or raids at once, and the game then
-- sends one message per instance. Messages that arrive within COALESCE seconds of the
-- newest timer belong to that same action, so they start no new timer; the extra
-- dungeon names are just added to its label.
-- Returns: isNewTimer, isNewDungeon
local function AddReset(name)
	local c = S.GetChar()
	Prune()
	local now = time()
	local newest = c.resets[table.getn(c.resets)]
	if newest and (now - newest.t) < COALESCE then
		if not name then return false, false end
		local have = newest.name
		if have == name or (have and string.find(", " .. have .. ", ", ", " .. name .. ", ", 1, true)) then
			return false, false
		end
		if have then newest.name = have .. ", " .. name else newest.name = name end
		S.DataChanged()
		return false, true
	end
	table.insert(c.resets, { t = now, name = name, coin = 0 })
	Prune()
	S.DataChanged()
	return true, true
end

-------------------------------------------------------------------------------
-- Alerts (sound and a flash on the minimap button)
-------------------------------------------------------------------------------
local SOUND_FREE = "TellMessage"
local SOUND_CAP = "igQuestFailed"

local function PlayAlert(kind)
	if kind == "cap" then pcall(PlaySound, SOUND_CAP) else pcall(PlaySound, SOUND_FREE) end
	if S.FlashMinimapButton then S.FlashMinimapButton() end
end

local function Alert(kind)
	if not S.db.resetAlerts then return end
	PlayAlert(kind)
	if kind == "free" then
		S.IRCPrint("|cff88ff88A reset slot is now free.|r")
	elseif kind == "cap" then
		S.IRCPrint("|cffffcc00Reset cap reached (" .. MAX_RESETS .. "/" .. MAX_RESETS .. ").|r")
	end
end

-- tell the group, when you lead it
local function Announce(name)
	if not S.db.resetAnnounce then return end
	local channel
	if GetNumRaidMembers() > 0 then
		if IsRaidLeader() or IsRaidOfficer() then channel = "RAID" end
	elseif GetNumPartyMembers() > 0 then
		if IsPartyLeader() then channel = "PARTY" end
	end
	if channel then SendChatMessage((name or "Instance") .. " was reset.", channel) end
end

-------------------------------------------------------------------------------
-- Actions (the character being played)
-------------------------------------------------------------------------------
function S.DoDungeonReset()
	local list = Prune()
	local count = table.getn(list)
	ResetInstances()
	if count >= MAX_RESETS then
		local nextFree = RESET_DURATION - (time() - list[1].t)
		S.IRCPrint("|cffff5555At " .. MAX_RESETS .. "/" .. MAX_RESETS .. ".|r Next: " .. S.FormatClock(nextFree))
	else
		S.IRCPrint("|cffcccc88Reset sent, waiting for the game to confirm...|r")
	end
	S.UIChanged()
end

function S.ResetAllTimers()
	local c = S.GetChar()
	c.resets = {}
	lastActive = 0
	S.IRCPrint("|cffcccc88All timers cleared.|r")
	S.DataChanged()
end

-------------------------------------------------------------------------------
-- Game messages
-------------------------------------------------------------------------------
-- The game's own wording for "X has been reset." is used when this client has it,
-- so a server that words it differently still matches. The plain text is the fallback.
local function GlobalPattern(fmt)
	if type(fmt) ~= "string" then return nil end
	local p = string.gsub(fmt, "([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
	p = string.gsub(p, "%%s", "(.+)")
	return "^" .. p
end
local RESET_OK = GlobalPattern(INSTANCE_RESET_SUCCESS)

-- When a reset is asked for (our button or the game's own menu), the next few
-- seconds of game messages are watched. If the game confirms it in words we did
-- not expect, it still counts. If nothing is recognised, chat shows what the
-- game said, so the wording can be added.
local WINDOW = 4
local awaitUntil = 0
local reqCounted, reqFailed = false, false
local heard = {}

if type(ResetInstances) == "function" then
	local origReset = ResetInstances
	ResetInstances = function()
		awaitUntil = GetTime() + WINDOW
		reqCounted, reqFailed = false, false
		heard = {}
		origReset()
	end
end

local function HandleReset(name, by)
	local isNew, nameAdded = AddReset(name)
	-- only the player who did the reset tells the group about it
	if nameAdded and not by then Announce(name) end
	reqCounted = true
	if isNew then
		S.IRCPrint("|cff88ff88" .. (name or "Instance") .. " reset" .. (by and (" by " .. by) or "") ..
			" (" .. table.getn(S.GetChar().resets) .. "/" .. MAX_RESETS .. ")|r")
	elseif nameAdded then
		S.IRCPrint("|cff88ff88" .. (name or "Instance") .. " reset too (same reset, no new timer)|r")
	end
end

local function IsFailure(msg)
	return string.find(msg, "still inside") or string.find(msg, "currently in that instance")
		or string.find(msg, "Cannot reset") or string.find(msg, "cannot be reset")
end

-- "Blackrock Depths has been reset." (you reset it, dungeon or raid)
-- "Blackrock Depths has been reset by Fayz" (some clients show it this way)
-- Either way the instance reset counts against you, so both start a timer.
local function OnResetMessage(msg)
	if not msg or not S.db or not S.ready then return end
	local waiting = GetTime() < awaitUntil
	local name
	if RESET_OK then
		local _, _, n1 = string.find(msg, RESET_OK)
		name = n1
	end
	local matched = name ~= nil
	if not matched and string.find(msg, "has been reset") then
		matched = true
		local _, _, n2 = string.find(msg, "^(.-) has been reset")
		name = n2
	end
	if matched then
		if name == "" then name = nil end
		local _, _, by = string.find(msg, "has been reset by ([^%s%.,!]+)")
		if by == UnitName("player") then by = nil end
		HandleReset(name, by)
	elseif IsFailure(msg) then
		reqFailed = true
		S.IRCPrint("|cffff5555Reset failed:|r " .. msg)
	elseif waiting then
		local low = string.lower(msg)
		if string.find(low, "reset") then
			-- confirmed in words we did not expect, right after a reset was asked for
			table.insert(heard, msg)
			HandleReset(nil, nil)
		elseif string.find(low, "instance") then
			table.insert(heard, msg)
		end
	end
end

S.On("CHAT_MSG_SYSTEM", OnResetMessage)
S.On("UI_INFO_MESSAGE", OnResetMessage)   -- in case this client sends it that way
S.On("UI_ERROR_MESSAGE", OnResetMessage)  -- some failures come this way

-- called once a second: if a reset was asked for and nothing was counted, say what the game said
local function CheckRequest()
	if awaitUntil > 0 and GetTime() >= awaitUntil then
		awaitUntil = 0
		if not reqCounted and not reqFailed then
			if table.getn(heard) > 0 then
				S.IRCPrint("|cffcccc88Reset sent, nothing counted. The game said:|r " .. table.concat(heard, " | "))
			else
				S.IRCPrint("|cffcccc88Reset sent, but the game did not say an instance was reset, so no timer was started.|r")
			end
		end
	end
end

-- Diagnostic for finding out how a message reaches the client: /shalts resetdebug
-- echoes every game message that mentions a reset, with the event it came from.
local dbgFrame
function S.ToggleResetDebug()
	if not dbgFrame then
		dbgFrame = CreateFrame("Frame")
		dbgFrame.on = false
		local events = { "CHAT_MSG_SYSTEM", "UI_INFO_MESSAGE", "UI_ERROR_MESSAGE", "CHAT_MSG_RAID_WARNING",
			"CHAT_MSG_RAID_BOSS_EMOTE", "CHAT_MSG_MONSTER_EMOTE", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_CHANNEL_NOTICE" }
		for i = 1, table.getn(events) do
			local e = events[i]
			pcall(function() dbgFrame:RegisterEvent(e) end)
		end
		dbgFrame:SetScript("OnEvent", function()
			if dbgFrame.on and arg1 and (string.find(string.lower(arg1), "reset") or string.find(string.lower(arg1), "instance")) then
				S.Print("|cffff9900reset message|r [" .. tostring(event) .. "] " .. arg1)
				if S.db then S.db.lastResetDebug = tostring(event) .. " | " .. arg1 end
			end
		end)
	end
	dbgFrame.on = not dbgFrame.on
	S.Print("reset message echo " .. (dbgFrame.on and "on: reset something and look for the lines" or "off"))
end

-- coin looted counts toward the newest timer
S.On("CHAT_MSG_MONEY", function(msg)
	if not msg or not S.db or not S.ready then return end
	local amt = ParseMoney(msg)
	if amt <= 0 then return end
	-- where the client can tell, only count coin looted inside an instance
	if type(IsInInstance) == "function" and not IsInInstance() then return end
	local list = Prune()
	local n = table.getn(list)
	if n == 0 then return end
	list[n].coin = (list[n].coin or 0) + amt
	S.DataChanged()
end)

S.On("PLAYER_ENTERING_WORLD", function()
	if not S.db or not S.ready then return end
	lastActive = table.getn(Prune())   -- no alert for timers that ran out while offline
end)

-------------------------------------------------------------------------------
-- Raid lockouts
-------------------------------------------------------------------------------
-- a character's lockouts that are still running, soonest to reset first
function S.LockView(c)
	local out = {}
	local now = time()
	local src = (c and c.locks) or {}
	for i = 1, table.getn(src) do
		local l = src[i]
		if l and l.e and l.e > now then table.insert(out, l) end
	end
	table.sort(out, function(a, b) return a.e < b.e end)
	return out
end

function S.ScanLocks()
	if not GetNumSavedInstances or not GetSavedInstanceInfo then return end
	local c = S.GetChar()
	local list = {}
	for i = 1, (GetNumSavedInstances() or 0) do
		local name, id, left = GetSavedInstanceInfo(i)
		if name and tonumber(left) then
			table.insert(list, { n = name, id = tonumber(id) or 0, e = time() + math.floor(left) })
		end
	end
	c.locks = list
	c.locksSeen = time()
	S.DataChanged()
end

-- the game answers a request with this event, so the list is only read then
S.On("UPDATE_INSTANCE_INFO", function()
	if S.db and S.ready then pcall(S.ScanLocks) end
end)

local function RequestLocks()
	if RequestRaidInfo then pcall(RequestRaidInfo) end
end

-- a raid save appears when you are saved to it, and changes when you zone out
S.On("PLAYER_ENTERING_WORLD", function() S.After(6, RequestLocks) end)
S.On("CHAT_MSG_SYSTEM", function(msg)
	if msg and (string.find(msg, "saved to this instance") or (INSTANCE_SAVED and msg == INSTANCE_SAVED)) then
		S.After(2, RequestLocks)
	end
end)

S.On("PLAYER_LOGIN", function()
	S.After(10, RequestLocks)
	local function Again()
		S.After(600, Again)
		RequestLocks()
	end
	S.After(600, Again)
end)

-------------------------------------------------------------------------------
-- Once a second: expire timers, fire alerts, keep open displays live
-------------------------------------------------------------------------------
local tickCount = 0
local function Tick()
	S.After(1, Tick)
	if not S.db or not S.ready then return end

	CheckRequest()
	local active = table.getn(Prune())
	if lastActive ~= nil then
		if active < lastActive then
			Alert("free")
		elseif active > lastActive and active >= MAX_RESETS then
			Alert("cap")
		end
	end
	lastActive = active

	-- timers tick on screen while the IRC tab or the minimap tooltip is showing
	if S.tab == "irc" and SHAltsFrame and SHAltsFrame:IsShown() then S.UIChanged() end
	-- the raids and cooldowns lists change slowly, so every few seconds is plenty
	tickCount = tickCount + 1
	if tickCount >= 5 then
		tickCount = 0
		if S.PruneTimers then S.PruneTimers() end
		if (S.tab == "raids" or S.tab == "cd" or S.tab == "track") and SHAltsFrame and SHAltsFrame:IsShown() then S.UIChanged() end
	end
	if S.minimapHover and S.ShowMinimapTip then S.ShowMinimapTip() end
end

S.On("PLAYER_LOGIN", function() S.After(4, Tick) end)

end)
