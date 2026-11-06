--[[
  Created by Vee (http://victortemprano.com), Drixi in-game
  See Github repo at https://github.com/tempranova/turtlerp

-- Need to account for all different possibilities for tooltip :)
-- Pvp, guilded, other unexpected things?
-- Not clearing and remaking (status bar), but instead overwriting existing lines
-- Using the "GetText() == nil" as a test for a line's existence
-- Not worrying about multiple overwrites? Could this cause lag? Are there overwrites occuring (only when rapidly mousing out and in again)

--]]

function TurtleRP.WrapTooltipLine(text, maxChars)
  if not text or maxChars <= 0 then
    return text
  end
  local function StripColorCodes(value)
    local stripped = value or ""
    stripped = string.gsub(stripped, "|c%x%x%x%x%x%x%x%x", "")
    stripped = string.gsub(stripped, "|r", "")
    return stripped
  end
  local function FindWrapIndex(value, startIndex, maxVisibleChars)
    local visibleIndex = 0
    local lastSpaceOrig = nil
    local i = startIndex
    local len = string.len(value)
    while i <= len do
      local twoChar = string.sub(value, i, i + 1)
      if twoChar == "|c" then
        i = i + 10
      elseif twoChar == "|r" then
        i = i + 2
      else
        local oneChar = string.sub(value, i, i)
        if oneChar == "\n" then
          return i
        end
        visibleIndex = visibleIndex + 1
        if oneChar == " " then
          lastSpaceOrig = i
        end
        if visibleIndex >= maxVisibleChars then
          return lastSpaceOrig or i
        end
        i = i + 1
      end
    end
    return nil
  end

  if string.len(StripColorCodes(text)) <= maxChars then
    return text
  end
  local wrappedParts = {}
  local startIndex = 1
  local len = string.len(text)
  while startIndex <= len do
    local wrapIndex = FindWrapIndex(text, startIndex, maxChars)
    if not wrapIndex then
      table.insert(wrappedParts, string.sub(text, startIndex))
      break
    end
    local currentChar = string.sub(text, wrapIndex, wrapIndex)
    if currentChar == "\n" then
      table.insert(wrappedParts, string.sub(text, startIndex, wrapIndex - 1))
      startIndex = wrapIndex + 1
    else
      table.insert(wrappedParts, string.sub(text, startIndex, wrapIndex - 1))
      startIndex = wrapIndex
      while startIndex <= len and string.sub(text, startIndex, startIndex) == " " do
        startIndex = startIndex + 1
      end
    end
  end
  return table.concat(wrappedParts, "\n")
end
-- Im not actually sure at this moment what the name of the Arena zone is so. This can be updated later.
TurtleRP.DisabledTooltipZones = {
  ["Warsong Gulch"] = true,
  ["Arathi Basin"] = true,
  ["Alterac Valley"] = true,
  ["Thorn Gorge"] = true,
  ["Arena"] = true,
}

function TurtleRP.ShouldUseCustomTooltip()
	if TurtleRPSettings and TurtleRPSettings["disable_tooltip"] == "1" then
	  return false
	end
	if IsAltKeyDown() then
	  return false
	end
  if TurtleRPSettings and TurtleRPSettings["disable_tooltip_bg"] == "1" then
    local zoneName = GetRealZoneText() or ""
    if TurtleRP.DisabledTooltipZones[zoneName] then
      return false
    end
    local inInstance, instanceType = IsInInstance()
    if instanceType == "pvp" or instanceType == "arena" then
      return false
    end
  end
  return true
end

function TurtleRP.ShouldUseCustomTooltipForUnit(unit)
  if not unit or unit == "" or not UnitExists(unit) then
    return false
  end
  if UnitIsPlayer(unit) then
    local unitName = UnitName(unit)
    local characterInfo = unitName and TurtleRPCharacters and TurtleRPCharacters[unitName] or nil
    if not characterInfo or not characterInfo["keyM"] or characterInfo["keyM"] == "" then
      return false
    end
    if (characterInfo["full_name"] and characterInfo["full_name"] ~= "")
      or (characterInfo["ic_info"] and characterInfo["ic_info"] ~= "")
      or (characterInfo["ooc_info"] and characterInfo["ooc_info"] ~= "")
      or (characterInfo["short_note"] and characterInfo["short_note"] ~= "")
      or (characterInfo["guild_override"] and characterInfo["guild_override"] ~= "") then
      return true
    end
    return false
  end
  if TurtleRP.IsOwnedPetUnit and TurtleRP.IsOwnedPetUnit(unit) then
    local petProfile = nil
    if TurtleRP.GetPetProfileFromUnit then
      petProfile = TurtleRP.GetPetProfileFromUnit(unit)
    end
    if not petProfile and TurtleRP.GetPetCommKeyFromUnit and TurtleRPPetCache then
      local petCommKey = TurtleRP.GetPetCommKeyFromUnit(unit)
      if petCommKey and TurtleRPPetCache[petCommKey] then
        petProfile = TurtleRPPetCache[petCommKey]
      end
    end
    if not petProfile or not petProfile["keyM"] or petProfile["keyM"] == "" then
      return false
    end
    if (petProfile["name"] and petProfile["name"] ~= "")
      or (petProfile["info"] and petProfile["info"] ~= "")
      or (petProfile["pronouns"] and petProfile["pronouns"] ~= "") then
      return true
    end
    return false
  end
  return false
end

local function TurtleRP_ClearTooltipLines()
  local i
  for i = 1, 20 do
    local left = getglobal("GameTooltipTextLeft" .. i)
    local right = getglobal("GameTooltipTextRight" .. i)
    if left then
      left:SetText("")
      left:SetTextColor(1, 1, 1)
    end
    if right then
      right:SetText("")
      right:Hide()
      right:SetTextColor(1, 1, 1)
    end
  end
end

local function TurtleRP_ClearTooltipLinesAfter(startIndex)
  local i
  for i = startIndex, 20 do
    local left = getglobal("GameTooltipTextLeft" .. i)
    local right = getglobal("GameTooltipTextRight" .. i)
    if left then
      left:SetText("")
      left:SetTextColor(1, 1, 1)
    end
    if right then
      right:SetText("")
      right:Hide()
      right:SetTextColor(1, 1, 1)
    end
  end
end

function TurtleRP.buildPetTooltip(unit)
  local petProfile, petUID = TurtleRP.GetPetProfileFromUnit(unit)
  if petProfile and type(petProfile) ~= "table" then
    petProfile = nil
  end
  if not petProfile and TurtleRP.GetPetCommKeyFromUnit and TurtleRPPetCache then
    local petCommKey = TurtleRP.GetPetCommKeyFromUnit(unit)
    if petCommKey and TurtleRPPetCache[petCommKey] then
      petProfile = TurtleRPPetCache[petCommKey]
    end
  end

  if not petProfile then
    return
  end

  local queriedLevel = UnitLevel(unit)
  local levelText = queriedLevel == -1 and "??" or tostring(queriedLevel or "")
  local species = TurtleRP.GetPetTypeFromUnit(unit) or ""

  if petProfile["level"] and petProfile["level"] ~= "" then
    levelText = tostring(petProfile["level"])
  end
  if petProfile["species"] and petProfile["species"] ~= "" then
    species = petProfile["species"]
  end

  local icon = (petProfile and petProfile["icon"]) or nil
  local pronouns = (petProfile and petProfile["pronouns"]) or nil
  local info = (petProfile and petProfile["info"]) or nil
  local name = (petProfile["name"] and petProfile["name"] ~= "") and petProfile["name"] or (UnitName(unit) or "Pet")

  local nameColor = "|cffF0C674"
  local pronounColor = "|cffffcc80"
  local blankLine = " "

  TurtleRP.gameTooltip:ClearLines()
  TurtleRP_ClearTooltipLines()

  local l = 1
  local titleExtraSpaces = (icon ~= nil and icon ~= "") and "       " or ""
  local nameWrapPrefix = nameColor .. titleExtraSpaces
  local nameLine = nameWrapPrefix .. name
  nameLine = TurtleRP.WrapTooltipLine(nameLine, 34)

  local newlinePos = string.find(nameLine, "\n", 1, true)
  if newlinePos then
    local wrappedFirst = string.sub(nameLine, 1, newlinePos - 1)
    local wrappedSecond = string.sub(nameLine, newlinePos + 1)
    if wrappedSecond and wrappedSecond ~= "" then
      nameLine = wrappedFirst .. "\n" .. nameWrapPrefix .. wrappedSecond
    end
  end

  TurtleRP.gameTooltip:AddLine(nameLine)
  if TurtleRPSettings["name_size"] == "1" then
    getglobal("GameTooltipTextLeft1"):SetFont("Fonts\\FRIZQT__.ttf", 18)
  else
    getglobal("GameTooltipTextLeft1"):SetFont("Fonts\\FRIZQT__.ttf", 15)
  end
  getglobal("GameTooltipTextLeft1"):SetText(nameLine)

  local speciesLevelText = ""
  if species ~= "" and levelText ~= "" then
    speciesLevelText = "|cffFFFFFFLevel " .. levelText .. " " .. species
  elseif species ~= "" then
    speciesLevelText = "|cffFFFFFF" .. species
  elseif levelText ~= "" then
    speciesLevelText = "|cffFFFFFFLevel " .. levelText
  end

  TurtleRP.gameTooltip:AddLine(" ")
  getglobal("GameTooltipTextLeft2"):SetText("")
  getglobal("GameTooltipTextRight2"):SetText("")
  getglobal("GameTooltipTextRight2"):Hide()

  if speciesLevelText ~= "" then
    getglobal("GameTooltipTextLeft2"):SetText("")
    getglobal("GameTooltipTextRight2"):Show()
    getglobal("GameTooltipTextRight2"):SetText(speciesLevelText)
    getglobal("GameTooltipTextRight2"):SetJustifyH("RIGHT")
    l = 2
  else
    l = 1
  end
  getglobal("GameTooltipTextLeft3"):SetText("")
  getglobal("GameTooltipTextRight3"):SetText("")
  getglobal("GameTooltipTextRight3"):Hide()
  getglobal("GameTooltipTextLeft4"):SetText("")
  getglobal("GameTooltipTextRight4"):SetText("")
  getglobal("GameTooltipTextRight4"):Hide()
  getglobal("GameTooltipTextLeft5"):SetText("")
  getglobal("GameTooltipTextRight5"):SetText("")
  getglobal("GameTooltipTextRight5"):Hide()

  if (info and info ~= "") or (pronouns and pronouns ~= "") then
    local wrappedInfo = TurtleRP.WrapTooltipLine(info or "", 46)
    local infoHeader = "Info" .. TurtleRP.getPronounsText(pronouns, pronounColor)

    TurtleRP.gameTooltip:AddLine(blankLine)
    getglobal("GameTooltipTextLeft3"):SetText(blankLine)
    getglobal("GameTooltipTextRight3"):SetText("")
    getglobal("GameTooltipTextRight3"):Hide()

    TurtleRP.gameTooltip:AddLine(infoHeader, 1, 0.6, 0, true)
    getglobal("GameTooltipTextLeft4"):SetText(infoHeader)
    getglobal("GameTooltipTextLeft4"):SetTextColor(1, 0.6, 0)
    getglobal("GameTooltipTextRight4"):SetText("")
    getglobal("GameTooltipTextRight4"):Hide()

    if info and info ~= "" then
      TurtleRP.gameTooltip:AddLine(wrappedInfo, 0.8, 0.8, 0.8, true)
      getglobal("GameTooltipTextLeft5"):SetText(wrappedInfo)
      getglobal("GameTooltipTextLeft5"):SetTextColor(0.8, 0.8, 0.8)
      getglobal("GameTooltipTextLeft5"):SetFont("Fonts\\FRIZQT__.ttf", 10)
      getglobal("GameTooltipTextRight5"):SetText("")
      getglobal("GameTooltipTextRight5"):Hide()
      l = 5
    else
      l = 4
    end
  end
  if icon ~= nil and icon ~= "" then
    TurtleRP_Tooltip_Icon:ClearAllPoints()
    TurtleRP_Tooltip_Icon:SetPoint("TOPLEFT", GameTooltipTextLeft1, "TOPLEFT", -2, 5)
    TurtleRP_Tooltip_Icon:SetFrameStrata("TOOLTIP")
    TurtleRP_Tooltip_Icon:SetFrameLevel(TurtleRP.gameTooltip:GetFrameLevel() + 10)
    TurtleRP_Tooltip_Icon_Icon:SetTexture(TurtleRP.GetIconTexture(icon))
    TurtleRP_Tooltip_Icon:Show()
  else
    TurtleRP_Tooltip_Icon:Hide()
  end
  if TurtleRP_Tooltip_Faction then
    TurtleRP_Tooltip_Faction:Hide()
  end
  TurtleRP_ClearTooltipLinesAfter(l + 1)
  TurtleRP_UpdateTooltipStatusBar(unit)
  TurtleRP.lastTooltipPetUID = petUID
  TurtleRP.gameTooltip:Show()
end

function TurtleRP.tooltip_events()
  local tooltipDefaults = {}
  local i

  for i = 1, 11 do
    local leftFont = getglobal("GameTooltipTextLeft" .. i)
    local rightFont = getglobal("GameTooltipTextRight" .. i)
    local lfontName, lfontHeight, lflag = leftFont:GetFont()
    tooltipDefaults["tooltipFontLeft" .. i .. "Name"] = lfontName
    tooltipDefaults["tooltipFontLeft" .. i .. "Height"] = lfontHeight
    tooltipDefaults["tooltipFontLeft" .. i .. "Flag"] = lflag
    local rfontName, rfontHeight, rflag = rightFont:GetFont()
    tooltipDefaults["tooltipFontRight" .. i .. "Name"] = rfontName
    tooltipDefaults["tooltipFontRight" .. i .. "Height"] = rfontHeight
    tooltipDefaults["tooltipFontRight" .. i .. "Flag"] = rflag
  end

  local function ResetTooltipFontsOnly()
    local j
    for j = 1, 11 do
      local left = getglobal("GameTooltipTextLeft" .. j)
      local right = getglobal("GameTooltipTextRight" .. j)

      left:SetFont(
        tooltipDefaults["tooltipFontLeft" .. j .. "Name"],
        tooltipDefaults["tooltipFontLeft" .. j .. "Height"],
        tooltipDefaults["tooltipFontLeft" .. j .. "Flag"]
      )
      right:SetFont(
        tooltipDefaults["tooltipFontRight" .. j .. "Name"],
        tooltipDefaults["tooltipFontRight" .. j .. "Height"],
        tooltipDefaults["tooltipFontRight" .. j .. "Flag"]
      )
      right:Hide()
    end
  end

  local function ClearTooltipTextForCustomBuild()
    local j
    for j = 1, 11 do
      local left = getglobal("GameTooltipTextLeft" .. j)
      local right = getglobal("GameTooltipTextRight" .. j)

      left:SetText("")
      right:SetText("")
      right:Hide()
    end
  end

  local function HideTooltipExtras(hideStatusBars)
    if TurtleRP_Tooltip_Icon then
      TurtleRP_Tooltip_Icon:Hide()
    end
    if TurtleRP_Tooltip_Faction then
      TurtleRP_Tooltip_Faction:Hide()
    end
    if hideStatusBars == nil or hideStatusBars then
      if GameTooltipStatusBar then
        GameTooltipStatusBar:Hide()
      end
      if pfUI and pfUI.tooltipStatusBar then
        pfUI.tooltipStatusBar:Hide()
      end
    end
  end

local function ApplyCustomTooltip()
  local unitName
  if TurtleRP.tooltipRefreshInProgress then
    return
  end
  if not UnitExists("mouseover") then
    HideTooltipExtras()
    return
  end
  if not TurtleRP.ShouldUseCustomTooltip() then
    return
  end
  if not TurtleRP.ShouldUseCustomTooltipForUnit("mouseover") then
    return
  end
  unitName = UnitName("mouseover")
  if not unitName or unitName == "" then
    return
  end
  ResetTooltipFontsOnly()
  ClearTooltipTextForCustomBuild()
  HideTooltipExtras()
  if UnitIsPlayer("mouseover") then
    TurtleRP.buildTooltip(unitName, "mouseover")
  else
    local cachedPetKey = TurtleRP.lastTooltipPetKey or nil
    TurtleRP.buildPetTooltip("mouseover", cachedPetKey)
  end
  TurtleRP.lastTooltipMode = "custom"
  TurtleRP.lastTooltipUnit = unitName
end

local function RestoreDefaultTooltip(forceRebuild)
  local unitName
  if not UnitExists("mouseover") then
    HideTooltipExtras(1)
    return
  end

  unitName = UnitName("mouseover")
  if not unitName or unitName == "" then
    HideTooltipExtras(1)
    return
  end

  HideTooltipExtras(false)
  ResetTooltipFontsOnly()
  if forceRebuild then
    TurtleRP.tooltipRefreshInProgress = true

    if TurtleRP.gameTooltip and TurtleRP.gameTooltip.ClearLines then
      TurtleRP.gameTooltip:ClearLines()
    end
    TurtleRP.gameTooltip:SetUnit("mouseover")
    TurtleRP.tooltipRefreshInProgress = nil
  end
  if pfUI and pfUI.tooltip and pfUI.tooltip.Update then
    pfUI.tooltip:Update()
  end
  if UnitExists("mouseover") then
    TurtleRP_UpdateTooltipStatusBar("mouseover")
  end
  TurtleRP.lastTooltipMode = "default"
  TurtleRP.lastTooltipUnit = unitName
end

  local defaultTooltipClearedScript = TurtleRP.gameTooltip:GetScript("OnTooltipCleared")
  TurtleRP.gameTooltip:SetScript("OnTooltipCleared", function()
    HideTooltipExtras()
    ResetTooltipFontsOnly()
    TurtleRP.lastTooltipMode = nil
    TurtleRP.lastTooltipUnit = nil
	TurtleRP.lastTooltipPetUID = nil
    TurtleRP.lastTooltipPetKey = nil
    if defaultTooltipClearedScript then
      defaultTooltipClearedScript()
    end
  end)

  local defaultTooltipUpdateScript = TurtleRP.gameTooltip:GetScript("OnUpdate")
  TurtleRP.gameTooltip:SetScript("OnUpdate", function()
    local currentUnitName
    local wantedMode
    local forceRebuild = nil

    if defaultTooltipUpdateScript then
      defaultTooltipUpdateScript()
    end
    if TurtleRP.tooltipRefreshInProgress then
      return
    end
    if not TurtleRP.gameTooltip:IsShown() then
      return
    end
    if not UnitExists("mouseover") then
      return
    end

    currentUnitName = UnitName("mouseover")
    wantedMode = "default"
    if TurtleRP.ShouldUseCustomTooltip() and TurtleRP.ShouldUseCustomTooltipForUnit("mouseover") then
      wantedMode = "custom"
    end

    if TurtleRP.lastTooltipUnit ~= currentUnitName or TurtleRP.lastTooltipMode ~= wantedMode then
      if wantedMode == "custom" then
        ApplyCustomTooltip()
      else
        forceRebuild = (TurtleRP.lastTooltipMode == "custom" and TurtleRP.lastTooltipUnit == currentUnitName)
        RestoreDefaultTooltip(forceRebuild)
      end
    end
  end)

  local defaultTooltipHideScript = TurtleRP.gameTooltip:GetScript("OnHide")
  TurtleRP.gameTooltip:SetScript("OnHide", function()
    HideTooltipExtras()
    ResetTooltipFontsOnly()
    TurtleRP.lastTooltipMode = nil
    TurtleRP.lastTooltipUnit = nil
	TurtleRP.lastTooltipPetUID = nil
    TurtleRP.lastTooltipPetKey = nil
    if defaultTooltipHideScript then
      defaultTooltipHideScript()
    end
  end)
end

function TurtleRP.getStatusText(currently_ic, ICOn, ICOff, whiteColor)
  local statusText = ""
  if currently_ic ~= nil then
    if currently_ic == "1" then
      statusText = " (" .. ICOn .. "IC" .. whiteColor .. ")"
    else
      statusText = " (" .. ICOff .. "OOC" .. whiteColor .. ")"
    end
  end
  return statusText
end

function TurtleRP.getPronounsText(pronouns, pronounColor)
  local pronounText = ""
  if pronouns ~= nil and pronouns ~= "" then
    pronounText = pronounColor .. " (" .. pronouns .. ")"
  end
  return pronounText
end

function TurtleRP.printICandOOC(info, headerText, blankLine, l)
  local n = l
  if info ~= nil and info ~= "" then
    n = n + 1
    TurtleRP.gameTooltip:AddLine(blankLine)
    getglobal("GameTooltipTextLeft"..n):SetText(blankLine)
    getglobal("GameTooltipTextLeft"..n):SetTextColor(1, 1, 1)
    getglobal("GameTooltipTextRight"..n):SetText("")
    getglobal("GameTooltipTextRight"..n):Hide()

    n = n + 1
    TurtleRP.gameTooltip:AddLine(headerText, 1, 0.6, 0, true)
    getglobal("GameTooltipTextLeft"..n):SetText(headerText)
    getglobal("GameTooltipTextLeft"..n):SetTextColor(1, 0.6, 0)
    getglobal("GameTooltipTextRight"..n):SetText("")
    getglobal("GameTooltipTextRight"..n):Hide()

    n = n + 1
    TurtleRP.gameTooltip:AddLine(info, 0.8, 0.8, 0.8, true)
    getglobal("GameTooltipTextLeft"..n):SetText(info)
    getglobal("GameTooltipTextLeft"..n):SetTextColor(0.8, 0.8, 0.8)
    getglobal("GameTooltipTextRight"..n):SetText("")
    getglobal("GameTooltipTextRight"..n):Hide()
    getglobal("GameTooltipTextLeft"..n):SetFont("Fonts\\FRIZQT__.ttf", 10)
  end
  return n
end

TurtleRP_ClearTooltipLines = function()
  local i
  for i = 1, 20 do
    local left = getglobal("GameTooltipTextLeft"..i)
    local right = getglobal("GameTooltipTextRight"..i)
    if left then
      left:SetText("")
      left:SetTextColor(1, 1, 1)
    end
    if right then
      right:SetText("")
      right:Hide()
      right:SetTextColor(1, 1, 1)
    end
  end
end

function TurtleRP_UpdateTooltipStatusBar(unit)
  if not GameTooltipStatusBar then
    return
  end

  local function HideFallbackText()
    if TurtleRP and TurtleRP.defaultTooltipStatusBarText then
      TurtleRP.defaultTooltipStatusBarText:Hide()
    end
    if GameTooltipStatusBar.backdrop and GameTooltipStatusBar.backdrop.health then
      GameTooltipStatusBar.backdrop.health:Hide()
    end
    if pfUI and pfUI.tooltipStatusBar and pfUI.tooltipStatusBar.HP then
      pfUI.tooltipStatusBar.HP:SetText("")
    end
  end

  if not unit or unit == "" or not UnitExists(unit) then
    GameTooltipStatusBar:Hide()
    if pfUI and pfUI.tooltipStatusBar then
      pfUI.tooltipStatusBar:Hide()
    end
    HideFallbackText()
    return
  end

  local hp = UnitHealth(unit)
  local hpMax = UnitHealthMax(unit)
  if not hp or not hpMax or hpMax <= 0 then
    GameTooltipStatusBar:Hide()
    if pfUI and pfUI.tooltipStatusBar then
      pfUI.tooltipStatusBar:Hide()
    end
    HideFallbackText()
    return
  end

  GameTooltipStatusBar:SetMinMaxValues(0, hpMax)
  GameTooltipStatusBar:SetValue(hp)

  if UnitIsPlayer(unit) then
    local colorR, colorG, colorB = nil, nil, nil
    local unitName = UnitName(unit)
    local characterInfo = unitName and TurtleRPCharacters and TurtleRPCharacters[unitName] or nil
    local useBlizzardClassColor = (IsAltKeyDown and IsAltKeyDown())
      or (TurtleRPSettings and TurtleRPSettings["disable_tooltip"] == "1")

    if not useBlizzardClassColor and characterInfo and characterInfo["class_color"] and characterInfo["class_color"] ~= "" and TurtleRP.hex2rgb then
      colorR, colorG, colorB = TurtleRP.hex2rgb(characterInfo["class_color"])
    else
      local _, classToken = UnitClass(unit)
      local color = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] or nil
      if color then
        colorR, colorG, colorB = color.r, color.g, color.b
      end
    end

    if colorR and colorG and colorB then
      if GameTooltipStatusBar.SetStatusBarColor_orig then
        GameTooltipStatusBar:SetStatusBarColor_orig(colorR, colorG, colorB)
      else
        GameTooltipStatusBar:SetStatusBarColor(colorR, colorG, colorB)
      end
      if GameTooltip.SetBackdropBorderColor then
        GameTooltip:SetBackdropBorderColor(colorR, colorG, colorB)
      end
    end
  else
    local reaction = nil
    if not (UnitPlayerControlled and UnitPlayerControlled(unit)) then
      reaction = UnitReaction(unit, "player")
    end

    local color = reaction and UnitReactionColor and UnitReactionColor[reaction] or nil
    if color then
      if GameTooltipStatusBar.SetStatusBarColor_orig then
        GameTooltipStatusBar:SetStatusBarColor_orig(color.r, color.g, color.b)
      else
        GameTooltipStatusBar:SetStatusBarColor(color.r, color.g, color.b)
      end
      if GameTooltip.SetBackdropBorderColor then
        GameTooltip:SetBackdropBorderColor(color.r, color.g, color.b)
      end
    end
  end

  local function AbbrevValue(value)
    if value >= 1000 then
      return string.format("%.1fk", value / 1000)
    end
    return tostring(value)
  end

  local hpText = AbbrevValue(hp) .. " / " .. AbbrevValue(hpMax)

  if pfUI and pfUI.tooltipStatusBar and pfUI.tooltipStatusBar.HP then
    pfUI.tooltipStatusBar.HP:SetText(hpText)
    pfUI.tooltipStatusBar.HP:Show()
    pfUI.tooltipStatusBar:Show()
    if GameTooltipStatusBar.backdrop and GameTooltipStatusBar.backdrop.health then
      GameTooltipStatusBar.backdrop.health:SetText("")
      GameTooltipStatusBar.backdrop.health:Hide()
    end
    if TurtleRP and TurtleRP.defaultTooltipStatusBarText then
      TurtleRP.defaultTooltipStatusBarText:Hide()
    end
    GameTooltipStatusBar:Show()
    return
  end

  if GameTooltipStatusBar.backdrop and not GameTooltipStatusBar.backdrop.health then
    GameTooltipStatusBar.backdrop.health = GameTooltipStatusBar.backdrop:CreateFontString("Status", "DIALOG", "GameFontWhite")
    GameTooltipStatusBar.backdrop.health:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    GameTooltipStatusBar.backdrop.health:SetPoint("TOP", 0, 4)
    GameTooltipStatusBar.backdrop.health:SetNonSpaceWrap(false)
  end

  if GameTooltipStatusBar.backdrop and GameTooltipStatusBar.backdrop.health then
    GameTooltipStatusBar.backdrop.health:SetText(hpText)
    GameTooltipStatusBar.backdrop.health:Show()
    if TurtleRP and TurtleRP.defaultTooltipStatusBarText then
      TurtleRP.defaultTooltipStatusBarText:Hide()
    end
  else
    if not TurtleRP.defaultTooltipStatusBarText then
      TurtleRP.defaultTooltipStatusBarText = GameTooltipStatusBar:CreateFontString(nil, "OVERLAY", "GameFontWhite")
      TurtleRP.defaultTooltipStatusBarText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
      TurtleRP.defaultTooltipStatusBarText:SetPoint("TOP", GameTooltipStatusBar, "TOP", 0, 4)
      TurtleRP.defaultTooltipStatusBarText:SetNonSpaceWrap(false)
    end
    TurtleRP.defaultTooltipStatusBarText:SetText(hpText)
    TurtleRP.defaultTooltipStatusBarText:Show()
  end

  GameTooltipStatusBar:Show()
end

local function TurtleRP_EnsureTooltipLine(index)
  local left = getglobal("GameTooltipTextLeft" .. index)

  while left and left:GetText() == nil do
    TurtleRP.gameTooltip:AddLine(" ")
    left = getglobal("GameTooltipTextLeft" .. index)
  end
end

function TurtleRP.buildTooltip(playerName, targetType)
  local characterInfo = TurtleRPCharacters[playerName]
  local locallyRetrievable = nil
  local liveName = targetType and UnitName(targetType) or playerName or ""
  local liveRace = targetType and UnitRace(targetType) or ""
  local liveClass = targetType and UnitClass(targetType) or ""
  local liveClassColor = (liveClass and TurtleRPClassData and TurtleRPClassData[liveClass] and TurtleRPClassData[liveClass][4]) or "ffffff"
  local queriedLevel = ""

  if characterInfo and characterInfo["keyM"] then
    locallyRetrievable = true
    if TurtleRP.NormalizeCharacterProfile then
      TurtleRP.NormalizeCharacterProfile(characterInfo)
    end
  end

  local nsfw            = locallyRetrievable and characterInfo["nsfw"] or nil
  local fullName        = locallyRetrievable and ((characterInfo["full_name"] and characterInfo["full_name"] ~= "") and characterInfo["full_name"] or liveName) or liveName
  if locallyRetrievable and characterInfo["title"] and characterInfo["title"] ~= "" then
    fullName = characterInfo["title"] .. " " .. fullName
  end
  local race            = locallyRetrievable and ((characterInfo["race"] and characterInfo["race"] ~= "") and characterInfo["race"] or liveRace) or liveRace
  local class           = locallyRetrievable and ((characterInfo["class"] and characterInfo["class"] ~= "") and characterInfo["class"] or liveClass) or liveClass
  local class_color     = locallyRetrievable and characterInfo['class_color'] or ((class and TurtleRPClassData and TurtleRPClassData[class] and TurtleRPClassData[class][4]) or "ffffff")
  local icon            = locallyRetrievable and characterInfo["icon"] or nil
  local currently_ic    = locallyRetrievable and characterInfo["currently_ic"] or nil
  local ic_info         = locallyRetrievable and characterInfo["ic_info"] or nil
  local ic_pronouns     = locallyRetrievable and characterInfo["ic_pronouns"] or nil
  local ooc_info        = locallyRetrievable and characterInfo["ooc_info"] or nil
  local ooc_pronouns    = locallyRetrievable and characterInfo["ooc_pronouns"] or nil
  local short_note      = locallyRetrievable and characterInfo["short_note"] or nil

  if targetType ~= nil then
    queriedLevel = UnitLevel(targetType)
  end

  local colorPrefix       = "|cff"
  local thisClassColor    = colorPrefix .. class_color
  local whiteColor        = colorPrefix .. "FFFFFF"
  local ICOn              = colorPrefix .. "40AF6F"
  local ICOff             = colorPrefix .. "D3681E"
  local pronounColor      = colorPrefix .. "ffcc80"

  local titleExtraSpaces  = (icon ~= nil and icon ~= "") and "       " or ""
  local guildExtraSpaces  = (icon ~= nil and icon ~= "") and "        " or ""
  if TurtleRP.shaguEnabled then
    guildExtraSpaces = (icon ~= nil and icon ~= "") and "          " or ""
  end
  local blankLine         = " "
  local statusText        = TurtleRP.getStatusText(currently_ic, ICOn, ICOff, whiteColor)
  local level             = queriedLevel == -1 and "??" or queriedLevel
  local levelAndStatusText= "Level " .. level .. statusText
  local raceAndClassText  = whiteColor .. race .. " " .. thisClassColor .. class
  local ICandPronounsText = "IC Info" .. TurtleRP.getPronounsText(ic_pronouns, pronounColor)
  local OOCandPronounsText= "OOC Info" .. TurtleRP.getPronounsText(ooc_pronouns, pronounColor)
  local ShortNoteText     = "Personal Note"

  if nsfw == "1" and TurtleRPSettings["show_nsfw"] == "0" then
     TurtleRP.gameTooltip:AddLine(blankLine)
     TurtleRP.gameTooltip:AddLine("NSFW RP Profile")
     TurtleRP.gameTooltip:AddLine("To view this profile, enable the 'Show NSFW'", 0.7, 0.7, 0.7)
     TurtleRP.gameTooltip:AddLine("option in TTRP settings.", 0.7, 0.7, 0.7)
     TurtleRP.gameTooltip:Show()
     return
  end

  TurtleRP.gameTooltip:ClearLines()
  TurtleRP_ClearTooltipLines()

  local l = 1
  local nameWrapPrefix = thisClassColor .. titleExtraSpaces
  local nameLine = nameWrapPrefix .. fullName
  nameLine = TurtleRP.WrapTooltipLine(nameLine, 34)

  local newlinePos = string.find(nameLine, "\n", 1, true)
  if newlinePos then
    local wrappedFirst = string.sub(nameLine, 1, newlinePos - 1)
    local wrappedSecond = string.sub(nameLine, newlinePos + 1)
    if wrappedSecond and wrappedSecond ~= "" then
      nameLine = wrappedFirst .. "\n" .. nameWrapPrefix .. wrappedSecond
    end
  end

  TurtleRP.gameTooltip:AddLine(nameLine)
  if TurtleRPSettings["name_size"] == "1" then
    getglobal("GameTooltipTextLeft1"):SetFont("Fonts\\FRIZQT__.ttf", 18)
  else
    getglobal("GameTooltipTextLeft1"):SetFont("Fonts\\FRIZQT__.ttf", 15)
  end
  getglobal("GameTooltipTextLeft"..l):SetText(nameLine)

  l = l + 1
  TurtleRP.gameTooltip:AddLine(blankLine)
  getglobal("GameTooltipTextLeft"..l):SetText(blankLine)
  getglobal("GameTooltipTextRight"..l):SetText("")
  getglobal("GameTooltipTextRight"..l):Hide()

  l = l + 1
  local guildDisplay = TurtleRP.GetGuildDisplayString(playerName, locallyRetrievable and characterInfo or nil)
  if guildDisplay then
    TurtleRP.gameTooltip:AddDoubleLine("", guildDisplay)
    local guildLine = guildExtraSpaces .. guildDisplay
    guildLine = TurtleRP.WrapTooltipLine(guildLine, 46)
    local guildLeft = getglobal("GameTooltipTextLeft"..l)
    local guildRight = getglobal("GameTooltipTextRight"..l)
    guildLeft:SetText("")
    guildRight:Show()
    guildRight:SetText(guildLine)
    guildRight:SetJustifyH("RIGHT")
    l = l + 1
  else
    TurtleRP.gameTooltip:AddLine(blankLine)
    getglobal("GameTooltipTextLeft"..l):SetText(blankLine)
    getglobal("GameTooltipTextRight"..l):SetText("")
    getglobal("GameTooltipTextRight"..l):Hide()
    if guildExtraSpaces ~= "" then
      l = l + 1
      TurtleRP.gameTooltip:AddLine(blankLine)
      getglobal("GameTooltipTextLeft"..l):SetText(blankLine)
      getglobal("GameTooltipTextRight"..l):SetText("")
      getglobal("GameTooltipTextRight"..l):Hide()
    end
  end

  TurtleRP.gameTooltip:AddLine(blankLine)
  getglobal("GameTooltipTextLeft"..l):SetText(blankLine)
  getglobal("GameTooltipTextRight"..l):SetText("")
  getglobal("GameTooltipTextRight"..l):Hide()

  l = l + 1
  TurtleRP.gameTooltip:AddDoubleLine(raceAndClassText, levelAndStatusText)
  getglobal("GameTooltipTextLeft"..l):SetText(raceAndClassText)
  getglobal("GameTooltipTextRight"..l):Show()
  getglobal("GameTooltipTextRight"..l):SetText(levelAndStatusText)

  l = l + 1
  TurtleRP.gameTooltip:AddLine(blankLine)
  getglobal("GameTooltipTextLeft"..l):SetText(blankLine)
  getglobal("GameTooltipTextRight"..l):SetText("")
  getglobal("GameTooltipTextRight"..l):Hide()

  l = l + 1
  TurtleRP.gameTooltip:AddDoubleLine("", "")
  getglobal("GameTooltipTextLeft"..l):SetText("")

  if TurtleRP.IsDevProfile(playerName) then
    getglobal("GameTooltipTextRight"..l):Show()
    getglobal("GameTooltipTextRight"..l):SetText(TurtleRP.GetDevBadgeText())
  elseif nsfw == "1" then
    getglobal("GameTooltipTextRight"..l):Show()
    getglobal("GameTooltipTextRight"..l):SetText("|cffff4444[NSFW]")
  else
    getglobal("GameTooltipTextRight"..l):SetText("")
    getglobal("GameTooltipTextRight"..l):Hide()
  end

  if locallyRetrievable then
    l = TurtleRP.printICandOOC(ic_info, ICandPronounsText, blankLine, l)
    l = TurtleRP.printICandOOC(ooc_info, OOCandPronounsText, blankLine, l)
    l = TurtleRP.printICandOOC(short_note, ShortNoteText, blankLine, l)

    if icon ~= nil and icon ~= "" then
      TurtleRP_Tooltip_Icon:ClearAllPoints()
      TurtleRP_Tooltip_Icon:SetPoint("TOPLEFT", GameTooltipTextLeft1, "TOPLEFT", -2, 2)
      TurtleRP_Tooltip_Icon:SetFrameStrata("TOOLTIP")
      TurtleRP_Tooltip_Icon:SetFrameLevel(TurtleRP.gameTooltip:GetFrameLevel() + 10)
      TurtleRP_Tooltip_Icon_Icon:SetTexture(TurtleRP.GetIconTexture(icon))
      TurtleRP_Tooltip_Icon:Show()
    else
      TurtleRP_Tooltip_Icon:Hide()
    end

    do
      local factionKey = characterInfo and characterInfo["faction"] or TurtleRP.getFactionDefault()
      local factionTex = TurtleRP.getFactionTooltipIcon(factionKey)
      if factionTex and TurtleRP_Tooltip_Faction and TurtleRP_Tooltip_Faction_Icon then
        TurtleRP_Tooltip_Faction:ClearAllPoints()
        TurtleRP_Tooltip_Faction:SetPoint("BOTTOMRIGHT", TurtleRP.gameTooltip, "BOTTOMRIGHT", -6, 6)
        TurtleRP_Tooltip_Faction:SetFrameStrata("TOOLTIP")
        TurtleRP_Tooltip_Faction:SetFrameLevel(TurtleRP.gameTooltip:GetFrameLevel() + 1)
        TurtleRP_Tooltip_Faction_Icon:SetTexture(factionTex)
        TurtleRP_Tooltip_Faction_Icon:SetAlpha(0.16)
        TurtleRP_Tooltip_Faction:Show()
      elseif TurtleRP_Tooltip_Faction then
        TurtleRP_Tooltip_Faction:Hide()
      end
    end
  end
  TurtleRP_ClearTooltipLinesAfter(l + 1)
  if targetType and UnitExists(targetType) then
    TurtleRP_UpdateTooltipStatusBar(targetType)
  end
  TurtleRP.gameTooltip:Show()
end
