local f=CreateFrame("Frame","QuestieOctoBootstrapFrame",UIParent)
f:RegisterEvent("PLAYER_ENTERING_WORLD")

function QuestieOcto:OnFoundationServiceReady()
  if self.ready then return end

  if self.Database.ready and self.DatabaseAPI:IsReady() and self.Completion.ready and self.QuestLog.snapshot then
    self.ready=true
    self.foundationReadyAt=GetTime and GetTime() or 0
    local q=self.DatabaseAPI:GetQuestCount()
    self:Print("foundation ready - "..tostring(q).." quests, "..tostring(self.Completion:Count())..
      " completed, "..tostring(self.QuestLog.stats.resolved).." active quest IDs resolved.")
    self:SendMessage("FOUNDATION_READY")
  end
end

f:SetScript("OnEvent",function()
  f:UnregisterEvent("PLAYER_ENTERING_WORLD")
  QuestieOcto.startedAt=GetTime()

  if not QuestieOcto.API:Validate() then
    QuestieOcto.enabled=false
    QuestieOcto:Error("ClassicAPI is required. Missing "..tostring(table.getn(QuestieOcto.API.missing)).." required API calls.")
    QuestieOcto:Error("Run /qo api after installing/updating ClassicAPI.")
    return
  end

  QuestieOcto.enabled=true
  if QuestieOcto.Tooltips and QuestieOcto.Tooltips.Initialize then
    QuestieOcto.Tooltips:Initialize()
  end
  QuestieOcto:RegisterMessage("DATABASE_READY",QuestieOcto,"OnFoundationServiceReady")
  QuestieOcto:RegisterMessage("DATABASE_API_READY",QuestieOcto,"OnFoundationServiceReady")
  QuestieOcto:RegisterMessage("COMPLETION_READY",QuestieOcto,"OnFoundationServiceReady")
  QuestieOcto:RegisterMessage("QUEST_LOG_CHANGED",QuestieOcto,"OnFoundationServiceReady")

  QuestieOcto:Print("ClassicAPI detected; starting Questie-Octo.")

  -- Prime character-local state before publishing the compiled database. The
  -- compiled DB is immediately ready (there is no runtime merge), so installing
  -- Quest Log/completion work first keeps the player's current state ahead of
  -- world-wide background presentation work in the startup queue.
  QuestieOcto.QuestLog:Start()
  QuestieOcto.Completion:ScheduleStart()
  QuestieOcto.Database:Start()
end)
