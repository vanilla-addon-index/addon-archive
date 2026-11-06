pfUI:RegisterModule("translator", "vanilla", function ()
  -- ============================================================
  -- TRADUCTOR UNIVERSAL v7.0.0 — Legendary-Tier Sequito Edition
  -- Motor Hibrido Trilingue de Alto Rendimiento (ES / ZH / EN)
  -- 21 Mejoras: Stemming, Memoria, Bilingue, Historial, etc.
  -- ============================================================

  pfUI.translator_version = "7.0.0"

  local C = pfUI_config

  -- ============================================================
  -- CONFIGURACION POR DEFECTO (EXPANDIDA v7)
  -- ============================================================
  C.translator = C.translator or {}
  -- Core
  C.translator.enable        = C.translator.enable        or "1"
  C.translator.incoming      = C.translator.incoming      or "1"
  C.translator.outgoing      = C.translator.outgoing      or "1"
  C.translator.server_type   = C.translator.server_type   or "0"
  C.translator.direction     = C.translator.direction     or "0"
  C.translator.silent_mode   = C.translator.silent_mode   or "0"
  C.translator.wim_bridge    = C.translator.wim_bridge    or "1"
  C.translator.debug_mode    = C.translator.debug_mode    or "0"
  C.translator.ctr_threshold = C.translator.ctr_threshold or "1.00"
  -- Channels
  C.translator.chan_say         = C.translator.chan_say         or "1"
  C.translator.chan_party       = C.translator.chan_party       or "1"
  C.translator.chan_raid        = C.translator.chan_raid        or "1"
  C.translator.chan_guild       = C.translator.chan_guild       or "1"
  C.translator.chan_whisper     = C.translator.chan_whisper     or "1"
  C.translator.chan_world       = C.translator.chan_world       or "1"
  C.translator.chan_lfg         = C.translator.chan_lfg         or "1"
  C.translator.chan_bg          = C.translator.chan_bg          or "1"
  C.translator.chan_officer     = C.translator.chan_officer     or "1"
  C.translator.chan_raidwarning = C.translator.chan_raidwarning or "1"
  C.translator.chan_emote       = C.translator.chan_emote       or "0"
  C.translator.chan_trade       = C.translator.chan_trade       or "0"
  C.translator.mailbox          = C.translator.mailbox          or "0"
  -- NEW v7 Features
  C.translator.bilingual_mode  = C.translator.bilingual_mode  or "0"
  C.translator.lang_badge      = C.translator.lang_badge      or "0"
  C.translator.smart_filter    = C.translator.smart_filter    or "1"
  C.translator.stemming        = C.translator.stemming        or "1"
  C.translator.player_memory   = C.translator.player_memory   or "1"
  C.translator.sound_notify    = C.translator.sound_notify    or "0"
  C.translator.auto_prefix     = C.translator.auto_prefix     or "0"
  C.translator.tag_color       = C.translator.tag_color       or "0"
  C.translator.anti_spam       = C.translator.anti_spam       or "1"
  C.translator.history_enabled = C.translator.history_enabled or "1"
  C.translator.freq_tracking   = C.translator.freq_tracking   or "1"
  C.translator.blacklist       = C.translator.blacklist       or ""
  C.translator.custom_rules    = C.translator.custom_rules    or ""

  -- ============================================================
  -- ESTRUCTURA DE DICCIONARIOS V4 (Hibrida Trilingue)
  -- NOTA: Renombrado a LANG_PAIRS para NO sombrar el iterador
  --       global pairs() de Lua 5.0 (bug critico anterior).
  -- ============================================================
  pfUI.translator_dicts = pfUI.translator_dicts or {}
  local LANG_PAIRS = { "es_en", "en_es", "zh_en", "en_zh", "zh_es", "es_zh" }
  for _, p in ipairs(LANG_PAIRS) do
    pfUI.translator_dicts[p .. "_words"]   = pfUI.translator_dicts[p .. "_words"]   or {}
    pfUI.translator_dicts[p .. "_phrases"] = pfUI.translator_dicts[p .. "_phrases"] or {}
    pfUI.translator_dicts[p .. "_keys"]    = pfUI.translator_dicts[p .. "_keys"]    or {}
  end

  pfUI.translator_stats = pfUI.translator_stats or { total_in = 0, total_out = 0, cache_hits = 0 }

  -- ============================================================
  -- CACHE LRU CON INVALIDACION POR CONFIGURACION (#1)
  -- ============================================================
  local TR_CACHE       = {}
  local TR_CACHE_ORDER = {}
  local TR_CACHE_MAX   = 5000
  local TR_CACHE_CFG   = nil

  -- ============================================================
  -- COLA ASINCRONA PARA CACHE DE ITEMS (#2 Mejora WoWTranslate)
  -- Y COLA DLL UnitXP (#4 Fallback Asincrono)
  -- ============================================================
  local ITEM_CACHE_QUEUE = {}
  local DLL_PENDING = {}
  local DLL_REQUEST_COUNTER = 0
  local hasWoWTranslateDLL = false  -- se verifica en PLAYER_ENTERING_WORLD
  local LAST_DLL_POLL = 0
  
  local pfUIItemCacheTooltip = CreateFrame("GameTooltip", "pfUIItemCacheTooltip", nil, "GameTooltipTemplate")
  pfUIItemCacheTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

  local pfUIQueueFrame = CreateFrame("Frame")
  pfUIQueueFrame:SetScript("OnUpdate", function()
    local now = GetTime()
    for i = table.getn(ITEM_CACHE_QUEUE), 1, -1 do
      local q = ITEM_CACHE_QUEUE[i]
      if now - q.time > 0.2 then
        table.remove(ITEM_CACHE_QUEUE, i)
        if q.callback then q.callback() end
      end
    end
    
    -- #4 UnitXP/WoWTranslate Polling (solo si DLL confirmada)
    if hasWoWTranslateDLL and (now - LAST_DLL_POLL > 0.1) then
      LAST_DLL_POLL = now
      local success, result = pcall(UnitXP, "WoWTranslate", "poll")
      if success and result and result ~= "" then
        local firstPipe = strfind(result, "|", 1, true)
        if firstPipe then
           local reqId = strsub(result, 1, firstPipe - 1)
           local remainder = strsub(result, firstPipe + 1)
           local secondPipe = strfind(remainder, "|", 1, true)
           local translation, err
           if secondPipe then
              translation = strsub(remainder, 1, secondPipe - 1)
              err = strsub(remainder, secondPipe + 1)
           else
              translation = remainder
           end
           
           if reqId and DLL_PENDING[reqId] then
              local req = DLL_PENDING[reqId]
              DLL_PENDING[reqId] = nil
              if not err or err == "" then
                 if req.callback then req.callback(translation, false, nil) end
              else
                 if req.callback then req.callback(nil, true, err) end
              end
           end
        end
      end
      
      -- Cleanup timeouts (10s para chat)
      for id, req in pairs(DLL_PENDING) do
         if now - req.time > 10 then
            DLL_PENDING[id] = nil
            if req.callback then req.callback(nil, true, "TIMEOUT") end
         end
      end
    end
  end)

  local function CacheConfigHash()
    return (C.translator.direction or "0") .. ":" ..
           (C.translator.server_type or "0") .. ":" ..
           (C.translator.stemming or "1")
  end

  local function CacheCheckInvalidation()
    local h = CacheConfigHash()
    if TR_CACHE_CFG and TR_CACHE_CFG ~= h then
      TR_CACHE = {}
      TR_CACHE_ORDER = {}
      if pfUI_cache then
        pfUI_cache.translator_cache = nil
        pfUI_cache.translator_cache_order = nil
        pfUI_cache.translator_cache_cfg = nil
      end
      if C.translator.debug_mode == "1" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR]|r Cache invalidada por cambio de config.")
      end
    end
    TR_CACHE_CFG = h
  end

  local function CacheGet(text)
    CacheCheckInvalidation()
    local val = TR_CACHE[text]
    if val then
      for i = 1, table.getn(TR_CACHE_ORDER) do
        if TR_CACHE_ORDER[i] == text then
          table.remove(TR_CACHE_ORDER, i)
          table.insert(TR_CACHE_ORDER, text)
          break
        end
      end
      pfUI.translator_stats.cache_hits = pfUI.translator_stats.cache_hits + 1
      return val
    end
  end

  local function CacheSet(text, result)
    if not text or TR_CACHE[text] then return end
    if table.getn(TR_CACHE_ORDER) >= TR_CACHE_MAX then
      local oldest = table.remove(TR_CACHE_ORDER, 1)
      TR_CACHE[oldest] = nil
    end
    TR_CACHE[text] = result
    table.insert(TR_CACHE_ORDER, text)
    if pfUI_cache then
       pfUI_cache.translator_cache = TR_CACHE
       pfUI_cache.translator_cache_order = TR_CACHE_ORDER
       pfUI_cache.translator_cache_cfg = TR_CACHE_CFG
    end
  end

  -- ============================================================
  -- HELPER: Idioma del cliente local (centralizado)
  -- ============================================================
  local function GetMyLang()
    local locale = GetLocale()
    if locale == "esES" or locale == "esMX" then return "es" end
    if locale == "zhCN" or locale == "zhTW" then return "zh" end
    return "en"
  end

  -- Heuristica de Reino (Sequito Intelligence)
  pfUI.translator_realm_votes = pfUI.translator_realm_votes or { en = 0, es = 0, zh = 0, detected = nil }

  -- ============================================================
  -- #17: MICRO-STEMMER MORFOLOGICO
  -- ============================================================
  local ES_SUFFIXES = {
    "amiento", "imiento", "amente", "mente",
    "iendo", "ando", "endo",
    "cion", "sion",
    "aron", "ieron", "amos", "emos", "imos",
    "ado", "ido", "ada", "ida",
    "ando", "endo",
    "aba", "ias", "ias",
  }
  local EN_SUFFIXES = {
    "ation", "tion", "sion", "ness", "ment",
    "able", "ible", "ling", "ally", "edly",
    "ized", "ised",
    "ful", "less", "ous",
    "ing", "ers", "est",
    "ed", "ly", "er",
  }
  table.sort(ES_SUFFIXES, function(a, b) return strlen(a) > strlen(b) end)
  table.sort(EN_SUFFIXES, function(a, b) return strlen(a) > strlen(b) end)

  local function MicroStem(word, lang, wordDict)
    if not word or strlen(word) < 5 then return nil end
    if C.translator.stemming ~= "1" then return nil end
    local suffixes = (lang == "es") and ES_SUFFIXES or EN_SUFFIXES
    for _, suffix in ipairs(suffixes) do
      local slen = strlen(suffix)
      if strlen(word) > slen + 2 then
        local ending = strsub(word, -slen)
        if strlower(ending) == suffix then
          local root = strsub(word, 1, -(slen + 1))
          -- Intentar raiz directa
          if wordDict[root] then return wordDict[root] end
          -- Intentar variantes comunes
          if lang == "es" then
            local try = { root .. "ar", root .. "er", root .. "ir", root .. "o", root .. "a", root .. "e" }
            for _, v in ipairs(try) do
              if wordDict[v] then return wordDict[v] end
            end
          else
            local try = { root .. "e", root, strsub(root, 1, -2) }
            for _, v in ipairs(try) do
              if wordDict[v] then return wordDict[v] end
            end
          end
        end
      end
    end
    return nil
  end

  
  -- ============================================================
  -- #18: DISTANCIA DE LEVENSHTEIN (Fuzzy Matching)
  -- ============================================================
  local function Levenshtein(s1, s2)
    if s1 == s2 then return 0 end
    local len1 = strlen(s1)
    local len2 = strlen(s2)
    if len1 == 0 then return len2 end
    if len2 == 0 then return len1 end
    
    local matrix = {}
    for i = 0, len1 do
      matrix[i] = {[0] = i}
    end
    for j = 0, len2 do
      matrix[0][j] = j
    end
    
    for i = 1, len1 do
      for j = 1, len2 do
        local cost = (strbyte(s1, i) == strbyte(s2, j)) and 0 or 1
        local min = matrix[i-1][j] + 1
        local del = matrix[i][j-1] + 1
        local sub = matrix[i-1][j-1] + cost
        if del < min then min = del end
        if sub < min then min = sub end
        matrix[i][j] = min
      end
    end
    return matrix[len1][len2]
  end

  local function FuzzyMatch(word, dict)
    if strlen(word) < 4 then return nil end
    local best_match = nil
    local best_dist = 2
    for k, v in pairs(dict) do
      if strlen(k) >= strlen(word) - 1 and strlen(k) <= strlen(word) + 1 then
        local dist = Levenshtein(word, k)
        if dist <= 1 and dist < best_dist then
          best_dist = dist
          best_match = v
        end
      end
    end
    return best_match
  end

  -- ============================================================
  -- #19: PLAYER LANGUAGE MEMORY
  -- ============================================================
  pfUI_cache = pfUI_cache or {}
  pfUI_cache.translator_player_lang = pfUI_cache.translator_player_lang or {}
  local PLAYER_LANG_MEM = pfUI_cache.translator_player_lang

  local function RememberPlayerLang(sender, lang)
    if not sender or lang == "unknown" then return end
    if C.translator.player_memory ~= "1" then return end
    PLAYER_LANG_MEM[sender] = lang
    -- Proteccion contra overflow: si supera 500, limpiar todo
    local count = 0
    local k = next(PLAYER_LANG_MEM)
    while k do count = count + 1; k = next(PLAYER_LANG_MEM, k) end
    if count > 500 then
      pfUI_cache.translator_player_lang = {}
      PLAYER_LANG_MEM = pfUI_cache.translator_player_lang
    end
  end

  local function RecallPlayerLang(sender)
    if C.translator.player_memory == "1" and sender then
      return PLAYER_LANG_MEM[sender]
    end
    return nil
  end

  -- ============================================================
  -- #24: BLACKLIST
  -- ============================================================
  local BLACKLIST_CACHE = {}
  local BLACKLIST_DIRTY = true

  local function ParseBlacklist()
    if not BLACKLIST_DIRTY then return end
    BLACKLIST_CACHE = {}
    local bl = C.translator.blacklist or ""
    if bl ~= "" then
      for name in string.gfind(bl, "([^,]+)") do
        name = string.gsub(name, "^%s*(.-)%s*$", "%1")
        if name ~= "" then
          BLACKLIST_CACHE[strlower(name)] = true
        end
      end
    end
    BLACKLIST_DIRTY = false
  end

  local function IsBlacklisted(sender)
    ParseBlacklist()
    if not sender then return false end
    return BLACKLIST_CACHE[strlower(sender)] == true
  end

  -- ============================================================
  -- #31: ANTI-SPAM DEDUPLICATION
  -- ============================================================
  local RECENT_MSGS   = {}
  local RECENT_MAX    = 20
  local RECENT_WINDOW = 60

  local function IsSpamDuplicate(sender, body)
    if C.translator.anti_spam ~= "1" then return false end
    local now = GetTime()
    -- Limpiar entradas viejas
    local fresh = {}
    for i = 1, table.getn(RECENT_MSGS) do
      local e = RECENT_MSGS[i]
      if (now - e.time) < RECENT_WINDOW then
        table.insert(fresh, e)
      end
    end
    RECENT_MSGS = fresh
    -- Buscar duplicado
    local key = (sender or "") .. ":" .. strsub(body or "", 1, 80)
    for i = 1, table.getn(RECENT_MSGS) do
      if RECENT_MSGS[i].key == key then
        RECENT_MSGS[i].count = RECENT_MSGS[i].count + 1
        return true, RECENT_MSGS[i].count
      end
    end
    -- Agregar nuevo
    if table.getn(RECENT_MSGS) >= RECENT_MAX then
      table.remove(RECENT_MSGS, 1)
    end
    table.insert(RECENT_MSGS, { key = key, time = now, count = 1 })
    return false
  end

  -- ============================================================
  -- #9: TRANSLATION HISTORY (Ring Buffer)
  -- ============================================================
  local TR_HISTORY     = {}
  local TR_HISTORY_MAX = 50
  local TR_HISTORY_POS = 0

  local function AddToHistory(sender, original, translated, channel)
    if C.translator.history_enabled ~= "1" then return end
    TR_HISTORY_POS = TR_HISTORY_POS + 1
    if TR_HISTORY_POS > TR_HISTORY_MAX then TR_HISTORY_POS = 1 end
    TR_HISTORY[TR_HISTORY_POS] = {
      sender     = sender or "?",
      original   = strsub(original or "", 1, 120),
      translated = strsub(translated or "", 1, 120),
      channel    = channel or "?",
      time       = GetTime(),
    }
  end

  -- ============================================================
  -- #12: FREQUENCY TRACKER
  -- ============================================================
  local FREQ_TABLE = {}

  local function TrackFrequency(key)
    if C.translator.freq_tracking ~= "1" then return end
    FREQ_TABLE[key] = (FREQ_TABLE[key] or 0) + 1
  end

  -- ============================================================
  -- #3: CUSTOM RULES LOADER
  -- ============================================================
  local function ProcessCustomRules()
    local rules_str = C.translator.custom_rules or ""
    if rules_str == "" then return end
    local count = 0
    for entry in string.gfind(rules_str, "([^;]+)") do
      entry = string.gsub(entry, "^%s*(.-)%s*$", "%1")
      local p1 = strfind(entry, "|", 1, true)
      if p1 then
        local es = strsub(entry, 1, p1 - 1)
        local rest = strsub(entry, p1 + 1)
        local p2 = strfind(rest, "|", 1, true)
        if p2 then
          local en = strsub(rest, 1, p2 - 1)
          local zh = strsub(rest, p2 + 1)
          if es ~= "" and en ~= "" then
            pfUI.translator_dicts["es_en_words"][strlower(es)] = en
            pfUI.translator_dicts["en_es_words"][strlower(en)] = es
          end
          if en ~= "" and zh ~= "" then
            pfUI.translator_dicts["en_zh_words"][strlower(en)] = zh
            pfUI.translator_dicts["zh_en_words"][zh] = en
          end
          if es ~= "" and zh ~= "" then
            pfUI.translator_dicts["es_zh_words"][strlower(es)] = zh
            pfUI.translator_dicts["zh_es_words"][zh] = es
          end
          count = count + 1
        end
      end
    end
    if count > 0 and C.translator.debug_mode == "1" then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR]|r " .. count .. " reglas personalizadas cargadas.")
    end
  end

  -- ============================================================
  -- LOGICA TRILINGUE (Sequito Intelligence v4.2.1)
  -- ============================================================
  local function GetTranslationMode(isIncoming)
    local server    = C.translator.server_type or "0"
    local force_dir = C.translator.direction   or "0"
    local myLang    = GetMyLang()

    local env = "en"
    if server == "1" then
      env = "en"
    elseif server == "2" then
      env = "es"
    elseif server == "3" then
      env = "zh"
    elseif server == "0" then
      if pfUI.translator_realm_votes.detected then
        env = pfUI.translator_realm_votes.detected
      else
        env = (myLang == "es" or myLang == "zh") and "en" or "es"
      end
    end

    if not isIncoming then
      if env == myLang and server == "0" and force_dir == "0" then return nil, nil end
      if force_dir == "1" then return "es", "en" end
      if force_dir == "2" then return "en", "es" end
      if force_dir == "3" then return "zh", "en" end
      if force_dir == "4" then return "en", "zh" end
      if force_dir == "5" then return "es", "zh" end
      if force_dir == "6" then return "zh", "es" end
      return myLang, env
    else
      if force_dir == "1" then return "es", "en" end
      if force_dir == "2" then return "en", "es" end
      if force_dir == "3" then return "zh", "en" end
      if force_dir == "4" then return "en", "zh" end
      if force_dir == "5" then return "es", "zh" end
      if force_dir == "6" then return "zh", "es" end
      return env, myLang
    end
  end

  -- ============================================================
  -- MOTOR HIBRIDO (Corazon del sistema)
  -- ============================================================
  local function CountChineseChars(text)
    if not text or type(text) ~= "string" then return 0 end
    local count = 0
    local i     = 1
    local len   = strlen(text)
    while i <= len do
      local byte = strbyte(text, i)
      if byte >= 224 and byte <= 239 then
        count = count + 1
        i = i + 3
      elseif byte >= 192 and byte <= 223 then
        i = i + 2
      elseif byte >= 240 then
        i = i + 4
      else
        i = i + 1
      end
    end
    return count
  end

  -- CTR: Calcula el ratio de coherencia de la traduccion
  local function GetTranslationRatio(orig_text, dest_text, srcLang)
    if srcLang == "zh" then
      local orig_zh = CountChineseChars(orig_text)
      if orig_zh == 0 then return 1.0 end
      local dest_zh = CountChineseChars(dest_text)
      if dest_zh > 0 then return 0.0 end
      return (orig_zh - dest_zh) / orig_zh
    else
      local orig_words = {}
      local total = 0
      for w in string.gfind(orig_text, "([%a%d\128-\255]+)") do
        local lw = strlower(w)
        orig_words[lw] = (orig_words[lw] or 0) + 1
        total = total + 1
      end
      if total == 0 then return 1.0 end

      local dest_words = {}
      for w in string.gfind(dest_text, "([%a%d\128-\255]+)") do
        local lw = strlower(w)
        dest_words[lw] = (dest_words[lw] or 0) + 1
      end

      local unchanged = 0
      local w = next(orig_words)
      while w ~= nil do
        local cnt = orig_words[w]
        if dest_words[w] then
          local d = dest_words[w]
          unchanged = unchanged + (cnt < d and cnt or d)
        end
        w = next(orig_words, w)
      end

      return (total - unchanged) / total
    end
  end

  -- ============================================================
  -- MOTOR: LocalTranslate (#2 puntuacion, #17 stemming)
  -- ============================================================
  local function LocalTranslate(text, wordDict, phraseDict, phraseKeys, srcLang, buckets, noBrackets, ignore_missing_cache)
    if not text or type(text) ~= "string" or strlen(text) < 2 then return nil end

    local cached = CacheGet(text)
    if cached then return cached end

    -- Fase 0: Preservar y Traducir enlaces nativamente (Items, Spells, Players)
    local links      = {}
    local link_count = 0
    local proc_text  = text
    local missing_cache = false

    proc_text = string.gsub(proc_text, "(|c%x%x%x%x%x%x%x%x|H(.-)|h.-|h|r)", function(full_link, h_data)
      local _, _, itemID = strfind(h_data, "^item:(%d+)")
      if itemID then
        local itemName = GetItemInfo(tonumber(itemID))
        if itemName then
          local colorCode = strsub(full_link, 1, 10)
          full_link = colorCode .. "|H" .. h_data .. "|h[" .. itemName .. "]|h|r"
        elseif not ignore_missing_cache then
          missing_cache = true
          pfUIItemCacheTooltip:SetHyperlink("item:"..itemID..":0:0:0")
        end
      end
      
      local _, _, questID = strfind(h_data, "^quest:(%d+)")
      if questID and pfDB and pfDB["quests"] and pfDB["quests"]["enUS"] then
         local qEntry = pfDB["quests"]["enUS"][tonumber(questID)]
         if qEntry and type(qEntry) == "table" and qEntry.T then
            local colorCode = strsub(full_link, 1, 10)
            full_link = colorCode .. "|H" .. h_data .. "|h[" .. qEntry.T .. "]|h|r"
         end
      end

      link_count = link_count + 1
      links[link_count] = full_link
      return " http://ph.wt/" .. link_count .. " "
    end)
    
    -- Also handle links without colors
    proc_text = string.gsub(proc_text, "(|H(.-)|h.-|h)", function(full_link, h_data)
      if strfind(full_link, "http://ph%.wt/%d+") then return full_link end
      local _, _, itemID = strfind(h_data, "^item:(%d+)")
      if itemID then
        local itemName = GetItemInfo(tonumber(itemID))
        if itemName then
          full_link = "|H" .. h_data .. "|h[" .. itemName .. "]|h"
        elseif not ignore_missing_cache then
          missing_cache = true
          pfUIItemCacheTooltip:SetHyperlink("item:"..itemID..":0:0:0")
        end
      end
      link_count = link_count + 1
      links[link_count] = full_link
      return " http://ph.wt/" .. link_count .. " "
    end)

    if missing_cache then
       return nil, true
    end
    -- Preservar color codes sueltos
    proc_text = string.gsub(proc_text, "(|c%x%x%x%x%x%x%x%x.-|r)", function(cc)
      link_count = link_count + 1
      links[link_count] = cc
      return " http://ph.wt/" .. link_count .. " "
    end)

    -- #2: Normalizar puntuacion invertida espanola
    if srcLang ~= "zh" then
      proc_text = string.gsub(proc_text, "\194\191", " ") -- ¿
      proc_text = string.gsub(proc_text, "\194\161", " ") -- ¡
      proc_text = strlower(proc_text)
    end

    -- Fase 0.7: English Contraction Normalizer
    if srcLang == "en" then
      proc_text = string.gsub(proc_text, "can't", "cannot")
      proc_text = string.gsub(proc_text, "cant", "cannot")
      proc_text = string.gsub(proc_text, "don't", "do not")
      proc_text = string.gsub(proc_text, "dont", "do not")
      proc_text = string.gsub(proc_text, "i'm", "i am")
      proc_text = string.gsub(proc_text, "im", "i am")
      proc_text = string.gsub(proc_text, "it's", "it is")
      proc_text = string.gsub(proc_text, "i'll", "i will")
      proc_text = string.gsub(proc_text, "you're", "you are")
      proc_text = string.gsub(proc_text, "they're", "they are")
      proc_text = string.gsub(proc_text, "we're", "we are")
      proc_text = string.gsub(proc_text, "he's", "he is")
      proc_text = string.gsub(proc_text, "she's", "she is")
      proc_text = string.gsub(proc_text, "won't", "will not")
      proc_text = string.gsub(proc_text, "wont", "will not")
      proc_text = string.gsub(proc_text, "didn't", "did not")
      proc_text = string.gsub(proc_text, "didnt", "did not")
      proc_text = string.gsub(proc_text, "isn't", "is not")
      proc_text = string.gsub(proc_text, "isnt", "is not")
      proc_text = string.gsub(proc_text, "wasn't", "was not")
      proc_text = string.gsub(proc_text, "wasnt", "was not")
      proc_text = string.gsub(proc_text, "weren't", "were not")
      proc_text = string.gsub(proc_text, "werent", "were not")
      proc_text = string.gsub(proc_text, "aren't", "are not")
      proc_text = string.gsub(proc_text, "arent", "are not")
      proc_text = string.gsub(proc_text, "haven't", "have not")
      proc_text = string.gsub(proc_text, "havent", "have not")
      proc_text = string.gsub(proc_text, "hasn't", "has not")
      proc_text = string.gsub(proc_text, "hasnt", "has not")
      proc_text = string.gsub(proc_text, "hadn't", "had not")
      proc_text = string.gsub(proc_text, "hadnt", "had not")
      proc_text = string.gsub(proc_text, "wouldn't", "would not")
      proc_text = string.gsub(proc_text, "wouldnt", "would not")
      proc_text = string.gsub(proc_text, "couldn't", "could not")
      proc_text = string.gsub(proc_text, "couldnt", "could not")
      proc_text = string.gsub(proc_text, "shouldn't", "should not")
      proc_text = string.gsub(proc_text, "shouldnt", "should not")
      proc_text = string.gsub(proc_text, "let's", "let us")
    end

    proc_text = " " .. proc_text .. " "
    local trans_occurred = false

    -- Fase 0.5: Atomic Bracket Translation Shield (%b[])
    if not noBrackets then
      proc_text = string.gsub(proc_text, "(%b[])", function(bracketed_str)
        if strfind(bracketed_str, "http://ph%.wt/%d+") then
          return bracketed_str
        end
        local inner = strsub(bracketed_str, 2, -2)
        if inner and strlen(inner) >= 2 then
          local translated_inner = LocalTranslate(inner, wordDict, phraseDict, phraseKeys, srcLang, buckets, true)
          local replaced
          if translated_inner and translated_inner ~= inner then
            replaced = "[" .. translated_inner .. "]"
            trans_occurred = true
          else
            replaced = bracketed_str
          end
          link_count = link_count + 1
          links[link_count] = replaced
          return " http://ph.wt/" .. link_count .. " "
        end
        return bracketed_str
      end)
    end

    local dll_payload = strsub(proc_text, 2, -2)

    -- Fase 1: Greedy Matching (Frases Compuestas / UTF-8 Multibyte)
    if phraseDict and phraseKeys then
      local candidateKeys
      if buckets then
        candidateKeys = {}
        local unique_candidates = {}
        if srcLang == "zh" then
          local len = strlen(proc_text)
          local i = 1
          while i <= len do
            local b = string.byte(proc_text, i)
            local char_len = 1
            if b and b >= 224 and b <= 239 then char_len = 3
            elseif b and b >= 192 and b <= 223 then char_len = 2 end
            local ch = strsub(proc_text, i, i + char_len - 1)
            i = i + char_len
            if ch and ch ~= "" and ch ~= " " then
              local bucket = buckets[ch]
              if bucket then
                for _, k in ipairs(bucket) do
                  if not unique_candidates[k] then
                    unique_candidates[k] = true
                    table.insert(candidateKeys, k)
                  end
                end
              end
            end
          end
        else
          local wStart = 1
          local len = strlen(proc_text)
          while wStart <= len do
            local s, e = strfind(proc_text, "[%w_'-]+", wStart)
            if not s then break end
            local word = strsub(proc_text, s, e)
            if word and word ~= "" then
              local ch = strsub(word, 1, 1)
              local bucket = buckets[ch]
              if bucket then
                for _, k in ipairs(bucket) do
                  if not unique_candidates[k] then
                    unique_candidates[k] = true
                    table.insert(candidateKeys, k)
                  end
                end
              end
            end
            wStart = e + 1
          end
        end
        table.sort(candidateKeys, function(a, b) return strlen(a) > strlen(b) end)
      else
        candidateKeys = {}
        for _, k in ipairs(phraseKeys) do table.insert(candidateKeys, k) end
        table.sort(candidateKeys, function(a, b) return strlen(a) > strlen(b) end)
      end

      for _, key in ipairs(candidateKeys) do
        if strfind(proc_text, key, 1, true) then
          local safe_key = string.gsub(key, "([%.%*%-%?%[%]%(%)%^%$%%])", "%%%1")
          local res, count
          if srcLang == "zh" then
            res, count = string.gsub(proc_text, safe_key, " " .. phraseDict[key] .. " ")
          else
            local pattern = "(%A)(" .. safe_key .. ")(%A)"
            res, count = string.gsub(proc_text, pattern, "%1" .. phraseDict[key] .. "%3")
          end
          if count and count > 0 then
            proc_text = res
            trans_occurred = true
            TrackFrequency(key)
            if C.translator.debug_mode == "1" then
              DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR]|r Key Hit: " .. key)
            end
          end
        end
      end
    end

    -- Fase 2: Hash Lookup + #17 Stemming (Palabras Simples — solo occidentales)
    if wordDict and srcLang ~= "zh" then
      local hashed_text = string.gsub(proc_text, "([%a%d\128-\255]+)", function(w)
        local lower_w = strlower(w)
        if wordDict[lower_w] then
          trans_occurred = true
          TrackFrequency(lower_w)
          return wordDict[lower_w]
        end
        -- #17: Intentar stemming si no hay coincidencia exacta
        local stemmed = MicroStem(lower_w, srcLang, wordDict)
        if stemmed then
          trans_occurred = true
          return stemmed
        end
        -- #18: Intentar coincidencia difusa (errores de tipeo)
        local fuzzy = FuzzyMatch(lower_w, wordDict)
        if fuzzy then
          trans_occurred = true
          return fuzzy
        end
        return w
      end)
      proc_text = hashed_text
    end

    if trans_occurred then
      local result = strsub(proc_text, 2, -2)

      if srcLang == "zh" then
        result = string.gsub(result, "%s+", " ")
        result = string.gsub(result, "^%s*(.-)%s*$", "%1")
      end

      -- Validar coherencia (CTR)
      local ratio     = GetTranslationRatio(text, result, srcLang)
      local min_ratio = tonumber(C.translator.ctr_threshold or "1.00")
      if min_ratio == 0 then min_ratio = 1.00 end -- Fix para variables guardadas en 0.00
      if srcLang ~= "zh" and min_ratio == 1.00 then
         min_ratio = 0.50 -- Evita que un numero o nombre en occidente anule toda la traduccion local
      end

      if ratio < min_ratio then
        -- Siempre retorna proc_text/links para que el caller pueda usar DLL
        return nil, false, dll_payload, links
      end

      -- Restaurar enlaces protegidos de forma recursiva (hasta 5 niveles de anidamiento)
      if link_count > 0 then
         local passes = 0
         while passes < 5 and strfind(result, "http://ph%.wt/%d+") do
           passes = passes + 1
           local replaced = false
           result = string.gsub(result, "%s*http://ph%.wt/(%d+)%s*", function(lid)
             local id = tonumber(lid)
             if links[id] then
               replaced = true
               return links[id]
             end
           end)
           if not replaced then break end
         end
      end

      CacheSet(text, result)
      -- FIX: Siempre retorna proc_text+links para permitir escalado a DLL por el caller
      return result, false, dll_payload, links
    end
    -- No se pudo traducir nada. Solo retornamos proc_text/links si
    -- el texto tiene contenido extranjero detectable (para DLL fallback).
    return nil, false, dll_payload, links
  end

  -- ============================================================
  -- #4: DETECTOR DE IDIOMA EXPANDIDO (Marcadores + Bigramas + Diccionario)
  -- ============================================================
  local EN_MARKERS = {
    "the", "and", "you", "are", "for", "have", "with", "not", "this",
    "that", "but", "they", "from", "will", "what", "your", "know", "how",
    "well", "just", "about", "would", "could", "should", "been", "were",
    "don't", "can't", "won't", "didn't", "isn't", "wasn't",
    "there", "their", "which", "where", "when", "than", "then",
    "me", "go", "do", "help", "run", "kill", "tank", "heal", "dps", "guild",
    "camp", "tent", "inv", "invite", "group", "party", "raid", "wipe", "lag",
    "bad", "sorry", "good", "need", "want", "love", "like", "come", "get",
    "yes", "ok", "please", "plz", "pls"
  }
  local ES_MARKERS = {
    "que", "por", "una", "con", "los", "las", "del", "les", "como",
    "pero", "para", "este", "esta", "hay", "muy", "mas", "aqui", "todos",
    "bien", "donde", "porque", "cuando", "entre", "puede", "desde",
    "sobre", "tiene", "mejor", "otro", "otra", "mismo", "mucho",
    "tambien", "despues", "antes", "ahora", "siempre", "nunca",
    "el", "la", "un", "mi", "tu", "su", "me", "te", "nos", "se", "si", "no",
    "yo", "ya", "es", "son", "hola", "gracias", "porfa", "ayuda", "grupo",
    "tienda", "mazmo", "raids", "clan", "tengo", "quiero", "puedo", "hacer",
    "vamos", "ir", "quien", "por favor"
  }
  -- Bigramas de alta exclusividad
  local EN_BIGRAMS = { "th", "sh", "wh", "ck", "gh", "ph" }
  local ES_BIGRAMS = { "ue", "ie", "ll", "rr", "gu", "ci" }

  local function DetectLanguage(text)
    if not text then return "unknown" end
    -- Chino: deteccion directa por bytes UTF-8 CJK
    if CountChineseChars(text) > 0 then return "zh" end
    -- Occidental: marcadores + bigramas
    local lower = " " .. strlower(text) .. " "
    local en_hits, es_hits = 0, 0
    for _, w in ipairs(EN_MARKERS) do
      if strfind(lower, " " .. w .. " ", 1, true) then en_hits = en_hits + 1 end
    end
    for _, w in ipairs(ES_MARKERS) do
      if strfind(lower, " " .. w .. " ", 1, true) then es_hits = es_hits + 1 end
    end
    -- #4: Bigramas como peso secundario
    local lower_raw = strlower(text)
    for _, bg in ipairs(EN_BIGRAMS) do
      if strfind(lower_raw, bg, 1, true) then en_hits = en_hits + 0.3 end
    end
    for _, bg in ipairs(ES_BIGRAMS) do
      if strfind(lower_raw, bg, 1, true) then es_hits = es_hits + 0.3 end
    end

    -- Motor de votos por diccionario de palabras (es_en_words / en_es_words)
    local en_dict_hits, es_dict_hits = 0, 0
    for w in string.gfind(lower, "([%a%d'-]+)") do
      if strlen(w) >= 3 then
        if pfUI.translator_dicts["es_en_words"] and pfUI.translator_dicts["es_en_words"][w] then
          es_dict_hits = es_dict_hits + 1
        end
        if pfUI.translator_dicts["en_es_words"] and pfUI.translator_dicts["en_es_words"][w] then
          en_dict_hits = en_dict_hits + 1
        end
      end
    end
    en_hits = en_hits + en_dict_hits * 1.5
    es_hits = es_hits + es_dict_hits * 1.5

    if en_hits > es_hits and en_hits >= 1 then return "en" end
    if es_hits > en_hits and es_hits >= 1 then return "es" end

    -- Fallback: para mensajes muy cortos, inferir idioma desde el diccionario
    -- Solo aplica si es una sola palabra o texto corto sin marcadores
    if strlen(text) <= 30 then
      local first_word = strlower(string.gsub(text, "^%s*([%a%d'-]+).*", "%1"))
      if first_word and first_word ~= "" then
        if pfUI.translator_dicts["es_en_words"] and pfUI.translator_dicts["es_en_words"][first_word] then return "es" end
        if pfUI.translator_dicts["en_es_words"] and pfUI.translator_dicts["en_es_words"][first_word] then return "en" end
      end
    end
    return "unknown"
  end


  -- ============================================================
  -- #20 #27: SEGURIDAD Y CANALES (expandido)
  -- ============================================================
  local function IsChanEnabled(chatType)
    if not C.translator or C.translator.enable ~= "1" then return false end
    local lower = strlower(chatType or "")
    if strfind(lower, "say")            then return C.translator.chan_say         == "1" end
    if strfind(lower, "party")          then return C.translator.chan_party       == "1" end
    if strfind(lower, "raid_warning")   then return C.translator.chan_raidwarning == "1" end
    if strfind(lower, "raid")           then return C.translator.chan_raid        == "1" end
    if strfind(lower, "guild")          then return C.translator.chan_guild       == "1" end
    if strfind(lower, "officer")        then return C.translator.chan_officer     == "1" end
    if strfind(lower, "whisper")        then return C.translator.chan_whisper     == "1" end
    if strfind(lower, "battleground")   then return C.translator.chan_bg          == "1" end
    if strfind(lower, "world")          then return C.translator.chan_world       == "1" end
    if strfind(lower, "lfg")            then return C.translator.chan_lfg         == "1" end
    if strfind(lower, "channel")        then return C.translator.chan_world       == "1" end
    if strfind(lower, "emote")          then return C.translator.chan_emote       == "1" end
    if strfind(lower, "text_emote")     then return C.translator.chan_emote       == "1" end
    return false
  end

  -- ============================================================
  -- #30: GetTRTag CON SOPORTE DE COLOR CONFIGURABLE
  -- ============================================================
  local _tr_tag_cache = nil
  local function GetTRTag()
    if _tr_tag_cache ~= nil then return _tr_tag_cache end
    if not C.translator or C.translator.silent_mode == "1" then
      _tr_tag_cache = ""
      return _tr_tag_cache
    end
    local color_mode = C.translator.tag_color or "0"
    local color_code = "|cff33ffcc" -- Normal (verde azulado)
    if color_mode == "1" then
      color_code = "|cffffff00" -- Alto Contraste (amarillo)
    elseif color_mode == "2" then
      color_code = "|cff888888" -- Discreto (gris)
    end
    _tr_tag_cache = " " .. color_code .. "[TR]|r"
    return _tr_tag_cache
  end

  -- ============================================================
  -- #11: LANGUAGE BADGE
  -- ============================================================
  local LANG_BADGES = {
    en = "|cff44ff44[EN]|r ",
    es = "|cffff6644[ES]|r ",
    zh = "|cffffff44[ZH]|r ",
  }

  local function GetLangBadge(lang)
    if C.translator.lang_badge ~= "1" then return "" end
    return LANG_BADGES[lang] or ""
  end

  -- ============================================================
  -- #22: SOUND NOTIFICATION
  -- ============================================================
  local SOUND_LAST_TIME = 0
  local SOUND_THROTTLE  = 3

  local function PlayTranslateSound()
    if C.translator.sound_notify ~= "1" then return end
    local now = GetTime()
    if (now - SOUND_LAST_TIME) < SOUND_THROTTLE then return end
    SOUND_LAST_TIME = now
    PlaySound("igMiniMapZoomIn")
  end

  -- ============================================================
  -- GESTION DE SALIDA (#26 Auto-Prefix)
  -- ============================================================
  local function TranslateOutgoing(msg, chatType, channel)
    if not msg or strfind(msg, "^[/%.!]") then return nil end
    if not C.translator or C.translator.enable ~= "1" or C.translator.outgoing ~= "1" then return nil end
    if not IsChanEnabled(chatType) then return nil end

    local myLang = GetMyLang()
    local src = myLang
    local dest = nil

    -- 1. Intentar autodetectar idioma del destinatario si es un susurro o mensaje dirigido
    local target_lang = nil
    local addressed_player = nil
    local msg_body = msg

    if strlower(chatType or "") == "whisper" and channel and channel ~= "" then
      target_lang = RecallPlayerLang(channel)
    else
      -- Buscar si empieza con "Nombre: " o "Nombre, "
      local _, _, possible_target, rest = strfind(msg, "^([%a%d\128-\255]+)%s*[:%,]%s*(.*)$")
      if possible_target and rest and rest ~= "" then
        local lang_check = RecallPlayerLang(possible_target)
        if lang_check then
          target_lang = lang_check
          addressed_player = possible_target
          msg_body = rest
        end
      end
    end

    if target_lang and target_lang ~= "unknown" then
      if target_lang == myLang then
        -- Mismo idioma que el cliente local, no es necesario traducir
        return nil
      else
        dest = target_lang
      end
    else
      -- Fallback al comportamiento original (entorno/servidor)
      local mode_src, mode_dest = GetTranslationMode(false)
      if mode_src and mode_dest then
        src = mode_src
        dest = mode_dest
      end
    end

    if not dest or src == dest then return nil end

    local prefix  = src .. "_" .. dest
    local words   = pfUI.translator_dicts[prefix .. "_words"]
    local phrases = pfUI.translator_dicts[prefix .. "_phrases"]
    local keys    = pfUI.translator_dicts[prefix .. "_keys"]
    local bkts    = pfUI.translator_dicts[prefix .. "_buckets"]

    if not words or not phrases then return nil end

    local trans = LocalTranslate(msg_body, words, phrases, keys, src, bkts)
    if trans then
      pfUI.translator_stats.total_out = pfUI.translator_stats.total_out + 1

      -- Si fue un mensaje dirigido a un jugador en canal público/grupal, reconstruir con el nombre
      if addressed_player then
        trans = addressed_player .. ": " .. trans
      end

      -- #26: Auto-prefix
      if C.translator.auto_prefix == "1" then
        local prefix_tag = "[" .. strupper(myLang) .. "] "
        trans = prefix_tag .. trans
      end
      return trans
    end
    return nil
  end

  -- ============================================================
  -- SECURE HOOK OUTGOING (sin cambios de logica)
  -- ============================================================
  local function SecureHookOutgoing()
    if pfUI.GravityTROutHooked then return end

    local originalChatEditSend = ChatEdit_SendText
    ChatEdit_SendText = function(editBox, addHistory)
      local msg = editBox:GetText()
      if msg and msg ~= "" then
        local trans = TranslateOutgoing(msg, editBox.chatType, editBox.channelTarget)
        if trans then
          pfUI.translator_sending_translated = true
          editBox:SetText(trans)
        end
      end
      local ret = originalChatEditSend(editBox, addHistory)
      pfUI.translator_sending_translated = nil
      return ret
    end

    local originalSendChatMessage = SendChatMessage
    SendChatMessage = function(msg, chatType, language, channel)
      if pfUI.translator_sending_translated then
        return originalSendChatMessage(msg, chatType, language, channel)
      end
      local trans = TranslateOutgoing(msg, chatType, channel)
      return originalSendChatMessage(trans or msg, chatType, language, channel)
    end

    if ChatThrottleLib then
      local originalCTLSend = ChatThrottleLib.SendChatMessage
      ChatThrottleLib.SendChatMessage = function(self, prio, msg, chatType, language, channel, queue)
        if pfUI.translator_sending_translated then
          return originalCTLSend(self, prio, msg, chatType, language, channel, queue)
        end
        local trans = TranslateOutgoing(msg, chatType, channel)
        return originalCTLSend(self, prio, trans or msg, chatType, language, channel, queue)
      end
    end

    pfUI.GravityTROutHooked = true
  end

  -- ============================================================
  -- GESTION DE ENTRADA DINAMICA (EXPANDIDA: #10 #11 #14 #19 #22 #24 #31)
  -- ============================================================
  local DEDUP_CACHE = {}
  local DEDUP_TIME = 0

  local function HookIncomingChat()
    if pfUI.GravityTRHooked then return end

    local function TranslatorAddMessage(frame, text, r, g, b, id, queue_retries)
      if not text or type(text) ~= "string" then
        return frame:pfOriginalAddMessage(text, r, g, b, id)
      end
      if not C.translator or C.translator.enable ~= "1" or C.translator.incoming ~= "1" then
        return frame:pfOriginalAddMessage(text, r, g, b, id)
      end

      local now = GetTime()
      if now > DEDUP_TIME then
        DEDUP_CACHE = {}
        DEDUP_TIME = now
      end

      if DEDUP_CACHE[text] then
        local entry = DEDUP_CACHE[text]
        if entry.bilingual then
          frame:pfOriginalAddMessage(entry.dim_text, entry.dim_r, entry.dim_g, entry.dim_b, id)
        end
        return frame:pfOriginalAddMessage(entry.text, r, g, b, id)
      end

      local original_text = text

      -- Rapida salida: solo mensajes con jugadores, canales, o emotes
      local hasPlayer  = strfind(text, "|Hplayer:",  1, true)
      local hasChannel = strfind(text, "|Hchannel:", 1, true)
      local hasEmote   = (C.translator.chan_emote == "1") and strfind(text, "emote", 1, true)
      local hasTrade   = (C.translator.chan_trade == "1") and strfind(strlower(text), "trade", 1, true)
      if not hasPlayer and not hasChannel and not hasEmote then
        DEDUP_CACHE[original_text] = { text = text }
        return frame:pfOriginalAddMessage(text, r, g, b, id)
      end
      
      -- #21: Parser de Canal de Comercio
      if hasTrade then
        local _, _, p = strfind(text, "|h(.-)|h")
        if p and (strfind(p, "WTS") or strfind(p, "WTB") or strfind(p, "WTT")) then
           -- Simple parser for commerce
           local s, e = strfind(text, p, 1, true)
           if s then
              local trans_p = string.gsub(p, "WTS", "Vendo")
              trans_p = string.gsub(trans_p, "WTB", "Compro")
              trans_p = string.gsub(trans_p, "WTT", "Cambio")
              text = strsub(text, 1, s-1) .. trans_p .. strsub(text, e+1)
           end
        end
      end

      -- Extraer nombre del emisor para Blacklist/Memory
      local sender_name = nil
      local _, _, sn = strfind(text, "|Hplayer:([^|]+)|")
      if sn then sender_name = sn end

      -- #24: Check blacklist
      if IsBlacklisted(sender_name) then
        DEDUP_CACHE[original_text] = { text = text }
        return frame:pfOriginalAddMessage(text, r, g, b, id)
      end

      -- Extraccion robusta del cuerpo del mensaje
      local prefix_text, body

      local best_end = nil
      local search_start = 1
      while true do
        local s, e = strfind(text, "|Hplayer:.-|h.-|h", search_start)
        if not s then break end
        best_end = e
        search_start = e + 1
      end

      if best_end then
        local col_s, col_e = strfind(text, "|?r?[:%\239%\188%\154]%s*", best_end)
        if col_s and col_s <= best_end + 8 then
          prefix_text = strsub(text, 1, col_e)
          body        = strsub(text, col_e + 1)
        end
      end

      if not body then
        local last_bracket = nil
        local lb_s = 1
        while true do
          local s = strfind(text, "%]", lb_s)
          if not s then break end
          last_bracket = s
          lb_s = s + 1
        end
        if last_bracket then
          local col_s, col_e = strfind(text, "[:%\239%\188%\154]%s*", last_bracket)
          if col_s and col_s <= last_bracket + 6 then
            prefix_text = strsub(text, 1, col_e)
            body        = strsub(text, col_e + 1)
          end
        end
      end

      if not body or strlen(body) < 2 then
        if CountChineseChars(text) < 1 then
          DEDUP_CACHE[original_text] = { text = text }
          return frame:pfOriginalAddMessage(text, r, g, b, id)
        end
        prefix_text = ""
        body = text
      end

      -- Detectar idioma del cuerpo
      local lang = DetectLanguage(body)

      -- #19: Player language memory
      if lang ~= "unknown" then
        RememberPlayerLang(sender_name, lang)
      elseif lang == "unknown" then
        local recalled = RecallPlayerLang(sender_name)
        if recalled then lang = recalled end
      end

      -- VOTACION HEURISTICA para deteccion automatica del servidor
      if C.translator.server_type == "0" and not pfUI.translator_realm_votes.detected then
        if lang == "en" then
          pfUI.translator_realm_votes.en = pfUI.translator_realm_votes.en + 1
        elseif lang == "es" then
          pfUI.translator_realm_votes.es = pfUI.translator_realm_votes.es + 1
        elseif lang == "zh" then
          pfUI.translator_realm_votes.zh = pfUI.translator_realm_votes.zh + 1
        end
        local v = pfUI.translator_realm_votes
        if v.en >= 8 then
          v.detected = "en"
          if C.translator.debug_mode == "1" then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR]|r Servidor detectado: EN")
          end
        elseif v.es >= 8 then
          v.detected = "es"
          if C.translator.debug_mode == "1" then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR]|r Servidor detectado: ES")
          end
        elseif v.zh >= 8 then
          v.detected = "zh"
          if C.translator.debug_mode == "1" then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR]|r Servidor detectado: ZH")
          end
        end
      end

      -- Seleccion de modo
      local src_env, dest_env = GetTranslationMode(true)
      if not src_env or not dest_env then
        DEDUP_CACHE[original_text] = { text = text }
        return frame:pfOriginalAddMessage(text, r, g, b, id)
      end

      local final_src = (lang ~= "unknown") and lang or src_env

      -- #14: Smart pre-filter — si el idioma detectado YA es el destino, saltar
      if C.translator.smart_filter == "1" and final_src == dest_env then
        -- Agregar badge sin traducir
        local badge = GetLangBadge(lang)
        if badge ~= "" then text = badge .. text end
        DEDUP_CACHE[original_text] = { text = text }
        return frame:pfOriginalAddMessage(text, r, g, b, id)
      end

      -- Debug
      if C.translator.debug_mode == "1" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR DBG]|r body: [" .. body .. "]")
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR DBG]|r lang=" .. lang .. " final_src=" .. final_src .. " dest=" .. dest_env)
      end

      -- Traducir
      if final_src ~= dest_env then
        local prefix_dict = final_src .. "_" .. dest_env
        local words   = pfUI.translator_dicts[prefix_dict .. "_words"]
        local phrases = pfUI.translator_dicts[prefix_dict .. "_phrases"]
        local keys    = pfUI.translator_dicts[prefix_dict .. "_keys"]
        local bkts    = pfUI.translator_dicts[prefix_dict .. "_buckets"]

        if C.translator.debug_mode == "1" then
          local nk = keys and table.getn(keys) or 0
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR DBG]|r dict=" .. prefix_dict .. " keys=" .. nk)
        end

        if words and phrases and keys then
          -- #31: Anti-spam check
          local is_spam = IsSpamDuplicate(sender_name, body)
          
          local ignore_cache = (queue_retries and queue_retries >= 3)
          local trans, missing, proc_text, links = LocalTranslate(body, words, phrases, keys, final_src, bkts, false, ignore_cache)

          -- Si faltaba caché de items, encolar procesamiento y abortar impresión
          if missing then
             local current_retries = queue_retries or 0
             table.insert(ITEM_CACHE_QUEUE, {
                time = GetTime(),
                callback = function()
                   DEDUP_CACHE[original_text] = nil
                   TranslatorAddMessage(frame, original_text, r, g, b, id, current_retries + 1)
                end
             })
             return
          end

          -- FIX CRITICO: Para chino con DLL disponible, NUNCA aceptar traduccion local.
          -- El diccionario local produce frases tipo Tarzan (palabra por palabra).
          -- Google traduce oraciones completas con contexto. Siempre preferir DLL para zh.
          if final_src == "zh" and hasWoWTranslateDLL and proc_text and links then
             trans = nil  -- Descartar resultado local y escalar a DLL
          end

          -- #4: Si falla el traductor local y tenemos DLL, usar DLL
          if not trans and hasWoWTranslateDLL and proc_text and links then
             DLL_REQUEST_COUNTER = DLL_REQUEST_COUNTER + 1
             local reqId = tostring(DLL_REQUEST_COUNTER)
             DLL_PENDING[reqId] = {
                 time = GetTime(),
                 callback = function(dll_trans, is_error, err_msg)
                     if is_error or not dll_trans then
                         if C.translator.debug_mode == "1" then
                            DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR]|r DLL Error: " .. tostring(err_msg))
                         end
                         if pfUI.translator_dicts and pfUI.translator_dicts[final_src .. "_" .. dest_env .. "_words"] then
                            -- Hubo error, mostrar fallback Tarzan
                            local tarzan = string.gsub(proc_text, " http://ph%.wt/(%d+) ", function(lid)
                               local idx = tonumber(lid)
                               return links[idx] or ""
                            end)
                            tarzan = strsub(tarzan, 2, -2)
                            
                            if final_src == "zh" then
                              tarzan = string.gsub(tarzan, "%s+", " ")
                              tarzan = string.gsub(tarzan, "^%s*(.-)%s*$", "%1")
                            end
                            
                            local badge = GetLangBadge(lang)
                            tarzan = badge .. prefix_text .. tarzan .. GetTRTag()
                            DEDUP_CACHE[original_text] = { text = tarzan }
                            frame:pfOriginalAddMessage(tarzan, r, g, b, id)
                         else
                            DEDUP_CACHE[original_text] = { text = text }
                            frame:pfOriginalAddMessage(text, r, g, b, id)
                         end
                         return
                     end

                    -- Reconstruir links
                    local passes = 0
                    while passes < 5 and strfind(dll_trans, "http://ph%.wt/%d+") do
                      passes = passes + 1
                      local replaced = false
                      dll_trans = string.gsub(dll_trans, "%s*http://ph%.wt/(%d+)%s*", function(lid)
                        local lid_num = tonumber(lid)
                        if links[lid_num] then replaced = true; return links[lid_num] end
                      end)
                      if not replaced then break end
                    end
                    
                    CacheSet(body, dll_trans)
                    
                    local badge = GetLangBadge(lang)
                    local final_text = badge .. prefix_text .. dll_trans .. GetTRTag()
                    
                    if C.translator.bilingual_mode == "1" then
                       local dim_r = (r or 1) * 0.45
                       local dim_g = (g or 1) * 0.45
                       local dim_b = (b or 1) * 0.45
                       frame:pfOriginalAddMessage(badge .. original_text, dim_r, dim_g, dim_b, id)
                       DEDUP_CACHE[original_text] = { text = final_text, bilingual = true, dim_text = badge .. original_text, dim_r = dim_r, dim_g = dim_g, dim_b = dim_b }
                    else
                       DEDUP_CACHE[original_text] = { text = final_text }
                    end
                    frame:pfOriginalAddMessage(final_text, r, g, b, id)
                 end
             }
             local ok = pcall(UnitXP, "WoWTranslate", "translate_async", reqId, proc_text, final_src, dest_env)
             if not ok then
                DLL_PENDING[reqId] = nil
                DEDUP_CACHE[original_text] = { text = original_text }
                frame:pfOriginalAddMessage(original_text, r, g, b, id)
             end
             return
          end

          if C.translator.debug_mode == "1" then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR DBG]|r result=" .. (trans or "nil") .. (is_spam and " [SPAM]" or ""))
          end

          if trans then
            if not is_spam then
              pfUI.translator_stats.total_in = pfUI.translator_stats.total_in + 1
              -- #9: History
              AddToHistory(sender_name, body, trans, "in")
              -- #22: Sound
              PlayTranslateSound()
            end

            -- #11: Language badge
            local badge = GetLangBadge(lang)

            -- #10: Bilingual mode
            if C.translator.bilingual_mode == "1" then
              -- Mostrar original con colores atenuados
              local dim_r = (r or 1) * 0.45
              local dim_g = (g or 1) * 0.45
              local dim_b = (b or 1) * 0.45
              
              text = badge .. prefix_text .. trans .. GetTRTag()
              DEDUP_CACHE[original_text] = { text = text, bilingual = true, dim_text = badge .. original_text, dim_r = dim_r, dim_g = dim_g, dim_b = dim_b }
              frame:pfOriginalAddMessage(DEDUP_CACHE[original_text].dim_text, dim_r, dim_g, dim_b, id)
              return frame:pfOriginalAddMessage(text, r, g, b, id)
            end

            text = badge .. prefix_text .. trans .. GetTRTag()
          elseif not trans then
            -- Sin traduccion, pero agregar badge si esta habilitado
            local badge = GetLangBadge(lang)
            if badge ~= "" then text = badge .. text end
          end
        end
      else
        -- Mismo idioma, solo badge
        local badge = GetLangBadge(lang)
        if badge ~= "" then text = badge .. text end
      end

      DEDUP_CACHE[original_text] = { text = text }
      return frame:pfOriginalAddMessage(text, r, g, b, id)
    end

    for i = 1, 10 do
      local frame = _G["ChatFrame" .. i]
      if frame and not frame.pfOriginalAddMessage then
        frame.pfOriginalAddMessage = frame.AddMessage
        frame.AddMessage = function(self, t, r, g, b, mid)
          TranslatorAddMessage(self, t, r, g, b, mid)
        end
      end
    end

    pfUI.GravityTRHooked = true
  end

  -- ============================================================
  -- PUENTE WIM (Bilateral — sin cambios)
  -- ============================================================
  local function HookWIMBridge()
    if not WIM_PostMessage or pfUI.GravityWIMHooked then return end
    local originalWIMPost = WIM_PostMessage

    WIM_PostMessage = function(user, msg, ttype, from, raw_msg, hotkeyFix)
      if C.translator and C.translator.enable == "1" and C.translator.wim_bridge == "1" and raw_msg then
        local isIncoming = (ttype == 1)
        local mode_check = (isIncoming     and C.translator.incoming == "1")
                        or (not isIncoming and C.translator.outgoing == "1")
        if mode_check then
          local src, dest = GetTranslationMode(isIncoming)
          if src and dest then
            local pfx     = src .. "_" .. dest
            local words   = pfUI.translator_dicts[pfx .. "_words"]
            local phrases = pfUI.translator_dicts[pfx .. "_phrases"]
            local keys    = pfUI.translator_dicts[pfx .. "_keys"]
            local bkts    = pfUI.translator_dicts[pfx .. "_buckets"]
            local trans   = LocalTranslate(raw_msg, words, phrases, keys, src, bkts)
            if trans then
              local safe_raw = string.gsub(raw_msg, "([%.%*%-%?%[%]%(%)%^%$%%])", "%%%1")
              msg     = string.gsub(msg, safe_raw, trans .. GetTRTag())
              raw_msg = trans
            end
          end
        end
      end
      return originalWIMPost(user, msg, ttype, from, raw_msg, hotkeyFix)
    end

    pfUI.GravityWIMHooked = true
  end


  -- ============================================================
  -- #32: INTEGRACION CON EL SISTEMA DE CORREO (Mailbox)
  -- ============================================================
  local function HookMailbox()
    if pfUI.GravityMailboxHooked then return end
    
    local originalOpenMail = OpenMailFrame:GetScript("OnShow")
    if originalOpenMail then
      OpenMailFrame:SetScript("OnShow", function()
        originalOpenMail()
        if C.translator and C.translator.enable == "1" and C.translator.mailbox == "1" then
          local body = OpenMailBodyText:GetText()
          local subject = OpenMailSubject:GetText()
          
          local function TranslateMail(text)
            if not text or text == "" then return text end
            local lang = DetectLanguage(text)
            if lang ~= "unknown" then
              local src, dest = GetTranslationMode(true)
              if src and dest and lang ~= dest then
                local pfx = lang .. "_" .. dest
                local words = pfUI.translator_dicts[pfx .. "_words"]
                local phrases = pfUI.translator_dicts[pfx .. "_phrases"]
                local keys = pfUI.translator_dicts[pfx .. "_keys"]
                local bkts = pfUI.translator_dicts[pfx .. "_buckets"]
                local trans = LocalTranslate(text, words, phrases, keys, lang, bkts)
                if trans then
                  return text .. "\n\n|cff33ffcc[TR] " .. trans .. "|r"
                end
              end
            end
            return text
          end
          
          if body then OpenMailBodyText:SetText(TranslateMail(body)) end
          if subject then OpenMailSubject:SetText(TranslateMail(subject)) end
        end
      end)
    end
    pfUI.GravityMailboxHooked = true
  end

  -- ============================================================
  -- #33: QUICK TRANSLATE FRAME
  -- ============================================================
  local quickFrame = CreateFrame("Frame", "pfUITranslatorQuick", UIParent)
  quickFrame:SetWidth(420)
  quickFrame:SetHeight(130)
  quickFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
  quickFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  quickFrame:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
  quickFrame:SetBackdropBorderColor(0.2, 1.0, 0.8, 0.7)
  quickFrame:EnableMouse(true)
  quickFrame:SetMovable(true)
  quickFrame:RegisterForDrag("LeftButton")
  quickFrame:SetScript("OnDragStart", function() this:StartMoving() end)
  quickFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  quickFrame:Hide()
  quickFrame:SetFrameStrata("DIALOG")

  local qTitle = quickFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  qTitle:SetPoint("TOP", quickFrame, "TOP", 0, -8)
  qTitle:SetText("|cff33ffcc[TR]|r " .. (T["Quick Translate"] or "Traductor Rapido"))

  local qClose = CreateFrame("Button", nil, quickFrame, "UIPanelCloseButton")
  qClose:SetPoint("TOPRIGHT", quickFrame, "TOPRIGHT", -2, -2)
  qClose:SetWidth(20)
  qClose:SetHeight(20)

  local qInput = CreateFrame("EditBox", "pfUITranslatorQuickInput", quickFrame)
  qInput:SetFontObject(ChatFontNormal)
  qInput:SetMultiLine(false)
  qInput:SetAutoFocus(false)
  qInput:SetMaxLetters(255)
  qInput:SetHeight(24)
  qInput:SetPoint("TOPLEFT", quickFrame, "TOPLEFT", 12, -28)
  qInput:SetPoint("TOPRIGHT", quickFrame, "TOPRIGHT", -12, -28)
  qInput:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  qInput:SetBackdropColor(0.1, 0.1, 0.15, 0.9)
  qInput:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
  qInput:SetTextInsets(5, 5, 2, 2)

  local qOutput = quickFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  qOutput:SetPoint("TOPLEFT", qInput, "BOTTOMLEFT", 2, -10)
  qOutput:SetPoint("TOPRIGHT", qInput, "BOTTOMRIGHT", -2, -10)
  qOutput:SetHeight(60)
  qOutput:SetJustifyH("LEFT")
  qOutput:SetJustifyV("TOP")
  qOutput:SetText("|cff888888" .. (T["Type text to translate..."] or "Escribe texto para traducir...") .. "|r")

  qInput:SetScript("OnTextChanged", function()
    local txt = this:GetText()
    if not txt or txt == "" then
      qOutput:SetText("|cff888888" .. (T["Type text to translate..."] or "Escribe texto para traducir...") .. "|r")
      return
    end
    local src, dest = GetTranslationMode(false)
    if not src or not dest then
      qOutput:SetText("|cffff4444" .. (T["Configure direction first"] or "Configura la direccion primero") .. "|r")
      return
    end
    local pfx = src .. "_" .. dest
    local trans = LocalTranslate(txt,
      pfUI.translator_dicts[pfx .. "_words"],
      pfUI.translator_dicts[pfx .. "_phrases"],
      pfUI.translator_dicts[pfx .. "_keys"],
      src,
      pfUI.translator_dicts[pfx .. "_buckets"])
    if trans then
      qOutput:SetText("|cff33ffcc" .. strupper(src) .. " > " .. strupper(dest) .. ":|r " .. trans)
    else
      qOutput:SetText("|cff888888(" .. (T["No matches found"] or "sin coincidencias") .. ")|r")
    end
  end)
  qInput:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  qInput:SetScript("OnEnterPressed", function() this:ClearFocus() end)


  -- ============================================================
  -- #23: PANEL DE ESTADISTICAS VISUALES (DASHBOARD)
  -- ============================================================
  local dashboardFrame = CreateFrame("Frame", "pfUITranslatorDashboard", UIParent)
  dashboardFrame:SetWidth(400)
  dashboardFrame:SetHeight(300)
  dashboardFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  dashboardFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  dashboardFrame:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
  dashboardFrame:SetBackdropBorderColor(0.2, 1.0, 0.8, 0.7)
  dashboardFrame:EnableMouse(true)
  dashboardFrame:SetMovable(true)
  dashboardFrame:RegisterForDrag("LeftButton")
  dashboardFrame:SetScript("OnDragStart", function() this:StartMoving() end)
  dashboardFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  dashboardFrame:Hide()
  dashboardFrame:SetFrameStrata("DIALOG")

  local dbTitle = dashboardFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  dbTitle:SetPoint("TOP", dashboardFrame, "TOP", 0, -10)
  dbTitle:SetText("|cff33ffccTranslator Dashboard v7.0.0|r")

  local dbClose = CreateFrame("Button", nil, dashboardFrame, "UIPanelCloseButton")
  dbClose:SetPoint("TOPRIGHT", dashboardFrame, "TOPRIGHT", -2, -2)

  local dbStats = dashboardFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  dbStats:SetPoint("TOPLEFT", dashboardFrame, "TOPLEFT", 15, -40)
  dbStats:SetJustifyH("LEFT")

  local function UpdateDashboard()
    local s = pfUI.translator_stats
    local total = s.total_in + s.total_out + s.cache_hits
    local hitp = (total > 0) and math.floor((s.cache_hits / total) * 100) or 0
    local detect = pfUI.translator_realm_votes.detected or "auto"
    
    local txt = "Estadisticas Globales:\n"
    txt = txt .. "Traducciones Entrantes: |cff00ff00" .. s.total_in .. "|r\n"
    txt = txt .. "Traducciones Salientes: |cff00ff00" .. s.total_out .. "|r\n"
    txt = txt .. "Aciertos de Cache: |cff00ccff" .. s.cache_hits .. " (" .. hitp .. "%)|r\n"
    txt = txt .. "Servidor Detectado: |cffffff00" .. strupper(detect) .. "|r\n\n"
    
    txt = txt .. "Top 5 Frases/Palabras:\n"
    local top_keys = {}
    local fk = next(FREQ_TABLE)
    while fk do
      table.insert(top_keys, { key = fk, count = FREQ_TABLE[fk] })
      fk = next(FREQ_TABLE, fk)
    end
    table.sort(top_keys, function(a, b) return a.count > b.count end)
    
    local limit = (table.getn(top_keys) > 5) and 5 or table.getn(top_keys)
    for i = 1, limit do
      txt = txt .. "  " .. i .. ". " .. top_keys[i].key .. " (|cff888888" .. top_keys[i].count .. "|r)\n"
    end
    dbStats:SetText(txt)
  end

  dashboardFrame:SetScript("OnShow", UpdateDashboard)

  -- ============================================================
  -- #15: PANEL STATUS INDICATOR
  -- ============================================================
  local panelFrame = CreateFrame("Button", "pfUITranslatorPanel", UIParent)
  panelFrame:SetWidth(110)
  panelFrame:SetHeight(18)
  panelFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 220, 2)
  panelFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  panelFrame:SetBackdropColor(0.05, 0.05, 0.08, 0.85)
  panelFrame:SetBackdropBorderColor(0.2, 1.0, 0.8, 0.5)
  panelFrame:EnableMouse(true)
  panelFrame:SetMovable(true)
  panelFrame:RegisterForDrag("LeftButton")
  panelFrame:SetScript("OnDragStart", function() this:StartMoving() end)
  panelFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  panelFrame:Hide()
  panelFrame:SetFrameStrata("MEDIUM")

  local panelText = panelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  panelText:SetPoint("CENTER", panelFrame, "CENTER", 0, 0)

  local panelTimer = 0
  panelFrame:SetScript("OnUpdate", function()
    panelTimer = panelTimer + arg1
    if panelTimer < 2 then return end
    panelTimer = 0
    local s = pfUI.translator_stats
    local src, dest = GetTranslationMode(true)
    local dir_str = "?"
    if src and dest then dir_str = strupper(src) .. ">" .. strupper(dest) end
    local total = s.total_in + s.total_out
    local dot = (C.translator.enable == "1") and "|cff00ff00*|r" or "|cffff0000*|r"
    panelText:SetText(dot .. " " .. dir_str .. " [" .. total .. "]")
  end)

  panelFrame:SetScript("OnClick", function()
    if pfUI.gui and pfUI.gui.ShowConfig then
      pfUI.gui.ShowConfig(T["Translator"] or "Traductor")
    end
  end)

  -- ============================================================
  -- INICIALIZACION
  -- ============================================================
  local initFrame = CreateFrame("Frame")
  initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  initFrame:RegisterEvent("ADDON_LOADED")
  initFrame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
      initFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")

      -- Migracion v6.8.2 (preservada)
      if C.translator and not C.translator.force_channels_v682 then
        C.translator.enable = "1"
        C.translator.incoming = "1"
        C.translator.outgoing = "1"
        C.translator.chan_say = "1"
        C.translator.chan_party = "1"
        C.translator.chan_raid = "1"
        C.translator.chan_guild = "1"
        C.translator.chan_whisper = "1"
        C.translator.chan_world = "1"
        C.translator.chan_lfg = "1"
        C.translator.chan_bg = "1"
        C.translator.chan_officer = "1"
        C.translator.force_channels_v682 = "1"
      end

      -- #3: Cargar reglas personalizadas
      -- #28 & #29: Cargar diccionarios pre-compilados si existen
      if pfUI_cache then
         if pfUI_cache.translator_compiled then
            pfUI.translator_dicts = pfUI_cache.translator_compiled
            if C.translator.debug_mode == "1" then
               DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR]|r Diccionarios cargados desde binario compilado.")
            end
         end
         -- Cargar cache de memoria de Google Translate (Aprendizaje Persistente)
         if pfUI_cache.translator_cache and pfUI_cache.translator_cache_order then
            TR_CACHE = pfUI_cache.translator_cache
            TR_CACHE_ORDER = pfUI_cache.translator_cache_order
            TR_CACHE_CFG = pfUI_cache.translator_cache_cfg
            
            -- Invalidar si la configuracion cambio estando offline
            local current_h = CacheConfigHash()
            if TR_CACHE_CFG and TR_CACHE_CFG ~= current_h then
               TR_CACHE = {}
               TR_CACHE_ORDER = {}
               TR_CACHE_CFG = current_h
               pfUI_cache.translator_cache = nil
               pfUI_cache.translator_cache_order = nil
               pfUI_cache.translator_cache_cfg = nil
               if C.translator.debug_mode == "1" then
                  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR]|r Cache offline invalidada por cambio de config.")
               end
            else
               -- Purgar entradas con texto chino en la clave (traducciones Tarzan del dict local).
               -- Las traducciones de Google NO tienen chars chinos en la CLAVE (el original).
               -- Esto fuerza que las frases chinas sean re-traducidas por Google.
               local purged = 0
               local new_order = {}
               for i = 1, table.getn(TR_CACHE_ORDER) do
                  local k = TR_CACHE_ORDER[i]
                  if CountChineseChars(k) > 0 then
                     TR_CACHE[k] = nil
                     purged = purged + 1
                  else
                     table.insert(new_order, k)
                  end
               end
               TR_CACHE_ORDER = new_order
               if C.translator.debug_mode == "1" then
                  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR]|r Memoria cargada: " .. table.getn(TR_CACHE_ORDER) .. " traducciones (" .. purged .. " Tarzan purgadas).")
               end
            end
         end
      end
      pcall(HookMailbox)
      pcall(ProcessCustomRules)

      pcall(SecureHookOutgoing)
      pcall(HookIncomingChat)
      if IsAddOnLoaded("WIM") then pcall(HookWIMBridge) end

      -- #4: Verificar DLL WoWTranslate (distinto de UnitXP_SP3)
      -- Check specifically for WoWTranslate commands, otherwise the DLL passes it to native UnitXP which throws a Usage error.
      local dllOk = pcall(UnitXP, "WoWTranslate", "poll")
      if dllOk then
        hasWoWTranslateDLL = true
        if C.translator.debug_mode == "1" then
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR]|r UnitXP detectado. Fallback DLL activo.")
        end
      end
      if C.translator and C.translator.enable == "1" and C.translator.mailbox == "1" then
        DEFAULT_CHAT_FRAME:AddMessage(
          "|cff00ccff[Translator v" .. pfUI.translator_version .. "]|r " ..
          (T["Enable Translator"] or "Traductor Trilingue Activo") .. "."
        )
      end
    elseif event == "ADDON_LOADED" and arg1 == "WIM" then
      pcall(HookWIMBridge)
    end
  end)

  -- ============================================================
  -- COMANDOS DE CHAT (/tr) — EXPANDIDOS
  -- ============================================================
  SLASH_PFTR1 = "/tr"
  SlashCmdList["PFTR"] = function(msg)
    if not msg then msg = "" end
    msg = string.gsub(msg, "^%s*(.-)%s*$", "%1")

    if msg == "stats" then
      local s      = pfUI.translator_stats
      local total  = s.total_in + s.total_out + s.cache_hits
      local hitp   = (total > 0) and math.floor((s.cache_hits / total) * 100) or 0
      local detect = pfUI.translator_realm_votes.detected or "auto"
      -- Top 3 frecuencias
      local top_keys = {}
      local fk = next(FREQ_TABLE)
      while fk do
        table.insert(top_keys, { key = fk, count = FREQ_TABLE[fk] })
        fk = next(FREQ_TABLE, fk)
      end
      table.sort(top_keys, function(a, b) return a.count > b.count end)
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cff00ccff[TR v" .. pfUI.translator_version .. "]|r" ..
        "  |cffffffaaEntrada:|r "  .. s.total_in ..
        "  |cffffffaaSalida:|r "   .. s.total_out ..
        "  |cffffffaaCache:|r "    .. s.cache_hits .. " (" .. hitp .. "%)" ..
        "  |cffffffaaServidor:|r " .. detect
      )
      if table.getn(top_keys) > 0 then
        local top_str = "  |cffffffaaTop:|r "
        local limit = (table.getn(top_keys) > 5) and 5 or table.getn(top_keys)
        for i = 1, limit do
          top_str = top_str .. top_keys[i].key .. "(" .. top_keys[i].count .. ") "
        end
        DEFAULT_CHAT_FRAME:AddMessage(top_str)
      end

    elseif msg == "reset" then
      local v = pfUI.translator_realm_votes
      v.en = 0; v.es = 0; v.zh = 0; v.detected = nil
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR]|r Deteccion de idioma de reino reiniciada.")

    elseif msg == "debug" then
      local d = C.translator.debug_mode
      C.translator.debug_mode = (d == "1") and "0" or "1"
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33ffcc[TR]|r Modo debug: " ..
        (C.translator.debug_mode == "1" and "|cff00ff00ON|r" or "|cffff4444OFF|r")
      )

    elseif msg == "quick" then
      if quickFrame:IsShown() then
        quickFrame:Hide()
      else
        quickFrame:Show()
        qInput:SetFocus()
      end

    elseif msg == "panel" then
      if panelFrame:IsShown() then
        panelFrame:Hide()
      else
        panelFrame:Show()
      end

    elseif msg == "dashboard" or msg == "dash" then
      if dashboardFrame:IsShown() then
        dashboardFrame:Hide()
      else
        dashboardFrame:Show()
      end

    elseif msg == "history" or msg == "hist" then
      DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[TR History]|r Ultimas traducciones:")
      local count = 0
      for i = TR_HISTORY_POS, 1, -1 do
        if TR_HISTORY[i] then
          local h = TR_HISTORY[i]
          DEFAULT_CHAT_FRAME:AddMessage(
            "  |cff888888" .. h.sender .. "|r: " ..
            "|cffff8888" .. h.original .. "|r -> |cff88ff88" .. h.translated .. "|r"
          )
          count = count + 1
          if count >= 10 then break end
        end
      end
      if count < 10 then
        for i = TR_HISTORY_MAX, TR_HISTORY_POS + 1, -1 do
          if TR_HISTORY[i] then
            local h = TR_HISTORY[i]
            DEFAULT_CHAT_FRAME:AddMessage(
              "  |cff888888" .. h.sender .. "|r: " ..
              "|cffff8888" .. h.original .. "|r -> |cff88ff88" .. h.translated .. "|r"
            )
            count = count + 1
            if count >= 10 then break end
          end
        end
      end
      if count == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("  (vacio)")
      end

    elseif msg == "last" then
      -- #25: Mostrar la ultima traduccion
      if TR_HISTORY[TR_HISTORY_POS] then
        local h = TR_HISTORY[TR_HISTORY_POS]
        DEFAULT_CHAT_FRAME:AddMessage(
          "|cff00ccff[TR Last]|r |cff888888" .. h.sender .. "|r:" ..
          " |cffff8888" .. h.original .. "|r" ..
          " -> |cff88ff88" .. h.translated .. "|r"
        )
      else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[TR]|r Sin traducciones recientes.")
      end

    elseif strsub(msg, 1, 6) == "ignore" then
      local name = strsub(msg, 8)
      name = string.gsub(name, "^%s*(.-)%s*$", "%1")
      if name and name ~= "" then
        local existing = C.translator.blacklist or ""
        if existing ~= "" then
          C.translator.blacklist = existing .. "," .. name
        else
          C.translator.blacklist = name
        end
        BLACKLIST_DIRTY = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR]|r Jugador ignorado: |cffff4444" .. name .. "|r")
      else
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR]|r Uso: /tr ignore NombreJugador")
      end

    elseif strsub(msg, 1, 8) == "unignore" then
      local name = strsub(msg, 10)
      name = string.gsub(name, "^%s*(.-)%s*$", "%1")
      if name and name ~= "" then
        local bl = C.translator.blacklist or ""
        -- Remover nombre de la lista
        local new_bl = {}
        for n in string.gfind(bl, "([^,]+)") do
          n = string.gsub(n, "^%s*(.-)%s*$", "%1")
          if strlower(n) ~= strlower(name) then
            table.insert(new_bl, n)
          end
        end
        C.translator.blacklist = table.concat(new_bl, ",")
        BLACKLIST_DIRTY = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR]|r Jugador removido de la lista: |cff00ff00" .. name .. "|r")
      else
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR]|r Uso: /tr unignore NombreJugador")
      end

    elseif strsub(msg, 1, 7) == "addrule" then
      local rule = strsub(msg, 9)
      rule = string.gsub(rule, "^%s*(.-)%s*$", "%1")
      if rule and rule ~= "" and strfind(rule, "|", 1, true) then
        local existing = C.translator.custom_rules or ""
        if existing ~= "" then
          C.translator.custom_rules = existing .. ";" .. rule
        else
          C.translator.custom_rules = rule
        end
        -- #28 & #29: Cargar diccionarios pre-compilados si existen
      if pfUI_cache and pfUI_cache.translator_compiled then
         pfUI.translator_dicts = pfUI_cache.translator_compiled
         if C.translator.debug_mode == "1" then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR]|r Diccionarios cargados desde binario compilado.")
         end
      end
      pcall(HookMailbox)
      pcall(ProcessCustomRules)
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR]|r Regla anadida: |cffffff00" .. rule .. "|r")
      else
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR]|r Uso: /tr addrule espanol|english|中文")
      end

    elseif msg == "help" then
      DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[TR v" .. pfUI.translator_version .. "] Comandos:|r")
      DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/tr|r — Abrir panel de configuracion")
      DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/tr stats|r — Estadisticas de sesion")
      DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/tr debug|r — Toggle modo debug")
      DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/tr quick|r — Traductor rapido interactivo")
      DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/tr panel|r — Toggle indicador de panel")
      DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/tr dashboard|r — Panel de estadisticas y frecuencias")
      DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/tr history|r — Ultimas 10 traducciones")
      DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/tr last|r — Ultima traduccion")
      DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/tr reset|r — Reiniciar deteccion de servidor")
      DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/tr ignore Nombre|r — Ignorar jugador")
      DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/tr unignore Nombre|r — Des-ignorar jugador")
      DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/tr addrule es|en|zh|r — Agregar regla personalizada")

    else
      if pfUI.gui and pfUI.gui.ShowConfig then
        pfUI.gui.ShowConfig(T["Translator"] or "Traductor")
      end
    end
  end

  -- Exponer funcion de traduccion para uso por addons externos
  pfUI.Translate = LocalTranslate

  -- Registrar modulo de configuracion para invalidar caches en tiempo real
  pfUI.translator = {
    UpdateConfig = function(self)
      _tr_tag_cache = nil
      BLACKLIST_DIRTY = true
      CacheCheckInvalidation()
    end,
  }

end)
