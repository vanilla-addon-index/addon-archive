-- HonorHistory: honor log
-- WoW 1.12 / Lua 5.0 — no string.match, 32-upvalue-per-function limit

local WIN_W = 420
local WIN_H = 400
local ROW_H = 14
local DATESEP_H = 18  -- day separator row height
local WEEKSEP_H = 22  -- week separator (highest hierarchy)
local GROUP_GAP_SEC = 300
local BG_FINISH_GRACE = 10   -- seconds: bonus awards arriving after bgresult still belong to same game
local BG_SESSION_GAP = 7200  -- seconds: max gap between entries in one sealed BG game (2h covers long AV)
local MAX_ENTRIES   = 20000
local FONT = "Fonts\\FRIZQT__.TTF"
local TIP_W = 220

-- ===== BG zone tables =====
local _IsBG = {
	["Warsong Gulch"] = true,
	["Arathi Basin"]  = true,
	["Alterac Valley"]= true,
	["Thorn Gorge"]   = true,
	["Blood Ring"]    = true,
}

local _ZONE_ABBR    = THSE.ZONE_ABBR
local _BG_MARK_ICON = THSE.BG_MARK_ICON
local GetDailyBG    = THSE.GetDailyBG

-- Return the daily BG for a local calendar day by snapping to local noon.
-- Avoids the UTC/local mismatch in the hours between local and UTC midnight.
local function DailyBGForDay(t)
	local h = tonumber(date("%H", t)) or 12
	local m = tonumber(date("%M", t)) or 0
	local s = tonumber(date("%S", t)) or 0
	return GetDailyBG(t - (h * 3600 + m * 60 + s) + 43200)
end

local function IsBGZone(zone)
	return zone and _IsBG[zone] == true
end

-- Reverse lookup: rank number → rank name (by faction)
local _NUM_TO_RANK_ALLIANCE = {
	[1]="Private", [2]="Corporal", [3]="Sergeant", [4]="Master Sergeant",
	[5]="Sergeant Major", [6]="Knight", [7]="Knight-Lieutenant", [8]="Knight-Captain",
	[9]="Knight-Champion", [10]="Lieutenant Commander", [11]="Commander",
	[12]="Marshal", [13]="Field Marshal", [14]="Grand Marshal",
}
local _NUM_TO_RANK_HORDE = {
	[1]="Scout", [2]="Grunt", [3]="Sergeant", [4]="Senior Sergeant",
	[5]="First Sergeant", [6]="Stone Guard", [7]="Blood Guard", [8]="Legionnaire",
	[9]="Centurion", [10]="Champion", [11]="Lieutenant General",
	[12]="General", [13]="Warlord", [14]="High Warlord",
}

-- Look up a player's rank name from the BG scoreboard (returns nil outside BGs)
-- Uses a persistent cache refreshed on UPDATE_BATTLEFIELD_SCORE events.
local _bgScoreRank = {}  -- name -> rankName

local function RefreshBGScoreCache()
	if type(GetNumBattlefieldScores) ~= "function" then return end
	local n = GetNumBattlefieldScores()
	for i = 1, n do
		local name, _, _, _, _, faction, rank = GetBattlefieldScore(i)
		if name and type(rank) == "number" and rank > 0 then
			local tbl = (faction == 1) and _NUM_TO_RANK_ALLIANCE or _NUM_TO_RANK_HORDE
			local rankName = tbl[rank]
			-- Extended ranks (15+): use GetPVPRankInfo API
			if not rankName and GetPVPRankInfo then
				rankName = GetPVPRankInfo(rank)
			end
			if rankName then
				_bgScoreRank[name] = rankName
				local short = string.gsub(name, "%-.*", "")
				if short ~= name then _bgScoreRank[short] = rankName end
			end
		end
	end
end

local function ScoreboardRank(playerName)
	if not playerName then return nil end
	local short = string.gsub(playerName, "%-.*", "")
	if not (_bgScoreRank[playerName] or _bgScoreRank[short]) then
		-- Cache miss — do an immediate synchronous refresh in case data is available
		RefreshBGScoreCache()
	end
	if not (_bgScoreRank[playerName] or _bgScoreRank[short]) and RequestBattlefieldScoreData then
		-- Still nil — request fresh data from server for next lookup
		RequestBattlefieldScoreData()
	end
	return _bgScoreRank[playerName] or _bgScoreRank[short]
end

-- Quests that turn in marks from all three main BGs simultaneously
local _CONCERTED_QUEST = {
	["Concerted Efforts"] = true,  -- Alliance
	["For Great Honor"]   = true,  -- Horde
}

-- ===== Rank lookup =====
local _RANK_TO_NUM = {
	["private"]=1,         ["scout"]=1,
	["corporal"]=2,        ["grunt"]=2,
	["sergeant"]=3,        ["sergeant"]=3,
	["master sergeant"]=4, ["senior sergeant"]=4,
	["sergeant major"]=5,  ["first sergeant"]=5,
	["knight"]=6,          ["stone guard"]=6,
	["knight-lieutenant"]=7, ["blood guard"]=7,
	["knight-captain"]=8,  ["legionnaire"]=8,
	["knight-champion"]=9, ["centurion"]=9,
	["lieutenant commander"]=10, ["champion"]=10,
	["commander"]=11,      ["lieutenant general"]=11,
	["marshal"]=12,        ["general"]=12,
	["field marshal"]=13,  ["warlord"]=13,
	["grand marshal"]=14,  ["high warlord"]=14,
}

local function GetRankNum(rankName)
	if not rankName then return 0 end
	return _RANK_TO_NUM[string.lower(rankName)] or 0
end

-- ===== Formatters =====
local function FmtHonor(n)
	n = math.floor(n or 0)
	if n >= 1000 then
		return string.format("%d,%03d", math.floor(n / 1000), n - math.floor(n / 1000) * 1000)
	end
	return tostring(n)
end

local function FmtTime(t)
	return date("%H:%M", t)
end

local function FmtDuration(sec)
	local h = math.floor(sec / 3600)
	local m = math.floor(math.mod(sec, 3600) / 60)
	if h > 0 then return h .. "h " .. m .. "m" end
	return m .. "m"
end

local function FmtDate(t)
	return date("%a %d %b", t)
end

local function FmtDateLabel(dayStr)
	local dayAbbr = string.sub(dayStr, 1, 3)
	local dateRest = string.sub(dayStr, 5)
	local grey = "|cff606060"
	local today = date("%a %d %b", time())
	if dayStr == today then
		return "Today " .. grey .. dayAbbr .. "|r"
	end
	local yesterday = date("%a %d %b", time() - 86400)
	if dayStr == yesterday then
		return "Yesterday " .. grey .. dayAbbr .. "|r"
	end
	return dateRest .. " " .. grey .. dayAbbr .. "|r"
end

-- ===== DB accessor =====
local GetDB = THSE.GetDB

-- ===== Shared helpers =====
local function TrimHistory(hs)
	while table.getn(hs.honorHistory) > MAX_ENTRIES do
		table.remove(hs.honorHistory)
	end
end

-- Append "Rank Progress" lines with Honor-per-1% breakdown to a tooltip.
-- gain: rank progress delta (0-1 scale); total/hKills/hOther: honor amounts.
local function AppendRankGainTip(L, gain, total, hKills, hOther)
	if gain < 0.00005 then return end
	table.insert(L, { "", nil })
	table.insert(L, { "Rank Progress", nil, 1.0, 0.82, 0.0 })
	table.insert(L, { "Progress", "+" .. string.format("%.2f", gain * 100) .. "%", 0.7, 0.7, 0.7, 0.27, 0.87, 0.47 })
	local pctPoints = gain * 100
	if total > 0 and pctPoints > 0 then
		table.insert(L, { "Honor per 1%", FmtHonor(math.floor(total / pctPoints)), 0.7, 0.7, 0.7, 0.867, 0.733, 0.267, true })
		if hKills > 0 then
			table.insert(L, { "  HK per 1%", FmtHonor(math.floor(hKills / pctPoints)), 0.55, 0.55, 0.55, 0.867, 0.733, 0.267, true })
		end
		if hOther > 0 then
			table.insert(L, { "  Bonus+Quest per 1%", FmtHonor(math.floor(hOther / pctPoints)), 0.55, 0.55, 0.55, 0.867, 0.733, 0.267, true })
		end
	end
end

-- ===== QuestToBG: substring-match quest name to BG zone =====
local function QuestToBG(questName)
	if not questName then return nil end
	local q = string.lower(questName)
	for zone, _ in pairs(_ZONE_ABBR) do
		if string.find(q, string.lower(zone), 1, true) then
			return zone
		end
	end
	return nil
end

-- ===== BuildGroups =====
-- Returns list of groups from hs.honorHistory (newest first → index 1)
-- Group key = "zone:startT"
local function BuildGroups(history)
	local groups = {}
	local cur    = nil
	-- pendingResult carries the timestamp of the bgresult event so we can use
	-- it as a game boundary: entries with t > pendingResult.t belong to the
	-- already-sealed group; entries with t <= pendingResult.t belong to an
	-- earlier game (force a new group).
	local pendingResult = nil  -- { zone=..., result=..., t=... }
	-- pendingTicks: tick entries that arrived before any group existed (cur==nil).
	-- Flushed (prepended) to the next group that is created so they appear
	-- in the most recent group, newest-first.
	local pendingTicks = {}

	for i = 1, table.getn(history) do
		local e = history[i]

		if e.type == "bgresult" then
			if cur and IsBGZone(cur.zone) and cur.zone == e.zone then
				if not cur.sealed then
					-- Unsealed group: apply grace check
					if (cur.lastT - e.t) <= BG_FINISH_GRACE then
						cur.result    = e.result
						cur.sealed    = true
						cur.sealedAtT = e.t
					else
						cur.sealed    = true
						cur.sealedAtT = cur.lastT
						pendingResult = { zone = e.zone, result = e.result, t = e.t }
					end
				elseif not cur.result then
					-- Sealed by bgexit but no result yet → attach the Win/Loss.
					-- Don't create a new boundary — remaining entries belong to
					-- the same game and should merge via BG_SESSION_GAP fallback.
					cur.result = e.result
				else
					-- Already has a result → belongs to an older game
					pendingResult = { zone = e.zone, result = e.result, t = e.t }
				end
			else
				pendingResult = { zone = e.zone, result = e.result, t = e.t }
			end
		elseif e.type == "bgexit" then
			-- bgexit seals the current BG group (game boundary) but carries
			-- no result — the bgresult that follows will supply it.
			-- Only seal if the bgexit belongs to THIS game session (timestamp
			-- within grace of the group's entries). If older, it's from a
			-- previous game — defer as boundary marker.
			if cur and IsBGZone(cur.zone) and cur.zone == e.zone then
				if not cur.sealed then
					if (cur.startT - e.t) <= BG_FINISH_GRACE then
						-- bgexit is close to group entries → same game, seal it
						cur.sealed    = true
						cur.sealedAtT = e.t
						table.insert(cur.entries, e)
					else
						-- bgexit is from previous game → seal cur (no result)
						-- and set boundary so old entries start a new group
						cur.sealed    = true
						cur.sealedAtT = cur.lastT
						pendingResult = { zone = e.zone, result = nil, t = e.t }
					end
				else
					-- Already sealed → boundary marker for older entries
					pendingResult = pendingResult or { zone = e.zone, result = nil, t = e.t }
				end
			end
			-- If cur is nil or different zone, skip — bgresult handles boundaries
		else
			-- Tick entries are metadata — always attach to current group,
			-- never create new groups or affect grouping boundaries.
			if e.type == "tick" then
				if cur then
					table.insert(cur.entries, e)
				else
					-- No group yet: buffer until the next real group is created.
					table.insert(pendingTicks, e)
				end
				-- Don't update cur.lastT or cur.total; tick is transparent.
			else
			local sameGroup = false
				if cur then
					local sameZone = (e.zone == cur.zone)
					local withinGap = (cur.lastT - e.t) <= GROUP_GAP_SEC
					if IsBGZone(e.zone) then
						if not cur.sealed then
							sameGroup = sameZone and (cur.lastT - e.t) <= BG_SESSION_GAP
						else
							-- Sealed BG group: use explicit boundary if available,
							-- otherwise fall back to time gap between entries.
							if pendingResult then
								sameGroup = sameZone and (e.t > pendingResult.t)
							else
								sameGroup = sameZone and (cur.lastT - e.t) <= BG_SESSION_GAP
							end
						end
					else
						sameGroup = sameZone and withinGap
					end
				end

				if sameGroup then
					table.insert(cur.entries, e)
					cur.total = cur.total + (e.amount or 0)
					cur.lastT = e.t
					if e.type == "turnin" or e.type == "award" then
						cur.isTurnin = true
					end
				else
					cur = {
						zone     = e.zone,
						isBG     = IsBGZone(e.zone),
						isTurnin = (e.type == "turnin" or e.type == "award"),
						total    = e.amount or 0,
						result   = nil,
						startT   = e.t,
						lastT    = e.t,
						entries  = { e },
					}
					-- Flush any ticks that arrived before this group existed.
					-- Insert newest-first: iterate pendingTicks in reverse so the
					-- chronologically newest tick ends up at cur.entries[1].
					if table.getn(pendingTicks) > 0 then
						for pi = table.getn(pendingTicks), 1, -1 do
							table.insert(cur.entries, 1, pendingTicks[pi])
						end
						pendingTicks = {}
					end
					-- Apply deferred bgresult if it matches this new group's zone
					if pendingResult and cur.isBG and pendingResult.zone == cur.zone then
						cur.result    = pendingResult.result
						cur.sealed    = true
						cur.sealedAtT = pendingResult.t
						pendingResult = nil
					end
					table.insert(groups, cur)
				end
			end -- tick vs normal entry
		end
	end

	-- Stabilize gKey using lastT (oldest entry) so keys don't change when new entries arrive
	for _, g in ipairs(groups) do
		g.gKey = (g.zone or "?") .. ":" .. tostring(g.lastT)
	end

	return groups
end

-- ===== Category helpers =====
local function GroupCat(g)
	if g.isBG     then return "bg"     end
	if g.isTurnin then return "turnin" end
	return "world"
end

local _CAT_COLOR = {
	bg     = { 1.0,  0.82, 0.0  },  -- WoW interface yellow
	turnin = { 0.55, 0.80, 1.0  },  -- teal/blue
	world  = { 0.75, 0.45, 0.85 },  -- soft purple (faction/PvP feel)
}

local function CatColor(cat)
	local c = _CAT_COLOR[cat] or _CAT_COLOR.world
	return c[1], c[2], c[3]
end

-- ===== Tooltip builder =====
local function BuildGroupTip(g)
	local cat = GroupCat(g)
	local cr, cg, cb = CatColor(cat)
	local tip = { title = g.zone or "Unknown", tr = cr, tg = cg, tb = cb, lines = {} }
	local L = tip.lines

	-- Category subtitle
	local catLabel = cat == "bg" and "Battleground" or cat == "turnin" and "Quest Turn-in" or "World PvP"
	table.insert(L, { catLabel, nil, cr * 0.7, cg * 0.7, cb * 0.7 })

	local nKills, hKills = 0, 0
	local nTurnin, hTurnin = 0, 0
	local nAward, hAward = 0, 0
	local firstT, lastT

	for _, e in ipairs(g.entries) do
		if not firstT or e.t < firstT then firstT = e.t end
		if not lastT  or e.t > lastT  then lastT  = e.t end
		if e.type == "kill" then
			nKills = nKills + 1; hKills = hKills + (e.amount or 0)
		elseif e.type == "turnin" then
			nTurnin = nTurnin + 1; hTurnin = hTurnin + (e.amount or 0)
		elseif e.type == "award" then
			nAward = nAward + 1; hAward = hAward + (e.amount or 0)
		end
	end

	local span = (firstT and lastT) and (lastT - firstT) or 0

	if g.isBG then
		-- Time range
		if firstT then
			local tstr = firstT ~= lastT
				and (FmtTime(firstT) .. " - " .. FmtTime(lastT))
				or FmtTime(firstT)
			table.insert(L, { tstr, nil, 0.45, 0.45, 0.45 })
		end
		-- Victory / Defeat
		if g.result == "win" then
			table.insert(L, { "Victory", nil, 0.38, 0.85, 0.38 })
		elseif g.result == "loss" then
			table.insert(L, { "Defeat",  nil, 0.85, 0.32, 0.32 })
		end
		table.insert(L, { "", nil })
		-- "Honor" section header
		table.insert(L, { "Honor", nil, 1.0, 0.82, 0.0 })
		if hKills  > 0 then table.insert(L, { "Kills",  "+" .. FmtHonor(hKills),  0.7, 0.7, 0.7, 1,    1,    1    }) end
		if hAward  > 0 then table.insert(L, { "Bonus",  "+" .. FmtHonor(hAward),  0.7, 0.7, 0.7, 0.867, 0.733, 0.267 }) end
		if hTurnin > 0 then table.insert(L, { "Marks",   "+" .. FmtHonor(hTurnin), 0.7, 0.7, 0.7, 0.55, 0.80, 1.0  }) end
		local nSrc = 0
		if hKills>0 then nSrc=nSrc+1 end
		if hAward>0 then nSrc=nSrc+1 end
		if hTurnin>0 then nSrc=nSrc+1 end
		if nSrc > 1 then table.insert(L, { "--------------------", nil, 0.25, 0.25, 0.25 }) end
		table.insert(L, { "Total",    "+" .. FmtHonor(g.total), 1.0, 0.82, 0.0, 0.867, 0.733, 0.267 })
		if span > 60 then
			local hph = math.floor(g.total * 3600 / span)
			table.insert(L, { "Honor/hr", FmtHonor(hph),         0.55, 0.55, 0.55, 0.867, 0.733, 0.267 })
		end
	elseif g.isTurnin then
		-- Time range
		if firstT then
			local tstr = firstT ~= lastT
				and (FmtTime(firstT) .. " - " .. FmtTime(lastT))
				or FmtTime(firstT)
			table.insert(L, { tstr, nil, 0.45, 0.45, 0.45 })
		end
		table.insert(L, { "", nil })
		-- "Honor" section header
		table.insert(L, { "Honor", nil, 1.0, 0.82, 0.0 })
		if hTurnin > 0 then table.insert(L, { "Marks",   "+" .. FmtHonor(hTurnin), 0.7, 0.7, 0.7, 0.55, 0.80, 1.0  }) end
		if hAward  > 0 then table.insert(L, { "Bonus",  "+" .. FmtHonor(hAward),  0.7, 0.7, 0.7, 0.867, 0.733, 0.267 }) end
		if hKills  > 0 then table.insert(L, { "Kills",  "+" .. FmtHonor(hKills),  0.7, 0.7, 0.7, 1,    1,    1    }) end
		local nSrc = 0
		if hTurnin>0 then nSrc=nSrc+1 end
		if hAward>0 then nSrc=nSrc+1 end
		if hKills>0 then nSrc=nSrc+1 end
		if nSrc > 1 then table.insert(L, { "--------------------", nil, 0.25, 0.25, 0.25 }) end
		table.insert(L, { "", nil })
		table.insert(L, { "Total",    "+" .. FmtHonor(g.total), 1.0, 0.82, 0.0, 0.867, 0.733, 0.267 })
	else
		-- Time range + duration
		if firstT then
			local tstr = firstT ~= lastT
				and (FmtTime(firstT) .. " - " .. FmtTime(lastT))
				or FmtTime(firstT)
			if span > 60 then tstr = tstr .. "  (" .. FmtDuration(span) .. ")" end
			table.insert(L, { tstr, nil, 0.45, 0.45, 0.45 })
		end
		table.insert(L, { "", nil })
		-- Sources section
		table.insert(L, { "Sources", nil, 1.0, 0.82, 0.0 })
		if nKills  > 0 then table.insert(L, { "Kills",  nKills  .. "x", 0.7, 0.7, 0.7, 0.8, 0.8, 0.8 }) end
		if nTurnin > 0 then table.insert(L, { "Marks",  nTurnin .. "x", 0.7, 0.7, 0.7, 0.8, 0.8, 0.8 }) end
		if nAward  > 0 then table.insert(L, { "Awards", nAward  .. "x", 0.7, 0.7, 0.7, 0.8, 0.8, 0.8 }) end
		table.insert(L, { "", nil })
		-- Honor section
		table.insert(L, { "Honor", nil, 1.0, 0.82, 0.0 })
		if hKills  > 0 then table.insert(L, { "Kills",  "+" .. FmtHonor(hKills),  0.7, 0.7, 0.7, 1,     1,     1     }) end
		if hTurnin > 0 then table.insert(L, { "Marks",  "+" .. FmtHonor(hTurnin), 0.7, 0.7, 0.7, 0.55,  0.80,  1.0   }) end
		if hAward  > 0 then table.insert(L, { "Bonus",  "+" .. FmtHonor(hAward),  0.7, 0.7, 0.7, 0.867, 0.733, 0.267 }) end
		local nSrc = 0
		if hKills>0 then nSrc=nSrc+1 end
		if hTurnin>0 then nSrc=nSrc+1 end
		if hAward>0 then nSrc=nSrc+1 end
		if nSrc > 1 then table.insert(L, { "--------------------", nil, 0.25, 0.25, 0.25 }) end
		table.insert(L, { "Total",    "+" .. FmtHonor(g.total), 1.0, 0.82, 0.0, 0.867, 0.733, 0.267 })
		if span > 60 then
			local hph = math.floor(g.total * 3600 / span)
			table.insert(L, { "Honor/hr", FmtHonor(hph),         0.55, 0.55, 0.55, 0.867, 0.733, 0.267 })
		end
	end

	-- Rank Progress (per group, chained to previous group)
	AppendRankGainTip(L, g.chainedRankGain or 0, g.total, hKills, hAward + hTurnin)

	return tip
end

local function BuildWeekTip(label, weekGroups, wTop, wBot, apiHonor, decayPct)
	local tip = { title = label, tr = 1.0, tg = 0.82, tb = 0.0, lines = {} }
	local L = tip.lines

	local nBGs, nWins, nLosses = 0, 0, 0
	local nKills, nTurnin = 0, 0
	local hKills, hBG, hTurnin, hBonus = 0, 0, 0, 0
	local wFirstT, wLastT, wTotal = nil, nil, 0
	local wActiveTime = 0  -- sum of per-group spans (active time only)

	for _, g in ipairs(weekGroups) do
		if not wFirstT or g.lastT  < wFirstT then wFirstT = g.lastT  end
		if not wLastT  or g.startT > wLastT  then wLastT  = g.startT end
		wTotal = wTotal + g.total
		local gSpan = g.startT - g.lastT
		if gSpan > 0 then wActiveTime = wActiveTime + gSpan end
		if g.isBG then
			nBGs = nBGs + 1
			if g.result == "win"  then nWins   = nWins   + 1 end
			if g.result == "loss" then nLosses = nLosses + 1 end
		end
		for _, e in ipairs(g.entries) do
			if e.type == "kill" then
				nKills = nKills + 1; hKills = hKills + (e.amount or 0)
			elseif e.type == "turnin" then
				nTurnin = nTurnin + 1; hTurnin = hTurnin + (e.amount or 0)
			elseif e.type == "award" then
				if g.isBG then hBG    = hBG    + (e.amount or 0)
				else            hBonus = hBonus + (e.amount or 0) end
			end
		end
	end

	-- Date range
	if wFirstT and wLastT then
		local d1 = date("%d %b", wFirstT)
		local d2 = date("%d %b", wLastT)
		local tstr = d1 ~= d2 and (d1 .. " - " .. d2) or d1
		if wActiveTime > 60 then tstr = tstr .. "  (" .. FmtDuration(wActiveTime) .. ")" end
		table.insert(L, { tstr, nil, 0.45, 0.45, 0.45 })
	end
	table.insert(L, { "", nil })

	-- Sources section
	table.insert(L, { "Sources", nil, 1.0, 0.82, 0.0 })
	if nBGs > 0 then
		table.insert(L, { "Battlegrounds", tostring(nBGs), 0.7, 0.7, 0.7, 0.7, 0.7, 0.7 })
		if nWins + nLosses > 0 then
			local pct = math.floor(nWins * 100 / (nWins + nLosses))
			local wStr = "|cff4dff4d" .. nWins .. "|r"
			local lStr = "|cffff4d4d" .. nLosses .. "|r"
			local wr = "  " .. wStr .. "/" .. lStr .. "  " .. pct .. "%"
			table.insert(L, { wr, nil, 0.7, 0.7, 0.7 })
		end
	end
	if nKills  > 0 then table.insert(L, { "Kills",  tostring(nKills),  0.7, 0.7, 0.7, 0.7, 0.7, 0.7 }) end
	if nTurnin > 0 then table.insert(L, { "Marks",  tostring(nTurnin), 0.7, 0.7, 0.7, 0.7, 0.7, 0.7 }) end
	table.insert(L, { "", nil })

	-- Honor section
	table.insert(L, { "Honor", nil, 1.0, 0.82, 0.0 })
	if hKills  > 0 then table.insert(L, { "Kills",         "+" .. FmtHonor(hKills),  0.7, 0.7, 0.7, 1,     1,     1     }) end
	if hBG     > 0 then table.insert(L, { "Battlegrounds", "+" .. FmtHonor(hBG),     0.7, 0.7, 0.7, 0.867, 0.733, 0.267 }) end
	if hTurnin > 0 then table.insert(L, { "Marks",         "+" .. FmtHonor(hTurnin), 0.7, 0.7, 0.7, 0.55,  0.80,  1.0   }) end
	if hBonus  > 0 then table.insert(L, { "Bonus",         "+" .. FmtHonor(hBonus),  0.7, 0.7, 0.7, 0.867, 0.733, 0.267 }) end
	local nSrc = 0
	if hKills>0 then nSrc=nSrc+1 end; if hBG>0 then nSrc=nSrc+1 end
	if hTurnin>0 then nSrc=nSrc+1 end; if hBonus>0 then nSrc=nSrc+1 end
	if nSrc > 1 then table.insert(L, { "--------------------", nil, 0.25, 0.25, 0.25 }) end
	local displayTotal = wTotal
	if apiHonor and apiHonor > displayTotal then displayTotal = apiHonor end
	table.insert(L, { "Total", "+" .. FmtHonor(displayTotal), 1.0, 0.82, 0.0, 0.867, 0.733, 0.267 })
	if displayTotal > wTotal then
		table.insert(L, { "Tracked", "+" .. FmtHonor(wTotal), 0.45, 0.45, 0.45, 0.55, 0.55, 0.55, true })
	end
	if wActiveTime > 60 then
		local hph = math.floor(displayTotal * 3600 / wActiveTime)
		table.insert(L, { "Honor/hr", FmtHonor(hph), 0.55, 0.55, 0.55, 0.867, 0.733, 0.267 })
	end

	-- Rank Progress section
	local hasRankSection = (wTop and wBot) or (decayPct and decayPct > 0.001)
	if hasRankSection then
		local rankGain = nil
		if wTop and wBot then
			local wGain = wTop - wBot
			if wGain > 0.00005 then
				AppendRankGainTip(L, wGain, displayTotal, hKills, hBG + hTurnin + hBonus)
				rankGain = wGain
			elseif wGain < -0.00005 then
				table.insert(L, { "", nil })
				table.insert(L, { "Rank Progress", nil, 1.0, 0.82, 0.0 })
				table.insert(L, { "Net Change", string.format("%.2f", wGain * 100) .. "%", 0.7, 0.7, 0.7, 1.0, 0.30, 0.30 })
			end
		end
		if not rankGain and decayPct and decayPct > 0.001 then
			table.insert(L, { "", nil })
			table.insert(L, { "Rank Progress", nil, 1.0, 0.82, 0.0 })
		end
		if decayPct and decayPct > 0.001 then
			local lostStr = "-" .. string.format("%.2f", decayPct * 100) .. "%"
			table.insert(L, { "Decay", lostStr, 0.7, 0.7, 0.7, 1.0, 0.30, 0.30 })
		end
	end

	return tip
end

local function BuildDayTip(dayStr, dayGroups, decayPct, isToday)
	local tip = { title = dayStr, tr = 0.85, tg = 0.85, tb = 0.85, lines = {} }
	local L = tip.lines

	local nBGs, nWins, nLosses = 0, 0, 0
	local nKills, nTurnin = 0, 0
	local hKills, hBG, hTurnin, hBonus = 0, 0, 0, 0
	local dayFirstT, dayLastT, dayTotal = nil, nil, 0
	local dayActiveTime = 0  -- sum of per-group spans (active time only)

	for _, g in ipairs(dayGroups) do
		if not dayFirstT or g.lastT  < dayFirstT then dayFirstT = g.lastT  end
		if not dayLastT  or g.startT > dayLastT  then dayLastT  = g.startT end
		dayTotal = dayTotal + g.total
		local gSpan = g.startT - g.lastT
		if gSpan > 0 then dayActiveTime = dayActiveTime + gSpan end
		if g.isBG then
			nBGs = nBGs + 1
			if g.result == "win"  then nWins   = nWins   + 1 end
			if g.result == "loss" then nLosses = nLosses + 1 end
		end
		for _, e in ipairs(g.entries) do
			if e.type == "kill" then
				nKills = nKills + 1; hKills = hKills + (e.amount or 0)
			elseif e.type == "turnin" then
				nTurnin = nTurnin + 1; hTurnin = hTurnin + (e.amount or 0)
			elseif e.type == "award" then
				if g.isBG then hBG    = hBG    + (e.amount or 0)
				else            hBonus = hBonus + (e.amount or 0) end
			end
		end
	end

	-- Time range + duration
	if dayFirstT then
		local tstr = dayFirstT ~= dayLastT
			and (FmtTime(dayFirstT) .. " - " .. FmtTime(dayLastT))
			or FmtTime(dayFirstT)
		if dayActiveTime > 60 then tstr = tstr .. "  (" .. FmtDuration(dayActiveTime) .. ")" end
		table.insert(L, { tstr, nil, 0.45, 0.45, 0.45 })
		local dailyBG = DailyBGForDay(dayFirstT)
		if dailyBG then
			table.insert(L, { "Daily BG", dailyBG, 0.55, 0.55, 0.55, 1.0, 0.82, 0.0 })
		end
	end
	table.insert(L, { "", nil })

	-- Sources section
	table.insert(L, { "Sources", nil, 1.0, 0.82, 0.0 })
	if nBGs > 0 then
		table.insert(L, { "Battlegrounds", tostring(nBGs), 0.7, 0.7, 0.7, 0.7, 0.7, 0.7 })
		if nWins + nLosses > 0 then
			local pct = math.floor(nWins * 100 / (nWins + nLosses))
			local wStr = "|cff4dff4d" .. nWins .. "|r"
			local lStr = "|cffff4d4d" .. nLosses .. "|r"
			local wr = "  " .. wStr .. "/" .. lStr .. "  " .. pct .. "%"
			table.insert(L, { wr, nil, 0.7, 0.7, 0.7 })
		end
	end
	if nKills  > 0 then table.insert(L, { "Kills",         tostring(nKills),  0.7, 0.7, 0.7, 0.7, 0.7, 0.7 }) end
	if nTurnin > 0 then table.insert(L, { "Marks",         tostring(nTurnin), 0.7, 0.7, 0.7, 0.7, 0.7, 0.7 }) end
	table.insert(L, { "", nil })

	-- Honor section
	table.insert(L, { "Honor", nil, 1.0, 0.82, 0.0 })
	if hKills  > 0 then table.insert(L, { "Kills",         "+" .. FmtHonor(hKills),  0.7, 0.7, 0.7, 1,    1,    1    }) end
	if hBG     > 0 then table.insert(L, { "Battlegrounds", "+" .. FmtHonor(hBG),     0.7, 0.7, 0.7, 0.867, 0.733, 0.267 }) end
	if hTurnin > 0 then table.insert(L, { "Marks",         "+" .. FmtHonor(hTurnin), 0.7, 0.7, 0.7, 0.55,  0.80,  1.0  }) end
	if hBonus  > 0 then table.insert(L, { "Bonus",         "+" .. FmtHonor(hBonus),  0.7, 0.7, 0.7, 0.867, 0.733, 0.267 }) end
	local nSrc = 0
	if hKills>0 then nSrc=nSrc+1 end
	if hBG>0    then nSrc=nSrc+1 end
	if hTurnin>0 then nSrc=nSrc+1 end
	if hBonus>0  then nSrc=nSrc+1 end
	if nSrc > 1 then table.insert(L, { "--------------------", nil, 0.25, 0.25, 0.25 }) end
	table.insert(L, { "Total",    "+" .. FmtHonor(dayTotal), 1.0, 0.82, 0.0, 0.867, 0.733, 0.267 })
	if dayActiveTime > 60 then
		local hph = math.floor(dayTotal * 3600 / dayActiveTime)
		table.insert(L, { "Honor/hr", FmtHonor(hph), 0.55, 0.55, 0.55, 0.867, 0.733, 0.267 })
	end

	-- Rank Progress section (only if rankPct data exists on entries)
	local dayFirstRankPct = nil
	local dayLastRankPct  = nil
	for _, g in ipairs(dayGroups) do
		for _, e in ipairs(g.entries) do
			if e.rankPct then
				if not dayLastRankPct  then dayLastRankPct  = e.rankPct end  -- newest entry first
				dayFirstRankPct = e.rankPct  -- keep updating → ends at oldest entry
			end
		end
	end
	-- For today, use live API + persisted baseline so gain matches overlay
	if isToday then
		local liveRP = GetPVPRankProgress() or 0
		if liveRP > 0 and (not dayLastRankPct or liveRP > dayLastRankPct) then
			dayLastRankPct = liveRP
		end
		local _hs = GetDB()
		local dsStart = _hs and _hs.dayStartProgress
		if dsStart and (not dayFirstRankPct or dsStart < dayFirstRankPct) then
			dayFirstRankPct = dsStart
		end
	end
	local hasRankSection = (dayFirstRankPct and dayLastRankPct) or (decayPct and decayPct > 0.001)
	if hasRankSection then
		local rankGain = nil
		if dayFirstRankPct and dayLastRankPct then
			rankGain = dayLastRankPct - dayFirstRankPct
			if rankGain > 0.00005 then
				AppendRankGainTip(L, rankGain, dayTotal, hKills, hBG + hTurnin + hBonus)
			else
				rankGain = nil
			end
		end
		if not rankGain and decayPct and decayPct > 0.001 then
			table.insert(L, { "", nil })
			table.insert(L, { "Rank Progress", nil, 1.0, 0.82, 0.0 })
		end
		if decayPct and decayPct > 0.001 then
			local lostStr = "-" .. string.format("%.2f", decayPct * 100) .. "%"
			table.insert(L, { "Decay", lostStr, 0.7, 0.7, 0.7, 1.0, 0.30, 0.30 })
		end
	end

	return tip
end

local function ShowGroupTip(anchor, tip)
	if not tip then return end
	GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:SetText(tip.title, tip.tr or 1, tip.tg or 1, tip.tb or 1)
	local shift = IsShiftKeyDown()
	for _, ln in ipairs(tip.lines) do
		if ln[9] and not shift then
			-- skip shift-only lines
		else
			if ln[1] == "" and not ln[2] then
				GameTooltip:AddLine(" ")
			elseif ln[2] then
				GameTooltip:AddDoubleLine(ln[1], ln[2], ln[3] or 0.8, ln[4] or 0.8, ln[5] or 0.8, ln[6] or 0.8, ln[7] or 0.8, ln[8] or 0.8)
			else
				GameTooltip:AddLine(ln[1], ln[3] or 0.8, ln[4] or 0.8, ln[5] or 0.8)
			end
		end
	end
	GameTooltip:Show()
end

-- ===== Pool + constants =====
local P = {
	hdrBtn = {}, hdrBtnUsed = 0,
	ts = {}, icon = {}, icon2 = {}, icon3 = {}, name = {}, amt = {}, row = {}, estripe = {},
	entryUsed = 0,
	dateSep = {}, dateUsed = 0,
	weekSep = {}, weekUsed = 0,
}

local CONTENT_W = WIN_W - 22
local HDR_BTN_W = CONTENT_W - 8

-- Column X-offsets from TOPRIGHT (shared by day seps, week seps, and column headers)
local COL_WL     = -260   -- W/L fraction
local COL_PCT    = -214   -- Win rate %
local COL_RKVAL  = -164   -- Rank % value
local COL_RKICO  = -146   -- Rank icon
local COL_GAIN   = -86    -- Rank gain %
local COL_HONOR  = -18    -- Honor total

-- Pool allocators
local content  -- forward ref; set in CreateHistoryWindow

local function AcquireHdrBtn()
	P.hdrBtnUsed = P.hdrBtnUsed + 1
	if not P.hdrBtn[P.hdrBtnUsed] then
		local btn = CreateFrame("Button", nil, content)
		btn:SetHeight(16)
		btn:SetWidth(HDR_BTN_W)
		local hl = btn:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints(btn)
		hl:SetTexture(1, 1, 1, 0.06)

		-- Left-edge category stripe
		btn._stripe = btn:CreateTexture(nil, "BACKGROUND")
		btn._stripe:SetWidth(3)
		btn._stripe:SetPoint("TOPLEFT",    btn, "TOPLEFT",    0, 0)
		btn._stripe:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
		btn._stripe:SetTexture(1, 1, 1, 1)

		-- BG mark icon (shown for BG group headers)
		btn._ico = btn:CreateTexture(nil, "ARTWORK")
		btn._ico:SetWidth(14); btn._ico:SetHeight(14)
		btn._ico:SetPoint("LEFT", btn, "LEFT", 6, 0)

		btn._fs = btn:CreateFontString(nil, "OVERLAY")
		btn._fs:SetFont(FONT, 10, "OUTLINE")
		btn._fs:SetJustifyH("LEFT")
		btn._fs:SetPoint("TOPLEFT",  btn, "TOPLEFT",  22, -2)
		btn._fs:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -68, -2)

		btn._rt = btn:CreateFontString(nil, "OVERLAY")
		btn._rt:SetFont(FONT, 10)
		btn._rt:SetJustifyH("RIGHT")
		btn._rt:SetWidth(40)
		btn._rt:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -68, -2)
		btn._rt:SetTextColor(0.35, 0.35, 0.35)

		btn._ra = btn:CreateFontString(nil, "OVERLAY")
		btn._ra:SetFont(FONT, 10, "OUTLINE")
		btn._ra:SetJustifyH("RIGHT")
		btn._ra:SetWidth(56)
		btn._ra:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -14, -2)

		btn._rp = btn:CreateFontString(nil, "OVERLAY")
		btn._rp:SetFont(FONT, 10)
		btn._rp:SetJustifyH("RIGHT")
		btn._rp:SetWidth(52)
		btn._rp:SetTextColor(0.27, 0.87, 0.47)
		btn._rp:Hide()

		btn._rankIcon = btn:CreateTexture(nil, "ARTWORK")
		btn._rankIcon:SetWidth(12); btn._rankIcon:SetHeight(12)
		btn._rankIcon:Hide()

		btn._rankPctVal = btn:CreateFontString(nil, "OVERLAY")
		btn._rankPctVal:SetFont(FONT, 10)
		btn._rankPctVal:SetJustifyH("RIGHT")
		btn._rankPctVal:SetWidth(34)
		btn._rankPctVal:SetTextColor(0.75, 0.75, 0.75)
		btn._rankPctVal:Hide()

		btn:SetScript("OnEnter", function()
			ShowGroupTip(this, this._tip)
		end)
		btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

		P.hdrBtn[P.hdrBtnUsed] = btn
	end
	local btn = P.hdrBtn[P.hdrBtnUsed]
	btn:Show()
	return btn
end

local function AcquireEntry()
	P.entryUsed = P.entryUsed + 1
	local i = P.entryUsed
	if not P.ts[i] then
		P.ts[i]   = content:CreateFontString(nil, "OVERLAY")
		P.ts[i]:SetFont(FONT, 10)
		P.ts[i]:SetJustifyH("LEFT")
		P.ts[i]:SetWidth(48)
		P.ts[i]:SetTextColor(0.35, 0.35, 0.35)

		P.icon[i] = content:CreateTexture(nil, "ARTWORK")
		P.icon[i]:SetWidth(14)
		P.icon[i]:SetHeight(14)

		P.icon2[i] = content:CreateTexture(nil, "ARTWORK")
		P.icon2[i]:SetWidth(14); P.icon2[i]:SetHeight(14)
		P.icon3[i] = content:CreateTexture(nil, "ARTWORK")
		P.icon3[i]:SetWidth(14); P.icon3[i]:SetHeight(14)

		P.name[i] = content:CreateFontString(nil, "OVERLAY")
		P.name[i]:SetFont(FONT, 10)
		P.name[i]:SetJustifyH("LEFT")
		P.name[i]:SetWidth(200)

		P.amt[i]  = content:CreateFontString(nil, "OVERLAY")
		P.amt[i]:SetFont(FONT, 10)
		P.amt[i]:SetJustifyH("RIGHT")
		P.amt[i]:SetWidth(56)

		P.row[i]  = CreateFrame("Button", nil, content)
		P.row[i]:SetHeight(ROW_H)
		P.row[i]:SetWidth(CONTENT_W)
		local rhl = P.row[i]:CreateTexture(nil, "HIGHLIGHT")
		rhl:SetAllPoints(P.row[i])
		rhl:SetTexture(1, 1, 1, 0.04)
		P.row[i]:SetScript("OnEnter", function()
			ShowGroupTip(this, this._tip)
		end)
		P.row[i]:SetScript("OnLeave", function() GameTooltip:Hide() end)

		P.estripe[i] = content:CreateTexture(nil, "BACKGROUND")
		P.estripe[i]:SetWidth(1)
		P.estripe[i]:SetTexture(1, 1, 1, 1)
	end
	P.ts[i]:Show(); P.name[i]:Show(); P.amt[i]:Show(); P.row[i]:Show()
	P.icon[i]:Hide(); P.icon2[i]:Hide(); P.icon3[i]:Hide(); P.estripe[i]:Hide()
	return i
end

local function AcquireDateSep()
	P.dateUsed = P.dateUsed + 1
	if not P.dateSep[P.dateUsed] then
		local btn = CreateFrame("Button", nil, content)
		btn:SetHeight(ROW_H)
		btn:SetWidth(CONTENT_W)
		local hl = btn:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints(btn)
		hl:SetTexture(1, 1, 1, 0.06)
		-- 4px left-edge bar (highest hierarchy)
		btn._bar = btn:CreateTexture(nil, "BACKGROUND")
		btn._bar:SetWidth(5)
		btn._bar:SetPoint("TOPLEFT",    btn, "TOPLEFT",    0, -1)
		btn._bar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
		btn._bar:SetTexture(1, 1, 1, 0.9)  -- vertex-colored at render time
		-- Thin divider line across the full width (bottom)
		btn._line = btn:CreateTexture(nil, "BACKGROUND")
		btn._line:SetHeight(1)
		btn._line:SetPoint("BOTTOMLEFT",  btn, "BOTTOMLEFT",  0, 1)
		btn._line:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 1)
		btn._line:SetTexture(1, 1, 1, 0.12)
		-- Date label
		btn._fs = btn:CreateFontString(nil, "OVERLAY")
		btn._fs:SetFont(FONT, 10, "OUTLINE")
		btn._fs:SetJustifyH("LEFT")
		btn._fs:SetPoint("TOPLEFT",  btn, "TOPLEFT",  8, -4)
		btn._fs:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -266, -4)
		btn._fs:SetTextColor(1, 1, 1)
		-- Daily BG icon (between date label and W/L)
		btn._dailyIcon = btn:CreateTexture(nil, "ARTWORK")
		btn._dailyIcon:SetWidth(12); btn._dailyIcon:SetHeight(12)
		btn._dailyIcon:SetPoint("RIGHT", btn._hdrWL, "LEFT", -2, 0)
		btn._dailyIcon:Hide()
		-- W/L fraction (fixed position)
		btn._hdrWL = btn:CreateFontString(nil, "OVERLAY")
		btn._hdrWL:SetFont(FONT, 10)
		btn._hdrWL:SetJustifyH("RIGHT")
		btn._hdrWL:SetWidth(48)
		btn._hdrWL:SetPoint("TOPRIGHT", btn, "TOPRIGHT", COL_WL, -5)
		-- Win rate % (fixed position)
		btn._hdrPct = btn:CreateFontString(nil, "OVERLAY")
		btn._hdrPct:SetFont(FONT, 10)
		btn._hdrPct:SetJustifyH("RIGHT")
		btn._hdrPct:SetWidth(40)
		btn._hdrPct:SetPoint("TOPRIGHT", btn, "TOPRIGHT", COL_PCT, -5)
		-- Current rank % value (fixed, left of rank icon)
		btn._hdrRankPctVal = btn:CreateFontString(nil, "OVERLAY")
		btn._hdrRankPctVal:SetFont(FONT, 10)
		btn._hdrRankPctVal:SetJustifyH("RIGHT")
		btn._hdrRankPctVal:SetWidth(36)
		btn._hdrRankPctVal:SetPoint("TOPRIGHT", btn, "TOPRIGHT", COL_RKVAL, -5)
		btn._hdrRankPctVal:SetTextColor(0.75, 0.75, 0.75)
		btn._hdrRankPctVal:Hide()
		-- Decay arrow icon (shown left of rank% val on reset days with decay)
		btn._decayArrow = btn:CreateTexture(nil, "OVERLAY")
		btn._decayArrow:SetWidth(10); btn._decayArrow:SetHeight(10)
		btn._decayArrow:SetPoint("RIGHT", btn, "RIGHT", -192, 0)
		btn._decayArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
		btn._decayArrow:SetVertexColor(1.0, 0.30, 0.30, 1)
		btn._decayArrow:Hide()
		-- Rank icon (fixed, left of rank% val)
		btn._hdrRankIcon = btn:CreateTexture(nil, "ARTWORK")
		btn._hdrRankIcon:SetWidth(12); btn._hdrRankIcon:SetHeight(12)
		btn._hdrRankIcon:SetPoint("RIGHT", btn, "RIGHT", COL_RKICO, 0)
		btn._hdrRankIcon:Hide()
		-- Rank progression +gain% (fixed, left of faction badge)
		btn._hdrRankPct = btn:CreateFontString(nil, "OVERLAY")
		btn._hdrRankPct:SetFont(FONT, 10)
		btn._hdrRankPct:SetJustifyH("RIGHT")
		btn._hdrRankPct:SetWidth(54)
		btn._hdrRankPct:SetPoint("TOPRIGHT", btn, "TOPRIGHT", COL_GAIN, -5)
		btn._hdrRankPct:SetTextColor(0.27, 0.87, 0.47)
		btn._hdrRankPct:Hide()
		-- Day total honor (just left of faction badge)
		btn._hdrAmt = btn:CreateFontString(nil, "OVERLAY")
		btn._hdrAmt:SetFont(FONT, 10, "OUTLINE")
		btn._hdrAmt:SetJustifyH("RIGHT")
		btn._hdrAmt:SetWidth(56)
		btn._hdrAmt:SetPoint("TOPRIGHT", btn, "TOPRIGHT", COL_HONOR, -4)
		-- Faction badge (rightmost element)
		btn._factionBadge = btn:CreateTexture(nil, "ARTWORK")
		btn._factionBadge:SetWidth(14); btn._factionBadge:SetHeight(14)
		btn._factionBadge:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
		local f = UnitFactionGroup("player")
		if f == "Horde" then
			btn._factionBadge:SetTexture("Interface\\TargetingFrame\\UI-PVP-Horde")
		else
			btn._factionBadge:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")
		end
		btn._factionBadge:SetTexCoord(0.09, 0.63, 0.05, 0.63)
		btn._factionBadge:SetAlpha(1.0)
		btn._factionBadge:Hide()  -- not shown on day seps
		P.dateSep[P.dateUsed] = btn
	end
	P.dateSep[P.dateUsed]:Show()
	return P.dateSep[P.dateUsed]
end

local function AcquireWeekSep()
	P.weekUsed = P.weekUsed + 1
	if not P.weekSep[P.weekUsed] then
		local btn = CreateFrame("Button", nil, content)
		btn:SetHeight(WEEKSEP_H)
		btn:SetWidth(CONTENT_W)
		local hl = btn:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints(btn)
		hl:SetTexture(1, 1, 1, 0.08)
		-- Wider left bar for visual hierarchy over day seps
		btn._bar = btn:CreateTexture(nil, "BACKGROUND")
		btn._bar:SetWidth(8)
		btn._bar:SetPoint("TOPLEFT",    btn, "TOPLEFT",    0, -1)
		btn._bar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
		btn._bar:SetTexture(1, 1, 1, 0.9)
		-- Bottom line
		btn._line = btn:CreateTexture(nil, "BACKGROUND")
		btn._line:SetHeight(1)
		btn._line:SetPoint("BOTTOMLEFT",  btn, "BOTTOMLEFT",  0, 1)
		btn._line:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 1)
		btn._line:SetTexture(1, 1, 1, 0.20)
		-- Week label
		btn._fs = btn:CreateFontString(nil, "OVERLAY")
		btn._fs:SetFont(FONT, 11, "OUTLINE")
		btn._fs:SetJustifyH("LEFT")
		btn._fs:SetPoint("TOPLEFT",  btn, "TOPLEFT",  12, -4)
		btn._fs:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -266, -4)
		btn._fs:SetTextColor(1, 1, 1)
		-- W/L fraction
		btn._hdrWL = btn:CreateFontString(nil, "OVERLAY")
		btn._hdrWL:SetFont(FONT, 10)
		btn._hdrWL:SetJustifyH("RIGHT")
		btn._hdrWL:SetWidth(48)
		btn._hdrWL:SetPoint("TOPRIGHT", btn, "TOPRIGHT", COL_WL, -6)
		-- Win rate %
		btn._hdrPct = btn:CreateFontString(nil, "OVERLAY")
		btn._hdrPct:SetFont(FONT, 10)
		btn._hdrPct:SetJustifyH("RIGHT")
		btn._hdrPct:SetWidth(40)
		btn._hdrPct:SetPoint("TOPRIGHT", btn, "TOPRIGHT", COL_PCT, -6)
		-- Rank gain %
		btn._hdrRankPct = btn:CreateFontString(nil, "OVERLAY")
		btn._hdrRankPct:SetFont(FONT, 10)
		btn._hdrRankPct:SetJustifyH("RIGHT")
		btn._hdrRankPct:SetWidth(54)
		btn._hdrRankPct:SetPoint("TOPRIGHT", btn, "TOPRIGHT", COL_GAIN, -6)
		btn._hdrRankPct:SetTextColor(0.27, 0.87, 0.47)
		-- Rank icon (highest achieved during week)
		btn._hdrRankIcon = btn:CreateTexture(nil, "ARTWORK")
		btn._hdrRankIcon:SetWidth(14); btn._hdrRankIcon:SetHeight(14)
		btn._hdrRankIcon:SetPoint("RIGHT", btn, "RIGHT", COL_RKICO, 0)
		btn._hdrRankIcon:Hide()
		-- Rank % value (right of rank icon)
		btn._hdrRankPctVal = btn:CreateFontString(nil, "OVERLAY")
		btn._hdrRankPctVal:SetFont(FONT, 10)
		btn._hdrRankPctVal:SetJustifyH("RIGHT")
		btn._hdrRankPctVal:SetWidth(36)
		btn._hdrRankPctVal:SetPoint("TOPRIGHT", btn, "TOPRIGHT", COL_RKVAL + 2, -6)
		btn._hdrRankPctVal:SetTextColor(0.75, 0.75, 0.75)
		btn._hdrRankPctVal:Hide()
		-- Week total honor
		btn._hdrAmt = btn:CreateFontString(nil, "OVERLAY")
		btn._hdrAmt:SetFont(FONT, 11, "OUTLINE")
		btn._hdrAmt:SetJustifyH("RIGHT")
		btn._hdrAmt:SetWidth(56)
		btn._hdrAmt:SetPoint("TOPRIGHT", btn, "TOPRIGHT", COL_HONOR, -4)
		-- Faction badge
		btn._factionBadge = btn:CreateTexture(nil, "ARTWORK")
		btn._factionBadge:SetWidth(14); btn._factionBadge:SetHeight(14)
		btn._factionBadge:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
		local f = UnitFactionGroup("player")
		if f == "Horde" then
			btn._factionBadge:SetTexture("Interface\\TargetingFrame\\UI-PVP-Horde")
		else
			btn._factionBadge:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")
		end
		btn._factionBadge:SetTexCoord(0.09, 0.63, 0.05, 0.63)
		P.weekSep[P.weekUsed] = btn
	end
	P.weekSep[P.weekUsed]:Show()
	return P.weekSep[P.weekUsed]
end

local function HideAllPooled()
	for i = 1, P.hdrBtnUsed do P.hdrBtn[i]:Hide() end
	P.hdrBtnUsed = 0
	for i = 1, P.entryUsed do
		P.ts[i]:Hide(); P.icon[i]:Hide(); P.icon2[i]:Hide(); P.icon3[i]:Hide()
		P.name[i]:Hide(); P.amt[i]:Hide(); P.row[i]:Hide(); P.estripe[i]:Hide()
	end
	P.entryUsed = 0
	for i = 1, P.dateUsed do P.dateSep[i]:Hide() end
	P.dateUsed = 0
	for i = 1, P.weekUsed do P.weekSep[i]:Hide() end
	P.weekUsed = 0
end

-- ===== Collapse state =====
local _collapsed    = {}  -- gKey  → bool; gi==1 stays open, rest auto-collapse on first see
local _dayCollapsed = {}  -- dayStr → bool; true = day collapsed
local _weekCollapsed = {} -- weeksAgo number → bool; true = whole week collapsed
local _knownDays    = {}  -- dayStr → true; all days seen in last RefreshList
-- _VS: view-state flags packed into one table to reduce upvalue pressure on RefreshList
local _VS = { hideZero = false, compactMode = 0, renderSC = nil, dailyBG = DailyBGForDay, bgIcons = _BG_MARK_ICON, knownWeeks = {} }
-- hideZero: when true, groups/entries with +0 honor are hidden
-- compactMode: 0=normal, 1=compact (consecutive), 2=merged (one per type), 3=super compact (per day)
-- renderSC: set to RenderSuperCompactDay after its definition
-- dailyBG: GetDailyBG function ref;  bgIcons: _BG_MARK_ICON table ref

-- ===== Window state =====
local Win
local sf          -- ScrollFrame


-- ===== Thin scrollbar =====
-- 5px dark track + gold thumb. vH = fixed visible height of the scroll viewport.
-- Returns UpdateThumb() — call after programmatic scroll resets.
local function MakeThinScrollbar(wrapper, scrollFrame, child, vH)
	local PAD   = 4
	local BAR_W = 5
	local trkH  = vH - PAD * 2

	-- Track and thumb are anchored to scrollFrame so they align exactly with the viewport,
	-- not the outer wrapper (which includes header/footer regions).
	local track = wrapper:CreateTexture(nil, "BACKGROUND")
	track:SetWidth(BAR_W)
	track:SetTexture("Interface\\BUTTONS\\WHITE8X8")
	track:SetVertexColor(0.06, 0.06, 0.06, 0.85)
	track:SetPoint("TOPRIGHT",    scrollFrame, "TOPRIGHT",    2, -PAD)
	track:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 2,  PAD)

	local thumb = CreateFrame("Frame", nil, wrapper)
	thumb:SetWidth(BAR_W)
	local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
	thumbTex:SetAllPoints(thumb)
	thumbTex:SetTexture("Interface\\BUTTONS\\WHITE8X8")
	thumbTex:SetVertexColor(0.8, 0.67, 0.0, 0.75)
	thumb:Hide()

	local function UpdateThumb()
		local cH = child:GetHeight()
		if cH <= vH then thumb:Hide(); return end
		local thmH   = math.max(16, trkH * vH / cH)
		local rangeT = trkH - thmH
		local rangeS = cH - vH
		local posY   = rangeS > 0 and (scrollFrame:GetVerticalScroll() / rangeS * rangeT) or 0
		thumb:SetHeight(thmH)
		thumb:ClearAllPoints()
		thumb:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 2, -(PAD + posY))
		thumb:Show()
	end

	local dragging, dragStartY, dragStartScroll = false, 0, 0
	thumb:EnableMouse(true)
	thumb:SetScript("OnMouseDown", function()
		dragging = true
		local _, sy = GetCursorPosition()
		dragStartY     = sy / UIParent:GetEffectiveScale()
		dragStartScroll = scrollFrame:GetVerticalScroll()
	end)
	thumb:SetScript("OnMouseUp", function() dragging = false end)

	scrollFrame:SetScript("OnUpdate", function()
		if not dragging then return end
		local _, cy = GetCursorPosition()
		local dy     = dragStartY - cy / UIParent:GetEffectiveScale()
		local cH     = child:GetHeight()
		local thmH   = math.max(16, trkH * vH / cH)
		local rangeT = trkH - thmH
		local rangeS = cH - vH
		if rangeT > 0 then
			local new = math.max(0, math.min(rangeS, dragStartScroll + dy * rangeS / rangeT))
			scrollFrame:SetVerticalScroll(new)
			UpdateThumb()
		end
	end)

	return UpdateThumb
end

local updateThumb  -- set after window + scrollframe are created

-- ===== ScrollByDelta =====
local function ScrollByDelta(delta)
	if not sf then return end
	local cur = sf:GetVerticalScroll()
	local max = sf:GetVerticalScrollRange()
	local new = math.max(0, math.min(max, cur - delta * (ROW_H * 3)))
	sf:SetVerticalScroll(new)
	if updateThumb then updateThumb() end
end

-- ===== Entry-row renderer (split out to reduce upvalue count of RefreshList) =====
-- When _VS.compactMode >= 1, merge entries of the same type into summary rows.
-- Mode 1: merge consecutive runs only.  Mode 2+: merge ALL entries of the same type.
local function CompactEntries(entries, hideZero)
	if _VS.compactMode == 0 then return entries end

	-- Mode 2 (merged): one row per unique type across the whole group
	if _VS.compactMode >= 2 then
		local fixedOrder = { "kill", "award", "turnin" }
		local buckets  = {}
		for _, e in ipairs(entries) do
			local skip = hideZero and (e.amount or 0) == 0
			if not skip and (e.type == "kill" or e.type == "award" or e.type == "turnin") then
				local bt = e.type
				if not buckets[bt] then
					buckets[bt] = { count = 0, total = 0, firstT = e.t, lastT = e.t, zone = e.zone, subs = {} }
				end
				local b = buckets[bt]
				b.count = b.count + 1
				b.total = b.total + (e.amount or 0)
				if e.t < b.lastT  then b.lastT  = e.t end
				if e.t > b.firstT then b.firstT = e.t end
				table.insert(b.subs, e)
			end
		end
		local out = {}
		for _, bt in ipairs(fixedOrder) do
			local b = buckets[bt]
			if b then
				if b.count == 1 then
					local se = b.subs[1]
					se._merged = true
					table.insert(out, se)
				else
					table.insert(out, {
						type = "_compact", subtype = bt, amount = b.total,
						count = b.count, t = b.firstT, lastT = b.lastT, zone = b.zone,
						subEntries = b.subs, merged = true,
					})
				end
			end
		end
		return out
	end

	-- Mode 1 (compact): merge consecutive runs only
	local out = {}
	local i = 1
	local n = table.getn(entries)
	while i <= n do
		local e = entries[i]
		local skip = hideZero and (e.amount or 0) == 0
		if not skip and (e.type == "kill" or e.type == "award" or e.type == "turnin") then
			local runType = e.type
			local count = 1
			local total = e.amount or 0
			local firstT = e.t
			local lastT  = e.t
			local j = i + 1
			while j <= n and entries[j].type == runType do
				local ej = entries[j]
				if not (hideZero and (ej.amount or 0) == 0) then
					count = count + 1
					total = total + (ej.amount or 0)
					lastT = ej.t
				end
				j = j + 1
			end
			if count > 1 then
				local subEntries = {}
				for k = i, j - 1 do
					if not (hideZero and (entries[k].amount or 0) == 0) then
						table.insert(subEntries, entries[k])
					end
				end
				table.insert(out, {
					type = "_compact", subtype = runType, amount = total,
					count = count, t = firstT, lastT = lastT, zone = e.zone,
					subEntries = subEntries,
				})
			else
				table.insert(out, e)
			end
			i = j
		else
			table.insert(out, e)
			i = i + 1
		end
	end
	return out
end

local function BuildCompactTip(e)
	local st = e.subtype
	local titleLabel, tr, tg, tb
	if st == "kill" then
		titleLabel = "Kills"
		tr, tg, tb = 0.75, 0.75, 0.75
	elseif st == "turnin" then
		titleLabel = "Quests"
		tr, tg, tb = 0.55, 0.80, 1.0
	elseif st == "award" then
		titleLabel = "Bonus"
		tr, tg, tb = 0.867, 0.733, 0.267
	else
		titleLabel = "Events"
		tr, tg, tb = 0.5, 0.5, 0.5
	end
	local tip = { title = e.count .. "x " .. titleLabel, tr = tr, tg = tg, tb = tb, lines = {} }
	local L = tip.lines

	-- Time range
	local span = (e.t and e.lastT) and math.abs(e.t - e.lastT) or 0
	if e.t then
		local tstr = (e.t ~= e.lastT)
			and (FmtTime(e.lastT) .. " - " .. FmtTime(e.t))
			or FmtTime(e.t)
		if span > 60 then tstr = tstr .. "  (" .. math.floor(span / 60) .. "m)" end
		table.insert(L, { tstr, nil, 0.45, 0.45, 0.45 })
	end
	table.insert(L, { "", nil })

	-- Individual entries
	local subs = e.subEntries or {}
	local maxShow = 15
	local shown = 0
	for _, se in ipairs(subs) do
		if shown >= maxShow then
			local remaining = table.getn(subs) - maxShow
			table.insert(L, { "... +" .. remaining .. " more", nil, 0.4, 0.4, 0.4 })
			break
		end
		local leftText
		if st == "kill" then
			leftText = (se.victim or "Unknown")
		elseif st == "turnin" then
			leftText = se.questName or (se.zone or "Mark")
		elseif st == "award" then
			leftText = (se.zone or "Bonus")
		else
			leftText = (se.zone or "?")
		end
		local rightText = "+" .. FmtHonor(se.amount or 0)
		table.insert(L, { leftText, rightText, tr * 0.85, tg * 0.85, tb * 0.85, tr, tg, tb })
		shown = shown + 1
	end

	-- Divider + total
	if table.getn(subs) > 1 then
		table.insert(L, { "--------------------", nil, 0.25, 0.25, 0.25 })
	end
	table.insert(L, { "Total", "+" .. FmtHonor(e.amount), 1.0, 0.82, 0.0, 0.867, 0.733, 0.267 })

	return tip
end

local function RenderEntries(entries, yOff, cr, cg_c, cb, amtOffset, hideZero)
	local renderList = CompactEntries(entries, hideZero)
	for _, e in ipairs(renderList) do
		-- Never render tick entries with negative delta (weekly decay artefacts)
		local skipNegTick = e.type == "tick" and e.rankPct and e.prevRankPct and e.rankPct < e.prevRankPct
		if not skipNegTick and not (hideZero and (e.amount or 0) == 0 and e.type ~= "tick") then
			local ei = AcquireEntry()
			P.ts[ei]:Hide()
			local isConcerted = (e.type == "turnin" or e.type == "award")
				and e.questName
				and _CONCERTED_QUEST[e.questName]
			P.icon2[ei]:Hide(); P.icon3[ei]:Hide()
			if e.type == "_compact" then
				-- Compact summary row — pick icon by subtype
				local compactIcon
				if e.subtype == "kill" then
					compactIcon = "Interface\\Icons\\Ability_DualWield"
				elseif e.subtype == "turnin" then
					compactIcon = _BG_MARK_ICON[e.zone] or "Interface\\Icons\\INV_Misc_Coin_04"
				elseif e.subtype == "award" then
					compactIcon = _BG_MARK_ICON[e.zone] or "Interface\\Icons\\INV_Misc_Coin_02"
				else
					compactIcon = "Interface\\Icons\\INV_Misc_QuestionMark"
				end
				P.icon[ei]:ClearAllPoints()
				P.icon[ei]:SetTexture(compactIcon)
				P.icon[ei]:SetTexCoord(0.05, 0.95, 0.05, 0.95)
				P.icon[ei]:SetDesaturated(nil)
				P.icon[ei]:SetVertexColor(1, 1, 1)
				P.icon[ei]:SetPoint("TOPLEFT", content, "TOPLEFT", 28, -yOff)
				P.icon[ei]:Show()
				P.name[ei]:SetPoint("TOPLEFT", content, "TOPLEFT", 46, -yOff - 1)
			elseif isConcerted then
				P.icon[ei]:ClearAllPoints()
				P.icon[ei]:SetTexture(_BG_MARK_ICON["Warsong Gulch"])
				P.icon[ei]:SetTexCoord(0.05, 0.95, 0.05, 0.95)
				P.icon[ei]:SetDesaturated(nil)
				P.icon[ei]:SetVertexColor(1, 1, 1)
				P.icon[ei]:SetPoint("TOPLEFT", content, "TOPLEFT", 13, -yOff)
				P.icon[ei]:Show()
				P.icon2[ei]:ClearAllPoints()
				P.icon2[ei]:SetTexture(_BG_MARK_ICON["Arathi Basin"])
				P.icon2[ei]:SetTexCoord(0.05, 0.95, 0.05, 0.95)
				P.icon2[ei]:SetPoint("TOPLEFT", content, "TOPLEFT", 28, -yOff)
				P.icon2[ei]:Show()
				P.icon3[ei]:ClearAllPoints()
				P.icon3[ei]:SetTexture(_BG_MARK_ICON["Alterac Valley"])
				P.icon3[ei]:SetTexCoord(0.05, 0.95, 0.05, 0.95)
				P.icon3[ei]:SetPoint("TOPLEFT", content, "TOPLEFT", 43, -yOff)
				P.icon3[ei]:Show()
				P.name[ei]:SetPoint("TOPLEFT", content, "TOPLEFT", 59, -yOff - 1)
			else
				local iconTex = nil
				local iconGrey = false
				local iconTint = nil  -- {r,g,b} override for vertex color
				if e.type == "tick" then
					iconTex = "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up"
					iconTint = {0, 1, 0}
				elseif e.type == "award" or e.type == "turnin" then
					iconTex = _BG_MARK_ICON[e.zone]
						or _BG_MARK_ICON[QuestToBG(e.questName) or ""]
				elseif e.type == "kill" then
					if e.victimRank then
						local rankNum = GetRankNum(e.victimRank)
						if rankNum > 0 then
							iconTex = string.format(
								"Interface\\PvPRankBadges\\PvPRank%02d", rankNum)
						end
					end
					if not iconTex then
						iconTex = "Interface\\Icons\\Spell_Magic_LesserInvisibilty"
						iconGrey = true
					end
				end
				if iconTex then
					P.icon[ei]:ClearAllPoints()
					P.icon[ei]:SetTexture(iconTex)
					P.icon[ei]:SetTexCoord(0, 1, 0, 1)
					if iconGrey then
						P.icon[ei]:SetDesaturated(1)
						P.icon[ei]:SetVertexColor(0.6, 0.6, 0.6)
					elseif iconTint then
						P.icon[ei]:SetDesaturated(nil)
						P.icon[ei]:SetVertexColor(iconTint[1], iconTint[2], iconTint[3])
					else
						P.icon[ei]:SetDesaturated(nil)
						P.icon[ei]:SetVertexColor(1, 1, 1)
					end
					P.icon[ei]:SetPoint("TOPLEFT", content, "TOPLEFT", 28, -yOff)
					P.icon[ei]:Show()
					P.name[ei]:SetPoint("TOPLEFT", content, "TOPLEFT", 46, -yOff - 1)
				else
					P.name[ei]:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -yOff - 1)
				end
			end
			local nr, ng, nb = 1, 1, 1
			local ar, ag, ab = 1, 1, 1
			local nameText, amtText
			if e.type == "_compact" then
				local compactLabel
				if e.subtype == "kill" then
					compactLabel = "Kills"
					nr, ng, nb = 0.75, 0.75, 0.75; ar, ag, ab = 0.75, 0.75, 0.75
				elseif e.subtype == "turnin" then
					compactLabel = "Quests"
					nr, ng, nb = 0.55, 0.80, 1.0; ar, ag, ab = 0.55, 0.80, 1.0
				elseif e.subtype == "award" then
					compactLabel = "Bonus"
					nr, ng, nb = 0.867, 0.733, 0.267; ar, ag, ab = 0.867, 0.733, 0.267
				else
					compactLabel = "Events"
					nr, ng, nb = 0.5, 0.5, 0.5; ar, ag, ab = 0.5, 0.5, 0.5
				end
				if e.merged then
					nameText = e.count .. "x " .. compactLabel
				else
					local timeRange = FmtTime(e.lastT) .. "-" .. FmtTime(e.t)
					nameText = e.count .. "x " .. compactLabel .. " |cff505050" .. timeRange .. "|r"
				end
				amtText = "+" .. FmtHonor(e.amount)
			elseif e.type == "kill" then
				local ts = e._merged and "" or (" |cff505050" .. FmtTime(e.t) .. "|r")
				nameText = (e.victim or "Unknown") .. ts
				nr, ng, nb = 0.75, 0.75, 0.75; ar, ag, ab = 0.75, 0.75, 0.75
				amtText = "+" .. FmtHonor(e.amount)
			elseif e.type == "turnin" then
				local ts = e._merged and "" or (" |cff505050" .. FmtTime(e.t) .. "|r")
				if isConcerted then
					nameText = e.questName .. ts
				else
					local bgZone = QuestToBG(e.questName) or e.zone or "Mark"
					nameText = bgZone .. " Mark of Honor" .. ts
				end
				nr, ng, nb = 0.55, 0.80, 1.0; ar, ag, ab = 0.55, 0.80, 1.0
				amtText = "+" .. FmtHonor(e.amount)
			elseif e.type == "award" then
				local ts = e._merged and "" or (" |cff505050" .. FmtTime(e.t) .. "|r")
				nameText = (e.zone or "BG Award") .. ts
				nr, ng, nb = 0.867, 0.733, 0.267; ar, ag, ab = 0.867, 0.733, 0.267
				amtText = "+" .. FmtHonor(e.amount)
			elseif e.type == "tick" then
				local deltaStr = ""
				if e.rankPct and e.prevRankPct then
					local d = (e.rankPct - e.prevRankPct) * 100
					deltaStr = string.format("+%.2f%%", d)
				end
				nameText = "Rank Progression |cff505050" .. FmtTime(e.t) .. "|r"
				nr, ng, nb = 0.27, 0.87, 0.47; ar, ag, ab = 0.27, 0.87, 0.47
				amtText = deltaStr
			else
				local ts = e._merged and "" or (" |cff505050" .. FmtTime(e.t) .. "|r")
				nameText = (e.raw or e.zone or "?") .. ts
				nr, ng, nb = 0.5, 0.5, 0.5; ar, ag, ab = 0.5, 0.5, 0.5
				amtText = "+" .. FmtHonor(e.amount)
			end
			if (e.amount or 0) == 0 and e.type ~= "tick" then
				nr, ng, nb = 0.28, 0.28, 0.28
				ar, ag, ab = 0.28, 0.28, 0.28
			end
			P.name[ei]:SetText(nameText)
			P.name[ei]:SetTextColor(nr, ng, nb)
			if e.type == "tick" then
				-- Align percent under the group header's gain % column
				P.amt[ei]:ClearAllPoints()
				P.amt[ei]:SetPoint("TOPRIGHT", content, "TOPRIGHT", -82, -yOff - 1)
			else
				P.amt[ei]:ClearAllPoints()
				P.amt[ei]:SetPoint("TOPRIGHT", content, "TOPRIGHT", amtOffset, -yOff - 1)
			end
			P.amt[ei]:SetText(amtText)
			P.amt[ei]:SetTextColor(ar, ag, ab)
			P.estripe[ei]:SetVertexColor(cr, cg_c, cb)
			P.estripe[ei]:SetAlpha(0.4)
			P.estripe[ei]:SetPoint("TOPLEFT",    content, "TOPLEFT", 12, -yOff)
			P.estripe[ei]:SetPoint("BOTTOMLEFT", content, "TOPLEFT", 12, -yOff - ROW_H)
			P.estripe[ei]:Show()
			P.row[ei]:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -yOff)
			if e.type == "_compact" then
				P.row[ei]._tip = BuildCompactTip(e)
			elseif e.type == "tick" then
				local newPct = e.rankPct and string.format("%.2f%%", e.rankPct * 100) or "?"
				local oldPct = e.prevRankPct and string.format("%.2f%%", e.prevRankPct * 100) or "?"
				local delta = ""
				if e.rankPct and e.prevRankPct then
					local d = (e.rankPct - e.prevRankPct) * 100
					if d >= 0 then
						delta = string.format("+%.2f%%", d)
					else
						delta = string.format("-%.2f%%", -d)
					end
				end
				local tip = {
					title = "Rank Progression",
					tr = 0.27, tg = 0.87, tb = 0.47,
					lines = {
						{ FmtTime(e.t), nil, 0.5, 0.5, 0.5 },
						{ "", nil },
						{ "Rank", oldPct, 0.6, 0.6, 0.6, 0.75, 0.75, 0.75 },
						{ "Progression", delta, 0.6, 0.6, 0.6, 0.27, 0.87, 0.47 },
						{ "Total", newPct, 0.6, 0.6, 0.6, 1, 1, 1 },
					},
				}
				P.row[ei]._tip = tip
			else
				P.row[ei]._tip = nil
			end
			yOff = yOff + ROW_H
		end
	end
	return yOff
end

-- ===== Super compact: one category-summary row per category per day =====
local function BuildSuperCompactCatTip(catKey, catLabel, dayGroups)
	local cr, cg_c, cb = CatColor(catKey)
	local tip = { title = catLabel, tr = cr, tg = cg_c, tb = cb, lines = {} }
	local L = tip.lines
	local total = 0
	local nGroups = 0
	local zoneOrder = {}
	local zoneStats = {}
	for _, g in ipairs(dayGroups) do
		if GroupCat(g) == catKey then
			nGroups = nGroups + 1
			total = total + g.total
			local z = g.zone or "Unknown"
			if not zoneStats[z] then
				zoneStats[z] = { honor = 0, count = 0 }
				table.insert(zoneOrder, z)
			end
			zoneStats[z].honor = zoneStats[z].honor + g.total
			zoneStats[z].count = zoneStats[z].count + 1
		end
	end
	-- BG-specific: wins/losses
	if catKey == "bg" then
		local nW, nL = 0, 0
		for _, g in ipairs(dayGroups) do
			if GroupCat(g) == "bg" and g.result then
				if g.result == "win" then nW = nW + 1 else nL = nL + 1 end
			end
		end
		local sessStr = nGroups .. " game" .. (nGroups ~= 1 and "s" or "")
		if nW + nL > 0 then
			local pct = math.floor(nW * 100 / (nW + nL))
			sessStr = sessStr .. "  |cff4dff4d" .. nW .. "W|r|cff888888/|r|cffff4d4d" .. nL .. "L|r  " .. pct .. "%"
		end
		table.insert(L, { sessStr, nil, 0.45, 0.45, 0.45 })
	else
		table.insert(L, { nGroups .. " session" .. (nGroups ~= 1 and "s" or ""), nil, 0.45, 0.45, 0.45 })
	end
	table.insert(L, { "", nil })
	for _, z in ipairs(zoneOrder) do
		local s = zoneStats[z]
		local label = z
		if s.count > 1 then label = label .. " (" .. s.count .. "x)" end
		table.insert(L, { label, "+" .. FmtHonor(s.honor), cr * 0.85, cg_c * 0.85, cb * 0.85, cr, cg_c, cb })
	end
	if table.getn(zoneOrder) > 1 then
		table.insert(L, { "--------------------", nil, 0.25, 0.25, 0.25 })
	end
	table.insert(L, { "Total", "+" .. FmtHonor(total), 1.0, 0.82, 0.0, 0.867, 0.733, 0.267 })
	return tip
end

local function RenderSuperCompactDay(dayStr, dayGroups, yOff, hideZero)
	local catOrder = { "bg", "turnin", "world" }
	local catLabelMap = { bg = "Battlegrounds", turnin = "Quests", world = "World PvP" }
	local worldIcon = (UnitFactionGroup("player") == "Horde")
		and "Interface\\Icons\\INV_BannerPVP_01"
		or  "Interface\\Icons\\INV_BannerPVP_02"
	local catIconMap = {
		bg     = "Interface\\Icons\\INV_Jewelry_Amulet_07",
		turnin = "Interface\\Icons\\INV_Misc_Coin_04",
		world  = worldIcon,
	}
	local catData = {}
	for _, ck in ipairs(catOrder) do
		catData[ck] = { n = 0, total = 0 }
	end
	for _, g in ipairs(dayGroups) do
		if not (hideZero and g.total == 0 and (g.chainedRankGain or 0) == 0) then
			local ck = GroupCat(g)
			catData[ck].n = catData[ck].n + 1
			catData[ck].total = catData[ck].total + g.total
		end
	end
	for _, ck in ipairs(catOrder) do
		local cd = catData[ck]
		if cd.n > 0 then
			local cr, cg_c, cb = CatColor(ck)
			local ei = AcquireEntry()
			P.ts[ei]:Hide()
			P.icon[ei]:ClearAllPoints()
			P.icon[ei]:SetTexture(catIconMap[ck])
			P.icon[ei]:SetTexCoord(0.05, 0.95, 0.05, 0.95)
			P.icon[ei]:SetPoint("TOPLEFT", content, "TOPLEFT", 28, -yOff)
			P.icon[ei]:Show()
			P.name[ei]:SetPoint("TOPLEFT", content, "TOPLEFT", 46, -yOff - 1)
			P.name[ei]:SetText(cd.n .. "x " .. catLabelMap[ck])
			P.name[ei]:SetTextColor(cr, cg_c, cb)
			P.amt[ei]:SetPoint("TOPRIGHT", content, "TOPRIGHT", -18, -yOff - 1)
			P.amt[ei]:SetText("+" .. FmtHonor(cd.total))
			P.amt[ei]:SetTextColor(cr, cg_c, cb)
			P.estripe[ei]:SetVertexColor(cr, cg_c, cb)
			P.estripe[ei]:SetAlpha(0.4)
			P.estripe[ei]:SetPoint("TOPLEFT",    content, "TOPLEFT", 12, -yOff)
			P.estripe[ei]:SetPoint("BOTTOMLEFT", content, "TOPLEFT", 12, -yOff - ROW_H)
			P.estripe[ei]:Show()
			P.row[ei]:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -yOff)
			P.row[ei]._tip = BuildSuperCompactCatTip(ck, catLabelMap[ck], dayGroups)
			yOff = yOff + ROW_H
		end
	end
	return yOff
end
_VS.renderSC = RenderSuperCompactDay

-- ===== Week helpers (module-level to avoid upvalue pressure in RefreshList) =====
local function WinPctColor(pct)
	local r, g, b
	if pct <= 50 then
		-- Red (ff4d4d) at 0% → Pale yellow (ffffaa) at 50%
		local t = pct / 50
		r = 255
		g = math.floor(77 + 178 * t)
		b = math.floor(77 + 93 * t)
	else
		-- Pale yellow (ffffaa) at 50% → Green (4dff4d) at 100%
		local t = (pct - 50) / 50
		r = math.floor(255 - 178 * t)
		g = 255
		b = math.floor(170 - 93 * t)
	end
	return string.format("%02x%02x%02x", r, g, b)
end

local function CalcWeeksAgo(t, thisResetT)
	if t >= thisResetT then return 0 end
	return math.floor((thisResetT - t - 1) / (7 * 86400)) + 1
end
local function WeekLabel(wa, thisResetT)
	if wa == 0 then return "This Week"
	elseif wa == 1 then return "Last Week"
	else
		local wStart = thisResetT - wa * 7 * 86400
		return date("%b %d", wStart) .. " - " .. date("%b %d", wStart + 6 * 86400)
	end
end

-- ===== RefreshList =====
local function RefreshList()
	HideAllPooled()
	local hs = GetDB()
	if not hs or not hs.honorHistory then return end
	local history = hs.honorHistory
	if table.getn(history) == 0 then return end

	local _factionPvPTex = (UnitFactionGroup("player") == "Horde")
		and "Interface\\Icons\\INV_BannerPVP_01"
		or  "Interface\\Icons\\INV_BannerPVP_02"

	local groups = BuildGroups(history)
	local yOff   = 0
	local lastDate = nil
	local _scRendered = {}  -- dayStr → true; tracks super-compact days already rendered

	-- Precompute Wednesday reset boundary (epoch day 0 = Thu; +1 offset → Wed = 0)
	local _now = time()
	local _dayNum = math.floor(_now / 86400)
	local _daysSinceWed = (_dayNum + 1) - math.floor((_dayNum + 1) / 7) * 7
	local _thisResetT = _dayNum * 86400 - _daysSinceWed * 86400

	-- Pre-compute per-day and per-week stats
	local _dayWins       = {}
	local _dayLosses     = {}
	local _dayGroupsMap  = {}
	local _dayTopRankPct = {}
	local _dayBotRankPct = {}
	local _dayTopRankNum = {}
	local _weekHonor     = {}
	local _weekWins      = {}
	local _weekLosses    = {}
	local _weekTopRankPct = {}
	local _weekBotRankPct = {}
	local _weekTopRankNum = {}
	_knownDays = {}
	_VS.knownWeeks = {}
	for _, g in ipairs(groups) do
		local ds = FmtDate(g.startT)
		local wa = CalcWeeksAgo(g.startT, _thisResetT)
		local dk = ds .. "|" .. wa  -- composite day key: separates same calendar day across weekly resets
		_knownDays[dk] = true
		_VS.knownWeeks[wa] = true
		if not _dayGroupsMap[dk] then _dayGroupsMap[dk] = {} end
		table.insert(_dayGroupsMap[dk], g)
		if g.isBG and g.result then
			if not _dayWins[dk]  then _dayWins[dk] = 0;  _dayLosses[dk] = 0  end
			if not _weekWins[wa] then _weekWins[wa] = 0; _weekLosses[wa] = 0 end
			if g.result == "win" then
				_dayWins[dk] = _dayWins[dk] + 1;   _weekWins[wa] = _weekWins[wa] + 1
			else
				_dayLosses[dk] = _dayLosses[dk] + 1; _weekLosses[wa] = _weekLosses[wa] + 1
			end
		end
		_weekHonor[wa] = (_weekHonor[wa] or 0) + g.total
		for _, e in ipairs(g.entries) do
			if e.rankPct and e.rankPct > 0 then
				if not _dayTopRankPct[dk] then
					_dayTopRankPct[dk] = e.rankPct
					_dayTopRankNum[dk] = e.rankNum or 0
				end
				_dayBotRankPct[dk] = e.rankPct
				if not _weekTopRankPct[wa] then
					_weekTopRankPct[wa] = e.rankPct
					_weekTopRankNum[wa] = e.rankNum or 0
				end
				if (_weekTopRankNum[wa] or 0) == 0 and (e.rankNum or 0) > 0 then
					_weekTopRankNum[wa] = e.rankNum
				end
				_weekBotRankPct[wa] = e.rankPct
			end
		end
	end
	local _dayTotals = {}
	for dk, dgs in pairs(_dayGroupsMap) do
		local t = 0
		for _, dg in ipairs(dgs) do t = t + dg.total end
		_dayTotals[dk] = t
	end

	-- Pre-compute chained rank gain per group.
	-- Groups are newest-first; within each day, chain so that:
	--   group[i].chainedRankGain = group[i].newestRankPct - group[i+1].newestRankPct
	-- The oldest group in each day uses its own oldest-to-newest span.
	-- This guarantees the sum of all group gains = day total gain.
	for _, g in ipairs(groups) do
		-- Find this group's newest and oldest rankPct.
		-- Skip rankPct == 0: GetPVPRankProgress() returns 0 during loading screens.
		local top, bot = nil, nil
		for _, e in ipairs(g.entries) do
			if e.rankPct and e.rankPct > 0 then
				if not top then top = e.rankPct end
				bot = e.rankPct
			end
		end
		g._rankPctTop = top
		g._rankPctBot = bot
	end
	for ds, dgs in pairs(_dayGroupsMap) do
		-- dgs is newest-first (same order as groups)
		local n = table.getn(dgs)
		for i = 1, n do
			local g = dgs[i]
			if i < n then
				-- Chain to next group (chronologically previous)
				local prevTop = dgs[i + 1]._rankPctTop
				if g._rankPctTop and prevTop then
					g.chainedRankGain = g._rankPctTop - prevTop
				else
					g.chainedRankGain = 0
				end
			else
				-- Oldest group in the day: use its own span
				if g._rankPctTop and g._rankPctBot then
					g.chainedRankGain = g._rankPctTop - g._rankPctBot
				else
					g.chainedRankGain = 0
				end
			end
			if g.chainedRankGain < 0.00005 then g.chainedRankGain = 0 end
		end
	end

	local _prevWeeksAgo = nil
	local _todayStr = date("%a %d %b", time())
	for gi, g in ipairs(groups) do
		local dayStr = FmtDate(g.startT)
		local weeksAgo = CalcWeeksAgo(g.startT, _thisResetT)
		local dk = dayStr .. "|" .. weeksAgo  -- composite day key

		-- Week separator: insert at the first group of each new week bucket
		if weeksAgo ~= _prevWeeksAgo then
			-- Add a small gap after the previous week's content if it was open
			if _prevWeeksAgo ~= nil and not _weekCollapsed[_prevWeeksAgo] then
				yOff = yOff + 4
			end
			local wsep = AcquireWeekSep()
			wsep:SetHeight(WEEKSEP_H)
			wsep._bar:SetHeight(WEEKSEP_H)
			-- 1: amber-tinted bar, dims with age
			local wBright = math.max(0.3, 0.95 - weeksAgo * 0.18)
			wsep._bar:SetVertexColor(wBright, wBright, wBright, 1)
			-- 4: label dims with age
			local wLabelBright = math.max(0.35, 1.0 - weeksAgo * 0.25)
			wsep._fs:SetTextColor(wLabelBright, wLabelBright, wLabelBright)
			wsep._fs:SetText(WeekLabel(weeksAgo, _thisResetT))
			-- Honor total: use API for current week, stored snapshot for past weeks
			local wHonor = _weekHonor[weeksAgo] or 0
			if weeksAgo == 0 and GetPVPThisWeekStats then
				local _, apiHonor = GetPVPThisWeekStats()
				if apiHonor and apiHonor > wHonor then wHonor = apiHonor end
			else
				local snapKey = tostring(_thisResetT - weeksAgo * 604800)
				local snap = hs and hs.weekApiHonor and hs.weekApiHonor[snapKey]
				if snap and snap > wHonor then wHonor = snap end
			end
			if wHonor > 0 then
				wsep._hdrAmt:SetText("|cffddbb44+" .. FmtHonor(math.floor(wHonor)) .. "|r")
				wsep._hdrAmt:Show()
			else wsep._hdrAmt:Hide() end
			-- W/L
			local wW = _weekWins[weeksAgo] or 0
			local wL = _weekLosses[weeksAgo] or 0
			if wW + wL > 0 then
				local pct = math.floor(wW * 100 / (wW + wL))
				wsep._hdrWL:SetText("|cff4dff4d" .. wW .. "|r|cff888888/|r|cffff4d4d" .. wL .. "|r")
				wsep._hdrPct:SetText("|cff" .. WinPctColor(pct) .. pct .. "%|r")
				wsep._hdrWL:Show(); wsep._hdrPct:Show()
			else wsep._hdrWL:Hide(); wsep._hdrPct:Hide() end
			-- Rank gain for the week; 6: red text when net negative (decay week)
			local wTop = _weekTopRankPct[weeksAgo]
			local wBot = _weekBotRankPct[weeksAgo]
			-- For current week, use live API + persisted baseline so gain matches overlay
			if weeksAgo == 0 then
				local liveRP = GetPVPRankProgress() or 0
				if liveRP > 0 and (not wTop or liveRP > wTop) then wTop = liveRP end
				local wkStart = hs and hs.weeklyStartProgress
				if wkStart and (not wBot or wkStart < wBot) then wBot = wkStart end
			end
			local wGain = (wTop and wBot) and (wTop - wBot) or 0
			if wGain > 0.00005 then
				wsep._hdrRankPct:SetText("+" .. string.format("%.2f", wGain * 100) .. "%")
				wsep._hdrRankPct:SetTextColor(0.27, 0.87, 0.47)
				wsep._hdrRankPct:Show()
			elseif wGain < -0.00005 then
				wsep._hdrRankPct:SetText(string.format("%.2f", wGain * 100) .. "%")
				wsep._hdrRankPct:SetTextColor(1.0, 0.30, 0.30)
				wsep._hdrRankPct:Show()
			else wsep._hdrRankPct:Hide() end
			-- Rank badge + current rank %
			local wRankNum = _weekTopRankNum[weeksAgo] or 0
			if wRankNum == 0 then wRankNum = UnitPVPRank("player") or 0 end
			local wRankTex = 0
			if wRankNum > 0 then
				local _, t = GetPVPRankInfo(wRankNum)
				wRankTex = t or wRankNum
			end
			if wRankTex > 0 then
				wsep._hdrRankIcon:SetTexture(string.format("Interface\\PvPRankBadges\\PvPRank%02d", wRankTex))
				wsep._hdrRankIcon:Show()
				local wTopPct = wTop or 0
				wsep._hdrRankPctVal:SetText(string.format("%.1f", wTopPct * 100) .. "%")
				wsep._hdrRankPctVal:Show()
			else
				wsep._hdrRankIcon:Hide()
				wsep._hdrRankPctVal:Hide()
			end
			wsep._factionBadge:Show()
			local capturedWA = weeksAgo
			wsep:SetScript("OnClick", function()
				_weekCollapsed[capturedWA] = not _weekCollapsed[capturedWA]
				RefreshList()
			end)
			-- Week tooltip: gather all groups belonging to this week
			local weekGroups = {}
			for ds, dgs in pairs(_dayGroupsMap) do
				if CalcWeeksAgo(dgs[1].startT, _thisResetT) == weeksAgo then
					for _, wg in ipairs(dgs) do
						table.insert(weekGroups, wg)
					end
				end
			end
			local wApiHonor = nil
			if weeksAgo == 0 and GetPVPThisWeekStats then
				local _, ah = GetPVPThisWeekStats()
				wApiHonor = ah
			else
				local snapKey = tostring(_thisResetT - weeksAgo * 604800)
				wApiHonor = hs and hs.weekApiHonor and hs.weekApiHonor[snapKey]
			end
			local wDecayPct = nil
			local prevWTop = _weekTopRankPct[weeksAgo + 1]
			if prevWTop and wBot and (prevWTop - wBot > 0.001) then
				wDecayPct = prevWTop - wBot
			end
			wsep._tip = BuildWeekTip(WeekLabel(weeksAgo, _thisResetT), weekGroups, wTop, wBot, wApiHonor, wDecayPct)
			wsep:SetScript("OnEnter", function() ShowGroupTip(this, this._tip) end)
			wsep:SetScript("OnLeave", function() GameTooltip:Hide() end)
			wsep:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOff)
			yOff = yOff + WEEKSEP_H
		end

		-- Date separator
		if dk ~= lastDate then
			lastDate = dk
			if not _weekCollapsed[weeksAgo] then
			local sep = AcquireDateSep()
			sep:SetHeight(DATESEP_H)
			sep._bar:SetHeight(DATESEP_H)
			sep:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOff)
			-- Bar brightness: dims with age; warm tint to echo week sep amber
			local barBright = math.max(0.2, 0.75 - math.min(weeksAgo, 3) * 0.15)
			sep._bar:SetVertexColor(barBright, barBright, barBright, 1)
			local dayOpen = not _dayCollapsed[dk]
			local capturedDay = dk
			-- 3: label brightness tracks bar brightness
			local lblBright = math.max(0.38, barBright + 0.12)
			sep._fs:SetTextColor(lblBright, lblBright, lblBright)
			sep._fs:SetText(FmtDateLabel(dayStr))
			-- Daily BG icon
			local dailyBG = _VS.dailyBG(g.startT)
			local dailyTex = dailyBG and _VS.bgIcons[dailyBG]
			if dailyTex then
				sep._dailyIcon:SetTexture(dailyTex)
				sep._dailyIcon:Show()
			else
				sep._dailyIcon:Hide()
			end
			if dayOpen then sep._line:Show() else sep._line:Hide() end
			sep:SetScript("OnClick", function()
				_dayCollapsed[capturedDay] = not _dayCollapsed[capturedDay]
				RefreshList()
			end)
			-- BG W/L + wr% record
			local nW = _dayWins[dk] or 0
			local nL = _dayLosses[dk] or 0
			if nW + nL > 0 then
				local pct = math.floor(nW * 100 / (nW + nL))
				sep._hdrWL:SetText("|cff4dff4d" .. nW .. "|r|cff888888/|r|cffff4d4d" .. nL .. "|r")
				sep._hdrPct:SetText("|cff" .. WinPctColor(pct) .. pct .. "%|r")
				sep._hdrWL:Show(); sep._hdrPct:Show()
			else
				sep._hdrWL:Hide(); sep._hdrPct:Hide()
			end
			local dayTotal = _dayTotals[dk] or 0
			if dayTotal > 0 then
				sep._hdrAmt:SetText("|cfff2e095+" .. FmtHonor(math.floor(dayTotal)) .. "|r")
				sep._hdrAmt:Show()
			else
				sep._hdrAmt:Hide()
			end
			-- Day rank progression + current rank
			local dayLastRankPct  = _dayTopRankPct[dk]
			local dayFirstRankPct = _dayBotRankPct[dk]
			local dayLastRankNum  = _dayTopRankNum[dk] or 0
			if dayLastRankNum == 0 then dayLastRankNum = UnitPVPRank("player") or 0 end
			local dayRankTex = 0
			if dayLastRankNum > 0 then
				local _, t = GetPVPRankInfo(dayLastRankNum)
				dayRankTex = t or dayLastRankNum
			end
			-- For today, use live API + persisted baseline so gain matches overlay
			if dayStr == _todayStr and weeksAgo == 0 then
				local liveRP = GetPVPRankProgress() or 0
				if liveRP > 0 and (not dayLastRankPct or liveRP > dayLastRankPct) then
					dayLastRankPct = liveRP
				end
				local dsStart = hs and hs.dayStartProgress
				if dsStart and (not dayFirstRankPct or dsStart < dayFirstRankPct) then
					dayFirstRankPct = dsStart
				end
			end
			local dayRankGain = (dayFirstRankPct and dayLastRankPct) and (dayLastRankPct - dayFirstRankPct) or 0
			-- Decay detection: Wednesday rankPct start lower than previous calendar day rankPct end
			local prevDayStr = date("%a %d %b", g.startT - 86400)
			local prevDK = prevDayStr .. "|" .. (weeksAgo + 1)
			local decayOccurred = (string.sub(dayStr, 1, 3) == "Wed")
				and _dayBotRankPct[dk] ~= nil
				and _dayTopRankPct[prevDK] ~= nil
				and (_dayTopRankPct[prevDK] - _dayBotRankPct[dk] > 0.001)
			local decayAmt = decayOccurred and (_dayTopRankPct[prevDK] - _dayBotRankPct[dk]) or nil
			sep._tip = BuildDayTip(dayStr, _dayGroupsMap[dk] or {}, decayAmt, dayStr == _todayStr and weeksAgo == 0)
			sep:SetScript("OnEnter", function() ShowGroupTip(this, this._tip) end)
			sep:SetScript("OnLeave", function() GameTooltip:Hide() end)
			-- Rank display
			if dayRankGain > 0.00005 then
				sep._hdrRankPct:SetText("+" .. string.format("%.2f", dayRankGain * 100) .. "%")
				sep._hdrRankPct:Show()
				if dayRankTex > 0 then
					sep._hdrRankIcon:SetTexture(string.format("Interface\\PvPRankBadges\\PvPRank%02d", dayRankTex))
					if decayOccurred then
						sep._hdrRankPctVal:SetTextColor(1.0, 0.30, 0.30)
						sep._decayArrow:Show()
					else
						sep._hdrRankPctVal:SetTextColor(0.75, 0.75, 0.75)
						sep._decayArrow:Hide()
					end
					sep._hdrRankIcon:Show()
					sep._hdrRankPctVal:SetText(string.format("%.1f", dayLastRankPct * 100) .. "%")
					sep._hdrRankPctVal:Show()
				else
					sep._hdrRankIcon:Hide()
					sep._hdrRankPctVal:Hide()
					sep._decayArrow:Hide()
				end
			elseif decayOccurred and dayRankTex > 0 then
				-- Decay but no net gain this day: show rank state highlighted in decay colour
				sep._hdrRankPct:Hide()
				sep._hdrRankIcon:SetTexture(string.format("Interface\\PvPRankBadges\\PvPRank%02d", dayRankTex))
				sep._hdrRankIcon:Show()
				sep._hdrRankPctVal:SetText(string.format("%.1f", (dayLastRankPct or 0) * 100) .. "%")
				sep._hdrRankPctVal:SetTextColor(1.0, 0.30, 0.30)
				sep._hdrRankPctVal:Show()
				sep._decayArrow:Show()
			else
				sep._hdrRankPct:Hide()
				sep._hdrRankIcon:Hide()
				sep._hdrRankPctVal:Hide()
				sep._decayArrow:Hide()
			end
			yOff = yOff + DATESEP_H
			end  -- if not _weekCollapsed
		end

		if not _weekCollapsed[weeksAgo] then
		if not _dayCollapsed[dk] then
		if _VS.compactMode == 3 then
		-- Super compact: one row per category per day, rendered once
		if not _scRendered[dk] then
			_scRendered[dk] = true
			yOff = _VS.renderSC(dk, _dayGroupsMap[dk] or {}, yOff, _VS.hideZero)
		end
		elseif not (_VS.hideZero and g.total == 0 and (g.chainedRankGain or 0) == 0) then
		-- Group header button
		local gKey = g.gKey
		if _collapsed[gKey] == nil then
			_collapsed[gKey] = (gi ~= 1)
		end
		local isOpen = not _collapsed[gKey]
		local cat    = GroupCat(g)
		local cr, cg_c, cb = CatColor(cat)
		local gTip   = BuildGroupTip(g)

		local btn = AcquireHdrBtn()
		btn:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -yOff)

		-- Left-edge stripe: tinted green/red for BG win/loss, grey for no-result BG, otherwise category color
		local sr, sg_s, sb = cr, cg_c, cb
		local stripeAlpha, stripeWidth
		if g.isBG and g.result == "win" then
			sr, sg_s, sb = 0.302, 1.0, 0.302  -- matches day/week 4dff4d
			stripeAlpha = isOpen and 0.90 or 0.55
			stripeWidth = isOpen and 5 or 3
		elseif g.isBG and g.result == "loss" then
			sr, sg_s, sb = 1.0, 0.302, 0.302  -- matches day/week ff4d4d
			stripeAlpha = isOpen and 0.90 or 0.55
			stripeWidth = isOpen and 5 or 3
		elseif g.isBG and not g.result then
			sr, sg_s, sb = 0.55, 0.55, 0.55
			stripeAlpha = isOpen and 0.50 or 0.20
			stripeWidth = isOpen and 5 or 3
		else
			stripeAlpha = isOpen and 0.90 or 0.55
			stripeWidth = isOpen and 5 or 3
		end
		btn._stripe:SetWidth(stripeWidth)
		btn._stripe:SetVertexColor(sr, sg_s, sb)
		btn._stripe:SetAlpha(stripeAlpha)

		-- BG mark icon on header for BG groups; fallback icons for turnin/world
		local hdrMarkTex = _BG_MARK_ICON[g.zone]
		local hdrTexCoordX1, hdrTexCoordX2, hdrTexCoordY1, hdrTexCoordY2 = 0.05, 0.95, 0.05, 0.95
		if not hdrMarkTex then
			if g.isTurnin then
				hdrMarkTex = "Interface\\Icons\\INV_Misc_Coin_04"
			else
				hdrMarkTex = _factionPvPTex
				hdrTexCoordX1, hdrTexCoordX2, hdrTexCoordY1, hdrTexCoordY2 = 0.05, 0.95, 0.05, 0.95
			end
		end
		if hdrMarkTex then
			btn._ico:SetTexture(hdrMarkTex)
			btn._ico:SetTexCoord(hdrTexCoordX1, hdrTexCoordX2, hdrTexCoordY1, hdrTexCoordY2)
			btn._ico:Show()
		else
			btn._ico:Hide()
		end

		-- Zone label with time inline
		local label = g.zone or "Unknown"
		btn._fs:SetText(label .. " |cff505050" .. FmtTime(g.startT) .. "|r")
		btn._fs:SetTextColor(cr, cg_c, cb)
		btn._rt:Hide()
		btn._ra:SetText("|cffddbb44+" .. FmtHonor(g.total) .. "|r")

-- Rank progression gain
			local grpRankGain = g.chainedRankGain or 0
			-- _ra always flush right; _rp to its left when gain>0; no rank icon/pct on group rows
			btn._rankIcon:Hide()
			btn._rankPctVal:Hide()
			btn._ra:ClearAllPoints()
			btn._ra:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -14, -2)
			if grpRankGain > 0.00005 then
				btn._rp:SetText("+" .. string.format("%.2f", grpRankGain * 100) .. "%")
				btn._rp:ClearAllPoints()
				btn._rp:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -82, -2)
				btn._rp:Show()
				btn._fs:ClearAllPoints()
				btn._fs:SetPoint("TOPLEFT",  btn, "TOPLEFT",  22, -2)
				btn._fs:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -136, -2)
			else
				btn._rp:Hide()
				btn._fs:ClearAllPoints()
				btn._fs:SetPoint("TOPLEFT",  btn, "TOPLEFT",  22, -2)
				btn._fs:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -68, -2)
			end
			local amtOffset = -18  -- aligns with _hdrAmt column on day/week seps

		btn._tip = gTip
		local capturedKey = gKey
		btn:SetScript("OnClick", function()
			_collapsed[capturedKey] = not _collapsed[capturedKey]
			RefreshList()
		end)

		yOff = yOff + 16

		-- Entry rows (shown when group is expanded)
		if isOpen then
			local hz = _VS.hideZero and (g.chainedRankGain or 0) == 0
			yOff = RenderEntries(g.entries, yOff, cr, cg_c, cb, amtOffset, hz)
		end
		end  -- if _VS.compactMode / _VS.hideZero group
		end  -- if not _dayCollapsed
		end  -- if not _weekCollapsed
		_prevWeeksAgo = weeksAgo
	end

	content:SetHeight(math.abs(yOff) + 10)
	sf:UpdateScrollChildRect()
	if updateThumb then updateThumb() end
end
function THSE:HistoryRefresh()
	if not Win or not Win:IsVisible() then return end
	RefreshList()
end

function THSE:HistoryGetBGScoreRank()
	return _bgScoreRank
end

-- ===== Create window =====
local function CreateHistoryWindow()
	-- Restore persisted view state
	local hs = GetDB()
	if hs then
		if hs.histCompactMode then _VS.compactMode = hs.histCompactMode end
		if hs.histHideZero then _VS.hideZero = hs.histHideZero end
		-- Restore collapse state, then link tables so mutations auto-persist
		if hs.histDayCollapsed then
			for k, v in pairs(hs.histDayCollapsed) do _dayCollapsed[k] = v end
		end
		if hs.histWeekCollapsed then
			for k, v in pairs(hs.histWeekCollapsed) do _weekCollapsed[k] = v end
		end
		hs.histDayCollapsed  = _dayCollapsed
		hs.histWeekCollapsed = _weekCollapsed
	end
	Win = CreateFrame("Frame", "HonorHistoryFrame", UIParent)
	Win:SetWidth(WIN_W)
	Win:SetHeight(WIN_H)
	Win:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
	Win:SetFrameStrata("HIGH")
	Win:SetFrameLevel(10)
	Win:SetMovable(true)
	Win:EnableMouse(true)
	Win:SetClampedToScreen(true)
	Win:SetBackdrop({
		bgFile   = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	Win:SetBackdropColor(0, 0, 0, 0.8)
	Win:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
	Win:RegisterForDrag("LeftButton")
	Win:SetScript("OnDragStart", function() this:StartMoving() end)
	Win:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
	Win:EnableMouseWheel(true)
	Win:SetScript("OnMouseWheel", function() ScrollByDelta(arg1) end)
	Win:Hide()

	-- Title — centered in the header
	local title = Win:CreateFontString(nil, "OVERLAY")
	title:SetFont(FONT, 14, "OUTLINE")
	title:SetPoint("TOP", Win, "TOP", 0, -7)
	title:SetJustifyH("CENTER")
	title:SetTextColor(1.0, 0.82, 0.0)
	title:SetText("Honor History")

	-- Faction badge — 18×18, top-left corner
	local badge = Win:CreateTexture(nil, "OVERLAY")
	badge:SetWidth(26); badge:SetHeight(26)
	badge:SetPoint("TOPLEFT", Win, "TOPLEFT", -6, 2)

	local function UpdateBadge()
		local f, _ = UnitFactionGroup("player")
		if f == "Horde" then
			badge:SetTexture("Interface\\TargetingFrame\\UI-PVP-Horde")
		else
			badge:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")
		end
		badge:SetTexCoord(0.09, 0.63, 0.05, 0.63)
	end
	UpdateBadge()

	-- Close button
	local closeBtn = CreateFrame("Button", nil, Win, "UIPanelCloseButton")
	closeBtn:SetWidth(20); closeBtn:SetHeight(20)
	closeBtn:SetPoint("TOPRIGHT", Win, "TOPRIGHT", -2, -4)
	closeBtn:SetScript("OnClick", function() Win:Hide() end)

	-- Title divider
	local titleDiv = Win:CreateTexture(nil, "ARTWORK")
	titleDiv:SetTexture(1, 1, 1, 0.15)
	titleDiv:SetHeight(1)
	titleDiv:SetPoint("TOPLEFT",  Win, "TOPLEFT",  6, -27)
	titleDiv:SetPoint("TOPRIGHT", Win, "TOPRIGHT", -6, -27)

	-- Shared helper: overlay-style small icon button
	local function MakeTitleBtn(label, xOffset)
		local btn = CreateFrame("Button", nil, Win)
		btn:SetWidth(14); btn:SetHeight(14)
		btn:SetPoint("TOPRIGHT", Win, "TOPRIGHT", xOffset, -7)
		btn:SetBackdrop({
			bgFile   = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			edgeSize = 6,
			insets   = { left = 1, right = 1, top = 1, bottom = 1 },
		})
		btn:SetBackdropColor(0.10, 0.10, 0.10, 0.85)
		btn:SetBackdropBorderColor(0.45, 0.45, 0.45, 1.0)
		local fs = btn:CreateFontString(nil, "OVERLAY")
		fs:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
		fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
		fs:SetJustifyH("CENTER")
		fs:SetText(label)
		fs:SetTextColor(0.80, 0.65, 0.10)
		btn._fs = fs
		btn:SetScript("OnEnter", function()
			btn:SetBackdropBorderColor(0.75, 0.75, 0.75, 1.0)
			fs:SetTextColor(1.0, 0.85, 0.20)
			if btn._tipTitle then
				GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
				GameTooltip:ClearLines()
				GameTooltip:AddLine(btn._tipTitle, 1, 0.82, 0)
				if btn._tipDesc then
					GameTooltip:AddLine(btn._tipDesc, 0.6, 0.6, 0.6)
				end
				GameTooltip:Show()
			end
		end)
		btn:SetScript("OnLeave", function()
			btn:SetBackdropBorderColor(0.45, 0.45, 0.45, 1.0)
			if btn._activeColor then
				fs:SetTextColor(btn._activeColor[1], btn._activeColor[2], btn._activeColor[3])
			else
				fs:SetTextColor(0.80, 0.65, 0.10)
			end
			GameTooltip:Hide()
		end)
		return btn, fs
	end

	-- Expand/Collapse All button
	local expandBtn, expandFS = MakeTitleBtn("-", -26)
	expandBtn._tipTitle = "Collapse All"
	expandBtn._tipDesc  = "Collapses all open days and groups."

	local function SetExpandIcon(canCollapse)
		if canCollapse then
			expandFS:SetText("-")
			expandBtn._tipTitle = "Collapse All"
			expandBtn._tipDesc  = "Collapses all open days and groups."
		else
			expandFS:SetText("+")
			expandBtn._tipTitle = "Expand"
			expandBtn._tipDesc  = "Expands all weeks and today."
		end
	end

	expandBtn:SetScript("OnClick", function()
		-- Stage 1: are any group details open?
		local anyGroupOpen = false
		for _, v in pairs(_collapsed) do
			if not v then anyGroupOpen = true; break end
		end
		if anyGroupOpen then
			for k, _ in pairs(_collapsed) do _collapsed[k] = true end
			RefreshList()
			return
		end
		-- Stage 2: is today's day section open?
		local todayDK = date("%a %d %b", time()) .. "|0"
		if not _dayCollapsed[todayDK] and _knownDays[todayDK] then
			_dayCollapsed[todayDK] = true
			RefreshList()
			return
		end
		-- Stage 3: are any weeks open?
		local anyWeekOpen = false
		for wa, _ in pairs(_VS.knownWeeks) do
			if not _weekCollapsed[wa] then anyWeekOpen = true; break end
		end
		if anyWeekOpen then
			for wa, _ in pairs(_VS.knownWeeks) do
				_weekCollapsed[wa] = true
			end
			RefreshList()
			return
		end
		-- Everything collapsed — expand weeks + today's day only
		for wa, _ in pairs(_VS.knownWeeks) do
			_weekCollapsed[wa] = false
		end
		_dayCollapsed[todayDK] = false
		RefreshList()
	end)
	SetExpandIcon(true)

	-- Hide +0 toggle button
	local zeroBtn, zeroFS = MakeTitleBtn("0", -44)
	zeroBtn._tipTitle = "Hide Zero Entries"
	zeroBtn._tipDesc  = "Hides sessions where no honor was earned."

	local function UpdateZeroBtn()
		if _VS.hideZero then
			zeroFS:SetTextColor(0.25, 0.85, 0.25)
			zeroBtn._activeColor = { 0.25, 0.85, 0.25 }
			zeroBtn._tipTitle = "Show Zero Entries"
			zeroBtn._tipDesc  = "Currently hiding sessions with no honor. Click to show them."
		else
			zeroFS:SetTextColor(0.80, 0.65, 0.10)
			zeroBtn._activeColor = nil
			zeroBtn._tipTitle = "Hide Zero Entries"
			zeroBtn._tipDesc  = "Hides sessions where no honor was earned."
		end
	end
	zeroBtn:SetScript("OnEnter", function()
		zeroBtn:SetBackdropBorderColor(0.75, 0.75, 0.75, 1.0)
		zeroFS:SetTextColor(1.0, 0.85, 0.20)
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(zeroBtn._tipTitle, 1, 0.82, 0)
		GameTooltip:AddLine(zeroBtn._tipDesc, 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	zeroBtn:SetScript("OnLeave", function()
		zeroBtn:SetBackdropBorderColor(0.45, 0.45, 0.45, 1.0)
		UpdateZeroBtn()
		GameTooltip:Hide()
	end)
	zeroBtn:SetScript("OnClick", function()
		_VS.hideZero = not _VS.hideZero
		local _hs = GetDB()
		if _hs then _hs.histHideZero = _VS.hideZero end
		UpdateZeroBtn()
		RefreshList()
	end)
	UpdateZeroBtn()

	-- Compact Entries toggle button (cycles: off → compact → merged → super compact → off)
	local compactBtn, compactFS = MakeTitleBtn("C", -62)
	compactBtn._tipTitle = "Compact Entries"
	compactBtn._tipDesc  = "Merges consecutive similar entries into summary rows."

	local function UpdateCompactBtn()
		if _VS.compactMode == 3 then
			compactFS:SetText("S")
			compactFS:SetTextColor(0.55, 0.80, 1.0)
			compactBtn._activeColor = { 0.55, 0.80, 1.0 }
			compactBtn._tipTitle = "Super Compact"
			compactBtn._tipDesc  = "One row per category per day. Click to return to normal."
		elseif _VS.compactMode == 2 then
			compactFS:SetText("M")
			compactFS:SetTextColor(0.85, 0.55, 1.0)
			compactBtn._activeColor = { 0.85, 0.55, 1.0 }
			compactBtn._tipTitle = "Merged Compact"
			compactBtn._tipDesc  = "One row per source type per session. Click for super compact."
		elseif _VS.compactMode == 1 then
			compactFS:SetText("C")
			compactFS:SetTextColor(0.25, 0.85, 0.25)
			compactBtn._activeColor = { 0.25, 0.85, 0.25 }
			compactBtn._tipTitle = "Compact Entries"
			compactBtn._tipDesc  = "Compacting consecutive entries. Click for merged compact."
		else
			compactFS:SetText("C")
			compactFS:SetTextColor(0.80, 0.65, 0.10)
			compactBtn._activeColor = nil
			compactBtn._tipTitle = "Compact Entries"
			compactBtn._tipDesc  = "Merges consecutive similar entries into summary rows."
		end
	end
	compactBtn:SetScript("OnEnter", function()
		compactBtn:SetBackdropBorderColor(0.75, 0.75, 0.75, 1.0)
		compactFS:SetTextColor(1.0, 0.85, 0.20)
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(compactBtn._tipTitle, 1, 0.82, 0)
		GameTooltip:AddLine(compactBtn._tipDesc, 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	compactBtn:SetScript("OnLeave", function()
		compactBtn:SetBackdropBorderColor(0.45, 0.45, 0.45, 1.0)
		UpdateCompactBtn()
		GameTooltip:Hide()
	end)
	compactBtn:SetScript("OnClick", function()
		_VS.compactMode = math.mod(_VS.compactMode + 1, 4)
		local _hs = GetDB()
		if _hs then _hs.histCompactMode = _VS.compactMode end
		UpdateCompactBtn()
		RefreshList()
	end)
	UpdateCompactBtn()

	-- Column header bar (sits between title divider and scroll frame)
	local colHdr = CreateFrame("Frame", nil, Win)
	colHdr:SetPoint("TOPLEFT",  Win, "TOPLEFT",     6,  -28)
	colHdr:SetPoint("TOPRIGHT", Win, "TOPRIGHT",   -16,  -28)
	colHdr:SetHeight(16)
	local colHdrBg = colHdr:CreateTexture(nil, "BACKGROUND")
	colHdrBg:SetAllPoints(colHdr)
	colHdrBg:SetTexture(0, 0, 0, 0.15)
	local function MakeColLabel(text, rightOffset, width)
		local fs = colHdr:CreateFontString(nil, "OVERLAY")
		fs:SetFont(FONT, 9)
		fs:SetJustifyH("RIGHT")
		fs:SetWidth(width)
		fs:SetPoint("TOPRIGHT", colHdr, "TOPRIGHT", rightOffset, -4)
		fs:SetTextColor(0.55, 0.55, 0.55)
		fs:SetText(text)
		return fs
	end
	MakeColLabel("Wins",    COL_WL,    48)
	MakeColLabel("Win %",   COL_PCT,   40)
	MakeColLabel("Rank",    COL_RKVAL, 60)
	MakeColLabel("Gain %",  COL_GAIN,  54)
	MakeColLabel("Honor",   COL_HONOR, 56)

-- Scroll frame (plain; thin custom scrollbar drawn by MakeThinScrollbar)
	sf = CreateFrame("ScrollFrame", "HonorHistoryScrollFrame", Win)
	sf:SetPoint("TOPLEFT",     Win, "TOPLEFT",     6,  -44)
	sf:SetPoint("BOTTOMRIGHT", Win, "BOTTOMRIGHT", -12,   6)
	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", function() ScrollByDelta(arg1) end)

	content = CreateFrame("Frame", nil, sf)
	content:SetWidth(CONTENT_W)
	content:SetHeight(1)
	sf:SetScrollChild(content)

	-- vH = WIN_H - header(28)
	local SCROLL_VH = WIN_H - 50  -- header(28) + colHdr(16) + bottom(6)
	updateThumb = MakeThinScrollbar(Win, sf, content, SCROLL_VH)
end

-- ===== Event frame =====
local _ef = CreateFrame("Frame", "HonorHistoryEventFrame")
_ef:RegisterEvent("PLAYER_ENTERING_WORLD")
_ef:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")  -- kill + award messages
_ef:RegisterEvent("QUEST_TURNED_IN")
_ef:RegisterEvent("CHAT_MSG_SYSTEM")                  -- "You have been awarded X honor points."
_ef:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
_ef:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
_ef:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
_ef:RegisterEvent("UPDATE_FACTION")                   -- rank progress updates
_ef:RegisterEvent("ZONE_CHANGED_NEW_AREA")              -- BG exit detection
_ef:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")            -- BG scoreboard data arrived

local _pendingQuest   = nil
local _pendingQuestTs = nil
local PENDING_TTL     = 2  -- seconds
local _lastBGZone     = nil  -- tracks which BG zone we are inside

_ef:SetScript("OnEvent", function()
	local hs = GetDB()

	if event == "PLAYER_ENTERING_WORLD" then
		if hs and not hs.honorHistory then hs.honorHistory = {} end
		-- Initialise BG zone tracker
		local z = GetRealZoneText()
		_lastBGZone = IsBGZone(z) and z or nil
		-- Prime BG scoreboard cache
		if _lastBGZone then
			if RequestBattlefieldScoreData then RequestBattlefieldScoreData() end
			RefreshBGScoreCache()
		end

	elseif event == "ZONE_CHANGED_NEW_AREA" then
		local z = GetRealZoneText()
		if _lastBGZone and not IsBGZone(z) then
			-- Left a BG zone → insert boundary marker
			if hs and hs.honorHistory then
				local e = { t = time(), type = "bgexit", zone = _lastBGZone, amount = 0 }
				table.insert(hs.honorHistory, 1, e)
				TrimHistory(hs)
			end
		end
		_lastBGZone = IsBGZone(z) and z or nil
		-- Request scoreboard data when entering a BG
		if _lastBGZone and RequestBattlefieldScoreData then
			RequestBattlefieldScoreData()
		end

	elseif event == "UPDATE_BATTLEFIELD_SCORE" then
		RefreshBGScoreCache()
		-- Backfill unresolved victim ranks on recent kill entries
		if hs and hs.honorHistory then
			local filled = 0
			for i = 1, math.min(table.getn(hs.honorHistory), 200) do
				local e = hs.honorHistory[i]
				if e.type == "kill" and e.victim and not e.victimRank then
					local rk = _bgScoreRank[e.victim] or _bgScoreRank[string.gsub(e.victim, "%-.*", "")]
					if rk then e.victimRank = rk; filled = filled + 1 end
				end
			end
			if filled > 0 and Win and Win:IsVisible() then RefreshList() end
		end

	elseif event == "UPDATE_FACTION" then
		-- Rank progress update — create a tick entry when progress changes.
		-- Guard: skip if API hasn't loaded yet (returns 0 on login/reload).
		local newPct = GetPVPRankProgress() or 0
		if newPct > 0.0001 and hs and hs.honorHistory and table.getn(hs.honorHistory) > 0 then
			local newest = hs.honorHistory[1]
			if newest.type ~= "bgresult" and newest.type ~= "bgexit" and newest.type ~= "tick" then
				local prevPct = newest.rankPct or 0
				-- Skip if no valid baseline (first load / corrupted entry)
				-- Also require a meaningful change (> 0.01%) to avoid float noise on reload
				-- Skip negative deltas (weekly decay) — never record rank loss as a tick
				if prevPct > 0.0001 and (newPct - prevPct) > 0.0001 then
					if not hs.honorHistory then hs.honorHistory = {} end
					local thisW_hk, thisW_h = 0, 0
					if GetPVPThisWeekStats then
						thisW_hk, thisW_h = GetPVPThisWeekStats()
					end
					local te = {
						t = time(),
						type = "tick",
						amount = 0,
						zone = GetRealZoneText(),
						rankPct = newPct,
						prevRankPct = prevPct,
						rankNum = UnitPVPRank("player") or 0,
						tickHaHq = thisW_h or 0,
						tickHk = thisW_hk or 0,
					}
					table.insert(hs.honorHistory, 1, te)
					TrimHistory(hs)
					if Win and Win:IsVisible() then RefreshList() end
				end
			end
		end

	elseif event == "CHAT_MSG_BG_SYSTEM_NEUTRAL"
		or event == "CHAT_MSG_BG_SYSTEM_ALLIANCE"
		or event == "CHAT_MSG_BG_SYSTEM_HORDE" then
		if not hs then return end
		if not hs.honorHistory then hs.honorHistory = {} end
		local msg = string.lower(arg1 or "")
		local result = nil
		local hasWin = string.find(msg, "win") or string.find(msg, "victori") or string.find(msg, "conquer")
		local hasLoss = string.find(msg, "defea") or string.find(msg, "lost the battle")
		if hasWin and not hasLoss then
			-- "wins" appears in both "Alliance wins" and "Horde wins", so
			-- compare which faction is winning against the player's own faction.
			local playerFaction = string.lower(UnitFactionGroup("player") or "")
			local factionInMsg = nil
			if string.find(msg, "alliance") then factionInMsg = "alliance" end
			if string.find(msg, "horde")    then factionInMsg = "horde"    end
			if factionInMsg and playerFaction ~= "" and factionInMsg ~= playerFaction then
				result = "loss"
			else
				result = "win"
			end
		elseif hasLoss then
			result = "loss"
		end
		if result then
			local zone = GetRealZoneText()
			local e = { t = time(), type = "bgresult", result = result,
				zone = zone, amount = 0 }
			table.insert(hs.honorHistory, 1, e)
			TrimHistory(hs)
		end

	elseif event == "QUEST_TURNED_IN" then
		-- arg1=questName; set pending so next CHAT_MSG_COMBAT_HONOR_GAIN becomes turnin
		_pendingQuest   = arg1
		_pendingQuestTs = time()

	elseif event == "CHAT_MSG_SYSTEM" then
		local msg = arg1 or ""
		local lmsg = string.lower(msg)

		-- "You have been awarded X honor points."
		local _, _, awardedStr = string.find(lmsg, "awarded (%d+) honor")
		if awardedStr then
			if not hs then return end
			if not hs.honorHistory then hs.honorHistory = {} end
			local amount = tonumber(awardedStr) or 0
			local zone   = GetRealZoneText()
			local isPending = _pendingQuest and _pendingQuestTs
				and (time() - _pendingQuestTs) <= PENDING_TTL
			local entryType, questName
			if isPending then
				entryType = "turnin"
				questName = _pendingQuest
				_pendingQuest = nil; _pendingQuestTs = nil
			elseif IsBGZone(zone) then
				entryType = "award"
			else
				entryType = "award"
			end
			local e = { t=time(), type=entryType, amount=amount, zone=zone, questName=questName,
				rankPct=GetPVPRankProgress() or 0, rankNum=UnitPVPRank("player") or 0 }
			table.insert(hs.honorHistory, 1, e)
			TrimHistory(hs)
			if Win and Win:IsVisible() then RefreshList() end
			return
		end

		-- Quest turn-in fallback: "X completed."
		if string.find(lmsg, "completed") then
			-- Check for Concerted Efforts / For Great Honor by name first
			local foundConcerted = nil
			for qname, _ in pairs(_CONCERTED_QUEST) do
				if string.find(lmsg, string.lower(qname), 1, true) then
					foundConcerted = qname
					break
				end
			end
			if foundConcerted then
				_pendingQuest   = foundConcerted
				_pendingQuestTs = time()
			else
				local bg = QuestToBG(msg)
				if bg then
					_pendingQuest   = bg
					_pendingQuestTs = time()
				end
			end
		end

	elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
		-- Handles:
		--   "X dies, honorable kill Rank: Y  (Estimated Honor Points: N)"
		--   "You have been awarded X honor points."
		--   "You gain X honor..."  (Turtle WoW fallback)
		if not hs then return end
		if not hs.honorHistory then hs.honorHistory = {} end
		local msg = arg1 or ""
		local lmsg = string.lower(msg)

		-- Kill message: "X dies, honorable kill Rank: General  (Estimated Honor Points: N)"
		local _, _, v, r, n = string.find(msg,
			"(.+) dies, honorable kill Rank: ([^%(]+)%(Estimated Honor Points: (%d+)%)")
		if v and r and n then
			local victim = v
			local victimRank = string.gsub(r, "%s+$", "")
			local amount = tonumber(n) or 0
			local zone = GetRealZoneText()
			local e = { t=time(), type="kill", amount=amount, zone=zone,
				victim=victim, victimRank=victimRank, rankPct=GetPVPRankProgress() or 0, rankNum=UnitPVPRank("player") or 0 }
			table.insert(hs.honorHistory, 1, e)
			TrimHistory(hs)
			if Win and Win:IsVisible() then RefreshList() end
			return
		end

		-- Zero-honor kill: "X dies, dishonorable kill." (server text for kills beyond 20k HKs)
		local _, _, dv = string.find(msg, "(.+) dies, dishonorable kill")
		if dv then
			local zone = GetRealZoneText()
			local victimRank = ScoreboardRank(dv)
			local e = { t=time(), type="kill", amount=0, zone=zone,
				victim=dv, victimRank=victimRank, rankPct=GetPVPRankProgress() or 0, rankNum=UnitPVPRank("player") or 0 }
			table.insert(hs.honorHistory, 1, e)
			TrimHistory(hs)
			if Win and Win:IsVisible() then RefreshList() end
			return
		end

		-- Award/gain message
		local _, _, a = string.find(lmsg, "awarded (%d+) honor")
		if not a then
			_, _, a = string.find(lmsg, "you gain (%d+) honor")
		end
		if not a then return end
		local amount = tonumber(a) or 0
		local zone = GetRealZoneText()
		local isPending = _pendingQuest and _pendingQuestTs
			and (time() - _pendingQuestTs) <= PENDING_TTL
		local entryType, questName
		if isPending then
			entryType = "turnin"; questName = _pendingQuest
			_pendingQuest = nil; _pendingQuestTs = nil
		elseif IsBGZone(zone) then
			entryType = "award"
		else
			entryType = "kill"
		end
		local _, _, rk, vn = string.find(msg, "[Kk]illing the (%a[%a ]+) (%a+)%.")
		local victim, victimRank
		if rk and vn then victimRank=rk; victim=vn
		else
			local _, _, vName = string.find(msg, "[Kk]illing (%a[%a ]+)%.")
			if vName then victim=vName end
		end
		local e = { t=time(), type=entryType, amount=amount, zone=zone,
			victim=victim, victimRank=victimRank, questName=questName,
			rankPct=GetPVPRankProgress() or 0, rankNum=UnitPVPRank("player") or 0 }
		table.insert(hs.honorHistory, 1, e)
		TrimHistory(hs)
		if Win and Win:IsVisible() then RefreshList() end
	end
end)

-- ===== Public API =====
function THSE:HistoryOpen()
	if not Win then
		CreateHistoryWindow()
	end
	if Win:IsVisible() then
		Win:Hide()
	else
		Win:Show()
		RefreshList()
	end
end

function THSE:HistoryClose()
	if Win then Win:Hide() end
end
