-- pfQuest SmartArrow
-- Copyright (C) 2026 pfQuest SmartArrow contributors
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or (at your option)
-- any later version. It is distributed WITHOUT ANY WARRANTY; see LICENSE.md.

-- pfQuest SmartArrow: drives pfQuest's own arrow
--
-- No second arrow: this takes over the OnUpdate of pfQuest's arrow frame
-- (pfQuest.route.arrow) and renders the planned route into the widgets pfQuest
-- already built -- the arrow model, the objective icon, the title, the
-- description (the current travel action, or pfQuest's objective text on
-- the last leg) and the distance line. So pfQuest's arrow toggle, its saved position (Shift-drag), its scale
-- (Shift-wheel / config slider) and its font all keep working unchanged.
-- Underneath, a short notes area shows only what pfQuest cannot: the
-- objective is in a cave, at the top of a tower, on another level.
-- Detach() puts pfQuest's original handler back.

local floor, abs, pi, atan2, sqrt = math.floor, math.abs, math.pi, math.atan2, math.sqrt
local getn = table.getn

local MAXNOTES = 3
local CELLS, COLS = 108, 9 -- pfQuest's arrow sheet: 108 headings, 9 per row

local function modulo(val, by)
  return val - floor(val / by) * by
end

local function Gradient(perc)
  -- 1 = straight ahead (green), 0.5 = side (yellow), 0 = behind (red)
  local r = perc < 0.5 and 1 or (1 - perc) * 2
  local g = perc > 0.5 and 1 or perc * 2
  return r, g, 0
end

function pfQuestSmartArrow_FormatTime(secs)
  if not secs or secs >= 1e29 then
    return "?"
  end
  secs = floor(secs + 0.5)
  if secs < 60 then
    return secs .. "s"
  elseif secs < 3600 then
    return floor(secs / 60) .. "m " .. modulo(secs, 60) .. "s"
  end
  return floor(secs / 3600) .. "h " .. floor(modulo(secs, 3600) / 60) .. "m"
end

function pfQuestSmartArrow_FormatYards(yards)
  if yards >= 1000 then
    return string.format("%.1fk yd", yards / 1000)
  end
  return floor(yards) .. " yd"
end

local UI = {}
pfQuestSmartArrowUI = UI

local function Font()
  return (pfUI and pfUI.font_default) or STANDARD_TEXT_FONT
end

local function FontSize(delta)
  local size = pfUI_config and pfUI_config.global and tonumber(pfUI_config.global.font_size) or 12
  return size + (delta or 0)
end

-- the notes area: a few lines under pfQuest's distance text, built once.
-- Only special instructions go here (caves, towers, levels, your own pins);
-- the arrow, title, objective text and distance are pfQuest's own widgets.
local function BuildNotes(arrow)
  if arrow.pfqsaNotes then
    return arrow.pfqsaNotes
  end
  local holder = CreateFrame("Frame", nil, arrow.content or arrow)
  holder:SetWidth(300)
  holder:SetHeight(MAXNOTES * 13)
  holder:SetPoint("TOP", arrow.distance, "BOTTOM", 0, -4)
  holder.lines = {}
  for i = 1, MAXNOTES do
    local fs = holder:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    fs:SetFont(Font(), FontSize(-1), "OUTLINE")
    fs:SetJustifyH("CENTER")
    fs:SetWidth(300)
    fs:SetTextColor(1, 0.82, 0.3)
    if i == 1 then
      fs:SetPoint("TOP", holder, "TOP", 0, 0)
    else
      fs:SetPoint("TOP", holder.lines[i - 1], "BOTTOM", 0, -1)
    end
    holder.lines[i] = fs
  end
  arrow.pfqsaNotes = holder
  return holder
end

local lastnotes
local function DrawNotes(holder, view)
  local lines = holder.lines
  local notes = pfQuestSmartArrow_config.notes == "1" and view.notes or nil
  local sig = ""
  if notes then
    for i = 1, getn(notes) do sig = sig .. notes[i] .. "\n" end
  end
  if sig == lastnotes then
    return
  end
  lastnotes = sig
  for i = 1, MAXNOTES do
    lines[i]:SetText(notes and notes[i] or "")
  end
end

local function Render()
  local arrow = this
  local view = pfQuestSmartArrow.view
  if not view then
    return
  end

  arrow.title:SetText(view.title or "")
  arrow.description:SetText(view.action or "")

  local facing = pfQuestSmartArrowCompat.Facing()
  local point, player = view.point, view.player
  if facing and point and player and not view.flying then
    local dn, dw = point.n - player.n, point.w - player.w
    local angle = atan2(dw, dn) - facing
    local cell = modulo(floor(angle / (pi * 2) * CELLS + 0.5), CELLS)
    local col, row = modulo(cell, COLS), floor(cell / COLS)
    arrow.model:SetTexCoord(col * 56 / 512, (col + 1) * 56 / 512, row * 42 / 512, (row + 1) * 42 / 512)

    local perc = abs((pi - abs(modulo(angle + pi, 2 * pi) - pi)) / pi)
    local r, g, b = Gradient(perc)

    -- fade into the objective icon once practically on top of the target,
    -- the same way pfQuest's own arrow does
    local yards = sqrt(dn * dn + dw * dw)
    local alpha, iconalpha = 1, 0
    if view.final then
      alpha = (view.finaldist or yards) / (view.area or 50)
      if alpha > 1 then alpha = 1 end
      if alpha < 0.5 then alpha = 0.5 end
      iconalpha = (1 - alpha) * 2
      if iconalpha > 1 then iconalpha = 1 end
    end

    arrow.model:SetVertexColor(r + iconalpha, g + iconalpha, b + iconalpha)
    arrow.model:SetAlpha(alpha)
    arrow.model:Show()

    if view.icon then
      arrow.texture:SetTexture(view.icon)
      local c = view.iconcolor
      if c then
        arrow.texture:SetVertexColor(c[1], c[2], c[3], 1)
      else
        arrow.texture:SetVertexColor(1, 1, 1, 1)
      end
    end
    arrow.texture:SetAlpha(view.icon and iconalpha or 0)

    -- distance left along the planned path, not as the crow flies
    local info = "|cffaaaaaa" .. pfQuestSmartArrow_FormatYards(view.yards or yards)
    if view.total then
      info = info .. "  |cff888888total ~" .. pfQuestSmartArrow_FormatTime(view.total)
    end
    arrow.distance:SetText(info)
    arrow.distance.number = nil -- pfQuest's own change cache, if it comes back
  else
    arrow.model:SetAlpha(0)
    arrow.texture:SetAlpha(0)
    arrow.distance:SetText(view.flying and "|cff888888enjoy the flight|r" or "")
  end

  DrawNotes(BuildNotes(arrow), view)
end

-- pfQuest's arrow, or nil when this pfQuest has none we can drive
function UI:Frame()
  local a = pfQuest and pfQuest.route and pfQuest.route.arrow
  if a and a.model and a.texture and a.title and a.description and a.distance then
    return a
  end
  return nil
end

function UI:Attach()
  local arrow = self:Frame()
  if not arrow or self.attached then
    return arrow and true or nil
  end
  self.original = arrow:GetScript("OnUpdate")
  arrow:SetScript("OnUpdate", Render)

  -- right-click toggles the notes; pfQuest uses left for dragging
  if not self.mousehooked then
    self.mousehooked = true
    local orig = arrow:GetScript("OnMouseUp")
    arrow:SetScript("OnMouseUp", function()
      if orig then orig() end
      if arg1 == "RightButton" and UI.attached then
        pfQuestSmartArrow:ToggleNotes()
      end
    end)
  end

  BuildNotes(arrow):Show()
  lastnotes = nil
  self.attached = true
  return true
end

function UI:Detach()
  local arrow = self:Frame()
  if not arrow or not self.attached then
    return
  end
  arrow:SetScript("OnUpdate", self.original)
  if arrow.pfqsaNotes then
    arrow.pfqsaNotes:Hide()
  end
  -- let pfQuest's handler repaint its title/icon on its next target check
  arrow.distance.number = nil
  arrow.model:SetAlpha(1)
  self.attached = nil
end

function UI:SetShown(show)
  local arrow = self:Frame()
  if not arrow then
    return
  end
  if show and not arrow:IsShown() then
    arrow:Show()
  elseif not show and arrow:IsShown() then
    arrow:Hide()
  end
end
