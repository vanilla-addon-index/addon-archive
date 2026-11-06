-- Core: Item/cooldown logic. No frame references.
function LA.FindItem(item)
	if not item then return end
	item = string.lower(LA.ItemLinkToName(item))
	local link
	for i = 1, 23 do
		link = GetInventoryItemLink("player", i)
		if link then
			if item == string.lower(LA.ItemLinkToName(link)) then
				return i, nil, GetInventoryItemTexture("player", i), GetInventoryItemCount("player", i)
			end
		end
	end
	local count, bag, slot, texture
	local totalcount = 0
	for i = 0, NUM_BAG_FRAMES do
		for j = 1, MAX_CONTAINER_ITEMS do
			link = GetContainerItemLink(i, j)
			if link then
				if item == string.lower(LA.ItemLinkToName(link)) then
					bag, slot = i, j
					texture, count = GetContainerItemInfo(i, j)
					totalcount = totalcount + count
				end
			end
		end
	end
	return bag, slot, texture, totalcount
end

function LA.GetItemCooldown(item)
	local bag, slot = LA.FindItem(item)
	if slot then
		return GetContainerItemCooldown(bag, slot)
	elseif bag then
		return GetInventoryItemCooldown("player", bag)
	end
end

function LA.ItemLinkToName(link)
	if link then
		return string.gsub(link, "^.*%[(.*)%].*$", "%1")
	end
end

---@param row WarlockRow
---@param startTime number|nil
function LA.UpdateSSCD(row, startTime)
	if LA.DebugMode then
		LA.print("Personal SSCD detected.")
	end
	local a = row.assignment
	if (startTime == nil) then
		if (a.SSCooldown ~= nil) then
			if (a.SSCooldown == 0) then
				a.SSCooldown = nil
				a.SSonCD = "unknown"
			else
				a.SSonCD = "true"
			end
		else
			a.SSCooldown = nil
			a.SSonCD = "unknown"
		end
		a.LocalTime = GetTime()
	else
		a.SSCooldown = startTime
		a.LocalTime = GetTime()
		a.SSonCD = "true"
	end
end

function LA.UpdateAssignmentSSCDByName(name, cd)
	local row = LA.FindAssignmentByName(name)
	if row then
		row.assignment.SSCooldown = cd
		if LA.DebugMode then
			LA.print("Updated SS CD for " .. tostring(name) .. " successfully.")
		end
	end
end

function LA.ForceUpdateSSCD()
	if LA.DebugMode then
		LA.print("Forcing SSCD cache update.")
	end
	local startTime = LA.GetItemCooldown("Major Soulstone")
	local myRow = LA.GetMyAssignment()
	if myRow ~= nil then
		if myRow.assignment.SSCooldown ~= startTime then
			LA.UpdateSSCD(myRow, startTime)
		end
	else
		if LA.DebugMode then
			LA.print("Something went horribly wrong.")
		end
	end
end
