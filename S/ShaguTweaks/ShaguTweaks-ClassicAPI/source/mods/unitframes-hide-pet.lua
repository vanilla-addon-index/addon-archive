local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["Hide Pet Unit Frame"],
  description = T["Hides the Pet unitframe below the player in pet classes."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = false,
})

module.enable = function(self)
  if not PetFrame then return end

  -- PetFrame_Update shows the frame again whenever the pet changes, so a
  -- plain Hide() does not last. Parent it to a frame that is never shown:
  -- the stock pet code keeps running unchanged, and the frame, its bars and
  -- its child overlays (such as Real Health Numbers' text) never draw.
  if not self.hidden then
    self.hidden = CreateFrame("Frame")
    self.hidden:Hide()
  end

  PetFrame:SetParent(self.hidden)
end
