-- Real-world regression: Goldsmith LF work [items] and broad WoW profession abbreviations.
-- All professions/shorthands in a direct offer or LF request must be filtered.
table.getn=table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function UnitName() return 'Tester' end
local now,delivered=100,0
function GetTime() return now end
function ChatFrame_OnEvent() delivered=delivered+1 end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
WorldChatFilterDB={enabled=true,filterGuild=true,filterLFG=true,filterServices=true,filterTrade=true,filterRepeats=false,sensitivity='balanced'}
for _,f in ipairs({'Core.lua','Statistics.lua','Classifier.lua','Filter.lua'}) do dofile(f) end
WorldChatFilter.Initialize()
local W=WorldChatFilter
local ads={
 'Goldsmith LF work [Grail of Forgotten Memories][Ring of Unleashed Potential][Twilight Opal Cascade]and many more',
 'Goldsmith LF work |cffa335ee|Hitem:10001:0:0:0|h[Grail of Forgotten Memories]|h|r',
 'GOLDSMITH LF WORK',
 'LF WORK GOLDSMITH',
 'Gemologist LFW [Cut Gemstone]',
 'LFW Gemology',
 'LF WORK', 'LFW', 'LF WORK?', 'LFWORK',
 'Looking for work',
 'Goldsmith', 'GEMOLOGIST', 'ENCHANTER', 'JC', 'BS', 'LW', 'TL', 'ENCH',
 'Enchanter LF work [Enchant Weapon - Crusader]',
 'BLACKSMITH LFW [Sword]',
 'ENGINEER LFW [Rocket]',
 'ALCH LFW [Flask]',
 'ENGI LFW', 'ENG LFW', 'ENCH LFW', 'CHANT LFW', 'SCRIBE LFW',
 'INSCR LFW', 'JC LFW', 'LW LFW', 'TL LFW', 'BS LFW',
 'HERB LFW', 'MINE LFW', 'SKIN LFW', 'FA LFW', 'COOK LFW', 'FISH LFW',
 'LF goldsmith [Ring]',
 'LF JC [Deep Sapphire Circlet]',
 'LF BS', 'LF LW', 'LF ENGI', 'LF ENG', 'LF ALCH', 'LF ENCH',
 'LF CHANT', 'LF TL', 'LF TAILOR', 'LF SCRIBE', 'LF INSCR',
 'LF HERB', 'LF MINING', 'LF COOKING', 'LF FISHING', 'LF FA',
 'LF GEMOLOGY', 'LF INSCRIPTION',
 'Looking for a goldsmith',
 'Looking for an enchanter',
 'Looking for a leatherworker',
 'Looking for a jeweler',
 'Looking for a scribe',
 'Looking for an engineer',
 'Blacksmith [Dark Iron Shoulders] crafted for tips',
 'Leatherworking [Heavy Armor Kit] mats welcome',
 'Jewelcrafter [Rings] and [Necklaces] whisper me',
 'Goldsmith [A Magic Ring] and many more',
 'Herbalist available for collecting herbs',
 'Tailoring [Robe of the Archmage] tips welcome',
}
local chats={
 'What does LFW mean?',
 'Does BS LFW mean blacksmith looking for work?',
 'JC LFW means I can craft jewelry, right?',
 'What does LF WORK mean?',
 'I just learned Jewelcrafting',
 'JC is a nice profession',
 'Is JC better than enchanting?',
 'The enchanter gave me a discount',
 'My friend is a jeweler',
 'How is mining in Elwynn?',
 'Selling fish for gold is better than quests',
 'SELLING FISH [Stonescale Eel]', -- Trade, not Services
 'Do I need an enchanter for this?',
 'Does anyone know where the Jewelcrafting trainer is?',
 'I love fishing in Stranglethorn',
 'What does the word Goldsmith mean?',
 'Goldsmithing is an interesting new feature',
}
for _,mode in ipairs({'careful','balanced','aggressive'}) do
 W.db.sensitivity=mode
 for _,msg in ipairs(ads) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(blocked and cat=='Services',mode..' missed profession offer '..msg..' ('..tostring(cat)..' '..tostring(score)..': '..tostring(why)..')')
 end
 for _,msg in ipairs(chats) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  if msg=='SELLING FISH [Stonescale Eel]' then
   assert(blocked and cat=='Trade',mode..' fish marketplace misclassified as '..tostring(cat))
  else
   assert(not blocked,mode..' overfilter '..msg..' ('..tostring(cat)..' '..tostring(score)..': '..tostring(why)..')')
  end
 end
end
W.db.sensitivity='balanced'
local function event(msg,chan)
 now=now+1
 arg1,arg2,arg4,arg7,arg9=msg,'AnotherPerson','4. '..chan,7,chan
 local b,s=delivered,W.GetStats().total
 ChatFrame_OnEvent('CHAT_MSG_CHANNEL')
 return delivered-b,W.GetStats().total-s
end
for _,m in ipairs({ads[1],ads[7],ads[22]}) do
 local shown,count=event(m,'World')
 assert(shown==0 and count==1,'World must hide/count service exactly once: '..m)
 for _,ch in ipairs({'Trade','General','Guild','LookingForGroup','Party'}) do
  shown,count=event(m,ch)
  assert(shown==1 and count==0,'Must pass non-World '..ch)
 end
end
W.db.filterServices=false
local shown,count=event(ads[1],'World')
assert(shown==1 and count==0,'Services toggle should allow work offer')
print('PASS work/professions: '..#ads..' services, '..#chats..' ordinary/Trade x3, World channel and toggle')
