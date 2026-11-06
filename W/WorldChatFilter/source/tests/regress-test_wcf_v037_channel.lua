table.getn = table.getn or function(t) return #t end
SlashCmdList = {}
local mock={now=10, delivered=0, printed={}}
DEFAULT_CHAT_FRAME = {AddMessage=function(self,t) table.insert(mock.printed,t) end}
function CreateFrame() return {RegisterEvent=function() end, SetScript=function() end} end
function GetTime() return mock.now end
function UnitName() return 'MyCharacter' end
function ChatFrame_OnEvent(evt) mock.delivered=mock.delivered+1 end
WorldChatFilterDB={sensitivity='aggressive', enabled=true}
local root=''
dofile(root..'Core.lua')
dofile(root..'Statistics.lua')
dofile(root..'Classifier.lua')
dofile(root..'Filter.lua')
WorldChatFilter.Initialize()
local WCF=WorldChatFilter
assert(WCF.VERSION=='1.1.2')
local spam='WTS Arcanum of Rapidity 55G LEGS/HEAD ENCHANT'
local lf='LFM ZG12 - Need OT and 1x Heal - 1SR>MS>OS'
local tg='One of Turtle WoW top speedrun guilds, now looking for Mages/Shamans/Warlocks for our main rooster! https://discord.gg/99VREUC4P for more information!'
local chatter='Anyone else just enjoying the music in Westfall?'
for _,msg in ipairs({spam,lf,tg,'LFM BM rep farm tank only','LF3M Scholo need all 58+'}) do
 local cat,score,why,blocked=WCF.ClassifyMessage(msg)
 assert(blocked,'classifier failed baseline: '..msg)
end
local function event(msg,baseName,decorated,zoneID,evt,time)
 mock.now=time or mock.now+1
 arg1, arg2, arg4, arg7, arg9=msg,'OtherPlayer',decorated,zoneID,baseName
 local old=mock.delivered
 ChatFrame_OnEvent(evt or 'CHAT_MSG_CHANNEL')
 return mock.delivered-old
end
local cases={
 {nil, '5. World', 2, true},
 {'World', '4. World', 0, true},
 {'world', '5. World', 2, true},
 {'World', '6. World', 5, true},
 {'World', '7. World', 26, true},
 {'World', '8. Trade - City', 0, false},
 {'Trade - City', '8. World', 0, false},
 {'Trade - City','2. Trade - City',2,false},
 {'General - Stormwind City','1. General - Stormwind City',1,false},
 {'LookingForGroup','3. LookingForGroup',26,false},
 {'WorldDefense','6. WorldDefense',23,false},
 {'World Chat','7. World Chat', 0,false},
 {nil,'2. Trade - City',nil,false},
 {nil,nil,0,false},
}
local initial=WCF.GetStats().total
for _,case in ipairs(cases) do
 local world=case[4]
 assert(WCF.IsWorldChannel(case[1],case[2],case[3])==world, 'gating wrong '..tostring(case[2]))
 local delivered=event(spam,case[1],case[2],case[3])
 assert(delivered == (world and 0 or 1),'wrong delivery '..tostring(case[2])..' zone='..tostring(case[3]))
end
assert(WCF.GetStats().total==initial+5,'stats should record only World traffic')
-- Every category of advertised spam must be allowed when in Trade.
for _,m in ipairs({spam,lf,tg}) do
 assert(event(m,'Trade - City','2. Trade - City',2)==1, 'filtered Trade: '..m)
 assert(event(m,'World','4. World',7)==0, 'not filtered World: '..m)
end
assert(event(chatter,'World','4. World',7)==1,'filtered normal World chatter')
assert(event(spam,'World','4. World',7,'CHAT_MSG_SAY')==1,'filtered non-channel event')
-- Diagnostic mode never logs content/player names and does not bypass the filter.
SlashCmdList.WORLDCHATFILTER('channeldebug')
assert(WCF.channelDebug == true)
local before=#mock.printed
assert(event(spam,'World','4. World',27)==0)
assert(#mock.printed>before)
local found=false
for _,s in ipairs(mock.printed) do
 if string.find(s,'Channel metadata:',1,true) then
  found=true
  assert(not string.find(s,spam,1,true))
  assert(not string.find(s,'OtherPlayer',1,true))
 end
end
assert(found)
SlashCmdList.WORLDCHATFILTER('channeldebug')
assert(WCF.channelDebug == false)
print('v0.3.7 channel gate, live hook, Trade isolation, stats and diagnostics PASS')
