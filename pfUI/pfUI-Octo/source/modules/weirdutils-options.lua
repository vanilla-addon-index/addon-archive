pfUI:RegisterModule("weirdutils-options", "vanilla", function ()
  -- pfUI Octo :: the WeirdUtils section (29 Oct 2026; user: "a menu in pfui
  -- that is for weirdutils ... control over everything utils brings world
  -- marker control etc"). WeirdUtils (codeberg.org/MarcelineVQ/WeirdUtils,
  -- public domain) is a client DLL; this page only calls the Lua API it
  -- registers (README of v0.7.1): GetWeirdUtilsVersion, WorldMarker /
  -- ClearWorldMarker / GetWorldMarker / CanSetWorldMarker, Set/GetCursorScale,
  -- the screenshotQuality CVar, GetCombatLogPath / GetChatLogPath and the
  -- minimap tracking table its embedded addon keeps
  -- (WeirdUtils_MinimapIconsSettings, the same table it reads) with
  -- WeirdUtils.SetObjectTypeBlip / SetMinimapCityToggle. Every call is
  -- guarded: without the DLL the page says how to get it.
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not W or not O or not O.AddPage then return end
  local WU = {}
  pfUI.weirdutils = WU

  local function Has(fn) return type(_G[fn]) == "function" end
  function WU.Loaded() return Has("GetWeirdUtilsVersion") end
  function WU.Version(mod)
    if not WU.Loaded() then return nil end
    -- (never through pcall: WeirdUtils functions crashed the client when called that way, 29 Oct 2026)
    return _G.GetWeirdUtilsVersion(mod)
  end

  -- what each module does, in the order the page lists them
  WU.MODULES = {
    { "worldmarkers", "World markers", "Five coloured markers on the ground, shared with your group." },
    { "minimapicons", "Minimap tracking", "Bankers, mailboxes, trainers, vendors and more on the minimap." },
    { "bigcursor", "Big cursor", "A larger, still sharp mouse cursor." },
    { "pngscreenshots", "PNG screenshots", "Screenshots saved as small PNG files instead of TGA." },
    { "logsessions", "Log sessions", "Combat and chat logs split per character and day." },
    { "clickthrough", "Smart clicking", "Clicks pick loot, objects and NPCs behind other units (not in battlegrounds)." },
    { "transmogfix", "Transmog fix", "Stops the frame drops when transmogged gear loses durability." },
    { "healtextfix", "Heal text fix", "Stops SuperWoW's doubled floating heal numbers." },
    { "customassets", "Loose Data files", "Models and textures from the Data folder without repacking MPQs." },
  }

  -- ---------------------------------------------------------- world markers
  WU.MARKS = {
    { "Blue square", "Place Blue Square", 0, .44, 1 },
    { "Green triangle", "Place Green Triangle", .2, 1, .2 },
    { "Purple diamond", "Place Purple Diamond", .8, .3, 1 },
    { "Red cross", "Place Red Cross", 1, .2, .2 },
    { "Yellow star", "Place Yellow Star", 1, .9, .1 },
  }
  function WU.Place(i, unit)
    if not Has("WorldMarker") then return end
    local ui = type(_G.WorldMarkers) == "table" and _G.WorldMarkers.UI_WorldMarker
    if ui then ui(i, unit) return end
    local x = _G.WorldMarker(i, unit)
    if x == nil then UIErrorsFrame:AddMessage("World markers: you must be the group leader or an assistant.", 1, .4, .2) end
  end
  function WU.Clear(i)
    if not Has("ClearWorldMarker") then return end
    local ui = type(_G.WorldMarkers) == "table" and _G.WorldMarkers.UI_ClearWorldMarker
    if ui then ui(i) elseif i then _G.ClearWorldMarker(i) else _G.ClearWorldMarker() end
  end
  function WU.MarkerText()
    if not Has("GetWorldMarker") then return "|cffff5555World markers are not loaded.|r" end
    local can = Has("CanSetWorldMarker") and _G.CanSetWorldMarker()
    local out = can and "|cff55ff55You can place markers.|r" or "|cffffcc00Only the group leader or an assistant can place markers - you still see theirs.|r"
    local on = {}
    for i, m in ipairs(WU.MARKS) do
      local x = _G.GetWorldMarker(i)
      if x then table.insert(on, string.format("|cff%02x%02x%02x%s|r", m[3] * 255, m[4] * 255, m[5] * 255, m[1])) end
    end
    if table.getn(on) > 0 then return out .. "\nOn the ground now: " .. table.concat(on, ", ") end
    return out .. "\nNo markers on the ground."
  end

  -- ------------------------------------------------------- minimap tracking
  -- the embedded addon's categories (MinimapIcons.lua). Vendor sub-kinds use
  -- name lists only that addon has, so those apply after a reload.
  local TR = "Interface\\Minimap\\Tracking\\"
  WU.TRACK = {
    { "Banker", "banker", "Banker" }, { "Auctioneer", "auctioneer", "Auctioneer" }, { "Repair", "repair", "Repair" },
    { "Mailbox", "mailbox", "Mailbox" }, { "Innkeeper", "innkeeper", "Innkeeper" }, { "Flight Master", "flightmaster", "FlightMaster" },
    { "Quest Available", "quest_available", "QuestAvailable" }, { "Stable Master", "stablemaster", "StableMaster" },
    { "Battle Master", "battlemaster", "BattleMaster" }, { "Oranges", "oranges", "Orange" },
    { "Brainwasher", "brainwasher", "Brainwasher", 1.8 }, { "General Vendor", "vendor", "Food" },
    { "Class Trainer", "trainer", "Class", nil, "class" }, { "Profession Trainer", "trainer", "Profession", nil, "prof" },
    { "Reagent Vendor", nil, "Reagents" }, { "Poison Vendor", nil, "Poison" },
    { "Trade Goods", nil, "Trade" }, { "Ammunition", nil, "Ammunition" },
  }
  function WU.TrackOn(name)
    local s = _G.WeirdUtils_MinimapIconsSettings
    return s and s[name] and true or false
  end
  function WU.SetTrack(t, on)
    local s = _G.WeirdUtils_MinimapIconsSettings
    if not s then return end
    s[t[1]] = on and 1 or nil
    local api = _G.WeirdUtils
    if not t[2] then WU.needReload = true return end
    if not (type(api) == "table" and api.SetObjectTypeBlip) then return end
    local inc, exc
    local cls = UnitClass("player")
    if t[5] == "class" then inc = cls elseif t[5] == "prof" then exc = cls end
    if on then api.SetObjectTypeBlip(t[2], TR .. t[3], t[4] or 1.5, inc, exc)
    else api.SetObjectTypeBlip(t[2], nil, nil, inc, exc) end
  end
  function WU.SetCityHide(on)
    local s = _G.WeirdUtils_MinimapIconsSettings
    if not s then return end
    s["City Toggle"] = on and 1 or nil
    local api = _G.WeirdUtils
    if type(api) == "table" and api.SetMinimapCityToggle then api.SetMinimapCityToggle(on and 1 or 0) end
  end

  -- ------------------------------------------------------------------ cvars
  local function CVar(name)
    local ok, v = pcall(GetCVar, name)
    if ok then return tonumber(v) end
  end
  local function SetCV(name, v) pcall(SetCVar, name, tostring(v)) end

  -- ------------------------------------------------------------------- page
  local function Build(p)
    W.Heading(p, "WeirdUtils", { about = "WeirdUtils is a client DLL (codeberg.org/MarcelineVQ/WeirdUtils) with world markers, "
      .. "minimap tracking, a big cursor, PNG screenshots, per-day logs and several fixes. This page controls all of it." })

    if not WU.Loaded() then
      W.Card(p, "Not installed", { tip = "WeirdUtils is not running in this game." })
      W.Note(p, "Close the game and run |cffffd100Install pfUI Octo DLLs.bat|r in the pfUI folder: it installs WeirdUtils "
        .. "(weirdutils_noperf.dll) and adds it to dlls.txt. Then start the game again.", 0, true)
      return
    end

    W.Card(p, "What is running", { tip = "Each part of WeirdUtils and whether this game loaded it." })
    W.Live(p, function()
      local lines = {}
      for _, m in ipairs(WU.MODULES) do
        local v = WU.Version(m[1])
        table.insert(lines, (v and "|cff55ff55ON|r  " or "|cffff5555OFF|r  ") .. m[2] .. (v and (" |cff888888v" .. v .. "|r") or "") .. " - |cffaaaaaa" .. m[3] .. "|r")
      end
      return table.concat(lines, "\n")
    end)

    W.Card(p, "World markers", { icon = "Interface\\Icons\\Ability_Hunter_MarkedForDeath",
      tip = "Leader or assistant: place a marker at your target, or bind keys to place one where the mouse points. Everyone in the group with WeirdUtils sees them." })
    W.Live(p, WU.MarkerText)
    for i, m in ipairs(WU.MARKS) do
      local n = i
      W.Buttons(p, {
        { m[1] .. ": on my target", function() WU.Place(n, "target") end, 190, "Puts the marker under your target." },
        { "On me", function() WU.Place(n, "player") end, 90, "Puts the marker where you stand." },
        { "Remove", function() WU.Clear(n) end, 90, "Takes this marker away." },
      })
    end
    W.Buttons(p, { { "Remove all markers", function() WU.Clear() end, 190, "Takes every marker away." } })
    local MB = pfUI.markbar
    if MB then
      W.Check(p, "Marker bar on screen", "A small bar with the five marks: left-click = on you, right-click then click the ground = "
        .. "there, Shift-click = remove. Drag it to move it.",
        function() return C.weirdutils.bar == "1" end, function(v) C.weirdutils.bar = v and "1" or "0" MB.Apply() end)
      W.Check(p, "Lock the bar", "It stays where it is (Move Frames still moves it).",
        function() return C.weirdutils.lock == "1" end, function(v) C.weirdutils.lock = v and "1" or "0" end)
    end
    for _, m in ipairs(WU.MARKS) do
      W.KeyBind(p, m[1] .. " at the mouse", "Press the key with the mouse over the ground. Right-click the box to clear the key.", m[2])
    end
    W.KeyBind(p, "Remove all markers", nil, "Clear All Markers")

    if WU.Version("minimapicons") then
      W.Card(p, "Minimap tracking", { icon = "Interface\\Icons\\INV_Misc_Map_01",
        tip = "Which people and things show on the minimap. Saved for this character." })
      W.Check(p, "Hide in cities", "No tracking icons in capital cities (they fill the map there).",
        function() return WU.TrackOn("City Toggle") end, function(v) WU.SetCityHide(v) end)
      for _, t in ipairs(WU.TRACK) do
        local tt = t
        W.Check(p, tt[1], tt[2] and nil or "Applies after a reload.", function() return WU.TrackOn(tt[1]) end, function(v) WU.SetTrack(tt, v) end)
      end
      W.Buttons(p, { { "Reload now", function() ReloadUI() end, 130, "Applies the vendor kinds.", on = function() return WU.needReload end } })
    end

    local TB = pfUI.trackbutton
    if TB then
      W.Card(p, "Tracking button", { icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
        tip = "The round button that opens the tracking menu (find herbs, the people above)." })
      local function Up() TB.Apply() end
      W.Dropdown(p, "Where it goes", "On the map: where the game puts it. Free: put it anywhere with Move Frames. "
        .. "Addon bar: with your other addon buttons. Hidden: gone (the menu is then only on this page).",
        { { key = "map", label = "On the map" }, { key = "free", label = "Free - Move Frames" },
          { key = "bar", label = "In the addon button bar" }, { key = "hide", label = "Hidden" } },
        function() return C.weirdutils.track end, function(v) C.weirdutils.track = v Up() end)
      W.Check(p, "Gold ring", "Off: a square icon in pfUI's thin frame.",
        function() return C.weirdutils.track_border ~= "0" end, function(v) C.weirdutils.track_border = v and "1" or "0" Up() end)
      W.Slider(p, "Size", "0 = the game's own size.", 0, 64, 1,
        function() return tonumber(C.weirdutils.track_size) or 0 end, function(v) C.weirdutils.track_size = v Up() end,
        function(v) return v == 0 and "Game's" or (v .. " px") end)
    end

    if WU.Version("bigcursor") and Has("SetCursorScale") then
      W.Card(p, "Big cursor", { icon = "Interface\\Icons\\INV_Misc_Spyglass_02", tip = "1x = the normal cursor. Changes with the next cursor change." })
      W.Slider(p, "Cursor size", nil, 1, 4, .1,
        function() return tonumber(_G.GetCursorScale()) or 1 end,
        function(v) _G.SetCursorScale(v) end,
        function(v) return string.format("%.1fx", v) end)
    end

    if WU.Version("pngscreenshots") then
      W.Card(p, "Screenshots", { icon = "Interface\\Icons\\INV_Misc_Ticket_Tarot_Portal", tip = "Print Screen saves to the Screenshots folder." })
      W.Check(p, "Save as PNG", "Off: the game's own big TGA files.",
        function() return (CVar("screenshotQuality") or 6) > 0 end,
        function(v) SetCV("screenshotQuality", v and 6 or 0) end)
      W.Slider(p, "PNG squeeze", "1 = fastest, 9 = smallest files.", 1, 9, 1,
        function() local q = CVar("screenshotQuality") or 6 if q < 1 then q = 6 end return q end,
        function(v) SetCV("screenshotQuality", v) end)
      W.Buttons(p, { { "Take one now", function() Screenshot() end, 130 } })
    end

    W.Card(p, "Logs", { icon = "Interface\\Icons\\INV_Misc_Book_09",
      tip = "With Log sessions the files go to Logs\\<realm>\\<character>\\, one per day." })
    W.Check(p, "Write the combat log", "Turns the combat log file on (for log uploads).",
      function() return LoggingCombat() and true or false end, function(v) LoggingCombat(v and 1 or 0) end)
    W.Check(p, "Write the chat log", nil,
      function() return LoggingChat() and true or false end, function(v) LoggingChat(v and 1 or 0) end)
    W.Live(p, function()
      local c = Has("GetCombatLogPath") and _G.GetCombatLogPath()
      local t = Has("GetChatLogPath") and _G.GetChatLogPath()
      if not c and not t then return "|cffaaaaaaFiles: Logs\\WoWCombatLog.txt and Logs\\WoWChatLog.txt|r" end
      return "Combat log: |cffffd100" .. (c or "-") .. "|r\nChat log: |cffffd100" .. (t or "-") .. "|r"
    end)
  end

  O:AddPage("WeirdUtils", "weirdutils", "WeirdUtils", Build)
end)
