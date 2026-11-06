-- WorldChatFilter contextual World-ad classifier, Vanilla Lua 5.0 compatible.
-- Original scoring/lexicons curated for WorldChatFilter; not copied from other addons.
-- Words are whole-token matched, except the explicit foreign-language stems.
local WCF = WorldChatFilter

local function stripMarkup(message)
  local s = tostring(message or "")
  s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
  s = string.gsub(s, "|r", "")
  s = string.gsub(s, "|H[^|]*|h", "")
  s = string.gsub(s, "|h", "")
  return s
end

-- Optional UTF-8 Latin accents folding, because Vanilla Lua's string.lower
-- is ASCII-only. Keep Cyrillic untouched for lowerLanguages() below.
-- Map only Latin letters; avoid destroying Czech/Slovak word boundaries.
local latinAccents = {
  {"á","a"},{"Á","a"},{"ä","a"},{"Ä","a"},{"å","a"},{"Å","a"},{"à","a"},{"À","a"},
  {"â","a"},{"Â","a"},{"ã","a"},{"Ã","a"},{"ą","a"},{"Ą","a"},
  {"č","c"},{"Č","c"},{"ć","c"},{"Ć","c"},{"ç","c"},{"Ç","c"},
  {"ď","d"},{"Ď","d"},{"đ","d"},{"Đ","d"},
  {"é","e"},{"É","e"},{"ě","e"},{"Ě","e"},{"ë","e"},{"Ë","e"},
  {"ę","e"},{"Ę","e"},{"è","e"},{"È","e"},{"ê","e"},{"Ê","e"},
  {"í","i"},{"Í","i"},{"ï","i"},{"Ï","i"},{"î","i"},{"Î","i"},
  {"ĺ","l"},{"Ĺ","l"},{"ľ","l"},{"Ľ","l"},{"ł","l"},{"Ł","l"},
  {"ň","n"},{"Ň","n"},{"ń","n"},{"Ń","n"},{"ñ","n"},{"Ñ","n"},
  {"ó","o"},{"Ó","o"},{"ô","o"},{"Ô","o"},{"ö","o"},{"Ö","o"},
  {"ő","o"},{"Ő","o"},{"ò","o"},{"Ò","o"},{"õ","o"},{"Õ","o"},
  {"ř","r"},{"Ř","r"},{"ŕ","r"},{"Ŕ","r"},
  {"š","s"},{"Š","s"},{"ś","s"},{"Ś","s"},{"ş","s"},{"Ş","s"},
  {"ť","t"},{"Ť","t"},{"ţ","t"},{"Ţ","t"},
  {"ú","u"},{"Ú","u"},{"ů","u"},{"Ů","u"},{"ü","u"},{"Ü","u"},
  {"ű","u"},{"Ű","u"},{"ù","u"},{"Ù","u"},{"û","u"},{"Û","u"},
  {"ý","y"},{"Ý","y"},{"ÿ","y"},{"Ÿ","y"},
  {"ž","z"},{"Ž","z"},{"ź","z"},{"Ź","z"},{"ż","z"},{"Ż","z"},
}
local function normalize(raw)
  local s = raw
  -- Latin accents begin with C3, C4 or C5 in our explicit fold table.
  -- Cyrillic (D0/D1) and arbitrary UTF-8 links must not trigger 80+ gsubs.
  if string.find(s, "[\195-\197]") then
    local i
    for i = 1, table.getn(latinAccents) do
      s = string.gsub(s, latinAccents[i][1], latinAccents[i][2])
    end
  end
  s = string.lower(s)
  s = string.gsub(s, "[^%w]+", " ")
  s = string.gsub(s, "%s+", " ")
  return " " .. s .. " "
end

-- Lexicon entries never change: wrap each candidate only once rather than
-- constructing " " .. word .. " " for every word match on every message.
-- The cache is bounded by our fixed lexicon (not user/chat content).
local wrappedTerms = {}
local function contains(text, term)
  local pattern = wrappedTerms[term]
  if not pattern then
    pattern = " " .. term .. " "
    wrappedTerms[term] = pattern
  end
  return string.find(text, pattern, 1, true) ~= nil
end
local phrase = contains

local function any(text, words)
  local i
  for i = 1, table.getn(words) do
    if contains(text, words[i]) then return true end
  end
  return false
end

local function somePhrase(text, words)
  local i
  for i = 1, table.getn(words) do
    if phrase(text, words[i]) then return true end
  end
  return false
end

-- High-recall World group search: LF / LFM / LF1M / Looking for followed
-- anywhere later in the same message by "speakers". We intentionally do
-- NOT check a language dictionary: any X speakers (including Bluetooth)
-- counts, per the chosen aggressive false-positive policy.
local speakerSearchPatterns = {
  {" looking for ", true}, {" lf ", true}, {" lfm ", true},
  {" lf%d+m ", false}, {" lfm%d*m? ", false}
}
local function hasSpeakerSearch(text)
  if not contains(text, "speakers") then return false end
  local i
  for i = 1, table.getn(speakerSearchPatterns) do
    local pattern, plain = speakerSearchPatterns[i][1], speakerSearchPatterns[i][2]
    local from, finish = string.find(text, pattern, 1, plain)
    if from and string.find(text, " speakers ", finish + 1, true) then
      return true
    end
  end
  return false
end

-- Absolute prefix rule, after normalizing separators and letter case:
-- RU GUILD / RU-GUILD / RUSSIAN GILD / RU-GILD and comparable spellings.
-- It must match the BEGINNING only, not a later mention in a sentence.
local ruGuildPrefixes = {ru=true, rus=true, russian=true, russ=true,
    russki=true, russkii=true}
local guildSpellings = {guild=true, gild=true, gilde=true, guld=true}
local compactRuGuildPrefixes = {ruguild=true, rugild=true, rugilde=true,
    rusguild=true, rusgild=true, russianguild=true, russiangild=true}
local function hasRuGuildPrefix(text)
  local _, _, origin, word = string.find(text, "^%s*([%a]+)%s+([%a]+)%s")
  if origin and ruGuildPrefixes[origin] and guildSpellings[word] then
    return true
  end
  local _, _, compact = string.find(text, "^%s*([%a]+)%s")
  return compact and compactRuGuildPrefixes[compact] or false
end

-- Unicode-safe *selective* UTF-8 Russian folding for common ad stems.
-- ASCII-only string.lower() does not fold UTF-8 Cyrillic in Vanilla.
local function lowerLanguages(raw)
  local s = string.lower(raw)
  if not string.find(s, "[\208\209]") then return s end
  local d0, d1 = string.char(208), string.char(209)
  local upper1 = "[" .. string.char(144) .. "-" .. string.char(159) .. "]"
  local upper2 = "[" .. string.char(160) .. "-" .. string.char(175) .. "]"
  s = string.gsub(s, d0 .. "(" .. upper1 .. ")", function(v)
    return d0 .. string.char(string.byte(v) + 32)
  end)
  s = string.gsub(s, d0 .. "(" .. upper2 .. ")", function(v)
    return d1 .. string.char(string.byte(v) - 32)
  end)
  s = string.gsub(s, d0 .. string.char(129), d1 .. string.char(145))
  return s
end

-- Curated activity/alias groups based on Vanilla/Turtle terminology.
-- The names do NOT block messages on their own; they add evidence only
-- after group-finding intent has been identified.
local roles = {"dps","dd","dds","tank","tanks","heal","heals","healer","healers","healing"}
-- Short World recruitment: "Need DPS [quest]" / "DPS needed" with no
-- dungeon alias or literal "quest". Keep professions and potions separate.
local directNeedRoles = {dps=true, dd=true, dds=true, tank=true, tanks=true,
    heal=true, heals=true, healer=true, healers=true, healing=true}
local dungeons = {"sfk","bm","brd","lbrs","ubrs","brs","strat","stratholme","scholo", "scholomance",
 "mara","maraudon","zf","zg","dm","dire","maul","sm","rfc","wc","rfk","rfd","stockades",
 "deadmines","gnomer","gnomeregan","ulda","uldaman","st","bfd","sunken","temple","mc",
  "scarlet","graveyard","gy",
 "ony","onyxia","bwl","aq","aq20","aq40","naxx","k10","kara","karazhan"}
-- A dungeon at the start of a short message can introduce a compact roster
-- listing (e.g. "DEADMINES HEAL 2DPS"). Names by themselves never cause blocks.
local dungeonLeadTokens = {}
for i = 1, table.getn(dungeons) do dungeonLeadTokens[dungeons[i]] = true end

local activities = {"rep","reputation","farm","farming","run","runs","group","grp","party", "dungeon", "instance",
 "raid","raids","speedrun","speedruns","attunement","questing","elite","quest","quests","pvp","arena"}
local professions = {"enchanter","enchanting","enchants","enchant","alchemist","alchemy","blacksmith",
 "blacksmithing","tailor","tailoring","leatherworker","leatherworking","engineer","engineering",
 "crafter","crafting","jewelcrafter","jewelcrafting","jeweler","jeweller",
 "inscription","transmute","transmutes","crusader","arcanite","flask","flasks",
 "goldsmith","goldsmithing","gemologist","gemology","gemmologist",
 "inscriber","scribe","herbalist","herbalism","mining","miner","skinning","skinner",
 "cooking","cook","fishing","fisherman","first aid"}
-- Confirmed WoW abbreviations (BS, LW, JC, ENG, ALCH, ENCH, CHANT, etc.)
-- plus Turtle Jewelcrafting specializations. Short ambiguous tokens are
-- contextual unless the whole message is just the profession shorthand.
local professionNames = {"enchanter","enchanters","enchanting","blacksmith",
 "blacksmiths","blacksmithing","engineer","engineers","engineering","alchemist",
 "alchemists","alchemy","jewelcrafter","jewelcrafters","jewelcrafting",
 "jeweler","jeweller","goldsmith","goldsmiths","goldsmithing","gemologist",
 "gemologists","gemmologist","gemology","leatherworker","leatherworkers",
 "leatherworking","tailor","tailors","tailoring","scribe","inscriber",
 "inscription","herbalist","herbalism","miner","mining","skinner",
 "skinning","cook","cooking","fisherman","fishing","first aid"}
local professionShort = {"bs","lw","jc","eng","engi","engin","alch",
 "ench","chant","chanter","tl","inscr","insc","scribe","herb",
 "mine","skin","fish","cook","fa"}
local professionTerms = {}
local pi
for pi=1,table.getn(professionNames) do professionTerms[professionNames[pi]] = true end
for pi=1,table.getn(professionShort) do professionTerms[professionShort[pi]] = true end
local merchandise = {"gold","g","mats","materials","herbs","herb","ore","ores","item","items","boe","epic",
 "recipe","recipes","mount","mounts","stack","stacks","enchants","enchant","cloth","potions","potion"}
local services = {"boost","boosts","boosting","carry","carries","carrying","summon","summons","summoning",
 "portal","portals","transport","powerlevel","powerleveling","powerlevelling","crafting","enchanting"}
local contact = {"pst","whisper","whisp","pm","pn","wisp","message","dm","/w"}
local recruit = {"recruiting","recruitment","recruits","applicants",
 "rekrutiert","rekrutieren","rekrutierung","recrute","recrutement","recluta","reclutando"}
local guildNouns = {"guild","guilds","gilde","gilden","guilde","gildia","static","roster"}
-- Class names are *context*, never an advertisement by themselves. Include plural
-- recruitment listings ("Mages/Shamans/Warlocks") and Vanilla class nicknames.
-- Static raid weekday vocabulary: avoid allocating a table per chat line.
local raidWeekdays = {"monday","tuesday","wednesday","thursday","friday",
  "saturday","sunday","mondays","tuesdays","wednesdays","thursdays",
  "fridays","saturdays","sundays"}
-- Short weekday labels, German and Romance-language raid schedules.
-- These are meaningful only in conjunction with an actual raid/dungeon and a clock time.
local raidDayAliases = {"mon","tue","tues","wed","weds","thu","thur","thurs",
  "fri","sat","sun","mo","di","mi","fr","sa",
  "lunes","martes","miercoles","jueves","viernes","sabado","domingo",
  "lundi","mardi","mercredi","jeudi","vendredi","samedi","dimanche"}

local playerClasses = {"mage","mages","shaman","shamans","warlock","warlocks",
  "lock","locks","druid","druids","priest","priests","spriest",
  "warrior","warriors","hunter","hunters","rogue","rogues","paladin","paladins",
  "boomkin","boomkins","feral","ferals","resto","shadowpriest","shadowpriests"}

-- All supported group roles/classes as a bounded static lookup. A class word
-- alone is NEVER a reason to block; the sender must express group-search intent.
local groupTypes = {}
local i
for i = 1, table.getn(roles) do groupTypes[roles[i]] = true end
for i = 1, table.getn(playerClasses) do groupTypes[playerClasses[i]] = true end
-- Supports e.g. "LF 1 Holy Priest" without treating a spec alone as a request.
local groupSpecs = {holy=true, shadow=true, discipline=true, disc=true,
  protection=true, prot=true, restoration=true, resto=true,
  elemental=true, enhancement=true, enh=true, fury=true, arms=true,
  retribution=true, ret=true, balance=true, feral=true}

-- Detect "LF 1Healer", "LF1Mage", "LF 2 DPS", "LF 1 Rogue" and
-- "Looking for 2 Shamans". Lua 5.0 patterns; tokens must be whole words.
-- Do not enumerate specific class/count combinations in the classifier.
-- LF followed by an optional number + role/class/spec or dungeon/raid/BG.
-- Vanilla and Turtle WoW full names and popular community abbreviations.
-- The targets alone never cause a block; a leading LF is required.
local lfDestinations = {
  "ragefire chasm","rfc","wailing caverns","wc","deadmines","vc",
  "dm","shadowfang keep","sfk","blackfathom deeps","bfd","stockades",
  "stockade","stocks","stock","gnomeregan","gnomer","gnome",
  "razorfen kraul","rfk","razorfen downs","rfd","scarlet monastery","sm",
  "sm gy","sm lib","sm arm","sm cath","graveyard","library",
  "armory","cathedral","uldaman","ulda","zul farrak","zulfarrak",
  "zf","maraudon","mara","sunken temple","temple of atal hakkar","atal hakkar",
  "st","blackrock depths","brd","lower blackrock spire","lbrs","upper blackrock spire",
  "ubrs","blackrock spire","brs","dire maul","dm east","dm west",
  "dm north","dme","dmw","dmn","scholomance","scholo",
  "stratholme","strat","strat live","strat ud","molten core","mc",
  "onyxia","ony","blackwing lair","bwl","zul gurub","zg",
  "ruins of ahn qiraj","aq20","aq 20","aq","temple of ahn qiraj","aq40",
  "aq 40","naxxramas","naxx","warsong gulch","warsong","wsg",
  "arathi basin","ab","alterac valley","av","crescent grove","the crescent grove",
  "cg","hateforge quarry","hateforge","hfq","hq","stormwrought ruins",
  "stormwrought","swr","gilneas city","gilneas","karazhan crypt","karazhan crypts",
  "kara crypts","crypts","kc","black morass","bm","stormwind vault",
  "stormwind vaults","swv","lower karazhan halls","lower kara","kara10","kara 10",
  "k10","lkh","emerald sanctum","es","tower of karazhan","upper kara",
  "kara40","kara 40","tok","timbermaw hold","tmh","sunnyglade valley",
  "sgv","blood ring","thorn gorge","tg","dungeon","dungeons",
  "instance","instances","raid","raids","bg","bgs",
  "battleground","battlegrounds"
}
local lfRoleAliases = {
  rdps=true,mdps=true,ranged=true,melee=true,warr=true,war=true,hunt=true,
  hun=true,rog=true,pala=true,pally=true,pal=true,sham=true,shammy=true,
  dru=true,drood=true,dudu=true,wl=true,spriest=true,sp=true,hpal=true,
  rdru=true,rsham=true,ele=true,boomie=true,retadin=true,healadin=true
}
local lfAdvicePhrases = {"lf advice", "lf some advice", "lf tips",
  "lf some tips", "lf help with", "lf a name", "lf a cool"}
local function leadingLfTarget(text)
  -- normalize() wraps the line with spaces; uses Vanilla-compatible patterns.
  -- Matches LF RFK / LF4 RFK / LF 4 RFK / LF healer.
  if not string.find(text, "^ lf") then return false end
  local _, _, number, target = string.find(text, "^ lf%s*(%d*)%s+(.+) $")
  if not target then return false end
  if number ~= "" and tonumber(number) and tonumber(number) <= 0 then return false end
  if somePhrase(text, lfAdvicePhrases) then return false end
  local tail = " " .. target .. " "
  if somePhrase(tail, lfDestinations) then return true end
  local word
  for word in string.gfind(target, "%a+") do
    if groupTypes[word] or groupSpecs[word] or lfRoleAliases[word] then return true end
  end
  return false
end

local countedLfPattern = " lf%s*(%d+)%s*([%a]+) "
local countedLookingPattern = " looking for%s*(%d+)%s*([%a]+) "
local function countGroupSearch(text, pattern)
  local at = 1
  while true do
    local from, finish, count, noun = string.find(text, pattern, at)
    if not from then return false end
    if groupTypes[noun] and tonumber(count) and tonumber(count) > 0 then
      return true
    end
    if groupSpecs[noun] and tonumber(count) and tonumber(count) > 0 then
      local _, _, nextWord = string.find(string.sub(text, finish + 1), "^(%a+) ")
      if nextWord and groupTypes[nextWord] then return true end
    end
    at = finish + 1
  end
end

-- Find compact player counts anywhere in a message, including DPS1 or 1DPS.
-- Continue after non-role tokens such as "Kara10", not just the first match.
local function countedGroupTypeAnywhere(text, reverse)
  local at = 1
  while true do
    local from, finish, count, noun
    if reverse then
      from, finish, noun, count = string.find(text, " ([%a]+)(%d+) ", at)
    else
      from, finish, count, noun = string.find(text, " (%d+)([%a]+) ", at)
    end
    if not from then return false end
    if groupTypes[noun] and tonumber(count) and tonumber(count) > 0 then
      return true
    end
    at = finish  -- retain trailing word separator for an adjacent next token
  end
end

local function separatePositiveCount(text)
  local at = 1
  while true do
    local from, finish, count = string.find(text, " (%d+) ", at)
    if not from then return false end
    if tonumber(count) and tonumber(count) > 0 then return true end
    at = finish
  end
end

-- Reuse this static list instead of allocating a new table for every
-- summoning-directory advertisement (especially important on busy channels).
local summonDestinations = {"booty bay", "blackrock mountain", "blackfathom deeps",
 "dire maul", "gadgetzan", "ironforge", "maraudon", "hillsbrad",
 "hinterlands", "stormwind", "orgrimmar", "undercity", "thunder bluff",
 "eastern plaguelands", "dragonmaw", "tanaris", "silithus",
 "ashenvale", "desolace", "winterspring", "felwood", "stranglethorn",
 "hydraxian", "alach thalas", "alah thalas", "mc", "brd"}

local function newResult(category)
  -- Most chat messages do not advertise; allocate clue arrays only on hits.
  return {category = category, score = 0, intent = false}
end

local function add(result, amount, why)
  result.score = result.score + amount
  if not result.clues then result.clues = {} end
  table.insert(result.clues, why)
end

local function questionPenalty(text, message)
  -- Distinguishes "What does LFG mean?" from an actual LFG ad.
  if somePhrase(text, {"what does","what is","how do","how can","can anyone explain",
                            "anyone know","does anyone know","is there","what are","why is","why do", "can someone explain"}) then return 6 end
  if somePhrase(text, {"can i join","did our","is anyone","do you know","how many"}) then return 4 end
  if somePhrase(text, {"lf some advice","lf advice","lf tips","lf a cool","looking for advice",
        "looking for tips","lf some tips","lf a name","lf help with"}) then return 7 end
  if somePhrase(text, {"someone in our guild","that guild is","someone said","i heard",
        "was recruiting for","last night they"}) then return 5 end
  if somePhrase(text, {"how much do", "how much does", "how much can"}) then return 12 end
  if string.find(text, "^ does ") and contains(text, "mean") then return 10 end
  if string.find(message, "?", 1, true) then return 2 end
  return 0
end

local function lfg(text, lower, message)
  local r = newResult("LFG")
  local directLfTarget = leadingLfTarget(text)
  -- Generic LF<number>M group shorthand (LF1M, LF7M, LF12M, etc.).
  -- Normalization inserts spaces at word boundaries, so this detects whole
  -- tokens only and never matches e.g. ALF7M, LF7MX or player names.
  -- Intentionally use Lua 5.0 string patterns (no %f frontier syntax).
  local lfSlots = string.find(text, " lf%d+m ") ~= nil
  -- Both LF1M and LF 1M mean "looking for 1 more". Support LF 1 M
  -- too, using whole-token boundaries to avoid matching unrelated words.
  -- Numbers are intentionally unrestricted, as with LF<number>M.
  local spacedLfSlots = string.find(text, " lf %d+%s*m ") ~= nil
  local wordLfSlots = string.find(text, " lf %d+ more ") ~= nil
  local hasLfSlots = lfSlots or spacedLfSlots or wordLfSlots
  local countedLfRoleOrClass = string.find(text, " lf", 1, true) and
      countGroupSearch(text, countedLfPattern)
  local countedLookingRoleOrClass = string.find(text, " looking for", 1, true) and
      countGroupSearch(text, countedLookingPattern)
  -- Additional group-ad layouts: "need 1 heal for Windhorn" and
  -- "Deadmines heal 2DPS". A role count only contributes in a group context.
  local countedNeedRoleOrClass = string.find(text, "^ need ") and
      countGroupSearch(text, " need%s*(%d+)%s*([%a]+) ")
  local _, _, leadingToken = string.find(text, "^ ([%w]+) ")
  local startsDungeon = leadingToken and dungeonLeadTokens[leadingToken]
  -- Only scan for a bare counted role when a dungeon heads the message;
  -- otherwise ordinary World chit-chat would pay for an unnecessary scan.
  local standaloneCountedRole = startsDungeon and
      countGroupSearch(text, " (%d+)%s*([%a]+) ")
  -- LFM<number> (e.g. LFM1, LFM7, LFM12) and LFM<number>M are
  -- distinct from LF<number>M.  Lua 5.0 patterns, whole-token only.
  local lfmSlots = string.find(text, " lfm%d+m? ") ~= nil
  local prefixed = string.find(text, "^ lf ") ~= nil or
                   string.find(text, "^ lf%d+ ") ~= nil or
                   string.find(text, "^ lf%d+m ") ~= nil or
                   string.find(text, "^ lfm%d+m? ") ~= nil or
                   string.find(text, "^ lfg ") ~= nil or
                   string.find(text, "^ lfm ") ~= nil or
                   string.find(text, "^ lfp ") ~= nil
  local explicit = hasLfSlots or lfmSlots or any(text, {"lfg","lfm","lfp","lftank","lfhealer","lfdps","lfr"})
  -- Tagged speaker recruitment belongs to Guild. An untagged LF ... speakers
  -- request is LFG; do not let it bypass a disabled Guild filter.
  local speakerRequest = hasSpeakerSearch(text) and
      not string.find(message, "<[^<>]+>") and not hasRuGuildPrefix(text)
  local lf = contains(text, "lf") or string.find(text, " lf%d+ ") ~= nil or hasLfSlots
  local looking = somePhrase(text, {"looking for","searching for","looking 4"})
  local need = any(text, {"need","needs","needing","needed","missing"})
  local slots = somePhrase(text, {"last spot","last slot","one more","two more","spots open","slots open","fill group"})
  local role = any(text, roles)
  -- A leading player-role demand is LFG even when followed only by a quest
  -- title. Do not require an explicit dungeon, "quest" or a second role.
  local _, _, neededRole = string.find(text, "^ need ([%a]+) ")
  local _, _, neededAfterRole = string.find(text, "^ ([%a]+) needed ")
  local directRoleRequest = (neededRole and directNeedRoles[neededRole]) or
      (neededAfterRole and directNeedRoles[neededAfterRole])
  local roleDiscussion = somePhrase(text, {"heal potion", "healing potion",
      "heal spell", "healing spell", "dps meter", "dps addon", "dps advice",
      "dps guide", "dps rotation", "tank addon", "for my screenshot"})
  if directRoleRequest and roleDiscussion then directRoleRequest = false end
  local playerClass = any(text, playerClasses)
  local dungeon = any(text, dungeons)
  local activity = any(text, activities)
  -- A dungeon/raid + a player count + a class or group role is a strong
  -- roster signal in ANY order. The question mark is allowed ("DEADMINES
  -- 1DPS?"). Match both 1DPS/DPS1 and separate 1 DPS/DPS 1, avoiding a
  -- blacklist of dungeon names or individual ad strings.
  local dungeonRosterCount = false
  -- "17:00 ST" means server time, not Sunken Temple. Other dungeon
  -- names in the same message still count (e.g. "BRD 1DPS 17:00 ST").
  local rosterDungeon = dungeon
  if rosterDungeon and string.find(lower, "%d%d?:%d%d%s*st") then
    rosterDungeon = any(string.gsub(text, " st ", " "), dungeons)
  end
  if rosterDungeon then
    dungeonRosterCount = countedLfRoleOrClass or countedLookingRoleOrClass or
      ((role or playerClass) and separatePositiveCount(text)) or
      countedGroupTypeAnywhere(text, false) or
      countedGroupTypeAnywhere(text, true)
  end
  local summoning = any(text, {"summon","summons","summoning","sum","summ"})
  local typeCount = 0
  if any(text, {"tank","tanks"}) then typeCount = typeCount + 1 end
  if any(text, {"heal","heals","healer","healers","healing"}) then typeCount = typeCount + 1 end
  if any(text, {"dps","dd","dds"}) then typeCount = typeCount + 1 end
  -- Some scheduled PUG/raid ads do not use LF/LFM. A request for specific
  -- classes/roles ("Mages in demand", "Priests needed") combined with an
  -- organized group activity AND a schedule is still group recruitment.
  -- Never key off the advertised guild/raid name.  Both organization and
  -- an actual player-demand cue are required to avoid flagging WoW chat.
  local playerDemand = somePhrase(text, {"in demand", "still need", "need more",
      "looking for", "searching for", "seeking players"}) or
      any(text, {"needed", "wanted", "required"})
  local organizedGroup = any(text, {"pug", "pugs", "raid", "raids", "runs",
      "run", "raiding", "group", "groups"}) or
      somePhrase(text, {"raid team", "raid night", "raid nights"})
  local explicitWeekday = any(text, raidWeekdays) or any(text, raidDayAliases)
  local datedGroup = explicitWeekday or
      any(text, {"tonight", "tomorrow", "weekend", "weekends", "weekly"}) or
      somePhrase(text, {"raid schedule", "raid times", "server time"})
  local clockTime = string.find(message, "%d%d?:%d%d") ~= nil
  local scheduleContext = datedGroup or clockTime
  -- In World Chat, a dungeon/raid + weekday + clock time is a schedule
  -- advertisement even without LFM, a counted role or an invite. Word
  -- order does not matter, and conversational phrasing is not an exemption.
  local scheduledDungeonListing = explicitWeekday and clockTime and
      (rosterDungeon or organizedGroup)
  -- Queries and reports about player demand are not recruiting posts.
  local demandDiscussion = string.find(message, "?", 1, true) ~= nil or
      somePhrase(text, {"i heard", "i read", "someone said", "they said",
        "we discussed", "was discussing", "talking about", "last week",
        "last night", "yesterday", "people say", "what does", "what is",
        "the advertisement says", "the ad says", "i wonder"})
  local scheduledRoleDemand = playerDemand and (role or playerClass) and
      organizedGroup and scheduleContext and not demandDiscussion
  local plainDiscussion = string.find(message, "?", 1, true) or
      somePhrase(text, {"what does", "what is", "meaning of", "the phrase",
        "i heard", "someone said", "i ran", "i did", "we ran", "we did",
        "last night", "yesterday", "is this", "was it", "how do"})
  -- A destination follows a leading "LF" (e.g. LF Scarlet Graveyard),
  -- even if the sender omits LFG/LFM, dungeon initials or group counts.
  local leadingLfDungeon = prefixed and lf and dungeon and not plainDiscussion and
      not somePhrase(text, {"lf some advice", "lf advice", "lf tips",
        "lf some tips", "lf help with", "lf a name", "lf a cool",
        "looking for advice", "looking for tips"})
  -- A short leading NEED + number + role/class is a group-slot request.
  -- Guard against everyday need-a-potion or need-a-spell conversations.
  local needCountDiscussion = plainDiscussion or
      somePhrase(text, {"potion", "potions", "spell", "spells", "for my",
        "for your", "for this ability", "for this skill", "for my build"})
  local needRoleListing = countedNeedRoleOrClass and not needCountDiscussion and
      (dungeon or activity or contains(text, "for") or
       string.find(text, " %d+%s*[%a]+ $"))
  -- Dungeon-led compact rosters can contain either an extra role
  -- ("DEADMINES HEAL 2DPS") or just one counted slot ("DEADMINES 1DPS").
  -- For the single-slot form require exactly dungeon + count + role/class;
  -- this avoids blocking longer conversations mentioning the same shorthand.
  local singleSlotRoster = startsDungeon and standaloneCountedRole and
      string.find(text, "^ [%w]+ %d+%s*[%a]+ $") ~= nil
  local compactRosterListing = startsDungeon and standaloneCountedRole and
      (role or singleSlotRoster) and not plainDiscussion
  -- Require group formation semantics, not just dungeon names and class words.
  -- A standalone LF<number>M in a sentence about the shorthand is not an ad.
  -- When it does not lead the sentence, require group context before blocking.
  local slotDiscussion = somePhrase(text, {"what does", "what is", "what s",
      "meaning of", "how do you", "can anyone explain", "someone said",
      "i heard", "the term", "the phrase"}) and
      any(text, {"mean", "means", "meaning", "shorthand", "abbreviation"})
  local slotIntent = (hasLfSlots or lfmSlots) and not slotDiscussion and
      (prefixed or role or dungeon or activity or need or slots or any(text, contact))
  -- Discussion of an LF<number><class/role> shorthand must not trigger the
  -- strong group-search shortcut, even on Aggressive.
  local formatDiscussion = somePhrase(text, {"what does", "what is", "meaning of",
      "the term", "the phrase", "the abbreviation", "how to use",
      "how do you write", "someone said", "i heard", "people type",
      "people say", "can someone explain"})
  if (countedLfRoleOrClass or countedLookingRoleOrClass) and
      (slotDiscussion or formatDiscussion) and
      not dungeonRosterCount and not speakerRequest then return r end
  r.ignoreQuestionPenalty = directRoleRequest or speakerRequest or
      dungeonRosterCount or scheduledDungeonListing or directLfTarget
  r.intent = directRoleRequest or speakerRequest or scheduledDungeonListing or
      directLfTarget or dungeonRosterCount or
      scheduledRoleDemand or leadingLfDungeon or
      needRoleListing or compactRosterListing or
      countedLfRoleOrClass or countedLookingRoleOrClass or
    (explicit and (not (hasLfSlots or lfmSlots) or slotIntent)) or
    (lf and (role or dungeon or activity or (prefixed and playerClass))) or
    (looking and (role or contains(text, "group") or contains(text, "party"))) or
    (need and role and not roleDiscussion and
      (dungeon or activity or typeCount >= 2 or summoning)) or
    (slots and (role or dungeon or activity))
  if not r.intent then return r end
  if directLfTarget then add(r, 13, "leading LF with optional number + group target") end
  if directRoleRequest then add(r, 11, "direct Need <role> / <role> needed request") end
  if speakerRequest then add(r, 18, "LF/LFM/Looking for X speakers") end
  if dungeonRosterCount then add(r, 12, "dungeon + player slot + role/class in any order") end
  if scheduledDungeonListing then
    add(r, 12, "dungeon/raid + weekday + scheduled clock time")
  end
  if leadingLfDungeon then add(r, 5, "direct LF + dungeon destination") end
  if needRoleListing then add(r, 10, "numbered need for role/class") end
  if compactRosterListing then add(r, 10, "compact dungeon group roster") end
  if scheduledRoleDemand then
    add(r, 9, "scheduled group seeking roles/classes")
    add(r, 2, "organized raid/PUG/run")
    add(r, 2, "dated or timed event")
  end
  if countedLfRoleOrClass or countedLookingRoleOrClass then
    add(r, 10, "numbered role/class group request")
  end
  if explicit then
    local label = "LFG/LFM shorthand"
    if hasLfSlots then label = "LF <number>M group shorthand" end
    if lfmSlots then label = "LFM<number> group shorthand" end
    add(r, 8, label)
  end
  if lf and not explicit then add(r, 4, "LF shorthand") end
  if looking then add(r, 3, "looking-for intent") end
  if need then add(r, 3, "role request") end
  if slots then add(r, 4, "open group slots") end
  if prefixed and not explicit then add(r, 1, "leading LF") end
  if role then add(r, 3, "group role") end
  if playerClass and not role then add(r, 3, "player class") end
  if prefixed and lf and playerClass and not countedLfRoleOrClass then
    add(r, 3, "direct LF class request")
  end
  if dungeon then add(r, 2, "dungeon/raid alias") end
  if activity then add(r, 2, "group activity") end
  if typeCount >= 2 then add(r, 2, "multiple group roles") end
  if summoning then add(r, 1, "summon logistics") end
  if any(text, contact) then add(r, 1, "contact cue") end
  if string.find(text, " %d+ ") then add(r, 1, "slot count") end
  return r
end

-- Guild recruitment is multilingual, and can be implicit ("community searching", "recluta",
-- Latin-transliterated Russian). Combine recruitment language with raid/roster context;
-- guild, Discord and raid names are NEVER sufficient by themselves.
local function guild(text, lower, message)
  local r = newResult("Guild")
  -- Prefix is intentionally absolute: even questions or "not recruiting"
  -- that START with RU[-]GUILD are filtered in the World channel.
  if hasRuGuildPrefix(text) then
    r.intent = true
    r.ignoreQuestionPenalty = true
    add(r, 20, "RU/Russian guild prefix")
    return r
  end
  -- Explicit denial of recruitment is discussion, not an advertisement.
  if somePhrase(text, {"not recruiting", "not looking for recruits",
      "not accepting applications", "we are not recruiting",
      "aren t recruiting", "no recruitment"}) then return r end
  local community = any(text, {"community","communities"})
  local noun = any(text, guildNouns) or community or
      string.find(lower, "гильд", 1, true) ~= nil
  -- The tag is independent guild context; Swedish ads may use only <Name>.
  -- Match structure, never a specific guild/player name.
  local guildTag = string.find(message, "<[^<>]+>") ~= nil
  local roster = any(text, {"raiders","members","miembros","membros","igrokov","igroki", "players",
      "roster","rosters","rooster","roosters","healers","healer","tank","tanks","dps"}) or
      any(text, playerClasses)
  -- "main rooster" is a very common misspelling of "main roster" in ads.
  local team = any(text, {"team","teams","roster","rosters","rooster","roosters","static","statics"})
  local raid = any(text, {"raid","raids","raiding","mc","ony","naxx","aq40","bwl","k10","kara","zg"})
  local schedule = somePhrase(text, {"raid schedule","raid nights","raid times","raid timetable"}) or
      any(text, {"schedule","horario"})
  local discord = string.find(lower, "discord.gg/", 1, true) ~= nil or
      string.find(lower, "discord.com/invite/", 1, true) ~= nil
  local recruiting = any(text, recruit) or
      any(text, {"nabiraet","nabiraem","nabira","nabirayut","nabor","naborom"}) or
      string.find(lower, "набира", 1, true) ~= nil or
      string.find(lower, "набор", 1, true) ~= nil or
      string.find(lower, "рекрут", 1, true) ~= nil
  -- Czech/Slovak guild promotion: translate wording into *signals*, not a
  -- single blacklist phrase. Also recognizes accentless transliteration.
  -- "hledame aktivni jedince" + "PVE/ONY/MC", for example, is recruitment.
  local csSearch = any(text, {"hledame","hladame","shanime","nabirame",
      "prijimame","prijmeme","pribereme","zhaname","nabor","nabira","nabereme","prijima"})
  local csPeople = any(text, {"hrace","hracu","hracov","hraci","cleny", "clenu",
      "clenov","clenove","jedince","lidicky","lidi","aktivni","novacky",
      "veterany","posily","novych","novou","krev","spoluhrace"})
  local csGameContext = raid or any(text, {"pve","pvp","raidovani","raidi",
      "guild","gilda","gildy","guildy","gilde","cech","cechu","raidery","raideri","progress"})
  local csInvitation = somePhrase(text, {"otevira brany","otevirame brany",
      "otvira brany","otvirame brany","novou krev","nova krev",
      "pridej se k nam","pridaj sa k nam","radi vitame",
      "vitame nove","vitame novych","uvitame nove","uvitame novych","hledame nove cleny"})
  local csStrongInvite = somePhrase(text, {"otevira brany","otevirame brany",
      "otvira brany","otvirame brany","pridej se k nam","pridaj sa k nam",
      "radi vitame","vitame nove","vitame novych","uvitame nove","uvitame novych"})
  local csRecruitment =
      (csSearch and csPeople and csGameContext) or
      (csStrongInvite and csPeople and csGameContext) or
      (csInvitation and csSearch and csPeople)
  -- Swedish recruitment can advertise a tagged <Guild> without ever saying
  -- "guild" or "recruiting": "Levla, chilla eller raida? Alla ar valkomna".
  -- Require independent evidence: guild tag/noun, invitation and an activity
  -- pitch. These are WORD signals, never names or unrestricted substrings.
  local swInvite = somePhrase(text, {"alla roller ar valkomna", "alla ar valkomna",
      "alla klasser ar valkomna", "vi soker", "soker spelare", "soker fler",
      "vi rekryterar", "vi valkomnar", "vill du joina", "vill du raida",
      "hor av dig", "valkommen till var guild"})
  local swPromo = somePhrase(text, {"serverns basta", "svenska guild",
      "raids pa farm", "vi raider", "vill du", "allt fran"})
  local swActivity = any(text, {"levla", "levlar", "levela", "levelar",
      "lvla", "chilla", "chillar", "raida", "raidar", "raider",
      "raid", "raids", "raiding", "pve", "pvp", "dungeon", "dungeons"})
  -- Avoid mistaking quotations, translation requests or guild reports for ads.
  local swDiscussion = somePhrase(text, {"the guild says", "my guild says",
      "our guild says", "their guild says", "guild said", "guild says",
      "what does", "someone said", "i heard", "does anyone know",
      "the phrase", "vad betyder", "vad menas", "hur sager man",
      "jag horde", "jag laste", "jag sag", "jag undrar",
      "skrev att", "sager att", "sa att", "pratade om", "igar"})
  local swRecruitment = (noun or guildTag) and swInvite and
      (raid or roster or
       (noun and swPromo) or (guildTag and swActivity)) and
      not swDiscussion

  -- Polish recruitment: require player search/invitation + named group +
  -- independent WoW gameplay context. No blacklisted guild or player names.
  local plSearch = any(text, {"szuka", "szukamy", "szukaja", "poszukuje",
      "poszukujemy", "poszukuja", "rekrutuje", "rekrutujemy",
      "rekrutuja", "przyjmujemy", "nabor"})
  local plPeople = any(text, {"osob", "osoby", "graczy", "gracza",
      "ludzi", "czlonkow", "czlonka", "raiderow", "raidera",
      "aktywnych", "chetnych", "healerow", "tankow",
      "lvlujacych", "levelujacych", "levelujacy", "lvlujacy",
      "expijacych", "raidujacych"})
  local plTeam = any(text, {"gildia", "gildii", "druzyna", "druzyny",
      "ekipa", "ekipy", "klan", "klanu", "spolecznosc"})
  local plInvite = any(text, {"zapraszamy", "zaprasza", "dolacz",
      "dolaczcie", "dolaczaj", "wstap", "wstapcie"}) or
      somePhrase(text, {"dolacz do nas", "gramy razem"})
  -- "Do wspolnej zabawy/gry" alone is not proof of a WoW recruitment ad.
  -- Also avoid counting an explicitly NEGATED "WoW" ("nie WoW", "not WoW")
  -- as the gameplay signal for an otherwise unrelated group invitation.
  local plWow = contains(text, "wow") and not somePhrase(text, {
      "nie wow", "nie w wow", "nie do wow", "to nie wow",
      "nie chodzi o wow", "zamiast wow", "not wow", "not about wow"})
  local plGame = raid or plWow or
      any(text, {"rajd", "rajdy", "rajdow", "raidow", "raidy", "raidami",
          "raidach", "rajdami", "rajdach", "raidowanie",
          "pve", "pvp", "progres", "progress", "dungeony",
          "levelowanie", "expienie", "loot", "sr", "turtle",
          "turtla", "azeroth", "azerothu", "lvlowanie",
          "lvlowania", "levelowania", "lvlujacych",
          "levelujacych", "expijacych"}) or
      somePhrase(text, {"na rajdy", "na raidy", "na mc", "na bwl"})
  -- Exclude quoted adverts, translation questions and reports about guilds.
  local plDiscussion = somePhrase(text, {"co znaczy", "co oznacza",
      "co to znaczy", "co myslicie", "kto wie", "jaka to gildia",
      "slyszalem ze", "slyszalam ze", "czytalem ze",
      "czytalam ze", "ktos powiedzial", "widziales ze",
      "widzieliscie ze", "wczoraj", "kiedys", "cytuje",
      "pytam tylko", "pytanie o", "mowili ze",
      "czy ta gildia", "czy ten klan", "czy ktos wie",
      "widzalem ogloszenie", "widzialem ogloszenie",
      "widziales ogloszenie", "ogloszenie mowi",
      "ogloszenie pisze", "to cytat z",
      "widzialem ze", "widzialam ze", "widzielismy ze",
      "czy gildia", "czy polska gildia", "wiecie czy",
      "nie szukamy", "nie rekrutuje", "nie rekrutujemy",
      "nie przyjmujemy", "nie poszukujemy"}) or
      string.find(text, "^ czy ") ~= nil
  local plRecruitment = (guildTag or plTeam or noun) and plGame and
      ((plSearch and plPeople) or (plInvite and (guildTag or plTeam))) and
      not plDiscussion
  -- A Polish guild can announce its own recruitment without explicitly
  -- saying "players": "Polska gildia X rekrutuje. Robimy rajdy". The subject
  -- (gildia/gildii), direct recruitment verb, and WoW activity must all be
  -- present. A name or generic "rajdy" in conversation never suffices.
  local plDirectRecruit = any(text, {"rekrutuje", "rekrutuja",
      "rekrutujemy", "rekrutacja", "poszukuje", "poszukujemy",
      "przyjmuje", "przyjmujemy", "nabor", "nabory"})
  local plGuildSubject = any(text, {"gildia", "gildii", "guild"}) or
      (guildTag and plTeam)
  local plGuildAnnouncement = plGuildSubject and plDirectRecruit and
      plGame and not plDiscussion

  -- French guild recruitment frequently says "recrute tout joueur" or
  -- "nous sommes ouverts aux joueurs en lvling" rather than English role
  -- terms. A strong advertisement must combine guild identity, a recruitment
  -- action, a player audience, and independent WoW activity/context.
  -- Never key off the guild's name or a single French word.
  local frGroup = guildTag or noun or
      any(text, {"guilde", "guildes", "communaute", "clan"})
  local frRecruit = any(text, {"recrute", "recrutons", "recrutent",
      "recrutement", "recrutements", "recherchons", "recherche",
      "recherchent", "cherchons", "cherchent", "accueillons",
      "accueille", "accueillent", "acceptons", "rejoignez"}) or
      somePhrase(text, {"nous sommes ouverts", "nous sommes ouvertes",
          "sommes ouverts aux", "sommes ouvertes aux",
          "ouvert aux nouveaux", "ouverte aux nouveaux",
          "venez nous rejoindre", "rejoignez nous", "bienvenue a tous"})
  local frPeople = any(text, {"joueur", "joueurs", "membre", "membres",
      "raideur", "raideurs", "debutant", "debutants", "nouveaux",
      "nouvelles", "aventurier", "aventuriers", "personnes",
      "levelers", "lvling"}) or
      somePhrase(text, {"tout joueur", "tous les joueurs",
          "aux joueurs", "pour les joueurs", "tous niveaux",
          "tous les niveaux", "joueurs en leveling"})
  local frGame = raid or
      any(text, {"octo", "octowow", "wow", "turtle", "pve", "pvp",
          "raids", "raid", "leveling", "lvling", "donjon", "donjons",
          "quetes", "progression", "onyxia", "levelup"}) or
      somePhrase(text, {"contenu d octo", "contenu qu offre octo",
          "molten core", "ony clean", "mc clean", "en cours de leveling"})
  -- Reports, translations and questions containing a quoted recruitment
  -- sentence should stay visible, even when they name a tagged guild.
  local frDiscussion = string.find(message, "?", 1, true) ~= nil or
      somePhrase(text, {"est ce que", "quelqu un sait", "vous savez si",
          "savez vous si", "je me demande", "que signifie",
          "que veut dire", "qu est ce que", "qu en pensez vous",
          "j ai entendu", "j ai lu", "j ai vu", "on m a dit",
          "m a dit", "il parait que", "on dit que", "disent que",
          "le message dit que", "un message dit que", "ce message dit que",
          "sa pub dit que", "un joueur a dit que",
          "a dit que", "selon", "hier", "la semaine derniere",
          "je cite", "ils ont annonce", "leur annonce",
          "dans leur annonce", "ne recrute pas", "ne recrutent pas",
          "plus de recrutement", "recrutement ferme"})
  local frRecruitment = frGroup and frRecruit and frPeople and frGame and
      not frDiscussion
  -- A quoted French advertisement must not leak through the generic English
  -- score path (recrute + raid + message/contact). Only short-circuit when
  -- all four French-specific recruitment signals are present in a *report*.
  if frDiscussion and frGroup and frRecruit and frPeople and frGame then
    return r
  end

  -- Latin-script Russian recruitment: common spellings vary (ishet/ishchet,
  -- ishem/ischem, sobiraem/sobirayem, ...).  This is a COMBINATION rule,
  -- not a blacklist of specific messages or guild names. Require a search
  -- or team-assembly verb + people or team cues + WoW/guild context.
  local ruSearch = any(text, {"ishet","ischet","ishchet","ishut","ischut",
      "ishem","ischem","ishchem","ishim", "nabor",
      "nabiraet","nabiraem","nabirayem","nabirayut","nabira",
      "sobiraem","sobirayem","sobiraet","sobirayut"})
  local ruPeople = any(text, {"igrok","igroki","igrokov","igrokam","igrokami",
      "igrokovv","lyudey","lyudei","ludey","ludi","uchastnikov",
      "raiderov","raidery","rebyat","rebyata"})
  local ruTeam = any(text, {"core","statik","statica","kostyak","sostav",
      "statiku","static"})
  local ruContext = noun or raid or team or
      any(text, {"lvl","lvls","level","levels","pve","pvp","progress"})
  local ruDiscussion = somePhrase(text, {"what does", "what is", "what means",
      "can someone translate", "can you translate", "how do you say",
      "what s the meaning", "what is the meaning", "someone said",
      "i heard", "someone in our guild", "is this russian"})
  local ruRecruitment = not ruDiscussion and
      ((ruSearch and ruPeople and ruContext) or
       (ruSearch and ruTeam and (noun or raid or any(text, {"pve","pvp"}))))
  local welcome = any(text, {"welcome","willkommen","bienvenidos"})
  -- Direct contact + promotional audience language can be guild recruitment
  -- even without saying "guild" (e.g. "great place for returning players" / "whisper for invite").
  -- We require MULTIPLE cues to avoid classifying ordinary guild discussions.
  local guildCallToAction = somePhrase(text, {"whisper for invite","whisper for an invite",
      "whisper for invites","pst for invite","pm for invite","message for invite",
      "whisper for an invitation","whisper to join","whisper to get invited"})
  local communityPitch = somePhrase(text, {"great place for","a place for returning",
      "place for returning","home for returning","welcoming new players",
      "welcomes new players","new to octowow","new to turtle wow",
      "first time raiders","returning gamers","returning players",
      "new players welcome","find your flock","find your home","find a home",
      "all levels welcome"})
  local targetAudience = roster or any(text, {"returning","newcomers","newbies",
      "gamers","leveling","levelling","beginners","veterans","casuals"})
  local softRecruitment = guildCallToAction and communityPitch and targetAudience
  -- A guild may invite *regional/language-specific* players without mentioning
  -- raid roster or a schedule ("Guild ... looking for RU speaking players for PvP").
  -- Requiring roster/schedule previously let these clear adverts through.
  -- Require all three independent signals: guild identity, explicit search for
  -- members, and a promotional WoW community/activity pitch. A report or a
  -- question about another guild is not a recruitment advertisement.
  local memberSeeking = (any(text, {"searching", "seeking"}) or
      somePhrase(text, {"looking for", "looking 4", "searching for"})) and
      (roster or somePhrase(text, {"new members", "active members", "more members"}))
  local communityBenefits = any(text, {"pvp", "pve", "active", "online", "chill",
      "friendly", "casual", "hardcore", "events", "dungeons", "raids"}) or
      somePhrase(text, {"on farm", "every evening", "every night",
          "no rush", "positive vibe", "all content", "full content", "daily events"})
  local nonPromotionalQuestion = string.find(message, "?", 1, true) and
      not any(text, contact) and
      not any(text, {"wispate", "whispate", "whisperate", "scrivetemi"}) and
      not somePhrase(text, {"join us", "join our", "apply now", "for more info", "in privato"})
  local advertisementDiscussion = nonPromotionalQuestion or somePhrase(text, {
      "what does", "what is", "why is", "how do", "how can", "do you think",
      "i heard", "i read", "i saw", "someone said", "yesterday", "last night",
      "how can i", "is it normal", "any tips", "any advice", "what should",
      "the guild says", "their guild says", "someone in our guild",
      "the ad says", "the advertisement says", "the phrase"})
  local guildCommunityRecruitment = noun and memberSeeking and
      communityBenefits and not advertisementDiscussion
  -- Italian guild ads commonly use "reclutamenti" / "reclutiamo" instead of
  -- the English 'recruiting'. Detect the recruitment + member/community +
  -- contact *combination*, never the guild's name or an isolated Italian word.
  local italianRecruiting = any(text, {"reclutamenti", "reclutamento",
      "reclutiamo", "reclutano", "recluta", "reclutare", "reclutando",
      "cerchiamo", "cercasi"})
  local italianGroupContext = any(text, {"gilda", "gilde", "gruppo", "gruppi",
      "giocatori", "membri", "raider", "raiders", "team", "raid"}) or
      somePhrase(text, {"gruppo amichevole", "nuovi membri", "nuovi giocatori"})
  local italianContact = any(text, {"wispate", "whispate", "whisperate",
      "scrivetemi", "contattatemi", "contattateci", "whisper"}) or
      somePhrase(text, {"in privato", "scrivete in privato", "mandate un messaggio",
          "mandate un whisper", "unitevi a noi", "unisciti a noi", "vi aspettiamo"})
  local italianInvitation = somePhrase(text, {"in cerca di", "siamo alla ricerca",
      "apre i reclutamenti", "apriamo i reclutamenti", "cerchiamo giocatori",
      "cerchiamo membri", "cerca nuovi membri"})
  local italianDiscussion = advertisementDiscussion or
      somePhrase(text, {"cosa significa", "che significa", "sapete se",
          "ho sentito", "ho letto", "mi hanno detto", "non reclutiamo",
          "non cerchiamo", "non stiamo reclutando", "non sta reclutando",
          "reclutamenti chiusi", "ieri parlavo", "cosa sono i reclutamenti"})
  local italianGuildRecruitment = italianRecruiting and italianGroupContext and
      (italianContact or italianInvitation) and not italianDiscussion
  local invite = any(text, {"inviting","invite","invites","suchen","sucht","mitglieder","buscamos"}) or
      somePhrase(text, {"join us","join our","be part of","apply now","members wanted","spots open",
        "looking for new recruits","looking for recruits","recruits wanted","wanted recruits",
        "looking for members","looking for new members","seeking members","interested in adding"}) or
      string.find(lower, "приглаша", 1, true) ~= nil or
      string.find(lower, "ищем", 1, true) ~= nil or
      string.find(lower, "вступай", 1, true) ~= nil or
      string.find(lower, "принима", 1, true) ~= nil
  -- Some ongoing raid communities never use the word "guild": they advertise
  -- for players alongside RECURRING raid times and progression/roster details.
  -- This is NOT a blacklist of names, raid abbreviations, or raw "looking for".
  local openRoster = somePhrase(text, {"looking for players", "looking for more players",
      "looking for active players", "searching for players", "seeking players",
      "looking for raiders", "seeking raiders"})
  local recurringRaids = any(text, {"weekends", "weekly", "mondays", "tuesdays",
      "wednesdays", "thursdays", "fridays", "saturdays", "sundays"}) or
      somePhrase(text, {"every weekend", "each weekend", "every week",
         "raid nights", "raid schedule", "raiding schedule", "raids per week"})
  local progression = any(text, {"clears", "progression", "speedruns", "speedrun"}) or
      somePhrase(text, {"on farm", "farm status", "full clears", "mc clears"})
  local rosterStructure = string.find(text, " %d+ raids ") ~= nil or
      string.find(text, " %d+ man raids ") ~= nil or
      somePhrase(text, {"our raid teams", "our raid groups", "raid roster"})
  local rosterDiscussion = somePhrase(text, {"i read", "i saw", "someone said",
      "i heard", "what does", "what is", "why do", "can anyone explain",
      "the advertisement says", "the ad says"})
  local ongoingRaidRecruitment = openRoster and raid and not rosterDiscussion and
      ((recurringRaids and (progression or rosterStructure)) or
       (progression and rosterStructure) or
       (rosterStructure and team))
  -- German raid recruitment often uses "Raidplaetze frei" + "Gesucht" and
  -- localized class nicknames without the literal words "guild" or "LFM".
  -- normalize() folds umlauts: Raidplätze -> raidplatze. Require a player
  -- search, actual class/role and either open raid slots or a scheduled/
  -- counted raid. Never use a guild's or raid group's name as a trigger.
  local germanSearch = any(text, {"gesucht", "suchen", "suche", "sucht"})
  local germanOpenSlots = any(text, {"raidplatz", "raidplatze"}) and
      any(text, {"frei", "offen", "verfugbar"})
  local germanRoles = roster or any(text, {"healschami", "healdruid", "healpala",
      "healpriester", "schami", "retri", "heiler", "shadowpriester"})
  local germanCountedSlot = string.find(text, " %d+ ") ~= nil or
      string.find(text, " %d+[%a]+ ") ~= nil
  local germanTimedRaid = raid and string.find(message, "%d%d?:%d%d") ~= nil
  local germanDiscussion = advertisementDiscussion or somePhrase(text, {
      "was bedeutet", "was heisst", "wie meint", "ich habe gelesen",
      "ich habe gehort", "jemand sagte", "gestern", "letzte woche", "damals"})
  local germanRaidRecruitment = germanSearch and germanRoles and
      (germanOpenSlots or (raid and germanCountedSlot) or germanTimedRaid) and
      not germanDiscussion

  -- Social/community guild ads may invite casuals and levelers without
  -- advertising numbered raid spots. Require independent group identity,
  -- WoW gameplay, a promotional pitch, and a clear contact / join request
  -- (or an explicit member search). Do not classify ordinary references
  -- to raiding, a community or a lone "PM" as recruitment.
  local deGuild = guildTag or noun or
      any(text, {"gilde", "gilden", "gemeinschaft"})
  local deGameplay = raid or
      any(text, {"octowow", "turtle", "wow", "leveln", "leveling",
          "lvln", "raiden", "raide", "pve", "pvp", "dungeons",
          "dungeon", "questen", "quests"})
  local dePitch = any(text, {"community", "gemeinschaft", "casuals",
      "entspannte", "entspannt", "entspannten",
      "gemutlich", "gemutliche", "gemutlichen",
      "gemeinsam", "gemeinsame", "gemeinsamen", "zusammen",
      "freundlich", "locker", "lockere", "lockeren",
      "sozial", "hilfsbereit"}) or
      somePhrase(text, {"kein stress", "kein hardcore",
          "wir helfen", "neue spieler", "raids geplant"})
  local deContactVerb = somePhrase(text, {"melde dich", "meld dich",
      "meldet euch", "schreib uns", "schreib mir", "schreibt uns",
      "schreibt mir", "kontaktiere uns", "kontaktiert uns"})
  local deContactMeans = any(text, {"pm", "pn", "whisper", "wisp"}) or
      somePhrase(text, {"bei uns", "bei mir", "fur mehr infos",
          "fur mehr informationen", "fur infos", "fur eine einladung",
          "fur einladung", "um mitzumachen"})
  local deContact = deContactVerb and deContactMeans
  local deSearch = any(text, {"suchen", "suche", "sucht", "gesucht",
      "rekrutieren", "rekrutiert", "rekrutierung"}) or
      somePhrase(text, {"nehmen neue spieler auf",
          "neue spieler aufnehmen", "spieler willkommen"})
  local deAudience = any(text, {"mitspieler", "spieler", "mitglieder",
      "raider", "raiders", "casuals", "neulinge", "anfanger"})
  -- A rhetorical "Lust auf Community?" inside an advert is not discussion,
  -- but a quoted recruitment ad, information request, or denial is.
  local deDiscussion = germanDiscussion or
      somePhrase(text, {"was bedeutet", "was heisst", "was ist",
          "wie findet ihr", "wie kann ich", "wisst ihr ob",
          "ist das eine werbung", "in der anzeige", "in der werbung",
          "stand im text", "im text", "ich zitiere", "nur ein zitat",
          "ich habe gelesen", "ich habe gehort", "hat gesagt",
          "nicht fur wow", "nicht fur eine gilde",
          "keine neuen mitglieder", "wir rekrutieren nicht"})
  local deSocialInvitation = deGuild and deGameplay and dePitch and
      (deContact or (deSearch and deAudience)) and not deDiscussion

  -- Recruitment of named classes for a *recurring raid roster*. Require
  -- independent signals (player search + class, raid + weekly scheduling,
  -- organization/progression, and an invitation to contact the recruiter).
  -- Neither a guild name nor a mere reference to a guild is sufficient.
  local classSearch = (somePhrase(text, {"looking for", "looking 4"}) or
      any(text, {"searching", "seeking"})) and any(text, playerClasses)
  local dayCount = 0
  if classSearch and raid then
    local i
    for i=1,table.getn(raidWeekdays) do
      if contains(text,raidWeekdays[i]) then dayCount = dayCount+1 end
    end
  end
  local organizedRaids = any(text, {"prog","progress","progression","weekly","roster","team", "teams"}) or
       somePhrase(text, {"raid schedule","raid nights","every week","raids per week"})
  local recruitmentContact = any(text, contact) or discord or
       somePhrase(text, {"message me", "contact me", "apply now", "get in touch"})
  local scheduledClassRecruitment = classSearch and raid and
      (dayCount >= 2 or (dayCount >= 1 and organizedRaids)) and
      organizedRaids and recruitmentContact and not rosterDiscussion
  -- Emerging guilds often describe their *intention to form* a long-term
  -- raid team instead of saying "recruiting" or "looking for players".
  -- Require multiple independent signals: guild/community context, a team-
  -- formation phrase, and organized raiding context. Reject obvious reports,
  -- quotes, or requests for advice rather than recruitment offers.
  -- This recognizes families of adverts, not particular guild names.
  local formingRaidTeam = noun and team and raid and
      somePhrase(text, {"looking to build", "looking to form", "seeking to build",
          "seeking to form", "looking to assemble", "building a raid team",
          "forming a raid team", "building our raid team",
          "forming our raid team", "building a raiding team"})
  local formationDiscussion = somePhrase(text, {
      "what does", "what is", "how do", "how can", "any advice",
      "looking for advice", "asking for advice", "do you think",
      "someone said", "i heard", "i read", "i saw", "the ad says",
      "the advertisement says", "the guild says", "their guild says",
      "our guild was", "my guild was", "used to", "yesterday"})
  local guildFormationRecruitment = formingRaidTeam and not formationDiscussion and
      (schedule or any(text, contact) or
       somePhrase(text, {"for more info", "for more information",
           "raid nights", "raid times", "weekly raids", "raiding schedule"}) or
       (any(text, {"new", "fresh", "progression", "prog"}) and
          somePhrase(text, {"our raid team", "close knit raid team", "raid roster"})))
  local headline = somePhrase(text, {"looking for new recruits","looking for recruits","wanted recruits",
      "recruits wanted","looking for members","looking for new members","seeking members","interested in adding"})
  local promo = somePhrase(text, {"our guild","join our","join us","our team","our roster",
      "recruits based","looking for new","members wanted","now recruiting","currently recruiting",
      "we are recruiting","we re recruiting","wir sind","community gilde"})
  local searching = any(text, {"searching","seeking"}) or
      somePhrase(text, {"looking for","looking 4"})
  -- Searching alone is common conversation; demand a strong team/roster/raid context.
  -- Guild adverts often say "guilds, now looking for Mages/Shamans/Warlocks"
  -- without literally saying "recruiting". A guild/community + search intent
  -- + player/class needs + recruitment context must all be present.
  local searchingForGroup = searching and noun and roster and
      (team or raid or schedule or discord or
        somePhrase(text, {"now looking for", "currently looking for", "looking for raiders"}))
  local recruitingContext = roster or team or raid or schedule or discord or promo or
      any(text, {"wanted","looking","seeking","based","new","recruits"})
  -- Tagged guild recruiting is not necessarily a scheduled weekly roster.
  -- Recognize player/class search with optional adverbs, and Spanish
  -- community announcements like "comunidad activa ... te esperamos".
  local taggedSpeakerSearch = guildTag and hasSpeakerSearch(text)
  -- Direct invitations may advertise a named guild without using "recruiting",
  -- LFM or player-role requests: "Join THE CULT, we're a social guild".
  -- Only classify as Guild when a guild/community noun or <Guild Name> tag
  -- appears; an ordinary "Join the raid" is not a guild advertisement.
  local joinCallToAction = string.find(text, "^ join ") ~= nil or
      string.find(text, "^ come join ") ~= nil or
      string.find(text, "^ please join ") ~= nil or
      somePhrase(text, {"join us", "join our", "join my guild", "join the guild",
          "join our ranks", "come join", "invited to join"})
  local directGuildJoin = joinCallToAction and (noun or guildTag)
  local playerSearch = searching or somePhrase(text, {
      "looking mostly for", "looking mainly for", "looking primarily for",
      "now looking", "looking to recruit", "recruiting players"})
  local spanishInvitation = somePhrase(text, {
      "te esperamos", "los esperamos", "os esperamos",
      "susurro para inv", "susurro para invitacion", "susurro para invite",
      "susurrame para inv", "whisper para inv", "escribeme para inv",
      "escribenos para inv", "unete a nosotros", "unete al guild",
      "buscamos jugadores", "reclutamos jugadores"})
  local spanishCommunity = any(text, {"comunidad", "comunidades", "hermandad"}) or
      somePhrase(text, {"comunidad activa", "buena onda", "cero toxicidad"})
  local taggedClassRecruitment = (guildTag or noun) and playerSearch and
      (any(text, roles) or any(text, playerClasses)) and
      (team or raid or discord or noun or guildTag) and not advertisementDiscussion
  -- Guilds often recruit without mentioning classes, raids or the literal
  -- word "guild": <Secret Hideout> looking for friendly players ... welcome.
  -- The guild tag together with an explicit member search is sufficient.
  -- Recruitment may target a language/region rather than explicitly saying
  -- "players": "looking for English speakers ... /w your class & spec".
  -- Require a tagged group and searching/invitation context as before.
  local openAudience = any(text, {"players", "members", "raiders", "people",
      "recruits", "speakers", "speaker", "gamers", "folks", "newcomers"})
  local taggedOpenRecruitment = guildTag and openAudience and
      (playerSearch or (welcome and somePhrase(text, {
        "players are welcome", "members are welcome", "all players welcome",
        "all dedicated players", "everyone is welcome"}))) and
      not advertisementDiscussion
  local spanishGuildPromo = (guildTag or noun) and spanishInvitation and
      (raid or spanishCommunity) and not advertisementDiscussion
  -- Spanish recruitment may say just "recluta" with a member roster and
  -- activity, rather than using an explicit invite/contact phrase.
  local spanishRecruiting = any(text, {"recluta", "reclutamos", "reclutando",
      "reclutamiento", "reclutamientos"})
  local spanishOpenRecruitment = guildTag and spanishRecruiting and
      any(text, {"miembros", "jugadores", "players", "members"}) and
      (raid or discord or spanishCommunity) and not advertisementDiscussion

  -- Spanish guild showcases may omit "buscamos"/"reclutamos". Three independent
  -- signals must co-occur: (1) named guild + community/member pitch;
  -- (2) WoW raid/activity, including count-suffixed MC25/Kara10;
  -- (3) explicit contact request such as "/whisp para info".
  -- Never match named guilds themselves; single tokens cannot trigger this.
  local spanishShowcaseIdentity = (guildTag or
      any(text, {"gremio", "hermandad", "guild", "gilda"})) and
      (spanishCommunity or any(text, {"gremio", "hermandad"})) and
      any(text, {"miembros", "jugadores", "raiders", "integrantes"})
  local spanishShowcaseRaid = raid or
      any(text, {"raids", "raideo", "raideos", "pve", "pvp", "progresion",
          "progreso", "trash", "runs"}) or
      string.find(text, " mc%d+ ") ~= nil or
      string.find(text, " kara%d+ ") ~= nil or
      string.find(text, " zg%d+ ") ~= nil
  local spanishShowcaseContact = somePhrase(text, {
      "whisp para info", "wisp para info", "whisper para info",
      "susurro para info", "susurrame para info",
      "escribeme para info", "escribenos para info",
      "mensaje para info", "pm para info", "whisp para detalles",
      "whisper para detalles", "contactanos para info",
      "whisp para mas info", "manda whisp", "mandame whisper"
    }) or (any(text, {"whisp", "wisp", "whisper", "susurro",
            "susurrame"}) and
        somePhrase(text, {"para informacion", "mas informacion",
            "para detalles", "para unirte"}))
  local spanishShowcaseDiscussion = advertisementDiscussion or
      somePhrase(text, {"que significa", "que quiere decir", "que opinan",
          "alguien sabe", "ayer", "he leido", "he visto",
          "me dijeron", "me contaron", "dicen que", "su anuncio",
          "el anuncio", "anuncio dice", "hablando de",
          "es verdad que", "no estan reclutando", "no reclutan",
          "no buscamos miembros", "no buscamos jugadores"})
  local spanishGuildShowcase = spanishShowcaseIdentity and
      spanishShowcaseRaid and spanishShowcaseContact and
      not spanishShowcaseDiscussion

  -- Some guild showcases advertise a raid clear record and a website
  -- without any explicit "looking for"/"recruiting" verb.  Combined guild
  -- identity + raid content + clear ratios or external homepage are enough
  -- to identify such promotional posts in World; names/URLs are never listed.
  local guildWebsite = string.find(lower, "www.", 1, true) ~= nil or
      string.find(lower, "://", 1, true) ~= nil
  local raidProgress = string.find(message, "%d+%s*/%s*%d+") ~= nil
  local guildShowcase = guildTag and raid and
      ((noun and (raidProgress or guildWebsite)) or
       (raidProgress and guildWebsite))
  -- Explicit guild invitation + raid + time/timezone is a recruitment ad
  -- whatever its word order. A trailing '?' does not exempt this structure.
  local inviteCue = invite or spanishInvitation or
      any(text, {"inv", "invitar", "invitacion", "invitaciones"}) or
      somePhrase(text, {"whisper for invite", "ask for invite", "invite available"})
  local timeZone = any(text, {"gmt", "utc", "cet", "cest", "eet", "eest",
      "timezone", "serverzeit", "uhr"}) or
      somePhrase(text, {"server time", "realm time", "time zone"})
  local raidTime = string.find(message, "%d%d?:%d%d") ~= nil or timeZone
  local timedGuildInvitation = guildTag and inviteCue and raid and raidTime
  r.ignoreQuestionPenalty = timedGuildInvitation or taggedSpeakerSearch or directGuildJoin
  r.intent = headline or
      (noun and (recruiting or invite or (welcome and (any(text, contact) or promo)) or searchingForGroup)) or
      (recruiting and recruitingContext) or (invite and noun and promo) or
      csRecruitment or softRecruitment or swRecruitment or plRecruitment or
       plGuildAnnouncement or frRecruitment or ruRecruitment or
      guildCommunityRecruitment or italianGuildRecruitment or
      ongoingRaidRecruitment or guildFormationRecruitment or scheduledClassRecruitment or
       germanRaidRecruitment or deSocialInvitation or taggedClassRecruitment or taggedOpenRecruitment or
       spanishGuildPromo or spanishOpenRecruitment or spanishGuildShowcase or
       guildShowcase or timedGuildInvitation or taggedSpeakerSearch or directGuildJoin
  if not r.intent then return r end
  if taggedSpeakerSearch then
    add(r, 22, "tagged guild seeking X speakers")
  end
  if directGuildJoin then
    add(r, 12, "direct join invitation with guild/community context")
  end
  if taggedClassRecruitment then
    add(r, 10, "guild seeking classes/roles for roster")
    if discord then add(r, 2, "guild recruitment contact") end
  end
  if taggedOpenRecruitment then
    add(r, 12, "tagged guild recruiting players/members")
  end
  if spanishGuildPromo then
    add(r, 11, "Spanish community/guild invitation")
    if raid then add(r, 2, "raid activity advertised") end
  end
  if spanishOpenRecruitment then
    add(r, 20, "Spanish guild recruiting raid members")
  end
  if spanishGuildShowcase then
    add(r, 12, "Spanish guild/community showcase with contact invitation")
    add(r, 3, "members and raid/activity promotion")
    add(r, 2, "Spanish contact call-to-action")
  end
  if timedGuildInvitation then
    add(r, 12, "guild tag + invite + raid time/timezone")
  end
  if guildShowcase then
    add(r, 12, "tagged guild advertising raid progress/website")
    if raidProgress then add(r, 3, "raid clear progress") end
    if guildWebsite then add(r, 2, "guild website") end
  end
  if guildCommunityRecruitment then
    add(r, 8, "guild advertising for players with community/activity pitch")
    add(r, 3, "explicit member search")
    add(r, 2, "promotional community/activity context")
  end
  if italianGuildRecruitment then
    add(r, 8, "Italian member recruitment")
    add(r, 3, "guild/community recruitment context")
    if italianContact then add(r, 2, "direct contact invitation") end
  end
  if guildFormationRecruitment then
    add(r, 8, "guild formation/long-term raid team recruitment")
    if schedule then add(r, 2, "organized raid schedule") end
    if somePhrase(text, {"for more info", "for more information"}) then
      add(r, 2, "recruitment contact call-to-action")
    end
  end
  if ongoingRaidRecruitment then
    add(r, 7, "ongoing raid roster seeking players")
    if recurringRaids then add(r, 2, "recurring raid schedule") end
    if progression then add(r, 2, "raid progression/performance") end
    if rosterStructure then add(r, 2, "roster/raid structure") end
  end
  if scheduledClassRecruitment then
    add(r, 8, "scheduled raid roster seeking specific classes")
    add(r, 2, "recurring raid day(s) + organized progression")
    add(r, 2, "recruiter contact invitation")
  end
  if germanRaidRecruitment then
    add(r, 17, "German raid roster recruitment")
    if germanOpenSlots then add(r, 3, "open raid places") end
    if germanTimedRaid then add(r, 15, "scheduled raid time + German recruiter") end
  end
  if deSocialInvitation then
    add(r, 16, "German social guild inviting players")
    if deContact then add(r, 2, "direct German contact invitation") end
    if deSearch and deAudience then add(r, 2, "German player recruitment") end
  end
  if softRecruitment then
    add(r, 5, "guild-style invitation call-to-action")
    add(r, 4, "promotional community language")
    add(r, 2, "recruitment target audience")
  end
  if ruRecruitment then
    add(r, 5, "Russian-transliterated recruitment/assembly intent")
    if ruPeople then add(r, 3, "player/member search") end
    if ruTeam then add(r, 2, "team/core assembly") end
    if ruContext then add(r, 2, "guild/raid/level context") end
  end
  if swRecruitment then
    add(r, 10, "Swedish guild invitation/recruitment")
    if guildTag then add(r, 2, "guild tag with Swedish invitation") end
    if swActivity then add(r, 3, "Swedish gameplay/raid activity") end
    if swPromo then add(r, 2, "Swedish promotional context") end
  end
  if plRecruitment then
    add(r, 12, "Polish guild/team recruiting players for gameplay")
    if plSearch and plPeople then add(r, 3, "Polish player/member search") end
    if plTeam or guildTag then add(r, 2, "Polish guild/team identity") end
    if plInvite then add(r, 2, "Polish invitation") end
  end
  if plGuildAnnouncement then
    add(r, 14, "Polish guild explicitly recruiting for WoW activities")
    add(r, 2, "guild subject plus direct recruitment verb")
  end
  if frRecruitment then
    add(r, 12, "French guild recruiting players")
    add(r, 3, "French player/audience invitation")
    if guildTag then add(r, 2, "tagged guild advertising WoW content") end
  end
  if csRecruitment then
    if csSearch then add(r, 4, "Czech/Slovak recruitment intent") end
    if csPeople then add(r, 2, "Czech/Slovak member search") end
    if csInvitation then add(r, 4, "Czech/Slovak invitation phrase") end
    if csGameContext then add(r, 3, "Czech/Slovak WoW context") end
  end
  if noun then add(r, 3, "guild/community context") end
  if recruiting then add(r, 5, "recruitment language") end
  if invite then add(r, 4, "invitation language") end
  if searchingForGroup then add(r, 4, "guild roster/class search") end
  if welcome then add(r, 2, "welcome/invite cue") end
  if headline then add(r, 5, "recruitment phrase") end
  if promo then add(r, 2, "promotional phrasing") end
  if roster then add(r, 2, "member/class roster") end
  if team then add(r, 1, "team roster") end
  if raid then add(r, 1, "raid schedule or progress") end
  if schedule then add(r, 2, "schedule information") end
  if discord then add(r, 2, "Discord invitation link") end
  if any(text, contact) then add(r, 1, "contact cue") end
  if somePhrase(text, {"feeling lonely","are you lonely"}) then add(r, 2, "invitation opener") end
  return r
end

-- Detect direct LF + linked crafting recipe, including LF[Enchant ...] with
-- NO whitespace. Also understands native Vanilla craft hyperlinks like
-- |Henchant:, plus profession spell/tradeskill links with a craft-style title.
-- Item/quest/spell links and bracketed text alone are never blanket-blocked.
local lfCraftPrefixes = {
  "enchant", "enchanting", "formula", "recipe", "pattern", "plans",
  "plan", "schematic", "schematics", "design", "technique", "manual",
  "transmute", "alchemy", "blacksmithing", "tailoring", "leatherworking",
  "engineering", "jewelcrafting", "inscription", "cooking", "first aid"
}
local function isLeadingLfCraftLink(message)
  if type(message) ~= "string" or
      not string.find(message, "^%s*[Ll][Ff]") then return false end
  local display = stripMarkup(message)
  -- LF[recipe], LF [recipe], LF2[recipe], LF 2 [recipe].
  local _, _, count, tail = string.find(display, "^%s*[Ll][Ff]%s*(%d*)%s*(.*)$")
  if not tail or (count ~= "" and tonumber(count) and tonumber(count) <= 0) then
    return false
  end
  local _, endBracket = string.find(tail, "^%b[]")
  if not endBracket then return false end
  local label = normalize(string.sub(tail, 2, endBracket - 1))
  -- Enchant links identify crafting spells even when their display text
  -- contains no explicit profession keyword.
  if string.find(message, "|Henchant:", 1, true) or
      string.find(message, "|Htrade:", 1, true) or
      string.find(message, "|Htradeskill:", 1, true) then return true end
  local i
  for i=1,table.getn(lfCraftPrefixes) do
    local prefix = " " .. lfCraftPrefixes[i] .. " "
    if string.sub(label, 1, string.len(prefix)) == prefix then return true end
  end
  return false
end

local function trade(text, lower, message)
  local r = newResult("Trade")
  -- Crafting requests belong to Services, even if they use an item hyperlink.
  if isLeadingLfCraftLink(message) then return r end
  local shorthand = any(text, {"wts","wtb","wtt","wtbts","wtsg","wtbg"})
  local buySell = any(text, {"selling","buying","trading","sell","buy","trade","auctioning"})
  local goods = any(text, merchandise)
  local price = string.find(text, " %d+g ") or string.find(text, " %d+ gold ") or
                somePhrase(text, {"for gold","per stack","each stack","cheap price"})
  -- Direct seller headline: "SELLING FISH [Stonescale Eel]..." is clearly an
  -- offer even if no price is given and the goods are not in a fixed lexicon.
  -- Infer an advertisement from the *structure* of a leading SELLING clause,
  -- not from fish/item names. Questions and reflective/past-tense discussions
  -- about selling must still pass through as ordinary World conversation.
  local leadingSelling = string.find(text, "^ selling ") ~= nil
  local directSelling = false
  if leadingSelling and not string.find(message, "?", 1, true) then
    -- Lua 5.0 (Vanilla) supports captures through string.find; string.match
    -- is a newer Lua API and must not be used on the actual 1.18 client.
    local _, _, itemHead = string.find(text, "^ selling (%S+) ")
    local _, _, following = string.find(text, "^ selling %S+ (%S+) ")
    local hasObject = itemHead and itemHead ~= "is" and itemHead ~= "was" and
        itemHead ~= "can" and itemHead ~= "should" and itemHead ~= "means"
    local topicVerb = following == "is" or following == "was" or
        following == "were" or following == "can" or following == "could" or
        following == "should" or following == "would" or following == "means" or
        following == "makes" or following == "gets" or
        following == "seems" or following == "sounds" or
        following == "sucks"
    local discussion = somePhrase(text, {"is it worth", "is how i", "is how we",
        "was so", "was fun", "is a good way", "is the best way", "as a way to",
        "selling advice", "selling tips", "selling strategy", "selling is",
        "selling was", "selling can", "selling should", "selling means",
        "i was selling", "we were selling", "selling yesterday",
        "selling last night", "selling last week", "selling earlier",
        "is better than", "is how i", "is how we", "would be a",
        "made me", "gets you", "is profitable", "on the auction house is",
        "on the ah is", "is a pain", "on ah sucks"}) or
        any(text, {"yesterday", "profitable", "strategies"}) and
            not (price or any(text, contact))
    -- Discussion cannot become a Trade ad merely because it names gold,
    -- materials, or another token from the old merchandise lexicon.
    if (topicVerb or discussion) and not shorthand then return r end
    directSelling = hasObject and not topicVerb and not discussion
  end
  -- Short marketplace requests on World can be just "LF [item]", without
  -- WTB, gold, or a profession. Require a bracketed item directly after LF,
  -- with no long prose/question following it; arbitrary "LF" alone is safe.
  -- Works with WoW item links after stripMarkup, without any item-name list.
  local display = stripMarkup(message)
  local _, linkEnd = string.find(display, "^%s*[Ll][Ff]%s+%b[]")
  local shortItemRequest = false
  if linkEnd then
    local tail = string.sub(display, linkEnd + 1)
    tail = string.gsub(tail, "^%s+", "")
    local shortTail = normalize(tail)
    local buyCue = any(shortTail, {"pst", "whisper", "wisp", "tip", "tips", "paying",
         "mats", "materials", "offer", "gold"}) or string.find(shortTail, " %d+g ") ~= nil
    local question = string.find(tail, "?", 1, true) or
         somePhrase(shortTail, {"what does", "what is", "how do", "how to",
             "what about", "does this", "can anyone explain", "what s"})
    shortItemRequest = not question and
         (tail == "" or (string.len(tail) <= 40 and buyCue))
  end
  r.intent = shorthand or (buySell and (goods or price)) or shortItemRequest or directSelling
  if not r.intent then return r end
  if directSelling then add(r, 11, "leading SELLING merchandise offer") end
  if shortItemRequest then add(r, 11, "LF + bracketed item request") end
  if shorthand then add(r, 9, "WTS/WTB/WTT") end
  if buySell then add(r, 5, "buy/sell offer") end
  if goods then add(r, 3, "trade goods") end
  if price then add(r, 2, "price") end
  if any(text, contact) then add(r, 1, "contact cue") end
  return r
end

local function service(text, lower, message)
  local r = newResult("Services")
  local lfCraftLink = isLeadingLfCraftLink(message)
  local lfwToken = contains(text, "lfw")
  -- "LFW", "LF WORK" and "Looking for work" are equivalent, regardless
  -- of where they occur (e.g. "Goldsmith LF work [item]").
  local lfWorkPhrase = somePhrase(text, {"lf work", "lfwork", "looking for work"})
  local lfw = lfwToken or lfWorkPhrase
  local workDiscussion = somePhrase(text, {"what does", "what is", "what do",
      "does it mean", "mean by", "meaning of", "lfw mean", "lfw means", "lf work mean", "lf work means", "why does", "how much do",
      "how much does", "what do you think", "is it worth", "i heard",
      "someone said", "yesterday", "the term", "the phrase", "the ad says"}) and
      not any(text, {"pst", "whisper", "tip", "tips", "mats", "materials"})
  -- A question ABOUT "BS LFW" is still World conversation; a short
  -- "LFW?" is an advert asking for work, not an explanation.
  if lfw and workDiscussion then return r end
  local shortProfession = any(text, professionShort)
  local namedProfession = any(text, professionNames)
  local job = any(text, professions) or (shortProfession and lfw)
  local profession = shortProfession or namedProfession
  local serviceName = any(text, services)
  local offer = any(text, {"offering","offers","offer","available","crafting","commissions","commission",
       "service","services","orders","tips","tip","fee","fees","cheap","selling","wts","lfw",
       "work", "working", "for hire", "can craft", "will craft", "providing"})
  local price = any(text, {"gold","free","tips","tip","fee","fees","cheap","price","prices"})
  local request = any(text, contact)
  local linkedItem = string.find(message, "|Hitem:", 1, true) ~= nil or
      string.find(message, "%b[]") ~= nil
  -- A lone profession/shorthand in World is a short request/offer. In longer
  -- sentences require an actual trading/recruitment signal or item link.
  local _, _, loneWord = string.find(text, "^ ([%a]+) $")
  local bareProfession = (loneWord and professionTerms[loneWord]) or false
  local leadingLF = string.find(text, "^ lf ") ~= nil
  local _, _, firstLF = string.find(text, "^ lf ([%a]+) ")
  local _, _, firstLooking = string.find(text, "^ looking for ([%a]+) ")
  if firstLooking == "a" or firstLooking == "an" then
    local _, _, actual = string.find(text, "^ looking for a?n? ([%a]+) ")
    firstLooking = actual
  end
  local wantedProfession = (firstLF and professionTerms[firstLF]) or
      (firstLooking and professionTerms[firstLooking])
  local lookingForCraft = somePhrase(text, {"looking for someone to enchant",
      "looking for someone to craft", "lf weapon chain", "lf steel weapon chain"})
  local professionRequest = wantedProfession or lookingForCraft
  local ambiguousShort = any(text, {"fish", "mine", "fa", "skin"}) and not namedProfession
  local professionOffer = profession and not ambiguousShort and (linkedItem or request or
      any(text, {"offering", "offers", "available", "crafting", "commission",
        "commissions", "tips", "tip", "for hire", "can craft", "will craft",
        "orders", "service", "services", "wts"})) and not workDiscussion
  local mats = any(text, {"mats","materials"})
  local tips = any(text, {"tip","tips"}) or string.find(text, " %d+g ") ~= nil
  local materialsRequest = leadingLF and mats and tips
  -- Formatted service directories: "Player Summons: Town1,Town2,Town3,...".
  -- A summon mention by itself (e.g. chatting about a summon) is NOT enough.
  local colon = string.find(message, ":", 1, true)
  local commas = 0
  local destinationCount = 0
  if colon and colon < 55 and
       string.find(string.lower(string.sub(message, 1, colon)), "summons", 1, true) then
    local _, count = string.gsub(message, ",", "")
    commas = count
    if commas >= 3 then
      local i
      for i=1,table.getn(summonDestinations) do
        if contains(text, summonDestinations[i]) then destinationCount = destinationCount + 1 end
      end
    end
  end
  local summonDirectory = commas >= 3 and destinationCount >= 2 and
      not string.find(string.sub(message, 1, colon or 1), "?", 1, true)
  -- Price/speed/destination summon promotions may be formatted with brackets
  -- instead of a colon-separated directory. Combine multiple independent
  -- signals; a casual mention of "summons" or "3g" alone is not an ad.
  local mentionsSummons = any(text, {"summon", "summons", "summoning"})
  local summonFee = string.find(text, " %d+g ") ~= nil or
      any(text, {"free", "tip", "tips", "fees", "fee"})
  local summonSpeed = string.find(text, " under %d+ min") ~= nil or
      string.find(text, " within %d+ min") ~= nil or
      somePhrase(text, {"instant summon", "fast summons", "fast summoning", "quick summons"})
  local summonWhisper = string.find(string.lower(message), "/w", 1, true) ~= nil or
      any(text, {"pst", "whisper", "dm"})
  local destinations = false
  if mentionsSummons then
    local _, bracketDestinations = string.gsub(message, "%b[]", "")
    destinations = bracketDestinations >= 2
  end
  if not destinations and mentionsSummons then
    local i, n = 0, 0
    for i=1,table.getn(summonDestinations) do
      if contains(text, summonDestinations[i]) then n = n+1 end
    end
    destinations = n >= 2
  end
  local summonOfferDiscussion = somePhrase(text, {"what does", "what is", "how much",
      "how do", "how can", "did someone", "someone said", "i heard",
      "can anyone explain", "the ad says", "the advertisement says",
      "are summons", "why are summons", "what are summons"})
  local summonOffer = mentionsSummons and not summonOfferDiscussion and
      ((summonFee and (summonSpeed or summonWhisper or destinations)) or
       (summonSpeed and (destinations or summonWhisper)) or
       (destinations and summonWhisper))
  -- Taxi is commonly used as shorthand for paid summons.  Treat plain TAXI
  -- and obfuscated "T A X I" (including T.A.X.I / T-A-X-I after normalization)
  -- as a *service cue*, never as sufficient evidence by itself.  An actual
  -- offer must also provide fare/contact and/or a directory of destinations.
  -- No player, guild, or individual location is blacklisted.
  local taxiName = contains(text, "taxi") or phrase(text, "t a x i")
  local taxiOffer, taxiFare, taxiList, taxiPlaces, taxiBooking = false, false, false, 0, false
  if taxiName then
    local taxiQuestion = string.find(message, "?", 1, true) and
        (string.find(text, "^ do ") or string.find(text, "^ does ") or
         string.find(text, "^ did ") or string.find(text, "^ can ") or
         string.find(text, "^ would ") or string.find(text, "^ is ") or
         string.find(text, "^ are ") or string.find(text, "^ why ") or
         string.find(text, "^ what ") or string.find(text, "^ how "))
    local taxiDiscussion = taxiQuestion or somePhrase(text, {
      "what does", "what is", "what are", "how do", "how can", "how much",
      "can someone explain", "can anyone explain", "anyone know", "i heard",
      "someone said", "someone told", "the ad says", "the advertisement says",
      "the term", "the phrase", "talking about", "i hate", "tired of",
      "sick of", "stop posting", "stop spamming", "yesterday", "last night"
    })
    -- The existing normalizer turns "3Gold" into the single token "3gold".
    taxiFare = string.find(text, " %d+gold ") ~= nil or
               string.find(text, " %d+g ") ~= nil or
               string.find(text, " %d+gp ") ~= nil or
               somePhrase(text, {"free summons", "free taxi", "taxi free"})
    taxiBooking = request or string.find(string.lower(message), "/w", 1, true) ~= nil
    local _, plusCount = string.gsub(message, "%+", "")
    local _, commaCount = string.gsub(message, ",", "")
    -- Location names provide *context*, not individual blocking rules.
    local i
    for i = 1, table.getn(summonDestinations) do
      if contains(text, summonDestinations[i]) then taxiPlaces = taxiPlaces + 1 end
    end
    taxiList = plusCount >= 3 or (commaCount >= 3 and taxiPlaces >= 2)
    local mentionOffer = serviceName or any(text, {"service", "services", "available", "fast"})
    taxiOffer = not taxiDiscussion and (
      (taxiFare and (taxiList or taxiPlaces >= 2 or taxiBooking or mentionOffer)) or
      (taxiList and (taxiPlaces >= 2 or taxiBooking or mentionOffer)) or
      (taxiPlaces >= 3 and (taxiBooking or mentionOffer))
    )
  end
  -- "Do I need an enchanter?" has a profession, but no request listing.
  -- A leading LF + named profession is a direct request even when phrased
  -- as a brief question (LF JC?). Unlike a question ABOUT an LF phrase,
  -- its message starts with the actual request.
  r.ignoreQuestionPenalty = lfCraftLink or ((lfw or bareProfession or wantedProfession) and not workDiscussion)
  r.intent = lfCraftLink or (lfw and not workDiscussion) or bareProfession or professionOffer or
             (job and offer and (request or price or lfw)) or
             (serviceName and offer and (request or price or any(text,{"service","services","wts","selling"}))) or
             professionRequest or materialsRequest or summonDirectory or summonOffer or taxiOffer
  if not r.intent then return r end
  if lfCraftLink then add(r, 15, "LF + linked crafting/enchant recipe") end
  if lfw and not workDiscussion then
    add(r, 13, "LFW / LF WORK profession work advertisement")
  end
  if professionOffer then add(r, 12, "profession + item/contact/service offer") end
  if bareProfession then add(r, 12, "single-word profession request") end
  if professionRequest then
    add(r, 12, "LF/Looking for profession request")
    -- Item link + leading service request is stronger evidence than a lone
    -- shorthand ("LF LW") and can reach the Careful threshold as well.
    if leadingLF and (string.find(message, "|Hitem:", 1, true) or
                      string.find(message, "%b[]")) then
      add(r, 2, "requested craft with linked/named item")
    end
  end
  if materialsRequest then add(r, 8, "materials and tip for crafting") end
  if summonDirectory then
    add(r, 8, "summon service directory")
    add(r, 3, "multiple named destinations")
  end
  if summonOffer then
    add(r, 8, "summon service promotion")
    if summonFee then add(r, 3, "summon pricing/free offer") end
    if summonSpeed then add(r, 2, "summon turnaround promise") end
    if destinations then add(r, 2, "multiple destinations") end
    if summonWhisper then add(r, 2, "summon booking contact") end
  end
  if taxiOffer then
    add(r, 8, "TAXI summon service advertisement")
    if taxiFare then add(r, 3, "taxi fare") end
    if taxiList then add(r, 3, "multiple destinations listed") end
    if taxiPlaces >= 2 then add(r, 2, "named travel destinations") end
    if taxiBooking then add(r, 1, "booking contact") end
  end
  if lfw then add(r, 6, "looking for work") end
  if job then add(r, 3, "profession") end
  if shortProfession and (lfw or professionRequest or professionOffer) then
    add(r, 1, "profession abbreviation")
  end
  if serviceName then add(r, 3, "service type") end
  if offer then add(r, 3, "advertised offer") end
  if request then add(r, 1, "contact cue") end
  if price or tips then add(r, 2, "price/fee") end
  if somePhrase(text, {"weapon crusader","enchanter lfw","crafting orders","summon available"}) then
    add(r, 2, "service format")
  end
  return r
end

local classifiers = {guild, trade, service, lfg}
local settingNames = {Guild="filterGuild", Trade="filterTrade", Services="filterServices", LFG="filterLFG"}
local thresholds = {careful=10, balanced=7, aggressive=5}

function WCF.ClassifyMessage(message, allowDisabled)
  if type(message) ~= "string" then return nil, 0, "invalid message" end
  local raw = stripMarkup(message)
  local text = normalize(raw)
  local lower = lowerLanguages(raw)
  local penalty = questionPenalty(text, message)
  local best = nil
  local i
  for i = 1, table.getn(classifiers) do
    local r = classifiers[i](text, lower, message)
    local active = allowDisabled or (WCF.db and WCF.db[settingNames[r.category]])
    if r.intent and active then
      if not r.ignoreQuestionPenalty then
        r.score = r.score - penalty
        if r.score < 0 then r.score = 0 end
      end
      if not best or r.score > best.score then
        best = r
      end
    end
  end
  local sensitivity = (WCF.db and WCF.db.sensitivity) or "balanced"
  local threshold = thresholds[sensitivity] or 7
  if not best then return nil, 0, "no advertising intent", false, threshold end
  local why = table.concat(best.clues or {}, ", ")
  if penalty > 0 and not best.ignoreQuestionPenalty then
    why = why .. ", conversational/question penalty (-" .. penalty .. ")"
  end
  return best.category, best.score, why, best.score >= threshold, threshold
end

function WCF.IsAdvertisement(message)
  local category, score, why, blocked = WCF.ClassifyMessage(message)
  return blocked and true or false, category, score, why
end
