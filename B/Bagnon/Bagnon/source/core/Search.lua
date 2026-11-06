--[[
	Search.lua
		Item search for the inventory and bank windows (ClassicAPI C_Container.SetItemSearch).
		Each window has a search box in its bottom row. Items that do not match are dimmed
		(BagnonItem_SetLocked reads isFiltered); the search is shared by every bag window.
--]]

if not Bagnon_EngineReady then
	return
end

local function Box(frame)
	return _G[frame:GetName() .. "Search"]
end

local function ShowHint(box)
	local hint = _G[box:GetName() .. "Hint"]
	if box.focused or box:GetText() ~= "" then hint:Hide() else hint:Show() end
end

-- Set the one search the client keeps; INVENTORY_SEARCH_UPDATE refreshes the windows.
local function Apply(text)
	Bagnon_SetSearching(text ~= "")
	C_Container.SetItemSearch(text)
end

-- Empty a window's box, release the keyboard, and keep the other window's search if it has one.
function BagnonSearch_Close(frame)
	local box = Box(frame)
	box:ClearFocus()
	box:SetText("")
	local other = Box(frame == Bagnon and Banknon or Bagnon)
	Apply(other:GetText())
	ShowHint(box)
end

-- Show or hide the box (the Search box option). Another character's saved bags cannot be
-- searched, so there the box rests until the live bags are back.
function BagnonSearch_Update(frame, cached)
	local box = Box(frame)
	if BagnonSets.showSearch == 0 then
		BagnonSearch_Close(frame)
		if box:IsShown() then box:Hide() end
		return
	end
	if not box:IsShown() then box:Show() end
	if cached then BagnonSearch_Close(frame) end
	box:EnableMouse(not cached)
	box:SetAlpha(cached and 0.4 or 1)
end

function BagnonSearch_OnTextChanged(box)
	Apply(box:GetText())
	ShowHint(box)
end

function BagnonSearch_OnFocus(box, focused)
	box.focused = focused
	ShowHint(box)
end

function BagnonSearch_OnEnter(box)
	GameTooltip:SetOwner(box, "ANCHOR_TOP")
	GameTooltip:SetText(BAGNON_SEARCH, 1, 1, 1)
	GameTooltip:AddLine(BAGNON_SEARCH_TOOLTIP, 0.8, 0.8, 0.8, 1)
	GameTooltip:Show()
end

local function RefreshFrame(frame)
	if frame:IsVisible() and not Bagnon_IsCachedFrame(frame) then
		BagnonFrame_UpdateLock(frame)
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("INVENTORY_SEARCH_UPDATE")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
	if event == "PLAYER_LOGIN" then
		-- The client keeps the search over a /reload; the boxes start empty.
		Apply("")
	else
		RefreshFrame(Bagnon)
		RefreshFrame(Banknon)
	end
end)
