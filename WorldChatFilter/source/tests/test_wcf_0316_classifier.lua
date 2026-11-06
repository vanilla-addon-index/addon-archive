table.getn=table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
function UnitName() return 'Tester' end
function GetTime() return 10 end
local delivered=0
function ChatFrame_OnEvent() delivered=delivered+1 end
WorldChatFilterDB={sensitivity='balanced'}
local path=''
for _,f in ipairs({'Core.lua','Statistics.lua','Classifier.lua','Filter.lua'}) do dofile(path..f) end
WorldChatFilter.Initialize()
local W=WorldChatFilter
local positives={
 {'FAST SUMMONS (3g) [Hyjal] - [Winterspring] - [EPL Chapel] Under 2 min or FREE! (100% No-Bot) ? /w destination','Services'},
 {'SUMMONS 2g [Ironforge] - [Winterspring] /w for invite','Services'},
 {'Offering summons for FREE under 3 mins /w me','Services'},
 {'FAST SUMMONS (3g) [Hyjal] - [Winterspring] /w for details','Services'},
 {'Ashen Banner | Prog Friday, 9PM EST, Sunday 12PM | Looking for a good Rogue & Holy Priest, also open to other big pumpers for BWL+, Whisper or DM me on Discord!','Guild'},
 {'<New Dawn> Looking for Warlocks and Priests for AQ40 progression. Friday and Sunday 9PM. Whisper for details','Guild'},
 {'Seeking Warriors for weekly BWL raids Friday 8PM. PM me for more','Guild'},
 {'LF7M MC','LFG'},
 {'LF [Gold Belt Buckle]','Trade'},
}
local negatives={
 'Hey I joined Ashen Banner last night, great guild',
 'Did anyone see Ashen Banner in Stormwind?',
 'What do you think of the Ashen Banner guild?',
 'Ashen Banner has a funny name',
 'Ashen Banner cleared BWL on Friday, congrats!',
 'Ashen Banner raids on Friday, so I cannot play with them',
 'I heard Ashen Banner looking for Rogues for BWL, is that true?',
 'Our guild needs better DPS but we are not recruiting',
 'Looking for a Rogue to explain BWL tactics to me on Friday',
 'I am looking for rogue friends to chat with, not raid',
 'Looking for advice on our Friday raid schedule',
 'How much are summons to Winterspring?',
 'Are fast summons really under 2 min?',
 'The FAST SUMMONS 3g under 2 mins ad sounds fake, I heard',
 'I paid 3g for summons to Winterspring and got scammed',
 'Anybody know what /w destination means?',
 'My guild is Ashen Banner',
 'LF some advice on crafting my gear',
}
for _,mode in ipairs({'careful','balanced','aggressive'}) do
 W.db.sensitivity=mode
 for _,v in ipairs(positives) do
  local cat,score,why,blocked=W.ClassifyMessage(v[1]);
  print('AD',mode,cat,score,tostring(blocked),v[1]);
  assert(blocked and cat==v[2], 'missed '..mode..' '..v[1]..' WHY '..tostring(why))
 end
 for _,v in ipairs(negatives) do
  local cat,score,why,blocked=W.ClassifyMessage(v)
  if blocked then print('FALSE POSITIVE',mode,cat,score,v,why) end
  assert(not blocked,'false positive '..mode..' '..v..' WHY '..tostring(why))
 end
end
local filteredTotal=W.GetStats().total
local msg=positives[1][1]
local function send(name,number)
 arg1,arg2,arg4,arg7,arg9=msg,'RandomPlayer',number,7,name
 local before=delivered
 ChatFrame_OnEvent('CHAT_MSG_CHANNEL')
 return delivered-before
end
assert(send('World','4. World')==0)
assert(send('Trade','2. Trade')==1)
assert(send('General - Elwynn Forest','1. General - Elwynn Forest')==1)
assert(send('LookingForGroup','3. LookingForGroup')==1)
assert(W.GetStats().total==filteredTotal+1)
print('SUCCESS',#positives*3,'ads',#negatives*3,'nonads','World isolation')
