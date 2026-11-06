local PT = PizzaTonno
local Sauce = PizzaSauce
PT.hud = {}

local WIDTH, PADDING = 270, 10
local HEADER_HEIGHT, FOOTER_HEIGHT = 84, 42
local ROW_HEIGHT, MAX_ROWS = 40, 12
-- inside a row: the icon's and name's top, and the bar's bottom
local ICON_TOP, NAME_TOP, BAR_BOTTOM = 5, 6, 9
-- air between the fish list and the lines above and below it
local LIST_MARGIN = 5
local STRIP_TOP, INNER_WIDTH = 50, WIDTH - 2 * PADDING
local NAME_WIDTH = INNER_WIDTH - 23 - 44 - 15
-- the bars leave room at their right end for the player's own rate
local BAR_WIDTH = INNER_WIDTH - 40
local IDLE_HIDE = 120
-- solid bars look brighter than text of the same colour
local BAR_ALPHA = 0.7
local BAND_ALPHA = 0.15

local SEASON_ICONS = {
  s = 'Interface\\AddOns\\PizzaTonno\\img\\sun',
  w = 'Interface\\AddOns\\PizzaTonno\\img\\snowflake',
}
local SEASONS = { s = 'summer', w = 'winter' }
-- the dependencies of a fish whose chance is the same at any hour and in any season
local ANY_TIME = {}
local CONDITIONS = {
  d = 'Only bites by day',
  n = 'Only bites at night',
  s = 'Summer fish',
  w = 'Winter fish',
  k410 = 'Needs 410 fishing skill',
}

local ui = PT.ui
local tooltip = PT.tooltip
local solid, label, tick = ui.solid, ui.label, ui.tick
local LINE, TRACK, PLAIN, ACCENT = ui.LINE, ui.TRACK, ui.PLAIN, ui.ACCENT
local AMBER, BLUE, ICE, WHITE, GREY = ui.AMBER, ui.BLUE, ui.ICE, ui.WHITE, ui.GREY
local SUMMER, WINTER = ui.SUMMER, ui.WINTER

local frame = CreateFrame('Frame', 'PizzaTonnoHud', UIParent)
frame:SetWidth(WIDTH)
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:Hide()

local function anchor()
  local x, y = PizzaTonno_character.x, PizzaTonno_character.y
  frame:ClearAllPoints()
  if x and y then
    frame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', x, y)
  else
    frame:SetPoint('TOPRIGHT', UIParent, 'RIGHT', -220, 160)
  end
end

local function startDrag()
  if not PizzaTonno_character.locked then frame:StartMoving() end
end

-- Dragging leaves the frame anchored wherever the client likes; pin it by its top left again so
-- it keeps growing downwards.
local function stopDrag()
  frame:StopMovingOrSizing()
  PizzaTonno_character.x, PizzaTonno_character.y = frame:GetLeft(), frame:GetTop()
  anchor()
end

-- Frames that take the mouse for a tooltip swallow the drag, so each one passes it on.
local function draggable(region)
  region:EnableMouse(true)
  region:SetScript('OnMouseDown', startDrag)
  region:SetScript('OnMouseUp', stopDrag)
end

draggable(frame)

-- Like draggable, but a press that didn't move the card is a click.
local function clickable(region, onClick)
  region:EnableMouse(true)
  region:SetScript('OnMouseDown', function ()
    this.pressedAt = { frame:GetLeft(), frame:GetTop() }
    startDrag()
  end)
  region:SetScript('OnMouseUp', function ()
    local clicked = frame:GetLeft() == this.pressedAt[1] and frame:GetTop() == this.pressedAt[2]
    stopDrag()
    if clicked then onClick(this, arg1) end
  end)
end

ui.panel(frame, 0.9)

local title = label(frame, 13, 'TOPLEFT', PADDING, -13, WHITE)
local place = label(frame, 10, 'TOPLEFT', PADDING, -31, GREY)
local clock = label(frame, 13, 'TOPRIGHT', -PADDING, -13, WHITE)
label(frame, 10, 'TOPRIGHT', -PADDING, -31, GREY):SetText('zone time')
local skillText = label(frame, 10, 'TOPLEFT', PADDING, -STRIP_TOP - 13, GREY)
local flipText = label(frame, 10, 'TOPRIGHT', -PADDING, -STRIP_TOP - 13, GREY)
local basisText = label(frame, 10, 'BOTTOMLEFT', PADDING, 25, GREY)
local sessionText = label(frame, 10, 'BOTTOMLEFT', PADDING, 9, GREY)
local lureText = label(frame, 10, 'BOTTOMRIGHT', -PADDING, 9, GREY)
local noData = label(frame, 11, 'TOPLEFT', PADDING, -HEADER_HEIGHT - 12, GREY)
noData:SetText('No fishing data for this water')

-- the zone's 24 hours: night, day (06-18), night, and a marker for now
local function stripPart(from, to, color)
  local part = solid(frame, 'ARTWORK', color, BAR_ALPHA)
  part:SetPoint('TOPLEFT', frame, 'TOPLEFT', PADDING + from * INNER_WIDTH, -STRIP_TOP)
  part:SetWidth((to - from) * INNER_WIDTH)
  part:SetHeight(4)
end

stripPart(0, 0.25, BLUE)
stripPart(0.25, 0.75, AMBER)
stripPart(0.75, 1, BLUE)

local marker = tick(frame, 10)

local function separator(point, y)
  local line = solid(frame, 'BORDER', LINE)
  line:SetPoint('LEFT', frame, point .. 'LEFT', 0, y)
  line:SetPoint('RIGHT', frame, point .. 'RIGHT', 0, y)
  line:SetHeight(1)
end

separator('TOP', -HEADER_HEIGHT)
separator('BOTTOM', FOOTER_HEIGHT)

-- what the rows currently describe, for their tooltips
local here = {}

local function thisSession()
  return PizzaTonno_config.ownRates == 'session'
end

-- The player's counts here the way the rows compare them: at any hour or only in this light, in any
-- season or only this one. A refresh needs at most four of these, so each is counted once.
local tallyCounts, tallyTotals = {}, {}

local function forgetTallies()
  for key = 0, 3 do tallyCounts[key], tallyTotals[key] = nil, nil end
end

local function tally(light, season)
  local key = (light and 1 or 0) + (season and 2 or 0)
  if not tallyCounts[key] then
    tallyCounts[key], tallyTotals[key] = PT.catches.counts(here.zone, here.subzone, light and here.day, season,
      thisSession())
  end
  return tallyCounts[key], tallyTotals[key]
end

-- A leftover fish (chance 0) gets whatever its group's other fish leave, so its chance rises while a
-- day, night or seasonal fish of the group can't bite. Names those fish, or nil.
local function leftoverNote(itemId)
  local group
  for _, lootRow in ipairs(here.loot) do
    if lootRow[1] == itemId and lootRow[2] == 0 and lootRow[3] ~= 0 then group = lootRow[3] end
  end
  if not group then return end

  local names = {}
  for _, lootRow in ipairs(here.loot) do
    local condition = lootRow[4]
    if lootRow[3] == group and condition and condition ~= 'k410' then
      table.insert(names, PT.data.item(lootRow[1]) or 'Item ' .. lootRow[1])
    end
  end
  if table.getn(names) == 0 then return end
  return 'Gets what the other fish leave, so more while ' .. table.concat(names, ' or ') .. ' can\'t bite'
end

local function showTooltip(row)
  local itemId = row.itemId
  local when = (row.light and (here.day and ' by day' or ' at night') or '') .. (row.season and ' this season' or '')
  local counts, catches = tally(row.light, row.season)
  local yours = thisSession() and 'Yours this session: ' or 'Yours: '

  tooltip.open(row)
  tooltip.title(PT.data.item(itemId) or 'Item ' .. itemId)
  if PizzaTonno_config.watch[itemId] then tooltip.watched() end
  tooltip.line('Predicted: ' .. PT.utils.percent(row.chance) .. ' of catches right now')
  if catches > 0 then
    local n = counts[itemId] or 0
    local low, high = PT.utils.likelyRange(n, catches)
    tooltip.line(yours .. PT.utils.percent(n / catches) .. ' (' .. n .. ' of ' .. catches
      .. ' catches here' .. when .. ')')
    tooltip.line('95% likely between ' .. PT.utils.percent(low) .. ' and ' .. PT.utils.percent(high), GREY)
  else
    tooltip.line(yours .. 'no catches here' .. when .. ' yet', GREY)
  end

  local note = leftoverNote(itemId)
  if note then tooltip.line(note, ICE) end

  local condition = row.condition
  if condition then
    local note = CONDITIONS[condition]
    if SEASONS[condition] then
      local _, seconds = PT.clock.event(SEASONS[condition])
      note = note .. ', season ends in ' .. PT.utils.duration(seconds)
    end
    tooltip.line(note, ICE)
  end

  local caught = PT.fishing.session().items[itemId]
  if caught then tooltip.line('This session: ' .. caught, GREY) end
  tooltip.best(itemId)
  tooltip.gap()
  tooltip.line('Click for its page, right-click to ' .. (PizzaTonno_config.watch[itemId] and 'stop watching' or 'watch'),
    GREY)
  tooltip.show()
end

local header = CreateFrame('Frame', nil, frame)
header:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, 0)
header:SetPoint('BOTTOMRIGHT', frame, 'TOPRIGHT', 0, -HEADER_HEIGHT)
draggable(header)
header:SetScript('OnLeave', tooltip.hide)
header:SetScript('OnEnter', function ()
  tooltip.open(this)
  tooltip.title(title:GetText())

  local required = here.required
  if required then
    local skill, rank, modifier = PT.player.skill()
    if required > 0 then tooltip.line('Needs ' .. required .. ' fishing skill') end
    -- a catch lands skill - needed + 5 percent of the time
    tooltip.line('No fish gets away at ' .. required + 95)
    tooltip.line('Yours: ' .. skill .. ' (' .. rank .. ' +' .. modifier .. ')', GREY)
  end

  tooltip.line('The clock is this zone\'s time, which the fish follow.', GREY)
  tooltip.line('Day is 06:00 to 18:00. Kalimdor runs 12 hours apart from the Eastern Kingdoms.', GREY)
  tooltip.show()
end)

local footer = CreateFrame('Frame', nil, frame)
footer:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 0, 0)
footer:SetPoint('TOPRIGHT', frame, 'BOTTOMRIGHT', 0, FOOTER_HEIGHT)
draggable(footer)
footer:SetScript('OnLeave', tooltip.hide)
footer:SetScript('OnEnter', function ()
  tooltip.open(this)
  tooltip.title(thisSession() and 'Your rates this session' or 'Your rates, all time')
  tooltip.line('White numbers and ticks: how often you caught each fish here.')
  tooltip.line('The faint band around a tick is where the true rate likely is. It narrows the more you catch.',
    GREY)
  tooltip.show()
end)

-- Where the player's own rates come from: two words at the right of the footer, the chosen one in
-- purple, the other lighting up under the mouse.
local modes = {}

local function paintModes()
  for _, button in ipairs(modes) do
    local active = PizzaTonno_config.ownRates == button.mode
    local color = active and ACCENT or button.hovered and WHITE or GREY
    button.text:SetTextColor(color[1], color[2], color[3])
  end
end

local function modeButton(text, mode, tip)
  local button = CreateFrame('Frame', nil, footer)
  button.mode = mode
  button.text = label(button, 10, 'BOTTOMRIGHT', 0, 0, GREY)
  button.text:SetText(text)
  button:SetWidth(button.text:GetStringWidth())
  button:SetHeight(12)
  button:SetScript('OnEnter', function ()
    this.hovered = true
    paintModes()
    tooltip.open(this)
    tooltip.title(tip)
    tooltip.show()
  end)
  button:SetScript('OnLeave', function ()
    this.hovered = false
    paintModes()
    tooltip.hide()
  end)
  clickable(button, function ()
    PizzaTonno_config.ownRates = mode
    PT.hud.refresh()
  end)
  table.insert(modes, button)
  return button
end

local sessionMode = modeButton('Session', 'session', 'Your rates from this session\'s catches here')
sessionMode:SetPoint('BOTTOMRIGHT', footer, 'BOTTOMRIGHT', -PADDING, 25)
local allMode = modeButton('All time', 'all', 'Your rates from all your catches here')
allMode:SetPoint('BOTTOMRIGHT', sessionMode, 'BOTTOMLEFT', -10, 0)

local rows = {}

local HOVER, FLASH = 0.06, 0.25
local ICON_SIZE = 16

-- Fades a row's highlight to where it belongs: faintly lit under the mouse, dark otherwise. Every
-- hover does it, so each row keeps its fade and replays it.
local function settleGlow(row, from, duration)
  Sauce:Stop(row.glow)
  if not row.settle then
    row.settle = Sauce:Tween(row.glow, { type = 'alpha', easing = 'outCubic', defer = true })
  end
  row.settle:SetFrom(from)
  row.settle:SetTo(row.hovered and HOVER or 0)
  row.settle:SetDuration(duration)
  row.settle:Play()
end

local function setIconSize(icon, size)
  icon:SetWidth(size)
  icon:SetHeight(size)
end

local function rowOf(itemId)
  for _, row in ipairs(rows) do
    if row.itemId == itemId and row:IsShown() then return row end
  end
end

-- The row of a fish lights up and fades back while its icon pops by `pop` pixels. Looked up by
-- fish, not by row: watching one re-sorts the list.
local function pulse(itemId, pop)
  local row = rowOf(itemId)
  if not row then return end

  settleGlow(row, FLASH, 0.6)
  Sauce:Stop(row.icon)
  if not row.pop then
    row.grow = Sauce:Tween(row.icon, { type = 'custom', from = ICON_SIZE, duration = 0.1, easing = 'outQuad',
      setter = setIconSize, defer = true })
    row.shrink = Sauce:Tween(row.icon, { type = 'custom', to = ICON_SIZE, duration = 0.3, easing = 'outBack',
      setter = setIconSize, defer = true })
    row.pop = Sauce:Sequence({ row.grow, row.shrink }, { defer = true })
  end
  row.grow:SetTo(ICON_SIZE + pop)
  row.shrink:SetFrom(ICON_SIZE + pop)
  row.pop:Play()
end

local FLY_SIZE, FLY_TIME = 40, 0.55
local MIN_BEND, MAX_BEND = 25, 110
-- pixels per second squared, shared by the yank and the hops so they fall alike
local GRAVITY = 1900
-- the yank: from a speck this far below the cursor, flung this high above it
local YANK_SIZE, YANK_DEPTH = 4, 30
local MIN_FLING, MAX_FLING = 100, 150
-- and how far to the side of the cursor it lands, at most
local MAX_DRIFT = 50
-- landing: one tiny bounce (a fish is no rubber ball), then it lies still a moment before it flops
local THUD = 4
local MIN_LIE, MAX_LIE = 0.4, 0.8
-- how far up the screen the ground is
local GROUND = 0.45
local REST_TIME = 0.5
local CROP = { 0.08, 0.92, 0.08, 0.92 }
local flyers = {}
-- Fish in the air, by item: their rows keep the old tick until they land. Catches whose fish are
-- still in the air aren't in the footer's count yet either.
local arriving = {}
local airborne = { catches = 0, poolCatches = 0 }

local function flyer()
  for _, fish in ipairs(flyers) do
    if not fish:IsShown() then return fish end
  end

  local fish = CreateFrame('Frame', nil, UIParent)
  fish:SetFrameStrata('TOOLTIP')
  fish.icon = fish:CreateTexture(nil, 'ARTWORK')
  fish.icon:SetAllPoints()
  table.insert(flyers, fish)
  return fish
end

local function mirror(fish, mirrored)
  local left, right = CROP[1], CROP[2]
  if mirrored then left, right = right, left end
  fish.icon:SetTexCoord(left, right, CROP[3], CROP[4])
end

local function random(low, high)
  return low + math.random() * (high - low)
end

-- Yanked out of the water: a thrown fish, fired from below the cursor high into the air at a slight
-- angle, landing a little to one side on the ground, where it then flops. The cursor is on the
-- water, so the ground is lower: GROUND up the screen, or the cursor's height if that's lower
-- still. It grows to full size on the way up. Returns how long the throw takes.
local function planYank(fish)
  local top = fish.fromY + random(MIN_FLING, MAX_FLING)
  fish.startX, fish.startY = fish.fromX, fish.fromY - YANK_DEPTH
  fish.fromX = fish.fromX + random(-MAX_DRIFT, MAX_DRIFT)
  -- GetHeight() stays at 768 whatever the UI scale; the top edge is in the units we place things in
  fish.fromY = math.min(fish.fromY, UIParent:GetTop() * GROUND)
  fish.speed = math.sqrt(2 * GRAVITY * (top - fish.startY))
  fish.riseTime = fish.speed / GRAVITY
  return fish.riseTime + math.sqrt(2 * (top - fish.fromY) / GRAVITY)
end

local function yankStep(fish, t)
  local time = t * fish.yankTime
  local left = 1 - math.min(time / fish.riseTime, 1)
  local grown = 1 - left * left
  local size = YANK_SIZE + (FLY_SIZE - YANK_SIZE) * grown
  local y = fish.startY + fish.speed * time - GRAVITY * time * time / 2
  fish:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', fish.startX + (fish.fromX - fish.startX) * t, y)
  fish:SetWidth(size)
  fish:SetHeight(size)
  fish:SetAlpha(math.min(time / (fish.riseTime * 0.3), 1))
  mirror(fish, false)
end

local function thudStep(fish, t)
  fish:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', fish.fromX, fish.fromY + THUD * 4 * t * (1 - t))
end

-- how many half turns a hop makes: none, a flip, or a quick full spin
local TURNS = { 0, 0, 1, 1, 2 }
-- faster than this per half turn is a blur
local HALF_TURN_TIME = 0.09

-- Every fish flops its own way: 3 to 5 hops, each a random bit lower than the last and as long as
-- a real jump of that height would take (the square root of it). Each hop may turn the fish over,
-- at its own moment and speed. The turns add up to an even number, so it ends facing the way it
-- came out.
local function planHops(fish)
  local count, height, total, turns = math.random(3, 5), random(30, 44), 0, 0
  fish.hops = {}
  for i = 1, count do
    local from = random(0, 0.3)
    local hop = { time = math.sqrt(8 * height / GRAVITY), height = height, base = turns, from = from,
      span = random(0.35, 1 - from) }
    hop.most = math.floor(hop.time * hop.span / HALF_TURN_TIME)
    hop.turns = math.min(TURNS[math.random(table.getn(TURNS))], hop.most)
    fish.hops[i] = hop
    total, turns = total + hop.time, turns + hop.turns
    height = height * random(0.4, 0.7)
  end

  -- even out, on the last hop that can take one more half turn or give one up
  for i = count, 1, -1 do
    local hop = fish.hops[i]
    if math.mod(turns, 2) == 0 then break end
    local change = hop.turns < hop.most and 1 or hop.turns > 0 and -1 or 0
    hop.turns, turns = hop.turns + change, turns + change
    for j = i + 1, count do fish.hops[j].base = fish.hops[j].base + change end
  end
  return total
end

-- There's no 3D in this client, so the turn is faked: the width follows the cosine of the turn,
-- and the picture is mirrored while its back side faces us.
local function flopStep(fish, t)
  local elapsed, start = t * fish.flopTime, 0
  for i, hop in ipairs(fish.hops) do
    if elapsed <= start + hop.time or i == table.getn(fish.hops) then
      local u = math.min((elapsed - start) / hop.time, 1)
      local spin = math.min(math.max((u - hop.from) / hop.span, 0), 1)
      local turn = (hop.base + hop.turns * spin) * math.pi
      -- a parabola, like a real jump
      fish:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', fish.fromX, fish.fromY + hop.height * 4 * u * (1 - u))
      fish:SetWidth(math.max(FLY_SIZE * math.abs(math.cos(turn)), 1))
      mirror(fish, math.cos(turn) < 0)
      return
    end
    start = start + hop.time
  end
end

-- A caught fish comes out of the water at the cursor, which sits on the bobber when you click it,
-- flops a few times, lies still for a moment, then flies into its row and the row swallows it:
-- only then does the tick move to the new rate.
-- Along an arc that bulges sideways from the straight line by `fish.bend` pixels at its middle,
-- shrinking to the size of the row's icon.
local function flyStep(fish, t)
  local dx, dy = fish.toX - fish.fromX, fish.toY - fish.fromY
  local length = math.max(math.sqrt(dx * dx + dy * dy), 1)
  local bulge = fish.bend * math.sin(t * math.pi) / length
  local x = fish.fromX + dx * t - dy * bulge
  local y = fish.fromY + dy * t + dx * bulge
  local size = FLY_SIZE + (ICON_SIZE - FLY_SIZE) * t
  fish:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', x, y)
  fish:SetWidth(size)
  fish:SetHeight(size)
end

-- `catch` is the loot window the fish came in: it counts once its last fish is down (unless it's
-- only a show, like the demo).
local function land(itemId, catch, animated)
  arriving[itemId] = arriving[itemId] > 1 and arriving[itemId] - 1 or nil
  catch.left = catch.left - 1
  if catch.left == 0 and catch.counted then
    airborne.catches = airborne.catches - 1
    if catch.fromPool then airborne.poolCatches = airborne.poolCatches - 1 end
  end
  PT.hud.refresh()
  if not animated then return end

  pulse(itemId, 9)
  if PizzaTonno_config.watch[itemId] then PT.confetti.burst(rowOf(itemId)) end
end

local function flyIn(itemId, catch)
  local row = rowOf(itemId)
  if not row or not PizzaTonno_config.catchAnimation then
    land(itemId, catch, false)
    return
  end

  local scale = UIParent:GetEffectiveScale()
  local x, y = GetCursorPosition()

  local fish = flyer()
  fish.fromX, fish.fromY = x / scale, y / scale
  fish.toX, fish.toY = row:GetLeft() + ICON_SIZE / 2, row:GetTop() - ICON_TOP - ICON_SIZE / 2
  -- every fish takes its own curve, bending to either side
  fish.bend = (MIN_BEND + math.random() * (MAX_BEND - MIN_BEND)) * (math.random(2) == 1 and 1 or -1)
  fish.icon:SetTexture(ui.icon(itemId))
  fish.yankTime, fish.flopTime = planYank(fish), planHops(fish)
  fish.item, fish.catch = itemId, catch
  yankStep(fish, 0)
  fish:Show()

  -- each flyer builds its flight once and replays it with this throw's timings
  if not fish.flight then
    fish.yank = Sauce:Tween(fish, { type = 'custom', from = 0, to = 1, easing = 'linear', setter = yankStep,
      defer = true })
    fish.flop = Sauce:Tween(fish, { type = 'custom', from = 0, to = 1, easing = 'linear', setter = flopStep,
      defer = true })
    fish.flight = Sauce:Sequence({
      fish.yank,
      Sauce:Tween(fish, { type = 'custom', from = 0, to = 1, duration = math.sqrt(8 * THUD / GRAVITY),
        easing = 'linear', setter = thudStep, defer = true }),
      fish.flop,
      Sauce:Tween(fish, { type = 'custom', from = 0, to = 1, duration = FLY_TIME, easing = 'inQuad',
        setter = flyStep, delay = REST_TIME, defer = true }),
    }, { onFinish = function ()
      fish:Hide()
      land(fish.item, fish.catch, true)
    end, defer = true })
  end
  fish.yank:SetDuration(fish.yankTime)
  fish.flop:SetDuration(fish.flopTime)
  fish.flop:SetDelay(random(MIN_LIE, MAX_LIE))
  fish.flight:Play()
end

local function createRow(i)
  local row = CreateFrame('Frame', nil, frame)
  local y = -HEADER_HEIGHT - LIST_MARGIN - (i - 1) * ROW_HEIGHT
  row:SetPoint('TOPLEFT', frame, 'TOPLEFT', PADDING, y)
  row:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -PADDING, y)
  row:SetHeight(ROW_HEIGHT)
  row:EnableMouse(true)
  row:SetScript('OnEnter', function ()
    this.hovered = true
    settleGlow(this, nil, 0.15)
    showTooltip(this)
  end)
  row:SetScript('OnLeave', function ()
    this.hovered = false
    settleGlow(this, nil, 0.3)
    tooltip.hide()
  end)
  -- like anywhere in the almanac: left-click for the fish's page, right-click to watch
  clickable(row, function (row, button)
    if button ~= 'RightButton' then return PT.almanac.open('fish', row.itemId) end
    PT:ToggleWatch(row.itemId)
    PT.hud.refresh()
    PT.almanac.refresh()
    pulse(row.itemId, 5)
    showTooltip(row)
  end)

  row.glow = row:CreateTexture(nil, 'BACKGROUND')
  row.glow:SetTexture(1, 1, 1)
  row.glow:SetAlpha(0)

  -- Bright for watched fish, dimmed for the rest. Anchored by its centre so it can pop without
  -- shifting.
  row.icon = row:CreateTexture(nil, 'ARTWORK')
  row.icon:SetPoint('CENTER', row, 'TOPLEFT', ICON_SIZE / 2, -ICON_TOP - ICON_SIZE / 2)
  setIconSize(row.icon, ICON_SIZE)
  -- cut off the icon's baked-in border
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  row.name = label(row, 11, 'TOPLEFT', 23, -NAME_TOP, WHITE)
  row.name:SetWidth(NAME_WIDTH)
  row.name:SetHeight(14)
  row.name:SetJustifyH('LEFT')

  -- sun or snowflake behind the name of a seasonal fish
  row.seasonIcon = row:CreateTexture(nil, 'ARTWORK')
  row.seasonIcon:SetWidth(11)
  row.seasonIcon:SetHeight(11)

  -- predicted in the bar's colour; the player's own rate below it in white, like their tick
  -- centred on the name's line and on the bar
  row.rate = label(row, 11, 'RIGHT', 0, 0, WHITE)
  row.rate:SetPoint('RIGHT', row, 'TOPRIGHT', 0, -NAME_TOP - 7)
  row.own = label(row, 10, 'RIGHT', 0, 0, WHITE)
  row.own:SetPoint('RIGHT', row, 'BOTTOMRIGHT', 0, BAR_BOTTOM + 1.5)

  -- the whole width is 100% of catches
  local track = solid(row, 'BORDER', TRACK)
  track:SetPoint('BOTTOMLEFT', row, 'BOTTOMLEFT', 0, BAR_BOTTOM)
  track:SetWidth(BAR_WIDTH)
  track:SetHeight(3)

  row.bar = row:CreateTexture(nil, 'ARTWORK')
  row.bar:SetPoint('LEFT', track, 'LEFT', 0, 0)
  row.bar:SetHeight(3)

  -- the player's own rate, and the range the true rate is likely in
  row.mark = tick(row, 7)
  row.mark.track = track
  -- where the mark is, where it slides from and to, and where the row wants it (`setRow`)
  row.mark.at, row.mark.from, row.mark.to, row.yours = {}, {}, {}, {}
  row.mark.band = solid(row, 'OVERLAY', WHITE, BAND_ALPHA)
  row.mark.band:SetHeight(7)

  rows[i] = row
  return row
end

-- The tick at `x` and its band from `low` to `high`, in pixels along the bar.
local function placeMark(mark, x, low, high)
  local at = mark.at
  at.x, at.low, at.high = x, low, high
  mark:SetPoint('CENTER', mark.track, 'LEFT', x, 0)
  mark.band:SetPoint('LEFT', mark.track, 'LEFT', low, 0)
  mark.band:SetWidth(math.max(high - low, 1))
end

local function slideStep(mark, t)
  local from, to = mark.from, mark.to
  placeMark(mark, from.x + (to.x - from.x) * t, from.low + (to.low - from.low) * t,
    from.high + (to.high - from.high) * t)
end

-- Slides to `spot` on the bar (nil hides the mark); jumps when the row now shows another fish. A
-- catch moves every mark, so each one builds its slide once and replays it.
local function moveMark(mark, spot, slide)
  if not spot then
    mark.aimed = false
    mark:Hide()
    mark.band:Hide()
    return
  end

  local to = mark.to
  if not (mark.aimed and to.x == spot.x and to.low == spot.low and to.high == spot.high) then
    Sauce:Stop(mark)
    to.x, to.low, to.high = spot.x, spot.low, spot.high
    if slide and mark.aimed then
      if not mark.slide then
        mark.slide = Sauce:Tween(mark, { type = 'custom', from = 0, to = 1, duration = 0.5, easing = 'outCubic',
          setter = slideStep, defer = true })
      end
      local from, at = mark.from, mark.at
      from.x, from.low, from.high = at.x, at.low, at.high
      mark.slide:Play()
    else
      placeMark(mark, spot.x, spot.low, spot.high)
    end
    mark.aimed = true
  end
  mark:Show()
  mark.band:Show()
end

-- `caught` of the player's `catches` here brought this fish.
local function setRow(row, itemId, chance, condition, watched, caught, catches)
  local sameFish = row.itemId == itemId
  row.itemId, row.chance, row.condition = itemId, chance, condition

  local itemName = PT.data.item(itemId)
  -- the item's quality colour, dimmed for fish nobody watches
  local name, shade = ui.quality(itemId), watched and 1 or 0.65
  row.name:SetText(itemName or 'Item ' .. itemId)
  row.name:SetTextColor(name[1] * shade, name[2] * shade, name[3] * shade)

  if SEASON_ICONS[condition] then
    local tint = condition == 'w' and WINTER or SUMMER
    row.seasonIcon:SetTexture(SEASON_ICONS[condition])
    row.seasonIcon:SetVertexColor(tint[1], tint[2], tint[3])
    row.seasonIcon:SetPoint('LEFT', row.name, 'LEFT', math.min(row.name:GetStringWidth(), NAME_WIDTH) + 4, 0)
    row.seasonIcon:Show()
  else
    row.seasonIcon:Hide()
  end
  row.icon:SetTexture(ui.icon(itemId))
  local shade = watched and 1 or 0.45
  row.icon:SetVertexColor(shade, shade, shade)

  local bar = watched and ACCENT or PLAIN
  row.bar:SetTexture(bar[1], bar[2], bar[3], BAR_ALPHA)
  row.bar:SetWidth(math.max(chance * BAR_WIDTH, 1))
  -- Every tick waits while a fish is in the air, so they all slide together when it lands. A row
  -- that now shows another fish jumps at once.
  if not next(arriving) or not sameFish and not arriving[itemId] then
    local spot
    if catches > 0 then
      local low, high = PT.utils.likelyRange(caught, catches)
      spot = row.yours
      spot.x, spot.low, spot.high = caught / catches * BAR_WIDTH, low * BAR_WIDTH, high * BAR_WIDTH
    end
    moveMark(row.mark, spot, sameFish)
    row.own:SetText(catches > 0 and PT.utils.percent(caught / catches) or '')
  end

  row.rate:SetText(PT.utils.percent(chance))
  row.rate:SetTextColor(bar[1], bar[2], bar[3])
  row:Show()
end

-- Fills the rows with what this water can give under these conditions, watched fish first.
-- Returns how many.
local function fillRows(area, chances)
  local watch, caught = PizzaTonno_config.watch, PT.fishing.session().items

  local conditions, itemIds = {}, {}
  for _, lootRow in ipairs(area.loot) do
    if lootRow[4] then conditions[lootRow[1]] = lootRow[4] end
  end

  -- Own rates are compared like for like: a fish whose chance changes with day and night or with
  -- the season only counts the catches made under the same conditions as now.
  local depends, season = PT.loot.dependencies(area.loot), PT.clock.season()
  for itemId, chance in pairs(chances) do
    if chance > 0 then table.insert(itemIds, itemId) end
  end
  table.sort(itemIds, function (a, b)
    if watch[a] ~= watch[b] then return watch[a] == true end
    return chances[a] > chances[b]
  end)

  -- past the cap only what the player watches or caught this session still gets a row
  local count = 0
  for i, itemId in ipairs(itemIds) do
    if i <= MAX_ROWS or watch[itemId] or caught[itemId] then
      count = count + 1
      itemIds[count] = itemId
    end
  end

  for i = 1, count do
    local itemId, row = itemIds[i], rows[i] or createRow(i)

    -- Highlights sit 2 above their row so icon and bar are centred in them, and tile down the
    -- list; the first and last stretch over the list's margin to the lines above and below.
    row.glow:SetPoint('TOPLEFT', row, 'TOPLEFT', -PADDING + 1, i == 1 and LIST_MARGIN or 2)
    row.glow:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', PADDING - 1, i == count and -LIST_MARGIN or 2)
    local depend = depends[itemId] or ANY_TIME
    row.light, row.season = depend.light, depend.season and season

    local counts, catches = tally(row.light, row.season)
    setRow(row, itemId, chances[itemId], conditions[itemId], watch[itemId], counts[itemId] or 0, catches)
  end
  return count
end

-- /pt demo: a made-up table to look at long names and both seasonal marks at once
local DEMO = { loot = {
  { 11208, 22, 1 }, { 13756, 18, 1, 's' }, { 13755, 14, 1, 'w' }, { 13422, 9, 1 }, { 7973, 0.4, 1 }, { 13888, 0, 1 },
} }
local DEMO_CONDITIONS = { d = true, n = true, s = true, w = true }
local demo = false

-- What moves with the clock: the time and its marker, the countdown to day or night, the session and
-- the lure.
local function paintTime()
  local hour, minute = GetGameTime()
  local day = PT.clock.isDay(hour)
  local sky = day and AMBER or BLUE
  clock:SetText(string.format('%02d:%02d', hour, minute))
  clock:SetTextColor(sky[1], sky[2], sky[3])
  marker:SetPoint('CENTER', frame, 'TOPLEFT', PADDING + (hour * 60 + minute) / 1440 * INNER_WIDTH, -STRIP_TOP - 2)
  flipText:SetText((day and 'Night in ' or 'Day in ') .. PT.utils.duration(PT.clock.untilFlip(hour, minute) * 60))

  local session, seconds = PT.fishing.session()
  local catches, poolCatches = session.catches - airborne.catches, session.poolCatches - airborne.poolCatches
  if catches == 0 then
    sessionText:SetText('No catches yet')
  else
    local pool = poolCatches > 0 and ' (' .. poolCatches .. ' pool)' or ''
    sessionText:SetText(catches .. (catches == 1 and ' catch' or ' catches') .. pool .. ' in ' .. PT.utils.duration(seconds))
  end

  local lure = PT.player.lure()
  local lureColor = lure and ACCENT or GREY
  lureText:SetText(lure and string.format('Lure %d:%02d', math.floor(lure / 60), math.mod(lure, 60)) or 'No lure')
  lureText:SetTextColor(lureColor[1], lureColor[2], lureColor[3])
end

function PT.hud.refresh()
  local zone, subzone = PT.player.location()
  local day = PT.clock.isDay((GetGameTime()))
  local area, required = PT.data.spot(zone, subzone)
  if demo then area, required = DEMO, 0 end
  local skill, rank, modifier = PT.player.skill()
  here.zone, here.subzone, here.day, here.required = zone, subzone, day, area and required
  here.loot, here.skill, here.season = area and area.loot, skill, PT.clock.season()
  forgetTallies()

  title:SetText(subzone == '' and zone or subzone)
  place:SetText(subzone == '' and '' or zone)

  local skillLine = 'Skill ' .. rank .. (modifier > 0 and ' +' .. modifier or '')
  if area then
    skillLine = skillLine .. ', lands ' .. string.format('%.0f%%', PT.loot.landing(skill, required) * 100)
  end
  skillText:SetText(skillLine)

  local count = 0
  if area then
    local chances = demo and PT.loot.chances(DEMO.loot, DEMO_CONDITIONS) or PT.loot.rolled(area.loot, day,
      PT.clock.event('summer'), PT.clock.event('winter'), skill >= PT.loot.ELITE_SKILL)
    count = fillRows(area, chances)
  end
  for i = count + 1, table.getn(rows) do rows[i]:Hide() end
  if area then noData:Hide() else noData:Show() end

  -- what the white numbers rest on: every open-water catch here (a fish that depends on day and
  -- night or the season uses fewer, see its tooltip)
  local _, basis = tally()
  basis = basis - (airborne.catches - airborne.poolCatches)
  basisText:SetText(basis == 0 and 'No catches here yet'
    or 'Based on ' .. basis .. (basis == 1 and ' catch' or ' catches') .. ' here')
  paintModes()
  paintTime()

  frame:SetHeight(HEADER_HEIGHT + math.max(count, 1) * ROW_HEIGHT + 2 * LIST_MARGIN + FOOTER_HEIGHT)
end

local shown = false

function PT.hud.show()
  PT.hud.refresh()
  if shown then return end

  shown = true
  Sauce:Stop(frame)
  Sauce:FadeIn(frame, 0.3)
end

local function throw(itemIds, catch)
  for _, itemId in ipairs(itemIds) do arriving[itemId] = (arriving[itemId] or 0) + 1 end
  PT.hud.show()
  for _, itemId in ipairs(itemIds) do flyIn(itemId, catch) end
end

function PT.hud.catch(itemIds, fromPool)
  airborne.catches = airborne.catches + 1
  if fromPool then airborne.poolCatches = airborne.poolCatches + 1 end
  throw(itemIds, { left = table.getn(itemIds), fromPool = fromPool, counted = true })
end

-- Switches to the made-up table, and throws one of its fish to show the catch animation.
function PT.hud.toggleDemo()
  demo = not demo
  PT.hud.show()
  if demo then
    local lootRow = DEMO.loot[math.random(table.getn(DEMO.loot))]
    throw({ lootRow[1] }, { left = 1 })
  end
end

function PT.hud.hide()
  if not shown then return end

  shown = false
  Sauce:Stop(frame)
  Sauce:FadeOut(frame, 0.5)
end

frame:SetScript('OnUpdate', function ()
  if (this.tick or 0) > GetTime() then return end
  this.tick = GetTime() + 1

  if not shown then return end
  -- the demo stays up without a pole or a cast
  if not demo and PT.fishing.idle() > IDLE_HIDE then
    PT.hud.hide()
    return
  end

  -- The rows only change with what they were built for; a catch, a watch or a switch of the own
  -- rates rebuilds them at once.
  local zone, subzone = PT.player.location()
  if zone ~= here.zone or subzone ~= here.subzone or PT.clock.isDay((GetGameTime())) ~= here.day
    or PT.player.skill() ~= here.skill or PT.clock.season() ~= here.season then
    PT.hud.refresh()
  else
    paintTime()
  end
end)

function PT.hud.resetPosition()
  PizzaTonno_character.x, PizzaTonno_character.y = nil, nil
  anchor()
end

PT.hud.restore = anchor
