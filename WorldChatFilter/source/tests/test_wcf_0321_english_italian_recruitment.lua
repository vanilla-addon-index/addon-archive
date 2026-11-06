-- WorldChatFilter v0.3.21: recruitment intent across English and Italian.
-- Names are varied deliberately; detection must NEVER rely on a guild blacklist.
table.getn=table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function UnitName() return 'Tester' end
local now, delivered = 30, 0
function GetTime() return now end
function ChatFrame_OnEvent() delivered=delivered+1 end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
WorldChatFilterDB = {enabled=true,filterGuild=true,filterLFG=true,
  filterServices=true,filterTrade=true,filterRepeats=true,sensitivity='balanced'}
for _,file in ipairs({'Core.lua','Statistics.lua','Classifier.lua','Filter.lua'}) do
  dofile(''..file)
end
WorldChatFilter.Initialize()
local W=WorldChatFilter
assert(W.VERSION=='1.1.2')
local adverts = {
  -- Exact real-world screenshot message (content only, without channel header).
  '{RU}-{SNG} Guild "One Blood" looking for ru speaking players to farm PvP/PvE >no rush|chill and positive vibe <3 full content on farm 50+ online every evening!',
  '<Fratelli di Azeroth> apre i reclutamenti! Se state livellando e siete in cerca di un gruppo amichevole wispate in privato!',
  -- New guild names & varying languages: test generalization, not blacklists.
  '<New Horizon> Guild looking for English speaking players for PvP. Active and friendly community!',
  'Guild "Old Guard" looking for players for PVE content, chill and active online',
  'Fresh guild looking for casual players for PvE; no rush, friendly guild',
  'Guild seeking 30+ players for weekly PVP events',
  'EU Guild searching for more players for raids every night',
  'Gilda italiana recluta giocatori per raid, whisper per info',
  '<Il Sole> apriamo i reclutamenti per il gruppo amichevole, scrivetemi in privato',
  'Cerchiamo membri per la nostra gilda, scrivetemi in privato',
  '<Il Drago> reclutiamo giocatori per raid, contattatemi',
  '<La Torre> apre i reclutamenti! Cercate un gruppo amichevole? wispate in privato!',
}
local chats = {
  'One Blood helped me with a quest yesterday',
  'I heard One Blood guild is looking for RU speaking players for PvP yesterday',
  'What does looking for Russian speaking players mean?',
  'What does Guild mean in WoW?',
  'Are any guilds good for PvP? I am looking for advice',
  'I like the chill and positive vibe of my guild',
  'I farm PvP and PvE with friendly guildmates online every evening',
  'My guild has 50 players online every evening',
  'The guild is not recruiting right now, we just want to chat',
  'I saw a guild looking for players for PvP last night',
  'Fratelli di Azeroth helped me level yesterday',
  'I saw the guild Fratelli di Azeroth in Stormwind',
  'What does reclutamenti mean in Italian?',
  'Cosa significa reclutamenti?',
  'Sto cercando il significato di reclutamenti',
  'La gilda non sta reclutando membri, scrivete in privato per informazioni',
  'Il mio gruppo amichevole gioca a WoW ogni sera',
  'Someone in Italian said "apre i reclutamenti", what does that mean?',
  'How can I join a guild that is looking for PvE players?',
  'That guild is looking for players who love PvP? Sounds cool!',
}
for _,mode in ipairs({'careful','balanced','aggressive'}) do
  W.db.sensitivity=mode
  for _,ad in ipairs(adverts) do
    local c,s,why,blocked=W.ClassifyMessage(ad)
    assert(blocked and c=='Guild', mode..' should BLOCK: '..ad..' -> '..tostring(c)..' '..tostring(s)..' '..tostring(why))
  end
  for _,chat in ipairs(chats) do
    local c,s,why,blocked=W.ClassifyMessage(chat)
    assert(not blocked, mode..' should ALLOW: '..chat..' -> '..tostring(c)..' '..tostring(s)..' '..tostring(why))
  end
end
W.db.sensitivity='balanced'
local sample=adverts[1]
local function event(channel,numbered,kind)
  now=now+1
  arg1,arg2,arg4,arg7,arg8,arg9=sample,'Adposter',numbered,99,4,channel
  local before=delivered
  local stats=W.GetStats().total
  ChatFrame_OnEvent(kind or 'CHAT_MSG_CHANNEL')
  return delivered-before, W.GetStats().total-stats
end
local shown,count=event('World','4. World')
assert(shown==0 and count==1,'World advertising must be suppressed and counted')
for _,channel in ipairs({'Trade','General','LookingForGroup'}) do
  shown,count=event(channel,'5. '..channel)
  assert(shown==1 and count==0,channel..' must never be suppressed or counted')
end
shown,count=event('World','5. Trade')
assert(shown==1 and count==0,'Inconsistent channel names must fail open')
shown,count=event('World','4. World','CHAT_MSG_GUILD')
assert(shown==1 and count==0,'Guild chat must remain untouched')
-- Disabling the Guild filter is also respected in the actual channel path.
W.db.filterGuild=false
shown,count=event('World','4. World')
assert(shown==1 and count==0,'Guild category toggle must be respected')
print('PASS WCF v0.3.21 12 English/Italian examples x3; 20 chats x3; World-only integration')
