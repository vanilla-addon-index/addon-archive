table.getn=table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
function UnitName() return 'Tester' end
local now = 123
function GetTime() return now end
local delivered=0
function ChatFrame_OnEvent() delivered=delivered+1 end
WorldChatFilterDB={enabled=true,filterTrade=true,sensitivity='balanced'}
local root=''
for _,f in ipairs({'Core.lua','Statistics.lua','Classifier.lua','Filter.lua'}) do dofile(root..f) end
WorldChatFilter.Initialize()
local W=WorldChatFilter
local ads={
'SELLING FISH [Stonescale Eel][Lightning Eel][Oily Blackmouth]',
'SELLING FISH',
'Selling fish PST',
'SELLING [Stonescale Eel] [Lightning Eel]',
'Selling fresh fish stacks for 2g each',
'SELLING RARE MATERIALS /w me',
'Selling herbs cheap whisper',
'SELLING [Some Made Up Trinket] 30g PST',
'Selling stacks of mithril bars',
'SELLING! [Lightning Eel] /w me',
'WTS [Stonescale Eel] for 2g',
}
local chat={
'Selling fish is actually more profitable than farming mobs.',
'Selling fish on the auction house is a pain.',
'Selling items was the only fun thing about yesterday.',
'Selling fish? Is there any demand?',
'Selling is hard when everyone undercuts you.',
'What does selling fish mean?',
'I was selling fish in Stormwind yesterday.',
'Selling fish made me rich yesterday.',
'Anyone know if selling fish is profitable?',
'Selling my gear would be a terrible idea.',
'Selling fish for gold is better than quests.',
'Why are people selling so much fish?',
'SELLING? I just meant trading, not buying.',
'Just caught Stonescale Eel, what do I cook?',
}
for _,mode in ipairs({'careful','balanced','aggressive'}) do
 W.db.sensitivity=mode
 for _,m in ipairs(ads) do
  local cat,score,why,blocked=W.ClassifyMessage(m)
  assert(blocked and (cat=='Trade' or cat=='Services'), 'ad should be blocked '..mode..' '..m..' WHY '..tostring(why))
 end
 for _,m in ipairs(chat) do
  local cat,score,why,blocked=W.ClassifyMessage(m)
  assert(not blocked, 'normal chat should show '..mode..' '..m..' WHY '..tostring(why))
 end
end
local msg=ads[1]
local beforeTotal = W.GetStats().total
local function send(channel,decorated,event)
 now=now+1
 arg1,arg2,arg4,arg7,arg8,arg9=msg,'AnotherPlayer',decorated,6,4,channel
 local old=delivered
 ChatFrame_OnEvent(event or 'CHAT_MSG_CHANNEL')
 return delivered-old
end
assert(send('World','4. World')==0)
assert(W.GetStats().total==beforeTotal+1)
for _,v in ipairs({{'Trade','2. Trade'},{'General - Elwynn Forest','1. General - Elwynn Forest'},{'LookingForGroup','3. LookingForGroup'}}) do
 assert(send(v[1],v[2])==1)
end
assert(send('World','4. World','CHAT_MSG_SAY')==1)
assert(W.GetStats().total==beforeTotal+1)
print('PASS 11 ads and 14 normal chats x3, Trade isolation, World-only stats')
