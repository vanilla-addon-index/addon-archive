PortalFu = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceEvent-2.0", "FuBarPlugin-2.0")
local PortalFu = PortalFu

local L = AceLibrary("AceLocale-2.2"):new("PortalFu")
local tablet = AceLibrary("Tablet-2.0")
local dewdrop = AceLibrary("Dewdrop-2.0")
local BS = AceLibrary:HasInstance("Babble-Spell-2.3") and AceLibrary("Babble-Spell-2.3")

local string_find = string.find
local string_sub = string.sub
local math_floor = math.floor

local GetSpellInfo = GetSpellInfo
local GetSpellName = GetSpellName
local GetContainerNumSlots = GetContainerNumSlots
local GetContainerItemInfo = GetContainerItemInfo
local GetContainerItemLink = GetContainerItemLink
local GetContainerItemCooldown = GetContainerItemCooldown
local GetBindLocation = GetBindLocation

local scrollOfRecallIcon 	= "Interface\\Icons\\INV_Scroll_16"
local hearthstoneIcon		= "Interface\\Icons\\INV_Misc_Rune_01"

PortalFu.hasIcon = true
PortalFu.canHideText = true
PortalFu.hasNoColor = true
PortalFu.defaultMinimapPosition = 20
PortalFu.overrideMenu = true

PortalFu:RegisterDB("PortalFuDB", "PortalFuPerCharDB")
PortalFu:RegisterDefaults('profile', {
	showTag = true,
})


local function pairsByKeys(t)
	local a = {}
	for n in pairs(t) do
		table.insert(a, n)
	end
	table.sort(a)
	
	local i = 0
	local iter = function ()
		i = i + 1
		if a[i] == nil then
			return nil
		else
			return a[i], t[a[i]]
		end
	end
	return iter
end

local function findSpell(spellName)
	local i = 1
	while true do
		local s = GetSpellName(i, BOOKTYPE_SPELL)
		if not s then
			break
		end
		
		if s == spellName then
			return i
		end
		
		i = i + 1
	end
end


local function getHearthCooldown()
	local cooldown, startTime, duration

  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      local item = GetContainerItemLink(bag, slot)
      if item then
        if string_find(item, L["HEARTHSTONE"]) then
          startTime, duration = GetContainerItemCooldown(bag, slot)
          cooldown = duration - (GetTime() - startTime)
          cooldown = cooldown / 60
          cooldown = math_floor(cooldown)
          if cooldown <= 0 then
            return L["READY"]
          end

          return cooldown.." "..L["MIN"]
        end
      end
    end
  end
  
  return L["N/A"]
end

local function getReagentCount(name)
	local count = 0
  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      local item = GetContainerItemLink(bag, slot)
      if item then
        if string_find(item, name) then
          local _, itemCount = GetContainerItemInfo(bag, slot)
          count = count + itemCount
        end
      end
    end
  end
	
	return count
end

local function idAndNameFromLink(link)
	local name
	if (not link) then
		return ""
	end
	for id, name in string.gfind(link, "|c%x+|Hitem:(%d+):%d+:%d+:%d+|h%[(.-)%]|h|r$") do
		return tonumber(id), name
	end
	return nil
end

function PortalFu:GetItemSlot(itemId)
	local bag = nil
	local slot = nil
	if self.teleItems[itemId].slot then
		bag = self.teleItems[itemId].bag
		slot = self.teleItems[itemId].slot
	end

	if self.teleItems[itemId].slotCheckedSinceUpdate then
		return slot, bag
	end

	-- Check if the slot is not nil or has changed
	if slot then
		-- Check equipped items first
		if not bag then
			local link = GetInventoryItemLink("player", slot)
			if (link) then
				local id = idAndNameFromLink(link)
				if (id and id == itemId) then
					self.teleItems[itemId].slotCheckedSinceUpdate = true
					return slot, bag
				end
			end
		elseif bag then
			local link = GetContainerItemLink(bag, slot)
			if (link) then
				local id = idAndNameFromLink(link)
				if (id and id == itemId) then
					self.teleItems[itemId].slotCheckedSinceUpdate = true
					return slot, bag
				end
			end
		end
	end

	-- Old values did not match. Clear the previous values
	self.teleItems[itemId].bag = nil
	self.teleItems[itemId].slot = nil
	bag = nil
	slot = nil

	-- Do a full inventory/equipment search
	-- Check equipped items first
	for slot = 0, 19 do
		local link = GetInventoryItemLink("player", slot)
		if (link) then
			local id, name = idAndNameFromLink(link)
			if (id and id == itemId) then
				self.teleItems[itemId].bag = bag
				self.teleItems[itemId].slot = slot
				self.teleItems[itemId].slotCheckedSinceUpdate = true
				self.teleItems[itemId].icon = GetInventoryItemTexture("player", slot)
				return slot, bag
			end
		end
	end
	for bag = 4, 0, -1 do
		for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot)
			if (link) then
				local id, name = idAndNameFromLink(link)
				if (id and id == itemId) then
					self.teleItems[itemId].bag = bag
					self.teleItems[itemId].slot = slot
					self.teleItems[itemId].slotCheckedSinceUpdate = true
					self.teleItems[itemId].icon = GetContainerItemInfo(bag, slot)
					return slot, bag
				end
			end
		end
	end


	self.teleItems[itemId].slotCheckedSinceUpdate = true
	return slot, bag
end


function PortalFu:CheckTransport()

	local mageSpells = {
		Alliance = {
			"Teleport: Darnassus",
			"Teleport: Ironforge",
			"Teleport: Stormwind",
			"Portal: Darnassus",
			"Portal: Ironforge",
			"Portal: Stormwind",
			"Teleport: Theramore",
			"Portal: Theramore",
		},
		Horde = {
			"Teleport: Orgrimmar",
			"Teleport: Thunder Bluff",
			"Teleport: Undercity",
			"Portal: Orgrimmar",
			"Portal: Thunder Bluff",
			"Portal: Undercity",
			"Teleport: Stonard",
			"Portal: Stonard",
		}
	}

	local _, class = UnitClass("player")
	if class == "MAGE" then
		local faction = UnitFactionGroup('player')
		self.portals = mageSpells[faction]
	elseif class == "DRUID" then
		self.portals = {
			"Teleport: Moonglade" --18960 --TP:Moonglade
			}
	elseif class == "SHAMAN" then
		self.portals = {
			"Astral Recall" -- 556 --
			}
	end

	self.teleItems = {
		[61000] = {name = "Teleport: Cavern of Times"}, -- Time-Worn Rune
		[18984] = {name = "Teleport: Everlook"},
		[18986] = {name = "Teleport: Gadgetzan"},
		[51312] = {name = "Portable Wormhole Generator: Stormwind"},
		[51313] = {name = "Portable Wormhole Generator: Orgrimmar"},
	}
end


function PortalFu:OnInitialize()
	self:RegisterChatCommand({"/portalfu"}, function() PortalFu:ToggleMinimapAttached() end)
end

function PortalFu:OnEnable()
	self.METHODS = {}
	self.ITEMS = {}
	self.lastCast = L["N/A"]
	self:CheckTransport()
	self:UpdateSpells()
	self:RegisterEvent("LEARNED_SPELL_IN_TAB")
	self:RegisterEvent("BAG_UPDATE")
	self:UpdateDisplay()
	self:SetIcon(hearthstoneIcon)
end

function PortalFu:OnDisable()
	self.METHODS = nil
	self.lastCast = nil
	self.ITEMS = nil
	self:UnregisterAllEvents()
end

function PortalFu:LEARNED_SPELL_IN_TAB()
	self:UpdateSpells()
end

function PortalFu:BAG_UPDATE()
	for k,v in pairs(self.teleItems) do
		v.slotCheckedSinceUpdate = false
	end
	PortalFu:UpdateItems()
end

function PortalFu:OnMenuRequest(level,value)
	if level == 1 then
		for k,v in pairsByKeys(self.METHODS) do
			dewdrop:AddLine(
				'text', v.text,
--					'secure', v.secure,
				'icon', v.spellIcon,
				'func', function(v) 
					self:SetIcon(v.spellIcon)
					self.lastCast = v.text
					self:UpdateDisplay()
					CastSpellByName(v.text)
				end,
				'arg1', v,
				'disabled', false,
				'closeWhenClicked', true
			)
		end
		if self.METHODS then dewdrop:AddLine() end
		self:ShowItems()
		if self.ITEMS then dewdrop:AddLine() end
		self:ShowHearthstone()
		dewdrop:AddLine(
			'text', "FuBar Options",
			'hasArrow', true,
			'value', "fubar"
		)
		
		
	elseif level > 1 and (value == "fubar" or value == "position") then
		level = value == "position" and 2 or level
		self:AddImpliedMenuOptions(level )
	end
end

function PortalFu:UpdateText()
	if self.lastCast then
		local text = self.lastCast
		if string_find(self.lastCast,"Item:") then
			local _, _, id = string_find(self.lastCast,"Item:(%d+)")
			id = tonumber(id)
			text = self.teleItems[id].name
		end
		if string_find(text, ":") then
			 _, _, text = string_find(text,": (.+)")
		end
		self:SetText(text)
	else
		self:SetText(L["N/A"])
	end
end

function PortalFu:OnTooltipUpdate()
	local cat = tablet:AddCategory(
		'columns', 2,
		'child_textR', 1,
		'child_textG', 1,
		'child_textB', 0,
		'child_text2R', 1,
		'child_text2G', 1,
		'child_text2B', 1
	)
	cat:AddLine('text', L["RCLICK"], 'text2', L["SEE_SPELLS"])
	cat:AddLine('text', ' ')
	cat:AddLine('text', L["HEARTHSTONE"].." : "..GetBindLocation(), 'text2', getHearthCooldown())
	cat:AddLine('text', ' ')
	cat:AddLine('text', L["TP_P"], 'text2', getReagentCount(L["TP_RUNE"]).."/"..getReagentCount(L["P_RUNE"]))
end

function PortalFu:UpdateSpells()
	if self.portals then
		for _,unTransSpell in ipairs(self.portals) do
			local spell = BS[unTransSpell]
			local spellIcon = BS:GetSpellIcon(unTransSpell)
			local spellid = findSpell(spell)
			
			if spellid then	
				self.METHODS[spell] = {
					spellid = spellid,
					text = spell,
					spellIcon = spellIcon,
				}
			end
		end
	end
end

function PortalFu:UpdateItems()
	if not self.teleItems then return end
	for id, v in pairs(self.teleItems) do
		local slot, bag = self:GetItemSlot(id)
		if slot then
			self.ITEMS[id] = slot
		else
			self.ITEMS[id] = nil
		end
	end	
end

function PortalFu:ShowHearthstone()
	local text, icon
	local hsCd = getHearthCooldown()
	if hsCd == L["READY"] then
		local bindLoc = GetBindLocation()
		text = L["HEARTHSTONE"]
		if bindLoc then
			text = L["INN"] .." "..bindLoc
		end
		icon = hearthstoneIcon
		dewdrop:AddLine(
			'text', text,
			'icon', icon,
			'func', function(icon,text) 
				self:SetIcon(icon)
				self.lastCast = text
				self:UpdateDisplay()
				UseItemByName(L["HEARTHSTONE"])
			end,
			'arg1', icon,
			'arg2', text,
			'closeWhenClicked', true
		)
		dewdrop:AddLine()
	end
end

function PortalFu:ShowItems()
	for k,v in pairs(self.ITEMS) do
		dewdrop:AddLine(
			'text', self.teleItems[k].name,
			'icon', self.teleItems[k].icon,
			'func', function(id) 
				self:SetIcon(self.teleItems[id].icon)
				self.lastCast = "Item:"..id
				self:UpdateDisplay()
				local slot, bag = self:GetItemSlot(id)
				if not bag then
					UseInventoryItem(slot)
				else
					UseContainerItem(bag, slot)
				end
			end,
			'arg1', k,
			'closeWhenClicked', true
		)
	end
end

function PortalFu:OnClick()
	if self.lastCast and self.lastCast ~= L["N/A"] then
		if string_find(self.lastCast,L["INN"]) then
			UseItemByName(L["HEARTHSTONE"])
		elseif string_find(self.lastCast,"Item:") then
			local _, _, id = string_find(self.lastCast,"Item:(%d+)")
			id = tonumber(id)
			local slot, bag = self:GetItemSlot(id)
			if not bag then
				UseInventoryItem(slot)
			else
				UseContainerItem(bag, slot)
			end
		else
			CastSpellByName(self.lastCast)
		end
	else
		UseItemByName(L["HEARTHSTONE"])
	end
end