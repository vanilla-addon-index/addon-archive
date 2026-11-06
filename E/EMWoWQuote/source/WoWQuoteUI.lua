BINDING_HEADER_WOWQUOTE_HEADER = "WoWQuote"
BINDING_NAME_WOWQUOTE_TOGGLE = "Toggle WoWQuote"

local WQ_RaidOrParty = function(id)
	if (GetNumRaidMembers() > 0) then 
		WQ_Raid(id) 
	else
		WQ_Party(id)
	end
end

WQUI = {
	NUM_DISPLAYABLE = 20,  -- maxmimum number of quotes that are visible at a time
	
	CategoryDropDown = {}, -- hold functions for the Category DropDown
	ChannelDropDown = {},  -- hold functions for the Channel DropDown
	DisplayedItems = {},   -- all quotes displayed for the current category
	
	Quote = WQ_RaidOrParty,      -- the quote function that is used for posting quotes
	Channels = {
		{ name=WQChannels.s.name, func=WQ_Say },
		{ name=WQChannels.p.name, func=WQ_RaidOrParty },
		{ name=WQChannels.g.name, func=WQ_Guild },
		{ name=WQChannels.o.name, func=WQ_Officer },
	},
	
	Sorters = {
		ByMessage = function(a, b) return (a.msg < b.msg) end,
		ByID = function(a, b) return (a.id < b.id) end
	},
	Sorter = function(a, b) return (a.msg < b.msg) end
}

function WQUI:Msg(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg, 1.0, 0.5, 0.5)
end

function WQUI:Toggle()
	if (self:IsVisible()) then
		HideUIPanel(self)
	else
		ShowUIPanel(self)
	end
end

function WQUI:Localize()
	local L = WoWQuoteUI_Localization
	local name = self:GetName()
	
	getglobal(name.."Title"):SetText(L.DIALOG_TITLE)
	self.Columns.Text:SetText(L.COLUMN_TEXT)
	self.Columns.ID:SetText(L.COLUMN_DURATION)
	
	BINDING_HEADER_WOWQUOTE_HEADER = L.BINDING_HEADER
	BINDING_NAME_WOWQUOTE_TOGGLE = L.BINDING_TOGGLE
end

function WQUI:Initialize()
	UIPanelWindows[self:GetName()] = { area = "left", pushable = 5, whileDead = 1 };

	self:Localize()	
	self.Items = {}
	
	-- create list items
	self.Items[1] = CreateFrame("Button", "WoWQuoteItem1", self, "WoWQuoteItemTemplate")
	self.Items[1]:SetPoint("TOPLEFT", self, "TOPLEFT", 20, -100)

	for i=2,self.NUM_DISPLAYABLE do
		self.Items[i] = CreateFrame("Button", "WoWQuoteItem"..i, self, "WoWQuoteItemTemplate")
		self.Items[i]:SetPoint("TOPLEFT", self.Items[i-1], "BOTTOMLEFT", 0, 0)
	end
	
	self:SelectCategory(0) -- "all"
end

function WQUI:UpdateItems()
	local tablelen = 0

	for k, v in pairs(self.DisplayedItems) do
		tablelen = tablelen + 1
	end
	
	local numItems = tablelen;--strlen(self.DisplayedItems);
	local scrollFrame = getglobal(self:GetName().."ScrollFrame")
	local offset = FauxScrollFrame_GetOffset(scrollFrame) or 0
	
	-- display quotes according to the scrollbar's offset
	for i=1,self.NUM_DISPLAYABLE do
		local button = self.Items[i]

		if (i <= numItems) then
			local media = self.DisplayedItems[i+offset]
			local buttonName = button:GetName()
	
			getglobal(buttonName.."LabelsText"):SetText(media.msg)
			getglobal(buttonName.."LabelsID"):SetText(media.id)
			button.id = media.id
			button:Show();
		else -- hide unused button if there are less quotes than buttons
			button:Hide();
		end			
	end

	FauxScrollFrame_Update(scrollFrame, numItems, self.NUM_DISPLAYABLE, 16)
end

function WQUI:SortItems(...)
	--local arg = {...}

	if (arg[1]) then
		self.Sorter = arg[1]
	end
	sort(WQUI.DisplayedItems, self.Sorter)
end

function WQUI:SelectCategory(category)
	WQUI.DisplayedItems = {}
	for i in ipairs(WQmedia) do
		if (category == 0 or WQmedia[i].cat == category) then
			table.insert(WQUI.DisplayedItems, WQmedia[i])
		end
	end
	
	self:SortItems()	
	
	FauxScrollFrame_SetOffset(getglobal(self:GetName().."ScrollFrame"), 0)
	self:UpdateItems()
end

function WQUI.CategoryDropDown.OnClick()
	local category = this:GetID()
	UIDropDownMenu_SetSelectedID(WoWQuoteDialogCategoryDropDown, category);
	
	WQUI:SelectCategory(category-1) -- 0 for "all", but this is 1-index based
end

function WQUI.CategoryDropDown.Initialize()
	UIDropDownMenu_AddButton( {text=ALL, value=0, func=WQUI.CategoryDropDown.OnClick} );
	
	local tablelen = 0

	for k, v in pairs(WQcategories) do
		tablelen = tablelen + 1
	end
	
	for i=1, tablelen do
		UIDropDownMenu_AddButton( {text=WQcategories[i], value=i, func=WQUI.CategoryDropDown.OnClick} );
	end
end

function WQUI.ChannelDropDown.OnClick()
	local channel = this:GetID()
	UIDropDownMenu_SetSelectedID(WoWQuoteDialogChannelDropDown, channel);
	
	WQUI.Quote = WQUI.Channels[channel].func
end

function WQUI.ChannelDropDown.Initialize()

	local tablelen = 0

	for k, v in pairs(WQUI.Channels) do
		tablelen = tablelen + 1
	end

	for i=1, tablelen do
		UIDropDownMenu_AddButton( {text=WQUI.Channels[i].name, func=WQUI.ChannelDropDown.OnClick} );
	end
end
