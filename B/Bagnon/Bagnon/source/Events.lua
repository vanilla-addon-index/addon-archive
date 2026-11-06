--[[
	Events.lua
		The main event handler for Bagnon and Banknon.
		Author: Tuller, McPewPew, Fostercare5988
		It controls when the frames update, and when and when they are not shown.

		The UI by default fully supports showing/hiding the inventory frame at a vendor and the mailbox
		(through OpenBackpack and CloseBackpack, which Overrides.lua takes over).

		I've extended the behavior in the following ways:
			If a frame was previously shown by a user, it will not automatically close.
			The events of showing the bank and the auction house can also open the inventory or bank windows.
--]]

if not Bagnon_EngineReady then
	return
end

--[[ Local Functions ]]--

local function ShouldUpdateBag(frame, bag)
	return frame:IsVisible() and Bagnon_FrameHasBag(frame:GetName(), bag)
end

local function IsVisibleCachedFrame(frame)
	return frame:IsVisible() and Bagnon_IsCachedFrame(frame)
end

-- Native delayed bag updates collapse loot/sort bursts. Locks, cooldowns,
-- the keyring and main bank slots also use one next-tick refresh because those
-- paths are not all covered by BAG_UPDATE_DELAYED.
local pendingBags = {}
local pendingLocks, pendingCooldowns, pendingCachedMetadata, refreshTimer

local function RefreshFrame(frame, bags, locks, cooldowns, cachedMetadata)
	if not frame:IsVisible() then return end
	if Bagnon_IsCachedFrame(frame) then
		-- Item data can become resident after a cached view was built.
		-- Read its current owner now; never retain a queued player/frame.
		if cachedMetadata then BagnonFrame_Generate(frame) end
		return
	end
	local rebuilt = BagnonFrame_UpdateBags(frame, bags)
	if rebuilt then return end
	if locks then BagnonFrame_UpdateLock(frame, bags) end
	if cooldowns then
		local items = frame.items
		for slot = 1, frame.size or 0 do
			local item = items[slot]
			if item.hasItem and not item.isLink then
				local bagID = item:GetParent():GetID()
				if not bags[bagID] then BagnonItem_UpdateCooldown(bagID, item) end
			end
		end
	end
end

local function FlushUpdates()
	if refreshTimer then refreshTimer:Cancel(); refreshTimer = nil end
	local bags, locks, cooldowns, cachedMetadata = pendingBags, pendingLocks, pendingCooldowns, pendingCachedMetadata
	pendingBags, pendingLocks, pendingCooldowns, pendingCachedMetadata = {}, nil, nil, nil
	RefreshFrame(Bagnon, bags, locks, cooldowns, cachedMetadata)
	RefreshFrame(Banknon, bags, locks, cooldowns, cachedMetadata)
end

local function ScheduleRefresh()
	if not refreshTimer then
		local timer
		timer = C_Timer.NewTimer(0, function() if refreshTimer == timer then FlushUpdates() end end)
		refreshTimer = timer
	end
end

local function QueueBagUpdate(bag)
	if type(bag) ~= "number" then return end
	if ShouldUpdateBag(Bagnon, bag) or ShouldUpdateBag(Banknon, bag) then pendingBags[bag] = true end
	if bag == KEYRING_CONTAINER or bag == -1 then ScheduleRefresh() end
end

local function OpenIF(frameName, condition)
	if condition then
		BagnonFrame_Open(frameName, 1)
		return true
	end
end

local function CloseIF(frameName, condition)
	if condition then
		BagnonFrame_Close(frameName, 1)
	end
end

--[[
	Taken from Blizzard's code
	Shows the normal bank frame
--]]
local function ShowBlizBank()
	BankFrameTitleText:SetText(UnitName("npc"))
	SetPortraitTexture(BankPortraitTexture,"npc")
	ShowUIPanel(BankFrame)
	if not BankFrame:IsVisible() then
		CloseBankFrame()
	end
	UpdateBagSlotStatus()
end

--[[ Variable Loading ]]--

-- Settings of triggers and options that were taken out. Cleared so they do not sit in the file.
local RETIRED_SETTINGS = {
	"version", "showTooltips", "qualityBorders", "showForeverTooltips", "showBagsAtVendor", "showBagsAtMail", "showBagsAtTrade", "showBagsAtCraft",
	"showBankAtVendor", "showBankAtAH", "showBankAtMail", "showBankAtTrade", "showBankAtCraft",
}

local function LoadVariables()
	if type(BagnonSets) ~= "table" then
		BagnonSets = {
			showBagsAtBank = 1,
			showBagsAtAH = 1,
			showBankAtBank = 1,
			enchantBadges = 1,
			showFreeSlots = 1,
		}
		return
	end
	for _, key in ipairs(RETIRED_SETTINGS) do
		BagnonSets[key] = nil
	end
	if BagnonSets.enchantBadges == nil then
		BagnonSets.enchantBadges = 1
	end
	if BagnonSets.showFreeSlots == nil then
		BagnonSets.showFreeSlots = 1
	end
end

local function Load(eventFrame)
	BankFrame:UnregisterEvent("BANKFRAME_OPENED")

	LoadVariables()
	-- Retired: the bank had a sort-ignore toggle here; ClassicAPI keeps the value, so clear it.
	C_Container.SetBankAutosortDisabled(false)

	eventFrame:RegisterEvent("UI_SCALE_CHANGED")
	eventFrame:RegisterEvent("BAG_UPDATE")
	eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
	eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
	eventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
	eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
	eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
	eventFrame:RegisterEvent("BANKFRAME_OPENED")
	eventFrame:RegisterEvent("BANKFRAME_CLOSED")
	eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
	eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
	eventFrame:RegisterEvent("MAIL_CLOSED")
end

local function OnEvent(f, ev, a1, a2)

	--[[ Events For Updating Items ]]--
	if ev == "BAG_UPDATE_COOLDOWN" then
		pendingCooldowns = true; ScheduleRefresh()
	elseif ev == "GET_ITEM_INFO_RECEIVED" then
		-- ClassicAPI emits success as 1/nil. Hidden/live views need no metadata-only
		-- timer or item regeneration.
		if a2 and (IsVisibleCachedFrame(Bagnon) or IsVisibleCachedFrame(Banknon)) then
			pendingCachedMetadata = true; ScheduleRefresh()
		end
	elseif ev == "BAG_UPDATE" then
		QueueBagUpdate(a1)
	elseif ev == "BAG_UPDATE_DELAYED" then
		FlushUpdates()
	elseif ev == "PLAYERBANKSLOTS_CHANGED" then
		QueueBagUpdate(-1)
	elseif ev == "ITEM_LOCK_CHANGED" then
		pendingLocks = true; ScheduleRefresh()
	--the keyring's size changes based on the player's level
	elseif ev == "PLAYER_LEVEL_UP" then
		if ShouldUpdateBag(Bagnon, KEYRING_CONTAINER) then
			BagnonFrame_Generate(Bagnon)
		end
	--the frames keep their place when the interface scale or the window size changes
	elseif ev == "UI_SCALE_CHANGED" then
		BagnonFrame_Reposition(Bagnon)
		BagnonFrame_Reposition(Banknon)
	--[[ Events for Automatically Opening and Closing Frames ]]--
	elseif ev == "BANKFRAME_OPENED" then
		Bagnon_SetAtBank(true)
		Banknon.player = UnitName("player")
		Banknon.manOpened = nil
		BanknonTitle:SetText(format(Banknon.title, Banknon.player))
		OpenIF("Bagnon", BagnonSets.showBagsAtBank)
		if not OpenIF("Banknon", BagnonSets.showBankAtBank) then
			-- An already visible cached bank becomes the live player's bank even
			-- when automatic bank-window opening is disabled.
			if Banknon:IsShown() then BagnonFrame_Open("Banknon", 1) end
			ShowBlizBank()
		end
		-- A bank window that was already open now buys slots and sorts like the live one.
		if Banknon:IsShown() then Banknon_UpdatePurchaseButtonVis() end
	elseif ev == "BANKFRAME_CLOSED" then
		Bagnon_SetAtBank(nil)
		Banknon.manOpened = nil
		BagnonFrame_Close("Banknon")
		CloseIF("Bagnon", BagnonSets.showBagsAtBank)
	elseif ev == "AUCTION_HOUSE_SHOW" then
		OpenIF("Bagnon", BagnonSets.showBagsAtAH)
	elseif ev == "AUCTION_HOUSE_CLOSED" then
		CloseIF("Bagnon", BagnonSets.showBagsAtAH)
	elseif ev == "MAIL_CLOSED" then
		-- The mailbox opens the backpack through OpenBackpack and never closes it.
		CloseIF("Bagnon", true)
	--Loading event
	elseif ev == "ADDON_LOADED" and a1 == "Bagnon" then
		f:UnregisterEvent("ADDON_LOADED")
		Load(f)
	end
end

--create the event handler frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", OnEvent)
