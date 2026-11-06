-- SunderNP.lua
-- Tracks Sunder stacks on nameplates + Overpower (4s window + 5s cooldown).
-- Slash commands: /sundernp or /snp
--   opon  : enable Overpower on nameplates
--   opoff : disable Overpower on nameplates
--   help  : usage info

------------------------------------------------
-- 0) Saved Variables & Defaults
------------------------------------------------
SunderNPDB = SunderNPDB or {}

local SunderNP_Defaults = {
  overpowerEnabled = false,  -- Overpower is on by default
}

local function SunderNP_Initialize()
  for k, v in pairs(SunderNP_Defaults) do
    if SunderNPDB[k] == nil then
      SunderNPDB[k] = v
    end
  end
end

------------------------------------------------
-- 1) Slash Command Handler
------------------------------------------------
local function SunderNP_SlashCommand(msg)
  -- Force "msg" to be a string
  if type(msg) ~= "string" then
    msg = ""
  end

  -- Convert to lowercase
  msg = string.lower(msg)

  if msg == "opon" then
    SunderNPDB.overpowerEnabled = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SunderNP]|r Overpower feature: |cff00ff00ENABLED|r.")
  elseif msg == "opoff" then
    SunderNPDB.overpowerEnabled = false
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SunderNP]|r Overpower feature: |cffff0000DISABLED|r.")
  elseif msg == "help" or msg == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SunderNP]|r usage:")
    DEFAULT_CHAT_FRAME:AddMessage("  /sundernp opon   -> enable Overpower icon on nameplates")
    DEFAULT_CHAT_FRAME:AddMessage("  /sundernp opoff  -> disable Overpower icon on nameplates")
    DEFAULT_CHAT_FRAME:AddMessage("  /sundernp help   -> show this help text")
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SunderNP]|r: Unrecognized command '"..msg.."'. Type '/sundernp help' for usage.")
  end
end

------------------------------------------------
-- 2) Register an Event for Initialization
------------------------------------------------
local SunderNPFrame = CreateFrame("Frame", "SunderNP_MainFrame")
SunderNPFrame:RegisterEvent("VARIABLES_LOADED")
SunderNPFrame:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    SunderNP_Initialize()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[SunderNP]|r loaded. Type '/sundernp help' for options.")
  end
end)

-- Create slash commands
SLASH_SUNDERNP1 = "/sundernp"
SLASH_SUNDERNP2 = "/snp"
SlashCmdList["SUNDERNP"] = SunderNP_SlashCommand

------------------------------------------------
-- 3) Overpower Logic (4s window + 5s cooldown)
------------------------------------------------
local OverpowerFrame = CreateFrame("Frame", "SunderNP_OverpowerFrame", UIParent)

-- Overpower state
local overpowerActive = false
local overpowerEndTime = 0

local overpowerOnCooldown = false
local overpowerCdEndTime  = 0

local function IsOverpowerActive()
  return overpowerActive and (GetTime() < overpowerEndTime)
end

local function IsOverpowerOnCooldown()
  return overpowerOnCooldown and (GetTime() < overpowerCdEndTime)
end

local function IsOverpowerUsable()
  return IsOverpowerActive() and not IsOverpowerOnCooldown()
end

-- Listen for events that cause Overpower
OverpowerFrame:RegisterEvent("COMBAT_TEXT_UPDATE")           -- "SPELL_ACTIVE", Overpower
OverpowerFrame:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")  -- "dodges"
OverpowerFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")   -- "Your Overpower..."

OverpowerFrame:SetScript("OnEvent", function()
  local msg = arg1 or ""

  if event == "COMBAT_TEXT_UPDATE" then
    if arg1 == "SPELL_ACTIVE" and arg2 == "Overpower" then
      overpowerActive = true
      overpowerEndTime = GetTime() + 4

    end
  elseif event == "CHAT_MSG_COMBAT_SELF_MISSES" then
    if string.find(msg, "dodges") then
      if overpowerActive then
        overpowerEndTime = GetTime() + 4
      else
        overpowerActive = true
        overpowerEndTime = GetTime() + 4
      end
    end
  elseif event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
    if string.find(msg, "^Your Overpower") then
      -- Used Overpower => 5s cooldown
      overpowerOnCooldown = true
      overpowerCdEndTime  = GetTime() + 5

      if overpowerActive then
        overpowerActive = false
      end
    end
  end
end)

OverpowerFrame:SetScript("OnUpdate", function()
  local now = GetTime()

  if overpowerActive and now >= overpowerEndTime then
    overpowerActive = false
  end

  if overpowerOnCooldown and now >= overpowerCdEndTime then
    overpowerOnCooldown = false
  end
end)

------------------------------------------------
-- 4) Sunder Tracking
------------------------------------------------
local SunderArmorTexture = "Interface\\Icons\\Ability_Warrior_Sunder"

local function GetSunderStacks(unit)
  for i = 1, 16 do
    local name, icon, count = UnitDebuff(unit, i)
    if name == SunderArmorTexture then
      -- "icon" is actually the stack count
      return tonumber(icon) or 0
    end
  end
  return 0
end

------------------------------------------------
-- 5) pfUI Nameplate Hook
------------------------------------------------
local OverpowerIconTexture = "Interface\\Icons\\Ability_MeleeDamage"

local function HookPfuiNameplates()
  if not pfUI or not pfUI.nameplates then return end

  local oldOnCreate = pfUI.nameplates.OnCreate
  pfUI.nameplates.OnCreate = function(frame)
    oldOnCreate(frame)

    local plate = frame.nameplate
    if not plate or not plate.health then return end

    -- Sunder text
    local sunderText = plate.health:CreateFontString(nil, "OVERLAY")
    sunderText:SetFont("Fonts\\FRIZQT__.TTF", 25, "OUTLINE")
    sunderText:SetPoint("LEFT", plate.health, "RIGHT", 15, 0)
    plate.sunderText = sunderText

    -- Overpower icon
    local overpowerIcon = plate.health:CreateTexture(nil, "OVERLAY")
    overpowerIcon:SetTexture(OverpowerIconTexture)
    overpowerIcon:SetWidth(32)
    overpowerIcon:SetHeight(32)
    overpowerIcon:SetPoint("TOP", plate.health, "TOP", 0, 60)
    overpowerIcon:Hide()
    plate.overpowerIcon = overpowerIcon

    -- Overpower timer text
    local overpowerTimer = plate.health:CreateFontString(nil, "OVERLAY")
    overpowerTimer:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    overpowerTimer:SetPoint("CENTER", overpowerIcon, "CENTER", 0, 0)
    overpowerTimer:SetText("")
    overpowerTimer:Hide()
    plate.overpowerTimer = overpowerTimer
  end

  local oldOnDataChanged = pfUI.nameplates.OnDataChanged
  pfUI.nameplates.OnDataChanged = function(self, plate)
    oldOnDataChanged(self, plate)
    if not plate or not plate.sunderText or not plate.overpowerIcon or not plate.overpowerTimer then
      return
    end

    -- Sunder
    local guid = plate.parent:GetName(1)
    if guid and UnitExists(guid) then
      local stacks = GetSunderStacks(guid)
      if stacks > 0 then
        plate.sunderText:SetText(stacks)
        if stacks == 5 then
          plate.sunderText:SetTextColor(0, 1, 0, 1)
        elseif stacks == 4 then
          plate.sunderText:SetTextColor(0, 0.6, 0, 1)
        elseif stacks == 3 then
          plate.sunderText:SetTextColor(1, 1, 0, 1)
        elseif stacks == 2 then
          plate.sunderText:SetTextColor(1, 0.647, 0, 1)
        elseif stacks == 1 then
          plate.sunderText:SetTextColor(1, 0, 0, 1)
        end
      else
        plate.sunderText:SetText("")
      end
    else
      plate.sunderText:SetText("")
    end

    -- Overpower: only if user has it enabled in SunderNPDB
    if SunderNPDB.overpowerEnabled then
      -- Only show for current target
      if guid and UnitIsUnit(guid, "target") then
        if IsOverpowerActive() then
          plate.overpowerIcon:Show()
          plate.overpowerTimer:Show()

          if IsOverpowerOnCooldown() then
            local cdLeft = math.floor(overpowerCdEndTime - GetTime() + 0.5)
            if cdLeft < 0 then cdLeft = 0 end
            plate.overpowerTimer:SetText(cdLeft)
            plate.overpowerTimer:SetTextColor(1, 0, 0, 1) -- red
          else
            local windowLeft = math.floor(overpowerEndTime - GetTime() + 0.5)
            if windowLeft < 0 then windowLeft = 0 end
            plate.overpowerTimer:SetText(windowLeft)
            plate.overpowerTimer:SetTextColor(1, 1, 1, 1) -- white
          end
        else
          plate.overpowerIcon:Hide()
          plate.overpowerTimer:Hide()
          plate.overpowerTimer:SetText("")
        end
      else
        plate.overpowerIcon:Hide()
        plate.overpowerTimer:Hide()
        plate.overpowerTimer:SetText("")
      end
    else
      -- Overpower disabled => hide icon/timer
      plate.overpowerIcon:Hide()
      plate.overpowerTimer:Hide()
      plate.overpowerTimer:SetText("")
    end
  end
end

------------------------------------------------
-- 6) Default Blizzard Nameplates
------------------------------------------------
local nameplateCache = {}

local function CreatePlateElements(frame)
  local sunderText = frame:CreateFontString(nil, "OVERLAY")
  sunderText:SetFont("Fonts\\FRIZQT__.TTF", 25, "OUTLINE")
  sunderText:SetPoint("RIGHT", frame, "RIGHT", 15, 0)

  local overpowerIcon = frame:CreateTexture(nil, "OVERLAY")
  overpowerIcon:SetTexture(OverpowerIconTexture)
  overpowerIcon:SetWidth(32)
  overpowerIcon:SetHeight(32)
  overpowerIcon:SetPoint("TOP", frame, "TOP", 0, 60)
  overpowerIcon:Hide()

  local overpowerTimer = frame:CreateFontString(nil, "OVERLAY")
  overpowerTimer:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
  overpowerTimer:SetPoint("CENTER", overpowerIcon, "CENTER", 0, 0)
  overpowerTimer:SetText("")
  overpowerTimer:Hide()

  nameplateCache[frame] = {
    sunderText     = sunderText,
    overpowerIcon  = overpowerIcon,
    overpowerTimer = overpowerTimer,
  }
end

local function UpdateDefaultNameplates()
  local frames = { WorldFrame:GetChildren() }
  for _, frame in ipairs(frames) do
    if frame:IsVisible() and frame:GetName() == nil then
      local healthBar = frame:GetChildren()
      if healthBar and healthBar:IsObjectType("StatusBar") then
        if not nameplateCache[frame] then
          CreatePlateElements(frame)
        end
        local cache = nameplateCache[frame]
        local sunderText     = cache.sunderText
        local overpowerIcon  = cache.overpowerIcon
        local overpowerTimer = cache.overpowerTimer

        -- Usually, current target's nameplate has alpha=1
        if frame:GetAlpha() == 1 and UnitExists("target") then
          local stacks = GetSunderStacks("target")
          if stacks > 0 then
            sunderText:SetText(stacks)
            if stacks == 5 then
              sunderText:SetTextColor(0,1,0,1)
            else
              sunderText:SetTextColor(1,1,0,1)
            end
          else
            sunderText:SetText("")
          end

          if SunderNPDB.overpowerEnabled then
            if IsOverpowerActive() then
              overpowerIcon:Show()
              overpowerTimer:Show()

              if IsOverpowerOnCooldown() then
                local cdLeft = math.floor(overpowerCdEndTime - GetTime() + 0.5)
                if cdLeft<0 then cdLeft=0 end
                overpowerTimer:SetText(cdLeft)
                overpowerTimer:SetTextColor(1,0,0,1)
              else
                local windowLeft = math.floor(overpowerEndTime - GetTime() + 0.5)
                if windowLeft<0 then windowLeft=0 end
                overpowerTimer:SetText(windowLeft)
                overpowerTimer:SetTextColor(1,1,1,1)
              end
            else
              overpowerIcon:Hide()
              overpowerTimer:Hide()
              overpowerTimer:SetText("")
            end
          else
            -- Overpower disabled
            overpowerIcon:Hide()
            overpowerTimer:Hide()
            overpowerTimer:SetText("")
          end
        else
          -- not current target => hide
          sunderText:SetText("")
          overpowerIcon:Hide()
          overpowerTimer:Hide()
          overpowerTimer:SetText("")
        end
      end
    end
  end
end

local function HookDefaultNameplates()
  local updater = CreateFrame("Frame", "SunderNP_DefaultFrame")
  updater.tick = 0
  updater:SetScript("OnUpdate", function()
    if (this.tick or 0) > GetTime() then return end
    this.tick = GetTime() + 0.5
    UpdateDefaultNameplates()
  end)
end

------------------------------------------------
-- 7) Decide Which Hook
------------------------------------------------
if pfUI and pfUI.nameplates then
  HookPfuiNameplates()
else
  HookDefaultNameplates()
end
