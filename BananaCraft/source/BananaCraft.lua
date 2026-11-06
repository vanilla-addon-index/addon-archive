-- BananaCraft -- vormals BananaRepublik Partnerguild
-- Guild profession recipe database with sharing and search functionality
--
-- v1.0.1:
--   * PERF: guild roster is now cached instead of being queried per recipe
--           (GUILD_ROSTER_UPDATE keeps it accurate, 10s TTL as fallback)
--   * FIX:  removed emoji from chat output - the 1.12 client font has no
--           glyphs for them and rendered empty boxes. Replaced with colour codes.
-- Author: Lumihunt
-- Total: 1,513 recipes across 7 professions


-- Recipe maps loaded from BananaCraft_RecipeMaps.lua
-- Access via: BCRAFT_RecipeMaps[professionName][recipeName] = categoryName

-- -------------------------
-- German → English Profession Name Mapping
-- -------------------------
local ProfessionNameMap = {
  -- German → English
  ["Alchemie"] = "Alchemy",
  ["Schmiedekunst"] = "Blacksmithing",
  ["Verzauberkunst"] = "Enchanting",
  ["Verzauberungskunst"] = "Enchanting",
  ["Ingenieurskunst"] = "Engineering",
  ["Juwelierskunst"] = "Jewelcrafting",
  ["Lederverarbeitung"] = "Leatherworking",
  ["Schneiderei"] = "Tailoring",
  ["Bergbau"] = "Mining",
  ["Kräuterkunde"] = "Herbalism",
  ["Kochkunst"] = "Cooking",
  ["Erste Hilfe"] = "First Aid",
  -- English names stay the same
  ["Mining"] = "Mining",
  ["Herbalism"] = "Herbalism",
  ["Alchemy"] = "Alchemy",
  ["Blacksmithing"] = "Blacksmithing",
  ["Enchanting"] = "Enchanting",
  ["Engineering"] = "Engineering",
  ["Jewelcrafting"] = "Jewelcrafting",
  ["Leatherworking"] = "Leatherworking",
  ["Tailoring"] = "Tailoring",
}

-- Normalize profession name to English
local function normalizeProfessionName(profName)
  return ProfessionNameMap[profName] or profName
end

-- GetTradeSkillLine()/GetCraftDisplaySkillLine() liefern den Platzhalter
-- "UNKNOWN" (Rang 0/0), solange das Berufsfenster seine Daten noch nicht
-- geladen hat. Der darf nie als Berufsname gespeichert oder weitergegeben
-- werden.
local function isBadProfName(name)
  if not name or name == "" then return true end
  return string.upper(name) == "UNKNOWN"
end

local ADDON_NAME = "BananaCraft"
local DB_NAME = "BananaCraftDB"
local PREFIX = "BCRAFT0"
local DEBUG = false  -- Debug messages OFF by default (use /bc debug to enable)
local ADDON_VERSION = "3.0.0"  -- keep in sync with the .toc "## Version:" line
BCRAFT_VERSION = ADDON_VERSION

-- /bc versioncheck state (see startHashSync section for PING/PONG, this is
-- the separate, simpler VCHECK/VERSION request/response pair)
VersionCheckResponses = VersionCheckResponses or {}
VersionCheckActive = false

local tlen = table.getn
local LastScannedProf = {}  -- Now per-character: LastScannedProf[charName] = profName

-- -------------------------
-- Utility
-- -------------------------
local function msg(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffd200BananaCraft:|r " .. text)
end

local function debug(text)
  if DEBUG then
    DEFAULT_CHAT_FRAME:AddMessage("|cff888888[BananaCraft Debug]|r " .. text)
  end
end

local function now()
  return date("%Y-%m-%d %H:%M:%S")
end

local function playerName()
  return UnitName("player") or "Unknown"
end

-- -------------------------
-- Gildenbewusste Schluessel
--
-- Frueher war der Schluessel in db.guild einfach der Charaktername. Mit der
-- Gilde im Schluessel koennen zwei Gilden denselben Charakternamen haben,
-- ohne sich zu ueberschreiben.
--
-- Neuer Schluessel: "Charname@Gildenname".
-- Dieselbe Zeichenkette wandert auch ueber das Netzwerk, damit Sender und
-- Empfaenger garantiert denselben Schluessel bilden.
-- -------------------------
function BCRAFT_OwnGuild()
  local g = GetGuildInfo and GetGuildInfo("player")
  if g and g ~= "" then return g end

  -- Ohne Gilde: KEIN fester Sammelbegriff wie "Ohne Gilde".
  --
  -- Zwei gildenlose Spieler haetten sonst dieselbe Kennung. Folge waere,
  -- dass jeder die Daten des anderen fuer eigene haelt -- der
  -- Schleifenschutz beim Senden (Gilde == eigene Gilde) greift dann nicht
  -- mehr und beide schicken sich die Daten endlos zurueck.
  --
  -- Darum eine pro Charakter eindeutige Kennung.
  return "Solo:" .. (UnitName("player") or "Unknown")
end

function BCRAFT_MakeKey(player, guild)
  if not player or player == "" then return nil end
  -- Leere Gilde darf nie zu einem Sammel-Schluessel werden (siehe
  -- BCRAFT_OwnGuild): sonst laufen wieder mehrere Spieler unter einer Kennung.
  if not guild or guild == "" then guild = BCRAFT_OwnGuild() end
  return player .. "@" .. guild
end

function BCRAFT_SplitKey(key)
  if not key then return nil, nil end
  local at = string.find(key, "@", 1, true)
  if not at then
    -- Alter Schluessel ohne Gilde (vor der Migration)
    return key, nil
  end
  return string.sub(key, 1, at - 1), string.sub(key, at + 1)
end

local function myKey()
  return BCRAFT_MakeKey(playerName(), BCRAFT_OwnGuild())
end

local function ensureDB()
  if not _G[DB_NAME] then _G[DB_NAME] = {} end
  local db = _G[DB_NAME]
  if not db.guild then db.guild = {} end

  -- Einmalig: Reste der entfernten Testdaten (/bctest) aus alten
  -- SavedVariables loeschen, damit sie nie an echte Gilden gehen.
  if not db.testPurged then
    for key, data in pairs(db.guild) do
      if type(data) == "table" and data.isTestData then db.guild[key] = nil end
    end
    db.testPurged = true
  end

  -- MIGRATION auf gildenbewusste Schluessel.
  -- Laeuft genau einmal (db.schema wird danach gesetzt). Alte Eintraege
  -- ohne "@" bekommen die EIGENE Gilde angehaengt -- das ist die einzig
  -- sinnvolle Annahme, denn vor dieser Version konnten ueberhaupt nur
  -- Daten aus der eigenen Gilde in der DB landen.
  if not db.schema or db.schema < 2 then
    local ownGuild = BCRAFT_OwnGuild()
    local migrated = 0
    local rekeyed = {}

    for key, data in pairs(db.guild) do
      if string.find(key, "@", 1, true) then
        rekeyed[key] = data               -- schon migriert, unveraendert lassen
      else
        local newKey = BCRAFT_MakeKey(key, ownGuild)
        if rekeyed[newKey] then
          -- Kollision: neueren Datensatz behalten, nichts stillschweigend wegwerfen.
          -- "YYYY-MM-DD HH:MM:SS" sortiert als String korrekt chronologisch,
          -- darum reicht hier ein simpler Stringvergleich (parseTimestamp ist
          -- an dieser Stelle im File noch nicht als local sichtbar).
          local oldTs = tostring(rekeyed[newKey].updated or "")
          local newTs = tostring(data.updated or "")
          if newTs > oldTs then rekeyed[newKey] = data end
        else
          rekeyed[newKey] = data
        end
        migrated = migrated + 1
      end
    end

    db.guild = rekeyed
    db.schema = 2

    if migrated > 0 then
      debug("Migration: " .. migrated .. " Eintraege auf Gildenschluessel umgestellt (Gilde: " .. ownGuild .. ")")
    end
  end

  -- MIGRATION 2 -> 3: der alte Sammel-Schluessel "Ohne Gilde" wird durch die
  -- pro Charakter eindeutige Solo-Kennung ersetzt. Betroffen ist nur der
  -- EIGENE Charakter -- fremde Eintraege unter "Ohne Gilde" stammen von
  -- anderen Spielern, deren echte Kennung wir nicht kennen; die bleiben
  -- stehen und verschwinden beim naechsten Sync von selbst.
  if db.schema < 3 then
    local me = playerName()
    local legacyKey = me .. "@Ohne Gilde"
    if db.guild[legacyKey] then
      local newKey = BCRAFT_MakeKey(me, BCRAFT_OwnGuild())
      if newKey ~= legacyKey then
        if not db.guild[newKey] then
          db.guild[newKey] = db.guild[legacyKey]
        end
        db.guild[legacyKey] = nil
        debug("Migration: eigener Solo-Eintrag umgestellt auf " .. newKey)
      end
    end
    db.schema = 3
  end

  -- Die Partnerfunktion wurde entfernt (2.7.0): Daten der bisher bekannten
  -- Partnergilden und den Partnerbereich einmalig aus der Datenbank loeschen.
  -- Die eigene Gilde wird dabei nie angefasst.
  if db.partner then
    if type(db.partner.guilds) == "table" then
      local own = BCRAFT_OwnGuild()
      for g, _ in pairs(db.partner.guilds) do
        if g ~= own then
          local suffix = "@" .. g
          for key, _ in pairs(db.guild) do
            if string.sub(key, -string.len(suffix)) == suffix then db.guild[key] = nil end
          end
        end
      end
    end
    db.partner = nil
  end

    -- MIGRATION: Convert old db.me to per-character storage
  if db.me and db.me.profs and not db.characters then
    local myChar = playerName()
    db.characters = {}
    db.characters[myChar] = {
      profs = db.me.profs,
      updated = db.me.updated or now()
    }
    -- Don't delete db.me yet, just mark as migrated
    db.me._migrated = true
    
    debug("Migration complete! Your profession data has been converted.")
  end
  
  -- NEW: Per-character storage instead of account-wide
  local myChar = playerName()
  if not db.characters then db.characters = {} end
  if not db.characters[myChar] then db.characters[myChar] = {} end
  if not db.characters[myChar].profs then db.characters[myChar].profs = {} end
  if not db.characters[myChar].updated then db.characters[myChar].updated = now() end
  
  -- Keep db.me for backward compatibility (points to current character)
  db.me = db.characters[myChar]

  -- Realm merken: Alts anderer Realms werden nicht veroeffentlicht, man
  -- koennte sie dort nicht anfluestern.
  if GetRealmName then db.me.realm = GetRealmName() end

  -- altOf[Name@Gilde] = Besitzer. Wird zusammen mit den Alt-Rezepten verteilt,
  -- damit jeder "Alt von <Besitzer>" sehen kann.
  if not db.altOf then db.altOf = {} end
  if not db.altOfTs then db.altOfTs = {} end       -- Zeitstempel der Zuordnung (neueste gewinnt)
  if not db.altConfirm then db.altConfirm = {} end
  if not db.gather then db.gather = {} end        -- [Name@Gilde] = { Mining = {rank,max,ts}, Herbalism = {...} } -- vom Alt selbst bestaetigte Besitzer
  -- db.mainChar: Hauptcharakter dieses Accounts (account-weit in den SavedVariables)
  do
    -- Alte "geloescht"-Markierungen (Zuordnung entfernt) nach 30 Tagen vergessen
    local cutoff = time() - 30 * 24 * 60 * 60
    for key, ts in pairs(db.altOfTs) do
      if not db.altOf[key] and ts < cutoff then db.altOfTs[key] = nil end
    end
  end
  
  -- Verwaiste Solo-Eintraege aufraeumen, sobald die Gilde bekannt ist.
  -- Wer frueher gildenlos war und inzwischen in einer Gilde ist, steht
  -- sonst doppelt in der Liste: einmal als "Name@Gilde" und einmal als
  -- "Name@Solo:Name" ("<no guild (Name)>", nicht erreichbar).
  if not BCRAFT_SoloPurged and GetGuildInfo and GetGuildInfo("player") then
    BCRAFT_SoloPurged = true
    local me = playerName()
    local stale = {}
    for key in pairs(db.guild) do
      local at = string.find(key, "@Solo:", 1, true)
      if at then
        local nm = string.sub(key, 1, at - 1)
        local soloOf = string.sub(key, at + 6)
        if nm == soloOf then
          -- Eigener Solo-Eintrag ist immer veraltet; fremde nur, wenn derselbe
          -- Spieler inzwischen unter einer echten Gilde bekannt ist.
          local dup = (nm == me)
          if not dup then
            local prefix = nm .. "@"
            for k2 in pairs(db.guild) do
              if k2 ~= key and string.sub(k2, 1, string.len(prefix)) == prefix
                 and not string.find(k2, "@Solo:", 1, true) then
                dup = true
                break
              end
            end
          end
          if dup then table.insert(stale, key) end
        end
      end
    end
    for i = 1, table.getn(stale) do db.guild[stale[i]] = nil end
    if table.getn(stale) > 0 then
      debug("Aufgeraeumt: " .. table.getn(stale) .. " veraltete Solo-Eintraege entfernt")
    end
  end

  -- Rezepte reparieren, die wegen eines zu fruehen Scans unter dem
  -- Platzhalter-Beruf "UNKNOWN" gelandet sind: das Addon kennt zu jedem
  -- Rezept der 7 Berufe den richtigen Beruf (BCRAFT_RecipeMaps).
  if not BCRAFT_UnknownRepaired then
    BCRAFT_UnknownRepaired = true
    local owner = {}
    if BCRAFT_RecipeMaps then
      for prof, recipes in pairs(BCRAFT_RecipeMaps) do
        for rname, _ in pairs(recipes) do
          if owner[rname] == nil then owner[rname] = prof else owner[rname] = false end
        end
      end
    end
    local fixed = 0
    local function repairProfs(profs)
      if type(profs) ~= "table" then return end
      local badKeys = {}
      for pname, _ in pairs(profs) do
        if isBadProfName(pname) then table.insert(badKeys, pname) end
      end
      for b = 1, tlen(badKeys) do
        local bad = profs[badKeys[b]]
        profs[badKeys[b]] = nil
        if type(bad) == "table" and type(bad.recipes) == "table" then
          for i = 1, tlen(bad.recipes) do
            local rec = bad.recipes[i]
            local rname = type(rec) == "table" and rec.name or rec
            local prof = rname and owner[rname]
            if prof then
              if not profs[prof] then
                profs[prof] = { rank = 0, maxRank = 0, recipes = {}, scannedAt = bad.scannedAt }
              end
              if not profs[prof].recipes then profs[prof].recipes = {} end
              local have = false
              for j = 1, tlen(profs[prof].recipes) do
                local r2 = profs[prof].recipes[j]
                if (type(r2) == "table" and r2.name or r2) == rname then have = true break end
              end
              if not have then
                table.insert(profs[prof].recipes, rec)
                fixed = fixed + 1
              end
            end
          end
        end
      end
    end
    for _, data in pairs(db.guild) do
      if type(data) == "table" then repairProfs(data.profs) end
    end
    for _, data in pairs(db.characters) do
      if type(data) == "table" then repairProfs(data.profs) end
    end
    if fixed > 0 then
      debug("UNKNOWN repariert: " .. fixed .. " Rezepte")
    end
  end

  if not db.settings then db.settings = {} end
  if db.settings.onlineOnly == nil then db.settings.onlineOnly = false end
  if db.settings.altConfirm == nil then db.settings.altConfirm = false end
  if not db.bank then db.bank = {} end  -- Bank inventory storage
  if not db.bankScanned then db.bankScanned = nil end  -- Last bank scan timestamp
  return db
end

-- STEP 2: Online status via cached roster lookup
-- PERFORMANCE: The roster is scanned ONCE and cached in a lookup table.
-- Previously this function ran GuildRoster() + a full roster scan for every
-- single recipe of every crafter, on every keystroke in the search box.
local OnlineCache = {}        -- OnlineCache[name] = true/false
local OnlineCacheTime = 0     -- GetTime() of last rebuild
local ONLINE_CACHE_TTL = 10   -- seconds before the cache is considered stale

-- Rebuild the online lookup table from the guild roster (one pass).
local function refreshOnlineCache(force)
  local nowT = GetTime and GetTime() or 0

  if not force and OnlineCacheTime > 0 and (nowT - OnlineCacheTime) < ONLINE_CACHE_TTL then
    return  -- cache still fresh
  end

  OnlineCache = {}
  OnlineCacheTime = nowT

  -- Current player is always online
  OnlineCache[playerName()] = true

  if GetNumGuildMembers then
    GuildRoster()  -- one request per rebuild, not per recipe
    local numGuildMembers = GetNumGuildMembers()
    if numGuildMembers then
      for i = 1, numGuildMembers do
        local guildName, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if guildName then
          OnlineCache[guildName] = (online == 1)
        end
      end
    end
  end
end

-- Cheap lookup: no server request, no roster scan.
local function isPlayerOnline(name)
  if not name then return false end
  if name == playerName() then return true end

  refreshOnlineCache(false)
  return OnlineCache[name] == true
end

local function copyTable(t)
  local r = {}
  for k, v in pairs(t or {}) do r[k] = v end
  return r
end

local function norm(s)
  if not s then return "" end
  if type(s) ~= "string" then s = tostring(s) end
  return string.lower(s)
end

-- Safe timestamp parsing helper
local function parseTimestamp(timestamp)
  -- Accept epoch timestamps directly
  if type(timestamp) == "number" then
    return timestamp
  end

  if not timestamp then return nil end
  if type(timestamp) ~= "string" then return nil end

  -- trim spaces
  timestamp = string.gsub(timestamp, "^%s+", "")
  timestamp = string.gsub(timestamp, "%s+$", "")

  -- accept ISO-like "YYYY-MM-DDTHH:MM:SS"
  timestamp = string.gsub(timestamp, "T", " ")

  -- Vanilla Lua uses string.find with captures
  local _, _, year, month, day, hour, min, sec =
    string.find(timestamp, "^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$")

  if not (year and month and day and hour and min and sec) then
    return nil
  end

  return time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = tonumber(sec)
  })
end

-- -------------------------
-- Hashing helper (djb2-style, used by the ping/pong sync below)
-- -------------------------
-- Vanilla Lua 5.0 has no bitwise ops, so we keep the hash inside a plain
-- Lua number range using mod() after every multiply/add.
local function hashString(str)
  local hash = 5381
  for i = 1, string.len(str) do
    local c = string.byte(str, i)
    hash = mod(hash * 33 + c, 4294967296)
  end
  return hash
end

-- Cheap content fingerprint for one profession: sorted recipe names + how
-- many crafters we know for each. Doesn't need to be perfect, just needs to
-- change whenever the data actually changes, so two clients can agree
-- "we already have the same thing" without transferring anything.
local function professionHash(profData)
  if not profData or not profData.recipes then return 0 end

  local names = {}
  for i = 1, tlen(profData.recipes) do
    local rec = profData.recipes[i]
    if type(rec) == "table" and rec.name then
      table.insert(names, rec.name)
    end
  end
  table.sort(names)

  local s = tostring(profData.rank or 0) .. ";"
  for i = 1, tlen(names) do
    s = s .. names[i] .. ";"
  end

  return hashString(s)
end

-- -------------------------
-- Protocol safety
-- -------------------------
local SEP = "~"

-- Trenner zwischen den einzelnen Rezepten innerhalb eines Chunks.
--
-- Frueher stand hier "\n". Ueber Addon-Nachrichten (Gildenkanal) geht das
-- problemlos. Ein druckbares Zeichen ist trotzdem robuster, weil es auch
-- Export-Texte und die Zwischenablage unveraendert uebersteht.
--
-- Bewusst KEIN Steuerzeichen: die filtert der Chat genauso weg wie den
-- Zeilenumbruch. "^" ist druckbar, wird unveraendert durchgereicht und
-- kommt weder in Rezeptnamen noch in Reagenzien noch in Icon-Pfaden
-- ("Interface\\Icons\\INV_...") vor. Auch nicht "~" (Feldtrenner) oder
-- "#" (Trenner innerhalb eines Rezepts).
local LINE_SEP = "^"

local function safe(str)
  if str == nil then return "" end
  if type(str) ~= "string" then str = tostring(str) end
  str = string.gsub(str, "~", "-")
  str = string.gsub(str, "%^", "-")  -- LINE_SEP darf nicht in Nutzdaten stehen
  str = string.gsub(str, "\n", " ")
  str = string.gsub(str, "\r", "")
  return str
end

-- -------------------------
-- Send queue (throttle)
-- -------------------------
local SendQueue = {}
local SendThrottle = CreateFrame("Frame")
SendThrottle:Hide()

-- Broadcast Queue for sequential profession broadcasting
local BroadcastQueue = {}
local BroadcastTimer = CreateFrame("Frame")
BroadcastTimer:Hide()
BroadcastTimer.elapsed = 0
BroadcastTimer.delay = 2.0  -- 2 seconds between broadcasts

local function enqueueSend(chatType, payload)
  table.insert(SendQueue, { chatType = chatType, payload = payload })
  SendThrottle:Show()
end

SendThrottle:SetScript("OnUpdate", function()
  this.elapsed = (this.elapsed or 0) + arg1
  
  -- Send one message every 0.1 seconds (100ms throttle)
  if this.elapsed < 0.1 then
    return
  end
  
  this.elapsed = 0
  
  if tlen(SendQueue) == 0 then
    SendThrottle:Hide()
    return
  end
  
  local item = table.remove(SendQueue, 1)
  
  if SendAddonMessage then
    local payloadSize = string.len(item.payload)
    
    -- Vanilla has 255 byte limit!
    if payloadSize > 255 then
      debug("|cffff8800[SEND] Message zu gross!|r " .. payloadSize .. " bytes (Max: 255)")
      return
    end
    
    -- Vanilla 1.12 uses 4 parameters: (prefix, message, type, target)
    local success = pcall(SendAddonMessage, PREFIX, item.payload, item.chatType, nil)
    
    if not success then
      debug("|cffff0000[SEND] FEHLER beim Senden!|r")
    end
    -- Success messages removed - no spam!
  else
    debug("|cffff0000[SEND] SendAddonMessage nicht verfuegbar!|r")
  end
end)

-- Broadcast Timer: Sends one profession every 2 seconds
BroadcastTimer:SetScript("OnUpdate", function()
  this.elapsed = this.elapsed + arg1
  
  if this.elapsed >= this.delay then
    this.elapsed = 0
    
    if tlen(BroadcastQueue) == 0 then
      -- "Gesendet" erst melden, wenn auch die Gilden-Sendewarteschlange leer ist.
      if tlen(SendQueue) > 0 then return end
      BroadcastTimer:Hide()
      msg("|cff00ff00" .. BCRAFT_L.ALL_SENT .. "|r")
      return
    end
    
    -- Get next job
    local job = table.remove(BroadcastQueue, 1)
    local remaining = tlen(BroadcastQueue)
    
    msg("|cffffff00" .. BCRAFT_L.SENDING .. "|r " .. job.charName .. " - " .. BCRAFT_ProfName(job.profName) .. " (" .. remaining .. " " .. BCRAFT_L.REMAINING .. ")")
    
    -- Broadcast this profession with direct data
    BCRAFT_BroadcastProfession(job.profName, job.charName, job.profData)
  end
end)

-- -------------------------
-- Pending receive buffer
-- -------------------------
local Pending = {}

local function getPending(player, prof)
  if not Pending[player] then Pending[player] = {} end
  if not Pending[player][prof] then
    Pending[player][prof] = { total = 0, chunks = {}, rank = 0, maxRank = 0 }
  end
  return Pending[player][prof]
end

local function clearPending(player, prof)
  if Pending[player] then Pending[player][prof] = nil end
end

-- -------------------------
-- STEP 1 (Alternative): Cleanup old professions based on timestamp (5 days)
-- -------------------------
local function cleanupOldProfessions()
  -- Wrap in pcall to prevent crashes
  local success, err = pcall(function()
    local db = ensureDB()
    local currentTime = time()
    local maxAge = 14 * 24 * 60 * 60  -- 5 days in seconds
    
    local cleaned = 0
    
    for profName, profData in pairs(db.me.profs) do
      -- Safety checks
      if type(profData) == "table" and profData.scannedAt then
        local scanTime = parseTimestamp(profData.scannedAt)
        
        if scanTime then
          local age = currentTime - scanTime
          
          if age > maxAge then
            -- Older than 2 minutes - remove it
            db.me.profs[profName] = nil
            
            -- Update guild entry
            if db.guild[myKey()] and db.guild[myKey()].profs then
              db.guild[myKey()].profs[profName] = nil
            end
            
            debug("|cffff8800Gelöscht:|r " .. profName .. " (älter als 2 Minuten)")
            
            -- Broadcast deletion to guild
            local delMsg = "DEL" .. SEP .. safe(playerName()) .. SEP .. safe(profName)
            enqueueSend("GUILD", delMsg)
            
            cleaned = cleaned + 1
          end
        end
      end
    end
    
    if cleaned > 0 then
      debug("Cleanup: " .. cleaned .. " alte Berufe entfernt")
    end
  end)
  
  if not success then
    debug("Cleanup Fehler: " .. tostring(err))
  end
end

-- Cleanup old professions from ALL players (called on UI open only)
local function cleanupOldProfessionsFromAllPlayers()
  local db = ensureDB()
  local currentTime = time()
  local maxAge = 14 * 24 * 60 * 60  -- 14 Tage
  local cleaned = 0
  
  for player, data in pairs(db.guild) do
    if data.profs then
      for profName, profData in pairs(data.profs) do
        if type(profData) == "table" and profData.scannedAt then
          local scanTime = parseTimestamp(profData.scannedAt)
          
          if scanTime then
            local age = currentTime - scanTime
            if age > maxAge then
              -- Remove old profession from this player
              db.guild[player].profs[profName] = nil
              cleaned = cleaned + 1
              debug("UI-Cleanup: " .. player .. " - " .. profName .. " (Alter: " .. math.floor(age/60) .. " min)")
            end
          end
        end
      end
    end
  end
  
  if cleaned > 0 then
    debug("UI-Cleanup: " .. cleaned .. " alte Berufe von allen Spielern entfernt")
  end
end

-- -------------------------
-- Scan TradeSkill
-- -------------------------
local function scanCurrentTradeSkill()
  if not GetTradeSkillLine or not GetNumTradeSkills or not GetTradeSkillInfo then
    debug("TradeSkill API nicht verfügbar.")
    return
  end

  local profName, rank, maxRank = GetTradeSkillLine()
  if not profName or profName == "" then 
    debug("Kein Beruf geöffnet")
    return
  end
  if isBadProfName(profName) then
    debug("Beruf noch nicht geladen (UNKNOWN) - spaeter nochmal")
    return false  -- Signal failure for retry
  end

  -- IMPORTANT: Normalize profession name (German → English)
  local profNameOriginal = profName
  profName = normalizeProfessionName(profName)
  
  debug("Scanne Beruf: " .. profNameOriginal .. " → " .. profName)

  -- FIXED: Check if this profession was already scanned THIS SESSION for THIS CHARACTER
  local myChar = playerName()
  if LastScannedProf[myChar] and LastScannedProf[myChar] == profName then
    debug("Beruf '" .. profName .. "' wurde bereits in dieser Session gescannt")
    return
  end
  
  LastScannedProf[myChar] = profName

  local n = GetNumTradeSkills()
  if not n or n <= 0 then 
    debug("Keine Rezepte gefunden")
    return false  -- Signal failure for retry
  end

  local recipes = {}
  local currentHeader = nil

  for i = 1, n do
    local name, skillType = GetTradeSkillInfo(i)
    if name and skillType then
      if skillType == "header" then
        currentHeader = name
        -- Header debug removed for cleaner output
      else
        -- Get item link to extract item ID (optional for Enchanting)
        local itemLink = GetTradeSkillItemLink(i)
        local itemID = nil
        local iconTexture = nil
        
        if itemLink then
          -- Extract item ID from link: |Hitem:12345:0:0:0|h
          local _, _, id = string.find(itemLink, "item:(%d+)")
          if id then
            itemID = tonumber(id)
            debug("Recipe: " .. name .. " -> Item ID: " .. itemID)
          end
        else
          debug("Recipe: " .. name .. " -> No item link (Enchanting?)")
        end
        
        -- Get icon texture directly from tradeskill window
        iconTexture = GetTradeSkillIcon(i)
        
        local reagents = {}
        local numReagents = GetTradeSkillNumReagents and GetTradeSkillNumReagents(i)
        if numReagents and numReagents > 0 then
          for r = 1, numReagents do
            local rName, _, rCount = GetTradeSkillReagentInfo(i, r)
            if rName and rName ~= "" and rCount then
              table.insert(reagents, { name = rName, count = rCount })
            end
          end
        end
        
        -- Get tradeskill description
        local description = nil
        if GetTradeSkillDescription then
          description = GetTradeSkillDescription(i)
        end

        table.insert(recipes, {
          name = name,
          header = currentHeader,
          reagents = reagents,
          itemID = itemID,  -- May be nil for Enchanting
          icon = iconTexture,
          description = description,  -- NEW: Recipe description
        })
        
        -- Simplified debug output (Header/Category removed for cleaner log)
      end
    end
  end

  local db = ensureDB()
  db.me.profs[profName] = {
    rank = rank or 0,
    maxRank = maxRank or 0,
    recipes = recipes,
    scannedAt = now(),
  }
  db.me.updated = now()

  db.guild[myKey()] = { updated = db.me.updated, profs = copyTable(db.me.profs) }

  debug("Gescannt: |cff00ff00" .. profName .. "|r (" .. (rank or 0) .. "/" .. (maxRank or 0) .. ") — Rezepte: " .. tostring(tlen(recipes)))
  
  -- SAFETY: If no recipes found, clear cache so we can try again
  if tlen(recipes) == 0 then
    local myChar = playerName()
    LastScannedProf[myChar] = nil
    debug("WARNUNG: Keine Rezepte gefunden - Cache gelöscht für erneuten Versuch")
    return false  -- Signal failure for retry
  end

  -- STEP 1: Cleanup old professions after scan
  cleanupOldProfessions()

  local gname = GetGuildInfo and GetGuildInfo("player")
  if gname and gname ~= "" then
    BCRAFT_BroadcastProfession(profName)
  end
  
  msg("|cff00ff00" .. BCRAFT_L.SCANNED .. "|r " .. BCRAFT_ProfName(profName) .. " (" .. tlen(recipes) .. " " .. BCRAFT_L.RECIPES_SUFFIX .. ")")
  return true  -- Signal success
end

local function scanCurrentCraft()
  if not GetCraftDisplaySkillLine or not GetNumCrafts or not GetCraftInfo then
    debug("Craft API nicht verfügbar.")
    return
  end

  local profName, rank, maxRank = GetCraftDisplaySkillLine()
  if not profName or profName == "" then
    debug("Kein Craft-Beruf geöffnet")
    return
  end
  if isBadProfName(profName) then
    debug("Craft-Beruf noch nicht geladen (UNKNOWN) - spaeter nochmal")
    return false  -- Signal failure for retry
  end

  local profNameOriginal = profName
  profName = normalizeProfessionName(profName)
  
  debug("Scanne Craft: " .. profNameOriginal .. " → " .. profName)

  -- FIXED: Check if this craft profession was already scanned THIS SESSION for THIS CHARACTER
  local myChar = playerName()
  if LastScannedProf[myChar] and LastScannedProf[myChar] == profName then
    debug("Beruf '" .. profName .. "' wurde bereits in dieser Session gescannt")
    return
  end
  
  LastScannedProf[myChar] = profName

  local n = GetNumCrafts()
  if not n or n <= 0 then
    debug("Craft: Keine Rezepte gefunden")
    return false  -- Signal failure for retry
  end

  debug("Scanne Craft: " .. profName .. " (Anzahl: " .. n .. ")")

  local recipes = {}
  local currentHeader = nil

  for i = 1, n do
    local name, craftType = GetCraftInfo(i)
    if name and craftType then
      if craftType == "header" then
        currentHeader = name
        -- Header debug removed for cleaner output
      else
        local iconTexture = GetCraftIcon and GetCraftIcon(i)

        -- ItemLink/ID ist bei Enchanting oft nil – also NICHT nötig machen
        local itemLink = GetCraftItemLink and GetCraftItemLink(i)
        local itemID = nil
        if itemLink then
          local _, _, id = string.find(itemLink, "item:(%d+)")
          if id then itemID = tonumber(id) end
        end

        local reagents = {}
        local numReagents = GetCraftNumReagents and GetCraftNumReagents(i)
        if numReagents and numReagents > 0 then
          for r = 1, numReagents do
            local rName, _, rCount = GetCraftReagentInfo(i, r)
            if rName and rName ~= "" and rCount then
              table.insert(reagents, { name = rName, count = rCount })
            end
          end
        end
        
        -- Get craft description (for Enchanting spells)
        local description = nil
        if GetCraftDescription then
          description = GetCraftDescription(i)
        end

        table.insert(recipes, {
          name = name,
          header = currentHeader,
          reagents = reagents,
          itemID = itemID,     -- kann nil sein
          icon = iconTexture,  -- kann nil sein
          description = description,  -- NEW: Enchanting spell description
        })
        
        -- Detailed category debug removed for cleaner output
      end
    end
  end

  local db = ensureDB()
  db.me.profs[profName] = {
    rank = rank or 0,
    maxRank = maxRank or 0,
    recipes = recipes,
    scannedAt = now(),
  }
  db.me.updated = now()
  db.guild[myKey()] = { updated = db.me.updated, profs = copyTable(db.me.profs) }

  debug("Gescannt: |cff00ff00" .. profName .. "|r (" .. (rank or 0) .. "/" .. (maxRank or 0) .. ") — Rezepte: " .. tostring(tlen(recipes)))
  
  -- SAFETY: If no recipes found, clear cache so we can try again
  if tlen(recipes) == 0 then
    local myChar = playerName()
    LastScannedProf[myChar] = nil
    debug("WARNUNG: Keine Rezepte gefunden - Cache gelöscht für erneuten Versuch")
    return false  -- Signal failure for retry
  end

  cleanupOldProfessions()

  local gname = GetGuildInfo and GetGuildInfo("player")
  if gname and gname ~= "" then
    BCRAFT_BroadcastProfession(profName)
  end
  
  msg("|cff00ff00" .. BCRAFT_L.SCANNED .. "|r " .. BCRAFT_ProfName(profName) .. " (" .. tlen(recipes) .. " " .. BCRAFT_L.RECIPES_SUFFIX .. ")")
  return true  -- Signal success
end

-- -------------------------
-- Delayed Scan Timer (MUST be after scan functions!)
-- -------------------------
local ScanTimer = CreateFrame("Frame")
ScanTimer:Hide()
ScanTimer.elapsed = 0
ScanTimer.delay = 0.5  -- 500ms delay
ScanTimer.scanType = nil  -- "tradeskill" or "craft"
ScanTimer.retryCount = 0
ScanTimer.maxRetries = 3

ScanTimer:SetScript("OnUpdate", function()
  this.elapsed = this.elapsed + arg1
  
  if this.elapsed >= this.delay then
    this.elapsed = 0
    ScanTimer:Hide()
    
    -- Execute the scan
    if this.scanType == "tradeskill" then
      local success = scanCurrentTradeSkill()
      
      -- Retry if failed and retries available
      if not success and this.retryCount < this.maxRetries then
        this.retryCount = this.retryCount + 1
        debug("Scan fehlgeschlagen - Retry " .. this.retryCount .. "/" .. this.maxRetries .. " in 1 Sekunde...")
        this.delay = 1.0  -- 1 second for retry
        ScanTimer:Show()
      else
        this.retryCount = 0
        this.delay = 0.5  -- Reset to default
      end
      
    elseif this.scanType == "craft" then
      local success = scanCurrentCraft()
      
      -- Retry if failed and retries available
      if not success and this.retryCount < this.maxRetries then
        this.retryCount = this.retryCount + 1
        debug("Scan fehlgeschlagen - Retry " .. this.retryCount .. "/" .. this.maxRetries .. " in 1 Sekunde...")
        this.delay = 1.0  -- 1 second for retry
        ScanTimer:Show()
      else
        this.retryCount = 0
        this.delay = 0.5  -- Reset to default
      end
    end
  end
end)

local function scheduleScan(scanType)
  ScanTimer.scanType = scanType
  ScanTimer.retryCount = 0
  ScanTimer.elapsed = 0
  ScanTimer.delay = 0.5
  ScanTimer:Show()
  debug("Scan geplant in 0.5 Sekunden...")
end


-- -------------------------
-- UI refresh debounce
--
-- Borrowed from GuildRecipes Octo's handling of UNIT_INVENTORY_CHANGED: that
-- event (and, for us, every single keystroke in the search box) can fire many
-- times in a fraction of a second. uiBuildData() re-scans the whole guild
-- database and the online roster on every call, so without debouncing, typing
-- a five-letter search term means five full rebuilds instead of one. This
-- cancels any pending rebuild and reschedules it 0.15s out, so a burst of
-- keystrokes (or any other rapid trigger) collapses into a single refresh.
-- -------------------------
local UIRefreshTimer = CreateFrame("Frame")
UIRefreshTimer:Hide()
UIRefreshTimer.elapsed = 0
UIRefreshTimer.delay = 0.15

local function scheduleUIRefresh()
  UIRefreshTimer.elapsed = 0
  UIRefreshTimer:Show()
end

UIRefreshTimer:SetScript("OnUpdate", function()
  this.elapsed = this.elapsed + arg1
  if this.elapsed < this.delay then return end

  this.elapsed = 0
  UIRefreshTimer:Hide()

  if BCRAFT_UI_Refresh then
    BCRAFT_UI_Refresh()
  end
end)

-- -------------------------
-- Broadcast
-- -------------------------
function BCRAFT_BroadcastProfession(profName, characterName, profData)
  -- profData is now passed directly instead of using db.me
  if not profData then
    -- Fallback: try to get from db.me (for backward compatibility)
    local db = ensureDB()
    profData = db.me.profs[profName]
  end
  
  if not profData then 
    debug("Keine Daten für " .. profName)
    return 
  end

  -- Uebertragen wird immer der gildenbewusste Schluessel "Name@Gilde".
  -- Kommt schon ein Schluessel mit "@" rein, bleibt er unveraendert --
  -- sonst wuerde beim Weiterreichen fremder Daten deren Gilde faelschlich
  -- durch die eigene ersetzt.
  local p = characterName or playerName()
  if not string.find(p, "@", 1, true) then
    p = BCRAFT_MakeKey(p, BCRAFT_OwnGuild())
  end
  local rank = profData.rank or 0
  local maxRank = profData.maxRank or 0
  local recipes = profData.recipes or {}

  if tlen(recipes) == 0 then
    debug("Keine Rezepte für " .. profName)
    return
  end

  local recipeData = {}
  for i = 1, tlen(recipes) do
    local rec = recipes[i]
    local recStr = safe(rec.name or "")
    
    if rec.reagents and tlen(rec.reagents) > 0 then
      local reagentStr = ""
      for r = 1, tlen(rec.reagents) do
        local rg = rec.reagents[r]
        reagentStr = reagentStr .. rg.count .. "x" .. safe(rg.name) .. ";"
      end
      recStr = recStr .. "#" .. reagentStr
    end
    
    -- Add item ID at the end (if available)
    if rec.itemID then
      recStr = recStr .. "#" .. tostring(rec.itemID)
    end
    
    -- Add icon texture (if available)
    if rec.icon then
      recStr = recStr .. "#" .. safe(rec.icon)
    end
    
    table.insert(recipeData, recStr)
  end

  local chunks = {}
  local buf = ""
  
  -- Calculate overhead: "C~PlayerName~ProfName~ChunkIndex~"
  local overhead = string.len("C" .. SEP .. safe(p) .. SEP .. safe(profName) .. SEP .. "999" .. SEP)
  -- 240 statt 255: Sicherheitsabstand zur Laengengrenze von Addon-Nachrichten.
  local maxChunkSize = 240 - overhead
  
  for i = 1, tlen(recipeData) do
    local line = recipeData[i] .. LINE_SEP
    if string.len(buf .. line) > maxChunkSize then
      table.insert(chunks, buf)
      buf = line
    else
      buf = buf .. line
    end
  end
  
  if string.len(buf) > 0 then
    table.insert(chunks, buf)
  end

  local total = tlen(chunks)
  
  local startMsg = "S" .. SEP .. safe(p) .. SEP .. safe(profName) .. SEP .. tostring(rank) .. SEP .. tostring(maxRank) .. SEP .. tostring(total)
  local endMsg = "E" .. SEP .. safe(p) .. SEP .. safe(profName)

  do
    debug("[SEND] Broadcasting to GUILD: " .. p .. " - " .. profName .. " (" .. total .. " chunks)")

    enqueueSend("GUILD", startMsg)

    for idx = 1, total do
      local chunkMsg = "C" .. SEP .. safe(p) .. SEP .. safe(profName) .. SEP .. tostring(idx) .. SEP .. chunks[idx]
      enqueueSend("GUILD", chunkMsg)
    end

    enqueueSend("GUILD", endMsg)
  end
end

-- Wrapper to send a profession even if not currently open
function BCRAFT_SendAllRecipesForProfession(profName)
  BCRAFT_BroadcastProfession(profName)
end

-- Hauptcharakter dieses Accounts (Besitzer-Name fuer "Alt von ..."). Ohne
-- Einstellung ist es der aktuell eingeloggte Charakter.
local function altMainName()
  local db = ensureDB()
  if db.mainChar and db.characters[db.mainChar] then return db.mainChar end
  return playerName()
end

-- Zuordnung Alt -> Besitzer setzen (owner = nil: kein Alt). Aenderungen
-- bekommen einen neuen Zeitstempel, damit die neueste Angabe bei den
-- anderen gewinnt (auch das Entfernen).
local function setAltOf(db, key, owner)
  if db.altOf[key] == owner then return end
  db.altOf[key] = owner
  db.altOfTs[key] = time()
end

-- Der Alt bestaetigt selbst "ich bin Alt von <Main>" (nur wenn die optionale
-- Alt-Bestaetigung eingeschaltet ist und man als Alt eingeloggt ist).
local function sendAltConfirm()
  local db = ensureDB()
  if not db.settings.altConfirm then return end
  local main = db.mainChar
  local me = playerName()
  if not main or main == me or not db.characters[main] then return end
  if string.sub(BCRAFT_OwnGuild(), 1, 5) == "Solo:" then return end
  enqueueSend("GUILD", "ALTC" .. SEP .. safe(myKey()) .. SEP .. safe(main))
end

-- Alle Charaktere dieses Accounts (db.characters liegt account-weit in den
-- SavedVariables) unter der aktuellen Gilde in die Gildenliste uebernehmen.
-- Alles ausser dem Hauptcharakter gilt als "Alt von <Main>". Danach
-- verschickt broadcastAll() sie wie jeden anderen Eintrag. Die Gilde des Alts
-- spielt keine Rolle: er erscheint als Mitglied der Gilde, in der man gerade
-- eingeloggt ist.
--   * ohne Gilde (Solo): nichts zu veroeffentlichen
--   * anderer Realm: ausgenommen
--   * "nicht teilen" (noShare): ausgenommen und aus der eigenen Liste entfernt
--     (der Hauptcharakter wird immer geteilt)
local function publishAccountAlts()
  local db = ensureDB()
  local me = playerName()
  local guild = BCRAFT_OwnGuild()
  if string.sub(guild, 1, 5) == "Solo:" then return 0 end

  local main = altMainName()
  -- eigener Eintrag: Alt, wenn ein anderer Charakter als Main eingestellt ist
  setAltOf(db, myKey(), (me ~= main) and main or nil)

  local realm = GetRealmName and GetRealmName() or nil
  local count = 0
  for name, data in pairs(db.characters) do
    if name ~= me and type(data) == "table" and data.profs then
      local key = BCRAFT_MakeKey(name, guild)
      local sameRealm = (not data.realm) or (not realm) or (data.realm == realm)
      local hasRecipes = false
      for _, pd in pairs(data.profs) do
        if type(pd) == "table" and pd.recipes and tlen(pd.recipes) > 0 then hasRecipes = true break end
      end
      local hasGather = data.gather and next(data.gather) ~= nil
      if sameRealm and (hasRecipes or hasGather) and (name == main or not data.noShare) then
        db.guild[key] = { updated = data.updated or now(), profs = copyTable(data.profs) }
        db.gather[key] = data.gather and copyTable(data.gather) or nil
        -- Beim Veroeffentlichen gilt der Stand als frisch, sonst raeumt die
        -- 14-Tage-Bereinigung Alts weg, die lange nicht eingeloggt waren.
        for _, pd in pairs(db.guild[key].profs) do
          if type(pd) == "table" then pd.scannedAt = now() end
        end
        setAltOf(db, key, (name ~= main) and main or nil)
        count = count + 1
      elseif db.altOf[key] == main then
        db.guild[key] = nil
        db.gather[key] = nil
        setAltOf(db, key, nil)
      end
    end
  end
  return count
end

-- -------------------------
-- Sammelberufe (Bergbau, Kraeuterkunde): wer kann was abbauen / ernten
--
-- Diese Berufe haben kein Berufsfenster mit Rezepten. Darum wird nur der
-- Fertigkeitswert gelesen (Fertigkeiten-Fenster) und mit einer kleinen
-- Nachricht "GATH" geteilt. Ob jemand ein Vorkommen abbauen kann, ergibt
-- sich aus dem benoetigten Wert (Katalog) und dem Wert des Spielers.
-- -------------------------
local GATHER_PROFS = { Mining = true, Herbalism = true }
local lastGatherScan = 0

local function sendGather(key, prof, rank, maxRank)
  if string.sub(BCRAFT_OwnGuild(), 1, 5) == "Solo:" then return end
  enqueueSend("GUILD", "GATH" .. SEP .. safe(key) .. SEP .. safe(prof) .. SEP .. tostring(rank) .. SEP .. tostring(maxRank))
end

-- Fertigkeitswerte des eigenen Charakters lesen und bei Aenderung melden
local function scanGathering()
  if not (GetNumSkillLines and GetSkillLineInfo) then return end
  local db = ensureDB()
  lastGatherScan = GetTime and GetTime() or 0
  if ExpandSkillHeader then pcall(ExpandSkillHeader, 0) end   -- alle Kategorien aufklappen
  local found = {}
  for i = 1, GetNumSkillLines() do
    local name, header, _, rank, _, _, maxRank = GetSkillLineInfo(i)
    if name and not header then
      local en = normalizeProfessionName(name)
      if GATHER_PROFS[en] then found[en] = { rank = rank or 0, max = maxRank or 0 } end
    end
  end
  local me = db.me
  if not me.gather then me.gather = {} end
  local key = myKey()
  if not db.gather[key] then db.gather[key] = {} end
  for prof, _ in pairs(GATHER_PROFS) do
    local now_ = found[prof]
    local old = me.gather[prof]
    if now_ and now_.rank > 0 then
      if not old or old.rank ~= now_.rank or old.max ~= now_.max then
        me.gather[prof] = { rank = now_.rank, max = now_.max, ts = time() }
        db.gather[key][prof] = { rank = now_.rank, max = now_.max, ts = time() }
        sendGather(key, prof, now_.rank, now_.max)
      end
    elseif old then
      me.gather[prof] = nil
      db.gather[key][prof] = nil
      sendGather(key, prof, 0, 0)
    end
  end
end

function BCRAFT_ScanGathering()
  scanGathering()
end

-- alle bekannten Sammelwerte der eigenen Charaktere an die Gilde senden (Teilen-Button)
local function sendAllGather(db)
  local guild = BCRAFT_OwnGuild()
  if string.sub(guild, 1, 5) == "Solo:" then return end
  local me = playerName()
  for name, data in pairs(db.characters) do
    if type(data) == "table" and data.gather then
      local key = BCRAFT_MakeKey(name, guild)
      if name == me or (db.guild[key] and not data.noShare) then
        for prof, g in pairs(data.gather) do
          if GATHER_PROFS[prof] and g.rank and g.rank > 0 then sendGather(key, prof, g.rank, g.max or 0) end
        end
      end
    end
  end
end

-- Spieler mit Wert in einem Sammelberuf (fuer den Katalog)
function BCRAFT_GetGatherers(prof)
  local db = ensureDB()
  refreshOnlineCache(false)
  local list = {}
  for key, profs in pairs(db.gather) do
    local g = type(profs) == "table" and profs[prof] or nil
    if g and g.rank and g.rank > 0 then
      local name, guild = BCRAFT_SplitKey(key)
      local altOf = db.altOf[key]
      local online = isPlayerOnline(name)
      local contact = name
      if altOf and not online and isPlayerOnline(altOf) then
        online = true
        contact = altOf
      end
      table.insert(list, { player = name, guild = guild, rank = g.rank, maxRank = g.max or 0,
        online = online, altOf = altOf, contact = contact })
    end
  end
  return list
end

local function broadcastAll()
  local db = ensureDB()

  -- Alts dieses Accounts zuerst in die Liste uebernehmen
  local altCount = publishAccountAlts()
  if altCount > 0 then
    msg("|cff888888" .. BCRAFT_L.ALTS_INCLUDED .. " " .. altCount .. "|r")
  end
  
  -- Clear existing queue
  BroadcastQueue = {}
  
  -- Send ALL professions from guild database (most up-to-date)
  if db.guild then
    for playerName, playerData in pairs(db.guild) do
      if type(playerData) == "table" and playerData.profs then
        for profName, profData in pairs(playerData.profs) do
          if type(profData) == "table" and profData.recipes and tlen(profData.recipes) > 0 then
            table.insert(BroadcastQueue, {
              charName = playerName,
              profName = profName,
              profData = profData  -- Pass the actual profession data directly
            })
            debug("Queued: " .. playerName .. " - " .. profName .. " (" .. tlen(profData.recipes) .. " recipes)")
          end
        end
      end
    end
  end
  
  local totalJobs = tlen(BroadcastQueue)
  
  if totalJobs > 0 then
    -- Zuordnungen "Alt von ..." der eigenen Charaktere mitschicken (klein, eine
    -- Nachricht je Charakter). Der eigene Eintrag kommt zuerst: der Empfaenger
    -- prueft anhand des Absenders, ob die Angabe plausibel ist. Fremde
    -- Zuordnungen werden nicht weitergereicht.
    local mk = myKey()
    local keys = {}
    if db.altOf[mk] or db.altOfTs[mk] then table.insert(keys, mk) end
    local seen = {}
    for k, _ in pairs(db.altOfTs) do seen[k] = true end
    for k, _ in pairs(db.altOf) do seen[k] = true end
    for k, _ in pairs(seen) do
      local nm = BCRAFT_SplitKey(k)
      if k ~= mk and nm and db.characters[nm] then table.insert(keys, k) end
    end
    for i = 1, tlen(keys) do
      local k = keys[i]
      local owner = db.altOf[k]
      if (owner and db.guild[k]) or (not owner and db.altOfTs[k]) then
        enqueueSend("GUILD", "ALT" .. SEP .. safe(k) .. SEP .. safe(owner or "") .. SEP .. tostring(db.altOfTs[k] or 0))
      end
    end
    sendAltConfirm()
    sendAllGather(db)
    if not db.mainChar and tlen(keys) > 0 then
      msg("|cffff8800" .. BCRAFT_L.SET_PICK_MAIN_HINT .. "|r")
    end
    msg("|cffffff00" .. BCRAFT_L.TRANSFER_START .. "|r " .. totalJobs .. " " .. BCRAFT_L.PROFS_QUEUED)
    msg("|cff888888" .. BCRAFT_L.EST_TIME .. " " .. (totalJobs * 2) .. " " .. BCRAFT_L.SECONDS .. "|r")
    BroadcastTimer.elapsed = 0
    BroadcastTimer:Show()
  else
    msg("|cffff0000" .. BCRAFT_L.NOTHING_TO_SEND .. "|r " .. BCRAFT_L.SCAN_FIRST)
  end
end

-- -------------------------
-- Hash-based sync (PING/PONG)
--
-- Inspired by GuildRecipes Octo's approach: instead of always broadcasting
-- everything we know (which is what /bc send still does, and which is what
-- gets throttled hard by SendThrottle/BroadcastTimer on big guilds), we first
-- ask "does anyone have a different hash for profession X than me?", wait a
-- couple seconds for replies, and then only pull full data from the single
-- guildmate whose answer looked most current. Cheap ping-pong messages
-- instead of a full recipe dump for data we may already have.
--
-- This does NOT replace the S/C/E chunk format above -- once we decide we
-- need data from someone, we still ask them to run BCRAFT_BroadcastProfession
-- for that profession, and it still goes through the same two throttles.
-- -------------------------
local SyncPinging = false
local SyncBestPing = {}   -- SyncBestPing[profName] = { player = "...", updatedAt = <ts> }

local SyncTimeoutTimer = CreateFrame("Frame")
SyncTimeoutTimer:Hide()
SyncTimeoutTimer.elapsed = 0
SyncTimeoutTimer.delay = 2.0  -- same window GRO uses for ping replies

local function requestProfessionFrom(player, profName)
  debug("[SYNC] Requesting " .. profName .. " from " .. player)
  local reqMsg = "REQ" .. SEP .. safe(player) .. SEP .. safe(profName)
  enqueueSend("GUILD", reqMsg)
end

SyncTimeoutTimer:SetScript("OnUpdate", function()
  this.elapsed = this.elapsed + arg1
  if this.elapsed < this.delay then return end

  this.elapsed = 0
  SyncTimeoutTimer:Hide()

  if not SyncPinging then return end
  SyncPinging = false

  local requested = 0
  for profName, info in pairs(SyncBestPing) do
    if info and info.player then
      requestProfessionFrom(info.player, profName)
      requested = requested + 1
    end
  end

  if requested > 0 then
    msg("|cffffff00" .. BCRAFT_L.SYNC_REQUESTING .. "|r " .. requested)
  else
    msg("|cff00ff00" .. BCRAFT_L.SYNC_UP_TO_DATE .. "|r")
  end

  SyncBestPing = {}
end)

-- Ask the guild "who has newer data than me?" for every profession we track
-- locally (own + everything already in db.guild). Sends ONE small PING
-- message instead of a full broadcast.
local function startHashSync()
  local db = ensureDB()

  if SyncPinging then
    debug("[SYNC] Already pinging, ignoring duplicate /bc sync")
    return
  end

  -- Collect the newest hash+timestamp we currently have for every profession,
  -- across everyone in db.guild (so alts/other crafters are included too).
  local knownProfs = {}  -- knownProfs[profName] = { hash = n, updatedAt = ts }

  for player, data in pairs(db.guild) do
    if type(data) == "table" and data.profs then
      for profName, profData in pairs(data.profs) do
        if type(profData) == "table" and profData.recipes and tlen(profData.recipes) > 0 then
          local h = professionHash(profData)
          local ts = parseTimestamp(profData.scannedAt) or 0
          if not knownProfs[profName] or ts > knownProfs[profName].updatedAt then
            knownProfs[profName] = { hash = h, updatedAt = ts }
          end
        end
      end
    end
  end

  local count = 0
  local pingMsg = "PING"
  for profName, info in pairs(knownProfs) do
    pingMsg = pingMsg .. SEP .. safe(profName) .. SEP .. tostring(info.hash) .. SEP .. tostring(info.updatedAt)
    count = count + 1
  end

  if count == 0 then
    msg("|cffff0000" .. BCRAFT_L.NOTHING_TO_SEND .. "|r " .. BCRAFT_L.SCAN_FIRST)
    return
  end

  SyncPinging = true
  SyncBestPing = {}
  SyncTimeoutTimer.elapsed = 0
  SyncTimeoutTimer:Show()

  debug("[SYNC] Pinging guild for " .. count .. " professions")
  enqueueSend("GUILD", pingMsg)
end

-- Someone pinged us: for each profession where our hash differs, answer with
-- our own hash + timestamp so the requester can decide who has the freshest
-- copy. We never send full recipe data here -- that only happens if we're
-- picked as the "REQ" target afterwards.
local function handlePing(parts)
  local db = ensureDB()
  local sender = parts[2]  -- filled in by caller from the message's `sender`

  local pongMsg = "PONG" .. SEP .. safe(playerName())
  local answered = 0

  -- parts layout from index 2 onward: profName, hash, updatedAt, profName, hash, updatedAt, ...
  local i = 2
  while i + 2 <= tlen(parts) do
    local profName = parts[i]
    local theirHash = tonumber(parts[i + 1]) or 0

    local myProfData = db.guild[myKey()] and db.guild[myKey()].profs and db.guild[myKey()].profs[profName]
    if myProfData then
      local myHash = professionHash(myProfData)
      if myHash ~= theirHash then
        local myTs = parseTimestamp(myProfData.scannedAt) or 0
        pongMsg = pongMsg .. SEP .. safe(profName) .. SEP .. tostring(myTs)
        answered = answered + 1
      end
    end

    i = i + 3
  end

  if answered > 0 then
    enqueueSend("GUILD", pongMsg)
  end
end

-- A guildmate answered our ping. Keep track of whoever has the newest
-- timestamp per profession; once the timeout fires we ask that one player
-- (only) for the full data.
local function handlePong(parts, sender)
  if not SyncPinging then return end

  -- parts layout from index 3 onward: profName, updatedAt, profName, updatedAt, ...
  local i = 3
  while i + 1 <= tlen(parts) do
    local profName = parts[i]
    local theirTs = tonumber(parts[i + 1]) or 0

    if not SyncBestPing[profName] or theirTs > SyncBestPing[profName].updatedAt then
      SyncBestPing[profName] = { player = sender, updatedAt = theirTs }
    end

    i = i + 2
  end
end

-- -------------------------
-- Receive (STEP 1: Added DELETE handling)
-- -------------------------
local function handleAddonMessage(prefix, text, distrib, sender)
  -- Ignore other addons silently
  if prefix ~= PREFIX then 
    return
  end
  
  -- Ignore own messages silently (BEFORE any debug output!)
  if sender == playerName() then 
    return
  end

  local parts = {}
  local idx = 1
  while idx <= string.len(text) do
    local nextSep = string.find(text, SEP, idx, true)
    if nextSep then
      table.insert(parts, string.sub(text, idx, nextSep - 1))
      idx = nextSep + 1
    else
      table.insert(parts, string.sub(text, idx))
      break
    end
  end

  if tlen(parts) < 1 then return end
  
  local cmd = parts[1]
  local db = ensureDB()

  -- Hash-based sync messages (see startHashSync/handlePing/handlePong above)
  if cmd == "PING" then
    -- parts[2] onward is profName/hash/updatedAt triples; handlePing needs
    -- the sender at parts[2] slot for logging, so pass parts as-is and read
    -- from index 2.
    local fakeParts = { "PING", sender }
    for i = 2, tlen(parts) do
      table.insert(fakeParts, parts[i])
    end
    handlePing(fakeParts)
    return
  end

  if cmd == "PONG" then
    handlePong(parts, sender)
    return
  end

  -- /bc versioncheck: someone is asking who's running what version
  if cmd == "VCHECK" then
    local reply = "VERSION" .. SEP .. safe(sender) .. SEP .. safe(playerName()) .. SEP .. safe(ADDON_VERSION)
    enqueueSend("GUILD", reply)
    return
  end

  if cmd == "VERSION" then
    if tlen(parts) >= 4 then
      local requester = parts[2]
      local respondent = parts[3]
      local version = parts[4]
      if requester == playerName() and VersionCheckActive then
        msg("|cff00ff00" .. respondent .. "|r " .. BCRAFT_L.VERSIONCHECK_RUNS .. " |cffffff00v" .. version .. "|r")
      end
    end
    return
  end

  if cmd == "REQ" then
    if tlen(parts) >= 3 then
      local targetPlayer = parts[2]
      local profName = parts[3]
      if targetPlayer == playerName() then
        debug("[SYNC] " .. sender .. " requested " .. profName .. " from us")
        local myProfData = db.guild[myKey()] and db.guild[myKey()].profs and db.guild[myKey()].profs[profName]
        if myProfData then
          BCRAFT_BroadcastProfession(profName, playerName(), myProfData)
        end
      end
    end
    return
  end

  -- STEP 1: Handle DELETE messages
  if cmd == "DEL" then
    if tlen(parts) >= 3 then
      local player = parts[2]
      local prof = parts[3]
      
      if db.guild[player] and db.guild[player].profs then
        db.guild[player].profs[prof] = nil
        debug("|cffff8800Empfangen:|r " .. player .. " hat " .. prof .. " verlernt")
        debug("DELETE: " .. player .. " - " .. prof)
        
        BCRAFT_UI_Refresh()
      end
    end
    return
  end

  -- Sammelberuf-Wert eines Spielers: GATH~Name@Gilde~Beruf~Wert~Max
  if cmd == "GATH" then
    if tlen(parts) >= 5 and string.find(parts[2], "@", 1, true) and GATHER_PROFS[parts[3]] then
      local key, prof = parts[2], parts[3]
      local rank, maxRank = tonumber(parts[4]), tonumber(parts[5])
      local nName, nGuild = BCRAFT_SplitKey(key)
      local sk = BCRAFT_MakeKey(sender, nGuild)
      -- nur der Spieler selbst oder ein Charakter desselben Accounts darf melden
      local ok = (sender == nName) or (db.altOf[key] == sender)
        or (db.altOf[sk] ~= nil and (db.altOf[sk] == nName or db.altOf[sk] == db.altOf[key]))
      if ok and rank and maxRank and rank >= 0 and rank <= 300 and maxRank <= 300 then
        if rank == 0 then
          if db.gather[key] then db.gather[key][prof] = nil end
        else
          if not db.gather[key] then db.gather[key] = {} end
          db.gather[key][prof] = { rank = rank, max = maxRank, ts = time() }
        end
        scheduleUIRefresh()
      end
    end
    return
  end

  -- "Alt von ...": Zuordnung Alt -> Besitzer (Schluessel Name@Gilde) mit
  -- Zeitstempel. Plausibilitaetspruefung anhand des Absenders: er muss der Alt
  -- selbst, der Besitzer oder ein bereits bekannter Alt desselben Besitzers
  -- sein. Einen Beweis fuer "gleicher Account" gibt es im 1.12-Client nicht.
  if cmd == "ALT" then
    if tlen(parts) >= 3 and string.find(parts[2], "@", 1, true) and string.len(parts[3]) <= 24 then
      local key, owner = parts[2], parts[3]
      local ts = tonumber(parts[4]) or 0
      local nName, nGuild = BCRAFT_SplitKey(key)
      local ok = false
      if sender == nName then
        ok = true
      elseif owner ~= "" then
        if sender == owner or db.altOf[BCRAFT_MakeKey(sender, nGuild)] == owner then ok = true end
      else
        local cur = db.altOf[key]
        if cur and (sender == cur or db.altOf[BCRAFT_MakeKey(sender, nGuild)] == cur) then ok = true end
      end
      -- aeltere Angaben (oder gleich alte) verdraengen keine neueren
      local oldTs = db.altOfTs[key]
      if ok and oldTs and ts > 0 and ts <= oldTs then ok = false end
      if ok and ts == 0 and oldTs and oldTs > 0 then ok = false end
      if ok and owner == "" and ts == 0 then ok = false end
      if ok then
        if owner == "" then db.altOf[key] = nil else db.altOf[key] = owner end
        db.altOfTs[key] = ts
        if db.altConfirm[key] and db.altConfirm[key] ~= owner then db.altConfirm[key] = nil end
        scheduleUIRefresh()
      end
    end
    return
  end

  -- Der Alt bestaetigt selbst: "ich bin Alt von <Besitzer>". Gilt nur, wenn
  -- der Absender wirklich der Charakter aus dem Schluessel ist.
  if cmd == "ALTC" then
    if tlen(parts) >= 3 and string.find(parts[2], "@", 1, true) and parts[3] ~= "" and string.len(parts[3]) <= 24 then
      local nName = BCRAFT_SplitKey(parts[2])
      if sender == nName then
        db.altConfirm[parts[2]] = parts[3]
        scheduleUIRefresh()
      end
    end
    return
  end

  -- Datensaetze mit Platzhalter-Beruf "UNKNOWN" (alte Versionen) verwerfen
  if (cmd == "S" or cmd == "C" or cmd == "E") and tlen(parts) >= 3 and isBadProfName(parts[3]) then
    return
  end

  if cmd == "S" then
    if tlen(parts) >= 6 then
      local player = parts[2]
      local prof = parts[3]
      local rankS = parts[4]
      local maxS = parts[5]
      local totalS = parts[6]
      
      local pend = getPending(player, prof)
      pend.total = tonumber(totalS) or 0
      pend.rank = tonumber(rankS) or 0
      pend.maxRank = tonumber(maxS) or 0
      pend.chunks = {}
      -- Start message removed - no spam!
    end
    return
  end

  if cmd == "C" then
    if tlen(parts) >= 4 then
      local player = parts[2]
      local prof = parts[3]
      local idxS = parts[4]
      local chunk = parts[5] or ""
      
      local pend = getPending(player, prof)
      local chunkIdx = tonumber(idxS)
      if chunkIdx then
        pend.chunks[chunkIdx] = chunk
        
        -- Calculate total from highest chunk index if not set yet
        if not pend.total or pend.total == 0 then
          local maxIdx = 0
          for idx, _ in pairs(pend.chunks) do
            if idx > maxIdx then maxIdx = idx end
          end
          if maxIdx > 0 then
            pend.total = maxIdx
          end
        end
        
        local totalStr = pend.total and pend.total > 0 and tostring(pend.total) or "?"
        debug("[RECEIVE] Chunk " .. chunkIdx .. "/" .. totalStr .. " (" .. player .. " - " .. prof .. ")")
      end
    end
    return
  end

  if cmd == "E" then
    if tlen(parts) >= 3 then
      local player = parts[2]
      local prof = parts[3]
      
      local pend = getPending(player, prof)
      local total = pend.total or 0
      local got = 0
      for k, v in pairs(pend.chunks) do
        if v then got = got + 1 end
      end

      debug("[RECEIVE] Complete: " .. player .. " - " .. prof .. " (" .. got .. "/" .. total .. " chunks)")

      if got >= total and total > 0 then
        local full = ""
        for i = 1, total do
          if pend.chunks[i] then
            full = full .. pend.chunks[i]
          end
        end

        local recipes = {}
        local lineIdx = 1
        while lineIdx <= string.len(full) do
          local lineEnd = string.find(full, LINE_SEP, lineIdx, true)
          if lineEnd then
            local line = string.sub(full, lineIdx, lineEnd - 1)
            if line and line ~= "" then
              local recipeName = line
              local reagents = {}
              local itemID = nil
              local iconTexture = nil
              
              -- Format: RecipeName#reagents;#itemID#iconTexture
              local firstSep = string.find(line, "#", 1, true)
              if firstSep then
                recipeName = string.sub(line, 1, firstSep - 1)
                local remainder = string.sub(line, firstSep + 1)
                
                -- Check for second # (item ID / icon)
                local secondSep = string.find(remainder, "#", 1, true)
                local reagentPart = remainder
                
                if secondSep then
                  reagentPart = string.sub(remainder, 1, secondSep - 1)
                  local metaPart = string.sub(remainder, secondSep + 1)
                  
                  -- Check for third # (icon texture)
                  local thirdSep = string.find(metaPart, "#", 1, true)
                  if thirdSep then
                    local itemIDStr = string.sub(metaPart, 1, thirdSep - 1)
                    iconTexture = string.sub(metaPart, thirdSep + 1)
                    itemID = tonumber(itemIDStr)
                  else
                    -- Only item ID, no icon
                    itemID = tonumber(metaPart)
                  end
                end
                
                -- Parse reagents
                local rIdx = 1
                while rIdx <= string.len(reagentPart) do
                  local rEnd = string.find(reagentPart, ";", rIdx, true)
                  if rEnd then
                    local rStr = string.sub(reagentPart, rIdx, rEnd - 1)
                    local xPos = string.find(rStr, "x", 1, true)
                    if xPos then
                      local count = tonumber(string.sub(rStr, 1, xPos - 1))
                      local name = string.sub(rStr, xPos + 1)
                      if count and name then
                        table.insert(reagents, { count = count, name = name })
                      end
                    end
                    rIdx = rEnd + 1
                  else
                    break
                  end
                end
              end
              
              table.insert(recipes, { 
                name = recipeName, 
                header = nil, 
                reagents = reagents,
                itemID = itemID,  -- Store item ID
                icon = iconTexture  -- Store icon texture
              })
            end
            lineIdx = lineEnd + 1
          else
            break
          end
        end

        -- `player` ist hier bereits der gildenbewusste Schluessel "Name@Gilde".
        -- Kommt ausnahmsweise ein alter Schluessel ohne "@" an (aeltere
        -- Addon-Version in der Gilde), haengen wir die eigene Gilde an --
        -- ueber den Gildenkanal kann es ohnehin nur die eigene sein.
        if not string.find(player, "@", 1, true) then
          player = BCRAFT_MakeKey(player, BCRAFT_OwnGuild())
        end

        if not db.guild[player] then
          db.guild[player] = { updated = now(), profs = {} }
        end
        db.guild[player].profs[prof] = {
          rank = pend.rank,
          maxRank = pend.maxRank,
          recipes = recipes,
          scannedAt = now(),
        }
        db.guild[player].updated = now()

        debug("Empfangen: " .. player .. " — " .. prof .. " (" .. tlen(recipes) .. " Rezepte)")

        BCRAFT_UI_Refresh()
      end

      clearPending(player, prof)
    end
    return
  end
end

local function uiBuildData()
  local db = ensureDB()
  local recipeMap = {}  -- Map: recipeName -> list of crafters

  -- PERFORMANCE: refresh the online lookup ONCE per rebuild, not per recipe.
  refreshOnlineCache(false)

  -- Build map of recipes to crafters
  for player, data in pairs(db.guild) do
    if data.profs then
      for profName, profData in pairs(data.profs) do
        if profData.recipes then
          for i = 1, tlen(profData.recipes) do
            local rec = profData.recipes[i]
            local rname = ""
            if type(rec) == "table" then
              rname = rec.name or ""
            else
              rname = rec or ""
            end
            
            -- Create unique key for recipe
            local key = profName .. ":" .. rname
            
            if not recipeMap[key] then
              recipeMap[key] = {
                recipe = rname,
                prof = profName,
                recipeData = rec,
                crafters = {}  -- List of players who can craft this
              }
            end
            
            -- `player` ist der Schluessel "Name@Gilde" -- fuer Anzeige und
            -- Online-Pruefung brauchen wir den reinen Namen.
            local pName, pGuild = BCRAFT_SplitKey(player)
            local isOnline = isPlayerOnline(pName or player)

            -- Alt eines Gildenmitglieds: ist der Alt selbst offline, aber der
            -- Besitzer online, zaehlt er als erreichbar und der Whisper geht
            -- an den Besitzer.
            local altOf = db.altOf and db.altOf[player] or nil
            local contact = pName or player
            if altOf and not isOnline and isPlayerOnline(altOf) then
              isOnline = true
              contact = altOf
            end

            -- bestaetigt: eigener Account (kennen wir selbst) oder der Alt hat es
            -- selbst gemeldet
            local altConfirmed = false
            if altOf then
              if db.characters[pName or player] then altConfirmed = true
              else altConfirmed = (db.altConfirm[player] == altOf) end
            end

            table.insert(recipeMap[key].crafters, {
              player = pName or player,
              altOf = altOf,
              altConfirmed = altConfirmed,
              contact = contact,
              guild = pGuild,
              rank = profData.rank or 0,
              maxRank = profData.maxRank or 0,
              online = isOnline
            })
          end
        end
      end
    end
  end
  
  -- Convert map to list
  local results = {}
  for key, data in pairs(recipeMap) do
    table.insert(results, data)
  end

  return results
end

-- fuer den Katalog (BananaCraft_Browser.lua): Rezepte samt Herstellern
function BCRAFT_GetRecipeRows()
  return uiBuildData()
end

-- -------------------------
-- STEP 3: Inventory check for reagents (Bags + Bank)
-- -------------------------
local function getItemCountInBags(itemName)
  if not itemName or itemName == "" then return 0 end
  
  local total = 0
  local searchName = string.lower(itemName)
  
  -- Search all bags (0 = backpack, 1-4 = bags)
  for bag = 0, 4 do
    local numSlots = GetContainerNumSlots(bag)
    if numSlots then
      for slot = 1, numSlots do
        local itemLink = GetContainerItemLink(bag, slot)
        if itemLink then
          local _, _, name = string.find(itemLink, "%[(.+)%]")
          if name and string.lower(name) == searchName then
            local _, count = GetContainerItemInfo(bag, slot)
            if count then
              total = total + count
            end
          end
        end
      end
    end
  end
  
  return total
end

local function getItemCountInBank(itemName)
  if not itemName or itemName == "" then return 0 end
  
  local db = ensureDB()
  local searchName = string.lower(itemName)
  
  return db.bank[searchName] or 0
end

local function scanBank()
  local db = ensureDB()
  db.bank = {}  -- Clear old data
  
  -- Scan bank slots (bags -1, 5, 6, 7, 8, 9, 10, 11)
  -- Bag -1 is the main bank (28 slots)
  local bankBags = {-1, 5, 6, 7, 8, 9, 10, 11}
  local itemCount = {}
  
  for _, bag in pairs(bankBags) do
    local numSlots = GetContainerNumSlots(bag)
    if numSlots and numSlots > 0 then
      for slot = 1, numSlots do
        local itemLink = GetContainerItemLink(bag, slot)
        if itemLink then
          local _, _, name = string.find(itemLink, "%[(.+)%]")
          if name then
            local _, count = GetContainerItemInfo(bag, slot)
            if count then
              local searchName = string.lower(name)
              if not itemCount[searchName] then
                itemCount[searchName] = 0
              end
              itemCount[searchName] = itemCount[searchName] + count
            end
          end
        end
      end
    end
  end
  
  db.bank = itemCount
  db.bankScanned = now()
  
  local totalItems = 0
  for k, v in pairs(itemCount) do
    totalItems = totalItems + 1
  end
  
  debug("Bank gescannt: " .. totalItems .. " verschiedene Items gefunden")
end

-- -------------------------
-- UI: Recipe Popup
-- -------------------------
local BCRAFT_RecipePopup = nil
local BCRAFT_RecipeQuantity = 1  -- Default quantity

function BCRAFT_ShowRecipePopup(data)
  if not BCRAFT_RecipePopup then
    local pop = CreateFrame("Frame", "BCRAFT_RecipePopup", UIParent)
    BCRAFT_RecipePopup = pop
    tinsert(UISpecialFrames, "BCRAFT_RecipePopup")
    pop:SetWidth(400)  -- Wider for table layout
    pop:SetHeight(380)  -- Taller for editbox + summary
    pop:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    pop:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    pop:SetMovable(true)
    pop:EnableMouse(true)
    pop:RegisterForDrag("LeftButton")
    pop:SetScript("OnDragStart", function() this:StartMoving() end)
    pop:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    pop:SetFrameStrata("FULLSCREEN_DIALOG")

    local title = pop:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", pop, "TOP", 0, -18)
    pop.title = title

    -- Recipe icon (top right, centered between title and content)
    local icon = CreateFrame("Button", nil, pop)
    icon:SetWidth(40)
    icon:SetHeight(40)
    icon:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -60, -32)  -- More right spacing (-60), lower position (-32)
    pop.icon = icon
    
    local iconTexture = icon:CreateTexture(nil, "ARTWORK")
    iconTexture:SetAllPoints(icon)
    iconTexture:SetTexture("Interface\\Icons\\Trade_Engineering")  -- Default icon
    pop.iconTexture = iconTexture
    
    -- Icon border
    local iconBorder = icon:CreateTexture(nil, "OVERLAY")
    iconBorder:SetAllPoints(icon)
    iconBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    iconBorder:SetTexCoord(0.2, 0.8, 0.2, 0.8)
    
    -- Enable tooltip on hover
    icon:SetScript("OnEnter", function()
      if pop.currentRecipeName and type(pop.currentRecipeName) == "string" and string.len(pop.currentRecipeName) > 0 then
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        
        pcall(function()
          -- Only use SetHyperlink if it's a valid item link (starts with "item:")
          if string.find(pop.currentRecipeName, "^item:") then
            GameTooltip:SetHyperlink(pop.currentRecipeName)
          else
            -- For Enchanting recipes (no item), just show the name
            GameTooltip:SetText(pop.currentRecipeName, 1, 1, 1)
          end
          GameTooltip:Show()
        end)
      end
    end)
    
    icon:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    local close = CreateFrame("Button", nil, pop, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -6, -6)

    -- STEP 3: Quantity EditBox
    local qtyLabel = pop:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qtyLabel:SetPoint("TOPLEFT", pop, "TOPLEFT", 22, -50)
    qtyLabel:SetText(BCRAFT_L.QUANTITY)
    pop.qtyLabelFS = qtyLabel
    
    local qtyBox = CreateFrame("EditBox", "BCRAFT_QuantityBox", pop, "InputBoxTemplate")
    qtyBox:SetWidth(60)
    qtyBox:SetHeight(20)
    qtyBox:SetPoint("LEFT", qtyLabel, "RIGHT", 10, 0)
    qtyBox:SetAutoFocus(false)
    qtyBox:SetNumeric(true)
    qtyBox:SetMaxLetters(3)
    qtyBox:SetText(tostring(BCRAFT_RecipeQuantity))
    pop.qtyBox = qtyBox
    
    qtyBox:SetScript("OnEnterPressed", function() 
      this:ClearFocus()
      local qty = tonumber(this:GetText()) or 1
      if qty < 1 then qty = 1 end
      if qty > 100 then qty = 100 end
      BCRAFT_RecipeQuantity = qty
      this:SetText(tostring(qty))
      -- Refresh display
      if pop.currentData then
        BCRAFT_UpdateRecipePopupContent(pop, pop.currentData)
      end
    end)
    
    qtyBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)

    local scrollBg = CreateFrame("Frame", nil, pop)
    scrollBg:SetPoint("TOPLEFT", pop, "TOPLEFT", 18, -80)
    scrollBg:SetPoint("BOTTOMRIGHT", pop, "BOTTOMRIGHT", -38, 80)
    scrollBg:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    scrollBg:SetBackdropColor(0, 0, 0, 0.8)
    
    -- Logo removed for clean background

    local scroll = CreateFrame("ScrollFrame", "BCRAFT_RecipePopupScrollFrame", pop, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", scrollBg, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", scrollBg, "BOTTOMRIGHT", -28, 8)
    pop.scroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(320)
    content:SetHeight(400)
    scroll:SetScrollChild(content)
    pop.content = content

    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    text:SetWidth(320)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetFont("Fonts\\ARIALN.TTF", 13)  -- Use Arial Narrow for better alignment
    pop.text = text

    -- STEP 3: Missing summary
    local missingSummary = pop:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    missingSummary:SetPoint("BOTTOMLEFT", pop, "BOTTOMLEFT", 22, 50)
    missingSummary:SetPoint("BOTTOMRIGHT", pop, "BOTTOMRIGHT", -22, 50)
    missingSummary:SetJustifyH("LEFT")
    missingSummary:SetHeight(20)
    pop.missingSummary = missingSummary

    -- Whisper dropdown button (centered at bottom, no checkbox)
    local whisperBtn = CreateFrame("Button", nil, pop, "UIPanelButtonTemplate")
    whisperBtn:SetWidth(200)
    whisperBtn:SetHeight(24)
    whisperBtn:SetPoint("BOTTOM", pop, "BOTTOM", 0, 18)
    whisperBtn:SetText(BCRAFT_L.WHISPER)
    pop.whisperBtn = whisperBtn
    
    whisperBtn:SetScript("OnClick", function()
      if not pop.currentData or not pop.currentData.crafters then return end
      
      -- Build menu with ONLY online crafters
      local menu = {}
      local hasOnline = false
      
      for i = 1, tlen(pop.currentData.crafters) do
        local crafter = pop.currentData.crafters[i]
        if crafter.online then
          hasOnline = true
          local info = {}
          info.text = crafter.player .. " (" .. crafter.rank .. "/" .. crafter.maxRank .. ")"
          if crafter.altOf then
            info.text = info.text .. " - " .. BCRAFT_L.ALT_OF .. " " .. crafter.altOf
          end
          info.notCheckable = true
          info.func = function()
            local editbox = DEFAULT_CHAT_FRAME.editBox or ChatFrameEditBox
            if editbox then
              editbox:SetText("/w " .. (crafter.contact or crafter.player) .. " ")
              editbox:Show()
              editbox:SetFocus()
            end
          end
          table.insert(menu, info)
        end
      end
      
      -- If no one online, show banana message
      if not hasOnline then
        debug("|cffff8800Leider ist derzeit keine Banane Online die dir hier weiterhelfen kann!|r")
        return
      end
      
      -- Show dropdown menu with online crafters
      if tlen(menu) > 0 then
        local dropdown = CreateFrame("Frame", "BCRAFT_WhisperMenu", pop, "UIDropDownMenuTemplate")
        UIDropDownMenu_Initialize(dropdown, function()
          for i = 1, tlen(menu) do
            UIDropDownMenu_AddButton(menu[i])
          end
        end, "MENU")
        ToggleDropDownMenu(1, nil, dropdown, whisperBtn, 0, 0)
      end
    end)

    pop:Hide()
  end

  local pop = BCRAFT_RecipePopup
  pop.currentData = data
  pop.title:SetText(data.recipe or "Rezept")
  
  -- Use item ID if available (from recipeData)
  local itemID = nil
  local iconTexture = nil
  
  if data.recipeData then
    itemID = data.recipeData.itemID
    iconTexture = data.recipeData.icon
  end
  
  -- PRIORITY 1: Use stored icon texture (from scan) - NO CACHING!
  if iconTexture and type(iconTexture) == "string" and string.len(iconTexture) > 0 then
    pop.iconTexture:SetTexture(iconTexture)
    debug("Icon: Using stored texture: " .. iconTexture)
  -- PRIORITY 2: Try GetItemInfo WITHOUT caching
  elseif itemID then
    local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemID)
    
    if texture then
      pop.iconTexture:SetTexture(texture)
      debug("Icon: Loaded from ItemID: " .. tostring(itemID))
    else
      -- Fallback to profession icon - NO CACHING!
      local professionIcons = {
        ["Alchemy"] = "Interface\\Icons\\Trade_Alchemy",
        ["Blacksmithing"] = "Interface\\Icons\\Trade_BlackSmithing",
        ["Enchanting"] = "Interface\\Icons\\Trade_Engraving",
        ["Engineering"] = "Interface\\Icons\\Trade_Engineering",
        ["Leatherworking"] = "Interface\\Icons\\Trade_LeatherWorking",
        ["Tailoring"] = "Interface\\Icons\\Trade_Tailoring",
        ["Cooking"] = "Interface\\Icons\\INV_Misc_Food_15",
        ["First Aid"] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
      }
      local iconPath = professionIcons[data.prof] or "Interface\\Icons\\INV_Misc_QuestionMark"
      pop.iconTexture:SetTexture(iconPath)
      debug("Icon: Fallback to profession icon")
    end
  else
    -- PRIORITY 3: Legacy - try by name WITHOUT caching
    local _, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(data.recipe)
    
    if itemTexture then
      pop.iconTexture:SetTexture(itemTexture)
      debug("Icon: Loaded from name: " .. (data.recipe or "nil"))
    else
      -- Fallback to profession icon
      local professionIcons = {
        ["Alchemy"] = "Interface\\Icons\\Trade_Alchemy",
        ["Blacksmithing"] = "Interface\\Icons\\Trade_BlackSmithing",
        ["Enchanting"] = "Interface\\Icons\\Trade_Engraving",
        ["Engineering"] = "Interface\\Icons\\Trade_Engineering",
        ["Leatherworking"] = "Interface\\Icons\\Trade_LeatherWorking",
        ["Tailoring"] = "Interface\\Icons\\Trade_Tailoring",
        ["Cooking"] = "Interface\\Icons\\INV_Misc_Food_15",
        ["First Aid"] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
      }
      local iconPath = professionIcons[data.prof] or "Interface\\Icons\\INV_Misc_QuestionMark"
      pop.iconTexture:SetTexture(iconPath)
      debug("Icon: Fallback to profession icon (no name match)")
    end
  end
  
  -- Set tooltip item for hover
  if itemID then
    pop.currentRecipeName = "item:" .. tostring(itemID)
  else
    pop.currentRecipeName = data.recipe
  end
  
  -- Reset quantity box
  pop.qtyBox:SetText(tostring(BCRAFT_RecipeQuantity))
  
  BCRAFT_UpdateRecipePopupContent(pop, data)

  pop:Show()
end

-- STEP 3: Update popup content with inventory check first, then crafter list at bottom
function BCRAFT_UpdateRecipePopupContent(pop, data)
  local qty = BCRAFT_RecipeQuantity
  local db = ensureDB()
  
  local infoText = ""
  local missing = {}
  
  -- Show last bank scan
  if db.bankScanned then
    infoText = infoText .. "|cffaaaaaa(Bank: " .. db.bankScanned .. ")|r\n\n"
  end
  
  -- NEW: Show recipe description (for Enchanting spells)
  if type(data.recipeData) == "table" and data.recipeData.description and data.recipeData.description ~= "" then
    infoText = infoText .. "|cff00ff00" .. data.recipeData.description .. "|r\n\n"
  end
  
  if type(data.recipeData) == "table" and data.recipeData.reagents then
    local reagents = data.recipeData.reagents
    if tlen(reagents) > 0 then
      infoText = infoText .. "|cffffff00Materialien (x" .. qty .. "):|r\n\n"
      infoText = infoText .. "|cffaaaaaa Benötigt:|r\n"
      
      -- First: Show all required items
      for i = 1, tlen(reagents) do
        local r = reagents[i]
        local needed = (r.count or 1) * qty
        infoText = infoText .. string.format("• %dx %s\n", needed, r.name or "?")
      end
      
      infoText = infoText .. "\n|cffaaaaaa Verfügbar (Bank):|r\n"
      
      -- Second: Show inventory for each item
      for i = 1, tlen(reagents) do
        local r = reagents[i]
        local needed = (r.count or 1) * qty
        local haveBags = getItemCountInBags(r.name or "")
        local haveBank = getItemCountInBank(r.name or "")
        local haveTotal = haveBags + haveBank
        
        local status = ""
        local haveColor = ""
        
        if haveTotal >= needed then
          status = " |cff00ff00✓|r"
          haveColor = "|cff00ff00"
        else
          status = " |cffff0000✗|r"
          haveColor = "|cffff0000"
          local missingCount = needed - haveTotal
          table.insert(missing, missingCount .. "x " .. (r.name or "?"))
        end
        
        -- Show: Name: Total (Bank only)
        local countStr = ""
        if haveBank > 0 then
          countStr = string.format("%d (%d)", haveTotal, haveBank)
        else
          countStr = tostring(haveTotal)
        end
        
        infoText = infoText .. "• " .. (r.name or "?") .. ": " .. haveColor .. countStr .. "|r" .. status .. "\n"
      end
    end
  end
  
  -- NOW: Add crafter list at the bottom
  infoText = infoText .. "\n|cffffff00━━━━━━━━━━━━━━━━━━━━━━|r\n"
  infoText = infoText .. "|cffffff00" .. (data.gather and BCRAFT_L.CAT_GATHERED_BY or BCRAFT_L.CAT_CRAFTED_BY) .. "|r\n\n"
  
  if data.crafters and tlen(data.crafters) > 0 then
    -- Sort crafters: online first, then by name
    local sortedCrafters = {}
    for i = 1, tlen(data.crafters) do
      table.insert(sortedCrafters, data.crafters[i])
    end
    table.sort(sortedCrafters, function(a, b)
      if a.online ~= b.online then
        return a.online  -- online first
      end
      return a.player < b.player
    end)
    
    -- Display ALL crafters (online and offline)
    for i = 1, tlen(sortedCrafters) do
      local crafter = sortedCrafters[i]
      local statusColor = crafter.online and "|cff00ff00" or "|cff888888"
      local statusText = crafter.online and BCRAFT_L.ONLINE or BCRAFT_L.OFFLINE
      
      infoText = infoText .. "• " .. statusColor .. crafter.player .. "|r"

      -- Alt eines Gildenmitglieds kennzeichnen
      if crafter.altOf then
        local altNote = BCRAFT_L.ALT_OF .. " " .. crafter.altOf
        if db.settings.altConfirm then
          altNote = altNote .. ", " .. (crafter.altConfirmed and BCRAFT_L.ALT_CONFIRMED or BCRAFT_L.ALT_CLAIMED)
        end
        infoText = infoText .. " |cffcc99ff(" .. altNote .. ")|r"
      end

      infoText = infoText .. " |cffaaaaaa(" .. (data.prof or "") .. " " .. crafter.rank .. "/" .. crafter.maxRank .. ")"
      infoText = infoText .. " " .. statusText .. "|r\n"
    end
  else
    infoText = infoText .. "|cffff0000Keine Hersteller gefunden|r\n"
  end

  pop.text:SetText(infoText)
  local textHeight = pop.text:GetHeight()
  pop.content:SetHeight(math.max(textHeight + 20, 400))
  
  -- Update missing summary
  if data.gather then
    pop.missingSummary:SetText("")
  elseif tlen(missing) > 0 then
    pop.missingSummary:SetText("|cffff0000Fehlen:|r " .. table.concat(missing, ", "))
  else
    pop.missingSummary:SetText("|cff00ff00" .. BCRAFT_L.ALL_MATS .. "|r")
  end
end

-- -------------------------
-- Oberflaeche = Katalog (BananaCraft_Browser.lua)
-- -------------------------
function BCRAFT_UI_Refresh()
  if BCRAFT_RefreshCatalog then BCRAFT_RefreshCatalog() end
end

-- alte Berufe aus der Gildenliste raeumen (beim Oeffnen des Katalogs)
function BCRAFT_CleanupOld()
  cleanupOldProfessionsFromAllPlayers()
end

-- "Datenbank mit der Gilde teilen"
function BCRAFT_ShareDatabase()
  broadcastAll()
end

-- Kurzstatistik fuer die Fusszeile: "9 Spieler | 860 Rezepte"
function BCRAFT_StatsText()
  local db = ensureDB()
  local players, recipes = 0, 0
  for _, data in pairs(db.guild) do
    if type(data) == "table" and type(data.profs) == "table" then
      local has = false
      for _, pd in pairs(data.profs) do
        if type(pd) == "table" and type(pd.recipes) == "table" and tlen(pd.recipes) > 0 then
          has = true
        end
      end
      if has then players = players + 1 end
    end
  end
  for _ in pairs(BCRAFT_GetRecipeRows()) do recipes = recipes + 1 end
  return players .. " " .. BCRAFT_L.STATS_PLAYERS .. " | " .. recipes .. " " .. BCRAFT_L.STATS_RECIPES
end

-- -------------------------
-- CSV Export
-- -------------------------
local function exportToCSV()
  local db = ensureDB()
  local csv = "Spieler,Beruf,Rank,Rezept,Reagenzien\n"
  
  -- Build CSV data
  for player, data in pairs(db.guild) do
    if data.profs then
      for profName, profData in pairs(data.profs) do
        local rank = (profData.rank or 0) .. "/" .. (profData.maxRank or 0)
        
        if profData.recipes then
          for i = 1, tlen(profData.recipes) do
            local recipe = profData.recipes[i]
            local recipeName = recipe.name or "Unknown"
            
            -- Build reagent string
            local reagentStr = ""
            if recipe.reagents then
              for r = 1, tlen(recipe.reagents) do
                local rg = recipe.reagents[r]
                if r > 1 then reagentStr = reagentStr .. "; " end
                reagentStr = reagentStr .. (rg.count or 1) .. "x " .. (rg.name or "?")
              end
            end
            
            -- Escape quotes in strings
            recipeName = string.gsub(recipeName, '"', '""')
            reagentStr = string.gsub(reagentStr, '"', '""')
            
            -- Add row
            csv = csv .. string.format('%s,%s,%s,"%s","%s"\n', 
              player, profName, rank, recipeName, reagentStr)
          end
        end
      end
    end
  end
  
  -- Count lines
  local lineCount = 0
  for _ in string.gfind(csv, "[^\n]+") do
    lineCount = lineCount + 1
  end
  
  -- Save to global variable
  BCRAFT_CSV_Export = csv
  BCRAFT_CSV_Timestamp = date("%Y-%m-%d %H:%M:%S")
  BCRAFT_CSV_Lines = lineCount
  
  -- Create export popup with copyable text
  if not BCRAFT_ExportFrame then
    local f = CreateFrame("Frame", "BCRAFT_ExportFrame", UIParent)
    f:SetWidth(600)
    f:SetHeight(400)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    
    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -20)
    title:SetText("CSV Export")
    f.title = title
    
    -- Info text
    local info = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    info:SetPoint("TOP", title, "BOTTOM", 0, -10)
    info:SetWidth(550)
    info:SetJustifyH("CENTER")
    info:SetText("|cff00ff00Strg+A → Strg+C zum Kopieren!|r")
    f.info = info
    
    -- ScrollFrame for EditBox
    local scroll = CreateFrame("ScrollFrame", "BCRAFT_ExportScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -80)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -40, 50)
    
    -- EditBox (copyable!)
    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetWidth(520)
    editBox:SetHeight(280)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontWhite)
    editBox:SetFont("Fonts\\ARIALN.TTF", 11)
    editBox:SetMaxLetters(0)  -- Unlimited
    scroll:SetScrollChild(editBox)
    f.editBox = editBox
    
    editBox:SetScript("OnEscapePressed", function()
      BCRAFT_ExportFrame:Hide()
    end)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetWidth(100)
    closeBtn:SetHeight(22)
    closeBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 15)
    closeBtn:SetText("Schließen")
    closeBtn:SetScript("OnClick", function()
      BCRAFT_ExportFrame:Hide()
    end)
    
    BCRAFT_ExportFrame = f
    tinsert(UISpecialFrames, "BCRAFT_ExportFrame")
  end
  
  -- Set CSV text
  BCRAFT_ExportFrame.editBox:SetText(csv)
  BCRAFT_ExportFrame.editBox:HighlightText()  -- Pre-select all
  BCRAFT_ExportFrame.info:SetText(string.format("|cff00ff00%d Zeilen | %s|r\n|cffffff00Strg+A → Strg+C zum Kopieren!|r", lineCount, BCRAFT_CSV_Timestamp))
  BCRAFT_ExportFrame:Show()
  
  debug("|cff00ff00CSV Export-Fenster geöffnet!|r")
  debug("|cffffff00Strg+A|r → ganzen Text markieren")
  debug("|cffffff00Strg+C|r → kopieren")
  debug("Dann in Notepad einfügen und als .csv speichern!")
end


-- -------------------------
-- Alt-Export / -Import (Text ueber die Zwischenablage)
--
-- Fuer Alts auf ANDEREN Accounts: dort "Alts exportieren", Text mit Strg+C
-- kopieren, auf dem Hauptaccount "Alts importieren" und mit Strg+V einfuegen.
-- Das Addon liest den Text nur als Daten (nichts wird ausgefuehrt). Danach
-- gelten die Charaktere wie eigene Alts: sie werden mit "Share database with
-- guild" als "Alt von <Charakter>" geteilt.
--
-- Format (reiner Text, ohne "|" und ohne Zeilenumbrueche):
--   BCX1@@<Eintrag>@@<Eintrag>...@@END~<Anzahl>~<Pruefsumme>
--   Eintrag = Name~Realm~Beruf~Rang~Max~Rezept^Rezept^...
--   Rezept  = Name#Reagenzien#ItemID  (wie im Netzwerkprotokoll)
-- -------------------------
local ALT_FORMAT = "BCX1"
local ALT_MAX_CHARS = 60
local ALT_MAX_RECIPES = 600

local function altSafe(str)
  str = safe(str)
  str = string.gsub(str, "@", "-")
  return str
end

local function altExportString()
  local db = ensureDB()
  local myRealm = GetRealmName and GetRealmName() or ""

  local names = {}
  for name, data in pairs(db.characters) do
    if type(data) == "table" and data.profs and not data.imported then
      table.insert(names, name)
    end
  end
  table.sort(names)

  local records = {}
  local charCount = 0
  for i = 1, tlen(names) do
    local name = names[i]
    local data = db.characters[name]
    local profNames = {}
    for pname, pd in pairs(data.profs) do
      if type(pd) == "table" and pd.recipes and tlen(pd.recipes) > 0 and not isBadProfName(pname) then
        table.insert(profNames, pname)
      end
    end
    table.sort(profNames)
    if tlen(profNames) > 0 then
      charCount = charCount + 1
      for j = 1, tlen(profNames) do
        local pd = data.profs[profNames[j]]
        local recipes = {}
        for r = 1, tlen(pd.recipes) do
          local rec = pd.recipes[r]
          local rname = type(rec) == "table" and rec.name or rec
          if rname and rname ~= "" then
            local rs = altSafe(rname)
            if type(rec) == "table" then
              local reagents = ""
              if rec.reagents then
                for k = 1, tlen(rec.reagents) do
                  local rg = rec.reagents[k]
                  reagents = reagents .. (rg.count or 1) .. "x" .. altSafe(rg.name) .. ";"
                end
              end
              rs = rs .. "#" .. reagents
              if rec.itemID then rs = rs .. "#" .. tostring(rec.itemID) end
            end
            table.insert(recipes, rs)
          end
        end
        table.insert(records, altSafe(name) .. "~" .. altSafe(data.realm or myRealm) .. "~" .. altSafe(profNames[j])
          .. "~" .. tostring(pd.rank or 0) .. "~" .. tostring(pd.maxRank or 0) .. "~" .. table.concat(recipes, LINE_SEP))
      end
    end
  end

  if tlen(records) == 0 then return nil, 0, 0 end
  local body = table.concat(records, "@@")
  local text = ALT_FORMAT .. "@@" .. body .. "@@END~" .. tlen(records) .. "~" .. hashString(body)
  return text, charCount, tlen(records)
end

-- Rezeptzeile "Name#Reagenzien#ItemID" -> Rezept-Tabelle
local function altParseRecipe(line)
  local name = line
  local reagents = {}
  local itemID = nil
  local firstSep = string.find(line, "#", 1, true)
  if firstSep then
    name = string.sub(line, 1, firstSep - 1)
    local remainder = string.sub(line, firstSep + 1)
    local reagentPart = remainder
    local secondSep = string.find(remainder, "#", 1, true)
    if secondSep then
      reagentPart = string.sub(remainder, 1, secondSep - 1)
      itemID = tonumber(string.sub(remainder, secondSep + 1))
    end
    local idx = 1
    while idx <= string.len(reagentPart) do
      local e = string.find(reagentPart, ";", idx, true)
      if not e then break end
      local rStr = string.sub(reagentPart, idx, e - 1)
      local x = string.find(rStr, "x", 1, true)
      if x then
        local count = tonumber(string.sub(rStr, 1, x - 1))
        local rname = string.sub(rStr, x + 1)
        if count and rname ~= "" then table.insert(reagents, { count = count, name = rname }) end
      end
      idx = e + 1
    end
  end
  if name == "" then return nil end
  return { name = name, header = nil, reagents = reagents, itemID = itemID }
end

-- Text -> Charaktere in db.characters (als imported markiert).
-- Rueckgabe: ok, Anzahl Charaktere, Anzahl Berufe, uebersprungene Namen | Fehlertext
local function altImportString(text)
  local db = ensureDB()
  if type(text) ~= "string" then return false end

  text = string.gsub(text, "[\r\n]", "")
  text = string.gsub(text, "^%s+", "")
  text = string.gsub(text, "%s+$", "")

  local head = ALT_FORMAT .. "@@"
  if string.sub(text, 1, string.len(head)) ~= head then return false end

  -- letztes "@@END~" suchen
  local endPos = nil
  local from = 1
  while true do
    local f = string.find(text, "@@END~", from, true)
    if not f then break end
    endPos = f
    from = f + 1
  end
  if not endPos then return false end

  local body = string.sub(text, string.len(head) + 1, endPos - 1)
  local tail = string.sub(text, endPos + string.len("@@END~"))
  local _, _, cntS, hashS = string.find(tail, "^(%d+)~(%d+)$")
  if not cntS or tonumber(hashS) ~= hashString(body) then return false end

  local chars = {}
  local order = {}
  local recordCount = 0
  local idx = 1
  while idx <= string.len(body) + 1 do
    local e = string.find(body, "@@", idx, true)
    local rec
    if e then rec = string.sub(body, idx, e - 1) idx = e + 2
    else rec = string.sub(body, idx) idx = string.len(body) + 2 end

    if rec ~= "" then
      recordCount = recordCount + 1
      local fields = {}
      local fi = 1
      for _ = 1, 5 do
        local t = string.find(rec, "~", fi, true)
        if not t then fields = nil break end
        table.insert(fields, string.sub(rec, fi, t - 1))
        fi = t + 1
      end
      if not fields then return false end
      local recipeStr = string.sub(rec, fi)
      local cname, realm, prof = fields[1], fields[2], fields[3]
      if cname == "" or string.len(cname) > 24 or isBadProfName(prof) then return false end

      local recipes = {}
      local li = 1
      while li <= string.len(recipeStr) and tlen(recipes) < ALT_MAX_RECIPES do
        local le = string.find(recipeStr, LINE_SEP, li, true)
        local line
        if le then line = string.sub(recipeStr, li, le - 1) li = le + 1
        else line = string.sub(recipeStr, li) li = string.len(recipeStr) + 1 end
        local r = altParseRecipe(line)
        if r then table.insert(recipes, r) end
      end

      if not chars[cname] then
        chars[cname] = { realm = realm, profs = {} }
        table.insert(order, cname)
      end
      chars[cname].profs[prof] = {
        rank = tonumber(fields[4]) or 0,
        maxRank = tonumber(fields[5]) or 0,
        recipes = recipes,
        scannedAt = now(),
      }
    end
  end

  if recordCount ~= tonumber(cntS) or tlen(order) == 0 or tlen(order) > ALT_MAX_CHARS then return false end

  local me = playerName()
  local imported, profCount = 0, 0
  local skipped = {}
  for i = 1, tlen(order) do
    local cname = order[i]
    local existing = db.characters[cname]
    -- eigene, selbst gescannte Charaktere werden nie ueberschrieben
    if cname == me or (existing and not existing.imported and existing.profs and next(existing.profs)) then
      table.insert(skipped, cname)
    else
      db.characters[cname] = {
        profs = chars[cname].profs,
        updated = now(),
        realm = chars[cname].realm,
        imported = true,
      }
      imported = imported + 1
      for _ in pairs(chars[cname].profs) do profCount = profCount + 1 end
    end
  end
  return true, imported, profCount, skipped
end

-- Importierte Charaktere wieder entfernen
local function altClearImported()
  local db = ensureDB()
  local removed = 0
  local me = playerName()
  local guild = BCRAFT_OwnGuild()
  for name, data in pairs(db.characters) do
    if type(data) == "table" and data.imported then
      db.characters[name] = nil
      local key = BCRAFT_MakeKey(name, guild)
      if db.altOf[key] or db.guild[key] then
        db.guild[key] = nil
        setAltOf(db, key, nil)
      end
      if db.mainChar == name then db.mainChar = nil end
      removed = removed + 1
    end
  end
  return removed
end

-- Fenster mit grossem, kopierbarem Textfeld (Export) bzw. Einfuegefeld (Import)
local function showAltTextWindow(mode)
  local f = BCRAFT_AltFrame
  if not f then
    f = CreateFrame("Frame", "BCRAFT_AltFrame", UIParent)
    BCRAFT_AltFrame = f
    f:SetWidth(600)
    f:SetHeight(400)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    tinsert(UISpecialFrames, "BCRAFT_AltFrame")

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", f, "TOP", 0, -20)

    f.info = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.info:SetPoint("TOP", f.title, "BOTTOM", 0, -10)
    f.info:SetWidth(540)
    f.info:SetJustifyH("CENTER")

    local scroll = CreateFrame("ScrollFrame", "BCRAFT_AltScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -90)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -40, 55)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetWidth(520)
    editBox:SetHeight(260)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontWhite)
    editBox:SetFont("Fonts\\ARIALN.TTF", 11)
    editBox:SetMaxLetters(0)  -- unbegrenzt
    scroll:SetScrollChild(editBox)
    editBox:SetScript("OnEscapePressed", function() BCRAFT_AltFrame:Hide() end)
    f.editBox = editBox

    f.actionBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.actionBtn:SetWidth(170)
    f.actionBtn:SetHeight(24)
    f.actionBtn:SetPoint("BOTTOM", f, "BOTTOM", -95, 18)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetWidth(120)
    closeBtn:SetHeight(24)
    closeBtn:SetPoint("BOTTOM", f, "BOTTOM", 95, 18)
    closeBtn:SetText(BCRAFT_L.BTN_CLOSE)
    closeBtn:SetScript("OnClick", function() BCRAFT_AltFrame:Hide() end)
    f.closeBtn = closeBtn
  end

  f.closeBtn:SetText(BCRAFT_L.BTN_CLOSE)
  f.mode = mode

  if mode == "export" then
    local text, charCount, recCount = altExportString()
    f.title:SetText(BCRAFT_L.ALTX_TITLE_EXPORT)
    if not text then
      f.info:SetText("|cffff0000" .. BCRAFT_L.ALTX_NONE .. "|r")
      f.editBox:SetText("")
    else
      f.info:SetText("|cff00ff00" .. BCRAFT_L.ALTX_INFO_EXPORT .. "|r\n|cffaaaaaa"
        .. charCount .. " " .. BCRAFT_L.ALTX_CHARS .. ", " .. recCount .. " " .. BCRAFT_L.ALTX_PROFS .. "|r")
      f.editBox:SetText(text)
    end
    f.actionBtn:SetText(BCRAFT_L.BTN_SELECT_ALL)
    f.actionBtn:SetScript("OnClick", function()
      BCRAFT_AltFrame.editBox:SetFocus()
      BCRAFT_AltFrame.editBox:HighlightText()
    end)
    f:Show()
    f.editBox:SetFocus()
    f.editBox:HighlightText()
  else
    f.title:SetText(BCRAFT_L.ALTX_TITLE_IMPORT)
    f.info:SetText("|cff00ff00" .. BCRAFT_L.ALTX_INFO_IMPORT .. "|r")
    f.editBox:SetText("")
    f.actionBtn:SetText(BCRAFT_L.BTN_DO_IMPORT)
    f.actionBtn:SetScript("OnClick", function()
      local ok, n, profs, skipped = altImportString(BCRAFT_AltFrame.editBox:GetText())
      if not ok then
        msg("|cffff0000" .. BCRAFT_L.ALTX_BAD .. "|r")
        return
      end
      msg("|cff00ff00" .. BCRAFT_L.ALTX_DONE .. "|r " .. n .. " (" .. profs .. " " .. BCRAFT_L.ALTX_PROFS .. ")")
      if tlen(skipped) > 0 then
        msg("|cffff8800" .. BCRAFT_L.ALTX_SKIPPED .. "|r " .. table.concat(skipped, ", "))
      end
      msg("|cff888888" .. BCRAFT_L.ALTX_HINT .. "|r")
      BCRAFT_AltFrame:Hide()
      if BCRAFT_RefreshSettings then BCRAFT_RefreshSettings() end
    end)
    f:Show()
    f.editBox:SetFocus()
  end
end


-- -------------------------
-- Shift-Klick auf Item/Verzauberung/Rezept -> Name ins Suchfeld
--
-- Der 1.12-Client schreibt Shift-Klick-Links nur in die Chat-Eingabezeile,
-- und nur wenn die sichtbar ist (ChatFrameEditBox:IsVisible()). Hat unser
-- Suchfeld den Cursor, tun wir so, als waere sie sichtbar, und nehmen den
-- Text selbst entgegen. Sonst laeuft alles wie gewohnt weiter.
-- -------------------------
local LINK_PREFIXES = {
  "Formula", "Pattern", "Recipe", "Plans", "Schematic", "Manual", "Design",
  "Formel", "Muster", "Rezept", "Pläne", "Plaene", "Schema", "Handbuch", "Entwurf",
  "Enchanting", "Alchemy", "Blacksmithing", "Engineering", "Leatherworking",
  "Tailoring", "Jewelcrafting", "Cooking", "First Aid", "Mining", "Smelting",
  "Verzauberkunst", "Alchimie", "Schmiedekunst", "Ingenieurskunst",
  "Lederverarbeitung", "Schneiderei", "Juwelenschleifen", "Kochkunst", "Erste Hilfe",
  "Bergbau", "Schmelzen",
}

-- "|cff...|Hitem:123|h[Pattern: Brown Linen Vest]|h|r" -> "Brown Linen Vest"
local function linkToSearchText(link)
  if type(link) ~= "string" then return nil end
  local _, _, name = string.find(link, "%[(.-)%]")
  if not name then name = link end   -- schon reiner Text
  local sep = string.find(name, ": ", 1, true)
  if sep then
    local prefix = string.sub(name, 1, sep - 1)
    for i = 1, tlen(LINK_PREFIXES) do
      if prefix == LINK_PREFIXES[i] then
        name = string.sub(name, sep + 2)
        break
      end
    end
  end
  name = string.gsub(name, "^%s+", "")
  name = string.gsub(name, "%s+$", "")
  if name == "" then return nil end
  return name
end

-- Das aktive Suchfeld (Katalog oder Crafter-Liste) setzt BCRAFT_ActiveSearchBox, wenn es den Cursor bekommt.
local function searchHasLinkFocus()
  return BCRAFT_SearchFocused and BCRAFT_ActiveSearchBox
    and BCRAFT_ActiveSearchBox:IsVisible() and IsShiftKeyDown and IsShiftKeyDown()
end

function BCRAFT_InstallLinkHook()
  if BCRAFT_LinkHooked or not ChatFrameEditBox then return end
  BCRAFT_LinkHooked = true

  local origInsert = ChatFrameEditBox.Insert
  local origIsVisible = ChatFrameEditBox.IsVisible

  ChatFrameEditBox.IsVisible = function(self)
    if searchHasLinkFocus() then return true end
    return origIsVisible(self)
  end

  ChatFrameEditBox.Insert = function(self, text)
    if searchHasLinkFocus() then
      local name = linkToSearchText(text)
      if name then
        BCRAFT_ActiveSearchBox:SetText(name)   -- loest die Suche ueber OnTextChanged aus
        return
      end
    end
    return origInsert(self, text)
  end
end

-- -------------------------
-- Einstellungsfenster (Zahnrad)
--
-- Buendelt, was frueher nur ueber /bc-Befehle ging. Die Befehle bleiben
-- zusaetzlich nutzbar.
-- -------------------------
StaticPopupDialogs["BCRAFT_CONFIRM"] = {
  text = "%s",
  button1 = YES or "Yes",
  button2 = NO or "No",
  OnAccept = function()
    local action = BCRAFT_PendingAction
    BCRAFT_PendingAction = nil
    if action then action() end
  end,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
}

local function confirmAction(text, fn)
  BCRAFT_PendingAction = fn
  StaticPopup_Show("BCRAFT_CONFIRM", text)
end

local function buildSettings()
  local f = CreateFrame("Frame", "BCRAFT_SettingsFrame", UIParent)
  BCRAFT_SettingsFrame = f
  f:SetWidth(400)
  f:SetHeight(322)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  tinsert(UISpecialFrames, "BCRAFT_SettingsFrame")  -- Esc schliesst

  local texts = {}   -- {obj, key}: wird beim Sprachwechsel neu gesetzt
  f.texts = texts

  local function label(key, x, y, font, parent)
    local fs = (parent or f):CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent or f, "TOPLEFT", x, y)
    fs:SetText(BCRAFT_L[key])
    table.insert(texts, { fs, key })
    return fs
  end

  local function button(parent, key, w, x, y, fn)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(w)
    b:SetHeight(24)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetText(BCRAFT_L[key])
    b:SetScript("OnClick", fn)
    table.insert(texts, { b, key })
    return b
  end

  local function check(name, key, y, fn, x)
    local cb = CreateFrame("CheckButton", name, f, "UICheckButtonTemplate")
    cb:SetWidth(24)
    cb:SetHeight(24)
    cb:SetPoint("TOPLEFT", f, "TOPLEFT", x or 18, y)
    local t = getglobal(name .. "Text")
    t:SetText(BCRAFT_L[key])
    table.insert(texts, { t, key })
    cb:SetScript("OnClick", function() fn(this:GetChecked() and true or false) end)
    return cb
  end

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -18)
  title:SetText(BCRAFT_L.SET_TITLE)
  table.insert(texts, { title, "SET_TITLE" })

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

  -- Sprache
  label("SET_LANG", 22, -54)
  f.langBtns = {}
  local function langBtn(code, text, x, w)
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetWidth(w)
    b:SetHeight(22)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", x, -50)
    b:SetText(text)
    b.code = code
    b:SetScript("OnClick", function()
      BCRAFT_SetLocale(this.code)
      BCRAFT_ApplyLocale()
      msg(BCRAFT_L.LANG_SWITCHED)
    end)
    table.insert(f.langBtns, b)
    return b
  end
  langBtn("enUS", "EN", 110, 40)
  langBtn("deDE", "DE", 154, 40)
  local autoB = langBtn("auto", BCRAFT_L.SET_LANG_AUTO, 198, 54)
  table.insert(texts, { autoB, "SET_LANG_AUTO" })

  -- Schalter
  f.mmCB = check("BCRAFT_SetMinimapCB", "SET_MINIMAP", -82, function(on)
    ensureDB().settings.minimapButton = on
    BCRAFT_MinimapButton_Init()
  end)
  f.dbgCB = check("BCRAFT_SetDebugCB", "SET_DEBUG", -106, function(on)
    DEBUG = on
    msg("Debug: " .. (DEBUG and "|cff00ff00AN|r" or "|cffff0000AUS|r"))
  end)
  -- Optionale Alt-Bestaetigung: Alts melden selbst "ich bin Alt von <Main>",
  -- und die Anzeige unterscheidet "bestaetigt" und "angegeben".
  f.confirmCB = check("BCRAFT_SetConfirmCB", "SET_ALT_CONFIRM", -106, function(on)
    ensureDB().settings.altConfirm = on
    if on then sendAltConfirm() end
    BCRAFT_UI_Refresh()
  end, 206)
  f.confirmCB:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(BCRAFT_L.SET_ALT_CONFIRM, 1, 1, 1)
    GameTooltip:AddLine(BCRAFT_L.SET_ALT_CONFIRM_TIP, 0.8, 0.8, 0.8, 1)
    GameTooltip:Show()
  end)
  f.confirmCB:SetScript("OnLeave", function() GameTooltip:Hide() end)


  -- Daten
  label("SET_SECTION_DATA", 22, -142)
  button(f, "BTN_RESCAN", 172, 22, -164, function() SlashCmdList["BCRAFT"]("rescan") end)
  button(f, "BTN_SEND_ALL", 172, 206, -164, function() broadcastAll() end)
  button(f, "BTN_SYNC", 172, 22, -192, function() startHashSync() end)
  button(f, "BTN_EXPORT", 172, 206, -192, function() exportToCSV() end)
  button(f, "BTN_SCANBANK", 172, 22, -220, function() scanBank() end)
  button(f, "BTN_VERSIONCHECK", 172, 206, -220, function() SlashCmdList["BCRAFT"]("versioncheck") end)

  -- Loeschen
  local delDD = CreateFrame("Frame", "BCRAFT_DeleteDropDown", f, "UIDropDownMenuTemplate")
  delDD:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -246)
  local function delDDInit()
    local db = ensureDB()
    local mine = db.characters[playerName()]
    if not (mine and mine.profs) then return end
    for pname, _ in pairs(mine.profs) do
      local info = {}
      info.text = BCRAFT_ProfName(pname)
      info.value = pname
      info.func = function()
        local pn = this.value
        UIDropDownMenu_SetText(BCRAFT_L.SET_DELETE_PROF, delDD)
        confirmAction(string.format(BCRAFT_L.CONFIRM_DELETE_PROF, BCRAFT_ProfName(pn)), function()
          SlashCmdList["BCRAFT"]("delete " .. pn)
        end)
      end
      UIDropDownMenu_AddButton(info)
    end
  end
  UIDropDownMenu_Initialize(delDD, delDDInit)
  UIDropDownMenu_SetWidth(140, delDD)
  UIDropDownMenu_SetText(BCRAFT_L.SET_DELETE_PROF, delDD)
  f.delDD = delDD
  button(f, "BTN_DELETE_ALL", 172, 206, -248, function()
    confirmAction(BCRAFT_L.CONFIRM_DELETE_ALL, function()
      SlashCmdList["BCRAFT"]("delete all")
    end)
  end)

  -- Alts dieses Accounts: angehakt = wird mit "Share database with guild"
  -- geteilt. Die Zeilen werden in BCRAFT_RefreshSettings gefuellt.
  -- Export/Import fuer Alts auf anderen Accounts
  button(f, "BTN_ALT_EXPORT", 172, 22, -276, function() showAltTextWindow("export") end)
  button(f, "BTN_ALT_IMPORT", 172, 206, -276, function() showAltTextWindow("import") end)

  -- Zwei Auswahlmenues nebeneinander:
  --   links  "Alts von anderen Accounts" (importierte Charaktere): nur teilen/nicht teilen
  --   rechts "Twinks auf selbem Account": Main waehlen und Alts teilen/nicht teilen
  -- Der Main ist nur rechts waehlbar, importierte Alts sind reine Zugabe.
  label("SET_ALTS_OTHER", 22, -342)
  label("SET_ALTS_SAME", 222, -342)

  local function afterAltChange()
    publishAccountAlts()
    BCRAFT_RefreshSettings()
    BCRAFT_UI_Refresh()
  end

  local function titleEntry(text)
    local info = {}
    info.text = text
    info.isTitle = 1
    info.notCheckable = 1
    UIDropDownMenu_AddButton(info)
  end

  -- links: importierte Charaktere
  local otherDD = CreateFrame("Frame", "BCRAFT_OtherAltsDropDown", f, "UIDropDownMenuTemplate")
  otherDD:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -360)
  UIDropDownMenu_Initialize(otherDD, function()
    local db = ensureDB()
    local names = {}
    for name, data in pairs(db.characters) do
      if type(data) == "table" and data.imported then table.insert(names, name) end
    end
    table.sort(names)
    titleEntry(BCRAFT_L.SET_MENU_SHARE)
    if tlen(names) == 0 then
      local info = {}
      info.text = BCRAFT_L.SET_DD_NONE
      info.notCheckable = 1
      info.func = function() end
      UIDropDownMenu_AddButton(info)
    end
    for i = 1, tlen(names) do
      local name = names[i]
      local info = {}
      info.text = name
      info.checked = not db.characters[name].noShare
      info.func = function()
        local rec = ensureDB().characters[name]
        if rec then
          rec.noShare = (not rec.noShare) and true or nil
          afterAltChange()
        end
      end
      UIDropDownMenu_AddButton(info)
    end
  end)
  UIDropDownMenu_SetWidth(150, otherDD)
  f.otherDD = otherDD

  -- rechts: Charaktere dieses Accounts
  local sameDD = CreateFrame("Frame", "BCRAFT_SameAltsDropDown", f, "UIDropDownMenuTemplate")
  sameDD:SetPoint("TOPLEFT", f, "TOPLEFT", 206, -360)
  UIDropDownMenu_Initialize(sameDD, function()
    local db = ensureDB()
    local realm = GetRealmName and GetRealmName() or nil
    local me = playerName()
    local names = {}
    for name, data in pairs(db.characters) do
      if type(data) == "table" and not data.imported and (name == me or (data.profs
         and ((not data.realm) or (not realm) or data.realm == realm))) then
        table.insert(names, name)
      end
    end
    table.sort(names)

    titleEntry(BCRAFT_L.SET_MENU_MAIN)
    for i = 1, tlen(names) do
      local name = names[i]
      local info = {}
      info.text = name
      info.checked = (db.mainChar == name)
      info.func = function()
        local d = ensureDB()
        if d.characters[name] then
          d.mainChar = name
          d.characters[name].noShare = nil
          sendAltConfirm()
          afterAltChange()
        end
      end
      UIDropDownMenu_AddButton(info)
    end

    -- Teilen-Haken nur fuer Charaktere, die nicht Main und nicht der aktuelle sind
    local others = {}
    for i = 1, tlen(names) do
      if names[i] ~= me and names[i] ~= db.mainChar then table.insert(others, names[i]) end
    end
    if tlen(others) > 0 then
      titleEntry(BCRAFT_L.SET_MENU_SHARE)
      for i = 1, tlen(others) do
        local name = others[i]
        local info = {}
        info.text = name
        info.checked = not db.characters[name].noShare
        info.func = function()
          local rec = ensureDB().characters[name]
          if rec then
            rec.noShare = (not rec.noShare) and true or nil
            afterAltChange()
          end
        end
        UIDropDownMenu_AddButton(info)
      end
    end
  end)
  UIDropDownMenu_SetWidth(150, sameDD)
  f.sameDD = sameDD

  f:SetScript("OnShow", function() BCRAFT_RefreshSettings() end)
  f:Hide()
  return f
end

function BCRAFT_RefreshSettings(retext)
  local f = BCRAFT_SettingsFrame
  if not f then return end
  local db = ensureDB()

  if retext then
    for i = 1, tlen(f.texts) do
      local e = f.texts[i]
      e[1]:SetText(BCRAFT_L[e[2]])
    end
    UIDropDownMenu_SetText(BCRAFT_L.SET_DELETE_PROF, f.delDD)
  end

  f.mmCB:SetChecked(db.settings.minimapButton == true)
  f.dbgCB:SetChecked(DEBUG)

  local cur = db.settings.locale or "auto"
  for i = 1, tlen(f.langBtns) do
    local b = f.langBtns[i]
    local fs = b:GetFontString()
    if fs then
      if b.code == cur then fs:SetTextColor(1, 0.82, 0) else fs:SetTextColor(0.8, 0.8, 0.8) end
    end
  end

  -- Beschriftung der beiden Auswahlmenues
  if f.confirmCB then f.confirmCB:SetChecked(db.settings.altConfirm) end
  local importedCount = 0
  for _, data in pairs(db.characters) do
    if type(data) == "table" and data.imported then importedCount = importedCount + 1 end
  end
  UIDropDownMenu_SetText(importedCount > 0 and string.format(BCRAFT_L.SET_DD_IMPORTED_N, importedCount) or BCRAFT_L.SET_DD_NONE, f.otherDD)
  if db.mainChar and db.characters[db.mainChar] then
    UIDropDownMenu_SetText(string.format(BCRAFT_L.SET_DD_MAIN, db.mainChar), f.sameDD)
  else
    UIDropDownMenu_SetText("|cffff8800" .. BCRAFT_L.SET_DD_PICK .. "|r", f.sameDD)
  end

  local contentEnd = 400

  f:SetHeight(contentEnd + 22)
end

function BCRAFT_ToggleSettings()
  local f = BCRAFT_SettingsFrame or buildSettings()
  if f:IsShown() then
    f:Hide()
  else
    f:Show()
    -- neben dem Katalog oeffnen: rechts, sonst links, sonst darueber
    if BCRAFT_PlaceNextToCatalog then BCRAFT_PlaceNextToCatalog(f, true) end
  end
end

-- -------------------------
-- Slash commands
-- -------------------------
SLASH_BCRAFT1 = "/bc"
SlashCmdList["BCRAFT"] = function(input)
  input = input or ""
  
  if type(input) ~= "string" then input = "" end

  local cmd = ""
  if input ~= "" and string.len(input) > 0 then
    local success, _, _, c = pcall(string.find, input, "^(%S+)")
    if success and c then
      cmd = c
    end
  end
  cmd = string.lower(cmd or "")

  -- /bc ohne Zusatz oeffnet den Katalog
  if cmd == "" or cmd == "katalog" or cmd == "catalog" or cmd == "show" then
    BCRAFT_ToggleCatalog()
    return
  end
  if cmd == "checkmats" then
    BCRAFT_CheckMaterials()
    return
  end

  if cmd == "help" then
    msg(BCRAFT_L.CMD_HEADER)
    msg(BCRAFT_L.CMD_CATALOG)
    msg(BCRAFT_L.CMD_SHOW)
    msg(BCRAFT_L.CMD_SCAN)
    msg(BCRAFT_L.CMD_RESCAN)
    msg(BCRAFT_L.CMD_SEND)
    msg(BCRAFT_L.CMD_SYNC)
    msg(BCRAFT_L.CMD_VERSIONCHECK)
    msg(BCRAFT_L.CMD_DELETE)
    msg(BCRAFT_L.CMD_DELETE_ALL)
    msg(BCRAFT_L.CMD_SCANBANK)
    msg(BCRAFT_L.CMD_EXPORT)
    msg(BCRAFT_L.CMD_DEBUG)
    msg(BCRAFT_L.CMD_ABOUT)
    msg(BCRAFT_L.CMD_LANG)
    return
  end

  if cmd == "about" or cmd == "danke" or cmd == "info" then
    BCRAFT_ShowThanksFrame()
    return
  end

  if string.sub(cmd, 1, 4) == "lang" then
    local which = string.sub(cmd, 6)
    if which == "de" then which = "deDE" end
    if which == "en" then which = "enUS" end
    if which ~= "deDE" and which ~= "enUS" and which ~= "auto" then
      which = "auto"
    end
    BCRAFT_SetLocale(which)
    BCRAFT_ApplyLocale()
    msg(BCRAFT_L.LANG_SWITCHED)
    return
  end

  if cmd == "scan" then 
    local myChar = playerName()
    LastScannedProf[myChar] = nil
    scanCurrentTradeSkill()
    return 
  end
  if cmd == "rescan" then
    local myChar = playerName()
    LastScannedProf[myChar] = nil
    msg(BCRAFT_L.CACHE_CLEARED)
    return
  end
  if cmd == "send" then broadcastAll(); return end
  if cmd == "sync" then startHashSync(); return end
  if cmd == "versioncheck" then
    VersionCheckResponses = {}
    VersionCheckActive = true
    msg("|cffffff00" .. BCRAFT_L.VERSIONCHECK_ASKING .. "|r")
    enqueueSend("GUILD", "VCHECK" .. SEP .. safe(playerName()))
    return
  end
  if cmd == "scanbank" then
    scanBank()
    return
  end
  if cmd == "export" then
    exportToCSV()
    return
  end
  if cmd == "altexport" then showAltTextWindow("export") return end
  if cmd == "altimport" then showAltTextWindow("import") return end
  if cmd == "altclear" then
    local n = altClearImported()
    msg("|cff00ff00" .. BCRAFT_L.ALTX_CLEARED .. "|r " .. n)
    if BCRAFT_RefreshSettings then BCRAFT_RefreshSettings() end
    BCRAFT_UI_Refresh()
    return
  end
  if cmd == "debug" then
    DEBUG = not DEBUG
    msg("Debug: " .. (DEBUG and "|cff00ff00AN|r" or "|cffff0000AUS|r"))  -- Always show this
    return
  end
  
  if cmd == "delete" then
    -- Get profession name from input
    local _, _, profName = string.find(input, "^%S+%s+(.+)")
    
    if not profName or profName == "" then
      msg(BCRAFT_L.USAGE_DELETE)
      msg(BCRAFT_L.EXAMPLE_DELETE)
      return
    end
    
    profName = string.gsub(profName, "^%s*(.-)%s*$", "%1")  -- Trim spaces
    
    local db = ensureDB()
    local myChar = playerName()
    
    if string.lower(profName) == "all" then
      -- Delete EVERYTHING - complete database wipe
      local totalChars = 0
      local totalProfs = 0
      local totalGuild = 0
      
      -- Count before deleting
      if db.characters then
        for charName, charData in pairs(db.characters) do
          totalChars = totalChars + 1
          if charData.profs then
            for prof, _ in pairs(charData.profs) do
              totalProfs = totalProfs + 1
            end
          end
        end
      end
      
      if db.guild then
        for playerName, _ in pairs(db.guild) do
          totalGuild = totalGuild + 1
        end
      end
      
      -- WIPE EVERYTHING
      db.characters = {}
      db.guild = {}
      db.me = { profs = {} }
      db.bankItems = {}
      db.bankScanned = nil
      
      -- Clear all scan caches
      LastScannedProf = {}
      
      msg("|cffff0000" .. BCRAFT_L.DB_WIPED .. "|r")
      msg("  • " .. totalChars .. " Character(e)")
      msg("  • " .. totalProfs .. " Beruf(e)")
      msg("  • " .. totalGuild .. " Gilden-Einträge")
      
      if BCRAFT_MainFrame and BCRAFT_MainFrame:IsShown() then
        BCRAFT_UI_Refresh()
      end
    else
      -- Delete specific profession (normalize name)
      local normalizedProf = normalizeProfessionName(profName)
      
      if db.characters[myChar] and db.characters[myChar].profs and db.characters[myChar].profs[normalizedProf] then
        db.characters[myChar].profs[normalizedProf] = nil
        
        -- Also clear from guild
        if db.guild[myKey()] and db.guild[myKey()].profs then
          db.guild[myKey()].profs[normalizedProf] = nil
        end
        
        msg("|cffff0000" .. BCRAFT_L.DELETED .. "|r " .. normalizedProf)
        
        if BCRAFT_MainFrame and BCRAFT_MainFrame:IsShown() then
          BCRAFT_UI_Refresh()
        end
      else
        msg("|cffff0000Fehler:|r Beruf '" .. normalizedProf .. "' nicht gefunden")
      end
    end
    return
  end

  debug("Unbekannter Befehl. /bc help")
end

-- -------------------------
-- Events
-- -------------------------
-- kleiner Timer fuer den Sammelberuf-Scan (nach Login und nach Skill-Aenderungen)
local GatherTimer = CreateFrame("Frame")
GatherTimer:Hide()
GatherTimer.elapsed = 0
GatherTimer.delay = 3
GatherTimer:SetScript("OnUpdate", function()
  this.elapsed = this.elapsed + arg1
  if this.elapsed < this.delay then return end
  this:Hide()
  scanGathering()
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")  -- Only scan when window OPENS
eventFrame:RegisterEvent("CRAFT_SHOW")         -- Only scan when window OPENS
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("BANKFRAME_OPENED")   -- Auto-scan bank
eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE") -- Keep online cache accurate
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")  -- Sammelberufe: Fertigkeitswert hat sich geaendert

eventFrame:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    if arg1 == ADDON_NAME then
      ensureDB()
      -- Vanilla 1.12 doesn't need RegisterAddonMessagePrefix!
      -- Addon messages work automatically
      debug("Addon geladen - Kommunikation aktiv")
      
      -- Check if send function exists
      if SendAddonMessage then
        debug("|cff00ff00SendAddonMessage verfuegbar|r")
      else
        debug("|cffff0000FEHLER: SendAddonMessage NICHT verfuegbar!|r")
      end
    end
    return
  end

  if event == "PLAYER_LOGIN" then
    ensureDB()
    local db = ensureDB()
    
    -- Data migration: Fix old corrupted profession data
    local cleaned = 0
    for profName, profData in pairs(db.me.profs) do
      if type(profData) ~= "table" then
        -- Corrupted data - remove it
        db.me.profs[profName] = nil
        cleaned = cleaned + 1
        debug("Migration: Entferne korrupte Daten für " .. profName)
      elseif not profData.scannedAt then
        -- Old data without timestamp - add current timestamp
        profData.scannedAt = now()
        debug("Migration: Timestamp hinzugefügt für " .. profName)
      elseif parseTimestamp(profData.scannedAt) == nil then
        -- Invalid timestamp format - add current timestamp
        profData.scannedAt = now()
        debug("Migration: Invaliden Timestamp ersetzt für " .. profName)
      end
    end
    
    -- Clean ALL guild players' invalid timestamps
    for player, data in pairs(db.guild) do
      if data.profs then
        for profName, profData in pairs(data.profs) do
          if type(profData) == "table" then
            if not profData.scannedAt then
              profData.scannedAt = now()
              debug("Migration: Timestamp für " .. player .. " - " .. profName)
              elseif parseTimestamp(profData.scannedAt) == nil then
              -- Invalid timestamp format - repair instead of deleting
              profData.scannedAt = now()
              cleaned = cleaned + 1
              debug("Migration: Invaliden Timestamp repariert für " .. player .. " - " .. profName)
            end
          end
        end
      end
    end
    
    if cleaned > 0 then
      debug("Datenbank bereinigt: " .. cleaned .. " korrupte Einträge entfernt")
    end
    
    db.guild[myKey()] = { updated = db.me.updated, profs = copyTable(db.me.profs) }
    
    -- Cleanup old professions on login (2 minutes)
    cleanupOldProfessions()
    
    -- Restore the saved language (or auto-detect from the client)
    local db = ensureDB()
    BCRAFT_SetLocale(db.settings.locale or "auto")

    -- Initialize Minimap Button
    BCRAFT_MinimapButton_Init()

    -- Shift-Klick auf Items/Verzauberungen schreibt in das Suchfeld
    BCRAFT_InstallLinkHook()

    -- Sammelberufe nach dem Login einlesen
    GatherTimer.elapsed = 0
    GatherTimer.delay = 10
    GatherTimer:Show()

    -- Optionale Alt-Bestaetigung: als Alt eingeloggt meldet der Charakter kurz
    -- nach dem Login "ich bin Alt von <Main>" (eine kleine Nachricht)
    do
      local confirmer = CreateFrame("Frame")
      confirmer.elapsed = 0
      confirmer:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed < 30 then return end
        this:Hide()
        this:SetScript("OnUpdate", nil)
        sendAltConfirm()
      end)
    end

    debug("geladen. /bc show")
    return
  end

  if event == "TRADE_SKILL_SHOW" then
    scheduleScan("tradeskill")
    return
  end

  if event == "CRAFT_SHOW" then
    scheduleScan("craft")
    return
  end

  -- Do NOT scan on UPDATE events - they fire constantly!
  -- Only scan when window OPENS (SHOW events above)

  if event == "SKILL_LINES_CHANGED" then
    -- entprellt: der Scan selbst klappt Kategorien auf und loest das Ereignis erneut aus
    local nowT = GetTime and GetTime() or 0
    if nowT - lastGatherScan > 5 then
      GatherTimer.elapsed = 0
      GatherTimer.delay = 3
      GatherTimer:Show()
    end
    return
  end

  if event == "GUILD_ROSTER_UPDATE" then
    -- Roster data changed: rebuild the online lookup and repaint if visible.
    refreshOnlineCache(true)
    BCRAFT_UI_Refresh()
    return
  end

  if event == "CHAT_MSG_ADDON" then
    handleAddonMessage(arg1, arg2, arg3, arg4)
    return
  end

  if event == "BANKFRAME_OPENED" then
    -- Auto-scan bank when opened
    scanBank()
    return
  end
end)

-- -------------------------
-- Apply the active language to every already-created widget.
-- Called after switching language so no /reload is needed.
-- -------------------------
function BCRAFT_ApplyLocale()
  if BCRAFT_RelocalizeCatalog then BCRAFT_RelocalizeCatalog() end
  if BCRAFT_RefreshSettings then BCRAFT_RefreshSettings(true) end

  -- Thanks window, if it was already built
  local tf = BCRAFT_ThanksFrame
  if tf then
    if tf.titleFS then tf.titleFS:SetText(BCRAFT_L.THANKS_TITLE) end
    if tf.bodyFS then tf.bodyFS:SetText(BCRAFT_L.THANKS_BODY) end
    if tf.nameLabelFS then tf.nameLabelFS:SetText(BCRAFT_L.CHARACTER) end
    if tf.mailBtn then tf.mailBtn:SetText(BCRAFT_L.FILL_NAME) end
    if tf.okBtn then tf.okBtn:SetText(BCRAFT_L.CLOSE) end
  end

  -- The recipe popup rebuilds its text on open, so nothing to do there.
end

-- -------------------------
-- "Thank you" / support window
-- -------------------------
local BCRAFT_AUTHOR_CHAR = "Lumihunt"

function BCRAFT_ShowThanksFrame()
  local tf = BCRAFT_ThanksFrame

  if not tf then
    tf = CreateFrame("Frame", "BCRAFT_ThanksFrame", UIParent)
    tf:SetWidth(340)
    tf:SetHeight(275)
    tf:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    tf:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    tf:SetMovable(true)
    tf:EnableMouse(true)
    tf:RegisterForDrag("LeftButton")
    tf:SetScript("OnDragStart", function() this:StartMoving() end)
    tf:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    tf:SetFrameStrata("FULLSCREEN_DIALOG")

    local tt = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tt:SetPoint("TOP", tf, "TOP", 0, -18)
    tt:SetText(BCRAFT_L.THANKS_TITLE)
    tf.titleFS = tt

    local tclose = CreateFrame("Button", nil, tf, "UIPanelCloseButton")
    tclose:SetPoint("TOPRIGHT", tf, "TOPRIGHT", -6, -6)

    local body = tf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", tf, "TOPLEFT", 24, -52)
    body:SetWidth(292)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetText(BCRAFT_L.THANKS_BODY)
    tf.bodyFS = body

    local nameLabel = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", tf, "TOPLEFT", 24, -158)
    nameLabel:SetText(BCRAFT_L.CHARACTER)
    tf.nameLabelFS = nameLabel

    -- Selectable box so the name can be copied with Ctrl+C
    local nameBox = CreateFrame("EditBox", nil, tf, "InputBoxTemplate")
    nameBox:SetWidth(150)
    nameBox:SetHeight(20)
    nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 12, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetText(BCRAFT_AUTHOR_CHAR)
    -- Keep the value fixed: undo any edit the user makes
    nameBox:SetScript("OnTextChanged", function()
      if this:GetText() ~= BCRAFT_AUTHOR_CHAR then
        this:SetText(BCRAFT_AUTHOR_CHAR)
      end
    end)
    nameBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    nameBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    tf.nameBox = nameBox

    local hint = tf:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", tf, "TOPLEFT", 24, -184)
    hint:SetWidth(292)
    hint:SetJustifyH("LEFT")
    tf.hint = hint

    -- Fills the recipient field when a mailbox is open
    local mailBtn = CreateFrame("Button", nil, tf, "UIPanelButtonTemplate")
    mailBtn:SetWidth(150)
    mailBtn:SetHeight(24)
    mailBtn:SetPoint("BOTTOMLEFT", tf, "BOTTOMLEFT", 24, 22)
    mailBtn:SetText(BCRAFT_L.FILL_NAME)
    mailBtn:SetScript("OnClick", function()
      if MailFrame and MailFrame:IsVisible() and SendMailNameEditBox then
        -- Switch to the "send mail" tab, then prefill the recipient
        if MailFrameTab2 and MailFrameTab_OnClick then
          MailFrameTab_OnClick(2)
        end
        SendMailNameEditBox:SetText(BCRAFT_AUTHOR_CHAR)
        if SendMailSubjectEditBox and SendMailSubjectEditBox:GetText() == "" then
          SendMailSubjectEditBox:SetText("BananaCraft")
        end
        msg(BCRAFT_L.RECIPIENT_SET .. " |cff00ff00" .. BCRAFT_AUTHOR_CHAR .. "|r " .. BCRAFT_L.RECIPIENT_THANKS)
        BCRAFT_ThanksFrame:Hide()
      else
        msg(BCRAFT_L.NEED_MAILBOX .. " |cffffff00" .. BCRAFT_L.MAILBOX .. "|r " .. BCRAFT_L.NEED_MAILBOX_2)
      end
    end)
    tf.mailBtn = mailBtn

    local okBtn = CreateFrame("Button", nil, tf, "UIPanelButtonTemplate")
    okBtn:SetWidth(110)
    okBtn:SetHeight(24)
    okBtn:SetPoint("BOTTOMRIGHT", tf, "BOTTOMRIGHT", -24, 22)
    okBtn:SetText(BCRAFT_L.CLOSE)
    tf.okBtn = okBtn
    okBtn:SetScript("OnClick", function() BCRAFT_ThanksFrame:Hide() end)

    BCRAFT_ThanksFrame = tf
  end

  -- Adapt the hint and the button to the current situation
  if MailFrame and MailFrame:IsVisible() then
    tf.hint:SetText(BCRAFT_L.MAILBOX_OPEN)
    tf.mailBtn:Enable()
  else
    tf.hint:SetText(BCRAFT_L.MAILBOX_CLOSED)
    tf.mailBtn:Disable()
  end

  tf.nameBox:SetText(BCRAFT_AUTHOR_CHAR)

  if tf:IsShown() then tf:Hide() else tf:Show() end
end

-- -------------------------
-- Minimap Button Functions
-- -------------------------
local MINIMAP_ICON = "Interface\\AddOns\\BananaCraft\\BananaCraft_MinimapIcon"

function BCRAFT_MinimapButton_OnClick(button)
  if button == "LeftButton" then
    BCRAFT_ToggleCatalog()
  end
end

function BCRAFT_MinimapButton_OnEnter()
  GameTooltip:SetOwner(this, "ANCHOR_LEFT")
  GameTooltip:SetText("BananaCraft")
  GameTooltipTextLeft1:SetTextColor(1, 1, 1)
  GameTooltip:AddLine(BCRAFT_L.MM_LEFTCLICK)
  GameTooltip:AddLine(BCRAFT_L.MM_RIGHTCLICK)
  GameTooltip:Show()
end

-- Position als Winkel (Grad, 0 = rechts, gegen den Uhrzeigersinn) um die Kartenmitte.
function BCRAFT_MinimapButton_UpdatePosition()
  local b = BCRAFT_MinimapButtonFrame
  if not b then return end
  local db = ensureDB()
  local a = math.rad(db.settings.minimapButtonPos or 315)
  local radius = db.settings.minimapButtonRadius or 80
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * radius, math.sin(a) * radius)
end

function BCRAFT_MinimapButton_OnDrag()
  local mx, my = Minimap:GetCenter()
  local scale = Minimap:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  BCRAFT_MinimapButton_SetPosition(math.deg(math.atan2(cy / scale - my, cx / scale - mx)))
end

function BCRAFT_MinimapButton_SetPosition(v)
  if v < 0 then
    v = v + 360
  end

  local db = ensureDB()
  db.settings.minimapButtonPos = v
  BCRAFT_MinimapButton_UpdatePosition()
end

-- Der Button wird komplett in Lua gebaut (ein Button, Icon und Rahmen direkt
-- darauf), genau wie bei den anderen BananaForge-Addons. Die fruehere
-- XML-Variante mit Frame + Kind-Button wurde von UI-Addons (pfUI & Co.)
-- beim Umgestalten der Minimap-Buttons leergeraeumt.
function BCRAFT_MinimapButton_Init()
  local db = ensureDB()

  if db.settings.minimapButton == nil then
    db.settings.minimapButton = true
  end
  if db.settings.minimapButtonPos == nil then
    db.settings.minimapButtonPos = 315
  end
  if db.settings.minimapButtonRadius == nil then
    db.settings.minimapButtonRadius = 80
  end

  if not BCRAFT_MinimapButtonFrame then
    local b = CreateFrame("Button", "BCRAFT_MinimapButtonFrame", Minimap)
    b:SetWidth(33)
    b:SetHeight(33)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("RightButton")

    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture(MINIMAP_ICON)
    icon:SetWidth(24)
    icon:SetHeight(24)
    icon:SetPoint("CENTER", b, "CENTER", 0, 1)
    b.icon = icon

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(56)
    border:SetHeight(56)
    border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)

    b:SetScript("OnClick", function() BCRAFT_MinimapButton_OnClick(arg1) end)
    b:SetScript("OnEnter", function() BCRAFT_MinimapButton_OnEnter() end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnDragStart", function()
      this:SetScript("OnUpdate", function() BCRAFT_MinimapButton_OnDrag() end)
    end)
    b:SetScript("OnDragStop", function()
      this:SetScript("OnUpdate", nil)
    end)
  end

  if db.settings.minimapButton == true then
    BCRAFT_MinimapButtonFrame:Show()
  else
    BCRAFT_MinimapButtonFrame:Hide()
  end

  BCRAFT_MinimapButton_UpdatePosition()
end
