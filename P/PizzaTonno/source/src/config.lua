local PT = PizzaTonno

local defaultConfig = {
  watch = {},
  -- a caught fish flops out of the water and flies into the HUD (a settings option later)
  catchAnimation = true,
  -- own rates in the HUD: 'all' time or this 'session'
  ownRates = 'all',
  -- right-click in the world to cast while a pole is equipped
  quickCast = true,
  -- 'smart' (the weakest lure that's enough here), 'best' or 'off'
  lures = 'smart',
  -- louder effects, no music or ambience while a pole is equipped
  sounds = true,
  -- degrees around the minimap, counter-clockwise from its right edge
  minimap = { angle = 200, shown = true },
  -- the Journal's catches-over-time chart: 'hours', 'days', 'year' or 'all'
  journalRange = 'days',
}

local defaultCharacter = {
  locked = false,
}

local function fill(saved, defaults)
  for key, defaultValue in pairs(defaults) do
    if saved[key] == nil then
      saved[key] = defaultValue
    end
  end
  return saved
end

function PT:LoadConfig()
  PizzaTonno_config = fill(PizzaTonno_config or {}, defaultConfig)
  PizzaTonno_character = fill(PizzaTonno_character or {}, defaultCharacter)
  PizzaTonno_catches = fill(PizzaTonno_catches or {},
    { areas = {}, pools = {}, days = {}, fished = {}, log = {}, fbOverlap = {},
      imported = { areas = {}, pools = {} } })
end

function PT:ToggleWatch(itemId)
  local watch = PizzaTonno_config.watch
  watch[itemId] = not watch[itemId] or nil
  return watch[itemId]
end
