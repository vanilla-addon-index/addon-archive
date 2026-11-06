-------------------------------------------------------------------------------
-- SHAlts data views: turn stored characters into lines the window can show.
-- A line is { text, right, icon, id, header }.
-------------------------------------------------------------------------------
local S = SHAlts

local MAX_LINES = 400
local INDENT = "    "

local SLOT_NAMES = {
	"Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist",
	"Hands", "Finger", "Finger", "Trinket", "Trinket", "Back", "Main Hand",
	"Off Hand", "Ranged", "Tabard",
}

-------------------------------------------------------------------------------
-- Characters
-------------------------------------------------------------------------------
-- { { key = "Name-Realm", c = record }, ... } in display order
function S.SortedChars()
	local list = {}
	for key, c in pairs(S.db.chars) do
		table.insert(list, { key = key, c = c })
	end
	local byLevel = (S.db.sort == "level")
	table.sort(list, function(a, b)
		local al, bl = a.c.level or 0, b.c.level or 0
		if byLevel and al ~= bl then return al > bl end
		local an = string.lower(a.c.name or a.key)
		local bn = string.lower(b.c.name or b.key)
		if an ~= bn then return an < bn end
		return a.key < b.key
	end)
	return list
end

function S.TotalGold()
	local total, n = 0, 0
	for _, c in pairs(S.db.chars) do
		total = total + (c.money or 0)
		n = n + 1
	end
	return total, n
end

local function ItemInfo(id)
	local it = S.db.items[id]
	if it then return it.n or ("item:" .. id), it.c or "ffffffff", it.t end
	return "item:" .. id, "ffffffff", nil
end

local function ByName(a, b)
	local x, y = string.lower(a.name), string.lower(b.name)
	if x ~= y then return x < y end
	return a.id < b.id
end

-- append one line per item, sorted by name
local function ItemLines(lines, counts)
	local arr = {}
	for id, n in pairs(counts or {}) do
		local name, color, tex = ItemInfo(id)
		table.insert(arr, { id = id, n = n, name = name, color = color, tex = tex })
	end
	table.sort(arr, ByName)
	for i = 1, table.getn(arr) do
		local e = arr[i]
		local right = ""
		if e.n > 1 then right = "x" .. e.n end
		table.insert(lines, {
			icon = e.tex, id = e.id, right = right,
			text = "|c" .. e.color .. e.name .. "|r",
		})
	end
end

local function Header(text, right)
	return { text = text, right = right or "", header = true }
end

local function Note(text)
	return { text = "|cff888888" .. text .. "|r", right = "" }
end

-------------------------------------------------------------------------------
-- Per-character tabs
-------------------------------------------------------------------------------
local function BagLines(c)
	local lines = {}
	table.insert(lines, Header("Bags", (c.bagUsed or 0) .. " / " .. (c.bagTotal or 0) .. " slots"))
	ItemLines(lines, c.bags)
	return lines
end

local function BankLines(c)
	local lines = {}
	if not c.bankSeen then
		table.insert(lines, Note("Open this character's bank once to record it."))
		return lines
	end
	table.insert(lines, Header("Bank", (c.bankUsed or 0) .. " / " .. (c.bankTotal or 0) .. " slots"))
	ItemLines(lines, c.bank)
	table.insert(lines, Note("Last seen " .. date("%Y-%m-%d", c.bankSeen)))
	return lines
end

local function ProfLines(c)
	local lines = {}
	local skills = c.skills or {}
	if table.getn(skills) == 0 then
		table.insert(lines, Note("No professions recorded."))
		return lines
	end
	for i = 1, table.getn(skills) do
		local sk = skills[i]
		table.insert(lines, Header(sk.n, sk.r .. " / " .. sk.m))
		local set = c.recipes and c.recipes[sk.n]
		if set and next(set) then
			local names = {}
			for rname in pairs(set) do table.insert(names, rname) end
			table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)
			for j = 1, table.getn(names) do
				table.insert(lines, { text = INDENT .. names[j], right = "" })
			end
		else
			table.insert(lines, Note(INDENT .. "Open the profession window to record recipes."))
		end
	end
	return lines
end

local function GearLines(c)
	local lines = {}
	local any = false
	for slot = 1, 19 do
		local id = c.gear and c.gear[slot]
		if id then
			any = true
			local name, color, tex = ItemInfo(id)
			table.insert(lines, {
				icon = tex, id = id,
				text = "|c" .. color .. name .. "|r",
				right = "|cff888888" .. SLOT_NAMES[slot] .. "|r",
			})
		end
	end
	if not any then table.insert(lines, Note("No equipment recorded.")) end
	return lines
end

-------------------------------------------------------------------------------
-- Mail, character info
-------------------------------------------------------------------------------
local function MailLines(c)
	local lines = {}
	if not c.mailSeen then
		table.insert(lines, Note("Visit a mailbox with this character to record its mail."))
		return lines
	end
	local items = c.mail or {}
	table.insert(lines, Header("Mailbox", table.getn(items) .. " stacks"))
	if (c.mailMoney or 0) > 0 then
		table.insert(lines, { text = "Money waiting", right = S.FormatMoney(c.mailMoney) })
	end
	local arr = {}
	for i = 1, table.getn(items) do table.insert(arr, items[i]) end
	table.sort(arr, function(a, b)
		local x, y = string.lower(a.n or ""), string.lower(b.n or "")
		if x ~= y then return x < y end
		return (a.id or 0) < (b.id or 0)
	end)
	for i = 1, table.getn(arr) do
		local e = arr[i]
		local color = S.QualityColor(e.q)
		local right = ""
		if (e.c or 1) > 1 then right = "x" .. e.c end
		local line = { icon = e.t, id = e.id, right = right, text = "|c" .. color .. e.n .. "|r" }
		if not e.id then line.tip = { "|c" .. color .. e.n .. "|r", "|cffaaaaaaIn the mailbox|r" } end
		table.insert(lines, line)
	end
	if table.getn(arr) == 0 then table.insert(lines, Note("The mailbox was empty.")) end
	table.insert(lines, Note("Last seen " .. date("%Y-%m-%d", c.mailSeen)))
	return lines
end

local STANDING = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
local STANDING_COLOR = { "ff4040", "ff4040", "ff8040", "ffff00", "40ff40", "40ff40", "40ffa0", "40e0ff" }

local function FormatPlayed(sec)
	sec = math.floor(sec or 0)
	local d = math.floor(sec / 86400)
	local h = math.floor(math.mod(sec, 86400) / 3600)
	local m = math.floor(math.mod(sec, 3600) / 60)
	if d > 0 then return d .. "d " .. h .. "h" end
	if h > 0 then return h .. "h " .. m .. "m" end
	return m .. "m"
end

local function InfoLines(c)
	local lines = {}

	table.insert(lines, Header("Character"))
	if c.played then
		table.insert(lines, { text = "Time played", right = FormatPlayed(c.played) })
	else
		table.insert(lines, { text = "Time played", right = "|cff888888not recorded yet|r" })
	end
	if c.seen and c.seen > 0 then
		table.insert(lines, { text = "Last seen", right = date("%Y-%m-%d %H:%M", c.seen) })
	end

	local pv = c.pvp or {}
	table.insert(lines, Header("PvP"))
	if pv.rank then
		local prog = ""
		if pv.prog then prog = "  |cffaaaaaa" .. math.floor(pv.prog * 100 + .5) .. "%|r" end
		table.insert(lines, { text = "Rank", right = pv.rank .. prog })
	else
		table.insert(lines, { text = "Rank", right = "|cff888888none|r" })
	end
	if pv.hk then table.insert(lines, { text = "Lifetime honorable kills", right = tostring(pv.hk) }) end
	if pv.week then table.insert(lines, { text = "Honor this week", right = tostring(pv.week) }) end

	table.insert(lines, Header("Reputation"))
	local rep = c.rep or {}
	if table.getn(rep) == 0 then
		table.insert(lines, Note("Not recorded yet."))
	end
	for i = 1, table.getn(rep) do
		local r = rep[i]
		if r.s == 0 then
			table.insert(lines, { text = "|cffffd100" .. r.n .. "|r", right = "" })
		else
			local name = STANDING[r.s] or "?"
			local color = STANDING_COLOR[r.s] or "ffffff"
			local right = "|cff" .. color .. name .. "|r"
			if r.s < 8 and r.m > 0 then right = right .. " |cffaaaaaa" .. r.v .. "/" .. r.m .. "|r" end
			table.insert(lines, {
				text = INDENT .. r.n, right = right,
				tip = { r.n, "|cff" .. color .. name .. "|r", r.v .. " / " .. r.m },
			})
		end
	end
	return lines
end

-------------------------------------------------------------------------------
-- IRC tab: instance reset timers and raid lockouts
-------------------------------------------------------------------------------
local function LockTip(c)
	local tip = { S.ColoredName(c) }
	local locks = S.LockView(c)
	for i = 1, table.getn(locks) do
		table.insert(tip, locks[i].n .. "  |cffaaaaaa" .. S.FormatDuration(locks[i].e - time()) .. "|r")
	end
	if table.getn(locks) == 0 then
		if c.locksSeen then
			table.insert(tip, "|cff40ff40Not locked to any raid|r")
		else
			table.insert(tip, "|cff888888Log in on this character to record its lockouts|r")
		end
	end
	return tip
end

local function IRCLines(c, key)
	local lines = {}
	local now = time()
	local view = S.ResetView(c)
	table.insert(lines, Header("Instance resets", table.getn(view) .. " / " .. S.MAX_RESETS .. " used"))

	local total = 0
	for i = 1, S.MAX_RESETS do
		local e = view[i]
		if e then
			local rem = S.RESET_DURATION - (now - e.t)
			total = total + (e.coin or 0)
			table.insert(lines, {
				text = "|cffffffffReset " .. i .. "|r   |cff33ff99" .. S.FormatClock(rem) .. "|r",
				right = S.MoneyGSC(e.coin),
				tip = { e.name or "Instance reset", "Frees up in " .. S.FormatClock(rem), "Coin looted: " .. S.MoneyGSC(e.coin) },
			})
		else
			table.insert(lines, { text = "|cff777777Reset " .. i .. "   cleared|r", right = "" })
		end
	end
	table.insert(lines, { text = "|cffffd100Lockout total|r", right = S.MoneyGSC(total) })

	-- the game only lets you reset instances for the character you are playing
	if key == S.CharKey() then
		table.insert(lines, {
			text = "|cffffd100Reset instances|r", right = "|cff888888click|r", action = function() S.DoDungeonReset() end,
			tip = { "Reset instances", "Asks the game to reset your dungeons and raids.", "A timer starts only if the game confirms it." },
		})
		table.insert(lines, {
			text = "|cffffd100Reset all timers|r", right = "|cff888888click|r", action = function() S.ResetAllTimers() end,
			tip = { "Reset all timers", "Clears the five timers for this character." },
		})
	else
		table.insert(lines, Note("Select the character you are playing to reset instances."))
	end

	local locks = S.LockView(c)
	local right = "|cff40ff40free|r"
	if table.getn(locks) > 0 then right = "|cffff6060" .. table.getn(locks) .. " locked|r" end
	table.insert(lines, Header("Raid lockouts", right))
	for i = 1, table.getn(locks) do
		table.insert(lines, {
			text = locks[i].n, right = S.FormatDuration(locks[i].e - now),
			tip = { locks[i].n, "Resets in " .. S.FormatDuration(locks[i].e - now), "|cffaaaaaa" .. date("%Y-%m-%d %H:%M", locks[i].e) .. "|r" },
		})
	end
	if table.getn(locks) == 0 then
		if c.locksSeen then
			table.insert(lines, Note("Not locked to any raid."))
		else
			table.insert(lines, Note("Log in on this character to record its lockouts."))
		end
	end

	-- everyone at a glance
	table.insert(lines, Header("All characters"))
	local chars = S.SortedChars()
	for i = 1, table.getn(chars) do
		local e = chars[i]
		local n = table.getn(S.LockView(e.c))
		local r
		if not e.c.locksSeen then
			r = "|cff888888unknown|r"
		elseif n > 0 then
			r = "|cffff6060" .. n .. " locked|r"
		else
			r = "|cff40ff40free|r"
		end
		table.insert(lines, { text = S.ColoredName(e.c), right = r, tip = LockTip(e.c) })
	end
	return lines
end

-------------------------------------------------------------------------------
-- Cooldowns (all characters)
-------------------------------------------------------------------------------
local TIMER_PREFIX = "Timer: "

-- the cooldowns this addon knows about, so they can be switched off before they ever show up
local KNOWN_CDS = {
	"Salt Shaker", "Mooncloth", "Shadowcloth", "Spellcloth",
	"Transmute: Arcanite", "Transmute: Iron to Gold", "Transmute: Mithril to Truesilver",
	"Transmute: Air to Fire", "Transmute: Earth to Water", "Transmute: Fire to Earth", "Transmute: Water to Air",
	"Transmute: Life to Earth", "Transmute: Earth to Life", "Transmute: Undeath to Water", "Transmute: Water to Undeath",
	"Transmute: Elemental Fire",
}

function S.IsCustomTimer(name)
	return name ~= nil and string.sub(name, 1, string.len(TIMER_PREFIX)) == TIMER_PREFIX
end

-- custom timers are always shown; everything else can be switched off
function S.CdTracked(name)
	if S.IsCustomTimer(name) then return true end
	return not (S.db.cdOff and S.db.cdOff[name])
end

function S.SetCdTracked(name, on)
	if not S.db.cdOff then S.db.cdOff = {} end
	if on then S.db.cdOff[name] = nil else S.db.cdOff[name] = true end
	S.db.cdOffT = math.floor(time())
	S.DataChanged()
end

-- every cooldown name that can be switched on or off: the known ones plus anything seen on any alt
function S.CooldownNames()
	local set = {}
	for i = 1, table.getn(KNOWN_CDS) do set[KNOWN_CDS[i]] = true end
	for _, c in pairs(S.db.chars) do
		for name in pairs(c.cd or {}) do
			if not S.IsCustomTimer(name) then set[name] = true end
		end
	end
	for name in pairs(S.db.cdOff or {}) do set[name] = true end
	local out = {}
	for name in pairs(set) do table.insert(out, name) end
	table.sort(out, function(a, b) return string.lower(a) < string.lower(b) end)
	return out
end

-- "1d 12h", "90m", "2h30m" -> seconds, or nil and a reason
function S.ParseDuration(text)
	text = string.lower(text or "")
	local total, used = 0, 0
	for n, unit in string.gfind(text, "(%d+)%s*([dhms])") do
		local v = tonumber(n)
		if unit == "d" then total = total + v * 86400
		elseif unit == "h" then total = total + v * 3600
		elseif unit == "m" then total = total + v * 60
		else total = total + v end
		used = used + 1
	end
	local rest = string.gsub(text, "%d+%s*[dhms]", "")
	rest = string.gsub(rest, "[%s,]", "")
	if used == 0 or rest ~= "" then return nil, "Type a time like 24h, 2d, 90m or 1d12h." end
	if total < 1 then return nil, "That time is too short." end
	if total > 365 * 86400 then return nil, "That is more than a year." end
	return total
end

-- start a custom timer on the character being played
function S.AddTimer(name, timeText)
	name = string.gsub(name or "", "[|%c]", "")
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	if name == "" then return nil, "Type a name for the timer." end
	if string.len(name) > 30 then name = string.sub(name, 1, 30) end
	local secs, why = S.ParseDuration(timeText)
	if not secs then return nil, why end
	local c = S.GetChar()
	c.cd[TIMER_PREFIX .. name] = math.floor(time()) + secs
	S.DataChanged()
	return true, name, secs
end

function S.RemoveTimer(key)
	local c = S.GetChar()
	if c.cd[key] then
		c.cd[key] = nil
		S.DataChanged()
	end
end

-- finished custom timers are tidied away a day after they ran out
function S.PruneTimers()
	local c = S.db and S.db.chars[S.CharKey()]
	if not c or not c.cd then return end
	local cutoff = time() - 86400
	local changed = false
	for name, endsAt in pairs(c.cd) do
		if S.IsCustomTimer(name) and endsAt < cutoff then
			c.cd[name] = nil
			changed = true
		end
	end
	if changed then S.DataChanged() end
end

local function CooldownRows()
	local rows = {}
	local now = time()
	local chars = S.SortedChars()
	for i = 1, table.getn(chars) do
		local e = chars[i]
		for name, endsAt in pairs(e.c.cd or {}) do
			if S.CdTracked(name) then
				table.insert(rows, { c = e.c, name = name, left = endsAt - now })
			end
		end
	end
	table.sort(rows, function(a, b)
		if a.left ~= b.left then return a.left < b.left end
		if a.name ~= b.name then return a.name < b.name end
		return (a.c.name or "") < (b.c.name or "")
	end)
	return rows
end

local function GoTab(tab)
	if S.UI and S.UI.ShowTab then S.UI.ShowTab(tab) end
end

local function CooldownLines()
	local lines = {}
	table.insert(lines, {
		text = "|cffffd100Choose cooldowns and timers...|r", right = "|cff888888click|r",
		action = function() GoTab("track") end,
		tip = { "Choose cooldowns and timers", "Pick which profession cooldowns are shown,", "and see or remove your custom timers." },
	})
	local rows = CooldownRows()
	for i = 1, table.getn(rows) do
		local r = rows[i]
		local right
		if r.left <= 0 then right = "|cff40ff40Ready|r" else right = S.FormatDuration(r.left) end
		local tip
		if r.left <= 0 then
			tip = { S.ColoredName(r.c) .. ": " .. r.name, "|cff40ff40Ready|r" }
		else
			tip = { S.ColoredName(r.c) .. ": " .. r.name, "Ready in " .. S.FormatDuration(r.left), "|cffaaaaaa" .. date("%Y-%m-%d %H:%M", r.c.cd[r.name]) .. "|r" }
		end
		table.insert(lines, { text = S.ColoredName(r.c) .. "  " .. r.name, right = right, tip = tip })
	end
	if table.getn(rows) == 0 then
		table.insert(lines, Note("No cooldowns recorded yet."))
	end
	table.insert(lines, Note("Salt Shaker is tracked while it is in your bags."))
	return lines
end

-- the "choose cooldowns and timers" view
local function TrackLines()
	local lines = {}
	table.insert(lines, {
		text = "|cffffd100< Back to settings|r", right = "",
		action = function() GoTab("settings") end,
	})

	table.insert(lines, Header("Custom timers"))
	local mine = S.db.chars[S.CharKey()]
	local keys = {}
	for name in pairs((mine and mine.cd) or {}) do
		if S.IsCustomTimer(name) then table.insert(keys, name) end
	end
	table.sort(keys, function(a, b) return mine.cd[a] < mine.cd[b] end)
	local now = time()
	for i = 1, table.getn(keys) do
		local key = keys[i]
		local left = mine.cd[key] - now
		local right
		if left <= 0 then right = "|cff40ff40Ready|r" else right = S.FormatDuration(left) end
		table.insert(lines, {
			text = string.sub(key, string.len(TIMER_PREFIX) + 1), right = right,
			action = function() S.RemoveTimer(key) end,
			tip = { key, "Click to remove this timer.", "|cffaaaaaaOther characters see it too.|r" },
		})
	end
	if table.getn(keys) == 0 then
		table.insert(lines, Note("None yet. Add one in Settings, under Custom timer."))
	end

	table.insert(lines, Header("Cooldowns to track", "click to switch"))
	table.insert(lines, {
		text = "|cffaaaaaaTrack all|r", right = "",
		action = function()
			S.db.cdOff = {}
			S.db.cdOffT = math.floor(time())
			S.DataChanged()
		end,
	})
	local names = S.CooldownNames()
	for i = 1, table.getn(names) do
		local name = names[i]
		local on = S.CdTracked(name)
		table.insert(lines, {
			text = name,
			right = on and "|cff40ff40tracked|r" or "|cff888888hidden|r",
			action = function() S.SetCdTracked(name, not S.CdTracked(name)) end,
			tip = { name, on and "Shown on the Cooldowns tab, in alerts and on the minimap." or "Hidden everywhere.", "Click to switch." },
		})
	end
	table.insert(lines, Note("Hiding a cooldown only changes what you see. Nothing is lost."))
	return lines
end

-- "Name: Salt Shaker 2h 5m" for the chat command
function S.CooldownReport()
	local out = {}
	local rows = CooldownRows()
	for i = 1, table.getn(rows) do
		local r = rows[i]
		table.insert(out, S.ColoredName(r.c) .. ": " .. r.name .. " - " .. S.FormatDuration(r.left))
	end
	return out
end

-- "Name (Salt Shaker)" for every cooldown that is ready
function S.ReadyList()
	local out = {}
	local rows = CooldownRows()
	for i = 1, table.getn(rows) do
		local r = rows[i]
		if r.left <= 0 then table.insert(out, S.ColoredName(r.c) .. " (" .. r.name .. ")") end
	end
	return out
end

-------------------------------------------------------------------------------
-- Raids tab: when the server resets each raid, and who is saved to what
-------------------------------------------------------------------------------
local function StampText(t)
	return date("%a %b %d, %I:%M %p", t)
end

local function RaidsLines(key)
	local lines = {}
	local now = time()

	local sched, assumed = S.RaidSchedule(now)
	table.insert(lines, Header("Server raid resets", "resets in"))
	for i = 1, table.getn(sched) do
		local r = sched[i]
		local left = r.nextAt - now
		local label = r.name
		local tip = { r.name }
		if r.size then
			label = label .. "  |cff888888(" .. r.size .. ")|r"
			table.insert(tip, "Raid size " .. r.size .. " players")
		end
		if r.boss then
			label = label .. "  |cff888888(" .. r.boss .. ")|r"
			table.insert(tip, "Boss this cycle: " .. r.boss)
		end
		table.insert(tip, "Resets every " .. r.days .. " days")
		table.insert(tip, "Next: " .. StampText(r.nextAt))
		table.insert(tip, "|cffaaaaaaLast: " .. StampText(r.prevAt) .. "|r")
		table.insert(lines, { text = label, right = S.FormatDuration(left), tip = tip })
	end
	if assumed then
		table.insert(lines, Note("This realm's schedule is a guess based on N'Zoth."))
	end

	-- the raids the character picked in the dropdown is saved to
	local c = key and S.db.chars[key]
	if not c then
		table.insert(lines, Header("Saved to raids", ""))
		table.insert(lines, Note("No character selected."))
		return lines
	end
	local locks = {}
	if c.locksSeen then locks = S.LockView(c) end
	table.sort(locks, function(a, b) return a.e < b.e end)

	table.insert(lines, Header("Saved to raids", S.ColoredName(c)))
	for j = 1, table.getn(locks) do
		local l = locks[j]
		local tip = { S.ColoredName(c) .. ": " .. l.n, "Resets in " .. S.FormatDuration(l.e - now), "|cffaaaaaa" .. StampText(l.e) .. "|r" }
		if l.id and l.id > 0 then table.insert(tip, "|cffaaaaaaInstance ID " .. l.id .. "|r") end
		table.insert(lines, { text = "|cffffd100" .. l.n .. "|r", right = S.FormatDuration(l.e - now), tip = tip })
	end
	if not c.locksSeen then
		table.insert(lines, Note("Not recorded yet. Log in on this character once."))
	elseif table.getn(locks) == 0 then
		table.insert(lines, Note("Not saved to any raid."))
	end
	return lines
end

-------------------------------------------------------------------------------
-- Search (all characters, items and recipes)
-------------------------------------------------------------------------------
local function Hit(hits, id, e, field, n)
	local h = hits[id]
	if not h then
		h = { id = id, total = 0, per = {} }
		hits[id] = h
	end
	local p = h.per[e.key]
	if not p then
		p = { bags = 0, bank = 0, worn = 0 }
		h.per[e.key] = p
	end
	p[field] = p[field] + n
	h.total = h.total + n
end

local function NameMatches(id, q)
	local it = S.db.items[id]
	return it and it.n and string.find(string.lower(it.n), q, 1, true)
end

function S.SearchLines(text)
	local q = string.lower(text)
	local lines = {}
	local chars = S.SortedChars()
	local hits = {}

	for i = 1, table.getn(chars) do
		local e = chars[i]
		for id, n in pairs(e.c.bags or {}) do
			if NameMatches(id, q) then Hit(hits, id, e, "bags", n) end
		end
		for id, n in pairs(e.c.bank or {}) do
			if NameMatches(id, q) then Hit(hits, id, e, "bank", n) end
		end
		for _, id in pairs(e.c.gear or {}) do
			if NameMatches(id, q) then Hit(hits, id, e, "worn", 1) end
		end
	end

	local arr = {}
	for id, h in pairs(hits) do
		local name, color, tex = ItemInfo(id)
		table.insert(arr, { id = id, name = name, color = color, tex = tex, h = h })
	end
	table.sort(arr, ByName)

	if table.getn(arr) > 0 then table.insert(lines, Header("Items")) end
	for i = 1, table.getn(arr) do
		local a = arr[i]
		table.insert(lines, {
			icon = a.tex, id = a.id,
			text = "|c" .. a.color .. a.name .. "|r",
			right = "x" .. a.h.total,
		})
		for j = 1, table.getn(chars) do
			local e = chars[j]
			local p = a.h.per[e.key]
			if p then
				local parts = {}
				if p.bags > 0 then table.insert(parts, "bags " .. p.bags) end
				if p.bank > 0 then table.insert(parts, "bank " .. p.bank) end
				if p.worn > 0 then table.insert(parts, "worn") end
				table.insert(lines, {
					text = INDENT .. S.ColoredName(e.c),
					right = "|cffaaaaaa" .. table.concat(parts, ", ") .. "|r",
				})
			end
		end
		if table.getn(lines) >= MAX_LINES then break end
	end

	-- recipes
	local rec = {}
	for i = 1, table.getn(chars) do
		local e = chars[i]
		for prof, set in pairs(e.c.recipes or {}) do
			for rname in pairs(set) do
				if string.find(string.lower(rname), q, 1, true) then
					table.insert(rec, { name = rname, prof = prof, c = e.c })
				end
			end
		end
	end
	table.sort(rec, function(a, b)
		local x, y = string.lower(a.name), string.lower(b.name)
		if x ~= y then return x < y end
		return (a.c.name or "") < (b.c.name or "")
	end)
	if table.getn(rec) > 0 then table.insert(lines, Header("Recipes")) end
	for i = 1, table.getn(rec) do
		if table.getn(lines) >= MAX_LINES then break end
		local r = rec[i]
		table.insert(lines, {
			text = r.name .. " |cff888888(" .. r.prof .. ")|r",
			right = S.ColoredName(r.c),
		})
	end

	if table.getn(lines) == 0 then
		table.insert(lines, Note("No matches for \"" .. text .. "\"."))
	elseif table.getn(lines) >= MAX_LINES then
		table.insert(lines, Note("Too many results, showing the first " .. MAX_LINES .. "."))
	end
	return lines
end

-------------------------------------------------------------------------------
-- Entry point for the window
-------------------------------------------------------------------------------
-- tab: "bags" | "bank" | "mail" | "profs" | "gear" | "cd" | "raids" | "irc" | "info" | "settings" | "track"
function S.BuildLines(tab, key, searchText)
	if searchText and searchText ~= "" then return S.SearchLines(searchText) end
	if tab == "cd" then return CooldownLines() end
	if tab == "raids" then return RaidsLines(key) end
	if tab == "track" then return TrackLines() end
	if tab == "settings" then return {} end

	local c = key and S.db.chars[key]
	if not c then return { Note("No character selected.") } end

	local head = {
		text = S.ColoredName(c) .. "  |cffaaaaaaLevel " .. (c.level or "?") .. " " .. S.ClassName(c.class) .. "|r",
		right = S.FormatMoney(c.money),
		header = true,
	}
	local body
	if tab == "bank" then body = BankLines(c)
	elseif tab == "profs" then body = ProfLines(c)
	elseif tab == "gear" then body = GearLines(c)
	elseif tab == "mail" then body = MailLines(c)
	elseif tab == "info" then body = InfoLines(c)
	elseif tab == "irc" then body = IRCLines(c, key)
	else body = BagLines(c) end

	local lines = { head }
	for i = 1, table.getn(body) do table.insert(lines, body[i]) end
	return lines
end
