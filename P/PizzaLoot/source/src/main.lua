PizzaLoot = CreateFrame('Frame', 'PizzaLoot', UIParent)
local PL = PizzaLoot

PL.Colors = {
  primary = '|cffa050ff',
  secondary = '|cffffffff',
  grey = '|cffaaaaaa',
  gold = '|cffffd700',
  silver = '|cffc0c0c0',
  copper = '|cffb8732d',
}

PL.quality = {
  RARE = 3,
  EPIC = 4,
  LEGENDARY = 5,
}

PL.layout = {
  width = 190,
  height = 28,
  spacing = 4,
  rows = 5,
}

function PL:Print(msg, withPrefix)
  local prefix = withPrefix == false and '' or PL.Colors.primary .. 'Pizza' .. PL.Colors.secondary .. 'Loot:|r '
  DEFAULT_CHAT_FRAME:AddMessage(prefix .. msg)
end

function PL:PrintClean(msg)
  PL:Print(msg, false)
end

PL:RegisterEvent('VARIABLES_LOADED')
PL:SetScript('OnEvent', function ()
  PL:LoadConfig()
  PL.row.setWidth(PizzaLoot_config.width)
  PL.anchor.restore()
  PL:Print('Loaded! Type ' .. PL.Colors.primary .. '/ploot|r for options.')
end)
