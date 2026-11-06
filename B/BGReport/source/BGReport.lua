BINDING_HEADER_BGREPORT = "BGReport";
BINDING_NAME_BGREPORT1 = "Toggle menu";

-- do NOT localize those!
local BATTLEGROUND_ID = {
	['Warsong Gulch'] = 1,
	['Arathi Basin'] = 2,
	['Alterac Valley'] = 3
}

-- those are okay to localize if needed
local BATTLEGROUND_NAME = {
	[1] = 'Warsong Gulch',
	[2] = 'Arathi Basin',
	[3] = 'Alterac Valley'
}

local BUTTON_LABELS = {
	[BATTLEGROUND_ID['Warsong Gulch']] = {
		[0] = {
			'East',
			'...',
			'West',
			'...'
		},
		[1] = {
			'efr',
			'etun',
			'eroof',
			'ebalc',
			'egy',
			'efence',
			'eramp'
		},
		[2] = {
			'fr',
			'gy',
			'fence',
			'ramp',
			'balc',
			'roof',
			'tun'
		}
	},
	[BATTLEGROUND_ID['Arathi Basin']] = {
		[0] = {
			'Gold Mine',
			'Stables',
			'Lumber Mill',
			'Farm'
		},
		[1] = {
			'2',
			'1',
			'5',
			'3'
		},
		[2] = {
			'2',
			'1',
			'5',
			'3'
		},
		[3] = {
			'2',
			'1',
			'5',
			'3'
		},
		[4] = {
			'2',
			'1',
			'5',
			'3'
		},
		[5] = {
			'2',
			'1',
			'5',
			'3'
		}
	},
	[BATTLEGROUND_ID['Alterac Valley']] = {
		[0] = {
			'Iceblood',
			'Dun Baldar',
			'Stonehearth',
			'Frostwolf'
		},
		[1] = {
			'Tower Point',
			'IB Graveyard',
			'IB Tower'
		},
		[2] = {
			'SP GY',
			'North Bunker',
			'Aid Station',
			'South Bunker'
		},
		[3] = {
			'SH Bunker',
			'IW Bunker',
			'SH GY'	
		},
		[4] = {
			'East Tower',
			'Graveyard',
			'West Tower',
			'Relief Hut'
		}
	}
}
--[[
local BUTTONS = {
	[3] = { -- av
		[1] = {
			'buttons' = 4,
			'order' = 1,
		}
	}
}]]

--
-- credit to Dreyruugr (dreyruugr@gmail.com)
-- for vector lib
--
local Vector2D = {}
Vector2D.__index = Vector2D

function Vector2D:new(x, y)
	local vec = {}
	setmetatable(vec, Vector2D)
	vec.x = x
	vec.y = y
	vec.length = nil
	return vec
end

function Vector2D:Set(x, y)
	self.x = x
	self.y = y
	self.length = nil
end

function Vector2D:Add(other)
	self.x = self.x + other.x
	self.y = self.y + other.y
end

function Vector2D:GetLength()
	if ( self.length == nil ) then
		self.length = sqrt( (self.x * self.x) + (self.y * self.y) )
	end
	return self.length
end

function Vector2D:Normalize()
	if ( self:GetLength() == 0 ) then
		self.x = 0
		self.y = 0
		self.length = 0
		return
	end
	
	self.x = self.x / self:GetLength()
	self.y = self.y / self:GetLength()
	self.length = 1
end

function Vector2D:GetAngle()
	local angle = atan2( self.y, self.x )
	if ( angle < 0 ) then
		angle = 360 + angle
	end
	return angle
end



local BlankItem = {}
BlankItem.__index = BlankItem

function BlankItem:new()
	local item = {}
	setmetatable(item, BlankItem)
	return item
end

function BlankItem:GetID()
	return 0
end

function BlankItem:GetTexture()
	return ''
end

function BlankItem:GetLabel()
	return ''
end

function BlankItem:IsEnabled()
	return false
end



local Item = {}
Item.__index = Item

function Item:new(id)
	local item = {}
	item.texture = nil
	item.id = id or 0
	setmetatable(item, Item)
	return item
end

function Item:GetID()
	return self.id
end

function Item:SetID(id)
	self.id = id
	return self
end

function Item:SetTexture(path)
	self.texture = path
	return self
end

function Item:GetTexture()
	return self.texture
end

function Item:IsEnabled()
	return true
end

function Item:SetMacro(body)
	self.macro = body
	return self
end

function Item:GetMacro()
	return self.macro
end

function Item:SetScript(body, args)
	self.script = body
	self.scriptArgs = args
	return self
end

function Item:GetScript()
	return self.script
end

function Item:GetLabel()
	return self.label
end

function Item:SetLabel(text)
	self.label = text
	return self
end

function Item:SetTexCoord(left, right, top, bottom)
	self.texCoord = {left, right, top, bottom}
	return self
end

function Item:GetTexCoord()
	if ( self.texCoord ) then
		return unpack(self.texCoord)
	else
		return 0, 1, 0, 1
	end
end


local function splitStringBy(str, pat)
   local t = {n = 0}
   local fpat = "(.-)"..pat
   local last_end = 1
   local s,e,cap = string.find(str, fpat, 1)
   while s ~= nil do
      if s~=1 or cap~="" then
	 table.insert(t,cap)
      end
      last_end = e+1
      s,e,cap = string.find(str, fpat, last_end)
   end
   if last_end<=string.len(str) then
      cap = string.sub(str,last_end)
      table.insert(t,cap)
   end
   return t
end

local function splitMacroBody( str )
	local bodyLines = splitStringBy(str,'[\n]+')
	return bodyLines
end

local function splitScriptBody( str )
	str = string.gsub( str, "/", " /")
	str = string.gsub( str, "\" /", "\"/" )
	local bodyLines = splitStringBy( str,' /+')
	return bodyLines
end


local bgr = {}
local lineVec = Vector2D:new(0, 0)

bgr.StartPos = Vector2D:new(UIParent:GetWidth()/2, UIParent:GetHeight()/2)
bgr.EndPos = Vector2D:new(0, 0)
bgr.slotOwners = {}
bgr.Items = {}
bgr.ItemsSpecial = {}
bgr.frames = {}
bgr.activeItem = nil
bgr.isMarking = false

bgr.maxItems = 8
bgr.divider = 22.5

bgr.__tostring = function()
	return 'instance of <BGReport>'
end
setmetatable(bgr, bgr)

function bgr:SetDivider(num)
	self.divider = num
	return self
end

function bgr:GetDivider()
	return self.divider
end

function bgr:SetStartAngle(num)
	self.startAngle = num
	return self
end

function bgr:GetStartAngle()
	return self.startAngle or 0
end

function bgr:SetMaxItemCount(num)
	self.maxItems = num
	return
end

function bgr:GetMaxItemCount()
	return self.maxItems
end

function bgr:ResetItems()
	-- free frames used for radial buttons
	for index, value in ipairs(self.Items) do
		if ( self.Items[index] and self.Items[index].frame ) then
			self.Items[index].frame.isDirty = true
			self:DestroyFrames(self.Items[index].frame)
		end
	end
	
	-- free frame used for middle button
	if ( self.ItemsSpecial and self.ItemsSpecial[1] and self.ItemsSpecial[1].frame ) then
		self.ItemsSpecial[1].frame.isDirty = true
		self:DestroyFrames(self.ItemsSpecial[1].frame)
	end
	
	-- reset all items
	self.Items = {}
	for i = 1, self:GetMaxItemCount(), 1 do
		self.Items[i] = BlankItem:new()
	end
end

function bgr:MakeItems()
	self:ResetItems()
	self.ItemsSpecial[1] = Item:new():SetTexture([[Interface\AddOns\BGReport\textures\dot-active]])
end

local uid = 0
function bgr:GetFrame(reason)
	local frame
	
	for index, value in ipairs(self.frames) do
		if ( self.frames[index].isDirty ) then
			frame = self.frames[index]
			frame.isDirty = false
			break
		end
	end
	
	if ( frame ) then
		return frame
	else
		--DEFAULT_CHAT_FRAME:AddMessage('<BGReport> Creating BGReportFrame'..uid..' due to '..reason, 38/255, 115/255, 191/255)
		frame = CreateFrame('Frame', 'BGReportFrame'..uid, self.gui.frame)
		frame:SetAllPoints()
		frame.isDirty = false
		uid = uid + 1
		table.insert(self.frames, frame)
		return frame
	end
end

function bgr:DestroyFrames(frame)
	if ( frame and frame.isDirty ) then
		frame:Hide()
	else
		for index, value in ipairs(self.frames) do
			if ( self.frames[i].isDirty ) then
				self.frames[i]:Hide() 
			end
		end
	end
end

function bgr:InBattleground()
	local zone = GetRealZoneText()

	if ( zone == BATTLEGROUND_NAME[ BATTLEGROUND_ID['Alterac Valley'] ] ) then
		return BATTLEGROUND_ID['Alterac Valley']
	elseif ( zone == BATTLEGROUND_NAME[ BATTLEGROUND_ID['Arathi Basin'] ] ) then
		return BATTLEGROUND_ID['Arathi Basin']
	elseif ( zone == BATTLEGROUND_NAME[ BATTLEGROUND_ID['Warsong Gulch'] ] ) then
		return BATTLEGROUND_ID['Warsong Gulch']
	end
	
	return 0
end

function bgr:UpdateLabel(item, x, y)
	item.frame = self:GetFrame(item:GetLabel())
	if ( not item.frame.label ) then
		item.frame.label = item.frame:CreateFontString()
		item.frame.label:SetFontObject(ZoneTextFont)
	end

	item.frame.label:SetPoint('CENTER', x or 0, y or 0)
	item.frame.label:SetText(item:GetLabel())
	item.frame:Show()
end

function bgr:GetConfiguration()
	return self.configuration, self.configurationLevel
end

function bgr:SetConfiguration(configuration, level)
	self.configuration = configuration
	self.configurationLevel = level
	
	self:ResetItems()
	local itemOffset = self:GetSelectionRadius() - self:GetDeadzone() + (self:GetDeadzone() / 3)
	
	if configuration == 'wsg' then
		if level then
			if level == 1 then
				-- alliance side, north
				self:SetDivider(25.7142)
				self:SetStartAngle(-12.9)
				self:SetMaxItemCount(7)
				
				local macros = {
					'/bg efc efr',
					'/bg efc etun',
					'/bg efc eroof',
					'/bg efc ebalc',
					'/bg efc egy',
					'/bg efc efence',
					'/bg efc eramp'
				}
				local buttonAngle = self:GetStartAngle()
				local x, y
				x = 0;
				y = 0;
				
				self.gui.frame.texture:SetTexture([[Interface\AddOns\BGReport\textures\7]])
				self.gui.frame.texture:SetTexCoord(0, 1, 0, 1)
				
				for index = 1, 7 do
					self.Items[index] = Item:new(index)
					self.Items[index]:SetMacro(macros[index])
					self.Items[index]:SetLabel(BUTTON_LABELS[BATTLEGROUND_ID['Warsong Gulch']][level][index])
					self.Items[index]:SetTexture('Interface\\AddOns\\BGReport\\textures\\7-'..index)
					self.Items[index]:SetTexCoord(0, 1, 0, 1)
					
					if ( self.Items[index]:GetLabel() ~= '' ) then
						self:UpdateLabel(self.Items[index], x + (itemOffset * cos(-buttonAngle)), y + (itemOffset * sin(-buttonAngle)) )
						buttonAngle = buttonAngle - (360 / 7)
					end
				end
				
				self.ItemsSpecial[1] = Item:new()
				self.ItemsSpecial[1]:SetTexture([[Interface\AddOns\BGReport\textures\dot-active]])
				self.ItemsSpecial[1]:SetScript('self:SetConfiguration("wsg")')
				self.ItemsSpecial[1]:SetLabel('...')
				self:UpdateLabel(self.ItemsSpecial[1], 0, 0)
				
			elseif level == 2 then
				-- horde side, south
				self:SetDivider(25.7142)
				self:SetStartAngle(12.9)
				self:SetMaxItemCount(7)
				
				local macros = {
					'/bg efc fr',
					'/bg efc gy',
					'/bg efc fence',
					'/bg efc ramp',
					'/bg efc balc',
					'/bg efc roof',
					'/bg efc tun'
				}
				local buttonAngle = self:GetStartAngle()
				local x, y
				x = 0;
				y = 0;
				
				self.gui.frame.texture:SetTexture([[Interface\AddOns\BGReport\textures\7]])
				self.gui.frame.texture:SetTexCoord(0, 1, 1, 0)

				-- reverse order and shift by 1
				local textureIndex = 2

				for index = 1, 7 do
					textureIndex = textureIndex - 1
					if ( textureIndex == 0 ) then
						textureIndex = 7
					end
					
					self.Items[index] = Item:new(index)
					self.Items[index]:SetMacro(macros[index])
					self.Items[index]:SetLabel(BUTTON_LABELS[BATTLEGROUND_ID['Warsong Gulch']][level][index])
					self.Items[index]:SetTexture('Interface\\AddOns\\BGReport\\textures\\7-'..textureIndex)
					self.Items[index]:SetTexCoord(0, 1, 1, 0)
					
					if ( self.Items[index]:GetLabel() ~= '' ) then
						self:UpdateLabel(self.Items[index], x + (itemOffset * cos(-buttonAngle)), y + (itemOffset * sin(-buttonAngle)) )
						buttonAngle = buttonAngle - (360 / 7)
					end
				end

				self.ItemsSpecial[1] = Item:new()
				self.ItemsSpecial[1]:SetTexture([[Interface\AddOns\BGReport\textures\dot-active]])
				self.ItemsSpecial[1]:SetScript('self:SetConfiguration("wsg")')
				self.ItemsSpecial[1]:SetLabel('...')
				self:UpdateLabel(self.ItemsSpecial[1], 0, 0)
			end
		else
			-- main wsg menu
			bgr:SetDivider(45)
			bgr:SetStartAngle(0)
			bgr:SetMaxItemCount(4)
			
			local macros = {
				'/bg efc east',
				'<placeholder>',
				'/bg efc west',
				'<placeholder>'
			}
			local buttonAngle = self:GetStartAngle()
			local level = 0
			local x, y;
			x = 0;
			y = 0;
			
			self.gui.frame.texture:SetTexture([[Interface\AddOns\BGReport\textures\4]])
			self.gui.frame.texture:SetTexCoord(0, 1, 0, 1)

			for index = 1, 4 do
				
				self.Items[index] = Item:new(index)
				self.Items[index]:SetLabel(BUTTON_LABELS[BATTLEGROUND_ID['Warsong Gulch']][level][index])
				self.Items[index]:SetTexture('Interface\\AddOns\\BGReport\\textures\\4-'..index)
				self.Items[index]:SetTexCoord(0, 1, 0, 1)
				
				if ( index == 1 or index == 3 ) then
					self.Items[index]:SetMacro(macros[index])
				elseif ( index == 2 ) then
					self.Items[index]:SetScript('self:SetConfiguration("wsg", 1)')
				elseif ( index == 4 ) then
					self.Items[index]:SetScript('self:SetConfiguration("wsg", 2)')
				end
				
				if ( self.Items[index]:GetLabel() ~= '' ) then
					self:UpdateLabel(self.Items[index], x + (itemOffset * cos(-buttonAngle)), y + (itemOffset * sin(-buttonAngle)) )
					buttonAngle = buttonAngle - (360 / 4)
				end
			end

			self.ItemsSpecial[1] = Item:new()
			self.ItemsSpecial[1]:SetTexture([[Interface\AddOns\BGReport\textures\dot-active]])
			self.ItemsSpecial[1]:SetMacro('/bg efc mid')
			self.ItemsSpecial[1]:SetLabel('mid')
			self:UpdateLabel(self.ItemsSpecial[1], 0, 0)
			
		end
	elseif configuration == 'ab' then
		if level then
			if level == 1 then
				bgr:SetDivider(45)
				bgr:SetStartAngle(0)
				bgr:SetMaxItemCount(4)
				
				local macros = {
					'/bg gm 2',
					'/bg gm 1',
					'/bg gm 5',
					'/bg gm 3',
				}
				
				local buttonAngle = self:GetStartAngle()
				local x, y;
				x = 0;
				y = 0;
				
				self.gui.frame.texture:SetTexture([[Interface\AddOns\BGReport\textures\4]])
				self.gui.frame.texture:SetTexCoord(0, 1, 0, 1)
				
				for index = 1, 4 do
					self.Items[index] = Item:new(index)
					self.Items[index]:SetMacro(macros[index])
					self.Items[index]:SetLabel(BUTTON_LABELS[BATTLEGROUND_ID['Arathi Basin']][level][index])
					self.Items[index]:SetTexture('Interface\\AddOns\\BGReport\\textures\\4-'..index)
					self.Items[index]:SetTexCoord(0, 1, 0, 1)
					
					if ( self.Items[index]:GetLabel() ~= '' ) then
						self:UpdateLabel(self.Items[index], x + (itemOffset * cos(-buttonAngle)), y + (itemOffset * sin(-buttonAngle)) )
						buttonAngle = buttonAngle - (360 / 4)
					end
				end

				self.ItemsSpecial[1] = Item:new()
				self.ItemsSpecial[1]:SetTexture([[Interface\AddOns\BGReport\textures\dot-active]])
				self.ItemsSpecial[1]:SetLabel('...')
				self.ItemsSpecial[1]:SetScript('self:SetConfiguration("ab")')
				self:UpdateLabel(self.ItemsSpecial[1], 0, 0)
			elseif level == 2 then
				bgr:SetDivider(45)
				bgr:SetStartAngle(0)
				bgr:SetMaxItemCount(4)
				
				local macros = {
					'/bg st 2',
					'/bg st 1',
					'/bg st 5',
					'/bg st 3',
				}
				
				local buttonAngle = self:GetStartAngle()
				local x, y;
				x = 0;
				y = 0;
				
				self.gui.frame.texture:SetTexture([[Interface\AddOns\BGReport\textures\4]])
				self.gui.frame.texture:SetTexCoord(0, 1, 0, 1)
				
				for index = 1, 4 do
					self.Items[index] = Item:new(index)
					self.Items[index]:SetMacro(macros[index])
					self.Items[index]:SetLabel(BUTTON_LABELS[BATTLEGROUND_ID['Arathi Basin']][level][index])
					self.Items[index]:SetTexture('Interface\\AddOns\\BGReport\\textures\\4-'..index)
					self.Items[index]:SetTexCoord(0, 1, 0, 1)
					
					if ( self.Items[index]:GetLabel() ~= '' ) then
						self:UpdateLabel(self.Items[index], x + (itemOffset * cos(-buttonAngle)), y + (itemOffset * sin(-buttonAngle)) )
						buttonAngle = buttonAngle - (360 / 4)
					end
				end

				self.ItemsSpecial[1] = Item:new()
				self.ItemsSpecial[1]:SetTexture([[Interface\AddOns\BGReport\textures\dot-active]])
				self.ItemsSpecial[1]:SetLabel('...')
				self.ItemsSpecial[1]:SetScript('self:SetConfiguration("ab")')
				self:UpdateLabel(self.ItemsSpecial[1], 0, 0)
			elseif level == 3 then
				bgr:SetDivider(45)
				bgr:SetStartAngle(0)
				bgr:SetMaxItemCount(4)
				
				local macros = {
					'/bg lm 2',
					'/bg lm 1',
					'/bg lm 5',
					'/bg lm 3',
				}
				
				local buttonAngle = self:GetStartAngle()
				local x, y;
				x = 0;
				y = 0;
				
				self.gui.frame.texture:SetTexture([[Interface\AddOns\BGReport\textures\4]])
				self.gui.frame.texture:SetTexCoord(0, 1, 0, 1)
				
				for index = 1, 4 do
					self.Items[index] = Item:new(index)
					self.Items[index]:SetMacro(macros[index])
					self.Items[index]:SetLabel(BUTTON_LABELS[BATTLEGROUND_ID['Arathi Basin']][level][index])
					self.Items[index]:SetTexture('Interface\\AddOns\\BGReport\\textures\\4-'..index)
					self.Items[index]:SetTexCoord(0, 1, 0, 1)
					
					if ( self.Items[index]:GetLabel() ~= '' ) then
						self:UpdateLabel(self.Items[index], x + (itemOffset * cos(-buttonAngle)), y + (itemOffset * sin(-buttonAngle)) )
						buttonAngle = buttonAngle - (360 / 4)
					end
				end

				self.ItemsSpecial[1] = Item:new()
				self.ItemsSpecial[1]:SetTexture([[Interface\AddOns\BGReport\textures\dot-active]])
				self.ItemsSpecial[1]:SetLabel('...')
				self.ItemsSpecial[1]:SetScript('self:SetConfiguration("ab")')
				self:UpdateLabel(self.ItemsSpecial[1], 0, 0)
			elseif level == 4 then
				bgr:SetDivider(45)
				bgr:SetStartAngle(0)
				bgr:SetMaxItemCount(4)
				
				local macros = {
					'/bg farm 2',
					'/bg farm 1',
					'/bg farm 5',
					'/bg farm 3',
				}
				
				local buttonAngle = self:GetStartAngle()
				local x, y;
				x = 0;
				y = 0;
				
				self.gui.frame.texture:SetTexture([[Interface\AddOns\BGReport\textures\4]])
				self.gui.frame.texture:SetTexCoord(0, 1, 0, 1)
				
				for index = 1, 4 do
					self.Items[index] = Item:new(index)
					self.Items[index]:SetMacro(macros[index])
					self.Items[index]:SetLabel(BUTTON_LABELS[BATTLEGROUND_ID['Arathi Basin']][level][index])
					self.Items[index]:SetTexture('Interface\\AddOns\\BGReport\\textures\\4-'..index)
					self.Items[index]:SetTexCoord(0, 1, 0, 1)
					
					if ( self.Items[index]:GetLabel() ~= '' ) then
						self:UpdateLabel(self.Items[index], x + (itemOffset * cos(-buttonAngle)), y + (itemOffset * sin(-buttonAngle)) )
						buttonAngle = buttonAngle - (360 / 4)
					end
				end

				self.ItemsSpecial[1] = Item:new()
				self.ItemsSpecial[1]:SetTexture([[Interface\AddOns\BGReport\textures\dot-active]])
				self.ItemsSpecial[1]:SetLabel('...')
				self.ItemsSpecial[1]:SetScript('self:SetConfiguration("ab")')
				self:UpdateLabel(self.ItemsSpecial[1], 0, 0)
			elseif level == 5 then
				-- BS
				bgr:SetDivider(45)
				bgr:SetStartAngle(0)
				bgr:SetMaxItemCount(4)
				
				local macros = {
					'/bg bs 2',
					'/bg bs 1',
					'/bg bs 5',
					'/bg bs 3',
				}
				
				local buttonAngle = self:GetStartAngle()
				local x, y;
				x = 0;
				y = 0;
				
				self.gui.frame.texture:SetTexture([[Interface\AddOns\BGReport\textures\4]])
				self.gui.frame.texture:SetTexCoord(0, 1, 0, 1)
				
				for index = 1, 4 do
					self.Items[index] = Item:new(index)
					self.Items[index]:SetMacro(macros[index])
					self.Items[index]:SetLabel(BUTTON_LABELS[BATTLEGROUND_ID['Arathi Basin']][level][index])
					self.Items[index]:SetTexture('Interface\\AddOns\\BGReport\\textures\\4-'..index)
					self.Items[index]:SetTexCoord(0, 1, 0, 1)
					
					if ( self.Items[index]:GetLabel() ~= '' ) then
						self:UpdateLabel(self.Items[index], x + (itemOffset * cos(-buttonAngle)), y + (itemOffset * sin(-buttonAngle)) )
						buttonAngle = buttonAngle - (360 / 4)
					end
				end

				self.ItemsSpecial[1] = Item:new()
				self.ItemsSpecial[1]:SetTexture([[Interface\AddOns\BGReport\textures\dot-active]])
				self.ItemsSpecial[1]:SetLabel('...')
				self.ItemsSpecial[1]:SetScript('self:SetConfiguration("ab")')
				self:UpdateLabel(self.ItemsSpecial[1], 0, 0)
			end
		else
			-- main ab menu
			bgr:SetDivider(45)
			bgr:SetStartAngle(0)
			bgr:SetMaxItemCount(4)
			
			local buttonAngle = self:GetStartAngle()
			local level = 0
			local x, y;
			x = 0;
			y = 0;
			
			self.gui.frame.texture:SetTexture([[Interface\AddOns\BGReport\textures\4]])
			self.gui.frame.texture:SetTexCoord(0, 1, 0, 1)
			
			for index = 1, 4 do
				self.Items[index] = Item:new(index)
				self.Items[index]:SetLabel(BUTTON_LABELS[BATTLEGROUND_ID['Arathi Basin']][level][index])
				self.Items[index]:SetTexture('Interface\\AddOns\\BGReport\\textures\\4-'..index)
				self.Items[index]:SetTexCoord(0, 1, 0, 1)
				self.Items[index]:SetScript('self:SetConfiguration("ab", '..index..')')
				
				if ( self.Items[index]:GetLabel() ~= '' ) then
					self:UpdateLabel(self.Items[index], x + (itemOffset * cos(-buttonAngle)), y + (itemOffset * sin(-buttonAngle)) )
					buttonAngle = buttonAngle - (360 / 4)
				end
			end

			self.ItemsSpecial[1] = Item:new()
			self.ItemsSpecial[1]:SetTexture([[Interface\AddOns\BGReport\textures\dot-active]])
			self.ItemsSpecial[1]:SetLabel('BS')
			self.ItemsSpecial[1]:SetScript('self:SetConfiguration("ab", 5)')
			self:UpdateLabel(self.ItemsSpecial[1], 0, 0)
		end
	elseif configuration == 'av' then
		if level then
			if level == 1 then
				-- south, Iceblood
				bgr:SetDivider(60)
				bgr:SetStartAngle(30)
				bgr:SetMaxItemCount(3)
				
				local macros = {
					'/bg need help at tower point',
					'/bg need help at iceblood graveyard',
					'/bg need help at iceblood tower'
				}
				local buttonAngle = self:GetStartAngle()
				local x, y;
				x = 0;
				y = 0;

				self.gui.frame.texture:SetTexture([[Interface\AddOns\BGReport\textures\3]])
				self.gui.frame.texture:SetTexCoord(0, 1, 1, 0)
				
				-- reverse order and shift by 1
				local textureIndex = 2
				
				for index = 1, 3 do
				
					textureIndex = textureIndex - 1
					if ( textureIndex == 0 ) then
						textureIndex = 3
					end
					
					self.Items[index] = Item:new(index)
					self.Items[index]:SetMacro(macros[index])
					self.Items[index]:SetLabel(BUTTON_LABELS[BATTLEGROUND_ID['Alterac Valley']][level][index])
					self.Items[index]:SetTexture('Interface\\AddOns\\BGReport\\textures\\3-'..textureIndex)
					self.Items[index]:SetTexCoord(0, 1, 1, 0)
					
					if ( self.Items[index]:GetLabel() ~= '' ) then
						self:UpdateLabel(self.Items[index], x + (itemOffset * cos(-buttonAngle)), y + (itemOffset * sin(-buttonAngle)) )
						buttonAngle = buttonAngle - (360 / 3)
					end
				end
				
				self.ItemsSpecial[1] = Item:new()
				self.ItemsSpecial[1]:SetTexture([[Interface\AddOns\BGReport\textures\dot-active]])
				self.ItemsSpecial[1]:SetScript('self:SetConfiguration("av")')
				self.ItemsSpecial[1]:SetLabel('...')
				self:UpdateLabel(self.ItemsSpecial[1], 0, 0)
				
			elseif level == 2 then
				-- north, Dun Baldar
				bgr:SetDivider(45)
				bgr:SetStartAngle(0)
				bgr:SetMaxItemCount(4)
				
				local macros = {
					'/bg spgy needs help',
					'/bg nbunker needs help',
					'/bg aid station needs help',
					'/bg sbunker needs help'
				}
				local buttonAngle = self:GetStartAngle()
				local x, y;
				x = 0;
				y = 0;

				self.gui.frame.texture:SetTexture([[Interface\AddOns\BGReport\textures\4]])
				self.gui.frame.texture:SetTexCoord(0, 1, 0, 1)
				
				for index = 1, 4 do
					self.Items[index] = Item:new(index)
					self.Items[index]:SetMacro(macros[index])
					self.Items[index]:SetLabel(BUTTON_LABELS[BATTLEGROUND_ID['Alterac Valley']][level][index])
					self.Items[index]:SetTexture('Interface\\AddOns\\BGReport\\textures\\4-'..index)
					self.Items[index]:SetTexCoord(0, 1, 0, 1)
					
					if ( self.Items[index]:GetLabel() ~= '' ) then
						self:UpdateLabel(self.Items[index], x + (itemOffset * cos(-buttonAngle)), y + (itemOffset * sin(-buttonAngle)) )
						buttonAngle = buttonAngle - (360 / 4)
					end
				end

				self.ItemsSpecial[1] = Item:new()
				self.ItemsSpecial[1]:SetTexture([[Interface\AddOns\BGReport\textures\dot-active]])
				self.ItemsSpecial[1]:SetScript('self:SetConfiguration("av")')
				self.ItemsSpecial[1]:SetLabel('...')
				self:UpdateLabel(self.ItemsSpecial[1], 0, 0)
			
			elseif level == 3 then
				-- north, Stonehearth
				bgr:SetDivider(60)
				bgr:SetStartAngle(-30)
				bgr:SetMaxItemCount(3)
				
				local macros = {
					'/bg sh bunker needs help',
					'/bg iw bunker needs help',
					'/bg shgy needs help',
				}
				local buttonAngle = self:GetStartAngle()
				local x, y;
				x = 0;
				y = 0;

				self.gui.frame.texture:SetTexture([[Interface\AddOns\BGReport\textures\3]])
				self.gui.frame.texture:SetTexCoord(0, 1, 0, 1)
				
				for index = 1, 3 do
					self.Items[index] = Item:new(index)
					self.Items[index]:SetMacro(macros[index])
					self.Items[index]:SetLabel(BUTTON_LABELS[BATTLEGROUND_ID['Alterac Valley']][level][index])
					self.Items[index]:SetTexture('Interface\\AddOns\\BGReport\\textures\\3-'..index)
					self.Items[index]:SetTexCoord(0, 1, 0, 1)
					
					if ( self.Items[index]:GetLabel() ~= '' ) then
						self:UpdateLabel(self.Items[index], x + (itemOffset * cos(-buttonAngle)), y + (itemOffset * sin(-buttonAngle)) )
						buttonAngle = buttonAngle - (360 / 3)
					end
				end

				self.ItemsSpecial[1] = Item:new()
				self.ItemsSpecial[1]:SetTexture([[Interface\AddOns\BGReport\textures\dot-active]])
				self.ItemsSpecial[1]:SetScript('self:SetConfiguration("av")')
				self.ItemsSpecial[1]:SetLabel('...')
				self:UpdateLabel(self.ItemsSpecial[1], 0, 0)
			
			elseif level == 4 then
				-- south, frostwolf
				bgr:SetDivider(45)
				bgr:SetStartAngle(0)
				bgr:SetMaxItemCount(4)
				
				local macros = {
					'/bg east tower needs help',
					'/bg fw gy needs help',
					'/bg west tower needs help',
					'/bg hut needs help'
				}
				local buttonAngle = self:GetStartAngle()
				local x, y;
				x = 0;
				y = 0;

				self.gui.frame.texture:SetTexture([[Interface\AddOns\BGReport\textures\4]])
				self.gui.frame.texture:SetTexCoord(0, 1, 0, 1)
				
				for index = 1, 4 do
					self.Items[index] = Item:new(index)
					self.Items[index]:SetMacro(macros[index])
					self.Items[index]:SetLabel(BUTTON_LABELS[BATTLEGROUND_ID['Alterac Valley']][level][index])
					self.Items[index]:SetTexture('Interface\\AddOns\\BGReport\\textures\\4-'..index)
					self.Items[index]:SetTexCoord(0, 1, 0, 1)
					
					if ( self.Items[index]:GetLabel() ~= '' ) then
						self:UpdateLabel(self.Items[index], x + (itemOffset * cos(-buttonAngle)), y + (itemOffset * sin(-buttonAngle)) )
						buttonAngle = buttonAngle - (360 / 4)
					end
				end

				self.ItemsSpecial[1] = Item:new()
				self.ItemsSpecial[1]:SetTexture([[Interface\AddOns\BGReport\textures\dot-active]])
				self.ItemsSpecial[1]:SetScript('self:SetConfiguration("av")')
				self.ItemsSpecial[1]:SetLabel('...')
				self:UpdateLabel(self.ItemsSpecial[1], 0, 0)
			end
		else
			-- main av menu		
			bgr:SetDivider(45)
			bgr:SetStartAngle(0)
			bgr:SetMaxItemCount(4)
			
			local buttonAngle = self:GetStartAngle()
			local level = 0
			local x, y;
			x = 0;
			y = 0;

			self.gui.frame.texture:SetTexture([[Interface\AddOns\BGReport\textures\4]])
			self.gui.frame.texture:SetTexCoord(0, 1, 0, 1)
			
			for index = 1, 4 do
				self.Items[index] = Item:new(index)
				self.Items[index]:SetLabel(BUTTON_LABELS[BATTLEGROUND_ID['Alterac Valley']][level][index])
				self.Items[index]:SetTexture('Interface\\AddOns\\BGReport\\textures\\4-'..index)
				self.Items[index]:SetTexCoord(0, 1, 0, 1)
				self.Items[index]:SetScript('self:SetConfiguration("av", '..index..')')
				
				if ( self.Items[index]:GetLabel() ~= '' ) then
					self:UpdateLabel(self.Items[index], x + (itemOffset * cos(-buttonAngle)), y + (itemOffset * sin(-buttonAngle)) )
					buttonAngle = buttonAngle - (360 / 4)
				end
			end

			self.ItemsSpecial[1] = Item:new()
			self.ItemsSpecial[1]:SetTexture([[Interface\AddOns\BGReport\textures\dot-active]])
			self:UpdateLabel(self.ItemsSpecial[1], 0, 0)
		end
	end
	
	self:UpdateSlots()
end

function bgr:UpdateSlots()
	local firstEnabled = 0
	local lastEnabled = 0

	for popIndex = 1, self:GetMaxItemCount() do
		if ( self.Items[popIndex]:IsEnabled() ) then
			if ( lastEnabled < 1 ) then
				firstEnabled = popIndex
				lastEnabled = popIndex
			else
				local slotOffset = (lastEnabled - 1) * 2
				local diff = popIndex - lastEnabled;
				for slotIndex = 0, diff * 2, 1 do
					if ( slotIndex < diff ) then
						self.slotOwners[slotIndex + slotOffset] = lastEnabled
					else
						self.slotOwners[slotIndex + slotOffset] = popIndex
					end
				end
				lastEnabled = popIndex
			end
		end
	end
	
	if ( not firstEnabled ) then
		return;
	end
		
	if ( firstEnabled == lastEnabled ) then
		for slotIndex = 0, (self:GetMaxItemCount()*2 - 1), 1 do
			self.slotOwners[slotIndex] = firstEnabled
		end
	else
		local slotOffset = (lastEnabled - 1) * 2;
		local diff = (self:GetMaxItemCount() - lastEnabled) + firstEnabled
		for slotIndex = 0, diff * 2, 1 do
			if ( (slotIndex  + slotOffset) == 16 ) then
				slotOffset = -slotIndex
			end
			
			if ( slotIndex < diff ) then
				self.slotOwners[slotIndex + slotOffset] = lastEnabled
			else
				self.slotOwners[slotIndex + slotOffset] = firstEnabled
			end
		end
	end	
end

function bgr:GetSlotOwnerID( slotID )
	return self.slotOwners[slotID]
end

function bgr:GetItem( itemID )
	if ( itemID == -1 ) then
		if ( not self.ItemsSpecial[1] ) then
			error('middle button is not set')
		end
		return self.ItemsSpecial[1]
	else
		return self.Items[itemID]
	end
end

function bgr:GetMidSelectionRadius()
	return (self.gui.frame:GetHeight() - 0.1*self.gui.frame:GetHeight()) * 0.1730859375 * self.gui.frame:GetScale()
end

function bgr:GetDeadzone()
	return (self.gui.frame:GetHeight() - 0.1*self.gui.frame:GetHeight()) * 0.198828125 * self.gui.frame:GetScale()
end

function bgr:GetSelectionRadius()
	return (self.gui.frame:GetHeight() - 0.1*self.gui.frame:GetHeight()) / 2 * self.gui.frame:GetScale()
end

function bgr:OnMarkingStart()
	local configuration, level = self:GetConfiguration()
	
	if ( not configuration ) then
		return
	end
	
	self.isMarking = true
	
	self.gui.frame:Show()
	self.gui.frame.texture:Show()
	self.captureFrame:Show()
end

function bgr:OnMarkingEnd()
	self.isMarking = false
	self.itemID = nil
	self.lastitemID = nil
	
	self.gui.frame:Hide()
	self.gui.frame.texture:Hide()
	self.gui.activeButton:Hide()
	self.captureFrame:Hide()
	
	local configuration, level = self:GetConfiguration()
	if ( level ) then
		self:SetConfiguration(configuration)
	end
end

function bgr:OnMarkingUpdate()
	self.EndPos:Set(GetCursorPosition())
	lineVec:Set( self.EndPos.x - self.StartPos.x, self.EndPos.y - self.StartPos.y )
	length = lineVec:GetLength()
	lineVec:Normalize()
	angle = lineVec:GetAngle()
	
	-- adjust start position from 3o'clock to more like 4o'clock
	--[[if ( self:GetMaxItemCount() == 6 ) then
		angle = angle + self:GetDivider()
		if ( angle > 360 ) then
			angle = angle - 360
		end
	end]]
	angle = angle + self:GetStartAngle()
	if ( angle > 360 ) then
		angle = angle - 360
	elseif ( angle < 0 ) then
		angle = 360 - angle
	end
	
	slotID = math.floor(angle / self:GetDivider())
	self.itemID = self:GetSlotOwnerID( slotID )
	
	if ( length > self:GetSelectionRadius() ) then
		self.lastitemID = nil
		self.itemID = nil
		self.activeItem = nil
		self.gui.activeButton:Hide()
		return
	end
	
	if ( length < self:GetDeadzone() ) then
		if ( length < self:GetMidSelectionRadius() ) then
			self.itemID = -1
		else
			self.lastitemID = nil
			self.itemID = nil
			self.activeItem = nil
			self.gui.activeButton:Hide()
			return
		end
	end
	
	if self.itemID ~= self.lastitemID then
		self.activeItem = self:GetItem(self.itemID)
		if not self.activeItem then
			DEFAULT_CHAT_FRAME:AddMessage('self.activeItem is not set', 38/255, 115/255, 191/255)
			if not self.itemID then
				DEFAULT_CHAT_FRAME:AddMessage('self.itemID is not set', 38/255, 115/255, 191/255)
			end
			DEFAULT_CHAT_FRAME:AddMessage(format('slotID: %d', slotID), 38/255, 115/255, 191/255)
			DEFAULT_CHAT_FRAME:AddMessage(format('angle: %d', angle), 38/255, 115/255, 191/255)
			return
		end
		self.lastitemID = self.itemID
		self.gui.activeButton:SetTexture(self.activeItem:GetTexture())
		self.gui.activeButton:SetTexCoord(self.activeItem:GetTexCoord())
		self.gui.activeButton:Show()
		--DEFAULT_CHAT_FRAME:AddMessage(format('angle: %f, length: %f, slotID: %d, itemID: %s', angle, length, slotID, self.itemID))
	end
end

function bgr:OnUpdate()
	if ( self.isMarking ) then
		self:OnMarkingUpdate()
	end
end

bgr.gui = {}
bgr.gui.frame = CreateFrame('Frame', 'bgreportframe', UIParent)
bgr.gui.frame:SetWidth(UIParent:GetHeight() - 0.1*UIParent:GetHeight() )
bgr.gui.frame:SetHeight(UIParent:GetHeight() - 0.1*UIParent:GetHeight() )
bgr.gui.frame:SetPoint('CENTER', 0, 0)
bgr.gui.frame:Hide()
--[[bgr.gui.frame:SetBackdrop({
	bgFile=[[Interface\ChatFrame\ChatFrameBackground]],
	tile = true,
	tileSize = 16,
})
bgr.gui.frame:SetBackdropColor(0, 0, 0, .6)]]
bgr.gui.frame.texture = bgr.gui.frame:CreateTexture(nil, 'BACKGROUND')
bgr.gui.frame.texture:SetAllPoints()
bgr.gui.frame.texture:Hide()

bgr.gui.activeButton = bgr.gui.frame:CreateTexture(nil, 'BORDER')
bgr.gui.activeButton:SetAllPoints()

bgr.captureFrame = CreateFrame('Frame', nil, UIParent)
bgr.captureFrame:SetAllPoints()
bgr.captureFrame:EnableMouse(true)
bgr.captureFrame:Hide()
bgr.captureFrame:SetScript('OnMouseDown', function()
	self.Clicking = true
	if ( not self.activeItem ) then
		return
	end

	--DEFAULT_CHAT_FRAME:AddMessage(format('<BGReport> clicked button (ID: %d)', self.activeItem:GetID()), 38/255, 115/255, 191/255)
	local macro = self.activeItem:GetMacro()
	if ( macro ) then
		local bodyLines = splitScriptBody( macro )
		local text = ChatFrameEditBox:GetText()

		for k, v in ipairs( bodyLines ) do
			ChatFrameEditBox:SetText( "/"..v )
			ChatEdit_SendText(ChatFrameEditBox)
		end
		
		ChatFrameEditBox:SetText(text);
	end
	
	local script = self.activeItem:GetScript()
	if ( script ) then
		RunScript(script)
	end
	
	self.lastitemID = nil
	self.itemID = nil
	self.activeItem = nil
	self.gui.frame:SetScale(0.95) -- better visual feedback
	self.gui.activeButton:Hide()
end)
bgr.captureFrame:SetScript('OnMouseUp', function()
	self.Clicking = false
	self.gui.frame:SetScale(1)
end)

bgr.updateFrame = CreateFrame('Frame')
bgr.updateFrame:SetScript('OnUpdate', function()
	self = bgr
	self:OnUpdate()
end)

function bgr:OnEvent(event, arg1)
	local inBattleground = self:InBattleground()
	
	if ( event == 'ADDON_LOADED' and arg1 == 'BGReport' ) then
		DEFAULT_CHAT_FRAME:AddMessage('<BGReport> loaded in '..GetRealZoneText(), 38/255, 115/255, 191/255)
		--DEFAULT_CHAT_FRAME:AddMessage('<BGReport> ' .. tostring(self), 38/255, 115/255, 191/255)
		
		if ( inBattleground == 1 ) then
			DEFAULT_CHAT_FRAME:AddMessage('<BGReport> changing configuration to WSG', 38/255, 115/255, 191/255)
			self:SetConfiguration('wsg')
		elseif ( inBattleground == 2 ) then
			DEFAULT_CHAT_FRAME:AddMessage('<BGReport> changing configuration to AB', 38/255, 115/255, 191/255)
			self:SetConfiguration('ab')
		elseif ( inBattleground == 3 ) then
			DEFAULT_CHAT_FRAME:AddMessage('<BGReport> changing configuration to AV', 38/255, 115/255, 191/255)
			self:SetConfiguration('av')
		else
			local configuration, level = self:GetConfiguration()
			if ( configuration ) then
				DEFAULT_CHAT_FRAME:AddMessage('<BGReport> reseting configuration', 38/255, 115/255, 191/255)
				self:SetConfiguration()
			end
		end
		
	elseif ( event == 'ZONE_CHANGED_NEW_AREA' ) then
		
		--DEFAULT_CHAT_FRAME:AddMessage('<BGReport> new area: '..GetRealZoneText(), 38/255, 115/255, 191/255)
		if ( inBattleground == 1 ) then
			self:SetConfiguration('wsg')
		elseif ( inBattleground == 2 ) then
			self:SetConfiguration('ab')
		elseif ( inBattleground == 3 ) then
			self:SetConfiguration('av')
		else
			local configuration, level = self:GetConfiguration()
			if ( configuration ) then
				DEFAULT_CHAT_FRAME:AddMessage('<BGReport> reseting configuration', 38/255, 115/255, 191/255)
				self:SetConfiguration()
			end
		end
		
	end
end

bgr.updateFrame:SetScript('OnEvent', function()
	self = bgr
	self:OnEvent(event, arg1)
end)
bgr.updateFrame:RegisterEvent('ADDON_LOADED')
bgr.updateFrame:RegisterEvent('ZONE_CHANGED_NEW_AREA')


bgr:MakeItems()
bgr:UpdateSlots()

if ( BGReport_API ) then
	DEFAULT_CHAT_FRAME:AddMessage('<BGReport> addons conflict detected.', 1, 0.3, 0.3)
else
	--[[BGReport_API = {}
	BGReport_API.SetConfiguration = function(self, configuration, level)
		bgr:SetConfiguration(configuration, level)
	end
	BGReport_API.OnMarkingStart = function(self)
		bgr:OnMarkingStart()
	end
	BGReport_API.OnMarkingEnd = function(self)
		bgr:OnMarkingEnd()
	end]]
	BGReport_API = bgr
end
