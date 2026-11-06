-- Questie-Octo quest automation.
--
-- Design reference: Questie 6's event-driven auto accept/complete flow, adapted
-- for Octo/Turtle and ClassicAPI. This implementation deliberately uses
-- ClassicAPI quest-ID gossip selection when available and keeps several
-- stricter safety boundaries:
--   * one quest action at a time;
--   * completed turn-ins before new accepts;
--   * Shift disables automation for the current NPC conversation;
--   * multiple selectable rewards remain manual;
--   * money-cost turn-ins remain manual;
--   * QUEST_ACCEPT_CONFIRM remains manual;
--   * the same repeatable quest is processed at most once per NPC conversation.

QuestieOcto.QuestAutomation = QuestieOcto.QuestAutomation or {}
local A = QuestieOcto.QuestAutomation

A.pending=nil
A.conversationDisabled=false
A.conversationTarget=nil
A.processedRepeatables={}
A.closeGeneration=0

local function Settings()
  return QuestieOcto.MinimapSettings
end

local function IsShiftDown()
  if type(IsShiftKeyDown)~="function" then return false end
  local ok,value=pcall(IsShiftKeyDown)
  return ok and value and true or false
end

local function TargetKey()
  if type(UnitGUID)=="function" then
    local ok,guid=pcall(UnitGUID,"target")
    if ok and guid then return tostring(guid) end
  end
  if type(UnitName)=="function" then
    local ok,name=pcall(UnitName,"target")
    if ok and name then return tostring(name) end
  end
  return nil
end

local function FrameShown(frame)
  return frame and frame.IsShown and frame:IsShown() and true or false
end

local function EntryQuestID(entry)
  if type(entry)~="table" then return nil end
  return tonumber(entry.questID or entry.questId or entry.id)
end

local function EntryTitle(entry)
  if type(entry)~="table" then return nil end
  return entry.title or entry.name or entry.questName
end

local function BooleanValue(value)
  if value==nil then return nil end
  if value==1 or value==true then return true end
  if value==0 or value==false then return false end
  return value and true or false
end

local function AppendEntryTable(out,value)
  if type(value)~="table" then return end

  if EntryQuestID(value) then
    table.insert(out,value)
    return
  end

  local keys={}
  for key,entry in pairs(value) do
    if type(key)=="number" and type(entry)=="table" then
      table.insert(keys,key)
    end
  end
  table.sort(keys)

  for i=1,table.getn(keys) do
    local entry=value[keys[i]]
    if EntryQuestID(entry) then table.insert(out,entry) end
  end
end

local function ReadGossipEntries(functionName)
  if not C_GossipInfo or type(C_GossipInfo[functionName])~="function" then return {} end

  local ok,a,b,c,d,e,f,g,h=pcall(C_GossipInfo[functionName])
  if not ok then return {} end

  local out={}
  AppendEntryTable(out,a)
  AppendEntryTable(out,b)
  AppendEntryTable(out,c)
  AppendEntryTable(out,d)
  AppendEntryTable(out,e)
  AppendEntryTable(out,f)
  AppendEntryTable(out,g)
  AppendEntryTable(out,h)
  return out
end

local function AvailableEntries()
  return ReadGossipEntries("GetAvailableQuests")
end

local function ActiveEntries()
  return ReadGossipEntries("GetActiveQuests")
end

local function QuestModel(questID)
  if not questID or not QuestieOcto.QuestModel or not QuestieOcto.QuestModel.Get then return nil end
  return QuestieOcto.QuestModel:Get(questID)
end

local function IsRepeatableQuest(questID,entry)
  local q=QuestModel(questID)

  -- Explicit repeatable-after-first-completion semantics are character-local
  -- and take priority over live entry flags. The first interaction behaves as
  -- an ordinary quest; only characters that completed it once should require
  -- the Include Repeatable Quests automation opt-in afterward.
  if q and q.repeatableAfterFirstCompletion then
    return q.repeatable and true or false
  end

  if type(entry)=="table" then
    local value=BooleanValue(entry.isRepeatable)
    if value~=nil then return value end
    value=BooleanValue(entry.repeatable)
    if value~=nil then return value end
    if BooleanValue(entry.isDaily)==true or BooleanValue(entry.isWeekly)==true then return true end
  end

  if q then
    return (q.repeatable or q.daily or q.yearly) and true or false
  end
  return false
end

local function IsGrayQuest(questID,entry)
  if type(entry)=="table" then
    local value=BooleanValue(entry.isTrivial)
    if value~=nil then return value end
    value=BooleanValue(entry.trivial)
    if value~=nil then return value end
  end

  local q=QuestModel(questID)
  local questLevel=q and tonumber(q.level) or nil
  local playerLevel=type(UnitLevel)=="function" and tonumber(UnitLevel("player")) or nil
  if not questLevel or questLevel<=0 or not playerLevel then return false end

  -- Direct Octo/Turtle FrameXML uses a fixed 25-level quest green range:
  -- +25 remains standard, +26 becomes trivial/gray.
  return playerLevel>questLevel+25
end

local function IsCompletedQuest(questID,entry)
  if type(entry)=="table" then
    local value=BooleanValue(entry.isComplete)
    if value~=nil then return value end
    value=BooleanValue(entry.complete)
    if value~=nil then return value end
  end

  if questID and QuestieOcto.QuestLog and QuestieOcto.QuestLog.GetQuestStatus then
    return QuestieOcto.QuestLog:GetQuestStatus(questID)==1
  end
  return false
end

local function CurrentQuestTitle()
  if type(GetTitleText)~="function" then return nil end
  local ok,title=pcall(GetTitleText)
  if ok and title and title~="" then return title end
  return nil
end

local function FindUniqueEntryByTitle(entries,title)
  if not title then return nil end
  local found=nil
  for i=1,table.getn(entries or {}) do
    local entry=entries[i]
    if EntryTitle(entry)==title then
      if found then return nil end
      found=entry
    end
  end
  return found
end

local function FindActiveQuestIDByTitle(title)
  if not title or not QuestieOcto.QuestLog then return nil end
  local found=nil
  for questID,state in pairs(QuestieOcto.QuestLog.active or {}) do
    if state and state.title==title then
      if found then return nil end
      found=tonumber(questID)
    end
  end
  return found
end

local titleQuestIDs={}

local function QuestIDsForExactTitle(title)
  if not title or title=="" then return {} end
  if titleQuestIDs[title] then return titleQuestIDs[title] end

  local matches={}
  if QuestieOcto.DatabaseAPI and QuestieOcto.DatabaseAPI.GetQuestIDs and QuestieOcto.DatabaseAPI.GetQuestTitle then
    local ids=QuestieOcto.DatabaseAPI:GetQuestIDs() or {}
    for i=1,table.getn(ids) do
      local questID=tonumber(ids[i])
      if questID and QuestieOcto.DatabaseAPI:GetQuestTitle(questID)==title then
        table.insert(matches,questID)
      end
    end
  end

  titleQuestIDs[title]=matches
  return matches
end

local function CurrentNPCID()
  if not C_CreatureInfo or type(C_CreatureInfo.GetCreatureID)~="function" or type(UnitGUID)~="function" then return nil end

  local units={"npc","target"}
  for i=1,table.getn(units) do
    local ok,guid=pcall(UnitGUID,units[i])
    if ok and guid then
      local idOK,npcID=pcall(C_CreatureInfo.GetCreatureID,guid)
      npcID=idOK and tonumber(npcID) or nil
      if npcID then return npcID end
    end
  end
  return nil
end

local function HasCreatureStarter(questID,npcID)
  if not npcID then return false end
  local q=QuestModel(questID)
  local starters=q and q.starts and q.starts.creature or nil
  for i=1,table.getn(starters or {}) do
    if tonumber(starters[i])==npcID then return true end
  end
  return false
end

local function FindAvailableQuestIDByTitle(title)
  if not title then return nil end

  -- Gossip data is the strongest source when it exists because ClassicAPI gives
  -- us the exact localized title together with the quest ID. Quest-only NPCs
  -- use QUEST_GREETING instead, where the gossip list can legitimately be empty.
  local entry=FindUniqueEntryByTitle(AvailableEntries(),title)
  if entry then return EntryQuestID(entry),entry end

  local matches=QuestIDsForExactTitle(title)
  if table.getn(matches)==1 then return tonumber(matches[1]),nil end

  -- Duplicate titles exist in the database. Narrow them against the NPC starter
  -- when possible rather than guessing from the title alone.
  local npcID=CurrentNPCID()
  if npcID then
    local found=nil
    for i=1,table.getn(matches) do
      local questID=tonumber(matches[i])
      if questID and HasCreatureStarter(questID,npcID) then
        if found then return nil,nil end
        found=questID
      end
    end
    if found then return found,nil end
  end

  return nil,nil
end

function A:ResolveCurrentQuest(preferActive)
  if self.pending and self.pending.questID then
    return tonumber(self.pending.questID),self.pending.entry
  end

  local title=CurrentQuestTitle()
  if not title then return nil,nil end

  local first=preferActive and ActiveEntries() or AvailableEntries()
  local second=preferActive and AvailableEntries() or ActiveEntries()
  local entry=FindUniqueEntryByTitle(first,title) or FindUniqueEntryByTitle(second,title)
  if entry then return EntryQuestID(entry),entry end

  if preferActive then
    local questID=FindActiveQuestIDByTitle(title)
    if questID then return questID,nil end
  else
    local questID,fallbackEntry=FindAvailableQuestIDByTitle(title)
    if questID then return questID,fallbackEntry end
  end

  return nil,nil
end

function A:IsEnabled()
  return Settings():Get("autoAcceptQuests") or Settings():Get("autoTurnInQuests")
end

function A:ResetConversation()
  self.pending=nil
  self.conversationDisabled=false
  self.conversationTarget=nil
  self.processedRepeatables={}
  self.closeGeneration=(self.closeGeneration or 0)+1
end

function A:BeginInteraction()
  local target=TargetKey()
  if target and self.conversationTarget and target~=self.conversationTarget then
    self:ResetConversation()
  end
  if target then self.conversationTarget=target end

  if IsShiftDown() then self.conversationDisabled=true end
  return not self.conversationDisabled
end

function A:ScheduleConversationReset()
  self.closeGeneration=(self.closeGeneration or 0)+1
  local generation=self.closeGeneration
  QuestieOcto.Scheduler:After(0.15,function()
    if generation~=A.closeGeneration then return end
    if FrameShown(GossipFrame) or FrameShown(QuestFrame) then return end
    A:ResetConversation()
  end,"quest-automation-close")
end

function A:CanProcessQuest(questID,entry,accepting)
  questID=tonumber(questID)
  if not questID then return false,false end

  local repeatable=IsRepeatableQuest(questID,entry)
  if repeatable then
    if not Settings():Get("autoIncludeRepeatableQuests") then return false,true end
    -- A repeatable is marked as soon as Questie-Octo starts its interaction so
    -- it cannot loop when the NPC returns to gossip. The same pending quest
    -- must still be allowed to advance through DETAIL -> PROGRESS -> COMPLETE.
    if self.processedRepeatables[questID] and not (self.pending and tonumber(self.pending.questID)==questID) then
      return false,true
    end
  end

  if accepting and not Settings():Get("autoAcceptGrayQuests") and IsGrayQuest(questID,entry) then
    return false,repeatable
  end

  return true,repeatable
end

function A:MarkRepeatableProcessed(questID,repeatable)
  if repeatable and questID then self.processedRepeatables[tonumber(questID)]=true end
end

function A:SelectActiveQuest(questID,entry,legacyIndex)
  local allowed,repeatable=self:CanProcessQuest(questID,entry,false)
  if not allowed then return false end

  self.pending={ kind="turnin", stage="selected", questID=questID, entry=entry }

  local ok=false
  -- QUEST_GREETING is not the gossip list. When a native greeting-row index is
  -- supplied, use the native QuestFrame selector first. ClassicAPI's
  -- C_GossipInfo.SelectActiveQuest deliberately targets SelectGossipActiveQuest.
  if legacyIndex and type(SelectActiveQuest)=="function" then
    ok=pcall(SelectActiveQuest,legacyIndex)
  elseif C_GossipInfo and type(C_GossipInfo.SelectActiveQuest)=="function" then
    ok=pcall(C_GossipInfo.SelectActiveQuest,questID)
  end

  if not ok then
    self.pending=nil
    return false
  end

  self:MarkRepeatableProcessed(questID,repeatable)
  return true
end

function A:SelectAvailableQuest(questID,entry,legacyIndex)
  local allowed,repeatable=self:CanProcessQuest(questID,entry,true)
  if not allowed then return false end

  self.pending={ kind="accept", stage="selected", questID=questID, entry=entry }

  local ok=false
  -- Same distinction as active quests: QUEST_GREETING rows use the native
  -- SelectAvailableQuest(index), while C_GossipInfo selects a gossip row by ID.
  if legacyIndex and type(SelectAvailableQuest)=="function" then
    ok=pcall(SelectAvailableQuest,legacyIndex)
  elseif C_GossipInfo and type(C_GossipInfo.SelectAvailableQuest)=="function" then
    ok=pcall(C_GossipInfo.SelectAvailableQuest,questID)
  end

  if not ok then
    self.pending=nil
    return false
  end

  self:MarkRepeatableProcessed(questID,repeatable)
  return true
end

function A:TryModernGossip()
  -- Turn-ins always win over new accepts when both automation options are on.
  if Settings():Get("autoTurnInQuests") then
    local active=ActiveEntries()
    for i=1,table.getn(active) do
      local entry=active[i]
      local questID=EntryQuestID(entry)
      if questID and IsCompletedQuest(questID,entry) then
        local allowed=self:CanProcessQuest(questID,entry,false)
        if allowed then
          self:SelectActiveQuest(questID,entry,nil)
          return true
        end
      end
    end
  end

  if Settings():Get("autoAcceptQuests") then
    local available=AvailableEntries()
    for i=1,table.getn(available) do
      local entry=available[i]
      local questID=EntryQuestID(entry)
      if questID then
        local allowed=self:CanProcessQuest(questID,entry,true)
        if allowed then
          self:SelectAvailableQuest(questID,entry,nil)
          return true
        end
      end
    end
  end

  return false
end

function A:TryLegacyGossip()
  -- Current Octo FrameXML exposes gossip quest rows as title/value pairs. This
  -- fallback is only used when ClassicAPI's modern gossip table did not yield a
  -- selectable quest; keep the same one-action-at-a-time policy.
  if Settings():Get("autoTurnInQuests") and type(GetGossipActiveQuests)=="function" and type(SelectGossipActiveQuest)=="function" then
    local active={GetGossipActiveQuests()}
    local questIndex=1
    for i=1,table.getn(active),2 do
      local title=active[i]
      local questID=FindActiveQuestIDByTitle(title)
      if questID and IsCompletedQuest(questID,nil) then
        local allowed,repeatable=self:CanProcessQuest(questID,nil,false)
        if allowed then
          self.pending={ kind="turnin", stage="selected", questID=questID, entry=nil }
          local ok=pcall(SelectGossipActiveQuest,questIndex)
          if ok then
            self:MarkRepeatableProcessed(questID,repeatable)
            return true
          end
          self.pending=nil
        end
      end
      questIndex=questIndex+1
    end
  end

  if Settings():Get("autoAcceptQuests") and type(GetGossipAvailableQuests)=="function" and type(SelectGossipAvailableQuest)=="function" then
    local available={GetGossipAvailableQuests()}
    local questIndex=1
    for i=1,table.getn(available),2 do
      local title=available[i]
      local questID,entry=FindAvailableQuestIDByTitle(title)
      if questID then
        local allowed,repeatable=self:CanProcessQuest(questID,entry,true)
        if allowed then
          self.pending={ kind="accept", stage="selected", questID=questID, entry=entry }
          local ok=pcall(SelectGossipAvailableQuest,questIndex)
          if ok then
            self:MarkRepeatableProcessed(questID,repeatable)
            return true
          end
          self.pending=nil
        end
      end
      questIndex=questIndex+1
    end
  end

  return false
end

function A:TryLegacyGreeting()
  -- Quest-only NPCs use the native QuestFrame/QUEST_GREETING path rather than
  -- GossipFrame. Keep that path separate and automate only rows whose title can
  -- be resolved safely to one quest ID (or one matching starter for duplicates).
  if Settings():Get("autoTurnInQuests") and type(GetNumActiveQuests)=="function" and type(GetActiveTitle)=="function" then
    local count=tonumber(GetNumActiveQuests()) or 0
    for index=1,count do
      local title,isComplete=GetActiveTitle(index)
      local questID=FindActiveQuestIDByTitle(title)
      if questID and (isComplete==1 or isComplete==true or IsCompletedQuest(questID,nil)) then
        local allowed=self:CanProcessQuest(questID,nil,false)
        if allowed then
          self:SelectActiveQuest(questID,nil,index)
          return true
        end
      end
    end
  end

  if Settings():Get("autoAcceptQuests") and type(GetNumAvailableQuests)=="function" and type(GetAvailableTitle)=="function" then
    local count=tonumber(GetNumAvailableQuests()) or 0
    for index=1,count do
      local title=GetAvailableTitle(index)
      local questID,entry=FindAvailableQuestIDByTitle(title)
      if questID then
        local allowed=self:CanProcessQuest(questID,entry,true)
        if allowed then
          self:SelectAvailableQuest(questID,entry,index)
          return true
        end
      end
    end
  end

  return false
end

function A:OnGossipShow()
  if not self:IsEnabled() or not self:BeginInteraction() then return end
  self.pending=nil
  if not self:TryModernGossip() then self:TryLegacyGossip() end
end

function A:OnQuestGreeting()
  if not self:IsEnabled() or not self:BeginInteraction() then return end
  self.pending=nil
  if not self:TryModernGossip() then self:TryLegacyGreeting() end
end

function A:OnQuestDetail()
  if not Settings():Get("autoAcceptQuests") or not self:BeginInteraction() then return end

  local questID,entry=self:ResolveCurrentQuest(false)
  local allowed,repeatable=self:CanProcessQuest(questID,entry,true)
  if not allowed then return end
  if type(AcceptQuest)~="function" then return end

  self.pending={ kind="accept", stage="detail", questID=questID, entry=entry }
  local ok=pcall(AcceptQuest)
  if ok then
    self.pending.stage="accepted"
    self:MarkRepeatableProcessed(questID,repeatable)
  end
end

function A:OnQuestProgress()
  if not Settings():Get("autoTurnInQuests") or not self:BeginInteraction() then return end

  local questID,entry=self:ResolveCurrentQuest(true)
  local allowed,repeatable=self:CanProcessQuest(questID,entry,false)
  if not allowed then return end

  -- Native Octo shows a confirmation popup for money-cost turn-ins. Keep that
  -- whole transaction manual rather than automatically spending the player's money.
  if type(GetQuestMoneyToGet)=="function" then
    local ok,cost=pcall(GetQuestMoneyToGet)
    if ok and (tonumber(cost) or 0)>0 then return end
  end

  if type(IsQuestCompletable)~="function" or type(CompleteQuest)~="function" then return end
  local ok,complete=pcall(IsQuestCompletable)
  if not ok or not complete then return end

  self.pending={ kind="turnin", stage="progress", questID=questID, entry=entry }
  ok=pcall(CompleteQuest)
  if ok then
    self.pending.stage="complete"
    self:MarkRepeatableProcessed(questID,repeatable)
  end
end

function A:OnQuestComplete()
  if not Settings():Get("autoTurnInQuests") or not self:BeginInteraction() then return end

  local questID,entry=self:ResolveCurrentQuest(true)
  local allowed,repeatable=self:CanProcessQuest(questID,entry,false)
  if not allowed then return end

  if type(GetQuestMoneyToGet)=="function" then
    local ok,cost=pcall(GetQuestMoneyToGet)
    if ok and (tonumber(cost) or 0)>0 then return end
  end

  if type(GetNumQuestChoices)~="function" or type(GetQuestReward)~="function" then return end
  local ok,choices=pcall(GetNumQuestChoices)
  if not ok then return end
  choices=tonumber(choices) or 0

  -- More than one selectable reward always stays manual.
  if choices>1 then return end

  local rewardIndex=choices==1 and 1 or 0
  self.pending={ kind="turnin", stage="reward", questID=questID, entry=entry }
  ok=pcall(GetQuestReward,rewardIndex)
  if ok then
    self.pending.stage="rewarded"
    self:MarkRepeatableProcessed(questID,repeatable)
  end
end

local frame=CreateFrame("Frame","QuestieOctoQuestAutomationEvents",UIParent)
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("QUEST_GREETING")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_PROGRESS")
frame:RegisterEvent("QUEST_COMPLETE")
frame:RegisterEvent("GOSSIP_CLOSED")
frame:RegisterEvent("QUEST_FINISHED")
frame:SetScript("OnEvent",function()
  if event=="GOSSIP_SHOW" then
    A:OnGossipShow()
  elseif event=="QUEST_GREETING" then
    A:OnQuestGreeting()
  elseif event=="QUEST_DETAIL" then
    A:OnQuestDetail()
  elseif event=="QUEST_PROGRESS" then
    A:OnQuestProgress()
  elseif event=="QUEST_COMPLETE" then
    A:OnQuestComplete()
  elseif event=="GOSSIP_CLOSED" or event=="QUEST_FINISHED" then
    A:ScheduleConversationReset()
  end
end)
