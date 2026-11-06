-- EGM item search over EGM.ItemDB (data/items.lua: every tradeable item, parallel arrays sorted by name).
-- The 1.12 client only knows items it has cached, so ordering by name needs the shipped list (2026-11-05:
-- "ein Item leichter ordern als mit ID, wie im AH suchen, nur alle handelbaren Items").
EGM = EGM or {}
local S = {}
EGM.ItemSearch = S

local lower, byId

local function db() return EGM.ItemDB end

local function prep()
  local d = db()
  if not d or lower then return end
  lower, byId = {}, {}
  for i = 1, d.n do
    lower[i] = string.lower(d.name[i])
    byId[d.id[i]] = i
  end
end

function S.available() local d = db(); return d and d.n and d.n > 0 end

local function entry(i)
  local d = db()
  return { idx = i, id = d.id[i], name = d.name[i], stack = d.stack[i] or 1, q = d.q[i] or 1,
    tex = "Interface\\Icons\\" .. (d.icon[i] or "INV_Misc_QuestionMark") }
end

-- names that start with the text first, then names that contain it; at most `max` hits, each list in name order
function S.find(text, max)
  local d = db()
  local out = {}
  if not d then return out end
  prep()
  local t = string.lower(text or "")
  t = string.gsub(t, "^%s+", ""); t = string.gsub(t, "%s+$", "")
  if string.len(t) < 2 then return out end
  max = max or 200
  local starts, contains = {}, {}
  for i = 1, d.n do
    local p = string.find(lower[i], t, 1, true)
    if p == 1 then
      table.insert(starts, i)
      if table.getn(starts) >= max then break end
    elseif p and table.getn(contains) < max then
      table.insert(contains, i)
    end
  end
  for i = 1, table.getn(starts) do table.insert(out, entry(starts[i])) end
  for i = 1, table.getn(contains) do
    if table.getn(out) >= max then break end
    table.insert(out, entry(contains[i]))
  end
  return out
end

function S.byId(id)
  local d = db()
  if not d then return nil end
  prep()
  local i = byId[tonumber(id)]
  return i and entry(i) or nil
end
