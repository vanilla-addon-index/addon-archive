local _G = getfenv(0)
local textureOffset = 0
local minimapX
local minimapY
local getn = table.getn
presetNames = { "Diablo by Zork", "Faded Square by Renaitre", "Blue Rune Circles", "Blue Rune Diamond", "Burning Sun", "Stargate", "Simple Square", "Ruins", "Emerald Portal", "Shamanism", "Space by Ruka", "Clouds by koccs", "Rogue", "Electric", "LL Corner Rounded", }
shapeNames = { "Round", "Square", "Diamond", "Hexagon", "Octagon", "Heart", "Snowflake", "LL Corner Rounded", "LR Corner Rounded", "UL Corner Rounded", "UR Corner Rounded", "Large Circle", "Route66", "Deathsky", "VFX Border",}

variableOptionSliders = {
	{ text = "Rotation Speed", func = "CRotSpeedChanged", value = "rotSpeed", minValue = -64, maxValue = 64, valueStep = 1 },
	{ text = "Scale", func = "CScaleChanged", value = "scale", minValue = 0.0, maxValue = 4, valueStep = 0.01 },
}

-- Pagination state
local presetPage = 0
local shapePage = 0
local PRESETS_PER_PAGE = 8
local SHAPES_PER_PAGE = 8

local function print(msg)
	if msg and msg ~= "" then
		DEFAULT_CHAT_FRAME:AddMessage(msg, 1, 1, 1)
	end
end

function NotImportant_OnLoad()
end

function CApplyPreset(preset)
	local preset = SexyMap2DB.userPresets[preset] or borderPresets[preset]
	
	SexyMap2DB.borders = deepCopyHash(preset.borders)
	SexyMap2DB.backdrop = deepCopyHash(preset.backdrop)
	SexyMap2DB.shape = preset.shape
	CTextureOptionFrame.selectedTexture = nil
	
	CClearArtwork()
	CLoadArtwork()
	CTexture_Update()
	CVariable_Update()
	CUpdateShapeList()
end

function CInitiateMenu()
	CSexyMapMainFrame:Show()
	-- Show sub-frames
	CTextureOptionFrame:Show()
	CMinimapOptionFrame:Show()
	-- Initialize all lists
	CUpdatePresetList()
	CUpdateShapeList()
	CTexture_Update()
	CZoneTextToggle_Update()
	CMinimapButtonsToggle_Update()
	CMinimapToggle_Update()
	CMapScaleSlider_Update()
	CMinimapOptionFrame.menuState = true
end

function CHideMenu()
	CTextureOptionFrame.selectedTexture = nil
	CVariableOptionFrame:Hide()
	CSexyMapMainFrame:Hide()
	CMinimapOptionFrame.menuState = false
end

-------------------------------------------------
-- Preset list (button-based, replaces dropdown)
-------------------------------------------------
function CUpdatePresetList()
	local startIdx = presetPage * PRESETS_PER_PAGE + 1
	for i = 1, PRESETS_PER_PAGE do
		local btn = _G["CPresetBtn"..i]
		local idx = startIdx + i - 1
		if idx <= getn(presetNames) then
			btn:SetText(presetNames[idx])
			btn.presetName = presetNames[idx]
			btn:Show()
		else
			btn:Hide()
		end
	end
	-- Prev/Next buttons
	if presetPage > 0 then
		CPresetPrevBtn:Show()
	else
		CPresetPrevBtn:Hide()
	end
	if (presetPage + 1) * PRESETS_PER_PAGE < getn(presetNames) then
		CPresetNextBtn:Show()
	else
		CPresetNextBtn:Hide()
	end
end

function CPresetBtn_OnClick()
	local name = this.presetName
	if name then
		CApplyPreset(name)
	end
end


function CPresetPrev_OnClick()
	if presetPage > 0 then
		presetPage = presetPage - 1
		CUpdatePresetList()
	end
end

function CPresetNext_OnClick()
	if (presetPage + 1) * PRESETS_PER_PAGE < getn(presetNames) then
		presetPage = presetPage + 1
		CUpdatePresetList()
	end
end

-------------------------------------------------
-- Shape list (button-based, replaces dropdown)
-------------------------------------------------
function CUpdateShapeList()
	local startIdx = shapePage * SHAPES_PER_PAGE + 1
	for i = 1, SHAPES_PER_PAGE do
		local btn = _G["CShapeBtn"..i]
		local idx = startIdx + i - 1
		if idx <= getn(shapeNames) then
			btn:SetText(shapeNames[idx])
			btn.shapeName = shapeNames[idx]
			if SexyMap2DB.shape == shapeNames[idx] then
				btn:LockHighlight()
			else
				btn:UnlockHighlight()
			end
			btn:Show()
		else
			btn:Hide()
		end
	end
	-- Prev/Next buttons
	if shapePage > 0 then
		CShapePrevBtn:Show()
	else
		CShapePrevBtn:Hide()
	end
	if (shapePage + 1) * SHAPES_PER_PAGE < getn(shapeNames) then
		CShapeNextBtn:Show()
	else
		CShapeNextBtn:Hide()
	end
end

function CShapeBtn_OnClick()
	local name = this.shapeName
	if name then
		SexyMap2DB.shape = name
		CApplyShape(SexyMap2DB.shape)
		CUpdateShapeList()
	end
end

function CShapePrev_OnClick()
	if shapePage > 0 then
		shapePage = shapePage - 1
		CUpdateShapeList()
	end
end

function CShapeNext_OnClick()
	if (shapePage + 1) * SHAPES_PER_PAGE < getn(shapeNames) then
		shapePage = shapePage + 1
		CUpdateShapeList()
	end
end

-------------------------------------------------
-- Texture list (border texture buttons)
-------------------------------------------------
function CTexture_Update()
	local button
	for i=1,12 do
		button = _G["CTextureButton"..i]
		textureIndex = textureOffset + i
		button.textureIndex = textureIndex
		
		if not SexyMap2DB.borders[textureIndex] then
			button:Hide()
		else
			button:Show()
			_G["CTextureButton"..i.."Texture"]:SetText(SexyMap2DB.borders[textureIndex].name or SexyMap2DB.borders[textureIndex].texture)
		end
		
		if CTextureOptionFrame.selectedTexture == textureIndex then
			button:LockHighlight()
		else
			button:UnlockHighlight()
		end
	end
end

function CMinimap_Update()
	-- Shape highlight handled in CUpdateShapeList
end

function CVariable_Update()
	if not CTextureOptionFrame.selectedTexture then
		CVariableOptionFrame:Hide()
		return
	else
		CVariableOptionFrame:Show()
	end
	local texture = CTextureOptionFrame.selectedTexture
	local button
	local slider
	local string
	local thumb
	local high
	local low
	for i,v in ipairs(variableOptionSliders) do
		slider = _G["CVariableSlider"..i]
		string = _G["CVariableSlider"..i.."Text"]
		thumb = _G["CVariableSlider"..i.."Thumb"]
		high = _G["CVariableSlider"..i.."High"]
		low = _G["CVariableSlider"..i.."Low"]
		
		if slider.disabled then
			CDisableSlider(slider)
		else
			CEnableSlider(slider)
		end
		
		slider:SetMinMaxValues(v.minValue, v.maxValue)
		slider:SetValueStep(v.valueStep)
		-- Clamp stored value to slider range before setting
		local storedVal = SexyMap2DB.borders[texture][v.value] or 0
		if storedVal < v.minValue then storedVal = v.minValue end
		if storedVal > v.maxValue then storedVal = v.maxValue end
		slider:SetValue(storedVal)
		slider:SetScript("OnValueChanged", _G[v.func])
		string:SetText(v.text)
		high:SetText(v.maxValue)
		low:SetText(v.minValue)
	end
end



function CTextureButton_OnClick(button)
	local id = this.textureIndex
	CTextureOptionFrame.selectedTexture = id
	CTexture_Update()
	CVariable_Update()
end

function CRotSpeedChanged()
	local i = CTextureOptionFrame.selectedTexture
	SexyMap2DB.borders[i].rotSpeed = this:GetValue()
	CCreateBorder(SexyMap2DB.borders[i])
end


function CScaleChanged()
	local i = CTextureOptionFrame.selectedTexture
	local val = this:GetValue()
	-- Clamp to 0.0 minimum to prevent wrapping
	if val < 0 then val = 0 end
	SexyMap2DB.borders[i].scale = val
	CCreateBorder(SexyMap2DB.borders[i])
end


function CDisableSlider(slider)
	local name = slider:GetName();
	_G[name.."Thumb"]:Hide();
	_G[name.."Text"]:SetVertexColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b);
	_G[name.."Low"]:SetVertexColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b);
	_G[name.."High"]:SetVertexColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b);
end


function CEnableSlider(slider)
	local name = slider:GetName();
	_G[name.."Thumb"]:Show();
	_G[name.."Text"]:SetVertexColor(NORMAL_FONT_COLOR.r , NORMAL_FONT_COLOR.g , NORMAL_FONT_COLOR.b);
	_G[name.."Low"]:SetVertexColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
	_G[name.."High"]:SetVertexColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
end

function GameMenu_AddButton(button)
	if GameMenu_InsertAfter == nil then
		GameMenu_InsertAfter = GameMenuButtonMacros
	end
	if GameMenu_InsertBefore == nil then
		GameMenu_InsertBefore = GameMenuButtonLogout
	end

	button:ClearAllPoints()
	button:SetPoint( "TOP", GameMenu_InsertAfter:GetName(), "BOTTOM", 0, -1 )
	GameMenu_InsertBefore:SetPoint( "TOP", button:GetName(), "BOTTOM", 0, -1 )
	GameMenu_InsertAfter = button
	GameMenuFrame:SetHeight( GameMenuFrame:GetHeight() + button:GetHeight() + 2 )
end

-------------------------------------------------
-- Zone Text Toggle
-------------------------------------------------
function CZoneTextToggle_OnClick()
	if this:GetChecked() then
		SexyMap2DB.showZoneText = true
	else
		SexyMap2DB.showZoneText = false
	end
	CUpdateZoneText()
end

function CZoneTextToggle_Update()
	if SexyMap2DB.showZoneText then
		CZoneTextCheckbox:SetChecked(true)
	else
		CZoneTextCheckbox:SetChecked(false)
	end
end

-------------------------------------------------
-- Minimap Buttons Toggle
-------------------------------------------------
function CMinimapButtonsToggle_OnClick()
	if this:GetChecked() then
		SexyMap2DB.showMinimapButtons = true
	else
		SexyMap2DB.showMinimapButtons = false
	end
	CUpdateMinimapButtonsVisibility()
end

function CMinimapButtonsToggle_Update()
	if SexyMap2DB.showMinimapButtons then
		CMinimapButtonsCheckbox:SetChecked(true)
	else
		CMinimapButtonsCheckbox:SetChecked(false)
	end
end

-------------------------------------------------
-- Minimap Visibility Toggle (replaces the X button)
-------------------------------------------------
function CMinimapToggle_OnClick()
	if this:GetChecked() then
		SexyMap2DB.showMinimap = true
	else
		SexyMap2DB.showMinimap = false
	end
	CUpdateMinimapVisibility()
end

function CMinimapToggle_Update()
	if SexyMap2DB.showMinimap then
		CMinimapCheckbox:SetChecked(true)
	else
		CMinimapCheckbox:SetChecked(false)
	end
end

-------------------------------------------------
-- Map Scale Slider
-------------------------------------------------
function CMapScaleSlider_OnValueChanged()
	local val = this:GetValue()
	if val < 0.3 then val = 0.3 end
	if val > 1.0 then val = 1.0 end
	SexyMap2DB.mapScale = val
	CApplyMapScale()
	-- Update the value text
	CMapScaleSliderValueText:SetText(string.format("%.2f", val))
end


function CMapScaleSlider_Update()
	CMapScaleSlider:SetMinMaxValues(0.3, 1.0)
	CMapScaleSlider:SetValueStep(0.05)
	local val = SexyMap2DB.mapScale or 1.0
	if val < 0.3 then val = 0.3 end
	if val > 1.0 then val = 1.0 end
	CMapScaleSlider:SetValue(val)
	CMapScaleSliderLow:SetText("0.30")
	CMapScaleSliderHigh:SetText("1.00")
	CMapScaleSliderValueText:SetText(string.format("%.2f", val))
end


-------------------------------------------------
-- Set Defaults Button
-------------------------------------------------
function CSetDefaultsBtn_OnClick()
	CSetDefaults()
end
