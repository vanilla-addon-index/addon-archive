-- pfQuest xpGuide: the settings window. Every option and every window of the addon in one place, so nothing needs a
-- slash command: six pages (Guides, Configuration, Auto mode, Helpers, Usage, Features) picked with the page buttons along the top (or
-- the sidebar with pfUI's look), each with its ticks and buttons. Guides is where a guide is picked: the groups on the left,
-- the guides of the group on the right. Usage and Features are text (Help.lua has the words), scrolled with the mouse wheel. The gear on the guide (step box or quest list) opens it, so does right-clicking the minimap button, or /xpg settings.

local ER = pfQuest_xpGuide
local GOLD, GREY, WHITE, END = ER.GOLD, ER.GREY, ER.WHITE, ER.END

local W = 640
local LEFT = 22                      -- the left edge of a page's words
local COL_W = math.floor((W - 44) / 2)   -- one of the two columns of ticks
local TOP_Y = -84                    -- where a page starts, under the title, the line about the guide and the page buttons
local S = { checks = {}, buttons = {}, tabs = {}, pages = {}, helpViews = {} }
-- With pfUI the window is laid out the way OctoPad's settings are: the pages picked from a sidebar on the left, the title in the
-- top left corner, each page under a small accent header (Theme.lua). S.side is the sidebar's width, S.top where a page starts.
local SIDE_W = 132
S.side, S.top = 0, TOP_Y
local function Themed() return ER.Skin and ER.Skin.On() end

local function Db() return ER.db or {} end

local function Running() return ER.Steps and ER.Steps.Running() end

local function Hide() if S.frame then S.frame:Hide() end end

-- A tick: label, is it on now, turn it on or off, and a short tooltip (tip). wide: the tick has a whole row; part: one of Auto mode's own
-- ticks (greyed while Auto mode is off). The toggles that already have their own function use it, so the chat line and the windows follow
-- as with the slash command. A button: label, what the tooltip says, what it does. note: a grey line under the ticks.
local PAGES = {
  { title = "Guides", head = "Pick a guide. Every guide for your faction, by level: the one that suits you now is gold.",
    guides = true, checks = {}, buttons = {} },
  { title = "Configuration", head = "Your guide, how hard it is and how it looks.",
    checks = {
      { "Lock the guide window",
        function() return Db().guideLocked end,
        function(on)
          Db().guideLocked = on and true or nil
          if ER.GuideFooterChanged then ER.GuideFooterChanged() end
        end,
        tip = "Keep the guide window where it is: no moving or resizing by mistake." },
      { "Go on to the next guide",
        function() return not Db().autoNextOff end,
        function(on) if ER.db then ER.db.autoNextOff = not on end end,
        tip = "When a guide ends, the next one starts by itself." },
      { "Ask every 3 levels how it goes",
        function() return not Db().checkinOff end,
        function(on) if ER.db then ER.db.checkinOff = not on end end,
        tip = "Every 3 levels: Too easy, About right or Too hard?" },
      { "Leave out money steps",
        function() return ER.HasMoney and ER.HasMoney() end,
        function(on) if ER.SetHasMoney then ER.SetHasMoney(on) end end,
        tip = "For when you have money on another character." },
    },
    -- the text size, set with two arrows and the size between them, as when splitting a stack in your bags
    stepper = { "Text size", "The size of the guide's text. Left is smaller, right is bigger.",
      "Follows pfQuest's quest tracker size until you change it. Click the number to follow pfQuest again." },
    buttons = {
      { "Change difficulty", "Casual, Medium or Hard.", function()
        Hide()
        if ER.ShowWizardMood then ER.ShowWizardMood() end
      end },
      { "Start guide again", "Back to step 1 of this guide.", function()
        local info = Running() and ER.Steps.Info()
        if info then ER.Steps.Load(ER.Steps.Key(info), true) end
        Hide()
      end },
      { "Stop the guide", "Close the guide. The Guides page starts one again.", function()
        if Running() then
          ER.Steps.Stop()
          ER.Print("guide stopped.")
        end
        Hide()
      end },
      { "Find my place", "Puts the guide back where your quest log says you are.", function()
        if ER.FindMyPlace then ER.FindMyPlace() end
        Hide()
      end },
    },
  },
  { title = "Character", head = "The experience rate of your server and your professions. The Fast guides use them to choose the steps.",
    checks = (function()
      local list = {
        { "1x experience",
          function() return ER.XPRate and ER.XPRate() == 1 end,
          function() if ER.SetXPRate then ER.SetXPRate(1) end end,
          section = "Experience rate",
          tip = "Normal rates. The Fast guides keep their extra quests." },
        { "2x experience",
          function() return ER.XPRate and ER.XPRate() == 2 end,
          function() if ER.SetXPRate then ER.SetXPRate(2) end end,
          tip = "Double experience. The Fast guides leave out the quests that a 1x server needs for the same levels." },
      }
      local function Prof(name, first, section, tip)
        table.insert(list, {
          name,
          function() return ER.HasProf and ER.HasProf(name) end,
          function(on) if ER.SetProf then ER.SetProf(name, on) end end,
          section = first and section or nil,
          prof = name,
          tip = tip,
        })
      end
      local PRIMARY = { "Mining", "Herbalism", "Skinning", "Alchemy", "Blacksmithing", "Engineering", "Enchanting",
        "Leatherworking", "Tailoring" }
      local SECONDARY = { "First Aid", "Cooking", "Fishing", "Survival" }
      for i, n in ipairs(PRIMARY) do
        Prof(n, i == 1, "Primary professions", "Tick the ones you have or mean to learn (the game's skill list ticks the ones you have). The guide adds where to train, what to gather on the way and when to go back.")
      end
      for i, n in ipairs(SECONDARY) do
        Prof(n, i == 1, "Secondary professions", "Steps for " .. n .. " while you pass its trainers. First Aid and Cooking are on until you untick them.")
      end
      return list
    end)(),
    note = "Professions you already have are ticked from your skill list and stay ticked.",
    buttons = {} },
  { title = "Auto mode", head = "pfQuest xpGuide does the clicking at NPCs. Hold Shift when you talk to one to do it yourself.",
    checks = {
      { "Auto mode",
        function() return not Db().autoOff end,
        function(on) if ER.db then ER.db.autoOff = not on end end,
        tip = "Turns all of the ticks below on or off at once. Hold Shift when you talk to an NPC to do it yourself.", wide = true },
      { "Take and hand in quests", section = "Quest givers",
        function() return not Db().autoquestOff end,
        function(on) if ER.db then ER.db.autoquestOff = not on end end,
        tip = "Takes the quests of the step you are on and hands in finished ones; the next steps' quests only from that step's NPC. Rewards: you pick; if none fit you, it takes the one that sells for the most.", part = true },
      { "Pick quests in NPC menus",
        function() return not Db().automenuOff end,
        function(on) if ER.db then ER.db.automenuOff = not on end end,
        tip = "When an NPC has several quests, picks the right one.", part = true },
      { "Take the flight on fly steps", section = "Travel",
        function() return not Db().autoflightOff end,
        function(on) if ER.db then ER.db.autoflightOff = not on end end,
        tip = "Opens the flight map and flies to the step's town.", part = true },
      { "Set my hearthstone at the inn",
        function() return not Db().autoinnOff end,
        function(on) if ER.db then ER.db.autoinnOff = not on end end,
        tip = "On a set-hearthstone step, at that inn only.", part = true },
      { "Sell grey items and repair", section = "Vendors",
        function() return not Db().autosellOff end,
        function(on) if ER.db then ER.db.autosellOff = not on end end,
        tip = "At any vendor. Never white or quest items.", part = true },
      { "Use your hearthstone button", section = "Always (with Auto mode off too)",
        function() return not Db().hearthBtnOff end,
        function(on)
          if ER.db then ER.db.hearthBtnOff = not on end
          if ER.StepsChanged then ER.StepsChanged() end
        end,
        tip = "A button on hearth steps. It never hearths by itself." },
    },
    buttons = {},
  },
  { title = "Helpers", head = "Extra help on screen: the arrow, markers, tips and tooltips.",
    checks = {
      { "Show the arrow", section = "Arrow",
        function() return not Db().arrowOff end,
        function(on) if (not Db().arrowOff) ~= on and ER.ToggleArrow then ER.ToggleArrow() end end,
        tip = "The arrow that points the way. The arrow icon under the guide window does the same." },
      { "Use xpGuide's own markers", section = "Enemies and NPCs",
        function() return ER.OwnMarkers and ER.OwnMarkers() or false end,
        function(on) if (ER.OwnMarkers and ER.OwnMarkers() or false) ~= on and ER.ToggleSkulls then ER.ToggleSkulls() end end,
        tip = "Off by default: pfQuest's markers show on the map, and pfQuest-turtle's sword and bag on nameplates (moved next to the level). Tick it for the guide's own: left of the level on nameplates a skull on mobs to kill, a sack on mobs that drop what you need, ! on who gives the step's quest, ? on who takes it back; and a marker on the map at the step's place. With pfQuest-turtle's icons on, the skull and sack are still left to them." },
      { "Show the tips box", section = "Tips and warnings",
        function() return not Db().tipsOff end,
        function(on) if (not Db().tipsOff) ~= on and ER.ToggleTips then ER.ToggleTips() end end,
        tip = "The \"pfQuest xpGuide says\" box under the guide: questions (money, moving on) and tips." },
      { "Show warnings",
        function() return not Db().warnOff end,
        function(on)
          if ER.db then ER.db.warnOff = not on end
          if ER.StepsChanged then ER.StepsChanged() end
        end,
        tip = "Dangerous mobs, caves and mines." },
      { "Use pfUI's look", section = "Look and other",
        function() return not Db().pfuiThemeOff end,
        function(on) if (not Db().pfuiThemeOff) ~= on and ER.ToggleTheme then ER.ToggleTheme() end end,
        tip = "With pfUI, pfQuest xpGuide's windows take pfUI's colours, font and borders. Takes effect after /reload." },
      { "Minimap button",
        function() return not Db().minimapHidden end,
        function(on)
          if ER.db then ER.db.minimapHidden = not on end
          if ER.UpdateMinimapButton then ER.UpdateMinimapButton() end
        end,
        tip = "The pfQuest xpGuide button on the minimap." },
    },
    buttons = {},
  },
  { title = "Advanced", head = "Settings most players never need, the fallback guide and a report for bug reports.",
    checks = {
      { "Use pfQuest's arrow", section = "Arrow and tooltips",
        function() return ER.WantPfArrow and ER.WantPfArrow() or false end,
        function(on) if (ER.WantPfArrow and ER.WantPfArrow() or false) ~= on and ER.TogglePfArrow then ER.TogglePfArrow() end end,
        tip = "On by default: when your pfQuest has an arrow and it is switched on, it points the way and ours stays hidden: one arrow, not two. With pfQuest SmartArrow installed it is routed: zone exits, flight paths, boats, roads, around obstacles. Untick it for the guide's own arrow; without pfQuest's arrow the guide's own is used anyway." },
      { "Easy / Hard on enemy tooltips",
        function() return not Db().rateOff end,
        function(on) if ER.db then ER.db.rateOff = not on end end,
        tip = "Enemy tooltips say Easy, Medium or Hard." },
      { "Popup on a chain's first quest", section = "Other",
        function() return Db().chainPopup end,
        function(on) if ER.db then ER.db.chainPopup = on end end,
        tip = "Says how long the chain is and what comes next." },
      { "Tell my party when I hand in",
        function() return Db().partyAnnounce end,
        function(on) if ER.db then ER.db.partyAnnounce = on end end,
        tip = "One line in party chat." },
    },
    buttons = {
      { "Switch to fallback", "RestedXP's original guide in place of the xpGuide Fast route guide you follow, and back (/xpg fallback).", function()
          if ER.FastRoute then ER.FastRoute.Switch() end
        end },
      { "Report", "Prints what the addon sees (race, zone, guide, addons) for a bug report, and keeps it in the saved file (/xpg report).", function()
          if ER.Report then ER.Report() end
        end },
    },
  },
  { title = "Usage", head = "How to use pfQuest xpGuide, and what it works with.", help = "usage", checks = {}, buttons = {} },
  { title = "Features", head = "What pfQuest xpGuide does, and what changed in each version.", help = "features", checks = {}, buttons = {} },
}

-- The row along the bottom, under every page.
local BOTTOM = {
  { "Close", "Close the settings.", function() Hide() end },
}

-- Every tick of every page in one list, in the order they are made; each one knows its page.
local CHECKS = {}
for p, page in ipairs(PAGES) do
  for _, c in ipairs(page.checks) do
    c.page = p
    table.insert(CHECKS, c)
  end
end

-- What the window holds, for the tests: each page's title, its ticks (labels), how many are Auto mode's part ticks, its buttons (labels);
-- the bottom row; the page open now.
function ER.SettingsInfo()
  local out = { pages = {}, bottom = {}, page = S.page }
  for _, page in ipairs(PAGES) do
    local parts, labels, buttons, sections = 0, {}, {}, {}
    for _, c in ipairs(page.checks) do
      if c.part then parts = parts + 1 end
      if c.section then table.insert(sections, c.section) end
      table.insert(labels, c[1])
    end
    for _, b in ipairs(page.buttons) do table.insert(buttons, b[1]) end
    table.insert(out.pages, { title = page.title, head = page.head, checks = labels, parts = parts, buttons = buttons, sections = sections, help = page.help })
  end
  for _, b in ipairs(BOTTOM) do table.insert(out.bottom, b[1]) end
  return out
end

-- A window taller than the screen is made smaller to fit: 1 when it fits (or the screen height is not known), else the share that fits
-- with 20 units to spare.
function ER.SettingsScale(height, screen)
  if type(height) == "number" and height > 0 and type(screen) == "number" and screen >= 300 and height > screen - 20 then
    return (screen - 20) / height
  end
  return 1
end

local function Refresh()
  local off = Db().autoOff
  for i, c in ipairs(S.checks) do
    c:SetChecked(CHECKS[i][2]() and 1 or nil)
    -- Auto mode's own ticks are greyed and cannot be clicked while Auto mode is off (they keep their setting for when
    -- it is back on).
    if CHECKS[i].part then
      c:SetAlpha(off and 0.45 or 1)
      if off then c:Disable() else c:Enable() end
    end
  end
  local info = Running() and ER.Steps.Info()
  local mode = ER.MODES and ER.Mode and ER.MODES[ER.Mode()]
  S.sub:SetText(GREY .. "Difficulty: " .. END .. WHITE .. (mode and mode.label or "?") .. END .. GREY .. "     Guide: " .. END ..
    WHITE .. (info and (info.title or info.name) or "none") .. END ..
    ((info and info.fast and ER.XPRate) and (GREY .. ", " .. ER.XPRate() .. "x exp" .. END) or ""))
  -- the professions show your skill in them
  for i, c in ipairs(S.checks) do
    local d = CHECKS[i]
    if d.prof then
      local label = getglobal("pfQuest_xpGuideSettingsCheck" .. i .. "Text")
      if label and ER.ProfDetail then
        label:SetText(d.prof .. "  " .. (ER.KnowsProf(d.prof) and WHITE or GREY) .. ER.ProfDetail(d.prof) .. END)
      end
    end
  end
  if S.FillStepper then S.FillStepper() end
  if S.FillGuides then S.FillGuides() end
  if S.FillHelp then S.FillHelp() end
end

-- A page by its number or its name ("Guides", "settings", ...); nil when there is none.
local function PageIndex(n)
  if type(n) == "string" then
    local want = string.lower(n)
    for i, page in ipairs(PAGES) do if string.lower(page.title) == want then return i end end
    n = tonumber(n)
  end
  n = tonumber(n)
  if n and PAGES[n] then return n end
  return nil
end

-- Shows a page (its number or name) and keeps it as the page to open next time.
local function ShowPage(n)
  n = PageIndex(n) or 1
  S.page = n
  if ER.db then ER.db.settingsPage = n end
  for i, page in ipairs(S.pages) do
    if i == n then page:Show() else page:Hide() end
    local tab = S.tabs[i]
    if tab then
      if i == n then tab:LockHighlight() else tab:UnlockHighlight() end
    end
  end
end

local function Tooltip(owner, title, text)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(title)
  if text then GameTooltip:AddLine(text, 1, 1, 1, 1) end
  GameTooltip:Show()
end

local function Button(name, parent, def, width)
  local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
  b:SetWidth(width)
  b:SetHeight(22)
  b:SetText(def.label and def.label() or def[1])
  b.def = def
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function()
    this.def[3](arg1 == "RightButton")
    if this.def.label then this:SetText(this.def.label()) end
  end)
  b:SetScript("OnEnter", function() Tooltip(this, this.def[1], this.def[2]) end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

------------------------------------------------------------------------------------------------------
-- The Guides page: the groups on the left, the group's guides on the right (scrolls with the mouse wheel or its arrows)
------------------------------------------------------------------------------------------------------

local GREEN = ER.GREEN
local ROWS, ROW_H = 14, 16
local GROUP_W = 176

local function Row(name, parent, w)
  local r = CreateFrame("Button", name, parent)
  r:SetWidth(w)
  r:SetHeight(ROW_H)
  local glow = r:CreateTexture(nil, "HIGHLIGHT")
  glow:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  glow:SetBlendMode("ADD")
  glow:SetAllPoints(r)
  r.pick = r:CreateTexture(nil, "BACKGROUND")
  r.pick:SetTexture(1, 1, 1, 0.08)
  r.pick:SetAllPoints(r)
  r.pick:Hide()
  r.text = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  r.text:SetPoint("LEFT", r, "LEFT", 4, 0)
  r.text:SetWidth(w - 8)
  r.text:SetHeight(14)
  r.text:SetJustifyH("LEFT")
  return r
end

-- Which group to show: the one picked, else the one holding the guide that runs now, else the one that suits you best.
local function OpenGroup(groups)
  if S.group then
    for _, grp in ipairs(groups) do if grp.name == S.group then return grp end end
  end
  local running, best = ER.Steps.Info(), ER.Steps.Suggest()[1]
  for _, want in ipairs({ running, best }) do
    for _, grp in ipairs(groups) do
      for _, g in ipairs(grp.guides) do if g == want then return grp end end
    end
  end
  return groups[1]
end

-- RestedXP's original guides, the fallback, sit in one folder of the group list: "RestedXP's original (fallback) >" opens it,
-- "< RestedXP's original" goes back.
local FOLDER, BACK = { special = "folder" }, { special = "back" }
local function Experimental(grp) return grp and ER.Steps.Fallback(grp.guides[1]) or false end

-- The rows of the group list: the main groups and the folder, or the folder's groups under a way back.
local function GroupList(groups)
  local main, exp = {}, {}
  for _, g in ipairs(groups) do table.insert(Experimental(g) and exp or main, g) end
  if table.getn(exp) == 0 then return main end
  if S.inExp then
    table.insert(exp, 1, BACK)
    return exp
  end
  table.insert(main, FOLDER)
  return main
end

local function FillGuides()
  if not S.groupRows then return end
  local groups = ER.Steps.Groups()
  local best = ER.Steps.Suggest()[1]
  local running = ER.Steps.Info()
  local grp = OpenGroup(groups)
  -- the window opens on the folder that holds the group shown
  if S.inExp == nil then S.inExp = Experimental(grp) end
  local rows = GroupList(groups)
  local most = math.max(0, table.getn(rows) - ROWS)
  S.goff = math.max(0, math.min(S.goff or 0, most))
  local runningExp = running and ER.Steps.Fallback(running)
  for i, r in ipairs(S.groupRows) do
    local g = rows[i + S.goff]
    if g == FOLDER then
      r.text:SetText(WHITE .. "RestedXP's original (fallback)" .. END .. (runningExp and (GREEN .. "  (now)" .. END) or "") .. GREY .. "  >" .. END)
      r.grp = g
      r.pick:Hide()
      r:Show()
    elseif g == BACK then
      r.text:SetText(GREY .. "<  " .. END .. GOLD .. "RestedXP's original" .. END)
      r.grp = g
      r.pick:Hide()
      r:Show()
    elseif g then
      local has = false
      for _, x in ipairs(g.guides) do if x == best then has = true end end
      local now = running and running.group == g.name
      r.text:SetText((S.inExp and "  " or "") .. (has and GOLD or WHITE) .. ER.GroupLabel(g.name) .. END ..
        (now and (GREEN .. "  (now)" .. END) or "") .. GREY .. "  >" .. END)
      r.grp = g
      if g == grp then r.pick:Show() else r.pick:Hide() end
      r:Show()
    else
      r.grp = nil
      r:Hide()
    end
  end
  local list = grp and grp.guides or {}
  local total = table.getn(list)
  local most = math.max(0, total - ROWS)
  S.offset = math.max(0, math.min(S.offset or 0, most))
  for i, r in ipairs(S.guideRows) do
    local g = list[i + S.offset]
    if g then
      local text = g.title or g.name
      if running == g then
        text = GREEN .. text .. "  (now)" .. END
      elseif g == best then
        text = GOLD .. text .. END .. GREY .. "  (best)" .. END
      else
        text = WHITE .. text .. END
      end
      r.text:SetText(text)
      r.guide = g
      r:Show()
    else
      r.guide = nil
      r:Hide()
    end
  end
  S.listTitle:SetText(grp and (GOLD .. ER.GroupLabel(grp.name) .. END .. GREY .. "   " .. total .. (total == 1 and " guide" or " guides") .. END) or "")
  if S.offset > 0 then S.up:Enable() else S.up:Disable() end
  if S.offset < most then S.down:Enable() else S.down:Disable() end
  if most > 0 then S.up:Show() S.down:Show() else S.up:Hide() S.down:Hide() end
  -- the running casual-route zone's place on the route, under its group's guides
  local where = grp and running and running.group == grp.name and ER.RouteLine and ER.RouteLine()
  if where then S.routeLine:SetText(GREY .. where .. END) S.routeLine:Show() else S.routeLine:Hide() end
end
S.FillGuides = FillGuides

local function Scroll(by)
  S.offset = (S.offset or 0) + by
  FillGuides()
end

function S.BuildGuides(page, y)
  local inner = W - 2 * LEFT
  local listX = LEFT + GROUP_W + 10
  local listW = inner - GROUP_W - 10 - 22
  local groupsHead = page:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  groupsHead:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT + 4, y)
  groupsHead:SetText(GREY .. "Group" .. END)
  S.listTitle = page:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  S.listTitle:SetPoint("TOPLEFT", page, "TOPLEFT", listX + 4, y)
  S.listTitle:SetJustifyH("LEFT")
  y = y - 16
  -- a faint field behind each list
  for _, box in ipairs({ { LEFT, GROUP_W }, { listX, listW + 22 } }) do
    local t = page:CreateTexture(nil, "BACKGROUND")
    t:SetTexture(0, 0, 0, 0.25)
    t:SetPoint("TOPLEFT", page, "TOPLEFT", box[1], y + 2)
    t:SetWidth(box[2])
    t:SetHeight(ROWS * ROW_H + 4)
  end
  S.groupRows, S.guideRows = {}, {}
  for i = 1, ROWS do
    local r = Row("pfQuest_xpGuideGuideMenuGroup" .. i, page, GROUP_W)
    r:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT, y - (i - 1) * ROW_H)
    r:SetScript("OnClick", function()
      local grp = this.grp
      if not grp then return end
      if grp.special then
        -- into the folder (its first group shows) or back out (the group that suits you best shows)
        S.inExp, S.goff, S.offset = grp == FOLDER, 0, 0
        S.group = nil
        if S.inExp then
          for _, g in ipairs(ER.Steps.Groups()) do
            if Experimental(g) then S.group = g.name break end
          end
          local running = ER.Steps.Info()
          if running and ER.Steps.Fallback(running) then S.group = running.group end
        else
          local running, best = ER.Steps.Info(), ER.Steps.Suggest()[1]
          local show = (running and not ER.Steps.Fallback(running)) and running or best
          if show and not ER.Steps.Fallback(show) then S.group = show.group end
        end
        FillGuides()
        return
      end
      S.group, S.offset = grp.name, 0
      FillGuides()
    end)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function()
      S.goff = (S.goff or 0) + (arg1 > 0 and -3 or 3)
      FillGuides()
    end)
    r:SetScript("OnEnter", function()
      local grp = this.grp
      if not grp then return end
      if grp == FOLDER then
        Tooltip(this, "RestedXP's original (fallback)", "RestedXP's Fast route as RestedXP made it, without the xpGuide Fast options. " ..
          "For when the xpGuide Fast route goes wrong: /xpg fallback switches between the two. Click to see the guides.")
      elseif grp == BACK then
        Tooltip(this, "The xpGuide Fast route", "Back to the xpGuide Fast route.")
      else
        Tooltip(this, ER.GroupLabel(grp.name), "Click to see its guides.")
      end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:Hide()
    S.groupRows[i] = r
  end
  local list = CreateFrame("Frame", "pfQuest_xpGuideGuideMenuPanel", page)
  list:SetPoint("TOPLEFT", page, "TOPLEFT", listX, y)
  list:SetWidth(listW)
  list:SetHeight(ROWS * ROW_H)
  list:EnableMouseWheel(true)
  list:SetScript("OnMouseWheel", function() Scroll(arg1 > 0 and -3 or 3) end)
  for i = 1, ROWS do
    local r = Row("pfQuest_xpGuideGuideMenuGuide" .. i, list, listW)
    r:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(i - 1) * ROW_H)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function() Scroll(arg1 > 0 and -3 or 3) end)
    r:SetScript("OnClick", function()
      local g = this.guide
      if not g then return end
      Hide()
      if ER.ChooseGuide then ER.ChooseGuide(g) else ER.StartGuide(ER.Steps.Key(g), nil, nil, true) end
    end)
    r:SetScript("OnEnter", function()
      local g = this.guide
      if not g then return end
      local body = "Levels " .. g.lo .. " to " .. g.hi .. "."
      if g.about and g.about ~= "" then body = body .. "\n" .. g.about end
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetText(g.title or g.name)
      GameTooltip:AddLine(body, 1, 1, 1, 1)
      GameTooltip:AddLine("Click to follow this guide.", 0.6, 0.6, 0.6, 1)
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:Hide()
    S.guideRows[i] = r
  end
  local function Arrow(name, dir, point, dy)
    local b = CreateFrame("Button", name, page)
    b:SetWidth(18)
    b:SetHeight(18)
    local which = dir < 0 and "Up" or "Down"
    b:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. which .. "Button-Up")
    b:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. which .. "Button-Down")
    b:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. which .. "Button-Disabled")
    b:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. which .. "Button-Highlight", "ADD")
    b:SetPoint(point, list, point == "TOPLEFT" and "TOPRIGHT" or "BOTTOMRIGHT", 2, dy)
    b.dir = dir
    b:SetScript("OnClick", function() Scroll(this.dir * (ROWS - 1)) end)
    return b
  end
  S.up = Arrow("pfQuest_xpGuideGuideMenuUp", -1, "TOPLEFT", 0)
  S.down = Arrow("pfQuest_xpGuideGuideMenuDown", 1, "BOTTOMLEFT", 0)
  y = y - ROWS * ROW_H - 6
  S.routeLine = page:CreateFontString("pfQuest_xpGuideGuideMenuLine", "ARTWORK", "GameFontHighlightSmall")
  S.routeLine:SetPoint("TOPLEFT", page, "TOPLEFT", listX + 4, y)
  S.routeLine:SetWidth(listW)
  S.routeLine:SetHeight(14)
  S.routeLine:SetJustifyH("LEFT")
  S.routeLine:Hide()
  y = y - 16
  return y
end

------------------------------------------------------------------------------------------------------
-- The Usage and Features pages: the words of Help.lua in a box that scrolls with the mouse wheel or its arrows
------------------------------------------------------------------------------------------------------

local WHEEL = 36
local function HelpScroll(view, delta)
  local at = view:GetVerticalScroll() or 0
  local to = math.max(0, math.min(view.range or 0, at + delta))
  view:SetVerticalScroll(to)
  view.at = to
  if view.up then
    if to <= 0 then view.up:Disable() else view.up:Enable() end
    if to >= (view.range or 0) then view.down:Disable() else view.down:Enable() end
  end
end

function S.BuildHelp(page, y, key)
  local w = W - 2 * LEFT - 24
  local view = CreateFrame("ScrollFrame", "pfQuest_xpGuideHelpView" .. key, page)
  view:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT, y)
  view:SetWidth(w)
  view:SetHeight(200)
  local child = CreateFrame("Frame", "pfQuest_xpGuideHelpText" .. key, view)
  child:SetWidth(w)
  child:SetHeight(10)
  view:SetScrollChild(child)
  view.key, view.texts, view.child, view.w, view.top = key, {}, child, w, -y
  view:EnableMouseWheel(true)
  view:SetScript("OnMouseWheel", function() HelpScroll(this, -(arg1 or 0) * WHEEL) end)
  local function Arrow(name, dir)
    local b = CreateFrame("Button", name, page)
    b:SetWidth(18)
    b:SetHeight(18)
    local which = dir < 0 and "Up" or "Down"
    b:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. which .. "Button-Up")
    b:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. which .. "Button-Down")
    b:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. which .. "Button-Disabled")
    b:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. which .. "Button-Highlight", "ADD")
    b:SetPoint(dir < 0 and "TOPLEFT" or "BOTTOMLEFT", view, dir < 0 and "TOPRIGHT" or "BOTTOMRIGHT", 4, 0)
    b.dir = dir
    b:SetScript("OnClick", function() HelpScroll(view, this.dir * view:GetHeight() * 0.8) end)
    return b
  end
  view.up, view.down = Arrow("pfQuest_xpGuideHelpUp" .. key, -1), Arrow("pfQuest_xpGuideHelpDown" .. key, 1)
  table.insert(S.helpViews, view)
  return y
end

-- A page's words cut at line ends into pieces of at most HELP_PART bytes (a single longer line is cut where it is).
local HELP_PART = 2000
local function HelpParts(words)
  local parts, cur = {}, ""
  local function Add(line)
    if cur == "" then cur = line
    elseif string.len(cur) + 1 + string.len(line) <= HELP_PART then cur = cur .. "\n" .. line
    else table.insert(parts, cur); cur = line end
  end
  local start = 1
  while true do
    local a = string.find(words, "\n", start, true)
    local line = string.sub(words, start, a and a - 1 or nil)
    while string.len(line) > HELP_PART do
      Add(string.sub(line, 1, HELP_PART))
      line = string.sub(line, HELP_PART + 1)
    end
    Add(line)
    if not a then break end
    start = a + 1
  end
  if cur ~= "" or table.getn(parts) == 0 then table.insert(parts, cur) end
  return parts
end

-- The words, fitted to the box; how far they can scroll follows from how tall they are.
function S.FillHelp()
  for _, view in ipairs(S.helpViews) do
    local words = ER.HelpText and ER.HelpText(view.key) or ""
    -- The game client crashes (in its own code, no Lua error) on a font string of more than 4096 bytes, so a long page is set
    -- as several font strings, one under the other, each well under that.
    local parts = HelpParts(words)
    local h = 0
    for i, part in ipairs(parts) do
      local fs = view.texts[i]
      if not fs then
        fs = view.child:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        if ER.ApplyFont then ER.ApplyFont(fs, 0) end
        view.texts[i] = fs
      end
      fs:ClearAllPoints()
      fs:SetPoint("TOPLEFT", view.child, "TOPLEFT", 0, -h)
      fs:Show()
      h = h + ER.FitHeight(fs, part, view.w, 1)
    end
    for i = table.getn(parts) + 1, table.getn(view.texts) do
      view.texts[i]:SetText("")
      view.texts[i]:Hide()
    end
    if h < 100 then h = 100 end
    view.child:SetHeight(h)
    view.range = math.max(0, h - view:GetHeight())
    HelpScroll(view, 0)
  end
end

-- Builds one page's ticks, note and buttons in its own frame and returns how tall it is. Ticks sit in two columns; a wide tick has a whole
-- row. The first of a pair waits (pendingH) for the second, so the pair is as tall as the taller of the two labels.
local function BuildPage(p, def, nc, nb)
  local page = CreateFrame("Frame", "pfQuest_xpGuideSettingsPage" .. p, S.frame)
  page:SetPoint("TOPLEFT", S.frame, "TOPLEFT", S.side, S.top)
  page:SetWidth(W)
  S.pages[p] = page

  local y = 0
  local head = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  head:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT, y)
  head:SetJustifyH("LEFT")
  local rule = page:CreateTexture(nil, "ARTWORK")
  rule:SetHeight(1)
  rule:SetWidth(W - 2 * LEFT)
  if Themed() then
    -- OctoPad's header: the page's name in small accent capitals with a thin accent line, its sentence in grey under it.
    head:SetText(def.title)
    ER.Skin.Header(head, rule)
    rule:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT, y - 13)
    local sentence = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sentence:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT, y - 20)
    sentence:SetJustifyH("LEFT")
    y = y - 20 - ER.FitHeight(sentence, GREY .. def.head .. END, W - 2 * LEFT, 12) - 4
  else
    y = y - ER.FitHeight(head, def.head, W - 2 * LEFT, 14) - 4
    rule:SetTexture(1, 1, 1, 0.15)
    rule:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT, y)
  end
  y = y - 6
  if def.guides then y = S.BuildGuides(page, y) end
  if def.help then y = S.BuildHelp(page, y, def.help) end

  local col, pendingH = 0, nil
  for _, c in ipairs(def.checks) do
    nc = nc + 1
    if (c.wide or c.section) and pendingH then
      y = y - pendingH
      pendingH, col = nil, 0
    end
    -- a small heading over a group of ticks
    if c.section then
      y = y - 4
      local sh = page:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
      sh:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT + 4, y)
      sh:SetJustifyH("LEFT")
      local accent = Themed() and ER.Skin.ACCENT or GOLD
      sh:SetText(accent .. string.upper(c.section) .. END)
      local line = page:CreateTexture(nil, "ARTWORK")
      line:SetHeight(1)
      line:SetPoint("LEFT", sh, "RIGHT", 6, 0)
      line:SetPoint("RIGHT", page, "LEFT", W - LEFT, 0)
      line:SetTexture(1, 1, 1, 0.08)
      S.sections = S.sections or {}
      table.insert(S.sections, c.section)
      y = y - 15
    end
    local b = CreateFrame("CheckButton", "pfQuest_xpGuideSettingsCheck" .. nc, page, "UICheckButtonTemplate")
    b:SetWidth(24)
    b:SetHeight(24)
    local x, labelW = LEFT, W - 2 * LEFT - 30
    if not c.wide then
      x = LEFT + col * COL_W + (c.part and 10 or 0)
      labelW = COL_W - 34 - (c.part and 10 or 0)
    end
    b:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
    local rowH = 24
    local label = getglobal("pfQuest_xpGuideSettingsCheck" .. nc .. "Text")
    if label then
      label:ClearAllPoints()
      label:SetPoint("TOPLEFT", b, "TOPRIGHT", 0, -4)
      label:SetJustifyH("LEFT")
      rowH = math.max(24, ER.FitHeight(label, c[1], labelW, 16) + 8)
    end
    b.index, b.page = nc, p
    b:SetScript("OnClick", function()
      local on = this:GetChecked() and true or false
      CHECKS[this.index][3](on)
      Refresh()
    end)
    b:SetScript("OnEnter", function()
      local d = CHECKS[this.index]
      Tooltip(this, d[1], d.tip)
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    S.checks[nc] = b
    if c.wide then
      y = y - rowH
    elseif col == 0 then
      pendingH, col = rowH, 1
    else
      y = y - math.max(pendingH or 24, rowH)
      pendingH, col = nil, 0
    end
  end
  if pendingH then y = y - pendingH end

  if def.note then
    y = y - 4
    local note = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT + 4, y)
    note:SetJustifyH("LEFT")
    y = y - ER.FitHeight(note, GREY .. def.note .. END, W - 2 * LEFT - 4, 14)
  end


  if def.stepper then
    y = y - 6
    local st = def.stepper
    local label = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT + 6, y - 5)
    label:SetText(st[1])
    local function Arrow(name, dir)
      local b = CreateFrame("Button", name, page)
      b:SetWidth(16)
      b:SetHeight(16)
      local side = (dir < 0) and "Left" or "Right"
      b:SetNormalTexture("Interface\\MoneyFrame\\Arrow-" .. side .. "-Up")
      b:SetPushedTexture("Interface\\MoneyFrame\\Arrow-" .. side .. "-Down")
      b:SetDisabledTexture("Interface\\MoneyFrame\\Arrow-" .. side .. "-Disabled")
      b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
      b.dir = dir
      b:SetScript("OnClick", function()
        if ER.NudgeFontSize then ER.NudgeFontSize(this.dir) end
        if S.FillStepper then S.FillStepper() end
      end)
      b:SetScript("OnEnter", function() Tooltip(this, (this.dir < 0) and "Smaller text" or "Bigger text", st[2]) end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      return b
    end
    local left = Arrow("pfQuest_xpGuideSettingsSizeLeft", -1)
    left:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT + 150, y - 3)
    -- the size, between the arrows, on a dark field like the bag split's
    local box = CreateFrame("Button", "pfQuest_xpGuideSettingsSizeValue", page)
    box:SetWidth(64)
    box:SetHeight(20)
    box:SetPoint("LEFT", left, "RIGHT", 4, 0)
    local fill = box:CreateTexture(nil, "BACKGROUND")
    fill:SetTexture(0, 0, 0, 0.5)
    fill:SetAllPoints(box)
    box.text = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    box.text:SetPoint("CENTER", box, "CENTER", 0, 0)
    box:SetScript("OnClick", function()
      if ER.SetFontSize then ER.SetFontSize(nil) end
      if S.FillStepper then S.FillStepper() end
    end)
    box:SetScript("OnEnter", function() Tooltip(this, st[1], st[3]) end)
    box:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local right = Arrow("pfQuest_xpGuideSettingsSizeRight", 1)
    right:SetPoint("LEFT", box, "RIGHT", 4, 0)
    S.FillStepper = function()
      local n = ER.FontSize and ER.FontSize() or 12
      local own = ER.db and tonumber(ER.db.fontSize)
      box.text:SetText(WHITE .. n .. END .. (own and "" or (GREY .. "  pfQuest" .. END)))
      if n <= (ER.FONT_MIN or 8) then left:Disable() else left:Enable() end
      if n >= (ER.FONT_MAX or 24) then right:Disable() else right:Enable() end
    end
    S.FillStepper()
    y = y - 26
  end
  if table.getn(def.buttons) > 0 then y = y - 8 end
  local bw = math.floor((W - 2 * LEFT - 8) / 2)
  for i, bd in ipairs(def.buttons) do
    nb = nb + 1
    local b = Button("pfQuest_xpGuideSettingsButton" .. nb, page, bd, bw)
    local bc = math.mod(i - 1, 2)
    b:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT + 2 + bc * (bw + 8), y)
    S.buttons[nb] = b
    if bc == 1 then y = y - 26 end
  end
  if math.mod(table.getn(def.buttons), 2) == 1 then y = y - 26 end

  local height = -y + 6
  page:SetHeight(height)
  return height, nc, nb
end

local function Build()
  local themed = Themed()
  S.side, S.top = themed and SIDE_W or 0, themed and -58 or TOP_Y
  local f = CreateFrame("Frame", "pfQuest_xpGuideSettings", UIParent)
  S.frame = f
  f:SetWidth(W + S.side)
  f:SetFrameStrata("DIALOG")
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  if ER.Skin then ER.Skin.Window(f, nil) end
  f:Hide()
  table.insert(UISpecialFrames, "pfQuest_xpGuideSettings")

  local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  S.sub = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  local close = CreateFrame("Button", "pfQuest_xpGuideSettingsClose", f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
  local count = table.getn(PAGES)
  if themed then
    -- OctoPad's title: the name in the accent, the rest in grey; the line about the guide above the page.
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
    title:SetText(ER.Skin.ACCENT .. "pfQuest xpGuide" .. END)
    ER.Skin.Title(title, 14)
    local ver = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    ver:SetPoint("LEFT", title, "RIGHT", 8, -1)
    ver:SetText(GREY .. "settings  v" .. ER.VERSION .. END)
    S.sub:SetPoint("TOPLEFT", f, "TOPLEFT", S.side + LEFT, -36)
    -- The sidebar: a darker strip with one flat button per page (Theme.lua turns them into OctoPad's buttons).
    local side = f:CreateTexture(nil, "BACKGROUND")
    S.sideTex = side
    side:SetTexture("Interface\\Buttons\\WHITE8X8")
    local th = ER.Skin.Theme()
    side:SetVertexColor(th.side[1], th.side[2], th.side[3], 1)
    side:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -40)
    side:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
    side:SetWidth(S.side - 4)
    for p, page in ipairs(PAGES) do
      local tab = Button("pfQuest_xpGuideSettingsTab" .. p, f, { page.title, page.head, function() end }, S.side - 20)
      tab:SetHeight(28)
      tab:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -50 - (p - 1) * 34)
      tab.page = p
      tab:SetScript("OnClick", function() ShowPage(this.page) end)
      S.tabs[p] = tab
    end
  else
    title:SetPoint("TOP", f, "TOP", 0, -18)
    title:SetText("pfQuest xpGuide settings")
    S.sub:SetPoint("TOP", title, "BOTTOM", 0, -6)

    -- The page buttons along the top.
    local tw = math.floor((W - 2 * LEFT - (count - 1) * 6) / count)
    for p, page in ipairs(PAGES) do
      local tab = Button("pfQuest_xpGuideSettingsTab" .. p, f, { page.title, page.head, function() end }, tw)
      tab:SetPoint("TOPLEFT", f, "TOPLEFT", LEFT + (p - 1) * (tw + 6), -54)
      -- six buttons in a row: the small font keeps "Configuration" inside its button
      local label = getglobal("pfQuest_xpGuideSettingsTab" .. p .. "Text")
      if label and label.SetFontObject and GameFontNormalSmall then label:SetFontObject(GameFontNormalSmall) end
      tab.page = p
      tab:SetScript("OnClick", function() ShowPage(this.page) end)
      S.tabs[p] = tab
    end
  end

  -- Every page is as tall as the tallest, so the window keeps one size while the pages change.
  local tallest, nc, nb = 0, 0, 0
  for p, page in ipairs(PAGES) do
    local h
    h, nc, nb = BuildPage(p, page, nc, nb)
    if h > tallest then tallest = h end
  end
  for _, page in ipairs(S.pages) do page:SetHeight(tallest) end
  -- Usage and Features fill the page: their boxes are as tall as what is left under the heading.
  for _, view in ipairs(S.helpViews) do view:SetHeight(math.max(120, tallest - view.top - 8)) end

  local bw = 120
  for i, def in ipairs(BOTTOM) do
    local b = Button("pfQuest_xpGuideSettingsBottom" .. i, f, def, bw)
    b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", S.side + LEFT + (i - 1) * (bw + 8), 38)
  end

  local credit = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  credit:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 16)
  credit:SetText(GREY .. "pfQuest xpGuide   v" .. ER.VERSION .. END)
  local height = -S.top + tallest + 70   -- the bottom row and the credit line under the pages
  if themed then height = math.max(height, 50 + count * 34 + 70) end   -- room for the sidebar's buttons
  f:SetHeight(height)
  if ER.Skin then ER.Skin.Tree(f) end
  f:SetScale(ER.SettingsScale(height, UIParent:GetHeight()))
end

function ER.ShowSettings(page)
  if not S.frame then Build() end
  if PageIndex(page) == PageIndex("Guides") then S.group, S.offset, S.inExp, S.goff = nil, 0, nil, 0 end
  Refresh()
  ShowPage(page or Db().settingsPage or S.page or 1)
  S.frame:Show()
end

-- The Guides page of the settings window (the guide menu lives there now).
function ER.ShowGuideMenu()
  ER.ShowSettings("Guides")
end

-- The guide list follows the guide (GuideWindow.lua calls this when the steps change).
function ER.GuideMenuRefresh()
  if S.frame and S.frame:IsShown() and S.FillGuides then S.FillGuides() end
end

function ER.SettingsShown()
  return S.frame ~= nil and S.frame:IsShown() and true or false
end

function ER.ToggleSettings()
  if S.frame and S.frame:IsShown() then S.frame:Hide() else ER.ShowSettings() end
end

ER.Loaded("Settings.lua")
