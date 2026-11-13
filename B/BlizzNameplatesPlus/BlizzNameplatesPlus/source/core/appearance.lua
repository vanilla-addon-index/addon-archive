BNP = BNP or {}

function BNP:GetLevelNumberScale()
  local scale = tonumber(BNP_DB and BNP_DB.levelNumberScale) or 1
  return math.max(0.5, math.min(1.5, scale))
end

function BNP:ApplyLevelNumberScale(plate)
  local level = plate and plate.level
  if not level or not level.GetFont or not level.SetFont then return end
  local font, size, flags = level:GetFont()
  if not font or not size then return end
  if not plate.BNPLevelBaseSize then plate.BNPLevelBaseSize = size end
  local wanted = plate.BNPLevelBaseSize * self:GetLevelNumberScale()
  if math.abs(size - wanted) > 0.01 then level:SetFont(font, wanted, flags) end
end

function BNP:RefreshLevelNumberScale()
  local plate
  for plate in pairs(self.plates or {}) do self:ApplyLevelNumberScale(plate) end
end

local modernColors = {
  DRUID = {r=1, g=0.49, b=0.04}, HUNTER = {r=0.67, g=0.83, b=0.45},
  MAGE = {r=0.25, g=0.78, b=0.92}, PALADIN = {r=0.96, g=0.55, b=0.73},
  PRIEST = {r=1, g=1, b=1}, ROGUE = {r=1, g=0.96, b=0.41},
  SHAMAN = {r=0, g=0.44, b=0.87}, WARLOCK = {r=0.53, g=0.53, b=0.93},
  WARRIOR = {r=0.78, g=0.61, b=0.43},
}

function BNP:GetModernClassColor(class)
  local palette = ShaguTweaks and ShaguTweaks.ModernClassColors or modernColors
  return class and palette[class]
end

function BNP:GetRecoloredBorderColor()
  local shagu = ShaguTweaks
  local key
  if shagu and shagu.DarkMode then key = "darkmode.color"
  elseif shagu and shagu.GoldMode then key = "goldmode.color" end
  local color = key and shagu.overwrites and shagu.overwrites[key]
  if type(color) == "table" then return color.r, color.g, color.b, color.a or 1 end
  if key == "goldmode.color" then return 1, 0.78, 0.4, 1 end
  return 0.3, 0.3, 0.3, 0.9
end

-- Spell icons include their silver rim in the artwork. Copy only the outer
-- four pixels of a 64px icon, preserving the untinted spell image underneath.
function BNP:ApplyAuraBorderColor(icon)
  local strips = icon.BNPRecoloredEdges
  if not (self.IsDarkNameplateBorderEnabled and self:IsDarkNameplateBorderEnabled()) then
    if strips then
      local i
      for i = 1, 4 do strips[i]:Hide() end
    end
    return
  end
  local path = icon.texture and icon.texture:GetTexture()
  if not path then return end
  if not strips then
    strips = {}
    icon.BNPRecoloredEdges = strips
    local parent = icon.BNPTextOverlay or icon
    local i
    for i = 1, 4 do strips[i] = parent:CreateTexture(nil, "BORDER") end
    strips[1]:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
    strips[1]:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, 0)
    strips[2]:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
    strips[2]:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    strips[3]:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
    strips[3]:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
    strips[4]:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, 0)
    strips[4]:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    strips[1]:SetTexCoord(0, 1, 0, 0.0625)
    strips[2]:SetTexCoord(0, 1, 0.9375, 1)
    strips[3]:SetTexCoord(0, 0.0625, 0, 1)
    strips[4]:SetTexCoord(0.9375, 1, 0, 1)
  end
  local r, g, b, a = self:GetRecoloredBorderColor()
  local shagu = ShaguTweaks
  if shagu and shagu.GoldMode and not shagu.DarkMode then
    local edge = shagu.overwrites and shagu.overwrites["goldmode.border"]
    r, g, b, a = 0.8, 0.62, 0.32, 1
    if type(edge) == "table" then r, g, b, a = edge.r, edge.g, edge.b, edge.a or 1 end
  end
  local width, height = icon:GetWidth(), icon:GetHeight()
  local i
  for i = 1, 4 do
    local strip = strips[i]
    if i <= 2 then strip:SetHeight(height * 0.0625)
    else strip:SetWidth(width * 0.0625) end
    strip:SetTexture(path)
    strip:SetVertexColor(r, g, b, a)
    strip:Show()
  end
end

function BNP:RefreshAuraBorderColors()
  local plate, i
  for plate in pairs(self.plates or {}) do
    local container = plate.BNPAuraContainer
    if container then
      for i = 1, table.getn(container.icons or {}) do self:ApplyAuraBorderColor(container.icons[i]) end
    end
    container = plate.BNPCCContainer
    if container then
      for i = 1, table.getn(container.icons or {}) do self:ApplyAuraBorderColor(container.icons[i]) end
    end
  end
end

local modernTexture = "Interface\\AddOns\\BlizzNameplatesPlus\\media\\BlizzardRetailBar"

function BNP:GetCastbarFillTexture()
  if BNP_DB and BNP_DB.modernClassColors then return modernTexture end
  return "Interface\\TargetingFrame\\UI-StatusBar"
end

function BNP:ApplyModernHealthTexture(plate)
  local bar = plate and plate.healthbar
  if not bar or not bar.SetStatusBarTexture then return end
  if BNP_DB and BNP_DB.modernClassColors then
    if not plate.BNPModernHealthActive then
      local original = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
      if type(original) == "string" then plate.BNPOldHealthTexture = original
      elseif original and original.GetTexture then plate.BNPOldHealthTexture = original:GetTexture() end
      plate.BNPModernHealthActive = true
    end
    bar:SetStatusBarTexture(modernTexture)
  elseif plate.BNPModernHealthActive then
    bar:SetStatusBarTexture(plate.BNPOldHealthTexture or "Interface\\TargetingFrame\\UI-StatusBar")
    plate.BNPModernHealthActive = nil
    plate.BNPOldHealthTexture = nil
  end
end

function BNP:RefreshModernNameplates()
  local plate
  for plate in pairs(self.plates or {}) do self:ApplyModernHealthTexture(plate) end
  if self.RefreshClassColors then self:RefreshClassColors() end
  if self.UpdateTankMode then self:UpdateTankMode() end
  if self.RefreshPersonalNameplateStyle then self:RefreshPersonalNameplateStyle() end
  if self.RefreshCastbarStyle then self:RefreshCastbarStyle() end
end

-- The level well is a small health-texture fill underneath the native rim.
-- Cache values so the existing visual guard performs no unchanged writes.
function BNP:UpdateLevelBackground(plate)
  local border, bar = plate.border, plate.healthbar
  if not border or not bar then return end
  local background = plate.BNPNeutralLevelBackground
  local hidden = self.IsNameplateBorderHidden and self:IsNameplateBorderHidden()
  if hidden or plate.BNPTotemLastKey then
    if background then background:Hide() end
    return
  end
  if not background then
    background = border:GetParent():CreateTexture(nil, "BACKGROUND")
    plate.BNPNeutralLevelBackground = background
  end
  if background:GetParent() ~= border:GetParent() then
    background:SetParent(border:GetParent())
  end
  -- Match the entire border region. The alpha-masked fill uses the same
  -- 128x32 atlas, eliminating separate inset position/size calculations.
  if not background.BNPAnchored then
    background:ClearAllPoints()
    background:SetAllPoints(border)
    background.BNPAnchored = true
  end
  local ulx, uly, llx, lly, urx, ury, lrx, lry = border:GetTexCoord()
  if background.BNPULX ~= ulx or background.BNPULY ~= uly
    or background.BNPLLX ~= llx or background.BNPLLY ~= lly
    or background.BNPURX ~= urx or background.BNPURY ~= ury
    or background.BNPLRX ~= lrx or background.BNPLRY ~= lry then
    background:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
    background.BNPULX, background.BNPULY = ulx, uly
    background.BNPLLX, background.BNPLLY = llx, lly
    background.BNPURX, background.BNPURY = urx, ury
    background.BNPLRX, background.BNPLRY = lrx, lry
  end
  local style = "dark"
  if background.BNPStyle ~= style then
    background:SetTexture("Interface\\AddOns\\BlizzNameplatesPlus\\media\\level_fill_" .. style .. ".tga")
    background.BNPStyle = style
  end
  -- WoW Forever-style dark olive well, independent of health and border tint.
  local r, g, b, a = 0.055, 0.065, 0.025, 1
  if background.BNPR ~= r or background.BNPG ~= g or background.BNPB ~= b or background.BNPA ~= a then
    background:SetVertexColor(r, g, b, a)
    background.BNPR, background.BNPG, background.BNPB, background.BNPA = r, g, b, a
  end
  if not background:IsShown() then background:Show() end
end
