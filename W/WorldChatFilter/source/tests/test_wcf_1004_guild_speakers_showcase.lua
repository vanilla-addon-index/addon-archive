-- Regression: English-language speaker recruitment and silent RU-guild showcases.
-- Do not depend on specific guild names, URLs, or player names.
table.getn=table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function UnitName() return 'Tester' end
local now, delivered=100,0
function GetTime() return now end
function ChatFrame_OnEvent() delivered=delivered+1 end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
WorldChatFilterDB={enabled=true,filterGuild=true,filterLFG=true,filterServices=true,filterTrade=true,filterRepeats=false,sensitivity='balanced'}
for _,f in ipairs({'Core.lua','Statistics.lua','Classifier.lua','Filter.lua'}) do dofile(f) end
WorldChatFilter.Initialize()
local W=WorldChatFilter
local adverts={
 '<Gamers Zone> is looking for friendly english speakers from EU timezone to start raiding on live stream, week nights. loot rule will be sr>ms . /w me your timezone class & spec if you are interested',
 'RU-Guild <GTD> Igra, Obchenie, Horoshee nastroenie. MC 12/12, ONY 2/2, World Bosses [www.goingtodeath.ru] OctoWoW Forever!',
 '<Another Crew> looking for German speakers for weekly raiding /w for invite',
 '<Moonlit> looking for English speakers to build a new community',
 '<New Dawn> recruiting friendly newcomers to our guild',
 'RU-Guild <New Sunrise> MC 12/12 ONY 2/2',
 'Guild <Night Shifters> BWL 8/8 MC 12/12',
 '<Scarlet Progress> BWL 8/8, MC 12/12, www.example.org',
 'www.guildsite.example Guild <Stone> hosts MC each week',
}
local nonad={
 'I prefer raiding with English speakers',
 'Is anyone playing from the EU timezone?',
 'What does 12/12 mean in MC?',
 'My guild cleared MC 12/12 yesterday',
 '<Hidden Friends> is a nice guild name',
 '<Moonlit> raided with us yesterday',
 'Website www.example.org is broken',
 'Who runs World Bosses in OctoWoW?',
 'What is the loot rule SR > MS?',
}
for _,mode in ipairs({'careful','balanced','aggressive'}) do
 W.db.sensitivity=mode
 for _,msg in ipairs(adverts) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(blocked and cat=='Guild', mode..' leaked: '..msg..' cat='..tostring(cat)..' score='..tostring(score)..' why='..tostring(why))
 end
 for _,msg in ipairs(nonad) do
  local cat,score,why,blocked=W.ClassifyMessage(msg)
  assert(not blocked, mode..' falsely blocked: '..msg..' cat='..tostring(cat)..' score='..tostring(score)..' why='..tostring(why))
 end
end
W.db.sensitivity='balanced'
local function event(message,channel)
 now=now+1
 arg1,arg2,arg4,arg7,arg9=message,'OtherPlayer','4. '..channel,7,channel
 local shown,count=delivered,W.GetStats().total
 ChatFrame_OnEvent('CHAT_MSG_CHANNEL')
 return delivered-shown,W.GetStats().total-count
end
for _,msg in ipairs({adverts[1],adverts[2]}) do
 local shown,recorded=event(msg,'World')
 assert(shown==0 and recorded==1,'World guild advert should hide and record once')
 for _,ch in ipairs({'Trade','General','LookingForGroup','Guild','Party'}) do
  shown,recorded=event(msg,ch)
  assert(shown==1 and recorded==0,'Non-World channel was affected: '..ch)
 end
end
W.db.filterGuild=false
local shown,recorded=event(adverts[1],'World')
assert(shown==1 and recorded==0,'Guild filter toggle must be respected')
shown,recorded=event(adverts[2],'World')
assert(shown==1 and recorded==0,'Guild promo toggle must be respected')
print('PASS tagged multilingual recruitment + website/progress promotions: '..#adverts..' ads, '..#nonad..' neutral samples x3, channel/toggle safeguards')
