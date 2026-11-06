--bratmage contribution

TurtleRPAltIdentifier = {}

function TurtleRPAltIdentifier.GetDefaults()
	return {
	  enabled = "0",
	  prefix = "",
	  disable_if_match = "1",

	  guild = "0",
	  officer = "0",
	  party = "0",
	  raid = "0",
	  yell = "0",

	  channels = {}
	}
end

function TurtleRPAltIdentifier.Initialize()
  if TurtleRPSettings == nil then
    TurtleRPSettings = {}
  end

  if TurtleRPSettings["alt_identifier"] == nil then
    TurtleRPSettings["alt_identifier"] = TurtleRPAltIdentifier.GetDefaults()
  end

  local settings = TurtleRPSettings["alt_identifier"]
  local defaults = TurtleRPAltIdentifier.GetDefaults()

  for key, value in pairs(defaults) do
    if settings[key] == nil then
      settings[key] = value
    end
  end

  TurtleRPAltIdentifier.settings = settings
end

function TurtleRPAltIdentifier.GetSettings()
  if TurtleRPSettings == nil then
    return nil
  end
  return TurtleRPSettings["alt_identifier"]
end

function TurtleRPAltIdentifier.GetPlayerName()
  return UnitName("player") or ""
end

function TurtleRPAltIdentifier.IsSlashCommand(msg)
  if not msg or msg == "" then
    return false
  end
  local trimmed = string.gsub(msg, "^%s+", "")
  local firstChar = string.sub(trimmed, 1, 1)
  return firstChar == "/" or firstChar == "."
end

function TurtleRPAltIdentifier.ShouldPrefixMessage(msg, chatType, language, channel)
  local settings = TurtleRPAltIdentifier.GetSettings()
  if not settings then
    return false
  end

  if settings["enabled"] ~= "1" then
    return false
  end
  local prefix = settings["prefix"] or ""
  if prefix == "" then
    return false
  end
  if not msg or string.gsub(msg, "%s", "") == "" then
    return false
  end
  if string.find(msg, "^%(" .. prefix .. "%)") then
    return false
  end
  if TurtleRPAltIdentifier.IsSlashCommand(msg) then
    return false
  end
  if settings["disable_if_match"] == "1" and string.lower(prefix) == string.lower(TurtleRPAltIdentifier.GetPlayerName()) then
    return false
  end
  local finalChatType = string.upper(chatType or "")
  if finalChatType == "CHANNEL" then
    local channelId, channelName = GetChannelName(channel)
    if channelName and TurtleRP and TurtleRP.channelName and string.lower(channelName) == string.lower(TurtleRP.channelName) then
      return false
    end
    if not channelId or channelId == 0 then
      return false
    end
    if settings["channels"] == nil then
      settings["channels"] = {}
    end
    return settings["channels"][tostring(channelId)] == "1"
  end

  if finalChatType == "GUILD" then
    return settings["guild"] == "1"
  elseif finalChatType == "OFFICER" then
    return settings["officer"] == "1"
  elseif finalChatType == "PARTY" then
    return settings["party"] == "1"
  elseif finalChatType == "RAID" then
    return settings["raid"] == "1"
  elseif finalChatType == "YELL" then
    return settings["yell"] == "1"
  end
  return false
end

function TurtleRPAltIdentifier.BuildPrefixedMessage(msg)
  local settings = TurtleRPAltIdentifier.GetSettings()
  if not settings then
    return msg
  end
  local prefix = settings["prefix"] or ""
  if prefix == "" then
    return msg
  end
  return "(" .. prefix .. ") " .. msg
end

function TurtleRPAltIdentifier.GetIdentifierText()
  local settings = TurtleRPAltIdentifier.GetSettings()
  if not settings then
    return ""
  end
  local prefix = settings["prefix"] or ""
  if prefix == "" then
    return ""
  end
  return "(" .. prefix .. ") "
end

function TurtleRPAltIdentifier.GetMaxChatLength(chatType)
  return 255
end

function TurtleRPAltIdentifier.FindChunkBreak(text, maxLen)
  if string.len(text) <= maxLen then
    return string.len(text)
  end
  local slice = string.sub(text, 1, maxLen)
  local i
  for i = maxLen, 1, -1 do
    if string.sub(slice, i, i) == " " then
      return i
    end
  end
  return maxLen
end

function TurtleRPAltIdentifier.SplitMessageForIdentifier(msg, identifierText, chatType)
  local maxLen = TurtleRPAltIdentifier.GetMaxChatLength(chatType)
  local firstChunkLen = maxLen - string.len(identifierText)
  if firstChunkLen <= 0 then
    return nil
  end
  if string.len(identifierText .. msg) <= maxLen then
    return { identifierText .. msg }
  end
  local chunks = {}
  local remaining = msg

  local firstBreak = TurtleRPAltIdentifier.FindChunkBreak(remaining, firstChunkLen)
  table.insert(chunks, identifierText .. string.sub(remaining, 1, firstBreak))
  remaining = string.gsub(string.sub(remaining, firstBreak + 1), "^%s+", "")
  while remaining ~= "" do
    local breakPos = TurtleRPAltIdentifier.FindChunkBreak(remaining, maxLen)
    table.insert(chunks, string.sub(remaining, 1, breakPos))
    remaining = string.gsub(string.sub(remaining, breakPos + 1), "^%s+", "")
  end
  return chunks
end

function TurtleRPAltIdentifier.HookSendChatMessage()
  if TurtleRPAltIdentifier.originalSendChatMessage ~= nil then
    return
  end
  TurtleRPAltIdentifier.originalSendChatMessage = SendChatMessage
  SendChatMessage = function(msg, chatType, language, channel)
    if TurtleRPAltIdentifier.ShouldPrefixMessage(msg, chatType, language, channel) then
      local identifierText = TurtleRPAltIdentifier.GetIdentifierText()
      local chunks = TurtleRPAltIdentifier.SplitMessageForIdentifier(msg, identifierText, chatType)
      if chunks and table.getn(chunks) > 0 then
        local i
        for i = 1, table.getn(chunks) do
          TurtleRPAltIdentifier.originalSendChatMessage(chunks[i], chatType, language, channel)
        end
        return
      end
    end
    TurtleRPAltIdentifier.originalSendChatMessage(msg, chatType, language, channel)
  end
end

function TurtleRPAltIdentifier.GetJoinedChannels()
  local results = {}
  local seen = {}
  local channelList = { GetChannelList() }
  local i = 1
  while i <= table.getn(channelList) do
    local channelId = channelList[i]
    local channelName = channelList[i + 1]
    if type(channelId) == "number" and type(channelName) == "string" and channelName ~= "" then
      if not seen[tostring(channelId)] then
        if not TurtleRP or not TurtleRP.channelName or string.lower(channelName) ~= string.lower(TurtleRP.channelName) then
          table.insert(results, {
            id = channelId,
            name = channelName
          })
          seen[tostring(channelId)] = true
        end
      end
      if type(channelList[i + 2]) == "number" and type(channelList[i + 3]) == "string" then
        i = i + 2
      else
        i = i + 3
      end
    else
      i = i + 1
    end
  end
  table.sort(results, function(a, b)
    return tonumber(a.id) < tonumber(b.id)
  end)

  return results
end

function TurtleRPAltIdentifier.GetSelectedChannelId()
  local settings = TurtleRPAltIdentifier.GetSettings()
  if not settings then
    return ""
  end
  return settings["selected_channel_id"] or ""
end

function TurtleRPAltIdentifier.SetSelectedChannelId(channelId)
  local settings = TurtleRPAltIdentifier.GetSettings()
  if not settings then
    return
  end
  settings["selected_channel_id"] = tostring(channelId or "")
end

function TurtleRPAltIdentifier.IsChannelEnabled(channelId)
  local settings = TurtleRPAltIdentifier.GetSettings()
  if not settings then
    return false
  end
  if settings["channels"] == nil then
    settings["channels"] = {}
  end
  return settings["channels"][tostring(channelId)] == "1"
end

function TurtleRPAltIdentifier.SetChannelEnabled(channelId, enabled)
  local settings = TurtleRPAltIdentifier.GetSettings()
  if not settings then
    return
  end
  if settings["channels"] == nil then
    settings["channels"] = {}
  end
  settings["channels"][tostring(channelId)] = enabled and "1" or "0"
end

function TurtleRPAltIdentifier.ToggleChannelById(channelId)
  if not channelId or channelId == "" then
    return
  end
  TurtleRPAltIdentifier.SetChannelEnabled(channelId, not TurtleRPAltIdentifier.IsChannelEnabled(channelId))
end

function TurtleRPAltIdentifier.InitializeChannelDropdown(dropdown)
  if not dropdown then
    return
  end
  UIDropDownMenu_Initialize(dropdown, function()
    local info = {}
    info.text = "Select Channel..."
    info.value = ""
    info.func = function()
      TurtleRPAltIdentifier.SetSelectedChannelId("")
      UIDropDownMenu_SetSelectedValue(dropdown, "")
      getglobal(dropdown:GetName() .. "Text"):SetText("Select Channel...")
      if TurtleRP and TurtleRP.RefreshAltIdentifierUI then
        TurtleRP.RefreshAltIdentifierUI()
      end
      CloseDropDownMenus()
    end
    UIDropDownMenu_AddButton(info)
    local channels = TurtleRPAltIdentifier.GetJoinedChannels()
    local _, entry
    for _, entry in ipairs(channels) do
      info = {}
      info.text = tostring(entry.id) .. " - " .. entry.name
      info.value = tostring(entry.id)
      info.func = function()
        TurtleRPAltIdentifier.SetSelectedChannelId(this.value)
        UIDropDownMenu_SetSelectedValue(dropdown, this.value)
        getglobal(dropdown:GetName() .. "Text"):SetText(this.text)
        if TurtleRP and TurtleRP.RefreshAltIdentifierUI then
          TurtleRP.RefreshAltIdentifierUI()
        end
        CloseDropDownMenus()
      end
      UIDropDownMenu_AddButton(info)
    end
  end)
end

function TurtleRP.RefreshAltIdentifierUI()
  if not TurtleRP_AdminSB_Content5 then
    return
  end

  TurtleRPAltIdentifier.Initialize()

  local settings = TurtleRPAltIdentifier.GetSettings()
  if not settings then
    return
  end

  local enableButton = TurtleRP_AdminSB_Content5_AltIdentifierEnableButton
  local inputBox = TurtleRP_AdminSB_Content5_AltIdentifierInput
  local disableIfMatchButton = TurtleRP_AdminSB_Content5_AltIdentifierDisableIfMatchButton
  local guildButton = TurtleRP_AdminSB_Content5_AltIdentifierGuildButton
  local officerButton = TurtleRP_AdminSB_Content5_AltIdentifierOfficerButton
  local partyButton = TurtleRP_AdminSB_Content5_AltIdentifierPartyButton
  local raidButton = TurtleRP_AdminSB_Content5_AltIdentifierRaidButton
  local yellButton = TurtleRP_AdminSB_Content5_AltIdentifierYellButton
  local dropdown = TurtleRP_AdminSB_Content5_AltIdentifierChannelDropdown
  local channelToggleButton = TurtleRP_AdminSB_Content5_AltIdentifierChannelToggleButton

  enableButton:SetChecked(settings["enabled"] == "1")
  inputBox:SetText(settings["prefix"] or "")
  disableIfMatchButton:SetChecked(settings["disable_if_match"] == "1")

  guildButton:SetChecked(settings["guild"] == "1")
  officerButton:SetChecked(settings["officer"] == "1")
  partyButton:SetChecked(settings["party"] == "1")
  raidButton:SetChecked(settings["raid"] == "1")
  yellButton:SetChecked(settings["yell"] == "1")

  TurtleRPAltIdentifier.InitializeChannelDropdown(dropdown)

  local selectedChannelId = TurtleRPAltIdentifier.GetSelectedChannelId()
  local dropdownText = getglobal(dropdown:GetName() .. "Text")
  local displayText = "Select Channel..."

  if selectedChannelId and selectedChannelId ~= "" then
    local channels = TurtleRPAltIdentifier.GetJoinedChannels()
    local _, entry
    for _, entry in ipairs(channels) do
      if tostring(entry.id) == tostring(selectedChannelId) then
        displayText = tostring(entry.id) .. " - " .. entry.name
        break
      end
    end
    UIDropDownMenu_SetSelectedValue(dropdown, selectedChannelId)
  else
    UIDropDownMenu_SetSelectedValue(dropdown, "")
  end
  if dropdownText then
    dropdownText:SetText(displayText)
  end
  if channelToggleButton then
    if selectedChannelId and selectedChannelId ~= "" and TurtleRPAltIdentifier.IsChannelEnabled(selectedChannelId) then
      channelToggleButton:SetText("Disable")
    else
      channelToggleButton:SetText("Enable")
    end
  end
end

function TurtleRP.ToggleAltIdentifierEnabled()
  TurtleRPAltIdentifier.Initialize()
  local settings = TurtleRPAltIdentifier.GetSettings()
  if not settings then
    return
  end
  if settings["enabled"] == "1" then
    settings["enabled"] = "0"
  else
    settings["enabled"] = "1"
  end
  TurtleRP.RefreshAltIdentifierUI()
  if TurtleRP.RefreshAdminStateSnapshot then
    TurtleRP.RefreshAdminStateSnapshot()
  end
end

function TurtleRP.SaveAltIdentifierPrefix()
  TurtleRPAltIdentifier.Initialize()
  local settings = TurtleRPAltIdentifier.GetSettings()
  if not settings then
    return
  end
  local text = TurtleRP_AdminSB_Content5_AltIdentifierInput:GetText() or ""
  settings["prefix"] = TurtleRP.validateBeforeSaving(text) or ""
  TurtleRP_AdminSB_Content5_AltIdentifierInput:ClearFocus()
  TurtleRP.RefreshAltIdentifierUI()
  if TurtleRP.RefreshAdminStateSnapshot then
    TurtleRP.RefreshAdminStateSnapshot()
  end
end

function TurtleRP.ToggleAltIdentifierDisableIfMatch()
  TurtleRPAltIdentifier.Initialize()
  local settings = TurtleRPAltIdentifier.GetSettings()
  if not settings then
    return
  end
  if settings["disable_if_match"] == "1" then
    settings["disable_if_match"] = "0"
  else
    settings["disable_if_match"] = "1"
  end
  TurtleRP.RefreshAltIdentifierUI()
  if TurtleRP.RefreshAdminStateSnapshot then
    TurtleRP.RefreshAdminStateSnapshot()
  end
end

function TurtleRP.ToggleAltIdentifierChatType(chatType, button)
  TurtleRPAltIdentifier.Initialize()
  local settings = TurtleRPAltIdentifier.GetSettings()
  if not settings or not chatType then
    return
  end
  if settings[chatType] == "1" then
    settings[chatType] = "0"
  else
    settings[chatType] = "1"
  end
  if button then
    button:SetChecked(settings[chatType] == "1")
  end
  if TurtleRP.RefreshAdminStateSnapshot then
    TurtleRP.RefreshAdminStateSnapshot()
  end
end

function TurtleRP.ToggleAltIdentifierSelectedChannel()
  TurtleRPAltIdentifier.Initialize()

  local channelId = TurtleRPAltIdentifier.GetSelectedChannelId()
  if not channelId or channelId == "" then
    return
  end
  TurtleRPAltIdentifier.ToggleChannelById(channelId)
  TurtleRP.RefreshAltIdentifierUI()
  if TurtleRP.RefreshAdminStateSnapshot then
    TurtleRP.RefreshAdminStateSnapshot()
  end
end

function TurtleRP.RefreshAltIdentifierChannels()
  TurtleRPAltIdentifier.Initialize()
  TurtleRP.RefreshAltIdentifierUI()
  if TurtleRP.RefreshAdminStateSnapshot then
    TurtleRP.RefreshAdminStateSnapshot()
  end
end

function TurtleRPAltIdentifier.OnVariablesLoaded()
  TurtleRPAltIdentifier.Initialize()
  TurtleRPAltIdentifier.HookSendChatMessage()
end

local TurtleRPAltIdentifierFrame = CreateFrame("Frame")
TurtleRPAltIdentifierFrame:RegisterEvent("VARIABLES_LOADED")
TurtleRPAltIdentifierFrame:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    TurtleRPAltIdentifier.OnVariablesLoaded()
  end
end)

SLASH_TTRPAI1 = "/tai"

function SlashCmdList.TTRPAI(msg)
  local settings = TurtleRPAltIdentifier.GetSettings()
  if not settings then return end

  if msg == "on" then
    settings.enabled = "1"
    print("Alt-Identifier enabled")
  elseif msg == "off" then
    settings.enabled = "0"
    print("Alt-Identifier disabled")
  elseif string.sub(msg, 1, 4) == "set " then
    local name = string.sub(msg, 5)
    settings.prefix = name
    print("Alt-Identifier set to:", name)
  elseif msg == "test" then
    print("Prefix:", settings.prefix)
    print("Enabled:", settings.enabled)
  elseif msg == "channels" then
    local channels = TurtleRPAltIdentifier.GetJoinedChannels()
    if table.getn(channels) == 0 then
      print("No joined channels found.")
      return
    end
    for _, v in ipairs(channels) do
      local enabled = settings.channels and settings.channels[tostring(v.id)] == "1"
      print(v.id .. ": " .. v.name .. " - " .. (enabled and "ON" or "OFF"))
    end
  elseif string.sub(msg, 1, 11) == "channel on " then
    local channelId = string.sub(msg, 12)
    if channelId ~= "" then
      settings.channels[tostring(channelId)] = "1"
      print("Alt-Identifier enabled for channel " .. channelId)
    end
  elseif string.sub(msg, 1, 12) == "channel off " then
    local channelId = string.sub(msg, 13)
    if channelId ~= "" then
      settings.channels[tostring(channelId)] = "0"
      print("Alt-Identifier disabled for channel " .. channelId)
    end
  else
    print("/tai on | off | set NAME | test | channels | channel on # | channel off #")
  end
end