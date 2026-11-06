-- EGM core: namespace, callbacks, money, ids, item helpers (Lua 5.0)
EGM = EGM or {}
EGM.VERSION = "0.1.5"
EGM.NO_GUILD = "Join a guild to use EGM"
EGM.PROTO = 1

local U = {}
EGM.Util = U

-- internal callbacks ------------------------------------------------------------------------------
local callbacks = {}
function EGM.On(name, fn)
  if not callbacks[name] then callbacks[name] = {} end
  table.insert(callbacks[name], fn)
end
function EGM.Fire(name, a1, a2, a3)
  local list = callbacks[name]
  if not list then return end
  for i = 1, table.getn(list) do
    local ok, err = pcall(list[i], a1, a2, a3)
    if not ok and EGM.debug and DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("EGM error in " .. name .. ": " .. tostring(err)) end
  end
end

-- UI scale ----------------------------------------------------------------------------------------
U.SCALE_MIN, U.SCALE_MAX, U.SCALE_STEP, U.SCALE_DEFAULT = 0.7, 1.3, 0.05, 1
-- clamp to [MIN, MAX] and snap to STEP; anything that is not a number falls back to the default
function U.clampScale(s)
  s = tonumber(s)
  if not s then return U.SCALE_DEFAULT end
  if s < U.SCALE_MIN then s = U.SCALE_MIN elseif s > U.SCALE_MAX then s = U.SCALE_MAX end
  s = math.floor(s / U.SCALE_STEP + 0.5) * U.SCALE_STEP
  return math.floor(s * 100 + 0.5) / 100
end
-- saved value (EGM_CharDB.ui.scale), clamped; default when unset
function U.getScale()
  local c = EGM.DB and EGM.DB.char
  return U.clampScale(c and c.ui and c.ui.scale)
end
-- clamp + save; returns the stored value
function U.saveScale(s)
  s = U.clampScale(s)
  local c = EGM.DB and EGM.DB.char
  if c then c.ui = c.ui or {}; c.ui.scale = s end
  return s
end

-- money -------------------------------------------------------------------------------------------
local function parts(c)
  c = math.floor(tonumber(c) or 0)
  if c < 0 then c = 0 end
  return math.floor(c / 10000), math.floor(math.mod(c, 10000) / 100), math.mod(c, 100)
end
function U.moneyPlain(c)
  local g, s, k = parts(c)
  local out = ""
  if g > 0 then out = g .. "g" end
  if s > 0 or (g > 0 and k > 0) then out = out .. (out ~= "" and " " or "") .. s .. "s" end
  if k > 0 then out = out .. (out ~= "" and " " or "") .. k .. "c" end
  if out == "" then out = "0c" end
  return out
end
function U.money(c)
  local g, s, k = parts(c)
  local out = ""
  local function add(v, suffix, color)
    out = out .. (out ~= "" and " " or "") .. "|cffffffff" .. v .. "|r|c" .. color .. suffix .. "|r"
  end
  if g > 0 then add(g, "g", "ffffd700") end
  if s > 0 or (g > 0 and k > 0) then add(s, "s", "ffc7c7cf") end
  if k > 0 then add(k, "c", "ffeda55f") end
  if out == "" then add(0, "c", "ffeda55f") end
  return out
end

-- time, ids, player ----------------------------------------------------------------------------------
function U.now() return time() end

local B36 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
local function b36(n, width)
  n = math.floor(n)
  local s = ""
  repeat
    local d = math.mod(n, 36)
    s = string.sub(B36, d + 1, d + 1) .. s
    n = math.floor(n / 36)
  until n == 0
  while string.len(s) < width do s = "0" .. s end
  return string.sub(s, -width)
end
local function hash(str)
  local h = 7
  for i = 1, string.len(str or "") do h = math.mod(h * 31 + string.byte(str, i), 1679616) end
  return h
end
local counter = 0
-- 8 chars: 2 from the char name, 4 from the clock, 2 from a counter + random; unique enough between a guild's clients
function U.newId(prefix)
  counter = math.mod(counter + 1, 36)
  local tail = math.mod(counter * 36 + math.random(0, 35), 1296)
  return (prefix or "") .. b36(hash(U.player()), 2) .. b36(math.mod(U.now(), 1679616), 4) .. b36(tail, 2)
end
-- short form for display ("#A7F29K")
function U.shortId(id) return id and string.sub(id, -6) or "?" end

function U.player() return UnitName("player") or "?" end

-- items ---------------------------------------------------------------------------------------------
function U.itemIdFromLink(link)
  if not link then return nil end
  local _, _, id = string.find(link, "item:(%d+)")
  local _, _, name = string.find(link, "%[(.-)%]")
  return id and tonumber(id), name
end
-- {name, tex, stack, quality} from the client cache, else from orders we know
function U.itemInfo(id)
  id = tonumber(id)
  if not id then return nil end
  -- 1.12 order: name, link, quality, minLevel, type, subType, stackCount, equipLoc, texture (no item level)
  local name, _, quality, _, _, _, stack, _, tex = GetItemInfo(id)
  if name then return { name = name, tex = tex, stack = stack or 1, quality = quality } end
  local cache = EGM.DB and EGM.DB.realm and EGM.DB.realm.items
  local c = cache and cache[id]
  if c then return { name = c.name, tex = c.tex, stack = c.stack or 1, quality = c.quality } end
  local e = EGM.ItemSearch and EGM.ItemSearch.byId(id)
  if e then return { name = e.name, tex = e.tex, stack = e.stack, quality = e.q } end
  return nil
end

function U.print(msg)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffd94f2bEGM|r " .. tostring(msg)) end
end

-- "18h", "45m", "expired"
function U.left(at)
  local s = (at or 0) - U.now()
  if s <= 0 then return "expired" end
  -- 48 h and more read as days ("6d 23h"), below that in hours
  if s >= 48 * 3600 then return math.floor(s / 86400) .. "d " .. math.floor(math.mod(s, 86400) / 3600) .. "h" end
  if s >= 3600 then return math.floor(s / 3600) .. "h" end
  return math.max(1, math.floor(s / 60)) .. "m"
end

-- The "Mail" addon (shirsig, 12-slot send window) replaces ClickSendMailItemButton / PickupContainerItem /
-- GetContainerItemInfo with hooks that keep attachments in its own table; the real send slot stays empty
-- ("Could not attach item", 2026-11-05; same cause as an earlier addon bug). Its originals live in Mail.orig.
-- Resolved per call: the hooks are installed at PLAYER_LOGIN, after EGM loaded.
function U.real(name)
  local g = getfenv(0)
  local m = rawget(g, "Mail")
  local o = type(m) == "table" and rawget(m, "orig") or nil
  if type(o) == "table" and type(o[name]) == "function" then return o[name] end
  return g[name]
end
