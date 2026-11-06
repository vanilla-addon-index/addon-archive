--[[
	Overrides.lua
		Function Overrides for Bagnon
		Author: Tuller, McPewPew, Fostercare5988
		Built for ClassicAPI

	OpenBackpack, and CloseBackPack are called automatically
--]]

if not Bagnon_EngineReady then
	return
end

local function BagIsControlledByBagnon(id)
	return (not BagnonSets["Bagnon"] and Bagnon_IsInventoryBag(id)) or Bagnon_FrameHasBag("Bagnon", id)
end

local function BagIsControlledByBanknon(id)
	return BagnonSets.showBankAtBank and Bagnon_FrameHasBag("Banknon", id)
end

local bToggleBag = ToggleBag
ToggleBag = function(id)
	--bag slots
	if BagIsControlledByBagnon(id) then
		BagnonFrame_Toggle("Bagnon")
	--bank slots
	elseif BagIsControlledByBanknon(id) then
		return
	--the blizzard way
	else
		bToggleBag(id)
	end
end

ToggleBackpack = function()
	BagnonFrame_Toggle("Bagnon")
end

local bOpenBag = OpenBag
OpenBag = function(id)
	if BagIsControlledByBagnon(id) then
		BagnonFrame_Open("Bagnon", 1)
	else
		bOpenBag(id)
	end
end

local bCloseBag = CloseBag
CloseBag = function(id)
	if BagIsControlledByBagnon(id) then
		BagnonFrame_Close("Bagnon", 1)
	else
		bCloseBag(id)
	end
end

OpenBackpack = function()
	BagnonFrame_Open("Bagnon", 1)
end

CloseBackpack = function()
	BagnonFrame_Close("Bagnon", 1)
end

--OpenAllBags is actually a toggle unless forceOpen is requested
OpenAllBags = function(forceOpen)
	if forceOpen then
		BagnonFrame_Open("Bagnon", 1)
	else
		BagnonFrame_Toggle("Bagnon")
	end
end

CloseAllBags = function()
	BagnonFrame_Close("Bagnon")
end

local bToggleKeyring = ToggleKeyRing
ToggleKeyRing = function()
	if Bagnon_FrameHasBag("Bagnon", KEYRING_CONTAINER) then
		BagnonFrame_Toggle("Bagnon")
	else
		bToggleKeyring()
	end
end
