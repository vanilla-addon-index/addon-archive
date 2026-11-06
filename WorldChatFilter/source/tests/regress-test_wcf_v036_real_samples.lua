table.getn = table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
function ChatFrame_OnEvent() end
WorldChatFilterDB = {sensitivity='balanced'}
local base=''
dofile(base..'Core.lua');dofile(base..'Classifier.lua');WorldChatFilter.Initialize()
local samples={
 {"|cffefca7fBS LFW - does you soul stir with desire? |cffa335ee|Hitem:16905:0:0:0|h[Bloodsoul Gauntlets]|h|r|cffa335ee|Hitem:17502:0:0:0|h[Darksoul Shoulders]|h|r /w me",'Services'},
 {"BS LFW - does you soul stir with desire? [Bloodsoul Gauntlets][Darksoul Shoulders] /w me",'Services'},
 {"<Nerds of a Feather> is a great place for returning gamers, players new to OctoWow, first-time raiders, or leveling at all levels, ar just about anybody else. just ONE rule: NO JERKS allowed! Whisper for invite and find your flock today.",'Guild'},
}
local safe={
 "How much do blacksmiths earn from BS LFW ads?",
 "Does BS LFW mean blacksmith looking for work?",
 "Whisper for invite? Is there a guild event today?",
 "I whispered my friend for an invite to the party",
 "That guild is a great place for returning players, I joined them last year",
 "Any returning gamers here?",
 "The [Bloodsoul Gauntlets] look really good with that set",
}
local modes={'careful','balanced','aggressive'}
for _, mode in ipairs(modes) do
 WorldChatFilter.db.sensitivity=mode
 for _, entry in ipairs(samples) do
  local category,score,why,blocked,threshold=WorldChatFilter.ClassifyMessage(entry[1]);
  print(mode,'AD',category or '-',score,threshold,blocked and 'BLOCK' or 'ALLOW')
  assert(blocked and category==entry[2], 'failed ad '..mode..': '..entry[1])
 end
 for _,message in ipairs(safe) do
  local category,score,why,blocked,threshold=WorldChatFilter.ClassifyMessage(message)
  print(mode,'CHAT',category or '-',score,threshold,blocked and 'BLOCK' or 'ALLOW')
  assert(not blocked,'false positive '..mode..': '..message)
 end
end
print('Real screenshot strings, WoW item links, conversation safety: PASS')
