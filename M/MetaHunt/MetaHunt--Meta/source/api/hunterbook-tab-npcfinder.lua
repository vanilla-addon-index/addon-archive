if type(MTH_HUNTERBOOK_TABS) ~= "table" then MTH_HUNTERBOOK_TABS = {} end

MTH_HUNTERBOOK_TABS.npcs = {
	headerLabel = "NPC Finder",
	columnLabels = { "ID", "Name", "React", "Function", "Zone" },
	columnLayout = {
		{ x = 8, width = 52, align = "LEFT" },
		{ x = 60, width = 140, align = "LEFT" },
		{ x = 200, width = 40, align = "LEFT" },
		{ x = 242, width = 160, align = "LEFT" },
		{ x = 404, width = 148, align = "LEFT" },
	},
}

function MTH_BOOKTAB_GetNPCReactBucket(fac)
	local f = tostring(fac or "")
	if f == "A" then return "A" end
	if f == "H" then return "H" end
	return "AH"
end
MTH_BOOK_GetNPCReactBucket = MTH_BOOKTAB_GetNPCReactBucket

function MTH_BOOKTAB_GetNPCFunctionLabel(key)
	local map = {
		vendor = "Ammo Vendor",
		repair = "Repair",
		stablemaster = "Stable Master",
		huntertrainer = "Hunter Trainer",
		pettrainer = "Pet Trainer",
	}
	return map[key] or (string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2))
end
MTH_BOOK_GetNPCFunctionLabel = MTH_BOOKTAB_GetNPCFunctionLabel

function MTH_BOOKTAB_GetNPCFunctions(vendor)
	local out = {}
	local seen = {}
	local meta = vendor and vendor.meta
	if meta then
		for key, value in pairs(meta) do
			if type(key) == "string" and value and tostring(value) ~= "" then
				local normalizedKey = MTH_BOOK_SafeLower(key)
				if normalizedKey ~= "" and not seen[normalizedKey] then
					seen[normalizedKey] = true
					table.insert(out, normalizedKey)
				end
			end
		end
	end
	table.sort(out, function(a, b)
		return MTH_BOOK_SafeLower(MTH_BOOKTAB_GetNPCFunctionLabel(a)) < MTH_BOOK_SafeLower(MTH_BOOKTAB_GetNPCFunctionLabel(b))
	end)
	return out
end
MTH_BOOK_GetNPCFunctions = MTH_BOOKTAB_GetNPCFunctions

function MTH_BOOKTAB_GetNPCFunctionSummary(vendor)
	local keys = MTH_BOOKTAB_GetNPCFunctions(vendor)
	if table.getn(keys) == 0 then return "-", {} end
	local labels = {}
	for i = 1, table.getn(keys) do
		table.insert(labels, MTH_BOOKTAB_GetNPCFunctionLabel(keys[i]))
	end
	return table.concat(labels, ", "), keys
end
MTH_BOOK_GetNPCFunctionSummary = MTH_BOOKTAB_GetNPCFunctionSummary

local function MTH_BOOKTAB_GetZoneAndSubzone(zoneId)
	local zid = tonumber(zoneId)
	if not zid then return "-", "-" end
	local zoneName = MTH_BOOK_GetZoneName(zid)
	-- Coord zone IDs are WMA; MTH_DS_Zones is keyed by pfQuest area IDs. Translate
	-- first, or WMA 121 (Feralas) collides with pfQ 121 (Raven Hill -> parent Duskwood).
	local pfqId = zid
	if type(MTH_MAP_WMA_TO_PFQ) == "table" then
		pfqId = MTH_MAP_WMA_TO_PFQ[zid] or zid
	end
	local row = MTH_DS_Zones and (MTH_DS_Zones[pfqId] or MTH_DS_Zones[tostring(pfqId)])
	if row and row.parent and tonumber(row.parent) and tonumber(row.parent) ~= pfqId then
		local parentName = MTH_BOOK_GetZoneName(row.parent)
		if parentName and string.sub(parentName, 1, 5) ~= "Zone " then
			return parentName, zoneName
		end
	end
	return zoneName, "-"
end

function MTH_BOOKTAB_GetNPCZoneSummary(vendor)
	if not vendor or not vendor.coords or table.getn(vendor.coords) == 0 then
		return "-", "-", {}
	end
	local zones = {}
	local zoneSet = {}
	local firstZone = "-"
	local firstSubzone = "-"
	for i = 1, table.getn(vendor.coords) do
		local c = vendor.coords[i]
		if c and c[3] then
			local zoneName, subzoneName = MTH_BOOKTAB_GetZoneAndSubzone(c[3])
			if firstZone == "-" then
				firstZone = zoneName
				firstSubzone = subzoneName
			end
			if zoneName ~= "-" and not zoneSet[zoneName] then
				zoneSet[zoneName] = true
				table.insert(zones, zoneName)
			end
		end
	end
	return firstZone, firstSubzone, zones
end
MTH_BOOK_GetNPCZoneSummary = MTH_BOOKTAB_GetNPCZoneSummary

-- Zone column text: every distinct zone the NPC sits in, most-specific (smallest
-- map) first, so multi-location NPCs read e.g. "Darnassus, Teldrassil".
function MTH_BOOKTAB_GetNPCZoneDisplay(vendor)
	if not vendor or not vendor.coords or table.getn(vendor.coords) == 0 then
		return "-"
	end
	local seen = {}
	local list = {}
	for i = 1, table.getn(vendor.coords) do
		local c = vendor.coords[i]
		if c and c[3] then
			local zoneName = MTH_BOOK_GetZoneName(c[3])
			if zoneName and zoneName ~= "-" and not seen[zoneName] then
				seen[zoneName] = true
				local area = nil
				local size = MTH_DS_MinimapSizes and (MTH_DS_MinimapSizes[tonumber(c[3])] or MTH_DS_MinimapSizes[c[3]])
				if type(size) == "table" and tonumber(size[1]) and tonumber(size[2]) then
					area = tonumber(size[1]) * tonumber(size[2])
				end
				table.insert(list, { name = zoneName, area = area, order = i })
			end
		end
	end
	local count = table.getn(list)
	if count == 0 then return "-" end
	-- Smallest map first; zones with no known size keep data order, at the end.
	table.sort(list, function(x, y)
		if x.area and y.area then
			if x.area ~= y.area then return x.area < y.area end
			return x.order < y.order
		end
		if x.area then return true end
		if y.area then return false end
		return x.order < y.order
	end)
	local names = {}
	for i = 1, count do table.insert(names, list[i].name) end
	return table.concat(names, ", ")
end
MTH_BOOK_GetNPCZoneDisplay = MTH_BOOKTAB_GetNPCZoneDisplay

function MTH_BOOK_NPCHasZoneId(vendor, zoneId)
	local zid = tonumber(zoneId)
	if not zid or not vendor or not vendor.coords then
		return false
	end
	for i = 1, table.getn(vendor.coords) do
		local c = vendor.coords[i]
		if c and tonumber(c[3]) == zid then
			return true
		end
	end
	return false
end

function MTH_BOOK_NPCMatches(npcId, vendor)
	if not vendor then return false end
	local react = MTH_BOOK_GetNPCReactBucket(vendor.fac)
	if react == "A" and not MTH_BOOK_STATE.flag1 then return false end
	if react == "H" and not MTH_BOOK_STATE.flag2 then return false end
	if react == "AH" and not MTH_BOOK_STATE.flag3 then return false end

	if MTH_BOOK_STATE.npcHideNoZone then
		local firstZone = MTH_BOOK_GetNPCZoneSummary(vendor)
		local zoneText = MTH_BOOK_SafeLower(firstZone)
		if firstZone == "-" or zoneText == "" or zoneText == "unknown" or string.sub(zoneText, 1, 5) == "zone " then
			return false
		end
	end

	if MTH_BOOK_STATE.npcFunction and MTH_BOOK_STATE.npcFunction ~= "all" then
		local hasFunction = false
		local functions = MTH_BOOK_GetNPCFunctions(vendor)
		for i = 1, table.getn(functions) do
			if functions[i] == MTH_BOOK_STATE.npcFunction then
				hasFunction = true
				break
			end
		end
		if not hasFunction then return false end
	end

	if MTH_BOOK_STATE.npcZone and MTH_BOOK_STATE.npcZone ~= "all" then
		local _, _, zones = MTH_BOOK_GetNPCZoneSummary(vendor)
		local hasZone = false
		for i = 1, table.getn(zones) do
			if zones[i] == MTH_BOOK_STATE.npcZone then
				hasZone = true
				break
			end
		end
		if not hasZone then return false end
	end

	if MTH_BOOK_STATE.npcInZoneOnly then
		local currentZoneId = MTH_BOOK_GetCurrentZoneId()
		if currentZoneId and not MTH_BOOK_NPCHasZoneId(vendor, currentZoneId) then
			return false
		end
	end

	if MTH_BOOK_STATE.search ~= "" then
		local functionSummary = MTH_BOOK_GetNPCFunctionSummary(vendor)
		local firstZone, firstSubzone = MTH_BOOK_GetNPCZoneSummary(vendor)
		local displayName = (MTH and MTH.GetLocalizedNPCNameById and MTH:GetLocalizedNPCNameById(npcId, vendor.name)) or vendor.name
		local hay = MTH_BOOK_SafeLower(tostring(displayName or "") .. " " .. tostring(functionSummary or "") .. " " .. tostring(firstZone or "") .. " " .. tostring(firstSubzone or "") .. " " .. tostring(npcId))
		if string.find(hay, MTH_BOOK_STATE.search, 1, true) == nil then
			return false
		end
	end

	return true
end

function MTH_BOOK_NPCSort(a, b)
	local vendors = MTH_DS_Vendors
	local va = vendors and vendors[a]
	local vb = vendors and vendors[b]
	if not va or not vb then return a < b end
	local vaName = (MTH and MTH.GetLocalizedNPCNameById and MTH:GetLocalizedNPCNameById(a, va.name)) or va.name
	local vbName = (MTH and MTH.GetLocalizedNPCNameById and MTH:GetLocalizedNPCNameById(b, vb.name)) or vb.name
	local na = MTH_BOOK_SafeLower(vaName)
	local nb = MTH_BOOK_SafeLower(vbName)
	if na ~= nb then return na < nb end
	return a < b
end
