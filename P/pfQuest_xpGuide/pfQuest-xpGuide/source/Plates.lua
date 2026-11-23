-- pfQuest xpGuide: a small marker left of the level on the nameplate of everyone your quests need:
--   a skull on enemies a quest log objective names ("Young Scavenger slain: 3/8") or the current step says to kill,
--   a sack on enemies that drop an item a quest still needs (from pfQuest's data, when it is installed),
--   "!" on whoever gives the current step's quest, "?" on whoever takes it back.
-- When the quest is part of a chain marked in the step list, that chain's shape sits behind the marker in the chain's
-- colour, and the marker keeps a thin dark border to stand out from it. The bars are the game's own nameplates, so they
-- only show while those are on (V for enemies, Shift-V for friendly NPCs). With pfUI the markers are smooth line icons
-- in the theme's accent; without it the skull is the game's gold raid skull and the others the same smooth icons in gold.

local ER = pfQuest_xpGuide
local ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"

local plates, count = {}, 0   -- nameplates found so far, and how many children of the world frame were looked at
local wanted = {}             -- singular names of the enemies wanted now
local current = {}            -- those the guide's current step names (brighter marker)

-- A nameplate: a nameless button on the world frame with a health bar in it. (Not by its border picture: some
-- clients and nameplate addons change that.)
local function IsPlate(frame)
  if not frame or not frame.GetObjectType or frame:GetObjectType() ~= "Button" then return false end
  if frame.GetName and frame:GetName() then return false end
  local bar = frame.GetChildren and frame:GetChildren()
  return bar and bar.GetObjectType and bar:GetObjectType() == "StatusBar" and true or false
end

-- The enemy's name on a plate: the first text on it that is not the level.
local function PlateName(plate)
  local regions = { plate:GetRegions() }
  for _, r in ipairs(regions) do
    if r.GetObjectType and r:GetObjectType() == "FontString" then
      local text = r:GetText()
      if text and text ~= "" and not string.find(text, "^[%d%?%+ ]+$") then return text, r end
    end
  end
  return nil
end

-- The enemy's level on a plate: pfUI's own level text when pfUI draws the plate, else the game's (the text that is
-- only a number, "??" or "12+").
local function PlateLevel(plate)
  local np = plate.nameplate
  if np and np.level and np.level.GetObjectType and np.level:GetObjectType() == "FontString" then return np.level end
  for _, r in ipairs({ plate:GetRegions() }) do
    if r.GetObjectType and r:GetObjectType() == "FontString" then
      local text = r:GetText()
      if text and text ~= "" and string.find(text, "^[%d%?%+ ]+$") then return r end
    end
  end
  return nil
end

-- What each name is wanted for: { title = quest title or true, kind = "kill", "collect", "pickup" or "handin" }.
local RANK = { collect = 1, kill = 2, pickup = 3, handin = 4 }
local function Want(out, name, title, kind)
  if not name or name == "" then return end
  local key = ER.Steps.Singular(name)
  local old = out[key]
  if old and RANK[old.kind] > RANK[kind] then return end
  if old and old.kind == kind and type(old.title) == "string" and type(title) ~= "string" then return end
  out[key] = { title = title, kind = kind }
end

-- The enemies the quest log still needs: kill objectives by name, item objectives through what drops them.
local function FromQuestLog(out)
  local Steps = ER.Steps
  local known = ER.Recorder and ER.Recorder.Known and ER.Recorder.Known() or {}
  local n = GetNumQuestLogEntries() or 0
  for i = 1, n do
    local title, _, _, header, _, complete = GetQuestLogTitle(i)
    if title and not header and not complete then
      local objectives = GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(i) or 0
      for j = 1, objectives do
        local text, kind, finished = GetQuestLogLeaderBoard(j, i)
        if text and not finished then
          local _, _, thing = string.find(text, "^(.-):%s*%d+%s*/%s*%d+")
          thing = thing or text
          if kind == "monster" then
            local _, _, mob = string.find(thing, "^(.-) slain$")
            Want(out, mob or thing, title, "kill")
          elseif kind == "item" then
            local info = known[title]
            local facts = info and info.pfid and ER.QuestFacts and ER.QuestFacts(info.pfid)
            local o = facts and facts.objectives[string.lower(thing)]
            for _, src in ipairs(o and (o.allSources or o.sources) or {}) do
              if src.db == "units" then Want(out, src.name, title, "collect") end
            end
          end
        end
      end
    end
  end
end

-- Who takes a quest back: pfQuest's data, else the casual route's quest list.
local takers
local function Taker(id)
  local facts = ER.QuestFacts and ER.QuestFacts(id)
  if facts and facts.taker and facts.taker.name then return facts.taker.name end
  if not takers then
    takers = {}
    for _, guides in pairs(type(pfQuest_xpGuide_Quests) == "table" and pfQuest_xpGuide_Quests or {}) do
      for _, g in ipairs(guides) do
        for _, q in ipairs(g.quests or {}) do if q.id and q.taker then takers[q.id] = q.taker end end
      end
    end
  end
  return takers[id]
end

-- The current step's (and the side steps') people: who gives a quest still to pick up, who takes back one in your log.
local function People(out, now)
  local Steps = ER.Steps
  local list = {}
  local cur = Steps.Current()
  if cur then table.insert(list, cur) end
  for _, st in ipairs((Steps.Side and Steps.Side()) or {}) do table.insert(list, st) end
  for _, step in ipairs(list) do
    for _, e in ipairs(step.elements or {}) do
      local id = tonumber(e.id)
      if id and id > 0 and (e.kind == "A" or e.kind == "T") and not (Steps.ElementDone and Steps.ElementDone(step, e)) then
        local title = Steps.QuestTitle(id) or true
        local who, kind
        if e.kind == "A" then
          local row = ER.QuestRow and ER.QuestRow(id)
          who, kind = row and row.g, "pickup"
        elseif Steps.InLog(id) then
          who, kind = Taker(id), "handin"
        end
        if who then
          Want(out, who, title, kind)
          now[Steps.Singular(who)] = true
        end
      end
    end
  end
end

local function Rebuild()
  local out, now = {}, {}
  FromQuestLog(out)
  if ER.Steps.Running() then
    -- the current step's enemies: its quest (for the chain colour) is the step's first quest in a marked chain
    local cur = ER.Steps.Current()
    local title = true
    if cur and ER.Steps.StepQuests then
      for _, id in ipairs((ER.Steps.StepQuests(cur))) do
        if ER.ChainColourForQuest and ER.ChainColourForQuest(id) then title = ER.Steps.QuestTitle(id) or true break end
      end
    end
    for name in pairs(ER.Steps.TargetNames()) do
      local old = out[name]
      if not old then out[name] = { title = title, kind = "kill" }
      elseif old.title == true then old.title = title end
      now[name] = true
    end
    People(out, now)
  end
  wanted, current = out, now
end

-- Is this enemy wanted? By its whole name, or by its first name when the guide only uses that ("Kill Meven" for
-- Meven Korgal).
local function Wanted(text, set)
  set = set or wanted
  if not text then return false end
  if set[ER.Steps.Singular(text)] then return true end
  local _, _, first = string.find(text, "^(%S+) ")
  return first and set[first] and true or false
end

-- The quest an enemy is for (its title), when known.
local function QuestFor(text)
  if not text then return nil end
  local v = wanted[ER.Steps.Singular(text)]
  if not v then
    local _, _, first = string.find(text, "^(%S+) ")
    v = first and wanted[first]
  end
  return v and type(v.title) == "string" and v.title or nil
end

-- What it is wanted for ("kill", "collect", "pickup", "handin").
local function KindFor(text)
  if not text then return nil end
  local v = wanted[ER.Steps.Singular(text)]
  if not v then
    local _, _, first = string.find(text, "^(%S+) ")
    v = first and wanted[first]
  end
  return v and v.kind or "kill"
end

-- Its chain's colour and shape in the step list (the same as the step's mark), else nil.
local function ColourFor(text)
  local q = ER.ChainColourForTitle and QuestFor(text)
  return q and ER.ChainColourForTitle(q)
end
local function ShapeFor(text)
  local q = ER.ChainShapeForTitle and QuestFor(text)
  return q and ER.ChainShapeForTitle(q)
end

-- The marker's look, by theme: "pfui" (a small smooth skull, as the guide window's footer icons) or "skull" (the game's
-- raid skull). Either takes the colour of its quest's chain mark in the step list; gold / the accent otherwise.
local function Themed() return ER.Skin and ER.Skin.On and ER.Skin.On() end

local MEDIA = "Interface\\AddOns\\pfQuest-xpGuide\\Media\\"

-- The marker sits left of the enemy's level. When its quest is in a marked chain, the chain's shape (filled, in the
-- chain's colour, the same shape as the step's mark in the list) sits behind it, about the marker's size; the marker
-- keeps a thin dark border so it stands out from the shape. Without a level text on the plate it goes over the name.
local SKULL = 16       -- the marker
local SKULL_ON = 13    -- the marker on a shape, so the shape shows round it
local SHAPE = 20       -- the shape behind it
local GAP = 3          -- between the shape's right edge and the level
local function Frame(plate)
  local f = CreateFrame("Frame", nil, plate)
  f:SetWidth(SKULL)
  f:SetHeight(SKULL)
  f:SetFrameLevel((plate.GetFrameLevel and plate:GetFrameLevel() or 0) + 5)
  local ring = f:CreateTexture(nil, "BACKGROUND")
  ring:SetWidth(SHAPE)
  ring:SetHeight(SHAPE)
  ring:Hide()
  return f, ring
end

-- The pictures: our own smooth icons (Media), each with a dark outline of the same shape; the game's raid skull for
-- kills without pfUI's look.
local ICONS = { kill = "IconSkull", collect = "IconBag", pickup = "IconBang", handin = "IconQuery" }

local function SetPicture(m, what)
  if m.what == what then return end
  m.what = what
  local t, edge, f = m.tex, m.edge, m.frame
  edge:ClearAllPoints()
  if m.kind == "skull" and what == "kill" then
    t:SetTexture(ICON)
    t:SetTexCoord(0.75, 1, 0.25, 0.5)
    edge:SetTexture(ICON)
    edge:SetTexCoord(0.75, 1, 0.25, 0.5)
    -- the thin border: the same skull in black, a pixel bigger all round, behind it
    edge:SetPoint("TOPLEFT", f, "TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
  else
    local name = ICONS[what] or ICONS.kill
    t:SetTexture(MEDIA .. name)
    t:SetTexCoord(0, 1, 0, 1)
    edge:SetTexture(MEDIA .. name .. "Edge")
    edge:SetTexCoord(0, 1, 0, 1)
    edge:SetAllPoints(f)
  end
end

-- kind: "pfui" (smooth icons in the accent) or "skull" (gold, the raid skull for kills).
local function Make(plate, kind)
  local f, ring = Frame(plate)
  local edge = f:CreateTexture(nil, "BORDER")
  edge:SetVertexColor(0, 0, 0, 0.9)
  local t = f:CreateTexture(nil, "ARTWORK")
  t:SetAllPoints(f)
  local base = kind == "pfui" and { 0.2, 1, 0.8 } or { 1, 0.82, 0.25 }
  local m = { kind = kind, frame = f, ring = ring, tex = t, skull = t, edge = edge, parts = { t } }
  local colour = nil
  m.Tint = function(c) colour = c end
  m.Bright = function(on)
    local c = colour or base
    if kind == "pfui" then
      t:SetVertexColor(c[1], c[2], c[3], on and 1 or 0.55)
    else
      t:SetVertexColor(c[1], c[2], c[3])
      t:SetAlpha(on and 1 or 0.7)
    end
    edge:SetAlpha(on and 0.9 or 0.6)
  end
  m.Show = function() f:Show() end
  m.Hide = function() f:Hide() end
  SetPicture(m, "kill")
  m.Bright(true)
  return m
end

-- Where the marker goes: the place of the shape (shown or not) is fixed, GAP pixels left of the level, and the marker is
-- centred on it, so neither ever runs over the level; with no level text, over the name.
local function Place(m, level, name)
  local at = level or name
  if m.at == at then return end
  m.at = at
  m.ring:ClearAllPoints()
  if level then
    m.ring:SetPoint("RIGHT", level, "LEFT", -GAP, 0)
  elseif name then
    m.ring:SetPoint("BOTTOM", name, "TOP", 0, 3)
  end
  m.frame:ClearAllPoints()
  m.frame:SetPoint("CENTER", m.ring, "CENTER", 0, 0)
end

-- The shape behind the marker: filled, in a darker shade of the chain's colour so the marker (the chain's colour, with
-- its thin dark border) reads on it, and the marker a little smaller so the shape shows round it. None (and the marker
-- at full size) when the quest is in no marked chain.
local function Enclose(m, shape, colour, on)
  if not shape then
    m.ring:Hide()
    m.frame:SetWidth(SKULL)
    m.frame:SetHeight(SKULL)
    return
  end
  m.frame:SetWidth(SKULL_ON)
  m.frame:SetHeight(SKULL_ON)
  m.ring:SetTexture(MEDIA .. "Chain" .. shape)
  local c = colour or { 1, 0.82, 0.25 }
  m.ring:SetVertexColor(c[1] * 0.75, c[2] * 0.75, c[3] * 0.75, on and 0.95 or 0.65)
  m.ring:Show()
end

-- lightblade's pfQuest-turtle ("pfQuest [TurtleWoW DB]") puts its own kill and loot icons on nameplates (a sword and a bag,
-- "Show Quest Icons on Nameplates" in pfQuest's settings, on by default; it registers /pfqnp). While those are on, ours leave
-- kill and loot to it, so a mob does not get two markers; the ! and ? (who gives the step's quest, who takes it back) stay ours.
local function OtherKillLootIcons()
  if not SLASH_PFQUESTNP1 then return false end
  return not (pfQuest_config and pfQuest_config["nameplatesEnabled"] == "0")
end
ER.OtherPlateIcons = OtherKillLootIcons

-- Its icon sits by the plate's left edge (its "Icon X/Y Position", -20 and -8 by default), away from the level, where ours stands
-- right beside it; with ours left out that looks like a gap. While its position is the default one, its icon is moved to our
-- place: left of the level, or left of our own ! or ? when the plate has one. A position set in pfQuest's settings is left alone.
-- It sets its icon's place only when it hands the icon to a plate or its settings window closes, so this is checked on every pass.
local function TheirIcon(plate)
  local kids = { plate:GetChildren() }
  for i = 1, table.getn(kids) do
    local k = kids[i]
    local ic = type(k) == "table" and rawget(k, "Icon")
    local tex = type(ic) == "table" and type(ic.GetTexture) == "function" and ic:GetTexture()
    if type(tex) == "string" and string.find(tex, "pfQuest%-turtle") and (string.find(tex, "slay$") or string.find(tex, "loot$")) then
      return k
    end
  end
end

local function DefaultPlace()
  local c = pfQuest_config or {}
  local x, y = tonumber(c["nameplateX"]), tonumber(c["nameplateY"])
  return (x == nil or x == -20 or x == -25) and (y == nil or y == -8 or y == -5)
end

local function MoveTheirIcon(plate, ours)
  if not (SLASH_PFQUESTNP1 and plate.GetChildren) then return end
  local icon = TheirIcon(plate)
  if not icon or not DefaultPlace() then return end
  local level = PlateLevel(plate)
  local _, name = PlateName(plate)
  local to, point, rel, x, y
  if ours then
    to, point, rel, x, y = ours.ring, "RIGHT", "LEFT", -1, 0
  elseif level then
    to, point, rel, x, y = level, "RIGHT", "LEFT", -GAP, 0
  elseif name then
    to, point, rel, x, y = name, "BOTTOM", "TOP", 0, 3
  else
    return
  end
  local p, at = icon:GetPoint(1)
  if p == point and at == to then return end
  icon:ClearAllPoints()
  icon:SetPoint(point, to, rel, x, y)
end
ER.MoveTheirPlateIcon = MoveTheirIcon

-- The addon's own markers (nameplate !, ?, skull and sack; its marker on the map): off by default since 2.1.0, pfQuest's and
-- pfQuest-turtle's show instead. Settings -> Helpers, or /xpg skulls, turns them on.
function ER.OwnMarkers()
  return ER.db and ER.db.ownMarkers == true or false
end

local function Mark(plate)
  local text, name = PlateName(plate)
  local want = Wanted(text) and ER.OwnMarkers()
  if want and OtherKillLootIcons() then
    local k = KindFor(text)
    if k == "kill" or k == "collect" then want = false end
  end
  if want then
    local kind = Themed() and "pfui" or "skull"
    if plate.xpGuideSkull and plate.xpGuideSkull.kind ~= kind then
      plate.xpGuideSkull:Hide()
      plate.xpGuideMarks = plate.xpGuideMarks or {}
      plate.xpGuideMarks[plate.xpGuideSkull.kind] = plate.xpGuideSkull
      plate.xpGuideSkull = plate.xpGuideMarks[kind]
    end
    if not plate.xpGuideSkull then
      plate.xpGuideSkull = Make(plate, kind)
    end
    local m = plate.xpGuideSkull
    SetPicture(m, KindFor(text))
    local level = PlateLevel(plate)
    Place(m, level, name)
    -- the colour of its quest's chain (as the step's mark in the list), else the usual; the current step's enemies stand
    -- out, the rest of the quest log's are softer
    local colour = ColourFor(text)
    local on = Wanted(text, current) or not next(current)
    m.Tint(colour)
    m.Bright(on)
    Enclose(m, ShapeFor(text), colour, on)
    m:Show()
    MoveTheirIcon(plate, m)
  else
    if plate.xpGuideSkull then plate.xpGuideSkull:Hide() end
    MoveTheirIcon(plate, nil)
  end
end

local scan = CreateFrame("Frame", "pfQuest_xpGuidePlates")
scan.wait, scan.since = 0, 10
scan:SetScript("OnUpdate", function()
  this.wait = this.wait + arg1
  if this.wait < 0.2 then return end
  this.since = this.since + this.wait
  this.wait = 0
  if not (ER.Steps and WorldFrame and WorldFrame.GetNumChildren) then return end
  local total = WorldFrame:GetNumChildren()
  if total > count then
    local kids = { WorldFrame:GetChildren() }
    for i = count + 1, total do
      if IsPlate(kids[i]) then table.insert(plates, kids[i]) end
    end
    count = total
  end
  if table.getn(plates) == 0 then return end
  if this.since >= 1 then
    this.since = 0
    Rebuild()
  end
  for _, plate in ipairs(plates) do
    if plate:IsVisible() then Mark(plate) end
  end
end)

-- /xpg skulls test: what the skulls see, for a screenshot when they do not show.
function ER.SkullTest()
  Rebuild()
  local names = {}
  for name in pairs(wanted) do table.insert(names, name) end
  table.sort(names)
  local shown = {}
  for _, plate in ipairs(plates) do
    if plate:IsVisible() then
      local n = PlateName(plate)
      table.insert(shown, (n or "?") .. (Wanted(n) and (Wanted(n, current) and " (marked, this step)" or " (marked)") or ""))
    end
  end
  ER.Print("skulls are " .. (ER.OwnMarkers() and "on" or "OFF (pfQuest's markers)") .. (Themed() and " (pfUI style)" or "") .. ". Enemies wanted: " ..
    (table.getn(names) > 0 and table.concat(names, ", ") or "none") .. ".")
  ER.Print("Health bars on screen (" .. table.getn(shown) .. "): " .. (table.getn(shown) > 0 and table.concat(shown, ", ") or
    "none found. Press V to show enemy health bars."))
end

-- /xpg skulls: on or off.
function ER.ToggleSkulls()
  if not ER.db then return end
  ER.db.ownMarkers = not ER.OwnMarkers()
  ER.Print("xpGuide's own markers " .. (ER.db.ownMarkers and "on: on nameplates (V shows enemy nameplates, Shift-V friendly ones) and on the map."
    or "off: pfQuest's markers show (and pfQuest-turtle's on nameplates)."))
end

ER.Loaded("Plates.lua")
