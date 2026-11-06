table.getn=table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
function UnitName() return 'Tester' end
local now,delivered=10,0
function GetTime() return now end
function ChatFrame_OnEvent() delivered=delivered+1 end
WorldChatFilterDB={enabled=true,sensitivity='balanced'}
local root=''
for _,f in ipairs({'Core.lua','Statistics.lua','Classifier.lua','Filter.lua'}) do dofile(root..f) end
WorldChatFilter.Initialize()
local w=WorldChatFilter
assert(w.VERSION=='1.1.2')
local ads={
 'T A X I 3Gold: Hyjal + Waterlords + Silithus + Everlook + Tanaris + Ratchet + EPL/Stratholme + DireMaul + Booty Bay + BlackRockMountain',
 'T.A.X.I 3Gold: Hyjal + Waterlords + Silithus + Everlook',
 'T-A-X-I 3Gold: Hyjal + Waterlords + Silithus + Everlook',
 'TAXI 3Gold: Hyjal + Waterlords + Silithus + Everlook',
 'TAXI 3g: Everlook, Silithus, Ratchet, Tanaris, Booty Bay /w for rides',
 'TAXI 4g PST',
 'T A X I : Booty Bay + Silithus + Tanaris + Everlook + Ratchet',
 'TAXI SERVICES 2gold available to Booty Bay',
 'Taxi runs to Booty Bay + Gadgetzan + Dire Maul + Orgrimmar for 5g',
}
local chats={
 'What is T A X I 3Gold: Hyjal + Silithus + Tanaris + Everlook?',
 'What does TAXI mean in World chat?',
 'I heard TAXI 3Gold: Hyjal + Silithus + Everlook + Ratchet',
 'T A X I are letters separated by spaces',
 'Do people really pay 3gold for taxi service?',
 'Taxi to Silithus was a silly idea yesterday',
 'I hate TAXI 3gold ads: Hyjal + Silithus + Ratchet + Everlook',
 'The taxi was expensive, but I got to Booty Bay',
 'Anyone know how the taxi advertisements work?',
 'The T A X I word reminds me of real taxis',
 'Are there taxis in Azeroth?',
 'The spells are Taxi Driver and Summon Water Elemental, right?',
}
for _,mode in ipairs({'careful','balanced','aggressive'}) do
 w.db.sensitivity=mode
 for _,msg in ipairs(ads) do
  local cat,score,why,blocked=w.ClassifyMessage(msg)
  assert(blocked and cat=='Services', 'miss '..mode..' '..msg..' '..tostring(cat)..':'..tostring(score)..' '..tostring(why))
 end
 for _,msg in ipairs(chats) do
  local cat,score,why,blocked=w.ClassifyMessage(msg)
  assert(not blocked, 'false positive '..mode..' '..msg..' '..tostring(cat)..':'..tostring(score)..' '..tostring(why))
 end
end
local message=ads[1]
local function event(base,decorated,kind)
 now=now+1
 local was=delivered
 arg1,arg2,arg4,arg7,arg9=message,'Someone',decorated,7,base
 ChatFrame_OnEvent(kind or 'CHAT_MSG_CHANNEL')
 return delivered-was
end
local initial=w.GetStats().total
assert(event('World','4. World')==0, 'World ad not hidden')
assert(w.GetStats().total==initial+1,'World statistics did not increment')
assert(event('Trade - City','5. Trade - City')==1, 'Trade was filtered')
assert(event('General - Stormwind City','1. General - Stormwind City')==1, 'General was filtered')
assert(event('LookingForGroup','3. LookingForGroup')==1, 'LFG channel was filtered')
assert(event('World','4. World','CHAT_MSG_SAY')==1, 'SAY was filtered')
assert(w.GetStats().total==initial+1, 'non-World incremented statistics')
print('PASS taxi: '..#ads..' ad variants, '..#chats..' chat negatives across 3 modes, World only isolation')
