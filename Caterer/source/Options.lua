if not Caterer then return end

local _G = _G
local type = _G.type
local pairs = _G.pairs
local print = _G.print
local select = _G.select
local tonumber = _G.tonumber
local cos = _G.math.cos
local sin = _G.math.sin
local rad = _G.math.rad
local sqrt = _G.math.sqrt
local fmod = _G.math.fmod
local floor = _G.math.floor
local find = _G.string.find
local match = _G.string.match
local upper = _G.string.upper
local lower = _G.string.lower
local format = _G.string.format
local getn = _G.table.getn
local tsort = _G.table.sort
local tinsert = _G.table.insert

local PlaySound = _G.PlaySound
local CreateFrame = _G.CreateFrame
local GetAddOnMetadata = _G.GetAddOnMetadata

local addon_name = 'Caterer'
local addon = Caterer
local L		= LibStub('AceLocale-3.0'):GetLocale(addon_name)
local BC	= LibStub('LibBabble-Class-3.0'):GetLookupTable()

local classes = {'Warrior', 'Paladin', 'Priest', 'Shaman', 'Druid', 'Rogue', 'Mage', 'Warlock', 'Hunter'}

StaticPopupDialogs['CATERER_CONFIRM_RESET_SETTINGS'] = { 
	text = L["Do you really want to reset the settings to their default values?"],
	button1 = OKAY,
	button2 = CANCEL,
	OnAccept = function()
		addon.config.default()
	end,
	OnCancel = function() end,
	timeout = 0,
	exclusive = 1,
	hideOnEscape = 1,
	whileDead = 1,
}

addon.config = CreateFrame('Frame', addon_name..'Config')
local config = addon.config
config:Hide()
config:SetFrameStrata('HIGH')
config:EnableMouse(true)
config:SetPoint('CENTER', 0, 0)
config:SetWidth(433)
config:SetHeight(458)
config:SetBackdrop({
	bgFile = [[Interface\DialogFrame\UI-DialogBox-Background]], tile = true, tileSize = 32,
	edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]], edgeSize = 32,
	insets = {left = 11, right = 11, top = 12, bottom = 10},
})

config.title = config:CreateTexture(config:GetName()..'Title', 'ARTWORK')
config.title.text = config:CreateFontString(config:GetName()..'HeaderText', 'ARTWORK', 'GameFontNormal')
config.title.text:SetPoint('TOP', 0, -2)
config.title.text:SetText(addon_name..' '..GetAddOnMetadata(addon_name, 'version'))
config.title:SetTexture([[Interface\DialogFrame\UI-DialogBox-Header]])
config.title:SetPoint('TOP', 0, 12)
config.title:SetWidth(config.title.text:GetStringWidth()*2.8)
config.title:SetHeight(64)

config.cancel_btn = CreateFrame('Button', config:GetName()..'Cancel', config, 'UIPanelButtonTemplate')
config.cancel_btn:SetText(CANCEL)
config.cancel_btn:SetWidth(96)
config.cancel_btn:SetHeight(22)
config.cancel_btn:SetPoint('BOTTOMRIGHT', -16, 16)
config.cancel_btn:SetScript('OnClick', function()
	config.cancel()
	config:Hide()
end)

config.okay_btn = CreateFrame('Button', config:GetName()..'Okay', config, 'UIPanelButtonTemplate')
config.okay_btn:SetText(OKAY)
config.okay_btn:SetWidth(96)
config.okay_btn:SetHeight(22)
config.okay_btn:SetPoint('BOTTOMRIGHT', config.cancel_btn, 'BOTTOMLEFT', 0, 0)
config.okay_btn:SetScript('OnClick', function()
	config.okay()
	config:Hide()
end)

config.defaults_btn = CreateFrame('Button', config:GetName()..'Defaults', config, 'UIPanelButtonGrayTemplate')
config.defaults_btn:SetText(DEFAULTS)
config.defaults_btn:SetWidth(96)
config.defaults_btn:SetHeight(22)
config.defaults_btn:SetPoint('BOTTOMLEFT', 16, 16)
config.defaults_btn:SetScript('OnClick', function()
	StaticPopup_Show('CATERER_CONFIRM_RESET_SETTINGS')
end)

config.desc = config:CreateFontString(nil, 'ARTWORK', 'GameFontWhite')
config.desc:SetPoint('TOPLEFT', 16, -40)
config.desc:SetWidth(config:GetWidth() - 16*2)
config.desc:SetJustifyH('LEFT')
config.desc:SetText(GetAddOnMetadata(addon_name, 'Notes'))

config.container = CreateFrame('Frame', config:GetName()..'Container', config)
local container = config.container
container:SetPoint('TOPLEFT', config, 'TOPLEFT', 20, -100)
container:SetPoint('BOTTOMRIGHT', config, 'BOTTOMRIGHT', -20, 40)

container.TopLeft = container:CreateTexture(nil, 'BACKGROUND')
container.TopLeft:SetTexture([[Interface\Tooltips\UI-Tooltip-Border]])
container.TopLeft:SetWidth(16)
container.TopLeft:SetHeight(16)
container.TopLeft:SetPoint('TOPLEFT', 0, 0)
container.TopLeft:SetTexCoord(.5, .625, 0, 1)
container.BottomLeft = container:CreateTexture(nil, 'BACKGROUND')
container.BottomLeft:SetTexture([[Interface\Tooltips\UI-Tooltip-Border]])
container.BottomLeft:SetWidth(16)
container.BottomLeft:SetHeight(16)
container.BottomLeft:SetPoint('BOTTOMLEFT', 0, 0)
container.BottomLeft:SetTexCoord(.75, .875, 0, 1)
container.BottomRight = container:CreateTexture(nil, 'BACKGROUND')
container.BottomRight:SetTexture([[Interface\Tooltips\UI-Tooltip-Border]])
container.BottomRight:SetWidth(16)
container.BottomRight:SetHeight(16)
container.BottomRight:SetPoint('BOTTOMRIGHT', 0, 0)
container.BottomRight:SetTexCoord(.875, 1, 0, 1)
container.TopRight = container:CreateTexture(nil, 'BACKGROUND')
container.TopRight:SetTexture([[Interface\Tooltips\UI-Tooltip-Border]])
container.TopRight:SetWidth(16)
container.TopRight:SetHeight(16)
container.TopRight:SetPoint('TOPRIGHT', 0, 0)
container.TopRight:SetTexCoord(.625, .75, 0, 1)
container.Left = container:CreateTexture(nil, 'BACKGROUND')
container.Left:SetTexture([[Interface\Tooltips\UI-Tooltip-Border]])
container.Left:SetPoint('TOPLEFT', container.TopLeft, 'BOTTOMLEFT')
container.Left:SetPoint('BOTTOMRIGHT', container.BottomLeft, 'TOPRIGHT')
container.Left:SetTexCoord(0, .125, 0, 1)
container.Right = container:CreateTexture(nil, 'BACKGROUND')
container.Right:SetTexture([[Interface\Tooltips\UI-Tooltip-Border]])
container.Right:SetPoint('TOPLEFT', container.TopRight, 'BOTTOMLEFT')
container.Right:SetPoint('BOTTOMRIGHT', container.BottomRight, 'TOPRIGHT')
container.Right:SetTexCoord(.125, .25, 0, 1)
container.Bottom = container:CreateTexture(nil, 'BACKGROUND')
container.Bottom:SetTexture([[Interface\Tooltips\UI-Tooltip-Border]])
container.Bottom:SetPoint('BOTTOMLEFT', container.BottomLeft, 'BOTTOMRIGHT')
container.Bottom:SetPoint('BOTTOMRIGHT', container.BottomRight, 'BOTTOMLEFT')
container.Bottom:SetTexCoord(.8, .95, 0, 1)
container.Spacer1 = container:CreateTexture(nil, 'BACKGROUND')
container.Spacer1:SetTexture([[Interface\AddOns\Caterer\textures\UI-OptionsFrame-Spacer]])
container.Spacer1:SetPoint('LEFT', container.TopLeft, 'RIGHT')
container.Spacer2 = container:CreateTexture(nil, 'BACKGROUND')
container.Spacer2:SetTexture([[Interface\AddOns\Caterer\textures\UI-OptionsFrame-Spacer]])
container.Spacer2:SetPoint('RIGHT', container.TopRight, 'LEFT')

container.tabs = {}
container.frames = {}

-- General tab
---------------------------------------------------
container.tabs[1] = CreateFrame('Button', container:GetName()..'Tab1', container, 'OptionsFrameTabButtonTemplate')
container.tabs[1]:SetPoint('BOTTOMLEFT', container, 'TOPLEFT', 6, -2)
container.tabs[1]:SetText(L["General"])
container.tabs[1]:SetID(1)
container.tabs[1]:SetScript('OnClick', function() container:Tab_OnClick(this) end)

container.frames[1] = CreateFrame('Frame', container:GetName()..'Frame1', container)
container.frames[1]:SetAllPoints()
local general_frame = container.frames[1]

general_frame.enabled = CreateFrame('CheckButton', general_frame:GetName()..'EnableCheckbox', general_frame, 'OptionsCheckButtonTemplate')
_G[general_frame.enabled:GetName()..'Text']:SetText(L["Enable addon"])
general_frame.enabled:SetWidth(26)
general_frame.enabled:SetHeight(26)
general_frame.enabled:SetPoint('TOPLEFT', 20, -20)
general_frame.enabled:SetScript('OnClick', function()
	general_frame.enabled.setFunc(this:GetChecked())
end)

general_frame.food_label = general_frame:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
general_frame.food_label:SetPoint('TOPLEFT', general_frame.enabled, 'BOTTOMLEFT', 0, -30)
general_frame.food_label:SetWidth(50)
general_frame.food_label:SetJustifyH('LEFT')
general_frame.food_label:SetText(L["Food"]..':')
general_frame.food = CreateFrame('Frame', general_frame:GetName()..'FoodDropdown', general_frame, 'UIDropDownMenuTemplate')
general_frame.food:SetPoint('LEFT', general_frame.food_label, 'RIGHT', -10, -2)
UIDropDownMenu_SetWidth(260, general_frame.food)
UIDropDownMenu_Initialize(general_frame.food, function()
	for k, v in pairs(addon.order.food) do
		local info = {}
		info.text = addon.dataTable.food[v]
		info.value = v
		info.func = function()
			UIDropDownMenu_SetSelectedValue(general_frame.food, this.value)
		end
		UIDropDownMenu_AddButton(info)
	end
end)

general_frame.water_label = general_frame:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
general_frame.water_label:SetPoint('TOPLEFT', general_frame.food_label, 'BOTTOMLEFT', 0, -20)
general_frame.water_label:SetWidth(50)
general_frame.water_label:SetJustifyH('LEFT')
general_frame.water_label:SetText(L["Water"]..':')
general_frame.water = CreateFrame('Frame', general_frame:GetName()..'WaterDropdown', general_frame, 'UIDropDownMenuTemplate')
general_frame.water:SetPoint('LEFT', general_frame.water_label, 'RIGHT', -10, -2)
UIDropDownMenu_SetWidth(260, general_frame.water)
UIDropDownMenu_Initialize(general_frame.water, function()
	for k, v in pairs(addon.order.water) do
		local info = {}
		info.text = addon.dataTable.water[v]
		info.value = v
		info.func = function()
			UIDropDownMenu_SetSelectedValue(general_frame.water, this.value)
		end
		UIDropDownMenu_AddButton(info)
	end
end)

general_frame.trades = {}
for i, trade in pairs(addon.order.trades) do
	general_frame.trades[trade] = CreateFrame('CheckButton', general_frame:GetName()..'Trades'..trade..'Checkbox', general_frame, 'OptionsCheckButtonTemplate')
	local text = format('Trade with %s', trade)
	_G[general_frame.trades[trade]:GetName()..'Text']:SetText(L[text])
	general_frame.trades[trade]:SetWidth(26)
	general_frame.trades[trade]:SetHeight(26)
	
	if i == 1 then
		general_frame.trades[trade]:SetPoint('TOPLEFT', general_frame.water_label, 'BOTTOMLEFT', 0, -20)
		else
		general_frame.trades[trade]:SetPoint('TOPLEFT', general_frame.trades[addon.order.trades[(i-1)]], 'BOTTOMLEFT', 0, -2)
	end
end

general_frame.requests = CreateFrame('CheckButton', general_frame:GetName()..'RequestsCheckbox', general_frame, 'OptionsCheckButtonTemplate')
_G[general_frame.requests:GetName()..'Text']:SetText(L["Whisper requests"])
general_frame.requests:SetWidth(26)
general_frame.requests:SetHeight(26)
general_frame.requests:SetPoint('TOPLEFT', general_frame.trades.other, 'BOTTOMLEFT', 0, -16)

-- Class filter tab
---------------------------------------------------
container.tabs[2] = CreateFrame('Button', container:GetName()..'Tab2', container, 'OptionsFrameTabButtonTemplate')
container.tabs[2]:SetPoint('LEFT', container.tabs[1], 'RIGHT', -10, 0)
container.tabs[2]:SetText(L["Class filter"])
container.tabs[2]:SetID(2)
container.tabs[2]:SetScript('OnClick', function() container:Tab_OnClick(this) end)

container.frames[2] = CreateFrame('Frame', container:GetName()..'Frame2', container)
container.frames[2]:Hide()
container.frames[2]:SetAllPoints()
local class_filter = container.frames[2]

class_filter.classes = {}
class_filter.classes[0] = {}
class_filter.classes[0].label = class_filter:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
class_filter.classes[0].label:SetText(L["Class"])
class_filter.classes[0].label:SetJustifyH('LEFT')
class_filter.classes[0].label:SetWidth(140)
class_filter.classes[0].label:SetPoint('TOPLEFT', 30, -20)

class_filter.classes[0].food = class_filter:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
class_filter.classes[0].food:SetText(L["Food"])
local width = class_filter.classes[0].food:GetStringWidth()
class_filter.classes[0].food:SetWidth(width >= 50 and width or 50)
class_filter.classes[0].food:SetPoint('LEFT', class_filter.classes[0].label, 'RIGHT', 0, 0)

class_filter.classes[0].water = class_filter:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
class_filter.classes[0].water:SetText(L["Water"])
local width = class_filter.classes[0].water:GetStringWidth()
class_filter.classes[0].water:SetWidth(width >= 50 and width or 50)
class_filter.classes[0].water:SetPoint('LEFT', class_filter.classes[0].food, 'RIGHT', 20, 0)

for i, v in pairs(classes) do
	local class_text = upper(v)
	class_filter.classes[i] = {}
	local class = class_filter.classes[i]
	class.label = class_filter:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
	class.label:SetWidth(140)
	class.label:SetJustifyH('LEFT')
	class.label:SetText(BC[v])
	local color = RAID_CLASS_COLORS[class_text]
	class.label:SetTextColor(color.r, color.g, color.b)
	if i == 1 then
		class.label:SetPoint('TOPLEFT', class_filter.classes[(i-1)].label, 'BOTTOMLEFT', 0, -14)
		else
		class.label:SetPoint('TOPLEFT', class_filter.classes[(i-1)].label, 'BOTTOMLEFT', 0, -18)
	end
	
	local offsetX, offsetY
	if i == 1 then offsetX, offsetY = 5, -2 else offsetX, offsetY = 0, 1.6 end
	
	class.food = CreateFrame('EditBox', class_filter:GetName()..class_text..'Food', class_filter, 'InputBoxTemplate')
	class.food:SetWidth(32)
	class.food:SetHeight(32)
	class.food:SetMaxLetters(3)
	class.food:SetNumeric(true)
	class.food:SetAutoFocus(false)
	class.food:SetPoint('TOP', class_filter.classes[(i-1)].food, 'BOTTOM', offsetX, offsetY)
	class.food:SetScript('OnEditFocusGained', function()
		local self = this
		self.prev = self:GetText()
		self:HighlightText()
	end)
	class.food:SetScript('OnEscapePressed', function()
		local self = this
		self:SetText(self.prev)
		self:ClearFocus()
	end)
	class.food:SetScript('OnEnterPressed', function()
		local self = this
		class_filter:CheckAndUpdateValues(self, class, 'food')
		self:ClearFocus()
	end)
	
	class.water = CreateFrame('EditBox', class_filter:GetName()..class_text..'Water', class_filter, 'InputBoxTemplate')
	class.water:SetWidth(32)
	class.water:SetHeight(32)
	class.water:SetMaxLetters(3)
	class.water:SetNumeric(true)
	class.water:SetAutoFocus(false)
	class.water:SetPoint('TOP', class_filter.classes[(i-1)].water, 'BOTTOM', offsetX, offsetY)
	class.water:SetScript('OnEditFocusGained', function()
		local self = this
		self.prev = self:GetText()
		self:HighlightText()
	end)
	class.water:SetScript('OnEscapePressed', function()
		local self = this
		self:SetText(self.prev)
		self:ClearFocus()
	end)
	class.water:SetScript('OnEnterPressed', function()
		local self = this
		class_filter:CheckAndUpdateValues(self, class, 'water')
		self:ClearFocus()
	end)
	if class_text == 'ROGUE' or class_text == 'WARRIOR' then class.water:Hide() end
end

-- ExceptionList tab
---------------------------------------------------
container.tabs[3] = CreateFrame('Button', container:GetName()..'Tab3', container, 'OptionsFrameTabButtonTemplate')
container.tabs[3]:SetPoint('LEFT', container.tabs[2], 'RIGHT', -10, 0)
container.tabs[3]:SetText(L["Exception list"])
container.tabs[3]:SetID(3)
container.tabs[3]:SetScript('OnClick', function() container:Tab_OnClick(this) end)

container.frames[3] = CreateFrame('Frame', container:GetName()..'Frame3', container)
container.frames[3]:Hide()
container.frames[3]:SetAllPoints()
local exception_frame = container.frames[3]

exception_frame.edit = CreateFrame('EditBox', exception_frame:GetName()..'Input', exception_frame, 'InputBoxTemplate')
exception_frame.edit:SetPoint('TOPLEFT', 16, -10)
exception_frame.edit:SetPoint('TOPRIGHT', -16, -10)
exception_frame.edit:SetHeight(21)
exception_frame.edit:SetText(L["<player name>"]..' '..L["<amount of food>"]..' '..L["<amount of water>"])
exception_frame.edit:SetFontObject('GameFontDisable')
exception_frame.edit:SetAutoFocus(false)
exception_frame.edit:SetScript('OnEnter', function()
	local self = this
	GameTooltip:SetOwner(self, 'ANCHOR_TOPLEFT')
	GameTooltip:SetText(L["To add the current target, instead of the name, you can write '%t'."]..'\n\n'..L["If you want to ignore the player, then set the quantity for both items to zero."], nil, nil, nil, nil, true)
end)
exception_frame.edit:SetScript('OnLeave', function()
	GameTooltip:Hide()
end)
exception_frame.edit:SetScript('OnEditFocusGained', function()
	local self = this
	if self:GetText() == L["<player name>"]..' '..L["<amount of food>"]..' '..L["<amount of water>"] then
		self:SetFontObject('GameFontWhite')
		self:SetText('')
	end
	self:HighlightText()
	self.focus = true
end)
exception_frame.edit:SetScript('OnEditFocusLost', function()
	local self = this
	if self:GetText() == '' then
		self:SetFontObject('GameFontDisable')
		self:SetText(L["<player name>"]..' '..L["<amount of food>"]..' '..L["<amount of water>"])
	end
	self.focus = false
end)
exception_frame.edit:SetScript('OnEnterPressed', function()
	local self = this
	local text = self:GetText()
	if text == '' then
		self:ClearFocus()
	else
		exception_frame:AddPlayer(text)
	end
end)

exception_frame.sort_arrow = exception_frame:CreateTexture(exception_frame:GetName()..'SortArrow', 'ARTWORK')
exception_frame.sort_arrow:SetTexture([[Interface\Buttons\UI-SortArrow]])
exception_frame.sort_arrow:SetWidth(15)
exception_frame.sort_arrow:SetHeight(10)

exception_frame.header = {}
exception_frame.header.name = CreateFrame('Button', exception_frame:GetName()..'Header_name', exception_frame, 'WhoFrameColumnHeaderTemplate')
exception_frame.header.name:SetText(L["Player name"])
exception_frame.header.name:SetPoint('TOPLEFT', exception_frame, 'TOPLEFT', 10, -32)
exception_frame.header.name:SetScript('OnClick', function()
	exception_frame:UpdateSorting('name')
end)

exception_frame.header.food = CreateFrame('Button', exception_frame:GetName()..'Header_food', exception_frame, 'WhoFrameColumnHeaderTemplate')
exception_frame.header.food:SetText(L["Food"])
exception_frame.header.food:SetPoint('LEFT', exception_frame.header.name, 'RIGHT', 0, 0)
exception_frame.header.food:SetScript('OnClick', function()
	exception_frame:UpdateSorting('food')
end)

exception_frame.header.water = CreateFrame('Button', exception_frame:GetName()..'Header_water', exception_frame, 'WhoFrameColumnHeaderTemplate')
exception_frame.header.water:SetText(L["Water"])
exception_frame.header.water:SetPoint('LEFT', exception_frame.header.food, 'RIGHT', 0, 0)
exception_frame.header.water:SetScript('OnClick', function()
	exception_frame:UpdateSorting('water')
end)

exception_frame.btns = {}
local first_btn_offsetY = -select(5, exception_frame.header.name:GetPoint()) + exception_frame.header.name:GetHeight()
local free_height = exception_frame:GetHeight()-exception_frame.header.name:GetHeight()+select(5, exception_frame.header.name:GetPoint())
local EXCEPTIONLIST_BTN_HEIGHT = 16
local EXCEPTIONLIST_TO_DISPLAY = floor(free_height/EXCEPTIONLIST_BTN_HEIGHT)
local btns = exception_frame.btns
for i = 1, EXCEPTIONLIST_TO_DISPLAY do
	btns[i] = CreateFrame('Button', exception_frame:GetName()..'Button'..i, exception_frame)
	btns[i]:Hide()
	btns[i]:SetID(i)
	btns[i]:SetHeight(EXCEPTIONLIST_BTN_HEIGHT)
	btns[i]:SetHighlightTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]])
	btns[i]:GetHighlightTexture():SetBlendMode('ADD')
	btns[i].name = btns[i]:CreateFontString(btns[i]:GetName()..'Text', 'BORDER', 'GameFontNormal')
	btns[i].name:SetPoint('LEFT', 20, 0)
	btns[i].name:SetJustifyH('LEFT')
	btns[i].name:SetJustifyV('MIDDLE')
	btns[i].food = btns[i]:CreateFontString(btns[i]:GetName()..'Text', 'BORDER', 'GameFontNormal')
	btns[i].food:SetPoint('LEFT', btns[i].name, 'RIGHT', 0, 0)
	btns[i].food:SetJustifyH('CENTER')
	btns[i].food:SetJustifyV('MIDDLE')
	btns[i].water = btns[i]:CreateFontString(btns[i]:GetName()..'Text', 'BORDER', 'GameFontNormal')
	btns[i].water:SetPoint('LEFT', btns[i].food, 'RIGHT', 0, 0)
	btns[i].water:SetJustifyH('CENTER')
	btns[i].water:SetJustifyV('MIDDLE')
	
	if i == 1 then
		btns[i]:SetPoint('TOPLEFT', exception_frame, 'TOPLEFT', 0, -first_btn_offsetY)
		else
		btns[i]:SetPoint('TOPLEFT', btns[(i-1)], 'BOTTOMLEFT', 0, 0)
	end
	btns[i]:SetScript('OnClick', function()
		local self = this
		PlaySound('igMainMenuOptionCheckBoxOn')
		exception_frame.edit:ClearFocus()
		if not exception_frame.selected or exception_frame.selected ~= self.name:GetText() then
			exception_frame.selected = self.name:GetText()
			else
			exception_frame.selected = nil
		end
		exception_frame:UpdateSelectedButton()
	end)
	
	btns[i].delete = CreateFrame('Button', btns[i]:GetName()..'DeleteButton', btns[i])
	btns[i].delete:SetID(i)
	btns[i].delete:SetWidth(18)
	btns[i].delete:SetHeight(18)
	btns[i].delete:SetPoint('RIGHT', -5, 0)
	btns[i].delete:SetNormalTexture([[Interface\AddOns\Caterer\textures\ReadyCheck-NotReady.blp]])
	btns[i].delete:SetHighlightTexture([[Interface\AddOns\Caterer\textures\ReadyCheck-NotReady.blp]])
	btns[i].delete:GetHighlightTexture():SetBlendMode('ADD')
	btns[i].delete.normalTexture = btns[i].delete:GetNormalTexture()
	btns[i].delete:SetAlpha(.5)
	btns[i].delete.normalTexture:SetDesaturated(1)
	btns[i].delete:SetScript('OnEnter', function()
		local self = this
		GameTooltip:SetOwner(self, 'ANCHOR_TOPLEFT')
		GameTooltip:SetText(DELETE)
		
		self:SetAlpha(1)
		self.normalTexture:SetDesaturated(0)
		
		local btn = self:GetParent()
		if exception_frame.selected ~= btn.name:GetText() then btn:LockHighlight() end
	end)
	btns[i].delete:SetScript('OnLeave', function()
		local self = this
		GameTooltip:Hide()
		
		self:SetAlpha(.5)
		self.normalTexture:SetDesaturated(1)
		
		local btn = self:GetParent()
		if exception_frame.selected ~= btn.name:GetText() then btn:UnlockHighlight() end
	end)
	btns[i].delete:SetScript('OnClick', function()
		local self = this
		local btn = self:GetParent()
		exception_frame:RemovePlayer(btn.data.name)
		if exception_frame.selected ~= btn.name:GetText() then btn:LockHighlight() end -- update highlight
	end)
end

exception_frame.scroll = CreateFrame('ScrollFrame', exception_frame:GetName()..'ScrollFrame', exception_frame, 'FauxScrollFrameTemplate')
exception_frame.scroll:SetPoint('TOPLEFT', btns[1], 0, 0)
exception_frame.scroll:SetPoint('BOTTOMRIGHT', btns[getn(btns)], -2, 0)
exception_frame.scroll:SetScript('OnShow', function()
	exception_frame:UpdateTextAreaWidth(26)
end)
exception_frame.scroll:SetScript('OnHide', function()
	exception_frame:UpdateTextAreaWidth(0)
end)
exception_frame.scroll:SetScript('OnVerticalScroll', function()
	FauxScrollFrame_OnVerticalScroll(EXCEPTIONLIST_BTN_HEIGHT, exception_frame.UpdateList)
end)

-- Functions
---------------------------------------------------
local s2 = sqrt(2)
local function CalculateCorner(angle)
  local r = rad(angle)
	local x, y = .5+cos(r)/s2, .5+sin(r)/s2
  return x, y
end

local function RotateTexture(texture, angle)
  local LRx, LRy = CalculateCorner(angle + 45)  -- 0 + 45
  local LLx, LLy = CalculateCorner(angle + 135) -- 90 + 45
  local ULx, ULy = CalculateCorner(angle + 225) -- 180 + 45
  local URx, URy = CalculateCorner(angle + 315) -- 270 + 45

  texture:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
end

local function CopyTable(t)
	local r_t = {}
	for k, v in pairs(t) do
		if type(v) == 'table' then
			v = CopyTable(v)
		end
		r_t[k] = v
	end
	return r_t
end

local function GetIterateKeyTable(t)
	local r_t = {}
	for k, v in pairs(t) do
		r_t[getn(r_t)+1] = {name = k, food = v.food, water = v.water}
	end
	return r_t
end

local function SortTable(t)
	local sort_type1, sort_type2 = exception_frame.sorting[1], exception_frame.sorting[2]
	local function sort1(a, b) return a[sort_type2] < b[sort_type2] end
	local function sort2(a, b) return a[sort_type2] > b[sort_type2] end

	tsort(t, sort_type1 == '<' and sort1 or sort2)
	return t
end

function container:Tab_OnClick(self)
	PlaySound('igCharacterInfoTab')
	container.frames[container.selectedTab]:Hide()
	PanelTemplates_Tab_OnClick(container) -- update selectedTab
	container.frames[container.selectedTab]:Show()
	
	container.Spacer1:SetPoint('BOTTOMRIGHT', container.tabs[container.selectedTab], 'BOTTOMLEFT', 11, -7)
	container.Spacer2:SetPoint('BOTTOMLEFT', container.tabs[container.selectedTab], 'BOTTOMRIGHT', -9, -7)
end

function class_filter:CheckAndUpdateValues(self, class, type)
	local food = tonumber(class.food:GetText())
	local water = tonumber(class.water:GetText())
	if not food or not water then
		self:SetText(self.prev)
		elseif fmod(food, 20) ~= 0 or fmod(water, 20) ~= 0 then
		self:SetText(self.prev)
		return print(L["The numbers must be a multiple of 20."])
		elseif food > 120 or water > 120 then
		-- if one of them is more than 120, then cannot be EQUALIZE!
		self:SetText(self.prev)
		return print(L["The total number of items should not exceed 120."])
		elseif food + water > 120 then
		-- EQUALIZE the values ​​so that the total is 120!
		if type == 'food' then
			class.water:SetText(120 - food)
			elseif type == 'water' then
			class.food:SetText(120 - water)
		end
	end
end

function exception_frame:UpdateTextAreaWidth(shift)
	local btn_width = self:GetWidth() - shift
	local header_name_offsetX = select(4, self.header.name:GetPoint())
	local btn_delete_offsetX = -select(4, btns[1].delete:GetPoint())*2 + btns[1].delete:GetWidth()
	local btn_width_for_data = btn_width - btn_delete_offsetX
	WhoFrameColumn_SetWidth(btn_width_for_data*2/3 - header_name_offsetX, self.header.name)
	WhoFrameColumn_SetWidth(btn_width_for_data*1/6, self.header.food)
	WhoFrameColumn_SetWidth(btn_width_for_data*1/6, self.header.water)
	for i = 1, EXCEPTIONLIST_TO_DISPLAY do
		btns[i]:SetWidth(btn_width)
		btns[i].name:SetWidth(self.header.name:GetWidth() - header_name_offsetX)
		btns[i].food:SetWidth(self.header.food:GetWidth())
		btns[i].water:SetWidth(self.header.water:GetWidth())
	end
end

function exception_frame:UpdateSortArrow()	
	local sort_1, sort_2 = exception_frame.sorting[1], exception_frame.sorting[2]
	local texture = self.sort_arrow
	if sort_1 == '>' then
		RotateTexture(texture, 180)
		texture:SetPoint('LEFT', self.header[sort_2]:GetFontString(), 'RIGHT', -3, 0)
	else
		RotateTexture(texture, 0)
		texture:SetPoint('LEFT', self.header[sort_2]:GetFontString(), 'RIGHT', 3, -2)
	end
end

function exception_frame:UpdateSorting(SortBy)
	exception_frame.sorting[1] = exception_frame.sorting[2] == SortBy and exception_frame.sorting[1] == '<' and '>' or '<'
	exception_frame.sorting[2] = SortBy
	
	exception_frame:UpdateSortArrow()
	exception_frame:UpdateList(true)
end

function exception_frame:UpdateSelectedButton()
	local btns = self.btns
	
	for i=1, EXCEPTIONLIST_TO_DISPLAY do
		if not btns[i].index then break end
		btns[i]:UnlockHighlight()
		if self.selected and self.selected == btns[i].name:GetText() then
			btns[i]:LockHighlight()
		end
	end
end

function exception_frame:UpdateList(list_changed)
	if list_changed then
		local list = exception_frame.exceptionList                     -- ['name'] = {food = #, water = #}
		local iterate_list = GetIterateKeyTable(list)                  -- [iter] = {name = 'name', food = #, water = #}
		exception_frame.sorted_exceptionList = SortTable(iterate_list) -- SORTED: [iter] = {name = 'name', food = #, water = #}
	end
	
	local sorted_list = exception_frame.sorted_exceptionList
	local offset = FauxScrollFrame_GetOffset(exception_frame.scroll)
	local num_exceptions = getn(sorted_list)
	local btns = exception_frame.btns
	local index

	for i=1, EXCEPTIONLIST_TO_DISPLAY do
		index = i + offset
		if index <= num_exceptions then
			btns[i].index = index
			btns[i].data = {}
			btns[i].data.name = sorted_list[index].name
			btns[i].data.food = sorted_list[index].food
			btns[i].data.water = sorted_list[index].water
			
			btns[i].name:SetText(addon:FirstToUpper(btns[i].data.name))
			btns[i].food:SetText(btns[i].data.food)
			btns[i].water:SetText(btns[i].data.water)
			
			if btns[i].data.food == 0 and btns[i].data.water == 0 then
				btns[i].food:SetTextColor(1, 0, 0)
				btns[i].water:SetTextColor(1, 0, 0)
			else
				btns[i].food:SetTextColor(1, .82, 0)
				btns[i].water:SetTextColor(1, .82, 0)
			end
			
			btns[i]:Show()
			else
			btns[i]:Hide()
		end
	end
	exception_frame:UpdateSelectedButton()
	
	if list_changed then
		FauxScrollFrame_Update(exception_frame.scroll, num_exceptions, EXCEPTIONLIST_TO_DISPLAY, EXCEPTIONLIST_BTN_HEIGHT)
	end
end

function exception_frame:AddPlayer(str)
	local name, food, water = match(str, '([^%s]+) (%d+) (%d+)$')
	if name == '%t' then name = UnitName('target') end
	food, water = tonumber(food), tonumber(water)
	
	if not (name and food and water) or fmod(food, 20) ~= 0 or fmod(water, 20) ~= 0 then
		return print(L["Expected string"]..': '..L["<player name>"]..' '..L["<amount of food>"]..' '..L["<amount of water>"]..'. '..L["Note"]..': '..L["The numbers must be a multiple of 20."])
		elseif food + water > 120 then
		return print(L["The total number of items should not exceed 120."])
	end
	
	name = lower(name)
	local type
	if self.exceptionList[name] then
		type = '|cffDAA520'..L["edited"]..'|r'
		else
		type = '|cff00FF00'..L["added"]..'|r'
	end
	
	self.exceptionList[name] = {['food'] = food, ['water'] = water}
	local color_name = food+water == 0 and 'CD5C5C' or 'bfffff'
	print(format(L["Player <%s> was successfully %s."], '|cff'..color_name..addon:FirstToUpper(name)..'|r', type))
	self.edit:SetText('')
	self.edit:ClearFocus()
	self:UpdateList(true)
end

function exception_frame:RemovePlayer(name)
	name = lower(name)
	
	self.exceptionList[name] = nil
	if self.selected and lower(self.selected) == name then
		self.selected = nil
	end

	print(format(L["Player <%s> was successfully %s."], '|cffbfffff'..addon:FirstToUpper(name)..'|r', '|cffFF0000'..L["removed"]..'|r'))
	self:UpdateList(true)
end

function general_frame.enabled.setFunc(state)
	if state == true or state == '1' or state == 1 then
		for i = 2, getn(container.tabs) do
			PanelTemplates_EnableTab(container, i)
		end
		_G[general_frame.food:GetName()..'Button']:Enable()
		general_frame.food_label:SetFontObject('GameFontNormal')
		_G[general_frame.water:GetName()..'Button']:Enable()
		general_frame.water_label:SetFontObject('GameFontNormal')
		for _, trade in pairs(addon.order.trades) do
			general_frame.trades[trade]:Enable()
			_G[general_frame.trades[trade]:GetName()..'Text']:SetFontObject('GameFontNormalSmall')
		end
		general_frame.requests:Enable()
		_G[general_frame.requests:GetName()..'Text']:SetFontObject('GameFontNormalSmall')
		
		else
		
		for i = 2, getn(container.tabs) do
			PanelTemplates_DisableTab(container, i)
		end
		_G[general_frame.food:GetName()..'Button']:Disable()
		general_frame.food_label:SetFontObject('GameFontDisable')
		_G[general_frame.water:GetName()..'Button']:Disable()
		general_frame.water_label:SetFontObject('GameFontDisable')
		for _, trade in pairs(addon.order.trades) do
			general_frame.trades[trade]:Disable()
			_G[general_frame.trades[trade]:GetName()..'Text']:SetFontObject('GameFontDisableSmall')
		end
		general_frame.requests:Disable()
		_G[general_frame.requests:GetName()..'Text']:SetFontObject('GameFontDisableSmall')
	end
end

function config:UpdateConfig()
	general_frame.enabled:SetChecked(CatererDB.enabled)
	UIDropDownMenu_SetSelectedValue(general_frame.food, CatererDB.tradeWhat.food)
	UIDropDownMenu_SetText(addon.dataTable.food[CatererDB.tradeWhat.food], general_frame.food)
	UIDropDownMenu_SetSelectedValue(general_frame.water, CatererDB.tradeWhat.water)
	UIDropDownMenu_SetText(addon.dataTable.water[CatererDB.tradeWhat.water], general_frame.water)
	general_frame.trades.friends:SetChecked(CatererDB.tradeFilter.friends)
	general_frame.trades.group:SetChecked(CatererDB.tradeFilter.group)
	general_frame.trades.guild:SetChecked(CatererDB.tradeFilter.guild)
	general_frame.trades.other:SetChecked(CatererDB.tradeFilter.other)
	general_frame.requests:SetChecked(CatererDB.whisperRequest)
	
	for i, class in pairs(classes) do
		class_filter.classes[i].food:SetText(CatererDB.tradeCount[upper(class)].food)
		class_filter.classes[i].water:SetText(CatererDB.tradeCount[upper(class)].water)
	end
	exception_frame.sorting = {CatererDB.exceptionList_sort[1], CatererDB.exceptionList_sort[2]}
	exception_frame.exceptionList = CopyTable(CatererDB.exceptionList)
	exception_frame:UpdateSorting(exception_frame.sorting[2])
end

function config:SetDefaultSettings()
	CatererDB = addon.defaults
	print(L["All settings are reset to default values."])
	self:UpdateConfig()
end

function config:SaveChanges()
	if general_frame.enabled:GetChecked() then
		CatererDB.enabled = true
		Caterer:OnEnable()
		else
		CatererDB.enabled = false
		Caterer:OnDisable()
	end
	CatererDB.tradeWhat.food = UIDropDownMenu_GetSelectedValue(general_frame.food)
	CatererDB.tradeWhat.water = UIDropDownMenu_GetSelectedValue(general_frame.water)
	CatererDB.tradeFilter.friends = general_frame.trades.friends:GetChecked()
	CatererDB.tradeFilter.group = general_frame.trades.group:GetChecked()
	CatererDB.tradeFilter.guild = general_frame.trades.guild:GetChecked()
	CatererDB.tradeFilter.other = general_frame.trades.other:GetChecked()
	CatererDB.whisperRequest = general_frame.requests:GetChecked()
	
	for i, class in pairs(classes) do
		CatererDB.tradeCount[upper(class)].food = tonumber(class_filter.classes[i].food:GetText())
		CatererDB.tradeCount[upper(class)].water = tonumber(class_filter.classes[i].water:GetText())
	end
	
	CatererDB.exceptionList_sort = {exception_frame.sorting[1], exception_frame.sorting[2]}
	CatererDB.exceptionList = CopyTable(exception_frame.exceptionList)
end

function config:CancelChanges()
	self:UpdateConfig()
end

-- Hooks
---------------------------------------------------
local orig_SendWho = SendWho
function SendWho(str)
	if exception_frame.edit.focus and exception_frame.edit:GetText() == '' then
		local name = match(str, '-(.+)-?')
		exception_frame.edit:Insert(name)
	else
		orig_SendWho(str)
	end
end

-- OnLoad
---------------------------------------------------
PanelTemplates_SetNumTabs(container, getn(container.tabs))
PanelTemplates_SetTab(container, 1)
container.Spacer1:SetPoint('BOTTOMRIGHT', container.tabs[container.selectedTab], 'BOTTOMLEFT', 11, -7)
container.Spacer2:SetPoint('BOTTOMLEFT', container.tabs[container.selectedTab], 'BOTTOMRIGHT', -9, -7)
exception_frame:UpdateTextAreaWidth(0)

config.name = addon_name
config.default = function() config:SetDefaultSettings() end
config.okay = function() config:SaveChanges() end
config.cancel = function() config:CancelChanges() end

SLASH_CATERER1 = '/caterer'
function SlashCmdList.CATERER()
	config:Show()
end





function addon:Test(quantity, ignore_probability)
	local random = math.random
	local n = quantity or random(20,50)
	local ignore_probability = ignore_probability or 20
	local values = {0, 20, 40, 60, 80, 100, 120}
	local chars = {'a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z'}
	for i = 1, n do
		local ignore
		if ignore_probability > 0 then
			local roll = random(1,100)
			ignore = roll <= ignore_probability and true
		end
		
		local name = ''
		local length = random(3,12)
		for i = 1, length do
			name = name..chars[random(1,26)]
		end
		local food, water = 0, 0
		if not ignore then
			food = values[random(1,7)]
			water = 120 - food
		end
		exception_frame:AddPlayer(name..' '..food..' '..water)
	end
end



-- HARD FIX
---------------------------------------------------

-- Function to handle the update of manually calculated scrollframes.  Used mostly for listings with an indeterminate number of items
function _G.FauxScrollFrame_Update(frame, numItems, numToDisplay, valueStep, button, smallWidth, bigWidth, highlightFrame, smallHighlightWidth, bigHighlightWidth )
	-- If more than one screen full of skills then show the scrollbar
	local frameName = frame:GetName();
	local scrollBar = _G[ frameName..'ScrollBar' ];
	local showScrollBar;
	if ( numItems > numToDisplay ) then
		frame:Show();
		showScrollBar = 1;
		else
		scrollBar:SetValue(0);
		frame:Hide();
	end
	if ( frame:IsShown() ) then  -- BUG FIX: for correct work must be IsShown, NOT IsVisible!
		local scrollChildFrame = _G[ frameName..'ScrollChildFrame' ];
		local scrollUpButton = _G[ frameName..'ScrollBarScrollUpButton' ];
		local scrollDownButton = _G[ frameName..'ScrollBarScrollDownButton' ];
		local scrollFrameHeight = 0;
		local scrollChildHeight = 0;
		
		if ( numItems > 0 ) then
			scrollFrameHeight = (numItems - numToDisplay) * valueStep;
			scrollChildHeight = numItems * valueStep;
			if ( scrollFrameHeight < 0 ) then
				scrollFrameHeight = 0;
			end
			scrollChildFrame:Show();
			else
			scrollChildFrame:Hide();
		end
		scrollBar:SetMinMaxValues(0, scrollFrameHeight); 
		scrollBar:SetValueStep(valueStep);
		scrollChildFrame:SetHeight(scrollChildHeight);
		
		-- Arrow button handling
		if ( scrollBar:GetValue() == 0 ) then
			scrollUpButton:Disable();
			else
			scrollUpButton:Enable();
		end
		if ((scrollBar:GetValue() - scrollFrameHeight) == 0) then
			scrollDownButton:Disable();
			else
			scrollDownButton:Enable();
		end
		
		-- Shrink because scrollbar is shown
		if ( highlightFrame ) then
			highlightFrame:SetWidth(smallHighlightWidth);
		end
		if ( button ) then
			for i=1, numToDisplay do
				_G[button..i]:SetWidth(smallWidth);
			end
		end
		else
		-- Widen because scrollbar is hidden
		if ( highlightFrame ) then
			highlightFrame:SetWidth(bigHighlightWidth);
		end
		if ( button ) then
			for i=1, numToDisplay do
				_G[button..i]:SetWidth(bigWidth);
			end
		end
	end
	return showScrollBar;
end
