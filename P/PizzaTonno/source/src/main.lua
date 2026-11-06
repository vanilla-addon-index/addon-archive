PizzaTonno = CreateFrame('Frame', 'PizzaTonno', UIParent)
local PT = PizzaTonno

PT.Colors = {
  primary = '|cffa050ff',
  secondary = '|cffffffff',
  grey = '|cffaaaaaa',
  day = '|cffffb84d',
  night = '|cff5994f2',
  winter = '|cff66eded',
  green = '|cff00ff98',
  red = '|cffc41e3a',
}

function PT:Print(msg, withPrefix)
  local prefix = withPrefix == false and '' or PT.Colors.primary .. 'Pizza' .. PT.Colors.secondary .. 'Tonno:|r '
  DEFAULT_CHAT_FRAME:AddMessage(prefix .. msg)
end

function PT:PrintClean(msg)
  PT:Print(msg, false)
end

PT:RegisterEvent('VARIABLES_LOADED')
PT:SetScript('OnEvent', function ()
  PT:LoadConfig()
  PT.hud.restore()
  PT.minimap.restore()
end)
