-- Regression: Polish guild/team recruitment with or without diacritics.
-- Require multiple independent signals, never blacklist a name or isolated
-- "MC", "sobota", "progress" or a player mention. Lua 5.0 compatible.
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

local adverts={
 "<CHŁOPAKI Z BARRENSOW> rekrutują lvlujących i Raiderow do wspólnej zabawy w Azeroth. Oferujemy pomoc i luźną atmosferę. Jesteś zainteresowany? Napisz do nas!",
 "<Wschodnia Straz> Rekrutujemy lvlujacych i raiderow do wspolnej zabawy w Azeroth. Napisz do nas!",
 "<Błękitny Szlak> Rekrutują levelujących do rajdów w Azeroth, zapraszamy!",
 "Gildia <Błękitni> szuka lvlujących do gry w Azeroth, napisz do nas.",
 "<Ostatni Bastion> doswiadczona druzyna z turtla szuka osob do wspolnej gry, MC sobota 20. Loot SR+. Wspólny progres, minimalne zaangazowanie wymagane.",
 "<Przystan> doświadczona drużyna szuka osób do wspólnej gry, MC sobota 20. Loot SR+.",
 "<New Beginning> szukamy graczy do wspolnej gry, rajdy i progres na Turtle.",
 "Doświadczona drużyna poszukuje członków do wspólnego grania i raidów.",
 "<Wichry> Zapraszamy do wspólnej gry, MC oraz BWL.",
 "<Bursztyn> rekrutujemy graczy na rajdy PVE.",
 "Gildia <Brzask> szuka ludzi do wspólnego progresu w MC.",
 "Ekipa poszukuje raiderow do wspolnej gry, MC o 20.",
 "<Zmierzch> Zapraszamy na rajdy, wspolny progres i PVP.",
}
local ordinary={
 "Lubie Azeroth, a lvlujacych jest tu dzisiaj bardzo duzo.",
 "Jestes zainteresowany wspolna zabawa w planszowki? Napisz do nas!",
 "<Błękitni> oferuja pomoc i luzna atmosfere. Napisz do nas!",
 "Czy ta gildia <Wschodnia Straz> rekrutuje lvlujacych do Azeroth?",
 "Czytałem że <Błękitny Szlak> rekrutują lvlujących i Raiderow w Azeroth.",
 "Widzialem ogloszenie: <Wschodnia Straz> rekrutuja lvlujacych do Azeroth.",
 "To cytat z chatu: <Wschodnia Straz> rekrutuja raiderow do Azeroth!",
 "Gildia <Wschodnia Straz> rekrutuje graczy do gry w szachy, nie WoW.",
 "Ekipa rekrutuje graczy do planszowek, to nie WoW.",
 "<Niebiescy> rekrutuja raiderow do gry w karty, nie w WoW.",
 "MC sobota 20, a loot ma byc SR+?",
 "Jak wyglada progres w MC w sobote?",
 "<Ostatni Bastion> to ciekawa nazwa gildii.",
 "Czy <Przystan> szuka osob do wspolnej gry na MC?",
 "Słyszałem że <Przystan> szuka osób do wspólnej gry na MC.",
 "Czytałem że gildia <Brzask> szuka osób do wspólnej gry.",
 "Wczoraj <Wichry> szuka osób do wspólnej gry na MC.",
 "Co oznacza \"drużyna szuka osób do wspólnej gry, MC\"?",
 "<Ostatni Bastion> pisal cos na world?",
 "Szukam osób do pomocy z zadaniem, czy ktoś może?",
 "Drużyna grała w MC, było bardzo fajnie.",
 "Szuka osob do organizacji imprezy, nie raidu.",
 "Zapraszamy do rozmowy o MC, czy ktos pamieta stare czasy?",
 "Gram razem z przyjaciolmi. Wspolny progres jest fajny.",
 "Z jakiej gildii jest gracz <Brzask>?",
 "Druzyna szuka osob do wspolnej gry w planszowki.",
}
for _,mode in ipairs({"careful","balanced","aggressive"}) do
 W.db.sensitivity=mode
 for _,msg in ipairs(adverts) do
  local cat,score,why,blocked,threshold=W.ClassifyMessage(msg)
  assert(blocked and cat=="Guild" and score>=threshold,
   mode.." MISSED Polish guild ad: "..msg.." cat="..tostring(cat)..
   " score="..tostring(score).." why="..tostring(why))
 end
 for _,msg in ipairs(ordinary) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(not blocked,
   mode.." FALSE POSITIVE Polish ordinary chat: "..msg.." cat="..tostring(cat)..
   " score="..tostring(score).." why="..tostring(why))
 end
end
W.db.sensitivity="balanced"
local function event(message,channel,author)
 now=now+1
 arg1,arg2,arg4,arg7,arg9=message,author or "OtherPlayer","4. "..channel,7,channel
 local oldShown,oldStats=delivered,W.GetStats().total
 ChatFrame_OnEvent("CHAT_MSG_CHANNEL")
 return delivered-oldShown,W.GetStats().total-oldStats
end
local example=adverts[1]
local shown,count=event(example,"World")
assert(shown==0 and count==1,"Polish guild ad should be hidden in /World")
local session,lifetime=W.GetStats()
assert(session.Guild==1 and lifetime.Guild==1,"Polish ad should count under Guild")
for _,channel in ipairs({"Trade","General","LookingForGroup","Guild","Party","Raid","Whisper"}) do
 shown,count=event(example,channel)
 assert(shown==1 and count==0,"Polish guild ad affected non-World: "..channel)
end
for _,msg in ipairs({ordinary[4],ordinary[5],ordinary[14]}) do
 shown,count=event(msg,"World")
 assert(shown==1 and count==0,"Polish discussion was hidden in World: "..msg)
end
W.db.filterGuild=false
shown,count=event(adverts[2],"World")
assert(shown==1 and count==0,"Disabled Guild category must allow Polish advert")
W.db.filterGuild=true
W.db.enabled=false
shown,count=event(adverts[3],"World")
assert(shown==1 and count==0,"Global filter OFF must allow Polish advert")
W.db.enabled=true
shown,count=event(adverts[4],"World","Tester")
assert(shown==1 and count==0,"Own World messages must not be filtered")
print("PASS Polish guild invites: "..#adverts.." ads / "..#ordinary..
      " ordinary x3; World-only, master/Guild toggles, own messages")
