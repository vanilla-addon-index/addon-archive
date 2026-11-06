-- EGM core: SavedVariables. EGM_DB (account, per realm: journal + item cache), EGM_CharDB (per char: settings, last prices, drafts)
EGM = EGM or {}
local DB = {}
EGM.DB = DB

local CHAR_DEFAULTS = { whisper = true, autopay = false, openAtMailbox = true, minimap = true, tooltip = true, confirmDeliver = true }
DB.defaults = CHAR_DEFAULTS

-- usable before VARIABLES_LOADED (tests, early calls); init() swaps in the saved tables
DB.realm = { events = {}, items = {}, guilds = {} }
DB.char = { whisper = true, autopay = false, openAtMailbox = true, minimap = true, last = {}, drafts = {} }

-- The journal is per realm AND guild: EGM_DB is account-wide, so chars of one account in different guilds (or
-- without one) must not share orders (2026-11-06: a guildless alt showed up in a guilded char's browse).
local bucket = { events = {} } -- no guild / name not known yet: transient, never saved
local bucketGuild = nil

-- guild name of this char, nil = not (yet) known
function DB.guildName()
  if IsInGuild and not IsInGuild() then return nil end
  local n = GetGuildInfo and GetGuildInfo("player")
  if type(n) == "string" and n ~= "" then return n end
  return nil
end
-- true = this char is certainly guildless; false = in a guild (name may still be loading)
function DB.noGuild() return IsInGuild and not IsInGuild() and true or false end
function DB.hasGuild() return bucketGuild ~= nil end
function DB.events() return bucket.events end

-- select the bucket of the current guild; the first guild char claims the legacy realm-wide journal
function DB.switch()
  local g = DB.guildName()
  if g == bucketGuild then return false end
  bucketGuild = g
  if not g then
    bucket = { events = {} }
  else
    local r = DB.realm
    r.guilds = r.guilds or {}
    local b = r.guilds[g]
    if not b then b = { events = {} }; r.guilds[g] = b end
    b.events = b.events or {}
    if r.events then
      for i = 1, table.getn(r.events) do table.insert(b.events, r.events[i]) end
      r.events = nil
    end
    bucket = b
  end
  if EGM.Journal and EGM.Journal.load then EGM.Journal.load() end
  if EGM.Fire then EGM.Fire("STATE") end
  return true
end

function DB.init()
  EGM_DB = EGM_DB or {}
  local realm = GetRealmName() or "?"
  EGM_DB[realm] = EGM_DB[realm] or {}
  local r = EGM_DB[realm]
  r.items = r.items or {}
  r.guilds = r.guilds or {}
  DB.realm = r
  bucketGuild = nil
  bucket = { events = {} }

  EGM_CharDB = EGM_CharDB or {}
  local c = EGM_CharDB
  for k, v in pairs(CHAR_DEFAULTS) do if c[k] == nil then c[k] = v end end
  c.last = c.last or {}
  c.drafts = c.drafts or {}
  DB.char = c

  if not DB.switch() and EGM.Journal and EGM.Journal.load then EGM.Journal.load() end
end
