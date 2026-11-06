-- Swedish tagged guild welcome/activities regression (Vanilla Lua 5.0).
-- No blacklisted player/guild names. Exclude discussion and other channels.
table.getn=table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function UnitName() return "Tester" end
local now,delivered=100,0
function GetTime() return now end
function ChatFrame_OnEvent() delivered=delivered+1 end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
WorldChatFilterDB={
  enabled=true,filterGuild=true,filterLFG=true,filterTrade=true,
  filterServices=true,filterRepeats=false,sensitivity="balanced"
}
for _,f in ipairs({"Core.lua","Statistics.lua","Classifier.lua","Filter.lua"}) do dofile(f) end
local W=WorldChatFilter
W.Initialize()

local advertisements={
  "<Fika>, allt från dadgamers till TrueNerds. Levla, chilla eller raida? Alla är välkomna!",
  "<Northern Lanterns>, allt fran casuals till hardcore. Levla eller raida? Alla ar valkomna!",
  "<New Dawn> Alla är välkomna att levla och chilla!",
  "<Pine Owls> Vi söker fler! Vill du raida eller levla med oss?",
  "<The Harbor> Vi rekryterar! Levla, chilla eller raida med oss.",
  "Guild <Evening Crew> — Vi söker fler. Vill du raida?",
}
local nonAdvertisements={
  'Vad betyder "Alla är välkomna"?',
  '<Fika> står i Stormwind. Vad betyder "Alla är välkomna att levla eller raida?"',
  'Jag hörde att <Fika> säger att alla är välkomna att raida.',
  'Guild <Fika> skrev att alla är välkomna att raida.',
  'Jag läste att <Fika> sa att alla är välkomna att levla och chilla.',
  'Vi raidar med <Fika> ikväll. Det var kul!',
  'Jag vill levla, chilla eller raida! Någon som vill hänga?',
  'Alla är välkomna att chilla i Stormwind.',
  '<Fika> Alla är välkomna.',
  'Hej <Fika>, vill du hjälpa mig att levla?',
  'Å, Ä och Ö är vanliga svenska bokstäver.',
}

for _,mode in ipairs({"careful","balanced","aggressive"}) do
  W.db.sensitivity=mode
  for _,msg in ipairs(advertisements) do
    local cat,score,why,blocked,threshold=W.ClassifyMessage(msg)
    assert(blocked and cat=="Guild" and score>=threshold,
      mode.." MISSED Swedish guild invitation: "..msg..
      " cat="..tostring(cat).." score="..tostring(score)..
      " threshold="..tostring(threshold).." why="..tostring(why))
  end
  for _,msg in ipairs(nonAdvertisements) do
    local cat,score,why,blocked=W.ClassifyMessage(msg)
    assert(not blocked,mode.." FALSE POSITIVE: "..msg..
      " cat="..tostring(cat).." score="..tostring(score)..
      " why="..tostring(why))
  end
end

W.db.sensitivity="balanced"
local function event(msg,channel,source)
  now=now+1
  arg1,arg2,arg4,arg7,arg9=msg,source or "OtherPerson","4. "..channel,7,channel
  local before,counts=delivered,W.GetStats().total
  ChatFrame_OnEvent("CHAT_MSG_CHANNEL")
  return delivered-before,W.GetStats().total-counts
end

local original=advertisements[1]
local shown,count=event(original,"World")
assert(shown==0 and count==1,"Swedish guild advertisement should hide in World")
local session,lifetime=W.GetStats()
assert(session.Guild==1 and lifetime.Guild==1,
       "Swedish recruitment must count under the Guild category")

for _,channel in ipairs({"Trade","General","LookingForGroup","Guild","Party","Raid","Whisper"}) do
  shown,count=event(original,channel)
  assert(shown==1 and count==0,"Must never filter non-World channel: "..channel)
end
for _,msg in ipairs({nonAdvertisements[2],nonAdvertisements[3],nonAdvertisements[7]}) do
  shown,count=event(msg,"World")
  assert(shown==1 and count==0,"Ordinary Swedish conversation hidden from World: "..msg)
end

W.db.filterGuild=false
shown,count=event(advertisements[2],"World")
assert(shown==1 and count==0,"Guild category toggle must allow Swedish promotions")
W.db.filterGuild=true
W.db.enabled=false
shown,count=event(advertisements[3],"World")
assert(shown==1 and count==0,"Global OFF must allow Swedish promotions")
W.db.enabled=true
shown,count=event(advertisements[4],"World","Tester")
assert(shown==1 and count==0,"Own Swedish World message must not be hidden")
print("PASS Swedish tagged guild advertisements: "..#advertisements..
      " ads, "..#nonAdvertisements.." neutral samples x3, World-only/toggle/category/own-message safety")
