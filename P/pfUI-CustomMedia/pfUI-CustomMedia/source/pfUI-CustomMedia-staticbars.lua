-- Keep unit-frame bar textures at their full-size scale while values change.
-- pfUI draws its health/power bars with textures whose geometry shrinks to
-- the current value. Cropping the texture UVs by that same fraction prevents
-- the image from being rescaled into the smaller region.

if not pfUI or not pfUI.uf then return end

local function UpdateTexture(bar, texture, vertical)
  if not texture then return end

  -- Skip redundant UV updates when the fill fraction hasn't actually changed.
  -- This avoids re-issuing SetTexCoord on every DisplayValue/SetValue call
  -- when the bar value is static.
  local lastFrac = bar._pfUICustomMediaLastFrac
  local minimum, maximum
  if bar.GetMinMaxValues then
    minimum, maximum = bar:GetMinMaxValues()
  else
    minimum, maximum = bar.min, bar.max
  end
  local range = maximum and minimum and maximum - minimum
  local fraction = 0

  if range and range > 0 then
    local value
    if bar.min ~= nil then
      value = bar.val_ or bar.val
    elseif bar.GetValue then
      value = bar:GetValue()
    end
    if value then
      fraction = (value - minimum) / range
      if fraction < 0 then fraction = 0 elseif fraction > 1 then fraction = 1 end
    end
  end

  if lastFrac == fraction then return end
  bar._pfUICustomMediaLastFrac = fraction

  if vertical then
    -- A vertical fill grows upward from the bottom edge.
    texture:SetTexCoord(0, 1, 1 - fraction, 1)
  else
    texture:SetTexCoord(0, fraction, 0, 1)
  end
end

local function DecoratePfUIBar(bar)
  if not bar or bar._pfUICustomMediaStatic then return end
  local texture = bar.bar
  if not texture or not bar.DisplayValue then return end

  bar._pfUICustomMediaStatic = true
  local displayValue = bar.DisplayValue
  bar.DisplayValue = function(self, value)
    displayValue(self, value)
    UpdateTexture(self, texture, self.mode == "vertical")
  end

  -- Reapply after pfUI changes the selected media texture or the bar layout.
  local setTexture = bar.SetStatusBarTexture
  if setTexture then
    bar.SetStatusBarTexture = function(self, ...)
      setTexture(self, ...)
      UpdateTexture(self, texture, self.mode == "vertical")
    end
  end

  bar:DisplayValue(bar.val_ or bar.val or 0)
end

local function DecorateDruidMana(bar)
  if not bar or bar._pfUICustomMediaStatic then return end
  if not bar.GetStatusBarTexture or not bar.SetValue then return end

  bar._pfUICustomMediaStatic = true

  local setValue = bar.SetValue
  bar.SetValue = function(self, value)
    setValue(self, value)
    UpdateTexture(self, self:GetStatusBarTexture(), false)
  end

  local setMinMaxValues = bar.SetMinMaxValues
  if setMinMaxValues then
    bar.SetMinMaxValues = function(self, minimum, maximum, ...)
      setMinMaxValues(self, minimum, maximum, ...)
      UpdateTexture(self, self:GetStatusBarTexture(), false)
    end
  end

  UpdateTexture(bar, bar:GetStatusBarTexture(), false)
end

local function DecorateUnitFrame(frame)
  if not frame then return end
  if frame.hp then DecoratePfUIBar(frame.hp.bar) end
  if frame.power then DecoratePfUIBar(frame.power.bar) end
  DecorateDruidMana(frame.druidmana)
end

-- Existing frames are created while pfUI loads, before this dependent addon.
for _, frame in ipairs(pfUI.uf.frames or {}) do
  DecorateUnitFrame(frame)
end

-- Some frames (for example raid frames) are created later as needed.
local createUnitFrame = pfUI.uf.CreateUnitFrame
if type(createUnitFrame) == "function" then
  pfUI.uf.CreateUnitFrame = function(self, ...)
    local frame = createUnitFrame(self, ...)
    DecorateUnitFrame(frame)
    return frame
  end
end
