-- Adapted from TokensWorth/ShaguTweaks-mods (MIT, original copyright GryllsAddons).

local T = ShaguTweaks.T
local Filter = ShaguTweaks.ExtrasChatFilter

local module = ShaguTweaks:register({
  title = T["Block NPC Spam"],
  description = T["Blocks known repetitive NPC say/yell spam messages."],
  expansions = { ["vanilla"] = true, ["tbc"] = nil },
  category = T["Chat"],
  enabled = nil,
})

local blockedEvents = {
  ["CHAT_MSG_MONSTER_SAY"] = true,
  ["CHAT_MSG_MONSTER_YELL"] = true,
}

local blockedNPCs = {}
local npcNames = {
  -- enUS
  "Tansy Sparkpen",
  "Fara Boltbreaker",
  "Shellcoin Promoter",

  -- ruRU
  "Зазывала ярмарки Новолуния",
  "Томас Миллер",
  "Уильям",
  "Донна",
  "Жюстина Демалье",
  "Мерлис Малаган",
  "Лиана Пирс",
  "Сюзанна",
  "Джейни Аншип",
}

for _, name in pairs(npcNames) do
  blockedNPCs[name] = true
  blockedNPCs[string.lower(name)] = true
end

local blockedPhrases = {
  { "shellcoin", "invest" },
  { "shells", "trade" },
  { "shells", "money" },
}

local function IsBlockedNPC(sender)
  if not sender then return false end
  return blockedNPCs[sender] or blockedNPCs[string.lower(sender)] or false
end

local function IsBlockedPhrase(message)
  if not message then return false end

  local normalized = string.lower(string.gsub(message, "[^A-Za-z0-9]", ""))

  for _, phrase in pairs(blockedPhrases) do
    local matched = true

    for _, word in pairs(phrase) do
      if not string.find(normalized, word, 1, true) then
        matched = false
        break
      end
    end

    if matched then return true end
  end

  return false
end

local function FilterNPCSpam(event)
  if not blockedEvents[event] then return false end
  if not arg1 or not arg2 then return false end

  return IsBlockedNPC(arg2) or IsBlockedPhrase(arg1)
end

module.enable = function(self)
  if Filter then
    Filter:Register("BlockNPCSpam", FilterNPCSpam)
  end
end

module.disable = function(self)
  if Filter then
    Filter:Unregister("BlockNPCSpam")
  end
end
