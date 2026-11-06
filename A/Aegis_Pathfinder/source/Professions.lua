--[[
	Professions.lua -- trade-skill tracking for profession guides.

	Quest guides advance on quest events. Profession guides cannot: there is no
	"quest" to accept or turn in, only a skill number that climbs while you
	craft. This module watches that number and completes a step when its
	|SKILL| target is reached, which is the profession equivalent of the
	arrival detection that advances travel steps.

	Tags consumed here (emitted by QuestShellPlusParser and documented in
	docs/GUIDE_AUTHORING.md):

	  |SKILL|<profession> <from> <to>|   advance when skill reaches <to>
	  |CRAFT|<count> <item>|             what to make, and roughly how many
	  |MATS|<qty>x <item>, ...|          reagents for a single craft
]]

local AegisPathfinder = AegisPathfinder

-- Skill names as GetSkillLineInfo reports them. Mining is the awkward one:
-- the skill line is "Mining" but the craft window is "Smelting", and guides
-- may name either.
local SKILL_ALIASES = {
	["smelting"] = "mining",
}

--- Current rank and cap in a profession, or nil if the player does not
--- have it. The cap is GetSkillLineInfo's seventh value: 75, 150, 225 or 300
--- as Apprentice, Journeyman, Expert or Artisan.
function AegisPathfinder:GetSkillLine(profession)
	if not profession then return nil end

	local wanted = string.lower(profession)
	wanted = SKILL_ALIASES[wanted] or wanted

	for i = 1, GetNumSkillLines() do
		local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
		if name and not isHeader then
			local have = string.lower(name)
			have = SKILL_ALIASES[have] or have
			if have == wanted then
				return rank, maxRank
			end
		end
	end

	return nil
end

--- Current rank in a profession, or nil if the player does not have it.
function AegisPathfinder:GetSkillRank(profession)
	local rank = self:GetSkillLine(profession)
	return rank
end

--- The profession's skill cap, or nil if the player does not have it.
function AegisPathfinder:GetSkillCap(profession)
	local _, cap = self:GetSkillLine(profession)
	return cap
end

--- Progress through the step's skill range, as a 0..1 ratio.
-- Returns nil when the step is not a skill step or the player lacks the
-- profession, so callers can tell "no progress" from "not applicable".
function AegisPathfinder:GetSkillProgress(i)
	local profession, from, to = self:GetObjectiveTag("SKILL", i)
	if not profession or not to then return nil end

	local rank = self:GetSkillRank(profession)
	if not rank then return nil end

	from = from or 0
	if to <= from then return 1, rank, to end

	local ratio = (rank - from) / (to - from)
	if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end

	return ratio, rank, to
end

--- Complete the current step if its skill target has been reached.
-- Called on every skill change rather than polling.
function AegisPathfinder:CheckSkillObjective()
	local i = self.current
	if not i then return end
	if self:GetObjectiveStatus(i) then return end

	local profession, _, to = self:GetObjectiveTag("SKILL", i)
	if not profession or not to then return end

	local rank = self:GetSkillRank(profession)
	if not rank or rank < to then return end

	self:Debug(string.format("Skill objective met: %s %d/%d", profession, rank, to))
	self:SetTurnedIn()
end

--- True when a step can complete itself from skill events, which the UI shows
-- differently from a step the player has to tick by hand.
function AegisPathfinder:IsSkillObjective(i)
	local profession = self:GetObjectiveTag("SKILL", i)
	return profession ~= nil
end

--- Reagents a step needs, as { item = name, need = n, have = n }.
-- `have` is nil when the item cannot be counted (the bag scan works on item
-- IDs; guide reagents are names), so the UI can show a need-only list rather
-- than a wrong count.
function AegisPathfinder:GetStepReagents(i)
	local mats = self:GetObjectiveTag("MATS", i)
	if not mats then return nil end

	local _, count = self:GetObjectiveTag("CRAFT", i)
	count = count or 1

	local out = {}
	for qty, item in string.gfind(mats, "(%d+)x ([^,]+)") do
		table.insert(out, {
			item = self.trim(item),
			perCraft = tonumber(qty),
			need = tonumber(qty) * count,
		})
	end

	if table.getn(out) == 0 then return nil end

	return out
end

--- Every reagent the remaining steps of the current guide still call for.
-- This is the addon's answer to the reference document's shopping list, but
-- computed from where the player actually is rather than from step one.
function AegisPathfinder:GetRemainingMaterials()
	if not self.actions then return nil end

	local totals, order = {}, {}
	for i = self.current or 1, table.getn(self.actions) do
		if not self:GetObjectiveStatus(i) then
			local reagents = self:GetStepReagents(i)
			if reagents then
				for _, r in ipairs(reagents) do
					if not totals[r.item] then
						totals[r.item] = 0
						table.insert(order, r.item)
					end
					totals[r.item] = totals[r.item] + r.need
				end
			end
		end
	end

	if table.getn(order) == 0 then return nil end

	local list = {}
	for _, item in ipairs(order) do
		table.insert(list, { item = item, need = totals[item] })
	end

	return list
end

--- True when any step of the loaded guide lists reagents -- which is what
--- decides whether the panel offers a shopping list at all. Remembered per
--- step list, since the panel asks on every paint.
local matsGuide, matsAnswer
function AegisPathfinder:GuideHasMaterials()
	if not self.tags then return false end
	if matsGuide ~= self.tags then
		matsGuide, matsAnswer = self.tags, false
		for _, tags in pairs(self.tags) do
			if type(tags) == "string" and string.find(tags, "|MATS|", 1, true) then
				matsAnswer = true
				break
			end
		end
	end
	return matsAnswer
end

--- The craft the player is on or coming up to: the first unfinished step,
--- from the current one on, that lists reagents.
function AegisPathfinder:GetShoppingStep()
	if not self.actions then return nil end
	for i = self.current or 1, table.getn(self.actions) do
		if not self:GetObjectiveStatus(i) and self:GetObjectiveTag("MATS", i) then
			return i
		end
	end
	return nil
end

--[[ Item ids, by name.

	Guides name their reagents; the auction house and Aegis: Exchange work in
	item ids. The bags answer for anything carried, which is exact. Past that,
	Exchange's own name map (filled by its auction scans) and then pfQuest's
	item database, which knows every item in the game by name.
]]
local bagIds = {}
local pfIndex   -- built on first use, once pfQuest's database is there

local function PfQuestItems()
	if not pfIndex then
		local items = pfDB and pfDB.items
		local names = items and (items.loc or items.enUS)
		if type(names) == "table" then
			pfIndex = {}
			for id, name in pairs(names) do
				-- One name, several ids is rare and means a retired copy of
				-- the item; the lower id is the original.
				if type(name) == "string" and (not pfIndex[name] or id < pfIndex[name]) then
					pfIndex[name] = id
				end
			end
		end
	end
	return pfIndex
end

function AegisPathfinder:ItemIdByName(name)
	if not name then return nil end
	if bagIds[name] then return bagIds[name] end
	-- Another addon's data: a surprise there is a missing id, not an error.
	local exchange = AegisExchange and AegisExchange.db
	if exchange and exchange.IdFromName then
		local ok, id = pcall(exchange.IdFromName, name)
		if ok and id then return id end
	end
	local pf = PfQuestItems()
	return pf and pf[name] or nil
end

--- How many of each item the bags hold, by name. Counting by name is what a
--- guide's reagent list can be matched against; the ids come for free and
--- are kept for ItemIdByName.
function AegisPathfinder:CountBags()
	local counts = {}
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) or 0 do
			local link = GetContainerItemLink(bag, slot)
			local _, _, id, name = string.find(link or "", "item:(%d+).-%[(.-)%]")
			if name then
				local _, count = GetContainerItemInfo(bag, slot)
				counts[name] = (counts[name] or 0) + (count or 1)
				bagIds[name] = tonumber(id)
			end
		end
	end
	return counts
end

--- The shopping list for a scope, with what the bags already hold.
--- "step" is the craft you are on or coming up to; anything else, every
--- step still ahead. Returns the list ({ item, need, have }) or nil, and the
--- step the "step" scope is for.
function AegisPathfinder:GetShoppingList(scope)
	local list, step
	if scope == "step" then
		step = self:GetShoppingStep()
		list = step and self:GetStepReagents(step)
	else
		list = self:GetRemainingMaterials()
	end
	if not list then return nil, step end

	local have = self:CountBags()
	for _, entry in ipairs(list) do
		entry.have = have[entry.item] or 0
	end
	return list, step
end

--[[ The steps still ahead, as Aegis: Exchange crafting projects.

	One project per thing to make: { name, itemId, made, want, reagents }, in
	the route's order, with `want` the number of crafts. Exchange multiplies
	the reagents by it, so its shopping list comes to the same totals as the
	one here. The same craft on two steps is one project with both counts --
	Exchange keeps one project per name.

	A step with reagents but nothing to craft (the ingredients a quest wants
	handed in) is named for the step.
]]
function AegisPathfinder:GetRemainingCrafts()
	if not self.actions then return nil end

	local out, byName = {}, {}
	for i = self.current or 1, table.getn(self.actions) do
		if not self:GetObjectiveStatus(i) then
			local reagents = self:GetStepReagents(i)
			if reagents then
				local item, count = self:GetObjectiveTag("CRAFT", i)
				if not item then
					local _, title = self:GetObjectiveInfo(i)
					item, count = title, 1
				end
				count = count or 1

				local list, sig = {}, {}
				for _, r in ipairs(reagents) do
					table.insert(list, { name = r.item, count = r.perCraft })
					table.insert(sig, r.perCraft .. "x" .. r.item)
				end
				sig = table.concat(sig, ",")

				-- Only merge a repeat whose reagents match; a guide that makes
				-- one thing two ways gets both, told apart by number.
				local name, n = item, 1
				while byName[name] and byName[name].sig ~= sig do
					n = n + 1
					name = string.format("%s (%d)", item, n)
				end

				local project = byName[name]
				if project then
					project.want = project.want + count
				else
					project = { name = name, made = 1, want = count, reagents = list, sig = sig }
					byName[name] = project
					table.insert(out, project)
				end
			end
		end
	end

	if table.getn(out) == 0 then return nil end
	-- The bags first: whatever is carried is matched to its exact id.
	self:CountBags()
	for _, project in ipairs(out) do
		project.sig = nil
		project.itemId = self:ItemIdByName(project.name)
		for _, r in ipairs(project.reagents) do
			r.itemId = self:ItemIdByName(r.name)
		end
	end
	return out
end

--[[ Events ]]

function AegisPathfinder:RegisterProfessionEvents()
	-- CHAT_MSG_SKILL fires on every skill-up. SKILL_LINES_CHANGED covers
	-- learning a profession and training the next rank, which move the skill
	-- cap without a skill-up message.
	self:RegisterEvent("CHAT_MSG_SKILL", "OnSkillChanged")
	self:RegisterEvent("SKILL_LINES_CHANGED", "OnSkillChanged")
end

function AegisPathfinder:OnSkillChanged()
	self:CheckSkillObjective()
	self:UpdateStatusFrame()
end
