local AB = AshenBuilds

-- Profanity filter for community build names.
--  * Own names containing profanity can't be published.
--  * Names heard from other players are shown with the offending word masked
--    ("F******", "A**"), including leetspeak, stretched and spaced-out spellings.
--
-- Text is split into words at anything that isn't a letter (after leetspeak is
-- mapped), and each word is checked on its own. Checking across words made
-- ordinary phrases match ("Push It" -> "pushit" -> "shit"). Spelled-out words
-- ("f u c k", "f.u.c.k") are caught by joining runs of single letters.
--
-- ANYWHERE roots are long enough to be unambiguous, so they match inside a word
-- ("Fucking", "sh1tty"). WORD roots are short and appear inside ordinary words
-- (Assassination, Class, Peacock, Grapes), so they only match as a whole word,
-- optionally with a plural/verb ending. Every root also matches with its letters
-- repeated ("fuuuck", "asss").

local ANYWHERE = {"fuck", "fuk", "fck", "shit", "cunt", "nigger", "nigga", "faggot", "bitch", "whore", "twat",
  "retard", "bastard", "dildo", "porn", "penis", "vagina", "pussy", "slut", "asshole", "motherf", "cocksuck", "jerkoff",
  "piss", "tranny",
  -- Common letter swaps that leetspeak mapping doesn't cover.
  "phuck", "phuk", "fvck", "fvk", "shlt"}
local WORD = {"ass", "arse", "dick", "cock", "cum", "tit", "tits", "fag", "rape", "rapist", "nazi", "kys", "sex", "boob",
  "boobs", "hoe", "coon", "wank", "kike", "spic", "chink"}
local ENDINGS = {"", "s", "es", "ed", "er", "ers", "ing"}

-- Real words and names that contain a root. Compared against the whole word.
local ALLOW = {shiitake = true, scunthorpe = true, pissarro = true, penistone = true}
-- Allowed only when followed by one of these words: "Bastard Sword" is a weapon type.
local ALLOW_BEFORE = {bastard = {sword = true, swords = true}}

local LEET = {["0"] = "o", ["1"] = "i", ["!"] = "i", ["3"] = "e", ["4"] = "a", ["@"] = "a", ["5"] = "s", ["$"] = "s", ["7"] = "t", ["+"] = "t", ["8"] = "b", ["9"] = "g"}

-- "fuck" -> "f+u+c+k+", so repeated letters still match.
local function Stretch(root)
  local out, i = "", nil
  for i = 1, string.len(root) do out = out .. string.sub(root, i, i) .. "+" end
  return out
end

local ANYWHERE_PATTERNS, WORD_PATTERNS = {}, {}
do
  local i, j
  for i = 1, table.getn(ANYWHERE) do table.insert(ANYWHERE_PATTERNS, Stretch(ANYWHERE[i])) end
  for i = 1, table.getn(WORD) do
    for j = 1, table.getn(ENDINGS) do table.insert(WORD_PATTERNS, "^" .. Stretch(WORD[i]) .. ENDINGS[j] .. "$") end
  end
end

-- Splits text into lower-case words with leetspeak mapped. Each word keeps the
-- position in `text` of every letter, so matches can be masked in the original.
local function Words(text)
  local words, word = {}, nil
  local i, ch, low
  for i = 1, string.len(text) do
    ch = string.sub(text, i, i); low = LEET[ch] or string.lower(ch)
    if string.find(low, "^%a$") then
      if not word then word = {text = "", from = {}}; table.insert(words, word) end
      word.text = word.text .. low; table.insert(word.from, i)
    elseif string.byte(ch) < 128 then
      word = nil
    end
    -- Bytes of accented letters (UTF-8, 128+) are skipped without ending the word,
    -- so "Fück" is still one word ("fck").
  end
  return words
end

-- Runs of two or more single letters ("f u c k", "f.u.c.k") joined into one word.
local function SpelledOut(words)
  local out, run, i, j, w = {}, {}, nil, nil, nil
  local function flush()
    if table.getn(run) >= 2 then
      w = {text = "", from = {}}
      for j = 1, table.getn(run) do w.text = w.text .. run[j].text; table.insert(w.from, run[j].from[1]) end
      table.insert(out, w)
    end
    run = {}
  end
  for i = 1, table.getn(words) do
    if string.len(words[i].text) == 1 then table.insert(run, words[i]) else flush() end
  end
  flush()
  return out
end

local function Allowed(words, i)
  local w = words[i].text
  if ALLOW[w] then return true end
  local next = words[i + 1]
  return ALLOW_BEFORE[w] and next and ALLOW_BEFORE[w][next.text] and true or false
end

local function CheckWord(w, hits)
  local i, s, e
  for i = 1, table.getn(ANYWHERE_PATTERNS) do
    s = 1
    while true do
      s, e = string.find(w.text, ANYWHERE_PATTERNS[i], s)
      if not s then break end
      table.insert(hits, {w.from[s], w.from[e]}); s = e + 1
    end
  end
  for i = 1, table.getn(WORD_PATTERNS) do
    if string.find(w.text, WORD_PATTERNS[i]) then table.insert(hits, {w.from[1], w.from[string.len(w.text)]}); break end
  end
end

-- Returns a list of {first, last} character ranges in `text` that are profane.
local function FindProfanity(text)
  local words = Words(tostring(text or ""))
  local hits, i = {}, nil
  for i = 1, table.getn(words) do
    if not Allowed(words, i) then CheckWord(words[i], hits) end
  end
  local spelled = SpelledOut(words)
  for i = 1, table.getn(spelled) do CheckWord(spelled[i], hits) end
  return hits
end

function AB:IsProfane(text) return table.getn(FindProfanity(text)) > 0 end

-- Masks every profane word, keeping its first letter: "Kame Fucking Sucks Ass" -> "Kame F****** Sucks A**".
function AB:MaskProfanity(text)
  text = tostring(text or "")
  local hits = FindProfanity(text)
  if table.getn(hits) == 0 then return text end
  local mask, i, h, p = {}, nil, nil, nil
  for i = 1, table.getn(hits) do
    h = hits[i]
    -- Widen the hit to the whole word it sits in.
    local first, last = h[1], h[2]
    while first > 1 and not string.find(string.sub(text, first - 1, first - 1), "^%s$") do first = first - 1 end
    while last < string.len(text) and not string.find(string.sub(text, last + 1, last + 1), "^%s$") do last = last + 1 end
    for p = first + 1, last do mask[p] = true end
  end
  local out = {}
  for p = 1, string.len(text) do out[p] = mask[p] and "*" or string.sub(text, p, p) end
  return table.concat(out)
end
