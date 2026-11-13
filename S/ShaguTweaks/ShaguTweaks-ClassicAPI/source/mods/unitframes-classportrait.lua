local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API or {}

local addonpath
local tocs = { "", "-master", "-tbc", "-wotlk" }
for _, name in pairs(tocs) do
  local current = string.format("ShaguTweaks%s", name)
  local _, title = GetAddOnInfo(current)
  if title then
    addonpath = "Interface\\AddOns\\" .. current
    break
  end
end

local CLASS_PORTRAIT_TEXTURE = (addonpath or "Interface\\AddOns\\ShaguTweaks") .. "\\img\\UI-Classes-Circles"

local CLASS_ICON_TCOORDS = {
  ["WARRIOR"] = { 0, 0.25, 0, 0.25 },
  ["MAGE"] = { 0.25, 0.49609375, 0, 0.25 },
  ["ROGUE"] = { 0.49609375, 0.7421875, 0, 0.25 },
  ["DRUID"] = { 0.7421875, 0.98828125, 0, 0.25 },
  ["HUNTER"] = { 0, 0.25, 0.25, 0.5 },
  ["SHAMAN"] = { 0.25, 0.49609375, 0.25, 0.5 },
  ["PRIEST"] = { 0.49609375, 0.7421875, 0.25, 0.5 },
  ["WARLOCK"] = { 0.7421875, 0.98828125, 0.25, 0.5 },
  ["PALADIN"] = { 0, 0.25, 0.5, 0.75 },
  ["DEATHKNIGHT"] = { 0.25, .5, 0.5, .75 },
}

local module = ShaguTweaks:register({
  title = T["Unit Frame Class Portraits"],
  description = T["Replace unitframe portraits with class icons."],
  expansions = { ["vanilla"] = true },
  category = T["Unit Frames"],
  enabled = nil,
})

local function UpdatePortraits(frame)
  if not frame or not frame.unit or not frame.portrait then return end

  -- detect unit class or remove for non-player units
  local _, class = UnitClass(frame.unit)
  class = UnitIsPlayer(frame.unit) and class or nil

  -- Reapply after Blizzard's UnitFrame_Update: that function can replace the
  -- portrait texture even when the new target has the same class.
  if class then
    local iconCoords = CLASS_ICON_TCOORDS[class]
    if iconCoords then
      local wanted = CLASS_PORTRAIT_TEXTURE
      if frame.portrait:GetTexture() ~= wanted then frame.portrait:SetTexture(wanted) end
      local l, t, l2, b, r, t2, r2, b2 = frame.portrait:GetTexCoord()
      if l ~= iconCoords[1] or t ~= iconCoords[3] or l2 ~= iconCoords[1]
        or b ~= iconCoords[4] or r ~= iconCoords[2] or t2 ~= iconCoords[3]
        or r2 ~= iconCoords[2] or b2 ~= iconCoords[4] then
        frame.portrait:SetTexCoord(unpack(iconCoords))
      end
    end
  else
    local l, t, l2, b, r, t2, r2, b2 = frame.portrait:GetTexCoord()
    if l ~= 0 or t ~= 0 or l2 ~= 0 or b ~= 1 or r ~= 1 or t2 ~= 0 or r2 ~= 1 or b2 ~= 1 then
      frame.portrait:SetTexCoord(0, 1, 0, 1)
    end
  end
end

module.enable = function(self)
  -- overwrite portraits set by the game
  ShaguTweaks.hooksecurefunc("UnitFrame_Update", function(frame)
    UpdatePortraits(type(frame) == "table" and frame.unit and frame or this)
  end)

  -- handle portrait update events
  local events = CreateFrame("Frame")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:RegisterEvent("UNIT_PORTRAIT_UPDATE")
  local function RefreshFrame(frame)
    if not frame or not frame.unit then return end
    if event == "PLAYER_ENTERING_WORLD" or frame.unit == arg1
      or (arg1 and UnitIsUnit(frame.unit, arg1)) then UpdatePortraits(frame) end
  end
  events:SetScript("OnEvent", function()
    RefreshFrame(PlayerFrame)
    RefreshFrame(TargetFrame)
    RefreshFrame(PartyMemberFrame1)
    RefreshFrame(PartyMemberFrame2)
    RefreshFrame(PartyMemberFrame3)
    RefreshFrame(PartyMemberFrame4)
  end)

  -- Turtle/Vanilla already runs TargetofTarget_OnUpdate for the target-of-target
  -- frame. Reuse that existing update path instead of adding a second poller.
  -- Keep a GUID cache when ClassicAPI is available so two units with the same
  -- display name are still detected as different units.
  local lasttotguid = nil
  if type(TargetofTarget_OnUpdate) == "function" then
    local originalTargetofTargetOnUpdate = TargetofTarget_OnUpdate
    -- The stock handler replaces the portrait when CURRENT_TARGETTARGET (the
    -- target-of-target's name) changes; reapply the class icon in that same
    -- frame. A GUID check five times a second covers same-name units and
    -- clients whose handler does not track that global, instead of calling
    -- UnitGUID on every frame.
    local totelapsed = 0
    TargetofTarget_OnUpdate = function(elapsed)
      local before = CURRENT_TARGETTARGET
      originalTargetofTargetOnUpdate(elapsed)

      totelapsed = totelapsed + (elapsed or arg1 or 0)
      if CURRENT_TARGETTARGET == before and totelapsed < .2 then return end
      totelapsed = 0

      local guid = API.UnitGUID and API.UnitGUID("targettarget") or UnitName("targettarget")
      if guid ~= lasttotguid or CURRENT_TARGETTARGET ~= before then
        lasttotguid = guid
        UpdatePortraits(TargetofTargetFrame)
      end
    end
  else
    -- Compatibility fallback for clients that do not expose the stock handler.
    local tot = CreateFrame("Frame", nil, TargetFrame)
    tot.elapsed = 0
    tot:SetScript("OnUpdate", function()
      this.elapsed = this.elapsed + arg1
      if this.elapsed < .2 then return end
      this.elapsed = 0

      local guid = API.UnitGUID and API.UnitGUID("targettarget") or UnitName("targettarget")
      if guid ~= lasttotguid then
        lasttotguid = guid
        UpdatePortraits(TargetofTargetFrame)
      end
    end)
  end
end
