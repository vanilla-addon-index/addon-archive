-- Test panel for steps 1 and 2: shows what AdeGear understood about the item under the
-- mouse. It sits next to the game tooltip. In step 5 this becomes the real comparison.

local AG = AdeGear
local Inspect = {}
AG.Inspect = Inspect

local WIDTH = 250

local STATE_TEXT = {
  ok = { "USABLE", { 0.35, 0.95, 0.35 } },
  itemlevel = { "USABLE LATER", { 1, 0.82, 0 } },
  train = { "NEEDS TRAINING", { 1, 0.6, 0.2 } },
  level = { "LOCKED BY LEVEL", { 1, 0.6, 0.2 } },
  never = { "CAN'T USE", { 1, 0.3, 0.3 } },
  classlock = { "CAN'T USE", { 1, 0.3, 0.3 } },
  notgear = { "NOT GEAR", { 0.62, 0.62, 0.62 } },
  prof = { "NEEDS A PROFESSION", { 1, 0.6, 0.2 } },
  need = { "NEEDS A MATCHING WEAPON", { 1, 0.6, 0.2 } },
}

local Anchor

local function Tip()
  if not Inspect.tip then
    Inspect.tip = AG.Tip.New("AdeGearInspectPanel", WIDTH)
    -- the game (or pfUI) opens its "currently equipped" tooltips a moment after the item tooltip,
    -- so the position is checked again a few times per second
    Inspect.tip.frame:SetScript("OnUpdate", function()
      Inspect.elapsed = (Inspect.elapsed or 0) + arg1
      if Inspect.elapsed < 0.1 then return end
      Inspect.elapsed = 0
      if Inspect.owner and Inspect.owner:IsShown() then Anchor(Inspect.tip, Inspect.owner) end
    end)
  end
  return Inspect.tip
end

function Inspect.Hide()
  Inspect.owner = nil
  if Inspect.tip then Inspect.tip:Hide() end
  if AG.Compare then AG.Compare.Hide() end
end

-- the comparison tooltips that belong to a tooltip (Anchor is shared with the real comparison)
local EXTRA = {
  GameTooltip = { "ShoppingTooltip1", "ShoppingTooltip2" },
  ItemRefTooltip = { "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2" },
}

-- puts the panel beside the outermost visible tooltip, on the side that has room
Anchor = function(tip, owner)
  local f = tip.frame
  local leftFrame, rightFrame = owner, owner
  local leftX = owner:GetLeft()
  local rightX = owner:GetRight()
  if not leftX or not rightX then return end
  local os = owner:GetEffectiveScale()
  leftX, rightX = leftX * os, rightX * os

  local names = EXTRA[owner:GetName() or ""] or {}
  for i = 1, table.getn(names) do
    local t = getglobal(names[i])
    if t and t:IsShown() and t:GetLeft() and t:GetRight() then
      local s = t:GetEffectiveScale()
      local l, r = t:GetLeft() * s, t:GetRight() * s
      if l < leftX then leftX = l; leftFrame = t end
      if r > rightX then rightX = r; rightFrame = t end
    end
  end

  local ps = UIParent:GetEffectiveScale()
  local room = UIParent:GetRight() * ps - rightX
  local onRight = room >= (WIDTH + 10) * ps
  local side = onRight and rightFrame or leftFrame
  -- one anchor per hover: the position is worked out when the set of visible tooltips changes (or a new
  -- item is hovered) and then left alone, so the panel stays still while it is read
  local key = (onRight and "R" or "L") .. (side:GetName() or "?")
  if Inspect.anchorKey == key then return end
  Inspect.anchorKey = key

  -- the panel hangs from the top of the tooltip it sits beside. When it is taller than the room below that top,
  -- it is moved up by just the missing amount, never above the top of the screen.
  local fs = f:GetEffectiveScale()
  local h = (f:GetHeight() or 0) * fs
  local up = 0
  local top = side:GetTop()
  if top and h > 0 then
    local t = top * side:GetEffectiveScale()
    up = h - t + 4
    local maxUp = UIParent:GetTop() * ps - t
    if up > maxUp then up = maxUp end
    if up < 0 then up = 0 end
    up = math.floor(up / fs + 0.5)
  end
  f:ClearAllPoints()
  if onRight then
    f:SetPoint("TOPLEFT", side, "TOPRIGHT", 4, up)
  else
    f:SetPoint("TOPRIGHT", side, "TOPLEFT", -4, up)
  end
end

Inspect.Anchor = Anchor

local function WeaponLine(it)
  local w = it.weapon
  if not w or not w.min then return nil end
  return string.format("%d-%d, speed %.2f, %.1f dps", w.min, w.max, w.speed, w.dps)
end

-- builds the panel content for an item
function Inspect.Fill(it)
  -- only gear: nothing for consumables, bags, quest items, shirts and tabards
  if not it.slot or it.bag or it.slot == "SHIRT" or it.slot == "TABARD" then return nil end
  local ctx = AG.Rules.Context()
  local check = AG.Rules.Check(it, ctx)
  local targets = AG.Rules.Targets(it, ctx)
  local tip = Tip()
  tip:Reset()

  tip:Line("AdeGear scan", "test build", AG.C.accent, AG.C.dim, 11)
  tip:Rule()

  tip:Line(it.name, nil, AG.Q[it.quality or 1], nil, 13)
  if it.recipe then tip:Line("item this recipe makes", nil, AG.C.dim) end
  local kind = it.slotText or "no slot found"
  if it.weaponKind then kind = kind .. ", " .. it.weaponKind
  elseif it.armorKind then kind = kind .. ", " .. it.armorKind end
  tip:Line(kind, nil, AG.C.dim, nil, 11)
  local wl = WeaponLine(it)
  if wl then tip:Line(wl, nil, AG.C.dim, nil, 11) end

  local st = STATE_TEXT[check.state] or STATE_TEXT.ok
  tip:Space(2)
  tip:Line(st[1], nil, st[2], nil, 13)
  for i = 1, table.getn(check.lines) do
    tip:Line(check.lines[i], nil, AG.C.text, nil, 11)
  end

  if table.getn(targets) > 0 then
    tip:Rule()
    tip:Line("GOES IN", nil, AG.C.dim, nil, 10)
    for i = 1, table.getn(targets) do
      local t = targets[i]
      local now = "empty"
      local c = AG.C.dim
      if t.equipped then now = t.equipped.name; c = AG.Q[t.equipped.quality or 1] end
      tip:Line(t.label, now, AG.C.text, c, 11)
      for j = 1, table.getn(t.notes) do
        tip:Line("  > " .. t.notes[j], nil, AG.C.gold, nil, 10)
      end
    end
  end

  local w = AG.Weights.ForPlayer()
  local total, rows = 0, {}
  local stats = it.stats
  if w then total, rows, stats = AG.Weights.ItemValue(it, w) end
  local keys = AG.Items.SortedKeys(stats)
  if table.getn(keys) > 0 then
    tip:Rule()
    if w then
      tip:Row("UNDERSTOOD", "amount", "points", AG.C.dim, AG.C.dim, AG.C.dim)
    else
      tip:Line("UNDERSTOOD", nil, AG.C.dim)
    end
    for i = 1, table.getn(keys) do
      local k = keys[i]
      local amount = AG.Items.NumText(stats[k])
      if w then
        local pts, pc = "", AG.C.dim
        if rows[k] then
          pts = string.format("%.1f", rows[k])
          if rows[k] > 0 then pc = AG.C.good elseif rows[k] < 0 then pc = AG.C.bad end
        end
        tip:Row(AG.Items.Label(k), amount, pts, AG.C.text, AG.C.text, pc)
      else
        tip:Line(AG.Items.Label(k), amount, AG.C.text, AG.C.good)
      end
    end
    if w then
      tip:Row("WORTH TO YOU", "", string.format("%.1f", total), AG.C.gold, AG.C.gold, AG.C.gold)
      tip:Line("valued as " .. AG.Weights.MixText(w) .. ". Set bonuses and effects are not counted yet.", nil, AG.C.dim)
    end
  end

  local set = it.set
  if set and set.name then
    tip:Rule()
    local count = nil
    if set.have then count = set.have .. "/" .. set.total end
    tip:Line("SET", count, AG.C.dim, AG.C.text)
    tip:Line(set.name, nil, AG.C.gold)
    for i = 1, table.getn(set.bonuses) do
      local b = set.bonuses[i]
      local text = b.text
      if b.n then text = "(" .. b.n .. ") " .. text end
      local c = AG.C.dim
      if b.active then c = AG.C.good end
      tip:Line(text, nil, c)
    end
  end

  if table.getn(it.special) > 0 then
    tip:Rule()
    tip:Line("SPECIAL, NOT COUNTED YET", nil, AG.C.dim, nil, 10)
    for i = 1, table.getn(it.special) do
      tip:Line(it.special[i], nil, AG.C.warn, nil, 10)
    end
  end

  if table.getn(it.unparsed) > 0 then
    tip:Rule()
    tip:Line("NOT UNDERSTOOD", nil, AG.C.dim, nil, 10)
    for i = 1, table.getn(it.unparsed) do
      tip:Line(it.unparsed[i], nil, AG.C.bad, nil, 10)
    end
  end

  tip:Done()
  return tip, check, targets
end

-- called by the tooltip hooks with the tooltip and an item link
function Inspect.Show(owner, link, own)
  local it = AG.Items.FromLink(link)
  if it then
    Inspect.last = it
    if it.slot and not it.bag then AG.Items.LogUnparsed(it) end   -- only gear is collected
  end
  if not AG.Get("testPanel") then
    -- the real comparison; the test panel below is for /adeg scan
    if Inspect.tip then Inspect.tip:Hide() end
    if AG.Compare then AG.Compare.Show(owner, link, own) end
    return
  end
  if AG.Compare then AG.Compare.Hide() end
  if not it then Inspect.Hide() return end
  local tip = Inspect.Fill(it)
  if not tip then Inspect.Hide() return end
  Inspect.owner = owner
  Inspect.anchorKey = nil
  Anchor(tip, owner)
  tip:Show()
end

----------------------------------------------------------------------
-- Chat output (for /adeg item and /adeg equipped)
----------------------------------------------------------------------

local function Say(text)
  DEFAULT_CHAT_FRAME:AddMessage(text)
end

function Inspect.Dump(it)
  if not it then
    AG.Msg("no item yet: hover an item first")
    return
  end
  local ctx = AG.Rules.Context()
  local check = AG.Rules.Check(it, ctx)
  AG.Msg(it.name .. " (quality " .. tostring(it.quality) .. ")")
  Say("  slot: " .. tostring(it.slotText) .. " (" .. tostring(it.slot) .. "), weapon: " .. tostring(it.weaponKind) ..
    ", armor: " .. tostring(it.armorKind) .. ", requires level " .. tostring(it.reqLevel))
  local wl = WeaponLine(it)
  if wl then Say("  weapon: " .. wl) end
  local keys = AG.Items.SortedKeys(it.stats)
  for i = 1, table.getn(keys) do
    Say("  " .. AG.Items.Label(keys[i]) .. ": " .. AG.Items.NumText(it.stats[keys[i]]))
  end
  for i = 1, table.getn(it.special) do Say("  special: " .. it.special[i]) end
  for i = 1, table.getn(it.unparsed) do Say("  |cffff5555not understood:|r " .. it.unparsed[i]) end
  Say("  can use: " .. check.state .. " - " .. table.concat(check.lines, " "))
  Say("  you are " .. tostring(ctx.class) .. " level " .. tostring(ctx.level) .. ", skill list " ..
    (ctx.skills and "read" or "NOT read") .. ", dual wield " .. tostring(ctx.dual))
end

function Inspect.Unparsed()
  local list = AdeGearDB and AdeGearDB.unparsed
  local count = 0
  if list then
    for line, name in pairs(list) do
      count = count + 1
      if count <= 15 then Say("  " .. line .. "   (" .. tostring(name) .. ")") end
    end
  end
  AG.Msg(count .. " unknown tooltip lines saved. /reload writes them to the AdeGear.lua saved variables file.")
end
