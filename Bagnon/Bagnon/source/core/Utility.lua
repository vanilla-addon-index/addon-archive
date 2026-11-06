--[[
	Utility.lua
		Functions that don't belong anywhere else
		Author: Tuller, McPewPew, Fostercare5988
		Built for the Enhanced WoW 1.12.1 Client (ClassicAPI)
--]]

if not Bagnon_EngineReady then
	return
end

local currentPlayer = UnitName("player")

-- The character that is logged in. The name can be empty while the client is still loading.
function Bagnon_CurrentPlayer()
	if not currentPlayer or currentPlayer == "" then
		currentPlayer = UnitName("player")
	end
	return currentPlayer
end

--[[ At the bank ]]--

-- Written by Events.lua when the bank opens and closes; everything else only asks.
local atBank

function Bagnon_SetAtBank(value)
	atBank = value
end

function Bagnon_AtBank()
	return atBank
end

--[[ Search: set by Search.lua while the player has text in a search box ]]--

local searching

function Bagnon_SetSearching(value)
	searching = value
end

function Bagnon_Searching()
	return searching
end

--[[ Boolean functions ]]--

function Bagnon_IsInventoryBag(bagID)
	return bagID == KEYRING_CONTAINER or (bagID >= 0 and bagID < 5)
end

function Bagnon_IsBankBag(bagID)
	return bagID == -1 or (bagID > 4 and bagID < 11)
end

function Bagnon_FrameHasBag(frameName, bagID)
	local frameSets = BagnonSets[frameName]
	local bags = frameSets and frameSets.bags
	if not bags then return false end
	for i = 1, #bags do
		if bags[i] == bagID then return true end
	end
	return false
end

--returns the bag's family bitmask: 0 for a plain bag, 1 quiver, 2 ammo pouch, 4 soul bag,
--and the profession bags above that (C_Item.GetItemFamily). The backpack, bank and keyring have none.
--A cached player's bag reads the family of its saved link; a live bag reads it from the client.
--ClassicAPI answers a bag family for the bags 1..4 only, so a bank bag reads its item.
function Bagnon_BagFamily(bagID, player)
	if bagID <= 0 then return 0 end
	if player then
		local _, link = BagnonDB.GetBagData(player, bagID)
		return link and C_Item.GetItemFamily(link) or 0
	end
	if bagID <= 4 then
		local _, family = C_Container.GetContainerNumFreeSlots(bagID)
		return family
	end
	local link = GetInventoryItemLink("player", ContainerIDToInventoryID(bagID))
	return link and C_Item.GetItemFamily(link) or 0
end

--[[ Detection for Cached Frames.  Only works if we have cached data available ]]--

function Bagnon_IsCachedFrame(frame)
	return Bagnon_CurrentPlayer() ~= frame.player or (not atBank and frame:GetName() == "Banknon")
end

function Bagnon_IsCachedBag(player, bagID)
	return Bagnon_CurrentPlayer() ~= player or (not atBank and Bagnon_IsBankBag(bagID))
end

--returns true if the item is being viewed from a cache
function Bagnon_IsCachedItem(item)
	local bag = item:GetParent()
	--we're not looking at the current player's items
	if Bagnon_CurrentPlayer() ~= bag:GetParent().player then
		return true
	end
	--the bank frame is visible in the normal way
	if atBank then
		return false
	end
	--we're looking at the player's bank away from the actual bank
	return Bagnon_IsBankBag(bag:GetID())
end

function Bagnon_AnchorTooltip(frame)
	GameTooltip:ClearAllPoints()

	if frame:GetLeft() < (UIParent:GetRight() / 2) then
		if frame:GetTop() < (UIParent:GetTop() / 2) then
			GameTooltip:SetPoint("BOTTOMLEFT", frame, "TOPLEFT")
		else
			GameTooltip:SetPoint("TOPLEFT", frame, "BOTTOMRIGHT")
		end
	else
		if frame:GetTop() < (UIParent:GetTop() / 2) then
			GameTooltip:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT")
		else
			GameTooltip:SetPoint("TOPRIGHT", frame, "BOTTOMLEFT")
		end
	end
end

--[[ Messaging ]]--

--send a message to the player
function BagnonMsg(msg, r, g, b)
	DEFAULT_CHAT_FRAME:AddMessage(msg, r or 0, g or 0.7, b or 1)
end
