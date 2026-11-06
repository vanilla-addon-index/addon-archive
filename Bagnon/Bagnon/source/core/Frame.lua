--[[
	Frame.lua
		Functionality for Bagnon Inventory/Bank frames
		Author: Tuller, McPewPew, Fostercare5988
		Built for the Enhanced WoW 1.12.1 Client (ClassicAPI)

	BagSlots:
		-2: Key (1.11)
		-1: Bank (24 slots)
		0:  Main Inventory (16 slots)
		1, 2, 3, 4: Inventory Bags (16 - 32?)
		5, 6, 7, 8, 9, 10:  Bank Bags (16 - 32?)

	TODO:
		Potentially, I can make the frame completely dynamically generated and merge Bagnon, Bagnon_Core, and Banknon
--]]

if not Bagnon_EngineReady then
	return
end

--Local constants
local FRAMESTRATA = {"LOW", "MEDIUM", "HIGH"}
local DEFAULT_COLS = 10
local DEFAULT_SPACING = 2
local DEFAULT_ALPHA = 0.85
local DEFAULT_BG = {r = 0, g = 0, b = 0, a = 1}
local FRAME_DEFAULTS = {stayOnScreen = 1, cols = DEFAULT_COLS, space = DEFAULT_SPACING, alpha = DEFAULT_ALPHA, strata = 3, bagsShown = 1}
local PLAYER_BAGS = {0, 1, 2, 3, 4}
local BANK_BAGS = {-1, 5, 6, 7, 8, 9, 10}
local BAG_BAR_GAP = 8	-- between the bag icons and the bottom row, as wide as between the grid and the icons

local function SavedNumber(value, default, minimum, maximum)
	local number = tonumber(value)
	if not number or number ~= number or number == math.huge or number == -math.huge then return default end
	if minimum and number < minimum then return default end
	if maximum and number > maximum then return default end
	return number
end

--[[
	Load settings for the frame
--]]

function BagnonFrame_Load(frame, bags, title)
	local frameName = frame:GetName()
	frame.items = frame.items or {}

	--make frame close on escape
	tinsert(UISpecialFrames, frameName)

	--fill in whatever the saved settings of the frame lack
	if type(BagnonSets[frameName]) ~= "table" then
		BagnonSets[frameName] = {}
	end
	local settings = BagnonSets[frameName]
	for key, default in pairs(FRAME_DEFAULTS) do
		if settings[key] == nil then settings[key] = default end
	end
	if type(settings.bg) ~= "table" then
		settings.bg = {r = 0, g = 0, b = 0, a = 1}
	end
	settings.cols = math.floor(SavedNumber(settings.cols, DEFAULT_COLS, 1, 32))
	settings.space = SavedNumber(settings.space, DEFAULT_SPACING, 0, 32)
	settings.alpha = SavedNumber(settings.alpha, DEFAULT_ALPHA, 0, 1)
	settings.strata = math.floor(SavedNumber(settings.strata, 3, 1, 3))
	settings.scale = SavedNumber(settings.scale, 1, 0.01)
	settings.parentScale = SavedNumber(settings.parentScale, nil, 0.01)
	settings.top = SavedNumber(settings.top, nil)
	settings.left = SavedNumber(settings.left, nil)
	for channel, default in pairs(DEFAULT_BG) do
		settings.bg[channel] = SavedNumber(settings.bg[channel], default, 0, 1)
	end

	--add what bags are controlled by the frame
	if type(settings.bags) ~= "table" then
		settings.bags = bags
	end

	--set the frame's transparency
	frame:SetAlpha(settings.alpha)

	--set the frame's background
	local bgSets = settings.bg
	frame:SetBackdropColor(bgSets.r, bgSets.g, bgSets.b, bgSets.a)
	frame:SetBackdropBorderColor(1, 1, 1, bgSets.a)

	--set the frame's layer (low, medium, or high)
	BagnonFrame_SetStrata(frame, settings.strata)

	local bagFrame = _G[frameName .. "Bags"]
	local showBagsBtn = _G[frameName .. "ShowBags"]
	if bagFrame then
		if settings.bagsShown == 1 then
			bagFrame:Show()
			showBagsBtn:SetText(BAGNON_HIDEBAGS)
		else
			bagFrame:Hide()
			showBagsBtn:SetText(BAGNON_SHOWBAGS)
		end
	end

	frame:SetClampedToScreen(settings.stayOnScreen == 1)

	frame.defaultBags = bags

	--the character switcher for cached data
	frame.player = UnitName("player")

	local dropdownButton = CreateFrame("Button", frameName .. "DropDown", frame, "BagnonDBUIDropDownButton")
	dropdownButton:SetAlpha(frame:GetAlpha())
	_G[frameName .. "Title"]:SetPoint("TOPLEFT", dropdownButton, "TOPRIGHT", 4, 2)

	BagnonFrame_OrderBags(frame, settings.reverse)

	--set the frame's title
	frame.title = title
	_G[frameName .. "Title"]:SetText(format(frame.title, UnitName("player")))
	frame:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonUp")

	--create the frame
	--reposition actually handles rescaling
	BagnonFrame_Reposition(frame)
	BagnonFrame_Generate(frame)
end

--[[
	Generate the frame (add all items, resize)
--]]

function BagnonFrame_Generate(frame)
	frame.size = 0
	local bagSizes = frame.bagSizes
	if bagSizes then table.wipe(bagSizes) else frame.bagSizes = {} end
	local frameName = frame:GetName()
	local frameSets = BagnonSets[frameName]
	local bags

	if not frameSets then
		return
	end

	-- cached frames use their default bag list
	local cached = Bagnon_IsCachedFrame(frame)
	if cached then
		bags = frame.defaultBags or frameSets.bags
		MoneyFrame_Update(frameName .. "MoneyFrame", BagnonDB.GetMoney(frame.player))
	-- normal frames use the current saved bag list
	else
		bags = frameSets.bags
		MoneyFrame_Update(frameName .. "MoneyFrame", GetMoney())
	end

	if not bags then
		return
	end

	for _, bagID in pairs(bags) do
		BagnonFrame_AddBag(frame, bagID)
	end

	_G[frameName .. "SortButton"]:SetAlpha(cached and 0.4 or 1.0)
	BagnonSearch_Update(frame, cached)

	BagnonFrame_Layout(frame, frameSets.cols, frameSets.space)
	BagnonFrame_UpdateFreeSlots(frame)
	frame.generatedPlayer = frame.player
	frame.generatedCached = cached and true or false
	--frame:Show()
end

--[[
	Add all the slots of the given bag to the given frame.
	Increase the total size of frame to include the size of the bag
--]]

-- The frame keeps one holder frame per bag; the slots of the bag are its children.
local function GetHolder(frame, bagID)
	local holders = frame.holders
	if not holders then
		holders = {}
		frame.holders = holders
	end
	local holder = holders[bagID]
	if not holder then
		holder = CreateFrame("Frame", frame:GetName() .. "DummyBag" .. bagID, frame)
		holder:SetID(bagID)
		holders[bagID] = holder
	end
	return holder
end

local function LiveBagSize(bagID)
	if bagID == KEYRING_CONTAINER then return GetKeyRingSize() end
	if bagID <= 0 or GetInventoryItemTexture("player", ContainerIDToInventoryID(bagID)) then
		return GetContainerNumSlots(bagID)
	end
	return 0
end

function BagnonFrame_AddBag(frame, bagID)
	local frameName = frame:GetName()
	local slot = frame.size

	local bagSize
	if Bagnon_IsCachedBag(frame.player, bagID) then
		local size = BagnonDB.GetBagData(frame.player, bagID)
		bagSize = tonumber(size) or 0
	else
		bagSize = LiveBagSize(bagID)
	end
	frame.bagSizes[bagID] = bagSize

	--update used slots
	local holder = GetHolder(frame, bagID)
	holder.bagFamily = nil
	local items = frame.items
	for index = 1, bagSize, 1 do
		slot = slot + 1
		local item = items[slot] or BagnonItem_Create(frameName .. "Item" .. slot, holder)
		items[slot] = item
		item:SetID(index)
		item:SetParent(holder)
		item:Show()

		BagnonItem_Update(item)
	end

	frame.size = frame.size + bagSize
end

--[[
	Resize and hide any unusable bag slots in the frame.
		This function needs to know about the layout of the frame
--]]

function BagnonFrame_TrimToSize(frame)
	if not frame.space then return end

	local height

	--hide unused slots
	local items = frame.items
	for slot = (frame.size or 0) + 1, #items do
		items[slot]:Hide()
	end

	--set the frame's width
	--correction for any frame that's completely empty
	if not frame.size or frame.size == 0 then
		height = 64
		frame:SetWidth(256)
	else
		--15 is the estimated border width of the frame, 37 is the width of an item button
		if frame.size < frame.cols then
			frame:SetWidth((37 + frame.space) * frame.size + 16 - frame.space)
		else
			frame:SetWidth((37 + frame.space) * frame.cols + 16 - frame.space)
		end

		--set the frame's height, adjusted to fit a bag frame if its shown/there is one
		height = (37 + frame.space) * math.ceil(frame.size / frame.cols)  + 64 - frame.space
	end

	--adjust for the bag frame, if present
	local bagFrame = _G[frame:GetName() .. "Bags"]

	if bagFrame and bagFrame:IsShown() then
		frame:SetHeight(height + bagFrame:GetHeight() + BAG_BAR_GAP)

		if frame:GetWidth() < bagFrame:GetWidth() then
			--the +8 is for correcting for the border width of the frame
			frame:SetWidth(bagFrame:GetWidth() + 8)
		end
	else
		frame:SetHeight(height)
	end
end


-- Rebind only when the current live container sizes differ. The bag bar and
-- main event controller can observe the same resize in either callback order.
function BagnonFrame_RefreshSize(frame)
	if Bagnon_IsCachedFrame(frame) then return false end
	if not frame.bagSizes then
		BagnonFrame_Generate(frame)
		return true
	end
	for _, bag in pairs(BagnonSets[frame:GetName()].bags) do
		if frame.bagSizes[bag] ~= LiveBagSize(bag) then
			BagnonFrame_Generate(frame)
			return true
		end
	end
	return false
end

-- Update all item information for usable slots
function BagnonFrame_Update(frame, bagID, inBatch)
	if not frame.size or Bagnon_IsCachedFrame(frame) then return end

	-- Rebind buttons before partial updates when a container's size changes.
	-- The bag-bar event handler may be hidden, or run after this handler.
	if not inBatch and BagnonFrame_RefreshSize(frame) then return end
	local startSlot = 1
	local endSlot

	--if we don't know the ID of the bag that updated, then update all slots, else only update the necessary slots.
	if not bagID then
		endSlot = frame.size
	else
		for _, bag in pairs(BagnonSets[frame:GetName()].bags) do
			if bag == bagID then
				endSlot = startSlot + frame.bagSizes[bag] - 1
				break
			else
				startSlot = startSlot + frame.bagSizes[bag]
			end
		end
	end
	if not endSlot then return end

	--a bag may have been replaced: read its family again for the border colours
	for bag, holder in pairs(frame.holders) do
		if not bagID or bag == bagID then holder.bagFamily = nil end
	end

	--update the necessary slots
	local items = frame.items
	for slot = startSlot, endSlot do
		BagnonItem_Update(items[slot])
	end

	if not inBatch then BagnonFrame_UpdateFreeSlots(frame) end
end

-- A native inventory batch can dirty several bags. Check the shared binding
-- layout once, update only those bags, then publish the free-space counter once.
-- Return true when regeneration already refreshed every item's lock/cooldown.
function BagnonFrame_UpdateBags(frame, bags)
	if not frame.size or Bagnon_IsCachedFrame(frame) then return end
	local selected = BagnonSets[frame:GetName()].bags
	local dirty
	for _, bag in pairs(selected) do
		if bags[bag] then dirty = true; break end
	end
	if not dirty then return end
	if BagnonFrame_RefreshSize(frame) then return true end
	for _, bag in pairs(selected) do
		if bags[bag] then BagnonFrame_Update(frame, bag, true) end
	end
	BagnonFrame_UpdateFreeSlots(frame)
end

function BagnonFrame_UpdateLock(frame, refreshedBags)
	if not frame.size or Bagnon_IsCachedFrame(frame) then return end

	local items = frame.items
	for slot = 1, frame.size do
		local item = items[slot]
		local bagID = item:GetParent():GetID()
		if not (refreshedBags and refreshedBags[bagID]) then
			local _, _, locked = GetContainerItemInfo(bagID, item:GetID())
			BagnonItem_SetLocked(item, locked)
		end
	end
end

-- Layout the frame with given number of columns and button spacing
function BagnonFrame_Layout(frame, cols, space)
	if not frame.size or frame.size == 0 then return end

	local frameName = frame:GetName()
	local frameSets = BagnonSets[frameName]

	cols = cols or frameSets.cols or DEFAULT_COLS
	space = space or frameSets.space or DEFAULT_SPACING
	frameSets.cols = cols
	frameSets.space = space
	frame.cols = cols
	frame.space = space

	-- The buttons hang on each other by slot number, so the same count, columns and
	-- spacing leave them where they are.
	if frame.laidSize ~= frame.size or frame.laidCols ~= cols or frame.laidSpace ~= space then
		local items = frame.items
		for slot = 1, frame.size do
			local button = items[slot]
			button:ClearAllPoints()
			if slot == 1 then
				button:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -31)
			elseif (slot - 1) % cols == 0 then
				button:SetPoint("TOP", items[slot - cols], "BOTTOM", 0, -space)
			else
				button:SetPoint("LEFT", items[slot - 1], "RIGHT", space, 0)
			end
		end
		frame.laidSize, frame.laidCols, frame.laidSpace = frame.size, cols, space
	end

	BagnonFrame_TrimToSize(frame)
end

--[[
	Safe Open/Close/Toggle <frame>
--]]

function BagnonFrame_Open(frameName, automatic)
	local frame = _G[frameName]
	if not frame then
		return
	end

	-- Native OpenAllBags can call this for several bags in the same visible
	-- window. Inventory events keep that view current; regenerate only on open
	-- or when its cached/live owner changed.
	if not frame:IsShown() or frame.generatedPlayer ~= frame.player or
		frame.generatedCached ~= (Bagnon_IsCachedFrame(frame) and true or false) then
		BagnonFrame_Generate(frame)
	end
	frame:Show()

	if not automatic then
		frame.manOpened = 1
	end
end

function BagnonFrame_Close(frameName, automatic)
	local frame = _G[frameName]
	if frame then
		if not(automatic and frame.manOpened) then
			frame:Hide()
			frame.manOpened = nil
		end
	end
end

function BagnonFrame_Toggle(frameName)
	local frame = _G[frameName]
	if not frame then
		return
	end

	if frame:IsVisible() then
		BagnonFrame_Close(frameName)
	else
		BagnonFrame_Open(frameName)
	end
end

--[[
	Highlight all the slots of <bag>
--]]

function BagnonFrame_HighlightSlots(frame, bagID)
	if not frame.size then return end

	local items = frame.items
	for slot = 1, frame.size do
		local item = items[slot]
		if item:GetParent():GetID() == bagID then
			item:LockHighlight()
		end
	end
end

function BagnonFrame_UnhighlightAll(frame)
	if not frame.size then return end

	local items = frame.items
	for slot = 1, frame.size do
		items[slot]:UnlockHighlight()
	end
end

--[[
	Add/Remove <Bag> from the frame
--]]

function BagnonFrame_ToggleBag(frame, bagID)
	if not frame then return end

	local frameName = frame:GetName()

	-- add bag
	if not Bagnon_FrameHasBag(frameName, bagID) then
		table.insert(BagnonSets[frameName].bags, bagID)
	-- remove bag
	else
		for index, id in ipairs(BagnonSets[frameName].bags) do
			if id == bagID then
				table.remove(BagnonSets[frameName].bags, index)
				break
			end
		end
	end

	BagnonFrame_OrderBags(frame, BagnonSets[frameName].reverse)

	if frame:IsShown() then
		BagnonFrame_Generate(frame)
	end
end

--[[
	Frame Positioning Functions
--]]

function BagnonFrame_StartMoving(frame)
	if not BagnonSets[frame:GetName()].locked then
		frame.isMoving = 1
		frame:StartMoving()
	end
end

function BagnonFrame_StopMoving(frame)
	frame.isMoving = nil
	frame:StopMovingOrSizing()
	BagnonFrame_SavePosition(frame)
end

--Place the frame at the last place it was at.
--This is used when the frame first loads because the game currently does not remember the last position of a frame that's dynamically loaded
function BagnonFrame_Reposition(frame)
	local frameName = frame:GetName()
	if not BagnonSets[frameName] then return end

	local top = BagnonSets[frameName].top
	local left = BagnonSets[frameName].left
	if not (top and left) then return end

	local scale = BagnonSets[frameName].scale or 1
	local parent = frame:GetParent() or UIParent
	local parentScale = parent:GetScale() or 1

	local ratio = 1
	if BagnonSets[frameName].parentScale and parentScale > 0 then
		ratio = BagnonSets[frameName].parentScale / parentScale
	end

	frame:ClearAllPoints()
	frame:SetScale(scale)
	frame:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", left * ratio, top * ratio)
end

--Save the frame's current position.  Needed because frames don't remember their positions if dynamically loaded.
function BagnonFrame_SavePosition(frame)
	local frameName = frame:GetName()
	if not BagnonSets[frameName] then return end

	local top = frame:GetTop()
	local left = frame:GetLeft()
	if top and left and top > 0 and left > 0 then
		BagnonSets[frameName].top = top
		BagnonSets[frameName].left = left
		BagnonSets[frameName].scale = frame:GetScale()
		if frame:GetParent() then
			BagnonSets[frameName].parentScale = frame:GetParent():GetScale()
		end
	end
end

--set the layer of the frame
function BagnonFrame_SetStrata(frame, strata)
	BagnonSets[frame:GetName()].strata = strata
	frame:SetFrameStrata(FRAMESTRATA[strata])
end

--[[
	Tooltip Functions
--]]

--tooltips for the title
function BagnonFrame_OnEnter(f)
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("TOPLEFT", f, "BOTTOMLEFT", -2, 0)
	GameTooltip:SetOwner(f, "ANCHOR_PRESERVE")
	GameTooltip:SetText(f:GetText(), 1, 1, 1)
	GameTooltip:AddLine(BAGNON_TITLE_TOOLTIP)
	GameTooltip:Show()
end

function BagnonFrame_OnLeave()
	GameTooltip:Hide()
end

--[[
	Money Frame
--]]

--the enter tooltip (gold of every character) is in tooltips.lua
function BagnonFrameMoney_OnLeave()
	GameTooltip:Hide()
end

-- This is a hack that enables tooltips but still allows clicking on the money frame
function BagnonFrameMoney_OnClick(f)
	local parent = f:GetParent()
	local parentName = parent:GetName()

	if MouseIsOver(_G[parentName .. "GoldButton"]) then
		OpenCoinPickupFrame(COPPER_PER_GOLD, MoneyTypeInfo[parent.moneyType].UpdateFunc(), parent)
		parent.hasPickup = 1
	elseif MouseIsOver(_G[parentName .. "SilverButton"]) then
		OpenCoinPickupFrame(COPPER_PER_SILVER, MoneyTypeInfo[parent.moneyType].UpdateFunc(), parent)
		parent.hasPickup = 1
	elseif MouseIsOver(_G[parentName .. "CopperButton"]) then
		OpenCoinPickupFrame(1, MoneyTypeInfo[parent.moneyType].UpdateFunc(), parent)
		parent.hasPickup = 1
	end
end

--[[
	Rightclick Menu Stuff
--]]

--hide any menus attached to the frame, if they're visible and we're hiding the frame
function BagnonFrame_OnHide(f)
	BagnonSearch_Close(f)
	if BagnonDBUICharacterList.frame == f then
		BagnonDBUICharacterList:Hide()
	end
end

function BagnonFrame_OnClick(frame, mouseButton)
	if mouseButton == "RightButton" then
		BagnonOptions_Open(frame:GetName())
	end
end

--[[
	Bag Sorting
--]]

--when sorting in reverse, the keyring is always at the top of the frame
local function ReverseSort(a, b)
	if a == KEYRING_CONTAINER then
		return true
	elseif b == KEYRING_CONTAINER then
		return false
	elseif a and b then
		return a > b
	end
end

--when sorting in normal order, the keyring is always at the bottom of the frame
local function NormalSort(a, b)
	if a == KEYRING_CONTAINER then
		return false
	elseif b == KEYRING_CONTAINER then
		return true
	elseif a and b then
		return a < b
	end
end

function BagnonFrame_OrderBags(frame, reverse)
	if reverse then
		if frame then
			table.sort(BagnonSets[frame:GetName()].bags, ReverseSort)
			if frame.defaultBags then
				table.sort(frame.defaultBags, ReverseSort)
			end
		end
	else
		if frame then
			table.sort(BagnonSets[frame:GetName()].bags, NormalSort)
			if frame.defaultBags then
				table.sort(frame.defaultBags, NormalSort)
			end
		end
	end
end

--[[
	Modern Bag/Bank Sorting (ClassicAPI, v1.15.13+ equipment slot grouping)
--]]

function Bagnon_RequestSort(bank)
	PlaySound("igMainMenuOption")
	if bank then C_Container.SortBankBags() else C_Container.SortBags() end
	return true -- request dispatched, not confirmed completion
end

function BagnonFrameSort_OnClick(frame, btn)
	-- Right-Click: toggle sort direction (Left-to-Right vs Right-to-Left)
	if btn == "RightButton" then
		local current = C_Container.GetSortBagsRightToLeft()
		local newOrder = not current
		C_Container.SetSortBagsRightToLeft(newOrder)
		PlaySound("igMainMenuOption")
		local orderStr = newOrder and BAGNON_SORT_RIGHT_TO_LEFT or BAGNON_SORT_LEFT_TO_RIGHT
		BagnonMsg(format(BAGNON_SORT_DIRECTION_CHANGED, orderStr))
		local sortBtn = _G[frame:GetName() .. "SortButton"]
		if GameTooltip:IsOwned(sortBtn) then
			BagnonFrameSort_OnEnter(sortBtn)
		end
		return
	end

	-- Left-Click: execute sort
	if Bagnon_IsCachedFrame(frame) then
		BagnonMsg(BAGNON_CANNOT_SORT_OFFLINE)
		return
	end

	if frame:GetName() == "Banknon" then
		if not Bagnon_AtBank() then
			BagnonMsg(BAGNON_CANNOT_SORT_BANK_AWAY)
			return
		end
		Bagnon_RequestSort(true)
	else
		Bagnon_RequestSort(false)
	end
end

function BagnonFrameSort_OnEnter(f)
	local frame = f:GetParent()
	local isBank = (frame and frame:GetName() == "Banknon")

	GameTooltip:SetOwner(f, "ANCHOR_TOPRIGHT")
	GameTooltip:SetText(isBank and BAGNON_SORT_BANK or BAGNON_SORT_BAGS, 1, 1, 1)

	if Bagnon_IsCachedFrame(frame) then
		GameTooltip:AddLine(BAGNON_CANNOT_SORT_OFFLINE, 1, 0.2, 0.2)
	elseif isBank and not Bagnon_AtBank() then
		GameTooltip:AddLine(BAGNON_CANNOT_SORT_BANK_AWAY, 1, 0.2, 0.2)
	else
		GameTooltip:AddLine(BAGNON_SORT_TOOLTIP_LEFT, 0.8, 0.8, 0.8)
		local r2l = C_Container.GetSortBagsRightToLeft()
		local orderStr = r2l and BAGNON_SORT_RIGHT_TO_LEFT or BAGNON_SORT_LEFT_TO_RIGHT
		GameTooltip:AddLine(format(BAGNON_SORT_TOOLTIP_RIGHT, orderStr), 0.6, 0.8, 1)
	end
	GameTooltip:Show()
end

function BagnonFrameSort_OnLeave()
	GameTooltip:Hide()
end

--[[
	Free Slot Counter
--]]

-- ClassicAPI counts free slots for the backpack and bags 1..4 only; it answers 0 for
-- the bank and its bags, so those are counted slot by slot.
local function FreeSlotsOf(bagID, numSlots)
	if bagID >= 0 and bagID <= 4 then
		return C_Container.GetContainerNumFreeSlots(bagID) or 0
	end
	local free = 0
	for slot = 1, numSlots do
		if not GetContainerItemInfo(bagID, slot) then free = free + 1 end
	end
	return free
end

function BagnonFrame_UpdateFreeSlots(frame)
	if not frame then return end
	local frameName = frame:GetName()
	local freeSlotsBtn = _G[frameName .. "FreeSlots"]
	local titleBtn = _G[frameName .. "Title"]
	local sortBtn = _G[frameName .. "SortButton"]
	local closeBtn = _G[frameName .. "CloseButton"]

	local dropdownBtn = _G[frameName .. "DropDown"]
	local dropdownShown = dropdownBtn:IsShown() and true or false
	local showFree = BagnonSets.showFreeSlots ~= 0
	local showSort = BagnonSets.showSortButton ~= 0
	-- Item/lock bursts change counts, not these owned title anchors. Rebuild
	-- only when the dropdown or an option that moves the header controls changes.
	if frame.headerDropdown ~= dropdownShown or frame.headerSort ~= showSort then
		frame.headerDropdown, frame.headerSort = dropdownShown, showSort
		if showSort then sortBtn:Show() else sortBtn:Hide() end
		-- The free space ends at the left-most control that is shown. The title always
		-- ends at the free space, shown or not, so its height and text never move.
		freeSlotsBtn:ClearAllPoints()
		if showSort then
			freeSlotsBtn:SetPoint("RIGHT", sortBtn, "LEFT", -12, 0)
		else
			freeSlotsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
		end
		titleBtn:ClearAllPoints()
		if dropdownShown then
			titleBtn:SetPoint("TOPLEFT", dropdownBtn, "TOPRIGHT", 4, 2)
		else
			titleBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -2)
		end
		titleBtn:SetPoint("BOTTOMRIGHT", freeSlotsBtn, "BOTTOMLEFT", -6, 0)
	end
	if not showFree then
		if freeSlotsBtn:IsShown() then freeSlotsBtn:Hide() end
		return
	end
	if not freeSlotsBtn:IsShown() then freeSlotsBtn:Show() end

	local freeSlots = 0
	local totalSlots = 0

	if Bagnon_IsCachedFrame(frame) then
		local bags = frame.defaultBags or (BagnonSets[frameName] and BagnonSets[frameName].bags)
		if bags then
			for _, bagID in pairs(bags) do
				if tonumber(bagID) ~= KEYRING_CONTAINER then
					local free, size = BagnonDB.GetFreeSlots(frame.player, bagID)
					freeSlots = freeSlots + free
					totalSlots = totalSlots + size
				end
			end
		end
	else
		-- Every bag of the frame's own range, the way the tooltip counts them.
		-- CalculateTotalNumberOfFreeBagSlots leaves specialty bags out of the free count
		-- while the total here includes them.
		local liveBags = frameName == "Banknon" and BANK_BAGS or PLAYER_BAGS
		for _, bagID in ipairs(liveBags) do
			local numSlots = GetContainerNumSlots(bagID)
			if numSlots and numSlots > 0 then
				totalSlots = totalSlots + numSlots
				freeSlots = freeSlots + FreeSlotsOf(bagID, numSlots)
			end
		end
	end

	if freeSlotsBtn.freeSlots ~= freeSlots or freeSlotsBtn.totalSlots ~= totalSlots then
		freeSlotsBtn:SetText(format(BAGNON_FREE_SLOTS_FORMAT or "%d / %d Free", freeSlots, totalSlots))
		freeSlotsBtn.freeSlots = freeSlots
		freeSlotsBtn.totalSlots = totalSlots
	end
end

function BagnonFrameFreeSlots_OnEnter(f)
	local frame = f:GetParent()
	local frameName = frame:GetName()

	GameTooltip:SetOwner(f, "ANCHOR_TOPLEFT")
	GameTooltip:SetText(format(BAGNON_FREE_SLOTS_TITLE or "Free Space: %d / %d", f.freeSlots or 0, f.totalSlots or 0), 1, 1, 1)

	local bags = frame.defaultBags or (BagnonSets[frameName] and BagnonSets[frameName].bags)
	if bags then
		for _, bagID in pairs(bags) do
			local numBagID = tonumber(bagID)
			if numBagID and numBagID ~= KEYRING_CONTAINER then
				local bagName, numFree, numTotal
				if Bagnon_IsCachedFrame(frame) then
					numFree, numTotal = BagnonDB.GetFreeSlots(frame.player, bagID)
					if numTotal > 0 then
						if numBagID == 0 then
							bagName = BACKPACK_TOOLTIP or "Backpack"
						elseif numBagID == -1 then
							bagName = "Bank"
						else
							local _, link = BagnonDB.GetBagData(frame.player, bagID)
							bagName = link or format("Bag %d", numBagID)
						end
					end
				else
					numTotal = GetContainerNumSlots(bagID)
					if numTotal and numTotal > 0 then
						numFree = FreeSlotsOf(bagID, numTotal)
						if bagID == 0 then
							bagName = BACKPACK_TOOLTIP or "Backpack"
						elseif bagID == -1 then
							bagName = "Bank"
						else
							local invID = ContainerIDToInventoryID(bagID)
							local link = GetInventoryItemLink("player", invID)
							bagName = link or format("Bag %d", bagID <= 4 and bagID or (bagID - 4))
						end
					end
				end

				if bagName and numTotal and numTotal > 0 then
					local color = (numFree == 0 and "|cffff2020") or (numFree <= 2 and "|cffffff60") or "|cff20ff20"
					GameTooltip:AddDoubleLine(bagName, format("%s%d / %d|r", color, numFree, numTotal), 1, 1, 1)
				end
			end
		end
	end
	GameTooltip:Show()
end

function BagnonFrameFreeSlots_OnLeave()
	GameTooltip:Hide()
end
