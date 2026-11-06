local A = OctoQuestRewards
local G = getfenv(0)
A.predictions = {}
A.frame = CreateFrame("Frame", "OctoQuestRewardsEvents")

function A.Print(text)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff88ccffOQR:|r " .. text) end
end

function A.DebugRecord(r, force)
  local text = "ID=" .. tostring(r.id or "?") .. " title=" .. r.title
    .. " questLevel=" .. tostring(r.level or "?") .. " playerLevel=" .. r.playerLevel
    .. " IDsource=" .. r.idSource .. " XPsource=" .. r.xpSource
    .. " predictedXP=" .. tostring(r.xp or "unknown")
    .. " predictedMoney=" .. tostring(r.money or "unknown") .. "c"
    .. " moneySource=" .. tostring(r.moneySource or "unavailable")
  if force or text ~= A.lastDebug then A.Print(text); A.lastDebug = text end
end

-- One deferred update per event burst, removed immediately. No idle polling.
function A.Schedule()
  A.frame:SetScript("OnUpdate", function()
    A.frame:SetScript("OnUpdate", nil)
    A.RenderAll()
  end)
end

local function Difference(actual, predicted)
  if actual == nil or predicted == nil then return "unknown" end
  return tostring(actual - predicted)
end

function A.Report(r, xp, money, source)
  if not A.db.debug then return end
  if r then A.DebugRecord(r, true) end
  A.Print("actualXP=" .. tostring(xp or "unknown") .. " actualMoney=" .. tostring(money or "unknown")
    .. "c differenceXP(actual-predicted)=" .. Difference(xp, r and r.xp)
    .. " differenceMoney=" .. Difference(money, r and r.money) .. "c source=" .. source)
  A.db.lastTurnIn = { id = r and r.id, title = r and r.title,
    playerLevel = r and r.playerLevel, predictedXP = r and r.xp,
    predictedMoney = r and r.money, xp = xp, money = money, source = source }
end

function A.BeginTurnIn()
  if not A.db.debug then return end
  local r = A.GetRecord("reward")
  if r then
    A.pending = { record = r, expires = GetTime() + 8 }
    A.DebugRecord(r, true)
  end
end

local function EscapePattern(text)
  return (string.gsub(text, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

local function CaptureFormat(message, template, marker, capture)
  if not template then return nil end
  local pattern = EscapePattern(template)
  pattern = string.gsub(pattern, EscapePattern(EscapePattern(marker)), function() return capture end)
  local _, _, value = string.find(message, "^" .. pattern .. "$")
  return value
end

local function ReadChatMoney(text)
  local value, found = 0, false
  for _, unit in ipairs({{G.GOLD, 10000}, {G.SILVER, 100}, {G.COPPER, 1}}) do
    if type(unit[1]) == "string" then
      local _, _, amount = string.find(string.lower(text), "(%d+)%s*" .. EscapePattern(string.lower(unit[1])))
      if amount then value, found = value + tonumber(amount) * unit[2], true end
    end
  end
  if found then return value end
end

function A.SystemMessage(message)
  local p = A.pending
  if not A.db.debug or not p or type(message) ~= "string" then return end
  if GetTime() > p.expires then A.pending = nil; return end
  local title = CaptureFormat(message, G.ERR_QUEST_COMPLETE_S, "%s", "(.-)")
  if title then
    if title ~= p.record.title then A.pending = nil; return end
    p.confirmed = true
  end
  local xp = CaptureFormat(message, G.ERR_QUEST_REWARD_EXP_I, "%d", "(%d+)")
  if xp then p.xp = tonumber(xp) end
  local moneyText = CaptureFormat(message, G.ERR_QUEST_REWARD_MONEY_S, "%s", "(.-)")
  if moneyText then p.money = ReadChatMoney(moneyText) end
  if p.confirmed and (title or xp or moneyText) then
    A.Report(p.record, p.xp, p.money, "server quest system messages; missing values remain unknown")
  end
end

-- This Vanilla function has one argument and no return payload to preserve.
-- Wrapping is necessary for correlating server chat with an actual submission.
local function SetupHooks()
  if type(G.GetQuestReward) == "function" then
    local old = G.GetQuestReward
    G.GetQuestReward = function(choice)
      A.BeginTurnIn()
      return old(choice)
    end
  end
  if type(G.QuestLog_UpdateQuestDetails) == "function" then
    if type(G.hooksecurefunc) == "function" then
      G.hooksecurefunc("QuestLog_UpdateQuestDetails", A.Schedule)
    else
      local old = G.QuestLog_UpdateQuestDetails
      -- Inspected Vanilla FrameXML: single doNotScroll argument, no returns.
      G.QuestLog_UpdateQuestDetails = function(doNotScroll)
        old(doNotScroll)
        A.Schedule()
      end
    end
  end
  A.SetupUI()
end

local function Has(fn) return type(fn) == "function" and "yes" or "no" end
function A.Status()
  local version, build = GetBuildInfo()
  A.Print("1.0.0 loaded; client=" .. tostring(version) .. " build=" .. tostring(build)
    .. " content=" .. tostring(G.TURTLE_WOW_VERSION or "unknown") .. "; debug=" .. tostring(A.db.debug)
    .. "; XP scaling=" .. A.db.scaling .. " (unverified server match, assumed 1x)")
  A.Print("NPC money API=" .. Has(G.GetRewardMoney) .. "; log money API=" .. Has(G.GetQuestLogRewardMoney)
    .. "; ClassicAPI quest cache=" .. Has(C_QuestLog and C_QuestLog.GetQuestDetails)
    .. "; pfQuest=" .. tostring(pfDB ~= nil) .. "; pfExtend XP=" .. tostring(PfExtend_QuestRewards ~= nil)
    .. "; QUEST_TURNED_IN=" .. (A.turnedInSeen and "observed" or "not observed")
    .. "; event registration=" .. tostring(A.turnInRegistered))
  if A.current then A.DebugRecord(A.current, true) end
  local last = A.db.lastTurnIn
  if last then
    A.Print("last receipt: ID=" .. tostring(last.id or "?") .. " title=" .. tostring(last.title or "?")
      .. " actualXP=" .. tostring(last.xp or "unknown") .. " actualMoney=" .. tostring(last.money or "unknown")
      .. "c source=" .. tostring(last.source))
  end
end

local function Command(message)
  local cmd = string.lower(message or "")
  if cmd == "debug" then
    A.db.debug = not A.db.debug
    A.pending, A.lastDebug = nil, nil
    A.Print("Debug " .. (A.db.debug and "enabled" or "disabled") .. ".")
    A.Schedule()
  elseif cmd == "status" then A.Status()
  elseif cmd == "scaling vanilla" or cmd == "scaling full25" then
    A.db.scaling = cmd == "scaling vanilla" and "vanilla" or "full25"
    A.Print("XP scaling assumption: " .. A.db.scaling .. "; estimates remain unverified.")
    A.Schedule()
  else
    A.Print("/oqr debug toggles turn-in comparisons; /oqr status shows sources and last receipt.")
    A.Print("Optional: /oqr scaling vanilla or /oqr scaling full25. Default: Vanilla scaling, 1x rate.")
  end
end

local initialized
A.frame:SetScript("OnEvent", function()
  if event == "PLAYER_LOGIN" then
    if initialized then return end
    initialized = true
    OctoQuestRewardsDB = OctoQuestRewardsDB or {}
    A.db = OctoQuestRewardsDB
    if A.db.scaling ~= "full25" then A.db.scaling = "vanilla" end
    SLASH_OCTOQUESTREWARDS1 = "/oqr"
    SlashCmdList.OCTOQUESTREWARDS = Command
    SetupHooks()
    A.turnInRegistered = pcall(A.frame.RegisterEvent, A.frame, "QUEST_TURNED_IN")
    if C_QuestLog then pcall(A.frame.RegisterEvent, A.frame, "QUEST_DATA_LOAD_RESULT") end
    A.Schedule()
  elseif not initialized then return
  elseif event == "QUEST_TURNED_IN" then
    A.turnedInSeen = true
    local id, xp, money = tonumber(arg1), tonumber(arg2), tonumber(arg3)
    local r = id and A.predictions[id]
    if A.pending and (not r or r.id == A.pending.record.id) then r = A.pending.record end
    if not r then
      r = { id = id, title = "unknown", playerLevel = UnitLevel("player"),
        idSource = "QUEST_TURNED_IN", xpSource = "unavailable" }
    end
    A.Report(r, xp, money, "QUEST_TURNED_IN server completion packet")
    A.pending = nil
  elseif event == "CHAT_MSG_SYSTEM" then A.SystemMessage(arg1)
  elseif event == "QUEST_FINISHED" or event == "QUEST_GREETING" then
    A.current = nil
    A.Schedule()
  else A.Schedule() end
end)

for _, name in ipairs({"PLAYER_LOGIN", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
  "QUEST_FINISHED", "QUEST_GREETING", "QUEST_ITEM_UPDATE", "QUEST_LOG_UPDATE", "PLAYER_LEVEL_UP",
  "CHAT_MSG_SYSTEM", "UI_SCALE_CHANGED"}) do
  pcall(A.frame.RegisterEvent, A.frame, name)
end
