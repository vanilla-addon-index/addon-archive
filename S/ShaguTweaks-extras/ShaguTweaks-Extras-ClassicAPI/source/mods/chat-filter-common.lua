-- Shared chat-filter dispatcher for Extras modules.
-- Installs one ChatFrame_OnEvent wrapper only when a filter is enabled.

local Filter = ShaguTweaks.ExtrasChatFilter

if not Filter then
  Filter = {
    handlers = {},
    order = {},
    known = {},
    installed = false,
    installer = nil,
  }
  ShaguTweaks.ExtrasChatFilter = Filter
end

function Filter:Install()
  if self.installed then return end

  self.installed = true
  self.original = ChatFrame_OnEvent

  ChatFrame_OnEvent = function(event)
    for i = 1, table.getn(Filter.order) do
      local current = Filter.handlers[Filter.order[i]]
      if current and current(event) then
        return
      end
    end

    if Filter.original then
      return Filter.original(event)
    end
  end
end

function Filter:ScheduleInstall()
  if self.installed or self.installer then return end

  -- ShaguTweaks enables modules during VARIABLES_LOADED in unspecified table
  -- order. Install on PLAYER_ENTERING_WORLD so this dispatcher becomes the
  -- outer wrapper after the core Chat Spam Filter regardless of module order.
  -- That prevents locally hidden World/NPC messages from entering its cache.
  self.installer = CreateFrame("Frame")
  self.installer:RegisterEvent("PLAYER_ENTERING_WORLD")
  self.installer:SetScript("OnEvent", function()
    Filter:Install()
    this:UnregisterAllEvents()
    this:Hide()
    Filter.installer = nil
  end)
end

function Filter:Register(key, handler)
  if type(key) ~= "string" or type(handler) ~= "function" then return end

  if not self.known[key] then
    self.known[key] = true
    self.order[table.getn(self.order) + 1] = key
  end

  self.handlers[key] = handler
  self:ScheduleInstall()
end

function Filter:Unregister(key)
  self.handlers[key] = nil
end
