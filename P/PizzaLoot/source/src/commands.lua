local PL = PizzaLoot

local MIN_WIDTH, MAX_WIDTH = 80, 500
local TEST_MONEY = 24713
local DIRECTIONS = { up = true, down = true, left = true, right = true }

local samples = {
  [0] = { 'Runecloth', 5, 'Interface\\Icons\\INV_Fabric_Purplefire_01' },
  [1] = { 'Dreamfoil', 2, 'Interface\\Icons\\INV_Misc_Herb_DreamFoil' },
  [2] = { 'Icy Chill Enchant', 1, 'Interface\\Icons\\Spell_Frost_Stun' },
  [3] = { 'Blade of Eternal Fury', 1, 'Interface\\Icons\\INV_Sword_04' },
  [4] = { 'Ashkandi, Greatsword of the Brotherhood', 1, 'Interface\\Icons\\INV_Sword_50' },
  [5] = { 'Thunderfury, Blessed Blade of the Windseeker', 1, 'Interface\\Icons\\INV_Sword_39' },
}

local tiers = {
  rare = PL.quality.RARE,
  epic = PL.quality.EPIC,
  legendary = PL.quality.LEGENDARY,
}

local function setDirection(key, value, label)
  local direction = value and string.lower(value)
  if not DIRECTIONS[direction] then
    PL:Print(label .. ' direction must be up, down, left or right')
    return
  end

  PizzaLoot_config[key] = direction
  PL:Print(label .. ' direction set to ' .. direction)
end

local function showSample(quality)
  local sample = samples[quality]
  PL.queue.add(PL.notice.item(sample[1], quality, sample[2], sample[3]))
end

SLASH_PIZZALOOT1, SLASH_PIZZALOOT2 = '/ploot', '/pizzaloot'

SlashCmdList['PIZZALOOT'] = function (args)
  local cmd, msg = PL.utils.strSplit(args, ' ')
  local command = cmd and string.lower(cmd)

  if command == 'lock' then
    PL.anchor.setLocked(true)
    PL:Print('Frame locked')
    return
  end

  if command == 'unlock' then
    PL.anchor.setLocked(false)
    PL:Print('Frame unlocked. Drag to reposition.')
    return
  end

  if command == 'reset' then
    PL.anchor.resetPosition()
    PL:Print('Position reset to default')
    return
  end

  if command == 'width' then
    local width = tonumber(msg)
    if not width or width < MIN_WIDTH or width > MAX_WIDTH then
      PL:Print('Width must be between ' .. MIN_WIDTH .. ' and ' .. MAX_WIDTH)
      return
    end

    PizzaLoot_config.width = width
    PL.row.setWidth(width)
    PL:Print('Row width set to ' .. width)
    return
  end

  if command == 'in' then
    setDirection('slideIn', msg, 'Slide-in')
    PL.stack.relayout()
    return
  end

  if command == 'out' then
    setDirection('slideOut', msg, 'Slide-out')
    return
  end

  if command == 'confetti' then
    PizzaLoot_config.confetti = not PizzaLoot_config.confetti
    PL:Print('Confetti on epic and legendary ' .. (PizzaLoot_config.confetti and 'enabled' or 'disabled'))
    return
  end

  if command == 'test' then
    local tier = msg and tiers[string.lower(msg)]
    if tier then
      showSample(tier)
      return
    end

    for quality = 0, PL.quality.EPIC do showSample(quality) end
    PL.queue.add(PL.notice.money(TEST_MONEY))
    return
  end

  PL:PrintClean(PL.Colors.primary .. 'Pizza' .. PL.Colors.secondary .. 'Loot|r commands:')
  PL:PrintClean(PL.Colors.primary .. '   /ploot|r lock ' .. PL.Colors.grey .. '- Lock the frame')
  PL:PrintClean(PL.Colors.primary .. '   /ploot|r unlock ' .. PL.Colors.grey .. '- Unlock and drag to move')
  PL:PrintClean(PL.Colors.primary .. '   /ploot|r reset ' .. PL.Colors.grey .. '- Reset position to default')
  PL:PrintClean(PL.Colors.primary .. '   /ploot|r width ' .. PizzaLoot_config.width .. PL.Colors.grey .. ' - Set row width (' .. MIN_WIDTH .. '-' .. MAX_WIDTH .. ')')
  PL:PrintClean(PL.Colors.primary .. '   /ploot|r in ' .. PizzaLoot_config.slideIn .. PL.Colors.grey .. ' - Slide-in direction: up/down/left/right (up fills top-down)')
  PL:PrintClean(PL.Colors.primary .. '   /ploot|r out ' .. PizzaLoot_config.slideOut .. PL.Colors.grey .. ' - Slide-out direction: up/down/left/right')
  PL:PrintClean(PL.Colors.primary .. '   /ploot|r confetti ' .. PL.Colors.grey .. '- Toggle the epic/legendary confetti burst')
  PL:PrintClean(PL.Colors.primary .. '   /ploot|r test ' .. PL.Colors.grey .. '- Show all quality tiers')
  PL:PrintClean(PL.Colors.primary .. '   /ploot|r test rare/epic/legendary ' .. PL.Colors.grey .. '- Show a single tier')
end
