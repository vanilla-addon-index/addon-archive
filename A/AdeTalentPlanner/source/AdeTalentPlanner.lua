--[[
	AdeTalentPlanner - core
	WoW 1.12 (Lua 5.0): no '#', no '%', no string methods (s:sub), no select/gmatch.

	Data (AdeTalentPlannerDB, account-wide):
	  trees[CLASS]    = { className, numTabs, sig, updated, tabs = { [t] = { name, icon, bg, num, talents = { [i] = {name, icon, tier, col, max, rt, rc} } } } }
	  builds[id]      = { id, class, name, code, created, mod, del }   (shared by every character)
	  spellIds[CLASS] = { sig, map = { [t] = { [i] = { [rank] = spellId } } } }   (needs SuperWoW SpellInfo)
	  chars[key]      = { sel = { [CLASS] = buildId } }
	  settings        = { linkMode, scale, ctrlLearn, maxPoints, scanMax, point }

	Cross-account: with SuperWoW, builds/trees/spellIds are also kept in
	<WoW folder>\imports\AdeTalentPlanner (ImportFile / ExportFile), merged on
	login and on every save (newest change of each build wins).
]]

ATP = {}
local ATP = ATP

ATP.VERSION = "1.0.0"
ATP.FILE = "AdeTalentPlanner"
ATP.LINK_COLOR = "|cff71d5ff"
ATP.SPELL_LINK_COLOR = "|cffffd000"

local mod = math.mod or math.fmod
local getn = table.getn

-------------------------------------------------------------------------------
-- small helpers
-------------------------------------------------------------------------------
function ATP.Print(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff71d5ffAdeTP:|r " .. tostring(msg))
	end
end
local Print = ATP.Print

local function IconKey(path)
	if type(path) ~= "string" then return "" end
	path = string.lower(path)
	local _, _, last = string.find(path, "([^\\/]+)$")
	return last or path
end
ATP.IconKey = IconKey

local function RankNum(rank)
	if type(rank) ~= "string" then return 1 end
	local _, _, n = string.find(rank, "(%d+)")
	return tonumber(n) or 1
end
ATP.RankNum = RankNum

local function Hash(s)
	local h = 0
	for i = 1, string.len(s) do
		h = mod(h * 31 + string.byte(s, i), 2147483647)
	end
	return string.len(s) .. ":" .. h
end
ATP.Hash = Hash

-- name allowed inside a chat link
function ATP.CleanName(name)
	name = tostring(name or "")
	name = string.gsub(name, "[%[%]|:]", "")
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	if string.len(name) > 40 then name = string.sub(name, 1, 40) end
	if name == "" then name = "Build" end
	return name
end

-------------------------------------------------------------------------------
-- build code: one digit per talent (API index order), trees joined by '-'
-- e.g. "0503200000000-0505302513-25"  (trailing zeros trimmed)
-------------------------------------------------------------------------------
function ATP.Encode(ranks, numTabs)
	local parts = {}
	numTabs = numTabs or 3
	for t = 1, numTabs do
		local tr = ranks[t] or {}
		local last = 0
		for i, v in pairs(tr) do
			if type(i) == "number" and type(v) == "number" and v > 0 and i > last then last = i end
		end
		local s = ""
		for i = 1, last do
			local v = tr[i] or 0
			if v > 9 then v = 9 end
			s = s .. v
		end
		parts[t] = s
	end
	return table.concat(parts, "-")
end

-- returns ranks table or nil if the code is malformed
function ATP.Decode(code)
	if type(code) ~= "string" then return nil end
	if string.find(code, "[^%d%-]") then return nil end
	local ranks = { {} }
	local t, pos = 1, 0
	for c = 1, string.len(code) do
		local ch = string.sub(code, c, c)
		if ch == "-" then
			t = t + 1
			if t > 5 then return nil end
			ranks[t] = {}
			pos = 0
		else
			pos = pos + 1
			local v = tonumber(ch)
			if v > 0 then ranks[t][pos] = v end
		end
	end
	return ranks
end

function ATP.TreePoints(ranks, t)
	local sum = 0
	local tr = ranks[t]
	if tr then
		for i, v in pairs(tr) do
			if type(i) == "number" and type(v) == "number" then sum = sum + v end
		end
	end
	return sum
end

function ATP.TotalPoints(ranks)
	local sum = 0
	for t, _ in pairs(ranks) do
		if type(t) == "number" then sum = sum + ATP.TreePoints(ranks, t) end
	end
	return sum
end

function ATP.PointsString(ranks, numTabs)
	local out = {}
	for t = 1, (numTabs or 3) do out[t] = ATP.TreePoints(ranks, t) end
	return table.concat(out, "/")
end

-------------------------------------------------------------------------------
-- planning rules (pure, work for any class whose tree is cached)
-------------------------------------------------------------------------------
-- index of the talent at tier/col in tab t
function ATP.FindTalent(tree, t, tier, col)
	local tab = tree and tree.tabs[t]
	if not tab then return nil end
	for i = 1, tab.num do
		local tal = tab.talents[i]
		if tal and tal.tier == tier and tal.col == col then return i end
	end
	return nil
end

local function PointsBelowTier(ranks, tree, t, tier)
	local sum = 0
	local tab = tree.tabs[t]
	local tr = ranks[t] or {}
	for i = 1, tab.num do
		local tal = tab.talents[i]
		if tal and tal.tier < tier then sum = sum + (tr[i] or 0) end
	end
	return sum
end
ATP.PointsBelowTier = PointsBelowTier

local function PrereqMet(ranks, tree, t, tal)
	if not tal.rt then return true end
	local pi = ATP.FindTalent(tree, t, tal.rt, tal.rc)
	if not pi then return true end
	local pr = (ranks[t] and ranks[t][pi]) or 0
	return pr >= tree.tabs[t].talents[pi].max
end
ATP.PrereqMet = PrereqMet

-- can one more point go into talent i of tab t (ignores total point limit if maxPoints nil)
function ATP.CanAdd(tree, ranks, t, i, maxPoints)
	local tab = tree and tree.tabs[t]
	local tal = tab and tab.talents[i]
	if not tal then return false end
	local r = (ranks[t] and ranks[t][i]) or 0
	if r >= tal.max then return false end
	if maxPoints and ATP.TotalPoints(ranks) >= maxPoints then return false end
	if PointsBelowTier(ranks, tree, t, tal.tier) < (tal.tier - 1) * 5 then return false end
	if not PrereqMet(ranks, tree, t, tal) then return false end
	return true
end

-- every talent with points in tab t still has its tier and prerequisite satisfied
function ATP.TabValid(tree, ranks, t)
	local tab = tree.tabs[t]
	local tr = ranks[t] or {}
	for i = 1, tab.num do
		local tal = tab.talents[i]
		local r = tr[i] or 0
		if tal and r > 0 then
			if r > tal.max then return false end
			if PointsBelowTier(ranks, tree, t, tal.tier) < (tal.tier - 1) * 5 then return false end
			if not PrereqMet(ranks, tree, t, tal) then return false end
		end
	end
	return true
end

function ATP.CanRemove(tree, ranks, t, i)
	local tr = ranks[t]
	local r = tr and tr[i] or 0
	if r <= 0 then return false end
	if r > 1 then tr[i] = r - 1 else tr[i] = nil end
	local ok = ATP.TabValid(tree, ranks, t)
	tr[i] = r
	return ok
end

function ATP.AddPoint(tree, ranks, t, i, maxPoints)
	if not ATP.CanAdd(tree, ranks, t, i, maxPoints) then return false end
	ranks[t] = ranks[t] or {}
	ranks[t][i] = (ranks[t][i] or 0) + 1
	return true
end

function ATP.RemovePoint(tree, ranks, t, i)
	if not ATP.CanRemove(tree, ranks, t, i) then return false end
	local r = ranks[t][i]
	if r > 1 then ranks[t][i] = r - 1 else ranks[t][i] = nil end
	return true
end

-- drop ranks that do not exist in the tree (code from another server version etc.)
function ATP.Clamp(tree, ranks)
	for t = 1, tree.numTabs do
		local tab = tree.tabs[t]
		local tr = ranks[t]
		if tr then
			for i, v in pairs(tr) do
				local tal = tab.talents[i]
				if not tal then tr[i] = nil
				elseif v > tal.max then tr[i] = tal.max end
			end
		end
	end
	return ranks
end

-------------------------------------------------------------------------------
-- serializer for the shared file
-------------------------------------------------------------------------------
local function ser(v, out)
	local tv = type(v)
	if tv == "number" then
		tinsert(out, tostring(v))
	elseif tv == "string" then
		tinsert(out, string.format("%q", v))
	elseif tv == "boolean" then
		tinsert(out, v and "true" or "false")
	elseif tv == "table" then
		tinsert(out, "{")
		for k, val in pairs(v) do
			local kt, vt = type(k), type(val)
			if (kt == "number" or kt == "string") and (vt == "number" or vt == "string" or vt == "boolean" or vt == "table") then
				tinsert(out, "[")
				ser(k, out)
				tinsert(out, "]=")
				ser(val, out)
				tinsert(out, ",")
			end
		end
		tinsert(out, "}\n")
	else
		tinsert(out, "nil")
	end
end

function ATP.Serialize(v)
	local out = {}
	ser(v, out)
	return table.concat(out)
end

function ATP.Deserialize(text)
	if type(text) ~= "string" then return nil end
	local f = loadstring("return " .. text)
	if not f then return nil end
	if setfenv then setfenv(f, {}) end
	local ok, res = pcall(f)
	if ok and type(res) == "table" then return res end
	return nil
end

-------------------------------------------------------------------------------
-- database
-------------------------------------------------------------------------------
function ATP:InitDB()
	if type(AdeTalentPlannerDB) ~= "table" then AdeTalentPlannerDB = {} end
	local db = AdeTalentPlannerDB
	db.trees = db.trees or {}
	db.builds = db.builds or {}
	db.spellIds = db.spellIds or {}
	db.chars = db.chars or {}
	db.settings = db.settings or {}
	local s = db.settings
	if s.linkMode == nil then s.linkMode = "link" end
	if s.scale == nil then s.scale = 1 end
	if s.ctrlLearn == nil then s.ctrlLearn = 1 end
	if s.maxPoints == nil then s.maxPoints = 51 end
	if s.scanMax == nil then s.scanMax = 60000 end
	self.db = db

	local localized, class = UnitClass("player")
	self.playerClass = class
	self.charKey = (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
	db.chars[self.charKey] = db.chars[self.charKey] or {}
	self.char = db.chars[self.charKey]
	self.char.sel = self.char.sel or {}
	self.char.class = class
end

-- time-counter-random: unique across accounts, sorts in creation order
function ATP:NewId()
	self.idCounter = (self.idCounter or 0) + 1
	return string.format("%d-%04d-%06d", time(), self.idCounter, math.random(1, 999999))
end

function ATP:GetBuilds(class)
	local list = {}
	for id, b in pairs(self.db.builds) do
		if b.class == class and not b.del then tinsert(list, b) end
	end
	table.sort(list, function(a, b)
		local ca, cb = a.created or 0, b.created or 0
		if ca == cb then return a.id < b.id end
		return ca < cb
	end)
	return list
end

function ATP:CreateBuild(class, name, code)
	local now = time()
	local b = { id = self:NewId(), class = class, name = ATP.CleanName(name), code = code or "", created = now, mod = now }
	self.db.builds[b.id] = b
	self:MarkDirty()
	return b
end

function ATP:SaveBuild(b, ranks, numTabs)
	b.code = ATP.Encode(ranks, numTabs)
	b.mod = time()
	self:MarkDirty()
end

function ATP:RenameBuild(b, name)
	b.name = ATP.CleanName(name)
	b.mod = time()
	self:MarkDirty()
end

function ATP:DeleteBuild(b)
	b.del = 1
	b.code = ""
	b.mod = time()
	self:MarkDirty()
end

function ATP:NextBuildName(class)
	local used = {}
	for _, b in ipairs(self:GetBuilds(class)) do used[b.name] = 1 end
	local n = 1
	while used["Build " .. n] do n = n + 1 end
	return "Build " .. n
end

-------------------------------------------------------------------------------
-- talent tree cache (lets you plan / view any class you have logged in once)
-------------------------------------------------------------------------------
function ATP:CacheOwnTree()
	if not self.db then return false end
	local numTabs = GetNumTalentTabs and GetNumTalentTabs() or 0
	if not numTabs or numTabs == 0 then return false end
	local localized, class = UnitClass("player")
	local tree = { className = localized, numTabs = numTabs, tabs = {} }
	local sig = {}
	for t = 1, numTabs do
		local name, icon, _, bg = GetTalentTabInfo(t)
		if not name then return false end
		local num = GetNumTalents(t) or 0
		local tab = { name = name, icon = icon, bg = bg, num = num, talents = {} }
		tinsert(sig, t .. "=" .. name .. ":" .. tostring(bg))
		for i = 1, num do
			local tname, ticon, tier, col, _, maxRank = GetTalentInfo(t, i)
			if not tname then return false end
			local tal = { name = tname, icon = ticon, tier = tier, col = col, max = maxRank }
			local rt, rc = GetTalentPrereqs(t, i)
			if rt then tal.rt = rt; tal.rc = rc end
			tab.talents[i] = tal
			tinsert(sig, i .. ":" .. tname .. ":" .. tier .. ":" .. col .. ":" .. maxRank .. ":" .. (rt or 0) .. ":" .. (rc or 0) .. ":" .. IconKey(ticon))
		end
		tree.tabs[t] = tab
	end
	tree.sig = Hash(table.concat(sig, "|"))
	local old = self.db.trees[class]
	if not old or old.sig ~= tree.sig then
		tree.updated = time()
		self.db.trees[class] = tree
		self:MarkDirty()
		self:StartSpellScan()
	elseif old.className ~= localized then
		old.className = localized
	end
	self.treeCached = true
	return true
end

function ATP:GetTree(class)
	return self.db and self.db.trees[class]
end

-------------------------------------------------------------------------------
-- talent -> spell id scan (SuperWoW SpellInfo). Gives real talent chat links
-- ("enchant:<spellId>") that every player can click, addon or not.
-------------------------------------------------------------------------------
local scanFrame = CreateFrame("Frame")
scanFrame:Hide()

function ATP:StartSpellScan(force)
	if type(SpellInfo) ~= "function" or not self.db then return end
	local want, classes, any = {}, {}, false
	for class, tree in pairs(self.db.trees) do
		local s = self.db.spellIds[class]
		if force or not s or s.sig ~= tree.sig then
			any = true
			classes[class] = tree.sig
			for t = 1, tree.numTabs do
				local tab = tree.tabs[t]
				for i = 1, tab.num do
					local tal = tab.talents[i]
					if tal then
						local key = string.lower(tal.name)
						want[key] = want[key] or {}
						tinsert(want[key], { class = class, t = t, i = i, max = tal.max, icon = IconKey(tal.icon) })
					end
				end
			end
		end
	end
	if not any then return end
	self.scan = { want = want, classes = classes, id = 1, last = tonumber(self.db.settings.scanMax) or 60000, found = {} }
	scanFrame:Show()
end

local SCAN_STEP = 2000
scanFrame:SetScript("OnUpdate", function()
	local s = ATP.scan
	if not s then this:Hide() return end
	local stop = s.id + SCAN_STEP - 1
	if stop > s.last then stop = s.last end
	local want, found = s.want, s.found
	for id = s.id, stop do
		local ok, name, rank, tex = pcall(SpellInfo, id)
		if ok and type(name) == "string" then
			local list = want[string.lower(name)]
			if list then
				local r = RankNum(rank)
				local ikey = IconKey(tex)
				for _, e in ipairs(list) do
					if r >= 1 and r <= e.max then
						found[e.class] = found[e.class] or {}
						local fc = found[e.class]
						fc[e.t] = fc[e.t] or {}
						fc[e.t][e.i] = fc[e.t][e.i] or {}
						local slot = fc[e.t][e.i]
						local iconMatch = (ikey == e.icon)
						local cur = slot[r]
						-- lowest id wins, but an icon match always beats a non-match
						if not cur or (iconMatch and not cur.im) then
							slot[r] = { id = id, im = iconMatch }
						end
					end
				end
			end
		end
	end
	s.id = stop + 1
	if s.id > s.last then
		this:Hide()
		ATP.scan = nil
		local n = 0
		for class, sig in pairs(s.classes) do
			local map = {}
			local fc = found[class] or {}
			for t, ti in pairs(fc) do
				map[t] = {}
				for i, ranks in pairs(ti) do
					map[t][i] = {}
					for r, v in pairs(ranks) do map[t][i][r] = v.id; n = n + 1 end
				end
			end
			ATP.db.spellIds[class] = { sig = sig, map = map }
		end
		ATP:MarkDirty()
	end
end)

function ATP:GetSpellId(class, t, i, rank)
	local s = self.db.spellIds[class]
	local tree = self.db.trees[class]
	if not s or not tree or s.sig ~= tree.sig or not s.map then return nil end
	local m = s.map[t] and s.map[t][i]
	return m and m[rank]
end

-------------------------------------------------------------------------------
-- description of a talent at any rank
--   1) AdeTalents data (exact, verified numbers; any class it has data for)
--   2) the talent's spell tooltip (needs the SuperWoW spell id scan)
-------------------------------------------------------------------------------
local function Round4(x)
	return math.floor(x * 10000 + 0.5) / 10000
end

-- same rules as AdeTalents.GetValues / GetText, but for any class
function ATP.AdeTalentsText(class, name, rank)
	local AT = AdeTalents
	if type(AT) ~= "table" then return nil end
	local _, playerClass = UnitClass("player")
	if class == playerClass and type(AT.GetText) == "function" then
		local ok, text = pcall(AT.GetText, name, rank)
		if ok and type(text) == "string" and text ~= "" then return text end
	end
	local data = type(AT.Data) == "table" and AT.Data[class]
	local t = type(data) == "table" and data[name]
	if type(t) ~= "table" or type(t.text) ~= "string" or type(t.n) ~= "table" then return nil end
	if not rank or rank < 1 or rank > (t.max or 1) then return nil end
	local k = t.k or ""
	local values = {}
	for i = 1, getn(t.n) do
		local kind = string.sub(k, i, i)
		if kind == "r" then
			values[i] = Round4(t.n[i] * rank)
		elseif kind == "c" then
			values[i] = t.n[i]
		elseif kind == "v" then
			local list = type(t.v) == "table" and t.v[i]
			values[i] = (type(list) == "table" and list[rank]) or false
		else
			values[i] = false
		end
	end
	local text = string.gsub(t.text, "{(%d+)}", function(i)
		local v = values[tonumber(i)]
		if v then return string.format("%g", v) end
		return "?"
	end)
	return text
end

local scanTip
local spellTextCache = {}
function ATP.SpellText(id)
	if not id then return nil end
	if spellTextCache[id] ~= nil then return spellTextCache[id] or nil end
	if not scanTip then
		scanTip = CreateFrame("GameTooltip", "ATPScanTooltip", nil, "GameTooltipTemplate")
	end
	scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
	scanTip:ClearLines()
	scanTip:SetHyperlink("enchant:" .. id)
	local text
	for i = scanTip:NumLines(), 2, -1 do
		local fs = getglobal("ATPScanTooltipTextLeft" .. i)
		local line = fs and fs:GetText()
		if line and line ~= "" and line ~= " " then text = line break end
	end
	scanTip:Hide()
	spellTextCache[id] = text or false
	return text
end

function ATP:RankText(class, t, i, rank)
	local tree = self:GetTree(class)
	local tal = tree and tree.tabs[t] and tree.tabs[t].talents[i]
	if not tal or not rank or rank < 1 or rank > tal.max then return nil end
	return ATP.AdeTalentsText(class, tal.name, rank) or ATP.SpellText(self:GetSpellId(class, t, i, rank))
end

-------------------------------------------------------------------------------
-- chat links
-------------------------------------------------------------------------------
-- single talent: real spell link when the spell id is known, plain text otherwise
function ATP:TalentLink(class, t, i, rank)
	local tree = self:GetTree(class)
	local tal = tree and tree.tabs[t] and tree.tabs[t].talents[i]
	if not tal then return nil end
	if not rank or rank < 1 then rank = 1 end
	if rank > tal.max then rank = tal.max end
	local id = self:GetSpellId(class, t, i, rank)
	if id then
		return ATP.SPELL_LINK_COLOR .. "|Henchant:" .. id .. "|h[" .. tal.name .. "]|h|r"
	end
	return "[" .. tal.name .. " " .. rank .. "/" .. tal.max .. "]"
end

function ATP:MakeBuildLink(class, code, name)
	local ranks = ATP.Decode(code) or {}
	local tree = self:GetTree(class)
	local numTabs = (tree and tree.numTabs) or 3
	local cname = (tree and tree.className) or (string.sub(class, 1, 1) .. string.lower(string.sub(class, 2)))
	return ATP.LINK_COLOR .. "|Hadetp:b:" .. class .. ":" .. code .. "|h[" .. cname .. ": " .. ATP.CleanName(name) .. " (" .. ATP.PointsString(ranks, numTabs) .. ")]|h|r"
end

-- what goes into the chat box (respects /adetp linkmode)
function ATP:BuildChatText(class, code, name)
	if self.db.settings.linkMode == "plain" then
		return "[AdeTP:" .. class .. ":" .. code .. ":" .. ATP.CleanName(name) .. "]"
	end
	return self:MakeBuildLink(class, code, name)
end

function ATP.InsertChat(text)
	if not text then return end
	if ChatFrameEditBox:IsVisible() then
		ChatFrameEditBox:Insert(text)
	elseif ChatFrame_OpenChat then
		ChatFrame_OpenChat(text)
	else
		ChatFrameEditBox:Show()
		ChatFrameEditBox:Insert(text)
	end
end

-- plain codes in incoming chat become clickable for addon users
local function ConvertPlain(msg)
	if type(msg) ~= "string" or not string.find(msg, "[AdeTP:", 1, true) then return msg end
	return (string.gsub(msg, "%[AdeTP:(%u+):([%d%-]*):([^%]]*)%]", function(class, code, name)
		return ATP:MakeBuildLink(class, code, name)
	end))
end
ATP.ConvertPlain = ConvertPlain

function ATP:HookChatFrames()
	for n = 1, (NUM_CHAT_WINDOWS or 7) do
		local f = getglobal("ChatFrame" .. n)
		if f and not f.atpHooked then
			f.atpHooked = true
			local orig = f.AddMessage
			f.AddMessage = function(self, msg, r, g, b, id)
				return orig(self, ConvertPlain(msg), r, g, b, id)
			end
		end
	end
end

-- link clicks
local origSetItemRef = SetItemRef
function SetItemRef(link, text, button)
	if type(link) == "string" and string.sub(link, 1, 6) == "adetp:" then
		ATP:OnLinkClick(link, text, button)
		return
	end
	return origSetItemRef(link, text, button)
end

function ATP:OnLinkClick(link, text, button)
	local _, _, class, code = string.find(link, "^adetp:b:(%u+):([%d%-]*)$")
	if not class then return end
	if IsShiftKeyDown() and ChatFrameEditBox:IsVisible() then
		ChatFrameEditBox:Insert(ATP.LINK_COLOR .. "|H" .. link .. "|h" .. (text or "[build]") .. "|h|r")
		return
	end
	-- "[Hunter: Name (0/31/20)]" -> "Name"
	local name = text or ""
	local _, _, inner = string.find(name, "^%[(.*)%]$")
	name = inner or name
	name = string.gsub(name, "^[^:]*: ", "")
	name = string.gsub(name, " %([%d/]*%)$", "")
	if ATPUI then ATPUI:ShowLinked(class, code, name) end
end

-------------------------------------------------------------------------------
-- cross-account sync (SuperWoW ImportFile / ExportFile)
-------------------------------------------------------------------------------
function ATP:HasFileIO()
	return type(ImportFile) == "function" and type(ExportFile) == "function"
end

-- merge another copy of the data into ours; returns true if anything changed
function ATP:MergeData(data)
	if type(data) ~= "table" then return false end
	local changed = false
	if type(data.builds) == "table" then
		for id, b in pairs(data.builds) do
			if type(id) == "string" and type(b) == "table" and type(b.class) == "string" then
				local mine = self.db.builds[id]
				local bm = tonumber(b.mod) or 0
				if not mine or bm > (tonumber(mine.mod) or 0) then
					local code = tostring(b.code or "")
					if not ATP.Decode(code) then code = "" end
					self.db.builds[id] = {
						id = id, class = b.class, name = ATP.CleanName(b.name), code = code,
						created = tonumber(b.created) or 0, mod = bm, del = b.del and 1 or nil,
					}
					changed = true
				end
			end
		end
	end
	if type(data.trees) == "table" then
		for class, tree in pairs(data.trees) do
			local mine = self.db.trees[class]
			if type(tree) == "table" and type(tree.tabs) == "table" and tonumber(tree.numTabs)
				and (not mine or (tonumber(tree.updated) or 0) > (tonumber(mine.updated) or 0)) then
				self.db.trees[class] = tree
				changed = true
			end
		end
	end
	if type(data.spellIds) == "table" then
		for class, s in pairs(data.spellIds) do
			local mine = self.db.spellIds[class]
			local tree = self.db.trees[class]
			if type(s) == "table" and tree and s.sig == tree.sig and (not mine or mine.sig ~= tree.sig) then
				self.db.spellIds[class] = s
				changed = true
			end
		end
	end
	return changed
end

function ATP:SyncImport()
	if not self:HasFileIO() then return false end
	local ok, text = pcall(ImportFile, ATP.FILE)
	if not ok or type(text) ~= "string" or text == "" then return false end
	local data = ATP.Deserialize(text)
	if not data then
		Print("shared build file could not be read, it will be rewritten.")
		return false
	end
	local changed = self:MergeData(data)
	if changed and ATPUI then ATPUI:OnDataChanged() end
	return changed
end

function ATP:SyncExport()
	if not self:HasFileIO() then return end
	-- read first so builds saved meanwhile by another client/account are kept
	self:SyncImport()
	local data = { v = 1, builds = self.db.builds, trees = self.db.trees, spellIds = self.db.spellIds }
	local ok, err = pcall(ExportFile, ATP.FILE, ATP.Serialize(data))
	if not ok then Print("could not write the shared build file: " .. tostring(err)) end
	self.dirty = nil
end

local syncFrame = CreateFrame("Frame")
syncFrame:Hide()
syncFrame:SetScript("OnUpdate", function()
	if ATP.dirty and GetTime() - ATP.dirty > 2 then
		this:Hide()
		ATP:SyncExport()
	end
end)

function ATP:MarkDirty()
	self.dirty = GetTime()
	if self:HasFileIO() then syncFrame:Show() end
end

-------------------------------------------------------------------------------
-- import plans from SpecialTalentUI (current character only)
-------------------------------------------------------------------------------
function ATP:ImportOld()
	if not SpecialTalentPlannedSaved and LoadAddOn then
		local loaded, reason = LoadAddOn("SpecialTalentUI")
		if not loaded then
			Print("SpecialTalentUI could not be loaded (" .. tostring(reason) .. "). Enable it in the AddOns list, log in, run /adetp importold, then disable it again.")
			return
		end
	end
	local saved = SpecialTalentPlannedSaved
	local key = UnitName("player") .. " of " .. GetRealmName()
	local mine = saved and saved[key]
	if not mine or type(mine.plans) ~= "table" then
		Print("no SpecialTalentUI plans found for this character.")
		return
	end
	local class = self.playerClass
	local tree = self:GetTree(class)
	local numTabs = (tree and tree.numTabs) or 3
	local existing = {}
	for _, b in ipairs(self:GetBuilds(class)) do existing[b.name .. "#" .. b.code] = 1 end
	local count = 0
	for p = 1, 20 do
		local plan = mine.plans[p]
		if type(plan) == "table" and (tonumber(plan.points) or 0) > 0 then
			local ranks = {}
			for t = 1, numTabs do
				ranks[t] = {}
				if type(plan[t]) == "table" then
					for i, v in pairs(plan[t]) do
						if type(i) == "number" and type(v) == "number" and v > 0 then ranks[t][i] = v end
					end
				end
			end
			local code = ATP.Encode(ranks, numTabs)
			local name = ATP.CleanName(plan.name or ("Imported " .. p))
			if not existing[name .. "#" .. code] then
				self:CreateBuild(class, name, code)
				existing[name .. "#" .. code] = 1
				count = count + 1
			end
		end
	end
	Print("imported " .. count .. " plan(s) from SpecialTalentUI. You can disable SpecialTalent and SpecialTalentUI now and /reload.")
	if ATPUI then ATPUI:OnDataChanged() end
end

-------------------------------------------------------------------------------
-- events
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:RegisterEvent("SPELLS_CHANGED")
ev:RegisterEvent("CHARACTER_POINTS_CHANGED")
ev:SetScript("OnEvent", function()
	if event == "PLAYER_ENTERING_WORLD" then
		if not ATP.db then
			math.randomseed(time())
			ATP:InitDB()
			ATP:HookChatFrames()
			ATP:SyncImport()
			ATP:CacheOwnTree()
			ATP:StartSpellScan()
			if ATPUI then ATPUI:Init() end
			if ATP:HasFileIO() then ATP:MarkDirty() end
		end
	elseif event == "PLAYER_LOGOUT" then
		if ATP.db and ATP.dirty then ATP:SyncExport() end
	elseif ATP.db then
		if not ATP.treeCached then ATP:CacheOwnTree() end
		if ATPUI then ATPUI:OnTalentsChanged() end
	end
end)

-------------------------------------------------------------------------------
-- slash commands
-------------------------------------------------------------------------------
SLASH_ADETALENTPLANNER1 = "/adetp"
SlashCmdList["ADETALENTPLANNER"] = function(msg)
	if not ATP.db then return end
	msg = msg or ""
	local _, _, cmd, rest = string.find(msg, "^%s*(%S*)%s*(.-)%s*$")
	cmd = string.lower(cmd or "")
	local s = ATP.db.settings
	if cmd == "" or cmd == "show" then
		ATPUI:Toggle()
	elseif cmd == "link" then
		ATPUI:LinkCurrent()
	elseif cmd == "linkmode" then
		rest = string.lower(rest or "")
		if rest == "plain" or rest == "link" then s.linkMode = rest end
		Print("link mode: " .. s.linkMode .. "  (link = clickable link, plain = [AdeTP:...] text for servers that block custom links)")
	elseif cmd == "scale" then
		local v = tonumber(rest)
		if v and v >= 0.4 and v <= 1.5 then s.scale = v; ATPUI:ApplyScale() end
		Print("scale: " .. s.scale)
	elseif cmd == "ctrl" then
		if s.ctrlLearn then s.ctrlLearn = nil else s.ctrlLearn = 1 end
		Print("Ctrl-click needed to learn in Learned mode: " .. (s.ctrlLearn and "on" or "off"))
		ATPUI:Refresh()
	elseif cmd == "maxpoints" then
		local v = tonumber(rest)
		if v and v >= 1 and v <= 200 then s.maxPoints = math.floor(v); ATPUI:Refresh() end
		Print("max planned points: " .. s.maxPoints)
	elseif cmd == "sync" then
		if ATP:HasFileIO() then ATP:SyncExport(); Print("synced with " .. ATP.FILE .. " in your WoW imports folder.")
		else Print("SuperWoW not found: builds are shared by all characters of this account only.") end
	elseif cmd == "scan" then
		if type(SpellInfo) == "function" then ATP:StartSpellScan(true); Print("rescanning talent spells...")
		else Print("SuperWoW not found: talents are linked as plain text.") end
	elseif cmd == "scanmax" then
		local v = tonumber(rest)
		if v and v >= 1000 then s.scanMax = math.floor(v); ATP:StartSpellScan(true) end
		Print("highest spell id scanned: " .. s.scanMax)
	elseif cmd == "style" then
		rest = string.lower(rest or "")
		if rest == "auto" then s.style = nil elseif rest == "blizz" or rest == "pfui" then s.style = rest end
		Print("look: " .. (s.style or "auto (pfUI if loaded)") .. "  - type /reload to apply")
	elseif cmd == "importold" then
		ATP:ImportOld()
	else
		Print("v" .. ATP.VERSION .. " commands:")
		Print("/adetp - open or close the window (or press your talent key)")
		Print("/adetp link - put the shown build in chat")
		Print("/adetp linkmode link|plain - clickable link or plain text code")
		Print("/adetp scale 0.4-1.5, /adetp ctrl, /adetp maxpoints N")
		Print("/adetp style auto|blizz|pfui - window look (auto = pfUI if loaded)")
		Print("/adetp sync - sync with other accounts now (SuperWoW)")
		Print("/adetp scan, /adetp scanmax N - rebuild talent spell links (SuperWoW)")
		Print("/adetp importold - import this character's SpecialTalentUI plans")
	end
end
