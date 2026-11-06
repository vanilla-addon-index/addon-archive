-- pandaUI :: modules/castbarclassic.lua
--
-- Classic-only castbar skin, used for both the player and the target bar. Candidate A was confirmed visible in game
-- on 2026-09-05: Interface\CastingBar\UI-CastingBar-Border. The measured
-- CastingBarFrame geometry is reproduced with addon-owned regions only. This
-- file deliberately never resolves, walks, retains, anchors to, or mutates the
-- client's CastingBarFrame or any of its regions; see knowledge.json /
-- castbar.native_frame_hierarchy and frames.native_widget_reference_crash_risk.

local U = PandaUI
local M = U.media
local classicCastbar = {
  WIDTH = 195,
  HEIGHT = 13,
  BORDER_WIDTH = 256,
  BORDER_HEIGHT = 64,
  SPARK_WIDTH = 32,
  SPARK_HEIGHT = 32,
  FILL_COLOR = { 1.00, 0.70, 0.00, 1.00 },
  BACKGROUND_COLOR = { 0.12, 0.12, 0.12, 1.00 },
}

function classicCastbar.UpdateSpark(widget)
  if not widget or not widget.puiSpark then return end

  local size = tonumber(widget:GetWidth()) or 0
  local minimum = tonumber(widget.puiMin) or 0
  local range = (tonumber(widget.puiMax) or 0) - minimum
  local extent = 0
  if range > 0 and size > 0 then
    extent = size / range * ((tonumber(widget.puiValue) or 0) - minimum)
  end
  if extent < 0 then extent = 0 end
  if extent > size then extent = size end

  if extent <= 0 then
    if widget.puiSpark:IsShown() then widget.puiSpark:Hide() end
    return
  end

  widget.puiSpark:ClearAllPoints()
  widget.puiSpark:SetPoint("CENTER", widget, "LEFT", extent, 0)
  if not widget.puiSpark:IsShown() then widget.puiSpark:Show() end
end

function classicCastbar.SetDynamicShown(widget, shown)
  if not widget or not widget.puiSpark then return end
  if not shown then
    if widget.puiSpark:IsShown() then widget.puiSpark:Hide() end
    return
  end
  classicCastbar.UpdateSpark(widget)
end

-- Installed as widget.puiResize: modules/castbar.lua's edit-mode size sliders
-- (player bar). The stock border and spark carry transparent padding around
-- the bar they were drawn for, so they are scaled by the same factor as the
-- bar rather than stretched to it; the fill and bed follow the bar's own size.
function classicCastbar.Resize(widget, width, height)
  if not widget or not width or not height then return end
  widget:SetWidth(width)
  widget:SetHeight(height)
  local scaleX = width / classicCastbar.WIDTH
  local scaleY = height / classicCastbar.HEIGHT
  if widget.puiBorder then
    widget.puiBorder:SetWidth(classicCastbar.BORDER_WIDTH * scaleX)
    widget.puiBorder:SetHeight(classicCastbar.BORDER_HEIGHT * scaleY)
  end
  if widget.puiSpark then
    widget.puiSpark:SetHeight(classicCastbar.SPARK_HEIGHT * scaleY)
  end
  if widget.name then pcall(widget.name.SetWidth, widget.name, width - 10) end
end

function U.CreateClassicCastbar(frameName)
  -- Exact-theme gate: no other native-chrome or Modern theme inherits this
  -- ornamental stock art merely because it shares module infrastructure.
  if type(U.GetActiveThemeStyle) ~= "function" or
     U.GetActiveThemeStyle() ~= "classic-wow" then return nil end

  local widget = U.CreateStatusBar(UIParent, {
    name = frameName,
    width = classicCastbar.WIDTH,
    height = classicCastbar.HEIGHT,
    texture = M.texture.classicStatusBar,
    color = classicCastbar.FILL_COLOR,
    background = classicCastbar.BACKGROUND_COLOR,
  })
  if not widget then return nil end

  -- Match the safe visual probe exactly: the depleted bed uses the same stock
  -- status texture at a dark tint, with the verified normal border over it.
  widget.puiBackground:SetTexture(M.texture.classicStatusBar)

  local border = widget:CreateTexture(nil, "OVERLAY")
  border:SetTexture(M.texture.classicCastbarBorder)
  border:SetWidth(classicCastbar.BORDER_WIDTH)
  border:SetHeight(classicCastbar.BORDER_HEIGHT)
  border:SetPoint("CENTER", widget, "CENTER", 0, 0)

  local spark = widget:CreateTexture(nil, "OVERLAY")
  spark:SetTexture(M.texture.classicCastbarSpark)
  spark:SetWidth(classicCastbar.SPARK_WIDTH)
  spark:SetHeight(classicCastbar.SPARK_HEIGHT)
  -- This stock texture carries a black field intended for additive
  -- composition. With the default BLEND mode that field becomes the moving
  -- black square confirmed in game on 2026-09-05. Updated-client docs support
  -- ADD; if the method is absent or errors, omit the optional spark instead of
  -- leaving the artifact visible.
  if not spark.SetBlendMode or
     not pcall(spark.SetBlendMode, spark, "ADD") then
    spark:Hide()
    spark = nil
  end
  if spark then
    spark:SetPoint("CENTER", widget, "LEFT", 0, 0)
    spark:Hide()
  end

  local name = U.CreateLabel(widget, {
    inherits = "GameFontHighlightSmall",
    color = M.color.text,
    width = 185,
    height = 16,
    justify = "CENTER",
  })
  if name then name:SetPoint("CENTER", widget, "CENTER", 0, 0) end

  -- Both the player and the target tracker consume the same compact widget
  -- contract as Modern. This Classic version intentionally has no icon or
  -- countdown: the measured native bar has one centered text region and no
  -- separate icon/time cell.
  widget.bar = widget
  widget.name = name
  widget.time = nil
  widget.icon = nil
  widget.showIcon = false
  widget.puiKeepNativeTint = true
  widget.puiSpark = spark
  widget.puiBorder = border
  widget.puiResize = classicCastbar.Resize
  if spark then
    widget.puiUpdateSpark = classicCastbar.UpdateSpark
    widget.puiSetDynamicShown = classicCastbar.SetDynamicShown
  end
  widget.puiCells = { widget.puiBackground, widget.puiFillTexture, border }
  if name then table.insert(widget.puiCells, name) end

  widget:SetMinMaxValues(0, 1)
  widget:SetValue(0)
  return widget
end

-- The builder was target-only when it was written; the player bar now uses the
-- same skin. Kept so an older call site is not a nil call.
U.CreateClassicTargetCastbar = U.CreateClassicCastbar
