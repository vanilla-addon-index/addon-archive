--[[
	BagnonForever.lua
		Records inventory data about the current player
		Author: Tuller, McPewPew, Fostercare5988
		Built for the Enhanced WoW 1.12.1 Client (ClassicAPI)

	BagnonForeverData has the following format, which was adapted from KC_Items
	BagnonForeverData = {
		Realm
			Character
				BagID = size,count,[link]
					ItemSlot = link,[count]
				Money = money
	}
--]]

if not Bagnon_EngineReady then
	return
end

--local globals
local currentPlayer = UnitName("player"); --the name of the current player that's logged on
local currentRealm = GetRealmName(); --what currentRealm we're on
local atBank; --is the current player at the bank or not

local function EnsurePlayerAndRealm()
	if not currentPlayer or currentPlayer == "" then
		currentPlayer = UnitName("player")
	end
	if not currentRealm or currentRealm == "" then
		currentRealm = GetRealmName()
	end
	return currentPlayer and currentPlayer ~= "" and currentRealm and currentRealm ~= ""
end

--[[ Utility Functions ]]--

--takes a hyperlink (what you see in chat) and converts it to a shortened item link.
--a shortened item link is either the item:w:x:y:z form without the 'item:' part, or just the item's ID (the 'w' part)
function BagnonForever_HyperlinkToShortLink(hyperLink)
	if(hyperLink) then
		local _, _, w, x, y, z = string.find(hyperLink, "item:(%d+):(%-?%d+):(%-?%d+):(%-?%d+)");
		if not w then return nil end
		if(tonumber(x) == 0 and tonumber(y) == 0 and tonumber(z) == 0) then
			return w;
		else
			return w .. ":" .. x .. ":" .. y .. ":" .. z;
		end
	end
end

--[[  Storage Functions ]]--

-- Read one authoritative slot; SaveBagData owns storage and cache invalidation.
local function ReadItemData(bagID, itemSlot)
	local data = BagnonForever_HyperlinkToShortLink(GetContainerItemLink(bagID, itemSlot))
	if data then
		local _, count = GetContainerItemInfo(bagID, itemSlot)
		if count and count > 1 then
			data = data .. "," .. count
		end
	end
	return data
end

--saves all the data about the current player's bag
local function SaveBagData(bagID)
	if not EnsurePlayerAndRealm() or not BagnonForeverData then return end
	local realmData = BagnonForeverData[currentRealm]
	local playerData = realmData and realmData[currentPlayer]
	if not playerData then return end
	--don't save bank data unless you're at the bank
	if Bagnon_IsBankBag(bagID) and not atBank then
		return;
	end

	local size;
	if(bagID == KEYRING_CONTAINER) then
		size = GetKeyRingSize();
	else
		size = GetContainerNumSlots(bagID);
	end

	local bagData = playerData[bagID]
	local changed = false
	if(size > 0) then
		local link, count;

		if bagID > 0 then
			local invID = ContainerIDToInventoryID(bagID);
			if invID then
				link = BagnonForever_HyperlinkToShortLink( GetInventoryItemLink("player", invID) );
				count = GetInventoryItemCount("player", invID);
			end
		end
		count = count or 0;

		-- Reuse the stored bag; unchanged native batches need no new table/index.
		if type(bagData) ~= "table" then
			bagData = {}
			playerData[bagID] = bagData
			changed = true
		end
		local header = size .. "," .. count .. "," .. (link or "")
		if bagData.s ~= header then bagData.s = header; changed = true end

		--save all item info
		for index = 1, size, 1 do
			local data = ReadItemData(bagID, index)
			if bagData[index] ~= data then bagData[index] = data; changed = true end
		end
		for slot in pairs(bagData) do
			if type(slot) == "number" and slot > size then
				bagData[slot] = nil
				changed = true
			end
		end
	else
		if bagData ~= nil then playerData[bagID] = nil; changed = true end
	end

	if changed then
		BagnonDB.InvalidatePlayerCache(currentPlayer, currentRealm)
	end
end

-- Persist the final carried state once per native bag batch. The bank is read the same
-- way while the banker is accessible; closing the bank flushes it first. The keyring and
-- the main bank slots are not covered by BAG_UPDATE_DELAYED, so they use a next-frame timer.
local dirtyBags = {}
local flushTimer
local function FlushBagData()
	if flushTimer then flushTimer:Cancel(); flushTimer = nil end
	for bag in pairs(dirtyBags) do
		dirtyBags[bag] = nil
		SaveBagData(bag)
	end
end

local function QueueBagData(bag)
	if type(bag) ~= "number" then return end
	if Bagnon_IsBankBag(bag) then
		if not atBank then return end
	elseif bag ~= KEYRING_CONTAINER and (bag < 0 or bag > 4) then
		return
	end
	dirtyBags[bag] = true
	if (bag == KEYRING_CONTAINER or bag == -1) and not flushTimer then
		flushTimer = C_Timer.NewTimer(0, FlushBagData)
	end
end

local function SavePlayerMoney()
	if not EnsurePlayerAndRealm() then return end
	if not BagnonForeverData[currentRealm] then
		BagnonForeverData[currentRealm] = {}
	end
	if not BagnonForeverData[currentRealm][currentPlayer] then
		BagnonForeverData[currentRealm][currentPlayer] = {}
	end
	BagnonForeverData[currentRealm][currentPlayer].g = GetMoney();
end

--save all bank data about the current player
local function SaveBankData()
	SaveBagData(-1);
	local bagID;
	for bagID = 5, 10, 1 do
		SaveBagData(bagID);
	end
end

--save all inventory data about the current player
local function SaveAllData()
	local i;
	--you know, this should probably be a constant
	for i = -2, 10, 1 do
		SaveBagData(i);
	end
	SavePlayerMoney();
end

--[[ Removal Functions ]]--

--removes all saved data about the given player
function BagnonForever_RemovePlayer(player, realm)
	if type(player) ~= "string" or player == "" or type(realm) ~= "string" then return end
	if(BagnonForeverData[realm]) then
		BagnonForeverData[realm][player] = nil;
	end
	BagnonDB.InvalidatePlayerCache(player, realm)
end

--[[
	BagnonForever settings loader
--]]
local function LoadVariables()
	if not EnsurePlayerAndRealm() then return end

	if not BagnonForeverData then
		BagnonForeverData = {}
	end
	-- Retired: written every login, never read.
	BagnonForeverData.version, BagnonForeverData.wowVersion = nil, nil

	BagnonDB.InvalidatePlayerCache()

	if(not BagnonForeverData[currentRealm]) then
		BagnonForeverData[currentRealm] = {};
	end

	if(not BagnonForeverData[currentRealm][currentPlayer]) then
		BagnonForeverData[currentRealm][currentPlayer] = {};
	end
	-- Existing characters also need a current snapshot after offline changes.
	-- Bank data remains untouched until the bank is accessible.
	SaveAllData()
end

--Event handler creation
CreateFrame("Frame", "BagnonForever");

BagnonForever:RegisterEvent("BAG_UPDATE");
BagnonForever:RegisterEvent("BAG_UPDATE_DELAYED");
BagnonForever:RegisterEvent("PLAYER_LOGOUT");
BagnonForever:RegisterEvent("PLAYER_LOGIN");
BagnonForever:RegisterEvent("BANKFRAME_CLOSED");
BagnonForever:RegisterEvent("BANKFRAME_OPENED");
BagnonForever:RegisterEvent("PLAYERBANKSLOTS_CHANGED");
BagnonForever:RegisterEvent("PLAYER_MONEY");

local function BagnonForever_OnEvent(self, ev, a1)
	if(ev == "BAG_UPDATE") then
		QueueBagData(a1);
	elseif ev == "BAG_UPDATE_DELAYED" or ev == "PLAYER_LOGOUT" then
		FlushBagData();
	elseif(ev == "PLAYERBANKSLOTS_CHANGED") then
		QueueBagData(-1);
	elseif(ev == "BANKFRAME_CLOSED") then
		FlushBagData();
		atBank = nil;
	elseif(ev == "BANKFRAME_OPENED") then
		atBank = 1;
		SaveBankData();
	elseif(ev == "PLAYER_MONEY") then
		SavePlayerMoney();
	elseif(ev == "PLAYER_LOGIN") then
		LoadVariables();
		FlushBagData();
		SavePlayerMoney();
	end
end
BagnonForever:SetScript("OnEvent", BagnonForever_OnEvent);
