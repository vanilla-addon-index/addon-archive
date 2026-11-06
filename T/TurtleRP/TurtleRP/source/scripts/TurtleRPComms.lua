--[[
  Created by Vee (http://victortemprano.com), Drixi in-game
  See Github repo at https://github.com/tempranova/turtlerp

-- Communication system
--- Notes :
--- ALL information send via the chat channel is stored by ALL players;
---  every player updates their unique key anytime a new message is sent out

-- Request types
M Mouseover
T Target
D Description

-- Data responses
MR
TR
DR

-- Player1 sends out a request for information.
  - If they have no key for that player: "<request type>:<Player2>~NO_KEY"
  - If they have a key for that player: "<request type>:<Player2>~<unique key>"
  - In the meantime, Player1 displays whatever they have stored locally
-- Player2 is listening, recieves the request
  - If the key matches their local key, they send nothing back
  - If the key doesn't match, they send a response: "<data type>:<Player2>~<unique key>~<DATA>"

]]

local lastRequestType = nil
local lastPlayerName = nil
local timeOfLastSend = time()
local lastMouseoverKey = nil
local lastMouseoverRequestAt = 0
local mouseoverRequestCooldown = 2
local lastPetMouseoverKey = nil
local lastPetMouseoverRequestAt = 0
local petMouseoverRequestCooldown = 8
TurtleRP.requestCooldowns = TurtleRP.requestCooldowns or {}
function TurtleRP.CanSendRequest(requestType, targetKey, cooldownSeconds)
  local now, requestKey, lastAt

  if not requestType or requestType == "" or not targetKey or targetKey == "" then
    return false
  end
  now = GetTime and GetTime() or time()
  requestKey = requestType .. ":" .. targetKey
  lastAt = TurtleRP.requestCooldowns[requestKey]

  if lastAt and (now - lastAt) < (cooldownSeconds or 0) then
    return false
  end
  TurtleRP.requestCooldowns[requestKey] = now
  return true
end
function TurtleRP.TrySendRequest(requestType, targetKey, cooldownSeconds)
  if TurtleRP.CanSendRequest(requestType, targetKey, cooldownSeconds) then
    TurtleRP.sendRequestForData(requestType, targetKey)
    return true
  end
  return false
end
local function TurtleRP_CanSendPetMouseoverRequest(petCommKey)
  local now = GetTime and GetTime() or time()
  if not petCommKey or petCommKey == "" then
    return false
  end
  if lastPetMouseoverKey ~= petCommKey or (now - lastPetMouseoverRequestAt) >= petMouseoverRequestCooldown then
    lastPetMouseoverKey = petCommKey
    lastPetMouseoverRequestAt = now
    return true
  end
  return false
end
local rpRequestQueue = {}
local rpRequestLookup = {}
local rpSeenSpeakers = {}
local versionWarningShown = {}
local lastMouseoverPlayer = nil
local lastMouseoverPetKey = nil
local failedPetLookups = {}
local failedPetLookupCooldown = 60

local function TurtleRP_IsFailedPetLookup(unitKey)
  local now = GetTime and GetTime() or time()
  local lastAt = failedPetLookups[unitKey]
  if lastAt and (now - lastAt) < failedPetLookupCooldown then
    return true
  end
  return false
end

local function TurtleRP_MarkFailedPetLookup(unitKey)
  local now = GetTime and GetTime() or time()
  if unitKey and unitKey ~= "" then
    failedPetLookups[unitKey] = now
  end
end

TurtleRP.rpSeenSpeakers = rpSeenSpeakers

local splitString

-----
-- Interface interaction for communication and display
-----
function TurtleRP.mouseover_and_target_events()
  splitString = TurtleRP.splitString

  local TurtleRPTargetFrame = CreateFrame("Frame", "TurtleRPTargetFrame")
  TurtleRPTargetFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
  TurtleRPTargetFrame:SetScript("OnEvent", function()
    if UnitIsPlayer("target") then
      if UnitName("target") == UnitName("player") then
        TurtleRP.buildTargetFrame(UnitName("player"))
      else
        TurtleRP_Target:Hide()
        TurtleRP.TrySendRequest("T", UnitName("target"), 10)
      end

    elseif TurtleRP.IsOwnedPetUnit and TurtleRP.IsOwnedPetUnit("target") then
      local localPetProfile = nil
      local petCommKey = TurtleRP.GetPetCommKeyFromUnit and TurtleRP.GetPetCommKeyFromUnit("target") or nil

      if TurtleRP.GetPetProfileFromUnit then
        localPetProfile = TurtleRP.GetPetProfileFromUnit("target")
      end

      if localPetProfile then
        TurtleRP.buildPetTargetFrame(localPetProfile)
      elseif petCommKey then
        TurtleRP_Target:Hide()
        TurtleRP.TrySendRequest("PT", petCommKey, 10)
      else
        TurtleRP_Target:Hide()
      end

    else
      TurtleRP_Target:Hide()
    end
  end)

  local TurtleRPMouseoverFrame = CreateFrame("Frame", "TurtleRPMouseoverFrame")
  TurtleRPMouseoverFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
  TurtleRPMouseoverFrame:SetScript("OnEvent", function()
    if UnitIsPlayer("mouseover") then
      local mouseoverPlayer = UnitName("mouseover")
      if mouseoverPlayer ~= lastMouseoverPlayer then
        lastMouseoverPlayer = mouseoverPlayer
        lastMouseoverPetKey = nil
        TurtleRP.TrySendRequest("M", mouseoverPlayer, 30)
      end

    elseif TurtleRP.IsOwnedPetUnit and TurtleRP.IsOwnedPetUnit("mouseover") then
      local petCommKey = TurtleRP.GetPetCommKeyFromUnit and TurtleRP.GetPetCommKeyFromUnit("mouseover") or nil

      local failedKey = petCommKey or UnitName("mouseover")
      if failedKey and TurtleRP_IsFailedPetLookup(failedKey) then
        return
      end
      if petCommKey then
        TurtleRP.lastTooltipPetKey = petCommKey
        if petCommKey ~= lastMouseoverPetKey then
          lastMouseoverPetKey = petCommKey
          lastMouseoverPlayer = nil
          if TurtleRPPetCache and TurtleRPPetCache[petCommKey] then
            TurtleRP.buildPetTooltip("mouseover", petCommKey)
          elseif TurtleRP_CanSendPetMouseoverRequest(petCommKey) then
            if not TurtleRP.TrySendRequest("PM", petCommKey, 30) then
              TurtleRP_MarkFailedPetLookup(failedKey)
            end
          end
        end
      end
    end
  end)

  TurtleRP.targetFrame:EnableMouse()
  local defaultTargetFrameFunction = TurtleRP.targetFrame:GetScript("OnEnter")
  TurtleRP.targetFrame:SetScript("OnEnter", function()
    if defaultTargetFrameFunction then
      defaultTargetFrameFunction()
    end

    if UnitName("target") == UnitName("player") then
      TurtleRP.buildTooltip(UnitName("player"), "target")
    elseif TurtleRP.IsOwnedPetUnit and TurtleRP.IsOwnedPetUnit("target") then
      TurtleRP.buildPetTooltip("target")
    end
  end)
end

----
-- Chat setup
----

-- This function often runs too early
function TurtleRP.communication_prep()
  if TurtleRP.canChat() then
    TurtleRP.pingWithLocationAndVersion("A")
  end

  local TurtleRPChannelJoinDelay = CreateFrame("Frame")
  local delayedTime = GetTime() + 15
  TurtleRPChannelJoinDelay:SetScript("OnUpdate", function()
    if GetTime() >= delayedTime then
        this:SetScript("OnUpdate", nil)
        TurtleRP.checkTTRPChannel()
    end
  end)
end

function TurtleRP.send_ping_message()
  if TurtleRP.canChat() then
    TurtleRP.pingWithLocationAndVersion("P")
  end
  local TurtleRPChannelPingDelay = CreateFrame("Frame", "TurtleRPChannelPingDelay")
  local nextSend = GetTime() + TurtleRP.timeBetweenPings
  TurtleRPChannelPingDelay:SetScript("OnUpdate", function()
    if GetTime() >= nextSend then
      nextSend = GetTime() + TurtleRP.timeBetweenPings
      if TurtleRP.disableMessageSending == nil then
        if TurtleRP.canChat() then
          TurtleRP.pingWithLocationAndVersion("P")
        end
      end
    end
  end)
end

function TurtleRP.checkTTRPChannel()
  local lastVal = 0
  local chanList = { GetChannelList() }

  for _, value in next, chanList do
    if value == TurtleRP.channelName then
      TurtleRP.channelIndex = lastVal
      break
    end
    lastVal = value
  end

  if TurtleRP.channelIndex == 0 then
    JoinChannelByName(TurtleRP.channelName)
  end

  if TurtleRP.canChat() then
    TurtleRP.pingWithLocationAndVersion("A")
  end
end

function TurtleRP.communication_events()
    TurtleRP_Target_DescriptionButton:SetScript("OnClick", function()
        if UnitIsPlayer("target") then
            TurtleRP.OpenProfile()
            if UnitName("target") == UnitName("player") then
                TurtleRP.buildDescription(UnitName("player"))
            else
                TurtleRP.TrySendRequest("D", UnitName("target"), 5)
            end
            return
        end
        if TurtleRP.IsOwnedPetUnit and TurtleRP.IsOwnedPetUnit("target") then
            local localPetProfile = TurtleRP.GetPetProfileFromUnit and TurtleRP.GetPetProfileFromUnit("target") or nil
            local petUID = TurtleRP.GetPetUID and TurtleRP.GetPetUID("target") or nil

            if localPetProfile and petUID then
                TurtleRP.OpenPetProfile(petUID, "description")
            else
                local petCommKey = TurtleRP.GetPetCommKeyFromUnit and TurtleRP.GetPetCommKeyFromUnit("target") or nil
                if petCommKey then
                    TurtleRP.showDescription = petCommKey
                    TurtleRP.TrySendRequest("PD", petCommKey, 5)
                end
            end
        end
    end)
    local CheckMessages = CreateFrame("Frame", "TurtleRPMessageScanner")
    CheckMessages:RegisterEvent("CHAT_MSG_CHANNEL")
    CheckMessages:SetScript("OnEvent", function()
        if event == "CHAT_MSG_CHANNEL" then
            local channelName = string.lower(arg9 or "")
            local sender = arg2
            if channelName == string.lower(TurtleRP.channelName) then
                TurtleRP.checkChatMessage(TurtleRP.DrunkDecode(arg1), sender)
            end
        end
    end)
end

----
-- Player communication
----
function TurtleRP.sendRequestForData(requestType, targetKey)
  if not TurtleRP.canChat() or not targetKey or targetKey == "" then
    return
  end
	if string.sub(requestType, 1, 1) ~= "P" and targetKey == UnitName("player") then
	  if not TurtleRP.previewSource and not TurtleRP.previewCharacterInfo then
		TurtleRP.displayData(requestType, targetKey)
	  end
	  return
	end
  if timeOfLastSend < (time() - 1) or lastRequestType ~= requestType or lastPlayerName ~= targetKey then
    timeOfLastSend = time()
    lastRequestType = requestType
    lastPlayerName = targetKey
    if string.sub(requestType, 1, 1) == "P" then
      local petCache = TurtleRPPetCache and TurtleRPPetCache[targetKey] or nil
      if petCache and petCache["key" .. string.sub(requestType, 2, 2)] ~= nil then
        TurtleRP.ttrpChatSend(requestType .. ':' .. targetKey .. '~' .. petCache["key" .. string.sub(requestType, 2, 2)])
        TurtleRP.displayData(requestType, targetKey)
      else
        TurtleRP.ttrpChatSend(requestType .. ':' .. targetKey .. '~NO_KEY')
      end
    else
      if TurtleRPQueryablePlayers[targetKey] ~= nil or TurtleRPCharacters[targetKey] ~= nil then
        if TurtleRPCharacters[targetKey] ~= nil and TurtleRPCharacters[targetKey]['key' .. requestType] ~= nil then
          local currentKey = TurtleRPCharacters[targetKey]['key' .. requestType]
          TurtleRP.ttrpChatSend(requestType .. ':' .. targetKey .. '~' .. currentKey)
          TurtleRP.displayData(requestType, targetKey)
        else
          TurtleRP.ttrpChatSend(requestType .. ':' .. targetKey .. '~NO_KEY')
        end
      end
    end
  end
end

function TurtleRP.checkChatMessage(msg, senderName)
  local colonStart, colonEnd = string.find(msg, ':')
  if colonStart then
    local dataPrefix = string.sub(msg, 1, colonEnd - 1)
    local tildeStart, tildeEnd = string.find(msg, '~')
    local targetKeyFromString
    local isForMe = nil
    local isResponse
    if not tildeStart or tildeStart <= colonEnd then
      return
    end
    targetKeyFromString = string.sub(msg, colonEnd + 1, tildeEnd - 1)
    if not targetKeyFromString or targetKeyFromString == "" then
      return
    end
    if string.sub(dataPrefix, 1, 1) == "P" then
      if TurtleRP.GetLocalPetProfileForCommKey and TurtleRP.GetLocalPetProfileForCommKey(targetKeyFromString) then
        isForMe = true
      end
    else
      if targetKeyFromString == UnitName("player") then
        isForMe = true
      end
    end
    isResponse = string.sub(dataPrefix, -1) == "R"
    if isResponse then
      TurtleRP.recieveAndStoreData(dataPrefix, senderName, msg, targetKeyFromString)
    elseif isForMe then
      if TurtleRP.canChat() and TurtleRP.checkUniqueKey(dataPrefix, msg) ~= true then
        TurtleRP.sendData(dataPrefix, targetKeyFromString)
      end
    end
  else
    local firstLetter = string.sub(msg, 1, 1)
    if firstLetter == "P" or firstLetter == "A" then
      TurtleRP.recievePingInformation(senderName, msg)
    end
  end
end

function TurtleRP.checkUniqueKey(dataPrefix, msg)
  local keyValid = false
  local dataFromString = TurtleRP.getDataFromString(msg)
  local keyData = dataFromString[2]
  if keyData == "NO_KEY" then
    return false
  end
  if string.sub(dataPrefix, 1, 1) == "P" then
  local petProfile = nil
  local targetKey = nil
  local _, _, extractedKey = string.find(msg, "^[^:]+:([^~]+)~")
  targetKey = extractedKey

  if TurtleRP.GetLocalPetProfileForCommKey then
    petProfile = TurtleRP.GetLocalPetProfileForCommKey(targetKey)
  end

  local logicalPrefix = string.sub(dataPrefix, 2, 2)
  if petProfile and keyData == petProfile["key" .. logicalPrefix] then
    keyValid = true
  end
	else
	  if keyData == TurtleRPCharacterInfo["key" .. dataPrefix] then
		keyValid = true
	  end
	end
  return keyValid
end

local dataSplitTable = {}
function TurtleRP.getDataFromString(msg)
  local beginningOfData = strfind(msg, "~")
  local dataSlice = strsub(msg, beginningOfData)
  local splitArray = splitString(dataSlice, "~", dataSplitTable)
  return splitArray
end

function sendChunks(dataPrefix, targetKey, stringChunks, uniqueKey)
  local totalToSend = table.getn(stringChunks)
  for i in stringChunks do
    TurtleRP.ttrpChatSend(dataPrefix .. 'R:' .. targetKey .. "~" .. uniqueKey .. '~' .. i .. '~' .. totalToSend .. '~' .. stringChunks[i])
  end
end

function TurtleRP.GetCommDataSource(dataPrefix, targetKey)
  if string.sub(dataPrefix, 1, 1) == "P" then
    local petProfile = TurtleRP.GetLocalPetProfileForCommKey and TurtleRP.GetLocalPetProfileForCommKey(targetKey) or nil
    return petProfile
  end
  return TurtleRPCharacterInfo
end

function TurtleRP.GetLogicalCommPrefix(dataPrefix)
  if string.sub(dataPrefix, 1, 1) == "P" then
    return string.sub(dataPrefix, 2, 2)
  end
  return dataPrefix
end

function TurtleRP.sendData(dataPrefix, targetKey)
  local sourceData = TurtleRP.GetCommDataSource(dataPrefix, targetKey)
  local logicalPrefix = TurtleRP.GetLogicalCommPrefix(dataPrefix)
  if not sourceData or not sourceData["key" .. logicalPrefix] then
    return
  end
  local stringChunks = TurtleRP.splitByChunk(TurtleRP.buildDataStringToSend(dataPrefix, sourceData), 230)
  sendChunks(dataPrefix, targetKey, stringChunks, sourceData["key" .. logicalPrefix])
end

function TurtleRP.buildDataStringToSend(dataPrefix, sourceData)
  local dataToBuild = TurtleRP.dataKeys(dataPrefix)
  local stringToSend = ""
  local logicalSource = sourceData or TurtleRPCharacterInfo
  for i, dataRef in ipairs(dataToBuild) do
    if i ~= 1 then
      local thisData = logicalSource[dataRef]
      if dataRef == "description" then
        thisData = gsub(logicalSource["description"] or "", "%\n", "@N")
        if thisData == "" then
          thisData = " "
        end
      end
      if thisData == nil then
        thisData = ""
      end
      local frontDelimiter = i == 2 and "" or "~"
      stringToSend = stringToSend .. frontDelimiter .. thisData
    end
  end
  return stringToSend
end

local dataKeys = {
	["M"] = {
		"keyM",
		"icon",
		"full_name",
		"race",
		"class",
		"class_color",
		"ooc_info",
		"ic_info",
		"currently_ic",
		"ooc_pronouns",
		"ic_pronouns",
		"nsfw",
		"title",
		"class_token",
		"faction",
		"guild_override",
		"guild_ic",
		"guild_ooc"
	},
	["T"] = {
		"keyT",
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
		"currently"
	},
	["D"] = {"keyD", "description", "description_link_text", "description_link"},

    ["PM"] = {
        "keyM",
        "icon",
        "name",
        "species",
        "level",
        "info",
        "pronouns"
    },
    ["PT"] = {
        "keyT",
        "atAGlance1",
        "atAGlance1Title",
        "atAGlance1Icon",
        "atAGlance2",
        "atAGlance2Title",
        "atAGlance2Icon",
        "atAGlance3",
        "atAGlance3Title",
        "atAGlance3Icon",
        "name",
        "species",
        "level"
    },
    ["PD"] = {"keyD", "description"}
}

dataKeys["MR"], dataKeys["TR"], dataKeys["DR"] = dataKeys["M"], dataKeys["T"], dataKeys["D"]
dataKeys["PMR"], dataKeys["PTR"], dataKeys["PDR"] = dataKeys["PM"], dataKeys["PT"], dataKeys["PD"]

local emptyDataKeys = {}

function TurtleRP.dataKeys(dataPrefix)
    return dataKeys[dataPrefix] or emptyDataKeys
end

function TurtleRP.storeChunkedData(dataPrefix, playerName, stringData)
  local tempKey = "temp" .. dataPrefix
  local chunkIndex = tonumber(stringData[3] or "")
  local chunkTotal = tonumber(stringData[4] or "")
  local totalReceived = table.getn(stringData)
  local justDataString = ""
  local i

  if TurtleRPCharacters[playerName] == nil then
    TurtleRPCharacters[playerName] = {}
  end
  if TurtleRPCharacters[playerName][tempKey] == nil then
    TurtleRPCharacters[playerName][tempKey] = ""
  end
  if not chunkIndex or not chunkTotal or chunkIndex < 1 or chunkTotal < 1 or chunkIndex > chunkTotal then
    return false
  end
  if chunkIndex == 1 then
    TurtleRPCharacters[playerName][tempKey] = ""
  end
  if TurtleRPCharacters[playerName][tempKey] == "" and stringData[2] ~= nil then
    justDataString = stringData[2] .. "~"
  end
  for i = 5, totalReceived do
    justDataString = justDataString .. (stringData[i] or "") .. (i == totalReceived and "" or "~")
  end
  TurtleRPCharacters[playerName][tempKey] = TurtleRPCharacters[playerName][tempKey] .. justDataString
  return chunkIndex == chunkTotal
end

local processSplitTable = {}
function TurtleRP.processAndStoreData(dataPrefix, storageTable, storageKey)
  local dataToSave = TurtleRP.dataKeys(dataPrefix)
  local tempKey = "temp" .. dataPrefix
  local rawData
  local strs
  local i, dataRef
  if not storageTable or not storageKey or not storageTable[storageKey] then
    return false
  end
  if not dataToSave or table.getn(dataToSave) == 0 then
    return false
  end
  rawData = storageTable[storageKey][tempKey]
  if rawData == nil or rawData == "" then
    return false
  end
  strs = splitString(rawData, "~", processSplitTable)
  for i, dataRef in ipairs(dataToSave) do
    if strs[i] ~= nil then
      storageTable[storageKey][dataRef] = strs[i]
    else
      storageTable[storageKey][dataRef] = ""
    end
  end
  return true
end

function TurtleRP.recieveAndStoreData(dataPrefix, senderName, msg, targetKey)
  local stringData = TurtleRP.getDataFromString(msg)
  local storageTable = nil
  local storageKey = nil
  if string.sub(dataPrefix, 1, 1) == "P" then
    if TurtleRPPetCache == nil then
      TurtleRPPetCache = {}
    end
    storageTable = TurtleRPPetCache
    storageKey = targetKey
    if storageTable[storageKey] == nil then
      storageTable[storageKey] = {}
    end
    storageTable[storageKey]["owner_name"] = senderName
  else
    storageTable = TurtleRPCharacters
    storageKey = senderName
    if storageTable[storageKey] == nil then
      storageTable[storageKey] = {}
    end
  end

  if dataPrefix == "MR" or dataPrefix == "TR" or dataPrefix == "DR" or dataPrefix == "PMR" or dataPrefix == "PTR" or dataPrefix == "PDR" then
    local readyToProcess = false
    local processed = false
    local tempKey = "temp" .. dataPrefix
    local chunkIndex = tonumber(stringData[3] or "")
    local chunkTotal = tonumber(stringData[4] or "")
    local totalReceived = table.getn(stringData)
    local justDataString = ""
    local i

    if storageTable[storageKey][tempKey] == nil then
      storageTable[storageKey][tempKey] = ""
    end

    if chunkIndex and chunkTotal and chunkIndex >= 1 and chunkTotal >= 1 and chunkIndex <= chunkTotal then
      if string.sub(dataPrefix, 1, 1) == "P" then
        if chunkIndex == 1 then
          storageTable[storageKey][tempKey] = ""
        end
        if storageTable[storageKey][tempKey] == "" and stringData[2] ~= nil then
          storageTable[storageKey][tempKey] = stringData[2] .. "~"
        end
        for i = 5, totalReceived do
          justDataString = justDataString .. (stringData[i] or "") .. (i == totalReceived and "" or "~")
        end
        storageTable[storageKey][tempKey] = storageTable[storageKey][tempKey] .. justDataString
        readyToProcess = (chunkIndex == chunkTotal)
      else
        readyToProcess = TurtleRP.storeChunkedData(dataPrefix, storageKey, stringData)
      end
    end

    if readyToProcess then
      processed = TurtleRP.processAndStoreData(dataPrefix, storageTable, storageKey)
      if processed then
        if dataPrefix == "MR" then
          TurtleRP.RefreshDirectoryIfVisible()
        end
        TurtleRP.displayData(dataPrefix, storageKey)
      end
    end
  end
end

local pingSplitTable = {}
function TurtleRP.recievePingInformation(playerName, msg)
    local zoneText = string.sub(msg, 2)
    TurtleRPQueryablePlayers[playerName] = time()
    if TurtleRPCharacters[playerName] == nil then
        TurtleRPCharacters[playerName] = {}
    end
    local charData = TurtleRPCharacters[playerName]
    charData["zone"] = zoneText
    local strs = splitString(zoneText, "~", pingSplitTable)
    if table.getn(strs) < 3 then
        return
    end

    local zone = strs[1]
    charData["zone"] = zone
    charData["zoneX"] = strs[2]
    charData["zoneY"] = strs[3]

    if strs[4] ~= nil and strs[4] ~= "" then
        charData["version"] = strs[4]
    else
        charData["version"] = "unknown"
    end

    if charData["version"] ~= "unknown" and TurtleRP.currentVersion ~= nil and TurtleRP.currentVersion ~= "" then
        if TurtleRP.IsVersionOlder(charData["version"], TurtleRP.currentVersion) then
            charData["outdated_version"] = "1"
        else
            charData["outdated_version"] = "0"
        end
        if TurtleRP.IsVersionOlder(TurtleRP.latestVersion or TurtleRP.currentVersion, charData["version"]) then
            TurtleRP.latestVersion = charData["version"]
        end
        if TurtleRP.IsVersionOlder(TurtleRP.currentVersion, charData["version"]) then
            if not versionWarningShown["shown"] then
                versionWarningShown["shown"] = true
                DEFAULT_CHAT_FRAME:AddMessage("|cffFF5555[TurtleRP]|r Your TurtleRP version is outdated.")
                DEFAULT_CHAT_FRAME:AddMessage("|cffAAAAAAInstalled: " .. TurtleRP.currentVersion .. " | Latest seen: " .. charData["version"] .. "|r")
                DEFAULT_CHAT_FRAME:AddMessage("|cffAAAAAAPlease update via Turtle Launcher to avoid compatibility issues. |cff587BAF - https://github.com/bratmage/TurtleRP.git -|r")
            end
        end
    else
        charData["outdated_version"] = "0"
    end

    if strs[5] ~= nil and strs[5] ~= "" then
        charData["currently_ic"] = strs[5]
    else
        charData["currently_ic"] = "1"
    end

    if strs[6] ~= nil and strs[6] ~= "" then
        charData["protocol_version"] = strs[6]
    else
        charData["protocol_version"] = "1"
    end

    if strs[7] ~= nil and strs[7] ~= "" then
        charData["faction"] = strs[7]
    else
        charData["faction"] = "neutral"
    end

    if strs[8] ~= nil and strs[8] ~= "" then
        charData["full_name"] = strs[8]
    end

    if strs[9] ~= nil and strs[9] ~= "" then
        charData["class_color"] = strs[9]
    end

    if not WorldMapFrame:IsVisible() then
        return
    end

    if zone == TurtleRP.GetZones(GetCurrentMapContinent())[GetCurrentMapZone()] then
        TurtleRP.show_player_locations()
    end
end

function TurtleRP.displayData(dataPrefix, storageKey)
  if (dataPrefix == "M" or dataPrefix == "MR") and storageKey == UnitName("mouseover") then
    TurtleRP.buildTooltip(storageKey, "mouseover")
  end
  if (dataPrefix == "T" or dataPrefix == "TR") and storageKey == UnitName("target") then
    TurtleRP.buildTargetFrame(storageKey)
  end
  if (dataPrefix == "D" or dataPrefix == "DR") and storageKey == UnitName("target") then
    TurtleRP.buildDescription(storageKey)
  end
	if (dataPrefix == "PM" or dataPrefix == "PMR") and UnitExists("mouseover") and not UnitIsPlayer("mouseover") then
	  if TurtleRPPetCache and TurtleRPPetCache[storageKey] then
        TurtleRP.lastTooltipPetKey = storageKey
		if TurtleRP.ShouldUseCustomTooltip and TurtleRP.ShouldUseCustomTooltip() then
		  TurtleRP.buildPetTooltip("mouseover", storageKey)
		end
	  end
	end
	if (dataPrefix == "PT" or dataPrefix == "PTR") and UnitExists("target") and not UnitIsPlayer("target") then
	  if TurtleRPPetCache and TurtleRPPetCache[storageKey] then
		TurtleRP.buildPetTargetFrame(TurtleRPPetCache[storageKey])
	  end
	end
  if (dataPrefix == "PT" or dataPrefix == "PTR") and TurtleRP.IsOwnedPetUnit and TurtleRP.IsOwnedPetUnit("target") then
    if TurtleRPPetCache and TurtleRPPetCache[storageKey] then
      TurtleRP.buildPetTargetFrame(TurtleRPPetCache[storageKey])
    end
  end
  if (dataPrefix == "PD" or dataPrefix == "PDR") and TurtleRP.showDescription and TurtleRP.showDescription == storageKey and TurtleRPPetCache and TurtleRPPetCache[storageKey] then
    TurtleRP.currentlyViewedPetUID = nil
    TurtleRP.previewCharacterInfo = TurtleRPPetCache[storageKey]
    TurtleRP.previewSource = "pet_admin"
    TurtleRP.OpenProfilePreview("description")
    TurtleRP.buildPetDescription(nil)
    TurtleRP_Target:Hide()
    TurtleRP.showDescription = nil
  end
  if storageKey == TurtleRP.currentlyViewedPlayer and TurtleRP_CharacterDetails:IsVisible() then
    if TurtleRP.currentProfileTab == "general" and (dataPrefix == "M" or dataPrefix == "MR" or dataPrefix == "T" or dataPrefix == "TR") then
      TurtleRP.buildGeneral(storageKey)
    end
    if TurtleRP.currentProfileTab == "description" and (dataPrefix == "D" or dataPrefix == "DR") then
      TurtleRP.buildDescription(storageKey)
    end
    if TurtleRP.currentProfileTab == "notes" and (dataPrefix == "M" or dataPrefix == "MR") then
      TurtleRP.SetNameAndIcon(storageKey)
    end
  end
  if storageKey == TurtleRP.showDescription and (dataPrefix == "D" or dataPrefix == "DR") then
    TurtleRP.OpenProfile("description")
    TurtleRP.buildDescription(storageKey)
    TurtleRP_Target:Hide()
    TurtleRP.showDescription = nil
  end
end

function TurtleRP.splitByChunk(text, chunkSize)
    local splitLength = 200
    local sz = math.ceil(strlen(text) / splitLength)
    local loopNumber = 0
    local chunksToReturn = {}
    while loopNumber < sz do
      local startAt = (loopNumber * splitLength)
      chunksToReturn[loopNumber + 1] = strsub(text, startAt, startAt + splitLength - 1)
      loopNumber = loopNumber + 1
    end
    return chunksToReturn
end

-- Have to keep stupid 1.1.0 code because I made a boo boo
-- //bratmage / i have no idea what this 1.1.0 note means but im keeping it forever
-- //bratmage 2.0 / hahaha oops i changed it
local function TurtleRP_UpdateOwnDirectoryEntry(zoneName, zoneX, zoneY)
  local playerName = UnitName("player")
  local charData
  if not playerName or playerName == "" then
    return
  end
  if TurtleRPCharacters[playerName] == nil then
    TurtleRPCharacters[playerName] = {}
  end
  charData = TurtleRPCharacters[playerName]
  TurtleRPQueryablePlayers[playerName] = time()
  charData["zone"] = zoneName or ""
  charData["version"] = TurtleRP.currentVersion or "unknown"
  charData["currently_ic"] = TurtleRPCharacterInfo["currently_ic"] or "1"
  charData["protocol_version"] = "4"
  charData["faction"] = TurtleRPCharacterInfo["faction"] or TurtleRP.getFactionDefault()
  charData["full_name"] = TurtleRPCharacterInfo["full_name"] or playerName or ""
  charData["class_color"] = TurtleRPCharacterInfo["class_color"] or ""
  charData["outdated_version"] = "0"
  if TurtleRPSettings["share_location"] == "1" then
    if zoneX == 0 and zoneY == 0 then
      if zoneName == "Ironforge" or zoneName == "Stormwind City" or zoneName == "Darnassus" or zoneName == "Orgrimmar" or zoneName == "Thunder Bluff" or zoneName == "Undercity" or zoneName == "Alah'thalas" then
        charData["zoneX"] = "0.5"
        charData["zoneY"] = "0.5"
      else
        charData["zoneX"] = "false"
        charData["zoneY"] = "false"
      end
    else
      charData["zoneX"] = tostring(math.floor(zoneX * 10000) / 10000)
      charData["zoneY"] = tostring(math.floor(zoneY * 10000) / 10000)
    end
  else
    charData["zoneX"] = "false"
    charData["zoneY"] = "false"
  end
  TurtleRP.RefreshDirectoryIfVisible()
  if WorldMapFrame and WorldMapFrame:IsVisible() then
    TurtleRP.show_player_locations()
  end
end

function TurtleRP.pingWithLocationAndVersion(message)
  local oldContinent, oldZone = GetCurrentMapContinent(), GetCurrentMapZone()
  SetMapToCurrentZone()
  local zoneX, zoneY = GetPlayerMapPosition("player")
  local zoneName = GetRealZoneText()
  local icStatus = TurtleRPCharacterInfo["currently_ic"] or "1"
  local addonVersion = TurtleRP.currentVersion or "unknown"
  local protocolVersion = "4"
  local faction = TurtleRPCharacterInfo["faction"] or TurtleRP.getFactionDefault()
  local fullName = TurtleRPCharacterInfo["full_name"] or UnitName("player") or ""
  local classColor = TurtleRPCharacterInfo["class_color"] or ""

  if oldContinent and oldContinent > 0 then
    SetMapZoom(oldContinent, oldZone or 0)
  end

  message = message .. zoneName
  local shouldShareLocation = TurtleRPSettings["share_location"] == "1"

  if shouldShareLocation then
    if (zoneX == 0 and zoneY == 0) then
      if zoneName == "Ironforge" or zoneName == "Stormwind City" or zoneName == "Darnassus" or zoneName == "Orgrimmar" or zoneName == "Thunder Bluff" or zoneName == "Undercity" or zoneName == "Alah'thalas" then
        message = message .. "~0.5~0.5~" .. addonVersion .. "~" .. icStatus .. "~" .. protocolVersion .. "~" .. faction .. "~" .. fullName .. "~" .. classColor
      else
        message = message .. "~false~false~" .. addonVersion .. "~" .. icStatus .. "~" .. protocolVersion .. "~" .. faction .. "~" .. fullName .. "~" .. classColor
      end
    else
      message = message .. "~" .. math.floor(zoneX * 10000) / 10000 .. "~" .. math.floor(zoneY * 10000) / 10000 .. "~" .. addonVersion .. "~" .. icStatus .. "~" .. protocolVersion .. "~" .. faction .. "~" .. fullName .. "~" .. classColor
    end
  else
    message = message .. "~false~false~" .. addonVersion .. "~" .. icStatus .. "~" .. protocolVersion .. "~" .. faction .. "~" .. fullName .. "~" .. classColor
  end
  TurtleRP_UpdateOwnDirectoryEntry(zoneName, zoneX, zoneY)
  TurtleRP.ttrpChatSend(message)
end

local strGsub = string.gsub

function TurtleRP.DrunkEncode(text)
    text = strGsub(text, "s", "°")
    text = strGsub(text, "S", "§")
    return text
end

local DrunkSuffix = string.gsub(SLURRED_SPEECH, "%%s(.+)", "%1$"); -- remove "%s" from the localized " ...hic!" text
function TurtleRP.DrunkDecode(text)
	text = strGsub(text, "°", "s")
	text = strGsub(text, "§", "S")
	text = strGsub(text, DrunkSuffix, "") -- likely only needed if decoding an entire message
	return text
end
	--11 second delay on refreshing the directory.
function TurtleRP.RefreshDirectoryIfVisible()
    if not (TurtleRP_DirectoryFrame and TurtleRP_DirectoryFrame:IsVisible()) then
        return
    end
    local now = GetTime()
    if not TurtleRP.lastDirectoryRefreshTime then
        TurtleRP.lastDirectoryRefreshTime = 0
    end
    if now - TurtleRP.lastDirectoryRefreshTime < 11 then
        return
    end
    TurtleRP.lastDirectoryRefreshTime = now
    TurtleRP.updateDirectorySearch()
    TurtleRP.Directory_ScrollBar_Update()
end

function TurtleRP.QueueDirectorySearchRequest(playerName)
    if not playerName or playerName == "" then
        return
    end
    if playerName == UnitName("player") then
        return
    end
    if TurtleRPCharacters[playerName] ~= nil then
        return
    end
    if rpRequestLookup[playerName] then
        return
    end
    rpRequestLookup[playerName] = true
    table.insert(rpRequestQueue, playerName)
end
function TurtleRP.ttrpChatSend(message)
  ChatThrottleLib:SendChatMessage("NORMAL", TurtleRP.channelName, TurtleRP.DrunkEncode(message), "CHANNEL", nil, GetChannelName(TurtleRP.channelName))
end
