-------------------------------------------------------------------------------
-- Server raid reset schedule: when each raid resets for everyone, so you know
-- when you can run it again. This is separate from your own saves and timers.
--
-- Each raid resets every N days from a known starting moment. The schedule and
-- the way daylight saving is handled keep the times matching the server.
-------------------------------------------------------------------------------
local S = SHAlts

S.Try("Raids.lua", function()

local DAY = 86400

-- seconds since 1970 for a calendar date and hour, read as UTC
local function UTC(y, m, d, h)
	if m <= 2 then y = y - 1 end
	local era = math.floor(y / 400)
	local yoe = y - era * 400
	local mp = math.mod(m + 9, 12)
	local doy = math.floor((153 * mp + 2) / 5) + d - 1
	local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
	return (era * 146097 + doe - 719468) * DAY + h * 3600
end
S.UTCSeconds = UTC

-- how often each reset timer repeats; raids that share a timer reset together
local GROUPS = { raid40 = 7, kara = 5, zg = 3, tmh = 7, eom = 14 }

-- every raid on its own line, with its size range where it is known
local RAIDS = {
	{ name = "Onyxia's Lair",        group = "raid40", size = "20-40" },
	{ name = "Molten Core",          group = "raid40", size = "20-40" },
	{ name = "Blackwing Lair",       group = "raid40", size = "20-40" },
	{ name = "Emerald Sanctum",      group = "raid40", size = "20-40" },
	{ name = "Temple of Ahn'Qiraj",  group = "raid40", size = "20-40" },
	{ name = "Naxxramas",            group = "raid40", size = "20-40" },
	{ name = "Upper Karazhan Halls", group = "raid40", size = "35-40" },
	{ name = "Ruins of Ahn'Qiraj",   group = "zg",     size = "12-20" },
	{ name = "Zul'Gurub",            group = "zg",     size = "12-20" },
	{ name = "Timbermaw Hold",       group = "tmh",    size = "12-20" },
	{ name = "Lower Karazhan Halls", group = "kara",   size = "10" },
	{ name = "Edge of Madness",      group = "eom" },
}

-- the Edge of Madness bosses, in the order they take turns
local EOM_BOSSES = { "Gri'lek", "Hazza'rah", "Renataki", "Wushoolay" }

-- the first reset of each cycle, per realm group
local SET_A = {
	raid40 = UTC(2026, 6, 17, 1),
	ony    = UTC(2026, 6, 17, 1),
	kara   = UTC(2026, 6, 17, 1),
	zg     = UTC(2025, 8, 30, 3),
	tmh    = UTC(2025, 8, 29, 3),
	eom    = UTC(2025, 4, 7, 23),
}
local SET_B = {
	raid40 = UTC(2026, 6, 17, 1),
	ony    = UTC(2025, 9, 1, 3),
	kara   = UTC(2025, 9, 2, 3),
	zg     = UTC(2025, 8, 30, 3),
	tmh    = UTC(2025, 8, 29, 3),
	eom    = UTC(2025, 4, 7, 23),
}
local REALMS = {
	["N'Zoth"] = SET_A, ["C'Thun"] = SET_A, ["Y'Shaarj"] = SET_A,
	["Nordanaar"] = SET_B, ["Ambershire"] = SET_B,
}

-- Returns a list of { id, name, sub, days, nextAt, prevAt } (real clock times,
-- in seconds), and true when this realm's schedule is a guess.
function S.RaidSchedule(now)
	now = now or time()
	local set = REALMS[GetRealmName() or ""]
	local assumed = false
	if not set then set = SET_A; assumed = true end

	-- outside daylight saving the clock is an hour behind
	local t = date("*t", now)
	local shift = 0
	if not (t and t.isdst) then shift = 3600 end
	local serverNow = now - shift

	-- work out each timer once, then give every raid its timer's times
	local times = {}
	for group, days in pairs(GROUPS) do
		local anchor = set[group]
		local interval = days * DAY
		local cycles = math.floor((serverNow - anchor) / interval)
		local prev = anchor + cycles * interval
		times[group] = { days = days, nextAt = prev + interval + shift, prevAt = prev + shift }
	end

	-- Edge of Madness: the boss in play changes every 14 days, cycling through four
	local sday = math.floor(serverNow / DAY)
	local boss = EOM_BOSSES[math.mod(math.floor((sday + 2) / 14), 4) + 1]

	local out = {}
	for i = 1, table.getn(RAIDS) do
		local r = RAIDS[i]
		local t = times[r.group]
		table.insert(out, {
			name = r.name, size = r.size, group = r.group, days = t.days,
			nextAt = t.nextAt, prevAt = t.prevAt,
			boss = (r.group == "eom") and boss or nil,
		})
	end
	return out, assumed
end

end)
