-- Cache global variables
local _G = _G
local error = _G.error
local select = _G.select
local tonumber = _G.tonumber
local type = _G.type
local unpack = unpack
local match = _G.string.match
-- Cache WoW API
local GetContainerNumSlots = _G.GetContainerNumSlots
local GetContainerItemLink = _G.GetContainerItemLink
local GetContainerItemInfo = _G.GetContainerItemInfo

RAID_CLASS_COLORS["SHAMAN"] = {r = 0.14, g = 0.35, b = 1.0} -- fix class color

local function ExtractID(link)
	local id = match(link, 'H.-:(%d+):')
	id = tonumber(id)
	return id
end

function hooksecurefunc(arg1, arg2, arg3)
	local isMethod = type(arg1) == "table" and type(arg2) == "string" and type(arg1[arg2]) == "function" and type(arg3) == "function"
	if not (isMethod or (type(arg1) == "string" and type(_G[arg1]) == "function" and type(arg2) == "function")) then
		error("Usage: hooksecurefunc([table,] \"functionName\", hookfunc)", 2)
	end

	if not isMethod then
		arg1, arg2, arg3 = _G, arg1, arg2
	end

	local original_func = arg1[arg2]

	arg1[arg2] = function(...)
		local original_return = {original_func(unpack(arg))}
		arg3(unpack(arg))

		return unpack(original_return)
	end
end

----------------------------
-- API GetContainerItemID --
----------------------------
function GetContainerItemID(bag, slot)
	local link = GetContainerItemLink(bag, slot)
	if not link then return end
	local itemID = ExtractID(link)
	return itemID
end

----------------------
-- API GetItemCount --
----------------------
function GetItemCount(obj)
	
	local itemID, size, slotCount, slotID
	local count = 0
	
	if type(obj) == 'number' then
		itemID = obj -- if obj is ID
	elseif type(obj) == 'string' then
		itemID = tonumber(match(obj, 'item:(%d+)')) -- if obj is link
		if not itemID then
			itemID = tonumber(obj) -- if obj is ID, but type 'string'
		end
	end
	if not itemID then return count end

	for bag = 4, 0, -1 do
		size = GetContainerNumSlots(bag)
		if size then
			for slot = size, 1, -1 do
				slotID = GetContainerItemID(bag, slot)
				if slotID and itemID == slotID then
					slotCount = select(2, GetContainerItemInfo(bag, slot))
					count = count + slotCount
				end
			end
		end
	end		
	return count
end

