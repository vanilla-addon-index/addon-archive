pfUI:RegisterModule("meters-options", "vanilla", function ()
  -- pfUI Octo :: the Meters section (user, 22 Oct 2026, Details! as the
  -- model: "a preview in UI able to add windows and set them up, change the
  -- looks, everything"). Details! is All Rights Reserved: only its option
  -- names were read. Three pages in place of pfUI's Meters pages (hidden):
  --   Windows  a tab per window (+ New window, Remove), a pinned preview of
  --            the window on a made-up fight, looks, and cards for what it
  --            shows, the window, the title bar, the bars and the texts
  --   Data     what is tracked and kept
  --   Threat   the threat meter
  -- The preview is a real meter window (meters-window.lua CreateWindow with
  -- pv); each part opens its card, the grip sets its size, Shift + wheel
  -- over the bars / title sets their height.
  local M = pfUI.meters
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not M or not M.S or not W or not O or not O.AddPage then return end
  local PfChk, PfSld = O.PfChk, O.PfSld

  local MO = { cur = 1 }
  pfUI.metersOcto = MO

  local function S() return C.meters["win" .. MO.cur] end
  local function G() return C.meters end
  local function Px(v) return v .. " px" end
  local function Pct(v) return math.floor(v * 100 + .5) .. "%" end
  local function Pct2(v) return math.floor(v + .5) .. "%" end
  local function Reload() if pfUI.gui then pfUI.gui.settingChanged = true end end

  function MO.Apply()
    M.RestyleAll()
    if MO.preview then MO.Sync() end
  end
  local Up = function() MO.Apply() end

  local function Chk(p, label, desc, group, key, after) return PfChk(p, label, desc, group, key, after or Up) end
  local function Sld(p, label, desc, min, max, step, group, key, fmt, after) return PfSld(p, label, desc, min, max, step, group, key, after or Up, fmt) end
  local function Drop(p, label, desc, options, group, key, after)
    return W.Dropdown(p, label, desc, options, function() return group()[key] end, function(v)
      group()[key] = v
      ;(after or Up)()
    end)
  end
  local function Color(p, label, desc, group, key, after)
    return W.Color(p, label, desc, function()
      local r, g, b, a = GetStringColor(group()[key] or "1,1,1,1")
      return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
    end, function(r, g, b, a)
      group()[key] = string.format("%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1)
      ;(after or Up)()
    end)
  end
  local function List(pairs2)
    local out = {}
    for _, e in ipairs(pairs2) do table.insert(out, { key = e[1], label = e[2] }) end
    return out
  end
  local function Textures()
    local out = {}
    local list = pfUI.gui and pfUI.gui.dropdowns and pfUI.gui.dropdowns.uf_bartexture
    if type(list) == "function" then list = list() end
    for _, e in ipairs(list or {}) do
      local _, _, k, l = string.find(e, "^(.-):(.*)$")
      if k then table.insert(out, { key = k, label = l, texture = k }) end
    end
    return out
  end
  local function Fonts()
    local out = { { key = "", label = "Unit frame font" } }
    for _, f in ipairs(W.Fonts and W.Fonts() or {}) do table.insert(out, { key = f.key, label = f.label, font = f.key }) end
    return out
  end
  local function Modes()
    local out = {}
    for _, m in ipairs(M.MODES or {}) do table.insert(out, { key = m.key, label = m.name }) end
    return out
  end

  -- ---------------------------------------------------------------- preview

  -- what a click on each part opens
  MO.GO = { title = "Title bar", buttons = "Title bar", bars = "Bars", name = "Texts", value = "Texts",
    window = "Window", shows = "Shows", status = "Status bar" }
  function MO.Open(part)
    local title = MO.GO[part] or "Window"
    if pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection("mtwindows", title) else O:Open("mtwindows") end
  end
  M.PreviewClick = function(win, part) MO.Open(part) end
  M.PreviewSized = function(win) MO.Apply() end

  -- the preview window follows the chosen window's settings
  function MO.Sync()
    local pw = MO.preview
    if not pw then return end
    local s = S()
    pw.cfg = MO.cur
    pw.mode = s.mode or "damage"
    pw.segment = "current"
    M.ApplyStyle(pw)
    local w, h = tonumber(s.width) or 260, tonumber(s.height) or 160
    if not pw.psize then
      pw:SetWidth(w)
      pw:SetHeight(h)
    end
    -- fits the box (the window keeps its own size; the view scales)
    local box = MO.box
    local k = math.min(1.6, ((box:GetWidth() or 600) - 20) / w, ((box:GetHeight() or 200) - 30) / h)
    pw:SetScale(math.max(.4, k))
    pw:ClearAllPoints()
    pw:SetPoint("CENTER", box, "CENTER", 0, -6 / math.max(.4, k))
    pw:Show()
    pw:SetAlpha(1)
    pw.Refresh(pw)
    MO.Spots()
  end

  -- spots over the bar texts (the bars themselves open Bars)
  MO.spots = {}
  local function Spot(i, part)
    local key = i .. part
    local h = MO.spots[key]
    if h then return h end
    h = CreateFrame("Button", nil, MO.preview)
    h:SetFrameLevel(MO.preview:GetFrameLevel() + 12)
    h.part = part
    h.hl = h:CreateTexture(nil, "OVERLAY")
    h.hl:SetAllPoints(h)
    h.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
    local ar, ag, ab = .2, .55, .9
    if GetAccentColor then ar, ag, ab = GetAccentColor() end
    h.hl:SetVertexColor(ar, ag, ab, .3)
    h.hl:Hide()
    h:SetScript("OnEnter", function()
      this.hl:Show()
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:AddLine(this.part == "name" and "Name (and rank number)" or "Value: total, per second, percent")
      GameTooltip:AddLine("Click: its settings", 1, 1, 1)
      GameTooltip:Show()
    end)
    h:SetScript("OnLeave", function() this.hl:Hide() GameTooltip:Hide() end)
    h:SetScript("OnClick", function() MO.Open(this.part) end)
    MO.spots[key] = h
    return h
  end
  function MO.Spots()
    local pw = MO.preview
    if not pw then return end
    for i, b in ipairs(pw.bars) do
      for _, e in ipairs({ { b.left, "name", "LEFT" }, { b.right, "value", "RIGHT" } }) do
        local h = Spot(i, e[2])
        local fs = e[1]
        local w = fs:GetStringWidth() or 0
        if b:IsShown() and w > 0 then
          local _, size = fs:GetFont()
          h:ClearAllPoints()
          h:SetWidth(math.min(w, fs:GetWidth() or w) + 4)
          h:SetHeight((tonumber(size) or 10) + 2)
          h:SetPoint(e[3], fs, e[3], e[3] == "LEFT" and -2 or 2, 0)
          h:Show()
        else
          h:Hide()
        end
      end
    end
  end

  -- Shift + wheel over the window: bar height (over the title: its height)
  local function Wheel()
    local s = S()
    if IsShiftKeyDown() then
      local key = MouseIsOver(MO.preview.head and MO.preview.titlebtn) and "titleheight" or "barheight"
      local v = (tonumber(s[key]) or 16) + (arg1 or 0)
      s[key] = tostring(math.max(8, math.min(40, v)))
      MO.Apply()
    elseif pfUI.plates and pfUI.plates.PassWheel then
      pfUI.plates.PassWheel(MO.box)
    end
  end

  local function Preview(p)
    W.Pin(p, "Preview", "The chosen window with your settings, on a made-up fight. Pick a window with the tabs. Click any "
      .. "part for its settings; drag the corner grip to size it; hold Shift and scroll over the bars (or the title) to "
      .. "change their height. Click this bar to fold it away.", function(p)
      -- the windows as tabs, and New / Remove
      local row = W.Row(p, 24, 0, 4)
      MO.tabs = {}
      for i = 1, M.MAXWIN do
        local b = W.Button(row, "Window " .. i, 92, 22)
        b:SetPoint("LEFT", row, "LEFT", (i - 1) * 96, 0)
        b.n = i
        b:SetScript("OnClick", function()
          MO.cur = this.n
          MO.Apply()
          O:Refresh()
        end)
        MO.tabs[i] = b
      end
      local new = W.Button(row, "+ New window", 108, 22)
      new:SetPoint("LEFT", row, "LEFT", M.MAXWIN * 96 + 4, 0)
      new:SetScript("OnClick", function()
        local w = M.AddWindow()
        if w then MO.cur = w.id end
        MO.Apply()
        O:Refresh()
      end)
      W.Tip(new, "New window", "Adds a meter window (up to " .. M.MAXWIN .. "). It floats: move it with Move frames or its title bar.")
      MO.newBtn = new
      -- (user, 24 Oct 2026: at the top, whichever window is being changed)
      local row2 = W.Row(p, 24, 0, 4)
      local match = W.Button(row2, "Match all windows to this one", 230, 22)
      match:SetPoint("LEFT", row2, "LEFT", 0, 0)
      match:SetScript("OnClick", function()
        local n = M.MatchAll and M.MatchAll(MO.cur) or 0
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r meters: " .. n .. " " .. (n == 1 and "window" or "windows")
          .. " now " .. (n == 1 and "has" or "have") .. " the size and look of window " .. MO.cur .. ".")
      end)
      W.Tip(match, "Match all windows to this one", "Every other meter window takes this window's size and look - bars, "
        .. "fonts, colours, title bar, buttons. What each one shows (damage, threat...) stays its own.")
      MO.matchBtn = match
      local box = W.Box(p, 210)
      MO.box = box
      -- the preview window, a real one
      local pw = M.CreateWindow(MO.cur, { parent = box, cfg = MO.cur })
      MO.preview = pw
      pw:EnableMouseWheel(true)
      pw:SetScript("OnMouseWheel", Wheel)
      -- the window's background opens Window
      local bgspot = CreateFrame("Button", nil, pw)
      bgspot:SetAllPoints(pw)
      bgspot:SetFrameLevel(pw:GetFrameLevel())
      bgspot:SetScript("OnClick", function() MO.Open("window") end)
      bgspot:EnableMouseWheel(true)
      bgspot:SetScript("OnMouseWheel", Wheel)
      -- the status bar opens its card
      if pw.status then
        local stspot = CreateFrame("Button", nil, pw.status)
        stspot:SetAllPoints(pw.status)
        stspot:SetFrameLevel(pw.status:GetFrameLevel() + 2)
        stspot:SetScript("OnClick", function() MO.Open("status") end)
        stspot:SetScript("OnEnter", function()
          GameTooltip:SetOwner(this, "ANCHOR_TOP")
          GameTooltip:AddLine("Status bar")
          GameTooltip:AddLine("Click: its settings", 1, 1, 1)
          GameTooltip:Show()
        end)
        stspot:SetScript("OnLeave", function() GameTooltip:Hide() end)
        MO.statusSpot = stspot
      end
      local cap = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      cap:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -6)
      cap:SetTextColor(.6, .6, .6)
      MO.cap = cap
      table.insert(p.items, { Refresh = function()
        local n = table.getn(M.windows)
        if MO.cur > n then MO.cur = n end
        for i, b in ipairs(MO.tabs) do
          if i <= n then b:Show() else b:Hide() end
          W.Pick(b, i == MO.cur)
        end
        if n >= M.MAXWIN then MO.newBtn:Hide() else MO.newBtn:Show() end
        local s = S()
        local where = "floating"
        cap:SetText("Window " .. MO.cur .. " (" .. where .. "), shown on a made-up fight  -  " .. (s.width or "?") .. " x " .. (s.height or "?"))
        MO.Sync()
      end })
      -- texts' spots follow the words
      box:SetScript("OnUpdate", function()
        if (this.tick or 0) > GetTime() then return end
        this.tick = GetTime() + .3
        MO.Spots()
      end)
      local band = W.Row(p, 20, 0, 3)
      local bg = band:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints(band)
      bg:SetTexture("Interface\\Buttons\\WHITE8X8")
      local ar, ag, ab = .2, .55, .9
      if GetAccentColor then ar, ag, ab = GetAccentColor() end
      bg:SetVertexColor(ar, ag, ab, .22)
      local how = band:CreateFontString(nil, "OVERLAY")
      how:SetFont(W.UIFont(), 11, "OUTLINE")
      how:SetPoint("LEFT", band, "LEFT", 12, 0)
      local k = string.format("|cff%02x%02x%02x", math.floor(ar * 255), math.floor(ag * 255), math.floor(ab * 255))
      how:SetText(k .. "Click|r a part  its settings     " .. k .. "Drag|r the corner grip  size     " .. k .. "Shift + wheel|r  bar / title height     "
        .. k .. "Move frames|r  move windows")
      W.HowTo(p, band, how:GetText())
    end)
  end

  -- the looks, three to a row; the one in use is lit
  local function Looks(p)
    local btns, rows = {}, {}
    local n = table.getn(M.LOOKS)
    for r = 1, math.ceil(n / 3) do rows[r] = W.Row(p, 24, 0, 6) end
    local function Paint()
      local cur = M.CurrentLook({ cfg = MO.cur })
      for _, b in ipairs(btns) do W.Pick(b, b.key == cur) end
    end
    for i, l in ipairs(M.LOOKS) do
      local b = W.Button(rows[math.floor((i - 1) / 3) + 1], l[2], 200, 22)
      b:SetPoint("LEFT", b:GetParent(), "LEFT", math.mod(i - 1, 3) * 206, 0)
      b.key = l[1]
      b:SetScript("OnClick", function()
        M.ApplyLook({ cfg = MO.cur }, this.key)
        Paint()
        MO.Apply()
        O:Refresh()
      end)
      W.Tip(b, l[2], "Background, border, title bar, bar texture, spacing and icons of this window in one click.")
      btns[i] = b
    end
    table.insert(p.items, { Refresh = Paint })
    Paint()
  end

  -- ---------------------------------------------------------------- windows page

  local BORDERS = { { "pfui", "pfUI's thin line" }, { "none", "None" }, { "gold", "Gold" }, { "accent", "Accent colour" },
    { "glow", "Soft glow (accent)" }, { "custom", "Own colour" } }
  local AUTOHIDE = { { "never", "Always shown" }, { "outofcombat", "Hide out of combat" }, { "incombat", "Hide in combat" } }
  local COLORBY = { { "class", "Class colour" }, { "fixed", "One colour" } }
  local GROW = { { "down", "Top to bottom" }, { "up", "Bottom to top" } }
  local ICONS = { { "class", "Class icon" }, { "none", "None" } }
  local OUTLINE = { { "OUTLINE", "Outline" }, { "THICKOUTLINE", "Thick outline" }, { "NONE", "None" } }
  local NAMECOLOR = { { "white", "White" }, { "class", "Class colour" } }

  local function BuildWindows(p)
    W.Heading(p, "Meter windows", { on = { function() return C.meters.hidden ~= "1" end, function(v) M.ShowAll(v) end, "Show or hide every meter window (the same as the meters button)." }, about = "Pick a window with the tabs (or make a new one), then its look. Every window has "
      .. "its own settings; the preview shows the one you are editing." })
    Preview(p)
    -- (user, 24 Oct 2026: a meter went off the screen, "a reset positions button")
    W.Card(p, "Where they are", { tip = "Lost a window off the screen? Reset puts it back." })
    W.Buttons(p, {
      { "Reset positions", function() if M.ResetPositions then M.ResetPositions() end end, 140,
        "Every meter window back to its starting place in the middle of the screen." },
      { "Move frames", function() if pfUI.unlock then pfUI.unlock:Show() end end, 120,
        "Layout mode: drag the meter windows (and everything else) where you want them." },
      { "Show / hide all", function() if M.ToggleAll then M.ToggleAll() end end, 120,
        "The same as clicking the meters button on your screen." },
    })
    W.Check(p, "Meters button on the screen", "A small button that shows or hides every meter window. Shift + drag "
      .. "moves it; right-click opens these options.", function() return C.meters.togglebtn ~= "0" end, function(v)
      C.meters.togglebtn = v and "1" or "0"
      if M.toggle then if v then M.toggle:Show() else M.toggle:Hide() end end
    end)
    -- (user, 23 Oct 2026: "a full test mode ... click on test bars in the
    -- meter and look at the extra frames with information")
    W.Card(p, "Test mode", { on = { function() return M.testOn and true or false end,
      function(v) if M.TestMode then M.TestMode(v) end end,
      "Every window shows a made-up Onyxia fight with everything a real one has. Click any bar for its breakdown." } })
    W.Live(p, function()
      if M.testOn then
        return "|cff55ff55On|r - every window shows a made-up 2 minute Onyxia fight. Click any bar: every name in the "
          .. "breakdown opens that player, enemy or spell. A real fight turns it off."
      end
      return "Off - switch it on to try every display and its breakdown without a fight (/pfmetertest)."
    end, 2)
    W.Buttons(p, {
      { "Open a breakdown", function()
        if M.TestMode and not M.testOn then M.TestMode(true) end
        local w = M.windows and M.windows[1]
        if not w then return end
        local rows = M.Rows(w.mode, w.segment)
        if rows[1] then M.ShowDetails(w, rows[1]) end
      end, 150, "Turns test mode on and opens the breakdown of window 1's top bar." },
    })
    W.Card(p, "Looks", { tip = "Ready-made looks for this window." })
    Looks(p)

    W.Card(p, "Shows", { tip = "What this window shows when it opens (its title bar changes it while playing)." })
    Drop(p, "Shows", nil, Modes(), S, "mode")
    Drop(p, "Fight", nil, List({ { "current", "Current fight" }, { "overall", "Overall" } }), S, "segment")

    W.Card(p, "Window", { tip = "Size, background, border, and how it shows in and out of combat." })
    Sld(p, "Width", "When it floats.", 150, 600, 1, S, "width", Px)
    Sld(p, "Height", "When it floats.", 60, 500, 1, S, "height", Px)
    Color(p, "Background", nil, S, "bg")
    Drop(p, "Border", nil, List(BORDERS), S, "border")
    Color(p, "Border colour", "For Own colour.", S, "bordercolor")
    Sld(p, "Opacity in combat", nil, .1, 1, .05, S, "alpha", Pct)
    Sld(p, "Opacity out of combat", nil, 0, 1, .05, S, "oocalpha", Pct)
    Drop(p, "Hide", nil, List(AUTOHIDE), S, "autohide")
    Chk(p, "Lock size and place", nil, S, "lock")

    W.Card(p, "Title bar", { tip = "The bar at the top: what it shows, its look and its buttons." })
    Chk(p, "Show the title bar", nil, S, "title")
    Sld(p, "Height", nil, 10, 40, 1, S, "titleheight", Px)
    Color(p, "Background", nil, S, "titlebg")
    Chk(p, "Title in the accent colour", nil, S, "titleaccent")
    Color(p, "Title colour", "When not in the accent colour.", S, "titlecolor")
    Sld(p, "Title size", nil, 8, 20, 1, S, "titlesize", Px)
    Chk(p, "Show the fight", "Its time and name beside the title.", S, "showseg")
    Chk(p, "Menu button", nil, S, "btnmenu")
    Chk(p, "Report button", nil, S, "btnreport")
    Chk(p, "Reset button", nil, S, "btnreset")
    Chk(p, "Padlock button", "Lock or unlock the window: unlocked, drag the title to move it and the corner to resize it.", S, "btnlock")

    W.Card(p, "Bars")
    Sld(p, "Height", nil, 8, 40, 1, S, "barheight", Px)
    Sld(p, "Spacing", nil, 0, 10, 1, S, "spacing", Px)
    Drop(p, "Texture", nil, Textures(), S, "texture")
    Drop(p, "Colour", nil, List(COLORBY), S, "colorby")
    Color(p, "One colour", nil, S, "barcolor")
    Sld(p, "Bar opacity", nil, .1, 1, .05, S, "baralpha", Pct)
    Color(p, "Behind the bars", "The empty part of each row.", S, "barbg")
    Drop(p, "Grow", nil, List(GROW), S, "grow")
    Drop(p, "Icon", nil, List(ICONS), S, "icons")
    Chk(p, "Rank numbers", nil, S, "rank")

    W.Card(p, "Texts", { tip = "The name on the left, the value on the right." })
    Drop(p, "Font", nil, Fonts(), S, "font")
    Sld(p, "Size", nil, 6, 20, 1, S, "fontsize", Px)
    Drop(p, "Outline", nil, List(OUTLINE), S, "outline")
    Chk(p, "Shadow", nil, S, "shadow")
    Drop(p, "Name colour", nil, List(NAMECOLOR), S, "namecolor")
    Drop(p, "Value", "The order of total, per second and percent.", List(M.ORDERS), S, "order")
    Chk(p, "Per second", nil, S, "showps")
    Chk(p, "Percent", nil, S, "showpct")
    Chk(p, "In brackets", nil, S, "brackets")

    W.Card(p, "Status bar", { tip = "A strip under the bars with three things of your choice (Details' status bar)." })
    Chk(p, "Show the status bar", nil, S, "status")
    Drop(p, "Left", nil, List(M.SLOTS), S, "statusleft")
    Drop(p, "Middle", nil, List(M.SLOTS), S, "statusmid")
    Drop(p, "Right", nil, List(M.SLOTS), S, "statusright")

    W.Card(p, "Share this look", { tip = "Copy this window's look as text to give to a friend, or paste one in. What the "
      .. "window shows, its fight and its lock are not part of it." })
    W.Edit(p, "This window's look", "Click, then Ctrl+A and Ctrl+C to copy.", function() return M.ExportLook({ cfg = MO.cur }) end,
      function() end)
    W.Edit(p, "Paste a look here", "Paste (Ctrl+V) and press Enter: this window takes it.", function() return "" end, function(v)
      local n = M.ImportLook({ cfg = MO.cur }, v)
      if n > 0 then
        MO.Apply()
        O:Refresh()
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI Octo|r: window " .. MO.cur .. " took " .. n .. " settings of the look.")
      elseif v and v ~= "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI Octo|r: that is not a meter look (it starts with OCTOMETER1:).")
      end
    end)

    W.Card(p, "Remove this window")
    W.Buttons(p, { { "Remove window", function()
      if MO.cur <= 1 then return end
      CreateQuestionDialog("Remove meter window " .. MO.cur .. "?", function()
        M.RemoveWindow(MO.cur)
        MO.cur = math.max(1, MO.cur - 1)
        MO.Apply()
        O:Refresh()
      end)
    end } })
  end

  -- ---------------------------------------------------------------- data, threat


  local function BuildData(p)
    W.Heading(p, "Meter data", { about = "What the meters track and keep." })
    W.Card(p, "Meters")
    Chk(p, "Use the meters", "After a reload.", G, "enable", Reload)
    Chk(p, "Ask to reset in a new instance", nil, G, "resetask", function() end)
    W.Card(p, "Tracking")
    Chk(p, "Merge pets into their owner", nil, G, "mergepets", function() M.who = {} end)
    Chk(p, "Everyone nearby (battlegrounds)", nil, G, "trackall", function() M.who = {} end)
    Drop(p, "Fights kept", nil, List({ { "5", "5" }, { "10", "10" }, { "20", "20" }, { "30", "30" } }), G, "history", function() end)
    W.Card(p, "Fights", { tip = "How fights are kept and timed, as in Details!." })
    Chk(p, "Merge trash", "Trash fights in a row become one \"Trash\" fight; boss fights stay apart.", G, "mergetrash", function() end)
    Chk(p, "Switch to the new fight", "When a fight starts, windows showing an earlier one show it.", G, "autocurrent", function() end)
    Drop(p, "Per second over", "Active: each player's own active time (Details' activity). Whole fight: the fight's length "
      .. "(Details' effective time).", List({ { "active", "Active time" }, { "effective", "Whole fight" } }), G, "timemeasure", Up)
    Chk(p, "Do not keep trash fights", "Only boss fights stay in the list (the overall still counts the trash).", G, "erasetrash", function() end)
    W.Card(p, "Numbers, reports and tooltips")
    Drop(p, "Numbers", nil, List({ { "short", "Short (12.3k)" }, { "comma", "With commas (12,345)" }, { "full", "In full (12345)" } }),
      G, "numformat", Up)
    Drop(p, "Report lines", "How many players a report sends.", List({ { "5", "5" }, { "10", "10" }, { "15", "15" }, { "20", "20" }, { "25", "25" } }),
      G, "reportlines", function() end)
    Chk(p, "Tooltips on the bars", nil, G, "tooltip", function() end)
    Drop(p, "Tooltip lines", nil, List({ { "5", "5" }, { "8", "8" }, { "12", "12" }, { "20", "20" } }), G, "tooltiplines", function() end)
    Chk(p, "Windows snap together", "A window dropped near another sits flush against it.", G, "snap", function() end)

    -- custom displays (Details' custom tab, without code)
    W.Card(p, "Custom displays", { tip = "Your own displays: one spell's damage, healing, casts or damage taken, or one buff's "
      .. "or debuff's uptime, per player. They show under Custom in a window's title menu once a spell is set." })
    for i = 1, 5 do
      local n = i
      local function CU() return C.meters["custom" .. n] end
      local function Changed() if M.CustomNames then M.CustomNames() end MO.Apply() end
      W.Edit(p, "Display " .. n .. ": name", "Leave empty to use the spell's name.", function() return CU().name or "" end,
        function(v) CU().name = v or "" Changed() end)
      Drop(p, "Display " .. n .. ": shows", nil, List(M.CUSTOMKINDS or {}), CU, "kind", Changed)
      W.Edit(p, "Display " .. n .. ": spell or aura", "Exactly as the game writes it, e.g. Sunder Armor.",
        function() return CU().spell or "" end, function(v) CU().spell = v or "" Changed() end)
    end
  end

  -- ---------------------------------------------------------------- threat
  -- (moved from OctoBG's "Threat label" page, 23 Oct 2026, and added to)

  -- the preview: a made-up nameplate with the label as you set it, going
  -- through safe, near your cap, past it and aggro. The label can be dragged
  -- (Across / Up-down), Shift + wheel sizes its text, right-click puts it back.
  local function ThreatPreview(p)
    local TH = M.threat
    W.Pin(p, "Preview", "A nameplate with your threat label, going through safe, near your cap, past it and aggro. "
      .. "Click the label or the plate for their settings, drag the label to move it.", function(pp)
      local box = (W.ZoomBox or W.Box)(pp, 120)
      local holder = CreateFrame("Frame", nil, box)
      holder:SetAllPoints(box)
      holder:SetFrameStrata("FULLSCREEN")
      -- the mock plate: name over the health bar, one frame like a real plate,
      -- so "above" sits over the name as it does in game
      local plate = CreateFrame("Button", nil, holder)
      plate:SetWidth(150)
      plate:SetHeight(28)
      plate:SetPoint("CENTER", box, "CENTER", 0, -8)
      plate.bar = plate:CreateTexture(nil, "ARTWORK")
      plate.bar:SetTexture(pfUI.media["img:bar"] or "Interface\\Buttons\\WHITE8X8")
      plate.bar:SetPoint("BOTTOMLEFT", plate, "BOTTOMLEFT")
      plate.bar:SetWidth(110)
      plate.bar:SetHeight(12)
      plate.bar:SetVertexColor(.8, .15, .15)
      plate.bg = plate:CreateTexture(nil, "BACKGROUND")
      plate.bg:SetPoint("BOTTOMLEFT", plate, "BOTTOMLEFT")
      plate.bg:SetPoint("BOTTOMRIGHT", plate, "BOTTOMRIGHT")
      plate.bg:SetHeight(12)
      plate.bg:SetTexture(0, 0, 0, .7)
      plate.name = plate:CreateFontString(nil, "OVERLAY")
      plate.name:SetFont(pfUI.font_default, 11, "OUTLINE")
      plate.name:SetPoint("BOTTOM", plate, "BOTTOM", 0, 15)
      plate.name:SetText("Onyxia's Elite Guard")
      plate:SetScript("OnClick", function() MO.OpenThreat("Label") end)
      plate:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:AddLine("Your target's nameplate")
        GameTooltip:AddLine("Click: the label's settings", 1, 1, 1)
        GameTooltip:Show()
      end)
      plate:SetScript("OnLeave", function() GameTooltip:Hide() end)
      local caption = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      caption:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -6)
      caption:SetTextColor(.6, .6, .6)
      local l = TH and TH.NewLabel(holder) or nil

      local function Place()
        l:ClearAllPoints()
        if C.meters.twhere == "screen" then
          l:SetPoint("BOTTOM", box, "BOTTOM", 0, 6)
        else
          local pt = TH.POINTS[C.meters.twhere] or TH.POINTS.above
          l:SetPoint(pt[1], plate, pt[2], tonumber(C.meters.tx) or 0, tonumber(C.meters.ty) or 0)
        end
      end
      local function Clamp(v, lo, hi) return tostring(math.max(lo, math.min(hi, math.floor(v + .5)))) end

      if l then
        l:SetFrameStrata("FULLSCREEN")
        l:SetFrameLevel(holder:GetFrameLevel() + 5)
        l:EnableMouse(true)
        l:EnableMouseWheel(true)
        l.hl = l:CreateTexture(nil, "BACKGROUND")
        l.hl:SetAllPoints(l)
        l.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
        local ar, ag, ab = .2, .55, .9
        if GetAccentColor then ar, ag, ab = GetAccentColor() end
        l.hl:SetVertexColor(ar, ag, ab, .25)
        l.hl:Hide()
        l:SetScript("OnEnter", function()
          this.hl:Show()
          GameTooltip:SetOwner(this, "ANCHOR_TOP")
          GameTooltip:AddLine("Threat label")
          GameTooltip:AddLine("Click: its settings", 1, 1, 1)
          if C.meters.twhere == "screen" then
            GameTooltip:AddLine("It sits in its own box: move that with Move frames", 1, 1, 1)
          else
            GameTooltip:AddLine("Drag: move it", 1, 1, 1)
          end
          GameTooltip:AddLine("Shift + mouse wheel: text size", 1, 1, 1)
          GameTooltip:AddLine("Right-click: put it back", 1, 1, 1)
          GameTooltip:Show()
        end)
        l:SetScript("OnLeave", function() this.hl:Hide() GameTooltip:Hide() end)
        l:SetScript("OnMouseDown", function()
          if arg1 == "RightButton" or C.meters.twhere == "screen" then return end
          local cx, cy = GetCursorPosition()
          this.down = { cx, cy, tonumber(C.meters.tx) or 0, tonumber(C.meters.ty) or 0 }
          this.moved = nil
        end)
        -- dragging runs in the holder's OnUpdate (the label's own is TH's)
        l:SetScript("OnMouseUp", function()
          if arg1 == "RightButton" then
            C.meters.tx, C.meters.ty, C.meters.tsize = "0", "2", "13"
            Place()
            O:Refresh()
            return
          end
          local moved = this.moved
          this.down, this.moved = nil, nil
          if moved then O:Refresh() else MO.OpenThreat("Label") end
        end)
        l:SetScript("OnMouseWheel", function()
          if IsShiftKeyDown() then
            C.meters.tsize = Clamp((tonumber(C.meters.tsize) or 13) + (arg1 or 0), 8, 30)
            holder.t = 0
            O:Refresh()
          elseif pfUI.plates and pfUI.plates.PassWheel then
            pfUI.plates.PassWheel(this)
          end
        end)
      end
      MO.threatPreview = { plate = plate, label = l, caption = caption, holder = holder }
      local STEPS = { { "safe", 45 }, { "near your cap", nil }, { "past your cap", 120 }, { "you have aggro" } }
      holder:SetScript("OnUpdate", function()
        if not l then return end
        local d = l.down
        if d then
          local x, y = GetCursorPosition()
          local k = box:GetEffectiveScale() or 1
          local dx, dy = (x - d[1]) / k, (y - d[2]) / k
          if l.moved or math.abs(dx) + math.abs(dy) >= 3 then
            l.moved = true
            C.meters.tx = Clamp(d[3] + dx, -150, 150)
            C.meters.ty = Clamp(d[4] + dy, -100, 100)
            Place()
          end
        end
        if (this.t or 0) > GetTime() then return end
        this.t = GetTime() + .25
        local step = math.mod(math.floor(GetTime() / 2.5), 4) + 1
        local limit = tonumber(C.meters.threatwarn) or 90
        local j
        if step == 4 then j = TH.SampleJudge(nil, true)
        elseif step == 2 then j = TH.SampleJudge(limit * ((tonumber(C.meters.tnear) or 80) + 8) / 100)
        else j = TH.SampleJudge(STEPS[step][2] / 100 * limit) end
        caption:SetText("Now: " .. STEPS[step][1] .. "   -   " .. TH.CapText())
        if C.meters.tlabel ~= "1" or C.meters.tlook == "none" then l:Hide() return end
        Place()
        TH.Paint(l, j)
        l:Show()
      end)

      -- how to use it, on screen
      local band = W.Row(pp, 20, 0, 3)
      local bg = band:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints(band)
      bg:SetTexture("Interface\\Buttons\\WHITE8X8")
      local ar, ag, ab = .2, .55, .9
      if GetAccentColor then ar, ag, ab = GetAccentColor() end
      bg:SetVertexColor(ar, ag, ab, .22)
      local how = band:CreateFontString(nil, "OVERLAY")
      how:SetFont(W.UIFont(), 11, "OUTLINE")
      how:SetPoint("LEFT", band, "LEFT", 12, 0)
      local k = string.format("|cff%02x%02x%02x", math.floor(ar * 255), math.floor(ag * 255), math.floor(ab * 255))
      how:SetText(k .. "Click|r the label  its settings     " .. k .. "Drag|r  move it     " .. k .. "Shift + wheel|r  text size     "
        .. k .. "Right-click|r  put back")
      W.HowTo(pp, band, how:GetText())
    end)
  end

  function MO.OpenThreat(card)
    if pfUI.plates and pfUI.plates.OpenSection then pfUI.plates.OpenSection("mtthreat", card) else O:Open("mtthreat") end
  end

  local function BuildThreat(p)
    local TH = M.threat
    W.Heading(p, "Threat", { on = O.KeySwitch(function() return C.meters end, "threat", "Ask the server for threat on or off (takes a reload).", function() pfUI.gui.settingChanged = true end), about = "Your threat on the mob you target, from the server (the same answers TWThreat shows): "
      .. "only in a party or raid, on a mob in combat. A label by your target's nameplate turns yellow near your cap and red "
      .. "past it, a popup and a sound can warn you, and a meter window can show everyone's threat." })
    if not TH then
      W.Card(p, "Threat")
      Chk(p, "Threat meter", "After a reload.", G, "threat", Reload)
      return
    end
    ThreatPreview(p)
    W.Live(p, function() return "Status: " .. TH.StatusLine() end)
    W.Buttons(p, {
      { "Sample on my target (8 s)", function() if TH.sampleUntil and GetTime() < TH.sampleUntil then TH.sampleUntil = 0 else TH.Sample(8) end end,
        nil, "Your threat label shows a made-up reading on your target for 8 seconds. Click again to stop.",
        on = function() return TH.sampleUntil and GetTime() < TH.sampleUntil end },
      { "Test the popup", function() TH.Alert(C.meters.threatpopup or "THREAT", 1, .25, .2) TH.Sound() end, nil, nil,
        on = function() return pfThreatAlert and pfThreatAlert:IsShown() end },
      { "Open a threat window", function()
        local w = M.AddWindow()
        if w then M.SetMode(w, "threat") end
      end, nil, nil, on = function()
        for _, w in ipairs(M.windows or {}) do if w.mode == "threat" and w:IsShown() then return true end end
      end },
    })

    W.Card(p, "Threat meter", { tip = "Asking the server for threat. Off: no label, no popups, no threat window." })
    Chk(p, "Ask the server for threat", "After a reload.", G, "threat", Reload)

    W.Card(p, "Your cap", { tip = "How much threat you allow yourself before the label turns red and the popup shouts." })
    Sld(p, "Stay under", "Your threat as a share of the reference below.", 10, 150, 5, G, "threatwarn", Pct2, function() end)
    Drop(p, "...of", "The pull point: where the mob turns to you (110% of the tank's threat in melee, 130% at range). "
      .. "The top player: stay behind the tank; the top two or three: behind the off-tank or a big hitter too.",
      List(TH.REFS), G, "threatref", function() end)
    Sld(p, "Yellow from", "The label turns yellow at this share of your cap.", 50, 95, 5, G, "tnear", Pct2, function() end)
    W.Buttons(p, {
      { "Safe 70%", function() C.meters.threatwarn, C.meters.threatref = "70", "1" O:Refresh() end,
        on = function() return C.meters.threatwarn == "70" and C.meters.threatref == "1" end },
      { "Push 90%", function() C.meters.threatwarn, C.meters.threatref = "90", "1" O:Refresh() end,
        on = function() return C.meters.threatwarn == "90" and C.meters.threatref == "1" end },
      { "Edge 100%", function() C.meters.threatwarn, C.meters.threatref = "100", "1" O:Refresh() end,
        on = function() return C.meters.threatwarn == "100" and C.meters.threatref == "1" end },
    })

    W.Card(p, "Label", { tip = "The label by your target's nameplate (or in a box you place)." })
    Chk(p, "Show the label", nil, G, "tlabel", function() end)
    Drop(p, "Show it as", nil, List(TH.LOOKS), G, "tlook", function() end)
    Drop(p, "Where", "A box I place: move the \"Threat Box\" with Move frames.", List(TH.PLACES), G, "twhere", function() end)
    Sld(p, "Across", nil, -150, 150, 1, G, "tx", Px, function() end)
    Sld(p, "Up / down", nil, -100, 100, 1, G, "ty", Px, function() end)
    Sld(p, "Text size", nil, 8, 30, 1, G, "tsize", Px, function() end)
    Drop(p, "Outline", nil, List({ { "NONE", "None" }, { "OUTLINE", "Outline" }, { "THICKOUTLINE", "Thick outline" } }), G, "toutline", function() end)
    Chk(p, "With aggro: the next player", "\"Aggro  next 92%\" - for tanks.", G, "tnext", function() end)
    Chk(p, "...and their name", "\"Aggro  next Jaina 92%\".", G, "tnextname", function() end)

    W.Card(p, "Colours")
    Color(p, "Safe", nil, G, "tcolsafe", function() end)
    Color(p, "Near your cap", nil, G, "tcolnear", function() end)
    Color(p, "Past your cap", nil, G, "tcolover", function() end)
    Color(p, "Aggro", nil, G, "tcolaggro", function() end)

    W.Card(p, "Popups", { tip = "A big line in the middle of the screen, once each time you cross your cap." })
    Chk(p, "Shout when I pass my cap", nil, G, "threatflash", function() end)
    Chk(p, "Also when I pull aggro", "\"AGGRO!\" - tanks may want this off.", G, "threataggro", function() end)
    W.Edit(p, "Message", nil, function() return C.meters.threatpopup or "" end, function(v)
      if v and v ~= "" then C.meters.threatpopup = v end
    end)
    Chk(p, "Sound", nil, G, "threatsound", function() end)
    local CT = pfUI.sctB and pfUI.sctB.SCT
    local sounds = {}
    for _, s in ipairs(CT and CT.SOUNDS or { { key = "RaidWarning", label = "Raid warning" } }) do
      if s.key then table.insert(sounds, { key = s.key, label = s.label }) end
    end
    W.Dropdown(p, "Which sound", "Picking one plays it.", sounds, function() return C.meters.threatsoundkey end, function(v)
      C.meters.threatsoundkey = v
      if CT and CT.PlaySound then CT.PlaySound(v) end
    end)
  end

  O.replaced[T["Meters"]] = true
  O:AddPage("Meters", "mtwindows", "Windows", BuildWindows)
  O:AddPage("Meters", "mtdata", "Data", BuildData)
  O:AddPage("Meters", "mtthreat", "Threat", BuildThreat)
end)
