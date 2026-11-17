-- Starting a guide (picked on the settings window's Guides page, Settings.lua) and moving on to the next one when a guide is finished. The guide window itself is GuideWindow.lua.

local ER = pfQuest_xpGuide
local GOLD, GREY, WHITE, END = ER.GOLD, ER.GREY, ER.WHITE, ER.END
local GREEN = ER.GREEN


local function Say(msg)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99xpGuide:|r " .. msg) end
end

local function Plain(text)
  text = string.gsub(text or "", "|c%x%x%x%x%x%x%x%x", "")
  return (string.gsub(text, "|r", ""))
end

-- How tall a text is at this width, measured by the game (never guessed from letter counts). Leaves the font string
-- at that width and height with the text in it. The minimum height is only a floor for the result; if the game gives
-- no height, each line counts as the font size plus a small gap.
function ER.FitHeight(fs, text, width, minHeight)
  local least = minHeight or 14
  fs:SetWidth(width)
  fs:SetHeight(0)   -- 0 = size to the text
  fs:SetText(text or "")
  local h = fs:GetHeight()
  if not h or h < 1 then
    -- The client gave no height: work it out from the width of the text on one line.
    fs:SetWidth(0)
    local full = fs:GetStringWidth() or 0
    fs:SetWidth(width)
    local lines = math.ceil(full / (width * 0.9))   -- the 0.9 leaves room for words that do not fill a row
    if lines < 1 then lines = 1 end
    local _, size = fs:GetFont()
    if type(size) ~= "number" or size < 1 then size = 12 end
    h = lines * (size + 2)
  end
  if h < least then h = least end
  fs:SetHeight(h)
  return h
end

-- One line that fits the width: when it is too wide, whole words come off the end and "..." goes on. With an ending ("tail"), the
-- ending always stays whole and follows the "..."; only the text before it is cut, word by word and last letter by letter.
function ER.FitLine(fs, text, width, tail)
  tail = tail or ""
  fs:SetWidth(0)   -- 0 = size to the text, so the width read next is the whole text on one line
  fs:SetText((text or "") .. tail)
  local full = fs:GetStringWidth() or 0
  if full <= width then
    fs:SetWidth(width)
    return
  end
  local words = {}
  for w in string.gfind(text or "", "[^ ]+") do table.insert(words, w) end
  while table.getn(words) > 1 do
    table.remove(words)
    fs:SetText(table.concat(words, " ") .. "..." .. tail)
    if (fs:GetStringWidth() or 0) <= width then break end
  end
  if table.getn(words) == 1 then
    local word = words[1]
    fs:SetText(word .. "..." .. tail)
    while tail ~= "" and string.len(word) > 1 and (fs:GetStringWidth() or 0) > width do
      word = string.sub(word, 1, string.len(word) - 1)
      fs:SetText(word .. "..." .. tail)
    end
  end
  fs:SetWidth(width)
end

------------------------------------------------------------------------------------------------------
-- The step box
------------------------------------------------------------------------------------------------------

-- The lines of one step: { text, done, kind, step }.
-- The guide that comes after the one running. For the casual route, a player who is past the next zone (above its top level) gets the first
-- zone after it that is not passed over; the second value lists the zones passed over (nil when none).
local function NextToStart()
  local nxt = ER.Steps.NextGuide()
  if nxt and ER.RouteSkipPast then return ER.RouteSkipPast(nxt) end
  return nxt, nil
end
ER.NextToStart = NextToStart

------------------------------------------------------------------------------------------------------
-- Group names
------------------------------------------------------------------------------------------------------

-- The fast routes' groups ("Alliance 1-20") are shown as "Fast route 1-20"; every other name stays as it is. Display only:
-- the group of a guide, and so its saved key, keeps its name.
function ER.GroupLabel(name)
  if type(name) ~= "string" then return name end
  local _, _, side, levels = string.find(name, "^(%a+) (%d+%-%d+)$")
  if levels and (side == "Alliance" or side == "Horde") then return "Fast route " .. levels end
  -- xpGuide's own Fast groups carry the faction in their name (their saved key); the heading needs the room for the rate
  local _, _, fl = string.find(name, "^xpGuide Fast %a+ (%d+%-%d+)$")
  if fl then return "xpGuide Fast " .. fl end
  return name
end

-- The guide menu itself is the Guides page of the settings window (Settings.lua: ER.ShowGuideMenu, ER.GuideMenuRefresh).

------------------------------------------------------------------------------------------------------
-- Building the window
------------------------------------------------------------------------------------------------------

-- Starts a guide and shows the guide window and the arrow. quiet: the caller prints its own line. byHand: picked from the guide list
-- (the check-in then waits a while before it asks about moving on, Adapt.lua).
function ER.StartGuide(key, fresh, quiet, byHand)
  -- A zone that is started again is not "ahead of the plan" because of the last time (ER.RouteNextLine reads that mark).
  local again = ER.Steps.Find(key)
  if again then again.ahead = nil end
  if not ER.Steps.Load(key, fresh) then
    Say("that guide could not be loaded.")
    return false
  end
  local info = ER.Steps.Info()
  if ER.GuideStarted then ER.GuideStarted(ER.Steps.Key(info), byHand) end
  if not quiet then
    Say("following " .. GOLD .. (info.title or info.name) .. END .. ". The arrow points the way; " .. GOLD .. "/xpg" .. END ..
      " shows or hides the steps.")
  end
  if ER.db then ER.db.arrowOff = nil end   -- a new guide always starts with the arrow on
  ER.ShowTracker()
  if ER.ArrowUpdate then ER.ArrowUpdate() end
  return true
end

-- When a guide is finished the next one starts by itself, no click needed. true when one was started.
function ER.AutoNextGuide()
  if ER.db and ER.db.autoNextOff then return false end
  local prev = ER.Steps.Info()
  local nxt, skipped = NextToStart()
  if not nxt then return false end
  -- A casual-route zone that follows its own zone starts at the top: the part-way scan would drop its travel steps and could take a quest
  -- of the same name from the zone before for progress. Advance ticks off whatever is already done.
  if not ER.StartGuide(ER.Steps.Key(nxt), nxt.route and true or nil, true) then return false end
  -- The casual route has its own single line; every other guide keeps the old one.
  local line = ER.RouteNextLine and ER.RouteNextLine(prev, nxt, skipped)
  if line then
    Say(line)
  else
    Say(GOLD .. "guide finished." .. END .. " Now following " .. GOLD .. (nxt.title or nxt.name) .. END .. ".")
  end
  return true
end

-- Picks the step window back up after a login when a guide was running.
local starter = CreateFrame("Frame", "pfQuest_xpGuideTrackerStarter")
starter:RegisterEvent("PLAYER_ENTERING_WORLD")
starter:SetScript("OnEvent", function()
  this:UnregisterEvent("PLAYER_ENTERING_WORLD")
  this.wait = 0
  this:SetScript("OnUpdate", function()
    this.wait = this.wait + arg1
    if this.wait < 2 then return end
    this:SetScript("OnUpdate", nil)
    if ER.Steps.Running() or ER.Steps.Resume() then ER.ShowTracker() end
  end)
end)

ER.Loaded("Tracker.lua")
