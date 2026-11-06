-------------------------------------------------------------------------------
-- SHAlts cross-account sync.
--
-- Each account has its own saved-variables file, so the game cannot see another
-- account's alts by itself. SuperWoW's ExportFile/ImportFile read and write
-- plain text files in the game folder's "imports" directory, and every account
-- running from the same game folder shares that directory. We keep one file
-- there (SHAltsSync), merge it into our data and write it back.
--
-- The file is parsed by hand as plain text. It is never run as Lua, so nothing
-- in it can execute, and a damaged or edited file can only fail to merge.
-- Merge rule: per character, the newest "seen" time wins, and the character
-- you are playing is never overwritten from the file.
-------------------------------------------------------------------------------
local S = SHAlts

local FILE = "SHAltsSync"
local HEADER = "SHALTS"
local PUSH_EVERY = 10   -- seconds between writes while data keeps changing
local POLL_EVERY = 5    -- seconds between looks at the shared file for changes from another client
local KEEP_ALERTED = 14 * 86400   -- how long an announced cooldown is remembered

local lastError
local lastText   -- the file as we last read or wrote it, so an unchanged file is not parsed again

function S.SyncForget() lastText = nil end

function S.SyncAvailable()
	return type(ImportFile) == "function" and type(ExportFile) == "function"
end

-------------------------------------------------------------------------------
-- Text helpers. Fields are separated by | , : and ; so those (and % and
-- line breaks) are written as %XX inside names.
-------------------------------------------------------------------------------
local function Esc(s)
	s = tostring(s or "")
	return (string.gsub(s, "[%%|,:;\r\n]", function(ch)
		return string.format("%%%02X", string.byte(ch))
	end))
end

local function Unesc(s)
	return (string.gsub(s, "%%(%x%x)", function(h)
		return string.char(tonumber(h, 16))
	end))
end

local function Num(v)
	v = tonumber(v) or 0
	return tostring(math.floor(v))
end

local function Split(s, sep)
	local out = {}
	local pos = 1
	while true do
		local i = string.find(s, sep, pos, true)
		if not i then
			table.insert(out, string.sub(s, pos))
			break
		end
		table.insert(out, string.sub(s, pos, i - 1))
		pos = i + 1
	end
	return out
end

-------------------------------------------------------------------------------
-- Write
-------------------------------------------------------------------------------
local function CountList(t)
	local parts = {}
	for id, n in pairs(t or {}) do
		table.insert(parts, Num(id) .. ":" .. Num(n))
	end
	return table.concat(parts, ",")
end

function S.SyncSerialize()
	local out = { HEADER }
	local used = {}

	for key, c in pairs(S.db.chars) do
		table.insert(out, table.concat({
			"C", Esc(key), Esc(c.name), Esc(c.realm), Esc(c.class), Num(c.level), Num(c.money),
			Esc(c.faction), Num(c.seen), Num(c.bagUsed), Num(c.bagTotal),
			Num(c.bankUsed), Num(c.bankTotal), Num(c.bankSeen),
		}, "|"))

		if next(c.bags or {}) then table.insert(out, "B|" .. CountList(c.bags)) end
		if next(c.bank or {}) then table.insert(out, "K|" .. CountList(c.bank)) end
		if next(c.gear or {}) then table.insert(out, "G|" .. CountList(c.gear)) end

		local sk = {}
		for i = 1, table.getn(c.skills or {}) do
			local s = c.skills[i]
			table.insert(sk, Esc(s.n) .. ":" .. Num(s.r) .. ":" .. Num(s.m))
		end
		if table.getn(sk) > 0 then table.insert(out, "S|" .. table.concat(sk, ",")) end

		for prof, set in pairs(c.recipes or {}) do
			local names = {}
			for rname in pairs(set) do table.insert(names, Esc(rname)) end
			if table.getn(names) > 0 then
				table.insert(out, "R|" .. Esc(prof) .. "|" .. table.concat(names, ","))
			end
		end

		local cds = {}
		for name, endsAt in pairs(c.cd or {}) do
			table.insert(cds, Esc(name) .. ":" .. Num(endsAt))
		end
		if table.getn(cds) > 0 then table.insert(out, "D|" .. table.concat(cds, ",")) end

		local ml = {}
		for i = 1, table.getn(c.mail or {}) do
			local m = c.mail[i]
			table.insert(ml, Esc(m.n) .. ":" .. Num(m.c) .. ":" .. Esc(m.t) .. ":" .. Num(m.q) .. ":" .. Num(m.id))
		end
		if table.getn(ml) > 0 then table.insert(out, "M|" .. table.concat(ml, ",")) end
		if c.mailSeen then table.insert(out, "E|" .. Num(c.mailSeen) .. "|" .. Num(c.mailMoney)) end
		if c.played then table.insert(out, "P|" .. Num(c.played) .. "|" .. Num(c.playedAt)) end

		local pv = c.pvp
		if pv and next(pv) then
			table.insert(out, table.concat({
				"V", Esc(pv.rank), Num(pv.num), Num((pv.prog or 0) * 1000), Num(pv.hk), Num(pv.dk), Num(pv.week),
			}, "|"))
		end

		local tl = {}
		for i = 1, table.getn(c.resets or {}) do
			local e = c.resets[i]
			table.insert(tl, Num(e.t) .. ":" .. Esc(e.name) .. ":" .. Num(e.coin))
		end
		if table.getn(tl) > 0 then table.insert(out, "T|" .. table.concat(tl, ",")) end

		local ll = {}
		for i = 1, table.getn(c.locks or {}) do
			local l = c.locks[i]
			table.insert(ll, Esc(l.n) .. ":" .. Num(l.id) .. ":" .. Num(l.e))
		end
		if table.getn(ll) > 0 then table.insert(out, "L|" .. table.concat(ll, ",")) end
		if c.locksSeen then table.insert(out, "O|" .. Num(c.locksSeen)) end

		local rl = {}
		for i = 1, table.getn(c.rep or {}) do
			local r = c.rep[i]
			table.insert(rl, Esc(r.n) .. ":" .. Num(r.s) .. ":" .. Num(r.v) .. ":" .. Num(r.m))
		end
		if table.getn(rl) > 0 then table.insert(out, "F|" .. table.concat(rl, ",")) end

		for id in pairs(c.bags or {}) do used[id] = true end
		for id in pairs(c.bank or {}) do used[id] = true end
		for _, id in pairs(c.gear or {}) do used[id] = true end
	end

	for id in pairs(used) do
		local it = S.db.items[id]
		if it and it.n then
			table.insert(out, "I|" .. Num(id) .. "|" .. Esc(it.n) .. "|" .. Esc(it.c) .. "|" .. Esc(it.t))
		end
	end

	for key, t in pairs(S.db.deleted) do
		table.insert(out, "X|" .. Esc(key) .. "|" .. Num(t))
	end
	if S.db.starAsked then table.insert(out, "A|1") end

	-- which cooldowns are switched off; the newest choice wins on every account
	if S.db.cdOffT then
		local names = {}
		for name in pairs(S.db.cdOff or {}) do table.insert(names, Esc(name)) end
		table.insert(out, "Q|" .. Num(S.db.cdOffT) .. "|" .. table.concat(names, ","))
	end

	-- cooldowns already announced, so other accounts don't announce them again
	local cutoff = time() - KEEP_ALERTED
	for id, t in pairs(S.db.alerted or {}) do
		if t >= cutoff then table.insert(out, "Y|" .. Esc(id) .. "|" .. Num(t)) end
	end

	return table.concat(out, "\n")
end

-------------------------------------------------------------------------------
-- Read: returns chars, items, tombstones. Anything malformed is skipped.
-------------------------------------------------------------------------------
local function ReadCounts(s)
	local t = {}
	for _, pair in ipairs(Split(s or "", ",")) do
		local kv = Split(pair, ":")
		local k, v = tonumber(kv[1]), tonumber(kv[2])
		if k and v then t[k] = v end
	end
	return t
end

function S.SyncParse(text)
	local chars, items, tombs = {}, {}, {}
	local flags = { alerted = {} }
	local cur

	if string.sub(text, 1, string.len(HEADER)) ~= HEADER then
		return nil, "not a SHAlts sync file"
	end

	for line in string.gfind(text, "[^\n]+") do
		line = string.gsub(line, "\r", "")
		local f = Split(line, "|")
		local tag = f[1]

		if tag == "C" and not (f[2] and f[2] ~= "" and f[3] and f[3] ~= "") then
			cur = nil   -- no key or no name: skip this character and the lines under it
		elseif tag == "C" then
			cur = {
				name = Unesc(f[3] or ""), realm = Unesc(f[4] or ""), class = Unesc(f[5] or ""),
				level = tonumber(f[6]) or 0, money = tonumber(f[7]) or 0,
				faction = Unesc(f[8] or ""), seen = tonumber(f[9]) or 0,
				bagUsed = tonumber(f[10]) or 0, bagTotal = tonumber(f[11]) or 0,
				bankUsed = tonumber(f[12]) or 0, bankTotal = tonumber(f[13]) or 0,
				bags = {}, bank = {}, gear = {}, skills = {}, recipes = {}, cd = {},
				mail = {}, rep = {}, pvp = {}, resets = {}, locks = {},
			}
			local bs = tonumber(f[14])
			if bs and bs > 0 then cur.bankSeen = bs end
			if cur.faction == "" then cur.faction = nil end
			chars[Unesc(f[2])] = cur
		elseif tag == "B" and cur then
			cur.bags = ReadCounts(f[2])
		elseif tag == "K" and cur then
			cur.bank = ReadCounts(f[2])
		elseif tag == "G" and cur then
			cur.gear = ReadCounts(f[2])
		elseif tag == "S" and cur then
			for _, part in ipairs(Split(f[2] or "", ",")) do
				local p = Split(part, ":")
				if p[1] and p[1] ~= "" then
					table.insert(cur.skills, { n = Unesc(p[1]), r = tonumber(p[2]) or 0, m = tonumber(p[3]) or 0 })
				end
			end
		elseif tag == "R" and cur and f[2] and f[2] ~= "" then
			local set = {}
			for _, rname in ipairs(Split(f[3] or "", ",")) do
				if rname ~= "" then set[Unesc(rname)] = true end
			end
			cur.recipes[Unesc(f[2])] = set
		elseif tag == "D" and cur then
			for _, part in ipairs(Split(f[2] or "", ",")) do
				local p = Split(part, ":")
				local t = tonumber(p[2])
				if p[1] and p[1] ~= "" and t then cur.cd[Unesc(p[1])] = t end
			end
		elseif tag == "M" and cur then
			for _, part in ipairs(Split(f[2] or "", ",")) do
				local p = Split(part, ":")
				if p[1] and p[1] ~= "" then
					local e = { n = Unesc(p[1]), c = tonumber(p[2]) or 1, t = Unesc(p[3] or ""), q = tonumber(p[4]) or 1 }
					if e.t == "" then e.t = nil end
					local id = tonumber(p[5])
					if id and id > 0 then e.id = id end
					table.insert(cur.mail, e)
				end
			end
		elseif tag == "E" and cur then
			cur.mailSeen = tonumber(f[2])
			cur.mailMoney = tonumber(f[3]) or 0
		elseif tag == "P" and cur then
			cur.played = tonumber(f[2])
			cur.playedAt = tonumber(f[3])
		elseif tag == "V" and cur then
			local pv = {}
			if f[2] and f[2] ~= "" then pv.rank = Unesc(f[2]) end
			pv.num = tonumber(f[3])
			pv.prog = (tonumber(f[4]) or 0) / 1000
			pv.hk, pv.dk, pv.week = tonumber(f[5]), tonumber(f[6]), tonumber(f[7])
			cur.pvp = pv
		elseif tag == "F" and cur then
			for _, part in ipairs(Split(f[2] or "", ",")) do
				local p = Split(part, ":")
				if p[1] and p[1] ~= "" then
					table.insert(cur.rep, { n = Unesc(p[1]), s = tonumber(p[2]) or 0, v = tonumber(p[3]) or 0, m = tonumber(p[4]) or 0 })
				end
			end
		elseif tag == "T" and cur then
			for _, part in ipairs(Split(f[2] or "", ",")) do
				local p = Split(part, ":")
				local t = tonumber(p[1])
				if t then
					local name = Unesc(p[2] or "")
					if name == "" then name = nil end
					table.insert(cur.resets, { t = t, name = name, coin = tonumber(p[3]) or 0 })
				end
			end
		elseif tag == "L" and cur then
			for _, part in ipairs(Split(f[2] or "", ",")) do
				local p = Split(part, ":")
				local e = tonumber(p[3])
				if p[1] and p[1] ~= "" and e then
					table.insert(cur.locks, { n = Unesc(p[1]), id = tonumber(p[2]) or 0, e = e })
				end
			end
		elseif tag == "O" and cur then
			cur.locksSeen = tonumber(f[2])
		elseif tag == "I" then
			local id = tonumber(f[2])
			if id and f[3] and f[3] ~= "" then
				local it = { n = Unesc(f[3]), c = Unesc(f[4] or "ffffffff") }
				local tex = Unesc(f[5] or "")
				if tex ~= "" then it.t = tex end
				items[id] = it
			end
		elseif tag == "X" and f[2] and tonumber(f[3]) then
			tombs[Unesc(f[2])] = tonumber(f[3])
		elseif tag == "A" and f[2] == "1" then
			flags.starAsked = true
		elseif tag == "Q" and tonumber(f[2]) then
			local set = {}
			for _, nm in ipairs(Split(f[3] or "", ",")) do
				if nm ~= "" then set[Unesc(nm)] = true end
			end
			flags.cdOff, flags.cdOffT = set, tonumber(f[2])
		elseif tag == "Y" and f[2] and f[2] ~= "" and tonumber(f[3]) then
			flags.alerted[Unesc(f[2])] = tonumber(f[3])
		end
	end
	return chars, items, tombs, flags
end

-------------------------------------------------------------------------------
-- Merge
-------------------------------------------------------------------------------
function S.SyncMerge(chars, items, tombs, flags)
	local db = S.db
	if flags and flags.starAsked then db.starAsked = true end
	if flags and flags.cdOffT and flags.cdOffT > (db.cdOffT or 0) then
		db.cdOff, db.cdOffT = flags.cdOff or {}, flags.cdOffT
	end
	if flags and flags.alerted then
		local cutoff = time() - KEEP_ALERTED
		for id, t in pairs(flags.alerted) do
			if t >= cutoff and (db.alerted[id] or 0) < t then db.alerted[id] = t end
		end
		for id, t in pairs(db.alerted) do
			if t < cutoff then db.alerted[id] = nil end
		end
	end
	local mine = S.CharKey()
	local added = 0

	for key, t in pairs(tombs) do
		if (db.deleted[key] or 0) < t then db.deleted[key] = t end
	end
	-- the character being played always wins, and is never "deleted"
	db.deleted[mine] = nil

	for key, c in pairs(chars) do
		local have = db.chars[key]
		local tomb = db.deleted[key]
		local removed = tomb and tomb >= (c.seen or 0)
		local empty = (c.level or 0) < 1 and have and (have.level or 0) > 0
		if key ~= mine and not removed and not empty and (not have or (have.seen or 0) < (c.seen or 0)) then
			db.chars[key] = c
			added = added + 1
		end
	end

	-- apply removals made on another account
	for key, t in pairs(db.deleted) do
		local have = db.chars[key]
		if have and key ~= mine and (have.seen or 0) <= t then db.chars[key] = nil end
	end

	for id, it in pairs(items) do
		if not db.items[id] then db.items[id] = it end
	end
	return added
end

-------------------------------------------------------------------------------
-- Sync
-------------------------------------------------------------------------------
local function Fail(err)
	lastError = tostring(err)
	if not S.syncWarned then
		S.syncWarned = true
		S.Print("sync problem: " .. lastError)
	end
end

-- read the shared file and merge it in
function S.SyncPull()
	if not S.db or not S.db.sync or not S.SyncAvailable() then return false end
	-- a missing file may raise an error instead of returning nil
	local ok, text = pcall(ImportFile, FILE)
	if not ok or type(text) ~= "string" or text == "" then return true end
	if text == lastText then return true end
	lastText = text
	local ok2, chars, items, tombs, flags = pcall(S.SyncParse, text)
	if not ok2 then Fail(chars); return false end
	if not chars then Fail(items); return false end
	local ok3, err = pcall(S.SyncMerge, chars, items, tombs, flags)
	if not ok3 then Fail(err); return false end
	lastError = nil
	-- another client brought in newer data: show it right away
	if err and err > 0 then S.UIChanged() end
	return true
end

-- merge, then write everything back
function S.Sync()
	if not S.db or not S.db.sync or not S.SyncAvailable() then return false end
	if not S.SyncPull() then return false end
	-- our own record is live, so it is current as of now; this is what makes
	-- other accounts take our newest data rather than an older copy
	local me = S.db.chars[S.CharKey()]
	if me and S.ready then me.seen = time() end
	local out = S.SyncSerialize()
	local ok, err = pcall(function() ExportFile(FILE, out) end)
	if not ok then Fail(err); return false end
	lastText = out
	S.lastSync = time()
	S.syncDirty = false
	S.UIChanged()
	return true
end

function S.SyncCommand(arg)
	if not S.SyncAvailable() then
		S.Print("sync needs SuperWoW (ImportFile/ExportFile were not found), so each account only sees its own alts")
		return
	end
	arg = string.lower(arg or "")
	if arg == "on" then S.db.sync = true elseif arg == "off" then S.db.sync = false end
	if not S.db.sync then
		S.Print("sync is off (/shalts sync on to turn it on)")
		return
	end
	local ok = S.Sync()
	local n = 0
	for _ in pairs(S.db.chars) do n = n + 1 end
	if ok then
		S.Print("synced, " .. n .. " characters (file: imports\\" .. FILE .. ")")
	else
		S.Print("sync failed: " .. tostring(lastError))
	end
end

-- write while the data keeps changing, never more often than PUSH_EVERY
local function Loop()
	if S.ready and S.syncDirty then S.Sync() end
	S.After(PUSH_EVERY, Loop)
end

-- Two clients running from the same game folder share the file, so a change
-- made by one shows up in the other within a few seconds. Skipped in combat,
-- and an unchanged file costs almost nothing (see lastText).
local function Poll()
	S.After(POLL_EVERY, Poll)
	if not S.ready or not S.db or not S.db.sync then return end
	if UnitAffectingCombat and UnitAffectingCombat("player") then return end
	S.SyncPull()
end

S.On("PLAYER_LOGIN", function()
	S.After(12, Poll)
	-- after the first scan (3s), so our own character is already current
	S.After(5, function()
		S.Sync()
		Loop()
	end)
end)

-- last write on the way out; pcall so a hiccup here can never error at logout
S.On("PLAYER_LOGOUT", function()
	if S.ready then
		-- no rescan here: while logging out the game reports empty bags and level 0.
		-- The data is already current from the events during play.
		pcall(S.Sync)
	end
end)
