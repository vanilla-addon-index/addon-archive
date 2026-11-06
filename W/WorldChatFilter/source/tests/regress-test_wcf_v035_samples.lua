table.getn = table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
function ChatFrame_OnEvent() end
function UnitName() return 'Mychar' end
WorldChatFilterDB={}
local base=''
dofile(base..'Core.lua');dofile(base..'Classifier.lua')
WorldChatFilter.Initialize()
local ads = {
  '<Griefers Inc> {UK/EU} Semi HC Community Searching +HEALERS / Mage or Lock In Our Two Teams! x2 SR Raid Schedule: Monday/Friday (19:00CET) /w more info. Ony/MC/k10 on farm.',
  '<MEGAPANZAS> recluta. Solo 1 dia de raid, Domingo 22:00 ST/19:00 Arg, 55min MC (de chill) SR+>MS>OS. [discord.gg/MEGAPANZAS] +1000 miembros Realm First Naxx/AQ40/BWL/K40/ES en Turtle SA',
  'RU Guild <CUHUU TPAKTOP> NabiraeT AdeKBATHbIX igrokov. BCTY/7AU K HaM! ZG \\ KARA na Farme | MC sobiraem Static!',
  'RU Guild is the name of a channel right?', -- intentionally filtered by absolute prefix
}
for _,m in ipairs(ads) do local cat,s,why,blocked,t=WorldChatFilter.ClassifyMessage(m); print('baseline',blocked or false,cat or '-',s or 0,t or 0,why or '') end

for _,m in ipairs(ads) do local cat,s,why,blocked,t=WorldChatFilter.ClassifyMessage(m); assert(blocked and cat=='Guild', 'FAILED: '..m) end
local good={
'What does recluta mean in Spanish?',
'Our guild went to Naxx and we had a great time last night',
'Does anyone have our raid schedule?',
'Can I join a guild with my healer?',
'Who runs the community Discord?',
'The community is searching for a name for our pet',
'Does guild recruitment spam annoy anyone else?',
'I am searching for my guild members in Stormwind',
'I played in Spain yesterday and it was fun',
'Discord.gg links are everywhere nowadays',
'Me gustan los miembros de mi guild',
}
for _,m in ipairs(good) do local cat,s,why,blocked,t=WorldChatFilter.ClassifyMessage(m); print(blocked and 'FALSE BLOCK' or 'ALLOW', s or 0,m);assert(not blocked,m) end
