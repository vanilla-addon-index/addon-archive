-- Regression: shuffled dungeon slot requests and EN/ES guild recruitment adverts.
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
local lfgAds={
 'DEADMINES 1DPS?', '1DPS DEADMINES?', '1 DPS Deadmines?',
 'DPS 1 DEADMINES?', 'Deadmines DPS 1?', '1 DEADMINES DPS?',
 'DPS1 DEADMINES?', 'DEADMINES DPS1?', 'Deadmines HEAL 2DPS?',
 'What does LF1DPS for DEADMINES mean?', 'Kara10 DEADMINES DPS1?',
 'LFM DEADMINES 1 MAGE?', '1 tank needed for BRD?',
 'Why are Mages needed for Friday PUG 17:00 ST?',
}
local guildAds={
 '<Thunder Ale Brewing Co.> is starting fresh here on Octowow! One of Turtle WoW\'s top speedrun guilds, now looking mostly for Mages/Shamans/Warlocks for our main rooster! [https://discord.gg/99VREUC4P] for more information!',
 '<<EL AZOTE>> llega a OctoWow. Fuimos la guild más numerosa de Turtle WoW SA y ahora aterrizamos en OctoWow. Comunidad activa, raids, buena onda y cero toxicidad. ¡Te esperamos! Susurro para inv',
 '<New Sailors> Raid every Sunday 20:30 CET - whisper for invite!',
 'Raid tonight UTC 20:30, ask for invite to <New Sailors>',
 'Invite for <New Sailors>, raids on Fridays 20:00 server time',
 'I saw <New Sailors> invite someone for MC raid at 20:00 yesterday',
 '<New Dawn> looking mostly for Priests/Shamans; raid roster, discord.gg/example',
 '<Los Amigos> raids en comunidad activa, susurro para inv',
 'Te esperamos! Comunidad activa, raids! <Los Amigos> susurro para inv',
 'Comunidad activa y raids, <Los Amigos> te esperamos! susurro para inv',
}
local ordinary={
 'DEADMINES HEAL potion?',
 'Deadmines is fun with a rogue',
 'What is the Deadmines level requirement?',
 'I need 1 Mage for my screenshot',
 'That guild helped me yesterday in raids',
 '<New Sailors> cleared raids yesterday',
 '<Los Amigos> juega en OctoWoW; raids ayer',
 'Where can I find guilds for raids?',
 'What does susurro para inv mean?',
 'My guild does not do raids at 20:30 CET',
 'I am searching for my guild members in Stormwind',
}
for _,mode in ipairs({'careful','balanced','aggressive'}) do
 W.db.sensitivity=mode
 for _,msg in ipairs(lfgAds) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(blocked and cat=='LFG',mode..' LFG missed '..msg..' '..tostring(cat)..' '..tostring(score)..' '..tostring(why))
 end
 for _,msg in ipairs(guildAds) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(blocked and cat=='Guild',mode..' guild missed '..msg..' '..tostring(cat)..' '..tostring(score)..' '..tostring(why))
 end
 for _,msg in ipairs(ordinary) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(not blocked,mode..' false positive '..msg..' '..tostring(cat)..' '..tostring(score)..' '..tostring(why))
 end
end
W.db.sensitivity='balanced'
local function deliver(msg,base)
 now=now+1
 arg1,arg2,arg4,arg7,arg9=msg,'User', '4. '..base,7,base
 local before=delivered
 local prior=W.GetStats().total
 ChatFrame_OnEvent('CHAT_MSG_CHANNEL')
 return delivered-before,W.GetStats().total-prior
end
for _,msg in ipairs({lfgAds[1],guildAds[1],guildAds[2]}) do
 local shown,count=deliver(msg,'World')
 assert(shown==0 and count==1,'Must filter World and update stats '..msg)
 for _,chan in ipairs({'Trade','General','LookingForGroup','Guild'}) do
  shown,count=deliver(msg,chan)
  assert(shown==1 and count==0,'Must not filter '..chan)
 end
end
W.db.filterGuild=false
assert(deliver(guildAds[1],'World')==1,'Guild toggle must work')
W.db.filterGuild=true; W.db.filterLFG=false
assert(deliver(lfgAds[1],'World')==1,'LFG toggle must work')
print('PASS permutations: '..#lfgAds..' dungeon ads, '..#guildAds..' guild ads, '..#ordinary..' chats x3; hooks/toggles/stats')
