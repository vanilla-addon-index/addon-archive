local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API
local module = ShaguTweaks:register({
  title = T["Proc & Reactive Spell Highlights"],
  description = T["Highlights action buttons for active procs and reactive spells using ClassicAPI. Supports spells and macros; central proc artwork is left to other addons."],
  expansions = { ["vanilla"] = true }, category = T["Action Bar"], enabled = nil,
})
module.enable = function(self)
  if self.states then return end
  local query = _G.C_SpellActivationOverlay and _G.C_SpellActivationOverlay.IsSpellOverlayed or _G.IsSpellOverlayed
  local valid = _G.C_EventUtils and _G.C_EventUtils.IsEventValid
  if type(query) ~= "function" or not API.GetActionInfo or not valid
    or not valid("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    or not valid("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE") then return end
  local states, byButton = {}, {}
  self.states = states
  local function Paint(state, active)
    if active then
      if not state.glow:IsShown() then
        state.glow:Show()
        if state.pulse then state.pulse:Play() end
      end
    else
      if state.pulse then state.pulse:Stop() end
      state.glow:Hide()
    end
  end
  local function Sync(state)
    local spell
    if state.button:IsVisible() then
      local slot = ActionButton_GetPagedID(state.button)
      if slot then
        local kind, id = API.GetActionInfo(slot)
        if kind == "spell" then spell = id
        elseif kind == "macro" and _G.GetMacroSpell then
          local name, rank, spellID = _G.GetMacroSpell(id)
          spell = spellID
        end
      end
    end
    state.spell = spell
    Paint(state, spell and query(spell))
  end
  for _, prefix in ipairs({"ActionButton", "BonusActionButton", "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton", "MultiBarRightButton", "MultiBarLeftButton"}) do
    for i = 1, 12 do
      local button = _G[prefix .. i]
      if button then
        local glow = CreateFrame("Frame", nil, button)
        glow:SetAllPoints(button)
        glow:SetFrameLevel(button:GetFrameLevel() + 5)
        glow:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
        glow:SetBackdropBorderColor(.7, .9, 1, 1)
        -- Additive light stands out against both dark and gold button rims.
        -- Use the client's existing action-button glow artwork.
        local halo = glow:CreateTexture(nil, "OVERLAY")
        halo:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        halo:SetBlendMode("ADD")
        halo:SetVertexColor(.55, .85, 1, 1)
        halo:SetPoint("TOPLEFT", button, "TOPLEFT", -8, 8)
        halo:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 8, -8)
        glow:EnableMouse(false)
        glow:Hide()
        local state = { button = button, glow = glow, halo = halo }
        if type(glow.CreateAnimationGroup) == "function" then
          local pulse = glow:CreateAnimationGroup()
          local fade = pulse:CreateAnimation("Alpha")
          if type(fade.SetFromAlpha) == "function" and type(fade.SetToAlpha) == "function" then
            pulse:SetLooping("BOUNCE")
            fade:SetFromAlpha(1); fade:SetToAlpha(.7)
            fade:SetDuration(.4); fade:SetSmoothing("IN_OUT")
            state.pulse = pulse
          end
        end
        table.insert(states, state); byButton[button] = state
        local function Changed() Sync(state) end
        ShaguTweaks.HookScript(button, "OnShow", Changed)
        ShaguTweaks.HookScript(button, "OnHide", Changed)
        Sync(state)
      end
    end
  end
  ShaguTweaks.hooksecurefunc("ActionButton_Update", function()
    local state = byButton[this]
    if state then Sync(state) end
  end)
  local events = CreateFrame("Frame")
  self.events = events
  for _, name in ipairs({"SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
    "PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED",
    "UPDATE_BONUS_ACTIONBAR", "UPDATE_MACROS", "ACTIONBAR_UPDATE_STATE",
    "PLAYER_TARGET_CHANGED", "MODIFIER_STATE_CHANGED", "SPELLS_CHANGED"}) do
    if valid(name) then events:RegisterEvent(name) end
  end
  events:SetScript("OnEvent", function()
    local proc = event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE"
    for _, state in ipairs(states) do
      if proc then
        if state.spell == arg1 then Paint(state, state.button:IsVisible() and query(arg1)) end
      else Sync(state) end
    end
  end)
end
