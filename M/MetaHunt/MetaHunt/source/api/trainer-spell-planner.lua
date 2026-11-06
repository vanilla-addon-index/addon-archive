-- MetaHunt shared trainer spell status and cost planner.
-- UI, chat notifications, and future level-up messages consume these functions.

local function MTH_TP_Lower(value)
	return string.lower(tostring(value or ""))
end

local function MTH_TP_RankNumber(rank)
	local _, _, value = string.find(tostring(rank or ""), "(%d+)")
	return tonumber(value) or 0
end

function MTH_TrainerPlan_GetPrice(row, honored)
	local base = tonumber(row and row.trainerCost) or 0
	if honored then return math.floor(base * 0.90) end
	return base
end

local function MTH_TP_IsKnownHunter(row)
	if type(MTH_HT_GetSpellInfo) ~= "function" then return false end
	local known = MTH_HT_GetSpellInfo(row and row.name)
	if type(known) ~= "table" then return false end
	local requiredRank = MTH_TP_RankNumber(row and row.rank)
	return requiredRank == 0 or (tonumber(known.rankNum) or 0) >= requiredRank
end

local function MTH_TP_IsKnownPet(row)
	if type(MTH_PETS_GetRootStore) ~= "function" then return false end
	local pets = MTH_PETS_GetRootStore()
	local store = pets and pets.petStore
	local petId = store and store.activeCurrentId
	local pet = store and store.activeById and petId and store.activeById[tostring(petId)]
	local spells = pet and pet.petSpellbook and pet.petSpellbook.spells
	if type(spells) ~= "table" then return false end
	local requiredName = MTH_TP_Lower(row and row.name)
	local requiredRank = MTH_TP_RankNumber(row and row.rank)
	for _, spell in ipairs(spells) do
		if MTH_TP_Lower(spell and spell.name) == requiredName then
			local knownRank = tonumber(spell.rank) or 0
			if requiredRank == 0 or knownRank >= requiredRank then return true end
		end
	end
	return false
end

function MTH_TrainerPlan_IsKnown(kind, row)
	if kind == "hunter" then return MTH_TP_IsKnownHunter(row) end
	return MTH_TP_IsKnownPet(row)
end

local function MTH_TP_HasMissingPrerequisite(kind, row)
	if type(row and row.prerequisites) ~= "table" then return false end
	for _, prerequisite in ipairs(row.prerequisites) do
		local _, _, name, rank = string.find(tostring(prerequisite), "^(.+)%s%([Rr]ank%s*(%d+)%)$")
		if name and rank and not MTH_TrainerPlan_IsKnown(kind, { name = name, rank = "Rank " .. rank }) then
			return true
		end
	end
	return false
end

function MTH_TrainerPlan_GetStatus(kind, row, playerLevel)
	if MTH_TrainerPlan_IsKnown(kind, row) then return "known" end
	local observed = type(MTH_GetTrainerLiveStatus) == "function"
		and MTH_GetTrainerLiveStatus(kind, row and row.name, row and row.rank) or nil
	if observed and observed.status == "used" then return "known" end
	if observed and observed.status == "available" then return "notlearned" end
	if observed and observed.status == "unavailable" then return "notyet" end
	local requiredLevel = tonumber(row and row.requiredLevel) or 0
	if not playerLevel or playerLevel < requiredLevel or MTH_TP_HasMissingPrerequisite(kind, row) then
		return "notyet"
	end
	return "notlearned"
end

function MTH_TrainerPlan_Build(kind, options)
	options = options or {}
	local catalog = MTH_DS_TrainerCatalog
	local rows = catalog and catalog[kind] or nil
	local playerLevel = tonumber(options.playerLevel)
	if not playerLevel and type(UnitLevel) == "function" then playerLevel = tonumber(UnitLevel("player")) end
	local honored = options.honored and true or false
	local plan = {
		kind = kind,
		playerLevel = playerLevel,
		honored = honored,
		rows = {},
		now = { count = 0, cost = 0 },
		nextLevel = { level = nil, count = 0, cost = 0 },
		remaining = { count = 0, cost = 0 },
	}
	if type(rows) ~= "table" then return plan end
	for _, row in ipairs(rows) do
		local status = MTH_TrainerPlan_GetStatus(kind, row, playerLevel)
		local price = MTH_TrainerPlan_GetPrice(row, honored)
		local entry = { row = row, status = status, price = price }
		table.insert(plan.rows, entry)
		if status ~= "known" then
			plan.remaining.count = plan.remaining.count + 1
			plan.remaining.cost = plan.remaining.cost + price
			if status == "notlearned" then
				plan.now.count = plan.now.count + 1
				plan.now.cost = plan.now.cost + price
			end
			local requiredLevel = tonumber(row.requiredLevel) or 0
			if playerLevel and requiredLevel > playerLevel then
				if not plan.nextLevel.level or requiredLevel < plan.nextLevel.level then
					plan.nextLevel.level = requiredLevel
					plan.nextLevel.count = 0
					plan.nextLevel.cost = 0
				end
				if requiredLevel == plan.nextLevel.level then
					plan.nextLevel.count = plan.nextLevel.count + 1
					plan.nextLevel.cost = plan.nextLevel.cost + price
				end
			end
		end
	end
	return plan
end

function MTH_TrainerPlan_BuildLevel(kind, targetLevel, options)
	options = options or {}
	local level = tonumber(targetLevel)
	local catalog = MTH_DS_TrainerCatalog
	local rows = catalog and catalog[kind] or nil
	local honored = options.honored and true or false
	local plan = {
		kind = kind,
		level = level,
		honored = honored,
		rows = {},
		available = { count = 0, cost = 0 },
		unlearned = { count = 0, cost = 0 },
	}
	if not level or type(rows) ~= "table" then return plan end
	for _, row in ipairs(rows) do
		if tonumber(row.requiredLevel) == level and (options.includeKnown or not MTH_TrainerPlan_IsKnown(kind, row)) then
			local status = MTH_TrainerPlan_GetStatus(kind, row, level)
			local price = MTH_TrainerPlan_GetPrice(row, honored)
			local entry = { row = row, status = status, price = price }
			table.insert(plan.rows, entry)
			plan.unlearned.count = plan.unlearned.count + 1
			plan.unlearned.cost = plan.unlearned.cost + price
			if status == "notlearned" then
				plan.available.count = plan.available.count + 1
				plan.available.cost = plan.available.cost + price
			end
		end
	end
	return plan
end

function MTH_TrainerPlan_MatchesQuick(status, quick)
	if quick == "known" then return status == "known" end
	if quick == "notlearned" then return status == "notlearned" end
	if quick == "notyet" then return status == "notyet" end
	return true
end
