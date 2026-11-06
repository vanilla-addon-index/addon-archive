-- Vanilla chat has no ChatFrame_AddMessageEventFilter; wrap ChatFrame_OnEvent.
-- Never modify or suppress any channel other than the exact /World channel.
local WCF = WorldChatFilter
local activity = {}       -- Recent messages per author, pruned after 30 seconds.
local lastActivitySweep = -30
local cacheKey, cacheAt, cacheHide = nil, -100, false

-- Settings may change while a chat frame redraws the same message.
function WCF.InvalidateMessageCache()
  cacheKey, cacheAt, cacheHide = nil, -100, false
end

-- Ad recognition is implemented by Classifier.lua, separate from chat hooking.
-- All detections are weighted by context and pass through an intent gate.

local function stripMarkup(message)
  local text = message or ""
  text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
  text = string.gsub(text, "|r", "")
  text = string.gsub(text, "|H[^|]*|h", "")
  text = string.gsub(text, "|h", "")
  return text
end

local function repeatBody(message)
  -- Preserve non-English chat; %w on old Lua is predominantly ASCII.
  local body = string.lower(stripMarkup(message))
  body = string.gsub(body, "[%c%p]+", " ")
  body = string.gsub(body, "%s+", " ")
  body = WCF.Trim(body)
  return body
end

local function checkRepeat(message, author, now)
  if not WCF.db.filterRepeats then return false end
  local body = repeatBody(message)
  if string.len(body) < 14 then return false end
  -- Previously activity grew forever as new authors appeared. Sweep inactive
  -- authors periodically; never prune an author still inside the 30s window.
  if now < lastActivitySweep or now - lastActivitySweep >= 30 then
    local name, record
    for name, record in pairs(activity) do
      if now < record.lastSeen or now - record.lastSeen > 30 then
        activity[name] = nil
      end
    end
    lastActivitySweep = now
  end
  local key = string.lower(author)
  local record = activity[key]
  if not record then
    record = {lastSeen = now, items = {}}
    activity[key] = record
  end
  record.lastSeen = now
  local items = record.items
  local i = 1
  local matching = nil
  -- Keep a bounded rolling window so alternating copy/paste spam is caught.
  while i <= table.getn(items) do
    local entry = items[i]
    if now < entry.time or now - entry.time > 30 then
      table.remove(items, i)
    else
      if entry.body == body then matching = entry end
      i = i + 1
    end
  end
  if matching then
    matching.count = matching.count + 1
    matching.time = now
    return matching.count >= 2
  end
  table.insert(items, {body = body, time = now, count = 1})
  if table.getn(items) > 8 then table.remove(items, 1) end
  return false
end

function WCF.ShouldHideChannelMessage(message, author, baseName, decoratedName, zoneChannelID)
  if not WCF.db or not WCF.db.enabled then return false end
  if not WCF.IsWorldChannel(baseName, decoratedName, zoneChannelID) then return false end
  if type(message) ~= "string" or type(author) ~= "string" or author == "" then return false end

  -- Never hide the user's own World messages.
  if type(UnitName) == "function" then
    local me = UnitName("player")
    if me and string.lower(me) == string.lower(author) then return false end
  end

  local now = 0
  if type(GetTime) == "function" then now = GetTime() end
  local signature = author .. "\001" .. message .. "\001world"
  -- ChatFrame_OnEvent may be invoked once for EACH visible chat window.
  if signature == cacheKey and now >= cacheAt and now - cacheAt < 0.15 then
    return cacheHide
  end

  local hide = false
  local category, score, why, blocked
  local customCategory, customWhy
  if WCF.MatchCustomFilter then
    customCategory, customWhy = WCF.MatchCustomFilter(message, author)
  end
  if customCategory then
    category, score, why, blocked = customCategory, 0, customWhy, true
  else
    category, score, why, blocked = WCF.ClassifyMessage(message)
  end
  if blocked then
    hide = true
    if WCF.db.debug then
      WCF.Print("Blocked " .. tostring(category) .. " (" .. tostring(score) .. "): " .. tostring(why))
    end
  elseif checkRepeat(message, author, now) then
    hide = true
    if WCF.db.debug then WCF.Print("Blocked repeated message from " .. author) end
  end
  cacheKey, cacheAt, cacheHide = signature, now, hide
  if hide then
    if WCF.RecordHiddenMessage then
      WCF.RecordHiddenMessage(blocked and category or "Repeats")
    else
      WCF.sessionHidden = WCF.sessionHidden + 1
    end
    if WCF.RefreshUI then WCF.RefreshUI() end
  end
  return hide
end

function WCF.InstallChatHook()
  if type(ChatFrame_OnEvent) ~= "function" then return end
  if WCF.chatHook and ChatFrame_OnEvent == WCF.chatHook then return end
  local previous = ChatFrame_OnEvent
  local hook
  hook = function(evt)
    if evt == "CHAT_MSG_CHANNEL" then
      -- Optional non-content diagnostics to verify the client's event layout.
      if WCF.channelDebug then
        local base = tostring(arg9)
        local numbered = tostring(arg4)
        local zoneID = tostring(arg7)
        local label = base .. " / " .. numbered .. " / " .. zoneID
        WCF.channelDebugSeen = WCF.channelDebugSeen or {}
        WCF.channelDebugCount = WCF.channelDebugCount or 0
        if not WCF.channelDebugSeen[label] and WCF.channelDebugCount < 12 then
          WCF.channelDebugSeen[label] = true
          WCF.channelDebugCount = WCF.channelDebugCount + 1
          WCF.Print("Channel metadata: base=" .. base .. ", numbered=" .. numbered ..
            ", zoneID=" .. zoneID .. ", isWorld=" ..
            (WCF.IsWorldChannel(arg9, arg4, arg7) and "yes" or "no"))
        end
      end
      -- Color only the verified /World slot, before Blizzard draws the message.
      -- A non-World event in an old slot must immediately restore its color.
      if WCF.ColorOnChannelEvent then WCF.ColorOnChannelEvent(arg9, arg4, arg7, arg8) end
      if WCF.ShouldHideChannelMessage(arg1, arg2, arg9, arg4, arg7) then
        return
      end
    end
    return previous(evt)
  end
  WCF.chatHook = hook
  ChatFrame_OnEvent = hook
end

WCF.InstallChatHook()
