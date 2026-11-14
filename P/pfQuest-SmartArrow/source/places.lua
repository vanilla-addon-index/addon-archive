-- pfQuest SmartArrow
-- Copyright (C) 2026 pfQuest SmartArrow contributors
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or (at your option)
-- any later version. It is distributed WITHOUT ANY WARRANTY; see LICENSE.md.

-- pfQuest SmartArrow: special places
--
-- pfQuest's coordinates are flat (x, y, zone), so on its own the arrow cannot
-- tell that an objective is down a mine shaft or at the top of a tower. This
-- file supplies that, and nothing else, as short notes under the arrow:
--
--   shipped  a small hand-made list (data/places.lua) of well-known quest caves
--            and towers. It only says *what* the place is; its coordinates are
--            approximate, so it never moves the arrow.
--   learned  every indoor place you walk into (IsIndoors + sub-zone name):
--            where the entrance is, how far it extends, and how far it goes
--            up or down from the entrance. A learned entrance becomes a real
--            waypoint ("Enter Fargodeep Mine") when the objective is inside.
--   notes    your own: /smartarrow note <text> pins a note where you stand,
--            shown whenever an objective is within 40 yards of it.

local sqrt = math.sqrt
local getn, insert = table.getn, table.insert

local P = {}
pfQuestSmartArrowPlaces = P

local FLOOR = 6        -- yards of height that count as another floor
local MARGIN = 12      -- yards around a learned place's extent
local NOTE_RADIUS = 40 -- yards
local MAX_EXTENT = 400 -- a learned place never grows past this (bad samples)

local KIND_TEXT = {
  cave = "in the cave",
  mine = "down in the mine",
  crypt = "underground",
  building = "inside",
  tower = "at the top of the tower",
  upstairs = "upstairs",
}

local function Dist(a, b)
  local dn, dw = a.n - b.n, a.w - b.w
  return sqrt(dn * dn + dw * dw)
end

local function Store()
  return pfQuestSmartArrow_config
end

-- shipped places, resolved to world space once ------------------------------

function P:Resolve()
  self.shipped = {}
  local G = pfQuestSmartArrowGraph
  for _, p in ipairs(pfQuestSmartArrowData and pfQuestSmartArrowData.places or {}) do
    local c, n, w = G.Resolve(p.zone, p.x, p.y)
    local _, n2, w2 = G.Resolve(p.zone, p.x + (p.r or 2), p.y)
    if c and n2 then
      local r = sqrt((n2 - n) * (n2 - n) + (w2 - w) * (w2 - w))
      insert(self.shipped, { c = c, n = n, w = w, r = r, name = p.name, kind = p.kind, zone = p.zone })
    end
  end
end

local function InLearned(place, pt)
  return place.c == pt.c
    and pt.n >= place.minN - MARGIN and pt.n <= place.maxN + MARGIN
    and pt.w >= place.minW - MARGIN and pt.w <= place.maxW + MARGIN
end

-- the special place an objective lies in: learned first (it is precise),
-- then shipped. Returns learned, shipped (either may be nil).
function P:Find(target)
  if not target or not target.c then
    return nil, nil
  end
  local learned, shipped
  for _, place in ipairs(Store().places) do
    if InLearned(place, target) then
      learned = place
      break
    end
  end
  for _, place in ipairs(self.shipped or {}) do
    if place.c == target.c and Dist(place, target) <= place.r then
      shipped = place
      break
    end
  end
  -- shipped and learned are the same place when the names match
  if learned and shipped and learned.name ~= shipped.name then
    shipped = nil
  end
  -- once a shipped place has been walked, its measured extent decides: an
  -- objective merely near the approximate circle is not "inside" any more
  if not learned and shipped then
    for _, place in ipairs(Store().places) do
      if place.name == shipped.name and place.zone == shipped.zone then
        if getn(place.entrances or {}) > 0 and place.maxN - place.minN > 15 then
          return nil, nil
        end
        learned = place
        break
      end
    end
  end
  return learned, shipped
end

-- is the player already inside it?
function P:Inside(learned, shipped, player)
  if not player.indoors then
    return false
  end
  local name = (learned and learned.name) or (shipped and shipped.name)
  if name and player.sub == name then
    return true
  end
  return learned and InLearned(learned, player) or false
end

-- nearest learned entrance to the player
function P:Entrance(learned, player)
  if not learned or not learned.entrances then
    return nil
  end
  local best, bestd
  for _, e in ipairs(learned.entrances) do
    if e.c == player.c then
      local d = Dist(e, player)
      if not bestd or d < bestd then
        best, bestd = e, d
      end
    end
  end
  return best
end

-- the notes shown under the arrow for this objective
function P:Notes(target, player, final)
  local notes = {}
  if not target then
    return notes
  end

  local learned, shipped = self:Find(target)
  local name = (learned and learned.name ~= "" and learned.name) or (shipped and shipped.name)
  local kind = shipped and shipped.kind or (learned and "building")

  if learned or shipped then
    local inside = self:Inside(learned, shipped, player)
    if inside then
      if final and learned and player.z and learned.ezt then
        local up = (learned.zmax or learned.ezt) - learned.ezt
        local down = learned.ezt - (learned.zmin or learned.ezt)
        if up > FLOOR and down > FLOOR then
          insert(notes, "Several levels here: check above and below")
        elseif up > FLOOR then
          insert(notes, "Has an upper level: go up")
        elseif down > FLOOR then
          insert(notes, "Goes down: keep descending")
        end
      end
      if kind == "tower" then
        insert(notes, "Top of the tower: keep climbing")
      end
    else
      local where = KIND_TEXT[kind] or "inside"
      if kind == "tower" then
        insert(notes, "Objective is at the top of " .. (name or "the tower"))
      elseif name then
        insert(notes, "Objective is " .. where .. ": " .. name)
      else
        insert(notes, "Objective is " .. where)
      end
      if not self:Entrance(learned, player) and kind ~= "tower" then
        insert(notes, "|cff888888entrance not known yet; it is remembered once you walk in|r")
      end
    end
  end

  for _, note in ipairs(Store().notes_list) do
    if note.c == target.c and Dist(note, target) <= NOTE_RADIUS then
      insert(notes, note.text)
    end
  end

  return notes
end

-- learning ------------------------------------------------------------------

local function FindByName(zone, name)
  for _, place in ipairs(Store().places) do
    if place.zone == zone and place.name == name then
      return place
    end
  end
  return nil
end

local function Grow(place, pt)
  local minN, maxN = place.minN, place.maxN
  local minW, maxW = place.minW, place.maxW
  if pt.n < minN then minN = pt.n end
  if pt.n > maxN then maxN = pt.n end
  if pt.w < minW then minW = pt.w end
  if pt.w > maxW then maxW = pt.w end
  if maxN - minN > MAX_EXTENT or maxW - minW > MAX_EXTENT then
    return -- a teleport or a misread; ignore it
  end
  place.minN, place.maxN, place.minW, place.maxW = minN, maxN, minW, maxW
  if pt.z then
    if not place.zmin or pt.z < place.zmin then place.zmin = pt.z end
    if not place.zmax or pt.z > place.zmax then place.zmax = pt.z end
  end
end

-- called with consecutive position samples
function P:Learn(last, player)
  if pfQuestSmartArrow_config.learn ~= "1" or not last then
    return
  end
  if player.taxi or last.taxi or last.c ~= player.c or not player.zone then
    return
  end
  local moved = Dist(last, player)
  if moved > 30 then
    return -- teleport, hearth, loading screen
  end

  -- walking in: remember the doorway
  if player.indoors and not last.indoors and player.sub and player.sub ~= "" then
    local place = FindByName(player.zone, player.sub)
    if not place then
      place = {
        c = player.c, zone = player.zone, name = player.sub,
        minN = player.n, maxN = player.n, minW = player.w, maxW = player.w,
        entrances = {}, ezt = player.z,
      }
      insert(Store().places, place)
    end
    local door = { c = player.c, n = (last.n + player.n) / 2, w = (last.w + player.w) / 2, z = player.z }
    local known = false
    for _, e in ipairs(place.entrances) do
      if Dist(e, door) < 25 then known = true break end
    end
    if not known and getn(place.entrances) < 6 then
      insert(place.entrances, door)
    end
    place.ezt = place.ezt or player.z
  end

  -- walking around inside: grow the known extent and height range
  if player.indoors and player.sub and player.sub ~= "" then
    local place = FindByName(player.zone, player.sub)
    if place then
      Grow(place, player)
    end
  end
end

-- notes you pin yourself ----------------------------------------------------

function P:AddNote(player, text)
  insert(Store().notes_list, { c = player.c, n = player.n, w = player.w, text = text })
end

-- remove the note nearest to the player (within 60 yards)
function P:RemoveNote(player)
  local notes = Store().notes_list
  local best, bestd
  for i, note in ipairs(notes) do
    if note.c == player.c then
      local d = Dist(note, player)
      if d < 60 and (not bestd or d < bestd) then
        best, bestd = i, d
      end
    end
  end
  if best then
    return table.remove(notes, best)
  end
  return nil
end
