-- Adapted from TokensWorth/ShaguTweaks-mods (MIT, original copyright GryllsAddons).

local T = ShaguTweaks.T

local module = ShaguTweaks:register({
  title = T["Loot Quality"],
  description = T["Colors the loot frame using the highest item quality in the current loot window."],
  expansions = { ["vanilla"] = true, ["tbc"] = nil },
  category = T["Loot"],
  enabled = nil,
})

local MIN_QUALITY = 2 -- uncommon / green

local function FindLootTitle()
  local regions = { LootFrame:GetRegions() }

  for i = 1, table.getn(regions) do
    local region = regions[i]
    -- Some Vanilla/Turtle regions expose GetText without being FontStrings.
    -- Only keep a region that can actually be recolored.
    if region
      and type(region.GetText) == "function"
      and type(region.SetTextColor) == "function"
      and region:GetText() == ITEMS then
      return region
    end
  end
end

module.enable = function(self)
  if not self.border then
    self.border = LootFrame:CreateTexture(nil, "OVERLAY")
    self.border:SetTexture("Interface\\LootFrame\\UI-LootPanel")
    self.border:SetPoint("TOPLEFT", LootFrame, "TOPLEFT", -4, 3)
    self.border:SetPoint("BOTTOMRIGHT", LootFrame, "BOTTOMRIGHT", 5, -3)
    self.border:SetDrawLayer("ARTWORK")

    self.highlight = LootFrame:CreateTexture(nil, "OVERLAY")
    self.highlight:SetTexture("Interface\\LootFrame\\UI-LootPanel")
    self.highlight:SetAllPoints(self.border)
    self.highlight:SetDrawLayer("ARTWORK")
    self.highlight:SetBlendMode("ADD")
  end

  self.titleRegion = self.titleRegion or FindLootTitle()

  if self.titleRegion
    and not self.titleColor
    and type(self.titleRegion.GetTextColor) == "function" then
    local r, g, b, a = self.titleRegion:GetTextColor()
    self.titleColor = { r or 1, g or .82, b or 0, a or 1 }
  end

  local function RestoreTitle()
    if not self.titleRegion or type(self.titleRegion.SetTextColor) ~= "function" then return end

    local color = self.titleColor
    if color then
      self.titleRegion:SetTextColor(color[1], color[2], color[3], color[4])
    else
      self.titleRegion:SetTextColor(1, .82, 0)
    end
  end

  local function ResetVisuals()
    self.border:Hide()
    self.highlight:Hide()
    RestoreTitle()
  end

  local function UpdateQuality()
    local highestQuality = 0
    local count = GetNumLootItems() or 0

    for i = 1, count do
      if LootSlotIsItem(i) then
        local _, _, _, quality = GetLootSlotInfo(i)
        quality = tonumber(quality) or 0
        if quality > highestQuality then
          highestQuality = quality
        end
      end
    end

    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[highestQuality]
    if highestQuality < MIN_QUALITY or not color then
      ResetVisuals()
      return
    end

    -- Common (white) items get the Darkened/Golden UI border color instead
    -- of white; every other quality keeps its color.
    local r, g, b = color.r, color.g, color.b
    local edge = ShaguTweaks.UIBorder
    if edge and r > .9 and g > .9 and b > .9 then r, g, b = edge.r, edge.g, edge.b end

    self.border:SetVertexColor(r, g, b)
    self.highlight:SetVertexColor(r, g, b)
    self.border:Show()
    self.highlight:Show()

    if self.titleRegion and type(self.titleRegion.SetTextColor) == "function" then
      self.titleRegion:SetTextColor(color.r, color.g, color.b)
    end
  end

  self.ResetVisuals = ResetVisuals
  self.events = self.events or CreateFrame("Frame")
  self.events:UnregisterAllEvents()
  self.events:RegisterEvent("LOOT_OPENED")
  self.events:RegisterEvent("LOOT_SLOT_CLEARED")
  self.events:RegisterEvent("LOOT_CLOSED")

  self.events:SetScript("OnEvent", function()
    if event == "LOOT_CLOSED" then
      ResetVisuals()
    else
      UpdateQuality()
    end
  end)

  ResetVisuals()
end

module.disable = function(self)
  if self.events then
    self.events:UnregisterAllEvents()
  end

  if self.ResetVisuals then
    self.ResetVisuals()
  end
end
