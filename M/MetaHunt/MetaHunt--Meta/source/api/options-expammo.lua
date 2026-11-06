------------------------------------------------------
-- MetaHunt: Experimental Ammunition Options Panel
-- TWoW 1.18.1 — "Nightmares of Ursol"
------------------------------------------------------

local function MTH_EA_OPT_Ready()
	return type(MTH_GetFrame) == "function"
		and type(MTH_CreateCheckbox) == "function"
		and type(MTH_CreateSlider) == "function"
end

local function MTH_EA_OPT_GetCfg()
	if type(MTH_SavedVariables) ~= "table" then return {} end
	if type(MTH_SavedVariables.modules) ~= "table" then return {} end
	return MTH_SavedVariables.modules["expammo"] or {}
end

local MTH_EA_OPT_STATE = { bindStatus = nil, bindButton = nil, captureFrame = nil }
local function MTH_EA_OPT_GetBindText()
	if not GetBindingKey then return "Unbound" end
	local k1, k2 = GetBindingKey("EXPAMMO ACTION")
	if not k1 and not k2 then return "Unbound" end
	if k1 and k2 then return k1 .. " / " .. k2 end
	return k1 or k2 or "Unbound"
end

local function MTH_EA_OPT_UpdateBindStatus()
	local bs = MTH_EA_OPT_STATE.bindStatus
	if not bs then return end
	bs:SetText("Key: " .. MTH_EA_OPT_GetBindText())
end

-- key must already be the full chord string (e.g. "ALT-F", "BUTTON3", "MOUSEWHEELUP")
local function MTH_EA_OPT_SaveBinding(key)
	if not SetBinding or not SaveBindings or not GetBindingKey then return end
	local old1, old2 = GetBindingKey("EXPAMMO ACTION")
	if old1 then SetBinding(old1) end
	if old2 then SetBinding(old2) end
	if key and key ~= "" then
		SetBinding(key, "EXPAMMO ACTION")
	end
	local bs = 1
	if GetCurrentBindingSet then bs = GetCurrentBindingSet() or 1 end
	SaveBindings(bs)
end

local function MTH_EA_OPT_GetPrefix()
	return string.format("%s%s%s",
		(IsAltKeyDown and IsAltKeyDown() and "ALT-" or ""),
		(IsControlKeyDown and IsControlKeyDown() and "CTRL-" or ""),
		(IsShiftKeyDown and IsShiftKeyDown() and "SHIFT-" or ""))
end

local function MTH_EA_OPT_StopCapture()
	if MTH_EA_OPT_STATE.captureFrame then
		MTH_EA_OPT_STATE.captureFrame:Hide()
	end
	local bb = MTH_EA_OPT_STATE.bindButton
	if bb then bb:SetText("Set Key") end
	MTH_EA_OPT_UpdateBindStatus()
end

local function MTH_EA_OPT_MakeCaptureFrame()
	local f = CreateFrame("Frame", "MTH_ExpAmmoBindCapture", UIParent)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetAllPoints(UIParent)
	f:EnableKeyboard(true)
	f:EnableMouse(true)
	f:EnableMouseWheel(true)
	f:Hide()
	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(f)
	bg:SetTexture(0, 0, 0, 0.5)
	local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	lbl:SetPoint("CENTER", f, "CENTER", 0, 0)
	lbl:SetText("|cffffff00Press a key, mouse button, or scroll wheel|r\n|cffaaaaaa(ESC to cancel)|r")
	f:SetScript("OnKeyUp", function()
		local key = arg1
		if not key or key == "" then return end
		if key == "ESCAPE" then MTH_EA_OPT_StopCapture() return end
		if key == "UNKNOWN" or key == "PRINTSCREEN" then return end
		if key == "ALT" or key == "CTRL" or key == "SHIFT" then return end
		MTH_EA_OPT_SaveBinding(MTH_EA_OPT_GetPrefix() .. key)
		MTH_EA_OPT_StopCapture()
	end)
	f:SetScript("OnMouseUp", function()
		local btmap = { LeftButton="BUTTON1", RightButton="BUTTON2", MiddleButton="BUTTON3", Button4="BUTTON4", Button5="BUTTON5" }
		local mapped = btmap[arg1]
		if not mapped then return end
		local prefix = MTH_EA_OPT_GetPrefix()
		if prefix == "" and (mapped == "BUTTON1" or mapped == "BUTTON2") then return end
		MTH_EA_OPT_SaveBinding(prefix .. mapped)
		MTH_EA_OPT_StopCapture()
	end)
	f:SetScript("OnMouseWheel", function()
		local wheelkey = (arg1 == 1 and "MOUSEWHEELUP") or (arg1 == -1 and "MOUSEWHEELDOWN") or nil
		if not wheelkey then return end
		MTH_EA_OPT_SaveBinding(MTH_EA_OPT_GetPrefix() .. wheelkey)
		MTH_EA_OPT_StopCapture()
	end)
	return f
end

local function MTH_EA_OPT_StartCapture()
	if not MTH_EA_OPT_STATE.captureFrame then
		MTH_EA_OPT_STATE.captureFrame = MTH_EA_OPT_MakeCaptureFrame()
	end
	MTH_EA_OPT_STATE.captureFrame:Show()
	local bb = MTH_EA_OPT_STATE.bindButton
	if bb then bb:SetText("Press key...") end
end

local function MTH_EA_OPT_BuildUI(container)
	local cfg = MTH_EA_OPT_GetCfg()
	local showHint = cfg.showHint ~= false

	local panel = MTH_Layout.Panel(container)
	panel:Title("MM Widget — Experimental Ammunition Tracker")

	-- Right-column gating: dim the box frames and disable their interactive
	-- controls when the "Show action hint cell" checkbox is off.
	local rightBoxes = {}
	local rightControls = {}
	local function setRightEnabled(enabled)
		local i
		for i = 1, table.getn(rightBoxes) do
			local f = rightBoxes[i]
			if f and f.SetAlpha then f:SetAlpha(enabled and 1.0 or 0.35) end
		end
		for i = 1, table.getn(rightControls) do
			local c = rightControls[i]
			if c and c.Enable and c.Disable then
				if enabled then c:Enable() else c:Disable() end
			end
		end
	end

	-- ===== LEFT: Module =====
	local moduleBox = panel:Box("left", "MTH_ExpAmmoModuleBox", "Module")
	local moduleEnabled = true
	if MTH and MTH.IsModuleEnabled then
		moduleEnabled = MTH:IsModuleEnabled("expammo", true) and true or false
	end
	moduleBox:Checkbox("MTH_ExpAmmoModuleCB", "Enable MM Widget module", {
		checked = moduleEnabled,
		onClick = function()
			local v = this:GetChecked() == 1
			if MTH and MTH.SetModuleEnabled then MTH:SetModuleEnabled("expammo", v) end
			if MTH_ExpAmmo then MTH_ExpAmmo.SetEnabled(v) end
		end,
	})

	-- ===== LEFT: Tracker Visibility =====
	local visBox = panel:Box("left", "MTH_ExpAmmoVisBox", "Tracker Visibility")
	visBox:Checkbox("MTH_ExpAmmoShowLnLCB", "Show Lock and Load cell (top)", {
		checked = cfg.showLnL ~= false,
		onClick = function() if MTH_ExpAmmo then MTH_ExpAmmo.SetShowLnL(this:GetChecked() == 1) end end,
	})
	visBox:Checkbox("MTH_ExpAmmoShowHintCB", "Show action hint cell (bottom)", {
		checked = showHint,
		onClick = function()
			local v = this:GetChecked() == 1
			if MTH_ExpAmmo then MTH_ExpAmmo.SetShowHint(v) end
			setRightEnabled(v)
		end,
	})
	visBox:Checkbox("MTH_ExpAmmoHideOOCCB", "Hide widget when out of combat", {
		checked = cfg.hideOOC == true,
		onClick = function() if MTH_ExpAmmo then MTH_ExpAmmo.SetHideOOC(this:GetChecked() == 1) end end,
	})

	-- ===== LEFT: Appearance =====
	local appBox = panel:Box("left", "MTH_ExpAmmoAppBox", "Appearance")
	appBox:Slider("MTH_ExpAmmoCellSizeSlider", {
		label = "Cell Size (px)", min = 20, max = 80, step = 4,
		value = math.max(20, math.min(80, cfg.cellSize or 40)),
		onChange = function(val) if MTH_ExpAmmo then MTH_ExpAmmo.SetCellSize(val) end end,
	})
	appBox:Slider("MTH_ExpAmmoCellGapSlider", {
		label = "Cell Spacing (px)", min = 0, max = 20, step = 1,
		value = math.max(0, math.min(20, cfg.cellGap or 2)),
		onChange = function(val) if MTH_ExpAmmo then MTH_ExpAmmo.SetCellGap(val) end end,
	})
	appBox:Checkbox("MTH_ExpAmmoBigCDCB", "Large cooldown numbers (centered in cell)", {
		checked = cfg.bigCD == true,
		onClick = function() if MTH_ExpAmmo then MTH_ExpAmmo.SetBigCD(this:GetChecked() == 1) end end,
	})

	-- ===== LEFT: Position =====
	local posBox = panel:Box("left", "MTH_ExpAmmoPosBox", "Position")
	posBox:Button("MTH_ExpAmmoToggleAnchor", "Toggle Anchor", {
		width = 130,
		onClick = function() if MTH_ExpAmmo then MTH_ExpAmmo.ToggleAnchor() end end,
	})
	posBox:Note("MTH_ExpAmmoPosNote",
		"Shows 4 drag handles around the widget (top / bottom / left / right). Drag any one to reposition it.",
		{ color = MTH_Layout.Theme.colText, lines = 3 })

	-- ===== RIGHT: Smart Action Cell (helper + keybind + casting) =====
	-- One feature = one box. The intro notes explain the bottom cell, and the
	-- Keybind / Casting controls that drive it live underneath as sub-sections.
	local cellBox = panel:Box("right", "MTH_ExpAmmoCellBox", "Smart Action Cell")
	table.insert(rightBoxes, cellBox:Frame())
	cellBox:Text("MTH_ExpAmmoHintSub",
		"Options below apply to the bottom cell only. Disable \"Show action hint cell\" to hide the cell and these controls.",
		{ color = { 1, 1, 1 }, lines = 3 })
	cellBox:Note("MTH_ExpAmmoHintNam",
		"Notes:\n - You need NAMPOWER for this to work reliably.\n - Aimed/Steady/Multi/Arcane Shots SHOULD BE on your action bars.",
		{ lines = 3 })

	-- Keybind sub-section
	cellBox:Gap(4)
	cellBox:Text("MTH_ExpAmmoKeyHead", "Keybind",
		{ font = MTH_Layout.Theme.fontBoxTitle, color = MTH_Layout.Theme.colPanelTitle })
	cellBox:Note("MTH_ExpAmmoBindTip",
		"One key to rule them all.\n Aimed Shot when ready, Steady Shot while Aimed is on cooldown, consume-spell (Multi / Serpent / Arcane) when proc is up.",
		{ lines = 4 })
	MTH_EA_OPT_STATE.bindStatus = cellBox:Text("MTH_ExpAmmoBindStatus",
		"Key: " .. MTH_EA_OPT_GetBindText())
	local keyButtons = cellBox:Buttons({
		{ name = "MTH_ExpAmmoBindButton", label = "Set Key", width = 90,
			onClick = function()
				if MTH_EA_OPT_STATE.captureFrame and MTH_EA_OPT_STATE.captureFrame:IsShown() then
					MTH_EA_OPT_StopCapture()
				else
					MTH_EA_OPT_StartCapture()
				end
			end },
		{ name = "MTH_ExpAmmoBindClear", label = "Clear", width = 70,
			onClick = function() MTH_EA_OPT_SaveBinding(nil) end },
	})
	MTH_EA_OPT_STATE.bindButton = keyButtons[1]
	table.insert(rightControls, keyButtons[1])
	table.insert(rightControls, keyButtons[2])

	-- Casting sub-section
	cellBox:Gap(4)
	cellBox:Text("MTH_ExpAmmoCastHead", "Casting",
		{ font = MTH_Layout.Theme.fontBoxTitle, color = MTH_Layout.Theme.colPanelTitle })
	local quiverCB = cellBox:Checkbox("MTH_ExpAmmoQuiverNoClipCB", "Use Quiver no-clip casting", {
		checked = cfg.useQuiverNoClip == true,
		onClick = function() if MTH_ExpAmmo then MTH_ExpAmmo.SetUseQuiverNoClip(this:GetChecked() == 1) end end,
	})
	table.insert(rightControls, quiverCB)
	cellBox:Note("MTH_ExpAmmoQuiverTip",
		"Requires the Quiver addon. Routes Aimed/Steady/Multi cast through Quiver.CastNoClip to avoid clipping your auto-shot swing timer.",
		{ lines = 3 })

	-- ===== RIGHT: Rotation =====
	local rotBox = panel:Box("right", "MTH_ExpAmmoRotBox", "Rotation")
	table.insert(rightBoxes, rotBox:Frame())
	rotBox:Note("MTH_ExpAmmoRotTip",
		"Uncheck a shot to permanently skip it during its proc window. The keybind will cast Steady/Aimed instead.",
		{ lines = 2 })
	local multiCB = rotBox:Checkbox("MTH_ExpAmmoBlockMultiCB", "Multi-Shot (Explosive)", {
		checked = cfg.blockExplosive ~= true,
		onClick = function() if MTH_ExpAmmo then MTH_ExpAmmo.SetBlockExplosive(not (this:GetChecked() == 1)) end end,
	})
	table.insert(rightControls, multiCB)
	local serpentCB = rotBox:Checkbox("MTH_ExpAmmoBlockSerpentCB", "Serpent Sting (Poisonous)", {
		checked = cfg.blockPoisonous ~= true,
		onClick = function() if MTH_ExpAmmo then MTH_ExpAmmo.SetBlockPoisonous(not (this:GetChecked() == 1)) end end,
	})
	table.insert(rightControls, serpentCB)
	local arcaneCB = rotBox:Checkbox("MTH_ExpAmmoBlockArcaneCB", "Arcane Shot (Enchanted)", {
		checked = cfg.blockEnchanted ~= true,
		onClick = function() if MTH_ExpAmmo then MTH_ExpAmmo.SetBlockEnchanted(not (this:GetChecked() == 1)) end end,
	})
	table.insert(rightControls, arcaneCB)

	panel:Finish()

	-- Apply initial gating state.
	setRightEnabled(showHint)
end

function MTH_SetupExpAmmoOptions()
	if not MTH_EA_OPT_Ready() then return end
	local container = MTH_GetFrame("MetaHuntOptionsExpAmmo")
	if not container then return end
	local ok, err = pcall(MTH_EA_OPT_BuildUI, container)
	if not ok and MTH and MTH.Print then
		MTH:Print("[MTH ExpAmmo OPTIONS] " .. tostring(err), "error")
	end
end
