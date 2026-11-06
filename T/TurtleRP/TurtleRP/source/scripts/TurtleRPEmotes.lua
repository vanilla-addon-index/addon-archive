--[[
  Created by Vee (http://victortemprano.com), Drixi in-game
  See Github repo at https://github.com/tempranova/turtlerp
]]

StaticPopupDialogs["CONFIRM_QUOTATION"] = {
  text = TEXT('You typed an emote with a unclosed quotation ("). This could result in the chat being formatted wrong.');
  button1 = TEXT("Send"),
  button2 = TEXT("Don't Send"),
  OnShow = function()
    TurtleRP.sendWithError = nil
  end,
  -- OnHide = function()
  -- end,
  OnAccept = function()
    TurtleRP.sendWithError = true
    TurtleRP.SendLongFormMessage("EMOTE", TurtleRP.errorMessage)
  end,
  timeout = 0,
  whileDead = 0,
  interruptCinematic = 1,
  notClosableByLogout = 0
};

function TurtleRP.escapeFocusFromChatbox()
  local existingWorldFrameFunctions = WorldFrame:GetScript("OnMouseDown")
  WorldFrame:SetScript("OnMouseDown", function()
    if TurtleRP.editingChatBox then
      TurtleRP_ChatBox_TextScrollBox_TextInput:ClearFocus()
      TurtleRP.editingChatBox = false
    end
    if existingWorldFrameFunctions then
      existingWorldFrameFunctions()
    end
  end)
end

-----
-- Handling custom emotes
-----
function TurtleRP.emote_events()
  if TurtleRP.currentEmoteFrameAdapter then
    local i, frame
    for i = 1, 7 do
      frame = getglobal("ChatFrame" .. i)
      if frame and frame:GetScript("OnEvent") == TurtleRP.currentEmoteFrameAdapter then
        return
      end
    end
  end
  local TurtleLastEmote = {}
  local TurtleEmoteCounter = 0
  local TurtleLastSender = {}
  local beginningQuoteFlag = {}
  local oldChatFrame_OnEvent = ChatFrame_OnEvent
  if oldChatFrame_OnEvent == TurtleRP.currentEmoteChatHook and TurtleRP.originalEmoteChatFrame_OnEvent then
    oldChatFrame_OnEvent = TurtleRP.originalEmoteChatFrame_OnEvent
  end
  TurtleRP.originalEmoteChatFrame_OnEvent = oldChatFrame_OnEvent

  local function TurtleRP_EmoteChatFrame_OnEvent(event)
    local savedEvent = event

    if ( strsub(event, 1, 8) == "CHAT_MSG" ) then
      local type = strsub(event, 10)
      if ( type == "SYSTEM") then
        if arg1 == "You are now AFK: Away from Keyboard" then
          TurtleRP.disableMessageSending = true
        end
        if arg1 == "You are no longer AFK." then
          TurtleRP.disableMessageSending = nil
        end
      end
      if ( type == "EMOTE" ) then
        if beginningQuoteFlag[this:GetID()] == nil then
          beginningQuoteFlag[this:GetID()] = 0
        end
        if TurtleRP.sendingLongForm ~= nil then
          if TurtleLastSender[this:GetID()] and TurtleLastSender[this:GetID()] == arg2 then
            if string.find(TurtleLastEmote[this:GetID()], '"') then
              local splitArrayQuotes = TurtleRP.splitString(TurtleLastEmote[this:GetID()], '"')
              local numberOfQuotes = getn(splitArrayQuotes) + 1
              if (numberOfQuotes - math.floor(numberOfQuotes/2)*2) ~= 0 then
                beginningQuoteFlag[this:GetID()] = 1 - beginningQuoteFlag[this:GetID()]
              end
            end
          end
          TurtleEmoteCounter = TurtleEmoteCounter + 1
          if TurtleRP.sendingLongForm == (TurtleEmoteCounter + 1) then
            TurtleRP.sendingLongForm = nil
          end
        end

        TurtleLastEmote[this:GetID()] = arg1
        TurtleLastSender[this:GetID()] = arg2
        savedEvent = "TURTLE_TAKEOVER"

        local nameString = arg2
        local splitArray = TurtleRP.splitString(arg1, '"')
        local firstChunk = splitArray[1]
        local firstFour = strsub(firstChunk, 1, 4)
        local firstThree = strsub(firstChunk, 1, 3)
        local firstOne = strsub(firstChunk, 1, 1)
        local hideNameCompletely = false

        if firstFour == "||| " then
          firstChunk = strsub(firstChunk, 5)
          hideNameCompletely = true
          nameString = ""
        elseif firstThree == "|| " then
          firstChunk = strsub(firstChunk, 4)
          hideNameCompletely = true
          nameString = ""
        elseif firstOne == "|" then
          firstChunk = strsub(firstChunk, 2)
          firstChunk = string.gsub(firstChunk, "^%s*", "")
          hideNameCompletely = true
          nameString = ""
        else
          nameString = TurtleRP.GetChatDisplayName(arg2, arg2, true)
        end

        local newString = beginningQuoteFlag[this:GetID()] == 1 and (" |cffFFFFFF" .. firstChunk) or firstChunk
        if getn(splitArray) > 1 then
          for i = 2, getn(splitArray) do
            if (i - math.floor(i/2)*2) == 0 then
              local colorChange = beginningQuoteFlag[this:GetID()] == 1 and "|cffFF7E40" or "|cffFFFFFF"
              local colorRevert = beginningQuoteFlag[this:GetID()] == 1 and "|cffFFFFFF" or "|cffFF7E40"
              local finalQuoteToAdd = splitArray[i + 1] and '"' or ''
              newString = newString .. colorChange .. '"' .. splitArray[i] .. finalQuoteToAdd .. colorRevert
            else
              newString = newString .. splitArray[i]
            end
          end
        end

        local body
        if hideNameCompletely then
          body = "|cffFF7E40" .. newString
        else
          local formattedName = nameString
          if formattedName == nil or formattedName == "" then
            formattedName = TurtleRP.GetChatDisplayName(arg2, arg2, true)
          end

          if not TurtleRPSettings or TurtleRPSettings["chat_colors"] ~= "1" then
            formattedName = string.gsub(formattedName, "|[cC][fF][fF]%x%x%x%x%x%x", "")
            formattedName = string.gsub(formattedName, "|[rR]", "")
            formattedName = "|cffFF7E40" .. formattedName .. "|r"
          end

          body = format(
            TEXT(getglobal("CHAT_"..type.."_GET")) .. "|cffFF7E40" .. TurtleRP.EscapePercentageCharacter(newString) .. "|r",
            formattedName
          )
        end
        this:AddMessage(body)
      end
    end

    oldChatFrame_OnEvent(savedEvent)
  end

  local function TurtleRP_ChatFrameEventAdapter()
    ChatFrame_OnEvent(event)
  end

  ChatFrame_OnEvent = TurtleRP_EmoteChatFrame_OnEvent
  TurtleRP.currentEmoteChatHook = TurtleRP_EmoteChatFrame_OnEvent
  TurtleRP.currentEmoteFrameAdapter = TurtleRP_ChatFrameEventAdapter

  local i, frame
  for i = 1, 7 do
    frame = getglobal("ChatFrame" .. i)
    if frame then
      frame:SetScript("OnEvent", TurtleRP_ChatFrameEventAdapter)
    end
  end
end

function TurtleRP.SendLongFormMessage(type, message)
  local finalType = string.upper(type or "")
  local currentCharCount = 0
  local currentMessageString = ""
  local emotePrefix = ""

  message = tostring(message or "")
  if message == "" then
    return
  end

 if finalType == "EMOTE" then
    local suppressEmoteName = false
    local showEmoteName = TurtleRPSettings and TurtleRPSettings["auto_emote_name"] == "1"

    if TurtleRP.sendWithError == nil then
      if string.find(message, '"') then
        local splitArrayQuotes = TurtleRP.splitString(message, '"')
        local numberOfQuotes = getn(splitArrayQuotes) + 1
        if (numberOfQuotes - math.floor(numberOfQuotes / 2) * 2) ~= 0 then
          TurtleRP.errorMessage = message
          StaticPopup_Show("CONFIRM_QUOTATION")
          return
        end
      end
    end

    if strsub(message, 1, 1) == "|" then
      suppressEmoteName = true
      message = string.gsub(message, "^|%s*", "", 1)
    end

    if suppressEmoteName then
      emotePrefix = "||| "
    elseif showEmoteName then
      emotePrefix = ""
    else
      emotePrefix = "|| "
    end
  end
  local splitMessage = TurtleRP.splitString(message, " ")
  TurtleRP.sendingLongForm = getn(splitMessage)
  for i, v in splitMessage do
    local stringLength = strlen(v)
    local sendMessage = false
    currentCharCount = currentCharCount + stringLength
    if splitMessage[i + 1] then
      if (strlen(splitMessage[i + 1]) + currentCharCount) > 200 then
        sendMessage = true
      end
    else
      sendMessage = true
    end
    local extraSpace = currentMessageString == "" and emotePrefix or " "
    currentMessageString = currentMessageString .. extraSpace .. v
    if sendMessage then
      ChatThrottleLib:SendChatMessage("NORMAL", "TTRP", currentMessageString, finalType)
      currentMessageString = ""
      currentCharCount = 0
    end
  end
  if TurtleRP_ChatBox_TextScrollBox_TextInput then
    TurtleRP_ChatBox_TextScrollBox_TextInput:SetText("")
  end
end
function TurtleRP.EscapePercentageCharacter(text)
	text = string.gsub(text, "%%", "%%%%");
	return text;
end
