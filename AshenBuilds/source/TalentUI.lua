AshenBuilds = AshenBuilds or {}
local AB = AshenBuilds

-- Talent window, styled after the game's own talent frame:
--  * each tree shows its own background art from the game, darkened to sit in the ember theme;
--  * icons are grey when they can't be learned, full colour with a green rank when they
--    can (or are part-spent), and gold when maxed;
--  * prerequisite arrows join a talent to the one it unlocks;
--  * ranks sit in a small badge, icons glow on hover and clicks make a sound.

local ICON, COL_STEP, ROW_STEP, LEFT, TOP = 44, 70, 70, 27, -58
local PANEL_W, PANEL_H = 310, 556

-- The game's talent background art for every class, per tree.
local TREE_ART = {
  WARRIOR = {"WarriorArms", "WarriorFury", "WarriorProtection"},
  PALADIN = {"PaladinHoly", "PaladinProtection", "PaladinCombat"},
  HUNTER = {"HunterBeastMastery", "HunterMarksmanship", "HunterSurvival"},
  ROGUE = {"RogueAssassination", "RogueCombat", "RogueSubtlety"},
  PRIEST = {"PriestDiscipline", "PriestHoly", "PriestShadow"},
  SHAMAN = {"ShamanElementalCombat", "ShamanEnhancement", "ShamanRestoration"},
  MAGE = {"MageArcane", "MageFire", "MageFrost"},
  WARLOCK = {"WarlockCurses", "WarlockSummoning", "WarlockDestruction"},
  DRUID = {"DruidBalance", "DruidFeralCombat", "DruidRestoration"},
}
-- The art comes in four pieces that together make a 320x384 picture.
local ART_PIECES = {{"TopLeft", 0, 0, 256, 256}, {"TopRight", 256, 0, 64, 256}, {"BottomLeft", 0, 256, 256, 128}, {"BottomRight", 256, 256, 64, 128}}
-- The bottom pieces are 128 tall but only the top ~76 rows are painted, so the
-- picture itself is 320x332; sizing to 384 left a black band at the bottom.
local ART_W, ART_H = 320, 332
local MAX_STRETCH = 1.15  -- allow a little vertical stretch instead of cropping the sides away

local GOLD, GREEN, GREY = {1, 0.82, 0}, {0.25, 1, 0.25}, {0.5, 0.5, 0.5}

local function backdrop(frame) AB:WindowBackdrop(frame) end

local function button(parent, text, width, height)
  local result = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  result:SetWidth(width)
  result:SetHeight(height)
  result:SetText(text)
  AB:SkinButton(result, "ember")
  return result
end

local function TalentPos(row, col) return LEFT + (col - 1) * COL_STEP, TOP - (row - 1) * ROW_STEP end

-- Covers the panel with the tree art, cropping instead of stretching (like the ember background).
local function PlaceArt(panel, name)
  local w, h = PANEL_W - 8, PANEL_H - 8
  -- Always fill the full height; crop the sides only as far as needed after a small stretch.
  local scaleY = h / ART_H
  local scaleX = math.max(w / ART_W, scaleY / MAX_STRETCH)
  local sw, sh = w / scaleX, ART_H
  local sx, sy = (ART_W - sw) * 0.45, 0
  local i, p, tex, x0, x1, y0, y1
  for i = 1, 4 do
    p = ART_PIECES[i]; tex = panel.art[i]
    x0 = math.max(p[2], sx); x1 = math.min(p[2] + p[4], sx + sw)
    y0 = math.max(p[3], sy); y1 = math.min(p[3] + p[5], sy + sh)
    if x1 - x0 > 0.01 and y1 - y0 > 0.01 then
      tex:SetTexture("Interface\\TalentFrame\\" .. name .. "-" .. p[1])
      tex:ClearAllPoints()
      tex:SetPoint("TOPLEFT", panel, "TOPLEFT", 4 + (x0 - sx) * scaleX, -4 - (y0 - sy) * scaleY)
      tex:SetWidth((x1 - x0) * scaleX); tex:SetHeight((y1 - y0) * scaleY)
      tex:SetTexCoord((x0 - p[2]) / p[4], (x1 - p[2]) / p[4], (y0 - p[3]) / p[5], (y1 - p[3]) / p[5])
      tex:Show()
    else
      tex:Hide()
    end
  end
end

local function createTreePanel(parent, treeIndex)
  local panel = CreateFrame("Frame", nil, parent)
  panel:SetWidth(PANEL_W)
  panel:SetHeight(PANEL_H)
  -- Three 310-wide trees with 26px gaps, centred in the 1060-wide window.
  panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 39 + ((treeIndex - 1) * 336), -92)
  panel:SetFrameLevel(parent:GetFrameLevel() + 1)
  AB:StylePanel(panel, "panel")
  -- The backdrop fill draws in the same BACKGROUND layer as the tree art and can
  -- land on top of it (the trees showed plain black), so the panel keeps only its
  -- border and the art, darkened by the tint below, is the fill.
  panel:SetBackdropColor(0, 0, 0, 0)

  panel.art = {}
  local i
  for i = 1, 4 do panel.art[i] = panel:CreateTexture(nil, "BACKGROUND") end
  -- Darken the art so icons and text stay readable, heavier at the top and bottom.
  panel.tint = panel:CreateTexture(nil, "BORDER"); panel.tint:SetTexture(0, 0, 0, 0.42)
  panel.tint:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4); panel.tint:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)
  panel.fadeTop = panel:CreateTexture(nil, "BORDER"); panel.fadeTop:SetTexture(1, 1, 1, 1)
  panel.fadeTop:SetGradientAlpha("VERTICAL", 0, 0, 0, 0, 0.03, 0.02, 0.015, 0.95)
  panel.fadeTop:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4); panel.fadeTop:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4); panel.fadeTop:SetHeight(70)
  panel.fadeBottom = panel:CreateTexture(nil, "BORDER"); panel.fadeBottom:SetTexture(1, 1, 1, 1)
  panel.fadeBottom:SetGradientAlpha("VERTICAL", 0.03, 0.02, 0.015, 0.9, 0, 0, 0, 0)
  panel.fadeBottom:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 4, 4); panel.fadeBottom:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4); panel.fadeBottom:SetHeight(60)

  local e = AB.THEME.ember
  panel.rule = panel:CreateTexture(nil, "ARTWORK"); panel.rule:SetTexture(e[1], e[2], e[3], 0.6)
  panel.rule:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -38); panel.rule:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -38); panel.rule:SetHeight(1)

  panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -13)
  panel.title:SetText("Tree " .. treeIndex)
  panel.points = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  panel.points:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -14, -13)
  panel.points:SetText("0")

  panel.lines = {}
  return panel
end

local function createTalentButton(panel)
  local b = CreateFrame("Button", nil, panel)
  b:SetWidth(ICON + 6); b:SetHeight(ICON + 6)
  b:SetFrameLevel(panel:GetFrameLevel() + 4)
  b:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 12, insets = {left = 3, right = 3, top = 3, bottom = 3}})
  b:SetBackdropColor(0, 0, 0, 0.9)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetWidth(ICON - 2); b.icon:SetHeight(ICON - 2); b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
  local hl = b:GetHighlightTexture(); if hl then hl:SetBlendMode("ADD"); hl:ClearAllPoints(); hl:SetPoint("TOPLEFT", b.icon, "TOPLEFT", 0, 0); hl:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", 0, 0) end
  -- Rank badge under the bottom-right corner.
  b.badge = CreateFrame("Frame", nil, b); b.badge:SetWidth(30); b.badge:SetHeight(15)
  b.badge:SetPoint("CENTER", b, "BOTTOMRIGHT", -2, 2); b.badge:SetFrameLevel(b:GetFrameLevel() + 2)
  b.badge:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", tile = true, tileSize = 8, edgeSize = 1, insets = {left = 1, right = 1, top = 1, bottom = 1}})
  b.badge:SetBackdropColor(0.02, 0.02, 0.02, 0.95)
  b.rank = b.badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.rank:SetPoint("CENTER", b.badge, "CENTER", 0, 0)

  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function()
    local before = AB:GetTalentRank(AB.current, this.treeIndex, this.talentIndex)
    if arg1 == "RightButton" then AB:RemoveTalentPoint(this.treeIndex, this.talentIndex) else AB:AddTalentPoint(this.treeIndex, this.talentIndex) end
    local after = AB:GetTalentRank(AB.current, this.treeIndex, this.talentIndex)
    if after > before then PlaySound("igMainMenuOptionCheckBoxOn") elseif after < before then PlaySound("igMainMenuOptionCheckBoxOff") end
    AB:ShowTalentTooltip(this)
  end)
  b:SetScript("OnEnter", function() AB:ShowTalentTooltip(this) end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

function AB:CreateTalentUI()
  if self.talentFrame then return end

  local open = button(self.frame, "TALENTS", 90, 25)
  open:SetPoint("RIGHT", self.communityButton, "LEFT", -8, 0)
  open:SetScript("OnClick", function()
    AB.talentFrame:Show()
    AB:RefreshTalentUI()
  end)
  self.talentOpenButton = open

  local frame = CreateFrame("Frame", "AshenBuildsTalentFrame", UIParent)
  frame:SetWidth(1060)
  frame:SetHeight(696)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  backdrop(frame)
  self:SetupWindow(frame, {fit = true})
  frame:Hide()
  self.talentFrame = frame
  self:ApplyEmberBackground(frame, 11, 0.5, 0.5, 0.45)
  self:AddEmberHeader(frame, 72, 11)
  self:AddEmberFloor(frame, 36, 11)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", frame, "TOP", 0, -18)
  title:SetText("ASHEN TALENTS")
  title:SetTextColor(1, 0.45, 0.16)

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton"); frame.closeButton = close
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
  self:AddChrome(frame, title); self:AddChrome(frame, close)

  self.talentSummary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  self.talentSummary:SetPoint("TOP", title, "BOTTOM", 0, -8)

  local reset = button(frame, "Reset Talents", 120, 22)
  reset:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -45, -48)
  reset:SetScript("OnClick", function() AB:ResetTalents(); PlaySound("igMainMenuOptionCheckBoxOff") end)

  local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOM", frame, "BOTTOM", 0, 20)
  hint:SetText("Left-click to learn a rank  -  Right-click to remove one")
  hint:SetTextColor(self.THEME.muted[1], self.THEME.muted[2], self.THEME.muted[3])

  self.talentTreePanels = {}
  self.talentTreeTitles = {}
  self.talentButtons = {}

  local tree, row, col, b, x, y
  for tree = 1, 3 do
    local panel = createTreePanel(frame, tree)
    self.talentTreePanels[tree] = panel
    self.talentTreeTitles[tree] = panel.title
    self.talentButtons[tree] = {}
    for row = 1, 7 do
      for col = 1, 4 do
        b = createTalentButton(panel)
        x, y = TalentPos(row, col)
        b:SetPoint("TOPLEFT", panel, "TOPLEFT", x - 3, y + 3)
        table.insert(self.talentButtons[tree], b)
      end
    end
  end
end

-- Line pool per tree panel.
local function Line(panel, n)
  local t = panel.lines[n]
  if not t then t = panel:CreateTexture(nil, "ARTWORK"); panel.lines[n] = t end
  t:SetTexture(1, 1, 1, 1); t:ClearAllPoints(); t:Show()
  return t
end
local function Arrow(panel, n)
  panel.arrows = panel.arrows or {}
  local t = panel.arrows[n]
  if not t then t = panel:CreateTexture(nil, "ARTWORK"); t:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up"); t:SetWidth(18); t:SetHeight(18); panel.arrows[n] = t end
  t:ClearAllPoints(); t:Show()
  return t
end

-- Draws a prerequisite arrow from talent a to talent b (both {row, col}).
local function DrawArrow(panel, state, a, b, lit)
  local c = lit and GOLD or GREY
  local ax, ay = TalentPos(a[1], a[2]); local bx, by = TalentPos(b[1], b[2])
  local acx, bcx = ax + ICON / 2, bx + ICON / 2
  local t
  if a[1] == b[1] then
    -- Same row: a short horizontal line between the icons.
    local x0, x1 = math.min(ax, bx) + ICON + 3, math.max(ax, bx) - 3
    state.n = state.n + 1; t = Line(panel, state.n)
    t:SetPoint("TOPLEFT", panel, "TOPLEFT", x0, ay - ICON / 2 + 2); t:SetWidth(x1 - x0); t:SetHeight(4)
    t:SetVertexColor(c[1], c[2], c[3], 0.9)
    return
  end
  local startY = ay - ICON - 3
  if a[2] ~= b[2] then
    -- Different column: across at the prerequisite's middle, then down.
    startY = ay - ICON / 2 + 2
    local x0 = bcx > acx and (ax + ICON + 3) or (bcx - 2)
    local x1 = bcx > acx and (bcx + 2) or (ax - 3)
    state.n = state.n + 1; t = Line(panel, state.n)
    t:SetPoint("TOPLEFT", panel, "TOPLEFT", x0, startY); t:SetWidth(x1 - x0); t:SetHeight(4)
    t:SetVertexColor(c[1], c[2], c[3], 0.9)
  end
  state.n = state.n + 1; t = Line(panel, state.n)
  t:SetPoint("TOPLEFT", panel, "TOPLEFT", bcx - 2, startY); t:SetWidth(4); t:SetHeight(startY - (by + 10))
  t:SetVertexColor(c[1], c[2], c[3], 0.9)
  state.a = state.a + 1; t = Arrow(panel, state.a)
  t:SetPoint("CENTER", panel, "TOPLEFT", bcx, by + 8)
  t:SetVertexColor(c[1], c[2], c[3], 1)
end

local function SetBorder(b, c) b:SetBackdropBorderColor(c[1], c[2], c[3], 1); b.badge:SetBackdropBorderColor(c[1], c[2], c[3], 0.9); b.rank:SetTextColor(c[1], c[2], c[3]) end

function AB:ShowTalentTooltip(btn)
  local data, token = self:GetTalentData(self.current.class)
  local talent = data and btn.treeIndex and data[btn.treeIndex] and data[btn.treeIndex][btn.talentIndex]
  if not talent then return end
  local names = self.TREE_NAMES[token] or {"Tree 1", "Tree 2", "Tree 3"}

  local rank = self:GetTalentRank(self.current, btn.treeIndex, btn.talentIndex)
  local max = table.getn(talent.ranks or {})
  GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
  GameTooltip:ClearLines()
  GameTooltip:AddLine(talent.name, 1, 1, 1)
  GameTooltip:AddLine("Rank " .. rank .. "/" .. max, rank >= max and GOLD[1] or GREEN[1], rank >= max and GOLD[2] or GREEN[2], rank >= max and GOLD[3] or GREEN[3])

  -- What's still needed, in red, like the game's own talent tooltips.
  local needed = ((tonumber(talent.row) or 1) - 1) * 5
  local have = self:GetTalentPointsInTree(self.current, btn.treeIndex)
  if rank == 0 and have < needed then GameTooltip:AddLine("Requires " .. needed .. " points in " .. (names[btn.treeIndex] or "this tree") .. " (" .. have .. " spent)", 1, 0.2, 0.2) end
  if talent.req then
    local req = data[btn.treeIndex][tonumber(talent.req)]
    local reqMax = req and table.getn(req.ranks or {}) or 1
    if req and self:GetTalentRank(self.current, btn.treeIndex, tonumber(talent.req)) < reqMax then
      GameTooltip:AddLine("Requires " .. reqMax .. " point" .. (reqMax == 1 and "" or "s") .. " in " .. req.name, 1, 0.2, 0.2)
    end
  end
  GameTooltip:AddLine(talent.desc or "No description available.", 1, 0.82, 0, true)

  local mods = self:GetTalentModifiers(self.current)
  local i, source
  for i = 1, table.getn(mods.sources or {}) do
    source = mods.sources[i]
    if source.name == talent.name then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Calculated Effects", 0.3, 0.8, 1)
      GameTooltip:AddLine(source.effects, 0.2, 1, 0.2, true)
      break
    end
  end

  local ok = self:CanAddTalent(self.current, btn.treeIndex, btn.talentIndex)
  GameTooltip:AddLine(" ")
  if ok then GameTooltip:AddLine("Click to learn", GREEN[1], GREEN[2], GREEN[3])
  elseif rank < max and self:GetTalentPointsSpent(self.current) >= self:GetTalentBudget(self.current) then GameTooltip:AddLine("No talent points left", 1, 0.2, 0.2) end
  if rank > 0 then GameTooltip:AddLine("Right-click to remove a rank", 0.6, 0.6, 0.6) end
  GameTooltip:Show()
end

-- Tree art: the game's own names when the build is the player's class, else the known defaults.
function AB:TalentTreeArt(token, tree)
  local _, playerToken = UnitClass("player")
  if playerToken == token and GetTalentTabInfo then
    local _, _, _, background = GetTalentTabInfo(tree)
    if background and background ~= "" then return background end
  end
  return TREE_ART[token] and TREE_ART[token][tree]
end

function AB:RefreshTalentUI()
  if not self.talentFrame then return end

  local data, token = self:GetTalentData(self.current.class)
  local names = self.TREE_NAMES[token] or {"Tree 1", "Tree 2", "Tree 3"}
  local spent, budget = self:GetTalentPointsSpent(self.current), self:GetTalentBudget(self.current)
  local split = self:GetTalentPointsInTree(self.current, 1) .. " / " .. self:GetTalentPointsInTree(self.current, 2) .. " / " .. self:GetTalentPointsInTree(self.current, 3)
  local left = budget - spent
  self.talentSummary:SetText(self.current.class .. "  |cff8d96a8-|r  " .. split .. "  |cff8d96a8-|r  " .. (left > 0 and ("|cff40ff40" .. left .. " point" .. (left == 1 and "" or "s") .. " left|r") or ("|cffffd100" .. spent .. " / " .. budget .. " points|r")))

  local tree, i, b, talent, slot, rank, max, points, panel, state, ok, req, reqMax
  for tree = 1, 3 do
    panel = self.talentTreePanels[tree]
    points = self:GetTalentPointsInTree(self.current, tree)
    panel.title:SetText(names[tree] or ("Tree " .. tree))
    panel.points:SetText(points)
    if points > 0 then panel.points:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) else panel.points:SetTextColor(GREY[1], GREY[2], GREY[3]) end
    local art = self:TalentTreeArt(token, tree)
    if art and panel.artName ~= art then PlaceArt(panel, art); panel.artName = art end

    for i = 1, table.getn(self.talentButtons[tree]) do self.talentButtons[tree][i]:Hide() end
    for i = 1, table.getn(panel.lines) do panel.lines[i]:Hide() end
    for i = 1, table.getn(panel.arrows or {}) do panel.arrows[i]:Hide() end
    state = {n = 0, a = 0}

    for i = 1, table.getn(data and data[tree] or {}) do
      talent = data[tree][i]
      slot = ((tonumber(talent.row) or 1) - 1) * 4 + (tonumber(talent.column) or 1)
      b = self.talentButtons[tree][slot]
      if b then
        b.treeIndex = tree; b.talentIndex = i
        b.icon:SetTexture(talent.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        rank = self:GetTalentRank(self.current, tree, i)
        max = table.getn(talent.ranks or {})
        ok = self:CanAddTalent(self.current, tree, i)
        b.rank:SetText(rank .. "/" .. max)
        if rank >= max then
          SetBorder(b, GOLD); b.icon:SetVertexColor(1, 1, 1); if b.icon.SetDesaturated then b.icon:SetDesaturated(nil) end; b.badge:Show()
        elseif rank > 0 or ok then
          SetBorder(b, GREEN); b.icon:SetVertexColor(1, 1, 1); if b.icon.SetDesaturated then b.icon:SetDesaturated(nil) end; b.badge:Show()
        else
          -- Locked: grey icon; the rank badge only shows once the talent is reachable.
          SetBorder(b, {0.35, 0.33, 0.3}); if b.icon.SetDesaturated then b.icon:SetDesaturated(1); b.icon:SetVertexColor(0.65, 0.65, 0.65) else b.icon:SetVertexColor(0.35, 0.35, 0.35) end
          b.badge:Hide()
        end
        b:Show()

        if talent.req then
          req = data[tree][tonumber(talent.req)]
          if req then
            reqMax = table.getn(req.ranks or {})
            DrawArrow(panel, state, {tonumber(req.row) or 1, tonumber(req.column) or 1}, {tonumber(talent.row) or 1, tonumber(talent.column) or 1},
              self:GetTalentRank(self.current, tree, tonumber(talent.req)) >= reqMax)
          end
        end
      end
    end
  end
end

local oldCreate = AB.CreateUI
function AB:CreateUI()
  oldCreate(self)
  self:CreateTalentUI()
end

local oldRefresh = AB.RefreshUI
function AB:RefreshUI()
  oldRefresh(self)
  if self.talentFrame and self.talentFrame:IsShown() then
    self:RefreshTalentUI()
  end
end
