--[[
  Created by Vee (http://victortemprano.com), Drixi in-game
  See Github repo at https://github.com/tempranova/turtlerp
]]

-----
-- Interface helpers
-----

function TurtleRP.OpenAdmin()
  if TurtleRP_MinimapIcon then
    TurtleRP_MinimapIcon:StopMovingOrSizing()
  end
  TurtleRP.movingMinimapButton = nil

  UIPanelWindows["TurtleRP_AdminSB"] = { area = "left", pushable = 0 }

  TurtleRP.previewCharacterInfo = nil
  TurtleRP.previewSource = nil
  TurtleRP.ExitPetAtAGlanceMode()
  if TurtleRP_IconSelector then
    TurtleRP_IconSelector.selectedIconIndex = {}
  end

  ShowUIPanel(TurtleRP_AdminSB)
  TurtleRP.populate_interface_user_data()
  TurtleRP.ApplyRandomPrideTitle(TurtleRP_AdminSB_TitleLabel)
  TurtleRP.RefreshAdminStateSnapshot()

  local adminTabs = {
    [1] = { texture = "Interface\\Icons\\Spell_Nature_MoonGlow", tooltip = "Profile" },
    [2] = { texture = "Interface\\Icons\\INV_Misc_Head_Human_02", tooltip = "At A Glance" },
    [3] = { texture = "Interface\\Icons\\INV_Misc_StoneTablet_11", tooltip = "Description" },
    [4] = { texture = "Interface\\Icons\\INV_Letter_03", tooltip = "Notes" },
    [5] = { texture = "Interface\\Icons\\INV_Misc_Book_09", tooltip = "Profiles" },
    [6] = { texture = "Interface\\Icons\\Trade_Engineering", tooltip = "Settings" },
    [7] = { texture = "Interface\\Icons\\INV_Misc_QuestionMark", tooltip = "About / Help" }
  }

  for i = 1, 7 do
    local tab = getglobal("TurtleRP_AdminSB_Tab" .. i)
    local tabData = adminTabs[i]
    tab:SetNormalTexture(tabData.texture)
    tab.tooltip = tabData.tooltip
    tab:Show()
  end

  TurtleRP_AdminSB_Content1_Tab2:Hide()
  if TurtleRP_AdminSB_Content5_Tab2 then
    TurtleRP_AdminSB_Content5_Tab2:Hide()
  end

  TurtleRP_AdminSB_SpellBookFrameTabButton1:SetText("Basic Info")
  TurtleRP_AdminSB_SpellBookFrameTabButton1:SetNormalTexture("Interface\\Spellbook\\UI-Spellbook-Tab1-Selected")
  TurtleRP_AdminSB_SpellBookFrameTabButton1.bookType = "profile"
  TurtleRP_AdminSB_SpellBookFrameTabButton2:SetNormalTexture("Interface\\Spellbook\\UI-SpellBook-Tab-Unselected")
  TurtleRP_AdminSB_SpellBookFrameTabButton2:SetText("RP Style")
  TurtleRP_AdminSB_SpellBookFrameTabButton2.bookType = "rp_style"

  TurtleRP.RefreshProfilesTab()
  TurtleRP.OnAdminTabClick(1)
  TurtleRP.currentDescriptionAlign = ""
end

TurtleRP.currentDescriptionTag = "p"
TurtleRP.currentDescriptionAlign = ""

function TurtleRP.InsertDescriptionTag(tag)
    TurtleRP.currentDescriptionTag = tag
    TurtleRP.ApplyDescriptionTag()
end

function TurtleRP.SetDescriptionAlign(align)
    TurtleRP.currentDescriptionAlign = align
    if TurtleRP_AdminSB_Content3_LeftButton then
        TurtleRP_AdminSB_Content3_LeftButton:SetChecked(align == "")
    end
    if TurtleRP_AdminSB_Content3_CenterButton then
        TurtleRP_AdminSB_Content3_CenterButton:SetChecked(align == ":c")
    end
    if TurtleRP_AdminSB_Content3_RightButton then
        TurtleRP_AdminSB_Content3_RightButton:SetChecked(align == ":r")
    end
end

function TurtleRP.ApplyDescriptionTag()
    local box = TurtleRP_AdminSB_Content3_DescriptionScrollBox_DescriptionInput
    if not box then return end

    local tag = TurtleRP.currentDescriptionTag or "p"
    local align = TurtleRP.currentDescriptionAlign or ""
    local openTag = "<" .. tag .. align .. ">"
    local closeTag = "</" .. tag .. ">"
    local placeholder = "Your text here!"
    local text = box:GetText() or ""
    local cursorPos = box.GetCursorPosition and box:GetCursorPosition() or string.len(text)
    local beforeText
    local afterText
    local insertText
    local highlightStart
    local highlightEnd

    if cursorPos < 0 then
        cursorPos = 0
    end
    if cursorPos > string.len(text) then
        cursorPos = string.len(text)
    end

    box:SetFocus()

    beforeText = string.sub(text, 1, cursorPos)
    afterText = string.sub(text, cursorPos + 1)

    insertText = openTag .. " " .. placeholder .. " " .. closeTag
    box:SetText(beforeText .. insertText .. afterText)

    highlightStart = cursorPos + string.len(openTag .. " ")
    highlightEnd = highlightStart + string.len(placeholder)

    if box.HighlightText then
        box:HighlightText(highlightStart, highlightEnd)
    end
    if box.SetCursorPosition then
        box:SetCursorPosition(highlightEnd)
    end
end

function TurtleRP.InsertDescriptionBreak()
    local box = TurtleRP_AdminSB_Content3_DescriptionScrollBox_DescriptionInput
    if not box then return end

    local text = box:GetText() or ""
    local cursorPos = box.GetCursorPosition and box:GetCursorPosition() or string.len(text)
    local beforeText
    local afterText
    local insertText = "<br>"

    if cursorPos < 0 then
        cursorPos = 0
    end
    if cursorPos > string.len(text) then
        cursorPos = string.len(text)
    end

    beforeText = string.sub(text, 1, cursorPos)
    afterText = string.sub(text, cursorPos + 1)

    box:SetFocus()
    box:SetText(beforeText .. insertText .. afterText)

    if box.SetCursorPosition then
        box:SetCursorPosition(cursorPos + string.len(insertText))
    end
end
function TurtleRP.ApplyAdminTabClick(id)
  for i=1, 7 do
    local tab = getglobal("TurtleRP_AdminSB_Tab"..i)
    local content = getglobal("TurtleRP_AdminSB_Content"..i)
    if tab then
      if i ~= id then
        tab:SetChecked(0)
      else
        tab:SetChecked(1)
      end
    end
    if content then
      if i ~= id then
        content:Hide()
      else
        content:Show()
      end
    end
  end
    if id ~= 2 and TurtleRP.editingPetAtAGlance == 1 then
    TurtleRP.ExitPetAtAGlanceMode()
  end
  TurtleRP_AdminSB_Content1_Tab2:Hide()
  if TurtleRP_AdminSB_Content5_Tab2 then
    TurtleRP_AdminSB_Content5_Tab2:Hide()
  end
  if TurtleRP_AdminSB_Content2_BackButton then
    if id == 2 and TurtleRP.editingPetAtAGlance == 1 then
      TurtleRP_AdminSB_Content2_BackButton:Show()
    else
      TurtleRP_AdminSB_Content2_BackButton:Hide()
    end
  end
  TurtleRP_AdminSB_SpellBookFrameTabButton1:SetNormalTexture("Interface\\Spellbook\\UI-Spellbook-Tab1-Selected")
  TurtleRP_AdminSB_SpellBookFrameTabButton2:SetNormalTexture("Interface\\Spellbook\\UI-SpellBook-Tab-Unselected")
  if id == 1 then
    TurtleRP_AdminSB_SpellBookFrameTabButton1:Show()
    TurtleRP_AdminSB_SpellBookFrameTabButton2:Show()
    TurtleRP_AdminSB_SpellBookFrameTabButton1:SetText("Basic Info")
    TurtleRP_AdminSB_SpellBookFrameTabButton2:SetText("RP Style")
    TurtleRP_AdminSB_SpellBookFrameTabButton1.bookType = "profile"
    TurtleRP_AdminSB_SpellBookFrameTabButton2.bookType = "rp_style"
    TurtleRP.ApplyBottomTabAdminClick("profile")
  elseif id == 5 then
    TurtleRP_AdminSB_SpellBookFrameTabButton1:Show()
    TurtleRP_AdminSB_SpellBookFrameTabButton2:Show()
    TurtleRP_AdminSB_SpellBookFrameTabButton1:SetText("Character Profiles")
    TurtleRP_AdminSB_SpellBookFrameTabButton2:SetText("Pet Profiles")
    TurtleRP_AdminSB_SpellBookFrameTabButton1.bookType = "character_profiles"
    TurtleRP_AdminSB_SpellBookFrameTabButton2.bookType = "pet_profiles"
    TurtleRP.RefreshProfilesTab()
    TurtleRP.ApplyBottomTabAdminClick("character_profiles")
  else
    TurtleRP_AdminSB_SpellBookFrameTabButton1:Hide()
    TurtleRP_AdminSB_SpellBookFrameTabButton2:Hide()
  end
end

function TurtleRP.OnAdminTabClick(id)
  local currentTab = nil
  for i=1, 7 do
    local tab = getglobal("TurtleRP_AdminSB_Tab"..i)
    if tab and tab:GetChecked() then
      currentTab = i
      break
    end
  end
  if id == 2 and TurtleRP.editingPetAtAGlance == 1 then
    TurtleRP.ExitPetAtAGlanceMode()
    TurtleRP.ApplyAdminTabClick(2)
    TurtleRP.RefreshAdminStateSnapshot()
    return
  end
  if currentTab == id then
    TurtleRP.ApplyAdminTabClick(id)
    return
  end
  TurtleRP.RequestAdminTabSwitch("main", id)
end

function TurtleRP.ApplyBottomTabAdminClick(bookType)
  if bookType == "profile" then
    TurtleRP_AdminSB_Content1:Show()
    TurtleRP_AdminSB_Content1_Tab2:Hide()
    if TurtleRP_AdminSB_Content5 then TurtleRP_AdminSB_Content5:Hide() end
    if TurtleRP_AdminSB_Content5_Tab2 then TurtleRP_AdminSB_Content5_Tab2:Hide() end
    TurtleRP_AdminSB_SpellBookFrameTabButton1:SetNormalTexture("Interface\\Spellbook\\UI-Spellbook-Tab1-Selected")
    TurtleRP_AdminSB_SpellBookFrameTabButton2:SetNormalTexture("Interface\\SpellBook\\UI-SpellBook-Tab-Unselected")

  elseif bookType == "rp_style" then
    TurtleRP_AdminSB_Content1:Hide()
    TurtleRP_AdminSB_Content1_Tab2:Show()
    if TurtleRP_AdminSB_Content5 then TurtleRP_AdminSB_Content5:Hide() end
    if TurtleRP_AdminSB_Content5_Tab2 then TurtleRP_AdminSB_Content5_Tab2:Hide() end
    TurtleRP_AdminSB_SpellBookFrameTabButton1:SetNormalTexture("Interface\\SpellBook\\UI-SpellBook-Tab-Unselected")
    TurtleRP_AdminSB_SpellBookFrameTabButton2:SetNormalTexture("Interface\\Spellbook\\UI-Spellbook-Tab1-Selected")
    TurtleRP.SetInitialDropdowns()

  elseif bookType == "character_profiles" then
    if TurtleRP_AdminSB_Content1 then TurtleRP_AdminSB_Content1:Hide() end
    if TurtleRP_AdminSB_Content1_Tab2 then TurtleRP_AdminSB_Content1_Tab2:Hide() end
    TurtleRP_AdminSB_Content5:Show()
    if TurtleRP_AdminSB_Content5_Tab2 then TurtleRP_AdminSB_Content5_Tab2:Hide() end
    TurtleRP_AdminSB_SpellBookFrameTabButton1:SetNormalTexture("Interface\\Spellbook\\UI-Spellbook-Tab1-Selected")
    TurtleRP_AdminSB_SpellBookFrameTabButton2:SetNormalTexture("Interface\\SpellBook\\UI-SpellBook-Tab-Unselected")
    TurtleRP.RefreshProfilesTab()

  elseif bookType == "pet_profiles" then
    if TurtleRP_AdminSB_Content1 then TurtleRP_AdminSB_Content1:Hide() end
    if TurtleRP_AdminSB_Content1_Tab2 then TurtleRP_AdminSB_Content1_Tab2:Hide() end
    if TurtleRP_AdminSB_Content5 then TurtleRP_AdminSB_Content5:Hide() end
    TurtleRP_AdminSB_Content5_Tab2:Show()
    TurtleRP_AdminSB_SpellBookFrameTabButton1:SetNormalTexture("Interface\\SpellBook\\UI-SpellBook-Tab-Unselected")
    TurtleRP_AdminSB_SpellBookFrameTabButton2:SetNormalTexture("Interface\\Spellbook\\UI-Spellbook-Tab1-Selected")
    if (not TurtleRP.currentAdminPetUID or TurtleRP.currentAdminPetUID == "")
      and TurtleRP.lastAdminPetUID and TurtleRP.lastAdminPetUID ~= "" then
      TurtleRP.currentAdminPetUID = TurtleRP.lastAdminPetUID
    end
    TurtleRP.RefreshProfilesTab()
    TurtleRP.populate_pet_admin_data()
  end
end

function TurtleRP.OnBottomTabAdminClick(bookType)
  local currentBookType = "profile"
  if TurtleRP_AdminSB_Content1_Tab2 and TurtleRP_AdminSB_Content1_Tab2:IsShown() then
    currentBookType = "rp_style"
  elseif TurtleRP_AdminSB_Content5 and TurtleRP_AdminSB_Content5:IsShown() then
    currentBookType = "character_profiles"
  elseif TurtleRP_AdminSB_Content5_Tab2 and TurtleRP_AdminSB_Content5_Tab2:IsShown() then
    currentBookType = "pet_profiles"
  end
  if currentBookType == bookType then
    TurtleRP.ApplyBottomTabAdminClick(bookType)
    return
  end
  TurtleRP.RequestAdminTabSwitch("bottom", bookType)
end

function TurtleRP.InitializeProfilesDropdown()
  local dropdown = TurtleRP_AdminSB_Content5_ProfileDropdown
  if not dropdown then
    return
  end
  UIDropDownMenu_Initialize(dropdown, function()
    local info = {}
    info.text = "Select Profile..."
    info.value = ""
		info.func = function()
		  UIDropDownMenu_SetSelectedValue(dropdown, "")
		  getglobal(dropdown:GetName() .. "Text"):SetText("Select Profile...")
		  CloseDropDownMenus()
		end
    UIDropDownMenu_AddButton(info)
    local names = TurtleRP.GetAllAccountProfileNames()
    for _, profileName in ipairs(names) do
      info = {}
      info.text = profileName
      info.value = profileName
	info.func = function()
	  UIDropDownMenu_SetSelectedValue(dropdown, this.value)
	  getglobal(dropdown:GetName() .. "Text"):SetText(this.value)
	  CloseDropDownMenus()
	end
      UIDropDownMenu_AddButton(info)
    end
  end)
end

function TurtleRP.InitializePetProfilesDropdown()
  local dropdown = TurtleRP_AdminSB_Content5_Tab2_ProfileDropdown
  if not dropdown then
    return
  end

  UIDropDownMenu_Initialize(dropdown, function()
    local info = {}
    info.text = "Select Pet Profile..."
    info.value = ""
    info.func = function()
      UIDropDownMenu_SetSelectedValue(dropdown, "")
      getglobal(dropdown:GetName() .. "Text"):SetText("Select Pet Profile...")
      TurtleRP.populate_pet_admin_data()
      CloseDropDownMenus()
    end
    UIDropDownMenu_AddButton(info)

    if not TurtleRP.currentAdminPetUID or TurtleRP.currentAdminPetUID == "" then
      return
    end

    local entry = TurtleRP.GetPetProfileEntry(TurtleRP.currentAdminPetUID)
    if not entry or not entry["profiles"] then
      return
    end

    local names = {}
    local profileName
    for profileName in pairs(entry["profiles"]) do
      table.insert(names, profileName)
    end
    table.sort(names, function(a, b)
      return string.lower(a) < string.lower(b)
    end)

    for _, profileName in ipairs(names) do
      info = {}
      info.text = profileName
      info.value = profileName
      info.func = function()
        UIDropDownMenu_SetSelectedValue(dropdown, this.value)
        getglobal(dropdown:GetName() .. "Text"):SetText(this.value)
        TurtleRP.populate_pet_admin_data()
        CloseDropDownMenus()
      end
      UIDropDownMenu_AddButton(info)
    end
  end)
end

function TurtleRP.RefreshProfilesTab()
  if not TurtleRP_AdminSB_Content5 then
    return
  end
  local currentProfileName = TurtleRP.GetBoundProfileName(UnitName("player")) or ""
  TurtleRP_AdminSB_Content5_CurrentProfileText:SetText(currentProfileName)
  TurtleRP_AdminSB_Content5_RenameInput:SetText(currentProfileName)
  TurtleRP.InitializeProfilesDropdown()
  local dropdown = TurtleRP_AdminSB_Content5_ProfileDropdown
  local text = dropdown and getglobal(dropdown:GetName() .. "Text") or nil
  local selectedProfile = dropdown and UIDropDownMenu_GetSelectedValue(dropdown) or nil
  if selectedProfile and selectedProfile ~= "" and TurtleRPAccountProfiles and TurtleRPAccountProfiles[selectedProfile] then
    UIDropDownMenu_SetSelectedValue(dropdown, selectedProfile)
    if text then
      text:SetText(selectedProfile)
    end
  else
    UIDropDownMenu_SetSelectedValue(dropdown, "")
    if text then
      text:SetText("Select Profile...")
    end
  end
  TurtleRP.InitializePetProfilesDropdown()
  if TurtleRP.currentAdminPetUID and TurtleRP.currentAdminPetUID ~= "" then
    local petDropdown = TurtleRP_AdminSB_Content5_Tab2_ProfileDropdown
    local petText = petDropdown and getglobal(petDropdown:GetName() .. "Text") or nil
    local petSelected = petDropdown and UIDropDownMenu_GetSelectedValue(petDropdown) or nil
    if not petSelected or petSelected == "" then
      petSelected = TurtleRP.GetAssignedPetProfileName(TurtleRP.currentAdminPetUID) or ""
      if petDropdown then
        UIDropDownMenu_SetSelectedValue(petDropdown, petSelected)
      end
    end
    if petText then
      if petSelected ~= "" then
        petText:SetText(petSelected)
      else
        petText:SetText("Select Pet Profile...")
      end
    end
  end
end

function TurtleRP.GetUniqueNewProfileName(baseName)
  local candidate = baseName
  local suffix = 2

  while TurtleRPAccountProfiles and TurtleRPAccountProfiles[candidate] ~= nil do
    candidate = baseName .. " " .. suffix
    suffix = suffix + 1
  end

  return candidate
end

function TurtleRP.AssignSelectedAccountProfile()
  local dropdown = TurtleRP_AdminSB_Content5_ProfileDropdown
  local selectedProfile = UIDropDownMenu_GetSelectedValue(dropdown)
  if not selectedProfile or selectedProfile == "" then
    return
  end
  TurtleRP.BindProfileToCharacter(UnitName("player"), selectedProfile)
  TurtleRP.populate_interface_user_data()
  TurtleRP.RefreshProfilesTab()
  TurtleRP.RefreshAdminStateSnapshot()
end

function TurtleRP.CreateNewBlankAccountProfile()
  TurtleRP.SyncBoundProfile(UnitName("player"))
  local baseName = UnitName("player") .. " Profile"
  local newName = TurtleRP.GetUniqueNewProfileName(baseName)
  TurtleRP.CreateBlankProfile(newName)
  TurtleRP.BindProfileToCharacter(UnitName("player"), newName)
  TurtleRP.populate_interface_user_data()
  TurtleRP.RefreshProfilesTab()
  TurtleRP.RefreshAdminStateSnapshot()
end

function TurtleRP.DuplicateCurrentAccountProfile()
  TurtleRP.SyncBoundProfile(UnitName("player"))
  local currentProfileName = TurtleRP.GetBoundProfileName(UnitName("player"))
  local duplicatedProfile
  local newName

  if not currentProfileName or currentProfileName == "" then
    return
  end

  newName = TurtleRP.GetUniqueNewProfileName(currentProfileName)
  duplicatedProfile = TurtleRP.CopyTableShallow(TurtleRPAccountProfiles[currentProfileName])
  TurtleRP.NormalizeCharacterProfile(duplicatedProfile)
  duplicatedProfile["keyM"] = TurtleRP.randomchars()
  duplicatedProfile["keyT"] = TurtleRP.randomchars()
  duplicatedProfile["keyD"] = TurtleRP.randomchars()

  TurtleRPAccountProfiles[newName] = duplicatedProfile
  TurtleRP.BindProfileToCharacter(UnitName("player"), newName)

  TurtleRP.populate_interface_user_data()
  TurtleRP.RefreshProfilesTab()
  TurtleRP.RefreshAdminStateSnapshot()
end

function TurtleRP.IsReservedProfileName(profileName)
  if not profileName or profileName == "" then
    return true
  end

  local lowered = string.lower(profileName)
  if lowered == "0" or lowered == "1" or lowered == "2" or lowered == "3" then
    return true
  end

  return false
end

function TurtleRP.RenameAccountProfile(oldName, newName)
  if not oldName or oldName == "" or not newName or newName == "" then
    return nil
  end
  if TurtleRPAccountProfiles == nil then
    TurtleRPAccountProfiles = {}
  end
  if TurtleRPCharacterProfileBindings == nil then
    TurtleRPCharacterProfileBindings = {}
  end
  if TurtleRPAccountProfiles[oldName] == nil then
    return nil
  end
  if TurtleRPAccountProfiles[newName] ~= nil then
    return nil
  end
  if TurtleRP.IsReservedProfileName(newName) then
    return nil
  end
  TurtleRPAccountProfiles[newName] = TurtleRPAccountProfiles[oldName]
  TurtleRPAccountProfiles[oldName] = nil
  for playerName, boundProfileName in pairs(TurtleRPCharacterProfileBindings) do
    if boundProfileName == oldName then
      TurtleRPCharacterProfileBindings[playerName] = newName
    end
  end
  if TurtleRP.GetBoundProfileName(UnitName("player")) == newName then
    TurtleRP.NormalizeCharacterProfile(TurtleRPAccountProfiles[newName])
    TurtleRPCharacterInfo = TurtleRPAccountProfiles[newName]
    TurtleRPCharacters[UnitName("player")] = TurtleRPCharacterInfo
  end
  return newName
end

function TurtleRP.RenameCurrentAccountProfile()
  local oldName = TurtleRP.GetBoundProfileName(UnitName("player"))
  if not oldName or oldName == "" then
    return
  end
  local input = TurtleRP_AdminSB_Content5_RenameInput
  if not input then
    return
  end
  local newName = TurtleRP.validateBeforeSaving(input:GetText())
  input:ClearFocus()
  if not newName or newName == "" or newName == oldName then
    TurtleRP.RefreshProfilesTab()
    return
  end
  TurtleRP.SyncBoundProfile(UnitName("player"))
  if TurtleRP.RenameAccountProfile(oldName, newName) == nil then
    TurtleRP.RefreshProfilesTab()
    return
  end
  TurtleRP.populate_interface_user_data()
  TurtleRP.RefreshProfilesTab()
  local dropdown = TurtleRP_AdminSB_Content5_ProfileDropdown
  local text = dropdown and getglobal(dropdown:GetName() .. "Text") or nil
  if dropdown then
    UIDropDownMenu_SetSelectedValue(dropdown, newName)
  end
  if text then
    text:SetText(newName)
  end
  TurtleRP.RefreshAdminStateSnapshot()
end

function TurtleRP.ShowDeleteCurrentAccountProfilePopup()
  StaticPopup_Show("TTRP_DELETE_PROFILE_CONFIRM")
end

local TurtleRPProfileExportKeys = {
  "full_name",
  "race",
  "class",
  "class_token",
  "class_color",
  "title",
  "icon",
  "ic_info",
  "ooc_info",
  "ic_pronouns",
  "ooc_pronouns",
  "currently_ic",
  "nsfw",
  "faction",
  "currently",
  "atAGlance1",
  "atAGlance1Title",
  "atAGlance1Icon",
  "atAGlance2",
  "atAGlance2Title",
  "atAGlance2Icon",
  "atAGlance3",
  "atAGlance3Title",
  "atAGlance3Icon",
  "experience",
  "walkups",
  "combat",
  "injury",
  "romance",
  "death",
  "description",
  "description_link_text",
  "description_link",
  "notes",
  "short_note",
  "guild_override",
  "guild_ic",
  "guild_ooc"
}

local TurtleRPProfileExportDelimiter = "^"

local function TurtleRP_EscapeProfileExportValue(value)
  local s = tostring(value or "")
  s = string.gsub(s, "%%", "%%p")
  s = string.gsub(s, "%^", "%%c")
  s = string.gsub(s, "\r", "")
  s = string.gsub(s, "\n", "%%n")
  return s
end

local function TurtleRP_UnescapeProfileExportValue(value)
  local s = tostring(value or "")
  s = string.gsub(s, "%%n", "\n")
  s = string.gsub(s, "%%c", "^")
  s = string.gsub(s, "%%p", "%%")
  return s
end

local function TurtleRP_SplitExportString(text)
  local results = {}
  local startPos = 1
  local delimPos = string.find(text, TurtleRPProfileExportDelimiter, startPos, true)

  while delimPos do
    table.insert(results, string.sub(text, startPos, delimPos - 1))
    startPos = delimPos + 1
    delimPos = string.find(text, TurtleRPProfileExportDelimiter, startPos, true)
  end

  table.insert(results, string.sub(text, startPos))
  return results
end

local function TurtleRP_ParseExportData(importString)
  if not importString or importString == "" then
    return nil
  end

  local parts = TurtleRP_SplitExportString(importString)
  if table.getn(parts) < 3 then
    return nil
  end

  if parts[1] ~= "TTRP" and parts[1] ~= "TTRPPET" then
    return nil
  end
  local data = {}
  local importedName = TurtleRP_UnescapeProfileExportValue(parts[2] or "")

  local i
  for i = 3, table.getn(parts) do
    local segment = parts[i]
    local eqPos = string.find(segment, "=", 1, true)
    if eqPos then
      local key = string.sub(segment, 1, eqPos - 1)
      local value = string.sub(segment, eqPos + 1)
      data[key] = TurtleRP_UnescapeProfileExportValue(value)
    end
  end

  return {
    profileName = importedName,
    fields = data
  }
end

function TurtleRP.GetCurrentProfileExportString()
  TurtleRP.SyncBoundProfile(UnitName("player"))

  local profileName = TurtleRP.GetBoundProfileName(UnitName("player")) or UnitName("player")
  local profile = TurtleRPAccountProfiles and TurtleRPAccountProfiles[profileName] or TurtleRPCharacterInfo
  if not profile then
    return ""
  end

  local parts = { "TTRP", TurtleRP_EscapeProfileExportValue(profileName) }
  local _, key
  for _, key in ipairs(TurtleRPProfileExportKeys) do
    table.insert(parts, key .. "=" .. TurtleRP_EscapeProfileExportValue(profile[key] or ""))
  end

  return table.concat(parts, TurtleRPProfileExportDelimiter)
end

function TurtleRP.ShowExportCurrentProfilePopup()
  local exportString = TurtleRP.GetCurrentProfileExportString()
  StaticPopup_Show("TTRP_EXPORT_PROFILE")
  if StaticPopup1EditBox then
    StaticPopup1EditBox:SetText(exportString or "")
    StaticPopup1EditBox:HighlightText()
    StaticPopup1EditBox:SetFocus()
  end
end

TurtleRP.pendingImportedProfileString = nil

function TurtleRP.ShowImportProfilePopup()
  TurtleRP.pendingImportedProfileString = nil
  StaticPopup_Show("TTRP_IMPORT_PROFILE")
  if StaticPopup1EditBox then
    StaticPopup1EditBox:SetText("")
    StaticPopup1EditBox:SetFocus()
  end
end
-- Pet import/export
local TurtleRPPetExportKeys = {
  "name",
  "unit_name",
  "pronouns",
  "info",
  "icon",
  "atAGlance1",
  "atAGlance1Title",
  "atAGlance1Icon",
  "atAGlance2",
  "atAGlance2Title",
  "atAGlance2Icon",
  "atAGlance3",
  "atAGlance3Title",
  "atAGlance3Icon",
  "description",
  "notes",
  "profile_name"
}

TurtleRP.pendingImportedPetProfileString = nil

function TurtleRP.GetCurrentPetProfileExportString()
  local petUID = TurtleRP.currentAdminPetUID
  local petProfile = TurtleRP.GetCurrentAdminPetProfile()
  if not petUID or petUID == "" or not petProfile then
    return ""
  end
  local profileName = petProfile["profile_name"] or TurtleRP.GetAssignedPetProfileName(petUID) or (petProfile["name"] or "Pet")
  local parts = { "TTRPPET", TurtleRP_EscapeProfileExportValue(profileName) }
  local _, key
  for _, key in ipairs(TurtleRPPetExportKeys) do
    table.insert(parts, key .. "=" .. TurtleRP_EscapeProfileExportValue(petProfile[key] or ""))
  end
  return table.concat(parts, TurtleRPProfileExportDelimiter)
end

function TurtleRP.ShowExportCurrentPetProfilePopup()
  if not TurtleRP.currentAdminPetUID or TurtleRP.currentAdminPetUID == "" or not TurtleRP.GetCurrentAdminPetProfile() then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r No pet profile loaded.")
    return
  end
  local exportString = TurtleRP.GetCurrentPetProfileExportString()
  StaticPopup_Show("TTRP_EXPORT_PET_PROFILE")
  if StaticPopup1EditBox then
    StaticPopup1EditBox:SetText(exportString or "")
    StaticPopup1EditBox:HighlightText()
    StaticPopup1EditBox:SetFocus()
  end
end

function TurtleRP.ShowImportPetProfilePopup()
  if not TurtleRP.currentAdminPetUID or TurtleRP.currentAdminPetUID == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r Load a pet first.")
    return
  end
  TurtleRP.pendingImportedPetProfileString = nil
  StaticPopup_Show("TTRP_IMPORT_PET_PROFILE")
  if StaticPopup1EditBox then
    StaticPopup1EditBox:SetText("")
    StaticPopup1EditBox:SetFocus()
  end
end

function TurtleRP.BeginImportPetProfileFlow(importString)
  local parsed = TurtleRP_ParseExportData(importString)
  if not parsed or string.sub(importString or "", 1, 7) ~= "TTRPPET" then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r Invalid pet import string.")
    return
  end
  if not TurtleRP.currentAdminPetUID or TurtleRP.currentAdminPetUID == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r Load a pet first.")
    return
  end
  TurtleRP.pendingImportedPetProfileString = importString
  local importedName = parsed.profileName
  if not importedName or importedName == "" then
    importedName = "Imported Pet Profile"
  end
  StaticPopup_Show("TTRP_IMPORT_PET_PROFILE_NAME")
  if StaticPopup1EditBox then
    StaticPopup1EditBox:SetText(importedName)
    StaticPopup1EditBox:HighlightText()
    StaticPopup1EditBox:SetFocus()
  end
end

function TurtleRP.ImportPetProfileStringAsNewProfile(importString, requestedName)
  local petUID = TurtleRP.currentAdminPetUID
  local parsed = TurtleRP_ParseExportData(importString)
  local entry
  local importedName
  local desiredName
  local finalName
  local newProfile
  local _, key
  if not parsed then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r Invalid pet import string.")
    return
  end
  if not petUID or petUID == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r Load a pet first.")
    return
  end
  entry = TurtleRP.EnsurePetProfileEntry(petUID)
  if not entry then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r Failed to access pet profiles.")
    return
  end

  importedName = parsed.profileName
  desiredName = TurtleRP.validateBeforeSaving(requestedName or "")
  if desiredName and desiredName ~= "" then
    importedName = desiredName
  end
  if not importedName or importedName == "" then
    importedName = "Imported Pet Profile"
  end

  finalName = importedName
  if entry["profiles"][finalName] ~= nil then
    local suffix = 2
    while entry["profiles"][finalName] ~= nil do
      finalName = importedName .. " " .. suffix
      suffix = suffix + 1
    end
  end
  newProfile = {}
  for _, key in ipairs(TurtleRPPetExportKeys) do
    newProfile[key] = ""
  end
  for _, key in ipairs(TurtleRPPetExportKeys) do
    if parsed.fields[key] ~= nil then
      newProfile[key] = parsed.fields[key]
    end
  end
  newProfile["profile_name"] = finalName
  newProfile["comm_id"] = ""
  newProfile["keyM"] = TurtleRP.randomchars()
  newProfile["keyT"] = TurtleRP.randomchars()
  newProfile["keyD"] = TurtleRP.randomchars()
  if not newProfile["name"] or newProfile["name"] == "" then
    newProfile["name"] = finalName
  end
  if newProfile["unit_name"] == nil then
    newProfile["unit_name"] = ""
  end
  if newProfile["pronouns"] == nil then
    newProfile["pronouns"] = ""
  end
  if newProfile["info"] == nil then
    newProfile["info"] = ""
  end
  if newProfile["icon"] == nil then
    newProfile["icon"] = ""
  end
  if newProfile["atAGlance1"] == nil then
    newProfile["atAGlance1"] = ""
  end
  if newProfile["atAGlance1Title"] == nil then
    newProfile["atAGlance1Title"] = ""
  end
  if newProfile["atAGlance1Icon"] == nil then
    newProfile["atAGlance1Icon"] = ""
  end
  if newProfile["atAGlance2"] == nil then
    newProfile["atAGlance2"] = ""
  end
  if newProfile["atAGlance2Title"] == nil then
    newProfile["atAGlance2Title"] = ""
  end
  if newProfile["atAGlance2Icon"] == nil then
    newProfile["atAGlance2Icon"] = ""
  end
  if newProfile["atAGlance3"] == nil then
    newProfile["atAGlance3"] = ""
  end
  if newProfile["atAGlance3Title"] == nil then
    newProfile["atAGlance3Title"] = ""
  end
  if newProfile["atAGlance3Icon"] == nil then
    newProfile["atAGlance3Icon"] = ""
  end
  if newProfile["description"] == nil then
    newProfile["description"] = ""
  end
  if newProfile["notes"] == nil then
    newProfile["notes"] = ""
  end
  newProfile["comm_id"] = TurtleRP.BuildPetCommKey(
    UnitName("player"),
    newProfile["unit_name"] or newProfile["name"] or "",
    newProfile["unit_species"] or newProfile["species"] or "",
    nil
  )
  if newProfile["name"] == nil then newProfile["name"] = "" end
  if newProfile["species"] == nil then newProfile["species"] = "" end
  if newProfile["level"] == nil then newProfile["level"] = "" end
  if newProfile["unit_species"] == nil then newProfile["unit_species"] = newProfile["species"] or "" end
  entry["profiles"][finalName] = newProfile
  entry["assignedProfile"] = finalName
  TurtleRP.RefreshProfilesTab()
  if TurtleRP_AdminSB_Content5_Tab2_ProfileDropdown then
    UIDropDownMenu_SetSelectedValue(TurtleRP_AdminSB_Content5_Tab2_ProfileDropdown, finalName)
    local text = getglobal(TurtleRP_AdminSB_Content5_Tab2_ProfileDropdown:GetName() .. "Text")
    if text then
      text:SetText(finalName)
    end
  end
  TurtleRP.populate_pet_admin_data()
  TurtleRP.RefreshAdminStateSnapshot()
  TurtleRP.pendingImportedPetProfileString = nil
  DEFAULT_CHAT_FRAME:AddMessage("|cff66CC66[TurtleRP]|r Imported pet profile: " .. finalName)
end
--Importing functionality
function TurtleRP.BeginImportProfileFlow(importString)
  local parsed = TurtleRP_ParseExportData(importString)
  if not parsed then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r Invalid import string.")
    return
  end
  TurtleRP.pendingImportedProfileString = importString
  local importedName = parsed.profileName
  if not importedName or importedName == "" then
    importedName = UnitName("player") .. " Imported"
  end
  StaticPopup_Show("TTRP_IMPORT_PROFILE_NAME")
  if StaticPopup1EditBox then
    StaticPopup1EditBox:SetText(importedName)
    StaticPopup1EditBox:HighlightText()
    StaticPopup1EditBox:SetFocus()
  end
end

function TurtleRP.ImportProfileStringAsNewProfile(importString, requestedName)
  local parsed = TurtleRP_ParseExportData(importString)
  if not parsed then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r Invalid import string.")
    return
  end
  if TurtleRPAccountProfiles == nil then
    TurtleRPAccountProfiles = {}
  end
  local importedName = parsed.profileName
  local desiredName = TurtleRP.validateBeforeSaving(requestedName or "")
  if desiredName and desiredName ~= "" then
    importedName = desiredName
  end
  if not importedName or importedName == "" then
    importedName = UnitName("player") .. " Imported"
  end

  local finalName = importedName
  if TurtleRPAccountProfiles[finalName] ~= nil then
    finalName = TurtleRP.GetUniqueNewProfileName(importedName)
  end

  local newProfile = TurtleRP.CreateBlankProfile(finalName)
  if not newProfile then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r Failed to create imported profile.")
    return
  end

  local _, key
  for _, key in ipairs(TurtleRPProfileExportKeys) do
    if parsed.fields[key] ~= nil then
      newProfile[key] = parsed.fields[key]
    end
  end

  if not newProfile["full_name"] or newProfile["full_name"] == "" then
    newProfile["full_name"] = UnitName("player")
  end
  if not newProfile["race"] or newProfile["race"] == "" then
    newProfile["race"] = UnitRace("player")
  end
  if not newProfile["class"] or newProfile["class"] == "" then
    local localizedClass = UnitClass("player")
    newProfile["class"] = localizedClass
  end
  if not newProfile["class_token"] or newProfile["class_token"] == "" then
    local _, classToken = UnitClass("player")
    newProfile["class_token"] = classToken
  end
  if not newProfile["class_color"] or newProfile["class_color"] == "" then
    local localizedClass = newProfile["class"] or select(1, UnitClass("player"))
    if TurtleRPClassData[localizedClass] then
      newProfile["class_color"] = TurtleRPClassData[localizedClass][4]
    end
  end
  if not newProfile["currently_ic"] or newProfile["currently_ic"] == "" then
    newProfile["currently_ic"] = "1"
  end
  if not newProfile["nsfw"] or newProfile["nsfw"] == "" then
    newProfile["nsfw"] = "0"
  end
  if newProfile["notes"] == nil then
    newProfile["notes"] = ""
  end
  if newProfile["short_note"] == nil then
    newProfile["short_note"] = ""
  end

  newProfile["keyM"] = TurtleRP.randomchars()
  newProfile["keyT"] = TurtleRP.randomchars()
  newProfile["keyD"] = TurtleRP.randomchars()
  newProfile["character_notes"] = {}
  newProfile["character_short_notes"] = {}
  newProfile["character_disable_rp_color"] = {}
  TurtleRP.NormalizeCharacterProfile(newProfile)

  TurtleRP.BindProfileToCharacter(UnitName("player"), finalName)
  TurtleRP.populate_interface_user_data()
  TurtleRP.RefreshProfilesTab()
  TurtleRP.RefreshAdminStateSnapshot()

  TurtleRP.pendingImportedProfileString = nil
  DEFAULT_CHAT_FRAME:AddMessage("|cff66CC66[TurtleRP]|r Imported profile: " .. finalName)
end

function TurtleRP.DeleteAccountProfile(profileName)
  if not profileName or profileName == "" then
    return nil
  end
  if TurtleRPAccountProfiles == nil then
    TurtleRPAccountProfiles = {}
  end
  if TurtleRPCharacterProfileBindings == nil then
    TurtleRPCharacterProfileBindings = {}
  end
  if TurtleRPAccountProfiles[profileName] == nil then
    return nil
  end
  local remainingNames = {}
  for existingName in pairs(TurtleRPAccountProfiles) do
    if existingName ~= profileName then
      table.insert(remainingNames, existingName)
    end
  end
  if table.getn(remainingNames) == 0 then
    return nil
  end
  table.sort(remainingNames, function(a, b)
    return string.lower(a) < string.lower(b)
  end)
  local fallbackProfileName = remainingNames[1]
  for playerName, boundProfileName in pairs(TurtleRPCharacterProfileBindings) do
    if boundProfileName == profileName then
      TurtleRPCharacterProfileBindings[playerName] = fallbackProfileName
    end
  end
  TurtleRPAccountProfiles[profileName] = nil
  return fallbackProfileName
end

function TurtleRP.DeleteCurrentAccountProfile()
  local currentProfileName = TurtleRP.GetBoundProfileName(UnitName("player"))
  if not currentProfileName or currentProfileName == "" then
    return
  end
  TurtleRP.SyncBoundProfile(UnitName("player"))
  local fallbackProfileName = TurtleRP.DeleteAccountProfile(currentProfileName)
  if fallbackProfileName == nil then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r You cannot delete your last remaining profile.")
    TurtleRP.RefreshProfilesTab()
    return
  end
  TurtleRP.BindProfileToCharacter(UnitName("player"), fallbackProfileName)
  TurtleRP.populate_interface_user_data()
  TurtleRP.RefreshProfilesTab()
  TurtleRP.RefreshAdminStateSnapshot()
end

function TurtleRP.ShouldShareLocation()
  if TurtleRPSettings["share_location"] ~= "1" then
    return false
  end
  if TurtleRPSettings["bgs"] == "on" and UnitIsPVP("player") then
    return false
  end

  return true
end

function TurtleRP.showColorPicker(r, g, b, a, changedCallback)
 ColorPickerFrame:SetColorRGB(r, g, b);
 ColorPickerFrame.hasOpacity, ColorPickerFrame.opacity = (a ~= nil), a;
 ColorPickerFrame.previousValues = {r,g,b,a};
 ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = changedCallback, changedCallback, changedCallback;
 ColorPickerFrame:Hide(); 
 ColorPickerFrame:Show();
end

function TurtleRP.colorPickerCallback(restore)
  local newR, newG, newB, newA
  if restore then
    newR, newG, newB, newA = unpack(restore)
  else
    newA, newR, newG, newB = OpacitySliderFrame:GetValue(), ColorPickerFrame:GetColorRGB()
  end

  local r, g, b, a = newR, newG, newB, newA
  TurtleRP_AdminSB_Content1_ClassColorButton:SetBackdropColor(r, g, b)
end

-----
-- Dropdown RP Style selectors
-----
function TurtleRP.InitializeRPStyleDropdown(frame, items)
  UIDropDownMenu_Initialize(frame, function()
    local frameName = frame:GetName()
    local visibleText = getglobal(frameName .. "_Text")
    local info

    info = {}
    info.text = "Select..."
    info.value = ""
    info.checked = false
    info.hasArrow = false
    info.func = function()
      UIDropDownMenu_SetSelectedValue(frame, "")
      if visibleText then
        visibleText:SetText("Select...")
      end
      CloseDropDownMenus()
    end
    UIDropDownMenu_AddButton(info)

    for i, v in items do
      local optionValue = i
      local optionText = v

      info = {}
      info.text = optionText
      info.value = optionValue
      info.checked = false
      info.hasArrow = false
      info.func = function()
        UIDropDownMenu_SetSelectedValue(frame, optionValue)
        if visibleText then
          visibleText:SetText(optionText)
        end
        CloseDropDownMenus()
      end
      UIDropDownMenu_AddButton(info)
    end

    local selectedValue = UIDropDownMenu_GetSelectedValue(frame)
    if visibleText then
      if selectedValue and selectedValue ~= "" and items[selectedValue] then
        visibleText:SetText(items[selectedValue])
      else
        visibleText:SetText("Select...")
      end
    end
  end)
end

function TurtleRP.SetInitialDropdowns()
  local dropdownsToSet = {}
  dropdownsToSet["experience"] = TurtleRP_AdminSB_Content1_Tab2_ExperienceDropdown
  dropdownsToSet["walkups"] = TurtleRP_AdminSB_Content1_Tab2_WalkupsDropdown
  dropdownsToSet["combat"] = TurtleRP_AdminSB_Content1_Tab2_CombatDropdown
  dropdownsToSet["injury"] = TurtleRP_AdminSB_Content1_Tab2_InjuryDropdown
  dropdownsToSet["romance"] = TurtleRP_AdminSB_Content1_Tab2_RomanceDropdown
  dropdownsToSet["death"] = TurtleRP_AdminSB_Content1_Tab2_DeathDropdown

  for i, v in dropdownsToSet do
    if v then
      local playerData = TurtleRPCharacters and TurtleRPCharacters[UnitName("player")]
      local thisValue = playerData and playerData[i] or nil
      local visibleText = getglobal(v:GetName() .. "_Text")

      if thisValue and thisValue ~= "" and thisValue ~= "0" and TurtleRPDropdownOptions[i] and TurtleRPDropdownOptions[i][thisValue] then
        UIDropDownMenu_SetSelectedValue(v, thisValue)
        if visibleText then
          visibleText:SetText(TurtleRPDropdownOptions[i][thisValue])
        end
      else
        UIDropDownMenu_SetSelectedValue(v, "")
        if visibleText then
          visibleText:SetText("Select...")
        end
      end
    end
  end
end

-----
-- Faction / Icon Selector
-----
function TurtleRP.open_faction_selector()
  if not TurtleRP_FactionSelector then
    return
  end
  TurtleRP_FactionSelector:Show()
  TurtleRP_FactionSelector:SetFrameStrata("HIGH")
  if TurtleRP.factionFrames == nil then
    TurtleRP.factionFrames = {}
  end
  TurtleRP.render_faction_selector()
end

function TurtleRP.render_faction_selector()
  local items = TurtleRP.getFactionSelectorItems()
  local i
  for i = 1, table.getn(TurtleRP.factionFrames) do
    TurtleRP.factionFrames[i]:Hide()
  end
  for i = 1, table.getn(items) do
    local item = items[i]
    local button = TurtleRP.factionFrames[i]
    if not button then
      button = CreateFrame("Button", "TurtleRPFactionButton" .. i, TurtleRP_FactionSelector)
      button:SetWidth(64)
      button:SetHeight(64)
      button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
      local column = math.mod(i - 1, 5)
      local row = math.floor((i - 1) / 5)
      button:SetPoint("TOPLEFT", TurtleRP_FactionSelector, "TOPLEFT", 28 + (column * 64), -50 - (row * 72))
      button.tex = button:CreateTexture(nil, "ARTWORK")
      button.tex:SetAllPoints(button)

      button:SetScript("OnEnter", function()
        if this.factionName then
          GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
          GameTooltip:SetText(this.factionName)
          GameTooltip:Show()
        end
      end)
      button:SetScript("OnLeave", function()
        GameTooltip:Hide()
      end)
      button:SetScript("OnClick", function()
        if this.factionKey then
          TurtleRP.pendingFactionSelection = this.factionKey
          TurtleRP.updateFactionButton()
          TurtleRP_FactionSelector:Hide()
        end
      end)
      TurtleRP.factionFrames[i] = button
    end
    button.factionKey = item.key
    button.factionName = item.name
    button.tex:SetTexture(item.texture)
    button:Show()
  end
end

function TurtleRP.GetSelectorItems()
  if TurtleRP.currentIconSelector == "faction" then
    return TurtleRP.getFactionSelectorItems()
  end

  if TurtleRP.selectorItemsCache then
    return TurtleRP.selectorItemsCache
  end

  local items = {}
  local allIcons = TurtleRP.GetAllIcons()
  local i
  local iconName
  local aliases
  local aliasJoined
  local j

  for i = 1, table.getn(allIcons) do
    iconName = allIcons[i]
    aliases = TurtleRP.GetIconAliases(iconName)
    aliasJoined = ""
    if aliases then
      for j = 1, table.getn(aliases) do
        if aliases[j] and aliases[j] ~= "" then
          if aliasJoined ~= "" then
            aliasJoined = aliasJoined .. " "
          end
          aliasJoined = aliasJoined .. string.lower(aliases[j])
        end
      end
    end

    items[i] = {
      key = i,
      name = iconName,
      rawNameSearch = string.lower(iconName or ""),
      normalizedNameSearch = TurtleRP.NormalizeIconSearchText(iconName or ""),
      aliasSearch = aliasJoined,
      normalizedAliasSearch = TurtleRP.NormalizeIconSearchText(aliasJoined),
      texture = "Interface\\Icons\\" .. iconName,
    }
  end

  TurtleRP.selectorItemsCache = items
  return items
end

function TurtleRP.create_icon_selector()
  TurtleRP_IconSelector:Show()
  TurtleRP_IconSelector:SetFrameStrata("high")
  TurtleRP_IconSelector_FilterSearchInput:SetFrameStrata("high")
  TurtleRP_IconSelector_ScrollBox:SetFrameStrata("high")

  if TurtleRP.iconFrames == nil then
    TurtleRP.iconFrames = TurtleRP.makeIconFrames()
  end

  TurtleRP.iconSelectorFilter = ""
  TurtleRP.filteredIconItemsCache = nil
  TurtleRP.filteredIconItemsCacheKey = nil

  TurtleRP_IconSelector_FilterSearchInput:SetText("")
  TurtleRP_IconSelector_ScrollBox.offset = 0
  FauxScrollFrame_SetOffset(TurtleRP_IconSelector_ScrollBox, 0)

  TurtleRP.Icon_ScrollBar_Update()
end

function TurtleRP.GetCurrentIconFilterTextRaw()
  if TurtleRP_IconSelector_FilterSearchInput and TurtleRP_IconSelector_FilterSearchInput:GetText() then
    return string.lower(TurtleRP_IconSelector_FilterSearchInput:GetText() or "")
  end
  return string.lower(TurtleRP.iconSelectorFilter or "")
end
function TurtleRP.GetCurrentIconFilterTextNormalized()
  return TurtleRP.NormalizeIconSearchText(TurtleRP.GetCurrentIconFilterTextRaw())
end

function TurtleRP.IconItemMatchesFilter(item, rawFilterText, normalizedFilterText)
  if not item then
    return nil
  end
  if (not rawFilterText or rawFilterText == "") and (not normalizedFilterText or normalizedFilterText == "") then
    return 1
  end
  if rawFilterText and rawFilterText ~= "" then
    if item.rawNameSearch ~= "" and string.find(item.rawNameSearch, rawFilterText, 1, true) then
      return 1
    end
    if item.aliasSearch ~= "" and string.find(item.aliasSearch, rawFilterText, 1, true) then
      return 1
    end
  end
  if normalizedFilterText and normalizedFilterText ~= "" then
    if item.normalizedNameSearch ~= "" and string.find(item.normalizedNameSearch, normalizedFilterText, 1, true) then
      return 1
    end
    if item.normalizedAliasSearch ~= "" and string.find(item.normalizedAliasSearch, normalizedFilterText, 1, true) then
      return 1
    end
  end
  return nil
end

function TurtleRP.GetFilteredIconItems()
  local items = TurtleRP.GetSelectorItems()
  local rawFilterText = TurtleRP.GetCurrentIconFilterTextRaw and TurtleRP.GetCurrentIconFilterTextRaw() or string.lower(TurtleRP.iconSelectorFilter or "")
  local normalizedFilterText = TurtleRP.GetCurrentIconFilterTextNormalized and TurtleRP.GetCurrentIconFilterTextNormalized() or TurtleRP.NormalizeIconSearchText(rawFilterText)
  local cacheKey = (TurtleRP.currentIconSelector or "") .. "||" .. rawFilterText .. "||" .. normalizedFilterText

  if TurtleRP.filteredIconItemsCacheKey == cacheKey and TurtleRP.filteredIconItemsCache then
    return TurtleRP.filteredIconItemsCache
  end

  local filteredItems = {}
  local i
  local count = 0

  if rawFilterText == "" and normalizedFilterText == "" then
    TurtleRP.filteredIconItemsCacheKey = cacheKey
    TurtleRP.filteredIconItemsCache = items
    return items
  end

  for i = 1, table.getn(items) do
    if TurtleRP.IconItemMatchesFilter(items[i], rawFilterText, normalizedFilterText) then
      count = count + 1
      filteredItems[count] = items[i]
    end
  end

  TurtleRP.filteredIconItemsCacheKey = cacheKey
  TurtleRP.filteredIconItemsCache = filteredItems
  return filteredItems
end

function TurtleRP.GetFilteredIconCount()
  return table.getn(TurtleRP.GetFilteredIconItems())
end

function TurtleRP.Icon_ScrollBar_Update()
  local iconsPerRow = 8
  local visibleRows = 10
  local rowHeight = 34
  local filteredItems = TurtleRP.GetFilteredIconItems()
  local totalIcons = table.getn(filteredItems)
  local totalRows = math.ceil(totalIcons / iconsPerRow)
  local currentRow = FauxScrollFrame_GetOffset(TurtleRP_IconSelector_ScrollBox) or 0
  local maxRowOffset = totalRows - visibleRows
  local iconOffset = 0

  if maxRowOffset < 0 then
    maxRowOffset = 0
  end

  if currentRow < 0 then
    currentRow = 0
  end

  if currentRow > maxRowOffset then
    currentRow = maxRowOffset
    FauxScrollFrame_SetOffset(TurtleRP_IconSelector_ScrollBox, currentRow)
  end

  TurtleRP_IconSelector_ScrollBox.offset = currentRow
  FauxScrollFrame_Update(TurtleRP_IconSelector_ScrollBox, totalRows, visibleRows, rowHeight)

  iconOffset = currentRow * iconsPerRow
  TurtleRP.renderIcons(iconOffset, filteredItems)
end

function TurtleRP.IconSelector_OnVerticalScroll(scrollOffset)
  FauxScrollFrame_OnVerticalScroll(34, TurtleRP.Icon_ScrollBar_Update)
end

function TurtleRP.EnsureIconSelectorContentFrame()
  if TurtleRP_IconSelector_Content then
    return TurtleRP_IconSelector_Content
  end
  local content = CreateFrame("Frame", "TurtleRP_IconSelector_Content", TurtleRP_IconSelector)
  content:SetWidth(280)
  content:SetHeight(340)
  content:SetPoint("TOPLEFT", TurtleRP_IconSelector, "TOPLEFT", 16, -40)
  return content
end

function TurtleRP.makeIconFrames()
  local IconFrames = {}
  local iconsPerRow = 8
  local visibleRows = 10
  local totalVisibleIcons = iconsPerRow * visibleRows
  local iconSize = 32
  local iconSpacing = 2
  local i

 for i = 1, totalVisibleIcons do
  local column = math.mod((i - 1), iconsPerRow)
  local row = math.floor((i - 1) / iconsPerRow)
  local thisIconFrame = CreateFrame("Button", "TurtleRPIcon_" .. i, TurtleRP.EnsureIconSelectorContentFrame())

  thisIconFrame:SetWidth(iconSize)
  thisIconFrame:SetHeight(iconSize)
  thisIconFrame:SetPoint("TOPLEFT", TurtleRP_IconSelector_Content, "TOPLEFT", column * (iconSize + iconSpacing), row * -(iconSize + iconSpacing))
    thisIconFrame:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    thisIconFrame.itemKey = nil
    thisIconFrame.itemName = nil
    thisIconFrame.tex = thisIconFrame:CreateTexture(nil, "ARTWORK")
    thisIconFrame.tex:SetAllPoints(thisIconFrame)
	thisIconFrame.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    thisIconFrame.tex:SetTexture(nil)
    thisIconFrame.border = thisIconFrame:CreateTexture(nil, "BORDER")
    thisIconFrame.border:SetAllPoints(thisIconFrame)
    thisIconFrame.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

    thisIconFrame:SetScript("OnClick", function()
      if not this.itemKey then
        return
      end
      if TurtleRP.currentIconSelector == "faction" then
        TurtleRPCharacterInfo["faction"] = this.itemKey
        TurtleRP.updateFactionButton()
      else
        TurtleRP_IconSelector.selectedIconIndex = TurtleRP_IconSelector.selectedIconIndex or {}
        TurtleRP_IconSelector.selectedIconIndex[TurtleRP.currentIconSelector] = this.itemKey
        if TurtleRP.currentIconSelector == "icon" then
          TurtleRP.setCharacterIcon()
        elseif TurtleRP.currentIconSelector == "pet_icon" then
          TurtleRP.setPetAdminIcon()
        else
          TurtleRP.setAtAGlanceIcons()
        end
      end
      TurtleRP_IconSelector:Hide()
    end)
    thisIconFrame:SetScript("OnEnter", function()
      if this.itemName and this.itemName ~= "" then
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(this.itemName)
        GameTooltip:Show()
      end
    end)
    thisIconFrame:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
    IconFrames[i] = thisIconFrame
  end
  return IconFrames
end

function TurtleRP.renderIcons(iconOffset, filteredItems)
  local i
  if TurtleRP.iconFrames == nil then
    return
  end
  if not filteredItems then
    filteredItems = TurtleRP.GetFilteredIconItems()
  end
  for i = 1, table.getn(TurtleRP.iconFrames) do
    local iconFrame = TurtleRP.iconFrames[i]
    local item = filteredItems[(iconOffset or 0) + i]
    if item and item.texture then
      iconFrame.itemKey = item.key
      iconFrame.itemName = item.name
      iconFrame.tex:SetTexture(item.texture)
      iconFrame:Show()
    else
      iconFrame.itemKey = nil
      iconFrame.itemName = nil
      iconFrame.tex:SetTexture(nil)
      iconFrame:Hide()
    end
  end
end

function TurtleRP.ToggleChatNames()
  if TurtleRPSettings["chat_names"] == "1" then
    TurtleRPSettings["chat_names"] = "0"
    TurtleRP_AdminSB_Content6_ChatNamesButton:SetChecked(false)
  else
    TurtleRPSettings["chat_names"] = "1"
    TurtleRP_AdminSB_Content6_ChatNamesButton:SetChecked(true)
  end
end
