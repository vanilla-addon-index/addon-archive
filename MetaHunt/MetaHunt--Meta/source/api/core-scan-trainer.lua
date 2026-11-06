-- MetaHunt: one-time live trainer catalog collector.
-- Developer workflow: /mth trainerscan, then open a Hunter or Pet Trainer.

local MTH_TS_Frame
local MTH_TS_Armed = false
local MTH_TS_AutoArmed = false

local function MTH_TS_Log(text)
	if MTH_DebugFrame and type(MTH_DebugFrame.AddInfo) == "function" then
		MTH_DebugFrame:AddInfo("[TrainerScan] " .. tostring(text))
	end
end

local function MTH_TS_Call(name, ...)
	local fn = getglobal and getglobal(name) or (_G and _G[name])
	if type(fn) ~= "function" then return nil, "missing" end
	local ok, a, b, c, d, e, f, g = pcall(fn, unpack(arg))
	if not ok then return nil, "error=" .. tostring(a) end
	return { a, b, c, d, e, f, g }, nil
end

local function MTH_TS_Values(values)
	if not values then return "" end
	local parts = {}
	local i = 1
	while i <= table.getn(values) do
		if values[i] ~= nil then
			table.insert(parts, tostring(values[i]))
		end
		i = i + 1
	end
	return table.concat(parts, " | ")
end

local function MTH_TS_TargetName()
	if type(UnitName) == "function" then
		local name = UnitName("target")
		if name and name ~= "" then return name end
	end
	local title = getglobal and getglobal("TrainerFrameTitleText") or nil
	if title and title.GetText then return title:GetText() or "?" end
	return "?"
end

local function MTH_TS_GetLiveStatusStore()
	if type(MTH_CharSavedVariables) ~= "table" then MTH_CharSavedVariables = {} end
	if type(MTH_CharSavedVariables.trainerLiveStatus) ~= "table" then
		MTH_CharSavedVariables.trainerLiveStatus = {}
	end
	return MTH_CharSavedVariables.trainerLiveStatus
end

local function MTH_TS_GetCatalogKind(name, rank)
	local catalog = MTH_DS_TrainerCatalog
	if type(catalog) ~= "table" or type(catalog.byNameRank) ~= "table" then return nil end
	local keySuffix = "\031" .. tostring(name or "") .. "\031" .. tostring(rank or "")
	if catalog.byNameRank["hunter" .. keySuffix] then return "hunter" end
	if catalog.byNameRank["pet" .. keySuffix] then return "pet" end
	return nil
end

function MTH_GetTrainerLiveStatus(kind, name, rank)
	local store = type(MTH_CharSavedVariables) == "table" and MTH_CharSavedVariables.trainerLiveStatus or nil
	if type(store) ~= "table" then return nil end
	return store[tostring(kind or "") .. "\031" .. tostring(name or "") .. "\031" .. tostring(rank or "")]
end

local function MTH_TS_CollectLiveStatuses()
	local countValues = MTH_TS_Call("GetNumTrainerServices")
	local total = countValues and tonumber(countValues[1]) or 0
	if total <= 0 then return false end

	local trainerName = MTH_TS_TargetName()
	local store = MTH_TS_GetLiveStatusStore()
	local observed = 0
	for index = 1, total do
		local info = MTH_TS_Call("GetTrainerServiceInfo", index)
		local name = info and info[1] or nil
		local rank = info and info[2] or ""
		local status = info and info[3] or nil
		local kind = MTH_TS_GetCatalogKind(name, rank)
		if kind and (status == "available" or status == "unavailable" or status == "used") then
			local key = kind .. "\031" .. tostring(name) .. "\031" .. tostring(rank)
			store[key] = {
				status = status,
				observedAt = time(),
				trainer = trainerName,
			}
			observed = observed + 1
		end
	end

	if observed > 0 then
		MTH_TS_Log("Live trainer overlay: " .. tostring(observed) .. " observed catalog row(s) from " .. tostring(trainerName) .. ".")
		if MTH and MTH.Print and (not MTH.IsMessageEnabled or MTH:IsMessageEnabled("trainerScan", true)) then
			MTH:Print("Trainer scan: " .. tostring(observed) .. " Hunter/Pet spell status" .. (observed == 1 and "" or "es") .. " observed.")
		end
		return true
	end
	return false
end

local function MTH_TS_Collect()
	local countValues, countError = MTH_TS_Call("GetNumTrainerServices")
	local total = countValues and tonumber(countValues[1]) or 0
	if not total or total <= 0 then
		MTH_TS_Log("No trainer services yet. GetNumTrainerServices=" .. tostring(MTH_TS_Values(countValues))
			.. " " .. tostring(countError or ""))
		return false
	end

	local trainerName = MTH_TS_TargetName()
	local capture = {
		trainer = trainerName,
		capturedAt = time(),
		services = {},
	}
	MTH_TRAINER_SCAN_LAST = capture
	if type(MTH_CharSavedVariables) == "table" then
		if type(MTH_CharSavedVariables.trainerCatalogScans) ~= "table" then
			MTH_CharSavedVariables.trainerCatalogScans = {}
		end
		MTH_CharSavedVariables.trainerCatalogScans[trainerName] = capture
	end
	MTH_TS_Log("=== " .. tostring(capture.trainer) .. " | " .. tostring(total) .. " trainer services ===")

	local index = 1
	while index <= total do
		local info, infoError = MTH_TS_Call("GetTrainerServiceInfo", index)
		local icon, iconError = MTH_TS_Call("GetTrainerServiceIcon", index)
		local cost, costError = MTH_TS_Call("GetTrainerServiceCost", index)
		local level, levelError = MTH_TS_Call("GetTrainerServiceLevelReq", index)
		local skill, skillError = MTH_TS_Call("GetTrainerServiceSkillReq", index)
		local description, descriptionError = MTH_TS_Call("GetTrainerServiceDescription", index)
		local reqCountValues = MTH_TS_Call("GetTrainerServiceNumAbilityReq", index)
		local reqCount = reqCountValues and tonumber(reqCountValues[1]) or 0
		local requirements = {}
		local reqIndex = 1
		while reqIndex <= reqCount do
			local requirement, reqError = MTH_TS_Call("GetTrainerServiceAbilityReq", index, reqIndex)
			table.insert(requirements, {
				name = requirement and requirement[1] or nil,
			flag = requirement and requirement[2] or nil,
				error = reqError,
			})
			reqIndex = reqIndex + 1
		end

		local row = {
			index = index,
			name = info and info[1] or nil,
			rank = info and info[2] or nil,
			status = info and info[3] or nil,
			expanded = info and info[4] or nil,
			icon = icon and icon[1] or nil,
			cost = cost and cost[1] or nil,
			requiredLevel = level and level[1] or nil,
			skillRequirement = skill,
			description = description and description[1] or nil,
			abilityRequirements = requirements,
		}
		table.insert(capture.services, row)

		MTH_TS_Log(string.format("%02d name=%s | rank=%s | status=%s | expanded=%s | level=%s | cost=%s | icon=%s",
			index, tostring(row.name), tostring(row.rank), tostring(row.status), tostring(row.expanded),
			tostring(row.requiredLevel), tostring(row.cost), tostring(row.icon)))
		if row.description and row.description ~= "" then
			MTH_TS_Log("  description=" .. tostring(row.description))
		end
		if table.getn(requirements) > 0 then
			local requirementText = {}
			local requirementIndex = 1
			while requirementIndex <= table.getn(requirements) do
				local requirement = requirements[requirementIndex]
				table.insert(requirementText, tostring(requirement.name)
					.. " [flag=" .. tostring(requirement.flag) .. "]")
				requirementIndex = requirementIndex + 1
			end
			MTH_TS_Log("  abilityRequirements=" .. table.concat(requirementText, ", "))
		end
		if skill and table.getn(skill) > 0 then
			MTH_TS_Log("  skillRequirement=" .. MTH_TS_Values(skill))
		end
		if infoError or iconError or costError or levelError or skillError or descriptionError then
			MTH_TS_Log("  API=" .. tostring(infoError or "ok") .. ", " .. tostring(iconError or "ok")
				.. ", " .. tostring(costError or "ok") .. ", " .. tostring(levelError or "ok")
				.. ", " .. tostring(skillError or "ok") .. ", " .. tostring(descriptionError or "ok"))
		end
		index = index + 1
	end

	MTH_TS_Log("=== Capture complete. " .. tostring(total)
		.. " rows retained in MTH_TRAINER_SCAN_LAST and trainerCatalogScans. ===")
	return true
end

local function MTH_TS_EnsureFrame()
	if not MTH_TS_Frame then
		MTH_TS_Frame = CreateFrame("Frame", "MTH_TrainerCatalogScanner")
		MTH_TS_Frame:SetScript("OnEvent", function()
			if event == "TRAINER_SHOW" then
				MTH_TS_AutoArmed = true
				this.elapsed = 0
				this:SetScript("OnUpdate", function()
					this.elapsed = (this.elapsed or 0) + (arg1 or 0)
					if this.elapsed < 0.25 then return end
					this:SetScript("OnUpdate", nil)
					MTH_TS_CollectLiveStatuses()
				end)
				return
			end
			if event ~= "TRAINER_LIST_UPDATE" or not (MTH_TS_Armed or MTH_TS_AutoArmed) then return end
			this.elapsed = 0
			this:SetScript("OnUpdate", function()
				this.elapsed = (this.elapsed or 0) + (arg1 or 0)
				if this.elapsed < 0.25 then return end
				this:SetScript("OnUpdate", nil)
				local manualArmed = MTH_TS_Armed
				MTH_TS_Armed = false
				MTH_TS_AutoArmed = false
				MTH_TS_CollectLiveStatuses()
				if manualArmed and not MTH_TS_Collect() and MTH and MTH.Print then
					MTH:Print("Trainer list was empty. Open the trainer again and run /mth trainerscan.")
				end
			end)
		end)
		MTH_TS_Frame:RegisterEvent("TRAINER_SHOW")
		MTH_TS_Frame:RegisterEvent("TRAINER_LIST_UPDATE")
	end
end

function MTH_CommandTrainerScan()
	if MTH_DebugFrame and type(MTH_DebugFrame.Show) == "function" then MTH_DebugFrame:Show() end
	local currentRows = MTH_TS_Call("GetNumTrainerServices")
	if currentRows and (tonumber(currentRows[1]) or 0) > 0 then
		MTH_TS_Collect()
		if MTH and MTH.Print then
			MTH:Print("Trainer catalog captured from the open trainer window.")
		end
		return
	end

	MTH_TS_EnsureFrame()

	MTH_TS_Armed = true
	if MTH and MTH.Print then
		MTH:Print("Trainer catalog scan armed. Open a Hunter Trainer or Pet Trainer; results will appear in the debug window.")
	end
end

MTH_TS_EnsureFrame()