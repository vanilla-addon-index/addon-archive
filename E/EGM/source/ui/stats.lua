-- EGM tab 4: Statistics on the AH "Browse" art, laid out like a meter: per row a class-colored bar (value relative to
-- the best), rank (gold/silver/bronze for 1-3), class-colored name, the value and its case count in grey.
-- Left filter list like the Browse tab (Browse art, same filter buttons): metric entries, a gap, period entries. The
-- selected metric and period are highlighted like the selected Browse filter. Bottom bar: summary in the left art box, Close.
-- (2026-11-05: hard to read, wanted class colors)
EGM = EGM or {}
local T = {}
local f, cols, metricBtns, periodBtns, summary
local metric, days = "volume", nil
local ROWS, ROW_H, ROW_GAP = 10, 26, 3
local COL_X, COL_W = { 190, 494 }, 296 -- right of the Browse filter list (x 186), left of the scroll bar area (797)
local METRICS = {
  { "volume", "Volume", "Trading volume: gold of C.O.D. deliveries that were actually paid." },
  { "fulfillment", "Fulfillment", "Buyers: share of the ordered amount that was delivered and paid.\nSellers: paid deliveries of all sent deliveries." },
  { "payment", "Payment", "Buyers: C.O.D. mails paid after they were seen, and the average time to pay.\nSellers: share of sent deliveries the buyer paid." },
}
local PERIODS = { { nil, "All Time" }, { 30, "30 Days" }, { 7, "7 Days" } }
local RANK_COLOR = { "|cffffd100", "|cffd0d0d0", "|cffd08a4a" }
local ROLE_TITLE = { "Top Buyers", "Top Sellers" }

local function metricName() for i = 1, table.getn(METRICS) do if METRICS[i][1] == metric then return METRICS[i][2] end end; return "" end

local function valueText(r)
  if metric == "volume" then return EGM.Util.money(r.value), r.num .. (r.num == 1 and " trade" or " trades") end
  local extra = r.num .. "/" .. r.den
  if r.nd and r.nd > 0 then extra = extra .. "  avg " .. math.floor(r.delay / r.nd / 60) .. "m" end
  return r.value .. "%", extra
end

local function periodName() if days then return days .. " days" end; return "all time" end
local function periodLabel() for i = 1, table.getn(PERIODS) do if PERIODS[i][1] == days then return PERIODS[i][2] end end; return "" end

-- same marking as the Browse filter list: gold highlight bar and white label on the selected entry
local function markSelected(btns, list, current)
  for i = 1, table.getn(btns) do
    local b = btns[i]
    local on = (list[i][1] == current)
    b._checked = on
    if b._selTex then if on then b._selTex:Show() else b._selTex:Hide() end end
    if b._label then if on then b._label:SetTextColor(1, 1, 1) else b._label:SetTextColor(1, 0.82, 0) end end
  end
end

local function update()
  if not f then return end
  markSelected(metricBtns, METRICS, metric)
  markSelected(periodBtns, PERIODS, days)
  if summary then summary:SetText(metricName() .. " - " .. periodLabel()) end
  local me = EGM.Util.player()
  local roles = { "buyers", "sellers" }
  for c = 1, 2 do
    local col = cols[c]
    col.head:SetText(ROLE_TITLE[c] .. "  |cff9d9d9d" .. metricName() .. ", " .. periodName() .. "|r")
    local top = EGM.Stats.top(roles[c], metric, days)
    local best = 0
    for i = 1, table.getn(top) do if top[i].value > best then best = top[i].value end end
    for i = 1, ROWS do
      local row, r = col.rows[i], top[i]
      if r then
        local cr, cg, cb = 0.7, 0.7, 0.7
        if EGM.Roster and EGM.Roster.classRGB then cr, cg, cb = EGM.Roster.classRGB(r.name) end
        local frac = best > 0 and r.value / best or 0
        row.bar:SetWidth(math.max(2, frac * (COL_W - 4)))
        row.bar:SetVertexColor(cr, cg, cb, 0.35)
        row.rank:SetText((RANK_COLOR[i] or "|cff9d9d9d") .. i .. "|r")
        local hex = (EGM.Roster and EGM.Roster.classHex and EGM.Roster.classHex(r.name)) or "|cffffffff"
        row.name:SetText(hex .. r.name .. "|r")
        local v, extra = valueText(r)
        row.value:SetText(v)
        row.extra:SetText(extra)
        if r.name == me then row.mine:Show() else row.mine:Hide() end
        row:Show()
      else
        row:Hide()
      end
    end
    if table.getn(top) == 0 then col.empty:Show() else col.empty:Hide() end
  end
end

local function buildColumn(c)
  local x = COL_X[c]
  local col = { rows = {} }
  local h = CreateFrame("Button", "EGMStatsHead" .. c, f, "WhoFrameColumnHeaderTemplate")
  -- headers in the row of the Browse column headers (y -82), 4 px left of the rows
  local hx, hw = x - 4, COL_W + 4
  h:SetPoint("TOPLEFT", f, "TOPLEFT", hx, -82)
  if WhoFrameColumn_SetWidth then WhoFrameColumn_SetWidth(hw, h) else h:SetWidth(hw) end
  h:Disable()
  col.head = h
  for i = 1, ROWS do
    local row = CreateFrame("Frame", "EGMStatsRow" .. c .. "_" .. i, f)
    row:SetWidth(COL_W); row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", f, "TOPLEFT", x, -105 - (i - 1) * (ROW_H + ROW_GAP))
    row.bar = row:CreateTexture(nil, "BACKGROUND")
    row.bar:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    row.bar:SetHeight(ROW_H - 2)
    row.bar:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.mine = row:CreateTexture(nil, "BORDER")
    row.mine:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.mine:SetBlendMode("ADD"); row.mine:SetAlpha(0.35)
    row.mine:SetAllPoints(row)
    row.rank = row:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    row.rank:SetPoint("RIGHT", row, "LEFT", 28, 0)
    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.name:SetPoint("LEFT", row, "LEFT", 36, 0)
    row.name:SetWidth(84); row.name:SetHeight(14); row.name:SetJustifyH("LEFT")
    row.extra = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.extra:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.extra:SetWidth(84); row.extra:SetJustifyH("RIGHT")
    row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.value:SetPoint("RIGHT", row.extra, "LEFT", -6, 0)
    row:Hide()
    col.rows[i] = row
  end
  col.empty = f:CreateFontString(nil, "ARTWORK", "GameFontDisable")
  col.empty:SetPoint("TOP", f, "TOPLEFT", x + COL_W / 2, -150)
  col.empty:SetText("No paid trades yet")
  return col
end

local function addTip(btn, title, text)
  btn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT"); GameTooltip:SetText(title, 1, 0.82, 0); GameTooltip:AddLine(text, 1, 1, 1, 1); GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function T.build(parent)
  f = parent
  cols = { buildColumn(1), buildColumn(2) }
  -- left list: same position, size and template as the Browse filter buttons (156x20 from 23,-105, 2 px apart)
  local mk = EGM.UI and EGM.UI.filterButton
  metricBtns, periodBtns = {}, {}
  local prev
  for i = 1, table.getn(METRICS) do
    local m = METRICS[i][1]
    local b
    if prev then b = mk(f, "EGMStatsMetric" .. i, METRICS[i][2], prev, 0, -2, function() T.setMetric(m) end)
    else b = mk(f, "EGMStatsMetric" .. i, METRICS[i][2], nil, 23, -105, function() T.setMetric(m) end) end
    prev = b; metricBtns[i] = b
    addTip(b, METRICS[i][2], METRICS[i][3])
  end
  for i = 1, table.getn(PERIODS) do
    local d = PERIODS[i][1]
    local gap = (i == 1) and -14 or -2 -- a gap between the metric group and the period group
    local b = mk(f, "EGMStatsPeriod" .. i, PERIODS[i][2], prev, 0, gap, function() T.setPeriod(d) end)
    prev = b; periodBtns[i] = b
  end
  -- bottom bar: only Close sits on a button slot; the left art box carries a summary (no control)
  summary = f:CreateFontString("EGMStatsSummary", "ARTWORK", "GameFontHighlightSmall")
  summary:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 30, 18)
  summary:SetWidth(140); summary:SetHeight(14); summary:SetJustifyH("LEFT")
  local close = CreateFrame("Button", "EGMStatsClose", f, "UIPanelButtonTemplate")
  close:SetWidth(80); close:SetHeight(22)
  close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 14)
  close:SetText("Close")
  close:SetScript("OnClick", function() EGM.UI.hide() end)
  update()
end

function T.refresh() update() end

function T.setMetric(m) metric = m; update() end
function T.setPeriod(d) days = d; update() end
function T.state() return metric, days end
EGM.StatsTab = T

if EGM.UI and EGM.UI.registerTab then EGM.UI.registerTab(4, T.build, T.refresh, "Browse")
else EGM.PendingTabs = EGM.PendingTabs or {}; table.insert(EGM.PendingTabs, { index = 4, build = T.build, refresh = T.refresh, art = "Browse" }) end
