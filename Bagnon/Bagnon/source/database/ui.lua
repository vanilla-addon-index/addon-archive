--[[
	ui.lua
		Functions for the dropdown menu for showing cached data
		Author: Tuller, McPewPew, Fostercare5988
		Built for ClassicAPI

	Essentially the dropdown is used to switch between the inventory of other characters
	Why not use a normal dropdown?  It takes a lot of memory
--]]

if not Bagnon_EngineReady then
	return
end

local minWidth = 120

--switch to view a different character's data
function BagnonDBUI_ChangePlayer(frame, player)
	frame.player = player

	--update the frame's title
	_G[frame:GetName() .. "Title"]:SetText(string.format(frame.title, player))

	--update the frame's contents
	BagnonFrame_Generate(frame)

	--update the frame's bags, if they exist and are shown
	local bagFrame = _G[frame:GetName() .. "Bags"]
	if bagFrame and bagFrame:IsShown() then
		for i = 1, 10 do
			BagnonBag_UpdateTexture(frame, i)
		end
	end

	--update banknon's purchase button
	if frame == Banknon then
		Banknon_UpdatePurchaseButtonVis()
	end
end

--[[ Character List ]]--

--create a player button, which is used to switch between characters
local function CreatePlayerButton(id, parent)
	local button = CreateFrame("CheckButton", parent:GetName() .. id, parent, "BagnonDBUINameBox")
	if id == 1 then
		button:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -4)
	else
		button:SetPoint("TOP", _G[parent:GetName() .. (id - 1)], "BOTTOM", 0, 6)
	end
	return button
end

function BagnonDBUI_ShowCharacterList(parentFrame)
	BagnonDBUICharacterList.frame = parentFrame

	local width = minWidth

	--update button info
	local index = 0
	for player in BagnonDB.GetPlayers(true) do
		index = index + 1

		local button = _G["BagnonDBUICharacterList" .. index] or CreatePlayerButton(index, BagnonDBUICharacterList)
		button:SetText(player)
		if button:GetTextWidth() + 40 > width then
			width = button:GetTextWidth() + 40
		end

		if parentFrame.player == player then
			button:SetChecked(true)
		else
			button:SetChecked(false)
		end
		button:Show()
	end

	local i = index + 1
	while _G["BagnonDBUICharacterList" .. i] do
		_G["BagnonDBUICharacterList" .. i]:Hide()
		i = i + 1
	end

	--resize and position the frame
	BagnonDBUICharacterList:SetHeight(12 + index * 19)
	BagnonDBUICharacterList:SetWidth(width)
	BagnonDBUICharacterList:ClearAllPoints()
	BagnonDBUICharacterList:SetPoint("TOPLEFT", parentFrame:GetName() .. "DropDown", "BOTTOMLEFT", 0, 4)
	BagnonDBUICharacterList:Show()
end

