-- Regressions: German social-guild invitations and Polish explicit guild
-- recruitment without player nouns. No guild/player name blacklists.
-- Lua 5.0 compatible; mocked Vanilla World-only chat routing.
table.getn=table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function UnitName() return "Tester" end
local now,shown=100,0
function GetTime() return now end
function ChatFrame_OnEvent() shown=shown+1 end
function CreateFrame()
 return {RegisterEvent=function() end,SetScript=function() end}
end
WorldChatFilterDB={
 enabled=true,filterGuild=true,filterLFG=true,filterTrade=true,
 filterServices=true,filterRepeats=false,sensitivity="balanced"
}
for _,file in ipairs({"Core.lua","Statistics.lua","Classifier.lua","Filter.lua"}) do dofile(file) end
local W=WorldChatFilter
W.Initialize()

local germanAds={
 "<Bananenrepublik> Lust auf Community statt Einzelkampf? Entspannte deutsche Gilde auf OctoWoW, wir helfen uns beim Leveln und planen später gemütliche Raids. Casuals willkommen, kein Stress, kein Hardcore. Melde dich per PM!",
 "<Abendstern> Deutsche Gilde auf OctoWoW. Gemeinsam leveln und gemütlich raiden. Schreib uns für eine Einladung!",
 "<Waldlicht> Lust auf eine entspannte Gilde? Wir helfen beim Leveln, Raids sind geplant. Meldet euch per PN!",
 "<Nordwind> Wir sind eine soziale Gilde für Casuals. Gemeinsame Raids und Leveln, schreib uns eine PM!",
 "<Morgenrot> Deutsche Community auf OctoWoW, wir machen Raids und nehmen neue Spieler auf. Melde dich bei uns!",
 "<Mondfels> Entspannte Gilde, casuals willkommen, wir helfen beim leveln. Schreib mir für mehr Infos.",
 "<Wolken> Wir suchen Mitspieler für unsere Gilde auf OctoWoW, gemeinsame Raids, bitte PM!",
 "<Steinwald> Du suchst eine lockere Gilde? Wir raiden und leveln zusammen. Meld dich per Whisper.",
}
local polishAds={
 "Polska gildia Chlopaki z Barrensow rekrutuje. Od zera do niskiej klasy sredniej - i to w 60 lvli. Robimy wszystkie dostepne rajdy. Bober kurwa",
 "Polska gildia Nowy Brzeg rekrutuje! Robimy wszystkie dostępne rajdy.",
 "Gildia Bursztynowi rekrutuje, chodzimy na rajdy MC i BWL.",
 "<Srebrny Szlak> Polska gildia rekrutuje na rajdy PvE.",
 "Gildia Zielona Dolina poszukuje. Gramy razem na Turtle, robimy rajdy.",
 "Polska gildia przyjmuje nowych, organizujemy raidy na 60 lvl.",
 "Gildia Zachodni Wiatr rekrutuje, gramy wspólnie na Azeroth i robimy wszystkie rajdy.",
 "<Północ> Nasza gildia rekrutuje. MC, Ony i wspólny progres.",
}
local germanChat={
 "<Bananenrepublik> ist eine Gilde auf OctoWoW. Wir leveln heute.",
 "Lust auf Community statt Einzelkampf? Welche Gilde könnt ihr empfehlen?",
 "Casuals willkommen? Wie funktioniert das auf OctoWoW?",
 "Melde dich per PM, ich erkläre dir die Quest in Westfall.",
 "<Nordwind> plant später gemütliche Raids. Viel Erfolg!",
 "Gestern habe ich gelesen, dass <Abendstern> eine deutsche Gilde ist. Melde dich per PM stand im Text.",
 "Was bedeutet 'Melde dich per PM' in einer Gildenwerbung für Raids?",
 "Ich habe gehört, <Waldlicht> sucht Spieler, meldet euch per PN stand in der Anzeige.",
 "Die Gilde <Wolken> will morgen leveln und raiden. Wie finde ich den Weg?",
 "Wir helfen beim Leveln. Hat jemand Fragen?",
 "Schreib uns für eine Einladung zum Schachabend, nicht für WoW.",
 "Die Gilde auf OctoWoW hat gestern Raids gemacht, keine Werbung.",
}
local polishChat={
 "Czy polska gildia Chlopaki z Barrensow rekrutuje na rajdy?",
 "Słyszałem że polska gildia rekrutuje na rajdy.",
 "Widziałem że gildia rekrutuje na raid MC, czy to prawda?",
 "Wczoraj polska gildia rekrutowała na rajdy, teraz już nie.",
 "Gildia w moim mieście rekrutuje do turnieju szachowego, nie do WoW.",
 "Polska gildia gra na Turtle, robimy wszystkie rajdy.",
 "Robimy wszystkie dostępne rajdy, ale nikogo nie szukamy.",
 "Gildia Chlopaki z Barrensow jest fajna, robimy z nimi rajdy.",
 "Polska gildia rekrutuje do gry w planszówki, nie WoW.",
 "Czy ktoś wie kiedy gildia zaczyna wszystkie dostępne rajdy?",
 "Co znaczy 'gildia rekrutuje na rajdy'?",
 "Widziałem ogłoszenie: gildia rekrutuje, robimy wszystkie rajdy.",
}

for _,mode in ipairs({"careful","balanced","aggressive"}) do
 W.db.sensitivity=mode
 for _,item in ipairs({{name="German",ads=germanAds},{name="Polish",ads=polishAds}}) do
  for _,msg in ipairs(item.ads) do
   local cat,score,why,blocked,threshold=W.ClassifyMessage(msg)
   assert(blocked and cat=="Guild" and score>=threshold,
     mode.." MISSED "..item.name.." ad: "..msg..
     " category="..tostring(cat).." score="..tostring(score)..
     " threshold="..tostring(threshold).." why="..tostring(why))
  end
 end
 for _,item in ipairs({{name="German",chats=germanChat},{name="Polish",chats=polishChat}}) do
  for _,msg in ipairs(item.chats) do
   local cat,score,why,blocked=W.ClassifyMessage(msg)
   assert(not blocked,mode.." FALSE POSITIVE "..item.name.." conversation: "..
     msg.." category="..tostring(cat)..
     " score="..tostring(score).." why="..tostring(why))
  end
 end
end
W.db.sensitivity="balanced"
local function event(msg,channel,author)
 now=now+1
 arg1,arg2,arg4,arg7,arg9=msg,author or "AnotherPlayer","4. "..channel,7,channel
 local oldShown,oldCount=shown,W.GetStats().total
 ChatFrame_OnEvent("CHAT_MSG_CHANNEL")
 return shown-oldShown,W.GetStats().total-oldCount
end
for _,ad in ipairs({germanAds[1],polishAds[1]}) do
 local oldShown,oldCount=shown,W.GetStats().total
 local displayed,filtered=event(ad,"World")
 assert(displayed==0 and filtered==1,"Must block guild ad in World")
 for _,channel in ipairs({"Trade","General","LookingForGroup","Guild","Party","Raid","Whisper"}) do
  displayed,filtered=event(ad,channel)
  assert(displayed==1 and filtered==0,"Must not touch non-World channel: "..channel)
 end
 for _,chat in ipairs({germanChat[1],polishChat[1]}) do
  displayed,filtered=event(chat,"World")
  assert(displayed==1 and filtered==0,"Must show normal World discussion")
 end
end
local session=W.GetStats()
assert(session.Guild==2,"Both World ads must count under Guild exactly once")
W.db.filterGuild=false
local displayed,filtered=event(germanAds[2],"World")
assert(displayed==1 and filtered==0,"Guild category OFF must show German ad")
displayed,filtered=event(polishAds[2],"World")
assert(displayed==1 and filtered==0,"Guild category OFF must show Polish ad")
W.db.filterGuild=true
W.db.enabled=false
displayed,filtered=event(germanAds[3],"World")
assert(displayed==1 and filtered==0,"Master OFF must show German ad")
displayed,filtered=event(polishAds[3],"World")
assert(displayed==1 and filtered==0,"Master OFF must show Polish ad")
W.db.enabled=true
displayed,filtered=event(germanAds[4],"World","Tester")
assert(displayed==1 and filtered==0,"Own German ad must never be hidden")
displayed,filtered=event(polishAds[4],"World","Tester")
assert(displayed==1 and filtered==0,"Own Polish ad must never be hidden")
print("PASS social German & playerless Polish guild recruitment: "..
 #germanAds.."+"..#polishAds.." ads, "..#germanChat.."+"..#polishChat..
 " chats x3; all-channel, category, master, own-message tests")
