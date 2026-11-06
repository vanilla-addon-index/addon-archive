local PT = PizzaTonno
PT.cast = {}

-- A right-click shorter than this casts. While a cast is out it takes two within DOUBLE_CLICK, so a
-- single right-click on the bobber still loots it.
local SHORT_CLICK = 0.2
local DOUBLE_CLICK = 0.4
local FISHING_ICON = 'Interface\\Icons\\Trade_Fishing'

-- Weakest first: item id, fishing skill bonus, fishing rank needed. The world DB has no others.
local LURES = {
  { 6529, 25, 0 },     -- Shiny Bauble
  { 6530, 50, 50 },    -- Nightcrawlers
  { 6811, 50, 50 },    -- Aquadynamic Fish Lens
  { 6532, 75, 100 },   -- Bright Baubles
  { 7307, 75, 100 },   -- Flesh Eating Worm
  { 6533, 100, 100 },  -- Aquadynamic Fish Attractor
}

BINDING_HEADER_PIZZATONNO = 'PizzaTonno'
BINDING_NAME_PIZZATONNO_FISH = 'Fish'

local spellId, reboundKeys, clickToMove, addingLure
local pressedAt, firstClickAt = 0, 0

local function findSpell()
  local i = 1
  local texture = GetSpellTexture(i, BOOKTYPE_SPELL)
  while texture do
    if texture == FISHING_ICON then return i end
    i = i + 1
    texture = GetSpellTexture(i, BOOKTYPE_SPELL)
  end
end

local IS_LURE = {}
for _, lure in ipairs(LURES) do IS_LURE[lure[1]] = true end

-- The first bag and slot of each lure the player carries, in one pass: every slot looked at makes a
-- string of its item link.
local function findLures()
  local found = {}
  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      local itemId = PT.utils.itemId(GetContainerItemLink(bag, slot))
      if IS_LURE[itemId] and not found[itemId] then found[itemId] = { bag, slot } end
    end
  end
  return found
end

-- 'smart' takes the weakest lure that still lifts the skill to where nothing here changes any more,
-- or none if it's there already. 'best' (and 'smart' in water without data) takes the strongest.
local function pickLure()
  local mode = PizzaTonno_config.lures
  if mode == 'off' or PT.player.lure() then return end

  local skill, rank = PT.player.skill()
  local area, required = PT.data.spot(PT.player.location())
  local target = mode == 'smart' and area and PT.loot.fullSkill(area.loot, required)
  if target and skill >= target then return end

  local carried, best = findLures(), nil
  for _, lure in ipairs(LURES) do
    local place = carried[lure[1]]
    if place and rank >= lure[3] then
      if target and skill + lure[2] >= target then return place[1], place[2] end
      best = place
    end
  end
  if best then return best[1], best[2] end
end

-- There is no API for objects under the cursor, but the game shows their name in GameTooltip,
-- owned by UIParent. Pools are objects too, and casting at them is the point.
local function onObject()
  if not GameTooltip:IsVisible() or not GameTooltip:IsOwned(UIParent) then return false end
  return not PT.data.isPool(GameTooltipTextLeft1:GetText())
end

-- FishingBuddy hijacks the same click while it's loaded. A unit or object under the cursor or a
-- modifier key gets the ordinary right-click, and a click while the lure goes on would interrupt it.
local function wanted()
  return PizzaTonno_config.quickCast and not IsAddOnLoaded('FishingBuddy') and not addingLure and PT.player.hasPole()
    and not UnitExists('mouseover') and not onObject()
    and not IsShiftKeyDown() and not IsControlKeyDown() and not IsAltKeyDown()
end

-- FishingBuddy's trick: for one click the right button's binding points at our hidden binding, so
-- its mouse-up casts instead of turning or interacting.
local function rebind()
  if reboundKeys then return end
  local key1, key2 = GetBindingKey('TURNORACTION')
  if not key1 then return end
  reboundKeys = { key1, key2 }
  for _, key in ipairs(reboundKeys) do SetBinding(key, 'PIZZATONNO_CAST') end
end

local function restoreBindings()
  if not reboundKeys then return end
  for _, key in ipairs(reboundKeys) do SetBinding(key, 'TURNORACTION') end
  reboundKeys = nil
end

local function onMouseDown()
  if arg1 ~= 'RightButton' or not wanted() then return end
  pressedAt = GetTime()
  -- click-to-move would walk into the water
  if GetCVar('autointeract') == '1' then
    SetCVar('autointeract', '0')
    clickToMove = true
  end
end

local function onMouseUp()
  if arg1 ~= 'RightButton' or not wanted() then return end
  local now = GetTime()
  if now - pressedAt > SHORT_CLICK then return end

  if PT.fishing.casting() and now - firstClickAt > DOUBLE_CLICK then
    firstClickAt = now
    return
  end
  firstClickAt = 0
  rebind()
end

-- Chained rather than replaced, and only once every addon has loaded, so other WorldFrame handlers
-- keep working.
local function hookWorldFrame()
  local oldDown, oldUp = WorldFrame:GetScript('OnMouseDown'), WorldFrame:GetScript('OnMouseUp')
  WorldFrame:SetScript('OnMouseDown', function ()
    onMouseDown()
    if oldDown then oldDown() end
  end)
  WorldFrame:SetScript('OnMouseUp', function ()
    if oldUp then oldUp() end
    onMouseUp()
  end)
end

-- Puts a lure on first if one is due, else casts.
function PT.cast.fish()
  local bag, slot = pickLure()
  if bag then
    UseContainerItem(bag, slot)
    if SpellIsTargeting() then
      PickupInventoryItem(GetInventorySlotInfo('MainHandSlot'))
      addingLure = true
      return
    end
  end

  spellId = spellId or findSpell()
  if spellId then CastSpell(spellId, BOOKTYPE_SPELL) end
end

function PT.cast.onBinding(keystate)
  restoreBindings()
  if keystate ~= 'up' then return end

  -- the mouse-up would otherwise leave the camera turning
  if IsMouselooking() then MouselookStop() end
  PT.cast.fish()
end

-- The pole came off: give click-to-move back.
function PT.cast.stop()
  restoreBindings()
  addingLure = nil
  if clickToMove then
    SetCVar('autointeract', '1')
    clickToMove = nil
  end
end

local function lureDone()
  addingLure = nil
end

local handlers = {
  PLAYER_LOGIN = hookWorldFrame,
  -- the spell may have moved in the spell book
  SPELLS_CHANGED = function () spellId = nil end,
  SPELLCAST_STOP = lureDone,
  SPELLCAST_INTERRUPTED = lureDone,
  SPELLCAST_FAILED = lureDone,
}

local frame = CreateFrame('Frame')
for event in pairs(handlers) do frame:RegisterEvent(event) end
frame:SetScript('OnEvent', function () handlers[event]() end)
