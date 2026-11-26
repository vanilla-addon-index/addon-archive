--[[
OctoPad World  -  controller play without the mouse.

  * SOFT TARGET    Of the units whose nameplates are already visible, the one nearest the
                   screen centre gets a name pulsing in red / yellow / green (by reaction) and a mouseover tooltip,
                   including your quest kill counts ("Boar slain: 3/10").  Nameplates are
                   switched on in the game: V = enemies, Ctrl+V = friendly (or use pfUI plates).
                   With SuperWoW the full unit tooltip is used, otherwise name / level / health.
                   Your real target is never changed.
  * BUTTON HINTS   A bar that shows what each button does for the open window
                   (Confirm / Back / Right-click / ...), like ConsolePort's hotkey hints.

Lua 5.0: no '#', no '%', no varargs.
]]

local OP = OctoPad

local rings, card, hintBar = {}, nil, nil
local softAcc, hintAcc = 0, 0
local softOwned = false
local softKey = nil
local questVer = 0

----------------------------------------------------------------------
-- Soft target (nameplate based)
----------------------------------------------------------------------
local function BuildSoft()
  card = CreateFrame("Frame", "OctoPadSoftCard", UIParent)
  card:SetWidth(190)
  card:SetHeight(72)
  card:SetPoint("LEFT", UIParent, "CENTER", 150, 30)
  card:SetFrameStrata("TOOLTIP")
  if not OP.Round(card, .9) then
    card:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
  end
  card.name = card:CreateFontString(nil, "OVERLAY")
  card.name:SetFont(OP.Font(), 12, "OUTLINE")
  card.name:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -7)
  card.name:SetWidth(174)
  card.name:SetJustifyH("LEFT")
  card.level = card:CreateFontString(nil, "OVERLAY")
  card.level:SetFont(OP.Font(), 10, "OUTLINE")
  card.level:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -23)
  card.level:SetTextColor(.8, .8, .8)
  card.barBack = card:CreateTexture(nil, "ARTWORK")
  card.barBack:SetTexture("Interface\\Buttons\\WHITE8X8")
  card.barBack:SetVertexColor(0, 0, 0, .7)
  card.barBack:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -38)
  card.barBack:SetWidth(174)
  card.barBack:SetHeight(8)
  card.bar = card:CreateTexture(nil, "OVERLAY")
  card.bar:SetTexture("Interface\\Buttons\\WHITE8X8")
  card.bar:SetVertexColor(.2, .8, .2, .95)
  card.bar:SetPoint("TOPLEFT", card, "TOPLEFT", 9, -39)
  card.bar:SetHeight(6)
  card.quest = card:CreateFontString(nil, "OVERLAY")
  card.quest:SetFont(OP.Font(), 10, "OUTLINE")
  card.quest:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -52)
  card.quest:SetWidth(174)
  card.quest:SetJustifyH("LEFT")
  card:Hide()
end

local function GetRing(i)
  if rings[i] then return rings[i] end
  local r = CreateFrame("Frame", "OctoPadSoftRing" .. i, UIParent)
  r:SetFrameStrata("BACKGROUND")
  r:EnableMouse(false)
  r.glow = r:CreateTexture(nil, "BACKGROUND")
  r.glow:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  r.glow:SetBlendMode("ADD")
  r:Hide()
  rings[i] = r
  return r
end

local function HideRings(from)
  local i
  for i = from, table.getn(rings) do rings[i]:Hide() end
end

-- The soft select is shown on the nameplate's name: its colour pulses slowly between the reaction colour
-- (hostile red, neutral yellow, friendly green) and a lighter tint.  The original colour is restored afterwards.
local styled = nil
local function RestoreName()
  if styled then
    pcall(styled.fs.SetTextColor, styled.fs, styled.r, styled.g, styled.b)
    styled = nil
  end
end

function OP.SoftNameFS() return styled and styled.fs end

local function PulseName()
  if not styled then return end
  local t = .5 + .5 * math.sin(GetTime() * 2.4)          -- about one pulse every 2.6 s
  local k = .25 + .75 * t
  local s = styled
  s.fs:SetTextColor(s.cr * k + (1 - k) * .35, s.cg * k + (1 - k) * .35, s.cb * k + (1 - k) * .35)
end

local function StyleName(fs, cr, cg, cb)
  if not fs then return end
  if not styled or styled.fs ~= fs then
    RestoreName()
    local r, g, b = fs:GetTextColor()
    styled = { fs = fs, r = r or 1, g = g or 1, b = b or 1 }
  end
  styled.cr, styled.cg, styled.cb = cr, cg, cb
  PulseName()
end

local function HideSoft()
  OP.softToken = nil
  RestoreName()
  if softKey and SetMouseoverUnit then pcall(SetMouseoverUnit) end
  softKey = nil
  HideRings(1)
  if card then card:Hide() end
  if softOwned then
    GameTooltip:Hide()
    softOwned = false
  end
end

-- read name / level / reaction colour / health from a nameplate frame
-- the visible name text of a plate: pfUI keeps it on p.nameplate.name (the Blizzard regions are hidden)
local function FindNameFS(p, name, fallback)
  local np = p.nameplate
  if np and np.name and np.name.GetText then return np.name end
  local frames = { p }
  local kids = { p:GetChildren() }
  local i, j
  for i = 1, table.getn(kids) do table.insert(frames, kids[i]) end
  for i = 1, table.getn(frames) do
    local regs = { frames[i]:GetRegions() }
    for j = 1, table.getn(regs) do
      local r = regs[j]
      if r:GetObjectType() == "FontString" and r:GetText() == name and r:IsVisible() and (r:GetAlpha() or 1) > 0.05 then
        return r
      end
    end
  end
  return fallback
end

local function PlateInfo(p)
  local regs = { p:GetRegions() }
  local fs = {}
  local i
  for i = 1, table.getn(regs) do
    if regs[i]:GetObjectType() == "FontString" then table.insert(fs, regs[i]) end
  end
  if not fs[1] then return nil end
  local name = fs[1]:GetText()
  if not name or name == "" then return nil end
  local info = { name = name, level = fs[2] and fs[2]:GetText() or "" }
  info.nameFS = FindNameFS(p, name, fs[1])
  info.r, info.g, info.b = fs[1]:GetTextColor()
  local kids = { p:GetChildren() }
  for i = 1, table.getn(kids) do
    if kids[i]:GetObjectType() == "StatusBar" then
      local mn, mx = kids[i]:GetMinMaxValues()
      local v = kids[i]:GetValue()
      if mx and mn and mx > mn then info.hp = (v - mn) / (mx - mn) end
      info.bar = kids[i]
      break
    end
  end
  return info
end

OP.PlateInfo = PlateInfo

-- every visible nameplate on screen, nearest to the screen centre first
local function ScanPlates()
  local es = UIParent:GetEffectiveScale()
  local sw, sh = UIParent:GetWidth() * es, UIParent:GetHeight() * es
  local cx, cy = sw / 2, sh / 2
  local kids = { WorldFrame:GetChildren() }
  local list = {}
  local i
  for i = 1, table.getn(kids) do
    local p = kids[i]
    if p ~= UIParent and not p:GetName() and p:IsVisible() then
      local x, y = p:GetCenter()
      if x and y then
        local ps = p:GetEffectiveScale()
        x, y = x * ps, y * ps
        if x > 0 and x < sw and y > 0 and y < sh then
          local info = PlateInfo(p)
          if info then
            local dx, dy = x - cx, y - cy
            table.insert(list, { frame = p, info = info, d = math.sqrt(dx * dx + dy * dy) })
          end
        end
      end
    end
  end
  table.sort(list, function(a, b) return a.d < b.d end)
  return list
end

local function TokenFor(p, info)
  if SUPERWOW_VERSION then
    local g = p:GetName(1)
    if g and g ~= "" then return g end
  end
  if UnitExists("mouseover") and UnitName("mouseover") == info.name then return "mouseover" end
  if UnitExists("target") and UnitName("target") == info.name then return "target" end
  return nil
end

-- Quest objectives that involve this unit ("Boar slain: 3/10"), read from the quest log.
local function QuestLines(name)
  local lines = {}
  if not GetNumQuestLogEntries then return lines end
  local n = GetNumQuestLogEntries()
  local q
  for q = 1, n do
    local title, _, _, isHeader = GetQuestLogTitle(q)
    if title and not isHeader then
      local nobj = GetNumQuestLeaderBoards(q) or 0
      local j
      for j = 1, nobj do
        local desc, otype, done = GetQuestLogLeaderBoard(j, q)
        if desc and otype == "monster" and string.find(desc, name, 1, true) == 1 then
          table.insert(lines, { title = title, text = desc, done = done })
        end
      end
    end
  end
  return lines
end

local function QuestText(lines)
  local out = ""
  local i
  for i = 1, table.getn(lines) do
    local l = lines[i]
    local col = l.done and "|cff55ff55" or "|cffffd100"
    if out ~= "" then out = out .. "\n" end
    out = out .. col .. l.text .. "|r"
  end
  return out
end

local function ShowCard(info, lines)
  local t = OP.Theme()
  if not card.opRounded then
    card:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], t.bg[4])
    card:SetBackdropBorderColor(t.ac[1], t.ac[2], t.ac[3], .7)
  end
  card.name:SetText(info.name)
  card.name:SetTextColor(info.r or 1, info.g or 1, info.b or 1)
  card.level:SetText((info.level and info.level ~= "") and ("Level " .. info.level) or "")
  if info.hp then
    card.bar:SetWidth(math.max(1, 172 * info.hp))
    card.bar:Show()
    card.barBack:Show()
  else
    card.bar:Hide()
    card.barBack:Hide()
  end
  local h = 52
  if table.getn(lines) > 0 then
    card.quest:SetText(QuestText(lines))
    h = 54 + table.getn(lines) * 12
  else
    card.quest:SetText("")
  end
  card:SetHeight(h)
  card:Show()
end

-- soft select: name colour by reaction (hostile red, neutral yellow, friendly green)
local function ReactionColor(entry)
  local info = entry.info
  local tok = OP.softToken
  if tok and UnitExists(tok) then
    if UnitCanAttack("player", tok) then
      if UnitIsEnemy and not UnitIsEnemy("player", tok) then return 1, .85, .1 end   -- neutral
      return 1, .15, .1
    end
    return .2, 1, .3
  end
  local r, g, b = info.r or 1, info.g or 1, info.b or 1
  if r > .8 and g < .45 then return 1, .15, .1 end
  if r > .8 and g > .75 and b < .4 then return 1, .85, .1 end
  if g > .7 and r < .6 then return .2, 1, .3 end
  return .2, 1, .3
end

local function DrawRing(entry)
  local cr, cg, cb = ReactionColor(entry)
  StyleName(entry.info.nameFS, cr, cg, cb)
end

local function ShowPrimary(entry)
  local p, info = entry.frame, entry.info
  local token = TokenFor(p, info)
  local key = info.name .. tostring(token) .. "#" .. questVer
  if key == softKey then
    -- keep the card's health bar live
    if card:IsShown() and info.hp then card.bar:SetWidth(math.max(1, 172 * info.hp)) end
    return
  end
  softKey = key
  local lines = QuestLines(info.name)

  -- SuperWoW: make the soft-selected unit the real mouseover and show the game's own tooltip for it
  -- (other addons that hook the tooltip, such as pfQuest, then add their lines as usual)
  local viaMouseover = false
  if SetMouseoverUnit and token and token ~= "mouseover" and token ~= "target" then
    if pcall(SetMouseoverUnit, token) and UnitExists("mouseover") then viaMouseover = true end
  elseif token == "mouseover" then
    viaMouseover = true
  end

  local unit = viaMouseover and "mouseover" or token
  if unit then
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("LEFT", UIParent, "CENTER", 150, 30)
    local ok = pcall(GameTooltip.SetUnit, GameTooltip, unit)
    if ok then
      if not pfQuest then
        local i
        for i = 1, table.getn(lines) do
          local l = lines[i]
          if l.done then GameTooltip:AddLine(l.text, .3, 1, .3) else GameTooltip:AddLine(l.text, 1, .82, 0) end
        end
      end
      GameTooltip:Show()
      softOwned = true
      card:Hide()
      return
    end
  end
  -- no mouseover available (no SuperWoW): OctoPad's own card
  if softOwned then
    GameTooltip:Hide()
    softOwned = false
  end
  ShowCard(info, lines)
end

local function SoftTick(active)
  local cfg = OP.cfg
  if not cfg.soft or active or OP.edit then return HideSoft() end
  -- never fight another tooltip (HUD button hover, item tooltips, ...)
  if GameTooltip:IsVisible() and not softOwned then return HideSoft() end
  local list = ScanPlates()
  local n = table.getn(list)
  if n == 0 then return HideSoft() end
  OP.softToken = TokenFor(list[1].frame, list[1].info)
  DrawRing(list[1])
  HideRings(2)
  ShowPrimary(list[1])
end

----------------------------------------------------------------------
-- Smart target: action-bar buttons pick their own target.  Each category can be switched off
-- (cfg.smartcat): spells, buffs, attacks, pets, other.
--   buffs   (helpful spells) -> soft/mouseover friend, else your friendly target, else yourself
--   spells  (harmful/other)  -> soft/mouseover enemy, else your current target
--   attacks (Attack, Auto Shot, Shoot, Throw, equipped weapons) -> target the soft/mouseover enemy first
--   pets    (Mend Pet, Revive Pet ...) -> your pet
--   other   (items with "Use:") -> helpful ones on yourself, harmful ones on the soft enemy
-- Casting at a unit other than your target needs SuperWoW (CastSpellByName with a unit).
-- Attacks and items can only change your real target (TargetUnit); that is skipped if the client blocked it.
----------------------------------------------------------------------
local scanTip
-- Classification order matters (a wrong "helpful" guess self-casts an attack and gives "Invalid target"):
--   1. enemy / hostile in the tooltip            -> harmful
--   2. clearly healing / friendly wording         -> helpful   (heal, restore, party member, absorb ...)
--   3. damage / melee / weapon / attack wording   -> harmful   (Heroic Strike: "increases melee damage")
--   4. vague buff wording                         -> helpful   (increases armor, mark of ...)
local STRONG_HELP = { "heal", "restore", "resurrect", "revive", "cure", "dispel", "friendly", "party member",
                      "raid member", "absorb", "remove" }
local HELP_WORDS = { "increase", "grant", "armor", "protect", "bless", "regenerat", "immun", "fortitude", "spirit",
                     "intellect", "stamina", "thorns", "mark of", "renew", "ally" }
local HARM_WORDS = { "damage", "melee", "weapon", "attack", "strike", "slow", "stun", "root", "fear", "sleep",
                     "interrupt", "taunt", "curse", "poison", "disease", "burn", "wound", "drain", "silence",
                     "polymorph", "banish", "incapacit", "knock", "bleed" }
local ATTACK_NAMES = { ["attack"] = 1, ["auto shot"] = 1, ["shoot"] = 1, ["throw"] = 1, ["shoot bow"] = 1,
                       ["shoot gun"] = 1, ["shoot crossbow"] = 1 }

local function HasWord(text, list)
  local i
  for i = 1, table.getn(list) do
    if string.find(text, list[i], 1, true) then return true end
  end
  return false
end

-- name, rank text, kind ("help" / "harm" / "other"), isItem, lowercase body of an action slot
local function ScanSlot(slot)
  if not scanTip then
    scanTip = CreateFrame("GameTooltip", "OctoPadScanTip", UIParent, "GameTooltipTemplate")
  end
  scanTip:SetOwner(UIParent, "ANCHOR_NONE")
  scanTip:SetAction(slot)
  local name = OctoPadScanTipTextLeft1 and OctoPadScanTipTextLeft1:GetText()
  if not name or name == "" then return nil end
  local rank = OctoPadScanTipTextRight1 and OctoPadScanTipTextRight1:GetText()
  if rank == "" then rank = nil end
  local body = ""
  local i
  for i = 2, 12 do
    local l = getglobal("OctoPadScanTipTextLeft" .. i)
    local t = l and l:GetText()
    if t then body = body .. " " .. string.lower(t) end
  end
  local isItem = string.find(body, "use:", 1, true) ~= nil
  local kind = "other"
  local known = not isItem and OP.SPELL_KIND and OP.SPELL_KIND[string.lower(name)]
  if known then
    kind = known                                -- OctoPadSpells.lua: no guessing for known spells
  elseif string.find(body, "enemy", 1, true) or string.find(body, "hostile", 1, true) then
    kind = "harm"
  elseif HasWord(body, STRONG_HELP) then
    kind = "help"
  elseif HasWord(body, HARM_WORDS) then
    kind = "harm"
  elseif HasWord(body, HELP_WORDS) then
    kind = "help"
  end
  return name, rank, kind, isItem, body
end

local function CastAt(name, rank, unit)
  local spell = name
  if rank and string.find(rank, "Rank", 1, true) then spell = name .. "(" .. rank .. ")" end
  return pcall(CastSpellByName, spell, unit)
end

-- make `unit` your real target (attacks and items need it); skipped when the client blocks TargetUnit
local function RetargetTo(unit)
  if not unit or not TargetUnit then return end
  if OP.cfg.blocked and OP.cfg.blocked.TargetUnit then return end
  if UnitExists("target") and UnitIsUnit(unit, "target") then return end
  pcall(TargetUnit, unit)
end

-- returns true when it handled the action (the caller then skips its normal UseAction)
-- n = the controller button (1..40) for its per-button override (cfg.smartover[n]):
--   nil = automatic, "asis" = never redirect, "self" = always on yourself, "soft" = always on the soft target
function OP.SmartUse(slot, n)
  if not slot or not HasAction(slot) or GetActionText(slot) then return false end
  local over = n and OP.cfg.smartover and OP.cfg.smartover[n]
  if over == "asis" then return false end
  if over == "self" then
    UseAction(slot, 0, 1)
    return true
  end
  local cat = OP.cfg.smartcat or {}
  local name, rank, kind, isItem, body = ScanSlot(slot)
  if not name then return false end
  if over == "soft" then
    local u = OP.cfg.soft and OP.softToken or nil
    if not u and UnitExists("mouseover") then u = "mouseover" end
    if u and SUPERWOW_VERSION and CastAt(name, rank, u) then return true end
    return false
  end

  local unit = OP.cfg.soft and OP.softToken or nil
  if not unit and UnitExists("mouseover") then unit = "mouseover" end
  local hostile = unit and UnitCanAttack("player", unit)
  local friend = unit and not hostile
  local redirect = SUPERWOW_VERSION ~= nil
  local lname = string.lower(name)

  -- classify
  local group
  if (IsAttackAction and IsAttackAction(slot)) or ATTACK_NAMES[lname] or (IsEquippedAction and IsEquippedAction(slot)) then
    group = "attacks"
  elseif string.find(lname, "pet", 1, true) or string.find(body, "your pet", 1, true) then
    group = "pets"
  elseif isItem or (IsConsumableAction and IsConsumableAction(slot)) then
    group = "other"
  elseif kind == "help" then
    group = "buffs"
  else
    group = "spells"
  end
  if cat[group] == false then return false end

  if group == "attacks" then
    if hostile then RetargetTo(unit) end
    return false
  elseif group == "pets" then
    if redirect and UnitExists("pet") and kind ~= "harm" then
      if CastAt(name, rank, "pet") then return true end
    end
    return false
  elseif group == "other" then
    if kind == "help" then
      if UnitExists("target") and not UnitCanAttack("player", "target") then return false end
      if friend and redirect then RetargetTo(unit) return false end
      UseAction(slot, 0, 1)                                 -- self
      return true
    elseif kind == "harm" and hostile then
      RetargetTo(unit)
    end
    return false
  end

  if kind == "help" then
    if unit and friend and redirect then
      if CastAt(name, rank, unit) then return true end
    end
    if UnitExists("target") and not UnitCanAttack("player", "target") then return false end
    UseAction(slot, 0, 1)                                   -- self
    return true
  elseif kind == "harm" then
    if unit and hostile and redirect then
      if CastAt(name, rank, unit) then return true end
    end
    return false
  end
  if unit and redirect then
    if CastAt(name, rank, unit) then return true end
  end
  return false
end

----------------------------------------------------------------------
-- Button hints  (glyph icons for the selected controller style)
----------------------------------------------------------------------
local HINT_ENTRIES = 7
local ROLE_FIRST = { "UI_CONFIRM", "UI_BACK", "UI_ALT", "UI_SHIFT" }
local FLATBD = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
  insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function ThemeHints()
  if not hintBar or hintBar.opRounded then return end
  local t = OP.Theme()
  hintBar:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], t.bg[4])
  hintBar:SetBackdropBorderColor(t.bd[1], t.bd[2], t.bd[3], t.bd[4])
end

local function BuildHints()
  hintBar = CreateFrame("Frame", "OctoPadHints", UIParent)
  hintBar:SetHeight(30)
  hintBar:SetPoint("TOP", UIParent, "TOP", 0, -64)
  hintBar:SetFrameStrata("DIALOG")
  hintBar:EnableMouse(false)
  if not OP.Round(hintBar, .9) then hintBar:SetBackdrop(FLATBD) end
  hintBar.e = {}
  local i
  for i = 1, HINT_ENTRIES do
    local e = {}
    e.icon = hintBar:CreateTexture(nil, "ARTWORK")
    e.icon:SetHeight(20)
    e.text = hintBar:CreateFontString(nil, "OVERLAY")
    e.text:SetFont(OP.Font(), 11, "OUTLINE")
    e.text:SetTextColor(.9, .9, .9)
    hintBar.e[i] = e
  end
  ThemeHints()
  hintBar:Hide()
end

-- first slot (key position 1..10 on any bar) whose window role is `role`;
-- returns the key position and the trigger layer (0 none, 1 LT, 2 RT)
local function KeyForRole(role)
  local i
  for i = 1, 10 do
    if OP.UIRoleFor(i) == role then return i, 0 end
  end
  for i = 11, 20 do
    if OP.UIRoleFor(i) == role then return i - 10, 1 end
  end
  return nil
end

-- icon (+ optional trigger icon) then label; returns the next x
local function SetEntry(i, x, key, layer, text)
  local e = hintBar.e[i]
  e.icon:ClearAllPoints()
  e.icon:SetPoint("LEFT", hintBar, "LEFT", x, 0)
  local w = 20
  if key == 9 or key == 10 then w = 33 end
  e.icon:SetWidth(w)
  e.icon:SetTexture(OP.GlyphFor(key))
  if key == 9 or key == 10 then e.icon:SetTexCoord(0, 1, .18, .82) else e.icon:SetTexCoord(0, 1, 0, 1) end
  e.icon:Show()
  local nx = x + w + 4
  if layer and layer > 0 then
    if not e.trig then
      e.trig = hintBar:CreateTexture(nil, "ARTWORK")
      e.trig:SetHeight(20)
      e.trig:SetWidth(33)
      e.trig:SetTexCoord(0, 1, .18, .82)
    end
    e.trig:ClearAllPoints()
    e.trig:SetPoint("LEFT", hintBar, "LEFT", nx, 0)
    e.trig:SetTexture(OP.GlyphTrig(layer))
    e.trig:Show()
    nx = nx + 37
  elseif e.trig then
    e.trig:Hide()
  end
  e.text:SetText(text)
  e.text:ClearAllPoints()
  e.text:SetPoint("LEFT", hintBar, "LEFT", nx, 0)
  e.text:Show()
  return nx + e.text:GetStringWidth() + 16
end

local function HideEntry(i)
  local e = hintBar.e[i]
  e.icon:Hide()
  if e.trig then e.trig:Hide() end
  e.text:Hide()
end

local function HintsTick(active)
  local cfg = OP.cfg
  if not cfg.hints or not active or OP.edit then
    if hintBar and hintBar:IsShown() then hintBar:Hide() end
    return
  end
  if not hintBar then BuildHints() end
  ThemeHints()
  local confirmText, hasTabs, isItem = OP.UIFocusInfo()
  local list = {}
  local i
  for i = 1, table.getn(ROLE_FIRST) do
    local role = ROLE_FIRST[i]
    local k, layer = KeyForRole(role)
    -- right-click / shift-click only make sense on item slots
    if (role == "UI_ALT" or role == "UI_SHIFT") and not isItem then k = nil end
    if k then
      local text = OP.UI_ROLE_NAMES[role]
      if role == "UI_CONFIRM" then text = confirmText end
      table.insert(list, { k, layer, text })
    end
  end
  if hasTabs then
    local kp, lp = KeyForRole("UI_TAB_PREV")
    local kn, ln = KeyForRole("UI_TAB_NEXT")
    if kp then table.insert(list, { kp, lp, "Prev tab" }) end
    if kn then table.insert(list, { kn, ln, "Next tab" }) end
  end
  if isItem then
    local kd, ld = KeyForRole("UI_DESTROY")
    if kd then table.insert(list, { kd, ld, "Destroy" }) end
  end
  local x, n = 10, 0
  for i = 1, table.getn(list) do
    if n < HINT_ENTRIES then
      n = n + 1
      x = SetEntry(n, x, list[i][1], list[i][2], list[i][3])
    end
  end
  for i = n + 1, HINT_ENTRIES do HideEntry(i) end
  hintBar:SetWidth(math.max(60, x - 6))
  hintBar:Show()
end

----------------------------------------------------------------------
-- Driver
----------------------------------------------------------------------
local function Shown(name)
  local f = getglobal(name)
  return f and f.IsVisible and f:IsVisible()
end

local drv = CreateFrame("Frame", "OctoPadWorldDriver")
drv:RegisterEvent("PLAYER_LOGIN")
drv:RegisterEvent("QUEST_LOG_UPDATE")

-- Deselect NPCs after talking to them: the game leaves the NPC targeted, and its plate then
-- hides the rest.  When the conversation / shop / bank ... closes, the target it selected is cleared.
local OPEN_EVENTS = { GOSSIP_SHOW = 1, QUEST_GREETING = 1, QUEST_DETAIL = 1, QUEST_PROGRESS = 1, QUEST_COMPLETE = 1,
                      MERCHANT_SHOW = 1, TRAINER_SHOW = 1, BANKFRAME_OPENED = 1, TAXIMAP_OPENED = 1,
                      AUCTION_HOUSE_SHOW = 1, MAIL_SHOW = 1, PETITION_SHOW = 1 }
local CLOSE_EVENTS = { GOSSIP_CLOSED = 1, QUEST_FINISHED = 1, MERCHANT_CLOSED = 1, TRAINER_CLOSED = 1,
                       BANKFRAME_CLOSED = 1, TAXIMAP_CLOSED = 1, AUCTION_HOUSE_CLOSED = 1, MAIL_CLOSED = 1,
                       PETITION_CLOSED = 1 }
local INTERACT_FRAMES = { "GossipFrame", "QuestFrame", "MerchantFrame", "ClassTrainerFrame", "BankFrame", "TaxiFrame",
                          "AuctionFrame", "MailFrame", "PetitionFrame" }
local talkedTo, clearAt = nil, nil
local noteAt, noteDone = nil, nil

-- Interact pressed: NPCs with no dialog (no window opens, so no close event) are deselected a moment later too
function OP.NoteInteract()
  noteAt = GetTime() + 0.4
  noteDone = nil
end

local function InteractionOpen()
  local i
  for i = 1, table.getn(INTERACT_FRAMES) do
    local f = getglobal(INTERACT_FRAMES[i])
    if f and f.IsVisible and f:IsVisible() then return true end
  end
  return false
end

local function AutoDeselect()
  clearAt = nil
  local cfg = OP.cfg
  if not cfg or cfg.autodeselect == false or not talkedTo then return end
  if InteractionOpen() then return end
  local name = talkedTo
  talkedTo = nil
  if not ClearTarget or (cfg.blocked and cfg.blocked.ClearTarget) then return end
  if UnitExists("target") and not UnitIsPlayer("target") and UnitName("target") == name then
    pcall(ClearTarget)
  end
end

drv:SetScript("OnEvent", function()
  if event == "QUEST_LOG_UPDATE" then
    questVer = questVer + 1
    return
  end
  if OPEN_EVENTS[event] then
    if UnitExists("target") and not UnitIsPlayer("target") then talkedTo = UnitName("target") end
    clearAt = nil
    return
  end
  if CLOSE_EVENTS[event] then
    clearAt = GetTime() + 0.5      -- gossip -> quest and similar hand-overs fire a close first
    return
  end
  BuildSoft()
end)
local ev
for ev in pairs(OPEN_EVENTS) do drv:RegisterEvent(ev) end
for ev in pairs(CLOSE_EVENTS) do drv:RegisterEvent(ev) end
drv:SetScript("OnUpdate", function()
  if not OP.cfg or not card then return end
  local active = OP.UIActive()
  PulseName()
  if clearAt and GetTime() >= clearAt then AutoDeselect() end
  if noteAt then
    local now = GetTime()
    if not noteDone and now >= noteAt then
      noteDone = true
      -- the unit Interact selected (a window event may already have recorded it)
      if UnitExists("target") and not UnitIsPlayer("target") and not UnitCanAttack("player", "target") then
        talkedTo = talkedTo or UnitName("target")
      end
      noteAt = now + 1.1           -- give a dialog / shop window time to open
    elseif noteDone then
      noteAt, noteDone = nil, nil
      if talkedTo and not InteractionOpen() then AutoDeselect() end
    end
  end

  softAcc = softAcc + arg1
  if softAcc >= 0.1 then
    softAcc = 0
    SoftTick(active)
  end

  hintAcc = hintAcc + arg1
  if hintAcc >= 0.2 then
    hintAcc = 0
    HintsTick(active)
  end
end)
