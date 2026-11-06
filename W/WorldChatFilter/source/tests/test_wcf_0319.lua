table.getn = table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
function UnitName() return 'Tester' end
local now=1
function GetTime() return now end
local delivered=0
function ChatFrame_OnEvent() delivered=delivered+1 end
WorldChatFilterDB={enabled=true,filterTrade=true,filterGuild=true,filterLFG=true,filterServices=true,filterRepeats=true,sensitivity='balanced'}
local root=''
for _,f in ipairs({'Core.lua','Statistics.lua','Classifier.lua','Filter.lua'}) do dofile(root..f) end
WorldChatFilter.Initialize()
local W=WorldChatFilter
local ads={
'LF 1M Hinterlands Elites Last Spot',
'LF1M Hinterlands Elites Last Spot',
'LF 1 M Hinterlands Elites Last Spot',
'LF 2M for elite quests',
'LF 2 M for elite quests',
'LF 10M for group quests',
'LF 2 MORE for elite quests',
'LF 3M BRD',
'LFM1 dd (no rogue) DMW',
'LF7M Kara10',
}
local chat={
'What does LF 1M mean?',
'What is LF 1M shorthand for?',
'LF advice for Hinterlands elites',
'Anyone know if Hinterlands elites are hard?',
'I finished the Hinterlands elites yesterday',
'The phrase LF 2 M means looking for 2 more',
'Thinking of questing in Hinterlands later',
'I heard you can solo most Hinterlands elites',
}
for _,mode in ipairs({'careful','balanced','aggressive'}) do
 W.db.sensitivity=mode
 for _,msg in ipairs(ads) do
  local c,score,why,blocked=W.ClassifyMessage(msg)
  assert((mode=='careful' and msg=='LF7M Kara10') or (blocked and c=='LFG'),'Missing ad: '..mode..' '..msg..' reason '..tostring(why)..' score '..tostring(score))
 end
 for _,msg in ipairs(chat) do
  local c,score,why,blocked=W.ClassifyMessage(msg)
  assert(not blocked,'False positive: '..mode..' '..msg..' reason '..tostring(why)..' score '..tostring(score))
 end
end
local msg=ads[1]
W.db.sensitivity='balanced'
local origStats=W.GetStats().total
local function send(base,numbered,evt)
 now=now+1
 arg1,arg2,arg4,arg7,arg8,arg9=msg,'Other',numbered,6,4,base
 local before=delivered
 ChatFrame_OnEvent(evt or 'CHAT_MSG_CHANNEL')
 return delivered-before
end
assert(send('World','4. World')==0,'World ad should hide')
assert(W.GetStats().total==origStats+1)
for _,c in ipairs({{'Trade','2. Trade'},{'General - Elwynn Forest','1. General - Elwynn Forest'},{'LookingForGroup','5. LookingForGroup'}}) do assert(send(c[1],c[2])==1,'other channel should show '..c[1]) end
assert(send('World','4. World','CHAT_MSG_SAY')==1,'non-channel event should show')
assert(W.GetStats().total==origStats+1)
print('PASS LF separated variants, x3 sensitivity, negative chat cases, World vs Trade & other channels')
