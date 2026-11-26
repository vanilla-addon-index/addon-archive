--[[
OctoPad v1.4.0  -  gamepad layer for OctoWoW (1.12 / Interface 11200)

The 1.12 client has no gamepad API. A controller reaches the game as keyboard
input (Steam Input, JoyToKey, AntiMicroX, ...). OctoPad gives those keys console
meaning:

  * LAYOUT  : ConsoleExperienceClassic key scheme and action-slot numbers
              (face 1-4, d-pad 5-8, bumpers 9/0, LT = Shift, RT = Ctrl).
  * LOGIC   : optional "forever" profile following WoW: Forever's gamepad logic.
  * GLYPHS  : Xbox, PlayStation, Nintendo Switch Pro labels.
  * CONTEXT : every button has a GAME action and a WINDOW action. While a window
              (bags, map, character, merchant, ...) is open the window action wins.
  * SECURE  : OctoWoW blocks addons from "protected" functions (Jump, auto-run,
              ...). Those actions are therefore bound to Blizzard's own binding
              commands instead of being called from Lua.

Files: OctoPad.lua (core) / OctoPadHUD.lua (HUD, layout editor, radial) /
OctoPadUI.lua (window navigation) / OctoPadMenu.lua (minimap button + options).
Lua 5.0: no '#', no '%', no varargs.
]]

OctoPad = {}
local OP = OctoPad
OP.VERSION = "1.13.0"

local defaults = {
  profile  = "ce",       -- "ce" | "forever"
  style    = "xbox",     -- "xbox" | "ps" | "switch" | "switchn"
  hud      = true,
  scale    = 1,
  hudpos   = "auto",     -- auto | barsides | bottom | abovebars | bottomleft | bottomright | custom
  chords   = false,      -- LB+RB chord layer (Steam sends ALT-1..ALT-8)
  bound    = false,
  enforce  = true,       -- re-apply bindings at login if something overwrote them
  firstrun = false,
  mmshow   = true,
  mmangle  = 225,
  mmshape  = "auto",     -- auto | round | square
  native   = true,       -- secure mode: protected actions use Blizzard's own bindings
  uimode   = true,       -- controller navigates open windows (context-aware buttons)
  smartfocus = true,     -- the focus ring starts on the most likely input (Accept, Complete Quest, ...)
  hints    = true,       -- button hint bar while a window is open
  keycaps  = "chevron",  -- window-control icon style: chevron (default) / retro / pfui
  sysicons = true,       -- controller-aware icons for system actions
  soft     = true,       -- soft highlight of every nameplated unit + tooltip for the one nearest the centre
  smarttarget = true,    -- spells / attacks / heals / buffs pick their target (soft target, mouseover, self)
  stickradial = true,    -- left stick selects in the radial menu
}

local cfg
OP.lastSlot = nil
OP.lastTime = 0
OP.edit = false

function OP.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[OctoPad]|r " .. msg)
end
local Print = OP.Print

function OP.Font()
  if pfUI and pfUI.font_default then return pfUI.font_default end
  return "Fonts\\FRIZQT__.TTF"
end

-- pfUI border colour ("r,g,b,a" string in pfUI_config.appearance.border.color)
function OP.BorderColor()
  local c = pfUI_config and pfUI_config.appearance and pfUI_config.appearance.border and pfUI_config.appearance.border.color
  if c then
    local _, _, r, g, b = string.find(c, "([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)")
    if r then return tonumber(r), tonumber(g), tonumber(b) end
  end
  return .4, .4, .4
end

-- Apply pfUI's own backdrop to a big container frame when pfUI is present.
function OP.Skin(frame, alpha)
  if pfUI and pfUI.api and pfUI.api.CreateBackdrop then
    local ok = pcall(pfUI.api.CreateBackdrop, frame, nil, nil, alpha or .85)
    if ok then return true end
  end
  return false
end

-- pfUI's rounded backdrop for any frame: returns true when pfUI drew it (the frame's own backdrop is
-- then removed; use OP.BD(frame) to colour borders / fills), false to let the caller use a flat one.
function OP.Round(f, alpha)
  if f.opRounded ~= nil then return f.opRounded end
  local ok = OP.Skin(f, alpha)
  f.opRounded = (ok and f.backdrop) and true or false
  if f.opRounded then f:SetBackdrop(nil) end
  return f.opRounded
end

function OP.BD(f)
  if f.opRounded and f.backdrop then return f.backdrop end
  return f
end

-- Theme: pfUI's colours when pfUI is loaded, a neutral dark scheme otherwise.
local function ParseColor(str, d)
  if type(str) == "string" then
    local _, _, r, g, b, a = string.find(str, "([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,?%s*([%d%.]*)")
    if r then return { tonumber(r), tonumber(g), tonumber(b), tonumber(a) or 1 } end
  end
  return d
end

function OP.Theme()
  local t = { bg = { .05, .06, .08, .92 }, bd = { .25, .27, .3, 1 }, ac = { .2, 1, .8, 1 } }
  local ap = pfUI_config and pfUI_config.appearance
  if ap and ap.border then
    t.bg = ParseColor(ap.border.background, t.bg)
    t.bd = ParseColor(ap.border.color, t.bd)
    if t.bg[4] > .95 then t.bg[4] = .95 end
  end
  -- lighter fill for buttons / inputs
  t.fill = { math.min(1, t.bg[1] + .07), math.min(1, t.bg[2] + .07), math.min(1, t.bg[3] + .07), 1 }
  t.side = { math.max(0, t.bg[1] - .02), math.max(0, t.bg[2] - .02), math.max(0, t.bg[3] - .02), 1 }
  return t
end

-- Glyph textures (Glyphs\<style>_<key>.tga): key 1-10 buttons, t1 / t2 triggers.
local GLYPH_DIR = "Interface\\AddOns\\OctoPad\\Glyphs\\"
function OP.GlyphFor(idx)
  if idx >= 5 and idx <= 8 then return GLYPH_DIR .. "dpad_" .. idx end
  return GLYPH_DIR .. (cfg and cfg.style or "xbox") .. "_" .. idx
end
function OP.GlyphTrig(i)
  return GLYPH_DIR .. (cfg and cfg.style or "xbox") .. "_t" .. i
end

-- Icons for window controls.  Style: "chevron" (default, bold chevron pictograms tinted for the controller),
-- "retro" (keyboard keycap) or "pfui" (flat cap in your pfUI colours).
OP.ROLE_KEYCAP = {
  UI_CONFIRM = "key_confirm", UI_BACK = "key_back", UI_ALT = "key_alt", UI_SHIFT = "key_shift",
  UI_UP = "key_up", UI_DOWN = "key_down", UI_LEFT = "key_left", UI_RIGHT = "key_right",
  UI_TAB_NEXT = "key_tabnext", UI_TAB_PREV = "key_tabprev",
  UI_SCROLL_UP = "key_scrollup", UI_SCROLL_DOWN = "key_scrolldown", UI_DESTROY = "key_destroy",
}
function OP.KeycapStyle()
  local k = cfg and cfg.keycaps
  if k == "retro" or k == "pfui" then return k end
  return "chevron"                       -- default; also an old "auto" value
end
-- paint `icon` (and the `legend` texture lying over it) as the keycap for a window role; returns false if none
function OP.PaintKeycap(icon, legend, role, style)
  local key = OP.ROLE_KEYCAP[role]
  if not key then return false end
  style = style or OP.KeycapStyle()
  icon:SetTexCoord(0, 1, 0, 1)
  if style == "chevron" then
    local st = cfg and cfg.style or "xbox"
    local th = (st == "ps") and "ps" or ((st == "switch" or st == "switchn") and "switch" or "xbox")
    icon:SetTexture("Interface\\AddOns\\OctoPad\\Icons\\" .. th .. "_" .. role)
    icon:SetVertexColor(1, 1, 1)
    if legend then legend:Hide() end
  elseif style == "pfui" then
    local th = OP.Theme()
    local tr, tg, tb = th.fill[1] + .05, th.fill[2] + .05, th.fill[3] + .05
    local lr, lg, lb = th.ac[1], th.ac[2], th.ac[3]
    if role == "UI_CONFIRM" then tr, tg, tb = tr * .6, tg * .6 + .14, tb * .6; lr, lg, lb = .55, 1, .55
    elseif role == "UI_BACK" or role == "UI_DESTROY" then tr, tg, tb = tr * .6 + .16, tg * .6, tb * .6; lr, lg, lb = 1, .55, .5 end
    icon:SetTexture(GLYPH_DIR .. "pfcap")
    icon:SetVertexColor(tr, tg, tb)
    if legend then
      legend:SetTexture(GLYPH_DIR .. "pkl_" .. string.sub(key, 5))
      legend:SetVertexColor(lr, lg, lb)
      legend:Show()
    end
  else
    icon:SetTexture(GLYPH_DIR .. key)
    icon:SetVertexColor(1, 1, 1)
    if legend then legend:Hide() end
  end
  return true
end

----------------------------------------------------------------------
-- Glyph styles
--   face[1..4] labels for keys 1,2,3,4   (CE order: A, X, Y, B)
--   bump[1] = key 9 (RB position), bump[2] = key 0 (LB position)
--   trig[1] = Shift (LT position), trig[2] = Ctrl (RT position)
--   pos = "xbox"     : key1 bottom, key2 left, key3 top, key4 right
--         "nintendo" : key1 right,  key2 top,  key3 left, key4 bottom
-- Switch Pro uses the Xbox-style names LT/RT/LB/RB for triggers and shoulders.
----------------------------------------------------------------------
OP.STYLES = {
  xbox    = { name = "Xbox", short = "Xbox",
              face = { "A", "X", "Y", "B" }, bump = { "RB", "LB" }, trig = { "LT", "RT" },
              pos = "xbox", colors = "xbox" },
  ps      = { name = "PlayStation", short = "PlayStation",
              face = { "X", "Sq", "Tr", "O" }, bump = { "R1", "L1" }, trig = { "L2", "R2" },
              pos = "xbox", colors = "ps" },
  switch  = { name = "Switch Pro (Steam default - buttons mapped by position)", short = "Switch Pro (default)",
              face = { "B", "Y", "X", "A" }, bump = { "RB", "LB" }, trig = { "LT", "RT" },
              pos = "xbox", colors = "grey" },
  switchn = { name = "Switch Pro (Steam 'Use Nintendo Button Layout' ON)", short = "Switch Pro (Nintendo)",
              face = { "A", "X", "Y", "B" }, bump = { "RB", "LB" }, trig = { "LT", "RT" },
              pos = "nintendo", colors = "grey" },
}
OP.STYLE_ORDER = { "xbox", "ps", "switch", "switchn" }

local FACE_COLORS = {
  xbox = { { .25, .8, .25 }, { .25, .5, 1 }, { 1, .8, .1 }, { .9, .25, .25 } },
  ps   = { { .4, .6, 1 }, { .95, .55, .85 }, { .25, .8, .6 }, { .9, .25, .25 } },
  grey = { { .7, .7, .7 }, { .7, .7, .7 }, { .7, .7, .7 }, { .7, .7, .7 } },
}
local DPAD_LABELS = { "Dn", "L", "Up", "R" }

function OP.Style()
  return OP.STYLES[cfg.style] or OP.STYLES.xbox
end

function OP.LabelFor(idx)
  local st = OP.Style()
  if idx <= 4 then return st.face[idx]
  elseif idx <= 8 then return DPAD_LABELS[idx - 4]
  elseif idx == 9 then return st.bump[1]
  end
  return st.bump[2]
end

function OP.ColorFor(idx)
  local st = OP.Style()
  if idx <= 4 then
    local c = FACE_COLORS[st.colors][idx]
    return c[1], c[2], c[3]
  end
  return .35, .35, .35
end

-- "LT + A" style name for a slot number 1..40
function OP.SlotName(n)
  local st = OP.Style()
  local page = math.floor((n - 1) / 10)
  local idx = math.mod(n - 1, 10) + 1
  local prefix = ""
  if page == 1 then prefix = st.trig[1] .. " + "
  elseif page == 2 then prefix = st.trig[2] .. " + "
  elseif page == 3 then prefix = st.trig[1] .. " + " .. st.trig[2] .. " + " end
  return prefix .. OP.LabelFor(idx)
end

----------------------------------------------------------------------
-- Binding names (Key Bindings menu)
----------------------------------------------------------------------
BINDING_HEADER_OCTOPAD = "OctoPad - Controller Actions"
BINDING_HEADER_OCTOPADEXTRA = "OctoPad - Extras"
BINDING_HEADER_OCTOPADCHORD = "OctoPad - LB+RB Chords (optional)"
BINDING_HEADER_OCTOPADSTICK = "OctoPad - Radial stick (internal, do not bind)"
BINDING_NAME_OCTOPAD_STICK_UP = "Radial stick up"
BINDING_NAME_OCTOPAD_STICK_LEFT = "Radial stick left"
BINDING_NAME_OCTOPAD_STICK_DOWN = "Radial stick down"
BINDING_NAME_OCTOPAD_STICK_RIGHT = "Radial stick right"
do
  local pageNames = { "", "LT + ", "RT + ", "LT + RT + " }
  local btnNames = { "A", "X", "Y", "B", "Down", "Left", "Up", "Right", "RB", "LB" }
  local i
  for i = 1, 40 do
    local page = math.floor((i - 1) / 10) + 1
    local idx = math.mod(i - 1, 10) + 1
    setglobal("BINDING_NAME_OCTOPAD_ACTION_" .. i, "Slot " .. i .. " (" .. pageNames[page] .. btnNames[idx] .. ")")
  end
  BINDING_NAME_OCTOPAD_RADIAL = "Toggle Radial Menu"
  BINDING_NAME_OCTOPAD_CAMERA = "Camera (hold) - turn the camera without clicking"
  for i = 1, 8 do
    setglobal("BINDING_NAME_OCTOPAD_CHORD_" .. i, "LB+RB chord " .. i .. " (" .. btnNames[i] .. ")")
  end
end

----------------------------------------------------------------------
-- System actions
--   native = name of Blizzard's own binding command. Actions that OctoWoW's
--   client protects (movement, combat, targeting) are bound to that command
--   directly, so OctoPad never calls the protected Lua function itself.
----------------------------------------------------------------------
OP.ACTIONS = {}
OP.ACTION_ORDER = {}
local ACTIONS = OP.ACTIONS
local QM = "Interface\\Icons\\INV_Misc_QuestionMark"
local warnedInteract = false
local warnedNative = false

local function Def(id, short, icon, fn, native)
  ACTIONS[id] = { id = id, short = short, icon = icon, fn = fn, native = native }
  table.insert(OP.ACTION_ORDER, id)
end

local function CycleGroup()
  local list = { "player" }
  local i
  if GetNumRaidMembers and GetNumRaidMembers() > 0 then
    for i = 1, GetNumRaidMembers() do table.insert(list, "raid" .. i) end
  else
    for i = 1, 4 do
      if UnitExists("party" .. i) then table.insert(list, "party" .. i) end
    end
  end
  local cur = 0
  for i = 1, table.getn(list) do
    if UnitExists("target") and UnitIsUnit("target", list[i]) then cur = i break end
  end
  cur = cur + 1
  if cur > table.getn(list) then cur = 1 end
  TargetUnit(list[cur])
end

local function DoInteract()
  if InteractNearest then
    InteractNearest(1)
    if OP.NoteInteract then OP.NoteInteract() end
    return
  end
  if not warnedInteract then
    warnedInteract = true
    Print("Interact.dll not found - install https://github.com/luskanek/Interact for a real Interact. Falling back to 'target nearest friend'.")
  end
  if TargetNearestFriend then TargetNearestFriend() end
  if OP.NoteInteract then OP.NoteInteract() end
end

local function DoBack()
  if OP.RadialShown and OP.RadialShown() then OP.CloseRadial() return end
  if OP.UIActive and OP.UIActive() then OP.UIRun("UI_BACK") return end
  if CursorHasItem and CursorHasItem() then ClearCursor() return end
  if SpellIsTargeting and SpellIsTargeting() then SpellStopTargeting() return end
  if UnitExists("target") then ClearTarget() end
end

local function DoInspect()
  if UnitExists("target") and UnitIsPlayer("target") then
    if InspectUnit then InspectUnit("target") end
  else
    Print("Inspect: target a player first.")
  end
end

--  id                  short       icon                                                       function                                          native binding
Def("JUMP",       "Jump",     "Interface\\Icons\\Spell_Nature_Levitate",      function() if Jump then Jump() end end, "JUMP")
Def("INTERACT",   "Interact", "Interface\\Icons\\Spell_Holy_LayOnHands",      DoInteract)
Def("BACK",       "Back",     "Interface\\Icons\\Spell_ChargeNegative",       DoBack)
Def("INSPECT",    "Inspect",  "Interface\\Icons\\Ability_Hunter_EagleEye",    DoInspect)
Def("AUTORUN",    "Run",      "Interface\\Icons\\Ability_Rogue_Sprint",       function() if ToggleAutoRun then ToggleAutoRun() end end, "TOGGLEAUTORUN")
Def("SITSTAND",   "Sit",      "Interface\\Icons\\Spell_Nature_Sleep",         function() if SitOrStand then SitOrStand() end end, "SITORSTAND")
Def("TARGET_ENEMY",       "Enemy",   "Interface\\Icons\\Ability_Marksmanship", function() if TargetNearestEnemy then TargetNearestEnemy() end end, "TARGETNEARESTENEMY")
Def("TARGET_ENEMY_PREV",  "Enemy-",  "Interface\\Icons\\Ability_Marksmanship", function() if TargetNearestEnemy then TargetNearestEnemy(1) end end, "TARGETPREVIOUSENEMY")
Def("TARGET_FRIEND",      "Friend",  "Interface\\Icons\\Spell_Holy_Heal",      function() if TargetNearestFriend then TargetNearestFriend() end end, "TARGETNEARESTFRIEND")
Def("TARGET_FRIEND_PREV", "Friend-", "Interface\\Icons\\Spell_Holy_Heal",      function() if TargetNearestFriend then TargetNearestFriend(1) end end, "TARGETPREVIOUSFRIEND")
Def("ASSIST",     "Assist",   "Interface\\Icons\\Ability_Hunter_MarkedForDeath", function() AssistUnit("target") end, "ASSISTTARGET")
Def("TARGET_PET", "Pet",      "Interface\\Icons\\Ability_Hunter_BeastCall",   function() TargetUnit("pet") end, "TARGETPET")
Def("CLEAR_TARGET", "Clear",  "Interface\\Icons\\Spell_Shadow_AntiShadow",    function() ClearTarget() end)
Def("CYCLE_PARTY", "Party",   "Interface\\Icons\\Spell_Holy_PrayerOfHealing", CycleGroup)
Def("ATTACK",     "Attack",   "Interface\\Icons\\Ability_SteelMelee",         function() if AttackTarget then AttackTarget() end end, "STARTATTACK")
Def("STOP_ATTACK", "Stop",    "Interface\\Icons\\Ability_Warrior_Disarm",     function() if StopAttack then StopAttack() end end, "STOPATTACK")
Def("PET_ATTACK", "PetAtk",   "Interface\\Icons\\Ability_GhoulFrenzy",        function() if PetAttack then PetAttack() end end, "PETATTACK")
Def("ZOOM_IN",    "Zoom+",    "Interface\\Icons\\Spell_Holy_MindVision",      function() CameraZoomIn(1) end)
Def("ZOOM_OUT",   "Zoom-",    "Interface\\Icons\\Spell_Holy_MindVision",      function() CameraZoomOut(1) end)
Def("MAP",        "Map",      "Interface\\Icons\\INV_Misc_Map_01",            function() ToggleWorldMap() end)
Def("BAGS",       "Bags",     "Interface\\Icons\\INV_Misc_Bag_08",            function() OpenAllBags() end)
Def("CHARACTER",  "Char",     "Interface\\Icons\\INV_Shirt_White_01",         function() ToggleCharacter("PaperDollFrame") end)
Def("SPELLBOOK",  "Spells",   "Interface\\Icons\\INV_Misc_Book_09",           function() ToggleSpellBook(BOOKTYPE_SPELL) end)
Def("TALENTS",    "Talents",  "Interface\\Icons\\Ability_Warrior_StrengthOfArms", function() ToggleTalentFrame() end)
Def("QUESTS",     "Quests",   "Interface\\Icons\\INV_Misc_Note_01",           function() ToggleQuestLog() end)
Def("SOCIAL",     "Social",   "Interface\\Icons\\INV_Letter_15",              function() ToggleFriendsFrame() end)
Def("GAMEMENU",   "Menu",     "Interface\\Icons\\INV_Misc_Gear_01",           function() ToggleGameMenu() end)
Def("CHAT",       "Chat",     "Interface\\Icons\\INV_Misc_Note_02",           function() ChatFrame_OpenChat("") end)
Def("OCTOPAD",    "Setup",    "Interface\\Icons\\INV_Misc_Gear_08",           function() if OP.ToggleMenu then OP.ToggleMenu() end end)
Def("RADIAL",     "Radial",   "Interface\\Icons\\Spell_Holy_CircleOfRenewal", function() if OP.ToggleRadial then OP.ToggleRadial() end end)

-- Blizzard's own binding command for an action, if secure mode is on and the
-- client actually knows that command.
function OP.NativeFor(id)
  local a = ACTIONS[id]
  if not a or not a.native or not cfg.native then return nil end
  if getglobal("BINDING_NAME_" .. a.native) == nil then return nil end
  return a.native
end

-- Run an action from Lua. Native-capable actions are NOT called from Lua in
-- secure mode (that is what produced the "blocked from an action only
-- available to the Blizzard UI" popup); they only run through their key.
function OP.RunAction(id)
  local a = ACTIONS[id]
  if not a then return end
  if OP.NativeFor(id) then
    if not warnedNative then
      warnedNative = true
      Print(a.short .. " runs through Blizzard's own key binding (secure mode), so it works from its controller button, not from the HUD / radial / chords. Turn off 'Secure mode' in the menu to call it from Lua.")
    end
    return
  end
  a.fn()
end

----------------------------------------------------------------------
-- Profiles. Slot numbers are the ConsoleExperienceClassic numbers:
--   1-10 base, 11-20 LT(Shift), 21-30 RT(Ctrl), 31-40 LT+RT(Ctrl+Shift)
--   position in a page: 1=A 2=X 3=Y 4=B 5=Dn 6=L 7=Up 8=R 9=RB 10=LB
----------------------------------------------------------------------
OP.PROFILES = {
  ce = {                     -- Console Experience layout; Jump / Interact depend on the controller (below)
    [20] = "SITSTAND",       -- LT + LB
    [29] = "AUTORUN",        -- RT + RB
  },
  forever = {                -- WoW: Forever logic
    [1] = "JUMP", [2] = "INTERACT", [3] = "INSPECT", [4] = "BACK",
    [9] = "TARGET_ENEMY",  [10] = "TARGET_FRIEND",
    [19] = "TARGET_ENEMY_PREV", [20] = "TARGET_FRIEND_PREV",
    [29] = "ASSIST",       [30] = "TARGET_PET",
    [39] = "CLEAR_TARGET", [40] = "CYCLE_PARTY",
  },
}
-- Jump / Interact on the face buttons: Xbox / PlayStation A / Cross = Jump, X / Square = Interact;
-- Nintendo X = Jump, A = Interact (by label: positional Switch = top / right, Nintendo layout = X / A keys)
local CE_FACE = { xbox = { 1, 2 }, ps = { 1, 2 }, switch = { 3, 4 }, switchn = { 2, 1 } }
setmetatable(OP.PROFILES.ce, { __index = function(t, k)
  local f = CE_FACE[cfg and cfg.style or "xbox"] or CE_FACE.xbox
  if k == f[1] then return "JUMP" end
  if k == f[2] then return "INTERACT" end
  return nil
end })
OP.PROFILE_ORDER = { "ce", "forever" }
OP.PROFILE_NAMES = { ce = "Console Experience", forever = "WoW: Forever" }

OP.DEFAULT_CHORDS = { "MAP", "RADIAL", "CHARACTER", "BAGS", "CHAT", "SPELLBOOK", "QUESTS", "TALENTS" }

----------------------------------------------------------------------
-- Window context: what each button does while a window has focus.
-- (Game action = the slot's ability / system action; Window action = this.)
----------------------------------------------------------------------
OP.UI_ROLES = { "UI_CONFIRM", "UI_ALT", "UI_SHIFT", "UI_BACK", "UI_UP", "UI_DOWN", "UI_LEFT", "UI_RIGHT",
                "UI_TAB_NEXT", "UI_TAB_PREV", "UI_SCROLL_UP", "UI_SCROLL_DOWN", "UI_DESTROY" }
OP.UI_ROLE_NAMES = {
  UI_CONFIRM = "Confirm", UI_ALT = "Right-click", UI_SHIFT = "Shift-click", UI_BACK = "Back",
  UI_UP = "Up", UI_DOWN = "Down", UI_LEFT = "Left", UI_RIGHT = "Right",
  UI_TAB_NEXT = "Next tab", UI_TAB_PREV = "Prev tab", UI_SCROLL_UP = "Scroll up", UI_SCROLL_DOWN = "Scroll dn", UI_DESTROY = "Destroy item",
}
OP.UI_DEFAULT = {
  [13] = "UI_DESTROY",
  [1] = "UI_CONFIRM", [2] = "UI_ALT", [3] = "UI_SHIFT", [4] = "UI_BACK",
  [5] = "UI_DOWN", [6] = "UI_LEFT", [7] = "UI_UP", [8] = "UI_RIGHT",
  [9] = "UI_TAB_NEXT", [10] = "UI_TAB_PREV",
  [15] = "UI_SCROLL_DOWN", [17] = "UI_SCROLL_UP",
}

function OP.UIRoleFor(n)
  local v = cfg.ui[n]
  if v == "none" then return nil end
  if v then return v end
  return OP.UI_DEFAULT[n]
end

function OP.ProxyFor(n)
  local v = cfg.slots[n]
  if v == "none" then return nil end
  if v then return v end
  return OP.PROFILES[cfg.profile][n]
end

-- Controller-aware icons for system actions: Menu / Setup show the controller's own Start / Select button,
-- every other action is a pictogram tinted for the selected controller (Xbox green, PlayStation blue, Switch red).
local ICON_DIR = "Interface\\AddOns\\OctoPad\\Icons\\"
local THEME_OF = { xbox = "xbox", ps = "ps", switch = "switch", switchn = "switch" }
function OP.SysIcon(id)
  local style = cfg.style or "xbox"
  if id == "GAMEMENU" then return GLYPH_DIR .. style .. "_start" end
  if id == "OCTOPAD" then return GLYPH_DIR .. style .. "_select" end
  if not ACTIONS[id] then return nil end
  return ICON_DIR .. (THEME_OF[style] or "xbox") .. "_" .. id
end

-- Icon shown for a system action: per-slot choice > per-action choice > default.
function OP.IconFor(n, id)
  local a = ACTIONS[id]
  if n and cfg.icons[n] then return cfg.icons[n] end
  if cfg.aicons[id] then return cfg.aicons[id] end
  if cfg.sysicons ~= false then
    local s = OP.SysIcon(id)
    if s then return s end
  end
  return (a and a.icon) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function OP.ActualSlot(n)
  if n <= 10 then
    local b = 0
    if GetBonusBarOffset then b = GetBonusBarOffset() or 0 end
    if b > 0 then return 60 + b * 12 + n end
  end
  return n
end

----------------------------------------------------------------------
-- Entry points called from Bindings.xml
----------------------------------------------------------------------
function OctoPad_Action(n)
  if not cfg then return end
  OP.lastSlot = n
  OP.lastTime = GetTime()
  if ChatFrameEditBox and ChatFrameEditBox:IsVisible() then return end
  if OP.Flash then OP.Flash(n) end
  if OP.RadialShown and OP.RadialShown() then
    OP.RadialKey(math.mod(n - 1, 10) + 1)
    return
  end
  -- context: a window has focus -> the button's WINDOW action wins
  if cfg.uimode and OP.UIActive and OP.UIActive() then
    local role = OP.UIRoleFor(n)
    if role then
      OP.UIRun(role)
      return
    end
  end
  -- otherwise the GAME action
  local proxy = OP.ProxyFor(n)
  if proxy and ACTIONS[proxy] then
    OP.RunAction(proxy)
    return
  end
  local slot = OP.ActualSlot(n)
  if cfg.smarttarget and OP.SmartUse and OP.SmartUse(slot, n) then return end
  UseAction(slot, 0)
end

function OctoPad_Chord(i)
  if not cfg then return end
  OP.lastSlot = "chord " .. i
  OP.lastTime = GetTime()
  if OP.RadialShown and OP.RadialShown() then return end
  local id = cfg.chordmap[i] or OP.DEFAULT_CHORDS[i]
  if id and ACTIONS[id] then OP.RunAction(id) end
end

-- left stick keys while the radial menu is open (runOnUp bindings)
-- Camera (hold): mouse-look while held, with no mouse button involved.  A held right mouse button that is
-- released over a unit counts as a right-click (target / attack / talk); this never clicks anything.
-- Steam Input: send this key (default `) while the right stick is deflected, instead of the right mouse button.
-- While a window or OctoPad's menu is open the stick just moves the cursor.
local camLooking = false
-- default camera key: ` (grave / backtick).  F12 is Steam's screenshot key, so an old F12 binding moves to `.
OP.CAMERA_KEY = "`"
function OP.EnsureCameraKey()
  local cur = GetBindingKey("OCTOPAD_CAMERA")
  if cur == "F12" then
    SetBinding("F12")
    cur = nil
  end
  if cur then return end
  local act = GetBindingAction(OP.CAMERA_KEY)
  if act and act ~= "" and act ~= "OCTOPAD_CAMERA" then
    if not cfg.camkeyWarned then
      Print("Camera (hold) not bound: ` is already used by " .. act .. ". Pick a key with /opad camerakey <KEY>.")
      cfg.camkeyWarned = true
    end
    return
  end
  SetBinding(OP.CAMERA_KEY, "OCTOPAD_CAMERA")
  SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)
end
function OctoPad_Camera(state)
  if state == "up" then
    if camLooking and MouselookStop then MouselookStop() end
    camLooking = false
    return
  end
  if camLooking or not MouselookStart then return end
  if OP.UIActive and OP.UIActive() then return end
  local m = getglobal("OctoPadMenu")
  if m and m:IsVisible() then return end
  if CursorHasItem and CursorHasItem() then return end
  if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then return end
  MouselookStart()
  camLooking = true
end

function OctoPad_Stick(dir, state)
  if OP.StickKey then OP.StickKey(dir, state) end
end

function OctoPad_ToggleRadial()
  if not cfg then return end
  OP.lastSlot = "radial"
  OP.lastTime = GetTime()
  if OP.ToggleRadial then OP.ToggleRadial() end
end

----------------------------------------------------------------------
-- Bind / unbind / verify (same keys as ConsoleExperienceClassic)
----------------------------------------------------------------------
local KEYS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }
local MODS = { "", "SHIFT-", "CTRL-", "CTRL-SHIFT-" }

function OP.KeyFor(n)
  return MODS[math.floor((n - 1) / 10) + 1] .. KEYS[math.mod(n - 1, 10) + 1]
end

-- The command a slot's key should have RIGHT NOW (depends on window context).
function OP.WantedBinding(n)
  local proxy = OP.ProxyFor(n)
  local native = proxy and OP.NativeFor(proxy)
  if native then
    if cfg.uimode and OP.UIActive and OP.UIActive() and OP.UIRoleFor(n) then
      return "OCTOPAD_ACTION_" .. n
    end
    return native
  end
  return "OCTOPAD_ACTION_" .. n
end

local function SaveSet()
  local set = 1
  if GetCurrentBindingSet then set = GetCurrentBindingSet() or 1 end
  SaveBindings(set)
end

local function Remember(key)
  local cur = GetBindingAction(key)
  if cur and cur ~= "" and not string.find(cur, "^OCTOPAD") and cur ~= cfg.set[key] then
    cfg.prev[key] = cur
  end
end

local function BindKey(key, cmd)
  Remember(key)
  SetBinding(key, cmd)
  cfg.set[key] = cmd
end

function OP.CEDetected()
  return ConsoleExperience ~= nil
end

local function InCombat()
  return InCombatLockdown and InCombatLockdown()
end

function OP.BindAll()
  local n, i
  for n = 1, 40 do BindKey(OP.KeyFor(n), OP.WantedBinding(n)) end
  BindKey("SHIFT-ESCAPE", "OCTOPAD_RADIAL")
  if cfg.chords then
    for i = 1, 8 do BindKey("ALT-" .. KEYS[i], "OCTOPAD_CHORD_" .. i) end
  end
  SaveSet()
  cfg.bound = true
end

function OP.UnbindAll()
  local keys = {}
  local n, i
  for n = 1, 40 do table.insert(keys, OP.KeyFor(n)) end
  table.insert(keys, "SHIFT-ESCAPE")
  for i = 1, 8 do table.insert(keys, "ALT-" .. KEYS[i]) end
  for i = 1, table.getn(keys) do
    local key = keys[i]
    local cur = GetBindingAction(key)
    if cur and (string.find(cur, "^OCTOPAD") or cur == cfg.set[key]) then
      SetBinding(key)
      if cfg.prev[key] then SetBinding(key, cfg.prev[key]) end
    end
  end
  cfg.set = {}
  SaveSet()
  cfg.bound = false
end

-- returns "ok" | "none" | "partial", count, firstProblem
function OP.BindingStatus()
  local ok, bad = 0, nil
  local n
  for n = 1, 40 do
    local key = OP.KeyFor(n)
    local act = GetBindingAction(key)
    if act == OP.WantedBinding(n) then
      ok = ok + 1
    elseif not bad then
      bad = key .. " -> " .. ((act and act ~= "") and act or "unbound")
    end
  end
  if ok == 40 then return "ok", ok end
  if ok == 0 then return "none", ok end
  return "partial", ok, bad
end

-- Window context flipped (or mapping changed): re-point only the keys we own.
-- Transient: not saved; the saved set always describes the "no window" state.
function OP.RefreshContextBindings()
  if not cfg or not cfg.bound or OP.CEDetected() then return end
  if InCombat() then OP.pendingContext = true return end
  local n
  for n = 1, 40 do
    local key = OP.KeyFor(n)
    if cfg.set[key] then
      local want = OP.WantedBinding(n)
      if GetBindingAction(key) ~= want then
        SetBinding(key, want)
        cfg.set[key] = want
      end
    end
  end
end

-- Mapping changed (profile / slots / secure mode): re-apply and save, debounced.
function OP.RequestRebind()
  OP.rebindAt = GetTime() + 0.6
end

function OP.SetChords(on)
  cfg.chords = on and true or false
  local i
  if cfg.chords and cfg.bound then
    for i = 1, 8 do BindKey("ALT-" .. KEYS[i], "OCTOPAD_CHORD_" .. i) end
  elseif not cfg.chords then
    for i = 1, 8 do
      local cur = GetBindingAction("ALT-" .. KEYS[i])
      if cur and string.find(cur, "^OCTOPAD") then SetBinding("ALT-" .. KEYS[i]) end
    end
  end
  SaveSet()
end

function OP.NotifyChanged()
  if cfg and cfg.bound then OP.RequestRebind() end
  if OP.HUDRefresh then OP.HUDRefresh() end
  if OP.MenuRefresh then OP.MenuRefresh() end
end

----------------------------------------------------------------------
-- Settings migrations.  cfg.schema = how many have run on these settings.  To change the shape or meaning of
-- a saved setting, append a function here (never edit or reorder the old ones).
----------------------------------------------------------------------
OP.MIGRATIONS = {
  -- 1: the mouse-cursor feature was removed: drop any leftover assignments to it
  function(db)
    local n
    for n = 1, 40 do
      if db.ui[n] == "UI_CURSOR" then db.ui[n] = nil end
      if db.slots[n] == "CURSOR" then db.slots[n] = nil end
    end
    db.cursor, db.reticle = nil, nil
  end,
  -- 2: smart target categories
  function(db)
    if type(db.smartcat) ~= "table" then db.smartcat = {} end
    local i
    local cats = { "spells", "buffs", "attacks", "pets", "other" }
    for i = 1, table.getn(cats) do
      if db.smartcat[cats[i]] == nil then db.smartcat[cats[i]] = true end
    end
  end,
  -- 3: window-control icon style "auto" became the chevron set
  function(db)
    if db.keycaps == "auto" or db.keycaps == nil then db.keycaps = "chevron" end
  end,
  -- 4: the aggro ring moved to CombatLedger_pfUIThreat
  function(db)
    db.aggro, db.aggrowarn = nil, nil
  end,
}

function OP.Migrate(db)
  local from = db.schema or 0
  local i
  for i = from + 1, table.getn(OP.MIGRATIONS) do
    OP.MIGRATIONS[i](db)
  end
  db.schema = table.getn(OP.MIGRATIONS)
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ADDON_ACTION_FORBIDDEN")
f:RegisterEvent("ADDON_ACTION_BLOCKED")
local healAt = nil
local poll = 0

f:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == "OctoPad" then
    -- settings are per character (OctoPadCharDB).  The first time a character logs in with this version it
    -- starts from a copy of the old account-wide settings (OctoPadDB), then evolves on its own.
    if not OctoPadCharDB then
      OctoPadCharDB = {}
      if OctoPadDB then
        local function Copy(t)
          if type(t) ~= "table" then return t end
          local o, k, v = {}, nil, nil
          for k, v in pairs(t) do o[k] = Copy(v) end
          return o
        end
        local k, v
        for k, v in pairs(OctoPadDB) do OctoPadCharDB[k] = Copy(v) end
      end
    end
    local db = OctoPadCharDB
    local k, v
    for k, v in pairs(defaults) do
      if db[k] == nil then db[k] = v end
    end
    local tables = { "slots", "prev", "chordmap", "ui", "blocked", "set", "btn", "windows", "icons", "aicons", "smartover" }
    for k = 1, table.getn(tables) do
      if not db[tables[k]] then db[tables[k]] = {} end
    end
    if not db.gscale then db.gscale = { left = 1, right = 1 } end
    if not db.stickkeys then db.stickkeys = { "W", "A", "S", "D" } end   -- up, left, down, right
    cfg = db
    OP.cfg = cfg
    OP.Migrate(cfg)

  elseif event == "PLAYER_LOGIN" then
    if not cfg then return end
    if OP.BuildHUD then OP.BuildHUD() end
    if OP.BuildMinimap then OP.BuildMinimap() end
    if OP.UIInit then OP.UIInit() end
    if OP.CEDetected() then
      Print("|cffff9900ConsoleExperienceClassic is loaded too.|r Both use keys 1-0; disable one of them. OctoPad will not touch your key bindings while it is loaded (override: /opad bind force).")
    elseif not cfg.firstrun then
      cfg.firstrun = true
      OP.BindAll()
      Print("v" .. OP.VERSION .. " first run: controller keys applied. Click the |cffffff00minimap button|r or type |cffffff00/opad|r for options; the menu can remove the keys again.")
    end

  elseif event == "PLAYER_ENTERING_WORLD" then
    if cfg and OP.EnsureCameraKey then OP.EnsureCameraKey() end
    if cfg and cfg.bound and cfg.enforce and not OP.CEDetected() then
      healAt = GetTime() + 4          -- let other addons finish rebinding first
    end

  elseif event == "ADDON_ACTION_FORBIDDEN" or event == "ADDON_ACTION_BLOCKED" then
    if cfg and arg1 == "OctoPad" then
      local fn = tostring(arg2)
      cfg.blocked[fn] = (cfg.blocked[fn] or 0) + 1
      Print("The client blocked OctoPad from calling |cffff9900" .. fn .. "|r (protected function). Logged under /opad debug.")
      if not cfg.native then
        cfg.native = true
        Print("Secure mode switched on: Jump / Run / targeting now use Blizzard's own key bindings.")
        OP.RequestRebind()
      end
      if OP.MenuRefresh then OP.MenuRefresh() end
    end
  end
end)

f:SetScript("OnUpdate", function()
  if not cfg then return end
  local now = GetTime()

  if healAt and now >= healAt then
    healAt = nil
    if cfg.bound and cfg.enforce then
      local state, _, bad = OP.BindingStatus()
      if state ~= "ok" then
        OP.BindAll()
        Print("Controller key bindings were changed by something else (" .. tostring(bad or "unbound") .. ") and have been re-applied.")
        if OP.MenuRefresh then OP.MenuRefresh() end
      end
    end
  end

  if OP.rebindAt and now >= OP.rebindAt and not InCombat() then
    OP.rebindAt = nil
    if cfg.bound and not OP.CEDetected() then OP.BindAll() end
    if OP.MenuRefresh then OP.MenuRefresh() end
  end

  poll = poll + arg1
  if poll >= 0.15 then
    poll = 0
    local active = (cfg.uimode and OP.UIActive and OP.UIActive()) and true or false
    if active ~= OP.lastUI then
      OP.lastUI = active
      OP.RefreshContextBindings()
    elseif OP.pendingContext and not InCombat() then
      OP.pendingContext = false
      OP.RefreshContextBindings()
    end
  end
end)

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
local function Help()
  Print("v" .. OP.VERSION .. "  profile=" .. cfg.profile .. "  style=" .. cfg.style .. "  bound=" .. tostring(cfg.bound))
  Print("/opad  or  /opad menu       open the options menu (also: minimap button)")
  Print("/opad bind | unbind | repair  controller key layout")
  Print("/opad profile ce|forever    /opad style xbox|ps|switch|switchn")
  Print("/opad slot <1-40> <ACTION|none|default>   /opad ui <1-40> <ROLE|none|default>   /opad actions")
  Print("/opad hud on|off   scale <0.5-2>   edit   resetpos   radial   minimap on|off")
  Print("/opad native on|off (secure mode)   /opad uimode on|off (window navigation)   /opad smartfocus on|off")
  Print("/opad soft on|off   /opad hints on|off   /opad stick <up> <left> <down> <right>")
  Print("/opad window <FrameName>|mouse   /opad windows (list)   /opad icon <1-40> <IconName|default>")
  Print("/opad chords on|off   /opad reset   /opad debug   /opad probe [test]")
end

SLASH_OCTOPAD1 = "/opad"
SLASH_OCTOPAD2 = "/octopad"
SlashCmdList["OCTOPAD"] = function(msg)
  if not cfg then return end
  local _, _, cmd, rest = string.find(msg or "", "^(%S*)%s*(.*)$")
  cmd = string.lower(cmd or "")
  rest = rest or ""
  local arg = string.lower(rest)

  if cmd == "" or cmd == "menu" or cmd == "options" then
    if OP.ToggleMenu then OP.ToggleMenu() end

  elseif cmd == "help" then
    Help()

  elseif cmd == "bind" or cmd == "repair" then
    if OP.CEDetected() and arg ~= "force" then
      Print("ConsoleExperienceClassic is loaded and already owns keys 1-0. Disable it, or run |cffffff00/opad bind force|r.")
    else
      OP.BindAll()
      Print("Controller keys applied.")
    end
    OP.NotifyChanged()

  elseif cmd == "unbind" then
    OP.UnbindAll()
    Print("OctoPad keys removed; previous bindings restored where known.")
    OP.NotifyChanged()

  elseif cmd == "profile" then
    if OP.PROFILES[arg] then
      cfg.profile = arg
      Print("Profile: " .. OP.PROFILE_NAMES[arg])
      OP.NotifyChanged()
    else
      Print("/opad profile ce | forever")
    end

  elseif cmd == "style" then
    if OP.STYLES[arg] then
      cfg.style = arg
      Print("Glyph style: " .. OP.STYLES[arg].name)
      OP.NotifyChanged()
    else
      local i
      for i = 1, table.getn(OP.STYLE_ORDER) do
        Print("  " .. OP.STYLE_ORDER[i] .. " = " .. OP.STYLES[OP.STYLE_ORDER[i]].name)
      end
    end

  elseif cmd == "slot" or cmd == "ui" then
    local _, _, sn, act = string.find(rest, "^(%d+)%s+(%S+)")
    sn = tonumber(sn)
    local tbl, valid = cfg.slots, ACTIONS
    if cmd == "ui" then
      tbl = cfg.ui
      valid = OP.UI_ROLE_NAMES
    end
    if sn and sn >= 1 and sn <= 40 and act then
      act = string.upper(act)
      if act == "DEFAULT" then
        tbl[sn] = nil
        Print(cmd .. " " .. sn .. ": default")
      elseif act == "NONE" then
        tbl[sn] = "none"
        Print(cmd .. " " .. sn .. ": none")
      elseif valid[act] then
        tbl[sn] = act
        Print(cmd .. " " .. sn .. ": " .. act)
      else
        if cmd == "ui" then Print("Unknown role. Roles: " .. table.concat(OP.UI_ROLES, ", "))
        else Print("Unknown action. /opad actions") end
      end
      OP.NotifyChanged()
    else
      Print("/opad " .. cmd .. " <1-40> <" .. (cmd == "ui" and "ROLE" or "ACTION") .. "|none|default>")
    end

  elseif cmd == "actions" then
    Print("Actions: " .. table.concat(OP.ACTION_ORDER, ", "))
    Print("Window roles: " .. table.concat(OP.UI_ROLES, ", "))

  elseif cmd == "hud" then
    if arg == "on" then cfg.hud = true
    elseif arg == "off" then cfg.hud = false
    else cfg.hud = not cfg.hud end
    OP.NotifyChanged()

  elseif cmd == "scale" then
    local n = tonumber(arg)
    if n then
      if n < 0.5 then n = 0.5 elseif n > 2 then n = 2 end
      cfg.scale = n
      Print("HUD scale " .. n)
      OP.NotifyChanged()
    else
      Print("/opad scale <0.5-2>")
    end

  elseif cmd == "edit" or cmd == "unlock" then
    if OP.SetEdit then OP.SetEdit(not OP.edit) end
    Print("Layout edit mode " .. (OP.edit and "ON: drag a button to move it, mouse wheel resizes it, drag the blue handles to move a cross." or "OFF."))

  elseif cmd == "lock" then
    if OP.SetEdit then OP.SetEdit(false) end

  elseif cmd == "resetpos" then
    if OP.ResetHUDPosition then OP.ResetHUDPosition() end
    Print("HUD position reset.")

  elseif cmd == "radial" then
    if OP.ToggleRadial then OP.ToggleRadial() end

  elseif cmd == "minimap" then
    if arg == "on" then cfg.mmshow = true elseif arg == "off" then cfg.mmshow = false else cfg.mmshow = not cfg.mmshow end
    if OP.MinimapRefresh then OP.MinimapRefresh() end
    OP.NotifyChanged()

  elseif cmd == "native" then
    cfg.native = (arg ~= "off")
    Print("Secure mode " .. (cfg.native and "ON (protected actions use Blizzard's own key bindings)" or "OFF (Lua calls; may trigger the 'blocked' popup)"))
    OP.NotifyChanged()

  elseif cmd == "uimode" then
    cfg.uimode = (arg ~= "off")
    Print("Window navigation " .. (cfg.uimode and "ON" or "OFF"))
    OP.NotifyChanged()

  elseif cmd == "smartfocus" then
    cfg.smartfocus = (arg ~= "off")
    Print("Smart default focus " .. (cfg.smartfocus and "ON (starts on Accept / Complete Quest / Continue ...)" or "OFF (starts on the top-left element)"))
    OP.NotifyChanged()

  elseif cmd == "window" then
    if arg == "mouse" then
      if OP.RegisterWindowUnderMouse then OP.RegisterWindowUnderMouse() end
    elseif rest ~= "" and OP.RegisterWindow then
      OP.RegisterWindow(rest)
      Print("Added '" .. rest .. "' to the navigable windows.")
    else
      Print("/opad window <GlobalFrameName>  or  /opad window mouse  (hover the window first)")
    end

  elseif cmd == "windows" then
    if OP.ListWindows then OP.ListWindows() end

  elseif cmd == "icon" then
    local _, _, sn, ic = string.find(rest, "^(%d+)%s+(%S+)")
    sn = tonumber(sn)
    if sn and sn >= 1 and sn <= 40 and ic then
      if string.lower(ic) == "default" then
        cfg.icons[sn] = nil
        Print("Slot " .. sn .. ": default icon")
      else
        if not string.find(ic, "\\") then ic = "Interface\\Icons\\" .. ic end
        cfg.icons[sn] = ic
        Print("Slot " .. sn .. ": icon " .. ic)
      end
      OP.NotifyChanged()
    else
      Print("/opad icon <1-40> <IconName or full path or default>   (or use menu > Slots > icon button)")
    end

  elseif cmd == "smart" then
    local _, _, c1, c2 = string.find(arg or "", "^(%a+)%s*(%a*)$")
    if c1 and cfg.smartcat and cfg.smartcat[c1] ~= nil then
      if c2 == "on" then cfg.smartcat[c1] = true elseif c2 == "off" then cfg.smartcat[c1] = false else cfg.smartcat[c1] = not cfg.smartcat[c1] end
      Print("Smart target " .. c1 .. " " .. (cfg.smartcat[c1] and "ON" or "OFF"))
    else
      if arg == "on" then cfg.smarttarget = true elseif arg == "off" then cfg.smarttarget = false else cfg.smarttarget = not cfg.smarttarget end
      Print("Smart target " .. (cfg.smarttarget and "ON" or "OFF") .. "   (categories: /opad smart <spells|buffs|attacks|pets|other> on|off)")
    end
    OP.NotifyChanged()

  elseif cmd == "soft" then
    if arg == "on" then cfg.soft = true elseif arg == "off" then cfg.soft = false else cfg.soft = not cfg.soft end
    Print("Soft target " .. (cfg.soft and "ON" or "OFF"))
    OP.NotifyChanged()

  elseif cmd == "hints" then
    if arg == "on" then cfg.hints = true elseif arg == "off" then cfg.hints = false else cfg.hints = not cfg.hints end
    Print("Button hints " .. (cfg.hints and "ON" or "OFF"))
    OP.NotifyChanged()

  elseif cmd == "stick" then
    local _, _, u, l, d, r = string.find(rest, "^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")
    if u then
      cfg.stickkeys = { string.upper(u), string.upper(l), string.upper(d), string.upper(r) }
      Print("Left stick keys (up left down right): " .. table.concat(cfg.stickkeys, " "))
    else
      Print("/opad stick <up> <left> <down> <right>   (now " .. table.concat(cfg.stickkeys, " ") .. ")")
    end

  elseif cmd == "probe" then
    if OP.Probe then OP.Probe(arg) end

  elseif cmd == "camerakey" then
    local key = string.upper(rest or "")
    if key ~= "" then
      local old = GetBindingKey("OCTOPAD_CAMERA")
      if old then SetBinding(old) end
      SetBinding(key, "OCTOPAD_CAMERA")
      SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)
      Print("Camera (hold) is now on " .. key .. ". In Steam Input, send " .. key .. " while the right stick is pushed (instead of the right mouse button).")
    else
      Print("Camera (hold) key: " .. (GetBindingKey("OCTOPAD_CAMERA") or "none") .. "   /opad camerakey <KEY>  (default `)")
    end

  elseif cmd == "chords" then
    if arg == "on" or arg == "off" then
      OP.SetChords(arg == "on")
      Print("Chord layer " .. arg .. (cfg.chords and " (ALT-1..8: A,X,Y,B,Down,Left,Up,Right)" or ""))
      OP.NotifyChanged()
    else
      Print("/opad chords on|off")
    end

  elseif cmd == "deselect" then
    if arg == "on" then cfg.autodeselect = true elseif arg == "off" then cfg.autodeselect = false else cfg.autodeselect = (cfg.autodeselect == false) end
    Print("Deselect NPCs after talking to them " .. (cfg.autodeselect ~= false and "ON" or "OFF"))

  elseif cmd == "reset" then
    OctoPadCharDB = nil
    OctoPadDB = nil
    ReloadUI()

  elseif cmd == "debug" then
    Print("version " .. OP.VERSION .. "  profile=" .. cfg.profile .. "  style=" .. cfg.style .. "  secure mode=" .. tostring(cfg.native) .. "  window navigation=" .. tostring(cfg.uimode))
    Print("ConsoleExperience: " .. tostring(OP.CEDetected()) .. "   Interact.dll: " .. tostring(InteractNearest ~= nil) ..
      "   pfUI: " .. tostring(pfUI ~= nil) .. "   pfUI movable: " .. tostring(OP.HUDPfMove and OP.HUDPfMove() or false))
    local state, count, bad = OP.BindingStatus()
    Print("bindings: " .. state .. " (" .. count .. "/40)" .. (bad and ("  first problem: " .. bad) or "") ..
      "   binding set: " .. tostring(GetCurrentBindingSet and GetCurrentBindingSet() or "?"))
    if OP.lastSlot then
      Print("last input: " .. tostring(OP.lastSlot) .. "  " .. string.format("%.1f", GetTime() - OP.lastTime) .. "s ago")
    else
      Print("last input: none received yet (keys bound natively - Jump, Run, targeting - do not report here)")
    end
    local blocked = ""
    local k, v
    for k, v in pairs(cfg.blocked) do blocked = blocked .. k .. " x" .. v .. "  " end
    Print("functions the client blocked: " .. (blocked ~= "" and blocked or "none"))
    local base, i = ""
    for i = 1, 10 do
      local p = OP.ProxyFor(i)
      local nat = p and OP.NativeFor(p)
      base = base .. i .. "=" .. (p or "bar") .. (nat and "*" or "") .. " "
    end
    Print("base page (* = native binding): " .. base)
    Print("soft target: " .. tostring(cfg.soft) .. "   SuperWoW: " .. tostring(SUPERWOW_VERSION ~= nil))
    Print("window context active: " .. tostring(OP.UIActive and OP.UIActive() or false))

  else
    Help()
  end
end
