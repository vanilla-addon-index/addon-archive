local PL = PizzaLoot
PL.money = {}

local GOLD, SILVER = 10000, 100

local coins = {
  { least = GOLD,   color = { 1.0, 0.84, 0.0 },   icon = 'Interface\\Icons\\INV_Misc_Coin_01' },
  { least = SILVER, color = { 0.75, 0.75, 0.75 }, icon = 'Interface\\Icons\\INV_Misc_Coin_03' },
  { least = 0,      color = { 0.72, 0.45, 0.2 },  icon = 'Interface\\Icons\\INV_Misc_Coin_05' },
}

function PL.money.parse(msg)
  local _, _, gold = string.find(msg, '(%d+) Gold')
  local _, _, silver = string.find(msg, '(%d+) Silver')
  local _, _, copper = string.find(msg, '(%d+) Copper')

  local total = (tonumber(gold) or 0) * GOLD + (tonumber(silver) or 0) * SILVER + (tonumber(copper) or 0)
  if total == 0 then return nil end
  return total
end

function PL.money.format(total)
  local gold = math.floor(total / GOLD)
  local silver = math.floor(math.mod(total, GOLD) / SILVER)
  local copper = math.mod(total, SILVER)

  local parts = {}
  if gold > 0 then table.insert(parts, PL.Colors.gold .. gold .. 'g|r') end
  if silver > 0 then table.insert(parts, PL.Colors.silver .. silver .. 's|r') end
  if copper > 0 or table.getn(parts) == 0 then table.insert(parts, PL.Colors.copper .. copper .. 'c|r') end

  return table.concat(parts, ' ')
end

function PL.money.coin(total)
  for _, coin in ipairs(coins) do
    if total >= coin.least then return coin.color, coin.icon end
  end
end
