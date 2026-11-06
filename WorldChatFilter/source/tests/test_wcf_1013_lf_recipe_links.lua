-- Regression: LF + crafted recipe/enchant links, including missing whitespace.
table.getn = table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function UnitName() return "Tester" end
local now, delivered = 100, 0
function GetTime() return now end
function ChatFrame_OnEvent() delivered=delivered+1 end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
WorldChatFilterDB={enabled=true,filterGuild=true,filterLFG=true,filterServices=true,
 filterTrade=true,filterRepeats=false,sensitivity="balanced"}
for _,f in ipairs({"Core.lua","Statistics.lua","Classifier.lua","Filter.lua"}) do dofile(f) end
WorldChatFilter.Initialize()
local W=WorldChatFilter
local serviceAds={"LF[Enchant Weapon - Spell Power]",
 "LF [Enchant Weapon - Spell Power]",
 "lf[Enchant Weapon - Spell Power]",
 "LF1[Enchant Weapon - Spell Power]",
 "LF 2 [Enchant Weapon - Spell Power]",
 "LF|cffffffff|Henchant:22749|h[Enchant Weapon - Spell Power]|h|r",
 "LF |cffffffff|Henchant:22749|h[Enchant Weapon - Spell Power]|h|r",
 "LF|cffffffff|Henchant:12345|h[Spell Power]|h|r",
 "LF |cff71d5ff|Hspell:22749|h[Enchant Weapon - Spell Power]|h|r",
 "LF|cff0070dd|Hitem:18259:0:0:0|h[Formula: Enchant Weapon - Spell Power]|h|r",
 "LF |cff0070dd|Hitem:99999:0:0:0|h[Pattern: Spidersilk Boots]|h|r",
 "LF[Recipe: Swiftness Potion]",
 "LF [Plans: Arcanite Reaper]",
 "LF[Schematic: Gnomish Death Ray]",
 "LF [Design: Ring of Example]",
 "LF[Transmute: Arcanite]",
 "LF |cff71d5ff|Htrade:1234|h[Engineering]|h|r",
 "LF |cff71d5ff|Htradeskill:1234|h[Blacksmithing]|h|r",
 "LF [Enchant Weapon - Spell Power] pst"}
local ordinary={"Anyone know who can make [Enchant Weapon - Spell Power]?",
 "What does LF[Enchant Weapon - Spell Power] mean?",
 "How did you learn [Enchant Weapon - Spell Power]?",
 "I just learned |cffffffff|Henchant:22749|h[Enchant Weapon - Spell Power]|h|r",
 "|cffffffff|Henchant:22749|h[Enchant Weapon - Spell Power]|h|r",
 "LF recipe advice",
 "LF enchant advice",
 "I linked [Pattern: Spidersilk Boots] earlier",
 "LF[Something unrelated]"}
local tradeAds={"LF |cff0070dd|Hitem:123|h[Mithril Bar]|h|r",
 "LF [Mithril Bar]"}
for _,mode in ipairs({"careful","balanced","aggressive"}) do
 W.db.sensitivity=mode
 for _,msg in ipairs(serviceAds) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(blocked and cat=="Services",mode.." missed recipe: "..msg.." => "..tostring(cat).." "..tostring(score).." "..tostring(why))
 end
 for _,msg in ipairs(ordinary) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(not blocked,mode.." false positive: "..msg.." => "..tostring(cat).." "..tostring(score).." "..tostring(why))
 end
 for _,msg in ipairs(tradeAds) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(blocked and cat=="Trade",mode.." missed item link: "..msg.." => "..tostring(cat).." "..tostring(score))
 end
end
W.db.sensitivity="balanced"
local function event(msg,base)
 now=now+1
 arg1,arg2,arg4,arg7,arg9=msg,"OtherPerson","4. "..base,7,base
 local before,count=delivered,W.GetStats().total
 ChatFrame_OnEvent("CHAT_MSG_CHANNEL")
 return delivered-before,W.GetStats().total-count
end
for _,msg in ipairs({serviceAds[1],serviceAds[6],serviceAds[10]}) do
 local shown,count=event(msg,"World")
 assert(shown==0 and count==1,"craft LF must be hidden once in World: "..msg)
 for _,ch in ipairs({"Trade","General","Guild","LookingForGroup","Party"}) do
  shown,count=event(msg,ch)
  assert(shown==1 and count==0,"non-World channel filtered: "..ch)
 end
end
W.db.filterServices=false
for _,msg in ipairs({serviceAds[1],serviceAds[6],serviceAds[10]}) do
 local cat,score,why,blocked=W.ClassifyMessage(msg)
 assert(not blocked,"Services disabled should allow recipe request: "..msg.." ("..tostring(cat)..")")
 local shown,count=event(msg,"World")
 assert(shown==1 and count==0,"Services disabled should not hide World request")
end
print("PASS LF recipe links: "..#serviceAds.." services, "..#ordinary.." normal, "..#tradeAds.." Trade x3 + channels/toggle")
