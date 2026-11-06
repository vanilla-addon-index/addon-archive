local function MTH_CHRON_GetGlobal(name)
	if type(getglobal) == "function" then
		return getglobal(name)
	end
	if _G then
		return _G[name]
	end
	return nil
end

local function MTH_CHRON_IsReady()
	local required = {
		"MTH_GetFrame",
		"MTH_ClearContainer",
		"MTH_CreateCheckbox",
		"MTH_CreateSlider",
		"MTH_CreateActionButton",
	}

	for i = 1, table.getn(required) do
		if MTH_CHRON_GetGlobal(required[i]) == nil then
			return false
		end
	end
	return true
end

local MTH_CHRON_STATE = {
	controls = {},
}

local MTH_CHRON_DEFAULTS = {
	growup = false,
	reverse = false,
	fadeonkill = true,
	fadeonfade = true,
	barposition = {},
	ghost = 0,
	selfbars = true,
	barwidth = 220,
	barheight = 16,
	spacing = 0,
	barscale = 1,
	iconposition = "LEFT",
	textsize = 10,
	textcolor = "white",
	bgcolor = "teal",
	barcolor = "gray",
	bordercolor = "black",
	bordertex = "None",
	bgalpha = 0.5,
	text = "$t",
	onlyself = false,
	disabledSpells = {
		COMMON = {
			["Ephemeral Power"] = {},
			["Mind Quickening"] = {},
			["Unstable Power"] = {},
		},
		RACIAL = {},
		HUNTER = {},
	},
}

local function MTH_CHRON_SeedDefaultCommonDisabled(commonBucket)
	if type(commonBucket) ~= "table" then
		return
	end
	local names = {
		"Ephemeral Power",
		"Mind Quickening",
		"Unstable Power",
	}
	for i = 1, table.getn(names) do
		local baseName = names[i]
		if commonBucket[baseName] == nil then
			commonBucket[baseName] = {}
		end
		if MTH and MTH.LocalizeSpell then
			local localized = MTH:LocalizeSpell(baseName)
			if localized and localized ~= "" and commonBucket[localized] == nil then
				commonBucket[localized] = {}
			end
		end
	end
end

local function MTH_CHRON_CopyTable(source)
	local target = {}
	for key, value in pairs(source) do
		if type(value) == "table" then
			target[key] = MTH_CHRON_CopyTable(value)
		else
			target[key] = value
		end
	end
	return target
end

local function MTH_CHRON_GetProfile()
	if not (MTH and MTH.GetModuleCharSavedVariables) then
		return MTH_CHRON_CopyTable(MTH_CHRON_DEFAULTS)
	end

	local store = MTH:GetModuleCharSavedVariables("chronometer")
	if type(store) ~= "table" then
		return MTH_CHRON_CopyTable(MTH_CHRON_DEFAULTS)
	end
	if type(store.profile) ~= "table" and MTH.GetModuleSavedVariables then
		local accountStore = MTH:GetModuleSavedVariables("chronometer")
		if type(accountStore) == "table" and type(accountStore.profile) == "table" then
			store.profile = MTH_CHRON_CopyTable(accountStore.profile)
		end
	end
	if type(store.profile) ~= "table" then
		store.profile = {}
	end
	local profile = store.profile

	for key, value in pairs(MTH_CHRON_DEFAULTS) do
		if profile[key] == nil then
			if type(value) == "table" then
				profile[key] = MTH_CHRON_CopyTable(value)
			else
				profile[key] = value
			end
		end
	end

	if type(profile.disabledSpells) ~= "table" then
		profile.disabledSpells = {}
	end
	if type(profile.disabledSpells.COMMON) ~= "table" then
		profile.disabledSpells.COMMON = {}
	end
	MTH_CHRON_SeedDefaultCommonDisabled(profile.disabledSpells.COMMON)
	if type(profile.disabledSpells.RACIAL) ~= "table" then
		profile.disabledSpells.RACIAL = {}
	end

	local _, class = UnitClass("player")
	class = class or "HUNTER"
	if type(profile.disabledSpells[class]) ~= "table" then
		profile.disabledSpells[class] = {}
	end

	return profile
end

local function MTH_CHRON_GetTimerDefinitions()
	local engine = MTH_ChronometerHunter
	if engine and engine.timers and (engine.timers[engine.SPELL] or engine.timers[engine.EVENT]) then
		return engine.timers, engine.SPELL, engine.EVENT
	end

	if not engine then
		return nil, 1, 2
	end

	local fake = {
		SPELL = 1,
		EVENT = 2,
		groups = {},
		timers = {},
	}
	function fake:AddGroup(id, forall, color)
		if color then
			self.groups[id] = { fa = forall, cr = color }
		else
			self.groups[id] = { fa = forall }
		end
	end
	function fake:AddTimer(kind, name, duration, targeted, isgain, selforselect, extra)
		if type(self.timers[kind]) ~= "table" then
			self.timers[kind] = {}
		end
		if type(extra) ~= "table" then
			extra = {}
		end
		self.timers[kind][name] = {
			d = duration,
			k = { t = targeted, g = isgain, s = selforselect },
			x = extra,
		}
	end

	if type(engine.dataSetup) == "table" then
		for _, setupFunc in pairs(engine.dataSetup) do
			if type(setupFunc) == "function" then
				setupFunc(fake)
			end
		end
	end

	return fake.timers, fake.SPELL, fake.EVENT
end

local function MTH_CHRON_SortKeys(list)
	table.sort(list, function(a, b)
		return tostring(a) < tostring(b)
	end)
end

local function MTH_CHRON_BuildTimerLists()
	local timers, spellKind, eventKind = MTH_CHRON_GetTimerDefinitions()
	local classSpells, classEvents, racial = {}, {}, {}
	if type(timers) ~= "table" then
		return classSpells, classEvents, racial
	end

	local function classify(timerRecord)
		if timerRecord and timerRecord.x and timerRecord.x.cl == "COMMON" then
			return "COMMON"
		elseif timerRecord and timerRecord.x and timerRecord.x.cl == "RACIAL" then
			return "RACIAL"
		end
		local _, class = UnitClass("player")
		return class or "HUNTER"
	end

	for timerName, timerRecord in pairs(timers[spellKind] or {}) do
		local bucket = classify(timerRecord)
		if bucket == "RACIAL" then
			table.insert(racial, timerName)
		elseif bucket ~= "COMMON" then
			table.insert(classSpells, timerName)
		end
	end

	for timerName, timerRecord in pairs(timers[eventKind] or {}) do
		local bucket = classify(timerRecord)
		if bucket == "RACIAL" then
			table.insert(racial, timerName)
		elseif bucket ~= "COMMON" then
			table.insert(classEvents, timerName)
		end
	end

	MTH_CHRON_SortKeys(classSpells)
	MTH_CHRON_SortKeys(classEvents)
	MTH_CHRON_SortKeys(racial)
	return classSpells, classEvents, racial
end

local function MTH_CHRON_ApplyLiveProfile(profile)
	if not profile then
		return
	end
	local engine = MTH_ChronometerHunter
	if not (engine and engine._mth_enabled) then
		return
	end

	engine.profile = profile
	if engine.SetCandyBarGroupGrowth and engine.SetCandyBarGroupPoint and engine.anchor then
		local growup = profile.growup and true or false
		if growup then
			engine:SetCandyBarGroupPoint("MTHChronometer", "BOTTOM", engine.anchor, "TOP", 0, 0)
		else
			engine:SetCandyBarGroupPoint("MTHChronometer", "TOP", engine.anchor, "BOTTOM", 0, 0)
		end
		engine:SetCandyBarGroupGrowth("MTHChronometer", growup)
	end
	if engine.SetCandyBarGroupVerticalSpacing then
		engine:SetCandyBarGroupVerticalSpacing("MTHChronometer", profile.spacing or 0)
	end

	if type(engine.bars) == "table" then
		for i = 1, 20 do
			local bar = engine.bars[i]
			if bar and bar.id then
				if profile.barscale and engine.SetCandyBarScale then
					engine:SetCandyBarScale(bar.id, profile.barscale)
				end
				if profile.barwidth and engine.SetCandyBarWidth then
					engine:SetCandyBarWidth(bar.id, profile.barwidth)
				end
				if profile.barheight and engine.SetCandyBarHeight then
					engine:SetCandyBarHeight(bar.id, profile.barheight)
				end
				if profile.iconposition and engine.SetCandyBarIconPosition then
					engine:SetCandyBarIconPosition(bar.id, profile.iconposition)
				end
				if profile.textsize and engine.SetCandyBarFontSize then
					engine:SetCandyBarFontSize(bar.id, profile.textsize)
				end
				if profile.text and engine.SetCandyBarText then
					local target = bar.target or "none"
					local text = target == "none" and (bar.name or "") or profile.text
					text = string.gsub(tostring(text or ""), "$t", tostring(target))
					text = string.gsub(tostring(text or ""), "$s", tostring(bar.name or ""))
					engine:SetCandyBarText(bar.id, text)
				end
				if engine.SetCandyBarReversed then
					engine:SetCandyBarReversed(bar.id, profile.reverse and true or false)
				end
			end
		end
	end
end

local function MTH_CHRON_MakeTitle(parent, name, text, x, y)
	local label = parent:CreateFontString(name, "ARTWORK", "GameFontHighlight")
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	label:SetText(text)
	return label
end

local function MTH_CHRON_MakeSmall(parent, name, text, x, y)
	local label = parent:CreateFontString(name, "ARTWORK", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	label:SetText(text)
	return label
end

local function MTH_CHRON_IsChecked(control)
	if not control or type(control.GetChecked) ~= "function" then
		return false
	end
	local checked = control:GetChecked()
	return checked == 1 or checked == true
end


local function MTH_CHRON_MakeInput(parent, name, x, y, width, height, value, onAccept)
	local edit = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
	if not edit then
		return nil
	end
	edit:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	edit:SetWidth(width or 200)
	edit:SetHeight(height or 20)
	edit:SetAutoFocus(false)
	edit:SetText(tostring(value or ""))
	edit:SetScript("OnEnterPressed", function()
		if not this then return end
		if type(onAccept) == "function" then
			onAccept(this:GetText() or "")
		end
		this:ClearFocus()
	end)
	return edit
end

local function MTH_CHRON_NormalizeSection(tabKey)
	if not tabKey and _G then
		tabKey = _G.MTH_CHRON_OPTIONS_SECTION
	end
	if tabKey == "ChronometerBar" then
		return "bar"
	elseif tabKey == "ChronometerClassSpells" then
		return "classspells"
	elseif tabKey == "ChronometerClassEvents" then
		return "classevents"
	elseif tabKey == "ChronometerRacial" then
		return "racial"
	end
	return "general"
end

local function MTH_CHRON_RenderTimerBox(box, profile, items, bucket, prefix)
	prefix = tostring(prefix or "Main")
	if table.getn(items) == 0 then
		box:Text("MetaHuntOptionsChronometerSectionEmpty" .. prefix, "(none)")
		return
	end

	for i = 1, table.getn(items) do
		local row = items[i]
		local timerName = row
		local label = row
		if type(row) == "table" then
			timerName = row.key or row.timer or row.name
			label = row.label or row.name or row.key
		end
		timerName = tostring(timerName or "")
		label = tostring(label or timerName)
		local controlName = "MetaHuntOptionsChronometerTimer" .. prefix .. tostring(bucket) .. tostring(i)
		box:Checkbox(controlName, label, {
			checked = profile.disabledSpells[bucket][timerName] == nil,
			onClick = function()
				local currentlyDisabled = profile.disabledSpells[bucket][timerName] ~= nil
				if currentlyDisabled then
					profile.disabledSpells[bucket][timerName] = nil
					this:SetChecked(true)
				else
					profile.disabledSpells[bucket][timerName] = {}
					this:SetChecked(nil)
				end

				MTH_CHRON_ApplyLiveProfile(profile)
			end,
		})
	end
end

local MTH_CHRON_HUNTER_TRINKETS = {
	{ labelToken = "Devilsaur Eye", timerToken = "Devilsaur Fury" },
	{ labelToken = "Zandalarian Hero Medallion", timerToken = "Restless Strength" },
	{ labelToken = "Earthstrike", timerToken = "Earthstrike" },
	{ labelToken = "Badge of the Swarmguard", timerToken = "Badge of the Swarmguard" },
	{ labelToken = "Jom Gabbar", timerToken = "Jom Gabbar" },
	{ labelToken = "Kiss of the Spider", timerToken = "Kiss of the Spider" },
	{ labelToken = "Slayer's Crest", timerToken = "Slayer's Crest" },
}

local function MTH_CHRON_LocalizeTimerToken(token)
	if MTH and MTH.LocalizeSpell then
		return tostring(MTH:LocalizeSpell(token) or token)
	end
	return tostring(token)
end

local function MTH_CHRON_BuildHunterTrinketItems(classEvents)
	local eventSet = {}
	for i = 1, table.getn(classEvents or {}) do
		eventSet[tostring(classEvents[i])] = true
	end

	local result = {}
	for i = 1, table.getn(MTH_CHRON_HUNTER_TRINKETS) do
		local def = MTH_CHRON_HUNTER_TRINKETS[i]
		local key = MTH_CHRON_LocalizeTimerToken(def.timerToken)
		if eventSet[key] then
			table.insert(result, {
				key = key,
				label = MTH_CHRON_LocalizeTimerToken(def.labelToken),
			})
		end
	end
	return result
end

function MTH_RefreshChronometerOptions(tabKey)
	if not MTH_CHRON_IsReady() then return end
	MTH_SetupChronometerOptions(tabKey)
end

function MTH_SetupChronometerOptions(tabKey)
	if not MTH_CHRON_IsReady() then
		if MTH and MTH.Print then
			MTH:Print("Chronometer options dependencies missing", "error")
		end
		return
	end
	local section = MTH_CHRON_NormalizeSection(tabKey)
	local container = MTH_GetFrame("MetaHuntOptionsChronometer")
	if not container then return end

	MTH_CHRON_STATE.controls = {}

	local profile = MTH_CHRON_GetProfile()
	local _, class = UnitClass("player")
	class = class or "HUNTER"

	local panel = MTH_Layout.Panel(container)
	panel:Title("Chronometer")

	local moduleEnabled = false
	do
		local module = MTH and MTH:GetModule("chronometer")
		moduleEnabled = module and module.enabled and true or false
	end
	panel:TopCheckbox("MetaHuntOptionsChronometerEnabled", "Enable Chronometer module", {
		checked = moduleEnabled,
		onClick = function()
			local enabled = this:GetChecked() == 1
			if MTH and MTH.SetModuleEnabled then
				MTH:SetModuleEnabled("chronometer", enabled)
			end
		end,
	})

	if section == "general" then
		local genBox = panel:Box("left", "MetaHuntOptionsChronometerGeneralBox", "General")
		genBox:Slider("MetaHuntOptionsChronometerGhost", {
			label = "Ghost Duration", min = 0, max = 30, step = 1,
			value = tonumber(profile.ghost) or 0,
			onChange = function(value)
				profile.ghost = tonumber(value) or 0
				MTH_CHRON_ApplyLiveProfile(profile)
			end,
		})
		genBox:Checkbox("MetaHuntOptionsChronometerFadeOnKill", "Fade on kill", {
			checked = profile.fadeonkill and true or false,
			onClick = function() profile.fadeonkill = this:GetChecked() == 1 end,
		})
		genBox:Checkbox("MetaHuntOptionsChronometerFadeOnFade", "Fade on aura fade", {
			checked = profile.fadeonfade and true or false,
			onClick = function() profile.fadeonfade = this:GetChecked() == 1 end,
		})
		genBox:Checkbox("MetaHuntOptionsChronometerSelfBars", "Show self bars", {
			checked = profile.selfbars and true or false,
			onClick = function() profile.selfbars = this:GetChecked() == 1 end,
		})
		genBox:Checkbox("MetaHuntOptionsChronometerOnlySelf", "Only self target", {
			checked = profile.onlyself and true or false,
			onClick = function() profile.onlyself = this:GetChecked() == 1 end,
		})
	elseif section == "bar" then
		local ctrlBox = panel:Box("left", "MetaHuntOptionsChronometerControlsBox", "Controls")
		ctrlBox:Buttons({
			{ name = "MetaHuntOptionsChronometerRunTest", label = "Run Test", width = 120,
				onClick = function()
					local engine = MTH_ChronometerHunter
					if engine and engine.RunTest then engine:RunTest() end
				end },
			{ name = "MetaHuntOptionsChronometerAnchor", label = "Toggle Anchor", width = 120,
				onClick = function()
					local engine = MTH_ChronometerHunter
					if engine and engine.ToggleAnchor then engine:ToggleAnchor() end
				end },
		})
		local anchorX = tonumber(profile.barposition and profile.barposition.x) or 0
		local anchorY = tonumber(profile.barposition and profile.barposition.y) or 0
		ctrlBox:Note("MetaHuntOptionsChronometerAnchorPos",
			"Anchor: X " .. tostring(anchorX) .. "  Y " .. tostring(anchorY))

		local dimBox = panel:Box("left", "MetaHuntOptionsChronometerDimBox", "Dimensions")
		dimBox:Slider("MetaHuntOptionsChronometerBarWidth", {
			label = "Bar Width", min = 80, max = 320, step = 1,
			value = tonumber(profile.barwidth) or 220,
			onChange = function(value)
				profile.barwidth = tonumber(value) or 220
				MTH_CHRON_ApplyLiveProfile(profile)
			end,
		})
		dimBox:Slider("MetaHuntOptionsChronometerBarScale", {
			label = "Bar Scale", min = 0.5, max = 1.5, step = 0.1,
			value = tonumber(profile.barscale) or 1,
			format = function(v) return string.format("%.1f", v) end,
			onChange = function(value)
				profile.barscale = tonumber(value) or 1
				MTH_CHRON_ApplyLiveProfile(profile)
			end,
		})
		dimBox:Slider("MetaHuntOptionsChronometerBarHeight", {
			label = "Bar Height", min = 8, max = 30, step = 1,
			value = tonumber(profile.barheight) or 16,
			onChange = function(value)
				profile.barheight = tonumber(value) or 16
				MTH_CHRON_ApplyLiveProfile(profile)
			end,
		})
		dimBox:Slider("MetaHuntOptionsChronometerBarSpacing", {
			label = "Bar Spacing", min = 0, max = 15, step = 1,
			value = tonumber(profile.spacing) or 0,
			onChange = function(value)
				profile.spacing = tonumber(value) or 0
				MTH_CHRON_ApplyLiveProfile(profile)
			end,
		})
		dimBox:Slider("MetaHuntOptionsChronometerTextSize", {
			label = "Text Size", min = 8, max = 20, step = 1,
			value = tonumber(profile.textsize) or 10,
			onChange = function(value)
				profile.textsize = tonumber(value) or 10
				MTH_CHRON_ApplyLiveProfile(profile)
			end,
		})

		local textBox = panel:Box("right", "MetaHuntOptionsChronometerTextBox", "Text & Growth")
		textBox:Note("MetaHuntOptionsChronometerTextPatternHint",
			"Bar text tokens: $s = spell, $t = target", { lines = 2 })
		local patternEdit = textBox:EditRow("MetaHuntOptionsChronometerTextPatternLabel", "Bar Text",
			"MetaHuntOptionsChronometerTextPattern", 150, { height = 20 })
		if patternEdit then
			patternEdit:SetText(tostring(profile.text or "$t"))
			patternEdit:SetScript("OnEnterPressed", function()
				local newText = this:GetText() or ""
				if newText == "" then newText = "$t" end
				profile.text = tostring(newText)
				MTH_CHRON_ApplyLiveProfile(profile)
				this:ClearFocus()
			end)
		end
		textBox:Checkbox("MetaHuntOptionsChronometerGrowUp", "Grow bars upward", {
			checked = profile.growup and true or false,
			onClick = function()
				profile.growup = this:GetChecked() == 1
				MTH_CHRON_ApplyLiveProfile(profile)
			end,
		})
		textBox:Checkbox("MetaHuntOptionsChronometerReverse", "Reverse bars", {
			checked = profile.reverse and true or false,
			onClick = function()
				profile.reverse = this:GetChecked() == 1
				MTH_CHRON_ApplyLiveProfile(profile)
			end,
		})

		local iconBox = panel:Box("right", "MetaHuntOptionsChronometerIconBox", "Icon Position")
		local iconLeft, iconRight
		iconLeft = iconBox:Checkbox("MetaHuntOptionsChronometerIconLeft", "Left", {
			checked = profile.iconposition ~= "RIGHT",
			onClick = function()
				profile.iconposition = "LEFT"
				iconLeft:SetChecked(true)
				iconRight:SetChecked(nil)
				MTH_CHRON_ApplyLiveProfile(profile)
			end,
		})
		iconRight = iconBox:Checkbox("MetaHuntOptionsChronometerIconRight", "Right", {
			checked = profile.iconposition == "RIGHT",
			onClick = function()
				profile.iconposition = "RIGHT"
				iconRight:SetChecked(true)
				iconLeft:SetChecked(nil)
				MTH_CHRON_ApplyLiveProfile(profile)
			end,
		})
	else
		local classSpells, classEvents, racial = MTH_CHRON_BuildTimerLists()
		if section == "classspells" then
			local spellsBox = panel:Box("left", "MetaHuntOptionsChronometerSpellsBox", "Hunter Spells")
			MTH_CHRON_RenderTimerBox(spellsBox, profile, classSpells, class, "ClassSpells")
			local trinketBox = panel:Box("right", "MetaHuntOptionsChronometerTrinketsBox", "Hunter Trinkets")
			MTH_CHRON_RenderTimerBox(trinketBox, profile, MTH_CHRON_BuildHunterTrinketItems(classEvents), class, "ClassTrinkets")
		elseif section == "classevents" then
			local eventsBox = panel:Box("left", "MetaHuntOptionsChronometerEventsBox", "Hunter Events")
			MTH_CHRON_RenderTimerBox(eventsBox, profile, classEvents, class, "ClassEvents")
		elseif section == "racial" then
			local racialBox = panel:Box("left", "MetaHuntOptionsChronometerRacialBox", "Racial")
			MTH_CHRON_RenderTimerBox(racialBox, profile, racial, "RACIAL", "Racial")
		end
	end

	panel:Finish()
end

	if _G then
		_G.MTH_SetupChronometerOptions = MTH_SetupChronometerOptions
		_G.MTH_RefreshChronometerOptions = MTH_RefreshChronometerOptions
	end
