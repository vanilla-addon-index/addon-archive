local PL = PizzaLoot
PL.anchor = {}

local DEFAULT_Y = 140

local frame = CreateFrame('Frame', 'PizzaLootAnchor', UIParent)
frame:SetWidth(PL.utils.snap(PL.layout.width))
frame:SetHeight(PL.utils.snap(PL.layout.rows * PL.layout.height + (PL.layout.rows - 1) * PL.layout.spacing))
frame:SetFrameStrata('HIGH')
frame:SetMovable(true)
frame:EnableMouse(false)
PL.anchor.frame = frame

local backdrop = frame:CreateTexture(nil, 'BACKGROUND')
backdrop:SetAllPoints()
backdrop:SetTexture(0.3, 0.1, 0.5, 0.4)
backdrop:Hide()

local label = frame:CreateFontString(nil, 'OVERLAY')
label:SetFont(STANDARD_TEXT_FONT, 10, 'OUTLINE')
label:SetPoint('CENTER', frame, 'CENTER', 0, 0)
label:SetText('PizzaLoot (drag to move)')
label:SetTextColor(1, 1, 1, 0.8)
label:Hide()

local function place(x, y)
  frame:ClearAllPoints()
  if x and y then
    frame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', x, y)
  else
    frame:SetPoint('CENTER', UIParent, 'CENTER', 0, DEFAULT_Y)
  end
end

place()

function PL.anchor.setLocked(locked)
  PizzaLoot_config.locked = locked
  frame:EnableMouse(not locked)
  if locked then
    backdrop:Hide()
    label:Hide()
  else
    backdrop:Show()
    label:Show()
  end
end

function PL.anchor.resetPosition()
  PizzaLoot_config.x, PizzaLoot_config.y = nil, nil
  place()
end

function PL.anchor.restore()
  place(PizzaLoot_config.x, PizzaLoot_config.y)
  PL.anchor.setLocked(PizzaLoot_config.locked)
end

frame:SetScript('OnMouseDown', function ()
  if not PizzaLoot_config.locked then frame:StartMoving() end
end)

frame:SetScript('OnMouseUp', function ()
  frame:StopMovingOrSizing()
  PizzaLoot_config.x, PizzaLoot_config.y = frame:GetLeft(), frame:GetTop()
end)
