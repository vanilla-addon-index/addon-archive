--[[ TalentAdvisor.lua -- the Talent Advisor: which talent each point goes to.

	Two builds a character: the levelling build for your class, followed
	until 60, then the build for your preferred spec -- the one picked on the
	Item Score page -- or whichever you choose. Some classes have another
	levelling build to choose instead (Protection, Bear). The builds are data, by
	talent name (TalentBuilds.lua, written by Tools/build/talent_builds.py),
	and each is checked against the tree the game has before it is followed:
	one that does not fit says so and is not followed.

	It only recommends; it never spends a point. Points spent where the build
	puts none (or more than it puts) are "off the build", and it carries on
	from the build's closest point. It never says to respec: at 60, with
	every point on the levelling build, it says your spec's build is ready
	for when you do.

	This is the engine: reading the tree, choosing the build, the next point,
	what is off the build, the lines it says, and the chat on a level up; and
	Modern Spellbook's share strings, a shared build to follow, and the ranks
	of a plan. TalentWindow.lua draws it on Blizzard's talent window,
	TalentModern.lua on Modern Spellbook's.
]]

local AegisPathfinder = AegisPathfinder

local TA = {}
AegisPathfinder.TalentAdvisor = TA

-- Points by 60: one a level from 10.
TA.POINTS = 51
TA.FIRST_LEVEL = 10

-- Item Score's specs that are not a talent tree's name.
local SPEC_TREE = {
	BeastMastery = "Beast Mastery",
	FeralCat = "Feral Combat", FeralBear = "Feral Combat",
	EnhancementTank = "Enhancement",
}

local function Char() return AegisPathfinder.db and AegisPathfinder.db.char end

--- The advisor's settings for this character: on, the build to follow
--- ("auto": levelling until 60, then your spec's), and the chat line.
function TA:Settings()
	local char = Char()
	if not char then return nil end
	if char.talentadvisor == nil then char.talentadvisor = true end
	if char.talentchat == nil then char.talentchat = true end
	char.talentbuild = char.talentbuild or "auto"
	-- A Warrior's or Paladin's shield build was called Sword and Board.
	char.talentbuild = string.gsub(char.talentbuild, ":Sword and Board$", ":Protection")
	return char
end

--[[ Builds ----------------------------------------------------------------------- ]]

--- A build's order -- talent, rank, talent, rank, ... -- as its points, one
--- talent name a point.
function TA.Expand(order)
	local points, have = {}, {}
	for i = 1, table.getn(order), 2 do
		local name, upto = order[i], order[i + 1]
		for _ = (have[name] or 0) + 1, upto do table.insert(points, name) end
		if upto > (have[name] or 0) then have[name] = upto end
	end
	return points
end

--- How many points each talent gets: { talent = ranks }.
function TA.Targets(points)
	local t = {}
	for _, name in ipairs(points) do t[name] = (t[name] or 0) + 1 end
	return t
end

--- A build's points, worked out once.
function TA.Points(build)
	if not build.points then build.points = TA.Expand(build.order) end
	return build.points
end

--- The builds for a class (a token: "WARRIOR").
function TA:ClassBuilds(class)
	if not class then
		local _
		_, class = UnitClass("player")
	end
	return AegisPathfinder.TalentBuilds and AegisPathfinder.TalentBuilds[class]
end

--- What a "Build to follow" choice is: "auto", "levelling" or a spec's
--- name, and the other levelling build it names, if any -- "auto:Bear" is
--- Bear until 60, then your spec's; "levelling:Bear" is Bear alone.
function TA.ParseChoice(choice)
	local _, _, kind, alt = string.find(choice or "auto", "^(%a+):(.+)$")
	if kind then return kind, alt end
	return choice or "auto", nil
end

--- The levelling build: the class's, or the other one named `alt`.
function TA.LevellingBuild(builds, alt)
	for _, b in ipairs(alt and builds.alts or {}) do
		if b.name == alt then return b end
	end
	return builds.levelling
end

--- A class's build at 60 for a spec, by its tree's name or Item Score's.
function TA.SpecBuild(builds, spec)
	if not (builds and spec) then return nil end
	spec = SPEC_TREE[spec] or spec
	for _, b in ipairs(builds.specs) do
		if b.spec == spec then return b end
	end
	return nil
end

--- Your preferred spec's build: the spec picked on the Item Score page, or
--- the one it works out from your talents.
function TA:PreferredBuild(builds)
	local IS = AegisPathfinder.ItemScore
	local spec = IS and IS.Spec and IS:Spec()
	return TA.SpecBuild(builds, spec)
end

--[[ The tree --------------------------------------------------------------------- ]]

--- The tree the game has, read from the talent API: { tabs = { { name,
--- talents } }, talent = { name -> { name, tab, index, tier, column, max,
--- rank, pre } } }. A talent's prerequisite is the one the client names
--- first, by name.
function TA.ReadTree()
	local tree = { tabs = {}, talent = {} }
	for tab = 1, (GetNumTalentTabs and GetNumTalentTabs() or 0) do
		local tabName = GetTalentTabInfo(tab)
		local at, list = {}, {}
		for i = 1, GetNumTalents(tab) do
			local name, icon, tier, column, rank, maxRank = GetTalentInfo(tab, i)
			if name then
				local t = { name = name, tab = tab, index = i, tier = tier, column = column,
					rank = rank or 0, max = maxRank or 1, icon = icon }
				t.preTier, t.preColumn = GetTalentPrereqs(tab, i)
				at[tier .. ":" .. column] = t
				tree.talent[name] = t
				table.insert(list, t)
			end
		end
		for _, t in ipairs(list) do
			local p = t.preTier and at[t.preTier .. ":" .. t.preColumn]
			t.pre = p and p.name or nil
		end
		tree.tabs[tab] = { name = tabName, talents = list }
	end
	return tree
end

--- The ranks you have: { talent = rank }, only those with a point.
function TA.Ranks(tree)
	local ranks = {}
	for name, t in pairs(tree.talent) do
		if t.rank > 0 then ranks[name] = t.rank end
	end
	return ranks
end

function TA.Total(ranks)
	local n = 0
	for _, r in pairs(ranks) do n = n + r end
	return n
end

--- Points spent in one tree.
function TA.Spent(tree, ranks, tab)
	local n = 0
	for name, r in pairs(ranks) do
		local t = tree.talent[name]
		if t and t.tab == tab then n = n + r end
	end
	return n
end

--- Whether a talent can take another point now: ranks left, 5 points in its
--- tree a row above it, its prerequisite at full rank.
function TA.CanLearn(tree, ranks, name)
	local t = tree.talent[name]
	if not t or (ranks[name] or 0) >= t.max then return false end
	if TA.Spent(tree, ranks, t.tab) < 5 * (t.tier - 1) then return false end
	if t.pre and (ranks[t.pre] or 0) < tree.talent[t.pre].max then return false end
	return true
end

--- Whether a build fits the tree: every talent in it, no more ranks than it
--- has, each point learnable in its order, and 51 of them (a shared build
--- may have fewer). Returns true, or false and why ("it has no Master
--- Strike").
function TA.Fits(tree, build)
	local ranks = {}
	local points = TA.Points(build)
	for _, name in ipairs(points) do
		local t = tree.talent[name]
		if not t then return false, "it has no " .. name end
		if (ranks[name] or 0) >= t.max then
			return false, name .. " has " .. t.max .. (t.max == 1 and " rank" or " ranks")
		end
		if not TA.CanLearn(tree, ranks, name) then
			return false, name .. " can't be learnt where the build puts it"
		end
		ranks[name] = (ranks[name] or 0) + 1
	end
	if not build.shared and table.getn(points) ~= TA.POINTS then
		return false, "it has " .. table.getn(points) .. " points, not " .. TA.POINTS
	end
	return true
end

--[[ Following a build ------------------------------------------------------------- ]]

--- The next point: the build's first point you do not have that you can
--- learn now. With points off the build a later point may come first, as
--- the closest one you can take. Returns the talent and the rank it goes
--- to; or nil and the talent that is waiting for more points in its tree.
function TA.Next(tree, ranks, points)
	local seen, waiting = {}, nil
	for _, name in ipairs(points) do
		seen[name] = (seen[name] or 0) + 1
		if seen[name] > (ranks[name] or 0) then
			waiting = waiting or name
			if TA.CanLearn(tree, ranks, name) then return name, (ranks[name] or 0) + 1 end
		end
	end
	return nil, waiting
end

--- The points you have that the build does not put there: { talent =
--- extra }, and how many in all.
function TA.Off(ranks, targets)
	local off, total = {}, 0
	for name, r in pairs(ranks) do
		local extra = r - (targets[name] or 0)
		if extra > 0 then
			off[name] = extra
			total = total + extra
		end
	end
	return off, total
end

--- The build to follow. `choice` is "auto", "levelling" or a spec's name,
--- either of the first two with ":" and another levelling build's name.
--- Auto follows the levelling build until 60, and at 60 while every point
--- you have is on it (then `ready` is true once all 51 are spent); after a
--- respec, or with points elsewhere, your preferred spec's.
function TA.Choose(builds, choice, preferred, level, ranks)
	if not builds then return nil end
	local kind, alt = TA.ParseChoice(choice)
	local lev = TA.LevellingBuild(builds, alt)
	if kind == "levelling" then return lev end
	if kind ~= "auto" then
		local b = TA.SpecBuild(builds, kind)
		if b then return b end
	end
	if not preferred or (level or 0) < 60 then return lev end
	local total = TA.Total(ranks)
	local _, off = TA.Off(ranks, TA.Targets(TA.Points(lev)))
	if total > 0 and off == 0 then return lev, total >= TA.POINTS end
	return preferred
end

-- What each build was found to be against the tree, for this session:
-- build -> { ok, why }. The tree does not change while you play.
TA.fit = {}

--- Everything the window and chat need, now: the build, whether it fits,
--- the next point, the targets, what is off the build, points to spend.
--- `tree`, `level` and `unspent` default to the game's.
function TA:State(tree, level, unspent)
	local s = self:Settings()
	local builds = self:ClassBuilds()
	if not (s and builds) then return nil end
	tree = tree or TA.ReadTree()
	-- No talents read (the client has not sent them yet): nothing to say,
	-- rather than a build found not to fit for the rest of the session.
	if not next(tree.talent) then return nil end
	level = level or UnitLevel("player")
	if not unspent then unspent = (UnitCharacterPoints("player")) or 0 end
	local ranks = TA.Ranks(tree)
	-- A shared build (Follow) when that is the choice and it reads; else as
	-- auto, which is what Choose makes of a choice it doesn't know.
	local build, ready = s.talentbuild == "shared" and self:SharedBuild(tree)
	if not build then
		build, ready = TA.Choose(builds, s.talentbuild, self:PreferredBuild(builds), level, ranks)
	end
	if not build then return nil end
	local fit = TA.fit[build]
	if not fit then
		local ok, why = TA.Fits(tree, build)
		fit = { ok = ok, why = why }
		TA.fit[build] = fit
	end
	local state = { tree = tree, ranks = ranks, build = build, ready = ready, level = level,
		unspent = unspent, fits = fit.ok, why = fit.why, builds = builds, choice = s.talentbuild }
	if not fit.ok then return state end
	local points = TA.Points(build)
	state.targets = TA.Targets(points)
	state.off, state.offTotal = TA.Off(ranks, state.targets)
	state.next, state.rank = TA.Next(tree, ranks, points)
	if not state.next then state.waiting = state.rank; state.rank = nil end
	return state
end

--[[ What it says ------------------------------------------------------------------ ]]

--- A build's name, as the window's menu and chat give it.
function TA.BuildLabel(builds, build, className)
	if build.shared then return "Shared build" end
	if build == builds.levelling then return (className or "Class") .. " leveling" end
	if build.name then return (className or "Class") .. " " .. build.name .. " leveling" end
	return build.spec .. " at 60"
end

--- On a level up with a point to spend.
function TA.LevelLine(level, talent, rank, max, treeName)
	return string.format("Level %d: a talent point to spend. Take %s (rank %d of %d) in %s.",
		level, talent, rank, max, treeName)
end

--- At 60 with all 51 points on the levelling build.
function TA.ReadyLine(spec)
	return "All 51 points are spent. Your " .. spec .. " build is ready for when you respec: "
		.. "pick it under Following on the talent window to see it."
end

--- When a build does not fit the tree the game has.
function TA.UnfitLine(label, why)
	return "The " .. label .. " build doesn't fit your talent tree (" .. why
		.. "), so the Talent Advisor won't follow it."
end

local function Points(n) return n .. (n == 1 and " point" or " points") end

--- The name of the build followed now: "Warrior leveling", "Fury at 60".
function TA:Label(state)
	return TA.BuildLabel(state.builds, state.build, (UnitClass("player")))
end

--- What "Leveling, then my spec at 60" says now -- or "Bear leveling, then
--- my spec at 60" for another levelling build `alt`: your spec by name, and
--- at 60 which of the two it is following.
function TA.AutoLabel(state, preferred, alt)
	local lead = alt and (alt .. " leveling") or "Leveling"
	if not preferred then return lead .. ", then my spec at 60" end
	local current = state and state.choice == (alt and "auto:" .. alt or "auto")
	if not current or (state.level or 0) < 60 then
		return lead .. ", then " .. preferred.spec .. " at 60"
	end
	if state.build ~= preferred then return lead .. " (done), then " .. preferred.spec end
	return preferred.spec .. ", my spec"
end

--- "Build to follow", as a dropdown's items: levelling then your spec (and
--- each other levelling build then your spec), the levelling builds alone,
--- and each spec's build at 60, yours marked.
function TA:BuildItems(state)
	local builds = state and state.builds or self:ClassBuilds()
	if not builds then return {} end
	local preferred = self:PreferredBuild(builds)
	local className = (UnitClass("player")) or "Class"
	local items = { { value = "auto", label = TA.AutoLabel(state, preferred) } }
	for _, a in ipairs(builds.alts or {}) do
		table.insert(items, { value = "auto:" .. a.name, label = TA.AutoLabel(state, preferred, a.name) })
	end
	table.insert(items, { value = "levelling", label = className .. " leveling" })
	for _, a in ipairs(builds.alts or {}) do
		table.insert(items, { value = "levelling:" .. a.name, label = className .. " " .. a.name .. " leveling" })
	end
	for _, b in ipairs(builds.specs) do
		table.insert(items, { value = b.spec, label = b.spec .. " at 60" .. (b == preferred and " (my spec)" or "") })
	end
	local s = self:Settings()
	if s and s.talentshared then table.insert(items, { value = "shared", label = "Shared build" }) end
	return items
end

--- What the strip over the talent window says: where the next point goes,
--- and how many points are off the build (or why the build is not
--- followed). Returns the line and the warning, either may be nil.
function TA:StripLines(state)
	if not state.fits then return nil, TA.UnfitLine(self:Label(state), state.why) end
	local line
	local preferred = self:PreferredBuild(state.builds)
	local t = state.next and state.tree.talent[state.next]
	if state.ready and preferred then
		line = "All 51 points spent. Your " .. preferred.spec .. " build is ready for when you respec."
	elseif state.waiting then
		line = state.waiting .. " needs more points in its tree first."
	elseif not t then
		line = "Every point of this build is spent."
	elseif state.unspent > 0 then
		line = "Next: " .. state.next .. ", rank " .. state.rank .. " of " .. t.max
			.. (state.unspent > 1 and " (" .. state.unspent .. " points to spend)" or "")
	elseif state.level < 60 then
		line = "Your point at level " .. (state.level + 1) .. " goes to " .. state.next .. "."
	else
		line = "Next, after a respec: " .. state.next .. "."
	end
	local warn
	if (state.offTotal or 0) > 0 then
		warn = Points(state.offTotal) .. " off the build. It carries on from the closest point."
	end
	return line, warn
end

--- The card over the window for the next point: its title, the line under
--- it, and the talent's icon -- "Take Shield Slam", "Rank 1 of 1 in
--- Protection · 1 point to spend". Short, to fit the window. Nil with no
--- next point to name.
function TA:NextCard(state)
	if not (state.fits and state.next) or state.ready then return nil end
	local t = state.tree.talent[state.next]
	local where = "Rank " .. state.rank .. " of " .. t.max .. " in " .. state.tree.tabs[t.tab].name
	if state.unspent > 0 then
		return "Take " .. state.next, where .. " · " .. Points(state.unspent) .. " to spend", t.icon
	elseif state.level < 60 then
		return "Next: " .. state.next, where .. " · at level " .. (state.level + 1), t.icon
	end
	return "After a respec: " .. state.next, where, t.icon
end

--- How a talent is marked on the window: "todo" with the points the build
--- puts there, "done" once you have them all, "off" with the points you
--- have past them; nil for a talent the build leaves alone. And whether
--- the next point goes there.
function TA.Mark(state, name)
	local have, want = state.ranks[name] or 0, state.targets[name] or 0
	local kind, text
	if have > want then
		kind, text = "off", "+" .. (have - want)
	elseif want > 0 then
		kind, text = have >= want and "done" or "todo", tostring(want)
	end
	return kind, text, state.next == name
end

--- The advisor's lines on a talent's tooltip.
function TA:TipLines(state, name)
	local lines = {}
	local have, want = state.ranks[name] or 0, state.targets[name] or 0
	local label = self:Label(state)
	if want > 0 then
		local line = label .. " puts " .. Points(want) .. " here"
		if have > want then line = line .. "; you have " .. have
		elseif have == want then line = line .. ": done" end
		table.insert(lines, "Pathfinder: " .. line .. ".")
	elseif have > 0 then
		table.insert(lines, "Pathfinder: " .. label .. " puts no points here.")
	end
	if state.next == name then table.insert(lines, "Your next point goes here.") end
	return lines
end

--[[ Modern Spellbook's strings and plans ------------------------------------------

	Modern Spellbook (github.com/lioryx/ModernSpellBook) shares a build as
	"MSB1-<CLASS>-<tree 1>-<tree 2>-<tree 3>": each tree a digit a talent, its
	rank, in the order the game numbers the tree's talents. Its plans are
	ranks by tree and talent number, which its Apply learns. ]]

local function Trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end

--- `ranks` ({ talent = rank }) as a share string for `class` ("WARRIOR").
function TA.ShareString(tree, class, ranks)
	local parts = { "MSB1", class }
	for tab = 1, table.getn(tree.tabs) do
		local digits, n = {}, 0
		for _, t in ipairs(tree.tabs[tab].talents) do
			digits[t.index] = math.min(9, ranks[t.name] or 0)
			if t.index > n then n = t.index end
		end
		for i = 1, n do digits[i] = digits[i] or 0 end
		table.insert(parts, table.concat(digits))
	end
	return table.concat(parts, "-")
end

--- A share string read against the tree: { talent = rank } and how many
--- points; or nil and why: "class" for another class's, "format" for
--- anything else (not one, no points, more than 51).
function TA.ReadShare(tree, class, text)
	local parts = {}
	for part in string.gfind(Trim(text) .. "-", "([^%-]*)%-") do table.insert(parts, part) end
	if parts[1] ~= "MSB1" then return nil, "format" end
	if parts[2] ~= class then return nil, "class" end
	local ranks, total = {}, 0
	for tab = 1, table.getn(tree.tabs) do
		local digits = parts[tab + 2] or ""
		for _, t in ipairs(tree.tabs[tab].talents) do
			local r = math.min(tonumber(string.sub(digits, t.index, t.index)) or 0, t.max)
			if r > 0 then
				ranks[t.name] = r
				total = total + r
			end
		end
	end
	if total == 0 or total > TA.POINTS then return nil, "format" end
	return ranks, total
end

--- One row's talents in the order to take them: by column, a prerequisite
--- before the talent that needs it -- Turtle WoW has some in the same row
--- (Holy's Divine Favor needs Holy Shock, beside it).
local function RowOrder(row)
	local inRow, placed, out = {}, {}, {}
	for _, t in ipairs(row) do inRow[t.name] = true end
	local left = table.getn(row)
	while left > 0 do
		local moved = false
		for _, t in ipairs(row) do
			if not placed[t.name] and not (t.pre and inRow[t.pre] and not placed[t.pre]) then
				placed[t.name], left, moved = true, left - 1, true
				table.insert(out, t)
			end
		end
		-- Whatever is left can't be ordered so; Fits says why.
		if not moved then
			for _, t in ipairs(row) do
				if not placed[t.name] then
					placed[t.name] = true
					table.insert(out, t)
				end
			end
			left = 0
		end
	end
	return out
end

--- A shared build: its ranks in the order to take them -- the tree with the
--- most points first, a row at a time.
function TA.ShareBuild(tree, ranks)
	local tabs = {}
	for tab = 1, table.getn(tree.tabs) do
		table.insert(tabs, { tab = tab, spent = TA.Spent(tree, ranks, tab) })
	end
	table.sort(tabs, function(a, b)
		if a.spent ~= b.spent then return a.spent > b.spent end
		return a.tab < b.tab
	end)
	local order = {}
	for _, e in ipairs(tabs) do
		local list = {}
		for _, t in ipairs(tree.tabs[e.tab].talents) do
			if ranks[t.name] then table.insert(list, t) end
		end
		table.sort(list, function(a, b)
			if a.tier ~= b.tier then return a.tier < b.tier end
			return a.column < b.column
		end)
		local k = 1
		while list[k] do
			local row = {}
			local tier = list[k].tier
			while list[k] and list[k].tier == tier do
				table.insert(row, list[k])
				k = k + 1
			end
			for _, t in ipairs(RowOrder(row)) do
				table.insert(order, t.name)
				table.insert(order, ranks[t.name])
			end
		end
	end
	return { shared = true, order = order }
end

--- The shared build you follow, read against the tree once a session.
function TA:SharedBuild(tree)
	local s = self:Settings()
	local text = s and s.talentshared
	if not text then return nil end
	if TA.shared and TA.shared.text == text then return TA.shared.build end
	local _, class = UnitClass("player")
	local ranks = TA.ReadShare(tree, class, text)
	local build = ranks and TA.ShareBuild(tree, ranks) or nil
	TA.shared = { text = text, build = build }
	return build
end

--- Follow a pasted share string. Returns true, or false and what to say.
function TA:Follow(text)
	local s = self:Settings()
	local tree = TA.ReadTree()
	if not (s and next(tree.talent)) then return false, "Your talents aren't there to read yet." end
	local _, class = UnitClass("player")
	local ranks, why = TA.ReadShare(tree, class, text)
	if not ranks then
		if why == "class" then return false, "That build is for another class." end
		return false, "That isn't a Modern Spellbook build string."
	end
	local ok, unfit = TA.Fits(tree, TA.ShareBuild(tree, ranks))
	if not ok then return false, "That build can't be taken a row at a time: " .. unfit .. "." end
	s.talentshared, s.talentbuild, TA.shared = Trim(text), "shared", nil
	return true
end

--- The build you follow as a share string, for a friend or Modern
--- Spellbook's Import.
function TA:ShareText(state)
	if not (state and state.fits) then return nil end
	local _, class = UnitClass("player")
	return TA.ShareString(state.tree, class, state.targets)
end

--- How many points a plan to your level has, and the whole build.
function TA.PlanSizes(state)
	local mine = math.max(0, math.min(TA.POINTS, (state.level or 0) - TA.FIRST_LEVEL + 1))
	return mine, table.getn(TA.Points(state.build))
end

--- A plan of `n` points: the ranks you have, then the build's next points
--- as the advisor gives them, until there are `n` or the build runs out --
--- so points already off the build don't make the plan one you can't apply.
function TA.PlanRanks(state, n)
	local ranks = {}
	for name, r in pairs(state.ranks) do ranks[name] = r end
	local points = TA.Points(state.build)
	while TA.Total(ranks) < n do
		local name = TA.Next(state.tree, ranks, points)
		if not name then break end
		ranks[name] = (ranks[name] or 0) + 1
	end
	return ranks
end

--- A plan's name in Modern Spellbook's list: "Pathfinder: Protection leveling
--- to 30", "Pathfinder: Fury to 30"; without "to" for the whole build ("Pathfinder:
--- Fury at 60").
function TA:PlanName(state, upto)
	local b = state.build
	local short = (b.shared and "Shared build") or (b == state.builds.levelling and "Leveling")
		or (b.name and (b.name .. " leveling")) or (b.spec and (b.spec .. (upto and "" or " at 60"))) or "Leveling"
	return "Pathfinder: " .. short .. (upto and (" to " .. upto) or "")
end

--[[ Chat ------------------------------------------------------------------------ ]]

-- Builds already said not to fit, this session: once is enough.
TA.warned = {}

--- Say once a session that a build does not fit the tree. A warning, so it
--- shows with Pathfinder's chat messages off.
function TA:WarnUnfit(state)
	if TA.warned[state.build] then return end
	TA.warned[state.build] = true
	local c = AegisPathfinder.Theme and AegisPathfinder.Theme:Code("goldDeep") or ""
	AegisPathfinder:Print(c .. TA.UnfitLine(self:Label(state), state.why) .. "|r")
end

--- On a level up: the talent to take with the new point. `level` is the
--- event's; the point may not be counted yet, so there is at least one.
function TA:LevelUp(level)
	local s = self:Settings()
	if not (s and s.talentadvisor and level and level >= TA.FIRST_LEVEL) then return end
	local state = self:State(nil, level, math.max(1, (UnitCharacterPoints("player")) or 0))
	if not state then return end
	if not state.fits then return self:WarnUnfit(state) end
	if not state.next then return end
	-- The card over the screen, with the talents button lit (TalentWindow.lua).
	if s.talentnudge ~= false and TA.Window and TA.Window.Toast then TA.Window:Toast(level, state) end
	if s.talentchat == false then return end
	local t = state.tree.talent[state.next]
	AegisPathfinder:Say(TA.LevelLine(level, state.next, state.rank, t.max, state.tree.tabs[t.tab].name))
end

--- When points are spent or given: at 60 with all 51 on the levelling
--- build, say once that your spec's is ready; a respec says it again later.
function TA:PointsChanged()
	local s = self:Settings()
	if not (s and s.talentadvisor) then return end
	local state = self:State()
	if not (state and state.fits) then return end
	if not state.ready then
		s.talentready = nil
		return
	end
	if s.talentready then return end
	s.talentready = true
	local preferred = self:PreferredBuild(state.builds)
	if preferred then AegisPathfinder:Say(TA.ReadyLine(preferred.spec)) end
end

--- Draw the talent windows again, if they are open, and the talents
--- button: the settings changed.
function TA:Refresh()
	if TA.Window then TA.Window:Repaint() end
	if TA.Modern then TA.Modern:Paint() end
end

-- Registered as the file loads; until the settings are there they are let go.
local events = CreateFrame("Frame")
TA.events = events
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("CHARACTER_POINTS_CHANGED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function()
	if not AegisPathfinder.db then return end
	if event == "PLAYER_LEVEL_UP" then
		TA:LevelUp(tonumber(arg1))
	elseif event == "CHARACTER_POINTS_CHANGED" then
		TA:PointsChanged()
	end
	-- A point to spend lights the talents button (TalentWindow.lua).
	if TA.Window and TA.Window.PaintMicro then TA.Window:PaintMicro() end
end)
