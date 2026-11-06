-- Regression: "LF JC [item]" Jewelcrafting request from World chat.
-- Professions use request context, not a blanket blacklist of "JC" or item names.
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
local ads={
 'LF JC [Deep Sapphire Circlet]',
 'LF JC |cff0070dd|Hitem:12345:0:0:0|h[Deep Sapphire Circlet]|h|r',
 'LF JC',
 'LF JC?',
 'lf jc [Deep Sapphire Circlet] for mats + tip',
 'LF jewelcrafter [Deep Sapphire Circlet]',
 'LF Jewelcrafting',
 'LF jeweler [Deep Sapphire Circlet]',
 'Looking for a jewelcrafter',
 'Looking for jc to craft me a necklace',
 'JC LFW crafting jewelry /w me',
}
-- Standalone item links and mentions of JC should remain visible.
local ordinary={
 'JC is a nice profession',
 'I just learned Jewelcrafting',
 'Is JC better than enchanting?',
 'My friend is a jeweler',
 'What can I make with Deep Sapphire Circlet?',
 'I love [Deep Sapphire Circlet]',
 'Does anyone know where the Jewelcrafting trainer is?',
 'JC LFW means I can craft jewelry, right?', -- choose whether chat penalty suffices
}
for _,mode in ipairs({'careful','balanced','aggressive'}) do
 W.db.sensitivity=mode
 for _,msg in ipairs(ads) do
   local cat,score,why,blocked=W.ClassifyMessage(msg)
   assert(blocked and cat=='Services',mode..' missed JC request: '..msg..' cat='..tostring(cat)..' score='..tostring(score)..' why='..tostring(why))
 end
 for _,msg in ipairs(ordinary) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(not blocked,mode..' false positive: '..msg..' cat='..tostring(cat)..' score='..tostring(score)..' why='..tostring(why))
 end
end
local itemOnly='|cff0070dd|Hitem:12345:0:0:0|h[Deep Sapphire Circlet]|h|r'
local _,_,_,itemBlocked=W.ClassifyMessage(itemOnly)
assert(not itemBlocked,'Item links alone must remain visible')
W.db.sensitivity='balanced'
local function deliver(msg,ch)
 now=now+1
 arg1,arg2,arg4,arg7,arg9=msg,'OtherPlayer','4. '..ch,7,ch
 local seen,prev=delivered,W.GetStats().total
 ChatFrame_OnEvent('CHAT_MSG_CHANNEL')
 return delivered-seen,W.GetStats().total-prev
end
for _,msg in ipairs({'LF JC [Deep Sapphire Circlet]','LF JC'}) do
 local shown,count=deliver(msg,'World')
 assert(shown==0 and count==1,'World profession request must hide exactly once')
 for _,ch in ipairs({'Trade','General','LookingForGroup','Guild','Party'}) do
  shown,count=deliver(msg,ch)
  assert(shown==1 and count==0,'Other channel must pass: '..ch)
 end
end
W.db.filterServices=false
local shown,count=deliver('LF JC [Deep Sapphire Circlet]','World')
assert(shown==1 and count==0,'Services toggle must be respected')
print('PASS JC/crafting requests: '..(#ads)..' ads and '..#ordinary..' ordinary samples x3; World-only/toggle/stats')
