-- Adapted from TokensWorth/ShaguTweaks-mods (MIT, original copyright GryllsAddons).

local T = ShaguTweaks.T
local Filter = ShaguTweaks.ExtrasChatFilter

local module = ShaguTweaks:register({
  title = T["World Chat Hider"],
  description = T["Hides World channel messages while inside an instance without leaving the channel."],
  expansions = { ["vanilla"] = true, ["tbc"] = nil },
  category = T["Chat"],
  enabled = nil,
})

local function IsInsideInstance()
  if type(IsInInstance) ~= "function" then return false end

  local inside = IsInInstance()
  return inside == 1 or inside == true
end

local function IsWorldChannel()
  -- Vanilla 1.12 CHAT_MSG_CHANNEL exposes the base channel name in arg9.
  -- Custom channel names are not localized, so comparing the actual event is
  -- both cheaper and safer than querying GetChannelName("world") every time.
  if arg9 and string.lower(arg9) == "world" then
    return true
  end

  -- Conservative fallback for clients that omit arg9: arg4 is the numbered
  -- channel label (for example "5. World").
  if arg4 then
    local full = string.lower(arg4)
    if full == "world" then return true end

    local _, _, base = string.find(full, "^%d+%.%s*(.+)$")
    if base == "world" then return true end
  end

  return false
end

local function FilterWorldChat(event)
  if event ~= "CHAT_MSG_CHANNEL" then return false end
  if not IsInsideInstance() then return false end

  return IsWorldChannel()
end

module.enable = function(self)
  if Filter then
    Filter:Register("WorldChatHider", FilterWorldChat)
  end
end

module.disable = function(self)
  if Filter then
    Filter:Unregister("WorldChatHider")
  end
end
