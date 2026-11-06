-- v1.1 Spanish guild showcases: roster/raid pitch + contact, no explicit recruiting verb.
-- These are *combinations*, never blacklists for guild names, raid names or Discord.
-- Vanilla Lua 5.0 mock; validates all sensitivities, channel isolation and toggles.
table.getn=table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function UnitName() return "Tester" end
local now,delivered=100,0
function GetTime() return now end
function ChatFrame_OnEvent() delivered=delivered+1 end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
WorldChatFilterDB={
 enabled=true,filterGuild=true,filterLFG=true,filterServices=true,
 filterTrade=true,filterRepeats=false,sensitivity="balanced"
}
for _,path in ipairs({"Core.lua","Statistics.lua","Classifier.lua","Filter.lua"}) do dofile(path) end
local W=WorldChatFilter
W.Initialize()

local advertisements={
 "<Bastión de Guerra> Comunidad consolidada con +390 miembros activos, social y PVE. Raids semanales de MC25, Kara10, ZG y Trash Runs con un enfoque serio pero flexible, adaptado al ritmo de todos. Discord activo con guías. /whisp para info",
 "<Niebla Serena> Comunidad consolidada con 390 miembros activos. Raids semanales de MC25, Kara10 y ZG. /whisp para info.",
 "<Los Pinos> Comunidad con miembros activos, MC25 los sábados. /wisp para info",
 "<El Faro> Hermandad con jugadores activos, PvE y Kara10 cada semana. /whisper para info",
 "<Brumas> Comunidad estable con integrantes, raids semanales. Susurro para info",
 "<Caminantes> Comunidad con 90 miembros, raids semanales y progresión PvE. /pm para info",
 "<Luz Azul> Comunidad consolidada, miembros activos y raid de ZG. Escribeme para info",
 "Nuestro gremio es una comunidad de 200 miembros con MC25 y Kara10. /whisp para info",
 "<Tigres> Comunidad de miembros activos con PVP y raids semanales. /whisp para detalles",
}
local conversations={
 "MC25, Kara10 y ZG son buenas raids para empezar.",
 "Discord activo con guías, ¿alguien puede recomendar uno?",
 "Comunidad consolidada con 390 miembros activos y raids semanales.",
 "<Alborada> comunidad consolidada con 390 miembros activos. Raids semanales de MC25 y Kara10.",
 "<Alborada> comunidad consolidada con 390 miembros activos. /whisp para info",
 "<Alborada> raids semanales de MC25 y Kara10. /whisp para info",
 "<Alborada> comunidad consolidada con 390 miembros activos. /whisp para info sobre Discord.",
 "Ayer vi que <Alborada> tiene comunidad con miembros activos, raids semanales y /whisp para info.",
 "He leído que <Alborada> es una comunidad de miembros activos, raids y /whisp para info.",
 "Me dijeron que <Alborada> tiene comunidad con miembros activos, MC25 y /whisp para info.",
 "¿Alguien sabe si <Alborada> es una comunidad con miembros activos, raids y /whisp para info?",
 "Qué significa lo de <Alborada> comunidad con miembros activos, raid y /whisp para info?",
 "El anuncio de <Alborada> dice comunidad con miembros activos, raids y /whisp para info.",
 "<Alborada> comunidad con miembros activos, PVE y /whisp para info, pero no reclutan.",
 "Nuestro guild se llama <Alborada>, llevamos meses jugando a MC25.",
 "<Alborada> comunidad de miembros activos hace una raid hoy. ¿Dónde está la entrada?",
 "Miembros activos de una comunidad, progresión en ZG y consejos para Discord.",
 "La palabra 'Kara10' no debería bloquear conversaciones.",
}
for _,mode in ipairs({"careful","balanced","aggressive"}) do
 W.db.sensitivity=mode
 for _,msg in ipairs(advertisements) do
  local cat,score,why,blocked,threshold=W.ClassifyMessage(msg)
  assert(blocked and cat=="Guild" and score>=threshold,
    mode.." leaked Spanish showcase: "..msg.." cat="..tostring(cat)..
    " score="..tostring(score).." threshold="..tostring(threshold)..
    " why="..tostring(why))
 end
 for _,msg in ipairs(conversations) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(not blocked,
    mode.." FALSE POSITIVE Spanish chat: "..msg.." cat="..tostring(cat)..
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
local shown,count=event(advertisements[1],"World")
assert(shown==0 and count==1,"Spanish guild showcase must be hidden from World")
local session,lifetime=W.GetStats()
assert(session.Guild==1 and lifetime.Guild==1,
 "Spanish showcase must increment Guild statistics exactly once")
for _,channel in ipairs({"Trade","General","LookingForGroup","Guild","Party","Raid","Whisper"}) do
 shown,count=event(advertisements[1],channel)
 assert(shown==1 and count==0,"Non-World channel wrongly filtered: "..channel)
end
for _,msg in ipairs({conversations[4],conversations[8],conversations[11]}) do
 shown,count=event(msg,"World")
 assert(shown==1 and count==0,"Ordinary Spanish World message wrongly filtered: "..msg)
end
W.db.filterGuild=false
shown,count=event(advertisements[2],"World")
assert(shown==1 and count==0,"Guild category OFF must allow showcase")
W.db.filterGuild=true
W.db.enabled=false
shown,count=event(advertisements[3],"World")
assert(shown==1 and count==0,"Master OFF must allow showcase")
W.db.enabled=true
shown,count=event(advertisements[4],"World","Tester")
assert(shown==1 and count==0,"Own guild showcase must never hide")
print("PASS Spanish guild showcases: "..#advertisements.." adverts and "..
      #conversations.." chats x3; World-only, toggles, self-message safeguards")
