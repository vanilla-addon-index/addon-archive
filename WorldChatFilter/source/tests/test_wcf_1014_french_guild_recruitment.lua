-- French guild recruitment regression: tagged and named guild player calls.
-- Exercises the exact /World example and harmless conversations on all modes.
-- Built for the Vanilla 1.12 Lua 5.0 API (run under Lua 5.1 in CI).
table.getn=table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function UnitName() return "Tester" end
local now,delivered=100,0
function GetTime() return now end
function ChatFrame_OnEvent() delivered=delivered+1 end
function CreateFrame()
 return {RegisterEvent=function() end,SetScript=function() end}
end
WorldChatFilterDB={
 enabled=true,filterGuild=true,filterLFG=true,
 filterTrade=true,filterServices=true,filterRepeats=false,
 sensitivity="balanced"
}
for _,path in ipairs({"Core.lua","Statistics.lua","Classifier.lua","Filter.lua"}) do
 dofile(path)
end
local W=WorldChatFilter
W.Initialize()

local advertisements={
 "<Ost Ardent > (FR°°°) Recrute tout joueur désirant découvrir le contenu qu'offre Octo (MC & Ony clean) Nous sommes ouverts aux joueurs en lvling.",
 "<Les Hirondelles> (FR) Recrute tout joueur qui souhaite découvrir Octo, MC et Ony. Nous sommes ouverts aux joueurs en leveling.",
 "<Le Havre> Recrutons des joueurs pour MC et Ony. Débutants bienvenus!",
 "Guilde <Les Etoiles> recherche des membres pour raids MC et progression PVE.",
 "<Montagne> Nous sommes ouverts aux joueurs en lvling sur Octo!",
 "<Le Dragon> Accueillons les nouveaux joueurs pour raids MC et Ony.",
 "<Soleil> Nous acceptons les débutants pour PVE et raids sur Octo.",
 "<Vallee> Recrutement de joueurs, raid MC, contenu Octo, venez nous rejoindre.",
 "<La Clairiere> Rejoignez notre guilde! Tous les joueurs bienvenus pour les raids.",
}
local ordinary={
 "<Ost Ardent> fait MC ce soir, vous venez?",
 "MC & Ony clean! Bravo a tous!",
 "<Le Havre> est une guilde avec de nombreux joueurs sur Octo.",
 "Recrute tout joueur pour une partie d'echecs, pas WoW.",
 "<La Clairiere> et ses joueurs parlent de la dernière mise à jour d'Octo.",
 "Que signifie 'Recrute tout joueur désirant découvrir le contenu qu'offre Octo'?",
 "J'ai lu que <Ost Ardent> recrute tout joueur pour MC sur Octo.",
 "On m'a dit que <Le Havre> recrute des joueurs pour MC.",
 "Hier la guilde <Les Etoiles> cherchait des joueurs pour Ony.",
 "<Montagne> Nous sommes ouverts aux discussions sur les raids.",
 "<La Clairiere> Nous sommes ouverts aux joueurs qui souhaitent discuter de leveling?",
 "La guilde <Le Havre> ne recrute pas de joueurs sur Octo.",
 "Est-ce que <Le Dragon> recrute des joueurs pour MC?",
 "Une guilde discute de nouveaux joueurs lors d'un tournoi d'echecs.",
 "Le message dit que <Ost Ardent> recrute des joueurs pour MC.",
 "Un joueur recrute son ami pour un jeu de cartes.",
}
for _,mode in ipairs({"careful","balanced","aggressive"}) do
 W.db.sensitivity=mode
 for _,msg in ipairs(advertisements) do
  local category,score,why,blocked,threshold=W.ClassifyMessage(msg)
  assert(blocked and category=="Guild" and score>=threshold,
   mode.." missed French guild recruitment: "..msg..
   " category="..tostring(category).." score="..tostring(score)..
   " threshold="..tostring(threshold).." reasons="..tostring(why))
 end
 for _,msg in ipairs(ordinary) do
  local category,score,why,blocked=W.ClassifyMessage(msg)
  assert(not blocked,mode.." false positive French chat: "..msg..
    " category="..tostring(category).." score="..tostring(score)..
    " reasons="..tostring(why))
 end
end
W.db.sensitivity="balanced"
local function event(msg,channel,author)
 now=now+1
 arg1,arg2,arg4,arg7,arg9=msg,author or "OtherPlayer","4. "..channel,7,channel
 local oldShown,oldCount=delivered,W.GetStats().total
 ChatFrame_OnEvent("CHAT_MSG_CHANNEL")
 return delivered-oldShown,W.GetStats().total-oldCount
end

local shown,count=event(advertisements[1],"World")
assert(shown==0 and count==1,"French recruitment should hide only from World")
local session,total=W.GetStats()
assert(session.Guild==1 and total.Guild==1,
 "French recruitment must be counted as Guild exactly once")
for _,channel in ipairs({"Trade","General","LookingForGroup","Guild","Party","Raid","Whisper"}) do
 shown,count=event(advertisements[1],channel)
 assert(shown==1 and count==0,"wrongly hidden non-World channel "..channel)
end
for _,message in ipairs({ordinary[6],ordinary[7],ordinary[13]}) do
 shown,count=event(message,"World")
 assert(shown==1 and count==0,"wrongly filtered French discussion in World")
end
W.db.filterGuild=false
shown,count=event(advertisements[2],"World")
assert(shown==1 and count==0,"Guild filtering OFF must not hide French recruitment")
W.db.filterGuild=true
W.db.enabled=false
shown,count=event(advertisements[3],"World")
assert(shown==1 and count==0,"Master OFF must not hide French recruitment")
W.db.enabled=true
shown,count=event(advertisements[4],"World","Tester")
assert(shown==1 and count==0,"Own World message must never be hidden")
print("PASS French guild recruitment: "..#advertisements.." ads and "..
      #ordinary.." ordinary samples x3; World-only, toggles and own message")
