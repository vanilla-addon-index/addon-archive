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

---@class KillTrackTimerFrame
local TF = {
  Running = false
}

KT.TimerFrame = TF

local T = KT.Timer

local function Enabled( object, enabled )
  if not object.Enable or not object.Disable then return end
  if enabled then
    object:Enable()
  else
    object:Disable()
  end
end

local frame

local function SetupFrame()
  if frame then return end
  frame = CreateFrame( "Frame", nil, UIParent )
  frame:Hide()
  frame:EnableMouse( true )
  frame:SetMovable( true )
  frame:SetWidth( 200 )
  frame:SetHeight( 93 )

  frame:SetPoint( "Center", UIParent, "Center", 0, 0 )

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

  frame:SetScript( "OnMouseDown", function() this:StartMoving() end )
  frame:SetScript( "OnMouseUp", function() this:StopMovingOrSizing() end )

  ---@diagnostic disable-next-line: inject-field
  frame.currentLabel = frame:CreateFontString( nil, "OVERLAY", nil )
  frame.currentLabel:SetFont( "Fonts\\FRIZQT__.TTF", 10, "" )
  frame.currentLabel:SetPoint( "TopLeft", frame, "TopLeft", 8, -8 )
  frame.currentLabel:SetText( "Number of kills:" )

  ---@diagnostic disable-next-line: inject-field
  frame.currentCount = frame:CreateFontString( nil, "OVERLAY", nil )
  frame.currentCount:SetFont( "Fonts\\FRIZQT__.TTF", 10, "" )
  frame.currentCount:SetPoint( "TopRight", frame, "TopRight", -8, -8 )
  frame.currentCount:SetText( "0" )

  ---@diagnostic disable-next-line: inject-field
  frame.timeLabel = frame:CreateFontString( nil, "OVERLAY", nil )
  frame.timeLabel:SetFont( "Fonts\\FRIZQT__.TTF", 10, "" )
  frame.timeLabel:SetPoint( "TopLeft", frame.currentLabel, "BottomLeft", 0, -2 )
  frame.timeLabel:SetText( "Time left:" )

  ---@diagnostic disable-next-line: inject-field
  frame.timeCount = frame:CreateFontString( nil, "OVERLAY", nil )
  frame.timeCount:SetFont( "Fonts\\FRIZQT__.TTF", 10, "" )
  frame.timeCount:SetPoint( "TopRight", frame.currentCount, "BottomRight", 0, -2 )
  frame.timeCount:SetText( "00:00:00" )

  ---@diagnostic disable-next-line: inject-field
  frame.killsPerMinuteLabel = frame:CreateFontString( nil, "OVERLAY", nil )
  frame.killsPerMinuteLabel:SetFont( "Fonts\\FRIZQT__.TTF", 10, "" )
  frame.killsPerMinuteLabel:SetPoint( "TopLeft", frame.timeLabel, "BottomLeft", 0, -2 )
  frame.killsPerMinuteLabel:SetText( "Kills Per Minute:" )

  ---@diagnostic disable-next-line: inject-field
  frame.killsPerMinuteCount = frame:CreateFontString( nil, "OVERLAY", nil )
  frame.killsPerMinuteCount:SetFont( "Fonts\\FRIZQT__.TTF", 10, "" )
  frame.killsPerMinuteCount:SetPoint( "TopRight", frame.timeCount, "BottomRight", 0, -2 )
  frame.killsPerMinuteCount:SetText( "0" )

  ---@diagnostic disable-next-line: inject-field
  frame.killsPerSecondLabel = frame:CreateFontString( nil, "OVERLAY", nil )
  frame.killsPerSecondLabel:SetFont( "Fonts\\FRIZQT__.TTF", 10, "" )
  frame.killsPerSecondLabel:SetPoint( "TopLeft", frame.killsPerMinuteLabel, "BottomLeft", 0, -2 )
  frame.killsPerSecondLabel:SetText( "Kills Per Second:" )

  ---@diagnostic disable-next-line: inject-field
  frame.killsPerSecondCount = frame:CreateFontString( nil, "OVERLAY", nil )
  frame.killsPerSecondCount:SetFont( "Fonts\\FRIZQT__.TTF", 10, "" )
  frame.killsPerSecondCount:SetPoint( "TopRight", frame.killsPerMinuteCount, "BottomRight", 0, -2 )
  frame.killsPerSecondCount:SetText( "Kills Per Minute:" )

  ---@diagnostic disable-next-line: inject-field
  frame.cancelButton = CreateFrame( "Button", nil, frame, "UIPanelButtonTemplate" )
  frame.cancelButton:SetWidth( 60 )
  frame.cancelButton:SetHeight( 16 )
  frame.cancelButton:SetPoint( "Bottom", frame, "Bottom", -40, 7 )
  frame.cancelButton:SetScript( "OnLoad", function( self ) self:Disable() end )
  frame.cancelButton:SetScript( "OnClick", function() TF:Cancel() end )
  frame.cancelButton:SetText( "Stop" )

  ---@diagnostic disable-next-line: inject-field
  frame.closeButton = CreateFrame( "Button", nil, frame, "UIPanelButtonTemplate" )
  frame.closeButton:SetWidth( 60 )
  frame.closeButton:SetHeight( 16 )
  frame.closeButton:SetPoint( "Bottom", frame, "Bottom", 40, 7 )
  frame.closeButton:SetScript( "OnLoad", function( self ) self:Disable() end )
  frame.closeButton:SetScript( "OnClick", function() TF:Close() end )
  frame.closeButton:SetText( "Close" )

  ---@diagnostic disable-next-line: inject-field
  frame.progressBar = CreateFrame( "StatusBar", nil, frame )
  frame.progressBar:SetStatusBarTexture( [[Interface\TargetingFrame\UI-StatusBar]] )
  frame.progressBar:SetStatusBarColor( 0, 1, 0 )
  frame.progressBar:SetMinMaxValues( 0, 1 )
  frame.progressBar:SetValue( 0 )
  frame.progressBar:SetPoint( "TopLeft", frame.killsPerSecondLabel, "BottomLeft", -1, -2 )
  frame.progressBar:SetPoint( "Right", frame.killsPerSecondCount, "Right", 0, 0 )
  frame.progressBar:SetPoint( "Bottom", frame.cancelButton, "Top", 0, 2 )

  ---@diagnostic disable-next-line: inject-field
  frame.progressLabel = frame.progressBar:CreateFontString( nil, "OVERLAY", nil )
  frame.progressLabel:SetFont( "Fonts\\FRIZQT__.TTF", 10, "OUTLINE" )
  frame.progressLabel:SetAllPoints( frame.progressBar )
  frame.progressLabel:SetText( "0%" )
end

function TF:InitializeControls()
  frame.currentCount:SetText( "0" )
  frame.timeCount:SetText( "00:00:00" )
  frame.progressLabel:SetText( "0%" )
  frame.progressBar:SetValue( 0 )
  self:UpdateControls()
end

function TF:UpdateControls()
  Enabled( frame.cancelButton, self.Running )
  Enabled( frame.closeButton, not self.Running )
end

function TF:UpdateData( data, state )
  if state == T.State.START then
    self:InitializeControls()
  else
    local kills = T:GetData( "Kills", true )
    local kpm, kps
    if data.Current <= 0 then
      kpm, kps = 0, 0
    else
      kpm = kills / (data.Current / 60)
      kps = kills / data.Current
    end
    frame.currentCount:SetText( kills )
    frame.timeCount:SetText( data.LeftFormat )
    frame.progressLabel:SetText( floor( data.Progress * 100 ) .. "%" )
    ---@diagnostic disable-next-line: undefined-field
    frame.progressBar:SetMinMaxValues( 0, data.Total )
    ---@diagnostic disable-next-line: undefined-field
    frame.progressBar:SetValue( data.Current )
    frame.killsPerMinuteCount:SetText( string.format( "%.2f", kpm ) )
    frame.killsPerSecondCount:SetText( string.format( "%.2f", kps ) )
    if state == T.State.STOP then self:Stop() end
  end
  self:UpdateControls()
end

function TF:Start( s, m, h )
  if self.Running then return end
  self.Running = true
  SetupFrame()
  self:InitializeControls()
  frame:Show()
  if not T:Start( s, m, h, function( d, u ) TF:UpdateData( d, u ) end, nil ) then
    self:Stop()
    frame:Hide()
  end
end

function TF:Stop()
  if not self.Running then return end
  self.Running = false
end

function TF:Cancel()
  T:Stop()
end

function TF:Close()
  if not frame then return end
  self:InitializeControls()
  frame:Hide()
end
