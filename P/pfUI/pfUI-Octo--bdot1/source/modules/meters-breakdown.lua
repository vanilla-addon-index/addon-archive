pfUI:RegisterModule("meters-breakdown", "vanilla", function ()
  -- pfUI Octo :: the breakdown window (meters phase 3, Details!' "player
  -- details" as the model - Details! is All Rights Reserved, nothing of it is
  -- copied). Clicking any bar of a meter window opens it. 23 Oct 2026 (user:
  -- "extra frames ... should carry the same UI look and store vast info from
  -- the meters every bit of info should be in there easy to manage and linked
  -- with easy click through menus") it shows everything the meter keeps, in
  -- the window's own look, and every name in it is a link:
  --   a player   Summary, Spells, Targets, Taken, Casts, Auras, Utility,
  --              Deaths, Chart, Compare. Spells / Targets / Chart / Compare
  --              switch between damage, healing and friendly fire.
  --   an enemy   Summary, Hit by, Spells on it, It hit, Its spells
  --   a spell    (damage taken by spell) who it hit, who cast it
  -- Clicking a player, enemy or spell anywhere opens it; Back goes back; the
  -- name in the header lists everyone in the fight, Enemies every enemy.
  local M = pfUI.meters
  if not M or not M.ShowDetails or not M.MODES then return end

  local floor, max, min = math.floor, math.max, math.min
  local Num = M.Num
  local Clock = M.Clock or function(t) t = max(0, floor(t or 0)) return string.format("%d:%02d", floor(t / 60), math.mod(t, 60)) end
  local MODE = {}
  for _, m in ipairs(M.MODES) do MODE[m.key] = m end
  local function Pct(part, all) return (all and all > 0) and string.format("%.1f%%", part / all * 100) or "-" end
  local function Avg(total, n) return n > 0 and Num(total / n) or "-" end
  local HEALMODES = { heal = true, hps = true, overheal = true, htaken = true }
  local LINK = "|cff7fbfff"

  local B = { tab = "spells", stack = {} }
  M.breakdown = B

  -- ---------------------------------------------------------------- the frame

  local W, H = 900, 530
  local f = CreateFrame("Frame", "pfMeterBreakdown", UIParent)
  f:SetWidth(W)
  f:SetHeight(H)
  f:SetPoint("CENTER", 0, 40)
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:SetMovable(true) this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:Hide()
  CreateBackdrop(f, nil, true, .94)
  CreateBackdropShadow(f)
  table.insert(UISpecialFrames, "pfMeterBreakdown")
  B.frame = f

  local texts = {}
  local function Text(parent, size, justify)
    local t = parent:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    t:SetFont(pfUI.font_default, size or C.global.font_size, "OUTLINE")
    t:SetJustifyH(justify or "LEFT")
    t.base = size or C.global.font_size
    table.insert(texts, t)
    return t
  end

  f.icon = f:CreateTexture(nil, "OVERLAY")
  f.icon:SetWidth(22)
  f.icon:SetHeight(22)
  f.icon:SetPoint("TOPLEFT", 10, -8)

  -- a small text button
  local function Button(parent, label, width, func, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(width)
    b:SetHeight(20)
    CreateBackdrop(b, nil, true, .8)
    b.text = Text(b, C.global.font_size, "CENTER")
    b.text:SetAllPoints(b)
    b.text:SetText(label)
    b:SetScript("OnClick", func)
    b:SetScript("OnEnter", function()
      local r, g, bb = GetAccentColor()
      if this.backdrop then this.backdrop:SetBackdropBorderColor(r, g, bb, 1) end
      if this.tip then
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText(this.tip, 1, 1, 1)
        GameTooltip:Show()
      end
    end)
    b:SetScript("OnLeave", function()
      if this.backdrop then
        if this.lit then
          local r, g, bb = GetAccentColor()
          this.backdrop:SetBackdropBorderColor(r, g, bb, 1)
        else
          this.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
        end
      end
      GameTooltip:Hide()
    end)
    b.tip = tip
    return b
  end
  B.Button = Button

  -- the header: the name opens a list of everyone in the fight
  f.who = Button(f, "", 200, function() B.PeopleMenu(this) end, "Everyone in this fight: click one to open them")
  f.who:SetPoint("LEFT", f.icon, "RIGHT", 6, 0)
  f.name = f.who.text
  f.name:ClearAllPoints()
  f.name:SetPoint("LEFT", f.who, "LEFT", 6, 0)
  f.who.text.base = C.global.font_size + 4
  f.name:SetFont(pfUI.font_default, C.global.font_size + 4, "OUTLINE")
  f.sub = Text(f, C.global.font_size)
  f.sub:SetPoint("LEFT", f.who, "RIGHT", 10, 0)
  f.sub:SetTextColor(.6, .6, .6)

  f.close = Button(f, "X", 20, function() f:Hide() end)
  f.close:SetPoint("TOPRIGHT", -8, -8)
  f.report = Button(f, "Report", 64, function() B.ReportMenu(this) end, "Send this tab to chat")
  f.report:SetPoint("RIGHT", f.close, "LEFT", -4, 0)
  f.next = Button(f, ">", 22, function() B.Step(1) end, "Next in the window")
  f.next:SetPoint("RIGHT", f.report, "LEFT", -8, 0)
  f.prev = Button(f, "<", 22, function() B.Step(-1) end, "Previous in the window")
  f.prev:SetPoint("RIGHT", f.next, "LEFT", -2, 0)
  f.foes = Button(f, "Enemies", 70, function() B.FoeMenu(this) end, "Every enemy in this fight: click one to open it")
  f.foes:SetPoint("RIGHT", f.prev, "LEFT", -8, 0)
  f.back = Button(f, "< Back", 60, function() B.Back() end, "Back to what was open before")
  f.back:SetPoint("RIGHT", f.foes, "LEFT", -4, 0)

  -- tabs (the set depends on what is open)
  B.TABS = { { "summary", "Summary" }, { "spells", "Spells" }, { "targets", "Targets" }, { "taken", "Taken" },
             { "casts", "Casts" }, { "auras", "Auras" }, { "utility", "Utility" }, { "deaths", "Deaths" },
             { "chart", "Chart" }, { "compare", "Compare" } }
  B.FOETABS = { { "fsummary", "Summary" }, { "fhitby", "Hit by" }, { "ftaken", "Spells on it" }, { "fhit", "It hit" },
                { "fspells", "Its spells" } }
  B.SPELLTABS = { { "ssummary", "Who it hit" }, { "sfrom", "Who cast it" } }
  -- what is shown: every display of the windows, by group (user, 23 Oct
  -- 2026: "add in here at the top selectors for all the options so we can
  -- quickly look all in this window"); the group in use is lit
  B.GROUPS = {}
  local seenGroup = {}
  for _, m in ipairs(M.MODES) do
    if m.group and not seenGroup[m.group] and m.key ~= "threat" then
      seenGroup[m.group] = true
      table.insert(B.GROUPS, m.group)
    end
  end
  f.showing = Text(f, C.global.font_size)
  f.showing:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -42)
  f.showing:SetText("Showing")
  f.showing:SetTextColor(.6, .6, .6)
  f.groups = {}
  for i, g in ipairs(B.GROUPS) do
    local group = g
    local b = Button(f, group, 150, function() B.ModeMenu(this, group) end, "Pick a " .. string.lower(group) .. " display")
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 70 + (i - 1) * 156, -38)
    b.group = group
    f.groups[i] = b
  end
  function B.ModeMenu(anchor, group)
    local items = { { group, head = true } }
    for _, m in ipairs(M.MODES) do
      if m.group == group and m.key ~= "threat" and (not m.shown or m.shown()) then
        local key = m.key
        table.insert(items, { m.name, function() B.SetMode(key) end, checked = key == B.mode })
      end
    end
    M.ShowMenu(anchor, items)
  end
  -- a new display: players keep the one open (or the top one); enemy and
  -- spell displays open their top row
  function B.SetMode(key)
    local mode = MODE[key]
    if not mode then return end
    B.mode, B.kind = key, nil
    B.offset, B.lineOffset, B.spell, B.target, B.death = 0, 0, nil, nil, nil
    local rows = M.Rows(key, B.segment)
    if mode.rows then
      local r = rows[1]
      if r and r.foe then B.actor, B.foe, B.bspell, B.tab = nil, r.name, nil, key == "enemydone" and "fhit" or "fsummary"
      elseif r and r.byspell then B.actor, B.foe, B.bspell, B.tab = nil, nil, r.name, "ssummary" end
    else
      if not B.actor and rows[1] and rows[1].actor then B.actor = rows[1].actor end
      B.foe, B.bspell = nil, nil
      B.tab = B.FIRSTTAB and B.FIRSTTAB[key] or "spells"
    end
    B.Draw()
  end
  local function PaintGroups()
    local cur = MODE[B.mode]
    for _, b in ipairs(f.groups) do
      local on = cur and cur.group == b.group
      b.lit = on
      b.text:SetText(on and (cur.name .. "  v") or (b.group .. "  v"))
      if b.backdrop then
        if on then
          local ar, ag, ab = GetAccentColor()
          b.backdrop:SetBackdropBorderColor(ar, ag, ab, 1)
          b.backdrop:SetBackdropColor(ar * .45, ag * .45, ab * .45, .9)
        else
          b.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
          b.backdrop:SetBackdropColor(0, 0, 0, .8)
        end
      end
    end
  end
  B.PaintGroups = PaintGroups

  f.tabs = {}
  for i = 1, 10 do
    local b = Button(f, "", 84, function()
      B.tab = this.key
      B.offset = 0
      B.Draw()
    end)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 10 + (i - 1) * 88, -64)
    b.line = b:CreateTexture(nil, "OVERLAY")
    b.line:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.line:SetHeight(2)
    b.line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 1, 1)
    b.line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    f.tabs[i] = b
  end

  -- damage / healing / friendly fire, over the list of the tabs that use it
  B.KINDS = { { "damage", "Damage" }, { "heal", "Healing" }, { "ff", "Friendly fire" } }
  f.kinds = {}
  for i, k in ipairs(B.KINDS) do
    local key = k[1]
    local b = Button(f, k[2], 96, function() B.kind = key B.spell = nil B.offset = 0 B.Draw() end)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 10 + (i - 1) * 100, -90)
    b.key = key
    f.kinds[i] = b
  end
  local KINDTABS = { spells = true, targets = true, chart = true, compare = true }

  -- the body: a list of bars on the left, a panel of lines on the right
  local BODY_TOP, ROWH = -116, 18
  local LIST_W = 470
  f.list = CreateFrame("Frame", nil, f)
  f.list:SetPoint("TOPLEFT", f, "TOPLEFT", 10, BODY_TOP)
  f.list:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
  f.list:SetWidth(LIST_W)
  f.list:EnableMouseWheel(true)
  f.list:SetScript("OnMouseWheel", function()
    B.offset = max(0, (B.offset or 0) - (arg1 or 0) * 3)
    B.Draw()
  end)
  f.panel = CreateFrame("Frame", nil, f)
  f.panel:SetPoint("TOPLEFT", f.list, "TOPRIGHT", 10, 0)
  f.panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
  CreateBackdrop(f.panel, nil, true, .5)
  f.panel:EnableMouseWheel(true)
  f.panel:SetScript("OnMouseWheel", function()
    B.lineOffset = max(0, (B.lineOffset or 0) - (arg1 or 0) * 3)
    B.Draw()
  end)
  f.rows, f.lines = {}, {}
  local MAXROWS = floor((H + BODY_TOP - 10) / (ROWH + 2))
  local MAXLINES = floor((H + BODY_TOP - 22) / 16)
  B.MAXROWS = MAXROWS

  local function Row(i)
    local r = f.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, f.list)
    r:SetHeight(ROWH)
    r:SetPoint("TOPLEFT", f.list, "TOPLEFT", 0, -(i - 1) * (ROWH + 2))
    r:SetPoint("RIGHT", f.list, "RIGHT", 0, 0)
    r.bar = CreateFrame("StatusBar", nil, r)
    r.bar:SetAllPoints(r)
    r.bar:SetMinMaxValues(0, 1)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints(r)
    r.bg:SetTexture(1, 1, 1, .05)
    r.sel = r:CreateTexture(nil, "OVERLAY")
    r.sel:SetAllPoints(r)
    r.sel:SetTexture(1, 1, 1, .12)
    r.sel:Hide()
    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetAllPoints(r)
    r.hl:SetTexture(1, 1, 1, .08)
    r.left = Text(r.bar, C.global.font_size)
    r.left:SetPoint("LEFT", r, "LEFT", 4, 0)
    r.right = Text(r.bar, C.global.font_size, "RIGHT")
    r.right:SetPoint("RIGHT", r, "RIGHT", -4, 0)
    r.left:SetPoint("RIGHT", r.right, "LEFT", -6, 0)
    r:SetScript("OnClick", function() if this.onclick then this.onclick() end end)
    r:SetScript("OnEnter", function()
      if not this.tip then return end
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetText(this.tip, 1, 1, 1)
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.rows[i] = r
    return r
  end

  -- a line on the right panel: label and value; a line with `go` is a link
  local function Line(i)
    local l = f.lines[i]
    if l then return l end
    l = {}
    l.btn = CreateFrame("Button", nil, f.panel)
    l.btn:SetHeight(16)
    l.btn:SetPoint("TOPLEFT", f.panel, "TOPLEFT", 4, -4 - (i - 1) * 16)
    l.btn:SetPoint("RIGHT", f.panel, "RIGHT", -4, 0)
    l.btn.hl = l.btn:CreateTexture(nil, "HIGHLIGHT")
    l.btn.hl:SetAllPoints(l.btn)
    l.btn.hl:SetTexture(1, 1, 1, .08)
    l.btn:SetScript("OnClick", function() if this.go then this.go() end end)
    l.label = Text(f.panel, C.global.font_size)
    l.label:SetPoint("TOPLEFT", f.panel, "TOPLEFT", 8, -6 - (i - 1) * 16)
    l.value = Text(f.panel, C.global.font_size, "RIGHT")
    l.value:SetPoint("TOPRIGHT", f.panel, "TOPRIGHT", -8, -6 - (i - 1) * 16)
    f.lines[i] = l
    return l
  end

  -- ---------------------------------------------------------------- filling

  local texture = "Interface\\AddOns\\pfUI\\img\\bar_elvui"
  local cr, cg, cb = .6, .6, .6

  -- list: { { name, value, text, onclick, selected, color, tip } }
  local function FillList(list, maxv)
    local off = B.offset or 0
    if off > max(0, table.getn(list) - MAXROWS) then off = max(0, table.getn(list) - MAXROWS) B.offset = off end
    for i = 1, MAXROWS do
      local e = list[i + off]
      local r = Row(i)
      if e then
        r.bar:SetStatusBarTexture(texture)
        local c = e.color
        r.bar:SetStatusBarColor(c and c[1] or cr, c and c[2] or cg, c and c[3] or cb, .8)
        r.bar:SetValue((maxv and maxv > 0 and e.value) and e.value / maxv or 0)
        r.left:SetText((e.link and LINK or "") .. e.name .. (e.link and "|r" or ""))
        r.right:SetText(e.text or "")
        r.onclick, r.tip = e.onclick, e.tip
        if e.selected then r.sel:Show() else r.sel:Hide() end
        r:Show()
      else
        r:Hide()
      end
    end
    B.listShown = list
  end

  -- lines: { { label, value, head, go } }
  local function FillLines(lines)
    local ar, ag, ab = GetAccentColor()
    local off = B.lineOffset or 0
    if off > max(0, table.getn(lines) - MAXLINES) then off = max(0, table.getn(lines) - MAXLINES) B.lineOffset = off end
    for i = 1, max(MAXLINES, table.getn(f.lines)) do
      local e = i <= MAXLINES and lines[i + off]
      local l = Line(i)
      if e then
        l.label:SetText(e[1] or "")
        l.value:SetText(e[2] or "")
        if e.head then l.label:SetTextColor(ar, ag, ab)
        elseif e.go then l.label:SetTextColor(.5, .75, 1)
        else l.label:SetTextColor(.85, .85, .85) end
        l.label:Show()
        l.value:Show()
        l.btn.go = e.go
        if e.go then l.btn:Show() else l.btn:Hide() end
      else
        l.label:Hide()
        l.value:Hide()
        l.btn:Hide()
      end
    end
    B.linesShown = lines
  end

  local function Sorted(tbl, field)
    local out = {}
    for name, v in pairs(tbl or {}) do
      local x = field and v[field] or v
      if type(x) == "number" then table.insert(out, { name = name, v = x, data = v }) end
    end
    table.sort(out, function(x, y) return x.v > y.v end)
    return out
  end

  -- ---------------------------------------------------------------- links

  local function Seg() return B.seg end
  -- a name as a link: a player of the fight, an enemy, or nothing
  local function Link(name)
    local seg = Seg()
    if not seg or not name then return end
    if seg.actors and seg.actors[name] then return function() B.Open({ actor = seg.actors[name] }) end end
    if seg.foes and seg.foes[name] then return function() B.Open({ foe = name }) end end
  end
  B.Link = Link
  local function Named(name)
    if Link(name) then return LINK .. name .. "|r" end
    return name
  end
  -- "Spell - Source": the source part
  local function SourceOf(label)
    local _, _, spell, who = string.find(label or "", "^(.-) %- (.+)$")
    return spell or label, who
  end

  -- ---------------------------------------------------------------- player tabs

  -- the spells of an actor: list, total, heal?
  local function SpellsOf(a, mode)
    if mode == "taken" then return a.tspells, a.taken end
    if mode == "ff" then return a.ffspells or {}, a.ff or 0 end
    if mode == "heal" or HEALMODES[mode] then return a.hspells, a.heal, true end
    return a.spells, a.damage
  end
  local function TargetsOf(a, mode)
    if mode == "taken" then return a.sources, a.taken, "Damaged by" end
    if mode == "htaken" then return a.hsources or {}, a.htaken or 0, "Healed by" end
    if mode == "ff" then return a.fftargets or {}, a.ff or 0, "Hit" end
    if mode == "heal" or HEALMODES[mode] then return a.htargets, a.heal, "Healed" end
    return a.targets, a.damage, "Targets"
  end
  B.SpellsOf, B.TargetsOf = SpellsOf, TargetsOf
  local function Kind() return B.kind or "damage" end

  -- one spell in detail (right panel)
  local function SpellLines(name, s, total, heal)
    local lines = { { name, "", head = true } }
    local n = s.hits + s.ticks
    table.insert(lines, { heal and "Healed" or "Damage", Num(s.total) .. "  (" .. Pct(s.total, total) .. ")" })
    if B.active and B.active > 0 then table.insert(lines, { heal and "HPS" or "DPS", Num(s.total / B.active) }) end
    if s.hits > 0 then
      local crits = s.crits or 0
      local ctotal = s.ctotal or 0
      local normal = s.hits - crits
      -- (ticks apart: they are not hits)
      local ntotal = s.total - ctotal - (s.ttotal or 0)
      table.insert(lines, { "Hits", s.hits })
      table.insert(lines, { "  Normal", normal .. "   avg " .. Avg(max(0, ntotal), normal) })
      table.insert(lines, { "  Critical", crits .. "  (" .. Pct(crits, s.hits) .. ")   avg " .. Avg(ctotal, crits) })
      if s.cmax then table.insert(lines, { "  Biggest crit", Num(s.cmax) }) end
      table.insert(lines, { "  Smallest / biggest", (s.min and Num(s.min) or "-") .. " / " .. Num(s.max) })
    end
    if s.ticks > 0 then table.insert(lines, { "Ticks", s.ticks .. "   avg " .. Avg(s.ttotal or s.total, s.ticks) }) end
    if heal then
      table.insert(lines, { "Overhealing", Num(s.over or 0) .. "  (" .. Pct(s.over or 0, s.total + (s.over or 0)) .. ")" })
    elseif s.misses > 0 then
      table.insert(lines, { "Missed", s.misses .. "  (" .. Pct(s.misses, n + s.misses) .. ")" })
      for how, count in pairs(s.how or {}) do
        if how ~= "glancing" and how ~= "crushing" then table.insert(lines, { "  " .. how, count }) end
      end
    end
    if s.how and s.how.glancing then table.insert(lines, { "Glancing", s.how.glancing }) end
    if s.how and s.how.crushing then table.insert(lines, { "Crushing", s.how.crushing }) end
    if s.targets then
      table.insert(lines, { " ", "" })
      table.insert(lines, { "Targets", "", head = true })
      local list = Sorted(s.targets)
      for i = 1, min(8, table.getn(list)) do
        table.insert(lines, { list[i].name, Num(list[i].v) .. "  (" .. Pct(list[i].v, s.total) .. ")", go = Link(list[i].name) })
      end
    end
    return lines
  end
  B.SpellLines = SpellLines

  local function Summary(a, seg)
    local fight = seg and M.Duration(seg) or 1
    local act = max(1, a.active or 0)
    local function Go(tab, kind) return function() B.kind = kind or B.kind B.tab = tab B.offset = 0 B.Draw() end end
    local lines = { { "Damage and healing", "", head = true },
      { "Damage done", Num(a.damage) .. "   (" .. Num(a.damage / act) .. " dps)", go = Go("spells", "damage") },
      { "Healing done", Num(a.heal) .. "   (" .. Num(a.heal / act) .. " hps)", go = Go("spells", "heal") },
      { "Overhealing", Num(a.overheal) .. "  (" .. Pct(a.overheal, a.heal + a.overheal) .. ")", go = Go("spells", "heal") },
      { "Damage taken", Num(a.taken), go = Go("taken") },
      { "Healing taken", Num(a.htaken or 0), go = Go("taken") },
      { "Friendly fire", Num(a.ff or 0), go = Go("spells", "ff") },
      { "Time", "", head = true },
      { "Fight", Clock(fight) },
      { "Active", Clock(act) .. "  (" .. Pct(min(act, fight), fight) .. ")", go = Go("chart") },
      { "Utility", "", head = true },
      { "Interrupts / dispels", (a.interrupts or 0) .. " / " .. (a.dispels or 0), go = Go("utility") },
      { "Cooldowns used", a.cds or 0, go = Go("casts") },
      { "Resurrects", a.ress or 0, go = Go("casts") },
      { "Kills / deaths", (a.frags or 0) .. " / " .. (a.deaths or 0), go = Go((a.deaths or 0) > 0 and "deaths" or "utility") },
      { "Casts", a.ncasts or 0, go = Go("casts") },
      { "Buff / debuff uptime", Clock(a.buffsum or 0) .. " / " .. Clock(a.debuffsum or 0), go = Go("auras") },
    }
    -- resources gained
    for pow, v in pairs(a.power or {}) do table.insert(lines, { pow .. " gained", Num(v), go = Go("utility") }) end
    FillLines(lines)
    -- the left: top spells of the window's kind
    local spells, total = SpellsOf(a, Kind())
    local list = {}
    for _, e in ipairs(Sorted(spells, "total")) do
      local name = e.name
      table.insert(list, { name = name, value = e.v, text = Num(e.v) .. "  " .. Pct(e.v, total),
        onclick = function() B.spell = name B.tab = "spells" B.Draw() end })
    end
    FillList(list, list[1] and list[1].value)
  end

  local function Spells(a)
    local spells, total, heal = SpellsOf(a, Kind())
    local sorted = Sorted(spells, "total")
    if not B.spell or not spells[B.spell] then B.spell = sorted[1] and sorted[1].name end
    local list = {}
    for _, e in ipairs(sorted) do
      local name = e.name
      local s = e.data
      table.insert(list, { name = name, value = e.v,
        text = Num(e.v) .. "  " .. Pct(e.v, total) .. "  |cff888888" .. (s.hits + s.ticks) .. "x|r",
        selected = name == B.spell, onclick = function() B.spell = name B.lineOffset = 0 B.Draw() end })
    end
    FillList(list, sorted[1] and sorted[1].v)
    if B.spell and spells[B.spell] then FillLines(SpellLines(B.spell, spells[B.spell], total, heal)) else FillLines({ { "Nothing here in this fight.", "" } }) end
  end

  local function Targets(a)
    local tbl, total, title = TargetsOf(a, Kind())
    local spells = SpellsOf(a, Kind())
    local sorted = Sorted(tbl)
    if not B.target or not tbl[B.target] then B.target = sorted[1] and sorted[1].name end
    local list = {}
    for _, e in ipairs(sorted) do
      local name = e.name
      table.insert(list, { name = name, link = Link(name) and true, value = e.v, text = Num(e.v) .. "  " .. Pct(e.v, total),
        selected = name == B.target, onclick = function() B.target = name B.lineOffset = 0 B.Draw() end })
    end
    FillList(list, list[1] and list[1].value)
    local lines = { { title, "", head = true }, { "Total", Num(total) }, { "How many", table.getn(list) } }
    local t = B.target
    if t then
      table.insert(lines, { " ", "" })
      table.insert(lines, { t, "", head = true })
      local go = Link(t)
      if go then table.insert(lines, { "Open " .. t, "", go = go }) end
      -- which of this player's spells went there
      local by = {}
      for sname, s in pairs(spells or {}) do
        if s.targets and s.targets[t] then by[sname] = s.targets[t] end
      end
      for _, e in ipairs(Sorted(by)) do table.insert(lines, { "  " .. e.name, Num(e.v) }) end
      -- everyone else on that enemy
      local foe = B.seg and B.seg.foes and B.seg.foes[t]
      if foe and foe.from then
        table.insert(lines, { "Everyone on " .. t, "", head = true })
        for _, e in ipairs(Sorted(foe.from)) do
          table.insert(lines, { e.name, Num(e.v) .. "  (" .. Pct(e.v, foe.taken) .. ")", go = Link(e.name) })
        end
      end
    end
    FillLines(lines)
  end

  local function Taken(a)
    local sorted = Sorted(a.tspells, "total")
    if not B.spell or not a.tspells[B.spell] then B.spell = sorted[1] and sorted[1].name end
    local list = {}
    for _, e in ipairs(sorted) do
      local name = e.name
      local spell, who = SourceOf(name)
      table.insert(list, { name = spell .. "  |cff888888" .. (who or "") .. "|r", value = e.v,
        text = Num(e.v) .. "  " .. Pct(e.v, a.taken) .. "  |cff888888" .. e.data.hits .. "x|r", color = { .7, .25, .25 },
        selected = name == B.spell, onclick = function() B.spell = name B.lineOffset = 0 B.Draw() end })
    end
    FillList(list, sorted[1] and sorted[1].v)
    local lines = {}
    if B.spell and a.tspells[B.spell] then
      local s = a.tspells[B.spell]
      local spell, who = SourceOf(B.spell)
      table.insert(lines, { spell, "", head = true })
      table.insert(lines, { "From", who and Named(who) or "?", go = Link(who) })
      table.insert(lines, { "Damage", Num(s.total) .. "  (" .. Pct(s.total, a.taken) .. ")" })
      table.insert(lines, { "Hits / biggest", s.hits .. " / " .. Num(s.max) })
      table.insert(lines, { " ", "" })
    end
    table.insert(lines, { "Damaged by", Num(a.taken), head = true })
    for _, e in ipairs(Sorted(a.sources)) do
      table.insert(lines, { e.name, Num(e.v) .. "  (" .. Pct(e.v, a.taken) .. ")", go = Link(e.name) })
    end
    if next(a.avoid or {}) then
      table.insert(lines, { "Avoided", "", head = true })
      for how, n in pairs(a.avoid) do table.insert(lines, { "  " .. how, n }) end
    end
    if (a.htaken or 0) > 0 then
      table.insert(lines, { "Healed by", Num(a.htaken), head = true })
      for _, e in ipairs(Sorted(a.hsources)) do
        table.insert(lines, { e.name, Num(e.v) .. "  (" .. Pct(e.v, a.htaken) .. ")", go = Link(e.name) })
      end
    end
    FillLines(lines)
  end

  local function Casts(a)
    local sorted = Sorted(a.casts)
    local list = {}
    for _, e in ipairs(sorted) do
      local name = e.name
      -- a spell with numbers opens its detail
      local kind = (a.spells and a.spells[name] and "damage") or (a.hspells and a.hspells[name] and "heal")
      table.insert(list, { name = name, value = e.v, text = e.v .. "  " .. Pct(e.v, a.ncasts or 0),
        tip = kind and "Click: its numbers" or nil,
        onclick = kind and function() B.kind = kind B.spell = name B.tab = "spells" B.Draw() end or nil })
    end
    FillList(list, sorted[1] and sorted[1].v)
    local start = B.seg and B.seg.start or 0
    local lines = { { "Casts", (a.ncasts or 0) .. "  (" .. table.getn(sorted) .. " spells)", head = true } }
    table.insert(lines, { "Cooldowns used", a.cds or 0, head = true })
    for _, c in ipairs(a.cdlist or {}) do
      table.insert(lines, { Clock(c.t - start) .. "  " .. c.spell, c.target and Named(c.target) or "", go = Link(c.target) })
    end
    table.insert(lines, { "Resurrects", a.ress or 0, head = true })
    for _, c in ipairs(a.resslist or {}) do
      table.insert(lines, { Clock(c.t - start) .. "  " .. c.spell, c.target and Named(c.target) or "", go = Link(c.target) })
    end
    FillLines(lines)
  end

  local function Auras(a, seg)
    local fight = seg and M.Duration(seg) or 1
    local list = {}
    for _, e in ipairs(Sorted(a.buffs)) do
      table.insert(list, { name = e.name, value = e.v, text = Clock(e.v) .. "  " .. Pct(min(e.v, fight), fight), color = { .3, .7, .35 } })
    end
    for _, e in ipairs(Sorted(a.debuffs)) do
      table.insert(list, { name = e.name .. "  |cff888888(on enemies)|r", value = e.v, text = Clock(e.v) .. "  " .. Pct(min(e.v, fight), fight),
        color = { .6, .3, .7 } })
    end
    FillList(list, fight)
    FillLines({ { "Uptime", "", head = true },
      { "Buffs on " .. a.name, Clock(a.buffsum or 0) },
      { "Debuffs from " .. a.name, Clock(a.debuffsum or 0) },
      { "Fight", Clock(fight) },
      { " ", "" },
      { "Green: buffs on them, purple: their debuffs on enemies. Bars are % of the fight.", "" } })
  end

  local function Utility(a, seg)
    local start = seg and seg.start or 0
    local list = {}
    for _, e in ipairs(a.ilist or {}) do
      local tgt = e.target
      table.insert(list, { name = Clock(e.t - start) .. "  Interrupted " .. (e.spell or "?") .. " on " .. Named(tgt or "?"), value = 1,
        text = e.with and ("with " .. e.with) or "", color = { .9, .6, .2 }, onclick = Link(tgt) })
    end
    for _, e in ipairs(a.dlist or {}) do
      local tgt = e.target
      table.insert(list, { name = Clock(e.t - start) .. "  Removed " .. (e.aura or "?") .. " from " .. Named(tgt or "?"), value = 1,
        text = e.with and ("with " .. e.with) or "", color = { .3, .6, .9 }, onclick = Link(tgt) })
    end
    for _, e in ipairs(a.fraglist or {}) do
      local tgt = e.target
      table.insert(list, { name = Clock(e.t - start) .. "  Killed " .. Named(tgt or "?"), value = 1, text = "",
        color = { .7, .2, .2 }, onclick = Link(tgt) })
    end
    for _, e in ipairs(a.resslist or {}) do
      local tgt = e.target
      table.insert(list, { name = Clock(e.t - start) .. "  Resurrected " .. Named(tgt or "?"), value = 1, text = e.spell or "",
        color = { .3, .8, .4 }, onclick = Link(tgt) })
    end
    if table.getn(list) == 0 then table.insert(list, { name = "No interrupts, dispels, kills or resurrects in this fight.", value = 0 }) end
    FillList(list, 1)
    local lines = { { "Interrupts / dispels / kills", (a.interrupts or 0) .. " / " .. (a.dispels or 0) .. " / " .. (a.frags or 0), head = true } }
    for pow, v in pairs(a.power or {}) do
      table.insert(lines, { pow .. " gained", Num(v), head = true })
      for _, e in ipairs(Sorted(a.psources and a.psources[pow])) do table.insert(lines, { "  " .. e.name, Num(e.v) }) end
    end
    if (a.ff or 0) > 0 then
      table.insert(lines, { "Friendly fire", Num(a.ff), head = true })
      for _, e in ipairs(Sorted(a.fftargets)) do table.insert(lines, { e.name, Num(e.v), go = Link(e.name) }) end
    end
    FillLines(lines)
  end

  -- the other players of this fight, for Compare
  local function Others(seg, a)
    local out = {}
    for name, o in pairs(seg and seg.actors or {}) do
      if o ~= a then table.insert(out, o) end
    end
    table.sort(out, function(x, y) return (x.damage + x.heal) > (y.damage + y.heal) end)
    return out
  end

  local function Compare(a, seg)
    local others = Others(seg, a)
    -- the same class first, else the biggest
    if not B.other or not seg.actors[B.other] or B.other == a.name then
      B.other = nil
      for _, o in ipairs(others) do if o.class == a.class then B.other = o.name break end end
      if not B.other and others[1] then B.other = others[1].name end
    end
    local o = B.other and seg.actors[B.other]
    if not o then
      FillList({}, 1)
      FillLines({ { "Nobody else in this fight to compare with.", "" } })
      return
    end
    local mine, mtotal = SpellsOf(a, Kind())
    local theirs, ttotal = SpellsOf(o, Kind())
    local names = {}
    for n in pairs(mine) do names[n] = true end
    for n in pairs(theirs) do names[n] = true end
    local list, top = {}, 1
    for n in pairs(names) do
      local x = mine[n] and mine[n].total or 0
      local y = theirs[n] and theirs[n].total or 0
      top = max(top, x, y)
      local gap = y > 0 and string.format("%+.0f%%", (x - y) / y * 100) or "new"
      local color = x >= y and "|cff66ff66" or "|cffff6666"
      table.insert(list, { name = n, value = x, sort = max(x, y),
        text = Num(x) .. "  |cff888888vs|r " .. Num(y) .. "  " .. color .. gap .. "|r" })
    end
    table.sort(list, function(p, q) return p.sort > q.sort end)
    FillList(list, top)
    local lines = { { a.name .. "  vs  " .. o.name, "", head = true },
      { "Total", Num(mtotal) .. "  /  " .. Num(ttotal) },
      { "Per second", Num(mtotal / max(1, a.active or 0)) .. "  /  " .. Num(ttotal / max(1, o.active or 0)) },
      { "Active", Clock(a.active or 0) .. "  /  " .. Clock(o.active or 0) },
      { "Open " .. o.name, "", go = Link(o.name) },
      { " ", "" }, { "Compare with", "", head = true } }
    FillLines(lines)
    -- a list of the others to pick from, under the lines
    B.compareChoices = others
  end

  -- Chart: the player's damage (or healing) per second through the fight,
  -- as columns, with the group's in grey behind (Details' charts)
  f.chart = CreateFrame("Frame", nil, f)
  f.chart:SetPoint("TOPLEFT", f, "TOPLEFT", 10, BODY_TOP)
  f.chart:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
  CreateBackdrop(f.chart, nil, true, .5)
  f.chart.cols, f.chart.back = {}, {}
  f.chart.top = Text(f.chart, C.global.font_size - 1)
  f.chart.top:SetPoint("TOPLEFT", f.chart, "TOPLEFT", 6, -4)
  f.chart.right = Text(f.chart, C.global.font_size - 1, "RIGHT")
  f.chart.right:SetPoint("TOPRIGHT", f.chart, "TOPRIGHT", -6, -4)
  f.chart.bottom = Text(f.chart, C.global.font_size - 1)
  f.chart.bottom:SetPoint("BOTTOMLEFT", f.chart, "BOTTOMLEFT", 6, 4)
  f.chart.endtime = Text(f.chart, C.global.font_size - 1, "RIGHT")
  f.chart.endtime:SetPoint("BOTTOMRIGHT", f.chart, "BOTTOMRIGHT", -6, 4)
  f.chart:Hide()
  local CHART_W, CHART_H = W - 20 - 16, H + BODY_TOP - 10 - 40

  local function Column(list, i, parent)
    local c = list[i]
    if c then return c end
    c = parent:CreateTexture(nil, "ARTWORK")
    c:SetTexture("Interface\\Buttons\\WHITE8X8")
    list[i] = c
    return c
  end

  local function Chart(a, seg)
    local heal = Kind() == "heal"
    local mine = M.Curve and M.Curve(seg, a.name, heal) or {}
    local all = M.Curve and M.Curve(seg, nil, heal) or {}
    local n = table.getn(mine)
    local ch = f.chart
    for _, c in pairs(ch.cols) do c:Hide() end
    for _, c in pairs(ch.back) do c:Hide() end
    if n < 2 then
      ch.top:SetText("No chart for this fight yet (it is drawn from the fight's samples, one a second).")
      ch.right:SetText("")
      ch.bottom:SetText("")
      ch.endtime:SetText("")
      B.chartPoints = 0
      return
    end
    -- at most one column per 2 pixels: samples are bunched together
    local cols = min(n, floor(CHART_W / 2))
    local per = n / cols
    local top, peak, sum = 1, 0, 0
    local vm, va = {}, {}
    for i = 1, cols do
      local from, to = floor((i - 1) * per) + 1, max(floor((i - 1) * per) + 1, floor(i * per))
      local m, g = 0, 0
      for j = from, to do m, g = m + (mine[j] or 0), g + (all[j] or 0) end
      m, g = m / (to - from + 1), g / (to - from + 1)
      vm[i], va[i] = m, g
      top = max(top, m, g)
      peak = max(peak, m)
      sum = sum + m
    end
    local w = CHART_W / cols
    local r, g, b = cr, cg, cb
    for i = 1, cols do
      local bk = Column(ch.back, i, ch)
      bk:ClearAllPoints()
      bk:SetPoint("BOTTOMLEFT", ch, "BOTTOMLEFT", 8 + (i - 1) * w, 20)
      bk:SetWidth(max(1, w - 1))
      bk:SetHeight(max(1, va[i] / top * CHART_H))
      bk:SetVertexColor(1, 1, 1, .12)
      bk:Show()
      local col = Column(ch.cols, i, ch)
      col:ClearAllPoints()
      col:SetPoint("BOTTOMLEFT", ch, "BOTTOMLEFT", 8 + (i - 1) * w, 20)
      col:SetWidth(max(1, w - 1))
      col:SetHeight(max(1, vm[i] / top * CHART_H))
      col:SetVertexColor(r, g, b, .9)
      col:Show()
    end
    local what = heal and "healing" or "damage"
    ch.top:SetText(a.name .. ": " .. what .. " per second  (grey: the whole group)")
    ch.right:SetText("peak " .. Num(peak) .. "   average " .. Num(sum / cols) .. "   scale " .. Num(top))
    ch.bottom:SetText("0:00")
    ch.endtime:SetText(Clock(seg.timeline[n].t))
    B.chartPoints = cols
  end
  B.Chart = Chart

  local function Deaths(a, seg)
    local start = seg and seg.start or 0
    local deaths = a.deathlogs or {}
    if table.getn(deaths) == 0 then
      FillList({}, 1)
      FillLines({ { "No deaths in this fight.", "" } })
      return
    end
    B.death = min(B.death or 1, table.getn(deaths))
    local list = {}
    for i, d in ipairs(deaths) do
      local idx = i
      table.insert(list, { name = string.format("Death %d at %s", i, Clock(d.t - start)), value = 1,
        text = d.killer and ("by " .. Named(d.killer)) or "", color = { .6, .15, .15 },
        selected = i == B.death, onclick = function() B.death = idx B.Draw() end })
    end
    FillList(list, 1)
    -- the last hits and heals, newest last, with health
    local d = deaths[B.death]
    local lines = { { "Before death " .. B.death, "health", head = true } }
    if d.killer and Link(d.killer) then table.insert(lines, { "Killed by " .. d.killer, "", go = Link(d.killer) }) end
    for _, e in ipairs(d.log or {}) do
      local sign = e.kind == "heal" and "|cff66ff66+" or "|cffff6666-"
      local hp = (e.hp and e.hpmax and e.hpmax > 0) and floor(e.hp / e.hpmax * 100) .. "%" or ""
      table.insert(lines, { string.format("%4.1fs ", e.t - d.t) .. sign .. Num(e.amount) .. (e.crit and "*" or "") .. "|r " ..
        (e.spell or "") .. " |cff888888" .. (e.who or "") .. "|r", hp, go = Link(e.who) })
    end
    FillLines(lines)
  end

  -- ---------------------------------------------------------------- enemy and spell views

  local function FoeDraw(name, seg)
    local foe = seg and seg.foes and seg.foes[name]
    if not foe then
      FillList({}, 1)
      FillLines({ { name .. " is not in this fight.", "" } })
      return
    end
    local tab = B.tab
    local list, lines = {}, {}
    if tab == "fhitby" or tab == "fsummary" then
      for _, e in ipairs(Sorted(foe.from)) do
        local who = e.name
        local a = seg.actors[who]
        local c = a and a.class and RAID_CLASS_COLORS[a.class]
        table.insert(list, { name = who, link = Link(who) and true, value = e.v, text = Num(e.v) .. "  " .. Pct(e.v, foe.taken),
          color = c and { c.r, c.g, c.b }, onclick = Link(who) })
      end
    elseif tab == "fhit" then
      for _, e in ipairs(Sorted(foe.to)) do
        local who = e.name
        table.insert(list, { name = who, link = Link(who) and true, value = e.v, text = Num(e.v) .. "  " .. Pct(e.v, foe.done), onclick = Link(who),
          color = { .7, .25, .25 } })
      end
    elseif tab == "ftaken" then
      for _, e in ipairs(Sorted(foe.tspells, "total")) do
        local spell, who = SourceOf(e.name)
        table.insert(list, { name = spell .. "  |cff888888" .. (who or "") .. "|r", value = e.v,
          text = Num(e.v) .. "  " .. Pct(e.v, foe.taken), onclick = Link(who) })
      end
    else
      local sorted = Sorted(foe.dspells, "total")
      if not B.spell or not foe.dspells[B.spell] then B.spell = sorted[1] and sorted[1].name end
      for _, e in ipairs(sorted) do
        local sname = e.name
        table.insert(list, { name = sname, value = e.v, text = Num(e.v) .. "  " .. Pct(e.v, foe.done), color = { .7, .25, .25 },
          selected = sname == B.spell, onclick = function() B.spell = sname B.Draw() end })
      end
      if B.spell and foe.dspells[B.spell] then
        local s = foe.dspells[B.spell]
        lines = { { B.spell, "", head = true }, { "Damage", Num(s.total) .. "  (" .. Pct(s.total, foe.done) .. ")" },
          { "Hits / biggest", s.hits .. " / " .. Num(s.max or 0) } }
        local b = seg.byspell and seg.byspell[B.spell]
        if b then
          table.insert(lines, { "Who it hit", "", head = true })
          for _, e in ipairs(Sorted(b.targets)) do table.insert(lines, { e.name, Num(e.v), go = Link(e.name) }) end
        end
      end
    end
    FillList(list, list[1] and list[1].value)
    if table.getn(lines) == 0 then
      lines = { { name, "", head = true },
        { "Damage taken", Num(foe.taken), go = function() B.tab = "fhitby" B.Draw() end },
        { "Damage done", Num(foe.done), go = function() B.tab = "fhit" B.Draw() end },
        { "Fight", Clock(M.Duration(seg)) } }
      if seg.boss == name then table.insert(lines, { "The boss of this fight", "" }) end
      table.insert(lines, { "Most damage on it", "", head = true })
      for i, e in ipairs(Sorted(foe.from)) do
        if i > 5 then break end
        table.insert(lines, { e.name, Num(e.v), go = Link(e.name) })
      end
      table.insert(lines, { "It hit most", "", head = true })
      for i, e in ipairs(Sorted(foe.to)) do
        if i > 5 then break end
        table.insert(lines, { e.name, Num(e.v), go = Link(e.name) })
      end
    end
    FillLines(lines)
  end

  local function SpellDraw(name, seg)
    local b = seg and seg.byspell and seg.byspell[name]
    if not b then
      FillList({}, 1)
      FillLines({ { name .. " did not hit anyone in this fight.", "" } })
      return
    end
    local list = {}
    local tbl = B.tab == "sfrom" and b.from or b.targets
    for _, e in ipairs(Sorted(tbl)) do
      local who = e.name
      table.insert(list, { name = who, link = Link(who) and true, value = e.v, text = Num(e.v) .. "  " .. Pct(e.v, b.total), onclick = Link(who),
        color = { .7, .25, .25 } })
    end
    FillList(list, list[1] and list[1].value)
    local lines = { { name, "", head = true }, { "Damage on your group", Num(b.total) }, { "Hits / biggest", b.hits .. " / " .. Num(b.max) },
      { "Cast by", "", head = true } }
    for _, e in ipairs(Sorted(b.from)) do table.insert(lines, { e.name, Num(e.v), go = Link(e.name) }) end
    FillLines(lines)
  end

  -- ---------------------------------------------------------------- open / draw

  -- the window's look on the breakdown: bar texture, font, background, border
  local function Look()
    local s = B.win and M.S and M.S(B.win)
    if not s then return end
    texture = (s.texture and s.texture ~= "") and s.texture or texture
    local font = (s.font and s.font ~= "") and s.font or pfUI.font_default
    local outline = s.outline == "NONE" and "" or (s.outline or "OUTLINE")
    local size = tonumber(s.fontsize) or C.global.font_size
    for _, t in ipairs(texts) do t:SetFont(font, max(8, t.base + (size - C.global.font_size)), outline) end
    if f.backdrop and M.Col then
      f.backdrop:SetBackdropColor(M.Col(s.bg, "0,0,0,0.85"))
      f.backdrop:SetBackdropBorderColor(M.Col(s.bordercolor, "0,0,0,1"))
    end
  end
  B.Look = Look

  local function Tabs(set)
    local ar, ag, ab = GetAccentColor()
    for i, b in ipairs(f.tabs) do
      local t = set[i]
      if t then
        b.key = t[1]
        b.text:SetText(t[2])
        if b.key == B.tab then
          b.text:SetTextColor(ar, ag, ab)
          b.line:SetVertexColor(ar, ag, ab, 1)
          b.line:Show()
        else
          b.text:SetTextColor(1, 1, 1)
          b.line:Hide()
        end
        b:Show()
      else
        b:Hide()
      end
    end
  end

  function B.Draw()
    local seg = M.Segment(B.segment)
    B.seg = seg
    Look()
    PaintGroups()
    local mode = MODE[B.mode] or MODE.damage
    local segname = gsub(M.SegmentName and M.SegmentName(B.segment) or "", "|c%x%x%x%x%x%x%x%x", "")
    segname = gsub(segname, "|r", "")
    if B.stack and table.getn(B.stack) > 0 then f.back:Show() else f.back:Hide() end
    f.icon:Hide()
    cr, cg, cb = .6, .6, .6

    -- an enemy, or a spell that hit the group
    if B.foe or B.bspell then
      local set = B.foe and B.FOETABS or B.SPELLTABS
      local ok = false
      for _, t in ipairs(set) do if t[1] == B.tab then ok = true end end
      if not ok then B.tab = set[1][1] end
      Tabs(set)
      for _, k in ipairs(f.kinds) do k:Hide() end
      f.name:SetText(B.foe or B.bspell)
      f.name:SetTextColor(1, .45, .45)
      f.who:SetWidth(max(80, (f.name:GetStringWidth() or 60) + 14))
      f.sub:SetText((B.foe and "enemy" or "spell on your group") .. "  -  " .. segname)
      f.chart:Hide()
      f.list:Show()
      f.panel:Show()
      f.list:SetPoint("TOPLEFT", f, "TOPLEFT", 10, BODY_TOP + 26)
      if B.foe then FoeDraw(B.foe, seg) else SpellDraw(B.bspell, seg) end
      f:Show()
      return
    end

    local a = B.actor
    if not a then return end
    -- the actor of this segment (the test fight, a newer fight)
    if seg and seg.actors and seg.actors[a.name] then a = seg.actors[a.name] B.actor = a end
    if not B.kind then B.kind = HEALMODES[B.mode] and "heal" or (B.mode == "ff" and "ff" or "damage") end
    B.active = max(1, a.active or 0)
    local ok = false
    for _, t in ipairs(B.TABS) do if t[1] == B.tab then ok = true end end
    if not ok then B.tab = "spells" end
    Tabs(B.TABS)
    -- header
    local coords = a.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[a.class]
    if coords then
      f.icon:SetTexture(pfUI.media["img:classicons"])
      f.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
      f.icon:Show()
    end
    local c = a.class and RAID_CLASS_COLORS[a.class]
    f.name:SetText(a.name)
    if c then f.name:SetTextColor(c.r, c.g, c.b) cr, cg, cb = c.r, c.g, c.b else f.name:SetTextColor(1, 1, 1) end
    f.who:SetWidth(max(80, (f.name:GetStringWidth() or 60) + 14))
    f.sub:SetText(mode.name .. "  -  " .. segname)
    -- damage / healing / friendly fire switch on the tabs that use it
    local kinds = KINDTABS[B.tab]
    local ar, ag, ab = GetAccentColor()
    for _, k in ipairs(f.kinds) do
      if kinds then
        k:Show()
        if k.key == Kind() then k.text:SetTextColor(ar, ag, ab) else k.text:SetTextColor(1, 1, 1) end
      else
        k:Hide()
      end
    end
    f.list:SetPoint("TOPLEFT", f, "TOPLEFT", 10, kinds and BODY_TOP or (BODY_TOP + 26))
    -- the chart takes the whole body
    if B.tab == "chart" then
      f.list:Hide()
      f.panel:Hide()
      f.chart:Show()
    else
      f.chart:Hide()
      f.list:Show()
      f.panel:Show()
    end
    if B.tab == "summary" then Summary(a, seg)
    elseif B.tab == "chart" then Chart(a, seg)
    elseif B.tab == "targets" then Targets(a)
    elseif B.tab == "taken" then Taken(a)
    elseif B.tab == "casts" then Casts(a)
    elseif B.tab == "auras" then Auras(a, seg)
    elseif B.tab == "utility" then Utility(a, seg)
    elseif B.tab == "compare" then Compare(a, seg)
    elseif B.tab == "deaths" then Deaths(a, seg)
    else Spells(a) end
    f:Show()
  end

  -- what is open now, for Back
  local function Current() return { actor = B.actor, foe = B.foe, bspell = B.bspell, tab = B.tab, kind = B.kind } end
  local function Show(v)
    B.actor, B.foe, B.bspell = v.actor, v.foe, v.bspell
    B.tab = v.tab or (v.foe and "fsummary") or (v.bspell and "ssummary") or B.tab
    if v.kind then B.kind = v.kind end
    B.offset, B.lineOffset, B.spell, B.target, B.death = 0, 0, nil, nil, nil
    B.Draw()
  end
  -- open a player, an enemy or a spell from a link (Back returns)
  function B.Open(v)
    table.insert(B.stack, Current())
    if table.getn(B.stack) > 30 then table.remove(B.stack, 1) end
    if v.actor and not v.tab then v.tab = (B.tab and not B.foe and not B.bspell) and B.tab or "summary" end
    Show(v)
  end
  function B.Back()
    local v = table.remove(B.stack)
    if v then Show(v) end
  end

  -- the tab that fits what the window shows
  local FIRSTTAB = { deaths = "deaths", taken = "taken", htaken = "taken", interrupts = "utility", dispels = "utility",
    frags = "utility", ress = "casts", cooldowns = "casts", buffs = "auras", debuffs = "auras", mana = "utility",
    rage = "utility", energy = "utility" }
  B.FIRSTTAB = FIRSTTAB

  -- a click on a bar opens it
  local ShowSimple = M.ShowDetails
  M.ShowDetails = function(win, row)
    if not row then return end
    B.win, B.row = win, row
    B.mode = win.mode
    B.segment = win.segment
    B.stack = {}
    B.kind = nil
    B.offset, B.lineOffset, B.spell, B.target, B.death = 0, 0, nil, nil, nil
    if row.actor then
      B.actor, B.foe, B.bspell = row.actor, nil, nil
      -- (the last player tab stays, unless the window says otherwise)
      local keep
      for _, t in ipairs(B.TABS) do if t[1] == B.tab and t[1] ~= "deaths" then keep = B.tab end end
      B.tab = FIRSTTAB[win.mode] or keep or "spells"
    elseif row.foe then
      B.actor, B.foe, B.bspell = nil, row.name, nil
      B.tab = win.mode == "enemydone" and "fhit" or "fsummary"
    elseif row.byspell then
      B.actor, B.foe, B.bspell = nil, nil, row.name
      B.tab = "ssummary"
    else
      return ShowSimple(win, row)
    end
    B.Draw()
  end

  -- < >: the next row of the window's list
  function B.Step(dir)
    if not B.win then return end
    local rows = M.Rows(B.mode, B.segment)
    for i, r in ipairs(rows) do
      local same = (B.actor and r.actor and r.actor.name == B.actor.name) or (B.foe and r.foe and r.name == B.foe)
        or (B.bspell and r.byspell and r.name == B.bspell)
      if same then
        local n = rows[i + dir]
        if n then
          if n.actor then B.actor, B.foe, B.bspell = n.actor, nil, nil
          elseif n.foe then B.actor, B.foe, B.bspell = nil, n.name, nil
          elseif n.byspell then B.actor, B.foe, B.bspell = nil, nil, n.name end
          B.offset, B.lineOffset, B.spell, B.target = 0, 0, nil, nil
          B.Draw()
        end
        return
      end
    end
  end

  -- everyone in the fight / every enemy, as menus
  function B.PeopleMenu(anchor)
    local seg = B.seg
    if not seg or not M.ShowMenu then return end
    local items = { { "Players in this fight", head = true } }
    local list = {}
    for name, a in pairs(seg.actors or {}) do table.insert(list, a) end
    table.sort(list, function(x, y) return (x.damage + x.heal) > (y.damage + y.heal) end)
    for _, a in ipairs(list) do
      local actor = a
      local c = a.class and RAID_CLASS_COLORS[a.class]
      local label = c and string.format("|cff%02x%02x%02x%s|r", floor(c.r * 255), floor(c.g * 255), floor(c.b * 255), a.name) or a.name
      table.insert(items, { label .. "  |cff888888" .. Num(a.damage) .. " / " .. Num(a.heal) .. "|r",
        function() B.Open({ actor = actor }) end, checked = B.actor and B.actor.name == a.name })
    end
    M.ShowMenu(anchor, items)
  end
  function B.FoeMenu(anchor)
    local seg = B.seg
    if not seg or not M.ShowMenu then return end
    local items = { { "Enemies in this fight", head = true } }
    for _, e in ipairs(Sorted(seg.foes, "taken")) do
      local name = e.name
      table.insert(items, { name .. "  |cff888888" .. Num(e.v) .. "|r", function() B.Open({ foe = name }) end, checked = B.foe == name })
    end
    if table.getn(items) == 1 then table.insert(items, { "No enemies in this fight", head = true }) end
    M.ShowMenu(anchor, items)
  end

  -- Compare: pick the other player
  f.pick = Button(f.panel, "Pick player...", 120, function()
    local items = { { "Compare with", head = true } }
    for _, o in ipairs(B.compareChoices or {}) do
      local name = o.name
      table.insert(items, { name, function() B.other = name B.Draw() end, checked = name == B.other })
    end
    M.ShowMenu(this, items)
  end)
  f.pick:SetPoint("BOTTOMLEFT", f.panel, "BOTTOMLEFT", 8, 8)
  f.pick:Hide()
  local draw = B.Draw
  B.Draw = function()
    draw()
    if B.actor and not B.foe and not B.bspell and B.tab == "compare" and B.compareChoices and table.getn(B.compareChoices) > 0 then
      f.pick:Show()
    else
      f.pick:Hide()
    end
  end

  -- ---------------------------------------------------------------- report

  -- what the open tab shows, as chat lines (top 10)
  local function Plain(s) return gsub(gsub(tostring(s or ""), "|c%x%x%x%x%x%x%x%x", ""), "|r", "") end
  function B.ReportLines()
    local title = B.actor and B.actor.name or B.foe or B.bspell
    if not title then return {} end
    local mode = MODE[B.mode] or MODE.damage
    local out = { "pfUI Octo - " .. title .. " - " .. mode.name .. " (" .. B.tab .. ")" }
    if B.tab == "summary" or B.tab == "deaths" or B.tab == "fsummary" then
      for _, l in ipairs(B.linesShown or {}) do
        if not l.head and l[1] and l[1] ~= " " then
          table.insert(out, Plain(l[1] .. "  " .. tostring(l[2] or "")))
        end
        if table.getn(out) > 12 then break end
      end
    else
      for i, e in ipairs(B.listShown or {}) do
        if i > (tonumber(C.meters.reportlines) or 10) then break end
        table.insert(out, i .. ". " .. Plain(e.name) .. "  " .. Plain(e.text))
      end
    end
    return out
  end

  function B.Report(channel, whisper)
    for _, line in ipairs(B.ReportLines()) do SendChatMessage(line, channel, nil, whisper) end
  end

  function B.ReportMenu(anchor)
    local items = { { "Report this tab", head = true },
      { "Say", function() B.Report("SAY") end },
      { "Party", function() B.Report("PARTY") end },
      { "Raid", function() B.Report("RAID") end },
      { "Guild", function() B.Report("GUILD") end },
      { "Officer", function() B.Report("OFFICER") end } }
    if UnitIsPlayer("target") and UnitIsFriend("player", "target") then
      local name = UnitName("target")
      table.insert(items, { "Whisper " .. name, function() B.Report("WHISPER", name) end })
    end
    M.ShowMenu(anchor, items)
  end
end)
