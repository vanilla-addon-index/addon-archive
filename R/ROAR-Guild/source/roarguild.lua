-- RoarGuild v1.33
-- Vanilla WoW 1.12
-- Lua 5.0-safe
-- SavedVariables: ROGUDB

-------------------------------------------------
-- [0] Constants
-------------------------------------------------
local ADDON_VERSION = "1.33"

local ROAR_REMINDER_INTERVAL = 420
local ROAR_REMINDER_CD = 73

-- Independent global fallback defaults (per-profile)
-- chancePermille: 5 => 0.5%
local FALLBACK_DEFAULT = { enabled=true, cd=2, chancePermille=5, last=0, emoteIDs={1} }

-------------------------------------------------
-- [1] Shared Utils
-------------------------------------------------
local U = {}

function U.trim(s)
  s = s or ""
  s = string.gsub(s, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  return s
end

function U.upper(s)
  return string.upper(U.trim(s or ""))
end

function U.split_cmd(raw)
  local s = U.trim(raw or "")
  local _, _, cmd, rest = string.find(s, "^(%S+)%s*(.*)$")
  if not cmd then return "", "" end
  return cmd, rest or ""
end

function U.pick(t)
  local n = table.getn(t or {})
  if n < 1 then return nil end
  return t[math.random(1, n)]
end

function U.arrayHas(t, value)
  if type(t) ~= "table" then return false end
  local i = 1
  while t[i] ~= nil do
    if t[i] == value then return true end
    i = i + 1
  end
  return false
end

-------------------------------------------------
-- [2] RoarGuild (ROGU) State
-------------------------------------------------
local ROGU = {
  profileKey = nil,
  profile = nil,        -- bound to ROGUDB.profiles[key]
  slots = nil,          -- bound to profile.slots
  fallback = nil,       -- bound to profile.fallback
  enabled = true,       -- from profile.enabled
  watchMode = false,

  stats = nil,          -- bound to profile.stats
  
  lastRoar = 0,
  lastReminder = 0,

  _loaded = false,
}

-------------------------------------------------
-- [2.1] Data Pools
-------------------------------------------------
local inviteText = {
  "<ROAR> A friendly guild for joy, curiosity, and shared adventures. We explore Azeroth at our own pace and roar at the good moments. You’re welcome to join us.",
  "<ROAR> Hear that? That’s Azeroth calling. We quest, wander, laugh, and /roar at victories big and small. Come roar with us!",
  "<ROAR> A band of joyful explorers roaming Azeroth for stories, treasure, and good times. No rush, no pressure, just adventure and loud roars.",
  "<ROAR> The pride gathers! We celebrate level-ups, loot, sunsets, and silly moments with a good /roar. Casual adventures, big hearts. All welcome.",
  "<ROAR> Casual adventurers, loud celebrations, shared stories. If you like exploring Azeroth and roaring at life, you belong here.",
  "<ROAR> A guild for joy, curiosity, and shared stories. Quest, dungeon, PvP, RP, collect, and wander together. Play to inspire, not to impress.",
  "<ROAR> Do you play for the world, not the meter? For stories, curiosity, and good vibes? We explore Azeroth together at our own pace.",
  "<ROAR> We play to inspire, not to impress. A home for curious souls, shared adventures, and good energy across Azeroth.",
  "<ROAR> Curious explorers and joyful wanderers wanted. We value respect, creativity, and shared stories. Let Azeroth hear your roar.",
  "<ROAR> Playing for curiosity, respect, and shared stories? So are we. Explore Azeroth together. Roar together.",
  "<ROAR> Not in a hurry? Good. We wander, explore, and celebrate the journey with a loud roar.",
  "<ROAR> A casual guild for people who still enjoy getting lost in Azeroth.",
  "<ROAR> We chase moments, not meters.",
  "<ROAR> Join a pride that values curiosity, kindness, and shared adventures.",
  "<ROAR> Azeroth is a world, not a checklist. Come explore it with us.",
  "<ROAR> From quiet wandering to loud celebrations, we enjoy every part of the journey.",
  "<ROAR> A home for explorers, storytellers, collectors, fighters, and friendly souls.",
  "<ROAR> Adventure feels better when shared."
}



-------------------------------------------------
-- [2.2] Chat + Emote
-------------------------------------------------
local function roarChat(text)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff4444RoarGuild:|r "..tostring(text or ""))
  end
end

local function performEmote(token)
  if DoEmote then
    DoEmote(token)
  else
    SendChatMessage("makes a battle cry!", "EMOTE")
  end
end

-------------------------------------------------
-- [2.3] Profiles 
-------------------------------------------------
local function ROGU_ProfileKey()
  local name = UnitName("player") or "Unknown"
  local realm = (GetRealmName and GetRealmName()) or ""
  if realm == "" then return name end
  return name .. "-" .. realm
end

-- Shared (account-wide) master emote list defaults
local function ROGU_EnsureEmoteDefaults(db)
  if type(db.emotes) ~= "table" then db.emotes = {} end
  if table.getn(db.emotes) < 1 then
    db.emotes[1] = { emote = "ROAR" }
    return
  end

  if type(db.emotes[1]) ~= "table" or type(db.emotes[1].emote) ~= "string" or db.emotes[1].emote == "" then
    db.emotes[1] = { emote = "ROAR" }
  else
    db.emotes[1].emote = U.upper(db.emotes[1].emote)
    if db.emotes[1].emote == "" then db.emotes[1].emote = "ROAR" end
  end
end

local function ROGU_EnsureFallbackDefaultsOn(tbl)
  if type(tbl) ~= "table" then return end
  if tbl.enabled == nil then tbl.enabled = FALLBACK_DEFAULT.enabled end
  if tbl.cd == nil then tbl.cd = FALLBACK_DEFAULT.cd end
  if tbl.chancePermille == nil then tbl.chancePermille = FALLBACK_DEFAULT.chancePermille end
  if tbl.last == nil then tbl.last = 0 end
  if type(tbl.emoteIDs) ~= "table" or table.getn(tbl.emoteIDs) < 1 then
    tbl.emoteIDs = { 1 }
  end
end

local function ROGU_EnsureDB()
  if type(ROGUDB) ~= "table" then ROGUDB = {} end
  if type(ROGUDB.profiles) ~= "table" then ROGUDB.profiles = {} end
  ROGU_EnsureEmoteDefaults(ROGUDB)
  return ROGUDB
end

-- One-time migration from legacy root fields (older versions) into this character profile
local function ROGU_MigrateLegacyRootToProfile(db, p)
  if p._migrated == true then return end

  -- Legacy: db.slots, db.enabled, db.fallback (root)
  if type(db.slots) == "table" and type(p.slots) == "table" and next(p.slots) == nil then
    p.slots = db.slots
  end

  if db.enabled ~= nil and p.enabled == true then
    p.enabled = db.enabled
  end

  if type(db.fallback) == "table" then
    p.fallback = db.fallback
    ROGU_EnsureFallbackDefaultsOn(p.fallback)
  end

  -- Clear legacy roots to avoid two sources of truth
  db.slots = nil
  db.enabled = nil
  db.fallback = nil

  p._migrated = true
end

local function ROGU_EnsureProfile(db)
  local key = ROGU_ProfileKey()
  local p = db.profiles[key]
  if type(p) ~= "table" then
    p = {}
    db.profiles[key] = p
  end

  if p.enabled == nil then p.enabled = true end
  if type(p.slots) ~= "table" then p.slots = {} end
  if type(p.fallback) ~= "table" then p.fallback = {} end
  ROGU_EnsureFallbackDefaultsOn(p.fallback)

  -- Per-character stats (rolling hour + lifetime total)
  if type(p.stats) ~= "table" then p.stats = {} end
  if p.stats.total == nil then p.stats.total = 0 end
  if type(p.stats.stamps) ~= "table" then p.stats.stamps = {} end
  if p.stats.head == nil then p.stats.head = 1 end
  if p.stats.lastReport == nil then p.stats.lastReport = 0 end

  ROGU_MigrateLegacyRootToProfile(db, p)

  return p, key
end


-------------------------------------------------
-- [2.4] Emote IDs sanitize + pick
-------------------------------------------------
local function ROGU_FindEmoteID(db, token)
  token = U.upper(token)
  if token == "" then return nil end
  local i = 1
  while db.emotes and db.emotes[i] do
    local e = db.emotes[i]
    if type(e) == "table" and type(e.emote) == "string" then
      if U.upper(e.emote) == token then
        return i
      end
    end
    i = i + 1
  end
  return nil
end

-- keeps only unique numeric ids within [1..#db.emotes], ensures at least {1}
local function ROGU_SanitizeEmoteIDs(cfg, db)
  if type(cfg.emoteIDs) ~= "table" then cfg.emoteIDs = {} end

  local maxID = table.getn(db.emotes or {})
  if maxID < 1 then
    ROGU_EnsureEmoteDefaults(db)
    maxID = table.getn(db.emotes)
  end

  local out, seen = {}, {}
  local i = 1
  while cfg.emoteIDs[i] ~= nil do
    local id = tonumber(cfg.emoteIDs[i])
    if id and id >= 1 and id <= maxID and not seen[id] then
      out[table.getn(out) + 1] = id
      seen[id] = true
    end
    i = i + 1
  end

  if table.getn(out) < 1 then out[1] = 1 end
  cfg.emoteIDs = out
end

local function ROGU_PickEmoteForCfg(cfg)
  local db = ROGU_EnsureDB()
  local ids = (cfg and cfg.emoteIDs) or nil
  if type(ids) ~= "table" or table.getn(ids) < 1 then ids = { 1 } end

  local id = tonumber(ids[math.random(1, table.getn(ids))]) or 1
  local entry = (db.emotes and db.emotes[id]) or nil
  local token = (entry and entry.emote) or "ROAR"
  token = U.upper(token)
  if token == "" then token = "ROAR" end
  return token
end

-------------------------------------------------
-- [2.4.9] Forward declarations for stats
-------------------------------------------------
local ROGU_StatsRecordEmote
local ROGU_StatsPerMinuteLastHour
local ROGU_StatsMaybeHourlyReport_OnActivity

-------------------------------------------------
-- [2.5] Load Once (bind runtime to current profile)
-------------------------------------------------
local function ROGU_LoadOnce()
  if ROGU._loaded then return end
  local db = ROGU_EnsureDB()
  local profile, key = ROGU_EnsureProfile(db)

  ROGU.profileKey = key
  ROGU.profile = profile
  ROGU.slots = profile.slots
  ROGU.fallback = profile.fallback
  ROGU.enabled = profile.enabled
  ROGU.stats = profile.stats


  for _, cfg in pairs(ROGU.slots) do
    if cfg.chance == nil then cfg.chance = 100 end
    if cfg.cd == nil then cfg.cd = 6 end
    if cfg.last == nil then cfg.last = 0 end
    if type(cfg.emoteIDs) ~= "table" or table.getn(cfg.emoteIDs) < 1 then cfg.emoteIDs = { 1 } end
    ROGU_SanitizeEmoteIDs(cfg, db)
  end

  ROGU_SanitizeEmoteIDs(ROGU.fallback, db)

  ROGU._loaded = true
end

local function ROGU_SyncToProfile()
  if not ROGU.profile then return end
  ROGU.profile.enabled = ROGU.enabled
  ROGU.profile.slots = ROGU.slots
  ROGU.profile.fallback = ROGU.fallback
  ROGU.profile.stats = ROGU.stats
end


-------------------------------------------------
-- [2.6] Features
-------------------------------------------------
local function ROGU_SendInvite(channelNum)
  local msg = U.pick(inviteText)
  if not msg or msg == "" then return end

  local ch = tonumber(channelNum) or 1
  if ch < 1 then ch = 1 end
  if ch > 10 then ch = 10 end

  SendChatMessage(msg, "CHANNEL", nil, ch)
end

local function ROGU_DoBattleEmoteForCfg(cfg, now)
  if not ROGU.enabled or not cfg then return end

  cfg.last = cfg.last or 0
  if now - cfg.last < (cfg.cd or 0) then return end
  cfg.last = now

  if math.random(1,100) <= (cfg.chance or 0) then
    local token = ROGU_PickEmoteForCfg(cfg)
    performEmote(token)
    ROGU.lastRoar = now

    if ROGU_StatsRecordEmote then
      ROGU_StatsRecordEmote()
    end
  end
end

local function ROGU_TryFallback(now, slot)
  if not ROGU.enabled then return end
  local fb = ROGU.fallback
  if type(fb) ~= "table" then return end
  if fb.enabled == false then return end
  if not slot or slot < 1 or slot > 200 then return end

  fb.last = fb.last or 0
  if now - fb.last < (fb.cd or 0) then return end

  local perm = tonumber(fb.chancePermille) or 0
  if perm < 0 then perm = 0 end
  if perm > 1000 then perm = 1000 end

  if math.random(1,1000) <= perm then
    local token = ROGU_PickEmoteForCfg(fb)
    performEmote(token)
    ROGU.lastRoar = now
    fb.last = now

    if ROGU_StatsRecordEmote then
      ROGU_StatsRecordEmote()
    end
  end
end

local function ROGU_MaybeReminder(now)
  if not ROGU.enabled then return end
  if ROGU.lastRoar > 0 then
    if now - ROGU.lastRoar >= ROAR_REMINDER_INTERVAL
       and now - (ROGU.lastReminder or 0) >= ROAR_REMINDER_CD then
      roarChat("You have not roared in a while.")
      ROGU.lastReminder = now
    end
  end
end

local function ROGU_ReportRestedXP()
  local r = GetXPExhaustion()
  if not r then roarChat("No rest."); return end

  local m = UnitXPMax("player")
  if not m or m == 0 then roarChat("No XP data."); return end

  local bubbles = math.floor((r * 20) / m + 0.5)
  if bubbles > 30 then bubbles = 30 end

  roarChat("Rest: "..bubbles.." bubbles ("..r.." XP)")
end

-------------------------------------------------
-- [2.6.5] Roarboard: shared guild message board
-------------------------------------------------
local RB_CHANNEL = "roarboard"
local RB_PREFIX = "RB1"
local RB_MAX_TEXT = 180
local RB_EXPIRY = 7 * 24 * 60 * 60
local RB_VISIBLE_ROWS = 12

local Roarboard = {
  db = nil,
  selectedID = nil,
  offset = 0,
  frame = nil,
  rows = nil,
  title = nil,
  body = nil,
  date = nil,
  count = nil,
}

local function RB_Now()
  if time then return time() end
  return math.floor(GetTime())
end

local function RB_Escape(s)
  s = tostring(s or "")
  s = string.gsub(s, "%%", "%%25")
  s = string.gsub(s, "|", "%%7C")
  s = string.gsub(s, "\r", " ")
  s = string.gsub(s, "\n", " ")
  return s
end

local function RB_Unescape(s)
  s = tostring(s or "")
  s = string.gsub(s, "%%7[Cc]", "|")
  s = string.gsub(s, "%%25", "%%")
  return s
end

local function RB_EnsureDB()
  local db = ROGU_EnsureDB()
  if type(db.roarboard) ~= "table" then db.roarboard = {} end
  local rb = db.roarboard
  if type(rb.posts) ~= "table" then rb.posts = {} end
  if type(rb.seen) ~= "table" then rb.seen = {} end
  Roarboard.db = rb
  return rb
end

local function RB_Prune()
  local rb = RB_EnsureDB()
  local cutoff = RB_Now() - RB_EXPIRY
  for id, post in pairs(rb.posts) do
    if type(post) ~= "table" or (tonumber(post.lastActivity) or tonumber(post.timestamp) or 0) < cutoff then
      rb.posts[id] = nil
      if Roarboard.selectedID == id then Roarboard.selectedID = nil end
    end
  end
  for id, stamp in pairs(rb.seen) do
    if (tonumber(stamp) or 0) < cutoff then rb.seen[id] = nil end
  end
end

local function RB_PostList()
  RB_Prune()
  local posts = {}
  for _, post in pairs(RB_EnsureDB().posts) do
    if type(post) == "table" then
      posts[table.getn(posts) + 1] = post
    end
  end
  table.sort(posts, function(a, b)
    return (tonumber(a.lastActivity) or tonumber(a.timestamp) or 0) > (tonumber(b.lastActivity) or tonumber(b.timestamp) or 0)
  end)
  return posts
end

local function RB_ChannelNumber()
  local ch = GetChannelName and GetChannelName(RB_CHANNEL) or 0
  return tonumber(ch) or 0
end

local function RB_JoinChannel()
  if RB_ChannelNumber() < 1 and JoinChannelByName then
    JoinChannelByName(RB_CHANNEL)
  end
end

local function RB_Send(payload)
  RB_JoinChannel()
  local ch = RB_ChannelNumber()
  if ch < 1 then
    roarChat("Roarboard channel is not ready. Try again in a moment.")
    return false
  end
  SendChatMessage(payload, "CHANNEL", nil, ch)
  return true
end

local function RB_RefreshUI()
  if not Roarboard.frame or not Roarboard.frame:IsShown() then return end
  local posts = RB_PostList()
  local maxOffset = table.getn(posts) - RB_VISIBLE_ROWS
  if maxOffset < 0 then maxOffset = 0 end
  if Roarboard.offset > maxOffset then Roarboard.offset = maxOffset end
  if Roarboard.offset < 0 then Roarboard.offset = 0 end

  local selected = nil
  local i = 1
  while i <= RB_VISIBLE_ROWS do
    local row = Roarboard.rows[i]
    local post = posts[Roarboard.offset + i]
    if post then
      local preview = string.gsub(post.text or "", "^%s*(.-)%s*$", "%1")
      if string.len(preview) > 42 then preview = string.sub(preview, 1, 39).."..." end
      row.postID = post.postID
      row:SetText((post.username or "?")..": "..preview)
      row:Show()
      if post.postID == Roarboard.selectedID then selected = post end
    else
      row.postID = nil
      row:Hide()
    end
    i = i + 1
  end

  if not selected and posts[1] then
    selected = posts[1]
    Roarboard.selectedID = selected.postID
  end
  if selected then
    Roarboard.title:SetText(selected.username or "Unknown")
    Roarboard.body:SetText(selected.text or "")
    Roarboard.date:SetText("Posted "..date("%Y-%m-%d %H:%M", tonumber(selected.timestamp) or 0))
    Roarboard.count:SetText("Roars: "..tostring(tonumber(selected.roarcount) or 0))
  else
    Roarboard.title:SetText("No active posts")
    Roarboard.body:SetText("Post with /roarboard <message> to start the board.")
    Roarboard.date:SetText("")
    Roarboard.count:SetText("")
  end
end

local function RB_ApplyPost(post)
  if type(post) ~= "table" or not post.postID or not post.username or not post.timestamp then return end
  local rb = RB_EnsureDB()
  local existing = rb.posts[post.postID]
  if not existing then
    rb.posts[post.postID] = post
  else
    existing.username = post.username
    existing.timestamp = post.timestamp
    existing.text = post.text
    if (tonumber(post.roarcount) or 0) > (tonumber(existing.roarcount) or 0) then
      existing.roarcount = tonumber(post.roarcount) or 0
    end
    if (tonumber(post.lastActivity) or 0) > (tonumber(existing.lastActivity) or 0) then
      existing.lastActivity = tonumber(post.lastActivity) or 0
    end
  end
  RB_Prune()
  RB_RefreshUI()
end

local function RB_NewPost(text)
  text = U.trim(text or "")
  if text == "" then return false end
  if string.len(text) > RB_MAX_TEXT then
    roarChat("Roarboard posts are limited to "..tostring(RB_MAX_TEXT).." characters.")
    return false
  end
  local username = UnitName("player") or "Unknown"
  local stamp = RB_Now()
  local post = {
    postID = username.."-"..tostring(stamp).."-"..tostring(math.random(1000, 9999)),
    username = username,
    timestamp = stamp,
    lastActivity = stamp,
    roarcount = 0,
    text = text,
  }
  local payload = RB_PREFIX.."|P|"..RB_Escape(post.postID).."|"..RB_Escape(username).."|"..tostring(stamp).."|"..tostring(stamp).."|0|"..RB_Escape(text)
  if not RB_Send(payload) then return false end
  RB_ApplyPost(post)
  return true
end

local function RB_Roar(postID)
  local post = RB_EnsureDB().posts[postID]
  if not post then return end
  local eventID = (UnitName("player") or "Unknown").."-"..tostring(RB_Now()).."-"..tostring(math.random(1000, 9999))
  local stamp = RB_Now()
  local payload = RB_PREFIX.."|R|"..RB_Escape(eventID).."|"..RB_Escape(postID).."|"..tostring(stamp).."|||"
  if not RB_Send(payload) then return end
  local rb = RB_EnsureDB()
  rb.seen[eventID] = stamp
  post.roarcount = (tonumber(post.roarcount) or 0) + 1
  post.lastActivity = stamp
  RB_RefreshUI()
end

local function RB_HandleMessage(msg)
  if type(msg) ~= "string" or string.sub(msg, 1, string.len(RB_PREFIX) + 1) ~= RB_PREFIX.."|" then return end
  local _, _, kind = string.find(msg, "^RB1|([^|]+)")
  if kind == "P" then
    local _, _, a, b, c, d, e, f = string.find(msg, "^RB1|P|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
    if not a then return end
    RB_ApplyPost({
      postID = RB_Unescape(a), username = RB_Unescape(b), timestamp = tonumber(c) or 0,
      lastActivity = tonumber(d) or tonumber(c) or 0, roarcount = tonumber(e) or 0, text = RB_Unescape(f),
    })
  elseif kind == "R" then
    local _, _, a, b, c = string.find(msg, "^RB1|R|([^|]*)|([^|]*)|([^|]*)")
    if not a then return end
    local eventID, postID, stamp = RB_Unescape(a), RB_Unescape(b), tonumber(c) or RB_Now()
    local rb = RB_EnsureDB()
    if not rb.seen[eventID] then
      rb.seen[eventID] = stamp
      local post = rb.posts[postID]
      if post then
        post.roarcount = (tonumber(post.roarcount) or 0) + 1
        post.lastActivity = stamp
        RB_RefreshUI()
      end
    end
  elseif kind == "S" then
    local posts = RB_PostList()
    local i = 1
    while posts[i] do
      local post = posts[i]
      RB_Send(RB_PREFIX.."|P|"..RB_Escape(post.postID).."|"..RB_Escape(post.username).."|"..tostring(post.timestamp).."|"..tostring(post.lastActivity or post.timestamp).."|"..tostring(post.roarcount or 0).."|"..RB_Escape(post.text))
      i = i + 1
    end
  end
end

local function RB_Show()
  RB_Prune()
  if not Roarboard.frame then
    local frame = CreateFrame("Frame", "RoarboardFrame", UIParent)
    frame:SetWidth(700)
    frame:SetHeight(460)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({ bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=32, insets={left=11,right=11,top=11,bottom=11} })
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    frame:Hide()
    tinsert(UISpecialFrames, "RoarboardFrame")

    local heading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOP", frame, "TOP", 0, -18)
    heading:SetText("Roarboard")
    local subheading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subheading:SetPoint("TOP", heading, "BOTTOM", 0, -3)
    subheading:SetText("A shared board for the people of ROAR")

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetTexture("Interface\\QuestFrame\\UI-QuestLog-QuestLogTab")
    divider:SetWidth(2)
    divider:SetHeight(365)
    divider:SetPoint("LEFT", frame, "LEFT", 238, -10)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    Roarboard.rows = {}
    local i = 1
    while i <= RB_VISIBLE_ROWS do
      local row = CreateFrame("Button", nil, frame)
      row:SetWidth(210)
      row:SetHeight(24)
      row:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -65 - ((i - 1) * 27))
      row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
      row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      row.text:SetPoint("LEFT", row, "LEFT", 3, 0)
      row.text:SetJustifyH("LEFT")
      row:SetFontString(row.text)
      row:SetScript("OnClick", function()
        Roarboard.selectedID = this.postID
        RB_RefreshUI()
      end)
      Roarboard.rows[i] = row
      i = i + 1
    end

    local up = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    up:SetWidth(90); up:SetHeight(22); up:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 22); up:SetText("Newer")
    up:SetScript("OnClick", function() Roarboard.offset = Roarboard.offset - RB_VISIBLE_ROWS; RB_RefreshUI() end)
    local down = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    down:SetWidth(90); down:SetHeight(22); down:SetPoint("LEFT", up, "RIGHT", 8, 0); down:SetText("Older")
    down:SetScript("OnClick", function() Roarboard.offset = Roarboard.offset + RB_VISIBLE_ROWS; RB_RefreshUI() end)

    Roarboard.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    Roarboard.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 265, -65)
    Roarboard.date = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    Roarboard.date:SetPoint("TOPLEFT", Roarboard.title, "BOTTOMLEFT", 0, -5)
    Roarboard.count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    Roarboard.count:SetPoint("TOPLEFT", Roarboard.date, "BOTTOMLEFT", 0, -3)
    Roarboard.body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    Roarboard.body:SetPoint("TOPLEFT", frame, "TOPLEFT", 265, -130)
    Roarboard.body:SetPoint("RIGHT", frame, "RIGHT", -35, 0)
    Roarboard.body:SetJustifyH("LEFT")
    Roarboard.body:SetJustifyV("TOP")

    local roar = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    roar:SetWidth(110); roar:SetHeight(26); roar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 265, 24); roar:SetText("Roar")
    roar:SetScript("OnClick", function() if Roarboard.selectedID then RB_Roar(Roarboard.selectedID) end end)
    Roarboard.frame = frame
  end
  Roarboard.frame:Show()
  RB_RefreshUI()
end


-------------------------------------------------
-- [2.7] Stats: lifetime total + rolling last hour
-------------------------------------------------

local STATS_WINDOW = 3600
local STATS_REPORT_INTERVAL = 3600

local function ROGU_Now()
  if time then return time() end
  return math.floor(GetTime())
end

local function ROGU_StatsPrune(now)
  local s = ROGU.stats
  if type(s) ~= "table" or type(s.stamps) ~= "table" then return end

  local cutoff = now - STATS_WINDOW
  local stamps = s.stamps
  local head = tonumber(s.head) or 1
  if head < 1 then head = 1 end

  while stamps[head] and stamps[head] <= cutoff do
    head = head + 1
  end
  s.head = head

  -- compact occasionally so stamps doesn't grow forever
  local n = table.getn(stamps)
  if head > 50 and head > math.floor(n / 2) then
    local out = {}
    local j = 1
    local i = head
    while stamps[i] do
      out[j] = stamps[i]
      j = j + 1
      i = i + 1
    end
    s.stamps = out
    s.head = 1
  end
end

local function ROGU_StatsCountLastHour()
  local s = ROGU.stats
  if type(s) ~= "table" or type(s.stamps) ~= "table" then return 0 end
  local n = table.getn(s.stamps)
  local head = tonumber(s.head) or 1
  if head < 1 then head = 1 end
  local c = n - head + 1
  if c < 0 then c = 0 end
  return c
end

ROGU_StatsRecordEmote = function()
  local s = ROGU.stats
  if type(s) ~= "table" then return end

  local now = ROGU_Now()
  if type(s.stamps) ~= "table" then s.stamps = {} end
  if s.head == nil then s.head = 1 end
  if s.total == nil then s.total = 0 end

  s.total = s.total + 1
  s.stamps[table.getn(s.stamps) + 1] = now

  -- keep rolling window clean on each emote
  ROGU_StatsPrune(now)
end

ROGU_StatsPerMinuteLastHour = function()
  local now = ROGU_Now()
  ROGU_StatsPrune(now)
  return ROGU_StatsCountLastHour() / 60
end

ROGU_StatsMaybeHourlyReport_OnActivity = function()
  local s = ROGU.stats
  if type(s) ~= "table" then return end

  local now = ROGU_Now()
  ROGU_StatsPrune(now)

  s.lastReport = tonumber(s.lastReport) or 0
  if s.lastReport == 0 then
    s.lastReport = now
    return
  end

  if now - s.lastReport < STATS_REPORT_INTERVAL then return end

  local count = ROGU_StatsCountLastHour()
  local perMin = count / 60
  local total = tonumber(s.total) or 0
  roarChat("total roars: "..tostring(total).." | last hour: "..tostring(count).." ("..string.format("%.1f", perMin).." per minute)")

  s.lastReport = now
end


-------------------------------------------------
-- [3] Hook UseAction
-------------------------------------------------
local _Orig_UseAction = UseAction

function UseAction(slot, checkCursor, onSelf)
  ROGU_LoadOnce()
  local now = GetTime()

  if ROGU.watchMode then
    roarChat("pressed slot "..tostring(slot))
  end

  for _, cfg in pairs(ROGU.slots) do
    if cfg.slot == slot then
      ROGU_DoBattleEmoteForCfg(cfg, now)
    end
  end

  -- Always-active independent fallback
  ROGU_TryFallback(now, slot)

  -- Reminder
  ROGU_MaybeReminder(now)

  -- Stats: prune + hourly report gate (only on slot activity)
  ROGU_StatsMaybeHourlyReport_OnActivity()


  return _Orig_UseAction(slot, checkCursor, onSelf)
end

-------------------------------------------------
-- [4] Slash Commands: /rogu
-------------------------------------------------
SLASH_ROGU1 = "/rogu"
SlashCmdList["ROGU"] = function(raw)
  ROGU_LoadOnce()
  local db = ROGU_EnsureDB()

  local cmd, rest = U.split_cmd(raw)
  cmd = U.upper(cmd)

  -------------------------------------------------
  -- [4.1] Core: help / info / enable
  -------------------------------------------------
  if cmd == "" or cmd == "HELP" then
    roarChat(" invite <1-10> | slotX <n> | chanceX <0-100> | timerX <sec> | fallback chance <0-1000> | fallback timer <sec> | emote <TOKEN> | emote list | emoteX <id|-id|clear|list> | watch | info | reset | resetcd | on | off | rexp | roar")
    return
  end

  if cmd == "INFO" then
    roarChat("version: "..ADDON_VERSION)
    roarChat("profile: "..tostring(ROGU.profileKey or "?"))
    roarChat("enabled: "..tostring(ROGU.enabled))
    roarChat("emotes in DB: "..tostring(table.getn(db.emotes)))

  local s = ROGU.stats
    if type(s) ~= "table" then
      roarChat("stats: not initialized")
    else
      local total = tonumber(s.total) or 0
      local perMin = 0
      if ROGU_StatsPerMinuteLastHour then
        perMin = ROGU_StatsPerMinuteLastHour()
      end
      roarChat("total roars: "..tostring(total))
      roarChat("last hour: "..string.format("%.1f", perMin).." per minute")
    end



    if type(ROGU.fallback) == "table" then
      local fb = ROGU.fallback
      ROGU_SanitizeEmoteIDs(fb, db)
      local fbids = ""
      local k = 1
      while fb.emoteIDs and fb.emoteIDs[k] do
        if fbids ~= "" then fbids = fbids.."," end
        fbids = fbids..tostring(fb.emoteIDs[k])
        k = k + 1
      end
      if fbids == "" then fbids = "1" end
      roarChat("fallback: enabled "..tostring(fb.enabled).." | cd "..tostring(fb.cd).."s | chance "..tostring(fb.chancePermille).."/1000 | emotes ["..fbids.."]")
    end

    for i,cfg in pairs(ROGU.slots) do
      ROGU_SanitizeEmoteIDs(cfg, db)
      local ids = ""
      for k=1,table.getn(cfg.emoteIDs or {}) do
        if ids ~= "" then ids = ids.."," end
        ids = ids..tostring(cfg.emoteIDs[k])
      end
      if ids == "" then ids = "1" end
      roarChat("instance"..tostring(i)..": slot "..tostring(cfg.slot).." | chance "..tostring(cfg.chance).."% | cd "..tostring(cfg.cd).."s | emotes ["..ids.."]")
    end
    return
  end

  if cmd == "ON" then
    ROGU.enabled = true
    ROGU_SyncToProfile()
    roarChat("enabled")
    return
  end

  if cmd == "OFF" then
    ROGU.enabled = false
    ROGU_SyncToProfile()
    roarChat("disabled")
    return
  end

  -------------------------------------------------
  -- [4.2] Social: invite + manual roar
  -------------------------------------------------
  if cmd == "INVITE" then
    local ch = U.trim(rest or "")
    if ch == "" then ch = "1" end
    ROGU_SendInvite(ch)
    return
  end

  if cmd == "ROAR" then
    performEmote("ROAR")
    if ROGU_StatsRecordEmote then
      ROGU_StatsRecordEmote()
    end
ROGU.lastRoar = GetTime()
return
  end

  -------------------------------------------------
  -- [4.3] Utility: rested XP
  -------------------------------------------------
  if cmd == "REXP" then
    ROGU_ReportRestedXP()
    return
  end

  -------------------------------------------------
  -- [4.4] Debug: watch pressed slots
  -------------------------------------------------
  if cmd == "WATCH" then
    ROGU.watchMode = not ROGU.watchMode
    roarChat("watch mode "..(ROGU.watchMode and "ON" or "OFF"))
    return
  end

  -------------------------------------------------
  -- [4.4.5] Fallback config: chance / timer
  -------------------------------------------------
  if cmd == "FALLBACK" then
    local sub, subrest = U.split_cmd(rest or "")
    sub = U.upper(sub)
    local fb = ROGU.fallback
    if type(fb) ~= "table" then
      fb = {}
      ROGU.fallback = fb
      ROGU_EnsureFallbackDefaultsOn(fb)
    end

    if sub == "CHANCE" then
      local n = tonumber(subrest)
      if n and n >= 0 and n <= 1000 then
        fb.chancePermille = n
        roarChat("fallback chance "..tostring(n).."/1000")
      else
        roarChat("usage: /rogu fallback chance <0-1000>")
      end
      return
    end

    if sub == "TIMER" then
      local n = tonumber(subrest)
      if n and n >= 0 then
        fb.cd = n
        roarChat("fallback cooldown "..tostring(n).."s")
      else
        roarChat("usage: /rogu fallback timer <sec>")
      end
      return
    end

    roarChat("usage: /rogu fallback chance <0-1000> | /rogu fallback timer <sec>")
    return
  end

  -------------------------------------------------
  -- [4.5]Instance config: slotX / chanceX / timerX
  -------------------------------------------------
  local _, _, slotIndex = string.find(cmd, "^SLOT(%d+)$")
  if slotIndex then
    local instance = tonumber(slotIndex)
    local slot = tonumber(rest)
    if instance and slot then
      ROGU.slots[instance] = ROGU.slots[instance] or { emoteIDs={1} }
      local cfg = ROGU.slots[instance]
      cfg.slot = slot
      cfg.chance = cfg.chance or 100
      cfg.cd = cfg.cd or 6
      cfg.last = 0
      ROGU_SanitizeEmoteIDs(cfg, db)
      roarChat("instance"..tostring(instance).." watching slot "..tostring(slot))
    else
      roarChat("usage: /rogu slotX <slot>")
    end
    return
  end

  local _, _, chanceIndex = string.find(cmd, "^CHANCE(%d+)$")
  if chanceIndex then
    local instance = tonumber(chanceIndex)
    local n = tonumber(rest)
    if ROGU.slots[instance] and n and n>=0 and n<=100 then
      ROGU.slots[instance].chance = n
      roarChat("instance"..tostring(instance).." chance "..tostring(n).."%")
    else
      roarChat("invalid instance or value")
    end
    return
  end

  local _, _, timerIndex = string.find(cmd, "^TIMER(%d+)$")
  if timerIndex then
    local instance = tonumber(timerIndex)
    local n = tonumber(rest)
    if ROGU.slots[instance] and n and n>=0 then
      ROGU.slots[instance].cd = n
      roarChat("instance"..tostring(instance).." cooldown "..tostring(n).."s")
    else
      roarChat("invalid instance or value")
    end
    return
  end

  -------------------------------------------------
  -- [4.6]Emote DB: add + list
  -------------------------------------------------
  if cmd == "EMOTE" then
    local sub = U.upper(rest)

    if sub == "LIST" then
      local i = 1
      while db.emotes and db.emotes[i] do
        local token = (type(db.emotes[i]) == "table" and db.emotes[i].emote) or ""
        token = U.upper(token)
        if token == "" then token = "?" end
        roarChat(tostring(i)..": "..token)
        i = i + 1
      end
      return
    end

    local token = U.upper(rest)
    if token == "" then
      roarChat("usage: /rogu emote <TOKEN> | /rogu emote list")
      return
    end

    local existing = ROGU_FindEmoteID(db, token)
    if existing then
      roarChat("emote exists: "..tostring(existing)..": "..token)
      return
    end

    local id = table.getn(db.emotes) + 1
    db.emotes[id] = { emote = token }
    roarChat("added emote "..tostring(id)..": "..token)

    for _, cfg in pairs(ROGU.slots) do
      ROGU_SanitizeEmoteIDs(cfg, db)
    end
    ROGU_SanitizeEmoteIDs(ROGU.fallback, db)
    return
  end

  -------------------------------------------------
  -- [4.7]Instance emote selection: emoteX add/remove/clear/list
  -------------------------------------------------
  local _, _, emoteIndex = string.find(cmd, "^EMOTE(%d+)$")
  if emoteIndex then
    local instance = tonumber(emoteIndex)
    if not instance then roarChat("invalid instance"); return end

    ROGU.slots[instance] = ROGU.slots[instance] or { slot=nil, chance=100, cd=6, last=0, emoteIDs={1} }
    local cfg = ROGU.slots[instance]
    local arg = U.trim(rest or "")

    if arg == "" then
      roarChat("usage: /rogu emote"..tostring(instance).." <id|-id|clear|list>")
      return
    end

    if string.lower(arg) == "clear" then
      cfg.emoteIDs = {1}
      roarChat("instance"..tostring(instance).." emotes set to: 1")
      return
    end

    if string.lower(arg) == "list" then
      ROGU_SanitizeEmoteIDs(cfg, db)
      local out = ""
      local i = 1
      while cfg.emoteIDs[i] do
        local id = cfg.emoteIDs[i]
        local tok = (db.emotes[id] and db.emotes[id].emote) or "ROAR"
        if out ~= "" then out = out.." | " end
        out = out..tostring(id)..":"..U.upper(tok)
        i = i + 1
      end
      roarChat("instance"..tostring(instance).." emotes: "..out)
      return
    end

    local remove = false
    if string.sub(arg, 1, 1) == "-" then
      remove = true
      arg = U.trim(string.sub(arg, 2))
    end

    local id = tonumber(arg)
    local maxID = table.getn(db.emotes)
    if not id or id < 1 or id > maxID then
      roarChat("invalid emote id (1-"..tostring(maxID)..")")
      return
    end

    ROGU_SanitizeEmoteIDs(cfg, db)

    if remove then
      local new = {}
      for i=1,table.getn(cfg.emoteIDs) do
        if cfg.emoteIDs[i] ~= id then
          new[table.getn(new)+1] = cfg.emoteIDs[i]
        end
      end
      if table.getn(new) < 1 then new[1] = 1 end
      cfg.emoteIDs = new
      roarChat("instance"..tostring(instance).." removed emote id "..tostring(id))
    else
      if U.arrayHas(cfg.emoteIDs, id) then
        roarChat("instance"..tostring(instance).." already has emote id "..tostring(id))
      else
        cfg.emoteIDs[table.getn(cfg.emoteIDs)+1] = id
        roarChat("instance"..tostring(instance).." added emote id "..tostring(id))
      end
    end
    return
  end

  -------------------------------------------------
  -- [4.8]Maintenance: reset instances / reset cooldown gates
  -------------------------------------------------
  if cmd == "RESET" then
    ROGU.slots = {}
    if ROGU.profile then
      ROGU.profile.slots = ROGU.slots
    end
    roarChat("all instances cleared")
    return
  end

  if cmd == "RESETCD" then
    -- reset per-instance cooldown gates
    for _, cfg in pairs(ROGU.slots or {}) do
      if type(cfg) == "table" then
        cfg.last = 0
      end
    end

    -- reset fallback throttle too
    if type(ROGU.fallback) == "table" then
      ROGU.fallback.last = 0
    end

    -- reset reminder timers
    ROGU.lastRoar = 0
    ROGU.lastReminder = 0

    ROGU_SyncToProfile()
    roarChat("cooldowns reset")
    return
  end

  roarChat(" invite <1-10> | slotX <n> | chanceX <0-100> | timerX <sec> | fallback chance <0-1000> | fallback timer <sec> | emote <TOKEN> | emote list | emoteX <id|-id|clear|list> | watch | info | reset | resetcd | on | off | rexp | roar")
end

-------------------------------------------------
-- [4.9] Roarboard commands
-------------------------------------------------
SLASH_ROARBOARD1 = "/roarboard"
SlashCmdList["ROARBOARD"] = function(raw)
  ROGU_LoadOnce()
  RB_EnsureDB()
  raw = U.trim(raw or "")
  if raw == "" then
    RB_Show()
    return
  end
  if U.upper(raw) == "SYNC" then
    if RB_Send(RB_PREFIX.."|S|0||||") then
      roarChat("Roarboard sync requested.")
    end
    return
  end
  RB_NewPost(raw)
end

-------------------------------------------------
-- [5] Init / Save
-------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LOGOUT")
f:RegisterEvent("CHAT_MSG_CHANNEL")

f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    math.randomseed(math.floor(GetTime() * 1000))
    math.random()

    -- ensure profile exists early
    ROGU_LoadOnce()

    -- reset all cooldown gates on login
    for _, cfg in pairs(ROGU.slots or {}) do
      if type(cfg) == "table" then
        cfg.last = 0
      end
    end

    if type(ROGU.fallback) == "table" then
      ROGU.fallback.last = 0
    end

    ROGU.lastRoar = 0
    ROGU.lastReminder = 0

    ROGU_SyncToProfile()
    RB_EnsureDB()
    RB_Prune()
    RB_JoinChannel()

  elseif event == "PLAYER_LOGOUT" then
    ROGU_SyncToProfile()

  elseif event == "CHAT_MSG_CHANNEL" then
    local channel = string.lower(tostring(arg9 or ""))
    local display = string.lower(tostring(arg8 or ""))
    if channel == RB_CHANNEL or string.find(display, RB_CHANNEL, 1, true) then
      RB_HandleMessage(arg1)
    end
  end
end)
