-- Regression: single-slot Deadmines ads and German raid recruitment.
table.getn = table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function UnitName() return 'Tester' end
local now, delivered=100,0
function GetTime() return now end
function ChatFrame_OnEvent() delivered=delivered+1 end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
WorldChatFilterDB={enabled=true,filterGuild=true,filterLFG=true,filterServices=true,filterTrade=true,filterRepeats=false,sensitivity='balanced'}
for _,f in ipairs({'Core.lua','Statistics.lua','Classifier.lua','Filter.lua'}) do dofile(f) end
WorldChatFilter.Initialize()
local W=WorldChatFilter
local adLFG={
  'DEADMINES 1DPS',
  'DEADMINES 1 DPS',
  'deadmines 2DPS',
  'BRD 1HEALER',
  'SFK 1 tank',
  'DEADMINES HEAL 2DPS',
  -- Explicit preference: all dungeon + count + role/class combinations are filtered.
  'DEADMINES 1DPS?',
  'What does DEADMINES 1DPS mean?',
  'Deadmines 1dps is a strange composition',
  'I saw someone type DEADMINES 1DPS',
  'Deadmines 1DPS was enough last night',
  'Was bedeutet Gesucht 1 Shadow Priest für MC 19:30?',
  'Gestern waren noch Raidplätze frei und 1 Priest war gesucht für MC',
}
local adGuild={
  '<Oktagon> hat noch feste Raidplätze frei! Gesucht: 1 Shadow Priest, 1 Healschami, 1 Healdruid & 1 Retri! MC Mi 19:30 Uhr (~50 Min) SR+ &',
  'Raidplätze frei! Gesucht: 1 Healschami für MC 19:30 Uhr',
  'Gesucht: 1 Shadow Priest für MC',
  'Raidplatze frei, gesucht 1 Healdruid!',
}
local conversations={
  'DEADMINES 1 potion',
  'Deadmines is nice for DPS',
  'Ich habe gehört dass Raidplätze frei sind und 1 Healschami gesucht wird',
  'MC 19:30 Uhr ist ein guter Raidzeitpunkt',
  'We had a Shadow Priest for MC yesterday',
}
for _,mode in ipairs({'careful','balanced','aggressive'}) do
 W.db.sensitivity=mode
 for _,m in ipairs(adLFG) do
  local c,score,why,blocked=W.ClassifyMessage(m)
  assert(blocked and c=='LFG',mode..' LFG missed '..m..' '..tostring(c)..' '..tostring(score)..' '..tostring(why))
 end
 for _,m in ipairs(adGuild) do
  local c,score,why,blocked=W.ClassifyMessage(m)
  assert(blocked and c=='Guild',mode..' German raid recruitment missed '..m..' '..tostring(c)..' '..tostring(score)..' '..tostring(why))
 end
 for _,m in ipairs(conversations) do
  local c,score,why,blocked=W.ClassifyMessage(m)
  assert(not blocked,mode..' false positive '..m..' '..tostring(c)..' '..tostring(score)..' '..tostring(why))
 end
end
W.db.sensitivity='balanced'
local function deliveredFor(msg,base,decorated)
 now=now+1
 arg1,arg2,arg4,arg7,arg9=msg,'OtherPlayer',decorated,7,base
 local before=delivered
 ChatFrame_OnEvent('CHAT_MSG_CHANNEL')
 return delivered-before
end
for _,m in ipairs({adLFG[1],adGuild[1]}) do
 assert(deliveredFor(m,'World','4. World')==0,'World advert leaked: '..m)
 for _,c in ipairs({'Trade','General','LookingForGroup','Guild'}) do
  assert(deliveredFor(m,c,'4. '..c)==1,'Non-World filtered: '..c)
 end
end
print('PASS regression: '..#adLFG..' LFG ads, '..#adGuild..' German roster ads, '..#conversations..' normal chats x3 and World-only hook')
