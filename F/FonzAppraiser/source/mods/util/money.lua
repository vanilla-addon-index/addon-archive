local A = FonzAppraiser
local L = A.locale

A.module 'util.money'

local COPPER_TO_SILVER = 100
local SILVER_TO_GOLD = 100
local COPPER_TO_GOLD = 10000
local DENOMINATIONS = { 1, COPPER_TO_SILVER, COPPER_TO_GOLD }
local _, _, DECIMAL_SEPARATOR = strfind(format("%.1f", 1/3), "(%D+)")


local COPPER = COPPER or L["COPPER"]
local SILVER = SILVER or L["SILVER"]
local GOLD = GOLD or L["GOLD"]

--Source: library "Abacus-2.0"
---[[
local COPPER_ABBR = strlower(strsub(COPPER, 1, 1))
local SILVER_ABBR = strlower(strsub(SILVER, 1, 1))
local GOLD_ABBR = strlower(strsub(GOLD, 1, 1))
if (strbyte(COPPER_ABBR) or 128) > 127 then
  -- non-western
  COPPER_ABBR = COPPER
  SILVER_ABBR = SILVER
  GOLD_ABBR = GOLD
end

local COLOR_WHITE = "ffffff"
local COLOR_GREEN = "00ff00"
local COLOR_RED = "ff0000"
local COLOR_COPPER = "eda55f"
local COLOR_SILVER = "c7c7cf"
local COLOR_GOLD = "ffd700"
--]]

local inf = 1/0
local abs = math.abs

function M.unitMoney(copper_value)
  local gold = floor(copper_value/COPPER_TO_GOLD)
  local silver = floor(mod(copper_value, COPPER_TO_GOLD)/COPPER_TO_SILVER)
  local copper = mod(copper_value, COPPER_TO_SILVER)

  return gold, silver, copper
end

function M.baseMoney(gold, silver, copper)
  return (gold or 0) * COPPER_TO_GOLD
    + (silver or 0) * COPPER_TO_SILVER
    + (copper or 0)
end

function M.stringToMoney(money_string)
  local _, _, num = strfind(money_string, "^%s*(%d+)%s*$")
  if num then return tonumber(num) end

  local pattern = format("^%%s*(%%d+%s%%d+)%%s*$",
    gsub(DECIMAL_SEPARATOR, "(%p)", "%%%1", 1))
  _, _, num = strfind(money_string, pattern)
  if num then return floor(tonumber(num)*COPPER_TO_GOLD) end

  local units = {0, 0, 0}
  local found = false
  for i,v in ipairs({COPPER_ABBR, SILVER_ABBR, GOLD_ABBR}) do
    local pattern = format("(%%d+)%%s*%s", v)
    gsub(money_string, pattern, function(num_string)
      units[i] = units[i] + tonumber(num_string)
      found = true
    end, 1)
  end
  if not found then return end

  local value = 0
  for i = 1,3 do
    value = value + units[i] * DENOMINATIONS[i]
  end
  return value
end

function M.extendedStringToMoney(money_string)
  local units = {}
  gsub(money_string, "%d+", function(num_string)
    tinsert(units, tonumber(num_string))
  end)
  local n = getn(units); if n < 1 then return end

  local value = 0
  -- Clamp to last 3 numbers (copper, silver, gold) to avoid
  -- picking up extra numbers from item links or other text.
  local use_n = (n > 3) and 3 or n
  for i = n, n - use_n + 1, -1 do
    local denom_index = n - i + 1
    local denom = DENOMINATIONS[denom_index]
    if denom then
      value = value + units[i] * denom
    end
  end
  return value
end

-- Helpers for currency message parsing/normalization
function M.isCurrencyMessage(text)
  if not text or text == "" then return false end
  local s = strlower(text)
  -- Require a number next to currency words or abbreviations to avoid
  -- false positives from random letters in system messages.
  local has_eng = strfind(s, "%d+%s*gold")
    or strfind(s, "%d+%s*silver")
    or strfind(s, "%d+%s*copp?er")
  local gold_word = GOLD and strlower(GOLD) or nil
  local silver_word = SILVER and strlower(SILVER) or nil
  local copper_word = COPPER and strlower(COPPER) or nil
  local has_loc = (gold_word and strfind(s, "%d+%s*" .. gold_word))
    or (silver_word and strfind(s, "%d+%s*" .. silver_word))
    or (copper_word and strfind(s, "%d+%s*" .. copper_word))
  local has_abbr = strfind(s, "%d+%s*[gsc]")
  return (has_eng or has_loc or has_abbr) and true or false
end

function M.normalizeCurrencyWords(text)
  local normalized = gsub(text or "", "[,%.]", "")
  normalized = gsub(normalized, "[Gg]old", "g")
  normalized = gsub(normalized, "[Ss]ilver", "s")
  normalized = gsub(normalized, "[Cc]opp?er", "c")
  if GOLD then
    normalized = gsub(normalized,
      format("(%%d+)%%s+%s", strlower(GOLD)),
      function(n) return n .. GOLD_ABBR end)
  end
  if SILVER then
    normalized = gsub(normalized,
      format("(%%d+)%%s+%s", strlower(SILVER)),
      function(n) return n .. SILVER_ABBR end)
  end
  if COPPER then
    normalized = gsub(normalized,
      format("(%%d+)%%s+%s", strlower(COPPER)),
      function(n) return n .. COPPER_ABBR end)
  end
  return normalized
end

function M.valueFromCurrencyText(text)
  if not text or text == "" then return end
  -- Внутри модуля читать нужно не через M.*, а напрямую:
  -- функции были записаны в среду (environment) метамеханикой A.module,
  -- поэтому чтение через M.* возвращает nil.
  local normalized = (normalizeCurrencyWords and normalizeCurrencyWords(text)) or text
  local s2m = stringToMoney
  if type(s2m) == "function" then
    local v = s2m(normalized)
    if v ~= nil then return v end
  end
  local e2m = extendedStringToMoney
  if type(e2m) == "function" then
    return e2m(text)
  end
end

--Source: library "Abacus-2.0"
function M.formatMoneyFull(value, colorize, textColor, zero_padding)
  local gold = abs(value / 10000)
  local silver = abs(mod(value / 100, 100))
  local copper = abs(mod(value, 100))

  local negl = ""
  local color = COLOR_WHITE
  if value > 0 then
    if textColor then
      color = COLOR_GREEN
    end
  elseif value < 0 then
    negl = "-"
    if textColor then
      color = COLOR_RED
    end
  end
  if not zero_padding then
    if colorize then
      if value == inf or value == -inf then
        return format("|cff%s%s|r", color, value)
      elseif value ~= value then
        return format("|cff%s0|r|cff%s%s|r", COLOR_WHITE, COLOR_COPPER, COPPER_ABBR)
      elseif value >= 10000 or value <= -10000 then
        return format("|cff%s%s%d|r|cff%s%s|r |cff%s%d|r|cff%s%s|r |cff%s%d|r|cff%s%s|r", color, negl, gold, COLOR_GOLD, GOLD_ABBR, color, silver, COLOR_SILVER, SILVER_ABBR, color, copper, COLOR_COPPER, COPPER_ABBR)
      elseif value >= 100 or value <= -100 then
        return format("|cff%s%s%d|r|cff%s%s|r |cff%s%d|r|cff%s%s|r", color, negl, silver, COLOR_SILVER, SILVER_ABBR, color, copper, COLOR_COPPER, COPPER_ABBR)
      else
        return format("|cff%s%s%d|r|cff%s%s|r", color, negl, copper, COLOR_COPPER, COPPER_ABBR)
      end
    else
      if value == inf or value == -inf then
        return format("%s", value)
      elseif value ~= value then
        return format("0%s", COPPER_ABBR)
      elseif value >= 10000 or value <= -10000 then
        return format("%s%d%s %d%s %d%s", negl, gold, GOLD_ABBR, silver, SILVER_ABBR, copper, COPPER_ABBR)
      elseif value >= 100 or value <= -100 then
        return format("%s%d%s %d%s", negl, silver, SILVER_ABBR, copper, COPPER_ABBR)
      else
        return format("%s%d%s", negl, copper, COPPER_ABBR)
      end
    end
  else
    if colorize then
      if value == inf or value == -inf then
        return format("|cff%s%s|r", color, value)
      elseif value ~= value then
        return format("|cff%s0|r|cff%s%s|r", COLOR_WHITE, COLOR_COPPER, COPPER_ABBR)
      elseif value >= 10000 or value <= -10000 then
        return format("|cff%s%s%d|r|cff%s%s|r |cff%s%02d|r|cff%s%s|r |cff%s%02d|r|cff%s%s|r", color, negl, gold, COLOR_GOLD, GOLD_ABBR, color, silver, COLOR_SILVER, SILVER_ABBR, color, copper, COLOR_COPPER, COPPER_ABBR)
      elseif value >= 100 or value <= -100 then
        return format("|cff%s%s%d|r|cff%s%s|r |cff%s%02d|r|cff%s%s|r", color, negl, silver, COLOR_SILVER, SILVER_ABBR, color, copper, COLOR_COPPER, COPPER_ABBR)
      else
        return format("|cff%s%s%d|r|cff%s%s|r", color, negl, copper, COLOR_COPPER, COPPER_ABBR)
      end
    else
      if value == inf or value == -inf then
        return format("%s", value)
      elseif value ~= value then
        return format("0%s", COPPER_ABBR)
      elseif value >= 10000 or value <= -10000 then
        return format("%s%d%s %02d%s %02d%s", negl, gold, GOLD_ABBR, silver, SILVER_ABBR, copper, COPPER_ABBR)
      elseif value >= 100 or value <= -100 then
        return format("%s%d%s %02d%s", negl, silver, SILVER_ABBR, copper, COPPER_ABBR)
      else
        return format("%s%d%s", negl, copper, COPPER_ABBR)
      end
    end
  end
end