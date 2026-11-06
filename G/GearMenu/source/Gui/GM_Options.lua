--[[
  MIT License

  Copyright (c) 2019 Michael Wiesendanger

  Permission is hereby granted, free of charge, to any person obtaining
  a copy of this software and associated documentation files (the
  "Software"), to deal in the Software without restriction, including
  without limitation the rights to use, copy, modify, merge, publish,
  distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to
  the following conditions:

  The above copyright notice and this permission notice shall be
  included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--

local mod = gm
local me = {}
mod.opt = me

me.tag = "Options"

-- allow the escape key to close the options window, consistent with the
-- rest of the game's UI panels (e.g. bags, character sheet, spellbook)
table.insert(UISpecialFrames, GM_CONSTANTS.ELEMENT_OPTIONS_FRAME)

function me.InitOptionsMenu()
  local optionsFrame = getglobal(GM_CONSTANTS.ELEMENT_OPTIONS_FRAME)

  if optionsFrame:IsShown() then
    optionsFrame:Hide()
    return
  end

  -- set version title
  getglobal(GM_CONSTANTS.ELEMENT_OPTIONS_TITLE):SetText(GM_ENVIRONMENT.ADDON_NAME ..
    " " .. GM_ENVIRONMENT.ADDON_VERSION)
  -- show optionsframe
  optionsFrame:Show()
end

--[[
  Close the optionsmenu by hiding it
]]--
function me.OptionCloseButtonOnClick()
  getglobal(GM_CONSTANTS.ELEMENT_OPTIONS_FRAME):Hide()
end

--[[
  @param {boolean} locked
]]--
function me.ReflectLockState(locked)
  local mainFrame = getglobal(GM_CONSTANTS.ELEMENT_MAIN_FRAME)
  local slotFrame = getglobal(GM_CONSTANTS.ELEMENT_SLOT_FRAME)

  if locked then
    mainFrame:SetBackdropColor(0, 0, 0, 0)
    mainFrame:SetBackdropBorderColor(0, 0, 0, 0 * 2)
    slotFrame:SetBackdropColor(0, 0, 0, 0)
    slotFrame:SetBackdropBorderColor(0, 0, 0, 0 * 2)
    slotFrame:EnableMouse(0 * 2)

    -- hide move button
    getglobal(GM_CONSTANTS.ELEMENT_DRAG_BUTTON):Hide()
  else
    mainFrame:SetBackdropColor(.5, .5, .5, .5)
    mainFrame:SetBackdropBorderColor(.5, .5, .5, .5 * 2)
    slotFrame:SetBackdropColor(.5, .5, .5, .5)
    slotFrame:SetBackdropBorderColor(.5, .5, .5, .5 * 2)
    slotFrame:EnableMouse(.5 * 2)

    -- show move button
    getglobal(GM_CONSTANTS.ELEMENT_DRAG_BUTTON):Show()
  end
end
