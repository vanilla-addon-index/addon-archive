-- The guide window, laid out the way RestedXP Guides lays out its own (layout only: no RestedXP code or art is used).
--
--   [ Elwynn Forest: 4/51 quests  [Skip] ]  the step you are on, in a box: the guide's name and the route or difficulty at the
--   [ Casual route, on Casual          ]  top (with the Skip step button), then one line per thing to do, each with a tick box
--   [ [x] ! Accept The Fargodeep Mine  ]  (ticked when done) and an icon for what it is; the warnings, the reasons and the
--   [ [ ] * Kill Kobold Miners 3/8     ]  helpers (hearthstone, skip, rating) under them
--   [ On the way                       ]  steps you can do on the way, in a second box
--   | [ ] 10  Accept Kobold Camp ...   |  every step of the guide in a list you can scroll, each with a tick box: the step you
--   | [ ] 11  Kill Kobold Vermin   ... |  are on marked, the ones behind you ticked; tick a later one to skip it
--   [ (cog) pfQuest xpGuide 1.0  [//]  ]  the footer: the cog opens the menu (pick a guide, settings, ...), the grip resizes
--
-- Nothing straddles a box's border, so no border runs through any text. The boxes keep a gap wide enough for pfUI's borders,
-- which are drawn outside each frame.
--
-- The window moves by dragging the step boxes, the list or the footer (unless locked with the padlock). Its place and size are
-- saved. The steps and when they are done come from Steps.lua; the guide menu and starting a guide are Tracker.lua's.

local ER = pfQuest_xpGuide
local GOLD, GREY, WHITE, END = ER.GOLD, ER.GREY, ER.WHITE, ER.END
local SKIPPED = "|cffd9a24a"   -- a skipped step's title in the list: muted amber
local GREEN = ER.GREEN

local G = { lines = {}, side = {}, rows = {} }
local LINES, SIDE_LINES = 12, 6
local DEF_W, MIN_W, MAX_W = 260, 220, 460
local DEF_H, MIN_H, MAX_H = 150, 80, 640   -- the step list and the footer
local MIN_ROW_H, FOOT_H = 16, 20
local FOOT_GAP = 6     -- between the list's bottom border and the footer icons
local ICON_INSET = 4   -- from the window's left and right edges
local GAP = 12   -- between the boxes and the list: room for pfUI's borders, drawn a few pixels outside each frame
local MAX_ROWS = math.floor(MAX_H / MIN_ROW_H) + 1

-- A list row is as tall as its text needs: the list's text is a size under the guide's (ER.FontSize, pfQuest's by default).
local function RowH()
  local n = (ER.FontSize and ER.FontSize() or 12) + 4
  if n < MIN_ROW_H then n = MIN_ROW_H end
  return n
end

-- The least height of one line of text in the step box.
local function LineH()
  return (ER.FontSize and ER.FontSize() or 12) + 2
end

local function Font(fs, delta)
  if ER.ApplyFont then ER.ApplyFont(fs, delta) end
end

-- The icon for each kind of line: in-game textures of the 1.12 client.
local ICON = {
  A = "Interface\\GossipFrame\\AvailableQuestIcon",
  T = "Interface\\GossipFrame\\ActiveQuestIcon",
  C = "Interface\\Icons\\Ability_DualWield",
  K = "Interface\\Icons\\INV_Misc_Bag_08",
  U = "Interface\\Icons\\INV_Misc_Bag_07",
  X = "Interface\\Icons\\Spell_Holy_SurgeOfLight",
  H = "Interface\\Icons\\INV_Misc_Rune_01",
  F = "Interface\\GossipFrame\\TaxiGossipIcon",
  P = "Interface\\GossipFrame\\TaxiGossipIcon",
  B = "Interface\\Icons\\INV_Misc_Map_01",
  Z = "Interface\\Icons\\INV_Misc_Map_01",
  V = "Interface\\GossipFrame\\VendorGossipIcon",
  G = "Interface\\Icons\\Ability_Warrior_Charge",
  I = "Interface\\GossipFrame\\GossipGossipIcon",
}

local function Say(msg)
  if ER.Print then ER.Print(msg) end
end

local function Plain(text)
  if not text then return "" end
  text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
  text = string.gsub(text, "|r", "")
  return text
end

local function Themed() return ER.Skin and ER.Skin.On() end

-- The colour that marks "this one": OctoPad's accent with pfUI's look, gold without.
local function Mark()
  if Themed() then local t = ER.Skin.Theme() return t.ac[1], t.ac[2], t.ac[3] end
  return 0.85, 0.65, 0.3
end

local function Backdrop(f, alpha, gold)
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  f:SetBackdropColor(0, 0, 0, alpha or 0.85)
  if gold then f:SetBackdropBorderColor(0.85, 0.65, 0.3, 1) else f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1) end
  if ER.Skin then ER.Skin.Window(f, alpha) end
end

local function Tip(widget, fn)
  widget:SetScript("OnEnter", function()
    if this.Hover then this.Hover(this, true) end
    local title, body, hint = fn(this)
    if not title then return end
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText(title, 1, 0.82, 0)
    if body and body ~= "" then GameTooltip:AddLine(body, 1, 1, 1, 1) end
    if hint then GameTooltip:AddLine(hint, 0.6, 0.6, 0.6, 1) end
    GameTooltip:Show()
  end)
  widget:SetScript("OnLeave", function()
    if this.Hover then this.Hover(this, nil) end
    GameTooltip:Hide()
  end)
end

------------------------------------------------------------------------------------------------------
-- What the step box says (the same lines the old step box had)
------------------------------------------------------------------------------------------------------

local function StepLines(step, max)
  local out = {}
  local Steps = ER.Steps
  for _, e in ipairs(step.elements) do
    local line = Steps.Line(step, e)
    if line then
      line.step = step
      -- A hearth line that is not done becomes the "Use your hearthstone" button (a real click only; Auto.lua does the use), unless the
      -- Settings tick for the button is off (hearthBtnOff): then it stays a plain line and you use the hearthstone yourself.
      if line.kind == "H" and line.done ~= true and ER.Auto and ER.Auto.UseHearth and not (ER.db and ER.db.hearthBtnOff) then
        line.hearth = true
        line.text = GOLD .. "Use your hearthstone" .. END .. GREY .. " (" .. Plain(line.text) .. ")" .. END
      end
      table.insert(out, line)
      if max and table.getn(out) >= max then break end
    end
  end
  if table.getn(out) == 0 then table.insert(out, { text = Steps.Title(step), step = step }) end
  return out
end
ER.GuideStepLines = StepLines

-- The quest a step is about, for skipping it: the first pick-up, hand-in or quest work the step shows (nil when it has none).
local function StepQuest(step)
  for _, e in ipairs(step.elements) do
    local id = tonumber(e.id)
    if id and id ~= 0 and (e.kind == "A" or e.kind == "T" or e.kind == "C" or e.kind == "K") and ER.Steps.Line(step, e) then return id end
  end
  return nil
end

-- Hints for a step that says only "Finish X" or "Hand in X": the quest's own short hint, one per quest (at most two), when
-- the step has no instructions of its own (no "Talk to ...", "Kill ...", "Use ..." lines).
local function StepHints(step)
  local out = {}
  if not step or not ER.QuestHint then return out end
  for _, e in ipairs(step.elements) do
    if (e.kind == "I" or e.kind == "M" or e.kind == "U") and e.text and e.text ~= "" then return out end
  end
  local seen = {}
  for _, e in ipairs(step.elements) do
    local id = (e.kind == "C" or e.kind == "T") and tonumber(e.id)
    if id and not seen[id] and table.getn(out) < 2 and not ER.Steps.TurnedIn(id) then
      seen[id] = true
      local hint = ER.QuestHint(id)
      if hint then table.insert(out, { text = GREY .. hint .. END, step = step, note = true, hint = true }) end
    end
  end
  return out
end

local function NowLines(step)
  local Steps = ER.Steps
  local lines = {}
  if step then
    for _, l in ipairs((StepLines(step))) do table.insert(lines, l) end
    for _, l in ipairs((StepHints(step))) do table.insert(lines, l) end
    local reason = ER.WhyLine and ER.WhyLine(step)
    if reason then table.insert(lines, { text = GREY .. reason .. END, step = step, note = true }) end
    -- The Settings tick "Show warnings" off (warnOff) leaves these out; the guide's own words stay, they are the step.
    for _, w in ipairs(((ER.db and ER.db.warnOff) and {} or Steps.Warnings())) do
      if w.kind ~= "rxp" then table.insert(lines, { text = GOLD .. string.gsub(w.line, "|r", "|r" .. GOLD) .. END, step = step, note = true }) end
    end
    local hard = ER.HardLine and ER.HardLine(step)
    if hard then table.insert(lines, { text = hard, step = step, note = true }) end
    local needLevel = ER.NeedLevelLine and ER.NeedLevelLine(step)
    if needLevel then table.insert(lines, { text = needLevel, step = step, note = true }) end
    local why = ER.GrindReasonLine and ER.GrindReasonLine(step)
    if why then table.insert(lines, { text = GREY .. why .. END, step = step, note = true }) end
    local chain = ER.ChainLine and ER.ChainLine(step)
    if chain then
      for line in string.gfind(chain, "[^\n]+") do table.insert(lines, { text = GREY .. line .. END, step = step, note = true }) end
    end
    if Steps.ByHand(step) then
      table.insert(lines, { text = GREY .. "Tick the box or click here when this is done." .. END, step = step, tick = true })
    end
  else
    table.insert(lines, { text = GOLD .. "This guide is finished." .. END, note = true })
    local nxt = ER.NextToStart and ER.NextToStart()
    if nxt then
      table.insert(lines, { text = "Next: " .. WHITE .. (nxt.title or nxt.name) .. END .. GREY .. "  (click to start it)" .. END, nextGuide = nxt })
    else
      table.insert(lines, { text = GREY .. "Pick the next guide: the cog under the list, then the Guides page." .. END, note = true })
    end
  end
  return lines
end

-- Done with the step you are on: ticked by hand when it is one you tick yourself, skipped otherwise.
local function DoneOrSkip()
  G.hold = true
  local Steps = ER.Steps
  local step = Steps.Current()
  if not step then return end
  if Steps.ByHand(step) then
    Steps.Tick(step.n)
  elseif Steps.Finished and Steps.Finished(step) then
    Say("this quest is finished: hand it in. A finished quest is not skipped.")
  else
    Steps.Next(true)
  end
end

-- A step's tick box in the list: tick the one you are on to finish it (or skip it), tick a later one to skip it when the
-- guide gets there (untick to do it after all), untick one behind you to go back to it.
local function RowTick(step)
  local Steps = ER.Steps
  if not step then return end
  local pos = Steps.Position()
  G.hold = true
  if step.n == pos then
    DoneOrSkip()
  elseif step.n > pos then
    if not Steps.Passed(step.n) and Steps.Finished and Steps.Finished(step) then
      Say("step " .. step.n .. "'s quest is finished: hand it in. A finished quest is not skipped.")
    else
      Steps.SkipLater(step.n, not Steps.Passed(step.n))
    end
  elseif not Steps.CanUnskip or Steps.CanUnskip(step.n) then
    if Steps.Retake then Steps.Retake(step.n) else Steps.Jump(step.n) end
  elseif Steps.DroppedIn and Steps.DroppedIn(step) then
    Say("step " .. step.n .. " is skipped for good: you abandoned its quest and it can no longer be picked up.")
  else
    Say("step " .. step.n .. " is done.")
  end
  if G.Refresh then G.Refresh() end
end

local function RowTickTip(step, done, how)
  local Steps = ER.Steps
  local pos = Steps.Position()
  local finished = Steps.Finished and Steps.Finished(step)
  if step.n == pos then
    if Steps.ByHand(step) then return "Step " .. step.n, "Tick when you have done this.", nil end
    if finished then return "Step " .. step.n, "The quest is finished: hand it in.", "A finished quest cannot be skipped." end
    return "Step " .. step.n, "Tick to skip this step and move on.", "The guide never skips a step by itself."
  elseif step.n > pos then
    if done then return "Step " .. step.n, "Skipped by you: the guide will pass over it.", "Click to do it after all." end
    if finished then return "Step " .. step.n, "The quest is finished: hand it in.", "A finished quest cannot be skipped." end
    return "Step " .. step.n, "Tick to skip this step: the guide will pass over it.", nil
  end
  if not done then return "Step " .. step.n, "Brought back: you picked its quest up again, so this is to do again.", "Click to go back to it now; the guide also offers it in the step box." end
  if how == "done" or (Steps.CanUnskip and not Steps.CanUnskip(step.n)) then return "Step " .. step.n, "Completed.", nil end
  if how == "skip" and Steps.CanUnskip and not Steps.CanUnskip(step.n) then
    return "Step " .. step.n, "Skipped for good: its quest can no longer be done (grey now, or handed in).", nil
  end
  if how == "skip" then return "Step " .. step.n, "Skipped by you.", "Click to go back to this step." end
  if how == "passed" and Steps.DroppedIn and Steps.DroppedIn(step) then
    return "Step " .. step.n, "Skipped for good: you abandoned " .. Plain(Steps.QuestTitle(Steps.DroppedIn(step)) or "its quest") .. " and it can no longer be picked up.", nil
  end
  if how == "abandoned" then
    local id = Steps.AbandonedIn and Steps.AbandonedIn(step)
    local title = id and Steps.QuestTitle(id) or "its quest"
    return "Step " .. step.n, "Passed over: you abandoned " .. Plain(title) .. ".",
      "Click to go back to it and pick the quest up again. Taking it again from the quest giver brings its steps back too."
  end
  return "Step " .. step.n, "Passed over by the guide: its quest was not taken, not needed, or you went past it.", "Click to go back to this step."
end

-- A line was clicked (or its tick box).
local function LineClick(line)
  if not line then return end
  if line.hearth then
    if ER.Auto and ER.Auto.UseHearth then ER.Auto.UseHearth() end
    return
  end

  if line.nextGuide then
    -- A casual-route zone that follows its own zone starts at the top (the part-way scan is for a guide picked from the menu).
    local nxt, skipped = ER.NextToStart()
    nxt = nxt or line.nextGuide
    local prev = ER.Steps.Info()
    if ER.StartGuide(ER.Steps.Key(nxt), nxt.route and true or nil, skipped and true or nil) and skipped and ER.RouteNextLine then
      local words = ER.RouteNextLine(prev, nxt, skipped)
      if words then Say(words) end
    end
    return
  end
  if not line.step then return end
  if line.tick or line.kind == "M" or ER.Steps.ByHand(line.step) then
    G.hold = true
    ER.Steps.Tick(line.step.n)
  end
end

local function LineTip(btn)
  local line = btn.line
  if line and line.nextGuide then return "Next guide", Plain(line.nextGuide.title or line.nextGuide.name), "Click to start it." end
  if not line or not line.step then return nil end
  local hint = "The arrow shows where this happens."
  if line.done ~= nil then hint = "Ticked by itself when you do it in the game." end
  if line.tick or line.kind == "M" or ER.Steps.ByHand(line.step) then hint = "Tick the box or click when you have done this." end
  if line.hearth then hint = "Click to use your hearthstone. The guide never uses it by itself." end
  return Plain(ER.Steps.Title(line.step)), Plain(line.text), hint
end

------------------------------------------------------------------------------------------------------
-- The step boxes
------------------------------------------------------------------------------------------------------

local function MakeLine(box, name)
  local b = CreateFrame("Button", name, box)
  b:SetHeight(14)
  local glow = b:CreateTexture(nil, "HIGHLIGHT")
  glow:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  glow:SetBlendMode("ADD")
  glow:SetAllPoints(b)
  local tick = CreateFrame("CheckButton", name .. "Tick", b, "UICheckButtonTemplate")
  tick:SetWidth(14)
  tick:SetHeight(14)
  tick:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 1)
  tick:SetScript("OnClick", function()
    local line = this:GetParent().line
    -- the box shows what the game says; only a step you tick by hand changes when you click it
    this:SetChecked(line and line.done == true and 1 or nil)
    if line and (line.tick or line.kind == "M" or (line.step and ER.Steps.ByHand(line.step))) then LineClick(line) end
  end)
  b.tickBox = tick
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetWidth(12)
  b.icon:SetHeight(12)
  b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 16, 0)
  b.text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  b.text:SetPoint("TOPLEFT", b, "TOPLEFT", 31, 0)
  b.text:SetJustifyH("LEFT")
  b.text:SetJustifyV("TOP")
  Font(b.text, 0)
  b:SetScript("OnClick", function() LineClick(this.line) end)
  Tip(b, LineTip)
  b:Hide()
  return b
end

local function MakeBox(name, parent, heading)
  local box = CreateFrame("Frame", name, parent)
  box:SetHeight(40)
  Backdrop(box, 0.9, true)
  box:EnableMouse(true)
  -- the heading, inside the box: the guide's name and its route or difficulty (the step box), or "On the way"
  box.title = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  box.title:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -9)
  box.title:SetJustifyH("LEFT")
  Font(box.title, 1)
  if heading then
    box.detail = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    box.detail:SetPoint("TOPLEFT", box.title, "BOTTOMLEFT", 0, -2)
    box.detail:SetJustifyH("LEFT")
    Font(box.detail, -2)
  end
  -- a thin line between the heading and the lines
  box.rule = box:CreateTexture(nil, "ARTWORK")
  box.rule:SetTexture("Interface\\Buttons\\WHITE8X8")
  box.rule:SetHeight(1)
  box.rule:SetVertexColor(1, 1, 1, 0.12)
  return box
end

-- The "Skip step" button inside the step box, top right, next to the guide's name: one click, no menu. On a step you tick by
-- hand it says "Mark done".
local function SmallButton(box, name)
  local b = CreateFrame("Button", name, box)
  b:SetHeight(18)
  b:SetWidth(70)
  Backdrop(b, 1, true)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
  Font(b.text, -1)
  local glow = b:CreateTexture(nil, "HIGHLIGHT")
  glow:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  glow:SetBlendMode("ADD")
  glow:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
  glow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
  return b
end

-- Sizes a small button to its words and the text size.
local function FitButton(b, words)
  b.text:SetText(GOLD .. words .. END)
  b:SetHeight(math.max(18, ((ER.FontSize and ER.FontSize()) or 12) + 5))
  b:SetWidth(math.max(56, b.text:GetStringWidth() + 16))
end

-- "Unskip previous", left of Skip: back to the step behind when you skipped it yourself.
local function MakeUnskip(box, name)
  local b = SmallButton(box, name)
  b:SetPoint("TOPRIGHT", box.skip, "TOPLEFT", -4, 0)
  b:SetScript("OnClick", function()
    local n = ER.Steps.SkippedBehind and ER.Steps.SkippedBehind()
    if n then
      G.hold = true
      ER.Steps.Jump(n)
    end
  end)
  Tip(b, function()
    local n = ER.Steps.SkippedBehind and ER.Steps.SkippedBehind()
    if not n then return nil end
    return "Unskip previous", "Back to step " .. n .. ", which you skipped.", nil
  end)
  b:Hide()
  box.unskip = b
  return b
end

local function MakeSkip(box, name)
  local b = CreateFrame("Button", name, box)
  b:SetHeight(18)
  b:SetWidth(70)
  b:SetPoint("TOPRIGHT", box, "TOPRIGHT", -8, -8)
  Backdrop(b, 1, true)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
  Font(b.text, -1)
  local glow = b:CreateTexture(nil, "HIGHLIGHT")
  glow:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  glow:SetBlendMode("ADD")
  glow:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
  glow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
  b:SetScript("OnClick", function() DoneOrSkip() end)
  Tip(b, function()
    local step = ER.Steps.Current()
    if not step then return nil end
    if ER.Steps.ByHand(step) then return "Mark done", "Tick this step off and move on.", nil end
    if ER.Steps.Finished and ER.Steps.Finished(step) then return "Finished", "The quest is finished: hand it in.", "A finished quest cannot be skipped." end
    return "Skip step", "Skip this step and move on.", "The guide never skips a step by itself."
  end)
  box.skip = b
  return b
end

-- Fills a box with lines; returns its height.
local function FillBox(box, widgets, lines, width, title, detail)
  local inner = width - 20
  local room = inner - ((box.skip and box.skip:IsShown()) and (box.skip:GetWidth() + 6) or 0)
    - ((box.unskip and box.unskip:IsShown()) and (box.unskip:GetWidth() + 4) or 0)
  local size = (ER.FontSize and ER.FontSize()) or 12
  -- a title given as { head, tail } is shortened in its head only: "Elwynn F...: 4/51 quests" keeps how far you are
  if type(title) == "table" then ER.FitLine(box.title, title[1], room, title[2]) else ER.FitLine(box.title, title or "", room) end
  local y = -9 - (size + 3)
  if box.detail then
    ER.FitLine(box.detail, detail or "", room)
    y = y - (size + 1)
  end
  box.rule:ClearAllPoints()
  box.rule:SetPoint("TOPLEFT", box, "TOPLEFT", 10, y - 2)
  box.rule:SetPoint("TOPRIGHT", box, "TOPRIGHT", -10, y - 2)
  y = y - 7
  for i = 1, table.getn(widgets) do
    local b, line = widgets[i], lines[i]
    if line then
      b.line = line
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", box, "TOPLEFT", 10, y)
      b:SetWidth(inner)
      -- the tick box for what the game ticks or you tick; the icon for what kind of thing it is
      local hasTick = line.done ~= nil or line.tick
      if hasTick then
        b.tickBox:Show()
        b.tickBox:SetChecked(line.done == true and 1 or nil)
      else
        b.tickBox:Hide()
      end
      local icon = (not line.note) and line.kind and ICON[line.kind]
      if line.hearth then icon = ICON.H end
      if icon then
        b.icon:SetTexture(icon)
        b.icon:Show()
      else
        b.icon:Hide()
      end
      local left = (hasTick or icon) and 31 or 4
      b.text:ClearAllPoints()
      b.text:SetPoint("TOPLEFT", b, "TOPLEFT", left, 0)
      local text = line.text or ""
      if line.done == true then text = GREY .. Plain(text) .. END end
      local h = ER.FitHeight(b.text, text, inner - left, LineH()) + 2
      b:SetHeight(h)
      b:Show()
      y = y - h - 2
    else
      b.line = nil
      b:Hide()
    end
  end
  local height = -y + 6
  box:SetHeight(height)
  return height
end

------------------------------------------------------------------------------------------------------
-- The step list
------------------------------------------------------------------------------------------------------

local function ListRows()
  -- the list fills the window above the footer
  local h = ((G.frame and G.frame:GetHeight()) or DEF_H) - (FOOT_H + FOOT_GAP)
  local n = math.floor((h - 10) / RowH())
  if n < 1 then n = 1 end
  if n > MAX_ROWS then n = MAX_ROWS end
  return n
end

-- Where the list is scrolled to. When the guide moves on by itself, the step you are on sits under the last few done
-- (KEEP_DONE of them, fewer in a short window), so you can see what was just ticked off. When you moved it yourself (a tick
-- box, Skip, Unskip, Mark done), the list stays where it is, only scrolling as far as needed to keep the current step in view.
local KEEP_DONE = 3

-- The quest a step is about: its first pick-up, quest work or hand-in.
local function MainQuest(step)
  for _, e in ipairs(step.elements or {}) do
    if (e.kind == "A" or e.kind == "C" or e.kind == "T") and tonumber(e.id) and tonumber(e.id) ~= 0 then return tonumber(e.id) end
  end
  return nil
end

-- Chain colours: each quest chain with two or more of its quests in this guide gets a colour, in the order its first
-- quest appears; every step about one of its quests shows a mark in that colour beside its number, so a chain's steps
-- can be told apart from another's even where the guide goes back and forth between them. The guide's order is kept.
-- Colour-blind friendly: every chain has its own shape as well as its colour (the Okabe-Ito colours, told apart with the
-- common colour-vision differences), so the shape alone tells two chains apart.
local CHAIN_COLOURS = {
  { 0.90, 0.62, 0.00 }, { 0.34, 0.71, 0.91 }, { 0.00, 0.62, 0.45 }, { 0.94, 0.89, 0.26 },
  { 0.00, 0.45, 0.70 }, { 0.84, 0.37, 0.00 }, { 0.80, 0.47, 0.65 }, { 0.86, 0.86, 0.86 },
}
local CHAIN_SHAPES = { "Circle", "Square", "Triangle", "Diamond", "Ring", "Plus", "TriangleDown", "Bar" }
local SHAPE_WORDS = { Circle = "circle", Square = "square", Triangle = "triangle", Diamond = "diamond", Ring = "ring",
  Plus = "plus", TriangleDown = "down triangle", Bar = "bar" }
local MAX_MARKS = 3
-- Chain lines: each chain gets a lane (a narrow column between the tick box and the step's text). Its line runs without
-- a break from its first step in the list to its last, through the steps of other quests in between, with the chain's
-- shape on the line at each of its own steps, like a metro map. Chains that overlap get different lanes; those that
-- follow one another share one.
local MAX_LANES, LANE_W, LANE_X = 5, 7, 21

-- { [step number] = { { root, colour, title, part, parts }, ... } } for the list, worked out once per guide.
local function ChainMarks(all)
  local info = ER.Steps.Info()
  local key = (info and info.name or "") .. "#" .. table.getn(all)
  if G.marksKey == key and G.marks then return G.marks end
  local marks = {}
  if not ER.ChainOf or not ER.Steps.StepQuests then
    G.marks, G.marksKey, G.colourByQuest, G.colourByTitle, G.shapeByTitle = marks, key, {}, {}, {}
    G.lanes, G.laneCount = {}, 0
    return marks
  end
  -- which chains have two or more of their quests here, and in what order they first show
  local quests, order, rootOf = {}, {}, {}
  for _, it in ipairs(all) do
    for _, id in ipairs((ER.Steps.StepQuests(it.step))) do
      if rootOf[id] == nil then
        local chain = ER.ChainOf(id)
        rootOf[id] = chain and chain.first or false
        if chain then
          local r = chain.first
          if not quests[r] then quests[r] = { ids = {}, count = 0, chain = chain } table.insert(order, r) end
          if not quests[r].ids[id] then quests[r].ids[id] = true quests[r].count = quests[r].count + 1 end
        end
      end
    end
  end
  local colourOf, n = {}, 0
  for _, r in ipairs(order) do
    if quests[r].count >= 2 then
      n = n + 1
      colourOf[r] = { colour = CHAIN_COLOURS[math.mod(n - 1, table.getn(CHAIN_COLOURS)) + 1],
        shape = CHAIN_SHAPES[math.mod(n - 1, table.getn(CHAIN_SHAPES)) + 1] }
    end
  end
  for _, it in ipairs(all) do
    local list, seen = {}, {}
    for _, id in ipairs((ER.Steps.StepQuests(it.step))) do
      local r = rootOf[id]
      if r and colourOf[r] and not seen[r] and table.getn(list) < MAX_MARKS then
        seen[r] = true
        local chain = ER.ChainOf(id)
        table.insert(list, { root = r, colour = colourOf[r].colour, shape = colourOf[r].shape, title = ER.Steps.QuestTitle(r) or ER.Steps.QuestTitle(id) or ("quest " .. r),
          part = chain and chain.pos or 1, parts = chain and chain.len or 1 })
      end
    end
    if table.getn(list) > 0 then marks[it.step.n] = list end
  end
  -- each chain's span in the list (by place in the list, not step number) and its lane
  local span, roots = {}, {}
  for idx, it in ipairs(all) do
    for _, m in ipairs(marks[it.step.n] or {}) do
      local sp = span[m.root]
      if not sp then sp = { a = idx, b = idx, colour = m.colour, root = m.root } span[m.root] = sp table.insert(roots, sp) end
      sp.b = idx
    end
  end
  local laneEnd, count = {}, 0
  for _, sp in ipairs(roots) do   -- in the order the chains start
    if sp.b > sp.a then
      for l = 1, MAX_LANES do
        if not laneEnd[l] or laneEnd[l] < sp.a then
          sp.lane, laneEnd[l] = l, sp.b
          if l > count then count = l end
          break
        end
      end
    end
  end
  local lanes = {}
  for l = 1, MAX_LANES do lanes[l] = {} end
  for _, sp in ipairs(roots) do if sp.lane then table.insert(lanes[sp.lane], sp) end end
  G.lanes, G.laneCount, G.spans = lanes, count, span
  -- for the nameplate markers (Plates.lua): each marked chain's colour by quest number and by quest title
  local byQuest, byTitle, shapeByTitle = {}, {}, {}
  for id, r in pairs(rootOf) do
    if r and colourOf[r] then
      byQuest[id] = colourOf[r].colour
      local t = ER.Steps.QuestTitle(id)
      if t then byTitle[t] = colourOf[r].colour shapeByTitle[t] = colourOf[r].shape end
    end
  end
  G.colourByQuest, G.colourByTitle, G.shapeByTitle = byQuest, byTitle, shapeByTitle
  G.marks, G.marksKey = marks, key
  return marks
end
G.ChainMarks = ChainMarks

-- A quest's chain colour in the step list (the colour of its steps' marks), or nil when it is in no marked chain.
function ER.ChainColourForQuest(id)
  if not G.colourByQuest and ER.Steps.Running() then ChainMarks(ER.Steps.All()) end
  return G.colourByQuest and G.colourByQuest[tonumber(id)]
end
function ER.ChainColourForTitle(title)
  if not G.colourByTitle and ER.Steps.Running() then ChainMarks(ER.Steps.All()) end
  return G.colourByTitle and G.colourByTitle[title]
end
-- Its chain's shape in the step list ("Circle", "Square", ...), or nil.
function ER.ChainShapeForTitle(title)
  if not G.shapeByTitle and ER.Steps.Running() then ChainMarks(ER.Steps.All()) end
  return G.shapeByTitle and G.shapeByTitle[title]
end

-- The mouse over a step: every other step in view of the same chain (or chains) lights up in that chain's colour, and
-- the chain's line goes to full strength; off the step, they go back.
G.LightChains = function(row)
  local roots = {}
  if row and row.chains then for _, m in ipairs(row.chains) do roots[m.root] = m.colour end end
  for i = 1, MAX_ROWS do
    local r = G.rows and G.rows[i]
    if r and r.related then
      local colour
      if row and r ~= row and r:IsShown() and r.chains then
        for _, m in ipairs(r.chains) do if roots[m.root] then colour = colour or roots[m.root] end end
      end
      if colour then
        r.related:SetVertexColor(colour[1], colour[2], colour[3], 0.22)
        r.related:Show()
      else
        r.related:Hide()
      end
      -- the chain's line at full strength all along while one of its steps is under the mouse
      for _, rail in ipairs(r.rail or {}) do
        if rail.chain and rail.colour then
          local a = (row and roots[rail.chain]) and 1 or rail.alpha
          rail.up:SetVertexColor(rail.colour[1], rail.colour[2], rail.colour[3], a)
          rail.down:SetVertexColor(rail.colour[1], rail.colour[2], rail.colour[3], a)
        end
      end
    end
  end
  G.lit = row
end

local function FillList()
  local all = ER.Steps.All()
  G.all = all
  local pos = ER.Steps.Position()
  local cur
  for i, it in ipairs(all) do if it.step.n == pos then cur = i end end
  local shown = ListRows()
  local total = table.getn(all)
  if G.followPos ~= pos then
    G.followPos = pos
    local off
    local keep = KEEP_DONE
    if keep > math.floor((shown - 1) / 2) then keep = math.floor((shown - 1) / 2) end
    if G.hold and G.offset then
      off = G.offset
      if cur and cur <= off then off = cur - 1 end
      if cur and cur > off + shown then off = cur - shown end
    else
      off = (cur or 1) - 1 - keep
      -- a step you can go back to (abandoned or skipped, shown as a button) is not scrolled out of view above: the list
      -- keeps the newest one at the top (the step you are on is always in the step box above the list)
      local pin
      for i, it in ipairs(all) do if it.regain and cur and i < cur then pin = i end end
      if pin and pin - 1 < off then off = pin - 1 end
    end
    if off > total - shown then off = total - shown end
    if off < 0 then off = 0 end
    G.offset = off
    if G.scroll then
      FauxScrollFrame_SetOffset(G.scroll, off)
      local bar = getglobal(G.scroll:GetName() .. "ScrollBar")
      if bar and bar.SetValue then bar:SetValue(off * RowH()) end
    end
  end
  -- a window made taller (or a guide that got shorter) never leaves empty rows under the last step
  local most = total - shown
  if most < 0 then most = 0 end
  if (G.offset or 0) > most then G.offset = most end
  if (G.offset or 0) < 0 then G.offset = 0 end
  G.hold = nil
  local rowH = RowH()
  if G.scroll then FauxScrollFrame_Update(G.scroll, total, shown, rowH) end
  local off = G.offset or 0
  local width = G.frame:GetWidth()
  local r1, g1, b1 = Mark()
  local marks = ChainMarks(all)
  for i = 1, MAX_ROWS do
    local r = G.rows[i]
    local it = (i <= shown) and all[off + i]
    if it then
      local s = it.step
      r.step = s
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", G.list, "TOPLEFT", 6, -5 - (i - 1) * rowH)
      r:SetHeight(rowH)
      r.text:SetHeight(rowH - 2)
      r:SetWidth(width - 34)
      r.num:SetText(GREY .. s.n .. END)
      -- the chain lines: in each lane, the line of the chain whose span covers this row (top half unless it starts here,
      -- bottom half unless it ends here), brighter on the chain's own steps; the chain's shape on the line at its steps
      r.chains = marks[s.n]
      local idx = off + i
      local half = math.floor(rowH / 2)
      local mine = {}
      for _, m in ipairs(r.chains or {}) do mine[m.root] = true end
      for l = 1, MAX_LANES do
        local rail, sp = r.rail[l], nil
        for _, c in ipairs(G.lanes[l] or {}) do if c.a <= idx and idx <= c.b then sp = c break end end
        rail.chain = sp and sp.root or nil
        if sp then
          local a = mine[sp.root] and 0.9 or 0.45
          rail.up:SetHeight(rowH - half)
          rail.down:SetHeight(half)
          rail.colour, rail.alpha = sp.colour, a
          rail.up:SetVertexColor(sp.colour[1], sp.colour[2], sp.colour[3], a)
          rail.down:SetVertexColor(sp.colour[1], sp.colour[2], sp.colour[3], a)
          if idx > sp.a then rail.up:Show() else rail.up:Hide() end
          if idx < sp.b then rail.down:Show() else rail.down:Hide() end
        else
          rail.up:Hide()
          rail.down:Hide()
        end
      end
      local extra = 0
      for k = 1, MAX_MARKS do
        local m = r.chains and r.chains[k]
        local t = r.chainMark[k]
        if m then
          local sp = G.spans and G.spans[m.root]
          t:ClearAllPoints()
          if sp and sp.lane then
            t:SetPoint("CENTER", r, "LEFT", LANE_X + (sp.lane - 1) * LANE_W, 0)
          else
            -- a chain with only this step in the list, or more chains than lanes: its shape beside the number
            t:SetPoint("RIGHT", r, "RIGHT", -26 - extra * 11, 0)
            extra = extra + 1
          end
          t:SetTexture("Interface\\AddOns\\pfQuest_xpGuide\\Media\\Chain" .. m.shape)
          t:SetVertexColor(m.colour[1], m.colour[2], m.colour[3], 1)
          t:Show()
        else
          t:Hide()
        end
      end
      local indent = (G.laneCount or 0) > 0 and (G.laneCount * LANE_W + 1) or 0
      local markRoom = extra > 0 and (extra * 11 + 4) or 0
      r.text:ClearAllPoints()
      r.text:SetPoint("LEFT", r, "LEFT", 18 + indent, 0)
      local title = Plain(ER.Steps.Title(s))
      if s.n == pos then
        ER.FitLine(r.text, WHITE .. title .. END, width - 70 - indent - markRoom)
        r.bar:SetVertexColor(r1, g1, b1, 1)
        r.bar:Show()
        r.bg:SetVertexColor(r1, g1, b1, 0.18)
        r.bg:Show()
        r:SetAlpha(1)
      else
        -- completed: grey, ticked; skipped or passed over: muted amber, with the skip mark; still to come: white
        local colour = WHITE
        if it.how == "done" then colour = GREY elseif it.how then colour = SKIPPED end
        ER.FitLine(r.text, colour .. title .. END, width - 70 - indent - markRoom)
        r.bar:Hide()
        r.bg:Hide()
        r:SetAlpha(it.done and (it.how == "done" and 0.5 or 0.7) or 0.75)
      end
      r.done = it.done
      r.how = it.how
      local skipped = it.done and it.how ~= "done"
      r.check:SetChecked((it.done and not skipped) and 1 or nil)
      if skipped then r.skipMark:Show() else r.skipMark:Hide() end
      r.regain = it.regain
      if it.regain then
        for _, t in ipairs(r.btn) do
          t:SetVertexColor(r1, g1, b1, 0.9)
          t:Show()
        end
        r.bg:SetVertexColor(r1, g1, b1, 0.12)
        r.bg:Show()
        ER.FitLine(r.text, GOLD .. title .. END, width - 70 - indent - markRoom)
        r:SetAlpha(1)
      else
        for _, t in ipairs(r.btn) do t:Hide() end
      end
      r:Show()
    else
      r.step = nil
      r:Hide()
    end
  end
  if G.FillBackCount then G.FillBackCount(all) end
  -- the rows show other steps now: light the chain again for the step under the mouse
  if G.lit then G.LightChains(G.lit:IsShown() and G.lit.chains and G.lit or nil) end
end

-- The footer's count of steps you can go back to (abandoned or skipped quests shown as buttons in the list).
local function FillBackCount(all)
  local b = G.backCount
  if not b then return end
  local n, firstIdx = 0, nil
  for i, it in ipairs(all) do
    if it.regain then
      n = n + 1
      firstIdx = firstIdx or i
    end
  end
  b.firstIdx = firstIdx
  if n == 0 then
    b:Hide()
    return
  end
  b.text:SetText(GOLD .. n .. (n == 1 and " step" or " steps") .. " to go back to" .. END)
  b:SetWidth(b.text:GetStringWidth() + 4)
  b:Show()
end
G.FillBackCount = FillBackCount

-- The menu for a step in the list (right-click or double-click), as RestedXP's.
local function StepMenu(step)
  local items = {
    { text = "Step " .. step.n, title = true },
    { text = "Go to step " .. step.n, fn = function() ER.Steps.Jump(step.n) end },
  }
  local id = StepQuest(step)
  if id and ER.ShowSkipMenu then
    table.insert(items, { text = "Skip its quest...", fn = function() ER.ShowSkipMenu(id) end })
  end
  ER.PopupMenu(items)
end

------------------------------------------------------------------------------------------------------
-- The menus: the game's own drop-down list (pfUI skins it), at the mouse
------------------------------------------------------------------------------------------------------

local menuFrame
function ER.PopupMenu(items)
  if not menuFrame then menuFrame = CreateFrame("Frame", "pfQuest_xpGuideGuideMenuDrop", UIParent, "UIDropDownMenuTemplate") end
  G.menuItems = items
  UIDropDownMenu_Initialize(menuFrame, function()
    for _, it in ipairs(G.menuItems or {}) do
      local info = {}
      info.text = it.text
      info.isTitle = it.title and 1 or nil
      info.notCheckable = 1
      info.checked = it.checked and 1 or nil
      local fn = it.fn
      if fn then info.func = function() CloseDropDownMenus() fn() end end
      UIDropDownMenu_AddButton(info)
    end
  end, "MENU")
  ToggleDropDownMenu(1, nil, menuFrame, "cursor", 0, 0)
end


------------------------------------------------------------------------------------------------------
-- Building it
------------------------------------------------------------------------------------------------------

local function SavePlace()
  local f = G.frame
  local point, _, relPoint, x, y = f:GetPoint(1)
  if ER.db then
    ER.db.guidePos = { point = point, relPoint = relPoint, x = x, y = y }
    ER.db.guideSize = { w = math.floor(f:GetWidth() + 0.5), h = math.floor(f:GetHeight() + 0.5) }
  end
end

local function Draggable(widget)
  widget:EnableMouse(true)
  widget:RegisterForDrag("LeftButton")
  widget:SetScript("OnDragStart", function()
    if ER.db and ER.db.guideLocked then return end
    G.frame:StartMoving()
  end)
  widget:SetScript("OnDragStop", function()
    G.frame:StopMovingOrSizing()
    SavePlace()
  end)
end

-- Footer icons: small smooth line-art pictures (Media\Icon*.tga, white, tinted here), no border, the accent colour under
-- the mouse. Each sits in a 16 px button with the picture inset, so the click area is comfortable and nothing touches a border.
local MEDIA = "Interface\\AddOns\\pfQuest_xpGuide\\Media\\"
local ICON_SIZE, ICON_BOX = 13, 16

local function IconColour(b)
  local r, g, bl, a = 0.78, 0.78, 0.78, 0.9
  if b.over then
    r, g, bl = Mark()
    a = 1
  elseif b.dim then
    a = 0.35
  end
  b.pic:SetVertexColor(r, g, bl, a)
end

local function IconSet(b, name)
  b.picName = name
  b.pic:SetTexture(MEDIA .. name)
end

local function IconButton(parent, name, pic)
  local b = CreateFrame("Button", name, parent)
  b:SetWidth(ICON_BOX)
  b:SetHeight(ICON_BOX)
  b.pic = b:CreateTexture(nil, "ARTWORK")
  b.pic:SetWidth(ICON_SIZE)
  b.pic:SetHeight(ICON_SIZE)
  b.pic:SetPoint("CENTER", b, "CENTER", 0, 0)
  IconSet(b, pic)
  IconColour(b)
  b.Hover = function(self, on)
    self.over = on
    IconColour(self)
  end
  return b
end

-- The footer icons follow the settings: the padlock shut when the window is locked (and the grip dim), the arrow dim when
-- there is none.
G.FootIcons = function()
  if G.lockBtn then
    local locked = ER.db and ER.db.guideLocked
    IconSet(G.lockBtn, locked and "IconLocked" or "IconUnlocked")
    IconColour(G.lockBtn)
    if G.grip then
      G.grip.dim = locked
      IconColour(G.grip)
    end
  end
  if G.arrowBtn then
    G.arrowBtn.dim = ER.ArrowChoice and ER.ArrowChoice() == "off"
    IconColour(G.arrowBtn)
  end
end

local function Build()
  -- The main frame is the list and the footer; the step boxes stack on top of it.
  local f = CreateFrame("Frame", "pfQuest_xpGuideGuide", UIParent)
  G.frame = f
  local size = ER.db and ER.db.guideSize
  f:SetWidth((size and size.w) or DEF_W)
  f:SetHeight((size and size.h) or DEF_H)
  local pos = ER.db and ER.db.guidePos
  if type(pos) == "table" and pos.point then
    f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
  else
    f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -330)
  end
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:SetResizable(true)
  f:SetMinResize(MIN_W, MIN_H)
  f:SetMaxResize(MAX_W, MAX_H)
  f:SetScript("OnShow", function() if G.Refresh then G.Refresh() end end)
  f:SetScript("OnSizeChanged", function() if G.Refresh then G.Refresh() end end)
  f:Hide()

  -- The list of every step.
  local list = CreateFrame("Frame", "pfQuest_xpGuideGuideList", f)
  G.list = list
  list:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  list:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, FOOT_H + FOOT_GAP)
  Backdrop(list, 0.8)
  Draggable(list)
  list:EnableMouseWheel(true)
  list:SetScript("OnMouseWheel", function()
    local total, shown = table.getn(G.all or {}), ListRows()
    local off = (G.offset or 0) - (arg1 or 0) * 3
    if off > total - shown then off = total - shown end
    if off < 0 then off = 0 end
    G.offset = off
    if G.scroll then
      FauxScrollFrame_SetOffset(G.scroll, off)
      local bar = getglobal(G.scroll:GetName() .. "ScrollBar")
      if bar and bar.SetValue then bar:SetValue(off * RowH()) end
    end
    FillList()
  end)
  local scroll = CreateFrame("ScrollFrame", "pfQuest_xpGuideGuideScroll", list, "FauxScrollFrameTemplate")
  G.scroll = scroll
  scroll:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -5)
  scroll:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -26, 5)
  scroll:SetScript("OnVerticalScroll", function()
    FauxScrollFrame_OnVerticalScroll(RowH(), function()
      G.offset = FauxScrollFrame_GetOffset(G.scroll)
      FillList()
    end)
  end)
  for i = 1, MAX_ROWS do
    local r = CreateFrame("Button", "pfQuest_xpGuideGuideRow" .. i, list)
    r:SetHeight(MIN_ROW_H)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    r.bg:SetAllPoints(r)
    r.bar = r:CreateTexture(nil, "ARTWORK")
    r.bar:SetTexture("Interface\\Buttons\\WHITE8X8")
    r.bar:SetWidth(2)
    r.bar:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
    r.bar:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
    local glow = r:CreateTexture(nil, "HIGHLIGHT")
    glow:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    glow:SetBlendMode("ADD")
    glow:SetAllPoints(r)
    -- the step's tick box: ticked when the step is behind you (or skipped); click it to finish, skip or go back (RowTick)
    local box = CreateFrame("CheckButton", "pfQuest_xpGuideGuideRow" .. i .. "Tick", r, "UICheckButtonTemplate")
    box:SetWidth(16)
    box:SetHeight(16)
    box:SetPoint("LEFT", r, "LEFT", 1, 0)
    box:SetScript("OnClick", function() RowTick(this:GetParent().step) end)
    Tip(box, function(b)
      local row = b:GetParent()
      if not row.step then return nil end
      return RowTickTip(row.step, row.done, row.how)
    end)
    r.check = box
    -- a skipped step shows a "skip" mark in its box instead of a tick, so it is not mistaken for one that was done
    -- (on its own layer above the box: pfUI's checkbox skin strips the box's own textures)
    local markLayer = CreateFrame("Frame", nil, box)
    markLayer:SetAllPoints(box)
    markLayer:SetFrameLevel(box:GetFrameLevel() + 3)
    r.skipMark = markLayer:CreateTexture(nil, "OVERLAY")
    r.skipMark:SetTexture("Interface\\AddOns\\pfQuest_xpGuide\\Media\\IconSkipped")
    r.skipMark:SetWidth(11)
    r.skipMark:SetHeight(11)
    r.skipMark:SetPoint("CENTER", markLayer, "CENTER", 0, 0)
    r.skipMark:SetVertexColor(0.95, 0.65, 0.25, 1)
    r.skipMark:Hide()
    -- lit when the mouse is over another step of the same chain
    r.related = r:CreateTexture(nil, "BACKGROUND")
    r.related:SetTexture("Interface\\Buttons\\WHITE8X8")
    r.related:SetAllPoints(r)
    r.related:Hide()
    r.Hover = function(self, on) G.LightChains(on and self or nil) end
    r.check.Hover = function(self, on) G.LightChains(on and r or nil) end
    -- an abandoned quest that can still be picked up: the row looks like a button (accent outline and fill); a click goes
    -- back to where you pick it up, so the arrow points at the quest giver
    r.btn = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
      local t = r:CreateTexture(nil, "BORDER")
      t:SetTexture("Interface\\Buttons\\WHITE8X8")
      if side == "TOP" or side == "BOTTOM" then
        t:SetHeight(1)
        t:SetPoint(side .. "LEFT", r, side .. "LEFT", 0, 0)
        t:SetPoint(side .. "RIGHT", r, side .. "RIGHT", 0, 0)
      else
        t:SetWidth(1)
        t:SetPoint("TOP" .. side, r, "TOP" .. side, 0, 0)
        t:SetPoint("BOTTOM" .. side, r, "BOTTOM" .. side, 0, 0)
      end
      t:Hide()
      table.insert(r.btn, t)
    end
    -- the chain lines (see MAX_LANES): two halves a lane, so a line can start or end at a step's shape
    r.rail = {}
    for l = 1, MAX_LANES do
      local x = LANE_X + (l - 1) * LANE_W
      local up = r:CreateTexture(nil, "BORDER")
      up:SetTexture("Interface\\Buttons\\WHITE8X8")
      up:SetWidth(2)
      up:SetPoint("TOP", r, "TOPLEFT", x, 0)
      local down = r:CreateTexture(nil, "BORDER")
      down:SetTexture("Interface\\Buttons\\WHITE8X8")
      down:SetWidth(2)
      down:SetPoint("BOTTOM", r, "BOTTOMLEFT", x, 0)
      up:Hide()
      down:Hide()
      r.rail[l] = { up = up, down = down }
    end
    r.text = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", r, "LEFT", 18, 0)
    r.text:SetHeight(MIN_ROW_H - 2)
    Font(r.text, -1)
    r.text:SetJustifyH("LEFT")
    r.num = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    r.num:SetPoint("RIGHT", r, "RIGHT", -2, 0)
    -- chain marks: a small shape in the chain's colour, left of the step number (up to three chains a step)
    r.chainMark = {}
    for k = 1, MAX_MARKS do
      local t = r:CreateTexture(nil, "OVERLAY")
      t:SetTexture("Interface\\AddOns\\pfQuest_xpGuide\\Media\\ChainCircle")
      t:SetWidth(8)
      t:SetHeight(8)
      t:SetPoint("RIGHT", r, "RIGHT", -26 - (k - 1) * 11, 0)
      t:Hide()
      r.chainMark[k] = t
    end
    r.num:SetJustifyH("RIGHT")
    Font(r.num, -2)
    r.last = 0
    r:SetScript("OnClick", function()
      if not this.step then return end
      if this.regain and arg1 ~= "RightButton" then
        G.hold = true
        ER.Steps.Retake(this.step.n)
        return
      end
      local now = GetTime()
      if arg1 == "RightButton" or now - (this.last or 0) <= 0.5 then
        this.last = 0
        StepMenu(this.step)
      else
        this.last = now
      end
    end)
    Tip(r, function(b)
      if not b.step then return nil end
      local lines = {}
      for _, l in ipairs((StepLines(b.step))) do table.insert(lines, Plain(l.text)) end
      for _, l in ipairs((StepHints(b.step))) do table.insert(lines, Plain(l.text)) end
      for _, m in ipairs(b.chains or {}) do
        local c = string.format("|cff%02x%02x%02x", math.floor(m.colour[1] * 255), math.floor(m.colour[2] * 255), math.floor(m.colour[3] * 255))
        table.insert(lines, c .. Plain(m.title) .. " chain|r" .. GREY .. " (" .. (SHAPE_WORDS[m.shape] or "") .. "), part " .. m.part .. " of " .. m.parts .. END)
      end
      if b.regain then
        local title = Plain(ER.Steps.QuestTitle(b.regain.id) or "this quest")
        if b.regain.kind == "abandoned" then
          return "Click to go back and pick it up again", "You abandoned " .. title .. ".",
            "The arrow then points at the quest giver. Its steps, and the rest of its chain, come back when you take it again."
        end
        local names = {}
        for _, id in ipairs(b.regain.ids or { b.regain.id }) do table.insert(names, Plain(ER.Steps.QuestTitle(id) or ("quest " .. id))) end
        title = table.concat(names, " and ")
        return "Click to go back and do it", "You skipped " .. title .. ".",
          "The guide goes back to this step, with what the skip left out, then carries on where you were."
      end
      local hint = "Tick its box to skip it. Right-click or double-click to go to it."
      local m = b.chains and b.chains[1]
      if m and m.part and m.part > 1 then hint = "Part of the chain that starts with " .. m.title .. ". " .. hint end
      return "Step " .. b.step.n, table.concat(lines, "\n"), hint
    end)
    r:Hide()
    G.rows[i] = r
  end

  -- The footer, under the list with a gap so no icon touches the list's border (pfUI draws borders a few pixels outside a
  -- frame). Left: the cog (Settings) and the arrow (pfQuest's, the guide's own, or none). Right: close, lock and the grip.
  local foot = CreateFrame("Frame", "pfQuest_xpGuideGuideFooter", f)
  G.foot = foot
  foot:SetHeight(FOOT_H)
  foot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  foot:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  Draggable(foot)
  local cog = IconButton(foot, "pfQuest_xpGuideGuideCog", "IconCog")
  cog:SetPoint("LEFT", foot, "LEFT", ICON_INSET, 0)
  cog:SetScript("OnClick", function() if ER.ShowSettings then ER.ShowSettings() end end)
  Tip(cog, function() return "Settings", "Open the settings: pick a guide, text size, helpers and more.", nil end)
  local arrow = IconButton(foot, "pfQuest_xpGuideGuideArrow", "IconArrow")
  arrow:SetPoint("LEFT", cog, "RIGHT", 4, 0)
  arrow:SetScript("OnClick", function()
    if ER.CycleArrow then ER.CycleArrow() end
    G.FootIcons()
  end)
  Tip(arrow, function()
    local now = ER.ArrowChoice and ER.ArrowChoice() or "own"
    local said = { pfquest = "pfQuest's arrow", own = "the guide's own arrow", off = "no arrow" }
    local nxt = { pfquest = "own", own = "off", off = "pfquest" }
    local n = nxt[now]
    if n == "pfquest" and not (ER.PfQuestArrowCan and ER.PfQuestArrowCan()) then n = "own" end
    return "Arrow", "Now: " .. said[now] .. ".", "Click for " .. said[n] .. "."
  end)
  G.arrowBtn = arrow
  -- how many abandoned or skipped steps you can still go back to; a click shows the first of them in the list
  local back = CreateFrame("Button", "pfQuest_xpGuideGuideBackCount", foot)
  back:SetHeight(ICON_BOX)
  back:SetWidth(60)
  back:SetPoint("LEFT", arrow, "RIGHT", 8, 0)
  back.text = back:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  back.text:SetPoint("LEFT", back, "LEFT", 0, 0)
  Font(back.text, -2)
  back:SetScript("OnClick", function()
    local idx = this.firstIdx
    if not idx then return end
    local shown = ListRows()
    local total = table.getn(G.all or {})
    local off = idx - 1
    if off > total - shown then off = total - shown end
    if off < 0 then off = 0 end
    G.offset = off
    if G.scroll then
      FauxScrollFrame_SetOffset(G.scroll, off)
      local bar = getglobal(G.scroll:GetName() .. "ScrollBar")
      if bar and bar.SetValue then bar:SetValue(off * RowH()) end
    end
    FillList()
  end)
  Tip(back, function()
    return "Steps to go back to", "Quests you abandoned or skipped that you can still do. They are the outlined steps in the list.",
      "Click to show the first of them. Click one there to go back to it."
  end)
  back:Hide()
  G.backCount = back
  local grip = IconButton(foot, "pfQuest_xpGuideGuideGrip", "IconGrip")
  grip:SetPoint("RIGHT", foot, "RIGHT", -ICON_INSET, 0)
  G.grip = grip
  local lock = IconButton(foot, "pfQuest_xpGuideGuideLock", "IconUnlocked")
  lock:SetPoint("RIGHT", grip, "LEFT", -4, 0)
  lock:SetScript("OnClick", function()
    if ER.db then ER.db.guideLocked = (not ER.db.guideLocked) or nil end
    G.FootIcons()
    Say((ER.db and ER.db.guideLocked) and "guide window locked: it no longer moves or resizes." or "guide window unlocked.")
  end)
  Tip(lock, function()
    if ER.db and ER.db.guideLocked then return "Locked", "The window does not move or resize.", "Click to unlock it." end
    return "Lock", "Click to keep the window where it is, at its size.", nil
  end)
  G.lockBtn = lock
  local close = IconButton(foot, "pfQuest_xpGuideGuideClose", "IconClose")
  close:SetPoint("RIGHT", lock, "LEFT", -4, 0)
  close:SetScript("OnClick", function() ER.ToggleTracker() end)
  Tip(close, function() return "Hide", "Hide the guide window. The guide keeps going.", "/xpg shows it again." end)
  G.FootIcons()
  grip:SetScript("OnMouseDown", function()
    if ER.db and ER.db.guideLocked then return end
    f:StartSizing("BOTTOMRIGHT")
  end)
  grip:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
    SavePlace()
    if G.Refresh then G.Refresh() end
  end)
  Tip(grip, function()
    if ER.db and ER.db.guideLocked then return "Resize", "The window is locked.", "Click the padlock to unlock it." end
    return "Resize", "Drag to make the window wider, or the list longer.", nil
  end)

  -- The step boxes, stacked on the list: the step you are on, then what you can do on the way.
  local stack = CreateFrame("Frame", "pfQuest_xpGuideGuideStack", f)
  G.stack = stack
  stack:SetPoint("BOTTOMLEFT", list, "TOPLEFT", 0, GAP)
  stack:SetPoint("BOTTOMRIGHT", list, "TOPRIGHT", 0, GAP)
  stack:SetHeight(40)
  G.now = MakeBox("pfQuest_xpGuideGuideNow", stack, true)
  G.now:SetPoint("TOPLEFT", stack, "TOPLEFT", 0, 0)
  G.now:SetPoint("TOPRIGHT", stack, "TOPRIGHT", 0, 0)
  Draggable(G.now)
  for i = 1, LINES do G.lines[i] = MakeLine(G.now, "pfQuest_xpGuideGuideLine" .. i) end
  MakeSkip(G.now, "pfQuest_xpGuideGuideSkip")
  MakeUnskip(G.now, "pfQuest_xpGuideGuideUnskip")
  G.sideBox = MakeBox("pfQuest_xpGuideGuideSide", stack)
  G.sideBox:SetPoint("TOPLEFT", G.now, "BOTTOMLEFT", 0, -GAP)
  G.sideBox:SetPoint("TOPRIGHT", G.now, "BOTTOMRIGHT", 0, -GAP)
  Draggable(G.sideBox)
  for i = 1, SIDE_LINES do G.side[i] = MakeLine(G.sideBox, "pfQuest_xpGuideGuideSideLine" .. i) end
end

------------------------------------------------------------------------------------------------------
-- Filling it
------------------------------------------------------------------------------------------------------

-- The step box's heading: the guide's name (on the Casual route, the zone and how far you are in it) and its group and
-- difficulty. No step number: the list shows where you are.
local function Heading()
  local info = ER.Steps.Info()
  if not info then return "", "" end
  local short, head, tail
  if ER.RouteShort then short, head, tail = ER.RouteShort() end
  local title
  if head then title = { GOLD .. Plain(head), (tail or "") .. END } else title = GOLD .. Plain(info.title or info.name) .. END end
  local detail
  if info.fast and ER.XPRate then
    -- the rate first: it is the part that must stay when a narrow window cuts the line short
    detail = GREY .. ER.XPRate() .. "x exp, " .. ER.GroupLabel(info.group) .. ", on " .. ER.MODES[ER.Mode()].label .. END
  else
    detail = GREY .. ER.GroupLabel(info.group) .. ", on " .. ER.MODES[ER.Mode()].label .. END
  end
  return title, detail
end

G.Refresh = function()
  if not G.frame or not G.frame:IsShown() then return end
  local Steps = ER.Steps
  if not Steps.Running() then
    G.frame:Hide()
    return
  end
  local width = G.frame:GetWidth()
  local step = Steps.Current()
  local skip = G.now.skip
  if step then
    local finished = not Steps.ByHand(step) and Steps.Finished and Steps.Finished(step)
    FitButton(skip, Steps.ByHand(step) and "Mark done" or (finished and "Finished" or "Skip step"))
    if finished then
      skip.text:SetText(GREY .. "Finished" .. END)
      skip:Disable()
    else
      skip:Enable()
    end
    skip:Show()
  else
    skip:Hide()
  end
  local unskip = G.now.unskip
  if Steps.SkippedBehind and Steps.SkippedBehind() then
    FitButton(unskip, "Unskip previous")
    unskip:Show()
  else
    unskip:Hide()
  end
  local title, detail = Heading()
  local h = FillBox(G.now, G.lines, NowLines(step), width, title, detail)
  local sideLines = {}
  for _, s in ipairs((Steps.Side())) do
    for _, l in ipairs((StepLines(s, 2))) do
      l.side = true
      if table.getn(sideLines) < SIDE_LINES then table.insert(sideLines, l) end
    end
  end
  if table.getn(sideLines) > 0 then
    h = h + GAP + FillBox(G.sideBox, G.side, sideLines, width, GREY .. "On the way" .. END)
    G.sideBox:Show()
  else
    G.sideBox:Hide()
  end
  G.stack:SetHeight(h)
  FillList()
end

-- The text size changed (Settings, /xpg font): the rows and boxes grow or shrink to it.
ER.FontsChanged = function()
  if not G.frame then return end
  G.followPos = nil
  G.Refresh()
end

-- The lock or arrow changed somewhere else (Settings, /xpg): the footer icons follow.
ER.GuideFooterChanged = function() if G.FootIcons then G.FootIcons() end end

ER.StepsChanged = function()
  G.Refresh()
  if ER.GuideMenuRefresh then ER.GuideMenuRefresh() end
end

------------------------------------------------------------------------------------------------------
-- Showing and hiding
------------------------------------------------------------------------------------------------------

function ER.ShowTracker()
  if not G.frame then Build() end
  G.frame:Show()
  if G.FootIcons then G.FootIcons() end
  G.Refresh()
  if ER.PlaceTips then ER.PlaceTips() end
end

function ER.TrackerShown()
  return G.frame and G.frame:IsShown() or false
end

function ER.ToggleTracker()
  if not G.frame then Build() end
  if G.frame:IsShown() then
    G.frame:Hide()
    if ER.PlaceTips then ER.PlaceTips() end
    Say("guide window hidden; the guide keeps going. " .. GOLD .. "/xpg" .. END .. " shows it again.")
  else
    ER.ShowTracker()
  end
end

-- The window, for the guide menu to sit next to (nil when it is not up).
function ER.GuideFrame()
  if G.frame and G.frame:IsShown() then return G.frame end
  return nil
end

-- The window's bottom edge, for the tips box to sit under (nil when it is not up).
function ER.TrackerBottom()
  if G.frame and G.frame:IsShown() then return G.frame end
  return nil
end

ER.Loaded("GuideWindow.lua")
