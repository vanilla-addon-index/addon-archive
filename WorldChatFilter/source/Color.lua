-- WorldChatFilter v0.3.16 experimental World chat colors (Vanilla Lua 5.0).
-- Only touches the transient ChatTypeInfo["CHANNEL" .. WorldSlot] RGB fields.
-- No ChangeChatColor call and no persistent WoW chat-color modification.
local WCF = WorldChatFilter
local tintedSlot = nil
local original = nil

local presets = {
  {id = "warmstone", label = "Warm Stone",    r = 201/255, g = 184/255, b = 162/255},
  {id = "sage",      label = "Soft Sage",     r = 169/255, g = 189/255, b = 165/255},
  {id = "lavender",  label = "Muted Lavender",r = 184/255, g = 169/255, b = 206/255},
  {id = "gold",      label = "Dusty Gold",    r = 209/255, g = 183/255, b = 127/255},
}
WCF.COLOR_PRESETS = presets
WCF.DEFAULT_COLOR_PRESET = "gold"

local function clamp(value, fallback)
  value = tonumber(value)
  if not value or value ~= value then return fallback end
  if value < 0 then return 0 end
  if value > 1 then return 1 end
  return value
end

local function copyRGB(rgb)
  if type(rgb) ~= "table" then return nil end
  if type(rgb.r) ~= "number" or type(rgb.g) ~= "number" or type(rgb.b) ~= "number" then return nil end
  return {r = clamp(rgb.r, 209/255), g = clamp(rgb.g, 183/255), b = clamp(rgb.b, 127/255)}
end

local function findPreset(id)
  local _, entry
  for _, entry in ipairs(presets) do
    if entry.id == id then return entry end
  end
  return nil
end

function WCF.GetWorldColorPreset()
  if not WCF.db then WCF.Initialize() end
  local id = WCF.db.worldColorPreset
  if id == "custom" then return "custom" end
  if findPreset(id) then return id end
  return WCF.DEFAULT_COLOR_PRESET
end

function WCF.GetWorldColorRGB()
  local preset = WCF.GetWorldColorPreset()
  if preset == "custom" then
    local rgb = copyRGB(WCF.db.worldColorCustom)
    if rgb then return rgb.r, rgb.g, rgb.b end
  else
    local color = findPreset(preset)
    if color then return color.r, color.g, color.b end
  end
  local fallback = findPreset(WCF.DEFAULT_COLOR_PRESET)
  return fallback.r, fallback.g, fallback.b
end

function WCF.GetWorldColorLabel()
  local preset = WCF.GetWorldColorPreset()
  if preset == "custom" then return "Custom" end
  local entry = findPreset(preset)
  return entry and entry.label or "Dusty Gold"
end

function WCF.GetWorldColorHex()
  local r, g, b = WCF.GetWorldColorRGB()
  return string.format("#%02X%02X%02X", math.floor(r*255 + 0.5),
    math.floor(g*255 + 0.5), math.floor(b*255 + 0.5))
end

function WCF.SelectWorldColorPreset(id)
  if not findPreset(id) then return false end
  if not WCF.db then WCF.Initialize() end
  WCF.db.worldColorPreset = id
  WCF.RefreshWorldColor()
  return true
end

function WCF.SetCustomWorldColor(r, g, b)
  if not WCF.db then WCF.Initialize() end
  local beforeR, beforeG, beforeB = WCF.GetWorldColorRGB()
  WCF.db.worldColorCustom = {
    r = clamp(r, beforeR), g = clamp(g, beforeG), b = clamp(b, beforeB),
  }
  WCF.db.worldColorPreset = "custom"
  WCF.RefreshWorldColor()
end

function WCF.ResetWorldColorSelection()
  if not WCF.db then WCF.Initialize() end
  WCF.db.worldColorPreset = WCF.DEFAULT_COLOR_PRESET
  WCF.db.worldColorCustom = {}
  WCF.RefreshWorldColor()
end

local function validSlot(n)
  n = tonumber(n)
  if not n or n < 1 or n > 10 or math.floor(n) ~= n then return nil end
  return n
end

local function isWorldName(name)
  if type(name) ~= "string" then return false end
  name = WCF.Trim(name)
  return string.lower(name) == "world"
end

function WCF.RestoreWorldColor()
  if not tintedSlot or not original then return end
  local info = ChatTypeInfo and ChatTypeInfo["CHANNEL" .. tintedSlot]
  if info then info.r, info.g, info.b = original.r, original.g, original.b end
  tintedSlot, original = nil, nil
end

function WCF.ApplyWorldColor(slot)
  slot = validSlot(slot)
  if not WCF.db or not WCF.db.enabled or not WCF.db.tintWorld then
    WCF.RestoreWorldColor()
    return false
  end
  if not slot or type(ChatTypeInfo) ~= "table" then return false end
  local info = ChatTypeInfo["CHANNEL" .. slot]
  if not info or type(info.r) ~= "number" or type(info.g) ~= "number" or type(info.b) ~= "number" then
    return false
  end
  if tintedSlot ~= slot then
    WCF.RestoreWorldColor()
    original = {r = info.r, g = info.g, b = info.b}
    tintedSlot = slot
  end
  info.r, info.g, info.b = WCF.GetWorldColorRGB()
  return true
end

function WCF.RefreshWorldColor()
  if not WCF.db or not WCF.db.enabled or not WCF.db.tintWorld then
    WCF.RestoreWorldColor()
    return
  end
  -- Resolve World by NAME; never assume World is /4, /5, etc.
  if type(GetChannelName) ~= "function" then return end
  local id, name = GetChannelName("World")
  id = validSlot(id)
  if id and isWorldName(name) then
    WCF.ApplyWorldColor(id)
  else
    WCF.RestoreWorldColor()
  end
end

function WCF.ColorOnChannelEvent(baseName, numberedName, zoneID, channelID)
  local isWorld = WCF.IsWorldChannel(baseName, numberedName, zoneID)
  local id = validSlot(channelID)
  if isWorld then
    if id then WCF.ApplyWorldColor(id) else WCF.RefreshWorldColor() end
  elseif id and id == tintedSlot then
    WCF.RestoreWorldColor()
  end
end

-- Blizzard's built-in Vanilla color picker supports live callback + Cancel.
-- The picker has no meaningful channel alpha; do not show an opacity slider.
function WCF.OpenWorldColorPicker()
  if not WCF.db then WCF.Initialize() end
  if not ColorPickerFrame or not ColorPickerFrame.SetColorRGB or
     not ColorPickerFrame.GetColorRGB then
    WCF.Print("Blizzard Color Picker is unavailable on this client.")
    return false
  end
  local oldPreset = WCF.GetWorldColorPreset()
  local oldCustom = copyRGB(WCF.db.worldColorCustom)
  local r, g, b = WCF.GetWorldColorRGB()
  if CloseDropDownMenus then CloseDropDownMenus() end
  ColorPickerFrame:Hide()
  -- Prevent the previous addon's callback from firing while setting initial RGB.
  ColorPickerFrame.func = nil
  ColorPickerFrame.opacityFunc = nil
  ColorPickerFrame.cancelFunc = nil
  ColorPickerFrame.hasOpacity = false
  ColorPickerFrame.opacity = nil
  ColorPickerFrame.previousValues = {r, g, b}
  ColorPickerFrame:SetColorRGB(r, g, b)
  local active = true
  ColorPickerFrame.func = function()
    if not active then return end
    local red, green, blue = ColorPickerFrame:GetColorRGB()
    WCF.SetCustomWorldColor(red, green, blue)
  end
  ColorPickerFrame.cancelFunc = function()
    if not active then return end
    active = false
    WCF.db.worldColorPreset = oldPreset
    WCF.db.worldColorCustom = oldCustom or {}
    WCF.RefreshWorldColor()
  end
  -- Some clients show via UIParent, but the default picker exists in 1.12.
  ColorPickerFrame:Show()
  return true
end
