table.getn=table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
function UnitName() return 'Tester' end
local clock=0
function GetTime() return clock end
local delivered=0
function ChatFrame_OnEvent() delivered=delivered+1 end
WorldChatFilterDB={enabled=true, filterTrade=true,filterGuild=true,filterLFG=true,filterServices=true,filterRepeats=true,sensitivity='balanced'}
local root=''
for _,f in ipairs({'Core.lua','Statistics.lua','Classifier.lua','Filter.lua'}) do dofile(root..f) end
WorldChatFilter.Initialize()
local W=WorldChatFilter
local ads={
  'LF 1Healer Hinterlands Elites',
  'LF 1 Healer Hinterlands Elites',
  'LF1Healer Hinterlands Elites',
  'LF 2 DPS Hinterlands Elites',
  'LF2DPS BRD',
  'LF 1 Tank for BRD',
  'LF 1 Rogue',
  'LF1Mage',
  'LF 1 Mage',
  'LF2Warlocks for MC',
  'LF 2 Shamans to join',
  'LF 1 Holy Priest for MC',
  'Looking for 2 Mages for ZG',
  'LF Priest Hinterlands Elites',
  'LF Mage',
  'LF 1 Rogue for group quests',
  'LF 1Druid Hinterlands Elites',
  'LFM1 dd (no rogue) DMW',
}
local chat={
  'What does LF 1Healer mean?',
  'What does LF1Mage mean?',
  'What is LF 1 Mage short for?',
  'How to use LF1Mage in chat?',
  'The phrase LF 2 Shamans means two more shamans are needed',
  'I heard LF 1 Rogue in World earlier',
  'People type LF 1 Mage all the time',
  'Is Mage fun for Hinterlands elites?',
  'A priest helped me with Hinterlands quests yesterday',
  'I play a rogue and can solo the elites',
  'What does LF 1M mean?',
  'I need advice on my healer build',
  'Need 1 recipe for my mage',
  'Anyone know if this dungeon is hard?',
  'LF advice on which class to play',
}
for _,mode in ipairs({'careful','balanced','aggressive'}) do
  W.db.sensitivity=mode
  for _,s in ipairs(ads) do
    local cat, score, why, blocked = W.ClassifyMessage(s)
    assert(blocked and cat=='LFG', mode..' should block: '..s..' result: '..tostring(cat)..' '..tostring(score)..' '..tostring(why))
  end
  for _,s in ipairs(chat) do
    local cat, score, why, blocked = W.ClassifyMessage(s)
    assert(not blocked, mode..' should allow: '..s..' result: '..tostring(cat)..' '..tostring(score)..' '..tostring(why))
  end
end
local sample='LF 1Healer Hinterlands Elites'
W.db.sensitivity='balanced'
local preCount=W.GetStats().total
local function dispatch(base,numbered,event)
  clock=clock+1
  arg1,arg2,arg4,arg7,arg8,arg9=sample,'Other',numbered,6,4,base
  local before=delivered
  ChatFrame_OnEvent(event or 'CHAT_MSG_CHANNEL')
  return delivered-before
end
assert(dispatch('World','4. World')==0)
assert(W.GetStats().total==preCount+1)
for _,name in ipairs({'Trade','General','LookingForGroup'}) do
  assert(dispatch(name,'5. '..name)==1, name..' must not be filtered')
end
assert(dispatch('World','4. World','CHAT_MSG_SAY')==1)
assert(W.GetStats().total==preCount+1)
print('PASS counted LF roles/classes across 18 ads x 3 modes; 15 normal chats x 3; World/Trade event isolation')
