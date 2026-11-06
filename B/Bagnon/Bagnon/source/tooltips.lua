--[[
	tooltips.lua
		Tooltip integration for Bagnon
		Author: Tuller, McPewPew, Fostercare5988
		Built for the Enhanced WoW 1.12.1 Client (ClassicAPI)
--]]

if not Bagnon_EngineReady then
	return
end

--[[ Local Functions ]]--

-- What the other characters carry of the item
local function AddOwners(frame, id)
	local me = Bagnon_CurrentPlayer()
	local added = false
	for player in BagnonDB.GetPlayers() do
		if player ~= me then
			local invCount, bankCount = BagnonDB.GetPlayerItemTotals(id, player)

			if (invCount + bankCount) > 0 then
				local tooltipString = player .. " " .. BAGNON_FOREVER_HAS
				if invCount > 0 then
					tooltipString = tooltipString .. " " .. invCount .. " " .. BAGNON_FOREVER_BAGS
				end
				if bankCount > 0 then
					tooltipString = tooltipString .. " " .. bankCount .. " " .. BAGNON_FOREVER_BANK
				end
				frame:AddLine(tooltipString, 1, 1, 0)
				added = true
			end
		end
	end
	if added then frame:Show() end
end

-- GearRack (optional addon): the sets and the trinket queue that hold the item
local function AddGearRack(frame, link)
	if not GearRack then return end
	local sets = GearRack.GetSetsWithItem and GearRack.GetSetsWithItem(link)
	if sets then
		frame:AddLine("GearRack: " .. sets, 0.2, 0.8, 1.0)
	end
	local slot = GearRack.GetQueuedSlotForItem and GearRack.GetQueuedSlotForItem(link)
	if slot == 13 then
		frame:AddLine("GearRack: Queued (Top Slot)", 1.0, 0.82, 0.0)
	elseif slot == 14 then
		frame:AddLine("GearRack: Queued (Bottom Slot)", 1.0, 0.82, 0.0)
	end
	if sets or slot == 13 or slot == 14 then frame:Show() end
end

--[[ Item tooltips ]]--

-- One script for every way an item gets into a tooltip (bag, bank, equipped, link, loot, roll,
-- auction, merchant). The client sets the tooltip as this; GetItem returns name, link and ID.
local function OnTooltipSetItem()
	local _, link, id = this:GetItem()
	if not id then return end
	-- A tooltip that is set again without being cleared first is only decorated once.
	if this.bagnonItem == link then return end
	this.bagnonItem = link
	AddOwners(this, id)
	AddGearRack(this, link)
end

local function OnTooltipDone()
	this.bagnonItem = nil
end

for _, tooltip in ipairs({GameTooltip, ItemRefTooltip}) do
	tooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
	tooltip:HookScript("OnTooltipCleared", OnTooltipDone)
	tooltip:HookScript("OnHide", OnTooltipDone)
end

--[[ Money Frame Tooltip ]]--

-- Alters the tooltip of bagnon moneyframes to show total gold across all characters on the current realm
function BagnonFrameMoney_OnEnter(f)
	if f:GetLeft() and f:GetLeft() > (UIParent:GetRight() / 2) then
		GameTooltip:SetOwner(f, "ANCHOR_LEFT")
	else
		GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
	end
	GameTooltip:SetText(string.format(BAGNON_FOREVER_MONEY_ON_REALM, GetRealmName()))

	SetTooltipMoney(GameTooltip, BagnonDB.GetTotalMoney())
	GameTooltip:Show()
end
