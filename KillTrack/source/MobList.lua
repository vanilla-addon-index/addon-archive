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

-- Beware of some possibly messy code in this file

---@class KillTrack
KT = KT or {}

---@class KillTrackMobList
local ML = {}

KT.MobList = ML
local KTT = KT.Tools

local Sort = KT.Sort.Desc
---@type { Id: integer, Name: string, ZoneName: string, gKills: integer, cKills: integer }[]
local Mobs = nil
local LastFilter = nil
local LastZone = nil
local LastOffset = 0

-- Frame Constants
local FRAME_WIDTH = 451
local FRAME_HEIGHT = 545
local HEADER_HEIGHT = 24
local HEADER_LEFT = 13
local HEADER_TOP = -90
local ROW_HEIGHT = 15
local ROW_COUNT = 27
local ROW_TEXT_PADDING = 4
local NAME_WIDTH = KT.pfUI and 300 or 271
local CHAR_WIDTH = KT.pfUI and 76 or 90
local GLOBAL_WIDTH = KT.pfUI and 50 or 65
local SCROLL_WIDTH = 27 -- Scrollbar width
local STATUS_TEXT = "Showing entries %d through %d out of %d total (%d hidden)"

---@type Frame
local frame = nil
local created = false

---@type ScrollDropdown
local scroll_drop = LibStub:GetLibrary( "LibScrollDrop-1.0" )

-- Frame helper functions

---@class Header : Button
---@field label FontString

---@param parent table
---@return Header
local function CreateHeader( parent )
  local h = CreateFrame( "Button", nil, parent )
  ---@cast h Header

  h:SetHeight( HEADER_HEIGHT )

  ---@diagnostic disable-next-line: inject-field
  h.label = h:CreateFontString( nil, "ARTWORK", "GameFontHighlightSmall" )
  h.label:SetPoint( "TopLeft", h, "TopLeft", ROW_TEXT_PADDING * 2, 0 )
  h.label:SetHeight( HEADER_HEIGHT )

  local bgl = h:CreateTexture( nil, "BACKGROUND" )
  bgl:SetTexture( "Interface\\FriendsFrame\\WhoFrame-ColumnTabs" )
  bgl:SetWidth( 5 )
  bgl:SetHeight( HEADER_HEIGHT )
  bgl:SetPoint( "TopLeft", h, "TopLeft", 0, 0 )
  bgl:SetTexCoord( 0, 0.07815, 0, 0.75 )

  local bgr = h:CreateTexture( nil, "BACKGROUND" )
  bgr:SetTexture( "Interface\\FriendsFrame\\WhoFrame-ColumnTabs" )
  bgr:SetWidth( 5 )
  bgr:SetHeight( HEADER_HEIGHT )
  bgr:SetPoint( "TopRight", h, "TopRight", 0, 0 )
  bgr:SetTexCoord( 0.90625, 0.96875, 0, 0.75 )

  local bgm = h:CreateTexture( nil, "BACKGROUND" )
  bgm:SetTexture( "Interface\\FriendsFrame\\WhoFrame-ColumnTabs" )
  bgm:SetHeight( HEADER_HEIGHT )
  bgm:SetPoint( "Left", bgl, "Right" )
  bgm:SetPoint( "Right", bgr, "Left" )
  bgm:SetTexCoord( 0.07815, 0.90625, 0, 0.75 )

  local hl = h:CreateTexture()
  h:SetHighlightTexture( "Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight" )
  hl:SetPoint( "TopLeft", bgl, "TopLeft", -2, 5 )
  hl:SetPoint( "BottomRight", bgr, "BottomRight", 2, -7 )

  return h
end

---@param container table
---@param previous table
---@return table
local function CreateRow( container, previous )
  local row = CreateFrame( "Button", nil, container )
  row:SetHighlightTexture( "Interface\\QuestFrame\\UI-QuestTitleHighlight" )
  row:SetHeight( ROW_HEIGHT )
  row:SetPoint( "Left", container, "Left", 0, 0 )
  row:SetPoint( "Right", container, "Right", 0, 0 )
  row:SetPoint( "TopLeft", previous, "BottomLeft", 0, 0 )

  ---@diagnostic disable-next-line: inject-field
  row.nameField = row:CreateFontString( nil, "ARTWORK", "GameFontHighlightSmall" )
  row.nameField:SetHeight( ROW_HEIGHT )
  row.nameField:SetWidth( NAME_WIDTH - SCROLL_WIDTH - ROW_TEXT_PADDING * 4 )
  row.nameField:SetPoint( "Left", row, "Left", ROW_TEXT_PADDING * 2, 0 )
  row.nameField:SetJustifyH( "Left" )

  ---@diagnostic disable-next-line: inject-field
  row.charKillField = row:CreateFontString( nil, "ARTWORK", "GameFontHighlightSmall" )
  row.charKillField:SetHeight( ROW_HEIGHT )
  row.charKillField:SetWidth( CHAR_WIDTH - ROW_TEXT_PADDING * 4 - 4 )
  row.charKillField:SetPoint( "Left", row.nameField, "Right", 4 * ROW_TEXT_PADDING, 0 )
  row.charKillField:SetJustifyH( "Right" )

  ---@diagnostic disable-next-line: inject-field
  row.globalKillField = row:CreateFontString( nil, "ARTWORK", "GameFontHighlightSmall" )
  row.globalKillField:SetHeight( ROW_HEIGHT )
  row.globalKillField:SetWidth( GLOBAL_WIDTH - ROW_TEXT_PADDING * 2 + 4 )
  row.globalKillField:SetPoint( "Left", row.charKillField, "Right", 4 * ROW_TEXT_PADDING - 2, 0 )
  row.globalKillField:SetJustifyH( "Right" )

  row:SetScript( "OnClick", function()
    local name = this.nameField:GetText()
    KT:ShowDelete( name )
  end )

  row:SetScript( "OnEnter", function()
    local name = this.nameField:GetText()
    local globalData = KT.Global.MOBS[ name ]
    if not globalData then return end
    local killTimestamp = globalData.LastKillAt
    if not killTimestamp then return end
    local lastKillAt = KTT:FormatDateTime( killTimestamp )
    local tpString = string.format( "Last killed at %s", lastKillAt )

    GameTooltip:SetOwner( this, "ANCHOR_BOTTOMLEFT" )
    GameTooltip:ClearLines()
    GameTooltip:AddLine( tpString )
    GameTooltip:Show()
  end )

  row:SetScript( "OnLeave", function()
    GameTooltip:Hide()
  end )

  return row
end

function ML:Show()
  ML.Zones = nil
  if not created then
    ML:Create()
  end
  if frame:IsShown() then return end
  frame:Show()
end

function ML:Hide()
  if not frame or not frame:IsShown() then return end
  frame:Hide()
end

function ML:Toggle()
  if frame and frame:IsShown() then
    ML:Hide()
  else
    ML:Show()
  end
end

function ML:Create()
  if frame then return end
  frame = CreateFrame( "Frame", "KillTrackMobListFrame", UIParent )
  frame:Hide()
  frame:SetToplevel( true )
  frame:EnableMouse( true )
  frame:SetMovable( true )
  frame:SetPoint( "Center", UIParent, "Center", 0, 0 )
  frame:SetWidth( FRAME_WIDTH )
  frame:SetHeight( FRAME_HEIGHT )

  table.insert( UISpecialFrames, frame:GetName() )

  local bd = {
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
  }

  frame:SetBackdrop( bd )

  ---@diagnostic disable-next-line: inject-field
  frame.titleLabel = frame:CreateFontString( nil, "OVERLAY", "GameFontNormal" )
  frame.titleLabel:SetHeight( 16 )
  frame.titleLabel:SetPoint( "TopLeft", frame, "TopLeft", 0, -8 )
  frame.titleLabel:SetPoint( "Right", frame, "Right", 0, 0 )
  frame.titleLabel:SetJustifyH( "Center" )
  frame.titleLabel:SetText( "KillTrack Mob Database (" .. KT.Version .. ")" )

  frame:SetScript( "OnMouseDown", function() frame:StartMoving() end )
  frame:SetScript( "OnMouseUp", function() frame:StopMovingOrSizing() end )
  frame:SetScript( "OnShow", function()
    ML:UpdateMobs( Sort, LastFilter )
    ML:UpdateEntries( LastOffset )
  end )

  ---@diagnostic disable-next-line: inject-field
  frame.closeButton = CreateFrame( "Button", nil, frame, "UIPanelCloseButton" )
  frame.closeButton:SetPoint( "TopRight", frame, "TopRight", -1, -1 )
  frame.closeButton:SetScript( "OnClick", function() ML:Hide() end )

  ---@diagnostic disable-next-line: inject-field
  frame.purgeButton = CreateFrame( "Button", nil, frame, "UIPanelButtonTemplate" )
  frame.purgeButton:SetHeight( 24 )
  frame.purgeButton:SetWidth( 100 )
  frame.purgeButton:SetPoint( "TopLeft", frame, "TopLeft", 10, -8 )
  frame.purgeButton:SetText( "Purge Data" )
  frame.purgeButton:SetScript( "OnClick", function()
    KT:ShowPurge()
  end )

  ---@diagnostic disable-next-line: inject-field
  frame.resetButton = CreateFrame( "Button", nil, frame, "UIPanelButtonTemplate" )
  frame.resetButton:SetHeight( 24 )
  frame.resetButton:SetWidth( 100 )
  frame.resetButton:SetPoint( "TopLeft", frame.purgeButton, "BottomLeft", 0, -3 )
  frame.resetButton:SetText( "Reset All" )
  frame.resetButton:SetScript( "OnClick", function()
    KT:ShowReset()
  end )

  local font = KT.pfUI and "GameFontNormal" or "GameFontNormalSmall"

  ---@diagnostic disable-next-line: inject-field
  frame.helpLabel = frame:CreateFontString( nil, "OVERLAY", font )
  frame.helpLabel:SetWidth( 300 )
  frame.helpLabel:SetHeight( 32 )
  frame.helpLabel:SetPoint( "TopLeft", frame, "TopLeft", 120, -28 )
  frame.helpLabel:SetJustifyH( "Left" )
  frame.helpLabel:SetText(
    "Click on an individual entry to delete it from the database. Use the search to filter database by name." )

  ---@diagnostic disable-next-line: inject-field
  frame.searchBox = CreateFrame( "EditBox", "KillTrackMobListSearchBox", frame, "SearchBoxTemplate" )
  frame.searchBox:SetWidth( 150 )
  frame.searchBox:SetHeight( 16 )
  frame.searchBox:SetPoint( "TopLeft", frame.resetButton, "BottomLeft", 8, -6 )
  frame.searchBox:SetScript( "OnTextChanged", function( s )
    local text = frame.searchBox:GetText()
    if (not _G[ frame.searchBox:GetName() .. "ClearButton" ]:IsShown()) then
      text = ""
      LastFilter = nil
    end
    if not text or text == "" then
      ML:UpdateMobs( Sort )
    else
      ML:UpdateMobs( Sort, text )
    end
    ML:UpdateEntries( LastOffset )
  end )
  frame.searchBox:SetScript( "OnEnterPressed", function() frame.searchBox:ClearFocus() end )
  ---@diagnostic disable-next-line: inject-field
  frame.searchBox.clearButton = _G[ frame.searchBox:GetName() .. "ClearButton" ]
  local sBoxOldFunc = frame.searchBox.clearButton:GetScript( "OnHide" )
  frame.searchBox.clearButton:SetScript( "OnHide", function( s )
    if sBoxOldFunc then sBoxOldFunc( s ) end
    if not frame:IsShown() then return end
    ML:UpdateMobs( Sort, nil )
    ML:UpdateEntries( LastOffset )
  end )

  ---@diagnostic disable-next-line: inject-field
  frame.searchTipLabel = frame:CreateFontString( nil, "OVERLAY", font )
  frame.searchTipLabel:SetWidth( 125 )
  frame.searchTipLabel:SetHeight( 16 )
  frame.searchTipLabel:SetPoint( "Left", frame.searchBox, "Right", 5, 0 )
  frame.searchTipLabel:SetJustifyH( "Left" )
  frame.searchTipLabel:SetText( "(Supports Lua patterns)" )

  local dropdown = scroll_drop:New( frame, {
    default_text = "All zones",
    dropdown_style = "classic",
    label_on_select = "value",
    width = 120
  } )

  dropdown:SetPoint( "Left", frame.searchTipLabel, "Right", 17, 0 )
  dropdown:SetItems( function()
    local zone_data = {}
    local list = {}
    for _, mob in pairs( KT.Global.MOBS ) do
      if mob.ZoneName then
        zone_data[ mob.ZoneName ] = zone_data[ mob.ZoneName ] and zone_data[ mob.ZoneName ] + 1 or 1
      end
    end

    table.insert( list, {
      value = nil,
      text = "All Zones"
    })

    for zone, count in pairs( zone_data ) do
      table.insert( list, {
        value = zone,
        text = zone .. " (" .. count .. ")"
      } )
    end

    table.sort( list, function(a,b)
      if not a.value then return true end
      if not b.value then return false end
      return a.value < b.value
    end )

    return list
  end, function( value, index )
    LastZone = value
    ML:UpdateMobs( Sort, LastFilter )
    ML:UpdateEntries( LastOffset )
  end )

  ---@diagnostic disable-next-line: inject-field
  frame.nameHeader = CreateHeader( frame )
  frame.nameHeader:SetPoint( "TopLeft", frame, "TopLeft", HEADER_LEFT, HEADER_TOP )
  frame.nameHeader:SetWidth( NAME_WIDTH - SCROLL_WIDTH )
  frame.nameHeader.label:SetText( "Name" )
  frame.nameHeader:SetScript( "OnClick", function()
    local sort = KT.Sort.AlphaA
    if Sort == sort then
      sort = KT.Sort.AlphaD
    end
    ML:UpdateMobs( sort, LastFilter )
    ML:UpdateEntries( LastOffset )
  end )

  ---@diagnostic disable-next-line: inject-field
  frame.charKillHeader = CreateHeader( frame )
  frame.charKillHeader:SetPoint( "TopLeft", frame.nameHeader, "TopRight", -2, 0 )
  frame.charKillHeader:SetWidth( CHAR_WIDTH )
  frame.charKillHeader.label:SetText( "Character Kills" )
  frame.charKillHeader:SetScript( "OnClick", function()
    local sort = KT.Sort.CharDesc
    if Sort == sort then
      sort = KT.Sort.CharAsc
    end
    ML:UpdateMobs( sort, LastFilter )
    ML:UpdateEntries( LastOffset )
  end )

  ---@diagnostic disable-next-line: inject-field
  frame.globalKillHeader = CreateHeader( frame )
  frame.globalKillHeader:SetPoint( "TopLeft", frame.charKillHeader, "TopRight", -2, 0 )
  frame.globalKillHeader:SetWidth( GLOBAL_WIDTH + HEADER_LEFT )
  frame.globalKillHeader.label:SetText( "Global Kills" )
  frame.globalKillHeader:SetScript( "OnClick", function()
    local sort = KT.Sort.Desc
    if Sort == sort then
      sort = KT.Sort.Asc
    end
    ML:UpdateMobs( sort, LastFilter )
    ML:UpdateEntries( LastOffset )
  end )

  ---@diagnostic disable-next-line: inject-field
  frame.rows = CreateFrame( "Frame", nil, frame )
  frame.rows:SetPoint( "Left", frame, "Left", 10, 0 )
  frame.rows:SetPoint( "Right", frame, "Right", -SCROLL_WIDTH - 9, 0 )
  frame.rows:SetPoint( "Top", frame.nameHeader, "Bottom", 0, 0 )
  frame.rows:SetPoint( "Bottom", frame, "Bottom", 0, 0 )
  frame.rows:SetPoint( "TopLeft", frame.nameHeader, "BottomLeft", 0, 30 )

  local previous = frame.nameHeader
  for i = 1, ROW_COUNT do
    local key = "row" .. i
    frame.rows[ key ] = CreateRow( frame.rows, previous )
    frame.rows[ key ].nameField:SetText( "" )
    frame.rows[ key ].charKillField:SetText( "" )
    frame.rows[ key ].globalKillField:SetText( "" )
    previous = frame.rows[ key ]
  end

  ---@diagnostic disable-next-line: inject-field
  frame.rows.scroller = CreateFrame( "ScrollFrame", "KillTrackMobListScrollFrame", frame.rows, "FauxScrollFrameTemplate" )
  ---@diagnostic disable-next-line: inject-field
  frame.rows.scroller.name = frame.rows.scroller:GetName()
  frame.rows.scroller:SetWidth( frame.rows:GetWidth() )
  frame.rows.scroller:SetPoint( "TopRight", frame.rows, "TopRight", -1, -HEADER_HEIGHT - 5 )
  frame.rows.scroller:SetPoint( "BottomRight", frame.rows, "BottomRight", 0, 24 )
  frame.rows.scroller:SetScript( "OnVerticalScroll", function()
    FauxScrollFrame_OnVerticalScroll( ROW_HEIGHT, function()
      local offset = FauxScrollFrame_GetOffset( frame.rows.scroller )
      ML:UpdateEntries( offset )
    end
    )
  end )

  self:UpdateMobs( Sort )

  ---@diagnostic disable-next-line: inject-field
  frame.statusLabel = frame:CreateFontString( nil, "OVERLAY", "GameFontNormal" )
  frame.statusLabel:SetWidth( 420 )
  frame.statusLabel:SetHeight( 16 )
  frame.statusLabel:SetPoint( "Bottom", frame, "Bottom", 0, 8 )
  frame.statusLabel:SetText( string.format( STATUS_TEXT, 1, ROW_COUNT, getn( Mobs ), 0 ) )


  self:UpdateEntries( LastOffset )

  created = true
end

---@param sort KillTrackMobSortMode?
---@param filter string?
function ML:UpdateMobs( sort, filter )
  sort = (sort or Sort) or KT.Sort.Desc
  Sort = sort
  LastFilter = filter
  if filter == "Search" then filter = nil end
  Mobs = KT:GetSortedMobTable( Sort, filter and string.lower( filter ) or nil, nil, LastZone )
  FauxScrollFrame_Update( frame.rows.scroller, getn( Mobs ), ROW_COUNT, ROW_HEIGHT )
end

---@param offset integer?
function ML:UpdateEntries( offset )
  if (getn( Mobs ) <= 0) then
    for i = 1, ROW_COUNT do
      local row = frame.rows[ "row" .. i ]
      if i == 1 then
        row.nameField:SetText( "No entries in database or none matched search!" )
      else
        row.nameField:SetText( "" )
      end
      row.charKillField:SetText( "" )
      row.globalKillField:SetText( "" )
      row:Disable()
    end

    frame.statusLabel:SetText( string.format( STATUS_TEXT, 0, 0, 0, 0 ) )

    return
  elseif getn( Mobs ) < ROW_COUNT then
    for i = 1, ROW_COUNT do
      local row = frame.rows[ "row" .. i ]
      row.nameField:SetText( "" )
      row.charKillField:SetText( "" )
      row.globalKillField:SetText( "" )
      row:Disable()
    end
  end
  offset = (tonumber( offset ) or LastOffset) or 0
  LastOffset = offset
  local limit = ROW_COUNT
  if limit > getn( Mobs ) then
    limit = getn( Mobs )
  end
  for i = 1, limit do
    local row = frame.rows[ "row" .. i ]
    local mob = Mobs[ i + offset ]
    row.nameField:SetText( mob.Name )
    row.charKillField:SetText( mob.cKills )
    row.globalKillField:SetText( mob.gKills )
    row:Enable()
  end

  local mobCount = KTT:TableLength( KT.Global.MOBS )
  local hidden = mobCount - getn( Mobs )
  frame.statusLabel:SetText( string.format( STATUS_TEXT, 1 + offset, math.min( getn( Mobs ), offset + ROW_COUNT ), getn( Mobs ), hidden ) )

  if offset == 0 then
    _G[ frame.rows.scroller.name .. "ScrollBarScrollUpButton" ]:Disable()
  else
    _G[ frame.rows.scroller.name .. "ScrollBarScrollUpButton" ]:Enable()
  end

  if offset + ROW_COUNT == getn( Mobs ) then
    _G[ frame.rows.scroller.name .. "ScrollBarScrollDownButton" ]:Disable()
  else
    _G[ frame.rows.scroller.name .. "ScrollBarScrollDownButton" ]:Enable()
  end
end
