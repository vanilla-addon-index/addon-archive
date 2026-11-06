-- WorldChatFilter 0.3.22: scheduled PUG/raid role demand without LFG/LFM.
-- Never blacklist guild names: examples use multiple fake and unrelated guilds.
table.getn=table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function UnitName() return 'Tester' end
local now, delivered=100,0
function GetTime() return now end
function ChatFrame_OnEvent() delivered=delivered+1 end
function CreateFrame() return {RegisterEvent=function() end, SetScript=function() end} end
WorldChatFilterDB={enabled=true,filterGuild=true,filterLFG=true,filterServices=true,filterTrade=true,filterRepeats=true,sensitivity='balanced'}
for _,f in ipairs({'Core.lua','Statistics.lua','Classifier.lua','Filter.lua'}) do dofile(''..f) end
WorldChatFilter.Initialize()
local W=WorldChatFilter
assert(W.VERSION=='1.1.2')
local ads={
 '<BRUTAL> ! Sub-hour runs with at least 1 guaranteed wipe! SR+, RT: Saturday+Sunday Pug! 17:00 ST! Healers and Mages in demand!',
 '<Example> Friday PUG 18:30 ST - Priests needed for our run',
 'Saturday PUG 17:00 ST - Mages and Priests needed',
 'Raid Sunday 20:00 ST, healers required',
 'Friday BWL raid at 19:00 - Hunters and Shamans wanted',
 '<Example> Weekend PUG at 21:00 ST: DPS in demand!',
 '<Moon> Our raids Saturday 21:00! Tanks required.',
 'Saturday and Sunday raids: Mages in demand',
 'Tomorrow PUG 20:00: Shamans needed',
 'Weekly raid at 18:30 - healers in demand',
 'Sunday group at 19:00 - Rogues wanted',
 'Every Monday PUG at 16:30 ST: Priests required',
 'Friday raid 20:00 ST - Looking for Warlocks',
 'Are healers in demand for Saturday PUG at 17:00?',
 'I heard healers in demand for Saturday PUG 17:00',
 'We discussed Priests needed for Saturday PUG at 17:00',
 'I am healing a PUG on Saturday at 17:00',
 'The Saturday PUG with healers at 17:00 was fun',
 'Why are Mages needed for Friday PUG 17:00 ST?',
 'Saturday PUG 17:00 ST - are Mages required?',
}
local chats={
 'Healers and mages are in demand, why is that?',
 'Healers and Mages in demand for next raid season',
 'What does in demand mean for a Mage?',
 'Mages are very fun to play in raids on Friday',
 'Is anyone looking for a good name for their PUG?',
 'What does it mean when an ad says Priests required for Friday PUG?',
 'My guild BRUTAL is not recruiting, we raided Saturday',
 'I joined BRUTAL to play with my friends',
}
for _,mode in ipairs({'careful','balanced','aggressive'}) do
 W.db.sensitivity=mode
 for _,ad in ipairs(ads) do
  local category,score,why,blocked=W.ClassifyMessage(ad)
  assert(blocked and category=='LFG',mode..': missed '..ad..' ('..tostring(category)..':'..tostring(score)..' '..tostring(why)..')')
 end
 for _,msg in ipairs(chats) do
  local category,score,why,blocked=W.ClassifyMessage(msg)
  assert(not blocked,mode..': false positive '..msg..' ('..tostring(category)..':'..tostring(score)..' '..tostring(why)..')')
 end
end
W.db.sensitivity='balanced'
local sample=ads[1]
local function event(channel,decorated,kind)
 now=now+1
 arg1,arg2,arg4,arg7,arg8,arg9=sample,'AdvertisingPlayer',decorated,24,4,channel
 local oldDisplayed=delivered
 local oldTotal=W.GetStats().total
 ChatFrame_OnEvent(kind or 'CHAT_MSG_CHANNEL')
 return delivered-oldDisplayed,W.GetStats().total-oldTotal
end
local showed,hidden=event('World','4. World')
assert(showed==0 and hidden==1,'Must suppress World PUG ad and count once')
for _,name in ipairs({'Trade','General','LookingForGroup'}) do
 showed,hidden=event(name,'4. '..name)
 assert(showed==1 and hidden==0,name..' must pass and must not count')
end
showed,hidden=event('World','4. Trade')
assert(showed==1 and hidden==0,'Conflicting channel metadata must fail open')
W.db.filterLFG=false
showed,hidden=event('World','4. World')
assert(showed==1 and hidden==0,'LFG toggle must disable this new detection')
print('PASS v0.3.22 scheduled PUG demand: '..#ads..' ads + '..#chats..' chats at all modes; World/Trade isolation')
