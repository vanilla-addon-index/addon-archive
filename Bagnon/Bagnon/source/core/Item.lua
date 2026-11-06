--[[
	Item.lua
		Functions used by the item slots in Bagnon
		Author: Tuller, McPewPew, Fostercare5988
		Built for ClassicAPI
--]]

if not Bagnon_EngineReady then
	return
end

-- Hide the enchant badge and stop its countdown.
local function HideEnchant(item)
	local overlay = item.enchantOverlay
	if overlay then
		overlay.sweep:Clear(); overlay.cdEnd = nil
		overlay:Hide()
	end
end

--[[ OnX Handlers: one shared function each; the client sets this and arg1 ]]--

local function OnClick() BagnonItem_OnClick(this, arg1) end
local function OnEnter() BagnonItem_OnEnter(this) end
local function OnLeave() BagnonItem_OnLeave(this) end
local function OnDrag() BagnonItem_OnClick(this, "LeftButton", 1) end
local function OnHide() BagnonItem_OnHide(this) end

local QUALITY_BORDER_BACKDROP = {
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 8,
	edgeSize = 16,
	insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

-- High-luminance, high-contrast palette for clear distinction (Green vs Blue vs Purple)
local ENHANCED_QUALITY_COLORS = {
	[2] = { r = 0.05, g = 1.00, b = 0.15 }, -- Vibrant Emerald Green
	[3] = { r = 0.00, g = 0.70, b = 1.00 }, -- Radiant Electric Sky Blue
	[4] = { r = 0.85, g = 0.20, b = 1.00 }, -- Vivid Neon Purple / Magenta
	[5] = { r = 1.00, g = 0.55, b = 0.00 }, -- Flaming Orange
	[6] = { r = 0.95, g = 0.85, b = 0.40 }, -- Radiant Gold
}

local function GetBorderQualityColor(quality)
	local color = ENHANCED_QUALITY_COLORS[quality]
	if color then
		return color.r, color.g, color.b
	end
	return GetItemQualityColor(quality)
end

function BagnonItem_Create(name, parent)
	--create the button
	local item = CreateFrame("Button", name, parent, "BagnonItemTemplate")
	item:SetAlpha(parent:GetParent():GetAlpha())

	-- Child widgets are looked up once, here
	item.cooldown = _G[name .. "Cooldown"]
	item.cooldown:EnableMouse(false)
	item.normalTexture = _G[name .. "NormalTexture"]

	-- Native modern rarity border frame
	local qBorder = CreateFrame("Frame", name .. "QualityBorder", item)
	qBorder:SetPoint("TOPLEFT", item, "TOPLEFT", -2, 2)
	qBorder:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 2, -2)
	qBorder:SetBackdrop(QUALITY_BORDER_BACKDROP)
	qBorder:EnableMouse(false)
	qBorder:Hide()
	item.qualityBorder = qBorder

	item:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	item:RegisterForDrag("LeftButton")

	item:SetScript("OnClick", OnClick)
	item:SetScript("OnEnter", OnEnter)
	item:SetScript("OnLeave", OnLeave)
	item:SetScript("OnDragStart", OnDrag)
	item:SetScript("OnReceiveDrag", OnDrag)
	item:SetScript("OnHide", OnHide)

	return item
end

function BagnonItem_OnClick(item, mouseButton, ignoreModifiers)
	if not item.isLink then
		ContainerFrameItemButton_OnClick(mouseButton, ignoreModifiers)
		return
	end

	--a saved item of another character: link it or dress it up
	if not item.hasItem or mouseButton ~= "LeftButton" then return end
	local bag = item:GetParent()
	if IsControlKeyDown() then
		DressUpItemLink((BagnonDB.GetItemData(bag:GetParent().player, bag:GetID(), item:GetID())))
	elseif IsShiftKeyDown() then
		ChatFrameEditBox:Insert(BagnonDB.GetItemHyperlink(bag:GetParent().player, bag:GetID(), item:GetID()))
	end
end

--[[
	Show tooltip on hover
--]]

function BagnonItem_OnEnter(item)
	local bag = item:GetParent()
	--link case
	if item.isLink then
		if item.hasItem then
			GameTooltip:SetOwner(item)
			local link, count = BagnonDB.GetItemData(bag:GetParent().player, bag:GetID(), item:GetID())
			GameTooltip:SetHyperlink(link, count)
			Bagnon_AnchorTooltip(item)
		end
	--normal bag case
	else
		if bag:GetID() == -1 then
			GameTooltip:SetOwner(item)
			GameTooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(item:GetID()))
		else
			ContainerFrameItemButton_OnEnter(item)
		end
		Bagnon_AnchorTooltip(item)
	end
end

function BagnonItem_OnLeave(item)
	item.updateTooltip = nil
	GameTooltip:Hide()
	ResetCursor()
end

function BagnonItem_OnHide(item)
	if item.hasStackSplit == 1 then
		StackSplitFrame:Hide()
	end
end

--[[
	Update Functions
--]]

-- Lock state of the icon. While searching, a slot that does not match is dimmed. A slot
-- waiting for its cooldown stays dimmed unless it is locked.
local INFO = {}
function BagnonItem_SetLocked(item, locked)
	local filtered
	if not item.isLink and Bagnon_Searching() then
		local info = C_Container.GetContainerItemInfo(item:GetParent():GetID(), item:GetID(), INFO)
		filtered = info and info.isFiltered
	end
	if filtered then
		SetItemButtonDesaturated(item, 1, 0.3, 0.3, 0.3)
	else
		SetItemButtonDesaturated(item, locked, 0.5, 0.5, 0.5)
		if item.cooldownWait and not locked then
			SetItemButtonTextureVertexColor(item, 0.4, 0.4, 0.4)
		end
	end
	item.qualityBorder:SetAlpha(filtered and 0.25 or 1)
end

-- Update the texture, lock status, and other information about an item
function BagnonItem_Update(item)
	local texture, itemCount, locked, readable, quality
	local bagID = item:GetParent():GetID()

	if Bagnon_IsCachedItem(item) then
		item.isLink = 1

		local player = item:GetParent():GetParent().player

		local _
		_, itemCount, texture, quality = BagnonDB.GetItemData(player, bagID, item:GetID())
		BagnonItem_UpdateBorder(item, quality, player)

		item.hasItem = texture and 1 or nil

		--hide cooldown since there isn't one for linked items
		BagnonItem_UpdateCooldown(bagID, item)
		HideEnchant(item)
		BagnonItem_SetLocked(item, nil)
		item.readable = nil
	else
		item.isLink = nil

		texture, itemCount, locked, quality, readable = GetContainerItemInfo(bagID, item:GetID())
		-- Native 1.12 already returns quality; an empty slot needs no metadata lookup.
		BagnonItem_UpdateBorder(item, quality or (not texture and 0))
		item.hasItem = texture and 1 or nil
		item.readable = readable

		if texture then
			BagnonItem_UpdateCooldown(bagID, item)
			BagnonItem_UpdateEnchant(item)
		else
			item.cooldown:Hide()
			item.cooldownWait = nil
			HideEnchant(item)
		end
		BagnonItem_SetLocked(item, locked)
	end

	--update texture and count
	SetItemButtonTexture(item, texture)
	SetItemButtonCount(item, itemCount)
end

-- Lazy on-demand overlay allocation: instantiated only when a weapon is present in bag slots 0..4
local function GetOrCreateEnchantOverlay(item)
	local overlay = item.enchantOverlay
	if overlay then
		return overlay
	end

	overlay = CreateFrame("Frame", item:GetName() .. "EnchantOverlay", item)
	overlay:SetAllPoints(item)
	overlay:EnableMouse(false)
	overlay:SetFrameLevel(item:GetFrameLevel() + 3)

	local iconFrame = CreateFrame("Frame", nil, overlay)
	iconFrame:SetWidth(14)
	iconFrame:SetHeight(14)
	iconFrame:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -1, -1)

	local iconBg = iconFrame:CreateTexture(nil, "BACKGROUND")
	iconBg:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 0, 0)
	iconBg:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 0, 0)
	iconBg:SetTexture(0, 0, 0, 0.85)

	local icon = iconFrame:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
	icon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	overlay.icon = icon
	overlay.iconFrame = iconFrame

	local duration = overlay:CreateFontString(nil, "OVERLAY")
	duration:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
	duration:SetPoint("TOPRIGHT", iconFrame, "BOTTOMRIGHT", 0, -1)
	duration:SetShadowOffset(1, -1)
	duration:SetShadowColor(0, 0, 0, 1)
	duration:SetTextColor(1.0, 0.4, 0.1)	-- only the few-charges text uses this label
	overlay.duration = duration

	-- The client counts the time down (countdownForCooldowns CVar 1): whole
	-- seconds, then minutes from 60 s. No sweep, no flash; only the number.
	local sweep = CreateFrame("Cooldown", nil, overlay, "CooldownFrameTemplate")
	sweep:SetWidth(30); sweep:SetHeight(10)
	sweep:SetPoint("TOPRIGHT", iconFrame, "BOTTOMRIGHT", 0, -1)
	sweep:EnableMouse(false)
	sweep:SetDrawSwipe(false); sweep:SetDrawBling(false); sweep:SetCountdownAbbrevThreshold(60)
	local number = sweep:GetCountdownFontString()
	number:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
	number:ClearAllPoints(); number:SetPoint("RIGHT", sweep, "RIGHT")
	-- The enchant ran out: read the item again and hide the badge.
	sweep:SetScript("OnCooldownDone", function() BagnonItem_UpdateEnchant(item) end)
	overlay.sweep = sweep

	overlay:Hide()
	item.enchantOverlay = overlay
	return overlay
end

function BagnonItem_UpdateEnchant(item)
	if BagnonSets.enchantBadges == 0 or item.isLink or not item.hasItem or Bagnon_IsCachedItem(item) then
		HideEnchant(item)
		return
	end

	local bagID = item:GetParent():GetID()
	local slotID = item:GetID()

	-- Only inspect real player bag slots (0..4), not bank slots (-1, 5..10)
	if bagID < 0 or bagID > 4 then
		HideEnchant(item)
		return
	end

	-- Read the current instance at this location; never infer an enchant from text.
	local location = item.enchantLocation or {}
	item.enchantLocation = location
	location.bagID, location.slotIndex = bagID, slotID
	local hasEnchant, expirationMs, charges, enchantID = C_Item.GetItemTempEnchantInfo(location)
	if not hasEnchant then
		HideEnchant(item)
		return
	end

	local overlay = GetOrCreateEnchantOverlay(item)
	-- Enchant metadata is resident DBC data. Re-resolve only when this slot's ID changes.
	if overlay.enchantID ~= enchantID then
		local info = C_Item.GetEnchantInfo(enchantID)
		local texture = info and info.spellID and C_Spell.GetSpellTexture(info.spellID)
		texture = texture or "Interface\\Icons\\INV_Misc_QuestionMark"
		if overlay.texture ~= texture then overlay.icon:SetTexture(texture); overlay.texture = texture end
		overlay.enchantID = enchantID
	end
	if not overlay.iconFrame:IsShown() then overlay.iconFrame:Show() end

	local text = ""
	if charges and charges > 0 and charges <= 5 then
		-- Few charges left matter more than the time: show them instead.
		text = charges .. "c"
		overlay.sweep:Clear(); overlay.cdEnd = nil
	else
		-- Start the client's countdown once; reading the same enchant again keeps it.
		local seconds = expirationMs / 1000
		local finish = GetTime() + seconds
		if not overlay.cdEnd or math.abs(overlay.cdEnd - finish) > 1.5 then
			overlay.cdEnd = finish
			overlay.sweep:SetCooldown(GetTime(), seconds)
		end
	end
	if overlay.badgeText ~= text then overlay.duration:SetText(text); overlay.badgeText = text end
	if not overlay:IsShown() then overlay:Show() end
end

function BagnonItem_UpdateBorder(button, quality, player)
	local holder = button:GetParent()
	local bagID = holder:GetID()
	local qBorder = button.qualityBorder

	if not quality or quality < 0 then
		-- Native 1.12 can return -1 instead of the rarity, also in bank slots: the item
		-- data knows it. A saved item that is not cached yet has none until
		-- GET_ITEM_INFO_RECEIVED (BagnonDB.GetItemData already asked for it).
		if not (player and Bagnon_IsCachedItem(button)) then
			local itemID = C_Container.GetContainerItemID(bagID, button:GetID())
			quality = itemID and C_Item.GetItemQualityByID(itemID)
		end
	end

	if quality and quality > 1 then
		if qBorder.quality ~= quality then
			local red, green, blue = GetBorderQualityColor(quality)
			qBorder:SetBackdropBorderColor(red, green, blue, 1)
			qBorder.quality = quality
		end
		if not qBorder:IsShown() then qBorder:Show() end
	elseif qBorder:IsShown() then
		qBorder:Hide()
	end

	--ammo and special bag slot coloring; the family is read once per bag (Frame.lua resets it)
	if bagID == KEYRING_CONTAINER then
		button.normalTexture:SetVertexColor(1, 0.7, 0)
	else
		local family = holder.bagFamily
		if not family then
			family = Bagnon_BagFamily(bagID, player)
			holder.bagFamily = family
		end
		if family % 8 ~= 0 then
			button.normalTexture:SetVertexColor(1, 1, 0)	-- quiver, ammo pouch or soul bag
		elseif family ~= 0 then
			button.normalTexture:SetVertexColor(0, 1, 0)	-- profession bag
		else
			button.normalTexture:SetVertexColor(1, 1, 1)
		end
	end
end

--Update cooldown
function BagnonItem_UpdateCooldown(container, button)
	if button.isLink then
		CooldownFrame_SetTimer(button.cooldown, 0, 0, 0)
		button.cooldownWait = nil
		return
	end

	local start, duration, enable = GetContainerItemCooldown(container, button:GetID())
	CooldownFrame_SetTimer(button.cooldown, start, duration, enable)

	-- Not started yet (for example while a use is blocked): dim the icon until it is
	if duration > 0 and enable == 0 then
		button.cooldownWait = 1
		SetItemButtonTextureVertexColor(button, 0.4, 0.4, 0.4)
	elseif button.cooldownWait then
		button.cooldownWait = nil
		SetItemButtonTextureVertexColor(button, 1, 1, 1)
	end
end
