-- The comparison panel. It only draws a result table; the numbers come from a scoring engine
-- (step 2 and 3 of the project). The table comes from Compare.lua.
--
-- data = {
--   class = "PALADIN", classText = "Holy Paladin", roleText = "Healer + leveling",
--   mix = { tank = 0, heal = 0.7, dmg = 0.3 },        -- shares, add up to 1
--   equipped = { name, q, icon, score }, new = { name, q, icon, score },
--   unusable = { title, lines = { ... } },             -- when set, only this is shown
--   notice = { text, color }, target = "Finger 2",     -- banner under the header, slot compared with
--   empty = true,                                      -- the slot is empty (no percent change)
--   notes = { ... },                                   -- short remarks (caps, ...), shown from detail 2
--   stats = { { label, delta, fmt, value, note } },    -- value = points, note = talent remark
--   roles = { { label, pct } },
--   talents = { { name, text } }, warnings = { ... }, fit = { made, fit },
--   demo = true,
-- }

local AG = AdeGear
local Panel = {}
AG.Panel = Panel

local WIDTH = 252

local function Hex(c) return AG.Hex(c) end

-- verdict from the score change in percent
local function Verdict(pct)
  if pct >= 25 then return "BIG UPGRADE", { 0.2, 1, 0.4 }
  elseif pct >= 8 then return "UPGRADE", { 0.4, 0.92, 0.4 }
  elseif pct >= 2 then return "SMALL UPGRADE", { 0.7, 0.9, 0.35 }
  elseif pct > -2 then return "ABOUT EQUAL", { 0.75, 0.75, 0.75 }
  elseif pct > -8 then return "SMALL DOWNGRADE", { 1, 0.7, 0.3 }
  elseif pct > -25 then return "DOWNGRADE", { 1, 0.45, 0.3 }
  end
  return "BIG DOWNGRADE", { 1, 0.25, 0.25 }
end
Panel.Verdict = Verdict

local function Signed(v)
  if v > 0 then return string.format("+%.1f", v) end
  if v < 0 then return string.format("%.1f", v) end
  return "0.0"
end

local function PctText(p)
  if p > 0 then return string.format("+%d%%", math.floor(p + 0.5)) end
  if p < 0 then return string.format("%d%%", math.floor(p - 0.5)) end
  return "0%"
end

local function PctColor(p)
  if p >= 2 then return AG.C.good end
  if p <= -2 then return AG.C.bad end
  return AG.C.dim
end

----------------------------------------------------------------------
-- Role mix bar: tank / heal / damage shares
----------------------------------------------------------------------

local function CreateMixBar(parent)
  local bar = CreateFrame("Frame", nil, parent)
  AG.Style(bar, "field")
  bar.seg = {
    AG.W.Box(bar, AG.C.tank[1], AG.C.tank[2], AG.C.tank[3], 1, "ARTWORK"),
    AG.W.Box(bar, AG.C.heal[1], AG.C.heal[2], AG.C.heal[3], 1, "ARTWORK"),
    AG.W.Box(bar, AG.C.dmg[1], AG.C.dmg[2], AG.C.dmg[3], 1, "ARTWORK"),
  }
  bar.Set = function(self, tank, heal, dmg)
    local inner = self:GetWidth() - 2
    local shares = { tank or 0, heal or 0, dmg or 0 }
    local x = 1
    for i = 1, 3 do
      local seg = self.seg[i]
      seg:ClearAllPoints()
      local w = math.floor(inner * shares[i] + 0.5)
      if w > 0 then
        seg:SetPoint("TOPLEFT", self, "TOPLEFT", x, -1)
        seg:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", x, 1)
        seg:SetWidth(w)
        seg:Show()
        x = x + w
      else
        seg:Hide()
      end
    end
  end
  return bar
end

----------------------------------------------------------------------
-- Score row: item icon, name, score number and a bar relative to the better item
----------------------------------------------------------------------

local function CreateScoreRow(parent)
  local row = CreateFrame("Frame", nil, parent)

  local iconFrame = CreateFrame("Frame", nil, row)
  iconFrame:SetWidth(30)
  iconFrame:SetHeight(30)
  iconFrame:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  AG.Style(iconFrame, "field")
  local icon = iconFrame:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
  icon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  row.iconFrame = iconFrame
  row.icon = icon
  row.tag = AG.W.Text(row, 12, AG.C.text)
  row.tag:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 6, 0)
  row.name = AG.W.Text(row, 12)
  row.name:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 6, -14)
  row.name:SetWidth(165)
  row.value = AG.W.Text(row, 12, AG.C.text, "RIGHT")
  row.value:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)

  local back = CreateFrame("Frame", nil, row)
  back:SetHeight(5)
  back:SetPoint("BOTTOMLEFT", iconFrame, "BOTTOMRIGHT", 6, 0)
  back:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
  AG.Style(back, "field")
  row.back = back
  row.fill = AG.W.Box(back, 1, 1, 1, 1, "ARTWORK")

  row.Set = function(self, tag, item, maxScore, color, tagColor)
    self.tag:SetText(tag)
    tagColor = tagColor or AG.C.text
    self.tag:SetTextColor(tagColor[1], tagColor[2], tagColor[3])
    -- one line only: a long name is cut (the width is about 28 letters)
    local nm = item.name or "?"
    if string.len(nm) > 30 then nm = string.sub(nm, 1, 28) .. ".." end
    self.name:SetText(nm)
    local q = AG.Q[item.q or 1]
    self.name:SetTextColor(q[1], q[2], q[3])
    self.iconFrame:SetBackdropBorderColor(q[1], q[2], q[3], 1)
    self.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    self.value:SetText(string.format("%.1f", item.score or 0))
    self.value:SetTextColor(color[1], color[2], color[3])
    local frac = 0
    if maxScore and maxScore > 0 then frac = (item.score or 0) / maxScore end
    if frac < 0.02 then frac = 0.02 end
    if frac > 1 then frac = 1 end
    local w = (self:GetWidth() - 36 - 2) * frac
    if w < 1 then w = 1 end
    self.fill:ClearAllPoints()
    self.fill:SetPoint("TOPLEFT", self.back, "TOPLEFT", 1, -1)
    self.fill:SetPoint("BOTTOMLEFT", self.back, "BOTTOMLEFT", 1, 1)
    self.fill:SetWidth(w)
    self.fill:SetVertexColor(color[1], color[2], color[3], 1)
  end
  return row
end

----------------------------------------------------------------------
-- The panel
----------------------------------------------------------------------

function Panel.Get(strata)
  if Panel.tip then return Panel.tip end
  local tip = AG.Tip.New("AdeGearComparePanel", WIDTH, strata)
  local f = tip.frame
  tip.mix = CreateMixBar(f)
  tip.rowOld = CreateScoreRow(f)
  tip.rowNew = CreateScoreRow(f)
  tip.verdict = AG.W.Text(f, 12, AG.C.text, "CENTER")
  Panel.tip = tip
  return tip
end

local function ShareText(label, c, share)
  return "|cff" .. Hex(c) .. label .. " " .. math.floor(share * 100 + 0.5) .. "%|r"
end

local function Header(tip, d)
  local cc = AG.ClassColor[d.class] or AG.C.text
  tip:Line(d.classText or "?", d.roleText, cc, AG.C.dim)
end

local function Unusable(tip, d)
  local u = d.unusable
  tip:Rule()
  tip:Line(u.title or "You can't use this item", nil, AG.C.bad, nil, 13)
  for i = 1, table.getn(u.lines or {}) do
    tip:Line(u.lines[i], nil, AG.C.text)
  end
  tip:Space(2)
end

-- detail: 1 compact, 2 normal, 3 detailed
function Panel.Update(d, detail)
  local tip = Panel.Get()
  tip:Reset()
  Header(tip, d)

  if d.unusable then
    Unusable(tip, d)
    if d.demo then
      tip:Rule()
      tip:Line("DEMO DATA, not real item values", nil, AG.C.dim, nil, 10)
    end
    tip:Done()
    return tip
  end

  if d.notice then tip:Line(d.notice.text, nil, d.notice.color or AG.C.warn, nil, 11) end
  if d.target then tip:Line("compared with: " .. d.target, nil, AG.C.text, nil, 10) end

  -- role mix bar and legend
  local mix = d.mix or { tank = 0, heal = 0, dmg = 1 }
  tip:Place(tip.mix, 7)
  tip.mix:Set(mix.tank, mix.heal, mix.dmg)
  local parts = {}
  if mix.tank > 0 then table.insert(parts, ShareText("Tank", AG.C.tank, mix.tank)) end
  if mix.heal > 0 then table.insert(parts, ShareText("Heal", AG.C.heal, mix.heal)) end
  if mix.dmg > 0 then table.insert(parts, ShareText("Damage", AG.C.dmg, mix.dmg)) end
  tip:Line(table.concat(parts, "   "), nil, AG.C.text, nil, 10)
  tip:Space(2)

  -- scores
  local eq, nw = d.equipped, d.new
  local best = math.max(eq.score or 0, nw.score or 0)
  local pct = 0
  if (eq.score or 0) > 0 then pct = ((nw.score - eq.score) / eq.score) * 100 end
  local text, color = Verdict(pct)
  if d.empty then
    pct = nil
    if (nw.score or 0) > 0.05 then text, color = "FILLS AN EMPTY SLOT", AG.C.good
    else text, color = "NOTHING FOR YOU", AG.C.dim end
  end
  -- the hovered item first, in the verdict color; what you wear below it as a grey baseline
  tip:Place(tip.rowNew, 32)
  tip:Place(tip.rowOld, 32)
  tip.rowNew:Set("THIS ITEM", nw, best, color, color)
  tip.rowOld:Set("EQUIPPED", eq, best, AG.C.dim, AG.C.dim)
  tip:Space(2)

  tip:Place(tip.verdict, 20)
  if pct then tip.verdict:SetText(text .. "  " .. PctText(pct)) else tip.verdict:SetText(text) end
  tip.verdict:SetTextColor(color[1], color[2], color[3])

  if detail >= 2 and d.gs then
    local delta = math.floor(d.gs.new + 0.5) - math.floor(d.gs.old + 0.5)
    local sign = ""
    if delta > 0 then sign = "+" end
    tip:Line("GearScore " .. math.floor(d.gs.old + 0.5) .. " to " .. math.floor(d.gs.new + 0.5) .. "  (" .. sign .. delta .. ")", nil, AG.C.dim, nil, 10)
  end

  if detail >= 2 then
    -- every slot the item could go in
    local opts = d.options or {}
    if table.getn(opts) > 1 then
      tip:Rule()
      tip:Line("IN EACH SLOT", nil, AG.C.text, nil, 10)
      for i = 1, table.getn(opts) do
        local o = opts[i]
        local right, rc = "", AG.C.text
        if o.pct then right = PctText(o.pct); rc = PctColor(o.pct) end
        local left = o.label .. " (replaces " .. o.name .. ")"
        if o.best then left = left .. " <" end
        tip:Line(left, right, AG.C.text, rc, 11)
      end
    end
    -- effects: what you get and what you lose
    local fx = d.effects or { gained = {}, lost = {} }
    if table.getn(fx.gained) + table.getn(fx.lost) > 0 then
      tip:Rule()
      tip:Line("EFFECTS", nil, AG.C.text, nil, 10)
      for i = 1, table.getn(fx.gained) do tip:Line("+ " .. fx.gained[i], nil, AG.C.good, nil, 10) end
      for i = 1, table.getn(fx.lost) do tip:Line("- lost: " .. fx.lost[i], nil, AG.C.bad, nil, 10) end
    end
  end

  if detail >= 2 then
    -- stat by stat
    local stats = d.stats or {}
    if table.getn(stats) > 0 then
      tip:Rule()
      tip:Line("STAT BY STAT", nil, AG.C.text, nil, 10)
      local sorted = {}
      for i = 1, table.getn(stats) do table.insert(sorted, stats[i]) end
      table.sort(sorted, function(a, b) return math.abs(a.value) > math.abs(b.value) end)
      local limit = table.getn(sorted)
      if detail < 3 and limit > 5 then limit = 5 end
      for i = 1, limit do
        local s = sorted[i]
        local c = AG.C.dim
        if s.value > 0 then c = AG.C.good elseif s.value < 0 then c = AG.C.bad end
        local fmt = s.fmt or "%+g"
        tip:Line(string.format(fmt, s.delta) .. " " .. s.label, Signed(s.value), c, c)
        if s.note then
          tip:Line("  > " .. s.note, nil, AG.C.gold, nil, 10)
        end
      end
      if limit < table.getn(sorted) then
        tip:Line("+ " .. (table.getn(sorted) - limit) .. " more, hold Alt", nil, AG.C.dim, nil, 10)
      end
    end

    local notes = d.notes or {}
    if table.getn(notes) > 0 then
      tip:Rule()
      for i = 1, table.getn(notes) do
        tip:Line(notes[i], nil, AG.C.gold, nil, 10)
      end
    end

    -- by role (detailed view only: the panel is about your role)
    local roles = d.roles or {}
    if detail >= 3 and table.getn(roles) > 0 then
      tip:Rule()
      tip:Line("BY ROLE", nil, AG.C.text, nil, 10)
      local parts2 = {}
      for i = 1, table.getn(roles) do
        local r = roles[i]
        table.insert(parts2, r.label .. " |cff" .. Hex(PctColor(r.pct)) .. PctText(r.pct) .. "|r")
      end
      tip:Line(table.concat(parts2, "    "), nil, AG.C.text)
    end

    -- talents that were counted
    local talents = d.talents or {}
    if table.getn(talents) > 0 then
      tip:Rule()
      tip:Line("TALENTS COUNTED", nil, AG.C.text, nil, 10)
      for i = 1, table.getn(talents) do
        local t = talents[i]
        tip:Line("|cff" .. Hex(AG.C.gold) .. t.name .. "|r  |cff" .. Hex(AG.C.dim) .. t.text .. "|r", nil, AG.C.text, nil, 11)
      end
    end
  end

  if detail >= 3 then
    local warnings = d.warnings or {}
    if table.getn(warnings) > 0 then
      tip:Rule()
      for i = 1, table.getn(warnings) do
        tip:Line("! " .. warnings[i], nil, AG.C.warn, nil, 11)
      end
    end
    if d.fit then
      tip:Rule()
      tip:Line("Made for", d.fit.made, AG.C.dim, AG.C.text, 11)
      tip:Line("Fit for your spec", d.fit.fit, AG.C.dim, AG.C.good, 11)
    end
  end

  if d.demo then
    tip:Rule()
    tip:Line("DEMO DATA, not real item values", nil, AG.C.dim, nil, 10)
  end
  tip:Done()
  return tip
end
