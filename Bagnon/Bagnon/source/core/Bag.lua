--[[
	Bag.lua
		Functions used by Bagnon Bags
		Author: Tuller, McPewPew, Fostercare5988
		Built for ClassicAPI
--]]

if not Bagnon_EngineReady then
	return
end

--[[ Bag Frame Functions ]]--

local function GetBagSlot(bagFrame, index)
	if not bagFrame then return nil end
	local bags = bagFrame.bagSlots
	if not bags then
		bags = {}
		bagFrame.bagSlots = bags
	end
	local bag = bags[index]
	if not bag then
		bag = _G[bagFrame:GetName() .. index]
		if bag then
			bags[index] = bag
		end
	end
	return bag
end

local function ForAllBagSlots(bagFrame, action, arg1)
	if not bagFrame then return end
	for i = 1, 10 do
		local bag = GetBagSlot(bagFrame, i)
		if bag then
			action(bag, arg1)
		end
	end
end

--this function is used when updating the frame's size based on a bag being replaced/removed/added, so we don't care about the keyring
local function UpdateFrameSize(bagFrame)
	local size = 0
	for i = 1, 10 do
		local bag = GetBagSlot(bagFrame, i)
		if bag and GetInventoryItemTexture("player", ContainerIDToInventoryID(bag:GetID())) then
			size = size + GetContainerNumSlots(bag:GetID())
		end
	end
	local change = (size or 0) - (bagFrame.size or 0)

	--only generate the frame again if the size of the frame changed
	if change ~= 0 then
		bagFrame.size = size
		-- The main bag-event owner may already have rebound this same resize.
		BagnonFrame_RefreshSize(bagFrame:GetParent())
	end
end

-- The bag bar owns its size, bag icons and lock state. Refresh each once at
-- the native batch boundary, with a next-tick fallback for bank/lock events.
local function FlushBagBar(frame)
    if frame.bagRefreshTimer then frame.bagRefreshTimer:Cancel(); frame.bagRefreshTimer=nil end
    local dirty, all, size, locks = frame.dirtyBagSlots, frame.refreshAllBags, frame.refreshBagSize, frame.refreshBagLocks
    frame.dirtyBagSlots, frame.refreshAllBags, frame.refreshBagSize, frame.refreshBagLocks = nil, nil, nil, nil
    if not frame:IsVisible() or Bagnon_IsCachedFrame(frame:GetParent()) then return end
    if all then
        ForAllBagSlots(frame,BagnonBag_Update)
    elseif dirty then
        for index in pairs(dirty) do
            local bag=GetBagSlot(frame,index)
            if bag then BagnonBag_Update(bag) end
        end
    end
    if size then UpdateFrameSize(frame) end
    if locks and not all then
        for index=1,10 do
            if not (dirty and dirty[index]) then
                local bag=GetBagSlot(frame,index)
                if bag then BagnonBag_UpdateLock(bag) end
            end
        end
    end
end

local function QueueBagBar(frame)
    if frame.bagRefreshTimer then return end
    local timer
    timer=C_Timer.NewTimer(0,function()
        if frame.bagRefreshTimer==timer then FlushBagBar(frame) end
    end)
    frame.bagRefreshTimer=timer
end

function BagnonBagFrame_OnEvent(f, ev, a1)
	if not f:IsVisible() or Bagnon_IsCachedFrame(f:GetParent()) then return end

    if ev == "BAG_UPDATE_DELAYED" then
        FlushBagBar(f)
    elseif ev == "BAG_UPDATE" or ev == "PLAYERBANKSLOTS_CHANGED" or ev == "PLAYERBANKBAGSLOTS_CHANGED" then
        if not a1 or f:GetParent() == Banknon then
            f.refreshAllBags=true
        elseif type(a1)=="number" and a1>0 then
            f.dirtyBagSlots=f.dirtyBagSlots or {}
            f.dirtyBagSlots[a1]=true
        end
        f.refreshBagSize=true
        QueueBagBar(f)
    elseif ev == "ITEM_LOCK_CHANGED" then
        f.refreshBagLocks=true
        QueueBagBar(f)
	elseif ev == "CURSOR_UPDATE" then
		ForAllBagSlots(f, BagnonBag_UpdateCursor)
	end
end

function BagnonBagFrame_OnLoad(f)
	f:RegisterEvent("BAG_UPDATE")
	f:RegisterEvent("BAG_UPDATE_DELAYED")
	f:RegisterEvent("ITEM_LOCK_CHANGED")
	f:RegisterEvent("CURSOR_UPDATE")

	f:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
	f:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
end

--[[ Individual Bag Slot Code ]]--

--[[ Sort Exclusion: ClassicAPI can leave the backpack out of the native sort ]]--

local function SortIgnored(bagID)
	return bagID == 0 and C_Container.GetBackpackAutosortDisabled()
end

-- Flip the setting of the backpack. <bag> is its button, to refresh the badge.
function Bagnon_ToggleSortIgnore(bag)
	local ignore = not C_Container.GetBackpackAutosortDisabled()
	C_Container.SetBackpackAutosortDisabled(ignore)
	PlaySound("igMainMenuOption")
	BagnonMsg(format(ignore and BAGNON_AUTOSORT_IGNORE_ENABLED or BAGNON_AUTOSORT_IGNORE_DISABLED, BACKPACK_TOOLTIP))
	BagnonBag_UpdateSortIgnore(bag)
end

function BagnonBag_UpdateSortIgnore(bag)
	local badge = bag.sortIgnoreBadge
	if SortIgnored(bag:GetID()) then
		if not badge then
			badge = bag:CreateTexture(bag:GetName() .. "SortIgnoreBadge", "OVERLAY")
			badge:SetWidth(16)
			badge:SetHeight(16)
			badge:SetPoint("TOPRIGHT", bag, "TOPRIGHT", 2, 2)
			badge:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
			bag.sortIgnoreBadge = badge
		end
		badge:Show()
	elseif badge then
		badge:Hide()
	end
end

function BagnonBag_Update(bag)
	if not bag then return end

	local invID = ContainerIDToInventoryID(bag:GetID())

	local textureName = GetInventoryItemTexture("player", invID)
	if textureName then
		SetItemButtonTexture(bag, textureName)
		BagnonBag_SetCount(bag, GetInventoryItemCount("player", invID))

		if not IsInventoryItemLocked(invID) then
			SetItemButtonTextureVertexColor(bag, 1.0, 1.0, 1.0)
			SetItemButtonNormalTextureVertexColor(bag, 1.0, 1.0, 1.0)
		end
		bag.hasItem = 1
	else
		SetItemButtonTexture(bag, nil)
		BagnonBag_SetCount(bag, 0)
		SetItemButtonTextureVertexColor(bag, 1, 1, 1)
		SetItemButtonNormalTextureVertexColor(bag, 1, 1, 1)
		bag.hasItem = nil
	end
	if GameTooltip:IsOwned(bag) then
		if textureName then
			BagnonBag_OnEnter(bag)
		else
			GameTooltip:Hide()
			ResetCursor()
		end
	end
	BagnonBag_UpdateLock(bag)
	BagnonBag_UpdateSortIgnore(bag)
end

function BagnonBag_UpdateLock(bag)
	if IsInventoryItemLocked(ContainerIDToInventoryID(bag:GetID())) then
		SetItemButtonDesaturated(bag, 1, 0.5, 0.5, 0.5)
	else
		SetItemButtonDesaturated(bag, nil)
	end
end

function BagnonBag_UpdateCursor(bag)
	if CursorCanGoInSlot(ContainerIDToInventoryID(bag:GetID())) then
		bag:LockHighlight()
	else
		bag:UnlockHighlight()
	end
end


--[[
	Update the texture and count of the bag
		Used mainly for cached bags
--]]
function BagnonBag_UpdateTexture(frame, bagID)
	if not frame then return end
	local bagFrame = _G[frame:GetName() .. "Bags"]
	local bag = GetBagSlot(bagFrame, bagID)
	if not bag or bag:GetID() <= 0 then return end

	if Bagnon_IsCachedBag(frame.player, bagID) then
		local _, link, count = BagnonDB.GetBagData(frame.player, bagID)
		if link then
			local _, _, _, _, _, _, _, _, texture = GetItemInfo(link)
			SetItemButtonTexture(bag, texture)
		else
			SetItemButtonTexture(bag, nil)
		end
		if count then
			BagnonBag_SetCount(bag, count)
		end
	else
		local texture = GetInventoryItemTexture("player", ContainerIDToInventoryID(bagID))
		if texture then
			SetItemButtonTexture(bag, texture)
		else
			SetItemButtonTexture(bag, nil)
		end
		BagnonBag_SetCount(bag, GetInventoryItemCount("player", ContainerIDToInventoryID(bagID)))
	end
end

function BagnonBag_SetCount(button, count)
	if not button then return end
	if not count then count = 0 end

	button.count = count
	local countText = button.countText or _G[button:GetName() .. "Count"]
	if not button.countText then
		button.countText = countText
	end

	if count > 1 or (button.isBag and count > 0) then
		if countText then
			if count > 9999 then
				countText:SetFont(NumberFontNormal:GetFont(), 10, "OUTLINE")
			elseif count > 999 then
				countText:SetFont(NumberFontNormal:GetFont(), 11, "OUTLINE")
			else
				countText:SetFont(NumberFontNormal:GetFont(), 12, "OUTLINE")
			end
			countText:SetText(count)
			countText:Show()
		end
	else
		if countText then
			countText:Hide()
		end
	end
end

--[[ OnX Functions ]]--

function BagnonBag_OnLoad(b)
	b:RegisterForDrag("LeftButton")
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
end

function BagnonBag_OnShow(b)
	BagnonBag_UpdateTexture(b:GetParent():GetParent(), b:GetID())
	BagnonBag_UpdateSortIgnore(b)
end

function BagnonBag_OnClick(b, mouseButton)
	local frame = b:GetParent():GetParent()
	local bagID = b:GetID()
	if Bagnon_IsCachedBag(frame.player, bagID) then return end

	-- Alt-click or right-click (with nothing on the cursor) on the backpack leaves it out of the sort
	if (IsAltKeyDown() or (mouseButton == "RightButton" and not CursorHasItem())) and bagID == 0 then
		Bagnon_ToggleSortIgnore(b)
		if GameTooltip:IsOwned(b) then
			BagnonBag_OnEnter(b)
		end
		return
	end

	if not IsShiftKeyDown() then
		--damn you blizzard for making the keyring specific code!
		if bagID == KEYRING_CONTAINER then
			PutKeyInKeyRing()
		elseif bagID == 0 then
			PutItemInBackpack()
		else
			PutItemInBag(ContainerIDToInventoryID(bagID))
		end
	else
		BagnonFrame_ToggleBag(frame, bagID)
	end
end

function BagnonBag_OnDrag(b)
	if Bagnon_IsCachedBag(b:GetParent():GetParent().player, b:GetID()) then return end

	PickupBagFromSlot(ContainerIDToInventoryID(b:GetID()))
	PlaySound("BAGMENUBUTTONPRESS")
end

--tooltip functions
function BagnonBag_OnEnter(b)
	local frame = b:GetParent():GetParent()
	local bagID = b:GetID()
	local cached = Bagnon_IsCachedBag(frame.player, bagID)

	BagnonFrame_HighlightSlots(frame, bagID)

	if b:GetLeft() and (b:GetLeft() < (UIParent:GetRight() / 2)) then
		GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
	else
		GameTooltip:SetOwner(b, "ANCHOR_LEFT")
	end

	--mainmenubag specific code
	if bagID == 0 then
		GameTooltip:SetText(TEXT(BACKPACK_TOOLTIP), 1, 1, 1)
	--keyring specific code...again
	elseif bagID == KEYRING_CONTAINER then
		GameTooltip:SetText(KEYRING, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	--cached bags
	elseif cached then
		local _, link = BagnonDB.GetBagData(frame.player, bagID)

		if link then
			GameTooltip:SetHyperlink(link)
			GameTooltip:Show()
		else
			GameTooltip:SetText(TEXT(EQUIP_CONTAINER), 1, 1, 1)
		end
	elseif not GameTooltip:SetInventoryItem("player", ContainerIDToInventoryID(bagID)) then
		GameTooltip:SetText(TEXT(EQUIP_CONTAINER), 1, 1, 1)
	end

	if SortIgnored(bagID) then
		GameTooltip:AddLine("|cffff6060" .. BAGNON_AUTOSORT_IGNORED .. "|r")
	end
	if bagID == 0 then
		GameTooltip:AddLine(BAGNON_AUTOSORT_TOGGLE_IGNORE, 0.6, 0.8, 1)
	end

	--add the shift click to hide/show tooltip
	if not cached then
		if Bagnon_FrameHasBag(frame:GetName(), bagID) then
			GameTooltip:AddLine(BAGNON_BAGS_HIDE)
		else
			GameTooltip:AddLine(BAGNON_BAGS_SHOW)
		end
	end
	GameTooltip:Show()
end

function BagnonBag_OnLeave(b)
	BagnonFrame_UnhighlightAll(b:GetParent():GetParent())
	GameTooltip:Hide()
end
