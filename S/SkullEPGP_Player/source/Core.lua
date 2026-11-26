-- Skull EPGP Player (WoW 1.12 / Lua 5.0)
-- Receives the loot announcements of the officer addon (SkullEPGP_Officer) and lets you answer with one click.
-- Protocol (addon prefix SKULLEPGP, sent by the master looter / raid leader):
--   AUC;<id>;<seconds left>;<copies>;<link>      bidding open
--   BID;<id>;<char>;<MIN|NEED|MAX|ROLL>;<roll>;<pr>   somebody bid / rolled
--   END;<id>    bidding closed        CAN;<id>   cancelled
--   WIN;<id>;<char>;<tier>;<cost>               item awarded
--   P;<Main/Alt>,<ep>,<gp>;...                   priorities       CFG;<MIN>;<NEED>;<MAX>;<baseGP>   prices
-- Player -> officer: "REQ" (asks for my priority, prices and the current announcement); the officer answers "NP" when I am not in the list
-- When the loot master uses RollFor instead, RollFor.lua reads its announcements (P.auction.src == "rf").
SkullEPGPP = {}
local P = SkullEPGPP
P.PREFIX = "SKULLEPGP"
P.TIERS = { ROLL = 1, MIN = 2, NEED = 3, MAX = 4 }
-- the buttons. With the officer addon the three rolls are a plain /roll (bid ROLL); with RollFor they are
-- /roll <MS>, /roll <OS>, /roll <TMOG> (100 / 99 / 98 by default), and MIN / NEED / MAX are a /roll <MS>
P.CHOICES = { "MS", "OS", "TMOG", "MIN", "NEED", "MAX" }
P.LABEL = { MS = "Roll MS", OS = "Roll OS", TMOG = "Tmog", MIN = "MIN", NEED = "NEED", MAX = "MAX", ROLL = "Roll" }
P.IS_ROLL = { MS = true, OS = true, TMOG = true }
P.auction = nil
P.pending = nil            -- { choice, t } : a choice was sent, waiting for the officer's confirmation
P.lastReq = -100
P.history = {}          -- won items of this session (not saved): { link, char, bid }

local DEFAULTS = {
	autoShow = true,
	autoClose = true,
	cfg = { MIN = 5, NEED = 15, MAX = 45, baseGP = 0 },
	me = nil,              -- { ep, gp } last known values of this character's main
	onlyPrebids = false,   -- true: the bidding window never opens by itself (only the pre-bids work)
	lists = { prebid = {} },     -- prebid[key] = { id, name, link, bid = ROLL|MIN|NEED|MAX }
	minimapAngle = 200,
	minimapHidden = false,
}

function P:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff49C0C0[EPGP]|r " .. tostring(msg))
end

local function split(s, sep)
	local out, pos = {}, 1
	while true do
		local a = string.find(s, sep, pos, true)
		if not a then
			table.insert(out, string.sub(s, pos))
			break
		end
		table.insert(out, string.sub(s, pos, a - 1))
		pos = a + string.len(sep)
	end
	return out
end

local function copyDefaults(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then
			if type(v) == "table" then
				dst[k] = {}
				copyDefaults(dst[k], v)
			else
				dst[k] = v
			end
		elseif type(v) == "table" and type(dst[k]) == "table" then
			copyDefaults(dst[k], v)
		end
	end
end

function P:InitDB()
	SkullEPGP_PlayerDB = SkullEPGP_PlayerDB or {}
	self.db = SkullEPGP_PlayerDB
	copyDefaults(self.db, DEFAULTS)
	for _, e in pairs(self.db.lists.prebid) do
		if e.bid == "ROLL" then e.bid = "MS" end          -- before 1.7.0 there was a single "Roll"
	end
end

-------------------------------------------------------------------------------
-- Item filter (blacklist / whitelist): decides if the window opens by itself for an announced item
-------------------------------------------------------------------------------
-- text = item link, item id, or item name  ->  key, id, name, link
-- a real clickable link for an item id (GetItemInfo may return a bare "item:id:0:0:0" string on some clients)
local QCOL = { [0] = "9d9d9d", "ffffff", "1eff00", "0070dd", "a335ee", "ff8000" }
P.QCOL = QCOL
function P:MakeLink(id, link)
	if link and string.find(link, "|h%[") then return link end
	if not id then return link end
	local n, l, q = GetItemInfo("item:" .. id .. ":0:0:0")
	if not n then return nil end
	if l and string.find(l, "|h%[") then return l end
	return "|cff" .. (QCOL[q or 1] or "ffffff") .. "|Hitem:" .. id .. ":0:0:0|h[" .. n .. "]|h|r"
end

-- looks for the link of an item by its name: bags, equipped items, last announcement, history
function P:FindLinkByName(name)
	if not name or name == "" then return nil end
	local lname = string.lower(name)
	local function test(l)
		if l then
			local _, _, n = string.find(l, "%[(.-)%]")
			if n and string.lower(n) == lname then return true end
		end
	end
	if GetContainerNumSlots then
		for b = 0, 4 do
			for sl = 1, (GetContainerNumSlots(b) or 0) do
				local l = GetContainerItemLink(b, sl)
				if test(l) then return l end
			end
		end
	end
	if GetInventoryItemLink then
		for sl = 1, 19 do local l = GetInventoryItemLink("player", sl); if test(l) then return l end end
	end
	if self.auction and test(self.auction.link) then return self.auction.link end
	for _, h in ipairs(self.history or {}) do if test(h.link) then return h.link end end
	return nil
end

-- link and icon of what the user typed (link, id or name), when they can be found
function P:ResolveItem(text)
	local key, id, name, link = self:ParseItem(text)
	if not key then return nil end
	local tex
	if id then
		local _, l, _, _, _, _, _, _, t = GetItemInfo("item:" .. id .. ":0:0:0")
		tex = t
		if not link and l then link = self:MakeLink(id, l) end
	end
	return link, tex
end

function P:ParseItem(text)
	text = text or ""
	local _, _, id = string.find(text, "Hitem:(%d+)")
	local _, _, name = string.find(text, "%[(.-)%]")
	local link = id and text or nil
	if not id then
		local _, _, num = string.find(text, "^%s*(%d+)%s*$")
		if num then
			id = num
			local n, l = GetItemInfo(tonumber(id))
			name = n
			if n and l then link = self:MakeLink(id, l) end
		else
			local _, _, nm = string.find(text, "^%s*(.-)%s*$")
			name = nm
			local found = self:FindLinkByName(nm)
			if found then
				local _, _, fid = string.find(found, "Hitem:(%d+)")
				if fid then return fid, fid, nm, found end
			end
		end
	end
	if id then return id, id, name, link end
	if name and name ~= "" then return "n:" .. string.lower(name), nil, name, nil end
end

function P:InList(listName, link)
	local list = self.db.lists[listName]
	if not list then return false end
	local key, id, name = self:ParseItem(link)
	if not key then return false end
	if id and list[id] then return true end
	if name and list["n:" .. string.lower(name)] then return true end
	return false
end

function P:AddToList(listName, text)
	local list = self.db.lists[listName]
	local key, id, name, link = self:ParseItem(text)
	if not list or not key then return false end
	list[key] = { id = id, name = name or ("item " .. tostring(id)), link = link }
	if listName == "prebid" then list[key].bid = "NEED" end
	return true, list[key]
end

function P:RemoveFromList(listName, key)
	local list = self.db.lists[listName]
	if list and list[key] then list[key] = nil; return true end
	return false
end

-- sorted array of { key, entry } for display
function P:ListEntries(listName)
	local out = {}
	for k, e in pairs(self.db.lists[listName] or {}) do table.insert(out, { key = k, e = e }) end
	table.sort(out, function(a, b) return string.lower(a.e.name or "") < string.lower(b.e.name or "") end)
	return out
end

-------------------------------------------------------------------------------
-- Pre-bids (manual list) and history
-------------------------------------------------------------------------------
function P:ItemId(link)
	local _, _, id = string.find(link or "", "Hitem:(%d+)")
	return id
end

P.BIDS = P.CHOICES

-- the pre-bid entry of an item (or nil), when the option is on
function P:FindPrebid(link)
	local list = self.db.lists.prebid
	local key, id, name = self:ParseItem(link)
	if not key then return nil end
	if id and list[id] then return id, list[id] end
	if name and list["n:" .. string.lower(name)] then return "n:" .. string.lower(name), list["n:" .. string.lower(name)] end
	return nil
end

function P:SetPrebid(key, bid)
	local e = self.db.lists.prebid[key]
	if e then e.bid = bid end
end

function P:AddHistory(link, char, bid)
	table.insert(self.history, 1, { link = link, char = char, bid = bid })
	if table.getn(self.history) > 200 then table.remove(self.history) end
	if self.Loot then self.Loot:Refresh() end
end

-------------------------------------------------------------------------------
-- Who may send us announcements: the raid / party leader and the master looter
-------------------------------------------------------------------------------
-- cached for a few seconds: it scans the whole raid roster and runs for every message of the officer
P.offCache = {}
function P:IsOfficerName(name)
	if not name then return false end
	local key, now = string.lower(name), GetTime()
	local c = self.offCache[key]
	if c and now - c.t < 5 then return c.v end
	local v = self:CheckOfficerName(name) and true or false
	self.offCache[key] = { v = v, t = now }
	return v
end

function P:CheckOfficerName(name)
	if not name then return false end
	name = string.lower(name)
	local nraid = GetNumRaidMembers() or 0
	if nraid > 0 then
		for i = 1, nraid do
			local n, rank = GetRaidRosterInfo(i)
			if n and string.lower(n) == name and rank and rank >= 1 then return true end   -- leader or assistant
		end
	else
		for i = 1, (GetNumPartyMembers() or 0) do
			local u = "party" .. i
			local n = UnitName(u)
			if n and string.lower(n) == name and UnitIsPartyLeader and UnitIsPartyLeader(u) then return true end
		end
		if string.lower(UnitName("player")) == name and IsPartyLeader and IsPartyLeader() then return true end
	end
	local method, partyID, raidID = GetLootMethod()
	if method == "master" then
		local u
		if raidID and raidID > 0 then u = "raid" .. raidID elseif partyID == 0 then u = "player" elseif partyID and partyID > 0 then u = "party" .. partyID end
		local n = u and UnitName(u)
		if n and string.lower(n) == name then return true end
	end
	return false
end

-------------------------------------------------------------------------------
-- Priority
-------------------------------------------------------------------------------
function P:PR(ep, gp)
	local den = (gp or 0) + (self.db.cfg.baseGP or 0)
	if den < 1 then den = 1 end
	return (ep or 0) / den
end

function P:MyPR()
	local me = self.db and self.db.me
	if not me then return nil end
	return self:PR(me.ep, me.gp), me.ep, me.gp
end

-------------------------------------------------------------------------------
-- Messages from the officer
-------------------------------------------------------------------------------
function P:HandleMessage(text, sender)
	if not self.db or not text then return end
	local f = split(text, ";")
	local tag = f[1]
	if tag == "P" then
		local me = string.lower(UnitName("player"))
		for i = 2, table.getn(f) do
			local e = split(f[i], ",")
			local ep, gp = tonumber(e[2]), tonumber(e[3])
			if e[1] and ep and gp then
				for name in string.gfind(e[1], "[^/]+") do
					if string.lower(name) == me then
						self.db.me = { ep = ep, gp = gp }
						self.db.noEntry = nil
						if self.UI then self.UI:Refresh() end
					end
				end
			end
		end
	elseif tag == "NP" then
		if not f[2] or string.lower(f[2]) ~= string.lower(UnitName("player")) then return end
		self.db.noEntry = true            -- the officer has no priority for me: stop asking
		if self.UI then self.UI:Refresh() end
	elseif tag == "CFG" then
		local mn, nd, mx, base = tonumber(f[2]), tonumber(f[3]), tonumber(f[4]), tonumber(f[5])
		if mn and nd and mx then
			self.db.cfg.MIN, self.db.cfg.NEED, self.db.cfg.MAX = mn, nd, mx
			self.db.cfg.baseGP = base or 0
			if self.UI then self.UI:Refresh() end
		end
	elseif tag == "AUC" then
		local id, secs, count = tonumber(f[2]), tonumber(f[3]), tonumber(f[4])
		if not id or not secs then return end
		local link = table.concat(f, ";", 5)
		local a = self.auction
		if a and a.id == id then
			a.endTime = GetTime() + secs           -- answer to REQ for the same announcement: just resync the timer
			if a.state == "closed" then a.state = "open" end
		else
			self:NewAuction({ src = "epgp", id = id, link = link, count = count or 1, endTime = GetTime() + secs, timed = true,
				state = "open", bids = {}, winners = {}, myChoice = nil, started = GetTime(), test = (sender == "test") })
			if not self.db.me and not self.db.noEntry then self:Request() end
		end
		if self.UI then self.UI:Refresh() end
	elseif tag == "BID" then
		local a = self.auction
		local id = tonumber(f[2])
		if not a or a.id ~= id or not f[3] then return end
		local bid, roll, pr = f[4], tonumber(f[5]) or 0, tonumber(f[6]) or 0
		if not self.TIERS[bid] then return end
		a.bids[string.lower(f[3])] = { char = f[3], bid = bid, roll = (roll > 0) and roll or nil, pr = pr, t = GetTime() }
		if string.lower(f[3]) == string.lower(UnitName("player")) then
			a.myChoice = bid
			self.pending = nil
		end
		if self.UI then self.UI:Refresh() end
	elseif tag == "END" or tag == "CAN" then
		local a = self.auction
		if a and a.id == tonumber(f[2]) then
			a.state = (tag == "END") and "closed" or "cancelled"
			a.closedAt = GetTime()
			self.pending = nil
			if self.UI then self.UI:Refresh() end
		end
	elseif tag == "WIN" then
		local a = self.auction
		if not a or a.id ~= tonumber(f[2]) or not f[3] then return end
		table.insert(a.winners, { char = f[3], bid = f[4], cost = tonumber(f[5]) or 0 })
		if not a.test then
			local b = a.bids[string.lower(f[3])]
			local what = f[4] or "?"
			if what == "ROLL" then what = "Roll " .. tostring((b and b.roll) or "?") end
			self:AddHistory(a.link, f[3], what)
		end
		a.bids[string.lower(f[3])] = nil
		if table.getn(a.winners) >= (a.count or 1) then
			a.state = "awarded"
			a.closedAt = GetTime()
			a.bids = {}                       -- last copy awarded: the list of bidders is cleared
		end
		if string.lower(f[3]) == string.lower(UnitName("player")) then
			self:Print("|cff33cc33You won " .. a.link .. "!|r")
			local pkey = self:FindPrebid(a.link)
			if pkey then
				self.db.lists.prebid[pkey] = nil                  -- won: removed from the pre-bid list
				if self.Options and self.Options.Refresh then self.Options:Refresh() end
			end
		end
		if self.UI then self.UI:Refresh() end
	end
end

-- a new announcement (officer addon or RollFor): window, sound, pre-bid
function P:NewAuction(a)
	self.auction = a
	self.pending = nil
	local link = a.link
	if self.db.onlyPrebids then
		if self.UI then self.UI:HideWindow() end
		self:Print("Announced: " .. link .. " (window not opened: only pre-bids. Type /epgpp to open it)")
	else
		if self.UI and self.db.autoShow then self.UI:ShowWindow() end
		PlaySound("igQuestLogOpen")
	end
	-- pre-bid saved for this item: sent now
	local pkey, pe = self:FindPrebid(link)
	if pe and not a.test then
		local bid = pe.bid or "NEED"
		if self:Choose(bid) then
			self:Print("Pre-bid sent: |cffffd700" .. (self.LABEL[bid] or bid) .. "|r on " .. link)
		end
	end
	if self.UI then self.UI:Refresh() end
	if self.Options and self.Options:IsShown() then self.Options:Refresh() end
end

function P:OnAddonMessage(prefix, text, channel, sender)
	if not self.db then return end
	if prefix == self.RF.PREFIX then self.RF:OnAddonMessage(text, sender) return end
	if prefix ~= self.PREFIX then return end
	if text == "REQ" then return end                       -- player -> officer message
	if string.len(text) > 2 and string.sub(text, 3, 3) == ";" and string.sub(text, 1, 1) == "S" then return end   -- officer <-> officer sync
	if not self:IsOfficerName(sender) then return end
	self:HandleMessage(text, sender)
end

-------------------------------------------------------------------------------
-- Choices
-------------------------------------------------------------------------------
-- may the button for this choice (MS / OS / TMOG / MIN / NEED / MAX) be used now ?
function P:CanChoose(choice)
	local a = self.auction
	if not a or a.state ~= "open" or self.pending then return false end
	if a.src == "rf" then
		if a.blocked or a.myChoice then return false end
		local max = self.RF:RollMax(a, choice)
		if max < 1 then return false end                   -- transmog rolls disabled by the loot master
		if a.onlyMax and max ~= a.onlyMax then return false end
		return true
	end
	if a.myChoice == nil then return true end
	return a.myChoice == "NEED" and choice == "MAX"       -- one choice per announcement; NEED can be upgraded to MAX
end

function P:Channel()
	if GetNumRaidMembers() > 0 then return "RAID" end
	if GetNumPartyMembers() > 0 then return "PARTY" end
	return nil
end

function P:Choose(choice)
	if not self:CanChoose(choice) then return false end
	local a = self.auction
	if a.src == "rf" then return self.RF:Roll(choice) end
	if self.IS_ROLL[choice] then a.rollLabel = choice end      -- the officer only knows "ROLL"
	if a.test then
		self:Print("(test) would send: " .. (self.IS_ROLL[choice] and "/roll" or choice))
		a.myChoice = self.IS_ROLL[choice] and "ROLL" or choice
		if self.UI then self.UI:Refresh() end
		return true
	end
	if self.IS_ROLL[choice] then
		local ok = pcall(RandomRoll, 1, 100)
		if not ok then self:Print("Could not roll: type /roll in the chat.") return false end
	else
		local ch = self:Channel()
		if not ch then self:Print("You are not in a group.") return false end
		SendChatMessage(choice, ch)
	end
	self.pending = { choice = self.LABEL[choice] or choice, t = 0 }
	if self.UI then self.UI:Refresh() end
	return true
end

-- bids sorted like the officer's ranking: tier, priority, roll, arrival
function P:SortedBids()
	local a = self.auction
	local list = {}
	if not a then return list end
	for _, b in pairs(a.bids) do table.insert(list, b) end
	if a.src == "rf" then self.RF:Sort(list) return list end
	table.sort(list, function(x, y)
		local tx, ty = self.TIERS[x.bid], self.TIERS[y.bid]
		if tx ~= ty then return tx > ty end
		if tx > 1 and x.pr ~= y.pr then return x.pr > y.pr end
		local rx, ry = x.roll or 0, y.roll or 0
		if rx ~= ry then return rx > ry end
		if x.t ~= y.t then return x.t < y.t end
		return x.char < y.char
	end)
	return list
end

-------------------------------------------------------------------------------
-- Requests, timers, events
-------------------------------------------------------------------------------
function P:Request()
	local now = GetTime()
	if now - self.lastReq < 5 then return end
	local ch = self:Channel()
	if not ch then return end
	self.lastReq = now
	SendAddonMessage(self.PREFIX, "REQ", ch)
end

P.tick = 0
function P:OnUpdate(elapsed)
	if not self.db then return end
	self.tick = self.tick + (elapsed or 0)
	if self.pending then
		self.pending.t = self.pending.t + (elapsed or 0)
		if self.pending.t > 3 then
			self.pending = nil
			self:Print("No confirmation from the officer yet for your choice (not in the EPGP list, or the choice was refused).")
			if self.UI then self.UI:Refresh() end
		end
	end
	-- no priority yet (the officer imported before we were connected): ask again every 30 s, silently
	self.reqTick = (self.reqTick or 0) + (elapsed or 0)
	if self.reqTick >= 30 then
		self.reqTick = 0
		if self.inGroup and not self.db.me and not self.db.noEntry then self:Request() end
	end
	self.RF:OnUpdate()
	if self.tick < 0.25 then return end
	self.tick = 0
	local a = self.auction
	if a and a.closedAt and self.db.autoClose and GetTime() - a.closedAt > 20 and self.UI then
		self.UI:HideWindow()
	end
	if self.UI then self.UI:UpdateTimer() end
end

function P:OnEvent(event, a1, a2, a3, a4)
	if event == "VARIABLES_LOADED" then
		self:InitDB()
		if self.UI then self.UI:ApplySaved() end
		if self.Minimap then self.Minimap:Apply() end
	elseif not self.db then
		return
	elseif event == "PLAYER_ENTERING_WORLD" or event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
		self.offCache = {}                -- leader / master looter may have changed
		local n = (GetNumRaidMembers() or 0) + (GetNumPartyMembers() or 0)
		if n > 0 and not self.inGroup then self.db.noEntry = nil; self:Request() end      -- just joined a group: ask for my priority and the current item
		self.inGroup = n > 0
		if n == 0 then
			self.auction = nil
			if self.UI then self.UI:HideWindow() end
			if self.Loot then self.Loot:Refresh() end
		end
	elseif event == "CHAT_MSG_ADDON" then
		self:OnAddonMessage(a1, a2, a3, a4)
	elseif event == "CHAT_MSG_SYSTEM" then
		self.RF:OnSystem(a1)
	else                                                  -- raid / party / raid warning: RollFor announcements
		self.RF:OnChat(a1, a2)
	end
end

local frame = CreateFrame("Frame", "SkullEPGPPlayerEvents")
local evs = { "VARIABLES_LOADED", "PLAYER_ENTERING_WORLD", "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "CHAT_MSG_ADDON",
	"CHAT_MSG_SYSTEM", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_PARTY" }
for i = 1, table.getn(evs) do frame:RegisterEvent(evs[i]) end
frame:SetScript("OnEvent", function() P:OnEvent(event, arg1, arg2, arg3, arg4) end)
frame:SetScript("OnUpdate", function() P:OnUpdate(arg1) end)

-------------------------------------------------------------------------------
-- Slash command
-------------------------------------------------------------------------------
SLASH_SKULLEPGPP1 = "/epgpp"
SLASH_SKULLEPGPP2 = "/skullepgpp"
SlashCmdList["SKULLEPGPP"] = function(raw)
	if not P.db then return end
	raw = raw or ""
	local msg = string.lower(raw)
	local _, _, listName, action, arg = string.find(raw, "^%s*(%a+)%s+(%a+)%s*(.-)%s*$")
	listName = listName and string.lower(listName)
	action = action and string.lower(action)
	if msg == "" then
		P.UI:Toggle()
	elseif msg == "history" then
		P.Loot:Show("history")
	elseif msg == "options" or msg == "config" or msg == "prebid" or msg == "prebids" then
		P.Options:Toggle()
	elseif (listName == "prebid") and (action == "add" or action == "remove" or action == "list") then
		if action == "list" then
			local n = 0
			for _, it in ipairs(P:ListEntries(listName)) do n = n + 1; P:Print(listName .. ": " .. (it.e.link or it.e.name)) end
			if n == 0 then P:Print("pre-bid list is empty.") end
		elseif action == "add" then
			local ok, e = P:AddToList(listName, arg)
			if ok then P:Print("Added to the pre-bid list: " .. (e.link or e.name)) else P:Print("Usage: /epgpp " .. listName .. " add [item link, item id or item name]") end
		else
			local key = P:ParseItem(arg)
			if key and P:RemoveFromList(listName, key) then P:Print("Removed from the " .. "pre-bid list: " .. arg)
			else P:Print("Not in the " .. "pre-bid list.") end
		end
		if P.Options then P.Options:Refresh() end
	elseif msg == "minimap" then
		P.db.minimapHidden = not P.db.minimapHidden
		if P.Minimap then P.Minimap:Apply() end
		P:Print("Minimap button: " .. (P.db.minimapHidden and "hidden" or "shown"))
	elseif msg == "test" then
		P:HandleMessage("CFG;5;15;45;10", "test")
		P:HandleMessage("P;" .. UnitName("player") .. ",5726.24,6.52", "test")
		P:HandleMessage("AUC;999;45;1;|cffa335ee|Hitem:19019:0:0:0|h[Thunderfury, Blade of the Windseeker]|h|r", "test")
		P:HandleMessage("BID;999;Alice;MAX;0;346.67", "test")
		P:HandleMessage("BID;999;Bob;NEED;0;200.12", "test")
		P:HandleMessage("BID;999;Carol;MIN;0;150.5", "test")
		P:HandleMessage("BID;999;Dave;ROLL;87;0", "test")
		P:Print("Test announcement shown (your buttons will not send anything useful).")
	elseif msg == "testrf" then
		local fake = "|cffa335ee|Hitem:19019:0:0:0|h[Thunderfury, Blade of the Windseeker]|h|r"
		P.RF:Start({ id = 19019, link = fake, count = 1, seconds = 20, th = { ms = 100, os = 99, tm = 98 }, sr = {}, sender = "test", test = true })
		P.RF:AddRoll(P.auction, "Alice", "MS", 87)
		P.RF:AddRoll(P.auction, "Bob", "OS", 98)
		P.RF:AddRoll(P.auction, "Carol", "TMOG", 41)
		P:Print("Test RollFor announcement shown (your buttons will not roll).")
	elseif msg == "auto on" or msg == "auto off" then
		P.db.autoShow = (msg == "auto on")
		P:Print("Open the window automatically on an announcement: " .. (P.db.autoShow and "yes" or "no"))
	elseif msg == "reset" then
		P.UI:ResetPosition()
	elseif msg == "req" then
		P.lastReq = -100
		P:Request()
	else
		P:Print("/epgpp - show / hide the window   |   /epgpp history - items won   |   /epgpp options - pre-bids   |   /epgpp auto on|off   |   /epgpp reset   |   /epgpp req   |   /epgpp test   |   /epgpp testrf")
		P:Print("Pre-bids: /epgpp prebid add|remove|list [item link]   |   /epgpp minimap")
	end
end
