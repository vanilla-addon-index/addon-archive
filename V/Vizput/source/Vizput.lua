local TBP = {}
TBP.frame = CreateFrame("Frame", "VizputFrame")
TBP.stateFrame = CreateFrame("Frame", "VizputStateFrame")

local READY = "READY"
local SPLITTING = "SPLITTING"
local COMBINING = "COMBINING"
local SPLIT_COMBINING = "SPLIT_COMBINING"
local AUCTIONING = "AUCTIONING"

TBP.job = nil
TBP.processing = false
TBP.basePickupContainerItem = nil
TBP.originalPickupContainerItem = nil
TBP.originalSplitContainerItem = nil
TBP.originalAuctionFrameTab_OnClick = nil
TBP.selectedDuration = 480
TBP.tabIndex = nil
TBP.cursorItem = nil
TBP.cursorItemData = nil

local function tbpPrint(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Vizput says:|r "..msg)
end

local function trim(text)
	if not text then
		return ""
	end
	return string.gsub(string.gsub(text, "^%s+", ""), "%s+$", "")
end

local function getItemSignatureFromLink(link)
	if not link then
		return nil
	end
	local _, _, signature = string.find(link, "|Hitem:([^|]+)|h")
	return signature
end

local function getItemIdFromLink(link)
	if not link then
		return nil
	end
	local _, _, itemId = string.find(link, "|Hitem:(%-?%d+):")
	return tonumber(itemId)
end

local function getContainerItemSignature(bag, slot)
	return getItemSignatureFromLink(GetContainerItemLink(bag, slot))
end

local function getContainerItemName(bag, slot)
	local link = GetContainerItemLink(bag, slot)
	if link then
		return GetItemInfo(link)
	end
end

local function getItemNameFallback(link)
	if not link then
		return "Selected item"
	end

	local _, _, itemName = string.find(link, "%[(.+)%]")
	if itemName and itemName ~= "" then
		return itemName
	end

	return "Selected item"
end

local function formatMoney(copper)
	if not copper then
		return "?"
	end

	local gold = math.floor(copper / 10000)
	local silver = math.floor(math.mod(copper, 10000) / 100)
	local copperOnly = math.mod(copper, 100)
	return string.format("%dg %ds %dc", gold, silver, copperOnly)
end

local function getItemQualityColorFromLink(link)
	if not link then
		return nil, nil, nil
	end

	local _, _, colorCode = string.find(link, "|c(%x%x%x%x%x%x%x%x)|Hitem:")
	if colorCode then
		local r = tonumber(string.sub(colorCode, 3, 4), 16)
		local g = tonumber(string.sub(colorCode, 5, 6), 16)
		local b = tonumber(string.sub(colorCode, 7, 8), 16)
		if r and g and b then
			return r / 255, g / 255, b / 255
		end
	end

	local _, _, _, quality = GetItemInfo(link)
	if quality == nil then
		return nil, nil, nil
	end

	if GetItemQualityColor then
		local _, r, g, b = GetItemQualityColor(quality)
		if r and g and b then
			return r, g, b
		end
	end

	if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
		local color = ITEM_QUALITY_COLORS[quality]
		return color.r, color.g, color.b
	end

	return nil, nil, nil
end

local function setStatus(text)
	if VizputPanelStatus then
		VizputPanelStatus:SetText(text or "")
	end
end

local function updateCapturedSummary()
	if not VizputPanelItemName then
		return
	end

	if TBP.capturedItem then
		local total = TBP.GetItemQuantityBySignature(TBP.capturedItem.signature)
		local liveLink = TBP.capturedItem.link
		if TBP.capturedItem.bag and TBP.capturedItem.slot then
			liveLink = GetContainerItemLink(TBP.capturedItem.bag, TBP.capturedItem.slot) or liveLink
		end
		VizputPanelItemName:SetText(TBP.capturedItem.name or "(unknown item)")
		local r, g, b = getItemQualityColorFromLink(liveLink)
		if not r or not g or not b then
			r, g, b = NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b
		end
		VizputPanelItemName:SetTextColor(r, g, b)
		VizputPanelItemMeta:SetText("Available in bags: "..total)
		if VizputPanelItemButtonIcon then
			VizputPanelItemButtonIcon:SetTexture(TBP.capturedItem.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
		end
		if VizputPanelItemButtonCount then
			local countText = ""
			if TBP.capturedItem.count and TBP.capturedItem.count > 1 then
				countText = tostring(TBP.capturedItem.count)
			end
			VizputPanelItemButtonCount:SetText(countText)
		end
	else
		VizputPanelItemName:SetText("No item captured")
		VizputPanelItemName:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		VizputPanelItemMeta:SetText("Drag an item onto the slot.")
		if VizputPanelItemButtonIcon then
			VizputPanelItemButtonIcon:SetTexture("Interface\\Buttons\\UI-EmptySlot")
		end
		if VizputPanelItemButtonCount then
			VizputPanelItemButtonCount:SetText("")
		end
	end

	TBP.UpdateTotalItems()
end

local function createBackdrop(frame)
	if not frame then
		return
	end
	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 }
	})
	frame:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
	frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
end

local function setButtonEnabled(button, enabled)
	if not button then
		return
	end
	if enabled then
		button:Enable()
	else
		button:Disable()
	end
end

local function setAuctionFrameBrowseTextures()
	AuctionFrameTopLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Browse-TopLeft")
	AuctionFrameTop:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Browse-Top")
	AuctionFrameTopRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Browse-TopRight")
	AuctionFrameBotLeft:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Browse-BotLeft")
	AuctionFrameBot:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Browse-Bot")
	AuctionFrameBotRight:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-Browse-BotRight")
end

function TBP.FindAuctionItem()
	local auctionName, _, auctionCount = GetAuctionSellItemInfo()
	if not auctionName or not auctionCount then
		return nil
	end

	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			local _, itemCount, itemLocked = GetContainerItemInfo(bag, slot)
			if itemLocked and itemCount == auctionCount and getContainerItemName(bag, slot) == auctionName then
				return bag, slot
			end
		end
	end
end

function TBP.ClearAuctionSellSlot()
	local bag, slot = TBP.FindAuctionItem()
	if bag and slot then
		ClickAuctionSellItemButton()
		TBP.RealPickupContainerItem(bag, slot)
	end
end

function TBP.FindEmptySlot()
	for bag = 0, 4 do
		for slot = GetContainerNumSlots(bag), 1, -1 do
			if not GetContainerItemInfo(bag, slot) then
				return { bag = bag, slot = slot }
			end
		end
	end
	return nil
end

function TBP.FindStackBySignature(signature, startBag, startSlot)
	startBag = startBag or 0
	startSlot = startSlot or 1

	for bag = startBag, 4 do
		local firstSlot = startSlot
		if firstSlot < 1 then
			firstSlot = 1
		end
		for slot = firstSlot, GetContainerNumSlots(bag) do
			if getContainerItemSignature(bag, slot) == signature then
				return { bag = bag, slot = slot }
			end
		end
		startSlot = 1
	end
	return nil
end

function TBP.GetItemQuantityBySignature(signature)
	local quantity = 0
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			if getContainerItemSignature(bag, slot) == signature then
				local _, count = GetContainerItemInfo(bag, slot)
				quantity = quantity + (count or 0)
			end
		end
	end
	return quantity
end

function TBP.RealPickupContainerItem(bag, slot)
	if TBP.basePickupContainerItem then
		return TBP.basePickupContainerItem(bag, slot)
	end
	return PickupContainerItem(bag, slot)
end

function TBP.RealSplitContainerItem(bag, slot, count)
	if TBP.originalSplitContainerItem then
		return TBP.originalSplitContainerItem(bag, slot, count)
	end
	return SplitContainerItem(bag, slot, count)
end

function TBP.GlobalPickupContainerItem(bag, slot)
	local link = GetContainerItemLink(bag, slot)
	local texture, count = GetContainerItemInfo(bag, slot)
	local itemLink = link
	local name, _, _, quality = GetItemInfo(itemLink or "")

	TBP.RealPickupContainerItem(bag, slot)

	if CursorHasItem() and itemLink then
		TBP.cursorItem = { bag = bag, slot = slot }
		TBP.cursorItemData = {
			bag = bag,
			slot = slot,
			link = itemLink,
			count = count or 1,
			name = name or getItemNameFallback(itemLink),
			quality = quality,
			texture = texture,
			signature = getItemSignatureFromLink(itemLink)
		}
	else
		TBP.cursorItem = nil
		TBP.cursorItemData = nil
	end
end

function TBP.SetCapturedItem(itemData)
	if not itemData or not itemData.signature then
		return
	end

	TBP.capturedItem = {
		bag = itemData.bag,
		slot = itemData.slot,
		link = itemData.link,
		signature = itemData.signature,
		name = itemData.name or getItemNameFallback(itemData.link),
		quality = itemData.quality,
		texture = itemData.texture,
		count = itemData.count
	}
	updateCapturedSummary()
	setStatus("Item captured.")
end

function TBP.CaptureBagItem(bag, slot)
	local link = GetContainerItemLink(bag, slot)
	if not link then
		tbpPrint("That item is not ready yet. Give it a moment, then try again.")
		return
	end

	local texture, count = GetContainerItemInfo(bag, slot)
	local name, _, _, quality = GetItemInfo(link)
	TBP.SetCapturedItem({
		bag = bag,
		slot = slot,
		link = link,
		signature = getItemSignatureFromLink(link),
		name = name or getItemNameFallback(link),
		quality = quality,
		texture = texture,
		count = count or 1
	})
end

function TBP.CaptureCursorItem()
	if not CursorHasItem() or not TBP.cursorItemData then
		tbpPrint("Pick up an item from your bags, then drop it on Vizput's slot.")
		return
	end

	TBP.SetCapturedItem(TBP.cursorItemData)
	TBP.GlobalPickupContainerItem(TBP.cursorItemData.bag, TBP.cursorItemData.slot)
end

function TBP.ClearCapturedItem()
	TBP.capturedItem = nil
	updateCapturedSummary()
	setStatus("Idle")
end

function TBP.BlockedPickupContainerItem()
end

function TBP.BlockedSplitContainerItem()
end

function TBP.SetState(newState)
	local job = TBP.job
	if not job or job.state == newState then
		return
	end

	if job.state == SPLITTING or job.state == COMBINING or job.state == SPLIT_COMBINING then
		TBP.stateFrame:UnregisterEvent("ITEM_LOCK_CHANGED")
	elseif job.state == AUCTIONING then
		TBP.stateFrame:UnregisterEvent("BAG_UPDATE")
	end

	job.state = newState
	job.lockEvents = 0

	if newState == SPLITTING or newState == COMBINING or newState == SPLIT_COMBINING then
		TBP.stateFrame:RegisterEvent("ITEM_LOCK_CHANGED")
	elseif newState == AUCTIONING then
		TBP.stateFrame:RegisterEvent("BAG_UPDATE")
	end
end

function TBP.BeginProcessing()
	if TBP.processing or not TBP.job then
		return false
	end
	if not AuctionFrame or not AuctionFrame:IsVisible() then
		return false
	end

	TBP.processing = true
	TBP.originalPickupContainerItem = PickupContainerItem
	TBP.originalSplitContainerItem = SplitContainerItem
	PickupContainerItem = TBP.BlockedPickupContainerItem
	SplitContainerItem = TBP.BlockedSplitContainerItem
	return true
end

function TBP.EndProcessing()
	if not TBP.processing then
		return
	end

	if TBP.originalPickupContainerItem then
		PickupContainerItem = TBP.originalPickupContainerItem
		TBP.originalPickupContainerItem = nil
	end
	if TBP.originalSplitContainerItem then
		SplitContainerItem = TBP.originalSplitContainerItem
		TBP.originalSplitContainerItem = nil
	end

	TBP.stateFrame:UnregisterEvent("ITEM_LOCK_CHANGED")
	TBP.stateFrame:UnregisterEvent("BAG_UPDATE")
	TBP.processing = false
end

function TBP.FinishJob(message)
	local job = TBP.job
	if job then
		if message then
			tbpPrint(message)
		else
			tbpPrint(string.format("Posted %d/%d auctions of %s in stacks of %d. Clean work.", job.postedCount, job.stackCount, job.name, job.stackSize))
		end
	end
	TBP.job = nil
	TBP.EndProcessing()
	setStatus("Idle")
	setButtonEnabled(VizputPanelStartButton, true)
	setButtonEnabled(VizputPanelStopButton, false)
	updateCapturedSummary()
end

function TBP.FailJob(message)
	TBP.FinishJob(message or "Batch posting stopped.")
end

function TBP.Run()
	local job = TBP.job
	if not job or job.state ~= READY then
		return
	end

	local stack1
	if job.stackHint and getContainerItemSignature(job.stackHint.bag, job.stackHint.slot) == job.signature then
		stack1 = job.stackHint
	else
		stack1 = TBP.FindStackBySignature(job.signature)
		if stack1 then
			local candidate = { bag = stack1.bag, slot = stack1.slot }
			local _, candidateSize = GetContainerItemInfo(candidate.bag, candidate.slot)
			while candidate and candidateSize ~= job.stackSize do
				candidate = TBP.FindStackBySignature(job.signature, candidate.bag, candidate.slot + 1)
				if candidate then
					_, candidateSize = GetContainerItemInfo(candidate.bag, candidate.slot)
				end
			end
			if candidate then
				stack1 = candidate
			end
		end
	end

	if not stack1 then
		TBP.FailJob("No more matching items were found.")
		return
	end

	local _, stack1Size = GetContainerItemInfo(stack1.bag, stack1.slot)
	if stack1Size == job.stackSize then
		job.stackHint = stack1
		TBP.SetState(AUCTIONING)
		TBP.RealPickupContainerItem(stack1.bag, stack1.slot)
		ClickAuctionSellItemButton()
		StartAuction(job.bid, job.buyout, job.duration)
		setStatus(string.format("Posting %d/%d...", job.postedCount + 1, job.stackCount))
	elseif stack1Size < job.stackSize then
		local stack2 = TBP.FindStackBySignature(job.signature, stack1.bag, stack1.slot + 1)
		if not stack2 then
			TBP.FailJob("Not enough items left to build the next stack.")
			return
		end

		local _, stack2Size = GetContainerItemInfo(stack2.bag, stack2.slot)
		if stack1Size + stack2Size <= job.stackSize then
			TBP.SetState(COMBINING)
			TBP.RealPickupContainerItem(stack2.bag, stack2.slot)
			TBP.RealPickupContainerItem(stack1.bag, stack1.slot)
			job.stackHint = stack1
			setStatus("Combining partial stacks...")
		else
			TBP.SetState(SPLIT_COMBINING)
			TBP.RealSplitContainerItem(stack2.bag, stack2.slot, job.stackSize - stack1Size)
			TBP.RealPickupContainerItem(stack1.bag, stack1.slot)
			job.stackHint = stack1
			setStatus("Splitting and combining stacks...")
		end
	else
		local emptySlot = TBP.FindEmptySlot()
		if not emptySlot then
			TBP.FailJob("No empty bag slot is available for stack splitting.")
			return
		end

		TBP.SetState(SPLITTING)
		TBP.RealSplitContainerItem(stack1.bag, stack1.slot, job.stackSize)
		TBP.RealPickupContainerItem(emptySlot.bag, emptySlot.slot)
		job.stackHint = emptySlot
		setStatus("Splitting stack...")
	end
end

function TBP.OnStateEvent(event)
	local job = TBP.job
	if not job then
		return
	end

	if event == "ITEM_LOCK_CHANGED" then
		job.lockEvents = job.lockEvents + 1
		if job.state == SPLITTING and job.lockEvents >= 4 then
			TBP.SetState(READY)
			TBP.Run()
		elseif (job.state == COMBINING or job.state == SPLIT_COMBINING) and job.lockEvents >= 3 then
			TBP.SetState(READY)
			TBP.Run()
		end
	elseif event == "BAG_UPDATE" then
		if job.state == AUCTIONING and job.stackHint and not GetContainerItemInfo(job.stackHint.bag, job.stackHint.slot) then
			job.postedCount = job.postedCount + 1
			if job.postedCount >= job.stackCount then
				TBP.FinishJob()
			else
				TBP.SetState(READY)
				TBP.Run()
			end
		end
	end
end

function TBP.GetSelectedDuration()
	return TBP.selectedDuration or 480
end

function TBP.StartBatchPost()
	if TBP.job then
		tbpPrint("A batch is already moving.")
		return
	end

	if not TBP.capturedItem or not TBP.capturedItem.signature then
		tbpPrint("Capture an item first.")
		return
	end

	local stackSize = tonumber(VizputPanelStackSize:GetText())
	local stackCount = tonumber(VizputPanelStackCount:GetText())
	local bid = TBP.GetPriceFromFields("VizputPanelBid")
	local buyout = TBP.GetPriceFromFields("VizputPanelBuyout")
	local duration = TBP.GetSelectedDuration()

	if not stackSize or stackSize < 1 then
		tbpPrint("Enter a valid stack size.")
		return
	end
	if not stackCount or stackCount < 1 then
		tbpPrint("Enter a valid auction count.")
		return
	end
	if not bid or bid < 1 then
		tbpPrint("Enter a valid starting bid.")
		return
	end
	if not buyout or buyout < bid then
		tbpPrint("Enter a valid buyout that is at least the bid.")
		return
	end

	local quantity = TBP.GetItemQuantityBySignature(TBP.capturedItem.signature)
	if quantity < stackSize * stackCount then
		tbpPrint(string.format("Not enough stock. Need %d, found %d.", stackSize * stackCount, quantity))
		return
	end

	if not AuctionFrame or not AuctionFrame:IsVisible() then
		tbpPrint("Open the auction house first.")
		return
	end

	TBP.ClearAuctionSellSlot()
	TBP.job = {
		name = TBP.capturedItem.name,
		signature = TBP.capturedItem.signature,
		stackSize = stackSize,
		stackCount = stackCount,
		bid = bid,
		buyout = buyout,
		duration = duration,
		postedCount = 0,
		lockEvents = 0,
		state = READY,
		stackHint = nil
	}

	if not TBP.BeginProcessing() then
		TBP.job = nil
		tbpPrint("Could not start the posting run.")
		return
	end

	setButtonEnabled(VizputPanelStartButton, false)
	setButtonEnabled(VizputPanelStopButton, true)
	setStatus(string.format("Starting: %s x%d for %d auctions at %s / %s.", TBP.capturedItem.name or "Selected item", stackSize, stackCount, formatMoney(bid), formatMoney(buyout)))
	TBP.Run()
end

function TBP.StopBatchPost()
	if not TBP.job then
		return
	end
	TBP.FailJob("Batch posting stopped. We can resume when you're ready.")
end

function TBP.CreateDurationButton(name, parent, label, anchorTo, x, y, duration)
	local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
	button:SetWidth(42)
	button:SetHeight(20)
	button:SetPoint("TOPLEFT", anchorTo, "TOPLEFT", x, y)
	button:SetText(label)
	button.durationValue = duration
	return button
end

function TBP.MakeNumericBox(name, parent, width, height, point, relativeTo, relativePoint, x, y, defaultValue)
	local box = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
	box:SetAutoFocus(false)
	box:SetWidth(width)
	box:SetHeight(height)
	box:SetPoint(point, relativeTo, relativePoint, x, y)
	box:SetTextInsets(6, 6, 0, 0)
	box:SetText(defaultValue or "")
	box:SetScript("OnTextChanged", function()
		local current = this:GetText() or ""
		local cleaned = string.gsub(current, "[^0-9]", "")
		if cleaned ~= current then
			this:SetText(cleaned)
		end
		if this.onValueChanged then
			this:onValueChanged()
		end
	end)
	return box
end

function TBP.UpdateTotalItems()
	if not VizputPanelTotalItems or not VizputPanelStackSize or not VizputPanelStackCount then
		return
	end

	local stackSize = tonumber(VizputPanelStackSize:GetText()) or 0
	local stackCount = tonumber(VizputPanelStackCount:GetText()) or 0
	local totalItems = stackSize * stackCount
	local availableItems = 0

	if TBP.capturedItem and TBP.capturedItem.signature then
		availableItems = TBP.GetItemQuantityBySignature(TBP.capturedItem.signature)
	end

	VizputPanelTotalItems:SetText("Total Items: "..totalItems)
	if availableItems > 0 and totalItems > availableItems then
		VizputPanelTotalItems:SetTextColor(1, 0.1, 0.1)
	else
		VizputPanelTotalItems:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	end
end

function TBP.CreateCoinInput(name, parent, point, relativeTo, relativePoint, x, y, coinTexture)
	local box = TBP.MakeNumericBox(name, parent, 28, 20, point, relativeTo, relativePoint, x, y, "")
	local icon = parent:CreateTexture(nil, "ARTWORK")
	icon:SetWidth(14)
	icon:SetHeight(14)
	icon:SetPoint("LEFT", box, "RIGHT", 4, 0)
	icon:SetTexture(coinTexture)
	return box
end

function TBP.SetTabOrder(fields)
	local total = table.getn(fields)
	for index = 1, total do
		local field = fields[index]
		local nextField = fields[index + 1] or fields[1]
		local prevField = fields[index - 1] or fields[total]
		field:SetScript("OnTabPressed", function()
			this:ClearFocus()
			if IsShiftKeyDown() then
				prevField:SetFocus()
				prevField:HighlightText()
			else
				nextField:SetFocus()
				nextField:HighlightText()
			end
		end)
	end
end

function TBP.GetCoinBoxValue(box)
	if not box then
		return 0
	end
	local value = tonumber(box:GetText())
	if not value or value < 0 then
		return 0
	end
	return math.floor(value)
end

function TBP.GetPriceFromFields(prefix)
	local gold = TBP.GetCoinBoxValue(getglobal(prefix.."Gold"))
	local silver = TBP.GetCoinBoxValue(getglobal(prefix.."Silver"))
	local copper = TBP.GetCoinBoxValue(getglobal(prefix.."Copper"))
	return (gold * 10000) + (silver * 100) + copper
end

function TBP.BuildPanel()
	if VizputPanel or not AuctionFrame then
		return
	end

	local panel = CreateFrame("Frame", "VizputPanel", AuctionFrame)
	panel:SetWidth(626)
	panel:SetHeight(352)
	panel:SetPoint("TOPLEFT", AuctionFrame, "TOPLEFT", 0, 0)
	panel:Hide()

	local leftPane = CreateFrame("Frame", nil, panel)
	leftPane:SetWidth(174)
	leftPane:SetHeight(308)
	leftPane:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -101)
	createBackdrop(leftPane)

	local rightPane = CreateFrame("Frame", nil, panel)
	rightPane:SetWidth(346)
	rightPane:SetHeight(308)
	rightPane:SetPoint("TOPLEFT", panel, "TOPLEFT", 232, -101)
	createBackdrop(rightPane)

	local title = leftPane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", leftPane, "TOPLEFT", 10, -10)
	title:SetText("Vizput")

	local subtitle = leftPane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
	subtitle:SetText("Batch Posting")

	local itemSlot = CreateFrame("Button", "VizputPanelItemButton", leftPane)
	itemSlot:SetWidth(46)
	itemSlot:SetHeight(46)
	itemSlot:SetPoint("TOPLEFT", leftPane, "TOPLEFT", 14, -42)
	itemSlot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	itemSlot:RegisterForDrag("LeftButton")
	itemSlot:SetScript("OnReceiveDrag", TBP.CaptureCursorItem)
	itemSlot:SetScript("OnMouseUp", function()
		if arg1 == "RightButton" then
			TBP.ClearCapturedItem()
		elseif CursorHasItem() then
			TBP.CaptureCursorItem()
		end
	end)
	itemSlot:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		if TBP.capturedItem and TBP.capturedItem.bag and TBP.capturedItem.slot then
			GameTooltip:SetBagItem(TBP.capturedItem.bag, TBP.capturedItem.slot)
		else
			GameTooltip:AddLine("Drop Item Here")
			GameTooltip:AddLine("Drag an item from your bags onto this slot.", 1, 1, 1, 1)
			GameTooltip:AddLine("Right-click to clear.", 0.7, 0.7, 0.7, 1)
			GameTooltip:Show()
		end
	end)
	itemSlot:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	local itemIcon = itemSlot:CreateTexture("VizputPanelItemButtonIcon", "ARTWORK")
	itemIcon:SetTexture("Interface\\Buttons\\UI-EmptySlot")
	itemIcon:SetAllPoints(itemSlot)

	local itemCount = itemSlot:CreateFontString("VizputPanelItemButtonCount", "OVERLAY", "NumberFontNormal")
	itemCount:SetPoint("BOTTOMRIGHT", itemSlot, "BOTTOMRIGHT", -2, 2)
	itemCount:SetJustifyH("RIGHT")

	local itemName = leftPane:CreateFontString("VizputPanelItemName", "OVERLAY", "GameFontHighlight")
	itemName:SetPoint("TOPLEFT", itemSlot, "TOPRIGHT", 8, -2)
	itemName:SetWidth(92)
	itemName:SetJustifyH("LEFT")

	local itemMeta = leftPane:CreateFontString("VizputPanelItemMeta", "OVERLAY", "GameFontHighlightSmall")
	itemMeta:SetPoint("TOPLEFT", itemName, "BOTTOMLEFT", 0, -4)
	itemMeta:SetWidth(92)
	itemMeta:SetJustifyH("LEFT")

	local hint = leftPane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", leftPane, "TOPLEFT", 14, -106)
	hint:SetWidth(142)
	hint:SetJustifyH("LEFT")
	hint:SetText("Drop item here.")

	local clearButton = CreateFrame("Button", "VizputPanelClearButton", leftPane, "UIPanelButtonTemplate")
	clearButton:SetWidth(72)
	clearButton:SetHeight(22)
	clearButton:SetPoint("BOTTOMLEFT", leftPane, "BOTTOMLEFT", 14, 16)
	clearButton:SetText("Clear")
	clearButton:SetScript("OnClick", TBP.ClearCapturedItem)

	local priceTitle = rightPane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	priceTitle:SetPoint("TOPLEFT", rightPane, "TOPLEFT", 12, -12)
	priceTitle:SetText("Create Auctions")

	local priceHint = rightPane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	priceHint:SetPoint("TOPLEFT", priceTitle, "BOTTOMLEFT", 0, -4)
	priceHint:SetText("Choose quantity, price, and duration.")

	local stackSizeLabel = rightPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	stackSizeLabel:SetPoint("TOPLEFT", rightPane, "TOPLEFT", 12, -56)
	stackSizeLabel:SetText("Stack Size")

	local stackCountLabel = rightPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	stackCountLabel:SetPoint("TOPLEFT", rightPane, "TOPLEFT", 114, -56)
	stackCountLabel:SetText("Auctions")

	local bidLabel = rightPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	bidLabel:SetPoint("TOPLEFT", rightPane, "TOPLEFT", 12, -104)
	bidLabel:SetText("Bid")

	local buyoutLabel = rightPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	buyoutLabel:SetPoint("TOPLEFT", rightPane, "TOPLEFT", 12, -148)
	buyoutLabel:SetText("Buyout")

	local stackSize = TBP.MakeNumericBox("VizputPanelStackSize", rightPane, 62, 20, "TOPLEFT", rightPane, "TOPLEFT", 12, -72, "1")
	local stackCount = TBP.MakeNumericBox("VizputPanelStackCount", rightPane, 62, 20, "TOPLEFT", rightPane, "TOPLEFT", 114, -72, "1")
	local totalItems = rightPane:CreateFontString("VizputPanelTotalItems", "OVERLAY", "GameFontHighlightSmall")
	totalItems:SetPoint("TOPLEFT", rightPane, "TOPLEFT", 194, -74)
	totalItems:SetWidth(120)
	totalItems:SetJustifyH("LEFT")
	totalItems:SetText("Total Items: 1")
	stackSize.onValueChanged = TBP.UpdateTotalItems
	stackCount.onValueChanged = TBP.UpdateTotalItems
	local bidGold = TBP.CreateCoinInput("VizputPanelBidGold", rightPane, "TOPLEFT", rightPane, "TOPLEFT", 72, -100, "Interface\\Icons\\INV_Misc_Coin_01")
	local bidSilver = TBP.CreateCoinInput("VizputPanelBidSilver", rightPane, "TOPLEFT", rightPane, "TOPLEFT", 126, -100, "Interface\\Icons\\INV_Misc_Coin_03")
	local bidCopper = TBP.CreateCoinInput("VizputPanelBidCopper", rightPane, "TOPLEFT", rightPane, "TOPLEFT", 180, -100, "Interface\\Icons\\INV_Misc_Coin_05")
	local buyoutGold = TBP.CreateCoinInput("VizputPanelBuyoutGold", rightPane, "TOPLEFT", rightPane, "TOPLEFT", 72, -144, "Interface\\Icons\\INV_Misc_Coin_01")
	local buyoutSilver = TBP.CreateCoinInput("VizputPanelBuyoutSilver", rightPane, "TOPLEFT", rightPane, "TOPLEFT", 126, -144, "Interface\\Icons\\INV_Misc_Coin_03")
	local buyoutCopper = TBP.CreateCoinInput("VizputPanelBuyoutCopper", rightPane, "TOPLEFT", rightPane, "TOPLEFT", 180, -144, "Interface\\Icons\\INV_Misc_Coin_05")
	TBP.SetTabOrder({
		stackSize,
		stackCount,
		bidGold,
		bidSilver,
		bidCopper,
		buyoutGold,
		buyoutSilver,
		buyoutCopper
	})

	local priceFormat = rightPane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	priceFormat:SetPoint("TOPLEFT", rightPane, "TOPLEFT", 12, -180)
	priceFormat:SetWidth(320)
	priceFormat:SetJustifyH("LEFT")
	priceFormat:SetText("Prices are for the full stack.")

	local durationLabel = rightPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	durationLabel:SetPoint("TOPLEFT", rightPane, "TOPLEFT", 12, -198)
	durationLabel:SetText("Duration")

	local duration2 = TBP.CreateDurationButton("VizputPanelDuration2", rightPane, "2h", rightPane, 72, -194, 120)
	local duration8 = TBP.CreateDurationButton("VizputPanelDuration8", rightPane, "8h", rightPane, 120, -194, 480)
	local duration24 = TBP.CreateDurationButton("VizputPanelDuration24", rightPane, "24h", rightPane, 168, -194, 1440)

	local function setDuration(which)
		TBP.selectedDuration = which
		duration2:Enable()
		duration8:Enable()
		duration24:Enable()
		if which == 120 then
			duration2:Disable()
		elseif which == 480 then
			duration8:Disable()
		else
			duration24:Disable()
		end
	end

	duration2:SetScript("OnClick", function() setDuration(duration2.durationValue) end)
	duration8:SetScript("OnClick", function() setDuration(duration8.durationValue) end)
	duration24:SetScript("OnClick", function() setDuration(duration24.durationValue) end)
	setDuration(480)

	local startButton = CreateFrame("Button", "VizputPanelStartButton", rightPane, "UIPanelButtonTemplate")
	startButton:SetWidth(104)
	startButton:SetHeight(22)
	startButton:SetPoint("BOTTOMRIGHT", rightPane, "BOTTOMRIGHT", -108, 18)
	startButton:SetText("Batch Post")
	startButton:SetScript("OnClick", TBP.StartBatchPost)

	local stopButton = CreateFrame("Button", "VizputPanelStopButton", rightPane, "UIPanelButtonTemplate")
	stopButton:SetWidth(88)
	stopButton:SetHeight(22)
	stopButton:SetPoint("BOTTOMRIGHT", rightPane, "BOTTOMRIGHT", -12, 18)
	stopButton:SetText("Stop")
	stopButton:SetScript("OnClick", TBP.StopBatchPost)
	stopButton:Disable()

	local status = rightPane:CreateFontString("VizputPanelStatus", "OVERLAY", "GameFontHighlightSmall")
	status:SetPoint("BOTTOMLEFT", rightPane, "BOTTOMLEFT", 12, 22)
	status:SetWidth(170)
	status:SetJustifyH("LEFT")
	status:SetJustifyV("MIDDLE")
	status:SetText("Idle")

	updateCapturedSummary()
	TBP.UpdateTotalItems()
end

function TBP.HideOtherAuctionFrames()
	if AuctionFrameBrowse then
		AuctionFrameBrowse:Hide()
	end
	if AuctionFrameBid then
		AuctionFrameBid:Hide()
	end
	if AuctionFrameAuctions then
		AuctionFrameAuctions:Hide()
	end
end

function TBP.SelectTab()
	if not TBP.tabIndex or not VizputPanel then
		return
	end

	if TBP.originalAuctionFrameTab_OnClick then
		TBP.originalAuctionFrameTab_OnClick(3)
		PanelTemplates_SetTab(AuctionFrame, TBP.tabIndex)
	else
		PanelTemplates_SetTab(AuctionFrame, TBP.tabIndex)
	end
	TBP.HideOtherAuctionFrames()
	setAuctionFrameBrowseTextures()
	VizputPanel:Show()
	updateCapturedSummary()
end

function TBP.EnsureTab()
	if TBP.tabIndex or not AuctionFrame then
		return
	end

	local tabIndex = 1
	while getglobal("AuctionFrameTab"..tabIndex) do
		tabIndex = tabIndex + 1
	end

	local tabName = "AuctionFrameTab"..tabIndex
	local tab = CreateFrame("Button", tabName, AuctionFrame, "AuctionTabTemplate")
	tab:SetID(tabIndex)
	getglobal(tabName.."Text"):SetText("Vizput")
	tab:SetPoint("LEFT", getglobal("AuctionFrameTab"..(tabIndex - 1)), "RIGHT", -8, 0)
	tab:Show()

	PanelTemplates_SetNumTabs(AuctionFrame, tabIndex)
	if PanelTemplates_TabResize then
		PanelTemplates_TabResize(0, tab, nil, 36)
	end

	TBP.tabIndex = tabIndex

	if not TBP.originalAuctionFrameTab_OnClick then
		TBP.originalAuctionFrameTab_OnClick = AuctionFrameTab_OnClick
		AuctionFrameTab_OnClick = function(index)
			local targetIndex = index
			if not targetIndex and this then
				targetIndex = this:GetID()
			end

			if targetIndex == TBP.tabIndex then
				if VizputPanel then
					VizputPanel:Hide()
				end
				TBP.originalAuctionFrameTab_OnClick(3)
				PanelTemplates_SetTab(AuctionFrame, TBP.tabIndex)
				TBP.HideOtherAuctionFrames()
				setAuctionFrameBrowseTextures()
				VizputPanel:Show()
				updateCapturedSummary()
				return
			end

			if VizputPanel then
				VizputPanel:Hide()
			end

			return TBP.originalAuctionFrameTab_OnClick(index)
		end
	end
end

function TBP.OnEvent()
	if event == "ADDON_LOADED" and arg1 == "Vizput" then
		TBP.basePickupContainerItem = PickupContainerItem
		PickupContainerItem = TBP.GlobalPickupContainerItem
		SLASH_VIZPUT1 = "/vizput"
		SLASH_VIZPUT2 = "/vz"
		SlashCmdList["VIZPUT"] = function(msg)
			msg = string.lower(trim(msg or ""))
			if msg == "stop" then
				TBP.StopBatchPost()
			else
				tbpPrint("Open the auction house, drag an item from your bags onto Vizput's slot, then Batch Post. Use /vizput stop to cancel.")
			end
		end
	elseif event == "AUCTION_HOUSE_SHOW" then
		TBP.BuildPanel()
		TBP.EnsureTab()
		VizputPanel:Hide()
		updateCapturedSummary()
	elseif event == "AUCTION_HOUSE_CLOSED" then
		TBP.StopBatchPost()
		if VizputPanel then
			VizputPanel:Hide()
		end
	elseif event == "BAG_UPDATE" then
		updateCapturedSummary()
	end
end

TBP.frame:SetScript("OnEvent", TBP.OnEvent)
TBP.frame:RegisterEvent("ADDON_LOADED")
TBP.frame:RegisterEvent("AUCTION_HOUSE_SHOW")
TBP.frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
TBP.frame:RegisterEvent("BAG_UPDATE")

TBP.stateFrame:SetScript("OnEvent", function()
	TBP.OnStateEvent(event)
end)
