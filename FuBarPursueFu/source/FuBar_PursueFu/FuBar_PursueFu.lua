--[[---------------------------------------------------------------------------------
 ADDON DECLARATION
------------------------------------------------------------------------------------]]
PursueFu = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0", "AceDB-2.0", "AceConsole-2.0", "FuBarPlugin-2.0")
local L = AceLibrary("AceLocale-2.1"):GetInstance("FuBar_PursueFu", true)
local BS = AceLibrary("AceLocale-2.1"):GetInstance("Babble-Spell-2.1")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")
local T = AceLibrary("Tablet-2.0")

local defaultIcon = "Interface\\Icons\\Ability_Hunter_Pathfinding"

local rev = "$Rev: 13161 $"
PursueFu.version = "1."..string.sub(rev, -7, -7).."."..string.sub(rev, -6, -2)

PursueFu.cannotHideText = false
PursueFu.hasIcon = defaultIcon
PursueFu.overrideMenu = false

--[[---------------------------------------------------------------------------------
 IMPORTANT TABLES
------------------------------------------------------------------------------------]]
local spellNames = { BS"Find Herbs", BS"Find Minerals", BS"Find Treasure",
	BS"Track Beasts", BS"Track Humanoids", BS"Track Hidden", BS"Track Elementals",
	BS"Track Undead", BS"Track Demons", BS"Track Giants", BS"Track Dragonkin",
	BS"Sense Undead", BS"Sense Demons"
}

local profileDefaults = {
	showMiniMap = true,
	showHint = true,
	remindMe = true,
	herbs = false,
	mines = false,
	chests = false
}

local charDefaults = {
	spellsDirty = true,
	lastSpell = "",
	spells = {}
}

PursueFu.OnMenuRequest = {
	type = "group",
	args = {
		headerOptSpace = {
			type = "header",
			order = 799,
		},
		headerOptions = {
			name = "Options",
			type = "header",
			order = 900,
		},
		[ "Minimap" ] = {
			name = L["Show Minimap Icon"], type = "toggle",
			desc = L["Show the minimap tracking icon."], order = 901,
			get = "GetMiniMap", set = "SetMiniMap"
		},
		[ "Hint" ] = {
			name = L["Show Tooltip Hint"], type = "toggle",
			desc = L["Show the hint at the bottom of the FuBar tooltip."], order = 902,
			get = "GetTooltipHint", set = "SetTooltipHint"
		},
		[ "Reminder" ] = {
			name = L["Post-Mortem Reminder"], type = "toggle",
			desc = L["Remind me upon resurrection that my tracking has been deactivated."], order = 903,
			get = "GetReminder", set = "SetReminder"
		},
	}
}

--[[---------------------------------------------------------------------------------
 FUNCTIONS REGARDING SETTINGS
------------------------------------------------------------------------------------]]
function PursueFu:GetHeaderOptsHidden()
	if ( self.db.char ) and ( self.db.char.spells ) then
		return false
	end
	return true
end

function PursueFu:GetMiniMap()
	return self.db.profile.showMiniMap
end

function PursueFu:SetMiniMap()
	self.db.profile.showMiniMap = not self.db.profile.showMiniMap
	self:ReMinimap()
end

function PursueFu:GetTooltipHint()
	return self.db.profile.showHint
end

function PursueFu:SetTooltipHint()
	self.db.profile.showHint = not self.db.profile.showHint
end

function PursueFu:GetReminder()
	return self.db.profile.remindMe
end

function PursueFu:SetReminder()
	self.db.profile.remindMe = not self.db.profile.remindMe
	if ( self.remRegistered ) and ( not self.db.profile.remindMe ) then
		self:UnregisterEvent("PLAYER_UNGHOST")
		self:UnregisterEvent("PLAYER_ALIVE")
		self.remRegistered = nil
	elseif ( not self.remRegistered ) and ( self.db.profile.remindMe ) then
		self:RegisterEvent("PLAYER_UNGHOST", "LifeChangingEvent")
		self:RegisterEvent("PLAYER_ALIVE", "LifeChangingEvent")
		self.remRegistered = true
	end
end

--[[---------------------------------------------------------------------------------
 INITIALIZATIONS
------------------------------------------------------------------------------------]]
function PursueFu:OnInitialize()
	self:RegisterDB("PursueFu2DB", "PursueFu2PerCharDB")
	self:RegisterDefaults("profile", profileDefaults)
	self:RegisterDefaults("char", charDefaults)
	self:RegisterChatCommand(L["chatCommands"], self.OnMenuRequest)
end

function PursueFu:OnEnable()
	self:RegisterEvent("SPELLS_CHANGED", "SpellChange")
	self:RegisterEvent("LEARNED_SPELL_IN_TAB", "SpellChange")
	self:RegisterEvent("PLAYER_AURAS_CHANGED", "UpdateData")
	if ( self.db.profile.remindMe ) then
		self:RegisterEvent("PLAYER_UNGHOST", "LifeChangingEvent")
		self:RegisterEvent("PLAYER_ALIVE", "LifeChangingEvent")
		self.remRegistered = true
	end
	self:UpdateData()
	self:PopulateDB('herbs')
	self:PopulateDB('mines')
	self:PopulateDB('chests')
end

function PursueFu:OnDisable()
	self.remRegistered = nil
end

--[[---------------------------------------------------------------------------------
 CORE
------------------------------------------------------------------------------------]]
function PursueFu:PopulateDB(meta)
	if self.db.profile[meta] and pfDatabase then
		SlashCmdList["PFDB"](meta)
	end
end

function PursueFu:SetDBmeta(field, value)
	self.db.profile[field] = value
	self:PopulateDB(field)
end
function PursueFu:GetDBmeta(field)
	return self.db.profile[field]
end

function PursueFu:GetNextSpell(spell)
	local n , nspell = false, ""
	if not spell or spell == "" then
	  nspell = next(self.db.char.spells)
	  return nspell
	end

	for k, v in pairs(self.db.char.spells) do
	  
	  if n then
		 nspell = k
		 return nspell
	  end
	  if spell == k then
		 n = true
	  end
	end
	if nspell == "" then
	  nspell = next(self.db.char.spells)
	end
	return nspell
end

function PursueFu:CompileSpells()
	local i = 1
	while true do
		local sName, _ = GetSpellName(i, BOOKTYPE_SPELL)
		if ( not sName ) then
			do break end
		end	
		for _, spell in ipairs(spellNames) do
			if ( spell == sName ) then
				self.db.char.spells[sName] = BS:GetSpellIcon(spell)
			end
		end
		i = i + 1
	end
	
	i = 1
	for k, v in pairs(self.db.char.spells) do
		i = i + 1
		local name = string.gsub(k, "%s", "_")
		if ( not self.OnMenuRequest.args[name] ) then
			local k, v = k, v
			self.OnMenuRequest.args[name] = {
				name = k, type = "toggle",
				desc = k, order = i,
				get = function()
					if ( self.db.char.currTexture == v ) then
						return true
					end
				end,
				set = function() self:ToggleTrackingSpell(k) end,
			}
		end
	end
	i = nil
	
	if pfDatabase then
		self.OnMenuRequest.args["headerOptSpace2"] = {
			type = "header",
			order = 699,
		}
		self.OnMenuRequest.args["headerpfQuest"] = {
			name = "Populate pfQuest objects",
			type = "header",
			order = 700,
		}
		self.OnMenuRequest.args["herbs"] = {
			name = L["Herbs"], type = "toggle",
			desc = L["/db herbs"], order = 701,
			get = "GetDBmeta", set = "SetDBmeta",
			passValue = 'herbs'
		}
		self.OnMenuRequest.args["mines"] = {
			name = L["Mines"], type = "toggle",
			desc = L["/db mines"], order = 701,
			get = "GetDBmeta", set = "SetDBmeta",
			passValue = 'mines'
		}
		self.OnMenuRequest.args["chests"] = {
			name = L["Chests"], type = "toggle",
			desc = L["/db chests"], order = 701,
			get = "GetDBmeta", set = "SetDBmeta",
			passValue = 'chests'
		}
				
	end
	
	--[[
	local findIndex, trackIndex, senseIndex = 100, 200, 300
	for l, _ in pairs(self.db.char.spells) do
		local _, _, first = string.find(l, "^(%a?).*$")
		if ( first == "F" ) then
			m.order = findIndex + m.order
		elseif ( first == "T" ) then
			m.order = trackIndex + m.order
		elseif ( first == "S" ) then
			m.order = senseIndex + m.order
		else
			self:Print("Invalid key: "..l..".")
		end
	end
	
	if ( findIndex > 100 ) then
		if ( not self.OnMenuRequest.args["headerFind"] ) then
			self.OnMenuRequest.args["headerFind"] = {
				name = L["Find Abilities"],
				type = "header",
				order = 100,
			}
		end
	end
	if ( trackIndex > 200 ) then
		if ( not self.OnMenuRequest.args["headerTrack"] ) then
			self.OnMenuRequest.args["headerTrack"] = {
				name = L["Track Abilities"],
				type = "header",
				order = 200,
			}
		end
	end
	if ( senseIndex > 300 ) then
		if ( not self.OnMenuRequest.args["headerSense"] ) then
			self.OnMenuRequest.args["headerSense"] = {
				name = L["Sense Abilities"],
				type = "header",
				order = 300,
			}
		end
	end
	--]]
end

function PursueFu:OnClick(button)
	self:ToggleTrackingSpell(self:GetNextSpell(self.db.char.lastSpell))
end
	
function PursueFu:FindTracking(theTexture)
	for i, v in ipairs(spellNames) do
		if ( theTexture == BS:GetSpellIcon(v) ) then
			return C:Green(v)
		end
	end
	return C:Red(L["No match!"])
end

function PursueFu:ToggleTrackingSpell(v)
	if ( self.db.char.currTexture ) and
	   ( self.db.char.currTexture == self.db.char.spells[v] ) then
		CancelTrackingBuff()
		self:SetIcon(defaultIcon)
		self:SetText(C:Orange(L["Tracking Off"]))
	else
		if ( UnitOnTaxi("player") ) then
			self:Print(C:Red(ERR_CLIENT_LOCKED_OUT))
			return
		end
		CastSpellByName(v)
		self:SetIcon(self.db.char.spells[v])
		self:SetText(v)
		self.db.char.lastSpell = v
	end
	D:Close(1)
	self:UpdateData()
end

function PursueFu:ReMinimap()
	if ( self.db.char.currTexture ) then
		if ( self.db.profile.showMiniMap ) then
			MiniMapTrackingFrame:Show()
		else
			MiniMapTrackingFrame:Hide()
		end
	end
end

function PursueFu:LifeChangingEvent()
	if ( UnitHealth("player") > 10 ) then
		if ( self.db.char.currTexture ) and ( not GetTrackingTexture() ) then
			self:Print(C:Red(L["Reminder: Due to your recent death, your trackers are no longer active."]))
		end
	end
end

function PursueFu:SpellChange()
	self.db.char.spellsDirty = true
	self:UpdateData()
end

--[[---------------------------------------------------------------------------------
 FUBAR UPDATES
------------------------------------------------------------------------------------]]
function PursueFu:OnDataUpdate()
	self.db.char.currTexture = GetTrackingTexture()
	self:ReMinimap()
	if ( self.db.char.spellsDirty == true ) then
		self:CompileSpells()
		self.db.char.spellsDirty = false
	end
	self:UpdateText()
end
	
function PursueFu:OnTextUpdate()
	if ( self.db.char.currTexture ~= nil ) then
		self:SetIcon(self.db.char.currTexture)
		self:SetText(self:FindTracking(self.db.char.currTexture))
	else
		self:SetIcon(defaultIcon)
		self:SetText(C:Orange(L["Tracking Off"]))
	end
end

function PursueFu:OnTooltipUpdate()
	if ( not self.db.char.currTexture ) then
		local cat = T:AddCategory( "text", C:Orange(L["Tracking Off"]), "justify", "CENTER" )
		cat:AddLine()
	else
		local cat = T:AddCategory()
		for k, v in pairs(self.db.char.spells) do
			if ( self.db.char.currTexture == v ) then
				cat:AddLine( "text", C:Green(k), "justify", "CENTER" )
			end
		end
	end
	if ( self.db.profile.showHint == true ) then
		T:SetHint(L["Left-click to toggle next ability."].."\n"..L["Right-click to switch abilites."])
	end
end
