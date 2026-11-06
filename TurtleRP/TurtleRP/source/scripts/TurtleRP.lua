--[[
  Created by Vee (http://victortemprano.com), Drixi in-game
  See Github repo at https://github.com/tempranova/turtlerp
]]

-----
-- Global storage (not saved)
-----
TurtleRP.TestMode = 0

-- Dev
-- currentversion has been replaced with a dynamic version that reads from the toc. keep for compatability.
TurtleRP.currentVersion = "unknown"
TurtleRP.latestVersion = TurtleRP.currentVersion
-- Chat
TurtleRP.channelName = "TTRP"
TurtleRP.channelIndex = 0
TurtleRP.timeBetweenPings = 30
TurtleRP.minChatLevel = 10
TurtleRP.currentlyRequestedData = nil
TurtleRP.disableMessageSending = nil
TurtleRP.sendingLongForm = nil
TurtleRP.errorMessage = nil
TurtleRP.sendWithError = nil
-- Interface
TurtleRP.iconFrames = nil
TurtleRP.directoryFrames = nil
TurtleRP.iconSelectorCreated = nil
TurtleRP.currentIconSelector = nil
TurtleRP.iconSelectorFilter = ""
TurtleRP.RPMode = 0
TurtleRP.movingIconTray = nil
TurtleRP.movingMinimapButton = nil
TurtleRP.editingChatBox = nil
TurtleRP.currentChatType = nil
TurtleRP.targetFrame = TargetFrame
TurtleRP.gameTooltip = GameTooltip
TurtleRP.shaguEnabled = nil
-- Directory
TurtleRP.currentlyViewedPlayer = nil
TurtleRP.currentlyViewedPlayerFrame = nil
TurtleRP.locationFrames = {}
TurtleRP.showDescription = nil
TurtleRP.currentProfileTab = "general"
TurtleRP.secondColumn = "Character Name"
TurtleRP.sortByKey = "status"
TurtleRP.sortByOrder = 1
TurtleRP.searchTerm = ""
TurtleRP.adminSuppressClosePrompt = nil
TurtleRP.adminUnsavedPopupPending = nil
TurtleRP.adminStateSnapshot = nil
TurtleRP.adminPendingTabSwitch = nil
TurtleRP.adminPendingBottomTabSwitch = nil
TurtleRP.previewCharacterInfo = nil
TurtleRP.previewSource = nil
TurtleRP.currentlyViewedPetUID = nil
TurtleRP.currentAdminPetUID = nil
TurtleRP.movingMinimapButton = nil
-- Accounting for PFUI, Go Shagu Go
if pfUI ~= nil and pfUI.uf ~= nil and pfUI.uf.target ~= nil then
  TurtleRP.targetFrame = pfUI.uf.target
  TurtleRP.shaguEnabled = true
end

function TurtleRP.ForceCloseMap()
  if WorldMapFrame:IsVisible() then
    ToggleWorldMap()
  end
end
--minimap icon stuffs
function TurtleRP.SaveMinimapIconPosition()
  local centerX, centerY
  local parentX, parentY

  if not TurtleRPSettings or not TurtleRP_MinimapIcon or not MinimapCluster then
    return
  end

  centerX, centerY = TurtleRP_MinimapIcon:GetCenter()
  parentX, parentY = MinimapCluster:GetCenter()

  if centerX and centerY and parentX and parentY then
    TurtleRPSettings["minimap_icon_x"] = centerX - parentX
    TurtleRPSettings["minimap_icon_y"] = centerY - parentY
  end
end

function TurtleRP.RestoreMinimapIconPosition()
  local x = -40
  local y = 0

  if not TurtleRP_MinimapIcon or not MinimapCluster then
    return
  end

  if TurtleRPSettings then
    if type(TurtleRPSettings["minimap_icon_x"]) == "number" then
      x = TurtleRPSettings["minimap_icon_x"]
    end
    if type(TurtleRPSettings["minimap_icon_y"]) == "number" then
      y = TurtleRPSettings["minimap_icon_y"]
    end
  end

  TurtleRP_MinimapIcon:StopMovingOrSizing()
  TurtleRP_MinimapIcon:ClearAllPoints()
  TurtleRP_MinimapIcon:SetPoint("CENTER", MinimapCluster, "CENTER", x, y)
end

function TurtleRP.RefreshMinimapIconState()
  if not TurtleRP_MinimapIcon or not TurtleRPSettings then
    return
  end
  if TurtleRPSettings["hide_minimap_icon"] == "1" then
    TurtleRP_MinimapIcon:Hide()
    return
  end
  if pfUI == nil and WorldMapFrame and WorldMapFrame:IsShown() then
    TurtleRP_MinimapIcon:Hide()
    return
  end
  TurtleRP_MinimapIcon:Show()
end

function TurtleRP.ResetMinimapIconPosition()
  if not TurtleRP_MinimapIcon then
    return
  end

  if not TurtleRPSettings then
    TurtleRPSettings = {}
  end

  TurtleRPSettings["minimap_icon_x"] = -40
  TurtleRPSettings["minimap_icon_y"] = 0
  TurtleRPSettings["hide_minimap_icon"] = "0"

  TurtleRP.movingMinimapButton = nil
  TurtleRP_MinimapIcon:StopMovingOrSizing()
  TurtleRP.RestoreMinimapIconPosition()
  TurtleRP.RefreshMinimapIconState()
end

function TurtleRP.CloseWorldMap()
    if WorldMapFrame and WorldMapFrame:IsVisible() then
        if ToggleWorldMap then
            ToggleWorldMap()
        else
            HideUIPanel(WorldMapFrame)
        end
        return 1
    end
    return nil
end
-- New icon compatibility
TurtleRP.baseIconsCount = table.getn(TurtleRPIcons or {})

TurtleRP.Factions = {
  alliance = {
    display = "Alliance",
    icon    = "Interface\\Addons\\TurtleRP\\images\\trp_faction_alliance.blp",
    tooltip = "Interface\\Addons\\TurtleRP\\images\\trp_faction_alliance_tt.blp",
    mapIC   = "Interface\\Addons\\TurtleRP\\images\\WorldMapPlayerIconAlliance.blp",
  },
  horde = {
    display = "Horde",
    icon    = "Interface\\Addons\\TurtleRP\\images\\trp_faction_horde.blp",
    tooltip = "Interface\\Addons\\TurtleRP\\images\\trp_faction_horde_tt.blp",
    mapIC   = "Interface\\Addons\\TurtleRP\\images\\WorldMapPlayerIconHorde.blp",
  },
  neutral = {
    display = "Independent",
    icon    = "Interface\\Addons\\TurtleRP\\images\\trp_faction_neutral.blp",
    tooltip = "Interface\\Addons\\TurtleRP\\images\\trp_faction_neutral_tt.blp",
    -- just reusing the asset already here but i did edit the color slightly
    mapIC   = "Interface\\Addons\\TurtleRP\\images\\WorldMapPlayerIconTRP.blp",
  },
  scarlet = {
    display = "Scarlet",
    icon    = "Interface\\Addons\\TurtleRP\\images\\trp_faction_scarlet.blp",
    tooltip = "Interface\\Addons\\TurtleRP\\images\\trp_faction_scarlet_tt.blp",
    mapIC   = "Interface\\Addons\\TurtleRP\\images\\WorldMapPlayerIconScarlet.blp",
  },
  scourge = {
    display = "Scourge",
    icon    = "Interface\\Addons\\TurtleRP\\images\\trp_faction_scourge.blp",
    tooltip = "Interface\\Addons\\TurtleRP\\images\\trp_faction_scourge_tt.blp",
    mapIC   = "Interface\\Addons\\TurtleRP\\images\\WorldMapPlayerIconScourge.blp",
  },
}

function TurtleRP.getFactionDefault()
  local factionGroup = UnitFactionGroup("player")
  if factionGroup == "Alliance" then
    return "alliance"
  elseif factionGroup == "Horde" then
    return "horde"
  end

  local _, raceEnglish = UnitRace("player")
  if raceEnglish == "Human"
    or raceEnglish == "Dwarf"
    or raceEnglish == "NightElf"
    or raceEnglish == "Gnome"
    or raceEnglish == "BloodElf" then
    return "alliance"
  elseif raceEnglish == "Orc"
    or raceEnglish == "Troll"
    or raceEnglish == "Tauren"
	or raceEnglish == "Goblin"
    or raceEnglish == "Undead" then
    return "horde"
  end

  return "neutral"
end

function TurtleRP.getFactionInfo(faction)
  local f = faction or "neutral"
  return TurtleRP.Factions[f] or TurtleRP.Factions["neutral"]
end

TurtleRPFactionWireMap = {
  neutral  = "f0",
  alliance = "f1",
  horde    = "f2",
  scarlet  = "f3",
  scourge  = "f4",
}

TurtleRPFactionWireReverseMap = {
  f0 = "neutral",
  f1 = "alliance",
  f2 = "horde",
  f3 = "scarlet",
  f4 = "scourge",
}

function TurtleRP.EncodeFactionValue(faction)
  local normalized = faction or "neutral"
  if TurtleRPFactionWireMap[normalized] then
    return TurtleRPFactionWireMap[normalized]
  end
  return TurtleRPFactionWireMap["neutral"]
end

function TurtleRP.DecodeFactionValue(faction)
  local value = faction or ""
  if TurtleRPFactionWireReverseMap[value] then
    return TurtleRPFactionWireReverseMap[value]
  end
  if TurtleRP.Factions and TurtleRP.Factions[value] then
    return value
  end
  return "neutral"
end

function TurtleRP.getFactionDisplayName(faction)
  local info = TurtleRP.getFactionInfo(faction)
  return (info and info.display) or "Neutral"
end

function TurtleRP.getFactionOrder()
  return { "alliance", "horde", "neutral", "scourge", "scarlet" }
end

function TurtleRP.getFactionSelectorItems()
  local order = TurtleRP.getFactionOrder()
  local items = {}
  local i

  for i = 1, table.getn(order) do
    local key = order[i]
    local info = TurtleRP.getFactionInfo(key)
    items[i] = {
      key = key,
      name = info.display,
      texture = info.icon,
    }
  end

  return items
end

function TurtleRP.getFactionIcon(faction)
  local info = TurtleRP.getFactionInfo(faction)
  return info and info.icon or nil
end

function TurtleRP.getFactionTooltipIcon(faction)
  local info = TurtleRP.getFactionInfo(faction)
  return info and info.tooltip or nil
end

function TurtleRP.getMapIcon(faction, currently_ic)
  if currently_ic ~= "1" then
    return "Interface\\Addons\\TurtleRP\\images\\WorldMapPlayerIconOOC.blp"
  end
  local info = TurtleRP.getFactionInfo(faction)
  return info and info.mapIC or "Interface\\Addons\\TurtleRP\\images\\WorldMapPlayerIconTRP.blp"
end

function TurtleRP.GetPetUID(unit)
  if not unit or unit == "" or not UnitExists(unit) then
    return nil
  end
  local ownerName = UnitName("player") or "unknownOwner"
  local petName = UnitName(unit) or "unknownPet"
  local petType = "unknownType"
  local function getPetType(fromUnit)
    if UnitCreatureFamily and UnitCreatureFamily(fromUnit) and UnitCreatureFamily(fromUnit) ~= "" then
      return UnitCreatureFamily(fromUnit)
    end
    if UnitCreatureType and UnitCreatureType(fromUnit) and UnitCreatureType(fromUnit) ~= "" then
      return UnitCreatureType(fromUnit)
    end
    return "unknownType"
  end
  if UnitExists("pet") and UnitIsUnit and UnitIsUnit(unit, "pet") then
    petName = UnitName("pet") or petName
    petType = getPetType("pet")
    return ownerName .. "_pet_" .. petName .. "_" .. petType
  end
  if unit == "target" and UnitExists("pet") then
    local targetName = UnitName("target")
    local playerPetName = UnitName("pet")
    if targetName and playerPetName and targetName == playerPetName then
      petType = getPetType("pet")
      return ownerName .. "_pet_" .. targetName .. "_" .. petType
    end
  end
  return nil
end

function TurtleRP.GetAdminPendingFactionValue(fallback)
  if TurtleRP.pendingFactionSelection ~= nil and TurtleRP.pendingFactionSelection ~= "" then
    return TurtleRP.pendingFactionSelection
  end
  return fallback
end

function TurtleRP.updateFactionButton()
  local button = TurtleRP_AdminSB_Content1_FactionButton
  local preview = TurtleRP_AdminSB_Content1_FactionMapPreview
  if not button then
    return
  end
  local faction = TurtleRP.GetAdminPendingFactionValue(
    (TurtleRPCharacterInfo and TurtleRPCharacterInfo["faction"]) or TurtleRP.getFactionDefault()
  )
  local factionTex = TurtleRP.getFactionIcon(faction)
  local mapTex = TurtleRP.getMapIcon(faction, "1")
  if factionTex then
    button:SetBackdrop({ bgFile = factionTex })
  else
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\UI-EmptySlot-White" })
  end
  if preview then
    if mapTex then
      preview:SetBackdrop({ bgFile = mapTex })
    else
      preview:SetBackdrop({ bgFile = "Interface\\Buttons\\UI-EmptySlot-White" })
    end
  end
end

function TurtleRP.GetIconNameByGlobalIndex(index)
  local idx = tonumber(index)
  if not idx or idx < 1 then
    return nil
  end
  if idx <= TurtleRP.baseIconsCount then
    return TurtleRPIcons[idx]
  end
  idx = idx - TurtleRP.baseIconsCount
  if TurtleRPNewIcons and TurtleRPNewIcons[idx] then
    return TurtleRPNewIcons[idx]
  end
  return nil
end

function TurtleRP.GetIconTexture(iconIndex)
  local iconName = TurtleRP.GetIconNameByGlobalIndex(iconIndex)
  if not iconName or iconName == "" then
    return nil
  end
  return "Interface\\Icons\\" .. iconName
end

function TurtleRP.GetAllIcons()
  local allIcons = {}
  if TurtleRPIcons then
    for i = 1, table.getn(TurtleRPIcons) do
      table.insert(allIcons, TurtleRPIcons[i])
    end
  end
  if TurtleRPNewIcons then
    for i = 1, table.getn(TurtleRPNewIcons) do
      table.insert(allIcons, TurtleRPNewIcons[i])
    end
  end
  return allIcons
end

function TurtleRP.GetIconAliases(iconName)
  if not iconName or iconName == "" then
    return nil
  end
  if not TurtleRPIconAliases then
    return nil
  end
  return TurtleRPIconAliases[iconName]
end

function TurtleRP.NormalizeIconSearchText(text)
  local s = string.lower(tostring(text or ""))
  s = string.gsub(s, "&.-;", "")
  s = string.gsub(s, "[%._%-%s%p]", "")
  return s
end

function TurtleRP.GetIconSearchText(iconName)
  local pieces = {}
  local aliases
  local i
  if iconName and iconName ~= "" then
    table.insert(pieces, TurtleRP.NormalizeIconSearchText(iconName))
  end
  aliases = TurtleRP.GetIconAliases(iconName)
  if aliases then
    for i = 1, table.getn(aliases) do
      if aliases[i] and aliases[i] ~= "" then
        table.insert(pieces, TurtleRP.NormalizeIconSearchText(aliases[i]))
      end
    end
  end
  return table.concat(pieces, " ")
end
-----
-- Addon load event
-----
local TurtleRP_Parent = CreateFrame("Frame")
TurtleRP_Parent:RegisterEvent("ADDON_LOADED")
TurtleRP_Parent:RegisterEvent("PLAYER_LOGOUT")

function TurtleRP:OnEvent()
	if event == "PLAYER_LOGOUT" then
      TurtleRP.SyncBoundProfile(UnitName("player"))
      return
    elseif event == "ADDON_LOADED" and arg1 == "TurtleRP" then

  local tocVersion = GetAddOnMetadata("TurtleRP", "Version")
  if tocVersion and tocVersion ~= "" then
    TurtleRP.currentVersion = tocVersion
  else
    TurtleRP.currentVersion = "unknown"
  end
  TurtleRP.latestVersion = TurtleRP.currentVersion

    local TurtleRPCharacterInfoTemplate = {}

    TurtleRPCharacterInfoTemplate["keyM"] = TurtleRP.randomchars()
    TurtleRPCharacterInfoTemplate["nsfw"] = "0"
    TurtleRPCharacterInfoTemplate["icon"] = ""
	TurtleRPCharacterInfoTemplate["title"] = ""
    local localizedClass, classToken = UnitClass("player")

    TurtleRPCharacterInfoTemplate["full_name"] = UnitName("player")
    TurtleRPCharacterInfoTemplate["race"] = UnitRace("player")
    TurtleRPCharacterInfoTemplate["class"] = localizedClass
    TurtleRPCharacterInfoTemplate["class_token"] = classToken
    TurtleRPCharacterInfoTemplate["class_color"] = TurtleRPClassData[localizedClass][4]
    TurtleRPCharacterInfoTemplate["faction"] = TurtleRP.getFactionDefault()
    TurtleRPCharacterInfoTemplate["ic_info"] = ""
    TurtleRPCharacterInfoTemplate["ooc_info"] = ""
    TurtleRPCharacterInfoTemplate["ic_pronouns"] = ""
    TurtleRPCharacterInfoTemplate["ooc_pronouns"] = ""
    TurtleRPCharacterInfoTemplate["currently_ic"] = "1"

    TurtleRPCharacterInfoTemplate["notes"] = ""
	TurtleRPCharacterInfoTemplate["short_note"] = ""

    TurtleRPCharacterInfoTemplate["keyT"] = TurtleRP.randomchars()
    TurtleRPCharacterInfoTemplate["currently"] = ""
    TurtleRPCharacterInfoTemplate["atAGlance1"] = ""
    TurtleRPCharacterInfoTemplate["atAGlance1Title"] = ""
    TurtleRPCharacterInfoTemplate["atAGlance1Icon"] = ""
    TurtleRPCharacterInfoTemplate["atAGlance2"] = ""
    TurtleRPCharacterInfoTemplate["atAGlance2Title"] = ""
    TurtleRPCharacterInfoTemplate["atAGlance2Icon"] = ""
    TurtleRPCharacterInfoTemplate["atAGlance3"] = ""
    TurtleRPCharacterInfoTemplate["atAGlance3Title"] = ""
    TurtleRPCharacterInfoTemplate["atAGlance3Icon"] = ""
    TurtleRPCharacterInfoTemplate["experience"] = "z"
    TurtleRPCharacterInfoTemplate["walkups"] = "z"
    TurtleRPCharacterInfoTemplate["combat"] = "z"
    TurtleRPCharacterInfoTemplate["injury"] = "z"
    TurtleRPCharacterInfoTemplate["romance"] = "z"
    TurtleRPCharacterInfoTemplate["death"] = "z"

	TurtleRPCharacterInfoTemplate["keyD"] = TurtleRP.randomchars()
	TurtleRPCharacterInfoTemplate["description"] = ""
	TurtleRPCharacterInfoTemplate["description_link_text"] = ""
	TurtleRPCharacterInfoTemplate["description_link"] = ""

    TurtleRPCharacterInfoTemplate["character_notes"] = {}
    TurtleRPCharacterInfoTemplate["character_short_notes"] = {}
    TurtleRPCharacterInfoTemplate["character_disable_rp_color"] = {}

    local TurtleRPSettingsTemplate = {}
    TurtleRPSettingsTemplate["bgs"] = "off"
    TurtleRPSettingsTemplate["tray"] = "1"
    TurtleRPSettingsTemplate["name_size"] = "1"
    TurtleRPSettingsTemplate["hide_minimap_icon"] = "0"
    TurtleRPSettingsTemplate["share_location"] = "0"
    TurtleRPSettingsTemplate["minimap_icon_x"] = -40
    TurtleRPSettingsTemplate["minimap_icon_y"] = 0
    TurtleRPSettingsTemplate["show_nsfw"] = "0"
	TurtleRPSettingsTemplate["chat_names"] = "1"
	TurtleRPSettingsTemplate["chat_colors"] = "1"
    TurtleRPSettingsTemplate["auto_emote_name"] = "1"
	TurtleRPSettingsTemplate["disable_tooltip"] = "0"
	TurtleRPSettingsTemplate["disable_tooltip_bg"] = "0"

    -- Legacy only. Keep for migration/backward compatibility.
    TurtleRPSettingsTemplate["selected_profile"] = "0"
    TurtleRPSettingsTemplate["profiles_migrated_to_account"] = "0"

    local TurtleRPPlayerProfilesTemplate = {}
    TurtleRPPlayerProfilesTemplate["0"] = TurtleRPCharacterInfoTemplate
    TurtleRPPlayerProfilesTemplate["1"] = TurtleRPCharacterInfoTemplate
    TurtleRPPlayerProfilesTemplate["2"] = TurtleRPCharacterInfoTemplate
    TurtleRPPlayerProfilesTemplate["3"] = TurtleRPCharacterInfoTemplate

    if TurtleRPPlayerProfiles == nil then
      TurtleRPPlayerProfiles = TurtleRPPlayerProfilesTemplate
    end

    -- New account-wide profile storage.
    if TurtleRPAccountProfiles == nil then
      TurtleRPAccountProfiles = {}
    end
    if TurtleRPCharacterProfileBindings == nil then
      TurtleRPCharacterProfileBindings = {}
    end
    if TurtleRPCharacterInfo == nil then
      TurtleRPCharacterInfo = TurtleRP.CopyTableShallow(TurtleRPCharacterInfoTemplate)
    end
    if TurtleRPCharacters == nil then
      TurtleRPCharacters = {}
    else
      for character in pairs(TurtleRPCharacters) do
        if not TurtleRPCharacters[character]["nsfw"] then
          TurtleRPCharacters[character]["nsfw"] = "0"
        end
      end
    end
    if TurtleRPSettings == nil then
      TurtleRPSettings = TurtleRPSettingsTemplate
    end
    if TurtleRPQueryablePlayers == nil then
      TurtleRPQueryablePlayers = {}
    end
    if TurtleRPPetProfiles == nil then
      TurtleRPPetProfiles = {}
    end
	local petUID, entry, profileName, profileData
		for petUID, entry in pairs(TurtleRPPetProfiles) do
		  if entry and entry["profiles"] then
			for profileName, profileData in pairs(entry["profiles"]) do
			  if profileData and (not profileData["comm_id"] or profileData["comm_id"] == "") then
				profileData["comm_id"] = TurtleRP.randomchars() .. TurtleRP.randomchars()
			  end
			end
		  end
		end

    -- For adding additional settings after plugin is in use
	-- Reformatted in 2.0, add to TurtleRP.NormalizeCharacterProfile now
    if TurtleRPSettings ~= nil then
      for i, field in pairs(TurtleRPSettingsTemplate) do
        if TurtleRPSettings[i] == nil then
          TurtleRPSettings[i] = TurtleRPSettingsTemplate[i]
        end
      end
    end
      TurtleRP.NormalizeCharacterProfile(TurtleRPCharacterInfo)
      local profileName, profileData
      for profileName, profileData in pairs(TurtleRPAccountProfiles or {}) do
        if type(profileData) == "table" then
          TurtleRP.NormalizeCharacterProfile(profileData)
        end
      end
      local legacyKey, legacyProfile
      for legacyKey, legacyProfile in pairs(TurtleRPPlayerProfiles or {}) do
        if type(legacyProfile) == "table" then
          TurtleRP.NormalizeCharacterProfile(legacyProfile)
        end
      end
      local characterName, characterProfile
      for characterName, characterProfile in pairs(TurtleRPCharacters or {}) do
        if type(characterProfile) == "table" then
          TurtleRP.NormalizeCharacterProfile(characterProfile)
        end
      end
      local playerName = UnitName("player")
      TurtleRP.MigrateLegacyProfilesForCurrentCharacter()
      TurtleRPCharacterInfo = TurtleRP.GetBoundProfile(playerName)
      TurtleRPCharacters[playerName] = TurtleRPCharacterInfo
      TurtleRPPlayerProfiles[TurtleRPSettings["selected_profile"]] = TurtleRPCharacterInfo


    -- Intro message
    TurtleRP.log("Welcome, |cff8C48AB" .. TurtleRPCharacterInfo["full_name"] .. "|r, to " .. TurtleRP.GetRandomPrideTitleText() .. "|r.")
    TurtleRP.log("Type |cff8C48AB/ttrp |rto open the addon, or |cff8C48AB/ttrp help|r to see slash commands.")

    if not TurtleRP.canChat() and UnitLevel("player") ~= 0 then
      TurtleRP.log("Sorry, but due to Turtle WoW restrictions you can't access other player's TurtleRP profiles until level " .. TurtleRP.minChatLevel .. ".")
    end

    TurtleRP.communication_prep()
    TurtleRP.send_ping_message()

    TurtleRP.RestoreMinimapIconPosition()
    TurtleRP.populate_interface_user_data()
    if TurtleRP_AdminSB_Content6_ChatNamesButton then
      TurtleRP_AdminSB_Content6_ChatNamesButton:SetChecked(TurtleRPSettings["chat_names"] == "1" and true or false)
    end
    if TurtleRP_AdminSB_Content6_ChatColorsButton then
      TurtleRP_AdminSB_Content6_ChatColorsButton:SetChecked(TurtleRPSettings["chat_colors"] == "1" and true or false)
    end

    TurtleRP.tooltip_events()
    TurtleRP.mouseover_and_target_events()
    TurtleRP.communication_events()
    TurtleRP.display_nearby_players()
	TurtleRP.chatHooksPending = true
    if TurtleRP_AdminSB_Content7_VersionText then
	  TurtleRP_AdminSB_Content7_VersionText:SetText(TurtleRP.currentVersion)
	elseif TurtleRP_AdminSB_Content6_VersionText then
	  TurtleRP_AdminSB_Content6_VersionText:SetText(TurtleRP.currentVersion)
	end
	
	StaticPopupDialogs["TTRP_DESCRIPTION_LINK"] = {
	  text = "Copy this link:",
	  button1 = "Close",
	  hasEditBox = 1,
	  maxLetters = 512,
	  editBoxWidth = 260,
	  OnShow = function()
		local linkText = TurtleRP.pendingDescriptionLink or ""
		if this.editBox then
		  this.editBox:SetText(linkText)
		  this.editBox:HighlightText()
		  this.editBox:SetFocus()
		  this.editBox:SetScript("OnEscapePressed", function()
			this:GetParent():Hide()
		  end)
		  this.editBox:SetScript("OnEnterPressed", function()
			this:HighlightText()
		  end)
		end
	  end,
	  OnAccept = function()
	  end,
	  OnHide = function()
		if this.editBox then
		  this.editBox:SetText("")
		  this.editBox:SetScript("OnEscapePressed", nil)
		  this.editBox:SetScript("OnEnterPressed", nil)
		end
		TurtleRP.pendingDescriptionLink = nil
	  end,
	  timeout = 0,
	  whileDead = 1,
	  hideOnEscape = 1,
	  preferredIndex = 3,
	};
		
    StaticPopupDialogs["TTRP_ADMIN_UNSAVED"] = {
      text = "You have unsaved changes. Continue editing, or discard them?",
      button1 = "Continue Editing",
      button2 = "Discard Changes",
      OnAccept = function()
        TurtleRP.adminPendingTabSwitch = nil
        TurtleRP.adminPendingBottomTabSwitch = nil
      end,
      OnCancel = function()
        if TurtleRP.adminPendingTabSwitch ~= nil then
          local pendingTab = TurtleRP.adminPendingTabSwitch
          TurtleRP.adminPendingTabSwitch = nil
          TurtleRP.adminPendingBottomTabSwitch = nil
          TurtleRP.populate_interface_user_data()
          TurtleRP.RefreshAdminStateSnapshot()
          TurtleRP.ApplyAdminTabClick(pendingTab)
          return
        end
        if TurtleRP.adminPendingBottomTabSwitch ~= nil then
          local pendingBottomTab = TurtleRP.adminPendingBottomTabSwitch
          TurtleRP.adminPendingBottomTabSwitch = nil
          TurtleRP.adminPendingTabSwitch = nil
          TurtleRP.populate_interface_user_data()
          TurtleRP.RefreshAdminStateSnapshot()
          TurtleRP.ApplyBottomTabAdminClick(pendingBottomTab)
          return
        end
        TurtleRP.ForceCloseAdmin()
      end,
      timeout = 0,
      whileDead = 1,
      hideOnEscape = 1,
      preferredIndex = 3,
    };
	--Here's the popup for migration.
    StaticPopupDialogs["TTRP_PROFILE_MIGRATION_COMPLETE"] = {
      text = "Welcome to " .. TurtleRP.GetDisplayVersionText() .. "!\n\nYour old character profile slots have been migrated to the new account-wide profile system.",
      button1 = "Okay",
      OnAccept = function()
        TurtleRP.pendingProfileMigrationPopup = nil
      end,
      OnCancel = function()
        TurtleRP.pendingProfileMigrationPopup = nil
      end,
      timeout = 0,
      whileDead = 1,
      hideOnEscape = 1,
      preferredIndex = 3,
    };

    StaticPopupDialogs["TTRP_DELETE_PROFILE_CONFIRM"] = {
      text = "Delete this profile?\n\nThis cannot be undone.",
      button1 = "Delete",
      button2 = "Cancel",
      OnAccept = function()
        TurtleRP.DeleteCurrentAccountProfile()
      end,
      OnCancel = function()
      end,
      timeout = 0,
      whileDead = 1,
      hideOnEscape = 1,
      preferredIndex = 3,
    };

    StaticPopupDialogs["TTRP_EXPORT_PROFILE"] = {
      text = "Copy this profile export string:",
      button1 = "Close",
      hasEditBox = 1,
      maxLetters = 4096,
      editBoxWidth = 260,
      OnShow = function()
        if this.editBox then
          this.editBox:SetText(TurtleRP.GetCurrentProfileExportString() or "")
          this.editBox:HighlightText()
          this.editBox:SetFocus()
        end
      end,
      OnAccept = function()
      end,
      OnHide = function()
        if this.editBox then
          this.editBox:SetText("")
        end
      end,
      timeout = 0,
      whileDead = 1,
      hideOnEscape = 1,
      preferredIndex = 3,
    };

        StaticPopupDialogs["TTRP_IMPORT_PROFILE"] = {
      text = "Paste a TurtleRP profile export string:",
      button1 = "Next",
      button2 = "Cancel",
      hasEditBox = 1,
      maxLetters = 4096,
      editBoxWidth = 260,
      OnAccept = function()
        local importString = ""
        local popup = this and this:GetParent() or nil
        if popup and popup.editBox then
          importString = popup.editBox:GetText() or ""
        end
        TurtleRP.BeginImportProfileFlow(importString)
      end,
      OnShow = function()
        if this.editBox then
          this.editBox:SetText("")
          this.editBox:SetWidth(260)
          this.editBox:SetFocus()
        end
      end,
      OnHide = function()
        if this.editBox then
          this.editBox:SetText("")
        end
      end,
      EditBoxOnEnterPressed = function()
        local popup = this:GetParent()
        if popup and popup.button1 then
          popup.button1:Click()
        end
      end,
      timeout = 0,
      whileDead = 1,
      hideOnEscape = 1,
      preferredIndex = 3,
    };

    StaticPopupDialogs["TTRP_IMPORT_PROFILE_NAME"] = {
      text = "What would you like to call this imported profile?",
      button1 = "Import",
      button2 = "Cancel",
      hasEditBox = 1,
      maxLetters = 50,
      editBoxWidth = 260,
      OnAccept = function()
        local requestedName = ""
        local popup = this and this:GetParent() or nil
        if popup and popup.editBox then
          requestedName = popup.editBox:GetText() or ""
        end
        TurtleRP.ImportProfileStringAsNewProfile(TurtleRP.pendingImportedProfileString, requestedName)
      end,
      OnShow = function()
        if this.editBox then
          this.editBox:SetWidth(260)
          this.editBox:SetFocus()
        end
      end,
      OnHide = function()
        if this.editBox then
          this.editBox:SetText("")
        end
      end,
      EditBoxOnEnterPressed = function()
        local popup = this:GetParent()
        if popup and popup.button1 then
          popup.button1:Click()
        end
      end,
      timeout = 0,
      whileDead = 1,
      hideOnEscape = 1,
      preferredIndex = 3,
    };
	
	    StaticPopupDialogs["TTRP_EXPORT_PET_PROFILE"] = {
      text = "Copy this pet profile export string:",
      button1 = "Close",
      hasEditBox = 1,
      maxLetters = 4096,
      editBoxWidth = 260,
      OnShow = function()
        if this.editBox then
          this.editBox:SetText(TurtleRP.GetCurrentPetProfileExportString() or "")
          this.editBox:HighlightText()
          this.editBox:SetFocus()
        end
      end,
      OnAccept = function()
      end,
      OnHide = function()
        if this.editBox then
          this.editBox:SetText("")
        end
      end,
      timeout = 0,
      whileDead = 1,
      hideOnEscape = 1,
      preferredIndex = 3,
    };

    StaticPopupDialogs["TTRP_IMPORT_PET_PROFILE"] = {
      text = "Paste a TurtleRP pet profile export string:",
      button1 = "Next",
      button2 = "Cancel",
      hasEditBox = 1,
      maxLetters = 4096,
      editBoxWidth = 260,
      OnAccept = function()
        local importString = ""
        local popup = this and this:GetParent() or nil
        if popup and popup.editBox then
          importString = popup.editBox:GetText() or ""
        end
        TurtleRP.BeginImportPetProfileFlow(importString)
      end,
      OnShow = function()
        if this.editBox then
          this.editBox:SetText("")
          this.editBox:SetWidth(260)
          this.editBox:SetFocus()
        end
      end,
      OnHide = function()
        if this.editBox then
          this.editBox:SetText("")
        end
      end,
      EditBoxOnEnterPressed = function()
        local popup = this:GetParent()
        if popup and popup.button1 then
          popup.button1:Click()
        end
      end,
      timeout = 0,
      whileDead = 1,
      hideOnEscape = 1,
      preferredIndex = 3,
    };

    StaticPopupDialogs["TTRP_IMPORT_PET_PROFILE_NAME"] = {
      text = "What would you like to call this imported pet profile?",
      button1 = "Import",
      button2 = "Cancel",
      hasEditBox = 1,
      maxLetters = 50,
      editBoxWidth = 260,
      OnAccept = function()
        local requestedName = ""
        local popup = this and this:GetParent() or nil
        if popup and popup.editBox then
          requestedName = popup.editBox:GetText() or ""
        end
        TurtleRP.ImportPetProfileStringAsNewProfile(TurtleRP.pendingImportedPetProfileString, requestedName)
      end,
      OnShow = function()
        if this.editBox then
          this.editBox:SetWidth(260)
          this.editBox:SetFocus()
        end
      end,
      OnHide = function()
        if this.editBox then
          this.editBox:SetText("")
        end
      end,
      EditBoxOnEnterPressed = function()
        local popup = this:GetParent()
        if popup and popup.button1 then
          popup.button1:Click()
        end
      end,
      timeout = 0,
      whileDead = 1,
      hideOnEscape = 1,
      preferredIndex = 3,
    };

	StaticPopupDialogs["TTRP_NSFW_DETECTED_CONFIRM"] = {
	  text = "Possible NSFW text was detected in this profile.\n\nContent considered NSFW that is not marked could lead to escalation. Mark NSFW?",
	  button1 = "Mark NSFW",
	  button2 = "Keep SFW",
	  button3 = "Cancel",
	  OnAccept = function()
		if TurtleRP_AdminSB_Content1_NSFWButton then
		  TurtleRP_AdminSB_Content1_NSFWButton:SetChecked(true)
		end
		TurtleRP.RunPendingNSFWSave()
	  end,
	  OnCancel = function()
		TurtleRP.pendingNSFWOverride = "allow_sfw"
		TurtleRP.RunPendingNSFWSave()
	  end,
	  OnAlt = function()
		TurtleRP.pendingNSFWSaveCallback = nil
		TurtleRP.pendingNSFWKeyword = nil
		TurtleRP.pendingNSFWOverride = nil
	  end,
	  timeout = 0,
	  whileDead = 1,
	  hideOnEscape = 1,
	  preferredIndex = 3,
	};
	
    -- Slash commands
    SLASH_TURTLERP1 = "/ttrp"
    function SlashCmdList.TURTLERP(msg)
      local trimmed = msg or ""
      local lowerMsg = string.lower(trimmed)
      if lowerMsg == "help" then
        TurtleRP.log("|cff8C48AB/ttrp|r - open admin panel")
        TurtleRP.log("|cff8C48AB/ttrp dir|r - open directory panel")
        TurtleRP.log("|cff8C48AB/ttrp tray|r - reset the icon tray position")
        TurtleRP.log("|cff8C48AB/ttrp minimapreset|r - reset the minimap icon position")
        TurtleRP.log("|cff8C48AB/ttrp closemap|r - close the world map")
        TurtleRP.log("|cff8C48AB/ttrp petcreate|r - create and assign a new pet profile from your current target")
        TurtleRP.log("|cff8C48AB/ttrp petassign <profile name>|r - assign an existing pet profile to your current target")
        TurtleRP.log("|cff8C48AB/ttrp petlist|r - list profiles for your current target")
        TurtleRP.log("|cff8C48AB/ttrp petopen|r - open the assigned pet profile for your current target")
        TurtleRP.log("|cff8C48AB/ttrp petcurrent|r - show the currently assigned pet profile for your current target")
        TurtleRP.log("Visit our Discord for more help.")

      elseif lowerMsg == "dir" or lowerMsg == "directory" then
        TurtleRP.OpenDirectory()
      elseif lowerMsg == "tray" then
         TurtleRP_IconTray:ClearAllPoints()
         TurtleRP_IconTray:SetPoint("CENTER", "UIParent")
         TurtleRP_IconTray:Show()
      elseif lowerMsg == "minimapreset" or lowerMsg == "resetminimap" or lowerMsg == "mmreset" then
         TurtleRP.ResetMinimapIconPosition()
         DEFAULT_CHAT_FRAME:AddMessage("|cff66CC66[TurtleRP]|r Minimap icon reset.")
      elseif lowerMsg == "closemap" or lowerMsg == "mapclose" or lowerMsg == "closeworldmap" then
         if TurtleRP.CloseWorldMap() then
            DEFAULT_CHAT_FRAME:AddMessage("|cff66CC66[TurtleRP]|r World map closed.")
         else
            DEFAULT_CHAT_FRAME:AddMessage("|cffFFCC66[TurtleRP]|r World map was not open.")
         end
--Mainly for debugging but like.... might as well keep? This is all stuff for pet profiles.
      elseif lowerMsg == "petcreate" then
        TurtleRP.CreatePetProfileFromTarget()
      elseif string.find(lowerMsg, "^petassign%s+") then
        local profileName = string.gsub(trimmed, "^%s*[Pp][Ee][Tt][Aa][Ss][Ss][Ii][Gg][Nn]%s+", "")
        if profileName == nil or profileName == "" then
          DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r Usage: /ttrp petassign <profile name>")
        else
          TurtleRP.AssignExistingPetProfileToTarget(profileName)
        end
      elseif lowerMsg == "petlist" then
        local petUID = TurtleRP.GetPetUID("target")
        local entry = petUID and TurtleRPPetProfiles and TurtleRPPetProfiles[petUID] or nil
        local foundAny = nil
        if not TurtleRP.IsOwnedPetUnit("target") then
          DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r You must target your own pet.")
          return
        end
        if not entry or not entry["profiles"] then
          DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r No pet profiles found for that target.")
          return
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff66CC66[TurtleRP]|r Pet profiles for current target:")
        for profileName, profileData in pairs(entry["profiles"]) do
          local marker = ""
          if entry["assignedProfile"] == profileName then
            marker = " |cff8C48AB(assigned)|r"
          end
          DEFAULT_CHAT_FRAME:AddMessage(" - " .. profileName .. marker)
          foundAny = true
        end
        if not foundAny then
          DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r No pet profiles found for that target.")
        end

      elseif lowerMsg == "petopen" then
        local petUID = TurtleRP.GetPetUID("target")
        local profile = petUID and TurtleRP.GetAssignedPetProfile and TurtleRP.GetAssignedPetProfile(petUID) or nil
        if not TurtleRP.IsOwnedPetUnit("target") then
          DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r You must target your own pet.")
          return
        end
        if not petUID or not profile then
          DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r No assigned pet profile found for that target.")
          return
        end
        TurtleRP.OpenPetProfile(petUID, "general")
      elseif lowerMsg == "petcurrent" then
        local profile, petUID, profileName = TurtleRP.GetPetProfileFromUnit("target")
        if not TurtleRP.IsOwnedPetUnit("target") then
          DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r You must target your own pet.")
          return
        end
        if not profile or not petUID then
          DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r No assigned pet profile found for that target.")
          return
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff66CC66[TurtleRP]|r Current pet UID: " .. petUID)
        DEFAULT_CHAT_FRAME:AddMessage("|cff66CC66[TurtleRP]|r Assigned profile: " .. (profileName or "unknown"))
        DEFAULT_CHAT_FRAME:AddMessage("|cff66CC66[TurtleRP]|r Display name: " .. (profile["name"] or ""))
      else
        TurtleRP.OpenAdmin()
      end
    end
  end
end

TurtleRP_Parent:SetScript("OnEvent", TurtleRP.OnEvent)

function TurtleRP.ShowDeleteSelectedAccountProfilePopup()
    local dropdown = TurtleRP_AdminSB_Content5_ProfileDropdown
    local selected = dropdown and UIDropDownMenu_GetSelectedValue(dropdown)
    if not selected or selected == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[TurtleRP]|r No profile selected.")
        return
    end
    StaticPopupDialogs["TURTLERP_DELETE_SELECTED_PROFILE"] = {
        text = "Delete selected profile: " .. selected .. "?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            local fallbackProfileName = TurtleRP.DeleteAccountProfile(selected)
            if fallbackProfileName == nil then
                DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r You cannot delete your last remaining profile.")
                TurtleRP.RefreshProfilesTab()
                return
            end
            if TurtleRP.GetBoundProfileName(UnitName("player")) ~= selected then
                TurtleRP.populate_interface_user_data()
                TurtleRP.RefreshProfilesTab()
                TurtleRP.RefreshAdminStateSnapshot()
                return
            end
            TurtleRP.BindProfileToCharacter(UnitName("player"), fallbackProfileName)
            TurtleRP.populate_interface_user_data()
            TurtleRP.RefreshProfilesTab()
            TurtleRP.RefreshAdminStateSnapshot()
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
    StaticPopup_Show("TURTLERP_DELETE_SELECTED_PROFILE")
end
-----
-- Building interfaces to display data
-----
function TurtleRP.SetTargetFrameText(primaryText, secondaryText)
  local targetWidth = 100
  TurtleRP_Target_TargetName:SetText(primaryText or "")
  if TurtleRP_Target_TargetSubText then
    if secondaryText and secondaryText ~= "" then
      TurtleRP_Target_TargetSubText:SetText(secondaryText)
      TurtleRP_Target_TargetSubText:Show()
      targetWidth = math.max(targetWidth, TurtleRP_Target_TargetSubText:GetStringWidth() or 0)
    else
      TurtleRP_Target_TargetSubText:SetText("")
      TurtleRP_Target_TargetSubText:Hide()
    end
  end
  targetWidth = math.max(targetWidth, TurtleRP_Target_TargetName:GetStringWidth() or 0)
  TurtleRP_Target:SetWidth(targetWidth + 40)
end

function TurtleRP.SaveTargetCurrently(skipClearFocus)
  if not TurtleRP_Target_CurrentlyInput then
    return
  end
  if TurtleRP.savingTargetCurrently then
    return
  end
  TurtleRP.savingTargetCurrently = true
  local currently = TurtleRP_Target_CurrentlyInput:GetText() or ""
  TurtleRPCharacterInfo["currently"] = TurtleRP.validateBeforeSaving(currently) or ""
  TurtleRPCharacterInfo["keyT"] = TurtleRP.randomchars()
  TurtleRPCharacters[UnitName("player")] = TurtleRPCharacterInfo
  TurtleRP.SyncBoundProfile(UnitName("player"))
  if not skipClearFocus then
    TurtleRP_Target_CurrentlyInput:ClearFocus()
  end
  if UnitExists("target") and UnitName("target") == UnitName("player") then
    TurtleRP.buildTargetFrame(UnitName("player"))
  end
  TurtleRP.savingTargetCurrently = nil
end

function TurtleRP.BuildTargetAtAGlanceFromData(data)
  TurtleRP_Target_AtAGlance1:Hide()
  if data["atAGlance1Icon"] ~= "" then
    local tex = TurtleRP.GetIconTexture(data["atAGlance1Icon"])
    if tex then
      TurtleRP_Target_AtAGlance1_Icon:SetTexture(tex)
      TurtleRP_Target_AtAGlance1_TextPanel_TitleText:SetText(data["atAGlance1Title"] or "")
      TurtleRP_Target_AtAGlance1_TextPanel_Text:SetText(data["atAGlance1"] or "")
      TurtleRP_Target_AtAGlance1:Show()
    end
  end
  TurtleRP_Target_AtAGlance2:Hide()
  if data["atAGlance2Icon"] ~= "" then
    local tex = TurtleRP.GetIconTexture(data["atAGlance2Icon"])
    if tex then
      TurtleRP_Target_AtAGlance2_Icon:SetTexture(tex)
      TurtleRP_Target_AtAGlance2_TextPanel_TitleText:SetText(data["atAGlance2Title"] or "")
      TurtleRP_Target_AtAGlance2_TextPanel_Text:SetText(data["atAGlance2"] or "")
      TurtleRP_Target_AtAGlance2:Show()
    end
  end
  TurtleRP_Target_AtAGlance3:Hide()
  if data["atAGlance3Icon"] ~= "" then
    local tex = TurtleRP.GetIconTexture(data["atAGlance3Icon"])
    if tex then
      TurtleRP_Target_AtAGlance3_Icon:SetTexture(tex)
      TurtleRP_Target_AtAGlance3_TextPanel_TitleText:SetText(data["atAGlance3Title"] or "")
      TurtleRP_Target_AtAGlance3_TextPanel_Text:SetText(data["atAGlance3"] or "")
      TurtleRP_Target_AtAGlance3:Show()
    end
  end
end

function TurtleRP.buildTargetFrame(playerName)
  local characterInfo = TurtleRPCharacters[playerName]
  local isSelfTarget = playerName == UnitName("player")
  TurtleRP_Target:Hide()
  if TurtleRP_Target_CurrentlyInput then
    TurtleRP_Target_CurrentlyInput:Hide()
    TurtleRP_Target_CurrentlyInput:ClearFocus()
  end
  if TurtleRP_Target_TargetSubText then
    TurtleRP_Target_TargetSubText:Show()
  end
  if not characterInfo or characterInfo["keyT"] == nil then
    return
  end
  local displayName = characterInfo["full_name"] or playerName or ""
  if characterInfo["title"] and characterInfo["title"] ~= "" then
    displayName = characterInfo["title"] .. " " .. displayName
  end
  TurtleRP.BuildTargetAtAGlanceFromData(characterInfo)
  if isSelfTarget and TurtleRP_Target_CurrentlyInput then
    TurtleRP.SetTargetFrameText(displayName, "")
    TurtleRP_Target_TargetSubText:Hide()
    TurtleRP_Target_CurrentlyInput:SetText(characterInfo["currently"] or "")
    TurtleRP_Target_CurrentlyInput:Show()
    TurtleRP_Target:SetWidth(math.max(TurtleRP_Target:GetWidth() or 0, 190))
  else
    TurtleRP.SetTargetFrameText(displayName, characterInfo["currently"] or "")
  end
  TurtleRP_Target:Show()
end

function TurtleRP.buildPetTargetFrame(petData)
  TurtleRP_Target:Hide()

  if not petData or petData["keyT"] == nil then
    return
  end
  local petName = petData["name"] or "Pet"
  local petSub = ""
  if petData["level"] and petData["level"] ~= "" and petData["species"] and petData["species"] ~= "" then
    petSub = "Level " .. petData["level"] .. " " .. petData["species"]
  elseif petData["species"] and petData["species"] ~= "" then
    petSub = petData["species"]
  elseif petData["level"] and petData["level"] ~= "" then
    petSub = "Level " .. petData["level"]
  end
  TurtleRP.BuildTargetAtAGlanceFromData(petData)
  TurtleRP.SetTargetFrameText(petName, petSub)
  TurtleRP_Target:Show()
end

function TurtleRP.NormalizePetCommPart(value)
  local text = string.lower(tostring(value or ""))
  text = string.gsub(text, "[~:§°|]", "")
  text = string.gsub(text, "%s+", "")
  return text
end

local TurtleRP_PetOwnerScanTooltip = nil

function TurtleRP.GetPetOwnerNameFromUnit(unit)
  if not unit or unit == "" or not UnitExists(unit) then
    return nil
  end
  if UnitIsUnit and UnitExists("pet") and UnitIsUnit(unit, "pet") then
    return UnitName("player")
  end
  if not TurtleRP_PetOwnerScanTooltip then
    TurtleRP_PetOwnerScanTooltip = CreateFrame("GameTooltip", "TurtleRPPetOwnerScanTooltip", UIParent, "GameTooltipTemplate")
    TurtleRP_PetOwnerScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
  end

  TurtleRP_PetOwnerScanTooltip:ClearLines()
  TurtleRP_PetOwnerScanTooltip:SetUnit(unit)
  local i
  for i = 2, 8 do
    local line = getglobal("TurtleRPPetOwnerScanTooltipTextLeft" .. i)
    local text = line and line:GetText() or nil
    local ownerName = nil

    if text and text ~= "" then
      _, _, ownerName = string.find(text, "^Companion of (.+)$")
      if not ownerName then _, _, ownerName = string.find(text, "^Pet of (.+)$") end
      if not ownerName then _, _, ownerName = string.find(text, "^Minion of (.+)$") end
      if not ownerName then _, _, ownerName = string.find(text, "^(.+)'s Companion$") end
      if not ownerName then _, _, ownerName = string.find(text, "^(.+)'s Pet$") end
      if not ownerName then _, _, ownerName = string.find(text, "^(.+)'s Minion$") end

      if ownerName and ownerName ~= "" then
        TurtleRP_PetOwnerScanTooltip:Hide()
        return ownerName
      end
    end
  end
  TurtleRP_PetOwnerScanTooltip:Hide()
  return nil
end

function TurtleRP.BuildPetCommKey(petName, petSpecies)
  local namePart = TurtleRP.NormalizePetCommPart(petName)
  local speciesPart = TurtleRP.NormalizePetCommPart(petSpecies)
  if namePart == "" then
    return nil
  end
  if speciesPart ~= "" then
    return "pet_" .. namePart .. "_" .. speciesPart
  end
  return "pet_" .. namePart
end

function TurtleRP.GetPetCommKeyFromUnit(unit)
  if not unit or unit == "" or not UnitExists(unit) then
    return nil
  end
  local petName = UnitName(unit) or ""
  local petSpecies = TurtleRP.GetPetTypeFromUnit and TurtleRP.GetPetTypeFromUnit(unit) or ""
  if petName == "" then
    return nil
  end
  return TurtleRP.BuildPetCommKey(petName, petSpecies)
end

function TurtleRP.GetLocalPetProfileForCommKey(commKey)
  if not commKey or commKey == "" or not TurtleRPPetProfiles then
    return nil
  end
  local petUID, entry
  for petUID, entry in pairs(TurtleRPPetProfiles) do
    if entry and entry["assignedProfile"] and entry["profiles"] and entry["profiles"][entry["assignedProfile"]] then
      local profile = entry["profiles"][entry["assignedProfile"]]

      local profileKey = TurtleRP.BuildPetCommKey(
        profile["unit_name"] or profile["name"] or "",
        profile["unit_species"] or profile["species"] or ""
      )
      if profileKey and profileKey == commKey then
        return profile, petUID
      end

      if profile["comm_id"] and profile["comm_id"] ~= "" and profile["comm_id"] == commKey then
        return profile, petUID
      end
    end
  end
  if UnitExists and UnitExists("pet") and TurtleRP.IsOwnedPetUnit and TurtleRP.IsOwnedPetUnit("pet") then
    local liveUID = TurtleRP.GetPetUID and TurtleRP.GetPetUID("pet") or nil
    local liveEntry = liveUID and TurtleRPPetProfiles[liveUID] or nil
    if liveEntry and liveEntry["assignedProfile"] and liveEntry["profiles"] and liveEntry["profiles"][liveEntry["assignedProfile"]] then
      local liveProfile = liveEntry["profiles"][liveEntry["assignedProfile"]]
      local liveKey = TurtleRP.BuildPetCommKey(
        UnitName("pet") or liveProfile["unit_name"] or liveProfile["name"] or "",
        (TurtleRP.GetPetTypeFromUnit and TurtleRP.GetPetTypeFromUnit("pet")) or liveProfile["unit_species"] or liveProfile["species"] or ""
      )
      if liveKey and liveKey == commKey then
        liveProfile["unit_name"] = UnitName("pet") or liveProfile["unit_name"] or liveProfile["name"] or ""
        liveProfile["unit_species"] = (TurtleRP.GetPetTypeFromUnit and TurtleRP.GetPetTypeFromUnit("pet")) or liveProfile["unit_species"] or liveProfile["species"] or ""
        liveProfile["level"] = (TurtleRP.GetPetLevelFromUnit and TurtleRP.GetPetLevelFromUnit("pet")) or liveProfile["level"] or ""
        liveProfile["comm_id"] = liveKey
        return liveProfile, liveUID
      end
    end
  end
  if UnitExists and UnitExists("target") and TurtleRP.IsOwnedPetUnit and TurtleRP.IsOwnedPetUnit("target") then
    local targetUID = TurtleRP.GetPetUID and TurtleRP.GetPetUID("target") or nil
    local targetEntry = targetUID and TurtleRPPetProfiles[targetUID] or nil
    if targetEntry and targetEntry["assignedProfile"] and targetEntry["profiles"] and targetEntry["profiles"][targetEntry["assignedProfile"]] then
      local targetProfile = targetEntry["profiles"][targetEntry["assignedProfile"]]
      local targetKey = TurtleRP.BuildPetCommKey(
        UnitName("target") or targetProfile["unit_name"] or targetProfile["name"] or "",
        (TurtleRP.GetPetTypeFromUnit and TurtleRP.GetPetTypeFromUnit("target")) or targetProfile["unit_species"] or targetProfile["species"] or ""
      )
      if targetKey and targetKey == commKey then
        targetProfile["unit_name"] = UnitName("target") or targetProfile["unit_name"] or targetProfile["name"] or ""
        targetProfile["unit_species"] = (TurtleRP.GetPetTypeFromUnit and TurtleRP.GetPetTypeFromUnit("target")) or targetProfile["unit_species"] or targetProfile["species"] or ""
        targetProfile["level"] = (TurtleRP.GetPetLevelFromUnit and TurtleRP.GetPetLevelFromUnit("target")) or targetProfile["level"] or ""
        targetProfile["comm_id"] = targetKey
        return targetProfile, targetUID
      end
    end
  end
  return nil
end

-----
-- Populate data
-----
function TurtleRP.populate_interface_user_data()
  TurtleRP_AdminSB_Content1_NameInput:SetText(TurtleRPCharacterInfo["full_name"])
  TurtleRP_AdminSB_Content1_RaceInput:SetText(TurtleRPCharacterInfo["race"])
  TurtleRP_AdminSB_Content1_ClassInput:SetText(TurtleRPCharacterInfo["class"])
	TurtleRP_AdminSB_Content1_TitleInput:SetText(TurtleRPCharacterInfo["title"] or "")
  local r, g, b = TurtleRP.hex2rgb(TurtleRPCharacterInfo['class_color'])
  TurtleRP_AdminSB_Content1_ClassColorButton:SetBackdropColor(r, g, b)
  TurtleRP_AdminSB_Content1_ICScrollBox_ICInfoInput:SetText(TurtleRPCharacterInfo["ic_info"])
  TurtleRP_AdminSB_Content1_OOCScrollBox_OOCInfoInput:SetText(TurtleRPCharacterInfo["ooc_info"])
  TurtleRP_AdminSB_Content1_ICPronounsInput:SetText(TurtleRPCharacterInfo["ic_pronouns"])
  TurtleRP_AdminSB_Content1_OOCPronounsInput:SetText(TurtleRPCharacterInfo["ooc_pronouns"])
  if TurtleRP_AdminSB_Content1_CurrentlyInput then
    TurtleRP_AdminSB_Content1_CurrentlyInput:SetText(TurtleRPCharacterInfo["currently"] or "")
  end
  TurtleRP.setCharacterIcon()
  TurtleRP.pendingFactionSelection = nil
  TurtleRP.updateFactionButton()
  TurtleRP_AdminSB_Content2_AtAGlance1ScrollBox_AAG1Input:SetText(TurtleRPCharacterInfo["atAGlance1"])
  TurtleRP_AdminSB_Content2_AAG1TitleInput:SetText(TurtleRPCharacterInfo["atAGlance1Title"])
  TurtleRP_AdminSB_Content2_AtAGlance2ScrollBox_AAG2Input:SetText(TurtleRPCharacterInfo["atAGlance2"])
  TurtleRP_AdminSB_Content2_AAG2TitleInput:SetText(TurtleRPCharacterInfo["atAGlance2Title"])
  TurtleRP_AdminSB_Content2_AtAGlance3ScrollBox_AAG3Input:SetText(TurtleRPCharacterInfo["atAGlance3"])
  TurtleRP_AdminSB_Content2_AAG3TitleInput:SetText(TurtleRPCharacterInfo["atAGlance3Title"])
  TurtleRP.setAtAGlanceIcons()
	local replacedLineBreaks = gsub(TurtleRPCharacterInfo["description"], "@N", "%\n")
	TurtleRP_AdminSB_Content3_DescriptionScrollBox_DescriptionInput:SetText(replacedLineBreaks)
	if TurtleRP_AdminSB_Content3_LinkTextInput then
	  TurtleRP_AdminSB_Content3_LinkTextInput:SetText(TurtleRPCharacterInfo["description_link_text"] or "")
	end
	if TurtleRP_AdminSB_Content3_LinkInput then
	  TurtleRP_AdminSB_Content3_LinkInput:SetText(TurtleRPCharacterInfo["description_link"] or "")
	end
  TurtleRP_AdminSB_Content4_NotesScrollBox_NotesInput:SetText(TurtleRPCharacterInfo["notes"])
  TurtleRP_AdminSB_Content4_ShortNoteBox_Input:SetText(TurtleRPCharacterInfo["short_note"] or "")

  if _G["TurtleRP_AdminSB_Content1_GuildOverrideInput"] then
    _G["TurtleRP_AdminSB_Content1_GuildOverrideInput"]:SetText(TurtleRPCharacterInfo["guild_override"] or "")
  end
  if _G["TurtleRP_AdminSB_Content1_GuildICButton"] then
    _G["TurtleRP_AdminSB_Content1_GuildICButton"]:SetChecked(TurtleRPCharacterInfo["guild_ic"] == "1")
  end
  if _G["TurtleRP_AdminSB_Content1_GuildOOCButton"] then
    _G["TurtleRP_AdminSB_Content1_GuildOOCButton"]:SetChecked(TurtleRPCharacterInfo["guild_ooc"] == "1")
  end

  TurtleRP_AdminSB_Content6_PVPButton:SetChecked(TurtleRPSettings["bgs"] == "on" and true or false)
  TurtleRP_AdminSB_Content6_NameButton:SetChecked(TurtleRPSettings["name_size"] == "1" and true or false)

  if TurtleRPCharacterInfo["nsfw"] == "1" then
    TurtleRP_AdminSB_Content1_NSFWButton:SetChecked(true)
  else
    TurtleRP_AdminSB_Content1_NSFWButton:SetChecked(false)
  end

  if TurtleRPCharacterInfo["currently_ic"] == "1" then
    TurtleRP_AdminSB_Content1_ICButton:SetChecked(true)
    TurtleRP_IconTray_ICModeButton2:Show()
    TurtleRP_IconTray_ICModeButton:Hide()
  else
    TurtleRP_AdminSB_Content1_ICButton:SetChecked(false)
    TurtleRP_IconTray_ICModeButton:Show()
    TurtleRP_IconTray_ICModeButton2:Hide()
  end

  if TurtleRPSettings["tray"] == "1" then
    TurtleRP_AdminSB_Content6_TrayButton:SetChecked(true)
    TurtleRP_IconTray:Show()
  end

  TurtleRP_AdminSB_Content6_HideMinimapButton:SetChecked(TurtleRPSettings["hide_minimap_icon"] ~= "1" and true or false)

  if TurtleRPSettings["share_location"] == "1" then
    TurtleRP_AdminSB_Content6_ShareLocationButton:SetChecked(true)
  else
    TurtleRP_AdminSB_Content6_ShareLocationButton:SetChecked(false)
  end

  TurtleRP.RefreshMinimapIconState()
  if TurtleRPSettings["show_nsfw"] == "1" then
    TurtleRP_AdminSB_Content6_ShowNSFWButton:SetChecked(true)
  else
    TurtleRP_AdminSB_Content6_ShowNSFWButton:SetChecked(false)
  end
  if TurtleRPSettings["chat_names"] == "1" then
    TurtleRP_AdminSB_Content6_ChatNamesButton:SetChecked(true)
  else
    TurtleRP_AdminSB_Content6_ChatNamesButton:SetChecked(false)
  end
  if TurtleRPSettings["chat_colors"] == "1" then
    TurtleRP_AdminSB_Content6_ChatColorsButton:SetChecked(true)
  else
    TurtleRP_AdminSB_Content6_ChatColorsButton:SetChecked(false)
  end

  if _G["TurtleRP_AdminSB_Content6_DisableTooltipButton"] then
    if TurtleRPSettings["disable_tooltip"] == "1" then
      TurtleRP_AdminSB_Content6_DisableTooltipButton:SetChecked(true)
    else
      TurtleRP_AdminSB_Content6_DisableTooltipButton:SetChecked(false)
    end
  end
  if _G["TurtleRP_AdminSB_Content6_DisableTooltipBGButton"] then
    if TurtleRPSettings["disable_tooltip_bg"] == "1" then
      TurtleRP_AdminSB_Content6_DisableTooltipBGButton:SetChecked(true)
    else
      TurtleRP_AdminSB_Content6_DisableTooltipBGButton:SetChecked(false)
    end
  end
  if TurtleRP.RefreshAltIdentifierUI then
    TurtleRP.RefreshAltIdentifierUI()
  end
end

local function TurtleRP_SetIconButtonBackdrop(button, iconIndex)
  local tex = TurtleRP.GetIconTexture(iconIndex)
  if tex then
    button:SetBackdrop({
      bgFile = tex
    })
  else
    button:SetBackdrop({
      bgFile = "Interface\\Buttons\\UI-EmptySlot-White"
    })
  end
end

function TurtleRP.setCharacterIcon()
  local pendingIcons = TurtleRP_IconSelector and TurtleRP_IconSelector.selectedIconIndex
  local iconIndex = pendingIcons and pendingIcons["icon"] or TurtleRPCharacterInfo["icon"]
  TurtleRP_SetIconButtonBackdrop(TurtleRP_AdminSB_Content1_IconButton, iconIndex)
end

function TurtleRP.setAtAGlanceIcons()
  local pendingIcons = TurtleRP_IconSelector and TurtleRP_IconSelector.selectedIconIndex or {}
  local profile = nil
  if TurtleRP.editingPetAtAGlance == 1 and TurtleRP.GetCurrentAdminPetProfile then
    profile = TurtleRP.GetCurrentAdminPetProfile()
  end
  if not profile then
    profile = TurtleRPCharacters[UnitName("player")]
  end
  profile = profile or {}
  TurtleRP_SetIconButtonBackdrop(
    TurtleRP_AdminSB_Content2_AAG1IconButton,
    pendingIcons["atAGlance1Icon"] ~= nil and pendingIcons["atAGlance1Icon"] or profile["atAGlance1Icon"]
  )
  TurtleRP_SetIconButtonBackdrop(
    TurtleRP_AdminSB_Content2_AAG2IconButton,
    pendingIcons["atAGlance2Icon"] ~= nil and pendingIcons["atAGlance2Icon"] or profile["atAGlance2Icon"]
  )
  TurtleRP_SetIconButtonBackdrop(
    TurtleRP_AdminSB_Content2_AAG3IconButton,
    pendingIcons["atAGlance3Icon"] ~= nil and pendingIcons["atAGlance3Icon"] or profile["atAGlance3Icon"]
  )
end

-- Legacy helper kept for a bit so older calls dont explode lol
function TurtleRP.SetProfileDropdown()
  return
end

-- Profile preview
function TurtleRP.CopyTableShallow(source)
  local copy = {}
  if not source then
    return copy
  end
  for k, v in pairs(source) do
    if type(v) == "table" then
      local childCopy = {}
      for childK, childV in pairs(v) do
        childCopy[childK] = childV
      end
      copy[k] = childCopy
    else
      copy[k] = v
    end
  end
  return copy
end

function TurtleRP.NormalizeCharacterProfile(profile)
  local localizedClass, classToken = UnitClass("player")
  local className, classData

  if not profile or type(profile) ~= "table" then
    return profile
  end

  if not profile["keyM"] or profile["keyM"] == "" then
    profile["keyM"] = TurtleRP.randomchars()
  end
  if not profile["keyT"] or profile["keyT"] == "" then
    profile["keyT"] = TurtleRP.randomchars()
  end
  if not profile["keyD"] or profile["keyD"] == "" then
    profile["keyD"] = TurtleRP.randomchars()
  end

  if profile["nsfw"] == nil then
    profile["nsfw"] = "0"
  end
  if profile["icon"] == nil then
    profile["icon"] = ""
  end
  if profile["title"] == nil then
    profile["title"] = ""
  end

  if profile["full_name"] == nil then
    profile["full_name"] = ""
  end
  if profile["race"] == nil then
    profile["race"] = ""
  end
  if profile["class"] == nil then
    profile["class"] = ""
  end
  if profile["class_token"] == nil then
    profile["class_token"] = ""
  end

  className = profile["class"]
  classData = nil
  if className ~= "" and TurtleRPClassData then
    classData = TurtleRPClassData[className]
  end
  if profile["class_color"] == nil then
    profile["class_color"] = (classData and classData[4]) or ""
  end

  if profile["faction"] == nil or profile["faction"] == "" then
    profile["faction"] = TurtleRP.getFactionDefault()
  end
  if profile["ic_info"] == nil then
    profile["ic_info"] = ""
  end
  if profile["ooc_info"] == nil then
    profile["ooc_info"] = ""
  end
  if profile["ic_pronouns"] == nil then
    profile["ic_pronouns"] = ""
  end
  if profile["ooc_pronouns"] == nil then
    profile["ooc_pronouns"] = ""
  end
  if profile["currently_ic"] == nil or profile["currently_ic"] == "" then
    profile["currently_ic"] = "1"
  end

  if profile["notes"] == nil then
    profile["notes"] = ""
  end
  if profile["short_note"] == nil then
    profile["short_note"] = ""
  end
  if profile["currently"] == nil then
    profile["currently"] = ""
  end

  if profile["atAGlance1"] == nil then profile["atAGlance1"] = "" end
  if profile["atAGlance1Title"] == nil then profile["atAGlance1Title"] = "" end
  if profile["atAGlance1Icon"] == nil then profile["atAGlance1Icon"] = "" end
  if profile["atAGlance2"] == nil then profile["atAGlance2"] = "" end
  if profile["atAGlance2Title"] == nil then profile["atAGlance2Title"] = "" end
  if profile["atAGlance2Icon"] == nil then profile["atAGlance2Icon"] = "" end
  if profile["atAGlance3"] == nil then profile["atAGlance3"] = "" end
  if profile["atAGlance3Title"] == nil then profile["atAGlance3Title"] = "" end
  if profile["atAGlance3Icon"] == nil then profile["atAGlance3Icon"] = "" end

  if profile["experience"] == nil then profile["experience"] = "z" end
  if profile["walkups"] == nil then profile["walkups"] = "z" end
  if profile["combat"] == nil then profile["combat"] = "z" end
  if profile["injury"] == nil then profile["injury"] = "z" end
  if profile["romance"] == nil then profile["romance"] = "z" end
  if profile["death"] == nil then profile["death"] = "z" end

  if profile["description"] == nil then
    profile["description"] = ""
  end
  if profile["description_link_text"] == nil then
    profile["description_link_text"] = ""
  end
  if profile["description_link"] == nil then
    profile["description_link"] = ""
  end
  if profile["guild_override"] == nil then
    profile["guild_override"] = ""
  end
  if profile["guild_ic"] == nil then
    profile["guild_ic"] = "0"
  end
  if profile["guild_ooc"] == nil then
    profile["guild_ooc"] = "0"
  end

  if profile["character_notes"] == nil then
    profile["character_notes"] = {}
  end
  if profile["character_short_notes"] == nil then
    profile["character_short_notes"] = {}
  end
  if profile["character_disable_rp_color"] == nil then
    profile["character_disable_rp_color"] = {}
  end

  return profile
end
-- Pet functionality
function TurtleRP.IsOwnedPetUnit(unit)
  local ownerName = nil
  if not unit or unit == "" or not UnitExists(unit) then
    return false
  end
  if UnitIsPlayer and UnitIsPlayer(unit) then
    return false
  end
  if UnitIsUnit and UnitExists("pet") and UnitIsUnit(unit, "pet") then
    return true
  end
  if UnitIsOwnedByPlayer and UnitIsOwnedByPlayer(unit) then
    return true
  end
  if UnitPlayerControlled and UnitPlayerControlled(unit) and not UnitIsPlayer(unit) then
    return true
  end
  if TurtleRP.GetPetOwnerNameFromUnit then
    ownerName = TurtleRP.GetPetOwnerNameFromUnit(unit)
    if ownerName and ownerName ~= "" then
      return true
    end
  end
  return false
end

function TurtleRP.GetPetTypeFromUnit(unit)
  if not unit or unit == "" or not UnitExists(unit) then
    return ""
  end
  if UnitCreatureFamily and UnitCreatureFamily(unit) and UnitCreatureFamily(unit) ~= "" then
    return UnitCreatureFamily(unit)
  end
  if UnitCreatureType and UnitCreatureType(unit) and UnitCreatureType(unit) ~= "" then
    return UnitCreatureType(unit)
  end
  return ""
end

function TurtleRP.GetPetLevelFromUnit(unit)
  if not unit or unit == "" or not UnitExists(unit) then
    return ""
  end
  local level = UnitLevel(unit)
  if not level or level <= 0 then
    return ""
  end
  return tostring(level)
end

function TurtleRP.GetPetProfileNameForUnit(unit)
  local petName = UnitName(unit) or "Pet"
  local entry = TurtleRPPetProfiles and TurtleRPPetProfiles[TurtleRP.GetPetUID(unit)] or nil
  local candidate = petName
  local suffix = 2
  if not entry or not entry["profiles"] then
    return candidate
  end
  while entry["profiles"][candidate] ~= nil do
    candidate = petName .. " " .. suffix
    suffix = suffix + 1
  end
  return candidate
end
--pets presently only use the following fields. 
function TurtleRP.CreateBlankPetProfile(unit, profileName)
  local petName = UnitName(unit) or "Pet"
  local blankProfile = {}

	blankProfile["comm_id"] = TurtleRP.BuildPetCommKey(
	  UnitName(unit) or petName,
	  TurtleRP.GetPetTypeFromUnit(unit)
	)
	blankProfile["keyM"] = TurtleRP.randomchars()
	blankProfile["keyT"] = TurtleRP.randomchars()
	blankProfile["keyD"] = TurtleRP.randomchars()

	blankProfile["icon"] = ""
	blankProfile["name"] = petName
	blankProfile["unit_name"] = petName
	blankProfile["info"] = ""
	blankProfile["pronouns"] = ""
	blankProfile["level"] = TurtleRP.GetPetLevelFromUnit(unit)
	blankProfile["species"] = TurtleRP.GetPetTypeFromUnit(unit)
	blankProfile["unit_species"] = blankProfile["species"]

  blankProfile["atAGlance1"] = ""
  blankProfile["atAGlance1Title"] = ""
  blankProfile["atAGlance1Icon"] = ""
  blankProfile["atAGlance2"] = ""
  blankProfile["atAGlance2Title"] = ""
  blankProfile["atAGlance2Icon"] = ""
  blankProfile["atAGlance3"] = ""
  blankProfile["atAGlance3Title"] = ""
  blankProfile["atAGlance3Icon"] = ""

  blankProfile["description"] = ""
  blankProfile["description_link_text"] = ""
  blankProfile["description_link"] = ""
  blankProfile["notes"] = ""

  blankProfile["profile_name"] = profileName or petName

  return blankProfile
end

function TurtleRP.EnsurePetProfileEntry(petUID)
  if TurtleRPPetProfiles == nil then
    TurtleRPPetProfiles = {}
  end
  if TurtleRPPetCache == nil then
  TurtleRPPetCache = {}
end
  if not petUID or petUID == "" then
    return nil
  end
  if TurtleRPPetProfiles[petUID] == nil then
    TurtleRPPetProfiles[petUID] = {
      assignedProfile = nil,
      profiles = {}
    }
  end
  if TurtleRPPetProfiles[petUID]["profiles"] == nil then
    TurtleRPPetProfiles[petUID]["profiles"] = {}
  end
  return TurtleRPPetProfiles[petUID]
end

function TurtleRP.AssignPetProfile(petUID, profileName)
  local entry = TurtleRP.EnsurePetProfileEntry(petUID)
  if not entry or not profileName or profileName == "" then
    return nil
  end
  if entry["profiles"][profileName] == nil then
    return nil
  end
  entry["assignedProfile"] = profileName
  TurtleRP.currentlyViewedPetUID = petUID
  return entry["profiles"][profileName]
end

function TurtleRP.CreatePetProfileFromTarget()
  local unit = "target"
  if not TurtleRP.IsOwnedPetUnit(unit) then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r You must target your own pet.")
    return nil
  end
  local petUID = TurtleRP.GetPetUID(unit)
  if not petUID or petUID == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r Could not identify that pet.")
    return nil
  end
  local entry = TurtleRP.EnsurePetProfileEntry(petUID)
  if not entry then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r Failed to create pet profile entry.")
    return nil
  end
  local profileName = TurtleRP.GetPetProfileNameForUnit(unit)
  local newProfile = TurtleRP.CreateBlankPetProfile(unit, profileName)
  entry["profiles"][profileName] = newProfile
  entry["assignedProfile"] = profileName
  TurtleRP.currentlyViewedPetUID = petUID
  TurtleRP.currentAdminPetUID = petUID
  TurtleRP.lastAdminPetUID = petUID
  if TurtleRP_AdminSB_Content5_Tab2 and TurtleRP_AdminSB_Content5_Tab2:IsShown() then
    if TurtleRP.RefreshProfilesTab then
      TurtleRP.RefreshProfilesTab()
    end
    local dropdown = TurtleRP_AdminSB_Content5_Tab2_ProfileDropdown
    local text = dropdown and getglobal(dropdown:GetName() .. "Text") or nil
    if dropdown then
      UIDropDownMenu_SetSelectedValue(dropdown, profileName)
    end
    if text then
      text:SetText(profileName)
    end
    TurtleRP.populate_pet_admin_data()
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cff66CC66[TurtleRP]|r Created pet profile: " .. profileName)
  return newProfile
end

function TurtleRP.CreatePetProfileFromAdminTarget()
  local newProfile = TurtleRP.CreatePetProfileFromTarget()
  local petUID = TurtleRP.GetPetUID("target")
  local dropdown = TurtleRP_AdminSB_Content5_Tab2_ProfileDropdown
  local dropdownText = dropdown and getglobal(dropdown:GetName() .. "Text") or nil
  local selectedName = petUID and TurtleRP.GetAssignedPetProfileName(petUID) or ""
  if not newProfile or not petUID or petUID == "" then
    return
  end
  TurtleRP.currentAdminPetUID = petUID
  TurtleRP.lastAdminPetUID = petUID
  if TurtleRP.RefreshProfilesTab then
    TurtleRP.RefreshProfilesTab()
  end
  if dropdown then
    UIDropDownMenu_SetSelectedValue(dropdown, selectedName)
  end
  if dropdownText then
    if selectedName ~= "" then
      dropdownText:SetText(selectedName)
    else
      dropdownText:SetText("Select Pet Profile...")
    end
  end
  TurtleRP.populate_pet_admin_data()
end

function TurtleRP.AssignExistingPetProfileToTarget(profileName)
  local unit = "target"
  if not TurtleRP.IsOwnedPetUnit(unit) then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r You must target your own pet.")
    return nil
  end
  local petUID = TurtleRP.GetPetUID(unit)
  if not petUID or petUID == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r Could not identify that pet.")
    return nil
  end
  local assignedProfile = TurtleRP.AssignPetProfile(petUID, profileName)
  if not assignedProfile then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r That pet profile does not exist.")
    return nil
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cff66CC66[TurtleRP]|r Assigned pet profile: " .. profileName)
  return assignedProfile
end

function TurtleRP.GetPetProfileEntry(petUID)
  if not petUID or petUID == "" or not TurtleRPPetProfiles then
    return nil
  end
  return TurtleRPPetProfiles[petUID]
end

function TurtleRP.GetAssignedPetProfileName(petUID)
  local entry = TurtleRP.GetPetProfileEntry(petUID)
  if not entry then
    return nil
  end
  return entry["assignedProfile"]
end

function TurtleRP.GetPetProfileByName(petUID, profileName)
  local entry = TurtleRP.GetPetProfileEntry(petUID)
  if not entry or not entry["profiles"] or not profileName or profileName == "" then
    return nil
  end
  return entry["profiles"][profileName]
end

function TurtleRP.GetAssignedPetProfile(petUID)
  local profileName = TurtleRP.GetAssignedPetProfileName(petUID)
  if not profileName or profileName == "" then
    return nil
  end
  return TurtleRP.GetPetProfileByName(petUID, profileName)
end

function TurtleRP.GetPetProfileFromUnit(unit)
  local petUID = TurtleRP.GetPetUID(unit)
  if not petUID then
    return nil, nil, nil
  end
  local profile = TurtleRP.GetAssignedPetProfile(petUID)
  local profileName = TurtleRP.GetAssignedPetProfileName(petUID)
  return profile, petUID, profileName
end

function TurtleRP.GetCurrentViewedPetProfile()
  if not TurtleRP.currentlyViewedPetUID or TurtleRP.currentlyViewedPetUID == "" then
    return nil
  end
  return TurtleRP.GetAssignedPetProfile(TurtleRP.currentlyViewedPetUID)
end

function TurtleRP.GetCurrentAdminPetProfile()
  local petUID = TurtleRP.currentAdminPetUID
  if not petUID or petUID == "" then
    return nil
  end
  local dropdown = TurtleRP_AdminSB_Content5_Tab2_ProfileDropdown
  local selectedProfileName = dropdown and UIDropDownMenu_GetSelectedValue(dropdown) or nil
  if selectedProfileName and selectedProfileName ~= "" then
    local selectedProfile = TurtleRP.GetPetProfileByName(petUID, selectedProfileName)
    if selectedProfile then
      return selectedProfile
    end
  end
  return TurtleRP.GetAssignedPetProfile(petUID)
end

function TurtleRP.setPetAdminIcon()
  local petProfile = TurtleRP.GetCurrentAdminPetProfile()
  local pendingIcons = TurtleRP_IconSelector and TurtleRP_IconSelector.selectedIconIndex or {}
  local iconIndex = pendingIcons["pet_icon"]
  if iconIndex == nil and petProfile then
    iconIndex = petProfile["icon"]
  end
  if TurtleRP_AdminSB_Content5_Tab2_IconButton then
    TurtleRP_SetIconButtonBackdrop(TurtleRP_AdminSB_Content5_Tab2_IconButton, iconIndex)
  end
end

function TurtleRP.populate_pet_admin_data()
  local petProfile = TurtleRP.GetCurrentAdminPetProfile()
  local petUID = TurtleRP.currentAdminPetUID
  local dropdown = TurtleRP_AdminSB_Content5_Tab2_ProfileDropdown
  local profileName = dropdown and UIDropDownMenu_GetSelectedValue(dropdown) or nil
  if not profileName or profileName == "" then
    profileName = petUID and TurtleRP.GetAssignedPetProfileName(petUID) or ""
  end
  local petDropdown = TurtleRP_AdminSB_Content5_Tab2_ProfileDropdown
  local petDropdownText = petDropdown and getglobal(petDropdown:GetName() .. "Text") or nil
  if TurtleRP_AdminSB_Content5_Tab2_AssignedProfileText then
    TurtleRP_AdminSB_Content5_Tab2_AssignedProfileText:SetText(profileName or "")
  end
  if TurtleRP_AdminSB_Content5_Tab2_RenameInput then
    TurtleRP_AdminSB_Content5_Tab2_RenameInput:SetText(profileName or "")
  end
  if petDropdownText then
    if profileName and profileName ~= "" then
      petDropdownText:SetText(profileName)
    else
      petDropdownText:SetText("Select Pet Profile...")
    end
  end

  if not petProfile then
    TurtleRP_AdminSB_Content5_Tab2_NameInput:SetText("")
    TurtleRP_AdminSB_Content5_Tab2_PronounsInput:SetText("")
    TurtleRP_AdminSB_Content5_Tab2_InfoScrollBox_InfoInput:SetText("")
    TurtleRP_AdminSB_Content5_Tab2_DescriptionScrollBox_DescriptionInput:SetText("")
    if TurtleRP_IconSelector then
      TurtleRP_IconSelector.selectedIconIndex = TurtleRP_IconSelector.selectedIconIndex or {}
      TurtleRP_IconSelector.selectedIconIndex["pet_icon"] = ""
    end

    TurtleRP.setPetAdminIcon()
    if TurtleRP_AdminSB_Content5_Tab2 and TurtleRP_AdminSB_Content5_Tab2:IsShown() then
      TurtleRP.editingPetAtAGlance = nil
      TurtleRP.RefreshAdminStateSnapshot()
    end
    return
  end
  TurtleRP_AdminSB_Content5_Tab2_NameInput:SetText(petProfile["name"] or "")
  TurtleRP_AdminSB_Content5_Tab2_PronounsInput:SetText(petProfile["pronouns"] or "")
  TurtleRP_AdminSB_Content5_Tab2_InfoScrollBox_InfoInput:SetText(petProfile["info"] or "")
  TurtleRP_AdminSB_Content5_Tab2_DescriptionScrollBox_DescriptionInput:SetText(petProfile["description"] or "")
  if TurtleRP_IconSelector then
    TurtleRP_IconSelector.selectedIconIndex = TurtleRP_IconSelector.selectedIconIndex or {}
    TurtleRP_IconSelector.selectedIconIndex["pet_icon"] = petProfile["icon"] or ""
  end
  TurtleRP.setPetAdminIcon()

  if TurtleRP_AdminSB_Content5_Tab2 and TurtleRP_AdminSB_Content5_Tab2:IsShown() then
    TurtleRP.editingPetAtAGlance = nil
    TurtleRP.RefreshAdminStateSnapshot()
  end
end

function TurtleRP.LoadPetAdminFromTarget(createIfMissing)
  local unit = "target"
  local dropdown = TurtleRP_AdminSB_Content5_Tab2_ProfileDropdown
  local dropdownText = dropdown and getglobal(dropdown:GetName() .. "Text") or nil
  local petUID = TurtleRP.GetPetUID(unit)
  if not petUID or petUID == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r Could not identify that pet.")
    return
  end
  local petProfile = TurtleRP.GetAssignedPetProfile(petUID)
  if not petProfile and createIfMissing then
    petProfile = TurtleRP.CreatePetProfileFromTarget()
  end
  if not petProfile then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r No assigned pet profile found for that target.")
    return
  end
  TurtleRP.currentAdminPetUID = petUID
  TurtleRP.lastAdminPetUID = petUID
  if TurtleRP.RefreshProfilesTab then
    TurtleRP.RefreshProfilesTab()
  end
  local selectedName = TurtleRP.GetAssignedPetProfileName(petUID) or ""
  if dropdown then
    UIDropDownMenu_SetSelectedValue(dropdown, selectedName)
  end
  if dropdownText then
    if selectedName ~= "" then
      dropdownText:SetText(selectedName)
    else
      dropdownText:SetText("Select Pet Profile...")
    end
  end
  TurtleRP.populate_pet_admin_data()
end

function TurtleRP.AssignSelectedPetProfile()
  local dropdown = TurtleRP_AdminSB_Content5_Tab2_ProfileDropdown
  local selectedProfile = dropdown and UIDropDownMenu_GetSelectedValue(dropdown) or nil
  if not TurtleRP.currentAdminPetUID or TurtleRP.currentAdminPetUID == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r No pet loaded.")
    return
  end
  if not selectedProfile or selectedProfile == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r No pet profile selected.")
    return
  end
  if not TurtleRP.AssignPetProfile(TurtleRP.currentAdminPetUID, selectedProfile) then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r That pet profile does not exist.")
    return
  end
  TurtleRP.lastAdminPetUID = TurtleRP.currentAdminPetUID
  TurtleRP.RefreshProfilesTab()
  if dropdown then
    UIDropDownMenu_SetSelectedValue(dropdown, selectedProfile)
    local text = getglobal(dropdown:GetName() .. "Text")
    if text then
      text:SetText(selectedProfile)
    end
  end
  TurtleRP.populate_pet_admin_data()
end

function TurtleRP.RenameCurrentPetProfile()
  local petUID = TurtleRP.currentAdminPetUID
  local entry = petUID and TurtleRP.GetPetProfileEntry(petUID) or nil
  local dropdown = TurtleRP_AdminSB_Content5_Tab2_ProfileDropdown
  local oldName = dropdown and UIDropDownMenu_GetSelectedValue(dropdown) or nil
  local newName = TurtleRP.validateBeforeSaving(TurtleRP_AdminSB_Content5_Tab2_RenameInput:GetText()) or ""
  if (not oldName or oldName == "") and entry then
    oldName = entry["assignedProfile"]
  end
  if not petUID or not entry or not oldName or oldName == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r No pet profile selected.")
    return
  end
  if newName == "" or newName == oldName then
    TurtleRP.RefreshProfilesTab()
    if dropdown then
      UIDropDownMenu_SetSelectedValue(dropdown, oldName)
      local text = getglobal(dropdown:GetName() .. "Text")
      if text then
        text:SetText(oldName)
      end
    end
    TurtleRP.populate_pet_admin_data()
    return
  end
  if entry["profiles"][newName] ~= nil then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r A pet profile with that name already exists.")
    return
  end
  entry["profiles"][newName] = entry["profiles"][oldName]
  entry["profiles"][oldName] = nil
  entry["profiles"][newName]["profile_name"] = newName
  if entry["assignedProfile"] == oldName then
    entry["assignedProfile"] = newName
  end
  TurtleRP.RefreshProfilesTab()
  if dropdown then
    UIDropDownMenu_SetSelectedValue(dropdown, newName)
    local text = getglobal(dropdown:GetName() .. "Text")
    if text then
      text:SetText(newName)
    end
  end
  TurtleRP.populate_pet_admin_data()
end

function TurtleRP.DeleteCurrentPetProfile()
  local petUID = TurtleRP.currentAdminPetUID
  local entry = petUID and TurtleRP.GetPetProfileEntry(petUID) or nil
  local dropdown = TurtleRP_AdminSB_Content5_Tab2_ProfileDropdown
  local currentName = dropdown and UIDropDownMenu_GetSelectedValue(dropdown) or nil
  if (not currentName or currentName == "") and entry then
    currentName = entry["assignedProfile"]
  end
  if not petUID or not entry or not currentName or currentName == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r No pet profile selected.")
    return
  end
  local remainingNames = {}
  local profileName
  for profileName in pairs(entry["profiles"]) do
    if profileName ~= currentName then
      table.insert(remainingNames, profileName)
    end
  end
  entry["profiles"][currentName] = nil
  if entry["assignedProfile"] == currentName then
    if table.getn(remainingNames) > 0 then
      table.sort(remainingNames, function(a, b)
        return string.lower(a) < string.lower(b)
      end)
      entry["assignedProfile"] = remainingNames[1]
    else
      entry["assignedProfile"] = nil
    end
  end
  if table.getn(remainingNames) == 0 and TurtleRP.lastAdminPetUID == petUID then
    TurtleRP.lastAdminPetUID = nil
  end
  TurtleRP.RefreshProfilesTab()
  if dropdown then
    local nextSelected = ""
    if table.getn(remainingNames) > 0 then
      table.sort(remainingNames, function(a, b)
        return string.lower(a) < string.lower(b)
      end)
      nextSelected = remainingNames[1]
    end
    UIDropDownMenu_SetSelectedValue(dropdown, nextSelected)
    local text = getglobal(dropdown:GetName() .. "Text")
    if text then
      if nextSelected ~= "" then
        text:SetText(nextSelected)
      else
        text:SetText("Select Pet Profile...")
      end
    end
  end
  TurtleRP.populate_pet_admin_data()
end

function TurtleRP.populate_pet_at_a_glance_data()
  local petProfile = TurtleRP.GetCurrentAdminPetProfile()
  if not petProfile then
    return
  end
  TurtleRP_AdminSB_Content2_AtAGlance1ScrollBox_AAG1Input:SetText(petProfile["atAGlance1"] or "")
  TurtleRP_AdminSB_Content2_AAG1TitleInput:SetText(petProfile["atAGlance1Title"] or "")
  TurtleRP_AdminSB_Content2_AtAGlance2ScrollBox_AAG2Input:SetText(petProfile["atAGlance2"] or "")
  TurtleRP_AdminSB_Content2_AAG2TitleInput:SetText(petProfile["atAGlance2Title"] or "")
  TurtleRP_AdminSB_Content2_AtAGlance3ScrollBox_AAG3Input:SetText(petProfile["atAGlance3"] or "")
  TurtleRP_AdminSB_Content2_AAG3TitleInput:SetText(petProfile["atAGlance3Title"] or "")
  if TurtleRP_IconSelector then
    TurtleRP_IconSelector.selectedIconIndex = TurtleRP_IconSelector.selectedIconIndex or {}
    TurtleRP_IconSelector.selectedIconIndex["atAGlance1Icon"] = petProfile["atAGlance1Icon"] or ""
    TurtleRP_IconSelector.selectedIconIndex["atAGlance2Icon"] = petProfile["atAGlance2Icon"] or ""
    TurtleRP_IconSelector.selectedIconIndex["atAGlance3Icon"] = petProfile["atAGlance3Icon"] or ""
  end
  TurtleRP.setAtAGlanceIcons()
end

function TurtleRP.ExitPetAtAGlanceMode()
  if TurtleRP.editingPetAtAGlance ~= 1 then
    return
  end
  TurtleRP.editingPetAtAGlance = nil
  if TurtleRP_AdminSB_Content2_BackButton then
    TurtleRP_AdminSB_Content2_BackButton:Hide()
  end
  TurtleRP_AdminSB_Content2_AtAGlance1ScrollBox_AAG1Input:SetText(TurtleRPCharacterInfo["atAGlance1"] or "")
  TurtleRP_AdminSB_Content2_AAG1TitleInput:SetText(TurtleRPCharacterInfo["atAGlance1Title"] or "")
  TurtleRP_AdminSB_Content2_AtAGlance2ScrollBox_AAG2Input:SetText(TurtleRPCharacterInfo["atAGlance2"] or "")
  TurtleRP_AdminSB_Content2_AAG2TitleInput:SetText(TurtleRPCharacterInfo["atAGlance2Title"] or "")
  TurtleRP_AdminSB_Content2_AtAGlance3ScrollBox_AAG3Input:SetText(TurtleRPCharacterInfo["atAGlance3"] or "")
  TurtleRP_AdminSB_Content2_AAG3TitleInput:SetText(TurtleRPCharacterInfo["atAGlance3Title"] or "")
  if TurtleRP_IconSelector then
    TurtleRP_IconSelector.selectedIconIndex = TurtleRP_IconSelector.selectedIconIndex or {}
    TurtleRP_IconSelector.selectedIconIndex["atAGlance1Icon"] = TurtleRPCharacterInfo["atAGlance1Icon"] or ""
    TurtleRP_IconSelector.selectedIconIndex["atAGlance2Icon"] = TurtleRPCharacterInfo["atAGlance2Icon"] or ""
    TurtleRP_IconSelector.selectedIconIndex["atAGlance3Icon"] = TurtleRPCharacterInfo["atAGlance3Icon"] or ""
  end
  TurtleRP.setAtAGlanceIcons()
end

function TurtleRP.OpenPetAtAGlance()
  if not TurtleRP.currentAdminPetUID or TurtleRP.currentAdminPetUID == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r No pet loaded.")
    return
  end
  local petProfile = TurtleRP.GetCurrentAdminPetProfile()
  if not petProfile then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r No pet profile loaded.")
    return
  end
  TurtleRP.previewCharacterInfo = nil
  TurtleRP.previewSource = nil
  TurtleRP.ApplyAdminTabClick(2)
  TurtleRP.editingPetAtAGlance = 1
  TurtleRP.populate_pet_at_a_glance_data()
  if TurtleRP_AdminSB_Content2_BackButton then
    TurtleRP_AdminSB_Content2_BackButton:Show()
  end
  TurtleRP.RefreshAdminStateSnapshot()
end

function TurtleRP.ReturnFromPetAtAGlance()
  TurtleRP.ExitPetAtAGlanceMode()
  TurtleRP.ApplyAdminTabClick(5)
  TurtleRP.ApplyBottomTabAdminClick("pet_profiles")
  TurtleRP.populate_pet_admin_data()
  TurtleRP.RefreshAdminStateSnapshot()
end

function TurtleRP.save_pet_general()
  local petProfile = TurtleRP.GetCurrentAdminPetProfile()
  local pendingIcons = TurtleRP_IconSelector and TurtleRP_IconSelector.selectedIconIndex or {}

  if not petProfile then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r No pet profile loaded in admin.")
    return
  end
	petProfile["keyM"] = TurtleRP.randomchars()
	petProfile["keyD"] = TurtleRP.randomchars()
	petProfile["name"] = TurtleRP.validateBeforeSaving(TurtleRP_AdminSB_Content5_Tab2_NameInput:GetText()) or ""
	petProfile["pronouns"] = TurtleRP.validateBeforeSaving(TurtleRP_AdminSB_Content5_Tab2_PronounsInput:GetText()) or ""
	petProfile["info"] = TurtleRP.validateBeforeSaving(TurtleRP_AdminSB_Content5_Tab2_InfoScrollBox_InfoInput:GetText()) or ""
	petProfile["description"] = TurtleRP.validateBeforeSaving(TurtleRP_AdminSB_Content5_Tab2_DescriptionScrollBox_DescriptionInput:GetText()) or ""

	if TurtleRP.currentAdminPetUID and TurtleRPPetProfiles and TurtleRPPetProfiles[TurtleRP.currentAdminPetUID] then
	  petProfile["unit_name"] = petProfile["unit_name"] or petProfile["name"] or ""
	  petProfile["unit_species"] = petProfile["unit_species"] or petProfile["species"] or ""
	end
	petProfile["comm_id"] = TurtleRP.BuildPetCommKey(
	  petProfile["unit_name"] or petProfile["name"] or "",
	  petProfile["unit_species"] or petProfile["species"] or ""
	)
	if pendingIcons["pet_icon"] ~= nil then
	  petProfile["icon"] = pendingIcons["pet_icon"]
	end
  TurtleRP.populate_pet_admin_data()
  TurtleRP.RefreshProfilesTab()
  DEFAULT_CHAT_FRAME:AddMessage("|cff66CC66[TurtleRP]|r Saved pet profile: " .. (petProfile["profile_name"] or petProfile["name"] or "Pet"))
end

function TurtleRP.OpenPetAdminPreview(openTo)
  if not TurtleRP.currentAdminPetUID or TurtleRP.currentAdminPetUID == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r No pet loaded.")
    return
  end
  local petProfile = TurtleRP.GetCurrentAdminPetProfile()
  if not petProfile then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r No pet profile loaded.")
    return
  end
  TurtleRP.previewCharacterInfo = TurtleRP.CopyTableShallow(petProfile)
  TurtleRP.previewSource = "pet_admin"
  TurtleRP.currentlyViewedPetUID = TurtleRP.currentAdminPetUID
  TurtleRP.currentlyViewedPlayer = nil
  TurtleRP_CharacterDetails_FrameTabButton1.bookType = "general"
  TurtleRP_CharacterDetails_FrameTabButton2.bookType = "description"
  TurtleRP_CharacterDetails_FrameTabButton3.bookType = "notes"
  TurtleRP_CharacterDetails:ClearAllPoints()
  if TurtleRP_AdminSB and TurtleRP_AdminSB:IsShown() then
    TurtleRP_CharacterDetails:SetPoint("TOPLEFT", TurtleRP_AdminSB, "TOPRIGHT", 20, 0)
  else
    TurtleRP_CharacterDetails:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
  TurtleRP_CharacterDetails:Show()
  TurtleRP.OnBottomTabProfileClick(openTo or "general")
end
--player profile informatiom
function TurtleRP.GetDefaultProfileNameForCharacter(playerName)
  if not playerName or playerName == "" then
    playerName = UnitName("player")
  end
  return playerName
end

function TurtleRP.GetBoundProfileName(playerName)
  if not playerName or playerName == "" then
    playerName = UnitName("player")
  end
  if TurtleRPCharacterProfileBindings == nil then
    TurtleRPCharacterProfileBindings = {}
  end
  if TurtleRPCharacterProfileBindings[playerName] == nil or TurtleRPCharacterProfileBindings[playerName] == "" then
    TurtleRPCharacterProfileBindings[playerName] = TurtleRP.GetDefaultProfileNameForCharacter(playerName)
  end
  return TurtleRPCharacterProfileBindings[playerName]
end

function TurtleRP.EnsureAccountProfile(profileName, templateSource)
  if TurtleRPAccountProfiles == nil then
    TurtleRPAccountProfiles = {}
  end
  if not profileName or profileName == "" then
    return nil
  end
  if TurtleRPAccountProfiles[profileName] == nil then
    TurtleRPAccountProfiles[profileName] = TurtleRP.CopyTableShallow(templateSource or TurtleRPCharacterInfo or {})
  end
  TurtleRP.NormalizeCharacterProfile(TurtleRPAccountProfiles[profileName])
  return TurtleRPAccountProfiles[profileName]
end

function TurtleRP.GetBoundProfile(playerName)
  local profileName = TurtleRP.GetBoundProfileName(playerName)
  local profile = TurtleRP.EnsureAccountProfile(profileName, TurtleRPCharacterInfo)
  if profile then
    TurtleRP.NormalizeCharacterProfile(profile)
  end
  return profile
end

function TurtleRP.SyncBoundProfile(playerName)
  if not playerName or playerName == "" then
    playerName = UnitName("player")
  end
  if TurtleRPCharacterProfileBindings == nil then
    TurtleRPCharacterProfileBindings = {}
  end
  if TurtleRPAccountProfiles == nil then
    TurtleRPAccountProfiles = {}
  end
  if TurtleRPCharacterInfo == nil then
    return
  end
  local profileName = TurtleRP.GetBoundProfileName(playerName)
  if not profileName or profileName == "" then
    return
  end
  TurtleRPAccountProfiles[profileName] = TurtleRP.CopyTableShallow(TurtleRPCharacterInfo)
end

function TurtleRP.BindProfileToCharacter(playerName, profileName)
  if not playerName or playerName == "" then
    playerName = UnitName("player")
  end
  if not profileName or profileName == "" then
    return nil
  end
  if TurtleRPCharacterProfileBindings == nil then
    TurtleRPCharacterProfileBindings = {}
  end
  if TurtleRPAccountProfiles == nil then
    TurtleRPAccountProfiles = {}
  end
  if TurtleRPAccountProfiles[profileName] == nil then
    return nil
  end
  if playerName == UnitName("player") then
    TurtleRP.SyncBoundProfile(playerName)
  end
  TurtleRPCharacterProfileBindings[playerName] = profileName
  if playerName == UnitName("player") then
    TurtleRPCharacterInfo = TurtleRP.CopyTableShallow(TurtleRPAccountProfiles[profileName])
    TurtleRPAccountProfiles[profileName] = TurtleRPCharacterInfo
    TurtleRPCharacters[playerName] = TurtleRPCharacterInfo
  end

  return TurtleRPAccountProfiles[profileName]
end

function TurtleRP.CreateBlankProfile(profileName)
  if not profileName or profileName == "" then
    return nil
  end
  if TurtleRPAccountProfiles == nil then
    TurtleRPAccountProfiles = {}
  end
  if TurtleRPAccountProfiles[profileName] ~= nil then
    return nil
  end
  local localizedClass, classToken = UnitClass("player")
  local blankProfile = {}

  blankProfile["keyM"] = TurtleRP.randomchars()
  blankProfile["nsfw"] = "0"
  blankProfile["icon"] = ""
  blankProfile["title"] = ""
  blankProfile["full_name"] = UnitName("player")
  blankProfile["race"] = UnitRace("player")
  blankProfile["class"] = localizedClass
  blankProfile["class_token"] = classToken
  blankProfile["class_color"] = TurtleRPClassData[localizedClass][4]
  blankProfile["faction"] = TurtleRP.getFactionDefault()
  blankProfile["ic_info"] = ""
  blankProfile["ooc_info"] = ""
  blankProfile["ic_pronouns"] = ""
  blankProfile["ooc_pronouns"] = ""
  blankProfile["currently_ic"] = "1"
  blankProfile["notes"] = ""
  blankProfile["short_note"] = ""
  blankProfile["guild_override"] = ""
  blankProfile["guild_ic"] = "0"
  blankProfile["guild_ooc"] = "0"

  blankProfile["keyT"] = TurtleRP.randomchars()
  blankProfile["currently"] = ""
  blankProfile["atAGlance1"] = ""
  blankProfile["atAGlance1Title"] = ""
  blankProfile["atAGlance1Icon"] = ""
  blankProfile["atAGlance2"] = ""
  blankProfile["atAGlance2Title"] = ""
  blankProfile["atAGlance2Icon"] = ""
  blankProfile["atAGlance3"] = ""
  blankProfile["atAGlance3Title"] = ""
  blankProfile["atAGlance3Icon"] = ""
  blankProfile["experience"] = "z"
  blankProfile["walkups"] = "z"
  blankProfile["combat"] = "z"
  blankProfile["injury"] = "z"
  blankProfile["romance"] = "z"
  blankProfile["death"] = "z"
  
  blankProfile["keyD"] = TurtleRP.randomchars()
  blankProfile["description"] = ""
  blankProfile["character_notes"] = {}
  blankProfile["character_short_notes"] = {}
  blankProfile["character_disable_rp_color"] = {}

  TurtleRP.NormalizeCharacterProfile(blankProfile)
  TurtleRPAccountProfiles[profileName] = blankProfile
  return blankProfile
end

function TurtleRP.GetAllAccountProfileNames()
  local names = {}
  if TurtleRPAccountProfiles == nil then
    TurtleRPAccountProfiles = {}
  end
  for profileName in pairs(TurtleRPAccountProfiles) do
    table.insert(names, profileName)
  end
  table.sort(names, function(a, b)
    return string.lower(a) < string.lower(b)
  end)
  return names
end

--Profile temp check for migration to account wide saving. Some people already have multiple profiles through the dropdown I'm replacing. 
function TurtleRP.AreProfilesEquivalent(profileA, profileB)
  local keysToCompare = {
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
    "notes",
    "short_note",
    "guild_override",
    "guild_ic",
    "guild_ooc"
  }
  if not profileA and not profileB then
    return true
  end
  if not profileA or not profileB then
    return false
  end
  for _, key in ipairs(keysToCompare) do
    local a = profileA[key] or ""
    local b = profileB[key] or ""
    if a ~= b then
      return false
    end
  end

  return true
end

function TurtleRP.GetUniqueMigratedProfileName(baseName)
  local candidate = baseName
  local suffix = 2
  while TurtleRPAccountProfiles[candidate] ~= nil do
    candidate = baseName .. " " .. suffix
    suffix = suffix + 1
  end
  return candidate
end

function TurtleRP.MigrateLegacyProfilesForCurrentCharacter()
  local playerName = UnitName("player")
  if TurtleRPSettings["profiles_migrated_to_account"] == "1" then
    return
  end
  if TurtleRPAccountProfiles == nil then
    TurtleRPAccountProfiles = {}
  end
  if TurtleRPCharacterProfileBindings == nil then
    TurtleRPCharacterProfileBindings = {}
  end
  if TurtleRPPlayerProfiles == nil then
    TurtleRPPlayerProfiles = {}
  end
  local createdNames = {}
  local firstCreatedName = nil
  local selectedLegacyProfile = tostring(TurtleRPSettings["selected_profile"] or "0")
  local selectedMigratedName = nil

  for i = 0, 3 do
    local legacyKey = tostring(i)
    local legacyProfile = TurtleRPPlayerProfiles[legacyKey]

    if legacyProfile ~= nil then
      local alreadyMatchedName = nil
      for _, existingName in ipairs(createdNames) do
        if TurtleRP.AreProfilesEquivalent(TurtleRPAccountProfiles[existingName], legacyProfile) then
          alreadyMatchedName = existingName
          break
        end
      end

      if alreadyMatchedName == nil then
        local baseName = playerName
        if firstCreatedName ~= nil then
          baseName = playerName .. " " .. (table.getn(createdNames) + 1)
        end
        local finalName = TurtleRP.GetUniqueMigratedProfileName(baseName)
        TurtleRPAccountProfiles[finalName] = TurtleRP.CopyTableShallow(legacyProfile)
        table.insert(createdNames, finalName)
        if firstCreatedName == nil then
          firstCreatedName = finalName
        end
        alreadyMatchedName = finalName
      end
      if legacyKey == selectedLegacyProfile then
        selectedMigratedName = alreadyMatchedName
      end
    end
  end

  if firstCreatedName == nil then
    local fallbackName = TurtleRP.GetUniqueMigratedProfileName(playerName)
    TurtleRPAccountProfiles[fallbackName] = TurtleRP.CopyTableShallow(TurtleRPCharacterInfo or {})
    firstCreatedName = fallbackName
    selectedMigratedName = fallbackName
  end
  if selectedMigratedName == nil then
    selectedMigratedName = firstCreatedName
  end
  TurtleRPCharacterProfileBindings[playerName] = selectedMigratedName
  TurtleRPCharacterInfo = TurtleRPAccountProfiles[selectedMigratedName]
  TurtleRPCharacters[playerName] = TurtleRPCharacterInfo

  TurtleRPSettings["profiles_migrated_to_account"] = "1"
  TurtleRP.pendingProfileMigrationPopup = 1
end

--End of migration, start of build
function TurtleRP.BuildAdminProfilePreviewData()
  local preview = TurtleRP.CopyTableShallow(TurtleRPCharacterInfo)
  preview["full_name"] = TurtleRP.validateBeforeSaving(TurtleRP_AdminSB_Content1_NameInput:GetText()) or ""
  preview["race"] = TurtleRP.validateBeforeSaving(TurtleRP_AdminSB_Content1_RaceInput:GetText()) or ""
  preview["class"] = TurtleRP.validateBeforeSaving(TurtleRP_AdminSB_Content1_ClassInput:GetText()) or ""
  preview["title"] = TurtleRP.validateBeforeSaving(TurtleRP_AdminSB_Content1_TitleInput:GetText()) or ""
  preview["ic_info"] = TurtleRP.validateBeforeSaving(TurtleRP_AdminSB_Content1_ICScrollBox_ICInfoInput:GetText()) or ""
  preview["ooc_info"] = TurtleRP.validateBeforeSaving(TurtleRP_AdminSB_Content1_OOCScrollBox_OOCInfoInput:GetText()) or ""
  preview["ic_pronouns"] = TurtleRP.validateBeforeSaving(TurtleRP_AdminSB_Content1_ICPronounsInput:GetText()) or ""
  preview["ooc_pronouns"] = TurtleRP.validateBeforeSaving(TurtleRP_AdminSB_Content1_OOCPronounsInput:GetText()) or ""
  preview["icon"] = TurtleRP.GetAdminPendingIconValue("icon", TurtleRPCharacterInfo["icon"] or "")
  preview["faction"] = TurtleRP.GetAdminPendingFactionValue(TurtleRPCharacterInfo["faction"] or TurtleRP.getFactionDefault())
  preview["atAGlance1"] = TurtleRP.validateBeforeSaving(TurtleRP_AdminSB_Content2_AtAGlance1ScrollBox_AAG1Input:GetText()) or ""
  preview["atAGlance1Title"] = TurtleRP.validateBeforeSaving(TurtleRP_AdminSB_Content2_AAG1TitleInput:GetText()) or ""
  preview["atAGlance1Icon"] = TurtleRP.GetAdminPendingIconValue("atAGlance1Icon", TurtleRPCharacterInfo["atAGlance1Icon"] or "")
  preview["atAGlance2"] = TurtleRP.validateBeforeSaving(TurtleRP_AdminSB_Content2_AtAGlance2ScrollBox_AAG2Input:GetText()) or ""
  preview["atAGlance2Title"] = TurtleRP.validateBeforeSaving(TurtleRP_AdminSB_Content2_AAG2TitleInput:GetText()) or ""
  preview["atAGlance2Icon"] = TurtleRP.GetAdminPendingIconValue("atAGlance2Icon", TurtleRPCharacterInfo["atAGlance2Icon"] or "")
  preview["atAGlance3"] = TurtleRP.validateBeforeSaving(TurtleRP_AdminSB_Content2_AtAGlance3ScrollBox_AAG3Input:GetText()) or ""
  preview["atAGlance3Title"] = TurtleRP.validateBeforeSaving(TurtleRP_AdminSB_Content2_AAG3TitleInput:GetText()) or ""
  preview["atAGlance3Icon"] = TurtleRP.GetAdminPendingIconValue("atAGlance3Icon", TurtleRPCharacterInfo["atAGlance3Icon"] or "")
  preview["experience"] = UIDropDownMenu_GetSelectedValue(TurtleRP_AdminSB_Content1_Tab2_ExperienceDropdown) or preview["experience"]
  preview["walkups"] = UIDropDownMenu_GetSelectedValue(TurtleRP_AdminSB_Content1_Tab2_WalkupsDropdown) or preview["walkups"]
  preview["combat"] = UIDropDownMenu_GetSelectedValue(TurtleRP_AdminSB_Content1_Tab2_CombatDropdown) or preview["combat"]
  preview["injury"] = UIDropDownMenu_GetSelectedValue(TurtleRP_AdminSB_Content1_Tab2_InjuryDropdown) or preview["injury"]
  preview["romance"] = UIDropDownMenu_GetSelectedValue(TurtleRP_AdminSB_Content1_Tab2_RomanceDropdown) or preview["romance"]
  preview["death"] = UIDropDownMenu_GetSelectedValue(TurtleRP_AdminSB_Content1_Tab2_DeathDropdown) or preview["death"]

  preview["keyM"] = preview["keyM"] or TurtleRP.randomchars()
  preview["keyT"] = preview["keyT"] or TurtleRP.randomchars()

  if _G["TurtleRP_AdminSB_Content1_GuildOverrideInput"] then
    local overrideText = _G["TurtleRP_AdminSB_Content1_GuildOverrideInput"]:GetText() or ""
    preview["guild_override"] = TurtleRP.validateBeforeSaving(overrideText) or ""
  else
    preview["guild_override"] = TurtleRPCharacterInfo and TurtleRPCharacterInfo["guild_override"] or ""
  end
  if _G["TurtleRP_AdminSB_Content1_GuildICButton"] then
    preview["guild_ic"] = _G["TurtleRP_AdminSB_Content1_GuildICButton"]:GetChecked() and "1" or "0"
  else
    preview["guild_ic"] = TurtleRPCharacterInfo and TurtleRPCharacterInfo["guild_ic"] or "0"
  end
  if _G["TurtleRP_AdminSB_Content1_GuildOOCButton"] then
    preview["guild_ooc"] = _G["TurtleRP_AdminSB_Content1_GuildOOCButton"]:GetChecked() and "1" or "0"
  else
    preview["guild_ooc"] = TurtleRPCharacterInfo and TurtleRPCharacterInfo["guild_ooc"] or "0"
  end

  return preview
end

function TurtleRP.BuildAdminDescriptionPreviewData()
  local preview = TurtleRP.CopyTableShallow(TurtleRPCharacterInfo)

  preview["description"] = TurtleRP.validateBeforeSaving(
    TurtleRP_AdminSB_Content3_DescriptionScrollBox_DescriptionInput:GetText()
  ) or ""

  preview["description_link_text"] = TurtleRP.validateBeforeSaving(
    TurtleRP_AdminSB_Content3_LinkTextInput and TurtleRP_AdminSB_Content3_LinkTextInput:GetText() or ""
  ) or ""

  preview["description_link"] = TurtleRP.validateBeforeSaving(
    TurtleRP_AdminSB_Content3_LinkInput and TurtleRP_AdminSB_Content3_LinkInput:GetText() or ""
  ) or ""

  preview["keyD"] = preview["keyD"] or TurtleRP.randomchars()
  return preview
end

function TurtleRP.OpenAdminProfilePreview()
  TurtleRP.previewCharacterInfo = TurtleRP.BuildAdminProfilePreviewData()
  TurtleRP.previewSource = "admin_profile"
  TurtleRP.currentlyViewedPlayer = UnitName("player")
  TurtleRP.OpenProfilePreview("general")
end

function TurtleRP.OpenAdminDescriptionPreview()
  TurtleRP.previewCharacterInfo = TurtleRP.BuildAdminDescriptionPreviewData()
  TurtleRP.previewSource = "admin_description"
  TurtleRP.currentlyViewedPlayer = UnitName("player")
  TurtleRP.OpenProfilePreview("description")
end

function TurtleRP.GetAdminPendingIconValue(key, fallback)
  local pendingIcons = TurtleRP_IconSelector and TurtleRP_IconSelector.selectedIconIndex or nil
  if pendingIcons and pendingIcons[key] ~= nil then
    return pendingIcons[key]
  end
  return fallback
end

function TurtleRP.GetAdminClassColorHex()
  local r, g, b = TurtleRP_AdminSB_Content1_ClassColorButton:GetBackdropColor()
  return TurtleRP.rgb2hex(r, g, b)
end

function TurtleRP.ClearAdminFocus()
  if not TurtleRP_AdminSB then
    return
  end

  TurtleRP_AdminSB_Content1_NameInput:ClearFocus()
  TurtleRP_AdminSB_Content1_RaceInput:ClearFocus()
  TurtleRP_AdminSB_Content1_ClassInput:ClearFocus()
  TurtleRP_AdminSB_Content1_TitleInput:ClearFocus()
  TurtleRP_AdminSB_Content1_ICScrollBox_ICInfoInput:ClearFocus()
  TurtleRP_AdminSB_Content1_OOCScrollBox_OOCInfoInput:ClearFocus()
  TurtleRP_AdminSB_Content1_ICPronounsInput:ClearFocus()
  TurtleRP_AdminSB_Content1_OOCPronounsInput:ClearFocus()

  TurtleRP_AdminSB_Content2_AAG1TitleInput:ClearFocus()
  TurtleRP_AdminSB_Content2_AAG2TitleInput:ClearFocus()
  TurtleRP_AdminSB_Content2_AAG3TitleInput:ClearFocus()
  TurtleRP_AdminSB_Content2_AtAGlance1ScrollBox_AAG1Input:ClearFocus()
  TurtleRP_AdminSB_Content2_AtAGlance2ScrollBox_AAG2Input:ClearFocus()
  TurtleRP_AdminSB_Content2_AtAGlance3ScrollBox_AAG3Input:ClearFocus()

	TurtleRP_AdminSB_Content3_DescriptionScrollBox_DescriptionInput:ClearFocus()
	if TurtleRP_AdminSB_Content3_LinkTextInput then
	  TurtleRP_AdminSB_Content3_LinkTextInput:ClearFocus()
	end
	if TurtleRP_AdminSB_Content3_LinkInput then
	  TurtleRP_AdminSB_Content3_LinkInput:ClearFocus()
	end

  TurtleRP_AdminSB_Content4_ShortNoteBox_Input:ClearFocus()
  TurtleRP_AdminSB_Content4_NotesScrollBox_NotesInput:ClearFocus()
end

function TurtleRP.CaptureAdminStateSnapshot()
  if not TurtleRP_AdminSB then
    return ""
  end

  if TurtleRP.editingPetAtAGlance == 1 then
    local petProfile = TurtleRP.GetCurrentAdminPetProfile() or {}
    local petDropdown = TurtleRP_AdminSB_Content5_Tab2_ProfileDropdown
    local selectedPetProfile = petDropdown and UIDropDownMenu_GetSelectedValue(petDropdown) or ""

    local parts = {
      "pet_aag",
      TurtleRP.currentAdminPetUID or "",
      selectedPetProfile or "",
      TurtleRP_AdminSB_Content2_AtAGlance1ScrollBox_AAG1Input:GetText() or "",
      TurtleRP_AdminSB_Content2_AAG1TitleInput:GetText() or "",
      TurtleRP.GetAdminPendingIconValue("atAGlance1Icon", petProfile["atAGlance1Icon"] or ""),
      TurtleRP_AdminSB_Content2_AtAGlance2ScrollBox_AAG2Input:GetText() or "",
      TurtleRP_AdminSB_Content2_AAG2TitleInput:GetText() or "",
      TurtleRP.GetAdminPendingIconValue("atAGlance2Icon", petProfile["atAGlance2Icon"] or ""),
      TurtleRP_AdminSB_Content2_AtAGlance3ScrollBox_AAG3Input:GetText() or "",
      TurtleRP_AdminSB_Content2_AAG3TitleInput:GetText() or "",
      TurtleRP.GetAdminPendingIconValue("atAGlance3Icon", petProfile["atAGlance3Icon"] or "")
    }

    return table.concat(parts, "§")
  end

  local characterInfo = TurtleRPCharacterInfo or {}
  local playerInfo = TurtleRPCharacters[UnitName("player")] or characterInfo

  local experience = UIDropDownMenu_GetSelectedValue(TurtleRP_AdminSB_Content1_Tab2_ExperienceDropdown)
  local walkups = UIDropDownMenu_GetSelectedValue(TurtleRP_AdminSB_Content1_Tab2_WalkupsDropdown)
  local combat = UIDropDownMenu_GetSelectedValue(TurtleRP_AdminSB_Content1_Tab2_CombatDropdown)
  local injury = UIDropDownMenu_GetSelectedValue(TurtleRP_AdminSB_Content1_Tab2_InjuryDropdown)
  local romance = UIDropDownMenu_GetSelectedValue(TurtleRP_AdminSB_Content1_Tab2_RomanceDropdown)
  local death = UIDropDownMenu_GetSelectedValue(TurtleRP_AdminSB_Content1_Tab2_DeathDropdown)

  local currentExperience = experience ~= nil and tostring(experience) or (characterInfo["experience"] or "z")
  local currentWalkups = walkups ~= nil and tostring(walkups) or (characterInfo["walkups"] or "z")
  local currentCombat = combat ~= nil and tostring(combat) or (characterInfo["combat"] or "z")
  local currentInjury = injury ~= nil and tostring(injury) or (characterInfo["injury"] or "z")
  local currentRomance = romance ~= nil and tostring(romance) or (characterInfo["romance"] or "z")
  local currentDeath = death ~= nil and tostring(death) or (characterInfo["death"] or "z")

  local parts = {
    TurtleRP_AdminSB_Content1_NameInput:GetText() or "",
    TurtleRP_AdminSB_Content1_RaceInput:GetText() or "",
    TurtleRP_AdminSB_Content1_ClassInput:GetText() or "",
    TurtleRP_AdminSB_Content1_TitleInput:GetText() or "",
    TurtleRP_AdminSB_Content1_ICScrollBox_ICInfoInput:GetText() or "",
    TurtleRP_AdminSB_Content1_OOCScrollBox_OOCInfoInput:GetText() or "",
    TurtleRP_AdminSB_Content1_ICPronounsInput:GetText() or "",
    TurtleRP_AdminSB_Content1_OOCPronounsInput:GetText() or "",
    TurtleRP_AdminSB_Content1_ICButton:GetChecked() and "1" or "0",
    TurtleRP_AdminSB_Content1_NSFWButton:GetChecked() and "1" or "0",
    TurtleRP.GetAdminClassColorHex(),
    TurtleRP.GetAdminPendingIconValue("icon", characterInfo["icon"] or ""),
    TurtleRP.GetAdminPendingFactionValue(characterInfo["faction"] or TurtleRP.getFactionDefault()),
    currentExperience,
    currentWalkups,
    currentCombat,
    currentInjury,
    currentRomance,
    currentDeath,
    TurtleRP_AdminSB_Content2_AtAGlance1ScrollBox_AAG1Input:GetText() or "",
    TurtleRP_AdminSB_Content2_AAG1TitleInput:GetText() or "",
    TurtleRP.GetAdminPendingIconValue("atAGlance1Icon", characterInfo["atAGlance1Icon"] or ""),
    TurtleRP_AdminSB_Content2_AtAGlance2ScrollBox_AAG2Input:GetText() or "",
    TurtleRP_AdminSB_Content2_AAG2TitleInput:GetText() or "",
    TurtleRP.GetAdminPendingIconValue("atAGlance2Icon", characterInfo["atAGlance2Icon"] or ""),
    TurtleRP_AdminSB_Content2_AtAGlance3ScrollBox_AAG3Input:GetText() or "",
	TurtleRP_AdminSB_Content2_AAG3TitleInput:GetText() or "",
	TurtleRP.GetAdminPendingIconValue("atAGlance3Icon", characterInfo["atAGlance3Icon"] or ""),
	TurtleRP_AdminSB_Content3_DescriptionScrollBox_DescriptionInput:GetText() or "",
	(TurtleRP_AdminSB_Content3_LinkTextInput and TurtleRP_AdminSB_Content3_LinkTextInput:GetText() or ""),
	(TurtleRP_AdminSB_Content3_LinkInput and TurtleRP_AdminSB_Content3_LinkInput:GetText() or ""),
	TurtleRP_AdminSB_Content4_NotesScrollBox_NotesInput:GetText() or "",
    TurtleRP_AdminSB_Content4_ShortNoteBox_Input:GetText() or "",
    playerInfo["notes"] or "",
    playerInfo["short_note"] or "",
    (_G["TurtleRP_AdminSB_Content1_GuildOverrideInput"] and _G["TurtleRP_AdminSB_Content1_GuildOverrideInput"]:GetText() or (characterInfo["guild_override"] or "")),
    (_G["TurtleRP_AdminSB_Content1_GuildICButton"] and _G["TurtleRP_AdminSB_Content1_GuildICButton"]:GetChecked() and "1" or "0"),
    (_G["TurtleRP_AdminSB_Content1_GuildOOCButton"] and _G["TurtleRP_AdminSB_Content1_GuildOOCButton"]:GetChecked() and "1" or "0"),
    (TurtleRPSettings["alt_identifier"] and TurtleRPSettings["alt_identifier"]["enabled"]) or "0",
    (TurtleRPSettings["alt_identifier"] and TurtleRPSettings["alt_identifier"]["prefix"]) or "",
    (TurtleRPSettings["alt_identifier"] and TurtleRPSettings["alt_identifier"]["disable_if_match"]) or "1",
    (TurtleRPSettings["alt_identifier"] and TurtleRPSettings["alt_identifier"]["guild"]) or "0",
    (TurtleRPSettings["alt_identifier"] and TurtleRPSettings["alt_identifier"]["officer"]) or "0",
    (TurtleRPSettings["alt_identifier"] and TurtleRPSettings["alt_identifier"]["party"]) or "0",
    (TurtleRPSettings["alt_identifier"] and TurtleRPSettings["alt_identifier"]["raid"]) or "0",
    (TurtleRPSettings["alt_identifier"] and TurtleRPSettings["alt_identifier"]["yell"]) or "0",
    (TurtleRPSettings["alt_identifier"] and TurtleRPSettings["alt_identifier"]["selected_channel_id"]) or ""
  }

  return table.concat(parts, "§")
end

function TurtleRP.RefreshAdminStateSnapshot()
  TurtleRP.ClearAdminFocus()
  TurtleRP.adminStateSnapshot = TurtleRP.CaptureAdminStateSnapshot()
end
function TurtleRP.HasUnsavedAdminChanges()
  if not TurtleRP_AdminSB then
    return false
  end

  if TurtleRP.adminStateSnapshot == nil then
    return false
  end

  return TurtleRP.CaptureAdminStateSnapshot() ~= TurtleRP.adminStateSnapshot
end

function TurtleRP.ForceCloseAdmin()
  TurtleRP.adminSuppressClosePrompt = true
  TurtleRP.adminUnsavedPopupPending = nil
  StaticPopup_Hide("TTRP_ADMIN_UNSAVED")

  TurtleRP.previewCharacterInfo = nil
  TurtleRP.previewSource = nil
  TurtleRP_IconSelector.selectedIconIndex = {}
  TurtleRP.adminStateSnapshot = nil
  TurtleRP.adminPendingTabSwitch = nil
  TurtleRP.adminPendingBottomTabSwitch = nil

  HideUIPanel(TurtleRP_AdminSB)
  TurtleRP.populate_interface_user_data()

  TurtleRP.adminSuppressClosePrompt = nil
end

function TurtleRP.RequestCloseAdmin()
  TurtleRP.ClearAdminFocus()
  TurtleRP.adminPendingTabSwitch = nil
  TurtleRP.adminPendingBottomTabSwitch = nil
  if TurtleRP.HasUnsavedAdminChanges() then
    StaticPopup_Show("TTRP_ADMIN_UNSAVED")
  else
    TurtleRP.ForceCloseAdmin()
  end
end

function TurtleRP.RequestAdminTabSwitch(tabType, value)
  TurtleRP.ClearAdminFocus()
  if not TurtleRP.HasUnsavedAdminChanges() then
    TurtleRP.adminPendingTabSwitch = nil
    TurtleRP.adminPendingBottomTabSwitch = nil
    if tabType == "main" then
      TurtleRP.ApplyAdminTabClick(value)
    elseif tabType == "bottom" then
      TurtleRP.ApplyBottomTabAdminClick(value)
    end
    return
  end
  TurtleRP.adminPendingTabSwitch = nil
  TurtleRP.adminPendingBottomTabSwitch = nil
  if tabType == "main" then
    TurtleRP.adminPendingTabSwitch = value
  elseif tabType == "bottom" then
    TurtleRP.adminPendingBottomTabSwitch = value
  end

  StaticPopup_Show("TTRP_ADMIN_UNSAVED")
end

function TurtleRP.ShowAdminUnsavedPopupDelayed()
  if TurtleRP.adminUnsavedPopupPending then
    return
  end

  TurtleRP.adminUnsavedPopupPending = true

  local popupDelayFrame = CreateFrame("Frame")
  popupDelayFrame:SetScript("OnUpdate", function()
    popupDelayFrame:SetScript("OnUpdate", nil)
    TurtleRP.adminUnsavedPopupPending = nil

    if TurtleRP_AdminSB and TurtleRP_AdminSB:IsShown() then
      StaticPopup_Show("TTRP_ADMIN_UNSAVED")
    end
  end)
end

function TurtleRP.HandleAdminHidden()
  if TurtleRP.adminSuppressClosePrompt then
    return
  end
  TurtleRP.ClearAdminFocus()
  if not TurtleRP.HasUnsavedAdminChanges() then
    return
  end

  ShowUIPanel(TurtleRP_AdminSB)
  TurtleRP.ShowAdminUnsavedPopupDelayed()
end
-----
-- Saving
-----
--more legacy no-op while i transition to new system
function TurtleRP.change_character_profile()
  return
end

function TurtleRP.change_nsfw_status()
  if TurtleRP_AdminSB_Content1_NSFWButton:GetChecked() then
    TurtleRP_AdminSB_Content1_NSFWButton:SetChecked(true)
  else
    TurtleRP_AdminSB_Content1_NSFWButton:SetChecked(false)
  end
end

function TurtleRP.change_ic_status()
  if TurtleRPCharacterInfo["currently_ic"] ~= "1" then
    TurtleRPCharacterInfo["currently_ic"] = "1"
    TurtleRP_IconTray_ICModeButton2:Show()
    TurtleRP_IconTray_ICModeButton:Hide()
    TurtleRP_AdminSB_Content1_ICButton:SetChecked(true)
  else
    TurtleRPCharacterInfo["currently_ic"] = "0"
    TurtleRP_IconTray_ICModeButton:Show()
    TurtleRP_IconTray_ICModeButton2:Hide()
    TurtleRP_AdminSB_Content1_ICButton:SetChecked(false)
  end

  TurtleRPCharacterInfo["keyM"] = TurtleRP.randomchars()
  TurtleRPCharacters[UnitName("player")] = TurtleRPCharacterInfo
  TurtleRP.SyncBoundProfile(UnitName("player"))

  if TurtleRP.canChat() then
    TurtleRP.pingWithLocationAndVersion("P")
  end

  if WorldMapFrame and WorldMapFrame:IsVisible() then
    TurtleRP.show_player_locations()
  end

  if TurtleRP_AdminSB and TurtleRP_AdminSB:IsShown() then
    TurtleRP.RefreshAdminStateSnapshot()
  end
end

function TurtleRP.save_general()
  TurtleRPCharacterInfo['keyM'] = TurtleRP.randomchars()
  TurtleRPCharacterInfo['keyT'] = TurtleRP.randomchars()
  local full_name = TurtleRP_AdminSB_Content1_NameInput:GetText()
  TurtleRP_AdminSB_Content1_NameInput:ClearFocus()
  TurtleRPCharacterInfo["full_name"] = TurtleRP.validateBeforeSaving(full_name)
  local race = TurtleRP_AdminSB_Content1_RaceInput:GetText()
  TurtleRP_AdminSB_Content1_RaceInput:ClearFocus()
  TurtleRPCharacterInfo["race"] = TurtleRP.validateBeforeSaving(race)
  local class = TurtleRP_AdminSB_Content1_ClassInput:GetText()
  TurtleRP_AdminSB_Content1_ClassInput:ClearFocus()
  TurtleRPCharacterInfo["class"] = TurtleRP.validateBeforeSaving(class)
  local _, classToken = UnitClass("player")
  TurtleRPCharacterInfo["class_token"] = classToken
  local title = TurtleRP_AdminSB_Content1_TitleInput:GetText()
  TurtleRP_AdminSB_Content1_TitleInput:ClearFocus()
  TurtleRPCharacterInfo["title"] = TurtleRP.validateBeforeSaving(title)
  local r, g, b = TurtleRP_AdminSB_Content1_ClassColorButton:GetBackdropColor()
  TurtleRPCharacterInfo["class_color"] = TurtleRP.rgb2hex(r, g, b)
  local pendingIcons = TurtleRP_IconSelector and TurtleRP_IconSelector.selectedIconIndex or {}
  if pendingIcons["icon"] ~= nil then
    TurtleRPCharacterInfo["icon"] = pendingIcons["icon"]
  end
  TurtleRPCharacterInfo["faction"] = TurtleRP.GetAdminPendingFactionValue(
    TurtleRPCharacterInfo["faction"] or TurtleRP.getFactionDefault()
  )
  TurtleRP.pendingFactionSelection = nil
  if TurtleRPCharacterInfo["faction"] == nil or TurtleRPCharacterInfo["faction"] == "" then
    TurtleRPCharacterInfo["faction"] = TurtleRP.getFactionDefault()
  end
  local ic_info = TurtleRP_AdminSB_Content1_ICScrollBox_ICInfoInput:GetText()
  TurtleRP_AdminSB_Content1_ICScrollBox_ICInfoInput:ClearFocus()
  TurtleRPCharacterInfo["ic_info"] = TurtleRP.validateBeforeSaving(ic_info)
  local ooc_info = TurtleRP_AdminSB_Content1_OOCScrollBox_OOCInfoInput:GetText()
  TurtleRP_AdminSB_Content1_OOCScrollBox_OOCInfoInput:ClearFocus()
  TurtleRPCharacterInfo["ooc_info"] = TurtleRP.validateBeforeSaving(ooc_info)
  local ic_pronouns = TurtleRP_AdminSB_Content1_ICPronounsInput:GetText()
  TurtleRP_AdminSB_Content1_ICPronounsInput:ClearFocus()
  TurtleRPCharacterInfo["ic_pronouns"] = TurtleRP.validateBeforeSaving(ic_pronouns)
  local ooc_pronouns = TurtleRP_AdminSB_Content1_OOCPronounsInput:GetText()
  TurtleRP_AdminSB_Content1_OOCPronounsInput:ClearFocus()
  TurtleRPCharacterInfo["ooc_pronouns"] = TurtleRP.validateBeforeSaving(ooc_pronouns)
  if TurtleRP_AdminSB_Content1_CurrentlyInput then
    local currently = TurtleRP_AdminSB_Content1_CurrentlyInput:GetText()
    TurtleRP_AdminSB_Content1_CurrentlyInput:ClearFocus()
    TurtleRPCharacterInfo["currently"] = TurtleRP.validateBeforeSaving(currently) or ""
  end
  TurtleRPCharacterInfo["nsfw"] = TurtleRP_AdminSB_Content1_NSFWButton:GetChecked() and "1" or "0"

  if _G["TurtleRP_AdminSB_Content1_GuildOverrideInput"] then
    local guildOverrideText = _G["TurtleRP_AdminSB_Content1_GuildOverrideInput"]:GetText()
    _G["TurtleRP_AdminSB_Content1_GuildOverrideInput"]:ClearFocus()
    TurtleRPCharacterInfo["guild_override"] = TurtleRP.validateBeforeSaving(guildOverrideText)
  end
  if _G["TurtleRP_AdminSB_Content1_GuildICButton"] then
    TurtleRPCharacterInfo["guild_ic"] = _G["TurtleRP_AdminSB_Content1_GuildICButton"]:GetChecked() and "1" or "0"
  end
  if _G["TurtleRP_AdminSB_Content1_GuildOOCButton"] then
    TurtleRPCharacterInfo["guild_ooc"] = _G["TurtleRP_AdminSB_Content1_GuildOOCButton"]:GetChecked() and "1" or "0"
  end
  TurtleRPCharacters[UnitName("player")] = TurtleRPCharacterInfo
  TurtleRP.SyncBoundProfile(UnitName("player"))
  TurtleRP.setCharacterIcon()

  if TurtleRP.canChat() then
    TurtleRP.pingWithLocationAndVersion("P")
  end
  if WorldMapFrame and WorldMapFrame:IsVisible() then
    TurtleRP.show_player_locations()
  end
  TurtleRP.RefreshAdminStateSnapshot()
end

function TurtleRP.save_style()
  TurtleRPCharacterInfo['keyT'] = TurtleRP.randomchars()
  local experience = UIDropDownMenu_GetSelectedValue(TurtleRP_AdminSB_Content1_Tab2_ExperienceDropdown)
  TurtleRPCharacterInfo["experience"] = experience ~= nil and experience or 0
  local walkups = UIDropDownMenu_GetSelectedValue(TurtleRP_AdminSB_Content1_Tab2_WalkupsDropdown)
  TurtleRPCharacterInfo["walkups"] = walkups ~= nil and walkups or 0
  local combat = UIDropDownMenu_GetSelectedValue(TurtleRP_AdminSB_Content1_Tab2_CombatDropdown)
  TurtleRPCharacterInfo["combat"] = combat ~= nil and combat or 0
  local injury = UIDropDownMenu_GetSelectedValue(TurtleRP_AdminSB_Content1_Tab2_InjuryDropdown)
  TurtleRPCharacterInfo["injury"] = injury ~= nil and injury or 0
  local romance = UIDropDownMenu_GetSelectedValue(TurtleRP_AdminSB_Content1_Tab2_RomanceDropdown)
  TurtleRPCharacterInfo["romance"] = romance ~= nil and romance or 0
  local death = UIDropDownMenu_GetSelectedValue(TurtleRP_AdminSB_Content1_Tab2_DeathDropdown)
  TurtleRPCharacterInfo["death"] = death ~= nil and death or 0
  TurtleRPCharacters[UnitName("player")] = TurtleRPCharacterInfo
  TurtleRP.SyncBoundProfile(UnitName("player"))
  TurtleRP.RefreshAdminStateSnapshot()
end

function TurtleRP.save_at_a_glance()
  local aag1Text = TurtleRP_AdminSB_Content2_AtAGlance1ScrollBox_AAG1Input:GetText()
  TurtleRP_AdminSB_Content2_AtAGlance1ScrollBox_AAG1Input:ClearFocus()
  local aag1TitleText = TurtleRP_AdminSB_Content2_AAG1TitleInput:GetText()
  TurtleRP_AdminSB_Content2_AAG1TitleInput:ClearFocus()
  local aag2Text = TurtleRP_AdminSB_Content2_AtAGlance2ScrollBox_AAG2Input:GetText()
  TurtleRP_AdminSB_Content2_AtAGlance2ScrollBox_AAG2Input:ClearFocus()
  local aag2TitleText = TurtleRP_AdminSB_Content2_AAG2TitleInput:GetText()
  TurtleRP_AdminSB_Content2_AAG2TitleInput:ClearFocus()
  local aag3Text = TurtleRP_AdminSB_Content2_AtAGlance3ScrollBox_AAG3Input:GetText()
  TurtleRP_AdminSB_Content2_AtAGlance3ScrollBox_AAG3Input:ClearFocus()
  local aag3TitleText = TurtleRP_AdminSB_Content2_AAG3TitleInput:GetText()
  TurtleRP_AdminSB_Content2_AAG3TitleInput:ClearFocus()

  local pendingIcons = TurtleRP_IconSelector and TurtleRP_IconSelector.selectedIconIndex or {}

  if TurtleRP.editingPetAtAGlance == 1 then
    local petProfile = TurtleRP.GetCurrentAdminPetProfile()
    if not petProfile then
      DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r No pet profile loaded.")
      return
    end

    petProfile["keyT"] = TurtleRP.randomchars()
    petProfile["atAGlance1"] = TurtleRP.validateBeforeSaving(aag1Text)
    petProfile["atAGlance1Title"] = TurtleRP.validateBeforeSaving(aag1TitleText)
    petProfile["atAGlance2"] = TurtleRP.validateBeforeSaving(aag2Text)
    petProfile["atAGlance2Title"] = TurtleRP.validateBeforeSaving(aag2TitleText)
    petProfile["atAGlance3"] = TurtleRP.validateBeforeSaving(aag3Text)
    petProfile["atAGlance3Title"] = TurtleRP.validateBeforeSaving(aag3TitleText)

    if pendingIcons["atAGlance1Icon"] ~= nil then
      petProfile["atAGlance1Icon"] = pendingIcons["atAGlance1Icon"]
    end
    if pendingIcons["atAGlance2Icon"] ~= nil then
      petProfile["atAGlance2Icon"] = pendingIcons["atAGlance2Icon"]
    end
    if pendingIcons["atAGlance3Icon"] ~= nil then
      petProfile["atAGlance3Icon"] = pendingIcons["atAGlance3Icon"]
    end

    TurtleRP.populate_pet_at_a_glance_data()
    TurtleRP.RefreshProfilesTab()
    TurtleRP.RefreshAdminStateSnapshot()
    return
  end

  TurtleRPCharacterInfo["keyT"] = TurtleRP.randomchars()
  TurtleRPCharacterInfo["atAGlance1"] = TurtleRP.validateBeforeSaving(aag1Text)
  TurtleRPCharacterInfo["atAGlance1Title"] = TurtleRP.validateBeforeSaving(aag1TitleText)
  TurtleRPCharacterInfo["atAGlance2"] = TurtleRP.validateBeforeSaving(aag2Text)
  TurtleRPCharacterInfo["atAGlance2Title"] = TurtleRP.validateBeforeSaving(aag2TitleText)
  TurtleRPCharacterInfo["atAGlance3"] = TurtleRP.validateBeforeSaving(aag3Text)
  TurtleRPCharacterInfo["atAGlance3Title"] = TurtleRP.validateBeforeSaving(aag3TitleText)

  if pendingIcons["atAGlance1Icon"] ~= nil then
    TurtleRPCharacterInfo["atAGlance1Icon"] = pendingIcons["atAGlance1Icon"]
  end
  if pendingIcons["atAGlance2Icon"] ~= nil then
    TurtleRPCharacterInfo["atAGlance2Icon"] = pendingIcons["atAGlance2Icon"]
  end
  if pendingIcons["atAGlance3Icon"] ~= nil then
    TurtleRPCharacterInfo["atAGlance3Icon"] = pendingIcons["atAGlance3Icon"]
  end

  TurtleRPCharacters[UnitName("player")] = TurtleRPCharacterInfo
  TurtleRP.SyncBoundProfile(UnitName("player"))
  TurtleRP.setAtAGlanceIcons()
  TurtleRP.RefreshAdminStateSnapshot()
end

function TurtleRP.save_description()
  local description = TurtleRP_AdminSB_Content3_DescriptionScrollBox_DescriptionInput:GetText()
  local linkText = TurtleRP_AdminSB_Content3_LinkTextInput and TurtleRP_AdminSB_Content3_LinkTextInput:GetText() or ""
  local link = TurtleRP_AdminSB_Content3_LinkInput and TurtleRP_AdminSB_Content3_LinkInput:GetText() or ""
  TurtleRP_AdminSB_Content3_DescriptionScrollBox_DescriptionInput:ClearFocus()
  if TurtleRP_AdminSB_Content3_LinkTextInput then
    TurtleRP_AdminSB_Content3_LinkTextInput:ClearFocus()
  end
  if TurtleRP_AdminSB_Content3_LinkInput then
    TurtleRP_AdminSB_Content3_LinkInput:ClearFocus()
  end
  if TurtleRP.currentlyViewedPetUID and TurtleRP.currentlyViewedPetUID ~= "" then
    local petProfile = TurtleRP.GetAssignedPetProfile(TurtleRP.currentlyViewedPetUID)
    if not petProfile then
      return
    end
    petProfile["keyD"] = TurtleRP.randomchars()
    petProfile["description"] = TurtleRP.validateBeforeSaving(description)
    petProfile["description_link_text"] = TurtleRP.validateBeforeSaving(linkText) or ""
    petProfile["description_link"] = TurtleRP.validateBeforeSaving(link) or ""
    return
  end
  TurtleRPCharacterInfo["keyD"] = TurtleRP.randomchars()
  TurtleRPCharacterInfo["description"] = TurtleRP.validateBeforeSaving(description)
  TurtleRPCharacterInfo["description_link_text"] = TurtleRP.validateBeforeSaving(linkText) or ""
  TurtleRPCharacterInfo["description_link"] = TurtleRP.validateBeforeSaving(link) or ""
  TurtleRPCharacters[UnitName("player")] = TurtleRPCharacterInfo
  TurtleRP.SyncBoundProfile(UnitName("player"))
  TurtleRP.RefreshAdminStateSnapshot()
end

function TurtleRP.save_notes()
  local short_note = TurtleRP_AdminSB_Content4_ShortNoteBox_Input:GetText()
  TurtleRP_AdminSB_Content4_ShortNoteBox_Input:ClearFocus()
  TurtleRPCharacterInfo["short_note"] = TurtleRP.validateBeforeSaving(short_note) or ""
  local notes = TurtleRP_AdminSB_Content4_NotesScrollBox_NotesInput:GetText()
  TurtleRP_AdminSB_Content4_NotesScrollBox_NotesInput:ClearFocus()
  TurtleRPCharacterInfo["notes"] = notes
  TurtleRPCharacters[UnitName("player")] = TurtleRPCharacterInfo
  if TurtleRP.currentlyViewedPlayer == UnitName("player") and TurtleRP_CharacterDetails_Notes:IsShown() then
    TurtleRP_CharacterDetails_Notes_NotesScrollBox_NotesContent_NotesInput:SetText(TurtleRPCharacterInfo["notes"] or "")
    TurtleRP_CharacterDetails_Notes_ShortNoteBox_Input:SetText(TurtleRPCharacterInfo["short_note"] or "")
  end
  TurtleRP.SyncBoundProfile(UnitName("player"))
  TurtleRP.RefreshAdminStateSnapshot()
end

function TurtleRP.save_character_notes()
  local notes = TurtleRP_CharacterDetails_Notes_NotesScrollBox_NotesContent_NotesInput:GetText()
  TurtleRP_CharacterDetails_Notes_NotesScrollBox_NotesContent_NotesInput:ClearFocus()
  local short_note = TurtleRP_CharacterDetails_Notes_ShortNoteBox_Input:GetText()
  TurtleRP_CharacterDetails_Notes_ShortNoteBox_Input:ClearFocus()

  if TurtleRP.currentlyViewedPetUID and TurtleRP.currentlyViewedPetUID ~= "" then
    local petProfile = TurtleRP.GetAssignedPetProfile(TurtleRP.currentlyViewedPetUID)
    if not petProfile then
      return
    end
    petProfile["notes"] = notes or ""
    return
  end
  if TurtleRP.currentlyViewedPlayer == UnitName("player") then
    TurtleRPCharacterInfo["notes"] = notes
    TurtleRPCharacterInfo["short_note"] = TurtleRP.validateBeforeSaving(short_note) or ""
    TurtleRPCharacters[UnitName("player")] = TurtleRPCharacterInfo
  elseif TurtleRP.currentlyViewedPlayer and TurtleRP.currentlyViewedPlayer ~= "" then
    if TurtleRPCharacterInfo["character_notes"] == nil then
      TurtleRPCharacterInfo["character_notes"] = {}
    end
    TurtleRPCharacterInfo["character_notes"][TurtleRP.currentlyViewedPlayer] = notes
    if TurtleRPCharacterInfo["character_short_notes"] == nil then
      TurtleRPCharacterInfo["character_short_notes"] = {}
    end
    TurtleRPCharacterInfo["character_short_notes"][TurtleRP.currentlyViewedPlayer] =
      TurtleRP.validateBeforeSaving(short_note) or ""
  end
end
-- This entire function is being implemented in March/April of 2026. It exists only to migrate old data. This can be removed in like, 6 months+.
function TurtleRP.migrate_self_notes()
  local playerName = UnitName("player")
  if TurtleRPCharacterInfo["character_notes"] == nil then
    TurtleRPCharacterInfo["character_notes"] = {}
  end
  if TurtleRPCharacterInfo["character_short_notes"] == nil then
    TurtleRPCharacterInfo["character_short_notes"] = {}
  end
  if TurtleRPCharacterInfo["notes"] == nil then
    TurtleRPCharacterInfo["notes"] = ""
  end
  if TurtleRPCharacterInfo["short_note"] == nil then
    TurtleRPCharacterInfo["short_note"] = ""
  end
  local old_self_notes = TurtleRPCharacterInfo["character_notes"][playerName]
  if (TurtleRPCharacterInfo["notes"] == nil or TurtleRPCharacterInfo["notes"] == "")
    and old_self_notes ~= nil and old_self_notes ~= "" then
    TurtleRPCharacterInfo["notes"] = old_self_notes
  end
  local old_self_short = TurtleRPCharacterInfo["character_short_notes"][playerName]
  if (TurtleRPCharacterInfo["short_note"] == nil or TurtleRPCharacterInfo["short_note"] == "")
    and old_self_short ~= nil and old_self_short ~= "" then
    TurtleRPCharacterInfo["short_note"] = old_self_short
  end
  TurtleRPCharacters[UnitName("player")] = TurtleRPCharacterInfo
  TurtleRPPlayerProfiles[TurtleRPSettings["selected_profile"]] = TurtleRPCharacterInfo
end

function TurtleRP.canChat()
    return UnitLevel("player") >= TurtleRP.minChatLevel
end

function TurtleRP.GetVersionNumberParts(versionString)
  versionString = tostring(versionString or "")
  local _, _, major, minor, patch = string.find(versionString, "^(%d+)%.(%d+)%.(%d+)$")
  if not major then
    return nil, nil, nil
  end
  return tonumber(major), tonumber(minor), tonumber(patch)
end

function TurtleRP.IsVersionOlder(versionA, versionB)
  local a1, a2, a3 = TurtleRP.GetVersionNumberParts(versionA)
  local b1, b2, b3 = TurtleRP.GetVersionNumberParts(versionB)
  -- For bypassing non-stable tags like 2.0.0b. Realized during 2.0 development that I caused lots of false notifications lol
  if not a1 or not b1 then
    return false
  end
  if a1 ~= b1 then
    return a1 < b1
  end
  if a2 ~= b2 then
    return a2 < b2
  end
  return a3 < b3
end

-- Offer to join /rp channel upon reaching level 10, or first login after installing/update.
function TurtleRP.CheckLevelForChannel(newLevel, isLogin)
    local id, name = GetChannelName("rp")
    if id > 0 then 
        TurtleRPSettings["seen_rp_prompt"] = "1"
        return 
    end
    if newLevel >= 10 and TurtleRPSettings["seen_rp_prompt"] ~= "1" then
        local delay = isLogin and 30 or 10;
        
        local timerFrame = CreateFrame("Frame");
        timerFrame:SetScript("OnUpdate", function()
            delay = delay - arg1; 
            if delay <= 0 then
                TurtleRP.ShowRPPopup(isLogin);
                this:Hide(); 
                this:SetScript("OnUpdate", nil);
            end
        end);
    end
end

function TurtleRP.ShowRPPopup(isLogin)
    local id, name = GetChannelName("rp")
    if id > 0 then 
        TurtleRPSettings["seen_rp_prompt"] = "1"
        return 
    end
    local popupText = "You've reached level 10! Would you like to join the RP channel to find other roleplayers?";
    if isLogin then
        popupText = "Thank you for installing TurtleRP! Would you like to join the global /rp channel to find other roleplayers?";
    end

    StaticPopupDialogs["TTRP_JOIN_PROMPT"] = {
        text = popupText,
        button1 = "Join /rp",
        button2 = "Maybe Later",
        OnAccept = function()
            JoinChannelByName("rp")
            ChatFrame_AddChannel(ChatFrame1, "rp")
            TurtleRPSettings["seen_rp_prompt"] = "1"
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00TurtleRP: Joined /rp channel. You may always leave with /leave rp |r")
        end,
        OnCancel = function()
            TurtleRPSettings["seen_rp_prompt"] = "1" 
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    };
    StaticPopup_Show("TTRP_JOIN_PROMPT");
end

--just a debugging command
SLASH_RPRESET1 = "/rpreset";
SlashCmdList["RPRESET"] = function(msg)
    TurtleRPSettings["seen_rp_prompt"] = "0";
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00TurtleRP: RP Channel prompt has been reset. It will appear again on next login or level up.|r");
end
  -- i am so vain
function TurtleRP.IsDevProfile(playerName)
  if not playerName or playerName == "" then
    return false
  end
  local function normalize(str)
    str = string.lower(str or "")
    str = string.gsub(str, "%s+", "")
    return str
  end
  local realmName = normalize(GetRealmName())
  local loweredName = normalize(playerName)
  if realmName ~= "nordanaar" then
    return false
  end
  return loweredName == "prynn" or loweredName == "bratmage" or loweredName == "celryn" or loweredName == "niane"
end
function TurtleRP.GetDevBadgeText()
  return "|cff5bcefaT|cff70d4fbu|cff84dafbr|cff98e0fct|cffade6fcl|cffc2edfde|cffd6f3feR|cffeaf9feP|cffffffff |cffffffffD|cfffde8ede|cfffbd2e3v|cfff9bdd9e|cfff7a7cfl|cfff591c5o|cfff37bbbp|cfff165b1e|cfff04fa7r"
end

--vain AND gay, hello other programmer girlies <3
--ive currently got these set to appear in the login message, and the Admin panel header

TurtleRP.PrideTitleGradients = {
  { "e40303", "ff8c00", "ffed00" }, -- warm pride
  { "ff5e5b", "f4a261", "ffd166" }, -- soft sunset
  { "d52d00", "ff9a56", "ffffff" }, -- lesbian-inspired soft
  { "ff218c", "ffd800", "21b1ff" }, -- pan
  { "ff76a4", "ffffff", "7fbdf0" }, -- trans
  { "078d70", "98e8c1", "7bade2" }, -- mlm
  { "5bcefa", "f5a9b8", "ffffff" }, -- trans alt
  { "a85cf9", "ffffff", "4cc9f0" }, -- queer pastel
  { "ff7aa2", "ffd6e0", "cde7ff" }, -- pastel blend
  { "1a1a1a", "7a7a7a", "ffffff", "7f3fbf" }, -- ace
  { "d60270", "9b4f96", "0038a8" }, --bi
  { "f5e500", "ffffff", "9c59d1", "1a1a1a" }, --enbie
  { "3da542", "a7d379", "ffffff", "a8a8a8", "1a1a1a" }, --aro
  { "0000ff", "ff0000", "1a1a1a", "ffd700" }, --poly
}

function TurtleRP.Lerp(a, b, t)
  return a + (b - a) * t
end

function TurtleRP.HexToRGB255(hex)
  return tonumber(strsub(hex, 1, 2), 16), tonumber(strsub(hex, 3, 4), 16), tonumber(strsub(hex, 5, 6), 16)
end

function TurtleRP.RGB255ToHex(r, g, b)
  return string.format("%02x%02x%02x", r, g, b)
end

function TurtleRP.BuildGradientText(text, colors)
  if not text or text == "" then
    return ""
  end
  local plainText = tostring(text)
  local charCount = string.len(plainText)
  if charCount == 0 then
    return plainText
  end
  if not colors or table.getn(colors) < 2 then
    return plainText
  end
  local segmentCount = table.getn(colors) - 1
  local output = ""

  local i
  for i = 1, charCount do
    local ch = string.sub(plainText, i, i)

    if ch == " " then
      output = output .. ch
    else
      local progress = 0
      if charCount > 1 then
        progress = (i - 1) / (charCount - 1)
      end
      local scaled = progress * segmentCount
      local segment = math.floor(scaled) + 1
      if segment > segmentCount then
        segment = segmentCount
      end
      local localT = scaled - (segment - 1)
      local r1, g1, b1 = TurtleRP.HexToRGB255(colors[segment])
      local r2, g2, b2 = TurtleRP.HexToRGB255(colors[segment + 1])
      local r = math.floor(TurtleRP.Lerp(r1, r2, localT) + 0.5)
      local g = math.floor(TurtleRP.Lerp(g1, g2, localT) + 0.5)
      local b = math.floor(TurtleRP.Lerp(b1, b2, localT) + 0.5)

      output = output .. "|cff" .. TurtleRP.RGB255ToHex(r, g, b) .. ch
    end
  end
  return output .. "|r"
end

function TurtleRP.GetDisplayVersionText()
  local versionText = tostring(TurtleRP.currentVersion or "")
  if versionText == "" or versionText == "unknown" then
    versionText = "2.x"
  end
  return "TurtleRP " .. versionText
end

function TurtleRP.GetRandomPrideTitleText()
  local gradients = TurtleRP.PrideTitleGradients
  local count = table.getn(gradients)
  local baseText = TurtleRP.GetDisplayVersionText()
  if count == 0 then
    return baseText
  end
  local index = math.random(1, count)
  return TurtleRP.BuildGradientText(baseText, gradients[index])
end

function TurtleRP.ApplyRandomPrideTitle(fontString)
  if not fontString then
    return
  end
  fontString:SetText(TurtleRP.GetRandomPrideTitleText())
end
-----
-- Utility
-----
local setn = table.setn
local strFind = string.find
local strSub = string.sub
function TurtleRP.splitString(str, delimiter, t)
    local result
    if t then
        -- Reuse this table
        for k, v in ipairs(t) do
            t[k] = nil
        end
        result = t
    else
        result = {}
    end
    local from = 1
    local delim_from, delim_to = strFind(str, delimiter, from, true)
    local i = 1
    while delim_from do
        result[i] = strSub(str, from, delim_from - 1)
        i = i + 1
        from = delim_to + 1
        delim_from, delim_to = strFind(str, delimiter, from, true)
    end
    result[i] = strSub(str, from)
    setn(result, i)
    return result
end

function TurtleRP.randomchars()
	local res = ""
	for i = 1, 5 do
		res = res .. string.char(math.random(97, 122))
	end
	return res
end

function TurtleRP.hex2rgb(hex)
  return tonumber(strsub(hex, 1, 2), 16)/255, tonumber(strsub(hex, 3, 4), 16)/255, tonumber(strsub(hex, 5, 6), 16)/255
end

function TurtleRP.rgb2hex(r, g, b)
	return string.format("%02x%02x%02x",
		math.floor(r*255),
		math.floor(g*255),
		math.floor(b*255))
end

function TurtleRP.validateBeforeSaving(data)
  if string.find(data, '~') or string.find(data, '°') or string.find(data, '§') then
    _ERRORMESSAGE('Please do not use the characters "~", "°", or "§" in your text. Thanks!')
  else
    return data
  end
end
--this was the funniest thing i ever had to put together. shoutout to my visit to Moon Guard Goldshire, and F-List.
TurtleRP.NSFWKeywordList = {
    "18+", "69", "a/b/o", "ab/o", "adult themes", "aftercare", "ageplay", "alluring", "anal", "anus", "arousal", "aroused",
    "ass", "bare", "bdsm", "bimbo", "bimbod", "bimbofication", "bloodplay", "blowjob", "bondage", "boobs", "bra", "breasts", "breed", "breeding",
    "bulge", "busty", "butt", "chest puppies", "chestpuppies", "claiming", "climax", "clit", "cnc", "cock", "consensual non-consent", "coquette", "cowgirl",
    "creampie", "cuck", "cuckold", "cum", "cunt", "curvaceous", "daddykink", "deepthroat", "desire", "dick", "dirty rp", "doggystyle",
    "dom", "dominant", "domme", "dommy", "double penetration", "dubcon", "ecchi", "edging", "erection", "erogenous", "erotic", "erotica", "erp",
    "estrus", "exaggerated curves", "exhibition", "exhibitionism", "explicit", "f-list", "f-list.net", "facefuck", "facesitting", "facials", "feralplay", "fetish",
    "fisting", "flirt", "flirtatious", "flirty", "foot worship", "footfetish", "freeuse", "frisky", "fuck me", "fucktoy", "gangbang", "giantess", "gore", "hard limits",
    "hardon", "heavy breasts", "hentai", "horny", "impregnation", "incubus", "inflation", "intimate", "jiggle", "jiggling",
    "kink", "kinks", "kinky", "kittenplay", "knifeplay", "knotting", "lactation", "latex", "length", "lewd", "lewdness", "libido",
    "lingerie", "lust", "lustful", "masochism", "masochist", "mating", "mating press", "maturerp", "milking", "mindcontrol", "minx",
    "mistress", "mommykink", "mrp", "naked", "naughty", "nesting", "netorare", "no list", "noncon", "nsfw", "nsfwrp",
    "ntr", "nude", "nudity", "oral", "orgasm", "orgy", "overstimulation", "ownership", "paddle", "panties", "pegging", "petplay", "pheromones",
    "pillowy", "piss", "plaything", "pole dance", "primalplay", "provocative", "puppyplay", "pussy",
    "queening", "rapeplay", "ravish", "rimming", "risque", "rope", "rubber", "rut", "sadism", "sadist", "scat", "scent marking", "seduce",
    "seduction", "seductive", "seed", "semen", "sensual", "sensuous", "sex", "sexual", "shaft", "shibari", "sinful", "size difference", "slave", "slut", "smut", "smutrp",
    "soaked", "soft flesh", "soft limits", "spanking", "strapon", "strip", "stripping", "sub", "subby", "submissive", "succubus", "suggestive",
    "taboo", "tantalizing", "tease", "tempter", "tentacle", "tf", "thick thighs", "thicc", "threesome", "throatfuck", "throbbing", "tits",
    "torture", "total power exchange", "touch starved", "tpe", "transformation", "unbirth", "underwear", "use me", "vagina", "vaginal", "vixen", "voluptuous", "vore", "voyeur", "voyeurism",
    "watersports", "whore", "yearning", "yes list"
}

function TurtleRP.NormalizeNSFWDetectionText(text)
  local s = string.lower(tostring(text or ""))
  s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
  s = string.gsub(s, "|r", "")
  s = string.gsub(s, "<.->", " ")
  s = string.gsub(s, "[^%w%s]", " ")
  s = string.gsub(s, "%s+", " ")
  return s
end

function TurtleRP.GetAdminNSFWDetectionText()
  local parts = {}

  local function addBox(box)
    if box and box.GetText then
      table.insert(parts, box:GetText() or "")
    end
  end

  addBox(TurtleRP_AdminSB_Content1_NameInput)
  addBox(TurtleRP_AdminSB_Content1_RaceInput)
  addBox(TurtleRP_AdminSB_Content1_ClassInput)
  addBox(TurtleRP_AdminSB_Content1_TitleInput)
  addBox(TurtleRP_AdminSB_Content1_ICScrollBox_ICInfoInput)
  addBox(TurtleRP_AdminSB_Content1_OOCScrollBox_OOCInfoInput)
  addBox(TurtleRP_AdminSB_Content1_ICPronounsInput)
  addBox(TurtleRP_AdminSB_Content1_OOCPronounsInput)

  if _G["TurtleRP_AdminSB_Content1_GuildOverrideInput"] then
    addBox(_G["TurtleRP_AdminSB_Content1_GuildOverrideInput"])
  end

  addBox(TurtleRP_AdminSB_Content2_AAG1TitleInput)
  addBox(TurtleRP_AdminSB_Content2_AtAGlance1ScrollBox_AAG1Input)
  addBox(TurtleRP_AdminSB_Content2_AAG2TitleInput)
  addBox(TurtleRP_AdminSB_Content2_AtAGlance2ScrollBox_AAG2Input)
  addBox(TurtleRP_AdminSB_Content2_AAG3TitleInput)
  addBox(TurtleRP_AdminSB_Content2_AtAGlance3ScrollBox_AAG3Input)

  addBox(TurtleRP_AdminSB_Content3_DescriptionScrollBox_DescriptionInput)

  return TurtleRP.NormalizeNSFWDetectionText(table.concat(parts, " "))
end

function TurtleRP.AdminProfileLooksNSFW()
  local text = TurtleRP.GetAdminNSFWDetectionText()
  local i, keyword

  for i, keyword in ipairs(TurtleRP.NSFWKeywordList) do
    local pattern = "%f[%w]" .. string.lower(keyword) .. "%f[%W]"
    if string.find(text, pattern) then
      return true, keyword
    end
  end

  return false, nil
end

function TurtleRP.RunPendingNSFWSave()
  local callbackName = TurtleRP.pendingNSFWSaveCallback
  TurtleRP.pendingNSFWSaveCallback = nil

  if callbackName == "TurtleRP.save_general" then
    TurtleRP.save_general()
  elseif callbackName == "TurtleRP.save_at_a_glance" then
    TurtleRP.save_at_a_glance()
  elseif callbackName == "TurtleRP.save_description" then
    TurtleRP.save_description()
  elseif callbackName == "TurtleRP.save_notes" then
    TurtleRP.save_notes()
  end

  TurtleRP.pendingNSFWKeyword = nil
  TurtleRP.pendingNSFWOverride = nil
end

function TurtleRP.TryPromptNSFWThen(saveFunctionName)
  if not saveFunctionName or saveFunctionName == "" then
    return
  end
  if TurtleRP.currentlyViewedPetUID and TurtleRP.currentlyViewedPetUID ~= "" then
    TurtleRP.pendingNSFWSaveCallback = saveFunctionName
    TurtleRP.RunPendingNSFWSave()
    return
  end
  if TurtleRP.pendingNSFWOverride == "allow_sfw" then
    TurtleRP.pendingNSFWOverride = nil
    TurtleRP.pendingNSFWSaveCallback = saveFunctionName
    TurtleRP.RunPendingNSFWSave()
    return
  end
  if TurtleRP_AdminSB_Content1_NSFWButton and TurtleRP_AdminSB_Content1_NSFWButton:GetChecked() then
    TurtleRP.pendingNSFWSaveCallback = saveFunctionName
    TurtleRP.RunPendingNSFWSave()
    return
  end
  local detected, keyword = TurtleRP.AdminProfileLooksNSFW()
  if not detected then
    TurtleRP.pendingNSFWSaveCallback = saveFunctionName
    TurtleRP.RunPendingNSFWSave()
    return
  end
  TurtleRP.pendingNSFWSaveCallback = saveFunctionName
  TurtleRP.pendingNSFWKeyword = keyword or ""
  StaticPopup_Show("TTRP_NSFW_DETECTED_CONFIRM")
end

function TurtleRP.cleanDirectory()
  for i, v in TurtleRPCharacters do
    if string.find(i, '°') or string.find(i, '§') then
      local fixedName = TurtleRP.DrunkDecode(i)
      TurtleRPCharacters[fixedName] = TurtleRPCharacters[i]
      TurtleRPCharacters[i] = nil
    end
  end
end
-- allowing for blizzard raid colors based on rp colors setting being off
function TurtleRP.GetClassTokenFromCharacter(character)
    if not character then
        return nil
    end
    if character["class_token"] and character["class_token"] ~= "" then
        local token = string.upper(character["class_token"])
        if RAID_CLASS_COLORS and RAID_CLASS_COLORS[token] then
            return token
        end
    end

    if character["class"] and character["class"] ~= "" then
        local classValue = string.upper(character["class"])
        if RAID_CLASS_COLORS and RAID_CLASS_COLORS[classValue] then
            return classValue
        end
        if LOCALIZED_CLASS_NAMES_MALE then
            for token, localized in pairs(LOCALIZED_CLASS_NAMES_MALE) do
                if localized == character["class"] then
                    return token
                end
            end
        end
        if LOCALIZED_CLASS_NAMES_FEMALE then
            for token, localized in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
                if localized == character["class"] then
                    return token
                end
            end
        end
    end
	
    if character["class_color"] and character["class_color"] ~= "" and TurtleRPClassData then
        local wanted = string.lower(character["class_color"])
        for localizedClass, classData in pairs(TurtleRPClassData) do
            if classData and classData[4] and string.lower(classData[4]) == wanted then
                local token = string.upper(localizedClass)
                if RAID_CLASS_COLORS and RAID_CLASS_COLORS[token] then
                    return token
                end
                if LOCALIZED_CLASS_NAMES_MALE then
                    for raidToken, localized in pairs(LOCALIZED_CLASS_NAMES_MALE) do
                        if localized == localizedClass then
                            return raidToken
                        end
                    end
                end
                if LOCALIZED_CLASS_NAMES_FEMALE then
                    for raidToken, localized in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
                        if localized == localizedClass then
                            return raidToken
                        end
                    end
                end
            end
        end
    end
    return nil
end

function TurtleRP.GetRaidClassColorHex(character)
    local classToken = TurtleRP.GetClassTokenFromCharacter(character)
    if not classToken or not RAID_CLASS_COLORS or not RAID_CLASS_COLORS[classToken] then
        return nil
    end
    local color = RAID_CLASS_COLORS[classToken]
    return string.format("%02x%02x%02x",
        math.floor(color.r * 255),
        math.floor(color.g * 255),
        math.floor(color.b * 255))
end

function TurtleRP.IsRPColorDisabledForPlayer(playerName)
    if not playerName or not TurtleRPCharacterInfo then
        return false
    end
    if not TurtleRPCharacterInfo["character_disable_rp_color"] then
        TurtleRPCharacterInfo["character_disable_rp_color"] = {}
    end
    return TurtleRPCharacterInfo["character_disable_rp_color"][playerName] == "1"
end

function TurtleRP.ToggleRPColorDisabledForPlayer(playerName)
    if not playerName or playerName == "" or playerName == UnitName("player") then
        return
    end
    if not TurtleRPCharacterInfo["character_disable_rp_color"] then
        TurtleRPCharacterInfo["character_disable_rp_color"] = {}
    end

    if TurtleRPCharacterInfo["character_disable_rp_color"][playerName] == "1" then
        TurtleRPCharacterInfo["character_disable_rp_color"][playerName] = "0"
    else
        TurtleRPCharacterInfo["character_disable_rp_color"][playerName] = "1"
    end

    if TurtleRP_CharacterDetails and TurtleRP_CharacterDetails:IsShown() then
        if TurtleRP.currentProfileTab == "notes" then
            TurtleRP.buildNotes(playerName)
        elseif TurtleRP.currentProfileTab == "general" then
            TurtleRP.buildGeneral(playerName)
        end
    end
end

function TurtleRP.GetEffectiveClassColorHex(playerName, character)
    character = character or (TurtleRPCharacters and playerName and TurtleRPCharacters[playerName]) or nil
    if not character then
        return nil
    end

    if playerName and TurtleRP.IsRPColorDisabledForPlayer(playerName) then
        return TurtleRP.GetRaidClassColorHex(character)
    end

    if character["class_color"] and character["class_color"] ~= "" then
        return character["class_color"]
    end

    return TurtleRP.GetRaidClassColorHex(character)
end
-- replacing the IGN with turtle rp name, using the full_name variable
function TurtleRP.GetChatDisplayName(playerName, displayedName, includeTitle)
    local fallbackName = displayedName or playerName or ""
    local showNames = TurtleRPSettings and TurtleRPSettings["chat_names"] == "1"
    local showColors = TurtleRPSettings and TurtleRPSettings["chat_colors"] == "1"
    local character = TurtleRPCharacters and playerName and TurtleRPCharacters[playerName] or nil

    local fallbackStripped = string.gsub(fallbackName, "|[cC][fF][fF]%x%x%x%x%x%x", "")
    fallbackStripped = string.gsub(fallbackStripped, "|[rR]", "")
    if not showNames then
        local effectiveColor = TurtleRP.GetEffectiveClassColorHex(playerName, character)
        if showColors and effectiveColor and effectiveColor ~= "" then
            return "|cff" .. effectiveColor .. fallbackStripped .. "|r"
        end
        return fallbackName
    end
    if not character or not character.full_name or character.full_name == "" then
        local effectiveColor = TurtleRP.GetEffectiveClassColorHex(playerName, character)
        if showColors and effectiveColor and effectiveColor ~= "" then
            return "|cff" .. effectiveColor .. fallbackStripped .. "|r"
        end
        return fallbackName
    end
    local baseName = character.full_name
    local rawName = baseName
    if includeTitle and character.title and character.title ~= "" then
        rawName = character.title .. " " .. rawName
    end
    local strippedName = string.gsub(rawName, "|[cC][fF][fF]%x%x%x%x%x%x", "")
    strippedName = string.gsub(strippedName, "|[rR]", "")
    if showColors then
        if string.find(baseName, "|[cC][fF][fF]%x%x%x%x%x%x") and not TurtleRP.IsRPColorDisabledForPlayer(playerName) then
            return rawName
        end
        local effectiveColor = TurtleRP.GetEffectiveClassColorHex(playerName, character)
        if effectiveColor and effectiveColor ~= "" then
            return "|cff" .. effectiveColor .. strippedName .. "|r"
        end
        return strippedName
    end
    local raidColorHex = TurtleRP.GetRaidClassColorHex(character)
    if raidColorHex then
        return "|cff" .. raidColorHex .. strippedName .. "|r"
    end
    return strippedName
end

function TurtleRP.ReplaceNamesInChat(text)
    if not text or not TurtleRPCharacters then
        return text
    end
    local showNames = TurtleRPSettings["chat_names"] == "1"
    local showColors = TurtleRPSettings["chat_colors"] == "1"
    if not showNames and not showColors then
        return text
    end
    text = string.gsub(text, "(|Hplayer:([^:|]+)[^|]*|h%[)([^%]]+)(%]|h)", function(prefix, rawName, displayedName, suffix)
        if strlower(rawName) == "usertag" then
            return prefix .. "" .. suffix
        end
        local finalName = TurtleRP.GetChatDisplayName(rawName, displayedName, false)
        return prefix .. finalName .. suffix
    end)
    return text
end

function TurtleRP.ResetChatWindowVisuals()
    local i
    for i = 1, 7 do
        local frame = getglobal("ChatFrame" .. i)
        local background = getglobal("ChatFrame" .. i .. "Background")
        if frame then
            if FCF_SetWindowColor then
                FCF_SetWindowColor(frame, 0, 0, 0)
            end
            if FCF_SetWindowAlpha then
                FCF_SetWindowAlpha(frame, 0)
            end
        end
        if background then
            background:SetVertexColor(0, 0, 0)
            background:SetAlpha(0)
            background:Hide()
        end
    end
end

function TurtleRP.InitializeChatHooksDeferred()
    if TurtleRP.chatHooksDelayFrame then
        TurtleRP.chatHooksDelayFrame.elapsed = 0
        TurtleRP.chatHooksDelayFrame:SetScript("OnUpdate", function()
            this.elapsed = (this.elapsed or 0) + arg1
            if this.elapsed < 0.25 then
                return
            end
            this:SetScript("OnUpdate", nil)
            TurtleRP.HookChatFrames()
            TurtleRP.HookPlayerLinkClicks()
            if not TurtleRP.currentEmoteFrameAdapter then
                TurtleRP.emote_events()
            end
            TurtleRP.ResetChatWindowVisuals()
            if ChatFrame1 and FCF_SetWindowName then
                local chatName = GetChatWindowInfo(1)
                if not chatName or chatName == "" then
                    FCF_SetWindowName(ChatFrame1, GENERAL or "General")
                end
            end
        end)
        return
    end

    TurtleRP.chatHooksDelayFrame = CreateFrame("Frame")
    TurtleRP.chatHooksDelayFrame.elapsed = 0
    TurtleRP.chatHooksDelayFrame:SetScript("OnUpdate", function()
        this.elapsed = (this.elapsed or 0) + arg1
        if this.elapsed < 0.25 then
            return
        end
        this:SetScript("OnUpdate", nil)
        TurtleRP.HookChatFrames()
        TurtleRP.HookPlayerLinkClicks()
        if not TurtleRP.currentEmoteFrameAdapter then
            TurtleRP.emote_events()
        end
        TurtleRP.ResetChatWindowVisuals()
        if ChatFrame1 and FCF_SetWindowName then
            local chatName = GetChatWindowInfo(1)
            if not chatName or chatName == "" then
                FCF_SetWindowName(ChatFrame1, GENERAL or "General")
            end
        end
    end)
end

function TurtleRP.HookChatFrames()
    for i = 1, 7 do
        local frame = getglobal("ChatFrame" .. i)
        if frame and not frame.TurtleRPHooked then
            local originalAddMessage = frame.AddMessage
            frame.AddMessage = function(self, text, r, g, b, id, ...)
                local skipReplace = false

                if text then
                    local checkText = text
                    checkText = string.gsub(checkText, "|c%x%x%x%x%x%x%x%x", "")
                    checkText = string.gsub(checkText, "|r", "")
                    checkText = string.gsub(checkText, "|H.-|h(.-)|h", "%1")
                    checkText = string.lower(checkText)

                    if string.find(checkText, "general")
                    or string.find(checkText, "trade")
                    or string.find(checkText, "world")
                    or string.find(checkText, "hardcore")
                    or string.find(checkText, "lookingforgroup")
                    or string.find(checkText, "%f[%a]lfg%f[%A]") then
                        skipReplace = true
                    end
                end

                if not skipReplace then
                    text = TurtleRP.ReplaceNamesInChat(text)
                end

                return originalAddMessage(self, text, r, g, b, id, unpack(arg))
            end

            frame.TurtleRPHooked = true
        end
    end
end

local function TurtleRP_RunAfterDropdowns(callback)
    local waitFrame = CreateFrame("Frame")
    waitFrame:SetScript("OnUpdate", function()
        if (DropDownList1 and DropDownList1:IsVisible()) or (DropDownList2 and DropDownList2:IsVisible()) then
            return
        end
        waitFrame:SetScript("OnUpdate", nil)
        if callback then
            callback()
        end
    end)
end


function TurtleRP.ShowProfileFromChatLink(playerName)
    if not playerName or playerName == "" then
        return
    end

    TurtleRP.currentlyViewedPlayer = playerName
    TurtleRP.sendRequestForData("M", playerName)
    CloseDropDownMenus()
    TurtleRP.OpenProfile("general")
end


function TurtleRP.ShowChatPlayerMenu(playerName)
  if not playerName or playerName == "" then return end
  if not TurtleRP.ChatPlayerMenu then
    TurtleRP.ChatPlayerMenu = CreateFrame("Frame", "TurtleRP_ChatPlayerMenu", UIParent, "UIDropDownMenuTemplate")
  end
  TurtleRP.chatMenuPlayerName = playerName
  UIDropDownMenu_Initialize(TurtleRP.ChatPlayerMenu, function()
    local info = UIDropDownMenu_CreateInfo()

    info.text = playerName
    info.isTitle = 1
    info.notCheckable = 1
    info.disabled = 1
    UIDropDownMenu_AddButton(info)

    info = UIDropDownMenu_CreateInfo()
    info.text = "Whisper"
    info.notCheckable = 1
    info.func = function()
      ChatFrame_SendTell(TurtleRP.chatMenuPlayerName)
    end
    UIDropDownMenu_AddButton(info)

    info = UIDropDownMenu_CreateInfo()
    info.text = "Invite"
    info.notCheckable = 1
    info.func = function()
      InviteByName(TurtleRP.chatMenuPlayerName)
    end
    UIDropDownMenu_AddButton(info)

    info = UIDropDownMenu_CreateInfo()
    info.text = "Target"
    info.notCheckable = 1
    info.func = function()
      TargetByName(TurtleRP.chatMenuPlayerName, true)
    end
    UIDropDownMenu_AddButton(info)

    info = UIDropDownMenu_CreateInfo()
    info.text = "Report Player"
    info.notCheckable = 1
    info.func = function()
      CloseDropDownMenus()
      if ToggleHelpFrame then ToggleHelpFrame() end
      if HelpFrame and HelpFrame:IsShown() and HelpFrame_ShowFrame and HelpFrameOpenTicket then
        HelpFrame_ShowFrame(HelpFrameOpenTicket)
      end
    end
    UIDropDownMenu_AddButton(info)

    info = UIDropDownMenu_CreateInfo()
	info.text = "Show TurtleRP Profile"
    info.notCheckable = 1
    info.func = function()
		local selectedPlayer = TurtleRP.chatMenuPlayerName
		  CloseDropDownMenus()
		  TurtleRP.ForceCloseMap()
		  local openFrame = CreateFrame("Frame")
		  openFrame:SetScript("OnUpdate", function()
			openFrame:SetScript("OnUpdate", nil)
			TurtleRP.ShowProfileFromChatLink(selectedPlayer)
		  end)
		end
    UIDropDownMenu_AddButton(info)

    info = UIDropDownMenu_CreateInfo()
    info.text = "Ignore Player"
    info.notCheckable = 1
    info.func = function()
      AddIgnore(TurtleRP.chatMenuPlayerName)
    end
    UIDropDownMenu_AddButton(info)

    info = UIDropDownMenu_CreateInfo()
    info.text = "Cancel"
    info.notCheckable = 1
    info.func = function()
      CloseDropDownMenus()
    end
    UIDropDownMenu_AddButton(info)
  end)
  ToggleDropDownMenu(1, nil, TurtleRP.ChatPlayerMenu, "cursor", 24, -24)
end

--New chat message to show player_name variable when shift clicking due to the hook overriding it
function TurtleRP.HookPlayerLinkClicks()
    if TurtleRP.playerLinkHooked then
        return
    end

    TurtleRP.playerLinkHooked = true
    TurtleRP.originalSetItemRef = SetItemRef

    SetItemRef = function(link, text, button)
        if not link then
            return TurtleRP.originalSetItemRef(link, text, button)
        end

        local _, _, linkType, playerName = string.find(link, "^(%a+):([^:]+)")
        if linkType ~= "player" or not playerName then
            return TurtleRP.originalSetItemRef(link, text, button)
        end

        if button == "RightButton" then
            TurtleRP.ShowChatPlayerMenu(playerName)
            return
        end

        if IsShiftKeyDown() then
            local message = "|cff999999Player:|r " .. playerName
            if TurtleRP.IsDevProfile(playerName) then
                message = message .. " [" .. TurtleRP.GetDevBadgeText() .. "|r]"
            end
            DEFAULT_CHAT_FRAME:AddMessage(message)
        end

        return TurtleRP.originalSetItemRef(link, text, button)
    end
end

function TurtleRP.EnableStandaloneWorldMapBehavior()
  if pfUI ~= nil then
    return
  end
  if not WorldMapFrame then
    return
  end
  table.insert(UISpecialFrames, "WorldMapFrame")
  UIPanelWindows["WorldMapFrame"] = { area = "center" }
  if not TurtleRP.originalWorldMapOnShow then
    TurtleRP.originalWorldMapOnShow = WorldMapFrame:GetScript("OnShow")
  end
  if not TurtleRP.originalWorldMapOnHide then
    TurtleRP.originalWorldMapOnHide = WorldMapFrame:GetScript("OnHide")
  end
  WorldMapFrame:SetScript("OnShow", function()
    if TurtleRP.originalWorldMapOnShow then
      TurtleRP.originalWorldMapOnShow()
    end
    TurtleRP.RefreshMinimapIconState()
  end)
  WorldMapFrame:SetScript("OnHide", function()
    if TurtleRP.originalWorldMapOnHide then
      TurtleRP.originalWorldMapOnHide()
    end
    TurtleRP.RefreshMinimapIconState()
  end)
  if not TurtleRP.originalToggleWorldMap then
    TurtleRP.originalToggleWorldMap = ToggleWorldMap
  end
  ToggleWorldMap = function()
    if WorldMapFrame:IsShown() then
      WorldMapFrame:Hide()
    else
      WorldMapFrame:Show()
    end
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        TurtleRP.HookPlayerLinkClicks()
        if TurtleRP.OnLoad then
            TurtleRP.OnLoad()
        end
    elseif event == "PLAYER_LEVEL_UP" then
        TurtleRP.CheckLevelForChannel(arg1, false)
    elseif event == "PLAYER_ENTERING_WORLD" then
        TurtleRP.EnableStandaloneWorldMapBehavior()
        TurtleRP.InitializeChatHooksDeferred()
        TurtleRP.CheckLevelForChannel(UnitLevel("player"), true)
    end
end)

function TurtleRP.log(msg)
  DEFAULT_CHAT_FRAME:AddMessage(msg)
end

function TurtleRP.GetGuildDisplayString(playerName, characterInfo)
  if not characterInfo then
    return nil
  end
  local overrideText = characterInfo["guild_override"] or ""
  local guildIC = characterInfo["guild_ic"] or "0"
  local guildOOC = characterInfo["guild_ooc"] or "0"

  local guildColor = "|cffd6bf72"
  local noteColor = "|cff8f8f8f"
  local icColor = "|cff6e9b7f"
  local oocColor = "|cffb28667"

  if overrideText ~= "" then
    local guildStr = guildColor .. "<" .. overrideText .. ">"
    guildStr = guildStr .. " " .. noteColor .. "(Custom)"
    if guildIC == "1" then
      guildStr = guildStr .. " " .. icColor .. "(IC)"
    elseif guildOOC == "1" then
      guildStr = guildStr .. " " .. oocColor .. "(OOC)"
    end
    return guildStr
  end
  local guildName, guildRank
  if playerName and playerName ~= "" then
    if UnitName("player") == playerName then
      guildName, guildRank = GetGuildInfo("player")
    elseif UnitExists("target") and UnitName("target") == playerName then
      guildName, guildRank = GetGuildInfo("target")
    elseif UnitExists("mouseover") and UnitName("mouseover") == playerName then
      guildName, guildRank = GetGuildInfo("mouseover")
    end
  end
  if guildName and guildName ~= "" then
    local guildStr = guildColor .. "<" .. (guildRank or "") .. " of " .. guildName .. ">"
    if guildIC == "1" then
      guildStr = guildStr .. " " .. icColor .. "(IC)"
    elseif guildOOC == "1" then
      guildStr = guildStr .. " " .. oocColor .. "(OOC)"
    end
    return guildStr
  end
  return nil
end
