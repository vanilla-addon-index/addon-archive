-- Regression: high-recall LF/LFM/Looking-for X speakers and absolute RU-GUILD prefix.
-- Language vocabulary is deliberately unrestricted; even Bluetooth speakers blocks.
table.getn=table.getn or function(t) return #t end
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
local adsLFG={
 'LF English speakers', 'Looking for Greek speakers',
 'LFM Russian speakers', 'LF1M German speakers',
 'LF13M Turkish speakers', 'LFM2M Spanish speakers',
 'LF1M friendly Korean speakers',
 'Looking for active friendly Spanish speakers',
 'looking for Martian speakers',
 'LF Bluetooth speakers for my PC', -- intentional false positive
 'What does LF Greek speakers mean?', -- intentionally blocked
 'People keep saying LFM English speakers', -- intentionally blocked
 'LF English speakers?',
 'lf Lithuanian speakers for the group',
 'In our guild, LF Greek speakers are welcome',
 'French speakers were here; LF Russian speakers to raid',
}
local adsGuild={
 '<Guild Alpha> looking for English speakers',
 '<Gamers Zone> Looking for Russian speakers to join our guild',
 '<Team Orange> LFM German speakers for raids',
 'RU GUILD', 'RU-GUILD for MC 12/12', 'RU-GILD ONY 2/2',
 'RU_GUILD welcome', 'ru:gild looking for members',
 'RUSSIAN GUILD hello', 'RUSSIAN-GILD not recruiting',
 'RUS GUILD blah', 'russ guild fun', 'RUSSIAN GILDE',
 '   RU -- GUILD not recruiting',
 '<RU-GUILD> what does RU guild mean?',
 'RU GUILD is a funny typo lol', -- intentionally filtered
 'RU Guild or EU Guild, which would you join?', -- intentionally filtered
 'Russian guild players helped yesterday', -- intentionally filtered by absolute prefix
 'RUGUILD recruiting people', 'RUSSIANGILD MC 12/12',
}
local ordinary={
 'I talked to the RU GUILD yesterday',
 'Does RU-GILD mean Russian guild?',
 '<Green Team> is made up of friendly players',
 'My Bluetooth speakers are broken',
 'English speakers prefer their own channel',
 'How many speakers should I connect?',
 'LF a good name for my speaker device',
 'LF a good speaker for a podcast',
 'I need a Greek translator to help',
}
for _,mode in ipairs({'careful','balanced','aggressive'}) do
 W.db.sensitivity=mode
 for _,msg in ipairs(adsLFG) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(blocked and cat=='LFG',mode..' missed speaker request '..msg..' '..tostring(cat)..' '..tostring(score)..' '..tostring(why))
 end
 for _,msg in ipairs(adsGuild) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(blocked and cat=='Guild',mode..' missed guild request '..msg..' '..tostring(cat)..' '..tostring(score)..' '..tostring(why))
 end
 for _,msg in ipairs(ordinary) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(not blocked,mode..' ordinary message blocked '..msg..' '..tostring(cat)..' '..tostring(score)..' '..tostring(why))
 end
end
W.db.sensitivity='balanced'
local function event(msg,base)
 now=now+1
 arg1,arg2,arg4,arg7,arg9=msg,'SomeoneElse','4. '..base,7,base
 local n,c=delivered,W.GetStats().total
 ChatFrame_OnEvent('CHAT_MSG_CHANNEL')
 return delivered-n,W.GetStats().total-c
end
for _,msg in ipairs({adsLFG[1],adsGuild[1],adsGuild[4]}) do
 local shown,cnt=event(msg,'World')
 assert(shown==0 and cnt==1,'Must hide World advert and record once')
 for _,channel in ipairs({'General','Trade','LookingForGroup','Guild','Party'}) do
  shown,cnt=event(msg,channel)
  assert(shown==1 and cnt==0,'Must never hide or count '..channel)
 end
end
W.db.filterLFG=false
assert(event(adsLFG[1],'World')==1,'LFG toggle must be respected')
W.db.filterLFG=true;W.db.filterGuild=false
assert(event(adsGuild[1],'World')==1,'Tagged speakers must respect Guild toggle')
assert(event(adsGuild[4],'World')==1,'RU Guild prefix must respect Guild toggle')
print('PASS speakers/prefix: '..#adsLFG..' LFG + '..#adsGuild..' Guild ads, '..#ordinary..' non-ads x3 and World-only/toggles/stats')
