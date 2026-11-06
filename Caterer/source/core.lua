--[[---------------------------------------------------------------------------------
	Caterer
	written by Pik/Silvermoon (original author), continued Artur91425 
	code based on FreeRefills code by Kyahx with a shout out to Maia.
	inspired by Arcanum, Trade Dispenser, Vending Machine.
------------------------------------------------------------------------------------]]
local _G = _G
local select = _G.select
local UnitClass = _G.UnitClass

if select(2, UnitClass('Player')) ~= 'MAGE' then return end

local pairs = _G.pairs
local print = _G.print
local error = _G.error
local tonumber = _G.tonumber
local fmod = _G.math.fmod
local floor = _G.math.floor
local gsub = _G.string.gsub
local upper = _G.string.upper
local lower = _G.string.lower
local match = _G.string.match
local format = _G.string.format

local UnitName = _G.UnitName
local IsInGuild = _G.IsInGuild
local UnitInRaid = _G.UnitInRaid
local CancelTrade = _G.CancelTrade
local AcceptTrade = _G.AcceptTrade
local UnitInParty = _G.UnitInParty
local TargetByName = _G.TargetByName
local GetItemCount = _G.GetItemCount
local GetGuildInfo = _G.GetGuildInfo
local InitiateTrade = _G.InitiateTrade
local GetNumFriends = _G.GetNumFriends
local GetFriendInfo = _G.GetFriendInfo
local CursorHasItem = _G.CursorHasItem
local SendChatMessage = _G.SendChatMessage
local ClickTradeButton = _G.ClickTradeButton
local GetContainerItemID = _G.GetContainerItemID
local PickupContainerItem = _G.PickupContainerItem
local GetContainerNumSlots = _G.GetContainerNumSlots
local GetContainerItemInfo = _G.GetContainerItemInfo


local addon_name = 'Caterer'
Caterer = CreateFrame('Frame')

local addon = Caterer
local L		= LibStub('AceLocale-3.0'):GetLocale(addon_name)
local LDB = LibStub('LibDataBroker-1.1')
local LDBIcon = LibStub('LibDBIcon-1.0')
local LibQTip = LibStub('LibQTip-1.0')

local target, whisperMode, whisperCount
addon:RegisterEvent('VARIABLES_LOADED')

addon.order = {
	trades = {'friends', 'group', 'guild', 'other'},
	food = {5349, 1113, 1114, 1487, 8075, 8076, 22895},
	water = {5350, 2288, 2136, 3772, 8077, 8078, 8079},
}

addon.dataTable = {
	food = {
		[22895] = L["Conjured Cinnamon Roll"],
		[8076]  = L["Conjured Sweet Roll"],
		[8075]  = L["Conjured Sourdough"],
		[1487]  = L["Conjured Pumpernickel"],
		[1114]  = L["Conjured Rye"],
		[1113]  = L["Conjured Bread"],
		[5349]  = L["Conjured Muffin"]
	},
	water = {
		[8079]  = L["Conjured Crystal Water"],
		[8078]  = L["Conjured Sparkling Water"],
		[8077]  = L["Conjured Mineral Water"],
		[3772]  = L["Conjured Spring Water"],
		[2136]  = L["Conjured Purified Water"],
		[2288]  = L["Conjured Fresh Water"],
		[5350]  = L["Conjured Water"]
	}
}

addon.defaults = {
	enabled = true,
	minimapIcon = {
		hide = false,
		minimapPos = 220,
		radius = 80,
	},
	exceptionList = {},
	exceptionList_sort = {
		[1] = '>',
		[2] = 'name',
	},
	whisperRequest = false,
	tradeWhat = {food = 22895, water = 8079},
	tradeCount = {
		['DRUID']   = {food = 0 , water = 60},
		['HUNTER']  = {food = 60, water = 20},
		['PALADIN'] = {food = 40, water = 40},
		['PRIEST']  = {food = 0 , water = 60},
		['ROGUE']   = {food = 60, water = 0 },
		['SHAMAN']  = {food = 0 , water = 60},
		['WARLOCK'] = {food = 60, water = 40},
		['WARRIOR'] = {food = 60, water = 0 },
		['MAGE']    = {food = 0 , water = 0 },
	},
	tradeFilter = {
		friends = true,
		group = true,
		guild = true,
		other = false
	},
}

function addon:OnEvent()
	if not this[event] then return end
	this[event](this, arg1, arg2, arg3, arg4, arg5)
end

function addon:OnInitialize()
	if not CatererDB then CatererDB = self.defaults end
	local icon_obj = LDB:NewDataObject(addon_name, {
		icon = [[Interface\Icons\Inv_drink_18]],
		OnClick = function()
			if arg1 ~= 'RightButton' then return end
			addon.config:Show()
		end,
		OnEnter = function()
			if LibQTip:IsAcquired(addon_name..'MiniMapTooltip') then return end
			
			this.tooltip = LibQTip:Acquire(addon_name..'MiniMapTooltip', 2, 'LEFT', 'RIGHT')
			local tooltip = this.tooltip
			
			local header_font = CreateFont(addon_name..'HeaderFont')
			header_font:SetFont('GameTooltipHeaderText', 16)
			header_font:SetTextColor(.41, .80, .94)
			tooltip:SetHeaderFont(header_font)
			
			tooltip:SetFont(GameFontNormal)
			
			local header = tooltip:AddHeader()
			tooltip:SetCell(header, 1, addon_name..' '..GetAddOnMetadata(addon_name, 'Version'), header_font, 'CENTER', 2)
			tooltip:AddSeparator(6, nil, nil, nil, 0)
			
			tooltip.food = tooltip:AddLine(L["Food"]..':', addon.dataTable.food[CatererDB.tradeWhat.food])
			tooltip:SetLineScript(tooltip.food, 'OnMouseDown', addon.ToggleOptions, {'tradeWhat', 'food'})
			
			tooltip.water = tooltip:AddLine(L["Water"]..':', addon.dataTable.water[CatererDB.tradeWhat.water])
			tooltip:SetLineScript(tooltip.water, 'OnMouseDown', addon.ToggleOptions, {'tradeWhat', 'water'})
			
			tooltip:AddSeparator(10, nil, nil, nil, 0)
			
			for _, trade in pairs(addon.order.trades) do
				local text = format('Trade with %s', trade)
				local value = CatererDB.tradeFilter[trade]
				tooltip[trade] = tooltip:AddLine(L[text]..':', value and L["On"] or L["Off"])
				tooltip:SetCellTextColor(tooltip[trade], 2, value and 0 or 1, value and 1 or 0, 0, 1)
				tooltip:SetLineScript(tooltip[trade], 'OnMouseDown', addon.ToggleOptions, {'tradeFilter', trade})
			end
			tooltip:AddSeparator(10, nil, nil, nil, 0)
			
			local value = CatererDB.whisperRequest
			tooltip.request = tooltip:AddLine(L["Whisper requests"]..':', value and L["On"] or L["Off"])
			tooltip:SetCellTextColor(tooltip.request, 2, value and 0 or 1, value and 1 or 0, 0, 1)
			tooltip:SetLineScript(tooltip.request, 'OnMouseDown', addon.ToggleOptions, {'whisperRequest'})
			
			tooltip:AddSeparator(10, nil, nil, nil, 0)
			
			local hint_line = tooltip:AddLine()
			tooltip:SetCell(hint_line, 1, '|cff00ff00'..L["Right click on the minimap button to open settings.\nClick on the point tooltip to quickly manage the addon."]..'|r', nil, 'LEFT', 2)
			
			tooltip:SmartAnchorTo(this)
			tooltip:Show()
		end,
		OnLeave = function()
			this.tooltip:SetAutoHideDelay(0.15, this)
		end
	})
	LDBIcon:Register(addon_name, icon_obj, CatererDB.minimapIcon)
	self.minimapButton = LDBIcon:GetMinimapButton(addon_name)
	
	if CatererDB.enabled then
		self:OnEnable()
		else
		self:OnDisable()
	end
	self.config:UpdateConfig()
end

function addon:OnEnable()
	self:RegisterEvent('TRADE_SHOW')
	self:RegisterEvent('TRADE_ACCEPT_UPDATE')
	self:RegisterEvent('CHAT_MSG_WHISPER')
end

function addon:OnDisable()
	self:UnregisterAllEvents()
end

--[[---------------------------------------------------------------------------------
	Event Handlers
------------------------------------------------------------------------------------]]

function addon:VARIABLES_LOADED()
	self:OnInitialize()
end

function addon:TRADE_SHOW()
	self:UnregisterEvent('UI_ERROR_MESSAGE')
	local performTrade = self:CheckTheTrade()
	if not performTrade then return end
	
	local NPCName, NPCClass = lower(UnitName('NPC')), select(2, UnitClass('NPC'))
	local item = CatererDB.tradeWhat
	local count
	if whisperMode then
		count = whisperCount
	elseif CatererDB.exceptionList[NPCName] then
		if count.food == 0 and count.water == 0 then
			SendChatMessage('['..addon_name..'] '..L["You are on my blacklist."], 'WHISPER', nil, NPCName)
			return CancelTrade()
		end
		count = CatererDB.exceptionList[NPCName]
	else
		count = CatererDB.tradeCount[NPCClass]
	end
	
	for itemType in pairs(self.dataTable) do
		self:DoTheTrade(item[itemType], count[itemType], itemType)
	end
end

function addon:TRADE_ACCEPT_UPDATE(arg1, arg2)
	-- arg1 - Player has agreed to the trade (1) or not (0)
	-- arg2 - Target has agreed to the trade (1) or not (0)
	if arg2 then
		AcceptTrade()
	end
end

function addon:CHAT_MSG_WHISPER(arg1, arg2)
	-- arg1 - Message received
	-- arg2 - Author
	local prefix, foodCount, waterCount = match(arg1, '^(#cat) (%d+) (%d+)')
	if not prefix then return end
	
	foodCount, waterCount = tonumber(foodCount), tonumber(waterCount)
	if not CatererDB.whisperRequest then
		return SendChatMessage('['..addon_name..'] '..L["Service is temporarily disabled."], 'WHISPER', nil, arg2)
		elseif not (foodCount and waterCount) or fmod(foodCount, 20) ~= 0 or fmod(waterCount, 20) ~= 0 then
		return SendChatMessage('['..addon_name..'] '..L["Expected string"]..': <#cat> '..L["<amount of food>"]..'> <'..L["<amount of water>"]..'. '..L["Note"]..': '..L["The numbers must be a multiple of 20."], 'WHISPER', nil, arg2)
		elseif foodCount + waterCount > 120 then
		return SendChatMessage('['..addon_name..'] '..L["The total number of items should not exceed 120."], 'WHISPER', nil, arg2)
		elseif foodCount + waterCount == 0 then
		return SendChatMessage('['..addon_name..'] '..L["The quantity for both items can not be zero."], 'WHISPER', nil, arg2)
	end
	
	TargetByName(arg2, true)
	target = UnitName('target')
	whisperCount = {}
	if target == arg2 then
		whisperMode = true
		whisperCount = {food = foodCount, water = waterCount}
		self:RegisterEvent('UI_ERROR_MESSAGE') -- check if target to trade is too far
		InitiateTrade('target')
	end
end

function addon:UI_ERROR_MESSAGE(arg1)
	-- arg1 - Message received
	if arg1 == ERR_TRADE_TOO_FAR then
		whisperMode = false
		SendChatMessage('['..addon_name..'] '..L["It is necessary to come closer."], 'WHISPER', nil, target)
	end
	self:UnregisterEvent('UI_ERROR_MESSAGE')
end

--[[--------------------------------------------------------------------------------
	Shared Functions
-----------------------------------------------------------------------------------]]

function addon:CheckTheTrade()
	-- Check to see whether or not we should execute the trade.
	local UnitInGroup, UnitInMyGuild, UnitInFriendList
	
	if UnitInParty('NPC') or UnitInRaid('NPC') then
		UnitInGroup = true
	end
	if IsInGuild() and GetGuildInfo('player') == GetGuildInfo('NPC') then
		UnitInMyGuild = true
	end
	local numFriends = GetNumFriends()
	for i = 1, numFriends do
		if UnitName('NPC') == GetFriendInfo(i) then
			UnitInFriendList = true
			break
		end
	end
	
	if CatererDB.tradeFilter.group and UnitInGroup then
		return true
		elseif CatererDB.tradeFilter.guild and UnitInMyGuild then
		return true
		elseif CatererDB.tradeFilter.friends and UnitInFriendList then
		return true
		elseif CatererDB.tradeFilter.other then
		if UnitInGroup or UnitInMyGuild or UnitInFriendList then
			return false
			else
			return true
		end
	end
end

function addon:DoTheTrade(itemID, count, itemType)
	if not TradeFrame:IsShown() or count == 0 then return end
	
	local bagCount = GetItemCount(itemID)
	if bagCount < count then
		local itemName, hyperLink = GetItemInfo(itemID)
		if not itemName then
			hyperLink = 'item:'..itemID..':0:0:0'
			itemName = addon.dataTable[itemType][itemID]
		end
		local link = '|cffffffff'..'|H'..hyperLink..'|h['..itemName..']|h|r'		
		SendChatMessage(format(L["I can't complete the trade right now. I'm out of %s."], link))
		return CancelTrade()
	end
	
	local stackSize = 20
	local stackLeft = floor(count/stackSize)
	
	for bag = 4, 0, -1 do
		local size = GetContainerNumSlots(bag)
		if size then
			for slot = size, 1, -1 do
				if stackLeft == 0 then break end
				
					local slotID = GetContainerItemID(bag, slot)
					if slotID == itemID then
					local slotCount = select(2, GetContainerItemInfo(bag, slot))
					if slotCount == stackSize then
						PickupContainerItem(bag, slot)
						if not CursorHasItem() then return error('|cffff9966'..L["Had a problem picking things up!"]..'|r') end
						local tradeSlot = TradeFrame_GetAvailableSlot() -- Blizzard function
						ClickTradeButton(tradeSlot)
						stackLeft = stackLeft - 1
					end
				end
			end
		end
	end
	if whisperMode then whisperMode = false end
end

function addon:FirstToUpper(str) -- first character UPPER case
  return gsub(str, '^%l', upper)
end

function addon:UpdateTooltipValue(line, col, value)
	self.minimapButton.tooltip:SetCell(line, col, value)
end

function addon:ToggleOptions(arg)
	local a1, a2 = unpack(arg)
	if a1 == 'tradeWhat' then
		local button = arg1
		local value, curKey, newKey
		for i, id in pairs(addon.order[a2]) do
			if id == CatererDB[a1][a2] then
				curKey = i
				break
			end
		end
		
		if button == 'RightButton' then --обратный порядок
			curKey = curKey - 2
			if curKey <= 0 then curKey = getn(addon.order[a2]) + curKey end
		end
		newKey, value = next(addon.order[a2], curKey)
		if not newKey then
			newKey, value = next(addon.order[a2])
		end
		
		CatererDB[a1][a2] = value
		
		local line = addon.minimapButton.tooltip[a2]
		addon:UpdateTooltipValue(line, 2, addon.dataTable[a2][CatererDB[a1][a2]])
	elseif a1 == 'tradeFilter' then
		local value = CatererDB[a1][a2]
		CatererDB[a1][a2] = not value
		
		local line = addon.minimapButton.tooltip[a2]
		addon:UpdateTooltipValue(line, 2, CatererDB[a1][a2] and L["On"] or L["Off"])
		addon.minimapButton.tooltip:SetCellTextColor(line, 2, CatererDB[a1][a2] and 0 or 1, CatererDB[a1][a2] and 1 or 0, 0, 1)
	elseif a1 == 'whisperRequest' then
		local value = CatererDB[a1]
		CatererDB[a1] = not value
		
		local line = addon.minimapButton.tooltip.request
		addon:UpdateTooltipValue(line, 2, CatererDB[a1] and L["On"] or L["Off"])
		addon.minimapButton.tooltip:SetCellTextColor(line, 2, CatererDB[a1] and 0 or 1, CatererDB[a1] and 1 or 0, 0, 1)
	end
	
	addon.config:UpdateConfig()
end

addon:SetScript('OnEvent', addon.OnEvent)
