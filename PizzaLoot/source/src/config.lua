local PL = PizzaLoot

local defaultConfig = {
  locked = true,
  width = PL.layout.width,
  confetti = true,
  slideIn = 'down',
  slideOut = 'left',
}

function PL:LoadConfig()
  if not PizzaLoot_config then
    PizzaLoot_config = {}
  end

  for key, defaultValue in pairs(defaultConfig) do
    if PizzaLoot_config[key] == nil then
      PizzaLoot_config[key] = defaultValue
    end
  end
end
