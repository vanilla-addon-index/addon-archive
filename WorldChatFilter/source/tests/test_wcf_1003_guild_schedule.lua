-- Regression: implicit tagged recruitment & weekday/time dungeon schedules.
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
local guildAds={
 '<Secret Hideout> is looking for active, friendly players who wants to help build our crew. Experienced or new, all dedicated players are welcome.',
 '<Green Haven> looking for friendly players!',
 '<New Family> looking for players who want to build our crew',
 '<New Family> all dedicated players are welcome',
 '<Snow Clan> Members are welcome!',
 'Looking for active players! <Tree Friends>',
}
local scheduledAds={
 'MC Mi 19:30 Uhr (~50 Min) SR+ &',
 '19:30 Mi MC',
 'MC 19:30 Mi',
 'Wednesday 19:30 MC',
 '19:30 Wednesday MC',
 'BRD Thursday 18:30',
 'Thursday BRD 18:30',
 'Raid Wednesday 19:30',
 '19:30 Wednesday raid',
 'Fri ZG 20:30',
 'Fri 20:30 ZG',
 'Sunday Deadmines 17:00',
 'Mi 19:30 Uhr MC?',
 'We did MC Wednesday 19:30',
 'Why are Mages needed for Friday PUG 17:00 ST?',
}
local ordinary={
 '<Secret Hideout> is a cool guild name',
 'Someone said <Secret Hideout> was looking for players yesterday',
 'I am searching for my guild members in Stormwind',
 'Deadmines is a nice dungeon',
 'MC is fun on Wednesdays',
 'I can play on Wednesday evening',
 '17:00 ST is the scheduled server reboot time on Friday',
 'What time is MC on Wednesday?',
}
for _,mode in ipairs({'careful','balanced','aggressive'}) do
 W.db.sensitivity=mode
 for _,msg in ipairs(guildAds) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(blocked and cat=='Guild',mode..' guild ad leaked '..msg..' '..tostring(cat)..' '..tostring(score)..' '..tostring(why))
 end
 for _,msg in ipairs(scheduledAds) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(blocked and cat=='LFG',mode..' scheduled group leaked '..msg..' '..tostring(cat)..' '..tostring(score)..' '..tostring(why))
 end
 for _,msg in ipairs(ordinary) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(not blocked,mode..' unintended match '..msg..' '..tostring(cat)..' '..tostring(score)..' '..tostring(why))
 end
end
W.db.sensitivity='balanced'
local function receive(msg, base)
 now=now+1
 arg1,arg2,arg4,arg7,arg9=msg, 'AnotherPlayer', '4. '..base, 8, base
 local seen=delivered
 local hits=W.GetStats().total
 ChatFrame_OnEvent('CHAT_MSG_CHANNEL')
 return delivered-seen,W.GetStats().total-hits
end
for _,msg in ipairs({guildAds[1],scheduledAds[1]}) do
 local shown,count=receive(msg,'World')
 assert(shown==0 and count==1,'World advert must hide exactly once')
 for _,channel in ipairs({'Trade','General','Guild','LookingForGroup','Party'}) do
  shown,count=receive(msg,channel)
  assert(shown==1 and count==0,'Must not filter or count '..channel)
 end
end
W.db.filterGuild=false
assert(receive(guildAds[1],'World')==1,'Guild toggle must allow tagged promo')
W.db.filterGuild=true;W.db.filterLFG=false
assert(receive(scheduledAds[1],'World')==1,'LFG toggle must allow dated run')
print('PASS new intent: '..#guildAds..' tagged guild ads, '..#scheduledAds..' timed raids, '..#ordinary..' nonmatches x3; World-only/toggles/stats')
