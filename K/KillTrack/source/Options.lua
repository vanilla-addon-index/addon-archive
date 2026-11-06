--[[
    * Copyright (c) 2011-2020 by Adam Hellberg.
    *
    * This file is part of KillTrack.
    *
    * KillTrack is free software: you can redistribute it and/or modify
    * it under the terms of the GNU General Public License as published by
    * the Free Software Foundation, either version 3 of the License, or
    * (at your option) any later version.
    *
    * KillTrack is distributed in the hope that it will be useful,
    * but WITHOUT ANY WARRANTY; without even the implied warranty of
    * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    * GNU General Public License for more details.
    *
    * You should have received a copy of the GNU General Public License
    * along with KillTrack. If not, see <http://www.gnu.org/licenses/>.
--]]

---@class KillTrack
KT = KT or {}

local KTT = KT.Tools

-----@class KillTrackOptions
local Opt = {
  Panel = CreateFrame( "Frame" )
}

KT.Options = Opt

local panel = Opt.Panel

---@diagnostic disable-next-line: inject-field
panel.name = "KillTrack"
panel:Hide()

local category = {} --Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Opt.Category = category

-- Dirty hack to give a name to option checkboxes
local checkCounter = 0

---@param label string
---@param description string
---@param onclick function
---@return CheckButton
local function checkbox( label, description, onclick )
  local check = CreateFrame( "CheckButton", "KillTrackOptCheck" .. checkCounter, panel, "UICheckButtonTemplate" )
  check:SetScript( "OnClick", function()
    local checked = this:GetChecked()
    --    PlaySound( checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF )
    onclick( this, checked and true or false )
  end )
  ---@diagnostic disable-next-line: inject-field
  check.label = _G[ check:GetName() .. "Text" ]
  check.label:SetText( label )
  ---@diagnostic disable-next-line: inject-field
  check.tooltipText = label
  ---@diagnostic disable-next-line: inject-field
  check.tooltipRequirement = description
  checkCounter = checkCounter + 1
  return check
end

---@param text string
---@param tooltip string
---@param onclick function
---@return Button
local function button( text, tooltip, onclick )
  local btn = CreateFrame( "Button", nil, panel, "UIPanelButtonTemplate" )
  btn:SetText( text )
  ---@diagnostic disable-next-line: inject-field
  btn.tooltipText = tooltip
  btn:SetScript( "OnClick", function( self ) onclick( self ) end )
  btn:SetHeight( 24 )
  return btn
end

function Opt:CreateFrame()
  local frame = CreateFrame( "Frame", nil, UIParent )

  frame:SetToplevel( true )
  frame:EnableMouse( true )
  frame:SetMovable( true )
  frame:SetPoint( "Center", UIParent, "Center", 0, 0 )
  frame:SetWidth( 450 )
  frame:SetHeight( 420 )
  frame:SetBackdrop( {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    edgeSize = 16,
    tileSize = 32,
    insets = {
      left = 2.5,
      right = 2.5,
      top = 2.5,
      bottom = 2.5
    }
  } )

  frame:SetScript( "OnMouseDown", function() frame:StartMoving() end )
  frame:SetScript( "OnMouseUp", function() frame:StopMovingOrSizing() end )

  ---@diagnostic disable-next-line: inject-field
  frame.closeButton = CreateFrame( "Button", nil, frame, "UIPanelCloseButton" )
  frame.closeButton:SetPoint( "TopRight", frame, "TopRight", -1, -1 )
  frame.closeButton:SetScript( "OnClick", function() Opt:Hide() end )

  self.Frame = frame

  panel:SetParent( frame )
  panel:SetPoint( "TopLeft", frame, "TopLeft", 5, -5 )
  panel:SetPoint( "BottomRight", frame, "BottomRight", 5, 5 )

  local title = panel:CreateFontString( nil, "ARTWORK", "GameFontNormalLarge" )
  title:SetPoint( "TopLeft", panel, "TopLeft", 16, -16 )
  title:SetText( "KillTrack" )

  local printKills = checkbox( "Print kill updates to chat",
    "With this enabled, every kill you make is going to be announced locally in the chatbox",
    function( _, checked ) KT.Global.PRINTKILLS = checked end )
  printKills:SetPoint( "TopLeft", title, "BottomLeft", -2, -16 )

  local tooltipControl = checkbox( "Show mob data in tooltip",
    "With this enabled, KillTrack will print data about mobs in the tooltip",
    function( _, checked ) KT.Global.TOOLTIP = checked end )
  tooltipControl:SetPoint( "Left", printKills, "Right", 180, 0 )

  local printNew = checkbox( "Print new mob entries to chat",
    "With this enabled, new mobs added to the database will be announced locally in the chat",
    function( _, checked ) KT.Global.PRINTNEW = checked end )
  printNew:SetPoint( "TopLeft", printKills, "BottomLeft", 0, 0 )

  local countGroup = checkbox( "Count group kills",
    "With this disabled, only killing blows made by yourself will count",
    function( _, checked ) KT.Global.COUNT_GROUP = checked end )
  countGroup:SetPoint( "Left", printNew, "Right", 180, 0 )

  local thresholdDesc = panel:CreateFontString( nil, "ARTWORK", "GameFontNormal" )
  thresholdDesc:SetPoint( "TopLeft", printNew, "BottomLeft", 0, -8 )
  thresholdDesc:SetTextColor( 1, 1, 1 )
  thresholdDesc:SetJustifyH( "Left" )
  thresholdDesc:SetText( "Threshold for displaying kill achievements\n(press enter to apply)" )

  local threshold = CreateFrame( "EditBox", "KillTrackOptThreshold", panel, "InputBoxTemplate" )
  threshold:SetHeight( 22 )
  threshold:SetWidth( 70 )
  threshold:SetPoint( "Left", thresholdDesc, "Right", 14, 0 )
  threshold:SetAutoFocus( false )
  threshold:EnableMouse( true )
  threshold:SetScript( "OnEditFocusGained", function()
    this:SetTextColor( 0, 1, 0 )
    this:HighlightText()
  end )
  local function setThreshold( box, enter )
    box:SetTextColor( 1, 1, 1 )
    local value = tonumber( box:GetNumber() )
    if value and value > 0 then
      KT.Global.ACHIEV_THRESHOLD = value
      if not enter then
        KT:Msg( "Updated threshold value!" )
      end
      box:SetText( KT.Global.ACHIEV_THRESHOLD )
    else
      box:SetText( KT.Global.ACHIEV_THRESHOLD )
      box:HighlightText()
    end
  end
  threshold:SetScript( "OnEditFocusLost", function() setThreshold( this ) end )
  threshold:SetScript( "OnEnterPressed", function() setThreshold( this, true ) end )

  local showTarget = button( "Target", "Show information about the currently selected target",
    function()
      if not UnitExists( "target" ) or UnitIsPlayer( "target" ) then return end
      local name = UnitName( "target" )
      KT:PrintKills( name )
    end )
  showTarget:SetWidth( 150 )
  showTarget:SetPoint( "TopLeft", thresholdDesc, "BottomLeft", 0, -16 )

  local list = button( "List", "Open the mob database",
    function()
      KT.MobList:Show()
    end )
  list:SetWidth( 150 )
  list:SetPoint( "TopLeft", showTarget, "TopRight", 8, 0 )

  local purge = button( "Purge", "Purge mob entries with a kill count below a specified number",
    function() KT:ShowPurge() end )
  purge:SetWidth( 150 )
  purge:SetPoint( "TopLeft", showTarget, "BottomLeft", 0, -8 )

  local reset = button( "Reset", "Clear the database of ALL mob entries",
    function() KT:ShowReset() end )
  reset:SetWidth( 150 )
  reset:SetPoint( "TopLeft", purge, "TopRight", 8, 0 )

  local minimap = checkbox( "Show minimap icon", "Adds the KillTrack broker to your minimap",
    function( _, checked ) KT.Broker:SetMinimap( checked ) end )
  minimap:SetPoint( "TopLeft", purge, "BottomLeft", 0, -8 )

  local disableDungeons = checkbox( "Disable in dungeons (save CPU)",
    "When this is checked, mob kills in dungeons won't be counted.",
    function( _, checked ) KT.Global.DISABLE_DUNGEONS = checked end )
  disableDungeons:SetPoint( "TopLeft", minimap, "BottomLeft", 0, 0 )

  local disableRaids = checkbox( "Disable in raids (save CPU)",
    "When this is checked, mob kills in raids won't be counted.",
    function( _, checked ) KT.Global.DISABLE_RAIDS = checked end )
  disableRaids:SetPoint( "TopLeft", disableDungeons, "BottomLeft", 0, 0 )

  local datetimeFormatDesc = panel:CreateFontString( nil, "ARTWORK", "GameFontNormal" )
  datetimeFormatDesc:SetPoint( "TopLeft", disableRaids, "BottomLeft", 0, -8 )
  datetimeFormatDesc:SetTextColor( 1, 1, 1 )
  datetimeFormatDesc:SetJustifyH( "Left" )
  datetimeFormatDesc:SetText( "Datetime format template\n(press enter to apply)" )

  local datetimeFormat = CreateFrame( "EditBox", "KillTrackOptDateTimeFormat", panel, "InputBoxTemplate" )
  datetimeFormat:SetHeight( 22 )
  datetimeFormat:SetWidth( 160 )
  datetimeFormat:SetPoint( "Left", datetimeFormatDesc, "Right", 14, 0 )
  datetimeFormat:SetAutoFocus( false )
  datetimeFormat:EnableMouse( true )
  local datetimeFormatPreview = panel:CreateFontString( nil, "ARTWORK", "GameFontNormal" )
  datetimeFormatPreview:SetPoint( "TopLeft", datetimeFormat, "BottomLeft", -5, -2 )
  datetimeFormatPreview:SetTextColor( 1, 1, 1 )
  datetimeFormatPreview:SetText( "Preview:" )
  local datetimeFormatPreviewValue = panel:CreateFontString( nil, "ARTWORK", "GameFontNormal" )
  datetimeFormatPreviewValue:SetPoint( "Left", datetimeFormatPreview, "Right", 8, 0 )
  datetimeFormatPreviewValue:SetTextColor( 1, 1, 1 )
  datetimeFormatPreviewValue:SetText( KTT:FormatDateTime() --[[@as string]] )

  datetimeFormat:SetScript( "OnEditFocusGained", function()
    this:SetTextColor( 0, 1, 0 )
    this:HighlightText()
  end )

  local function setDateTimeFormat( box, enter )
    box:SetTextColor( 1, 1, 1 )
    local value = box:GetText()
    if type( value ) ~= "string" then
      box:SetText( KT.Global.DATETIME_FORMAT )
      box:HighlightText()
      return
    end
    local valid, errMsg = pcall( KTT.FormatDateTime, KTT, nil, value )
    if not valid then
      KT:Msg( "Invalid format string: " .. (errMsg or "unknown error") )
      box:HighlightText()
      return
    end
    KT.Global.DATETIME_FORMAT = value
    if not enter then
      KT:Msg( "Updated datetime format!" )
    end
    box:SetText( KT.Global.DATETIME_FORMAT )
  end
  datetimeFormat:SetScript( "OnEditFocusLost", function() setDateTimeFormat( this ) end )
  datetimeFormat:SetScript( "OnEnterPressed", function() setDateTimeFormat( this, true ) end )
  datetimeFormat:SetScript( "OnTextChanged", function()
    local value = this:GetText()
    if type( value ) ~= "string" then return end
    local valid, result = pcall( KTT.FormatDateTime, KTT, nil, value )
    if valid then
      datetimeFormatPreviewValue:SetText( result --[[@as string]] )
    else
      datetimeFormatPreviewValue:SetText( "invalid format" )
    end
  end )
  local datetimeFormatReset = button( "Reset", "Reset the datetime format to the default", function()
    KT.Global.DATETIME_FORMAT = KT.Defaults.DateTimeFormat
    datetimeFormat:SetText( KT.Global.DATETIME_FORMAT )
  end )
  datetimeFormatReset:SetWidth( 80 )
  datetimeFormatReset:SetPoint( "Left", datetimeFormat, "Right", 5, 0 )

  local close = button( "Close", "Clear the database of ALL mob entries", function()
    Opt:Hide()
  end )
  close:SetWidth( 100 )
  close:SetPoint( "Bottom", panel, "Bottom", 0, 8 )


  local function init()
    printKills:SetChecked( KT.Global.PRINTKILLS )
    tooltipControl:SetChecked( KT.Global.TOOLTIP )
    printNew:SetChecked( KT.Global.PRINTNEW )
    countGroup:SetChecked( KT.Global.COUNT_GROUP )
    threshold:SetText( tostring( KT.Global.ACHIEV_THRESHOLD ) )
    minimap:SetChecked( not KT.Global.BROKER.MINIMAP.hide )
    disableDungeons:SetChecked( KT.Global.DISABLE_DUNGEONS )
    disableRaids:SetChecked( KT.Global.DISABLE_RAIDS )
    datetimeFormat:SetText( KT.Global.DATETIME_FORMAT )
  end

  init()

  panel:SetScript( "OnShow", init )
  panel:Show()
end

function Opt:Show()
  if not self.Frame then
    self:CreateFrame()
  end

  self.Frame:Show()
end

function Opt:Hide()
  self.Frame:Hide()
end

function Opt:Toggle()
  if self.Frame and self.Frame:IsVisible() then
    Opt:Hide()
  else
    Opt:Show()
  end
end

--panel:SetScript( "OnShow", function() Opt.Show( this ) end )

--Settings.RegisterAddOnCategory(category)
