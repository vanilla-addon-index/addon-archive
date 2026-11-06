-- Optional count LF + classes/roles/Vanilla and Turtle instances and battlegrounds.
table.getn=table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function UnitName() return "Tester" end
local clock,delivered=100,0
function GetTime() return clock end
function ChatFrame_OnEvent() delivered=delivered+1 end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
WorldChatFilterDB={enabled=true,filterGuild=true,filterLFG=true,
filterServices=true,filterTrade=true,filterRepeats=false,sensitivity="balanced"}
for _,f in ipairs({"Core.lua","Statistics.lua","Classifier.lua","Filter.lua"}) do dofile(f) end
WorldChatFilter.Initialize()
local W=WorldChatFilter
local ads={"LF4 RAZORFEN KRAUL","LF RAZORFEN KRAUL","LF 4 RAZORFEN KRAUL","LF RFK","LF 3 TANK","LF DPS","LF 1 rogue","LF pala","LF rdps","LF 2 hunter for Mara","LF Stockades","LF Onyxia","LF BWL","LF WSG","LF BG","LF Crescent Grove","LF Hateforge Quarry","LF Stormwrought Ruins","LF Karazhan Crypt","LF Black Morass","LF Lower Karazhan Halls","LF KARA10","LF Emerald Sanctum","LF Tower of Karazhan","LF Timbermaw Hold","LF SGV","LF Thorn Gorge","LF4 RFK","LF AV","LF 2 Druid"}
local chats={"I completed Razorfen Kraul yesterday","What does LF4 RFK mean?","What does LF RAZORFEN KRAUL mean?","LF another idea","LF some advice about my build","LF friendship","LF unknown activity","Our guild completed Crescent Grove","The new battleground is fun"}
for _,mode in ipairs({"careful","balanced","aggressive"}) do
 W.db.sensitivity=mode
 for _,msg in ipairs(ads) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(blocked and cat=="LFG",mode.." missed "..msg.." "..tostring(cat).." "..tostring(score).." "..tostring(why))
 end
 for _,msg in ipairs(chats) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(not blocked,mode.." false positive "..msg.." "..tostring(cat).." "..tostring(score).." "..tostring(why))
 end
end
W.db.sensitivity="balanced"
local function event(msg,chan)
 clock=clock+1
 arg1,arg2,arg4,arg7,arg9=msg,"OtherPlayer","4. "..chan,7,chan
 local before,stat=delivered,W.GetStats().total
 ChatFrame_OnEvent("CHAT_MSG_CHANNEL")
 return delivered-before,W.GetStats().total-stat
end
for _,msg in ipairs({ads[1],ads[2],ads[4],ads[15]}) do
 local shown,count=event(msg,"World")
 assert(shown==0 and count==1,"World LFG ad must hide")
 for _,chan in ipairs({"Trade","General","Guild","LookingForGroup","Party"}) do
  shown,count=event(msg,chan)
  assert(shown==1 and count==0,"Incorrect non-World filtering: "..chan)
 end
end
W.db.filterLFG=false
local shown,count=event(ads[1],"World")
assert(shown==1 and count==0,"LFG toggle must allow")
print("PASS LF optional count: "..#ads.." ads, "..#chats.." ordinary chats, World-only")
