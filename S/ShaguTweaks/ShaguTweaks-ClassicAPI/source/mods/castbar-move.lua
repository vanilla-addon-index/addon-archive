-- Movable Cast Bar
--
-- Hold Ctrl+Shift+Alt to show a marker over the player's cast bar and drag
-- it anywhere; right-click the marker to put it back. The position is saved
-- per character. The Swing Timer, Wand Timer and the Improved Castbar icon
-- are anchored to the cast bar, so they follow it.

local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T

local POSITION_KEY = "CastBarPosition"

-- One table for state: Lua 5.0 allows only 32 upvalues per function.
local S = { preview = false }

local ModifiersDown = ShaguTweaks.API.AreMoveModifiersDown

local function SavedPosition()
  local pos = ShaguTweaks_config and ShaguTweaks_config[POSITION_KEY]
  if pos and pos[1] and pos[2] then return pos end
end

-- Put the bar at the saved spot. Goes through the original SetPoint because
-- the wrapper below ignores everybody else while a saved spot exists.
local function Apply()
  local pos = SavedPosition()
  if not pos then return end
  CastingBarFrame:ClearAllPoints()
  S.orig(CastingBarFrame, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])
end

-- Back to the stock spot; Reduced Actionbar re-anchors it on the next layout pass.
local function Reset()
  if ShaguTweaks_config then ShaguTweaks_config[POSITION_KEY] = nil end
  CastingBarFrame:ClearAllPoints()
  S.orig(CastingBarFrame, "BOTTOM", UIParent, "BOTTOM", 0, 60)
  if _G.UIParent_ManageFramePositions then _G.UIParent_ManageFramePositions() end
end

local function SetPreview(on)
  if S.preview == on then return end
  S.preview = on
  if on then
    local tint = ShaguTweaks.UITint
    S.mover.border:SetVertexColor(tint and tint.r or 1, tint and tint.g or 1,
      tint and tint.b or 1, tint and tint.a or 1)
    S.mover:Show()
  else
    CastingBarFrame:StopMovingOrSizing()
    S.mover:Hide()
  end
end

-- Same look as the Swing Timer preview bars: the classic cast bar with its
-- border and spark, full, in the cast bar's gold.
local function CreateMover()
  local m = CreateFrame("StatusBar", "ShaguTweaksCastBarMover", UIParent)
  m:SetFrameStrata("DIALOG")
  m:SetAllPoints(CastingBarFrame)
  m:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  m:SetStatusBarColor(1, .7, 0)
  m:SetMinMaxValues(0, 1)
  m:SetValue(1)
  m:EnableMouse(true)
  m:Hide()

  m.bg = m:CreateTexture(nil, "BACKGROUND")
  m.bg:SetAllPoints(m)
  m.bg:SetTexture(0, 0, 0, .5)

  -- Keep the rim above the StatusBar's ARTWORK fill during preview/dragging.
  m.border = m:CreateTexture(nil, "OVERLAY")
  m.border:SetTexture("Interface\\CastingBar\\UI-CastingBar-Border")
  m.border:SetWidth(256)
  m.border:SetHeight(64)
  m.border:SetPoint("TOP", m, "TOP", 0, 28)

  m.spark = m:CreateTexture(nil, "OVERLAY")
  m.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
  m.spark:SetBlendMode("ADD")
  m.spark:SetWidth(32)
  m.spark:SetHeight(32)
  m.spark:SetPoint("CENTER", m, "RIGHT", 0, 2)

  m.text = m:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  m.text:SetPoint("CENTER", m, "CENTER", 0, 3)
  m.text:SetText(T["Cast Bar"])

  m:SetScript("OnMouseDown", function()
    if arg1 == "LeftButton" then
      -- the swing bars default to sitting on top of the cast bar: pin them
      -- first so only the cast bar moves
      if ShaguTweaks.FreezeSwingBars then ShaguTweaks.FreezeSwingBars() end
      CastingBarFrame:StartMoving()
    end
  end)
  m:SetScript("OnMouseUp", function()
    CastingBarFrame:StopMovingOrSizing()
    ShaguTweaks_config = ShaguTweaks_config or {}
    if arg1 == "RightButton" then
      Reset()
    else
      ShaguTweaks_config[POSITION_KEY] = { CastingBarFrame:GetLeft(), CastingBarFrame:GetBottom() }
      Apply()
    end
  end)

  S.mover = m
end

ShaguTweaks.EnableCastBarMover = function()
  if not CastingBarFrame then return end

  if not S.mover then
    S.orig = CastingBarFrame.SetPoint
    CreateMover()

    CastingBarFrame:SetMovable(true)
    CastingBarFrame:SetClampedToScreen(true)

    S.events = CreateFrame("Frame")
    S.events:SetScript("OnEvent", function()
      if event == "MODIFIER_STATE_CHANGED" then
        SetPreview(ModifiersDown())
      else
        Apply()
      end
    end)
  end

  -- Reduced Actionbar and others re-anchor the bar on every layout pass.
  -- While a saved spot exists their SetPoint calls are ignored.
  CastingBarFrame.SetPoint = function(frame, a, b, c, d, e)
    if SavedPosition() then return end
    return S.orig(frame, a, b, c, d, e)
  end

  S.events:RegisterEvent("PLAYER_ENTERING_WORLD")
  S.events:RegisterEvent("MODIFIER_STATE_CHANGED")
  Apply()
end
