local unitscan = CreateFrame'Frame'
unitscan:SetScript('OnUpdate', function() unitscan.UPDATE() end)
unitscan:SetScript('OnEvent', function() 
	if event == "VARIABLES_LOADED" then
		unitscan.LOAD()
		unitscan.scan = true
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
unitscan_minlevel = unitscan_minlevel or 0  -- default: show everything
unitscan_wf = unitscan_wf or 0  -- 0 = never auto close, otherwise seconds until auto close


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
		
			-- Do not scan if player already has a target
			if UnitExists("target") then
    		return
			end
		
		
		for name, _ in unitscan_targets do
			if name == unitscan.target(name) then
				unitscan.foundTarget = name
				unitscan.toggle_target(name)
				unitscan.play_sound()
				unitscan.flash.animation:Play()
				unitscan.button:set_target()			
			end
			unitscan.restoreTarget()
		end

		for name, _ in unitscan_zonetargets do
			if strupper(name) == unitscan.target(name) then
				unitscan.foundTarget = name		
				unitscan.toggle_zonetarget(name)
				unitscan.play_sound()
				unitscan.flash.animation:Play()
				unitscan.button:set_target()
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

		 -- LEVEL FILTER HERE
    local targetLevel = UnitLevel("target")
    local playerLevel = UnitLevel("player")

    -- Minimum level filter
if targetLevel > 0 and targetLevel < unitscan_minlevel then
    return nil
end

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
			if t <= .2 then
				flash:SetAlpha(t * 5)
			elseif t <= .4 then
				flash:SetAlpha(1)
			elseif t <= .6 then
				flash:SetAlpha(1 - (t - .4) * 5)
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
	end
	
	local button = CreateFrame("Button", "unitscan_button", UIParent)
	button:Hide()
	unitscan.button = button
button.autoCloseTime = nil

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

		-- NEW CODE: start auto-close timer
  		if unitscan_wf and unitscan_wf > 0 then
   	     		self.autoCloseTime = GetTime() + unitscan_wf
  		else
      			self.autoCloseTime = nil
    		end



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
		if unitscan.scan then
-- NEW CODE: auto-close window fade
if unitscan.button and unitscan.button:IsShown() and unitscan.button.autoCloseTime then
    if GetTime() >= unitscan.button.autoCloseTime then
        unitscan.button:Hide()
        unitscan.button.autoCloseTime = nil
    end
end

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
	
SLASH_UNITSCAN1 = '/unitscan'
function SlashCmdList.UNITSCAN(parameter)
	local _, _, name = strfind(parameter, '^%s*(.-)%s*$')
	
	if name == '' then
		unitscan.print("Added targets:")
		for _, key in ipairs(unitscan.sorted_targets()) do
			unitscan.print(key)
		end
		-- zone targets
		unitscan.print("Zone targets:")
		for _, key in ipairs(unitscan.sorted_zonetargets()) do
			unitscan.print(key)
		end
	else
		unitscan.toggle_target(name)
	end
end

SLASH_UNITSCANLEVEL1 = "/unitscanlevel"
function SlashCmdList.UNITSCANLEVEL(msg)
    local num = tonumber(msg)

    if not num then
        unitscan.print("Current minimum alert level: " .. unitscan_minlevel)
        unitscan.print("Use /unitscanlevel <number> to change it.")
        return
    end

    if num < 1 or num > 100 then
        unitscan.print("Invalid level. Enter a number between 1 and 100.")
        return
    end

    unitscan_minlevel = num
    unitscan.print("Unitscan will now alert only mobs of level " .. num .. " or higher.")
end




SLASH_UNITSCANWF1 = "/unitscanwf"
function SlashCmdList.UNITSCANWF(msg)
    local num = tonumber(msg)

    if not num then
        unitscan.print("Current window fade time: " .. unitscan_wf)
        unitscan.print("Use /unitscanwf <seconds> (0–100).")
        return
    end

    if num < 0 or num > 100 then
        unitscan.print("Invalid value. Enter a number between 0 and 100.")
        return
    end

    unitscan_wf = num

    if num == 0 then
        unitscan.print("Unitscan window will stay open until closed manually.")
    else
        unitscan.print("Unitscan window will auto-close after " .. num .. " seconds.")
    end
end



SLASH_UNITSCANHELP1 = "/unitscanhelp"
function SlashCmdList.UNITSCANHELP(msg)
    unitscan.print("===== Unitscan Help =====")

    unitscan.print("/unitscan <name>")
    unitscan.print("  Toggle tracking of a specific NPC by name.")
    unitscan.print("  Example: /unitscan Hogger")
    unitscan.print("  Current tracked targets: " .. table.getn(unitscan.sorted_targets()))

    unitscan.print("/unitscanlevel <number>")
    unitscan.print("  Only alert for mobs at or above this level.")
    unitscan.print("  0 shows all mobs. Current: " .. unitscan_minlevel)

    unitscan.print("/unitscanwf <seconds>")
    unitscan.print("  Sets how long the popup creature window stays open.")
    unitscan.print("  0 = stays open until closed manually.")
    unitscan.print("  Current: " .. unitscan_wf .. " seconds")

    unitscan.print("/unitscantarget")
    unitscan.print("  Retarget the last detected NPC (if available).")

    unitscan.print("/unitscanhelp")
    unitscan.print("  Shows this help message.")
end




SLASH_UNITSCANTARGET1 = '/unitscantarget'
function SlashCmdList.UNITSCANTARGET()
	if unitscan.foundTarget then
		TargetByName(unitscan.foundTarget, true)
	end
end
