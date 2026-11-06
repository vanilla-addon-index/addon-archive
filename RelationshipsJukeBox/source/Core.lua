local ADDON_NAME = "RelationshipsJukeBox"
local ADDON_MEDIA_PREFIX = "Interface\\AddOns\\RelationshipsJukeBox\\Media\\"

RelationshipsJukeboxDB = RelationshipsJukeboxDB or {}

local RJ = {}
RJ.page = 1
RJ.pageSize = 12
RJ.rows = {}
RJ.playQueue = nil
RJ.playQueuePosition = 0
RJ.searchFilter = ""
RJ.filteredIndices = nil  -- nil = no filter (show all); table = list of DB indices matching search
RJ.currentIndex = nil
RJ.currentPath = nil
RJ.currentName = nil
RJ.currentCanStop = false
RJ.currentDuration = 0
RJ.trackStartTime = nil   -- GetTime() when current track started playing
RJ.pausedElapsed = nil    -- elapsed seconds saved when paused (for timer display)
RJ.trackEndTime = nil
RJ.autoPlayEnabled = false
RJ.shuffleMode = false
RJ.isPaused = false
RJ.pauseCooldownUntil = 0  -- timestamp until which pause/play is blocked (1s cooldown)
RJ.playCooldownUntil = 0   -- timestamp until which the Play button is blocked (1s cooldown)
RJ.skipCooldownUntil = 0  -- timestamp until which Skip is blocked (1s cooldown)
RJ.prevCooldownUntil = 0   -- timestamp until which Previous is blocked (1s cooldown)
RJ.stopCooldownUntil = 0   -- timestamp until which Stop is blocked (1s cooldown)
local COOLDOWN_SECS = 1    -- universal cooldown for all playback buttons

-- Marquee (scrolling text) state for mini player
RJ.marqueeOffset = 0          -- current pixel offset for scrolling
RJ.marqueeSpeed = 25          -- pixels per second
RJ.marqueeGap = 0             -- legacy gap value; smooth looping now uses a text separator instead
RJ.marqueeSeparator = "   •   "
RJ.marqueeCycleWidth = 0      -- width of one full repeated cycle
RJ.marqueeLastUpdate = 0      -- last OnUpdate timestamp
RJ.marqueeFullText = ""       -- the repeated display text used for looping
RJ.marqueeSingleWidth = 0     -- pixel width of the single-copy display text
RJ.marqueeSingleText = ""     -- the single-copy display text (before duplication)

-- Polling state: when a track has no duration metadata, we poll IsPlaying
-- to detect when it finishes, so autoplay/shuffle can advance.
RJ.pollingForEnd = false
RJ.pollStartDelay = 2
RJ.pollTimer = 0
RJ.pollInterval = 0.5
RJ.consecutiveNotPlaying = 0
RJ.consecutiveThreshold = 4

-- Delayed sound re-enable state: KillAllSounds() sets MasterSoundEffects="0"
-- and schedules a re-enable via the ticker's OnUpdate after a short delay.
RJ._pendingReenableAt = nil        -- GetTime() when MasterSoundEffects should be re-enabled
RJ._pendingReenableCallback = nil  -- function to call after re-enable (e.g., play new track)

-- Fallback duration used when no metadata is available (seconds).
local FALLBACK_DURATION = 180

-- Format seconds as M:SS or MM:SS
-- Note: WoW 1.12 uses Lua 5.0 which has no '%' operator; use math.mod() instead.
local function FormatTime(seconds)
  if not seconds or seconds < 0 then seconds = 0 end
  seconds = math.floor(seconds + 0.5)
  local m = math.floor(seconds / 60)
  local s = math.mod(seconds, 60)
  return string.format("%d:%02d", m, s)
end

-- Format elapsed/total as "M:SS/M:SS"
local function FormatElapsedTime(elapsed, total)
  return FormatTime(elapsed) .. "/" .. FormatTime(total)
end

local function Count(t)
  if table.getn then return table.getn(t) end
  local n = 0
  while t[n + 1] ~= nil do
    n = n + 1
  end
  return n
end

-----------------------------------------------------------------------
-- Sound-CVar snapshot / restore.
--
-- Every CVar this addon writes to (MasterSoundEffects, EnableMusic,
-- MasterVolume, ...) is snapshotted into SavedVariables the FIRST time
-- we change it in a session, and restored on PLAYER_LOGOUT.
--
-- Why SavedVariables and not just an in-memory table:
--   KillAllSounds() sets MasterSoundEffects="0" and re-enables it ~50ms
--   later from the ticker.  If the player /reloads, logs out, or the
--   client crashes inside that window, "0" is what WoW persists to
--   Config.wtf and every sound effect is muted on the next login with
--   no obvious cause.  Persisting the pre-mute value lets us recover
--   on the very next VARIABLES_LOADED even after a hard crash.
-----------------------------------------------------------------------
local function SnapshotCVar(name)
  if type(RelationshipsJukeboxDB) ~= "table" then RelationshipsJukeboxDB = {} end
  if type(RelationshipsJukeboxDB.savedCVars) ~= "table" then
    RelationshipsJukeboxDB.savedCVars = {}
  end
  if RelationshipsJukeboxDB.savedCVars[name] ~= nil then
    return  -- already snapshotted this session (or from a previous crashed session)
  end
  local cv = GetCVar or function() return nil end
  local ok, val = pcall(cv, name)
  if ok and val ~= nil then
    RelationshipsJukeboxDB.savedCVars[name] = tostring(val)
  end
end

local function RestoreSavedCVars()
  if type(RelationshipsJukeboxDB) ~= "table" then return end
  local saved = RelationshipsJukeboxDB.savedCVars
  if type(saved) ~= "table" then return end
  local sc = SetCVar or function() end
  for name, value in pairs(saved) do
    pcall(sc, name, value)
  end
  RelationshipsJukeboxDB.savedCVars = nil
end

local function Trim(s)
  if not s then return "" end
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function NormalizePath(input)
  local path = Trim(input)
  path = string.gsub(path, "/", "\\")
  if path == "" then return "" end
  if string.find(string.lower(path), "^interface\\") or string.find(string.lower(path), "^sound\\") or string.find(string.lower(path), "^data\\") then
    return path
  end
  return ADDON_MEDIA_PREFIX .. path
end

local function CanonicalPath(input)
  local path = NormalizePath(input)
  return string.lower(path)
end

local function EnsureDB()
  if type(RelationshipsJukeboxDB) ~= "table" then RelationshipsJukeboxDB = {} end
  if type(RelationshipsJukeboxDB.tracks) ~= "table" then RelationshipsJukeboxDB.tracks = {} end
end

local function ExtractFileName(path)
  local clean
  if not path then return "" end
  clean = string.gsub(path, "/", "\\")
  clean = string.gsub(clean, "^.*\\", "")
  return clean
end

-- Clean up a file name for display: strip leading numbers, dashes, underscores,
-- and convert remaining underscores to spaces.  Also remove the file extension.
-- Examples:
--   "05 - this_song3.mp3"  -> "this song"
--   "01. Session.mp3"      -> "Session"
--   "06 - System Of A Down - Chop Suey_.mp3" -> "System Of A Down - Chop Suey"
local function CleanDisplayName(name)
  if not name or name == "" then return "" end
  -- Remove file extension (last .mp3, .wav, .ogg, etc.)
  name = string.gsub(name, "%.%w+$", "")
  -- Strip leading numbers followed by optional separator (digits, dots, dashes, spaces)
  -- e.g. "05 - ", "01. ", "06 - ", "02. ", etc.
  name = string.gsub(name, "^[%d%.]+[%s%-_]*", "")
  -- Strip any remaining leading dashes or underscores
  name = string.gsub(name, "^[%-_]+", "")
  -- Strip leading whitespace
  name = string.gsub(name, "^%s+", "")
  -- Strip trailing numbers, dashes, underscores
  name = string.gsub(name, "[%d%-_]+$", "")
  -- Strip trailing whitespace
  name = string.gsub(name, "%s+$", "")
  -- Replace remaining underscores with spaces
  name = string.gsub(name, "_", " ")
  -- Collapse multiple spaces into one
  name = string.gsub(name, "  +", " ")
  return Trim(name)
end

local function GetTrackPath(entry)
  if type(entry) == "table" then
    return NormalizePath(entry.path or entry.file or "")
  end
  if type(entry) == "string" then
    return NormalizePath(entry)
  end
  return ""
end

-- GetTrackName returns the raw track name for storage and path resolution.
-- It does NOT apply CleanDisplayName — the stored name must match the actual
-- file so that path/name resolution works correctly across reloads.
local function GetTrackName(entry)
  local path = GetTrackPath(entry)
  if type(entry) == "table" then
    local customName = Trim(entry.name or entry.title or "")
    if customName ~= "" then
      return customName
    end
  end
  return ExtractFileName(path)
end

-- GetTrackDisplayName returns a cleaned-up name suitable for UI display only.
-- This strips leading numbers, dashes, underscores, extensions, etc.
-- It must NEVER be used when storing names into SavedVariables or matching
-- entries by name, only for rendering labels and status text.
local function GetTrackDisplayName(entry)
  return CleanDisplayName(GetTrackName(entry))
end

local function GetTrackDuration(entry)
  if type(entry) == "table" then
    local duration = tonumber(entry.duration or entry.length or entry.seconds or 0)
    if duration and duration > 0 then
      return duration
    end
  end
  return 0
end

local function CreateTrackEntry(path, name, duration, folder, dateAdded, size)
  local normalized = NormalizePath(path)
  if normalized == "" then return nil end
  return {
    path = normalized,
    name = Trim(name or "") ~= "" and Trim(name) or ExtractFileName(normalized),
    duration = tonumber(duration) or 0,
    folder = folder or "",
    dateAdded = tonumber(dateAdded) or 0,
    size = tonumber(size) or 0,
  }
end

-- Return the subfolder (relative to Media\) that a track lives in.  Uses the
-- explicit `folder` field written by the PS1 generator when present, and
-- falls back to deriving from the path (everything between ADDON_MEDIA_PREFIX
-- and the file leaf).  Empty string == root of Media\.
local function GetTrackFolder(entry)
  if type(entry) == "table" and type(entry.folder) == "string" and entry.folder ~= "" then
    return entry.folder
  end
  local path = GetTrackPath(entry)
  if path == "" then return "" end
  local prefixLen = string.len(ADDON_MEDIA_PREFIX)
  if string.lower(string.sub(path, 1, prefixLen)) == string.lower(ADDON_MEDIA_PREFIX) then
    local rel = string.sub(path, prefixLen + 1)
    local stripped = string.gsub(rel, "\\[^\\]+$", "")
    if stripped == rel then return "" end
    return stripped
  end
  return ""
end

local function GetTrackDateAdded(entry)
  if type(entry) == "table" then
    return tonumber(entry.dateAdded or entry.added or 0) or 0
  end
  return 0
end

local function BuildTrackLookup()
  local seen = {}
  local i
  EnsureDB()
  for i = 1, Count(RelationshipsJukeboxDB.tracks) do
    local path = GetTrackPath(RelationshipsJukeboxDB.tracks[i])
    if path ~= "" then
      seen[string.lower(path)] = i
    end
  end
  return seen
end

local function MergeAutoPlaylist()
  local auto, seen, imported, updated, i, entry, path, name, duration, track, existingIndex, existingEntry, currentName, currentDuration, changed
  EnsureDB()
  auto = RelationshipsJukeboxAutoPlaylist
  if type(auto) ~= "table" or type(auto.tracks) ~= "table" then
    return 0, 0
  end
  seen = BuildTrackLookup()
  imported = 0
  updated = 0
  for i = 1, Count(auto.tracks) do
    entry = auto.tracks[i]
    path = GetTrackPath(entry)
    if path ~= "" then
      local key = string.lower(path)
      name = GetTrackName(entry)
      duration = GetTrackDuration(entry)
      local folder = (type(entry) == "table" and type(entry.folder) == "string") and entry.folder or ""
      local dateAdded = (type(entry) == "table" and tonumber(entry.dateAdded or 0)) or 0
      local size = (type(entry) == "table" and tonumber(entry.size or 0)) or 0
      existingIndex = seen[key]
      if existingIndex then
        existingEntry = RelationshipsJukeboxDB.tracks[existingIndex]
        changed = false
        if type(existingEntry) ~= "table" then
          track = CreateTrackEntry(path, name, duration, folder, dateAdded, size)
          if track then
            RelationshipsJukeboxDB.tracks[existingIndex] = track
            updated = updated + 1
          end
        else
          existingEntry.path = NormalizePath(existingEntry.path or existingEntry.file or path)
          currentName = Trim(existingEntry.name or existingEntry.title or "")
          if currentName == "" or currentName == ExtractFileName(path) then
            existingEntry.name = name
            changed = true
          end
          currentDuration = tonumber(existingEntry.duration or existingEntry.length or existingEntry.seconds or 0) or 0
          if currentDuration <= 0 and duration > 0 then
            existingEntry.duration = duration
            changed = true
          end
          -- Backfill folder / dateAdded / size when the PS1 generator supplies them
          -- and the stored entry is missing them.  Never overwrite existing values
          -- (the user may have older exports that don't include these fields).
          if folder ~= "" and (existingEntry.folder == nil or existingEntry.folder == "") then
            existingEntry.folder = folder
            changed = true
          end
          if dateAdded > 0 and (not tonumber(existingEntry.dateAdded) or existingEntry.dateAdded == 0) then
            existingEntry.dateAdded = dateAdded
            changed = true
          end
          if size > 0 and (not tonumber(existingEntry.size) or existingEntry.size == 0) then
            existingEntry.size = size
            changed = true
          end
          if changed then
            updated = updated + 1
          end
        end
      else
        track = CreateTrackEntry(path, name, duration, folder, dateAdded, size)
        if track then
          table.insert(RelationshipsJukeboxDB.tracks, track)
          seen[key] = Count(RelationshipsJukeboxDB.tracks)
          imported = imported + 1
        end
      end
    end
  end
  return imported, updated
end

-----------------------------------------------------------------------
-- Playlists & Favorites
-----------------------------------------------------------------------
-- Storage shape in SavedVariables:
--   RelationshipsJukeboxDB.playlists = {
--     ["Favorites"] = { paths = { "Interface\\...\\track.mp3", ... }, builtin = true },
--     ["My Mix"]    = { paths = { ... } },
--     ...
--   }
--   RelationshipsJukeboxDB.activePlaylist = "All" | "Favorites" | "folder:<name>" | "user:<name>"
--
-- Folder auto-playlists are NOT stored in the .playlists table: they are
-- derived on demand from the .folder field on each track (populated by
-- GeneratePlaylist.ps1) so they always match what's on disk.
-----------------------------------------------------------------------
local function EnsurePlaylists()
  EnsureDB()
  if type(RelationshipsJukeboxDB.playlists) ~= "table" then
    RelationshipsJukeboxDB.playlists = {}
  end
  local fav = RelationshipsJukeboxDB.playlists["Favorites"]
  if type(fav) ~= "table" then
    RelationshipsJukeboxDB.playlists["Favorites"] = { paths = {}, builtin = true }
  elseif type(fav.paths) ~= "table" then
    fav.paths = {}
  end
  if type(RelationshipsJukeboxDB.activePlaylist) ~= "string" then
    RelationshipsJukeboxDB.activePlaylist = "All"
  end
end

local function Playlist_PathSet(name)
  EnsurePlaylists()
  local pl = RelationshipsJukeboxDB.playlists[name]
  local set = {}
  if type(pl) ~= "table" or type(pl.paths) ~= "table" then return set end
  for i = 1, Count(pl.paths) do
    set[string.lower(pl.paths[i] or "")] = true
  end
  return set
end

local function Playlist_Contains(name, path)
  if not path or path == "" then return false end
  return Playlist_PathSet(name)[string.lower(path)] == true
end

local function Playlist_AddPath(name, path)
  EnsurePlaylists()
  path = NormalizePath(path or "")
  if path == "" or name == nil or name == "" or name == "All" then return false end
  if type(RelationshipsJukeboxDB.playlists[name]) ~= "table" then
    RelationshipsJukeboxDB.playlists[name] = { paths = {} }
  end
  local pl = RelationshipsJukeboxDB.playlists[name]
  if type(pl.paths) ~= "table" then pl.paths = {} end
  local lower = string.lower(path)
  for i = 1, Count(pl.paths) do
    if string.lower(pl.paths[i]) == lower then return false end
  end
  table.insert(pl.paths, path)
  return true
end

local function Playlist_RemovePath(name, path)
  EnsurePlaylists()
  local pl = RelationshipsJukeboxDB.playlists[name]
  if type(pl) ~= "table" or type(pl.paths) ~= "table" then return false end
  local lower = string.lower(NormalizePath(path or ""))
  for i = Count(pl.paths), 1, -1 do
    if string.lower(pl.paths[i]) == lower then
      table.remove(pl.paths, i)
      return true
    end
  end
  return false
end

local function Playlist_TogglePath(name, path)
  if Playlist_Contains(name, path) then
    Playlist_RemovePath(name, path)
    return false
  end
  Playlist_AddPath(name, path)
  return true
end

local function ToggleFavorite(path)
  return Playlist_TogglePath("Favorites", path)
end

-- Return sorted list of folder names present in the current track library.
local function GetFolderPlaylists()
  EnsureDB()
  local folders, seen = {}, {}
  for i = 1, Count(RelationshipsJukeboxDB.tracks) do
    local f = GetTrackFolder(RelationshipsJukeboxDB.tracks[i])
    if f ~= "" and not seen[f] then
      seen[f] = true
      table.insert(folders, f)
    end
  end
  table.sort(folders)
  return folders
end

-- Return sorted list of user-defined playlists (excludes the built-in Favorites).
local function GetUserPlaylists()
  EnsurePlaylists()
  local names = {}
  for name, _ in pairs(RelationshipsJukeboxDB.playlists) do
    if name ~= "Favorites" then table.insert(names, name) end
  end
  table.sort(names)
  return names
end

-- Return the DB indices that belong to the active playlist, or nil for "All".
local function ActivePlaylistIndices()
  EnsurePlaylists()
  local active = RelationshipsJukeboxDB.activePlaylist or "All"
  if active == "All" or active == "" then return nil end
  EnsureDB()
  local out = {}
  if active == "Queue" then
    -- Show the user queue in playback order. Duplicates & missing tracks
    -- are handled: missing paths are skipped, duplicates appear once each
    -- position they occur.
    if type(RelationshipsJukeboxDB.userQueue) == "table"
       and type(RelationshipsJukeboxDB.userQueue.paths) == "table" then
      local paths = RelationshipsJukeboxDB.userQueue.paths
      for qi = 1, Count(paths) do
        local idx = nil
        local target = string.lower(paths[qi] or "")
        for i = 1, Count(RelationshipsJukeboxDB.tracks) do
          if string.lower(GetTrackPath(RelationshipsJukeboxDB.tracks[i])) == target then
            idx = i; break
          end
        end
        if idx then table.insert(out, idx) end
      end
    end
    return out
  end
  if active == "Favorites" then
    local set = Playlist_PathSet("Favorites")
    for i = 1, Count(RelationshipsJukeboxDB.tracks) do
      if set[string.lower(GetTrackPath(RelationshipsJukeboxDB.tracks[i]))] then
        table.insert(out, i)
      end
    end
    return out
  end
  if string.sub(active, 1, 7) == "folder:" then
    local folder = string.sub(active, 8)
    for i = 1, Count(RelationshipsJukeboxDB.tracks) do
      if GetTrackFolder(RelationshipsJukeboxDB.tracks[i]) == folder then
        table.insert(out, i)
      end
    end
    return out
  end
  if string.sub(active, 1, 5) == "user:" then
    local name = string.sub(active, 6)
    local set = Playlist_PathSet(name)
    for i = 1, Count(RelationshipsJukeboxDB.tracks) do
      if set[string.lower(GetTrackPath(RelationshipsJukeboxDB.tracks[i]))] then
        table.insert(out, i)
      end
    end
    return out
  end
  return nil
end

-- Friendly label for the active-playlist dropdown text.
local function PlaylistDisplayLabel(value)
  if not value or value == "" or value == "All" then return "All Tracks" end
  if value == "Favorites" then return "* Favorites" end
  if value == "Queue" then return "Up Next (Queue)" end
  if string.sub(value, 1, 7) == "folder:" then return "[folder] " .. string.sub(value, 8) end
  if string.sub(value, 1, 5) == "user:"   then return string.sub(value, 6) end
  return value
end

-----------------------------------------------------------------------
-- User Queue ("Up Next")
--
-- A user-managed queue of track paths.  Independent from the internal
-- RJ.playQueue (which is the shuffled playlist queue built by Play All).
-- The user queue is drained FIRST whenever a track ends and always
-- auto-advances regardless of the autoPlayEnabled toggle.
--
-- Storage: RelationshipsJukeboxDB.userQueue.paths = { "Interface\\...", ... }
-----------------------------------------------------------------------
local function EnsureUserQueue()
  EnsureDB()
  if type(RelationshipsJukeboxDB.userQueue) ~= "table" then
    RelationshipsJukeboxDB.userQueue = { paths = {} }
  elseif type(RelationshipsJukeboxDB.userQueue.paths) ~= "table" then
    RelationshipsJukeboxDB.userQueue.paths = {}
  end
  return RelationshipsJukeboxDB.userQueue
end

local function Queue_Count()
  EnsureUserQueue()
  return Count(RelationshipsJukeboxDB.userQueue.paths)
end

local function Queue_Add(path)
  EnsureUserQueue()
  path = NormalizePath(path or "")
  if path == "" then return false end
  table.insert(RelationshipsJukeboxDB.userQueue.paths, path)
  return true
end

local function Queue_PlayNext(path)
  EnsureUserQueue()
  path = NormalizePath(path or "")
  if path == "" then return false end
  table.insert(RelationshipsJukeboxDB.userQueue.paths, 1, path)
  return true
end

local function Queue_PopHead()
  EnsureUserQueue()
  local q = RelationshipsJukeboxDB.userQueue.paths
  if Count(q) == 0 then return nil end
  local head = q[1]
  table.remove(q, 1)
  return head
end

local function Queue_RemoveAt(index)
  EnsureUserQueue()
  local q = RelationshipsJukeboxDB.userQueue.paths
  if index and index >= 1 and index <= Count(q) then
    table.remove(q, index)
    return true
  end
  return false
end

local function Queue_Clear()
  EnsureUserQueue()
  RelationshipsJukeboxDB.userQueue.paths = {}
end

-- Look up a DB index for a given track path (case-insensitive on the path).
local function IndexForPath(path)
  if not path or path == "" then return nil end
  EnsureDB()
  local target = string.lower(NormalizePath(path))
  for i = 1, Count(RelationshipsJukeboxDB.tracks) do
    if string.lower(GetTrackPath(RelationshipsJukeboxDB.tracks[i])) == target then
      return i
    end
  end
  return nil
end




local function SetStatus(msg, r, g, b)
  if RJ.statusText then
    RJ.statusText:SetText(msg or "")
    if RJ.statusText.SetTextColor then
      RJ.statusText:SetTextColor(r or 1, g or 0.82, b or 0)
    end
  end
end

-----------------------------------------------------------------------
-- NOW-PLAYING ANNOUNCE
-----------------------------------------------------------------------
-- Broadcasts the currently playing track to a chat channel.  Off by
-- default; configured via the Options panel on the main GUI, or the
-- "/rj np [channel]" slash command for a one-off manual announce.
--
-- RelationshipsJukeboxDB.announce = {
--   enabled = false,               -- auto-announce on track change
--   channel = "AUTO",              -- AUTO | PARTY | RAID | GUILD | SAY | YELL
--   format  = "\226\153\170 Now Playing: %s",
-- }
local VALID_ANNOUNCE_CHANNELS = {
  AUTO = true, PARTY = true, RAID = true, GUILD = true, SAY = true, YELL = true,
}

local function EnsureAnnounceSettings()
  if type(RelationshipsJukeboxDB) ~= "table" then return end
  if type(RelationshipsJukeboxDB.announce) ~= "table" then
    RelationshipsJukeboxDB.announce = {}
  end
  local a = RelationshipsJukeboxDB.announce
  if type(a.enabled) ~= "boolean" then a.enabled = false end
  if type(a.channel) ~= "string" or not VALID_ANNOUNCE_CHANNELS[a.channel] then
    a.channel = "AUTO"
  end
  if type(a.format) ~= "string" or a.format == "" then
    a.format = "\226\153\170 Now Playing: %s"
  end
end

-- Resolve AUTO -> best available channel for the current group state.
-- Returns nil when AUTO is selected and the player is solo (so auto-
-- announce stays quiet instead of spamming /say).
local function ResolveAnnounceChannel(chan)
  chan = chan or "AUTO"
  if chan ~= "AUTO" then return chan end
  local raid = (GetNumRaidMembers and GetNumRaidMembers()) or 0
  if raid > 0 then return "RAID" end
  local party = (GetNumPartyMembers and GetNumPartyMembers()) or 0
  if party > 0 then return "PARTY" end
  return nil
end

-- force=true  -> manual announce (slash command); falls back to SAY
--                when AUTO resolves to solo, and ignores the enabled flag.
-- force=false -> automatic announce on track change; requires enabled=true
--                and stays silent when solo under AUTO.
function AnnounceNowPlaying(force, channelOverride)
  EnsureAnnounceSettings()
  local a = RelationshipsJukeboxDB.announce
  if not force and not a.enabled then return end
  local name = RJ.currentName
  if not name or name == "" then
    if force then SetStatus("No track is playing.", 1, 0.4, 0.4) end
    return
  end
  local chan = channelOverride or a.channel or "AUTO"
  if not VALID_ANNOUNCE_CHANNELS[chan] then
    if force then SetStatus("Unknown channel: " .. chan, 1, 0.4, 0.4) end
    return
  end
  local resolved = ResolveAnnounceChannel(chan)
  if not resolved then
    if force then
      resolved = "SAY"
    else
      return
    end
  end
  if not SendChatMessage then return end
  local msg = string.format(a.format or "Now Playing: %s", name)
  SendChatMessage(msg, resolved)
end

local function ShuffleQueue(queue)
  local i
  if not queue then return end
  for i = Count(queue), 2, -1 do
    local j = math.random(i)
    queue[i], queue[j] = queue[j], queue[i]
  end
end

-----------------------------------------------------------------------
-- AUDIO CHANNEL STRATEGY (revised for Turtle WoW / OctoWoW)
-----------------------------------------------------------------------
-- WoW 1.12 uses FMOD 3.x which has multiple independent audio channels.
--
-- KEY INSIGHT: The Music channel (used by PlayMusic and zone ambient
-- music) shares the same FMOD channel.  Zone music events REPLACE
-- whatever is playing on the Music channel, which restarts jukebox
-- tracks.  The addon disables EnableMusic on load to prevent zone music
-- from overlapping with jukebox playback.
--
-- PlaySoundFile(path, "Ambience") routes through the Ambience channel
-- on Turtle WoW / OctoWoW, which is separate from both the Music and
-- SFX channels.  The jukebox volume is controlled by the MasterVolume
-- CVar (0.0-1.0), which the in-game Options screen exposes as the
-- "Master Volume" slider.  The addon provides its own volume slider on
-- the main GUI that sets MasterVolume directly, controlling the master
-- output volume for all game audio including the jukebox.
--
-- Zone changes and loading screens do NOT interrupt sounds on the
-- Ambience channel, so no event handler is needed for them.
--
-- To STOP a playing track, we use KillAllSounds() which sets
-- MasterSoundEffects="0" to kill ALL currently playing sounds, then
-- re-enables it on the next frame via the ticker.  FMOD needs at least
-- one frame to process the "off" state before we can safely re-enable.
-- The new PlaySoundFile call that follows (after the re-enable callback)
-- then starts fresh.
--
-- STOP / SKIP / PREVIOUS:
--   • KillAllSounds() sets MasterSoundEffects="0" to kill the current
--     sound, then re-enables on the next frame.  This creates a
--     ~1 frame silence but reliably stops whatever is playing.
--     The subsequent PlaySoundFile starts the new track cleanly.
--
-- PAUSE:
--   • Pause saves elapsed time and stops the track via
--     KillAllSounds() (same disable/re-enable mechanism).
--   • Resume replays the track from the beginning (PlaySoundFile
--     has no seek/offset API).  The track restarts, but pause/
--     resume functionality is preserved.
--
-- ZONE MUSIC SUPPRESSION:
--   • The jukebox now plays through its own sound channel, so zone
--     ambient music events no longer interfere with jukebox playback.
--     We still set EnableMusic="0" while the jukebox is playing to
--     prevent the game engine from playing zone ambient music on the
--     Music channel.
--
-- KEY BENEFIT: KillAllSounds() / MasterSoundEffects toggle reliably stops ANY
-- playing sound regardless of channel, so Stop/Skip/Previous
-- always work.
-- Check whether a file path uses a format that previously required
-- PlayMusic (WAV/OGG).  Now ALL tracks use PlaySoundFile regardless
-- of format, so this function is only used for format identification,
-- not for channel routing decisions.
local function IsMusicPath(path)
  local lower = string.lower(path or "")
  return string.find(lower, "%.wav$") ~= nil
      or string.find(lower, "%.ogg$") ~= nil
end

-- Check whether a file path is an MP3 file.  Now ALL tracks use
-- PlaySoundFile regardless of format.  This function is kept for
-- format identification only, not for channel routing decisions.
local function IsSfxPath(path)
  local lower = string.lower(path or "")
  return string.find(lower, "%.mp3$") ~= nil
end

-----------------------------------------------------------------------
-- KillAllSounds: Disable all sound via CVar, schedule re-enable next frame
-----------------------------------------------------------------------
-- FMOD 3.x needs at least one frame to process the "off" state before
-- we can safely re-enable.  If we toggle off/on in the same frame,
-- FMOD never actually stops the audio.  This function:
--   1. Sets MasterSoundEffects="0" to immediately kill ALL playing sounds
--   2. Schedules a re-enable via the ticker's OnUpdate (next frame)
--   3. Also calls StopMusic() as a fallback
--
-- The caller can optionally pass a callback to invoke after re-enable
-- (e.g., to play a new track immediately after the old one is killed).

local function KillAllSounds(afterReenableCallback)
  local sc = SetCVar or function() end
  -- Snapshot MasterSoundEffects BEFORE muting, so if the player /reloads
  -- or crashes before the ticker re-enables it, we can restore it on
  -- the next login instead of leaving Config.wtf with SFX muted.
  SnapshotCVar("MasterSoundEffects")
  -- Kill ALL currently playing sounds by disabling the master sound CVar.
  pcall(sc, "MasterSoundEffects", "0")
  -- Also stop any PlayMusic track as a fallback.
  if StopMusic then
    StopMusic()
  end
  -- Schedule re-enable on the next frame.  FMOD needs at least one
  -- frame to process the "off" before we turn sound back on.
  -- If a callback was already pending, preserve it unless a new one
  -- is provided (the new callback supersedes the old one).
  RJ._pendingReenableAt = GetTime() + 0.05   -- ~50ms delay (1-2 frames at 30fps)
  if afterReenableCallback then
    RJ._pendingReenableCallback = afterReenableCallback
  end
end

-- Stop the jukebox track.
-- PlaySoundFile is fire-and-forget, so StopMusic() does NOT stop it.
-- Instead, we use KillAllSounds() which disables MasterSoundEffects (killing
-- ALL playing sounds) and re-enables it on the next frame.  A safety
-- StopMusic() call is also included inside KillAllSounds as a fallback.
local function StopJukeboxTrack()
  KillAllSounds()
end

-----------------------------------------------------------------------
-- Forward declarations (mutual recursion: PlayNextQueuedTrack <-> PlayTrack)
-----------------------------------------------------------------------
local PlayTrack
local PlayNextQueuedTrack

-----------------------------------------------------------------------
-- Playback button state (forward-declared so PausePlayback/ResumePlayback can call it)
-----------------------------------------------------------------------
local RefreshPlaybackButtons

-----------------------------------------------------------------------
-- Zone music control (forward-declared so PausePlayback/ResumePlayback/
-- StopPlayback/PlayTrack can call them before their definitions)
-----------------------------------------------------------------------


-----------------------------------------------------------------------
-- Format detection helpers
-- These identify file formats (MP3 vs WAV/OGG) for display purposes.
-- ALL tracks use PlaySoundFile regardless of format, so these are
-- only for format identification, not channel routing.
-----------------------------------------------------------------------

-----------------------------------------------------------------------
-- Pause / Resume
-----------------------------------------------------------------------
local function PausePlayback()
  if not RJ.currentPath or RJ.isPaused then return end
  if GetTime() < RJ.pauseCooldownUntil then
    SetStatus("Pause cooldown -- please wait...", 1, 1, 0.2)
    return
  end
  RJ.isPaused = true

  -- Save remaining time for timed tracks
  if RJ.trackEndTime then
    RJ.pausedRemaining = RJ.trackEndTime - GetTime()
    RJ.trackEndTime = nil
  else
    RJ.pausedRemaining = nil
  end
  -- Save elapsed time for timer display while paused
  if RJ.trackStartTime then
    RJ.pausedElapsed = GetTime() - RJ.trackStartTime
  else
    RJ.pausedElapsed = nil
  end
  RJ.pollingForEnd = false
  -- Restore zone music CVar (note: since the addon disables EnableMusic
  -- on load, this will restore it to "0" -- game music stays off even
  -- while paused, which is the intended behavior).
  RestoreZoneMusic()
  -- Stop the jukebox track.
  StopJukeboxTrack()
  -- 1-second cooldown after pause to prevent rapid toggle spam
  RJ.pauseCooldownUntil = GetTime() + COOLDOWN_SECS
  SetStatus("Paused: " .. (RJ.currentName or ""), 1, 1, 0.2)
  RefreshPlaybackButtons()
  RefreshMiniPlayer()
end

local function ResumePlayback()
  if not RJ.isPaused then return end
  if GetTime() < RJ.pauseCooldownUntil then
    SetStatus("Play cooldown -- please wait...", 1, 1, 0.2)
    return
  end
  RJ.isPaused = false

  if RJ.currentPath then
    -- Ensure all sound is enabled so PlaySoundFile works.
    local sc = SetCVar or function() end
    pcall(sc, "MasterSoundEffects", "1")

    -- ALL tracks use PlaySoundFile(path, "Ambience").
    if PlaySoundFile then
      PlaySoundFile(RJ.currentPath, "Ambience")
      RJ.currentCanStop = true
    end

    -- Suppress zone ambient music on the Music channel.
    SuppressZoneMusic()

    -- Restore timer or polling
    if RJ.pausedRemaining and RJ.pausedRemaining > 0 then
      RJ.trackEndTime = GetTime() + RJ.pausedRemaining
      RJ.pausedRemaining = nil
    elseif RJ.currentCanStop and IsPlaying then
      RJ.pollingForEnd = true
      RJ.pollTimer = GetTime() + RJ.pollStartDelay
      RJ.consecutiveNotPlaying = 0
      RJ.pausedRemaining = nil
    end

    -- Adjust trackStartTime so elapsed timer continues from where it was
    if RJ.pausedElapsed then
      RJ.trackStartTime = GetTime() - RJ.pausedElapsed
      RJ.pausedElapsed = nil
    else
      RJ.trackStartTime = GetTime()
    end
  end

  -- 1-second cooldown after resume to prevent rapid toggle spam
  RJ.pauseCooldownUntil = GetTime() + COOLDOWN_SECS
  -- Set the full 1-second play cooldown to prevent spam-playing other tracks
  RJ.playCooldownUntil = GetTime() + COOLDOWN_SECS
  SetStatus("Resumed: " .. (RJ.currentName or ""), 0.2, 1, 0.2)
  RefreshPlaybackButtons()
  RefreshMiniPlayer()
end


local function TogglePause()
  if GetTime() < RJ.pauseCooldownUntil then
    SetStatus("Pause/Play cooldown -- please wait...", 1, 1, 0.2)
    return
  end
  if RJ.isPaused then
    ResumePlayback()
  else
    PausePlayback()
  end
end


local function StopPlayback(silent)
  -- 1-second cooldown on Stop to prevent music overlap
  if not silent and GetTime() < RJ.stopCooldownUntil then
    SetStatus("Stop cooldown -- please wait...", 1, 1, 0.2)
    return
  end

  RJ.isPaused = false
  RJ.pausedRemaining = nil
  RJ.pauseCooldownUntil = 0
  RJ.playCooldownUntil = 0
  RJ.skipCooldownUntil = 0
  RJ.prevCooldownUntil = 0
  RJ.stopCooldownUntil = 0
  RJ.autoPlayEnabled = false
  RJ.playQueue = nil
  RJ.playQueuePosition = 0
  RJ.trackEndTime = nil
  RJ.trackStartTime = nil
  RJ.pausedElapsed = nil
  RJ.currentDuration = 0
  RJ.pollingForEnd = false
  RJ.pollTimer = 0
  RJ.consecutiveNotPlaying = 0

  -- Restore zone music CVar (note: since the addon disables EnableMusic
  -- on load, this will restore it to "0" -- game music stays off even
  -- when stopped, matching the intended behavior).
  RestoreZoneMusic()
  -- Stop the jukebox track.
  StopJukeboxTrack()

  RJ.currentCanStop = false
  RJ.currentIndex = nil
  RJ.currentPath = nil
  RJ.currentName = nil

  if not silent then
    -- Set 1-second cooldown after Stop to prevent rapid re-play causing audio overlap
    RJ.stopCooldownUntil = GetTime() + COOLDOWN_SECS
    SetStatus("Stopped.", 1, 0.82, 0)
  end

  RefreshPlaybackButtons()
  RefreshMiniPlayer()
end

-----------------------------------------------------------------------
-- Playback button state
-----------------------------------------------------------------------
RefreshPlaybackButtons = function()
  local hasTracks = Count(RelationshipsJukeboxDB.tracks) > 0
  local isPlaying = RJ.currentPath ~= nil or RJ.autoPlayEnabled
  local inQueue = RJ.autoPlayEnabled and RJ.playQueue ~= nil
  local now = GetTime()

  if RJ.playAllButton then
    if hasTracks and not isPlaying and now >= RJ.playCooldownUntil and now >= RJ.stopCooldownUntil then
      RJ.playAllButton:Enable()
    else
      RJ.playAllButton:Disable()
    end
  end

  if RJ.shuffleButton then
    if hasTracks and not isPlaying and now >= RJ.playCooldownUntil and now >= RJ.stopCooldownUntil then
      RJ.shuffleButton:Enable()
    else
      RJ.shuffleButton:Disable()
    end
  end

  if RJ.stopButton then
    if (isPlaying or RJ.isPaused) and now >= RJ.stopCooldownUntil then
      RJ.stopButton:Enable()
    else
      RJ.stopButton:Disable()
    end
  end

  if RJ.skipButton then
    if inQueue and now >= RJ.skipCooldownUntil then
      RJ.skipButton:Enable()
    else
      RJ.skipButton:Disable()
    end
  end

  if RJ.prevButton then
    if inQueue and RJ.playQueuePosition > 1 and now >= RJ.prevCooldownUntil then
      RJ.prevButton:Enable()
    else
      RJ.prevButton:Disable()
    end
  end

  RefreshMiniPlayer()
end

-----------------------------------------------------------------------
-- List / page UI
-----------------------------------------------------------------------
local function RefreshList()
  EnsureDB()

  -- Determine which indices to display: filtered or all
  local indices = RJ.filteredIndices  -- nil = no filter (show all)
  local total, totalPages

  if indices then
    total = Count(indices)
  else
    total = Count(RelationshipsJukeboxDB.tracks)
  end

  totalPages = math.max(1, math.ceil(total / RJ.pageSize))
  if RJ.page > totalPages then RJ.page = totalPages end
  if RJ.page < 1 then RJ.page = 1 end

  local startIndex = ((RJ.page - 1) * RJ.pageSize) + 1

  for i = 1, RJ.pageSize do
    local row = RJ.rows[i]
    local listPos = startIndex + i - 1  -- position within the display list (1-based)
    local idx  -- actual DB index

    if indices then
      idx = indices[listPos]
    else
      idx = listPos
    end

    local entry = RelationshipsJukeboxDB.tracks[idx]

    if entry then
      row.index = idx  -- store real DB index so Play/Remove work correctly
      local isCurrent = (RJ.currentIndex == idx) or
        (RJ.currentPath and string.lower(RJ.currentPath) == string.lower(GetTrackPath(entry)))
      local prefix = isCurrent and ">" or (idx .. ".")
      row.label:SetText(prefix .. " " .. GetTrackDisplayName(entry))
      if isCurrent then
        row.label:SetTextColor(0.4, 1, 0.4)
      else
        row.label:SetTextColor(1, 0.82, 0)
      end
      -- Favorite star colour
      if row.fav and row.fav.text then
        if Playlist_Contains("Favorites", GetTrackPath(entry)) then
          row.fav.text:SetTextColor(1, 0.82, 0)   -- gold
          row.fav.text:SetText("*")
        else
          row.fav.text:SetTextColor(0.35, 0.35, 0.35)  -- dim
          row.fav.text:SetText("*")
        end
      end
      -- Disable Play button during 1-second cooldown (play or stop)
      if GetTime() < RJ.playCooldownUntil or GetTime() < RJ.stopCooldownUntil then
        row.play:Disable()
      else
        row.play:Enable()
      end
      row:Show()
    else
      row.index = nil
      row.label:SetText("")
      if row.fav and row.fav.text then row.fav.text:SetText("") end
      row:Hide()
    end
  end

  if RJ.pageText then
    local active = RelationshipsJukeboxDB and RelationshipsJukeboxDB.activePlaylist or "All"
    local pageText = "Page " .. RJ.page .. "/" .. totalPages .. "  Tracks: " .. total
    if active and active ~= "All" and active ~= "" then
      pageText = pageText .. "  [" .. PlaylistDisplayLabel(active) .. "]"
    end
    if RJ.searchFilter and RJ.searchFilter ~= "" then
      pageText = pageText .. " (search)"
    end
    RJ.pageText:SetText(pageText)
  end

  RefreshPlaybackButtons()
end

-----------------------------------------------------------------------
-- Track playback core
-----------------------------------------------------------------------
-- IsMusicPath and IsSfxPath are defined above (before PausePlayback/
-- ResumePlayback) so those functions can reference them.  See the
-- comments there for the full channel-routing strategy.

-- Legacy alias kept for clarity in comments / status messages
local function IsMp3Path(path)
  return string.find(string.lower(path or ""), "%.mp3$") ~= nil
end

PlayNextQueuedTrack = function()
  -- User queue takes priority over the shuffled playlist queue.
  -- Also works when autoplay is off, so "Add to Queue" always auto-advances.
  if Queue_Count() > 0 then
    local nextPath = Queue_PopHead()
    local idx = IndexForPath(nextPath)
    if idx then
      PlayTrack(idx, true)
      RecomputeView(); RefreshList()
      return
    end
    -- Path not found in library; fall through to try next
    RecomputeView(); RefreshList()
    return PlayNextQueuedTrack()
  end

  if not RJ.autoPlayEnabled or type(RJ.playQueue) ~= "table" then
    StopPlayback(true)
    RefreshPlaybackButtons()
    return
  end

  RJ.playQueuePosition = RJ.playQueuePosition + 1

  if RJ.playQueuePosition > Count(RJ.playQueue) then
    StopPlayback(true)
    SetStatus("Playlist finished.", 0.2, 1, 0.2)
    RefreshPlaybackButtons()
    return
  end

  local queueEntry = RJ.playQueue[RJ.playQueuePosition]
  PlayTrack(queueEntry, true)
end


PlayTrack = function(indexOrEntry, fromQueue)
  EnsureDB()

  -- 1-second cooldown to prevent spam-playing multiple tracks on top of each other
  -- Skip cooldown for auto-advancing from queue (fromQueue == true)
  if not fromQueue and (GetTime() < RJ.playCooldownUntil or GetTime() < RJ.stopCooldownUntil) then
    SetStatus("Cooldown active -- please wait...", 1, 1, 0.2)
    return nil
  end

  local entry
  if type(indexOrEntry) == "number" then
    entry = RelationshipsJukeboxDB.tracks[indexOrEntry]
  elseif type(indexOrEntry) == "table" then
    entry = indexOrEntry
  else
    entry = nil
  end

  local path = GetTrackPath(entry)
  local name = GetTrackDisplayName(entry)
  local duration = GetTrackDuration(entry)
  local ok

  if path == "" then
    SetStatus("Track not found.", 1, 0.2, 0.2)
    if fromQueue then
      PlayNextQueuedTrack()
    end
    return nil
  end

  -- Stop any currently playing jukebox track.
  if RJ.currentPath then
    -- KillAllSounds disables MasterSoundEffects and re-enables it on the
    -- next frame.  We must defer playing the new track until after
    -- the re-enable, so we pass the play logic as a callback.
    RJ.isPaused = false
    RJ.pausedRemaining = nil
    RJ.currentCanStop = false
    RJ.pollingForEnd = false
    RJ.pollTimer = 0
    RJ.consecutiveNotPlaying = 0

    -- Define what to do after sound is re-enabled: play the new track.
    local playAfterReenable = function()
      -- Ensure all sound is enabled so PlaySoundFile works.
      local sc2 = SetCVar or function() end
      pcall(sc2, "MasterSoundEffects", "1")

      if PlaySoundFile then
        PlaySoundFile(path, "Ambience")
        ok = 1
        RJ.currentCanStop = true   -- PlaySoundFile track
      else
        ok = nil
        RJ.currentCanStop = false
      end

      if ok then
        -- Suppress zone ambient music on the Music channel.
        SuppressZoneMusic()

        -- Set 1-second play cooldown to prevent spam
        RJ.playCooldownUntil = GetTime() + COOLDOWN_SECS

        if type(indexOrEntry) == "number" then
          RJ.currentIndex = indexOrEntry
        else
          RJ.currentIndex = nil
        end
        RJ.currentPath = path
        RJ.currentName = name
        RJ.currentDuration = duration
        RJ.trackStartTime = GetTime()

        if fromQueue then
          local queueLen = Count(RJ.playQueue or {})
          local posLabel = RJ.playQueuePosition .. "/" .. queueLen

          if duration and duration > 0 then
            RJ.trackEndTime = GetTime() + duration
            SetStatus("Playing " .. posLabel .. ": " .. name .. " (" .. FormatTime(duration) .. ")", 0.2, 1, 0.2)
          elseif RJ.currentCanStop and IsPlaying then
            RJ.trackEndTime = nil
            RJ.pollingForEnd = true
            RJ.pollTimer = GetTime() + RJ.pollStartDelay
            RJ.consecutiveNotPlaying = 0
            SetStatus("Playing " .. posLabel .. ": " .. name .. " (auto-advancing when track ends)", 0.2, 1, 0.2)
          else
            RJ.trackEndTime = GetTime() + FALLBACK_DURATION
            RJ.pollingForEnd = false
            SetStatus("Playing " .. posLabel .. ": " .. name .. " (~" .. FormatTime(FALLBACK_DURATION) .. " estimated)", 0.2, 1, 0.2)
          end
        else
          -- Single track play (not from queue)
          if duration and duration > 0 then
            RJ.trackEndTime = GetTime() + duration
            SetStatus("Playing: " .. name .. " (" .. FormatTime(duration) .. ")", 0.2, 1, 0.2)
          elseif RJ.currentCanStop and IsPlaying then
            RJ.trackEndTime = nil
            RJ.pollingForEnd = true
            RJ.pollTimer = GetTime() + RJ.pollStartDelay
            RJ.consecutiveNotPlaying = 0
            SetStatus("Playing: " .. name, 0.2, 1, 0.2)
          else
            RJ.trackEndTime = GetTime() + FALLBACK_DURATION
            RJ.pollingForEnd = false
            SetStatus("Playing: " .. name .. " (~" .. FormatTime(FALLBACK_DURATION) .. " estimated)", 0.2, 1, 0.2)
          end
        end
        RefreshPlaybackButtons()
        RefreshMiniPlayer()
        AnnounceNowPlaying(false)
      else
        SetStatus("Playback error for: " .. (name or "?"), 1, 0.2, 0.2)
      end
    end

    KillAllSounds(playAfterReenable)
    return ok
  end

  RJ.isPaused = false
  RJ.pausedRemaining = nil
  RJ.currentCanStop = false
  RJ.pollingForEnd = false
  RJ.pollTimer = 0
  RJ.consecutiveNotPlaying = 0

  -- Play the track using PlaySoundFile(path, "Ambience").
  -- ALL tracks use PlaySoundFile for playback.  To stop a playing
  -- track, use KillAllSounds() which disables MasterSoundEffects and
  -- re-enables it on the next frame.
  -- Ensure all sound is enabled so PlaySoundFile works.
  -- Zone events or other addons may have disabled it.
  local sc = SetCVar or function() end
  pcall(sc, "MasterSoundEffects", "1")

  if PlaySoundFile then
    PlaySoundFile(path, "Ambience")
    ok = 1
    RJ.currentCanStop = true   -- PlaySoundFile track
  else
    ok = nil
    RJ.currentCanStop = false
  end

  if ok then
    -- Suppress zone ambient music on the Music channel.
    SuppressZoneMusic()

    -- Set 1-second play cooldown to prevent spam
    RJ.playCooldownUntil = GetTime() + COOLDOWN_SECS

    if type(indexOrEntry) == "number" then
      RJ.currentIndex = indexOrEntry
    else
      RJ.currentIndex = nil
    end
    RJ.currentPath = path
    RJ.currentName = name
    RJ.currentDuration = duration
    RJ.trackStartTime = GetTime()

    if fromQueue then
      local queueLen = Count(RJ.playQueue or {})
      local posLabel = RJ.playQueuePosition .. "/" .. queueLen

      if duration and duration > 0 then
        -- Known duration: use timed advancement
        RJ.trackEndTime = GetTime() + duration
        SetStatus("Playing " .. posLabel .. ": " .. name .. " (" .. FormatTime(duration) .. ")", 0.2, 1, 0.2)
      elseif RJ.currentCanStop and IsPlaying then
        -- PlaySoundFile track with no duration: poll IsPlaying() to detect end
        RJ.trackEndTime = nil
        RJ.pollingForEnd = true
        RJ.pollTimer = GetTime() + RJ.pollStartDelay
        RJ.consecutiveNotPlaying = 0
        SetStatus("Playing " .. posLabel .. ": " .. name .. " (auto-advancing when track ends)", 0.2, 1, 0.2)
      else
        -- PlaySoundFile track with no duration and no IsPlaying: use fallback
        RJ.trackEndTime = GetTime() + FALLBACK_DURATION
        RJ.pollingForEnd = false
        SetStatus("Playing " .. posLabel .. ": " .. name .. " (~" .. FormatTime(FALLBACK_DURATION) .. " estimated)", 0.2, 1, 0.2)
      end
    else
      -- Single track play (not from queue)
      if duration and duration > 0 then
        RJ.trackEndTime = GetTime() + duration
        SetStatus("Playing: " .. name .. " (" .. FormatTime(duration) .. ")", 0.2, 1, 0.2)
      elseif RJ.currentCanStop and IsPlaying then
        RJ.trackEndTime = nil
        RJ.pollingForEnd = true
        RJ.pollTimer = GetTime() + RJ.pollStartDelay
        RJ.consecutiveNotPlaying = 0
        SetStatus("Playing: " .. name, 0.2, 1, 0.2)
      else
        RJ.trackEndTime = GetTime() + FALLBACK_DURATION
        RJ.pollingForEnd = false
        SetStatus("Playing: " .. name .. " (~" .. FormatTime(FALLBACK_DURATION) .. " estimated)", 0.2, 1, 0.2)
      end
    end
  else
    RJ.trackEndTime = nil
    RJ.pollingForEnd = false
    SetStatus("Could not play: " .. name .. "  (check filename/path)", 1, 0.2, 0.2)
    if fromQueue then
      -- Skip to next after a brief delay to avoid infinite recursion on bad files
      RJ.trackEndTime = GetTime() + 0.5
      RJ.pollingForEnd = false
    end
  end

  RefreshPlaybackButtons()
  if ok then AnnounceNowPlaying(false) end
  return ok
end

-- Skip to next track in queue
local function SkipTrack()
  if not RJ.autoPlayEnabled or type(RJ.playQueue) ~= "table" then
    return
  end
  -- 1-second cooldown on Skip to prevent music overlap
  if GetTime() < RJ.skipCooldownUntil then
    SetStatus("Skip cooldown -- please wait...", 1, 1, 0.2)
    return
  end
  RJ.skipCooldownUntil = GetTime() + COOLDOWN_SECS
  RJ.prevCooldownUntil = GetTime() + COOLDOWN_SECS
  -- Stop the jukebox track before advancing.  Use KillAllSounds
  -- with a callback so the next track plays AFTER sound is re-enabled.
  RJ.isPaused = false
  RJ.pausedRemaining = nil
  RJ.currentCanStop = false
  RJ.trackEndTime = nil
  RJ.pollingForEnd = false
  KillAllSounds(PlayNextQueuedTrack)
end


-- Go back to previous track in queue
local function PreviousTrack()
  if not RJ.autoPlayEnabled or type(RJ.playQueue) ~= "table" then
    return
  end
  -- 1-second cooldown on Previous to prevent music overlap
  if GetTime() < RJ.prevCooldownUntil then
    SetStatus("Previous cooldown -- please wait...", 1, 1, 0.2)
    return
  end
  RJ.prevCooldownUntil = GetTime() + COOLDOWN_SECS
  RJ.skipCooldownUntil = GetTime() + COOLDOWN_SECS
  if RJ.playQueuePosition <= 1 then
    RJ.playQueuePosition = 0
  else
    RJ.playQueuePosition = RJ.playQueuePosition - 2
  end
  -- Stop the jukebox track before going back.  Use KillAllSounds
  -- with a callback so the next track plays AFTER sound is re-enabled.
  RJ.isPaused = false
  RJ.pausedRemaining = nil
  RJ.currentCanStop = false
  RJ.trackEndTime = nil
  RJ.pollingForEnd = false
  KillAllSounds(PlayNextQueuedTrack)
end


-- Return DB indices for an arbitrary playlist identifier, using the same
-- semantics as ActivePlaylistIndices() but for a value you pass in
-- (rather than reading RelationshipsJukeboxDB.activePlaylist). Returns
-- nil when the value means "everything" ("All" / "" / nil).
local function IndicesForPlaylistValue(value)
  EnsurePlaylists(); EnsureDB()
  if not value or value == "" or value == "All" then return nil end
  local out = {}
  if value == "Favorites" then
    local set = Playlist_PathSet("Favorites")
    for i = 1, Count(RelationshipsJukeboxDB.tracks) do
      if set[string.lower(GetTrackPath(RelationshipsJukeboxDB.tracks[i]))] then
        table.insert(out, i)
      end
    end
    return out
  end
  if string.sub(value, 1, 7) == "folder:" then
    local folder = string.sub(value, 8)
    for i = 1, Count(RelationshipsJukeboxDB.tracks) do
      if GetTrackFolder(RelationshipsJukeboxDB.tracks[i]) == folder then
        table.insert(out, i)
      end
    end
    return out
  end
  if string.sub(value, 1, 5) == "user:" then
    local name = string.sub(value, 6)
    local set = Playlist_PathSet(name)
    for i = 1, Count(RelationshipsJukeboxDB.tracks) do
      if set[string.lower(GetTrackPath(RelationshipsJukeboxDB.tracks[i]))] then
        table.insert(out, i)
      end
    end
    return out
  end
  return nil
end
RJ.IndicesForPlaylistValue = IndicesForPlaylistValue

-- Append every track in a playlist to the user's Up Next queue.
-- value uses the same identifiers as the playlist dropdown.
local function Queue_AddPlaylist(value)
  local indices = IndicesForPlaylistValue(value)
  if indices == nil then
    -- "All": queue every DB track in order
    indices = {}
    for i = 1, Count(RelationshipsJukeboxDB.tracks) do
      table.insert(indices, i)
    end
  end
  local added = 0
  for i = 1, Count(indices) do
    local e = RelationshipsJukeboxDB.tracks[indices[i]]
    if e and Queue_Add(GetTrackPath(e)) then added = added + 1 end
  end
  return added
end
RJ.Queue_AddPlaylist = Queue_AddPlaylist

local function StartPlaylist(shuffle, playlistValue)
  EnsureDB()

  -- 1-second cooldown to prevent spam-starting playlists
  if GetTime() < RJ.playCooldownUntil or GetTime() < RJ.stopCooldownUntil then
    SetStatus("Cooldown active -- please wait...", 1, 1, 0.2)
    return
  end

  -- Resolve which tracks to play:
  --   * explicit playlistValue argument (e.g. from "Play all in <playlist>")
  --   * else the currently active view (ActivePlaylistIndices)
  --   * else every DB track ("All")
  local indices
  if playlistValue ~= nil then
    indices = IndicesForPlaylistValue(playlistValue)
  else
    indices = ActivePlaylistIndices()
  end

  local total
  if indices == nil then
    total = Count(RelationshipsJukeboxDB.tracks)
  else
    total = Count(indices)
  end
  if total == 0 then
    SetStatus("No tracks in this playlist.", 1, 0.2, 0.2)
    return
  end

  StopPlayback(true)

  RJ.playQueue = {}
  RJ.playQueuePosition = 0
  RJ.autoPlayEnabled = true
  RJ.shuffleMode = shuffle and true or false

  if indices == nil then
    for i = 1, total do table.insert(RJ.playQueue, i) end
  else
    for i = 1, total do table.insert(RJ.playQueue, indices[i]) end
  end

  if RJ.shuffleMode then
    ShuffleQueue(RJ.playQueue)
  end

  if playlistValue and playlistValue ~= "" then
    SetStatus("Playing " .. total .. " track(s) from: " .. PlaylistDisplayLabel(playlistValue), 0.2, 1, 0.2)
  end

  PlayNextQueuedTrack()
end
RJ.StartPlaylist = StartPlaylist


-- Recompute the visible track list from (activePlaylist ∩ searchFilter) and
-- store it in RJ.filteredIndices.  When both are inactive, RJ.filteredIndices
-- is set to nil, which RefreshList treats as "show every DB track in order".
function RecomputeView()
  EnsureDB()
  local base = ActivePlaylistIndices()
  local query = Trim(RJ.searchFilter or "")

  if query == "" then
    RJ.filteredIndices = base
    return
  end

  local lower = string.lower(query)
  local out = {}
  if base then
    for i = 1, Count(base) do
      local e = RelationshipsJukeboxDB.tracks[base[i]]
      if e and string.find(string.lower(GetTrackDisplayName(e)), lower, 1, true) then
        table.insert(out, base[i])
      end
    end
  else
    for i = 1, Count(RelationshipsJukeboxDB.tracks) do
      local e = RelationshipsJukeboxDB.tracks[i]
      if e and string.find(string.lower(GetTrackDisplayName(e)), lower, 1, true) then
        table.insert(out, i)
      end
    end
  end
  RJ.filteredIndices = out
end

local function PerformSearch()
  EnsureDB()
  local query = Trim(RJ.searchInput and RJ.searchInput:GetText() or "")

  if query == "" then
    RJ.searchFilter = ""
    RJ.page = 1
    RecomputeView()
    RefreshList()
    SetStatus("Search cleared.", 0.2, 1, 0.2)
    return
  end

  RJ.searchFilter = query
  RJ.page = 1
  RecomputeView()
  RefreshList()

  local matchCount = Count(RJ.filteredIndices or {})
  if RJ.filteredIndices == nil then
    matchCount = Count(RelationshipsJukeboxDB.tracks)
  end
  if matchCount > 0 then
    SetStatus("Found " .. matchCount .. " track(s) matching \"" .. query .. "\"", 0.2, 1, 0.2)
  else
    SetStatus("No tracks found matching \"" .. query .. "\"", 1, 0.2, 0.2)
  end
end

local function ClearSearch()
  RJ.searchFilter = ""
  if RJ.searchInput then RJ.searchInput:SetText("") end
  RJ.page = 1
  RecomputeView()
  RefreshList()
  SetStatus("Search cleared.", 0.2, 1, 0.2)
end

-- Called by the playlist dropdown when the user picks a new view.
local function SetActivePlaylist(value)
  EnsurePlaylists()
  RelationshipsJukeboxDB.activePlaylist = value or "All"
  RJ.page = 1
  RecomputeView()
  RefreshList()
  if RJ.playlistDropdownText then
    RJ.playlistDropdownText:SetText(PlaylistDisplayLabel(value))
  end
  SetStatus("View: " .. PlaylistDisplayLabel(value), 0.6, 0.9, 1)
end
RJ.SetActivePlaylist = SetActivePlaylist



local function RemoveTrack(index)
  EnsureDB()
  if RelationshipsJukeboxDB.tracks[index] then
    local removed = GetTrackDisplayName(RelationshipsJukeboxDB.tracks[index])
    table.remove(RelationshipsJukeboxDB.tracks, index)
    if RJ.currentIndex == index then
      StopPlayback(true)
    end
    -- Re-run search if a filter is active so filteredIndices stays in sync
    if RJ.searchFilter and RJ.searchFilter ~= "" then
      PerformSearch()
    else
      RefreshList()
    end
    SetStatus("Removed: " .. removed, 1, 0.82, 0)
  end
end

-----------------------------------------------------------------------
-- Button helper
-----------------------------------------------------------------------
local function MakeButton(name, parent, width, height, text)
  local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
  b:SetWidth(width)
  b:SetHeight(height)
  b:SetText(text)
  return b
end

-----------------------------------------------------------------------
-- Main GUI: track list window
-- Layout (total height 600):
--   TOP:  title/subtitle/input         (~106 px from top)
--   MIDDLE: track list rows (12/page)   (~336 px)
--   Row 1: Playback controls           (<< Prev, Skip >>, Play All, Shuffle, Stop)
--   Row 2: Page navigation             (Prev, Page X/Y, Next)
--   Slash help text                       (~20 px)
--   Status bar                            (~20 px)
--   Bottom padding                        (~18 px)
-----------------------------------------------------------------------

-----------------------------------------------------------------------
-- New-playlist StaticPopup
--
-- When the user picks "New playlist..." from either the header dropdown or a
-- row's right-click menu, we ask for a name.  If RJ._pendingAddPath is set
-- when the popup is confirmed, that path is added to the freshly created
-- playlist so the row-context flow "Add to > New playlist..." works in one
-- step.
-----------------------------------------------------------------------
StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs["RJ_NEW_PLAYLIST"] = {
  text = "New playlist name:",
  button1 = "Create",
  button2 = "Cancel",
  hasEditBox = 1,
  maxLetters = 32,
  OnShow = function()
    -- 'this' is the dialog frame in 1.12 OnShow
    local eb = getglobal(this:GetName() .. "EditBox")
    if eb then eb:SetText(""); eb:SetFocus() end
  end,
  OnAccept = function()
    -- In 1.12, 'this' inside OnAccept is the OK button, not the dialog.
    -- Walk up to the parent dialog to find the edit box.
    local dialog = this
    if this and this.GetParent then
      local p = this:GetParent()
      if p and p.GetName and p:GetName() and string.find(p:GetName(), "^StaticPopup%d") then
        dialog = p
      end
    end
    local eb = dialog and getglobal(dialog:GetName() .. "EditBox") or nil
    local name = eb and Trim(eb:GetText() or "") or ""
    if name == "" then
      SetStatus("Playlist name cannot be empty.", 1, 0.4, 0.4)
      return
    end
    if name == "All" or name == "Favorites" then
      SetStatus("That playlist name is reserved.", 1, 0.4, 0.4)
      return
    end
    EnsurePlaylists()
    local created = false
    if type(RelationshipsJukeboxDB.playlists[name]) ~= "table" then
      RelationshipsJukeboxDB.playlists[name] = { paths = {} }
      created = true
    end
    if RJ._pendingAddPath and RJ._pendingAddPath ~= "" then
      Playlist_AddPath(name, RJ._pendingAddPath)
      SetStatus("Added track to playlist: " .. name, 0.2, 1, 0.2)
      RJ._pendingAddPath = nil
    else
      if created then
        SetStatus("Created playlist: " .. name, 0.2, 1, 0.2)
      else
        SetStatus("Playlist already exists: " .. name, 1, 0.82, 0)
      end
    end
    -- Switch view to the new playlist so the user sees it immediately.
    if RJ.SetActivePlaylist then
      RJ.SetActivePlaylist("user:" .. name)
    else
      RecomputeView(); RefreshList()
    end
  end,
  EditBoxOnEnterPressed = function()
    -- 'this' is the edit box; click the Accept button so OnAccept runs
    -- with 'this' bound to Button1 (matches the normal click path).
    local parent = this:GetParent()
    if not parent then return end
    local btn = getglobal(parent:GetName() .. "Button1")
    if btn then btn:Click() end
  end,
  EditBoxOnEscapePressed = function() this:GetParent():Hide() end,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
}

local function PromptNewPlaylist(pendingPath)
  RJ._pendingAddPath = pendingPath
  if StaticPopup_Show then StaticPopup_Show("RJ_NEW_PLAYLIST") end
end

-----------------------------------------------------------------------
-- Row right-click context menu
--
-- Uses UIDropDownMenu in MENU mode.  Level-1 shows Play / favorite toggle /
-- "Add to playlist >" / Remove.  Level-2 lists every user playlist plus a
-- "New playlist..." action.  1.12 signals which submenu to populate via the
-- UIDROPDOWNMENU_MENU_LEVEL and UIDROPDOWNMENU_MENU_VALUE globals inside the
-- initialize function -- there is no per-button callback for submenu items.
-----------------------------------------------------------------------
local function EnsureRowContextMenu()
  if RJ.rowContextMenu then return RJ.rowContextMenu end
  local m = CreateFrame("Frame", "RJRowContextMenu", UIParent, "UIDropDownMenuTemplate")
  m.displayMode = "MENU"
  RJ.rowContextMenu = m
  return m
end

local function ShowRowContextMenu(row)
  if not row or not row.index then return end
  local entry = RelationshipsJukeboxDB.tracks[row.index]
  if not entry then return end

  RJ._contextPath = GetTrackPath(entry)
  RJ._contextIndex = row.index

  local menu = EnsureRowContextMenu()
  local initFn = function()
    local info
    local level = UIDROPDOWNMENU_MENU_LEVEL or 1
    local value = UIDROPDOWNMENU_MENU_VALUE

    if level == 2 and value == "ADDTO" then
      local names = GetUserPlaylists()
      for i = 1, Count(names) do
        local pname = names[i]
        info = {}
        info.text = pname
        info.notCheckable = 1
        info.func = function()
          local added = Playlist_AddPath(pname, RJ._contextPath)
          if added then
            SetStatus("Added to " .. pname, 0.2, 1, 0.2)
          else
            SetStatus("Already in " .. pname, 1, 0.82, 0)
          end
          if CloseDropDownMenus then CloseDropDownMenus() end
        end
        UIDropDownMenu_AddButton(info, 2)
      end
      info = {}
      info.text = "New playlist..."
      info.notCheckable = 1
      info.func = function()
        PromptNewPlaylist(RJ._contextPath)
        if CloseDropDownMenus then CloseDropDownMenus() end
      end
      UIDropDownMenu_AddButton(info, 2)
      return
    end

    -- Level 1: primary actions
    info = {}
    info.text = GetTrackDisplayName(entry)
    info.isTitle = 1
    info.notCheckable = 1
    UIDropDownMenu_AddButton(info, 1)

    info = {}
    info.text = "Play"
    info.notCheckable = 1
    info.func = function() PlayTrack(RJ._contextIndex, false); if CloseDropDownMenus then CloseDropDownMenus() end end
    UIDropDownMenu_AddButton(info, 1)

    info = {}
    info.text = "Play next"
    info.notCheckable = 1
    info.func = function()
      Queue_PlayNext(RJ._contextPath)
      SetStatus("Queued next: " .. GetTrackDisplayName(entry), 0.2, 1, 0.2)
      if RelationshipsJukeboxDB.activePlaylist == "Queue" then
        RecomputeView(); RefreshList()
      end
      if CloseDropDownMenus then CloseDropDownMenus() end
    end
    UIDropDownMenu_AddButton(info, 1)

    info = {}
    info.text = "Add to queue"
    info.notCheckable = 1
    info.func = function()
      Queue_Add(RJ._contextPath)
      SetStatus("Added to queue (" .. Queue_Count() .. "): " .. GetTrackDisplayName(entry), 0.2, 1, 0.2)
      if RelationshipsJukeboxDB.activePlaylist == "Queue" then
        RecomputeView(); RefreshList()
      end
      if CloseDropDownMenus then CloseDropDownMenus() end
    end
    UIDropDownMenu_AddButton(info, 1)

    info = {}
    if Playlist_Contains("Favorites", RJ._contextPath) then
      info.text = "Remove from Favorites"
    else
      info.text = "Add to Favorites"
    end
    info.notCheckable = 1
    info.func = function()
      ToggleFavorite(RJ._contextPath)
      RecomputeView(); RefreshList()
      if CloseDropDownMenus then CloseDropDownMenus() end
    end
    UIDropDownMenu_AddButton(info, 1)

    info = {}
    info.text = "Add to playlist"
    info.hasArrow = 1
    info.notCheckable = 1
    info.value = "ADDTO"
    UIDropDownMenu_AddButton(info, 1)

    -- Also list currently-playlists-containing-this-track so user can quickly remove
    local user = GetUserPlaylists()
    local any = false
    for i = 1, Count(user) do
      if Playlist_Contains(user[i], RJ._contextPath) then
        if not any then
          info = {}
          info.text = "Remove from"
          info.isTitle = 1
          info.notCheckable = 1
          UIDropDownMenu_AddButton(info, 1)
          any = true
        end
        local pname = user[i]
        info = {}
        info.text = "  " .. pname
        info.notCheckable = 1
        info.func = function()
          Playlist_RemovePath(pname, RJ._contextPath)
          SetStatus("Removed from " .. pname, 1, 0.82, 0)
          RecomputeView(); RefreshList()
          if CloseDropDownMenus then CloseDropDownMenus() end
        end
        UIDropDownMenu_AddButton(info, 1)
      end
    end

    info = {}
    info.text = ""
    info.disabled = 1
    info.notCheckable = 1
    UIDropDownMenu_AddButton(info, 1)

    -- If viewing the Queue, offer a quick "Remove from queue" for this track.
    if RelationshipsJukeboxDB.activePlaylist == "Queue" then
      info = {}
      info.text = "Remove from queue"
      info.notCheckable = 1
      info.func = function()
        EnsureUserQueue()
        local paths = RelationshipsJukeboxDB.userQueue.paths
        local target = string.lower(RJ._contextPath or "")
        for i = 1, Count(paths) do
          if string.lower(paths[i]) == target then
            table.remove(paths, i)
            break
          end
        end
        SetStatus("Removed from queue.", 1, 0.82, 0)
        RecomputeView(); RefreshList()
        if CloseDropDownMenus then CloseDropDownMenus() end
      end
      UIDropDownMenu_AddButton(info, 1)
    end

    info = {}
    info.text = "Remove from library"
    info.notCheckable = 1
    info.func = function() RemoveTrack(RJ._contextIndex); if CloseDropDownMenus then CloseDropDownMenus() end end
    UIDropDownMenu_AddButton(info, 1)

    info = {}
    info.text = "Cancel"
    info.notCheckable = 1
    info.func = function() if CloseDropDownMenus then CloseDropDownMenus() end end
    UIDropDownMenu_AddButton(info, 1)
  end

  UIDropDownMenu_Initialize(menu, initFn, "MENU")
  ToggleDropDownMenu(1, nil, menu, "cursor", 0, 0)
end

-----------------------------------------------------------------------
-- Simple tooltip helper -- attaches title + optional body to any frame.
-----------------------------------------------------------------------
local function AttachTooltip(frame, title, body)
  if not frame then return end
  frame:SetScript("OnEnter", function()
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1)
    if body then GameTooltip:AddLine(body, 0.8, 0.8, 0.8, 1) end
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
RJ.AttachTooltip = AttachTooltip

-----------------------------------------------------------------------
-- Row "+" button: dedicated Add-to-playlist popup menu.
-- Anchors under the "+" button, lists every user playlist, plus a
-- "New playlist..." entry that opens the create-playlist popup with
-- this track queued for insertion.
-----------------------------------------------------------------------
local function EnsureAddToPlaylistMenu()
  if RJ.addToPlaylistMenu then return RJ.addToPlaylistMenu end
  local m = CreateFrame("Frame", "RJAddToPlaylistMenu", UIParent, "UIDropDownMenuTemplate")
  m.displayMode = "MENU"
  RJ.addToPlaylistMenu = m
  return m
end

function ShowAddToPlaylistMenu(row, anchor)
  if not row or not row.index then return end
  local entry = RelationshipsJukeboxDB.tracks[row.index]
  if not entry then return end
  RJ._contextPath = GetTrackPath(entry)
  RJ._contextIndex = row.index

  local menu = EnsureAddToPlaylistMenu()
  local initFn = function()
    local info
    info = {}
    info.text = "Add to playlist"
    info.isTitle = 1
    info.notCheckable = 1
    UIDropDownMenu_AddButton(info, 1)

    local names = GetUserPlaylists()
    if Count(names) == 0 then
      info = {}
      info.text = "(no playlists yet)"
      info.disabled = 1
      info.notCheckable = 1
      UIDropDownMenu_AddButton(info, 1)
    else
      for i = 1, Count(names) do
        local pname = names[i]
        local already = Playlist_Contains(pname, RJ._contextPath)
        info = {}
        info.text = already and (pname .. "  (already in)") or pname
        info.notCheckable = 1
        info.disabled = already and 1 or nil
        info.func = function()
          local added = Playlist_AddPath(pname, RJ._contextPath)
          if added then
            SetStatus("Added to " .. pname, 0.2, 1, 0.2)
          else
            SetStatus("Already in " .. pname, 1, 0.82, 0)
          end
          RecomputeView(); RefreshList()
          if CloseDropDownMenus then CloseDropDownMenus() end
        end
        UIDropDownMenu_AddButton(info, 1)
      end
    end

    info = {}; info.text = ""; info.disabled = 1; info.notCheckable = 1
    UIDropDownMenu_AddButton(info, 1)

    info = {}
    info.text = "Play next (queue)"
    info.notCheckable = 1
    info.func = function()
      Queue_PlayNext(RJ._contextPath)
      SetStatus("Queued next.", 0.2, 1, 0.2)
      if RelationshipsJukeboxDB.activePlaylist == "Queue" then RecomputeView(); RefreshList() end
      if CloseDropDownMenus then CloseDropDownMenus() end
    end
    UIDropDownMenu_AddButton(info, 1)

    info = {}
    info.text = "Add to queue (" .. Queue_Count() .. ")"
    info.notCheckable = 1
    info.func = function()
      Queue_Add(RJ._contextPath)
      SetStatus("Added to queue (" .. Queue_Count() .. ").", 0.2, 1, 0.2)
      if RelationshipsJukeboxDB.activePlaylist == "Queue" then RecomputeView(); RefreshList() end
      if CloseDropDownMenus then CloseDropDownMenus() end
    end
    UIDropDownMenu_AddButton(info, 1)

    info = {}
    info.text = "* Toggle Favorite"
    info.notCheckable = 1
    info.func = function()
      ToggleFavorite(RJ._contextPath)
      RecomputeView(); RefreshList()
      if CloseDropDownMenus then CloseDropDownMenus() end
    end
    UIDropDownMenu_AddButton(info, 1)

    info = {}
    info.text = "New playlist..."
    info.notCheckable = 1
    info.func = function()
      PromptNewPlaylist(RJ._contextPath)
      if CloseDropDownMenus then CloseDropDownMenus() end
    end
    UIDropDownMenu_AddButton(info, 1)
  end

  UIDropDownMenu_Initialize(menu, initFn, "MENU")
  ToggleDropDownMenu(1, nil, menu, anchor or "cursor", 0, 0)
end
RJ.ShowAddToPlaylistMenu = ShowAddToPlaylistMenu


local function CreateRow(parent, i)
  local row = CreateFrame("Frame", nil, parent)
  row:SetWidth(680)
  row:SetHeight(27)
  row:EnableMouse(true)

  -- Right-click anywhere on the row opens the context menu.
  row:SetScript("OnMouseUp", function()
    if arg1 == "RightButton" then
      ShowRowContextMenu(row)
    end
  end)

  -- Row background (alternating shade) + explicit border textures (some
  -- 1.12 clients don't render SetBackdrop borders on anonymous child frames).
  row.bg = row:CreateTexture(nil, "BACKGROUND")
  row.bg:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
  row.bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)

  if math.mod(i, 2) == 1 then
    row.bg:SetTexture(0.10, 0.10, 0.10, 0.82)
  else
    row.bg:SetTexture(0.06, 0.06, 0.06, 0.78)
  end
  row.baseColor = { r = math.mod(i, 2) == 1 and 0.10 or 0.06,
                    g = math.mod(i, 2) == 1 and 0.10 or 0.06,
                    b = math.mod(i, 2) == 1 and 0.10 or 0.06,
                    a = math.mod(i, 2) == 1 and 0.82 or 0.78 }

  row.borderTop = row:CreateTexture(nil, "BORDER")
  row.borderTop:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  row.borderTop:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
  row.borderTop:SetHeight(1)
  row.borderTop:SetTexture(0.45, 0.45, 0.45, 0.95)

  row.borderBottom = row:CreateTexture(nil, "BORDER")
  row.borderBottom:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
  row.borderBottom:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
  row.borderBottom:SetHeight(1)
  row.borderBottom:SetTexture(0.45, 0.45, 0.45, 0.95)

  row.borderLeft = row:CreateTexture(nil, "BORDER")
  row.borderLeft:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  row.borderLeft:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
  row.borderLeft:SetWidth(1)
  row.borderLeft:SetTexture(0.45, 0.45, 0.45, 0.95)

  row.borderRight = row:CreateTexture(nil, "BORDER")
  row.borderRight:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
  row.borderRight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
  row.borderRight:SetWidth(1)
  row.borderRight:SetTexture(0.45, 0.45, 0.45, 0.95)

  -- Favorite star.  Turtle WoW / 1.12 fonts don't reliably render Unicode
  -- stars, so we use an ASCII "*" and colour it gold when the track is in
  -- Favorites (grey otherwise).  Clicking toggles the favorite state.
  row.fav = CreateFrame("Button", nil, row)
  row.fav:SetWidth(18)
  row.fav:SetHeight(18)
  row.fav:SetPoint("LEFT", row, "LEFT", 6, 0)
  row.fav.text = row.fav:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.fav.text:SetAllPoints()
  row.fav.text:SetJustifyH("CENTER")
  row.fav.text:SetText("*")
  row.fav:SetScript("OnClick", function()
    if not row.index then return end
    local entry = RelationshipsJukeboxDB.tracks[row.index]
    if not entry then return end
    local nowFav = ToggleFavorite(GetTrackPath(entry))
    if nowFav then
      SetStatus("Added to Favorites: " .. GetTrackDisplayName(entry), 1, 0.82, 0)
    else
      SetStatus("Removed from Favorites: " .. GetTrackDisplayName(entry), 0.7, 0.7, 0.7)
    end
    RecomputeView()
    RefreshList()
  end)
  AttachTooltip(row.fav, "Favorite", "Click to add/remove from Favorites.")

  row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.label:SetPoint("LEFT", row.fav, "RIGHT", 6, 0)
  row.label:SetWidth(444)
  row.label:SetJustifyH("LEFT")
  row.label:SetText("")

  -- "+" button: opens a menu listing every user playlist so the user can
  -- add this track without going through the right-click context menu.
  row.addTo = MakeButton(nil, row, 22, 20, "+")
  row.addTo:SetPoint("RIGHT", row, "RIGHT", -156, 0)
  row.addTo:SetScript("OnClick", function()
    if not row.index then return end
    ShowAddToPlaylistMenu(row, row.addTo)
  end)
  AttachTooltip(row.addTo, "Add to playlist",
    "Add this track to one of your playlists (or create a new one).")

  row.play = MakeButton(nil, row, 70, 20, "Play")
  row.play:SetPoint("RIGHT", row, "RIGHT", -80, 0)
  row.play:SetScript("OnClick", function()
    if row.index then PlayTrack(row.index, false) end
  end)
  AttachTooltip(row.play, "Play track", "Play this song immediately.")

  row.remove = MakeButton(nil, row, 70, 20, "Remove")
  row.remove:SetPoint("RIGHT", row, "RIGHT", -6, 0)
  row.remove:SetScript("OnClick", function()
    if row.index then RemoveTrack(row.index) end
  end)
  AttachTooltip(row.remove, "Remove from library",
    "Removes this track from the addon's library. Files on disk are not deleted; re-run GeneratePlaylist.bat to re-import.")

  return row
end


-- Options subpanel that lives inside the main jukebox frame.  Exposes
-- controls for the Now-Playing announce feature: an on/off checkbox and
-- a channel dropdown (Auto / Party / Raid / Guild / Say / Yell).
local ANNOUNCE_CHANNEL_ORDER = { "AUTO", "PARTY", "RAID", "GUILD", "SAY", "YELL" }
local ANNOUNCE_CHANNEL_LABEL = {
  AUTO  = "Auto (Raid > Party)",
  PARTY = "Party",
  RAID  = "Raid",
  GUILD = "Guild",
  SAY   = "Say",
  YELL  = "Yell",
}

function CreateAnnounceOptionsPanel(parent)
  if RJ.optionsFrame then return RJ.optionsFrame end
  EnsureAnnounceSettings()

  local p = CreateFrame("Frame", "RJOptionsFrame", parent)
  RJ.optionsFrame = p
  p:SetWidth(360)
  p:SetHeight(210)
  p:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, -46)
  p:SetFrameStrata("DIALOG")
  p:EnableMouse(true)
  p:Hide()

  if p.SetBackdrop then
    p:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 24,
      insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    p:SetBackdropColor(0, 0, 0, 0.95)
  end

  local title = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", p, "TOP", 0, -14)
  title:SetText("Announce Now Playing")

  local closeBtn = MakeButton(nil, p, 22, 20, "X")
  closeBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -10)
  closeBtn:SetScript("OnClick", function() p:Hide() end)

  -- Enable checkbox
  local cb = CreateFrame("CheckButton", "RJAnnounceEnable", p, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", p, "TOPLEFT", 18, -44)
  cb:SetWidth(24); cb:SetHeight(24)
  local cbLabel = getglobal and getglobal(cb:GetName() .. "Text") or nil
  if cbLabel then cbLabel:SetText("Auto-announce when a new track starts") end
  cb:SetScript("OnClick", function()
    EnsureAnnounceSettings()
    local checked = cb:GetChecked() and true or false
    RelationshipsJukeboxDB.announce.enabled = checked
    if checked then
      SetStatus("Auto-announce ON", 0.2, 1, 0.2)
    else
      SetStatus("Auto-announce OFF", 0.7, 0.7, 0.7)
    end
  end)
  RJ.announceCheckbox = cb

  -- Channel dropdown
  local chanLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  chanLabel:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 4, -14)
  chanLabel:SetText("Send to:")

  local dd = CreateFrame("Frame", "RJAnnounceChannelDD", p, "UIDropDownMenuTemplate")
  dd:SetPoint("LEFT", chanLabel, "RIGHT", -6, -2)
  RJ.announceChannelDD = dd

  local function ChooseChannel(value)
    EnsureAnnounceSettings()
    RelationshipsJukeboxDB.announce.channel = value
    if UIDropDownMenu_SetSelectedValue then
      UIDropDownMenu_SetSelectedValue(dd, value)
    end
    if UIDropDownMenu_SetText then
      UIDropDownMenu_SetText(ANNOUNCE_CHANNEL_LABEL[value] or value, dd)
    end
    SetStatus("Announce channel: " .. (ANNOUNCE_CHANNEL_LABEL[value] or value), 0.2, 1, 0.2)
  end

  local function InitChannelDD()
    local info
    for i = 1, Count(ANNOUNCE_CHANNEL_ORDER) do
      local v = ANNOUNCE_CHANNEL_ORDER[i]
      info = {}
      info.text = ANNOUNCE_CHANNEL_LABEL[v] or v
      info.value = v
      info.checked = (RelationshipsJukeboxDB.announce.channel == v)
      info.func = function() ChooseChannel(this and this.value or v) end
      UIDropDownMenu_AddButton(info)
    end
  end
  UIDropDownMenu_Initialize(dd, InitChannelDD)
  UIDropDownMenu_SetWidth(160, dd)

  -- Test / manual announce button
  local testBtn = MakeButton(nil, p, 130, 22, "Announce Now")
  testBtn:SetPoint("TOPLEFT", chanLabel, "BOTTOMLEFT", -4, -14)
  testBtn:SetScript("OnClick", function()
    AnnounceNowPlaying(true)
  end)
  AttachTooltip(testBtn, "Announce Now",
    "Send the currently playing track to the selected channel right now.  Works even when auto-announce is off.")

  local help = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  help:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 16, 14)
  help:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -16, 14)
  help:SetJustifyH("LEFT")
  help:SetText("Slash: /rj np [party|raid|guild|say|yell|auto]\nAuto mode picks Raid if in a raid, else Party.")
  if help.SetTextColor then help:SetTextColor(0.8, 0.8, 0.8) end

  -- Sync visible controls with saved settings whenever the panel opens.
  RJ.RefreshOptionsPanel = function()
    EnsureAnnounceSettings()
    local a = RelationshipsJukeboxDB.announce
    if cb.SetChecked then cb:SetChecked(a.enabled) end
    if UIDropDownMenu_SetSelectedValue then
      UIDropDownMenu_SetSelectedValue(dd, a.channel)
    end
    if UIDropDownMenu_SetText then
      UIDropDownMenu_SetText(ANNOUNCE_CHANNEL_LABEL[a.channel] or a.channel, dd)
    end
  end
  RJ.RefreshOptionsPanel()

  return p
end

local function CreateUI()
  if RJ.frame then return end

  local f = CreateFrame("Frame", ADDON_NAME .. "Frame", UIParent)
  RJ.frame = f
  f:SetWidth(730)
  f:SetHeight(600)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetClampedToScreen(true)
  f:SetScript("OnDragStart", function() f:StartMoving() end)
  f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
  f:Hide()

  if f.SetBackdrop then
    f:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    f:SetBackdropColor(0, 0, 0, 0.85)
  end

  -- Title bar
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOP", f, "TOP", 0, -16)
  title:SetText("Relationships Jukebox")

  local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  subtitle:SetPoint("TOP", title, "BOTTOM", 0, -18)
  subtitle:SetText("Put Your Sound Files In The \"RelationshipsJukeBox\\Media\" Folder Then Run \"GeneratePlaylist.bat\"")

  local close = MakeButton(nil, f, 28, 22, "X")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -14)
  close:SetScript("OnClick", function() f:Hide() end)

  -- Options button (opens the Announce settings panel).
  local optionsBtn = MakeButton(nil, f, 70, 22, "Options")
  optionsBtn:SetPoint("RIGHT", close, "LEFT", -6, 0)
  optionsBtn:SetScript("OnClick", function()
    if RJ.optionsFrame then
      if RJ.optionsFrame:IsShown() then
        RJ.optionsFrame:Hide()
      else
        if RJ.RefreshOptionsPanel then RJ.RefreshOptionsPanel() end
        RJ.optionsFrame:Show()
      end
    end
  end)
  AttachTooltip(optionsBtn, "Options", "Configure the Now Playing announce channel and toggle auto-announce on or off.")
  RJ.optionsButton = optionsBtn

  -- ----- Options panel (Announce settings) --------------------------
  CreateAnnounceOptionsPanel(f)

  -- Search input row
  local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  searchLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -76)
  searchLabel:SetText("Search")

  local searchInput = CreateFrame("EditBox", ADDON_NAME .. "SearchInput", f, "InputBoxTemplate")
  RJ.searchInput = searchInput
  searchInput:SetWidth(210)
  searchInput:SetHeight(20)
  searchInput:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
  searchInput:SetAutoFocus(false)
  searchInput:SetTextInsets(6, 6, 0, 0)
  searchInput:SetText("")
  searchInput:SetScript("OnEscapePressed", function()
    searchInput:ClearFocus()
  end)
  searchInput:SetScript("OnEnterPressed", function()
    searchInput:ClearFocus()
    PerformSearch()
  end)

  local searchBtn = MakeButton(nil, f, 70, 22, "Search")
  searchBtn:SetPoint("LEFT", searchInput, "RIGHT", 10, 0)
  searchBtn:SetScript("OnClick", PerformSearch)
  AttachTooltip(searchBtn, "Search", "Filter the visible tracks by name.")

  local clearBtn = MakeButton(nil, f, 60, 22, "Clear")
  clearBtn:SetPoint("LEFT", searchBtn, "RIGHT", 8, 0)
  clearBtn:SetScript("OnClick", ClearSearch)
  AttachTooltip(clearBtn, "Clear search", "Reset the search box and show all matching tracks in the current playlist.")

  -- ----- Header playlist dropdown ---------------------------------------
  -- Lets the user switch the visible list between:
  --   * All Tracks
  --   * Favorites (built-in playlist)
  --   * one auto-playlist per subfolder of Media\
  --   * user-defined playlists
  -- Also exposes "New playlist..." for creating an empty one on the spot.
  local viewLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  viewLabel:SetPoint("LEFT", clearBtn, "RIGHT", 12, 0)
  viewLabel:SetText("View:")

  local dd = CreateFrame("Frame", "RJPlaylistDropDown", f, "UIDropDownMenuTemplate")
  RJ.playlistDropdown = dd
  dd:SetPoint("LEFT", viewLabel, "RIGHT", -8, -2)

  local function InitPlaylistDropdown()
    local info
    local level = UIDROPDOWNMENU_MENU_LEVEL or 1
    local active = RelationshipsJukeboxDB.activePlaylist or "All"

    -- Submenu: "Play all in playlist" branch
    if level == 2 and (UIDROPDOWNMENU_MENU_VALUE == "PLAYALL"
                    or UIDROPDOWNMENU_MENU_VALUE == "QUEUEALL") then
      local isQueue = (UIDROPDOWNMENU_MENU_VALUE == "QUEUEALL")
      local entries = {}
      table.insert(entries, { label = "All Tracks", value = "All" })
      table.insert(entries, { label = "* Favorites", value = "Favorites" })
      local folders = GetFolderPlaylists()
      for i = 1, Count(folders) do
        table.insert(entries, { label = "[folder] " .. folders[i], value = "folder:" .. folders[i] })
      end
      local user = GetUserPlaylists()
      for i = 1, Count(user) do
        table.insert(entries, { label = user[i], value = "user:" .. user[i] })
      end
      for i = 1, Count(entries) do
        local e = entries[i]
        info = {}
        info.text = e.label
        info.notCheckable = 1
        if isQueue then
          info.func = function()
            local n = Queue_AddPlaylist(e.value)
            SetStatus("Queued " .. n .. " track(s) from: " .. PlaylistDisplayLabel(e.value), 0.2, 1, 0.2)
            if RelationshipsJukeboxDB.activePlaylist == "Queue" then
              RecomputeView(); RefreshList()
            end
            if CloseDropDownMenus then CloseDropDownMenus() end
          end
        else
          info.func = function()
            StartPlaylist(false, e.value)
            if CloseDropDownMenus then CloseDropDownMenus() end
          end
        end
        UIDropDownMenu_AddButton(info, 2)
      end
      return
    end

    -- Submenu: "Delete playlist" branch
    if level == 2 and UIDROPDOWNMENU_MENU_VALUE == "DELETE" then
      local names = GetUserPlaylists()
      for i = 1, Count(names) do
        local pname = names[i]
        info = {}
        info.text = pname
        info.notCheckable = 1
        info.func = function()
          RelationshipsJukeboxDB.playlists[pname] = nil
          if RelationshipsJukeboxDB.activePlaylist == ("user:" .. pname) then
            RelationshipsJukeboxDB.activePlaylist = "All"
          end
          SetStatus("Deleted playlist: " .. pname, 1, 0.82, 0)
          RecomputeView(); RefreshList()
          if RJ.playlistDropdownText then
            RJ.playlistDropdownText:SetText(PlaylistDisplayLabel(RelationshipsJukeboxDB.activePlaylist))
          end
          if CloseDropDownMenus then CloseDropDownMenus() end
        end
        UIDropDownMenu_AddButton(info, 2)
      end
      return
    end

    -- Primary level
    local function Add(text, value)
      info = {}
      info.text = text
      info.value = value
      info.checked = (active == value) and 1 or nil
      info.func = function()
        SetActivePlaylist(value)
        if CloseDropDownMenus then CloseDropDownMenus() end
      end
      UIDropDownMenu_AddButton(info, 1)
    end

    Add("All Tracks", "All")
    Add("* Favorites", "Favorites")
    Add("Up Next (Queue) [" .. Queue_Count() .. "]", "Queue")

    local folders = GetFolderPlaylists()
    if Count(folders) > 0 then
      info = {}; info.text = "-- Folders --"; info.isTitle = 1; info.notCheckable = 1
      UIDropDownMenu_AddButton(info, 1)
      for i = 1, Count(folders) do
        Add("[folder] " .. folders[i], "folder:" .. folders[i])
      end
    end

    local user = GetUserPlaylists()
    if Count(user) > 0 then
      info = {}; info.text = "-- Playlists --"; info.isTitle = 1; info.notCheckable = 1
      UIDropDownMenu_AddButton(info, 1)
      for i = 1, Count(user) do
        Add(user[i], "user:" .. user[i])
      end
    end

    info = {}
    info.text = "Play all in playlist"
    info.hasArrow = 1
    info.notCheckable = 1
    info.value = "PLAYALL"
    UIDropDownMenu_AddButton(info, 1)

    info = {}
    info.text = "Queue playlist (add to Up Next)"
    info.hasArrow = 1
    info.notCheckable = 1
    info.value = "QUEUEALL"
    UIDropDownMenu_AddButton(info, 1)

    info = {}; info.text = ""; info.disabled = 1; info.notCheckable = 1
    UIDropDownMenu_AddButton(info, 1)

    info = {}
    info.text = "New playlist..."
    info.notCheckable = 1
    info.func = function()
      PromptNewPlaylist(nil)
      if CloseDropDownMenus then CloseDropDownMenus() end
    end
    UIDropDownMenu_AddButton(info, 1)

    if Queue_Count() > 0 then
      info = {}
      info.text = "Clear queue (" .. Queue_Count() .. ")"
      info.notCheckable = 1
      info.func = function()
        Queue_Clear()
        SetStatus("Queue cleared.", 1, 0.82, 0)
        RecomputeView(); RefreshList()
        if CloseDropDownMenus then CloseDropDownMenus() end
      end
      UIDropDownMenu_AddButton(info, 1)
    end

    if Count(user) > 0 then
      info = {}
      info.text = "Delete playlist"
      info.hasArrow = 1
      info.notCheckable = 1
      info.value = "DELETE"
      UIDropDownMenu_AddButton(info, 1)
    end
  end

  RJ.InitPlaylistDropdown = InitPlaylistDropdown

  pcall(UIDropDownMenu_Initialize, dd, InitPlaylistDropdown)
  pcall(UIDropDownMenu_SetWidth, 160, dd)
  RJ.playlistDropdownText = getglobal("RJPlaylistDropDownText")
  if RJ.playlistDropdownText then
    RJ.playlistDropdownText:SetText(PlaylistDisplayLabel(RelationshipsJukeboxDB.activePlaylist or "All"))
  end
  AttachTooltip(dd, "Playlist view", "Switch which list of tracks is shown -- All / Favorites / one auto-playlist per Media subfolder / your own playlists.")



  -- Track list (anchored from top, leaves room for buttons at bottom)
  local listAnchor = CreateFrame("Frame", nil, f)
  listAnchor:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -106)
  listAnchor:SetWidth(690)
  listAnchor:SetHeight(336)

  for i = 1, RJ.pageSize do
    local row = CreateRow(listAnchor, i)
    if i == 1 then
      row:SetPoint("TOPLEFT", listAnchor, "TOPLEFT", 0, 1)
    else
      row:SetPoint("TOPLEFT", RJ.rows[i-1], "BOTTOMLEFT", 0, -1)
    end
    RJ.rows[i] = row
  end

  -- Bottom button bar: two rows
  --   Row 1 (higher): Playback controls (<< Prev, Skip >>, Play All, Shuffle, Stop)
  --   Row 2 (lower):  Page navigation  (Prev, Page X/Y, Next) + Timer
  local playbackY = 108  -- playback controls row offset from bottom
  local pageY    = 54    -- page navigation row offset from bottom

  -- Playback controls (upper row, left-aligned)
  RJ.prevButton = MakeButton(nil, f, 70, 22, "<< Prev")
  RJ.prevButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 24, playbackY)
  RJ.prevButton:SetScript("OnClick", PreviousTrack)
  RJ.prevButton:Disable()

  RJ.skipButton = MakeButton(nil, f, 70, 22, "Skip >>")
  RJ.skipButton:SetPoint("LEFT", RJ.prevButton, "RIGHT", 8, 0)
  RJ.skipButton:SetScript("OnClick", SkipTrack)
  RJ.skipButton:Disable()

  RJ.playAllButton = MakeButton(nil, f, 80, 22, "Play All")
  RJ.playAllButton:SetPoint("LEFT", RJ.skipButton, "RIGHT", 8, 0)
  RJ.playAllButton:SetScript("OnClick", function() StartPlaylist(false) end)

  RJ.shuffleButton = MakeButton(nil, f, 70, 22, "Shuffle")
  RJ.shuffleButton:SetPoint("LEFT", RJ.playAllButton, "RIGHT", 8, 0)
  RJ.shuffleButton:SetScript("OnClick", function() StartPlaylist(true) end)

  RJ.stopButton = MakeButton(nil, f, 60, 22, "Stop")
  RJ.stopButton:SetPoint("LEFT", RJ.shuffleButton, "RIGHT", 8, 0)
  RJ.stopButton:SetScript("OnClick", function() StopPlayback(false) end)

  -- Page navigation (lower row, left-aligned — moved down to replace slash text area)
  local prev = MakeButton(nil, f, 70, 22, "Prev")
  prev:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 24, pageY)
  prev:SetScript("OnClick", function()
    RJ.page = RJ.page - 1
    RefreshList()
  end)

  RJ.pageText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  RJ.pageText:SetPoint("LEFT", prev, "RIGHT", 14, 0)
  RJ.pageText:SetText("Page 1/1")

  local nextBtn = MakeButton(nil, f, 70, 22, "Next")
  nextBtn:SetPoint("LEFT", RJ.pageText, "RIGHT", 14, 0)
  nextBtn:SetScript("OnClick", function()
    RJ.page = RJ.page + 1
    RefreshList()
  end)

  -- Volume slider (between Next button and timer, page navigation row)
  -- Controls the master volume via the "MasterVolume" CVar.
  -- This affects all game audio including the jukebox.
  -- The entire block is wrapped in pcall so that if *any* part of slider
  -- creation fails (missing API, texture, etc.) the rest of CreateUI()
  -- still runs — timer, reset button, mini player, minimap icon, etc.
  pcall(function()
    local sliderFrame = CreateFrame("Frame", nil, f)
    sliderFrame:SetWidth(120)
    sliderFrame:SetHeight(17)
    sliderFrame:SetPoint("LEFT", nextBtn, "RIGHT", 14, 0)
    if sliderFrame.SetBackdrop then
      sliderFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 }
      })
    end
    local slider = CreateFrame("Slider", nil, sliderFrame)
    RJ.volumeSlider = slider
    slider:SetAllPoints(sliderFrame)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(0, 100)
    slider:SetValueStep(5)
    -- SetObeyStepOnDrag may not exist in 1.12; guard it
    if slider.SetObeyStepOnDrag then
      slider:SetObeyStepOnDrag(true)
    end
    slider:EnableMouse(true)
    -- Thumb texture (the draggable knob)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    -- Label above the slider
    local sliderLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sliderLabel:SetPoint("BOTTOM", sliderFrame, "TOP", 0, 0)
    sliderLabel:SetText("Vol")
    -- Low / High labels below the slider
    local sliderLow = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sliderLow:SetPoint("TOPLEFT", sliderFrame, "BOTTOMLEFT", 2, 3)
    sliderLow:SetText("0")
    local sliderHigh = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sliderHigh:SetPoint("TOPRIGHT", sliderFrame, "BOTTOMRIGHT", -2, 3)
    sliderHigh:SetText("100")
    -- Read initial volume from SavedVariables (falls back to current CVar)
    local cv = GetCVar or function() return "1" end
    local ok, val = pcall(cv, "MasterVolume")
    local initial = RelationshipsJukeboxDB.volume
    if not initial then
      initial = (ok and val) and math.floor(tonumber(val) * 100 + 0.5) or 100
    end
    slider:SetValue(initial)
    slider:SetScript("OnValueChanged", function()
      local pct = this:GetValue()
      local sc = SetCVar or function() end
      -- Snapshot MasterVolume once so we can restore the player's
      -- original master output level on logout.
      SnapshotCVar("MasterVolume")
      -- MasterVolume is 0..1, slider is 0..100
      pcall(sc, "MasterVolume", string.format("%.2f", pct / 100))
      -- Persist slider position (not applied at login — see VARIABLES_LOADED)
      RelationshipsJukeboxDB.volume = pct
    end)
  end)

  -- Timer display (right side of page navigation row)
  RJ.timerText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  RJ.timerText:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, pageY)
  RJ.timerText:SetJustifyH("RIGHT")
  RJ.timerText:SetTextColor(0.8, 0.8, 0.8)
  RJ.timerText:SetText("")

  -- Reset button (bottom right, just under the timer display)
  -- Resets the addon to default: stops playback, restores music CVar,
  -- resets frame position, and re-initializes the database.
  local resetBtn = MakeButton(nil, f, 60, 20, "Reset")
  resetBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 33)
  resetBtn:SetScript("OnClick", function()
    -- Stop any playing track and restore full audio
    if RJ.currentPath or RJ.autoPlayEnabled then
      RestoreZoneMusic()
      StopJukeboxTrack()
    end
    -- Cancel any pending sound re-enable and immediately
    -- re-enable all sound so the player can hear game audio.
    -- KillAllSounds() sets MasterSoundEffects="0" and schedules a
    -- re-enable, but the re-enable callback is cancelled below.
    -- Without this, the player would be left with no sound at all.
    RJ._pendingReenableAt = nil
    RJ._pendingReenableCallback = nil
    do
      local sc = SetCVar or function() end
      pcall(sc, "MasterSoundEffects", "1")
      pcall(sc, "EnableMusic", "1")
    end
    RJ._originalEnableMusic = nil
    RJ._savedEnableMusic = nil
    -- Reset all internal state
    RJ.isPaused = false
    RJ.pausedRemaining = nil
    RJ.pauseCooldownUntil = 0
    RJ.playCooldownUntil = 0
    RJ.skipCooldownUntil = 0
    RJ.prevCooldownUntil = 0
    RJ.stopCooldownUntil = 0
    RJ.autoPlayEnabled = false
    RJ.playQueue = nil
    RJ.playQueuePosition = 0
    RJ.shuffleMode = false
    RJ.trackEndTime = nil
    RJ.trackStartTime = nil
    RJ.pausedElapsed = nil
    RJ.currentDuration = 0
    RJ.pollingForEnd = false
    RJ.pollTimer = 0
    RJ.consecutiveNotPlaying = 0
    RJ.currentCanStop = false
    RJ.currentIndex = nil
    RJ.currentPath = nil
    RJ.currentName = nil
    -- Reset frame position to center of screen
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    -- Reset mini player position and show it
    if RJ.miniFrame then
      RJ.miniFrame:ClearAllPoints()
      RJ.miniFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 300, -300)
      RJ.miniFrame:Show()
    else
      CreateMiniPlayer()
      if RJ.miniFrame then
        RJ.miniFrame:Show()
      end
    end
    -- Reset minimap icon to center of screen
    if RJ.minimapButton then
      RJ.minimapButton:ClearAllPoints()
      RJ.minimapButton:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
      RelationshipsJukeboxDB.iconX = nil
      RelationshipsJukeboxDB.iconY = nil
    end
    -- Reset volume slider to default (100%)
    do
      local sc = SetCVar or function() end
      SnapshotCVar("MasterVolume")
      pcall(sc, "MasterVolume", "1.0")
      RelationshipsJukeboxDB.volume = 100
      if RJ.volumeSlider then
        RJ.volumeSlider:SetValue(100)
      end
    end
    -- Re-initialize database
    EnsureDB()
    -- Reset page
    RJ.page = 1
    RJ.searchFilter = ""
    RJ.filteredIndices = nil
    RefreshList()
    RefreshPlaybackButtons()
    RefreshMiniPlayer()
    SetStatus("Addon reset to defaults. All sound re-enabled.", 0.2, 1, 0.2)
  end)

  -- Status bar (very bottom)
  RJ.statusText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  RJ.statusText:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 24, 18)
  RJ.statusText:SetWidth(680)
  RJ.statusText:SetJustifyH("LEFT")
  RJ.statusText:SetText("Ready.")

  RefreshList()
end

-----------------------------------------------------------------------
-- Mini Player: small floating control bar
-----------------------------------------------------------------------
function RefreshMiniPlayer()
  if not RJ.miniFrame then return end
  local mf = RJ.miniFrame
  local inQueue = RJ.autoPlayEnabled and RJ.playQueue ~= nil
  local isActive = RJ.currentPath ~= nil
  local now = GetTime()

  -- Build the display text for the mini player.  The ScrollFrame marquee
  -- will lay it out on the next frame; here we only reset state when the
  -- visible text actually changes.
  local newText
  if RJ.currentName and RJ.currentName ~= "" then
    if RJ.isPaused then
      newText = "|| " .. RJ.currentName
    else
      newText = RJ.currentName
    end
  else
    newText = "Relationships Jukebox"
  end

  if RJ.marqueeSingleText ~= newText then
    if mf.trackLabel then
      mf.trackLabel:SetText(newText)
    end
    RJ.marqueeOffset = 0
    RJ.marqueeLastUpdate = 0
    RJ.marqueeCycleWidth = 0
    RJ.marqueeSingleText = ""
    RJ.marqueeSingleWidth = 0
  end

  -- Enable/disable buttons with 1-second cooldown checks
  if inQueue and now >= RJ.skipCooldownUntil then
    mf.skipBtn:Enable()
  else
    mf.skipBtn:Disable()
  end

  if inQueue and RJ.playQueuePosition > 1 and now >= RJ.prevCooldownUntil then
    mf.prevBtn:Enable()
  else
    mf.prevBtn:Disable()
  end

  if isActive or RJ.isPaused then
    if now >= RJ.stopCooldownUntil then
      mf.stopBtn:Enable()
    else
      mf.stopBtn:Disable()
    end
  else
    mf.stopBtn:Disable()
  end
end


local function CreateMiniPlayer()
  if RJ.miniFrame then return end

  local mf = CreateFrame("Frame", ADDON_NAME .. "MiniFrame", UIParent)
  RJ.miniFrame = mf
  mf:SetWidth(216)
  mf:SetHeight(68)
  mf:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -60, -200)
  mf:SetMovable(true)
  mf:EnableMouse(true)
  mf:RegisterForDrag("LeftButton")
  mf:SetScript("OnDragStart", function() mf:StartMoving() end)
  mf:SetScript("OnDragStop", function() mf:StopMovingOrSizing() end)
  mf:SetClampedToScreen(true)
  mf:SetScript("OnShow", function()
    RJ.marqueeLastUpdate = 0
  end)

  if mf.SetBackdrop then
    mf:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    mf:SetBackdropColor(0, 0, 0, 0.7)
  end

  -- Track name (top row) - marquee scrolling text
  -- Use a ScrollFrame viewport plus repeated labels so the text scrolls
  -- smoothly at the pixel level without re-slicing strings every frame.
  mf.trackClip = CreateFrame("ScrollFrame", nil, mf)
  mf.trackClip:SetPoint("TOPLEFT", mf, "TOPLEFT", 8, -12)
  mf.trackClip:SetPoint("BOTTOMRIGHT", mf, "TOPRIGHT", -8, -30)
  mf.trackClip:SetHorizontalScroll(0)

  mf.trackCanvas = CreateFrame("Frame", nil, mf.trackClip)
  mf.trackCanvas:SetWidth(1)
  mf.trackCanvas:SetHeight(14)
  mf.trackClip:SetScrollChild(mf.trackCanvas)

  mf.trackLabels = {}
  for labelIndex = 1, 3 do
    local label = mf.trackCanvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetJustifyH("LEFT")
    label:SetTextColor(0.4, 1, 0.4)
    label:SetText("Relationships Jukebox")
    mf.trackLabels[labelIndex] = label
  end

  mf.trackLabel = mf.trackLabels[1]

  local function PositionMiniMarquee(offset)
    mf.trackCanvas:ClearAllPoints()

    if RJ.marqueeCycleWidth > 0 then
      -- Keep the middle copy inside the viewport and slide the whole strip to
      -- the left. Wrapping happens by reusing the previous/next copies, so the
      -- text never disappears into a blank gap between loops.
      mf.trackCanvas:SetPoint("TOPLEFT", mf.trackClip, "TOPLEFT", -RJ.marqueeCycleWidth - offset, 0)
    else
      mf.trackCanvas:SetPoint("TOPLEFT", mf.trackClip, "TOPLEFT", 0, 0)
    end
  end

  local function LayoutMiniMarquee(singleText)
    if not singleText or singleText == "" then
      singleText = "Relationships Jukebox"
    end

    local viewWidth = mf.trackClip:GetWidth()
    if viewWidth <= 0 then return end

    mf.trackLabels[1]:SetText(singleText)

    local singleWidth
    if mf.trackLabels[1].GetStringWidth then
      singleWidth = mf.trackLabels[1]:GetStringWidth()
    else
      singleWidth = string.len(singleText) * 7
    end

    RJ.marqueeSingleText = singleText
    RJ.marqueeSingleWidth = singleWidth

    if singleWidth <= viewWidth or singleWidth == 0 then
      RJ.marqueeCycleWidth = 0
      RJ.marqueeOffset = 0
      RJ.marqueeFullText = singleText

      mf.trackLabels[1]:ClearAllPoints()
      mf.trackLabels[1]:SetPoint("TOPLEFT", mf.trackCanvas, "TOPLEFT", 0, 0)
      mf.trackLabels[1]:SetText(singleText)
      mf.trackLabels[2]:SetText("")
      mf.trackLabels[3]:SetText("")

      mf.trackCanvas:SetWidth(math.max(viewWidth, singleWidth))
      PositionMiniMarquee(0)
      return
    end

    RJ.marqueeFullText = singleText .. (RJ.marqueeSeparator or "   ")
    for labelIndex = 1, 3 do
      mf.trackLabels[labelIndex]:SetText(RJ.marqueeFullText)
    end

    if mf.trackLabels[1].GetStringWidth then
      RJ.marqueeCycleWidth = mf.trackLabels[1]:GetStringWidth()
    else
      RJ.marqueeCycleWidth = string.len(RJ.marqueeFullText) * 7
    end

    for labelIndex = 1, 3 do
      mf.trackLabels[labelIndex]:ClearAllPoints()
      mf.trackLabels[labelIndex]:SetPoint("TOPLEFT", mf.trackCanvas, "TOPLEFT", (labelIndex - 1) * RJ.marqueeCycleWidth, 0)
    end

    mf.trackCanvas:SetWidth(RJ.marqueeCycleWidth * 3)
    PositionMiniMarquee(RJ.marqueeOffset)
  end

  -- Smooth marquee update fully clipped to the mini player bounds.
  mf:SetScript("OnUpdate", function()
    local singleText
    if RJ.currentName and RJ.currentName ~= "" then
      if RJ.isPaused then
        singleText = "|| " .. RJ.currentName
      else
        singleText = RJ.currentName
      end
    else
      singleText = "Relationships Jukebox"
    end

    if RJ.marqueeSingleText ~= singleText then
      RJ.marqueeOffset = 0
      RJ.marqueeLastUpdate = 0
      LayoutMiniMarquee(singleText)
    end

    if not RJ.currentName or RJ.currentName == "" then
      RJ.marqueeOffset = 0
      RJ.marqueeLastUpdate = 0
      PositionMiniMarquee(0)
      return
    end

    if RJ.marqueeCycleWidth <= 0 then
      PositionMiniMarquee(0)
      return
    end

    local now = GetTime()
    if RJ.marqueeLastUpdate == 0 then
      RJ.marqueeLastUpdate = now
      PositionMiniMarquee(RJ.marqueeOffset)
      return
    end

    local elapsed = now - RJ.marqueeLastUpdate
    RJ.marqueeLastUpdate = now
    if elapsed > 0.5 then elapsed = 0.5 end

    RJ.marqueeOffset = RJ.marqueeOffset + (RJ.marqueeSpeed * elapsed)
    while RJ.marqueeOffset >= RJ.marqueeCycleWidth do
      RJ.marqueeOffset = RJ.marqueeOffset - RJ.marqueeCycleWidth
    end

    PositionMiniMarquee(RJ.marqueeOffset)
  end)

  -- Timer display (between track name and control buttons)
  mf.timerText = mf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  mf.timerText:SetPoint("TOPLEFT", mf, "TOPLEFT", 4, -29)
  mf.timerText:SetPoint("TOPRIGHT", mf, "TOPRIGHT", -8, -29)
  mf.timerText:SetJustifyH("RIGHT")
  mf.timerText:SetTextColor(0.8, 0.8, 0.8)
  mf.timerText:SetText("")

  -- Control buttons (bottom row): <<, Stop, >>, +, -
  mf.prevBtn = MakeButton(nil, mf, 40, 20, "<<")
  mf.prevBtn:SetPoint("BOTTOMLEFT", mf, "BOTTOMLEFT", 6, 6)
  mf.prevBtn:SetScript("OnClick", PreviousTrack)
  mf.prevBtn:Disable()

  mf.stopBtn = MakeButton(nil, mf, 50, 20, "Stop")
  mf.stopBtn:SetPoint("LEFT", mf.prevBtn, "RIGHT", 4, 0)
  mf.stopBtn:SetScript("OnClick", function() StopPlayback(false) end)
  mf.stopBtn:Disable()

  mf.skipBtn = MakeButton(nil, mf, 40, 20, ">>")
  mf.skipBtn:SetPoint("LEFT", mf.stopBtn, "RIGHT", 4, 0)
  mf.skipBtn:SetScript("OnClick", SkipTrack)
  mf.skipBtn:Disable()

  -- Open full GUI button
  mf.openBtn = MakeButton(nil, mf, 28, 20, "+")
  mf.openBtn:SetPoint("LEFT", mf.skipBtn, "RIGHT", 4, 0)
  mf.openBtn:SetScript("OnClick", function()
    if RJ.frame then
      RJ.frame:Show()
      RefreshList()
    end
  end)

  -- Minimize button (bottom row, after + button)
  mf.minBtn = MakeButton(nil, mf, 28, 20, "-")
  mf.minBtn:SetPoint("LEFT", mf.openBtn, "RIGHT", 4, 0)
  mf.minBtn:SetScript("OnClick", function()
    mf:Hide()
    if RJ.minimapButton then
      RJ.minimapButton:Show()
    end
  end)

  mf:Show()
  -- Reset marquee timer when mini player first appears
  RJ.marqueeLastUpdate = 0
  RefreshMiniPlayer()
end

-----------------------------------------------------------------------
-- Minimap button
-----------------------------------------------------------------------
local function CreateMinimapButton()
  if RJ.minimapButton then return end

  pcall(function()
    -- Parent to UIParent so the button can be dragged anywhere on screen,
    -- not just pinned to the minimap.
    local btn = CreateFrame("Button", ADDON_NAME .. "MinimapButton", UIParent)
    RJ.minimapButton = btn
    btn:SetWidth(32)
    btn:SetHeight(32)

    -- Use the built-in paper/note icon (guaranteed to exist in 1.12).
    btn:SetNormalTexture("Interface\\Icons\\INV_Misc_Note_06")
    btn:SetPushedTexture("Interface\\Icons\\INV_Misc_Note_06")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Position: use saved coordinates, or default to a visible spot.
    local savedX = RelationshipsJukeboxDB.iconX
    local savedY = RelationshipsJukeboxDB.iconY
    if savedX and savedY then
      btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", savedX, -savedY)
    else
      -- Default position: top-right area of screen, guaranteed visible
      local screenWidth = UIParent:GetWidth() or 1024
      btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", screenWidth - 80, -30)
    end

    -- Tooltip
    btn:SetScript("OnEnter", function()
      GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
      GameTooltip:SetText("Relationships Jukebox")
      GameTooltip:AddLine("Click: Toggle Mini Player")
      GameTooltip:AddLine("Right-click: Toggle Full GUI")
      GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    -- Left click: toggle mini player
    btn:SetScript("OnClick", function()
      if RJ.miniFrame then
        if RJ.miniFrame:IsShown() then
          RJ.miniFrame:Hide()
        else
          RJ.miniFrame:Show()
          RefreshMiniPlayer()
        end
      else
        CreateMiniPlayer()
      end
    end)

    -- Right click: toggle full GUI
    btn:SetScript("OnMouseDown", function()
      if arg1 == "RightButton" then
        if not RJ.frame then CreateUI() end
        if RJ.frame:IsShown() then
          RJ.frame:Hide()
        else
          RJ.frame:Show()
          RefreshList()
        end
      end
    end)

    -- Free dragging: the button can be moved anywhere on screen.
    -- Save position to SavedVariables on drag stop.
    btn:SetMovable(true)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function()
      btn:StartMoving()
    end)
    btn:SetScript("OnDragStop", function()
      btn:StopMovingOrSizing()
      -- Save position to SavedVariables (store positive offset from top-left)
      local left = btn:GetLeft() or 0
      local top = btn:GetTop() or 0
      local screenTop = (UIParent:GetTop() or 768)
      RelationshipsJukeboxDB.iconX = left
      RelationshipsJukeboxDB.iconY = screenTop - top
    end)

    btn:Show()
  end)
end

-----------------------------------------------------------------------
-- Zone ambient music suppression
-----------------------------------------------------------------------
-- The jukebox now plays through its own sound channel, so zone ambient
-- music events no longer interfere with jukebox playback.  However, we
-- still disable EnableMusic while the jukebox is playing to prevent the
-- game engine from playing zone ambient music over the jukebox track on
-- the Music channel.  When the jukebox stops or pauses, RestoreZoneMusic()
-- restores the player's original EnableMusic setting.

-- Saved state for EnableMusic CVar restoration
RJ._savedEnableMusic = nil       -- original EnableMusic value before jukebox took over
RJ._originalEnableMusic = nil   -- player's EnableMusic value before addon loaded (for Reset)

-- Suppress zone ambient music when the jukebox is playing.
-- Saves the original EnableMusic value and sets it to "0" so the
-- engine does not start zone ambient music on the Music channel.
SuppressZoneMusic = function()
  local cv = GetCVar or function() return "1" end
  local sc = SetCVar or function() end
  local ok, val = pcall(cv, "EnableMusic")
  RJ._savedEnableMusic = (ok and val) or "1"
  -- Set EnableMusic="0" to suppress zone ambient music.
  pcall(sc, "EnableMusic", "0")
end

-- Restore zone ambient music when the jukebox stops or pauses.
-- Restores the EnableMusic value saved by SuppressZoneMusic(),
-- allowing zone ambient music to resume normally.
RestoreZoneMusic = function()
  local sc = SetCVar or function() end
  if RJ._savedEnableMusic then
    pcall(sc, "EnableMusic", RJ._savedEnableMusic)
    RJ._savedEnableMusic = nil
  end
end





-- Loading screen / zone change handler: NOT NEEDED.
-- Since the jukebox now uses its own sound channel ("Ambience"), loading
-- screens and zone changes do NOT interrupt jukebox playback.  The track
-- simply continues playing through them.  No event handler is required.
-- (Previously FMOD was thought to rebuild on PLAYER_ENTERING_WORLD and
-- kill all sounds, but on the separate channel the track persists.)

-----------------------------------------------------------------------
-- Logout handler: stop jukebox music when the player logs out
-----------------------------------------------------------------------
local logoutHandler = CreateFrame("Frame")
logoutHandler:RegisterEvent("PLAYER_LOGOUT")
logoutHandler:SetScript("OnEvent", function()
  -- Stop the jukebox track and restore the player's normal audio
  -- settings so that zone ambient music / SFX / ambience resume
  -- on the next login or character switch.
  if RJ.currentPath or RJ.autoPlayEnabled then
    RestoreZoneMusic()
    -- Stop the jukebox track.
    StopJukeboxTrack()
    RJ.autoPlayEnabled = false
    RJ.currentPath = nil
    RJ.currentName = nil
    RJ.currentIndex = nil
    RJ.isPaused = false
    RJ.pausedRemaining = nil
    RJ.currentCanStop = false
    RJ.pollingForEnd = false
    RJ.trackEndTime = nil
    RJ.trackStartTime = nil
    RJ.pausedElapsed = nil
    RJ.currentDuration = 0
  end
  -- Suppress the pending MasterSoundEffects re-enable — we're about to
  -- restore it explicitly from the snapshot below, and the ticker will
  -- not fire again this session.
  RJ._pendingReenableAt = nil
  RJ._pendingReenableCallback = nil
  -- Clear legacy in-memory copy (superseded by SavedVariables snapshot).
  RJ._originalEnableMusic = nil
  -- Restore every sound CVar the addon ever changed this session
  -- (EnableMusic, MasterSoundEffects, MasterVolume, ...) back to the
  -- value the player had before the addon loaded, and clear the
  -- snapshot so the next login starts clean.
  RestoreSavedCVars()
end)

-----------------------------------------------------------------------
-- Main ticker: handles timed advancement and IsPlaying polling
-----------------------------------------------------------------------
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
  -- -1) Pending MasterSoundEffects re-enable: if KillAllSounds() disabled all
  --     sound, we need to re-enable it after a short delay so FMOD has time
  --     to actually stop the audio before we turn the master CVar back on.
  if RJ._pendingReenableAt and GetTime() >= RJ._pendingReenableAt then
    local sc = SetCVar or function() end
    pcall(sc, "MasterSoundEffects", "1")
    RJ._pendingReenableAt = nil
    -- If a callback was registered (e.g., play new track after killing old one),
    -- invoke it now that sound is re-enabled.
    if RJ._pendingReenableCallback then
      local cb = RJ._pendingReenableCallback
      RJ._pendingReenableCallback = nil
      cb()
    end
  end

  -- 0) Loading screen resume: NOT NEEDED.  The jukebox plays on its own
  --     sound channel and continues through loading screens uninterrupted.
  --     No re-assert is required.

  -- 1) Timed advancement: track with known duration reached end time
  if not RJ.isPaused and RJ.trackEndTime and GetTime() >= RJ.trackEndTime then
    RJ.trackEndTime = nil
    if RJ.autoPlayEnabled or Queue_Count() > 0 then
      -- Queue/autoplay mode: advance to next track (user queue drained first)
      RJ.currentCanStop = false
      RJ.pollingForEnd = false
      KillAllSounds(PlayNextQueuedTrack)
    else
      -- Single track mode: stop playback when track finishes
      StopPlayback(true)
      SetStatus("Track finished.", 0.2, 1, 0.2)
    end
    return
  end

  -- 2) IsPlaying polling: detect when PlaySoundFile track finishes for tracks with no duration
  if not RJ.isPaused and RJ.pollingForEnd then
    if GetTime() < RJ.pollTimer then
      return
    end

    local playing = false
    if IsPlaying then
      playing = IsPlaying()
    end

    if not playing then
      RJ.consecutiveNotPlaying = RJ.consecutiveNotPlaying + 1
      if RJ.consecutiveNotPlaying >= RJ.consecutiveThreshold then
        RJ.pollingForEnd = false
        RJ.consecutiveNotPlaying = 0
        if RJ.autoPlayEnabled or Queue_Count() > 0 then
          -- Queue/autoplay mode: advance (user queue drained first)
          RJ.currentCanStop = false
          KillAllSounds(PlayNextQueuedTrack)
        else
          -- Single track mode: stop playback when track finishes
          StopPlayback(true)
          SetStatus("Track finished.", 0.2, 1, 0.2)
        end
      else
        -- Not sure yet; check again soon
        RJ.pollTimer = GetTime() + RJ.pollInterval
      end
    else
      -- Still playing; reset counter, schedule next check
      RJ.consecutiveNotPlaying = 0
      RJ.pollTimer = GetTime() + RJ.pollInterval
    end
  end

  -- 3) Re-enable stop button after cooldown expires (pause button removed from mini-player)
  if RJ.pauseCooldownUntil > 0 and GetTime() >= RJ.pauseCooldownUntil then
    RJ.pauseCooldownUntil = 0
    RefreshPlaybackButtons()
  end

  -- 4) Re-enable Play / Play All / Shuffle buttons after play cooldown expires
  if RJ.playCooldownUntil > 0 and GetTime() >= RJ.playCooldownUntil then
    RJ.playCooldownUntil = 0
    RefreshPlaybackButtons()
    RefreshList()
  end

  -- 5) Re-enable Skip button after skip cooldown expires
  if RJ.skipCooldownUntil > 0 and GetTime() >= RJ.skipCooldownUntil then
    RJ.skipCooldownUntil = 0
    RefreshPlaybackButtons()
  end

  -- 6) Re-enable Previous button after prev cooldown expires
  if RJ.prevCooldownUntil > 0 and GetTime() >= RJ.prevCooldownUntil then
    RJ.prevCooldownUntil = 0
    RefreshPlaybackButtons()
  end

  -- 7) Re-enable Stop button after stop cooldown expires
  if RJ.stopCooldownUntil > 0 and GetTime() >= RJ.stopCooldownUntil then
    RJ.stopCooldownUntil = 0
    RefreshPlaybackButtons()
  end

  -- 8) Update timer displays (main GUI + mini player)
  --    Shows elapsed/total in M:SS/M:SS format while a track is playing.
  --    While paused, the elapsed time freezes at the point of pause.
  if RJ.currentPath and RJ.trackStartTime then
    local elapsed
    if RJ.isPaused then
      elapsed = RJ.pausedElapsed or 0
    else
      elapsed = GetTime() - RJ.trackStartTime
    end
    local total = RJ.currentDuration or 0
    local timerStr
    if total > 0 then
      timerStr = FormatElapsedTime(elapsed, total)
    else
      timerStr = FormatTime(elapsed)
    end
    -- Main GUI timer
    if RJ.timerText then
      RJ.timerText:SetText(timerStr)
    end
    -- Mini player timer
    if RJ.miniFrame and RJ.miniFrame.timerText then
      RJ.miniFrame.timerText:SetText(timerStr)
    end
  else
    -- No track playing - clear timers
    if RJ.timerText then
      RJ.timerText:SetText("")
    end
    if RJ.miniFrame and RJ.miniFrame.timerText then
      RJ.miniFrame.timerText:SetText("")
    end
  end
end)

-----------------------------------------------------------------------
-- Auto-start on login (disabled — player chooses when to start music)
-----------------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("VARIABLES_LOADED")
loader:SetScript("OnEvent", function()
  local imported, updated

  if time then
    math.randomseed(time())
    math.random()
    math.random()
    math.random()
  end

  EnsureDB()
  EnsurePlaylists()
  EnsureAnnounceSettings()



  -- CRASH-RECOVERY: if a previous session ended (logout, /reload, or crash)
  -- without our PLAYER_LOGOUT handler firing — for example inside the ~50ms
  -- window where KillAllSounds() has MasterSoundEffects="0" — restore the
  -- pre-mute values from SavedVariables FIRST, before we do anything else.
  -- This guarantees the player logs in with their real sound settings even
  -- after a hard crash mid-mute.
  RestoreSavedCVars()

  -- Save the player's original EnableMusic value and disable game engine
  -- music so it does not overlap with jukebox playback.  Restored on
  -- PLAYER_LOGOUT via RestoreSavedCVars() (and on Reset).
  --
  -- IMPORTANT: We deliberately do NOT touch MasterVolume here.  MasterVolume
  -- is the global master output CVar and controls ALL game audio (SFX,
  -- ambience, jukebox, everything).  A previous version applied the saved
  -- jukebox slider value to MasterVolume at login, which muted every game
  -- sound whenever the slider had been dragged down.  The only thing that
  -- should be silenced when this addon loads is the in-game music ("the
  -- music box"), which is what EnableMusic="0" does.
  do
    local cv = GetCVar or function() return "1" end
    local sc = SetCVar or function() end
    SnapshotCVar("EnableMusic")
    local ok, val = pcall(cv, "EnableMusic")
    RJ._originalEnableMusic = (ok and val) or "1"
    pcall(sc, "EnableMusic", "0")
  end

  imported, updated = MergeAutoPlaylist()
  CreateUI()
  CreateMiniPlayer()
  CreateMinimapButton()

  -- Rebuild the dropdown now that folder-playlists (derived from track data)
  -- and user playlists (from SavedVariables) are both known.
  if RJ.playlistDropdown and RJ.InitPlaylistDropdown then
    pcall(UIDropDownMenu_Initialize, RJ.playlistDropdown, RJ.InitPlaylistDropdown)
  end
  if RJ.playlistDropdownText then
    RJ.playlistDropdownText:SetText(PlaylistDisplayLabel(RelationshipsJukeboxDB.activePlaylist or "All"))
  end
  RecomputeView()
  RefreshList()


  if imported > 0 and updated > 0 then
    SetStatus("Imported " .. imported .. " and updated " .. updated .. " track(s) from AutoPlaylist.lua.", 0.2, 1, 0.2)
  elseif imported > 0 then
    SetStatus("Imported " .. imported .. " track(s) from AutoPlaylist.lua.", 0.2, 1, 0.2)
  elseif updated > 0 then
    SetStatus("Updated " .. updated .. " track(s) from AutoPlaylist.lua.", 0.2, 1, 0.2)
  elseif Count(RelationshipsJukeboxDB.tracks) > 0 then
    SetStatus("Loaded " .. Count(RelationshipsJukeboxDB.tracks) .. " track(s). Ready.", 0.2, 1, 0.2)
  else
    SetStatus("No tracks found. Put files in " .. ADDON_MEDIA_PREFIX .. " then run GeneratePlaylist.bat and restart or /reload.", 1, 0.82, 0)
  end

  -- No auto-start on login — player chooses when to start music
end)

-----------------------------------------------------------------------
-- Slash commands
-----------------------------------------------------------------------
SLASH_RELJUKEBOX1 = "/rjukebox"
SLASH_RELJUKEBOX2 = "/rj"
SlashCmdList["RELJUKEBOX"] = function(msg)
  local command = string.lower(Trim(msg or ""))

  if not RJ.frame then CreateUI() end

  if command == "play" then
    StartPlaylist(false)
    return
  elseif command == "shuffle" then
    StartPlaylist(true)
    return
  elseif command == "stop" then
    StopPlayback(false)
    return
  elseif command == "skip" then
    SkipTrack()
    return
  elseif command == "prev" then
    PreviousTrack()
    return
  elseif command == "pause" then
    TogglePause()
    return
  elseif command == "mini" then
    if RJ.miniFrame then
      if RJ.miniFrame:IsShown() then
        RJ.miniFrame:Hide()
      else
        RJ.miniFrame:Show()
        RefreshMiniPlayer()
      end
    else
      CreateMiniPlayer()
    end
    return
  elseif command == "playlast" then
    local total = Count(RelationshipsJukeboxDB.tracks)
    if total > 0 then PlayTrack(total, false) end
    return
  elseif command == "fav" then
    -- Toggle Favorites for the currently playing track.
    if RJ.currentPath then
      local nowFav = ToggleFavorite(RJ.currentPath)
      if nowFav then
        SetStatus("Added current track to Favorites.", 1, 0.82, 0)
      else
        SetStatus("Removed current track from Favorites.", 0.7, 0.7, 0.7)
      end
      RecomputeView(); RefreshList()
    else
      SetStatus("No track is playing.", 1, 0.4, 0.4)
    end
    return
  elseif command == "np" or string.sub(command, 1, 3) == "np " then
    -- /rj np [party|raid|guild|say|yell|auto]  -- announce now-playing track
    local arg = Trim(string.sub(command, 3))
    local chan = nil
    if arg ~= "" then
      chan = string.upper(arg)
      if chan == "P" then chan = "PARTY"
      elseif chan == "R" then chan = "RAID"
      elseif chan == "G" then chan = "GUILD"
      elseif chan == "S" then chan = "SAY"
      elseif chan == "Y" then chan = "YELL"
      end
      if not VALID_ANNOUNCE_CHANNELS[chan] then
        SetStatus("Unknown channel: " .. arg .. " (party/raid/guild/say/yell/auto)", 1, 0.4, 0.4)
        return
      end
    end
    AnnounceNowPlaying(true, chan)
    return
  elseif command == "announce" then
    -- Toggle auto-announce on/off.
    EnsureAnnounceSettings()
    local a = RelationshipsJukeboxDB.announce
    a.enabled = not a.enabled
    if a.enabled then
      SetStatus("Auto-announce ON (channel: " .. a.channel .. ")", 0.2, 1, 0.2)
    else
      SetStatus("Auto-announce OFF", 0.7, 0.7, 0.7)
    end
    if RJ.announceCheckbox and RJ.announceCheckbox.SetChecked then
      RJ.announceCheckbox:SetChecked(a.enabled)
    end
    return
  elseif string.sub(command, 1, 9) == "playlist " then
    -- /rj playlist <name>  -- switch view.  Special values: all, favorites,
    -- folder:<name>, user:<name>.  Plain names are treated as user playlists.
    local arg = Trim(string.sub(command, 10))
    if arg == "" or arg == "all" then
      SetActivePlaylist("All")
    elseif arg == "favorites" or arg == "favourites" or arg == "fav" then
      SetActivePlaylist("Favorites")
    elseif string.sub(arg, 1, 7) == "folder:" or string.sub(arg, 1, 5) == "user:" then
      SetActivePlaylist(arg)
    else
      -- match against user-playlist names (case insensitive), then folders
      local lower = string.lower(arg)
      local matched = nil
      local user = GetUserPlaylists()
      for i = 1, Count(user) do
        if string.lower(user[i]) == lower then matched = "user:" .. user[i]; break end
      end
      if not matched then
        local folders = GetFolderPlaylists()
        for i = 1, Count(folders) do
          if string.lower(folders[i]) == lower then matched = "folder:" .. folders[i]; break end
        end
      end
      if matched then
        SetActivePlaylist(matched)
      else
        SetStatus("Unknown playlist: " .. arg, 1, 0.4, 0.4)
      end
    end
    if RJ.playlistDropdown and RJ.InitPlaylistDropdown then
      pcall(UIDropDownMenu_Initialize, RJ.playlistDropdown, RJ.InitPlaylistDropdown)
    end
    return
  elseif command == "help" or command == "?" then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd200Relationships Jukebox commands:|r")
    DEFAULT_CHAT_FRAME:AddMessage("  /rj                  - toggle main GUI")
    DEFAULT_CHAT_FRAME:AddMessage("  /rj play | shuffle   - start playlist")
    DEFAULT_CHAT_FRAME:AddMessage("  /rj stop | skip | prev | pause")
    DEFAULT_CHAT_FRAME:AddMessage("  /rj mini             - toggle mini player")
    DEFAULT_CHAT_FRAME:AddMessage("  /rj fav              - toggle Favorites for current track")
    DEFAULT_CHAT_FRAME:AddMessage("  /rj playlist <name>  - switch view (all / favorites / <folder> / <playlist>)")
    return
  end

  -- No command: toggle full GUI
  if RJ.frame:IsShown() then
    RJ.frame:Hide()
  else
    RJ.frame:Show()
    RefreshList()
  end
end
