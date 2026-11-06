table.getn = table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function UnitName() return 'Tester' end
local now,delivered=100,0
function GetTime() return now end
function ChatFrame_OnEvent() delivered=delivered+1 end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
WorldChatFilterDB={enabled=true,filterGuild=true,filterLFG=true,filterServices=true,filterTrade=true,filterRepeats=false,sensitivity='balanced'}
for _,f in ipairs({'Core.lua','Statistics.lua','Classifier.lua','Filter.lua'}) do dofile(f) end
WorldChatFilter.Initialize()
local W=WorldChatFilter
local ads={
 "Join THE CULT, we're a social guild and growing, and dope af (We are starting to raid)",
 "JOIN THE CULT - social guild - starting to raid",
 "Join The Crows, we're a friendly social guild",
 "Join <The Crows>, we're starting to raid",
 "Come join The Nightwatch, a growing guild",
 "Please join The Nightwatch, our social guild is growing",
 "Join our guild, we're a friendly community",
 "Join our social guild!",
 "Join our community for weekly events",
 "We are a growing guild, join us!",
 "The Nightwatch guild is growing, join us",
 "You're invited to join <The Crows> for a friendly experience",
 "Join THE CULT? We're a social guild",
}
local chats={
 "I joined THE CULT yesterday and their guild is social",
 "What does Join THE CULT mean?",
 "Are social guilds growing on OctoWoW?",
 "I'm thinking about joining a guild",
 "Join the raid!",
 "Join me in Stormwind",
 "We had fun raiding with The Cult last night",
 "We discussed joining guilds yesterday",
}
for _,mode in ipairs({'careful','balanced','aggressive'}) do
 W.db.sensitivity=mode
 for _,msg in ipairs(ads) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(blocked and cat=='Guild',mode..' missed '..msg..' '..tostring(cat)..' '..tostring(score)..' '..tostring(why))
 end
 for _,msg in ipairs(chats) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(not blocked,mode..' false positive '..msg..' '..tostring(cat)..' '..tostring(score)..' '..tostring(why))
 end
end
W.db.sensitivity='balanced'
local function event(msg,base)
 now=now+1
 arg1,arg2,arg4,arg7,arg9=msg,'User','4. '..base,7,base
 local before,stat=delivered,W.GetStats().total
 ChatFrame_OnEvent('CHAT_MSG_CHANNEL')
 return delivered-before,W.GetStats().total-stat
end
for _,msg in ipairs({ads[1],ads[4]}) do
 local shown,count=event(msg,'World')
 assert(shown==0 and count==1,'World Guild advertisement must be hidden once')
 for _,chan in ipairs({'Trade','General','Guild','LookingForGroup','Party'}) do
  shown,count=event(msg,chan)
  assert(shown==1 and count==0,'Non World must pass '..chan)
 end
end
W.db.filterGuild=false
local shown,count=event(ads[1],'World')
assert(shown==1 and count==0,'Guild toggle should allow ads')
print('PASS join invitation: '..#ads..' guild adverts + '..#chats..' chats x3 and channel/toggle checks')
