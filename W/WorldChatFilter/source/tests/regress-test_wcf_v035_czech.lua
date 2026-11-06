table.getn = table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
function UnitName() return 'Mychar' end
WorldChatFilterDB={}
local base=''
dofile(base..'Core.lua');dofile(base..'Classifier.lua')
WorldChatFilter.Initialize()
local ads = {
  '<Synove Severu> otevira brany pro novou krev, hledame aktivni jedince, radi vitame jak hobby hrace tak ostrilene veterany, v planu mame hlavne PVE, ONY/MC i dalsi.',
  '<Synové Severu> otevírá brány pro novou krev, hledáme aktivní jedince, rádi vítáme jak hobby hráče tak ostřílené veterány, v plánu máme hlavně PVE, ONY/MC i další.',
  'Hledáme aktivní hráče pro pravidelné raidy MC/ONY',
  'Naše gilda nabírá nové členy na PvE raidy.',
  'Prijmeme novych hracu do guildy na MC a BWL.',
  'Hladame aktivnych hracov na raidy PVE, vitame novych clenov.',
  'Pridaj sa k nam, hladame novych hracov na MC raid.',
}
local good = {
  'I really loved the guild raiding Ony and MC yesterday.',
  'Anyone know how to say hledame aktivni jedince in English?',
  'Hledame aktivni jedince for football, nothing to do with WoW',
  'Co znamena otevirame brany pro novou krev?',
  'Ahoj, hraje tu nekdo PVE? Ja rad chodim MC a Ony',
  'Nasi veterani hraji PVE hlavne o vikendu',
  'I heard Synove Severu are raiding MC these days',
  'Hledame stare screenshoty z raidu MC',
  'Nova krev v PVE je vzdy fajn',
  'Do you like Czech language in world chat?',
  'Our raid healer is active and we are ready for Ony.',
}
for _,mode in ipairs({'careful','balanced','aggressive'}) do
 WorldChatFilterDB.sensitivity=mode
 for _,m in ipairs(ads) do
  local cat,score,why,blocked,threshold = WorldChatFilter.ClassifyMessage(m)
  print(mode,'AD',blocked and 'BLOCK' or 'MISS',score,cat or '-',why or '-',m)
  assert(blocked and cat=='Guild',mode..' missed ad '..m)
 end
 for _,m in ipairs(good) do
  local cat,score,why,blocked,threshold = WorldChatFilter.ClassifyMessage(m)
  print(mode,'CHAT',blocked and 'FALSE BLOCK' or 'ALLOW',score,cat or '-',why or '-',m)
  assert(not blocked,mode..' false block '..m)
 end
end
print('Czech/Slovak multi-signal cases PASS')
