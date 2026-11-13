local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["Hide Player Name"],
  description = T["Hides your player name and raid group number. Requires Hide Player Frame Resources."],
  requires = { T["Hide Player Frame Resources"] },
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = nil,
})

module.enable = function(self)
  if ShaguTweaks_config[T["Hide Player Frame Resources"]] ~= 1 then return end
  local layout = ShaguTweaks.PlayerFrameResourcesLayout
  if layout and layout.name then layout.name:Hide() end
  local group = PlayerFrameGroupIndicator
  if group and not self.groupHidden then
    self.groupHidden = true
    local setAlpha = group.SetAlpha
    setAlpha(group, 0)
    ShaguTweaks.hooksecurefunc(group, "SetAlpha", function(frame) setAlpha(frame, 0) end)
  end
  -- Resource-hiding setup also reads the saved setting after all modules load,
  -- so this works regardless of their initialization order.
end
