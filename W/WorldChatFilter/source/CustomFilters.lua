-- WorldChatFilter v1.1: personal World-only player and text filters.
-- Vanilla 1.12 / Lua 5.0: no modern chat-event filters or UTF-8 libraries.
local WCF = WorldChatFilter
local popupID = "WCF_WORLD_BLOCK"
local popupMenus = {"FRIEND"} -- chat player links open FriendsDropDown in Vanilla 1.12

local function lowerKey(value)
  return string.lower(WCF.Trim(value or ""))
end

function WCF.InitializeCustomFilters()
  if not WCF.db then return end
  local db = WCF.db
  if type(db.blockedPlayers) ~= "table" then db.blockedPlayers = {} end
  if type(db.blockedPhrases) ~= "table" then db.blockedPhrases = {} end
  -- This category is ON by default but has no entries on a clean install.
  if type(db.customEnabled) ~= "boolean" then db.customEnabled = true end
  -- Old or corrupted SavedVariables must not break chat filtering.
  local i = table.getn(db.blockedPlayers)
  while i >= 1 do
    if type(db.blockedPlayers[i]) ~= "string" or db.blockedPlayers[i] == "" then
      table.remove(db.blockedPlayers, i)
    end
    i = i - 1
  end
  i = table.getn(db.blockedPhrases)
  while i >= 1 do
    local entry = db.blockedPhrases[i]
    if type(entry) ~= "table" or type(entry.text) ~= "string" or entry.text == "" then
      table.remove(db.blockedPhrases, i)
    else
      entry.wholeWord = entry.wholeWord == true
    end
    i = i - 1
  end
end

local function refresh()
  if WCF.InvalidateMessageCache then WCF.InvalidateMessageCache() end
  if WCF.RefreshCustomFiltersUI then WCF.RefreshCustomFiltersUI() end
  if WCF.RefreshUI then WCF.RefreshUI() end
end

local function validPlayer(name)
  if type(name) ~= "string" then return nil end
  name = WCF.Trim(name)
  if name == "" or string.len(name) > 64 or string.find(name, "[%s%c%[%]|:]") then
    return nil
  end
  return name
end

function WCF.IsBlockedPlayer(name)
  if not WCF.db then WCF.Initialize() end
  if type(name) ~= "string" then return false end
  local wanted = lowerKey(name)
  local i
  for i = 1, table.getn(WCF.db.blockedPlayers) do
    if lowerKey(WCF.db.blockedPlayers[i]) == wanted then return true end
  end
  return false
end

function WCF.AddBlockedPlayer(name)
  if not WCF.db then WCF.Initialize() end
  name = validPlayer(name)
  if not name then return false, "Enter a valid player name (no spaces)." end
  if type(UnitName) == "function" then
    local selfName = UnitName("player")
    if selfName and lowerKey(name) == lowerKey(selfName) then
      return false, "You cannot block yourself."
    end
  end
  if WCF.IsBlockedPlayer(name) then return false, "Player is already blocked." end
  table.insert(WCF.db.blockedPlayers, name)
  refresh()
  return true, name
end

function WCF.RemoveBlockedPlayer(name)
  if not WCF.db then WCF.Initialize() end
  if type(name) ~= "string" then return false end
  local wanted, i = lowerKey(name), 1
  while i <= table.getn(WCF.db.blockedPlayers) do
    if lowerKey(WCF.db.blockedPlayers[i]) == wanted then
      table.remove(WCF.db.blockedPlayers, i)
      refresh()
      return true
    end
    i = i + 1
  end
  return false
end

function WCF.AddBlockedPhrase(phrase, wholeWord)
  if not WCF.db then WCF.Initialize() end
  if type(phrase) ~= "string" then return false, "Enter a word or phrase." end
  phrase = WCF.Trim(phrase)
  if phrase == "" or string.len(phrase) > 120 or string.find(phrase, "[%c]") then
    return false, "Enter a word/phrase up to 120 characters."
  end
  local key = lowerKey(phrase)
  local i
  for i = 1, table.getn(WCF.db.blockedPhrases) do
    if lowerKey(WCF.db.blockedPhrases[i].text) == key then
      return false, "Phrase already exists. Remove it first to change its mode."
    end
  end
  table.insert(WCF.db.blockedPhrases, {text=phrase,wholeWord=wholeWord == true})
  refresh()
  return true, phrase
end

function WCF.RemoveBlockedPhrase(phrase)
  if not WCF.db then WCF.Initialize() end
  if type(phrase) ~= "string" then return false end
  local key, i = lowerKey(phrase), 1
  while i <= table.getn(WCF.db.blockedPhrases) do
    if lowerKey(WCF.db.blockedPhrases[i].text) == key then
      table.remove(WCF.db.blockedPhrases, i)
      refresh()
      return true
    end
    i = i + 1
  end
  return false
end

-- WoW item links include visible [item names]. Match visible message text,
-- not hidden hyperlink IDs, color codes, or Lua pattern syntax.
local function visibleText(message)
  message = string.gsub(message, "|c%x%x%x%x%x%x%x%x", "")
  message = string.gsub(message, "|r", "")
  message = string.gsub(message, "|H[^|]*|h", "")
  message = string.gsub(message, "|h", "")
  return string.lower(message)
end

local function isAsciiWord(ch)
  return ch ~= "" and string.find(ch, "[%w_]") ~= nil
end

local function hasPhrase(text, entry)
  local needle = lowerKey(entry.text)
  if needle == "" then return false end
  local start = 1
  while true do
    local first, last = string.find(text, needle, start, true)
    if not first then return false end
    if not entry.wholeWord then return true end
    local before = first > 1 and string.sub(text, first - 1, first - 1) or ""
    local after = string.sub(text, last + 1, last + 1)
    -- Whole word means neither adjacent byte is a word char. This is
    -- ASCII-word detection; non-ASCII case folding requires an external lib.
    if not isAsciiWord(before) and not isAsciiWord(after) then return true end
    start = last + 1
  end
end

-- Called only after the existing master enabled + exact /World checks.
function WCF.MatchCustomFilter(message, author)
  if not WCF.db or not WCF.db.customEnabled then return nil end
  if WCF.IsBlockedPlayer(author) then return "Custom", "blocked player: " .. author end
  if type(message) ~= "string" then return nil end
  local display = visibleText(message)
  local i
  for i = 1, table.getn(WCF.db.blockedPhrases) do
    local entry = WCF.db.blockedPhrases[i]
    if hasPhrase(display, entry) then return "Custom", "blocked phrase: " .. entry.text end
  end
  return nil
end

-- Compatible with the *real* 1.12 ItemRef.lua: a right click on a player
-- hyperlink invokes FriendsFrame_ShowDropdown => UnitPopupMenus["FRIEND"].
-- We append one unique menu ID rather than replacing Blizzard menu tables.
function WCF.InstallCustomPlayerPopup()
  if type(UnitPopupMenus) ~= "table" or type(UnitPopupButtons) ~= "table" or
     type(UnitPopup_ShowMenu) ~= "function" or type(UnitPopup_OnClick) ~= "function" then
    return false
  end
  if not UnitPopupButtons[popupID] then
    UnitPopupButtons[popupID] = {text="Block from World Chat", dist=0}
  end
  local _, menuName
  for _, menuName in ipairs(popupMenus) do
    local items = UnitPopupMenus[menuName]
    if type(items) == "table" then
      local found, i = false, nil
      for i = 1, table.getn(items) do
        if items[i] == popupID then found = true end
      end
      if not found then
        local pos = table.getn(items) + 1
        if items[pos-1] == "CANCEL" then pos = pos-1 end
        table.insert(items, pos, popupID)
      end
    end
  end
  if UnitPopup_ShowMenu ~= WCF.customPopupShowHook then
    local priorShow = UnitPopup_ShowMenu
    WCF.customPopupShowHook = function(dropdown, which, unit, name, userData)
      if which == "FRIEND" then
        local target = name
        if not target and unit and type(UnitName) == "function" then
          target = UnitName(unit)
        end
        UnitPopupButtons[popupID].text = (target and WCF.IsBlockedPlayer(target)) and
            "Unblock from World Chat" or "Block from World Chat"
      end
      return priorShow(dropdown, which, unit, name, userData)
    end
    UnitPopup_ShowMenu = WCF.customPopupShowHook
  end
  if UnitPopup_OnClick ~= WCF.customPopupClickHook then
    local priorClick = UnitPopup_OnClick
    WCF.customPopupClickHook = function()
      if this and this.value == popupID then
        local drop = UIDROPDOWNMENU_INIT_MENU and getglobal(UIDROPDOWNMENU_INIT_MENU)
        local target = drop and drop.name
        if target and target ~= "" then
          if WCF.IsBlockedPlayer(target) then
            WCF.RemoveBlockedPlayer(target)
            WCF.Print("Unblocked " .. target .. " from World Chat.")
          else
            local ok, reason = WCF.AddBlockedPlayer(target)
            if ok then WCF.Print("Blocked " .. target .. " from World Chat.")
            else WCF.Print(reason) end
          end
        end
        if type(CloseDropDownMenus) == "function" then CloseDropDownMenus() end
        return
      end
      return priorClick()
    end
    UnitPopup_OnClick = WCF.customPopupClickHook
  end
  return true
end
