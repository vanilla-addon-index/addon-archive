-- Swing Timer and Wand Timer
--
-- Ported from brues-code/pfUI's swingtimer module (MIT, Shagu and
-- contributors) and restyled as classic cast bars with the weapon icon.
-- ClassicAPI's PLAYER_SWING event reports the server's attack timers
-- (white hits, Heroic Strike/Maul, parry haste, extra attacks, Auto Shot
-- and wand Shoot), so nothing here guesses from the combat log.

local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API or {}

local swing = ShaguTweaks:register({
  title = T["Swing Timer"],
  description = T["Shows main-hand and off-hand swing timers above the cast bar, with the weapon's icon. Hold <Ctrl>, <Shift> and <Alt> to move each bar on its own; right-click a bar to reset it."],
  expansions = { ["vanilla"] = true },
  category = T["Action Bar"],
  enabled = false,
})

local wand = ShaguTweaks:register({
  title = T["Wand Timer"],
  description = T["Shows the time until your next wand shot (or Auto Shot) above the cast bar, with the weapon's icon."],
  expansions = { ["vanilla"] = true },
  category = T["Action Bar"],
  enabled = false,
})

local WIDTH, HEIGHT = 195, 13
local SPACING = 24      -- one bar plus its cast bar border
local GRACE = .15       -- bridge the frame or two until the next PLAYER_SWING
local THROTTLE = .02
local AUTOSHOT_WINDUP = .5

local COLORS = {
  mainhand = { 1, .7, 0 },    -- the cast bar's own gold
  offhand  = { 0, 1, 0 },     -- the channel bar's green
  ranged   = { .3, .6, 1 },
  far      = { .5, .5, .5 },  -- target out of range
  windup   = { 1, 0, 0 },     -- Auto Shot wind-up: don't move
  -- queued on-next-swing abilities, on the main-hand bar
  hs       = { .4, .8, 1 },   -- Heroic Strike: light blue (gold would hide pfUI's yellow)
  cleave   = { .2, .9, .2 },  -- Cleave: green, as in pfUI
  maul     = { 1, .55, 0 },   -- Maul: orange, as in pfUI
}

-- Rank 1 spell IDs; every rank shares the localized name.
local QUEUE_SPELLS = { hs = 78, cleave = 845, maul = 6807 }

local SLOTS = { mainhand = 16, offhand = 17, ranged = 18 }
local ORDER = { "mainhand", "offhand", "ranged" }
local PREVIEW = { mainhand = T["Main Hand"], offhand = T["Off Hand"], ranged = T["Ranged"] }

-- Everything lives in one table: Lua 5.0 allows only 32 upvalues per function.
local S = {
  melee = false, ranged = false,
  autoattack = false, autorepeat = false, combat = false,
  hunter = false, preview = false, elapsed = 0,
  far = {},
  bars = {},
  -- Heroic Strike / Cleave / Maul queue
  queue = false,       -- this class can queue one of them
  queued = nil,        -- "hs", "cleave", "maul" or nil
  queuedSeen = false,  -- its action button has been seen lit
  queueNames = {},     -- localized name -> kind
  queueSlots = {},     -- kind -> action slots holding it
  nextMelee = {},      -- spellID -> kind or false
}

-- Classify a spell ID as "hs", "cleave", "maul" or nil.
local function QueueKind(spellID)
  if not spellID or spellID <= 0 then return end
  local known = S.nextMelee[spellID]
  if known ~= nil then return known or nil end

  local kind = false
  if _G.C_Spell.IsNextMeleeSpell(spellID) then
    kind = S.queueNames[_G.C_Spell.GetSpellName(spellID) or ""] or false
  end
  S.nextMelee[spellID] = kind
  return kind or nil
end

-- Find the action buttons that hold each ability. A queued ability lights
-- its button (IsCurrentAction); Esc or a second press un-queues it without
-- any event, so the lit buttons are how a cancel is noticed.
local function ScanQueueSlots()
  S.queueSlots = { hs = {}, cleave = {}, maul = {} }
  if not S.queue then return end

  for slot = 1, 120 do
    local kind, id = GetActionInfo(slot)
    local name
    if kind == "spell" then
      name = _G.C_Spell.GetSpellName(id)
    elseif kind == "macro" then
      name = GetMacroSpell(id)
    end
    local queueKind = name and S.queueNames[name]
    if queueKind then table.insert(S.queueSlots[queueKind], slot) end
  end
end

local function ClearQueue()
  S.queued = nil
  S.queuedSeen = false
end

-- Keep the queued color while a button of that ability is lit. Once seen
-- lit and then dark, it was cancelled. Never seen lit (cast from a macro or
-- keybind not on the bars): keep it until the spell goes off or fails.
local function ReconcileQueue()
  if not S.queued then return end
  local slots = S.queueSlots[S.queued]
  if not slots then return end

  for i = 1, table.getn(slots) do
    if IsCurrentAction(slots[i]) then
      S.queuedSeen = true
      return
    end
  end

  if S.queuedSeen then ClearQueue() end
end

local function Supported()
  if not _G.C_SwingTimer or not _G.Enum or not _G.Enum.PlayerSwingType then return end
  local utils = _G.C_EventUtils
  if utils and utils.IsEventValid and not utils.IsEventValid("PLAYER_SWING") then return end
  return true
end

local ModifiersDown = ShaguTweaks.API.AreMoveModifiersDown

local function HasOffhandWeapon()
  local items = _G.C_Item
  if items and items.GetItemInventoryType then
    local invtype = items.GetItemInventoryType({ equipmentSlotIndex = SLOTS.offhand })
    return invtype == 13 or invtype == 22 -- one-hand, off-hand weapon
  end

  local link = GetInventoryItemLink("player", SLOTS.offhand)
  local _, _, id = link and string.find(link, "item:(%d+)")
  if not id then return false end
  local _, _, _, _, _, _, _, equip = GetItemInfo(tonumber(id))
  return equip == "INVTYPE_WEAPON" or equip == "INVTYPE_WEAPONOFFHAND"
end

local function UpdateSpeeds()
  local mh, oh = UnitAttackSpeed("player")
  S.bars.mainhand.speed = (mh and mh > 0) and mh or S.bars.mainhand.speed or 0
  S.bars.offhand.speed = (HasOffhandWeapon() and oh and oh > 0) and oh or 0
  local ra = UnitRangedDamage("player")
  S.bars.ranged.speed = (ra and ra > 0) and ra or 0
end

local function UpdateIcon(bar)
  local texture = GetInventoryItemTexture("player", bar.slot)
  if texture then
    bar.icon.texture:SetTexture(texture)
    bar.icon:Show()
  else
    bar.icon:Hide()
  end
end

local function Wanted(bar)
  if bar.key == "ranged" then return S.ranged end
  return S.melee
end

-- Every bar can have its own saved spot ("SwingTimerPosition_<bar>").
local function BarPosition(key)
  local pos = ShaguTweaks_config and ShaguTweaks_config["SwingTimerPosition_" .. key]
  if pos and pos[1] and pos[2] then return pos end
end

-- Bars without a saved spot stack upward from the container, in a fixed
-- order; bars with one sit where they were put.
local function Layout()
  local slot = 0
  for i = 1, 3 do
    local bar = S.bars[ORDER[i]]
    if bar:IsShown() then
      local pos = BarPosition(bar.key)
      bar:ClearAllPoints()
      if pos then
        bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])
      else
        bar:SetPoint("BOTTOM", S.container, "BOTTOM", 0, slot * SPACING)
        slot = slot + 1
      end
    end
  end
end

local function SetProgress(bar, progress, r, g, b)
  bar:SetValue(progress)
  bar:SetStatusBarColor(r, g, b)
  bar.spark:SetPoint("CENTER", bar, "LEFT", progress * WIDTH, 2)
end

local function StopBar(bar)
  if bar.wake then bar.wake:Cancel(); bar.wake = nil end
  if bar.windupWake then bar.windupWake:Cancel(); bar.windupWake = nil end
  if bar.binding then bar.binding:Disable() end
  bar.active = false
  bar.inWindup = false
  bar.timer = 0
  bar.graceAt = nil
  if not S.preview then bar:Hide() end
end

local function Running(bar)
  return bar.key == "ranged" and S.autorepeat
    or (bar.key ~= "ranged" and S.autoattack and S.combat)
end

local function UpdateColors()
  if S.preview then return end
  ReconcileQueue()
  for i = 1, 3 do
    local bar = S.bars[ORDER[i]]
    local color = COLORS[bar.key]
    if bar.key == "mainhand" and S.queued then color = COLORS[S.queued] end
    if bar.key == "ranged" and S.hunter and bar.active and bar.inWindup then color = COLORS.windup end
    if S.far[bar.swingType] then color = COLORS.far end
    bar:SetStatusBarColor(unpack(color))
  end
end

local function StopWaitingBars()
  if not S.native then return end
  local changed = false
  for i = 1, 3 do
    local bar = S.bars[ORDER[i]]
    if bar.active and bar.graced and not Running(bar) then StopBar(bar); changed = true end
  end
  if changed then Layout() end
end

local function StartBar(bar, remaining)
  if not Wanted(bar) or S.preview then return end
  if type(remaining) ~= "number" or remaining ~= remaining or remaining < 0 then return end
  UpdateSpeeds()
  if bar.speed <= 0 then return end

  -- remaining can be shorter than the weapon speed (parry haste, Auto Shot
  -- wind-up): keep the full swing as the bar length and start part-way.
  bar.max = math.max(bar.speed, remaining)
  bar.timer = remaining
  bar.graceAt = nil
  bar.active = true
  bar.graced = nil
  bar.inWindup = bar.key == "ranged" and S.hunter and remaining > 0 and remaining <= AUTOSHOT_WINDUP
  UpdateIcon(bar)

  if S.native then
    if bar.wake then bar.wake:Cancel() end
    if bar.windupWake then bar.windupWake:Cancel(); bar.windupWake = nil end
    bar.duration:SetTimeFromEnd(GetTime() + remaining, bar.max)
    bar:SetTimerDuration(bar.duration, _G.Enum.StatusBarInterpolation.Immediate,
      _G.Enum.StatusBarTimerDirection.ElapsedTime)
    bar.binding:Enable()
    bar.wake = _G.C_Timer.NewTimer(remaining, bar.due)
    if bar.key == "ranged" and S.hunter and remaining > AUTOSHOT_WINDUP then
      bar.windupWake = _G.C_Timer.NewTimer(remaining - AUTOSHOT_WINDUP, bar.windup)
    end
    UpdateColors()
  end

  if not bar:IsShown() then
    bar:Show()
    Layout()
  end
  if not S.native then S.driver:Show() end
end

local function ResetAll()
  for i = 1, 3 do StopBar(S.bars[ORDER[i]]) end
  Layout()
end

local function Tick(bar, delta, now)
  if not bar.active then return end

  bar.timer = bar.timer - delta
  if bar.timer <= 0 then
    bar.timer = 0
    -- Keep a full bar while auto-attack or Shoot is still on (the target may
    -- just be out of reach); hide it once the attacks stopped.
    local running = bar.key == "ranged" and S.autorepeat or (bar.key ~= "ranged" and S.autoattack and S.combat)
    if not bar.graceAt then
      bar.graceAt = now + GRACE
    elseif now >= bar.graceAt and not running then
      StopBar(bar)
      Layout()
      return
    end
  end

  local r, g, b = unpack(COLORS[bar.key])
  if bar.key == "mainhand" and S.queued then
    ReconcileQueue()
    if S.queued then r, g, b = unpack(COLORS[S.queued]) end
  end
  if bar.key == "ranged" and S.hunter and bar.timer > 0 and bar.timer <= AUTOSHOT_WINDUP then
    r, g, b = unpack(COLORS.windup)
  end
  if S.far[bar.swingType] then
    r, g, b = unpack(COLORS.far)
  end

  SetProgress(bar, 1 - bar.timer / bar.max, r, g, b)

  local tenth = math.floor(bar.timer * 10)
  if bar.lastTenth ~= tenth then
    bar.lastTenth = tenth
    bar.text:SetText(string.format("%.1f", tenth / 10))
  end
end

local function OnUpdate()
  S.elapsed = S.elapsed + arg1
  if S.elapsed < THROTTLE then return end
  local delta = S.elapsed
  S.elapsed = 0

  local now = GetTime()
  local any = false
  for i = 1, 3 do
    local bar = S.bars[ORDER[i]]
    Tick(bar, delta, now)
    any = any or bar.active
  end

  if not any then this:Hide() end
end

-- Classic cast bar look: dark background, UI-StatusBar fill, the cast bar
-- border and spark, and an icon frame like Improved Castbar's.
local function ApplyBarTheme(bar)
  local tint, edge = ShaguTweaks.UITint, ShaguTweaks.UIBorder
  bar.border:SetVertexColor(tint and tint.r or 1, tint and tint.g or 1,
    tint and tint.b or 1, tint and tint.a or 1)
  bar.icon:SetBackdropBorderColor(edge and edge.r or 1, edge and edge.g or 1,
    edge and edge.b or 1, edge and edge.a or 1)
end

local function CreateBar(key)
  local bar = CreateFrame("StatusBar", "ShaguTweaksSwingTimer_" .. key, S.container)
  bar:SetWidth(WIDTH)
  bar:SetHeight(HEIGHT)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  bar:Hide()

  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints(bar)
  bar.bg:SetTexture(0, 0, 0, .5)

  -- The StatusBar fill uses ARTWORK; keep the rim above it at every progress.
  bar.border = bar:CreateTexture(nil, "OVERLAY")
  bar.border:SetTexture("Interface\\CastingBar\\UI-CastingBar-Border")
  bar.border:SetWidth(256)
  bar.border:SetHeight(64)
  bar.border:SetPoint("TOP", bar, "TOP", 0, 28)

  bar.spark = bar:CreateTexture(nil, "OVERLAY")
  bar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
  bar.spark:SetBlendMode("ADD")
  bar.spark:SetWidth(32)
  bar.spark:SetHeight(32)
  bar.spark:SetPoint("CENTER", bar, "LEFT", 0, 2)

  bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  bar.text:SetPoint("CENTER", bar, "CENTER", 0, 3)

  -- As in pfUI, native duration objects own the fill and countdown. The
  -- spark follows the native fill texture without a Lua position updater.
  if S.native and type(bar.SetTimerDuration) ~= "function" then S.native = false end
  if S.native then
    bar.duration = _G.C_DurationUtil.CreateDuration()
    bar.binding = _G.C_DurationUtil.CreateDurationTextBinding()
    bar.binding:SetFontString(bar.text)
    bar.binding:SetDuration(bar.duration)
    bar.binding:SetFormatter(S.formatter)
    bar.binding:SetExpiredText("0.0")
    bar.binding:Disable()
    bar.spark:ClearAllPoints()
    bar.spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 2)
    -- Allocate callbacks once per bar, not on every swing reset.
    bar.grace = function()
      bar.wake = nil
      bar.graced = true
      if not Running(bar) then StopBar(bar); Layout() end
    end
    bar.due = function()
      bar.inWindup = false
      bar.binding:Disable()
      if not S.preview then bar.text:SetText("0.0") end
      bar.wake = _G.C_Timer.NewTimer(GRACE, bar.grace)
      UpdateColors()
    end
    bar.windup = function()
      bar.windupWake = nil
      bar.inWindup = true
      UpdateColors()
    end
  end

  bar.icon = CreateFrame("Frame", nil, bar)
  bar.icon:SetPoint("RIGHT", bar, "LEFT", -10, 2)
  bar.icon:SetWidth(28)
  bar.icon:SetHeight(28)
  bar.icon:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
  })

  bar.icon.texture = bar.icon:CreateTexture(nil, "BACKGROUND")
  bar.icon.texture:SetPoint("CENTER", 0, 0)
  bar.icon.texture:SetWidth(24)
  bar.icon.texture:SetHeight(24)
  bar.icon.texture:SetTexCoord(.08, .92, .08, .92)
  ApplyBarTheme(bar)
  -- Modules initialize in arbitrary order. Read the final palette when a real
  -- timer or mover preview appears, without an idle update or recolor scan.
  bar:SetScript("OnShow", function() ApplyBarTheme(this) end)

  -- Each bar is dragged on its own while the preview is up.
  bar:SetMovable(true)
  bar:SetClampedToScreen(true)
  bar:EnableMouse(false)
  bar:SetScript("OnMouseDown", function()
    if arg1 == "LeftButton" then this:StartMoving() end
  end)
  bar:SetScript("OnMouseUp", function()
    this:StopMovingOrSizing()
    ShaguTweaks_config = ShaguTweaks_config or {}
    if arg1 == "RightButton" then
      ShaguTweaks_config["SwingTimerPosition_" .. this.key] = nil
    else
      ShaguTweaks_config["SwingTimerPosition_" .. this.key] = { this:GetLeft(), this:GetBottom() }
    end
    Layout()
  end)

  bar.key = key
  bar.slot = SLOTS[key]
  bar.swingType = _G.Enum.PlayerSwingType[key == "mainhand" and "MainHand" or key == "offhand" and "OffHand" or "Ranged"]
  bar.speed, bar.timer, bar.max = 0, 0, 1

  return bar
end

-- Hold Ctrl+Shift+Alt to show every enabled bar and drag each one on its own;
-- right-click a bar to put just that one back.
local function SetPreview(on)
  if S.preview == on then return end
  S.preview = on

  for i = 1, 3 do
    local bar = S.bars[ORDER[i]]
    bar:EnableMouse(on)
    if not on then bar:StopMovingOrSizing() end
    if on and Wanted(bar) then
      if bar.binding then bar.binding:Disable(); bar:SetMinMaxValues(0, 1) end
      UpdateIcon(bar)
      local r, g, b = unpack(COLORS[bar.key])
      SetProgress(bar, 1, r, g, b)
      bar.text:SetText(PREVIEW[bar.key])
      bar.lastTenth = nil
      bar:Show()
    elseif S.native and bar.active then
      bar.spark:ClearAllPoints()
      bar.spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 2)
      bar:SetTimerDuration(bar.duration, _G.Enum.StatusBarInterpolation.Immediate,
        _G.Enum.StatusBarTimerDirection.ElapsedTime)
      if bar.duration:GetRemainingDuration() > 0 then bar.binding:Enable()
      else bar.text:SetText("0.0") end
    elseif not bar.active then
      bar:Hide()
    end
  end

  Layout()
  if S.native then UpdateColors() end
end

-- Keep the bars where they are when something they were stacked on (the cast
-- bar) is dragged: every bar that still follows the default spot is pinned.
ShaguTweaks.FreezeSwingBars = function()
  if not S.container then return end
  for i = 1, 3 do
    local bar = S.bars[ORDER[i]]
    local key = "SwingTimerPosition_" .. bar.key
    local left, bottom = bar:GetLeft(), bar:GetBottom()
    if bar:IsShown() and left and bottom and not BarPosition(bar.key) then
      ShaguTweaks_config = ShaguTweaks_config or {}
      ShaguTweaks_config[key] = { left, bottom }
    end
  end
  Layout()
end

local function RestorePosition()
  local pos = ShaguTweaks_config and ShaguTweaks_config["SwingTimerPosition"]
  S.container:ClearAllPoints()
  if pos and pos[1] and pos[2] then
    S.container:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])
  else
    -- default: stacked just above the cast bar
    S.container:SetPoint("BOTTOM", CastingBarFrame, "TOP", 0, 20)
  end
end

local function CreateCore()
  if S.container then return true end
  if not Supported() then return end

  S.container = CreateFrame("Frame", "ShaguTweaksSwingTimer", UIParent)
  S.container:SetWidth(WIDTH)
  S.container:SetHeight(HEIGHT)
  S.container:EnableMouse(false)

  S.native = API.durationtimers and true or false
  if S.native then
    S.formatter = _G.C_StringUtil.CreateNumericRuleFormatter()
    S.formatter:AddBreakpoint({ threshold = 0, step = .1,
      rounding = _G.Enum.NumericRuleFormatRounding.Down, format = "%.1f" })
  end

  for i = 1, 3 do S.bars[ORDER[i]] = CreateBar(ORDER[i]) end

  if not S.native then
    S.driver = CreateFrame("Frame", nil, UIParent)
    S.driver:Hide()
    S.driver:SetScript("OnUpdate", OnUpdate)
  end

  S.events = CreateFrame("Frame")
  S.events:SetScript("OnEvent", function()
    if event == "PLAYER_SWING" then
      local swingType = _G.Enum.PlayerSwingType
      if arg2 == swingType.MainHand then
        StartBar(S.bars.mainhand, arg1)
      elseif arg2 == swingType.OffHand then
        StartBar(S.bars.offhand, arg1)
      elseif arg2 == swingType.Ranged then
        StartBar(S.bars.ranged, arg1)
      end

    elseif event == "PLAYER_SWING_RANGE_UPDATE" then
      -- arg1 swing type, arg2 in range, arg3 a check was possible
      S.far[arg1] = arg3 and not arg2

    elseif event == "PLAYER_TARGET_CHANGED" then
      for i = 1, 3 do
        local swingType = S.bars[ORDER[i]].swingType
        S.far[swingType] = _G.C_SwingTimer.IsTargetWithinSwingRange(swingType) == false
      end

    elseif event == "PLAYER_ENTER_COMBAT" or event == "START_AUTOATTACK" then
      S.autoattack = true
    elseif event == "PLAYER_LEAVE_COMBAT" or event == "STOP_AUTOATTACK" then
      S.autoattack = false
    elseif event == "START_AUTOREPEAT_SPELL" then
      S.autorepeat = true
    elseif event == "STOP_AUTOREPEAT_SPELL" then
      S.autorepeat = false
    elseif event == "PLAYER_REGEN_DISABLED" then
      S.combat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
      S.combat = false
      ClearQueue()

    elseif event == "UNIT_SPELLCAST_SENT" then
      -- arg1 unit, arg4 spellID: Heroic Strike, Cleave or Maul queued
      if arg1 == "player" and S.queue then
        local kind = QueueKind(arg4)
        if kind then
          S.queued = kind
          S.queuedSeen = false
        end
      end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_FAILED" then
      -- arg1 unit, arg3 spellID: the queued swing went off or was refused
      if arg1 == "player" and S.queued and QueueKind(arg3) then
        ClearQueue()
      end

    elseif event == "ACTIONBAR_SLOT_CHANGED" then
      if S.queue then ScanQueueSlots() end

    elseif event == "ACTIONBAR_UPDATE_STATE" then
      -- Native timers do not poll action buttons. This event covers cancelling
      -- a queued attack by pressing it again or pressing Escape.
      ReconcileQueue()

    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED" then
      if event == "PLAYER_EQUIPMENT_CHANGED" and arg1 ~= 16 and arg1 ~= 17 and arg1 ~= 18 then return end
      UpdateSpeeds()
      for i = 1, 3 do
        local bar = S.bars[ORDER[i]]
        UpdateIcon(bar)
        if bar.active and bar.speed <= 0 then StopBar(bar) end
      end
      Layout()

    elseif event == "MODIFIER_STATE_CHANGED" then
      SetPreview(ModifiersDown() and true or false)

    elseif event == "PLAYER_DEAD" then
      ClearQueue()
      ResetAll()

    elseif event == "PLAYER_ENTERING_WORLD" then
      local _, class = UnitClass("player")
      S.hunter = class == "HUNTER"
      UpdateSpeeds()
      RestorePosition()
    end
    if S.native then StopWaitingBars(); UpdateColors() end
  end)

  local events = {
    "PLAYER_SWING", "PLAYER_SWING_RANGE_UPDATE", "PLAYER_TARGET_CHANGED",
    "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT",
    "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PLAYER_DEAD", "PLAYER_ENTERING_WORLD", "MODIFIER_STATE_CHANGED",
    -- ClassicAPI v1.18.14+; the 1.12 combat events above cover older versions
    "START_AUTOATTACK", "STOP_AUTOATTACK",
  }
  local utils = _G.C_EventUtils
  for i = 1, table.getn(events) do
    if not utils or not utils.IsEventValid or utils.IsEventValid(events[i]) then
      S.events:RegisterEvent(events[i])
    end
  end

  -- ClassicAPI's per-slot equipment event when present, else the 1.12 one
  if utils and utils.IsEventValid and utils.IsEventValid("PLAYER_EQUIPMENT_CHANGED") then
    S.events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  else
    S.events:RegisterEvent("UNIT_INVENTORY_CHANGED")
  end

  local _, class = UnitClass("player")
  S.hunter = class == "HUNTER"
  S.combat = UnitAffectingCombat("player") and true or false
  UpdateSpeeds()
  RestorePosition()
  return true
end

-- The range event fires only on a change, so read the state once.
local function EnableRangeCheck(bar)
  _G.C_SwingTimer.EnableRangeCheck(bar.swingType, true)
  S.far[bar.swingType] = _G.C_SwingTimer.IsTargetWithinSwingRange(bar.swingType) == false
end

-- Heroic Strike / Cleave (warriors) and Maul (druids) queue colors.
local function EnableQueueColors()
  local spell = _G.C_Spell
  if not spell or not spell.IsNextMeleeSpell or not spell.GetSpellName or not GetActionInfo then return end

  local _, class = UnitClass("player")
  local kinds = class == "WARRIOR" and { "hs", "cleave" } or class == "DRUID" and { "maul" }
  if not kinds then return end

  for i = 1, table.getn(kinds) do
    local name = spell.GetSpellName(QUEUE_SPELLS[kinds[i]])
    if name then S.queueNames[name] = kinds[i] end
  end
  S.queue = true
  ScanQueueSlots()

  -- player-only where ClassicAPI can filter: SUCCEEDED fires for every unit
  local events = S.events
  local unitEvents = { "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED" }
  for i = 1, table.getn(unitEvents) do
    if events.RegisterUnitEvent then
      events:RegisterUnitEvent(unitEvents[i], "player")
    else
      events:RegisterEvent(unitEvents[i])
    end
  end
  events:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
  events:RegisterEvent("ACTIONBAR_UPDATE_STATE")
end

swing.enable = function(self)
  if not CreateCore() then return end
  S.melee = true
  EnableRangeCheck(S.bars.mainhand)
  EnableRangeCheck(S.bars.offhand)
  EnableQueueColors()
end

wand.enable = function(self)
  if not CreateCore() then return end
  S.ranged = true
  EnableRangeCheck(S.bars.ranged)
end
