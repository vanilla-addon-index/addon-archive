-- 0.3.23: Real reports of implicit/abbreviated dungeon and open-world LFG.
table.getn = table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function UnitName() return 'Tester' end
local now, delivered=100,0
function GetTime() return now end
function ChatFrame_OnEvent() delivered=delivered+1 end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
WorldChatFilterDB={enabled=true,filterGuild=true,filterLFG=true,filterServices=true,filterTrade=true,filterRepeats=true,sensitivity='balanced'}
for _,f in ipairs({'Core.lua','Statistics.lua','Classifier.lua','Filter.lua'}) do dofile(''..f) end
WorldChatFilter.Initialize()
local W=WorldChatFilter
assert(W.VERSION == '1.1.2', 'v1.1.2 stable version expected')
local ads={
 'lf scarley graveyard',
 'lf scarlet graveyard*',
 'LF Scarlet Graveyard',
 'LF Graveyard',
 'LF SM GY',
 'LF BRD',
 'need 1 heal for windhorn',
 'need 1 healer for windhorn',
 'Need 1 Tank for the elite quests',
 'need 2 DPS for group quests',
 'Need 1 Mage for raid',
 'need 1 tank',
 'DEADMINES HEAL 2DPS',
 'DEADMINES HEAL 2 DPS',
 'BRD HEAL 2DPS',
 'SFK HEAL 1TANK',
 'Deadmines tank 2 heal',
  -- Explicit preference: all dungeon + count + role/class combinations are filtered.
 'DEADMINES HEAL 2DPS?',
 'I heard people advertising Deadmines heal 2dps',
 'We did Deadmines with heal 2dps yesterday',
}
local chats={
 'What does LF Scarlet Graveyard mean?',
 'LF some advice on BM rep farming',
 'LF advice for Scarlet Graveyard tactics',
 'LF a cool name for my rogue',
 'I loved Scarlet Graveyard yesterday',
 'Scarlet Graveyard is a fun dungeon',
 'I need 1 heal potion',
 'Need 1 heal potion',
 'Need 1 healing spell for my build',
 'I need 1 Mage for my screenshot',
 'Deadmines is great for healers and DPS',
 'I want to play a healer in Deadmines',
 'Anyone know if Windhorn is nearby?',
 'What does need 1 heal mean?',
}
for _,mode in ipairs({'careful','balanced','aggressive'}) do
 W.db.sensitivity=mode
 for _,msg in ipairs(ads) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(blocked and cat=='LFG', mode..' missed '..msg..' '..tostring(cat)..' '..tostring(score)..' '..tostring(why))
 end
 for _,msg in ipairs(chats) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(not blocked, mode..' false positive '..msg..' '..tostring(cat)..' '..tostring(score)..' '..tostring(why))
 end
end
W.db.sensitivity='balanced'
local sample=ads[1]
local function event(channel, decorated, eventName)
 now=now+1
 arg1,arg2,arg4,arg7,arg8,arg9=sample, 'User', decorated, 24, 4, channel
 local before=delivered
 local stats=W.GetStats().total
 ChatFrame_OnEvent(eventName or 'CHAT_MSG_CHANNEL')
 return delivered-before,W.GetStats().total-stats
end
local shown,counted=event('World','4. World')
assert(shown==0 and counted==1, 'Must hide and count World LFG')
for _,kind in ipairs({'Trade','General','LookingForGroup'}) do
 shown,counted=event(kind,'4. '..kind)
 assert(shown==1 and counted==0, 'Must not hide/count '..kind)
end
shown,counted=event('World','4. Trade')
assert(shown==1 and counted==0, 'Conflicting metadata must fail open')
shown,counted=event('World','4. World','CHAT_MSG_SAY')
assert(shown==1 and counted==0, 'Only channel chat filtered')
W.db.filterLFG=false
shown,counted=event('World','4. World')
assert(shown==1 and counted==0, 'LFG toggle must be honored')
print('PASS v0.3.23: '..#ads..' group ads, '..#chats..' ordinary conversations x3, World/Trade isolation')
