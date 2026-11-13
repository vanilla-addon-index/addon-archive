local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
  title = T["Reagent Counter"],
  description = T["Shows a reagent counter on action buttons."],
  expansions = { ["vanilla"] = true, ["tbc"] = false },
  maintainer = "@shagu (GitHub)",
  category = T["Action Bar"],
  enabled = nil,
})

module.enable = function(self)
  if self.counter then return end
  local reagent_slots = { }
  local reagent_counts = { }
  local macro_slots = { }
  local bars = { "Action", "BonusAction", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight" }

  local reagentcounter = CreateFrame("Frame", "ShaguTweaksReagentCount", UIParent)
  self.counter = reagentcounter
  reagentcounter:RegisterEvent("PLAYER_ENTERING_WORLD")
  reagentcounter:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
  reagentcounter:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
  reagentcounter:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
  reagentcounter:RegisterEvent("UPDATE_MACROS")
  reagentcounter:RegisterEvent("SPELLS_CHANGED")
  reagentcounter:RegisterEvent("BAG_UPDATE")

  local macroEvents = { "MODIFIER_STATE_CHANGED", "PLAYER_TARGET_CHANGED",
    "UPDATE_MOUSEOVER_UNIT", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS", "SPELL_UPDATE_COOLDOWN",
    "UNIT_AURA", "UNIT_DISPLAYPOWER" }
  local macroEventSet = {}
  local watchingMacros = false
  local function WatchMacros()
    local needed = next(macro_slots) ~= nil
    if needed == watchingMacros then return end
    watchingMacros = needed
    for _, name in ipairs(macroEvents) do
      if needed and API.eventutils and _G.C_EventUtils.IsEventValid(name) then
        macroEventSet[name] = true
        if name == "UNIT_AURA" or name == "UNIT_DISPLAYPOWER" then
          API.RegisterUnitEvent(reagentcounter, name, "player")
        else reagentcounter:RegisterEvent(name) end
      elseif not needed then
        reagentcounter:UnregisterEvent(name)
        macroEventSet[name] = nil
      end
    end
  end

  -- Hidden frames still receive events, but do not execute OnUpdate.
  -- Wake for one frame only when work is pending.
  reagentcounter:Hide()
  reagentcounter:SetScript("OnEvent", function()
    if (event == "UNIT_AURA" or event == "UNIT_DISPLAYPOWER") and arg1 ~= "player" then return end
    this.pending = true
    if macroEventSet[event] then
      this.macros = true
    elseif event ~= "BAG_UPDATE" then
      this.rescan = true
    end
    this:Show()
  end)

  reagentcounter:SetScript("OnUpdate", function()
    if not this.pending then
      this:Hide()
      return
    end

    -- Rebuild the action-slot -> reagent mapping only when the action layout
    -- changes. ClassicAPI resolves the spell/macro directly, so no tooltip
    -- scan or localized reagent-name parsing is required.
    if this.rescan then
      for slot = 1, 120 do
        reagentcounter.ScanSlot(slot)
      end
      WatchMacros()
    elseif this.macros then
      -- A native macro can resolve to another spell without being edited.
      -- Re-evaluate only known macro actions, not all 120 action slots.
      for slot in pairs(macro_slots) do reagentcounter.ScanSlot(slot) end
      WatchMacros()
    end

    -- Count only reagents referenced by active actions. ClassicAPI reads the
    -- inventory directly, avoiding a Lua bag scan for every reagent.
    for itemID in pairs(reagent_counts) do reagent_counts[itemID] = nil end
    for _, itemID in pairs(reagent_slots) do
      if reagent_counts[itemID] == nil then
        reagent_counts[itemID] = API.GetItemCount(itemID, false, false) or 0
      end
    end

    -- update all actionbar buttons
    for _, prefix in ipairs(bars) do
      for i = 1, NUM_ACTIONBAR_BUTTONS do
        local button = _G[prefix .. "Button" .. i]
        if button then
          local text = _G[button:GetName().."Count"]
          local slot = ActionButton_GetPagedID(button)

          if text then
            local itemID = reagent_slots[slot]
            if itemID then
              text:SetText(reagent_counts[itemID] or 0)
            elseif not IsConsumableAction(slot) then
              text:SetText()
            end
          end
        end
      end
    end

    this.pending = nil
    this.rescan = nil
    this.macros = nil
    this:Hide()
  end)

  reagentcounter.ScanSlot = function(slot)
    reagent_slots[slot] = nil
    macro_slots[slot] = nil
    if not HasAction(slot) then return end

    local actionType, actionID = API.GetActionInfo(slot)
    local spellID

    if actionType == "spell" then
      spellID = actionID
    elseif actionType == "macro" and actionID then
      macro_slots[slot] = actionID
      local _, _, macroSpellID = API.GetMacroSpell(actionID)
      spellID = macroSpellID
    end

    if not spellID then return end

    local reagents = API.GetSpellReagents(spellID)
    local reagent = reagents and reagents[1]
    if not reagent or not reagent.itemID then return end

    -- The action button only has one count field. Preserve the historical
    -- behavior by showing the first reagent's owned stack count.
    reagent_slots[slot] = reagent.itemID
  end

  -- The stock UI clears the Count fontstring on non-consumable actions whenever
  -- ActionButton_UpdateCount() runs. Re-apply our reagent value afterwards so
  -- login/reload refreshes cannot erase it a moment later.
  ShaguTweaks.hooksecurefunc("ActionButton_UpdateCount", function()
    local button = this
    if not button or not button.GetName then return end

    local slot = ActionButton_GetPagedID(button)
    local itemID = slot and reagent_slots[slot]
    if not itemID then return end

    local text = _G[button:GetName().."Count"]
    if text then
      text:SetText(reagent_counts[itemID] or 0)
    end
  end)
end
