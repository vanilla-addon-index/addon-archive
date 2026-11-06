local scanTooltip = CreateFrame("GameTooltip", "bvToolTip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local function clear_tooltip()
	for i = 1, 20 do
		if _G["bvToolTipTextLeft" .. i] then
			_G["bvToolTipTextLeft" .. i]:SetText("")
		end
		if _G["bvToolTipTextRight" .. i] then
			_G["bvToolTipTextRight" .. i]:SetText("")
		end
	end
end

local function starts_with(str, start)
	return string.sub(str, 1, string.len(start)) == start
end

local function get_base_blockvalue(tooltip)
	clear_tooltip()

	if tooltip:SetInventoryItem("player", 17) == nil then
		return 0
	end

	for i = 1, tooltip:NumLines() do
		if _G["bvToolTipTextRight" .. i]:GetText() == "Shield" then
			local bvLine = _G["bvToolTipTextLeft" .. i + 2]:GetText()
			local bvString = string.sub(bvLine, 1, -6)
			local bvBase = tonumber(bvString)
			if bvBase == nil then
				return 0
			end
			return bvBase
		end
	end

	return 0
end

local function get_gear_blockvalue(tooltip)
	local bvGear = 0
	for i = 1, 18 do
		clear_tooltip()
		if tooltip:SetInventoryItem("player", i) then
			for j = 1, tooltip:NumLines() do
				local line = _G["bvToolTipTextLeft" .. j]:GetText()
				if line ~= nil and starts_with(line, "Equip: Increases the block value of your shield by ") then
					local bv = string.sub(line, 52, string.len(line) - 1)
					bvGear = bvGear + bv
				end
			end
		end
	end
	return bvGear
end

local function get_talent_block_info()
	local _, playerClass = UnitClass("player")

	if playerClass ~= "PALADIN" and playerClass ~= "WARRIOR" and playerClass ~= "SHAMAN" then
		return nil, 0, 0, 0
	end

	local tabIndex, talentIndex, bvModifier, bvModifierPerPoint = 0, 0, 0, 0
	if playerClass == "PALADIN" then
		tabIndex = 2
		talentIndex = 8
		bvModifierPerPoint = 0.10
	elseif playerClass == "WARRIOR" then
		tabIndex = 3
		talentIndex = 5
		bvModifierPerPoint = 0.03
	elseif playerClass == "SHAMAN" then
		tabIndex = 2
		talentIndex = 2
		bvModifierPerPoint = 0.06
	end

	local name, _, _, _, currentRank, maxRank, _, _ = GetTalentInfo(tabIndex, talentIndex);
	bvModifier = bvModifierPerPoint * currentRank

	return name, currentRank, maxRank, bvModifier
end

local function get_strength_blockvalue()
	local _, stat, _, _ = UnitStat("player", 1)
	return math.floor(stat / 20)
end

SLASH_BV1 = "/bv"
SlashCmdList["BV"] = function()
	local bvBase = get_base_blockvalue(scanTooltip)
	local bvGear = get_gear_blockvalue(scanTooltip)
	local _, _, _, bvModifier = get_talent_block_info()
	local bvStr = get_strength_blockvalue()
	local bvTotal = math.floor((bvBase + bvGear) * (1 + bvModifier) + bvStr)

	DEFAULT_CHAT_FRAME:AddMessage("Total Block Value: " .. bvTotal)
end

SLASH_BVV1 = "/bvv"
SlashCmdList["BVV"] = function()
	local bvBase = get_base_blockvalue(scanTooltip)
	local bvGear = get_gear_blockvalue(scanTooltip)
	local talentName, currentRank, maxRank, bvModifier = get_talent_block_info()
	local bvTalentIncreaseMessage = ""
	if bvModifier ~= 0 then
		local bvTalentIncrease = math.floor((bvBase + bvGear) * bvModifier)
		bvTalentIncreaseMessage = "Your " ..
				talentName ..
				" talent (" ..
				currentRank ..
				"/" .. maxRank .. ") increases block value by: " .. bvTalentIncrease .. " (" .. bvModifier * 100 ..
				"%)"
	end

	local bvStr = get_strength_blockvalue()
	local bvTotal = math.floor((bvBase + bvGear) * (1 + bvModifier) + bvStr)

	DEFAULT_CHAT_FRAME:AddMessage("Total Block Value: " .. bvTotal)
	DEFAULT_CHAT_FRAME:AddMessage("Shield block value: " .. bvBase)
	DEFAULT_CHAT_FRAME:AddMessage("Gear block value: " .. bvGear)
	DEFAULT_CHAT_FRAME:AddMessage("Strength block value: " .. bvStr)
	DEFAULT_CHAT_FRAME:AddMessage(bvTalentIncreaseMessage)
end
