-- Extend the native extra-bar preference to main/bonus action buttons.
-- Own exactly one grid reference; drag-and-drop owns its separate reference.
local _G = ShaguTweaks.GetGlobalEnv()
local function BonusVisible()
  return _G.BonusActionBarFrame and BonusActionBarFrame:IsVisible()
end
local function HideCoveredButton(button)
  if ShaguTweaks.API.IsSupportedRuntime() and BonusVisible() then button:Hide() end
end
local function RefreshBaseButtons()
  if not ShaguTweaks.API.IsSupportedRuntime() then return end
  local previous = this
  for i = 1, 12 do
    local button = _G["ActionButton" .. i]
    if button then
      if BonusVisible() then button:Hide()
      else
        -- Let the native updater restore filled/empty slot visibility using
        -- the existing grid references. Never change the contents of a slot.
        this = button
        ActionButton_Update()
      end
    end
  end
  this = previous
end
local function UpdateGrid()
  if not ShaguTweaks.API.IsSupportedRuntime() then return end
  local show = _G.ALWAYS_SHOW_MULTIBARS == 1 or _G.ALWAYS_SHOW_MULTIBARS == "1"
  for _, prefix in ipairs({"ActionButton", "BonusActionButton"}) do
    for i = 1, 12 do
      local button = _G[prefix .. i]
      if button then
        if show and not button.stAlwaysShowGrid then
          button.stAlwaysShowGrid = true
          ActionButton_ShowGrid(button)
        elseif not show and button.stAlwaysShowGrid then
          button.stAlwaysShowGrid = nil
          ActionButton_HideGrid(button)
        end
      end
    end
  end
  RefreshBaseButtons()
end
ShaguTweaks.hooksecurefunc("MultiActionBar_UpdateGridVisibility", UpdateGrid)
-- Floating artwork no longer masks the caster bar below the form bar.
-- Native button refreshes and dragging can call Show again: keep covered
-- buttons hidden until the actual bonus frame closes (including animations).
for i = 1, 12 do
  local button = _G["ActionButton" .. i]
  if button then ShaguTweaks.hooksecurefunc(button, "Show", HideCoveredButton) end
end
if _G.BonusActionBarFrame then
  ShaguTweaks.HookScript(BonusActionBarFrame, "OnShow", RefreshBaseButtons)
  ShaguTweaks.HookScript(BonusActionBarFrame, "OnHide", RefreshBaseButtons)
end
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function()
  if ShaguTweaks.API.IsSupportedRuntime() then UpdateGrid() end
end)
