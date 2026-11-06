--[[
	Database.lua
		BagnonForever's implementation of BagnonDB
		Author: Tuller, McPewPew, Fostercare5988
		Built for the Enhanced WoW 1.12.1 Client (ClassicAPI)
--]]

if not Bagnon_EngineReady then
	return
end

BagnonDB = {}

--local globals
local currentRealm = GetRealmName(); --what currentRealm we're on

if not BagnonForeverData then
	BagnonForeverData = {}
end

if currentRealm and currentRealm ~= "" and not BagnonForeverData[currentRealm] then
	BagnonForeverData[currentRealm] = {}
end

local function GetRealm()
	if not currentRealm or currentRealm == "" then
		currentRealm = GetRealmName()
	end
	if currentRealm and currentRealm ~= "" and not BagnonForeverData[currentRealm] then
		BagnonForeverData[currentRealm] = {}
	end
	return currentRealm
end

--[[
	Access  Functions
--]]

--[[
	BagnonDB.GetPlayers()
		returns:
			iterator of all players on this realm with data
		usage:
			for playerName, data in BagnonDB.GetPlayers()
--]]

function BagnonDB.GetPlayers(sort)
	local realm = GetRealm()
	if not realm or not BagnonForeverData[realm] then
		return function() end
	end

	if not sort then
		-- If sort is false, just return pairs
		return pairs(BagnonForeverData[realm])
	end

	-- Each iterator owns its snapshot; nested menus must not overwrite one another.
	local sortedNamesBuffer = {}
	for name in pairs(BagnonForeverData[realm]) do
		table.insert(sortedNamesBuffer, name)
	end
	table.sort(sortedNamesBuffer)

	-- Return a custom iterator function
	local i = 0
	return function()
		i = i + 1
		local playerName = sortedNamesBuffer[i]
		if not playerName then return nil end
		return playerName, BagnonForeverData[realm][playerName]
	end
end

local function NextBag(data, key)
	local value
	repeat
		key, value = next(data, key)
	until key == nil or (type(key) == "number" and type(value) == "table")
	return key, value
end

local function NextItem(data, key)
	local value
	repeat
		key, value = next(data, key)
	until key == nil or (type(key) == "number" and key > 0 and type(value) == "string")
	return key, value
end

local function EmptyIterator() end

--[[
	BagnonDB.GetBags(player)
		returns:
			iterator of all bagsIDs for the given player
		usage:
			for bagID, data in BagnonDB.GetBags("playerName")
--]]

function BagnonDB.GetBags(player)
	local realm = GetRealm()
	if realm and player and BagnonForeverData[realm] and BagnonForeverData[realm][player] then
		return NextBag, BagnonForeverData[realm][player], nil
	end
	return EmptyIterator
end

--[[
	BagnonDB.GetItems(player, bagID)
		returns:
			iterator of all itemSlots with stuff in the given bag
		usage:
			for bagID, data in BagnonDB.GetBags("playerName", bagID)
--]]

function BagnonDB.GetItems(player, bagID)
	local realm = GetRealm()
	if realm and player and bagID and BagnonForeverData[realm] and BagnonForeverData[realm][player] and BagnonForeverData[realm][player][bagID] then
		return NextItem, BagnonForeverData[realm][player][bagID], nil
	end
	return EmptyIterator
end

local function ExpandShortLink(short)
	if type(short) ~= "string" then return nil end
	if string.find(short, "^%d+$") then
		return "item:" .. short .. ":0:0:0"
	elseif string.find(short, "^%d+:%-?%d+:%-?%d+:%-?%d+$") then
		return "item:" .. short
	end
end

local function GetStoredItem(player, bagID, itemSlot)
	local realm = GetRealm()
	local playerData = realm and player and BagnonForeverData[realm] and BagnonForeverData[realm][player]
	local bagData = type(playerData) == "table" and playerData[bagID]
	local data = type(bagData) == "table" and bagData[itemSlot]
	if type(data) ~= "string" then return nil end
	local _, _, short, count = string.find(data, "^([%d:%-]+),?(%d*)$")
	return ExpandShortLink(short), tonumber(count)
end

--[[
	BagnonDB.GetMoney(player)
		args:
			player (string)
				the name of the player we're looking at.  This is specific to the current realm we're on

		returns:
			(number) How much money, in copper, the given player has
--]]
function BagnonDB.GetMoney(player)
	local realm = GetRealm()
	if realm and player and BagnonForeverData[realm] and BagnonForeverData[realm][player] then
		return BagnonForeverData[realm][player].g or 0;
	end
	return 0;
end

--[[
	BagnonDB.GetTotalMoney(realm)
		returns:
			(number) Total money across all characters on the specified (or current) realm
--]]
function BagnonDB.GetTotalMoney(realm)
	local targetRealm = realm or GetRealm()
	if not targetRealm or not BagnonForeverData[targetRealm] then
		return 0
	end
	local total = 0
	for _, data in pairs(BagnonForeverData[targetRealm]) do
		if type(data) == "table" and data.g then
			total = total + data.g
		end
	end
	return total
end

--[[
	BagnonDB.GetBagData(player, bagID)
		args:
			player (string)
				the name of the player we're looking at.  This is specific to the current realm we're on
			bagID (number)
				the number of the bag we're looking at.

		returns:
			size (number)
				How many items the bag can hold (number)
			link (string)
				The itemlink of the bag, in the format item:w:x:y:z (string)
			count (number)
				How many items are in the bag.  This is used by ammo and soul shard bags
--]]
function BagnonDB.GetBagData(player, bagID)
	local realm = GetRealm()
	local playerData = realm and player and BagnonForeverData[realm] and BagnonForeverData[realm][player];
	if playerData then
		local bagData = playerData[bagID];
		if type(bagData) == "table" and type(bagData.s) == "string" then
			local _, _, size, count, link = string.find(bagData.s, "^(%d+),(%d+),(.*)$")
			if size then return tonumber(size), ExpandShortLink(link), tonumber(count) end
		end
	end
end

--[[
	BagnonDB.GetItemData(player, bagID, itemSlot)
		args:
			player (string)
				the name of the player we're looking at.  This is specific to the current realm we're on
			bagID (number)
				the number of the bag we're looking at.
			itemSlot (number)
				the specific item slot we're looking at

		returns:
			itemLink (string)
				The itemlink of the item, in the format item:w:x:y:z
			count (number)
				How many of there are of the specific item
			texture (string)
				The filepath of the item's texture
--]]
function BagnonDB.GetItemData(player, bagID, itemSlot)
	local link, count = GetStoredItem(player, bagID, itemSlot)
	if not link then return nil end
	local _, _, quality, _, _, _, _, _, texture = GetItemInfo(link)
	return link, count, texture, quality
end

local playerTotalsCache = {}

local function BuildPlayerItemIndex(realm, player)
	local playerData = realm and player and BagnonForeverData[realm] and BagnonForeverData[realm][player]
	if not playerData then return nil end

	local cache = {}
	for bagID, bagData in pairs(playerData) do
		if type(bagID) == "number" and type(bagData) == "table" then
			local isBank = (bagID == -1 or (bagID >= 5 and bagID <= 10))
			for itemSlot, itemData in pairs(bagData) do
				if tonumber(itemSlot) and type(itemData) == "string" then
					local _, _, rawID, rawCount = string.find(itemData, "^(%d+)[^,]*,?(%d*)")
					if rawID then
						local itemID = tonumber(rawID)
						if itemID then
							local qty = tonumber(rawCount) or 1
							local entry = cache[itemID]
							if not entry then
								entry = {0, 0}
								cache[itemID] = entry
							end
							if isBank then
								entry[2] = entry[2] + qty
							else
								entry[1] = entry[1] + qty
							end
						end
					end
				end
			end
		end
	end

	if not playerTotalsCache[realm] then
		playerTotalsCache[realm] = {}
	end
	playerTotalsCache[realm][player] = cache
	return cache
end

function BagnonDB.InvalidatePlayerCache(player, realm)
	local targetRealm = realm or GetRealm()
	if not targetRealm then
		table.wipe(playerTotalsCache)
		return
	end

	if player then
		if playerTotalsCache[targetRealm] then
			playerTotalsCache[targetRealm][player] = nil
		end
	else
		if playerTotalsCache[targetRealm] then
			table.wipe(playerTotalsCache[targetRealm])
		else
			table.wipe(playerTotalsCache)
		end
	end
end

--[[
	Returns (invCount, bankCount) of the specific item id across all bags of the given player.
	Backed by an on-demand indexed aggregation cache.
--]]
function BagnonDB.GetPlayerItemTotals(id, player)
	local targetID = tonumber(id)
	if not targetID then return 0, 0 end

	local realm = GetRealm()
	if not realm or not player then return 0, 0 end

	local realmCache = playerTotalsCache[realm]
	local playerCache = realmCache and realmCache[player]
	if not playerCache then
		playerCache = BuildPlayerItemIndex(realm, player)
	end

	if playerCache then
		local entry = playerCache[targetID]
		if entry then
			return entry[1], entry[2]
		end
	end

	return 0, 0
end

--[[
	BagnonDB.GetFreeSlots(player, bagID)
		returns:
			free (number), total (number) saved slots of the bag; reads the saved strings only
--]]
function BagnonDB.GetFreeSlots(player, bagID)
	local size = tonumber((BagnonDB.GetBagData(player, bagID))) or 0
	local realm = GetRealm()
	local playerData = realm and player and BagnonForeverData[realm] and BagnonForeverData[realm][player]
	local bagData = playerData and playerData[bagID]
	local used = 0
	if type(bagData) == "table" then
		for slot, data in pairs(bagData) do
			if type(slot) == "number" and slot > 0 and slot <= size and type(data) == "string" then
				used = used + 1
			end
		end
	end
	return size - used, size
end

--[[
	BagnonDB.GetItemHyperlink(player, bagID, itemSlot)
		args:
			player (string)
				the name of the player we're looking at.  This is specific to the current realm we're on
			bagID (number)
				the number of the bag we're looking at.
			itemSlot (number)
				the specific item slot we're looking at

		returns:
			hyperLink (string)
				This is what's linked in chat, ex |Hitem:6948:0:0:0|H[Hearthstone]|H
--]]
function BagnonDB.GetItemHyperlink(player, bagID, itemSlot)
	local link = GetStoredItem(player, bagID, itemSlot)
	if not link then return nil end
	local name, _, quality = GetItemInfo(link)
	if name then
		local _, _, _, hex = GetItemQualityColor(quality or 1)
		return (hex or "|cffffffff") .. "|H" .. link .. "|h[" .. name .. "]|h|r"
	end
	return "|cffffffff|H" .. link .. "|h[Item " .. link .. "]|h|r"
end
