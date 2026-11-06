-- EGM startup wiring: DB init, tabs, slash commands, comm start. Loads last.
EGM = EGM or {}

local inited = false
local tabsDone = false

local function registerTabs()
  if tabsDone or not (EGM.UI and EGM.UI.registerTab) or not EGM.PendingTabs then return end
  tabsDone = true
  for i = 1, table.getn(EGM.PendingTabs) do
    local t = EGM.PendingTabs[i]
    if t and t.index and t.build then EGM.UI.registerTab(t.index, t.build, t.refresh) end
  end
end

local function init()
  if inited then return end
  inited = true
  if EGM.DB and EGM.DB.init then EGM.DB.init() end
  registerTabs()
  if EGM.Minimap and EGM.Minimap.update then EGM.Minimap.update() end
  if EGM.Comm and EGM.Comm.start then EGM.Comm.start() end
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("EGM " .. (EGM.VERSION or "0.1.0") .. " loaded - /egm")
  end
end

SLASH_EGM1 = "/egm"
SlashCmdList["EGM"] = function(msg)
  msg = string.lower(msg or "")
  if string.find(msg, "^%s*debug") then
    EGM.debug = not EGM.debug
    DEFAULT_CHAT_FRAME:AddMessage("EGM debug " .. (EGM.debug and "on" or "off"))
  elseif string.find(msg, "^%s*options") then
    if EGM.Options and EGM.Options.show then EGM.Options.show() end
  elseif EGM.UI and EGM.UI.toggle then
    EGM.UI.toggle()
  end
end

if CreateFrame then
  local f = CreateFrame("Frame", "EGMInitFrame")
  f:RegisterEvent("ADDON_LOADED")
  f:RegisterEvent("VARIABLES_LOADED")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
      if arg1 == "EGM" then init() end
    elseif event == "VARIABLES_LOADED" then
      init()
    else
      -- late safety net: tabs registered by files that load after the UI core
      init()
      registerTabs()
    end
  end)
end
