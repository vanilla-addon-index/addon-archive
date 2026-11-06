local EZP = CreateFrame("Frame")
EZP.ConfigFrame = CreateFrame("Frame",nil,UIParent)
EZP.Parser = CreateFrame("GameTooltip", "EZPParser", nil, "GameTooltipTemplate")
EZP.ACE = AceLibrary("AceAddon-2.0"):new("FuBarPlugin-2.0")
EZP:RegisterEvent("ADDON_LOADED")
EZP:RegisterEvent("UNIT_INVENTORY_CHANGED")
EZP:RegisterEvent("BAG_UPDATE")

--fubar/mapicon
EZP.ACE.name = "EzPoison"
EZP.ACE.hasIcon = "Interface\\Icons\\Ability_Rogue_DualWeild"
EZP.ACE.defaultMinimapPosition = 200
EZP.ACE.cannotDetachTooltip = true

function EZP.ACE:OnClick()
	if (arg1 == "LeftButton") then
		if EZP.ConfigFrame:IsVisible() then EZP.ConfigFrame:Hide()
		else EZP:UpdateTexture(); EZP.ConfigFrame:Show() end
	end
end


-- pre-allocate work variables
EZP.Work = 	{
	slotInfo = {},
	ToolTipBuff = "",
	ID = {},
	Time = 0,
	iSCasting = nil,
	
		Poison = {
		[1] = "Instant Poison",
		[2] = "Deadly Poison",
		[3] = "Deadly Poison IV",
		[4] = "Crippling Poison",
		[5] = "Crippling Poison II",
		[6] = "Mind-numbing Poison",
		[7] = "Wound Poison",
		[8] = "Corrosive Poison II",
		[9] = "Agitating Poison",
		[10] = "Elemental Sharpening Stone",
		[11] = "Consecrated Sharpening Stone",
		[12] = "Blessed Wizard Oil",
		[13] = "Brilliant Wizard Oil",
		[14] = "Brilliant Mana Oil",
		[15] = "Frost Oil",
		[16] = "Corrosive Poison",
		[17] = "Dense Sharpening Stone",
		[18] = "Dissolvent Poison II",
	},
	PoisonID = {
		[1] = {6947,6949,6950,8926,8927,8928},
		[2] = {2892,2893,8984,8985,20844},
		[3] = 8985,
		[4] = 3775,
		[5] = 3776,
		[6] = {5237,6951,9186},
		[7] = {10918,10920,10921,10922},
		[8] = 47409,
		[9] = {65032},
		[10] = {18262},
		[11] = {23122},
		[12] = {28898},
		[13] = {20749},
		[14] = {20748},
		[15] = {3829},
		[16] = 47408,
		[17] = 12404,
		[18] = 54010,
	},
	PoisonIcon = {
		[1] = "Interface\\Icons\\Ability_Poisons",
		[2] = "Interface\\Icons\\Ability_Rogue_DualWeild",
		[3] = "Interface\\Icons\\Ability_Rogue_DualWeild",
		[4] = "Interface\\Icons\\Ability_PoisonSting",
		[5] = "Interface\\Icons\\INV_Potion_19",
		[6] = "Interface\\Icons\\Spell_Nature_NullifyDisease",
		[7] = "Interface\\Icons\\Ability_PoisonSting",
		[8] = "Interface\\Icons\\Spell_Nature_CorrosiveBreath",
		[9] = "Interface\\Icons\\Spell_Nature_NullifyPoison",
		[10] = "Interface\\Icons\\INV_Stone_02",
		[11] = "Interface\\Icons\\INV_Stone_SharpeningStone_02",
		[12] = "Interface\\Icons\\INV_Potion_26",
		[13] = "Interface\\Icons\\INV_Potion_105",
		[14] = "Interface\\Icons\\INV_Potion_100",
		[15] = "Interface\\Icons\\INV_Potion_20",
		[16] = "Interface\\Icons\\Spell_Nature_CorrosiveBreath",
		[17] = "Interface\\Icons\\INV_Stone_SharpeningStone_05",
		[18] = "Interface\\Icons\\Spell_Nature_SlowPoison",
	}
}

-- local functions
EZP.GetWeaponEnchantInfo = GetWeaponEnchantInfo

function EZP:OnEvent()
	if event == "BAG_UPDATE" then
		if arg1 == 0 or arg1 == 1 or arg1 == 2 or arg1 == 3 or arg1 == 4 then
			EZP:UpdatePoisonCount()
		end
		
	elseif event == "ADDON_LOADED" and arg1 == "EzPoison" then
		if not EZPcfg then
			EZPcfg = {
				Profile ={
					[1] = {MainHand = 0, OffHand = 0, Name = "Profile 1"},
					[2] = {MainHand = 0, OffHand = 0, Name = "Profile 2"},
					[3] = {MainHand = 0, OffHand = 0, Name = "Profile 3"},
					[4] = {MainHand = 0, OffHand = 0, Name = "Profile 4"},
					[5] = {MainHand = 0, OffHand = 0, Name = "Profile 5"},
					[6] = {MainHand = 0, OffHand = 0, Name = "Profile 6"},
					[7] = {MainHand = 0, OffHand = 0, Name = "Profile 7"},
				},
				CurrentProfile = 1,
				PosX = 200,
				PosY = -200,
				Scale = 1,
			}
		end

		EZP.ConfigFrame:ConfigureUI()
		EZP:SetProfile()
		EZP:ConfigFubar()
		EZP.ConfigFrame:SetScript("OnUpdate",EZP.AddonStart)
	
	elseif event == "SPELLCAST_START" then
		EZP.Work.iSCasting = 1
	
	elseif event == "SPELLCAST_STOP" or event ==  "SPELLCAST_INTERRUPTED" or event == "SPELLCAST_FAILED" then
		EZP:UnregisterEvent("SPELLCAST_STOP")
		EZP:UnregisterEvent("SPELLCAST_START")
		EZP:UnregisterEvent("SPELLCAST_INTERRUPTED")
		EZP:UnregisterEvent("SPELLCAST_FAILED")
		EZP.Work.iSCasting = nil
		EZP:UpdateTexture()
		
	elseif event == "UNIT_INVENTORY_CHANGED" then
		EZP:UpdateTexture()
	end
end

EZP:SetScript("OnEvent", EZP.OnEvent)

function EZP.ConfigFrame:ConfigureUI()
	-- moving frames function
	function EZP.ConfigFrame:StartMove()
		this:StartMoving()
	end
	
	function EZP.ConfigFrame:StopMove()
		this:StopMovingOrSizing()
		_, _, _, EZPcfg.PosX, EZPcfg.PosY = EZP.ConfigFrame:GetPoint()
	end
	
	self:SetScale(EZPcfg.Scale)
	local backdrop = {bgFile = "Interface\\TutorialFrame\\TutorialFrameBackground", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", tile=true,tileSize = 16, edgeSize = 16, insets = { left = 3, right = 5, top = 3, bottom = 5 }}  -- path to the background texture
	self:SetBackdrop(backdrop)
	self:SetBackdropColor(0,0,0,0.8)
	self:SetWidth(82)
	self:SetHeight(48)
	self:SetPoint("TOPLEFT",EZPcfg.PosX,EZPcfg.PosY)
	self:SetMovable(1)
	self:EnableMouse(1)
	self:RegisterForDrag("LeftButton")
	self:SetScript("OnDragStart", EZP.ConfigFrame.StartMove)
	self:SetScript("OnDragStop", EZP.ConfigFrame.StopMove)
	
	self.ProfileButton = CreateFrame("Button",nil,self)
	self.ProfileButton:SetWidth(82)
	self.ProfileButton:SetHeight(12)
	self.ProfileButton:SetPoint("BOTTOM",self,"TOP",0,0)
	self.ProfileButton:SetScript("OnEnter", function() for j=1,7 do self.ProfileButton[j]:Show() end end)
	self.ProfileButton:SetScript("OnLeave", function() for j=1,7 do self.ProfileButton[j]:Hide() end end)
	
	for i=1,7 do
		if i == 1 then self.ProfileButton[i] = CreateFrame("Button", nil, self.ProfileButton); self.ProfileButton[i]:SetPoint("BOTTOM",self,"TOPLEFT", 11 , 0)
		else self.ProfileButton[i] = CreateFrame("Button", nil, self.ProfileButton[i-1]); self.ProfileButton[i]:SetPoint("LEFT",self.ProfileButton[i-1],"RIGHT", 3, 0) end
		self.ProfileButton[i]:SetID(i)
		self.ProfileButton[i]:SetWidth(7)
		self.ProfileButton[i]:SetHeight(7)
		self.ProfileButton[i]:SetScript("OnClick", function () 
			EZP:SetProfile(this:GetID())
		end)
		self.ProfileButton[i]:SetNormalTexture("Interface\\AddOns\\EzPoison\\Media\\buttonD")
		self.ProfileButton[i]:SetScript("OnEnter", function() for j=1,7 do self.ProfileButton[j]:Show() end end)
		self.ProfileButton[i]:SetScript("OnLeave", function() for j=1,7 do self.ProfileButton[j]:Hide() end end)
		self.ProfileButton[i]:Hide()
	end
	
	----------------------------------------------------------------------------
	-- Updated EzPoison GUI / Dropdown Setup
	-- Paste this into your "EZP.ConfigFrame:ConfigureUI()" where appropriate
	----------------------------------------------------------------------------

	-- First, replace your current MainHand/OffHand dropdown-building functions:
	local function MainHandDropDownFun()
		local info = {}

		-- Title row
		info.text = "MainHand"
		info.isTitle = 1
		UIDropDownMenu_AddButton(info)

		-- Actual list items
		info = {}
		for _, i in ipairs(EZP:GetValidPoisonIndices()) do
			info.text   = EZP.Work.Poison[i]         -- e.g. "Elemental Sharpening Stone"
			info.icon   = EZP.Work.PoisonIcon[i]     -- icon path
			info.value  = i                          -- store the REAL index from your table
			info.checked = false
			info.textR = 0.4; info.textG = 0.8; info.textB = 0.4
			info.isTitle = nil
			info.func = function()
				-- Instead of SetSelectedID, use SetSelectedValue
				UIDropDownMenu_SetSelectedValue(getglobal("EZPMainHandDD"), this.value)
				EZP:UpdateSelection()
				EZP:SaveProfiles()
			end
			UIDropDownMenu_AddButton(info)
		end

		-- "None" entry, treat as 0
		info = {}
		info.text     = "None"
		info.checked  = false
		info.value    = 0  -- we'll interpret 0 as "no selection"
		info.textR    = 1; info.textG = 1; info.textB = 1
		info.isTitle  = nil
		info.func = function()
			UIDropDownMenu_SetSelectedValue(getglobal("EZPMainHandDD"), 0)
			EZP:UpdateSelection()
			EZP:SaveProfiles()
		end
		UIDropDownMenu_AddButton(info)
	end

	local function OffHandDropDownFun()
		local info = {}

		-- Title row
		info.text = "OffHand"
		info.isTitle = 1
		UIDropDownMenu_AddButton(info)

		-- Actual list items
		info = {}
		for _, i in ipairs(EZP:GetValidPoisonIndices()) do
			info.text   = EZP.Work.Poison[i]
			info.icon   = EZP.Work.PoisonIcon[i]
			info.value  = i
			info.checked = false
			info.textR = 0.4; info.textG = 0.8; info.textB = 0.4
			info.isTitle = nil
			info.func = function()
				UIDropDownMenu_SetSelectedValue(getglobal("EZPOffHandDD"), this.value)
				EZP:UpdateSelection()
				EZP:SaveProfiles()
			end
			UIDropDownMenu_AddButton(info)
		end

		-- "None" entry
		info = {}
		info.text     = "None"
		info.checked  = false
		info.value    = 0
		info.textR    = 1; info.textG = 1; info.textB = 1
		info.isTitle  = nil
		info.func = function()
			UIDropDownMenu_SetSelectedValue(getglobal("EZPOffHandDD"), 0)
			EZP:UpdateSelection()
			EZP:SaveProfiles()
		end
		UIDropDownMenu_AddButton(info)
	end

	-- Now, define your main-hand/off-hand frames as before, 
	-- but ensure we call _SetSelectedValue initialization:
	self.MainHand = CreateFrame("Button", "EZPMHButton", self)
	self.MainHand.BorderDropdown = CreateFrame("Frame","EZPMainHandDD", self, "UIDropDownMenuTemplate")
	UIDropDownMenu_Initialize(getglobal("EZPMainHandDD"), MainHandDropDownFun, "MENU")

	self.MainHand:SetWidth(32)
	self.MainHand:SetHeight(32)
	self.MainHand:SetPoint("LEFT",7,0)
	self.MainHand:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	self.MainHand:SetScript("OnClick", function()
		if arg1 == "LeftButton" then
			EZP:ApplyPoisen("MH")
		elseif arg1 == "RightButton" then
			ToggleDropDownMenu(1, nil, self.MainHand.BorderDropdown, self.OffHand, 0, 0)
		end
	end)
	self.MainHand:SetScript("OnEnter", function()
		self.MainHand.Background:SetVertexColor(1, 1, 1, 1)
		local id = EZP:GetInventoryID("MH")
		if id then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink("item:"..id[4])
			GameTooltip:Show()
		end
	end)
	self.MainHand:SetScript("OnLeave", function ()
		self.MainHand.Background:SetVertexColor(1, 1, 1, 0)
		GameTooltip:Hide()
	end)
	self.MainHand:SetNormalTexture("Interface\\Buttons\\UI-Quickslot-Depress")

	-- Glow
	self.MainHand.Background = self:CreateTexture(self,"BACKGROUND")
	self.MainHand.Background:SetPoint("CENTER",self.MainHand,"CENTER",0,0)
	self.MainHand.Background:SetWidth(36)
	self.MainHand.Background:SetHeight(36)
	self.MainHand.Background:SetTexture("Interface\\Buttons\\CheckButtonHilight")
	self.MainHand.Background:SetVertexColor(1, 1, 1, 0)
	self.MainHand.Background:SetBlendMode("ADD")

	-- Count text
	self.MainHand.Font = self.MainHand:CreateFontString(nil, "OVERLAY")
	self.MainHand.Font:SetPoint("BOTTOMRIGHT", -3, 3)
	self.MainHand.Font:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
	self.MainHand.Font:SetTextColor(0.8,0.8,0.8)

	------------------------------------------------
	-- OffHand
	------------------------------------------------
	self.OffHand = CreateFrame("Button", nil, self)
	self.OffHand.BorderDropdown = CreateFrame("Frame","EZPOffHandDD", self, "UIDropDownMenuTemplate")
	UIDropDownMenu_Initialize(getglobal("EZPOffHandDD"), OffHandDropDownFun, "MENU")

	self.OffHand:SetWidth(32)
	self.OffHand:SetHeight(32)
	self.OffHand:SetPoint("RIGHT",-7,0)
	self.OffHand:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	self.OffHand:SetScript("OnClick", function ()
		if arg1 == "LeftButton" then
			EZP:ApplyPoisen("OH")
		elseif arg1 == "RightButton" then
			ToggleDropDownMenu(1, nil, self.OffHand.BorderDropdown, self.OffHand, 0, 0)
		end
	end)
	self.OffHand:SetScript("OnEnter", function()
		self.OffHand.Background:SetVertexColor(1, 1, 1, 1)
		local id = EZP:GetInventoryID("OH")
		if id then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink("item:"..id[4])
			GameTooltip:Show()
		end
	end)
	self.OffHand:SetScript("OnLeave", function()
		self.OffHand.Background:SetVertexColor(1, 1, 1, 0)
		GameTooltip:Hide()
	end)
	self.OffHand:SetNormalTexture("Interface\\Buttons\\UI-Quickslot-Depress")

	-- Glow
	self.OffHand.Background = self:CreateTexture(self,"BACKGROUND")
	self.OffHand.Background:SetPoint("CENTER", self.OffHand,"CENTER",0,0)
	self.OffHand.Background:SetWidth(36)
	self.OffHand.Background:SetHeight(36)
	self.OffHand.Background:SetTexture("Interface\\Buttons\\CheckButtonHilight")
	self.OffHand.Background:SetVertexColor(1, 1, 1, 0)
	self.OffHand.Background:SetBlendMode("ADD")

	-- Count text
	self.OffHand.Font = self.OffHand:CreateFontString(nil, "OVERLAY")
	self.OffHand.Font:SetPoint("BOTTOMRIGHT", -3, 3)
	self.OffHand.Font:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
	self.OffHand.Font:SetTextColor(0.8,0.8,0.8)

	------------------------------------------------
	-- Final Show/Hide
	------------------------------------------------
	self:SetScript("OnShow",function() EZPcfg.isVisible = 1 end)
	self:SetScript("OnHide",function() EZPcfg.isVisible = nil end)
	if not EZPcfg.isVisible then EZP.ConfigFrame:Hide() end
end

-- workarround for the fact that temp. enchants are not loaded at the addon start
function EZP:AddonStart()
	EZP.Work.Time = EZP.Work.Time + arg1
	if EZP.Work.Time >= 2 then
		EZP.Work.Time = 0
		EZP.ConfigFrame:SetScript("OnUpdate",nil)
		EZP:UpdateTexture()
	end
end

function EZP:ConfigFubar()
	local options = {
		handler = EZP.ACE,
		type = "group",
		args = {
			Profile1 = {
				name = EZPcfg.Profile[1].Name,
				type = "group",
				desc = "Profile 1 modification.",
				order = 1,
				args = {
					Profiletoggle = {
					type = 'toggle',
					name = "Use",
					desc = "Enable this profile.",
					get = function () end,
					set = function () EZP:SetProfile(1) end,
					order = 1,
					},
					Profileuse = {
						type = 'text',
						name = "Rename",
						desc = "Rename this Profile",
						get = function () end,
						set = function (value)
							if not value or value == "" then value = "Profile 1" end
							EZPcfg.Profile[1].Name = value
							DEFAULT_CHAT_FRAME:AddMessage("EzPoison: ".."|cFFFFFFFF".."Profile 1 renamed to: ".."|cFFCC9900"..EZPcfg.Profile[1].Name.."|r".."|cFFFFFFFF"..".".."|r",0.4,0.8,0.4)
						end,
						usage = "Renaming",
						order = 2,
					},
				},
			},
			Profile2 = {
				name = EZPcfg.Profile[2].Name,
				type = "group",
				desc = "Profile 2 modification.",
				order = 2,
				args = {
					Profiletoggle = {
					type = 'toggle',
					name = "Use",
					desc = "Enable this profile.",
					get = function () end,
					set = function () EZP:SetProfile(2) end,
					order = 1,
					},
					Profileuse = {
						type = 'text',
						name = "Rename",
						desc = "Rename this Profile",
						get = function () end,
						set = function (value)
							if not value or value == "" then value = "Profile 2" end
							EZPcfg.Profile[2].Name = value
							DEFAULT_CHAT_FRAME:AddMessage("EzPoison: ".."|cFFFFFFFF".."Profile 2 renamed to: ".."|cFFCC9900"..EZPcfg.Profile[2].Name.."|r".."|cFFFFFFFF"..".".."|r",0.4,0.8,0.4)
						end,
						usage = "Renaming",
						order = 2,
					},
				},
			},
			Profile3 = {
				name = EZPcfg.Profile[3].Name,
				type = "group",
				desc = "Profile 3 modification.",
				order = 3,
				args = {
					Profiletoggle = {
					type = 'toggle',
					name = "Use",
					desc = "Enable this profile.",
					get = function () end,
					set = function () EZP:SetProfile(3) end,
					order = 1,
					},
					Profileuse = {
						type = 'text',
						name = "Rename",
						desc = "Rename this Profile",
						get = function () end,
						set = function (value)
							if not value or value == "" then value = "Profile 3" end
							EZPcfg.Profile[3].Name = value
							DEFAULT_CHAT_FRAME:AddMessage("EzPoison: ".."|cFFFFFFFF".."Profile 3 renamed to: ".."|cFFCC9900"..EZPcfg.Profile[3].Name.."|r".."|cFFFFFFFF"..".".."|r",0.4,0.8,0.4)
						end,
						usage = "Renaming",
						order = 2,
					},
				},
			},
			Profile4 = {
				name = EZPcfg.Profile[4].Name,
				type = "group",
				desc = "Profile 4 modification.",
				order = 4,
				args = {
					Profiletoggle = {
					type = 'toggle',
					name = "Use",
					desc = "Enable this profile.",
					get = function () end,
					set = function () EZP:SetProfile(4) end,
					order = 1,
					},
					Profileuse = {
						type = 'text',
						name = "Rename",
						desc = "Rename this Profile",
						get = function () end,
						set = function (value)
							if not value or value == "" then value = "Profile 4" end
							EZPcfg.Profile[4].Name = value
							DEFAULT_CHAT_FRAME:AddMessage("EzPoison: ".."|cFFFFFFFF".."Profile 4 renamed to: ".."|cFFCC9900"..EZPcfg.Profile[4].Name.."|r".."|cFFFFFFFF"..".".."|r",0.4,0.8,0.4)
						end,
						usage = "Renaming",
						order = 2,
					},
				},
			},
			Profile5 = {
				name = EZPcfg.Profile[5].Name,
				type = "group",
				desc = "Profile 5 modification.",
				order = 5,
				args = {
					Profiletoggle = {
					type = 'toggle',
					name = "Use",
					desc = "Enable this profile.",
					get = function () end,
					set = function () EZP:SetProfile(5) end,
					order = 1,
					},
					Profileuse = {
						type = 'text',
						name = "Rename",
						desc = "Rename this Profile",
						get = function () end,
						set = function (value)
							if not value or value == "" then value = "Profile 5" end
							EZPcfg.Profile[5].Name = value
							DEFAULT_CHAT_FRAME:AddMessage("EzPoison: ".."|cFFFFFFFF".."Profile 5 renamed to: ".."|cFFCC9900"..EZPcfg.Profile[5].Name.."|r".."|cFFFFFFFF"..".".."|r",0.4,0.8,0.4)
						end,
						usage = "Renaming",
						order = 2,
					},
				},
			},
			Profile6 = {
				name = EZPcfg.Profile[6].Name,
				type = "group",
				desc = "Profile 6 modification.",
				order = 6,
				args = {
					Profiletoggle = {
					type = 'toggle',
					name = "Use",
					desc = "Enable this profile.",
					get = function () end,
					set = function () EZP:SetProfile(6) end,
					order = 1,
					},
					Profileuse = {
						type = 'text',
						name = "Rename",
						desc = "Rename this Profile",
						get = function () end,
						set = function (value)
							if not value or value == "" then value = "Profile 6" end
							EZPcfg.Profile[6].Name = value
							DEFAULT_CHAT_FRAME:AddMessage("EzPoison: ".."|cFFFFFFFF".."Profile 6 renamed to: ".."|cFFCC9900"..EZPcfg.Profile[6].Name.."|r".."|cFFFFFFFF"..".".."|r",0.4,0.8,0.4)
						end,
						usage = "Renaming",
						order = 2,
					},
				},
			},
			Profile7 = {
				name = EZPcfg.Profile[7].Name,
				type = "group",
				desc = "Profile 7 modification.",
				order = 7,
				args = {
					Profiletoggle = {
					type = 'toggle',
					name = "Use",
					desc = "Enable this profile.",
					get = function () end,
					set = function () EZP:SetProfile(7) end,
					order = 1,
					},
					Profileuse = {
						type = 'text',
						name = "Rename",
						desc = "Rename this Profile",
						get = function () end,
						set = function (value)
							if not value or value == "" then value = "Profile 7" end
							EZPcfg.Profile[7].Name = value
							DEFAULT_CHAT_FRAME:AddMessage("EzPoison: ".."|cFFFFFFFF".."Profile 7 renamed to: ".."|cFFCC9900"..EZPcfg.Profile[7].Name.."|r".."|cFFFFFFFF"..".".."|r",0.4,0.8,0.4)
						end,
						usage = "Renaming",
						order = 2,
					},
				},
			},
			scaling = {
				type = "range",
				name = "Window Scale",
				desc = "Window Scale of the UI.",
				min = 0.5,
				max = 2,
				step = 0.1,
				get = function()
					return EZPcfg.Scale
				end,
				set = function(value)
					EZPcfg.Scale  = value
				end,
				order = 8,
			},
			apply = {
				type = 'toggle',
				name = "Apply Scale",
				desc = "Apply the chosen window scale.",
				get = function () end,
				set = function () 
					EZP.ConfigFrame:SetScale(EZPcfg.Scale)
					EZPcfg.PosX = 200
					EZPcfg.PosY = -200
					EZP.ConfigFrame:SetPoint("TOPLEFT",EZPcfg.PosX,EZPcfg.PosY) 
				end,
				order = 9,
			},
		},
	}
	EZP.ACE.OnMenuRequest = options
end

function EZP:UpdateTexture()
    -- No longer setting alpha here; defer to UpdatePoisonCount
    EZP:UpdatePoisonCount()
end

function EZP:UpdatePoisonCount()
    -- Main Hand Count and Alpha
    local countMH = 0
    local id = EZP:GetInventoryID("MH")
    if id then
        local targetItemID = id[4] -- Item ID from GetInventoryID
        for bag = 0, 4 do
            local numSlots = GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local _, _, itemIDStr = string.find(link, "item:(%d+)")
                    if itemIDStr then
                        local itemID = tonumber(itemIDStr)
                        if itemID and itemID == targetItemID then
                            local _, count = GetContainerItemInfo(bag, slot)
                            countMH = countMH + count
                        end
                    end
                end
            end
        end
    end
    EZP.ConfigFrame.MainHand.Font:SetText(countMH)
    if countMH > 0 then
        EZP.ConfigFrame.MainHand:SetAlpha(1) -- Fully opaque
    else
        EZP.ConfigFrame.MainHand:SetAlpha(0.2) -- Faded
    end

    -- Off Hand Count and Alpha
    local countOH = 0
    id = EZP:GetInventoryID("OH")
    if id then
        local targetItemID = id[4] -- Item ID from GetInventoryID
        for bag = 0, 4 do
            local numSlots = GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local _, _, itemIDStr = string.find(link, "item:(%d+)")
                    if itemIDStr then
                        local itemID = tonumber(itemIDStr)
                        if itemID and itemID == targetItemID then
                            local _, count = GetContainerItemInfo(bag, slot)
                            countOH = countOH + count
                        end
                    end
                end
            end
        end
    end
    EZP.ConfigFrame.OffHand.Font:SetText(countOH)
    if countOH > 0 then
        EZP.ConfigFrame.OffHand:SetAlpha(1) -- Fully opaque
    else
        EZP.ConfigFrame.OffHand:SetAlpha(0.2) -- Faded
    end
end

-- Helper function to convert numbers to Roman numerals for ranked poisons
function EZP:RomanNumeral(num)
    local roman = {"I", "II", "III", "IV", "V", "VI"}
    return roman[num] or ""
end

--------------------------------------------------------------------------
-- GET INVENTORY ID - uses selected "value" instead of the old "ID"
--------------------------------------------------------------------------
function EZP:GetInventoryID(hand)
    if not hand then return nil end

    local index
    if hand == "MH" then
        index = UIDropDownMenu_GetSelectedValue(EZP.ConfigFrame.MainHand.BorderDropdown)
    elseif hand == "OH" then
        index = UIDropDownMenu_GetSelectedValue(EZP.ConfigFrame.OffHand.BorderDropdown)
    end
    
    -- If "None" was chosen or nothing is set:
    if not index or index == 0 then
        return nil
    end

    -- Grab the actual name & itemIDs from your tables
    local poisonName = EZP.Work.Poison[index]
    local poisonIDs  = EZP.Work.PoisonID[index]

    if not poisonName or not poisonIDs then
        return nil
    end

    -- If multiple ranks:
    if type(poisonIDs) == "table" then
        -- (same logic as your code: check highest rank first, etc.)
        for rank = table.getn(poisonIDs), 1, -1 do
            local rankStr = (rank == 1) and "" or " "..EZP:RomanNumeral(rank)
            local fullName = poisonName .. rankStr
            -- search all bags for the item with this name
            for bag = 0, 4 do
                local numSlots = GetContainerNumSlots(bag)
                for slot = 1, numSlots do
                    local link = GetContainerItemLink(bag, slot)
                    if link then
                        local itemName = gsub(link, "^.*%[(.*)%].*$", "%1")
                        if itemName == fullName then
                            return {bag, slot, rankStr, poisonIDs[rank], index}
                        end
                    end
                end
            end
        end
    else
        -- single item
        for bag = 0, 4 do
            local numSlots = GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local itemName = gsub(link, "^.*%[(.*)%].*$", "%1")
                    if itemName == poisonName then
                        return {bag, slot, "", poisonIDs, index}
                    end
                end
            end
        end
    end

    return nil
end

function EZP:ApplyPoisen(hand)
	EZP:UpdateTexture()
	if hand and not EZP.Work.iSCasting then
		local id = EZP:GetInventoryID(hand)
		if id then
			EZP:RegisterEvent("SPELLCAST_START")
			EZP:RegisterEvent("SPELLCAST_STOP")
			EZP:RegisterEvent("SPELLCAST_INTERRUPTED")
			EZP:RegisterEvent("SPELLCAST_FAILED")
			UseContainerItem(id[1], id[2])
			if hand == "MH" then PickupInventoryItem(16)
			elseif hand == "OH" then PickupInventoryItem(17) end
			ReplaceEnchant()
			ClearCursor()
		else
			if hand == "MH" and UIDropDownMenu_GetSelectedID(EZP.ConfigFrame.MainHand.BorderDropdown) ~= 1 and UIDropDownMenu_GetSelectedID(EZP.ConfigFrame.MainHand.BorderDropdown) ~= 7 then
				 DEFAULT_CHAT_FRAME:AddMessage("EzPoison: ".."|cFFCC9900".."MainHand ".."|r".."|cFFFFFFFF".."Poison not found.".."|r",0.4,0.8,0.4)
			elseif hand == "OH" and UIDropDownMenu_GetSelectedID(EZP.ConfigFrame.OffHand.BorderDropdown) ~= 1 and UIDropDownMenu_GetSelectedID(EZP.ConfigFrame.OffHand.BorderDropdown) ~= 7 then
				DEFAULT_CHAT_FRAME:AddMessage("EzPoison: ".."|cFFCC9900".."OffHand ".."|r".."|cFFFFFFFF".."Poison not found.".."|r",0.4,0.8,0.4) 
			end
		end
	end
end

function EZP:AutoApplyPoison()
	EZP:UpdateTexture()
	if EZP.ConfigFrame.MainHand:GetAlpha() < 1 then
		EZP:ApplyPoisen("MH")
	elseif EZP.ConfigFrame.OffHand:GetAlpha() < 1 then
		EZP:ApplyPoisen("OH")
	end
end

--------------------------------------------------------------------------
-- SAVE PROFILES - store the selected "value" (index) rather than selected ID
--------------------------------------------------------------------------
function EZP:SaveProfiles()
    local MH = UIDropDownMenu_GetSelectedValue(EZP.ConfigFrame.MainHand.BorderDropdown)
    local OH = UIDropDownMenu_GetSelectedValue(EZP.ConfigFrame.OffHand.BorderDropdown)

    -- We’ll just store 0 if "None" was chosen, or else the actual index
    if not MH then MH = 0 end
    if not OH then OH = 0 end

    EZPcfg.Profile[EZPcfg.CurrentProfile].MainHand = MH
    EZPcfg.Profile[EZPcfg.CurrentProfile].OffHand  = OH
end

--------------------------------------------------------------------------
-- SETPROFILE - Loads the saved MH/OH selection for the chosen profile
--------------------------------------------------------------------------
function EZP:SetProfile(profileNum)
    if profileNum then
        EZPcfg.CurrentProfile = profileNum
    end

    -- Highlight the chosen profile’s button in the UI
    for i = 1, 7 do
        EZP.ConfigFrame.ProfileButton[i]:SetNormalTexture("Interface\\AddOns\\EzPoison\\Media\\buttonD")
    end
    EZP.ConfigFrame.ProfileButton[EZPcfg.CurrentProfile]
        :SetNormalTexture("Interface\\AddOns\\EzPoison\\Media\\buttonDselected")

    -- Retrieve the previously saved “value” (the index in EZP.Work.Poison)
    local MHValue = EZPcfg.Profile[EZPcfg.CurrentProfile].MainHand or 0
    local OHValue = EZPcfg.Profile[EZPcfg.CurrentProfile].OffHand  or 0

    -- Now set the dropdown selection by *value* (not by ID+1)
    UIDropDownMenu_SetSelectedValue(getglobal("EZPMainHandDD"), MHValue)
    UIDropDownMenu_SetSelectedValue(getglobal("EZPOffHandDD"),  OHValue)

    -- Force the UI to refresh and show correct icons
    EZP:UpdateSelection()
end


--------------------------------------------------------------------------
-- UPDATE SELECTION - set the button icons based on the "value"
--------------------------------------------------------------------------
function EZP:UpdateSelection()
    local MH = UIDropDownMenu_GetSelectedValue(EZP.ConfigFrame.MainHand.BorderDropdown)
    local OH = UIDropDownMenu_GetSelectedValue(EZP.ConfigFrame.OffHand.BorderDropdown)

    if MH and MH > 0 then
        EZP.ConfigFrame.MainHand:SetNormalTexture(EZP.Work.PoisonIcon[MH])
    else
        EZP.ConfigFrame.MainHand:SetNormalTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    end

    if OH and OH > 0 then
        EZP.ConfigFrame.OffHand:SetNormalTexture(EZP.Work.PoisonIcon[OH])
    else
        EZP.ConfigFrame.OffHand:SetNormalTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    end

    -- Make sure to refresh your count displays (faded or not) too
    EZP:UpdateTexture()
end

--additonal feature/ hooking temp-enchant OnUpdate function
function EZP:BuffFrame_Enchant_OnUpdate(elapsed)
	local hasMainHandEnchant, mainHandExpiration, mainHandCharges, hasOffHandEnchant, offHandExpiration, offHandCharges = GetWeaponEnchantInfo();
	
	-- No enchants, kick out early
	if ( not hasMainHandEnchant and not hasOffHandEnchant ) then
		TempEnchant1:Hide();
		TempEnchant1Duration:Hide();
		TempEnchant2:Hide();
		TempEnchant2Duration:Hide();
		BuffFrame:SetPoint("TOPRIGHT", "TemporaryEnchantFrame", "TOPRIGHT", 0, 0);
		return;
	end
	-- Has enchants
	local enchantButton;
	local textureName;
	local buffAlphaValue;
	local enchantIndex = 0;
	if ( hasOffHandEnchant ) then
		enchantIndex = enchantIndex + 1;
		textureName = GetInventoryItemTexture("player", 17);
		TempEnchant1:SetID(17);
		TempEnchant1Icon:SetTexture(textureName);
		TempEnchant1:Show();
		hasEnchant = 1;

		-- Show buff durations if necessary
		if ( offHandExpiration ) then
			offHandExpiration = offHandExpiration/1000;
		end
		if offHandCharges and offHandCharges > 0 then getglobal("TempEnchant1".."Count"):SetText(offHandCharges) end
		BuffFrame_UpdateDuration(TempEnchant1, offHandExpiration);

		-- Handle flashing
		if ( offHandExpiration and offHandExpiration < BUFF_WARNING_TIME ) then
			TempEnchant1:SetAlpha(BUFF_ALPHA_VALUE);
		else
			TempEnchant1:SetAlpha(1.0);
		end
		
	end
	if ( hasMainHandEnchant ) then
		enchantIndex = enchantIndex + 1;
		enchantButton = getglobal("TempEnchant"..enchantIndex);
		textureName = GetInventoryItemTexture("player", 16);
		enchantButton:SetID(16);
		getglobal(enchantButton:GetName().."Icon"):SetTexture(textureName);
		enchantButton:Show();
		hasEnchant = 1;

		-- Show buff durations if necessary
		if ( mainHandExpiration ) then
			mainHandExpiration = mainHandExpiration/1000;
		end
		if mainHandCharges and mainHandCharges > 0 then getglobal("TempEnchant2".."Count"):SetText(mainHandCharges) end
		BuffFrame_UpdateDuration(enchantButton, mainHandExpiration);

		-- Handle flashing
		if ( mainHandExpiration and mainHandExpiration < BUFF_WARNING_TIME ) then
			enchantButton:SetAlpha(BUFF_ALPHA_VALUE);
		else
			enchantButton:SetAlpha(1.0);
		end
	end
	--Hide unused enchants
	for i=enchantIndex+1, 2 do
		getglobal("TempEnchant"..i):Hide();
		getglobal("TempEnchant"..i.."Duration"):Hide();
	end

	-- Position buff frame
	TemporaryEnchantFrame:SetWidth(enchantIndex * 32);
	BuffFrame:SetPoint("TOPRIGHT", "TemporaryEnchantFrame", "TOPLEFT", -5, 0);
end

BuffFrame_Enchant_OnUpdate = EZP.BuffFrame_Enchant_OnUpdate

-- prompt
function EzPoisonPromt(arg1)
	if string.sub(arg1, 1, 5) == "scale" then
		local scale = tonumber(string.sub(arg1, 6, string.len(arg1)))
		if scale <=3 and scale >= 0.3 then EZPcfg.Scale = scale end
		EZP.ConfigFrame:SetScale(EZPcfg.Scale)
		EZPcfg.PosX = 200
		EZPcfg.PosY = -200
		EZP.ConfigFrame:SetPoint("TOPLEFT",EZPcfg.PosX,EZPcfg.PosY)
	
	elseif string.sub(arg1, 1, 5) == "apply" then
		EZP:AutoApplyPoison()
		
	elseif string.sub(arg1, 1, 7) == "profile" then
		local num = tonumber(string.sub(arg1, 8, string.len(arg1)))
		if num <=7 and num >= 1 then
			EZP:SetProfile(num)
		end
		
	elseif arg1 == nil or arg1 == "" then
		if EZP.ConfigFrame:IsVisible() then EZP.ConfigFrame:Hide()
		else EZP:UpdateTexture(); EZP.ConfigFrame:Show() end
	end
end
function EzPoisonProfile(num) EZP:SetProfile(num) end
function EzPoisonApply() EZP:AutoApplyPoison() end
function EzPoisonToggle()
	if EZP.ConfigFrame:IsVisible() then EZP.ConfigFrame:Hide()
	else EZP:UpdateTexture(); EZP.ConfigFrame:Show() end
end

-- binding list
BINDING_HEADER_HEAD = "EzPoison"

SlashCmdList['EZPOISON'] = EzPoisonPromt
SLASH_EZPOISON1 = '/ezpoison'
SLASH_EZPOISON2 = '/EzPoison'

function EZP:GetValidPoisonIndices()
    local _, class = UnitClass("player")

    if class == "ROGUE" then
        -- Poisons + Frost Oil only
        return {
            1, 2, 3, 4, 5, 6, 7, 8, 9,
            15,
            16, 18
        }

    elseif class == "WARRIOR" then
        -- Sharpening stones + Frost Oil
        return {
            10, 11, 15, 17
        }

    else
        -- Oils / stones / Frost Oil for other classes
        return {
            10, 11, 12, 13, 14, 15, 17
        }
    end
end

