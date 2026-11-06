--[[
  TankSuite - Config menu (/tks) and minimap button.
  Layout: sidebar with tabs on the left, one page per tab on the right.
  Every widget reads/writes TS.db through small closures (never cache TS.db.x
  in a local: "reset settings" replaces the tables).
]]

local TS = TankSuite
local UI = TS.UI
local C = UI.C
local M = { pages = {}, tabs = {}, current = "general" }
TS.Menu = M

local ICON = "Interface\\Icons\\"
local TABS = {
  { "general",  "tab_general",  ICON .. "INV_Misc_Gear_01" },
  { "announce", "tab_announce", ICON .. "Ability_Warrior_BattleShout" },
  { "maintank", "tab_maintank", ICON .. "Ability_Warrior_DefensiveStance" },
  { "messages", "tab_messages", ICON .. "INV_Misc_Note_01" },
  { "plates",   "tab_plates",   ICON .. "Ability_Defend" },
  { "tanks",    "tab_tanks",    ICON .. "Spell_Holy_SealOfFury" },
  { "about",    "tab_about",    ICON .. "INV_Misc_Book_09" },
}

local CHANNELS = {
  { "SAY", "ch_SAY" }, { "YELL", "ch_YELL" }, { "PARTY", "ch_PARTY" }, { "RAID", "ch_RAID" },
  { "RAID_WARNING", "ch_RAID_WARNING" }, { "GROUP", "ch_GROUP" }, { "GROUP_RW", "ch_GROUP_RW" },
  { "CHANNEL", "ch_CHANNEL" }, { "SELF", "ch_SELF" },
}

-- closures that read/write db.<a>.<b>
local function A() return TS.db.announce end
local function P() return TS.db.plates end

local function Bool(tblFn, key)
  return function() return tblFn()[key] and true or false end,
         function(v) tblFn()[key] = v and true or false end
end

local function Chk(page, label, tblFn, key, x, y, tip, width, after)
  local get, set = Bool(tblFn, key)
  local w = UI.Checkbox(page, label, get, function(v)
    set(v)
    if after then after() end
  end, tip, width)
  UI.Place(w, x, y)
  return w
end

-- 3-column grid of checkboxes bound to db.announce.<group>[key]
local function Grid(page, keys, tblFn, y0, prefix)
  for i = 1, table.getn(keys) do
    local col = math.mod(i - 1, 3)
    local row = math.floor((i - 1) / 3)
    Chk(page, prefix .. keys[i], tblFn, keys[i], col * 162, y0 + row * 24, nil, 160)
  end
end

local function Paragraph(page, key, x, y, width, height, color)
  local fs = UI.LText(page, key, 11, color or C.dim)
  fs:SetWidth(width)
  fs:SetHeight(height)
  fs:SetJustifyV("TOP")
  fs:SetPoint("TOPLEFT", page, "TOPLEFT", x, -y)
  return fs
end

local function Section(page, key, y)
  local s = UI.Section(page, key, 490)
  UI.Place(s, 0, y)
  return s
end

----------------------------------------------------------------------
-- Pages
----------------------------------------------------------------------
local function BuildGeneral(page)
  Section(page, "sec_general", 0)
  local lang = UI.Cycle(page, "opt_language", {
    { "auto", "lang_auto" }, { "en", "lang_en" }, { "fr", "lang_fr" },
  }, function() return TS.db.language end, function(v)
    TS.db.language = v
    TS.ApplyLanguage()
    M.RefreshAll()
  end, "tip_language")
  UI.Place(lang, 0, 30)

  local mm = UI.Checkbox(page, "opt_minimap", function() return TS.db.minimapShow end, function(v)
    TS.db.minimapShow = v
    M.PlaceMinimap()
  end)
  UI.Place(mm, 0, 62)

  Section(page, "sec_modules", 100)
  Chk(page, "opt_announcer", A, "enabled", 0, 130, "tip_announcer", 300)
  Chk(page, "opt_plates", P, "enabled", 0, 156, "tip_plates", 300)

  Section(page, "sec_status", 194)
  local status = UI.Text(page, "", 11, C.text)
  status:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -224)
  status:SetWidth(490)
  status:SetHeight(44)
  status:SetJustifyV("TOP")
  table.insert(UI.widgets, { Refresh = function()
    if TS.hasSuperWoW then
      status:SetText(TS.Hex(C.good[1], C.good[2], C.good[3]) .. TS.L("status_ok") .. "|r")
    else
      status:SetText(TS.Hex(C.bad[1], C.bad[2], C.bad[3]) .. TS.L("status_nosw") .. "|r")
    end
  end })

  local test = UI.Button(page, "btn_test", 170, 26, function() TS.Announcer.Test() end)
  UI.Place(test, 0, 280)
  local reset = UI.Button(page, "btn_reset", 170, 26, function()
    if not IsShiftKeyDown() then
      TS.Print(TS.L("reset_hint"))
      return
    end
    for k in pairs(TS.db) do TS.db[k] = nil end
    TS.Merge(TS.db, TS.defaults)
    TS.ApplyLanguage()
    M.RefreshAll()
    TS.Nameplates.RefreshStyle()
    TS.Print(TS.L("reset_done"))
  end)
  UI.Place(reset, 180, 280)
  UI.Tip(reset, "tip_reset")

end

local function BuildAnnounce(page)
  Section(page, "sec_channels", 0)
  local fc = UI.Cycle(page, "opt_failchannel", CHANNELS,
    function() return A().failChannel end, function(v) A().failChannel = v end, "tip_failchannel")
  UI.Place(fc, 0, 28)
  local ic = UI.Cycle(page, "opt_infochannel", CHANNELS,
    function() return A().infoChannel end, function(v) A().infoChannel = v end, "tip_infochannel")
  UI.Place(ic, 0, 54)
  local cc = UI.EditRow(page, "opt_customchannel",
    function() return A().customChannel end, function(v) A().customChannel = TS.Trim(v) end, "tip_customchannel")
  UI.Place(cc, 0, 80)
  Chk(page, "opt_grouponly", A, "groupOnly", 0, 110, "tip_grouponly", 240)
  Chk(page, "opt_alertself", A, "alertSelf", 250, 110, "tip_alertself", 240)

  Section(page, "sec_fail", 142)
  Grid(page, TS.Announcer.FAIL_KEYS, function() return A().fail end, 170, "spell_")
  Section(page, "sec_used", 250)
  Grid(page, TS.Announcer.USED_KEYS, function() return A().used end, 278, "spell_")
  Section(page, "sec_cd", 334)
  Grid(page, TS.Announcer.CD_KEYS, function() return A().cd end, 362, "spell_")
end

local function BuildMainTank(page)
  Section(page, "sec_maintank", 0)
  Paragraph(page, "mt_desc", 0, 28, 490, 44)
  Chk(page, "opt_mt_enable", function() return A().mainTank end, "enabled", 0, 78, "tip_mt", 400)
  local dur = UI.Slider(page, "opt_mt_duration", 5, 30, 1,
    function() return A().mainTank.duration end, function(v) A().mainTank.duration = v end, "tip_mt_duration")
  UI.Place(dur, 0, 106)
  Chk(page, "opt_mt_dual", function() return A().mainTank end, "skipDual", 0, 136, "tip_mt_dual", 400)

  Section(page, "sec_salv", 176)
  Paragraph(page, "salv_desc", 0, 204, 490, 44)
  Chk(page, "opt_salv", A, "removeSalvation", 0, 254, nil, 400)
  Chk(page, "opt_salv_notify", A, "notifySalvation", 0, 280, nil, 400)
end

local function BuildMessages(page)
  Section(page, "sec_messages", 0)
  Paragraph(page, "msg_hint", 0, 28, 490, 44)
  local names = { "fail", "used", "cd", "opening" }
  for i = 1, table.getn(names) do
    local name = names[i]
    local e = UI.Edit(page, "msg_label_" .. name, 490, function()
      return TS.Announcer.Template(name)
    end, function(v)
      v = TS.Trim(v)
      if v == "" or v == TS.Announcer.DefaultTemplate(name) then
        A().messages[name] = nil
      else
        A().messages[name] = v
      end
    end)
    UI.Place(e, 0, 76 + (i - 1) * 52)
  end
  local test = UI.Button(page, "btn_test", 170, 26, function() TS.Announcer.Test() end)
  UI.Place(test, 0, 292)
  local reset = UI.Button(page, "btn_reset_msgs", 170, 26, function()
    A().messages = {}
    M.RefreshAll()
  end)
  UI.Place(reset, 180, 292)
end

local COLOR_ROWS = {
  { "me", "col_me", "prev_me" },
  { "tank", "col_tank", "prev_tank" },
  { "other", "col_other", "prev_other" },
  { "none", "col_none", "prev_none" },
  { "pet", "col_pet", "prev_pet" },
}

local function BuildPlates(page)
  Section(page, "sec_plates", 0)
  local restyle = function() TS.Nameplates.RefreshStyle() end
  Chk(page, "opt_colorbar", P, "colorBar", 0, 28, "tip_colorbar", 240)
  Chk(page, "opt_showtext", P, "showText", 250, 28, "tip_showtext", 240)
  Chk(page, "opt_showicon", P, "showIcon", 0, 52, nil, 240)
  Chk(page, "opt_showonme", P, "showOnMe", 250, 52, "tip_showonme", 240)
  Chk(page, "opt_combatonly", P, "combatOnly", 0, 76, "tip_combatonly", 240)
  Chk(page, "opt_pertank", P, "perTankColor", 250, 76, "tip_pertank", 240)

  local pos = UI.Cycle(page, "opt_textpos", { { "TOP", "pos_top" }, { "BOTTOM", "pos_bottom" } },
    function() return P().textPos end, function(v) P().textPos = v; restyle() end)
  UI.Place(pos, 0, 106)
  local size = UI.Slider(page, "opt_fontsize", 8, 16, 1,
    function() return P().fontSize end, function(v) P().fontSize = v; restyle() end)
  UI.Place(size, 0, 134)

  Section(page, "sec_colors", 172)
  for i = 1, table.getn(COLOR_ROWS) do
    local row = COLOR_ROWS[i]
    local state = row[1]
    local y = 200 + (i - 1) * 28
    local sw = UI.Swatch(page, row[2], function() return P().colors[state] end, function(r, g, b)
      P().colors[state] = { r, g, b, 1 }
    end)
    UI.Place(sw, 0, y)

    -- live mini nameplate
    local bar = UI.Solid(page, "ARTWORK", { 1, 1, 1, 1 })
    bar:SetWidth(70)
    bar:SetHeight(8)
    bar:SetPoint("TOPLEFT", page, "TOPLEFT", 290, -(y + 8))
    local label = UI.LText(page, row[3], 11, C.text)
    label:SetPoint("LEFT", bar, "RIGHT", 10, 0)
    table.insert(UI.widgets, { Refresh = function()
      local c = P().colors[state]
      bar:SetVertexColor(c[1], c[2], c[3], 1)
    end })
  end
  UI.OnColorChanged = function() M.RefreshAll() end

  local rc = UI.Button(page, "btn_reset_colors", 190, 24, function()
    P().colors = TS.DeepCopy(TS.defaults.plates.colors)
    M.RefreshAll()
  end)
  UI.Place(rc, 0, 346)
end

----------------------------------------------------------------------
-- Tanks page
----------------------------------------------------------------------
local ROWS = 8

local function TankRows(page)
  local R = TS.Roster
  M.tankRows = {}
  M.tankPage = 1

  for i = 1, ROWS do
    local row = CreateFrame("Frame", nil, page)
    row:SetWidth(490)
    row:SetHeight(24)
    UI.Place(row, 0, 150 + (i - 1) * 26)
    UI.Box(row, (math.mod(i, 2) == 0) and C.panel or C.side, C.side)
    row.name = UI.Text(row, "", 12, C.text)
    row.name:SetPoint("LEFT", row, "LEFT", 10, 0)
    row.src = UI.Text(row, "", 11, C.dim)
    row.src:SetPoint("LEFT", row, "LEFT", 170, 0)
    row.swatch = UI.SwatchButton(row, function() return row.data and row.data.color or C.dim end,
      function(r, g, b)
        local d = row.data
        if not d then return end
        if not TS.db.tanks[d.name] then R.Promote(d.name) end
        TS.db.tanks[d.name].color = { r, g, b, 1 }
        M.RefreshTanks()
      end, 46, 16)
    row.swatch:SetPoint("LEFT", row, "LEFT", 300, 0)
    row.promote = UI.Button(row, "btn_keep", 60, 18, function()
      local d = row.data
      if d then R.Promote(d.name); M.RefreshTanks() end
    end)
    row.promote:SetPoint("LEFT", row, "LEFT", 356, 0)
    row.remove = UI.Button(row, "btn_remove", 60, 18, function()
      local d = row.data
      if not d then return end
      if d.source == "manual" then R.RemoveManual(d.name) else R.signals[d.name] = nil end
      M.RefreshTanks()
    end)
    row.remove:SetPoint("LEFT", row, "LEFT", 422, 0)
    row:Hide()
    M.tankRows[i] = row
  end
end

function M.RefreshTanks()
  if not M.tankRows then return end
  local R = TS.Roster
  local list = R.ListTanks()
  local pages = math.max(1, math.ceil(table.getn(list) / ROWS))
  if M.tankPage > pages then M.tankPage = pages end
  if M.tankPage < 1 then M.tankPage = 1 end
  for i = 1, ROWS do
    local row = M.tankRows[i]
    local d = list[(M.tankPage - 1) * ROWS + i]
    row.data = d
    if d then
      local r, g, b = TS.ClassColor(d.class)
      if not d.inGroup then r, g, b = r * 0.6, g * 0.6, b * 0.6 end
      row.name:SetText(TS.Hex(r, g, b) .. d.name .. "|r")
      row.src:SetText(TS.L("src_" .. d.source))
      row.swatch.Refresh()
      if d.source == "manual" then row.promote:Hide() else row.promote:Show() end
      if d.source == "mt" then row.remove:Hide() else row.remove:Show() end
      row:Show()
    else
      row:Hide()
    end
  end
  M.tankInfo:SetText(TS.Lf("tank_page", M.tankPage, pages))
  if table.getn(list) == 0 then
    M.tankEmpty:Show()
  else
    M.tankEmpty:Hide()
  end
end

local function BuildTanks(page)
  local R = TS.Roster
  Section(page, "sec_tanks", 0)
  Paragraph(page, "tanks_desc", 0, 28, 490, 32)

  local addTarget = UI.Button(page, "btn_add_target", 150, 24, function()
    local ok, name = R.AddManual(nil)
    if ok then TS.Print(TS.Lf("tank_added", name)) else TS.Print(TS.L("tank_add_fail")) end
    M.RefreshTanks()
  end)
  UI.Place(addTarget, 0, 66)
  UI.Tip(addTarget, "tip_add_target")

  local box = UI.EditInline(page, 130)
  UI.Place(box, 160, 67)
  local function addByName()
    local txt = TS.Trim(box:GetText() or "")
    if txt == "" then return end
    local ok, name = R.AddManual(txt)
    if ok then
      TS.Print(TS.Lf("tank_added", name))
      box:SetText("")
    end
    M.RefreshTanks()
  end
  box:SetScript("OnEnterPressed", function() addByName(); this:ClearFocus() end)
  local addName = UI.Button(page, "btn_add_name", 90, 24, addByName)
  UI.Place(addName, 298, 66)

  Chk(page, "opt_autodetect", function() return TS.db.tankOpts end, "autoDetect", 0, 100, "tip_autodetect", 240,
    function() M.RefreshTanks() end)
  Chk(page, "opt_raidrole", function() return TS.db.tankOpts end, "useRaidRole", 250, 100, "tip_raidrole", 240,
    function() M.RefreshTanks() end)

  local hx = { { "th_name", 10 }, { "th_source", 170 }, { "th_color", 300 } }
  for i = 1, table.getn(hx) do
    local head = UI.LText(page, hx[i][1], 11, C.dim)
    head:SetPoint("TOPLEFT", page, "TOPLEFT", hx[i][2], -132)
  end

  TankRows(page)

  local prev = UI.Button(page, "btn_prev", 60, 22, function()
    M.tankPage = M.tankPage - 1
    M.RefreshTanks()
  end)
  UI.Place(prev, 0, 362)
  local nextb = UI.Button(page, "btn_next", 60, 22, function()
    M.tankPage = M.tankPage + 1
    M.RefreshTanks()
  end)
  UI.Place(nextb, 70, 362)
  M.tankInfo = UI.Text(page, "", 11, C.dim)
  M.tankInfo:SetPoint("LEFT", nextb, "RIGHT", 12, 0)
  M.tankEmpty = UI.LText(page, "tanks_empty", 11, C.dim)
  M.tankEmpty:SetPoint("TOPLEFT", page, "TOPLEFT", 10, -158)

  local clear = UI.Button(page, "btn_clear", 150, 22, function()
    TS.db.tanks = {}
    M.RefreshTanks()
  end)
  UI.Place(clear, 340, 362)

  -- the roster changes while the menu is open: keep the list alive
  local acc = 0
  page:SetScript("OnUpdate", function()
    acc = acc + (arg1 or 0)
    if acc >= 1 then
      acc = 0
      M.RefreshTanks()
    end
  end)
  table.insert(UI.widgets, { Refresh = function() M.RefreshTanks() end })
end

local function BuildAbout(page)
  Section(page, "sec_about", 0)
  Paragraph(page, "about_text", 0, 28, 490, 88, C.text)
  Section(page, "sec_commands", 124)
  local keys = { "help_menu", "help_add", "help_remove", "help_list", "help_clear", "help_test", "help_toggle", "help_lang" }
  for i = 1, table.getn(keys) do
    local fs = UI.LText(page, keys[i], 11, C.text)
    fs:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -(154 + (i - 1) * 18))
  end
  Paragraph(page, "about_warn", 0, 322, 490, 60, C.dim)
end

local BUILDERS = {
  general = BuildGeneral, announce = BuildAnnounce, maintank = BuildMainTank,
  messages = BuildMessages, plates = BuildPlates, tanks = BuildTanks, about = BuildAbout,
}

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------
function M.Select(id)
  M.current = id
  for pid, page in pairs(M.pages) do
    if pid == id then page:Show() else page:Hide() end
  end
  for i = 1, table.getn(TABS) do
    local t = M.tabs[TABS[i][1]]
    if TABS[i][1] == id then
      t.bar:Show()
      t.hl:Show()
    else
      t.bar:Hide()
      t.hl:Hide()
    end
  end
  for i = 1, table.getn(TABS) do
    if TABS[i][1] == id then M.title:SetText(TS.L(TABS[i][2])) end
  end
  if id == "tanks" then M.RefreshTanks() end
end

function M.RefreshAll()
  UI.RefreshAll()
  if M.title then M.Select(M.current) end
end

function M.Build()
  if M.frame then return end
  local w = CreateFrame("Frame", "TankSuiteMenu", UIParent)
  M.frame = w
  w:SetWidth(704)
  w:SetHeight(496)
  w:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
  w:SetFrameStrata("DIALOG")
  w:SetMovable(true)
  w:EnableMouse(true)
  if w.SetClampedToScreen then w:SetClampedToScreen(true) end
  UI.Box(w, C.bg, C.border)
  table.insert(UISpecialFrames, "TankSuiteMenu")

  -- sidebar
  local side = CreateFrame("Frame", nil, w)
  side:SetWidth(176)
  side:SetPoint("TOPLEFT", w, "TOPLEFT", 1, -1)
  side:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", 1, 1)
  UI.Box(side, C.side, C.side)
  local logo = UI.Text(side, "|cff33a0f2Tank|r|cffffffffSuite|r", 19, C.text)
  logo:SetPoint("TOPLEFT", side, "TOPLEFT", 16, -16)
  local ver = UI.Text(side, "v" .. TS.version, 10, C.dim)
  ver:SetPoint("TOPLEFT", side, "TOPLEFT", 18, -40)

  for i = 1, table.getn(TABS) do
    local id, key, icon = TABS[i][1], TABS[i][2], TABS[i][3]
    local tab = CreateFrame("Button", nil, side)
    tab:SetWidth(174)
    tab:SetHeight(38)
    tab:SetPoint("TOPLEFT", side, "TOPLEFT", 0, -(66 + (i - 1) * 38))
    tab.hl = UI.Solid(tab, "BACKGROUND", C.btnHi)
    tab.hl:SetAllPoints(tab)
    tab.hl:Hide()
    tab.bar = UI.Solid(tab, "ARTWORK", C.accent)
    tab.bar:SetWidth(3)
    tab.bar:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    tab.bar:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
    tab.bar:Hide()
    local tex = tab:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(icon)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tex:SetWidth(22)
    tex:SetHeight(22)
    tex:SetPoint("LEFT", tab, "LEFT", 14, 0)
    local label = UI.LText(tab, key, 12, C.text)
    label:SetPoint("LEFT", tex, "RIGHT", 10, 0)
    tab:SetScript("OnClick", function() PlaySound("igMainMenuOption"); M.Select(id) end)
    tab:SetScript("OnEnter", function()
      if M.current ~= id then this.hl:Show() end
    end)
    tab:SetScript("OnLeave", function()
      if M.current ~= id then this.hl:Hide() end
    end)
    M.tabs[id] = tab
  end

  -- header (drag handle + title + close)
  local hdr = CreateFrame("Frame", nil, w)
  hdr:SetHeight(48)
  hdr:SetPoint("TOPLEFT", w, "TOPLEFT", 177, -1)
  hdr:SetPoint("TOPRIGHT", w, "TOPRIGHT", -1, -1)
  hdr:EnableMouse(true)
  hdr:RegisterForDrag("LeftButton")
  hdr:SetScript("OnDragStart", function() this:GetParent():StartMoving() end)
  hdr:SetScript("OnDragStop", function() this:GetParent():StopMovingOrSizing() end)
  M.title = UI.Text(hdr, "", 16, C.text)
  M.title:SetPoint("LEFT", hdr, "LEFT", 14, 0)
  local line = UI.Solid(hdr, "ARTWORK", C.border)
  line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 14, 0)
  line:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", -14, 0)

  local close = CreateFrame("Button", nil, hdr)
  close:SetWidth(24)
  close:SetHeight(24)
  close:SetPoint("RIGHT", hdr, "RIGHT", -14, 0)
  UI.Box(close, C.btn, C.border)
  local x = UI.Text(close, "x", 13, C.text)
  x:SetPoint("CENTER", close, "CENTER", 0, 1)
  x:SetJustifyH("CENTER")
  close:SetScript("OnClick", function() w:Hide() end)
  close:SetScript("OnEnter", function() this:SetBackdropBorderColor(C.bad[1], C.bad[2], C.bad[3], 1) end)
  close:SetScript("OnLeave", function() this:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1) end)

  -- pages
  local content = CreateFrame("Frame", nil, w)
  content:SetPoint("TOPLEFT", w, "TOPLEFT", 192, -62)
  content:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -14, 14)
  for i = 1, table.getn(TABS) do
    local id = TABS[i][1]
    local page = CreateFrame("Frame", nil, content)
    page:SetAllPoints(content)
    page:Hide()
    M.pages[id] = page
    BUILDERS[id](page)
  end

  M.RefreshAll()
  M.Select(M.current)
  w:Hide()
end

function M.Toggle()
  if not M.frame then
    local ok, err = pcall(M.Build)
    if not ok then
      -- do not keep a half-built window: the next /tks tries again from scratch
      if M.frame then M.frame:Hide() end
      M.frame, M.pages, M.tabs = nil, {}, {}
      TS.Print("|cffff5555" .. TS.L("menu_error") .. "|r " .. tostring(err))
      return
    end
  end
  if M.frame:IsShown() then
    M.frame:Hide()
  else
    M.RefreshAll()
    M.frame:Show()
  end
end

TS.ToggleMenu = M.Toggle
TS.RefreshMenu = function()
  if M.frame then M.RefreshAll() end
end

----------------------------------------------------------------------
-- Minimap button
----------------------------------------------------------------------
function M.PlaceMinimap()
  local b = M.minimap
  if not b then return end
  if not TS.db.minimapShow then
    b:Hide()
    return
  end
  local rad = math.rad(TS.db.minimapAngle)
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(rad), 80 * math.sin(rad))
  b:Show()
end

function M.BuildMinimap()
  local b = CreateFrame("Button", "TankSuiteMinimapButton", Minimap)
  M.minimap = b
  b:SetWidth(32)
  b:SetHeight(32)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture(ICON .. "Ability_Warrior_DefensiveStance")
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  icon:SetWidth(20)
  icon:SetHeight(20)
  icon:SetPoint("CENTER", b, "CENTER", 0, 0)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetWidth(54)
  border:SetHeight(54)
  border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")

  b:SetScript("OnClick", function()
    if arg1 == "RightButton" then
      TS.db.plates.enabled = not TS.db.plates.enabled
      TS.Print("Nameplates: " .. (TS.db.plates.enabled and "|cff44ff44ON|r" or "|cffff5555OFF|r"))
      TS.RefreshMenu()
    else
      M.Toggle()
    end
  end)
  b:SetScript("OnDragStart", function() this.dragging = true end)
  b:SetScript("OnDragStop", function() this.dragging = false end)
  b:SetScript("OnUpdate", function()
    if not this.dragging then return end
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    TS.db.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
    M.PlaceMinimap()
  end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("TankSuite", 0.2, 0.63, 0.95)
    GameTooltip:AddLine(TS.L("mm_left"), 1, 1, 1)
    GameTooltip:AddLine(TS.L("mm_right"), 1, 1, 1)
    GameTooltip:AddLine(TS.L("mm_drag"), 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  M.PlaceMinimap()
end

TS.OnInit(function()
  M.BuildMinimap()
end)
