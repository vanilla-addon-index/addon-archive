-- Relationships PVP

RelationshipsPVPCharDB = RelationshipsPVPCharDB or {}

local BG_KEYS    = { "AV", "WSG", "AB" }
local ARENA_KEYS = { "A2", "A3", "A5", "SK" }
local ALL_KEYS   = { "AV", "WSG", "AB", "A2", "A3", "A5", "SK" }

local BG_NAMES = {
  AV  = "Alterac Valley",
  WSG = "Warsong Gulch",
  AB  = "Arathi Basin",
  A2  = "2v2 Rated",
  A3  = "3v3 Rated",
  A5  = "5v5 Rated",
  SK  = "Skirmish",
}

local BG_COLORS = {
  AV  = { r = 0.6, g = 0.85, b = 1.0 },
  WSG = { r = 0.6, g = 1.0,  b = 0.6 },
  AB  = { r = 1.0, g = 0.85, b = 0.4 },
  A2  = { r = 1.0, g = 0.6,  b = 0.9 },
  A3  = { r = 1.0, g = 0.5,  b = 0.6 },
  A5  = { r = 0.9, g = 0.5,  b = 1.0 },
  SK  = { r = 0.8, g = 0.8,  b = 0.8 },
}

-- Arena bracket meta: teamSize + isRated (registeredMatch)
local ARENA_META = {
  A2 = { size = 2, rated = 1 },
  A3 = { size = 3, rated = 1 },
  A5 = { size = 5, rated = 1 },
  SK = { size = 2, rated = 0 }, -- default skirmish to 2v2 unrated
}

-- TurtleWoW / OctoWoW arena finder ids for JoinArenaQueue(id).
-- Skirmish must be 0; passing the team size opens the Blood Ring panel
-- without completing the queue.
local ARENA_IDS = {
  SK = 0,
  A2 = 1,
  A3 = 2,
  A5 = 3,
}

local MARKS_WIN  = 3
local MARKS_LOSS = 1

local currentBG = nil
local endReported = {}

-- Track the last arena bracket the user queued for, so we can classify
-- the resulting match even on clients that don't report teamSize.
local lastQueuedArena = nil

-- Runtime UI (row FontStrings created dynamically)
local rowStrings = {}
local totalRow   = nil

---------------------------------------------------------------
-- Utility
---------------------------------------------------------------
local function NewStatBlock()
  return {
    wins = 0, draws = 0, losses = 0,
    kills = 0, deaths = 0, hk = 0,
    marks = 0, honor = 0, spend = 0,
    bestKB = 0, streak = 0, bestStreak = 0,
  }
end

-- Read the player's current spendable honor from the honor UI ("H" panel).
-- Turtle / OctoWoW (1.18.1+) credits honor immediately as a currency; the
-- value shown at the top of the honor panel is the this-week honor total
-- returned by GetPVPThisWeekStats(). Fall back to session/lifetime stats
-- and finally GetHonorCurrency() for other clients.
local function GetSpendableHonor()
  if type(GetPVPThisWeekStats) == "function" then
    local hk, honor = GetPVPThisWeekStats()
    if honor then return honor end
  end
  if type(GetPVPSessionStats) == "function" then
    local hk, honor = GetPVPSessionStats()
    if honor then return honor end
  end
  if type(GetHonorCurrency) == "function" then
    return GetHonorCurrency() or 0
  end
  return nil
end

local function EnsureDB()
  local db = RelationshipsPVPCharDB
  db.stats = db.stats or {}
  db.icon  = db.icon  or { point = "CENTER", x = 60, y = -60 }
  if db.showIcon == nil then db.showIcon = true end
  -- Snapshot of spendable honor captured on BG entry:
  --   { key = <BG_KEY>, value = <spendable honor when we entered> }
  -- Persisted so a disconnect/relog mid-BG still resolves to a correct delta.
  db.honorSnap = db.honorSnap or nil
  -- Enemy kill tracking (BGs only)
  db.killedByAll        = db.killedByAll        or {}
  db.lastMatchKilledBy  = db.lastMatchKilledBy  or {}
  db.lastMatchKey       = db.lastMatchKey       or nil
  db.currentMatch       = db.currentMatch       or nil
  for i = 1, table.getn(ALL_KEYS) do
    local k = ALL_KEYS[i]
    local s = db.stats[k] or NewStatBlock()
    if s.honor      == nil then s.honor      = 0 end
    if s.spend      == nil then s.spend      = 0 end
    if s.bestKB     == nil then s.bestKB     = 0 end
    if s.streak     == nil then s.streak     = 0 end
    if s.bestStreak == nil then s.bestStreak = 0 end
    if s.hk         == nil then s.hk         = 0 end
    if s.marks      == nil then s.marks      = 0 end
    if s.draws      == nil then s.draws      = 0 end
    db.stats[k] = s
  end
  return db
end

-- Capture the pre-match spendable-honor value on BG entry.
local function CaptureSpendableHonor(key)
  if not key then return end
  local db = EnsureDB()
  if db.honorSnap and db.honorSnap.key == key then return end
  local v = GetSpendableHonor()
  if v == nil then return end
  db.honorSnap = { key = key, value = v, credited = 0 }
end

-- Add any new delta between the current spendable-honor value and the
-- snapshot into the BG's spend total. Idempotent: tracks how much has
-- already been credited so RecordEnd + the on-leave transition together
-- never double-count. `clear` = true removes the snapshot afterwards.
local function FinalizeSpendableHonor(key, clear)
  if not key then return end
  local db = RelationshipsPVPCharDB
  if not db or not db.honorSnap or db.honorSnap.key ~= key then return end
  local now = GetSpendableHonor()
  if now == nil then
    if clear then db.honorSnap = nil end
    return
  end
  local base  = db.honorSnap.value or 0
  local prior = db.honorSnap.credited or 0
  local delta = (now - base) - prior
  if delta < 0 then delta = 0 end
  if delta > 0 then
    local s = db.stats and db.stats[key]
    if s then s.spend = (s.spend or 0) + delta end
    db.honorSnap.credited = prior + delta
  end
  if clear then db.honorSnap = nil end
end

-- Handle a currentBG transition: capture on enter, finalize on leave.
local FinalizeMatchKillers
local function OnCurrentBGChanged(prevKey, newKey)
  if newKey and newKey ~= prevKey then
    if prevKey then FinalizeSpendableHonor(prevKey, true) end
    CaptureSpendableHonor(newKey)
  elseif prevKey and not newKey then
    FinalizeSpendableHonor(prevKey, true)
    FinalizeMatchKillers()
  end
  if newKey and newKey ~= prevKey then
    -- Starting a fresh BG: clear any stale currentMatch that didn't belong to this key.
    local db = RelationshipsPVPCharDB
    if db and db.currentMatch and db.currentMatch.key ~= newKey then
      FinalizeMatchKillers()
    end
  end
end

---------------------------------------------------------------
-- Enemy kill tracking (who kills you the most)
---------------------------------------------------------------
local lastAttackerName = nil
local lastAttackerTime = 0
local ATTACKER_WINDOW  = 15  -- seconds a hostile hit counts as "the killer"

-- Pull an attacker name out of a hostile combat log message. Handles:
--   "Name hits you for X."                       (melee)
--   "Name crits you for X."                      (melee crit)
--   "Name's Spell hits you for X Fire damage."   (direct spell)
--   "You suffer X Shadow damage from Name's Curse of Agony." (periodic)
local function ExtractAttackerName(msg)
  if not msg then return nil end
  local n = string.gfind and nil  -- unused; keep 1.12-safe
  local from = string.find(msg, "from ")
  if from then
    local rest = string.sub(msg, from + 5)
    local nm = string.gsub(rest, "'s.*$", "")
    nm = string.gsub(nm, "%..*$", "")
    nm = string.gsub(nm, "%s.*$", "")
    if nm and nm ~= "" then return nm end
  end
  -- Fall back to the first token (attacker name, possibly with "'s")
  local first = msg
  local space = string.find(first, " ")
  if space then first = string.sub(first, 1, space - 1) end
  first = string.gsub(first, "'s$", "")
  if first == "" then return nil end
  -- Ignore garbage tokens that clearly aren't a player name.
  if string.find(first, "^[%l]") then return nil end
  if first == "You" or first == "you" then return nil end
  return first
end

local function NoteHostileHit(msg)
  if not currentBG then return end
  local name = ExtractAttackerName(msg)
  if not name then return end
  lastAttackerName = name
  lastAttackerTime = GetTime()
end

-- Called on PLAYER_DEAD while in a BG: credit the most recent hostile hit
-- as the killer. Only tracked for real battlegrounds (AV/WSG/AB), not arenas.
local function RegisterDeath()
  if not currentBG then return end
  if currentBG ~= "AV" and currentBG ~= "WSG" and currentBG ~= "AB" then return end
  if not lastAttackerName then return end
  if (GetTime() - lastAttackerTime) > ATTACKER_WINDOW then return end
  local db = EnsureDB()
  if not db.currentMatch or db.currentMatch.key ~= currentBG then
    db.currentMatch = { key = currentBG, killedBy = {} }
    -- Fresh match: reset the "last match" tally so the Nemesis line
    -- starts from zero and updates live as deaths accumulate.
    db.lastMatchKilledBy = {}
    db.lastMatchKey      = currentBG
  end
  local n = lastAttackerName
  db.currentMatch.killedBy[n] = (db.currentMatch.killedBy[n] or 0) + 1
  -- Live update: promote this death straight into the "last match" and
  -- all-time KOS tables so the UI reflects it immediately, instead of
  -- waiting until FinalizeMatchKillers() runs at match end.
  db.lastMatchKilledBy[n] = (db.lastMatchKilledBy[n] or 0) + 1
  db.killedByAll[n]       = (db.killedByAll[n]       or 0) + 1
end

-- Called when we transition out of a BG: promote currentMatch tallies to
-- "last match" and roll them into the all-time KOS table.
function FinalizeMatchKillers()
  local db = RelationshipsPVPCharDB
  if not db or not db.currentMatch then return end
  -- Deaths are now folded into lastMatchKilledBy / killedByAll live in
  -- RegisterDeath(), so there's nothing to promote here -- just clear
  -- the in-progress match marker.
  db.currentMatch = nil
end

local function TopKiller(tbl)
  if not tbl then return nil, 0 end
  local best, count = nil, 0
  for name, c in pairs(tbl) do
    if c > count then best, count = name, c end
  end
  return best, count
end

-- Clamp a UIParent-relative CENTER offset so the button stays visible on screen.
function RelationshipsPVP_ClampScreenOffset(x, y)
  x = x or 0
  y = y or 0
  if not UIParent or not UIParent.GetWidth then return x, y end
  local w = UIParent:GetWidth()  or 1024
  local h = UIParent:GetHeight() or 768
  local pad = -60
  local maxX = (w / 2) - pad
  local maxY = (h / 2) - pad
  if x >  maxX then x =  maxX end
  if x < -maxX then x = -maxX end
  if y >  maxY then y =  maxY end
  if y < -maxY then y = -maxY end
  return x, y
end

-- Position the icon anywhere on screen (parented to UIParent for free drag).
function RelationshipsPVP_SetIconPosition(x, y, save)
  local btn = RelationshipsPVPMinimapButton
  if not btn or not UIParent then return end
  x, y = RelationshipsPVP_ClampScreenOffset(x, y)
  btn:ClearAllPoints()
  btn:SetParent(UIParent)
  btn:SetPoint("CENTER", UIParent, "CENTER", x, y)
  if btn.SetFrameStrata then btn:SetFrameStrata("MEDIUM") end
  if btn.SetFrameLevel then btn:SetFrameLevel(10) end
  if save then
    local db = EnsureDB()
    db.icon.point    = "CENTER"
    db.icon.relPoint = "CENTER"
    db.icon.parent   = "UIParent"
    db.icon.x        = x
    db.icon.y        = y
  end
end

-- Read the button's current center in UIParent coordinates and persist it.
function RelationshipsPVP_SaveIconPos()
  local db = EnsureDB()
  local btn = RelationshipsPVPMinimapButton
  if not btn or not UIParent then return end
  local x = db.icon.x or 0
  local y = db.icon.y or 0
  if btn.GetCenter and UIParent.GetCenter then
    local bx, by = btn:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if bx and by and ux and uy then
      x = bx - ux
      y = by - uy
    end
  end
  x, y = RelationshipsPVP_ClampScreenOffset(x, y)
  db.icon.point    = "CENTER"
  db.icon.relPoint = "CENTER"
  db.icon.parent   = "UIParent"
  db.icon.x        = x
  db.icon.y        = y
end

-- Free drag: reparent to UIParent and let the client move the frame.
function RelationshipsPVP_StartIconDrag()
  local btn = RelationshipsPVPMinimapButton
  if not btn then return end
  btn:SetParent(UIParent)
  if btn.SetFrameStrata then btn:SetFrameStrata("MEDIUM") end
  if btn.SetFrameLevel then btn:SetFrameLevel(10) end
  if btn.StartMoving then btn:StartMoving() end
end

function RelationshipsPVP_StopIconDrag()
  local btn = RelationshipsPVPMinimapButton
  if not btn then return end
  if btn.StopMovingOrSizing then btn:StopMovingOrSizing() end
  RelationshipsPVP_SaveIconPos()
  local db = EnsureDB()
  -- Re-anchor cleanly to a single CENTER/CENTER offset so the saved value is
  -- exactly what we restore on next login.
  RelationshipsPVP_SetIconPosition(db.icon.x, db.icon.y, 1)
end

local function ApplyIconVisibility()
  local db = EnsureDB()
  local btn = RelationshipsPVPMinimapButton
  if not btn then return end
  if db.showIcon then btn:Show() else btn:Hide() end
end

-- Loading screens / entering BGs can briefly hide parent frames; re-assert
-- our intended visibility so the icon never "randomly disappears".
local iconWatcher
local function InstallIconWatcher()
  if iconWatcher then return end
  iconWatcher = CreateFrame("Frame")
  iconWatcher.elapsed = 0
  iconWatcher:SetScript("OnUpdate", function()
    iconWatcher.elapsed = (iconWatcher.elapsed or 0) + arg1
    if iconWatcher.elapsed < 1.0 then return end
    iconWatcher.elapsed = 0
    local db = RelationshipsPVPCharDB
    if not db then return end
    local btn = RelationshipsPVPMinimapButton
    if not btn then return end
    if db.showIcon then
      if not btn:IsShown() then btn:Show() end
    else
      if btn:IsShown() then btn:Hide() end
    end
  end)
end

local function RestoreIconPos()
  local db = EnsureDB()
  local btn = RelationshipsPVPMinimapButton
  if not btn then return end

  -- Migrate any prior Minimap-relative save into a UIParent-relative offset
  -- so free-drag mode has a valid starting position.
  if db.icon.parent == "Minimap" and Minimap and Minimap.GetCenter and UIParent and UIParent.GetCenter then
    local mx, my = Minimap:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if mx and my and ux and uy then
      db.icon.x = (mx - ux) + (db.icon.x or 0)
      db.icon.y = (my - uy) + (db.icon.y or 0)
    end
    db.icon.parent   = "UIParent"
    db.icon.point    = "CENTER"
    db.icon.relPoint = "CENTER"
  end

  RelationshipsPVP_SetIconPosition(db.icon.x or 0, db.icon.y or 0, 1)
  ApplyIconVisibility()
  InstallIconWatcher()
end

local function SavePanelPos()
  local db = EnsureDB()
  db.panel = db.panel or {}
  if not RelationshipsPVPFrame then return end
  local point, _, _, x, y = RelationshipsPVPFrame:GetPoint()
  db.panel.point = point or "CENTER"
  db.panel.x = x or 0
  db.panel.y = y or 0
end

local function RestorePanelPos()
  local db = EnsureDB()
  if not RelationshipsPVPFrame or not db.panel or not db.panel.point then return end
  RelationshipsPVPFrame:ClearAllPoints()
  RelationshipsPVPFrame:SetPoint(db.panel.point, UIParent, db.panel.point, db.panel.x, db.panel.y)
end

local function Print(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffRelationships PVP:|r " .. msg)
  end
end

local function MapNameToKey(name)
  if not name then return nil end
  if name == BG_NAMES.AV  then return "AV"  end
  if name == BG_NAMES.WSG then return "WSG" end
  if name == BG_NAMES.AB  then return "AB"  end
  return nil
end

local function FormatNumber(n)
  n = n or 0
  if n >= 1000000 then
    return string.format("%.1fm", n / 1000000)
  elseif n >= 10000 then
    return string.format("%.1fk", n / 1000)
  end
  return tostring(n)
end

---------------------------------------------------------------
-- BG / Arena detection
---------------------------------------------------------------
local function ClassifyBattlefield(i)
  local status, mapName, instanceID, minLevel, maxLevel, teamSize, registered = GetBattlefieldStatus(i)
  if status ~= "active" then return nil end

  local bgKey = MapNameToKey(mapName)
  if bgKey then return bgKey end

  if teamSize and teamSize > 0 then
    if registered == 1 or registered == true then
      if teamSize == 2 then return "A2" end
      if teamSize == 3 then return "A3" end
      if teamSize == 5 then return "A5" end
    else
      return "SK"
    end
  end

  if lastQueuedArena then return lastQueuedArena end
  return nil
end

local function DetectCurrentBG()
  for i = 1, 3 do
    local status = GetBattlefieldStatus(i)
    if status == "active" then
      local key = ClassifyBattlefield(i)
      if key then return key, i end
    end
  end
  return nil, nil
end

local function RecordEnd(key, index)
  if not key or endReported[index] then return end
  endReported[index] = true

  local db = EnsureDB()
  local s = db.stats[key]
  if not s then return end

  local playerWon = false
  local isDraw = false
  local winner = GetBattlefieldWinner()
  if winner then
    local myFaction = UnitFactionGroup("player")
    -- Some server builds (incl. Turtle/Octo) report a draw as a winner
    -- value that is neither 0 (Horde) nor 1 (Alliance). Treat anything
    -- else as a draw so it isn't miscounted as a loss.
    isDraw = (winner ~= 0 and winner ~= 1)
    if isDraw then
      s.draws  = s.draws + 1
      s.streak = 0
    else
      local wonAsAlliance = (winner == 1 and myFaction == "Alliance")
      local wonAsHorde    = (winner == 0 and myFaction == "Horde")
      playerWon = wonAsAlliance or wonAsHorde
      if playerWon then
        s.wins   = s.wins + 1
        s.streak = s.streak + 1
        if s.streak > s.bestStreak then s.bestStreak = s.streak end
      else
        s.losses = s.losses + 1
        s.streak = 0
      end
    end
    local isBG = (key == "AV" or key == "WSG" or key == "AB")
    if isBG then
      -- Draws award the loss-tier mark count.
      s.marks = s.marks + (playerWon and MARKS_WIN or MARKS_LOSS)
    end
  end

  -- Roll up any spendable honor gained so far this match. Snapshot is
  -- kept until the currentBG->nil transition so late-credit ticks
  -- (e.g. end-of-match bonus) still count.
  FinalizeSpendableHonor(key, false)

  RequestBattlefieldScoreData()
  local me = UnitName("player")
  local rows = GetNumBattlefieldScores() or 0
  for r = 1, rows do
    local name, killingBlows, honorableKills, deaths, honorGained = GetBattlefieldScore(r)
    if name == me then
      local kb  = killingBlows or 0
      local hk  = honorableKills or 0
      local dth = deaths or 0
      local hon = honorGained or 0
      s.kills  = s.kills  + kb
      s.hk     = s.hk     + hk
      s.deaths = s.deaths + dth
      s.honor  = s.honor  + hon
      if kb > s.bestKB then s.bestKB = kb end
      break
    end
  end

  local marksMsg = ""
  if key == "AV" or key == "WSG" or key == "AB" then
    marksMsg = " +" .. (playerWon and MARKS_WIN or MARKS_LOSS) .. " marks"
  end
  local outcomeStr
  if isDraw then
    outcomeStr = "|cffffff66draw|r"
  elseif playerWon then
    outcomeStr = "|cff66ff66win|r"
  else
    outcomeStr = "|cffff6666loss|r"
  end
  Print(BG_NAMES[key] .. " recorded (" .. outcomeStr .. marksMsg .. ").")
end

---------------------------------------------------------------
-- Queue actions
---------------------------------------------------------------
-- Auto-close the Blizzard PvP panels if they pop up as a side effect
-- of the arena / BG queueing calls.
-- NOTE: We deliberately do NOT call HideUIPanel() here. HideUIPanel on a
-- frame that Blizzard's UI panel system has slotted into a left/center
-- slot triggers a slot reflow, which is what caused Character / Friends /
-- Spellbook panels to jump to the middle of the screen after the PvP
-- panel was opened. Directly calling :Hide() bypasses the slot manager
-- entirely; the slot suppression below (SuppressUIPanelWindows) ensures
-- Blizzard never registered a slot for these frames to begin with.
local function HidePvPPanels()
  if BattlefieldFrame       and BattlefieldFrame:IsVisible()       then BattlefieldFrame:Hide()       end
  if PVPBattlegroundFrame   and PVPBattlegroundFrame:IsVisible()   then PVPBattlegroundFrame:Hide()   end
  if PVPFrame               and PVPFrame:IsVisible()               then PVPFrame:Hide()               end
  if HonorFrame             and HonorFrame:IsVisible()             then HonorFrame:Hide()             end
end

-- Suppress the PvP panel entirely while we are auto-queueing. Reference-counted
-- so nested queues (Queue All BGs) do not release too early.
--
-- IMPORTANT: We previously hijacked BattlefieldFrame.Show / PVPBattlegroundFrame.Show
-- to no-op during suppression. That was the source of the "Character / Friends
-- panels jump to the middle of the screen" bug: Blizzard's ShowUIPanel() first
-- allocates a UI panel slot (left / center / doublewide) via UIPanelWindows,
-- THEN calls frame:Show(). Silently dropping :Show() left the slot reserved by
-- an invisible frame, so the next panel the user opened (Character, Friends,
-- Spellbook, ...) got shoved into a different slot -> centered.
--
-- The correct approach on 1.12 is to temporarily remove these frames from
-- UIPanelWindows while suppressing, so ShowUIPanel treats them as plain
-- frames and never allocates a slot. When suppression ends, the original
-- UIPanelWindows entries are restored so normal Blizzard UI behaviour is
-- preserved for the rest of the session.
local suppressPanels = 0
local savedUIPanelEntries = nil

local SUPPRESSED_PANEL_NAMES = {
  "BattlefieldFrame",
  "PVPBattlegroundFrame",
  "PVPFrame",
  "HonorFrame",
}

local function SuppressUIPanelWindows()
  if savedUIPanelEntries then return end
  savedUIPanelEntries = {}
  if type(UIPanelWindows) ~= "table" then return end
  for i = 1, table.getn(SUPPRESSED_PANEL_NAMES) do
    local name = SUPPRESSED_PANEL_NAMES[i]
    savedUIPanelEntries[name] = UIPanelWindows[name]
    UIPanelWindows[name] = nil
  end
end

local function RestoreUIPanelWindows()
  if not savedUIPanelEntries then return end
  if type(UIPanelWindows) == "table" then
    for i = 1, table.getn(SUPPRESSED_PANEL_NAMES) do
      local name = SUPPRESSED_PANEL_NAMES[i]
      UIPanelWindows[name] = savedUIPanelEntries[name]
    end
  end
  savedUIPanelEntries = nil
end

local function BeginSuppress()
  suppressPanels = suppressPanels + 1
  SuppressUIPanelWindows()
  HidePvPPanels()
end

local function EndSuppress()
  suppressPanels = suppressPanels - 1
  if suppressPanels < 0 then suppressPanels = 0 end
  HidePvPPanels()
  if suppressPanels == 0 then
    RestoreUIPanelWindows()
  end
end

-- Central pending-queue state. `pendingQueue` is a FIFO of items:
--   { kind = "bg"|"arena", key = <BG_KEY>, asGroup = 0/1 }
-- The finder frame processes them one at a time on BATTLEFIELDS_SHOW.
local pendingQueue = {}
local finderFrame

-- Kick the client into opening the finder for the requested queue type.
-- The BATTLEFIELDS_SHOW handler below immediately completes the queue and
-- hides the Blizzard/Blood Ring panel.
local function KickFinderFor(job)
  if job.kind == "arena" then
    if type(JoinArenaQueue) == "function" then
      local id = ARENA_IDS[job.key]
      if id == nil then id = 0 end
      JoinArenaQueue(id)
      return true
    end
    if type(JoinBattlegroundQueue) == "function" then
      JoinBattlegroundQueue(BG_NAMES[job.key])
      return true
    end
    return false
  end

  if type(JoinBattlegroundQueue) == "function" then
    JoinBattlegroundQueue(BG_NAMES[job.key])
    return true
  end
  return false
end

local function GetFinderFrame()
  if finderFrame then return finderFrame end
  finderFrame = CreateFrame("Frame")
  finderFrame:SetScript("OnEvent", function()
    if event ~= "BATTLEFIELDS_SHOW" then return end

    local job = pendingQueue[1]
    if not job then
      HidePvPPanels()
      EndSuppress()
      return
    end
    table.remove(pendingQueue, 1)

    if SetSelectedBattlefield then SetSelectedBattlefield(0) end

    if job.kind == "arena" then
      local meta = ARENA_META[job.key] or ARENA_META.SK
      lastQueuedArena = job.key
      -- Prefer explicit arena team-size setters where available.
      if type(SetArenaTeamSize) == "function" then SetArenaTeamSize(meta.size) end
      if JoinBattlefield then
        -- Turtle/Octo: JoinArenaQueue(id) opens Blood Ring, then
        -- JoinBattlefield(0[, asGroup]) actually joins First Available.
        if job.asGroup == 1 then JoinBattlefield(0, 1) else JoinBattlefield(0) end
      end
    else
      if JoinBattlefield then
        if job.asGroup == 1 then JoinBattlefield(0, 1) else JoinBattlefield(0) end
      end
    end

    HidePvPPanels()
    EndSuppress()

    -- Chain: if more queued, kick the next one after a very short delay.
    if pendingQueue[1] then
      local nxt = pendingQueue[1]
      BeginSuppress()
      finderFrame:RegisterEvent("BATTLEFIELDS_SHOW")
      if not KickFinderFor(nxt) then
        table.remove(pendingQueue, 1)
        finderFrame:UnregisterEvent("BATTLEFIELDS_SHOW")
        EndSuppress()
      end
    else
      finderFrame:UnregisterEvent("BATTLEFIELDS_SHOW")
    end
  end)
  return finderFrame
end

local function IsInGroup()
  if RelationshipsPVPGroupCheck and RelationshipsPVPGroupCheck:GetChecked() then return 1 end
  return 0
end

local function EnqueueAndKick(job)
  local f = GetFinderFrame()
  -- If another job is already in flight, just append; the handler will chain.
  if pendingQueue[1] then
    table.insert(pendingQueue, job)
    return true
  end
  table.insert(pendingQueue, job)
  BeginSuppress()
  f:UnregisterAllEvents()
  f:RegisterEvent("BATTLEFIELDS_SHOW")
  if not KickFinderFor(job) then
    pendingQueue = {}
    f:UnregisterEvent("BATTLEFIELDS_SHOW")
    EndSuppress()
    return false
  end
  return true
end

function RelationshipsPVP_Queue(key)
  if not BG_NAMES[key] then return end
  local asGroup = IsInGroup()

  if EnqueueAndKick({ kind = "bg", key = key, asGroup = asGroup }) then
    Print("Queued: |cffffd200" .. BG_NAMES[key] .. "|r"
      .. (asGroup == 1 and " |cff66ff66(group)|r" or ""))
    return
  end

  -- Fallback: legacy vanilla flow (visit a Battlemaster first).
  if not JoinBattlefield then
    Print("|cffff4444Battleground Finder not available on this client.|r")
    return
  end
  local idx
  if key == "AV"  then idx = 1
  elseif key == "WSG" then idx = 2
  elseif key == "AB"  then idx = 3 end
  JoinBattlefield(idx, asGroup)
  Print("Requested queue: |cffffd200" .. BG_NAMES[key] .. "|r")
end

---------------------------------------------------------------
-- Arena queue: fully automated, no manual panel confirmation
---------------------------------------------------------------
-- Turtle/Octo Blood Ring panel: JoinArenaQueue(id) opens a custom
-- frame (typically BloodRingFrame). It does NOT fire BATTLEFIELDS_SHOW
-- and JoinBattlefield does not apply, so we simulate a click on the
-- panel's own Join button.

-- Text labels the Blood Ring / arena finder Join button may carry.
local ARENA_JOIN_TEXTS = {
  ["join battle"]  = 1, ["join queue"]   = 1, ["join"]         = 1,
  ["enter queue"]  = 1, ["enter battle"] = 1, ["queue"]        = 1,
  ["enter"]        = 1, ["join arena"]   = 1, ["queue up"]     = 1,
}

local function _btnText(btn)
  if not btn then return nil end
  if btn.GetText then
    local t = btn:GetText()
    if t and t ~= "" then return t end
  end
  local name = btn.GetName and btn:GetName()
  if name then
    local fs = getglobal(name.."Text")
    if fs and fs.GetText then return fs:GetText() end
  end
  return nil
end

local function _looksLikeJoin(btn)
  if not btn or type(btn.GetObjectType) ~= "function" then return false end
  if btn:GetObjectType() ~= "Button" then return false end
  if btn.IsVisible and not btn:IsVisible() then return false end
  if btn.IsEnabled and btn:IsEnabled() == 0 then return false end
  local t = _btnText(btn)
  if not t then return false end
  return ARENA_JOIN_TEXTS[string.lower(t)] == 1
end

-- Locate the Blood Ring frame by likely names or a visible frame carrying
-- a Join-style child button.
local function FindArenaFinderFrame()
  local names = {
    "BloodRingFrame", "BloodringFrame", "BloodRingArenaFrame",
    "ArenaFinderFrame", "ArenaQueueFrame", "SkirmishFrame",
    "CustomArenaFrame", "PVPArenaFrame",
  }
  for i = 1, table.getn(names) do
    local f = getglobal(names[i])
    if f and f.IsVisible and f:IsVisible() then return f end
  end
  return nil
end

local function FindJoinButtonIn(frame)
  if not frame then return nil end
  -- Try predictable child names first.
  local name = frame.GetName and frame:GetName()
  if name then
    local suffixes = {
      "JoinButton", "JoinBattleButton", "QueueButton", "EnterButton",
      "Button1", "OKButton", "AcceptButton",
    }
    for i = 1, table.getn(suffixes) do
      local b = getglobal(name .. suffixes[i])
      if _looksLikeJoin(b) then return b end
    end
  end
  -- Walk direct children.
  if frame.GetChildren then
    local kids = { frame:GetChildren() }
    for i = 1, table.getn(kids) do
      if _looksLikeJoin(kids[i]) then return kids[i] end
    end
    -- One level deeper.
    for i = 1, table.getn(kids) do
      local k = kids[i]
      if k and k.GetChildren then
        local gkids = { k:GetChildren() }
        for j = 1, table.getn(gkids) do
          if _looksLikeJoin(gkids[j]) then return gkids[j] end
        end
      end
    end
  end
  return nil
end

-- Global sweep as a last resort: scan all frames for a visible Join-style
-- button attached to a visible top-level frame.
local function GlobalFindArenaJoinButton()
  local f = EnumerateFrames()
  while f do
    if f.IsVisible and f:IsVisible() and f.GetChildren then
      local kids = { f:GetChildren() }
      for i = 1, table.getn(kids) do
        if _looksLikeJoin(kids[i]) then return kids[i] end
      end
    end
    f = EnumerateFrames(f)
  end
  return nil
end

local arenaPoll
local arenaPollElapsed = 0
local arenaPollDeadline = 0

local function StopArenaPoll()
  if arenaPoll then arenaPoll:Hide() end
end

local function StartArenaPoll()
  if not arenaPoll then
    arenaPoll = CreateFrame("Frame")
    arenaPoll:Hide()
    arenaPoll:SetScript("OnUpdate", function()
      arenaPollElapsed = arenaPollElapsed + arg1
      if arenaPollElapsed < 0.05 then return end
      arenaPollElapsed = 0

      local frame = FindArenaFinderFrame()
      local btn   = FindJoinButtonIn(frame)
      if not btn then btn = GlobalFindArenaJoinButton() end
      if btn then
        -- Click the button as if the user pressed it.
        if btn.Click then btn:Click() end
        if frame and frame.Hide then frame:Hide() end
        HidePvPPanels()
        StopArenaPoll()
        return
      end

      if GetTime() > arenaPollDeadline then
        -- Give up quietly; leave the panel open so the user can click.
        StopArenaPoll()
      end
    end)
  end
  arenaPollElapsed = 0
  arenaPollDeadline = GetTime() + 3.0
  arenaPoll:Show()
end

function RelationshipsPVP_QueueArena(key)
  local meta = ARENA_META[key]
  if not meta then return end
  local asGroup = IsInGroup()
  lastQueuedArena = key

  -- 1) Direct TBC-style API — no panel involved.
  if type(JoinArena) == "function" then
    if type(SetArenaTeamSize) == "function" then SetArenaTeamSize(meta.size) end
    JoinArena(meta.size, meta.rated, asGroup)
    Print("Queued arena: |cffffd200" .. BG_NAMES[key] .. "|r"
      .. (asGroup == 1 and " |cff66ff66(group)|r" or ""))
    return
  end

  -- 2) Turtle/Octo custom entry point. JoinArenaQueue(id) opens the
  --    Blood Ring finder; we then click its Join button ourselves.
  if type(JoinArenaQueue) == "function" then
    local id = ARENA_IDS[key]; if id == nil then id = 0 end
    if type(SetArenaTeamSize) == "function" then SetArenaTeamSize(meta.size) end
    JoinArenaQueue(id)
    StartArenaPoll()
    Print("Queued arena: |cffffd200" .. BG_NAMES[key] .. "|r"
      .. (asGroup == 1 and " |cff66ff66(group)|r" or ""))
    return
  end

  Print("|cffff4444Arena API not available on this client. Visit an Arena Battlemaster.|r")
end

---------------------------------------------------------------
-- Queue for all standard battlegrounds (no arenas, no rated)
---------------------------------------------------------------
function RelationshipsPVP_QueueAllBGs()
  local asGroup = IsInGroup()
  local kicked = 0
  for i = 1, table.getn(BG_KEYS) do
    local key = BG_KEYS[i]
    if EnqueueAndKick({ kind = "bg", key = key, asGroup = asGroup }) then
      kicked = kicked + 1
    end
  end
  if kicked > 0 then
    Print("Queueing all standard battlegrounds ("
      .. kicked .. "): |cffffd200AV, WSG, AB|r"
      .. (asGroup == 1 and " |cff66ff66(group)|r" or ""))
  else
    Print("|cffff4444Battleground Finder not available on this client.|r")
  end
end

function RelationshipsPVP_LeaveAll()
  local left = 0
  for i = 1, 3 do
    local status = GetBattlefieldStatus(i)
    if status == "queued" or status == "confirm" then
      AcceptBattlefieldPort(i, 0)
      left = left + 1
    end
  end
  if left > 0 then
    Print("Left " .. left .. " pending queue(s).")
  else
    Print("No active queues.")
  end
  pendingQueue = {}
  lastQueuedArena = nil
end

---------------------------------------------------------------
-- Minimap icon toggle
---------------------------------------------------------------
function RelationshipsPVP_ToggleMinimapIcon()
  local db = EnsureDB()
  db.showIcon = not db.showIcon
  ApplyIconVisibility()
  Print(db.showIcon and "Minimap icon |cff66ff66shown|r." or "Minimap icon |cffff6666hidden|r. Use /rpvp to open.")
end

---------------------------------------------------------------
-- UI: build row FontStrings inside the stats panel
---------------------------------------------------------------
local COL_X = {  14, 158, 208, 258, 308, 358, 408, 458, 508, 558, 612, 668, 740 }
local COL_W = { 140,  46,  46,  46,  46,  46,  46,  46,  46,  50,  54,  70, 100 }
local COL_J = { "LEFT", "CENTER", "CENTER", "CENTER", "CENTER", "CENTER", "CENTER", "CENTER", "CENTER", "CENTER", "CENTER", "CENTER", "CENTER" }
local COL_NAMES = { "bg", "games", "win", "draw", "loss", "ratio", "kb", "hk", "dth", "kd", "mk", "bonus", "spend" }

local ROW_HEIGHT = 22
local ROW_TOP    = -34

local function MakeRow(panel, tag, yOff, striped)
  local row = {}
  if striped then
    local bg = panel:CreateTexture("RPVPRowBG"..tag, "BACKGROUND")
    bg:SetTexture(1, 1, 1, 0.04)
    bg:SetWidth(846); bg:SetHeight(ROW_HEIGHT - 2)
    bg:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, yOff + 2)
  end
  for c = 1, table.getn(COL_NAMES) do
    local fs = panel:CreateFontString(
      "RPVPRow"..tag.."_"..COL_NAMES[c],
      "ARTWORK",
      (c == 1) and "GameFontNormal" or "GameFontHighlight"
    )
    fs:SetWidth(COL_W[c]); fs:SetHeight(18)
    fs:SetJustifyH(COL_J[c])
    fs:SetPoint("TOPLEFT", panel, "TOPLEFT", COL_X[c], yOff)
    row[COL_NAMES[c]] = fs
  end
  return row
end

local function BuildStatsRows()
  if rowStrings["_built"] then return end
  local panel = RelationshipsPVPStatsPanel
  if not panel then return end

  for i = 1, table.getn(ALL_KEYS) do
    local key = ALL_KEYS[i]
    local yOff = ROW_TOP - (i - 1) * ROW_HEIGHT
    local row = MakeRow(panel, key, yOff, (math.mod(i, 2) == 0))
    local col = BG_COLORS[key]
    row.bg:SetText(BG_NAMES[key])
    row.bg:SetTextColor(col.r, col.g, col.b)
    rowStrings[key] = row
  end

  local n = table.getn(ALL_KEYS)
  local totalY = ROW_TOP - n * ROW_HEIGHT - 4
  local div = panel:CreateTexture("RPVPTotalDivider", "ARTWORK")
  div:SetTexture(1, 1, 1, 0.25)
  div:SetWidth(846); div:SetHeight(1)
  div:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, totalY + 2)

  totalRow = MakeRow(panel, "TOTAL", totalY - 6, false)
  totalRow.bg:SetText("Total")
  totalRow.bg:SetTextColor(1.0, 0.95, 0.7)

  rowStrings["_built"] = true
end

local function FormatQueueLine()
  local lines = ""
  local any = false
  for i = 1, 3 do
    local status, mapName, _, _, _, teamSize, registered = GetBattlefieldStatus(i)
    if status and status ~= "none" then
      any = true
      local color = "|cffffffff"
      if status == "queued"  then color = "|cffffff66" end
      if status == "confirm" then color = "|cff66ff66" end
      if status == "active"  then color = "|cff66ccff" end
      local label = mapName or "?"
      if teamSize and teamSize > 0 then
        label = label .. " (" .. teamSize .. "v" .. teamSize
          .. ((registered == 1 or registered == true) and " rated" or " skirmish") .. ")"
      end
      lines = lines .. "  [" .. i .. "] " .. label
        .. " - " .. color .. status .. "|r\n"
    end
  end
  if not any then return "  |cff888888(no active queues)|r\n" end
  return lines
end

local function FillRow(r, s)
  local draws = s.draws or 0
  local games = s.wins + draws + s.losses
  local pct = 0
  if games > 0 then pct = math.floor((s.wins / games) * 100 + 0.5) end
  local kd = "-"
  if s.deaths > 0 then
    kd = string.format("%.2f", (s.kills + s.hk) / s.deaths)
  elseif (s.kills + s.hk) > 0 then
    kd = "\226\136\158"
  end

  r.games:SetText(games)
  r.win:SetText(s.wins)
  r.draw:SetText(draws)
  r.loss:SetText(s.losses)
  r.ratio:SetText(pct .. "%")
  r.kb:SetText(s.kills)
  r.hk:SetText(s.hk)
  r.dth:SetText(s.deaths)
  r.kd:SetText(kd)
  r.mk:SetText(s.marks)
  -- Bonus honor is the honor gained from the battlefield scoreboard
  -- (GetBattlefieldScore -> honorGained). Tracked per-match, per-bracket.
  r.bonus:SetText(FormatNumber(s.honor or 0))
  r.bonus:SetTextColor(0.6, 0.85, 1.0)
  -- Spendable honor is measured as the delta of the honor UI ("H" panel)
  -- from BG entry -> BG exit. This is the honor actually credited to the
  -- character wallet for this BG, tracked per-player from the client.
  r.spend:SetText(FormatNumber(s.spend or 0))
  r.spend:SetTextColor(1.0, 0.82, 0.0)

  if games == 0 then
    r.ratio:SetTextColor(0.7, 0.7, 0.7)
  elseif pct >= 60 then
    r.ratio:SetTextColor(0.4, 1.0, 0.4)
  elseif pct >= 40 then
    r.ratio:SetTextColor(1.0, 0.9, 0.4)
  else
    r.ratio:SetTextColor(1.0, 0.5, 0.5)
  end
end

function RelationshipsPVP_Refresh()
  if not RelationshipsPVPFrame or not RelationshipsPVPFrame:IsVisible() then return end
  local db = EnsureDB()
  BuildStatsRows()

  local totals = NewStatBlock()
  for i = 1, table.getn(ALL_KEYS) do
    local k = ALL_KEYS[i]
    local s = db.stats[k]
    local r = rowStrings[k]
    if r then FillRow(r, s) end

    totals.wins   = totals.wins   + s.wins
    totals.draws  = totals.draws  + (s.draws or 0)
    totals.losses = totals.losses + s.losses
    totals.kills  = totals.kills  + s.kills
    totals.hk     = totals.hk     + s.hk
    totals.deaths = totals.deaths + s.deaths
    totals.honor  = totals.honor  + s.honor
    totals.spend  = (totals.spend or 0) + (s.spend or 0)
    totals.marks  = totals.marks  + s.marks
    if s.bestStreak > totals.bestStreak then totals.bestStreak = s.bestStreak end
    if s.bestKB     > totals.bestKB     then totals.bestKB     = s.bestKB     end
  end

  if totalRow then FillRow(totalRow, totals) end

  if RelationshipsPVPExtrasText then
    RelationshipsPVPExtrasText:SetText(
      "|cffffd200Best win streak:|r " .. totals.bestStreak
      .. "    |cffffd200Best KBs (single match):|r " .. totals.bestKB
      .. "    |cffffd200Total bonus honor:|r |cffffd100" .. FormatNumber(totals.honor or 0) .. "|r"
      .. "    |cffffd200Total spendable honor:|r |cffffd100" .. FormatNumber(totals.spend or 0) .. "|r"
    )
  end

  if RelationshipsPVPNemesisText then
    local nm = TopKiller(db.lastMatchKilledBy)
    if nm then
      RelationshipsPVPNemesisText:SetText(
        "|cffff9966Last BG Nemesis:|r |cffffffff" .. nm .. "|r"
      )
    else
      RelationshipsPVPNemesisText:SetText("|cffff9966Last BG Nemesis:|r |cff888888none yet|r")
    end
  end

  if RelationshipsPVPKOSText then
    local nm = TopKiller(db.killedByAll)
    if nm then
      RelationshipsPVPKOSText:SetText(
        "|cffff3333KOS:|r |cffffffff" .. nm .. "|r"
      )
    else
      RelationshipsPVPKOSText:SetText("|cffff3333KOS:|r |cff888888none yet|r")
    end
  end

  local qtext = FormatQueueLine()
  if currentBG then
    qtext = qtext .. "\n  |cff66ff66Currently inside: " .. BG_NAMES[currentBG] .. "|r"
  end
  if RelationshipsPVPQueueText then
    RelationshipsPVPQueueText:SetText(qtext)
  end
end

---------------------------------------------------------------
-- Reset panel + minimap button to the centre of the screen
---------------------------------------------------------------
function RelationshipsPVP_ResetPositions()
  local db = EnsureDB()

  if RelationshipsPVPFrame then
    RelationshipsPVPFrame:ClearAllPoints()
    RelationshipsPVPFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    RelationshipsPVPFrame:Show()
  end

  if RelationshipsPVPMinimapButton then
    RelationshipsPVP_SetIconPosition(0, 0, 1)
    db.icon.point    = "CENTER"
    db.icon.relPoint = "CENTER"
    db.icon.x        = 0
    db.icon.y        = 0
    db.icon.parent   = "UIParent"
  end

  db.panel = { point = "CENTER", x = 0, y = 0 }
  Print("Panel and minimap button reset to screen centre.")
end

function RelationshipsPVP_ResetStats()
  local db = EnsureDB()
  for i = 1, table.getn(ALL_KEYS) do
    db.stats[ALL_KEYS[i]] = NewStatBlock()
  end
  Print("PvP statistics cleared.")
  RelationshipsPVP_Refresh()
end

---------------------------------------------------------------
-- Events
---------------------------------------------------------------
function RelationshipsPVP_OnLoad()
  this:RegisterEvent("PLAYER_LOGIN")
  this:RegisterEvent("PLAYER_ENTERING_WORLD")
  this:RegisterEvent("PLAYER_LOGOUT")
  this:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
  this:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
  this:RegisterEvent("PLAYER_DEAD")
  this:RegisterEvent("PLAYER_REGEN_ENABLED")
  this:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
  this:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
  this:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
  this:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
  this:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
  this:RegisterEvent("HONOR_CURRENCY_UPDATE")
  this:RegisterEvent("CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS")
  this:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE")
  this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE")

  SLASH_RELATIONSHIPSPVP1 = "/rpvp"
  SLASH_RELATIONSHIPSPVP2 = "/relpvp"
  SLASH_RELATIONSHIPSPVP3 = "/relationshipspvp"
  SlashCmdList["RELATIONSHIPSPVP"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "leave" then
      RelationshipsPVP_LeaveAll()
    elseif msg == "av" then
      RelationshipsPVP_Queue("AV")
    elseif msg == "wsg" then
      RelationshipsPVP_Queue("WSG")
    elseif msg == "ab" then
      RelationshipsPVP_Queue("AB")
    elseif msg == "all" then
      RelationshipsPVP_QueueAllBGs()
    elseif msg == "2v2" then
      RelationshipsPVP_QueueArena("A2")
    elseif msg == "3v3" then
      RelationshipsPVP_QueueArena("A3")
    elseif msg == "5v5" then
      RelationshipsPVP_QueueArena("A5")
    elseif msg == "skirmish" or msg == "sk" then
      RelationshipsPVP_QueueArena("SK")
    elseif msg == "icon" or msg == "minimap" then
      RelationshipsPVP_ToggleMinimapIcon()
    elseif msg == "reset" then
      RelationshipsPVP_ResetPositions()
    elseif msg == "clear" or msg == "wipe" then
      RelationshipsPVP_ResetStats()
    elseif msg == "clearkos" or msg == "kos" then
      RelationshipsPVPCharDB.killedByAll       = {}
      RelationshipsPVPCharDB.lastMatchKilledBy = {}
      RelationshipsPVPCharDB.lastMatchKey      = nil
      RelationshipsPVPCharDB.currentMatch      = nil
      Print("Enemy kill tracking cleared.")
      RelationshipsPVP_Refresh()
    else
      if RelationshipsPVPFrame:IsVisible() then
        RelationshipsPVPFrame:Hide()
      else
        RelationshipsPVPFrame:Show()
      end
    end
  end

  Print("Loaded v1.8. Type /rpvp to open, /rpvp all to queue all BGs, /rpvp icon to toggle minimap icon.")
end

function RelationshipsPVP_SavePanelPos()
  SavePanelPos()
end

function RelationshipsPVP_OnEvent(event)
  if event == "PLAYER_LOGOUT" then
    RelationshipsPVP_SaveIconPos()
    SavePanelPos()
    return
  end

  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    EnsureDB()
    RestoreIconPos()
    RestorePanelPos()
    local key = DetectCurrentBG()
    local prev = currentBG
    currentBG = key
    OnCurrentBGChanged(prev, key)
    if not key then endReported = {} end
    RelationshipsPVP_Refresh()

  elseif event == "UPDATE_BATTLEFIELD_STATUS" then
    local key = DetectCurrentBG()
    local prev = currentBG
    currentBG = key
    OnCurrentBGChanged(prev, key)
    RelationshipsPVP_Refresh()

  elseif event == "UPDATE_BATTLEFIELD_SCORE" then
    local key, idx = DetectCurrentBG()
    if key and idx and GetBattlefieldWinner() then
      RecordEnd(key, idx)
    end
    RelationshipsPVP_Refresh()

  elseif event == "PLAYER_REGEN_ENABLED" then
    RelationshipsPVP_Refresh()

  elseif event == "CHAT_MSG_BG_SYSTEM_NEUTRAL"
      or event == "CHAT_MSG_BG_SYSTEM_ALLIANCE"
      or event == "CHAT_MSG_BG_SYSTEM_HORDE" then
    RequestBattlefieldScoreData()

  elseif event == "CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS"
      or event == "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE"
      or event == "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE" then
    NoteHostileHit(arg1)

  elseif event == "PLAYER_DEAD" then
    RegisterDeath()
    RelationshipsPVP_Refresh()

  elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN"
      or event == "PLAYER_PVP_KILLS_CHANGED"
      or event == "HONOR_CURRENCY_UPDATE" then
    -- Honor was just credited. If we're currently in a tracked BG, roll
    -- the spendable-honor delta into this BG's spend total right away so
    -- the value ticks live instead of only at the final scoreboard.
    if currentBG then
      CaptureSpendableHonor(currentBG)
      FinalizeSpendableHonor(currentBG, false)
      RelationshipsPVP_Refresh()
    end
  end
end
