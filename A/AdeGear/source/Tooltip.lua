-- pfUI-style tooltip frame with a pool of lines. Used for the (demo) item tooltips and for
-- the comparison panel. Layout is top to bottom: Reset, then Line / Space / Rule / Place, then Done.

local AG = AdeGear
local Tip = {}
Tip.__index = Tip
AG.Tip = Tip

function Tip.New(name, width, strata)
  local self = setmetatable({}, Tip)
  local f = CreateFrame("Frame", name, UIParent)
  f:SetFrameStrata(strata or "TOOLTIP")
  f:SetWidth(width)
  f:SetHeight(20)
  AG.Style(f, "tip")
  f:Hide()
  self.frame = f
  self.width = width
  self.pad = 8
  self.y = 8
  self.lines = {}
  self.used = 0
  self.rules = {}
  self.rulesUsed = 0
  self.widgets = {}
  return self
end

function Tip:Reset()
  self.y = self.pad
  self.used = 0
  self.rulesUsed = 0
  for i = 1, table.getn(self.lines) do
    self.lines[i].l:Hide()
    self.lines[i].r:Hide()
    if self.lines[i].m then self.lines[i].m:Hide() end
  end
  for i = 1, table.getn(self.rules) do self.rules[i]:Hide() end
  for i = 1, table.getn(self.widgets) do self.widgets[i]:Hide() end
end

-- One line. left/right are text, lc/rc are colors {r,g,b} (default white).
-- size is the font size (default 12). Long left text wraps onto more lines.
function Tip:Line(left, right, lc, rc, size)
  size = 12   -- one size for the whole tooltip, the size argument is ignored
  self.used = self.used + 1
  local ln = self.lines[self.used]
  if not ln then
    ln = { l = AG.W.Text(self.frame, size), r = AG.W.Text(self.frame, size, AG.C.text, "RIGHT") }
    self.lines[self.used] = ln
  end
  AG.SetFont(ln.l, size)
  AG.SetFont(ln.r, size)
  lc = lc or AG.C.text
  rc = rc or AG.C.text
  if ln.m then ln.m:Hide() end
  local inner = self.width - 2 * self.pad

  ln.l:ClearAllPoints()
  ln.r:ClearAllPoints()
  ln.l:SetTextColor(lc[1], lc[2], lc[3])
  ln.l:SetText(left or "")
  if right and right ~= "" then
    ln.r:SetTextColor(rc[1], rc[2], rc[3])
    ln.r:SetText(right)
    ln.r:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -self.pad, -self.y)
    ln.r:Show()
    ln.l:SetWidth(inner - ln.r:GetStringWidth() - 10)
  else
    ln.r:Hide()
    ln.l:SetWidth(inner)
  end
  ln.l:SetPoint("TOPLEFT", self.frame, "TOPLEFT", self.pad, -self.y)
  ln.l:Show()

  local h = ln.l:GetHeight()
  local min = AG.LineHeight(size) - 2
  if not h or h < min then h = min end
  self.y = self.y + h + 2
end

-- Three columns: text on the left, an amount right-aligned at 60% of the width, points at the right edge.
-- Used for the list of stats, so the numbers do not run into each other.
function Tip:Row(left, mid, right, lc, mc, rc)
  self.used = self.used + 1
  local ln = self.lines[self.used]
  if not ln then
    ln = { l = AG.W.Text(self.frame, 12), r = AG.W.Text(self.frame, 12, AG.C.text, "RIGHT") }
    self.lines[self.used] = ln
  end
  if not ln.m then ln.m = AG.W.Text(self.frame, 12, AG.C.text, "RIGHT") end
  AG.SetFont(ln.l, 12)
  AG.SetFont(ln.r, 12)
  AG.SetFont(ln.m, 12)
  lc = lc or AG.C.text
  mc = mc or AG.C.text
  rc = rc or AG.C.text
  local inner = self.width - 2 * self.pad
  local midX = self.pad + math.floor(inner * 0.60)

  ln.l:ClearAllPoints()
  ln.m:ClearAllPoints()
  ln.r:ClearAllPoints()
  ln.l:SetTextColor(lc[1], lc[2], lc[3])
  ln.l:SetText(left or "")
  ln.l:SetWidth(math.floor(inner * 0.60) - 50)
  ln.l:SetPoint("TOPLEFT", self.frame, "TOPLEFT", self.pad, -self.y)
  ln.l:Show()
  ln.m:SetTextColor(mc[1], mc[2], mc[3])
  ln.m:SetText(mid or "")
  ln.m:SetPoint("TOPRIGHT", self.frame, "TOPLEFT", midX, -self.y)
  ln.m:Show()
  ln.r:SetTextColor(rc[1], rc[2], rc[3])
  ln.r:SetText(right or "")
  ln.r:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -self.pad, -self.y)
  ln.r:Show()

  local h = ln.l:GetHeight()
  local min = AG.LineHeight(12) - 2
  if not h or h < min then h = min end
  self.y = self.y + h + 2
end

function Tip:Space(h)
  self.y = self.y + h
end

-- thin separator line
function Tip:Rule()
  self.rulesUsed = self.rulesUsed + 1
  local r = self.rules[self.rulesUsed]
  if not r then
    r = AG.W.Box(self.frame, 0.25, 0.25, 0.25, 1)
    self.rules[self.rulesUsed] = r
  end
  self.y = self.y + 3
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", self.frame, "TOPLEFT", self.pad, -self.y)
  r:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -self.pad, -self.y)
  r:SetHeight(1)
  r:Show()
  self.y = self.y + 6
end

-- put an existing frame / fontstring / texture (a child of this tip) at the current position
function Tip:Place(widget, height)
  local known = false
  for i = 1, table.getn(self.widgets) do
    if self.widgets[i] == widget then known = true end
  end
  if not known then table.insert(self.widgets, widget) end
  widget:ClearAllPoints()
  widget:SetPoint("TOPLEFT", self.frame, "TOPLEFT", self.pad, -self.y)
  widget:SetWidth(self.width - 2 * self.pad)
  widget:SetHeight(height)
  widget:Show()
  self.y = self.y + height + 3
end

function Tip:Done()
  self.frame:SetHeight(self.y + self.pad - 3)
end

function Tip:Show() self.frame:Show() end
function Tip:Hide() self.frame:Hide() end

----------------------------------------------------------------------
-- Fills a tip with an item (name, quality and tooltip lines).
-- item.lines entries: { left, right, colorKey }, colorKey: g green, y gold, d dim, r red
----------------------------------------------------------------------

local KEYS = { g = AG.C.good, y = AG.C.gold, d = AG.C.dim, r = AG.C.bad, w = AG.C.text }

function AG.FillItemTip(tip, item, header)
  tip:Reset()
  if header then
    tip:Line(header, nil, AG.C.dim, nil, 11)
  end
  tip:Line(item.name, nil, AG.Q[item.q or 1], nil, 13)
  local lines = item.lines or {}
  for i = 1, table.getn(lines) do
    local ln = lines[i]
    local c = KEYS[ln[3] or "w"] or AG.C.text
    tip:Line(ln[1], ln[2], c, c)
  end
  tip:Done()
end
