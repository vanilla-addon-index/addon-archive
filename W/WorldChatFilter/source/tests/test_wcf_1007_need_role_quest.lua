-- Regression: direct role requirement, optional quest name/link and question punctuation.
table.getn=table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function UnitName() return 'Tester' end
local now,delivered=100,0
function GetTime() return now end
function ChatFrame_OnEvent() delivered=delivered+1 end
function CreateFrame() return {RegisterEvent=function() end, SetScript=function() end} end
WorldChatFilterDB={enabled=true,filterGuild=true,filterLFG=true,filterServices=true,filterTrade=true,filterRepeats=false,sensitivity='balanced'}
for _,f in ipairs({'Core.lua','Statistics.lua','Classifier.lua','Filter.lua'}) do dofile(f) end
WorldChatFilter.Initialize()
local W=WorldChatFilter
local ads={
 'Need DPS [WANTED: Baron Vardus]',
 'Need DPS |cffff8000|Hquest:523|h[WANTED: Baron Vardus]|h|r',
 'Need DPS',
 'Need DPS?',
 'Need Tank [WANTED: Another Mob]',
 'Need Healer for Baron Vardus',
 'DPS needed [WANTED: Baron Vardus]',
 'Healer needed for elite quest',
 'Need DPS [Elite Monster Quest]',
 'Need DPS Baron Vardus',
 'NEED DPS FOR ELITES',
}
local chats={
 'Need heal potion',
 'Need healing potion for my quest',
 'Need heal spell for my build',
 'Need DPS advice for my rotation',
 'Need DPS meter for my UI',
 'Need DPS addon',
 'Need DPS rotation advice',
 'Need Mage for my screenshot',
 'I need 1 heal potion',
 'How much DPS is needed to kill Baron Vardus?',
 'What does Need DPS mean?',
 'Baron Vardus is fun',
 'I picked up [WANTED: Baron Vardus]',
}
for _,mode in ipairs({'careful','balanced','aggressive'}) do
  W.db.sensitivity=mode
  for _,msg in ipairs(ads) do
    local cat,score,why,blocked=W.ClassifyMessage(msg)
    assert(blocked and cat=='LFG',mode..' missed LFG '..msg..' '..tostring(cat)..' '..tostring(score)..' '..tostring(why))
  end
  for _,msg in ipairs(chats) do
    local cat,score,why,blocked=W.ClassifyMessage(msg)
    assert(not blocked,mode..' false positive '..msg..' '..tostring(cat)..' '..tostring(score)..' '..tostring(why))
  end
end
W.db.sensitivity='balanced'
local function event(msg,base)
 now=now+1
 arg1,arg2,arg4,arg7,arg9=msg,'OtherPlayer','4. '..base,7,base
 local before,stats=delivered,W.GetStats().total
 ChatFrame_OnEvent('CHAT_MSG_CHANNEL')
 return delivered-before,W.GetStats().total-stats
end
for _,msg in ipairs({ads[1],ads[2],ads[3]}) do
  local shown,recorded=event(msg,'World')
  assert(shown==0 and recorded==1,'World must hide ad and record once '..msg)
  for _,name in ipairs({'Trade','General','LookingForGroup','Guild','Party'}) do
    shown,recorded=event(msg,name)
    assert(shown==1 and recorded==0,'Must not suppress non-World '..name)
  end
end
W.db.filterLFG=false
local shown,recorded=event(ads[1],'World')
assert(shown==1 and recorded==0,'LFG disabled should show message')
print('PASS direct Need role: '..#ads..' ads, '..#chats..' regular messages x3; hooks/toggles/stats')
