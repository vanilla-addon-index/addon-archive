pfUI:RegisterModule("sct", "vanilla", function ()
  -- pfUI Octo combat text: start-up and the "Combat Text" options pages.
  -- The engine is sct-engine.lua / sct-events.lua (moved from OctoBG) on the
  -- stand-in core sct-core.lua. Settings: pfUI_config.sct, real Lua values
  -- (booleans, numbers) as the engine expects; on first run copied from
  -- OctoBG's (OctoBGDB.sct) when there are any, then OctoBG hands its combat
  -- text over to this one (OctoBG checks pfUI.sct:On()).
  local B = pfUI.sctB
  local CT = B and B.SCT
  if not CT then return end

  -- ---------------------------------------------------------------- settings

  local function Copy(src)
    if type(src) ~= "table" then return src end
    local t = {}
    for k, v in pairs(src) do t[k] = Copy(v) end
    return t
  end

  local function Fill(dst, src)
    for k, v in pairs(src) do
      if type(v) == "table" then
        if type(dst[k]) ~= "table" then dst[k] = {} end
        Fill(dst[k], v)
      elseif dst[k] == nil then
        dst[k] = v
      end
    end
  end

  if type(pfUI_config.sct) ~= "table" then pfUI_config.sct = {} end
  Fill(pfUI_config.sct, B.DEFAULTS.sct)
  B.db = { sct = pfUI_config.sct, pos = {}, locked = true }

  -- OctoBG's combat text settings, copied once. OctoBG may load after pfUI
  -- (seen in game 19 Oct: its saved settings were not there yet at pfUI's
  -- load), so this runs at login, when every addon is loaded. The settings
  -- table stays the same table (B.db.sct). pfUI's on / off is kept.
  local function ImportOctoBG()
    local s = pfUI_config.sct
    if s.fromOctoBG or s.octoChecked then return end
    s.octoChecked = true
    if type(OctoBGDB) ~= "table" or type(OctoBGDB.sct) ~= "table" then return end
    local on = s.enabled
    for k in pairs(s) do s[k] = nil end
    for k, v in pairs(Copy(OctoBGDB.sct)) do s[k] = v end
    Fill(s, B.DEFAULTS.sct)
    s.enabled = on
    s.fromOctoBG, s.octoChecked = true, true
    if CT.panels then for key in pairs(CT.panels) do CT:PlaceArea(key) end end
  end

  pfUI.sct = { B = B, CT = CT }
  function pfUI.sct:On() return B.db and B.db.sct.enabled and not (C.disabled and C.disabled["sct"] == "1") end

  -- each step on its own: an error says so in chat and the rest (above all
  -- the options pages) still happens
  local function Try(what, fn)
    local ok, err = pcall(fn)
    if not ok then B:Print("|cffff5555error|r (" .. what .. "): " .. tostring(err)) end
  end
  pfUI.sct.Try = Try
  pfUI.sct.ImportOctoBG = ImportOctoBG

  Try("start-up", function()
  B:Fire("OBG_LOADED")

  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  f:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
      Try("import from OctoBG", ImportOctoBG)
      B:Fire("OBG_INIT")
      if pfUI_config.sct.fromOctoBG and not pfUI_config.sct.toldMoved then
        pfUI_config.sct.toldMoved = true
        B:Print("your OctoBG combat text settings were copied here - OctoBG now hands its combat text to pfUI. Options: /pfui, Combat Text.")
      end
    else
      B:Fire("OBG_ZONE")
    end
  end)

  -- sample texts in every area while pfUI's layout mode (/moveui) is open
  if pfUI.unlock then
    local show, hide = pfUI.unlock:GetScript("OnShow"), pfUI.unlock:GetScript("OnHide")
    pfUI.unlock:SetScript("OnShow", function() if show then show() end B.test = true end)
    pfUI.unlock:SetScript("OnHide", function() if hide then hide() end B.test = nil end)
  end

  -- SCT's /sctdisplay 'message' [red green blue 0-10] (when SCT itself is not loaded)
  local function Display(msg)
    local _, _, text, r, g, b = string.find(msg or "", "^%s*'(.-)'%s*(%d*)%s*(%d*)%s*(%d*)")
    if not text then text = msg end
    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    CT:Show(text, r and r / 10 or 1, g and g / 10 or 1, b and b / 10 or 1, "note", {})
  end
  if not (IsAddOnLoaded("sct") or IsAddOnLoaded("SCT")) then
    _G.SLASH_PFUISCTDISPLAY1 = "/sctdisplay"
    _G.SlashCmdList.PFUISCTDISPLAY = Display
  end

  -- /pfui sct test | on | off
  local slash = SlashCmdList.PFUI
  SlashCmdList.PFUI = function(msg, box)
    local _, _, sub = string.find(string.lower(msg or ""), "^sct%s*(%a*)")
    if sub then
      if sub == "test" then CT:TestMode(not CT:Testing())
      elseif sub == "on" then CT:SetEnabled(true)
      elseif sub == "off" then CT:SetEnabled(false)
      elseif sub == "status" then pfUI.sct.Status()
      else B:Print("/pfui sct test | on | off | status") end
      return
    end
    slash(msg, box)
  end
  end)

  -- /pfui sct status: what is running (for reports)
  function pfUI.sct.Status()
    local n = 0
    for _ in pairs(B.errors) do n = n + 1 end
    B:Print("on: " .. tostring(pfUI.sct:On()) .. ", areas: " .. tostring(CT.panels and CT.panels.inc ~= nil)
      .. ", options: " .. tostring(pfUI.octoui and pfUI.octoui.Options and pfUI.octoui.Options.BUILD.ctgeneral ~= nil)
      .. ", errors: " .. n)
    for err in pairs(B.errors) do B:Print("  " .. err) end
  end

end)
