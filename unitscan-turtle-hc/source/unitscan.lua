local unitscan = CreateFrame'Frame'
unitscan:SetScript('OnUpdate', function() unitscan.UPDATE() end)
unitscan:SetScript('OnEvent', function() 
	if event == "VARIABLES_LOADED" then
		unitscan.load_settings()
		unitscan.LOAD()
		unitscan.scan = true
		if not unitscan_settings.enabled then
			unitscan.print('scanning is off, type /unitscan to turn it on')
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		-- in combat
		-- disable scanning
		unitscan.incombat = true
		unitscan.scan = nil
	elseif event == "PLAYER_REGEN_ENABLED" then
		-- out of combat
		-- enable scanning
		unitscan.incombat = nil
		unitscan.scan = true
	elseif (event == "PLAYER_ENTER_COMBAT" or event == "START_AUTOREPEAT_SPELL") then
		-- melee autoattack / ranged autoattack enabled
		-- disable scanning if not in combat
		if not unitscan.incombat then
			unitscan.scan = nil
		end
	elseif (event == "STOP_AUTOREPEAT_SPELL" or event == "PLAYER_LEAVE_COMBAT") then
		-- melee / ranged autoattack disabled
		-- enable scanning if not in combat
		if not unitscan.incombat then
			unitscan.scan = true
		end
	else
		unitscan.load_zonetargets()
	end
	unitscan.config_refresh()
end)

unitscan:RegisterEvent'VARIABLES_LOADED'
unitscan:RegisterEvent'MINIMAP_ZONE_CHANGED'
unitscan:RegisterEvent'PLAYER_ENTERING_WORLD'
unitscan:RegisterEvent'PLAYER_REGEN_DISABLED' -- in combat
unitscan:RegisterEvent'PLAYER_REGEN_ENABLED' -- out of combat
unitscan:RegisterEvent'PLAYER_ENTER_COMBAT' -- melee autoattack enabled
unitscan:RegisterEvent'PLAYER_LEAVE_COMBAT' -- melee autoattack disabled
unitscan:RegisterEvent'START_AUTOREPEAT_SPELL' -- ranged autoattack enabled
unitscan:RegisterEvent'STOP_AUTOREPEAT_SPELL' -- ranged autoattack disabled

local BROWN = {.7, .15, .05}
local YELLOW = {1, 1, .15}
local CHECK_INTERVAL = 1

unitscan_targets = {}

local DEFAULTS = {
	enabled = true, -- scanning on/off
	sound = true, -- alert sound
	flash = true, -- red screen flash
	zonetargets = true, -- built-in list from zonetargets.lua
}

function unitscan.load_settings()
	if type(unitscan_settings) ~= 'table' then
		unitscan_settings = {}
	end
	for key, value in pairs(DEFAULTS) do
		if unitscan_settings[key] == nil then
			unitscan_settings[key] = value
		end
	end
end

do
	local last_played
	
	function unitscan.play_sound()
		if not last_played or GetTime() - last_played > 10 then
			SetCVar('MasterSoundEffects', 0)
			SetCVar('MasterSoundEffects', 1)
			-- PlaySoundFile[[Interface\AddOns\unitscan-turtle-hc\Event_wardrum_ogre.ogg]]
			-- PlaySoundFile[[Interface\AddOns\unitscan-turtle-hc\scourge_horn.ogg]]
			PlaySoundFile[[Interface\AddOns\unitscan-turtle-hc\gruntling_horn_bb.ogg]]
			last_played = GetTime()
		end
	end
end

function unitscan.alert()
	if unitscan_settings.sound then
		unitscan.play_sound()
	end
	if unitscan_settings.flash then
		unitscan.flash.animation:Play()
	end
	unitscan.button:set_target()
	unitscan.config_refresh()
end

function unitscan.load_zonetargets()
	unitscan_zone_targets()
end

do 
	local prevTarget
	local foundTarget
	local _PlaySound = PlaySound
	local _UIErrorsFrame_OnEvent = UIErrorsFrame_OnEvent
	local pass = function() end

	function unitscan.reset()
		prevTarget = nil
		foundTarget = nil
	end

	function unitscan.restoreTarget()
		if foundTarget and (not (prevTarget == foundTarget)) then
			PlaySound = pass
			TargetLastTarget()
			PlaySound = _PlaySound
		end
		unitscan.reset()
	end

	function unitscan.check_for_targets()
		for name, _ in unitscan_targets do
			if name == unitscan.target(name) then
				unitscan.foundTarget = name
				unitscan.toggle_target(name)
				unitscan.alert()
			end
			unitscan.restoreTarget()
		end

		if not unitscan_settings.zonetargets then return end

		for name, _ in unitscan_zonetargets do
			if strupper(name) == unitscan.target(name) then
				unitscan.foundTarget = name
				unitscan.toggle_zonetarget(name)
				unitscan.alert()
			end
			unitscan.restoreTarget()
		end
	end

	function unitscan.target(name)
		prevTarget = UnitName("target")		
		UIErrorsFrame_OnEvent = pass	
		PlaySound = pass
		TargetByName(name, true)
		UIErrorsFrame_OnEvent = _UIErrorsFrame_OnEvent
		PlaySound = _PlaySound

		foundTarget = UnitName("target")		
		-- Player target
		if UnitIsPlayer("target") then
			return foundTarget and strupper(foundTarget)
		-- NPC target
		elseif (not UnitIsDead("target")) and UnitCanAttack("target", "player") then
			return foundTarget and strupper(foundTarget)
		end
	end
end

function unitscan.LOAD()
	do
		local flash = CreateFrame'Frame'
		unitscan.flash = flash
		flash:Show()
		flash:SetAllPoints()
		flash:SetAlpha(0)
		flash:SetFrameStrata'FULLSCREEN_DIALOG'
		
		local texture = flash:CreateTexture()
		texture:SetBlendMode'ADD'
		texture:SetAllPoints()
		texture:SetTexture[[Interface\FullScreenTextures\LowHealth]]

		flash.animation = CreateFrame'Frame'
		flash.animation:Hide()
		flash.animation:SetScript('OnUpdate', function()
			local t = GetTime() - this.t0
			if t <= .5 then
				flash:SetAlpha(t * 2)
			elseif t <= 1 then
				flash:SetAlpha(1)
			elseif t <= 1.5 then
				flash:SetAlpha(1 - (t - 1) * 2)
			else
				flash:SetAlpha(0)
				this.loops = this.loops - 1
				if this.loops == 0 then
					this.t0 = nil
					this:Hide()
				else
					this.t0 = GetTime()
				end
			end
		end)
		function flash.animation:Play()
			if self.t0 then
				self.loops = 4
			else
				self.t0 = GetTime()
				self.loops = 3
			end
			self:Show()
		end
		function flash.animation:Stop()
			self.t0 = nil
			self:Hide()
			flash:SetAlpha(0)
		end
	end

	local button = CreateFrame("Button", "unitscan_button", UIParent)
	button:Hide()
	unitscan.button = button
	button:SetPoint('BOTTOM', UIParent, 0, 148)
	button:SetWidth(200)
	button:SetHeight(42)
	button:SetScale(1)
	button:SetMovable(true)
	button:SetUserPlaced(true)
	button:SetClampedToScreen(true)
	button:SetScript('OnMouseDown', function()
		if IsControlKeyDown() then
			this:RegisterForClicks()
			this:StartMoving()
		end
	end)
	button:SetScript('OnMouseUp', function()
		this:StopMovingOrSizing()
		this:RegisterForClicks'LeftButtonDown'
	end)
	button:SetFrameStrata'FULLSCREEN_DIALOG'
	
	button:SetBackdrop{
		tile = true,
		edgeSize = 16,
		edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
	}
	button:SetBackdropBorderColor(unpack(BROWN))
	button:SetScript('OnEnter', function()
		this:SetBackdropBorderColor(unpack(YELLOW))
	end)
	button:SetScript('OnLeave', function()
		this:SetBackdropBorderColor(unpack(BROWN))
	end)
	button:SetScript('OnClick', function()
		TargetByName(this:GetText(), true)
	end)
	function button:set_target()
		self:SetText(UnitName'target')

		self.model:reset()
		self.model:SetUnit'target'

		self:Show()
		self.glow.animation:Play()
		self.shine.animation:Play()
	end

	do
		local background = button:CreateTexture(nil, 'BACKGROUND')
		background:SetTexture[[Interface\AddOns\unitscan-turtle-hc\UI-Achievement-Parchment-Horizontal]]
		background:SetPoint('BOTTOMLEFT', 3, 3)
		background:SetPoint('TOPRIGHT', -3, -3)
		background:SetTexCoord(0, 1, 0, .25)
	end
	
	do
		local title_background = button:CreateTexture(nil, 'BORDER')
		title_background:SetTexture[[Interface\AddOns\unitscan-turtle-hc\UI-Achievement-Title]]
		title_background:SetPoint('TOPRIGHT', -5, -5)
		title_background:SetPoint('LEFT', 5, 0)
		title_background:SetHeight(18)
		title_background:SetTexCoord(0, .9765625, 0, .3125)
		title_background:SetAlpha(.8)

		local title = button:CreateFontString(nil, 'OVERLAY')
		title:SetFont([[Fonts\FRIZQT__.TTF]], 14)
		title:SetShadowOffset(1, -1)
		title:SetPoint('TOPLEFT', title_background, 0, 0)
		title:SetPoint('RIGHT', title_background)
		button:SetFontString(title)

		local subtitle = button:CreateFontString(nil, 'OVERLAY')
		subtitle:SetFont([[Fonts\FRIZQT__.TTF]], 12)
		subtitle:SetTextColor(0, 0, 0)
		subtitle:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -4)
		subtitle:SetPoint('RIGHT', title )
		subtitle:SetText'Unit Found!'
	end
	
	do
		local model = CreateFrame('PlayerModel', nil, button)
		button.model = model
		model:SetPoint('BOTTOMLEFT', button, 'TOPLEFT', 0, 10)
		model:SetPoint('RIGHT', 0, 0)
		model:SetHeight(button:GetWidth() * .6)
		
		do
			local last_update, delay
			function model:on_update()
				this:SetFacing(this:GetFacing() + (GetTime() - last_update) * math.pi / 4)
				last_update = GetTime()
			end
			
			function model:on_update_model()
				if delay > 0 then
					delay = delay - 1
					return
				end
				
				this:SetScript('OnUpdateModel', nil)
				this:SetScript('OnUpdate', this.on_update)
				this:SetModelScale(1)
				this:SetAlpha(1)	
				last_update = GetTime()
			end
			
			function model:reset()
				self:SetAlpha(0)
				self:SetFacing(0)
				self:SetModelScale(1)
				self:ClearModel()
				self:SetScript('OnUpdate', nil)
				self:SetScript("OnUpdateModel", self.on_update_model)
				delay = 10 -- to prevent scaling bugs
			end
		end
	end
	
	do
		local close = CreateFrame('Button', nil, button, 'UIPanelCloseButton')
		close:SetPoint('TOPRIGHT', 0, 0)
		close:SetWidth(32)
		close:SetHeight(32)
		close:SetScale(.8)
		close:SetHitRectInsets(8, 8, 8, 8)
	end
	
	do
		local glow = button.model:CreateTexture(nil, 'OVERLAY')
		button.glow = glow
		glow:SetPoint('CENTER', button, 'CENTER')
		glow:SetWidth(400 / 300 * button:GetWidth())
		glow:SetHeight(171 / 70 * button:GetHeight())
		glow:SetTexture[[Interface\AddOns\unitscan-turtle-hc\UI-Achievement-Alert-Glow]]
		glow:SetBlendMode'ADD'
		glow:SetTexCoord(0, .78125, 0, .66796875)
		glow:SetAlpha(0)

		glow.animation = CreateFrame'Frame'
		glow.animation:Hide()
		glow.animation:SetScript('OnUpdate', function()
			local t = GetTime() - this.t0
			if t <= .2 then
				glow:SetAlpha(t * 5)
			elseif t <= .7 then
				glow:SetAlpha(1 - (t - .2) * 2)
			else
				glow:SetAlpha(0)
				this:Hide()
			end
		end)
		function glow.animation:Play()
			self.t0 = GetTime()
			self:Show()
		end
	end

	do
		local shine = button:CreateTexture(nil, 'ARTWORK')
		button.shine = shine
		shine:SetPoint('TOPLEFT', button, 0, 8)
		shine:SetWidth(67 / 300 * button:GetWidth())
		shine:SetHeight(1.28 * button:GetHeight())
		shine:SetTexture[[Interface\AddOns\unitscan-turtle-hc\UI-Achievement-Alert-Glow]]
		shine:SetBlendMode'ADD'
		shine:SetTexCoord(.78125, .912109375, 0, .28125)
		shine:SetAlpha(0)
		
		shine.animation = CreateFrame'Frame'
		shine.animation:Hide()
		shine.animation:SetScript('OnUpdate', function()
			local t = GetTime() - this.t0
			if t <= .3 then
				shine:SetPoint('TOPLEFT', button, 0, 8)
			elseif t <= .7 then
				shine:SetPoint('TOPLEFT', button, (t - .3) * 2.5 * this.distance, 8)
			end
			if t <= .3 then
				shine:SetAlpha(0)
			elseif t <= .5 then
				shine:SetAlpha(1)
			elseif t <= .7 then
				shine:SetAlpha(1 - (t - .5) * 5)
			else
				shine:SetAlpha(0)
				this:Hide()
			end
		end)
		function shine.animation:Play()
			self.t0 = GetTime()
			self.distance = button:GetWidth() - shine:GetWidth() + 8
			self:Show()
		end
	end
end

do
	unitscan.last_check = GetTime()
	function unitscan.UPDATE()
		-- unitscan.button exists once LOAD has run, after the settings are loaded
		if unitscan.scan and unitscan.button and unitscan_settings.enabled then
			if GetTime() - unitscan.last_check >= CHECK_INTERVAL then
				unitscan.last_check = GetTime()
				if (unitscan.reloadtimer and (unitscan.last_check >= unitscan.reloadtimer)) then
					unitscan.reloadtimer = nil
					unitscan.load_zonetargets()			
					-- unitscan.print('reloaded zone targets')
				end				
				unitscan.check_for_targets()
			end
		end
	end
end

function unitscan.print(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(LIGHTYELLOW_FONT_COLOR_CODE .. '<unitscan> ' .. msg)
	end
end

function unitscan.sorted_targets()
	local sorted_targets = {}
	for key in pairs(unitscan_targets) do
		tinsert(sorted_targets, key)
	end
	sort(sorted_targets, function(key1, key2) return key1 < key2 end)
	return sorted_targets
end

function unitscan.sorted_zonetargets()
	local sorted_targets = {}
	for key in pairs(unitscan_zonetargets) do
		tinsert(sorted_targets, key)
	end
	sort(sorted_targets, function(key1, key2) return key1 < key2 end)
	return sorted_targets
end

function unitscan.toggle_target(name)
	local key = strupper(name)
	if unitscan_targets[key] then
		unitscan_targets[key] = nil
		unitscan.print('- ' .. key)
	elseif key ~= '' then
		unitscan_targets[key] = true
		unitscan.print('+ ' .. key)
	end
end

function unitscan.toggle_zonetarget(name)
	local key = name
	if unitscan_zonetargets[key] then
		unitscan.print(key .. ' was found!')
		unitscan_zonetargets[key] = nil
		unitscan.reloadtimer = GetTime() + 90
	end
end

function unitscan.print_targets()
	unitscan.print("Added targets:")
	for _, key in ipairs(unitscan.sorted_targets()) do
		unitscan.print(key)
	end
	-- zone targets
	unitscan.print("Zone targets:")
	for _, key in ipairs(unitscan.sorted_zonetargets()) do
		unitscan.print(key)
	end
end

function unitscan.set_enabled(enabled)
	unitscan_settings.enabled = enabled
	if enabled then
		unitscan.print('scanning on')
	else
		-- dismiss an alert that is still showing
		unitscan.button:Hide()
		unitscan.flash.animation:Stop()
		unitscan.print('scanning off')
	end
	unitscan.config_refresh()
end

function unitscan.count_zonetargets()
	local count = 0
	for _ in pairs(unitscan_zonetargets or {}) do
		count = count + 1
	end
	return count
end

function unitscan.config_create()
	local frame = CreateFrame('Frame', 'unitscan_config', UIParent)
	unitscan.config = frame
	frame:Hide()
	frame:SetWidth(320)
	frame:SetHeight(328)
	frame:SetPoint('CENTER', UIParent, 0, 80)
	frame:SetFrameStrata'DIALOG'
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag'LeftButton'
	frame:SetScript('OnDragStart', function() this:StartMoving() end)
	frame:SetScript('OnDragStop', function() this:StopMovingOrSizing() end)
	frame:SetScript('OnShow', function() unitscan.config_refresh() end)
	frame:SetBackdrop{
		bgFile = [[Interface\DialogFrame\UI-DialogBox-Background]],
		edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = {left = 11, right = 12, top = 12, bottom = 11},
	}
	-- close with Escape
	tinsert(UISpecialFrames, 'unitscan_config')

	do
		local header = frame:CreateTexture(nil, 'ARTWORK')
		header:SetTexture[[Interface\DialogFrame\UI-DialogBox-Header]]
		header:SetWidth(256)
		header:SetHeight(64)
		header:SetPoint('TOP', 0, 12)

		local title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
		title:SetPoint('TOP', header, 0, -14)
		title:SetText'unitscan'

		local close = CreateFrame('Button', nil, frame, 'UIPanelCloseButton')
		close:SetPoint('TOPRIGHT', -6, -6)
	end

	do
		local status = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
		frame.status = status
		status:SetPoint('TOP', 0, -32)

		local toggle = CreateFrame('Button', 'unitscan_config_toggle', frame, 'UIPanelButtonTemplate')
		frame.toggle = toggle
		toggle:SetWidth(160)
		toggle:SetHeight(24)
		toggle:SetPoint('TOP', 0, -52)
		toggle:SetScript('OnClick', function()
			unitscan.set_enabled(not unitscan_settings.enabled)
		end)
	end

	do
		local function checkbox(key, label, y)
			local check = CreateFrame('CheckButton', 'unitscan_config_' .. key, frame, 'UICheckButtonTemplate')
			frame[key] = check
			check:SetWidth(26)
			check:SetHeight(26)
			check:SetPoint('TOPLEFT', 20, y)
			getglobal(check:GetName() .. 'Text'):SetText(label)
			check:SetScript('OnClick', function()
				if this:GetChecked() then
					PlaySound'igMainMenuOptionCheckBoxOn'
				else
					PlaySound'igMainMenuOptionCheckBoxOff'
				end
				unitscan_settings[key] = this:GetChecked() and true or false
				unitscan.config_refresh()
			end)
		end
		checkbox('sound', 'Play the alert sound', -86)
		checkbox('flash', 'Flash the screen', -112)
		checkbox('zonetargets', 'Scan for the zone list (rares and elites)', -138)

		local zone = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
		frame.zone = zone
		zone:SetPoint('TOPLEFT', 48, -168)
		zone:SetWidth(250)
		zone:SetJustifyH'LEFT'
	end

	do
		local label = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
		label:SetPoint('TOPLEFT', 22, -194)
		label:SetText'Your targets'

		local list = CreateFrame('Button', 'unitscan_config_list', frame, 'UIPanelButtonTemplate')
		list:SetWidth(90)
		list:SetHeight(20)
		list:SetPoint('TOPRIGHT', -22, -190)
		list:SetText'List in chat'
		list:SetScript('OnClick', function() unitscan.print_targets() end)

		local input = CreateFrame('EditBox', 'unitscan_config_input', frame, 'InputBoxTemplate')
		frame.input = input
		input:SetWidth(170)
		input:SetHeight(20)
		input:SetPoint('TOPLEFT', 30, -216)
		input:SetAutoFocus(false)
		input:SetMaxLetters(64)
		input:SetScript('OnEnterPressed', function() unitscan.config_add() end)

		local add = CreateFrame('Button', 'unitscan_config_add', frame, 'UIPanelButtonTemplate')
		add:SetWidth(96)
		add:SetHeight(22)
		add:SetPoint('LEFT', input, 'RIGHT', 6, 0)
		add:SetText'Add / Remove'
		add:SetScript('OnClick', function() unitscan.config_add() end)

		local targets = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
		frame.targets = targets
		targets:SetPoint('TOPLEFT', 22, -244)
		targets:SetWidth(276)
		targets:SetHeight(36)
		targets:SetJustifyH'LEFT'
		targets:SetJustifyV'TOP'
	end

	do
		local note = frame:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
		note:SetPoint('BOTTOM', 0, 32)
		note:SetText'A target you add is removed once it is found.'

		local help = frame:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
		help:SetPoint('BOTTOM', 0, 18)
		help:SetText'Drag to move. /unitscan on, off, list, <name>'
	end
end

function unitscan.config_toggle()
	if not unitscan.config then
		unitscan.config_create()
	end
	if unitscan.config:IsShown() then
		unitscan.config:Hide()
	else
		unitscan.config:Show()
	end
end

function unitscan.config_add()
	local input = unitscan.config.input
	local _, _, name = strfind(input:GetText(), '^%s*(.-)%s*$')
	if name ~= '' then
		unitscan.toggle_target(name)
	end
	input:SetText''
	input:ClearFocus()
	unitscan.config_refresh()
end

function unitscan.config_refresh()
	local frame = unitscan.config
	if not (frame and frame:IsShown()) then return end

	if not unitscan_settings.enabled then
		frame.status:SetText'Scanning: |cffff2020off|r'
		frame.toggle:SetText'Turn scanning on'
	else
		if unitscan.scan then
			frame.status:SetText'Scanning: |cff20ff20on|r'
		else
			frame.status:SetText'Scanning: |cffffd100paused in combat|r'
		end
		frame.toggle:SetText'Turn scanning off'
	end

	frame.sound:SetChecked(unitscan_settings.sound and true or nil)
	frame.flash:SetChecked(unitscan_settings.flash and true or nil)
	frame.zonetargets:SetChecked(unitscan_settings.zonetargets and true or nil)

	frame.zone:SetText(GetZoneText() .. ': ' .. unitscan.count_zonetargets() .. ' on the zone list')
	if unitscan_settings.zonetargets then
		frame.zone:SetTextColor(1, 1, 1)
	else
		frame.zone:SetTextColor(.5, .5, .5)
	end

	local targets = unitscan.sorted_targets()
	if targets[1] then
		frame.targets:SetText(table.concat(targets, ', '))
	else
		frame.targets:SetText'|cff808080none|r'
	end
end

SLASH_UNITSCAN1 = '/unitscan'
function SlashCmdList.UNITSCAN(parameter)
	local _, _, name = strfind(parameter, '^%s*(.-)%s*$')
	local command = strlower(name)

	if name == '' then
		unitscan.config_toggle()
	elseif command == 'on' then
		unitscan.set_enabled(true)
	elseif command == 'off' then
		unitscan.set_enabled(false)
	elseif command == 'list' then
		unitscan.print_targets()
	else
		unitscan.toggle_target(name)
		unitscan.config_refresh()
	end
end

SLASH_UNITSCANTARGET1 = '/unitscantarget'
function SlashCmdList.UNITSCANTARGET()
	if unitscan.foundTarget then
		TargetByName(unitscan.foundTarget, true)
	end
end
