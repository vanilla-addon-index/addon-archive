-- RollFor.lua : lets the bidding window work when the loot master uses the RollFor addon instead of SkullEPGP_Officer.
-- RollFor's loot master broadcasts every roll session in hidden addon messages (prefix "RollFor"):
--   ROLL::START_ROLL::{...}   ROLL::TICK::{...}   ROLL::ROLL::{...}   ROLL::FINISH::{...}   ROLL::CANCEL_ROLL::
--   ROLL::TIE::{...}   ROLL::TIESTART::   ROLL::AWARDED::{...}   ROLL::CHUNK::<i>::<n>::<part>   (long messages)
-- Those are used when they arrive. Older RollFor versions only post in the chat, so the raid warning
-- "Roll for [item]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG)" and the result lines are read too.
-- Rolls themselves are read from the system chat ("X rolls 87 (1-99)"), like RollFor does.
local P = SkullEPGPP
local RF = {}
P.RF = RF
RF.PREFIX = "RollFor"
RF.TICK = 1.7               -- RollFor counts its "seconds" every 1.7 s
RF.chunks = {}

local RT = { MainSpec = "MS", OffSpec = "OS", Transmog = "TMOG", SoftRes = "MS" }
RF.RANK = { MS = 3, OS = 2, TMOG = 1 }

-------------------------------------------------------------------------------
-- RollFor serialises its tables with its own dump(): {["key"]=value,[1]=value}, strings without quotes
-------------------------------------------------------------------------------
function RF.Parse(s)
	if not s or s == "" then return {} end
	local len, pos = string.len(s), 1
	local value
	value = function()
		if string.sub(s, pos, pos) == "{" then
			pos = pos + 1
			local t = {}
			while pos <= len and string.sub(s, pos, pos) ~= "}" do
				local c = string.sub(s, pos, pos)
				if c == "," then
					pos = pos + 1
				elseif c == "[" then
					local _, e, k = string.find(s, '^%["?([^"%]]*)"?%]=', pos)
					if not e then return t end
					pos = e + 1
					t[tonumber(k) or k] = value()
				else
					local v = value()       -- leftover of a string that contained a comma: ignored
				end
			end
			pos = pos + 1
			return t
		end
		local _, e, raw = string.find(s, "^([^,}]*)", pos)
		if not e or e < pos then pos = pos + 1; return nil end
		pos = e + 1
		if raw == "nil" then return nil end
		return tonumber(raw) or raw
	end
	local ok, res = pcall(value)
	if ok and type(res) == "table" then return res end
	return {}
end

-------------------------------------------------------------------------------
-- helpers
-------------------------------------------------------------------------------
local function lower(s) return string.lower(s or "") end

-- "A, B and C" -> { "A", "B", "C" }
local function names(str)
	local out = {}
	str = string.gsub(str or "", " and ", ", ")
	for n in string.gfind(str, "[^,]+") do
		local _, _, clean = string.find(n, "^%s*(.-)%s*$")
		if clean and clean ~= "" then table.insert(out, clean) end
	end
	return out
end

local function hasName(list, name)
	name = lower(name)
	for _, n in ipairs(list or {}) do
		if lower(type(n) == "table" and (n.name or n.n) or n) == name then return true end
	end
	return false
end

local function me() return UnitName("player") end

-- max of the /roll for a choice (MS, OS, TMOG, MIN, NEED, MAX)
function RF:RollMax(a, choice)
	local th = a.th or {}
	if choice == "OS" then return th.os or 99 end
	if choice == "TMOG" then return th.tm or 98 end
	return th.ms or 100
end

-- MS / OS / TMOG of a roll, from its max
function RF:TypeOf(a, max)
	local th = a.th or {}
	if max == (th.ms or 100) then return "MS" end
	if max == (th.os or 99) then return "OS" end
	if (th.tm or 0) > 0 and max == th.tm then return "TMOG" end
	return nil
end

function RF:Sort(list)
	table.sort(list, function(x, y)
		local rx, ry = RF.RANK[x.bid] or 0, RF.RANK[y.bid] or 0
		if rx ~= ry then return rx > ry end
		local ax, ay = x.roll or 0, y.roll or 0
		if ax ~= ay then return ax > ay end
		if x.t ~= y.t then return x.t < y.t end
		return x.char < y.char
	end)
end

-------------------------------------------------------------------------------
-- a roll session starts
-------------------------------------------------------------------------------
-- info = { id, link, count, seconds, th = {ms, os, tm}, sr = {names}, classes = {..}, tex, sender }
function RF:Start(info)
	local now = GetTime()
	local a = P.auction
	if a and a.src == "rf" and a.id == info.id and a.state == "open" and now - a.started < 5 then
		-- same session announced twice (addon message + raid warning): keep the richer data
		if info.fromAddon then
			a.viaAddon = true
			a.th = info.th
			a.timed = true
			a.endTime = now + (info.seconds or 8) * RF.TICK
			a.sr, a.classes = info.sr, info.classes
			self:Eligibility(a)
			if P.UI then P.UI:Refresh() end
		end
		return
	end
	a = { src = "rf", id = info.id, link = info.link, count = info.count or 1, state = "open", bids = {}, winners = {},
		myChoice = nil, started = now, th = info.th, sr = info.sr or {}, classes = info.classes, officer = info.sender,
		timed = info.seconds ~= nil, viaAddon = info.fromAddon, endTime = now + (info.seconds or 8) * RF.TICK, test = info.test }
	if info.tex then a.iconTex = info.tex end
	self:Eligibility(a)
	P:NewAuction(a)
end

-- soft-reserve and class restrictions, like RollFor's own roll popup
function RF:Eligibility(a)
	a.blocked, a.onlyMax = nil, nil
	if a.sr and table.getn(a.sr) > 0 then
		if hasName(a.sr, me()) then
			a.onlyMax = (a.th and a.th.ms) or 100
		else
			local list = {}
			for _, n in ipairs(a.sr) do table.insert(list, type(n) == "table" and (n.name or n.n) or n) end
			a.blocked = "Soft-reserved by " .. table.concat(list, ", ")
		end
	end
	if a.classes and table.getn(a.classes) > 0 then
		local _, cls = UnitClass("player")
		local ok = false
		for _, c in ipairs(a.classes) do if lower(c) == lower(cls) then ok = true end end
		if not ok then a.blocked = "For " .. table.concat(a.classes, ", ") .. " only" end
	end
end

function RF:Current(id)
	local a = P.auction
	if a and a.src == "rf" and (not id or a.id == id) then return a end
end

function RF:AddRoll(a, char, bid, roll)
	if not char or not bid then return end
	local key = lower(char)
	if a.bids[key] then return end                       -- RollFor only counts the first roll (the list is cleared on a tie)
	if a.tie and not hasName(a.tiePlayers, char) then return end
	a.bids[key] = { char = char, bid = bid, roll = roll, t = GetTime() }
	if key == lower(me()) then
		a.myChoice = a.myChoice or bid
		P.pending = nil
	end
	if P.UI then P.UI:Refresh() end
end

function RF:Finish(a, winners)
	a.tie, a.tiePlayers = nil, nil
	a.state = "closed"
	a.closedAt = GetTime()
	a.winners = {}
	for _, w in ipairs(winners) do
		table.insert(a.winners, { char = w.char, bid = w.bid or "MS", cost = 0, roll = w.roll })
		if not a.test then
			P:AddHistory(a.link, w.char, (w.bid or "MS") .. (w.roll and (" " .. w.roll) or ""))
		end
		if lower(w.char) == lower(me()) then
			P:Print("|cff33cc33You won " .. a.link .. "!|r")
			local pkey = P:FindPrebid(a.link)
			if pkey then
				P.db.lists.prebid[pkey] = nil
				if P.Options and P.Options.Refresh then P.Options:Refresh() end
			end
		end
	end
	if table.getn(a.winners) > 0 then a.state = "awarded" end
	P.pending = nil
	if P.UI then P.UI:Refresh() end
end

function RF:StartTie(a, players, max)
	a.tie = true
	a.tiePlayers = players
	a.state = "open"
	a.closedAt = nil
	a.timed = false
	a.winners = {}
	a.bids = {}
	if hasName(players, me()) then
		a.myChoice = nil
		a.blocked = nil
		a.onlyMax = max
		P:Print("Tie on " .. a.link .. ": roll again!")
		if P.UI then P.UI:ShowWindow() end
		PlaySound("igQuestLogOpen")
	else
		a.blocked = "Tie between " .. table.concat(players, ", ")
	end
	if P.UI then P.UI:Refresh() end
end

-------------------------------------------------------------------------------
-- hidden addon messages
-------------------------------------------------------------------------------
function RF:OnAddonMessage(text, sender)
	if not text or sender == me() then return end
	local _, _, body = string.find(text, "^ROLL::(.*)$")
	if not body then return end
	local _, _, cmd, data = string.find(body, "^(.-)::(.*)$")
	if not cmd then return end
	if cmd == "CHUNK" then
		local _, _, i, n, part = string.find(data, "^(%d+)::(%d+)::(.*)$")
		i, n = tonumber(i), tonumber(n)
		if not i or not n then return end
		if i == 1 then self.chunks[sender] = {} end
		local c = self.chunks[sender]
		if not c then return end
		c[i] = part
		if i < n then return end
		local full = table.concat(c)
		self.chunks[sender] = nil
		_, _, cmd, data = string.find(full, "^(.-)::(.*)$")
		if not cmd then return end
	end
	if not P:IsOfficerName(sender) then return end
	self:Command(cmd, self.Parse(data), sender)
end

function RF:Command(cmd, d, sender)
	if cmd == "START_ROLL" then
		if d.st ~= "NormalRoll" and d.st ~= "SoftResRoll" then return end
		local i = d.i or {}
		local id = tonumber(i.id)
		if not id then return end
		local link = P:MakeLink(id)
		if not link then
			local q = tonumber(i.q) or 4
			local name = string.gsub(tostring(i.n or ("item " .. id)), "_", " ")
			link = "|cff" .. (P.QCOL[q] or "a335ee") .. "|Hitem:" .. id .. ":0:0:0|h[" .. name .. "]|h|r"
		end
		local sr = {}
		for _, p in ipairs(type(d.sr) == "table" and d.sr or {}) do if type(p) == "table" and p.n then table.insert(sr, p.n) end end
		local classes = {}
		for _, c in ipairs(type(i.cl) == "table" and i.cl or {}) do table.insert(classes, c) end
		local th = type(d.th) == "table" and d.th or {}
		self:Start({ id = id, link = link, count = tonumber(d.ic) or 1, seconds = tonumber(d.s), sender = sender, fromAddon = true,
			th = { ms = tonumber(th.ms) or 100, os = tonumber(th.os) or 99, tm = tonumber(th.tm) or 0 },
			sr = sr, classes = classes, tex = (i.tx and i.tx ~= "") and ("Interface\\Icons\\" .. i.tx) or nil })
		return
	end
	local a = self:Current()
	if not a then return end
	a.viaAddon = true
	if cmd == "TICK" then
		local sl = tonumber(d.sl)
		if sl and a.state == "open" then a.timed = true; a.endTime = GetTime() + sl * RF.TICK end
	elseif cmd == "ROLL" then
		self:AddRoll(a, d.pn, RT[d.rt] or "MS", tonumber(d.r))
	elseif cmd == "FINISH" then
		local w = {}
		for _, x in ipairs(d) do
			if type(x) == "table" and x.n then table.insert(w, { char = x.n, bid = RT[x.rt] or "MS", roll = tonumber(x.r) }) end
		end
		if table.getn(w) == 0 then
			a.state = "closed"; a.closedAt = GetTime(); P.pending = nil
			if P.UI then P.UI:Refresh() end
		else
			self:Finish(a, w)
		end
	elseif cmd == "CANCEL_ROLL" then
		a.state = "cancelled"; a.closedAt = GetTime(); P.pending = nil
		if P.UI then P.UI:Refresh() end
	elseif cmd == "TIE" then
		local players = {}
		for _, x in ipairs(type(d.p) == "table" and d.p or {}) do if type(x) == "table" and x.n then table.insert(players, x.n) end end
		a.pendingTie = { players = players, max = self:RollMax(a, RT[d.rt] or "MS") }
	elseif cmd == "TIESTART" then
		if a.pendingTie then self:StartTie(a, a.pendingTie.players, a.pendingTie.max); a.pendingTie = nil end
	end
	if P.UI then P.UI:UpdateTimer() end
end

-------------------------------------------------------------------------------
-- chat (older RollFor, or when the addon messages did not arrive)
-------------------------------------------------------------------------------
local function linkIn(msg)
	local _, _, link = string.find(msg, "(|c%x+|Hitem:%d+[^|]*|h%[.-%]|h|r)")
	local _, _, id = string.find(msg, "|Hitem:(%d+)")
	return link, tonumber(id)
end

function RF:OnChat(msg, sender)
	if not msg or not P:IsOfficerName(sender) then return end
	-- "Roll for 2x[item]: /roll (MS) or /roll 99 (OS) or /roll 98 (TMOG). 2 top rolls win."   /  "...: SR by A and B"
	local _, _, rest = string.find(msg, "^Roll for (.*)$")
	if rest then
		local link, id = linkIn(rest)
		if not id then return end
		local _, _, cnt = string.find(rest, "^(%d+)x")
		local th = { ms = 100, os = 99, tm = 98 }
		local _, _, ms = string.find(rest, "/roll (%d+) ?%(MS%)")
		local _, _, os = string.find(rest, "/roll (%d+) ?%(OS%)")
		local _, _, tm = string.find(rest, "/roll (%d+) ?%(TMOG%)")
		if string.find(rest, "%(OS%)") then
			th.ms = tonumber(ms) or 100
			th.os = tonumber(os) or 99
			th.tm = tonumber(tm) or 0
		end
		local sr = {}
		local _, _, srBy = string.find(rest, "SR by (.*)$")
		if srBy then
			srBy = string.gsub(srBy, "%.%s*%d+ top rolls win%.?$", "")
			srBy = string.gsub(srBy, "%.$", "")
			sr = names(srBy)
		end
		self:Start({ id = id, link = link or P:MakeLink(id), count = tonumber(cnt) or 1, th = th, sr = sr, sender = sender })
		return
	end
	local a = self:Current()
	if not a or a.viaAddon then return end          -- the addon messages already give everything
	if string.find(msg, "^Rolling for .* was canceled%.") then
		a.state = "cancelled"; a.closedAt = GetTime(); P.pending = nil
	elseif string.find(msg, "^No one rolled for ") then
		a.state = "closed"; a.closedAt = GetTime(); P.pending = nil
	else
		-- "A and B rolled the highest (95) for [item] (OS)."  /  "A rolled the next highest (80) for [item]."
		local _, _, who, roll = string.find(msg, "^(.-) r?e?%-?rolled the n?e?x?t? ?highest %((%d+)[^%)]*%) for ")
		if who then
			local bid = "MS"
			if string.find(msg, "%(OS%)%.?$") then bid = "OS" elseif string.find(msg, "%(TMOG%)%.?$") then bid = "TMOG" end
			-- kept for 1.5 s: if a tie announcement follows, the tied players are taken out again
			a.chatWinners = a.chatWinners or {}
			for _, n in ipairs(names(who)) do table.insert(a.chatWinners, { char = n, bid = bid, roll = tonumber(roll) }) end
			a.state = "closed"; a.closedAt = GetTime()
			a.chatWinnersAt = GetTime() + 1.5
		else
			-- tie: "A and B /roll 99 for [item] now."
			local _, _, who2, rollCmd = string.find(msg, "^(.-) (/roll[%d ]*) for .* now%.")
			if who2 then
				local tied = names(who2)
				local keep = {}
				for _, w in ipairs(a.chatWinners or {}) do if not hasName(tied, w.char) then table.insert(keep, w) end end
				a.chatWinners = keep
				local _, _, mx = string.find(rollCmd, "(%d+)")
				self:StartTie(a, names(who2), tonumber(mx) or 100)
			else
				local _, _, srWho = string.find(msg, "^(.-) soft%-ressed ")
				if srWho then
					local w = {}
					for _, n in ipairs(names(srWho)) do table.insert(w, { char = n, bid = "MS" }) end
					self:Finish(a, w)
				end
			end
		end
	end
	if P.UI then P.UI:Refresh() end
end

function RF:OnUpdate()
	local a = self:Current()
	if a and a.chatWinners and a.chatWinnersAt and GetTime() >= a.chatWinnersAt then
		local w = a.chatWinners
		a.chatWinners, a.chatWinnersAt = nil, nil
		if a.state ~= "open" then self:Finish(a, w) else a.chatWinners = w end   -- tie still running: applied at its end
	end
end

-------------------------------------------------------------------------------
-- /roll results in the system chat
-------------------------------------------------------------------------------
local rollPattern
local function buildRollPattern()
	local fmt = RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)"
	fmt = string.gsub(fmt, "([%(%)%.%-%+%*%?%[%]%^%$])", "%%%1")
	fmt = string.gsub(fmt, "%%s", "(.+)")
	fmt = string.gsub(fmt, "%%d", "(%%d+)")
	rollPattern = "^" .. fmt .. "$"
end

function RF:OnSystem(msg)
	local a = self:Current()
	if not a or a.state ~= "open" or not msg then return end
	if not rollPattern then buildRollPattern() end
	local _, _, who, roll, mn, mx = string.find(msg, rollPattern)
	roll, mn, mx = tonumber(roll), tonumber(mn), tonumber(mx)
	if not who or not roll or mn ~= 1 then return end
	if a.tie then
		if mx ~= a.onlyMax and not hasName(a.tiePlayers, who) then return end
	end
	local bid = self:TypeOf(a, mx)
	if not bid then return end
	if a.sr and table.getn(a.sr) > 0 and not hasName(a.sr, who) then return end
	self:AddRoll(a, who, bid, roll)
end

-------------------------------------------------------------------------------
-- my roll
-------------------------------------------------------------------------------
function RF:Roll(choice)
	local a = P.auction
	local max = self:RollMax(a, choice)
	if a.test then
		P:Print("(test) would /roll " .. max)
		self:AddRoll(a, me(), self:TypeOf(a, max) or "MS", math.random(1, max))
		return true
	end
	local ok = pcall(RandomRoll, 1, max)
	if not ok then P:Print("Could not roll: type /roll " .. max .. " in the chat.") return false end
	a.myChoice = choice
	a.myLabel = choice
	if P.UI then P.UI:Refresh() end
	return true
end
