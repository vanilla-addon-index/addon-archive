-- MetaHunt: auto-train Growl to a freshly tamed pet.
--

local MTH_GROWL_MAX_RANK = 7

-- ---------------------------------------------------------------------------
-- Saved-variable backed toggle (per character), default ON.
-- ---------------------------------------------------------------------------
local function MTH_Growl_GetStore()
	if type(MTH_CharSavedVariables) ~= "table" then
		MTH_CharSavedVariables = {}
	end
	if type(MTH_CharSavedVariables.growlTeach) ~= "table" then
		MTH_CharSavedVariables.growlTeach = {}
	end
	local store = MTH_CharSavedVariables.growlTeach
	if store.enabled == nil then
		store.enabled = true
	end
	return store
end

function MTH_Growl_IsEnabled()
	return MTH_Growl_GetStore().enabled and true or false
end

function MTH_Growl_SetEnabled(enabled)
	MTH_Growl_GetStore().enabled = enabled and true or false
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function MTH_Growl_DebugLog(line)
	if type(MTH_DebugFrame) == "table" and type(MTH_DebugFrame.AddInfo) == "function" then
		MTH_DebugFrame:AddInfo("[Growl] " .. tostring(line))
	end
end

local function MTH_Growl_GetGlobal(name)
	if type(getglobal) == "function" then
		return getglobal(name)
	end
	if _G then
		return _G[name]
	end
	return nil
end

-- Rank appropriate for a pet of the given level.
local function MTH_Growl_RankForLevel(level)
	local lvl = tonumber(level) or 0
	if lvl < 1 then lvl = 1 end
	local rank = math.floor(lvl / 10) + 1
	if rank < 1 then rank = 1 end
	if rank > MTH_GROWL_MAX_RANK then rank = MTH_GROWL_MAX_RANK end
	return rank
end

-- Parse a rank number out of a craft row's name/subtext (e.g. "Growl", "Rank 5").
local function MTH_Growl_ParseRank(name, subText)
	local sub = tostring(subText or "")
	local _, _, subRank = string.find(sub, "(%d+)")
	if subRank then return tonumber(subRank) end
	local nm = tostring(name or "")
	local _, _, nameRank = string.find(nm, "(%d+)")
	if nameRank then return tonumber(nameRank) end
	return nil
end

-- Find the hunter spellbook slot for a spell by name (e.g. "Beast Training").
local function MTH_Growl_FindSpellSlot(spellName)
	if not spellName or spellName == "" then return nil end
	local getSpellName = MTH_Growl_GetGlobal("GetSpellName")
	if type(getSpellName) ~= "function" then return nil end

	local getNumSpellTabs = MTH_Growl_GetGlobal("GetNumSpellTabs")
	local getSpellTabInfo = MTH_Growl_GetGlobal("GetSpellTabInfo")
	if type(getNumSpellTabs) == "function" and type(getSpellTabInfo) == "function" then
		local numTabs = getNumSpellTabs() or 0
		for tabIndex = 1, numTabs do
			local _, _, offset, numSpells = getSpellTabInfo(tabIndex)
			offset = tonumber(offset) or 0
			numSpells = tonumber(numSpells) or 0
			for spellIndex = (offset + 1), (offset + numSpells) do
				if getSpellName(spellIndex, "spell") == spellName then
					return spellIndex
				end
			end
		end
	end

	-- Fallback: linear scan of the spellbook.
	local nilStreak = 0
	for spellIndex = 1, 1024 do
		local nameAtIndex = getSpellName(spellIndex, "spell")
		if nameAtIndex then
			nilStreak = 0
			if nameAtIndex == spellName then
				return spellIndex
			end
		else
			nilStreak = nilStreak + 1
			if nilStreak >= 30 then break end
		end
	end
	return nil
end

-- Open the Beast Training window by casting the hunter "Beast Training" spell.
local function MTH_Growl_OpenTrainingWindow()
	local spellName = MTH_Growl_GetGlobal("ZHUNTER_PET_TRAINING") or "Beast Training"
	local slot = MTH_Growl_FindSpellSlot(spellName)
	local castSpell = MTH_Growl_GetGlobal("CastSpell")
	if slot and type(castSpell) == "function" then
		local getSpellName = MTH_Growl_GetGlobal("GetSpellName")
		local atSlot = (type(getSpellName) == "function") and getSpellName(slot, "spell") or "?"
		castSpell(slot, "spell")
		MTH_Growl_DebugLog("Opened Beast Training via CastSpell(slot=" .. tostring(slot)
			.. " name='" .. tostring(atSlot) .. "')")
		return true
	end
	local castSpellByName = MTH_Growl_GetGlobal("CastSpellByName")
	if type(castSpellByName) == "function" then
		castSpellByName(spellName)
		MTH_Growl_DebugLog("Opened Beast Training via CastSpellByName('" .. tostring(spellName) .. "') (slot not found)")
		return true
	end
	MTH_Growl_DebugLog("Could not open Beast Training (no spell slot, no CastSpellByName)")
	return false
end

-- Is the Beast Training / craft window currently visible?
local function MTH_Growl_IsTrainingWindowVisible()
	local frameNames = { "BeastTrainingFrame", "PetTrainingFrame", "CraftFrame" }
	for i = 1, table.getn(frameNames) do
		local frame = MTH_Growl_GetGlobal(frameNames[i])
		if frame then
			if frame.IsVisible and frame:IsVisible() then return true end
			if frame.IsShown and frame:IsShown() then return true end
		end
	end
	return false
end

-- ---------------------------------------------------------------------------
-- Pending auto-train request. Set when a fresh tame is confirmed; cleared once
-- we train (or time out).  { rank, name, elapsed, closeAfter, done }
-- ---------------------------------------------------------------------------
local MTH_Growl_Pending = nil

-- The offer currently awaiting the player's Yes/No answer. { rank, name, level }
local MTH_Growl_Offer = nil

-- While we auto-open the trainer to teach Growl, silence the Beast Training
-- scanner's chat feedback (set on confirm; expires after the teach window).
local MTH_Growl_SuppressScanUntil = 0
function MTH_Growl_IsTeaching()
	local getTime = MTH_Growl_GetGlobal("GetTime")
	local now = (type(getTime) == "function" and getTime()) or 0
	return now < (MTH_Growl_SuppressScanUntil or 0)
end

local function MTH_Growl_TryTrainNow()
	if not MTH_Growl_Pending or MTH_Growl_Pending.done then
		return false
	end

	local getNumCrafts = MTH_Growl_GetGlobal("GetNumCrafts")
	local getCraftInfo = MTH_Growl_GetGlobal("GetCraftInfo")
	local doCraft      = MTH_Growl_GetGlobal("DoCraft")
	if type(getNumCrafts) ~= "function" or type(getCraftInfo) ~= "function" or type(doCraft) ~= "function" then
		return false
	end

	local total = tonumber(getNumCrafts()) or 0
	if total <= 0 then
		return false -- window not populated yet
	end

	local target = MTH_Growl_Pending.rank
	local bestIndex, bestRank = nil, 0
	for i = 1, total do
		local craftName, craftSub, craftType = getCraftInfo(i)
		local lname = string.lower(tostring(craftName or ""))
		if string.find(lname, "growl", 1, true) and tostring(craftType) ~= "header" then
			local rank = MTH_Growl_ParseRank(craftName, craftSub)
			if rank then
				if rank == target then
					bestIndex, bestRank = i, rank
					break
				elseif rank < target and rank > bestRank then
					-- Highest rank we could give if the exact target isn't offered.
					bestIndex, bestRank = i, rank
				end
			end
		end
	end

	if not bestIndex then
		return false -- no Growl row found yet
	end

	doCraft(bestIndex)
	MTH_Growl_DebugLog("Trained Growl Rank " .. tostring(bestRank)
		.. " (target " .. tostring(target) .. ") for '" .. tostring(MTH_Growl_Pending.name)
		.. "' via DoCraft(" .. tostring(bestIndex) .. ")")
	if MTH and type(MTH.Print) == "function" then
		MTH:Print("Auto-taught Growl (Rank " .. tostring(bestRank) .. ") to " .. tostring(MTH_Growl_Pending.name) .. ".")
	end

	MTH_Growl_Pending.done = true
	if MTH_Growl_Pending.closeAfter then
		local closeCraft = MTH_Growl_GetGlobal("CloseCraft")
		if type(closeCraft) == "function" then
			closeCraft()
		end
	end
	MTH_Growl_Pending = nil
	return true
end

-- Driver frame: react to the craft window opening/updating, with an OnUpdate
-- poll as backup and a timeout so we never leave a stale pending request.
local MTH_Growl_Frame = CreateFrame("Frame", "MTH_GrowlTeachFrame")
MTH_Growl_Frame:RegisterEvent("CRAFT_SHOW")
MTH_Growl_Frame:RegisterEvent("CRAFT_UPDATE")
MTH_Growl_Frame:RegisterEvent("PET_TRAINING_SHOW")
MTH_Growl_Frame:SetScript("OnEvent", function()
	MTH_Growl_TryTrainNow()
end)
MTH_Growl_Frame:SetScript("OnUpdate", function()
	if not MTH_Growl_Pending then return end
	local p = MTH_Growl_Pending
	p.elapsed = (p.elapsed or 0) + (arg1 or 0)

	-- Train as soon as the window is populated.
	if MTH_Growl_TryTrainNow() then return end

	if p.elapsed > 8 then
		local getNumCrafts = MTH_Growl_GetGlobal("GetNumCrafts")
		local crafts = (type(getNumCrafts) == "function" and tonumber(getNumCrafts())) or -1
		MTH_Growl_DebugLog("Gave up training Growl Rank " .. tostring(p.rank)
			.. " for '" .. tostring(p.name) .. "' (timeout: windowVisible="
			.. tostring(MTH_Growl_IsTrainingWindowVisible()) .. " numCrafts=" .. tostring(crafts)
			.. " openAttempts=" .. tostring(p.openAttempts) .. ")")
		MTH_Growl_Pending = nil
		return
	end

	-- Window not up yet: re-attempt opening every second (the pet may still be
	-- settling right after the tame, so the first cast can be ignored).
	if not MTH_Growl_IsTrainingWindowVisible() then
		p.sinceOpen = (p.sinceOpen or 0) + (arg1 or 0)
		if p.sinceOpen >= 1.0 then
			p.sinceOpen = 0
			p.openAttempts = (p.openAttempts or 0) + 1
			if p.openAttempts <= 6 then
				MTH_Growl_OpenTrainingWindow()
			end
		end
	end
end)

-- ---------------------------------------------------------------------------
-- Start training the confirmed offer. Called from the popup's Yes button (a
-- hardware event), which makes opening the Beast Training window reliable.
-- ---------------------------------------------------------------------------
local function MTH_Growl_StartTraining(rank, petName)
	local alreadyOpen = MTH_Growl_IsTrainingWindowVisible()
	local getTime = MTH_Growl_GetGlobal("GetTime")
	MTH_Growl_SuppressScanUntil = ((type(getTime) == "function" and getTime()) or 0) + 10
	MTH_Growl_Pending = {
		rank = rank,
		name = petName,
		elapsed = 0,
		sinceOpen = 0,
		openAttempts = 0,
		closeAfter = not alreadyOpen,
		done = false,
	}
	MTH_Growl_DebugLog("Confirmed: train Growl Rank " .. tostring(rank) .. " for '"
		.. tostring(petName) .. "' (windowOpen=" .. tostring(alreadyOpen) .. ")")
	if alreadyOpen then
		MTH_Growl_TryTrainNow()
	else
		MTH_Growl_Pending.openAttempts = 1
		MTH_Growl_OpenTrainingWindow()
	end
end

-- ---------------------------------------------------------------------------
-- Confirmation popup. Yes = hardware event -> open Beast Training + DoCraft.
-- ---------------------------------------------------------------------------
StaticPopupDialogs["MTH_GROWL_TEACH"] = {
	text = "Teach %s to your newly tamed %s?",
	button1 = YES or "Yes",
	button2 = NO or "No",
	OnAccept = function()
		local offer = MTH_Growl_Offer
		MTH_Growl_Offer = nil
		if not offer then return end
		MTH_Growl_StartTraining(offer.rank, offer.name)
	end,
	OnCancel = function()
		MTH_Growl_Offer = nil
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

-- ---------------------------------------------------------------------------
-- Public entry point: called when a fresh tame is confirmed.
-- ---------------------------------------------------------------------------
function MTH_Growl_OfferForTamedPet(petName, petLevel)
	if not MTH_Growl_IsEnabled() then
		return
	end
	if type(StaticPopup_Show) ~= "function" then
		return
	end

	local rank = MTH_Growl_RankForLevel(petLevel)
	MTH_Growl_Offer = { rank = rank, name = petName, level = petLevel }
	local spellLabel = "Growl (Rank " .. tostring(rank) .. ")"
	local name = tostring(petName or "your pet")
	MTH_Growl_DebugLog("Offer pet='" .. name .. "' level=" .. tostring(petLevel) .. " -> " .. spellLabel)
	StaticPopup_Show("MTH_GROWL_TEACH", spellLabel, name)
end
