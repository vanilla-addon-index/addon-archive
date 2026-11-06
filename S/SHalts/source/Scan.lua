-------------------------------------------------------------------------------
-- SHAlts scanning: reads the current character and stores it in SHAltsDB
-------------------------------------------------------------------------------
local S = SHAlts

local SALT_SHAKER = 15846

-- Professions we keep. Matching by English name keeps this independent of
-- the skill window's header names.
local PROFS = {
	["Alchemy"] = true, ["Blacksmithing"] = true, ["Enchanting"] = true,
	["Engineering"] = true, ["Herbalism"] = true, ["Leatherworking"] = true,
	["Mining"] = true, ["Skinning"] = true, ["Tailoring"] = true,
	["Cooking"] = true, ["First Aid"] = true, ["Fishing"] = true,
	["Poisons"] = true,
}
S.PROFS = PROFS

-------------------------------------------------------------------------------
-- Records
-------------------------------------------------------------------------------
function S.GetChar()
	local key = S.CharKey()
	local c = S.db.chars[key]
	if not c then
		c = { bags = {}, bank = {}, gear = {}, skills = {}, recipes = {}, cd = {}, mail = {}, rep = {}, pvp = {}, resets = {}, locks = {} }
		S.db.chars[key] = c
	end
	c.name = UnitName("player")
	c.realm = GetRealmName()
	if not c.mail then c.mail = {} end
	if not c.rep then c.rep = {} end
	if not c.pvp then c.pvp = {} end
	if not c.resets then c.resets = {} end
	if not c.locks then c.locks = {} end
	return c, key
end

local function ParseLink(link)
	if not link then return nil end
	local _, _, color, id, name = string.find(link, "|c(%x+)|Hitem:(%d+):[^|]*|h%[(.-)%]|h|r")
	if id then return tonumber(id), name, color end
	return nil
end

local function RememberItem(id, name, color, tex)
	local it = S.db.items[id]
	if not it then
		it = {}
		S.db.items[id] = it
	end
	it.n = name
	it.c = color
	if tex then it.t = tex end
end

-------------------------------------------------------------------------------
-- Basic info
-------------------------------------------------------------------------------
function S.ScanInfo()
	-- while the game is still loading (or shutting down) the player reports level 0;
	-- recording that would wipe the real data, so wait for the next scan
	local lvl = UnitLevel("player")
	if not lvl or lvl < 1 then return end
	local c = S.GetChar()
	local _, class = UnitClass("player")
	c.class = class
	c.level = UnitLevel("player")
	c.money = GetMoney()
	c.faction = UnitFactionGroup("player")
	c.seen = time()
end

-------------------------------------------------------------------------------
-- Bags and bank
-------------------------------------------------------------------------------
-- hook(id, bag, slot) is called for every item found
local function ScanContainers(list, hook)
	local counts, used, total = {}, 0, 0
	for i = 1, table.getn(list) do
		local bag = list[i]
		local n = GetContainerNumSlots(bag)
		if n and n > 0 then
			total = total + n
			for slot = 1, n do
				local link = GetContainerItemLink(bag, slot)
				if link then
					used = used + 1
					local id, name, color = ParseLink(link)
					if id then
						local tex, count = GetContainerItemInfo(bag, slot)
						count = count or 1
						if count < 1 then count = 1 end
						counts[id] = (counts[id] or 0) + count
						RememberItem(id, name, color, tex)
						if hook then hook(id, bag, slot) end
					end
				end
			end
		end
	end
	return counts, used, total
end

-- Every cooldown write goes through here. If one finished since the last scan
-- (the cooldown time had passed and it now reads ready), the alert is told,
-- because the old end time is about to be overwritten with 0.
local function SetCooldown(c, name, endsAt)
	local old = c.cd[name]
	if old and old > 0 and endsAt == 0 and old <= time() + 2 and S.QueueAlert then
		S.QueueAlert(S.CharKey(), name, old)
	end
	c.cd[name] = endsAt
end

function S.ScanBags()
	-- same: a character always has a backpack, so zero slots means "not loaded yet"
	if not GetContainerNumSlots or (GetContainerNumSlots(0) or 0) < 1 then return end
	local c = S.GetChar()
	local shaker = false
	local counts, used, total = ScanContainers({ 0, 1, 2, 3, 4 }, function(id, bag, slot)
		if id == SALT_SHAKER then
			shaker = true
			local start, duration = GetContainerItemCooldown(bag, slot)
			local endsAt = 0
			-- a duration under 1.5s is just the global cooldown
			if start and duration and start > 0 and duration > 1.5 then
				local left = start + duration - GetTime()
				if left > 0 then endsAt = time() + math.floor(left) end
			end
			SetCooldown(c, "Salt Shaker", endsAt)
		end
	end)
	if not shaker then c.cd["Salt Shaker"] = nil end
	c.bags = counts
	c.bagUsed = used
	c.bagTotal = total
end

local bankOpen = false

function S.ScanBank()
	if not bankOpen then return end
	local c = S.GetChar()
	local counts, used, total = ScanContainers({ -1, 5, 6, 7, 8, 9, 10 })
	c.bank = counts
	c.bankUsed = used
	c.bankTotal = total
	c.bankSeen = time()
end

-------------------------------------------------------------------------------
-- Equipment
-------------------------------------------------------------------------------
function S.ScanGear()
	local c = S.GetChar()
	local gear = {}
	for slot = 1, 19 do
		local link = GetInventoryItemLink("player", slot)
		if link then
			local id, name, color = ParseLink(link)
			if id then
				gear[slot] = id
				RememberItem(id, name, color, GetInventoryItemTexture("player", slot))
			end
		end
	end
	c.gear = gear
end

-------------------------------------------------------------------------------
-- Professions (skill window)
-------------------------------------------------------------------------------
local skillIgnoreUntil = 0

function S.ScanSkills()
	local c = S.GetChar()

	-- Collapsed headers hide their skills, so open them all, read, then put
	-- back whichever headers were closed (bottom up so indexes stay valid).
	local wasCollapsed = {}
	for i = 1, GetNumSkillLines() do
		local name, header, expanded = GetSkillLineInfo(i)
		if header and not expanded then wasCollapsed[name] = true end
	end
	ExpandSkillHeader(0)

	local list = {}
	for i = 1, GetNumSkillLines() do
		local name, header, _, rank, _, _, maxRank = GetSkillLineInfo(i)
		if name and not header and PROFS[name] then
			table.insert(list, { n = name, r = rank or 0, m = maxRank or 0 })
		end
	end

	for i = GetNumSkillLines(), 1, -1 do
		local name, header = GetSkillLineInfo(i)
		if header and wasCollapsed[name] then CollapseSkillHeader(i) end
	end

	-- the expand/collapse above fires SKILL_LINES_CHANGED again; ignore it
	skillIgnoreUntil = GetTime() + 1
	c.skills = list
end

-------------------------------------------------------------------------------
-- Profession cooldowns. Stock 1.12 has no call for them, so the recipes that
-- have one are known by name, with their length for when the tooltip can't say.
-------------------------------------------------------------------------------
local function CdSeconds(name)
	if name == "Transmute: Arcanite" then return 2 * 86400 end
	if string.find(name, "^Transmute") then return 86400 end
	if name == "Mooncloth" or name == "Shadowcloth" or name == "Spellcloth" then return 4 * 86400 end
	return nil
end
S.CdSeconds = CdSeconds

local scanTip
local tipWorks = false   -- becomes true once a tooltip has shown us a cooldown line

-- seconds left according to the recipe tooltip ("Cooldown remaining: 3 days 2 hrs"), or nil
local function TipRemaining(index)
	local ok, left = pcall(function()
		if not scanTip then
			scanTip = CreateFrame("GameTooltip", "SHAltsScanTip", nil, "GameTooltipTemplate")
		end
		scanTip:SetOwner(UIParent, "ANCHOR_NONE")
		scanTip:ClearLines()
		scanTip:SetTradeSkillItem(index)
		for i = 1, (scanTip:NumLines() or 0) do
			local fs = getglobal("SHAltsScanTipTextLeft" .. i)
			local txt = fs and fs:GetText()
			if txt then
				local _, _, rest = string.find(txt, "[Cc]ooldown [Rr]emaining:?%s*(.+)")
				if rest then
					local total = 0
					local _, _, d = string.find(rest, "(%d+)%s*[Dd]ay")
					local _, _, h = string.find(rest, "(%d+)%s*[Hh]o?u?r")
					local _, _, m = string.find(rest, "(%d+)%s*[Mm]in")
					local _, _, sec = string.find(rest, "(%d+)%s*[Ss]ec")
					total = (tonumber(d) or 0) * 86400 + (tonumber(h) or 0) * 3600 + (tonumber(m) or 0) * 60 + (tonumber(sec) or 0)
					if total > 0 then return total end
				end
			end
		end
		return nil
	end)
	if ok then return left end
	return nil
end

-- A craft only starts a cooldown once it finishes, which shows up as a bag
-- change shortly after DoTradeSkill. Used when the tooltip can't tell us.
local pendingCd
if type(DoTradeSkill) == "function" then
	local origDo = DoTradeSkill
	DoTradeSkill = function(index, num)
		origDo(index, num)
		pcall(function()
			local name = GetTradeSkillInfo(index)
			local dur = name and CdSeconds(name)
			if dur then pendingCd = { name = name, dur = dur, t = GetTime() } end
		end)
	end
end

local function CommitPendingCooldown()
	local p = pendingCd
	if not p then return end
	local age = GetTime() - p.t
	if age > 20 then pendingCd = nil; return end
	if age < .5 then return end
	pendingCd = nil
	SetCooldown(S.GetChar(), p.name, time() + p.dur)
	S.DataChanged()
end

-------------------------------------------------------------------------------
-- Recipes (profession windows). A profession's list is only complete when
-- its window has been opened, so that is when it is recorded.
-------------------------------------------------------------------------------
local busy = false

local function AddRecipe(c, prof, name)
	local set = c.recipes[prof]
	if not set then
		set = {}
		c.recipes[prof] = set
	end
	set[name] = true
end

local function NoteCooldown(c, name, seconds)
	if seconds and seconds > 0 then
		SetCooldown(c, name, time() + math.floor(seconds))
	elseif c.cd[name] then
		SetCooldown(c, name, 0)
	end
end

-- full = true on window open: expand every header, then replace the list
local function ScanTradeSkill(full)
	if busy or not GetTradeSkillLine then return end
	local prof = GetTradeSkillLine()
	if not prof or not PROFS[prof] then return end
	if GetNumTradeSkills() == 0 then return end
	busy = true
	local c = S.GetChar()

	if full then
		for i = GetNumTradeSkills(), 1, -1 do
			local _, kind, _, expanded = GetTradeSkillInfo(i)
			if kind == "header" and not expanded then ExpandTradeSkillSubClass(i) end
		end
		c.recipes[prof] = {}
	end

	for i = 1, GetNumTradeSkills() do
		local name, kind = GetTradeSkillInfo(i)
		if name and kind ~= "header" then
			AddRecipe(c, prof, name)
			-- Cooldown recipes (transmutes, mooncloth...). A client that has the
			-- cooldown function gives exact numbers for everything; otherwise the
			-- recipe tooltip is read for the ones we know about.
			if type(GetTradeSkillCooldown) == "function" then
				NoteCooldown(c, name, GetTradeSkillCooldown(i))
			elseif CdSeconds(name) then
				local left = TipRemaining(i)
				if left then
					tipWorks = true
					SetCooldown(c, name, time() + left)
				elseif tipWorks and c.cd[name] then
					SetCooldown(c, name, 0)
				end
			end
		end
	end
	busy = false
	S.DataChanged()
end

local function ScanCraft(full)
	if busy or not GetCraftDisplaySkillLine then return end
	local prof = GetCraftDisplaySkillLine()
	if not prof or not PROFS[prof] then return end   -- also skips Beast Training
	if GetNumCrafts() == 0 then return end
	busy = true
	local c = S.GetChar()

	if full and ExpandCraftSkillLine then
		for i = GetNumCrafts(), 1, -1 do
			local _, _, kind, _, expanded = GetCraftInfo(i)
			if kind == "header" and not expanded then ExpandCraftSkillLine(i) end
		end
	end
	if full then c.recipes[prof] = {} end

	for i = 1, GetNumCrafts() do
		local name, _, kind = GetCraftInfo(i)
		if name and kind ~= "header" then AddRecipe(c, prof, name) end
	end
	busy = false
	S.DataChanged()
end

-------------------------------------------------------------------------------
-- Mailbox. Like the bank, the game only shows it while it is open, so it is
-- recorded automatically whenever you visit a mailbox.
-------------------------------------------------------------------------------
local mailOpen = false

function S.ScanMail()
	if not mailOpen or not GetInboxNumItems then return end
	local c = S.GetChar()

	-- name -> item id, for the items this addon has already seen
	local byName, clash = {}, {}
	for id, it in pairs(S.db.items) do
		if it.n then
			if byName[it.n] and byName[it.n] ~= id then clash[it.n] = true end
			byName[it.n] = id
		end
	end

	local merged, order, money = {}, {}, 0
	for i = 1, (GetInboxNumItems() or 0) do
		local okH, _, _, _, _, gold = pcall(GetInboxHeaderInfo, i)
		if okH and tonumber(gold) then money = money + gold end
		local ok, name, tex, count, quality = pcall(GetInboxItem, i)
		if ok and name then
			local id
			if GetInboxItemLink then
				local okL, link = pcall(GetInboxItemLink, i)
				if okL and link then id = ParseLink(link) end
			end
			if not id and not clash[name] then id = byName[name] end
			local key = id or name
			local e = merged[key]
			if not e then
				e = { n = name, c = 0, t = tex, q = quality or 1, id = id }
				merged[key] = e
				table.insert(order, e)
			end
			e.c = e.c + (count or 1)
			if id and not S.db.items[id] then RememberItem(id, name, S.QualityColor(quality), tex) end
		end
	end
	c.mail = order
	c.mailMoney = money
	c.mailSeen = time()
end

-------------------------------------------------------------------------------
-- Reputation
-------------------------------------------------------------------------------
local repIgnoreUntil = 0

function S.ScanRep()
	if not GetNumFactions or not GetFactionInfo then return end
	local n = GetNumFactions() or 0
	if n == 0 then return end
	local c = S.GetChar()

	-- collapsed headers hide their factions: open them (bottom up so the
	-- numbers above stay valid), read, then put them back
	local collapsed = {}
	for i = n, 1, -1 do
		local name, _, _, _, _, _, _, _, isHeader, isCollapsed = GetFactionInfo(i)
		if isHeader and isCollapsed then
			collapsed[name] = true
			ExpandFactionHeader(i)
		end
	end

	local list = {}
	for i = 1, (GetNumFactions() or 0) do
		local name, _, standing, bmin, bmax, bval, _, _, isHeader = GetFactionInfo(i)
		if name then
			if isHeader then
				table.insert(list, { n = name, s = 0, v = 0, m = 0 })
			else
				bmin, bmax, bval = bmin or 0, bmax or 0, bval or 0
				table.insert(list, { n = name, s = standing or 4, v = bval - bmin, m = bmax - bmin })
			end
		end
	end

	for i = (GetNumFactions() or 0), 1, -1 do
		local name, _, _, _, _, _, _, _, isHeader = GetFactionInfo(i)
		if isHeader and collapsed[name] then CollapseFactionHeader(i) end
	end
	repIgnoreUntil = GetTime() + 1   -- opening and closing headers fires the event again
	c.rep = list
end

-------------------------------------------------------------------------------
-- PvP rank and honor
-------------------------------------------------------------------------------
function S.ScanPvp()
	local c = S.GetChar()
	local p = {}
	pcall(function()
		local rank = UnitPVPRank and UnitPVPRank("player") or 0
		if rank and rank >= 1 and GetPVPRankInfo then
			local name, num = GetPVPRankInfo(rank)
			p.rank = name
			p.num = num
		end
		if GetPVPRankProgress then p.prog = GetPVPRankProgress() end
		if GetPVPLifetimeStats then
			local hk, dk = GetPVPLifetimeStats()
			p.hk, p.dk = hk, dk
		end
		if GetPVPThisWeekStats then
			local _, contribution = GetPVPThisWeekStats()
			p.week = contribution
		end
	end)
	c.pvp = p
end

-------------------------------------------------------------------------------
-- Time played. The game prints it in chat when asked, so chat is muted for
-- that one answer and our own request stays silent.
-------------------------------------------------------------------------------
local muted

local function RestoreChat()
	if not muted then return end
	for i = 1, table.getn(muted) do muted[i]:RegisterEvent("TIME_PLAYED_MSG") end
	muted = nil
end

function S.RequestPlayed()
	if not RequestTimePlayed or muted then return end
	muted = {}
	for i = 1, (NUM_CHAT_WINDOWS or 7) do
		local f = getglobal("ChatFrame" .. i)
		if f and f.UnregisterEvent then
			local was = true
			if f.IsEventRegistered then was = f:IsEventRegistered("TIME_PLAYED_MSG") and true or false end
			if was then
				f:UnregisterEvent("TIME_PLAYED_MSG")
				table.insert(muted, f)
			end
		end
	end
	S.After(5, RestoreChat)   -- even if the answer never comes, chat is put back
	RequestTimePlayed()
end

S.On("TIME_PLAYED_MSG", function(total)
	if tonumber(total) and S.db then
		local c = S.GetChar()
		c.played = total
		c.playedAt = time()
		S.DataChanged()
	end
	S.After(1, RestoreChat)
end)

-------------------------------------------------------------------------------
-- Scheduling: events only mark things dirty, one tick per second does the work
-------------------------------------------------------------------------------
local dirty = {}
local acc = 0
S.ready = false

function S.ScanAll()
	S.ScanInfo()
	S.ScanBags()
	S.ScanGear()
	S.ScanSkills()
	S.ScanPvp()
	S.ScanRep()
	S.DataChanged()
end

S.OnTick = function(elapsed)
	if not S.ready then return end
	acc = acc + elapsed
	if acc < 1 then return end
	if S.StarTick then S.StarTick(acc) end
	acc = 0

	local changed = false
	if dirty.info then dirty.info = nil; S.ScanInfo(); changed = true end
	if dirty.bags then dirty.bags = nil; S.ScanBags(); changed = true end
	if dirty.bank then dirty.bank = nil; S.ScanBank(); changed = true end
	if dirty.gear then dirty.gear = nil; S.ScanGear(); changed = true end
	if dirty.skills then dirty.skills = nil; S.ScanSkills(); changed = true end
	if dirty.rep then dirty.rep = nil; S.ScanRep(); changed = true end
	if dirty.pvp then dirty.pvp = nil; S.ScanPvp(); changed = true end
	if dirty.mail then dirty.mail = nil; S.ScanMail(); changed = true end
	if changed then S.DataChanged() end
end

S.On("PLAYER_LOGIN", function()
	-- bag and skill data is not always ready the moment we log in
	-- On a slow or busy client (two games loading at once) the character can
	-- still report level 0, no gold and no bag slots a few seconds after login.
	-- Wait until the level is real, then scan again a little later as a safety net.
	local tries = 0
	local function FirstScan()
		tries = tries + 1
		local lvl = UnitLevel("player")
		if (not lvl or lvl < 1) and tries < 20 then
			S.After(2, FirstScan)
			return
		end
		S.ready = true
		S.ScanAll()
		S.selected = S.CharKey()
		S.DataChanged()
		S.After(15, function() S.ScanAll() end)
	end
	S.After(3, FirstScan)
	-- time played, then again now and then; rank and honor change slowly too
	S.After(8, function() S.RequestPlayed() end)
	local function Periodic()
		S.After(1200, Periodic)
		S.RequestPlayed()
		dirty.pvp = true
	end
	S.After(1200, Periodic)
	S.After(6, function()
		if S.db.alert then
			local ready = S.ReadyList()
			if table.getn(ready) > 0 then
				S.Print("cooldowns ready: " .. table.concat(ready, ", "))
			end
		end
	end)
end)

S.On("PLAYER_MONEY", function() dirty.info = true end)
S.On("PLAYER_LEVEL_UP", function() dirty.info = true end)
S.On("UNIT_INVENTORY_CHANGED", function(unit)
	if unit == "player" then dirty.gear = true end
end)
S.On("BAG_UPDATE", function()
	CommitPendingCooldown()
	dirty.bags = true
	if bankOpen then dirty.bank = true end
end)
S.On("BAG_UPDATE_COOLDOWN", function() dirty.bags = true end)
S.On("SKILL_LINES_CHANGED", function()
	if GetTime() < skillIgnoreUntil then return end
	dirty.skills = true
end)

S.On("UPDATE_FACTION", function()
	if GetTime() < repIgnoreUntil then return end
	dirty.rep = true
end)
S.On("PLAYER_PVP_KILLS_CHANGED", function() dirty.pvp = true end)
S.On("PLAYER_PVP_RANK_CHANGED", function() dirty.pvp = true end)

S.On("MAIL_SHOW", function()
	mailOpen = true
	S.After(.5, function() dirty.mail = true end)
end)
S.On("MAIL_INBOX_UPDATE", function() if mailOpen then dirty.mail = true end end)
S.On("MAIL_CLOSED", function() mailOpen = false end)

S.On("BANKFRAME_OPENED", function()
	bankOpen = true
	S.After(.5, function() dirty.bank = true end)
end)
S.On("BANKFRAME_CLOSED", function()
	bankOpen = false
end)

S.On("TRADE_SKILL_SHOW", function() S.After(.3, function() ScanTradeSkill(true) end) end)
S.On("TRADE_SKILL_UPDATE", function() ScanTradeSkill(false) end)
S.On("CRAFT_SHOW", function() S.After(.3, function() ScanCraft(true) end) end)
S.On("CRAFT_UPDATE", function() ScanCraft(false) end)
