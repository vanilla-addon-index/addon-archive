local PT = PizzaTonno
PT.minimap = {}

-- from the minimap's centre to the button's
local RADIUS = 80

local button = CreateFrame('Button', 'PizzaTonnoMinimapButton', Minimap)
button:SetWidth(31)
button:SetHeight(31)
button:SetFrameStrata('MEDIUM')
button:SetFrameLevel(8)
button:SetHighlightTexture('Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight')
button:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
button:RegisterForDrag('LeftButton')

-- a plain drawn fish: the fishing skill icon and the fish emoji blur at this size
local icon = button:CreateTexture(nil, 'BACKGROUND')
icon:SetTexture('Interface\\AddOns\\PizzaTonno\\img\\fish')
icon:SetWidth(22)
icon:SetHeight(22)
icon:SetPoint('TOPLEFT', button, 'TOPLEFT', 6, -4)

local border = button:CreateTexture(nil, 'OVERLAY')
border:SetTexture('Interface\\Minimap\\MiniMap-TrackingBorder')
border:SetWidth(53)
border:SetHeight(53)
border:SetPoint('TOPLEFT', button, 'TOPLEFT', 0, 0)

local function place()
  local angle = math.rad(PizzaTonno_config.minimap.angle)
  button:ClearAllPoints()
  button:SetPoint('CENTER', Minimap, 'CENTER', RADIUS * math.cos(angle), RADIUS * math.sin(angle))
end

-- follows the cursor around the minimap's rim while dragged
local function follow()
  local scale = Minimap:GetEffectiveScale()
  local x, y = GetCursorPosition()
  local centerX, centerY = Minimap:GetCenter()
  PizzaTonno_config.minimap.angle = math.deg(math.atan2(y / scale - centerY, x / scale - centerX))
  place()
end

local function toggle(key)
  return function ()
    PizzaTonno_config[key] = not PizzaTonno_config[key]
  end
end

local LURE_MODES = {
  { 'smart', 'Weakest that\'s enough' },
  { 'best', 'Always the strongest' },
  { 'off', 'Off' },
}

local menu = CreateFrame('Frame', 'PizzaTonnoMinimapMenu', UIParent, 'UIDropDownMenuTemplate')

local function addItem(text, checked, func, keepShown)
  UIDropDownMenu_AddButton({ text = text, checked = checked, func = func, keepShownOnClick = keepShown })
end

local function fillMenu()
  local config = PizzaTonno_config

  if UIDROPDOWNMENU_MENU_LEVEL == 2 then
    for _, mode in ipairs(LURE_MODES) do
      local key = mode[1]
      UIDropDownMenu_AddButton({ text = mode[2], checked = config.lures == key,
        func = function () config.lures = key end }, 2)
    end
    return
  end

  UIDropDownMenu_AddButton({ text = 'PizzaTonno', isTitle = true, notCheckable = true })
  addItem('Right-click to cast', config.quickCast, toggle('quickCast'), true)
  UIDropDownMenu_AddButton({ text = 'Lures', hasArrow = true, value = 'lures', notCheckable = true })
  addItem('Fishing sounds', config.sounds, function ()
    config.sounds = not config.sounds
    if not config.sounds then PT.sounds.stop() elseif PT.player.hasPole() then PT.sounds.start() end
  end, true)
  addItem('Catch animation', config.catchAnimation, toggle('catchAnimation'), true)
  addItem('Lock the HUD', PizzaTonno_character.locked, function ()
    PizzaTonno_character.locked = not PizzaTonno_character.locked
  end, true)
  UIDropDownMenu_AddButton({ text = 'Import FishingBuddy history', notCheckable = true, func = PT.import.ask })
  addItem('Hide this button', nil, function ()
    PT.minimap.toggle()
    PT:Print('Minimap button hidden. ' .. PT.Colors.primary .. '/pt minimap|r shows it again.')
  end)
end

-- UIDropDownMenu_Initialize would fill it right away, before the saved variables exist;
-- ToggleDropDownMenu calls this each time the menu opens.
menu.initialize = fillMenu

button:SetScript('OnDragStart', function () this:SetScript('OnUpdate', follow) end)
button:SetScript('OnDragStop', function () this:SetScript('OnUpdate', nil) end)
button:SetScript('OnClick', function ()
  PT.tooltip.hide()
  if arg1 == 'LeftButton' then
    PT.almanac.toggle()
  else
    ToggleDropDownMenu(1, nil, menu, 'PizzaTonnoMinimapButton', 0, 0)
  end
end)
button:SetScript('OnEnter', function ()
  PT.tooltip.open(this, 'left')
  PT.tooltip.title(PT.Colors.primary .. 'Pizza' .. PT.Colors.secondary .. 'Tonno')
  PT.tooltip.line('Click for the almanac', PT.ui.GREY)
  PT.tooltip.line('Right-click for settings, drag to move', PT.ui.GREY)
  PT.tooltip.show()
end)
button:SetScript('OnLeave', PT.tooltip.hide)

function PT.minimap.restore()
  place()
  if PizzaTonno_config.minimap.shown then button:Show() else button:Hide() end
end

function PT.minimap.toggle()
  PizzaTonno_config.minimap.shown = not PizzaTonno_config.minimap.shown
  PT.minimap.restore()
end
