if type(MTH_HUNTERBOOK_TABS) ~= "table" then MTH_HUNTERBOOK_TABS = {} end

local trainerColumns = {
	{ x = 28, width = 150, align = "LEFT" },
	{ x = 180, width = 62, align = "LEFT" },
	{ x = 244, width = 43, align = "LEFT" },
	{ x = 289, width = 80, align = "LEFT" },
	{ x = 371, width = 105, align = "LEFT" },
	{ x = 478, width = 74, align = "LEFT" },
}

MTH_HUNTERBOOK_TABS.hunterspells = {
	headerLabel = "Hunter Spells",
	columnLabels = { "Spell", "Rank", "Level", "Price", "Branch", "Status" },
	columnLayout = trainerColumns,
}

MTH_HUNTERBOOK_TABS.petspells = {
	headerLabel = "Pet Spells",
	columnLabels = { "Spell", "Rank", "Level", "Price", "Branch", "Status" },
	columnLayout = trainerColumns,
}

function MTH_BOOKTAB_IsTrainerSpellMode(mode)
	return mode == "hunterspells" or mode == "petspells"
end

local function MTH_BOOKTAB_GetTrainerKind()
	if MTH_BOOK_STATE and MTH_BOOK_STATE.mode == "petspells" then return "pet" end
	return "hunter"
end

function MTH_BOOKTAB_FormatTrainerCost(copper)
	local value = tonumber(copper) or 0
	local gold = math.floor(value / 10000)
	value = value - gold * 10000
	local silver = math.floor(value / 100)
	local bronze = value - silver * 100
	local parts = {}
	if gold > 0 then table.insert(parts, "|cffffd100" .. tostring(gold) .. "g|r") end
	if silver > 0 or gold > 0 then table.insert(parts, "|cffc7c7cf" .. tostring(silver) .. "s|r") end
	table.insert(parts, "|cffeda55f" .. tostring(bronze) .. "c|r")
	return table.concat(parts, " ")
end

function MTH_BOOKTAB_GetTrainerDisplayCost(copper)
	if type(MTH_TrainerPlan_GetPrice) == "function" then
		return MTH_TrainerPlan_GetPrice({ trainerCost = copper }, MTH_BOOK_STATE and MTH_BOOK_STATE.trainerHonoredDiscount)
	end
	return tonumber(copper) or 0
end

function MTH_BOOKTAB_GetTrainerSpellStatus(row)
	local kind = MTH_BOOKTAB_GetTrainerKind()
	local playerLevel = MTH_BOOK_GetPlayerLevelValue and MTH_BOOK_GetPlayerLevelValue() or nil
	local status = type(MTH_TrainerPlan_GetStatus) == "function" and MTH_TrainerPlan_GetStatus(kind, row, playerLevel) or "notyet"
	if status == "known" then return "Known", "|cff40ff40" end
	if status == "notlearned" then return "Not learned", "|cffffa500" end
	return "Not yet learnable", "|cffff4040"
end

function MTH_BOOKTAB_BuildTrainerSpellResults()
	local results = {}
	local kind = MTH_BOOKTAB_GetTrainerKind()
	local plan = type(MTH_TrainerPlan_Build) == "function" and MTH_TrainerPlan_Build(kind, {
		playerLevel = MTH_BOOK_GetPlayerLevelValue and MTH_BOOK_GetPlayerLevelValue() or nil,
		honored = MTH_BOOK_STATE and MTH_BOOK_STATE.trainerHonoredDiscount,
	}) or nil
	if type(plan) ~= "table" or type(plan.rows) ~= "table" then return results end
	local search = MTH_BOOK_SafeLower(MTH_BOOK_STATE.search or "")
	for _, planned in ipairs(plan.rows) do
		local row = planned.row
		local level = tonumber(row.requiredLevel) or 0
		local haystack = tostring(row.name or "") .. " " .. tostring(row.rank or "") .. " " .. tostring(row.section or "") .. " " .. tostring(row.description or "")
		if type(row.prerequisites) == "table" then
			for _, prerequisite in ipairs(row.prerequisites) do
				haystack = haystack .. " " .. tostring(prerequisite)
			end
		end
		haystack = MTH_BOOK_SafeLower(haystack)
		if (search == "" or string.find(haystack, search, 1, true) ~= nil)
			and (not MTH_BOOK_STATE.minLevel or level >= MTH_BOOK_STATE.minLevel)
			and (not MTH_BOOK_STATE.maxLevel or level <= MTH_BOOK_STATE.maxLevel)
			and (type(MTH_TrainerPlan_MatchesQuick) ~= "function" or MTH_TrainerPlan_MatchesQuick(planned.status, MTH_BOOK_STATE.quick))
		then
			table.insert(results, row)
		end
	end
	return results
end

function MTH_BOOKTAB_UpdateTrainerPlanPanel(detail)
	local parent = detail and detail:GetParent()
	if not parent then return end
	if not parent.mthTrainerPlan then
		local panel = CreateFrame("Frame", nil, parent)
		panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -238)
		panel:SetWidth(136)
		panel:SetHeight(128)
		panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		panel:SetBackdropColor(0.06, 0.06, 0.06, 1)
		panel:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)
		panel.text = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		panel.text:SetPoint("TOPLEFT", panel, "TOPLEFT", 7, -7)
		panel.text:SetWidth(122)
		panel.text:SetJustifyH("LEFT")
		panel.text:SetJustifyV("TOP")
		parent.mthTrainerPlan = panel
	end
	local plan = type(MTH_TrainerPlan_Build) == "function" and MTH_TrainerPlan_Build(MTH_BOOKTAB_GetTrainerKind(), {
		playerLevel = MTH_BOOK_GetPlayerLevelValue and MTH_BOOK_GetPlayerLevelValue() or nil,
		honored = MTH_BOOK_STATE.trainerHonoredDiscount,
	}) or nil
	if not plan then return end
	local nextLevel = plan.nextLevel.level
	local nextLabel = "Next"
	if nextLevel then nextLabel = "At level " .. tostring(nextLevel) end
	local function formatBlock(label, summary)
		return "|cffffffff" .. label .. "|r\n"
			.. "|cff4da6ff" .. tostring(summary.count) .. "|r |cff9a9a9aspells|r |cffffffff| |r"
			.. MTH_BOOKTAB_FormatTrainerCost(summary.cost)
	end
	parent.mthTrainerPlan.text:SetText("|cffffd100Training Plan|r\n"
		.. formatBlock("Now", plan.now)
		.. "\n\n" .. formatBlock(nextLabel, plan.nextLevel)
		.. "\n\n" .. formatBlock("Remaining", plan.remaining))
	parent.mthTrainerPlan:Show()
end

function MTH_BOOKTAB_GetTrainerSpellTotal()
	local catalog = MTH_DS_TrainerCatalog
	local rows = catalog and catalog[MTH_BOOKTAB_GetTrainerKind()] or nil
	return type(rows) == "table" and table.getn(rows) or 0
end

function MTH_BOOKTAB_TrainerSpellSort(a, b)
	local al = tonumber(a and a.requiredLevel) or 0
	local bl = tonumber(b and b.requiredLevel) or 0
	if al ~= bl then return al < bl end
	local an = MTH_BOOK_SafeLower(a and a.name)
	local bn = MTH_BOOK_SafeLower(b and b.name)
	if an ~= bn then return an < bn end
	return MTH_BOOK_SafeLower(a and a.rank) < MTH_BOOK_SafeLower(b and b.rank)
end

function MTH_BOOKTAB_GetTrainerSpellSortKey(row, col)
	if col == 1 then return MTH_BOOK_SafeLower(row and row.name) end
	if col == 2 then return MTH_BOOK_SafeLower(row and row.rank) end
	if col == 3 then return tonumber(row and row.requiredLevel) or 0 end
	if col == 4 then return tonumber(row and row.trainerCost) or 0 end
	if col == 5 then return MTH_BOOK_SafeLower(row and row.section) end
	if col == 6 then
		local status = MTH_BOOKTAB_GetTrainerSpellStatus(row)
		return MTH_BOOK_SafeLower(status)
	end
	return nil
end

function MTH_BOOKTAB_GetTrainerSpellRowValues(row)
	local requiredLevel = tonumber(row and row.requiredLevel) or 0
	local playerLevel = MTH_BOOK_GetPlayerLevelValue and MTH_BOOK_GetPlayerLevelValue() or nil
	local levelColor = (playerLevel and playerLevel >= requiredLevel) and "|cff40ff40" or "|cffff4040"
	local status, statusColor = MTH_BOOKTAB_GetTrainerSpellStatus(row)
	return {
		tostring(row and row.name or "-"),
		tostring(row and row.rank or "-"),
		levelColor .. tostring(row and row.requiredLevel or "-") .. "|r",
		MTH_BOOKTAB_FormatTrainerCost(MTH_BOOKTAB_GetTrainerDisplayCost(row and row.trainerCost)),
		tostring(row and row.section or "-"),
		statusColor .. status .. "|r",
	}
end

function MTH_BOOKTAB_UpdateTrainerSpellDetail(detail, selected)
	if not MTH_BOOKTAB_IsTrainerSpellMode(MTH_BOOK_STATE and MTH_BOOK_STATE.mode) then return false end
	MTH_BOOKTAB_UpdateTrainerPlanPanel(detail)
	if not selected then
		MTH_BOOK_SetDetailText(detail, "|cFFFFD100Trainer Spells|r\n\nSelect a spell rank to inspect its trainer level, undiscounted cost, and prerequisites.")
		return true
	end
	local lines = {}
	table.insert(lines, "|cffffff00" .. tostring(selected.name or "Unknown") .. "|r")
	if selected.rank and selected.rank ~= "" then table.insert(lines, "|cffaaaaaa" .. tostring(selected.rank) .. "|r") end
	table.insert(lines, "")
	table.insert(lines, "|cff9a9a9aBranch:|r |cffffffff" .. tostring(selected.section or "-") .. "|r")
	local requiredLevel = tonumber(selected.requiredLevel) or 0
	local playerLevel = MTH_BOOK_GetPlayerLevelValue and MTH_BOOK_GetPlayerLevelValue() or nil
	local levelColor = (playerLevel and playerLevel >= requiredLevel) and "|cff40ff40" or "|cffff4040"
	table.insert(lines, "|cff9a9a9aRequired Level:|r " .. levelColor .. tostring(selected.requiredLevel or "-") .. "|r")
	local status, statusColor = MTH_BOOKTAB_GetTrainerSpellStatus(selected)
	table.insert(lines, "|cff9a9a9aStatus:|r " .. statusColor .. status .. "|r")
	table.insert(lines, "|cff9a9a9aBase Price:|r " .. MTH_BOOKTAB_FormatTrainerCost(selected.trainerCost))
	table.insert(lines, "|cff9a9a9aHonored Price:|r " .. MTH_BOOKTAB_FormatTrainerCost(math.floor((tonumber(selected.trainerCost) or 0) * 0.90)))
	if type(selected.prerequisites) == "table" and table.getn(selected.prerequisites) > 0 then
		table.insert(lines, "")
		table.insert(lines, "|cffffd100Prerequisites|r")
		for _, prerequisite in ipairs(selected.prerequisites) do
			table.insert(lines, "  " .. tostring(prerequisite))
		end
	end
	if selected.description and selected.description ~= "" then
		table.insert(lines, "")
		table.insert(lines, "|cffffd100Description|r")
		table.insert(lines, "|cffffffff  " .. tostring(selected.description) .. "|r")
	end
	local detailFrame = detail.mthTrainerDetailParent or detail:GetParent()
	if not detail.mthTrainerIcon then
		detail.mthTrainerIcon = detail:CreateTexture(nil, "ARTWORK")
		detail.mthTrainerIcon:SetWidth(28)
		detail.mthTrainerIcon:SetHeight(28)
	end
	detail.mthTrainerIcon:SetParent(detail)
	detail.mthTrainerIcon:ClearAllPoints()
	detail.mthTrainerIcon:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, 0)
	detail.mthTrainerIcon:SetTexture(MTH_BOOK_ResolveIconPath(selected.icon) or "Interface\\Icons\\INV_Misc_QuestionMark")
	detail.mthTrainerIcon:Show()
	if detail.SetTextInsets then detail:SetTextInsets(4, 4, 36, 4) end
	if not detail.mthTrainerDetailScroll then
		detail:ClearAllPoints()
		detail:SetPoint("TOPLEFT", detailFrame, "TOPLEFT", 8, -42)
		detail:SetWidth(detailFrame:GetWidth() - 16)
	end
	MTH_BOOK_SetDetailText(detail, table.concat(lines, "\n"))
	return true
end