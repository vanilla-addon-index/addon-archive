-- pfQuest xpGuide: the arrow. A small arrow near the top of the screen turns to point at the next place in the guide,
-- with what is there and how many yards away, like RestedXP's. It needs no other addon: the picture is our own
-- (Media\Arrow.tga, 64 turns drawn by tools/make-arrow.js) and the zone sizes come from Data\ZoneSizes.lua.
-- With pfQuest installed the same place is also marked on the world map and the minimap.
--
-- Which way you face comes from the game (GetPlayerFacing, on clients that have it) or from the minimap's player
-- arrow, the way pfQuest finds it. Drag the arrow to move it; right-click hides it (/xpg arrow brings it back).

local ER = pfQuest_xpGuide
local ARRIVED = 6   -- yards: closer than this counts as there

-- The arrow picture, a sheet of turns: pfQuest's 3D arrow (from TomTom) when pfQuest is installed, read from its own
-- folder (108 turns, 9 across, cells of 56 by 42 on a 512 sheet), else our own flat one (64 turns, 8 by 8). Both
-- are drawn anticlockwise from straight ahead, so the same cell number works for either.
local OWN = { texture = "Interface\\AddOns\\pfQuest_xpGuide\\Media\\Arrow", turns = 64, perRow = 8, w = 1 / 8, h = 1 / 8, width = 52, height = 52 }
local sheet
local function Sheet()
  if sheet then return sheet end
  if pfQuestConfig and type(pfQuestConfig.path) == "string" then
    sheet = { texture = pfQuestConfig.path .. "\\img\\arrow", turns = 108, perRow = 9, w = 56 / 512, h = 42 / 512, width = 64, height = 48 }
  else
    sheet = OWN
  end
  return sheet
end

local frame, pointer, titleText, distText
local facingModel
local lastMark
local pin   -- a quest picked in the simple list: the arrow points there until you get there or unpick it

local function SameText(a, b)
  return a and b and string.lower(a) == string.lower(b)
end

-- Which way the character faces, in radians anticlockwise from north. nil when the game will not say.
-- pfQuest's own reading comes first: its arrow turns on Turtle WoW, ours stayed still with the search below.
local function Facing()
  if GetPlayerFacing then return GetPlayerFacing() end
  if pfQuestCompat and pfQuestCompat.GetPlayerFacing then
    local ok, facing = pcall(pfQuestCompat.GetPlayerFacing)
    if ok and type(facing) == "number" then return facing end
  end
  if not facingModel and Minimap then
    -- The player arrow on the minimap, found the way pfQuest finds it (only that exact model, nothing similar).
    local kids = { Minimap:GetChildren() }
    for _, v in ipairs(kids) do
      if v.IsObjectType and v:IsObjectType("Model") and not v:GetName() and v.GetModel then
        local model = v:GetModel()
        if type(model) == "string" and string.find(string.lower(model), "interface\\minimap\\minimaparrow", 1, true) then
          facingModel = v
          break
        end
      end
    end
  end
  return facingModel and facingModel:GetFacing() or nil
end

local function Short(text)
  if not text then return "" end
  text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
  text = string.gsub(text, "|r", "")
  if string.len(text) > 60 then text = string.sub(text, 1, 57) .. "..." end
  return text
end

-- pfQuest's own arrow, when it can take our places: the world-space arrow of the brues-code pfQuest fork
-- (github.com/brues-code/pfQuest), which points at any node an addon adds with arrow = true and puts first the
-- one route.SetTarget names. Then only one arrow is on screen: ours stays hidden and pfQuest's points the way.
-- Not used when pfQuest's arrow is switched off (/db arrow), or when you untick it in the settings: then ours shows.
function ER.PfArrowAvailable()
  return pfQuest and pfQuest.route and type(pfQuest.route.worldcoords) == "table" and pfQuest.route.SetTarget
    and pfQuest.route.IsTarget and pfQuest.route.arrow and pfMap and pfMap.AddNode and pfMap.DeleteNode
    and pfMap.GetMapIDByName and pfMap.GetNodes and true or false
end

function ER.UsePfArrow()
  if ER.db and ER.db.pfArrowOff then return false end
  if not ER.PfArrowAvailable() then return false end
  if pfQuest_config and pfQuest_config["arrow"] == "0" then return false end
  return true
end

-- pfQuest SmartArrow (an add-on to pfQuest's arrow): when it is installed and on, it plans the way to our place, along real
-- zone exits, your flight paths, boats and zeppelins, walked roads and around obstacles and hostile camps, and draws that into
-- pfQuest's arrow. We hand it the place as a waypoint through its public pfQuestSmartArrow:SetWaypoint, on every pfQuest
-- build it runs on (brues-code or lightblade, with or without ClassicAPI). The waypoint is marked as a guide instruction,
-- as SmartArrow treats nodes that guide addons hand it: the step's words are shown as they are, and it is not let go with an
-- "Arrived" line, because the guide moves on by itself. A waypoint you set yourself (/smartarrow way) is never replaced.
function ER.SmartArrowAvailable()
  local sa = pfQuestSmartArrow
  return (sa and sa.ready and sa.SetWaypoint and pfQuestSmartArrow_config) and true or false
end

function ER.UseSmartArrow()
  if ER.db and ER.db.pfArrowOff then return false end
  if not ER.SmartArrowAvailable() then return false end
  if pfQuestSmartArrow_config.enabled ~= "1" then return false end   -- /smartarrow off: pfQuest's straight arrow again
  if pfQuest_config and pfQuest_config["arrow"] == "0" then return false end
  return true
end

-- How the arrow is steered now: "smart" (SmartArrow routes pfQuest's arrow), "pf" (pfQuest's arrow, straight), or nil (ours).
function ER.ArrowMode()
  if ER.UseSmartArrow() then return "smart" end
  if ER.UsePfArrow() then return "pf" end
  return nil
end

local ourNode   -- our node as pfMap keeps it, while it is pfQuest's arrow target
local ourWaypoint   -- our waypoint as SmartArrow keeps it
local waiting       -- a waypoint of yours is shown; ours goes in when it is cleared

-- Gives the arrow back to pfQuest's own objectives, but only when the target is still ours (a node you clicked stays).
local function ReleasePfTarget()
  if ourNode and pfQuest and pfQuest.route and pfQuest.route.IsTarget and pfQuest.route.IsTarget(ourNode) then
    pcall(pfQuest.route.SetTarget, nil)
  end
  ourNode = nil
end

-- The same for SmartArrow: only our own waypoint is cleared.
local function ReleaseSmartWaypoint()
  local sa = pfQuestSmartArrow
  if ourWaypoint and sa and sa.waypoint == ourWaypoint and sa.SetWaypoint then pcall(sa.SetWaypoint, sa, nil) end
  ourWaypoint = nil
  waiting = nil
end

-- A pfQuest node you clicked: pfQuest's arrow target, and not ours. SmartArrow would put any waypoint before it, so while
-- one is chosen ours steps aside, as with pfQuest's arrow alone.
local function ClickedNode()
  local route = pfQuest and pfQuest.route
  if not (route and route.IsTarget) then return false end
  local list = route.worldcoords or route.coords
  if type(list) ~= "table" then return false end
  local limit = table.getn(list)
  if limit > 250 then limit = 250 end
  for i = 1, limit do
    local node = list[i] and list[i][3]
    if node and node.addon ~= "PFQUEST_XPGUIDE" then
      local ok, yes = pcall(route.IsTarget, node)
      if ok and yes then return true end
    end
  end
  return false
end

-- Someone else's choice is shown: a SmartArrow waypoint you set (/smartarrow way), or a pfQuest node you clicked. It wins
-- until it is cleared; then ours goes back in.
local function ForeignWaypoint()
  local sa = pfQuestSmartArrow
  if sa and sa.waypoint and sa.waypoint ~= ourWaypoint then return true end
  return ClickedNode()
end

local function SmartWaypoint(mapId, t, label)
  local sa = pfQuestSmartArrow
  if not (mapId and sa and sa.SetWaypoint) then return false end
  if ForeignWaypoint() then waiting = true return true end   -- yours is shown; ours waits
  waiting = nil
  local ok, placed = pcall(sa.SetWaypoint, sa, mapId, t.x, t.y, label)
  if not ok or not placed or not sa.waypoint then return false end
  local wp = sa.waypoint
  wp.manual = nil   -- not a pin of yours: no "Arrived" line, no clearing; the guide moves on by itself
  wp.node = { arrow = true, title = label, description = t.zone }
  ourWaypoint = wp
  return true
end

-- Puts the place on pfQuest's world map and minimap (quietly, no chat line), once per new place, wording or arrow. With
-- SmartArrow the place is its waypoint; with pfQuest's arrow alone the node is an arrow candidate and becomes its target.
-- Says whether the arrow is now steered for us (false: our own arrow shows).
local steered = false
local function MarkMap(t, mode)
  local key = t and (t.zone .. "|" .. t.x .. "|" .. t.y .. "|" .. (t.text or "") .. "|" .. (mode or "own")) or nil
  if key == lastMark then
    -- you clicked a pfQuest node while ours is SmartArrow's waypoint: ours lets go, so yours is what the arrow follows
    if mode == "smart" and ourWaypoint and pfQuestSmartArrow.waypoint == ourWaypoint and ClickedNode() then
      local sa = pfQuestSmartArrow
      pcall(sa.SetWaypoint, sa, nil)
      ourWaypoint = nil
      waiting = true
      return steered
    end
    -- yours was cleared (or ours was): ours goes back in
    local gone = mode == "smart" and t and steered and not ForeignWaypoint()
      and (waiting or (ourWaypoint and pfQuestSmartArrow.waypoint ~= ourWaypoint))
    if gone then
      lastMark = nil
    else
      return steered
    end
  end
  lastMark = key
  steered = false
  if not (pfMap and pfMap.AddNode and pfMap.GetMapIDByName and pfMap.DeleteNode) then return false end
  ReleasePfTarget()
  if mode ~= "smart" then ReleaseSmartWaypoint() end
  pcall(function()
    pfMap:DeleteNode("PFQUEST_XPGUIDE")
    local label, mapId
    if t then
      mapId = pfMap:GetMapIDByName(t.zone)
      if mapId then
        label = Short(t.text)
        if label == "" then label = t.zone end
        pfMap:AddNode({ addon = "PFQUEST_XPGUIDE", zone = mapId, x = t.x, y = t.y, title = label, spawn = label,
          spawntype = "Guide", level = "", respawn = "N/A",
          description = t.zone, arrow = (mode == "pf") and true or nil })
      end
    end
    if pfMap.queue_update == true then pfMap.queue_update = GetTime() end
    -- UpdateNodes rebuilds the arrow's candidates and stamps each node's layer, which SetTarget compares.
    if pfMap.UpdateNodes then pfMap:UpdateNodes() end
    if mode == "smart" then
      if label then steered = SmartWaypoint(mapId, t, label) end
      if not steered then ReleaseSmartWaypoint() end
    elseif mode == "pf" and label then
      local nodes = pfMap:GetNodes("PFQUEST_XPGUIDE", label)
      if nodes and nodes[1] then
        ourNode = nodes[1]
        pfQuest.route.SetTarget(ourNode)
        if pfQuest.route.arrow and pfQuest_config and pfQuest_config["arrow"] ~= "0" then pfQuest.route.arrow:Show() end
        steered = true
      end
    end
  end)
  if not t then ReleaseSmartWaypoint() end
  return steered
end

-- The place to point at is worked out twice a second (or when the step changes); turning the arrow is every frame.
local target, targetAt

-- Turns the pointer toward a place that is dx yards east and dy yards south of you, and colours it (hidden when the game will not say
-- which way you face).
local function Point(dx, dy)
  local facing = Facing()
  if not facing then
    pointer:Hide()
    return
  end
  -- Bearing to the place, anticlockwise from north (x grows east, y grows south on the map).
  local bearing = math.atan2(-dx, -dy)
  local rel = bearing - facing
  local s = Sheet()
  local cell = math.mod(math.floor(rel / (2 * math.pi) * s.turns + 0.5), s.turns)
  if cell < 0 then cell = cell + s.turns end
  local col, row = math.mod(cell, s.perRow), math.floor(cell / s.perRow)
  pointer:SetTexCoord(col * s.w, (col + 1) * s.w, row * s.h, (row + 1) * s.h)
  -- Green when you face it, through yellow, to red when it is behind you.
  local off = math.abs(math.mod(rel + 3 * math.pi, 2 * math.pi) - math.pi) / math.pi
  pointer:SetVertexColor(math.min(1, off * 2), math.min(1, (1 - off) * 2), 0.1)
  pointer:Show()
end

local function Update(fresh)
  if not frame then return end
  local Steps = ER.Steps
  if not (Steps and Steps.Running()) or (ER.db and ER.db.arrowOff) then
    frame:Hide()
    MarkMap(nil)
    return
  end
  local now = GetTime()
  if fresh or not targetAt or now < targetAt or now - targetAt > 0.5 then
    target, targetAt = Steps.Target(), now
  end
  local t = pin or target
  if not t then
    frame:Hide()
    MarkMap(nil)
    return
  end
  -- SmartArrow or pfQuest's arrow points the way: ours stays hidden, but the rest below still runs (a pinned place is let go
  -- on arrival). When neither could take the place (SmartArrow cannot place that zone, say), ours shows.
  local mode = ER.ArrowMode()
  if MarkMap(t, mode) then frame:Hide() else frame:Show() end
  titleText:SetText(Short(t.text) ~= "" and Short(t.text) or (t.zone .. " (" .. math.floor(t.x + 0.5) .. ", " .. math.floor(t.y + 0.5) .. ")"))
  local here, px, py = Steps.Here()
  if not SameText(here, t.zone) or (px == 0 and py == 0) then
    -- Another zone: say where to head; on the same continent the pointer also turns toward it (from the zone edges in Data\ZoneSizes.lua).
    distText:SetText("|cffffd100Go to " .. t.zone .. "|r")
    local east, south
    if here and px and py and not (px == 0 and py == 0) and Steps.CrossYards then
      local _
      _, east, south = Steps.CrossYards(here, px, py, t.zone, t.x, t.y)
    end
    if east then Point(east, south) else pointer:Hide() end
    return
  end
  local yards, dx, dy = Steps.Yards(t.zone, px, py, t.x, t.y)
  if yards <= math.max(ARRIVED, (t.radius or 0) * 0.5) then
    pointer:Hide()
    distText:SetText("|cff40c040You are here|r")
    if t == pin then
      pin = nil
      if ER.PinChanged then ER.PinChanged() end
    end
    return
  end
  distText:SetText(math.floor(yards + 0.5) .. " yards")
  Point(dx, dy)
end

local function Build()
  frame = CreateFrame("Button", "pfQuest_xpGuideArrow", UIParent)
  frame:SetWidth(220)
  frame:SetHeight(96)
  local pos = ER.db and ER.db.arrowPos
  if type(pos) == "table" and pos.point then
    frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
  else
    frame:SetPoint("TOP", UIParent, "TOP", 0, -110)
  end
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:RegisterForClicks("RightButtonUp")
  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local point, _, relPoint, x, y = this:GetPoint()
    if ER.db then ER.db.arrowPos = { point = point, relPoint = relPoint, x = x, y = y } end
  end)
  frame:SetScript("OnClick", function()
    if ER.db then ER.db.arrowOff = true end
    this:Hide()
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99xpGuide:|r arrow hidden. |cffffd100/xpg arrow|r brings it back.")
    end
  end)
  frame:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Guide arrow")
    GameTooltip:AddLine("Points at the next place in your guide.", 1, 1, 1, 1)
    GameTooltip:AddLine("Drag to move. Right-click to hide (/xpg arrow brings it back).", 0.6, 0.6, 0.6, 1)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local s = Sheet()
  pointer = frame:CreateTexture(nil, "ARTWORK")
  pointer:SetTexture(s.texture)
  pointer:SetWidth(s.width)
  pointer:SetHeight(s.height)
  pointer:SetPoint("TOP", frame, "TOP", 0, 0)
  pointer:SetTexCoord(0, s.w, 0, s.h)

  titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  titleText:SetPoint("TOP", pointer, "BOTTOM", 0, -2)
  titleText:SetWidth(220)
  distText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  distText:SetPoint("TOP", titleText, "BOTTOM", 0, -2)
  if ER.ApplyFont then
    ER.ApplyFont(titleText, 0)
    ER.ApplyFont(distText, -2)
  end
  frame:Hide()
  if ER.Skin and ER.Skin.On() then ER.Skin.Register(frame) end

  -- A hidden frame never gets OnUpdate, so a separate always-shown frame turns the arrow.
  local driver = CreateFrame("Frame", "pfQuest_xpGuideArrowDriver")
  driver.wait = 0
  driver:SetScript("OnUpdate", function()
    this.wait = this.wait + arg1
    if this.wait < 0.05 then return end
    this.wait = 0
    Update()
  end)
end

-- Points the arrow at a place of your own choosing ({ zone, x, y, text }), or back at the guide (nil).
function ER.PinArrow(place)
  pin = place
  if ER.db and place then ER.db.arrowOff = nil end
  if not frame then Build() end
  Update(true)
  if ER.PinChanged then ER.PinChanged() end
end

function ER.ArrowPin() return pin end

-- Points the arrow now (the guide calls this when the step changes). Builds it the first time.
function ER.ArrowUpdate()
  if not frame then Build() end
  Update(true)
end

-- /xpg arrow: show it again (or hide it).
function ER.ToggleArrow()
  if not ER.db then return end
  ER.db.arrowOff = not ER.db.arrowOff
  if not frame then Build() end
  Update()
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99xpGuide:|r arrow " .. (ER.db.arrowOff and "hidden" or "shown") .. ".")
  end
  if ER.GuideFooterChanged then ER.GuideFooterChanged() end
end

-- The arrow button under the guide window: "pfquest" (pfQuest's arrow points the way, routed by SmartArrow when it is on),
-- "own" (pfQuest xpGuide's arrow) or "off" (no arrow). pfQuest's is offered only when pfQuest has an arrow we can steer and it is on.
function ER.PfQuestArrowCan()
  if pfQuest_config and pfQuest_config["arrow"] == "0" then return false end
  if ER.SmartArrowAvailable() and pfQuestSmartArrow_config.enabled == "1" then return true end
  return ER.PfArrowAvailable()
end

function ER.ArrowChoice()
  if ER.db and ER.db.arrowOff then return "off" end
  if ER.PfQuestArrowCan() and not (ER.db and ER.db.pfArrowOff) then return "pfquest" end
  return "own"
end

function ER.CycleArrow()
  if not ER.db then return end
  local now = ER.ArrowChoice()
  local nxt
  if now == "pfquest" then nxt = "own" elseif now == "own" then nxt = "off" else nxt = ER.PfQuestArrowCan() and "pfquest" or "own" end
  ER.db.arrowOff = (nxt == "off") or nil
  if nxt == "pfquest" then ER.db.pfArrowOff = nil elseif nxt == "own" then ER.db.pfArrowOff = true end
  if not frame then Build() end
  lastMark = nil   -- mark the place again, for the arrow now in use
  Update(true)
  local words = { pfquest = "pfQuest's arrow" .. (ER.UseSmartArrow() and ", routed by SmartArrow" or ""), own = "the guide's own arrow", off = "no arrow" }
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99xpGuide:|r " .. words[nxt] .. ".") end
  if ER.GuideFooterChanged then ER.GuideFooterChanged() end
  return nxt
end

-- /xpg pfarrow: let pfQuest's arrow point the way (the default when it can), or use our own.
function ER.TogglePfArrow()
  if not ER.db then return end
  ER.db.pfArrowOff = not ER.db.pfArrowOff
  if not frame then Build() end
  lastMark = nil   -- mark the place again, with or without pfQuest's arrow
  Update(true)
  if DEFAULT_CHAT_FRAME then
    local msg
    if ER.db.pfArrowOff then
      msg = "using the pfQuest xpGuide arrow."
    elseif ER.UseSmartArrow() then
      msg = "pfQuest's arrow points the way now, routed by pfQuest SmartArrow."
    elseif ER.SmartArrowAvailable() and pfQuestSmartArrow_config.enabled ~= "1" and ER.UsePfArrow() then
      msg = "pfQuest's arrow points the way now, in a straight line (|cffffd100/smartarrow on|r routes it)."
    elseif ER.UsePfArrow() then
      msg = "pfQuest's arrow points the way now."
    elseif ER.PfArrowAvailable() then
      msg = "pfQuest's arrow is switched off (|cffffd100/db arrow|r), so the pfQuest xpGuide arrow stays."
    else
      msg = "this pfQuest has no arrow pfQuest xpGuide can use (it needs github.com/brues-code/pfQuest), so the pfQuest xpGuide arrow stays."
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99xpGuide:|r " .. msg)
  end
  if ER.GuideFooterChanged then ER.GuideFooterChanged() end
end

local starter = CreateFrame("Frame", "pfQuest_xpGuideArrowStarter")
starter:RegisterEvent("PLAYER_LOGIN")
starter:SetScript("OnEvent", function()
  if not frame then Build() end
end)

ER.Loaded("Arrow.lua")
