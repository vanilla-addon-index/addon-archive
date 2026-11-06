--[[
  Created by Vee (http://victortemprano.com), Drixi in-game
  See Github repo at https://github.com/tempranova/turtlerp
]]

local function TurtleRP_PrepareProfileOpen()
  CloseDropDownMenus()
end


function TurtleRP.OpenProfile(openTo)
  TurtleRP.ForceCloseMap()
  TurtleRP.currentlyViewedPetUID = nil
  TurtleRP_CharacterDetails_FrameTabButton1.bookType = "general"
  TurtleRP_CharacterDetails_FrameTabButton2.bookType = "description"
  TurtleRP_CharacterDetails_FrameTabButton3.bookType = "notes"
  if not TurtleRP.currentlyViewedPlayer or TurtleRP.currentlyViewedPlayer == "" then
    TurtleRP.currentlyViewedPlayer = UnitName("player")
  end
  UIPanelWindows["TurtleRP_CharacterDetails"] = { area = "left", pushable = 6 }
  TurtleRP_PrepareProfileOpen()
  ShowUIPanel(TurtleRP_CharacterDetails)
  TurtleRP.OnBottomTabProfileClick(openTo)
end

function TurtleRP.OpenProfilePreview(openTo)
  TurtleRP.ForceCloseMap()
  TurtleRP.currentlyViewedPetUID = nil
  TurtleRP_CharacterDetails_FrameTabButton1.bookType = "general"
  TurtleRP_CharacterDetails_FrameTabButton2.bookType = "description"
  TurtleRP_CharacterDetails_FrameTabButton3.bookType = "notes"

  if not TurtleRP.currentlyViewedPlayer or TurtleRP.currentlyViewedPlayer == "" then
    TurtleRP.currentlyViewedPlayer = UnitName("player")
  end

  TurtleRP_CharacterDetails:ClearAllPoints()
  if TurtleRP_AdminSB and TurtleRP_AdminSB:IsShown() then
    TurtleRP_CharacterDetails:SetPoint("TOPLEFT", TurtleRP_AdminSB, "TOPRIGHT", 20, 0)
    TurtleRP_CharacterDetails:SetPoint("BOTTOMLEFT", TurtleRP_AdminSB, "BOTTOMRIGHT", 20, 0)
    TurtleRP_CharacterDetails:SetWidth(384)
    TurtleRP_CharacterDetails:SetHeight(TurtleRP_AdminSB:GetHeight())
    TurtleRP_PrepareProfileOpen()
    TurtleRP_CharacterDetails:Show()
  else
    UIPanelWindows["TurtleRP_CharacterDetails"] = { area = "left", pushable = 6 }
    TurtleRP_PrepareProfileOpen()
    ShowUIPanel(TurtleRP_CharacterDetails)
  end

  TurtleRP.OnBottomTabProfileClick(openTo or "general")
end

function TurtleRP.OnBottomTabProfileClick(bookType)
  TurtleRP.currentProfileTab = bookType or "general"

  TurtleRP_CharacterDetails_General:Hide()
  TurtleRP_CharacterDetails_DescriptionScrollBox:Hide()
  TurtleRP_CharacterDetails_Notes:Hide()

  if TurtleRP_CharacterDetails_LinkButton then
    TurtleRP_CharacterDetails_LinkButton.linkValue = nil
    TurtleRP_CharacterDetails_LinkButton:Hide()
  end

  if TurtleRP.currentlyViewedPetUID and TurtleRP.currentlyViewedPetUID ~= "" then
    if TurtleRP.currentProfileTab == "general" then
      TurtleRP.buildPetGeneral(TurtleRP.currentlyViewedPetUID)
    end
    if TurtleRP.currentProfileTab == "description" then
      TurtleRP.buildPetDescription(TurtleRP.currentlyViewedPetUID)
    end
    if TurtleRP.currentProfileTab == "notes" then
      TurtleRP.buildPetNotes(TurtleRP.currentlyViewedPetUID)
    end
    return
  end

  if TurtleRP.currentProfileTab == "general" then
    TurtleRP.buildGeneral(TurtleRP.currentlyViewedPlayer)
  end
  if TurtleRP.currentProfileTab == "description" then
    TurtleRP.buildDescription(TurtleRP.currentlyViewedPlayer)
  end
  if TurtleRP.currentProfileTab == "notes" then
    TurtleRP.buildNotes(TurtleRP.currentlyViewedPlayer)
  end
end

local TurtleRP_TextMeasureFrame = nil
local TurtleRP_TextMeasureFontString = nil

local function TurtleRP_StripColorCodes(text)
  local stripped = text or ""
  stripped = gsub(stripped, "|c%x%x%x%x%x%x%x%x", "")
  stripped = gsub(stripped, "|r", "")
  return stripped
end

local function TurtleRP_GetMeasureFontString(frame)
  if not TurtleRP_TextMeasureFrame then
    TurtleRP_TextMeasureFrame = CreateFrame("Frame", nil, UIParent)
    TurtleRP_TextMeasureFrame:Hide()
    TurtleRP_TextMeasureFontString = TurtleRP_TextMeasureFrame:CreateFontString(nil, "ARTWORK")
    TurtleRP_TextMeasureFontString:Hide()
  end

  if frame and frame.GetFontObject and frame:GetFontObject() then
    TurtleRP_TextMeasureFontString:SetFontObject(frame:GetFontObject())
  end

  return TurtleRP_TextMeasureFontString
end

local function TurtleRP_GetVisibleTextWidth(frame, text)
  local measure = TurtleRP_GetMeasureFontString(frame)
  measure:SetWidth(0)
  measure:SetText(TurtleRP_StripColorCodes(text))
  return measure:GetStringWidth() or 0
end

local function TurtleRP_GetWrappedTextHeight(frame, text, width)
  local measure = TurtleRP_GetMeasureFontString(frame)
  measure:SetWidth(width or 0)
  measure:SetJustifyH("LEFT")
  measure:SetJustifyV("TOP")
  measure:SetNonSpaceWrap(true)
  measure:SetText(TurtleRP_StripColorCodes(text))
  return measure:GetHeight() or 0
end

function TurtleRP.ShowOrHideProfileDetails(lastFrame, characterInfo, frame, stringToShow, overrideHide)
  if not frame then
    return lastFrame
  end

  local frameHidden = false
  if characterInfo["keyM"] == nil or overrideHide == true or stringToShow == nil or stringToShow == "" then
    frame:Hide()
    frameHidden = true
  else
    frame:Show()
    frame:SetText(stringToShow)
    local wrappedHeight = TurtleRP_GetWrappedTextHeight(frame, stringToShow, 265)
    local targetHeight = math.max(10, math.ceil(wrappedHeight))
    frame:SetHeight(targetHeight)
  end

	if lastFrame ~= nil then
	  if frame == TurtleRP_CharacterDetails_General_Guild then
		frame:ClearAllPoints()

		if frameHidden then
		  frame:SetPoint("TOPRIGHT", lastFrame, "BOTTOMRIGHT", 0, 0)
		  return lastFrame
		end

		frame:SetPoint("TOPRIGHT", lastFrame, "BOTTOMRIGHT", 0, -7)
		frame:SetJustifyH("RIGHT")
		return frame
	  end

	  if frameHidden then
		frame:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT", 0, 0)
		return lastFrame
	  end

	  frame:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT", 0, -7)
	end

  return frame
end

local function TurtleRP_GetStyleDisplayValue(category, value)
  if not value or value == "" or value == "0" or value == "z" then
    return nil
  end
  if not TurtleRPDropdownOptions[category] then
    return nil
  end
  return TurtleRPDropdownOptions[category][value]
end

function TurtleRP.buildGeneral(playerName)
  playerName = playerName or TurtleRP.currentlyViewedPlayer or UnitName("player")
  TurtleRP.currentlyViewedPlayer = playerName
  TurtleRP.currentProfileTab = "general"

  TurtleRP_CharacterDetails_DescriptionScrollBox:Hide()
  TurtleRP_CharacterDetails_Notes:Hide()

  local characterInfo = TurtleRP.previewCharacterInfo or TurtleRPCharacters[playerName]
  if characterInfo and TurtleRP.NormalizeCharacterProfile then
    TurtleRP.NormalizeCharacterProfile(characterInfo)
  end
  TurtleRP.SetNameAndIcon(playerName, characterInfo)
  if not characterInfo then
    return
  end
  local raceClassString = ""
  if characterInfo["keyM"] ~= nil then
    local classColor = TurtleRP.GetEffectiveClassColorHex(playerName, characterInfo)
    local raceText = characterInfo["race"] or ""
    local classText = characterInfo["class"] or ""
    if raceText == "" and playerName == UnitName("player") then
      raceText = UnitRace("player") or ""
    end
    if classText == "" and playerName == UnitName("player") then
      classText = UnitClass("player") or ""
    end
    if classColor and classColor ~= "" then
      raceClassString = raceText .. "|cff" .. classColor .. " " .. classText
    else
      raceClassString = raceText .. " " .. classText
    end
  end

  local lastFrame = nil
  lastFrame = TurtleRP.ShowOrHideProfileDetails(lastFrame, characterInfo, TurtleRP_CharacterDetails_General_TargetRaceClass, raceClassString)
  TurtleRP.ShowOrHideProfileDetails(nil, characterInfo, TurtleRP_CharacterDetails_General_ICOOC, characterInfo["currently_ic"] == "1" and "|cff40AF6FIC" or "|cffD3681EOOC")
  lastFrame = TurtleRP.ShowOrHideProfileDetails(
    lastFrame,
    characterInfo,
    TurtleRP_CharacterDetails_General_Guild,
    TurtleRP.GetGuildDisplayString(playerName, characterInfo)
  )

  lastFrame = TurtleRP.ShowOrHideProfileDetails(
    lastFrame,
    characterInfo,
    TurtleRP_CharacterDetails_General_ICInfo,
    "|cffCC9900IC Info" .. TurtleRP.getPronounsText(characterInfo["ic_pronouns"], "|cffffcc80"),
    characterInfo["ic_info"] == nil or characterInfo["ic_info"] == ""
  )

  if TurtleRP.IsDevProfile(playerName) then
    TurtleRP_CharacterDetails_General_DevText:SetText(TurtleRP.GetDevBadgeText())
    TurtleRP_CharacterDetails_General_DevText:Show()
    TurtleRP_CharacterDetails_General_DevText:ClearAllPoints()
    TurtleRP_CharacterDetails_General_DevText:SetPoint("TOPRIGHT", TurtleRP_CharacterDetails_General_ICInfo, "TOPRIGHT", 0, 0)
  else
    TurtleRP_CharacterDetails_General_DevText:SetText("")
    TurtleRP_CharacterDetails_General_DevText:Hide()
  end
-- NSFW indicator
TurtleRP_CharacterDetails_General_NSFW:Hide()
TurtleRP_CharacterDetails_General_NSFW:ClearAllPoints()

if characterInfo["nsfw"] == "1" then
  if TurtleRP.IsDevProfile(playerName) then
    TurtleRP_CharacterDetails_General_NSFW:SetPoint("RIGHT", TurtleRP_CharacterDetails_General_DevText, "LEFT", -6, 0)
  else
    TurtleRP_CharacterDetails_General_NSFW:SetPoint("RIGHT", TurtleRP_CharacterDetails_General_ICInfo, "RIGHT", 0, 0)
  end
  TurtleRP_CharacterDetails_General_NSFW:Show()
end
  lastFrame = TurtleRP.ShowOrHideProfileDetails(lastFrame, characterInfo, TurtleRP_CharacterDetails_General_ICInfoText, characterInfo["ic_info"])
  lastFrame = TurtleRP.ShowOrHideProfileDetails(lastFrame, characterInfo, TurtleRP_CharacterDetails_General_OOCInfo, "|cffCC9900OOC Info" .. TurtleRP.getPronounsText(characterInfo["ooc_pronouns"], "|cffffcc80"), characterInfo["ooc_info"] == nil or characterInfo["ooc_info"] == "")
  lastFrame = TurtleRP.ShowOrHideProfileDetails(lastFrame, characterInfo, TurtleRP_CharacterDetails_General_OOCInfoText, characterInfo["ooc_info"])

  TurtleRP_CharacterDetails_General_DarkBack:SetPoint("BOTTOMLEFT", lastFrame, "BOTTOMLEFT", 0, -10)

local styleRows = {
  {
    label = TurtleRP_CharacterDetails_General_ExperienceText,
    value = TurtleRP_CharacterDetails_General_Experience,
    text = "Experience",
    display = TurtleRP_GetStyleDisplayValue("experience", characterInfo["experience"])
  },
  {
    label = TurtleRP_CharacterDetails_General_WalkupsText,
    value = TurtleRP_CharacterDetails_General_Walkups,
    text = "Walk-Ups",
    display = TurtleRP_GetStyleDisplayValue("walkups", characterInfo["walkups"])
  },
  {
    label = TurtleRP_CharacterDetails_General_CombatText,
    value = TurtleRP_CharacterDetails_General_Combat,
    text = "Combat",
    display = TurtleRP_GetStyleDisplayValue("combat", characterInfo["combat"])
  },
  {
    label = TurtleRP_CharacterDetails_General_InjuryText,
    value = TurtleRP_CharacterDetails_General_Injury,
    text = "Injury",
    display = TurtleRP_GetStyleDisplayValue("injury", characterInfo["injury"])
  },
  {
    label = TurtleRP_CharacterDetails_General_RomanceText,
    value = TurtleRP_CharacterDetails_General_Romance,
    text = "Romance",
    display = TurtleRP_GetStyleDisplayValue("romance", characterInfo["romance"])
  },
  {
    label = TurtleRP_CharacterDetails_General_DeathText,
    value = TurtleRP_CharacterDetails_General_Death,
    text = "Death",
    display = TurtleRP_GetStyleDisplayValue("death", characterInfo["death"])
  }
}
local lastStyleLabel = nil
local lastStyleValue = nil
for _, row in ipairs(styleRows) do
  local hideRow = row.display == nil or row.display == ""

  lastStyleLabel = TurtleRP.ShowOrHideProfileDetails(
    lastStyleLabel,
    characterInfo,
    row.label,
    row.text,
    hideRow
  )
  lastStyleValue = TurtleRP.ShowOrHideProfileDetails(
    lastStyleValue,
    characterInfo,
    row.value,
    row.display,
    hideRow
  )
end

  TurtleRP_CharacterDetails_General_AtAGlance1:Hide()
  TurtleRP_CharacterDetails_General_AtAGlance2:Hide()
  TurtleRP_CharacterDetails_General_AtAGlance3:Hide()
  if characterInfo["keyT"] ~= nil then
    if characterInfo["atAGlance1Icon"] and characterInfo["atAGlance1Icon"] ~= "" then
      local iconIndex = characterInfo["atAGlance1Icon"]
      local tex = TurtleRP.GetIconTexture(iconIndex)
      TurtleRP_CharacterDetails_General_AtAGlance1_Icon:SetTexture(tex)
      TurtleRP_CharacterDetails_General_AtAGlance1_TextPanel_TitleText:SetText(characterInfo["atAGlance1Title"])
      TurtleRP_CharacterDetails_General_AtAGlance1_TextPanel_Text:SetText(characterInfo["atAGlance1"])
      TurtleRP_CharacterDetails_General_AtAGlance1:Show()
      TurtleRP_CharacterDetails_General_DarkBack:SetPoint("BOTTOMLEFT", TurtleRP_CharacterDetails_General_OOCInfoText, "BOTTOMLEFT", 0, -40)
    end

    if characterInfo["atAGlance2Icon"] and characterInfo["atAGlance2Icon"] ~= "" then
      local iconIndex = characterInfo["atAGlance2Icon"]
      local tex = TurtleRP.GetIconTexture(iconIndex)
      TurtleRP_CharacterDetails_General_AtAGlance2_Icon:SetTexture(tex)
      TurtleRP_CharacterDetails_General_AtAGlance2_TextPanel_TitleText:SetText(characterInfo["atAGlance2Title"])
      TurtleRP_CharacterDetails_General_AtAGlance2_TextPanel_Text:SetText(characterInfo["atAGlance2"])
      TurtleRP_CharacterDetails_General_AtAGlance2:Show()
      TurtleRP_CharacterDetails_General_DarkBack:SetPoint("BOTTOMLEFT", TurtleRP_CharacterDetails_General_OOCInfoText, "BOTTOMLEFT", 0, -40)
    end

    if characterInfo["atAGlance3Icon"] and characterInfo["atAGlance3Icon"] ~= "" then
      local iconIndex = characterInfo["atAGlance3Icon"]
      local tex = TurtleRP.GetIconTexture(iconIndex)
      TurtleRP_CharacterDetails_General_AtAGlance3_Icon:SetTexture(tex)
      TurtleRP_CharacterDetails_General_AtAGlance3_TextPanel_TitleText:SetText(characterInfo["atAGlance3Title"])
      TurtleRP_CharacterDetails_General_AtAGlance3_TextPanel_Text:SetText(characterInfo["atAGlance3"])
      TurtleRP_CharacterDetails_General_AtAGlance3:Show()
      TurtleRP_CharacterDetails_General_DarkBack:SetPoint("BOTTOMLEFT", TurtleRP_CharacterDetails_General_OOCInfoText, "BOTTOMLEFT", 0, -40)
    end

  end

  TurtleRP_CharacterDetails_FrameTabButton1:SetNormalTexture("Interface\\Spellbook\\UI-SpellBook-Tab1-Selected")
  TurtleRP_CharacterDetails_FrameTabButton2:SetNormalTexture("Interface\\Spellbook\\UI-Spellbook-Tab-Unselected")
  TurtleRP_CharacterDetails_FrameTabButton3:SetNormalTexture("Interface\\Spellbook\\UI-SpellBook-Tab-Unselected")

  TurtleRP_CharacterDetails_General:Show()
end

function TurtleRP.ShowDescriptionLinkPopup(link)
  TurtleRP.pendingDescriptionLink = link or ""
  StaticPopup_Show("TTRP_DESCRIPTION_LINK")
  if StaticPopup1EditBox then
    StaticPopup1EditBox:SetText(TurtleRP.pendingDescriptionLink or "")
    StaticPopup1EditBox:HighlightText()
    StaticPopup1EditBox:SetFocus()
  end
end

function TurtleRP.UpdateDescriptionLinkButton(characterInfo)
  local button = TurtleRP_CharacterDetails_LinkButton
  if not button then
    return
  end
  local linkText = characterInfo and characterInfo["description_link_text"] or ""
  local link = characterInfo and characterInfo["description_link"] or ""
  if linkText and linkText ~= "" and link and link ~= "" then
    button:SetText(linkText)
    button.linkValue = link
    button:Show()
  else
    button.linkValue = nil
    button:Hide()
  end
end

function TurtleRP.buildDescription(playerName)
  playerName = playerName or TurtleRP.currentlyViewedPlayer or UnitName("player")
  TurtleRP.currentlyViewedPlayer = playerName
  TurtleRP.currentProfileTab = "description"
  local characterInfo = TurtleRP.previewCharacterInfo or TurtleRPCharacters[playerName]
  if characterInfo and TurtleRP.NormalizeCharacterProfile then
    TurtleRP.NormalizeCharacterProfile(characterInfo)
  end
  if not characterInfo then
    return
  end
  TurtleRP_CharacterDetails_General:Hide()
  TurtleRP_CharacterDetails_Notes:Hide()
  local htmlFrame = TurtleRP_CharacterDetails_DescriptionScrollBox_DescriptionHolder_DescriptionHTML
  local plainTextFrame = TurtleRP_CharacterDetails_DescriptionScrollBox_DescriptionHolder_DescriptionHTML_TargetDescription
  local holderFrame = TurtleRP_CharacterDetails_DescriptionScrollBox_DescriptionHolder
  htmlFrame:SetText("")
  plainTextFrame:SetText("")
  holderFrame:SetHeight(50)
  if characterInfo["keyD"] ~= nil then
    TurtleRP.SetNameAndIcon(playerName, characterInfo)
    TurtleRP.UpdateDescriptionLinkButton(characterInfo)
    holderFrame:ClearAllPoints()
    holderFrame:SetPoint("TOPLEFT", TurtleRP_CharacterDetails_DescriptionScrollBox, "TOPLEFT", 0, 0)
    local descriptionText = characterInfo["description"] or ""
    if TurtleRP.DescriptionHasSupportedMarkup(descriptionText) then
      htmlFrame:SetHeight(1000)
      holderFrame:SetHeight(1000)
      htmlFrame:SetText(TurtleRP.SanitizeDescriptionHTML(descriptionText))
      plainTextFrame:SetText("")
    else
      local plainText = TurtleRP.NormalizePlainDescription(descriptionText)
      htmlFrame:SetText("")
      plainTextFrame:SetText(plainText or "")

      if plainText == nil or plainText == "" then
        holderFrame:SetHeight(50)
      else
        local textHeight = plainTextFrame:GetHeight() or 0
        holderFrame:SetHeight(math.max(50, textHeight + 20))
      end
    end
  end
  TurtleRP_CharacterDetails_DescriptionScrollBox:Show()
  if TurtleRP_CharacterDetails_DescriptionScrollBox.SetVerticalScroll then
    TurtleRP_CharacterDetails_DescriptionScrollBox:SetVerticalScroll(0)
  end
  if TurtleRP_CharacterDetails_DescriptionScrollBoxScrollBar and TurtleRP_CharacterDetails_DescriptionScrollBoxScrollBar.SetValue then
    TurtleRP_CharacterDetails_DescriptionScrollBoxScrollBar:SetValue(0)
  end
  TurtleRP_CharacterDetails_FrameTabButton1:SetNormalTexture("Interface\\Spellbook\\UI-SpellBook-Tab-Unselected")
  TurtleRP_CharacterDetails_FrameTabButton2:SetNormalTexture("Interface\\Spellbook\\UI-Spellbook-Tab1-Selected")
  TurtleRP_CharacterDetails_FrameTabButton3:SetNormalTexture("Interface\\Spellbook\\UI-SpellBook-Tab-Unselected")
end

function TurtleRP.buildNotes(playerName)
  playerName = playerName or TurtleRP.currentlyViewedPlayer or UnitName("player")
  TurtleRP.currentlyViewedPlayer = playerName
  TurtleRP.currentProfileTab = "notes"

  TurtleRP_CharacterDetails_General:Hide()
  TurtleRP_CharacterDetails_DescriptionScrollBox:Hide()

  local characterInfo = TurtleRPCharacters[playerName]
  if characterInfo and TurtleRP.NormalizeCharacterProfile then
    TurtleRP.NormalizeCharacterProfile(characterInfo)
  end
  if not characterInfo then
    return
  end
  TurtleRP.SetNameAndIcon(playerName)
  if playerName == UnitName("player") then
    TurtleRP_CharacterDetails_Notes_NotesScrollBox_NotesContent_NotesInput:SetText(
      TurtleRPCharacterInfo["notes"] or ""
    )
    TurtleRP_CharacterDetails_Notes_ShortNoteBox_Input:SetText(
      TurtleRPCharacterInfo["short_note"] or ""
    )
    TurtleRP_CharacterDetails_Notes_DisableRPColorButton:Hide()
    TurtleRP_CharacterDetails_Notes_DisableRPColorText:Hide()
  else
    if TurtleRPCharacterInfo["character_notes"][TurtleRP.currentlyViewedPlayer] ~= nil then
      TurtleRP_CharacterDetails_Notes_NotesScrollBox_NotesContent_NotesInput:SetText(
        TurtleRPCharacterInfo["character_notes"][TurtleRP.currentlyViewedPlayer]
      )
    else
      TurtleRP_CharacterDetails_Notes_NotesScrollBox_NotesContent_NotesInput:SetText("")
    end
    if TurtleRPCharacterInfo["character_short_notes"]
      and TurtleRPCharacterInfo["character_short_notes"][TurtleRP.currentlyViewedPlayer] ~= nil then
      TurtleRP_CharacterDetails_Notes_ShortNoteBox_Input:SetText(
        TurtleRPCharacterInfo["character_short_notes"][TurtleRP.currentlyViewedPlayer]
      )
    else
      TurtleRP_CharacterDetails_Notes_ShortNoteBox_Input:SetText("")
    end
    TurtleRP_CharacterDetails_Notes_DisableRPColorButton:SetChecked(
      TurtleRP.IsRPColorDisabledForPlayer(playerName)
    )
    TurtleRP_CharacterDetails_Notes_DisableRPColorButton:Show()
    TurtleRP_CharacterDetails_Notes_DisableRPColorText:Show()
  end
  TurtleRP_CharacterDetails_Notes:Show()
  TurtleRP_CharacterDetails_FrameTabButton1:SetNormalTexture("Interface\\Spellbook\\UI-Spellbook-Tab-Unselected")
  TurtleRP_CharacterDetails_FrameTabButton2:SetNormalTexture("Interface\\Spellbook\\UI-Spellbook-Tab-Unselected")
  TurtleRP_CharacterDetails_FrameTabButton3:SetNormalTexture("Interface\\Spellbook\\UI-SpellBook-Tab1-Selected")
end

function TurtleRP.OpenPetProfile(petUID, openTo)
  local useCenterArea = nil
  TurtleRP.currentlyViewedPetUID = petUID
  TurtleRP.currentlyViewedPlayer = nil
  TurtleRP_CharacterDetails_FrameTabButton1.bookType = "general"
  TurtleRP_CharacterDetails_FrameTabButton2.bookType = "description"
  TurtleRP_CharacterDetails_FrameTabButton3.bookType = "notes"
  useCenterArea = (pfUI == nil and WorldMapFrame and WorldMapFrame:IsVisible())
  if useCenterArea then
    UIPanelWindows["TurtleRP_CharacterDetails"] = { area = "center", pushable = 0 }
  else
    UIPanelWindows["TurtleRP_CharacterDetails"] = { area = "left", pushable = 6 }
  end
  TurtleRP_PrepareProfileOpen()
  ShowUIPanel(TurtleRP_CharacterDetails)
  TurtleRP.OnBottomTabProfileClick(openTo or "general")
end


function TurtleRP.buildPetGeneral(petUID)
  local petProfile = (TurtleRP.previewSource == "pet_admin" and TurtleRP.previewCharacterInfo)
  or (TurtleRP.GetAssignedPetProfile and TurtleRP.GetAssignedPetProfile(petUID))
  or nil
  local lastFrame = nil
  local speciesLevelText = ""
  local hasSpeciesLevel = nil

  TurtleRP.currentlyViewedPetUID = petUID
  TurtleRP.currentlyViewedPlayer = nil
  TurtleRP.currentProfileTab = "general"

  TurtleRP_CharacterDetails_DescriptionScrollBox:Hide()
  TurtleRP_CharacterDetails_Notes:Hide()

  TurtleRP.SetNameAndIcon(nil, petProfile)
  if not petProfile then
    return
  end
  if petProfile["level"] and petProfile["level"] ~= "" and petProfile["species"] and petProfile["species"] ~= "" then
    speciesLevelText = "Level " .. petProfile["level"] .. " " .. petProfile["species"]
    hasSpeciesLevel = true
  elseif petProfile["species"] and petProfile["species"] ~= "" then
    speciesLevelText = petProfile["species"]
    hasSpeciesLevel = true
  elseif petProfile["level"] and petProfile["level"] ~= "" then
    speciesLevelText = "Level " .. petProfile["level"]
    hasSpeciesLevel = true
  end
  lastFrame = TurtleRP.ShowOrHideProfileDetails(lastFrame, { keyM = "1" }, TurtleRP_CharacterDetails_General_TargetRaceClass, speciesLevelText, not hasSpeciesLevel)
  TurtleRP_CharacterDetails_General_ICOOC:Hide()
  TurtleRP_CharacterDetails_General_Guild:Hide()
  lastFrame = TurtleRP.ShowOrHideProfileDetails(
    lastFrame,
    { keyM = "1" },
    TurtleRP_CharacterDetails_General_ICInfo,
    "|cffCC9900Info" .. TurtleRP.getPronounsText(petProfile["pronouns"], "|cffffcc80"),
    petProfile["info"] == nil or petProfile["info"] == ""
  )

  TurtleRP_CharacterDetails_General_DevText:Hide()
  lastFrame = TurtleRP.ShowOrHideProfileDetails(lastFrame, { keyM = "1" }, TurtleRP_CharacterDetails_General_ICInfoText, petProfile["info"])
  TurtleRP_CharacterDetails_General_OOCInfo:Hide()
  TurtleRP_CharacterDetails_General_OOCInfoText:Hide()

  if lastFrame then
    TurtleRP_CharacterDetails_General_DarkBack:SetPoint("BOTTOMLEFT", lastFrame, "BOTTOMLEFT", 0, -10)
  else
    TurtleRP_CharacterDetails_General_DarkBack:SetPoint("BOTTOMLEFT", TurtleRP_CharacterDetails_General_TargetRaceClass, "BOTTOMLEFT", 0, -10)
  end

  TurtleRP_CharacterDetails_General_ExperienceText:Hide()
  TurtleRP_CharacterDetails_General_Experience:Hide()
  TurtleRP_CharacterDetails_General_WalkupsText:Hide()
  TurtleRP_CharacterDetails_General_Walkups:Hide()
  TurtleRP_CharacterDetails_General_CombatText:Hide()
  TurtleRP_CharacterDetails_General_Combat:Hide()
  TurtleRP_CharacterDetails_General_InjuryText:Hide()
  TurtleRP_CharacterDetails_General_Injury:Hide()
  TurtleRP_CharacterDetails_General_RomanceText:Hide()
  TurtleRP_CharacterDetails_General_Romance:Hide()
  TurtleRP_CharacterDetails_General_DeathText:Hide()
  TurtleRP_CharacterDetails_General_Death:Hide()

  TurtleRP_CharacterDetails_General_AtAGlance1:Hide()
  TurtleRP_CharacterDetails_General_AtAGlance2:Hide()
  TurtleRP_CharacterDetails_General_AtAGlance3:Hide()

  if petProfile["atAGlance1Icon"] and petProfile["atAGlance1Icon"] ~= "" then
    local tex = TurtleRP.GetIconTexture(petProfile["atAGlance1Icon"])
    if tex then
      TurtleRP_CharacterDetails_General_AtAGlance1_Icon:SetTexture(tex)
      TurtleRP_CharacterDetails_General_AtAGlance1_TextPanel_TitleText:SetText(petProfile["atAGlance1Title"] or "")
      TurtleRP_CharacterDetails_General_AtAGlance1_TextPanel_Text:SetText(petProfile["atAGlance1"] or "")
      TurtleRP_CharacterDetails_General_AtAGlance1:Show()
      TurtleRP_CharacterDetails_General_DarkBack:SetPoint("BOTTOMLEFT", TurtleRP_CharacterDetails_General_ICInfoText, "BOTTOMLEFT", 0, -40)
    end
  end
  if petProfile["atAGlance2Icon"] and petProfile["atAGlance2Icon"] ~= "" then
    local tex = TurtleRP.GetIconTexture(petProfile["atAGlance2Icon"])
    if tex then
      TurtleRP_CharacterDetails_General_AtAGlance2_Icon:SetTexture(tex)
      TurtleRP_CharacterDetails_General_AtAGlance2_TextPanel_TitleText:SetText(petProfile["atAGlance2Title"] or "")
      TurtleRP_CharacterDetails_General_AtAGlance2_TextPanel_Text:SetText(petProfile["atAGlance2"] or "")
      TurtleRP_CharacterDetails_General_AtAGlance2:Show()
      TurtleRP_CharacterDetails_General_DarkBack:SetPoint("BOTTOMLEFT", TurtleRP_CharacterDetails_General_ICInfoText, "BOTTOMLEFT", 0, -40)
    end
  end
  if petProfile["atAGlance3Icon"] and petProfile["atAGlance3Icon"] ~= "" then
    local tex = TurtleRP.GetIconTexture(petProfile["atAGlance3Icon"])
    if tex then
      TurtleRP_CharacterDetails_General_AtAGlance3_Icon:SetTexture(tex)
      TurtleRP_CharacterDetails_General_AtAGlance3_TextPanel_TitleText:SetText(petProfile["atAGlance3Title"] or "")
      TurtleRP_CharacterDetails_General_AtAGlance3_TextPanel_Text:SetText(petProfile["atAGlance3"] or "")
      TurtleRP_CharacterDetails_General_AtAGlance3:Show()
      TurtleRP_CharacterDetails_General_DarkBack:SetPoint("BOTTOMLEFT", TurtleRP_CharacterDetails_General_ICInfoText, "BOTTOMLEFT", 0, -40)
    end
  end
  TurtleRP_CharacterDetails_FrameTabButton1:SetNormalTexture("Interface\\Spellbook\\UI-SpellBook-Tab1-Selected")
  TurtleRP_CharacterDetails_FrameTabButton2:SetNormalTexture("Interface\\Spellbook\\UI-Spellbook-Tab-Unselected")
  TurtleRP_CharacterDetails_FrameTabButton3:SetNormalTexture("Interface\\Spellbook\\UI-SpellBook-Tab-Unselected")
  TurtleRP_CharacterDetails_General:Show()
end

function TurtleRP.buildPetDescription(petUID)
  local petProfile = (TurtleRP.previewSource == "pet_admin" and TurtleRP.previewCharacterInfo)
  or (TurtleRP.GetAssignedPetProfile and TurtleRP.GetAssignedPetProfile(petUID))
  or nil
  local htmlFrame = TurtleRP_CharacterDetails_DescriptionScrollBox_DescriptionHolder_DescriptionHTML
  local plainTextFrame = TurtleRP_CharacterDetails_DescriptionScrollBox_DescriptionHolder_DescriptionHTML_TargetDescription
  local holderFrame = TurtleRP_CharacterDetails_DescriptionScrollBox_DescriptionHolder
  TurtleRP.UpdateDescriptionLinkButton(nil)
  TurtleRP.currentlyViewedPetUID = petUID
  TurtleRP.currentlyViewedPlayer = nil
  TurtleRP.currentProfileTab = "description"

  if not petProfile then
    return
  end
  TurtleRP_CharacterDetails_General:Hide()
  TurtleRP_CharacterDetails_Notes:Hide()
  htmlFrame:SetText("")
  plainTextFrame:SetText("")
  holderFrame:SetHeight(50)
  TurtleRP.SetNameAndIcon(nil, petProfile)
  local descriptionText = petProfile["description"] or ""
  if TurtleRP.DescriptionHasSupportedMarkup(descriptionText) then
    htmlFrame:SetHeight(1000)
    holderFrame:SetHeight(1000)
    htmlFrame:SetText(TurtleRP.SanitizeDescriptionHTML(descriptionText))
    plainTextFrame:SetText("")
  else
    local plainText = TurtleRP.NormalizePlainDescription(descriptionText)
    htmlFrame:SetText("")
    plainTextFrame:SetText(plainText or "")

    if plainText == nil or plainText == "" then
      holderFrame:SetHeight(50)
    else
      local textHeight = plainTextFrame:GetHeight() or 0
      holderFrame:SetHeight(math.max(50, textHeight + 20))
    end
  end
  TurtleRP_CharacterDetails_DescriptionScrollBox:Show()
  if TurtleRP_CharacterDetails_DescriptionScrollBox.SetVerticalScroll then
    TurtleRP_CharacterDetails_DescriptionScrollBox:SetVerticalScroll(0)
  end
  if TurtleRP_CharacterDetails_DescriptionScrollBoxScrollBar and TurtleRP_CharacterDetails_DescriptionScrollBoxScrollBar.SetValue then
    TurtleRP_CharacterDetails_DescriptionScrollBoxScrollBar:SetValue(0)
  end
  TurtleRP_CharacterDetails_FrameTabButton1:SetNormalTexture("Interface\\Spellbook\\UI-SpellBook-Tab-Unselected")
  TurtleRP_CharacterDetails_FrameTabButton2:SetNormalTexture("Interface\\Spellbook\\UI-Spellbook-Tab1-Selected")
  TurtleRP_CharacterDetails_FrameTabButton3:SetNormalTexture("Interface\\Spellbook\\UI-SpellBook-Tab-Unselected")
end

function TurtleRP.buildPetNotes(petUID)
  local petProfile = TurtleRP.GetAssignedPetProfile and TurtleRP.GetAssignedPetProfile(petUID) or nil
  TurtleRP.currentlyViewedPetUID = petUID
  TurtleRP.currentlyViewedPlayer = nil
  TurtleRP.currentProfileTab = "notes"
  TurtleRP_CharacterDetails_General:Hide()
  TurtleRP_CharacterDetails_DescriptionScrollBox:Hide()
  if not petProfile then
    return
  end

  TurtleRP.SetNameAndIcon(nil, petProfile)
  TurtleRP_CharacterDetails_Notes_NotesScrollBox_NotesContent_NotesInput:SetText(petProfile["notes"] or "")
  TurtleRP_CharacterDetails_Notes_ShortNoteBox_Input:SetText("")
  if TurtleRP_CharacterDetails_Notes_ShortNoteBox then
  TurtleRP_CharacterDetails_Notes_ShortNoteBox:Hide()
	end
  TurtleRP_CharacterDetails_Notes_DisableRPColorButton:Hide()
  TurtleRP_CharacterDetails_Notes_DisableRPColorText:Hide()

  TurtleRP_CharacterDetails_Notes:Show()
  TurtleRP_CharacterDetails_FrameTabButton1:SetNormalTexture("Interface\\Spellbook\\UI-Spellbook-Tab-Unselected")
  TurtleRP_CharacterDetails_FrameTabButton2:SetNormalTexture("Interface\\Spellbook\\UI-Spellbook-Tab-Unselected")
  TurtleRP_CharacterDetails_FrameTabButton3:SetNormalTexture("Interface\\Spellbook\\UI-SpellBook-Tab1-Selected")
end

function TurtleRP.DescriptionHasSupportedMarkup(text)
  if not text or text == "" then
    return false
  end
  local lowerText = string.lower(text)
  return string.find(lowerText, "<%s*/?%s*h1[%s>]")
      or string.find(lowerText, "<%s*/?%s*h2[%s>]")
      or string.find(lowerText, "<%s*/?%s*h3[%s>]")
      or string.find(lowerText, "<%s*/?%s*p[%s>]")
      or string.find(lowerText, "<%s*/?%s*br%s*/?%s*>")
      or string.find(lowerText, "<%s*/?%s*page%s*/?%s*>")
end

function TurtleRP.ExpandShortTags(text)
  if not text then return "" end

  local t = text
  t = gsub(t, "<h1:c>", '<h1 align="center">')
  t = gsub(t, "<h2:c>", '<h2 align="center">')
  t = gsub(t, "<h3:c>", '<h3 align="center">')
  t = gsub(t, "<p:c>",  '<p align="center">')

  t = gsub(t, "<h1:r>", '<h1 align="right">')
  t = gsub(t, "<h2:r>", '<h2 align="right">')
  t = gsub(t, "<h3:r>", '<h3 align="right">')
  t = gsub(t, "<p:r>",  '<p align="right">')

  t = gsub(t, "<h1:l>", '<h1 align="left">')
  t = gsub(t, "<h2:l>", '<h2 align="left">')
  t = gsub(t, "<h3:l>", '<h3 align="left">')
  t = gsub(t, "<p:l>",  '<p align="left">')

  t = gsub(t, "</h1:c>", "</h1>")
  t = gsub(t, "</h2:c>", "</h2>")
  t = gsub(t, "</h3:c>", "</h3>")
  t = gsub(t, "</p:c>",  "</p>")

  t = gsub(t, "</h1:r>", "</h1>")
  t = gsub(t, "</h2:r>", "</h2>")
  t = gsub(t, "</h3:r>", "</h3>")
  t = gsub(t, "</p:r>",  "</p>")

  t = gsub(t, "</h1:l>", "</h1>")
  t = gsub(t, "</h2:l>", "</h2>")
  t = gsub(t, "</h3:l>", "</h3>")
  t = gsub(t, "</p:l>",  "</p>")

  return t
end
function TurtleRP.SanitizeDescriptionHTML(text)
  if not text then
    return ""
  end

	local sanitized = TurtleRP.ExpandShortTags(text)
	sanitized = gsub(sanitized, "\r\n", "\n")
	sanitized = gsub(sanitized, "\r", "\n")
	sanitized = gsub(sanitized, "@N", "<br />")
	sanitized = gsub(sanitized, "\n", "<br />")

	sanitized = gsub(sanitized, "<%s*(/?)%s*([%a%d]+)(.-)>", function(closingSlash, tagName, attributes)
	  local tag = string.lower(tagName or "")
	  local isClosing = closingSlash == "/"
	  local lowerAttributes = string.lower(attributes or "")

	  if tag == "br" then
		return "<br />"
	  end

	  if tag == "page" then
		if isClosing then
		  return "<br /><br /><br /><br /><br /><br />"
		end
		return ""
	  end

	  if tag ~= "h1" and tag ~= "h2" and tag ~= "h3" and tag ~= "p" then
		return ""
	  end

	  if isClosing then
		return "</" .. tag .. ">"
	  end

	  local _, _, align = string.find(lowerAttributes, 'align%s*=%s*"(.-)"')
	  if not align then
		_, _, align = string.find(lowerAttributes, "align%s*=%s*'(.-)'")
	  end
	  if align == "left" or align == "center" or align == "right" then
		return "<" .. tag .. ' align="' .. align .. '">'
	  end
	  return "<" .. tag .. ">"
	end)
	return "<html><body>" .. sanitized .. "<br /><br /><br /></body></html>"
end

function TurtleRP.NormalizePlainDescription(text)
  if not text then
    return ""
  end

  local normalized = text
  normalized = gsub(normalized, "\r\n", "\n")
  normalized = gsub(normalized, "\r", "\n")
  normalized = gsub(normalized, "@N", "\n")

  return normalized
end

function TurtleRP.SetNameAndIcon(playerName, overrideCharacterInfo)
  local characterInfo = overrideCharacterInfo or (playerName and TurtleRPCharacters[playerName]) or nil
  local isPetProfile = characterInfo and characterInfo["name"] ~= nil and characterInfo["full_name"] == nil
  if characterInfo and not isPetProfile and TurtleRP.NormalizeCharacterProfile then
    TurtleRP.NormalizeCharacterProfile(characterInfo)
  end

  if characterInfo and (characterInfo["keyM"] ~= nil or isPetProfile) then
    local nameToDisplay = ""
    if isPetProfile then
      nameToDisplay = characterInfo["name"] or ""
    else
      nameToDisplay = characterInfo["full_name"] or ""
      if characterInfo["title"] and characterInfo["title"] ~= "" then
        nameToDisplay = characterInfo["title"] .. " " .. nameToDisplay
      end
    end

    local icon = characterInfo["icon"]
    local tex = TurtleRP.GetIconTexture(icon)
    local nameWidth
    local baseX
    local baseY = -52
    TurtleRP_CharacterDetails_TargetName:ClearAllPoints()
    if tex then
      TurtleRP_CharacterDetails_Icon:SetTexture(tex)
      TurtleRP_CharacterDetails_Icon:Show()
      baseX = 65
      nameWidth = 295
    else
      TurtleRP_CharacterDetails_Icon:Hide()
      baseX = 20
      nameWidth = 335
    end
    local wrappedHeight = TurtleRP_GetWrappedTextHeight(TurtleRP_CharacterDetails_TargetName, nameToDisplay, nameWidth)
    if wrappedHeight < 18 then
      wrappedHeight = 18
    end
    local extraHeight = wrappedHeight - 18
    if extraHeight < 0 then
      extraHeight = 0
    end
    TurtleRP_CharacterDetails_TargetName:SetWidth(nameWidth)
    TurtleRP_CharacterDetails_TargetName:SetHeight(wrappedHeight)
    TurtleRP_CharacterDetails_TargetName:SetJustifyH("LEFT")
    if extraHeight > 0 then
      TurtleRP_CharacterDetails_TargetName:SetPoint("TOPLEFT", baseX, baseY + extraHeight - 4)
    else
      TurtleRP_CharacterDetails_TargetName:SetPoint("TOPLEFT", baseX, baseY)
    end
    TurtleRP_CharacterDetails_TargetName:SetText(nameToDisplay)
    if not isPetProfile then
      local factionTex = TurtleRP.getFactionTooltipIcon((characterInfo and characterInfo["faction"]) or TurtleRP.getFactionDefault())
      if factionTex then
        TurtleRP_CharacterDetails_General_FactionIcon:SetTexture(factionTex)
        TurtleRP_CharacterDetails_General_FactionIcon:SetAlpha(0.4)
        TurtleRP_CharacterDetails_General_FactionIcon:Show()
      else
        TurtleRP_CharacterDetails_General_FactionIcon:Hide()
      end
    else
      TurtleRP_CharacterDetails_General_FactionIcon:Hide()
    end
  else
    TurtleRP_CharacterDetails_Icon:Hide()
    if TurtleRP_CharacterDetails_General_FactionIcon then
      TurtleRP_CharacterDetails_General_FactionIcon:Hide()
    end
    TurtleRP_CharacterDetails_TargetName:ClearAllPoints()
    TurtleRP_CharacterDetails_TargetName:SetPoint("TOPLEFT", 25, -52)
    TurtleRP_CharacterDetails_TargetName:SetWidth(320)
    TurtleRP_CharacterDetails_TargetName:SetHeight(18)
    TurtleRP_CharacterDetails_TargetName:SetText("No profile saved.")
    TurtleRP_CharacterDetails_General_TargetRaceClass:SetText("")
  end
end
