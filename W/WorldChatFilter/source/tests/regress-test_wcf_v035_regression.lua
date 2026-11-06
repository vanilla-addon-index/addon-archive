table.getn = table.getn or function(t) return #t end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
function CreateFrame()
 return {RegisterEvent=function() end,SetScript=function() end}
end
function ChatFrame_OnEvent() end
function UnitName() return 'Mychar' end
WorldChatFilterDB={}
dofile('Core.lua')
dofile('Statistics.lua')
dofile('Classifier.lua')
dofile('Filter.lua')
WorldChatFilter.Initialize()
local ads = {
 'LF BM REP RUNS PST',
 '<Nagas in Paris> inviting based chuds to our small, chill guild',
 'need 1 heal 1 tank for sfk summon available',
 'DPS looking for BM rep farm',
 'LF 2 DPS 1 HEAL BM',
 '<Cleave> Looking for new recruits, Fastest MC, Ony, Zg and K10. Interested in adding 1 Boomkin, 1 Mage 1 SPriest. /w Warriortypeb if intrested',
 'feeling lonely? < wanted > recruits based chuds',
 'Enchanter LFW Weapon: Crusader/30Spell Power/Str/Unholy/Spirit! +9dmg... Bracers: 24Healing/mana regen/stamina/spirit/+7str',
 'RU Guild <СУНШТРАКТОР> Набирает активных игроков. Вступай к нам!',
 '<Bananenrepublik> Entspannte deutschsprachige Feierabend-/Community-Gilde! Wir sind zurück, neu geschmiedet auf OctoWoW. Gemeinsam leveln, helfen & später entspannt raiden. Kein Stress, kein Hardcore. Casuals & Veteranen willkommen! PM!',
 'WTS [Brilliant Sword] for 4g',
 'LF DPS Strat PST',
 'WTB herbs',
 'WTS portal summon services cheap pst',
 'Enchanter crafting Crusader enchant PST tips welcome',
 'LF rep farm',
 'LFG',
 'lf2m dps brd',
 'Looking for 1 tank for Scholo',
 'Our guild is recruiting raiders PST',
 'Guild <Warriors> looking for new members whisper me',
}
local good = {
 'How was your weekend?',
 'Does anyone know if BM rep farm is fun?',
 'What does LFG mean?',
 'What does WTS mean?',
 'Do I need an enchanter for this?',
 'What does LFW mean?',
 'I need 1 heal potion',
 'I need help optimizing my tank spec',
 'I love our guild',
 'Can I join your guild?',
 'Did our guild recruit anyone today?',
 'Someone in our guild was recruiting for a silly game last night',
 'Is anyone looking for a guild?',
 'LF a cool name for my rogue',
 'LF some advice on BM rep farming',
 'The healer in our group was awesome',
 'I just finished farming BM reputation',
 'I bought herbs yesterday',
 'That guild is recruiting weirdos lol',
 'Why are guilds recruiting so much?',
 'Anyone got advice for DPS in Strat?',
 'Need a new guild name suggestion',
 'Is the SFK summoning stone there?',
 'I can give you a portal later',
 'The enchanter gave me a discount',
 'I like helping people with rep farm',
 'Can someone explain LF BM REP RUNS PST?',
 'Why does everyone type LFG?',
 'Is portal service available on this server?',
 'Feeling lonely? Come hang out in Stormwind, no guild stuff',
}
local falseMiss, falseBlock = 0, 0
for _,v in ipairs(ads) do
 local cat,score,why,blocked,threshold = WorldChatFilter.ClassifyMessage(v)
 print((blocked and 'BLOCK' or 'MISS')..' '..score..'/'..threshold..' '..(cat or '-')..' '..v)
 if not blocked then falseMiss=falseMiss+1 end
end
for _,v in ipairs(good) do
 local cat,score,why,blocked,threshold = WorldChatFilter.ClassifyMessage(v)
 print((blocked and 'FALSE BLOCK' or 'ALLOW')..' '..score..'/'..threshold..' '..(cat or '-')..' '..v)
 if blocked then falseBlock=falseBlock+1 end
end
print('MISSES '..falseMiss..' FALSE POSITIVES '..falseBlock)
assert(falseMiss == 0 and falseBlock == 0)
