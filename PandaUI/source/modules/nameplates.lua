-- pandaUI :: modules/nameplates.lua
--
-- Replaces the client's floating nameplate art with pandaUI's own overlay:
--
--   Name .............................. Level
--   [==============  100.0%  ==============]
--
-- Name is anchored to the bar's left edge, level (difficulty coloured) to its
-- right edge, and the health percentage sits centred inside the bar. That is
-- the requested target layout; it is deliberately *not* pfUI's nameplate
-- layout, which centres the name over the plate and puts the level outside the
-- bar's left edge.
--
-- Theme art follows UnrealUI's nameplates: `modern-wow` draws Retail's
-- Cooldown Manager bar with the UI-HUD-Nameplates-Selected frame on the
-- target (M.modernWow.nameplate), `modern` a borderless flat bar, and
-- `classic-wow` the client's own UI-StatusBar fill.
--
-- The current target's plate also carries its debuffs (U.CreateNameplateAuraRows
-- in modules/auras.lua) and its cast (U.TargetCastInfo in modules/castbar.lua),
-- read through the "target" token. With Nampower every plate names its unit
-- (U.PlateGuid), so other plates show their debuffs and casts too (options
-- allPlateAuras / allPlateCasts); a stock client keeps the target-only path.
--
-- The options follow ShaguPlates' nameplate settings where they fit this
-- client, the same set UnrealUI adapted (C:\Games\Azeroth Launcher\
-- diagnostics\shaguplates-index; NAMEPLATES_ROADMAP.md tracks what is done
-- and what is not): sizes, hostile/friendly visibility, health text format,
-- per-disposition health-bar hiding, target outline and zoom, reaction
-- outlines, raid icons, name abbreviation, class colours, guild line, combo
-- points, totem icons and critter hiding. The settings pages are
-- modules/nameplatesettings.lua. ShaguPlates is intent only: no code, config
-- schema or assets are copied. Combat-state colours are Tank Mode
-- (style.TankKey). Not here: click handling and mouselook.
--
-- Compatibility notes that shaped this file:
--
--   * query_compat.py has NO record for nameplates, WorldFrame:GetChildren,
--     GetNumChildren, HookScript, ShowNameplates or the nameplate frame shape on
--     this client. Per the evidence-gap rule the discovery path follows what
--     UnrealPfUI does (modules/nameplates.lua: poll WorldFrame's children, take
--     the plate's regions and StatusBar children, read health from the native
--     bar). That is WORKING_SOURCE evidence, not runtime verification.
--   * UnrealPfUI keys the plate's parts off a fixed region *order*
--     (NAMEPLATE_OBJECTORDER) and a fixed border texture path. This client's
--     stock nameplate does not look like Vanilla's -- the observed plate draws a
--     name and a level and no health bar at all -- so an assumed order would map
--     the wrong region. Parts are therefore classified by what they actually
--     are (FontString vs Texture vs StatusBar child, and the texture's own
--     path), and everything unrecognised is muted. U.NameplateReport() prints
--     what was found so the guess can be replaced with measurement.
--   * A plate with no usable native health bar still gets a name/level row; the
--     bar is simply hidden rather than drawn empty.
--   * knowledge.json / scripts.child_onupdate_unreliable: no frame built here
--     owns an OnUpdate, and no script is hooked onto a native plate. Discovery
--     and refresh both run on the shared U.RegisterUpdate driver.
--   * knowledge.json / statusbar.native_widget_fill_not_laid_out: the bar is
--     U.CreateStatusBar, not the client's StatusBar widget.
--   * knowledge.json / rendering.native_texture_strip_requires_alpha: native
--     plate art is muted with SetTexture(nil) + SetAlpha(0) but deliberately
--     *not* Hide()d -- IsShown() on the native glow and elite icon is still the
--     only signal for mouseover and elite status.
--   * knowledge.json / fonts.stretched_justification_ignored: every label is
--     anchored to the one edge it belongs to, never stretched corner to corner.
--   * knowledge.json / core.getdifficultycolor_missing: level colour is taken
--     from the native level fontstring when it has one, with a local difficulty
--     helper as the fallback. No shim global is installed.

local U = PandaUI
local M = U.media

local NP = U.RegisterModule("nameplates")

-- ---------------------------------------------------------------------------
-- Configuration
--
-- Sizes are in plate units, before the UI scale the overlay inherits below.
-- ---------------------------------------------------------------------------
local defaults = {
  enabled        = true,
  width          = 160,
  healthHeight   = 17,
  nameSize       = 8,
  levelSize      = 12,
  healthTextSize = 11,
  verticalOffset = 0,
  showHealthText = true,
  showAuras      = true,   -- target debuffs at the configured plate corner
  auraPosition   = "TOPLEFT", -- TOPLEFT | TOPRIGHT | BOTTOMLEFT | BOTTOMRIGHT
  auraGap        = 20,     -- health-bar edge to the nearest aura-icon edge
  attachTargetCast = true, -- target cast under the target's plate
  allPlateAuras  = true,   -- Nampower: debuffs on every plate
  allPlateCasts  = true,   -- Nampower: casts under every plate
  fadeOthers     = true,   -- dim plates that are not the current target
  otherAlpha     = 0.75,
  showName       = true,   -- the unit's name above the bar
  -- Modern WoW's bar height, in art units before its `scale`.
  artHealthHeight = M.modernWow.nameplate.healthHeight,

  -- The client's own enemy/friendly plate switches, applied on login and on
  -- change (ShowNameplates & co. are documented 1.12.1, not runtime-verified
  -- on OctoWoW).
  showHostile    = true,
  showFriendly   = false,

  -- percent | current | curmax | curperc | deficit
  healthFormat   = "curmax",
  healthTextPos  = "CENTER", -- LEFT | CENTER | RIGHT
  abbrevNumbers  = false,    -- 4200 -> 4.2k
  abbrevNames    = true,     -- "Defias Pillager Captain" -> "D. P. Captain"

  -- Health bar hidden per disposition; the name and level row stays.
  hideEnemyNpc       = false,
  hideEnemyPlayer    = false,
  hideNeutralNpc     = false,
  hideFriendlyNpc    = false,
  hideFriendlyPlayer = false,
  keepHealthTarget   = true,  -- exceptions to the above
  keepHealthDamaged  = true,

  -- Target emphasis. The outline is the flat themes' 1-unit edge and Modern
  -- WoW's tinted selected-plate art (style.RefreshOutline). Colours are flat
  -- numbers: U.ModuleConfig copies a default table by reference.
  targetOutline  = false,
  highlightR     = M.color.accent[1],
  highlightG     = M.color.accent[2],
  highlightB     = M.color.accent[3],
  targetZoom     = false,
  targetZoomPercent = 25,

  -- Reaction outlines, drawn in the plate's reaction colour.
  outlineEnemy          = false,
  outlineNeutral        = false,
  outlineFriendlyNpc    = false,
  outlineFriendlyPlayer = false,

  -- Class colours for players named in core/playercache.lua.
  classColorEnemy        = true,
  classColorFriendly     = true,
  classColorFriendlyName = false,
  showGuild              = false,  -- guild line under the bar

  -- Totems (style.TotemIcon): hide their bar, or draw their icon instead.
  hideTotemHealth = true,
  totemIcons      = false,
  totemSize       = 24,
  hideCritterHealth = true,  -- style.IsCritter

  -- Combo points under the target's bar, filled points only.
  comboPoints    = true,
  comboSize      = 8,

  raidIcon       = true,
  raidIconPos    = "LEFT",    -- LEFT | TOP | RIGHT of the health bar
  raidIconSize   = 16,
  raidIconX      = 0,
  raidIconY      = 0,

  -- Tank Mode (style.TankKey): hostile NPCs in combat coloured by whom they
  -- target. Needs Nampower.
  tankMode         = false,
  tankAggroR       = 0,
  tankAggroG       = 1,
  tankAggroB       = 0,
  tankNoAggroR     = 1,
  tankNoAggroG     = 0,
  tankNoAggroB     = 0,
  tankShowInactive = false,
  tankInactiveR    = 0,
  tankInactiveG    = 0.45,
  tankInactiveB    = 1,
}

-- Option behaviour (see ShaguPlates' nameplate settings); one table so the
-- file's top-level local budget only pays once for it.
local style = {}

local cfg = defaults
local targetPlateActive = false
local targetOverlay = nil

function U.NameplatesEnabled()
  return U.ModuleConfig("nameplates", defaults).enabled and true or false
end

function U.SetNameplatesEnabled(value)
  value = value and true or false
  local settings = U.ModuleConfig("nameplates", defaults)
  if settings.enabled == value then return value end
  settings.enabled = value

  U.ShowConfirm({
    owner = "nameplates.enable-reload",
    centered = true,
    text = U.L("SETTINGS_NAMEPLATES_CHANGED"),
    detail = value and U.L("SETTINGS_NAMEPLATES_RELOAD_ON")
                   or U.L("SETTINGS_NAMEPLATES_RELOAD_OFF"),
    acceptText = U.L("COMMON_OK_SHORT"),
    cancelText = U.L("COMMON_CLOSE"),
  })
  return value
end

-- modules/castbar.lua hides its standalone target bar while this is true.
function U.NameplateTargetCastbarActive()
  return cfg.enabled and cfg.attachTargetCast and targetPlateActive
end

-- Read and written by modules/nameplatesettings.lua. A write is coerced to the
-- default's type, then every plate is re-laid-out and redrawn at once so a
-- slider drag shows on the world immediately.
function U.NameplateSetting(key)
  return cfg[key]
end

function U.SetNameplateSetting(key, value)
  local default = defaults[key]
  if default == nil then return end
  if type(default) == "boolean" then
    value = value and true or false
  elseif type(default) == "number" then
    value = tonumber(value) or default
  elseif type(value) ~= type(default) then
    return
  end
  local settings = U.ModuleConfig("nameplates", defaults)
  settings[key] = value
  cfg = settings
  if key == "showHostile" or key == "showFriendly" then
    style.ApplyVisibility()
  end
  style.Invalidate()
end

-- ---------------------------------------------------------------------------
-- Colours
--
-- Hostile / neutral / friendly (the "Reaction" section below decides which),
-- drawn in pandaUI's muted palette rather than the client's saturated
-- primaries.
-- ---------------------------------------------------------------------------
local UNIT_COLOR = {
  ENEMY         = { 0.75, 0.27, 0.32, 1.00 },
  NEUTRAL       = { 0.80, 0.72, 0.26, 1.00 },
  FRIENDLY_NPC  = { 0.35, 0.66, 0.34, 1.00 },
  FRIENDLY_UNIT = { 0.26, 0.50, 0.82, 1.00 },
}

-- ---------------------------------------------------------------------------
-- API access
--
-- Same contract as modules/unitframes.lua: resolve by name once, pcall the
-- call, coerce the result. Nothing here assumes a Vanilla return shape.
-- ---------------------------------------------------------------------------
local apiFnCache = {}

local function ResolveApiFn(name)
  local cached = apiFnCache[name]
  if cached ~= nil then
    if cached == false then return nil end
    return cached
  end

  local fn = U.G(name)
  if type(fn) == "function" then
    apiFnCache[name] = fn
    return fn
  end
  apiFnCache[name] = false
  return nil
end

local function ApiNumber(name, a, b)
  local fn = ResolveApiFn(name)
  if not fn then return nil end
  local ok, value = pcall(fn, a, b)
  if not ok then return nil end
  return tonumber(value)
end

local function ApiString(name, a, b)
  local fn = ResolveApiFn(name)
  if not fn then return nil end
  local ok, value = pcall(fn, a, b)
  if not ok or type(value) ~= "string" then return nil end
  return value
end

local function ApiTruth(name, a, b)
  local fn = ResolveApiFn(name)
  if not fn then return false end
  local ok, value = pcall(fn, a, b)
  if not ok then return false end
  if value == nil or value == false or value == 0 or value == "" then
    return false
  end
  return true
end

-- ---------------------------------------------------------------------------
-- Reaction
--
-- The 1.12.1 client already decides every plate's reaction: it tints the
-- native health bar red (hostile), yellow (neutral), green (friendly NPC) or
-- blue (friendly player), and re-tints it when a plate is recycled or a
-- neutral mob turns hostile. With no unit token per plate, that tint is the
-- only per-plate reaction signal a stock client has, so it is read first,
-- every pass, for every plate. pfUI-octo colours its plates from the same
-- tint on this client (GetUnitType; WORKING_112_SOURCE).
--
-- The tint is the colour of the bar's fill texture, so the native bar is
-- muted without destroying that texture (MuteHealthBar). Clearing it with
-- SetStatusBarTexture(nil) left nothing to read back: every plate fell
-- through to hostile until the target or mouseover taught its name.
--
-- Fallbacks, for a plate whose tint does not read back: the live target for
-- the target's own plate, then the reaction last seen live under that name
-- (target or mouseover), then a party/raid/guild member (style.CachedFriend),
-- then hostile.
-- ---------------------------------------------------------------------------
-- byName: name -> unit type seen live under it.
-- player: name -> whether that unit was a player, for the per-disposition
-- health-bar hiding (style.IsPlayer) and the class colours.
local reaction = { byName = {}, player = {} }

-- Stock tints are saturated primaries; the margins absorb float rounding.
function reaction.FromTint(r, g, b)
  if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
    return nil
  end
  if b < 0.3 then
    if r > 0.8 and g < 0.3 then return "ENEMY" end
    if r > 0.8 and g > 0.8 then return "NEUTRAL" end
    if r < 0.3 and g > 0.8 then return "FRIENDLY_NPC" end
  elseif b > 0.8 and r < 0.3 and g < 0.3 then
    return "FRIENDLY_UNIT"
  end
  return nil
end

function reaction.FromUnit(unit)
  if not ApiTruth("UnitExists", unit) then return nil end
  if ApiTruth("UnitIsPlayer", unit) and
     not ApiTruth("UnitCanAttack", "player", unit) then
    return "FRIENDLY_UNIT"
  end
  local value = ApiNumber("UnitReaction", unit, "player")
  if not value then return nil end
  if value <= 3 then return "ENEMY" end
  if value == 4 then return "NEUTRAL" end
  return "FRIENDLY_NPC"
end

-- A neutral mob the player's side has engaged is hostile, but nothing tells
-- the plate: the native tint stays yellow and UnitReaction stays 4 (user
-- report 2026-10-20). Engaged means in combat and attacking the player, the
-- pet or a party member -- or attacking nothing (stunned, feared, fleeing).
-- pfUI-octo's threat colouring uses per-plate GUID tokens; a stock client has
-- none, so only a unit token pandaUI can name is checked.
reaction.ENGAGED_BY = { "player", "pet", "party1", "party2", "party3", "party4" }

function reaction.Engaged(unit)
  if not ApiTruth("UnitAffectingCombat", unit) then return false end
  local victim = unit .. "target"
  if not ApiTruth("UnitExists", victim) then return true end
  local i
  for i = 1, table.getn(reaction.ENGAGED_BY) do
    if ApiTruth("UnitIsUnit", victim, reaction.ENGAGED_BY[i]) then
      return true
    end
  end
  return false
end

-- Engagement sticks to the plate, not the name, so switching target keeps
-- the mob red without colouring every mob that shares its name. It ends when
-- the player leaves combat, the target plate's mob leaves combat, or the
-- plate is recycled onto another unit (RefreshPlate clears it on hide).
function reaction.PlateEngaged(overlay, name)
  if not ApiTruth("UnitAffectingCombat", "player") then
    overlay.engaged = nil
    return false
  end
  if overlay.engaged ~= name then overlay.engaged = nil end
  if overlay.isTarget then
    if reaction.Engaged("target") then
      overlay.engaged = name
    elseif not ApiTruth("UnitAffectingCombat", "target") then
      overlay.engaged = nil
    end
  end
  return overlay.engaged ~= nil
end

function reaction.Learn(unit)
  local unitType = reaction.FromUnit(unit)
  local name = unitType and ApiString("UnitName", unit)
  if name then
    reaction.byName[name] = unitType
    reaction.player[name] = ApiTruth("UnitIsPlayer", unit)
  end
end

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------
-- Reads a method off a widget and calls it with no arguments. Every native
-- plate part is touched through here: the object may not have the method at
-- all on this client, and indexing a widget that is not a table would error
-- before the pcall around the call itself could help.
--
-- Deliberately argument-free. Lua 5.0's implicit `arg` table is not something
-- this runtime is verified to provide, so a vararg forwarder would be its own
-- unverified assumption; nothing here needs one.
--
-- The field read is a named upvalue rather than an anonymous closure: this runs
-- for every part of every plate five times a second, and building a closure per
-- call was the same allocation round 2 of
-- knowledge.json / compat.native_suppression_pcall_burst_stutter hoisted out of
-- core/compat.lua's sweep. The pcall boundary is unchanged -- the read still
-- fails independently of the call.
local readTarget, readMethod, readResult

local function ReadMethod()
  readResult = readTarget[readMethod]
end

local function Call(object, method)
  if not object then return nil end
  readTarget, readMethod, readResult = object, method, nil
  local ok = pcall(ReadMethod)
  local fn = readResult
  readTarget, readResult = nil, nil
  if not ok or type(fn) ~= "function" then return nil end
  local ok2, a, b, c, d = pcall(fn, object)
  if not ok2 then return nil end
  return a, b, c, d
end

local function ObjectType(object)
  local value = Call(object, "GetObjectType")
  if type(value) == "string" then return value end
  return nil
end

local function Clamp(value)
  if value < 0 then return 0 end
  if value > 1 then return 1 end
  return value
end

-- knowledge.json / core.getdifficultycolor_missing. Only used when the native
-- level fontstring has no colour to copy. Bands, colours and the
-- GetQuestGreenRange grey cut-off are kept identical to the unit frames'
-- DifficultyColor (modules/unitframes.lua) so the two never disagree about the
-- same mob; keep them in step if either is changed.
local function DifficultyColor(level)
  level = tonumber(level) or 0
  local playerLevel = ApiNumber("UnitLevel", "player") or 1
  local greenRange = ApiNumber("GetQuestGreenRange")
  if not greenRange or greenRange <= 0 then greenRange = 7 end

  if level <= 0 then return 0.69, 0.69, 0.69 end

  local diff = level - playerLevel
  if diff >= 5 then return 1.00, 0.10, 0.10 end
  if diff >= 3 then return 1.00, 0.50, 0.25 end
  if diff >= -2 then return 1.00, 1.00, 0.00 end
  if -diff <= greenRange then return 0.25, 0.75, 0.25 end
  return 0.50, 0.50, 0.50
end

-- Native plate art is silenced, not removed: IsShown() on the glow and the
-- elite icon stays the only readable signal for mouseover and classification.
-- rendering.native_texture_strip_requires_alpha is why the alpha is zeroed as
-- well as the texture cleared.
local function MuteTexture(region)
  if not region then return end
  pcall(function() region:SetTexture(nil) end)
  pcall(function() region:SetTexCoord(0, 0, 0, 0) end)
  pcall(function() region:SetAlpha(0) end)
end

-- GetText() and GetTextColor() must keep working: the name and level are
-- read back off these. SetAlpha(0) alone left the native name and level drawn
-- over the overlay on OctoWoW (user screenshot 2026-10-20), so the width is
-- squeezed to nothing as pfUI-octo's DisableObject does on this client
-- (WORKING_112_SOURCE); the alpha stays as a second layer.
local function MuteFontString(region)
  if not region then return end
  pcall(function() region:SetWidth(0.001) end)
  pcall(function() region:SetAlpha(0) end)
end

-- A native bar frame plus its own regions: parent_alpha_not_propagated means
-- zeroing the frame alone is not enough to stop the fill drawing.
local function MuteBar(bar)
  if not bar then return end
  pcall(function() bar:SetStatusBarTexture(nil) end)
  pcall(function() bar:SetAlpha(0) end)

  local ok, regions = pcall(function() return { bar:GetRegions() } end)
  if not ok or type(regions) ~= "table" then return end
  local i
  for i = 1, table.getn(regions) do
    if ObjectType(regions[i]) == "Texture" then MuteTexture(regions[i]) end
  end
end

-- The native health bar is still read every pass (value, min/max and the
-- reaction tint), so it is muted the way pfUI-octo mutes it on this client:
-- an empty fill path instead of nil, and none of its own regions touched.
-- The client keeps tinting that fill, and GetStatusBarColor reads it back.
local function MuteHealthBar(bar)
  if not bar then return end
  pcall(function() bar:SetStatusBarTexture("") end)
  pcall(function() bar:SetAlpha(0) end)
end

-- ---------------------------------------------------------------------------
-- Plate discovery
--
-- WORKING_SOURCE (UnrealPfUI modules/nameplates.lua): nameplates are anonymous
-- children of WorldFrame and appear as the child count grows. The *shape* test
-- upstream uses -- first region's texture is Interface\Tooltips\Nameplate-Border
-- -- is not reused, because this client's plate visibly is not Vanilla's.
-- Classification is structural instead.
-- ---------------------------------------------------------------------------
local registry = {}      -- native plate frame -> overlay
local plateOrder = {}    -- stable iteration order for the refresh pass
local scannedChildren = 0
local plateCount = 0

local stats = {
  worldChildren = 0,
  plates = 0,
  rejected = 0,
  withHealthBar = 0,
  detector = "none",
  -- Lowest and highest WorldFrame child count seen this session. This is the
  -- decisive measurement for whether nameplates are Lua frames here at all: if
  -- the count never moves while plates appear and disappear on screen, they are
  -- not WorldFrame children and no overlay approach can reach them.
  minChildren = -1,
  maxChildren = 0,
}

-- Why a WorldFrame child was not adopted. Measured first-pass result on this
-- client: 28 children, 0 plates, 28 rejected -- so the reason has to be
-- reportable rather than inferred from the layout not changing.
local rejectReasons = {}

local function Reject(reason)
  rejectReasons[reason] = (rejectReasons[reason] or 0) + 1
  return nil
end

local function IsNumericText(text)
  if type(text) ~= "string" then return false end
  return tonumber(text) ~= nil
end

-- Sorts a plate's regions and children into the parts pandaUI needs. Returns
-- nil when the frame does not look like a nameplate at all.
-- Work counters, same purpose as core/compat.lua's: this client has no
-- intra-frame profiler, so the only way to attribute a spike to a subsystem is
-- to count what it did. classified is the expensive one -- ClassifyPlate walks
-- every region and child of a WorldFrame child, and a *rejected* child is never
-- cached, so it is re-classified in full on every rescan.
local statScans, statRescans, statClassified, statRefreshed = 0, 0, 0, 0

local function ClassifyPlate(frame)
  statClassified = statClassified + 1

  -- pandaUI's own overlay: UnrealUI measured it listed as a WorldFrame child
  -- and adopted (muted) one frame after its plate. Never adopt it here.
  local ownName = Call(frame, "GetName")
  if type(ownName) == "string" and
     string.find(ownName, "^PandaUINamePlate%d+$") then
    return Reject("own-overlay")
  end
  -- The object type is recorded, not gated on. Measured: gating on
  -- Button/Frame plus "plates are anonymous" rejected all 28 WorldFrame
  -- children on this client -- and this runtime auto-names objects
  -- (GeneratedLuaUIObject_NNNN appears in frames.getpoint_relative_name_y
  -- _inverted), so a name-based filter cannot distinguish a plate from
  -- anything else here. Structure is the only usable signal.
  local ok, regions = pcall(function() return { frame:GetRegions() } end)
  if not ok or type(regions) ~= "table" then
    return Reject("no-getregions")
  end

  local parts = { textures = {}, fontstrings = {} }
  local i

  for i = 1, table.getn(regions) do
    local region = regions[i]
    local regionType = ObjectType(region)

    if regionType == "FontString" then
      table.insert(parts.fontstrings, region)
    elseif regionType == "Texture" then
      table.insert(parts.textures, region)

      local texture = Call(region, "GetTexture")
      if type(texture) == "string" then
        if string.find(texture, "Nameplate%-Border") then
          parts.border = region
        elseif string.find(texture, "Nameplate%-Glow") or
               string.find(texture, "Glow") then
          parts.glow = region
        elseif string.find(texture, "Elite") or string.find(texture, "Rare") then
          parts.levelicon = region
        elseif string.find(texture, "RaidTargetingIcon") then
          parts.raidicon = region
        end
      end
    end
  end

  local kidsOk, kids = pcall(function() return { frame:GetChildren() } end)
  if kidsOk and type(kids) == "table" then
    for i = 1, table.getn(kids) do
      local kid = kids[i]
      local kidType = ObjectType(kid)
      -- GetValue is the part that matters; the widget's reported type is not
      -- assumed to be "StatusBar" on this client.
      local hasValue = false
      pcall(function() hasValue = type(kid.GetValue) == "function" end)

      if kidType == "StatusBar" or hasValue then
        if not parts.healthbar then
          parts.healthbar = kid
        elseif not parts.castbar then
          parts.castbar = kid
        end
      end
    end
  end

  -- Accept on any of three independent signatures, so a Vanilla-shaped plate
  -- and this client's own shape both resolve. Which one matched is recorded for
  -- U.NameplateReport().
  --
  -- Each signature still demands a *combination*, never a single generic trait:
  -- adopting a plate mutes its native art for the rest of the session, so a
  -- false positive on some other WorldFrame child is not a cosmetic mistake.
  -- /pui np dumps every child so the threshold can be checked against what is
  -- really there rather than loosened blind.
  local fontCount = table.getn(parts.fontstrings)

  local detector
  if parts.border then
    detector = "border-texture"
  elseif parts.healthbar and fontCount >= 1 then
    detector = "healthbar+name"
  elseif fontCount >= 2 then
    detector = "name+level-fontstrings"
  else
    return Reject("shape " .. tostring(ObjectType(frame)) ..
                  " tex=" .. table.getn(parts.textures) ..
                  " fs=" .. fontCount ..
                  " bar=" .. (parts.healthbar and "y" or "n"))
  end

  parts.detector = detector

  -- The level is whichever fontstring currently reads as a number; the name is
  -- the first one that is not it. Re-checked on refresh, because a plate is
  -- recycled onto a different unit without being rebuilt.
  local first, second = parts.fontstrings[1], parts.fontstrings[2]
  if IsNumericText(Call(first, "GetText")) and second then
    parts.level, parts.name = first, second
  else
    parts.name, parts.level = first, second
  end

  return parts
end

-- ---------------------------------------------------------------------------
-- Options: layout, health text, health-bar hiding, outlines, zoom, raid icon
--
-- Behaviour follows ShaguPlates' options (modules/nameplates.lua HidePlate,
-- GetNameString, OnDataChanged's hp text, OnUpdate's zoom) -- WORKING_SOURCE
-- for intent only; nothing here reuses its code or config schema.
-- ---------------------------------------------------------------------------

-- A name seen live as the target or mouseover is known, then a name the player
-- cache read from a party, raid or guild unit (core/playercache.lua);
-- otherwise a name the bundled creature index does not list is taken for a
-- player. That heuristic also counts player pets and creatures missing from
-- the index as players.
function style.IsPlayer(name)
  if not name then return false end
  local known = reaction.player[name]
  if known ~= nil then return known end
  if type(U.PlayerKnown) == "function" and U.PlayerKnown(name) then
    return true
  end
  if type(U.unitNames) ~= "table" then return false end
  return U.unitNames[name] == nil
end

style.HIDE_KEY = {
  ENEMY         = { npc = "hideEnemyNpc",       player = "hideEnemyPlayer" },
  NEUTRAL       = { npc = "hideNeutralNpc",     player = "hideNeutralNpc" },
  FRIENDLY_NPC  = { npc = "hideFriendlyNpc",    player = "hideFriendlyPlayer" },
  FRIENDLY_UNIT = { npc = "hideFriendlyPlayer", player = "hideFriendlyPlayer" },
}

style.OUTLINE_KEY = {
  ENEMY = "outlineEnemy",
  NEUTRAL = "outlineNeutral",
  FRIENDLY_NPC = "outlineFriendlyNpc",
  FRIENDLY_UNIT = "outlineFriendlyPlayer",
}

-- ---------------------------------------------------------------------------
-- Class colours (core/playercache.lua)
--
-- ShaguPlates' enemyclassc / friendclassc / friendclassnamec, by intent. The
-- cache answers by name; a name seen live as a creature (reaction.player
-- false) is never coloured, so an NPC sharing a player's name keeps its
-- reaction colour.
-- ---------------------------------------------------------------------------

-- A name the cache knows but the reaction cache has never seen live came from
-- the party, raid or guild roster: always the player's own side.
function style.CachedFriend(name)
  if type(U.PlayerKnown) == "function" and U.PlayerKnown(name) and
     reaction.player[name] ~= false then
    return "FRIENDLY_UNIT"
  end
  return nil
end

function style.ClassOf(name)
  if type(U.PlayerInfo) ~= "function" or reaction.player[name] == false then
    return nil
  end
  local token = U.PlayerInfo(name)
  if token and M.ClassColor(token) then return token end
  return nil
end

style.FRIENDLY_TYPE = { FRIENDLY_UNIT = true, FRIENDLY_NPC = true }

-- The bar takes the Tank Mode colour when style.TankKey names one, else the
-- class colour for an enemy or a friendly player when its option is on, else
-- the reaction colour; a friendly player's name takes the class colour with
-- classColorFriendlyName. Cached per plate on the resolved key.
function style.RefreshColors(overlay, unitType, name, tankKey)
  local class = name and style.ClassOf(name)
  local friendly = style.FRIENDLY_TYPE[unitType] and true or false
  local barClass = class and ((friendly and cfg.classColorFriendly) or
                              (not friendly and cfg.classColorEnemy)) and
                   class or nil
  local barKey = tankKey or barClass or unitType
  if barKey ~= overlay.cache.barColor then
    overlay.cache.barColor = barKey
    if tankKey then
      local keys = style.TANK_RGB[tankKey]
      U.SetStatusBarColor(overlay.health, cfg[keys[1]], cfg[keys[2]],
                          cfg[keys[3]], 1)
    elseif barClass then
      U.SetStatusBarColor(overlay.health, M.ClassColor(barClass))
    else
      U.SetStatusBarColor(overlay.health, M.Unpack(UNIT_COLOR[unitType]))
    end
  end

  if not overlay.name then return end
  local nameClass = class and friendly and cfg.classColorFriendlyName and
                    class or nil
  local nameKey = nameClass or "plain"
  if nameKey == overlay.cache.nameColor then return end
  overlay.cache.nameColor = nameKey
  local r, g, b = 1, 1, 1
  if nameClass then r, g, b = M.ClassColor(nameClass) end
  pcall(overlay.name.SetTextColor, overlay.name, r, g, b, 1)
end

-- ---------------------------------------------------------------------------
-- Tank Mode
--
-- Behaviour after BlizzNameplatesPlus' Tank Mode (no code taken): a living,
-- untapped-or-ours hostile NPC in combat is TANK_AGGRO while it targets the
-- player, TANK_NO_AGGRO while it targets any other unit, and optionally
-- TANK_INACTIVE while stunned, confused or fleeing. A missing or unreadable
-- target is never TANK_NO_AGGRO: the plate keeps its ordinary colour.
--
-- Needs Nampower: the plate's GUID names the unit, "<guid>target" its victim
-- and GetUnitField(guid, "flags") its combat and control state
-- (knowledge.json / nameplates.tank_mode_guid_target_flags). The masks are
-- decimal because Lua 5.0 has no hex literals.
-- ---------------------------------------------------------------------------
style.TANK_RGB = {
  TANK_AGGRO    = { "tankAggroR", "tankAggroG", "tankAggroB" },
  TANK_NO_AGGRO = { "tankNoAggroR", "tankNoAggroG", "tankNoAggroB" },
  TANK_INACTIVE = { "tankInactiveR", "tankInactiveG", "tankInactiveB" },
}
style.FLAG_STUNNED  = 262144   -- UNIT_FLAG_STUNNED
style.FLAG_COMBAT   = 524288   -- UNIT_FLAG_IN_COMBAT
style.FLAG_CONFUSED = 4194304  -- UNIT_FLAG_CONFUSED
style.FLAG_FLEEING  = 8388608  -- UNIT_FLAG_FLEEING

function style.HasFlag(flags, mask)
  return math.mod(math.floor(flags / mask), 2) == 1
end

-- A summon, guardian or totem whose owner is a player (high GUID word zero).
function style.PlayerOwned(guid)
  local fn = ResolveApiFn("GetUnitField")
  if not fn then return false end
  local fields = style.OWNER_FIELDS
  local i
  for i = 1, table.getn(fields) do
    local ok, owner = pcall(fn, guid, fields[i])
    if ok and type(owner) == "string" and owner ~= "0x0000000000000000" and
       string.find(owner, "^0x00000000") then
      return true
    end
  end
  return false
end
style.OWNER_FIELDS = { "summonedBy", "createdBy", "charmedBy" }

-- What never changes for one GUID, read once when a plate takes it.
function style.TankBind(overlay, guid)
  overlay.tankGuid = guid
  overlay.tankToken = guid .. "target"
  overlay.tankUnit = not ApiTruth("UnitIsPlayer", guid) and
                     not ApiTruth("UnitPlayerControlled", guid) and
                     not style.PlayerOwned(guid)
end

function style.TankClear(overlay)
  overlay.tankGuid = nil
  overlay.tankToken = nil
  overlay.tankUnit = nil
end

-- The Tank Mode colour key for a visible plate, or nil for its ordinary
-- colour. alive is false only when the native bar reads zero health.
function style.TankKey(overlay, alive)
  local guid = overlay.guid
  if not guid then return nil end
  if overlay.tankGuid ~= guid then style.TankBind(overlay, guid) end
  if not overlay.tankUnit or not alive then return nil end

  -- Combat first: it is the cheap exit for every plate outside a pull, and
  -- it keeps neutral mobs yellow until they are engaged.
  local flags = ApiNumber("GetUnitField", guid, "flags")
  local inCombat
  if flags then
    if flags < 0 then flags = flags + 4294967296 end
    inCombat = style.HasFlag(flags, style.FLAG_COMBAT)
  else
    inCombat = ApiTruth("UnitAffectingCombat", guid)
  end
  if not inCombat then return nil end

  if not ApiTruth("UnitCanAttack", "player", guid) or
     ApiTruth("UnitIsDead", guid) then
    return nil
  end
  if ApiTruth("UnitIsTapped", guid) and
     not ApiTruth("UnitIsTappedByPlayer", guid) then
    return nil
  end

  if cfg.tankShowInactive and flags and
     (style.HasFlag(flags, style.FLAG_STUNNED) or
      style.HasFlag(flags, style.FLAG_CONFUSED) or
      style.HasFlag(flags, style.FLAG_FLEEING)) then
    return "TANK_INACTIVE"
  end

  -- UnitExists, not UnitIsUnit(token, token): the latter is true for a mob
  -- with no target (probe platetank.v1), which would have drawn it red.
  local token = overlay.tankToken
  if not ApiTruth("UnitExists", token) then return nil end
  if ApiTruth("UnitIsUnit", token, "player") then return "TANK_AGGRO" end
  return "TANK_NO_AGGRO"
end

-- ---------------------------------------------------------------------------
-- Totems
--
-- ShaguPlates' totems / totemicons, by intent: hide a totem's health bar, or
-- replace its plate with the totem's spell icon. Totems are found by creature
-- id rather than by name: the bundled name tables (Database/unit_names*.lua,
-- U.unitNames) map the client's own enUS, ruRU or zhCN name to the same ids,
-- so this one table needs no translation. A frFR client has no localized name
-- table, so its totems are not recognised. Ids: every rank of each shaman
-- totem in the enUS table; icons: each totem spell's icon (WORKING_SOURCE:
-- the same art names ShaguPlates' enUS table lists, plus Tranquil Air). A
-- literal Interface\Icons path is what modules/bankview.lua's fallback
-- already draws.
-- ---------------------------------------------------------------------------
style.TOTEM_IDS = {
  Spell_Nature_DiseaseCleansingTotem = { 5924 }, -- Disease Cleansing Totem
  Spell_Nature_StrengthOfEarthTotem02 = { 2630 }, -- Earthbind Totem
  Spell_Fire_SealOfFire = { 5879, 6110, 6111, 7844, 7845 }, -- Fire Nova Totem
  Spell_FireResistanceTotem_01 = { 5927, 7424, 7425 }, -- Fire Resistance Totem
  Spell_Nature_GuardianWard = { 5950, 6012, 7423, 10557 }, -- Flametongue Totem
  Spell_FrostResistanceTotem_01 = { 5926, 7412, 7413 }, -- Frost Resistance Totem
  Spell_Nature_InvisibilityTotem = { 7486, 7487, 15463 }, -- Grace of Air Totem
  Spell_Nature_GroundingTotem = { 5925 }, -- Grounding Totem
  INV_Spear_04 = { 3527, 3906, 3907, 3908, 3909 }, -- Healing Stream Totem
  Spell_Fire_SelfDestruct = { 5929, 7464, 7465, 7466 }, -- Magma Totem
  Spell_Nature_ManaRegenTotem = { 3573, 7414, 7415, 7416 }, -- Mana Spring Totem
  Spell_Frost_SummonWaterElemental = { 10467, 11100, 11101 }, -- Mana Tide Totem
  Spell_Nature_NatureResistanceTotem = { 7467, 7468, 7469 }, -- Nature Resistance Totem
  Spell_Nature_PoisonCleansingTotem = { 5923 }, -- Poison Cleansing Totem
  Spell_Fire_SearingTotem = { 2523, 3902, 3903, 3904, 7400, 7402 }, -- Searing Totem
  Spell_Nature_RemoveCurse = { 3968 }, -- Sentry Totem
  Spell_Nature_StoneClawTotem = { 3579, 3911, 3912, 3913, 7398, 7399 }, -- Stoneclaw Totem
  Spell_Nature_StoneSkinTotem = { 5873, 5919, 5920, 7366, 7367, 7368 }, -- Stoneskin Totem
  Spell_Nature_EarthBindTotem = { 5874, 5921, 5922, 7403, 15464 }, -- Strength of Earth Totem
  Spell_Nature_Brilliance = { 15803 }, -- Tranquil Air Totem
  Spell_Nature_TremorTotem = { 5913 }, -- Tremor Totem
  Spell_Nature_Windfury = { 6112, 7483, 7484 }, -- Windfury Totem
  Spell_Nature_EarthBind = { 9687, 9688, 9689 }, -- Windwall Totem
}
style.totemByName = {}

-- The totem's icon path, or nil. Cached per name (false for "not a totem").
function style.TotemIcon(name)
  if not name then return nil end
  local cached = style.totemByName[name]
  if cached ~= nil then return cached or nil end
  if not style.totemById then
    style.totemById = {}
    local icon, ids, i
    for icon, ids in pairs(style.TOTEM_IDS) do
      for i = 1, table.getn(ids) do
        style.totemById[ids[i]] = "Interface\\Icons\\" .. icon
      end
    end
  end
  local result = false
  local entry = type(U.unitNames) == "table" and U.unitNames[name]
  if type(entry) == "number" then
    result = style.totemById[entry] or false
  elseif type(entry) == "table" then
    local i
    for i = 1, table.getn(entry) do
      if style.totemById[entry[i]] then
        result = style.totemById[entry[i]]
        break
      end
    end
  end
  style.totemByName[name] = result
  return result or nil
end

-- ---------------------------------------------------------------------------
-- Critters
--
-- ShaguPlates' critters option, by intent: hide a critter's health bar. Same
-- id route as the totems above. The ids are every creature_template entry of
-- type 8 (Critter), patch <= 10, in the VMaNGOS database
-- tools/import_unit_reactions.py reads, less six GM, test and trigger
-- entries; all 93 are in the enUS and ruRU name tables, and all but Roach
-- (merged with Cockroach, so left out) in zhCN. A name counts only when every
-- id sharing it is a critter, so a critter name reused by a real creature is
-- never hidden.
-- ---------------------------------------------------------------------------
style.CRITTER_IDS = {
  385, 582, 620, 721, 883, 890, 1262, 1352, 1412, 1420, 1932, 1933, 2098,
  2110, 2442, 2620, 2848, 2914, 3300, 3444, 3681, 3835, 4075, 4076, 4166,
  4953, 5689, 5739, 5740, 5741, 5742, 5743, 5866, 5867, 5868, 5951, 6145,
  6271, 6368, 6653, 6827, 7208, 8881, 8963, 9600, 9699, 9700, 10016, 10017,
  10441, 10461, 10510, 10536, 10582, 10685, 10716, 10779, 10780, 11776,
  12120, 12152, 12296, 12297, 12298, 12299, 12383, 13016, 13017, 13321,
  13338, 14361, 14681, 14801, 14881, 14886, 14892, 15010, 15065, 15066,
  15071, 15072, 15219, 15475, 15476, 16030, 16068, 16369, 16372, 16373,
  16479, 16779, 16998, 18078,
}
style.critterByName = {}

function style.IsCritter(name)
  if not name then return false end
  local cached = style.critterByName[name]
  if cached ~= nil then return cached end
  if not style.critterSet then
    style.critterSet = {}
    local i
    for i = 1, table.getn(style.CRITTER_IDS) do
      style.critterSet[style.CRITTER_IDS[i]] = true
    end
  end
  local result = false
  local entry = type(U.unitNames) == "table" and U.unitNames[name]
  if type(entry) == "number" then
    result = style.critterSet[entry] or false
  elseif type(entry) == "table" and table.getn(entry) > 0 then
    result = true
    local i
    for i = 1, table.getn(entry) do
      if not style.critterSet[entry[i]] then result = false end
    end
  end
  style.critterByName[name] = result
  return result
end

-- Icon mode: the totem's icon in place of the plate. The name, level, health
-- text and bar step aside (style.HideHealth hides the bar); the raid mark,
-- cast bar and combo points keep working.
function style.RefreshTotem(overlay, name)
  local icon = cfg.totemIcons and style.TotemIcon(name) or nil
  overlay.totemShown = icon and true or false

  -- The name: showName (user request, 2026-10-20), and never beside a totem
  -- icon.
  local showName = cfg.showName and not overlay.totemShown
  if overlay.name and showName ~= overlay.cache.nameShown then
    overlay.cache.nameShown = showName
    if showName then overlay.name:Show() else overlay.name:Hide() end
  end

  if (icon or false) == overlay.cache.totem then return end
  overlay.cache.totem = icon or false
  local texture = overlay.totemIcon
  if icon then
    texture:SetTexture(icon)
    texture:Show()
    if overlay.level then overlay.level:Hide() end
  else
    texture:Hide()
    if overlay.level then overlay.level:Show() end
  end
end

function style.HideHealth(overlay, unitType, name, damaged)
  if overlay.totemShown then return true end
  if cfg.keepHealthTarget and overlay.isTarget then return false end
  if cfg.keepHealthDamaged and damaged then return false end
  if cfg.hideTotemHealth and style.TotemIcon(name) then return true end
  if cfg.hideCritterHealth and style.IsCritter(name) then return true end
  local keys = style.HIDE_KEY[unitType]
  if not keys then return false end
  return cfg[style.IsPlayer(name) and keys.player or keys.npc] and true or false
end

function style.Number(value)
  value = math.floor(value + 0.5)
  if cfg.abbrevNumbers then
    if value >= 1000000 then
      return string.format("%.1fm", value / 1000000)
    elseif value >= 1000 then
      return string.format("%.1fk", value / 1000)
    end
  end
  return tostring(value)
end

-- current/total are real hitpoints from Nampower or the bundled fallback, nil
-- when neither source knows them; fraction (0..1) always exists. The
-- percent is rounded up like the unit frames' (U.CeilPercent): rounding to
-- nearest printed 0% on a target whose frame still read 1%.
function style.HealthText(current, total, fraction)
  local format = cfg.healthFormat
  local whole = U.CeilPercent(fraction)
  local pct = whole .. "%"
  if not current or not total then
    if format == "deficit" then
      if whole >= 100 then return "" end
      return "-" .. (100 - whole) .. "%"
    end
    return pct
  end
  if format == "percent" then return pct end
  if format == "current" then return style.Number(current) end
  if format == "curperc" then
    return style.Number(current) .. " (" .. pct .. ")"
  end
  if format == "deficit" then
    if total - current < 0.5 then return "" end
    return "-" .. style.Number(total - current)
  end
  return style.Number(current) .. " / " .. style.Number(total)
end

-- First character, whole: a byte cut would break a Cyrillic or CJK name.
function style.Initial(word)
  local _, last = string.find(word, "^[\1-\127\192-\255][\128-\191]*")
  return string.sub(word, 1, last or 1) .. ". "
end

-- Characters, not bytes: "Y. Thalassian Boar" is the longest name the plate
-- shows whole (user request, 2026-10-20).
style.NAME_LIMIT = 18

-- UTF-8 character count, and the byte index where character n ends.
function style.CharCount(text)
  local _, count = string.gsub(text, "[^\128-\191]", "")
  return count
end

function style.CharEnd(text, n)
  local pos, i = 0, 0
  while i < n do
    local _, last = string.find(text, "^[\1-\127\192-\255][\128-\191]*", pos + 1)
    if not last then break end
    pos, i = last, i + 1
  end
  return pos
end

-- ShaguPlates' GetNameString: shorten the first word, then every word but the
-- last, until the name fits. Whatever is still too long, abbreviated or not,
-- is cut with "..." so it stays clear of the level.
function style.Name(name)
  if type(name) ~= "string" then return name end
  local limit = style.NAME_LIMIT
  if style.CharCount(name) <= limit then return name end
  if cfg.abbrevNames then
    name = string.gsub(name, "^(%S+) ", style.Initial)
    if style.CharCount(name) > limit then
      name = string.gsub(name, "(%S+) ", style.Initial)
    end
    if style.CharCount(name) <= limit then return name end
  end
  local cut = string.sub(name, 1, style.CharEnd(name, limit - 3))
  return (string.gsub(cut, "[%s%.]+$", "")) .. "..."
end

-- Offsets are in the overlay's own scale, so a zoomed plate divides them back
-- out and stays where the unzoomed one was. No PLATE_LIFT: that was an Unreal
-- plate-shape correction (knowledge.json
-- nameplates.pandaui_theme_auras_castbar_unverified, unrealComparison).
function style.Anchor(overlay)
  overlay:ClearAllPoints()
  overlay:SetPoint("TOP", overlay.plate, "TOP", 0,
                   cfg.verticalOffset / (overlay.zoom or 1))
end

-- The client pushes overlapping plates apart by the *native* frame's size, and
-- that frame is far larger than the overlay (198.9 x 49.7 measured,
-- PandaUIDiagDB.nameplateDump 2026-10-20), so a plate near another one was
-- shoved well away from its unit. WORKING_112_SOURCE (pfUI-octo nameplates.lua,
-- non-overlap mode): size the native frame to the overlay, in the plate's own
-- units (UI scale, not the target zoom), so only plates that visibly overlap
-- are moved. Checked every pass: pfUI-octo re-applies it on this client.
function style.FitNative(overlay)
  local plate = overlay.plate
  local scale = UIParent:GetScale()
  local width = overlay:GetWidth() * scale
  local height = overlay:GetHeight() * scale
  local nativeWidth = tonumber(Call(plate, "GetWidth")) or 0
  local nativeHeight = tonumber(Call(plate, "GetHeight")) or 0
  if math.abs(nativeWidth - width) < 0.5 and
     math.abs(nativeHeight - height) < 0.5 then return end
  pcall(plate.SetWidth, plate, width)
  pcall(plate.SetHeight, plate, height)
end

function style.LayoutRaidIcon(overlay)
  local icon = overlay.raidIcon
  if not icon then return end
  local size, x, y = cfg.raidIconSize, cfg.raidIconX, cfg.raidIconY
  icon:SetWidth(size)
  icon:SetHeight(size)
  icon:ClearAllPoints()
  if cfg.raidIconPos == "TOP" then
    icon:SetPoint("BOTTOM", overlay.health, "TOP", x, y + cfg.nameSize + 4)
  elseif cfg.raidIconPos == "RIGHT" then
    icon:SetPoint("LEFT", overlay.health, "RIGHT", 4 + x, y)
  else
    icon:SetPoint("RIGHT", overlay.health, "LEFT", -4 + x, y)
  end
end

-- The cast icon squares the health bar plus the cast row, on the side the
-- raid mark does not use.
function style.LayoutCastIcon(overlay, healthHeight)
  local icon = overlay.castIcon
  if not icon then return end
  if overlay.castArt then
    -- Modern WoW: inside the cast bar, the bar's full height.
    local size = overlay.cast:GetHeight() or 0
    icon:SetWidth(size)
    icon:SetHeight(size)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", overlay.cast, "TOPLEFT", 0, 0)
    return
  end
  local size = healthHeight + overlay.castGap + (overlay.cast:GetHeight() or 0)
  icon:SetWidth(size)
  icon:SetHeight(size)
  icon:ClearAllPoints()
  if cfg.raidIcon and cfg.raidIconPos == "RIGHT" then
    icon:SetPoint("TOPRIGHT", overlay.health, "TOPLEFT", -3, 0)
  else
    icon:SetPoint("TOPLEFT", overlay.health, "TOPRIGHT", 3, 0)
  end
end

-- Every size and position the options control. Called once when the overlay
-- is built and again by style.Invalidate after any option changes.
function style.Layout(overlay)
  local art = overlay.art
  local artScale = overlay.artScale or 1
  local plateWidth = cfg.width * artScale
  local healthHeight = (art and cfg.artHealthHeight or cfg.healthHeight) *
                       artScale
  local health = overlay.health

  overlay:SetWidth(plateWidth)
  overlay:SetHeight(healthHeight + cfg.nameSize + 4)
  style.Anchor(overlay)

  -- Modern WoW's BarBG and selected frame are anchored to the bar's corners
  -- by fixed insets (BuildOverlay), so they follow the new size.
  health:SetWidth(plateWidth)
  health:SetHeight(healthHeight)

  if overlay.name then
    overlay.name:SetWidth(plateWidth - 28)
    U.SetFont(overlay.name, cfg.nameSize)
  end
  if overlay.level then U.SetFont(overlay.level, cfg.levelSize) end

  local text = overlay.healthText
  if text then
    U.SetFont(text, cfg.healthTextSize)
    text:ClearAllPoints()
    if cfg.healthTextPos == "LEFT" then
      text:SetPoint("LEFT", health, "LEFT", 3, 0)
    elseif cfg.healthTextPos == "RIGHT" then
      text:SetPoint("RIGHT", health, "RIGHT", -3, 0)
    else
      text:SetPoint("CENTER", health, "CENTER", 0, 0)
    end
  end

  overlay.cast:SetWidth(plateWidth)
  if overlay.castName then
    overlay.castName:SetWidth(plateWidth - (overlay.castArt and
                              overlay.castTextX + 30 or 42))
  end
  style.LayoutRaidIcon(overlay)
  style.LayoutCastIcon(overlay, healthHeight)
  style.LayoutCombo(overlay)
  if overlay.totemIcon then
    overlay.totemIcon:SetWidth(cfg.totemSize)
    overlay.totemIcon:SetHeight(cfg.totemSize)
  end
end

-- ---------------------------------------------------------------------------
-- Combo points (target plate)
--
-- GetComboPoints("target") is documented, not runtime-verified, and is the
-- same call the unit frames' combo strip already makes (modules/unitframes.lua),
-- so that strip working in game is the evidence for this one. ShaguPlates'
-- intent (nameplates.lua 429-445, 788-792): only the filled points, small
-- squares under the bar, the first at its right edge. Flat themes draw the
-- unit frames' muted red-to-green palette (M.rogueCombo) with a black outline;
-- Modern WoW draws its active combo circle (M.modernWow.combo).
-- ---------------------------------------------------------------------------
style.COMBO_MAX = 5
style.COMBO_GAP = 2

function style.BuildCombo(overlay, modernWow)
  local layer = CreateFrame("Frame", nil, overlay)
  layer:SetWidth(1)
  layer:SetHeight(1)
  layer:Hide()
  local pips = {}
  local i
  for i = 1, style.COMBO_MAX do
    local pip = CreateFrame("Frame", nil, layer)
    local fill = pip:CreateTexture(nil, "ARTWORK")
    fill:SetAllPoints(pip)
    if modernWow then
      local cell = M.modernWow.combo.active
      fill:SetTexture(M.modernWow.texture.comboPoints)
      fill:SetTexCoord(cell[1], cell[2], cell[3], cell[4])
    else
      fill:SetTexture(M.texture.plain)
      U.SetColor(fill, M.Unpack(M.rogueCombo[i]))
      U.CreateBorder(pip, 1)
      U.SetBorderColor(pip, 0, 0, 0, 1)
    end
    pip:Hide()
    pips[i] = pip
  end
  overlay.combo = { layer = layer, pips = pips, modernWow = modernWow }
end

function style.LayoutCombo(overlay)
  local combo = overlay.combo
  if not combo then return end
  local height = cfg.comboSize
  local width = combo.modernWow and height * M.modernWow.combo.aspect or height
  local gap = combo.modernWow and M.modernWow.combo.gap or style.COMBO_GAP
  combo.layer:SetWidth(style.COMBO_MAX * width + (style.COMBO_MAX - 1) * gap)
  combo.layer:SetHeight(height)
  local i
  for i = 1, style.COMBO_MAX do
    local pip = combo.pips[i]
    pip:SetWidth(width)
    pip:SetHeight(height)
    pip:ClearAllPoints()
    pip:SetPoint("TOPRIGHT", combo.layer, "TOPRIGHT", -(i - 1) * (width + gap), 0)
  end
end

-- Rows under the bar stack in a fixed order -- cast bar, guild line, combo
-- points -- each skipped while hidden, so none overlaps another. The distance
-- from the bar's bottom to the top of the next row, given which rows above it
-- show.
function style.BelowOffset(overlay, withGuild)
  local offset = 0
  if overlay.cast:IsShown() then
    offset = offset + overlay.castGap + (overlay.cast:GetHeight() or 0)
  end
  if withGuild and overlay.guild and overlay.guild:IsShown() then
    offset = offset + 2 + (overlay.guild:GetHeight() or 0)
  end
  return offset
end

-- ShaguPlates' showguildname, by intent: the player's guild in brackets,
-- centred under the bar, green for the player's own guild and dim otherwise.
-- From core/playercache.lua; a name seen live as a creature shows none.
function style.RefreshGuild(overlay, name)
  local label = overlay.guild
  if not label then return end
  local guild
  if cfg.showGuild and name and reaction.player[name] ~= false and
     type(U.PlayerInfo) == "function" then
    local _, known = U.PlayerInfo(name)
    guild = known
  end
  local offset = style.BelowOffset(overlay, false)
  local own = guild and type(U.PlayerGuild) == "function" and
              U.PlayerGuild() == guild
  local key = guild and (guild .. "|" .. offset .. (own and "|own" or "")) or
              "none"
  if key == overlay.cache.guild then return end
  overlay.cache.guild = key
  if not guild then
    label:Hide()
    return
  end
  label:SetText("<" .. guild .. ">")
  pcall(label.SetTextColor, label,
        M.Unpack(own and M.color.guildOwn or M.color.textDim))
  label:ClearAllPoints()
  label:SetPoint("TOP", overlay.health, "BOTTOM", 0, -(offset + 2))
  label:Show()
end

-- After the cast bar and the guild line: the points sit under whichever of
-- them show (style.BelowOffset), at the bar's right edge.
function style.RefreshCombo(overlay)
  local combo = overlay.combo
  if not combo then return end
  local count = 0
  if cfg.comboPoints and overlay.isTarget then
    local get = ResolveApiFn("GetComboPoints")
    if get then
      local ok, value = pcall(get, "target")
      count = ok and tonumber(value) or 0
    end
  end
  local offset = style.BelowOffset(overlay, true)
  if count == overlay.cache.combo and offset == overlay.cache.comboOffset then
    return
  end
  overlay.cache.combo = count
  overlay.cache.comboOffset = offset

  combo.layer:ClearAllPoints()
  combo.layer:SetPoint("TOPRIGHT", overlay.health, "BOTTOMRIGHT", 0,
                       -(offset + style.COMBO_GAP))
  local i
  for i = 1, style.COMBO_MAX do
    if i <= count then combo.pips[i]:Show() else combo.pips[i]:Hide() end
  end
  if count > 0 then combo.layer:Show() else combo.layer:Hide() end
end

-- Target zoom: the whole overlay scales, so text and art stay in proportion.
function style.RefreshZoom(overlay)
  local zoom = 1
  if overlay.isTarget and cfg.targetZoom then
    zoom = 1 + cfg.targetZoomPercent / 100
  end
  if zoom == overlay.zoom then return end
  overlay.zoom = zoom
  pcall(function() overlay:SetScale(UIParent:GetScale() * zoom) end)
  style.Anchor(overlay)
end

-- The target plate draws above every overlapping plate: the others sit one
-- strata lower. WORKING_SOURCE (ShaguPlates, nameplates.lua 881-888): BACKGROUND
-- for the rest and LOW for the target, so the target never reaches MEDIUM,
-- where the client's windows draw. SetFrameStrata also sets it on child frames
-- (documented, not runtime-verified here), which carries the bars, cast bar
-- and aura row along; none of them sets a strata of its own.
function style.RefreshStrata(overlay)
  local strata = overlay.isTarget and "LOW" or "BACKGROUND"
  if strata == overlay.cache.strata then return end
  overlay.cache.strata = strata
  pcall(overlay.SetFrameStrata, overlay, strata)
end

-- Every theme: the target outline wins over a reaction outline; with neither
-- nothing is drawn (no resting outline, user request 2026-10-20). The flat
-- themes draw the 1-unit edges; Modern WoW draws its selected-plate art (a
-- white frame) tinted the same colour, and keeps it untinted on the target
-- when no outline applies, as its own target state. All options apply under
-- every theme (user request, 2026-10-20).
function style.RefreshOutline(overlay, unitType)
  local key, r, g, b = "none", 0, 0, 0
  if overlay.isTarget and cfg.targetOutline then
    key, r, g, b = "target", cfg.highlightR, cfg.highlightG, cfg.highlightB
  elseif style.OUTLINE_KEY[unitType] and cfg[style.OUTLINE_KEY[unitType]] then
    key = unitType
    r, g, b = M.Unpack(UNIT_COLOR[unitType])
  elseif overlay.isTarget and overlay.selectedBorder then
    key, r, g, b = "selected", 1, 1, 1
  end
  if key == overlay.cache.border then return end
  overlay.cache.border = key

  if overlay.selectedBorder then
    if key == "none" then
      overlay.selectedBorder:Hide()
    else
      overlay.selectedBorder:SetVertexColor(r, g, b, 1)
      overlay.selectedBorder:Show()
    end
  else
    style.ShowEdges(overlay.health, key ~= "none", r, g, b)
  end
end

-- The edges are shown and hidden outright rather than given a zero alpha:
-- a zero vertex alpha is exactly what failed to hide a fill on this client
-- (knowledge.json statusbar.native_fill_hide_routes).
function style.ShowEdges(frame, shown, r, g, b)
  local edges = frame.puiEdges
  if not edges then return end
  if shown then U.SetBorderColor(frame, r, g, b, 1) end
  local i
  for i = 1, table.getn(edges) do
    if shown then edges[i]:Show() else edges[i]:Hide() end
  end
end

-- The mark: GetRaidTargetIndex for the target, otherwise the native plate's
-- own raid-icon region, read back through its texture cell. Which cell the
-- client gives that region on this build is unmeasured (WORKING_SOURCE:
-- Vanilla's 4x4 UI-RaidTargetingIcons sheet); a cell outside 1..8 shows none.
function style.RaidIndex(overlay)
  if overlay.isTarget then
    local index = ApiNumber("GetRaidTargetIndex", "target")
    if index and index >= 1 and index <= 8 then return index end
  end
  local region = overlay.parts.raidicon
  if not region or not Call(region, "IsShown") then return nil end
  local left, top = Call(region, "GetTexCoord")
  left, top = tonumber(left), tonumber(top)
  if not left or not top then return nil end
  local index = math.floor(top * 4 + 0.5) * 4 + math.floor(left * 4 + 0.5) + 1
  if index < 1 or index > 8 then return nil end
  return index
end

function style.RefreshRaidIcon(overlay)
  local icon = overlay.raidIcon
  if not icon then return end
  local index = cfg.raidIcon and style.RaidIndex(overlay) or nil
  if index == overlay.cache.raid then return end
  overlay.cache.raid = index
  if not index then
    icon:Hide()
    return
  end
  local col = math.mod(index - 1, 4) * 0.25
  local row = math.floor((index - 1) / 4) * 0.25
  icon:SetTexCoord(col, col + 0.25, row, row + 0.25)
  icon:Show()
end

-- The client's own switches; documented, unverified on this client, so a
-- missing function is skipped rather than assumed.
--
-- WORKING_SOURCE (octo-framexml FrameXML/Bindings.xml:516-549): V and Shift-V
-- each hide the other plate type, Ctrl-V shows both, and all three toggle on
-- the globals NAMEPLATES_ON / FRIENDNAMEPLATES_ON. UIParent.lua:234,367 call
-- UpdateNameplates() on VARIABLES_LOADED and PLAYER_ENTERING_WORLD, which
-- always ends with HideFriendNameplates() (UIOptionsFrame.lua:767). So the
-- globals are kept in step with pandaUI's settings (as pfUI-octo does), and a
-- key press that changes them is saved back into those settings.
local visibility = { armed = false }

function style.ApplyVisibility()
  if not cfg.enabled then return end
  local fn = ResolveApiFn(cfg.showHostile and "ShowNameplates" or
                          "HideNameplates")
  if fn then pcall(fn) end
  fn = ResolveApiFn(cfg.showFriendly and "ShowFriendNameplates" or
                    "HideFriendNameplates")
  if fn then pcall(fn) end
  NAMEPLATES_ON = cfg.showHostile and 1 or nil
  FRIENDNAMEPLATES_ON = cfg.showFriendly and 1 or nil
  visibility.hostile = cfg.showHostile and true or false
  visibility.friendly = cfg.showFriendly and true or false
end

-- Runs on the next tick, after the stock PLAYER_ENTERING_WORLD handler has
-- reset the plates, whatever the handler order. Key sync starts only then, so
-- the client's own saved NAMEPLATES_ON restore is never taken for a key press.
function style.ScheduleVisibility()
  U.DeferOnce("nameplates.visibility", function()
    style.ApplyVisibility()
    visibility.armed = true
  end)
end

-- A V / Shift-V / Ctrl-V press changes the globals; adopt it as the setting so
-- the next loading screen keeps it.
function style.SyncKeyVisibility()
  if not visibility.armed then return end
  local hostile = NAMEPLATES_ON and true or false
  local friendly = FRIENDNAMEPLATES_ON and true or false
  if hostile == visibility.hostile and friendly == visibility.friendly then
    return
  end
  visibility.hostile = hostile
  visibility.friendly = friendly
  cfg.showHostile = hostile
  cfg.showFriendly = friendly
end

-- ---------------------------------------------------------------------------
-- Overlay construction
-- ---------------------------------------------------------------------------
local function BuildOverlay(frame, parts)
  plateCount = plateCount + 1

  local overlay = CreateFrame("Frame", "PandaUINamePlate" .. plateCount, frame)
  local themeStyle = U.GetActiveThemeStyle()
  local modern = themeStyle == "modern"
  local modernWow = themeStyle == "modern-wow"
  -- Classic draws the stock fill, the same native texture its unit frames use.
  local classic = themeStyle == "classic-wow"
  local nativeTexture = classic and M.texture.classicStatusBar or nil
  local art = modernWow and M.modernWow.nameplate or nil
  overlay.id = plateCount
  overlay.plate = frame
  overlay.parts = parts
  overlay.cache = {}
  overlay.modernWow = modernWow
  overlay.zoom = 1

  -- Non-target strata until the first refresh says otherwise
  -- (style.RefreshStrata).
  pcall(overlay.SetFrameStrata, overlay, "BACKGROUND")

  -- WORKING_SOURCE (UnrealPfUI): a WorldFrame-child overlay is scaled to the UI
  -- scale so plate sizes read in the same units as the rest of the addon.
  pcall(function() overlay:SetScale(UIParent:GetScale()) end)

  local artScale = art and art.scale or 1
  local plateWidth = cfg.width * artScale
  local healthHeight = (art and cfg.artHealthHeight or cfg.healthHeight) *
                       artScale
  overlay.art = art
  overlay.artScale = artScale

  -- Size and position come from style.Layout at the end, so the options can
  -- re-run it on a live plate.
  local health = U.CreateStatusBar(overlay, {
    width = plateWidth,
    height = healthHeight,
    color = UNIT_COLOR.ENEMY,
    background = art and { 1, 1, 1, 1 } or M.color.healthBg,
    texture = art and art.texture or
              (modern and M.unitFrame.statusTexture or nativeTexture),
  })
  health:SetPoint("BOTTOM", overlay, "BOTTOM", 0, 0)
  if art then
    -- Retail's Cooldown Manager bar: the fill and its BarBG are cells of one
    -- sheet. RefreshPlate narrows the fill's texcoords with the value, so the
    -- art is cropped rather than squashed.
    local sheet, fill, background = art.sheet, art.fill, art.background
    local inset = art.backgroundInset
    health.puiFillTexture:SetTexCoord(
      fill[1] / sheet[1], fill[3] / sheet[1],
      fill[2] / sheet[2], fill[4] / sheet[2])
    health.puiBackground:SetTexture(art.texture)
    health.puiBackground:SetTexCoord(
      background[1] / sheet[1], background[3] / sheet[1],
      background[2] / sheet[2], background[4] / sheet[2])
    health.puiBackground:ClearAllPoints()
    health.puiBackground:SetPoint("TOPLEFT", health, "TOPLEFT",
                                  inset.left * artScale, inset.top * artScale)
    health.puiBackground:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT",
                                  inset.right * artScale,
                                  inset.bottom * artScale)

    -- No pandaUI border: the target is marked by Retail's selected frame,
    -- tinted by the outline options (style.RefreshOutline).
    local selected = health:CreateTexture(nil, "OVERLAY")
    local crop = art.selectedTexCoord
    selected:SetTexture(art.selectedTexture)
    selected:SetTexCoord(crop[1], crop[2], crop[3], crop[4])
    inset = art.selectedInset
    selected:SetPoint("TOPLEFT", health, "TOPLEFT",
                      inset.left * artScale, inset.top * artScale)
    selected:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT",
                      inset.right * artScale, inset.bottom * artScale)
    selected:Hide()
    overlay.selectedBorder = selected
  else
    -- Border only: U.CreateStatusBar already owns the bar's background
    -- texture. The edges exist for the optional target and reaction outlines
    -- and start hidden (style.RefreshOutline), as in UnrealUI.
    U.CreateBorder(health)
    style.ShowEdges(health, false)
  end
  overlay.health = health

  -- Its own layer so the fill never covers the text. Placed by style.Layout
  -- (healthTextPos).
  overlay.healthText = U.CreateLabel(health, {
    size = cfg.healthTextSize,
    color = M.color.text,
    inherits = "GameFontNormal",
  })

  -- Name on the bar's left edge, level on its right: one anchor each, per
  -- fonts.stretched_justification_ignored. The fixed width (style.Layout)
  -- keeps a long name clear of the level. exactSize: under the default
  -- "original" font choice a plain size is dropped (knowledge.json /
  -- fonts.original_choice_drops_requested_size), so Name size did nothing.
  overlay.name = U.CreateLabel(overlay, {
    size = cfg.nameSize,
    color = { 1, 1, 1, 1 },
    inherits = "GameFontNormal",
    justify = "LEFT",
    exactSize = true,
  })
  if overlay.name then
    overlay.name:SetPoint("BOTTOMLEFT", health, "TOPLEFT", 0, 2)
  end

  overlay.level = U.CreateLabel(overlay, {
    size = cfg.levelSize,
    color = { 1, 1, 1, 1 },
    inherits = "GameFontNormal",
  })
  if overlay.level then
    overlay.level:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", 0, 2)
  end

  -- The target's cast, mirrored from modules/castbar.lua's target tracker.
  -- Under `modern-wow` it is UnrealUI's Retail nameplate cast bar
  -- (M.modernWow.nameplate.cast): the Modern WoW cast background and fill,
  -- an additive spark on the fill's edge, and the icon inside the bar.
  local castArt = art and art.cast or nil
  overlay.castArt = castArt
  local castHeight = castArt and castArt.height * artScale or 12
  local cast = U.CreateStatusBar(overlay, {
    width = plateWidth,
    height = castHeight,
    color = castArt and { 1, 1, 1, 1 } or M.color.cast,
    background = castArt and { 1, 1, 1, 1 } or M.color.healthBg,
    texture = castArt and M.modernWow.texture.castFill or
              (modern and M.unitFrame.statusTexture or nativeTexture),
  })
  -- Kept for the rows stacked under the cast bar (style.BelowOffset).
  overlay.castGap = castArt and castArt.spacing * artScale or 2
  cast:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -overlay.castGap)
  local castTextX, castTimeX = 3, -3
  if castArt then
    cast.puiBackground:SetTexture(M.modernWow.texture.castBackground)
    -- Additive, as the source draws it: with the default blend its black
    -- field is a moving dark square, so it is dropped if the blend fails.
    local spark = cast:CreateTexture(nil, "OVERLAY")
    spark:SetTexture(M.modernWow.texture.castSpark)
    if spark.SetBlendMode and pcall(spark.SetBlendMode, spark, "ADD") then
      spark:SetWidth(castArt.sparkWidth * artScale)
      spark:SetHeight((castArt.height + castArt.sparkExtra) * artScale)
      overlay.castSpark = spark
    end
    spark:Hide()
    castTextX = castHeight + castArt.textGap * artScale
    castTimeX = -castArt.timeInset * artScale
  elseif not modern then
    U.CreateBorder(cast)
    U.SetBorderColor(cast, M.Unpack(M.color.border))
  end
  overlay.castTextX = castTextX
  cast:Hide()
  overlay.cast = cast

  local castFont = castArt and
                   math.max(M.fontSize.tiny,
                            math.floor(castArt.font * artScale + 0.5)) or
                   M.fontSize.tiny
  overlay.castName = U.CreateLabel(cast, {
    size = castFont,
    color = M.color.text,
    inherits = "GameFontNormalSmall",
    justify = "LEFT",
  })
  if overlay.castName then
    overlay.castName:SetPoint("LEFT", cast, "LEFT", castTextX, 0)
  end

  overlay.castTime = U.CreateLabel(cast, {
    size = castFont,
    color = M.color.text,
    inherits = "GameFontNormalSmall",
    justify = "RIGHT",
  })
  if overlay.castTime then
    overlay.castTime:SetPoint("RIGHT", cast, "RIGHT", castTimeX, 0)
  end

  -- Spell icon, a child of the cast bar so it hides with it; placed by
  -- style.LayoutCastIcon. Modern WoW: inside the bar's left edge, the bar's
  -- full height, no border. Other themes: beside the bar, spanning health and
  -- cast rows (pfUI's plate layout).
  local castIcon = CreateFrame("Frame", nil, cast)
  castIcon.texture = castIcon:CreateTexture(nil, "ARTWORK")
  castIcon.texture:SetAllPoints(castIcon)
  castIcon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  if not modern and not castArt then
    U.CreateBorder(castIcon)
    U.SetBorderColor(castIcon, M.Unpack(M.color.border))
  end
  castIcon:Hide()
  overlay.castIcon = castIcon

  -- Target debuffs at the configured bar corner. The legacy offset is kept as
  -- a fallback for callers without the nameplate gap setting.
  if type(U.CreateNameplateAuraRows) == "function" then
    local auraArt = modernWow and M.modernWow.nameplateAura or nil
    local auraOffset
    if auraArt then
      auraOffset = cfg.nameSize + 4 + auraArt.gap -
                   auraArt.overlayInset.bottom + auraArt.size
    else
      auraOffset = cfg.nameSize + 30
    end
    overlay.auraRows = U.CreateNameplateAuraRows(
      health, overlay, overlay.id, auraOffset)
  end

  -- Raid mark. On the overlay rather than the bar, so hiding the health bar
  -- (style.HideHealth) keeps the mark; it sits beside the bar, never on it.
  local raid = overlay:CreateTexture(nil, "OVERLAY")
  raid:SetTexture(M.texture.raidTargetIcons)
  raid:Hide()
  overlay.raidIcon = raid

  style.BuildCombo(overlay, modernWow)

  -- Guild line (style.RefreshGuild), placed under the bar on each refresh.
  overlay.guild = U.CreateLabel(overlay, {
    size = M.fontSize.small,
    color = M.color.textDim,
    inherits = "GameFontNormalSmall",
  })
  if overlay.guild then overlay.guild:Hide() end

  -- Totem icon (style.RefreshTotem), centred on the bar's place, cropped like
  -- every other spell icon.
  local totem = overlay:CreateTexture(nil, "ARTWORK")
  totem:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  totem:SetPoint("CENTER", health, "CENTER", 0, 0)
  totem:Hide()
  overlay.totemIcon = totem

  style.Layout(overlay)
  overlay:Show()
  return overlay
end

-- The unit a plate's debuffs are read through: "target" for the target's
-- plate, the plate's GUID for the others (Nampower only), else nil.
local function PlateAuraUnit(overlay)
  if overlay.isTarget then return cfg.showAuras and "target" or nil end
  if cfg.allPlateAuras and overlay.guid then return overlay.guid end
  return nil
end

local function RefreshPlateAuras(overlay)
  if type(U.RefreshNameplateAuraRows) ~= "function" then return end

  local unit = PlateAuraUnit(overlay)
  if not unit then
    if overlay.auraActive then
      overlay.auraActive = false
      overlay.auraUnit = nil
      U.RefreshNameplateAuraRows(overlay.auraRows, false)
    end
    return
  end

  -- Other plates poll slower; DEBUFF_ADDED/REMOVED_OTHER pulls them forward
  -- (U.NameplateAuraChanged).
  local now = ApiNumber("GetTime") or 0
  if not overlay.auraActive or overlay.auraUnit ~= unit or
     now >= (overlay.nextAuraRefresh or 0) then
    overlay.auraActive = true
    overlay.auraUnit = unit
    overlay.nextAuraRefresh = now + (overlay.isTarget and 0.2 or 0.5)
    U.RefreshNameplateAuraRows(overlay.auraRows, true, unit)
  end
end

-- Called by modules/auras.lua on Nampower's debuff events for this GUID.
function U.NameplateAuraChanged(guid)
  local i
  for i = 1, table.getn(plateOrder) do
    local overlay = plateOrder[i]
    if overlay and overlay.guid == guid then overlay.nextAuraRefresh = 0 end
  end
end

-- The target's cast comes from its tracker; another plate's from the
-- Nampower GUID cast store (U.GuidCastInfo).
local function PlateCastInfo(overlay)
  if overlay.isTarget then
    if cfg.attachTargetCast and type(U.TargetCastInfo) == "function" then
      return U.TargetCastInfo()
    end
    return nil
  end
  if cfg.allPlateCasts and overlay.guid and
     type(U.GuidCastInfo) == "function" then
    return U.GuidCastInfo(overlay.guid)
  end
  return nil
end

-- modules/castbar.lua keeps its tick at frame rate while this is true and a
-- GUID cast is live.
function U.NameplateGuidCastsWanted()
  return cfg.enabled and cfg.allPlateCasts and U.hasNampower and true or false
end

local function RefreshPlateCast(overlay)
  local spell, elapsed, duration, texture = PlateCastInfo(overlay)
  if not spell or not duration then
    overlay.cast:Hide()
    overlay.castLive = nil
    return
  end

  local icon = overlay.castIcon
  if icon then
    if texture then
      if icon.shown ~= texture then
        icon.texture:SetTexture(texture)
        icon.shown = texture
      end
      icon:Show()
    else
      icon:Hide()
    end
  end

  overlay.cast:SetMinMaxValues(0, duration)
  overlay.cast:SetValue(elapsed)

  -- Modern WoW: the fill art is cropped to the progress rather than squeezed
  -- (its shape is baked in), and the spark rides the fill's edge, hidden at
  -- both ends as in the source.
  if overlay.castArt then
    local progress = duration > 0 and elapsed / duration or 0
    if progress < 0 then progress = 0 end
    if progress > 1 then progress = 1 end
    if progress > 0 then
      pcall(overlay.cast.puiFillTexture.SetTexCoord,
            overlay.cast.puiFillTexture, 0, progress, 0, 1)
    end
    local spark = overlay.castSpark
    if spark then
      if progress > 0 and progress < 1 then
        spark:ClearAllPoints()
        spark:SetPoint("CENTER", overlay.cast, "LEFT",
                       (tonumber(overlay.cast:GetWidth()) or 0) * progress, 0)
        spark:Show()
      else
        spark:Hide()
      end
    end
  end

  if overlay.castName then overlay.castName:SetText(spell) end
  if overlay.castTime then
    overlay.castTime:SetText(string.format("%.1f", duration - elapsed))
  end
  overlay.cast:Show()
  overlay.castLive = true
end

-- Called from modules/castbar.lua's tick, so plate casts move at the
-- castbar's rate rather than the 0.1s plate refresh. A cast on another plate
-- starts on that refresh and is then followed here.
function U.RefreshNameplateTargetCast()
  if targetOverlay then RefreshPlateCast(targetOverlay) end
  if not cfg.allPlateCasts then return end
  local i
  for i = 1, table.getn(plateOrder) do
    local overlay = plateOrder[i]
    if overlay and overlay.castLive and overlay ~= targetOverlay then
      RefreshPlateCast(overlay)
    end
  end
end

-- Silences every native part of one plate. Run on adoption and again each
-- time a plate is shown or recycled onto a new unit, since the client
-- re-lays out its native name and level then.
local function MutePlate(parts)
  MuteTexture(parts.border)
  MuteTexture(parts.glow)
  MuteTexture(parts.raidicon)
  MuteFontString(parts.name)
  MuteFontString(parts.level)
  MuteHealthBar(parts.healthbar)
  MuteBar(parts.castbar)

  -- Anything not classified above is stock art pandaUI is replacing. The elite
  -- icon is the one exception: it is muted but still read via IsShown().
  local i
  for i = 1, table.getn(parts.textures) do
    local region = parts.textures[i]
    if region ~= parts.border and region ~= parts.glow and
       region ~= parts.raidicon then
      MuteTexture(region)
    end
  end
  for i = 1, table.getn(parts.fontstrings) do
    MuteFontString(parts.fontstrings[i])
  end
end

local function AdoptPlate(frame)
  local parts = ClassifyPlate(frame)
  if not parts then
    stats.rejected = stats.rejected + 1
    return nil
  end

  MutePlate(parts)

  local overlay = BuildOverlay(frame, parts)
  registry[frame] = overlay
  table.insert(plateOrder, overlay)

  stats.plates = stats.plates + 1
  stats.detector = parts.detector
  if parts.healthbar then stats.withHealthBar = stats.withHealthBar + 1 end

  return overlay
end

local function ScanWorldFrame()
  local worldFrame = U.G("WorldFrame")
  if not worldFrame then return end

  local count = tonumber(Call(worldFrame, "GetNumChildren"))
  if not count then return end
  stats.worldChildren = count
  if stats.minChildren < 0 or count < stats.minChildren then
    stats.minChildren = count
  end
  if count > stats.maxChildren then stats.maxChildren = count end

  -- Vanilla never destroys a plate, but a shrinking count would leave the
  -- cursor past the end, so fall back to a full re-scan instead of trusting it.
  if count < scannedChildren then
    scannedChildren = 0
    statRescans = statRescans + 1
  end
  if count == scannedChildren then return end

  statScans = statScans + 1

  local ok, kids = pcall(function() return { worldFrame:GetChildren() } end)
  if not ok or type(kids) ~= "table" then return end

  local i
  for i = scannedChildren + 1, count do
    local child = kids[i]
    if child and not registry[child] then AdoptPlate(child) end
  end

  scannedChildren = count
end

-- ---------------------------------------------------------------------------
-- Refresh
-- ---------------------------------------------------------------------------

-- Health for one plate. Nampower exposes live server-fed values for a loaded
-- plate GUID. Without it, the native bar remains the universal fallback.
local function ReadHealth(overlay)
  if overlay.guid and type(U.NampowerUnitField) == "function" then
    local value = U.NampowerUnitField(overlay.guid, "health")
    local maximum = U.NampowerUnitField(overlay.guid, "maxHealth")
    if value and maximum and maximum > 0 then
      return value, 0, maximum, true
    end
  end

  local bar = overlay.parts.healthbar
  if bar then
    local value = tonumber(Call(bar, "GetValue"))
    local minimum, maximum = Call(bar, "GetMinMaxValues")
    minimum, maximum = tonumber(minimum), tonumber(maximum)
    if value and maximum and maximum > 0 then
      return value, (minimum or 0), maximum, false
    end
  end

  -- No usable native bar: the unit API can still answer for the target.
  if overlay.isTarget then
    local hp = ApiNumber("UnitHealth", "target")
    local hpMax = ApiNumber("UnitHealthMax", "target")
    if hp and hpMax and hpMax > 0 then return hp, 0, hpMax, false end
  end

  return nil
end

-- Hostile / neutral / friendly for one plate, in the order the "Reaction"
-- section gives: the native tint for every plate, target included, so a
-- plate always matches what the stock client decided; then the live target,
-- the name last seen live, the player cache, and hostile. A neutral plate the
-- player's side has engaged turns hostile (reaction.PlateEngaged).
local function BaseUnitType(overlay, name)
  -- Nampower: the plate's own unit decides. A plate just shown still carries
  -- a stale or default tint for a moment, which drew hostile mobs yellow
  -- before they turned red (user report 2026-11-03).
  if overlay.guid then
    local unitType = reaction.FromUnit(overlay.guid)
    if unitType then return unitType end
  end

  local r, g, b = Call(overlay.parts.healthbar, "GetStatusBarColor")
  local unitType = reaction.FromTint(r, g, b)
  if unitType then return unitType end

  if overlay.isTarget then
    unitType = reaction.FromUnit("target")
    if unitType then return unitType end
  end

  if not name then return "ENEMY" end
  return reaction.byName[name] or style.CachedFriend(name) or "ENEMY"
end

local function PlateUnitType(overlay, name)
  local unitType = BaseUnitType(overlay, name)
  if unitType == "NEUTRAL" and reaction.PlateEngaged(overlay, name) then
    return "ENEMY"
  end
  return unitType
end

-- Modern WoW's fill is one cell of an atlas: the drawn width shrinks with the
-- value, so its texcoords shrink with it to crop the art instead of squashing.
local function ApplyModernWowFill(overlay, fraction)
  if fraction < 0 then fraction = 0 end
  if fraction > 1 then fraction = 1 end
  if fraction == overlay.cache.fillFraction then return end
  overlay.cache.fillFraction = fraction

  local art = M.modernWow.nameplate
  local cell = art.fill
  local u1 = cell[1] / art.sheet[1]
  local u2 = cell[3] / art.sheet[1]
  overlay.health.puiFillTexture:SetTexCoord(
    u1, u1 + (u2 - u1) * fraction,
    cell[2] / art.sheet[2], cell[4] / art.sheet[2])
end

-- Health text for one plate: Nampower's live values first, then the bundled
-- creature fallback when it knows the name and level. Otherwise nil makes
-- style.HealthText use the native percentage.
local function PlateHealthText(overlay, name, levelText, value, minimum,
                               maximum, exact)
  local current, total
  if exact then
    current, total = value - minimum, maximum - minimum
  else
    local level = tonumber(levelText)
    if name and level and type(U.UnitVitalsHealth) == "function" then
      current, total = U.UnitVitalsHealth(
        overlay.isTarget and "target" or "nameplate",
        name, level, value - minimum, maximum - minimum)
    end
  end
  return style.HealthText(current, total,
                          (value - minimum) / (maximum - minimum))
end

local function RefreshPlate(overlay)
  local parts = overlay.parts
  local plate = overlay.plate

  local visible = Call(plate, "IsVisible")
  if not visible then
    -- A hidden plate is never the target: drop its auras and cast now, so a
    -- recycled plate cannot show the previous unit's. Its engagement goes
    -- with it (reaction.PlateEngaged).
    overlay.engaged = nil
    if overlay.tankGuid then style.TankClear(overlay) end
    if overlay.isTarget or overlay.guid or overlay.auraActive or
       overlay.castLive then
      overlay.isTarget = false
      overlay.guid = nil
      RefreshPlateAuras(overlay)
      overlay.cast:Hide()
      overlay.castLive = nil
    end
    return
  end

  -- Nampower names the plate's unit; recycled plates are re-read every pass.
  overlay.guid = U.PlateGuid(plate)

  -- Re-resolve which fontstring is the level: plates are recycled onto new
  -- units, and a name that happens to be numeric is not worth guarding against
  -- once, only every pass.
  local a, b = parts.fontstrings[1], parts.fontstrings[2]
  if b then
    if IsNumericText(Call(a, "GetText")) then
      parts.level, parts.name = a, b
    else
      parts.name, parts.level = a, b
    end
  end

  local name = Call(parts.name, "GetText")
  local levelText = Call(parts.level, "GetText")

  -- WORKING_SOURCE (UnrealPfUI): with no per-plate unit token, the current
  -- target's plate is the fully opaque one. UnrealUI also requires the name to
  -- match, so two opaque plates cannot both claim the target's auras.
  local hasTarget = ApiTruth("UnitExists", "target")
  local targetName = hasTarget and ApiString("UnitName", "target") or nil
  local plateAlpha = tonumber(Call(plate, "GetAlpha")) or 1
  -- 0.99, not 1: pfUI-octo's threshold on this client (WORKING_112_SOURCE).
  -- A target plate read just under 1 fell to the "nameplate" estimate rather
  -- than the target's tracked health, and disagreed with the target frame.
  overlay.isTarget = hasTarget and plateAlpha >= 0.99 and
                     (not targetName or targetName == name) and true or false
  -- With Nampower the GUID decides, so two same-name mobs never swap.
  if overlay.guid and style.targetGuid ~= nil then
    overlay.isTarget = (hasTarget and overlay.guid == style.targetGuid) and
                       true or false
  end
  if overlay.isTarget then
    targetPlateActive = true
    targetOverlay = overlay
  end

  -- Name, shortened when abbrevNames asks for it (style.Name).
  if overlay.name and name ~= overlay.cache.name then
    overlay.cache.name = name
    overlay.name:SetText(style.Name(name) or "")
    -- A plate recycled onto a new unit is re-laid out by the client: mute
    -- its native name and level again, once per new unit.
    MuteFontString(parts.name)
    MuteFontString(parts.level)
  end

  -- Level, with the stock elite/rare marker kept as a suffix. A plate that
  -- carries no level fontstring at all gets a blank slot rather than "??" --
  -- the target layout is a name row with nothing else in it, not an error.
  if overlay.level then
    local suffix = ""
    if parts.levelicon and Call(parts.levelicon, "IsShown") then suffix = "+" end

    local text = ""
    if parts.level then text = (levelText or "??") .. suffix end
    if text ~= overlay.cache.level then
      overlay.cache.level = text
      overlay.level:SetText(text)

      local r, g, b2 = Call(parts.level, "GetTextColor")
      if type(r) == "number" and type(g) == "number" and type(b2) == "number" then
        -- UnrealPfUI lifts the stock level colour by .3 so it stays legible
        -- against the world rather than the stock plate's dark backing.
        r, g, b2 = Clamp(r + 0.3), Clamp(g + 0.3), Clamp(b2 + 0.3)
      else
        r, g, b2 = DifficultyColor(levelText)
      end
      pcall(overlay.level.SetTextColor, overlay.level, r, g, b2, 1)
    end
  end

  -- Health is read first so Tank Mode can drop a corpse; then the reaction,
  -- the colours and the totem icon, which decide whether the health bar
  -- shows (style.HideHealth).
  local value, minimum, maximum, exactHealth = ReadHealth(overlay)
  local unitType = PlateUnitType(overlay, name)
  overlay.cache.unitType = unitType
  local tankKey = nil
  if cfg.tankMode then
    tankKey = style.TankKey(overlay, not value or value > minimum)
  end
  overlay.tankKey = tankKey
  style.RefreshColors(overlay, unitType, name, tankKey)
  style.RefreshTotem(overlay, name)

  -- Health
  if value and not style.HideHealth(overlay, unitType, name,
                                    value < maximum) then
    overlay.health:Show()
    overlay.health:SetMinMaxValues(minimum, maximum)
    overlay.health:SetValue(value)
    if overlay.modernWow and maximum > minimum then
      ApplyModernWowFill(overlay, (value - minimum) / (maximum - minimum))
    end

    if overlay.healthText then
      if cfg.showHealthText and maximum > minimum then
        overlay.healthText:SetText(PlateHealthText(
          overlay, name, levelText, value, minimum, maximum, exactHealth))
      else
        overlay.healthText:SetText("")
      end
    end
  else
    -- No health data, or hidden by option: the name/level row stands alone.
    overlay.health:Hide()
    if overlay.healthText then overlay.healthText:SetText("") end
  end

  -- Target emphasis: everything else dimmed, the target outlined (or its
  -- Modern WoW selected art), optionally zoomed and drawn above the rest.
  local wantAlpha = 1
  if cfg.fadeOthers and hasTarget and not overlay.isTarget then
    wantAlpha = cfg.otherAlpha
  end
  if wantAlpha ~= overlay.cache.alpha then
    overlay.cache.alpha = wantAlpha
    pcall(overlay.SetAlpha, overlay, wantAlpha)
  end

  style.RefreshOutline(overlay, unitType)
  style.FitNative(overlay)
  style.RefreshZoom(overlay)
  style.RefreshStrata(overlay)
  style.RefreshRaidIcon(overlay)

  RefreshPlateAuras(overlay)
  RefreshPlateCast(overlay)
  style.RefreshGuild(overlay, name)
  style.RefreshCombo(overlay)
end

local function RefreshAll()
  statRefreshed = statRefreshed + 1
  targetPlateActive = false
  targetOverlay = nil
  style.targetGuid = U.UnitGuid("target")
  reaction.Learn("target")
  reaction.Learn("mouseover")
  if type(U.PlayerCacheLearn) == "function" then
    U.PlayerCacheLearn("target")
    U.PlayerCacheLearn("mouseover")
  end
  local i
  for i = 1, table.getn(plateOrder) do
    local overlay = plateOrder[i]
    if overlay then
      local ok, err = pcall(RefreshPlate, overlay)
      if not ok then U.Debug("nameplate refresh: " .. tostring(err)) end
    end
  end
end

-- Runs every frame. The 0.1s refresh left a new or recycled plate drawing
-- its native art, and the previous unit's overlay, until the next tick: the
-- flash seen when a mob comes into plate range. Only two reads per plate
-- while nothing changes.
--
-- The client tints a just-shown plate a moment late (yellow before red, user
-- report 2026-11-03), so for WATCH_TINT seconds after that its tint is read
-- every frame too and a change redraws the plate at once.
local WATCH_TINT = 0.5

local function TintType(overlay)
  return reaction.FromTint(Call(overlay.parts.healthbar, "GetStatusBarColor"))
end

local function WatchPlates()
  local now = GetTime()
  local i
  for i = 1, table.getn(plateOrder) do
    local overlay = plateOrder[i]
    if overlay then
      if Call(overlay.plate, "IsVisible") then
        local raw = Call(overlay.parts.fontstrings[1], "GetText")
        local redraw = false
        if not overlay.live or raw ~= overlay.rawText then
          overlay.live = true
          overlay.rawText = raw
          overlay.tintUntil = now + WATCH_TINT
          overlay.tint = TintType(overlay)
          MutePlate(overlay.parts)
          overlay.cache.name = nil
          redraw = true
        elseif overlay.tintUntil then
          if now > overlay.tintUntil then
            overlay.tintUntil = nil
          else
            local tint = TintType(overlay)
            if tint ~= overlay.tint then
              overlay.tint = tint
              redraw = true
            end
          end
        end
        if redraw then
          local ok, err = pcall(RefreshPlate, overlay)
          if not ok then U.Debug("nameplate refresh: " .. tostring(err)) end
        end
      elseif overlay.live then
        overlay.live = false
      end
    end
  end
end

-- WORKING_112_SOURCE (pfUI-octo modules/nameplates.lua:600): ClassicAPI fires
-- NAME_PLATE_CREATED with the new plate frame as arg1, so it can be muted
-- before it is ever drawn. Stock clients have no such event; the per-frame
-- scan covers them.
local function OnPlateCreated(_, frame)
  if type(frame) ~= "table" or registry[frame] then return end
  if U.PerfDisabled and U.PerfDisabled("plates") then return end
  AdoptPlate(frame)
end

-- An option changed (U.SetNameplateSetting): drop every plate's draw cache so
-- colours, outlines and text are re-applied, re-run the layout, and redraw now
-- rather than on the next 0.1s tick.
function style.Invalidate()
  if not cfg.enabled then return end
  local i
  for i = 1, table.getn(plateOrder) do
    local overlay = plateOrder[i]
    if overlay then
      overlay.cache = {}
      local ok, err = pcall(style.Layout, overlay)
      if not ok then U.Debug("nameplate layout: " .. tostring(err)) end
    end
  end
  RefreshAll()
end

-- ---------------------------------------------------------------------------
-- Diagnostics
--
-- The detection path above is WORKING_SOURCE, not measured. This is what turns
-- one in-game run into the evidence that closes the gap.
-- ---------------------------------------------------------------------------
-- Read by core/perf.lua's export alongside U.SuppressionStats.
function U.NameplateStats()
  return {
    scans = statScans,
    rescans = statRescans,
    classified = statClassified,
    refreshPasses = statRefreshed,
    plates = plateCount,
    worldChildren = stats.worldChildren,
    minChildren = stats.minChildren,
    maxChildren = stats.maxChildren,
  }
end

function U.NameplateReport()
  local report = {
    enabled = cfg.enabled,
    worldChildren = stats.worldChildren,
    scanned = scannedChildren,
    plates = stats.plates,
    rejected = stats.rejected,
    withHealthBar = stats.withHealthBar,
    detector = stats.detector,
    minChildren = stats.minChildren,
    maxChildren = stats.maxChildren,
  }

  -- First live plate, described part by part.
  local i
  for i = 1, table.getn(plateOrder) do
    local overlay = plateOrder[i]
    if overlay and Call(overlay.plate, "IsVisible") then
      local parts = overlay.parts
      report.sample = {
        frameType = ObjectType(overlay.plate),
        regions = table.getn(parts.textures) + table.getn(parts.fontstrings),
        textures = table.getn(parts.textures),
        fontstrings = table.getn(parts.fontstrings),
        name = Call(parts.name, "GetText"),
        level = Call(parts.level, "GetText"),
        hasHealthBar = parts.healthbar and true or false,
        hasCastBar = parts.castbar and true or false,
        hasBorder = parts.border and true or false,
        hasGlow = parts.glow and true or false,
        isTarget = overlay.isTarget,
      }

      local value, minimum, maximum = ReadHealth(overlay)
      report.sample.health = value
      report.sample.healthMin = minimum
      report.sample.healthMax = maximum

      -- The raw tint is printed when it does not map to a known unit type: an
      -- unrecognised triple is the thing that would silently colour every plate
      -- hostile, so it has to be readable rather than inferred.
      local r, g, b = Call(parts.healthbar, "GetStatusBarColor")
      local mapped = reaction.FromTint(r, g, b)
      if mapped then
        report.sample.barColor = mapped
      elseif type(r) == "number" and type(g) == "number" and type(b) == "number" then
        report.sample.barColor = string.format("unmapped %.2f,%.2f,%.2f", r, g, b)
      else
        report.sample.barColor = "none"
      end
      break
    end
  end

  report.rejectReasons = rejectReasons
  return report
end

-- Raw description of every WorldFrame child, whether or not it was adopted.
--
-- The first in-game run reported 28 children and 0 plates, which says the
-- signature is wrong but not how. This is the readout that answers it: object
-- type, region and child composition, the texture paths and the fontstring
-- text actually present. It reads only -- nothing here mutes or adopts.
function U.NameplateDump()
  local out = {}

  local worldFrame = U.G("WorldFrame")
  if not worldFrame then return out end

  local count = tonumber(Call(worldFrame, "GetNumChildren")) or 0
  local ok, kids = pcall(function() return { worldFrame:GetChildren() } end)
  if not ok or type(kids) ~= "table" then return out end

  local i, j
  for i = 1, count do
    local child = kids[i]
    if child then
      local entry = {
        index = i,
        otype = ObjectType(child) or "?",
        name = Call(child, "GetName"),
        visible = Call(child, "IsVisible") and true or false,
        width = tonumber(Call(child, "GetWidth")),
        height = tonumber(Call(child, "GetHeight")),
        adopted = registry[child] and true or false,
        textures = 0,
        fontstrings = 0,
        children = 0,
        texturePaths = {},
        texts = {},
        childTypes = {},
      }

      local rOk, regions = pcall(function() return { child:GetRegions() } end)
      if rOk and type(regions) == "table" then
        for j = 1, table.getn(regions) do
          local regionType = ObjectType(regions[j])
          if regionType == "Texture" then
            entry.textures = entry.textures + 1
            local path = Call(regions[j], "GetTexture")
            if type(path) == "string" and table.getn(entry.texturePaths) < 4 then
              -- Only the tail is useful and chat lines are short.
              table.insert(entry.texturePaths, string.sub(path, -28))
            end
          elseif regionType == "FontString" then
            entry.fontstrings = entry.fontstrings + 1
            local text = Call(regions[j], "GetText")
            if type(text) == "string" and table.getn(entry.texts) < 3 then
              table.insert(entry.texts, text)
            end
          end
        end
      end

      local cOk, subs = pcall(function() return { child:GetChildren() } end)
      if cOk and type(subs) == "table" then
        entry.children = table.getn(subs)
        for j = 1, entry.children do
          if table.getn(entry.childTypes) < 3 then
            local hasValue = false
            pcall(function() hasValue = type(subs[j].GetValue) == "function" end)
            table.insert(entry.childTypes,
              (ObjectType(subs[j]) or "?") .. (hasValue and "*" or ""))
          end
        end
      end

      table.insert(out, entry)
    end
  end

  return out
end

-- ---------------------------------------------------------------------------
-- Module lifecycle
-- ---------------------------------------------------------------------------
function NP:OnInit()
  cfg = U.ModuleConfig("nameplates", defaults)
  -- The pages live in modules/nameplatesettings.lua.
  if type(U.RegisterNameplateSettings) == "function" then
    U.RegisterNameplateSettings()
  end
end

function NP:OnEnable()
  if not cfg.enabled then return end

  -- The hostile/friendly switches need a ready world (ShowNameplates is
  -- documented as a no-op before that), and a loading screen may reset them.
  -- OnEnable itself may run on that very event (core/init.lua), so apply once
  -- now as well.
  U.RegisterEvent("PLAYER_ENTERING_WORLD", style.ScheduleVisibility)
  style.ScheduleVisibility()

  if type(U.G("C_NamePlate")) == "table" then
    U.RegisterEvent("NAME_PLATE_CREATED", OnPlateCreated)
  end

  -- Discovery and the shown/recycled check run every frame, so a new plate
  -- never draws its native art; both are cheap while nothing changes. The
  -- full refresh stays on 0.1s.
  U.RegisterUpdate("nameplates.watch", 0, function()
    if U.PerfDisabled and U.PerfDisabled("plates") then return end
    ScanWorldFrame()
    WatchPlates()
  end)
  U.RegisterUpdate("nameplates.scan", 0.1, function()
    style.SyncKeyVisibility()
    if U.PerfDisabled and U.PerfDisabled("plates") then return end
    RefreshAll()
  end)
end
