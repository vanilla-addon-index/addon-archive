--[[
  MIT License

  Copyright (c) 2019 Michael Wiesendanger

  Permission is hereby granted, free of charge, to any person obtaining
  a copy of this software and associated documentation files (the
  "Software"), to deal in the Software without restriction, including
  without limitation the rights to use, copy, modify, merge, publish,
  distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to
  the following conditions:

  The above copyright notice and this permission notice shall be
  included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--

local mod = gm
local me = {}
mod.cmd = me

me.tag = "Cmd"

--[[
  Print cmd options for addon
]]--
local function ShowInfoMessage()
  DEFAULT_CHAT_FRAME:AddMessage(gm.L["info_title"])
  DEFAULT_CHAT_FRAME:AddMessage(gm.L["show"])
  DEFAULT_CHAT_FRAME:AddMessage(gm.L["hide"])
  DEFAULT_CHAT_FRAME:AddMessage(gm.L["opt"])
  DEFAULT_CHAT_FRAME:AddMessage(gm.L["reload"])
end

--[[
  Looks through every currently registered slash command (SLASH_*) to find
  one whose text is exactly "/gm" and returns the handler function bound to
  it. This lets us chain to whatever "/gm" already did (e.g. the built-in
  GM ticket window) before GearMenu adds its own "/gm" handling, instead of
  silently replacing it.
]]--
local function FindExistingGmHandler()
  for key, value in pairs(_G) do
    if type(key) == "string" and type(value) == "string" and value == "/gm" then
      local cmdKey = string.gsub(key, "^SLASH_", "")
      cmdKey = string.gsub(cmdKey, "%d+$", "")

      if string.find(key, "^SLASH_") and SlashCmdList[cmdKey] then
        return SlashCmdList[cmdKey]
      end
    end
  end

  return nil
end

--[[
  Shared handling for the GearMenu subcommands, used by both "/gm" and
  "/gearmenu".
]]--
local function HandleGearMenuCommand(msg)
  if msg == "" or msg == "info" then
    ShowInfoMessage()
  elseif msg == "opt" then
    mod.opt.InitOptionsMenu()
  elseif msg == "show" then
    mod.gui.ShowMainFrame()
  elseif msg == "hide" then
    mod.gui.HideMainFrame()
  elseif msg == "rl" or msg == "reload" then
    ReloadUI()
  end
end

--[[
  Setup slash command handler
]]--
function me.SetupSlashCmdList()
  -- capture the built-in "/gm" handler (e.g. GM ticket window) before we
  -- register our own, so bare "/gm" still opens it as normal
  local existingGmHandler = FindExistingGmHandler()

  SLASH_GEARMENU1 = "/gearmenu"

  SlashCmdList["GEARMENU"] = function(msg)
    mod.logger.LogDebug(me.tag, "/gearmenu passed argument: " .. msg)
    HandleGearMenuCommand(msg)
  end

  -- registered as its own separate command (not shared with /gearmenu)
  -- so a bare "/gm" can still be told apart from a bare "/gearmenu"
  SLASH_GEARMENUGM1 = "/gm"

  SlashCmdList["GEARMENUGM"] = function(msg)
    mod.logger.LogDebug(me.tag, "/gm passed argument: " .. msg)

    if msg == "" and existingGmHandler then
      existingGmHandler(msg)
    else
      HandleGearMenuCommand(msg)
    end
  end
end
