-- Finds out which item a tooltip is showing, by wrapping the tooltip functions of the game.
-- Every wrapper calls the original first, so other addons (pfUI) are not disturbed.

local AG = AdeGear

local function Wrap(tooltip, method, getLink)
  local original = tooltip[method]
  if type(original) ~= "function" then return end
  tooltip[method] = function(self, a, b, c, d)
    local r1, r2, r3 = original(self, a, b, c, d)
    local ok, link, own = pcall(getLink, a, b, c, d)
    if ok and link then
      if AG.GearScore then pcall(AG.GearScore.ItemLine, self, link) end
      AG.Inspect.Show(self, link, own)
    end
    return r1, r2, r3
  end
end

local function HookTooltip(tooltip)
  if not tooltip then return end
  Wrap(tooltip, "SetBagItem", function(bag, slot) return GetContainerItemLink(bag, slot) end)
  Wrap(tooltip, "SetInventoryItem", function(unit, slot) return GetInventoryItemLink(unit, slot), (unit == "player" and slot and slot >= 1 and slot <= 19) end)
  Wrap(tooltip, "SetHyperlink", function(link) return link end)
  Wrap(tooltip, "SetLootItem", function(slot) return GetLootSlotLink(slot) end)
  Wrap(tooltip, "SetMerchantItem", function(i) return GetMerchantItemLink(i) end)
  Wrap(tooltip, "SetAuctionItem", function(kind, i) return GetAuctionItemLink(kind, i) end)
  Wrap(tooltip, "SetQuestItem", function(kind, i) return GetQuestItemLink(kind, i) end)
  Wrap(tooltip, "SetQuestLogItem", function(kind, i) return GetQuestLogItemLink(kind, i) end)
  Wrap(tooltip, "SetLootRollItem", function(id) return GetLootRollItemLink(id) end)
  Wrap(tooltip, "SetTradePlayerItem", function(i) return GetTradePlayerItemLink(i) end)
  Wrap(tooltip, "SetTradeTargetItem", function(i) return GetTradeTargetItemLink(i) end)
  Wrap(tooltip, "SetTradeSkillItem", function(i, reagent)
    if reagent then return GetTradeSkillReagentItemLink(i, reagent) end
    return GetTradeSkillItemLink(i)
  end)

  -- hide our panel together with the tooltip, keeping the script that is already there
  local old = tooltip:GetScript("OnHide")
  tooltip:SetScript("OnHide", function()
    if old then old() end
    AG.Inspect.Hide()
  end)
end

HookTooltip(GameTooltip)
HookTooltip(ItemRefTooltip)
