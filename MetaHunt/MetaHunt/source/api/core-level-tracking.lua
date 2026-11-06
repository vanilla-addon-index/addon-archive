-- MetaHunt level tracker. All training facts come from MTH_DS_TrainerCatalog
-- through trainer-spell-planner.lua; this module only detects progression and
-- presents the resulting facts through chat and animations.

local MTH_LT_Frame = nil
local MTH_LT_PendingPetCheck = false
local MTH_LT_SuppressUntil = 0

local MTH_LT_HunterLines = {
	[1] = "You can now track beasts. Revolutionary: look for the things you intend to shoot.",
	[2] = "The wilderness remains deeply unimpressed.",
	[3] = "Still mostly leather, arrows, and misplaced confidence.",
	[4] = "You have actual trainer lessons now. Try not to spend all your coin on repairs.",
	[5] = "Your pet is doing its share. Please consider doing yours.",
	[6] = "A hunter's mark: because shouting at the target was not precise enough.",
	[7] = "Every pull is a plan until it becomes cardio.",
	[8] = "Concussive Shot. Distance is now a tactical concept, not an accident.",
	[9] = "Your arrows have begun their long argument with gravity.",
	[10] = "You have a hawk aspect. The bird remains unavailable for comment.",
	[11] = "A fine age for discovering that pets also require paperwork.",
	[12] = "Mend Pet unlocked. Your pet has noticed this was overdue.",
	[13] = "The wilderness has upgraded its complaints department.",
	[14] = "Eagle Eye. Finally, a way to inspect trouble before walking into it.",
	[15] = "You have survived another level through skill, luck, or a pet-shaped shield.",
	[16] = "Traps and sharp things. Subtlety continues to be optional.",
	[17] = "Your pet is still carrying the emotional weight of this partnership.",
	[18] = "Multi-Shot. One target was apparently an unacceptable limitation.",
	[19] = "Soon you may run faster. The enemies will take this personally.",
	[20] = "Congratulations: escape now has a speed setting.",
	[21] = "Fast enough to arrive at the next questionable decision sooner.",
	[22] = "Your trainer has new bills and somehow they are all addressed to you.",
	[23] = "The pet remains employed despite the working conditions.",
	[24] = "Beast Lore. At last: research before violence. Briefly.",
	[25] = "Halfway to better excuses, nowhere near fewer mistakes.",
	[26] = "Rapid Fire. Your bow has entered its impatient phase.",
	[27] = "Things are going well enough to become dangerous.",
	[28] = "Your arrows now contain a measurable amount of intent.",
	[29] = "Prepare for the hunter's most respected tactical maneuver.",
	[30] = "Feign Death. Why win a fight when you can become administrative debris?",
	[31] = "You are alive, which validates absolutely nothing.",
	[32] = "Flare. Stealth has been downgraded to a suggestion.",
	[33] = "The next trap is definitely part of the plan.",
	[34] = "Explosive Trap. Negotiation has left the chat.",
	[35] = "Your pet thinks this is all normal. That is worrying.",
	[36] = "More damage, more maintenance, same heroic disregard for repair bills.",
	[37] = "Keep going. The next disaster is probably already pathing toward you.",
	[38] = "Your toolkit is becoming impressively hard to explain to civilized people.",
	[39] = "One level until armor finally admits you have been taking hits.",
	[40] = "Mail training. Leather got you this far; enemies kept putting holes in it.",
	[41] = "You are now visibly better protected from consequences.",
	[42] = "More Multi-Shot: because collateral damage needed a sequel.",
	[43] = "Your pet has grown used to the sound of avoidable danger.",
	[44] = "The trainer is delighted. Your coin pouch is less enthusiastic.",
	[45] = "You are a seasoned hunter now, which means the mistakes are expensive.",
	[46] = "Nature resistance: proof that the outdoors have been escalating.",
	[47] = "Still alive. Still pointing the dangerous end away from yourself. Usually.",
	[48] = "Your damage has matured into a fully funded public nuisance.",
	[49] = "One more level until the trainer starts charging executive prices.",
	[50] = "Your arrows have tenure now.",
	[51] = "The wilderness would like a word. It has a queue.",
	[52] = "Aimed Shot hits harder, which is your preferred form of diplomacy.",
	[53] = "Your pet remains your most reliable party member. Make of that what you will.",
	[54] = "Explosive Trap again. The floor continues to be a valid target.",
	[55] = "Almost there. Try not to die to something with a tutorial tooltip.",
	[56] = "Aspect of the Viper. Mana problems now have a bird-shaped solution.",
	[57] = "The finish line is visible. So are several elite mobs. Choose carefully.",
	[58] = "The final trainer bills are arriving with alarming confidence.",
	[59] = "One last level. Your pet has begun drafting a victory speech.",
	[60] = "You made it. The wildlife will remember this unfavorably.",
}

local MTH_LT_Priority = {
	["Feign Death"] = 100,
	["Mail"] = 95,
	["Aspect of the Cheetah"] = 90,
	["Rapid Fire"] = 88,
	["Aspect of the Pack"] = 86,
	["Explosive Trap"] = 84,
	["Freezing Trap"] = 82,
	["Flare"] = 80,
	["Eagle Eye"] = 78,
	["Multi-Shot"] = 76,
	["Aimed Shot"] = 74,
	["Aspect of the Viper"] = 72,
	["Trueshot Aura"] = 70,
	["Volley"] = 68,
	["Track Hidden"] = 66,
}

local MTH_LT_PetLines = {
	"It is now statistically better than your last pull.",
	"The food budget has noticed.",
	"Please do not celebrate by pulling three extra mobs.",
	"It remains committed to solving problems with teeth.",
	"The wilderness has filed no objection.",
	"Your dependable colleague is carrying this team again.",
}

local MTH_LT_LoyaltyLines = {
	[2] = "It tolerates your leadership as long as the food arrives on time.",
	[3] = "Your authority has been acknowledged, reluctantly.",
	[4] = "It has decided your plans are survivable often enough.",
	[5] = "Please do not reward this trust with an elite pull.",
	[6] = "Against all evidence, it trusts you completely.",
}

local function MTH_LT_Store()
	if not MTH_CharSavedVariables then MTH_CharSavedVariables = {} end
	if type(MTH_CharSavedVariables.levelTracker) ~= "table" then
		MTH_CharSavedVariables.levelTracker = { petLine = 0, loyaltyLine = 0 }
	end
	return MTH_CharSavedVariables.levelTracker
end

local function MTH_LT_MessageEnabled(key, defaultValue)
	return MTH and type(MTH.IsMessageEnabled) == "function" and MTH:IsMessageEnabled(key, defaultValue)
end

local function MTH_LT_FormatCost(copper)
	local total = tonumber(copper) or 0
	local gold = math.floor(total / 10000)
	local silver = math.floor((total - gold * 10000) / 100)
	local bronze = total - gold * 10000 - silver * 100
	local parts = {}
	if gold > 0 then table.insert(parts, "|cffffd100" .. gold .. "g|r") end
	if silver > 0 or gold > 0 then table.insert(parts, "|cffc7c7cf" .. silver .. "s|r") end
	table.insert(parts, "|cffeda55f" .. bronze .. "c|r")
	return table.concat(parts, " ")
end

local function MTH_LT_NextLine(store, key, lines)
	store[key] = (tonumber(store[key]) or 0) + 1
	if store[key] > table.getn(lines) then store[key] = 1 end
	return lines[store[key]]
end

local function MTH_LT_GetHeadline(plan)
	local best = nil
	local bestPriority = -1
	for _, entry in ipairs(plan.rows or {}) do
		local priority = MTH_LT_Priority[tostring(entry.row and entry.row.name or "")] or 0
		if priority > bestPriority then best, bestPriority = entry, priority end
	end
	return best
end

local function MTH_LT_FormatRows(plan)
	local labels = {}
	for index, entry in ipairs(plan.rows or {}) do
		local row = entry.row or {}
		local label = tostring(row.name or "Unknown")
		if row.rank and row.rank ~= "" then label = label .. " " .. tostring(row.rank) end
		table.insert(labels, label)
	end
	return table.concat(labels, ", ")
end

local function MTH_LT_GrowlRankForLevel(level)
	local rank = math.floor((tonumber(level) or 1) / 10) + 1
	if rank < 1 then rank = 1 end
	if rank > 7 then rank = 7 end
	return rank
end

local function MTH_LT_BuildPetGrowlPlan(level, preview, honored)
	if type(MTH_TrainerPlan_BuildLevel) ~= "function" then return nil end
	local plan = MTH_TrainerPlan_BuildLevel("pet", level, { honored = honored and true or false, includeKnown = preview })
	local growlPlan = {
		rows = {},
		unlearned = { count = 0, cost = 0 },
	}
	for _, entry in ipairs(plan.rows or {}) do
		if tostring(entry.row and entry.row.name or "") == "Growl" then
			table.insert(growlPlan.rows, entry)
			growlPlan.unlearned.count = growlPlan.unlearned.count + 1
			growlPlan.unlearned.cost = growlPlan.unlearned.cost + (tonumber(entry.price) or 0)
		end
	end
	return growlPlan
end

local function MTH_LT_HandlePetGrowlLevel(petName, level)
	if level < 10 or level > 60 or math.mod(level, 10) ~= 0 then return end
	local rank = MTH_LT_GrowlRankForLevel(level)
	local known = type(MTH_HT_GetSpellInfo) == "function" and MTH_HT_GetSpellInfo("Growl") or nil
	if known and (tonumber(known.rankNum) or 0) >= rank then
		if type(MTH_Growl_OfferForTamedPet) == "function" then
			MTH_Growl_OfferForTamedPet(petName, level)
		end
	elseif MTH_LT_MessageEnabled("petLevelUp", true) then
		MTH:Print(petName .. " can now learn Growl Rank " .. tostring(rank) .. ". Visit a Pet Trainer to learn it.")
	end
end

local function MTH_LT_PrintSpellList(plan)
	local line = ""
	local isFirstLine = true
	for _, entry in ipairs(plan.rows or {}) do
		local row = entry.row or {}
		local label = tostring(row.name or "Unknown")
		if row.rank and row.rank ~= "" then label = label .. " " .. tostring(row.rank) end
		if line == "" then
			line = label
		elseif string.len(line) + string.len(label) + 2 > 92 then
			MTH:Print((isFirstLine and "New spells available: " or "And also: ") .. line)
			isFirstLine = false
			line = label
		else
			line = line .. ", " .. label
		end
	end
	if line ~= "" then MTH:Print((isFirstLine and "New spells available: " or "And also: ") .. line) end
end

local function MTH_LT_AnnounceTraining(kind, level, eventKind, preview)
	if type(MTH_TrainerPlan_BuildLevel) ~= "function" then return end
	local base = MTH_TrainerPlan_BuildLevel(kind, level, { honored = false, includeKnown = preview })
	local honored = MTH_TrainerPlan_BuildLevel(kind, level, { honored = true, includeKnown = preview })
	if base.unlearned.count <= 0 then
		if kind == "hunter" and MTH_LT_MessageEnabled("hunterLevelUp", true) then
			MTH:Print("Congratz! You hit level " .. tostring(level) .. ".")
		end
		if preview then MTH:Print("Level test: no " .. kind .. " trainer spells in the 1.18.1 catalog at level " .. tostring(level) .. ".") end
		return
	end
	local headline = MTH_LT_GetHeadline(base)
	local headlineText = headline and headline.row and tostring(headline.row.name or "") or "New training"
	if headline and headline.row and headline.row.rank and headline.row.rank ~= "" then headlineText = headlineText .. " " .. headline.row.rank end
	local isLevelCap = kind == "hunter" and level == 60
	if isLevelCap then headlineText = "The hunt is yours" end
	local isPetGrowlMilestone = kind == "pet" and level >= 10 and level <= 60 and math.mod(level, 10) == 0
	if isPetGrowlMilestone then headlineText = "Growl Rank " .. tostring(MTH_LT_GrowlRankForLevel(level)) end
	if kind == "hunter" and not isLevelCap then headlineText = nil end
	if MTH_LT_MessageEnabled(eventKind == "hunter" and "hunterLevelUp" or "petLevelUp", true) then
		if kind == "hunter" then
			MTH:Print("Congratz! You hit level " .. tostring(level) .. ".")
			MTH:Print(MTH_LT_HunterLines[level] or "New training is available.")
			MTH:Print("The spells you can learn will cost you " .. MTH_LT_FormatCost(base.unlearned.cost)
				.. ", but only " .. MTH_LT_FormatCost(honored.unlearned.cost) .. " if you are Honored with the master.")
			MTH_LT_PrintSpellList(base)
		else
			local displayPlan = isPetGrowlMilestone and MTH_LT_BuildPetGrowlPlan(level, preview) or base
			local displayHonoredPlan = isPetGrowlMilestone and MTH_LT_BuildPetGrowlPlan(level, preview, true) or honored
			if displayPlan and displayPlan.unlearned.count > 0 then
				MTH:Print("It can learn " .. MTH_LT_FormatRows(displayPlan))
				MTH:Print("Trainer cost: Base " .. MTH_LT_FormatCost(displayPlan.unlearned.cost) .. " | Honored " .. MTH_LT_FormatCost(displayHonoredPlan.unlearned.cost))
			end
		end
	end
	local isMilestone = kind == "hunter" and (level == 10 or level == 20 or level == 30 or level == 40 or level == 50 or level == 60)
	local flag = isMilestone and "level.huntermilestone" or (kind == "hunter" and "level.hunter" or "level.pet")
	if type(MTH_FX_IsEnabled) == "function" and MTH_FX_IsEnabled(flag) and type(MTH_Celebrate) == "function" then
		local subtitle = kind == "hunter" and (MTH_LT_HunterLines[level] or "New training is available.") or "Your beast grows stronger. Teach it something nasty."
		if isMilestone and type(MTH_CelebrateBlackHole) == "function" then
			MTH_CelebrateBlackHole(isLevelCap and headlineText or "Level " .. tostring(level), subtitle)
		else
			local title = headlineText and ("Level " .. tostring(level) .. " - " .. headlineText) or "Level " .. tostring(level)
			MTH_Celebrate(title, subtitle, "fanfare", 5)
		end
	end
end

local function MTH_LT_HandleHunterLevel(level)
	local store = MTH_LT_Store()
	local previous = tonumber(store.hunterLevel)
	store.hunterLevel = level
	if previous and level > previous then
		MTH_LT_AnnounceTraining("hunter", level, "hunter")
	end
end

local function MTH_LT_GetPetState()
	if type(UnitExists) ~= "function" or not UnitExists("pet") then return nil end
	local level = type(UnitLevel) == "function" and tonumber(UnitLevel("pet")) or nil
	local name = type(UnitName) == "function" and UnitName("pet") or "Your pet"
	if not level or level <= 0 then return nil end
	-- Loyalty is a localized name via GetPetLoyalty(); reuse the pet service which
	-- parses it (plus UI fallbacks) into a numeric 1-6 level.
	local loyalty = nil
	if type(MTH_GetCurrentPetInfo) == "function" then
		local info = MTH_GetCurrentPetInfo()
		if type(info) == "table" then loyalty = tonumber(info.loyaltyLevel) or nil end
	end
	return { key = tostring(name or "pet"), name = tostring(name or "Your pet"), level = level, loyalty = loyalty }
end

local function MTH_LT_HandlePetState()
	MTH_LT_PendingPetCheck = false
	local state = MTH_LT_GetPetState()
	if not state then return end
	local store = MTH_LT_Store()
	local pet = store.pet
	if type(pet) ~= "table" or pet.key ~= state.key then
		store.pet = state
		return
	end
	-- Just after a loading screen the pet's real level/loyalty can arrive a beat
	-- late; record them as the baseline silently so we never announce progress
	-- that actually happened in an earlier session (e.g. a fresh install).
	if type(GetTime) == "function" and MTH_LT_SuppressUntil > 0 and GetTime() < MTH_LT_SuppressUntil then
		store.pet = state
		return
	end
	if state.level > (tonumber(pet.level) or 0) then
		local line = MTH_LT_NextLine(store, "petLine", MTH_LT_PetLines)
		if MTH_LT_MessageEnabled("petLevelUp", true) then MTH:Print(state.name .. " reached level " .. state.level .. ". " .. line) end
		MTH_LT_AnnounceTraining("pet", state.level, "pet")
		MTH_LT_HandlePetGrowlLevel(state.name, state.level)
	end
	if state.loyalty and state.loyalty > 1 and state.loyalty > (tonumber(pet.loyalty) or 0) then
		local line = MTH_LT_LoyaltyLines[state.loyalty] or "The food arrangement appears to be working."
		if MTH_LT_MessageEnabled("petLoyaltyUp", true) then MTH:Print(state.name .. " reached Loyalty Level " .. state.loyalty .. ". " .. line) end
		if type(MTH_FX_IsEnabled) == "function" and MTH_FX_IsEnabled("level.loyalty") then
			local title = state.name .. " - Loyalty " .. state.loyalty
			if state.loyalty == 6 and type(MTH_CelebrateBlackHole) == "function" then
				MTH_CelebrateBlackHole(title, line)
			elseif type(MTH_Celebrate) == "function" then
				MTH_Celebrate(title, line, "fanfare")
			end
		end
	end
	store.pet = state
end

local function MTH_LT_RequestPetCheck()
	if MTH_LT_PendingPetCheck or not MTH_LT_Frame then return end
	MTH_LT_PendingPetCheck = true
	MTH_LT_Frame.elapsed = 0
	MTH_LT_Frame:SetScript("OnUpdate", function()
		this.elapsed = (this.elapsed or 0) + (arg1 or 0)
		if this.elapsed >= 0.35 then
			this:SetScript("OnUpdate", nil)
			MTH_LT_HandlePetState()
		end
	end)
end

function MTH_LevelTracker_Test(kind, level)
	if kind == "hunter" or kind == "pet" then
		local targetLevel = tonumber(level) or ((kind == "hunter") and (tonumber(UnitLevel("player")) or 1) or 1)
		MTH:Print("Level test: previewing " .. kind .. " trainer spells at level " .. tostring(targetLevel) .. ".")
		MTH_LT_AnnounceTraining(kind, targetLevel, kind, true)
		return true
	end
	if kind == "loyalty" then
		local state = MTH_LT_GetPetState()
		local loyalty = tonumber(level) or (state and state.loyalty) or 1
		if loyalty <= 1 then
			MTH:Print("Pet Loyalty starts at level 1 when you tame a pet. Test levels 2 through 6.")
			return false
		end
		local petName = state and state.name or "Your pet"
		local line = MTH_LT_LoyaltyLines[loyalty] or "The food arrangement appears to be working."
		MTH:Print(petName .. " reached Loyalty Level " .. tostring(loyalty) .. ". " .. line)
		local title = petName .. " - Loyalty " .. tostring(loyalty)
		if loyalty == 6 and type(MTH_CelebrateBlackHole) == "function" then
			MTH_CelebrateBlackHole(title, line)
		elseif type(MTH_Celebrate) == "function" then
			MTH_Celebrate(title, line, "fanfare")
		end
		return true
	end
	return false
end

function MTH_LevelTracker_Initialize()
	if MTH_LT_Frame then return end
	MTH_LT_Frame = CreateFrame("Frame", "MTH_LevelTracker")
	MTH_LT_Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	MTH_LT_Frame:RegisterEvent("PLAYER_LEVEL_UP")
	MTH_LT_Frame:RegisterEvent("UNIT_LEVEL")
	MTH_LT_Frame:RegisterEvent("UNIT_PET")
	MTH_LT_Frame:RegisterEvent("PET_BAR_UPDATE")
	MTH_LT_Frame:RegisterEvent("UNIT_HAPPINESS")
	MTH_LT_Frame:SetScript("OnEvent", function()
		if event == "PLAYER_ENTERING_WORLD" then
			local level = type(UnitLevel) == "function" and tonumber(UnitLevel("player")) or nil
			if level then MTH_LT_Store().hunterLevel = level end
			if type(GetTime) == "function" then MTH_LT_SuppressUntil = GetTime() + 8 end
			MTH_LT_RequestPetCheck()
		elseif event == "PLAYER_LEVEL_UP" then
			MTH_LT_HandleHunterLevel(tonumber(arg1) or tonumber(UnitLevel("player")) or 1)
		elseif event == "UNIT_LEVEL" and arg1 == "pet" then
			MTH_LT_RequestPetCheck()
		elseif event == "UNIT_PET" and arg1 == "player" then
			MTH_LT_RequestPetCheck()
		elseif event == "PET_BAR_UPDATE" then
			MTH_LT_RequestPetCheck()
		elseif event == "UNIT_HAPPINESS" then
			MTH_LT_RequestPetCheck()
		end
	end)
end

MTH_LevelTracker_Initialize()